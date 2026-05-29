local mod = get_mod("SprintRelicHeavy")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "override_sprint",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "helper_hotkey",
				type = "keybind",
				default_value = {},
				keybind_trigger = "held",
				keybind_type = "function_call",
				function_name = "helper_hotkey",
			},
			{
				setting_id = "use_block_cancel",
				type = "checkbox",
				default_value = true,
			},
		},
	},
}
