--[[
	File: ExpeditionsMissionGrid.lua
	Description: Expeditions mission grid runtime
	Overall Release Version: 1.1.0
	File Version: 1.0.0
	Last Updated: 2026-03-17
	Author: LAUREHTE
]]

local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIResolution = require("scripts/managers/ui/ui_resolution")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local mod = get_mod("ExpeditionsMissionGrid")

local DEFAULTS = {
	start_x = 18,
	start_y = 22,
	spacing_x = 15,
	spacing_y = 18,
	max_columns = 4,
	card_scale = 100,
}

local BASE_CARD_SIZE = {
	246,
	118,
}

local LINE_THICKNESS = 4
local CARD_Z = 220
local LINE_Z = 214
local OVERLAY_SCENEGRAPH_DEFINITION = {
	screen = table.clone(UIWorkspaceSettings.screen),
}

local function optional_require(path)
	local ok, result = pcall(require, path)

	if ok then
		return result
	end

	return nil
end

local function optional_settings(path)
	local settings = optional_require(path)

	if type(settings) == "table" and type(settings.settings) == "table" then
		return settings.settings
	end

	if type(settings) == "table" then
		return settings
	end

	return nil
end

local MISSION_TYPES = optional_settings("scripts/settings/mission/mission_types")
local ZONES = optional_settings("scripts/settings/zones/zones")

local function color(a, r, g, b)
	return {
		a,
		r,
		g,
		b,
	}
end

local CARD_COLORS = {
	normal_background = color(238, 8, 12, 10),
	normal_accent = color(255, 104, 255, 176),
	normal_frame = color(168, 104, 255, 176),
	normal_text = color(255, 232, 255, 232),
	normal_subtext = color(255, 154, 196, 154),
	locked_background = color(246, 38, 6, 6),
	locked_accent = color(255, 255, 72, 72),
	locked_frame = color(255, 255, 96, 96),
	locked_text = color(255, 255, 230, 230),
	locked_subtext = color(255, 255, 166, 166),
	locked_selected_background = color(255, 52, 10, 10),
	locked_selected_accent = color(255, 255, 108, 108),
	locked_selected_frame = color(255, 255, 140, 140),
	locked_selected_glow = color(255, 255, 170, 170),
	hover_background = color(245, 14, 20, 14),
	hover_accent = color(255, 124, 255, 188),
	hover_frame = color(196, 124, 255, 188),
	hover_text = color(255, 242, 255, 242),
	hover_subtext = color(255, 176, 214, 176),
	selected_background = color(245, 18, 28, 18),
	selected_accent = color(255, 138, 255, 196),
	selected_frame = color(220, 138, 255, 196),
	selected_glow = color(255, 188, 255, 228),
	selected_text = color(255, 248, 255, 248),
	selected_subtext = color(255, 190, 236, 190),
	line = color(180, 108, 255, 176),
	line_selected = color(255, 164, 255, 214),
}

