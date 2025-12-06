local ConstantElementNotificationFeedSettings = require("scripts/ui/constant_elements/elements/notification_feed/constant_element_notification_feed_settings")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local header_size = ConstantElementNotificationFeedSettings.header_size
local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	background = {
		horizontal_alignment = "left",
		parent = "screen",
		vertical_alignment = "top",
		size = {
			header_size[1],
			250,
		},
		position = {
			0,
			50,
			0,
		},
	},
}

local function create_notification_message_icon(scenegraph_id)
	local description_font_settings = UIFontSettings.hud_body
	local side_offset = 10
	local icon_size = {
		10,
		10,
	}

	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "icon",
			value = "",
			value_id = "icon",
			style = {
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "top",
				offset = {
					icon_size[1] + side_offset,
					0,
					2,
				},
				font_type = description_font_settings.font_type,
				font_size = description_font_settings.font_size,
				material_values = {},
				size = {
					22,
					22,
				},
			},
		},
	}, scenegraph_id)
end

local widget_definitions = {}

return {
	notification_message_icon = create_notification_message_icon("background"),
	widget_definitions = widget_definitions,
	scenegraph_definition = scenegraph_definition,
}
