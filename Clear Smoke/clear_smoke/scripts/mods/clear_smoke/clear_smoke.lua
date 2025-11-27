--------------------------------------
--------------------------------------
--Created by Leer
--Fixed by Xiao
--------------------------------------
--------------------------------------
local mod = get_mod("clear_smoke")

local active_decals = mod:persistent_table("smoke_active_decals")

local DECAL_UNIT_NAME = "content/levels/training_grounds/fx/decal_aoe_indicator"
local PACKAGE_NAME = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local BASE_RADIUS = 10
local BASE_DURATION = 15
local EXTENDED_DURATION = 30
local SMOKE_EFFECT_DURATION = 4
local DELETE_AFTER_DURATION_TIMER = 8

local function get_current_time()
    return Managers.time:time("main")
end

local function has_grenade_tinkerer_talent(unit)
    if not Unit.alive(unit) then return false end

    local player = Managers.state.player_unit_spawn:owner(unit)
    if player then
        local profile = player:profile()
        if profile and profile.archetype and profile.archetype.name == "veteran" then
            return profile.talents and profile.talents["veteran_improved_grenades"]
        end
    end
    return false
end

local function set_decal_color(decal_unit)
    local r = (mod:get("color_r") or 255) / 255
    local g = (mod:get("color_g") or 255) / 255
    local b = (mod:get("color_b") or 255) / 255

    local identity_value = Quaternion.identity()
    Quaternion.set_xyzw(identity_value, r, g, b, 0.5)
    Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", identity_value, true)
    Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", 0.05)
end

local function spawn_radius_decal(position, world, duration)
    if not position then return end

    local decal_unit = World.spawn_unit_ex(world, DECAL_UNIT_NAME, nil, position + Vector3(0, 0, 0.1))
    
    if not Unit.alive(decal_unit) then return end

    local diameter = BASE_RADIUS
    Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, diameter))
    set_decal_color(decal_unit)

    table.insert(active_decals, {
        unit = decal_unit,
        world = world,
        destroy_time = get_current_time() + duration
    })
end

local function create_radius_decal(self)
    if not mod:get("show_radius") then return end
    
    local unit = self._unit
    
    if not Unit.alive(unit) then return end

    local world = self._world or Managers.world:world("level_world")
    local duration = has_grenade_tinkerer_talent(unit) and EXTENDED_DURATION or BASE_DURATION
    
    local position = Unit.local_position(unit, 1)

    if not Managers.package:has_loaded(PACKAGE_NAME) then
        Managers.package:load(PACKAGE_NAME, "clear_smoke", function()
            spawn_radius_decal(position, world, duration)
        end)
    else
        spawn_radius_decal(position, world, duration)
    end
end

mod:hook_safe("ProjectileFxExtension", "destroy", function(self)
    if self._projectile_template and self._projectile_template.name == "smoke_grenade" then
        create_radius_decal(self)
    end
end)

mod.update = function(self, dt)
    if not Managers.time then return end
    
    local t = get_current_time()
    if not t then return end

    for i = #active_decals, 1, -1 do
        local data = active_decals[i]
        if t >= data.destroy_time then
            if Unit.alive(data.unit) then
                World.destroy_unit(data.world, data.unit)
            end
            table.remove(active_decals, i)
        else
            if mod:get("pulse_effect") and Unit.alive(data.unit) then
                local time_left = data.destroy_time - t
                if time_left <= 5 then
                    local pulse = math.sin(t * 12) * 0.5
                    local radius = BASE_RADIUS + pulse
                    Unit.set_local_scale(data.unit, 1, Vector3(radius, radius, radius))
                end
            end
        end
    end
end

function mod.on_game_state_changed(status, state_name)
    if state_name == "StateLoading" then
        for _, data in pairs(active_decals) do
            if Unit.alive(data.unit) then
                World.destroy_unit(data.world, data.unit)
            end
        end
        table.clear(active_decals)
    end
end

function mod.on_unload()
    for _, data in pairs(active_decals) do
        if Unit.alive(data.unit) then
            World.destroy_unit(data.world, data.unit)
        end
    end
    table.clear(active_decals)
end

mod:hook("SmokeFogSystem", "update", function(func, self, context, dt, t, ...)
    local is_server = self._is_server
    local unit_to_extension_map = self._unit_to_extension_map
    local stopped_particles_map = self._stopped_particles_map

    for unit, extension in pairs(unit_to_extension_map) do
        local remaining_duration = extension:remaining_duration(t)
        local remaining_effect_duration = remaining_duration - SMOKE_EFFECT_DURATION

        if not mod:get("remove_smoke") then
            if remaining_effect_duration <= 0 and not stopped_particles_map[unit] then
                Unit.flow_event(unit, "lua_stop_spawning_particles")
            elseif remaining_effect_duration > 0 and stopped_particles_map[unit] then
                Unit.flow_event(unit, "lua_start_spawning_particles")
            end
        else
            Unit.flow_event(unit, "lua_stop_spawning_particles")
        end

        if remaining_duration <= 0 and not extension.is_expired then
            stopped_particles_map[unit] = true
            extension.is_expired = true
        elseif remaining_duration > 0 and extension.is_expired then
            stopped_particles_map[unit] = nil
            extension.is_expired = false
        end

        if is_server and remaining_duration <= -DELETE_AFTER_DURATION_TIMER then
            Managers.state.unit_spawner:mark_for_deletion(unit)
        end
    end

    if is_server then
        self:_check_unit_collisions(t)
    end

    SmokeFogSystem.super.update(self, context, dt, t, ...)
end)