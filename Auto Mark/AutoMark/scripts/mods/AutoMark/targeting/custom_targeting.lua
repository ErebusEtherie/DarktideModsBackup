---@class AutoMarkMod:DMFMod
local mod                                  = get_mod("AutoMark")
local context                              = mod.context
local mark_context                         = mod.mark_context
local TAG_NAMES                            = mod.TAG_NAMES
local mod_settings                         = mod.settings
local companion_cancel_mark_breed_settings = mod.companion_cancel_mark_breed_settings
local noospheric_command_breed_settings    = mod.noospheric_command_breed_settings
local visibility_cache                     = mod.visibility_cache
local visibility_check_frame               = mod.visibility_check_frame
local servo_skull_visibility_cache         = mod.servo_skull_visibility_cache
local servo_skull_visibility_check_frame   = mod.servo_skull_visibility_check_frame

-- Imports
local Breed                                = require("scripts/utilities/breed")
local SpecialRulesSettings                 = require("scripts/settings/ability/special_rules_settings")
local Breed_height                         = Breed.height
local special_rules                        = SpecialRulesSettings.special_rules

-- Global Cache
local CLASS                                = CLASS
local HEALTH_ALIVE                         = HEALTH_ALIVE
local Managers                             = Managers
local get_game_object_field                = GameSession.game_object_field
local Actor_unit                           = Actor.unit
local Actor_world_bounds                   = Actor.world_bounds
local Unit_box                             = Unit.box
local Unit_node                            = Unit.node
local Unit_world_position                  = Unit.world_position
local PhysicsWorld_raycast                 = PhysicsWorld.raycast
local PhysicsWorld_make_raycast            = PhysicsWorld.make_raycast
local Raycast_cast                         = Raycast.cast
local ScriptUnit_extension                 = ScriptUnit.extension
local math_abs                             = math.abs
local math_max                             = math.max
local math_cos                             = math.cos
local math_rad                             = math.rad
local Vector3_dot                          = Vector3.dot
local Vector3_normalize                    = Vector3.normalize
local Vector3_length                       = Vector3.length
local Vector3_distance_squared             = Vector3.distance_squared
local Matrix4x4_right                      = Matrix4x4.right
local Matrix4x4_forward                    = Matrix4x4.forward
local Matrix4x4_translation                = Matrix4x4.translation
local table_clear                          = table.clear

-- Constants
local INDEX_POSITION                       = 1
local INDEX_DISTANCE                       = 2
local INDEX_NORMAL                         = 3
local INDEX_ACTOR                          = 4
local COLLISION_FILTER                     = "filter_player_ping_target_selection"
local EMPTY_TABLE                          = {}
local MAX_VISIBILITY_CHECKS_PER_FRAME      = 10

-- Params
local visibility_raycast_object            = nil

function mod:init_visibility_raycast_objects()
    local smart_targeting_extension = context.smart_targeting_extension
    local physics_world = smart_targeting_extension and smart_targeting_extension._physics_world
    if physics_world then
        visibility_raycast_object = PhysicsWorld_make_raycast(physics_world, "closest", "types", "both", "collision_filter", "filter_minion_line_of_sight_check")
    end
end

function mod:destroy_visibility_raycast_objects()
    visibility_raycast_object = nil
end

local function is_daemonhost_aggroed(unit)
    local game_session   = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    local stage          = get_game_object_field(game_session, game_object_id, "stage")
    return type(stage) == "number" and stage == 6
end

local function is_target_aggroed(unit)
    local game_session = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    local attacking_unit_id = get_game_object_field(game_session, game_object_id, "target_unit_id")
    return attacking_unit_id ~= -1
end

function mod:is_dormant_daemonhost(target_unit)
    local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    if breed_data and breed_data.tags.witch and not is_target_aggroed(target_unit) then
        return true
    end

    return false
end

local function get_breed_priority(breed_name, breed_data, breed_priorities, attacking_unit_id)
    if breed_data and breed_data.tags.witch then
        if attacking_unit_id == -1 then
            return breed_priorities[breed_name .. "_passive"] or 0, true
        else
            return breed_priorities[breed_name] or 0, false
        end
    else
        return breed_priorities[breed_name] or 0, false
    end
end

-- Check if Target Unit's Breed is Valid for Auto-Mark
local function is_breed_group_valid(breed_data, class_settings)
    if not breed_data or not class_settings then
        return false
    end

    -- toggle enemy by type
    if breed_data.tags.elite then
        return class_settings.toggle_elite
    elseif breed_data.tags.special then
        return class_settings.toggle_special
    elseif breed_data.is_boss then
        return class_settings.toggle_boss
    else
        return class_settings.toggle_other
    end
end

