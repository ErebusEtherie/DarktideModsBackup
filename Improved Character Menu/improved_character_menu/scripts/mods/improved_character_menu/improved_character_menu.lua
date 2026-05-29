local mod = get_mod("improved_character_menu")
local dmf = get_mod("DMF")
local gui_tweaker = get_mod("GuiTweaker")
local psych_ward = get_mod("psych_ward")


-- ============================================================
-- PSYCH WARD PRESET CONFIGURATION
-- Hardcoded preset values applied to psych_ward mod settings
-- when the "Enable Psych Ward Preset" toggle is turned on.
-- Repositions and resizes the 10 main menu buttons to fit
-- optimally alongside Improved Character Menu's layout.
-- ============================================================
local psych_ward_preset = {
    contracts_button_height = 50,
    contracts_button_width = 200,
    contracts_button_x_offset = -600,
    contracts_button_y_offset = -75,
    cosmetics_button_height = 50,
    cosmetics_button_width = 200,
    cosmetics_button_x_offset = -825,
    cosmetics_button_y_offset = -150,
    crafting_button_height = 50,
    crafting_button_width = 200,
    crafting_button_x_offset = -375,
    crafting_button_y_offset = -150,
    expedition_button_height = 50,
    expedition_button_width = 200,
    expedition_button_x_offset = -150,
    expedition_button_y_offset = -150,
    horde_button_height = 50,
    horde_button_width = 200,
    horde_button_x_offset = -600,
    horde_button_y_offset = -225,
    inventory_button_height = 50,
    inventory_button_width = 200,
    inventory_button_x_offset = -825,
    inventory_button_y_offset = -75,
    meatgrinder_button_height = 50,
    meatgrinder_button_width = 200,
    meatgrinder_button_x_offset = -825,
    meatgrinder_button_y_offset = -225,
    mission_button_height = 50,
    mission_button_width = 200,
    mission_button_x_offset = -150,
    mission_button_y_offset = -75,
    penance_button_height = 50,
    penance_button_width = 200,
    penance_button_x_offset = -600,
    penance_button_y_offset = -150,
    pw_contracts_button_pos_h = 230,
    pw_contracts_button_pos_v = -75,
    pw_contracts_button_size_h = 220,
    pw_contracts_button_size_v = 40,
    pw_cosmetics_button_pos_h = -230,
    pw_cosmetics_button_pos_v = -75,
    pw_cosmetics_button_size_h = 220,
    pw_cosmetics_button_size_v = 40,
    pw_crafting_button_pos_h = -5,
    pw_crafting_button_pos_v = -345,
    pw_crafting_button_size_h = 200,
    pw_crafting_button_size_v = 40,
    pw_inventory_button_pos_h = -5,
    pw_inventory_button_pos_v = -390,
    pw_inventory_button_size_h = 200,
    pw_inventory_button_size_v = 40,
    pw_mission_button_pos_h = 0,
    pw_mission_button_pos_v = 40,
    pw_mission_button_size_h = 250,
    pw_mission_button_size_v = 60,
    pw_penance_button_pos_h = 0,
    pw_penance_button_pos_v = -75,
    pw_penance_button_size_h = 220,
    pw_penance_button_size_v = 40,
    pw_vendor_button_pos_h = -5,
    pw_vendor_button_pos_v = -300,
    pw_vendor_button_size_h = 200,
    pw_vendor_button_size_v = 40,
    vendor_button_height = 50,
    vendor_button_width = 200,
    vendor_button_x_offset = -375,
    vendor_button_y_offset = -75,
}

-- Captures psych_ward's current settings before overwriting with the preset.
-- Preserves originals so they can be restored when the toggle is turned off.
local psych_ward_original_settings = nil
local psych_ward_setting_keys = {
    "contracts_button_x_offset", "contracts_button_y_offset", "contracts_button_width", "contracts_button_height",
    "cosmetics_button_x_offset", "cosmetics_button_y_offset", "cosmetics_button_width", "cosmetics_button_height",
    "crafting_button_x_offset", "crafting_button_y_offset", "crafting_button_width", "crafting_button_height",
    "expedition_button_x_offset", "expedition_button_y_offset", "expedition_button_width", "expedition_button_height",
    "horde_button_x_offset", "horde_button_y_offset", "horde_button_width", "horde_button_height",
    "inventory_button_x_offset", "inventory_button_y_offset", "inventory_button_width", "inventory_button_height",
    "meatgrinder_button_x_offset", "meatgrinder_button_y_offset", "meatgrinder_button_width", "meatgrinder_button_height",
    "mission_button_x_offset", "mission_button_y_offset", "mission_button_width", "mission_button_height",
    "penance_button_x_offset", "penance_button_y_offset", "penance_button_width", "penance_button_height",
    "vendor_button_x_offset", "vendor_button_y_offset", "vendor_button_width", "vendor_button_height",
}
local function capture_psych_ward_originals()
    if psych_ward_original_settings or not psych_ward then return end
    psych_ward_original_settings = {}
    for _, key in ipairs(psych_ward_setting_keys) do
        psych_ward_original_settings[key] = psych_ward:get(key)
    end
end

-- Applies the psych_ward preset via psych_ward's mod:set API.
-- Read-only from psych_ward's perspective: never modifies psych_ward's source files.
local function apply_psych_ward_preset()
    if not mod:get("enable_psych_ward_preset") then
        return
    end

    if not psych_ward then
        mod:warning("psych_ward mod not found, cannot apply Psych Ward preset")
        return
    end
    capture_psych_ward_originals()
    for key, value in pairs(psych_ward_preset) do
        psych_ward:set(key, value)
    end
end

-- ============================================================
-- CUSTOM UI COLORS PRESET
-- Injects color values into CustomUIColors mod's runtime settings
-- via its mod:set() API, bypassing the need to modify config files.
-- Takes effect immediately without requiring a game restart.
-- Assigns unique colors to each character slot with a cohesive dark theme.
-- ============================================================

-- Reference to the CustomUIColors mod, resolved at runtime.
local custom_ui_colors_mod = nil

-- Caches the user's original CustomUIColors settings before preset overwrites.
-- Used to restore original values when the toggle is disabled.
local custom_ui_colors_original_settings = nil

