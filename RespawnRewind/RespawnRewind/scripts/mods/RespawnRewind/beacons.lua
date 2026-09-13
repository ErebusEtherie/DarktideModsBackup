local mod = get_mod("RespawnRewind")

local Beacons = {}

-- Pinned from respawn_beacon_system.lua (@ Aussiemon master): the active respawn beacon is the nearest
-- beacon whose main-path distance exceeds the furthest-ahead player's distance + this constant.
local BEACON_AHEAD_DISTANCE = 25

-- All main-path math goes through MainPathQueries, which calls EngineOptimized directly. Do NOT use
-- the MainPathManager methods (ahead_unit, travel_distance_from_position): they depend on
-- _nav_spawn_points, which only generate_spawn_points builds, and that opens with
-- "if not self._is_server then return end". Darktide missions run on dedicated servers, so a live
-- mission is never is_server: the manager route silently returns nil on every client and only ever
-- worked under SoloPlay. EngineOptimized.register_main_path runs on clients with no server gate.
local MainPathQueries = nil
local function main_path_queries()
	if MainPathQueries == nil then
		local ok, m = pcall(require, "scripts/utilities/main_path_queries")
		MainPathQueries = ok and m or false
	end
	return MainPathQueries or nil
end

-- Static beacon world positions do not move; cache distance per beacon unit for the mission.
local distance_cache = {}

local function is_finite_number(n)
	-- The type check is load-bearing: without it nil passes (nil == nil and nil ~= math.huge).
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function is_finite_vector(v)
	if not v or not Vector3 or not Vector3.x then
		return false
	end
	local ok, x = pcall(Vector3.x, v)
	if not ok then
		return false
	end
	return is_finite_number(x) and is_finite_number(Vector3.y(v)) and is_finite_number(Vector3.z(v))
end

local function path_registered(mpq)
	if not mpq or not mpq.is_main_path_registered then
		return false
	end
	local ok, registered = pcall(mpq.is_main_path_registered)
	return (ok and registered) and true or false
end

-- Project a world position onto the main path, client-safe. Returns (travel_distance, offset), where
-- offset is how far the position actually sits from the point it snapped to.
-- MainPathQueries.closest_position returns (projected_position, travel_distance, ...).
local function project(mpq, pos)
	local ok, projected, dist = pcall(mpq.closest_position, pos)
	if not ok or not is_finite_number(dist) then
		return nil, nil
	end
	local offset = nil
	if projected then
		local ok_offset, d = pcall(Vector3.distance, pos, projected)
		if ok_offset and is_finite_number(d) then
			offset = d
		end
	end
	return dist, offset
end

-- ##### Player progress ##############################################################################
-- The game's beacon rule keys off ahead_unit, which tracks how far players have actually TRAVELLED.
-- That is server-only. Projection is the closest client-side stand-in, but it answers a different
-- question: "which bit of the route is nearest to you", not "how far have you got".
--
-- Those diverge exactly where a map locks you in a side room for an objective. The room sits off the
-- route, so a player inside it projects onto whatever path point is nearest, often well ahead of
-- where they have really reached, and the predicted beacon jumps forward before the game would move
-- it. Observed in play, on the same maps that make RitualDangerZones announce rituals early. Same
-- cause, two mods.
--
-- A projection is believed when EITHER test passes: it is near the route, or it is continuous with the
-- last value we credited. Otherwise the last trusted position is held, so it degrades to slightly stale
-- rather than confidently wrong.
--
-- Nearness alone was too strict. Measured on a real map: walking past the first respawn beacon put the
-- local player 22m from their own projection, just over the limit, so their progress froze at 91.4
-- while they walked on to 127.0. The mod fed that stale number into the beacon rule, predicted a nearer
-- respawn than the game chose, and told the player they were behind a line they had not reached.
--
-- Continuity covers that without weakening the original protection, because the objective-room failure
-- is a JUMP rather than a drift. Entering such a room moves the projection far past MAX_STEP in a single
-- sample and it is refused, and it stays refused, because the comparison is always against the last
-- CREDITED value. Comparing against the last SEEN value would absorb the jump and readmit the bad
-- number one tick later.
--
-- A respawn is a real teleport and fails continuity, but it lands the player on a beacon, which is on
-- the route, so the nearness test admits it.

