local mod = get_mod("AutoLoot")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
		{
			setting_id = "open_chests",
			type = "checkbox",
			default_value = true,
		},
		{
			setting_id = "pickup_materials",
			type = "checkbox",
			default_value = true,
		},
		{
			setting_id = "pickup_stimms",
			type = "checkbox",
			default_value = true,
		},
		{
			setting_id = "pickup_crates",
			type = "checkbox",
			default_value = true,
		},
		{
			setting_id  = "grenadesammo_group",
			type        = "group",
			sub_widgets = {
				{
					setting_id = "pickup_grenades",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "grenades_threshold",
					type = "numeric",
					default_value = 1,
					range = {0, 5},
					decimals_number = 0,  
				},
				{
					setting_id = "pickup_ammo",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "ammo_threshold",
					type = "numeric",
					default_value = 50,
					range = {1, 100},
					decimals_number = 0,  
				},
			}
		},
	}
}
}
