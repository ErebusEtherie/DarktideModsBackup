local mod = get_mod("RespawnRewind")

local BASE = "RespawnRewind/scripts/mods/RespawnRewind/"
local Beacons = mod:io_dofile(BASE .. "beacons")
local Markers = mod:io_dofile(BASE .. "markers")

local TICK_INTERVAL = 0.3
local cooldown = 0.0
local episode_active = false
local awaiting_last = {}
local last_predicted = nil

-- In gameplay once the extension systems exist and we are not on the Mourningstar hub.
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

-- What the game itself says a player is doing, read off the replicated character_state component.
-- PlayerUnitStatus.is_dead is literally state_name == "dead", and respawn_beacon_system reads the same
-- component for its hogtied check, so this is the game's own vocabulary rather than an inference.
--
-- Returns nil when it cannot be read, which the caller treats as "no opinion" and falls back.
local function player_state_name(player)
	local unit = player and player.player_unit
	if not (unit and Unit.alive(unit)) then
		return nil
	end
	if not ScriptUnit.has_extension(unit, "unit_data_system") then
		return nil
	end
	local ok_ext, extension = pcall(ScriptUnit.extension, unit, "unit_data_system")
	if not ok_ext or not extension or not extension.read_component then
		return nil
	end
	local ok_comp, component = pcall(extension.read_component, extension, "character_state")
	if not ok_comp or not component then
		return nil
	end
	local ok_name, name = pcall(function()
		return component.state_name
	end)
	if ok_name and type(name) == "string" then
		return name
	end
	return nil
end

-- A player is awaiting respawn when the game says their state is "dead", or, failing that, when they
-- exist with no live unit.
--
-- The unit test alone is late: a dump taken while the local player was genuinely dead still showed
-- unit=alive, so the unit lingers for a moment after death and the markers only appear once it goes.
-- Reading the state catches it immediately, and it is what the game keys its own respawn handling on.
--
-- Knocked-down and hogtied players are NOT awaiting respawn under either test. They keep a live unit,
-- and their state names are "knocked_down" and "hogtied", neither of which is "dead". They are waiting
-- for a rescue, which involves no beacon.
-- Players who have had a live unit at some point this mission.
--
-- "Has no unit" is not the same as "is waiting to respawn". When somebody leaves and a bot backfills
-- their slot, the replacement player object can exist before its unit spawns, and the mod read that as
-- a teammate awaiting respawn and put the markers up. Reported on Nexus.
--
-- A respawn is by definition a RE-spawn, so requiring that we have seen the player alive separates the
-- two cases: a backfill bot that has never spawned is ignored until it does, while a genuine death
-- still counts because that player was obviously alive beforehand.
local seen_alive = {}

local function player_awaiting_respawn(player)
	if not player then
		return false
	end
	if not seen_alive[player] then
		return false
	end
	local state = player_state_name(player)
	if state then
		return state == "dead"
	end
	local ok, alive = pcall(function()
		return player:unit_is_alive()
	end)
	if ok then
		return not alive
	end
	local unit = player.player_unit
	return not (unit and Unit.alive(unit))
end

-- The game's own answer to "is anyone actually waiting to spawn". This is the exact condition the
-- respawn beacon system gates on (fixed_update: should_be_active = not block_spawning and
-- has_players_waiting_to_spawn()), so when it is readable it is strictly better than inferring the
-- state from missing player units.
--
-- Returns true, false, or nil for unreadable. nil means "no opinion" and the caller falls back.
local function game_says_waiting_to_spawn()
	local spawn_manager = Managers.state and Managers.state.player_unit_spawn
	if not spawn_manager or not spawn_manager.has_players_waiting_to_spawn then
		return nil
	end
	local ok, waiting = pcall(spawn_manager.has_players_waiting_to_spawn, spawn_manager)
	if not ok then
		return nil
	end
	return waiting and true or false
end

