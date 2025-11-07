local mod = get_mod("AutoVault")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "onlyForward",
				type = "checkbox",
				default_value = true
			},
	}
}
}