-- Hardcoded correctness constants, not preferences. A player on the route is a few metres from the
-- centreline even hugging a wall; a locked side room is much further.
local ON_PATH_MAX_OFFSET = 20

-- progress[player] = last distance recorded while that player was demonstrably on the route. Keyed by
-- the player object, which survives the unit being replaced on respawn.
local progress = {}

-- Sample every living player. Call every tick, independent of whether markers are being drawn: the
-- history has to be continuous, or the first sample taken when someone dies could land while the team
-- is inside an objective room and credit the exact value this exists to reject.
-- The largest jump in projected distance that can still be one player walking, per tick.
--
-- The refresh is 0.3s, so real movement is a couple of metres. Entering a locked objective room moves
-- the projection tens or hundreds of metres in a single sample, because the room sits alongside a much
-- later part of the route. 10m separates those cleanly.
local MAX_STEP = 10

function Beacons.track()
	local mpq = main_path_queries()
	if not path_registered(mpq) then
		return
	end
	local players = Managers.player and Managers.player:players()
	if not players then
		return
	end
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) then
			local ok, pos = pcall(Unit.world_position, unit, 1)
			if ok and is_finite_vector(pos) then
				local dist, offset = project(mpq, pos)
				if dist then
					local credited = progress[player]
					-- A nil offset means no usable projected point came back. Credit it rather than
					-- freezing: falling back to the old behaviour beats going blind.
					local on_route = (not offset) or offset <= ON_PATH_MAX_OFFSET
					local continuous = credited and math.abs(dist - credited) <= MAX_STEP
					if on_route or continuous or not credited then
						progress[player] = dist
					end
				end
			end
		end
	end
end

-- Furthest-ahead living player's progress, the input the game's beacon rule uses.
--
-- Deliberately NOT monotonic: the whole hold-back mechanic depends on this falling again when the
-- team moves back, which is what pulls the respawn to an earlier beacon. Only living players count,
-- matching the game, so a dead player's last progress cannot pin the team to where they fell.
local function ahead_distance()
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

-- The nav world the respawn beacon system itself uses, for snapping beacon positions the way it does.
local function nav_world()
	local ext = Managers.state and Managers.state.extension
	local rbs = ext and ext:system("respawn_beacon_system")
	local ok, value = pcall(function()
		return rbs and rbs._nav_world
	end)
	return (ok and value) or nil
end

local NavQueries = nil
local function nav_queries()
	if NavQueries == nil then
		local ok, m = pcall(require, "scripts/utilities/nav_queries")
		NavQueries = ok and m or false
	end
	return NavQueries or nil
end

-- Snap a beacon's world position onto the nav mesh, exactly as _create_respawn_beacons does:
--
--   local target_navmesh_position = NavQueries.position_on_mesh_with_outside_position(nav_world, nil, position, 1, 1, 1)
--   local distance = main_path_manager:travel_distance_from_position(target_navmesh_position)
--
-- We cannot use travel_distance_from_position (server-only), but we CAN reproduce the snap, and that
-- is where the distances diverged. Beacons sit in side alcoves tens of metres off the route, so the
-- raw position and the on-mesh position project to different points along the path. Measured on one
-- map: our beacon 1 read 146.1 while the game clearly had it at 138.9 or less, which is the difference
-- between the mod saying "you are behind the line" and the game disagreeing.
--
-- Returns the snapped position, or the original when the snap is unavailable, so a client that cannot
-- reach the nav world is no worse off than before.
local function on_mesh(position)
	local nq = nav_queries()
	local world = nav_world()
	if not nq or not nq.position_on_mesh_with_outside_position or not world or not position then
		return position
	end
	local ok, snapped = pcall(nq.position_on_mesh_with_outside_position, world, nil, position, 1, 1, 1)
	if ok and snapped and is_finite_vector(snapped) then
		return snapped
	end
	return position
end

