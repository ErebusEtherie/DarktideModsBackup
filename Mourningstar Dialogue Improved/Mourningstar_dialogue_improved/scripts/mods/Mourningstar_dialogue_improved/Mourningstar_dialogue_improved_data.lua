local mod = get_mod("Mourningstar_dialogue_improved")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            {

                setting_id = "disable_mourningstar_chatter",
                type = "checkbox",
                default_value = false

            },
            {

                setting_id = "disable_radio_chatter",
                type = "checkbox",
                default_value = false

            },
            {

                setting_id = "disable_all_chatter",
                type = "checkbox",
                default_value = false

            }
        }
    }
}
