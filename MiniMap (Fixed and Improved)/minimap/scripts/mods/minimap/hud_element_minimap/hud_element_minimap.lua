local mod = get_mod("minimap")

local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local MinimapStrikemapGeometry = mod:io_dofile("minimap/scripts/mods/minimap/compatibility/minimap_strikemap_geometry")

local math_sin = math.sin
local math_cos = math.cos
local math_abs = math.abs
local math_atan = math.atan
local math_tan = math.tan
local table_sort = table.sort
local table_clear = table.clear

local definitions = mod:io_dofile("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_definitions")

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
    self._next_scan_t = 0
    self._cached_markers = {}
    self._enemy_marker_pool = {}
    self._enemy_marker_pool_size = 0

    self:set_scenegraph_position("minimap", mod:get("minimap_offset_x"), mod:get("minimap_offset_y"), 0, mod:get("minimap_horizontal_alignment"), mod:get("minimap_vertical_alignment"))
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

    if player.is_human_controlled then
        return not player:is_human_controlled()
    end

    return false
end

local pinged_units = {}
local companion_targeted_units = {}
local tracked_enemy_units = {}
local broadphase_results = {}
local enemy_markers_by_type = {
    boss = {},
    disabler = {},
    sniper = {},
    shield = {},
    ranged_elite = {},
    melee_elite = {},
    special = {},
    horde = {},
    roamer = {},
}
local non_enemy_markers = {}
local enemy_template = { name = "enemy" }
local scratch_absorbed_by_this_root = {}

local _marker_info_pool = {}
local function get_marker_info(index)
    local info = _marker_info_pool[index]
    if not info then
        info = { azimuth = 0, range = 0, vertical_distance = 0, name = "", marker = nil, threat_score = 0 }
        _marker_info_pool[index] = info
    end
    return info
end

local function sort_by_distance(a, b)
    local horiz_a = a.range or 0
    local horiz_b = b.range or 0
    local vert_a = a.vertical_distance or 0
    local vert_b = b.vertical_distance or 0
    local dist_a = horiz_a * horiz_a + vert_a * vert_a
    local dist_b = horiz_b * horiz_b + vert_b * vert_b
    return dist_a < dist_b
end

local function sort_by_threat(a, b)
    local threat_a = a.threat_score or 0
    local threat_b = b.threat_score or 0
    if threat_a ~= threat_b then
        return threat_a > threat_b
    end
    local horiz_a = a.range or 0
    local horiz_b = b.range or 0
    local vert_a = a.vertical_distance or 0
    local vert_b = b.vertical_distance or 0
    local dist_a = horiz_a * horiz_a + vert_a * vert_a
    local dist_b = horiz_b * horiz_b + vert_b * vert_b
    return dist_a < dist_b
end

local function get_or_grow_pool(self, index)
    local pool = self._enemy_marker_pool
    if not pool[index] then
        pool[index] = {
            unit = false,
            pos_x = 0, pos_y = 0, pos_z = 0,
            template = enemy_template
        }
    end
    return pool[index]
end