function mod:can_focus_target_overwrite(target_unit, target_tag)
    if not target_tag then
        return true
    end

    local target_buff_extension = ScriptUnit_extension(target_unit, "buff_system")
    if not target_buff_extension then
        return false
    end

    local focus_target_debuff = target_buff_extension._stacking_buffs["veteran_improved_tag_debuff"]
    local target_stack_count = focus_target_debuff and focus_target_debuff:stack_count() or 0
    local target_tag_name = target_tag and target_tag._template.name
    -- target does not have focus target debuff
    if target_tag_name ~= TAG_NAMES.VETERAN_TAG and target_stack_count <= 0 then
        return true
    end

    -- latency bug
    if target_tag_name == TAG_NAMES.VETERAN_TAG and target_stack_count <= 0 then
        return false
    end

    -- focus_target_overwrite not enabled
    if not mod_settings.focus_target_overwrite then
        return false
    end

    local talent_resource_component = context.talent_resource_component
    if not talent_resource_component then
        return false
    end

    -- check if player's buff stacks greater than target's debuff stacks
    local player_stack_count = talent_resource_component.current_resource or 0
    if player_stack_count <= target_stack_count then
        return false
    end

    return player_stack_count == context.focus_target_max_stacks
        or player_stack_count - target_stack_count >= mod_settings.focus_target_overwrite_delta
end

local function is_focus_target_tag_target_valid(target_unit, target_tag, target_breed_name, target_attacking_unit_id, removed_units)
    local target_tag_name = target_tag and target_tag._template.name
    if target_tag_name == TAG_NAMES.COMPANION_TAG or target_tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        if removed_units[target_unit] then
            return false
        end
    end

    if target_breed_name ~= "cultist_ritualist" and mod_settings.focus_target_ignore_unaggroed and target_attacking_unit_id == -1 then
        return false
    end

    if not mod:can_focus_target_overwrite(target_unit, target_tag) then
        return false
    end

    return true
end

local function is_ritual_started(daemonhost_id, game_session)
    if not daemonhost_id or daemonhost_id == -1 then
        return false
    end

    local stage = get_game_object_field(game_session, daemonhost_id, "stage")
    return type(stage) == "number" and stage > 1
end

local function is_cyber_mastiff_tag_target_valid(target_unit, target_tag, target_breed_name, target_breed_data, target_attacking_unit_id, game_session, removed_units, distance, companion_position, target_position)
    -- do not target unit tagged by focus target
    local target_tag_name = target_tag and target_tag._template.name
    if target_tag_name == TAG_NAMES.VETERAN_TAG then
        if removed_units[target_unit] then
            return false
        end
        -- do not target pounceble unit marked by other dog
    elseif target_tag_name == TAG_NAMES.COMPANION_TAG then
        local pounce_setting = target_breed_data.companion_pounce_setting
        local pounce_action = pounce_setting and pounce_setting.companion_pounce_action
        if pounce_action == "human" then
            return false
        end
    end

    -- check if target is aggroed or if ritual is started
    if target_breed_name == "chaos_mutator_ritualist" then
        if not is_ritual_started(target_attacking_unit_id, game_session) then
            return false
        end
    elseif target_breed_name == "cultist_ritualist" then
        -- do nothing
    else
        if mod_settings.companion_mark_ignore_unaggroed and target_attacking_unit_id == -1 then
            return false
        end
    end

    -- check if target is within range limitation
    local breed_settings = companion_cancel_mark_breed_settings[target_breed_name]
    local player_max_distance
    local companion_range_limitation
    if breed_settings and breed_settings.override then
        player_max_distance = breed_settings.max_distance or 0
        companion_range_limitation = breed_settings.range_limitation or 0
    else
        player_max_distance = mod_settings.companion_mark_max_distance or 0
        companion_range_limitation = mod_settings.companion_range_limitation or 0
    end

    if player_max_distance > 0 then
        if distance > player_max_distance then
            return false
        end
    end

    if companion_range_limitation > 0 then
        if not companion_position or not target_position then
            return false
        end

        if Vector3_distance_squared(companion_position, target_position) > companion_range_limitation * companion_range_limitation then
            return false
        end
    end

    return true
end

local function has_enough_capacitance(breed_settings, breed_data, max_ability_charges, remaining_capacitance)
    if not mod_settings.capacitance_retention or not context.has_noospheric_command then
        return true
    end

    if not breed_data or not max_ability_charges or not remaining_capacitance then
        return false
    end

    local capacitance_retention_threshold
    if breed_settings and breed_settings.override then
        capacitance_retention_threshold = breed_settings.threshold or 0
    else
        if breed_data.is_boss then
            capacitance_retention_threshold = mod_settings.capacitance_retention_boss_threshold
        elseif breed_data.tags.special then
            capacitance_retention_threshold = mod_settings.capacitance_retention_special_threshold
        else
            capacitance_retention_threshold = mod_settings.capacitance_retention_elite_threshold
        end
    end

    if 1 / capacitance_retention_threshold < 0 then
        capacitance_retention_threshold = max_ability_charges + capacitance_retention_threshold
    end

    return remaining_capacitance >= capacitance_retention_threshold
