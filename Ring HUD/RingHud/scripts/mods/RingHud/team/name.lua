-- File: RingHud/scripts/mods/RingHud/team/name.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Bridges (optional; all calls guarded with pcall)
local TLBridge  = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/true_level_bridge")
local WRYBridge = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/who_are_you_bridge")

local Name      = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local WHITE     = { 255, 255, 255, 255 } -- {a,r,g,b}

local function _slot_tinted_markup(text, tint_argb255)
    local r = (tint_argb255 and tint_argb255[2]) or 255
    local g = (tint_argb255 and tint_argb255[3]) or 255
    local b = (tint_argb255 and tint_argb255[4]) or 255
    return string.format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, tostring(text or ""))
end

local function _rgba255_markup(text, argb255)
    if not argb255 or type(argb255) ~= "table" then return tostring(text or "") end
    local r = argb255[2] or 255
    local g = argb255[3] or 255
    local b = argb255[4] or 255
    return string.format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, tostring(text or ""))
end

local function _open_rgb255(argb255_or_r, g, b)
    if type(argb255_or_r) == "table" then
        return string.format("{#color(%d,%d,%d)}", argb255_or_r[2] or 255, argb255_or_r[3] or 255, argb255_or_r[4] or 255)
    else
        return string.format("{#color(%d,%d,%d)}", argb255_or_r or 255, g or 255, b or 255)
    end
end

local function _profile_name_or(player, profile, fallback)
    if profile and profile.name and profile.name ~= "" then
        return profile.name
    end
    if player then
        local ok, nm = pcall(function() return player:name() end)
        if ok and nm and nm ~= "" then
            return nm
        end
    end
    return fallback
end

local function _peer_id_of(player)
    if not player then return nil end
    local ok, pid = pcall(function() return player.peer_id and player:peer_id() end)
    if ok and pid then return tostring(pid) end
    local raw = rawget(player, "peer_id")
    if raw ~= nil then return tostring(raw) end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Spare slot-tint allocator (used only when the game fails to give a valid tint)
-- ─────────────────────────────────────────────────────────────────────────────
-- Palette names are the standard Darktide slot colors (from Color[])
local _palette_names = { "player_1", "player_2", "player_3", "player_4" }

local function _copy_argb(v)
    return { v[1], v[2], v[3], v[4] }
end

local function _color_from_name(name)
    if not (name and Color and Color[name]) then return nil end
    local v = Color[name](255, true) -- {a,r,g,b}
    return _copy_argb(v)
end

-- Normalize to an "rgb key" string for set membership ("r,g,b")
local function _rgb_key(argb)
    if not argb then return "nil" end
    return string.format("%d,%d,%d", argb[2] or 0, argb[3] or 0, argb[4] or 0)
end

-- Consider a tint invalid if it's missing or effectively black (vanilla fallback)
local function _is_bad_tint(t)
    if not t or type(t) ~= "table" then return true end
    local r, g, b = t[2] or 0, t[3] or 0, t[4] or 0
    return (r == 0 and g == 0 and b == 0)
end

-- Frame/epoch-scoped registry of which RGBs we've handed out in recent composes.
-- This avoids duplicates when multiple slots lost their tint at once.
Name._alloc_epoch_t  = Name._alloc_epoch_t or 0
Name._alloc_used_rgb = Name._alloc_used_rgb or {} -- set of "r,g,b" -> true

local function _ui_now()
    local MT = Managers and Managers.time
    return (MT and MT.time and (MT:time("ui") or MT:time("gameplay"))) or os.clock()
end

local function _maybe_reset_epoch()
    local now = _ui_now()
    if (now - (Name._alloc_epoch_t or 0)) > 0.05 then
        Name._alloc_used_rgb = {}
        Name._alloc_epoch_t  = now
    end
end

