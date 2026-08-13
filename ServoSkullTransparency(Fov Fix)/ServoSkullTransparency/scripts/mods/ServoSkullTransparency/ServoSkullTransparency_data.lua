local mod = get_mod("ServoSkullTransparency")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    allow_rehooking = true,
    options = {
        widgets = {
            {
                setting_id = "opacity",
                type = "numeric",
                default_value = 70,
                range = { 0, 100 },
                decimals_number = 0,
                step_size_value = 5,
            },
            {
                setting_id = "fix_fov_position",
                type = "checkbox",
                default_value = true,
            },
        },
    },
}
