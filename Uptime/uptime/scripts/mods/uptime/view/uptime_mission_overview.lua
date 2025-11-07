local mod = get_mod("uptime")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Definitions = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_definitions")
local get_timeline_widget = mod:io_dofile("uptime/scripts/mods/uptime/view/timeline_widget")

function template(width)
    return {
        {
            pass_type = 'text',
            value_id = "mission_duration",
            style = {
                size = { width, 30 },
                line_spacing = 1.2,
                font_size = 26,
                drop_shadow = true,
                font_type = "machine_medium",
                text_color = Color.terminal_text_header(255, true),
            },
        }
    }
end

function get_mission_overview(uptime_view, mission, width)
    local widget_def = UIWidget.create_definition(template(width), Definitions.mission_section_scene_graph_id)
    local widget = uptime_view:_create_widget("mission_overview", widget_def)
    local mission_time = mod.ui.format_seconds(mission.time)
    local combat_time = mod.ui.format_seconds(mission.combat_time)
    local combat_percentage = string.format("%.1f", mission.combat_percentage) .. "%"
    widget.content.mission_duration = mod:localize("mission_duration", mission_time, combat_time, combat_percentage)

    local timeline = get_timeline_widget(
            uptime_view,
            uptime_view._definitions.mission_section_scene_graph_id,
            width,
            20,
            mission.combats_segments,
            mission.time)
    timeline.offset = { 0, 40 }

    return { widget, timeline }
end

return get_mission_overview