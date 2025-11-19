local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture_uv",
            value_id = "icon",
            value = "content/ui/materials/hud/interactions/icons/pocketable_default",
            style_id = "icon",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 1 },
                size = {
                    settings.icon_size[1] * 1.0,
                    settings.icon_size[2] * 1.0
                },
                default_color = Color.ui_hud_green_super_light(255, true),
                color = Color.ui_hud_green_super_light(255, true)
            }
        },
        {
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/frames/mission_top",
            style_id = "ring",
            style = {
                uvs = {
                    { 0.2, 0.2 },
                    { 0.8, 0.8 }
                },
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = {
                    settings.icon_size[1] * 1.3,
                    settings.icon_size[2] * 1.3
                },
                color = Color.ui_input_color(255, true)
            }
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y)
    local icon = widget.style.icon
    icon.offset[1] = x
    icon.offset[2] = y
    local ring = widget.style.ring
    ring.offset[1] = x
    ring.offset[2] = y

    local interaction_icon = marker.data:interaction_icon()
    local is_tagged = marker.template.get_smart_tag_id(marker) ~= nil
    icon.visible = is_tagged
    ring.visible = is_tagged

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

    if marker.widget then
        if marker.widget.content and marker.widget.content.icon then
            widget.content.icon = marker.widget.content.icon
        else
            widget.content.icon = interaction_icon
        end
        
        if marker.widget.style then
            local marker_icon_style = marker.widget.style.icon
            local marker_ring_style = marker.widget.style.ring
            
            if marker_icon_style and marker_icon_style.color then
                apply_color_to_texture(icon, marker_icon_style.color)
            end
            
            if marker_ring_style and marker_ring_style.color then
                apply_color_to_texture(ring, marker_ring_style.color)
            end
        end
    else
        widget.content.icon = interaction_icon
    end
end

return template
