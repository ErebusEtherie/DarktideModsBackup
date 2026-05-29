local mod = get_mod("TheEmperorProtects")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "mod_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "toggle_mod",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id      = "toggle_mod_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "toggle_mod",
					},
				}
			},
			{
				setting_id  = "psyker_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "prevent_overload",
						type          = "checkbox",
						default_value = true,
						sub_widgets   = {
							{
								setting_id    = "allow_when_warp_unbound_active",
								type          = "checkbox",
								default_value = true,
							},
							{
								setting_id    = "allow_when_venting_shriek_available",
								type          = "checkbox",
								default_value = false,
							},
							{
								setting_id    = "allow_when_scriers_gaze_available",
								type          = "checkbox",
								default_value = false,
							},
						}
					},
					{
						setting_id    = "auto_use_ability",
						type          = "checkbox",
						default_value = false,
					}
				}
			},
		}
	}
}
