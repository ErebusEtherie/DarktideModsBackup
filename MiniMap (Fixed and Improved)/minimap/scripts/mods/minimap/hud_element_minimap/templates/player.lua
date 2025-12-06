local UIWidget = require("scripts/managers/ui/ui_widget")
local mod = get_mod("minimap")

local template = {}
local settings = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            style_id = "icon",
            pass_type = "text",
            value_id = "icon_text",
            value = "",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                drop_shadow = false,
                font_type = "proxima_nova_bold",
                font_size = 20,
                text_color = Color.ui_hud_green_light(255, true),
                default_text_color = Color.ui_hud_green_light(255, true),
                size = settings.icon_size
            }
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
                offset = { 0, 0, 1 },
                size = { 100, 20 }
            }
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y, vertical_distance, range, is_out_of_range)
    local icon = widget.style.icon
    local distance_text_style = widget.style.distance_text
    icon.offset[1] = x
    icon.offset[2] = y
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + 8
    
    local show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.players
    local only_out_of_range = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false
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
