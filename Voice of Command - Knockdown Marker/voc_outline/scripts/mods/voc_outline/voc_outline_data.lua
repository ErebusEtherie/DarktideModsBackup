local mod = get_mod("voc_outline")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,

    options = {
        widgets = {
            {
                setting_id = "outline_type",
                type = "dropdown",
                default_value = "knocked_down",
                tooltip = "outline_type_tooltip",
                options = {
                    { text = "Orange", value = "knocked_down" },
                    { text = "Lime", value = "buff" },
                    { text = "Blue", value = "default_both_obscured" },
                },
            },
        },
    },
}
