local mod = get_mod("HavocPost")

return {
    name        = "HavocPost",
    description = "Post your Havoc assignment to Strike Team chat",
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id    = "show_startup_message",
                type          = "checkbox",
                default_value = true,
                tooltip       = "show_startup_message_tooltip",
            },
            {
                setting_id    = "show_rank",
                type          = "checkbox",
                default_value = true,
                tooltip       = "show_rank_tooltip",
            },
            {
                setting_id    = "show_charges",
                type          = "checkbox",
                default_value = true,
                tooltip       = "show_charges_tooltip",
            },
            {
                setting_id    = "show_fading_light",
                type          = "checkbox",
                default_value = false,
                tooltip       = "show_fading_light_tooltip",
            },
            {
                setting_id    = "show_havoc_tag",
                type          = "checkbox",
                default_value = true,
                tooltip       = "show_havoc_tag_tooltip",
            },
            {
                setting_id    = "show_status_messages",
                type          = "checkbox",
                default_value = false,
                tooltip       = "show_status_messages_tooltip",
            },
        },
    },
}