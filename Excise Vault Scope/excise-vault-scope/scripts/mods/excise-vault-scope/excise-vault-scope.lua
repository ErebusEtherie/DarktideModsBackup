-- excise-vault-scope.lua
local mod = get_mod("excise-vault-scope")

local TARGET_MISSION_ID = "lm_scavenge"
local OBJECTIVES = {
    decrypt = "objective_lm_scavenge_decrypt",
    proceed_hangars = "objective_lm_scavenge_proceed_hangars",
    reach_vault = "objective_lm_scavenge_reach_vault",
    interact_vaults_panel = "objective_lm_scavenge_interact_vaults_panel",
    deposit = "objective_lm_scavenge_deposit_assets",
    send_assets = "objective_lm_scavenge_send_assets",
    extraction = "objective_lm_scavenge_escape",
}
local MARKER_TYPES = {
    casket = "excise_vault_scope_marker",
    button = "excise_vault_scope_button_marker",
    midevent = "excise_vault_scope_mid_event_marker",
}
local COLOURS = {
    casket = { 255, 247, 158, 13 },
    button = { 255, 100, 172, 28 },
    midevent_setup = { 255, 161, 174, 155 },
    midevent_restart = { 255, 234, 47, 40 },
    shadow = { 200, 0, 0, 0 },
}
local DISTANCE_VALUES = {
    Near = 20,
    Far = 150,
}
local SIZE_FONT_SIZES = {
    Small = 65,
    Medium = 100,
    Large = 150,
}
local DEFAULT_CASKET_TEXT = ""
local COUNTDOWN_TEXT_3 = ""
local COUNTDOWN_TEXT_2 = ""
local COUNTDOWN_TEXT_1 = ""
local LEVEL_UP_ARROW_TEXT = ""
local LEVEL_DOWN_ARROW_TEXT = ""
local PENDING_MARKER = "pending"
local FLOOR_Z_SPLIT_MIN_GAP = 6
local LIVE_SCAN_INTERVAL_FRAMES = 15
local OBJECTIVE_SYNC_INTERVAL_FRAMES = 30

local settings_normalised = false
local cached_countdown_enabled = false
local cached_marker_font_size = SIZE_FONT_SIZES.Medium
local cached_marker_max_distance = DISTANCE_VALUES.Far
local cached_casket_level_font_size = math.max(24, math.floor(SIZE_FONT_SIZES.Medium * 0.6))
local cached_casket_level_offset = math.max(36, math.floor(SIZE_FONT_SIZES.Medium * 0.85))

local mission_is_target = false
local mission_authoritatively_non_target = false
local world_markers_instance = nil
local refresh_requested = false
local live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
local objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES

local tracked_units = {}
local casket_marker_ids = {}
local casket_marker_pending_frames = {}
local tracked_casket_spawn_z = {}
local tracked_casket_floor = {}
local tracked_casket_show_level = {}
local remaining_caskets = 0
local delivered_caskets = 0
local observed_casket_spawn_z_min = nil
local observed_casket_spawn_z_max = nil
local floor_threshold_z = nil

local clear_tracking_units = {}
local clear_remaining_units = {}
local socketed_units_scratch = {}
local tracked_remove_units = {}
local refresh_marker_units = {}
local update_marker_units = {}

local endevent = nil
local midevent = nil
local core = {}

local function refresh_cached_settings()
    local marker_size = mod:get("marker_size") or "Medium"
    local marker_max_distance = mod:get("marker_max_distance") or "Far"

    cached_countdown_enabled = mod:get("countdown") == true
    cached_marker_font_size = SIZE_FONT_SIZES[marker_size] or SIZE_FONT_SIZES.Medium
    cached_marker_max_distance = DISTANCE_VALUES[marker_max_distance] or DISTANCE_VALUES.Far
    cached_casket_level_font_size = math.max(24, math.floor(cached_marker_font_size * 0.6))
    cached_casket_level_offset = math.max(36, math.floor(cached_marker_font_size * 0.85))
end

local function normalise_saved_settings_once()
    if settings_normalised then
        return
    end

    settings_normalised = true

    local changed = false
    local size = mod:get("marker_size")

    if size == nil or size == "N/A" then
        mod:set("marker_size", "Medium")
        changed = true
    elseif size == "Normal" then
        mod:set("marker_size", "Small")
        changed = true
    elseif size == "Double" then
        mod:set("marker_size", "Medium")
        changed = true
    elseif size == "Triple" then
        mod:set("marker_size", "Large")
        changed = true
    end

    local distance = mod:get("marker_max_distance")

    if distance == nil or distance == "N/A" or distance == "Middling" then
        mod:set("marker_max_distance", "Far")
        changed = true
    end

    if mod:get("countdown") == nil then
        mod:set("countdown", false)
        changed = true
    end


    if changed and mod.save then
        pcall(mod.save, mod)
    end

    refresh_cached_settings()
