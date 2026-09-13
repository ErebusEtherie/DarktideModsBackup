local mod = get_mod("MechanicaAutomation")

local Breed = require("scripts/utilities/breed")

local CLASS = CLASS
local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit
local PhysicsWorld = PhysicsWorld
local Raycast = Raycast
local Vector3 = Vector3
local HEALTH_ALIVE = HEALTH_ALIVE
local ALIVE = ALIVE
local POSITION_LOOKUP = POSITION_LOOKUP
local callback = callback
local unpack = unpack or table.unpack

local SERVO_ENEMY_TAG = "servo_skull_enemy_companion_target"
local BASIC_ENEMY_TAG = "enemy_over_here"
local COMPANION_ORDER = "companion_order"

local CRYPTIC_CLASS = "cryptic"
local state

local SMART_TARGETING_TEMPLATE = {
    precision_target = {
        max_range = 100,
        min_range = 1,
        smart_tagging = true,
    },
}

local TALENT_NAMES = {
    FORCE_FIELD = "cryptic_grenade_ability_force_field",
    ARC_GRENADE = "cryptic_grenade_ability_arc_grenade",
}

local TASK_TEMPLATE_HINTS = {
    hacking = true,
    hack = true,
    auspex = true,
    scan = true,
    scann = true,
    objective = true,
    data = true,
    interrog = true,
    deploy = true,
    decode = true,
    puzzle = true,
    objective_socket = true,
    servo_skull = true,
    activator = true,
}

local TASK_INTERACTION_TYPES = {
    servo_skull = true,
    servo_skull_activator = true,
    decoding = true,
    setup_decoding = true,
    default = true,
    moveable_platform = true,
    scripted_scenario = true,
    luggable_socket = true,
    door_control_panel = true,
    pocketable = true,
}

local BLOCKED_TASK_INTERACTION_TYPES = {
    forge_material = true,
    ammunition = true,
    pickup = true,
    health_station = true,
}

local BLOCKED_TASK_TEMPLATE_HINTS = {
    ammo = true,
    ammunition = true,
    diamantine = true,
    forge_material = true,
    material = true,
    medicae = true,
    pickup = true,
    plasteel = true,
}

local TRAPPER_HINTS = {
    cultist_netgunner = true,
    cultist_trapper = true,
    netgun = true,
    net_gun = true,
    renegade_netgunner = true,
    renegade_trapper = true,
    scab_netgunner = true,
    scab_trapper = true,
    net_gunner = true,
    trapper = true,
    netgunner = true,
}

local POX_BURSTER_HINTS = {
    bomb = true,
    bomber = true,
    burster = true,
    explod = true,
    poxburster = true,
    suicide = true,
}

local FIXED_AUTO_PING_PRIORITY = {
    trapper = 100000,
    boss = 4500,
    special = 4000,
    elite = 3000,
    other = 1200,
}

local NORMAL_AUTO_PING_CONE_DEGREES = 62
local TRAPPER_AUTO_PING_CONE_DEGREES = 280
local AUTO_PING_FALLBACK_RADIUS = 40
local SMART_POX_DISENGAGE_BUFFER = 1

state = {
    mod_runtime_enabled = true,
    game_mode_valid = false,
    player = nil,
    player_unit = nil,
    class_name = nil,
    has_servo_skull = false,
    player_talent_extension = nil,
    smart_targeting_extension = nil,
    smart_tag_system = nil,
    hud_element_smart_tagging = nil,
    physics_world = nil,
    visibility_raycast_world = nil,
    visibility_raycast_object = nil,
    minions = {},
    minion_order = {},
    minion_scan_index = 1,
    alert_scan_index = 1,
    visibility_cache = {},
    visibility_frame = {},
    los_node_cache = {},
    timers = {
        task = 0,
        noosphere = 0,
        auto_ping_scan = 0,
        alert = 0,
        context_refresh = 0,
    },
    last_command_t = -999,
    sticky_enemy_unit = nil,
    last_servo_enemy_unit = nil,
    return_enemy_unit = nil,
    return_enemy_until = 0,
    last_noosphere_order_t = -999,
    noosphere_order_window_t = -999,
    noosphere_order_window_count = 0,
    noosphere_candidate_unit = nil,
    noosphere_candidate_until = 0,
    pending_noosphere_unit = nil,
    pending_noosphere_until = 0,
    tag_cleanup_units = {},
    self_issued_until = 0,
    companion_burst = nil,
    task_context_unit = nil,
    task_context_template = nil,
    task_context_until = 0,
    last_alert_key = nil,
    next_recovery_t = 0,
}

local settings = {}
local safe_extension
local aiming_parameters
local is_enemy_unit
local target_ready_for_smart_tag
local is_pox_burster_breed

local LOS_NODE_NAMES = {
    "j_head",
    "j_neck",
    "j_spine2",
    "j_spine1",
    "j_spine",
}

local function owned_tag_ids(extension)
    if type(extension) ~= "table" then
        return nil
    end

    return extension._owned_tag_ids or extension.owned_tag_ids
end

local function remove_owned_tag_id(extension, tag_id)
    local owned_ids = owned_tag_ids(extension)
    if type(owned_ids) ~= "table" or tag_id == nil then
        return
    end

    local write_index = 1
    local count = #owned_ids
    for read_index = 1, count do
        local owned_id = owned_ids[read_index]
        if owned_id ~= tag_id then
            owned_ids[write_index] = owned_id
            write_index = write_index + 1
        end
    end

    for i = write_index, count do
        owned_ids[i] = nil
    end

    if owned_ids[tag_id] == true then
        owned_ids[tag_id] = nil
    end
end

local function sanitize_owned_tag_ids(smart_tag_system, extension)
    local owned_ids = owned_tag_ids(extension)
    local all_tags = smart_tag_system and smart_tag_system._all_tags
    if type(owned_ids) ~= "table" or type(all_tags) ~= "table" then
        return
    end

    local write_index = 1
    local count = #owned_ids
    for read_index = 1, count do
        local tag_id = owned_ids[read_index]
        if tag_id ~= nil and all_tags[tag_id] ~= nil then
            owned_ids[write_index] = tag_id
            write_index = write_index + 1
        end
    end

    for i = write_index, count do
        owned_ids[i] = nil
    end

    for tag_id, value in pairs(owned_ids) do
        if value == true and all_tags[tag_id] == nil then
            owned_ids[tag_id] = nil
        end
    end
end

local function forget_tag_references(smart_tag_system, tag_id, tag)
    if not smart_tag_system or tag_id == nil then
        return
    end

    local unit_extension_data = smart_tag_system._unit_extension_data
    if type(unit_extension_data) ~= "table" then
        return
    end

    if tag then
        remove_owned_tag_id(unit_extension_data[tag._tagger_unit], tag_id)
        remove_owned_tag_id(unit_extension_data[tag._target_unit], tag_id)
    end

    for _, extension in pairs(unit_extension_data) do
        remove_owned_tag_id(extension, tag_id)
    end
end

local function clear_smart_tag_entry(smart_tag_system, tag_id, tag)
    if not smart_tag_system or type(smart_tag_system._all_tags) ~= "table" or tag_id == nil then
        return false
    end

    tag = tag or smart_tag_system._all_tags[tag_id]
    forget_tag_references(smart_tag_system, tag_id, tag)
    smart_tag_system._all_tags[tag_id] = nil
    return true
end

local function clear_runtime_target_state()
    state.sticky_enemy_unit = nil
    state.last_servo_enemy_unit = nil
    state.return_enemy_unit = nil
    state.return_enemy_until = 0
    state.last_noosphere_order_t = -999
    state.noosphere_order_window_t = -999
    state.noosphere_order_window_count = 0
    state.noosphere_candidate_unit = nil
    state.noosphere_candidate_until = 0
    state.pending_noosphere_unit = nil
    state.pending_noosphere_until = 0
    state.tag_cleanup_units = {}
    state.self_issued_until = 0
    state.last_command_t = -999
    state.companion_burst = nil
    state.task_context_unit = nil
    state.task_context_template = nil
    state.task_context_until = 0
    state.alert_scan_index = 1
    state.visibility_cache = {}
    state.visibility_frame = {}
    state.los_node_cache = {}
    state.timers.task = 0
    state.timers.noosphere = 0
    state.timers.auto_ping_scan = 0
    state.timers.alert = 0
    state.timers.context_refresh = 0
end
local player_for_unit

local function setting(setting_id, default_value)
    local value = mod:get(setting_id)
    if value == nil then
        return default_value
    end
    return value
end

local function setting_number(setting_id, default_value, min_value, max_value, integer)
    local value = tonumber(setting(setting_id, default_value)) or default_value
    if min_value and value < min_value then
        value = min_value
    end
    if max_value and value > max_value then
        value = max_value
    end
    if integer then
        value = math.floor(value + 0.5)
    end
    return value
end

local function refresh_settings()
    settings.panel_language = setting("panel_language", "pt-br")
    settings.toggle_mod = setting("toggle_mod", true)
    settings.toggle_notifications = setting("toggle_notifications", true)
    settings.debug_mode = setting("debug_mode", false)
    settings.global_command_cooldown = 0.04
    settings.replace_basic_enemy_tags = true
    settings.auto_ping_enabled = setting("auto_ping_enabled", true)

    settings.auto_tasks_enabled = setting("auto_tasks_enabled", true)
    settings.task_interval = setting_number("task_interval", 0.55, 0.25, 5.00)
    settings.task_max_range = setting_number("task_max_range", 15, 5, 15)
    settings.task_prefer_crosshair = setting("task_prefer_crosshair", true)
    settings.task_use_interactor_target = setting("task_use_interactor_target", true)
    settings.task_use_scannable_units = setting("task_use_scannable_units", true)
    settings.task_require_los = setting("task_require_los", true)
    settings.task_ignore_pickups = setting("task_ignore_pickups", true)
    settings.task_context_memory = setting_number("task_context_memory", 2.50, 0.50, 5.00)
    settings.task_fast_retry_on_new_context = setting("task_fast_retry_on_new_context", true)
    settings.task_cancel_burst_on_invalid_target = setting("task_cancel_burst_on_invalid_target", true)
    settings.task_burst_attempts = setting_number("task_burst_attempts", 10, 1, 10, true)
    settings.task_burst_spacing = setting_number("task_burst_spacing", 0.08, 0.08, 0.35)
    settings.task_trigger_interaction = setting("task_trigger_interaction", false)

    settings.noosphere_enabled = setting("noosphere_enabled", true)
    settings.noosphere_interval = setting_number("noosphere_interval", 1.60, 1.50, 2.00)
    settings.noosphere_scan_interval = 0.08
    settings.noosphere_max_range = 110
    settings.noosphere_cone_degrees = NORMAL_AUTO_PING_CONE_DEGREES
    settings.noosphere_peripheral_scan = true
    settings.noosphere_peripheral_radius = 70
    settings.noosphere_sticky_manual_target = true
    settings.noosphere_release_health_percent = setting_number("noosphere_release_health_percent", 0, 0, 100)
    settings.noosphere_auto_target = setting("noosphere_auto_target", true)
    settings.noosphere_trapper_max_priority = true
    settings.noosphere_keep_until_dead = true
    settings.noosphere_skip_passive_daemonhost = setting("noosphere_skip_passive_daemonhost", true)

    settings.smart_pox_enabled = setting("smart_pox_enabled", true)
    settings.smart_pox_max_range = setting_number("smart_pox_max_range", 45, 15, 100)
    settings.smart_pox_min_distance = setting_number("smart_pox_min_distance", 10, 10, 30)
    settings.smart_pox_ally_safe_radius = setting_number("smart_pox_ally_safe_radius", 10, 10, 30)
    settings.smart_pox_require_los = setting("smart_pox_require_los", true)

    settings.alert_hud_enabled = setting("alert_hud_enabled", true)
    settings.alert_hud_range = setting_number("alert_hud_range", 45, 10, 100)
    settings.alert_hud_interval = setting_number("alert_hud_interval", 1.00, 0.35, 5.00)

    settings.enemy_scan_budget = 120
    settings.los_cache_frames = 5
    settings.physics_safe_commands = true
    settings.disable_in_hub = true