end

function mod:has_enough_capacitance(target_unit)
    local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    local breed_name = breed_data and breed_data.name
    local breed_settings = noospheric_command_breed_settings[breed_name]
    local player_ability_extension = context.player_ability_extension
    local max_ability_charges = player_ability_extension and player_ability_extension:max_ability_charges("combat_ability")
    local remaining_capacitance = player_ability_extension and player_ability_extension:remaining_ability_capacitance("combat_ability")
    return has_enough_capacitance(breed_settings, breed_data, max_ability_charges, remaining_capacitance)
end

local function is_servo_skull_tag_target_valid(target_unit, target_tag, target_breed_name, target_breed_data, target_attacking_unit_id, game_session, removed_units, companion_position, target_position, max_ability_charges, remaining_capacitance)
    -- do not target unit tagged by focus target
    local target_tag_name = target_tag and target_tag._template.name
    if target_tag_name == TAG_NAMES.VETERAN_TAG then
        if removed_units[target_unit] then
            return false
        end
    end

    -- check if target is aggroed or if ritual is started
    if target_breed_name == "chaos_mutator_ritualist" then
        if not is_ritual_started(target_attacking_unit_id, game_session) then
            return false
        end
    elseif target_breed_name == "cultist_ritualist" then
        -- do nothing
    else
        if mod_settings.servo_skull_mark_ignore_unaggroed and target_attacking_unit_id == -1 then
            return false
        end
    end

    -- check if target is within range limitation
    local breed_settings = noospheric_command_breed_settings[target_breed_name]
    local servo_skull_range_limitation
    if breed_settings and breed_settings.override then
        servo_skull_range_limitation = breed_settings.range_limitation or 0
    else
        servo_skull_range_limitation = mod_settings.servo_skull_range_limitation or 0
    end

    if servo_skull_range_limitation > 0 then
        if not companion_position or not target_position then
            return false
        end

        if Vector3_distance_squared(companion_position, target_position) > servo_skull_range_limitation * servo_skull_range_limitation then
            return false
        end
    end

    -- check if capacitance is sufficient
    if not has_enough_capacitance(breed_settings, target_breed_data, max_ability_charges, remaining_capacitance) then
        return false
    end

    return true
end

local function is_target_visible(ray_origin, up, target_unit_center_pos, half_height, target_unit, fixed_frame)
    if not visibility_raycast_object then
        return false
    end

    local cached_visibility = visibility_cache[target_unit]
    local last_check_frame = visibility_check_frame[target_unit]
    if cached_visibility ~= nil and fixed_frame - last_check_frame <= 5 then
        return cached_visibility
    end

    mod.num_visibility_checks_this_frame = mod.num_visibility_checks_this_frame + 1
    if mod.num_visibility_checks_this_frame > MAX_VISIBILITY_CHECKS_PER_FRAME then
        return false
    end

    local to_target_center = target_unit_center_pos - ray_origin
    local to_target_top = to_target_center + up * half_height
    local hit_top = Raycast_cast(visibility_raycast_object, ray_origin, Vector3_normalize(to_target_top), Vector3_length(to_target_top))
    if not hit_top then
        visibility_cache[target_unit] = true
        visibility_check_frame[target_unit] = fixed_frame
        return true
    end

    local hit_center = Raycast_cast(visibility_raycast_object, ray_origin, Vector3_normalize(to_target_center), Vector3_length(to_target_center))
    visibility_cache[target_unit] = not hit_center
    visibility_check_frame[target_unit] = fixed_frame
    return not hit_center
end