-- Static beacon positions do not move, so the projection is cached per unit for the mission.
--
-- Returns (distance, offset). The offset is how far the beacon actually sits from its own projection,
-- and it is the tell for an untrustworthy distance: the game computes beacon distances server-side
-- when it creates them, while we can only project their world positions, and a beacon parked off the
-- route projects onto whatever path point is nearest rather than where it really is.
local function beacon_distance(mpq, unit)
	local cached = distance_cache[unit]
	if cached then
		return cached.distance, cached.offset, cached.snap_delta
	end
	local ok, pos = pcall(Unit.world_position, unit, 1)
	if not ok or not is_finite_vector(pos) then
		return nil, nil
	end
	local snapped = on_mesh(pos)
	local dist, offset = project(mpq, snapped)
	if not dist then
		return nil, nil
	end
	local raw_dist = project(mpq, pos)
	distance_cache[unit] = {
		distance = dist,
		offset = offset,
		snap_delta = (raw_dist and dist) and (dist - raw_dist) or nil,
	}
	return dist, offset
end

-- Every spawn beacon as { unit, position, distance, safe_zone }, ascending by main-path distance.
-- Enumerated from the respawn_beacon_system unit map, which ExtensionSystemBase populates via
-- on_add_extension on every client. The system's own derived tables (_beacon_main_path_data,
-- _beacon_main_path_distance_lookup, _sorted_beacons) are built inside _create_respawn_beacons, which
-- runs behind an is_server gate, so they are empty here and enumerating them would find nothing.
--
-- Safe-zone beacons are NOT filtered out. The game does not exclude them, it matches them: see
-- safe_zone_spawn().
local function list_beacons(mpq)
	local ext = Managers.state and Managers.state.extension
	local rbs = ext and ext:system("respawn_beacon_system")
	local unit_map = rbs and rbs._unit_to_extension_map
	if not unit_map then
		return {}
	end
	local out = {}
	for unit, extension in pairs(unit_map) do
		if Unit.alive(unit) then
			local safe_zone = false
			local ok_sz, sz = pcall(function()
				return extension:safe_zone()
			end)
			if ok_sz then
				safe_zone = sz and true or false
			end
			local dist, offset, snap_delta = beacon_distance(mpq, unit)
			local ok_pos, pos = pcall(Unit.world_position, unit, 1)
			if dist and ok_pos and is_finite_vector(pos) then
				out[#out + 1] = { unit = unit, position = pos, distance = dist, offset = offset, snap_delta = snap_delta, safe_zone = safe_zone }
			end
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return out
end

-- Which safe_zone class the game is currently selecting from. set_use_safe_zone flips this for the
-- scripted safe-zone sections, and _find_nearest_beacon_with_mainpath compares each beacon's own flag
-- against it with ==, so it is a match, not an exclusion. The field is initialised to false in the
-- system's init on every client and its setter carries no is_server gate, so reading it is never worse
-- than the hardcoded false it replaces.
local function safe_zone_spawn()
	local ext = Managers.state and Managers.state.extension
	local rbs = ext and ext:system("respawn_beacon_system")
	local ok, value = pcall(function()
		return rbs and rbs._safe_zone_spawn
	end)
	return (ok and value) and true or false
end

-- "linear" or "open". MainPathManager.path_type is a plain getter over a field assigned in init with
-- no server gate, so unlike ahead_unit it IS readable on a client. It decides which of the game's two
-- selection rules applies, and the two share nothing: linear measures along the main path, open
-- measures straight-line from the middle of the living squad.
local function path_type()
	local main_path = Managers.state and Managers.state.main_path
	if not main_path or not main_path.path_type then
		return nil
	end
	local ok, value = pcall(main_path.path_type, main_path)
	return ok and value or nil
end

local function matching_beacons(beacons, want_safe_zone)
	local out = {}
	for i = 1, #beacons do
		if beacons[i].safe_zone == want_safe_zone then
			out[#out + 1] = beacons[i]
		end
	end
	return out
end

local function index_of(list, unit)
	for i = 1, #list do
		if list[i].unit == unit then
			return i
		end
	end
	return nil
end

-- How far our beacon distances are assumed to overshoot the game's, in metres.
--
-- We cannot reproduce the game's projection: it constrains the search to the path segment belonging to
-- the nav spawn-point group a position sits in, and nav_spawn_points() is server-only. Our fallback
-- searches the whole path and reliably lands FURTHER along. Measured 146.1 against a game value of at
-- most 138.9 on one map.
--
-- Applied to the selection and the hold-back line alike, so the two always agree: beacon i wins when
-- distance_i > ahead + 25 + margin, and its line sits at distance_i - 25 - margin, which is the same
-- condition written the other way round.
-- Defaults to 0, so out of the box the mod reports the threshold it actually computes and behaviour is
-- unchanged for everyone. The margin exists because our beacon distances cannot match the game's, and
-- the error has a known direction, but the right size for it has not been measured on enough maps to
-- impose on anyone. Raise it if the run-back marker sits past the point that works for you.
local function runback_margin()
	local value = mod:get("runback_margin")
	if type(value) ~= "number" then
		return 0
	end
	return value
end

-- Exposed for the marker layer. Every marker the margin moves is a POSITION marker, and those bake
-- their position at add time, so the only way to show a margin change is to place them again. The
-- marker layer needs the same number this file uses to know when that has happened.
function Beacons.runback_margin()
	return runback_margin()
end

-- Mirror _find_nearest_beacon_with_mainpath: the first beacon past ahead + 25, else the furthest one.
-- The game reaches that fallback by walking its sorted list backward and taking the first match, which
-- is the last entry, so #list is the same beacon.
local function select_index_with_mainpath(matching, ahead)
	local min_distance = ahead + BEACON_AHEAD_DISTANCE + runback_margin()
	for i = 1, #matching do
		if matching[i].distance > min_distance then
			return i
		end
	end
	return #matching > 0 and #matching or nil
end

-- Mirror _find_nearest_beacon_with_distance, the rule on every non-linear path: the beacon closest to
-- the midpoint of the living squad, straight-line. A beacon of the other safe_zone class is a backup,
-- used only when the wanted class has nothing.
--
-- Components are read out of each Vector3 immediately rather than kept: an unboxed Vector3 from the
-- engine is frame-temporary, so accumulating them across a loop is exactly the pattern that produces
-- "Vector3 expected, got userdata" later.
local function select_with_distance(beacons, want_safe_zone)
	local players = Managers.player and Managers.player:players()
	if not players then
		return nil
	end
	local sx, sy, sz, count = 0, 0, 0, 0
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) then
			local ok, pos = pcall(Unit.world_position, unit, 1)
			if ok and is_finite_vector(pos) then
				sx, sy, sz = sx + Vector3.x(pos), sy + Vector3.y(pos), sz + Vector3.z(pos)
				count = count + 1
			end
		end
	end
	if count == 0 then
		return nil
	end
	local mx, my, mz = sx / count, sy / count, sz / count

	local best, best_d2
	local backup, backup_d2
	for i = 1, #beacons do
		local b = beacons[i]
		local dx, dy, dz = Vector3.x(b.position) - mx, Vector3.y(b.position) - my, Vector3.z(b.position) - mz
		local d2 = dx * dx + dy * dy + dz * dz
		if b.safe_zone == want_safe_zone then
			if not best_d2 or d2 < best_d2 then
				best, best_d2 = b, d2
			end
		elseif not backup_d2 or d2 < backup_d2 then
			backup, backup_d2 = b, d2
		end
	end
	return best or backup
end

-- Local (or currently observed) player position, for distance labels.
function Beacons.player_position()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if unit and Unit.alive(unit) then
		local ok, pos = pcall(Unit.world_position, unit, 1)
		if ok and is_finite_vector(pos) then
			return pos
		end
	end
	return nil
end

-- Compute the respawn model with the game's own rule. active = nearest beacon with distance >
-- ahead + 25 (else the furthest). runback = the beacon just before active; the run-back path point is
-- (prev.distance - 25), the position the furthest player must stay behind to make prev active.
-- The beacon the game is holding, and the narrow condition under which it holds one.
--
-- fixed_update reads `self._priority_respawn_beacon or self._current_active_respawn_beacon` and only
-- calls _find_optimal_beacon when both are nil, which looks like a latch for the whole respawn. It is
-- not. A few lines later in the SAME tick, _update_hogtied_players does:
--
--   local num_hogtied_players = #hogtied_players
--   if num_hogtied_players == 0 then
--       self._current_active_respawn_beacon = nil
--
-- So the hold survives only while somebody is hogtied. In an ordinary death, nobody is, and the game
-- re-picks the beacon every tick from the live ahead-distance. That live re-pick IS the hold-back
-- mechanic: falling back really does pull the respawn to an earlier beacon.
--
-- 1.2.0 latched unconditionally and froze that, which is the opposite of what the mod is for. Hogtied
-- state is readable from the same replicated character_state component as "dead", so the condition can
-- be reproduced exactly rather than guessed at.
--
-- _priority_respawn_beacon stays unreachable: make_respawn_beacon_priority opens with
-- "if not self._is_server then return end", so a scripted section that forces a beacon is invisible
-- here and will be mispredicted. Nothing client-side can detect it.
local function anyone_hogtied()
	local players = Managers.player and Managers.player:players()
	if not players then
		return false
	end
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) and ScriptUnit.has_extension(unit, "unit_data_system") then
			local ok_ext, extension = pcall(ScriptUnit.extension, unit, "unit_data_system")
			if ok_ext and extension and extension.read_component then
				local ok_comp, component = pcall(extension.read_component, extension, "character_state")
				if ok_comp and component then
					local ok_name, name = pcall(function()
						return component.state_name
					end)
					if ok_name and name == "hogtied" then
						return true
					end
				end
			end
		end
	end
	return false
