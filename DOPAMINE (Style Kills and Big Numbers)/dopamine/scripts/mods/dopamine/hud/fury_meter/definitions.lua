

---@type mod
local mod = get_mod("dopamine")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local FuryMeterPresentation = mod:core(mod.fury_meter_presentation, "hud/fury_meter/presentation")
local FuryMeterConstants = mod:core(mod.fury_meter_constants, "hud/fury_meter/constants")

local color_foreground_muted = mod.constants.COLOR.UI_FOREGROUND_MUTED
local color_border = mod.constants.COLOR.UI_BORDER
local color_border_muted = mod.constants.COLOR.UI_BORDER_MUTED

local color_initial_fill = mod.constants.COLOR.NUMBERS.YELLOW

local UI_FRAME_TICK_H = FuryMeterConstants.PRESENTATION.UI_FRAME_H + FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_DROP

local function stat_part_style(width, color, z_layer)
	return {
		font_type = mod.dl.fonts.reg.mono_tide_bold,
		font_size = 14,
		drop_shadow = true,
		horizontal_alignment = "center",
		vertical_alignment = "center",
		text_horizontal_alignment = "left",
		text_vertical_alignment = "center",
		text_color = color,
		size = { width, FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT },
		offset = { 0, 222, z_layer or 6 },
	}
end

local function text_style(font_size, halign, color, z_layer)
	return {
		font_type = mod.dl.fonts.reg.proxima_nova_medium,
		font_size = font_size,
		drop_shadow = false,
		horizontal_alignment = "center",
		vertical_alignment = "center",
		text_horizontal_alignment = halign or "center",
		text_vertical_alignment = "center",
		text_color = color,
		size = { FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH, 30 },
		offset = { 0, 222, z_layer or 6 },
	}
end

local function build_stat_passes()
	local passes = {}

	for segment = 1, 4 do
		passes[#passes + 1] = {
			value_id = "seg" .. segment .. "_lbl",
			style_id = "seg" .. segment .. "_lbl",
			pass_type = "text",
			value = "",
			style = stat_part_style(46, color_foreground_muted, 6),
		}
		passes[#passes + 1] = {
			value_id = "seg" .. segment .. "_val",
			style_id = "seg" .. segment .. "_val",
			pass_type = "text",
			value = "",
			style = stat_part_style(38, mod.constants.COLOR.UI_FOREGROUND, 6),
		}
		if segment < 4 then
			passes[#passes + 1] = {
				value_id = "sep" .. segment,
				style_id = "sep" .. segment,
				pass_type = "text",
				value = "",
				style = stat_part_style(FuryMeterConstants.PRESENTATION.SEPARATOR_WIDTH, color_foreground_muted, 6),
			}
		end
	end

	return passes
end

local function build_callout_passes()
	local passes = {}

	if FuryMeterConstants.PRESENTATION.CALLOUT_SHADOW_ENABLE then
		local shadow_color = FuryMeterConstants.PRESENTATION.CALLOUT_SHADOW_COLOR
		local shadow_style = text_style(
			mod.dl.settings.fury_rank_font_size,
			"left",
			{ shadow_color[1], shadow_color[2], shadow_color[3], shadow_color[4] },
			FuryMeterConstants.PRESENTATION.CALLOUT_Z - 1
		)
		shadow_style.drop_shadow = false

		passes[#passes + 1] = {
			value_id = "callout_shadow",
			style_id = "callout_shadow",
			pass_type = "text",
			value = "",
			style = shadow_style,
		}
	end

	passes[#passes + 1] = {
		value_id = "callout_text",
		style_id = "callout_text",
		pass_type = "text",
		value = "",
		style = text_style(
			mod.dl.settings.fury_rank_font_size,
			"left",
			mod.constants.COLOR.UI_FOREGROUND,
			FuryMeterConstants.PRESENTATION.CALLOUT_Z
		),
	}

	return passes
end

local bar_size =
	{ FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT }

local OVERKILL_STAGE_COUNT = FuryMeterPresentation.overkill_stage_count()

local Z_CHROME = 4 + OVERKILL_STAGE_COUNT * 2 + 1

local function add_overkill_passes(passes)
	for stage = 1, OVERKILL_STAGE_COUNT do
		passes[#passes + 1] = {
			pass_type = "rect",
			style_id = "ghost_overkill_" .. stage,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { 0, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT },
				offset = { 0, 222, 3 + stage * 2 },
				color = color_initial_fill,
			},
		}
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = "fill_overkill_" .. stage,
			value = FuryMeterConstants.PRESENTATION.TEX_FILL,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { 0, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT },
				offset = { 0, 222, 4 + stage * 2 },
				color = color_initial_fill,
			},
		}
	end

	return passes