-- Hardcoded preset mapping CustomUIColors setting IDs to desired color names or alpha values.
local custom_ui_colors_preset = {
    -- Character list background
    character_list_background_main_color = "black",
    character_list_background_main_alpha = 155,
    character_list_background_top_border_color = "white",
    character_list_background_top_border_alpha = 255,
    character_list_background_bottom_border_color = "white",
    character_list_background_bottom_border_alpha = 0,

    -- Character grid mask and scrollbar
    character_grid_scrollbar_thumb_idle_color = "white",
    character_grid_scrollbar_thumb_idle_alpha = 255,
    character_grid_scrollbar_thumb_highlight_color = "white",
    character_grid_scrollbar_thumb_highlight_alpha = 255,
    character_grid_scrollbar_track_frame_color = "white",
    character_grid_scrollbar_track_frame_alpha = 255,
    character_grid_scrollbar_track_background_color = "black",
    character_grid_scrollbar_track_background_alpha = 155,

    -- Character info
    character_info_style_id_1_color = "white",
    character_info_style_id_1_alpha = 255,
    character_info_text_archetype_text_color = "terminal_text_body",
    character_info_text_archetype_text_alpha = 255,
    character_info_text_character_text_color = "white",
    character_info_text_character_text_alpha = 255,

    -- Crafting Menu
    corner_bottom_left_s1_alpha = 255,
	corner_bottom_left_s1_color = "white",
	corner_bottom_left_s2_alpha = 255,
	corner_bottom_left_s2_color = "white",
	corner_bottom_right_s1_alpha = 255,
	corner_bottom_right_s1_color = "white",
	corner_bottom_right_s2_alpha = 255,
	corner_bottom_right_s2_color = "white",
	corner_top_left_s1_alpha = 255,
	corner_top_left_s1_color = "white",
	corner_top_left_s2_alpha = 255,
	corner_top_left_s2_color = "white",
	corner_top_right_no_wallet_s1_alpha = 255,
	corner_top_right_no_wallet_s1_color = "white",
	corner_top_right_s1_alpha = 255,
	corner_top_right_s1_color = "white",
	corner_top_right_s2_alpha = 255,
	corner_top_right_s2_color = "white",
	crafting_menu_button_divider_alpha = 255,
	crafting_menu_button_divider_color = "white",
	crafting_menu_overlay_alpha = 11,
	crafting_menu_overlay_color = "black",

    -- Create button
    create_button_background_default_color = "black",
    create_button_background_default_alpha = 155,
    create_button_background_gradient_color = "black",
    create_button_background_gradient_alpha = 255,
    create_button_outer_shadow_color = "black",
    create_button_outer_shadow_alpha = 255,

    -- Play button
    play_button_background_color = "black",
    play_button_background_alpha = 255,
    play_button_background_gradient_color = "black",
    play_button_background_gradient_alpha = 255,
    play_button_outer_shadow_color = "black",
    play_button_outer_shadow_alpha = 255,

    -- Wallet element background
    wallet_element_background_color = "black",
    wallet_element_background_alpha = 100,
    wallet_element_background_top_divider_color = "white",
    wallet_element_background_top_divider_alpha = 255,
    wallet_element_background_bottom_divider_color = "white",
    wallet_element_background_bottom_divider_alpha = 255,

    -- Background left (smoke)
    background_left_color = "black",
    background_left_alpha = 5,

    -- Metal corners
    metal_corners_color = "white",
    metal_corners_alpha = 255,

    -- Text elements
    main_menu_friends_online_color = "white",
    main_menu_friends_online_alpha = 255,
    main_menu_strike_team_color = "white",
    main_menu_strike_team_alpha = 255,
    main_menu_slots_count_color = "white",
    main_menu_slots_count_alpha = 255,

    -- Psych Ward buttons (background + gradient + shadow)
    cosmetics_button_background_color = "black",
    cosmetics_button_background_alpha = 155,
    cosmetics_button_background_gradient_color = "black",
    cosmetics_button_background_gradient_alpha = 255,
    cosmetics_button_outer_shadow_color = "black",
    cosmetics_button_outer_shadow_alpha = 255,

    penance_button_background_color = "black",
    penance_button_background_alpha = 155,
    penance_button_background_gradient_color = "black",
    penance_button_background_gradient_alpha = 255,
    penance_button_outer_shadow_color = "black",
    penance_button_outer_shadow_alpha = 255,

    contracts_button_background_color = "black",
    contracts_button_background_alpha = 155,
    contracts_button_background_gradient_color = "black",
    contracts_button_background_gradient_alpha = 255,
    contracts_button_outer_shadow_color = "black",
    contracts_button_outer_shadow_alpha = 255,

    horde_button_background_color = "black",
    horde_button_background_alpha = 155,
    horde_button_background_gradient_color = "black",
    horde_button_background_gradient_alpha = 255,
    horde_button_outer_shadow_color = "black",
    horde_button_outer_shadow_alpha = 255,

    mission_button_background_color = "black",
    mission_button_background_alpha = 155,
    mission_button_background_gradient_color = "black",
    mission_button_background_gradient_alpha = 255,
    mission_button_outer_shadow_color = "black",
    mission_button_outer_shadow_alpha = 255,

    expedition_button_background_color = "black",
    expedition_button_background_alpha = 155,
    expedition_button_background_gradient_color = "black",
    expedition_button_background_gradient_alpha = 255,
    expedition_button_outer_shadow_color = "black",
    expedition_button_outer_shadow_alpha = 255,

    meatgrinder_button_background_color = "black",
    meatgrinder_button_background_alpha = 155,
    meatgrinder_button_background_gradient_color = "black",
    meatgrinder_button_background_gradient_alpha = 255,
    meatgrinder_button_outer_shadow_color = "black",
    meatgrinder_button_outer_shadow_alpha = 255,

    inventory_button_background_color = "black",
    inventory_button_background_alpha = 155,
    inventory_button_background_gradient_color = "black",
    inventory_button_background_gradient_alpha = 255,
    inventory_button_outer_shadow_color = "black",
    inventory_button_outer_shadow_alpha = 255,

    crafting_button_background_color = "black",
    crafting_button_background_alpha = 155,
    crafting_button_background_gradient_color = "black",
    crafting_button_background_gradient_alpha = 255,
    crafting_button_outer_shadow_color = "black",
    crafting_button_outer_shadow_alpha = 255,

    vendor_button_background_color = "black",
    vendor_button_background_alpha = 155,
    vendor_button_background_gradient_color = "black",
    vendor_button_background_gradient_alpha = 255,
    vendor_button_outer_shadow_color = "black",
    vendor_button_outer_shadow_alpha = 255,

    -- Difficulty stepper
    difficulty_stepper_color = "white",
    difficulty_stepper_alpha = 255,

    -- Character Slot 1: Magenta
    character_slot_1_background_color = "magenta",
    character_slot_1_background_alpha = 255,
    character_slot_1_background_gradient_hover_color = "magenta",
    character_slot_1_background_gradient_hover_alpha = 255,
    character_slot_1_background_gradient_selected_color = "black",
    character_slot_1_background_gradient_selected_alpha = 255,
    character_slot_1_archetype_icon_selected_color = "white",
    character_slot_1_archetype_icon_selected_alpha = 255,
    character_slot_1_archetype_icon_hover_color = "white",
    character_slot_1_archetype_icon_hover_alpha = 255,
    character_slot_1_character_archetype_title_default_color = "white",
    character_slot_1_character_archetype_title_default_alpha = 255,
    character_slot_1_character_archetype_title_hover_color = "white",
    character_slot_1_character_archetype_title_hover_alpha = 255,
    character_slot_1_character_insignia_color = "white",
    character_slot_1_character_insignia_alpha = 255,
    character_slot_1_character_name_default_color = "white",
    character_slot_1_character_name_default_alpha = 255,
    character_slot_1_character_name_hover_color = "white",
    character_slot_1_character_name_hover_alpha = 255,
    character_slot_1_character_portrait_color = "white",
    character_slot_1_character_portrait_alpha = 255,
    character_slot_1_contracts_text_default_color = "white",
    character_slot_1_contracts_text_default_alpha = 255,
    character_slot_1_contracts_text_hover_color = "white",
    character_slot_1_contracts_text_hover_alpha = 255,
    character_slot_1_corner_hover_color = "magenta",
    character_slot_1_corner_hover_alpha = 255,
    character_slot_1_corner_selected_color = "magenta",
    character_slot_1_corner_selected_alpha = 255,
    character_slot_1_frame_hover_color = "magenta",
    character_slot_1_frame_hover_alpha = 255,
    character_slot_1_frame_selected_color = "magenta",
    character_slot_1_frame_selected_alpha = 255,
    character_slot_1_style_id_7_color = "white",
    character_slot_1_style_id_7_alpha = 0,
    character_slot_1_style_id_8_color = "white",
    character_slot_1_style_id_8_alpha = 0,
    character_slot_1_style_id_13_default_color = "white",
    character_slot_1_style_id_13_default_alpha = 255,
    character_slot_1_style_id_13_hover_color = "white",
    character_slot_1_style_id_13_hover_alpha = 255,

    -- Character Slot 2: Cyan
    character_slot_2_background_color = "cyan",
    character_slot_2_background_alpha = 255,
    character_slot_2_background_gradient_hover_color = "cyan",
    character_slot_2_background_gradient_hover_alpha = 255,
    character_slot_2_background_gradient_selected_color = "black",
    character_slot_2_background_gradient_selected_alpha = 255,
    character_slot_2_archetype_icon_selected_color = "white",
    character_slot_2_archetype_icon_selected_alpha = 255,
    character_slot_2_archetype_icon_hover_color = "white",
    character_slot_2_archetype_icon_hover_alpha = 255,
    character_slot_2_character_archetype_title_default_color = "white",
    character_slot_2_character_archetype_title_default_alpha = 255,
    character_slot_2_character_archetype_title_hover_color = "white",
    character_slot_2_character_archetype_title_hover_alpha = 255,
    character_slot_2_character_insignia_color = "white",
    character_slot_2_character_insignia_alpha = 255,
    character_slot_2_character_name_default_color = "white",
    character_slot_2_character_name_default_alpha = 255,
    character_slot_2_character_name_hover_color = "white",
    character_slot_2_character_name_hover_alpha = 255,
    character_slot_2_character_portrait_color = "white",
    character_slot_2_character_portrait_alpha = 255,
    character_slot_2_contracts_text_default_color = "white",
    character_slot_2_contracts_text_default_alpha = 255,
    character_slot_2_contracts_text_hover_color = "white",
    character_slot_2_contracts_text_hover_alpha = 255,
    character_slot_2_corner_hover_color = "cyan",
    character_slot_2_corner_hover_alpha = 255,
    character_slot_2_corner_selected_color = "cyan",
    character_slot_2_corner_selected_alpha = 255,
    character_slot_2_frame_hover_color = "cyan",
    character_slot_2_frame_hover_alpha = 255,
    character_slot_2_frame_selected_color = "cyan",
    character_slot_2_frame_selected_alpha = 255,
    character_slot_2_style_id_7_color = "white",
    character_slot_2_style_id_7_alpha = 0,
    character_slot_2_style_id_8_color = "white",
    character_slot_2_style_id_8_alpha = 0,
    character_slot_2_style_id_13_default_color = "white",
    character_slot_2_style_id_13_default_alpha = 255,
    character_slot_2_style_id_13_hover_color = "white",
    character_slot_2_style_id_13_hover_alpha = 255,

    -- Character Slot 3: Gold
    character_slot_3_background_color = "gold",
    character_slot_3_background_alpha = 255,
    character_slot_3_background_gradient_hover_color = "gold",
    character_slot_3_background_gradient_hover_alpha = 255,
    character_slot_3_background_gradient_selected_color = "black",
    character_slot_3_background_gradient_selected_alpha = 255,
    character_slot_3_archetype_icon_selected_color = "white",
    character_slot_3_archetype_icon_selected_alpha = 255,
    character_slot_3_archetype_icon_hover_color = "white",
    character_slot_3_archetype_icon_hover_alpha = 255,
    character_slot_3_character_archetype_title_default_color = "white",
    character_slot_3_character_archetype_title_default_alpha = 255,
    character_slot_3_character_archetype_title_hover_color = "white",
    character_slot_3_character_archetype_title_hover_alpha = 255,
    character_slot_3_character_insignia_color = "white",
    character_slot_3_character_insignia_alpha = 255,
    character_slot_3_character_name_default_color = "white",
    character_slot_3_character_name_default_alpha = 255,
    character_slot_3_character_name_hover_color = "white",
    character_slot_3_character_name_hover_alpha = 255,
    character_slot_3_character_portrait_color = "white",
    character_slot_3_character_portrait_alpha = 255,
    character_slot_3_contracts_text_default_color = "white",
    character_slot_3_contracts_text_default_alpha = 255,
    character_slot_3_contracts_text_hover_color = "white",
    character_slot_3_contracts_text_hover_alpha = 255,
    character_slot_3_corner_hover_color = "gold",
    character_slot_3_corner_hover_alpha = 255,
    character_slot_3_corner_selected_color = "gold",
    character_slot_3_corner_selected_alpha = 255,
    character_slot_3_frame_hover_color = "gold",
    character_slot_3_frame_hover_alpha = 255,
    character_slot_3_frame_selected_color = "gold",
    character_slot_3_frame_selected_alpha = 255,
    character_slot_3_style_id_7_color = "white",
    character_slot_3_style_id_7_alpha = 0,
    character_slot_3_style_id_8_color = "white",
    character_slot_3_style_id_8_alpha = 0,
    character_slot_3_style_id_13_default_color = "white",
    character_slot_3_style_id_13_default_alpha = 255,
    character_slot_3_style_id_13_hover_color = "white",
    character_slot_3_style_id_13_hover_alpha = 255,

    -- Character Slot 4: Red
    character_slot_4_background_color = "red",
    character_slot_4_background_alpha = 255,
    character_slot_4_background_gradient_hover_color = "red",
    character_slot_4_background_gradient_hover_alpha = 255,
    character_slot_4_background_gradient_selected_color = "black",
    character_slot_4_background_gradient_selected_alpha = 255,
    character_slot_4_archetype_icon_selected_color = "white",
    character_slot_4_archetype_icon_selected_alpha = 255,
    character_slot_4_archetype_icon_hover_color = "white",
    character_slot_4_archetype_icon_hover_alpha = 255,
    character_slot_4_character_archetype_title_default_color = "white",
    character_slot_4_character_archetype_title_default_alpha = 255,
    character_slot_4_character_archetype_title_hover_color = "white",
    character_slot_4_character_archetype_title_hover_alpha = 255,
    character_slot_4_character_insignia_color = "white",
    character_slot_4_character_insignia_alpha = 255,
    character_slot_4_character_name_default_color = "white",
    character_slot_4_character_name_default_alpha = 255,
    character_slot_4_character_name_hover_color = "white",
    character_slot_4_character_name_hover_alpha = 255,
    character_slot_4_character_portrait_color = "white",
    character_slot_4_character_portrait_alpha = 255,
    character_slot_4_contracts_text_default_color = "white",
    character_slot_4_contracts_text_default_alpha = 255,
    character_slot_4_contracts_text_hover_color = "white",
    character_slot_4_contracts_text_hover_alpha = 255,
    character_slot_4_corner_hover_color = "red",
    character_slot_4_corner_hover_alpha = 255,
    character_slot_4_corner_selected_color = "red",
    character_slot_4_corner_selected_alpha = 255,
    character_slot_4_frame_hover_color = "red",
    character_slot_4_frame_hover_alpha = 255,
    character_slot_4_frame_selected_color = "red",
    character_slot_4_frame_selected_alpha = 255,
    character_slot_4_style_id_7_color = "white",
    character_slot_4_style_id_7_alpha = 0,
    character_slot_4_style_id_8_color = "white",
    character_slot_4_style_id_8_alpha = 0,
    character_slot_4_style_id_13_default_color = "white",
    character_slot_4_style_id_13_default_alpha = 255,
    character_slot_4_style_id_13_hover_color = "white",
    character_slot_4_style_id_13_hover_alpha = 255,

    -- Character Slot 5: Blue
    character_slot_5_background_color = "blue",
    character_slot_5_background_alpha = 255,
    character_slot_5_background_gradient_hover_color = "blue",
    character_slot_5_background_gradient_hover_alpha = 255,
    character_slot_5_background_gradient_selected_color = "black",
    character_slot_5_background_gradient_selected_alpha = 255,
    character_slot_5_archetype_icon_selected_color = "white",
    character_slot_5_archetype_icon_selected_alpha = 255,
    character_slot_5_archetype_icon_hover_color = "white",
    character_slot_5_archetype_icon_hover_alpha = 255,
    character_slot_5_character_archetype_title_default_color = "white",
    character_slot_5_character_archetype_title_default_alpha = 255,
    character_slot_5_character_archetype_title_hover_color = "white",
    character_slot_5_character_archetype_title_hover_alpha = 255,
    character_slot_5_character_insignia_color = "white",
    character_slot_5_character_insignia_alpha = 255,
    character_slot_5_character_name_default_color = "white",
    character_slot_5_character_name_default_alpha = 255,
    character_slot_5_character_name_hover_color = "white",
    character_slot_5_character_name_hover_alpha = 255,
    character_slot_5_character_portrait_color = "white",
    character_slot_5_character_portrait_alpha = 255,
    character_slot_5_contracts_text_default_color = "white",
    character_slot_5_contracts_text_default_alpha = 255,
    character_slot_5_contracts_text_hover_color = "white",
    character_slot_5_contracts_text_hover_alpha = 255,
    character_slot_5_corner_hover_color = "blue",
    character_slot_5_corner_hover_alpha = 255,
    character_slot_5_corner_selected_color = "blue",
    character_slot_5_corner_selected_alpha = 255,
    character_slot_5_frame_hover_color = "blue",
    character_slot_5_frame_hover_alpha = 255,
    character_slot_5_frame_selected_color = "blue",
    character_slot_5_frame_selected_alpha = 255,
    character_slot_5_style_id_7_color = "white",
    character_slot_5_style_id_7_alpha = 0,
    character_slot_5_style_id_8_color = "white",
    character_slot_5_style_id_8_alpha = 0,
    character_slot_5_style_id_13_default_color = "white",
    character_slot_5_style_id_13_default_alpha = 255,
    character_slot_5_style_id_13_hover_color = "white",
    character_slot_5_style_id_13_hover_alpha = 255,

    -- Character Slot 6: Online Green
    character_slot_6_background_color = "online_green",
    character_slot_6_background_alpha = 255,
    character_slot_6_background_gradient_hover_color = "online_green",
    character_slot_6_background_gradient_hover_alpha = 255,
    character_slot_6_background_gradient_selected_color = "black",
    character_slot_6_background_gradient_selected_alpha = 255,
    character_slot_6_archetype_icon_selected_color = "white",
    character_slot_6_archetype_icon_selected_alpha = 255,
    character_slot_6_archetype_icon_hover_color = "white",
    character_slot_6_archetype_icon_hover_alpha = 255,
    character_slot_6_character_archetype_title_default_color = "white",
    character_slot_6_character_archetype_title_default_alpha = 255,
    character_slot_6_character_archetype_title_hover_color = "white",
    character_slot_6_character_archetype_title_hover_alpha = 255,
    character_slot_6_character_insignia_color = "white",
    character_slot_6_character_insignia_alpha = 255,
    character_slot_6_character_name_default_color = "white",
    character_slot_6_character_name_default_alpha = 255,
    character_slot_6_character_name_hover_color = "white",
    character_slot_6_character_name_hover_alpha = 255,
    character_slot_6_character_portrait_color = "white",
    character_slot_6_character_portrait_alpha = 255,
    character_slot_6_contracts_text_default_color = "white",
    character_slot_6_contracts_text_default_alpha = 255,
    character_slot_6_contracts_text_hover_color = "white",
    character_slot_6_contracts_text_hover_alpha = 255,
    character_slot_6_corner_hover_color = "online_green",
    character_slot_6_corner_hover_alpha = 255,
    character_slot_6_corner_selected_color = "online_green",
    character_slot_6_corner_selected_alpha = 255,
    character_slot_6_frame_hover_color = "online_green",
    character_slot_6_frame_hover_alpha = 255,
    character_slot_6_frame_selected_color = "online_green",
    character_slot_6_frame_selected_alpha = 255,
    character_slot_6_style_id_7_color = "white",
    character_slot_6_style_id_7_alpha = 0,
    character_slot_6_style_id_8_color = "white",
    character_slot_6_style_id_8_alpha = 0,
    character_slot_6_style_id_13_default_color = "white",
    character_slot_6_style_id_13_default_alpha = 255,
    character_slot_6_style_id_13_hover_color = "white",
    character_slot_6_style_id_13_hover_alpha = 255,

    -- Character Slot 7: Coral
    character_slot_7_background_color = "coral",
    character_slot_7_background_alpha = 255,
    character_slot_7_background_gradient_hover_color = "coral",
    character_slot_7_background_gradient_hover_alpha = 255,
    character_slot_7_background_gradient_selected_color = "black",
    character_slot_7_background_gradient_selected_alpha = 255,
    character_slot_7_archetype_icon_selected_color = "white",
    character_slot_7_archetype_icon_selected_alpha = 255,
    character_slot_7_archetype_icon_hover_color = "white",
    character_slot_7_archetype_icon_hover_alpha = 255,
    character_slot_7_character_archetype_title_default_color = "white",
    character_slot_7_character_archetype_title_default_alpha = 255,
    character_slot_7_character_archetype_title_hover_color = "white",
    character_slot_7_character_archetype_title_hover_alpha = 255,
    character_slot_7_character_insignia_color = "white",
    character_slot_7_character_insignia_alpha = 255,
    character_slot_7_character_name_default_color = "white",
    character_slot_7_character_name_default_alpha = 255,
    character_slot_7_character_name_hover_color = "white",
    character_slot_7_character_name_hover_alpha = 255,
    character_slot_7_character_portrait_color = "white",
    character_slot_7_character_portrait_alpha = 255,
    character_slot_7_contracts_text_default_color = "white",
    character_slot_7_contracts_text_default_alpha = 255,
    character_slot_7_contracts_text_hover_color = "white",
    character_slot_7_contracts_text_hover_alpha = 255,
    character_slot_7_corner_hover_color = "coral",
    character_slot_7_corner_hover_alpha = 255,
    character_slot_7_corner_selected_color = "coral",
    character_slot_7_corner_selected_alpha = 255,
    character_slot_7_frame_hover_color = "coral",
    character_slot_7_frame_hover_alpha = 255,
    character_slot_7_frame_selected_color = "coral",
    character_slot_7_frame_selected_alpha = 255,
    character_slot_7_style_id_7_color = "white",
    character_slot_7_style_id_7_alpha = 0,
    character_slot_7_style_id_8_color = "white",
    character_slot_7_style_id_8_alpha = 0,
    character_slot_7_style_id_13_default_color = "white",
    character_slot_7_style_id_13_default_alpha = 255,
    character_slot_7_style_id_13_hover_color = "white",
    character_slot_7_style_id_13_hover_alpha = 255,

    -- Character Slot 8: Violet
    character_slot_8_background_color = "violet",
    character_slot_8_background_alpha = 255,
    character_slot_8_background_gradient_hover_color = "violet",
    character_slot_8_background_gradient_hover_alpha = 255,
    character_slot_8_background_gradient_selected_color = "black",
    character_slot_8_background_gradient_selected_alpha = 255,
    character_slot_8_archetype_icon_selected_color = "white",
    character_slot_8_archetype_icon_selected_alpha = 255,
    character_slot_8_archetype_icon_hover_color = "white",
    character_slot_8_archetype_icon_hover_alpha = 255,
    character_slot_8_character_archetype_title_default_color = "white",
    character_slot_8_character_archetype_title_default_alpha = 255,
    character_slot_8_character_archetype_title_hover_color = "white",
    character_slot_8_character_archetype_title_hover_alpha = 255,
    character_slot_8_character_insignia_color = "white",
    character_slot_8_character_insignia_alpha = 255,
    character_slot_8_character_name_default_color = "white",
    character_slot_8_character_name_default_alpha = 255,
    character_slot_8_character_name_hover_color = "white",
    character_slot_8_character_name_hover_alpha = 255,
    character_slot_8_character_portrait_color = "white",
    character_slot_8_character_portrait_alpha = 255,
    character_slot_8_contracts_text_default_color = "white",
    character_slot_8_contracts_text_default_alpha = 255,
    character_slot_8_contracts_text_hover_color = "white",
    character_slot_8_contracts_text_hover_alpha = 255,
    character_slot_8_corner_hover_color = "violet",
    character_slot_8_corner_hover_alpha = 255,
    character_slot_8_corner_selected_color = "violet",
    character_slot_8_corner_selected_alpha = 255,
    character_slot_8_frame_hover_color = "violet",
    character_slot_8_frame_hover_alpha = 255,
    character_slot_8_frame_selected_color = "violet",
    character_slot_8_frame_selected_alpha = 255,
    character_slot_8_style_id_7_color = "white",
    character_slot_8_style_id_7_alpha = 0,
    character_slot_8_style_id_8_color = "white",
    character_slot_8_style_id_8_alpha = 0,
    character_slot_8_style_id_13_default_color = "white",
    character_slot_8_style_id_13_default_alpha = 255,
    character_slot_8_style_id_13_hover_color = "white",
    character_slot_8_style_id_13_hover_alpha = 255,

    -- Character Slot 9: Olive
    character_slot_9_background_color = "olive",
    character_slot_9_background_alpha = 255,
    character_slot_9_background_gradient_hover_color = "olive",
    character_slot_9_background_gradient_hover_alpha = 255,
    character_slot_9_background_gradient_selected_color = "black",
    character_slot_9_background_gradient_selected_alpha = 255,
    character_slot_9_archetype_icon_selected_color = "white",
    character_slot_9_archetype_icon_selected_alpha = 255,
    character_slot_9_archetype_icon_hover_color = "white",
    character_slot_9_archetype_icon_hover_alpha = 255,
    character_slot_9_character_archetype_title_default_color = "white",
    character_slot_9_character_archetype_title_default_alpha = 255,
    character_slot_9_character_archetype_title_hover_color = "white",
    character_slot_9_character_archetype_title_hover_alpha = 255,
    character_slot_9_character_insignia_color = "white",
    character_slot_9_character_insignia_alpha = 255,
    character_slot_9_character_name_default_color = "white",
    character_slot_9_character_name_default_alpha = 255,
    character_slot_9_character_name_hover_color = "white",
    character_slot_9_character_name_hover_alpha = 255,
    character_slot_9_character_portrait_color = "white",
    character_slot_9_character_portrait_alpha = 255,
    character_slot_9_contracts_text_default_color = "white",
    character_slot_9_contracts_text_default_alpha = 255,
    character_slot_9_contracts_text_hover_color = "white",
    character_slot_9_contracts_text_hover_alpha = 255,
    character_slot_9_corner_hover_color = "olive",
    character_slot_9_corner_hover_alpha = 255,
    character_slot_9_corner_selected_color = "olive",
    character_slot_9_corner_selected_alpha = 255,
    character_slot_9_frame_hover_color = "olive",
    character_slot_9_frame_hover_alpha = 255,
    character_slot_9_frame_selected_color = "olive",
    character_slot_9_frame_selected_alpha = 255,
    character_slot_9_style_id_7_color = "white",
    character_slot_9_style_id_7_alpha = 0,
    character_slot_9_style_id_8_color = "white",
    character_slot_9_style_id_8_alpha = 0,
    character_slot_9_style_id_13_default_color = "white",
    character_slot_9_style_id_13_default_alpha = 255,
    character_slot_9_style_id_13_hover_color = "white",
    character_slot_9_style_id_13_hover_alpha = 255,
}