end

local latched_unit = nil

function Beacons.compute()
	local mpq = main_path_queries()
	if not path_registered(mpq) then
		return nil
	end
	local beacons = list_beacons(mpq)
	if #beacons == 0 then
		return nil
	end

	local want_safe_zone = safe_zone_spawn()
	local active, previous
	local team_ahead

	-- An unreadable path_type is treated as linear on purpose. Linear is the common case and the rule
	-- this mod shipped with; defaulting the other way would silently drop the hold-back marker on every
	-- map the moment that getter drifted, and a missing feature is harder to notice than a wrong one.
	local kind = path_type()
	if kind == nil or kind == "linear" then
		local matching = matching_beacons(beacons, want_safe_zone)
		if #matching == 0 then
			return nil -- the game logs "No respawn beacon found" and returns nil here too
		end
		-- No living player unit to project (whole squad down / pre-spawn) means the game's rule has no
		-- input, so the server bails too. Show nothing rather than guess from a zero baseline.
		team_ahead = ahead_distance()
		if not team_ahead then
			return nil
		end
		local hold = anyone_hogtied()
		local index = hold and latched_unit and Unit.alive(latched_unit) and index_of(matching, latched_unit)
		if not index then
			index = select_index_with_mainpath(matching, team_ahead)
			if not index then
				return nil
			end
		end
		active = matching[index]
		previous = matching[index - 1]
	else
		-- Non-linear path: the game switches to the euclidean rule, which has no notion of a point on
		-- the route to stand behind, so no hold-back marker is produced here.
		if anyone_hogtied() and latched_unit and Unit.alive(latched_unit) then
			local index = index_of(beacons, latched_unit)
			active = index and beacons[index]
		end
		active = active or select_with_distance(beacons, want_safe_zone)
	end

	if not active then
		return nil
	end
	latched_unit = active.unit

	local model = { active = { unit = active.unit, position = active.position, distance = active.distance } }

	if previous then
		model.runback_beacon_unit = previous.unit
		model.runback_beacon_position = previous.position
		-- Safety margin on the hold-back line.
		--
		-- Our beacon distances cannot match the game's. PathTypeLinear._information_from_position projects
		-- onto the segment belonging to the nav spawn-point GROUP the position sits in:
		--
		--   local group = SpawnPointQueries.group_from_position(nav_world, main_path:nav_spawn_points(), position)
		--   local start_index = self._group_to_main_path_index[group]
		--   return MainPathQueries.closest_position_between_nodes(position, start_index, start_index + 1)
		--
		-- nav_spawn_points() is server-only, so we fall back to an unconstrained closest_position, which
		-- finds the globally nearest point instead. For a beacon tucked in an alcove those differ, and ours
		-- comes out LARGER: measured 146.1 against a game value of at most 138.9 on one map, so the line
		-- landed 7m past the real threshold.
		--
		-- The error has a known direction, and the costs are lopsided. A line drawn a few metres early
		-- costs a couple of seconds of walking; a line drawn a few metres late costs the beacon entirely.
		-- So the margin only ever moves the line BACK.
		local want = previous.distance - BEACON_AHEAD_DISTANCE - runback_margin()
		-- The hold-back line in path terms, and how the team sits against it. Signed on purpose: the
		-- marker is a threshold, not a destination. Positive means the team is past it and has to fall
		-- back that far for the earlier beacon to win; negative is the room left before crossing it and
		-- losing that option. Measured from the team's furthest-ahead progress, because that is the
		-- number the game's rule uses, not the distance from your own feet to the marker.
		model.runback_line_distance = want
		if team_ahead then
			model.runback_offset = team_ahead - want
		end
		if mpq.position_from_distance and want > 0 then
			local ok, pos = pcall(mpq.position_from_distance, want)
			if ok and is_finite_vector(pos) then
				model.runback_position = pos
			end
		end
		-- Fallback: the earlier beacon's own world position if the path point is unavailable.
		if not model.runback_position then
			model.runback_position = previous.position
		end
	end

	return model
