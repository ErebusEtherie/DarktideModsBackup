local mod = get_mod("emperor_vision")
local config = mod:io_dofile("emperor_vision/scripts/mods/emperor_vision/emperor_vision_config")

local OUTLINE_VISIBILITY_ENFORCE_INTERVAL_FRAMES = 30
local TRACKED_UNIT_UPDATE_INTERVAL_FRAMES = 5
local FULL_SCAN_INTERVAL_FRAMES = 30
local LOS_RECHECK_INTERVAL_FRAMES = 2
local MIN_SCAN_DISTANCE = 40
local MAX_SCAN_DISTANCE = 150
local DEFAULT_CUSTOM_OUTLINE_PRIORITY = 100
local LOS_BEHAVIOR_GLOBAL = config.LOS_BEHAVIOR_GLOBAL or "global"
local LOS_BEHAVIOR_ENABLED = config.LOS_BEHAVIOR_ENABLED or "enabled"
local LOS_BEHAVIOR_DISABLED = config.LOS_BEHAVIOR_DISABLED or "disabled"

local OUTLINE_MATERIAL_LAYERS = {
    "minion_outline",
}

local ALLY_SMART_TAG_OUTLINE_NAMES = {
    smart_tagged_enemy = true,
    smart_tagged_enemy_passive = true,
}

local VETERAN_SMART_TAG_OUTLINE_NAMES = {
    veteran_smart_tag = true,
}

local COMPANION_COMMAND_TAG_OUTLINE_NAMES = {
    adamant_smart_tag = true,
}

local outline_system = nil
local outline_settings_cache = nil

local unit_records = {}
local scan_results = {}

local force_outline_visibility = true
local require_line_of_sight = false
local preserve_custom_color_on_ally_tag = true
local preserve_custom_color_on_veteran_tag = true
local preserve_custom_color_on_companion_command_tag = true
local use_global_outline_override = false
local global_outline_visibility = 100
local global_outline_distance = 120

local outline_visibility_enforce_timer = 0
local tracked_unit_update_timer = 0
local full_scan_timer = 0
local update_frame_counter = 0
local has_active_outline_settings = false
local max_active_distance_cached = MIN_SCAN_DISTANCE

local known_entry_by_breed = config.get_entry_by_breed()
local ordered_breed_entries = config.get_ordered_breed_entries()

local UNKNOWN_BREED_KEY = config.UNKNOWN_BREED_KEY
local unknown_units_title = mod:localize("unknown_units_title")
local toggle_emperor_vision_command_description = mod:localize("toggle_emperor_vision_command_description")
local emperor_vision_on_text = mod:localize("emperor_vision_on_text")
local emperor_vision_off_text = mod:localize("emperor_vision_off_text")

local breed_records = {}
local ordered_breed_keys = {}
local setting_id_to_breed_key = {}

local function clamp_number(value, min_value, max_value, fallback)
    local number_value = tonumber(value)
    if number_value == nil then
        number_value = fallback
    end

    if number_value < min_value then
        number_value = min_value
    end

    if number_value > max_value then
        number_value = max_value
    end

    return number_value
end

local function setting_bool(setting_id, fallback)
    local value = mod:get(setting_id)
    if value == nil then
        return fallback
    end

    return value ~= false
end

local function normalize_los_behavior(value)
    return config.normalize_los_behavior and config.normalize_los_behavior(value) or LOS_BEHAVIOR_GLOBAL
end

local function resolve_record_los_enabled(los_behavior)
    if los_behavior == LOS_BEHAVIOR_ENABLED then
        return true
    end

    if los_behavior == LOS_BEHAVIOR_DISABLED then
        return false
    end

    return require_line_of_sight == true
end

local function unit_record_uses_los(unit_record)
    local record = unit_record and unit_record.record
    local settings = record and record.settings

    if settings and settings.los_enabled ~= nil then
        return settings.los_enabled == true
    end

    return require_line_of_sight == true
end

local function preserve_custom_color_on_veteran_tag_setting()
    local value = mod:get("preserve_custom_color_on_veteran_tag")
    if value == nil then
        return mod:get("preserve_custom_color_on_ally_tag") == true
    end

    return value == true
end