-- Captures the user's current CustomUIColors settings for every key in the preset.
-- Only runs once to preserve the true original values.
local function capture_custom_ui_colors_originals()
    if custom_ui_colors_original_settings then
        return
    end

    if not custom_ui_colors_mod then
        custom_ui_colors_mod = get_mod("CustomUIColors")
    end
    if not custom_ui_colors_mod then
        return
    end

    custom_ui_colors_original_settings = {}
    for setting_id, _ in pairs(custom_ui_colors_preset) do
        custom_ui_colors_original_settings[setting_id] = custom_ui_colors_mod:get(setting_id)
    end
end

-- Restores the user's original CustomUIColors settings from cached values.
-- Triggers refresh flags so colors are reapplied on the next update cycle.
local function restore_custom_ui_colors_originals()
    if not custom_ui_colors_original_settings then
        return
    end

    if not custom_ui_colors_mod then
        custom_ui_colors_mod = get_mod("CustomUIColors")
    end
    if not custom_ui_colors_mod then
        return
    end

    for setting_id, value in pairs(custom_ui_colors_original_settings) do
        custom_ui_colors_mod:set(setting_id, value)
    end

    custom_ui_colors_mod._color_changed = true
    custom_ui_colors_mod._alpha_changed = true
end

-- Injects all color and alpha values into CustomUIColors' runtime settings.
-- Triggers refresh flags so colors are reapplied on the next update cycle.
local function apply_custom_ui_colors_preset()
    if not mod:get("enable_custom_ui_colors_preset") then
        return
    end

    -- Resolve CustomUIColors mod reference at runtime
    if not custom_ui_colors_mod then
        custom_ui_colors_mod = get_mod("CustomUIColors")
    end
    if not custom_ui_colors_mod then
        mod:warning("CustomUIColors mod not found, cannot apply colors preset")
        return
    end

    -- Capture original values before overwriting (only runs once)
    capture_custom_ui_colors_originals()

    -- Inject every preset value into CustomUIColors' settings memory
    for setting_id, value in pairs(custom_ui_colors_preset) do
        custom_ui_colors_mod:set(setting_id, value)
    end

    -- Trigger CustomUIColors to reapply all colors on next update
    custom_ui_colors_mod._color_changed = true
    custom_ui_colors_mod._alpha_changed = true
