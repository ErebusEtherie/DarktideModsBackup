-- File: Targeter/scripts/mods/Targeter/core/ui.lua
-- Crosshair coloring and peril/heat tinting. Pointer cached/cleared here.

local mod = get_mod("Targeter")
if not mod then return end

local ColorUtilities = require("scripts/utilities/ui/colors")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")

local ColorUtilities_color_copy = ColorUtilities.color_copy
local math_max = math.max
local string_sub = string.sub

local peril_color_steps = { 0.2125, 0.425, 0.6375, 0.834, 0.984, 1.0 }
local peril_color_spectrum = {
    { 200, 138, 201, 38 }, { 200, 138, 201, 38 }, { 255, 255, 202, 58 },
    { 255, 255, 146, 76 }, { 255, 255, 89, 94 }, { 255, 244, 121, 229 },
    { 255, 244, 50, 229 },
}
local NUM_PERIL_STEPS = 6
local NUM_PERIL_SPECTRUM = 7

local PERIL_CROSSHAIRS = {
    charge_up_peril = true,
    charge_up_ads_peril = true,
    charge_up_peril_larger_dot = true,
    charge_up_ads_peril_larger_dot = true,
}

local function _read_overheat(unit_data, slot_name)
    if not slot_name then return 0 end
    local c = unit_data:read_component(slot_name)
    if not c then return 0 end
    local v = c.overheat_current_percentage or c.overheat_current_percent
    if type(v) == "table" then v = v[1] end
    if type(v) == "number" then return v end
    return 0
end

mod:hook_safe(CLASS.HudElementCrosshair, "update", function(self, dt, t, ui_renderer, render_settings, input_service)
    if not mod.crosshair_ui_hud then
        mod.crosshair_ui_hud = self._parent
    end

    mod._last_t = t

    local widget = self._widget
    local style_table = widget and widget.style
    if not style_table then return end

    local base_definition = self._crosshair_widget_definitions and
        self._crosshair_widget_definitions[self._crosshair_type]
    if not base_definition then return end

    local state_key = mod.crosshair_state or "default"
    local color_to_apply = (mod.color_types and mod.color_types[state_key]) or nil
    local base_style_table = base_definition.style

    for part_name, style in pairs(style_table) do
        if string_sub(part_name, 1, 4) ~= "hit_" then
            local base_style = base_style_table[part_name]
            local base_color = base_style and base_style.color
            if color_to_apply then
                ColorUtilities_color_copy(color_to_apply, style.color)
            elseif base_color then
                ColorUtilities_color_copy(base_color, style.color)
            end
        end
    end

    local ct = self._crosshair_type
    if PERIL_CROSSHAIRS[ct] then
        local current_peril_fraction = 0
        local player_extensions = mod.crosshair_ui_hud and mod.crosshair_ui_hud:player_extensions()

        if player_extensions and player_extensions.unit_data then
            local unit_data = player_extensions.unit_data

            local warp_charge_comp = unit_data:read_component("warp_charge")
            local warp_val = (warp_charge_comp and warp_charge_comp.current_percentage) or 0
            local warp_level = (type(warp_val) == "table" and warp_val[1]) or (type(warp_val) == "number" and warp_val) or
                0

            local overheat_level = 0
            local inv_comp = unit_data:read_component("inventory")
            if inv_comp then
                local wielded = inv_comp.wielded_slot
                if wielded and wielded ~= "none" then
                    local slot_cfg = PlayerCharacterConstants.slot_configuration and
                        PlayerCharacterConstants.slot_configuration[wielded]
                    if slot_cfg and slot_cfg.slot_type == "weapon" then
                        overheat_level = math_max(overheat_level, _read_overheat(unit_data, wielded))
                    end
                end
                overheat_level = math_max(overheat_level, _read_overheat(unit_data, "slot_primary"))
                overheat_level = math_max(overheat_level, _read_overheat(unit_data, "slot_secondary"))
            end

            current_peril_fraction = math_max(warp_level, overheat_level)
        end

        if current_peril_fraction > 0 then
            local peril_color = peril_color_spectrum[1]
            for i = 1, NUM_PERIL_STEPS do
                if current_peril_fraction < peril_color_steps[i] then
                    peril_color = peril_color_spectrum[i]
                    break
                elseif i == NUM_PERIL_STEPS and current_peril_fraction >= peril_color_steps[i] then
                    peril_color = peril_color_spectrum[NUM_PERIL_SPECTRUM]
                    break
                end
            end

            if style_table.charge_mask_left then
                ColorUtilities_color_copy(peril_color, style_table.charge_mask_left.color)
            end
            if style_table.charge_mask_right then
                ColorUtilities_color_copy(peril_color, style_table.charge_mask_right.color)
            end
        end
    end
end)

mod:hook_safe(CLASS.HudElementCrosshair, "destroy", function(self)
    mod.crosshair_ui_hud = nil
end)
