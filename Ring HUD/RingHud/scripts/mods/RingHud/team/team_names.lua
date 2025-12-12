-- File: RingHud/scripts/mods/RingHud/team/team_names.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public API (cross-file)
mod.team_names   = mod.team_names or {}
local Name       = mod.team_names

local UISettings = require("scripts/settings/ui/ui_settings")

-- WRU Icons Cache
local WRU_ICONS  = {
    steam = "\xEE\x81\xAB",
    xbox = "\xEE\x81\xAC",
    psn = "\xEE\x81\xB1",
    ps5 = "\xEE\x81\xB1",
    unknown = "\xEE\x81\xAF"
}

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

local function _manual_wru_modify(wru, name, account_name, account_id, ref)
    if not (wru and wru.get) then return name end

    -- Helpers local to this scope
    local function _is_myself(chk_id)
        local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
        local player_account_id = player and player:account_id()
        return chk_id == player_account_id
    end

    local function _format_inline_code(property, value)
        return string.format("{#%s(%s)}", property, value)
    end

    local function _apply_style(n, r)
        local suffix = ""
        if r and wru:get("enable_override_" .. r) then
            suffix = "_" .. r
        end

        n = string.format(" (%s){#reset()}", n)

        if wru:get("enable_custom_size" .. suffix) then
            local size = wru:get("sub_name_size" .. suffix)
            n = _format_inline_code("size", size) .. n
        end

        if wru:get("enable_custom_color" .. suffix) then
            local custom_color = wru:get("custom_color" .. suffix)
            if custom_color and Color[custom_color] then
                local c = Color[custom_color](255, true)
                local rgb = string.format("%s,%s,%s", c[2], c[3], c[4])
                n = _format_inline_code("color", rgb) .. n
            end
        end
        return n
    end

    local display_style = wru.current_style or wru:get("display_style")
    local icon_style = wru:get("platform_icon")
    local prefix = ""

    for _, icon in pairs(WRU_ICONS) do
        if string.match(account_name, icon) then
            prefix = icon .. " "
            break
        end
    end

    if icon_style == "off" then
        account_name = string.gsub(account_name, prefix, "")
    elseif icon_style == "character_only" then
        account_name = string.gsub(account_name, prefix, "")
        name = prefix .. name
    end

    if display_style == "character_only" or (not wru:get("enable_display_self") and _is_myself(account_id)) then
        name = name
    elseif display_style == "account_only" then
        name = account_name
    elseif display_style == "character_first" then
        name = name .. _apply_style(account_name, ref)
    elseif display_style == "account_first" then
        name = account_name .. _apply_style(name, ref)
    end

    return name
end

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
        -- WRU defines account_name on the mod object, but logic suggests passing id.
        local ok_ac, result = pcall(wru.account_name, account_id)
        if ok_ac and type(result) == "string" and result ~= "" then
            account_name = result
        end
    end

    -- Prevent crash: WRU requires a valid account_name string to perform matching.
    if not account_name then
        return base
    end

    -- Use our internal manual formatter to ensure it works even if WRU api is private
    local ok_fmt, modified = pcall(_manual_wru_modify, wru, base, account_name, account_id, "team_panel")
    if ok_fmt and type(modified) == "string" and modified ~= "" then
        return modified
    end

    return base
end

----------------------------------------------------------------
-- True Level integration (dock-only, opt-in per context)
----------------------------------------------------------------

