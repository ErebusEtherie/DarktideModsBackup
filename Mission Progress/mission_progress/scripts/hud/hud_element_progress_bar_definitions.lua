local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local mod = get_mod("mission_progress")

-- ############################################
-- Dynamic Theme Loading
-- ############################################

-- Get current theme (or default if not available yet)
local function get_theme()
    if mod.get_current_theme then
        return mod:get_current_theme()
    end
    -- Fallback defaults if theme system not loaded yet
    return {
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        orientation = "vertical",
        invert_direction = false,
        font_size = 14,
        marker_size = 8,
        bar_bg = { 200, 20, 20, 30 },
        bar_fill = { 255, 40, 100, 40 },
        bar_border = { 220, 60, 60, 60 },
        medicae_full = { 200, 40, 100, 80 },
        medicae_partial = { 200, 100, 80, 40 },
        medicae_empty = { 150, 60, 60, 60 },
        medicae_passed = { 150, 40, 40, 40 },
        tick_active = { 255, 180, 180, 180 },
        tick_passed = { 255, 80, 80, 80 },
        text_primary = { 255, 255, 255, 255 },
        text_secondary = { 180, 180, 180, 180 },
        current_marker = { 255, 255, 255, 255 },
        extraction = { 255, 255, 220, 100 },
        -- Respawn beacons (GREEN)
        beacon_active = { 220, 80, 200, 80 },
        beacon_passed = { 120, 40, 100, 40 },
        -- Grimoire (PURPLE)
        grimoire_active = { 220, 160, 60, 200 },
        grimoire_passed = { 120, 80, 30, 100 },
        -- Scripture (PURPLE - same as grimoire by default)
        scripture_active = { 220, 160, 60, 200 },
        scripture_passed = { 120, 80, 30, 100 },
    }
end

local theme = get_theme()

-- ############################################
-- Progress Bar Dimensions (from theme)
-- ############################################

local bar_width = theme.bar_width or 10
local bar_height = theme.bar_height or 300
local edge_offset = theme.edge_offset or 20
local vertical_offset = theme.vertical_offset or 50
local screen_edge = theme.screen_edge or "right"
local orientation = theme.orientation or "vertical"
local is_horizontal = orientation == "horizontal"
local font_size = theme.font_size or 14
local marker_size = theme.marker_size or 8
local max_medicae_markers = 10
local max_beacon_markers = 12
local max_grimoire_markers = 6
local max_scripture_markers = 6

-- ############################################
-- Color Palette (from theme)
-- ############################################

local colors = {
    bar_bg = theme.bar_bg or { 200, 20, 20, 30 },
    bar_fill = theme.bar_fill or { 255, 40, 100, 40 },
    bar_border = theme.bar_border or { 220, 60, 60, 60 },
    
    medicae_full = theme.medicae_full or { 255, 80, 220, 120 },
    medicae_partial = theme.medicae_partial or { 255, 220, 180, 60 },
    medicae_empty = theme.medicae_empty or { 180, 120, 120, 120 },
    medicae_passed = theme.medicae_passed or { 100, 50, 50, 50 },
    
    text_white = theme.text_primary or { 255, 255, 255, 255 },
    text_dim = theme.text_secondary or { 180, 180, 180, 180 },
    current_marker = theme.current_marker or { 255, 255, 255, 255 },
    
    extraction = theme.extraction or { 255, 255, 220, 100 },
    
    tick_active = theme.tick_active or { 255, 180, 180, 180 },
    tick_passed = theme.tick_passed or { 255, 80, 80, 80 },
    
    beacon_active = theme.beacon_active or { 220, 80, 200, 80 },
    beacon_passed = theme.beacon_passed or { 120, 40, 100, 40 },
    
    -- Grimoire colors (PURPLE)
    grimoire_active = theme.grimoire_active or { 220, 160, 60, 200 },
    grimoire_passed = theme.grimoire_passed or { 120, 80, 30, 100 },
    
    -- Scripture colors (PURPLE by default, can be customized separately)
    scripture_active = theme.scripture_active or theme.grimoire_active or { 220, 160, 60, 200 },
    scripture_passed = theme.scripture_passed or theme.grimoire_passed or { 120, 80, 30, 100 },
}

-- ############################################
-- Scenegraph Definition
-- ############################################

-- Calculate position based on screen edge and orientation
local container_h_align, container_v_align, x_position, y_position
local bar_size, container_size

if is_horizontal then
    -- Horizontal bar: top/bottom of screen
    -- screen_edge "right" = bottom, "left" = top
    container_h_align = "center"
    container_v_align = screen_edge == "left" and "top" or "bottom"
    x_position = vertical_offset  -- Use vertical_offset as horizontal offset
    y_position = screen_edge == "left" and edge_offset or -edge_offset
    bar_size = { bar_height, bar_width }  -- Swap width/height
    container_size = { bar_height + 120, 60 }