-- Show only during a real mid-mission respawn wait.
--
-- The unit-based test below is an INFERENCE: it reads "player object with no live unit" as "awaiting
-- respawn". That is not the same thing. A player who leaves the mission also stops having a unit, and
-- reported behaviour is that the markers then stayed up for the rest of the run, until the slot was
-- reclaimed by a new human. Bots cannot be excluded to fix it either, since a dead bot is a real
-- respawn the mod exists to mark.
--
-- So the game's own signal is asked first and the inference is only a fallback for when it cannot be
-- read. The "at least one player still up" half is kept in both paths: it rejects the pre-spawn window
-- and a full wipe, where no-live-unit would otherwise read as awaiting-respawn for everyone.
local function should_show()
	local players = Managers.player and Managers.player:players()
	if not players then
		return false
	end

	local awaiting, alive = false, false
	for _, player in pairs(players) do
		if player_awaiting_respawn(player) then
			awaiting = true
		else
			alive = true
		end
	end
	if not alive then
		return false
	end

	-- Precedence is deliberately lopsided while the signal is unproven. It has been confirmed READABLE
	-- on a live client, but only ever observed returning false with nobody dead, so it is not yet known
	-- to flip true on a client when someone is actually awaiting respawn.
	--
	-- The two failure modes are not equally bad. Trusting a client-blind signal means the mod draws
	-- nothing, ever, which is exactly how 1.0.0 shipped broken and went unnoticed. Trusting the old
	-- inference means the leaver bug persists: markers up for a slot nobody occupies. A cosmetic bug
	-- beats a silent one, so either source saying yes wins until a run with a real death settles it.
	--
	-- rr_players prints both, so one dump taken while a teammate is dead resolves this: signal true
	-- means drop the inference, signal false with awaiting true means the signal is server-only and the
	-- leaver case needs a different discriminator.
	local waiting = game_says_waiting_to_spawn()
	if waiting then
		return true
	end
	return awaiting
end

local function teardown_all()
	Markers.teardown_all()
	Beacons.teardown()
	seen_alive = {}
end

