local mod = get_mod("WarpFiend")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "peril_management",
                type = "group",
                sub_widgets = {
                    {
                        setting_id      = "peril_peak_threshold",
                        type            = "numeric",
                        range           = { 0.5, 0.95 },
                        default_value   = 0.8333,
                        decimals_number = 4,
                        step_size_value = 0.0001,
                        text            = mod:localize("peril_peak_threshold"),
                        description     = mod:localize("peril_peak_threshold_description"),
                    },
                    {
                        setting_id      = "peril_emergency_threshold",
                        type            = "numeric",
                        range           = { 0.90, 1.0 },
                        default_value   = 0.97,
                        decimals_number = 2,
                        step_size_value = 0.01,
                        text            = mod:localize("peril_emergency_threshold"),
                        description     = mod:localize("peril_emergency_threshold_description"),
                    },
                    {
                        setting_id      = "micro_quell_duration",
                        type            = "numeric",
                        range           = { 0.1, 1.0 },
                        default_value   = 0.4,
                        decimals_number = 2,
                        step_size_value = 0.05,
                        text            = mod:localize("micro_quell_duration"),
                        description     = mod:localize("micro_quell_duration_description"),
                    },
                },
            },
            {
                setting_id = "venting_shriek",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "auto_shriek_enable",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("auto_shriek_enable"),
                        description   = mod:localize("auto_shriek_enable_description"),
                    },
                    {
                        setting_id      = "target_density_threshold",
                        type            = "numeric",
                        range           = { 1, 10 },
                        default_value   = 3,
                        decimals_number = 0,
                        step_size_value = 1,
                        text            = mod:localize("target_density_threshold"),
                        description     = mod:localize("target_density_threshold_description"),
                    },
                    {
                        setting_id    = "hold_shriek_for_value",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("hold_shriek_for_value"),
                        description   = mod:localize("hold_shriek_for_value_description"),
                    },
                    {
                        setting_id    = "elite_priority",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("elite_priority"),
                        description   = mod:localize("elite_priority_description"),
                    },
                },
            },
            {
                setting_id = "input_mode_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "input_mode",
                        type          = "dropdown",
                        default_value = "auto_cast",
                        text          = mod:localize("input_mode"),
                        description   = mod:localize("input_mode_description"),
                        options       = {
                            { text = mod:localize("input_mode_auto"), value = "auto_cast" },
                            { text = mod:localize("input_mode_block"), value = "input_block" },
                        },
                    },
                },
            },
            {
                setting_id = "buff_monitoring",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "track_becalming_eruption",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("track_becalming_eruption"),
                        description   = mod:localize("track_becalming_eruption_description"),
                    },
                    {
                        setting_id    = "track_psykinetic_aura",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("track_psykinetic_aura"),
                        description   = mod:localize("track_psykinetic_aura_description"),
                    },
                    {
                        setting_id    = "track_empyric_shock",
                        type          = "checkbox",
                        default_value = true,
                        text          = mod:localize("track_empyric_shock"),
                        description   = mod:localize("track_empyric_shock_description"),
                    },
                },
            },
            {
                setting_id = "weapon_profile",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "staff_type",
                        type          = "dropdown",
                        default_value = "trauma",
                        text          = mod:localize("staff_type"),
                        description   = mod:localize("staff_type_description"),
                        options       = {
                            { text = mod:localize("staff_trauma"), value = "trauma" },
                            { text = mod:localize("staff_purgatus"), value = "purgatus" },
                            { text = mod:localize("staff_surge"), value = "surge" },
                            { text = mod:localize("staff_voidstrike"), value = "voidstrike" },
                        },
                    },
                    {
                        setting_id      = "custom_peril_cost",
                        type            = "numeric",
                        range           = { 0, 0.1 },
                        default_value   = 0,
                        decimals_number = 3,
                        step_size_value = 0.001,
                        text            = mod:localize("custom_peril_cost"),
                        description     = mod:localize("custom_peril_cost_description"),
                    },
                },
            },
            {
                setting_id = "debug",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "debug_logging",
                        type          = "checkbox",
                        default_value = false,
                        text          = mod:localize("debug_logging"),
                        description   = mod:localize("debug_logging_description"),
                    },
                },
            },
        },
    },
}