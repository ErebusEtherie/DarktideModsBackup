local mod = get_mod("uptime")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

function get_widget(uptime_view, scene_graph_id, width, height, segments, mission_length)
    local template = {
        {
            pass_type = "rect",
            style = {
                color = Color.black(120, true),
                size = { width, height }
            },
        } }

    for _, segment in pairs(segments) do
        -- some files have combat segments past the mission end. Root cause unkown
        local start = math.min(segment.start_time, mission_length)
        local endtime = math.min(segment.end_time, mission_length)

        --local start = segment.start_time
        --local endtime = segment.end_time
        local segment_width = ((endtime - start) / mission_length) * width
        local offset = (start / mission_length) * width
        template[#template + 1] = {
            pass_type = "rect",
            style = {
                size = { segment_width, height },
                offset = { offset, 0 },
                color = {
                    255,
                    255,
                    83,
                    44,
                },
            },
        }
    end

    local widget_def = UIWidget.create_definition(template, scene_graph_id)
    local widget = uptime_view:_create_widget("mission_timeline", widget_def)
    return widget
end

return get_widget