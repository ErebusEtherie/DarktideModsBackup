local mod = get_mod("minimap")

local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local definitions = require("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_definitions")

local HudElementMinimap = class("HudElementMinimap", "HudElementBase")

HudElementMinimap.init = function(self, parent, draw_layer, start_scale)
    HudElementMinimap.super.init(self, parent, draw_layer, start_scale, {
        widget_definitions = definitions.widget_definitions,
        scenegraph_definition = definitions.scenegraph_definition
    })

    self._settings = definitions.settings

    self._icon_widgets_by_name = {}
    self._icon_update_functions_by_name = {}
    local templates = definitions.icon_templates
    for name, template in pairs(templates) do
        local definition = template.create_widget_definition(self._settings, "minimap")
        self._icon_widgets_by_name[name] = UIWidget.init(name, definition)
        self._icon_update_functions_by_name[name] = template.update_function
    end

    self._registered_world_markers = false
end

HudElementMinimap._register_world_markers = function(self)
    self._registered_world_markers = true
    local cb = callback(self, "_cb_register_world_markers_list")

    Managers.event:trigger("request_world_markers_list", cb)
end

HudElementMinimap._cb_register_world_markers_list = function(self, world_markers)
    self._world_markers_list = world_markers
end

HudElementMinimap.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementMinimap.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    if not self._registered_world_markers then
        self:_register_world_markers()
    end
end

HudElementMinimap._update_background_color = function(self)
    local background_widget = self._widgets_by_name.background
    if not background_widget or not background_widget.style or not background_widget.style.circ then
        return
    end

    local settings = mod.settings or {}
    local r = settings.minimap_background_color_r or 180
    local g = settings.minimap_background_color_g or 180
    local b = settings.minimap_background_color_b or 180
    local opacity = settings.minimap_background_opacity or 64

    background_widget.style.circ.color = { opacity, r, g, b }
end

local markers_data = {}

local function is_bot_marker(marker)
    if not marker or not marker.data then
        return false
    end

    local data = marker.data
    local player = data.player

    if not player and data.player_unit then
        local pm = Managers.player
        if pm and pm.player_by_unit then
            player = pm:player_by_unit(data.player_unit)
        end
    end

    if not player then
        return false
    end

    local check_methods = {
        is_human_controlled = function(p) return not p:is_human_controlled() end,
        is_bot_player = function(p) return p:is_bot_player() end,
        is_bot = function(p) return p:is_bot() end,
    }

    for method_name, check_func in pairs(check_methods) do
        if player[method_name] then
            local ok, result = pcall(check_func, player)
            if ok and result then
                return true
            end
        end
    end

    return false
end

local function get_breed_type_from_marker(marker)
    if not marker or not marker.unit then
        return nil
    end
    
    local success, breed_type = pcall(function()
        local unit_data_extension = ScriptUnit.has_extension(marker.unit, "unit_data_system")
        if not unit_data_extension then
            return nil
        end
        
        local breed = unit_data_extension:breed()
        if not breed or not breed.tags then
            return nil
        end
        
        local tags = breed.tags
        
        if tags.monster or tags.captain or tags.cultist_captain then
            return "boss"
        elseif tags.elite then
            return "elite"
        elseif tags.special then
            return "special"
        elseif tags.horde then
            return "horde"
        elseif tags.roamer then
            return "roamer"
        else
            return "fodder"
        end
    end)
    
    return success and breed_type or nil
end

