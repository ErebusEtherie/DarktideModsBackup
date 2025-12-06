-- File: RingHud/scripts/mods/RingHud/team/team_names.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public API (cross-file)
mod.team_names   = mod.team_names or {}
local Name       = mod.team_names

local UISettings = require("scripts/settings/ui/ui_settings")

----------------------------------------------------------------
-- Internal helpers: "vanilla" character name
----------------------------------------------------------------

local function _safe_profile(player)
    if not player then
        return nil
    end

    -- Darktide's Player objects usually have a profile() method,
    -- but we also check for a raw 'profile' field just in case.
    local prof

    local profile_member = player.profile
    if type(profile_member) == "function" then
        prof = player:profile()
    else
        prof = rawget(player, "profile")
    end

    if type(prof) == "table" then
        return prof
    end

    return nil
end

local function _default_character_name(player, profile)
    -- Prefer profile.name (matches vanilla HUD behaviour)
    if profile and type(profile) == "table" then
        local n = profile.name or profile.character_name
        if type(n) == "string" and n ~= "" then
            return n
        end
    end

    -- Fallback: player:name() or raw 'name'
    if player then
        local name_member = player.name

        if type(name_member) == "function" then
            local s = player:name()
            if type(s) == "string" and s ~= "" then
                return s
            end
        end

        local raw = rawget(player, "name")
        if type(raw) == "string" and raw ~= "" then
            return raw
        end
    end

    -- Last resort
    return "?"
end

----------------------------------------------------------------
-- Mode / glyph helpers
----------------------------------------------------------------

-- Read the current team_name_icon setting (string like "name1_icon0_status1").
local function _team_name_icon_setting()
    local s = mod._settings and mod._settings.team_name_icon
    if type(s) == "string" and s ~= "" then
        return s
    end
    return "name1_icon1_status1"
end

-- Are we in an "icon0" mode (no big icon; glyph should live in the name)?
local function _is_icon_in_name_mode()
    local tni = _team_name_icon_setting()
    if type(tni) ~= "string" then
        return false
    end
    -- Covers:
    --   name0_icon0_status1
    --   name0_icon0_status0
    --   name1_icon0_status1
    --   name1_icon0_status0
    return tni:find("icon0", 1, true) ~= nil
end

local function _archetype_glyph(profile)
    local arch = profile and profile.archetype and profile.archetype.name
    local map  = UISettings.archetype_font_icon_simple
    if arch and map and map[arch] then
        return map[arch]
    end
    return nil
end

