local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local MAX_PLAYER_MARKERS = 4
local MAX_TRIGGER_MARKERS = 24

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	timeline_container = {
		parent = "screen",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = { 420, 140 },
		position = { 20, 240, 55 },
	},
	timeline_bar = {
		parent = "timeline_container",
		vertical_alignment = "center",
		horizontal_alignment = "left",
		size = { 260, 10 },
		position = { 0, 0, 1 },
	},
	timeline_stats = {
		parent = "screen",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = { 260, 120 },
		position = { 20, 360, 60 },
	},
}

for i = 1, MAX_PLAYER_MARKERS do
	scenegraph_definition["player_marker_" .. i] = {
		parent = "timeline_bar",
		vertical_alignment = "center",
		horizontal_alignment = "center",
		size = { 260, 24 },
		position = { 0, 0, 4 },
	}
end

for i = 1, MAX_TRIGGER_MARKERS do
	scenegraph_definition["trigger_marker_" .. i] = {
		parent = "timeline_bar",
		vertical_alignment = "center",
		horizontal_alignment = "center",
		size = { 240, 18 },
		position = { 0, 0, 3 },
	}
end

scenegraph_definition.max_marker = {
	parent = "timeline_bar",
	vertical_alignment = "center",
	horizontal_alignment = "center",
	size = { 140, 20 },
	position = { 0, 0, 5 },
}

local widget_definitions = {
	timeline_bg = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = { 140, 0, 0, 0 },
				offset = { 0, 0, 1 },
				size = { 260, 10 },
			},
		},
		{
			pass_type = "rect",
			style_id = "line",
			style = {
				color = UIHudSettings.color_tint_main_1,
				offset = { 1, 1, 2 },
				size = { 258, 8 },
			},
		},
	}, "timeline_bar"),
	timeline_stats = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "stats_bg",
			style = {
				color = { 180, 0, 0, 0 },
				offset = { 0, 0, 0 },
				size = { 1, 1 },
			},
		},
		{
			pass_type = "text",
			style_id = "text",
			value_id = "text",
			value = "",
			style = {
				font_type = "machine_medium",
				font_size = 12,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = UIHudSettings.color_tint_main_1,
				drop_shadow = true,
				offset = { 0, 0, 1 },
				size = { 260, 120 },
			},
		},
	}, "timeline_stats"),
}

for i = 1, MAX_PLAYER_MARKERS do
	widget_definitions["player_marker_" .. i] = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "tick",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				color = UIHudSettings.color_tint_main_1,
				offset = { 0, 0, 4 },
				size = { 8, 8 },
			},
		},
		{
			pass_type = "rect",
			style_id = "label_bg",
			style = {
				color = { 180, 0, 0, 0 },
				offset = { 12, 0, 4 },
				size = { 1, 1 },
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			value = "",
			style = {
				font_type = "machine_medium",
				font_size = 14,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = UIHudSettings.color_tint_main_1,
				drop_shadow = true,
				offset = { 12, 0, 5 },
				size = { 240, 20 },
			},
		},
	}, "player_marker_" .. i)
end

for i = 1, MAX_TRIGGER_MARKERS do
	widget_definitions["trigger_marker_" .. i] = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "tick",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				color = UIHudSettings.color_tint_main_1,
				offset = { 0, 0, 3 },
				size = { 6, 6 },
			},
		},
		{
			pass_type = "rect",
			style_id = "label_bg",
			style = {
				color = { 180, 0, 0, 0 },
				offset = { 12, 0, 3 },
				size = { 1, 1 },
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			value = "",
			style = {
				font_type = "machine_medium",
				font_size = 12,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = UIHudSettings.color_tint_main_1,
				drop_shadow = true,
				offset = { 12, 0, 4 },
				size = { 200, 16 },
			},
		},
	}, "trigger_marker_" .. i)
end

widget_definitions.max_marker = UIWidget.create_definition({
	{
		pass_type = "rect",
		style_id = "tick",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			color = UIHudSettings.color_tint_main_1,
			offset = { 0, 0, 5 },
			size = { 10, 10 },
		},
	},
	{
		pass_type = "rect",
		style_id = "label_bg",
		style = {
			color = { 180, 0, 0, 0 },
			offset = { 12, 0, 5 },
			size = { 1, 1 },
		},
	},
	{
		pass_type = "text",
		style_id = "label",
		value_id = "label",
		value = "MAX",
		style = {
			font_type = "machine_medium",
			font_size = 12,
			text_horizontal_alignment = "left",
			text_vertical_alignment = "center",
			text_color = UIHudSettings.color_tint_main_1,
			drop_shadow = true,
			offset = { 12, 0, 6 },
			size = { 120, 16 },
		},
	},
}, "max_marker")

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	max_players = MAX_PLAYER_MARKERS,
	max_triggers = MAX_TRIGGER_MARKERS,
}
