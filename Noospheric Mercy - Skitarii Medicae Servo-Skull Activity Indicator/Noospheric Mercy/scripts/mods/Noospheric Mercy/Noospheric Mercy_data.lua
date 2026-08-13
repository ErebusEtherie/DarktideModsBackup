local mod = get_mod("Noospheric Mercy")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "broadcast_enabled",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "broadcast_only_when_multiple",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_others",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "rescue_marker_enabled",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "hack_marker_enabled",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "outline_priority",
				type = "numeric",
				default_value = 5,
				range = { 1, 10 },
				decimals_number = 0,
			},
			{
				setting_id = "verbose_logging",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
