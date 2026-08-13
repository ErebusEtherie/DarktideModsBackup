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
local GameSession                          = GameSession
local PhysicsWorld                         = PhysicsWorld
local Actor_unit                           = Actor.unit
local Actor_world_bounds                   = Actor.world_bounds
local Unit_box                             = Unit.box
local Unit_node                            = Unit.node
local Unit_world_position                  = Unit.world_position
local PhysicsWorld_raycast                 = PhysicsWorld.raycast
local Raycast_cast                         = Raycast.cast
local ScriptUnit_extension                 = ScriptUnit.extension
local math_abs                             = math.abs
local math_max                             = math.max
local math_cos                             = math.cos
local math_rad                             = math.rad
local Vector3_dot                          = Vector3.dot
local Vector3_normalize                    = Vector3.normalize
local Vector3_length                       = Vector3.length
local Vector3_distance                     = Vector3.distance
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
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "both", "collision_filter", "filter_minion_line_of_sight_check")
    end
end

function mod:destroy_visibility_raycast_objects()
    visibility_raycast_object = nil
end

local function is_daemonhost_aggroed(unit)
    local game_session   = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    local stage          = GameSession.game_object_field(game_session, game_object_id, "stage")
    return type(stage) == "number" and stage == 6
end

local function is_target_aggroed(unit)
    local game_session = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    local target_unit_id = GameSession.game_object_field(game_session, game_object_id, "target_unit_id")
    return target_unit_id ~= -1
end

local function get_breed_priority(unit, breed_data, breed_priorities)
    local breed_name = breed_data and breed_data.name
    if breed_data and breed_data.tags.witch then
        if is_target_aggroed(unit) then
            return breed_priorities[breed_name] or 0, false
        else
            return breed_priorities[breed_name .. "_passive"] or 0, true
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

local function is_ritual_started(ritualist_unit)
    local game_session = Managers.state.game_session:game_session()
    local ritualist_id = Managers.state.unit_spawner:game_object_id(ritualist_unit)
    local daemonhost_id = GameSession.game_object_field(game_session, ritualist_id, "target_unit_id")
    if not daemonhost_id or daemonhost_id == -1 then
        return false
    end

    local stage = GameSession.game_object_field(game_session, daemonhost_id, "stage")
    return type(stage) == "number" and stage > 1
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

