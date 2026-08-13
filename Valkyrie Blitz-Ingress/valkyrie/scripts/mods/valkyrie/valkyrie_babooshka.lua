-- valkyrie_babooshka.lua
local BABOOSHKA_OGRYN_SCALE = 0.15
local BABOOSHKA_SLOT_SCALES = {
0.25,
0.5,
0.75,
1,
}
local M = {}
function M.init(ctx)
local temp_babooshka_slots = {}
function M.clear_spawner_flags(profile_spawner)
if not profile_spawner then
return
end
profile_spawner._valkyrie_babooshka_scale_factor = nil
profile_spawner._valkyrie_babooshka_slot_scale = nil
profile_spawner._valkyrie_babooshka_is_ogryn = nil
end
function M.clear_slot_scales(view)
local spawn_slots = view and view._spawn_slots
if not spawn_slots then
return
end
for i = 1, #spawn_slots do
local slot = spawn_slots[i]
if slot then
slot._valkyrie_babooshka_slot_scale = nil
local profile_spawner = slot.profile_spawner
if profile_spawner then
M.clear_spawner_flags(profile_spawner)
end
end
end
end
local function assign_babooshka_scale_to_slot(slot, factor)
if not slot then
return
end
slot._valkyrie_babooshka_slot_scale = factor
local profile_spawner = slot.profile_spawner
if profile_spawner then
profile_spawner._valkyrie_babooshka_slot_scale = factor
end
end
local function fallback_babooshka_slot_scales(spawn_slots)
for i = 1, math.min(ctx.max_occupants, #spawn_slots) do
assign_babooshka_scale_to_slot(spawn_slots[i], BABOOSHKA_SLOT_SCALES[i] or 1)
end
end
function M.update_slot_scales(view)
local spawn_slots = view and view._spawn_slots
if not spawn_slots then
return
end
if not ctx.should_show_babooshka() then
M.clear_slot_scales(view)
return
end
table.clear(temp_babooshka_slots)
local world_spawner = view._world_spawner
local _, camera_unit = ctx.steady_camera_camera(world_spawner)
local ok, camera_position, camera_rotation
if ctx.unit_alive(camera_unit) then
ok, camera_position, camera_rotation = pcall(function()
return Unit.world_position(camera_unit, 1), Unit.world_rotation(camera_unit, 1)
end)
end
if not ok or not camera_position or not camera_rotation then
fallback_babooshka_slot_scales(spawn_slots)
return
end
local right_ok, camera_right = pcall(function()
return Vector3.flat(Quaternion.right(camera_rotation))
end)
if not right_ok or not camera_right or Vector3.length_squared(camera_right) <= 0 then
fallback_babooshka_slot_scales(spawn_slots)
return
end
camera_right = Vector3.normalize(camera_right)
for i = 1, math.min(ctx.max_occupants, #spawn_slots) do
local slot = spawn_slots[i]
local spawn_point_unit = slot and slot.spawn_point_unit
if ctx.unit_alive(spawn_point_unit) then
local slot_position = Unit.world_position(spawn_point_unit, 1)
temp_babooshka_slots[#temp_babooshka_slots + 1] = {
index = i,
lateral = Vector3.dot(slot_position - camera_position, camera_right),
distance_squared = Vector3.length_squared(slot_position - camera_position),
slot = slot,
}
end
end
if #temp_babooshka_slots == 0 then
fallback_babooshka_slot_scales(spawn_slots)
return
end
table.sort(temp_babooshka_slots, function(a, b)
if math.abs(a.distance_squared - b.distance_squared) <= 0.0001 then
return a.index < b.index
end
return a.distance_squared < b.distance_squared
end)
if temp_babooshka_slots[2] and temp_babooshka_slots[1].lateral > temp_babooshka_slots[2].lateral then
temp_babooshka_slots[1], temp_babooshka_slots[2] = temp_babooshka_slots[2], temp_babooshka_slots[1]
end
if temp_babooshka_slots[4] and temp_babooshka_slots[3].lateral < temp_babooshka_slots[4].lateral then
temp_babooshka_slots[3], temp_babooshka_slots[4] = temp_babooshka_slots[4], temp_babooshka_slots[3]
end
for i = 1, #temp_babooshka_slots do
assign_babooshka_scale_to_slot(temp_babooshka_slots[i].slot, BABOOSHKA_SLOT_SCALES[i] or 1)
end
end
function M.apply_player_to_slot(player, slot)
local profile_spawner = slot and slot.profile_spawner
if not profile_spawner then
return
end
if not ctx.should_show_babooshka() then
M.clear_spawner_flags(profile_spawner)
return
end
M.update_slot_scales(ctx.active_intro_view())
profile_spawner._valkyrie_weapon_slot = nil
profile_spawner._request_wield_slot_id = nil
profile_spawner._valkyrie_babooshka_slot_scale = slot._valkyrie_babooshka_slot_scale
profile_spawner._valkyrie_babooshka_is_ogryn = ctx.is_ogryn_player(player, ctx.player_profile(player))
profile_spawner._valkyrie_babooshka_scale_factor = profile_spawner._valkyrie_babooshka_is_ogryn and BABOOSHKA_OGRYN_SCALE or nil
end
function M.scale_vector_by_factor(scale, factor)
if not factor or factor == 1 then
return scale
end
if scale then
local ok, x, y, z = pcall(Vector3.to_elements, scale)
if ok and type(x) == "number" and type(y) == "number" and type(z) == "number" then
return Vector3(x * factor, y * factor, z * factor)
end
end
return Vector3(factor, factor, factor)
end
function M.spawn_scale(profile_spawner, profile, scale)
local factor = profile_spawner._valkyrie_babooshka_slot_scale or 1
if profile_spawner._valkyrie_babooshka_scale_factor then
factor = profile_spawner._valkyrie_babooshka_scale_factor
elseif profile_spawner._valkyrie_babooshka_is_ogryn or ctx.is_ogryn_player(nil, profile) then
factor = BABOOSHKA_OGRYN_SCALE
end
return M.scale_vector_by_factor(scale, factor)
end
return M
end
return M