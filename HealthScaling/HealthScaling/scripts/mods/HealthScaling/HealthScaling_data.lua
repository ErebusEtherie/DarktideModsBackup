local mod = get_mod("HealthScaling")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
		{
			setting_id = "toughnessScale",
			type = "numeric",
			default_value = 1.0,
			range = {0.1, 5},
			decimals_number = 1,  
		},
		{
			setting_id = "healthScale",
			type = "numeric",
			default_value = 1.0,
			range = {0.1, 5},
			decimals_number = 1,  
		},
		{
			setting_id = "toughnessAnimation",
			type = "checkbox",
			default_value = true
		},
		{
			setting_id = "animationSpeed",
			type = "numeric",
			default_value = 2.5,
			range = {0.25, 5},
			decimals_number = 1,  
		},
		{
			setting_id = "logScaling",
			type = "checkbox",
			default_value = false
		},
		{
			setting_id = "logScale",
			type = "numeric",
			default_value = 5,
			range = {2, 30}, 
		},
		{
			setting_id = "moveBuffs",
			type = "checkbox",
			default_value = true
		},
		{
			setting_id = "moveCoherency",
			type = "checkbox",
			default_value = true
		},
	}
}
}
