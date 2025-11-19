local mod = get_mod("Disconnect")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id      = "disconnect_description",
				type            = "keybind",
				default_value   = {},
				keybind_trigger = "pressed",
				keybind_type    = "function_call",
				function_name   = "disconnect_keybind_func",
			},
			{
				setting_id = "mod_disconnect",
				type = "dropdown",
				default_value = "exit_to_main_menu",
				options = {
					{text = "opt_main_menu", value = "exit_to_main_menu"},
					{text = "opt_to_hub", value = "leave_to_hub"},
				}
			},
            {
                setting_id = "mod_disconnect_party",
				tooltip = "disconnect_party_tooltip",
                type = "checkbox",
                default_value = false,
            },
		}
	}
}