else
    -- Vertical bar: left/right of screen
    container_h_align = screen_edge == "left" and "left" or "right"
    container_v_align = "center"
    x_position = screen_edge == "left" and edge_offset or -edge_offset
    y_position = vertical_offset
    bar_size = { bar_width, bar_height }
    container_size = { 120, bar_height + 60 }
end

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    
    -- Main container - positioned based on theme
    progress_bar_container = {
        parent = "screen",
        vertical_alignment = container_v_align,
        horizontal_alignment = container_h_align,
        size = container_size,
        position = { x_position, y_position, 100 },
    },
    
    -- Progress bar background
    progress_bar = {
        parent = "progress_bar_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = bar_size,
        position = { 0, 0, 1 },
    },
    
    -- Distance text - positioned based on orientation
    distance_text = {
        parent = "progress_bar",
        vertical_alignment = is_horizontal and "center" or "top",
        horizontal_alignment = is_horizontal and "right" or "center",
        size = { 80, 20 },
        position = is_horizontal and { 70, 0, 3 } or { 0, -25, 3 },
    },
    
    -- Current position marker (arrow + percentage)
    current_position_marker = {
        parent = "progress_bar",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 60, 20 },
        position = { 0, 0, 2 },  -- z=2 to be below POI markers
    },
    
    -- Extraction marker
    extraction_marker = {
        parent = "progress_bar",
        vertical_alignment = is_horizontal and "center" or "top",
        horizontal_alignment = is_horizontal and "right" or "center",
        size = is_horizontal and { 4, bar_width + 20 } or { bar_width + 20, 4 },
        position = { 0, 2, 3 },
    },
}

-- Medicae markers - centered on bar like beacons
for i = 1, max_medicae_markers do
    scenegraph_definition["medicae_marker_" .. i] = {
        parent = "progress_bar",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 80, 16 },
        position = { 0, 0, 4 },
    }
end

-- Beacon markers - positioned on LEFT side of bar
for i = 1, max_beacon_markers do
    scenegraph_definition["beacon_marker_" .. i] = {
        parent = "progress_bar",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { bar_width, 4 },
        position = { 0, 0, 4 },
    }
end

-- Grimoire markers - centered on bar, tick only (no count box)
for i = 1, max_grimoire_markers do
    scenegraph_definition["grimoire_marker_" .. i] = {
        parent = "progress_bar",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { bar_width, 4 },
        position = { 0, 0, 5 },  -- z=5 to render above beacons (z=4)
    }
end

-- Scripture markers - same as grimoires (purple, mutually exclusive)
for i = 1, max_scripture_markers do
    scenegraph_definition["scripture_marker_" .. i] = {
        parent = "progress_bar",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { bar_width, 4 },
        position = { 0, 0, 5 },  -- z=5 same as grimoires
    }
end

-- ############################################
-- Widget Definitions
-- ############################################

local widget_definitions = {
    -- Progress bar background with borders
    progress_bar_bg = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                color = colors.bar_bg,
            },
        },
        {
            pass_type = "rect",
            style_id = "border_left",
            style = {
                color = colors.bar_border,
                size = is_horizontal and { 1, bar_width } or { 1, bar_height },
                offset = { 0, 0, 1 },
            },
        },
        {
            pass_type = "rect",
            style_id = "border_right",
            style = {
                color = colors.bar_border,
                size = is_horizontal and { 1, bar_width } or { 1, bar_height },
                offset = is_horizontal and { bar_height - 1, 0, 1 } or { bar_width - 1, 0, 1 },
            },
        },
        {
            pass_type = "rect",
            style_id = "border_top",
            style = {
                color = colors.bar_border,
                size = is_horizontal and { bar_height, 1 } or { bar_width, 1 },
                offset = { 0, 0, 1 },
            },
        },
        {
            pass_type = "rect",
            style_id = "border_bottom",
            style = {
                color = colors.bar_border,
                size = is_horizontal and { bar_height, 1 } or { bar_width, 1 },
                offset = is_horizontal and { 0, bar_width - 1, 1 } or { 0, bar_height - 1, 1 },
            },
        },
    }, "progress_bar"),
    
    -- Progress bar fill (size set dynamically based on orientation)
    progress_bar_fill = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "fill",
            style = {
                vertical_alignment = is_horizontal and "center" or "bottom",
                horizontal_alignment = is_horizontal and "left" or "center",
                color = colors.bar_fill,
                size = is_horizontal and { 0, bar_width - 2 } or { bar_width - 2, 0 },
                offset = is_horizontal and { 1, 0, 2 } or { 0, 1, 2 },
            },
        },
    }, "progress_bar"),
    
    -- Distance remaining text
    distance_text = UIWidget.create_definition({
        {
            pass_type = "text",
            style_id = "text",
            value_id = "text",
            value = "",
            style = {
                font_type = "machine_medium",
                font_size = font_size,
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = colors.text_dim,
                drop_shadow = true,
            },
        },
    }, "distance_text"),
    
    -- Current position marker with %
    current_position_marker = UIWidget.create_definition({
        -- Arrow/bar pointing at progress bar
        {
            pass_type = "rect",
            style_id = "arrow",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = colors.current_marker,
                size = is_horizontal and { 3, bar_width } or { bar_width, 3 },
                offset = { 0, 0, 2 },
            },
        },
        -- Percentage text (BELOW bar in horizontal, RIGHT of bar in vertical - opposite of medicae)
        {
            pass_type = "text",
            style_id = "text",
            value_id = "text",
            value = "0%",
            style = {
                font_type = "machine_medium",
                font_size = font_size,
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_horizontal_alignment = is_horizontal and "center" or "left",
                text_vertical_alignment = "center",
                text_color = colors.text_white,
                drop_shadow = true,
                size = { 55, font_size },
                offset = is_horizontal and { 0, (bar_width/2 + 10), 2 } or { (bar_width/2 + 30), 0, 2 },
            },
        },
    }, "current_position_marker"),
    
    -- Extraction marker
    extraction_marker = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "marker",
            style = {
                color = colors.extraction,
            },
        },
    }, "extraction_marker"),
}

