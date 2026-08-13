local UIWidget = require("scripts/managers/ui/ui_widget")
local minimap_mod = get_mod("minimap")
local minimap_settings = minimap_mod:io_dofile("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

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
        {
            style_id = "cluster_text",
            pass_type = "text",
            value_id = "cluster_text",
            value = "DEFAULT",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                drop_shadow = true,
                font_type = "proxima_nova_bold",
                font_size = 12,
                text_color = Color.white(255, true),
                offset = { 0, 0, 3 },
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

    local settings = minimap_mod and minimap_mod.settings or {}
    local vertical_distance_enabled = settings.enemy_radar_vertical_distance_enabled
    local vertical_distance_threshold = settings.enemy_radar_vertical_distance_threshold or 2.5
    local vertical_distance_transparency = settings.enemy_radar_vertical_distance_transparency or 180

    local alpha = 255
    if vertical_distance_enabled and vertical_distance and math.abs(vertical_distance) > vertical_distance_threshold then
        alpha = vertical_distance_transparency
    end

    local marker_icon_style = marker.widget and marker.widget.style and marker.widget.style.icon
    if marker_icon_style and marker_icon_style.color then
        local color = marker_icon_style.color
        if type(color) == "table" and #color >= 3 then
            color = { color[1], color[2], color[3], alpha }
        end
        apply_color_to_texture(icon, color)
    elseif marker.unit then
        if minimap_mod and minimap_mod.get_breed_color_fallback then
            local success, breed_color = pcall(minimap_mod.get_breed_color_fallback, marker.unit)
            if success and breed_color and type(breed_color) == "table" and #breed_color >= 3 then
                local color = { alpha, breed_color[1], breed_color[2], breed_color[3] }
                apply_color_to_texture(icon, color)
            else
                if not icon.color or (type(icon.color) == "table" and icon.color[4] ~= alpha) then
                    icon.color = Color.dark_red(alpha, true)
                else
                    if type(icon.color) == "table" and #icon.color >= 4 then
                        icon.color[4] = alpha
                    end
                end
            end
        else
            if not icon.color or (type(icon.color) == "table" and icon.color[4] ~= alpha) then
                icon.color = Color.dark_red(alpha, true)
            else
                if type(icon.color) == "table" and #icon.color >= 4 then
                    icon.color[4] = alpha
                end
            end
        end
    else
        if not icon.color or (type(icon.color) == "table" and icon.color[4] ~= alpha) then
            icon.color = Color.dark_red(alpha, true)
        else
            if type(icon.color) == "table" and #icon.color >= 4 then
                icon.color[4] = alpha
            end
        end
    end

    local distance_text_style = widget.style.distance_text
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (minimap_settings.icon_size[2] * 0.5) + 8

    local distance_markers = settings.distance_markers
    local show_distance = distance_markers and distance_markers.enemies
    local only_out_of_range = distance_markers and distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false
    local should_show_distance = show_distance and range and (not only_out_of_range or is_out_of_range) and icon_visible
    local breed_type = marker.breed_type
    local only_pinged = settings.enemy_name_filters and settings.enemy_name_filters.only_pinged
    local show_name = not only_pinged and settings.enemy_name_filters and breed_type and settings.enemy_name_filters[breed_type]
    local is_clustered = marker.cluster_count and marker.cluster_count > 1
    local should_show_name = show_name and icon_visible and not is_clustered

    widget.content.distance_text = ""
    distance_text_style.visible = false

    local texts = {}

    local vertical_str = ""
    if should_show_distance then
        local distance_m = math.floor(range * 10) / 10
        local distance_str = string.format("%.1fm", distance_m)
        if vertical_str ~= "" then
            distance_str = vertical_str .. " " .. distance_str
        end
        texts[#texts+1] = distance_str
    elseif vertical_str ~= "" and icon_visible then
        texts[#texts+1] = vertical_str
    end
    if should_show_name and marker.unit then
        if minimap_mod and minimap_mod.get_enemy_display_name then
            local name = minimap_mod.get_enemy_display_name(marker.unit)
            if name then
                texts[#texts+1] = name
            end
        end
    end

    if #texts > 0 then
        widget.content.distance_text = table.concat(texts, "\n")
        distance_text_style.visible = true
        distance_text_style.text_color = Color.white(alpha, true)
    end

    local cluster_text_style = widget.style.cluster_text
    cluster_text_style.offset[1] = x

    if should_show_distance then
        cluster_text_style.offset[2] = y + (minimap_settings.icon_size[2] * 0.5) + 20
    else
        cluster_text_style.offset[2] = y + (minimap_settings.icon_size[2] * 0.5) + 8
    end

    if marker.cluster_count and marker.cluster_count > 1 then
        local show_type = true
        if settings.enemy_clustering_show_type ~= nil then
            show_type = settings.enemy_clustering_show_type
        end

        if show_type then
            local category_name = "Enemy"
            if marker.breed_type == "boss" then category_name = "Boss"
            elseif marker.breed_type == "disabler" then category_name = "Disabler"
            elseif marker.breed_type == "sniper" then category_name = "Sniper"
            elseif marker.breed_type == "shield" then category_name = "Shield"
            elseif marker.breed_type == "ranged_elite" then category_name = "Ranged Elite"
            elseif marker.breed_type == "melee_elite" then category_name = "Melee Elite"
            elseif marker.breed_type == "special" then category_name = "Special"
            elseif marker.breed_type == "horde" then category_name = "Horde"
            elseif marker.breed_type == "roamer" then category_name = "Roamer"
            end
            widget.content.cluster_text = string.format("%s x%d", category_name, marker.cluster_count)
        else
            widget.content.cluster_text = string.format("x%d", marker.cluster_count)
        end

        cluster_text_style.visible = true
        cluster_text_style.text_color = Color.white(alpha, true)
    else
        widget.content.cluster_text = ""
        cluster_text_style.visible = false
    end
end

return template