mod.update = function(dt)
	if not mod:is_enabled() or not in_gameplay() then
		teardown_all()
		return
	end
	if cooldown > 0 then
		cooldown = cooldown - dt
		return
	end
	cooldown = TICK_INTERVAL

	-- Note anyone currently alive, so a player who has never spawned is not mistaken for one waiting to
	-- come back. Runs before every check that depends on it.
	local players_alive = Managers.player and Managers.player:players()
	if players_alive then
		for _, player in pairs(players_alive) do
			local unit = player.player_unit
			if unit and Unit.alive(unit) then
				seen_alive[player] = true
			end
		end
	end

	-- Sample player progress every tick, BEFORE the should_show gate. Markers only appear while someone
	-- is awaiting respawn, but the progress history behind them has to be continuous: if it only accrued
	-- while a marker was up, the first sample after a death could land while the team is inside a locked
	-- objective room and credit exactly the projection this rejects.
	Beacons.track()

	-- Watch for a player reappearing, and measure the model against what the game actually did.
	--
	-- Every respawn is a free calibration sample. Nothing here changes behaviour; it only writes a line
	-- to the log, so the margin can be derived from real respawns instead of eyeballed off a marker.
	local players_now = Managers.player and Managers.player:players()
	if players_now then
		for _, player in pairs(players_now) do
			local was_waiting = awaiting_last[player]
			local is_waiting = player_awaiting_respawn(player)
			if was_waiting and not is_waiting then
				local unit = player.player_unit
				if unit and Unit.alive(unit) then
					local ok, pos = pcall(Unit.world_position, unit, 1)
					if ok then
						local m = Beacons.measure_respawn(pos)
						if m then
							mod:info("RR respawn: actual=%s predicted=%s ahead=%s margin=%s implied_margin=%s off_beacon=%s",
								tostring(m.actual), tostring(m.predicted),
								m.ahead and string.format("%.1f", m.ahead) or "nil",
								tostring(m.margin),
								m.implied and string.format("%+.1f", m.implied) or "agreed",
								m.distance_to_beacon and string.format("%.1f", m.distance_to_beacon) or "nil")
						end
					end
				end
			end
			awaiting_last[player] = is_waiting
		end
	end

	-- The learn-the-map markers are placed once and stand on their own, so they run before the
	-- respawn-wait gate rather than inside it.
	Markers.sync_practice()

	if not should_show() then
		if episode_active then
			episode_active = false
			last_predicted = nil
			mod:info("RR episode end")
		end
		-- End of the respawn episode. The game drops its own latched beacon here, so drop ours or the
		-- next death would inherit the previous episode's answer.
		Beacons.end_episode()
		Markers.teardown_live()
		return
	end

	local model = Beacons.compute()
	if not model then
		Markers.teardown_live()
		return
	end

	-- Log the first tick of each respawn episode, and every tick the prediction moves after it.
	--
	-- The open question is WHEN the game commits the beacon. If it commits at the death, a retreat that
	-- finishes later cannot move the respawn and the hold-back marker is only actionable in a very short
	-- window. This records what we predicted at the moment of death and every change afterwards, so the
	-- prediction at commit time can be compared against where the player actually reappeared. Passive,
	-- so the case gets captured without anyone having to run a command mid-fight.
	local active_distance = model.active and model.active.distance
	if episode_active == false then
		episode_active = true
		mod:info("RR episode start: ahead=%s predicted_beacon_at=%s",
			tostring(Beacons.ahead_snapshot()), tostring(active_distance))
	elseif active_distance ~= last_predicted then
		mod:info("RR episode moved: ahead=%s predicted_beacon_at=%s",
			tostring(Beacons.ahead_snapshot()), tostring(active_distance))
	end
	last_predicted = active_distance

	Markers.sync(model)
end

mod.on_setting_changed = function()
	if not mod:is_enabled() then
		teardown_all()
		return
	end
	Markers.on_setting_changed()
end

mod.on_unload = function()
	teardown_all()
end

mod.on_disabled = function()
	teardown_all()
end

