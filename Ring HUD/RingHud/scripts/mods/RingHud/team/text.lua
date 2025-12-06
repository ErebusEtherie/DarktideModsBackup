-- File: RingHud/scripts/mods/RingHud/team/text.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Centralised colours (RingHud_colors.lua)
local Colors = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
-- Team constants (kept for non-centralised items like ability text colour)
local C      = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")

-- Visibility gates
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V                             = mod.team_visibility

local PlayerUnitStatus              = require("scripts/utilities/attack/player_unit_status")

local TXT                           = {}

-- Weak tables keyed by widget so we don’t leak across lifetimes
local _prev_reserve_by_widget       = setmetatable({}, { __mode = "k" })
local _reserve_show_until_by_widget = setmetatable({}, { __mode = "k" })

local function _now()
    if Application and Application.time_since_launch then
        return Application.time_since_launch()
    end
    local t = (Managers.time and (Managers.time:time("ui") or Managers.time:time("gameplay") or Managers.time:time("main"))) or
        os.clock()
    return t or 0
end

local function _local_player_is_dead_fallback()
    -- Use Managers.player:local_player_safe(1) per your rule
    local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not (unit and Unit.alive(unit)) then
        -- If no alive unit, treat as dead for “show teammates” purposes
        return true
    end

    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    local he  = ScriptUnit.has_extension(unit, "health_system") and ScriptUnit.extension(unit, "health_system")
    if uds and he then
        local cs = uds:read_component("character_state")
        return PlayerUnitStatus.is_dead(cs, he)
    end
    return false
end

local function _ads_hotkey_rule_active()
    -- Only relevant when the user’s dropdown is the ADS hotkey mode
    if not (mod._settings and mod._settings.ads_visibility_dropdown == "ads_vis_hotkey") then
        return false
    end
    -- ADS detection (same approach used elsewhere in RingHud)
    local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not unit then return false end
    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    if not uds then return false end
    local alt = uds:read_component("alternate_fire")
    return (alt and alt.is_active) or false
end

local function _hide_reserve(widget)
    local style   = widget and widget.style and widget.style.reserve_text_style
    local content = widget and widget.content
    if not (style and content) then return end
    local changed = false
    if style.visible then
        style.visible = false; changed = true
    end
    if content.reserve_text_value ~= "" then
        content.reserve_text_value = ""; changed = true
    end
    if changed then widget.dirty = true end
end

local function _hide_cd(widget)
    local style   = widget and widget.style and widget.style.ability_cd_text_style
    local content = widget and widget.content
    if not (style and content) then return end
    local changed = false
    if style.visible then
        style.visible = false; changed = true
    end
    if content.ability_cd_text ~= "" then
        content.ability_cd_text = ""; changed = true
    end
    if changed then widget.dirty = true end
end

