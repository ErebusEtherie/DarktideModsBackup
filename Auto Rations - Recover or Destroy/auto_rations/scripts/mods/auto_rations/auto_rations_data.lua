local mod = get_mod("auto_rations")

local widgets = {
    {
        setting_id = "enable_ration_mod",
        type = "checkbox",
        default_value = true,
    },
    {
        setting_id = "ration_action",
        type = "dropdown",
        default_value = "destroy",
        options = {
            {text = "pickup", value = "pickup"},
            {text = "destroy", value = "destroy"},
        },
    }
}

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,

    options = {
        widgets = widgets,
    },
}
