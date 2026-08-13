local mod = get_mod("TrainSolver")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
		{
			setting_id = "strength",
			type = "numeric",
			default_value = 0.66,
			range = {0.1, 3},
			decimals_number = 2,  
		}
	}
}
}
