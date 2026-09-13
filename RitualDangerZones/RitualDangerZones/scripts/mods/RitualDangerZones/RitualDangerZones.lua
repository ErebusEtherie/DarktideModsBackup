local mod = get_mod("RitualDangerZones")

-- ##### Settings migration ###########################################################################
-- DMF persists settings per setting_id and only consults default_value on a FIRST-EVER load. Changing
-- a default therefore does nothing for anyone who already has the mod. v1.0.0 shipped orange/yellow
-- rings at alpha 60 and projection depth 1, which is exactly the look v1.1.0 exists to fix, so without
-- this migration the release fixes nothing for a single existing user.
--
-- Only values still sitting on the EXACT v1.0.0 defaults are rewritten. Anything else is left alone: a
-- non-matching value is the only evidence we have of a deliberate choice, because DMF writes defaults
-- to disk on first load, so "has a saved value" cannot distinguish "chose it" from "never touched it".
-- The cost of that tradeoff is a user who deliberately picked the exact old default gets moved anyway.
-- Judged worth it: the old default is the thing the rework exists to remove.
--
-- Runs once, guarded by a stored schema version. `settings_version` is deliberately NOT a declared
-- widget: mod:set writes any key without validating it against the options schema, and mod:get returns
-- nil for a key never written, which is precisely the "pre-migration" signal needed. Compared with >=
-- so a future v3 does not re-run this v1->v2 pass.
local SETTINGS_VERSION = 3

-- Verified against the shipped v1.0.0 tree (git show main:...), not from memory.
local V1_DEFAULTS = {
	ring_start_color_r = 90, ring_start_color_g = 55, ring_start_color_b = 15, ring_start_color_a = 60,
	ring_speedup_color_r = 90, ring_speedup_color_g = 90, ring_speedup_color_b = 15, ring_speedup_color_a = 60,
	ring_projection_depth = 1,
}

local V2_DEFAULTS = {
	ring_start_color_r = 90, ring_start_color_g = 0, ring_start_color_b = 90, ring_start_color_a = 4,
	ring_speedup_color_r = 90, ring_speedup_color_g = 0, ring_speedup_color_b = 90, ring_speedup_color_a = 4,
	ring_projection_depth = 0.1,
}

-- v2 -> v3. The site rings describe euclidean distance from the daemonhost, and the game does not
-- measure that: it compares main-path distance against two tripwires. The rings are kept as an
-- opt-in site locator but they no longer default on, because on by default means the mod ships a
-- picture of a rule that does not exist.
--
-- Same tradeoff as the v1 -> v2 pass: "still equals the old default" is the only evidence of an
-- untouched setting, so a user who deliberately turned a ring on gets it turned off. That is worse
-- for a toggle than for a colour, so the migration logs a line naming what changed and the release
-- notes call it out.
local V2_RING_TOGGLES = {
	ring_start_enabled = true,
	ring_speedup_enabled = true,
}
local V3_RING_TOGGLES = {
	ring_start_enabled = false,
	ring_speedup_enabled = false,
}

local function migrate_settings()
	local from = mod:get("settings_version") or 1
	if from >= SETTINGS_VERSION then
		return
	end

	if from < 2 then
		local changed = 0
		for id, v1_value in pairs(V1_DEFAULTS) do
			if mod:get(id) == v1_value then
				mod:set(id, V2_DEFAULTS[id])
				changed = changed + 1
			end
		end
		if changed > 0 then
			mod:info("RitualDangerZones: updated " .. changed ..
				" ring setting(s) that were still on the v1.0.0 defaults. Customised values were kept.")
		end
	end

	if from < 3 then
		local changed = 0
		for id, v2_value in pairs(V2_RING_TOGGLES) do
			if mod:get(id) == v2_value then
				mod:set(id, V3_RING_TOGGLES[id])
				changed = changed + 1
			end
		end
		if changed > 0 then
			mod:info("RitualDangerZones: the rings around the ritual are now off by default, because " ..
				"the game triggers rituals by main-path distance, not by distance to the daemonhost. " ..
				"The new tripwires on the path replace them. Re-enable the old rings in Mod Options " ..
				"if you want them back.")
		end
	end

	mod:set("settings_version", SETTINGS_VERSION)
