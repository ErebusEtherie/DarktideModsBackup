-- valkyrie_weapon_presentation.lua
local WEAPON_PRESENTATION_FRONT_INWARD_OFFSET = 0.4
local WEAPON_PRESENTATION_REAR_INWARD_OFFSET = 0.6
local WEAPON_PRESENTATION_VERTICAL_OFFSET = 0.08
local SAFE_IDLE_ANIMATION_EVENTS = {
"inventory_idle_default",
"idle",
"idle_inventory",
"idle_cosmetics",
"idle_main_menu",
}
local weapon_slots = { slot_primary = true }
local M = { weapon_slots = weapon_slots }
function M.init(ctx)
local ignored_slots_without_weapons = nil
local weapon_vertical_states = setmetatable({}, { __mode = "k" })
local function streamed_unit_3p(profile_spawner)
local character_spawn_data = profile_spawner and profile_spawner._character_spawn_data
if character_spawn_data and character_spawn_data.streaming_complete then
return character_spawn_data.unit_3p
end
end
local function unit_has_animation_event(unit, animation_event)
if not animation_event or not ctx.unit_alive(unit) or not Unit.has_animation_state_machine or not Unit.has_animation_event then
return false
end
local state_machine_ok, has_state_machine = pcall(Unit.has_animation_state_machine, unit)
if not state_machine_ok or not has_state_machine then
return false
end
local event_ok, has_event = pcall(Unit.has_animation_event, unit, animation_event)
return event_ok and has_event == true
end
local function force_unit_visible(unit)
if not ctx.unit_alive(unit) then
return
end
Unit.set_unit_visibility(unit, true, true)
Unit.flow_event(unit, "lua_visible")
end
local function force_unit_hidden(unit)
if not ctx.unit_alive(unit) then
return
end
Unit.set_unit_visibility(unit, false, true)
Unit.flow_event(unit, "lua_hidden")
end
local function update_attachment_units(attachments_by_unit_3p, unit_3p, visible)
local attachments = attachments_by_unit_3p and unit_3p and attachments_by_unit_3p[unit_3p]
if not attachments then
return
end
for i = 1, #attachments do
if visible then
force_unit_visible(attachments[i])
else
force_unit_hidden(attachments[i])
end
end
end
local function force_slot_visible(slot)
if not slot then
return
end
slot.wants_hidden_by_gameplay_3p = false
slot.hidden_3p = false
force_unit_visible(slot.unit_3p)
update_attachment_units(slot.attachments_by_unit_3p, slot.unit_3p, true)
end
local function force_slot_hidden(slot)
if not slot then
return
end
slot.wants_hidden_by_gameplay_3p = true
slot.hidden_3p = true
force_unit_hidden(slot.unit_3p)
update_attachment_units(slot.attachments_by_unit_3p, slot.unit_3p, false)
end
function M.clear_state()
table.clear(weapon_vertical_states)
end
function M.clear_spawner_flags(profile_spawner)
if not profile_spawner then
return
end
profile_spawner._valkyrie_weapon_slot = nil
profile_spawner._request_wield_slot_id = nil
end
function M.get_ignored_slots_without_weapons()
if ignored_slots_without_weapons then
return ignored_slots_without_weapons
end
ignored_slots_without_weapons = {}
local original_ignored_slots = ctx.original_ignored_slots
for i = 1, #original_ignored_slots do
local slot_name = original_ignored_slots[i]
if not weapon_slots[slot_name] then
ignored_slots_without_weapons[#ignored_slots_without_weapons + 1] = slot_name
end
end
return ignored_slots_without_weapons
end
function M.preferred_weapon_slot(player)
local profile = ctx.player_profile(player)
local loadout = profile and profile.loadout
if loadout and loadout.slot_primary then
return "slot_primary"
end
end
function M.streamed_unit_3p(profile_spawner)
return streamed_unit_3p(profile_spawner)
end
function M.safe_animation_event_for_unit(unit, animation_event)
if unit_has_animation_event(unit, animation_event) then
return animation_event
end
for i = 1, #SAFE_IDLE_ANIMATION_EVENTS do
local fallback_event = SAFE_IDLE_ANIMATION_EVENTS[i]
if unit_has_animation_event(unit, fallback_event) then
return fallback_event
end
end
end
function M.lower_intro_weapon(slot)
if not ctx.should_show_weapon() or not slot then
return
end
local weapon_unit = slot.unit_3p
local parent_unit = slot.parent_unit_3p
if not ctx.unit_alive(weapon_unit) or not ctx.unit_alive(parent_unit) then
return
end
local local_position_ok, local_position = pcall(Unit.local_position, weapon_unit, 1)
if not local_position_ok or not local_position then
return
end
local components_ok, x, y, z = pcall(Vector3.to_elements, local_position)
if not components_ok or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
return
end
local state = weapon_vertical_states[weapon_unit]
if not state then
state = {
base_x = x,
base_y = y,
base_z = z,
}
weapon_vertical_states[weapon_unit] = state
end
local node_index = 1
local item = slot.item
local attach_node = item and (item.wielded_attach_node or item.attach_node)
if attach_node then
local has_node_ok, has_node = pcall(Unit.has_node, parent_unit, attach_node)
if has_node_ok and has_node then
local node_ok, resolved_node = pcall(Unit.node, parent_unit, attach_node)
if node_ok and type(resolved_node) == "number" then
node_index = resolved_node
end
end
end
local rotation_ok, parent_rotation = pcall(Unit.world_rotation, parent_unit, node_index)
if not rotation_ok or not parent_rotation then
return
end
local offset_ok, local_offset = pcall(function()
local inverse_rotation = Quaternion.inverse(parent_rotation)
return Quaternion.rotate(inverse_rotation, Vector3(0, 0, -WEAPON_PRESENTATION_VERTICAL_OFFSET))
end)
if not offset_ok or not local_offset then
return
end
local offset_components_ok, offset_x, offset_y, offset_z = pcall(Vector3.to_elements, local_offset)
if not offset_components_ok or type(offset_x) ~= "number" or type(offset_y) ~= "number" or type(offset_z) ~= "number" then
return
end
local wanted_position = Vector3(state.base_x + offset_x, state.base_y + offset_y, state.base_z + offset_z)
pcall(Unit.set_local_position, weapon_unit, 1, wanted_position)
end
function M.unignore_intro_weapons(profile_spawner)
if not profile_spawner or not profile_spawner._ignored_slots then
return
end
for slot_name, _ in pairs(weapon_slots) do
profile_spawner._ignored_slots[slot_name] = nil
end
end
function M.hide_intro_weapons(profile_spawner)
local spawn_data = profile_spawner and profile_spawner._character_spawn_data
local slots = spawn_data and spawn_data.slots
if not slots then
return
end
profile_spawner._valkyrie_weapon_slot = nil
profile_spawner._request_wield_slot_id = nil
for slot_name, _ in pairs(weapon_slots) do
force_slot_hidden(slots[slot_name])
end
end
function M.apply_intro_weapon_to_spawner(profile_spawner, slot_name)
if ctx.should_no_uniform() then
M.hide_intro_weapons(profile_spawner)
return
end
if not ctx.should_show_weapon() or not profile_spawner or not slot_name then
return
end
M.unignore_intro_weapons(profile_spawner)
profile_spawner._request_wield_slot_id = slot_name
profile_spawner._valkyrie_weapon_slot = slot_name
local spawn_data = profile_spawner._character_spawn_data
local slots = spawn_data and spawn_data.slots
local weapon_slot = slots and slots[slot_name]
if not weapon_slot then
return
end
profile_spawner:wield_slot(slot_name)
if profile_spawner._update_items_visibility then
profile_spawner:_update_items_visibility()
end
spawn_data.wielded_slot = weapon_slot
force_slot_visible(weapon_slot)
M.lower_intro_weapon(weapon_slot)
end
function M.queue_intro_weapon(player, slot)
if ctx.should_no_uniform() then
M.hide_intro_weapons(slot and slot.profile_spawner)
return nil
end
if not ctx.should_show_weapon() or not player or not slot then
return nil
end
local slot_name = M.preferred_weapon_slot(player)
local profile_spawner = slot.profile_spawner
if slot_name and profile_spawner then
M.unignore_intro_weapons(profile_spawner)
profile_spawner._request_wield_slot_id = slot_name
profile_spawner._valkyrie_weapon_slot = slot_name
slot.weapon_slot_requested = slot_name
return slot_name
end
end
function M.wield_intro_weapon(player, slot)
if not player or not slot then
return
end
if ctx.should_no_uniform() then
M.hide_intro_weapons(slot.profile_spawner)
return
end
local slot_name = slot.weapon_slot_requested or M.preferred_weapon_slot(player)
M.apply_intro_weapon_to_spawner(slot.profile_spawner, slot_name)
end
function M.wield_all_intro_weapons(view)
local spawn_slots = view and view._spawn_slots
if not spawn_slots then
return
end
for i = 1, #spawn_slots do
local slot = spawn_slots[i]
if slot and slot.occupied and slot.profile_spawner then
if ctx.should_no_uniform() then
M.hide_intro_weapons(slot.profile_spawner)
elseif ctx.should_show_weapon() and slot.player then
M.wield_intro_weapon(slot.player, slot)
end
end
end
end
local function weapon_presentation_inward_offset(position, camera_position)
local active_intro_view = ctx.active_intro_view()
local spawn_slots = active_intro_view and active_intro_view._spawn_slots
if not spawn_slots then
return WEAPON_PRESENTATION_REAR_INWARD_OFFSET
end
local ranked_slots = {}
local matched_slot_index = nil
local matched_distance_squared = math.huge
for i = 1, #spawn_slots do
local slot = spawn_slots[i]
local spawn_point_unit = slot and slot.spawn_point_unit
if ctx.unit_alive(spawn_point_unit) then
local slot_position = Unit.world_position(spawn_point_unit, 1)
local camera_distance_squared = Vector3.length_squared(slot_position - camera_position)
ranked_slots[#ranked_slots + 1] = {
distance_squared = camera_distance_squared,
index = i,
}
local position_distance_squared = Vector3.length_squared(slot_position - position)
if position_distance_squared < matched_distance_squared then
matched_distance_squared = position_distance_squared
matched_slot_index = i
end
end
end
if not matched_slot_index or #ranked_slots < 2 then
return WEAPON_PRESENTATION_REAR_INWARD_OFFSET
end
table.sort(ranked_slots, function(a, b)
if math.abs(a.distance_squared - b.distance_squared) <= 0.0001 then
return a.index < b.index
end
return a.distance_squared < b.distance_squared
end)
for i = 1, math.min(2, #ranked_slots) do
if ranked_slots[i].index == matched_slot_index then
return WEAPON_PRESENTATION_FRONT_INWARD_OFFSET
end
end
return WEAPON_PRESENTATION_REAR_INWARD_OFFSET
end
function M.inward_position(position)
if not position or not ctx.should_use_standing_presentation() then
return position
end
local active_intro_view = ctx.active_intro_view()
local world_spawner = active_intro_view and active_intro_view._world_spawner
local _, camera_unit = ctx.steady_camera_camera(world_spawner)
if not ctx.unit_alive(camera_unit) then
return position
end
local ok, camera_position, camera_rotation = pcall(function()
return Unit.world_position(camera_unit, 1), Unit.world_rotation(camera_unit, 1)
end)
if not ok or not camera_position or not camera_rotation then
return position
end
local camera_right = Vector3.flat(Quaternion.right(camera_rotation))
if Vector3.length_squared(camera_right) <= 0 then
return position
end
camera_right = Vector3.normalize(camera_right)
local lateral_offset = Vector3.dot(position - camera_position, camera_right)
local lateral_distance = math.abs(lateral_offset)
if lateral_distance <= 0.001 then
return position
end
local wanted_offset = weapon_presentation_inward_offset(position, camera_position)
local inward_distance = math.min(wanted_offset, lateral_distance)
local inward_direction = lateral_offset < 0 and 1 or -1
return position + camera_right * inward_distance * inward_direction
end
return M
end
return M
