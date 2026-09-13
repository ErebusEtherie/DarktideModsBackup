local mod = get_mod("mod_shrine")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "show_notifications",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "auto_backup_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "auto_backup_limit",
                type = "dropdown",
                default_value = 20,
                options = {
                    { text = "auto_limit_5", value = 5 },
                    { text = "auto_limit_10", value = 10 },
                    { text = "auto_limit_20", value = 20 },
                    { text = "auto_limit_50", value = 50 },
                    { text = "auto_limit_100", value = 100 },
                },
            },
            {
                setting_id = "show_missing_mod_rows",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_advanced_tools",
                type = "checkbox",
                default_value = false,
            },
        },
    },
}
