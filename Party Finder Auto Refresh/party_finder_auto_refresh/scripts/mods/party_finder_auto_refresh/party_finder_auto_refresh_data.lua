local mod = get_mod("party_finder_auto_refresh")

local widgets = {
    {
        setting_id = "refresh_interval",
        type = "numeric",
        default_value = 10,
        range = { 5, 20 },
        unit_text = "sec",
    },
    {
        setting_id = "toggle_key",
		type = "keybind",
		default_value = {},
		keybind_trigger = "pressed",
		keybind_type = "function_call",
		function_name = "toggle_auto_refresh",
    },
	{
        setting_id = "enable_refresh_notify",
        type = "checkbox",
        default_value = true,
    },
}

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = widgets,
    },
}