end

-- ============================================================
-- PSYCH WARD PRESET INTEGRATION
-- Integrates with the psych_ward mod to apply a custom button
-- layout optimized for Improved Character Menu. Works entirely
-- through psych_ward's public mod:set and mod:get APIs.
-- Captures original settings before overwriting, and restores
-- them when the user disables the preset toggle.
-- ============================================================
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    if not psych_ward then return end
    capture_psych_ward_originals()
    local sg = definitions.scenegraph_definition
    if not sg then return end
    local preset = psych_ward_preset
    local orig = psych_ward_original_settings
    local use_preset = mod:get("enable_psych_ward_preset")
-- Button scenegraphs that psych_ward creates, mapped to our preset offset/size keys.
    local button_overrides = {
        contracts_button = { x = "contracts_button_x_offset", y = "contracts_button_y_offset", w = "contracts_button_width", h = "contracts_button_height" },
        cosmetics_button = { x = "cosmetics_button_x_offset", y = "cosmetics_button_y_offset", w = "cosmetics_button_width", h = "cosmetics_button_height" },
        crafting_button  = { x = "crafting_button_x_offset",  y = "crafting_button_y_offset",  w = "crafting_button_width",  h = "crafting_button_height" },
        expedition_button = { x = "expedition_button_x_offset", y = "expedition_button_y_offset", w = "expedition_button_width", h = "expedition_button_height" },
        horde_button     = { x = "horde_button_x_offset",     y = "horde_button_y_offset",     w = "horde_button_width",     h = "horde_button_height" },
        inventory_button = { x = "inventory_button_x_offset", y = "inventory_button_y_offset", w = "inventory_button_width", h = "inventory_button_height" },
        meatgrinder_button = { x = "meatgrinder_button_x_offset", y = "meatgrinder_button_y_offset", w = "meatgrinder_button_width", h = "meatgrinder_button_height" },
        mission_button   = { x = "mission_button_x_offset",   y = "mission_button_y_offset",   w = "mission_button_width",   h = "mission_button_height" },
        penance_button   = { x = "penance_button_x_offset",   y = "penance_button_y_offset",   w = "penance_button_width",   h = "penance_button_height" },
        vendor_button    = { x = "vendor_button_x_offset",    y = "vendor_button_y_offset",    w = "vendor_button_width",    h = "vendor_button_height" },
    }
    for btn_name, keys in pairs(button_overrides) do
        local node = sg[btn_name]
        if node and node.position and node.size then
            if use_preset then
                node.position[1] = preset[keys.x]
                node.position[2] = preset[keys.y]
                node.size[1] = preset[keys.w]
                node.size[2] = preset[keys.h]
            elseif orig then
                local px = orig[keys.x]
                local py = orig[keys.y]
                local pw = orig[keys.w]
                local ph = orig[keys.h]
                if px then node.position[1] = px end
                if py then node.position[2] = py end
                if pw then node.size[1] = pw end
                if ph then node.size[2] = ph end
            end
        end
    end
end)

-- (base values cached in mod_self to survive DMF mod reload without offset drift)

-- ============================================================
-- SCROLL SPEED SETUP
-- Increases the DMF options menu scroll speed to 500 so users
-- can reach settings near the bottom without excessive scrolling.
-- Skipped if the user already has a speed of 500 or higher.
-- ============================================================
if dmf then
    local current_speed = dmf:get("dmf_options_scrolling_speed")
    if current_speed == nil or current_speed < 500 then
        dmf:set("dmf_options_scrolling_speed", 500)
    end
end

-- ============================================================
-- HELPER FUNCTIONS
-- get_opt(id, default): Retrieves a saved setting value,
-- returning the provided default if the setting hasn't been changed.
-- should_disable_blur(): Checks whether the user enabled the
-- "Disable Background Blur" option.
-- ============================================================

-- Gets a saved setting value, or returns the default if not yet configured.
local function get_opt(id, default)
    local v = mod:get(id)
    if v == nil then return default end
    return v
end

-- Checks whether the user has enabled "Disable Background Blur".
local function should_disable_blur()
    return get_opt("disable_main_menu_blur", true)
end

-- ============================================================
-- MAIN MENU BLUR SUPPRESSION
-- Intercepts the main menu blur effect at multiple levels to
-- completely disable it when "Disable Background Blur" is enabled.
-- Hooks UIManager, WorldRender, UIWorldSpawner, shader
-- environment, and MainMenuBackgroundView for comprehensive coverage.
-- Also integrates with GuiTweaker if that mod is installed.
-- ============================================================

local MM_MAIN_MENU_WORLD = "ui_main_menu_world"
local MM_MAIN_MENU_VIEWPORT = "ui_main_menu_world_viewport"
local WorldRender = nil

-- Hook #1: Blocks UIManager from requesting fullscreen blur.
mod:hook("UIManager", "use_fullscreen_blur", function(func, self, ...)
    if should_disable_blur() then
        return false, 0
    end
    return func(self, ...)
end)

-- Hook #2: Intercepts world render blur enable/disable functions.
mod:hook_require("scripts/utilities/world_render", function(wr)
    WorldRender = wr
    if type(wr.enable_world_fullscreen_blur) == "function" then
        mod:hook(wr, "enable_world_fullscreen_blur", function(func, world_name, viewport_name, blur_amount, ...)
            if should_disable_blur() and world_name == MM_MAIN_MENU_WORLD then
                return func(world_name, viewport_name, 0, ...)
            end
            return func(world_name, viewport_name, blur_amount, ...)
        end)
    end
    if type(wr.disable_world_fullscreen_blur) == "function" then
        mod:hook(wr, "disable_world_fullscreen_blur", function(func, world_name, viewport_name, ...)
            if should_disable_blur() and world_name == MM_MAIN_MENU_WORLD then
                return func(world_name, viewport_name, ...)
            end
            return func(world_name, viewport_name, ...)
        end)
    end
end)

-- Forces an immediate blur disable call on the main menu world.
local function disable_mm_blur_now()
    if WorldRender and type(WorldRender.disable_world_fullscreen_blur) == "function" then
        WorldRender.disable_world_fullscreen_blur(MM_MAIN_MENU_WORLD, MM_MAIN_MENU_VIEWPORT)
    end
end

-- Hook #3: Intercepts UI world spawner blur value setters.
mod:hook_require("scripts/managers/ui/ui_world_spawner", function(UIWorldSpawner)
    if type(UIWorldSpawner) ~= "table" then return end

    -- Overrides internal blur amount to always be zero.
    if type(UIWorldSpawner._set_world_blur_value) == "function" then
        mod:hook(UIWorldSpawner, "_set_world_blur_value", function(func, self, blur_amount, ...)
            if should_disable_blur() then
                return func(self, 0, ...)
            end
            return func(self, blur_amount, ...)
        end)
    end

    -- Overrides camera blur animations to use zero blur.
    if type(UIWorldSpawner.set_camera_blur) == "function" then
        mod:hook(UIWorldSpawner, "set_camera_blur", function(func, self, blur_amount, duration, anim_func)
            if should_disable_blur() then
                return func(self, 0, duration, anim_func)
            end
            return func(self, blur_amount, duration, anim_func)
        end)
    end

    -- Hook #4: Forces blur off at the shader environment level.
    if type(UIWorldSpawner._shading_callback) == "function" then
        mod:hook(UIWorldSpawner, "_shading_callback", function(func, self, world, shading_env, ...)
            func(self, world, shading_env, ...)
            if should_disable_blur() then
                local world_name = self._world_name
                if world_name == MM_MAIN_MENU_WORLD then
                    ShadingEnvironment.set_scalar(shading_env, "fullscreen_blur_enabled", 0)
                    ShadingEnvironment.set_scalar(shading_env, "dof_enabled", 0)
                end
            end
        end)
    end
end)

-- Clears all blur-related flags and values on the main menu background view.
-- Handles cached state that might otherwise keep blur visible after hooks fire.
local function force_clear_blur(self)
    self._screen_blurred = nil
    self._game_world_fullscreen_blur_enabled = false
    self._game_world_fullscreen_blur_amount = 0
    local ws = self._world_spawner
    if ws then
        ws._blur_animation_data = nil
        ws._current_blur = 0
        if type(ws._set_world_blur_value) == "function" then
            ws:_set_world_blur_value(0)
        end
        if ws._world then
            World.set_data(ws._world, "fullscreen_blur", 0)
        end
    end
    disable_mm_blur_now()
end

-- Hook #5: Intercepts the blur handler called directly by the background view.
mod:hook("MainMenuBackgroundView", "_handle_background_blur", function(func, self, ...)
    if should_disable_blur() then
        force_clear_blur(self)
        return
    end
    return func(self, ...)
end)

-- Hook #6: Clears blur every frame during the background view update loop.
mod:hook("MainMenuBackgroundView", "update", function(func, self, dt, t, input_service)
    if should_disable_blur() then
        force_clear_blur(self)
    end
    return func(self, dt, t, input_service)
end)

-- Hook #7: Clears blur the moment the background view first appears.
mod:hook("MainMenuBackgroundView", "on_enter", function(func, self, ...)
    local result = func(self, ...)
    if should_disable_blur() then
        force_clear_blur(self)
    end
    return result
end)

-- Tells GuiTweaker to stop applying blur, if that mod is installed.
if gui_tweaker and type(gui_tweaker.set_blur_disabled) == "function" then
    if should_disable_blur() then
        gui_tweaker:set_blur_disabled("main_menu_view", true)
        gui_tweaker:set_blur_disabled("main_menu_background_view", true)
    end
end

-- ============================================================
-- TRUE LEVEL CALCULATION
-- Calculates true levels independently so the "Account Level"
-- display includes XP overflow beyond the level cap, even without
-- the true_level mod installed. Fetches XP table and character
-- progression data from the backend API, caching results.
-- ============================================================

-- Persistent table caching XP data and character true levels across mod reloads.
local mod_self = mod:persistent_table("self")

-- Cache for the backend XP table (level_array, total_xp, max_level).
mod_self.xp_settings = mod_self.xp_settings or {}

-- Cache for character true levels, keyed by character_id.
mod_self.true_levels = mod_self.true_levels or {}

-- Flags tracking async fetch state for XP table and progression data.
mod_self.fetching_xp = false
mod_self.fetching_progression = false