local function calculate_threat_score(marker)
    if not marker or not marker.unit then
        return 0
    end
    
    local success, threat_score = pcall(function()
        -- Get enemy type priority (higher = more dangerous)
        local unit_data_extension = ScriptUnit.has_extension(marker.unit, "unit_data_system")
        if not unit_data_extension then
            return 0
        end
        
        local breed = unit_data_extension:breed()
        if not breed or not breed.tags then
            return 0
        end
        
        local tags = breed.tags
        local breed_name = breed.name
        local breed_priority = 0
        
        -- Breed-specific priority (categories are already separated, so we only need per-breed priority)
        if tags.special then
            -- Special enemy priorities (900-100)
            if breed_name == "chaos_poxwalker_bomber" then
                breed_priority = 900  -- Pox Bomber - highest special priority
            elseif breed_name == "renegade_netgunner" then
                breed_priority = 800  -- Trapper
            elseif breed_name == "renegade_flamer" or breed_name == "cultist_flamer" then
                breed_priority = 700  -- Flamers
            elseif breed_name == "renegade_grenadier" or breed_name == "cultist_grenadier" then
                breed_priority = 700  -- Grenadiers
            elseif breed_name == "chaos_hound" then
                breed_priority = 650  -- Pox Hound
            elseif breed_name == "renegade_sniper" then
                breed_priority = 600  -- Sniper
            elseif breed_name == "cultist_mutant" then
                breed_priority = 100  -- Mutant - lowest special priority
            else
                breed_priority = 200  -- Other specials
            end
            
        elseif tags.elite then
            -- Elite enemy priorities (900-100)
            if breed_name == "chaos_ogryn_executor" then
                breed_priority = 900  -- Ogryn Executor - highest
            elseif breed_name == "renegade_executor" then
                breed_priority = 850  -- Renegade Executor
            elseif breed_name == "cultist_berzerker" or breed_name == "renegade_berzerker" then
                breed_priority = 800  -- Ragers
            elseif breed_name == "renegade_plasma_gunner" then
                breed_priority = 750  -- Plasma Gunner
            elseif breed_name == "renegade_shocktrooper" or breed_name == "cultist_shocktrooper" then
                breed_priority = 700  -- Shocktroopers
            elseif breed_name == "renegade_gunner" or breed_name == "cultist_gunner" or breed_name == "chaos_ogryn_gunner" or breed_name == "renegade_radio_operator" then
                breed_priority = 650  -- Gunners + Radio Operator
            elseif breed_name == "chaos_ogryn_bulwark" then
                breed_priority = 600  -- Bulwark
            else
                breed_priority = 100  -- Other elites
            end
            
        elseif tags.monster or tags.captain or tags.cultist_captain then
            -- Boss/Monster priorities (950-650)
            if tags.captain or tags.cultist_captain then
                -- Check for twin captains first
                if breed_name == "renegade_twin_captain" or breed_name == "renegade_twin_captain_two" then
                    breed_priority = 950  -- Twins - highest boss threat
                else
                    breed_priority = 900  -- Regular Captains
                end
            else
                -- Monsters
                if breed_name == "chaos_spawn" then
                    breed_priority = 850  -- Chaos Spawn
                elseif breed_name == "chaos_beast_of_nurgle" then
                    breed_priority = 800  -- Beast of Nurgle
                elseif breed_name == "chaos_plague_ogryn" then
                    breed_priority = 750  -- Plague Ogryn 
                elseif breed_name == "chaos_daemonhost" then
                    breed_priority = 700  -- Daemonhost
                else
                    breed_priority = 650  -- Other monsters
                end
            end
            
        elseif tags.horde then
            breed_priority = 0  -- All horde same priority
            
        elseif tags.roamer then
            -- Roamer priorities
            if breed_name == "renegade_rifleman" then
                breed_priority = 50  -- Rifleman (ranged threat)
            else
                breed_priority = 0  -- Other roamers
            end
            
        else
            -- Fodder priorities
            if tags.ritualist or breed_name == "cultist_ritualist" then
                breed_priority = 100  -- Ritualist (support enemy)
            else
                breed_priority = 0  -- Basic fodder
            end
        end
        
        -- Get health status (0-1000, higher = more wounded)
        local health_extension = ScriptUnit.has_extension(marker.unit, "health_system")
        local health_score = 0
        
        if health_extension then
            local damage_taken = health_extension:damage_taken()
            local max_health = health_extension:max_health()
            
            if max_health > 0 then
                local damage_percent = math.min(damage_taken / max_health, 1.0)
                health_score = damage_percent * 1000
            end
        end
        
        -- Combined score: Breed priority + Health status
        -- Categories are separated before sorting, so we only compare within same category
        -- Example: Bomber (900 + health) > Trapper (800 + health)
        return breed_priority + health_score
    end)
    
    return success and threat_score or 0