local CARD_DEFINITION = UIWidget.create_definition({
	{
		pass_type = "rect",
		style_id = "shadow",
		style = {
			color = color(140, 0, 0, 0),
			offset = {
				4,
				6,
				0,
			},
		},
	},
	{
		pass_type = "rect",
		style_id = "background",
		style = {
			color = color(238, 8, 12, 10),
			offset = {
				0,
				0,
				1,
			},
		},
	},
	{
		pass_type = "rect",
		style_id = "accent",
		style = {
			color = color(255, 104, 255, 176),
			offset = {
				0,
				0,
				3,
			},
			size = {
				BASE_CARD_SIZE[1],
				4,
			},
		},
	},
	{
		pass_type = "texture",
		style_id = "frame",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = {
			color = color(168, 104, 255, 176),
			offset = {
				0,
				0,
				4,
			},
			scale_to_material = true,
		},
	},
	{
		pass_type = "texture",
		style_id = "selection_frame",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = {
			color = color(0, 188, 255, 228),
			offset = {
				-2,
				-2,
				5,
			},
			scale_to_material = true,
			size = {
				BASE_CARD_SIZE[1] + 4,
				BASE_CARD_SIZE[2] + 4,
			},
		},
	},
	{
		pass_type = "text",
		value_id = "title",
		value = "",
		style_id = "title",
		style = {
			font_size = 24,
			font_type = "machine_medium",
			text_color = color(255, 232, 255, 232),
			text_horizontal_alignment = "left",
			text_vertical_alignment = "top",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = {
				18,
				14,
				8,
			},
			size = {
				BASE_CARD_SIZE[1] - 36,
				30,
			},
			drop_shadow = false,
		},
	},
	{
		pass_type = "text",
		value_id = "subtitle",
		value = "",
		style_id = "subtitle",
		style = {
			font_size = 18,
			font_type = "machine_medium",
			text_color = color(255, 154, 196, 154),
			text_horizontal_alignment = "left",
			text_vertical_alignment = "top",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = {
				18,
				58,
				8,
			},
			size = {
				BASE_CARD_SIZE[1] - 36,
				20,
			},
			drop_shadow = false,
		},
	},
	{
		pass_type = "text",
		value_id = "detail",
		value = "",
		style_id = "detail",
		style = {
			font_size = 14,
			font_type = "machine_medium",
			text_color = color(255, 154, 196, 154),
			text_horizontal_alignment = "left",
			text_vertical_alignment = "top",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = {
				18,
				79,
				8,
			},
			size = {
				BASE_CARD_SIZE[1] - 36,
				18,
			},
			drop_shadow = false,
		},
	},
	{
		pass_type = "text",
		value_id = "tag",
		value = "",
		style_id = "tag",
		style = {
			font_size = 16,
			font_type = "machine_medium",
			text_color = color(255, 232, 255, 232),
			text_horizontal_alignment = "left",
			text_vertical_alignment = "bottom",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = {
				18,
				-12,
				8,
			},
			size = {
				BASE_CARD_SIZE[1] - 36,
				20,
			},
			drop_shadow = false,
		},
	},
}, "screen", nil, BASE_CARD_SIZE)

local LINE_DEFINITION = UIWidget.create_definition({
	{
		pass_type = "rect",
		style_id = "line",
		style = {
			color = color(180, 108, 255, 176),
			offset = {
				0,
				0,
				0,
			},
			size = {
				1,
				LINE_THICKNESS,
			},
		},
	},
}, "screen", nil, {
	1,
	LINE_THICKNESS,
})

local function numeric_setting(id, min_value, max_value)
	local value = mod:get(id)

	if value == nil then
		value = DEFAULTS[id]
	end

	if type(value) ~= "number" then
		value = tonumber(value)
	end

	if type(value) ~= "number" then
		value = DEFAULTS[id]
	end

	if min_value ~= nil and value < min_value then
		value = min_value
	end

	if max_value ~= nil and value > max_value then
		value = max_value
	end

	return value
end

local function card_scale_multiplier()
	return numeric_setting("card_scale", 50, 200) / 100
end

local function card_width()
	return BASE_CARD_SIZE[1] * card_scale_multiplier()
end

local function card_height()
	return BASE_CARD_SIZE[2] * card_scale_multiplier()
end

local function card_half_width()
	return card_width() * 0.5
end

local function card_half_height()
	return card_height() * 0.5
end

local function grid_position(index, max_columns)
	local zero_index = index - 1
	local row = math.floor(zero_index / max_columns)
	local column = zero_index % max_columns

	if row % 2 == 1 then
		column = max_columns - 1 - column
	end

	return row, column
end

local function layout_nodes(view)
	local ordered_nodes = view and view._ordered_nodes

	if not ordered_nodes or #ordered_nodes == 0 then
		return
	end

	local max_columns = math.max(1, math.floor(numeric_setting("max_columns", 1, 8) or DEFAULTS.max_columns))
	local start_x = numeric_setting("start_x", 0, 60) / 100
	local start_y = numeric_setting("start_y", 0, 60) / 100
	local spacing_x = numeric_setting("spacing_x", 6, 25) / 100
	local spacing_y = numeric_setting("spacing_y", 6, 25) / 100

	for i = 1, #ordered_nodes do
		local node = ordered_nodes[i]
		local ui = node and node.ui

		if ui then
			local row, column = grid_position(i, max_columns)
			local x = start_x + spacing_x * column
			local y = start_y + spacing_y * row

			ui.x = x
			ui.y = y
		end
	end
end

local function extract_xy(value)
	if value == nil then
		return nil
	end

	if type(value) == "table" then
		if type(value.x) == "number" and type(value.y) == "number" then
			return value.x, value.y
		end

		if type(value[1]) == "number" and type(value[2]) == "number" then
			return value[1], value[2]
		end
	end

	local ok_x, x = pcall(function()
		return value[1]
	end)
	local ok_y, y = pcall(function()
		return value[2]
	end)

	if ok_x and ok_y and type(x) == "number" and type(y) == "number" then
		return x, y
	end

	ok_x, x = pcall(function()
		return value.x
	end)
	ok_y, y = pcall(function()
		return value.y
	end)

	if ok_x and ok_y and type(x) == "number" and type(y) == "number" then
		return x, y
	end

	return nil
