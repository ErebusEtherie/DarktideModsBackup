local mod = get_mod("Compass Range Finder")

local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local FrameRenderer = mod:io_dofile("Compass Range Finder/scripts/mods/Compass Range Finder/CompassRangeFinderFrame")
local Targeting = mod:io_dofile("Compass Range Finder/scripts/mods/Compass Range Finder/CompassRangeFinderTargeting")
local color_lib = Color
local Unit = Unit

local HudElementCompassRangeFinder = class("HudElementCompassRangeFinder", "HudElementBase")

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
}

local definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = {},
}

local function get_compass_element(self)
	local parent = self._parent
	local elements = parent and parent._elements

	return elements and elements.HudElementPlayerCompass
end


-- Helper: Calculate distance between two positions
local function calculate_distance(pos1, pos2)
	if not (pos1 and pos2 and pos1.x and pos2.x) then return nil end
	local dx, dy, dz = pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Helper: Get color for a target slot
local function get_target_color(target)
	if target.slot and color_lib then
		local slot_color = color_lib["player_slot_" .. target.slot]
		if slot_color then
			return slot_color(255, true)
		end
	end
	return {255, 255, 255, 255}
end

-- Helper: Collect all relevant targets
local function collect_targets(compass_element)
	local t1 = Targeting.get_marked_expedition_target(compass_element)
	local t2 = Targeting.get_extra_opportunities_target(compass_element)
	local targets = {}
	if t1 then targets[#targets+1] = t1 end
	if t2 then targets[#targets+1] = t2 end
	return targets
end

local function draw_distance_overlay(compass_element, ui_renderer, screen_position)
	local player_angle_radians = compass_element:_get_camera_direction_angle()
	if not player_angle_radians then return end

	local player_direction_degree = math.deg(player_angle_radians)
	local effective_rotation = -player_direction_degree
	local angle_window = mod:get("distance_angle_window_degrees") or 10
	local targets = collect_targets(compass_element)
	if #targets == 0 then return end

	for i, target in ipairs(targets) do
		local target_angle_radians = compass_element:_get_position_direction_angle(target.position)
		if target_angle_radians then
			local target_angle_degrees = math.deg(target_angle_radians)
			local angle_delta = (target_angle_degrees - effective_rotation + 540) % 360 - 180
			if math.abs(angle_delta) <= angle_window then
				local color = get_target_color(target)
				local entry_position = {
					screen_position[1],
					screen_position[2] + (i - 1) * 36,
					screen_position[3],
				}
				local distance = target.distance
				if not distance and compass_element and compass_element._my_player and target.position then
					local player_unit = compass_element._my_player.player_unit
					if player_unit and Unit and Unit.local_position then
						local player_pos = Unit.local_position(player_unit, 1)
						distance = calculate_distance(player_pos, target.position)
					end
				end
				if distance then
					FrameRenderer.draw(ui_renderer, math.floor(distance + 0.5), color, entry_position)
				end
			end
		end
	end
end

HudElementCompassRangeFinder.init = function(self, parent, draw_layer, start_scale)
	HudElementCompassRangeFinder.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementCompassRangeFinder.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
	if not mod:is_enabled() then
		return
	end

	render_settings.start_layer = self._draw_layer
	UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)

	local resolution_lookup = rawget(_G, "RESOLUTION_LOOKUP")
	local screen_scale = (resolution_lookup and resolution_lookup.scale) or ui_renderer.scale or 1
	local resolution_width = (resolution_lookup and (resolution_lookup.width or resolution_lookup.res_w or resolution_lookup[1])) or 1920
	local resolution_height = (resolution_lookup and (resolution_lookup.height or resolution_lookup.res_h or resolution_lookup[2])) or 1080
	local screen_width = resolution_width / screen_scale
	local screen_height = resolution_height / screen_scale
	local horizontal_position = mod:get("distance_horizontal_position") or 0.5
	local vertical_position = mod:get("distance_vertical_position") or 0.12
	local screen_position = {
		screen_width * horizontal_position,
		screen_height * vertical_position,
		10,
	}

	local compass_element = get_compass_element(self)
	local expedition_active = Targeting.is_expedition_active(compass_element)
	if expedition_active then
		draw_distance_overlay(compass_element, ui_renderer, screen_position)
	end

	UIRenderer.end_pass(ui_renderer)
end

return HudElementCompassRangeFinder
