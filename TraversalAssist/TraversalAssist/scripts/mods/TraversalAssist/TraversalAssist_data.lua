local mod = get_mod("TraversalAssist")

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
                setting_id = "toggle_traversal_assist_hotkey",
                type = "keybind",
                keybind_type = "function_call",
                default_value = {},
                keybind_trigger = "pressed",
                function_name = "toggle_traversal_assist_hotkey"
            },
        }
    }
}