local mod = get_mod("shorten_usernames")

return {
	name = "Shorten Usernames",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				tab = "General",
				sub_widgets = {
					{
						setting_id = "shorten_myself",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "shorten_teammates",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "only_in_gameplay",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "truncation_string",
						type = "dropdown",
						default_value = ".",
						options = {
							{text = "truncation_option_ellipsis", value = "..."},
							{text = "truncation_option_two_dots", value = ".."},
							{text = "truncation_option_dot", value = "."},
							{text = "truncation_option_hyphen", value = "-"},
							{text = "truncation_option_tilde", value = "~"},
							{text = "truncation_option_none", value = ""},
						},
					},
				}
			},
			{
				setting_id = "length_settings",
				type = "group",
				tab = "Lengths",
				sub_widgets = {
					{
						setting_id = "header_character",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_shorten_character_name",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "max_length",
								type = "numeric",
								default_value = 20,
								range = {1, 30},
							},
						},
					},
					{
						setting_id = "header_account",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_shorten_account_name",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "max_length_account_name",
								type = "numeric",
								default_value = 20,
								range = {1, 30},
							},
						},
					},
				}
			}
		}
	}
}
