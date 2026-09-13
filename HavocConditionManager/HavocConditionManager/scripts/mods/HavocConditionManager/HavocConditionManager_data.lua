local mod = get_mod("HavocConditionManager")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "open_condition_manager",
				type = "button",
				button_text = "open",
				function_name = "open_condition_manager_view",
			},
		},
	},
}
