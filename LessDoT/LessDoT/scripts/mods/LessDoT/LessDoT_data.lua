local mod = get_mod("LessDoT")
return {
    name         = mod:localize("mod_name"),
	description  = mod:localize("mod_description"),
	is_togglable = true,
    options      = {
        widgets  = {
            {
                setting_id    = "bleed_group",
                type          = "group",
                sub_widgets   = {
                    {
                        setting_id    = "bleed_horde",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "bleed_elite",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "bleed_special",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "bleed_monster",
                        type          = "checkbox",
                        default_value = true,
                    },
                }
            },
            {
                setting_id    = "burn_group",
                type          = "group",
                sub_widgets   = {
                    {
                        setting_id    = "burn_horde",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "burn_elite",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "burn_special",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "burn_monster",
                        type          = "checkbox",
                        default_value = true,
                    },
                }
            },
            {
                setting_id    = "lightning_group",
                type          = "group",
                sub_widgets   = {
                    {
                        setting_id    = "lightning_horde",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "lightning_elite",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "lightning_special",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "lightning_monster",
                        type          = "checkbox",
                        default_value = true,
                    },
                }
            }
        }
    }
}