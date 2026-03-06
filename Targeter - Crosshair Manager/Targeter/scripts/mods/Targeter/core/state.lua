-- File: Targeter/scripts/mods/Targeter/core/state.lua
-- Per-frame acquisition (raycast) to determine target lock / weakspot state.

local mod = get_mod("Targeter")
if not mod then return end

local Breed = require("scripts/utilities/breed")
local HitZone = require("scripts/utilities/attack/hit_zone")

local MIN_DISTANCE, MAX_DISTANCE = 1.0, 50.0
local HIT_IDX_DISTANCE, HIT_IDX_ACTOR = 2, 4

local WEAKSPOT_TYPES = {
    headshot = true,
    weakspot = true,
    explosive_backpack = true,
    protected = true,
    protected_weakspot = true
}

local function is_weakspot(breed, hit_zone_name)
    local weakspot_types = breed and breed.hit_zone_weakspot_types
    local weakspot_type = weakspot_types and hit_zone_name and weakspot_types[hit_zone_name]
    return weakspot_type and WEAKSPOT_TYPES[weakspot_type] or false
end

local ScriptUnit_has_extension = ScriptUnit.has_extension
local Actor_unit = Actor.unit
local Unit_alive = Unit.alive
local Unit_world_position = Unit.world_position
local Unit_world_rotation = Unit.world_rotation
local Quaternion_forward = Quaternion.forward
local PhysicsWorld_raycast = PhysicsWorld.raycast
local HitZone_get_name = HitZone.get_name
local Breed_is_minion = Breed.is_minion
local Managers = Managers

mod:hook_safe(CLASS.PlayerUnitFirstPersonExtension, "fixed_update", function(self, arg1, arg2, arg3)
    if mod.game_mode_is_hub then
        return
    end

    local dt = (type(arg1) == "number" and arg1)
        or (type(arg2) == "number" and arg2)
        or self._fixed_time_step

    if not dt then
        local time_manager = Managers and Managers.time
        dt = time_manager and
            (time_manager:delta_time("gameplay") or time_manager:delta_time("ui") or time_manager:delta_time("main")) or
            0.0167
    end

    local trace_interval = mod._trace_interval or 0.03333333333 -- (1 / 30)
    local trace_accum = (mod._trace_accum or 0) + dt
    if trace_accum < trace_interval then
        mod._trace_accum = trace_accum
        return
    end
    mod._trace_accum = trace_accum - trace_interval

    mod.crosshair_state = "default"

    local shoot_position, shoot_direction = nil, nil
    if mod.get_shooting_vector then
        shoot_position, shoot_direction = mod.get_shooting_vector()
    end

    if not (shoot_position and shoot_direction) then
        local fpu = self._first_person_unit
        if fpu and Unit_alive(fpu) then
            shoot_position = Unit_world_position(fpu, 1)
            shoot_direction = Quaternion_forward(Unit_world_rotation(fpu, 1))
        end
    end

    local physics_world = self._physics_world
        or (self._footstep_context and self._footstep_context.physics_world)

    if not physics_world then
        local world_manager = Managers and Managers.world
        local level_world = world_manager and world_manager:world("level_world")
        physics_world = level_world and World.physics_world(level_world)
    end

    if not (shoot_position and shoot_direction and physics_world) then
        return
    end

    local hits = PhysicsWorld_raycast(physics_world, shoot_position, shoot_direction, MAX_DISTANCE, "all",
        "collision_filter", "filter_debug_unit_selector")

    if not hits then return end

    local closest_hit, closest_distance = nil, MAX_DISTANCE
    for i = 1, #hits do
        local hit = hits[i]
        local distance = hit[HIT_IDX_DISTANCE]
        local actor = hit[HIT_IDX_ACTOR]
        local unit = actor and Actor_unit(actor)
        if unit and unit ~= self._unit and distance > MIN_DISTANCE and distance < closest_distance then
            closest_hit = hit
            closest_distance = distance
        end
    end

    if not closest_hit then return end

    local hit_actor = closest_hit[HIT_IDX_ACTOR]
    local hit_unit = Actor_unit(hit_actor)

    local health_extension = ScriptUnit_has_extension(hit_unit, "health_system")
    if not (health_extension and health_extension:is_alive()) then return end

    local target_unit_data_extension = ScriptUnit_has_extension(hit_unit, "unit_data_system")
    if not target_unit_data_extension then return end

    local breed = target_unit_data_extension:breed()
    if not (breed and Breed_is_minion(breed)) then return end

    mod.crosshair_state = "target_locked"

    local hit_zone_name = HitZone_get_name(hit_unit, hit_actor)
    if is_weakspot(breed, hit_zone_name) then
        mod.crosshair_state = "weakspot_locked"
    end
end)
