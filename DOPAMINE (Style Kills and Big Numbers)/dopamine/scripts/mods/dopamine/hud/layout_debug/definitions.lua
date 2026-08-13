

---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local Z = 50

local BOXES = {
	{ id = "fury", width = 450, color = { 255, 255, 170, 40 } },
	{ id = "style", width = 450, color = { 255, 80, 220, 120 } },
	{ id = "task", width = 250, color = { 255, 230, 110, 210 } },
	{ id = "stats", width = 250, color = { 255, 90, 200, 255 } },
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
}
for _, box in ipairs(BOXES) do
	scenegraph_definition["node_" .. box.id] = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { box.width, 10 },
		position = { 0, 0, Z },
	}
end

local function edge(style_id, color)
	return {
		pass_type = "rect",
		style_id = style_id,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = { 0, 0, Z },
			size = { 0, 0 },
			color = { 0, color[2], color[3], color[4] },
		},
	}
end

local widget_definitions = {}
for _, box in ipairs(BOXES) do
	widget_definitions["box_" .. box.id] = UIWidget.create_definition({
		edge(box.id .. "_top", box.color),
		edge(box.id .. "_bottom", box.color),
		edge(box.id .. "_left", box.color),
		edge(box.id .. "_right", box.color),
	}, "node_" .. box.id)
end

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	boxes = BOXES,
}
