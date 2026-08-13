--[[
	Name: Noospheric Mercy
	Author: Wobin
	URL: https://github.com/Wobin/NoosphericMercy
	Date: 27/07/2026
	Version: 2.2.0
]]--

local mod = get_mod("Noospheric Mercy")
mod.version = "2.2.0"

local Tracker = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/tracker")
local TargetResolve = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/target_resolve")
local HackTarget = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/hack_target")
local HackArm = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/hack_arm")
local Visuals = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/visuals")
local Broadcast = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/broadcast")
local ChatListen = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/chat_listen")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")
local Settings = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/settings")

local function player_name_of(unit)
	local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
	local player = player_unit_spawn and player_unit_spawn:owner(unit)

	return (player and player.name and player:name()) or tostring(unit)
end

local function is_in_mission()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local name = game_mode_manager and game_mode_manager:game_mode_name()

	return name ~= nil and name ~= "hub" and name ~= "prologue_hub" and name ~= "shooting_range"
end

local _broadcast_done = {}

local function on_inject_ally(companion_unit, target_finder_component, position_finder_component, ability_extension, is_server)
	if not is_in_mission() then
		return
	end

	local ally = target_finder_component and target_finder_component.target_unit_1

	if not ally then
		Log.write("INJECT hook fired but target_unit_1 was nil (is_server=%s)", tostring(is_server))
		return
	end

	local changed = TargetResolve.set_exact(companion_unit, ally)

	if not changed then
		return
	end

	local player_unit_spawn = Managers.state.player_unit_spawn
	local owner_player = player_unit_spawn and player_unit_spawn:owner(companion_unit)
	local local_player = Managers.player:local_player(1)
	local firer_is_local = owner_player ~= nil and owner_player == local_player

	Log.write("INJECT hook: firer=%s target=%s is_server=%s firer_is_local=%s",
		player_name_of(companion_unit), player_name_of(ally), tostring(is_server), tostring(firer_is_local))

	if firer_is_local and not _broadcast_done[companion_unit] then
		local down_count = TargetResolve.count_needs_help()

		if Settings.get("broadcast_only_when_multiple") and down_count < 2 then
			Log.write("BROADCAST skipped: only %d player needs help (target is unambiguous)", down_count)
		else
			_broadcast_done[companion_unit] = true
			Broadcast.rescue(ally)
		end
	end
end

local function register_inject_hook()
	mod:hook_require("scripts/utilities/companion/companion_servo_skull_ability", function(instance)
		if instance and instance.start_inject_ally_ability then
			mod:hook_safe(instance, "start_inject_ally_ability", on_inject_ally)
			Log.write("INJECT hook attached via hook_require")
		end
	end)
end

mod:hook_safe("ChatManager", "_handle_event", function(self, message)
	if not is_in_mission() then
		return
	end

	ChatListen.on_message(message)
end)

local _refresh_log = {}
local _game_session = nil
local _hack_update_notified = false

local HACK_NODE = "targeting_rotation_node"

Tracker.on_start = function(go_id, skull_unit, kind)
	Log.write("%s START skull go_id=%s firer=%s",
		kind == Tracker.KIND_HACK and "HACK" or "RESCUE", tostring(go_id), player_name_of(skull_unit))
	Visuals.start(go_id)
end

Tracker.on_refresh = function(go_id, skull_unit, dt, t, kind)
	if kind == Tracker.KIND_HACK then
		local target = HackTarget.resolve(_game_session, go_id)

		if not target then
			if _refresh_log[go_id] ~= "hack_none" then
				_refresh_log[go_id] = "hack_none"
				Log.write("HACK skull go_id=%s -> no target", tostring(go_id))
				Visuals.clear(go_id)
			end

			return
		end

		_refresh_log[go_id] = "hack"
		Visuals.apply_hack(go_id, target, HackTarget.position_of(target, HACK_NODE))

		return
	end

	local ally, confidence, locked, source = TargetResolve.resolve(go_id, skull_unit, dt)

	if not ally then
		if _refresh_log[go_id] ~= "none" then
			_refresh_log[go_id] = "none"
			Log.write("RESOLVE skull go_id=%s -> no target (target recovered or unresolved)", tostring(go_id))
			Visuals.clear(go_id)
		end

		return
	end

	local name = player_name_of(ally)
	local key = name .. "|" .. tostring(confidence) .. "|" .. tostring(locked) .. "|" .. tostring(source)

	if _refresh_log[go_id] ~= key then
		_refresh_log[go_id] = key
		Log.write("RESOLVE skull go_id=%s -> target=%s confidence=%s locked=%s source=%s",
			tostring(go_id), name, tostring(confidence), tostring(locked), tostring(source))
	end

	Visuals.apply(go_id, ally, TargetResolve.position_of(ally), confidence)
end

Tracker.on_end = function(go_id, skull_unit, kind)
	local t = Managers.time:time("gameplay")

	Log.write("%s END skull go_id=%s firer=%s",
		kind == Tracker.KIND_HACK and "HACK" or "RESCUE", tostring(go_id), player_name_of(skull_unit))
	_refresh_log[go_id] = nil
	Visuals.stop(go_id, t)

	if kind == Tracker.KIND_HACK then
		HackTarget.clear(go_id)

		return
	end

	_broadcast_done[skull_unit] = nil
	TargetResolve.clear(skull_unit)
end

local SCAN_INTERVAL = 0.1
local _scan_accum = 0

mod.update = function(dt)
	if not is_in_mission() then
		Tracker.reset()
		Visuals.reset()
		HackTarget.reset()
		HackArm.reset()

		for skull in pairs(_broadcast_done) do
			_broadcast_done[skull] = nil
		end

		_game_session = nil
		_scan_accum = 0

		return
	end

	local state = Managers.state
	local time_manager = Managers.time
	local game_session_manager = state and state.game_session
	local game_session = game_session_manager and game_session_manager:game_session()

	if not (game_session
		and Managers.player
		and state.unit_spawner
		and state.extension
		and time_manager and time_manager:has_timer("gameplay")
		and ALIVE and POSITION_LOOKUP) then
		return
	end

	local t = time_manager:time("gameplay")

	_game_session = game_session
	_scan_accum = _scan_accum + dt

	if HackArm.is_broken() and not _hack_update_notified and Managers.event then
		_hack_update_notified = true
		Managers.event:trigger("event_add_notification_message", "alert",
			{ text = "Noospheric Mercy: a game update changed the hacking-detection API. Running in fallback mode - please update the mod." })
	end

	if _scan_accum >= SCAN_INTERVAL then
		local elapsed = _scan_accum
		_scan_accum = 0

		TargetResolve.log_down_transitions()

		if HackArm.is_broken() or TargetResolve.any_needs_help() or HackArm.is_active() or next(Tracker.active) then
			Tracker.update(elapsed, t, game_session)
		end
	end

	Visuals.update(t)
end

mod.on_all_mods_loaded = function()
	mod:info(mod.version)
	Settings.refresh()
	Visuals.register_outline()
	Visuals.register_marker()
	register_inject_hook()
	HackArm.register()
end

mod.on_setting_changed = function(setting_id)
	Settings.refresh()
	Visuals.refresh_outline_priority()
end

mod.on_unload = function()
	Visuals.cleanup_all()
end
