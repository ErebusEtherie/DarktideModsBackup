-- mutator_guard.lua
--
-- Makes sure the curse a leg was launched with is the curse the mission actually
-- runs, and reports the ground truth either way.
--
-- ===========================================================================
-- WHY THIS EXISTS: THE LEVEL LOAD WIPES THE LUA VM
-- ===========================================================================
--
-- run_state.lua's charter says it plainly: between missions, the mod's Lua state
-- is gone. That constraint is not only ours. The GAME's Lua state is rebuilt by a
-- level load too, including the require cache, which means the synthetic stacked
-- circumstance curses.lua registers into CircumstanceTemplates in the hub does
-- not exist in the mission's fresh copy of that table.
--
-- What the engine then does with a circumstance name it cannot find
-- (mechanism_adventure.lua:63): logs an error and quietly falls back to
-- "default". The mission loads, plays, and carries ZERO mutators. No crash, no
-- message a player would ever see. That is exactly the "half a mission of
-- Heinous Rituals with no daemonhosts" Kaizen reported: from assignment 2 on,
-- every leg launched under the stacked name, and every one of them fell back.
--
-- Two repairs, and both are needed because we cannot rely on ordering between
-- the engine's loading flow and mod load in the fresh VM:
--
--   1. RE-REGISTRATION AT ARRIVAL. curses.receive_templates now re-registers
--      the stacked template the moment the fresh VM's template table reaches
--      us, rebuilt from the settings-persisted run (settings survive the wipe;
--      that is the whole reason run_state stores the route there).
--
--   2. CORRECTION AT POINT OF USE (this module). The launcher records what it
--      launched (mission + circumstance) in settings. In the mission VM we hook
--      the two consumers of circumstance_name, CircumstanceManager.init and
--      MutatorManager._load_mutators, and if the engine arrives with something
--      other than what was launched (it fell back before our re-registration
--      could exist), we hand it the recorded name instead.
--
-- The hook on _load_mutators also gives us the thing this bug proved we need:
-- GROUND TRUTH. After the original runs we record which mutators actually
-- loaded and emit it to the event log; the entry file turns it into one line
-- on screen when gameplay starts, and /pil_mutators reads the live managers.
-- "The terminal said Heinous Rituals" is a claim; "mutator_more_witches
-- loaded" is a fact.
--
-- ===========================================================================
-- SAFETY FENCES, ALL OF WHICH MUST PASS BEFORE ANYTHING IS CORRECTED
-- ===========================================================================
--
--   * solo host only (shared.is_solo_host). A matchmade public mission must
--     never have a circumstance forced into it, whatever our run state says.
--   * an active pilgrimage run.
--   * the mission being loaded IS the mission the record was written for.
--     The hub is a mission too; without this check the guard would try to
--     curse the Mourningstar.
--   * the curses_guard setting (default on) as the kill switch.
--
-- When any fence fails, the engine's value passes through untouched.

local M = {}

local _mod
local _shared
local _hooks
local _run_state
local _curses
local _event_log
-- Declared at the top, above every function, because a Lua function only
-- captures locals that exist above its definition (the v0.14.1 boons lesson).
local _debug_log

-- Ground truth from the last mission load, for /pil_mutators and the notes.
local _last_report = nil

-- ---------------------------------------------------------------------------
-- The decision, pure and testable
-- ---------------------------------------------------------------------------

-- incoming        what the engine is about to use
-- expected        what the launcher recorded for this mission
-- expected_exists is the expected name resolvable in THIS VM's template table
--                 (after a re-registration attempt)
-- fallback        the leg's own single curse, for when the stacked name cannot
--                 be rebuilt; may be nil
-- fallback_exists as above, for the fallback
--
-- Returns name_to_use, note. note is nil when nothing was changed; otherwise a
-- short human sentence for the on-screen line and the event log.
function M.decide(incoming, expected, expected_exists, fallback, fallback_exists)
	if type(expected) ~= "string" or expected == "" or expected == "default" then
		return incoming, nil
	end

	if expected_exists then
		if incoming == expected then
			return incoming, nil
		end
		return expected, "curse restored: engine had '" .. tostring(incoming)
			.. "', launch recorded '" .. expected .. "'"
	end

	-- The recorded name cannot be honoured in this VM even after re-registration.
	-- Degrade to the leg's own curse rather than to nothing.
	if type(fallback) == "string" and fallback ~= "" and fallback ~= "default"
		and fallback_exists and incoming ~= fallback then
		return fallback, "stacked curse unavailable, restored this leg's own curse '"
			.. fallback .. "'"
	end

	return incoming, nil
