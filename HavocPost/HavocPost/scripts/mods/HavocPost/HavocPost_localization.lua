-- HavocPost localisation
return {
    mod_title = {
        en = "HavocPost",
    },
    mod_description = {
        en = "Post your current Havoc assignment info to the Strike Team chat with /havoc.",
    },

    -- Settings
    show_post_button = {
        en = "Show Post Button",
    },
    show_post_button_tooltip = {
        en = "Show the POST button in the Havoc terminal.",
    },
    show_startup_message = {
        en = "Show Startup Message",
    },
    show_startup_message_tooltip = {
        en = "Show the 'Type /havoc' hint message on startup.",
    },
    show_rank = {
        en = "Show Rank",
    },
    show_rank_tooltip = {
        en = "Include the Havoc rank in the posted message.",
    },
    show_charges = {
        en = "Show Charges",
    },
    show_charges_tooltip = {
        en = "Include the remaining charges in the posted message.",
    },
    show_fading_light = {
        en = "Show Emperor's Fading Light",
    },
    show_fading_light_tooltip = {
        en = "Include The Emperor's Fading Light in the posted circs. Disabled by default since it is always present.",
    },
    show_havoc_tag = {
        en = "Show [HAVOC] Tag",
    },
    show_havoc_tag_tooltip = {
        en = "Prefix the posted message with [HAVOC].",
    },
    show_status_messages = {
        en = "Show Status Messages",
    },
    show_status_messages_tooltip = {
        en = "Show confirmation and cache status messages after posting with /havoc.",
    },
    debug_mode = {
        en = "Debug Mode",
    },
    debug_mode_tooltip = {
        en = "Instead of posting to Strike Team chat, echoes the exact message that would be sent.",
    },

    -- Status / hints
    hp_loaded_hint = {
        en = "[HavocPost] Type /havoc in chat to share your Havoc assignment with your Strike Team.",
    },
    hp_posted_success = {
        en = "[HavocPost] Havoc info posted to Strike Team chat.",
    },

    -- Errors
    hp_error_no_chat = {
        en = "[HavocPost] Error: Chat manager is not available.",
    },
    hp_error_send_failed = {
        en = "[HavocPost] Error: Failed to send chat message.",
    },
    hp_error_no_player = {
        en = "[HavocPost] Error: Could not find local player.",
    },
    hp_error_no_character = {
        en = "[HavocPost] Error: Could not resolve character ID.",
    },
    hp_error_no_service = {
        en = "[HavocPost] Error: Havoc data service is not available. Are you in the Mourningstar hub?",
    },
    hp_error_fetch_failed = {
        en = "[HavocPost] Error: Could not fetch Havoc assignment data.",
    },
    hp_error_no_data = {
        en = "[HavocPost] Error: No Havoc assignment found. Open the Havoc terminal first.",
    },
    hp_error_promise = {
        en = "[HavocPost] Error while loading Havoc data",
    },
}