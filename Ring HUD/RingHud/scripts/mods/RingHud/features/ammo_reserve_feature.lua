-- File: RingHud/scripts/mods/RingHud/features/ammo_reserve_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local RingHudUtils       = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local U                  = RingHudUtils
local AmmoReserveFeature = {}

-- NOTE: 1.10+ path (correct): "scripts/network_lookup/network_constants"
local NetworkConstants   = require("scripts/network_lookup/network_constants")

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

        local max_size       = NetworkConstants
            and NetworkConstants.ammunition_reserve_array
            and NetworkConstants.ammunition_reserve_array.max_size
            or nil

        -- Use centralized helper from utils
        current_reserve      = U.sum_ammo_field(raw_current, max_size)
        max_reserve          = U.sum_ammo_field(raw_max, max_size)
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

----------------------------------------------------------------
-- RESERVE TEXT: computed only from hud_state.ammo_data (secondary slot).
-- All context rules (recent change, force-show, thresholds, latches)
-- live in context/ammo_visibility.lua via mod.ammo_vis_player(hud_state).
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

    -- Detect local reserve changes → bump recent-change timer in the visibility module
    if hud_element then
        local prev = hud_element._ammo_prev_reserve
        if prev ~= nil and prev ~= cur_reserve then
            if mod.ammo_vis_player_recent_change_bump then
                mod.ammo_vis_player_recent_change_bump()
            end
        end
        hud_element._ammo_prev_reserve = cur_reserve
    end

    -- Compute fraction safely (nil indicates infinite/unknown to the vis module)
    local reserve_frac    = has_finite and math.clamp(cur_reserve / max_reserve, 0, 1) or nil
    local reserve_actual  = cur_reserve

    -- Ask the central visibility module if we should show (pure policy call).
    local show_text_final = false
    if mod.ammo_vis_player then
        show_text_final = mod.ammo_vis_player(hud_state)
    end

    -- If hidden, clear and bail
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

    -- Visible: choose value format (percent vs actual) from dropdown
    local text_val_final
    if ammo_reserve_dropdown == "ammo_reserve_actual_auto"
        or ammo_reserve_dropdown == "ammo_reserve_actual_always" then
        text_val_final = string.format("%d", reserve_actual)
    else
        -- Default to percent; if reserve_frac is nil (shouldn't be visible then), fall back to 0
        local pct = (reserve_frac or 0) * 100
        text_val_final = string.format(RingHudUtils.percent_num_format, pct)
    end

    -- Style + color thresholds mirror the palette bands
    if text_style then
        changed = U.set_style_visible(text_style, true, changed)

        local color_frac = reserve_frac or 0
        local new_color
        if color_frac >= 0.85 then
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
