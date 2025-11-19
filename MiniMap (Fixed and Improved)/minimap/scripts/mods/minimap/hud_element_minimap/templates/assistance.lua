local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/hud/icons/player_assistance/player_assistance_icon",
            style_id = "icon",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 1, 1 },
                default_offset = { 0, 1, 1 },
                size = {
                    settings.icon_size[1] / 4,
                    settings.icon_size[2] / 2,
                },
                color = Color.ui_hud_green_super_light(255, true)
            }
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/hud/icons/player_assistance/player_assistance_frame",
            style_id = "frame",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = {
                    settings.icon_size[1],
                    settings.icon_size[2] * 0.9,
                },
                color = { 255, 236, 50, 50 }
            }
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y)
    local icon = widget.style.icon
    local frame = widget.style.frame
    icon.offset[1] = x + icon.default_offset[1]
    icon.offset[2] = y + icon.default_offset[2]
    frame.offset[1] = x
    frame.offset[2] = y

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
        apply_color_to_texture(icon, marker_icon_style.color)
    end
end

return template
