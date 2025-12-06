local mod = get_mod("minimap")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptUnit = require("scripts/foundation/utilities/script_unit")

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
                drop_shadow = true,
                font_type = "proxima_nova_bold",
                font_size = 18,
                text_color = Color.ui_hud_green_light(255, true),
                default_text_color = Color.black(255, true),
                size = settings.icon_size
            },
            visibility_function = function(content)
                return not content.show_status_icon and not content.show_companion_icon
            end
        },
        {
            style_id = "companion_icon",
            pass_type = "texture",
            value_id = "companion_icon_texture",
            value = "content/ui/materials/icons/throwables/hud/adamant_whistle",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = settings.icon_size,
                offset = {0, 0, 0}
            },
            visibility_function = function(content)
                return not content.show_status_icon and content.show_companion_icon
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
    local companion_icon_style = widget.style.companion_icon
    local status_icon_style = widget.style.status_icon
    local status_icon_ring_style = widget.style.status_icon_ring
    icon.offset[1] = x
    icon.offset[2] = y
    companion_icon_style.offset[1] = x
    companion_icon_style.offset[2] = y
    status_icon_style.offset[1] = x
    status_icon_style.offset[2] = y
    status_icon_ring_style.offset[1] = x
    status_icon_ring_style.offset[2] = y

    local data = marker.data
    local player_slot = data:slot()
    local unit = data.player_unit
    
    -- Check if this is a companion by checking the marker template name first, then unit's breed
    local template_name = marker.template and marker.template.name
    local is_companion_marker = (template_name == "nameplate_companion" or template_name == "nameplate_companion_hub")
    
    -- Check if this is a companion by checking the unit's breed
    local is_companion = false
    local owner_player = nil
    local owner_unit = nil
    if unit then
        local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
        if unit_data_extension then
            local breed = unit_data_extension:breed()
            if breed then
                -- Check if breed has companion tag or is companion_dog
                is_companion = (breed.tags and breed.tags.companion) or (breed.name == "companion_dog")
            end
        end
        
        -- Also check marker template name as fallback
        if not is_companion and is_companion_marker then
            is_companion = true
        end
        
        -- Get owner player if this is a companion
        if is_companion then
            local player_unit_spawn_manager = Managers.state.player_unit_spawn
            if player_unit_spawn_manager then
                owner_player = player_unit_spawn_manager:owner(unit)
                if owner_player then
                    owner_unit = owner_player.player_unit
                end
            end
        end
    elseif is_companion_marker then
        -- If no unit but marker is companion type, treat as companion
        is_companion = true
    end
    
    -- Check if disabled teammates visibility is enabled (based on dropdown setting)
    local icon_style = mod.settings and mod.settings.status_icon_style or "non_glowing"
    local show_disabled_status = (icon_style ~= "hidden")
    
    -- Check if this is the local player's own dog
    local is_local_player_dog = false
    if is_companion and owner_player then
        local local_player = Managers.player:local_player(1)
        if local_player and owner_player:peer_id() == local_player:peer_id() then
            is_local_player_dog = true
        end
    end
    
    -- For companions, don't check status at all - only show status on the player, not the dog
    -- This prevents the dog icon from showing downed/disabled status
    -- For regular teammates, check their own status
    local status = nil
    if show_disabled_status and unit and not is_companion then
        -- Only check status for regular teammates, not for companions (dogs)
        status = Status.for_unit(unit)
    end
    
    -- If teammate/owner has a disabled status, show status icon with player slot color
    if status then
        local slot_color = UISettings.player_slot_colors[player_slot]
        
        -- Handle different icon styles based on dropdown setting
        if icon_style == "glowing_with_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            -- Glowing icons are pre-colored and don't tint
            status_icon_style.color = Color.white(255, true)
            
            -- Apply player slot color to status icon ring
            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_ring_style.color = slot_color
            else
                status_icon_ring_style.color = Color.ui_hud_red_light(255, true)
            end
        elseif icon_style == "glowing_no_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            -- Glowing icons are pre-colored and don't tint
            status_icon_style.color = Color.white(255, true)
        elseif icon_style == "non_glowing_with_rings" and Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]
            
            -- Apply player slot color to status icon (non-glowing icons can be tinted)
            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_style.color = slot_color
            else
                status_icon_style.color = Color.white(255, true)
            end
            
            -- Apply silver/gold color to status icon ring for non-glowing version
            status_icon_ring_style.color = Color.silver(255, true)
        elseif Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]
            
            -- Apply player slot color to status icon (non-glowing icons can be tinted)
            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_style.color = slot_color
            else
                status_icon_style.color = Color.white(255, true)
            end
        end
    else
        -- Normal state - show class icon or dog icon for companions
        widget.content.show_status_icon = false
        
        -- Check if we're in the hub (mourning star)
        local game_mode_manager = Managers.state and Managers.state.game_mode
        local is_in_hub = false
        if game_mode_manager then
            local game_mode_name = game_mode_manager:game_mode_name()
            is_in_hub = (game_mode_name == "hub" or game_mode_name == "prologue_hub")
        end
        
        if is_companion then
            -- Check visibility settings (reuse is_local_player_dog from earlier check)
            local show_own_dog = mod.settings and mod.settings.own_dog_vis ~= false
            local show_teammate_dog = mod.settings and mod.settings.teammate_dog_vis ~= false
            
            -- Only show if visibility is enabled for this type of dog
            if (is_local_player_dog and show_own_dog) or (not is_local_player_dog and show_teammate_dog) then
                -- Get dog icon style setting
                local dog_icon_style = mod.settings and mod.settings.dog_icon_style or "dog_icon"
                
                local target_slot = player_slot
                local owner_profile = nil
                if owner_player then
                    target_slot = owner_player:slot()
                    owner_profile = owner_player:profile()
                end
                
                if dog_icon_style == "class_icon" and owner_profile then
                    widget.content.show_companion_icon = false
                    local archetype_name = owner_profile.archetype and owner_profile.archetype.name
                    local string_symbol = archetype_name and UISettings.archetype_font_icon_simple[archetype_name] or "•"
                    widget.content.icon_text = string_symbol
                    
                    if is_in_hub then
                        icon.text_color = Color.ui_hud_green_light(255, true)
                    else
                        icon.text_color = UISettings.player_slot_colors[target_slot] or icon.default_text_color
                    end
                elseif dog_icon_style == "unicode_icon" then
                    widget.content.show_companion_icon = false
                    widget.content.icon_text = "\u{E051}"
                    
                    if is_in_hub then
                        icon.text_color = Color.ui_hud_green_light(255, true)
                    else
                        icon.text_color = UISettings.player_slot_colors[target_slot] or icon.default_text_color
                    end
                else
                    widget.content.show_companion_icon = true
                    widget.content.companion_icon_texture = "content/ui/materials/icons/throwables/hud/adamant_whistle"
                    
                    if is_in_hub then
                        companion_icon_style.color = Color.ui_hud_green_light(255, true)
                    else
                        local slot_color = UISettings.player_slot_colors[target_slot]
                        if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                            companion_icon_style.color = slot_color
                        else
                            companion_icon_style.color = Color.white(255, true)
                        end
                    end
                end
            else
                -- Companion visibility is disabled, don't show it
                widget.content.show_companion_icon = false
                widget.content.icon_text = ""
            end
        else
            -- Regular teammate - show class icon
            widget.content.show_companion_icon = false
            local profile = data:profile()
            local archetype_name = profile.archetype and profile.archetype.name
            local string_symbol = archetype_name and UISettings.archetype_font_icon_simple[archetype_name] or "•"
            widget.content.icon_text = string_symbol
            -- In hub, use same color for everyone. In mission, use player slot color
            if is_in_hub then
                icon.text_color = Color.ui_hud_green_light(255, true)
            else
                icon.text_color = UISettings.player_slot_colors[player_slot] or icon.default_text_color
            end
        end
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
    local icon_visible = icon.visible ~= false or widget.content.show_status_icon or widget.content.show_companion_icon
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
