local mod = get_mod("RitualDangerZones")
local modules = mod:persistent_table("RitualDangerZones_modules")
local Detection = modules.Detection

local PathModel = {}

-- Client-safe main-path access. MainPathQueries goes through EngineOptimized and
-- EngineOptimized.register_main_path runs on every client with no server gate.
--
-- Do NOT reach for Managers.state.main_path here. Its ahead_unit and
-- travel_distance_from_position depend on _nav_spawn_points, which only the server builds
-- (generate_spawn_points opens with "if not self._is_server then return end"). Darktide missions
-- run on dedicated servers, so those methods return nil on every client, silently. RespawnRewind
-- 1.0.0 shipped that mistake and did nothing in live missions for its whole first version.
local MainPathQueries = nil
local function queries()
	if MainPathQueries == nil then
		local ok, m = pcall(require, "scripts/utilities/main_path_queries")
		MainPathQueries = ok and m or false
	end
	return MainPathQueries or nil
end

-- Offsets are read from the same settings table the daemonhost behaviour tree reads
-- (far 30 = ritual starts ticking, close 15 = full speed). Detection already resolves this
-- module for the site rings; re-resolving here keeps path_model free of a load-order dependency.
local function daemonhost_offsets()
	local ok, actions = pcall(require, "scripts/settings/breed/breed_actions/chaos/chaos_mutator_daemonhost_actions")
	local passive = (ok and actions and actions.passive) or {}
	local far = passive.far_distance_offset
	local close = passive.close_distance_offset
	if type(far) ~= "number" or type(close) ~= "number" then
		return nil, nil
	end
	return far, close
end

local function is_finite_number(n)
	-- The type check is load-bearing: without it nil passes, since nil == nil and nil ~= math.huge.
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- The game's ritual check begins with a safe-zone test and returns BEFORE any distance math when it
-- passes, so a ritual cannot tick while the team is still in the spawn area. We were missing it
-- entirely, which is why a ritual 25m from the start read as SPEEDING UP before the run had begun.
--
-- The flag clears the moment the team aggros anything (pacing_manager sets it false on the first
-- aggroed minion), so this only suppresses the opening window, not real play.
--
-- Unreadable is treated as NOT in the safe zone, which is the pre-existing behaviour: if this manager
-- turns out to be server-only, the mod is no worse than before rather than permanently silent.
-- Reported by rdz_path as `safe` so client-readability can be confirmed from one run.
function PathModel.in_safe_zone()
	local pacing = Managers.state and Managers.state.pacing
	if not pacing or not pacing.get_in_safe_zone then
		return false
	end
	local ok, in_safe = pcall(pacing.get_in_safe_zone, pacing)
	return (ok and in_safe) and true or false
end

function PathModel.available()
	local q = queries()
	if not q or not q.is_main_path_registered then
		return false
	end
	local ok, registered = pcall(q.is_main_path_registered)
	return (ok and registered) and true or false
end

-- Project a world position onto the main path. Returns (travel_distance, offset), where offset is how
-- far the position actually sits from its own projection. closest_position returns
-- (projected_position, travel_distance, ...), so the distance is the SECOND return value and the
-- FIRST is the point it snapped to.
--
-- The offset is the whole point. A projection says "the nearest bit of the route is here", not "you
-- have got this far", and those diverge badly the further you are from the route.
function PathModel.project(position)
	local q = queries()
	if not q or not position then
		return nil, nil
	end
	local ok, projected, distance = pcall(q.closest_position, position)
	if not ok or not is_finite_number(distance) then
		return nil, nil
	end
	local offset = nil
	if projected then
		local ok_offset, d = pcall(Vector3.distance, position, projected)
		if ok_offset and is_finite_number(d) then
			offset = d
		end
	end
	return distance, offset
end

-- Main-path travel distance of a world position, with no on-path check.
--
-- Correct for STATIC world objects (a daemonhost, a respawn beacon): the game projects those the same
-- way, off-path or not, so matching it is the point. Do NOT use this for player progress; see
-- PathModel.track.
function PathModel.travel_distance(position)
	local distance = PathModel.project(position)
	return distance
end

-- World position at a given path distance. Freshly built every call on purpose: an unboxed
-- Vector3 from the engine is frame-temporary, so callers must never cache the result.
function PathModel.position_at(distance)
	local q = queries()
	if not q or not is_finite_number(distance) then
		return nil
	end
	local ok, position = pcall(q.position_from_distance, distance)
	if ok and position then
		return position
	end
	return nil
end