-- Diagnostic. The 1.0.0 bug was invisible: every main-path call returned nil on a client, the mod
-- drew nothing, and nothing was logged. It passed testing only because it was tested under SoloPlay,
-- where the local machine IS the server and the server-only calls happen to work.
--
-- Run this in a LIVE mission (queue a normal mission with SoloPlay off, bots fill the empty slots and
-- you are still a client on a dedicated server). It answers "is the client-safe path model resolving"
-- in one line, without waiting for anyone to die.
--
-- Registration is pcall'd so an API drift in mod:command cannot abort the rest of this file.
pcall(function()
	-- Report to BOTH the chat echo and the console log. mod:echo reaches the in-game chat only, so
	-- diagnostic output run in a live mission is unreadable afterwards; mod:info lands in
	-- %APPDATA%/Fatshark/Darktide/console_logs and can be read after the fact.
	local function report(line)
		mod:echo(line)
		mod:info(line)
	end

	-- Dump of everything should_show() looks at. Run this while the markers are wrongly up: it says
	-- whether the game's signal is readable at all, and which player entry the unit-based inference is
	-- tripping over (a leaver's slot looks identical to a dead teammate through that lens).
	mod:command("rr_players", "RespawnRewind: dump the player list and the spawn-wait signal", function()
		local spawn_manager = Managers.state and Managers.state.player_unit_spawn
		local signal = "unreachable"
		if spawn_manager and spawn_manager.has_players_waiting_to_spawn then
			local ok, waiting = pcall(spawn_manager.has_players_waiting_to_spawn, spawn_manager)
			signal = ok and tostring(waiting and true or false) or "call failed"
		end
		report("RR players: has_players_waiting_to_spawn=" .. signal ..
			"  (a value here means the mod is using it and ignoring the unit inference)")

		local players = Managers.player and Managers.player:players()
		if not players then
			report("RR players: no player list")
			return
		end
		local function safe(fn, default)
			local ok, value = pcall(fn)
			if ok and value ~= nil then
				return tostring(value)
			end
			return default
		end
		local index = 0
		for _, player in pairs(players) do
			index = index + 1
			local unit = player.player_unit
			report(string.format(
				"RR player %d: name=%s type=%s human=%s slot=%s unit=%s awaiting=%s",
				index,
				safe(function() return player:name() end, "?"),
				safe(function() return player:type() end, "?"),
				safe(function() return player:is_human_controlled() end, "?"),
				safe(function() return player:slot() end, "?"),
				(unit and Unit.alive(unit)) and "alive" or "none",
				tostring(player_awaiting_respawn(player))) ..
				"  state=" .. tostring(player_state_name(player)))
		end
	end)

	mod:command("rr_practice", "RespawnRewind: why the map-practice markers are or are not showing", function()
		local d = Beacons.practice_debug()
		report(string.format("RR practice: setting=%s want_safe_zone=%s", tostring(mod:get("practice_enabled")), tostring(d.want_safe_zone)))
		report(string.format("RR practice: module=%s path_registered=%s position_from_distance=%s",
			tostring(d.module), tostring(d.path_registered), tostring(d.has_position_from_distance)))
		report(string.format("RR practice: beacons=%d matching_safe_zone=%d points=%d with_line=%d",
			d.total_beacons, d.matching, d.points, d.lines))
		local slots, placed, with_id = Markers.practice_state()
		report(string.format("RR practice: slots=%d markers_created=%d markers_with_id=%d", slots, placed, with_id))
		if d.points == 0 and d.total_beacons > 0 and d.matching == 0 then
			report("RR practice: every beacon is the other safe-zone class, so nothing matched.")
		end
	end)

	-- Every beacon, its projected path distance, and how far it sits from that projection. A hold-back
	-- line lands at (beacon distance - 25), so a beacon whose offset is large has an untrustworthy
	-- distance and will put its line in the wrong place.
	mod:command("rr_layout", "RespawnRewind: dump every beacon with its distance and projection offset", function()
		local cap = Beacons.snap_capability()
		report(string.format("RR layout: nav_queries=%s position_on_mesh_with_outside_position=%s nav_world=%s",
			tostring(cap.module), tostring(cap.has_function), tostring(cap.nav_world)))
		if not (cap.module and cap.has_function and cap.nav_world) then
			report("RR layout: the nav-mesh snap CANNOT run here, so every snap value below is a fallback, not a result.")
		end
		local beacons, ahead = Beacons.layout()
		report(string.format("RR layout: beacons=%d ahead=%s", #beacons,
			ahead and string.format("%.1f", ahead) or "nil"))
		for i = 1, #beacons do
			local b = beacons[i]
			-- snap is how far the nav-mesh snap moved this beacon's distance. The game measures from the
			-- snapped position, so a non-zero value here is error the mod used to carry.
			report(string.format("RR beacon %d: distance=%.1f line_at=%.1f offset=%s snap=%s safe_zone=%s",
				i, b.distance, b.distance - 25,
				b.offset and string.format("%.1f", b.offset) or "nil",
				b.snap_delta and string.format("%+.1f", b.snap_delta) or "nil",
				tostring(b.safe_zone)))
		end
	end)

	-- Where the mod's CPU time goes. Reported on the Nexus page as substantial even with nobody down,
	-- which fits: track() runs every refresh regardless, and each projection sweeps the whole main path.
	--
	-- os.clock resolves to 1ms, so each phase runs many times and the total is divided.
	mod:command("rr_perf", "RespawnRewind: time the per-refresh work", function()
		-- rawget on _G is the only way to ask whether the sandbox exposed a clock at all; indexing it
		-- directly errors when it is absent, which is the case this has to survive.
		-- selene: allow(global_usage)
		local mods_global = rawget(_G, "Mods")
		-- selene: allow(global_usage)
		local os_lib = (mods_global and mods_global.lua and mods_global.lua.os) or rawget(_G, "os")
		local clock = os_lib and os_lib.clock
		if type(clock) ~= "function" then
			report("RR perf: os.clock unavailable")
			return
		end
		local N = 200
		local function bench(label, fn)
			pcall(fn)
			local t0 = clock()
			for _ = 1, N do
				pcall(fn)
			end
			local ms = (clock() - t0) * 1000 / N
			report(string.format("RR perf  %-26s %8.4f ms/call", label, ms))
			return ms
		end

		local players = Managers.player and Managers.player:players()
		local living = 0
		if players then
			for _, player in pairs(players) do
				local unit = player.player_unit
				if unit and Unit.alive(unit) then
					living = living + 1
				end
			end
		end
		report(string.format("RR perf  living players: %d (track projects each one every refresh)", living))

		local one = bench("one projection", Beacons.time_one_projection)
		bench("one projection, 10 nodes", function()
			Beacons.time_one_windowed_projection(10)
		end)
		local track = bench("Beacons.track", Beacons.track)
		bench("should_show", should_show)
		bench("Beacons.compute", Beacons.compute)
		report(string.format("RR perf  one projection x %d living = %.4f ms, track measures %.4f ms",
			living, one * living, track))
	end)

	mod:command("rr_beacons", "RespawnRewind: dump respawn beacon diagnostics", function()
		local d = Beacons.diagnose()
		report(string.format(
			"RR: module=%s path_registered=%s beacons=%d ahead=%s active_at=%s runback=%s",
			tostring(d.module_loaded), tostring(d.path_registered), d.beacon_count,
			d.ahead and string.format("%.1f", d.ahead) or "nil",
			d.active_distance and string.format("%.1f", d.active_distance) or "nil",
			tostring(d.has_runback)))
		-- path_type decides WHICH rule is in play: "linear" is the ahead + 25 main-path rule, anything
		-- else is the euclidean midpoint rule and produces no hold-back marker. safe_zone is the class
		-- the game is selecting from. latched means the beacon is being held for this episode rather
		-- than recomputed, which is what the game does.
		report(string.format("RR: path_type=%s safe_zone=%s latched=%s latch_in_force=%s",
			tostring(d.path_type), tostring(d.safe_zone), tostring(d.latched), tostring(d.latch_in_force)))
		-- Who is holding the ahead-distance. If this is not you, running back yourself will not move the
		-- respawn, and that is the game's rule rather than a mod bug.
		-- Your own projection against what the mod actually credits you. A credited value stuck above
		-- live_distance means your progress is frozen because you are off the route, which makes running
		-- back do nothing.
		local lp = Beacons.local_progress()
		if lp then
			report(string.format("RR: you live=%s credited=%s off=%s (progress freezes above %d)",
				lp.live_distance and string.format("%.1f", lp.live_distance) or "nil",
				lp.credited and string.format("%.1f", lp.credited) or "nil",
				lp.offset and string.format("%.1f", lp.offset) or "nil",
				lp.max_offset))
		end
		local owner, is_local = Beacons.ahead_owner()
		report(string.format("RR: ahead set by %s%s", tostring(owner),
			is_local and " (you)" or " (NOT you: retreating alone will not move the respawn)"))
		if not d.path_registered then
			report("RR: main path not registered. Markers cannot compute.")
		elseif d.beacon_count == 0 then
			report("RR: no beacons resolved. This is the 1.0.0 client failure signature.")
		elseif not d.ahead then
			report("RR: no ahead distance. No living player unit projected onto the path.")
		else
			report("RR: path model is resolving on this client.")
		end
	end)
end)

mod:info("RespawnRewind loaded.")