HudElementMinimap._collect_markers = function(self)
    table_clear(markers_data)
    table_clear(pinged_units)
    table_clear(companion_targeted_units)
    table_clear(tracked_enemy_units)
    for _, list in pairs(enemy_markers_by_type) do
        table_clear(list)
    end
    table_clear(non_enemy_markers)
    local marker_info_index = 0

    local settings = mod.settings or {}
    local world_markers_list = self._world_markers_list
    local hide_bots = settings.hide_bots
    local enemy_radar_enabled = settings.enemy_radar_enabled
    local enemy_radar_filters = settings.enemy_radar_filters or {}
    local enemy_radar_limits = settings.enemy_radar_limits or {}

    local unit_threat_vis = settings.icon_vis and settings.icon_vis.unit_threat or false
    local unit_threat_adamant_vis = settings.icon_vis and settings.icon_vis.unit_threat_adamant or false

    if world_markers_list then
        for i = 1, #world_markers_list do
            local marker = world_markers_list[i]
            local template_name = marker.template.name
            local is_ping_marker = (template_name == "location_ping" or
                                    template_name == "location_threat" or
                                    template_name == "unit_threat")
            local is_companion_target = (template_name == "unit_threat_adamant" or template_name == "unit_threat_companion" or template_name == "unit_threat_veteran")

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

    if enemy_radar_enabled then
        local local_player = Managers.player:local_player(1)
        if local_player then
            local player_unit = local_player.player_unit
            if player_unit and Unit.alive(player_unit) and Unit.world(player_unit) then
                local broadphase_system = Managers.state.extension and Managers.state.extension:system("broadphase_system")
                local broadphase = broadphase_system and broadphase_system.broadphase

                if broadphase then
                    local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
                    local side = side_system and side_system.side_by_unit[player_unit]

                    if side then
                        local from_pos = Unit.world_position(player_unit, 1)
                        local enemy_side_names = side:relation_side_names("enemy")
                        local max_range = settings.enemy_radar_scan_range or 50.0

                        table_clear(broadphase_results)
                        local count = broadphase.query(broadphase, from_pos, max_range, broadphase_results, enemy_side_names)
                        local pool_index = 0

                        if count and count > 0 then
                            for i = 1, count do
                                local enemy_unit = broadphase_results[i]
                                if Unit.alive(enemy_unit) then
                                    if not pinged_units[enemy_unit] and not companion_targeted_units[enemy_unit] then
                                        local breed_type, threat_score = mod.classify_and_score_unit(enemy_unit)
                                        if breed_type and enemy_radar_filters[breed_type] then
                                            tracked_enemy_units[enemy_unit] = true

                                            pool_index = pool_index + 1
                                            local pooled = get_or_grow_pool(self, pool_index)
                                            local enemy_pos = Unit.world_position(enemy_unit, 1)
                                            pooled.unit = enemy_unit
                                            pooled.pos_x = Vector3.x(enemy_pos)
                                            pooled.pos_y = Vector3.y(enemy_pos)
                                            pooled.pos_z = Vector3.z(enemy_pos)
                                            pooled.cluster_count = 1
                                            pooled.breed_type = breed_type

                                            local azimuth, range, vertical_distance = self:_get_marker_azimuth_range(pooled)
                                            marker_info_index = marker_info_index + 1
                                            local marker_info = get_marker_info(marker_info_index)
                                            marker_info.azimuth = azimuth
                                            marker_info.range = range
                                            marker_info.vertical_distance = vertical_distance
                                            marker_info.name = "enemy"
                                            marker_info.marker = pooled
                                            marker_info.threat_score = threat_score

                                            local type_markers = enemy_markers_by_type[breed_type]
                                            type_markers[#type_markers + 1] = marker_info
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if world_markers_list then
        for i = 1, #world_markers_list do
            local marker = world_markers_list[i]
            local template_name = marker.template.name

            local is_player_marker = (template_name == "nameplate" or
                                     template_name == "nameplate_party" or
                                     template_name == "nameplate_party_hud" or
                                     template_name == "nameplate_combat" or
                                     template_name == "nameplate_companion" or
                                     template_name == "nameplate_companion_hub" or
                                     template_name == "ringhud_teammate_tile")

            if not (hide_bots and is_player_marker and is_bot_marker(marker)) then
                local is_enemy_marker = (template_name == "color_coded_healthbar" or template_name == "custom_healthbar")

                if not is_enemy_marker or not (marker.unit and tracked_enemy_units[marker.unit]) then
                    local azimuth, range, vertical_distance = self:_get_marker_azimuth_range(marker)
                    marker_info_index = marker_info_index + 1
                    local marker_info = get_marker_info(marker_info_index)
                    marker_info.azimuth = azimuth
                    marker_info.range = range
                    marker_info.vertical_distance = vertical_distance
                    marker_info.name = template_name
                    marker_info.marker = marker
                    marker_info.threat_score = 0

                    non_enemy_markers[#non_enemy_markers + 1] = marker_info
                end
            end
        end
    end

    local priority_mode = settings.enemy_radar_priority_mode or "threat"
    if priority_mode == "damage" then
        priority_mode = "threat"
    end

    local MAX_MARKERS = 100
    local current_marker_count = 0

    for _, marker_info in ipairs(non_enemy_markers) do
        if current_marker_count >= MAX_MARKERS then break end
        markers_data[#markers_data + 1] = marker_info
        current_marker_count = current_marker_count + 1
    end

    for breed_type, markers in pairs(enemy_markers_by_type) do
        if current_marker_count >= MAX_MARKERS then break end
        local limit = enemy_radar_limits[breed_type] or 0
        if limit > 0 and #markers > 0 then
            if priority_mode == "distance" then
                table_sort(markers, sort_by_distance)
            else
                table_sort(markers, sort_by_threat)
            end

            local clustered_indices = {}
            if settings.enemy_clustering_enabled then
                local cluster_radius = settings.enemy_clustering_radius or 3.0
                local cluster_threshold = settings.enemy_clustering_threshold or 3
                local cluster_radius_sq = cluster_radius * cluster_radius
                local num_markers = #markers
                for i = 1, num_markers do
                    if not clustered_indices[i] then
                        local root_marker = markers[i]
                        root_marker.marker.cluster_count = 1
                        local absorbed_by_this_root = scratch_absorbed_by_this_root
                        table_clear(absorbed_by_this_root)
                        for j = i + 1, num_markers do
                            if not clustered_indices[j] then
                                local target_marker = markers[j]
                                local dx = root_marker.marker.pos_x - target_marker.marker.pos_x
                                local dy = root_marker.marker.pos_y - target_marker.marker.pos_y
                                local dz = root_marker.marker.pos_z - target_marker.marker.pos_z
                                local dist_sq = dx*dx + dy*dy + dz*dz
                                if dist_sq <= cluster_radius_sq then
                                    clustered_indices[j] = true
                                    absorbed_by_this_root[#absorbed_by_this_root + 1] = j
                                    root_marker.marker.cluster_count = root_marker.marker.cluster_count + 1
                                    target_marker.marker.cluster_count = 0
                                end
                            end
                        end
                        if root_marker.marker.cluster_count < cluster_threshold then
                            root_marker.marker.cluster_count = 1
                            for _, j in ipairs(absorbed_by_this_root) do
                                clustered_indices[j] = nil
                                markers[j].marker.cluster_count = 1
                            end
                        end
                    end
                end
            end

            local visible_count = 0
            for i = 1, #markers do
                if visible_count >= limit then break end
                if current_marker_count >= MAX_MARKERS then break end

                if not clustered_indices[i] then
                    markers_data[#markers_data + 1] = markers[i]
                    current_marker_count = current_marker_count + 1
                    visible_count = visible_count + 1
                end
            end
        end
    end

    return markers_data
end

HudElementMinimap._get_marker_azimuth_range = function(self, marker, camera_position, camera_forward)
    if not marker then
        return 0, 0, 0
    end

    local marker_position

    if marker.position and marker.position.unbox then
        marker_position = marker.position:unbox()
    elseif marker.unit and Unit.alive(marker.unit) and Unit.world(marker.unit) then
        marker_position = Unit.world_position(marker.unit, 1)
    elseif marker.pos_x then
        marker_position = Vector3(marker.pos_x, marker.pos_y, marker.pos_z)
    end

    if marker_position then
        if not camera_position or not camera_forward then
            local camera = self._parent:player_camera()

            if not camera then
                return 0, 0, 0
            end

            camera_position = ScriptCamera.position(camera)
            camera_forward = Quaternion.forward(ScriptCamera.rotation(camera))
        end

        local diff_vector = marker_position - camera_position
        local vertical_distance = diff_vector.z
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
    local hfov = 2 * math_atan(math_tan(vfov / 2) * aspect_ratio)
    return hfov
end

local marker_name_to_icon = {
    location_attention = "attention",
    location_ping = "ping",
    location_threat = "threat",
    unit_threat = "threat",
    unit_threat_adamant = "companion_target",
    unit_threat_companion = "companion_target",
    unit_threat_veteran = "companion_target",
    nameplate = "player",
    nameplate_party = "teammate",
    nameplate_party_hud = "teammate",
    nameplate_combat = "teammate",
    nameplate_companion = "teammate",
    nameplate_companion_hub = "player",
    ringhud_teammate_tile = "teammate",
    objective = "objective",
    player_assistance = "none",
    interaction = "interactable",

    health_bar = "none",
    color_coded_healthbar = "enemy",
    custom_healthbar = "enemy",
    enemy = "enemy",
}

local function get_icon_name_from_marker_info(marker_info)
    local settings = mod.settings or {}

    if marker_info.name == "enemy" then
        if not settings.enemy_radar_enabled then
            return "none"
        end
        return "enemy"
    end

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

HudElementMinimap._draw_widget_by_marker = function(self, marker_info, ui_renderer, camera_position, camera_forward)
    local icon_name = get_icon_name_from_marker_info(marker_info)

    if icon_name == "none" or icon_name == "unknown" then
        return
    end

    local widget = self._icon_widgets_by_name[icon_name]
    local azimuth = marker_info.azimuth
    local range = marker_info.range
    local vertical_distance = marker_info.vertical_distance

    if camera_position and camera_forward then
        azimuth, range, vertical_distance = self:_get_marker_azimuth_range(
            marker_info.marker,
            camera_position,
            camera_forward
        )
    end

    local radius = range / self._settings.max_range * self._settings.radius
    local is_out_of_range = radius > self._settings.radius
    if is_out_of_range then
        radius = self._settings.out_of_range_radius
    end
    local x = radius * -math_sin(azimuth)
    local y = radius * -math_cos(azimuth)

    local update_function = self._icon_update_functions_by_name[icon_name]
    local ok = pcall(update_function, widget, marker_info.marker, x, y, vertical_distance, range, is_out_of_range)

    if ok then
        UIWidget.draw(widget, ui_renderer)
    end
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

    local camera = self._parent:player_camera()
    local camera_position = camera and ScriptCamera.position(camera) or nil
    local camera_rotation = camera and ScriptCamera.rotation(camera) or nil
    local camera_forward = camera_rotation and Quaternion.forward(camera_rotation) or nil

    local vfov = local_player and (Managers.state.camera:fov(local_player.viewport_name) or 1) or 1
    local hfov = get_hfov(vfov)
    local fov_indicator_style = self._widgets_by_name.fov_indicator.style
    fov_indicator_style.fov_left.angle = hfov / 2
    fov_indicator_style.fov_right.angle = -hfov / 2

    HudElementMinimap.super._draw_widgets(self, dt, t, input_service, ui_renderer)

    if MinimapStrikemapGeometry.is_active(t) then
        local pos = self:scenegraph_world_position("minimap_center", ui_renderer.scale)
        if pos then
            local center_x = pos[1] or 0
            local center_y = pos[2] or 0
            local snapshot = nil
            local rotation = nil
            if camera_position then
                snapshot = { player_position = camera_position }
                rotation = camera_rotation
            elseif local_player and local_player.player_unit and Unit.alive(local_player.player_unit) then
                snapshot = { player_position = Unit.world_position(local_player.player_unit, 1) }
                rotation = Unit.local_rotation(local_player.player_unit, 1)
            end

            local z = 0
            local projection_radius = self._settings.radius
            local range = self._settings.max_range
            local radar_style = "circle"

            MinimapStrikemapGeometry.draw(ui_renderer, snapshot, center_x, center_y, z, projection_radius, range, rotation, radar_style, t)
        end
    end

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

    local t_now = Managers.time and Managers.time:time("main") or 0
    if t_now >= self._next_scan_t then
        self._next_scan_t = t_now + 0.25
        self._cached_markers = self:_collect_markers()
    end

    local cached = self._cached_markers
    for i = 1, #cached do
        self:_draw_widget_by_marker(cached[i], ui_renderer, camera_position, camera_forward)
    end
end

return HudElementMinimap
