local mod = get_mod("Triage")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "health_threshold",			
				type = "numeric",
				default_value = 100,
				range = {0, 100},
			},
		}
	}
}
