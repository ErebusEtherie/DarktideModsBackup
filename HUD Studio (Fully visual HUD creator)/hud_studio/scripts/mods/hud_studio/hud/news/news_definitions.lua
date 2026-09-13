---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local UIWidget = require("scripts/managers/ui/ui_widget")
local Text = require("scripts/utilities/ui/text")

local WINDOW_SIZE = { 1220, 800 }

local GRID_WIDTH = 1000
local GRID_HEIGHT = WINDOW_SIZE[2]
local GRID_PIVOT_X = 0
local EDGE_PADDING = 40

local CONTENT_PADDING_Y = 40

local WRAP_HEIGHT = 4000

---@param indent number|nil
local function text_style(font_size, font_type, color, indent, align)
	indent = indent or 0

	return {
		font_size = font_size,
		font_type = font_type,
		text_color = color,
		text_horizontal_alignment = align or "left",
		text_vertical_alignment = "top",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { GRID_WIDTH - indent, WRAP_HEIGHT },
		offset = { indent, 0, 2 },
	}
end

local blueprints = {

	text = {
		size = { GRID_WIDTH, 20 },
		size_function = function(parent, element, ui_renderer)
			local height = Text.text_height(ui_renderer, element.text, element.style, element.style.size)

			return { GRID_WIDTH, height + 11 }
		end,
		pass_template = {
			{
				pass_type = "text",
				value_id = "text",
				style_id = "text",
				value = "",
				style = {},
			},
		},
		init = function(parent, widget, element)
			widget.content.text = element.text

			for key, value in pairs(element.style) do
				widget.style.text[key] = value
			end
		end,
	},
	divider = {
		size = { GRID_WIDTH, 28 },
		pass_template = {
			{
				pass_type = "rect",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					size = { GRID_WIDTH, 4 },
					offset = { 0, 0 },
					color = Color.terminal_frame(100, true),
				},
			},
		},
	},
	spacing = {
		size = { GRID_WIDTH, 20 },
		size_function = function(parent, element)
			return { GRID_WIDTH, element.height or 20 }
		end,
	},
}

local grid_settings = {
	scrollbar_width = 4,
	use_terminal_background = false,
	title_height = 0,
	grid_spacing = { 0, 0 },
	grid_size = { GRID_WIDTH, GRID_HEIGHT },
	mask_size = { GRID_WIDTH + EDGE_PADDING, GRID_HEIGHT },
	edge_padding = EDGE_PADDING,
}

local scenegraph_definition = {
	screen = {
		scale = "fit",
		size = { 1920, 1080 },
		position = { 0, 0, 100 },
	},
	window = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = WINDOW_SIZE,
		position = { 100, 0, 101 },
	},
	grid_pivot = {
		parent = "window",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { 0, 0 },
		position = { GRID_PIVOT_X, 0, 102 },
	},

	close_hint = {
		parent = "window",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { WINDOW_SIZE[1], 60 },
		position = { 0, 0, 100 },
	},
}

local widget_definitions = {

	screen_dim = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = Color.black(50, true),
				offset = { 0, 0, 0 },
			},
		},
	}, "screen"),
	window = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = Color.black(100, true),
				offset = { 0, 20, 0 },
				size = { GRID_WIDTH },
				size_addition = { 36, -40 },
			},
		},
	}, "window"),
	close_hint = UIWidget.create_definition({
		{
			name = "close_hint",
			pass_type = "text",
			value = mod:localize("news_close_hint"),
			style = {
				font_size = 36,
				font_type = "machine_medium",
				text_color = Color.terminal_text_header(255, true),
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				horizontal_alignment = "center",
				vertical_alignment = "center",
				offset = { -100, -100, 1 },
			},
		},
	}, "close_hint"),
}

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	blueprints = blueprints,
	grid_settings = grid_settings,
	text_style = text_style,
	grid_width = GRID_WIDTH,
	content_padding_y = CONTENT_PADDING_Y,
}