-- Public-ish helper: return a glyph prefix for this player/profile if the
-- current team_name_icon mode wants the icon folded into the name.
function Name.glyph_prefix(player, profile)
    if not _is_icon_in_name_mode() then
        return nil
    end

    local prof  = profile or _safe_profile(player)
    local glyph = _archetype_glyph(prof)

    if not glyph or glyph == "" then
        return nil
    end

    -- IMPORTANT:
    -- No {#reset()} here, so the slot tint we apply later will cover BOTH
    -- the glyph and the name with a single {#color(...)}.
    -- The glyph and name can safely share font/style.
    return "{#font(machine_medium)}" .. glyph .. " "
end

----------------------------------------------------------------
-- Who Are You? integration (dock-only, opt-in per context)
----------------------------------------------------------------

-- Apply who_are_you's string additions to a (possibly tinted) display name.
-- Context:
--   - Only used when `context == "docked"`.
--   - Never called for floating/nameplate names.
local function _apply_who_are_you(base, player, context)
    if not base or base == "" then
        return base
    end

    -- Only docked HUD paths should get WRU additions.
    if context ~= "docked" then
        return base
    end

    if type(get_mod) ~= "function" then
        return base
    end

    local wru = get_mod("who_are_you")
    if not wru then
        return base
    end

    -- If WRU exposes an "is_enabled" flag, respect it; otherwise assume on.
    local enabled = true
    if type(wru.is_enabled) == "function" then
        local ok_enabled, res = pcall(wru.is_enabled, wru)
        if ok_enabled and res == false then
            enabled = false
        end
    end

    if not enabled then
        return base
    end

    -- Need an account id to let WRU know who this is.
    if not player or type(player.account_id) ~= "function" then
        return base
    end

    local account_id = player:account_id()
    if not account_id or account_id == "" then
        return base
    end

    -- Prefer WRU's own helper for resolving account display name, if present.
    local account_name = nil
    if type(wru.account_name) == "function" then
        local ok_ac, result = pcall(wru.account_name, account_id)
        if ok_ac and type(result) == "string" and result ~= "" then
            account_name = result
        end
    end

    -- Try any formatter WRU chooses to expose:
    --   • first: method/field on the mod table,
    --   • then: a global (for older/newer versions).
    local fn = nil
    if type(wru.modify_character_name) == "function" then
        fn = function(name)
            return wru:modify_character_name(name, account_name, account_id, "hud")
        end
    elseif type(modify_character_name) == "function" then
        fn = function(name)
            return modify_character_name(name, account_name, account_id, "hud")
        end
    end

    if not fn then
        -- No exported formatter: leave base unchanged.
        return base
    end

    local ok_fmt, modified = pcall(fn, base)
    if ok_fmt and type(modified) == "string" and modified ~= "" then
        return modified
    end

    return base
end

----------------------------------------------------------------
-- True Level integration (dock-only, opt-in per context)
----------------------------------------------------------------

local function _apply_true_level(base, player, profile, context)
    if not base or base == "" then
        return base
    end

    -- Only docked HUD paths should get TL additions.
    if context ~= "docked" then
        return base
    end

    if type(get_mod) ~= "function" then
        return base
    end

    local tl = get_mod("true_level")
    if not tl then
        return base
    end

    -- Documented API: mod.get_true_levels(character_id) + mod.replace_level(text, true_levels, reference, need_adding)
    local get_true_levels = tl.get_true_levels
    local replace_level   = tl.replace_level

    if type(get_true_levels) ~= "function" or type(replace_level) ~= "function" then
        return base
    end

    local char_id = profile and profile.character_id
    if not char_id then
        return base
    end

    -- NOTE: true_level defines these as plain functions on the mod table, not methods.
    -- Do NOT pass `tl` as a self argument here.
    local ok_levels, true_levels = pcall(get_true_levels, char_id)
    if not ok_levels or not true_levels then
        return base
    end

    -- Reference "hud" matches TL's own HUD hooks; `need_adding = true` mirrors
    -- the Team Panel behaviour so TL can decide whether/where to inject.
    local ok_fmt, modified = pcall(replace_level, base, true_levels, "hud", true)
    if ok_fmt and type(modified) == "string" and modified ~= "" then
        return modified
    end

    return base
end

----------------------------------------------------------------
-- Markup helpers
----------------------------------------------------------------

-- Constant white-tag the "primary-only" path in RingHud_state_team trims at.
local WHITE_TAG = "{#color(255,255,255)}"

local function _colored_markup(text, tint_argb255)
    if not text or text == "" then
        return ""
    end

    local t = tint_argb255
    if not t or type(t) ~= "table" then
        -- No tint: return raw text (no markup).
        -- (Primary-only trimming will just keep the whole string in this case.)
        return text
    end

    local r = t[2] or 255
    local g = t[3] or 255
    local b = t[4] or 255

    -- Layout:
    --   {#color(r,g,b)} PRIMARY {#color(255,255,255)}{#reset()}
    --
    -- IMPORTANT:
    --  • This is called ONLY on the *primary* name segment (glyph+name),
    --    BEFORE Who Are You? and True Level append their own extras.
    --  • That means WHITE_TAG marks the end of the primary segment.
    --  • RingHud_state_team’s "primary_only" mode:
    --       - finds the FIRST WHITE_TAG,
    --       - keeps everything before it,
    --       - appends "{#reset()}".
    --
    -- The docked HUD then appends WRU/TL additions *after* this tinted block,
    -- so floating/nameplate HUDs stay WRU/TL-free while docked tiles get the
    -- extra lines with their own fonts/colours.
    return string.format("{#color(%d,%d,%d)}%s%s{#reset()}", r, g, b, text, WHITE_TAG)
end

----------------------------------------------------------------
-- Primary-name builder
----------------------------------------------------------------

local function _build_primary_plain(player, profile, optional_prefix)
    local prof   = profile or _safe_profile(player)
    local name   = _default_character_name(player, prof)

    -- Prefer an explicit prefix from callers; otherwise derive one from
    -- the current team_name_icon mode + archetype glyph.
    local prefix = optional_prefix
    if prefix == nil then
        prefix = Name.glyph_prefix(player, prof)
    end

    if prefix and prefix ~= "" then
        return tostring(prefix) .. tostring(name or ""), prof
    end

    return tostring(name or ""), prof
end

----------------------------------------------------------------
-- Single compose function
-- Signature kept for existing call-sites:
--   player, profile, tint_argb255, seeded_text, optional_prefix, context_or_opts?
--
-- New optional 6th argument:
--   • string "docked" | "floating" | whatever
--   • or a table with `context` / `ref` fields.
--
-- Behaviour:
--   • If seeded_text is non-empty, callers should use it directly (current
--     RingHud_state_team behaviour) and *not* pass it here.
--   • Otherwise:
--       1. Build PRIMARY = [glyph prefix?][default_character_name]
--       2. Apply slot-tint and WHITE_TAG via _colored_markup(PRIMARY, tint)
--          ⇒ this gives the shared "base, tinted" name used by BOTH:
--             - floating/nameplates (no WRU/TL),
--             - docked tiles (with WRU/TL appended).
--       3. If context == "docked", feed the tinted primary string through
--          who_are_you and true_level, which may append extra lines / markup.
--       4. Return the final string (already tinted; no further colouring).
----------------------------------------------------------------
function Name.compose(player, profile, tint_argb255, seeded_text, optional_prefix, context_or_opts)
    -- Decode optional context
    local context = nil
    if type(context_or_opts) == "string" then
        context = context_or_opts
    elseif type(context_or_opts) == "table" then
        context = context_or_opts.context or context_or_opts.ref
    end

    -- If a seeded string is provided, the current RingHud code paths
    -- handle it without calling Name.compose, so we don't special-case
    -- seeded_text here. We always build a fresh primary.
    local primary_plain, prof = _build_primary_plain(player, profile, optional_prefix)

    -- Step 1: base, slot-tinted primary name (glyph + name), with WHITE_TAG
    -- marking the end of the primary segment.
    local tinted_primary = _colored_markup(primary_plain, tint_argb255)

    -- Step 2: docked tiles get WRU/TL applied on top of the tinted primary.
    -- Floating/nameplate callers pass context "floating" and remain WRU/TL-free.
    local result = tinted_primary

    if context == "docked" then
        result = _apply_who_are_you(result, player, context)
        result = _apply_true_level(result, player, prof, context)
    end

    return result
end

----------------------------------------------------------------
-- Convenience helper for floating/nameplate HUDs
--
-- This now returns EXACTLY the "base, tinted" primary name:
--   • glyph + name, if icon0 mode is active,
--   • slot-coloured via _colored_markup(...),
--   • with a WHITE_TAG sentinel at the end of the primary segment,
--   • and NO WRU / True Level additions.
----------------------------------------------------------------
function Name.default(player)
    local prof = _safe_profile(player)
    local tint = nil

    if type(mod.team_slot_tint_argb) == "function" then
        -- marker is nil here; we only care about the player slot index
        tint = mod.team_slot_tint_argb(player, nil)
    end

    local primary_plain = _build_primary_plain(player, prof, nil)

    -- Floating/nameplate use: no WRU/TL; just base tinted primary.
    return _colored_markup(primary_plain, tint)
end

-- Back-compat alias on mod.*
mod.team_name = Name

return Name
