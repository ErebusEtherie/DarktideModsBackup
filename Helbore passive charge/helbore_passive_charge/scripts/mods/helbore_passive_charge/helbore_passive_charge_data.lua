local mod = get_mod("helbore_passive_charge")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id  = "keybinds",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "pressed_passive_charge",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "_toggle_select",
					}
                }
            }
        }
    }
}
