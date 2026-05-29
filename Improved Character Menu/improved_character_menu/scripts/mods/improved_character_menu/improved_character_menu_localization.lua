local mod = get_mod("improved_character_menu")

-- ============================================================
-- LOCALIZATION FILE
-- Contains all human-readable text displayed throughout the mod.
-- Each key maps to a setting_id from the data file, with values
-- keyed by language code (e.g., "en" for English).
-- Uses Darktide's rich text color codes: {#color(r,g,b)}Text{#reset()}
-- ============================================================

-- Track the mod version for display in the settings description
mod.version = "1.0.4"
mod:info("Improved Character Menu is installed, using version: " .. tostring(mod.version))

-- Color palette used throughout the settings menu text.
local colours = {
    title = "169,191,153",   -- Greenish tone for group headers
    subtitle = "230,150,30", -- Yellowish orange for the mod title and metadata labels
    text = "169,191,153",    -- Greenish tone for body text
}

-- All readable text shown in the mod options screen.
mod.localisation = {
    -- Mod description shown below the mod name in DMF.
    mod_description = {
        en = "{#color("
            .. colours.text
            .. ")}"
            .. "Tweaks the character select screen with a more compact layout and QoL improvements."
            .. "{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Author: {#color("
            .. colours.text
            .. ")}Lumberfart{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Version: {#color("
            .. colours.text
            .. ")}"
            .. mod.version
            .. "{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Disclaimer: {#color("
            .. colours.text
            .. ")}Made with OpenCode{#reset()}",
    },
    -- Mod name variants: active display name, plain text, and colored fancy version.
    mod_name = {
        en = "{#color(" .. colours.title .. ")}Improved Character Menu{#reset()}",
    },
    mod_name_boring = {
        en = "Improved Character Menu",
    },
    mod_name_pizazz = {
        en = "{#color(" .. colours.subtitle .. ")}Improved Character Menu{#reset()}",
    },
    mod_name_pizazz_toggle = {
        en = "Enable Name Pizazz",
    },
    mod_name_pizazz_tooltip = {
        en = "Toggles the colored effect on the mod name text. Requires a reload.",
    },
    -- General settings: display names and tooltips for the first settings group.
    -- Main menu background blur toggle.
    disable_main_menu_blur = {
        en = "Disable Background Blur",
    },
    disable_main_menu_blur_tooltip = {
        en = "Disables the background blur effect on the main menu for improved performance and clarity.",
    },
    -- Grid divider visibility toggle.
    disable_grid_dividers = {
        en = "Disable Grid Dividers",
    },
    disable_grid_dividers_tooltip = {
        en = "Disables the top and bottom horizontal dividers on the character select grid for improved performance and clarity.",
    },
    disable_scrollbar = {
        en = "Disable Grid Scrollbar",
    },
    disable_scrollbar_tooltip = {
        en = "Hides the character grid scrollbar for a cleaner look.",
    },
    -- Psych Ward preset compatibility toggle.
    enable_psych_ward_preset = {
        en = "Enable Psych Ward Preset",
    },
    enable_psych_ward_preset_tooltip = {
        en = "Applies a custom preset configuration to the Psych Ward mod, optimizing button positions and sizes for use with Improved Character Menu. Requires Psych Ward to be installed. Changes apply immediately.",
    },
    enable_custom_ui_colors_preset = {
        en = "Enable Custom UI Colors Preset",
    },
    enable_custom_ui_colors_preset_tooltip = {
        en = "Applies a custom color scheme to the main menu UI. Automatically backs up your current settings and restores them when disabled. Changes apply after restarting or returning to main menu.",
    },
    disable_news_feed = {
        en = "Disable News Feed",
    },
    disable_news_feed_tooltip = {
        en = "Hides the news feed element on the main menu for a cleaner look.",
    },
    news_feed_offset_x = {
        en = "News Feed Offset (X)",
    },
    news_feed_offset_y = {
        en = "News Feed Offset (Y)",
    },
    title_text_offset_y = {
        en = "Title Text Offset (Y)",
    },
    body_text_offset_y = {
        en = "Body Text Offset (Y)",
    },
    countdown_timer_offset_y = {
        en = "Countdown Timer Offset (Y)",
    },
    -- Grid settings: numeric sliders for size, spacing, and positioning.
    max_visible_slots = {
        en = "Max Visible Slots",
    },
    max_visible_slots_tooltip = {
        en = "Number of character slots to fit on screen without scrolling. Higher values expand the background panel to accommodate more slots.",
    },
    -- Grid element sizing and positioning labels.
    archetype_icon_size = {
        en = "Archetype Icon Size",
    },
    character_insignia_scale = {
        en = "Insignia Scale",
    },
    character_insignia_offset_x = {
        en = "Insignia Offset (X)",
    },
    character_portrait_scale = {
        en = "Portrait Scale",
    },
    character_portrait_offset_x = {
        en = "Portrait Offset (X)",
    },
    character_name_font_size = {
        en = "Name Font Size",
    },
    account_info_offset_x = {
        en = "Account Info Offset (X)",
    },
    account_info_offset_y = {
        en = "Account Info Offset (Y)",
    },
    -- Option group headers: collapsible section titles in DMF.
    general_settings = {
        en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
    },
    grid_settings = {
        en = "{#color(" .. colours.title .. ")}Grid Settings{#reset()}",
    },
    metal_decorations = {
        en = "{#color(" .. colours.title .. ")}Metal Decorations{#reset()}",
    },
    -- Metal decorations: visibility toggles for individual UI elements.
    -- Play button toggle and offsets.
    show_play_button = {
        en = "Play Button",
    },
    show_play_button_tooltip = {
        en = "Shows the play button on the character select screen.",
    },
    play_button_offset_x = {
        en = "Play Button Offset (X)",
    },
    play_button_offset_x_tooltip = {
        en = "Horizontal position of the play button.",
    },
    play_button_offset_y = {
        en = "Play Button Offset (Y)",
    },
    play_button_offset_y_tooltip = {
        en = "Vertical position of the play button.",
    },
    -- Archetype icon toggle and offsets.
    show_archetype_icon = {
        en = "Archetype Icon",
    },
    show_archetype_icon_tooltip = {
        en = "Shows the archetype icon in the character info panel.",
    },
    -- Character text group offsets.
    archetype_icon_offset_x = {
        en = "Archetype Icon Offset (X)",
    },
    archetype_icon_offset_x_tooltip = {
        en = "Horizontal position of the archetype icon in the character info panel.",
    },
    archetype_icon_offset_y = {
        en = "Archetype Icon Offset (Y)",
    },
    archetype_icon_offset_y_tooltip = {
        en = "Vertical position of the archetype icon in the character info panel.",
    },
    character_text_offset_x = {
        en = "Character Text Offset (X)",
    },
    character_text_offset_x_tooltip = {
        en = "Horizontal position of the character name, archetype title, and player title as a group.",
    },
    character_text_offset_y = {
        en = "Character Text Offset (Y)",
    },
    character_text_offset_y_tooltip = {
        en = "Vertical position of the character name, archetype title, and player title as a group.",
    },
    -- Wallet element toggles.
    show_wallet_top = {
        en = "Wallet Top",
    },
    show_wallet_top_tooltip = {
        en = "Shows the top divider on the wallet element.",
    },
    show_wallet_bottom = {
        en = "Wallet Bottom",
    },
    show_wallet_bottom_tooltip = {
        en = "Shows the bottom divider on the wallet element.",
    },
    show_list_top = {
        en = "List Top",
    },
    show_list_top_tooltip = {
        en = "Shows the top metal frame on the character list background.",
    },
    show_list_bottom = {
        en = "List Bottom",
    },
    show_list_bottom_tooltip = {
        en = "Shows the bottom metal frame on the character list background.",
    },
    -- Metal corner toggles for each decorative corner.
    show_top_left = {
        en = "Top Left",
    },
    show_top_left_tooltip = {
        en = "Shows the top-left metal corner decoration.",
    },
    show_top_right = {
        en = "Top Right",
    },
    show_top_right_tooltip = {
        en = "Shows the top-right metal corner decoration.",
    },
    show_bottom_left = {
        en = "Bottom Left",
    },
    show_bottom_left_tooltip = {
        en = "Shows the bottom-left metal corner decoration.",
    },
    show_bottom_right = {
        en = "Bottom Right",
    },
    show_bottom_right_tooltip = {
        en = "Shows the bottom-right metal corner decoration.",
    },
    show_news_feed_top = {
        en = "News Feed Top",
    },
    show_news_feed_top_tooltip = {
        en = "Shows the top metal frame on the news feed element.",
    },
    show_news_feed_bottom = {
        en = "News Feed Bottom",
    },
    show_news_feed_bottom_tooltip = {
        en = "Shows the bottom metal frame on the news feed element.",
    },
}

-- Switches mod name between colored fancy and plain versions based on the pizazz toggle.
mod.toggle_pizazz = function()
    for key, values in pairs(mod.localisation) do
        if key == "mod_name" then
            for language, text in pairs(values) do
                if mod:get("mod_name_pizazz_toggle") == false then
                    mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
                else
                    mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
                end
            end
        end
    end
end

-- Apply the pizazz toggle on mod load.
mod.toggle_pizazz()

-- Returns the populated localization table to the mod loader.
return mod.localisation