-- Medicae marker widgets - tick on bar, charges box offset
-- Using center alignment like beacons for proper bar alignment
for i = 1, max_medicae_markers do
    local tick_size = is_horizontal and { 3, bar_width } or { bar_width, 3 }
    local box_offset = is_horizontal and { 0, -(bar_width/2 + 12), 5 } or { -(bar_width/2 + 12), 0, 5 }
    local text_offset = is_horizontal and { 0, -(bar_width/2 + 12), 6 } or { -(bar_width/2 + 12), 0, 6 }
    
    widget_definitions["medicae_marker_" .. i] = UIWidget.create_definition({
        -- Tick mark that crosses through the bar
        {
            pass_type = "rect",
            style_id = "tick",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = { 255, 180, 180, 180 },  -- Light gray default
                size = tick_size,
                offset = { 0, 0, 6 },
            },
        },
        -- Charge count box
        {
            pass_type = "rect",
            style_id = "marker_bg",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = { 200, 30, 30, 40 },
                size = { 14, 14 },
                offset = box_offset,
            },
        },
        -- Charge number (in the box)
        {
            pass_type = "text",
            style_id = "charges",
            value_id = "charges_text",
            value = "",
            style = {
                font_type = "machine_medium",
                font_size = 11,
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = colors.text_white,
                drop_shadow = true,
                size = { 14, 14 },
                offset = text_offset,
            },
        },
    }, "medicae_marker_" .. i)
end

-- Beacon marker widgets
for i = 1, max_beacon_markers do
    local tick_size = is_horizontal and { marker_size / 2, bar_width } or { bar_width, marker_size / 2 }
    
    widget_definitions["beacon_marker_" .. i] = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "tick",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = colors.beacon_active,
                size = tick_size,
                offset = { 0, 0, 4 },
            },
        },
    }, "beacon_marker_" .. i)
end

-- Grimoire marker widgets
for i = 1, max_grimoire_markers do
    local tick_size = is_horizontal and { marker_size / 2, bar_width } or { bar_width, marker_size / 2 }
    
    widget_definitions["grimoire_marker_" .. i] = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "tick",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = colors.grimoire_active,
                size = tick_size,
                offset = { 0, 0, 5 },
            },
        },
    }, "grimoire_marker_" .. i)
end

-- Scripture marker widgets
for i = 1, max_scripture_markers do
    local tick_size = is_horizontal and { marker_size / 2, bar_width } or { bar_width, marker_size / 2 }
    
    widget_definitions["scripture_marker_" .. i] = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "tick",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = colors.scripture_active,
                size = tick_size,
                offset = { 0, 0, 5 },
            },
        },
    }, "scripture_marker_" .. i)
end

-- ############################################
-- Return Definition Table
-- ############################################

return {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
    bar_width = bar_width,
    bar_height = bar_height,
    is_horizontal = is_horizontal,
    font_size = font_size,
    marker_size = marker_size,
    max_medicae_markers = max_medicae_markers,
    max_beacon_markers = max_beacon_markers,
    max_grimoire_markers = max_grimoire_markers,
    max_scripture_markers = max_scripture_markers,
    colors = colors,
}
