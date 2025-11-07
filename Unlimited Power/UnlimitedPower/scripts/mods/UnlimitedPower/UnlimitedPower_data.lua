local mod = get_mod("UnlimitedPower")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id      = "mod_volume",
				title           = "mod_volume_title",
				type            = "numeric",
				range           = { 0, 100 },
				tooltip         = "mod_volume_description",
				default_value   = 50,
				decimals_number = 0,
			},
			{
				setting_id      = "mod_chance",
				title           = "mod_chance_title",
				type            = "numeric",
				range           = { 0, 100 },
				tooltip         = "mod_chance_description",
				default_value   = 10,
				decimals_number = 0,
			},
			{
				setting_id    = "mod_shadow",
				type          = "checkbox",
				title         = "mod_shadow_title",
				tooltip       = "mod_shadow_description",
				default_value = false,
			},
		},
	},
}
