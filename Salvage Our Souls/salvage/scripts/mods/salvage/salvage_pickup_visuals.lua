-- salvage_pickup_visuals.lua
return function(mod, shared)
local api = {}
local ROOT_NODE_INDEX = 1
local DEFAULT_HEIGHT = 0.3
local WORLD_PULSE_HEIGHT = 0.65
local FIRE_PULSE_HEIGHT = 0.25
local ELECTRICITY_PULSE_HEIGHT = 0.45
local PULSE_INTERVAL = 0.9
local REPEAT_INTERVAL = 1
local PULSE_EFFECT_ID = "staggering_pulse"
local DECAL_PATH = "content/levels/training_grounds/fx/decal_aoe_indicator"
local DECAL_PACKAGE_PATH = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local DECAL_RADIUS = 1
local FIRE_360_RADIUS_VARIABLE = "radius"
local COMPACT_FIRE_RADIUS = 1.25
local PLAYER_DROP_PICKUP_TYPE = "expedition_loot_player_drop"
local PLAYER_DROP_REASON_DISABLED = "disabled"
local context = shared and shared.context or {}
local clear_table = type(context.clear_table) == "function" and context.clear_table or function(value)
if type(value) == "table" and table and type(table.clear) == "function" then
table.clear(value)
end
end
local should_run = type(context.should_run) == "function" and context.should_run or function()
return false
end
local is_alive_unit = type(context.is_alive_unit) == "function" and context.is_alive_unit or function(unit)
if not unit or not Unit or type(Unit.alive) ~= "function" then
return false
end
local success, alive = pcall(Unit.alive, unit)
return success and alive == true
end
local is_valid_unit = type(context.is_valid_unit) == "function" and context.is_valid_unit or is_alive_unit
local safe_call = type(context.safe_call) == "function" and context.safe_call or function(object, method_name, ...)
local method = object and object[method_name]
if type(method) ~= "function" then
return nil
end
local success, result = pcall(method, object, ...)
if success then
return result
end
return nil
end
local tracked_effects_by_unit = setmetatable({}, { __mode = "k" })
local tracked_decals_by_unit = setmetatable({}, { __mode = "k" })
local tracked_pickups_by_unit = setmetatable({}, { __mode = "k" })
api.tracked_pickups_by_unit = tracked_pickups_by_unit
local cached_pickup_types_by_unit = setmetatable({}, { __mode = "k" })
mod._salvage_sync_effects_desired_units_scratch = mod._salvage_sync_effects_desired_units_scratch or {}
local decal_package_loading = false
local EFFECTS = {
{
id = "fire_360angle_01",
vfx = "content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_initial_blast",
fallback_vfx = {
"content/fx/particles/weapons/grenades/flame_grenade_initial_blast",
"content/fx/particles/player_buffs/buff_fire_360angle_01",
"content/fx/particles/debug/flame_thrower_test_short",
},
world_pulse = true,
radius_variable = true,
height = FIRE_PULSE_HEIGHT,
},
{
id = "fire_trail_01",
vfx = "content/fx/particles/weapons/grenades/flame_grenade_initial_blast",
fallback_vfx = {
"content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_initial_blast",
"content/fx/particles/player_buffs/buff_fire_trail_01",
"content/fx/particles/debug/flame_thrower_test_short",
},
world_pulse = true,
height = FIRE_PULSE_HEIGHT,
},
{
id = "staggering_pulse",
vfx = "content/fx/particles/weapons/grenades/smoke_grenade/smoke_grenade_initial_blast",
fallback_vfx = {
"content/fx/particles/impacts/generic_dust_unarmored",
"content/fx/particles/player_buffs/buff_staggering_pulse",
},
world_pulse = true,
height = WORLD_PULSE_HEIGHT,
},
{
id = "electricity_grenade_01",
vfx = "content/fx/particles/weapons/grenades/shock_grenade/shock_grenade_explosion",
fallback_vfx = {
"content/fx/particles/abilities/cryptic/cryptic_force_field_electric_explosion",
"content/fx/particles/weapons/grenades/shock_mine/shock_mine_self_destruct_01",
"content/fx/particles/player_buffs/buff_electricity_grenade_01",
},
world_pulse = true,
height = ELECTRICITY_PULSE_HEIGHT,
},
{
id = "daemonhost_shield",
vfx = "content/fx/particles/enemies/chaos_mutator_daemonhost_shield",
linked = true,
linked_orphaned_policy = "destroy",
max_cached_spawns = 3,
},
}
local EMPTY_EFFECT_CANDIDATES = {}
for i = 1, #EFFECTS do
local effect = EFFECTS[i]
local candidates = {}
if type(effect.vfx) == "string" and effect.vfx ~= "" then
candidates[#candidates + 1] = effect.vfx
end
local fallback_vfx = effect.fallback_vfx
if type(fallback_vfx) == "table" then
for j = 1, #fallback_vfx do
local vfx = fallback_vfx[j]
if type(vfx) == "string" and vfx ~= "" then
candidates[#candidates + 1] = vfx
end
end
effect.fallback_vfx = nil
end
effect.vfx_candidates = candidates
end
local CATEGORIES = {
{
id = "salvage",
uses_effect_options = true,
decal = {
setting_id = "salvage_blue_decal",
red = 30 / 255,
green = 144 / 255,
blue = 255 / 255,
alpha = 1,
},
types = {
expedition_currency_small_tier_1 = true,
expedition_currency_small_tier_2 = true,
},
},
{
id = "tech_remnants",
uses_effect_options = true,
decal = {
setting_id = "tech_remnants_green_decal",
red = 74 / 255,
green = 199 / 255,
blue = 60 / 255,
alpha = 1,
},
types = {
expedition_loot_small_tier_1 = true,
expedition_loot_small_tier_2 = true,
expedition_loot_small_tier_3 = true,
expedition_loot_player_drop = true,
},
},
}

local function read_pickup_type_from_unit(unit)
if not unit or not Unit or not Unit.alive or not Unit.has_data or not Unit.get_data then
return nil
end
local alive_success, alive = pcall(Unit.alive, unit)
if not alive_success or not alive then
return nil
end
local has_data_success, has_data = pcall(Unit.has_data, unit, "pickup_type")
if not has_data_success or not has_data then
return nil
end
local get_data_success, pickup_type = pcall(Unit.get_data, unit, "pickup_type")
if get_data_success then
return pickup_type
end
return nil
end
function api.pickup_type_from_unit(unit)
if not unit then
return nil
end
if not is_alive_unit(unit) then
cached_pickup_types_by_unit[unit] = nil
return nil
end
local cached_pickup_type = cached_pickup_types_by_unit[unit]
if cached_pickup_type ~= nil then
return cached_pickup_type
end
local pickup_type = read_pickup_type_from_unit(unit)
if type(pickup_type) == "string" and pickup_type ~= "" then
cached_pickup_types_by_unit[unit] = pickup_type
end
return pickup_type
end
local function category_for_pickup_type(pickup_type)
if not pickup_type then
return nil
end
for i = 1, #CATEGORIES do
local category = CATEGORIES[i]
if category.types[pickup_type] then
return category
end
end
return nil
end
local function category_enabled(category)
return category and mod:get("enable_" .. category.id) ~= false
end
local function effect_enabled(category, effect)
return category and category.uses_effect_options and category_enabled(category) and mod:get(category.id .. "_" .. effect.id) == true
end
local function decal_enabled(category)
return category and category.decal and category_enabled(category) and mod:get(category.decal.setting_id) == true
end
local function category_has_particle_effect(category)
if not category_enabled(category) then
return false
end
for i = 1, #EFFECTS do
if effect_enabled(category, EFFECTS[i]) then
return true
end
end
return false
end
local function category_has_any_effect(category)
return category_has_particle_effect(category) or decal_enabled(category)
end
local function is_salvage_effect_setting(setting_id)
if type(setting_id) ~= "string" then
return true
end
return setting_id == "enable_salvage" or setting_id == "enable_tech_remnants" or string.sub(setting_id, 1, 8) == "salvage_" or string.sub(setting_id, 1, 14) == "tech_remnants_"
end
local function pickup_type_from_marker_data(marker)
if not marker then
return nil
end
local success, pickup_type = pcall(function()
local data = marker.data
return data and data.type or nil
end)
if success then
return pickup_type
end
return nil
end
api.pickup_type_from_marker_data = pickup_type_from_marker_data
local function stop_particle(world, effect_id)
if not world or not effect_id or not World then
return
end
local destroyed = false
if World.destroy_particles then
local success = pcall(World.destroy_particles, world, effect_id)
destroyed = success == true
end
if not destroyed and World.stop_spawning_particles then
pcall(World.stop_spawning_particles, world, effect_id)
end
end
local function stop_particle_record(world, particle_record)
if type(particle_record) == "table" then
if particle_record.triggered then
return
end
if particle_record.player_fx then
stop_particle(world, particle_record.particle_id)
return
end
for i = 1, #particle_record do
stop_particle(world, particle_record[i])
end
else
stop_particle(world, particle_record)
end
end
local function stop_effect_for_unit(unit)
local effect_data = tracked_effects_by_unit[unit]
if not effect_data then
return
end
local active_effects = effect_data.active_effects
if active_effects then
for _, particle_record in pairs(active_effects) do
stop_particle_record(effect_data.world, particle_record)
end
end
tracked_effects_by_unit[unit] = nil
end
local function stop_all_particle_effects(clear_units)
for unit, _ in pairs(tracked_effects_by_unit) do
stop_effect_for_unit(unit)
end
if clear_units then
clear_table(tracked_pickups_by_unit)
clear_table(cached_pickup_types_by_unit)
end
end
local function stop_decal_for_unit(unit)
local decal_data = tracked_decals_by_unit[unit]
if not decal_data then
return
end
local decal_unit = decal_data.unit
if is_valid_unit(decal_unit) and World and World.destroy_unit and Unit.world then
local success, world = pcall(Unit.world, decal_unit)
if success and world then
World.destroy_unit(world, decal_unit)
end
end
tracked_decals_by_unit[unit] = nil
end
local function stop_all_decals()
for unit, _ in pairs(tracked_decals_by_unit) do
stop_decal_for_unit(unit)
end
end
local function stop_all_visuals(clear_units)
stop_all_particle_effects(clear_units)
stop_all_decals()
end
local function ensure_decal_package()
local package_manager = Managers and Managers.package
if not package_manager or not package_manager.has_loaded or not package_manager.load then
return false
end
local loaded_success, loaded = pcall(function()
return package_manager:has_loaded(DECAL_PACKAGE_PATH)
end)
if loaded_success and loaded then
return true
end
if not decal_package_loading then
decal_package_loading = true
local load_success = pcall(function()
package_manager:load(DECAL_PACKAGE_PATH, "salvage", function()
decal_package_loading = false
end)
end)
if not load_success then
decal_package_loading = false
end
end
return false
end
local function decal_position(unit)
if POSITION_LOOKUP and POSITION_LOOKUP[unit] then
return POSITION_LOOKUP[unit]
end
if Unit and Unit.world_position then
local success, position = pcall(Unit.world_position, unit, ROOT_NODE_INDEX)
if success then
return position
end
end
return nil
end
local function apply_decal_style(decal_data, category)
local decal = category and category.decal
local decal_unit = decal_data and decal_data.unit
if not decal or not is_valid_unit(decal_unit) or not Unit.set_vector4_for_material or not Unit.set_scalar_for_material or not Unit.set_local_scale then
return
end
local colour = Quaternion.identity()
Quaternion.set_xyzw(colour, decal.red, decal.green, decal.blue, 0)
Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", decal.alpha)
Unit.set_local_scale(decal_unit, ROOT_NODE_INDEX, Vector3(DECAL_RADIUS * 2, DECAL_RADIUS * 2, 1))
decal_data.active = true
end
local function show_decal_for_unit(unit, pickup_type, category)
if not decal_enabled(category) then
stop_decal_for_unit(unit)
return
end
local decal_data = tracked_decals_by_unit[unit]
if decal_data and is_valid_unit(decal_data.unit) then
apply_decal_style(decal_data, category)
return
end
stop_decal_for_unit(unit)
if not ensure_decal_package() or not is_alive_unit(unit) or not World or type(World.spawn_unit_ex) ~= "function" or not Unit or type(Unit.world) ~= "function" then
return
end
local world_success, world = pcall(Unit.world, unit)
local position = decal_position(unit)
if not world_success or not world or not position then
return
end
local spawn_success, decal_unit = pcall(World.spawn_unit_ex, world, DECAL_PATH, nil, position)
if not spawn_success or not is_valid_unit(decal_unit) then
return
end
if World.link_unit then
pcall(World.link_unit, world, decal_unit, ROOT_NODE_INDEX, unit, ROOT_NODE_INDEX)
end
decal_data = {
unit = decal_unit,
pickup_type = pickup_type,
category_id = category.id,
radius = DECAL_RADIUS,
active = false,
}
tracked_decals_by_unit[unit] = decal_data
apply_decal_style(decal_data, category)
end
local function particle_vfx_candidates(effect)
return effect and effect.vfx_candidates or EMPTY_EFFECT_CANDIDATES
end
local function effect_variable(effect)
if not effect or not effect.radius_variable or not Vector3 then
return nil, nil
end
local radius = effect.radius_value or DECAL_RADIUS
return FIRE_360_RADIUS_VARIABLE, Vector3(radius, radius, radius)
end
local function apply_particle_variable(world, effect_id, effect_name, variable_name, variable_value)
if not world or not effect_id or not effect_name or not variable_name or not variable_value or not World.find_particles_variable or not World.set_particles_variable then
return
end
pcall(function()
local variable_index = World.find_particles_variable(world, effect_name, variable_name)
World.set_particles_variable(world, effect_id, variable_index, variable_value)
end)
end
local function spawn_world_effect(world, effect_position, effect)
if not world or not effect_position or not effect then
return nil
end
local variable_name, variable_value = effect_variable(effect)
local candidates = particle_vfx_candidates(effect)
local particle_group = mod._salvage_managed_particle_group(world)
for i = 1, #candidates do
local vfx = candidates[i]
local effect_id = mod._salvage_create_particle(world, vfx, effect_position, nil, nil, particle_group, variable_name, variable_value)
if effect_id then
apply_particle_variable(world, effect_id, vfx, variable_name, variable_value)
return effect_id
end
if type(mod._salvage_create_player_fx_particle) == "function" then
local player_effect_id = mod._salvage_create_player_fx_particle(vfx, effect_position, nil, nil, variable_name, variable_value)
if player_effect_id then
return { player_fx = true, particle_id = player_effect_id, vfx = vfx }
end
end
end
return nil
end
local function spawn_linked_effect(world, unit, node_index, node_position, translation_offset, effect)
if not world or not is_alive_unit(unit) or not effect or not effect.vfx or not node_position or not translation_offset or not Matrix4x4 or not Vector3 then
return nil
end
local effect_position = node_position + translation_offset
if effect.world_pulse then
return spawn_world_effect(world, effect_position, effect)
end
local particle_group = mod._salvage_managed_particle_group(world)
local candidates = particle_vfx_candidates(effect)
for i = 1, #candidates do
local vfx = candidates[i]
local effect_id = mod._salvage_create_particle(world, vfx, Vector3.zero(), nil, nil, particle_group)
if effect_id then
if World and type(World.link_particles) == "function" then
local attachment_pose = Matrix4x4.from_translation(translation_offset)
local orphaned_policy = effect.linked_orphaned_policy or "destroy"
local linked_success = pcall(World.link_particles, world, effect_id, unit, node_index, attachment_pose, orphaned_policy)
if linked_success then
return effect_id
end
stop_particle(world, effect_id)
else
return effect_id
end
end
end
return spawn_world_effect(world, effect_position, effect)
end
local function effect_repeat_interval(effect)
if not effect then
return nil
end
if effect.id == PULSE_EFFECT_ID then
return PULSE_INTERVAL
end
if effect.id == "daemonhost_shield" then
return 2
end
if effect.id == "fire_trail_01" then
return 1.5
end
if effect.id == "fire_360angle_01" or effect.id == "electricity_grenade_01" then
return REPEAT_INTERVAL
end
return nil
end
local function effect_spawn_count(effect_id)
return 1
end
local function particle_record_count(particle_record)
if type(particle_record) == "table" then
if particle_record.triggered or particle_record.player_fx then
return 1
end
return #particle_record
end
return particle_record and 1 or 0
end
local function append_particle_record(existing_record, new_record)
if not existing_record then
return new_record
end
local combined_record = {}
if type(existing_record) == "table" then
for i = 1, #existing_record do
combined_record[#combined_record + 1] = existing_record[i]
end
else
combined_record[#combined_record + 1] = existing_record
end
if type(new_record) == "table" then
for i = 1, #new_record do
combined_record[#combined_record + 1] = new_record[i]
end
else
combined_record[#combined_record + 1] = new_record
end
return combined_record
end
local function effect_height(effect)
if effect and type(effect.height) == "number" then
return effect.height
end
return DEFAULT_HEIGHT
end
local function create_effect_record(world, unit, effect)
if not world or not is_alive_unit(unit) or not effect or not Unit or type(Unit.world_position) ~= "function" or not Vector3 then
return nil
end
local node_index = ROOT_NODE_INDEX
local success, node_position = pcall(Unit.world_position, unit, node_index)
if not success or not node_position then
return nil
end
local particle_record = {}
local translation_offset = Vector3(0, 0, effect_height(effect))
local count = effect_spawn_count(effect.id)
for i = 1, count do
local effect_id = spawn_linked_effect(world, unit, node_index, node_position, translation_offset, effect)
if effect_id then
particle_record[#particle_record + 1] = effect_id
end
end
if #particle_record == 0 then
return nil
end
if #particle_record == 1 then
return particle_record[1]
end
return particle_record
end
local function effect_should_run(unit, effect_data, effect)
local category = effect_data and effect_data.category
if not category_enabled(category) then
return false
end
return effect_enabled(category, effect)
end
local function spawn_effect(unit, effect_data, effect)
if not effect_data or not effect_should_run(unit, effect_data, effect) or not is_alive_unit(unit) then
return
end
local world = effect_data.world
if not world then
return
end
local active_effects = effect_data.active_effects
local old_particle_record = active_effects[effect.id]
local max_cached_spawns = effect.max_cached_spawns
if max_cached_spawns then
if particle_record_count(old_particle_record) >= max_cached_spawns then
effect_data.completed_effects[effect.id] = true
return
end
local particle_record = create_effect_record(world, unit, effect)
if particle_record then
active_effects[effect.id] = append_particle_record(old_particle_record, particle_record)
if particle_record_count(active_effects[effect.id]) >= max_cached_spawns then
effect_data.completed_effects[effect.id] = true
end
end
return
end
stop_particle_record(world, old_particle_record)
active_effects[effect.id] = nil
local particle_record = create_effect_record(world, unit, effect)
if particle_record then
active_effects[effect.id] = particle_record
end
end
local function spawn_effects_for_unit(unit, pickup_type)
if not is_alive_unit(unit) then
return
end
local category = category_for_pickup_type(pickup_type)
if not category_has_any_effect(category) then
stop_decal_for_unit(unit)
return
end
show_decal_for_unit(unit, pickup_type, category)
if tracked_effects_by_unit[unit] then
return
end
if not category_has_particle_effect(category) then
return
end
if not Unit or type(Unit.world) ~= "function" then
return
end
local world_success, world = pcall(Unit.world, unit)
if not world_success or not world then
return
end
local effect_data = {
pickup_type = pickup_type,
category = category,
world = world,
active_effects = {},
timers = {},
completed_effects = {},
}
tracked_effects_by_unit[unit] = effect_data
for i = 1, #EFFECTS do
local effect = EFFECTS[i]
if effect_repeat_interval(effect) then
effect_data.timers[effect.id] = 0
end
spawn_effect(unit, effect_data, effect)
end
end
local function update_effects(dt)
local update_dt = type(dt) == "number" and dt or 0
for unit, effect_data in pairs(tracked_effects_by_unit) do
local category = effect_data.category
if not is_alive_unit(unit) or not category_has_particle_effect(category) then
stop_effect_for_unit(unit)
else
for i = 1, #EFFECTS do
local effect = EFFECTS[i]
local effect_id = effect.id
local timers = effect_data.timers
local interval = effect_repeat_interval(effect)
if effect_enabled(category, effect) then
if not effect_data.completed_effects[effect_id] then
if interval then
if not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
timers[effect_id] = 0
else
timers[effect_id] = (timers[effect_id] or 0) + update_dt
if timers[effect_id] >= interval then
timers[effect_id] = timers[effect_id] % interval
spawn_effect(unit, effect_data, effect)
end
end
elseif not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
end
end
else
stop_particle_record(effect_data.world, effect_data.active_effects[effect_id])
effect_data.active_effects[effect_id] = nil
effect_data.completed_effects[effect_id] = nil
timers[effect_id] = 0
end
end
end
end
end
local function register_pickup_unit(unit)
if not should_run() or not is_alive_unit(unit) then
return
end
local pickup_type = api.pickup_type_from_unit(unit)
mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)
if not pickup_type or not category_for_pickup_type(pickup_type) then
return
end
tracked_pickups_by_unit[unit] = pickup_type
end
local function add_desired_pickup_unit(desired_units, unit, pickup_type)
if type(desired_units) ~= "table" or not is_alive_unit(unit) then
return
end
pickup_type = pickup_type or api.pickup_type_from_unit(unit)
local category = category_for_pickup_type(pickup_type)
if not category_has_any_effect(category) then
return
end
tracked_pickups_by_unit[unit] = pickup_type
desired_units[unit] = pickup_type
end
local function add_pickup_system_units(desired_units)
local pickup_system = type(mod._salvage_current_pickup_system) == "function" and mod._salvage_current_pickup_system() or nil
if not pickup_system then
return
end
local function consider_unit(unit)
add_desired_pickup_unit(desired_units, unit, nil)
end
local function consider_table_units(source)
if type(source) ~= "table" then
return
end
for key, value in pairs(source) do
consider_unit(key)
consider_unit(value)
end
end
consider_table_units(pickup_system._spawned_pickups)
local dropped_pickups = nil
if type(pickup_system.dropped_pickups) == "function" then
local success, result = pcall(pickup_system.dropped_pickups, pickup_system)
if success then
dropped_pickups = result
end
end
if type(dropped_pickups) ~= "table" then
dropped_pickups = pickup_system._dropped_pickups
end
consider_table_units(dropped_pickups)
end
local function add_registered_pickup_units(desired_units)
for unit, pickup_type in pairs(tracked_pickups_by_unit) do
local category = category_for_pickup_type(pickup_type)
if is_alive_unit(unit) and category_has_any_effect(category) then
desired_units[unit] = pickup_type
elseif not is_alive_unit(unit) then
tracked_pickups_by_unit[unit] = nil
end
end
end
local function add_marker_units(desired_units)
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
local world_markers = hud and hud.element and hud:element("HudElementWorldMarkers")
local markers_by_type = world_markers and world_markers._markers_by_type
if not markers_by_type then
return
end
for _, markers in pairs(markers_by_type) do
for i = 1, #markers do
local marker = markers[i]
local unit = marker and marker.unit
local pickup_type = unit and api.pickup_type_from_unit(unit)
if not pickup_type then
pickup_type = pickup_type_from_marker_data(marker)
end
local category = category_for_pickup_type(pickup_type)
if type(unit) == "userdata" and category_has_any_effect(category) then
desired_units[unit] = pickup_type
tracked_pickups_by_unit[unit] = pickup_type
end
end
end
end
function mod._salvage_add_pickup_system_player_drop_units(desired_units)
local pickup_system = mod._salvage_current_pickup_system()
if not pickup_system then
return
end
local function consider_unit(unit)
if is_alive_unit(unit) and api.pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
local raw_reason = type(mod._salvage_loot_handler_raw_drop_reason) == "function" and mod._salvage_loot_handler_raw_drop_reason(unit) or nil
if raw_reason ~= "reward" then
local live_worth = type(mod._salvage_dropped_loot_amount_for_unit) == "function" and mod._salvage_dropped_loot_amount_for_unit(unit) or nil
if type(live_worth) == "number" and live_worth > 0 then
if type(mod._salvage_apply_player_drop_worth_to_unit) == "function" then
mod._salvage_apply_player_drop_worth_to_unit(unit, live_worth)
end
end
local reason = type(mod._salvage_player_drop_reason_for_unit) == "function" and mod._salvage_player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED
if type(mod._salvage_player_drop_worth_by_unit) == "table" and not mod._salvage_player_drop_worth_by_unit[unit] and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end
desired_units[unit] = reason
if type(mod._salvage_note_player_drop_pickup_unit) == "function" then
mod._salvage_note_player_drop_pickup_unit(unit, reason)
end
end
end
end
local spawned_pickups = pickup_system._spawned_pickups
if type(spawned_pickups) == "table" then
for _, unit in pairs(spawned_pickups) do
consider_unit(unit)
end
end
local dropped_pickups = nil
if type(pickup_system.dropped_pickups) == "function" then
local success, result = pcall(pickup_system.dropped_pickups, pickup_system)
if success then
dropped_pickups = result
end
end
if type(dropped_pickups) ~= "table" then
dropped_pickups = pickup_system._dropped_pickups
end
if type(dropped_pickups) == "table" then
for unit, _ in pairs(dropped_pickups) do
consider_unit(unit)
end
end
end
function mod._salvage_add_tracked_pickup_player_drop_units(desired_units)
for unit, pickup_type in pairs(tracked_pickups_by_unit) do
if is_alive_unit(unit) and pickup_type == PLAYER_DROP_PICKUP_TYPE then
local raw_reason = type(mod._salvage_loot_handler_raw_drop_reason) == "function" and mod._salvage_loot_handler_raw_drop_reason(unit) or nil
if raw_reason ~= "reward" then
local live_worth = type(mod._salvage_dropped_loot_amount_for_unit) == "function" and mod._salvage_dropped_loot_amount_for_unit(unit) or nil
if type(live_worth) == "number" and live_worth > 0 then
if type(mod._salvage_apply_player_drop_worth_to_unit) == "function" then
mod._salvage_apply_player_drop_worth_to_unit(unit, live_worth)
end
end
local reason = type(mod._salvage_player_drop_reason_for_unit) == "function" and mod._salvage_player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED
if type(mod._salvage_player_drop_worth_by_unit) == "table" and not mod._salvage_player_drop_worth_by_unit[unit] and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end
desired_units[unit] = reason
if type(mod._salvage_note_player_drop_pickup_unit) == "function" then
mod._salvage_note_player_drop_pickup_unit(unit, reason)
end
end
end
end
end
local function sync_effects()
if not should_run() then
stop_all_visuals(true)
return
end
local desired_units = mod._salvage_sync_effects_desired_units_scratch
clear_table(desired_units)
add_registered_pickup_units(desired_units)
add_pickup_system_units(desired_units)
add_marker_units(desired_units)
for unit, pickup_type in pairs(desired_units) do
mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)
spawn_effects_for_unit(unit, pickup_type)
end
for unit, effect_data in pairs(tracked_effects_by_unit) do
local desired_pickup_type = desired_units[unit]
if not is_alive_unit(unit) or not desired_pickup_type or effect_data.pickup_type ~= desired_pickup_type then
stop_effect_for_unit(unit)
end
end
for unit, decal_data in pairs(tracked_decals_by_unit) do
local desired_pickup_type = desired_units[unit]
local category = category_for_pickup_type(desired_pickup_type)
if not is_alive_unit(unit) or not desired_pickup_type or decal_data.pickup_type ~= desired_pickup_type or not decal_enabled(category) then
stop_decal_for_unit(unit)
end
end
end
function api.is_effect_setting(setting_id)
return is_salvage_effect_setting(setting_id)
end
function api.stop_all(clear_units)
stop_all_visuals(clear_units)
end
function api.sync()
sync_effects()
end
function api.update(dt)
update_effects(dt)
end
function api.on_unit_deleted(unit)
if not unit then
return
end
stop_effect_for_unit(unit)
stop_decal_for_unit(unit)
tracked_pickups_by_unit[unit] = nil
cached_pickup_types_by_unit[unit] = nil
end
return api
end
