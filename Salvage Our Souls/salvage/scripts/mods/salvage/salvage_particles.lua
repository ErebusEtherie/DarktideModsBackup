-- salvage_particles.lua
local mod = get_mod("salvage")
mod._salvage_particle_retry_at = mod._salvage_particle_retry_at or {}
mod._salvage_particle_group_world = nil
mod._salvage_particle_group_id = nil
function mod._salvage_particle_time()
local time_manager = Managers and Managers.time
if time_manager and type(time_manager.time) == "function" then
local success, value = pcall(time_manager.time, time_manager, "main")
if success and type(value) == "number" then
return value
end
end
return 0
end
function mod._salvage_release_particle_group()
local world = mod._salvage_particle_group_world
local particle_group = mod._salvage_particle_group_id
if world and particle_group and World and type(World.destroy_particle_group) == "function" then
pcall(World.destroy_particle_group, world, particle_group)
end
mod._salvage_particle_group_world = nil
mod._salvage_particle_group_id = nil
end
function mod._salvage_managed_particle_group(world)
if not world or not GameParameters or GameParameters.destroy_unmanaged_particles ~= true or not World or type(World.create_particle_group) ~= "function" then
return nil
end
if mod._salvage_particle_group_world ~= world then
mod._salvage_release_particle_group()
mod._salvage_particle_group_world = world
end
if not mod._salvage_particle_group_id then
local success, particle_group = pcall(World.create_particle_group, world)
if success and particle_group then
mod._salvage_particle_group_id = particle_group
end
end
return mod._salvage_particle_group_id
end
function mod._salvage_local_player_fx_extension()
local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local unit = player and player.player_unit
if not unit or not ScriptUnit or type(ScriptUnit.has_extension) ~= "function" or not Unit or type(Unit.alive) ~= "function" then
return nil
end
local alive_success, alive = pcall(Unit.alive, unit)
if not alive_success or not alive then
return nil
end
local success, extension = pcall(ScriptUnit.has_extension, unit, "fx_system")
if success and extension then
return extension
end
return nil
end
local function set_particle_variable(world, particle_id, effect_name, variable_name, variable_value)
if not world or not particle_id or not effect_name or not variable_name or not variable_value or not World or type(World.find_particles_variable) ~= "function" or type(World.set_particles_variable) ~= "function" then
return
end
pcall(function()
local variable_index = World.find_particles_variable(world, effect_name, variable_name)
World.set_particles_variable(world, particle_id, variable_index, variable_value)
end)
end
function mod._salvage_create_player_fx_particle(effect_name, position, rotation, scale, optional_variable_name, optional_variable_value)
local fx_extension = mod._salvage_local_player_fx_extension()
if not fx_extension then
return nil
end
local success = false
local particle_id = nil
if type(fx_extension.spawn_particles) == "function" then
if optional_variable_name and optional_variable_value then
success, particle_id = pcall(fx_extension.spawn_particles, fx_extension, effect_name, position, rotation, scale, optional_variable_name, optional_variable_value, true)
if not success or not particle_id then
success, particle_id = pcall(fx_extension.spawn_particles, fx_extension, effect_name, position, rotation, nil, nil, nil, true)
end
else
success, particle_id = pcall(fx_extension.spawn_particles, fx_extension, effect_name, position, rotation, scale, nil, nil, true)
end
end
if (not success or not particle_id) and type(fx_extension.spawn_particles_local) == "function" then
success, particle_id = pcall(fx_extension.spawn_particles_local, fx_extension, effect_name, position, rotation, scale)
end
if (not success or not particle_id) and scale ~= nil and type(fx_extension.spawn_particles_local) == "function" then
success, particle_id = pcall(fx_extension.spawn_particles_local, fx_extension, effect_name, position, rotation, nil)
end
if success and particle_id then
local fx_world = nil
if type(fx_extension) == "table" then
fx_world = rawget(fx_extension, "_world")
end
set_particle_variable(fx_world, particle_id, effect_name, optional_variable_name, optional_variable_value)
mod._salvage_particle_retry_at[effect_name] = nil
return particle_id
end
return nil
end
function mod._salvage_create_particle(world, effect_name, position, rotation, scale, particle_group, optional_variable_name, optional_variable_value)
if not world or not effect_name or not position or not World or type(World.create_particles) ~= "function" then
return nil
end
local now = mod._salvage_particle_time()
local retry_at = mod._salvage_particle_retry_at and mod._salvage_particle_retry_at[effect_name]
if type(retry_at) == "number" and now < retry_at then
return nil
end
local success = false
local particle_id = nil
if particle_group then
success, particle_id = pcall(World.create_particles, world, effect_name, position, rotation, scale, particle_group)
if success and particle_id then
set_particle_variable(world, particle_id, effect_name, optional_variable_name, optional_variable_value)
mod._salvage_particle_retry_at[effect_name] = nil
return particle_id
end
if scale ~= nil then
success, particle_id = pcall(World.create_particles, world, effect_name, position, rotation, nil, particle_group)
if success and particle_id then
set_particle_variable(world, particle_id, effect_name, optional_variable_name, optional_variable_value)
mod._salvage_particle_retry_at[effect_name] = nil
return particle_id
end
end
end
success, particle_id = pcall(World.create_particles, world, effect_name, position, rotation, scale)
if success and particle_id then
set_particle_variable(world, particle_id, effect_name, optional_variable_name, optional_variable_value)
mod._salvage_particle_retry_at[effect_name] = nil
return particle_id
end
if scale ~= nil then
success, particle_id = pcall(World.create_particles, world, effect_name, position, rotation, nil)
if success and particle_id then
set_particle_variable(world, particle_id, effect_name, optional_variable_name, optional_variable_value)
mod._salvage_particle_retry_at[effect_name] = nil
return particle_id
end
end
particle_id = mod._salvage_create_player_fx_particle(effect_name, position, rotation, scale, optional_variable_name, optional_variable_value)
if particle_id then
return particle_id
end
if scale ~= nil then
particle_id = mod._salvage_create_player_fx_particle(effect_name, position, rotation, nil, optional_variable_name, optional_variable_value)
if particle_id then
return particle_id
end
end
mod._salvage_particle_retry_at[effect_name] = now + 0.5
return nil
end
function mod._salvage_reset_particle_runtime()
mod._salvage_release_particle_group()
mod._salvage_particle_retry_at = {}
end
return true