end

-- Drop the latched beacon at the end of a respawn episode, mirroring the game clearing
-- _current_active_respawn_beacon. Deliberately separate from teardown(): teardown also drops the
-- per-mission distance cache, which is expensive to rebuild and stays valid across episodes.
function Beacons.end_episode()
	latched_unit = nil
end

-- Every respawn point on the map and the line that governs it, for the "learn the map" option.
--
-- Beacon i qualifies while the team's progress is more than BEACON_AHEAD_DISTANCE behind it, and the
-- first qualifying beacon wins. So beacon_i.distance - 25 is the last point at which you still get
-- beacon i: cross it going forward and the respawn moves on to the next one.
--
-- Both points are returned because the line sits 25m SHORT of the beacon it governs, and a marker on
-- the line alone teaches the wrong place. Seeing the pair is what makes that offset legible.
--
-- The safety margin moves these lines back too, exactly as it moves the live hold-back marker. Without
-- that the practice set showed the raw computed threshold while the mod steered you to a different one,
-- which is the wrong way round: this set is where the margin is legible, because it is on screen while
-- you walk the map instead of only while somebody is dead.
--
-- Static for the whole mission at a given margin, so callers place a marker per entry once and place
-- them again when the margin moves.
-- Positions are rebuilt on every call and must not be cached by the caller either: an unboxed Vector3
-- from the engine is frame-temporary.
function Beacons.practice_points()
	local mpq = main_path_queries()
	if not path_registered(mpq) or not mpq.position_from_distance then
		return {}
	end
	local want_safe_zone = safe_zone_spawn()
	local beacons = list_beacons(mpq)
	local out = {}
	for i = 1, #beacons do
		local beacon = beacons[i]
		if beacon.safe_zone == want_safe_zone then
			local at = beacon.distance - BEACON_AHEAD_DISTANCE - runback_margin()
			local line_position = nil
			if at > 0 then
				local ok, position = pcall(mpq.position_from_distance, at)
				if ok and is_finite_vector(position) then
					line_position = position
				end
			end
			out[#out + 1] = {
				unit = beacon.unit,
				line_position = line_position,
				line_distance = at,
			}
		end
	end
	return out