end

migrate_settings()

-- Shared module registry so sub-modules can reach each other via mod:persistent_table.
local modules = mod:persistent_table("RitualDangerZones_modules")

local BASE = "RitualDangerZones/scripts/mods/RitualDangerZones/"
-- Detection must load first: ring_renderer + marker read modules.Detection at their own load time.
modules.Detection  = modules.Detection or mod:io_dofile(BASE .. "detection")
local Detection    = modules.Detection
local PathModel    = mod:io_dofile(BASE .. "path_model")
local RingRenderer = mod:io_dofile(BASE .. "ring_renderer")
local Timer        = mod:io_dofile(BASE .. "timer")
local Marker       = mod:io_dofile(BASE .. "marker")
local Warning      = mod:io_dofile(BASE .. "warning")

-- We are "in gameplay" once the extension systems exist (mission running), not on the Mourningstar hub.
local function in_gameplay()
	if not (Managers.state and Managers.state.extension) then
		return false
	end
	local game_mode = Managers.state.game_mode
	if game_mode and game_mode.game_mode_name then
		local ok, name = pcall(game_mode.game_mode_name, game_mode)
		if ok and name == "hub" then
			return false
		end
	end
	return true
end

local function teardown_all()
	RingRenderer.teardown_all()
	Marker.teardown_all()
	Warning.teardown_all()
	Timer.teardown_all()
end

-- Per-frame driver (DMF entry point). Throttled: the daemonhost moves slowly and the rings are
-- link_unit'd to it, so they follow at full framerate regardless of our refresh cadence. Running
-- the scan + re-style every frame was the mod's dominant CPU cost (measured 2.24 ms/frame active).
local REFRESH_INTERVAL = 0.2
local since_refresh = REFRESH_INTERVAL -- refresh on the first eligible frame

mod.update = function(dt)
	if not mod:is_enabled() or not in_gameplay() then
		teardown_all()
		-- Deliberately NOT inside teardown_all: that also runs whenever no ritual is active, which is
		-- most ticks, and wiping player progress there would defeat the point of holding it.
		PathModel.teardown()
		since_refresh = REFRESH_INTERVAL
		return
	end

	since_refresh = since_refresh + (dt or 0)
	if since_refresh < REFRESH_INTERVAL then
		return
	end
	since_refresh = 0.0

	-- Sample player progress BEFORE the ritual check, so it keeps accruing while no ritual exists.
	-- If this only ran alongside a live ritual, the first sample after one appeared could land while
	-- somebody is inside a locked objective room and credit exactly the bad value it exists to reject.
	PathModel.track()

	-- Gate on the live daemonhost units (breed scan), NOT is_ritual_active(): the ritual mutator
	-- (mutator_spawner) is server-only, so its presence is not visible to a joining client. The
	-- daemonhost units ARE replicated to every client, so find_ritual_units() works for joiners,
	-- which is the whole reliability premise.
	local units = Detection.find_ritual_units()
	if #units == 0 then
		teardown_all()
		return
	end
	RingRenderer.sync(units, PathModel)
	-- Marker.sync and Warning.sync both read Timer.update(unit); it is idempotent per tick (see
	-- timer.lua), so the two callers share one sample rather than double-sampling.
	Marker.sync(units, Timer)
	Warning.sync(units, Timer, PathModel)
end

-- Boss-encounter lifecycle bounds each ritual's active window per unit
-- (ported hooks from RitualZones.lua:8153 / 8192). Breed-filtered to chaos_mutator_daemonhost.
mod:hook_safe(CLASS.HudElementBossHealth, "event_boss_encounter_start", function(_self, unit, _boss_extension)
	if not unit or not Unit.alive(unit) or not ScriptUnit.has_extension(unit, "unit_data_system") then
		return
	end
	local breed = ScriptUnit.extension(unit, "unit_data_system"):breed()
	if not breed or breed.name ~= "chaos_mutator_daemonhost" then
		return
	end
	Timer.on_encounter_start(unit)
end)

