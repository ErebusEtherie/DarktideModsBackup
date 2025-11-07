local mod = get_mod("helbore_passive_charge")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local color_enabled = { 255, 255, 255, 255 }
local color_disabled = { 160, 160, 160, 160 }

local ui_definitions = {
    scenegraph_definition = {
        screen = UIWorkspaceSettings.screen,
        charge_container = {
            parent = "screen",
            vertical_alignment = "bottom",
            horizontal_alignment = "right",
            size = { 30, 30 },
            position = {
                -380,
                -80,
                10
            }
        }
    },
    widget_definitions = {
        charge = UIWidget.create_definition({
            {
                style_id = "icon",
                value_id = "icon",
                pass_type = "texture",
                value = "content/ui/materials/icons/presets/preset_11",
                style = {
                    size = {nil, nil},
                }
            }
        }, "charge_container")
    }
}

local HudElementCharge = class("HudElementCharge", "HudElementBase")

HudElementCharge.init = function(self, parent, draw_layer, start_scale)
   -- mod:debug("Initializing hud element")
    HudElementCharge.super.init(self, parent, draw_layer, start_scale, ui_definitions)
end

HudElementCharge.set_enabled = function(self, enabled)
    self._widgets_by_name.charge.style.icon.visible = enabled
end

HudElementCharge.set_active = function(self, active)
    self._widgets_by_name.charge.style.icon.color = active and color_enabled or color_disabled
end

HudElementCharge.set_side_length = function(self, side_length)
    local widget_size = self._widgets_by_name.charge.style.icon.size
    widget_size[1] = side_length
    widget_size[2] = side_length
end

return HudElementCharge