end

-- One unconstrained projection of the local player, for timing. This is the call the whole mod is
-- built on: track() runs it once per living player per refresh, and it searches the entire main path.
function Beacons.time_one_projection()
	local mpq = main_path_queries()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if not mpq or not (unit and Unit.alive(unit)) then
		return false
	end
	local ok, pos = pcall(Unit.world_position, unit, 1)
	if not ok or not is_finite_vector(pos) then
		return false
	end
	project(mpq, pos)
	return true
end

-- The same projection constrained to a window of path nodes around the last known one.
--
-- closest_position accepts optional node bounds and returns the node index it landed on, so the search
-- can be limited to the stretch a player could plausibly have moved through. That is both far cheaper
-- than sweeping every node and closer to what the game itself does, since PathTypeLinear projects
-- between two specific nodes rather than globally.
function Beacons.time_one_windowed_projection(window)
	local mpq = main_path_queries()
	if not mpq or not mpq.closest_position_between_nodes then
		return false
	end
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if not (unit and Unit.alive(unit)) then
		return false
	end
	local ok, pos = pcall(Unit.world_position, unit, 1)
	if not ok or not is_finite_vector(pos) then
		return false
	end
	local ok_full, _, _, _, node = pcall(mpq.closest_position, pos)
	if not ok_full or type(node) ~= "number" then
		return false
	end
	local lo = math.max(1, node - window)
	local hi = node + window
	pcall(mpq.closest_position_between_nodes, pos, lo, hi)
	return true
