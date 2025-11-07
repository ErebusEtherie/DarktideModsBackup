local mod = get_mod("StickyFingers")
return {
    name         = mod:localize("mod_name"),
	description  = mod:localize("mod_description"),
	is_togglable = true,
    options      = {
        widgets  = {
            {
                setting_id    = "EnableAuto",
                tooltip       = "EnableAutoTooltip",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id  = "AutoGroup",
                type        = "group",
                sub_widgets = {
                    {
                        setting_id = "Special",
                        type = "dropdown",
                        default_value = "disabled",
                        options = {
                            { text = "disabled", value = "disabled" },
                            { text = "interact_primary_pressed", value = "interact_primary_pressed" },
                            { text = "interact_secondary_pressed", value = "interact_secondary_pressed" },
                        }
                    },
                    {
                        setting_id    = "MedStation",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "MedThreshold",
                        type          = "numeric",
                        default_value = 100,
                        range         = {1, 100},
                    },
                    {
                        setting_id    = "TeammateRevive",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "TeammateRescue",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "TeammateLedge",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "TeammateNet",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "Mission",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "Door",
                        tooltip       = "DoorTooltip",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "DoorType",
                        type       = "dropdown",
                        default_value = "closed",
                        options = {
                            { text = "Open", value = "closed" },
                            { text = "Close", value = "open" },
                            { text = "OpenClose", value = "any" },
                        }
                    },
                    {
                        setting_id    = "Minigame",
                        tooltip       = "MinigameTooltip",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "Luggable",
                        type          = "checkbox",
                        default_value = false,
                    }
                }
            }
        }
    }
}