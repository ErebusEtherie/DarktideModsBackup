-- valkyrie_steady_camera.lua
local STEADY_CAMERA_FORWARD_OFFSET = -1.2
local STEADY_CAMERA_VERTICAL_FOV = math.rad(43)
local M = {}
function M.init(ctx)
local ScriptWorld = ctx.ScriptWorld
local MissionIntroViewSettings = ctx.MissionIntroViewSettings
local Missions = ctx.Missions
local steady_camera_locked_unit = nil
local steady_camera_locked_position = nil
local steady_camera_locked_rotation = nil
local steady_camera_locked_fov = nil
function M.clear_state()
steady_camera_locked_unit = nil
steady_camera_locked_position = nil
steady_camera_locked_rotation = nil
steady_camera_locked_fov = nil
end
function M.is_expeditions_intro_level(intro_level)
local levels = MissionIntroViewSettings.intro_levels_by_zone_id
local expedition_level = levels and levels.expeditions
return intro_level and expedition_level and intro_level.level_name == expedition_level.level_name
end
function M.default_intro_level_with_package()
local levels = MissionIntroViewSettings.intro_levels_by_zone_id
local default_intro_level = levels and levels.default
if not default_intro_level then
return nil, nil
end
return default_intro_level, {
is_level_package = true,
name = default_intro_level.level_name,
}
end
local function is_expedition_mission_name(mission_name)
local mission = mission_name and Missions[mission_name]
return mission and mission.zone_id == "expeditions"
end
function M.should_force_default_intro_level(mission_name)
return ctx.should_steady_camera() and (is_expedition_mission_name(mission_name) or ctx.is_expedition_start(ctx.get_mechanism_data()))
end
function M.is_intro_world_spawner(world_spawner)
return ctx.in_mission_intro() and ctx.active_intro_view() and world_spawner and ctx.active_intro_view()._world_spawner == world_spawner
end
function M.spawner()
local active_intro_view = ctx.active_intro_view()
return active_intro_view and active_intro_view._world_spawner
end
function M.active_for(world_spawner)
return ctx.should_steady_camera() and M.is_intro_world_spawner(world_spawner)
end
function M.camera(world_spawner)
if not world_spawner then
return nil, nil
end
local camera = world_spawner.camera and world_spawner:camera() or world_spawner._camera
local camera_unit = world_spawner.camera_unit and world_spawner:camera_unit() or world_spawner._camera_unit
return camera, camera_unit
end
local function set_world_spawner_camera(world_spawner, camera_unit, fov)
if not world_spawner or not ctx.unit_alive(camera_unit) then
return
end
local viewport = world_spawner._viewport
if viewport then
ScriptWorld.change_camera_unit(viewport, camera_unit, false)
end
local camera = Unit.camera(camera_unit, "camera")
if not camera then
return
end
Camera.set_data(camera, "unit", camera_unit)
world_spawner._camera = camera
world_spawner._camera_unit = camera_unit
world_spawner._camera_animation_data = nil
if fov then
Camera.set_vertical_fov(camera, fov)
world_spawner._start_camera_fov = math.deg(fov)
end
end
local function steady_camera_pulled_position(position, rotation)
return position + Quaternion.forward(rotation) * STEADY_CAMERA_FORWARD_OFFSET
end
local function steady_camera_spawn_centroid()
local active_intro_view = ctx.active_intro_view()
local spawn_slots = active_intro_view and active_intro_view._spawn_slots
if not spawn_slots or #spawn_slots == 0 then
return nil
end
local position_sum = Vector3.zero()
local count = 0
local max_slots = math.min(ctx.max_occupants, #spawn_slots)
for i = 1, max_slots do
local slot = spawn_slots[i]
local spawn_point_unit = slot and slot.spawn_point_unit
if ctx.unit_alive(spawn_point_unit) then
position_sum = position_sum + Unit.world_position(spawn_point_unit, 1)
count = count + 1
end
end
if count == 0 then
return nil
end
return position_sum * (1 / count)
end
local function steady_camera_can_lock(camera_unit)
local centroid = steady_camera_spawn_centroid()
if not centroid or not ctx.unit_alive(camera_unit) then
return false
end
local camera_position = Unit.world_position(camera_unit, 1)
local distance = Vector3.distance(camera_position, centroid)
return distance <= 12
end
function M.ensure(world_spawner)
if not M.active_for(world_spawner) then
return
end
if ctx.unit_alive(steady_camera_locked_unit) then
return
end
local camera, camera_unit = M.camera(world_spawner)
if not camera or not ctx.unit_alive(camera_unit) then
return
end
if not steady_camera_can_lock(camera_unit) then
return
end
local unit_spawner = world_spawner.unit_spawner and world_spawner:unit_spawner() or world_spawner._unit_spawner
if not unit_spawner or not unit_spawner.spawn_unit then
return
end
local rotation = Unit.world_rotation(camera_unit, 1)
local position = steady_camera_pulled_position(Unit.world_position(camera_unit, 1), rotation)
local fov = STEADY_CAMERA_VERTICAL_FOV
local locked_unit = unit_spawner:spawn_unit("core/units/camera", position, rotation)
if not ctx.unit_alive(locked_unit) then
return
end
steady_camera_locked_unit = locked_unit
steady_camera_locked_position = Vector3Box(position)
steady_camera_locked_rotation = QuaternionBox(rotation)
steady_camera_locked_fov = fov
set_world_spawner_camera(world_spawner, locked_unit, fov)
end
function M.apply()
local world_spawner = M.spawner()
if not M.active_for(world_spawner) then
M.clear_state()
return
end
M.ensure(world_spawner)
if not ctx.unit_alive(steady_camera_locked_unit) or not steady_camera_locked_position or not steady_camera_locked_rotation then
M.clear_state()
return
end
local position = steady_camera_locked_position:unbox()
local rotation = steady_camera_locked_rotation:unbox()
Unit.set_local_position(steady_camera_locked_unit, 1, position)
Unit.set_local_rotation(steady_camera_locked_unit, 1, rotation)
set_world_spawner_camera(world_spawner, steady_camera_locked_unit, steady_camera_locked_fov)
end
return M
end
return M
