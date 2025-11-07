local mod = get_mod("FXlimiter")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id  = "max_impact_fx_per_frame",
				type        = "numeric",
				default_value = 5,
				range = {0, 20},
				decimals_number = 0
			},
			{
				setting_id = "performance_features",
				type = "group",
				sub_widgets = {
					{
						setting_id = "simpler_blood_decals",
						tooltip = "simpler_blood_decals_desc",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "cheaper_fire",
						tooltip = "cheaper_fire_desc",
						type = "checkbox",
						default_value = true,
					}
				}
			}
		}
	}
}
