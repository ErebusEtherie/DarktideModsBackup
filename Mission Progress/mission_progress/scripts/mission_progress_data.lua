local mod = get_mod("mission_progress")

-- ############################################
-- Preset Definitions for Dropdown
-- ############################################

local preset_options = {
    { text = "preset_default", value = "default" },
    { text = "preset_custom", value = "custom" },
    { text = "preset_minimal", value = "minimal" },
    { text = "preset_neon_cyber", value = "neon_cyber" },
    { text = "preset_imperium", value = "imperium" },
    { text = "preset_mechanicus", value = "mechanicus" },
    { text = "preset_inquisition", value = "inquisition" },
    { text = "preset_chaos", value = "chaos" },
    { text = "preset_veteran", value = "veteran" },
    { text = "preset_zealot", value = "zealot" },
    { text = "preset_ogryn", value = "ogryn" },
    { text = "preset_psyker", value = "psyker" },
    { text = "preset_stealth", value = "stealth" },
    { text = "preset_hive_world", value = "hive_world" },
    { text = "preset_void_born", value = "void_born" },
    { text = "preset_death_guard", value = "death_guard" },
}

local screen_edge_options = {
    { text = "screen_edge_right", value = "right" },
    { text = "screen_edge_left", value = "left" },
}

local orientation_options = {
    { text = "orientation_vertical", value = "vertical" },
    { text = "orientation_horizontal", value = "horizontal" },
}

