local mod = get_mod("IWantToHear")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
        widgets = {
			{ setting_id = "bullet", type = "checkbox", default_value = false, },
			{ setting_id = "dog", type = "checkbox", default_value = false, },
		}
	}
}