end

local TRANSLATIONS = {
    enabled = {
        en = "Mechanica Automation enabled",
        es = "Automatizacion Mechanica activada",
        ["pt-br"] = "Automacao Mechanica ativada",
    },
    disabled = {
        en = "Mechanica Automation disabled",
        es = "Automatizacion Mechanica desactivada",
        ["pt-br"] = "Automacao Mechanica desativada",
    },
}

local function tr(key)
    local lang = settings.panel_language or "pt-br"
    local row = TRANSLATIONS[key]
    return row and (row[lang] or row.en) or key
end

local function debug_print(...)
    if not settings.debug_mode then
        return
    end

    local n = select("#", ...)
    if n <= 0 then
        return
    end

    local text = tostring(select(1, ...))
    for i = 2, n do
        text = text .. " " .. tostring(select(i, ...))
    end

    mod:echo("[MechanicaAutomation] " .. text)
end

local function unit_debug_id(unit)
    if not unit then
        return "nil"
    end

    return tostring(unit)
end

local function unit_kind(unit)
    if not unit then
        return "nil"
    end

    if is_enemy_unit and is_enemy_unit(unit) then
        return "enemy"
    end

    if player_for_unit and player_for_unit(unit) then
        return "player"
    end

    return "world"
end

local function notify(key)
    if settings.toggle_notifications then
        mod:notify(tr(key))
    end
end

local function safe_call(object, method_name, ...)
    if not object then
        return nil
    end

    local method = object[method_name]
    if type(method) ~= "function" then
        return nil
    end

    local args = { ... }
    local ok, result = pcall(function()
        return method(object, unpack(args))
    end)

    if ok then
        return result
    end

    return nil
end

local function safe_field(object, field_name)
    if not object or not field_name then
        return nil
    end

    local ok, value = pcall(function()
        return object[field_name]
    end)

    if ok then
        return value
    end

    return nil
end

safe_extension = function(unit, extension_name)
    if not unit or not ScriptUnit or not ScriptUnit.has_extension then
        return nil
    end

    local ok, extension = pcall(ScriptUnit.has_extension, unit, extension_name)
    if ok then
        return extension
    end

    return nil
end

local function required_extension(unit, extension_name)
    if not unit or not ScriptUnit or not ScriptUnit.extension then
        return nil
    end

    local ok, extension = pcall(ScriptUnit.extension, unit, extension_name)
    if ok then
        return extension
    end

    return nil
end

local function unit_alive(unit)
    if not unit then
        return false
    end

    if HEALTH_ALIVE and HEALTH_ALIVE[unit] then
        return true
    end

    if ALIVE and ALIVE[unit] then
        return true
    end

    if Unit and Unit.alive then
        local ok, alive = pcall(Unit.alive, unit)
        if ok then
            return not not alive
        end
    end

    return false
end

local function unit_position(unit)
    if not unit then
        return nil
    end

    local lookup_position = POSITION_LOOKUP and POSITION_LOOKUP[unit]
    if lookup_position then
        return lookup_position
    end

    if Unit and Unit.world_position then
        local ok, position = pcall(Unit.world_position, unit, 1)
        if ok then
            return position
        end
    end

    return nil
end

local function distance_between(a, b)
    if not a or not b then
        return math.huge
    end

    return Vector3.distance(a, b)
end

local function set_physics_world(physics_world)
    if state.physics_world == physics_world then
        return
    end

    state.physics_world = physics_world
    state.visibility_raycast_world = nil
    state.visibility_raycast_object = nil
    state.visibility_cache = {}
    state.visibility_frame = {}
    state.los_node_cache = {}
end

local function ensure_visibility_raycast()
    if not state.physics_world or state.visibility_raycast_world == state.physics_world then
        return
    end

    if PhysicsWorld and PhysicsWorld.make_raycast then
        local ok, raycast_object = pcall(
            PhysicsWorld.make_raycast,
            state.physics_world,
            "closest",
            "types",
            "both",
            "collision_filter",
            "filter_interactable_line_of_sight_marker_check"
        )

        if ok and raycast_object then
            state.visibility_raycast_object = raycast_object
            state.visibility_raycast_world = state.physics_world
        end
    end
end

local function get_local_player()
    local player_manager = Managers and Managers.player
    if not player_manager then
        return nil
    end

    if player_manager.local_player_safe then
        local player = safe_call(player_manager, "local_player_safe", 1)
        if player then
            return player
        end
    end

    return nil
end

local function get_player_unit(player)
    if not player then
        return nil
    end

    local ok, player_unit = pcall(function()
        return player.player_unit
    end)

    if ok and player_unit then
        return player_unit
    end

    return safe_call(player, "unit")
end

local function get_player_archetype(player)
    local archetype_name = safe_call(player, "archetype_name")
    if type(archetype_name) == "string" then
        return archetype_name
    end

    local profile = safe_call(player, "profile")
    local archetype = profile and profile.archetype
    return archetype and archetype.name
end