end

HudElementMinimap._collect_markers = function(self)
    table.clear(markers_data)

    local settings = mod.settings or {}
    local world_markers_list = self._world_markers_list
    local hide_bots = settings.hide_bots
    local enemy_radar_enabled = settings.enemy_radar_enabled
    local enemy_radar_filters = settings.enemy_radar_filters or {}
    local enemy_radar_limits = settings.enemy_radar_limits or {}
    
    local pinged_units = {}
    local companion_targeted_units = {}
    local unit_threat_vis = settings.icon_vis and settings.icon_vis.unit_threat or false
    local unit_threat_adamant_vis = settings.icon_vis and settings.icon_vis.unit_threat_adamant or false
    
    if world_markers_list then
        for i = 1, #world_markers_list do
            local marker = world_markers_list[i]
            local template = marker.template
            local template_name = template.name
            local is_ping_marker = (template_name == "location_ping" or 
                                    template_name == "location_threat" or 
                                    template_name == "unit_threat")
            local is_companion_target = (template_name == "unit_threat_adamant")
            
            if is_ping_marker and marker.unit then
                if template_name == "unit_threat" then
                    if unit_threat_vis then
                        pinged_units[marker.unit] = true
                    end
                else
                    pinged_units[marker.unit] = true
                end
            end
            
            if is_companion_target and marker.unit and unit_threat_adamant_vis then
                companion_targeted_units[marker.unit] = true
            end
        end
    end
    
    local enemy_markers_by_type = {
        elite = {},
        special = {},
        boss = {},
        horde = {},
        fodder = {},
        roamer = {},
    }
    local non_enemy_markers = {}

    if world_markers_list then
        for i = 1, #world_markers_list do
            local marker = world_markers_list[i]
            local template = marker.template
            local template_name = template.name

            local is_player_marker = (template_name == "nameplate" or
                                     template_name == "nameplate_party" or
                                     template_name == "nameplate_party_hud" or
                                     template_name == "nameplate_combat" or
                                     template_name == "nameplate_companion" or
                                     template_name == "nameplate_companion_hub" or
                                     template_name == "ringhud_teammate_tile")

            if not (hide_bots and is_player_marker and is_bot_marker(marker)) then
                local azimuth, range, vertical_distance = self:_get_marker_azimuth_range(marker)
                local marker_info = {
                    azimuth = azimuth,
                    range = range,
                    vertical_distance = vertical_distance,
                    name = template_name,
                    marker = marker,
                }
                
                local is_enemy_marker = (template_name == "color_coded_healthbar" or template_name == "custom_healthbar")
                
                if is_enemy_marker then
                    local enemy_healthbar_vis = settings.icon_vis and settings.icon_vis[template_name]
                    
                    if enemy_healthbar_vis and enemy_radar_enabled then
                        local is_pinged = marker.unit and pinged_units[marker.unit] or false
                        local is_companion_targeted = marker.unit and companion_targeted_units[marker.unit] or false
                        
                        -- Don't show enemy dot if it's pinged or companion targeted (those show their own icons)
                        if not is_pinged and not is_companion_targeted then
                            local breed_type = get_breed_type_from_marker(marker)
                            if breed_type and enemy_radar_filters[breed_type] then
                                marker_info.threat_score = calculate_threat_score(marker)
                                table.insert(enemy_markers_by_type[breed_type], marker_info)
                            end
                        end
                    end
                else
                    table.insert(non_enemy_markers, marker_info)
                end
            end
        end
    end
    
    local priority_mode = settings.enemy_radar_priority_mode or "threat"
    
    -- Backward compatibility: "damage" was renamed to "threat"
    if priority_mode == "damage" then
        priority_mode = "threat"
    end
    
    for breed_type, markers in pairs(enemy_markers_by_type) do
        local limit = enemy_radar_limits[breed_type] or 0
        if limit > 0 and #markers > 0 then
            if priority_mode == "distance" then
                table.sort(markers, function(a, b)
                    -- Calculate combined 3D distance (horizontal + vertical)
                    local horiz_a = a.range or 0
                    local horiz_b = b.range or 0
                    local vert_a = a.vertical_distance or 0
                    local vert_b = b.vertical_distance or 0
                    
                    -- Combined distance using pythagorean theorem
                    local dist_a = math.sqrt(horiz_a * horiz_a + vert_a * vert_a)
                    local dist_b = math.sqrt(horiz_b * horiz_b + vert_b * vert_b)
                    
                    return dist_a < dist_b
                end)
            else
                -- Threat mode: Enemy type priority + health status
                table.sort(markers, function(a, b)
                    local threat_a = a.threat_score or 0
                    local threat_b = b.threat_score or 0
                    if threat_a ~= threat_b then
                        return threat_a > threat_b
                    end
                    -- If threat is equal, prioritize by 3D distance
                    local horiz_a = a.range or 0
                    local horiz_b = b.range or 0
                    local vert_a = a.vertical_distance or 0
                    local vert_b = b.vertical_distance or 0
                    
                    local dist_a = math.sqrt(horiz_a * horiz_a + vert_a * vert_a)
                    local dist_b = math.sqrt(horiz_b * horiz_b + vert_b * vert_b)
                    
                    return dist_a < dist_b
                end)
            end
            
            for i = 1, math.min(limit, #markers) do
                table.insert(markers_data, markers[i])
            end
        end
    end
    
    for _, marker_info in ipairs(non_enemy_markers) do
        table.insert(markers_data, marker_info)
    end

    return markers_data
end

HudElementMinimap._get_marker_azimuth_range = function(self, marker)
    local marker_position = marker.position and marker.position:unbox()

    if marker_position then
        local camera = self._parent:player_camera()

        if not camera then
            return 0, 0, 0
        end

        local camera_position = ScriptCamera.position(camera)
        local camera_forward = Quaternion.forward(ScriptCamera.rotation(camera))
        local diff_vector = marker_position - camera_position
        local vertical_distance = math.abs(diff_vector.z)
        diff_vector.z = 0
        local azimuth = Vector3.flat_angle(camera_forward, diff_vector)
        local range = Vector3.length(diff_vector)

        return azimuth, range, vertical_distance
    end

    return 0, 0, 0
end

local function get_hfov(vfov)
    local width = RESOLUTION_LOOKUP.width
    local height = RESOLUTION_LOOKUP.height
    local aspect_ratio = width / height
    local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect_ratio)
    return hfov