-- Check if Tagged Target Unit can be Marked with Current Tag
function mod:is_target_valid(tag_name, target_tag, target_unit, target_breed_data)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        local target_tag_name = target_tag and target_tag._template.name
        if target_tag_name == TAG_NAMES.VETERAN_TAG then
            local tag_context = mark_context[tag_name]
            local removed_units = tag_context.removed_units
            if removed_units[target_unit] then
                return false
            end
        end

        if not target_breed_data then
            return false
        end

        -- do not target same pouncable unit or unit tagged by focus target
        if target_tag_name == TAG_NAMES.COMPANION_TAG then
            local pounce_setting = target_breed_data.companion_pounce_setting
            local pounce_action = pounce_setting and pounce_setting.companion_pounce_action
            if pounce_action == "human" then
                return false
            end
        end

        -- check if target is aggroed or if ritual is started
        local breed_name = target_breed_data.name
        if breed_name == "chaos_mutator_ritualist" then
            if not is_ritual_started(target_unit) then
                return false
            end
        elseif breed_name == "cultist_ritualist" then
            -- do nothing
        else
            if mod_settings.companion_mark_ignore_unaggroed and not is_target_aggroed(target_unit) then
                return false
            end
        end

        -- check if target is within range limitation
        local breed_settings = companion_cancel_mark_breed_settings[breed_name]
        local player_max_distance
        local companion_range_limitation
        if breed_settings and breed_settings.override then
            player_max_distance = breed_settings.max_distance or 0
            companion_range_limitation = breed_settings.range_limitation or 0
        else
            player_max_distance = 0
            companion_range_limitation = mod_settings.companion_range_limitation or 0
        end

        if player_max_distance > 0 or companion_range_limitation > 0 then
            local POSITION_LOOKUP = POSITION_LOOKUP
            local target_position = POSITION_LOOKUP[target_unit] or Unit_world_position(target_unit, 1)
            if not target_position then
                return false
            end

            if player_max_distance > 0 then
                local player = context.player
                local player_unit = player and player.player_unit
                if not player_unit then
                    return false
                end

                local player_position = POSITION_LOOKUP[player_unit] or Unit_world_position(player_unit, 1)
                if not player_position then
                    return false
                end

                if Vector3_distance_squared(player_position, target_position) > player_max_distance * player_max_distance then
                    return false
                end
            end

            if companion_range_limitation > 0 then
                local companion_spawner_extension = context.companion_spawner_extension
                local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
                local companion_unit = companion_units and companion_units[1]
                if not companion_unit then
                    return false
                end

                local companion_unit_position = POSITION_LOOKUP[companion_unit] or Unit_world_position(companion_unit, 1)
                if not companion_unit_position then
                    return false
                end

                if Vector3_distance_squared(companion_unit_position, target_position) > companion_range_limitation * companion_range_limitation then
                    return false
                end
            end
        end
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        local target_tag_name = target_tag and target_tag._template.name
        if target_tag_name == TAG_NAMES.COMPANION_TAG or target_tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            local tag_context = mark_context[tag_name]
            local removed_units = tag_context.removed_units
            if removed_units[target_unit] then
                return false
            end
        end

        if not target_breed_data then
            return false
        end

        local breed_name = target_breed_data.name
        if breed_name ~= "cultist_ritualist" and mod_settings.focus_target_ignore_unaggroed and not is_target_aggroed(target_unit) then
            return false
        end

        if not mod:can_focus_target_overwrite(target_unit, target_tag) then
            return false
        end
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        -- do not target unit tagged by focus target
        local target_tag_name = target_tag and target_tag._template.name
        if target_tag_name == TAG_NAMES.VETERAN_TAG then
            local tag_context = mark_context[tag_name]
            local removed_units = tag_context.removed_units
            if removed_units[target_unit] then
                return false
            end
        end

        if not target_breed_data then
            return false
        end

        -- check if target is aggroed or if ritual is started
        local breed_name = target_breed_data.name
        if breed_name == "chaos_mutator_ritualist" then
            if not is_ritual_started(target_unit) then
                return false
            end
        elseif breed_name == "cultist_ritualist" then
            -- do nothing
        else
            if mod_settings.servo_skull_mark_ignore_unaggroed and not is_target_aggroed(target_unit) then
                return false
            end
        end

        local companion_spawner_extension = context.companion_spawner_extension
        local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
        if not servo_skull_unit then
            return false
        end

        -- check if target is within range limitation
        local breed_settings = noospheric_command_breed_settings[breed_name]
        local servo_skull_range_limitation
        if breed_settings and breed_settings.override then
            servo_skull_range_limitation = breed_settings.range_limitation or 0
        else
            servo_skull_range_limitation = mod_settings.servo_skull_range_limitation or 0
        end

        if servo_skull_range_limitation > 0 then
            local POSITION_LOOKUP = POSITION_LOOKUP
            local servo_skull_position = POSITION_LOOKUP[servo_skull_unit] or Unit_world_position(servo_skull_unit, 1)
            if not servo_skull_position then
                return false
            end

            local target_position = POSITION_LOOKUP[target_unit] or Unit_world_position(target_unit, 1)
            if not target_position then
                return false
            end

            if Vector3_distance_squared(servo_skull_position, target_position) > servo_skull_range_limitation * servo_skull_range_limitation then
                return false
            end
        end

        -- check if capacitance is sufficient
        if mod_settings.capacitance_retention and context.has_noospheric_command then
            local player_ability_extension = context.player_ability_extension
            if not player_ability_extension then
                return false
            end

            local capacitance_retention_threshold
            if breed_settings and breed_settings.override then
                capacitance_retention_threshold = breed_settings.threshold or 0
            end

            if capacitance_retention_threshold == nil then
                if target_breed_data.is_boss then
                    capacitance_retention_threshold = mod_settings.capacitance_retention_boss_threshold
                elseif target_breed_data.tags.special then
                    capacitance_retention_threshold = mod_settings.capacitance_retention_special_threshold
                else
                    capacitance_retention_threshold = mod_settings.capacitance_retention_elite_threshold
                end
            end

            local max_ability_charges = player_ability_extension:max_ability_charges("combat_ability")
            local remaining_capacitance = player_ability_extension:remaining_ability_capacitance("combat_ability")
            if 1 / capacitance_retention_threshold < 0 then
                capacitance_retention_threshold = max_ability_charges + capacitance_retention_threshold
            end

            if remaining_capacitance < capacitance_retention_threshold then
                return false
            end
        end
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        if target_tag then
            return false
        end
    end

    return true
