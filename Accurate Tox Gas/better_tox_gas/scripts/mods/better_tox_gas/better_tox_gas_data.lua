return {
	name = "Better Tox Gas",
	description = "Improves visual duration accuracy of gas created by Tox Bombers.",
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "icon_timer",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "icon_seconds",
				type = "checkbox",
				default_value = true,
			},
		},
	},
}