-- Queue for progression data received before the XP table is loaded.
mod_self.progression_queue = nil

-- Calculates true level from progression data, including XP overflow beyond the cap.
-- Falls back to current_level if the XP table hasn't been loaded yet.
local function calculate_true_level(base_data)
    local xp_settings = mod_self.xp_settings

    -- If the XP table hasn't been fetched yet, fall back to current level
    if not xp_settings.level_array then
        return base_data.currentLevel
    end

    local level_array = xp_settings.level_array
    local max_level = xp_settings.max_level
    local current_level = base_data.currentLevel
    local current_xp = base_data.currentXp

    -- If below max level, no overflow to calculate
    if current_level < max_level then
        return current_level
    end

    -- Calculate XP needed per level at max level (difference between last two entries)
    local xp_per_level = level_array[max_level] - level_array[max_level - 1]

    -- Calculate total XP needed to reach max level
    local total_xp_for_max = level_array[max_level]

    -- Calculate XP earned beyond the max level cap
    local xp_over_max = current_xp - total_xp_for_max

    -- Calculate additional levels from overflow XP
    local additional_levels = math.floor(xp_over_max / xp_per_level)

    -- True level is base level plus overflow levels
    return current_level + additional_levels
end

-- Fetches the character XP table from the backend API asynchronously.
-- One-time fetch that gets cached for all subsequent level calculations.
local function fetch_xp_table()
    local xp_settings = mod_self.xp_settings

    -- Skip if already fetched or currently in progress
    if xp_settings.level_array or mod_self.fetching_xp then
        return
    end

    mod_self.fetching_xp = true

    -- Request the XP table from the backend progression interface
    local backend_interface = Managers.backend.interfaces
    if not backend_interface or not backend_interface.progression then
        mod:warning("Backend progression interface not available for XP table fetch")
        mod_self.fetching_xp = false
        return
    end

    local xp_promise = backend_interface.progression:get_xp_table("character")

    xp_promise:next(function(xp_per_level_array)
        -- Store the XP table in our persistent cache
        local max_level = #xp_per_level_array
        xp_settings.level_array = xp_per_level_array
        xp_settings.total_xp = xp_per_level_array[max_level]
        xp_settings.max_level = max_level

        mod_self.fetching_xp = false

        -- Process any queued progression data now that we have the XP table
        if mod_self.progression_queue then
            for char_id, data in pairs(mod_self.progression_queue) do
                mod_self.true_levels[char_id] = calculate_true_level(data)
            end
            mod_self.progression_queue = nil
        end
    end):catch(function(e)
        mod:warning("[True Level] Failed to fetch XP table: " .. tostring(e))
        mod_self.fetching_xp = false
    end)
end

-- Fetches progression data for all characters from the backend API.
-- Returns an array of character progression objects with currentXp and currentLevel.
local function fetch_all_character_progression()
    if mod_self.fetching_progression then
        return
    end

    mod_self.fetching_progression = true

    local backend_interface = Managers.backend.interfaces
    if not backend_interface or not backend_interface.progression then
        mod:warning("Backend progression interface not available for character progression fetch")
        mod_self.fetching_progression = false
        return
    end

    local progression_promise = backend_interface.progression:get_entity_type_progression("character")

    progression_promise:next(function(characters_progression)
        mod_self.fetching_progression = false

        for _, data in ipairs(characters_progression) do
            local char_id = data.id

            -- If XP table isn't ready yet, queue this data for later processing
            if not mod_self.xp_settings.level_array then
                if not mod_self.progression_queue then
                    mod_self.progression_queue = {}
                end
                mod_self.progression_queue[char_id] = data
                mod_self.true_levels[char_id] = data.currentLevel
            else
                mod_self.true_levels[char_id] = calculate_true_level(data)
            end
        end
    end):catch(function(e)
        mod:warning("[True Level] Failed to fetch character progression: " .. tostring(e))
        mod_self.fetching_progression = false
    end)
end

-- Sums the true levels of all characters in the main menu.
-- Falls back to profile.current_level if true level data isn't cached yet.
local function sum_account_level_from_widgets(character_widgets)
    local account_level = 0

    if not character_widgets then
        return account_level
    end

    for _, widget in ipairs(character_widgets) do
        local content = widget and widget.content
        local profile = content and content.profile

        if profile then
            local char_id = profile.character_id
            local true_level = char_id and mod_self.true_levels[char_id]

            if true_level then
                -- Use cached true level (includes XP overflow)
                account_level = account_level + true_level
            else
                -- Fallback to current_level if true level not yet calculated
                local fallback = profile.current_level or profile.level or 0
                account_level = account_level + fallback
            end
        end
    end

    return account_level
end

-- Triggers XP table and character progression fetch when the profile list changes.
-- Main entry point for true level calculation.
mod:hook_safe("MainMenuView", "_event_profiles_changed", function(self)
    fetch_xp_table()
    fetch_all_character_progression()
end)

-- ============================================================
-- METAL DECORATIONS TOGGLES
-- Provides individual toggles for each metal frame element and
-- UI decoration on the character select screen. Each toggle
-- sets the alpha of a specific style entry to 0 (hidden) or
-- 255 (visible). Applied every frame to handle engine resets.
-- ============================================================

-- Hides a style entry on a named widget by setting its alpha to zero.
local function hide_style_entry(self, widget_name, style_key)
    local w = self._widgets_by_name and self._widgets_by_name[widget_name]
    if w and w.style and w.style[style_key] then
        local s = w.style[style_key]
        if not s.color then
            s.color = { 0, 0, 0, 0 }
        else
            s.color[1] = 0
        end
        w.dirty = true
    end
end

-- Restores a style entry's alpha to fully visible.
local function show_style_entry(self, widget_name, style_key, default_alpha)
    local w = self._widgets_by_name and self._widgets_by_name[widget_name]
    if w and w.style and w.style[style_key] then
        local s = w.style[style_key]
        if s.color then
            s.color[1] = default_alpha or 255
        end
        w.dirty = true
    end
end

-- Applies all metal decoration visibility toggles to the main menu view.
-- Runs every frame to catch engine widget resets during character switching.
local function apply_metal_decorations(self)
    if not self._widgets_by_name then return end

-- Play Button: hides textures and background elements.
    if not get_opt("show_play_button", true) then
        hide_style_entry(self, "play_button", "style_id_2") -- ready_active icon
        hide_style_entry(self, "play_button", "style_id_3") -- ready_idle icon
        hide_style_entry(self, "play_button", "background") -- background panel
        hide_style_entry(self, "play_button", "background_gradient") -- gradient overlay
    else
        show_style_entry(self, "play_button", "style_id_2", 255)
        show_style_entry(self, "play_button", "style_id_3", 255)
        show_style_entry(self, "play_button", "background", 255)
        show_style_entry(self, "play_button", "background_gradient", 255)
    end

    -- Play Button Position: moves the entire button via scenegraph.
    local pb_sg = self._ui_scenegraph and self._ui_scenegraph.play_button
    if pb_sg and type(self._set_scenegraph_position) == "function" then
        if not mod_self.base_play_button_position then
            mod_self.base_play_button_position = { pb_sg.position[1] or 250, pb_sg.position[2] or 0, pb_sg.position[3] or 2 }
        end
        self:_set_scenegraph_position("play_button", mod_self.base_play_button_position[1] + get_opt("play_button_offset_x", 0), mod_self.base_play_button_position[2] + get_opt("play_button_offset_y", 0))
    end

    -- Archetype Icon: hides the icon texture.
    local ci_widget = self._widgets_by_name and self._widgets_by_name["character_info"]
    if not get_opt("show_archetype_icon", true) then
        hide_style_entry(self, "character_info", "style_id_1") -- archetype icon
    else
        show_style_entry(self, "character_info", "style_id_1", 255)
        if ci_widget and ci_widget.style and ci_widget.style.style_id_1 then
            local ai = ci_widget.style.style_id_1
            if not mod_self.base_archetype_icon_z then mod_self.base_archetype_icon_z = ai.offset[3] or 0 end
            ai.offset = { get_opt("archetype_icon_offset_x", 0), get_opt("archetype_icon_offset_y", -100), mod_self.base_archetype_icon_z }
            ai.dirty = true
        end

        -- Character Text Group: moves name, archetype title, and player title together.
        local ox = get_opt("character_text_offset_x", 0)
        local oy = get_opt("character_text_offset_y", -100)
        local text_styles = { "text_character", "text_archetype", "text_character_title" }
        for _, style_key in ipairs(text_styles) do
            local ts = ci_widget.style[style_key]
            if ts then
                if not mod_self.base_character_text_offsets then mod_self.base_character_text_offsets = {} end
                if not mod_self.base_character_text_offsets[style_key] then
                    mod_self.base_character_text_offsets[style_key] = { ts.offset[1] or 0, ts.offset[2] or 0, ts.offset[3] or 0 }
                end
                local base = mod_self.base_character_text_offsets[style_key]
                ts.offset = { base[1] + ox, base[2] + oy, base[3] }
                ts.dirty = true
            end
        end
    end

    -- Wallet element top divider
    if not get_opt("show_wallet_top", true) then
        hide_style_entry(self, "wallet_element_background", "top_divider")
    else
        show_style_entry(self, "wallet_element_background", "top_divider", 255)
    end

    -- Wallet element bottom divider
    if not get_opt("show_wallet_bottom", true) then
        hide_style_entry(self, "wallet_element_background", "bottom_divider")
    else
        show_style_entry(self, "wallet_element_background", "bottom_divider", 255)
    end

    -- Character list background top frame
    if not get_opt("show_list_top", true) then
        hide_style_entry(self, "character_list_background", "style_id_2")
    else
        show_style_entry(self, "character_list_background", "style_id_2", 255)
    end

    -- Character list background bottom frame
    if not get_opt("show_list_bottom", true) then
        hide_style_entry(self, "character_list_background", "style_id_3")
    else
        show_style_entry(self, "character_list_background", "style_id_3", 255)
    end

    -- Metal corner: top-left
    if not get_opt("show_top_left", true) then
        hide_style_entry(self, "metal_corners", "style_id_3")
    else
        show_style_entry(self, "metal_corners", "style_id_3", 255)
    end

    -- Metal corner: top-right
    if not get_opt("show_top_right", true) then
        hide_style_entry(self, "metal_corners", "style_id_4")
    else
        show_style_entry(self, "metal_corners", "style_id_4", 255)
    end

    -- Metal corner: bottom-left
    if not get_opt("show_bottom_left", true) then
        hide_style_entry(self, "metal_corners", "style_id_1")
    else
        show_style_entry(self, "metal_corners", "style_id_1", 255)
    end

    -- Metal corner: bottom-right
    if not get_opt("show_bottom_right", true) then
        hide_style_entry(self, "metal_corners", "style_id_2")
    else
        show_style_entry(self, "metal_corners", "style_id_2", 255)
    end
end

-- Applies scrollbar visibility toggle to the character grid scrollbar.
local function apply_scrollbar_visibility(self)
    local disable_scrollbar = get_opt("disable_scrollbar", false)
    if disable_scrollbar then
        hide_style_entry(self, "character_grid_scrollbar", "thumb")
        hide_style_entry(self, "character_grid_scrollbar", "track_frame")
        hide_style_entry(self, "character_grid_scrollbar", "track_background")
    else
        show_style_entry(self, "character_grid_scrollbar", "thumb", 255)
        show_style_entry(self, "character_grid_scrollbar", "track_frame", 255)
        show_style_entry(self, "character_grid_scrollbar", "track_background", 255)
    end
end

