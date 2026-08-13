local mod = get_mod("transonic_slayer")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {{
            setting_id = "blade_stylez",
            type = "group",
            sub_widgets = {{
                setting_id = "blade_energy",
                type = "numeric",
                default_value = 15,
                range = {10, 100}
            }, {
                setting_id = "blade_wiggle",
                type = "numeric",
                default_value = 15,
                range = {10, 100}
            }}
        }}
    }
}
