--[[
Big thanks and CREDIT to LeerH - some of this code is from Clear Smoke, which I recommend using for the Danger Zone circle
or to remove the smoke effect entirely.
]]
local mod = get_mod("vfx_swapper")
local smoke_effect_duration = 2

mod._smoke_fog_particles = mod:persistent_table("vfx_swapper_smoke_fog_particles")

local _replace_smoke_vfx = nil

mod.refresh_smoke_fog_vfx = function()
    _replace_smoke_vfx = mod:get("replace_smoke_grenade_vfx")
end
mod.refresh_smoke_fog_vfx()

local function spawn_ring_particles(world, vfx_name, center, radius)
    local particle_ids = {}
    particle_ids[#particle_ids + 1] = World.create_particles(world, vfx_name, center)
    local ring_configs = {
        { fraction = 0.55, base_count = 15},  -- inner ring
        { fraction = 0.90, base_count = 30 },  -- outer ring
    }

    for _, ring in ipairs(ring_configs) do
        local ring_radius = radius * ring.fraction
        -- Scale count with radius: larger smoke = more particles per ring
        local count = math.max(ring.base_count, math.floor(ring.base_count * (radius / 4.5)))
        local angle_step = (2 * math.pi) / count

        for i = 0, count - 1 do
            local angle = angle_step * i
            local offset_x = math.cos(angle) * ring_radius
            local offset_y = math.sin(angle) * ring_radius
            local pos = Vector3(center.x + offset_x, center.y + offset_y, center.z)
            particle_ids[#particle_ids + 1] = World.create_particles(world, vfx_name, pos)
        end
    end
    return particle_ids
end

local function stop_all_particles(world, particle_ids)
    for _, pid in ipairs(particle_ids) do
        World.stop_spawning_particles(world, pid)
    end
end

mod:hook_safe("SmokeFogSystem", "on_add_extension", function(self, world, unit, extension_name, extension_init_data, ...)
    if not mod._smoke_package_loaded or _replace_smoke_vfx == "DEFAULT" then
        return
    end
    Unit.flow_event(unit, "lua_stop_spawning_particles")

    local extension = self._unit_to_extension_map[unit]
    local radius = extension and extension.outer_radius or 5.5
    -- mod:echo(tostring(extension) .. " radius: " .. tostring(radius))
    -- for k, v in pairs(extension) do
    --     mod:echo("extension." .. tostring(k) .. " = " .. tostring(v))
    -- end

    local position = Unit.local_position(unit, 1)
    local particle_ids = spawn_ring_particles(world, _replace_smoke_vfx, position, radius)

    mod._smoke_fog_particles[unit] = {
        world = world,
        particle_ids = particle_ids,
        radius = radius,
        stopped = false,
    }
end)

mod:hook("SmokeFogSystem", "update", function(func, self, context, dt, t, ...)
    if not mod._smoke_package_loaded or _replace_smoke_vfx == "DEFAULT" then
        return func(self, context, dt, t, ...)
    end
    local unit_to_extension_map = self._unit_to_extension_map

    for unit, particle_data in pairs(mod._smoke_fog_particles) do
        local extension = unit_to_extension_map[unit]

        if not extension then
            stop_all_particles(particle_data.world, particle_data.particle_ids)
            mod._smoke_fog_particles[unit] = nil
        else
            local remaining_duration = extension:remaining_duration(t)
            local remaining_effect_duration = remaining_duration - smoke_effect_duration
            if remaining_effect_duration <= 0 and not particle_data.stopped then
                stop_all_particles(particle_data.world, particle_data.particle_ids)
                particle_data.stopped = true
            elseif remaining_effect_duration > 0 and particle_data.stopped then
                local position = Unit.local_position(unit, 1)
                local radius = extension.outer_radius or particle_data.radius 
                particle_data.particle_ids = spawn_ring_particles(particle_data.world, _replace_smoke_vfx, position, radius)
                particle_data.radius = radius
                particle_data.stopped = false
            end
            Unit.flow_event(unit, "lua_stop_spawning_particles")
        end
    end

    return func(self, context, dt, t, ...)
end)

mod:hook_safe("SmokeFogSystem", "on_remove_extension", function(self, removed_unit, extension_name)
    local particle_data = mod._smoke_fog_particles[removed_unit]
    if particle_data then
        stop_all_particles(particle_data.world, particle_data.particle_ids)
        mod._smoke_fog_particles[removed_unit] = nil
    end
end)