-- [NEW] Manual TL formatter to meet specific constraints:
-- 1. Format/tint true level number (as per TL settings).
-- 2. If havoc > 0, append "." + havoc, same tint as havoc.
-- 3. No spaces between level, dot, havoc.
-- 4. No glyphs.
local function _manual_tl_modify(tl, base, character_id, ref)
    if not (tl and tl.get_true_levels) then return base end

    local ok, true_levels = pcall(tl.get_true_levels, character_id)
    if not (ok and true_levels) then return base end

    -- Helper to resolve TL settings (handles boolean/"on" logic)
    local function get_tl_setting(key)
        local val = tl:get(key .. "_" .. ref)
        local global = tl:get(key)

        if val == "use_global" then
            val = global
        elseif type(global) == "boolean" then
            if val == "on" then
                val = true
            elseif val == "off" then
                val = false
            end
        end
        return val
    end

    local function apply_tl_color(text, color_name)
        if not color_name or color_name == "default" or not Color[color_name] then
            return string.format("{#color(255,255,255)}%s{#reset()}", text)
        end

        local c = Color[color_name](255, true)
        if not c then
            return string.format("{#color(255,255,255)}%s{#reset()}", text)
        end

        return string.format("{#color(%d,%d,%d)}%s{#reset()}", c[2], c[3], c[4], text)
    end

    -- 1. Level Number
    local display_style = get_tl_setting("display_style")
    local lvl_str = ""

    if display_style == "total" and true_levels.true_level then
        lvl_str = tostring(true_levels.true_level)
    elseif display_style == "separate" and true_levels.additional_level then
        lvl_str = string.format("%s (+%s)", true_levels.current_level, true_levels.additional_level)
    else
        lvl_str = tostring(true_levels.current_level)
    end

    local lvl_color = get_tl_setting("level_color")
    lvl_str = apply_tl_color(lvl_str, lvl_color)

    -- 2. Havoc Rank
    local havoc_str = ""
    local enable_havoc = get_tl_setting("enable_havoc_rank")
    -- Resolve enable_havoc (boolean or string)
    if enable_havoc == true or enable_havoc == "on" then
        local rank = true_levels.havoc_rank
        if rank and rank > 0 then
            local content = "." .. tostring(rank)
            local h_color = get_tl_setting("havoc_rank_color")
            havoc_str = apply_tl_color(content, h_color)
        end
    end

    -- 3. Assembly
    -- "No spaces between the true level, the "." and the havoc rank"
    local full_tl = lvl_str .. havoc_str

    if full_tl ~= "" then
        -- Separator between Name and TL.
        return base .. " " .. full_tl
    end

    return base
end

local function _apply_true_level(base, player, profile, context)
    if not base or base == "" then return base end
    if context ~= "docked" then return base end
    if type(get_mod) ~= "function" then return base end

    local tl = get_mod("true_level")
    if not tl then return base end

    local char_id = profile and profile.character_id
    if not char_id then return base end

    -- Use custom formatter (ignores tl.replace_level)
    local ok, res = pcall(_manual_tl_modify, tl, base, char_id, "team_panel")
    if ok and res then
        return res
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
        return text
    end

    local r = t[2] or 255
    local g = t[3] or 255
    local b = t[4] or 255

    -- Layout: {#color(r,g,b)} PRIMARY {#color(255,255,255)}{#reset()}
    return string.format("{#color(%d,%d,%d)}%s%s{#reset()}", r, g, b, text, WHITE_TAG)
end

----------------------------------------------------------------
-- Primary-name builder
----------------------------------------------------------------

local function _build_primary_plain(player, profile, optional_prefix)
    local prof   = profile or _safe_profile(player)
    local name   = _default_character_name(player, prof)

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
----------------------------------------------------------------
function Name.compose(player, profile, tint_argb255, seeded_text, optional_prefix, context_or_opts)
    -- Decode optional context
    local context = nil
    if type(context_or_opts) == "string" then
        context = context_or_opts
    elseif type(context_or_opts) == "table" then
        context = context_or_opts.context or context_or_opts.ref
    end

    local primary_plain, prof = _build_primary_plain(player, profile, optional_prefix)

    -- Step 1: base, slot-tinted primary name (glyph + name), with WHITE_TAG
    -- marking the end of the primary segment.
    local tinted_primary = _colored_markup(primary_plain, tint_argb255)

    -- Step 2: docked tiles get WRU/TL applied on top of the tinted primary.
    local result = tinted_primary

    if context == "docked" then
        -- [NEW] For docked mode, re-apply the slot tint after the primary block.
        -- This ensures default-colored text from WRU/TL inherits the slot tint.
        if tint_argb255 and type(tint_argb255) == "table" then
            local r = tint_argb255[2] or 255
            local g = tint_argb255[3] or 255
            local b = tint_argb255[4] or 255
            result = result .. string.format("{#color(%d,%d,%d)}", r, g, b)
        end

        result = _apply_who_are_you(result, player, context)
        result = _apply_true_level(result, player, prof, context)

        -- [NEW] Close any open color tags from our re-application
        if tint_argb255 then
            result = result .. "{#reset()}"
        end
    end

    return result
end

----------------------------------------------------------------
-- Convenience helper for floating/nameplate HUDs
----------------------------------------------------------------
function Name.default(player)
    local prof = _safe_profile(player)
    local tint = nil

    if type(mod.team_slot_tint_argb) == "function" then
        tint = mod.team_slot_tint_argb(player, nil)
    end

    local primary_plain = _build_primary_plain(player, prof, nil)

    return _colored_markup(primary_plain, tint)
end

-- Back-compat alias on mod.*
mod.team_name = Name

return Name