end

local function overlay_card_position(index)
	local max_columns = math.max(1, math.floor(numeric_setting("max_columns", 1, 8) or DEFAULTS.max_columns))
	local row, column = grid_position(index, max_columns)
	local screen_width = UIResolution.width_fragments()
	local screen_height = UIResolution.height_fragments()
	local start_x = screen_width * (numeric_setting("start_x", 0, 60) / 100)
	local start_y = screen_height * (numeric_setting("start_y", 0, 60) / 100)
	local spacing_x = screen_width * (numeric_setting("spacing_x", 6, 25) / 100)
	local spacing_y = screen_height * (numeric_setting("spacing_y", 6, 25) / 100)

	return start_x + spacing_x * column, start_y + spacing_y * row
end

local function contains_text(value, needle)
	if type(value) ~= "string" or value == "" then
		return false
	end

	return string.find(string.lower(value), needle, 1, true) ~= nil
end

local function is_hidden_overlay_node(node)
	if not node then
		return true
	end

	local ui = node.ui
	local id = node.id
	local name = node.name
	local display_name = ui and ui.display_name
	local missions = node.missions
	local mission_total = type(missions) == "table" and #missions or 0
	local unlock_status = node.unlock_status
	local unlocked = unlock_status == nil or unlock_status == "" or unlock_status == "unlocked"

	if contains_text(id, "quickplay") or contains_text(name, "quickplay") or contains_text(display_name, "quickplay") then
		return true
	end

	return mission_total == 0
		and unlocked
		and (type(display_name) ~= "string" or display_name == "")
		and (type(name) ~= "string" or name == "")
end

