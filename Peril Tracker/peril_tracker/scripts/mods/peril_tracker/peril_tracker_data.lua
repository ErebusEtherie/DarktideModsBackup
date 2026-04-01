local mod = get_mod("peril_tracker")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id      = "open_peril_history",
                type            = "keybind",
                default_value   = { "f9" },
                keybind_trigger = "pressed",
                keybind_type    = "view_toggle",
                view_name       = "peril_history_view",
            },
            {
                setting_id    = "sample_interval",
                type          = "numeric",
                default_value = 2,
                range         = { 1, 5 },
            },
            {
                setting_id    = "show_warp_nexus_lines",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id    = "debug_messages",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "save_files_options",
                type          = "group",
                sub_widgets   = {
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
