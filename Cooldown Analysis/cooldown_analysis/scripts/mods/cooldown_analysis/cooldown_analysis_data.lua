local mod = get_mod("cooldown_analysis")

return {
    name        = "cooldown_analysis",
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id      = "open_cooldown_history",
                type            = "keybind",
                default_value   = { "f10" },
                keybind_trigger = "pressed",
                keybind_type    = "view_toggle",
                view_name       = "cooldown_history_view",
            },
            {
                setting_id    = "debug_messages",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id  = "save_files_options",
                type        = "group",
                sub_widgets = {
                    {
                        setting_id    = "delete_old_entries",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "number_of_save_files",
                        type          = "numeric",
                        default_value = 30,
                        range         = { 1, 100 },
                    },
                },
            },
        }
    }
}
