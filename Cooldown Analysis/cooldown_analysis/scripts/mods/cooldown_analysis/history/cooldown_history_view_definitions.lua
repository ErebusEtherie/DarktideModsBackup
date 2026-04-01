local mod = get_mod("cooldown_analysis")

local UIWorkspaceSettings    = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
local UIFontSettings         = mod:original_require("scripts/managers/ui/ui_font_settings")
local UIWidget               = mod:original_require("scripts/managers/ui/ui_widget")

local _s = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_settings")

local scrollbar_width = _s.scrollbar_width
local grid_size       = _s.grid_size
local grid_width      = grid_size[1]
local grid_height     = grid_size[2]
local blur_edge       = _s.grid_blur_edge_size
local mask_size       = { grid_width + blur_edge[1] * 2, grid_height + blur_edge[2] * 2 }

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,

    background = {
        vertical_alignment   = "top",
        parent               = "screen",
        horizontal_alignment = "left",
        size                 = { grid_width, grid_height },
        position             = { 180, 220, 1 },
    },

    background_icon = {
        vertical_alignment   = "center",
        parent               = "screen",
        horizontal_alignment = "center",
        size                 = { 1250, 1250 },
        position             = { 0, 0, 0 },
    },

    grid_start = {
        vertical_alignment   = "top",
        parent               = "background",
        horizontal_alignment = "left",
        size                 = { 0, 0 },
        position             = { 0, 0, 0 },
    },

    grid_content_pivot = {
        vertical_alignment   = "top",
        parent               = "grid_start",
        horizontal_alignment = "left",
        size                 = { 0, 0 },
        position             = { 0, 0, 1 },
    },

    grid_mask = {
        vertical_alignment   = "center",
        parent               = "background",
        horizontal_alignment = "center",
        size                 = mask_size,
        position             = { 0, 0, 0 },
    },

    grid_interaction = {
        vertical_alignment   = "top",
        parent               = "background",
        horizontal_alignment = "left",
        size                 = { grid_width + scrollbar_width * 2, mask_size[2] },
        position             = { 0, 0, 0 },
    },

    scrollbar = {
        vertical_alignment   = "center",
        parent               = "background",
        horizontal_alignment = "right",
        size                 = { scrollbar_width, grid_height },
        position             = { 50, 0, 1 },
    },

    title_divider = {
        vertical_alignment   = "top",
        parent               = "screen",
        horizontal_alignment = "left",
        size                 = { 335, 18 },
        position             = { 180, 130, 1 },
    },

    title_text = {
        vertical_alignment   = "bottom",
        parent               = "title_divider",
        horizontal_alignment = "left",
        size                 = { 500, 50 },
        position             = { 0, -35, 1 },
    },
}

local widget_definitions = {
    settings_overlay = UIWidget.create_definition({
        { pass_type = "rect", style = { offset = { 0, 0, 0 }, color = { 160, 0, 0, 0 }, visible = false } }
    }, "screen"),

    background = UIWidget.create_definition({
        { pass_type = "rect", style = { color = { 255, 0, 0, 0 } } }
    }, "screen"),

    title_divider = UIWidget.create_definition({
        { pass_type = "texture", value = "content/ui/materials/dividers/skull_rendered_left_01" }
    }, "title_divider"),

    title_text = UIWidget.create_definition({
        {
            value_id  = "text",
            style_id  = "text",
            pass_type = "text",
            value     = "Cooldown Analysis",
            style     = table.clone(UIFontSettings.header_1),
        }
    }, "title_text"),

    background_icon = UIWidget.create_definition({
        {
            value     = "content/ui/vector_textures/symbols/cog_skull_01",
            pass_type = "slug_icon",
            style     = { offset = { 0, 0, 0 }, color = { 80, 0, 0, 0 } },
        }
    }, "background_icon"),

    scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scrollbar"),

    grid_mask = UIWidget.create_definition({
        {
            value     = "content/ui/materials/offscreen_masks/ui_overlay_offscreen_vertical_blur",
            pass_type = "texture",
            style     = { color = { 255, 255, 255, 255 } },
        }
    }, "grid_mask"),

    grid_interaction = UIWidget.create_definition({
        { pass_type = "hotspot", content_id = "hotspot" }
    }, "grid_interaction"),
}

local legend_inputs = {
    {
        input_action        = "back",
        on_pressed_callback = "cb_on_back_pressed",
        display_name        = "loc_settings_menu_close_menu",
        alignment           = "left_alignment",
    },
    {
        input_action        = "hotkey_item_sort",
        on_pressed_callback = "cb_reload_cache_pressed",
        display_name        = "loc_scan_folder",
        alignment           = "left_alignment",
    },
    {
        input_action        = "hotkey_character_delete",
        on_pressed_callback = "cb_delete_pressed",
        display_name        = "loc_delete_entry",
        alignment           = "right_alignment",
    },
}

local CooldownHistoryViewDefinitions = {
    legend_inputs         = legend_inputs,
    widget_definitions    = widget_definitions,
    scenegraph_definition = scenegraph_definition,
}

return settings("CooldownHistoryViewDefinitions", CooldownHistoryViewDefinitions)
