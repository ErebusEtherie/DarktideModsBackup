local mod = get_mod("FPS_FIX")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "fps_check",
				type = "checkbox",
				default_value = true,
			},
			{
                setting_id = "fps_scale",
				type = "numeric",
				default_value = 120.0,
				range = { 30.0, 360.0 },
            },
		}
	}
}
