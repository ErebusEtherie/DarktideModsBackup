local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local settings = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    minimap = {
        parent = "screen",
        vertical_alignment = "bottom",
        horizontal_alignment = "center",
        size = settings.size,
        position = settings.position,
    },
}

local widget_definitions = {
    background = UIWidget.create_definition({
        {
            pass_type = "circle",
            style_id = "circ",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, -1 },
                size = {
                    settings.radius * 2,
                    settings.radius * 2
                },
                color = Color.ui_grey_light(64, true)
            }
        },
        {
            pass_type = "circle",
            style_id = "center_dot",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = { 4, 4 },
                color = { 20, 30, 20, 100 }
            }
        },
    }, "minimap"),
    melee_range_ring = UIWidget.create_definition({
        {
            pass_type = "circle",
            style_id = "ring_circle",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 1 },
                size = { 0, 0 },
                color = Color.ui_grey_light(40, true),
            }
        },
    }, "minimap"),
    fov_indicator = UIWidget.create_definition({
        {
            value = "content/ui/materials/dividers/divider_line_01",
            pass_type = "rotated_texture",
            style_id = "fov_left",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, -settings.radius / 2, -1 },
                size = { 2, settings.radius },
                pivot = {
                    1,
                    settings.radius
                },
                angle = math.pi / 6,
                color = Color.ui_grey_light(64, true)
            }
        },
        {
            value = "content/ui/materials/dividers/divider_line_01",
            pass_type = "rotated_texture",
            style_id = "fov_right",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, -settings.radius / 2, -1 },
                size = { 2, settings.radius },
                pivot = {
                    1,
                    settings.radius
                },
                angle = -math.pi / 6,
                color = Color.ui_grey_light(64, true)
            }
        }
    }, "minimap"),
}

local icon_templates = {
    assistance = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/assistance"),
    attention = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/attention"),
    companion_target = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/companion_target"),
    enemy = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/enemy"),
    interactable = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/interactable"),
    objective = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/objective"),
    ping = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/ping"),
    player = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/player"),
    player_class = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/player_class"),
    teammate = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate"),
    teammate_class = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate_class"),
    threat = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/threat"),
    unknown = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/unknown"),
}

return {
    widget_definitions = widget_definitions,
    scenegraph_definition = scenegraph_definition,
    icon_templates = icon_templates,
    settings = settings,
}