end

return {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		furyMeterContainer = {
			parent = "screen",
			vertical_alignment = "top",
			horizontal_alignment = "center",
			size = bar_size,
			position = { 0, 0, 19 },
		},
	},

	widget_definitions = {
		bar = UIWidget.create_definition(
			add_overkill_passes({
				{
					pass_type = "texture",
					style_id = "grit",
					value = FuryMeterConstants.PRESENTATION.TEX_GRIT,
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH + 6,
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT + 6,
						},
						offset = { 0, 222, 0 },
						color = FuryMeterConstants.PRESENTATION.GRITTY_FRAME_COLOR,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_gritty()
					end,
				},
				{
					pass_type = "rect",
					style_id = "bg",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH,
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT,
						},
						offset = { 0, 222, 1 },
						color = FuryMeterConstants.PRESENTATION.GRITTY_BG,
					},
				},
				{
					pass_type = "rect",
					style_id = "ghost",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { 0, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT },
						offset = { 0, 222, 3 },
						color = color_initial_fill,
					},
				},
				{
					pass_type = "texture",
					style_id = "fill",
					value = FuryMeterConstants.PRESENTATION.TEX_FILL,
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { 0, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT },
						offset = { 0, 222, 4 },
						color = color_initial_fill,
					},
				},
				{
					pass_type = "rect",
					style_id = "ui_notch_1",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { 2, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.8 },
						offset = {
							-FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH * 0.25,
							222 - FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.1,
							Z_CHROME,
						},
						color = mod.dl.colors.to_argb(200, color_border_muted),
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "rect",
					style_id = "ui_notch_2",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { 3, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.8 },
						offset = { 0, 222 - FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.1, Z_CHROME },
						color = mod.dl.colors.to_argb(200, color_border_muted),
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "rect",
					style_id = "ui_notch_3",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { 2, FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.8 },
						offset = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH * 0.25,
							222 - FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT * 0.1,
							Z_CHROME,
						},
						color = mod.dl.colors.to_argb(200, color_border_muted),
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "rect",
					style_id = "ui_frame_l",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_W, UI_FRAME_TICK_H },
						offset = { 0, 222, Z_CHROME + 1 },
						color = color_border,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "rect",
					style_id = "ui_frame_r",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = { FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_W, UI_FRAME_TICK_H },
						offset = { 0, 222, Z_CHROME + 1 },
						color = color_border,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "rect",
					style_id = "ui_frame_h",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH + 10,
							FuryMeterConstants.PRESENTATION.UI_FRAME_H,
						},
						offset = { 0, 222, Z_CHROME + 2 },
						color = color_border,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_ui()
					end,
				},
				{
					pass_type = "texture",
					style_id = "shadow",
					value = FuryMeterConstants.PRESENTATION.TEX_SHADOW,
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH,
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT,
						},
						offset = { 0, 222, Z_CHROME },
						color = FuryMeterConstants.PRESENTATION.GRITTY_SHADOW_COLOR,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_gritty()
					end,
				},
				{
					pass_type = "texture",
					style_id = "highlight",
					value = FuryMeterConstants.PRESENTATION.TEX_HIGHLIGHT,
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						size = {
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH,
							FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT,
						},
						offset = { 0, 222, Z_CHROME + 1 },
						color = FuryMeterConstants.PRESENTATION.GRITTY_HIGHLIGHT_COLOR,
					},
					visibility_function = function()
						return FuryMeterPresentation.theme_gritty()
					end,
				},
			}),
			"furyMeterContainer"
		),

		stats = UIWidget.create_definition(build_stat_passes(), "furyMeterContainer"),

		caps = UIWidget.create_definition({
			{
				value_id = "left",
				style_id = "left",
				pass_type = "text",
				value = "",
				style = text_style(15, "center", FuryMeterConstants.PRESENTATION.CAP_TEXT_COLOR, 6),
			},
			{
				value_id = "right",
				style_id = "right",
				pass_type = "text",
				value = "",
				style = text_style(15, "center", FuryMeterConstants.PRESENTATION.CAP_TEXT_COLOR, 6),
			},
		}, "furyMeterContainer"),

		callout = UIWidget.create_definition(build_callout_passes(), "furyMeterContainer"),
	},
}
