local mod = get_mod("minimap")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local Status = require("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate_status")

local template = {}

template.create_widget_definition = function(settings, scenegraph_id)
    return UIWidget.create_definition({
        {
            style_id = "icon",
            pass_type = "text",
            value_id = "icon_text",
            value = "",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                drop_shadow = false,
                font_type = "proxima_nova_bold",
                font_size = 20,
                text_color = Color.ui_hud_green_light(255, true),
                default_text_color = Color.black(255, true),
                size = settings.icon_size
            },
            visibility_function = function(content)
                return not content.show_status_icon
            end
        },
        {
            style_id = "status_icon",
            pass_type = "texture",
            value_id = "status_icon_texture",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = {
                    settings.icon_size[1] * 0.9,
                    settings.icon_size[2] * 0.9
                },
                offset = {0, 0, 1}
            },
            visibility_function = function(content)
                return content.show_status_icon
            end
        },
        {
            style_id = "status_icon_ring",
            pass_type = "texture_uv",
            value = "content/ui/materials/hud/interactions/frames/mission_top",
            style = {
                uvs = {
                    { 0.2, 0.2 },
                    { 0.8, 0.8 }
                },
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = Color.ui_input_color(255, true),
                size = {
                    settings.icon_size[1] * 1.2,
                    settings.icon_size[2] * 1.2
                },
                offset = {0, 0, 0}
            },
            visibility_function = function(content)
                local icon_style = mod.settings and mod.settings.status_icon_style
                return content.show_status_icon and (icon_style == "glowing_with_rings" or icon_style == "non_glowing_with_rings")
            end
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
    local icon = widget.style.icon
    local status_icon_style = widget.style.status_icon
    local status_icon_ring_style = widget.style.status_icon_ring
    icon.offset[1] = x
    icon.offset[2] = y
    status_icon_style.offset[1] = x
    status_icon_style.offset[2] = y
    status_icon_ring_style.offset[1] = x
    status_icon_ring_style.offset[2] = y

    local data = marker.data
    local player_slot = data:slot()
    local unit = data.player_unit
    
    local ScriptUnit = require("scripts/foundation/utilities/script_unit")
    local template_name = marker.template and marker.template.name
    local is_companion_marker = (template_name == "nameplate_companion" or template_name == "nameplate_companion_hub")
    
    local is_companion = false
    if unit then
        local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
        if unit_data_extension then
            local breed = unit_data_extension:breed()
            if breed then
                is_companion = (breed.tags and breed.tags.companion) or (breed.name == "companion_dog")
            end
        end
        
        if not is_companion and is_companion_marker then
            is_companion = true
        end
    elseif is_companion_marker then
        is_companion = true
    end
    
    local icon_style = mod.settings and mod.settings.status_icon_style or "non_glowing"
    local show_disabled_status = (icon_style ~= "hidden")
    
    local status = nil
    if show_disabled_status and unit and not is_companion then
        status = Status.for_unit(unit)
    end
    
    if status then
        local slot_color = UISettings.player_slot_colors[player_slot]
        
        local function get_status_icon_color()
            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                return slot_color
            else
                return Color.white(255, true)
            end
        end
        
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
        
        if icon_style == "glowing_with_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            widget.content.icon_text = ""
            status_icon_style.color = Color.white(255, true)
            
            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_ring_style.color = slot_color
            else
                status_icon_ring_style.color = Color.ui_hud_red_light(255, true)
            end
        elseif icon_style == "glowing_no_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            widget.content.icon_text = ""
            status_icon_style.color = Color.white(255, true)
        elseif icon_style == "non_glowing_with_rings" and Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]
            widget.content.icon_text = ""
            local color = get_status_icon_color()
            apply_color_to_texture(status_icon_style, color)
            status_icon_ring_style.color = Color.silver(255, true)
        elseif Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]
            widget.content.icon_text = ""
            local color = get_status_icon_color()
            apply_color_to_texture(status_icon_style, color)
        end
    else
        widget.content.show_status_icon = false
        widget.content.icon_text = ""
        icon.text_color = UISettings.player_slot_colors[player_slot] or icon.default_text_color
    end
    
    local settings = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")
    local distance_text_style = widget.style.distance_text
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + 8
    
    local show_distance = nil
    if is_companion then
        show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.companions
    else
        show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.players
    end
    local only_out_of_range = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false or widget.content.show_status_icon
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
