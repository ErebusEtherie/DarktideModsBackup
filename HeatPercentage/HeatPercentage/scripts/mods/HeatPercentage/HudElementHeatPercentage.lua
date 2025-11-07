local mod = get_mod("HeatPercentage")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Crosshair = require("scripts/ui/utilities/crosshair")

local definitions = {
  	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		heat_area  = {
			parent = "screen",
			size = { 300, 100 },
			vertical_alignment = "center",
			horizontal_alignment = "center",
			position = { 0, -190, 5 }
		}
  	},
  	widget_definitions = {
		heat_text = UIWidget.create_definition({
			{
				pass_type = "text",
				value = "",
				value_id = "heat",
				style_id = "heat",
				style = {
					font_type = "machine_medium",
					font_size = 30,
					drop_shadow = true,
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = Color.ui_green_light(255, true),
					offset = { 0, 0, 100 }
				}
			}
		}, "heat_area")
  	}
}

HudElementHeatPercentage = class("HudElementHeatPercentage", "HudElementBase")

function HudElementHeatPercentage:init(parent, draw_layer, start_scale)
  	HudElementHeatPercentage.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementHeatPercentage.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementHeatPercentage.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	local player = Managers.player:local_player(1)
	if not player or not player.player_unit then
		self._widgets_by_name.heat_text.content.heat = ""
		self._widgets_by_name.heat_text.style.heat.font_size = 30
		return
	end
	local buff_extensions = ScriptUnit.extension(player.player_unit, "buff_system")
	local weapon_extension = ScriptUnit.extension(player.player_unit, "weapon_system")
	if not (buff_extensions and weapon_extension) then
		return
	end
	local current_weapon_template = weapon_extension and weapon_extension:weapon_template()
	if not weapon_extension._weapons.slot_primary then
		return
	end
	local primary_weapon_template = weapon_extension._weapons.slot_primary.weapon_template
	local is_primary_heat_weapon = primary_weapon_template and primary_weapon_template.overheat_configuration and primary_weapon_template.overheat_configuration.lockout_enabled
	local is_current_heat_weapon = current_weapon_template and current_weapon_template.overheat_configuration and current_weapon_template.overheat_configuration.lockout_enabled
	if is_primary_heat_weapon then
		if mod.percentage ~= nil then
			if mod:get("show_when_weapon_inactive") then
				if mod.locked_out then
					self._widgets_by_name.heat_text.style.heat.text_color = Color.ui_hud_red_light(255, true)
				elseif mod.percentage >= mod:get("warning_threshold") then
					self._widgets_by_name.heat_text.style.heat.text_color = Color.yellow(255, true)
				else
					self._widgets_by_name.heat_text.style.heat.text_color = Color.ui_green_light(255, true)
				end
				if mod:get("show_when_ability_active") then
					if mod.percentage > 0 then
						self._widgets_by_name.heat_text.content.heat = string.format("%.f%%", mod.percentage)
					else
						self._widgets_by_name.heat_text.content.heat = ""
					end
				else
					self._widgets_by_name.heat_text.content.heat = string.format("%.f%%", mod.percentage)
				end
				self._widgets_by_name.heat_text.style.heat.font_size = 30
				return
			elseif is_current_heat_weapon then
				if mod.locked_out then
					self._widgets_by_name.heat_text.style.heat.text_color = Color.ui_hud_red_light(255, true)
				elseif mod.percentage >= mod:get("warning_threshold") then
					self._widgets_by_name.heat_text.style.heat.text_color = Color.yellow(255, true)
				else
					self._widgets_by_name.heat_text.style.heat.text_color = Color.ui_green_light(255, true)
				end
				if mod:get("show_when_ability_active") then
					if mod.percentage > 0 then
						self._widgets_by_name.heat_text.content.heat = string.format("%.f%%", mod.percentage)
					else
						self._widgets_by_name.heat_text.content.heat = ""
					end
				else
					self._widgets_by_name.heat_text.content.heat = string.format("%.f%%", mod.percentage)
				end
				self._widgets_by_name.heat_text.style.heat.font_size = 30
				return
			else
				self._widgets_by_name.heat_text.content.heat = ""
				self._widgets_by_name.heat_text.style.heat.font_size = 30
				return
			end
		end
	end
	self._widgets_by_name.heat_text.content.heat = ""
	self._widgets_by_name.heat_text.style.heat.font_size = 30
end

mod:hook(CLASS.HudElementWeaponCounter, "_draw_widgets", function (func, self, dt, t, input_service, ui_renderer, render_settings)
    local pivot_position = self:scenegraph_world_position("pivot", ui_renderer.scale)
	local x, y = Crosshair.position(dt, t, self._parent, ui_renderer, self._crosshair_position_x, self._crosshair_position_y, pivot_position)

	self._crosshair_position_x = x
	self._crosshair_position_y = y

	HudElementWeaponCounter.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

	-- Hide the "slot_primary_overheat_lockout" widget (the relic blade heat bar)
	for _, widget in pairs(self._slot_widgets) do
		local widget_offset = widget.offset

		widget_offset[1] = x
		widget_offset[2] = y
		if widget.name ~= "slot_primary_overheat_lockout" then
			UIWidget.draw(widget, ui_renderer)
		elseif widget.name == "slot_primary_overheat_lockout" and not mod:get("hide_fatshark_heat_bar") then
			UIWidget.draw(widget, ui_renderer)
		end
	end

	local current_value = 0
	if self._slot_widgets.slot_primary and self._slot_widgets.slot_primary.style.charge_bar then
		current_value = self._slot_widgets.slot_primary.style.charge_bar.material_values.progress
	else
		return
	end

	-- 0.252 is 100% full
    local min_value = 0.028
    local max_value = 0.252
	-- Normalize to percentage
    mod.percentage = math.floor(((current_value - min_value) / (max_value - min_value)) * 100)
	mod.locked_out = self._slot_widgets.slot_primary.style.charge_bar.material_values.lockout == 1
end)

return HudElementHeatPercentage
