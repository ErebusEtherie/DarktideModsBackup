local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

local demolition_center_distance = 6
local demolition_marker_size = {
    12,
    6
}
local demolition_marker_style = {
    vertical_alignment = "center",
    horizontal_alignment = "center",
    angle = 0,
    offset = {
        demolition_center_distance,
        0,
        1
    },
    default_offset = {
        demolition_center_distance,
        0,
        1
    },
    size = demolition_marker_size,
    pivot = {
        demolition_marker_size[1] * 0.5 - demolition_center_distance,
        demolition_marker_size[2] * 0.5
    },
    color = Color.ui_terminal(255, true)
}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/icons/objective_main",
            style_id = "main",
            style = {
                uvs = {
                    { 0.1, 0.1 },
                    { 0.9, 0.9 }
                },
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 1 },
                size = settings.icon_size,
                color = UIHudSettings.color_tint_main_1
            }
        },
        {
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/frames/point_of_interest_top",
            style_id = "main2",
            style = {
                uvs = {
                    { 0.2, 0.2 },
                    { 0.8, 0.8 }
                },
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = settings.icon_size,
                color = UIHudSettings.color_tint_main_1
            }
        },
        {
            pass_type = "rotated_texture",
            style_id = "demo1",
            value = "content/ui/materials/hud/icons/objective_demolition/demolition_indicator_pointer",
            style = demolition_marker_style,
        },
        {
            pass_type = "rotated_texture",
            style_id = "demo2",
            value = "content/ui/materials/hud/icons/objective_demolition/demolition_indicator_pointer",
            style = demolition_marker_style,
        },
        {
            pass_type = "rotated_texture",
            style_id = "demo3",
            value = "content/ui/materials/hud/icons/objective_demolition/demolition_indicator_pointer",
            style = demolition_marker_style,
        },
        {
            style_id = "distance_text",
            pass_type = "text",
            value_id = "distance_text",
            value = "",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                drop_shadow = true,
                font_type = "proxima_nova_bold",
                font_size = 12,
                text_color = Color.white(255, true),
                offset = { 0, 0, 2 },
                size = { 100, 20 }
            }
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y, vertical_distance, range, is_out_of_range)
    local mod = get_mod("minimap")
    local main = widget.style.main
    local main2 = widget.style.main2
    main.offset[1] = x
    main.offset[2] = y
    main2.offset[1] = x
    main2.offset[2] = y

    local function apply_color_to_texture(texture_style, color)
        if texture_style and color then
            if not texture_style.color then
                texture_style.color = { 255, 255, 255, 255 }
            end
            if type(color) == "table" and #color >= 4 then
                texture_style.color[1] = color[1]
                texture_style.color[2] = color[2]
                texture_style.color[3] = color[3]
                texture_style.color[4] = color[4]
            else
                texture_style.color = color
            end
        end
    end

    local marker_icon_style = marker.widget and marker.widget.style and marker.widget.style.icon
    if marker_icon_style and marker_icon_style.color then
        apply_color_to_texture(main, marker_icon_style.color)
        apply_color_to_texture(main2, marker_icon_style.color)
    end

    local demo1 = widget.style.demo1
    local demo2 = widget.style.demo2
    local demo3 = widget.style.demo3
    local time_since_launch = Application.time_since_launch()
    local angle = time_since_launch % (math.pi * 2)
    demo1.angle = angle
    demo2.angle = angle + math.pi * 2 / 3
    demo3.angle = angle + math.pi * 4 / 3
    demo1.offset[1] = demo1.default_offset[1] + x
    demo1.offset[2] = demo1.default_offset[2] + y
    demo2.offset[1] = demo2.default_offset[1] + x
    demo2.offset[2] = demo2.default_offset[2] + y
    demo3.offset[1] = demo3.default_offset[1] + x
    demo3.offset[2] = demo3.default_offset[2] + y

    local ui_target_type = marker.data.ui_target_type or "default"
    if ui_target_type == "demolition" or ui_target_type == "corruptor" then
        main.visible = false
        main2.visible = false
        demo1.visible = true
        demo2.visible = true
        demo3.visible = true
    else
        main.visible = true
        main2.visible = true
        demo1.visible = false
        demo2.visible = false
        demo3.visible = false
    end
    
    local settings = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")
    local distance_text_style = widget.style.distance_text
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + 8
    
    local show_distance = mod and mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.objectives
    local only_out_of_range = mod and mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.only_out_of_range
    local icon_visible = (main.visible ~= false) or (main2.visible ~= false) or (demo1.visible ~= false) or (demo2.visible ~= false) or (demo3.visible ~= false)
    local should_show = show_distance and range and (not only_out_of_range or is_out_of_range) and icon_visible
    
    if should_show then
        local distance_m = math.floor(range * 10) / 10
        widget.content.distance_text = string.format("%.1fm", distance_m)
        distance_text_style.visible = true
    else
        widget.content.distance_text = ""
        distance_text_style.visible = false
    end
end

return template