local function build_breed_record(breed_key, display_name, category, defaults)
    local setting_ids = config.get_setting_ids(breed_key)

    local record = {
        key = breed_key,
        display_name = display_name,
        category = category,
        defaults = defaults,
        setting_ids = setting_ids,
        outline_slot = config.get_outline_slot_name(breed_key),
        settings = nil,
    }

    breed_records[breed_key] = record
    ordered_breed_keys[#ordered_breed_keys + 1] = breed_key

    for _, setting_id in pairs(setting_ids) do
        setting_id_to_breed_key[setting_id] = breed_key
    end
end

for i = 1, #ordered_breed_entries do
    local entry = ordered_breed_entries[i]
    build_breed_record(entry.breed_name, entry.display_name, entry.category, entry.defaults)
end

build_breed_record(UNKNOWN_BREED_KEY, unknown_units_title, "unknown", config.get_unknown_defaults())

local function has_active_local_player()
    local player_manager = Managers.player
    if not player_manager then
        return false
    end

    local num_players = player_manager._num_players
    if num_players and num_players <= 0 then
        return false
    end

    local players = player_manager._players
    if players and next(players) == nil then
        return false
    end

    return true
end

local function get_local_player_safe()
    if not has_active_local_player() then
        return nil
    end

    local player_manager = Managers.player
    if not player_manager then
        return nil
    end

    return player_manager:local_player(1)
end

local function get_local_player_unit_safe()
    local player = get_local_player_safe()
    local player_unit = player and player.player_unit

    if not player_unit or not ALIVE[player_unit] then
        return nil, nil
    end

    return player, player_unit
end

local function build_player_unit_lookup()
    local player_manager = Managers.player
    if not player_manager or not player_manager.players then
        return nil
    end

    local players = player_manager:players()
    if not players then
        return nil
    end

    local lookup = {}
    for _, player in pairs(players) do
        local player_unit = player and player.player_unit
        if player_unit then
            lookup[player_unit] = true
        end
    end

    return lookup
end

local function is_player_owned_unit(unit, player_unit_lookup)
    if player_unit_lookup then
        return player_unit_lookup[unit] == true
    end

    local player_manager = Managers.player
    if player_manager and player_manager.players then
        local players = player_manager:players()
        if players then
            for _, player in pairs(players) do
                if player and player.player_unit == unit then
                    return true
                end
            end
        end
    end

    return false
end

local function get_unit_side_name(unit_side)
    if not unit_side then
        return nil
    end

    local unit_side_name = unit_side.name
    if type(unit_side_name) == "function" then
        unit_side_name = unit_side:name()
    end

    return unit_side_name
end

local function build_hostility_context()
    local _, player_unit = get_local_player_unit_safe()
    if not player_unit then
        return nil
    end

    local extension_manager = Managers.state and Managers.state.extension
    local side_system = extension_manager and extension_manager:system("side_system")
    local side_by_unit = side_system and side_system.side_by_unit
    if not side_by_unit then
        return nil
    end

    local player_side = side_by_unit[player_unit]
    if not player_side then
        return nil
    end

    local enemy_side_names = player_side:relation_side_names("enemy")
    if not enemy_side_names then
        return nil
    end

    local enemy_side_lookup = {}
    for i = 1, #enemy_side_names do
        enemy_side_lookup[enemy_side_names[i]] = true
    end

    return {
        enemy_side_lookup = enemy_side_lookup,
        player_unit_lookup = build_player_unit_lookup(),
        side_by_unit = side_by_unit,
    }
end

local function is_unit_hostile_to_local_player(unit, hostility_context)
    local context = hostility_context or build_hostility_context()
    if not context then
        return nil
    end

    if is_player_owned_unit(unit, context.player_unit_lookup) then
        return false
    end

    local unit_side = context.side_by_unit[unit]
    if not unit_side then
        return nil
    end

    local unit_side_name = get_unit_side_name(unit_side)
    if not unit_side_name then
        return nil
    end

    return context.enemy_side_lookup[unit_side_name] == true
end

local function copy_color3(color)
    return {
        color[1],
        color[2],
        color[3],
    }
end

local function current_outline_priority()
    return DEFAULT_CUSTOM_OUTLINE_PRIORITY
end

local function update_outline_template_colors(record)
    local outline_settings = outline_settings_cache
    if not outline_settings or not outline_settings.MinionOutlineExtension then
        return
    end

    local settings = record.settings
    if not settings then
        return
    end

    local ext = outline_settings.MinionOutlineExtension

    local outline_slot = ext[record.outline_slot]
    if outline_slot then
        outline_slot.color = copy_color3(settings.outline_color)
        outline_slot.priority = current_outline_priority()
    end
end

local function refresh_record_settings(record)
    local ids = record.setting_ids
    local defaults = record.defaults

    local color_r = clamp_number(mod:get(ids.color_r), 0, 255, defaults.color_r)
    local color_g = clamp_number(mod:get(ids.color_g), 0, 255, defaults.color_g)
    local color_b = clamp_number(mod:get(ids.color_b), 0, 255, defaults.color_b)

    local visibility = clamp_number(mod:get(ids.visibility), 0, 100, defaults.visibility)
    local distance = clamp_number(mod:get(ids.distance), 5, 120, defaults.distance)
    local los_behavior = normalize_los_behavior(mod:get(ids.los_behavior))
    local los_enabled = resolve_record_los_enabled(los_behavior)

    if use_global_outline_override then
        visibility = global_outline_visibility
        distance = global_outline_distance
    end

    local visibility_scalar = visibility / 100

    local base_r = color_r / 255
    local base_g = color_g / 255
    local base_b = color_b / 255

    local visible_r = base_r * visibility_scalar
    local visible_g = base_g * visibility_scalar
    local visible_b = base_b * visibility_scalar

    local outline_color = {
        math.min(visible_r, 1),
        math.min(visible_g, 1),
        math.min(visible_b, 1),
    }

    record.settings = {
        enabled = setting_bool(ids.enabled, defaults.enabled),
        los_behavior = los_behavior,
        los_enabled = los_enabled,
        distance = distance,
        distance_squared = distance * distance,
        visibility = visibility,
        outline_color = outline_color,
    }

    update_outline_template_colors(record)
end

local function refresh_all_record_settings()
    for i = 1, #ordered_breed_keys do
        local key = ordered_breed_keys[i]
        local record = breed_records[key]
        refresh_record_settings(record)
    end

    local any_active = false
    local max_distance = MIN_SCAN_DISTANCE

    for i = 1, #ordered_breed_keys do
        local key = ordered_breed_keys[i]
        local record = breed_records[key]
        local settings = record.settings

        if settings and settings.enabled then
            any_active = true

            if settings.distance > max_distance then
                max_distance = settings.distance
            end
        end
    end

    if max_distance < MIN_SCAN_DISTANCE then
        max_distance = MIN_SCAN_DISTANCE
    end

    if max_distance > MAX_SCAN_DISTANCE then
        max_distance = MAX_SCAN_DISTANCE
    end

    has_active_outline_settings = any_active
    max_active_distance_cached = max_distance
end

local function get_max_active_distance()
    if not has_active_outline_settings then
        return nil
    end

    return max_active_distance_cached
end

local function register_outline_slots(outline_settings)
    if not outline_settings then
        local ok
        ok, outline_settings = pcall(require, "scripts/settings/outline/outline_settings")
        if not ok or not outline_settings then
            return
        end
    end

    outline_settings_cache = outline_settings

    local ext = outline_settings.MinionOutlineExtension
    if not ext then
        return
    end

    for i = 1, #ordered_breed_keys do
        local key = ordered_breed_keys[i]
        local record = breed_records[key]
        local settings = record.settings or {
            outline_color = { 1, 0, 0 },
        }

        ext[record.outline_slot] = {
            priority = current_outline_priority(),
            material_layers = OUTLINE_MATERIAL_LAYERS,
            color = copy_color3(settings.outline_color),
            visibility_check = function()
                return true
            end,
        }
    end
end

mod:hook_require("scripts/settings/outline/outline_settings", function(settings)
    register_outline_slots(settings)
end)

local function safe_has_outline(unit, slot)
    if not outline_system then
        return false
    end

    local has = false
    pcall(function()
        has = outline_system:has_outline(unit, slot)
    end)

    return has == true
end

local function safe_add_outline(unit, slot, skip_has_check)
    if not outline_system then
        return false
    end

    if not skip_has_check and safe_has_outline(unit, slot) then
        return true
    end

    local ok = pcall(function()
        outline_system:add_outline(unit, slot)
    end)

    return ok == true
end

local function safe_remove_outline(unit, slot, skip_has_check)
    if not outline_system then
        return false
    end

    if skip_has_check then
        local removed = false

        for _ = 1, 4 do
            local ok = pcall(function()
                outline_system:remove_outline(unit, slot)
            end)

            if not ok then
                break
            end

            removed = true

            if not safe_has_outline(unit, slot) then
                break
            end
        end

        return removed
    end

    local removed = false

    for _ = 1, 4 do
        if not safe_has_outline(unit, slot) then
            break
        end

        pcall(function()
            outline_system:remove_outline(unit, slot)
        end)

        removed = true
    end

    return removed
end

local ping_outline_hook_guard = 0

local function with_ping_outline_hook_guard(callback)
    ping_outline_hook_guard = ping_outline_hook_guard + 1
    local ok = pcall(callback)
    ping_outline_hook_guard = ping_outline_hook_guard - 1

    return ok == true
end

local function is_ping_outline_name(outline_name)
    return ALLY_SMART_TAG_OUTLINE_NAMES[outline_name]
        or VETERAN_SMART_TAG_OUTLINE_NAMES[outline_name]
        or COMPANION_COMMAND_TAG_OUTLINE_NAMES[outline_name]
end

local function should_preserve_custom_color_for_outline(outline_name)
    if ALLY_SMART_TAG_OUTLINE_NAMES[outline_name] then
        return preserve_custom_color_on_ally_tag == true
    end

    if VETERAN_SMART_TAG_OUTLINE_NAMES[outline_name] then
        return preserve_custom_color_on_veteran_tag == true
    end

    if COMPANION_COMMAND_TAG_OUTLINE_NAMES[outline_name] then
        return preserve_custom_color_on_companion_command_tag == true
    end

    return false
end

local function should_keep_ping_color_for_outline(outline_name)
    return is_ping_outline_name(outline_name) and not should_preserve_custom_color_for_outline(outline_name)
end

local function should_switch_between_custom_and_ping_with_los(outline_name, los_enabled)
    if not los_enabled then
        return false
    end

    return is_ping_outline_name(outline_name) and should_preserve_custom_color_for_outline(outline_name)
end

local function snapshot_active_ping_outlines(unit)
    local active_ping_outlines = nil

    for outline_name, _ in pairs(ALLY_SMART_TAG_OUTLINE_NAMES) do
        if safe_has_outline(unit, outline_name) then
            active_ping_outlines = active_ping_outlines or {}
            active_ping_outlines[outline_name] = 1
        end
    end

    for outline_name, _ in pairs(VETERAN_SMART_TAG_OUTLINE_NAMES) do
        if safe_has_outline(unit, outline_name) then
            active_ping_outlines = active_ping_outlines or {}
            active_ping_outlines[outline_name] = 1
        end
    end

    for outline_name, _ in pairs(COMPANION_COMMAND_TAG_OUTLINE_NAMES) do
        if safe_has_outline(unit, outline_name) then
            active_ping_outlines = active_ping_outlines or {}
            active_ping_outlines[outline_name] = 1
        end
    end

    return active_ping_outlines
end

local function register_ping_outline(unit_record, outline_name)
    if not unit_record or not is_ping_outline_name(outline_name) then
        return
    end

    local active_ping_outlines = unit_record.active_ping_outlines
    if not active_ping_outlines then
        active_ping_outlines = {}
        unit_record.active_ping_outlines = active_ping_outlines
    end

    active_ping_outlines[outline_name] = (active_ping_outlines[outline_name] or 0) + 1
end

local function unregister_ping_outline(unit, unit_record, outline_name)
    if not unit_record or not is_ping_outline_name(outline_name) then
        return
    end

    local active_ping_outlines = unit_record.active_ping_outlines
    if not active_ping_outlines then
        return
    end

    local count = active_ping_outlines[outline_name]
    if not count then
        if safe_has_outline(unit, outline_name) then
            active_ping_outlines[outline_name] = 1
        end
        return
    end

    if count > 1 then
        active_ping_outlines[outline_name] = count - 1
        return
    end

    if safe_has_outline(unit, outline_name) then
        active_ping_outlines[outline_name] = 1
    else
        active_ping_outlines[outline_name] = nil
    end

    local suppressed_ping_outlines = unit_record.suppressed_ping_outlines
    if suppressed_ping_outlines then
        suppressed_ping_outlines[outline_name] = nil
        if next(suppressed_ping_outlines) == nil then
            unit_record.suppressed_ping_outlines = nil
        end
    end

    if next(active_ping_outlines) == nil then
        unit_record.active_ping_outlines = nil
        unit_record.suppressed_ping_outlines = nil
    end
end

local function has_ping_outline_that_should_keep_ping_color(unit_record)
    if not unit_record or not unit_record.active_ping_outlines then
        return false
    end

    for outline_name, _ in pairs(unit_record.active_ping_outlines) do
        if should_keep_ping_color_for_outline(outline_name) then
            return true
        end
    end

    return false
end

local function has_ping_outline_that_should_switch_with_los(unit_record, los_enabled)
    if not unit_record or not unit_record.active_ping_outlines then
        return false
    end

    for outline_name, _ in pairs(unit_record.active_ping_outlines) do
        if should_switch_between_custom_and_ping_with_los(outline_name, los_enabled) then
            return true
        end
    end

    return false
end

local function suppress_ping_outlines_for_custom_visibility(unit, unit_record, los_enabled)
    local active_ping_outlines = unit_record and unit_record.active_ping_outlines
    if not active_ping_outlines then
        return
    end

    local suppressed_ping_outlines = unit_record.suppressed_ping_outlines

    for outline_name, count in pairs(active_ping_outlines) do
        if count and count > 0 and should_switch_between_custom_and_ping_with_los(outline_name, los_enabled)
            and safe_has_outline(unit, outline_name) then
            local removed = with_ping_outline_hook_guard(function()
                safe_remove_outline(unit, outline_name, true)
            end)

            if removed and not safe_has_outline(unit, outline_name) then
                suppressed_ping_outlines = suppressed_ping_outlines or {}
                suppressed_ping_outlines[outline_name] = true
            end
        end
    end

    unit_record.suppressed_ping_outlines = suppressed_ping_outlines
end

local function restore_suppressed_ping_outlines(unit, unit_record, los_enabled)
    local suppressed_ping_outlines = unit_record and unit_record.suppressed_ping_outlines
    if not suppressed_ping_outlines then
        return
    end

    local active_ping_outlines = unit_record.active_ping_outlines

    for outline_name, _ in pairs(suppressed_ping_outlines) do
        local active_count = active_ping_outlines and active_ping_outlines[outline_name]
        if active_count and active_count > 0 and should_switch_between_custom_and_ping_with_los(outline_name, los_enabled) then
            if not safe_has_outline(unit, outline_name) then
                with_ping_outline_hook_guard(function()
                    safe_add_outline(unit, outline_name, true)
                end)
            end

            if safe_has_outline(unit, outline_name) then
                suppressed_ping_outlines[outline_name] = nil
            end
        else
            suppressed_ping_outlines[outline_name] = nil
        end
    end

    if next(suppressed_ping_outlines) == nil then
        unit_record.suppressed_ping_outlines = nil
    end
end

local function clear_unit(unit)
    local unit_record = unit_records[unit]
    if not unit_record then
        return
    end

    restore_suppressed_ping_outlines(unit, unit_record, unit_record_uses_los(unit_record))

    local record = unit_record.record
    if unit_record.outline_active then
        safe_remove_outline(unit, record.outline_slot, true)
    else
        safe_remove_outline(unit, record.outline_slot)
    end

    unit_records[unit] = nil
end

local function clear_all_units()
    local units = {}

    for unit, _ in pairs(unit_records) do
        units[#units + 1] = unit
    end

    for i = 1, #units do
        clear_unit(units[i])
    end
end

local function should_force_global_outline_visibility()
    if not (mod.enabled and force_outline_visibility) then
        return false
    end

    local _, player_unit = get_local_player_unit_safe()

    return player_unit ~= nil
end

local function force_global_outline_visibility_now()
    if not outline_system or not should_force_global_outline_visibility() then
        return
    end

    pcall(function()
        outline_system:set_global_visibility(true)
    end)
end

local function get_level_physics_world()
    local world_manager = Managers.world
    if not world_manager or not world_manager.has_world then
        return nil
    end

    local world_name = "level_world"
    if not world_manager:has_world(world_name) then
        return nil
    end

    local world = world_manager:world(world_name)
    if not world then
        return nil
    end

    local ok, physics_world = pcall(World.physics_world, world)
    if not ok then
        return nil
    end

    return physics_world
end

local function has_line_of_sight_to_unit(player_position, unit)
    if not unit or not (HEALTH_ALIVE and HEALTH_ALIVE[unit]) then
        return false
    end

    local _, player_unit = get_local_player_unit_safe()
    if player_unit then
        local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
        if unit_data_extension then
            local first_person_component = unit_data_extension:read_component("first_person")
            local first_person_position = first_person_component and first_person_component.position

            if first_person_position then
                player_position = first_person_position
            end
        end
    end

    if not player_position then
        return false
    end

    local physics_world = get_level_physics_world()
    if not physics_world then
        return true
    end

    local node = Unit.has_node(unit, "j_head") and Unit.node(unit, "j_head") or 0
    local target_position = Unit.world_position(unit, node)
    if not target_position then
        return true
    end

    local direction = target_position - player_position
    local distance_squared = Vector3.length_squared(direction)
    if distance_squared == 0 then
        return true
    end

    local distance = math.sqrt(distance_squared)
    local direction_normalized = direction / distance
    local ray_length = math.max(distance - 0.1, 0)

    if ray_length <= 0 then
        return true
    end

    local hits
    local ok = pcall(function()
        hits = PhysicsWorld.immediate_raycast(
            physics_world,
            player_position,
            direction_normalized,
            ray_length,
            "all",
            "types",
            "both",
            "collision_filter",
            "filter_interactable_line_of_sight_marker_check"
        )
    end)

    if not ok then
        ok = pcall(function()
            hits = PhysicsWorld.immediate_raycast(
                physics_world,
                player_position,
                direction_normalized,
                ray_length,
                "all",
                "types",
                "both",
                "collision_filter",
                "filter_player_character_shooting_raycast_statics"
            )
        end)
    end

    if not ok then
        return true
    end

    local has_blocking_hit = type(hits) == "table" and #hits > 0

    return not has_blocking_hit
end

local function apply_unit_visuals(unit, unit_record, player_position)
    if not unit_record or not unit_record.record then
        return
    end

    if not (HEALTH_ALIVE and HEALTH_ALIVE[unit]) then
        clear_unit(unit)
        return
    end

    local record = unit_record.record
    local settings = record.settings
    local outline_active = unit_record.outline_active == true
    local los_enabled = settings and settings.los_enabled == true

    if not settings or not settings.enabled then
        if outline_active then
            safe_remove_outline(unit, record.outline_slot, true)
            unit_record.outline_active = false
        end
        return
    end

    if not player_position then
        if outline_active then
            safe_remove_outline(unit, record.outline_slot, true)
            unit_record.outline_active = false
        end
        return
    end

    if los_enabled and has_ping_outline_that_should_keep_ping_color(unit_record) then
        restore_suppressed_ping_outlines(unit, unit_record, los_enabled)
        unit_record.los_visible = nil
        unit_record.los_next_recheck_frame = 0

        if outline_active then
            safe_remove_outline(unit, record.outline_slot, true)
            unit_record.outline_active = false
        end

        return
    end

    local unit_position = Unit.world_position(unit, 1)
    if not unit_position then
        return
    end

    local delta = unit_position - player_position
    local distance_squared = Vector3.length_squared(delta)
    local in_distance = distance_squared <= settings.distance_squared

    local show_outline = in_distance
    if show_outline and los_enabled then
        local los_visible = unit_record.los_visible
        local los_next_recheck_frame = unit_record.los_next_recheck_frame or 0
        local can_use_cached_los = los_visible ~= nil and update_frame_counter < los_next_recheck_frame

        if can_use_cached_los then
            show_outline = los_visible
        else
            los_visible = has_line_of_sight_to_unit(player_position, unit)
            unit_record.los_visible = los_visible
            unit_record.los_next_recheck_frame = update_frame_counter + LOS_RECHECK_INTERVAL_FRAMES
            show_outline = los_visible
        end
    else
        unit_record.los_visible = nil
        unit_record.los_next_recheck_frame = 0
    end

    if has_ping_outline_that_should_switch_with_los(unit_record, los_enabled) then
        if show_outline then
            suppress_ping_outlines_for_custom_visibility(unit, unit_record, los_enabled)
        else
            restore_suppressed_ping_outlines(unit, unit_record, los_enabled)
        end
    else
        restore_suppressed_ping_outlines(unit, unit_record, los_enabled)
    end

    if show_outline then
        if not outline_active then
            if safe_add_outline(unit, record.outline_slot) then
                unit_record.outline_active = true
            end
        end
    elseif outline_active then
        safe_remove_outline(unit, record.outline_slot, true)
        unit_record.outline_active = false
    end
end

local function resolve_record_for_unit_data(unit_data)
    if not unit_data then
        return nil
    end

    local breed = unit_data:breed()
    if not breed then
        return nil
    end

    local breed_name = breed.name
    if type(breed_name) ~= "string" or breed_name == "" then
        return nil
    end

    if known_entry_by_breed[breed_name] then
        return breed_records[breed_name], breed_name, breed_name
    end

    local normalized_breed_name = config.normalize_breed_name(breed_name)
    if normalized_breed_name and known_entry_by_breed[normalized_breed_name] then
        return breed_records[normalized_breed_name], breed_name, normalized_breed_name
    end

    local category = config.classify_runtime_breed(breed.tags, normalized_breed_name or breed_name)
    if category then
        return breed_records[UNKNOWN_BREED_KEY], breed_name, normalized_breed_name
    end

    return nil
end

local function track_unit(unit, hostility_context)
    local is_hostile = is_unit_hostile_to_local_player(unit, hostility_context)
    if is_hostile == false then
        clear_unit(unit)
        return
    end

    local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data then
        clear_unit(unit)
        return
    end

    local record, raw_breed_name, normalized_breed_name = resolve_record_for_unit_data(unit_data)

    if not record then
        clear_unit(unit)
        return
    end

    local settings = record.settings
    if not settings or not settings.enabled then
        clear_unit(unit)
        return
    end

    local previous_unit_record = unit_records[unit]

    unit_records[unit] = {
        record = record,
        raw_breed_name = raw_breed_name,
        normalized_breed_name = normalized_breed_name,
        outline_active = safe_has_outline(unit, record.outline_slot),
        active_ping_outlines = previous_unit_record and previous_unit_record.active_ping_outlines
            or snapshot_active_ping_outlines(unit),
        suppressed_ping_outlines = previous_unit_record and previous_unit_record.suppressed_ping_outlines or nil,
        los_visible = nil,
        los_next_recheck_frame = 0,
    }

    local _, player_unit = get_local_player_unit_safe()
    local player_position = player_unit and Unit.world_position(player_unit, 1)

    apply_unit_visuals(unit, unit_records[unit], player_position)
end

local function rebuild_tracked_units(hostility_context)
    local stale = {}

    for unit, _ in pairs(unit_records) do
        if HEALTH_ALIVE and HEALTH_ALIVE[unit] then
            track_unit(unit, hostility_context)
        else
            stale[#stale + 1] = unit
        end
    end

    for i = 1, #stale do
        clear_unit(stale[i])
    end
end

local function scan_for_new_units()
    if not mod.enabled then
        return
    end

    local extension_manager = Managers.state and Managers.state.extension
    local side_system = extension_manager and extension_manager:system("side_system")
    local broadphase_system = extension_manager and extension_manager:system("broadphase_system")
    local _, player_unit = get_local_player_unit_safe()

    if not side_system or not broadphase_system or not player_unit then
        return
    end

    local player_side = side_system.side_by_unit[player_unit]
    if not player_side then
        return
    end

    local enemy_side_names = player_side:relation_side_names("enemy")
    if not enemy_side_names then
        return
    end

    local player_position = Unit.world_position(player_unit, 1)
    if not player_position then
        return
    end

    local broadphase = broadphase_system.broadphase
    if not broadphase then
        return
    end

    local range = get_max_active_distance()
    if not range then
        return
    end

    table.clear(scan_results)

    local hits = broadphase.query(broadphase, player_position, range, scan_results, enemy_side_names)
    if not hits or hits <= 0 then
        return
    end

    local hostility_context = build_hostility_context()

    for i = 1, hits do
        local unit = scan_results[i]

        if unit and HEALTH_ALIVE and HEALTH_ALIVE[unit] then
            if not unit_records[unit] then
                track_unit(unit, hostility_context)
            end
        end
    end
end

local function refresh_settings()
    force_outline_visibility = mod:get("force_outline_visibility") ~= false
    require_line_of_sight = mod:get("require_line_of_sight") == true
    preserve_custom_color_on_ally_tag = mod:get("preserve_custom_color_on_ally_tag") == true
    preserve_custom_color_on_veteran_tag = preserve_custom_color_on_veteran_tag_setting()
    preserve_custom_color_on_companion_command_tag = mod:get("preserve_custom_color_on_companion_command_tag") ~= false
    use_global_outline_override = mod:get("use_global_outline_override") == true
    global_outline_visibility = clamp_number(mod:get("global_outline_visibility"), 0, 100, 100)
    global_outline_distance = clamp_number(mod:get("global_outline_distance"), 5, 120, 120)
    refresh_all_record_settings()
end

local function should_reset_outline_on_setting_change(record, setting_id)
    if not record or not setting_id then
        return false
    end

    local ids = record.setting_ids
    if not ids then
        return false
    end

    return setting_id == ids.color_r
        or setting_id == ids.color_g
        or setting_id == ids.color_b
        or setting_id == ids.visibility
end

local function reapply_record_visuals(record, reset_outline)
    local _, player_unit = get_local_player_unit_safe()
    local player_position = player_unit and Unit.world_position(player_unit, 1)

    for unit, unit_record in pairs(unit_records) do
        if unit_record.record == record then
            if reset_outline then
                safe_remove_outline(unit, record.outline_slot, true)
                unit_record.outline_active = false
            end

            apply_unit_visuals(unit, unit_record, player_position)
        end
    end
end

local function reapply_all_record_visuals(reset_outline)
    local _, player_unit = get_local_player_unit_safe()
    local player_position = player_unit and Unit.world_position(player_unit, 1)

    for unit, unit_record in pairs(unit_records) do
        local record = unit_record.record

        if reset_outline and record then
            safe_remove_outline(unit, record.outline_slot, true)
            unit_record.outline_active = false
        end

        apply_unit_visuals(unit, unit_record, player_position)
    end
end

local function reapply_unit_visuals(unit, reset_outline)
    local unit_record = unit_records[unit]
    if not unit_record then
        return
    end

    local record = unit_record.record
    if not record then
        return
    end

    local _, player_unit = get_local_player_unit_safe()
    local player_position = player_unit and Unit.world_position(player_unit, 1)

    if reset_outline then
        safe_remove_outline(unit, record.outline_slot, true)
        unit_record.outline_active = false
    end

    apply_unit_visuals(unit, unit_record, player_position)
end

mod.toggle_emperor_vision = function()
    mod.enabled = not mod.enabled

    if mod.enabled then
        refresh_settings()
        rebuild_tracked_units(build_hostility_context())
        scan_for_new_units()
        force_global_outline_visibility_now()
        mod:echo(emperor_vision_on_text)
    else
        clear_all_units()
        mod:echo(emperor_vision_off_text)
    end
end

mod.on_enabled = function(initial_call)
    mod.enabled = true
    refresh_settings()
    rebuild_tracked_units(build_hostility_context())
    scan_for_new_units()
    force_global_outline_visibility_now()
end

mod.on_disabled = function(initial_call)
    mod.enabled = false
    clear_all_units()
end

mod.on_setting_changed = function(setting_id)
    if not setting_id then
        return
    end

    if setting_id == "force_outline_visibility" then
        force_outline_visibility = mod:get("force_outline_visibility") ~= false
        if force_outline_visibility then
            force_global_outline_visibility_now()
        end
        return
    end

    if setting_id == "require_line_of_sight" then
        require_line_of_sight = mod:get("require_line_of_sight") == true
        refresh_all_record_settings()
        reapply_all_record_visuals(false)
        return
    end

    if setting_id == "preserve_custom_color_on_ally_tag"
        or setting_id == "preserve_custom_color_on_veteran_tag"
        or setting_id == "preserve_custom_color_on_companion_command_tag" then
        preserve_custom_color_on_ally_tag = mod:get("preserve_custom_color_on_ally_tag") == true
        preserve_custom_color_on_veteran_tag = preserve_custom_color_on_veteran_tag_setting()
        preserve_custom_color_on_companion_command_tag = mod:get("preserve_custom_color_on_companion_command_tag") ~= false
        refresh_all_record_settings()
        reapply_all_record_visuals(true)

        full_scan_timer = FULL_SCAN_INTERVAL_FRAMES
        scan_for_new_units()
        return
    end

    if setting_id == "use_global_outline_override"
        or setting_id == "global_outline_visibility"
        or setting_id == "global_outline_distance" then
        use_global_outline_override = mod:get("use_global_outline_override") == true
        global_outline_visibility = clamp_number(mod:get("global_outline_visibility"), 0, 100, 100)
        global_outline_distance = clamp_number(mod:get("global_outline_distance"), 5, 120, 120)

        refresh_all_record_settings()

        local reset_outline = setting_id == "use_global_outline_override"
            or (setting_id == "global_outline_visibility" and use_global_outline_override)
        reapply_all_record_visuals(reset_outline)

        if use_global_outline_override or setting_id == "use_global_outline_override" then
            full_scan_timer = FULL_SCAN_INTERVAL_FRAMES
            scan_for_new_units()
        end
        return
    end

    local breed_key = setting_id_to_breed_key[setting_id]
    if not breed_key then
        return
    end

    local record = breed_records[breed_key]
    if not record then
        return
    end

    refresh_record_settings(record)

    local reset_outline = should_reset_outline_on_setting_change(record, setting_id)
    reapply_record_visuals(record, reset_outline)

    full_scan_timer = FULL_SCAN_INTERVAL_FRAMES
    scan_for_new_units()
end

mod:command("ev", toggle_emperor_vision_command_description, mod.toggle_emperor_vision)

mod:hook_safe(CLASS.OutlineSystem, "init", function(self)
    outline_system = self
end)

mod:hook(CLASS.OutlineSystem, "set_global_visibility", function(func, self, visible)
    outline_system = self

    if visible == false and should_force_global_outline_visibility() then
        return func(self, true)
    end

    return func(self, visible)
end)

mod:hook_safe(CLASS.OutlineSystem, "on_add_extension", function(self, world, unit, extension_name)
    outline_system = self

    if not mod.enabled then
        return
    end

    if is_player_owned_unit(unit) then
        clear_unit(unit)
        return
    end

    track_unit(unit, build_hostility_context())
end)

mod:hook_safe(CLASS.OutlineSystem, "add_outline", function(self, unit, outline_name)
    outline_system = self

    if not mod.enabled or ping_outline_hook_guard > 0 then
        return
    end

    local is_ally_smart_tag_outline = ALLY_SMART_TAG_OUTLINE_NAMES[outline_name]
    local is_veteran_smart_tag_outline = VETERAN_SMART_TAG_OUTLINE_NAMES[outline_name]
    local is_companion_command_tag_outline = COMPANION_COMMAND_TAG_OUTLINE_NAMES[outline_name]

    if not (is_ally_smart_tag_outline or is_veteran_smart_tag_outline or is_companion_command_tag_outline) then
        return
    end

    local had_unit_record = unit_records[unit] ~= nil

    if not had_unit_record then
        track_unit(unit, build_hostility_context())
    end

    local unit_record = unit_records[unit]
    local active_ping_outlines = unit_record and unit_record.active_ping_outlines
    local has_outline_in_active_map = active_ping_outlines and active_ping_outlines[outline_name] ~= nil

    if unit_record and (had_unit_record or not has_outline_in_active_map) then
        register_ping_outline(unit_record, outline_name)
    end

    local unit_los_enabled = unit_record_uses_los(unit_record)

    local preserve_custom_color_for_ping = (is_ally_smart_tag_outline and preserve_custom_color_on_ally_tag)
        or (is_veteran_smart_tag_outline and preserve_custom_color_on_veteran_tag)
        or (is_companion_command_tag_outline and preserve_custom_color_on_companion_command_tag)

    if not preserve_custom_color_for_ping then
        restore_suppressed_ping_outlines(unit, unit_record, unit_los_enabled)

        if unit_los_enabled and unit_record and unit_record.outline_active then
            local record = unit_record.record

            if record then
                safe_remove_outline(unit, record.outline_slot, true)
                unit_record.outline_active = false
                unit_record.los_visible = nil
                unit_record.los_next_recheck_frame = 0
            end
        end

        return
    end

    if unit_los_enabled then
        reapply_unit_visuals(unit, false)
        return
    end

    with_ping_outline_hook_guard(function()
        safe_remove_outline(unit, outline_name, true)
    end)
    reapply_unit_visuals(unit, false)
end)

mod:hook_safe(CLASS.OutlineSystem, "remove_outline", function(self, unit, outline_name)
    outline_system = self

    if not mod.enabled or ping_outline_hook_guard > 0 or not is_ping_outline_name(outline_name) then
        return
    end

    local unit_record = unit_records[unit]
    if not unit_record then
        return
    end

    unregister_ping_outline(unit, unit_record, outline_name)

    if unit_record_uses_los(unit_record) and not has_ping_outline_that_should_keep_ping_color(unit_record) then
        reapply_unit_visuals(unit, false)
    end
end)

mod:hook_safe("HealthExtension", "init", function(self, extension_init_context, unit)
    if not mod.enabled then
        return
    end

    track_unit(unit, build_hostility_context())
end)

mod:hook_safe("HuskHealthExtension", "init", function(self, extension_init_context, unit)
    if not mod.enabled then
        return
    end

    track_unit(unit, build_hostility_context())
end)

mod:hook_safe("HudElementWorldMarkers", "update", function(self, dt, t)
    if not mod.enabled then
        return
    end

    update_frame_counter = update_frame_counter + 1

    outline_visibility_enforce_timer = outline_visibility_enforce_timer + 1
    if outline_visibility_enforce_timer >= OUTLINE_VISIBILITY_ENFORCE_INTERVAL_FRAMES then
        outline_visibility_enforce_timer = 0
        force_global_outline_visibility_now()
    end

    tracked_unit_update_timer = tracked_unit_update_timer + 1
    if tracked_unit_update_timer >= TRACKED_UNIT_UPDATE_INTERVAL_FRAMES then
        tracked_unit_update_timer = 0

        if next(unit_records) ~= nil then
            local stale_units = {}
            for unit, _ in pairs(unit_records) do
                if not (HEALTH_ALIVE and HEALTH_ALIVE[unit]) then
                    stale_units[#stale_units + 1] = unit
                end
            end

            for i = 1, #stale_units do
                clear_unit(stale_units[i])
            end

            local hostility_context = build_hostility_context()
            local _, player_unit = get_local_player_unit_safe()
            local player_position = player_unit and Unit.world_position(player_unit, 1)

            for unit, unit_record in pairs(unit_records) do
                local is_hostile = is_unit_hostile_to_local_player(unit, hostility_context)
                if is_hostile == false then
                    clear_unit(unit)
                else
                    apply_unit_visuals(unit, unit_record, player_position)
                end
            end
        end
    end

    full_scan_timer = full_scan_timer + 1
    if full_scan_timer >= FULL_SCAN_INTERVAL_FRAMES then
        full_scan_timer = 0
        scan_for_new_units()
    end
end)

refresh_settings()
register_outline_slots()
