local mod = get_mod("minimap")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptUnit = require("scripts/foundation/utilities/script_unit")

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
                default_text_color = Color.ui_hud_green_light(255, true),
                size = settings.icon_size
            },
            visibility_function = function(content)
                return not content.show_companion_icon
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
                return content.show_companion_icon
            end
        },
    }, scenegraph_id)
end

template.update_function = function(widget, marker, x, y)
    local icon = widget.style.icon
    local companion_icon_style = widget.style.companion_icon
    icon.offset[1] = x
    icon.offset[2] = y
    companion_icon_style.offset[1] = x
    companion_icon_style.offset[2] = y

    local data = marker.data
    local player_slot = data:slot()
    local unit = data.player_unit
    
    -- Check if this is a companion by checking the marker template name first, then unit's breed
    local template_name = marker.template and marker.template.name
    local is_companion_marker = (template_name == "nameplate_companion" or template_name == "nameplate_companion_hub")
    
    -- Check if this is a companion by checking the unit's breed
    local is_companion = false
    local owner_player = nil
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
            end
        end
    elseif is_companion_marker then
        -- If no unit but marker is companion type, treat as companion
        is_companion = true
    end
    
    -- Check if we're in the hub (mourning star)
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local is_in_hub = false
    if game_mode_manager then
        local game_mode_name = game_mode_manager:game_mode_name()
        is_in_hub = (game_mode_name == "hub" or game_mode_name == "prologue_hub")
    end
    
    if is_companion then
        -- Check if this is the local player's own dog
        local is_local_player_dog = false
        if owner_player then
            local local_player = Managers.player:local_player(1)
            if local_player and owner_player:peer_id() == local_player:peer_id() then
                is_local_player_dog = true
            end
        end

        -- Check visibility settings
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
        -- Regular player - show class icon
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

return template
