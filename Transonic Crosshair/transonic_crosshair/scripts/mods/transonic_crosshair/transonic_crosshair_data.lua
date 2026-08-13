local mod = get_mod("transonic_crosshair")

return {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "bar_length",
				type = "numeric",
				default_value = 26,
				range = { 4, 80 },
				decimals_number = 0,
				title = "bar_length",
				tooltip = "bar_length_tooltip",
			},
			{
				setting_id = "bar_thickness",
				type = "numeric",
				default_value = 3,
				range = { 1, 12 },
				decimals_number = 0,
				title = "bar_thickness",
				tooltip = "bar_thickness_tooltip",
			},
			{
				setting_id = "swap_modes",
				type = "checkbox",
				default_value = false,
				title = "swap_modes",
				tooltip = "swap_modes_tooltip",
			},
		},
	},
}