-- ############################################
-- Data Definition
-- ############################################

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    allow_rehooking = true,
    
    options = {
        widgets = {
            -- ============================================
            -- THEME (first - pick your preset)
            -- ============================================
            {
                setting_id = "theme_preset",
                type = "dropdown",
                default_value = "default",
                options = preset_options,
            },
            
            -- ============================================
            -- POSITION & LAYOUT (orientation & placement)
            -- ============================================
            {
                setting_id = "group_position",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "bar_orientation",
                        type = "dropdown",
                        default_value = "vertical",
                        options = orientation_options,
                    },
                    {
                        setting_id = "bar_screen_edge",
                        type = "dropdown",
                        default_value = "right",
                        options = screen_edge_options,
                    },
                    {
                        setting_id = "bar_invert_direction",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "bar_invert_tags",
                        type = "checkbox",
                        default_value = false,
                    },
                },
            },
            
            -- ============================================
            -- SIZE & APPEARANCE
            -- ============================================
            {
                setting_id = "group_size",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "bar_width",
                        type = "numeric",
                        default_value = 10,
                        range = { 4, 30 },
                    },
                    {
                        setting_id = "bar_height",
                        type = "numeric",
                        default_value = 250,
                        range = { 100, 500 },
                    },
                    {
                        setting_id = "bar_edge_offset",
                        type = "numeric",
                        default_value = 20,
                        range = { 5, 200 },
                    },
                    {
                        setting_id = "bar_vertical_offset",
                        type = "numeric",
                        default_value = 20,
                        range = { -200, 200 },
                    },
                    {
                        setting_id = "bar_opacity",
                        type = "numeric",
                        default_value = 100,
                        range = { 10, 100 },
                    },
                },
            },
            
            -- ============================================
            -- TEXT SETTINGS
            -- ============================================
            {
                setting_id = "group_text",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "bar_font_size",
                        type = "numeric",
                        default_value = 14,
                        range = { 10, 24 },
                    },
                    {
                        setting_id = "decimal_precision",
                        type = "numeric",
                        default_value = 1,
                        range = { 0, 2 },
                    },
                    {
                        setting_id = "show_distance",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "show_percentage",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            
            -- ============================================
            -- MARKERS (what to show on the bar)
            -- ============================================
            {
                setting_id = "group_markers",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "show_progress_bar",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "show_medicae_markers",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "show_beacon_markers",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "show_grimoire_markers",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "show_scripture_markers",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            
            -- ============================================
            -- MARKER COLOR OVERRIDES (works with any theme)
            -- ============================================
            {
                setting_id = "group_marker_colors",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "override_marker_colors",
                        type = "checkbox",
                        default_value = false,
                    },
                    -- Grimoire colors (PURPLE)
                    {
                        setting_id = "grimoire_color_r",
                        type = "numeric",
                        default_value = 160,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "grimoire_color_g",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "grimoire_color_b",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    -- Scripture colors (PURPLE by default)
                    {
                        setting_id = "scripture_color_r",
                        type = "numeric",
                        default_value = 160,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "scripture_color_g",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "scripture_color_b",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    -- Beacon colors (GREEN)
                    {
                        setting_id = "beacon_color_r",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "beacon_color_g",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "beacon_color_b",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    -- Medicae colors (RED/ORANGE)
                    {
                        setting_id = "medicae_color_r",
                        type = "numeric",
                        default_value = 100,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "medicae_color_g",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "medicae_color_b",
                        type = "numeric",
                        default_value = 40,
                        range = { 0, 255 },
                    },
                },
            },
            
            -- ============================================
            -- CUSTOM DIMENSIONS (only when preset = custom)
            -- ============================================
            {
                setting_id = "group_dimensions",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "custom_bar_width",
                        type = "numeric",
                        default_value = 10,
                        range = { 4, 30 },
                    },
                    {
                        setting_id = "custom_bar_height",
                        type = "numeric",
                        default_value = 300,
                        range = { 100, 500 },
                    },
                    {
                        setting_id = "custom_screen_edge",
                        type = "dropdown",
                        default_value = "right",
                        options = screen_edge_options,
                    },
                    {
                        setting_id = "custom_edge_offset",
                        type = "numeric",
                        default_value = 20,
                        range = { 5, 200 },
                    },
                    {
                        setting_id = "custom_vertical_offset",
                        type = "numeric",
                        default_value = 50,
                        range = { -200, 200 },
                    },
                },
            },
            
            -- ============================================
            -- CUSTOM COLORS (only when preset = custom)
            -- ============================================
            {
                setting_id = "group_colors",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "custom_bar_bg_r",
                        type = "numeric",
                        default_value = 20,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_bg_g",
                        type = "numeric",
                        default_value = 20,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_bg_b",
                        type = "numeric",
                        default_value = 30,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_bg_a",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_fill_r",
                        type = "numeric",
                        default_value = 40,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_fill_g",
                        type = "numeric",
                        default_value = 100,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_fill_b",
                        type = "numeric",
                        default_value = 40,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_fill_a",
                        type = "numeric",
                        default_value = 255,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_border_r",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_border_g",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_border_b",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_bar_border_a",
                        type = "numeric",
                        default_value = 220,
                        range = { 0, 255 },
                    },
                },
            },
            
            -- ============================================
            -- CUSTOM MARKER COLORS (only when preset = custom)
            -- ============================================
            {
                setting_id = "group_custom_markers",
                type = "group",
                sub_widgets = {
                    -- Medicae (green-ish)
                    {
                        setting_id = "custom_medicae_r",
                        type = "numeric",
                        default_value = 40,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_medicae_g",
                        type = "numeric",
                        default_value = 100,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_medicae_b",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    -- Beacon (green)
                    {
                        setting_id = "custom_beacon_r",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_beacon_g",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_beacon_b",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                    -- Grimoire (purple)
                    {
                        setting_id = "custom_grimoire_r",
                        type = "numeric",
                        default_value = 160,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_grimoire_g",
                        type = "numeric",
                        default_value = 60,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_grimoire_b",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    -- Scripture (gold)
                    {
                        setting_id = "custom_scripture_r",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_scripture_g",
                        type = "numeric",
                        default_value = 180,
                        range = { 0, 255 },
                    },
                    {
                        setting_id = "custom_scripture_b",
                        type = "numeric",
                        default_value = 80,
                        range = { 0, 255 },
                    },
                },
            },
            
            -- ============================================
            -- KEYBIND
            -- ============================================
            {
                setting_id = "toggle_visibility_key",
                type = "keybind",
                default_value = {},
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "toggle_visibility",
            },
        },
    },
}
