-- shared.lua
--
-- Game-state helpers and the identifiers we would otherwise duplicate across modules.
-- BetterBots calls its equivalent shared_rules.lua, and the rule is: if a game string
-- or constant appears in more than one file, it lives here, so a Fatshark rename is a
-- single-file edit.
--
-- Every engine global is fetched through rawget so that a missing global degrades
-- rather than crashing.

local M = {}

local _mod

-- ---------------------------------------------------------------------------
-- Identifiers
-- ---------------------------------------------------------------------------

-- Game mode names that count as "standing around in the Mourningstar", which is
-- where the terminal lives and where a run can be started.
M.HUB_MODES = {
	hub            = true,
	hub_singleplay = true,
	prologue_hub   = true,
}

-- The training grounds. Useful as a safe sandbox for testing without a real mission.
--
-- There are TWO of these and they share one implementation
-- (game_mode_training_grounds.lua). "shooting_range" is the Psykhanium you walk into from
-- the Mourningstar; "training_grounds" is the other entry point. Knowing only one of them
-- is how the Psykhanium ended up being treated as a pilgrimage leg.
M.PSYKHANIUM_MODE = "shooting_range"

M.PSYKHANIUM_MODES = {
	shooting_range   = true,
	training_grounds = true,
}

-- Engine mechanism names we care about. `expedition` is the vanilla multi-level
-- sequential mode we are considering driving; `adventure` is a normal mission.
M.MECHANISM_ADVENTURE = "adventure"
M.MECHANISM_EXPEDITION = "expedition"

-- ---------------------------------------------------------------------------
-- Time
-- ---------------------------------------------------------------------------

local FixedFrame

-- Fixed-frame simulation time. This is the clock to use for ALL gameplay logic,
-- because it advances in fixed steps and is consistent with everything the engine
-- does. It resets each mission.
--
-- Before the extension manager exists (during load) there is no fixed time at all,
-- so we return 0 rather than crashing.
function M.fixed_time()
	local extension_manager = Managers and Managers.state and Managers.state.extension
	if not extension_manager or not extension_manager.latest_fixed_t then
		return 0
	end
	if not FixedFrame then
		local ok, module = pcall(require, "scripts/utilities/fixed_frame")
		if not ok then return 0 end
		FixedFrame = module
	end
	return FixedFrame.get_latest_fixed_time()
end

-- Wall-clock seconds. Only for profiling and log filenames, NEVER for gameplay,
-- because it does not respect pause or time scale and does not reset per mission.
function M.wall_time()
	return os.clock()
end

-- ---------------------------------------------------------------------------
-- Session and state queries
-- ---------------------------------------------------------------------------

function M.game_mode_name()
	local manager = Managers and Managers.state and Managers.state.game_mode
	if not manager or not manager.game_mode_name then return nil end
	local ok, name = pcall(manager.game_mode_name, manager)
	return ok and name or nil
end

function M.is_in_hub()
	return M.HUB_MODES[M.game_mode_name()] == true
end

function M.is_in_psykhanium()
	return M.PSYKHANIUM_MODES[M.game_mode_name()] == true
end

-- The mission currently loaded, by its internal name, or nil when there is not one.
--
-- This is the only trustworthy answer to "which mission am I actually in". The game mode
-- name is too coarse: a pilgrimage leg and a mission the player launched on their own are
-- both "coop_complete_objective". Comparing this against the run's expected mission is
-- what tells the two apart.
function M.mission_name()
	local manager = Managers and Managers.state and Managers.state.mission
	if not manager or not manager.mission_name then return nil end
	local ok, name = pcall(manager.mission_name, manager)
	return ok and name or nil
end

-- True when we are hosting a session with no other humans in it. This is the gate
-- for everything that is not network-safe: injected buff templates, direct component
-- writes, spawning, and so on.
--
-- Three independent checks, because any one of them can be unavailable depending on
-- when we ask.
function M.is_solo_host()
	local session = Managers and Managers.multiplayer_session
	if session and session.host_type then
		local ok, host_type = pcall(session.host_type, session)
		if ok and host_type then
			local constants = rawget(_G, "MatchmakingConstants")
			local singleplay = constants and constants.HOST_TYPES and constants.HOST_TYPES.singleplay
			if singleplay and host_type == singleplay then return true end
			if host_type == "singleplay" then return true end
		end
	end

	local game_mode = Managers and Managers.state and Managers.state.game_mode
	local settings = game_mode and game_mode.settings and game_mode:settings() or nil
	if settings and settings.host_singleplay == true then return true end

	return false
end

function M.is_server()
	local session = Managers and Managers.state and Managers.state.game_session
	if not session or not session.is_server then return false end
	local ok, is_server = pcall(session.is_server, session)
	return ok and is_server or false
end

-- ---------------------------------------------------------------------------
-- On-screen feedback
--
-- mod:notify and mod:echo route through DMF's logging layer, which on this install
-- is switched off entirely (logging_mode = "custom" with every output_mode_* at 0).
-- Every DMF logging call is a silent no-op here.
--
-- DMF's own logging.lua reaches the notification feed with a plain event trigger,
-- so we can call that directly and bypass the disabled settings completely. This is
-- the only reliable way to tell the player something happened.
--
-- Valid notification types, from DMF's _notification_types table: achievement,
-- alert, contract, currency, default, dev, item_granted, matchmaking.
-- ---------------------------------------------------------------------------

function M.notify(message, notification_type)
	if not Managers or not Managers.event then return false end
	-- v0.22.16: defensively substitute a placeholder when the message
	-- string is nil or empty. This kills the "empty red popup" pattern
	-- Kaizen was seeing occasionally (e.g. on run failure). A caller
	-- that ends up handing us "" is a bug, but a visible placeholder
	-- lets us track it down instead of the notification being an
	-- invisible red bar.
	local text = tostring(message)
	if text == nil or text == "" then
		text = "Pilgrimage: (empty notification, please report)"
	end
	local ok = pcall(function()
		Managers.event:trigger(
			"event_add_notification_message",
			notification_type or "default",
			text,
			nil,
			nil)
	end)
	return ok
end

-- ---------------------------------------------------------------------------
-- Player
-- ---------------------------------------------------------------------------

function M.local_player()
	local player_manager = Managers and Managers.player
	if not player_manager then return nil end
	local getter = player_manager.local_player_safe or player_manager.local_player
	if not getter then return nil end
	local ok, player = pcall(getter, player_manager, 1)
	return ok and player or nil
end

function M.local_player_unit()
	local player = M.local_player()
	local unit = player and player.player_unit
	local Unit = rawget(_G, "Unit")
	if unit and Unit and Unit.alive and not Unit.alive(unit) then return nil end
	return unit
end

-- Fetch an extension off a unit by system name, nil-safe.
-- Extension names are things like "buff_system", "health_system", "unit_data_system".
function M.extension(unit, name)
	local ScriptUnit = rawget(_G, "ScriptUnit")
	if not unit or not ScriptUnit or not ScriptUnit.has_extension then return nil end
	local ok, extension = pcall(ScriptUnit.has_extension, unit, name)
	return ok and extension or nil
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
end

return M