end

local function is_valid_unit(unit)
    return unit ~= nil and ALIVE and ALIVE[unit]
end

local function is_finite_number(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function unit_world_position(unit)
    if not is_valid_unit(unit) then
        return nil
    end

    return Unit.world_position(unit, 1)
end

local function unit_world_z(unit)
    local position = unit_world_position(unit)

    if not position then
        return nil
    end

    local z = position.z or position[3]

    return is_finite_number(z) and z or nil
end

local function extension_system_unit_map(system_name)
    local state_manager = Managers and Managers.state
    local extension_manager = state_manager and state_manager.extension
    local system_function = extension_manager and extension_manager.system

    if type(system_function) ~= "function" then
        return nil
    end

    local ok, system = pcall(system_function, extension_manager, system_name)

    if not ok or not system then
        return nil
    end

    local unit_map_function = system.unit_to_extension_map

    if type(unit_map_function) == "function" then
        local map_ok, unit_map = pcall(unit_map_function, system)

        if map_ok and type(unit_map) == "table" then
            return unit_map
        end
    end

    return type(system._unit_to_extension_map) == "table" and system._unit_to_extension_map or nil
end

local function mission_objective_system()
    local state_manager = Managers and Managers.state
    local extension_manager = state_manager and state_manager.extension
    local system_function = extension_manager and extension_manager.system

    if type(system_function) ~= "function" then
        return nil
    end

    local ok, system = pcall(system_function, extension_manager, "mission_objective_system")

    return ok and system or nil
end

local function active_mission_objective(objective_name)
    local system = mission_objective_system()
    local active_objective_function = system and system.active_objective

    if type(active_objective_function) ~= "function" then
        return nil
    end

    local ok, objective = pcall(active_objective_function, system, objective_name)

    return ok and objective or nil
end

local function objective_incremented_progression(objective_name)
    local objective = active_mission_objective(objective_name)
    local progression_function = objective and objective.incremented_progression

    if type(progression_function) ~= "function" then
        return nil
    end

    local ok, progression = pcall(progression_function, objective)

    return ok and type(progression) == "number" and progression or nil
end

local function get_world_markers_element()
    if world_markers_instance then
        return world_markers_instance
    end

    local ui_manager = Managers and Managers.ui
    local hud = ui_manager and ui_manager:get_hud()

    return hud and hud:element("HudElementWorldMarkers") or nil
end

local function clear_casket_marker_handles()
    table.clear(casket_marker_ids)
    table.clear(casket_marker_pending_frames)
end

local function adopt_world_markers_instance(world_markers)
    if not world_markers or world_markers_instance == world_markers then
        return
    end

    world_markers_instance = world_markers
    clear_casket_marker_handles()

    if endevent then
        endevent.clear_marker_handles()
    end

    if midevent then
        midevent.clear_marker_handles()
    end

    if mission_is_target then
        refresh_requested = true
    end
end

local function marker_id_is_live(marker_id, marker_type, owner_unit)
    if not marker_id or marker_id == PENDING_MARKER then
        return false
    end

    local world_markers = get_world_markers_element() or world_markers_instance

    if not world_markers or world_markers ~= world_markers_instance then
        return false
    end

    local markers_by_id = world_markers._markers_by_id
    local marker = markers_by_id and markers_by_id[marker_id]

    if not marker or marker_type and marker.type ~= marker_type then
        return false
    end

    if owner_unit then
        local marker_owner = marker.unit or marker.data and marker.data.owner_unit

        if marker_owner ~= owner_unit then
            return false
        end
    end

    return true
end

local function find_live_marker_id(marker_type, owner_unit)
    local world_markers = get_world_markers_element() or world_markers_instance
    local markers_by_type = world_markers and world_markers._markers_by_type
    local markers = markers_by_type and markers_by_type[marker_type]

    if not markers then
        return nil
    end

    for i = 1, #markers do
        local marker = markers[i]
        local marker_owner = marker.unit or marker.data and marker.data.owner_unit

        if marker_owner == owner_unit and not marker.deleted and not marker.remove then
            return marker.id
        end
    end

    return nil
end

local marker_removal_ids = {}

local function remove_live_markers(marker_type, owner_unit)
    local world_markers = get_world_markers_element() or world_markers_instance
    local markers_by_type = world_markers and world_markers._markers_by_type
    local markers = markers_by_type and markers_by_type[marker_type]

    table.clear(marker_removal_ids)

    if not markers then
        return
    end

    for i = 1, #markers do
        local marker = markers[i]
        local marker_owner = marker.unit or marker.data and marker.data.owner_unit

        if marker_owner == owner_unit and marker.id and not marker.deleted and not marker.remove then
            marker_removal_ids[#marker_removal_ids + 1] = marker.id
        end
    end

    for i = 1, #marker_removal_ids do
        Managers.event:trigger("remove_world_marker", marker_removal_ids[i])
    end
end

local function ensure_marker_template(marker_type, create_template, world_markers)
    if not mission_is_target then
        return false
    end

    world_markers = world_markers or get_world_markers_element() or world_markers_instance

    if not world_markers or not world_markers._marker_templates then
        return false
    end

    adopt_world_markers_instance(world_markers)

    local template = world_markers._marker_templates[marker_type]

    if type(template) ~= "table" or template._excise_vault_scope_marker_type ~= marker_type then
        local ok, replacement = pcall(create_template)

        if not ok or type(replacement) ~= "table" then
            return false
        end

        replacement._excise_vault_scope_marker_type = marker_type
        world_markers._marker_templates[marker_type] = replacement
    end

    return true
end

local function get_luggable_extension(unit)
    if not is_valid_unit(unit) then
        return nil
    end

    return ScriptUnit.has_extension(unit, "luggable_system")
end

local function is_casket_currently_carried(unit)
    local extension = get_luggable_extension(unit)

    if not extension then
        return false
    end

    local carried_function = extension.is_currently_carried

    if type(carried_function) == "function" then
        local ok, carried = pcall(carried_function, extension)

        if ok then
            return carried == true
        end
    end

    return extension._carrier_player_unit ~= nil
end

local function is_container_casket(unit)
    if not is_valid_unit(unit) or not Unit.has_data(unit, "pickup_type") then
        return false
    end

    return Unit.get_data(unit, "pickup_type") == "container_01_luggable"
end

local function casket_level_font_size()
    return cached_casket_level_font_size
end

local function casket_level_offset()
    return cached_casket_level_offset
end

local function clear_casket_level_data(unit)
    tracked_casket_spawn_z[unit] = nil
    tracked_casket_floor[unit] = nil
    tracked_casket_show_level[unit] = nil
end

local function update_floor_threshold_from_spawn_z(spawn_z)
    if not is_finite_number(spawn_z) then
        return false
    end

    observed_casket_spawn_z_min = observed_casket_spawn_z_min and math.min(observed_casket_spawn_z_min, spawn_z) or spawn_z
    observed_casket_spawn_z_max = observed_casket_spawn_z_max and math.max(observed_casket_spawn_z_max, spawn_z) or spawn_z

    local old_threshold_z = floor_threshold_z

    if observed_casket_spawn_z_min and observed_casket_spawn_z_max and observed_casket_spawn_z_max - observed_casket_spawn_z_min >= FLOOR_Z_SPLIT_MIN_GAP then
        floor_threshold_z = (observed_casket_spawn_z_min + observed_casket_spawn_z_max) * 0.5
    end

    return floor_threshold_z ~= old_threshold_z
end

local function classify_tracked_casket_floor(unit)
    if not tracked_units[unit] or not floor_threshold_z then
        return
    end

    local spawn_z = tracked_casket_spawn_z[unit]

    if is_finite_number(spawn_z) then
        tracked_casket_floor[unit] = spawn_z > floor_threshold_z and "upper" or "lower"
    end
end

local function classify_all_tracked_casket_floors()
    if not floor_threshold_z then
        return
    end

    for unit, _ in pairs(tracked_units) do
        classify_tracked_casket_floor(unit)
    end
end

local function current_casket_level_text(unit)
    if not tracked_units[unit] or tracked_casket_show_level[unit] == false then
        return "", ""
    end

    if is_casket_currently_carried(unit) then
        tracked_casket_show_level[unit] = false
        return "", ""
    end

    local floor = tracked_casket_floor[unit]

    if floor == "upper" then
        return LEVEL_UP_ARROW_TEXT, ""
    elseif floor == "lower" then
        return "", LEVEL_DOWN_ARROW_TEXT
    end

    return "", ""
end

local function current_casket_marker_text()
    if not cached_countdown_enabled then
        return DEFAULT_CASKET_TEXT
    end

    if remaining_caskets >= 3 then
        return COUNTDOWN_TEXT_3
    elseif remaining_caskets == 2 then
        return COUNTDOWN_TEXT_2
    elseif remaining_caskets == 1 then
        return COUNTDOWN_TEXT_1
    end

    return DEFAULT_CASKET_TEXT
end

local function remove_casket_marker(unit)
    remove_live_markers(MARKER_TYPES.casket, unit)
    casket_marker_ids[unit] = nil
    casket_marker_pending_frames[unit] = nil
end

local function request_casket_marker(unit)
    if not tracked_units[unit] or not endevent.ensure_casket_template() then
        return
    end

    local marker_id = casket_marker_ids[unit]

    if marker_id == PENDING_MARKER then
        local recovered_id = find_live_marker_id(MARKER_TYPES.casket, unit)

        if recovered_id then
            casket_marker_ids[unit] = recovered_id
            casket_marker_pending_frames[unit] = nil
        end

        return
    end

    if marker_id_is_live(marker_id, MARKER_TYPES.casket, unit) then
        casket_marker_pending_frames[unit] = nil
        return
    end

    local recovered_id = find_live_marker_id(MARKER_TYPES.casket, unit)

    if recovered_id then
        casket_marker_ids[unit] = recovered_id
        casket_marker_pending_frames[unit] = nil
        return
    end

    casket_marker_ids[unit] = PENDING_MARKER
    casket_marker_pending_frames[unit] = 0

    Managers.event:trigger("add_world_marker_unit", MARKER_TYPES.casket, unit, function(new_marker_id)
        if casket_marker_ids[unit] == PENDING_MARKER then
            casket_marker_ids[unit] = new_marker_id
            casket_marker_pending_frames[unit] = nil
        end
    end, { owner_unit = unit })
end

local function update_pending_casket_marker(unit)
    local marker_id = casket_marker_ids[unit]

    if marker_id == PENDING_MARKER then
        local recovered_id = find_live_marker_id(MARKER_TYPES.casket, unit)

        if recovered_id then
            casket_marker_ids[unit] = recovered_id
            casket_marker_pending_frames[unit] = nil
            return
        end

        local pending_frames = (casket_marker_pending_frames[unit] or 0) + 1

        casket_marker_pending_frames[unit] = pending_frames

        if pending_frames >= 30 then
            casket_marker_ids[unit] = nil
            casket_marker_pending_frames[unit] = nil
        end
    elseif marker_id and not marker_id_is_live(marker_id, MARKER_TYPES.casket, unit) then
        casket_marker_ids[unit] = nil
        casket_marker_pending_frames[unit] = nil
    end
end

local function clear_casket_tracking()
    table.clear(clear_tracking_units)

    for unit, _ in pairs(tracked_units) do
        clear_tracking_units[#clear_tracking_units + 1] = unit
    end

    for i = 1, #clear_tracking_units do
        remove_casket_marker(clear_tracking_units[i])
    end

    table.clear(tracked_units)
    table.clear(casket_marker_ids)
    table.clear(casket_marker_pending_frames)
    table.clear(tracked_casket_spawn_z)
    table.clear(tracked_casket_floor)
    table.clear(tracked_casket_show_level)
    remaining_caskets = 0
    delivered_caskets = 0
    observed_casket_spawn_z_min = nil
    observed_casket_spawn_z_max = nil
    floor_threshold_z = nil
end

local function track_casket(unit)
    if tracked_units[unit] or not is_container_casket(unit) then
        return
    end

    tracked_units[unit] = true
    tracked_casket_spawn_z[unit] = unit_world_z(unit)
    tracked_casket_show_level[unit] = true
    remaining_caskets = remaining_caskets + 1

    local threshold_changed = update_floor_threshold_from_spawn_z(tracked_casket_spawn_z[unit])

    classify_tracked_casket_floor(unit)

    if threshold_changed then
        classify_all_tracked_casket_floors()
    end

    refresh_requested = true
end

local function untrack_casket(unit)
    if not tracked_units[unit] then
        return
    end

    remove_casket_marker(unit)
    tracked_units[unit] = nil
    clear_casket_level_data(unit)
    remaining_caskets = math.max(0, remaining_caskets - 1)
end

local function clear_remaining_caskets()
    table.clear(clear_remaining_units)

    for unit, _ in pairs(tracked_units) do
        clear_remaining_units[#clear_remaining_units + 1] = unit
    end

    for i = 1, #clear_remaining_units do
        untrack_casket(clear_remaining_units[i])
    end
end

local function mark_casket_delivered(unit)
    if not tracked_units[unit] then
        return
    end

    remove_casket_marker(unit)
    tracked_units[unit] = nil
    clear_casket_level_data(unit)
    remaining_caskets = math.max(0, remaining_caskets - 1)
    delivered_caskets = math.min(3, delivered_caskets + 1)

    if delivered_caskets >= 3 and endevent then
        endevent.begin_final_button()
    end

    refresh_requested = true
end

local function socketed_casket_units()
    local socket_map = extension_system_unit_map("luggable_socket_system")
    local socketed_units = socketed_units_scratch
    local socketed_count = 0

    table.clear(socketed_units)

    if not socket_map then
        return socketed_units, socketed_count, false
    end

    for _, extension in pairs(socket_map) do
        local socketed_unit_function = extension and extension.socketed_unit

        if type(socketed_unit_function) == "function" then
            local ok, unit = pcall(socketed_unit_function, extension)

            if ok and is_container_casket(unit) and not socketed_units[unit] then
                socketed_units[unit] = true
                socketed_count = socketed_count + 1
            end
        end
    end

    return socketed_units, socketed_count, true
end

local function scan_existing_casket_units()
    if not mission_is_target then
        return false
    end

    if delivered_caskets >= 3 or active_mission_objective(OBJECTIVES.send_assets) or active_mission_objective(OBJECTIVES.extraction) then
        clear_remaining_caskets()
        return true
    end

    local unit_to_extension_map = extension_system_unit_map("luggable_system")

    if not unit_to_extension_map then
        return false
    end

    local socketed_units, socketed_count, sockets_scanned = socketed_casket_units()

    if sockets_scanned then
        delivered_caskets = math.max(delivered_caskets, math.min(3, socketed_count))
    end

    table.clear(tracked_remove_units)

    for unit, _ in pairs(tracked_units) do
        if not is_container_casket(unit) or socketed_units[unit] then
            tracked_remove_units[#tracked_remove_units + 1] = unit
        end
    end

    for i = 1, #tracked_remove_units do
        untrack_casket(tracked_remove_units[i])
    end

    for unit, _ in pairs(unit_to_extension_map) do
        if is_container_casket(unit) and not socketed_units[unit] then
            track_casket(unit)
        end
    end

    if delivered_caskets >= 3 and endevent then
        endevent.begin_final_button()
    end

    return true
end

local function refresh_casket_markers()
    table.clear(refresh_marker_units)

    for unit, _ in pairs(tracked_units) do
        refresh_marker_units[#refresh_marker_units + 1] = unit
    end

    for i = 1, #refresh_marker_units do
        remove_casket_marker(refresh_marker_units[i])
    end

    for i = 1, #refresh_marker_units do
        local unit = refresh_marker_units[i]

        if is_container_casket(unit) then
            request_casket_marker(unit)
        else
            untrack_casket(unit)
        end
    end
end

local function update_casket_markers()
    table.clear(update_marker_units)

    for unit, _ in pairs(tracked_units) do
        update_marker_units[#update_marker_units + 1] = unit
    end

    for i = 1, #update_marker_units do
        local unit = update_marker_units[i]

        if is_container_casket(unit) then
            update_pending_casket_marker(unit)
            request_casket_marker(unit)
        else
            untrack_casket(unit)
        end
    end
end

local function mission_name_from_params(params)
    if type(params) ~= "table" then
        return nil
    end

    local mission_name = params.mission_name

    if type(mission_name) == "string" and mission_name ~= "" then
        return mission_name
    end

    local mechanism_data = params.mechanism_data

    if type(mechanism_data) == "table" and type(mechanism_data.mission_name) == "string" and mechanism_data.mission_name ~= "" then
        return mechanism_data.mission_name
    end

    return nil
end

local function mission_name_from_manager()
    local state_manager = Managers and Managers.state
    local mission_manager = state_manager and state_manager.mission
    local mission_name_function = mission_manager and mission_manager.mission_name

    if type(mission_name_function) ~= "function" then
        return nil
    end

    local ok, mission_name = pcall(mission_name_function, mission_manager)

    return ok and type(mission_name) == "string" and mission_name ~= "" and mission_name or nil
end

local function mission_name_from_mechanism()
    local mechanism_manager = Managers and Managers.mechanism
    local mechanism_data_function = mechanism_manager and mechanism_manager.mechanism_data

    if type(mechanism_data_function) ~= "function" then
        return nil
    end

    local ok, mechanism_data = pcall(mechanism_data_function, mechanism_manager)

    if ok and type(mechanism_data) == "table" and type(mechanism_data.mission_name) == "string" and mechanism_data.mission_name ~= "" then
        return mechanism_data.mission_name
    end

    return nil
end

local function target_objective_definition_loaded()
    local system = mission_objective_system()
    local definition_function = system and system.objective_definition

    if type(definition_function) ~= "function" then
        return false
    end

    local ok, definition = pcall(definition_function, system, OBJECTIVES.deposit)

    return ok and definition ~= nil
end

local function is_excise_objective_name(objective_name)
    return type(objective_name) == "string" and string.find(objective_name, "^objective_lm_scavenge_") ~= nil
end

local function reset_runtime_state()
    clear_casket_tracking()

    if endevent then
        endevent.reset()
    end

    if midevent then
        midevent.reset()
    end

    refresh_requested = false
    live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end

local function activate_target_mission()
    mission_authoritatively_non_target = false

    if not mission_is_target then
        reset_runtime_state()
        mission_is_target = true

        if endevent then
            endevent.on_mission_activated()
        end

        if midevent then
            midevent.on_mission_activated()
        end
    end

    refresh_requested = true
    live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end

local function deactivate_target_mission(authoritative)
    if mission_is_target then
        reset_runtime_state()
    end

    mission_is_target = false
end

local function detect_current_mission(params, authoritative)
    local mission_name = mission_name_from_params(params)

    if not mission_name then
        mission_name = mission_name_from_manager() or mission_name_from_mechanism()
    end

    if mission_name == TARGET_MISSION_ID or target_objective_definition_loaded() then
        activate_target_mission()
        return true
    end

    if authoritative and mission_name then
        mission_authoritatively_non_target = true
        deactivate_target_mission(true)
    elseif authoritative then
        mission_authoritatively_non_target = false
    elseif not mission_is_target then
    end

    return mission_is_target
end

local function sync_live_objective_state()
    if not mission_is_target then
        return false
    end

    local deposited = objective_incremented_progression(OBJECTIVES.deposit)

    if deposited then
        delivered_caskets = math.max(delivered_caskets, math.min(3, math.floor(deposited)))
    end

    if active_mission_objective(OBJECTIVES.send_assets) or active_mission_objective(OBJECTIVES.extraction) then
        delivered_caskets = math.max(delivered_caskets, 3)
    end

    if delivered_caskets >= 3 then
        clear_remaining_caskets()
    end

    if midevent then
        midevent.sync_objectives()
    end

    if endevent then
        endevent.sync_objectives(delivered_caskets)
    end

    return true
end

local function scan_live_mission_units()
    if not mission_is_target then
        return false
    end

    local caskets_scanned = scan_existing_casket_units()
    local midevent_scanned = not midevent or midevent.scan_live_units()

    return caskets_scanned and midevent_scanned
end

local function handle_objective_started(objective_name)
    if not is_excise_objective_name(objective_name) then
        return
    end

    activate_target_mission()

    if midevent then
        midevent.on_objective_started(objective_name)
    end

    if endevent then
        endevent.on_objective_started(objective_name, delivered_caskets)
    end

    scan_live_mission_units()
    sync_live_objective_state()
    refresh_requested = true
    live_scan_frames = 0
    objective_sync_frames = 0
end

core.mod = mod
core.objectives = OBJECTIVES
core.marker_types = MARKER_TYPES
core.colours = COLOURS
core.distance_values = DISTANCE_VALUES
core.pending_marker = PENDING_MARKER
core.is_target = function()
    return mission_is_target
end
core.is_valid_unit = is_valid_unit
core.unit_world_position = unit_world_position
core.extension_system_unit_map = extension_system_unit_map
core.mission_objective_system = mission_objective_system
core.active_mission_objective = active_mission_objective
core.marker_id_is_live = marker_id_is_live
core.find_live_marker_id = find_live_marker_id
core.remove_live_markers = remove_live_markers
core.ensure_marker_template = ensure_marker_template
core.request_refresh = function()
    refresh_requested = true
end
core.marker_font_size = function()
    return cached_marker_font_size
end
core.marker_max_distance = function()
    return cached_marker_max_distance
end
core.button_font_size = function()
    return SIZE_FONT_SIZES.Large
end
core.button_max_distance = function()
    return DISTANCE_VALUES.Far
end
core.is_casket = is_container_casket
core.is_casket_tracked = function(unit)
    return tracked_units[unit] == true
end
core.casket_marker_live = function(unit)
    return tracked_units[unit] and marker_id_is_live(casket_marker_ids[unit], MARKER_TYPES.casket, unit) or false
end
core.casket_level_font_size = casket_level_font_size
core.casket_level_offset = casket_level_offset
core.current_casket_marker_text = current_casket_marker_text
core.current_casket_level_text = current_casket_level_text

local manager_factory = mod:io_dofile("excise-vault-scope/scripts/mods/excise-vault-scope/excise-vault-scope_manager")
local midevent_factory = mod:io_dofile("excise-vault-scope/scripts/mods/excise-vault-scope/excise-vault-scope_midevent")

if type(manager_factory) ~= "function" or type(midevent_factory) ~= "function" then
    mod:error("Failed to load Excise Vault Scope modules")
    return
end

endevent = manager_factory(core)
midevent = midevent_factory(core, endevent)

if type(endevent) ~= "table" or type(midevent) ~= "table" then
    mod:error("Failed to initialise Excise Vault Scope modules")
    return
end

endevent.set_external_exclusion(function(unit)
    return midevent.owns_unit(unit)
end)

local function custom_marker_is_live_for_unit(unit)
    return unit ~= nil and (core.casket_marker_live(unit) or endevent.has_live_marker(unit) or midevent.has_live_marker(unit))
end

local function hide_default_markers_for_custom_units(markers_by_type)
    if not markers_by_type then
        return
    end

    for marker_type, markers in pairs(markers_by_type) do
        if marker_type ~= MARKER_TYPES.casket and marker_type ~= MARKER_TYPES.button and marker_type ~= MARKER_TYPES.midevent and type(markers) == "table" then
            for i = 1, #markers do
                local marker = markers[i]
                local unit = marker.unit

                if unit and custom_marker_is_live_for_unit(unit) then
                    marker.draw = false
                end
            end
        end
    end
end

local function apply_casket_draw_settings(markers_by_type)
    local markers = markers_by_type and markers_by_type[MARKER_TYPES.casket]

    if not markers then
        return
    end

    for i = 1, #markers do
        local marker = markers[i]

        marker.template.max_distance = cached_marker_max_distance
        marker.scale = 1
        marker.ignore_scale = true
        marker.draw = type(marker.distance) == "number" and marker.distance <= cached_marker_max_distance
    end
end

mod.on_all_mods_loaded = function()
    normalise_saved_settings_once()
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
    detect_current_mission(nil, false)
    adopt_world_markers_instance(self)

    if mission_is_target then
        endevent.ensure_casket_template(self)
        endevent.ensure_template(self)
        midevent.ensure_template(self)
        scan_live_mission_units()
        sync_live_objective_state()
        refresh_requested = true
    end
end)

mod:hook_safe(CLASS.HudElementWorldMarkers, "destroy", function(self)
    if world_markers_instance == self then
        world_markers_instance = nil
        clear_casket_marker_handles()
        endevent.clear_marker_handles()
        midevent.clear_marker_handles()

        if mission_is_target then
            refresh_requested = true
        end
    end
end)

mod:hook_safe(CLASS.StateGameplay, "on_enter", function(self, parent, params)
    detect_current_mission(params, true)

    if mission_is_target then
        scan_live_mission_units()
        sync_live_objective_state()
        refresh_requested = true
    end
end)

mod:hook_safe(CLASS.StateGameplay, "on_exit", function()
    deactivate_target_mission(true)
    world_markers_instance = nil
end)

mod:hook_safe(CLASS.HudElementWorldMarkers, "_calculate_markers", function(self)
    if not mission_is_target and not mission_authoritatively_non_target then
        detect_current_mission(nil, false)
    end

    if not mission_is_target then
        return
    end

    adopt_world_markers_instance(self)
    live_scan_frames = live_scan_frames + 1
    objective_sync_frames = objective_sync_frames + 1

    if live_scan_frames >= LIVE_SCAN_INTERVAL_FRAMES then
        scan_live_mission_units()
        live_scan_frames = 0
    end

    if objective_sync_frames >= OBJECTIVE_SYNC_INTERVAL_FRAMES and mission_objective_system() then
        sync_live_objective_state()
        objective_sync_frames = 0
    end

    endevent.ensure_casket_template(self)
    endevent.ensure_template(self)
    midevent.ensure_template(self)

    if refresh_requested then
        refresh_requested = false
        refresh_casket_markers()
        endevent.refresh()
        midevent.refresh()
    end

    update_casket_markers()

    local markers_by_type = self._markers_by_type
    local interaction_markers = markers_by_type and markers_by_type.interaction or nil

    endevent.update(interaction_markers)
    midevent.update(interaction_markers)
    hide_default_markers_for_custom_units(markers_by_type)
    apply_casket_draw_settings(markers_by_type)
    endevent.apply_draw_settings(markers_by_type)
    midevent.apply_draw_settings(markers_by_type)
end)

mod:hook_safe(CLASS.LuggableExtension, "init", function(self, extension_init_context, unit)
    if not mission_is_target and not mission_authoritatively_non_target then
        detect_current_mission(nil, false)
    end

    if mission_is_target and is_container_casket(unit) then
        track_casket(unit)
    end
end)

mod:hook_safe(CLASS.LuggableExtension, "set_carried_by", function(self, player_unit_or_nil)
    local unit = self._unit

    if mission_is_target and player_unit_or_nil and tracked_units[unit] then
        tracked_casket_show_level[unit] = false
        refresh_requested = true
    end
end)

mod:hook_safe(CLASS.LuggableExtension, "destroy", function(self)
    if mission_is_target and tracked_units[self._unit] then
        untrack_casket(self._unit)
    end
end)

mod:hook_safe(CLASS.LuggableSocketExtension, "socket_luggable", function(self, luggable_unit)
    if mission_is_target and tracked_units[luggable_unit] then
        mark_casket_delivered(luggable_unit)
    elseif mission_is_target then
        live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
        objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
    end
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "init", function(self, extension_init_context, unit)
    midevent.on_decoder_init(unit)
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "enable_unit", function(self)
    midevent.on_decoder_enabled(self._unit)
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "hot_join_sync", function(self, unit_is_enabled, is_placed, started_decode, decoding_interrupted, is_finished)
    self._is_finished = is_finished == true
    midevent.on_decoder_hot_join(self, unit_is_enabled, is_finished)
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "decoder_setup_success", function(self)
    midevent.on_decoder_state_changed(self._unit)
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "decode_interrupt", function(self)
    midevent.on_decoder_state_changed(self._unit)
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "finished", function(self)
    midevent.on_decoder_finished(self._unit)
end)

mod:hook_safe(CLASS.DoorControlPanelExtension, "toggle_door_state", function(self)
    endevent.on_door_state_changed(self._unit)
    midevent.on_door_state_changed(self._unit)
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end)

mod:hook_safe(CLASS.InteracteeExtension, "set_active", function(self, is_active)
    local unit = self._unit

    if mission_is_target and is_active == false and tracked_units[unit] then
        tracked_casket_show_level[unit] = false
        refresh_requested = true
    end

    endevent.on_interactee_active_changed(unit, is_active)
    midevent.on_interactee_active_changed(unit, is_active)
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end)

mod:hook_safe(CLASS.InteracteeExtension, "hot_join_setup", function(self, is_active)
    local unit = self._unit

    if mission_is_target and is_active == false and tracked_units[unit] then
        tracked_casket_show_level[unit] = false
        refresh_requested = true
    end
end)

mod:hook_safe(CLASS.Interactable, "interactable_set_used", function(self, unit)
    endevent.on_interactable_used(unit)
    midevent.on_interactable_used(unit)
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end)

mod:hook_safe(CLASS.Interactable, "interactable_disable", function(self, unit)
    endevent.on_interactable_disabled(unit)
    midevent.on_interactable_disabled(unit)
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end)

mod:hook_safe(CLASS.Interactable, "interactable_disable_local", function(self, unit)
    endevent.on_interactable_disabled(unit)
    midevent.on_interactable_disabled(unit)
    objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "hot_join_sync", function()
    if not mission_is_target and not mission_authoritatively_non_target then
        detect_current_mission(nil, false)
    end

    if mission_is_target then
        scan_live_mission_units()
        sync_live_objective_state()
        refresh_requested = true
        live_scan_frames = 0
        objective_sync_frames = 0
    end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "register_objective_unit", function(self, objective_name)
    if is_excise_objective_name(objective_name) then
        activate_target_mission()
        refresh_requested = true
        live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
        objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
    end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "add_marker", function(self, objective_name)
    if is_excise_objective_name(objective_name) then
        activate_target_mission()
        refresh_requested = true
        live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
        objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
    end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "remove_marker", function(self, objective_name)
    if is_excise_objective_name(objective_name) then
        activate_target_mission()
        refresh_requested = true
        live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
        objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
    end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "start_mission_objective", function(self, objective_name)
    handle_objective_started(objective_name)
end)

mod:hook_safe(CLASS.HudElementMissionObjectivePopup, "event_mission_objective_start", function(self, mission_objective)
    if type(mission_objective) == "string" then
        handle_objective_started(mission_objective)
        return
    end

    local name_function = mission_objective and mission_objective.name
    local ok, objective_name = type(name_function) == "function" and pcall(name_function, mission_objective) or false

    if ok then
        handle_objective_started(objective_name)
    end
end)

mod.on_setting_changed = function(setting_id)
    refresh_cached_settings()


    if mission_is_target then
        refresh_requested = true
        live_scan_frames = LIVE_SCAN_INTERVAL_FRAMES
        objective_sync_frames = OBJECTIVE_SYNC_INTERVAL_FRAMES
    end
end

mod.on_disabled = function()
    deactivate_target_mission(true)
end
