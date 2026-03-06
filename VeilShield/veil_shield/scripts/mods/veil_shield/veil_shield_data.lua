local mod = get_mod("veil_shield")

local widgets = {
	{
		setting_id = "hide_slab_shield",
		type = "checkbox",
		default_value = true,
	},
	{
		setting_id = "hide_suppression_shield",
		type = "checkbox",
		default_value = true,
	},
	{
		setting_id = "shield_opacity",
		type = "numeric",
		default_value = 0.5,
		decimals_number = 1,
		range = {0.3, 1},
	},
	{
		setting_id = "fade_speed",
		type = "numeric",
		default_value = 1,
		decimals_number = 1,
		range = {0.3, 2.0},
	},
}

return {
	name = "VeilShield",
	description = "",
	is_togglable = false,
	options = {
		widgets = widgets
	}
}
