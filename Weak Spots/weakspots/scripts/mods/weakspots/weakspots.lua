-- weakspots.lua
local mod = get_mod("weakspots")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Actor = stingray.Actor
local Color = stingray.Color
local LineObject = stingray.LineObject
local Matrix4x4 = stingray.Matrix4x4
local Mesh = rawget(_G, "Mesh")
local PhysicsWorld = stingray.PhysicsWorld
local Quaternion = stingray.Quaternion
local Unit = stingray.Unit
local Vector3 = stingray.Vector3
local World = stingray.World
local LEVEL_WORLD_NAME = "level_world"
local NORMAL_NEAREST_COUNT = 5
local DIMENSION_CACHE_SETTING = "_weakspot_dimension_cache"
local DIMENSION_CACHE_SCHEMA = 1
local DEFAULT_EXTENTS = {0.18, 0.18, 0.22}
local BODY_NODE_NAMES = {"j_spine2", "j_spine1", "j_spine", "j_hips", "j_head"}
local HIT_ZONE_EXTENTS = {
head = {0.18, 0.18, 0.22},
hound_tail = {0.30, 0.24, 0.22},
weakspot = {0.30, 0.30, 0.30},
tongue = {0.18, 0.18, 0.45},
canister = {0.18, 0.16, 0.22},
backpack = {0.24, 0.20, 0.34},
}
local world
local physics_world
local line_object
local side_system
local cached_player_unit
local cached_first_person_component
local cached_first_person_extension
local marker_range = 20
local marker_range_squared = 400
local boss_only = false
local wireframe_visible = false
local active_target_count = 0
local active_candidate_count = 0
local target_pool = {}
local candidate_pool = {}
local candidate_refs = {}
local breed_zone_cache = {}
local crosshair_sticky_units = {}
local dimension_discovery_failed = {}
local dimension_cache = mod:get(DIMENSION_CACHE_SETTING)
local dimension_cache_dirty = false
if type(dimension_cache) ~= "table" or dimension_cache.schema ~= DIMENSION_CACHE_SCHEMA or type(dimension_cache.breeds) ~= "table" then
dimension_cache = {
schema = DIMENSION_CACHE_SCHEMA,
breeds = {},
}
mod:set(DIMENSION_CACHE_SETTING, dimension_cache)
end
local function refresh_marker_range()
local value = tonumber(mod:get("marker_range")) or 20
if value ~= 10 and value ~= 20 and value ~= 30 and value ~= 40 then
value = 20
end
marker_range = value
marker_range_squared = value * value
end
local function refresh_boss_only()
boss_only = mod:get("boss_only") == true
end
local function clear_crosshair_sticky()
table.clear(crosshair_sticky_units)
end
local function clear_dimension_discovery_failures()
table.clear(dimension_discovery_failed)
end
local function flush_dimension_cache()
if dimension_cache_dirty then
mod:set(DIMENSION_CACHE_SETTING, dimension_cache)
dimension_cache_dirty = false
end
end
local function clear_targets()
for i = 1, active_target_count do
local target = target_pool[i]
if target then
target.unit = nil
target.zone_count = 0
target.is_boss = false
end
end
active_target_count = 0
end
local function clear_candidates()
for i = 1, active_candidate_count do
local candidate = candidate_pool[i]
if candidate then
candidate.unit = nil
candidate.breed = nil
candidate.distance_squared = nil
end
candidate_refs[i] = nil
end
active_candidate_count = 0
end
local function reset_runtime_state()
clear_targets()
clear_candidates()
clear_crosshair_sticky()
clear_dimension_discovery_failures()
world = nil
physics_world = nil
line_object = nil
side_system = nil
cached_player_unit = nil
cached_first_person_component = nil
cached_first_person_extension = nil
wireframe_visible = false
end
local function fully_hot_join_synced()
local state = Managers.state
local unit_spawner = state and state.unit_spawner
if not unit_spawner or not unit_spawner.fully_hot_join_synced then
return false
end
return unit_spawner:fully_hot_join_synced() == true
end
local function in_hub()
local state = Managers.state
local game_mode_manager = state and state.game_mode
local game_mode_name = game_mode_manager and game_mode_manager.game_mode_name and game_mode_manager:game_mode_name()
return game_mode_name == "hub" or game_mode_name == "prologue_hub" or game_mode_name == "hub_singleplay"
end
local function level_world()
local world_manager = Managers.world
if not world_manager or not world_manager:has_world(LEVEL_WORLD_NAME) then
return nil
end
return world_manager:world(LEVEL_WORLD_NAME)
end
local function setup_world()
local new_world = level_world()
if not new_world then
return false
end
if world ~= new_world then
clear_targets()
clear_candidates()
clear_crosshair_sticky()
clear_dimension_discovery_failures()
world = new_world
physics_world = nil
line_object = nil
side_system = nil
cached_player_unit = nil
cached_first_person_component = nil
cached_first_person_extension = nil
wireframe_visible = false
end
local state = Managers.state
local extension_manager = state and state.extension
local new_side_system = extension_manager and extension_manager:system("side_system")
if not new_side_system then
return false
end
if not physics_world then
physics_world = World.physics_world(world)
end
side_system = new_side_system
return physics_world ~= nil
end
local function setup_renderer()
if line_object then
return true
end
if not world then
return false
end
line_object = World.create_line_object(world)
return line_object ~= nil
end
local function clear_render()
if line_object and world and wireframe_visible then
LineObject.reset(line_object)
LineObject.dispatch(world, line_object)
end
wireframe_visible = false
end
local function get_player_view()
local player_manager = Managers.player
local player = player_manager and player_manager:local_player(1)
local player_unit = player and player.player_unit
local alive_lookup = rawget(_G, "ALIVE")
if not player_unit or not alive_lookup or not alive_lookup[player_unit] then
cached_player_unit = nil
cached_first_person_component = nil
cached_first_person_extension = nil
return nil, nil, nil
end
if player_unit ~= cached_player_unit then
cached_player_unit = player_unit
cached_first_person_component = nil
cached_first_person_extension = nil
local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
if unit_data_extension then
cached_first_person_component = unit_data_extension:read_component("first_person")
end
cached_first_person_extension = ScriptUnit.has_extension(player_unit, "first_person_system")
end
return cached_player_unit, cached_first_person_component, cached_first_person_extension
end
local function target_is_alive(target_unit)
local alive_lookup = rawget(_G, "ALIVE")
local health_alive_lookup = rawget(_G, "HEALTH_ALIVE")
if not alive_lookup or not alive_lookup[target_unit] then
return false
end
if health_alive_lookup and not health_alive_lookup[target_unit] then
return false
end
return ScriptUnit.has_extension(target_unit, "unit_data_system") ~= nil
end
local function target_breed(target_unit)
local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
return unit_data_extension and unit_data_extension:breed()
end
local function weakspot_zones_for_breed(breed)
local cached = breed_zone_cache[breed]
if cached then
return cached
end
local zones = {}
local weakspot_types = breed and breed.hit_zone_weakspot_types
if weakspot_types then
for hit_zone_name, weakspot_type in pairs(weakspot_types) do
if weakspot_type ~= "shield" then
zones[#zones + 1] = hit_zone_name
end
end
end
breed_zone_cache[breed] = zones
return zones
end
local function breed_scale(target_unit)
local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
local scale_function = unit_data_extension and unit_data_extension.breed_size_variation
if scale_function then
local success, scale = pcall(scale_function, unit_data_extension)
if success and type(scale) == "number" and scale == scale and scale > 0.1 and scale < 10 then
return scale
end
end
return 1
end
local function valid_extent_number(value)
return type(value) == "number" and value == value and value > 0.005 and value < 1.5
end
local function valid_discovered_extents(hit_zone_name, x, y, z)
if not valid_extent_number(x) or not valid_extent_number(y) or not valid_extent_number(z) then
return false
end
local fallback = HIT_ZONE_EXTENTS[hit_zone_name] or DEFAULT_EXTENTS
local max_x = math.min(math.max(fallback[1] * 3, 0.15), 1.5)
local max_y = math.min(math.max(fallback[2] * 3, 0.15), 1.5)
local max_z = math.min(math.max(fallback[3] * 3, 0.2), 1.5)
local fallback_volume = fallback[1] * fallback[2] * fallback[3]
local volume = x * y * z
return x <= max_x and y <= max_y and z <= max_z and volume <= fallback_volume * 6
end
local function dimension_cache_entry(breed, hit_zone_name)
local breed_name = breed and breed.name
if type(breed_name) ~= "string" or breed_name == "" then
return nil, nil
end
local breed_cache = dimension_cache.breeds[breed_name]
local entry = breed_cache and breed_cache[hit_zone_name]
if entry ~= nil then
if type(entry) == "table" and type(entry.actor) == "string" and valid_discovered_extents(hit_zone_name, entry.x, entry.y, entry.z) then
return entry, breed_name
end
breed_cache[hit_zone_name] = nil
dimension_cache_dirty = true
end
return nil, breed_name
end
local function mark_dimension_discovery_failed(breed_name, hit_zone_name)
local breed_failures = dimension_discovery_failed[breed_name]
if not breed_failures then
breed_failures = {}
dimension_discovery_failed[breed_name] = breed_failures
end
breed_failures[hit_zone_name] = true
end
local function dimension_discovery_has_failed(breed_name, hit_zone_name)
local breed_failures = dimension_discovery_failed[breed_name]
return breed_failures and breed_failures[hit_zone_name] == true
end
local function discover_dimension_entry(target_unit, breed, hit_zone_name)
local cached, breed_name = dimension_cache_entry(breed, hit_zone_name)
if cached or not breed_name or not Mesh or not Mesh.box or dimension_discovery_has_failed(breed_name, hit_zone_name) then
return cached
end
local success, actor_names = pcall(HitZone.get_actor_names, target_unit, hit_zone_name)
if not success or not actor_names or #actor_names == 0 then
mark_dimension_discovery_failed(breed_name, hit_zone_name)
return nil
end
local scale = breed_scale(target_unit)
local best_actor
local best_x
local best_y
local best_z
local best_volume = 0
for i = 1, #actor_names do
local actor_name = actor_names[i]
local actor_success, actor = pcall(Unit.actor, target_unit, actor_name)
if actor_success and actor then
local node_success, node = pcall(Actor.node, actor)
if node_success and node then
local meshes_success, meshes = pcall(Unit.get_node_meshes, target_unit, node, true, false)
if meshes_success and meshes then
for mesh_index = 1, #meshes do
local mesh_success, mesh = pcall(Unit.mesh, target_unit, meshes[mesh_index])
if mesh_success and mesh then
local box_success, _, half_extents = pcall(Mesh.box, mesh)
if box_success and half_extents then
local x = half_extents.x / scale
local y = half_extents.y / scale
local z = half_extents.z / scale
if valid_discovered_extents(hit_zone_name, x, y, z) then
local volume = x * y * z
if volume > best_volume then
best_actor = actor_name
best_x = x
best_y = y
best_z = z
best_volume = volume
end
end
end
end
end
end
end
end
end
if not best_actor then
mark_dimension_discovery_failed(breed_name, hit_zone_name)
return nil
end
local breed_cache = dimension_cache.breeds[breed_name]
if not breed_cache then
breed_cache = {}
dimension_cache.breeds[breed_name] = breed_cache
end
local entry = {
actor = best_actor,
x = best_x,
y = best_y,
z = best_z,
}
breed_cache[hit_zone_name] = entry
dimension_cache_dirty = true
return entry
end
local function actor_node_position(target_unit, actor_name)
local actor_success, actor = pcall(Unit.actor, target_unit, actor_name)
if not actor_success or not actor then
return nil
end
local node_success, node = pcall(Actor.node, actor)
if not node_success or not node then
return nil
end
local position_success, position = pcall(Unit.world_position, target_unit, node)
return position_success and position or nil
end
local function actor_node_center(target_unit, hit_zone_name)
local success, actor_names = pcall(HitZone.get_actor_names, target_unit, hit_zone_name)
if not success or not actor_names or #actor_names == 0 then
return nil
end
local sum_x = 0
local sum_y = 0
local sum_z = 0
local count = 0
for i = 1, #actor_names do
local actor_success, actor = pcall(Unit.actor, target_unit, actor_names[i])
if actor_success and actor then
local node_success, node = pcall(Actor.node, actor)
if node_success and node then
local position_success, position = pcall(Unit.world_position, target_unit, node)
if position_success and position then
sum_x = sum_x + position.x
sum_y = sum_y + position.y
sum_z = sum_z + position.z
count = count + 1
end
end
end
end
if count == 0 then
return nil
end
return Vector3(sum_x / count, sum_y / count, sum_z / count)
end
local function named_node_position(target_unit, node_name)
local success, has_node = pcall(Unit.has_node, target_unit, node_name)
if not success or not has_node then
return nil
end
local node_success, node = pcall(Unit.node, target_unit, node_name)
if not node_success or not node then
return nil
end
local position_success, position = pcall(Unit.world_position, target_unit, node)
return position_success and position or nil
end
local function target_body_position(target_unit)
local center = actor_node_center(target_unit, "center_mass")
if center then
return center
end
for i = 1, #BODY_NODE_NAMES do
local position = named_node_position(target_unit, BODY_NODE_NAMES[i])
if position then
return position
end
end
local success, root_position = pcall(Unit.world_position, target_unit, 1)
if not success or not root_position then
return nil
end
return root_position + Vector3(0, 0, 0.9)
end
local function fallback_zone_center(target_unit, hit_zone_name, body_position)
if hit_zone_name == "head" then
local head_position = named_node_position(target_unit, "j_head")
if head_position then
return head_position
end
end
body_position = body_position or target_body_position(target_unit)
if not body_position then
return nil
end
local rotation_success, rotation = pcall(Unit.world_rotation, target_unit, 1)
local forward = rotation_success and rotation and Quaternion.forward(rotation) or Vector3(0, 1, 0)
local up = Vector3.up()
if hit_zone_name == "head" then
return body_position + up * 0.45
elseif hit_zone_name == "backpack" or hit_zone_name == "canister" then
return body_position - forward * 0.25 + up * 0.12
elseif hit_zone_name == "hound_tail" then
return body_position - forward * 0.45 - up * 0.18
elseif hit_zone_name == "tongue" then
return body_position + forward * 0.28 + up * 0.35
end
return body_position
end
local function weakspot_position(target_unit, hit_zone_name, body_position)
return actor_node_center(target_unit, hit_zone_name) or fallback_zone_center(target_unit, hit_zone_name, body_position)
end
local function static_line_of_sight(view_position, target_position)
local direction, distance = Vector3.direction_length(target_position - view_position)
if distance <= 0.1 then
return true
end
local ray_distance = math.max(distance - 0.1, 0.01)
local hit = PhysicsWorld.raycast(physics_world, view_position, direction, ray_distance, "closest", "types", "both", "collision_filter", "filter_player_character_shooting_raycast_statics")
return not hit
end
local function target_slot(index)
local target = target_pool[index]
if not target then
target = {
center_x = {},
center_y = {},
center_z = {},
extent_x = {},
extent_y = {},
extent_z = {},
zone_count = 0,
}
target_pool[index] = target
end
return target
end
local function fill_target(index, target_unit, breed, body_position)
local zones = weakspot_zones_for_breed(breed)
if #zones == 0 then
return false
end
body_position = body_position or target_body_position(target_unit)
if not body_position then
return false
end
local target = target_slot(index)
local center_x = target.center_x
local center_y = target.center_y
local center_z = target.center_z
local extent_x = target.extent_x
local extent_y = target.extent_y
local extent_z = target.extent_z
local scale = breed_scale(target_unit)
local zone_count = 0
for i = 1, #zones do
local hit_zone_name = zones[i]
local entry = discover_dimension_entry(target_unit, breed, hit_zone_name)
local center = entry and actor_node_position(target_unit, entry.actor) or weakspot_position(target_unit, hit_zone_name, body_position)
local fallback = HIT_ZONE_EXTENTS[hit_zone_name] or DEFAULT_EXTENTS
local x = entry and entry.x * scale or fallback[1]
local y = entry and entry.y * scale or fallback[2]
local z = entry and entry.z * scale or fallback[3]
if not center and entry then
center = weakspot_position(target_unit, hit_zone_name, body_position)
x = fallback[1]
y = fallback[2]
z = fallback[3]
end
if center then
zone_count = zone_count + 1
center_x[zone_count] = center.x
center_y[zone_count] = center.y
center_z[zone_count] = center.z
extent_x[zone_count] = x
extent_y[zone_count] = y
extent_z[zone_count] = z
end
end
for i = zone_count + 1, target.zone_count do
center_x[i] = nil
center_y[i] = nil
center_z[i] = nil
extent_x[i] = nil
extent_y[i] = nil
extent_z[i] = nil
end
if zone_count == 0 then
target.unit = nil
target.zone_count = 0
return false
end
target.unit = target_unit
target.zone_count = zone_count
target.is_boss = breed.is_boss == true
return true
end
local function get_player_side()
local side_name = side_system:get_default_player_side_name()
return side_name and side_system:get_side_from_name(side_name)
end
local function get_enemy_units()
local player_side = get_player_side()
return player_side and player_side:relation_units("enemy")
end
local function crosshair_target(player_unit, first_person_component, player_side)
local view_position = first_person_component.position
local view_rotation = first_person_component.rotation
if not view_position or not view_rotation or not player_side then
return nil, nil
end
local direction = Quaternion.forward(view_rotation)
local hits = PhysicsWorld.raycast(physics_world, view_position, direction, marker_range, "all", "types", "both", "collision_filter", "filter_player_character_shooting_raycast")
if not hits then
return nil, nil
end
for i = 1, #hits do
local hit = hits[i]
local hit_actor = hit[4]
if hit_actor then
local hit_unit = Actor.unit(hit_actor)
if hit_unit ~= player_unit then
if hit_unit and player_side.enemy_units_lookup[hit_unit] and target_is_alive(hit_unit) then
local breed = target_breed(hit_unit)
if breed and #weakspot_zones_for_breed(breed) > 0 then
return hit_unit, breed
end
end
return nil, nil
end
end
end
return nil, nil
end
local function candidate_slot(index)
local candidate = candidate_pool[index]
if not candidate then
candidate = {}
candidate_pool[index] = candidate
end
return candidate
end
local function build_normal_candidates(player_position, view_position, first_person_extension, player_side)
clear_candidates()
if not player_side then
return 0
end
local enemy_units = player_side:relation_units("enemy")
local candidate_count = 0
for i = 1, #enemy_units do
local enemy_unit = enemy_units[i]
if target_is_alive(enemy_unit) then
local root_success, enemy_position = pcall(Unit.world_position, enemy_unit, 1)
if root_success and enemy_position then
local distance_squared = Vector3.length_squared(enemy_position - player_position)
if distance_squared <= marker_range_squared then
local breed = target_breed(enemy_unit)
if breed and #weakspot_zones_for_breed(breed) > 0 then
local body_position = target_body_position(enemy_unit)
if body_position and first_person_extension:is_within_default_view(body_position) and static_line_of_sight(view_position, body_position) then
candidate_count = candidate_count + 1
local candidate = candidate_slot(candidate_count)
candidate.unit = enemy_unit
candidate.breed = breed
candidate.distance_squared = distance_squared
candidate.body_x = body_position.x
candidate.body_y = body_position.y
candidate.body_z = body_position.z
candidate_refs[candidate_count] = candidate
end
end
end
end
end
end
active_candidate_count = candidate_count
table.sort(candidate_refs, function(a, b)
return a.distance_squared < b.distance_squared
end)
return candidate_count
end
local function target_already_selected(target_unit, target_count)
for i = 1, target_count do
local target = target_pool[i]
if target and target.unit == target_unit then
return true
end
end
return false
end
local function prune_crosshair_sticky(player_side)
for target_unit in pairs(crosshair_sticky_units) do
local valid = target_is_alive(target_unit)
if valid and player_side and not player_side.enemy_units_lookup[target_unit] then
valid = false
end
if valid then
local breed = target_breed(target_unit)
valid = breed ~= nil and #weakspot_zones_for_breed(breed) > 0
end
if not valid then
crosshair_sticky_units[target_unit] = nil
end
end
end
local function scan_normal_targets(player_unit, first_person_component, first_person_extension)
local view_position = first_person_component.position
if not view_position or not first_person_extension then
clear_targets()
return
end
local player_side = get_player_side()
if not player_side then
clear_targets()
return
end
local crosshair_unit = crosshair_target(player_unit, first_person_component, player_side)
if crosshair_unit then
crosshair_sticky_units[crosshair_unit] = true
end
prune_crosshair_sticky(player_side)
local player_position = Unit.world_position(player_unit, 1)
local previous_count = active_target_count
local candidate_count = build_normal_candidates(player_position, view_position, first_person_extension, player_side)
local target_count = 0
local nearest_added = 0
for i = 1, candidate_count do
if nearest_added >= NORMAL_NEAREST_COUNT then
break
end
local candidate = candidate_refs[i]
local next_index = target_count + 1
local body_position = Vector3(candidate.body_x, candidate.body_y, candidate.body_z)
if fill_target(next_index, candidate.unit, candidate.breed, body_position) then
target_count = next_index
nearest_added = nearest_added + 1
end
end
for i = 1, candidate_count do
local candidate = candidate_refs[i]
if candidate.breed.is_boss == true and not target_already_selected(candidate.unit, target_count) then
local next_index = target_count + 1
local body_position = Vector3(candidate.body_x, candidate.body_y, candidate.body_z)
if fill_target(next_index, candidate.unit, candidate.breed, body_position) then
target_count = next_index
end
end
end
for target_unit in pairs(crosshair_sticky_units) do
if not target_already_selected(target_unit, target_count) then
local breed = target_breed(target_unit)
local next_index = target_count + 1
if breed and fill_target(next_index, target_unit, breed, nil) then
target_count = next_index
end
end
end
for i = target_count + 1, previous_count do
local target = target_pool[i]
if target then
target.unit = nil
target.zone_count = 0
end
end
active_target_count = target_count
end
local function scan_boss_targets(first_person_component)
local view_position = first_person_component.position
if not view_position then
clear_targets()
return
end
local enemy_units = get_enemy_units()
local previous_count = active_target_count
local target_count = 0
if enemy_units then
for i = 1, #enemy_units do
local enemy_unit = enemy_units[i]
if target_is_alive(enemy_unit) then
local breed = target_breed(enemy_unit)
if breed and breed.is_boss == true and #weakspot_zones_for_breed(breed) > 0 then
local body_position = target_body_position(enemy_unit)
if body_position and static_line_of_sight(view_position, body_position) then
local next_index = target_count + 1
if fill_target(next_index, enemy_unit, breed, body_position) then
target_count = next_index
end
end
end
end
end
end
for i = target_count + 1, previous_count do
local target = target_pool[i]
if target then
target.unit = nil
target.zone_count = 0
end
end
active_target_count = target_count
end
local function draw_targets()
if active_target_count == 0 then
if line_object and world and wireframe_visible then
LineObject.reset(line_object)
LineObject.dispatch(world, line_object)
end
wireframe_visible = false
return
end
if not setup_renderer() then
return
end
LineObject.reset(line_object)
local wireframe_color = Color(255, 255, 0, 0)
local drawn = 0
for target_index = 1, active_target_count do
local target = target_pool[target_index]
local target_unit = target and target.unit
if target_unit and target_is_alive(target_unit) then
for zone_index = 1, target.zone_count do
local x = target.center_x[zone_index]
local y = target.center_y[zone_index]
local z = target.center_z[zone_index]
if x and y and z then
local extent_x = target.extent_x[zone_index]
local extent_y = target.extent_y[zone_index]
local extent_z = target.extent_z[zone_index]
if extent_x and extent_y and extent_z then
local center = Vector3(x, y, z)
local pose = Matrix4x4.from_translation(center)
if target.is_boss then
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x - 0.008, extent_y - 0.008, extent_z - 0.008))
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x - 0.004, extent_y - 0.004, extent_z - 0.004))
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x, extent_y, extent_z))
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x + 0.004, extent_y + 0.004, extent_z + 0.004))
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x + 0.008, extent_y + 0.008, extent_z + 0.008))
else
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x, extent_y, extent_z))
LineObject.add_box(line_object, wireframe_color, pose, Vector3(extent_x + 0.006, extent_y + 0.006, extent_z + 0.006))
end
drawn = drawn + 1
end
end
end
end
end
LineObject.dispatch(world, line_object)
wireframe_visible = drawn > 0
end
function mod.update()
if not mod:is_enabled() then
return
end
if in_hub() or not fully_hot_join_synced() then
if world or physics_world or line_object or active_target_count > 0 then
reset_runtime_state()
end
return
end
if not setup_world() then
return
end
prune_crosshair_sticky()
local player_unit, first_person_component, first_person_extension = get_player_view()
if not player_unit or not first_person_component then
clear_targets()
clear_render()
return
end
if boss_only then
scan_boss_targets(first_person_component)
else
scan_normal_targets(player_unit, first_person_component, first_person_extension)
end
draw_targets()
flush_dimension_cache()
end
function mod.on_setting_changed(setting_id)
if setting_id == "marker_range" then
refresh_marker_range()
clear_targets()
elseif setting_id == "boss_only" then
refresh_boss_only()
clear_targets()
clear_crosshair_sticky()
end
end
function mod.on_settings_reset()
clear_targets()
clear_crosshair_sticky()
refresh_marker_range()
refresh_boss_only()
end
function mod.on_disabled()
flush_dimension_cache()
if fully_hot_join_synced() then
clear_render()
end
reset_runtime_state()
end
function mod.on_unload()
flush_dimension_cache()
if fully_hot_join_synced() then
clear_render()
end
reset_runtime_state()
end
refresh_marker_range()
refresh_boss_only()