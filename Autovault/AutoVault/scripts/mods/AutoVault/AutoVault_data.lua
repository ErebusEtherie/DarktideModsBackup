local mod = get_mod("AutoVault")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "onlyForward",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id = "toggle_auto_vault_hotkey",
                type = "keybind",
                keybind_type = "function_call",
                default_value = {},
                keybind_trigger = "pressed",
                function_name = "toggle_auto_vault_hotkey"
            },
        }
    }
}