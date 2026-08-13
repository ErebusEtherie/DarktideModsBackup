local mod = get_mod("LoadingBar")

return {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "lb_enabled",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "lb_style",
				type = "dropdown",
				default_value = "heavy",
				options = {
					{ text = "lb_style_heavy", value = "heavy" },
					{ text = "lb_style_simple", value = "simple" },
					{ text = "lb_style_fallback", value = "fallback" },
				},
			},
			{
				setting_id = "lb_show_reason",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "lb_show_percentage",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "lb_scale",
				type = "numeric",
				default_value = 1.0,
				range = { 0.5, 2.0 },
				decimals_number = 2,
			},
			{
				setting_id = "lb_bottom_margin",
				type = "numeric",
				default_value = 90,
				range = { 20, 400 },
				decimals_number = 0,
			},
			{
				setting_id = "lb_hide_spinner",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "lb_hide_wait_text",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
