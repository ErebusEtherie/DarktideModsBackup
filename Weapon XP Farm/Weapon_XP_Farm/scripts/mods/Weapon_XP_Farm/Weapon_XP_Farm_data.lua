local mod = get_mod("Weapon_XP_Farm")

return {
    name         = mod:localize("mod_name"),
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id      = "open_key",
                title           = "open_key",
                tooltip         = "open_key_tooltip",
                type            = "keybind",
                default_value   = { "l" },
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "toggle_menu",
            },
        },
    },
}

