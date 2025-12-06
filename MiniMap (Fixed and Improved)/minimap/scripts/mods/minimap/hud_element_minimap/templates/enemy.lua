local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/icons/default",
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
                color = Color.dark_red(255, true)
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

    -- Get vertical distance transparency settings
    local minimap_mod = get_mod("minimap")
    local vertical_distance_enabled = minimap_mod and minimap_mod.settings and minimap_mod.settings.enemy_radar_vertical_distance_enabled
    local vertical_distance_threshold = minimap_mod and minimap_mod.settings and minimap_mod.settings.enemy_radar_vertical_distance_threshold or 3.0
    local vertical_distance_transparency = minimap_mod and minimap_mod.settings and minimap_mod.settings.enemy_radar_vertical_distance_transparency or 40
    
    -- Calculate alpha based on vertical distance
    local alpha = 255
    if vertical_distance_enabled and vertical_distance and vertical_distance > vertical_distance_threshold then
        alpha = vertical_distance_transparency
    end

    local marker_icon_style = marker.widget and marker.widget.style and marker.widget.style.icon
    if marker_icon_style and marker_icon_style.color then
        local color = marker_icon_style.color
        if type(color) == "table" and #color >= 3 then
            -- Preserve RGB, update alpha
            color = { color[1], color[2], color[3], alpha }
        end
        apply_color_to_texture(icon, color)
        return
    end
    
    if marker.unit then
        -- Use minimap's custom colors (user-configurable)
        if minimap_mod and minimap_mod.get_breed_color_fallback then
            local success, breed_color = pcall(minimap_mod.get_breed_color_fallback, marker.unit)
            if success and breed_color and type(breed_color) == "table" and #breed_color >= 3 then
                local color = { alpha, breed_color[1], breed_color[2], breed_color[3] }
                apply_color_to_texture(icon, color)
                return
            end
        end
    end
    
    -- Default color with transparency
    if not icon.color or (type(icon.color) == "table" and icon.color[4] ~= alpha) then
        icon.color = Color.dark_red(alpha, true)
    else
        -- Update alpha of existing color
        if type(icon.color) == "table" and #icon.color >= 4 then
            icon.color[4] = alpha
        end
    end
    
    local settings = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")
    local distance_text_style = widget.style.distance_text
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + 8
    
    local show_distance = minimap_mod and minimap_mod.settings and minimap_mod.settings.distance_markers and minimap_mod.settings.distance_markers.enemies
    local only_out_of_range = minimap_mod and minimap_mod.settings and minimap_mod.settings.distance_markers and minimap_mod.settings.distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false
    local should_show = show_distance and range and (not only_out_of_range or is_out_of_range) and icon_visible
    
    if should_show then
        local distance_m = math.floor(range * 10) / 10
        widget.content.distance_text = string.format("%.1fm", distance_m)
        distance_text_style.visible = true
        distance_text_style.text_color = Color.white(alpha, true)
    else
        widget.content.distance_text = ""
        distance_text_style.visible = false
    end
end

return template
