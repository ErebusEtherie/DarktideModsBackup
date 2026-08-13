

---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local Constants = mod:core(mod.stat_chart_constants, "hud/stat_chart/constants").PRESENTATION

---@param font_size number
---@param argb_color argb_table
---@param z_layer number
---@param font_type string
---@return table style
local function text_style(font_size, argb_color, z_layer, font_type)
	return {
		font_type = font_type,
		font_size = font_size,
		drop_shadow = true,
		horizontal_alignment = "right",
		vertical_alignment = "top",
		text_horizontal_alignment = "right",
		text_vertical_alignment = "top",
		text_color = argb_color,
		size = { Constants.TEXT_WIDTH, font_size + math.floor(8 * Constants.UI_SCALE + 0.5) },
		offset = { 0, 0, z_layer },
	}
end

---@param style_id string
---@param z_layer number
---@param color argb_table
---@return table pass
local function bar_pass(style_id, z_layer, color)
	return {
		pass_type = "rect",
		style_id = style_id,
		style = {
			horizontal_alignment = "right",
			vertical_alignment = "top",
			size = { 0, Constants.BAR_HEIGHT },
			offset = { 0, 0, z_layer },
			color = { color[1], color[2], color[3], color[4] },
		},
	}
end

---@return table[] passes
local function build_row_passes()
	local passes = {}

	for row = 1, Constants.MAX_ROWS do

		passes[#passes + 1] = bar_pass("track_" .. row, Constants.Z_BAR_TRACK, Constants.BAR_TRACK_COLOR)
		passes[#passes + 1] = bar_pass("fill_" .. row, Constants.Z_BAR_FILL, mod.constants.COLOR.NUMBERS.YELLOW)

		passes[#passes + 1] = {
			value_id = "name_" .. row,
			style_id = "name_" .. row,
			pass_type = "text",
			value = "",
			style = text_style(Constants.NAME_FONT_SIZE, Constants.NAME_COLOR, Constants.Z_TEXT, mod.dl.fonts.reg.proxima_nova_medium),
		}
		passes[#passes + 1] = {
			value_id = "value_" .. row,
			style_id = "value_" .. row,
			pass_type = "text",
			value = "",
			style = text_style(Constants.VALUE_FONT_SIZE, Constants.VALUE_COLOR, Constants.Z_TEXT, mod.dl.fonts.reg.mono_tide_medium),
		}
	end

	return passes
end

---@return table[] passes
local function build_panel_passes()
	return {
		{
			pass_type = "texture_uv",
			style_id = "background",
			value_id = "background",
			value = Constants.PANEL_TEXTURE,
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "top",
				size = { Constants.PANEL_WIDTH, 60 },
				offset = { 0, 0, Constants.Z_PANEL },
				color = { Constants.PANEL_BG_COLOR[1], Constants.PANEL_BG_COLOR[2], Constants.PANEL_BG_COLOR[3], Constants.PANEL_BG_COLOR[4] },
				uvs = {
					{ 0, 0 },
					{ 1, 1 },
				},
			},
		},

		{
			pass_type = "rect",
			style_id = "border",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "top",
				size = { Constants.PANEL_BORDER_WIDTH, 60 },
				offset = { 0, 0, Constants.Z_BORDER },
				color = { Constants.PANEL_BORDER_COLOR[1], Constants.PANEL_BORDER_COLOR[2], Constants.PANEL_BORDER_COLOR[3], Constants.PANEL_BORDER_COLOR[4] },
			},
		},
	}
end

---@return table[] passes
local function build_title_passes()
	return {
		{
			value_id = "title",
			style_id = "title",
			pass_type = "text",
			value = "",

			style = text_style(Constants.TITLE_FONT_SIZE, Constants.TITLE_COLOR, Constants.Z_TITLE, mod.dl.fonts.reg.mono_tide_medium),
		},
	}
end

return {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		statChartRoot = {
			parent = "screen",
			vertical_alignment = "top",
			horizontal_alignment = "right",
			size = {
				Constants.ROOT_WIDTH,
				Constants.MAX_ROWS * Constants.ROW_HEIGHT,
			},
			position = { -Constants.ROOT_MARGIN_X, Constants.ROOT_OFFSET_Y, 19 },
		},
	},

	widget_definitions = {
		chart_panel = UIWidget.create_definition(build_panel_passes(), "statChartRoot"),
		chart_rows = UIWidget.create_definition(build_row_passes(), "statChartRoot"),
		chart_title = UIWidget.create_definition(build_title_passes(), "statChartRoot"),
	},
}