local function visible_overlay_nodes(view)
	local ordered_nodes = view and view._ordered_nodes
	local nodes = {}

	if type(ordered_nodes) ~= "table" then
		return nodes
	end

	for i = 1, #ordered_nodes do
		local node = ordered_nodes[i]

		if not is_hidden_overlay_node(node) then
			nodes[#nodes + 1] = node
		end
	end

	return nodes
end

local function resolve_overlay_link_index(target, lookup)
	if target == nil then
		return nil
	end

	local target_type = type(target)

	if target_type == "table" then
		return lookup.by_ref[target]
			or resolve_overlay_link_index(target.id, lookup)
			or resolve_overlay_link_index(target.name, lookup)
			or resolve_overlay_link_index(target.index, lookup)
	end

	if target_type == "string" then
		return lookup.by_id[target] or lookup.by_name[target]
	end

	if target_type == "number" then
		return lookup.by_index[target]
	end

	return nil
end

local function build_overlay_connections(nodes)
	local lookup = {
		by_ref = {},
		by_id = {},
		by_name = {},
		by_index = {},
	}
	local connections = {}
	local seen = {}

	for i = 1, #nodes do
		local node = nodes[i]
		lookup.by_ref[node] = i

		if type(node.id) == "string" and node.id ~= "" then
			lookup.by_id[node.id] = i
		end

		if type(node.name) == "string" and node.name ~= "" then
			lookup.by_name[node.name] = i
		end

		if type(node.index) == "number" then
			lookup.by_index[node.index] = i
		end
	end

	for i = 1, #nodes do
		local next_nodes = nodes[i] and nodes[i].next

		if type(next_nodes) == "table" then
			for key, value in pairs(next_nodes) do
				local target_index = resolve_overlay_link_index(value, lookup) or resolve_overlay_link_index(key, lookup)

				if target_index and target_index ~= i then
					local first_index = math.min(i, target_index)
					local second_index = math.max(i, target_index)
					local edge_key = string.format("%d:%d", first_index, second_index)

					if not seen[edge_key] then
						seen[edge_key] = true
						connections[#connections + 1] = {
							a = first_index,
							b = second_index,
						}
					end
				end
			end
		end
	end

	return connections
end

local function find_input_service(...)
	local arg_count = select("#", ...)

	for i = 1, arg_count do
		local value = select(i, ...)

		if type(value) == "table" and type(value.get) == "function" then
			return value
		end
	end

	return nil
end

local function cursor_position(input_service)
	if not input_service then
		return nil
	end

	local ok, cursor = pcall(input_service.get, input_service, "cursor")

	if not ok then
		return nil
	end

	return extract_xy(cursor)
end

local function scaled_cursor_position(view, input_service)
	local cursor_x, cursor_y = cursor_position(input_service)

	if not cursor_x or not cursor_y then
		return nil
	end

	local inverse_scale = view and view._render_settings and view._render_settings.inverse_scale

	if type(inverse_scale) ~= "number" or inverse_scale <= 0 then
		local render_scale = overlay_render_scale(view)
		inverse_scale = render_scale ~= 0 and 1 / render_scale or 1
	end

	return cursor_x * inverse_scale, cursor_y * inverse_scale
end

local function hovered_overlay_node(view, input_service)
	local cursor_x, cursor_y = scaled_cursor_position(view, input_service)
	local half_width = card_half_width()
	local half_height = card_half_height()

	if not cursor_x or not cursor_y then
		return nil, false
	end

	local ordered_nodes = visible_overlay_nodes(view)

	if type(ordered_nodes) ~= "table" then
		return nil, true
	end

	for i = #ordered_nodes, 1, -1 do
		local node = ordered_nodes[i]
		local x, y = overlay_card_position(i)
		local min_x = x - half_width
		local max_x = x + half_width
		local min_y = y - half_height
		local max_y = y + half_height

		if min_x <= cursor_x and cursor_x <= max_x and min_y <= cursor_y and cursor_y <= max_y then
			return node, true
		end
	end

	return nil, true
end

local function readable_name(node, index)
	local ui = node and node.ui
	local name = ui and ui.display_name or node and node.name

	if type(name) ~= "string" or name == "" then
		return string.format("Mission %d", index)
	end

	if type(Localize) == "function" then
		local ok, localized = pcall(Localize, name)

		if ok and type(localized) == "string" and localized ~= "" then
			return localized
		end
	end

	name = name:gsub("^exped%-node%-", "")
	name = name:gsub("^node_", "")
	name = name:gsub("_", " ")

	return name
end

local function localize_text(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	if type(Localize) == "function" then
		local ok, localized = pcall(Localize, value)

		if ok and type(localized) == "string" and localized ~= "" and localized ~= value then
			return localized
		end
	end

	return nil
end

local function clean_identifier_text(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	local cleaned = value
	cleaned = cleaned:gsub("^loc_", "")
	cleaned = cleaned:gsub("^exped%-node%-", "")
	cleaned = cleaned:gsub("^node_", "")
	cleaned = cleaned:gsub("^mission_type_", "")
	cleaned = cleaned:gsub("_", " ")
	cleaned = cleaned:gsub("%s+", " ")
	cleaned = cleaned:gsub("^%l", string.upper)

	return cleaned
end

local function display_text(value)
	return localize_text(value) or clean_identifier_text(value)
end

local function first_text(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)

		if type(value) == "string" and value ~= "" then
			return value
		end
	end

	return nil
end

local function selected_mission_data(view, node)
	if not node then
		return nil
	end

	if view and type(view.get_selected_mission_data) == "function" then
		local ok, mission = pcall(view.get_selected_mission_data, view, node)

		if ok and type(mission) == "table" then
			return mission
		end
	end

	local missions = node.missions

	if type(missions) == "table" and #missions > 0 then
		return missions[1]
	end

	return nil
end

local function mission_type_id(mission)
	local mission_type = mission and first_text(mission.mission_type, mission.missionType, mission.type)

	if mission_type == "expedition" then
		return "expeditions"
	end

	return mission_type
end

local function mission_type_settings(mission)
	local mission_type = mission_type_id(mission)

	if not MISSION_TYPES or type(mission_type) ~= "string" then
		return nil
	end

	return MISSION_TYPES[mission_type]
end

local function mission_zone_settings(mission)
	if not ZONES or type(mission) ~= "table" then
		return ZONES and ZONES.expeditions or nil
	end

	local zone_id = first_text(mission.zone, mission.zone_id, mission.map, mission.map_id)

	if type(zone_id) == "string" and ZONES[zone_id] then
		return ZONES[zone_id]
	end

	return ZONES.expeditions
end

local function mission_difficulty_text(view, mission)
	local challenge = mission and mission.challenge
	local resistance = mission and mission.resistance

	if type(challenge) ~= "number" or type(resistance) ~= "number" then
		local page_settings = view and view._page_settings
		local page_index = view and view._page_index
		local page = type(page_settings) == "table" and page_settings[page_index]

		if type(challenge) ~= "number" then
			challenge = page and page.challenge
		end

		if type(resistance) ~= "number" then
			resistance = page and page.resistance
		end
	end

	if type(challenge) == "number" and type(resistance) == "number" then
		return string.format("C%d / R%d", challenge, resistance)
	end

	return nil
end

local function node_card_info(view, node, index, locked)
	local mission = selected_mission_data(view, node)
	local mission_type = mission_type_settings(mission)
	local zone = mission_zone_settings(mission)
	local title = readable_name(node, index)
	local mission_type_name = display_text(mission_type and mission_type.name)
	local zone_name = display_text(zone and first_text(zone.name_short, zone.name))
	local difficulty = mission_difficulty_text(view, mission)
	local subtitle = ""
	local detail = ""

	if mission_type_name and not contains_text(mission_type_name, "expedition") then
		subtitle = mission_type_name
	end

	if zone_name and not contains_text(zone_name, "expedition") then
		if subtitle == "" then
			subtitle = zone_name
		else
			detail = zone_name
		end
	end

	if difficulty then
		if subtitle == "" then
			subtitle = difficulty
		elseif detail == "" then
			detail = difficulty
		end
	end

	if locked and subtitle == "" and detail == "" then
		subtitle = "Locked route"
	end

	return {
		title = title,
		subtitle = subtitle,
		detail = detail,
	}
end

local function is_node_locked(node)
	if not node then
		return false
	end

	local unlock_status = node.unlock_status

	if type(unlock_status) == "string" and unlock_status ~= "" then
		return unlock_status ~= "unlocked"
	end

	local to_unlock = node.to_unlock

	if type(to_unlock) == "number" then
		return to_unlock > 0
	end

	if type(to_unlock) == "table" then
		for _, value in pairs(to_unlock) do
			if value ~= nil and value ~= false and value ~= 0 then
				return true
			end
		end
	end

	return false
end

local function status_text(node, selected)
	local locked = is_node_locked(node)

	if selected then
		return "SELECTED"
	end

	if locked then
		return "UNAVAILABLE"
	end

	return "READY"
end

local function set_color(target, source)
	target[1] = source[1]
	target[2] = source[2]
	target[3] = source[3]
	target[4] = source[4]
end

local function overlay_render_scale(view)
	if view and type(view._render_scale) == "number" then
		return view._render_scale
	end

	if view and view._render_settings and type(view._render_settings.scale) == "number" then
		return view._render_settings.scale
	end

	if Managers and Managers.ui and type(Managers.ui.view_render_scale) == "function" then
		return Managers.ui:view_render_scale()
	end

	return 1
end

local function ensure_overlay_scenegraph(view)
	local scenegraph = view._expeditions_mission_grid_scenegraph
	local render_scale = overlay_render_scale(view)

	if not scenegraph then
		scenegraph = UIScenegraph.init_scenegraph(OVERLAY_SCENEGRAPH_DEFINITION, render_scale)
		view._expeditions_mission_grid_scenegraph = scenegraph
	end

	UIScenegraph.update_scenegraph(scenegraph, render_scale)

	return scenegraph
end

local function ensure_widgets(view, card_count, line_count)
	local cards = view._expeditions_mission_grid_cards
	local lines = view._expeditions_mission_grid_lines
	local scenegraph = ensure_overlay_scenegraph(view)

	if not cards then
		cards = {}
		view._expeditions_mission_grid_cards = cards
	end

	if not lines then
		lines = {}
		view._expeditions_mission_grid_lines = lines
	end

	for i = #cards + 1, card_count do
		cards[i] = UIWidget.init("expeditions_mission_grid_card_" .. tostring(i), CARD_DEFINITION)
	end

	for i = #lines + 1, line_count do
		lines[i] = UIWidget.init("expeditions_mission_grid_line_" .. tostring(i), LINE_DEFINITION)
	end

	for i = 1, #cards do
		cards[i].ui_scenegraph = scenegraph
	end

	for i = 1, #lines do
		lines[i].ui_scenegraph = scenegraph
	end

	return cards, lines
end

local function reset_node_unit_presentation(node)
	local ui = node and node.ui
	local node_unit = ui and ui.node_unit

	if not node_unit then
		return
	end

	if Unit and type(Unit.flow_event) == "function" then
		pcall(Unit.flow_event, node_unit, "unhover")
		pcall(Unit.flow_event, node_unit, "unselect")
	end

	if Unit and type(Unit.set_scalar_for_materials) == "function" then
		pcall(Unit.set_scalar_for_materials, node_unit, "node_selection_emissive_multiplier", 0, true)
		pcall(Unit.set_scalar_for_materials, node_unit, "emissive_multiplier", 0, true)
	end
end

local function suppress_background_node_feedback(view)
	local ordered_nodes = view and view._ordered_nodes

	if type(ordered_nodes) ~= "table" then
		return
	end

	for i = 1, #ordered_nodes do
		reset_node_unit_presentation(ordered_nodes[i])
	end
end

local function disable_intro_input_delay(view)
	if not view then
		return
	end

	view._node_enter_anim_finished = true
	view._node_enter_anim_time = 0
	view._enable_input_delay = 0
end

local function current_card_scale(view, node, selected, hovered)
	local animations = view._expeditions_mission_grid_card_scales

	if not animations then
		animations = {}
		view._expeditions_mission_grid_card_scales = animations
	end

	local key = tostring(node and (node.id or node.name) or "unknown")
	local current = animations[key] or 1
	local target = 1

	if hovered then
		target = 1.08
	end

	if selected then
		target = math.max(target, 1.12)
	end

	current = current + (target - current) * 0.28
	animations[key] = current

	return current
end

local function set_size(style_data, width, height)
	style_data.size = style_data.size or {}
	style_data.size[1] = width
	style_data.size[2] = height
end

local function update_card_widget(widget, x, y, card_info, tag, selected, hovered, locked, scale)
	local style = widget.style
	local content = widget.content
	local background_color = CARD_COLORS.normal_background
	local accent_color = CARD_COLORS.normal_accent
	local frame_color = CARD_COLORS.normal_frame
	local glow_color = color(0, 0, 0, 0)
	local title_color = CARD_COLORS.normal_text
	local subtitle_color = CARD_COLORS.normal_subtext
	local detail_color = CARD_COLORS.normal_subtext

	if locked then
		background_color = CARD_COLORS.locked_background
		accent_color = CARD_COLORS.locked_accent
		frame_color = CARD_COLORS.locked_frame
		title_color = CARD_COLORS.locked_text
		subtitle_color = CARD_COLORS.locked_subtext
		detail_color = CARD_COLORS.locked_subtext
	end

	if hovered then
		background_color = locked and CARD_COLORS.locked_background or CARD_COLORS.hover_background
		accent_color = locked and CARD_COLORS.locked_accent or CARD_COLORS.hover_accent
		frame_color = locked and CARD_COLORS.locked_frame or CARD_COLORS.hover_frame
		title_color = locked and CARD_COLORS.locked_text or CARD_COLORS.hover_text
		subtitle_color = locked and CARD_COLORS.locked_subtext or CARD_COLORS.hover_subtext
		detail_color = locked and CARD_COLORS.locked_subtext or CARD_COLORS.hover_subtext
	end

	if selected then
		if locked then
			background_color = CARD_COLORS.locked_selected_background
			accent_color = CARD_COLORS.locked_selected_accent
			frame_color = CARD_COLORS.locked_selected_frame
			glow_color = CARD_COLORS.locked_selected_glow
			title_color = CARD_COLORS.locked_text
			subtitle_color = CARD_COLORS.locked_subtext
			detail_color = CARD_COLORS.locked_subtext
		else
			background_color = CARD_COLORS.selected_background
			accent_color = CARD_COLORS.selected_accent
			frame_color = CARD_COLORS.selected_frame
			glow_color = CARD_COLORS.selected_glow
			title_color = CARD_COLORS.selected_text
			subtitle_color = CARD_COLORS.selected_subtext
			detail_color = CARD_COLORS.selected_subtext
		end
	end

	local width = card_width() * scale
	local height = card_height() * scale
	local half_width = width * 0.5
	local half_height = height * 0.5
	local padding_x = 18 * scale
	local title_x = padding_x
	local title_y = 14 * scale
	local subtitle_y = 58 * scale
	local detail_y = 79 * scale
	local tag_bottom = -12 * scale

	widget.offset[1] = x - half_width
	widget.offset[2] = y - half_height
	widget.offset[3] = CARD_Z
	content.size = content.size or {}
	content.size[1] = width
	content.size[2] = height

	content.title = string.upper(card_info.title)
	content.subtitle = string.upper(card_info.subtitle or "")
	content.detail = string.upper(card_info.detail or "")
	content.tag = tag

	set_size(style.shadow, width, height)
	set_size(style.background, width, height)
	set_size(style.accent, width, 4 * scale)
	set_size(style.frame, width, height)
	set_size(style.selection_frame, width + 4 * scale, height + 4 * scale)
	set_size(style.title, width - (title_x + padding_x), 30 * scale)
	set_size(style.subtitle, width - padding_x * 2, 20 * scale)
	set_size(style.detail, width - padding_x * 2, 18 * scale)
	set_size(style.tag, width - padding_x * 2, 20 * scale)
	style.title.offset[1] = title_x
	style.title.offset[2] = title_y
	style.subtitle.offset[1] = padding_x
	style.subtitle.offset[2] = subtitle_y
	style.detail.offset[1] = padding_x
	style.detail.offset[2] = detail_y
	style.tag.offset[1] = padding_x
	style.tag.offset[2] = tag_bottom

	set_color(style.background.color, background_color)
	set_color(style.accent.color, accent_color)
	set_color(style.frame.color, frame_color)
	set_color(style.selection_frame.color, glow_color)
	set_color(style.title.text_color, title_color)
	set_color(style.subtitle.text_color, subtitle_color)
	set_color(style.detail.text_color, detail_color)
	set_color(style.tag.text_color, accent_color)
end

local function set_line_segment_widget(widget, x, y, width, height, selected)
	local style = widget.style.line
	local size = style.size
	local content_size = widget.content.size or {}

	widget.offset[1] = x
	widget.offset[2] = y
	widget.offset[3] = LINE_Z

	size[1] = width
	size[2] = height
	content_size[1] = width
	content_size[2] = height
	widget.content.size = content_size

	if selected then
		set_color(style.color, CARD_COLORS.line_selected)
	else
		set_color(style.color, CARD_COLORS.line)
	end
end

local function append_connection_segments(segments, x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1

	if math.abs(dx) >= math.abs(dy) then
		local direction_x = dx >= 0 and 1 or -1
		local start_x = x1 + direction_x * card_half_width()
		local end_x = x2 - direction_x * card_half_width()
		local mid_x = (start_x + end_x) * 0.5

		segments[#segments + 1] = {
			start_x,
			y1,
			mid_x,
			y1,
		}
		segments[#segments + 1] = {
			mid_x,
			y1,
			mid_x,
			y2,
		}
		segments[#segments + 1] = {
			mid_x,
			y2,
			end_x,
			y2,
		}
	else
		local direction_y = dy >= 0 and 1 or -1
		local start_y = y1 + direction_y * card_half_height()
		local end_y = y2 - direction_y * card_half_height()
		local mid_y = (start_y + end_y) * 0.5

		segments[#segments + 1] = {
			x1,
			start_y,
			x1,
			mid_y,
		}
		segments[#segments + 1] = {
			x1,
			mid_y,
			x2,
			mid_y,
		}
		segments[#segments + 1] = {
			x2,
			mid_y,
			x2,
			end_y,
		}
	end
end

local function draw_widget(view, widget)
	if not widget or not view or not view._ui_renderer then
		return
	end

	UIWidget.draw(widget, view._ui_renderer)
end

local function draw_overlay(view, dt, input_service, layer)
	if view and view._expeditions_mission_grid_overlay_failed then
		return
	end

	local ordered_nodes = view and view._ordered_nodes

	if not ordered_nodes or #ordered_nodes == 0 then
		return
	end

	local ui_renderer = view._ui_renderer

	if not ui_renderer then
		return
	end

	local render_settings = view._render_settings

	if not render_settings then
		return
	end

	local pass_begun = false
	local ok, error_message = xpcall(function()
		local overlay_scenegraph = ensure_overlay_scenegraph(view)
		local render_scale = overlay_render_scale(view)
		local start_layer = layer or render_settings.start_layer or 0

		render_settings.start_layer = start_layer
		render_settings.scale = render_scale
		render_settings.inverse_scale = render_scale ~= 0 and 1 / render_scale or 1

		UIRenderer.begin_pass(ui_renderer, overlay_scenegraph, input_service, dt or 0, render_settings)
		pass_begun = true

		local visible_nodes = visible_overlay_nodes(view)
		local connections = build_overlay_connections(visible_nodes)
		local cards, lines = ensure_widgets(view, #visible_nodes, #connections * 3)
		local selected_node = view._selected_node
		local hovered_node = view._hovered_node
		local positions = {}

		for i = 1, #visible_nodes do
			local node = visible_nodes[i]
			local x, y = overlay_card_position(i)

			if x and y then
				positions[i] = {
					x = x,
					y = y,
				}

				local selected = node == selected_node
				local hovered = node == hovered_node
				local locked = is_node_locked(node)
				local card_info = node_card_info(view, node, i, locked)
				local scale = current_card_scale(view, node, selected, hovered)

				update_card_widget(
					cards[i],
					x,
					y,
					card_info,
					status_text(node, selected),
					selected,
					hovered,
					locked,
					scale
				)
			else
				positions[i] = false
			end
		end

		local line_widget_index = 1

		for i = 1, #connections do
			local connection = connections[i]
			local pos_a = positions[connection.a]
			local pos_b = positions[connection.b]

			if pos_a and pos_b then
				local selected = visible_nodes[connection.a] == selected_node or visible_nodes[connection.b] == selected_node
				local segments = {}

				append_connection_segments(segments, pos_a.x, pos_a.y, pos_b.x, pos_b.y)

				for segment_index = 1, #segments do
					local segment = segments[segment_index]
					local x1 = segment[1]
					local y1 = segment[2]
					local x2 = segment[3]
					local y2 = segment[4]
					local min_x = math.min(x1, x2)
					local min_y = math.min(y1, y2)
					local width = math.max(math.abs(x2 - x1), LINE_THICKNESS)
					local height = math.max(math.abs(y2 - y1), LINE_THICKNESS)
					local is_horizontal = math.abs(x2 - x1) >= math.abs(y2 - y1)
					local draw_x = is_horizontal and min_x or (x1 - LINE_THICKNESS * 0.5)
					local draw_y = is_horizontal and (y1 - LINE_THICKNESS * 0.5) or min_y
					local draw_width = is_horizontal and width or LINE_THICKNESS
					local draw_height = is_horizontal and LINE_THICKNESS or height
					local widget = lines[line_widget_index]

					if widget then
						set_line_segment_widget(widget, draw_x, draw_y, draw_width, draw_height, selected)
						draw_widget(view, widget)
					end

					line_widget_index = line_widget_index + 1
				end
			end
		end

		for i = 1, #visible_nodes do
			if positions[i] then
				draw_widget(view, cards[i])
			end
		end

		UIRenderer.end_pass(ui_renderer)
		pass_begun = false
	end, debug.traceback)

	if pass_begun then
		pcall(UIRenderer.end_pass, ui_renderer)
	end

	if not ok then
		view._expeditions_mission_grid_overlay_failed = true
		mod:error("overlay draw failed: %s", error_message)
	end
end

mod:hook(CLASS.ExpeditionView, "_update_nodes", function(func, self, ...)
	layout_nodes(self)

	local result = func(self, ...)
	disable_intro_input_delay(self)
	suppress_background_node_feedback(self)

	return result
end)

mod:hook(CLASS.ExpeditionView, "_handle_input", function(func, self, ...)
	disable_intro_input_delay(self)

	return func(self, ...)
end)

mod:hook(CLASS.ExpeditionView, "_handle_gamepad_input", function(func, self, ...)
	disable_intro_input_delay(self)

	return func(self, ...)
end)

mod:hook(CLASS.ExpeditionView, "_get_hovered_node", function(func, self, ...)
	local input_service = find_input_service(...)
	local hovered_node, handled = hovered_overlay_node(self, input_service)

	if handled then
		return hovered_node
	end

	return func(self, ...)
end)

mod:hook(CLASS.ExpeditionView, "_select_node", function(func, self, ...)
	local result = func(self, ...)
	suppress_background_node_feedback(self)

	return result
end)

mod:hook_safe(CLASS.ExpeditionView, "_update_node_hover_state", function(self)
	suppress_background_node_feedback(self)
end)

mod:hook_safe(CLASS.ExpeditionView, "draw", function(self, dt, t, input_service, layer)
	suppress_background_node_feedback(self)
	draw_overlay(self, dt, input_service, layer)
end)

mod:hook_safe(CLASS.ExpeditionView, "on_exit", function(self)
	self._expeditions_mission_grid_cards = nil
	self._expeditions_mission_grid_lines = nil
	self._expeditions_mission_grid_scenegraph = nil
	self._expeditions_mission_grid_overlay_failed = nil
	self._expeditions_mission_grid_card_scales = nil
end)