end

-- Whether the nav-mesh snap can actually run, reported separately from its result.
--
-- on_mesh() falls back to the unsnapped position when anything is unreachable, which produces a delta
-- of exactly 0.0 and is indistinguishable from a snap that moved nothing. This says which it was.
function Beacons.snap_capability()
	local nq = nav_queries()
	local world = nav_world()
	return {
		module = nq ~= nil,
		has_function = (nq ~= nil) and (nq.position_on_mesh_with_outside_position ~= nil) or false,
		nav_world = world ~= nil,
	}
end

-- Compare where a player actually reappeared against what the model predicted, and derive what the
-- margin would have had to be for the two to agree.
--
-- We cannot read the game's beacon distances, so the margin cannot be calculated: it has to be
-- measured. Every respawn is a free measurement. The game picked some beacon; if it picked a LATER one
-- than we did, then the beacon we chose failed its test, and since our test is
--
--   our_distance > ahead + BEACON_AHEAD_DISTANCE + margin
--
-- the smallest margin that would also have rejected it is
--
--   our_distance - ahead - BEACON_AHEAD_DISTANCE
--
-- Take the largest such value across several respawns and that is the margin this map needs. If the
-- game picks an EARLIER beacon than we did, the margin is already too big and the value is negative.
--
-- position is where the player reappeared. The nearest beacon to it is the one the game used.
function Beacons.measure_respawn(position)
	local mpq = main_path_queries()
	if not mpq or not path_registered(mpq) or not position then
		return nil
	end
	local beacons = list_beacons(mpq)
	if #beacons == 0 then
		return nil
	end
	local want_safe_zone = safe_zone_spawn()
	local matching = matching_beacons(beacons, want_safe_zone)
	if #matching == 0 then
		return nil
	end

	local actual_index, best_d2
	for i = 1, #matching do
		local p = matching[i].position
		local dx = Vector3.x(p) - Vector3.x(position)
		local dy = Vector3.y(p) - Vector3.y(position)
		local dz = Vector3.z(p) - Vector3.z(position)
		local d2 = dx * dx + dy * dy + dz * dz
		if not best_d2 or d2 < best_d2 then
			actual_index, best_d2 = i, d2
		end
	end
	if not actual_index then
		return nil
	end

	local ahead = ahead_distance()
	local predicted_index = ahead and select_index_with_mainpath(matching, ahead) or nil

	local implied = nil
	if ahead and predicted_index and predicted_index < actual_index then
		-- Our pick was too early. This is how much margin would have rejected it too.
		implied = matching[predicted_index].distance - ahead - BEACON_AHEAD_DISTANCE
	elseif ahead and predicted_index and predicted_index > actual_index then
		-- We picked later than the game: the margin is already overshooting.
		implied = matching[actual_index].distance - ahead - BEACON_AHEAD_DISTANCE
	end

	return {
		actual = actual_index,
		predicted = predicted_index,
		ahead = ahead,
		margin = runback_margin(),
		implied = implied,
		distance_to_beacon = best_d2 and math.sqrt(best_d2) or nil,
	}
end

-- The current ahead-distance, rounded, for episode logging.
function Beacons.ahead_snapshot()
	local value = ahead_distance()
	if not value then
		return nil
	end
	return math.floor(value * 10 + 0.5) / 10
end

-- The local player's live projection against the progress actually credited to them.
--
-- track() only credits a projection when the player is within ON_PATH_MAX_OFFSET of the route, and
-- otherwise holds the last trusted value. That is the objective-room fix, but it cuts both ways: if
-- retreating takes you off the route, your credited progress freezes at the higher number and the
-- respawn rule keeps reading you as further forward than you are.
--
-- live_distance vs credited is the tell. If credited is stuck above live_distance while you fall back,
-- the hold is why running back did nothing.
function Beacons.local_progress()
	local mpq = main_path_queries()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	if not mpq or not player then
		return nil
	end
	local unit = player.player_unit
	if not (unit and Unit.alive(unit)) then
		return nil
	end
	local ok, pos = pcall(Unit.world_position, unit, 1)
	if not ok or not is_finite_vector(pos) then
		return nil
	end
	local live_distance, offset = project(mpq, pos)
	return {
		live_distance = live_distance,
		offset = offset,
		credited = progress[player],
		max_offset = ON_PATH_MAX_OFFSET,
	}