local function _allocate_spare_tint(avoid_rgb_set)
    -- Build candidate palette once
    local candidates = {}
    for i = 1, #_palette_names do
        local c = _color_from_name(_palette_names[i])
        if c then candidates[#candidates + 1] = c end
    end
    -- Choose the first not already used
    for _, c in ipairs(candidates) do
        local key = _rgb_key(c)
        if not avoid_rgb_set[key] then
            avoid_rgb_set[key] = true
            return c
        end
    end
    -- If all are used, just return white as a safe, readable default
    return WHITE
end

-- Called by composer when incoming tint is bad; tries to avoid duplicates this frame
local function _effective_slot_tint_or_spare(bad_or_nil_tint)
    _maybe_reset_epoch()
    local used = Name._alloc_used_rgb

    if not _is_bad_tint(bad_or_nil_tint) then
        -- Mark the legit tint as used for this epoch and return it
        used[_rgb_key(bad_or_nil_tint)] = true
        return bad_or_nil_tint
    end

    -- Allocate a spare from the palette, skipping already-used ones
    local spare = _allocate_spare_tint(used)
    return spare
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Compose a teammate-name line.
-- Policy:
--   • Tint PRIMARY (incl. platform glyph) with slot tint; if tint is bad, allocate a spare.
--   • Secondary stays WRU-styled; reopen WHITE after primary so it doesn’t inherit.
--   • Append TL " <true>[.<havoc>]" with per-element colors (white by default).
--   • If no WRU/TL, fall back to slot-tinted plain name (or spare).
-- ─────────────────────────────────────────────────────────────────────────────
function Name.compose(player, profile, tint_argb255, seeded_text)
    -- 0) Caller-provided composite (e.g., floating precompute)
    if seeded_text and seeded_text ~= "" then
        return tostring(seeded_text)
    end

    -- Resolve a robust slot tint first (actual or spare if the game failed us)
    local slot_tint = _effective_slot_tint_or_spare(tint_argb255)

    ----------------------------------------------------------------
    -- 1) Build base name (prefer WRU parts so we can tint PRIMARY only)
    ----------------------------------------------------------------
    local base = nil

    if WRYBridge then
        -- Prefer parts so we can isolate primary/secondary
        if WRYBridge.parts_for_player then
            local ok, parts = pcall(WRYBridge.parts_for_player, player)
            if ok and parts then
                local primary        = parts.primary or _profile_name_or(player, profile, "?")
                local secondary      = parts.secondary_styled or ""

                -- Slot-tint the PRIMARY (incl. platform glyph if WRU puts it here)
                local tinted_primary = _slot_tinted_markup(primary, slot_tint)

                -- Re-open WHITE so any uncolored text after primary doesn't inherit the slot tint.
                base                 = tinted_primary .. _open_rgb255(WHITE) .. secondary
            end
        end

        -- If parts path failed, try compose_team_panel_name (already styled by WRU).
        if (not base or base == "") and WRYBridge.compose_team_panel_name then
            local ok, s = pcall(WRYBridge.compose_team_panel_name, player)
            if ok and s and s ~= "" then base = s end
        end

        -- As a last WRU fallback, decorate a plain name.
        if (not base or base == "") and WRYBridge.decorate then
            local plain = _profile_name_or(player, profile, "?")
            local ok, decorated = pcall(WRYBridge.decorate, player, plain)
            if ok and decorated and decorated ~= "" then base = decorated end
        end
    end

    -- No WRU → tint the plain name as our "primary".
    if not base or base == "" then
        base = _slot_tinted_markup(_profile_name_or(player, profile, "?"), slot_tint) .. _open_rgb255(WHITE)
    end

    local out = base

    ----------------------------------------------------------------
    -- 2) True Level suffix — per-element coloring
    ----------------------------------------------------------------
    if TLBridge and TLBridge.available and TLBridge.available() then
        local pid = _peer_id_of(player)
        if pid and TLBridge.peer_info then
            local ok, info = pcall(TLBridge.peer_info, pid)
            if ok and type(info) == "table" and info.true_level then
                local lvl       = tonumber(info.true_level) or 0
                local hvk       = tonumber(info.havoc_rank or 0) or 0
                local lvl_col   = info.level_color_argb255
                local hvk_col   = info.havoc_color_argb255

                -- Level: explicit WHITE if no TL color, so it never inherits slot tint
                local level_txt = (lvl_col and _rgba255_markup(tostring(lvl), lvl_col))
                    or _rgba255_markup(tostring(lvl), WHITE)

                -- Dot: match what follows (prefer havoc), else level, else WHITE
                local dot_txt   = "."
                if hvk > 0 then
                    local dot_col = hvk_col or lvl_col or WHITE
                    dot_txt = _rgba255_markup(".", dot_col)
                elseif lvl_col then
                    dot_txt = _rgba255_markup(".", lvl_col)
                else
                    dot_txt = _rgba255_markup(".", WHITE)
                end

                -- Havoc
                local havoc_txt = ""
                if hvk > 0 then
                    havoc_txt = (hvk_col and _rgba255_markup(tostring(hvk), hvk_col))
                        or _rgba255_markup(tostring(hvk), WHITE)
                end

                local suffix = " " .. level_txt
                if hvk > 0 then
                    suffix = suffix .. dot_txt .. havoc_txt
                end

                out = out .. suffix
            end
        end
        -- If TL is available but no data for this peer yet, keep 'out' as-is (base).
    end

    -- Hard end reset so later UI doesn’t inherit our colors
    if not out:find("{#reset()}%s*$") then
        out = out .. "{#reset()}"
    end

    return out ~= "" and out or "?"
end

-- Also expose via mod.* for convenience in call-sites that prefer that style.
mod.team_name = Name

return Name
