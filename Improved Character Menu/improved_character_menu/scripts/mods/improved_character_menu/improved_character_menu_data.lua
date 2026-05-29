local mod = get_mod("improved_character_menu")

-- ============================================================
-- MOD CONFIGURATION DATA (DMF OPTIONS MENU SCHEMA)
-- Defines the mod's settings in the DMF options menu.
-- DMF parses this table to generate the in-game UI.
-- is_togglable=false because hooks cannot be safely removed at runtime.
-- allow_rehooking=false to prevent duplicate hooking errors.
-- ============================================================

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    allow_rehooking = false,
    options = {
        widgets = {
            -- Group 1: General Settings (top-level behavior toggles).
            {
                setting_id = "general_settings",
                type = "group",
                sub_widgets = {
                    -- Toggles between a colored fancy mod name and plain text.
                    { setting_id = "mod_name_pizazz_toggle", type = "checkbox", default_value = true, tooltip = "mod_name_pizazz_tooltip" },
                    -- Applies a custom button layout preset for the Psych Ward mod.
                    { setting_id = "enable_psych_ward_preset", type = "checkbox", default_value = false, tooltip = "enable_psych_ward_preset_tooltip" },
                    -- Applies a custom color scheme to all main menu UI elements.
                    { setting_id = "enable_custom_ui_colors_preset", type = "checkbox", default_value = false, tooltip = "enable_custom_ui_colors_preset_tooltip" },
                    -- Removes background blur for better performance and clarity.
                    { setting_id = "disable_main_menu_blur", type = "checkbox", default_value = true, tooltip = "disable_main_menu_blur_tooltip" },
                    -- Hides horizontal divider lines between character cards.
                    { setting_id = "disable_grid_dividers", type = "checkbox", default_value = true, tooltip = "disable_grid_dividers_tooltip" },
                    -- Hides the character grid scrollbar for a cleaner aesthetic.
                    { setting_id = "disable_scrollbar", type = "checkbox", default_value = true, tooltip = "disable_scrollbar_tooltip" },
                    { setting_id = "disable_news_feed", type = "checkbox", default_value = false, tooltip = "disable_news_feed_tooltip" },
                    { setting_id = "news_feed_offset_x", type = "numeric", default_value = -145, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px" },
                    { setting_id = "news_feed_offset_y", type = "numeric", default_value = 100, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px" },
                    { setting_id = "title_text_offset_y", type = "numeric", default_value = 150, range = { 15, 175 }, decimals_number = 0, unit_text = "px" },

                    { setting_id = "body_text_offset_y", type = "numeric", default_value = 175, range = { 15, 175 }, decimals_number = 0, unit_text = "px" },

                    { setting_id = "countdown_timer_offset_y", type = "numeric", default_value = 125, range = { 15, 175 }, decimals_number = 0, unit_text = "px" },
                }
            },
            -- Group 2: Grid Settings (numeric sliders for fine-tuning).
            {
                setting_id = "grid_settings",
                type = "group",
                sub_widgets = {
                     -- Number of character slots visible before scrolling (3-9).
                     { setting_id = "max_visible_slots", type = "numeric", default_value = 6, range = { 3, 9 }, decimals_number = 0, unit_text = "slots", tooltip = "max_visible_slots_tooltip" },
                      -- Horizontal position of the account info text.
                      { setting_id = "account_info_offset_x", type = "numeric", default_value = 820, range = { -1000, 2000 }, decimals_number = 0, unit_text = "px" },
                      -- Vertical position of the account info text.
                      { setting_id = "account_info_offset_y", type = "numeric", default_value = -50, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px" },
                    -- Font size for the character name text on each card.
                    { setting_id = "character_name_font_size", type = "numeric", default_value = 21, range = { 12, 36 }, decimals_number = 0, unit_text = "pt" },
                    -- Size of the archetype icon in the character info panel.
                    { setting_id = "archetype_icon_size", type = "numeric", default_value = 75, range = { 25, 150 }, unit_text = "px" },
                    -- Scale multiplier for the insignia icon on each character card.
                    { setting_id = "character_insignia_scale", type = "numeric", default_value = 1, range = { 0, 1.5 }, decimals_number = 2, unit_text = "x" },
                    -- Horizontal offset of the insignia icon from default position.
                    { setting_id = "character_insignia_offset_x", type = "numeric", default_value = 30, range = { 0, 100 }, decimals_number = 0, unit_text = "px" },
                    -- Scale multiplier for the character portrait image.
                    { setting_id = "character_portrait_scale", type = "numeric", default_value = 1, range = { 0.5, 2 }, decimals_number = 2, unit_text = "x" },
                    -- Horizontal offset of the character portrait from default position.
                    { setting_id = "character_portrait_offset_x", type = "numeric", default_value = 60, range = { 0, 100 }, decimals_number = 0, unit_text = "px" },
                }
            },
            -- Group 3: Metal Decorations (individual UI element toggles).
            {
                setting_id = "metal_decorations",
                type = "group",
                sub_widgets = {
                    { setting_id = "show_play_button", type = "checkbox", default_value = true, tooltip = "show_play_button_tooltip" },
                    { setting_id = "play_button_offset_x", type = "numeric", default_value = 0, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "play_button_offset_x_tooltip" },
                    { setting_id = "play_button_offset_y", type = "numeric", default_value = -80, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "play_button_offset_y_tooltip" },
                    { setting_id = "show_archetype_icon", type = "checkbox", default_value = true, tooltip = "show_archetype_icon_tooltip" },
                    { setting_id = "archetype_icon_offset_x", type = "numeric", default_value = 0, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "archetype_icon_offset_x_tooltip" },
                    { setting_id = "archetype_icon_offset_y", type = "numeric", default_value = -100, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "archetype_icon_offset_y_tooltip" },
                    { setting_id = "character_text_offset_x", type = "numeric", default_value = 0, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "character_text_offset_x_tooltip" },
                    { setting_id = "character_text_offset_y", type = "numeric", default_value = -100, range = { -1000, 1000 }, decimals_number = 0, unit_text = "px", tooltip = "character_text_offset_y_tooltip" },
                    { setting_id = "show_wallet_top", type = "checkbox", default_value = true, tooltip = "show_wallet_top_tooltip" },
                    { setting_id = "show_wallet_bottom", type = "checkbox", default_value = true, tooltip = "show_wallet_bottom_tooltip" },
                    { setting_id = "show_list_top", type = "checkbox", default_value = true, tooltip = "show_list_top_tooltip" },
                    { setting_id = "show_list_bottom", type = "checkbox", default_value = true, tooltip = "show_list_bottom_tooltip" },
                    { setting_id = "show_top_left", type = "checkbox", default_value = true, tooltip = "show_top_left_tooltip" },
                    { setting_id = "show_top_right", type = "checkbox", default_value = true, tooltip = "show_top_right_tooltip" },
                    { setting_id = "show_bottom_left", type = "checkbox", default_value = true, tooltip = "show_bottom_left_tooltip" },
                    { setting_id = "show_bottom_right", type = "checkbox", default_value = true, tooltip = "show_bottom_right_tooltip" },
                    { setting_id = "show_news_feed_top", type = "checkbox", default_value = true, tooltip = "show_news_feed_top_tooltip" },
                    { setting_id = "show_news_feed_bottom", type = "checkbox", default_value = true, tooltip = "show_news_feed_bottom_tooltip" },
                }
            },
        }
    }
}