end

-- Every beacon with the numbers behind it, so a wrong hold-back line can be traced to a wrong beacon
-- distance rather than guessed at. A large offset means that beacon sits well off the route and its
-- projected distance should not be trusted.
function Beacons.layout()
	local mpq = main_path_queries()
	if not path_registered(mpq) then
		return {}, nil
	end
	return list_beacons(mpq), ahead_distance()
end

-- Why practice_points() returned what it did. Every stage it can fall out of, in order.
function Beacons.practice_debug()
	local mpq = main_path_queries()
	local out = {
		module = mpq ~= nil,
		path_registered = path_registered(mpq),
		has_position_from_distance = (mpq ~= nil) and (mpq.position_from_distance ~= nil) or false,
		total_beacons = 0,
		want_safe_zone = safe_zone_spawn(),
		matching = 0,
		points = 0,
		lines = 0,
	}
	if not out.path_registered then
		return out
	end
	local beacons = list_beacons(mpq)
	out.total_beacons = #beacons
	for i = 1, #beacons do
		if beacons[i].safe_zone == out.want_safe_zone then
			out.matching = out.matching + 1
		end
	end
	local list = Beacons.practice_points()
	out.points = #list
	for i = 1, #list do
		if list[i].line_position then
			out.lines = out.lines + 1
		end
	end
	return out
end

-- Who is setting the ahead-distance, and how far from the local player they are.
--
-- The rule reads the FURTHEST-AHEAD player, so retreating on your own does nothing while a teammate
-- sits further up the path. A knocked-down teammate still has a live unit and still counts, so a bot
-- that went down ahead of you pins the number in place and makes running back look broken.
function Beacons.ahead_owner()
	local players = Managers.player and Managers.player:players()
	if not players then
		return nil, nil
	end
	local best, best_player = nil, nil
	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit and Unit.alive(unit) then
			local value = progress[player]
			if value and (not best or best < value) then
				best, best_player = value, player
			end
		end
	end
	if not best_player then
		return nil, nil
	end
	local name = "?"
	local ok, value = pcall(function()
		return best_player:name()
	end)
	if ok and value then
		name = tostring(value)
	end
	local is_local = false
	local players_manager = Managers.player
	local local_player = players_manager and players_manager.local_player and players_manager:local_player(1)
	is_local = (local_player == best_player)
	return name, is_local
end

-- Diagnostic snapshot of every intermediate value compute() depends on.
--
-- This mod's failure mode is silence: in 1.0.0 every main-path call returned nil on a client and the
-- mod simply drew nothing, with no error in the log. "I saw no markers" cannot distinguish a broken
-- mod from a mission where nobody happened to die, so a dump of the intermediates is the only cheap
-- way to tell whether the client-safe path model is actually resolving. Reported by the rr_beacons
-- command; costs nothing when not called.
function Beacons.diagnose()
	local mpq = main_path_queries()
	local out = {
		module_loaded = mpq ~= nil,
		path_registered = path_registered(mpq),
		beacon_count = 0,
		ahead = nil,
		active_distance = nil,
		has_runback = false,
		path_type = path_type(),
		safe_zone = safe_zone_spawn(),
		latched = latched_unit ~= nil,
		latch_in_force = anyone_hogtied(),
	}
	if not out.path_registered then
		return out
	end
	local beacons = list_beacons(mpq)
	out.beacon_count = #beacons
	out.ahead = ahead_distance()
	local model = Beacons.compute()
	if model and model.active then
		out.active_distance = nil
		for i = 1, #beacons do
			if beacons[i].unit == model.active.unit then
				out.active_distance = beacons[i].distance
				break
			end
		end
		out.has_runback = model.runback_position ~= nil
	end
	return out
end

function Beacons.teardown()
	distance_cache = {}
	latched_unit = nil
	progress = {}
end

return Beacons
