
---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local StyleMeterPresentation = mod:core(mod.style_meter_presentation, "hud/style_meter/presentation")
local Constants = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION

local color_ui_foreground = mod.constants.COLOR.UI_FOREGROUND
local color_numbers_green = mod.constants.COLOR.NUMBERS.GREEN

local function text_style(font_size, color, z_layer, halign, font_type_override)
	return {
		font_type = font_type_override or StyleMeterPresentation.event_font_type(),
		font_size = font_size,
		drop_shadow = true,
		horizontal_alignment = halign or "right",
		vertical_alignment = "center",
		text_horizontal_alignment = halign or "right",
		text_vertical_alignment = "center",
		text_color = color,
		size = { Constants.TEXT_WIDTH, font_size + math.floor(8 * Constants.UI_SCALE + 0.5) },
		offset = { 0, 0, z_layer or 0 },
	}
end

---@param style_id string
---@param z_layer number
---@param color argb_table
---@return table pass
local function mult_bar_pass(style_id, z_layer, color)
	return {
		pass_type = "rect",
		style_id = style_id,
		style = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			size = { 0, Constants.MULT_BAR_HEIGHT },
			offset = { 0, 0, z_layer },
			color = { 0, color[2], color[3], color[4] },
		},
	}
end

local function build_event_list_passes()
	local passes = {

		mult_bar_pass("mult_bar_track", Constants.Z_MULT_BAR_TRACK, Constants.MULT_BAR_TRACK_COLOR),
		mult_bar_pass("mult_bar_fill", Constants.Z_MULT_BAR_FILL, Constants.MULT_BAR_FILL_COLOR),
		{
			value_id = "mult_label",
			style_id = "mult_label",
			pass_type = "text",
			value = "",
			style = text_style(
				StyleMeterPresentation.multiplier_label_font_size(),
				color_ui_foreground,
				Constants.Z_EVENT_ROWS + 1,
				"right",
				mod.dl.fonts.reg.mono_tide_medium
			),
		},
		{
			value_id = "mult_value",
			style_id = "mult_value",
			pass_type = "text",
			value = "",
			style = text_style(
				StyleMeterPresentation.event_font_size(),
				Constants.MULT_VALUE_COLOR_LOW,
				Constants.Z_EVENT_ROWS + 1,
				"right",
				mod.dl.fonts.reg.mono_tide_medium
			),
		},
	}

	for slot = 1, Constants.MAX_SLOTS do
		passes[#passes + 1] = {
			value_id = "slot_" .. slot,
			style_id = "slot_" .. slot,
			pass_type = "text",
			value = "",
			style = text_style(
				StyleMeterPresentation.event_font_size(),
				color_ui_foreground,
				Constants.Z_EVENT_ROWS,
				"right"
			),
		}
		passes[#passes + 1] = {
			value_id = "slot_" .. slot .. "_count",
			style_id = "slot_" .. slot .. "_count",
			pass_type = "text",
			value = "",
			style = text_style(
				StyleMeterPresentation.event_font_size(),
				color_ui_foreground,
				Constants.Z_EVENT_ROWS,
				"right"
			),
		}
	end

	return passes
end

local function build_sp_popup_passes()

	return {
		{
			value_id = "popup",
			style_id = "popup",
			pass_type = "text",
			value = "",
			style = text_style(
				Constants.SP_POPUP_FONT_SIZE,
				color_numbers_green,
				Constants.Z_POPUP,
				"right",
				mod.dl.fonts.reg.mono_tide_medium
			),
		},
	}
end

local function build_event_panel_passes()
	return {
		{
			pass_type = "texture_uv",
			style_id = "background",
			value = Constants.EVENT_PANEL_TEXTURE,
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				size = { Constants.EVENT_PANEL_WIDTH, 60 },
				offset = { 0, 0, Constants.Z_EVENT_PANEL },
				color = Constants.EVENT_PANEL_BG_COLOR,
				uvs = {
					{ 0, 0 },
					{ 1, 1 },
				},
			},
		},
	}
end

local function build_sp_panel_passes()
	return {
		{
			pass_type = "texture_uv",
			style_id = "background",
			value = Constants.SP_PANEL_TEXTURE,
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				size = { Constants.SP_PANEL_WIDTH, 60 },
				offset = { 0, 0, Constants.Z_SP_PANEL },
				color = Constants.SP_PANEL_BG_COLOR,
				uvs = {
					{ 0, 0 },
					{ 1, 1 },
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "border_right",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				size = { 4, 60 },
				offset = { 0, 0, Constants.Z_SP_PANEL + 1 },
				color = Constants.SP_PANEL_BORDER_COLOR,
			},
		},
	}
end

local function build_combo_sp_popup_passes()
	return {
		{
			value_id = "combo_main",
			style_id = "combo_main",
			pass_type = "text",
			value = "",
			style = text_style(Constants.SP_POPUP_FONT_SIZE, color_numbers_green, Constants.Z_POPUP, "right"),
		},
		{
			value_id = "combo_mult",
			style_id = "combo_mult",
			pass_type = "text",
			value = "",
			style = text_style(
				Constants.SP_COMBO_MULT_FONT_SIZE,
				mod.constants.COLOR.NUMBERS.GREEN_MUTED,
				Constants.Z_POPUP,
				"right"
			),
		},
	}
end

return {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		styleMeterRoot = {
			parent = "screen",
			vertical_alignment = "center",
			horizontal_alignment = "right",
			size = {
				Constants.ROOT_WIDTH,
				Constants.ROOT_HEIGHT,
			},
			position = { -Constants.ROOT_MARGIN_X, Constants.ROOT_OFFSET_Y, 19 },
		},
	},

	widget_definitions = {
		event_panel = UIWidget.create_definition(build_event_panel_passes(), "styleMeterRoot"),
		sp_panel = UIWidget.create_definition(build_sp_panel_passes(), "styleMeterRoot"),
		event_list = UIWidget.create_definition(build_event_list_passes(), "styleMeterRoot"),
		sp_counter = UIWidget.create_definition({
			{
				value_id = "sp_label",
				style_id = "sp_label",
				pass_type = "text",
				value = "STYLE POINTS",
				style = text_style(
					Constants.SP_LABEL_FONT_SIZE,
					mod.constants.COLOR.UI_BORDER,
					Constants.Z_SP,
					"right",
					mod.dl.fonts.reg.arial
				),
			},
			{
				value_id = "sp_value",
				style_id = "sp_value",
				pass_type = "text",
				value = "0",
				style = text_style(
					Constants.SP_FONT_SIZE,
					mod.constants.COLOR.NUMBERS.YELLOW,
					Constants.Z_SP,
					"right",
					mod.dl.fonts.reg.mono_tide_medium
				),
			},
		}, "styleMeterRoot"),
		sp_popups = UIWidget.create_definition(build_sp_popup_passes(), "styleMeterRoot"),
		combo_sp_popup = UIWidget.create_definition(build_combo_sp_popup_passes(), "styleMeterRoot"),
	},
}
