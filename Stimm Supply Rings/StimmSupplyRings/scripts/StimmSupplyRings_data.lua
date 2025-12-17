local mod = get_mod("StimmSupplyRings")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_attack_speed",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_cooldown",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_strength",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_toughness",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "min_investment",
				type = "numeric",
				range = {1, 5},
				default_value = 2,
				tooltip = "min_investment_tooltip",
			},
			{
				setting_id = "min_opacity",
				type = "numeric",
				range = {1, 100},
				default_value = 3,
			},
			{
				setting_id = "max_opacity",
				type = "numeric",
				range = {2, 100},
				default_value = 30,
			},
			{
				setting_id = "opacity_scaling_power",
				type = "numeric",
				range = {0, 3},
				default_value = 2,
				tooltip = "opacity_scaling_power_tooltip",
			},
			{
				setting_id = "enable_logging",
				type = "checkbox",
				default_value = false,
				tooltip = "enable_logging_tooltip",
			}
		}
	}
}
