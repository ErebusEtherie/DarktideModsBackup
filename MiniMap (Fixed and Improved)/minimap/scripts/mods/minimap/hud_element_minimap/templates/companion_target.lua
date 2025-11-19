local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/icons/enemy_priority",
            style_id = "icon",
            style = {
                uvs = {
                    { 0.1, 0.1 },
                    { 0.9, 0.9 }
                },
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = settings.icon_size,
                color = Color.ui_hud_green_light(255, true)
            }
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y, vertical_distance)
    local icon = widget.style.icon
    icon.offset[1] = x
    icon.offset[2] = y
    
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
    local color_to_apply = marker_icon_style and marker_icon_style.color or nil
    
    if not color_to_apply then
        local data = marker.data
        local player = data and data.player
        local tagger_player = nil
        if data and data.tag_instance and data.tag_instance.tagger_player then
            local success, result = pcall(function() return data.tag_instance:tagger_player() end)
            if success then
                tagger_player = result
            end
        end
        local player_slot = (tagger_player or player) and (tagger_player or player):slot() or 1
        color_to_apply = UISettings.player_slot_colors[player_slot] or Color.ui_hud_green_light(255, true)
    end
    
    apply_color_to_texture(icon, color_to_apply)
end

return template