mod:hook_safe(CLASS.HudElementBossHealth, "event_boss_encounter_end", function(_self, unit, _boss_extension)
	Timer.on_encounter_end(unit)
	RingRenderer.teardown(unit)
	Marker.teardown(unit)
	Warning.teardown(unit)
end)

-- Tear down cleanly when settings change or the mod is toggled off.
mod.on_setting_changed = function()
	if not mod:is_enabled() then
		teardown_all()
	end
end

mod.on_unload = function()
	teardown_all()
end

mod.on_disabled = function()
	teardown_all()
end

-- Diagnostic dump. This project has no Lua test harness, so this command is how the path numbers
-- get checked against reality: run it in a mission standing at a known spot and confirm the wire
-- distances bracket the ritual and that ahead_distance tracks the furthest teammate.
-- Registration is pcall'd so an API drift in mod:command cannot abort the rest of this file.
pcall(function()
	-- Report through both channels. Both reach the console log (echo as [ECHO], info as [INFO]) in
	-- %APPDATA%/Fatshark/Darktide/console_logs, so a run can be read after the fact rather than
	-- transcribed from chat. echo puts it on screen for the player at the same time.
	local function report(line)
		mod:echo(line)
		mod:info(line)
	end

	mod:command("rdz_path", "RitualDangerZones: dump main-path tripwire diagnostics", function()
		report("RDZ path available: " .. tostring(PathModel.available()) ..
			"  safe_zone: " .. tostring(PathModel.in_safe_zone()) ..
			"  (safe_zone true = the game will not tick any ritual yet)")
		local ahead = PathModel.ahead_distance()
		local local_distance = PathModel.local_distance()
		local local_offset = PathModel.local_offset()
		report("RDZ ahead distance: " .. tostring(ahead))
		local units = Detection.find_ritual_units()
		report("RDZ ritual units: " .. tostring(#units))
		for i = 1, #units do
			local unit = units[i]
			local position = Detection.get_unit_position(unit)
			local monster_distance = position and PathModel.travel_distance(position)
			local wires = PathModel.wires(unit)
			if wires and monster_distance and ahead then
				local tw = RingRenderer.tripwire_state(unit)
				report(string.format(
					"RDZ ritual %d: D=%.1f far_wire=%.1f close_wire=%.1f ahead=%.1f -> %s",
					i, monster_distance, wires.far, wires.close, ahead,
					(ahead > wires.close and "SPEEDING") or (ahead > wires.far and "TICKING") or "not tripped"))
				-- "drawn" means a live decal exists, so a wire you cannot see on the floor is a
				-- rendering problem: raise Tripwire projection depth in Mod Options. "latched" means
				-- it was crossed and is deliberately gone. "missing" means the spawn failed.
				report(string.format("RDZ ritual %d: tripwire far=%s close=%s",
					i, tw.far, tw.close))
				-- Why the banner says what it says, and whether the local player's own projection has
				-- run ahead of where they actually walked. If my_proj is up near D while you are still
				-- behind both wires on foot, nearest-point projection is the problem, not the stages.
				local w = Warning.debug(unit, PathModel, Timer)
				report(string.format("RDZ ritual %d: banner=%s from=%s (geometry=%s progressed=%s) my_proj=%s",
					i, w.shown, w.source, w.geometric, tostring(w.progressed),
					local_distance and string.format("%.1f", local_distance) or "nil"))
				-- off = how far you are from your own path projection. Large means you are off the
				-- route (a side room), so that projection is not progress and track() ignores it.
				report(string.format("RDZ ritual %d: my_off=%s (ignored above 20)",
					i, local_offset and string.format("%.1f", local_offset) or "nil"))
			else
				report(string.format("RDZ ritual %d: no path data (D=%s wires=%s)",
					i, tostring(monster_distance), tostring(wires ~= nil)))
			end
		end
	end)
end)

mod:info("RitualDangerZones loaded.")