end

local marker_name_to_icon = {
    location_attention = "attention",
    location_ping = "ping",
    location_threat = "threat",
    unit_threat = "threat",
    unit_threat_adamant = "companion_target", -- companion target skull
    nameplate = "player", -- in hub
    nameplate_party = "teammate", -- in mission
    nameplate_party_hud = "teammate", -- in mission HUD
    nameplate_combat = "teammate", -- in mission (combat)
    nameplate_companion = "teammate", -- companions
    nameplate_companion_hub = "player", -- companions in hub
    ringhud_teammate_tile = "teammate", -- RingHud compatibility
    objective = "objective",
    player_assistance = "none",
    interaction = "interactable",

    health_bar = "none",
    -- Health bar mods
    color_coded_healthbar = "enemy",
    custom_healthbar = "enemy",
}

local function get_icon_name_from_marker_info(marker_info)
    local settings = mod.settings or {}
    local visibility = settings.icon_vis and settings.icon_vis[marker_info.name]
    if not visibility then
        return "none"
    end

    local icon_name = marker_name_to_icon[marker_info.name] or "unknown"
    if settings.display_class_icon and (icon_name == "player" or icon_name == "teammate") then
        icon_name = icon_name .. "_class"
    end
    return icon_name
end

HudElementMinimap._draw_widget_by_marker = function(self, marker_info, ui_renderer)
    local icon_name = get_icon_name_from_marker_info(marker_info)

    if icon_name == "none" or icon_name == "unknown" then
        return
    end

    local widget = self._icon_widgets_by_name[icon_name]

    local radius = marker_info.range / self._settings.max_range * self._settings.radius
    local is_out_of_range = radius > self._settings.radius
    if is_out_of_range then
        radius = self._settings.out_of_range_radius
    end
    local x = radius * -math.sin(marker_info.azimuth)
    local y = radius * -math.cos(marker_info.azimuth)

    local update_function = self._icon_update_functions_by_name[icon_name]
    update_function(widget, marker_info.marker, x, y, marker_info.vertical_distance, marker_info.range, is_out_of_range)

    UIWidget.draw(widget, ui_renderer)