end

-- ---------------------------------------------------------------------------
-- In-game orchestration
-- ---------------------------------------------------------------------------

local function _guard_enabled()
	if not _mod or type(_mod.get) ~= "function" then return true end
	local ok, value = pcall(_mod.get, _mod, "curses_guard")
	if not ok or value == nil then return true end
	return value == true
end

local function _current_mission_name()
	local mission_manager = Managers and Managers.state and Managers.state.mission
	if not mission_manager or type(mission_manager.mission_name) ~= "function" then
		return nil
	end
	local ok, name = pcall(mission_manager.mission_name, mission_manager)
	if ok and type(name) == "string" and name ~= "" then return name end
	return nil
end

-- Returns name_to_use, note. Every fence that fails returns the engine's value.
function M.correct(incoming)
	if not _guard_enabled() then return incoming, nil end
	if not (_shared and _shared.is_solo_host()) then return incoming, nil end
	if not (_run_state and _run_state.is_active()) then return incoming, nil end

	local record = _run_state.launch_record and _run_state.launch_record()
	if not record then return incoming, nil end

	local mission = _current_mission_name()
	if not mission or mission ~= record.mission then return incoming, nil end

	local expected = record.circumstance

	-- The stacked template lives only as long as one Lua VM. Rebuild it from the
	-- persisted run before judging whether the expected name exists here.
	if _curses.exists(expected) ~= true and type(_curses.ensure_registered) == "function" then
		pcall(_curses.ensure_registered)
	end

	local fallback = _run_state.current_curse and _run_state.current_curse() or nil

	return M.decide(
		incoming,
		expected,
		_curses.exists(expected) == true,
		fallback,
		fallback ~= nil and _curses.exists(fallback) == true)
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

local function _loaded_mutator_names(mutator_manager)
	local names = {}
	local mutators = mutator_manager and mutator_manager._mutators
	if type(mutators) ~= "table" then return names end
	for name in pairs(mutators) do names[#names + 1] = tostring(name) end
	table.sort(names)
	return names
end

local function _report(mutator_manager, incoming, used, note)
	local names = _loaded_mutator_names(mutator_manager)

	_last_report = {
		incoming = tostring(incoming),
		used = tostring(used),
		note = note,
		mutators = names,
		mission = _current_mission_name(),
	}

	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "mutators_loaded",
			id = _event_log.next_id(),
			incoming = tostring(incoming),
			used = tostring(used),
			corrected = note ~= nil,
			count = #names,
			mutators = table.concat(names, ","),
		})
	end

	-- NO on-screen notification from here. This runs during gameplay INIT,
	-- before the notification feed is listening, and a message triggered into
	-- the void just disappears (the world-marker lesson). The entry file shows
	-- the banner on entering GameplayStateRun, reading last_report.
end

function M.last_report()
	return _last_report
end

-- ---------------------------------------------------------------------------
-- Hook installation. Both consumers of circumstance_name get the same
-- corrected answer, so the audio/theme layer and the mutator layer agree.
-- ---------------------------------------------------------------------------

function M.install_mutator_manager(MutatorManager)
	if _hooks.claim(MutatorManager, "__pilgrimage_mutator_guard") then return end

	_mod:hook(MutatorManager, "_load_mutators", function(func, self, circumstance_name)
		local used, note = circumstance_name, nil
		local ok, err = pcall(function()
			used, note = M.correct(circumstance_name)
		end)
		if not ok then
			used, note = circumstance_name, nil
			_debug_log("mutator_guard", 0, "correct threw: " .. tostring(err), 0, "error")
		end

		local result = func(self, used)

		pcall(_report, self, circumstance_name, used, note)
		return result
	end)
end

function M.install_circumstance_manager(CircumstanceManager)
	if _hooks.claim(CircumstanceManager, "__pilgrimage_mutator_guard") then return end

	-- Silent here: the mutator hook owns the on-screen report, and both hooks
	-- compute the same answer from the same record.
	_mod:hook(CircumstanceManager, "init", function(func, self, circumstance_name)
		local used = circumstance_name
		pcall(function()
			used = (M.correct(circumstance_name))
		end)
		return func(self, used)
	end)
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_run_state = deps.run_state
	_curses = deps.curses
	_event_log = deps.event_log
	_debug_log = deps.debug_log or function() end
end

return M