local EPSILON = 1e-05
local FORCE_FIELD_HEIGHT = 3.5
local FORCE_FIELD_RADIUS_SQUARED = 36
local WALL_ORDER = { 4, 3, 2, 1, 5, 6, 7 }
local function check_force_field_los(source_position, target_position)
    local force_field_system = context.force_field_system
    if not force_field_system then
        return false
    end

    local to_target = target_position - source_position
    local unit_to_extension_map = force_field_system._unit_to_extension_map
    local distance_to_target_squared = Vector3_dot(to_target, to_target)
    local to_target_x, to_target_y = target_position.x - source_position.x, target_position.y - source_position.y
    for _, force_field_extension in pairs(unit_to_extension_map) do
        if force_field_extension.__class_name ~= "PsykerForceFieldUnitExtension" then
            goto continue
        end

        if force_field_extension._sphere_shield then
            local force_field_position = force_field_extension._position:unbox()
            local to_force_field = force_field_position - source_position
            local distance_to_force_field_squared = Vector3_dot(to_force_field, to_force_field)
            if distance_to_force_field_squared < FORCE_FIELD_RADIUS_SQUARED then
                return true
            end

            local dot = Vector3_dot(to_force_field, to_target)
            if dot <= 0 then
                goto continue
            end

            local closest_point_to_force_field
            if distance_to_target_squared <= dot then
                closest_point_to_force_field = target_position
            else
                local t = dot / distance_to_target_squared
                closest_point_to_force_field = source_position + t * to_target
            end

            local distance_line_to_force_field_squared = Vector3_distance_squared(closest_point_to_force_field, force_field_position)
            if distance_line_to_force_field_squared < FORCE_FIELD_RADIUS_SQUARED then
                return true
            end
        else
            local force_field_position_z = force_field_extension._position:unbox().z
            local points = force_field_extension._points
            for i = 1, #WALL_ORDER - 1 do
                local point_a = points[WALL_ORDER[i]]:unbox()
                local point_b = points[WALL_ORDER[i + 1]]:unbox()
                local wall_x, wall_y = point_b.x - point_a.x, point_b.y - point_a.y
                local source_to_point_x, source_to_point_y = point_a.x - source_position.x, point_a.y - source_position.y
                local denom = to_target_x * wall_y - to_target_y * wall_x
                if math.abs(denom) > EPSILON then
                    local t = (source_to_point_x * wall_y - source_to_point_y * wall_x) / denom
                    local u = (source_to_point_x * to_target_y - source_to_point_y * to_target_x) / denom

                    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
                        local los_z = source_position.z + t * (target_position.z - source_position.z)
                        if los_z >= force_field_position_z and los_z <= force_field_position_z + FORCE_FIELD_HEIGHT then
                            return true
                        end
                    end
                end
            end
        end
        ::continue::
    end

    return false
end

local function is_cyber_mastiff_target_visible(ray_origin, up, target_unit_center_pos, half_height, target_unit, fixed_frame, target_tag, target_unit_marked_by_execution_order)
    if mod_settings.companion_mark_tagged_always_visible and (target_tag or target_unit_marked_by_execution_order) then
        return true
    end

    return is_target_visible(ray_origin, up, target_unit_center_pos, half_height, target_unit, fixed_frame)
end

local function is_servo_skull_target_visible(ray_origin, target_unit, fixed_frame, force_check)
    if not visibility_raycast_object then
        return false
    end

    local cached_visibility = servo_skull_visibility_cache[target_unit]
    local last_check_frame = servo_skull_visibility_check_frame[target_unit]
    if cached_visibility ~= nil and fixed_frame - last_check_frame <= 5 then
        return cached_visibility
    end

    if not force_check then
        mod.num_visibility_checks_this_frame = mod.num_visibility_checks_this_frame + 1
        if mod.num_visibility_checks_this_frame > MAX_VISIBILITY_CHECKS_PER_FRAME then
            return false
        end
    end

    local companion_spawner_extension = context.companion_spawner_extension
    local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
    if not servo_skull_unit then
        return false
    end

    local target_los_node = Unit_node(target_unit, "enemy_aim_target_03")
    local target_position = Unit_world_position(target_unit, target_los_node)
    local to_target_position = target_position - ray_origin
    local hit = Raycast_cast(visibility_raycast_object, ray_origin, Vector3_normalize(to_target_position), Vector3_length(to_target_position))
    servo_skull_visibility_cache[target_unit] = not hit
    servo_skull_visibility_check_frame[target_unit] = fixed_frame
    return not hit
end

function mod:is_servo_skull_target_visible(target_unit, fixed_frame, force_check)
    local companion_spawner_extension = context.companion_spawner_extension
    local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
    if not servo_skull_unit then
        return false
    end

    local servo_skull_los_node = Unit_node(servo_skull_unit, "skull_aim_center")
    local servo_skull_ray_origin = Unit_world_position(servo_skull_unit, servo_skull_los_node)
    return is_servo_skull_target_visible(servo_skull_ray_origin, target_unit, fixed_frame, force_check)
end

local broadphase_result = {}
local function broadphase_units(player_unit, player_position, max_range)
    local broadphase_system = context.broadphase_system
    local broadphase = broadphase_system and broadphase_system.broadphase
    if not broadphase then
        return nil, 0
    end

    local side_system = context.side_system
    local side = side_system and side_system.side_by_unit[player_unit]
    if not side then
        return nil, 0
    end

    table_clear(broadphase_result)
    local enemy_side_names = side:relation_side_names("enemy")
    local enemies_in_radius = broadphase:query(player_position, max_range, broadphase_result, enemy_side_names)
    return broadphase_result, enemies_in_radius
end

