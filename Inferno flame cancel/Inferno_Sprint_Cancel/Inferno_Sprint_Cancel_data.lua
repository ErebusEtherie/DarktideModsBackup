local mod = get_mod("Inferno_Sprint_Cancel")

return {
    name        = mod:localize("mod_name"),
    description = mod:localize("mod_description"),

    is_togglable    = true,
    allow_rehooking = true,

    options = {
        widgets = {
            {
                setting_id      = "sprint_delay",
                type            = "numeric",
                default_value   = 0.1,
                range           = { 0.0, 0.5 },
                step_size_value = 0.01,
                decimals_number = 2,
            },
            {
                setting_id      = "sprint_duration",
                type            = "numeric",
                default_value   = 0.08,
                range           = { 0.02, 0.3 },
                step_size_value = 0.01,
                decimals_number = 2,
            },
            {
                setting_id      = "loop_end_delay",
                type            = "numeric",
                default_value   = 0.05,
                range           = { 0.0, 0.5 },
                step_size_value = 0.01,
                decimals_number = 2,
            },
            {
                setting_id    = "debug_enabled",
                type          = "checkbox",
                default_value = false,
            },
        },
    },
}