-- Hides a style entry on a specific widget instance directly.
local function hide_style_on_widget(widget, style_key)
    if widget and widget.style and widget.style[style_key] then
        local s = widget.style[style_key]
        if not s.color then
            s.color = { 0, 0, 0, 0 }
        else
            s.color[1] = 0
        end
        widget.dirty = true
    end
end

-- Shows a style entry on a specific widget instance directly.
local function show_style_on_widget(widget, style_key, default_alpha)
    if widget and widget.style and widget.style[style_key] then
        local s = widget.style[style_key]
        if s.color then
            s.color[1] = default_alpha or 255
        end
        widget.dirty = true
    end
end

-- Applies news feed modifications including visibility toggles and offsets.
-- Routes all changes through the news element's own _widgets_by_name table.
local function apply_news_feed_tweaks(self)
    -- News feed widgets are inside the ViewElementNewsSlide child element.
    local news_element = self._news_element
    if not news_element or not news_element._widgets_by_name then return end

    local news_btn = news_element._widgets_by_name.news_button
    local open_news_btn = news_element._widgets_by_name.open_news_button

    -- Permanently hides open_news_button.
    if open_news_btn then
        open_news_btn.visible = false
        hide_style_on_widget(open_news_btn, "background")
        hide_style_on_widget(open_news_btn, "background_gradient")
        hide_style_on_widget(open_news_btn, "style_id_1")
        hide_style_on_widget(open_news_btn, "style_id_2")
    end

    -- Disable news feed entirely: hides all parts and the widget visibility.
    if get_opt("disable_news_feed", false) then
        hide_style_on_widget(news_btn, "background")
        hide_style_on_widget(news_btn, "title_background")
        hide_style_on_widget(news_btn, "body_background")
        hide_style_on_widget(news_btn, "body_gradient")
        hide_style_on_widget(news_btn, "screen_background")
        hide_style_on_widget(news_btn, "frame")
        hide_style_on_widget(news_btn, "corner")
        hide_style_on_widget(news_btn, "online_image")
        hide_style_on_widget(news_btn, "style_id_7")
        hide_style_on_widget(news_btn, "style_id_8")
        hide_style_on_widget(news_btn, "body_number")
        hide_style_on_widget(news_btn, "body_text")
        hide_style_on_widget(news_btn, "title")
        if news_btn then
            news_btn.visible = false
        end
        -- Still apply offset even when hidden so it's correct when re-enabled
        local ne_sg = news_element._ui_scenegraph and news_element._ui_scenegraph.news_area
        if ne_sg and type(news_element._set_scenegraph_position) == "function" then
            local offset_x = get_opt("news_feed_offset_x", -145)
            local offset_y = get_opt("news_feed_offset_y", 100)
            news_element:_set_scenegraph_position("news_area", offset_x, offset_y)
        end
        return
    end

    -- News feed is enabled: control visibility of specific elements.
    if news_btn then
        news_btn.visible = true
    end

    if news_btn and news_btn.style then
        -- Permanently hide background elements (always hidden regardless of toggle).
        hide_style_on_widget(news_btn, "background")
        hide_style_on_widget(news_btn, "title_background")
        hide_style_on_widget(news_btn, "body_background")
        hide_style_on_widget(news_btn, "body_gradient")

        -- Restore remaining base style entries to visible.
        show_style_on_widget(news_btn, "screen_background", 255)
        show_style_on_widget(news_btn, "frame", 255)
        show_style_on_widget(news_btn, "corner", 255)
        show_style_on_widget(news_btn, "online_image", 255)
        show_style_on_widget(news_btn, "title", 255)
        show_style_on_widget(news_btn, "body_number", 255)
        show_style_on_widget(news_btn, "body_text", 255)

        -- Toggle News Feed Top visibility (style_id_7 = frame pass).
        if not get_opt("show_news_feed_top", true) then
            hide_style_on_widget(news_btn, "style_id_7")
        else
            show_style_on_widget(news_btn, "style_id_7", 255)
        end

        -- Toggle News Feed Bottom visibility (style_id_8 = corner pass).
        if not get_opt("show_news_feed_bottom", true) then
            hide_style_on_widget(news_btn, "style_id_8")
        else
            show_style_on_widget(news_btn, "style_id_8", 255)
        end

        -- Apply title style tweaks
        local ti = news_btn.style.title
        if ti then
            ti.font_size = 19
            ti.dirty = true
        end

        -- Apply body_number style tweaks: font_size=19, size={185, 50} (wide enough for timer text).
        local bn = news_btn.style.body_number
        if bn then
            bn.font_size = 19
            bn.size = { 185, 50 }
            bn.dirty = true
        end

        -- Apply body_text style tweaks: font_size, offset, and text_color.
        local bt = news_btn.style.body_text
        if bt then
            bt.font_size = 19
            bt.text_color = { 255, 255, 255, 255 }
            bt.dirty = true
        end
    end

    -- Apply X/Y offset to news_area scenegraph position.
    local ne_sg = news_element._ui_scenegraph and news_element._ui_scenegraph.news_area
    if ne_sg and type(news_element._set_scenegraph_position) == "function" then
        local offset_x = get_opt("news_feed_offset_x", -145)
        local offset_y = get_opt("news_feed_offset_y", 100)
        news_element:_set_scenegraph_position("news_area", offset_x, offset_y)
    end
end

-- ============================================================
-- DYNAMIC SLOT PADDING
-- Core layout engine that adjusts the character list background,
-- grid mask, scrollbar, create button, and bottom frame so all
-- slots (5-9) fit on screen without scrolling or overlapping.
-- Captures original dimensions on first run as a clean baseline,
-- then resizes everything proportionally based on slot count.
-- ============================================================

-- Stores original scenegraph dimensions as a clean baseline for recalculations.
local original_scenegraph = nil

-- Captures current scenegraph values on first run as the baseline for all adjustments.
local function capture_original_scenegraph(sg)
    if original_scenegraph then return end

    local function safe_size(entry, idx)
        return entry and entry.size and entry.size[idx]
    end

    local function safe_pos(entry, idx)
        return entry and entry.position and entry.position[idx]
    end

    original_scenegraph = {
    -- Background dimensions and position
    character_list_background_w = safe_size(sg.character_list_background, 1),
    character_list_background_h = safe_size(sg.character_list_background, 2),
    character_list_background_y = safe_pos(sg.character_list_background, 2),
        -- Grid dimensions and position
        character_grid_background_w = safe_size(sg.character_grid_background, 1),
        character_grid_background_h = safe_size(sg.character_grid_background, 2),
        character_grid_background_pos_x = safe_pos(sg.character_grid_background, 1),
        character_grid_background_pos_y = safe_pos(sg.character_grid_background, 2),
        character_grid_start_w = safe_size(sg.character_grid_start, 1),
        character_grid_start_h = safe_size(sg.character_grid_start, 2),
        -- Mask dimensions
        character_grid_mask_w = safe_size(sg.character_grid_mask, 1),
        character_grid_mask_h = safe_size(sg.character_grid_mask, 2),
        character_grid_mask_pos_x = safe_pos(sg.character_grid_mask, 1),
        character_grid_mask_pos_y = safe_pos(sg.character_grid_mask, 2),
        -- Interaction dimensions
        character_grid_interaction_w = safe_size(sg.character_grid_interaction, 1),
        character_grid_interaction_h = safe_size(sg.character_grid_interaction, 2),
        -- Scrollbar dimensions
        character_grid_scrollbar_w = safe_size(sg.character_grid_scrollbar, 1),
        character_grid_scrollbar_h = safe_size(sg.character_grid_scrollbar, 2),
    -- Create button position
    create_button_x = safe_pos(sg.create_button, 1),
    create_button_y = safe_pos(sg.create_button, 2),
    -- Slots count position
    slots_count_x = safe_pos(sg.slots_count, 1),
    slots_count_y = safe_pos(sg.slots_count, 2),
    }

    -- Capture original create_button style offset on first run.
    local mm = Managers and Managers.ui and Managers.ui:view_instance("main_menu_view")
    if mm and mm._widgets_by_name then
        local create_widget = mm._widgets_by_name.create_button
        if create_widget and create_widget.style then
            for _, style_entry in pairs(create_widget.style) do
                if style_entry and style_entry.offset and style_entry.offset[2] then
                    original_scenegraph.create_button_style_offset_y = style_entry.offset[2]
                    break
                end
            end
        end
    end
end

-- Recalculates and applies proportional layout adjustments based on slot count.
-- Uses BaseView runtime methods to update already-created widgets.
local function recalculate_dynamic_padding(self, slot_count)
    -- Clamp slot count to the supported range (5 to 9).
    slot_count = math.max(5, math.min(9, slot_count))

    -- Grab the live scenegraph that the renderer actually uses.
    local sg = self._ui_scenegraph
    if not sg then return end

    -- Capture original dimensions on first run to prevent compounding drift.
    capture_original_scenegraph(sg)
    if not original_scenegraph then return end

    local orig = original_scenegraph

    -- How many slots the user wants to display without scrolling (from settings, default 8).
    local max_visible = get_opt("max_visible_slots", 8)
    max_visible = math.max(3, math.min(9, max_visible))

    -- Each character card is 80px tall.
    local slot_height = 80

    -- Calculate visible container height, capped at max_visible slots.
    local visible_height = math.min(slot_count, max_visible) * slot_height

    -- Calculate background height from visible_height, preserving the original padding offset.
    local orig_bg_h = orig.character_list_background_h
    local orig_grid_bg_h = orig.character_grid_background_h
    local padding_offset = orig_bg_h - orig_grid_bg_h
    local new_bg_h = visible_height + padding_offset

    -- ============================================================
    -- STEP 1: Resize the main background container.
    -- Updates both the scenegraph (for layout alignment) and
    -- the widget content size (for the drawn texture size).
    -- ============================================================

    local bg_w = orig.character_list_background_w

    -- 1a. Update Scenegraph (affects children alignment like create_button)
    self:_set_scenegraph_size("character_list_background", bg_w, new_bg_h)

    -- 1b. Background expands symmetrically from vertical center; children follow naturally.
    local orig_grid_pos_x, orig_grid_pos_y = orig.character_grid_background_pos_x or 15, orig.character_grid_background_pos_y or 185
    self:_set_scenegraph_position("character_grid_background", orig_grid_pos_x, orig_grid_pos_y)

    -- 1c. Update Widget Content Size (affects the drawn background texture).
    local bg_widget = self._widgets_by_name and self._widgets_by_name.character_list_background
    if bg_widget and bg_widget.content and bg_widget.content.size then
        bg_widget.content.size[2] = new_bg_h
        bg_widget.dirty = true
    end

    -- 1d. Resize background texture pass to stop exactly at the bottom frame.
    if bg_widget and bg_widget.style and bg_widget.style.background and bg_widget.style.background.size then
        bg_widget.style.background.size[2] = new_bg_h - 125
        bg_widget.style.background.size_addition = { 10, 30 }
        bg_widget.style.background.dirty = true
    end

    -- mod:echo(string.format("[DynamicPadding] Resized character_list_background to %dx%d", bg_w, new_bg_h))

    -- ============================================================
    -- STEP 2: Expand internal grid elements to fill the background.
    -- Resizes all grid containers proportionally to prevent empty
    -- space (ghost slots) and stop centering logic from triggering.
    -- ============================================================

    -- 2a. Resize grid background to match visible height.
    local grid_bg_w, grid_bg_h = orig.character_grid_background_w, orig.character_grid_background_h
    self:_set_scenegraph_size("character_grid_background", grid_bg_w, visible_height)
    -- mod:echo(string.format("[DynamicPadding] Resized grid background to %dx%d", grid_bg_w, visible_height))

    -- 2b. Resize grid start container (the UIWidgetGrid area viewport).
    local grid_start_w, grid_start_h = orig.character_grid_start_w, orig.character_grid_start_h
    self:_set_scenegraph_size("character_grid_start", grid_start_w, visible_height)
    -- mod:echo(string.format("[DynamicPadding] Resized grid start to %dx%d", grid_start_w, visible_height))

    -- 2c. Resize grid mask to match visible area with slight edge clipping.
    local mask_w, mask_h = orig.character_grid_mask_w, orig.character_grid_mask_h
    local new_mask_h = visible_height + (mask_h - grid_bg_h) - 19 + 5
    local orig_mask_x = orig.character_grid_mask_pos_x or 0
    local orig_mask_y = orig.character_grid_mask_pos_y or 0
    self:_set_scenegraph_size("character_grid_mask", mask_w, new_mask_h)
    self:_set_scenegraph_position("character_grid_mask", orig_mask_x, orig_mask_y - 5)
    -- mod:echo(string.format("[DynamicPadding] Resized grid mask to %dx%d", mask_w, new_mask_h))

    -- 2d. Resize grid interaction area to match visible viewport.
    local interaction_w, interaction_h = orig.character_grid_interaction_w, orig.character_grid_interaction_h
    self:_set_scenegraph_size("character_grid_interaction", interaction_w, visible_height)
    -- mod:echo(string.format("[DynamicPadding] Resized grid interaction to %dx%d", interaction_w, visible_height))

    -- 2e. Resize scrollbar to match visible area height.
    local scrollbar_w = orig.character_grid_scrollbar_w
    self:_set_scenegraph_size("character_grid_scrollbar", scrollbar_w, visible_height)
    -- mod:echo("[DynamicPadding] Resized scrollbar")

    -- ============================================================
    -- STEP 3: Adjust Button and Slots Count Offsets.
    -- Clear residual style offsets to avoid conflicts with scenegraph positioning.
    -- ============================================================

    -- 3a. Adjust Create Button Offset: clear style offset so scenegraph handles positioning.
    local create_widget = self._widgets_by_name and self._widgets_by_name.create_button
    if create_widget and create_widget.style then
        for _, style_entry in pairs(create_widget.style) do
            if style_entry and style_entry.offset and style_entry.offset[2] then
                style_entry.offset[2] = 0
                style_entry.dirty = true
            end
        end
        create_widget.dirty = true
    end
    -- mod:echo("[DynamicPadding] Reset create_button style offset (scenegraph handles positioning)")

    -- ============================================================
    -- STEP 4: Update Bottom Metal Frame Offset.
    -- Frame is anchored bottom with offset 0; mark dirty for engine refresh.
    -- ============================================================

    if bg_widget and bg_widget.style and bg_widget.style.style_id_3 then
        bg_widget.style.style_id_3.dirty = true
    end

    -- ============================================================
    -- STEP 5: Force Layout Updates.
    -- ============================================================

    self:_force_update_scenegraph()
    -- mod:echo("[DynamicPadding] Called _force_update_scenegraph()")

    if self._character_list_grid and type(self._character_list_grid.force_update_list_size) == "function" then
        self._character_list_grid:force_update_list_size()
        -- mod:echo("[DynamicPadding] Called grid:force_update_list_size()")
    end

    -- mod:echo("[DynamicPadding] Layout update complete")