local IGNORE_EXECUTION_ORDER_FORCE_MARK_BREED_NAMES = {
    chaos_poxwalker_bomber = true,
    chaos_ogryn_houndmaster = true,
}
local IGNORE_EXECUTION_ORDER_PRIORITY_BREED_NAMES = {
    cultist_ritualist = true,
    chaos_mutator_ritualist = true,
    renegade_netgunner = true,
}
local IGNORE_THREAT_PRIORITY_BREED_NAMES = {
    cultist_grenadier = true,
    renegade_grenadier = true,
    cultist_ritualist = true,
    chaos_mutator_ritualist = true,
}
function mod:find_auto_mark_target_unit(min_range, max_range, max_angle, tag_name, tag_context, class_settings, marked_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not smart_tag_system then
        return
    end

    -- raycast for hit unit list
    local hits, num_hits
    local use_angle_limit = max_angle > 0
    local ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
    if use_angle_limit then
        hits, num_hits = broadphase_units(player_unit, ray_origin, max_range)
    else
        hits, num_hits = PhysicsWorld_raycast(smart_targeting_extension._physics_world, ray_origin, forward, max_range, "all", "collision_filter", COLLISION_FILTER)
    end

    if not hits or num_hits <= 0 then
        return
    end

    -- cache func
    local game_session = Managers.state.game_session:game_session()
    local unit_spawner_manager = Managers.state.unit_spawner
    local get_game_object_id = unit_spawner_manager.game_object_id
    -- cache params
    local finite_angle = max_angle < 180
    local min_cosine = math_cos(math_rad(max_angle))
    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local canceled_units = tag_context and tag_context.canceled_units or EMPTY_TABLE
    local removed_units = tag_context and tag_context.removed_units or EMPTY_TABLE
    local execution_order_units = mark_context.execution_order_units or EMPTY_TABLE
    local breed_priorities = class_settings and class_settings.breed_priorities or EMPTY_TABLE
    local companion_position, max_ability_charges, remaining_capacitance
    if tag_name == TAG_NAMES.COMPANION_TAG then
        local companion_spawner_extension = context.companion_spawner_extension
        local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
        local companion_unit = companion_units and companion_units[1]
        companion_position = companion_unit and (POSITION_LOOKUP[companion_unit] or Unit_world_position(companion_unit, 1))
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        local companion_spawner_extension = context.companion_spawner_extension
        local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
        local servo_skull_los_node = servo_skull_unit and Unit_node(servo_skull_unit, "skull_aim_center")
        companion_position = servo_skull_los_node and Unit_world_position(servo_skull_unit, servo_skull_los_node)
        local player_ability_extension = context.player_ability_extension
        max_ability_charges = player_ability_extension and player_ability_extension:max_ability_charges("combat_ability")
        remaining_capacitance = player_ability_extension and player_ability_extension:remaining_ability_capacitance("combat_ability")
    end
    local threat_priority = tag_name == TAG_NAMES.COMPANION_TAG and mod_settings.companion_mark_threat_priority or tag_name == TAG_NAMES.SERVO_SKULL_TAG and mod_settings.servo_skull_mark_threat_priority
    local execution_order_priority = tag_name == TAG_NAMES.COMPANION_TAG and mod_settings.execution_order_priority and context.has_execution_order
    local execution_order_force_mark = tag_name == TAG_NAMES.COMPANION_TAG and mod_settings.execution_order_force_mark and context.has_execution_order
    local player_unit_id = get_game_object_id(unit_spawner_manager, player_unit)
    -- init best unit for switch logic
    local best_unit = nil
    local best_unit_tag = nil
    local best_unit_priority = -math.huge
    local best_unit_breed_name = nil
    local best_unit_is_attacking_player = false
    local best_unit_is_dormant_daemonhost = false
    local best_unit_marked_by_execution_order = false
    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit then
        best_unit = marked_unit
        local best_unit_data_extension = ScriptUnit_extension(best_unit, "unit_data_system")
        local best_unit_breed_data = best_unit_data_extension and best_unit_data_extension._breed
        best_unit_breed_name = best_unit_breed_data and best_unit_breed_data.name
        local best_unit_game_object_id = get_game_object_id(unit_spawner_manager, marked_unit)
        local best_unit_attacking_unit_id = get_game_object_field(game_session, best_unit_game_object_id, "target_unit_id")
        best_unit_priority, best_unit_is_dormant_daemonhost = get_breed_priority(best_unit_breed_name, best_unit_breed_data, breed_priorities, best_unit_attacking_unit_id)
        best_unit_marked_by_execution_order = execution_order_units[best_unit]
        best_unit_is_attacking_player = best_unit_attacking_unit_id == player_unit_id
    end

    for i = 1, num_hits do
        local hit_unit, hit_actor
        if use_angle_limit then
            hit_unit = hits[i]
        else
            local hit = hits[i]
            hit_actor = hit[INDEX_ACTOR]
            if not hit_actor then
                goto continue
            end

            hit_unit = Actor_unit(hit_actor)
        end

        -- ignore player unit, already marked unit and dead unit
        if hit_unit == player_unit or hit_unit == marked_unit or canceled_units[hit_unit] or not HEALTH_ALIVE[hit_unit] then
            goto continue
        end

        local hit_unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
        local hit_unit_breed_data = hit_unit_data_extension and hit_unit_data_extension._breed
        -- ignore untaggable unit
        if not hit_unit_breed_data or hit_unit_breed_data.smart_tag_target_type ~= "breed" or hit_unit_breed_data.faction_name == "imperium" or hit_unit_breed_data.unit_template_name ~= "minion" then
            goto continue
        end

        local hit_unit_breed_name = hit_unit_breed_data.name
        local hit_unit_game_object_id = get_game_object_id(unit_spawner_manager, hit_unit)
        local hit_unit_attacking_unit_id = get_game_object_field(game_session, hit_unit_game_object_id, "target_unit_id")
        local hit_unit_priority, hit_unit_is_dormant_daemonhost = get_breed_priority(hit_unit_breed_name, hit_unit_breed_data, breed_priorities, hit_unit_attacking_unit_id)
        local hit_unit_marked_by_execution_order = execution_order_units[hit_unit]
        local hit_unit_is_attacking_player = hit_unit_attacking_unit_id == player_unit_id
        -- filter unit by type and priority
        if hit_unit_priority <= 0 or not is_breed_group_valid(hit_unit_breed_data, class_settings) then
            if not execution_order_force_mark
                or not hit_unit_marked_by_execution_order
                or IGNORE_EXECUTION_ORDER_FORCE_MARK_BREED_NAMES[hit_unit_breed_name]
                or hit_unit_is_dormant_daemonhost
            then
                goto continue
            end
        end

        local hit_unit_score = hit_unit_priority
        local best_unit_score = best_unit_priority
        if execution_order_priority and not IGNORE_EXECUTION_ORDER_PRIORITY_BREED_NAMES[hit_unit_breed_name] and not IGNORE_EXECUTION_ORDER_PRIORITY_BREED_NAMES[best_unit_breed_name] then
            hit_unit_score = hit_unit_score + (hit_unit_marked_by_execution_order and 1000 or 0)
            best_unit_score = best_unit_score + (best_unit_marked_by_execution_order and 1000 or 0)
        end

        if threat_priority and not IGNORE_THREAT_PRIORITY_BREED_NAMES[hit_unit_breed_name] and not IGNORE_THREAT_PRIORITY_BREED_NAMES[best_unit_breed_name] then
            hit_unit_score = hit_unit_score + (hit_unit_is_attacking_player and 100 or 0)
            best_unit_score = best_unit_score + (best_unit_is_attacking_player and 100 or 0)
        end

        if hit_unit_score <= best_unit_score then
            goto continue
        end

        local hit_unit_center_pos
        if use_angle_limit then
            local hit_unit_pose, _ = Unit_box(hit_unit, true)
            hit_unit_center_pos = Matrix4x4_translation(hit_unit_pose)
        else
            hit_unit_center_pos = Actor_world_bounds(hit_actor)
        end
        local to_hit_unit_center = hit_unit_center_pos - ray_origin
        local distance = Vector3_length(to_hit_unit_center)
        -- filter unit by range
        if distance < min_range or distance > max_range then
            goto continue
        end

        if use_angle_limit and finite_angle then
            local hit_direction = Vector3_normalize(to_hit_unit_center)
            local hit_dot = Vector3_dot(forward, hit_direction)
            if hit_dot < min_cosine then
                goto continue
            end
        end

        local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
        if tag_name == TAG_NAMES.ENEMY_TAG then
            if hit_unit_tag then
                goto continue
            end
        elseif tag_name == TAG_NAMES.VETERAN_TAG then
            if hit_unit_is_dormant_daemonhost then
                if hit_unit_tag then
                    goto continue
                end
            else
                if not is_focus_target_tag_target_valid(hit_unit, hit_unit_tag, hit_unit_breed_name, hit_unit_attacking_unit_id, removed_units) then
                    goto continue
                end
            end
        elseif tag_name == TAG_NAMES.COMPANION_TAG then
            if not is_cyber_mastiff_tag_target_valid(hit_unit, hit_unit_tag, hit_unit_breed_name, hit_unit_breed_data, hit_unit_attacking_unit_id, game_session, removed_units, distance, companion_position, hit_unit_center_pos) then
                goto continue
            end
        elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            if not is_servo_skull_tag_target_valid(hit_unit, hit_unit_tag, hit_unit_breed_name, hit_unit_breed_data, hit_unit_attacking_unit_id, game_session, removed_units, companion_position, hit_unit_center_pos, max_ability_charges, remaining_capacitance) then
                goto continue
            end
        end

        local visible
        if tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            visible = is_servo_skull_target_visible(companion_position, hit_unit, fixed_frame)
        elseif tag_name == TAG_NAMES.COMPANION_TAG then
            local half_height = Breed_height(hit_unit, hit_unit_breed_data) * 0.5
            visible = is_cyber_mastiff_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame, hit_unit_tag, hit_unit_marked_by_execution_order)
        else
            local half_height = Breed_height(hit_unit, hit_unit_breed_data) * 0.5
            visible = is_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame)
        end

        if not visible then
            goto continue
        end

        best_unit = hit_unit
        best_unit_tag = hit_unit_tag
        best_unit_priority = hit_unit_priority
        best_unit_breed_name = hit_unit_breed_name
        best_unit_is_attacking_player = hit_unit_is_attacking_player
        best_unit_is_dormant_daemonhost = hit_unit_is_dormant_daemonhost
        best_unit_marked_by_execution_order = hit_unit_marked_by_execution_order

        ::continue::
    end

    if best_unit ~= marked_unit then
        return best_unit, best_unit_tag, best_unit_is_dormant_daemonhost
    end
