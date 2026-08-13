

---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local StyleMeterPresentation = mod:core(mod.style_meter_presentation, "hud/style_meter/presentation")
local Constants = mod:core(mod.task_constants, "hud/task/constants").PRESENTATION

---@param font_size number
---@param argb_color argb_table
---@param z_layer number|nil
---@param halign "left"|"right"|nil
---@return table style
local function text_style(font_size, argb_color, z_layer, halign)
	return {
		font_type = StyleMeterPresentation.event_font_type(),
		font_size = font_size,
		drop_shadow = true,
		horizontal_alignment = halign or "right",
		vertical_alignment = "top",
		text_horizontal_alignment = halign or "right",
		text_vertical_alignment = "top",
		text_color = argb_color,
		size = { Constants.TEXT_WIDTH, font_size + math.floor(8 * Constants.UI_SCALE + 0.5) },
		offset = { 0, 0, z_layer or 0 },
	}
end

---@return table[] passes
local function build_row_passes()
	local passes = {}

	for slot = 1, Constants.MAX_SLOTS do
		passes[#passes + 1] = {
			value_id = "line_" .. slot,
			style_id = "line_" .. slot,
			pass_type = "text",
			value = "",
			style = text_style(
				Constants.LINE_FONT_SIZE,
				Constants.COLOR_LINE_BASE,
				Constants.Z_ROWS,
				"right"
			),
		}
		passes[#passes + 1] = {
			value_id = "timer_" .. slot,
			style_id = "timer_" .. slot,
			pass_type = "text",
			value = "",
			style = text_style(
				Constants.TIMER_FONT_SIZE,
				Constants.COLOR_LINE_BASE,
				Constants.Z_ROWS,
				"right"
			),
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
				color = Constants.PANEL_BG_COLOR,
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
				size = { Constants.UI_BORDER_WIDTH, 60 },
				offset = { 0, 0, Constants.Z_BORDER },
				color = Constants.UI_BORDER_COLOR,
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
			style = {

				font_type = mod.dl.fonts.reg.mono_tide_medium,
				font_size = Constants.TITLE_FONT_SIZE,
				drop_shadow = true,
				horizontal_alignment = "right",
				vertical_alignment = "top",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				text_color = Constants.TITLE_COLOR_UI,
				size = { Constants.TEXT_WIDTH, Constants.TITLE_FONT_SIZE + math.floor(8 * Constants.UI_SCALE + 0.5) },
				offset = { 0, 0, Constants.Z_TITLE },
			},
		},
	}
end

return {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		taskTrackRoot = {
			parent = "screen",
			vertical_alignment = "top",
			horizontal_alignment = "right",
			size = {
				Constants.ROOT_WIDTH,
				Constants.PANEL_SLOTS * Constants.ROW_HEIGHT,
			},
			position = { -Constants.ROOT_MARGIN_X, Constants.ROOT_OFFSET_Y, 19 },
		},
	},

	widget_definitions = {
		task_panel = UIWidget.create_definition(build_panel_passes(), "taskTrackRoot"),
		task_rows = UIWidget.create_definition(build_row_passes(), "taskTrackRoot"),
		task_title = UIWidget.create_definition(build_title_passes(), "taskTrackRoot"),
	},
}
