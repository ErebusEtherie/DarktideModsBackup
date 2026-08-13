-- File: uptime/scripts/mods/uptime/view/timeline_widget.lua
local mod = get_mod("uptime"); if not mod then return end
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

function get_widget(uptime_view, scene_graph_id, width, height, segments, mission_length)
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    mission_length = tonumber(mission_length) or 0
    segments = segments or {}

    local frame_padding_x = 24
    local frame_padding_y = 15
    local frame_width = width + frame_padding_x * 2
    local frame_height = height + frame_padding_y * 2
    local frame_offset = {
        -frame_padding_x + 12,
        -frame_padding_y,
        3,
    }

    local template = {
        {
            pass_type = "texture",
            style_id = "timeline_frame_back",
            value = "content/ui/materials/bars/heavy/frame_back",
            style = {
                size = {
                    frame_width,
                    frame_height,
                },
                offset = frame_offset,
                color = Color.white(255, true),
            },
        },
        {
            pass_type = "rect",
            style_id = "timeline_background",
            style = {
                color = Color.black(255, true),
                size = {
                    width,
                    height,
                },
                offset = {
                    12,
                    0,
                    6,
                },
            },
        },
    }

    if mission_length > 0 then
        for _, segment in pairs(segments) do
            local segment_start = tonumber(segment and segment.start_time) or 0
            local segment_end = tonumber(segment and segment.end_time) or segment_start

            -- Some files have combat segments past the mission end. Root cause unknown.
            local start = math.min(segment_start, mission_length)
            local endtime = math.min(segment_end, mission_length)
            local duration = math.max(endtime - start, 0)
            local segment_width = (duration / mission_length) * width
            local offset = (start / mission_length) * width

            if segment_width > 0 then
                template[#template + 1] = {
                    pass_type = "rect",
                    style = {
                        size = {
                            segment_width,
                            height,
                        },
                        offset = {
                            offset + 12,
                            0,
                            7,
                        },
                        color = {
                            255,
                            255,
                            83,
                            44,
                        },
                    },
                }
            end
        end
    end

    template[#template + 1] = {
        pass_type = "texture",
        style_id = "timeline_frame_top",
        value = "content/ui/materials/bars/heavy/frame_top",
        style = {
            size = {
                frame_width,
                frame_height,
            },
            offset = {
                -frame_padding_x + 12,
                -frame_padding_y,
                4,
            },
            color = Color.white(255, true),
        },
    }

    local widget_def = UIWidget.create_definition(template, scene_graph_id)
    local widget = uptime_view:_create_widget("mission_timeline", widget_def)

    return widget
end

return get_widget
