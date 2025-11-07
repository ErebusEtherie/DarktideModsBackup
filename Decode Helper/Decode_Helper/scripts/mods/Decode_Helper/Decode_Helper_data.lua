local mod = get_mod("Decode_Helper")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets =
		{
			{
				setting_id = "highlight_opacity",
				type = "numeric",
				default_value = 100,
				range = {0, 255},
				decimals_number = 0
			},
			{
				setting_id = "reveal_count",
				type = "dropdown",
				default_value = 3,
				options = {
					{text = "num_1", value = 1},
					{text = "num_2", value = 2},
					{text = "num_3", value = 3}
				},
			},
		},
	},
}
