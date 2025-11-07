local mod = get_mod("LessAnnoyingFx")


return {
	name = "LessAnnoyingFx",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "setting_power_trail",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "setting_psyker_smite",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "setting_psyker_lightning",
				type = "checkbox",
				default_value = true,
			},

		}
	}
}