end

function mod:is_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame)
    if not visibility_raycast_object then
        return false
    end

    local cached_visibility = visibility_cache[hit_unit]
    local last_check_frame = visibility_check_frame[hit_unit]
    if cached_visibility ~= nil and fixed_frame - last_check_frame <= 5 then
        return cached_visibility
    end

    mod.num_visibility_checks_this_frame = mod.num_visibility_checks_this_frame + 1
    if mod.num_visibility_checks_this_frame > MAX_VISIBILITY_CHECKS_PER_FRAME then
        return false
    end

    local ray_to_target_center = hit_unit_center_pos - ray_origin
    local ray_to_target_top = ray_to_target_center + up * half_height * 2 / 3
    local hit_top = Raycast_cast(visibility_raycast_object, ray_origin, Vector3_normalize(ray_to_target_top), Vector3_length(ray_to_target_top))
    if not hit_top then
        visibility_cache[hit_unit] = true
        visibility_check_frame[hit_unit] = fixed_frame
        return true
    end

    local hit_center = Raycast_cast(visibility_raycast_object, ray_origin, Vector3_normalize(ray_to_target_center), Vector3_length(ray_to_target_center))
    visibility_cache[hit_unit] = not hit_center
    visibility_check_frame[hit_unit] = fixed_frame
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

function mod:is_servo_skull_target_visible(target_unit, fixed_frame, force_check)
    if not visibility_raycast_object then
        return false
    end

    local smoke_fog_system = context.smoke_fog_system
    if not smoke_fog_system then
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

    local servo_skull_data_extension = ScriptUnit_extension(servo_skull_unit, "unit_data_system")
    local servo_skull_breed_data = servo_skull_data_extension and servo_skull_data_extension._breed
    if not servo_skull_breed_data then
        return false
    end

    local line_of_sight_data = servo_skull_breed_data.line_of_sight_data
    local first_line_of_sight_data = line_of_sight_data[1]
    local from_node, to_node = first_line_of_sight_data.from_node, first_line_of_sight_data.to_node
    local los_from_node = Unit_node(servo_skull_unit, from_node)
    local los_to_node = Unit_node(target_unit, to_node)
    local los_from_position = Unit_world_position(servo_skull_unit, los_from_node)
    local los_to_position = Unit_world_position(target_unit, los_to_node)
    local to_los_position = los_to_position - los_from_position
    local los_direction = Vector3_normalize(to_los_position)
    local los_distance = Vector3_length(to_los_position)

    local hit = Raycast_cast(visibility_raycast_object, los_from_position, los_direction, los_distance)
    servo_skull_visibility_cache[target_unit] = not hit
    servo_skull_visibility_check_frame[target_unit] = fixed_frame
    return not hit
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

