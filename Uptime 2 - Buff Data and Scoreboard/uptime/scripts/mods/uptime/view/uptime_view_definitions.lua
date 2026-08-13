-- File: uptime/scripts/mods/uptime/view/uptime_view_definitions.lua
local mod = get_mod("uptime"); if not mod then return end

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
local background_definition = mod:io_dofile("uptime/scripts/mods/uptime/view/background_definition")
local tooltip_definition = mod:io_dofile("uptime/scripts/mods/uptime/view/tooltip_definition")
local UptimeHistoryViewSettings = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_settings")

local base_z = 100
local size = { 1000, 900 }
local max_panel_height = 1000
local row_grid_scene_graph_id = "uptime_rows_grid"
local row_scene_graph_id = "uptime_rows"
local mission_section_scene_graph_id = "mission_section"

local history_panel_x = 45
local history_panel_width = UptimeHistoryViewSettings.grid_size[1]
local history_scrollbar_width = UptimeHistoryViewSettings.scrollbar_width
local history_scrollbar_right_offset = 50
local uptime_panel_x = history_panel_x + history_panel_width + history_scrollbar_right_offset + history_scrollbar_width

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    container = {
        parent = "screen",
        vertical_alignment = "center",
        horizontal_alignment = "left",
        size = { 600, 400 },
        position = { uptime_panel_x, 0, base_z }
    },
    [mission_section_scene_graph_id] = {
        parent = "container",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { nil, 75 },
        position = { 25, 100, base_z + 1 }
    },
    [row_grid_scene_graph_id] = {
        parent = "container",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 600, 400 },
        position = { 25, 175, base_z + 1 }
    },
    [row_scene_graph_id] = {
        parent = row_grid_scene_graph_id,
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 0, 0 },
        position = { 0, 0, 0 }
    },
    scoreboard_grid_base = {
        parent = "container",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 250, 400 },
        position = { 0, 175, base_z + 1 }
    },
    scoreboard_grid_content = {
        parent = "scoreboard_grid_base",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 250, 400 },
        position = { 0, 0, 0 }
    },
    scoreboard_scrollbar = {
        parent = "scoreboard_grid_base",
        vertical_alignment = "center",
        horizontal_alignment = "right",
        size = { 10, 400 },
        position = { 25, 0, base_z + 2 }
    },
    scrollbar = {
        parent = row_grid_scene_graph_id,
        vertical_alignment = "center",
        horizontal_alignment = "right",
        size = { 10, 400 },
        position = { 25, 0, base_z + 2 }
    },
    tooltip = tooltip_definition.scene
}

local widget_definitions = {
    background = background_definition(size[1], size[2], base_z),
    scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scrollbar"),
    scoreboard_scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scoreboard_scrollbar"),
    tooltip = tooltip_definition.widget_definition
}

local legend_inputs = {
    {
        input_action = "hotkey_menu_special_1",
        on_pressed_callback = "cb_on_save_pressed",
        display_name = "loc_uptime_save",
        alignment = "left_alignment"
    },
}

local UptimeViewDefinitions = {
    legend_inputs = legend_inputs,
    widget_definitions = widget_definitions,
    scenegraph_definition = scenegraph_definition,
    max_panel_height = max_panel_height,
    row_grid_scene_graph_id = row_grid_scene_graph_id,
    row_scene_graph_id = row_scene_graph_id,
    mission_section_scene_graph_id = mission_section_scene_graph_id,
}

return settings("UptimeViewDefinitions", UptimeViewDefinitions)
