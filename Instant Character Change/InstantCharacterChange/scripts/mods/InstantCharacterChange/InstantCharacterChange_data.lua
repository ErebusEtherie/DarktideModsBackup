local mod = get_mod("InstantCharacterChange")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "chat_messages_enabled",
				type = "checkbox",
				default_value = false,
				tooltip = "chat_messages_enabled_tooltip",
			},
			{
				setting_id = "party_announce_enabled",
				type = "checkbox",
				default_value = false,
				tooltip = "party_announce_enabled_tooltip",
				sub_widgets = {
					{
						setting_id = "party_announce_color",
						type = "dropdown",
						default_value = "amber",
						tooltip = "party_announce_color_tooltip",
						options = {
							{ text = "party_color_none", value = "none" },
							{ text = "party_color_amber", value = "amber" },
							{ text = "party_color_steel_blue", value = "steel_blue" },
							{ text = "party_color_green", value = "green" },
							{ text = "party_color_red", value = "red" },
							{ text = "party_color_purple", value = "purple" },
						},
					},
				},
			},
			{
				setting_id = "diagnostics_enabled",
				type = "checkbox",
				default_value = false,
				tooltip = "diagnostics_enabled_tooltip",
			},
			{
				setting_id = "panel_offset_x",
				type = "numeric",
				default_value = 0,
				range = { -1300, 400 },
				decimals_number = 0,
				tooltip = "panel_offset_x_tooltip",
			},
			{
				setting_id = "panel_offset_y",
				type = "numeric",
				default_value = 0,
				range = { -450, 450 },
				decimals_number = 0,
				tooltip = "panel_offset_y_tooltip",
			},
			{
				setting_id = "panel_width",
				type = "numeric",
				default_value = 430,
				range = { 340, 600 },
				decimals_number = 0,
				tooltip = "panel_width_tooltip",
			},
			{
				setting_id = "panel_scale",
				type = "numeric",
				default_value = 100,
				range = { 70, 200 },
				decimals_number = 0,
				tooltip = "panel_scale_tooltip",
			},
			{
				setting_id = "panel_show_level",
				type = "checkbox",
				default_value = true,
				tooltip = "panel_show_level_tooltip",
			},
		},
	},
}
