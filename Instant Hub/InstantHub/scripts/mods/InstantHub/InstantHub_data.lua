local mod = get_mod("InstantHub")

mod.data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "hub_caching",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_notifications",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "preload_hub",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "preload_psychanium",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}

return mod.data
