local mod = get_mod("NoPetsLeftBehind")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "use_alternative_pos",
				type = "checkbox",
				default_value = true,
			},
		},
	}
}