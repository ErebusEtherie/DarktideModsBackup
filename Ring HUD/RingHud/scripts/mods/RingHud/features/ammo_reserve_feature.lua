-- File: RingHud/scripts/mods/RingHud/features/ammo_reserve_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local RingHudUtils           = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local U                      = RingHudUtils
local AmmoReserveFeature     = {}

-- NOTE: 1.10+ path (correct): "scripts/network_lookup/network_constants"
local NetworkConstants       = require("scripts/network_lookup/network_constants")

local MAX_AMMO_RESERVE_SIZE  = NetworkConstants
    and NetworkConstants.ammunition_reserve_array
    and NetworkConstants.ammunition_reserve_array.max_size
    or nil

local COLOR_DEFAULT_CRITICAL = { 255, 255, 0, 0 }
local COLOR_FORECAST_DIM     = { 180, 100, 100, 100 }

local WASTAGE_MODES          = {
    ammo_reserve_disabled        = "disabled",
    ammo_reserve_percent_auto    = "percent",
    ammo_reserve_percent_always  = "percent",
    ammo_reserve_actual_auto     = "actual",
    ammo_reserve_actual_always   = "actual",
    ammo_reserve_forecast_auto   = "forecast",
    ammo_reserve_forecast_always = "forecast",
}

----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------
local function _wastage_mode_from_dropdown(dropdown)
    if not dropdown then
        return "disabled"
    end
    local mode = WASTAGE_MODES[dropdown]
    if mode then
        return mode
    end
    return "disabled"
end

local function _wastage_color_for_mode(mode)
    local palette = mod.PALETTE_ARGB255
    local c = palette.AMMO_TEXT_COLOR_CRITICAL or COLOR_DEFAULT_CRITICAL
    -- Forecast mode without forecast data: de-emphasize (matches reserve-text behavior)
    if mode == "forecast" and mod.ammo_reserve_has_forecast_data == false then
        c = COLOR_FORECAST_DIM
    end
    return c
end

local function _format_wastage_suffix(value_str, color_argb255)
    if not value_str or value_str == "" then
        return nil
    end

    local c = color_argb255 or COLOR_DEFAULT_CRITICAL
    local r, g, b = c[2] or 255, c[3] or 255, c[4] or 255
    return string.format(" {#color(%d,%d,%d)}(-%s){#reset()}", r, g, b, value_str)
end

----------------------------------------------------------------
-- STATE (reserve): read from unit_data (secondary slot)
-- into hud_state.ammo_data
----------------------------------------------------------------
function AmmoReserveFeature.update_state(unit_data_comp_access_point, ammo_data)
    if not (unit_data_comp_access_point and ammo_data) then return end

    local secondary_comp       = unit_data_comp_access_point:read_component("slot_secondary")
    local current_reserve      = 0
    local max_reserve          = 0
    local has_infinite_reserve = false

    if secondary_comp then
        local raw_current    = secondary_comp.current_ammunition_reserve
        local raw_max        = secondary_comp.max_ammunition_reserve

        current_reserve      = U.sum_ammo_field(raw_current, MAX_AMMO_RESERVE_SIZE)
        max_reserve          = U.sum_ammo_field(raw_max, MAX_AMMO_RESERVE_SIZE)
        has_infinite_reserve = (max_reserve == 0)
    end

    ammo_data.current_reserve      = current_reserve
    ammo_data.max_reserve          = max_reserve
    ammo_data.has_infinite_reserve = has_infinite_reserve
end

-- Expose helper on the mod namespace for RingHud_state_player.lua to call
mod.ammo_reserve_update_state = function(unit_data_comp_access_point, ammo_data)
    return AmmoReserveFeature.update_state(unit_data_comp_access_point, ammo_data)
end

do
    local _tmp = { current_reserve = 0, max_reserve = 0, has_infinite_reserve = false }

    mod.ammo_reserve_read_secondary_reserve = function(unit_data_comp_access_point)
        if not unit_data_comp_access_point then
            return 0, 0, true
        end

        AmmoReserveFeature.update_state(unit_data_comp_access_point, _tmp)
        return _tmp.current_reserve or 0, _tmp.max_reserve or 0, _tmp.has_infinite_reserve == true
    end
end

