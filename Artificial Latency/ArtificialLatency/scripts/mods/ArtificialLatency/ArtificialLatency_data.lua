local mod = get_mod("ArtificialLatency")

return {
	name = "ArtificialLatency",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "al_ms",
				type = "numeric",
				range = {0, 1000},
				default_value = 0,
			},
		},
	},
}