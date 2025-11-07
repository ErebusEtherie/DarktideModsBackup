local mod = get_mod("clear_smoke")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            {
                setting_id = "remove_smoke",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_radius",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "pulse_effect",
                type = "checkbox",
                default_value = true,
            },
            {
				setting_id = "color_r",
				type = "numeric",
				default_value = 255,
				range = {0, 255},
				decimals_number = 0,
			},
			{
				setting_id = "color_g",
				type = "numeric",
				default_value = 255,
				range = {0, 255},
				decimals_number = 0,
			},
			{
				setting_id = "color_b",
				type = "numeric",
				default_value = 255,
				range = {0, 255},
				decimals_number = 0,
			},
        }
    }
}