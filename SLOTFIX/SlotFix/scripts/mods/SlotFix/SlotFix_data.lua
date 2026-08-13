local mod = get_mod("SlotFix")

return {
    name = "SlotFix",
    description = "Fixes a base game bug where players are assigned invalid slots (>4) after someone leaves.",
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "debug_messages",
                type = "checkbox",
                default_value = false,
                title = "debug_messages_title",
                description = "debug_messages_desc",
            }
        }
    }
}
