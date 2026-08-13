-- salvage_core.lua
return function(mod, exits)
local SYNC_INTERVAL = 0.25
local FALLEN_MARKER_SYNC_INTERVAL = 0.5
local PLAYER_DROP_MARKER_SYNC_INTERVAL = 0.5
local function load_file(path)
if not Mods or not Mods.file or type(Mods.file.dofile) ~= "function" then
return nil
end
local success, result = pcall(Mods.file.dofile, path)
if success then
return result
end
return nil
end
local function load_api(path, shared)
local factory = load_file(path)
if type(factory) ~= "function" then
return {}
end
local success, result = pcall(factory, mod, shared)
if success and type(result) == "table" then
return result
end
return {}
end
local function has_method(module, method)
return module and type(module[method]) == "function"
end
local context = load_file("salvage/scripts/mods/salvage/salvage_expedition_context") or {}
local should_run = type(context.should_run) == "function" and context.should_run or function()
return false
end
local menu = load_file("salvage/scripts/mods/salvage/salvage_menu") or {}
load_file("salvage/scripts/mods/salvage/salvage_particles")
local fallen_markers = load_file("salvage/scripts/mods/salvage/salvage_fallen_markers") or {}
local pickup_visuals = load_api("salvage/scripts/mods/salvage/salvage_pickup_visuals", { context = context })
local reliquaries = load_api("salvage/scripts/mods/salvage/salvage_reliquaries", { context = context, pickup_type_from_unit = pickup_visuals.pickup_type_from_unit })
local player_drops = load_api("salvage/scripts/mods/salvage/salvage_player_drops", { context = context, pickup_type_from_unit = pickup_visuals.pickup_type_from_unit, pickup_type_from_marker_data = pickup_visuals.pickup_type_from_marker_data, tracked_pickups_by_unit = pickup_visuals.tracked_pickups_by_unit })
local sync_timer = SYNC_INTERVAL
local fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
local player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL
local function reset_timers()
sync_timer = SYNC_INTERVAL
fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL
end
local function stop_runtime_visuals(clear_units)
if has_method(pickup_visuals, "stop_all") then
pickup_visuals.stop_all(clear_units)
end
if has_method(reliquaries, "stop_all") then
reliquaries.stop_all(clear_units)
end
if type(mod._salvage_reset_particle_runtime) == "function" then
mod._salvage_reset_particle_runtime()
end
if has_method(fallen_markers, "remove_all") then
fallen_markers.remove_all()
end
if has_method(player_drops, "remove_all") then
player_drops.remove_all()
end
end
local function install_unit_deletion_cleanup_hook()
if mod._salvage_unit_deletion_cleanup_hook_done then
return
end
mod._salvage_unit_deletion_cleanup_hook_done = true
if not mod or type(mod.hook_safe) ~= "function" then
return
end
mod:hook_safe("UnitSpawnerManager", "mark_for_deletion", function(_, unit)
if has_method(player_drops, "on_unit_deleted") then
player_drops.on_unit_deleted(unit)
end
if has_method(pickup_visuals, "on_unit_deleted") then
pickup_visuals.on_unit_deleted(unit)
end
if has_method(reliquaries, "on_unit_deleted") then
reliquaries.on_unit_deleted(unit)
end
if has_method(fallen_markers, "remove_for_unit") then
fallen_markers.remove_for_unit(unit)
end
if has_method(fallen_markers, "clear_found") then
fallen_markers.clear_found(unit)
end
end)
end
mod.on_all_mods_loaded = function()
if has_method(menu, "on_all_mods_loaded") then
menu.on_all_mods_loaded()
end
if has_method(player_drops, "on_all_mods_loaded") then
player_drops.on_all_mods_loaded()
end
install_unit_deletion_cleanup_hook()
if exits and type(exits.on_all_mods_loaded) == "function" then
exits.on_all_mods_loaded()
end
end
mod.update = function(dt)
if exits and type(exits.update) == "function" then
exits.update(dt)
end
if not should_run() then
stop_runtime_visuals(true)
reset_timers()
return
end
local update_dt = type(dt) == "number" and dt or 0
sync_timer = sync_timer + update_dt
fallen_marker_sync_timer = fallen_marker_sync_timer + update_dt
player_drop_marker_sync_timer = player_drop_marker_sync_timer + update_dt
if sync_timer >= SYNC_INTERVAL then
sync_timer = sync_timer % SYNC_INTERVAL
if has_method(pickup_visuals, "sync") then
pickup_visuals.sync()
end
if has_method(reliquaries, "sync") then
reliquaries.sync()
end
end
if fallen_marker_sync_timer >= FALLEN_MARKER_SYNC_INTERVAL then
fallen_marker_sync_timer = fallen_marker_sync_timer % FALLEN_MARKER_SYNC_INTERVAL
if has_method(fallen_markers, "sync") then
fallen_markers.sync()
end
end
if player_drop_marker_sync_timer >= PLAYER_DROP_MARKER_SYNC_INTERVAL then
player_drop_marker_sync_timer = player_drop_marker_sync_timer % PLAYER_DROP_MARKER_SYNC_INTERVAL
if has_method(player_drops, "observe_local") then
player_drops.observe_local()
end
if has_method(player_drops, "observe_stolen") then
player_drops.observe_stolen()
end
if has_method(player_drops, "sync") then
player_drops.sync()
end
end
if has_method(pickup_visuals, "update") then
pickup_visuals.update(update_dt)
end
if has_method(reliquaries, "update") then
reliquaries.update(update_dt)
end
end
mod.on_setting_changed = function(setting_id)
if has_method(pickup_visuals, "is_effect_setting") and pickup_visuals.is_effect_setting(setting_id) then
if has_method(pickup_visuals, "stop_all") then
pickup_visuals.stop_all(false)
end
sync_timer = SYNC_INTERVAL
if should_run() and has_method(pickup_visuals, "sync") then
pickup_visuals.sync()
end
end
if has_method(reliquaries, "is_setting") and reliquaries.is_setting(setting_id) then
if has_method(reliquaries, "stop_all") then
reliquaries.stop_all(false)
end
sync_timer = SYNC_INTERVAL
if should_run() and has_method(reliquaries, "sync") then
reliquaries.sync()
end
end
if setting_id == "mark_fallen_comrades" then
if has_method(fallen_markers, "remove_all") then
fallen_markers.remove_all()
end
fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
if should_run() and has_method(fallen_markers, "sync") then
fallen_markers.sync()
end
end
if setting_id == "mark_player_dropped_remnants" then
if has_method(player_drops, "remove_all") then
player_drops.remove_all()
end
player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL
if should_run() and has_method(player_drops, "sync") then
player_drops.sync()
end
end
if setting_id == "player_drop_warning" and has_method(player_drops, "reset_warning") then
player_drops.reset_warning()
end
if exits and type(exits.on_setting_changed) == "function" then
exits.on_setting_changed(setting_id)
end
end
mod.on_game_state_changed = function(status, state)
if status == "exit" or status == "enter" and state == "StateGameScore" then
stop_runtime_visuals(true)
reset_timers()
end
if exits and type(exits.on_game_state_changed) == "function" then
exits.on_game_state_changed(status, state)
end
end
mod.on_unload = function()
stop_runtime_visuals(true)
if exits and type(exits.on_unload) == "function" then
exits.on_unload()
end
end
mod.on_disabled = function()
stop_runtime_visuals(true)
if exits and type(exits.on_disabled) == "function" then
exits.on_disabled()
end
end
end
