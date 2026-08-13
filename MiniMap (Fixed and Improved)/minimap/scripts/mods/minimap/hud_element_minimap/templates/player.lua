local UIWidget = require("scripts/managers/ui/ui_widget")
local mod = get_mod("minimap")

local template = {}
local settings = mod:io_dofile("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

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
        {
            style_id = "vertical_arrow_overlay",
            pass_type = "text",
            value_id = "vertical_arrow_overlay",
            value = "",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                drop_shadow = true,
                font_type = "proxima_nova_bold",
                font_size = 20,
                text_color = { 255, 255, 255, 255 },
                offset = { 0, 0, 50 },
                size = { 40, 40 }
            },
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y, vertical_distance, range, is_out_of_range)
    if widget and widget.style and widget.style.vertical_arrow_overlay then
        widget.style.vertical_arrow_overlay.visible = false
    end
    local icon = widget.style.icon
    local distance_text_style = widget.style.distance_text
    icon.offset[1] = x
    icon.offset[2] = y
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + 12

    local show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.players
    local only_out_of_range = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false
    local should_show_distance = show_distance and range and (not only_out_of_range or is_out_of_range) and icon_visible
    local show_name = mod.settings and mod.settings.display_names and mod.settings.display_names.display_name_players
    local should_show_name = show_name and icon_visible

    widget.content.distance_text = ""
    distance_text_style.visible = false

    local texts = {}
    local vertical_str = ""
    if mod and mod:get("distance_marker_vertical_symbols") then
        local threshold = mod:get("distance_marker_vertical_threshold") or 2.5
        local is_vertical_threshold_exceeded = false
        if vertical_distance and vertical_distance > threshold then
            vertical_str = "↑"
            is_vertical_threshold_exceeded = true
        elseif vertical_distance and vertical_distance < -threshold then
            vertical_str = "↓"
            is_vertical_threshold_exceeded = true
        end
        if is_vertical_threshold_exceeded then
            local alpha = mod:get("distance_marker_vertical_transparency") or 180
            if widget and widget.style then
                for k, s in pairs(widget.style) do
                    if k ~= "vertical_arrow_overlay" then
                        if s and s.color and type(s.color) == "table" and #s.color >= 3 then
                            s.color = { alpha, s.color[2], s.color[3], s.color[4] }
                        end
                        if s and s.text_color and type(s.text_color) == "table" and #s.text_color >= 3 then
                            s.text_color = { alpha, s.text_color[2], s.text_color[3], s.text_color[4] }
                        end
                    end
                end
            end
        end
        local vertical_arrow_overlay_style = widget.style.vertical_arrow_overlay
        if vertical_arrow_overlay_style then
            if is_vertical_threshold_exceeded then
                widget.content.vertical_arrow_overlay = vertical_str
                vertical_arrow_overlay_style.offset[1] = x
                vertical_arrow_overlay_style.offset[2] = y
                vertical_arrow_overlay_style.offset[3] = 100
                
                local a = mod:get("distance_marker_vertical_arrow_opacity")
                if a == nil then a = 255 end
                local r = mod:get("distance_marker_vertical_arrow_color_r") or 255
                local g = mod:get("distance_marker_vertical_arrow_color_g") or 255
                local b = mod:get("distance_marker_vertical_arrow_color_b") or 255
                vertical_arrow_overlay_style.text_color = { a, r, g, b }
                vertical_arrow_overlay_style.font_size = mod:get("distance_marker_vertical_arrow_size") or 20
                
                vertical_arrow_overlay_style.visible = true
            else
                vertical_arrow_overlay_style.visible = false
            end
        end
        vertical_str = "" -- Prevent appending to distance text
    end

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
    if should_show_name then
        if mod and mod.get_player_display_name then
            local name = mod.get_player_display_name(marker)
            if name then
                texts[#texts+1] = name
            end
        end
    end

    if #texts > 0 then
        widget.content.distance_text = table.concat(texts, "\n")
        distance_text_style.visible = true
    end
end

return template
