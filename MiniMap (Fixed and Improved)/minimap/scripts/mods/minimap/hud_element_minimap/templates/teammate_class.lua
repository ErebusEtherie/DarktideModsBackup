local mod = get_mod("minimap")
local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptUnit = require("scripts/foundation/utilities/script_unit")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")
local settings = mod:io_dofile("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

local Status = mod:io_dofile("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate_status")

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
            style_id = "facing_arrow",
            pass_type = "rotated_texture",
            value = "content/ui/materials/icons/circumstances/more_resistance_01",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                color = Color.ui_hud_green_light(255, true),
                offset = { 0, 0, 4 },
                size = { 18, 18 },
                pivot = { 9, 9 },
                angle = 0
            },
            visibility_function = function(content)
                return mod and mod.settings and mod.settings.teammate_facing_arrows ~= false
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

    local template_name = marker.template and marker.template.name
    local is_companion_marker = (template_name == "nameplate_companion" or template_name == "nameplate_companion_hub")

    local is_companion = false
    local owner_player = nil
    local owner_unit = nil
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
        is_companion = true
    end

    local icon_style = mod.settings and mod.settings.status_icon_style or "non_glowing"
    local show_disabled_status = (icon_style ~= "hidden")

    local is_local_player_dog = false
    if is_companion and owner_player then
        local local_player = Managers.player:local_player(1)
        if local_player and owner_player:peer_id() == local_player:peer_id() then
            is_local_player_dog = true
        end
    end

    local status = nil
    if show_disabled_status and unit and not is_companion then
        status = Status.for_unit(unit)
    end

    if status then
        local slot_color = UISettings.player_slot_colors[player_slot]

        if icon_style == "glowing_with_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            status_icon_style.color = Color.white(255, true)

            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_ring_style.color = slot_color
            else
                status_icon_ring_style.color = Color.ui_hud_red_light(255, true)
            end
        elseif icon_style == "glowing_no_rings" and Status.icons_glowing[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons_glowing[status]
            status_icon_style.color = Color.white(255, true)
        elseif icon_style == "non_glowing_with_rings" and Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]

            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_style.color = slot_color
            else
                status_icon_style.color = Color.white(255, true)
            end

            status_icon_ring_style.color = Color.silver(255, true)
        elseif Status.icons[status] then
            widget.content.show_status_icon = true
            widget.content.status_icon_texture = Status.icons[status]

            if slot_color and type(slot_color) == "table" and #slot_color >= 4 then
                status_icon_style.color = slot_color
            else
                status_icon_style.color = Color.white(255, true)
            end
        end
    else
        widget.content.show_status_icon = false

        local game_mode_manager = Managers.state and Managers.state.game_mode
        local is_in_hub = false
        if game_mode_manager then
            local game_mode_name = game_mode_manager:game_mode_name()
            is_in_hub = (game_mode_name == "hub" or game_mode_name == "prologue_hub")
        end

        if is_companion then
            local show_own_dog = mod.settings and mod.settings.own_dog_vis ~= false
            local show_teammate_dog = mod.settings and mod.settings.teammate_dog_vis ~= false

            if (is_local_player_dog and show_own_dog) or (not is_local_player_dog and show_teammate_dog) then
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
                    local string_symbol = archetype_name and UISettings.archetype_font_icon[archetype_name] or "•"
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
                widget.content.show_companion_icon = false
                widget.content.icon_text = ""
            end
        else
            widget.content.show_companion_icon = false
            local profile = data:profile()
            local archetype_name = profile.archetype and profile.archetype.name
            local string_symbol = archetype_name and UISettings.archetype_font_icon[archetype_name] or "•"
            widget.content.icon_text = string_symbol
            if is_in_hub then
                icon.text_color = Color.ui_hud_green_light(255, true)
            else
                icon.text_color = UISettings.player_slot_colors[player_slot] or icon.default_text_color
            end
        end
    end


    local distance_text_style = widget.style.distance_text
    
    local text_y_offset = 12
    if unit and ScriptUnit.has_extension(unit, "unit_data_system") and not is_companion and (mod and mod.settings and mod.settings.teammate_facing_arrows ~= false) then
        text_y_offset = 26
    end
    
    distance_text_style.offset[1] = x
    distance_text_style.offset[2] = y + (settings.icon_size[2] * 0.5) + text_y_offset

    local show_distance = nil
    if is_companion then
        show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.companions
    else
        show_distance = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.players
    end
    local only_out_of_range = mod.settings and mod.settings.distance_markers and mod.settings.distance_markers.only_out_of_range
    local icon_visible = icon.visible ~= false or widget.content.show_status_icon or widget.content.show_companion_icon
    local should_show_distance = show_distance and range and (not only_out_of_range or is_out_of_range) and icon_visible
    local show_name = false
    if is_companion then
        show_name = mod.settings and mod.settings.display_names and mod.settings.display_names.display_name_companions
    else
        show_name = mod.settings and mod.settings.display_names and mod.settings.display_names.display_name_players
    end
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
        local name = nil
        if is_companion and mod and mod.get_companion_display_name then
            name = mod.get_companion_display_name(marker)
        elseif not is_companion and mod and mod.get_player_display_name then
            name = mod.get_player_display_name(marker)
        end
        if name then
            texts[#texts+1] = name
        end
    end

    if #texts > 0 then
        widget.content.distance_text = table.concat(texts, "\n")
        distance_text_style.visible = true
    end
    local facing_arrow = widget.style.facing_arrow
    if facing_arrow then
        if unit and ScriptUnit.has_extension(unit, "unit_data_system") and not is_companion and (mod and mod.settings and mod.settings.teammate_facing_arrows ~= false) then
            local local_player = Managers.player:local_player(1)
            local camera_manager = Managers.state.camera
            local camera = local_player and camera_manager and camera_manager:camera(local_player.viewport_name)
            
            if camera then
                local cam_rot = ScriptCamera.rotation(camera)
                local cam_fwd = Quaternion.forward(cam_rot)
                local camera_yaw = math.atan2(cam_fwd.y, cam_fwd.x)
                
                local unit_rot = Unit.local_rotation(unit, 1)
                local unit_fwd = Quaternion.forward(unit_rot)
                local unit_yaw = math.atan2(unit_fwd.y, unit_fwd.x)
                
                local angle = -(unit_yaw - camera_yaw)
                facing_arrow.angle = -angle
                
                local orbit_radius = (settings.icon_size[1] * 0.5) + 6
                facing_arrow.offset[1] = x + orbit_radius * math.sin(angle)
                facing_arrow.offset[2] = y - orbit_radius * math.cos(angle)
                
                local slot_color = UISettings.player_slot_colors[player_slot] or Color.ui_hud_green_light(255, true)
                facing_arrow.color = { slot_color[1], slot_color[2], slot_color[3], slot_color[4] }
                
                if is_vertical_threshold_exceeded then
                    facing_arrow.color[1] = mod:get("distance_marker_vertical_transparency") or 40
                end
                
                facing_arrow.visible = true
            else
                facing_arrow.visible = false
            end
        else
            facing_arrow.visible = false
        end
    end
end

return template