function mod:find_target_unit_custom(type, min_range, max_range, max_angle, tag_name, tag_context, class_settings, is_execution_order_priority, marked_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not smart_tag_system then
        return nil
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
        return nil
    end

    local finite_angle = max_angle < 180
    local max_cosine = math_cos(math_rad(max_angle))
    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local canceled_units = tag_context and tag_context.canceled_units or EMPTY_TABLE
    local breed_priorities = class_settings and class_settings.breed_priorities or EMPTY_TABLE
    local execution_order_units = mark_context.execution_order_units or EMPTY_TABLE
    local best_unit = nil
    local best_unit_tag = nil
    local best_unit_priority = -math.huge
    local best_unit_is_dormant_daemonhost = false
    local best_unit_marked_by_execution_order = false
    local best_unit_dot = -math.huge
    local best_unit_distance = math.huge
    -- init best unit for switch logic
    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit then
        best_unit = marked_unit
        local unit_data_extension = ScriptUnit_extension(best_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        best_unit_priority, best_unit_is_dormant_daemonhost = get_breed_priority(best_unit, breed_data, breed_priorities)
        best_unit_marked_by_execution_order = not not execution_order_units[best_unit]
    end

    for i = 1, num_hits do
        local hit_unit, hit_position, hit_actor
        if use_angle_limit then
            hit_unit = hits[i]
        else
            local hit = hits[i]
            hit_actor = hit[INDEX_ACTOR]
            if not hit_actor then
                goto continue
            end

            hit_unit = Actor_unit(hit_actor)
            hit_position = hit[INDEX_POSITION]
        end

        -- ignore player unit, already marked unit and dead unit
        if hit_unit == player_unit or hit_unit == marked_unit or canceled_units[hit_unit] or not HEALTH_ALIVE[hit_unit] then
            goto continue
        end

        local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        -- ignore untaggable unit
        if not breed_data or breed_data.smart_tag_target_type ~= "breed" then
            goto continue
        end

        local hit_unit_pose, _ = Unit_box(hit_unit, true)
        local object_right = Matrix4x4_right(hit_unit_pose)
        local object_forward = Matrix4x4_forward(hit_unit_pose)
        local world_extents_right = object_right * (breed_data.half_extent_right or 0.3)
        local world_extents_forward = object_forward * (breed_data.half_extent_forward or 0.3)
        local half_width = math_max(
            math_abs(Vector3_dot(right, world_extents_right + world_extents_forward)),
            math_abs(Vector3_dot(right, world_extents_right - world_extents_forward))
        )
        local hit_unit_center_pos
        if use_angle_limit then
            local afro_node = Unit_node(hit_unit, "r_afro")
            if afro_node then
                hit_unit_center_pos = Unit_world_position(hit_unit, afro_node)
            else
                hit_unit_center_pos = Matrix4x4_translation(hit_unit_pose)
            end
        else
            hit_unit_center_pos = Actor_world_bounds(hit_actor)
        end
        local half_height = Breed_height(hit_unit, breed_data) * 0.5
        local to_center = hit_unit_center_pos - ray_origin
        local distance = Vector3_length(to_center) - half_width
        -- filter unit by range
        if distance < min_range or distance > max_range then
            goto continue
        end

        if type == "auto" then
            local hit_unit_priority, hit_unit_is_dormant_daemonhost = get_breed_priority(hit_unit, breed_data, breed_priorities)
            local hit_unit_marked_by_execution_order = not not execution_order_units[hit_unit]
            -- filter unit by type and priority
            if hit_unit_priority <= 0 or not is_breed_group_valid(breed_data, class_settings) then
                local breed_name = breed_data.name
                if not is_execution_order_priority
                    or not mod_settings.execution_order_force_mark
                    or not hit_unit_marked_by_execution_order
                    or breed_name == "chaos_poxwalker_bomber"
                    or breed_name == "chaos_ogryn_houndmaster"
                    or hit_unit_is_dormant_daemonhost
                then
                    goto continue
                end
            end

            if is_execution_order_priority then
                if hit_unit_marked_by_execution_order == best_unit_marked_by_execution_order then
                    if hit_unit_priority <= best_unit_priority then
                        goto continue
                    end
                elseif best_unit_marked_by_execution_order then
                    goto continue
                end
            else
                if hit_unit_priority <= best_unit_priority then
                    goto continue
                end
            end

            if use_angle_limit and finite_angle then
                local hit_direction = Vector3_normalize(to_center)
                local hit_dot = Vector3_dot(forward, hit_direction)
                if hit_dot < max_cosine then
                    goto continue
                end
            end

            local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
            if tag_name == TAG_NAMES.VETERAN_TAG and hit_unit_is_dormant_daemonhost then
                if not mod:is_target_valid(TAG_NAMES.ENEMY_TAG, hit_unit_tag, hit_unit, breed_data) then
                    goto continue
                end
            else
                if not mod:is_target_valid(tag_name, hit_unit_tag, hit_unit, breed_data) then
                    goto continue
                end
            end

            local visible
            if tag_name == TAG_NAMES.SERVO_SKULL_TAG then
                visible = mod:is_servo_skull_target_visible(hit_unit, fixed_frame)
            else
                visible = mod:is_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame)
            end

            if not visible then
                goto continue
            end

            best_unit = hit_unit
            best_unit_tag = hit_unit_tag
            best_unit_priority = hit_unit_priority
            best_unit_is_dormant_daemonhost = hit_unit_is_dormant_daemonhost
            best_unit_marked_by_execution_order = hit_unit_marked_by_execution_order
        elseif type == "focus_target_melee" then
            if best_unit and best_unit_distance <= 3.5 and distance > 3.5 then
                goto continue
            end

            local hit_offset = hit_position - hit_unit_center_pos
            local x_diff_no_abs = Vector3_dot(hit_offset, right)
            local x_diff = math_abs(x_diff_no_abs)
            local y_diff = math_abs(Vector3_dot(hit_offset, up))
            if x_diff > half_width * 1.5 + 1 or y_diff > half_height + 1 then
                goto continue
            end

            local hit_direction = Vector3_normalize(to_center)
            local hit_dot = Vector3_dot(forward, hit_direction)
            if hit_dot < 0.7 or best_unit and (hit_dot <= best_unit_dot or x_diff > half_width or y_diff > half_height) then
                goto continue
            end

            if not mod:is_target_visible(ray_origin, up, hit_unit_center_pos, half_height, hit_unit, fixed_frame) then
                goto continue
            end

            best_unit = hit_unit
            best_unit_tag = smart_tag_system:unit_tag(hit_unit)
            best_unit_dot = hit_dot
            best_unit_distance = distance
            if x_diff <= half_width * 1.5 + 0.5 and y_diff <= half_height + 0.5 then
                break
            end
        end

        ::continue::
    end

    if best_unit ~= marked_unit then
        return best_unit, best_unit_tag, best_unit_is_dormant_daemonhost
    end

    return nil, nil, nil
end

function mod:is_dormant_daemonhost(target_unit)
    local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    if breed_data and breed_data.tags.witch and not is_target_aggroed(target_unit) then
        return true
    end

    return false
end

function mod:is_noospheric_command_boost_breed_valid(target_unit)
    local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    if not breed_data then
        return false
    end

    if breed_data.tags.witch and not is_target_aggroed(target_unit) then
        return false
    end

    local breed_name = breed_data.name
    local breed_settings = noospheric_command_breed_settings[breed_name]
    if breed_settings and breed_settings.override then
        return breed_settings.toggle
    end

    if breed_data.is_boss then
        return mod_settings.noospheric_command_boost_boss
    elseif breed_data.tags.special then
        return mod_settings.noospheric_command_boost_special
    else
        return mod_settings.noospheric_command_boost_elite
    end
end

mod:hook_safe(CLASS.PrecisionTargetFinder, "init",
    function(self, is_server, is_local_unit, player, physics_world, unit)
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "both", "collision_filter", "filter_minion_line_of_sight_check")
    end)
