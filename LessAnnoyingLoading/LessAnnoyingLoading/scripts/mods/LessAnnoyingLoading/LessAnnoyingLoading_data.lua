local mod = get_mod("LessAnnoyingLoading")

return {
	name = "LessAnnoyingLoading",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "setting_text_enable",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "setting_time_enable",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "setting_text_two_lines",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "setting_text_align",
				type = "dropdown",
				default_value = 0,
				options = {
					{ text = "original", value = 0 },
					{ text = "left-bottom", value = 1 },
					{ text = "center-bottom", value = 2 },
					{ text = "right-bottom", value = 3 },
					{ text = "icon-center", value = 4 },
				},
			},
			-- {
			-- 	setting_id = "setting_text_background_enable",
			-- 	type = "checkbox",
			-- 	default_value = false,
			-- },

			-- {
			-- 	setting_id = "setting_last_text_enable",
			-- 	type = "checkbox",
			-- 	default_value = true,
			-- },

			{
				setting_id = "setting_text_font_size",
				type = "numeric",
				default_value = 24,
				range = { 8, 48 },
			},
			{
				setting_id = "setting_text_offset_x",
				type = "numeric",
				default_value = 0,
				range = { -400, 100 },
			},
			{
				setting_id = "setting_text_offset_y",
				type = "numeric",
				default_value = 0,
				range = { -400, 100 },
			},

			{
				setting_id = "setting_text_font_type",
				type = "dropdown",
				default_value = "machine_medium",
				options = {
					{ text = "machine_medium", value = "machine_medium" },
					{ text = "arial", value = "arial" },
					{ text = "proxima_nova_medium", value = "proxima_nova_medium" },
					{ text = "itc_novarese_medium", value = "itc_novarese_medium" },
				},
			},

			{
				setting_id = "setting_text_opacity",
				type = "numeric",
				default_value = 255,
				range = { 16, 255 },
			},
		},
	},
}
