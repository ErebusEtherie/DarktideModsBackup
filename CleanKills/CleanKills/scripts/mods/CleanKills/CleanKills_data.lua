local mod = get_mod("CleanKills")

return {
    name = mod:localize("mod_title"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "enable_triage_logs",
                type = "checkbox",
                default_value = false,
                tooltip = "enable_triage_logs_tooltip",
            },
        },
    },
}