end

-- ============================================================
-- CHARACTER SELECT GRID TWEAKS
-- Handles visual customization of character cards including
-- font size, icon sizes, portrait/insignia scale and position,
-- and grid divider visibility. Hooks into MainMenuView lifecycle
-- to apply tweaks at the right times during card rendering.
-- ============================================================

-- Adjusts create button size and character info line spacing in the selection grid.
mod:hook_require("scripts/ui/pass_templates/character_select_pass_templates", function(instance)
    if instance.character_create_size then
        instance.character_create_size[2] = 80
    end
    if instance.character_info_margin then
        instance.character_info_margin[2] = 6
    end
end)

-- Base sizes for insignias and portraits before user scaling is applied.
local BASE_INSIGNIA_SIZE = { 25, 62.5 }
local BASE_PORTRAIT_SIZE = { 60, 67 }

-- Applies all user-chosen visual tweaks to a single character card widget.
-- Includes font size, icon size, scale, position, and divider visibility.
local function apply_tweaks(widget)
    if not widget or not widget.style then return end

    -- Character name text size.
    local cn = widget.style.character_name
    if cn then
        cn.font_size = get_opt("character_name_font_size", 21)
        cn.size = { cn.size[1] or 400, 10 }
        cn.dirty = true
    end

    -- Archetype title position.
    local cat = widget.style.character_archetype_title
    if cat then
        cat.offset = { cat.offset[1] or 130, 6, cat.offset[3] or 1 }
        cat.dirty = true
    end

    -- Insignia size and horizontal position.
    local ci = widget.style.character_insignia
    if ci then
        local scale = get_opt("character_insignia_scale", 1)
        ci.size = { BASE_INSIGNIA_SIZE[1] * scale, BASE_INSIGNIA_SIZE[2] * scale }
        ci.offset = { get_opt("character_insignia_offset_x", 30), 0, ci.offset[3] or 62 }
        ci.dirty = true
    end

    -- Portrait size and horizontal position.
    local cp = widget.style.character_portrait
    if cp then
        local scale = get_opt("character_portrait_scale", 1)
        cp.size = { BASE_PORTRAIT_SIZE[1] * scale, BASE_PORTRAIT_SIZE[2] * scale }
        cp.offset = { get_opt("character_portrait_offset_x", 0), cp.offset[2] or 0, cp.offset[3] or 0 }
        cp.dirty = true
    end

    -- Archetype icon size.
    local ai = widget.style.archetype_icon
    if ai then
        local sz = get_opt("archetype_icon_size", 75)
        ai.size = { sz, sz }
        ai.dirty = true
    end

    -- Hide top and bottom dividers on each character card if enabled.
    local hide_dividers = get_opt("disable_grid_dividers", true)
    if hide_dividers then
        local bottom_divider = widget.style["style_id_7"]
        if bottom_divider then
            if not bottom_divider.color then
                bottom_divider.color = { 0, 0, 0, 0 }
            else
                bottom_divider.color[1] = 0
            end
        end
        local top_divider = widget.style["style_id_8"]
        if top_divider then
            if not top_divider.color then
                top_divider.color = { 0, 0, 0, 0 }
            else
                top_divider.color[1] = 0
            end
        end
    else
        local bottom_divider = widget.style["style_id_7"]
        if bottom_divider then
            if not bottom_divider.color then
                bottom_divider.color = { 255, 255, 255, 255 }
            else
                bottom_divider.color[1] = 255
            end
        end
        local top_divider = widget.style["style_id_8"]
        if top_divider then
            if not top_divider.color then
                top_divider.color = { 255, 255, 255, 255 }
            else
                top_divider.color[1] = 255
            end
        end
    end

    -- Mark the widget as needing a redraw so changes appear immediately.
    widget.dirty = true
end

-- Replaces "X / Y characters" with "Slots Remaining: x" and "Account Level: x".
-- Account level sums cached true levels, falling back to current_level if needed.
local function force_slots_count_text(self)
    local widgets = self._widgets_by_name
    if not widgets then return end

    -- Find the slots_count widget by name or by searching all widgets.
    local slots_widget = widgets.slots_count
    if not slots_widget then
        -- Fallback: search through all widgets for the slots_count scenegraph_id
        for _, widget in pairs(widgets) do
            if widget.scenegraph_id == "slots_count" then
                slots_widget = widget
                break
            end
        end
    end
    if not slots_widget then return end

    -- Darktide's hard limit for active character cards is currently 9.
    local MAX_CHARACTER_SLOTS = 9

    -- _character_slot_spawn_id reflects the UI spawn count, but if the account
    -- has reached the cap or has more slots initialized, we take the higher value.
    local total_slots = math.max(MAX_CHARACTER_SLOTS, self._character_slot_spawn_id or 0)

    -- Calculate total slots and occupied slots.
    local profiles = self._character_profiles
    local occupied_slots = profiles and #profiles or 0
    local remaining = math.max(0, total_slots - occupied_slots)

    -- Calculate account level by summing true levels of all characters.
    local account_level = sum_account_level_from_widgets(self._character_list_widgets)

    -- Update widget text with slots remaining and account level on two lines.
    local slot_content = slots_widget.content
    if slot_content then
        local text = "Slots Remaining: " .. tostring(remaining) .. "\nAccount Level: " .. tostring(account_level)
        if slot_content.string then
            slot_content.string = text
        elseif slot_content.text then
            slot_content.text = text
        end
        slots_widget.dirty = true
    end
end

-- Moves slots_count text to user-specified X/Y offsets.
-- Screen-relative since slots_count is anchored to screen bottom.
local function force_slots_count_position(self)
    local offset_x = get_opt("account_info_offset_x", 820)
    local offset_y = get_opt("account_info_offset_y", -50)

    -- Update live scenegraph position
    if type(self._set_scenegraph_position) == "function" then
        self:_set_scenegraph_position("slots_count", offset_x, offset_y)
    end

    -- Force parent and anchors to decouple slots_count from the resizable background.
    local live_sg = self._ui_scenegraph
    if live_sg and live_sg.slots_count then
        live_sg.slots_count.parent = "screen"
        live_sg.slots_count.vertical_anchor = "bottom"
        live_sg.slots_count.horizontal_anchor = "center"
    end

    -- Update definitions table for view recreation.
    local sg = self.scenegraph_definition
    if sg and sg.slots_count and sg.slots_count.position then
        sg.slots_count.position[1] = offset_x
        sg.slots_count.position[2] = offset_y
    end
end