-- ##### Player progress ##############################################################################
-- The game reads team progress from the server's ahead_unit, which tracks how far players have
-- actually TRAVELLED. That is server-only. Projection is the closest client-side stand-in, but it
-- answers a different question: "which bit of the route is nearest to you", not "how far have you got".
--
-- Those two diverge exactly where a map locks you in a side room to do an objective. The room sits off
-- the route, so your projection snaps to whatever path point is nearest, often well ahead of where you
-- have actually reached. The game refuses to advance (you have not progressed); a naive projection
-- advances anyway. Observed in play on both this mod and RespawnRewind, on the same maps, from the
-- same cause: rituals announced before they trigger, and respawn beacons predicted a beacon early.
--
-- The fix: only believe a projection when the player is genuinely NEAR the path. Standing in a side
-- room puts you tens of metres from your own projection, and that offset is the tell. When it is too
-- large, hold the last position we could trust rather than believing a number we know is wrong.
--
-- Degrades safely: worst case the value is slightly stale, instead of confidently wrong.

-- Hardcoded, same policy as the refresh interval: a correctness constant, not a preference. A player
-- on the route is a few metres from the centreline even hugging a wall; a locked side room is much
-- further. Reported by rdz_path as `off` so it can be checked against a real map.
local ON_PATH_MAX_OFFSET = 20

-- progress[player] = last path distance recorded while that player was demonstrably on the route.
-- Keyed by the player object, which survives the unit being replaced on respawn.
local progress = {}

-- Sample every living player. Call this every eligible tick, INCLUDING when no ritual is active:
-- progress has to be continuous, or the first sample after a ritual appears could land while someone
-- is inside an objective room and credit exactly the bad value this exists to reject.
function PathModel.track()
	local players = Managers.player and Managers.player:players()
	if not players or not PathModel.available() then
		return
	end
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) then
			local position = Detection.get_unit_position(unit)
			if position then
				local distance, offset = PathModel.project(position)
				-- A nil offset means the projection came back without a usable point. Credit it rather
				-- than freezing: falling back to the old behaviour beats going blind.
				if distance and (not offset or offset <= ON_PATH_MAX_OFFSET) then
					progress[player] = distance
				end
			end
		end
	end
end

-- Furthest-ahead living player's path progress.
--
-- Deliberately NOT monotonic. The game's ahead_unit is the furthest-ahead player right now, not a
-- historical high-water mark, and RespawnRewind's whole hold-back mechanic depends on this number
-- falling again when the team moves back. RDZ does not need a floor here either: its stage latch
-- already prevents a warning downgrading.
--
-- Only living players count, matching the game. A dead player's last progress is ignored rather than
-- pinning the team's position to wherever they fell.
function PathModel.ahead_distance()
	local players = Managers.player and Managers.player:players()
	if not players then
		return nil
	end
	local best = nil
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) then
			local value = progress[player]
			if value and (not best or best < value) then
				best = value
			end
		end
	end
	return best
end

-- How far the local player currently is from their own projection, for diagnostics. A large value
-- means the projection is not trustworthy as progress, which is the whole premise of track().
function PathModel.local_offset()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if not (unit and Unit.alive(unit)) then
		return nil
	end
	local position = Detection.get_unit_position(unit)
	if not position then
		return nil
	end
	local _, offset = PathModel.project(position)
	return offset
end

-- Progress is per mission. Clear it when leaving gameplay, NOT from the mod's general teardown, which
-- also runs whenever no ritual is active: wiping it there would discard the history on most ticks and
-- defeat the hold-last-trusted behaviour.
function PathModel.teardown()
	progress = {}
end

-- The two tripwire path distances for one ritual unit.
--
-- The round trip through position_at is NOT redundant and must not be simplified to
-- (D - offset). point_on_mainpath clamps to the path bounds, so a wire that would land before
-- the level start collapses to roughly 0 instead of going negative. The game does exactly this
-- round trip, and matching it is what keeps our wires on the same points as the real check.
function PathModel.wires(unit)
	if not PathModel.available() then
		return nil
	end
	local position = Detection.get_unit_position(unit)
	if not position then
		return nil
	end
	local monster_distance = PathModel.travel_distance(position)
	if not monster_distance then
		return nil
	end
	local far_offset, close_offset = daemonhost_offsets()
	if not far_offset then
		return nil
	end

	local function wire_distance(offset)
		local wire_position = PathModel.position_at(monster_distance - offset)
		if not wire_position then
			return nil
		end
		return PathModel.travel_distance(wire_position)
	end

	local far = wire_distance(far_offset)
	local close = wire_distance(close_offset)
	if not far or not close then
		return nil
	end
	return { far = far, close = close }
end

-- The LOCAL player's own path projection, for diagnostics only.
--
-- ahead_distance() is a max over the whole team, so it cannot answer "did MY projection jump". That
-- distinction matters: nearest-point projection is not the same as distance travelled, and standing
-- next to an off-path daemonhost through a wall projects you onto the path beside IT, not where you
-- actually walked to. Comparing this against the wire distances is how that gets confirmed.
function PathModel.local_distance()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if not (unit and Unit.alive(unit)) then
		return nil
	end
	local position = Detection.get_unit_position(unit)
	return position and PathModel.travel_distance(position) or nil
end

modules.PathModel = PathModel
return PathModel