local function refresh_player(player_override)
    local player = player_override or state.player or get_local_player()
    local player_unit = get_player_unit(player)
    local previous_player = state.player
    local previous_player_unit = state.player_unit
    local previous_class_name = state.class_name
    local previous_has_servo_skull = state.has_servo_skull

    state.player = player
    state.player_unit = player_unit
    state.class_name = get_player_archetype(player)

    state.smart_targeting_extension = safe_extension(player_unit, "smart_targeting_system")
    state.player_talent_extension = safe_extension(player_unit, "talent_system")

    local talent_extension = state.player_talent_extension
    local talents = talent_extension and talent_extension._talents or {}
    local has_grenade_ability = false
    local has_servo_talent = false
    local has_disqualifying_grenade = false
    local cryptic_talent_names = {}

    for name, value in pairs(talents) do
        if type(name) == "string" then
            local lowered_name = string.lower(name)
            if string.find(lowered_name, "cryptic", 1, true)
                or string.find(lowered_name, "servo", 1, true)
                or string.find(lowered_name, "skull", 1, true)
                or string.find(lowered_name, "grenade", 1, true)
                or string.find(lowered_name, "blitz", 1, true)
                or string.find(lowered_name, "companion", 1, true)
            then
                cryptic_talent_names[#cryptic_talent_names + 1] = name
            end

            if string.find(name, "cryptic_grenade_ability_", 1, true) then
                has_grenade_ability = true
                if name == TALENT_NAMES.FORCE_FIELD or name == TALENT_NAMES.ARC_GRENADE then
                    has_disqualifying_grenade = true
                    break
                end
            end

            if string.find(name, "servo_skull", 1, true)
                or string.find(name, "inject_ally", 1, true)
                or string.find(name, "flamethrower", 1, true)
            then
                has_servo_talent = true
            end
        end
    end

    state.has_servo_skull = state.class_name == CRYPTIC_CLASS
        and (has_grenade_ability or has_servo_talent)
        and not has_disqualifying_grenade

    if previous_player ~= state.player
        or previous_player_unit ~= state.player_unit
        or previous_class_name ~= state.class_name
        or previous_has_servo_skull ~= state.has_servo_skull
    then
        clear_runtime_target_state()
        debug_print("player context changed", tostring(previous_class_name), "->", tostring(state.class_name), "servo", tostring(state.has_servo_skull))
    end

    set_physics_world(state.smart_targeting_extension and state.smart_targeting_extension._physics_world or nil)
    ensure_visibility_raycast()
end

local function refresh_systems()
    local extension_manager = Managers and Managers.state and Managers.state.extension
    state.smart_tag_system = extension_manager and safe_call(extension_manager, "system", "smart_tag_system") or state.smart_tag_system

    local hud = Managers and Managers.ui and safe_call(Managers.ui, "get_hud")
    local hud_element = hud and safe_call(hud, "element", "HudElementSmartTagging")
    state.hud_element_smart_tagging = hud_element or state.hud_element_smart_tagging

    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    if game_mode_manager then
        local in_hub = false
        local ok_social, social_hub = pcall(function()
            return game_mode_manager:is_social_hub()
        end)
        local ok_prologue, prologue_hub = pcall(function()
            return game_mode_manager:is_prologue_hub()
        end)

        in_hub = (ok_social and social_hub) or (ok_prologue and prologue_hub)
        state.game_mode_valid = not (settings.disable_in_hub and in_hub)
    else
        state.game_mode_valid = false
    end
end

local function gameplay_time()
    if Managers and Managers.time then
        local value = safe_call(Managers.time, "time", "gameplay")
        if type(value) == "number" then
            return value
        end
    end

    return 0
end

local function init_context()
    refresh_player()
    refresh_systems()
end

local function clear_transient_state()
    clear_runtime_target_state()
    state.companion_burst = nil
end

local function player_ready()
    return state.mod_runtime_enabled
        and settings.toggle_mod
        and state.game_mode_valid
        and state.player
        and state.player_unit
        and unit_alive(state.player_unit)
        and state.class_name == CRYPTIC_CLASS
        and state.has_servo_skull
        and state.smart_tag_system
end

aiming_parameters = function()
    local extension = state.smart_targeting_extension
    if not extension or not extension._targeting_parameters then
        return nil
    end

    local ok, ray_origin, forward, right, up = pcall(function()
        return extension:_targeting_parameters()
    end)

    if ok and ray_origin and forward then
        return ray_origin, forward, right, up
    end

    return nil
end

local function visibility_cache_valid(cached, cached_frame, fixed_frame)
    if cached == nil or not cached_frame or not fixed_frame then
        return false
    end

    local cache_frames = cached and settings.los_cache_frames or math.min(settings.los_cache_frames or 1, 1)
    return fixed_frame - cached_frame <= cache_frames
end

local function raycast_clear_to_position(ray_origin, target_position)
    if not ray_origin or not target_position then
        return false
    end

    local ok_ray, ray_to_target = pcall(function()
        return target_position - ray_origin
    end)
    if not ok_ray or not ray_to_target then
        return false
    end

    local ok_distance, distance = pcall(Vector3.length, ray_to_target)
    if not ok_distance or not distance then
        return false
    end

    if distance <= 0.05 then
        return true
    end

    local ok_direction, direction = pcall(Vector3.normalize, ray_to_target)
    if not ok_direction or not direction then
        return false
    end

    local visible = false
    local raycast_resolved = false
    if state.visibility_raycast_object and Raycast and Raycast.cast then
        local ok, hit = pcall(
            Raycast.cast,
            state.visibility_raycast_object,
            ray_origin,
            direction,
            distance
        )
        if ok then
            visible = not hit
            raycast_resolved = true
        else
            state.visibility_raycast_object = nil
            state.visibility_raycast_world = nil
        end
    end

    if not raycast_resolved and state.physics_world and PhysicsWorld and PhysicsWorld.raycast then
        local ok, hit = pcall(
            PhysicsWorld.raycast,
            state.physics_world,
            ray_origin,
            direction,
            distance,
            "closest",
            "collision_filter",
            "filter_interactable_line_of_sight_marker_check"
        )
        visible = ok and not hit
    end

    return visible
end

local function unit_los_nodes(unit)
    if not unit or not Unit or not Unit.node then
        return nil
    end

    local cached = state.los_node_cache[unit]
    if cached ~= nil then
        return cached or nil
    end

    local nodes = {}
    for i = 1, #LOS_NODE_NAMES do
        local ok_node, node = pcall(Unit.node, unit, LOS_NODE_NAMES[i])
        if ok_node and node ~= nil then
            nodes[#nodes + 1] = node
        end
    end

    if #nodes <= 0 then
        state.los_node_cache[unit] = false
        return nil
    end

    state.los_node_cache[unit] = nodes
    return nodes
end

local function unit_node_world_position(unit, node)
    if not unit or node == nil or not Unit or not Unit.world_position then
        return nil
    end

    local ok_position, position = pcall(Unit.world_position, unit, node)
    if ok_position then
        return position
    end

    return nil
end

local function raycast_visible(ray_origin, target_position, target_unit, fixed_frame)
    if not ray_origin or not target_position then
        return false
    end

    local cache_key = target_unit or target_position
    local cached = state.visibility_cache[cache_key]
    local cached_frame = state.visibility_frame[cache_key]
    if visibility_cache_valid(cached, cached_frame, fixed_frame) then
        return cached
    end

    local visible = raycast_clear_to_position(ray_origin, target_position)
    if not visible and target_unit then
        local nodes = unit_los_nodes(target_unit)
        for i = 1, nodes and #nodes or 0 do
            local sample_position = unit_node_world_position(target_unit, nodes[i])
            if sample_position and raycast_clear_to_position(ray_origin, sample_position) then
                visible = true
                break
            end
        end
    end

    state.visibility_cache[cache_key] = visible
    state.visibility_frame[cache_key] = fixed_frame or 0
    return visible
end

local function target_visible(target_unit, max_range, require_los, fixed_frame)
    if not target_unit or not unit_alive(target_unit) then
        return false
    end

    local ray_origin = aiming_parameters()
    local target_position_value = unit_position(target_unit)
    if not ray_origin or not target_position_value then
        return false
    end

    if max_range and distance_between(ray_origin, target_position_value) > max_range then
        return false
    end

    if not require_los then
        return true
    end

    return raycast_visible(ray_origin, target_position_value, target_unit, fixed_frame)
end

local function target_health_percent(unit)
    local health_extension = safe_extension(unit, "health_system")
    if not health_extension then
        return nil
    end

    local health_fraction = safe_call(health_extension, "current_health_percent")
    if type(health_fraction) == "number" then
        if health_fraction <= 1 then
            return math.max(0, math.min(100, health_fraction * 100))
        end

        return math.max(0, math.min(100, health_fraction))
    end

    local current_health = safe_call(health_extension, "current_health")
    local max_health = safe_call(health_extension, "max_health")
    if type(current_health) == "number" and type(max_health) == "number" and max_health > 0 then
        return math.max(0, math.min(100, current_health / max_health * 100))
    end

    return nil
end

local function noosphere_target_above_release_health(unit)
    local release_percent = settings.noosphere_release_health_percent or 0
    if release_percent <= 0 then
        return true
    end

    if not is_enemy_unit(unit) then
        return true
    end

    local health_percent = target_health_percent(unit)
    if health_percent == nil then
        return true
    end

    return health_percent > release_percent
end

local function target_breed(target_unit)
    local unit_data_extension = safe_extension(target_unit, "unit_data_system") or required_extension(target_unit, "unit_data_system")
    if not unit_data_extension then
        return nil
    end

    local breed_data = safe_call(unit_data_extension, "breed")
    if breed_data then
        return breed_data
    end

    return unit_data_extension._breed
end

is_enemy_unit = function(target_unit)
    local breed_data = target_breed(target_unit)
    return breed_data and Breed.is_minion(breed_data) and breed_data.smart_tag_target_type == "breed"
end

local function lowercase(value)
    if type(value) ~= "string" then
        return ""
    end

    return string.lower(value)
end

local function breed_name_text(breed_data)
    if not breed_data then
        return ""
    end

    local breed_name = lowercase(breed_data.name)
    if breed_name == "" then
        breed_name = lowercase(breed_data.display_name)
    end

    if breed_name == "" then
        breed_name = lowercase(breed_data.boss_display_name)
    end

    return breed_name
end

is_pox_burster_breed = function(breed_data)
    local breed_name = breed_name_text(breed_data)
    if breed_name == "" then
        return false
    end

    if not string.find(breed_name, "pox", 1, true) then
        return false
    end

    for hint, _ in pairs(POX_BURSTER_HINTS) do
        if string.find(breed_name, hint, 1, true) then
            return true
        end
    end

    return false
end

local function is_pox_bomb(target_unit)
    return is_pox_burster_breed(target_breed(target_unit))
end

local function ally_near_position(position, radius)
    if not position or not radius or radius <= 0 then
        return false
    end

    local player_manager = Managers and Managers.player
    local players = player_manager and safe_call(player_manager, "players")
    if not players then
        return false
    end

    for _, player in pairs(players) do
        if player and player ~= state.player then
            local player_unit = get_player_unit(player)
            local player_position = unit_alive(player_unit) and unit_position(player_unit)
            if player_position and distance_between(position, player_position) <= radius then
                return true
            end
        end
    end

    return false
end

local function smart_pox_safety(unit, fixed_frame)
    if not unit or not target_ready_for_smart_tag(unit) or not is_pox_bomb(unit) then
        return false
    end

    local pox_position = unit_position(unit)
    local player_position = unit_position(state.player_unit)
    if not pox_position or not player_position then
        return false
    end

    local distance = distance_between(player_position, pox_position)
    local min_distance = math.max(10, settings.smart_pox_min_distance or 10)
    local disengage_distance = min_distance + SMART_POX_DISENGAGE_BUFFER
    if distance <= disengage_distance then
        return false, distance, "close"
    end

    local max_range = settings.smart_pox_max_range or settings.noosphere_max_range or 45
    if distance > max_range then
        return false, distance, "far"
    end

    local ally_radius = math.max(10, settings.smart_pox_ally_safe_radius or 10)
    if ally_near_position(pox_position, ally_radius) then
        return false, distance, "ally"
    end

    if settings.smart_pox_require_los then
        local ray_origin = aiming_parameters()
        if not ray_origin or not raycast_visible(ray_origin, pox_position, unit, fixed_frame) then
            return false, distance, "los"
        end
    end

    return true, distance, "safe"
end

local function noosphere_target_allowed(unit, fixed_frame)
    if is_pox_bomb(unit) then
        return settings.smart_pox_enabled and smart_pox_safety(unit, fixed_frame)
    end

    return noosphere_target_above_release_health(unit)
end

local function breed_name_contains(breed_data, hints)
    local breed_name = breed_name_text(breed_data)
    for hint, _ in pairs(hints) do
        if string.find(breed_name, hint, 1, true) then
            return true
        end
    end

    return false
end

local function is_trapper_breed(breed_data)
    local tags = breed_data and breed_data.tags
    if tags and (tags.trapper or tags.netgunner) then
        return true
    end

    if tags and tags.disabler and breed_name_contains(breed_data, TRAPPER_HINTS) then
        return true
    end

    return breed_name_contains(breed_data, TRAPPER_HINTS)
end

local function is_passive_daemonhost(breed_data)
    local breed_name = lowercase(breed_data and breed_data.name)
    if not string.find(breed_name, "daemonhost", 1, true) then
        return false
    end

    return not (breed_data and breed_data.is_boss)
end

local function breed_priority(breed_data)
    if not breed_data then
        return 0
    end

    if settings.noosphere_skip_passive_daemonhost and is_passive_daemonhost(breed_data) then
        return 0
    end

    if is_pox_burster_breed(breed_data) then
        return 0
    end

    if settings.noosphere_trapper_max_priority and is_trapper_breed(breed_data) then
        return FIXED_AUTO_PING_PRIORITY.trapper
    end

    if breed_data.is_boss then
        return FIXED_AUTO_PING_PRIORITY.boss
    end

    if breed_data.tags and breed_data.tags.special then
        return FIXED_AUTO_PING_PRIORITY.special
    end

    if breed_data.tags and breed_data.tags.elite then
        return FIXED_AUTO_PING_PRIORITY.elite
    end

    if breed_data.faction_name ~= "imperium" then
        return FIXED_AUTO_PING_PRIORITY.other
    end

    return 0
end

local function companion_template_for(target_unit, fallback_template)
    local smart_tag_system = state.smart_tag_system
    if not smart_tag_system or not target_unit then
        return nil
    end

    local player_unit = state.player_unit
    local target_extension = smart_tag_system._unit_extension_data and smart_tag_system._unit_extension_data[target_unit]
    if target_extension then
        local template_name = safe_call(target_extension, "_contextual_tag_template_name", player_unit, COMPANION_ORDER)
        if type(template_name) == "string" and template_name ~= "" then
            return template_name
        end

        local template = safe_call(target_extension, "contextual_tag_template", player_unit, COMPANION_ORDER)
        if template and type(template.name) == "string" then
            return template.name
        end
    end

    return target_extension and fallback_template or nil
end

local function smart_tag_extension_for(unit)
    local smart_tag_system = state.smart_tag_system
    return smart_tag_system
        and unit
        and smart_tag_system._unit_extension_data
        and smart_tag_system._unit_extension_data[unit]
end

local function health_extension_allows_tag(unit)
    local health_extension = safe_extension(unit, "health_system")
    if not health_extension then
        return true
    end

    local is_dead = safe_call(health_extension, "is_dead")
    if is_dead == true then
        return false
    end

    local is_alive = safe_call(health_extension, "is_alive")
    if is_alive == false then
        return false
    end

    local current_health = safe_call(health_extension, "current_health")
    if type(current_health) == "number" and current_health <= 0 then
        return false
    end

    local health_percent = safe_call(health_extension, "current_health_percent")
    if type(health_percent) == "number" and health_percent <= 0 then
        return false
    end

    return true
end

target_ready_for_smart_tag = function(unit)
    return unit
        and unit_alive(unit)
        and health_extension_allows_tag(unit)
        and smart_tag_extension_for(unit) ~= nil
end

local function current_tag(target_unit)
    local smart_tag_system = state.smart_tag_system
    if not smart_tag_system or not target_unit or not smart_tag_system.unit_tag or not smart_tag_extension_for(target_unit) then
        return nil
    end

    return safe_call(smart_tag_system, "unit_tag", target_unit)
end

local function available_for_noosphere_order(unit)
    return unit ~= nil
end

local function can_command(t)
    return t - state.last_command_t >= settings.global_command_cooldown
end

local function can_issue_noosphere_order(t)
    local now = t or gameplay_time()
    local window_start = state.noosphere_order_window_t or -999
    if now - window_start > 6.0 then
        state.noosphere_order_window_t = now
        state.noosphere_order_window_count = 0
    end

    if (state.noosphere_order_window_count or 0) >= 5 then
        state.timers.noosphere = math.max(state.timers.noosphere or 0, 0.45)
        debug_print("noosphere rate guard")
        return false
    end

    state.noosphere_order_window_count = (state.noosphere_order_window_count or 0) + 1
    return true
end

local function append_unique(list, value)
    if not value then
        return
    end

    for i = 1, #list do
        if list[i] == value then
            return
        end
    end

    list[#list + 1] = value
end

local function template_list(template_names)
    local templates = {}
    if type(template_names) == "table" then
        for i = 1, #template_names do
            append_unique(templates, template_names[i])
        end
    else
        append_unique(templates, template_names)
    end

    return templates
end

local function pcall_success(fn)
    local ok, result = pcall(fn)
    return ok and result ~= false
end

local function reason_is_task(reason)
    return type(reason) == "string" and string.find(reason, "task", 1, true) ~= nil
end

local function reason_is_task_order(reason)
    return type(reason) == "string" and string.find(reason, "task", 1, true) ~= nil
end

local function reason_is_noosphere_order(reason)
    return reason == "noosphere" or reason == "smart_pox"
end

local function emergency_noosphere_unit(unit)
    local breed_data = target_breed(unit)
    return breed_data ~= nil and (is_trapper_breed(breed_data) or is_pox_burster_breed(breed_data))
end

local function clear_pending_noosphere()
    state.pending_noosphere_unit = nil
    state.pending_noosphere_until = 0
end

local function complete_noosphere_order(ordered, target_unit, reason, t)
    if not reason_is_noosphere_order(reason) then
        return
    end

    clear_pending_noosphere()

    if ordered then
        state.timers.noosphere = settings.noosphere_interval
        state.timers.auto_ping_scan = 0
        state.last_servo_enemy_unit = target_unit
        state.last_noosphere_order_t = t or gameplay_time()
        state.noosphere_candidate_unit = target_unit
        state.noosphere_candidate_until = (t or 0) + math.max(0.20, settings.noosphere_interval or 1.50)
    else
        state.timers.noosphere = 0.05
        state.timers.auto_ping_scan = 0
    end
end

local function set_companion_tag_now(template_names, target_unit, reason, t)
    if not player_ready() then
        complete_noosphere_order(false, target_unit, reason, t)
        return false
    end

    local smart_tag_system = state.smart_tag_system
    local player_unit = state.player_unit
    local templates = template_list(template_names)
    if not smart_tag_system or not player_unit or not target_unit or #templates == 0 then
        complete_noosphere_order(false, target_unit, reason, t)
        return false
    end

    if not target_ready_for_smart_tag(target_unit) then
        if target_unit == state.noosphere_candidate_unit then
            state.noosphere_candidate_unit = nil
            state.noosphere_candidate_until = 0
        end

        if target_unit == state.last_servo_enemy_unit or target_unit == state.sticky_enemy_unit then
            state.last_servo_enemy_unit = nil
            state.sticky_enemy_unit = nil
            state.timers.noosphere = 0
            state.timers.auto_ping_scan = 0
        end

        complete_noosphere_order(false, target_unit, reason, t)
        return false
    end

    local target_tag = current_tag(target_unit)
    local target_template = target_tag and target_tag._template
    local target_template_name = target_template and target_template.name
    local is_noosphere_order = reason_is_noosphere_order(reason)

    if is_noosphere_order
        and target_template_name
        and target_template_name ~= BASIC_ENEMY_TAG
        and target_template_name ~= SERVO_ENEMY_TAG
    then
        debug_print("skip noosphere overwrite", target_template_name)
        complete_noosphere_order(false, target_unit, reason, t)
        return false
    end

    local should_cancel_existing_tag = target_tag
        and type(smart_tag_system.cancel_tag) == "function"
        and settings.replace_basic_enemy_tags
        and target_template_name == BASIC_ENEMY_TAG

    if should_cancel_existing_tag then
        pcall(smart_tag_system.cancel_tag, smart_tag_system, target_tag._id, player_unit, true)
        target_tag = nil
        target_template = nil
        target_template_name = nil
    end

    for i = 1, #templates do
        local template_name = templates[i]
        local contextual_ok = false
        if (reason_is_task(reason) or is_noosphere_order) and type(smart_tag_system.set_contextual_unit_tag) == "function" then
            contextual_ok = pcall_success(function()
                smart_tag_system:set_contextual_unit_tag(player_unit, target_unit, COMPANION_ORDER)
            end)
        end

        if not target_ready_for_smart_tag(target_unit) then
            complete_noosphere_order(false, target_unit, reason, t)
            return false
        end

        local tag_ok = pcall_success(function()
            smart_tag_system:set_tag(template_name, player_unit, target_unit)
        end)

        local interaction_ok = false
        if type(smart_tag_system.trigger_tag_interaction) == "function" and settings.task_trigger_interaction and reason_is_task_order(reason) then
            local tag = current_tag(target_unit)
            local tag_id = tag and tag._id
            if tag_id then
                interaction_ok = pcall_success(function()
                    smart_tag_system:trigger_tag_interaction(tag_id, player_unit, target_unit, COMPANION_ORDER)
                end) or interaction_ok
            end
        end

        if tag_ok or is_noosphere_order and (contextual_ok or interaction_ok) then
            if not target_ready_for_smart_tag(target_unit) then
                complete_noosphere_order(false, target_unit, reason, t)
                return false
            end

            state.last_command_t = t or 0
            state.self_issued_until = (t or 0) + 0.35
            if template_name == SERVO_ENEMY_TAG then
                state.last_servo_enemy_unit = target_unit
            end
            debug_print("ordered", template_name, reason or "unknown")
            complete_noosphere_order(true, target_unit, reason, t)
            return true
        end

        debug_print("order failed", template_name, reason or "unknown")
    end

    complete_noosphere_order(false, target_unit, reason, t)
    return false
end

local function order_companion(template_names, target_unit, reason, t)
    if not can_command(t or 0) then
        return false
    end

    if not target_ready_for_smart_tag(target_unit) then
        return false
    end

    if not settings.physics_safe_commands then
        return set_companion_tag_now(template_names, target_unit, reason, t)
    end

    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    if game_mode_manager and game_mode_manager.register_physics_safe_callback then
        local cb = callback(function()
            if player_ready() and target_ready_for_smart_tag(target_unit) then
                set_companion_tag_now(template_names, target_unit, reason, t)
            end
        end)
        game_mode_manager:register_physics_safe_callback(cb)
        state.last_command_t = t or 0
        return true
    end

    return set_companion_tag_now(template_names, target_unit, reason, t)
end

local function noosphere_order_pending(t)
    if not state.pending_noosphere_unit then
        return false
    end

    if (t or 0) <= (state.pending_noosphere_until or 0)
        and target_ready_for_smart_tag(state.pending_noosphere_unit)
    then
        return true
    end

    clear_pending_noosphere()
    state.timers.noosphere = 0
    state.timers.auto_ping_scan = 0
    return false
end

local function order_noosphere(template_name, target_unit, reason, t)
    if not target_unit or not template_name or not reason_is_noosphere_order(reason) then
        return false
    end

    if not target_ready_for_smart_tag(target_unit) then
        complete_noosphere_order(false, target_unit, reason, t)
        return false
    end

    if not can_command(t or 0) then
        state.timers.noosphere = 0.04
        return false
    end

    if noosphere_order_pending(t) then
        return false
    end

    if not emergency_noosphere_unit(target_unit) and not can_issue_noosphere_order(t) then
        return false
    end

    if not settings.physics_safe_commands then
        return set_companion_tag_now(template_name, target_unit, reason, t)
    end

    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    if game_mode_manager and game_mode_manager.register_physics_safe_callback then
        state.pending_noosphere_unit = target_unit
        state.pending_noosphere_until = (t or 0) + 0.12
        state.timers.noosphere = 0.04
        state.last_command_t = t or 0

        local cb = callback(function()
            if player_ready() and target_ready_for_smart_tag(target_unit) then
                set_companion_tag_now(template_name, target_unit, reason, t)
            else
                complete_noosphere_order(false, target_unit, reason, t)
            end
        end)
        game_mode_manager:register_physics_safe_callback(cb)
        return true
    end

    return set_companion_tag_now(template_name, target_unit, reason, t)
end

local function set_companion_tag_scheduled(template_names, target_unit, reason, t)
    if not target_ready_for_smart_tag(target_unit) then
        return false
    end

    if not settings.physics_safe_commands then
        return set_companion_tag_now(template_names, target_unit, reason, t)
    end

    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    if game_mode_manager and game_mode_manager.register_physics_safe_callback then
        local cb = callback(function()
            if player_ready() and target_ready_for_smart_tag(target_unit) then
                set_companion_tag_now(template_names, target_unit, reason, t)
            end
        end)
        game_mode_manager:register_physics_safe_callback(cb)
        return true
    end

    return set_companion_tag_now(template_names, target_unit, reason, t)
end

local function queue_companion_burst(template_names, target_unit, reason, t, attempts, spacing)
    if not target_unit or not template_names then
        return false
    end

    local is_task = reason_is_task_order(reason)
    local max_attempts = is_task and 10 or 8

    attempts = math.max(1, math.min(max_attempts, math.floor(attempts or 2)))
    spacing = math.max(0.08, math.min(0.35, spacing or 0.16))

    local active = state.companion_burst
    if active and active.target_unit == target_unit and active.reason == reason then
        return true
    end

    state.companion_burst = {
        template_names = template_names,
        target_unit = target_unit,
        reason = reason or "task",
        remaining = math.max(0, attempts - 1),
        spacing = spacing,
        next_t = (t or 0) + spacing,
    }

    state.last_command_t = t or 0
    debug_print("companion burst", tostring(reason), "attempts", attempts)
    return set_companion_tag_scheduled(template_names, target_unit, reason, t)
end

local function run_companion_burst(t)
    local burst = state.companion_burst
    if not burst then
        return false
    end

    if burst.remaining <= 0
        or not unit_alive(burst.target_unit)
        or settings.task_cancel_burst_on_invalid_target
            and reason_is_task_order(burst.reason)
            and not target_ready_for_smart_tag(burst.target_unit)
    then
        state.companion_burst = nil
        return false
    end

    if t < burst.next_t then
        return true
    end

    burst.remaining = burst.remaining - 1
    burst.next_t = t + burst.spacing
    set_companion_tag_scheduled(burst.template_names, burst.target_unit, burst.reason, t)

    if burst.remaining <= 0 then
        state.companion_burst = nil
    end

    return true
end

local function track_manual_enemy_order(target_unit)
    if not target_unit or not is_enemy_unit(target_unit) then
        return
    end

    if is_pox_bomb(target_unit) then
        return
    end

    if not player_ready() then
        return
    end

    if not settings.auto_ping_enabled then
        return
    end

    if not settings.noosphere_sticky_manual_target then
        return
    end

    state.sticky_enemy_unit = target_unit
    state.last_servo_enemy_unit = target_unit
    debug_print("sticky manual target")
end

player_for_unit = function(unit)
    if not unit then
        return nil
    end

    local player_manager = Managers and Managers.player
    local players = player_manager and safe_call(player_manager, "players")
    if not players then
        return nil
    end

    for _, player in pairs(players) do
        if get_player_unit(player) == unit then
            return player
        end
    end

    return nil
end

local function interaction_type_for_unit(unit)
    local interactee_extension = safe_extension(unit, "interactee_system")
        or safe_extension(unit, "player_interactee_system")
    if not interactee_extension then
        return nil
    end

    return safe_call(interactee_extension, "interaction_type")
end

local function template_name_looks_like_task(template_name, interaction_type)
    if type(interaction_type) == "string" then
        local lowered_interaction = string.lower(interaction_type)
        if settings.task_ignore_pickups and BLOCKED_TASK_INTERACTION_TYPES[lowered_interaction] then
            return false
        end

        if TASK_INTERACTION_TYPES[lowered_interaction] then
            return true
        end
    end

    if type(template_name) ~= "string" or template_name == SERVO_ENEMY_TAG then
        return false
    end

    local lowered = string.lower(template_name)
    if settings.task_ignore_pickups then
        for hint, _ in pairs(BLOCKED_TASK_TEMPLATE_HINTS) do
            if string.find(lowered, hint, 1, true) then
                return false
            end
        end
    end

    for hint, _ in pairs(TASK_TEMPLATE_HINTS) do
        if string.find(lowered, hint, 1, true) then
            return true
        end
    end

    return false
end

local function valid_task_target(unit, fixed_frame)
    if not unit or not unit_alive(unit) or is_enemy_unit(unit) then
        return nil
    end

    if player_for_unit(unit) then
        return nil
    end

    local template_name = companion_template_for(unit, nil)
    local interaction_type = interaction_type_for_unit(unit)
    if not template_name or not template_name_looks_like_task(template_name, interaction_type) then
        return nil
    end

    if target_visible(unit, settings.task_max_range, settings.task_require_los, fixed_frame) then
        debug_print("task candidate", template_name)
        return template_name
    end

    return nil
end

local function remember_contextual_task_target(unit, template_name, t)
    local previous_unit = state.task_context_unit
    if not unit
        or not unit_alive(unit)
        or is_enemy_unit(unit)
        or player_for_unit(unit)
        or not template_name_looks_like_task(template_name, interaction_type_for_unit(unit))
    then
        return
    end

    state.task_context_unit = unit
    state.task_context_template = template_name
    state.task_context_until = (t or gameplay_time()) + (settings.task_context_memory or 2.5)
    if settings.task_fast_retry_on_new_context then
        state.timers.task = 0
        if state.companion_burst
            and reason_is_task_order(state.companion_burst.reason)
            and state.companion_burst.target_unit ~= unit
        then
            state.companion_burst = nil
        end
    elseif previous_unit ~= unit then
        state.timers.task = math.min(state.timers.task or 0, 0.25)
    end
    debug_print("task contextual cached", template_name)
end

local function current_contextual_task_target(fixed_frame)
    local t = gameplay_time()
    if not state.task_context_unit
        or state.task_context_until <= t
        or not unit_alive(state.task_context_unit)
    then
        state.task_context_unit = nil
        state.task_context_template = nil
        state.task_context_until = 0
        return nil
    end

    local template_name = valid_task_target(state.task_context_unit, fixed_frame)
    if template_name then
        return state.task_context_unit, template_name
    end

    return nil
end

local function current_world_marker_target()
    local hud_element = state.hud_element_smart_tagging
    if hud_element and hud_element._find_world_marker_target then
        local ok, marker = pcall(function()
            local target_marker = hud_element:_find_world_marker_target()
            return target_marker
        end)

        if ok and marker and marker.unit then
            return marker.unit
        end
    end

    local smart_targeting_extension = state.smart_targeting_extension
    local targeting_data = smart_targeting_extension and safe_call(smart_targeting_extension, "smart_tag_targeting_data")
    local target_unit = targeting_data and targeting_data.unit

    if target_unit and unit_alive(target_unit) then
        return target_unit
    end

    return nil
end

local function current_interactor_target()
    local interactor_extension = safe_extension(state.player_unit, "interactor_system")
    if not interactor_extension then
        return nil
    end

    local target_unit = safe_call(interactor_extension, "target_unit")
    if target_unit and unit_alive(target_unit) then
        return target_unit
    end

    target_unit = safe_call(interactor_extension, "focus_unit")
    if target_unit and unit_alive(target_unit) then
        return target_unit
    end

    return nil
end

local function try_task_candidate(unit, fixed_frame)
    local template_name = valid_task_target(unit, fixed_frame)
    if template_name then
        return unit, template_name
    end

    return nil
end

local function find_scannable_task(fixed_frame)
    local extension_manager = Managers and Managers.state and Managers.state.extension
    local mission_objective_zone_system = extension_manager and extension_manager.system and extension_manager:system("mission_objective_zone_system")
    local scannable_units = mission_objective_zone_system and safe_call(mission_objective_zone_system, "scannable_units")
    if not scannable_units then
        return nil
    end

    for scannable_unit, _ in pairs(scannable_units) do
        local scannable_extension = safe_extension(scannable_unit, "mission_objective_zone_scannable_system")
        local active = scannable_extension and safe_call(scannable_extension, "is_active")
        if active then
            local unit, template_name = try_task_candidate(scannable_unit, fixed_frame)
            if unit then
                return unit, template_name
            end
        end
    end

    return nil
end

local function find_task_target(fixed_frame)
    if settings.task_prefer_crosshair then
        local unit, template_name = try_task_candidate(current_world_marker_target(), fixed_frame)
        if unit then
            return unit, template_name
        end
    end

    if settings.task_use_interactor_target then
        local unit, template_name = try_task_candidate(current_interactor_target(), fixed_frame)
        if unit then
            return unit, template_name
        end
    end

    local unit, template_name = current_contextual_task_target(fixed_frame)
    if unit then
        return unit, template_name
    end

    if settings.task_use_scannable_units then
        return find_scannable_task(fixed_frame)
    end

    return nil
end

local function add_minion(unit)
    if not unit or state.minions[unit] then
        return
    end

    local breed_data = target_breed(unit)
    if breed_data and Breed.is_minion(breed_data) and breed_data.smart_tag_target_type == "breed" then
        state.minions[unit] = breed_data
        state.minion_order[#state.minion_order + 1] = unit
    end
end

local function cancel_servo_tags_for_unit(unit)
    local smart_tag_system = state.smart_tag_system
    if not unit or not smart_tag_system or type(smart_tag_system._all_tags) ~= "table" then
        return
    end

    if state.tag_cleanup_units[unit] then
        return
    end

    state.tag_cleanup_units[unit] = true

    local player_unit = state.player_unit
    local cancel_tag = smart_tag_system.cancel_tag

    for tag_id, tag in pairs(smart_tag_system._all_tags) do
        local template = tag and tag._template
        if tag
            and tag._target_unit == unit
            and template
            and template.name == SERVO_ENEMY_TAG
        then
            local cancelled = false
            if type(cancel_tag) == "function" and player_unit then
                cancelled = pcall(cancel_tag, smart_tag_system, tag_id, player_unit, true)
            end

            if not cancelled and smart_tag_system._all_tags[tag_id] == tag then
                clear_smart_tag_entry(smart_tag_system, tag_id, tag)
            end
        end
    end

    state.tag_cleanup_units[unit] = nil
end

local function remove_minion(unit)
    if not unit then
        return
    end

    local was_noosphere_target = state.sticky_enemy_unit == unit
        or state.last_servo_enemy_unit == unit
        or state.noosphere_candidate_unit == unit

    state.minions[unit] = nil
    state.visibility_cache[unit] = nil
    state.visibility_frame[unit] = nil
    state.los_node_cache[unit] = nil

    cancel_servo_tags_for_unit(unit)

    if state.sticky_enemy_unit == unit then
        state.sticky_enemy_unit = nil
    end

    if state.last_servo_enemy_unit == unit then
        state.last_servo_enemy_unit = nil
    end

    if state.noosphere_candidate_unit == unit then
        state.noosphere_candidate_unit = nil
        state.noosphere_candidate_until = 0
    end

    if state.return_enemy_unit == unit then
        state.return_enemy_unit = nil
        state.return_enemy_until = 0
    end

    if state.pending_noosphere_unit == unit then
        state.pending_noosphere_unit = nil
        state.pending_noosphere_until = 0
    end

    if state.companion_burst and state.companion_burst.target_unit == unit then
        state.companion_burst = nil
    end

    if state.task_context_unit == unit then
        state.task_context_unit = nil
        state.task_context_template = nil
        state.task_context_until = 0
    end

    if was_noosphere_target then
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
        state.noosphere_candidate_until = 0
    end
end

local function prune_minion_order()
    if #state.minion_order < 160 then
        return
    end

    local new_order = {}
    for i = 1, #state.minion_order do
        local unit = state.minion_order[i]
        if state.minions[unit] then
            new_order[#new_order + 1] = unit
        end
    end
    state.minion_order = new_order
    if state.minion_scan_index > #state.minion_order then
        state.minion_scan_index = 1
    end
end

local function prune_visibility_cache(fixed_frame)
    if not fixed_frame or fixed_frame % 120 ~= 0 then
        return
    end

    for unit, frame in pairs(state.visibility_frame) do
        if not unit_alive(unit) or not state.minions[unit] or fixed_frame - frame > 120 then
            state.visibility_cache[unit] = nil
            state.visibility_frame[unit] = nil
        end
    end
end

local function unit_in_cone(ray_origin, forward, unit, max_range, cone_cos)
    local position = unit_position(unit)
    if not position then
        return false
    end

    local to_target = position - ray_origin
    local distance = Vector3.length(to_target)
    if distance <= 0.05 or distance > max_range then
        return false
    end

    local direction = Vector3.normalize(to_target)
    local dot = Vector3.dot(forward, direction)
    return dot >= cone_cos, position, distance, dot
end

local function enemy_score(breed_data, distance, dot)
    local priority = breed_priority(breed_data)
    if priority <= 0 then
        return 0
    end

    local aim_bonus = math.max(0, dot or 0) * 10000
    local distance_bonus = math.max(0, 90 - (distance or 0)) * 18
    local priority_tie_breaker = math.min(priority, 5000) * 0.15
    return aim_bonus + distance_bonus + priority_tie_breaker
end

local function crosshair_enemy(max_range, fixed_frame)
    local smart_targeting_extension = state.smart_targeting_extension
    local precision_target_finder = smart_targeting_extension and smart_targeting_extension._precision_target_aim_assist
    if not smart_targeting_extension or not precision_target_finder then
        return nil
    end

    local ray_origin, forward, right, up = aiming_parameters()
    if not ray_origin then
        return nil
    end

    SMART_TARGETING_TEMPLATE.precision_target.max_range = max_range or 100

    local ok = pcall(function()
        precision_target_finder:update_precision_target(
            smart_targeting_extension._unit,
            SMART_TARGETING_TEMPLATE,
            ray_origin,
            forward,
            right,
            up,
            smart_targeting_extension._smart_tag_targeting_data,
            fixed_frame or smart_targeting_extension._latest_fixed_frame,
            smart_targeting_extension._visibility_cache,
            smart_targeting_extension._visibility_check_frame
        )
    end)

    if not ok then
        return nil
    end

    local targeting_data = safe_call(smart_targeting_extension, "smart_tag_targeting_data")
    local target_unit = targeting_data and targeting_data.unit
    if not target_unit
        or not target_ready_for_smart_tag(target_unit)
        or not is_enemy_unit(target_unit)
        or not available_for_noosphere_order(target_unit)
        or not noosphere_target_allowed(target_unit, fixed_frame)
    then
        return nil
    end

    local breed_data = target_breed(target_unit)
    if breed_priority(breed_data) <= 0 then
        return nil
    end

    return target_unit, breed_data, 1000000 + enemy_score(breed_data, 0, 1)
end

local function find_best_enemy(max_range, cone_degrees, require_los, fixed_frame)
    local ray_origin, forward = aiming_parameters()
    if not ray_origin or not forward then
        return nil
    end

    local cone_cos = math.cos(math.rad((cone_degrees or 110) * 0.5))
    local best_unit = nil
    local best_score = -math.huge
    local best_breed = nil
    local crosshair_unit, crosshair_breed, crosshair_score = crosshair_enemy(max_range, fixed_frame)
    if crosshair_unit then
        best_unit = crosshair_unit
        best_score = crosshair_score
        best_breed = crosshair_breed
    end
    local budget = math.max(1, math.floor(settings.enemy_scan_budget or 80))
    local count = #state.minion_order

    if count <= 0 then
        return best_unit, best_breed, best_score
    end

    for _ = 1, math.min(count, budget) do
        if state.minion_scan_index > count then
            state.minion_scan_index = 1
        end

        local unit = state.minion_order[state.minion_scan_index]
        state.minion_scan_index = state.minion_scan_index + 1

        local breed_data = state.minions[unit]
        if breed_data then
            local ready = target_ready_for_smart_tag(unit)
            if ready
                and available_for_noosphere_order(unit)
                and not is_trapper_breed(breed_data)
                and not is_pox_burster_breed(breed_data)
                and noosphere_target_allowed(unit, fixed_frame)
            then
                local in_cone, position, distance, dot = unit_in_cone(ray_origin, forward, unit, max_range, cone_cos)
                if in_cone and (not require_los or raycast_visible(ray_origin, position, unit, fixed_frame)) then
                    local score = enemy_score(breed_data, distance, dot)
                    if score > best_score then
                        best_unit = unit
                        best_score = score
                        best_breed = breed_data
                    end
                end
            elseif not ready then
                remove_minion(unit)
            end
        elseif unit then
            remove_minion(unit)
        end
    end

    prune_minion_order()
    return best_unit, best_breed, best_score
end

local function normal_global_auto_ping_target_visible(unit, fixed_frame)
    local breed_data = target_breed(unit)
    if not breed_data or is_trapper_breed(breed_data) or is_pox_burster_breed(breed_data) then
        return false
    end

    if not target_ready_for_smart_tag(unit)
        or not available_for_noosphere_order(unit)
        or not noosphere_target_allowed(unit, fixed_frame)
    then
        return false
    end

    local ray_origin = aiming_parameters()
    local position = unit_position(unit)
    if not ray_origin or not position then
        return false
    end

    local distance = Vector3.distance(ray_origin, position)
    return distance > 0.05
        and distance <= AUTO_PING_FALLBACK_RADIUS
        and raycast_visible(ray_origin, position, unit, fixed_frame)
end

local function global_enemy_score(breed_data, distance)
    local priority = breed_priority(breed_data)
    if priority <= 0 then
        return 0
    end

    local distance_bonus = math.max(0, AUTO_PING_FALLBACK_RADIUS - (distance or 0)) * 75
    local priority_bonus = math.min(priority, 5000) * 0.5
    return priority_bonus + distance_bonus
end

local function find_best_global_enemy(max_range, fixed_frame)
    local ray_origin = aiming_parameters()
    if not ray_origin then
        return nil
    end

    local radius = math.min(max_range or AUTO_PING_FALLBACK_RADIUS, AUTO_PING_FALLBACK_RADIUS)
    local best_unit = nil
    local best_score = -math.huge
    local best_breed = nil
    local count = #state.minion_order

    for i = 1, count do
        local unit = state.minion_order[i]
        local breed_data = state.minions[unit]
        if breed_data then
            local ready = target_ready_for_smart_tag(unit)
            if ready
                and available_for_noosphere_order(unit)
                and not is_trapper_breed(breed_data)
                and not is_pox_burster_breed(breed_data)
                and noosphere_target_allowed(unit, fixed_frame)
            then
                local position = unit_position(unit)
                local distance = position and Vector3.distance(ray_origin, position) or math.huge
                if distance > 0.05
                    and distance <= radius
                    and raycast_visible(ray_origin, position, unit, fixed_frame)
                then
                    local score = global_enemy_score(breed_data, distance)
                    if score > best_score then
                        best_unit = unit
                        best_score = score
                        best_breed = breed_data
                    end
                end
            elseif not ready then
                remove_minion(unit)
            end
        elseif unit then
            remove_minion(unit)
        end
    end

    prune_minion_order()
    return best_unit, best_breed, best_score
end

local function peripheral_enemy_score(breed_data, distance, dot)
    local priority = breed_priority(breed_data)
    if priority <= 0 then
        return 0
    end

    local close_bonus = math.max(0, (settings.noosphere_peripheral_radius or 40) - (distance or 0)) * 4
    return priority + close_bonus + (dot or 0) * 35
end

local function find_best_peripheral_enemy(max_range, fixed_frame)
    if not settings.noosphere_peripheral_scan then
        return nil
    end

    local ray_origin, forward = aiming_parameters()
    if not ray_origin or not forward then
        return nil
    end

    local radius = math.min(max_range or 40, settings.noosphere_peripheral_radius or 40)
    if radius <= 0 then
        return nil
    end

    local best_unit = nil
    local best_score = -math.huge
    local best_breed = nil
    local count = #state.minion_order
    local budget = math.min(count, math.max(1, math.floor((settings.enemy_scan_budget or 80) * 0.5)))

    for _ = 1, budget do
        if state.minion_scan_index > count then
            state.minion_scan_index = 1
        end

        local unit = state.minion_order[state.minion_scan_index]
        state.minion_scan_index = state.minion_scan_index + 1
        local breed_data = state.minions[unit]
        if breed_data then
            local ready = target_ready_for_smart_tag(unit)
            if ready and available_for_noosphere_order(unit) and noosphere_target_allowed(unit, fixed_frame) then
                local position = unit_position(unit)
                if position then
                    local to_target = position - ray_origin
                    local distance = Vector3.length(to_target)
                    if distance > 0.05 and distance <= radius then
                        local direction = Vector3.normalize(to_target)
                        local dot = Vector3.dot(forward, direction)
                        if raycast_visible(ray_origin, position, unit, fixed_frame) then
                            local score = peripheral_enemy_score(breed_data, distance, dot)
                            if score > best_score then
                                best_unit = unit
                                best_score = score
                                best_breed = breed_data
                            end
                        end
                    end
                end
            elseif not ready then
                remove_minion(unit)
            end
        elseif unit then
            remove_minion(unit)
        end
    end

    prune_minion_order()
    return best_unit, best_breed, best_score
end

local function find_best_trapper(max_range, fixed_frame)
    local ray_origin, forward = aiming_parameters()
    if not ray_origin or not forward then
        return nil
    end

    local cone_cos = math.cos(math.rad(TRAPPER_AUTO_PING_CONE_DEGREES * 0.5))
    local peripheral_radius = settings.noosphere_peripheral_scan and (settings.noosphere_peripheral_radius or 40) or 0
    local best_unit = nil
    local best_distance = math.huge
    local count = #state.minion_order
    local budget = count

    for i = 1, budget do
        local unit = state.minion_order[i]
        local breed_data = state.minions[unit]
        if breed_data then
            local ready = target_ready_for_smart_tag(unit)
            if ready
                and available_for_noosphere_order(unit)
                and not is_pox_bomb(unit)
                and is_trapper_breed(breed_data)
            then
                local in_cone, position, distance = unit_in_cone(ray_origin, forward, unit, max_range, cone_cos)
                local in_peripheral_radius = peripheral_radius > 0 and position and distance and distance <= peripheral_radius
                if (in_cone or in_peripheral_radius)
                    and distance < best_distance
                    and raycast_visible(ray_origin, position, unit, fixed_frame)
                then
                    best_unit = unit
                    best_distance = distance
                end
            elseif not ready then
                remove_minion(unit)
            end
        elseif unit then
            remove_minion(unit)
        end
    end

    prune_minion_order()
    return best_unit
end

local function find_smart_pox_target(fixed_frame)
    if not settings.smart_pox_enabled then
        return nil
    end

    local best_unit = nil
    local best_distance = math.huge
    local count = #state.minion_order

    for i = 1, count do
        local unit = state.minion_order[i]
        local breed_data = state.minions[unit]
        if breed_data then
            local ready = target_ready_for_smart_tag(unit)
            if ready and available_for_noosphere_order(unit) and is_pox_burster_breed(breed_data) then
                local safe, distance = smart_pox_safety(unit, fixed_frame)
                if safe and distance < best_distance then
                    best_unit = unit
                    best_distance = distance
                end
            elseif not ready then
                remove_minion(unit)
            end
        elseif unit then
            remove_minion(unit)
        end
    end

    prune_minion_order()
    return best_unit
end

local function normal_auto_ping_target_visible(unit, fixed_frame)
    local breed_data = target_breed(unit)
    if not breed_data or is_trapper_breed(breed_data) or is_pox_burster_breed(breed_data) then
        return false
    end

    if not target_ready_for_smart_tag(unit)
        or not available_for_noosphere_order(unit)
        or not noosphere_target_allowed(unit, fixed_frame)
    then
        return false
    end

    local ray_origin, forward = aiming_parameters()
    if not ray_origin or not forward then
        return false
    end

    local cone_cos = math.cos(math.rad((settings.noosphere_cone_degrees or NORMAL_AUTO_PING_CONE_DEGREES) * 0.5))
    local in_cone, position = unit_in_cone(ray_origin, forward, unit, settings.noosphere_max_range, cone_cos)
    return in_cone and raycast_visible(ray_origin, position, unit, fixed_frame)
end

local function priority_override_target_active(unit, fixed_frame)
    local breed_data = target_breed(unit)
    if not breed_data then
        return false
    end

    if is_pox_burster_breed(breed_data) then
        return settings.smart_pox_enabled and smart_pox_safety(unit, fixed_frame) == true
    end

    if not is_trapper_breed(breed_data) then
        return false
    end

    local ray_origin, forward = aiming_parameters()
    if not ray_origin or not forward then
        return false
    end

    local cone_cos = math.cos(math.rad(TRAPPER_AUTO_PING_CONE_DEGREES * 0.5))
    local peripheral_radius = settings.noosphere_peripheral_scan and (settings.noosphere_peripheral_radius or 40) or 0
    local in_cone, position, distance = unit_in_cone(ray_origin, forward, unit, settings.noosphere_max_range, cone_cos)
    local in_peripheral_radius = peripheral_radius > 0 and position and distance and distance <= peripheral_radius

    return (in_cone or in_peripheral_radius)
        and raycast_visible(ray_origin, position, unit, fixed_frame)
end

local function normal_return_target_valid(unit, fixed_frame)
    return normal_auto_ping_target_visible(unit, fixed_frame)
        or normal_global_auto_ping_target_visible(unit, fixed_frame)
end

local function remember_interrupted_normal_target(t, fixed_frame)
    local unit = state.last_servo_enemy_unit
    if not unit or not normal_return_target_valid(unit, fixed_frame) then
        return
    end

    state.return_enemy_unit = unit
    state.return_enemy_until = (t or gameplay_time()) + 8.0
end

local function take_return_enemy_target(t, fixed_frame)
    local unit = state.return_enemy_unit
    if not unit or (state.return_enemy_until or 0) < (t or gameplay_time()) then
        state.return_enemy_unit = nil
        state.return_enemy_until = 0
        return nil
    end

    if normal_return_target_valid(unit, fixed_frame) then
        return unit
    end

    state.return_enemy_unit = nil
    state.return_enemy_until = 0
    return nil
end

local function clear_noosphere_unit_state(unit)
    if state.sticky_enemy_unit == unit then
        state.sticky_enemy_unit = nil
    end

    if state.last_servo_enemy_unit == unit then
        state.last_servo_enemy_unit = nil
    end

    if state.noosphere_candidate_unit == unit then
        state.noosphere_candidate_unit = nil
        state.noosphere_candidate_until = 0
    end

    if state.pending_noosphere_unit == unit then
        state.pending_noosphere_unit = nil
        state.pending_noosphere_until = 0
    end
end

local function disengage_unsafe_pox_target(fixed_frame)
    local units = {
        state.last_servo_enemy_unit,
        state.sticky_enemy_unit,
        state.noosphere_candidate_unit,
        state.pending_noosphere_unit,
    }

    for i = 1, #units do
        local unit = units[i]
        local breed_data = target_breed(unit)
        if breed_data and is_pox_burster_breed(breed_data) and not priority_override_target_active(unit, fixed_frame) then
            cancel_servo_tags_for_unit(unit)
            clear_noosphere_unit_state(unit)
            state.timers.noosphere = 0
            state.timers.auto_ping_scan = 0
            debug_print("smart pox disengage")
            return true
        end
    end

    local smart_tag_system = state.smart_tag_system
    local all_tags = smart_tag_system and smart_tag_system._all_tags
    if type(all_tags) == "table" then
        for _, tag in pairs(all_tags) do
            local template = tag and tag._template
            local unit = tag and tag._target_unit
            local breed_data = target_breed(unit)
            if template
                and template.name == SERVO_ENEMY_TAG
                and breed_data
                and is_pox_burster_breed(breed_data)
                and not priority_override_target_active(unit, fixed_frame)
            then
                cancel_servo_tags_for_unit(unit)
                clear_noosphere_unit_state(unit)
                state.timers.noosphere = 0
                state.timers.auto_ping_scan = 0
                debug_print("smart pox tag cleared")
                return true
            end
        end
    end

    return false
end

local function closest_alert_threat(fixed_frame)
    if not settings.alert_hud_enabled then
        return nil
    end

    local player_position = unit_position(state.player_unit)
    if not player_position then
        return nil
    end

    local max_range = settings.alert_hud_range or 45
    local best_unit = nil
    local best_name = nil
    local best_distance = math.huge
    local count = #state.minion_order

    for i = 1, count do
        local unit = state.minion_order[i]
        local breed_data = state.minions[unit]
        if breed_data and target_ready_for_smart_tag(unit) then
            local is_trapper = is_trapper_breed(breed_data)
            local is_pox = is_pox_burster_breed(breed_data)
            if is_trapper or is_pox then
                local position = unit_position(unit)
                local distance = position and distance_between(player_position, position) or math.huge
                if distance <= max_range
                    and distance < best_distance
                    and raycast_visible(player_position, position, unit, fixed_frame)
                then
                    best_unit = unit
                    best_name = is_trapper and "TRAPPER" or "POX"
                    best_distance = distance
                end
            end
        elseif unit and not target_ready_for_smart_tag(unit) then
            remove_minion(unit)
        end
    end

    if best_unit then
        return best_name, best_distance
    end

    return nil
end

local function run_alert_hud(t, fixed_frame)
    if not settings.alert_hud_enabled or state.timers.alert > 0 then
        return
    end

    state.timers.alert = settings.alert_hud_interval or 1.0

    local name, distance = closest_alert_threat(fixed_frame)
    if not name then
        state.last_alert_key = nil
        return
    end

    local rounded_distance = math.floor((distance or 0) + 0.5)
    local key = name .. ":" .. tostring(rounded_distance)
    if key == state.last_alert_key and state.timers.alert > 0 then
        return
    end

    state.last_alert_key = key
    mod:notify("[Skitarii] " .. name .. " - " .. tostring(rounded_distance) .. "m")
end

local function hold_target_ready(unit, fixed_frame)
    if not (
        unit
        and target_ready_for_smart_tag(unit)
        and is_enemy_unit(unit)
        and available_for_noosphere_order(unit)
        and noosphere_target_allowed(unit, fixed_frame)
    ) then
        return false
    end

    local breed_data = target_breed(unit)
    if breed_data and (is_trapper_breed(breed_data) or is_pox_burster_breed(breed_data)) then
        return priority_override_target_active(unit, fixed_frame)
    end

    return normal_return_target_valid(unit, fixed_frame)
end

local function sticky_enemy_valid(fixed_frame)
    local unit = state.sticky_enemy_unit
    if not unit then
        return false
    end

    if not unit_alive(unit) or not is_enemy_unit(unit) then
        state.sticky_enemy_unit = nil
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
        return false
    end

    if not available_for_noosphere_order(unit) then
        state.sticky_enemy_unit = nil
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
        return false
    end

    if not hold_target_ready(unit, fixed_frame) then
        if not settings.noosphere_keep_until_dead then
            state.sticky_enemy_unit = nil
            state.timers.noosphere = 0
            state.timers.auto_ping_scan = 0
        end
        return false
    end

    return true
end

local function held_noosphere_target(fixed_frame)
    if not settings.noosphere_sticky_manual_target or not settings.noosphere_keep_until_dead then
        return nil
    end

    local unit = state.last_servo_enemy_unit or state.sticky_enemy_unit
    if not unit then
        return nil
    end

    if hold_target_ready(unit, fixed_frame) then
        return unit
    end

    if state.last_servo_enemy_unit == unit then
        state.last_servo_enemy_unit = nil
    end

    if state.sticky_enemy_unit == unit then
        state.sticky_enemy_unit = nil
    end

    state.timers.noosphere = 0
    state.timers.auto_ping_scan = 0
    return nil
end

local function acquire_noosphere_target(fixed_frame, t)
    if settings.noosphere_enabled and settings.noosphere_trapper_max_priority then
        local trapper_unit = find_best_trapper(settings.noosphere_max_range, fixed_frame)
        if trapper_unit then
            remember_interrupted_normal_target(t, fixed_frame)
            return trapper_unit
        end
    end

    local pox_unit = find_smart_pox_target(fixed_frame)
    if pox_unit then
        remember_interrupted_normal_target(t, fixed_frame)
        return pox_unit
    end

    if not settings.noosphere_enabled then
        return nil
    end

    local sticky_unit = state.sticky_enemy_unit
    local sticky_valid = settings.noosphere_sticky_manual_target
        and sticky_enemy_valid(fixed_frame)
        and noosphere_target_allowed(sticky_unit, fixed_frame)

    local auto_unit
    if settings.noosphere_auto_target then
        auto_unit = find_best_enemy(settings.noosphere_max_range, settings.noosphere_cone_degrees, true, fixed_frame)
    end

    if settings.noosphere_auto_target and auto_unit then
        return auto_unit
    end

    local return_unit = take_return_enemy_target(t, fixed_frame)
    if return_unit then
        return return_unit
    end

    local held_unit = held_noosphere_target(fixed_frame)
    if held_unit then
        return held_unit
    end

    if sticky_valid then
        return sticky_unit
    end

    if settings.noosphere_auto_target then
        local global_unit = find_best_global_enemy(AUTO_PING_FALLBACK_RADIUS, fixed_frame)
        if global_unit then
            return global_unit
        end
    end

    return nil
end

local function candidate_unit_valid(unit, fixed_frame)
    if not (
        unit
        and target_ready_for_smart_tag(unit)
        and is_enemy_unit(unit)
        and available_for_noosphere_order(unit)
        and noosphere_target_allowed(unit, fixed_frame)
    ) then
        return false
    end

    local breed_data = target_breed(unit)
    if breed_data and (is_trapper_breed(breed_data) or is_pox_burster_breed(breed_data)) then
        return priority_override_target_active(unit, fixed_frame)
    end

    return normal_auto_ping_target_visible(unit, fixed_frame)
end

local function choose_noosphere_target(t, fixed_frame)
    if not settings.auto_ping_enabled or (not settings.noosphere_enabled and not settings.smart_pox_enabled) then
        state.noosphere_candidate_unit = nil
        state.noosphere_candidate_until = 0
        return nil
    end

    if settings.noosphere_enabled and settings.noosphere_trapper_max_priority then
        local trapper_unit = find_best_trapper(settings.noosphere_max_range, fixed_frame)
        if trapper_unit then
            remember_interrupted_normal_target(t, fixed_frame)
            state.noosphere_candidate_unit = trapper_unit
            state.noosphere_candidate_until = (t or 0) + 0.20
            return trapper_unit
        end
    end

    local pox_unit = find_smart_pox_target(fixed_frame)
    if pox_unit then
        remember_interrupted_normal_target(t, fixed_frame)
        state.noosphere_candidate_unit = pox_unit
        state.noosphere_candidate_until = (t or 0) + 0.20
        return pox_unit
    end

    local candidate = state.noosphere_candidate_unit
    if state.timers.auto_ping_scan > 0
        and candidate_unit_valid(candidate, fixed_frame)
        and (t or 0) <= (state.noosphere_candidate_until or 0)
    then
        return candidate
    end

    state.timers.auto_ping_scan = settings.noosphere_scan_interval

    local target_unit = acquire_noosphere_target(fixed_frame, t)
    state.noosphere_candidate_unit = target_unit
    state.noosphere_candidate_until = (t or 0) + math.max(0.20, (settings.noosphere_scan_interval or 0.10) * 3)

    return target_unit
end

local function decrement_timers(dt)
    for key, value in pairs(state.timers) do
        if value > 0 then
            state.timers[key] = value - dt
        end
    end
end

local function maybe_refresh_context(dt)
    if state.timers.context_refresh > 0 then
        return
    end

    refresh_player()
    refresh_systems()
    state.timers.context_refresh = 2.0
end

local function run_task_logic(t, fixed_frame)
    if not settings.auto_tasks_enabled or state.timers.task > 0 then
        return false
    end

    state.timers.task = settings.task_interval
    local target_unit, template_name = find_task_target(fixed_frame)
    if target_unit and template_name then
        state.timers.noosphere = math.max(state.timers.noosphere or 0, 0.15)
        return queue_companion_burst(
            template_name,
            target_unit,
            "task",
            t,
            settings.task_burst_attempts,
            settings.task_burst_spacing
        )
    end

    return false
end

local function recover_auto_ping_if_stalled(t)
    if not settings.auto_ping_enabled or state.next_recovery_t > (t or 0) then
        return
    end

    state.next_recovery_t = (t or 0) + 5.0

    if not state.smart_tag_system or #state.minion_order <= 0 then
        return
    end

    local last_order = state.last_noosphere_order_t or -999
    if last_order > -900 and (t or 0) - last_order < 8.0 then
        return
    end

    clear_pending_noosphere()
    state.noosphere_candidate_unit = nil
    state.noosphere_candidate_until = 0
    state.timers.noosphere = 0
    state.timers.auto_ping_scan = 0
    state.visibility_cache = {}
    state.visibility_frame = {}
    debug_print("auto ping soft recovery")
end

local function run_smart_pox_logic(t, fixed_frame)
    if not settings.auto_ping_enabled or not settings.smart_pox_enabled or state.timers.noosphere > 0 then
        return false
    end

    if noosphere_order_pending(t) then
        return false
    end

    local target_unit = find_smart_pox_target(fixed_frame)
    if not target_unit then
        return false
    end

    local template_name = companion_template_for(target_unit, SERVO_ENEMY_TAG)
    if template_name then
        if state.companion_burst and reason_is_task_order(state.companion_burst.reason) then
            state.companion_burst = nil
        end
        return order_noosphere(template_name, target_unit, "smart_pox", t)
    end

    return false
end

local function run_noosphere_logic(t, fixed_frame)
    if not settings.auto_ping_enabled or (not settings.noosphere_enabled and not settings.smart_pox_enabled) then
        state.noosphere_candidate_unit = nil
        state.noosphere_candidate_until = 0
        clear_pending_noosphere()
        return false
    end

    if noosphere_order_pending(t) then
        return false
    end

    disengage_unsafe_pox_target(fixed_frame)

    if state.last_servo_enemy_unit and not target_ready_for_smart_tag(state.last_servo_enemy_unit) then
        state.last_servo_enemy_unit = nil
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
    end

    if state.last_servo_enemy_unit and not hold_target_ready(state.last_servo_enemy_unit, fixed_frame) then
        if state.noosphere_candidate_unit == state.last_servo_enemy_unit then
            state.noosphere_candidate_unit = nil
            state.noosphere_candidate_until = 0
        end

        state.last_servo_enemy_unit = nil
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
    end

    local held_unit = held_noosphere_target(fixed_frame)
    local watchdog_expired = held_unit
        and state.last_noosphere_order_t
        and state.last_noosphere_order_t > -900
        and (t or 0) - state.last_noosphere_order_t >= 2.00

    if watchdog_expired then
        state.timers.noosphere = 0
        state.timers.auto_ping_scan = 0
    end

    if state.timers.noosphere > 0
        and settings.noosphere_enabled
        and settings.noosphere_trapper_max_priority
    then
        local trapper_unit = find_best_trapper(settings.noosphere_max_range, fixed_frame)
        if trapper_unit and trapper_unit ~= state.last_servo_enemy_unit then
            local trapper_template = companion_template_for(trapper_unit, SERVO_ENEMY_TAG)
            remember_interrupted_normal_target(t, fixed_frame)
            if trapper_template and order_noosphere(trapper_template, trapper_unit, "noosphere", t) then
                return true
            end
        end

        local pox_unit = find_smart_pox_target(fixed_frame)
        if pox_unit and pox_unit ~= state.last_servo_enemy_unit then
            local pox_template = companion_template_for(pox_unit, SERVO_ENEMY_TAG)
            remember_interrupted_normal_target(t, fixed_frame)
            if pox_template and order_noosphere(pox_template, pox_unit, "smart_pox", t) then
                return true
            end
        end
    end

    if state.timers.noosphere > 0 then
        return false
    end

    local target_unit = choose_noosphere_target(t, fixed_frame)

    if not target_unit then
        state.timers.noosphere = 0.05
        return false
    end

    local template_name = companion_template_for(target_unit, SERVO_ENEMY_TAG)
    if template_name then
        return order_noosphere(template_name, target_unit, "noosphere", t)
    end

    state.noosphere_candidate_unit = nil
    state.noosphere_candidate_until = 0
    state.timers.noosphere = 0.05
    return false
end

local function logic_tick(dt, t, fixed_frame)
    decrement_timers(dt)
    maybe_refresh_context(dt)

    if not player_ready() then
        return
    end

    prune_visibility_cache(fixed_frame)

    if dt and dt > 0.25 then
        state.companion_burst = nil
        state.timers.task = math.max(state.timers.task or 0, 1.0)
        state.timers.auto_ping_scan = math.max(state.timers.auto_ping_scan or 0, 0.25)
        debug_print("stability hitch guard", tostring(dt))
        return
    end

    if Managers and Managers.ui and Managers.ui.using_input and Managers.ui:using_input() then
        return
    end

    recover_auto_ping_if_stalled(t)
    run_alert_hud(t, fixed_frame)

    if run_companion_burst(t) then
        return
    end

    local task_ordered = run_task_logic(t, fixed_frame)
    if task_ordered then
        return
    end

    if run_noosphere_logic(t, fixed_frame) then
        return
    end

    if run_smart_pox_logic(t, fixed_frame) then
        return
    end
end

mod.toggle_mod = function()
    local next_value = not settings.toggle_mod
    mod:set("toggle_mod", next_value, true)
    settings.toggle_mod = next_value
    notify(next_value and "enabled" or "disabled")
end

mod.on_enabled = function()
    state.mod_runtime_enabled = true
    refresh_settings()
end

mod.on_disabled = function()
    state.mod_runtime_enabled = false
    clear_transient_state()
end

mod.on_setting_changed = function()
    refresh_settings()
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            init_context()
        elseif status == "exit" then
            state.game_mode_valid = false
            clear_transient_state()
        end
    end
end

refresh_settings()


mod:hook_safe(CLASS.HumanPlayer, "init", function(self)
    if self.viewport_name == "player1" then
        state.player = self
        state.player_unit = get_player_unit(self)
        state.class_name = get_player_archetype(self)
        refresh_player(self)
    end
end)

mod:hook_safe(CLASS.HumanPlayer, "destroy", function(self)
    if self.viewport_name == "player1" then
        state.player = nil
        state.player_unit = nil
        clear_transient_state()
    end
end)

mod:hook_safe(CLASS.HumanPlayer, "set_profile", function(self)
    if self.viewport_name == "player1" then
        state.class_name = get_player_archetype(self)
        refresh_player(self)
    end
end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "init", function(self)
    if self._player and self._player.viewport_name == "player1" then
        state.smart_targeting_extension = self
        set_physics_world(self._physics_world)
        ensure_visibility_raycast()
    end
end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "delete", function(self)
    if self._player and self._player.viewport_name == "player1" then
        state.smart_targeting_extension = nil
        set_physics_world(nil)
    end
end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "fixed_update", function(self, unit, dt, t, fixed_frame)
    if self._player and self._player.viewport_name == "player1" then
        state.smart_targeting_extension = self
        set_physics_world(self._physics_world)
        logic_tick(dt, t, fixed_frame)
    end
end)

mod:hook_safe(CLASS.PlayerUnitTalentExtension, "_apply_talents", function(self)
    if self._player and self._player.viewport_name == "player1" then
        state.player_talent_extension = self
        refresh_player(self._player)
    end
end)

mod:hook_safe(CLASS.PlayerHuskTalentExtension, "_update_talents", function(self)
    if self._player and self._player.viewport_name == "player1" then
        refresh_player(self._player)
    end
end)

mod:hook_safe(CLASS.SmartTagSystem, "init", function(self)
    state.smart_tag_system = self
end)

mod:hook_safe(CLASS.SmartTagSystem, "destroy", function()
    state.smart_tag_system = nil
end)

mod:hook(CLASS.SmartTagSystem, "on_remove_extension", function(func, self, unit, extension_name)
    if extension_name == "SmartTagExtension" then
        local unit_extension_data = self and self._unit_extension_data
        sanitize_owned_tag_ids(self, unit_extension_data and unit_extension_data[unit])
    end

    local results = { pcall(func, self, unit, extension_name) }
    local ok = results[1]
    if ok then
        return unpack(results, 2)
    end

    local error_text = tostring(results[2])
    if extension_name == "SmartTagExtension"
        and string.find(error_text, "attempt to index a nil value", 1, true)
    then
        debug_print("suppressed stale smart tag extension removal", tostring(unit))
        return nil
    end

    error(error_text)
end)

mod:hook(CLASS.SmartTagSystem, "_remove_tag_locally", function(func, self, tag_id, reason)
    local tag = self and self._all_tags and self._all_tags[tag_id]
    local target_unit = tag and tag._target_unit
    local unit_extension_data = self and self._unit_extension_data
    local target_extension = target_unit and unit_extension_data and unit_extension_data[target_unit]
    local template = tag and tag._template
    local template_name = template and template.name
    local is_mechanica_servo_tag = template_name == SERVO_ENEMY_TAG
        or target_unit == state.last_servo_enemy_unit
        or target_unit == state.sticky_enemy_unit
        or target_unit == state.noosphere_candidate_unit

    if tag and target_unit and not target_extension and is_mechanica_servo_tag then
        debug_print("safe remove stale servo tag", tostring(tag_id), tostring(reason))
        clear_smart_tag_entry(self, tag_id, tag)
        remove_minion(target_unit)
        return
    end

    return func(self, tag_id, reason)
end)

mod:hook(CLASS.SmartTagSystem, "set_contextual_unit_tag", function(func, self, tagger_unit, target_unit, alternate)
    if state.player_unit and tagger_unit == state.player_unit then
        local unit_extension_data = self and self._unit_extension_data
        local target_extension = unit_extension_data and unit_extension_data[target_unit]
        local template_name = target_extension and safe_call(target_extension, "_contextual_tag_template_name", tagger_unit, alternate)
        if alternate == COMPANION_ORDER and player_ready() then
            debug_print("manual companion template", template_name or "nil")
            remember_contextual_task_target(target_unit, template_name, gameplay_time())
        end

        if template_name == SERVO_ENEMY_TAG and (state.self_issued_until <= 0 or gameplay_time() > state.self_issued_until) then
            track_manual_enemy_order(target_unit)
        end
    end

    return func(self, tagger_unit, target_unit, alternate)
end)

mod:hook(CLASS.SmartTagSystem, "trigger_tag_interaction", function(func, self, tag_id, interactor_unit, target_unit, optional_alternate)
    if state.player_unit and interactor_unit == state.player_unit then
        local unit_extension_data = self and self._unit_extension_data
        local target_extension = unit_extension_data and unit_extension_data[target_unit]
        local template_name = target_extension and safe_call(target_extension, "_contextual_tag_template_name", interactor_unit, optional_alternate)
        if optional_alternate == COMPANION_ORDER and player_ready() then
            debug_print("manual companion interaction", template_name or "nil")
            remember_contextual_task_target(target_unit, template_name, gameplay_time())
        end
        if template_name == SERVO_ENEMY_TAG and (state.self_issued_until <= 0 or gameplay_time() > state.self_issued_until) then
            track_manual_enemy_order(target_unit)
        end
    end

    return func(self, tag_id, interactor_unit, target_unit, optional_alternate)
end)

mod:hook(CLASS.SmartTagSystem, "set_tag", function(func, self, template_name, tagger_unit, target_unit, ...)
    if state.player_unit
        and tagger_unit == state.player_unit
        and template_name == SERVO_ENEMY_TAG
        and target_unit
        and not target_ready_for_smart_tag(target_unit)
    then
        remove_minion(target_unit)
        return false
    end

    local result = func(self, template_name, tagger_unit, target_unit, ...)

    if state.player_unit
        and tagger_unit == state.player_unit
        and target_unit
        and target_ready_for_smart_tag(target_unit)
        and is_enemy_unit(target_unit)
    then
        if template_name == SERVO_ENEMY_TAG and (state.self_issued_until <= 0 or gameplay_time() > state.self_issued_until) then
            track_manual_enemy_order(target_unit)
        end
    end

    return result
end)

mod:hook_safe(CLASS.SmartTag, "init", function(self, tag_id, template, tagger_unit, target_unit)
    local tagger_player = self._tagger_player
    if tagger_player and tagger_player.viewport_name == "player1" and template and template.name == SERVO_ENEMY_TAG and player_ready() then
        state.last_servo_enemy_unit = target_unit
        if target_unit
            and is_enemy_unit(target_unit)
            and not is_pox_bomb(target_unit)
            and settings.auto_ping_enabled
            and settings.noosphere_sticky_manual_target
            and gameplay_time() > state.self_issued_until
        then
            state.sticky_enemy_unit = target_unit
        end
    end
end)

mod:hook_safe(CLASS.HudElementSmartTagging, "init", function(self)
    if self._parent and self._parent._player_viewport_name == "player1" then
        state.hud_element_smart_tagging = self
    end
end)

mod:hook_safe(CLASS.HudElementSmartTagging, "destroy", function(self)
    if state.hud_element_smart_tagging == self then
        state.hud_element_smart_tagging = nil
    end
end)

mod:hook_safe("HealthExtension", "init", function(_, _, unit)
    add_minion(unit)
end)

mod:hook_safe("HuskHealthExtension", "init", function(_, _, unit)
    add_minion(unit)
end)

mod:hook_safe("HealthExtension", "kill", function(self)
    remove_minion(self and self._unit)
end)

mod:hook_safe("HuskHealthExtension", "kill", function(self)
    remove_minion(self and self._unit)
end)

mod:hook_safe("MinionDeathManager", "set_dead", function(_, unit)
    remove_minion(unit)
end)

mod:hook_safe("MinionSpawnManager", "unregister_unit", function(_, unit)
    remove_minion(unit)
end)

mod:hook_safe("UnitSpawnerManager", "mark_for_deletion", function(_, unit)
    remove_minion(unit)
end)