end

HudElementMinimap._draw_widgets = function(self, dt, t, input_service, ui_renderer)
    local settings = mod.settings or {}
    local show_in_hub = settings.show_in_hub
    local show_in_shooting_range = settings.show_in_shooting_range
    local show_when_dead = settings.show_when_dead

    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
    local is_in_hub = (game_mode_name == "hub")
    local is_in_shooting_range = (game_mode_name == "shooting_range")

    local is_dead = false
    local is_hogtied = false
    local local_player = Managers.player:local_player(1)
    if local_player then
        local player_unit = local_player.player_unit
        if player_unit and Unit.alive(player_unit) then
            local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
            if unit_data_extension then
                local character_state_component = unit_data_extension:read_component("character_state")
                if character_state_component then
                    is_dead = PlayerUnitStatus.is_dead(character_state_component)
                    is_hogtied = PlayerUnitStatus.is_hogtied(character_state_component)
                end
            end
        else
            is_dead = true
        end
    end

    if (is_in_hub and not show_in_hub) or
       (is_in_shooting_range and not show_in_shooting_range) or
       ((is_dead or is_hogtied) and not show_when_dead) then
        return
    end

    self:_update_background_color()

    local vfov = local_player and (Managers.state.camera:fov(local_player.viewport_name) or 1) or 1
    local hfov = get_hfov(vfov)
    local fov_indicator_style = self._widgets_by_name.fov_indicator.style
    fov_indicator_style.fov_left.angle = hfov / 2
    fov_indicator_style.fov_right.angle = -hfov / 2

    HudElementMinimap.super._draw_widgets(self, dt, t, input_service, ui_renderer)

    local enemy_radar_enabled = settings.enemy_radar_enabled
    local melee_ring_enabled = settings.enemy_radar_melee_ring_enabled
    local melee_ring_widget = self._widgets_by_name.melee_range_ring
    
    if melee_ring_widget then
    if enemy_radar_enabled and melee_ring_enabled then
            local melee_range = settings.enemy_radar_melee_range or 2.5
            local max_range = self._settings.max_range
            local minimap_radius = self._settings.radius
            local ring_radius = (melee_range / max_range) * minimap_radius
            
            if ring_radius <= minimap_radius then
                local circle_style = melee_ring_widget.style.ring_circle
                circle_style.size[1] = ring_radius * 2
                circle_style.size[2] = ring_radius * 2
                
                local ring_r = settings.enemy_radar_melee_ring_color_r or 180
                local ring_g = settings.enemy_radar_melee_ring_color_g or 180
                local ring_b = settings.enemy_radar_melee_ring_color_b or 180
                local ring_opacity = settings.enemy_radar_melee_ring_opacity or 40
                circle_style.color = { ring_opacity, ring_r, ring_g, ring_b }
                
                melee_ring_widget.alpha_multiplier = 1.0
                UIWidget.draw(melee_ring_widget, ui_renderer)
            else
                melee_ring_widget.alpha_multiplier = 0.0
        end
    else
            melee_ring_widget.alpha_multiplier = 0.0
        end
    end

    local markers_data = self:_collect_markers()
    for _, marker_info in ipairs(markers_data) do
        self:_draw_widget_by_marker(marker_info, ui_renderer)
    end
end

return HudElementMinimap
