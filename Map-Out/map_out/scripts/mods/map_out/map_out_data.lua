local mod = get_mod("map_out")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	
	options = {
        widgets = {
            {
                setting_id = "stow_map_key",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "stow_map_action",
            },
			
			{
                setting_id = "stow_map_key_alt",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "stow_map_action",
            },
			
			{
                setting_id = "hold_mode_keys",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "empty_function",
            },
			
			{
                setting_id      = "wheel_input",
                type            = "checkbox",
                default_value   = false,
            },
		}
	}
}
