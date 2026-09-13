-- betterbots_bridge.lua
--
-- Pilgrimage-owned, optional compatibility layer for Better Bots navigation.
-- Better Bots itself is never edited or redistributed. Instead, this module
-- wraps Darktide's shared NavQueries.ray_can_go function in memory and acts only
-- when the Lua call stack proves that one of two Better Bots files called it.
--
-- Field testing showed that caching and state checks reduced the frequency of
-- the native gwnav access violation but could not prevent it. A native worker
-- crash cannot be caught by Lua's pcall after the query has been submitted, so
-- the enabled guard now isolates these two optional Better Bots queries from
-- gwnav completely during a recorded Pilgrimage mission.
--
-- The isolation is deliberately gated four ways:
--   1. the Pilgrimage option is explicitly enabled;
--   2. Better Bots is installed;
--   3. the loaded mission matches Pilgrimage's recorded launch;
--   4. the caller is Better Bots hazard or charge navigation code.
--
-- Every other call reaches Darktide unchanged.

local M = {}

local _mod
local _hooks
local _settings
local _shared
local _run_state
local _debug_log
local _installed = false
local _dependency_seen = false
local _stats

local function _fresh_stats()
	return {
		bypassed = 0,
		by_caller = {
			hazard_dodge = 0,
			charge_path = 0,
		},
	}
end

_stats = _fresh_stats()

local function _enabled()
	return _settings and _settings.betterbots_navigation_guard_enabled
		and _settings.betterbots_navigation_guard_enabled() == true
end

local function _betterbots_present()
	if _dependency_seen then return true end
	local get_mod_fn = rawget(_G, "get_mod")
	if type(get_mod_fn) ~= "function" then return false end
	local ok, dependency = pcall(get_mod_fn, "BetterBots")
	if ok and dependency ~= nil then
		_dependency_seen = true
		return true
	end
	return false
end

local function _pilgrimage_mission_active()
	if not (_run_state and _shared) then return false end

	local ok_active, active = pcall(_run_state.is_active)
	if not ok_active or not active then return false end

	local ok_launch, launch = pcall(_run_state.launch_record)
	local ok_mission, mission = pcall(_shared.mission_name)
	return ok_launch and ok_mission
		and type(launch) == "table"
		and type(launch.mission) == "string"
		and mission == launch.mission
end

local function _inspect_stack_frame(level, debug_lib)
	local info = debug_lib.getinfo(level + 1, "S")
	if not info then return nil end

	local source = tostring(info.source or info.short_src or ""):lower():gsub("\\", "/")
	if not source:find("betterbots", 1, true) then return nil end
	if source:find("hazard_avoidance.lua", 1, true) then
		return "hazard_dodge"
	elseif source:find("charge_nav_validation.lua", 1, true) then
		return "charge_path"
	end
	return nil
end

local function _betterbots_caller()
	local debug_lib = rawget(_G, "debug")
	if not (debug_lib and type(debug_lib.getinfo) == "function") then
		return nil
	end

	-- DMF adds wrapper frames around hooks, and their exact count can vary with
	-- load order. Search a narrow bounded window instead of assuming one depth.
	for level = 2, 18 do
		local ok, caller = pcall(_inspect_stack_frame, level, debug_lib)
		if ok and caller then return caller end
	end
	return nil
end

local function _isolated_result(caller, start_position, end_position)
	if caller == "hazard_dodge" then
		-- Endpoint validation is an extra Better Bots layer. Returning success
		-- lets the already-selected base-game dodge proceed.
		return true, start_position, end_position
	end

	-- A charge is optional. Returning no valid projection makes Better Bots
	-- postpone it through its existing validation/retry path.
	return false, nil, nil
end

local function _install_hook()
	_hooks.require_now("scripts/utilities/nav_queries", function(NavQueries)
		if _installed or not (NavQueries and type(NavQueries.ray_can_go) == "function") then
			return
		end

		_mod:hook(NavQueries, "ray_can_go", function(func, nav_world, start_position,
			end_position, traverse_logic, check_above, check_below)
			if not _enabled() or not _betterbots_present() or not _pilgrimage_mission_active() then
				return func(nav_world, start_position, end_position, traverse_logic,
					check_above, check_below)
			end

			local caller = _betterbots_caller()
			if not caller then
				return func(nav_world, start_position, end_position, traverse_logic,
					check_above, check_below)
			end

			_stats.bypassed = _stats.bypassed + 1
			_stats.by_caller[caller] = (_stats.by_caller[caller] or 0) + 1
			return _isolated_result(caller, start_position, end_position)
		end)

		_installed = true
	end)
end

function M.reset()
	_stats = _fresh_stats()
end

function M.status()
	return {
		installed = _installed,
		enabled = _enabled(),
		dependency_present = _betterbots_present(),
		mission_active = _pilgrimage_mission_active(),
		stats = _stats,
	}
end

function M.summary()
	local status = M.status()
	local stats = status.stats
	return string.format(
		"%s, hook=%s, dependency=%s, pilgrimage=%s, isolated=%d, hazard=%d, charge=%d",
		status.enabled and "ENABLED" or "DISABLED",
		status.installed and "installed" or "inactive",
		status.dependency_present and "present" or "absent",
		status.mission_active and "active" or "inactive",
		stats.bypassed,
		stats.by_caller.hazard_dodge or 0,
		stats.by_caller.charge_path or 0
	)
end

function M.init(deps)
	_mod = deps.mod
	_hooks = deps.hooks
	_settings = deps.settings
	_shared = deps.shared
	_run_state = deps.run_state
	_debug_log = deps.debug_log
	M.reset()

	local ok, err = pcall(_install_hook)
	if not ok and _debug_log then
		_debug_log("betterbots_bridge_install", 0,
			"Better Bots navigation bridge install failed: " .. tostring(err), 0, "warn")
	end
end

return M
