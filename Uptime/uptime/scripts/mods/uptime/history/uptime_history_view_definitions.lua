--[[
  Uptime History View Definitions
  
  This file defines the UI layout and widget definitions for the uptime history view,
  including scenegraph nodes, widget styles, and input legend.
--]]

local mod = get_mod("uptime")

-- ===== Required Dependencies =====
local UISoundEvents = mod:original_require("scripts/settings/ui/ui_sound_events")
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

-- Load view settings
local _view_settings = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_settings")

-- ===== Size and Layout Settings =====
-- Scrollbar dimensions
local scrollbar_width = _view_settings.scrollbar_width

-- Grid dimensions
local grid_size = _view_settings.grid_size
local grid_width = grid_size[1]
local grid_height = grid_size[2]
local grid_blur_edge_size = _view_settings.grid_blur_edge_size

-- Mask dimensions (for content scrolling)
local mask_size = {
    grid_width + grid_blur_edge_size[1] * 2,
    grid_height + grid_blur_edge_size[2] * 2
}

-- ===== Scenegraph Definition =====
-- Defines the layout and positioning of UI elements
local scenegraph_definition = {
    -- Root screen element
    screen = UIWorkspaceSettings.screen,

    -- Main background
    background = {
        vertical_alignment = "top",
        parent = "screen",
        horizontal_alignment = "left",
        size = { grid_width, grid_height },
        position = { 180, 240, 1 }
    },

    -- Background icon
    background_icon = {
        vertical_alignment = "center",
        parent = "screen",
        horizontal_alignment = "center",
        size = { 1250, 1250 },
        position = { 0, 0, 0 }
    },

    -- Grid starting point
    grid_start = {
        vertical_alignment = "top",
        parent = "background",
        horizontal_alignment = "left",
        size = { 0, 0 },
        position = { 0, 0, 0 }
    },

    -- Grid content pivot (for scrolling)
    grid_content_pivot = {
        vertical_alignment = "top",
        parent = "grid_start",
        horizontal_alignment = "left",
        size = { 0, 0 },
        position = { 0, 0, 1 }
    },

    -- Grid mask (for content clipping)
    grid_mask = {
        vertical_alignment = "center",
        parent = "background",
        horizontal_alignment = "center",
        size = mask_size,
        position = { 0, 0, 0 }
    },

    -- Grid interaction area
    grid_interaction = {
        vertical_alignment = "top",
        parent = "background",
        horizontal_alignment = "left",
        size = { grid_width + scrollbar_width * 2, mask_size[2] },
        position = { 0, 0, 0 }
    },

    -- Scrollbar
    scrollbar = {
        vertical_alignment = "center",
        parent = "background",
        horizontal_alignment = "right",
        size = { scrollbar_width, grid_height },
        position = { 50, 0, 1 }
    },

    -- Button template
    button = {
        vertical_alignment = "left",
        parent = "grid_content_pivot",
        horizontal_alignment = "top",
        size = { 500, 64 },
        position = { 0, 0, 0 }
    },

    -- Title divider
    title_divider = {
        vertical_alignment = "top",
        parent = "screen",
        horizontal_alignment = "left",
        size = { 335, 18 },
        position = { 180, 145, 1 }
    },

    -- Title text
    title_text = {
        vertical_alignment = "bottom",
        parent = "title_divider",
        horizontal_alignment = "left",
        size = { 500, 50 },
        position = { 0, -35, 1 }
    },
}

-- ===== Widget Definitions =====
-- Defines the visual elements and their properties
local widget_definitions = {
    -- Settings overlay (darkens the screen)
    settings_overlay = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                offset = { 0, 0, 0 },
                color = { 160, 0, 0, 0 },
                visible = false,
            }
        }
    }, "screen"),

    -- Main background
    background = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = { 160, 0, 0, 0 }
            }
        }
    }, "screen"),

    -- Title divider (skull decoration)
    title_divider = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/dividers/skull_rendered_left_01"
        }
    }, "title_divider"),

    -- Title text
    title_text = UIWidget.create_definition({
        {
            value_id = "text",
            style_id = "text",
            pass_type = "text",
            value = "Uptime History",
            style = table.clone(UIFontSettings.header_1)
        }
    }, "title_text"),

    -- Background icon
    background_icon = UIWidget.create_definition({
        {
            value = "content/ui/vector_textures/symbols/cog_skull_01",
            pass_type = "slug_icon",
            style = {
                offset = { 0, 0, 0 },
                color = { 80, 0, 0, 0 }
            }
        }
    }, "background_icon"),
    -- Scrollbar
    scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scrollbar"),

    -- Grid mask (for content clipping)
    grid_mask = UIWidget.create_definition({
        {
            value = "content/ui/materials/offscreen_masks/ui_overlay_offscreen_vertical_blur",
            pass_type = "texture",
            style = {
                color = { 255, 255, 255, 255 }
            }
        }
    }, "grid_mask"),

    -- Grid interaction area (for mouse input)
    grid_interaction = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot"
        }
    }, "grid_interaction"),
}

-- ===== Input Legend =====
-- Defines the buttons shown at the bottom of the screen
local legend_inputs = {
    -- Back button
    {
        input_action = "back",
        on_pressed_callback = "cb_on_back_pressed",
        display_name = "loc_settings_menu_close_menu",
        alignment = "left_alignment"
    },

    -- Reload cache button
    {
        input_action = "hotkey_item_sort",
        on_pressed_callback = "cb_reload_cache_pressed",
        display_name = "loc_scan_folder",
        alignment = "left_alignment"
    },

    -- Delete button
    {
        input_action = "hotkey_character_delete",
        on_pressed_callback = "cb_delete_pressed",
        display_name = "loc_delete_entry",
        alignment = "right_alignment",
        on_hover_sound = UISoundEvents.social_menu_block_player,
    },
}

-- ===== Final Definitions =====
local UptimeHistoryViewDefinitions = {
    legend_inputs = legend_inputs,
    widget_definitions = widget_definitions,
    scenegraph_definition = scenegraph_definition
}

return settings("UptimeHistoryViewDefinitions", UptimeHistoryViewDefinitions)