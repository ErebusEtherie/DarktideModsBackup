return {
    mod_name = {
        en = "Mission Progress",
    },
    mod_description = {
        en = "Displays a visual progress bar showing mission completion, medicae station locations with charge counts, and distance to extraction.",
    },
    
    -- ############################################
    -- Position & Layout Group
    -- ############################################
    group_position = {
        en = "Position & Layout",
    },
    bar_orientation = {
        en = "Orientation",
    },
    bar_orientation_description = {
        en = "Display the bar vertically (side of screen) or horizontally (top/bottom).",
    },
    orientation_vertical = {
        en = "Vertical",
    },
    orientation_horizontal = {
        en = "Horizontal",
    },
    bar_screen_edge = {
        en = "Screen Edge",
    },
    bar_screen_edge_description = {
        en = "Which side of the screen to display the progress bar. For vertical: left/right. For horizontal: top/bottom.",
    },
    bar_invert_direction = {
        en = "Invert Direction",
    },
    bar_invert_direction_description = {
        en = "Flip the bar so 0% is at top/left and 100% is at bottom/right.",
    },
    bar_invert_tags = {
        en = "Invert Tags",
    },
    bar_invert_tags_description = {
        en = "Swap the sides where percentage text and medicae markers appear.",
    },
    
    -- ############################################
    -- Size & Appearance Group
    -- ############################################
    group_size = {
        en = "Size & Appearance",
    },
    bar_width = {
        en = "Bar Width",
    },
    bar_width_description = {
        en = "Thickness of the progress bar in pixels (4-30).",
    },
    bar_height = {
        en = "Bar Height",
    },
    bar_height_description = {
        en = "Length of the progress bar in pixels (100-500).",
    },
    bar_edge_offset = {
        en = "Edge Distance",
    },
    bar_edge_offset_description = {
        en = "Distance from the screen edge in pixels (5-200).",
    },
    bar_vertical_offset = {
        en = "Position Offset",
    },
    bar_vertical_offset_description = {
        en = "Offset from center along the bar's length. Positive = down/right (-200 to 200).",
    },
    bar_opacity = {
        en = "Opacity",
    },
    bar_opacity_description = {
        en = "Overall transparency of the progress bar (10-100%).",
    },
    
    -- ############################################
    -- Text Settings Group
    -- ############################################
    group_text = {
        en = "Text Settings",
    },
    bar_font_size = {
        en = "Font Size",
    },
    bar_font_size_description = {
        en = "Size of text for percentage and distance (10-24).",
    },
    decimal_precision = {
        en = "Decimal Precision",
    },
    decimal_precision_description = {
        en = "Number of decimal places for percentage (0-2).",
    },
    show_distance = {
        en = "Show Distance",
    },
    show_distance_description = {
        en = "Display remaining distance to extraction.",
    },
    show_percentage = {
        en = "Show Percentage",
    },
    show_percentage_description = {
        en = "Display current mission progress percentage.",
    },
    
    -- ############################################
    -- Markers Group
    -- ############################################
    group_markers = {
        en = "Markers",
    },
    show_progress_bar = {
        en = "Show Progress Bar",
    },
    show_progress_bar_description = {
        en = "Display the mission progress bar.",
    },
    show_medicae_markers = {
        en = "Show Medicae Markers",
    },
    show_medicae_markers_description = {
        en = "Show medicae station positions and charge counts.",
    },
    show_beacon_markers = {
        en = "Show Respawn Beacons",
    },
    show_beacon_markers_description = {
        en = "Show respawn beacon positions along the progress bar.",
    },
    show_grimoire_markers = {
        en = "Show Grimoires",
    },
    show_grimoire_markers_description = {
        en = "Show grimoire pickup positions along the progress bar.",
    },
    show_scripture_markers = {
        en = "Show Scriptures",
    },
    show_scripture_markers_description = {
        en = "Show scripture (tome) pickup positions along the progress bar.",
    },
    
    -- ############################################
    -- Theme Presets
    -- ############################################
    theme_preset = {
        en = "Theme",
    },
    theme_preset_description = {
        en = "Select a visual theme. Choose 'Custom' to unlock individual color and dimension settings.",
    },
    preset_default = {
        en = "Default",
    },
    preset_minimal = {
        en = "Minimal",
    },
    preset_neon_cyber = {
        en = "Neon Cyber",
    },
    preset_imperium = {
        en = "Imperium",
    },
    preset_mechanicus = {
        en = "Mechanicus",
    },
    preset_inquisition = {
        en = "Inquisition",
    },
    preset_chaos = {
        en = "Chaos",
    },
    preset_veteran = {
        en = "Veteran",
    },
    preset_zealot = {
        en = "Zealot",
    },
    preset_ogryn = {
        en = "Ogryn",
    },
    preset_psyker = {
        en = "Psyker",
    },
    preset_stealth = {
        en = "Stealth",
    },
    preset_hive_world = {
        en = "Hive World",
    },
    preset_void_born = {
        en = "Void Born",
    },
    preset_death_guard = {
        en = "Death Guard",
    },
    preset_custom = {
        en = "Custom",
    },
    
    -- ############################################
    -- Dimensions Group (Custom only)
    -- ############################################
    group_dimensions = {
        en = "Dimensions (Custom Theme)",
    },
    custom_bar_width = {
        en = "Bar Width",
    },
    custom_bar_width_description = {
        en = "Width of the progress bar in pixels. Requires reload.",
    },
    custom_bar_height = {
        en = "Bar Height",
    },
    custom_bar_height_description = {
        en = "Height of the progress bar in pixels. Requires reload.",
    },
    custom_screen_edge = {
        en = "Screen Edge",
    },
    custom_screen_edge_description = {
        en = "Which edge of the screen to place the bar. Requires reload.",
    },
    screen_edge_right = {
        en = "Right",
    },
    screen_edge_left = {
        en = "Left",
    },
    custom_edge_offset = {
        en = "Edge Offset",
    },
    custom_edge_offset_description = {
        en = "Distance from the screen edge in pixels. Requires reload.",
    },
    custom_vertical_offset = {
        en = "Vertical Offset",
    },
    custom_vertical_offset_description = {
        en = "Vertical offset from center. Positive = down. Requires reload.",
    },
    
    -- ############################################
    -- Colors Group (Custom only)
    -- ############################################
    group_colors = {
        en = "Colors (Custom Theme)",
    },
    custom_bar_bg_r = {
        en = "Background Red",
    },
    custom_bar_bg_r_description = {
        en = "Red component of bar background (0-255).",
    },
    custom_bar_bg_g = {
        en = "Background Green",
    },
    custom_bar_bg_g_description = {
        en = "Green component of bar background (0-255).",
    },
    custom_bar_bg_b = {
        en = "Background Blue",
    },
    custom_bar_bg_b_description = {
        en = "Blue component of bar background (0-255).",
    },
    custom_bar_bg_a = {
        en = "Background Alpha",
    },
    custom_bar_bg_a_description = {
        en = "Transparency of bar background (0-255).",
    },
    custom_bar_fill_r = {
        en = "Fill Red",
    },
    custom_bar_fill_r_description = {
        en = "Red component of progress fill (0-255).",
    },
    custom_bar_fill_g = {
        en = "Fill Green",
    },
    custom_bar_fill_g_description = {
        en = "Green component of progress fill (0-255).",
    },
    custom_bar_fill_b = {
        en = "Fill Blue",
    },
    custom_bar_fill_b_description = {
        en = "Blue component of progress fill (0-255).",
    },
    custom_bar_fill_a = {
        en = "Fill Alpha",
    },
    custom_bar_fill_a_description = {
        en = "Transparency of progress fill (0-255).",
    },
    custom_bar_border_r = {
        en = "Border Red",
    },
    custom_bar_border_r_description = {
        en = "Red component of bar border (0-255).",
    },
    custom_bar_border_g = {
        en = "Border Green",
    },
    custom_bar_border_g_description = {
        en = "Green component of bar border (0-255).",
    },
    custom_bar_border_b = {
        en = "Border Blue",
    },
    custom_bar_border_b_description = {
        en = "Blue component of bar border (0-255).",
    },
    custom_bar_border_a = {
        en = "Border Alpha",
    },
    custom_bar_border_a_description = {
        en = "Transparency of bar border (0-255).",
    },
    
    -- ############################################
    -- Custom Marker Colors (Custom Theme)
    -- ############################################
    group_custom_markers = {
        en = "Marker Colors (Custom Theme)",
    },
    custom_medicae_r = {
        en = "Medicae Red",
    },
    custom_medicae_r_description = {
        en = "Red component of medicae markers (0-255).",
    },
    custom_medicae_g = {
        en = "Medicae Green",
    },
    custom_medicae_g_description = {
        en = "Green component of medicae markers (0-255).",
    },
    custom_medicae_b = {
        en = "Medicae Blue",
    },
    custom_medicae_b_description = {
        en = "Blue component of medicae markers (0-255).",
    },
    custom_beacon_r = {
        en = "Beacon Red",
    },
    custom_beacon_r_description = {
        en = "Red component of respawn beacon markers (0-255).",
    },
    custom_beacon_g = {
        en = "Beacon Green",
    },
    custom_beacon_g_description = {
        en = "Green component of respawn beacon markers (0-255).",
    },
    custom_beacon_b = {
        en = "Beacon Blue",
    },
    custom_beacon_b_description = {
        en = "Blue component of respawn beacon markers (0-255).",
    },
    custom_grimoire_r = {
        en = "Grimoire Red",
    },
    custom_grimoire_r_description = {
        en = "Red component of grimoire markers (0-255).",
    },
    custom_grimoire_g = {
        en = "Grimoire Green",
    },
    custom_grimoire_g_description = {
        en = "Green component of grimoire markers (0-255).",
    },
    custom_grimoire_b = {
        en = "Grimoire Blue",
    },
    custom_grimoire_b_description = {
        en = "Blue component of grimoire markers (0-255).",
    },
    custom_scripture_r = {
        en = "Scripture Red",
    },
    custom_scripture_r_description = {
        en = "Red component of scripture markers (0-255).",
    },
    custom_scripture_g = {
        en = "Scripture Green",
    },
    custom_scripture_g_description = {
        en = "Green component of scripture markers (0-255).",
    },
    custom_scripture_b = {
        en = "Scripture Blue",
    },
    custom_scripture_b_description = {
        en = "Blue component of scripture markers (0-255).",
    },
    
    -- ############################################
    -- Marker Color Overrides
    -- ############################################
    group_marker_colors = {
        en = "Marker Colors",
    },
    override_marker_colors = {
        en = "Override Marker Colors",
    },
    override_marker_colors_description = {
        en = "Enable to override marker colors for any theme. When disabled, uses theme defaults.",
    },
    grimoire_color_r = {
        en = "Grimoire Red",
    },
    grimoire_color_r_description = {
        en = "Red component of grimoire markers (0-255).",
    },
    grimoire_color_g = {
        en = "Grimoire Green",
    },
    grimoire_color_g_description = {
        en = "Green component of grimoire markers (0-255).",
    },
    grimoire_color_b = {
        en = "Grimoire Blue",
    },
    grimoire_color_b_description = {
        en = "Blue component of grimoire markers (0-255).",
    },
    scripture_color_r = {
        en = "Scripture Red",
    },
    scripture_color_r_description = {
        en = "Red component of scripture markers (0-255).",
    },
    scripture_color_g = {
        en = "Scripture Green",
    },
    scripture_color_g_description = {
        en = "Green component of scripture markers (0-255).",
    },
    scripture_color_b = {
        en = "Scripture Blue",
    },
    scripture_color_b_description = {
        en = "Blue component of scripture markers (0-255).",
    },
    beacon_color_r = {
        en = "Beacon Red",
    },
    beacon_color_r_description = {
        en = "Red component of respawn beacon markers (0-255).",
    },
    beacon_color_g = {
        en = "Beacon Green",
    },
    beacon_color_g_description = {
        en = "Green component of respawn beacon markers (0-255).",
    },
    beacon_color_b = {
        en = "Beacon Blue",
    },
    beacon_color_b_description = {
        en = "Blue component of respawn beacon markers (0-255).",
    },
    medicae_color_r = {
        en = "Medicae Red",
    },
    medicae_color_r_description = {
        en = "Red component of medicae markers (0-255).",
    },
    medicae_color_g = {
        en = "Medicae Green",
    },
    medicae_color_g_description = {
        en = "Green component of medicae markers (0-255).",
    },
    medicae_color_b = {
        en = "Medicae Blue",
    },
    medicae_color_b_description = {
        en = "Blue component of medicae markers (0-255).",
    },
    
    -- ############################################
    -- Keybind
    -- ############################################
    toggle_visibility_key = {
        en = "Toggle Visibility",
    },
    toggle_visibility_key_description = {
        en = "Keybind to toggle the progress bar visibility.",
    },
}
