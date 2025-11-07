local mod = get_mod("HeatPercentage")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "show_when_weapon_inactive",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_when_ability_active",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "hide_fatshark_heat_bar",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "warning_threshold",
				type = "numeric",
				default_value = 85,
				range = {50, 99},
			},
		}
	}
}