-- Intercepts _set_scenegraph_position to lock slots_count in place.
-- Uses rawget to bypass the scenegraph's __index metamethod for missing nodes.
mod:hook("BaseView", "_set_scenegraph_position", function(func, self, scenegraph_id, x, y, z)
    if scenegraph_id == "slots_count" and self._ui_scenegraph and self._ui_scenegraph.slots_count then
        local offset_x = get_opt("account_info_offset_x", 820)
        local offset_y = get_opt("account_info_offset_y", -50)
        return func(self, "slots_count", offset_x, offset_y, z)
    end
    -- Only forward the call if the scenegraph node actually exists in this view.
    -- Uses rawget to bypass the scenegraph table's __index metamethod, which
    -- throws an error when accessing undefined field names (e.g. TalentBuilderView
    -- calling _set_scenegraph_position on "scroll_background" which isn't defined).
    if self._ui_scenegraph and rawget(self._ui_scenegraph, scenegraph_id) then
        return func(self, scenegraph_id, x, y, z)
    end
end)

-- Re-applies all visual tweaks to every visible character card.
-- Called whenever settings change so updates appear instantly.
local function refresh_all()
    local mm = Managers and Managers.ui and Managers.ui:view_instance("main_menu_view")
    if not mm then return end
    -- Re-apply dynamic padding based on current slot count.
    local profiles = mm._character_profiles
    local slot_count = profiles and #profiles or 0
    slot_count = math.max(5, math.min(9, slot_count))
    recalculate_dynamic_padding(mm, slot_count)
    if mm._character_list_widgets then
        for i = 1, #mm._character_list_widgets do
            local w = mm._character_list_widgets[i]
            apply_tweaks(w)
        end
    end
    force_slots_count_position(mm)
    apply_metal_decorations(mm)
    apply_scrollbar_visibility(mm)
    apply_news_feed_tweaks(mm)
    local renderer = mm._character_list_renderer
    if renderer then
        mm._render_settings.dirty = true
    end
end

-- Hook: Apply tweaks when a character card is populated with profile data.
mod:hook("MainMenuView", "_set_player_profile_information", function(func, self, profile, widget, ...)
    local result = func(self, profile, widget, ...)
    apply_tweaks(widget)
    return result
end)

-- Hook: Reposition slots_count and apply dynamic padding when the character list is rebuilt.
mod:hook("MainMenuView", "_sync_character_slots", function(func, self, ...)
    local result = func(self, ...)
    -- Determine how many character slots exist and adjust layout.
    local profiles = self._character_profiles
    local slot_count = profiles and #profiles or 0
    -- Clamp to the supported range of 5 to 9 slots.
    slot_count = math.max(5, math.min(9, slot_count))
    recalculate_dynamic_padding(self, slot_count)
    force_slots_count_position(self)
    force_slots_count_text(self)
    apply_scrollbar_visibility(self)
    apply_news_feed_tweaks(self)
    return result
end)

-- Hook: Reposition slots_count, apply padding, and re-apply decorations when entering the main menu.
mod:hook("MainMenuView", "on_enter", function(func, self, ...)
    local result = func(self, ...)
    local profiles = self._character_profiles
    local slot_count = profiles and #profiles or 0
    slot_count = math.max(5, math.min(9, slot_count))
    recalculate_dynamic_padding(self, slot_count)
    force_slots_count_position(self)
    force_slots_count_text(self)
    apply_metal_decorations(self)
    apply_scrollbar_visibility(self)
    apply_news_feed_tweaks(self)
    return result
end)

-- Hook: Re-apply decorations on every frame to handle widget resets.
mod:hook("MainMenuView", "update", function(func, self, dt, t, input_service)
    apply_metal_decorations(self)
    apply_scrollbar_visibility(self)
    apply_news_feed_tweaks(self)
    force_slots_count_position(self)
    force_slots_count_text(self)
    return func(self, dt, t, input_service)
end)

-- ============================================================
-- News Slide Element Configuration
-- ============================================================
local NEWS_SLIDE_ELEMENTS = {
    title = "Title Text",
    body_text = "Body Text",
    body_number = "Countdown Timer",
}

local NEWS_SLIDE_DEFAULTS = {
    title = {
        vertical_alignment = "top",
        text_vertical_alignment = "top",
        horizontal_alignment = "center",
        text_horizontal_alignment = "center",
    },
    body_text = {
        vertical_alignment = "top",
        text_vertical_alignment = "top",
        horizontal_alignment = "center",
        text_horizontal_alignment = "center",
    },
    body_number = {
        vertical_alignment = "top",
        text_vertical_alignment = "top",
        horizontal_alignment = "center",
        text_horizontal_alignment = "center",
    },
}

local NEWS_SLIDE_SETTING_IDS = {
    title = "title_text_offset_y",
    body_text = "body_text_offset_y",
    body_number = "countdown_timer_offset_y",
}

-- Hook: Applies slider-based Y offsets to news slide text elements.
-- Hooks ViewElementBase._draw_widgets (called by ViewElementNewsSlide.super._draw_widgets)
-- to set our offsets RIGHT BEFORE UIWidget.draw() reads them.
-- This prevents the original ViewElementNewsSlide._draw_widgets from overwriting them.
-- All three elements (timer, body text, title) use independent slider values.
mod:hook("ViewElementBase", "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer, render_settings)
    if not self._widgets_by_name or not self._widgets_by_name.news_button then
        return func(self, dt, t, input_service, ui_renderer, render_settings)
    end

    local news_btn = self._widgets_by_name.news_button
    local style = news_btn.style
    if not style then
        return func(self, dt, t, input_service, ui_renderer, render_settings)
    end

    for game_name, defaults in pairs(NEWS_SLIDE_DEFAULTS) do
        local element = style[game_name]
        if element then
            for key, value in pairs(defaults) do
                element[key] = value
            end
            local setting_id = NEWS_SLIDE_SETTING_IDS[game_name]
            local offset_y = mod:get(setting_id) or 88
            offset_y = math.max(15, math.min(175, offset_y))
            if element.offset then
                element.offset[2] = offset_y
            end
        end
    end

    return func(self, dt, t, input_service, ui_renderer, render_settings)
end)

-- Adjusts scrollbar height to fit the more compact layout.
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    local sg = definitions.scenegraph_definition
    if sg and sg.character_grid_scrollbar and sg.character_grid_scrollbar.size then
        sg.character_grid_scrollbar.size[2] = 323.265
    end
end)

-- Moves the "Create Character" button to center vertically with the bottom metal frame.
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    local sg = definitions.scenegraph_definition
    if sg and sg.create_button and sg.create_button.position then
        sg.create_button.position[2] = 40
    end
end)

-- Moves the bottom metal frame flush with the container bottom edge.
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    local widget_defs = definitions.widget_definitions
    if widget_defs and widget_defs.character_list_background then
        for _, pass in ipairs(widget_defs.character_list_background) do
            if pass.style and pass.style.vertical_alignment == "bottom" and pass.style.size and pass.style.size[2] == 134 then
                pass.style.offset[2] = 0
            end
        end
    end
end)

-- Anchors slots_count to screen bottom so it stays fixed regardless of resizing.
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    local sg = definitions.scenegraph_definition
    if sg and sg.slots_count then
        sg.slots_count.parent = "screen"
        sg.slots_count.vertical_anchor = "bottom"
        sg.slots_count.horizontal_anchor = "center"
        sg.slots_count.position = { get_opt("account_info_offset_x", 820), get_opt("account_info_offset_y", -50) }
    end
end)

-- Changes character_grid_mask to top-aligned so it expands downward with the grid.
mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(definitions)
    local sg = definitions.scenegraph_definition
    if sg and sg.character_grid_mask then
        sg.character_grid_mask.vertical_alignment = "top"
    end
end)

-- ============================================================
-- PRESET APPLICATION ON MOD LOAD
-- Applies enabled presets immediately so they're active from
-- the moment the main menu appears, without requiring toggles.
-- ============================================================
if mod:get("enable_psych_ward_preset") then
    apply_psych_ward_preset()
end

if mod:get("enable_custom_ui_colors_preset") then
    apply_custom_ui_colors_preset()
end

-- ============================================================
-- SETTING CHANGE CALLBACK
-- Called automatically whenever the user changes any setting.
-- Handles special cases like blur, psych_ward preset, and
-- CustomUIColors preset, then refreshes all visual tweaks.
-- ============================================================
mod.on_setting_changed = function(setting_id)
    if setting_id == "disable_main_menu_blur" then
        if gui_tweaker and type(gui_tweaker.set_blur_disabled) == "function" then
            if get_opt("disable_main_menu_blur", true) then
                gui_tweaker:set_blur_disabled("main_menu_view", true)
                gui_tweaker:set_blur_disabled("main_menu_background_view", true)
            else
                gui_tweaker:set_blur_disabled("main_menu_view", false)
                gui_tweaker:set_blur_disabled("main_menu_background_view", false)
            end
        end
    end
    if setting_id == "enable_psych_ward_preset" then
        local enabled = mod:get("enable_psych_ward_preset")

        if enabled then
            apply_psych_ward_preset()
        end

        -- Update both live scenegraph and definitions table for view recreation.
        local defs = require("scripts/ui/views/main_menu_view/main_menu_view_definitions")
        local def_sg = defs and defs.scenegraph_definition

        local mm = Managers and Managers.ui and Managers.ui:view_instance("main_menu_view")
        local live_sg = mm and mm._ui_scenegraph

        local button_keys = {
            contracts_button = { x = "contracts_button_x_offset", y = "contracts_button_y_offset", w = "contracts_button_width", h = "contracts_button_height" },
            cosmetics_button = { x = "cosmetics_button_x_offset", y = "cosmetics_button_y_offset", w = "cosmetics_button_width", h = "cosmetics_button_height" },
            crafting_button  = { x = "crafting_button_x_offset",  y = "crafting_button_y_offset",  w = "crafting_button_width",  h = "crafting_button_height" },
            expedition_button = { x = "expedition_button_x_offset", y = "expedition_button_y_offset", w = "expedition_button_width", h = "expedition_button_height" },
            horde_button     = { x = "horde_button_x_offset",     y = "horde_button_y_offset",     w = "horde_button_width",     h = "horde_button_height" },
            inventory_button = { x = "inventory_button_x_offset", y = "inventory_button_y_offset", w = "inventory_button_width", h = "inventory_button_height" },
            meatgrinder_button = { x = "meatgrinder_button_x_offset", y = "meatgrinder_button_y_offset", w = "meatgrinder_button_width", h = "meatgrinder_button_height" },
            mission_button   = { x = "mission_button_x_offset",   y = "mission_button_y_offset",   w = "mission_button_width",   h = "mission_button_height" },
            penance_button   = { x = "penance_button_x_offset",   y = "penance_button_y_offset",   w = "penance_button_width",   h = "penance_button_height" },
            vendor_button    = { x = "vendor_button_x_offset",    y = "vendor_button_y_offset",    w = "vendor_button_width",    h = "vendor_button_height" },
        }
        for btn_name, keys in pairs(button_keys) do
            if enabled then
                -- Apply preset to both definitions and live scenegraph.
                if def_sg and def_sg[btn_name] and def_sg[btn_name].position and def_sg[btn_name].size then
                    def_sg[btn_name].position[1] = psych_ward_preset[keys.x]
                    def_sg[btn_name].position[2] = psych_ward_preset[keys.y]
                    def_sg[btn_name].size[1] = psych_ward_preset[keys.w]
                    def_sg[btn_name].size[2] = psych_ward_preset[keys.h]
                end
                if live_sg and live_sg[btn_name] and live_sg[btn_name].position and live_sg[btn_name].size then
                    live_sg[btn_name].position[1] = psych_ward_preset[keys.x]
                    live_sg[btn_name].position[2] = psych_ward_preset[keys.y]
                    live_sg[btn_name].size[1] = psych_ward_preset[keys.w]
                    live_sg[btn_name].size[2] = psych_ward_preset[keys.h]
                end
            elseif psych_ward_original_settings then
                -- Revert to original psych_ward settings.
                local orig = psych_ward_original_settings
                local px = orig[keys.x]
                local py = orig[keys.y]
                local pw = orig[keys.w]
                local ph = orig[keys.h]
                if px and def_sg and def_sg[btn_name] and def_sg[btn_name].position then
                    def_sg[btn_name].position[1] = px
                end
                if py and def_sg and def_sg[btn_name] and def_sg[btn_name].position then
                    def_sg[btn_name].position[2] = py
                end
                if pw and def_sg and def_sg[btn_name] and def_sg[btn_name].size then
                    def_sg[btn_name].size[1] = pw
                end
                if ph and def_sg and def_sg[btn_name] and def_sg[btn_name].size then
                    def_sg[btn_name].size[2] = ph
                end
                if live_sg and live_sg[btn_name] and live_sg[btn_name].position and live_sg[btn_name].size then
                    if px then live_sg[btn_name].position[1] = px end
                    if py then live_sg[btn_name].position[2] = py end
                    if pw then live_sg[btn_name].size[1] = pw end
                    if ph then live_sg[btn_name].size[2] = ph end
                end
            end
        end

        -- Force scenegraph recalculation so world_position values update for rendering.
        if mm and type(mm._force_update_scenegraph) == "function" then
            mm:_force_update_scenegraph()
        elseif mm then
            mm._update_scenegraph = true
        end
    end
    -- Custom UI Colors: applies or reverts via CustomUIColors mod:set() API.
    if setting_id == "enable_custom_ui_colors_preset" then
        if mod:get("enable_custom_ui_colors_preset") then
            apply_custom_ui_colors_preset()
        else
            restore_custom_ui_colors_originals()
        end
    end
    refresh_all()
end
