local mod = get_mod("TraumaOutlines")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "player_only",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "outline_color",
                type = "dropdown",
                default_value = "smart_tagged_enemy",
                options = {
                    { text = "red", value = "smart_tagged_enemy"},
                    { text = "green", value = "smart_tagged_enemy_passive"},
                    { text = "yellow", value = "veteran_smart_tag"},
                    { text = "orange", value = "special_target"},
                    { text = "purple", value = "adamant_mark_target"}
                }
            },
            {
                setting_id = "show_center",
                type = "checkbox",
                default_value = false,
                sub_widgets = {
                    {
                        setting_id = "center_color",
                        type = "dropdown",
                        default_value = "smart_tagged_enemy_passive",
                        options = {
                            { text = "red", value = "smart_tagged_enemy"},
                            { text = "green", value = "smart_tagged_enemy_passive" },
                            { text = "yellow", value = "veteran_smart_tag" },
                            { text = "orange", value = "special_target" },
                            { text = "purple", value = "adamant_mark_target" }
                        }
                    },
                    {
                        setting_id = "center_only",
                        type = "checkbox",
                        default_value = false
                    }
                }
            }
        }
    }
}