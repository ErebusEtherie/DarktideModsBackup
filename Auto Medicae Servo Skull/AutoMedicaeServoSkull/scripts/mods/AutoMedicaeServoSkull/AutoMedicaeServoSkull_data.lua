local mod = get_mod("AutoMedicaeServoSkull")

return {
	name         = mod:localize("mod_name"),
	description  = mod:localize("mod_description"),
	is_togglable = true,
	options      = {
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
					{
						setting_id    = "toggle_mod_notify",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "debug_mode",
						type          = "checkbox",
						default_value = false,
					},
				}
			},
			{
				setting_id = "manual_inject_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id      = "manual_inject_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "manual_inject_held",
					},
					{
						setting_id      = "manual_inject_press_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "manual_inject_press",
					},
				}
			},
			{
				setting_id = "auto_inject_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "auto_inject",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_ignore_bot",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_knocked_down",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_knocked_down_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
					{
						setting_id    = "auto_inject_hogtied",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_hogtied_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
					{
						setting_id    = "auto_inject_netted",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_netted_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
					{
						setting_id    = "auto_inject_ignore_weapon_action",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_inject_ignore_ability_action",
						type          = "checkbox",
						default_value = false,
					},
				}
			},
			{
				setting_id = "auto_release_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "auto_release",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_release_ignore_bot",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_release_knocked_down",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_release_knocked_down_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
					{
						setting_id    = "auto_release_hogtied",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_release_hogtied_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
					{
						setting_id    = "auto_release_netted",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "auto_release_netted_threshold",
						type          = "numeric",
						default_value = 1,
						range         = { 1, 10 },
					},
				}
			},
		}
	}
}
