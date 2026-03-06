local mod = get_mod("BetterMovement")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "mod_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "debug_enabled",
                        type          = "checkbox",
                        default_value = false,
                    },
                },
            },
            {
                setting_id = "sprint_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "better_sprint",
                        type          = "checkbox",
                        default_value = true,
                        sub_widgets   = {
                            {
                                setting_id    = "always_sprint",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id    = "toggle_sprint",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id    = "hold_to_sprint",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id    = "hold_to_walk",
                                type          = "checkbox",
                                default_value = false,
                            },
                        }
                    },
                },
            },
            {
                setting_id = "dodge_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "prevent_accidental_jump",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "sprint_dodge",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "easy_dodge_slide",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "hold_dodge_slide",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "keep_dodging",
                        type          = "checkbox",
                        default_value = false,
                    },
                }
            },
            {
                setting_id = "movement_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id    = "easy_sprint_slide",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "auto_vault",
                        type          = "checkbox",
                        default_value = false,
                    },

                }
            }
        }
    }
}
