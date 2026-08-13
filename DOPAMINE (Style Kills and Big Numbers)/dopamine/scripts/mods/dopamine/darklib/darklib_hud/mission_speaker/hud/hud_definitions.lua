

---@param module DLH_MissionSpeaker
return function(module)
	local UIWidget = require("scripts/managers/ui/ui_widget")
	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
	local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
	local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

	local scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		missionSpeakerContainer = {
			parent = "screen",
			horizontal_alignment = "right",
			vertical_alignment = "top",
			size = module.constants.PRESENTATION.PORTRAIT_SIZE,
			position = { 0, 0, module.constants.PRESENTATION.Z },
		},
	}

	local name_text_style = table.clone(UIFontSettings.hud_body)

	name_text_style.horizontal_alignment = "right"
	name_text_style.vertical_alignment = "top"
	name_text_style.text_horizontal_alignment = "right"
	name_text_style.text_vertical_alignment = "bottom"
	name_text_style.size = { 650, 40 }
	name_text_style.offset = { module.presentation_manager.text_offset_x(), 15, 2 }
	name_text_style.drop_shadow = true
	name_text_style.font_size = 24

	local title_text_style = table.clone(name_text_style)

	title_text_style.offset = { module.presentation_manager.text_offset_x(), -10, 2 }
	title_text_style.text_color = UIHudSettings.color_tint_main_2

	local subtitle_text_style = table.clone(name_text_style)

	subtitle_text_style.size = { module.constants.PRESENTATION.SUBTITLE_WIDTH, 60 }
	subtitle_text_style.offset = { 0, module.constants.PRESENTATION.SUBTITLE_OFFSET_Y, 2 }
	subtitle_text_style.font_size = module.constants.PRESENTATION.SUBTITLE_FONT_SIZE
	subtitle_text_style.text_color = table.clone(UIHudSettings.color_tint_main_2)

	local widget_definitions = {
		popup = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "portrait",
				value = "content/ui/materials/base/ui_radio_portrait_base",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "top",
					offset = { 0, 0, 0 },
					color = { 255, 255, 255, 255 },
					material_values = {
						distortion = 1,
					},
				},
			},
			{
				pass_type = "texture",
				style_id = "frame",
				value = "content/ui/materials/hud/backgrounds/weapon_frame",
				style = {
					horizontal_alignment = "right",
					vertical_alignment = "center",
					color = UIHudSettings.color_tint_main_3,
					offset = { 0, 0, 2 },
					size_addition = { 8, 5 },
				},
			},
		}, "missionSpeakerContainer"),
		name_text = UIWidget.create_definition({
			{
				pass_type = "text",
				style_id = "name_text",
				value = "<name_text>",
				value_id = "name_text",
				style = name_text_style,
			},
		}, "missionSpeakerContainer"),
		title_text = UIWidget.create_definition({
			{
				pass_type = "text",
				style_id = "title_text",
				value_id = "title_text",
				value = Localize("loc_mission_speaker_title_text"),
				style = title_text_style,
			},
		}, "missionSpeakerContainer"),
		subtitle = UIWidget.create_definition({
			{
				pass_type = "text",
				style_id = "subtitle",
				value_id = "subtitle",
				value = "",
				style = subtitle_text_style,
			},
		}, "missionSpeakerContainer"),
		radio = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "soundwave",
				value = "content/ui/materials/icons/hud/radio",
				style = {
					horizontal_alignment = "left",
					vertical_alignment = "top",
					size = { module.constants.PRESENTATION.RADIO_SIZE[1], module.constants.PRESENTATION.RADIO_SIZE[2] },
					offset = {
						module.constants.PRESENTATION.RADIO_OFFSET[1],
						module.constants.PRESENTATION.RADIO_OFFSET[2],
						0,
					},
					color = UIHudSettings.color_tint_main_2,
				},
			},
		}, "missionSpeakerContainer"),
	}

	local bar_size = module.constants.PRESENTATION.BAR_SIZE

	for i = 1, module.constants.PRESENTATION.BAR_AMOUNT do
		local name = "bar_" .. i
		local bar_x = module.presentation_manager.bar_offset_x(i)

		widget_definitions[name] = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "background",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = { bar_size[1], bar_size[2] },
					color = UIHudSettings.color_tint_main_4,
					offset = { bar_x, module.constants.PRESENTATION.BAR_OFFSET[2], 0 },
				},
			},
			{
				pass_type = "texture",
				style_id = "bar",
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = { bar_size[1], bar_size[2] },
					color = UIHudSettings.color_tint_main_2,
					offset = { bar_x, module.constants.PRESENTATION.BAR_OFFSET[2], 1 },
				},
			},
			{
				pass_type = "texture",
				style_id = "frame",
				value = "content/ui/materials/frames/line_light",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "bottom",
					size = { bar_size[1], bar_size[2] },
					color = UIHudSettings.color_tint_main_3,
					size_addition = { 4, 4 },
					offset = { bar_x, module.constants.PRESENTATION.BAR_OFFSET[2] + 2, 2 },
				},
			},
		}, "missionSpeakerContainer")
	end

	local Definitions = {
		widget_definitions = widget_definitions,
		scenegraph_definition = scenegraph_definition,
	}

	return Definitions
end
