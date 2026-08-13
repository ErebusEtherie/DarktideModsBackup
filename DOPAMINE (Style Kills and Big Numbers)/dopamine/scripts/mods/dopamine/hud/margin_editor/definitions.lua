

---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local Z = 100

local Z_PANEL_BG = 0
local Z_PANEL = 1
local Z_LINE = 2
local Z_HANDLE = 3
local Z_DIVIDER = 4

local LINE_WIDTH = 1

local SCREEN_HEIGHT = UIWorkspaceSettings.screen.size[2]

local BAND_LENGTH = 260

local PANEL_BLEED = 14

local PANEL_MATERIAL_INSET = 14

local DIVIDER_MATERIAL = "content/ui/materials/dividers/skull_rendered_center_03"
local GLOW_MATERIAL = "content/ui/materials/effects/wide_upward_glow"

local HANDLE_LENGTH = 260
local HANDLE_DEPTH = 50

local GLOW_LENGTH = 260
local GLOW_DEPTH = 150

local FRAME_ANGLE = {
	left = -math.pi * 0.5,
	right = math.pi * 0.5,
	top = math.pi,
}

local GLOW_ANGLE = {
	left = -FRAME_ANGLE.left,
	right = -FRAME_ANGLE.right,

	top = 0,
}

local DIVIDER_NUDGE = HANDLE_DEPTH * 0.375
local GLOW_NUDGE = GLOW_DEPTH * 0.5

local DIVIDER_PIVOT = { HANDLE_LENGTH * 0.5, HANDLE_DEPTH * 0.5 }
local GLOW_PIVOT = { GLOW_LENGTH * 0.5, GLOW_DEPTH * 0.5 }

local PANEL_COLOR = { 200, 190, 210, 180 }

local PANEL_BG_COLOR = { 200, 0, 0, 0 }

local LINE_COLOR = { 255, 40, 40, 40 }

local DIVIDER_COLOR = { 255, 255, 255, 255 }

local GLOW_COLOR = { 255, 226, 199, 126 }

local CENTER_HANDLE_LIFT = 80

local HANDLES = {
	{ key = "margin_left", axis = "x", side = "left", art = "left", outward = -1 },
	{ key = "margin_right", axis = "x", side = "right", art = "right", outward = 1 },
	{ key = "offset_left", axis = "y", side = "left", art = "top", outward = -1 },
	{ key = "offset_right", axis = "y", side = "right", art = "top", outward = -1 },
	{
		key = "offset_center",
		axis = "y",
		side = "center",
		art = "top",
		outward = -1,
		display = -CENTER_HANDLE_LIFT,
	},
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
}

for i = 1, #HANDLES do
	local handle = HANDLES[i]
	local horizontal = handle.axis == "x"

	scenegraph_definition["node_" .. handle.key] = {
		parent = "screen",
		horizontal_alignment = handle.side,
		vertical_alignment = "top",

		size = horizontal and { LINE_WIDTH, SCREEN_HEIGHT } or { BAND_LENGTH, LINE_WIDTH },
		position = { 0, 0, Z },
	}
end

local function pass_visible(content)
	return content.visible
end

local widget_definitions = {}

for i = 1, #HANDLES do
	local handle = HANDLES[i]
	local horizontal = handle.axis == "x"

	local divider_nudge = handle.outward * DIVIDER_NUDGE
	local glow_nudge = handle.outward * GLOW_NUDGE
	local divider_offset = horizontal and { divider_nudge, 0, Z_DIVIDER } or { 0, divider_nudge, Z_DIVIDER }
	local glow_offset = horizontal and { glow_nudge, 0, Z_HANDLE } or { 0, glow_nudge, Z_HANDLE }

	widget_definitions["handle_" .. handle.key] = UIWidget.create_definition({

		{
			visibility_function = pass_visible,
			pass_type = "rect",
			style_id = "panel_bg",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				offset = { 0, 0, Z_PANEL_BG },
				size = { 0, 0 },
				color = { PANEL_BG_COLOR[1], PANEL_BG_COLOR[2], PANEL_BG_COLOR[3], PANEL_BG_COLOR[4] },
			},
		},

		{
			visibility_function = pass_visible,
			pass_type = "texture",
			style_id = "panel",
			value = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				scale_to_material = true,
				offset = { 0, 0, Z_PANEL },
				size = { 0, 0 },
				color = { PANEL_COLOR[1], PANEL_COLOR[2], PANEL_COLOR[3], PANEL_COLOR[4] },
			},
		},
		{
			visibility_function = pass_visible,
			pass_type = "rect",
			style_id = "line",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				offset = { 0, 0, Z_LINE },
				size = { 0, 0 },
				color = { LINE_COLOR[1], LINE_COLOR[2], LINE_COLOR[3], LINE_COLOR[4] },
			},
		},

		{
			visibility_function = pass_visible,
			pass_type = "rotated_texture",
			style_id = "glow",
			value = GLOW_MATERIAL,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = GLOW_ANGLE[handle.art],
				pivot = { GLOW_PIVOT[1], GLOW_PIVOT[2] },
				offset = glow_offset,
				size = { GLOW_LENGTH, GLOW_DEPTH },
				color = { 0, GLOW_COLOR[2], GLOW_COLOR[3], GLOW_COLOR[4] },
			},
		},
		{
			visibility_function = pass_visible,
			pass_type = "rotated_texture",
			style_id = "divider",
			value = DIVIDER_MATERIAL,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = FRAME_ANGLE[handle.art],
				pivot = { DIVIDER_PIVOT[1], DIVIDER_PIVOT[2] },
				offset = divider_offset,
				size = { HANDLE_LENGTH, HANDLE_DEPTH },
				color = { DIVIDER_COLOR[1], DIVIDER_COLOR[2], DIVIDER_COLOR[3], DIVIDER_COLOR[4] },
			},
		},
	}, "node_" .. handle.key, { visible = true })
end

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	handles = HANDLES,

	PANEL_ALPHA = PANEL_COLOR[1],
	PANEL_BG_ALPHA = PANEL_BG_COLOR[1],
	LINE_WIDTH = LINE_WIDTH,
	BAND_LENGTH = BAND_LENGTH,
	PANEL_BLEED = PANEL_BLEED,
	PANEL_MATERIAL_INSET = PANEL_MATERIAL_INSET,
	HANDLE_LENGTH = HANDLE_LENGTH,
	HANDLE_DEPTH = HANDLE_DEPTH,
	GLOW_LENGTH = GLOW_LENGTH,
	GLOW_DEPTH = GLOW_DEPTH,
	Z = Z,
}