end

local ENEMY_EXTENTS = {
    chaos_beast_of_nurgle = {
        half_extent_forward = 1.1,
        half_extent_right = 1.5,
    },
    chaos_ogryn_bulwark = {
        half_extent_right = 0.8,
    },
    chaos_ogryn_executor = {
        half_extent_right = 0.9,
    },
    chaos_ogryn_gunner = {
        half_extent_right = 0.8,
    },
    chaos_ogryn_houndmaster = {
        half_extent_right = 1.4,
    },
    chaos_plague_ogryn = {
        half_extent_right = 1.6,
    },
    chaos_spawn = {
        half_extent_right = 1.2,
    },
    cultist_berzerker = {
        half_extent_right = 0.5,
    },
    cultist_mutant = {
        half_extent_right = 1,
    },
    cultist_mutant_mutator = {
        half_extent_right = 1,
    },
    renegade_berzerker = {
        half_extent_right = 0.5,
    },
}
local DISTANCE_EPSILON = 0.4
local MIN_COSINE = math_cos(math_rad(35))
function mod:find_focus_target_switch_melee_target_unit(max_range)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not smart_tag_system then
        return
    end

    local ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
    local hits, num_hits = PhysicsWorld_raycast(smart_targeting_extension._physics_world, ray_origin, forward, max_range, "all", "collision_filter", COLLISION_FILTER)
    if not hits or num_hits <= 0 then
        return
    end

    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local best_unit
    local best_unit_dot = -math.huge
    local best_unit_distance = math.huge
    local best_unit_aim_strict = false
    local best_unit_aim_lenient = false
    local best_unit_aim_outer = false
    local best_unit_x_diff_edge = math.huge
    local best_unit_y_diff_edge = math.huge
    for i = 1, num_hits do
        local hit = hits[i]
        local hit_actor = hit[INDEX_ACTOR]
        if not hit_actor then
            goto continue
        end

        local hit_unit = Actor_unit(hit_actor)
        local hit_position = hit[INDEX_POSITION]
        if hit_unit == player_unit or not HEALTH_ALIVE[hit_unit] then
            goto continue
        end

        local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        -- ignore untaggable unit
        if not breed_data or breed_data.smart_tag_target_type ~= "breed" or breed_data.faction_name == "imperium" or breed_data.unit_template_name ~= "minion" then
            goto continue
        end

        local hit_unit_pose, _ = Unit_box(hit_unit, true)
        local object_right = Matrix4x4_right(hit_unit_pose)
        local object_forward = Matrix4x4_forward(hit_unit_pose)
        local enemy_extents = ENEMY_EXTENTS[breed_data.name] or EMPTY_TABLE
        local half_extent_right = enemy_extents.half_extent_right or breed_data.half_extent_right or 0.3
        local half_extent_forward = enemy_extents.half_extent_forward or breed_data.half_extent_forward or 0.3
        local world_extents_right = object_right * half_extent_right
        local world_extents_forward = object_forward * half_extent_forward
        local hit_unit_center_pos = Actor_world_bounds(hit_actor)
        local to_hit_unit_center = hit_unit_center_pos - ray_origin
        local to_hit_unit_center_direction = Vector3_normalize(hit_unit_center_pos - ray_origin)
        local half_length = math_max(
            math_abs(Vector3_dot(to_hit_unit_center_direction, world_extents_right + world_extents_forward)),
            math_abs(Vector3_dot(to_hit_unit_center_direction, world_extents_right - world_extents_forward))
        )
        local hit_unit_distance = Vector3_length(to_hit_unit_center) - half_length
        if hit_unit_distance > max_range then
            goto continue
        end

        local hit_dot = Vector3_dot(forward, to_hit_unit_center_direction)
        if hit_dot < MIN_COSINE then
            goto continue
        end

        local hit_offset = hit_position - hit_unit_center_pos
        local x_diff = math_abs(Vector3_dot(hit_offset, right))
        local y_diff = math_abs(Vector3_dot(hit_offset, up))
        local half_width = math_max(
            math_abs(Vector3_dot(right, world_extents_right + world_extents_forward)),
            math_abs(Vector3_dot(right, world_extents_right - world_extents_forward))
        )
        local half_height = Breed_height(hit_unit, breed_data) * 0.5
        local x_diff_edge = x_diff - half_width
        local y_diff_edge = y_diff - half_height
        local hit_unit_aim_outer = x_diff_edge <= 0.8 and y_diff_edge <= 0.8
        if not hit_unit_aim_outer then
            goto continue
        end

        local hit_unit_aim_strict = x_diff <= half_width and y_diff <= half_height
        if hit_unit_distance > 3.5 then
            if not hit_unit_aim_strict then
                goto continue
            end

            if best_unit_aim_lenient then
                if best_unit_distance <= 3.5 then
                    goto continue
                end
            elseif best_unit_aim_outer then
                if best_unit_distance <= 2.5 then
                    goto continue
                end
            end
        end

        local hit_unit_aim_lenient = x_diff_edge <= 0.4 and y_diff_edge <= 0.4
        local distance_diff = math_abs(hit_unit_distance - best_unit_distance)
        if best_unit_aim_strict then
            if best_unit_distance > 3.5 then
                if hit_unit_aim_strict then
                    if hit_unit_distance > 3.5 then
                        if distance_diff <= DISTANCE_EPSILON then
                            if hit_dot <= best_unit_dot then
                                goto continue
                            end
                        elseif hit_unit_distance > best_unit_distance then
                            goto continue
                        end
                    end
                elseif hit_unit_aim_lenient then
                    -- Nothing
                elseif hit_unit_aim_outer then
                    if hit_unit_distance > 2.5 then
                        goto continue
                    end
                end
            else
                if distance_diff <= DISTANCE_EPSILON then
                    if hit_unit_aim_strict then
                        if hit_dot <= best_unit_dot then
                            goto continue
                        end
                    else
                        goto continue
                    end
                elseif hit_unit_distance < best_unit_distance then
                    if not hit_unit_aim_lenient then
                        goto continue
                    end
                elseif hit_unit_distance > best_unit_distance then
                    goto continue
                end
            end
        elseif best_unit_aim_lenient then
            if distance_diff <= DISTANCE_EPSILON then
                if hit_unit_aim_strict then
                    -- Nothing
                elseif hit_unit_aim_lenient then
                    if x_diff_edge >= best_unit_x_diff_edge and y_diff_edge >= best_unit_y_diff_edge then
                        goto continue
                    end

                    if hit_dot <= best_unit_dot then
                        goto continue
                    end
                elseif hit_unit_aim_outer then
                    goto continue
                end
            elseif hit_unit_distance < best_unit_distance then
                -- Nothing
            elseif hit_unit_distance > best_unit_distance then
                goto continue
            end
        elseif best_unit_aim_outer then
            if distance_diff <= DISTANCE_EPSILON then
                if hit_unit_aim_lenient then
                    -- Nothing
                elseif hit_unit_aim_outer then
                    if x_diff_edge >= best_unit_x_diff_edge and y_diff_edge >= best_unit_y_diff_edge then
                        goto continue
                    end

                    if hit_dot <= best_unit_dot then
                        goto continue
                    end
                end
            elseif hit_unit_distance < best_unit_distance then
                -- Nothing
            elseif hit_unit_distance > best_unit_distance then
                if not hit_unit_aim_strict then
                    goto continue
                end
            end
        end

        if not is_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame) then
            goto continue
        end

        best_unit = hit_unit
        best_unit_dot = hit_dot
        best_unit_distance = hit_unit_distance
        best_unit_aim_strict = hit_unit_aim_strict
        best_unit_aim_lenient = hit_unit_aim_lenient
        best_unit_aim_outer = hit_unit_aim_outer
        best_unit_x_diff_edge = x_diff_edge
        best_unit_y_diff_edge = y_diff_edge

        ::continue::
    end

    if best_unit then
        local best_unit_tag = smart_tag_system:unit_tag(best_unit)
        return best_unit, best_unit_tag
    end
end

mod:hook_safe(CLASS.PrecisionTargetFinder, "init",
    function(self, is_server, is_local_unit, player, physics_world, unit)
        visibility_raycast_object = PhysicsWorld_make_raycast(physics_world, "closest", "types", "both", "collision_filter", "filter_minion_line_of_sight_check")
    end)
