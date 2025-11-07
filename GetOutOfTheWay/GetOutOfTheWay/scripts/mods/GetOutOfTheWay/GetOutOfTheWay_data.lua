local mod = get_mod("GetOutOfTheWay")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "min_distance",
				type = "numeric",
				default_value = 1.5,
				range = { 0, 20 },
				decimals_number = 2,
			},
			{
				setting_id = "max_distance",
				type = "numeric",
				default_value = 10.0,
				range = { 0, 20 },
				decimals_number = 2,
			},
			{
				setting_id = "max_height_difference",
				type = "numeric",
				default_value = 10.0,
				range = { 0, 20 },
				decimals_number = 2,
			},
			{
				setting_id = "only_ogryn",
				type = "checkbox",
				default_value = false,
			},
		}
	}
}