----------------------------------------------------------------
-- WASTAGE CALCULATION (for interaction popups)
--
-- Input:
--   cur_reserve:    current reserve bullets (secondary slot)
--   max_reserve:    max reserve bullets (secondary slot)
--   offer_bullets:  bullets offered by pickup/deployable (already includes diff_ammo_mod)
--   dropdown:       ammo_reserve_dropdown (passed in by caller)
--   offer_fraction: OPTIONAL fraction of reserve offered (already includes diff_ammo_mod),
--                  used for percent mode to avoid bullet rounding issues
--
-- Output:
--   full colored suffix INCLUDING leading space, e.g:
--     " {#color(r,g,b)}(-12%){#reset()}"
--     " {#color(r,g,b)}(-34){#reset()}"
--   or nil if no wastage / disabled / infinite / invalid
----------------------------------------------------------------
function AmmoReserveFeature.wastage_string_for_offer(cur_reserve, max_reserve, offer_bullets, dropdown, offer_fraction)
    local mode = _wastage_mode_from_dropdown(dropdown)
    if mode == "disabled" then
        return nil
    end

    cur_reserve   = tonumber(cur_reserve) or 0
    max_reserve   = tonumber(max_reserve) or 0
    offer_bullets = tonumber(offer_bullets) or 0
    -- infite ammo
    if max_reserve <= 0 then
        return nil
    end

    -- full ammo
    if cur_reserve >= max_reserve then
        return nil
    end

    -- nothing offered => nothing to waste
    if offer_bullets <= 0 then
        return nil
    end

    local color = _wastage_color_for_mode(mode)

    if mode == "percent" then
        local reserve_frac = math.clamp(cur_reserve / max_reserve, 0, 1)

        local offer_frac = tonumber(offer_fraction)
        if not offer_frac then
            offer_frac = offer_bullets / max_reserve
        end
        offer_frac = math.max(0, offer_frac)

        local waste_frac = (reserve_frac + offer_frac) - 1
        if waste_frac <= 0 then
            return nil
        end

        local waste_pct = U.round_int(waste_frac * 100)
        if waste_pct <= 0 then
            return nil
        end

        if waste_pct > 999 then waste_pct = 999 end

        return _format_wastage_suffix(string.format("%d%%", waste_pct), color)
    end

    -- For actual/forecast, compute wasted reserve bullets if taking the pickup now
    local waste_bullets = (cur_reserve + offer_bullets) - max_reserve
    if waste_bullets <= 0 then
        return nil
    end

    waste_bullets = math.floor(waste_bullets)

    if mode == "actual" then
        return _format_wastage_suffix(string.format("%d", math.max(0, waste_bullets)), color)
    elseif mode == "forecast" then
        local shot_cost = tonumber(mod.ammo_reserve_last_shot_cost) or 0
        if shot_cost <= 0 then shot_cost = 1 end

        local waste_shots = math.ceil(waste_bullets / shot_cost)
        if waste_shots <= 0 then
            return nil
        end

        return _format_wastage_suffix(string.format("%d", waste_shots), color)
    end

    return nil
end

mod.ammo_reserve_wastage_string_for_offer = function(cur_reserve, max_reserve, offer_bullets, dropdown, offer_fraction)
    return AmmoReserveFeature.wastage_string_for_offer(cur_reserve, max_reserve, offer_bullets, dropdown, offer_fraction)
end

----------------------------------------------------------------
-- RESERVE TEXT
----------------------------------------------------------------
function AmmoReserveFeature.update_text(hud_element, widget, hud_state, _hotkey_override_unused)
    if not widget or not widget.style then return end

    local content               = widget.content
    local text_style            = widget.style.reserve_text_style
    local changed               = false

    local ammo_reserve_dropdown = mod._settings.ammo_reserve_dropdown

    local data                  = hud_state and hud_state.ammo_data or {}
    local max_reserve           = data.max_reserve or 0
    local cur_reserve           = data.current_reserve or 0
    local has_finite            = max_reserve > 0

    local mode_type             = WASTAGE_MODES[ammo_reserve_dropdown]
    local is_forecast_mode      = (mode_type == "forecast")

    local shot_cost             = hud_state.most_recent_shot_cost_this_mission or 0
    local has_forecast_data     = (shot_cost > 0)

    if not has_forecast_data then shot_cost = 1 end

    mod.ammo_reserve_last_shot_cost = shot_cost
    mod.ammo_reserve_has_forecast_data = has_forecast_data

    if hud_element then
        local prev = hud_element._ammo_prev_reserve
        if prev ~= nil and prev ~= cur_reserve then
            if mod.ammo_vis_player_recent_change_bump then
                mod.ammo_vis_player_recent_change_bump()
            end
        end
        hud_element._ammo_prev_reserve = cur_reserve
    end

    local reserve_frac    = has_finite and math.clamp(cur_reserve / max_reserve, 0, 1) or nil
    local reserve_actual  = cur_reserve

    local show_text_final = false
    if mod.ammo_vis_player then
        show_text_final = mod.ammo_vis_player(hud_state)
    end

    if not show_text_final then
        if text_style then
            changed = U.set_style_visible(text_style, false, changed)
        end
        if content.reserve_text_value ~= "" then
            content.reserve_text_value = ""
            changed = true
        end
        if changed then widget.dirty = true end
        return
    end

    local text_val_final
    if is_forecast_mode then
        local shots_remaining = reserve_actual / shot_cost
        text_val_final = string.format("%d", math.ceil(shots_remaining))
    elseif mode_type == "actual" then
        text_val_final = string.format("%d", reserve_actual)
    else
        local pct = (reserve_frac or 0) * 100
        text_val_final = string.format(RingHudUtils.percent_num_format, pct)
    end

    if text_style then
        changed = U.set_style_visible(text_style, true, changed)

        local color_frac = reserve_frac or 0
        local new_color

        if is_forecast_mode and not has_forecast_data then
            new_color = COLOR_FORECAST_DIM
        elseif color_frac >= 0.85 then
            new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH
        elseif color_frac >= 0.65 then
            new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H
        elseif color_frac >= 0.45 then
            new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
        elseif color_frac >= 0.25 then
            new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW
        else
            new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL
        end

        if U.set_style_text_color(text_style, new_color) then
            changed = true
        end
    end

    if content.reserve_text_value ~= text_val_final then
        content.reserve_text_value = text_val_final
        changed = true
    end

    if changed then widget.dirty = true end
end

return AmmoReserveFeature