-- reserve_frac: [0..1] or nil (nil means "not applicable" / infinite reserve)
-- force_show_team: boolean | nil (true when show_all_hud_hotkey is held; ADS does NOT map here)
function TXT.update_ammo(widget, reserve_frac, force_show_team)
    local style   = widget and widget.style and widget.style.reserve_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    -- Team HUD disabled? Bail.
    if (mod._settings and mod._settings.team_hud_mode) == "team_hud_disabled" then
        _hide_reserve(widget)
        return
    end

    -- Always hidden if teammate has infinite reserve / no ammo concept.
    if reserve_frac == nil then
        _hide_reserve(widget)
        return
    end

    -- Can only become visible if the tile itself isn’t disabled.
    -- (Guard against parent gates commonly used in switching/floating modes.)
    if widget.visible == false or content._tile_disabled == true then
        _hide_reserve(widget)
        return
    end

    local munitions_opt = (mod._settings and mod._settings.team_munitions) or "team_munitions_context"
    local f             = math.clamp(reserve_frac or 0, 0, 1)
    local show          = false

    -- Maintain a local “recently changed” window per-widget (10s)
    do
        local prev = _prev_reserve_by_widget[widget]
        if prev == nil or prev ~= f then
            _reserve_show_until_by_widget[widget] = _now() + 10.0
        end
        _prev_reserve_by_widget[widget] = f
    end

    -- Global “always/disabled” still respected
    if munitions_opt == "team_munitions_always" then
        show = true
    elseif munitions_opt == "team_munitions_disabled" then
        show = false
    else
        -- team_munitions_context: apply your full ruleset
        -- Visible if the local player is dead
        local local_dead     =
            (V and V.local_player_is_dead and V.local_player_is_dead())
            or _local_player_is_dead_fallback()

        -- Force show (hotkey)
        local force_show     = (force_show_team == true)
            or (V and V.force_show_requested and V.force_show_requested())

        -- ADS + setting == "ads_vis_hotkey"
        local ads_hotkey     = (V and V.ads_force_rule and V.ads_force_rule()) or _ads_hotkey_rule_active()

        -- Within 10s after any change in that teammate's reserve fraction
        -- Prefer the peer-stable VM value (content._reserve_show_until) if present,
        -- falling back to this widget's local latch. Use the max of both.
        local now            = _now()
        local external_until = tonumber(content._reserve_show_until or 0) or 0
        local internal_until = _reserve_show_until_by_widget[widget] or 0
        local show_until     = (external_until > internal_until) and external_until or internal_until
        local latched        = show_until > now

        -- Proximity-based thresholds (local player's proximity + teammate’s reserve level)
        local near_small     = (mod.near_small_clip == true) and (f < 0.85)
        local near_large     = (mod.near_large_clip == true) and (f < 0.65)
        local near_cache     = (mod.near_ammo_cache_deployable == true) and (f < 0.45)

        -- Reserve < 25% hard threshold
        local hard_low       = (f < 0.25)

        -- Reassurance flag
        local reassure       = (mod.reassure_ammo == true)

        show                 = local_dead
            or force_show
            or ads_hotkey
            or latched
            or near_small
            or near_large
            or near_cache
            or hard_low
            or reassure
    end

    if not show then
        _hide_reserve(widget)
        return
    end

    -- Text value
    local new_text = string.format("%.0f%%", f * 100)

    -- Colour tiers (central palette)
    local new_color =
        (f >= 0.85 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH)
        or (f >= 0.65 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H)
        or (f >= 0.45 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L)
        or (f >= 0.25 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW)
        or mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL

    -- Apply only on change
    local changed = false
    if content.reserve_text_value ~= new_text then
        content.reserve_text_value = new_text
        changed = true
    end

    local tc = style.text_color -- TODO Util? Color?
    if (not tc)
        or tc[1] ~= new_color[1]
        or tc[2] ~= new_color[2]
        or tc[3] ~= new_color[3]
        or tc[4] ~= new_color[4] then
        style.text_color = table.clone(new_color)
        changed = true
    end

    if not style.visible then
        style.visible = true
        changed = true
    end

    if changed then widget.dirty = true end
end

-- seconds: integer seconds remaining
-- Respects counters gate: only shows when "CD" is enabled and seconds > 0
function TXT.update_ability_cd(widget, seconds)
    local style   = widget and widget.style and widget.style.ability_cd_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    -- Gate via V.counters (fallback to settings if V missing)
    local force_show = (V and V.force_show_requested and V.force_show_requested()) or false
    local show_cd    = false
    if V and V.counters then
        local cd = false
        cd = (V.counters(force_show))
        -- V.counters returns two values; handle both cases safely
        if type(cd) == "table" then
            show_cd = cd[1] == true
        else
            local cd_bool, _ = V.counters(force_show)
            show_cd = cd_bool == true
        end
    else
        local v = mod._settings and mod._settings.team_counters or "team_counters_cd"
        show_cd = (v == "team_counters_cd" or v == "team_counters_cd_toughness")
    end

    local s = tonumber(seconds or 0) or 0
    if s <= 0 or not show_cd then
        _hide_cd(widget)
        return
    end

    local new_text  = tostring(s) .. "s"
    local new_color = C.ABILITY_CD_TEXT_COLOR or mod.PALETTE_ARGB255.GENERIC_WHITE

    local changed   = false
    if content.ability_cd_text ~= new_text then
        content.ability_cd_text = new_text
        changed = true
    end

    local tc = style.text_color -- TODO Util? Color?
    if (not tc)
        or tc[1] ~= new_color[1]
        or tc[2] ~= new_color[2]
        or tc[3] ~= new_color[3]
        or tc[4] ~= new_color[4] then
        style.text_color = table.clone(new_color)
        changed = true
    end

    if not style.visible then
        style.visible = true
        changed = true
    end

    if changed then widget.dirty = true end
end

return TXT
