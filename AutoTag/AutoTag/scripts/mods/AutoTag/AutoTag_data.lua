local mod = get_mod("AutoTag")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
		{
			setting_id = "cd",
			type = "numeric",
			default_value = 10,
			range = {2, 30},
			decimals_number = 1,  
		},
		{
			setting_id = "manualoverride",
			type = "checkbox",
			default_value = false
		},
		{
			setting_id = "refresh",
			type = "checkbox",
			default_value = true
		},
	}
}
}
