local mod = get_mod("RitualDangerZones")
local modules = mod:persistent_table("RitualDangerZones_modules")
local Detection = modules.Detection

local RingRenderer = {}

local DECAL_PATH = "content/levels/training_grounds/fx/decal_aoe_indicator"
local PACKAGE_PATH = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"

-- decals_by_unit[unit] = { [ring_id] = decal_unit(userdata), ... }
local decals_by_unit = mod:persistent_table("rdz_decals")

local RING_ENABLE = { ritual_start = "ring_start_enabled", ritual_speedup = "ring_speedup_enabled" }
local RING_COLOR_BASE = { ritual_start = "ring_start_color", ritual_speedup = "ring_speedup_color" }
local RING_DEFAULT_ON = { ritual_start = false, ritual_speedup = false }
-- {r, g, b, a} in 0-100 (danger_zone convention).
--
-- Both rings are magenta on purpose. Darktide's palette is browns, greys and sickly green, so magenta
-- is one of the few hues that reads as "not part of the level". The earlier orange and yellow were
-- close enough to the floor and the ritual's own glow to disappear into them.
--
-- Same hue for both rings is also deliberate. They overlap inside 15m, and alpha composites, so the
-- inner zone lands at ~1-(1-0.04)^2 = 7.8%. The danger reads by DENSITY rather than by colour: closer
-- means deeper. Two different hues muddied that.
--
-- Alpha 4 is not a typo and is below danger_zone's 10. Alpha and area are coupled: danger_zone applies
-- 10 to small radii, these rings are 30m and 60m across. The shipped v1.0.0 default of 60, doubled to
-- ~84% in the overlap, is what made the rings read as spilled paint. Tested in-game, 2026-07-15.
local RING_DEFAULT_RGBA = {
	ritual_start   = { 90, 0, 90, 4 },
	ritual_speedup = { 90, 0, 90, 4 },
}

local function ring_enabled(ring_id)
	local v = mod:get(RING_ENABLE[ring_id])
	if v == nil then return RING_DEFAULT_ON[ring_id] end
	return v
end

-- Returns r, g, b, a each in 0..1 (settings are 0..100, matching danger_zone get_outline_rgba).
local function ring_rgba(ring_id)
	local base = RING_COLOR_BASE[ring_id]
	local d = RING_DEFAULT_RGBA[ring_id]
	local r = (mod:get(base .. "_r") or d[1]) / 100
	local g = (mod:get(base .. "_g") or d[2]) / 100
	local b = (mod:get(base .. "_b") or d[3]) / 100
	local a = (mod:get(base .. "_a") or d[4]) / 100
	return r, g, b, a
end

-- Projector Z-scale = how far the decal projects vertically, and it is the ONLY lever on wall smear.
-- The decal paints onto any surface inside its projector box, so a wall or stair crossing the ring
-- picks up the texture for the full depth. This is why shrinking the decals never helped: smear is a
-- function of depth, not of ring size or fill.
--
-- 0.1 means the ring projects 10cm vertically. Tested in-game 2026-07-15: it does not climb stairs and
-- does not bleed to the floor above, and the ring still renders on the daemonhost's own floor. Note
-- this is GLOBAL, not per-ring.
--
-- danger_zone and both native game call sites pass 1, which is a whole floor. That was 10x too deep
-- for these radii and is what put colour on every wall in range.
--
-- Guarded against 0: DMF does not clamp a slider to its declared range minimum, so the user can drive
-- this to 0 and a 0 Z-scale would collapse the projector.
local PROJECTION_DEPTH_DEFAULT = 0.1
local function projection_depth()
	local d = mod:get("ring_projection_depth")
	if type(d) == "number" and d > 0 then
		return d
	end
	return PROJECTION_DEPTH_DEFAULT
end

-- Mirror danger_zone.draw_circle: Quaternion(r,g,b,w=0) -> particle_color, alpha -> color_multiplier,
-- size -> local_scale(diameter, diameter, depth).
--
-- Styling is re-applied EVERY tick on purpose. Do not "optimize" this into a style-once-at-spawn path
-- keyed on a dirty flag: v1.1.0 did exactly that and shipped colourless rings. The material calls can
-- fail on the frame the decal spawns, the pcalls swallow it, and a latched dirty flag means nothing
-- ever retries. Re-applying is self-healing and is what the game itself does (training_grounds_steps
-- re-applies color_multiplier every frame while fading). The cost is a handful of material calls per
-- ritual host per tick.
--
-- Takes r,g,b,a in 0..1 directly rather than a ring id, because site rings and tripwires read their
-- colours from different setting keys.
-- depth is passed in rather than read here: the site rings and the tripwires need very different
-- values, because depth trades "reaches the floor on uneven ground" against "smears up nearby walls"
-- and that trade lands in opposite places at 30m radius versus 3m.
local function style_decal(decal, radius, r, g, b, a, depth)
	if not (decal and Unit.is_valid(decal)) then
		return
	end
	local colour = Quaternion.identity()
	Quaternion.set_xyzw(colour, r, g, b, 0)
	pcall(Unit.set_vector4_for_material, decal, "projector", "particle_color", colour, true)
	pcall(Unit.set_scalar_for_material, decal, "projector", "color_multiplier", a)
	local diameter = radius * 2
	pcall(Unit.set_local_scale, decal, 1, Vector3(diameter, diameter, depth))
end

-- Mirror danger_zone.get_decal spawn + link. The link keeps the ring on the host if it moves.
local function spawn_ring(world, unit, pos)
	local ok, decal = pcall(World.spawn_unit_ex, world, DECAL_PATH, nil, pos)
	if not ok or not decal then
		return nil
	end
	pcall(World.link_unit, world, decal, 1, unit, 1)
	return decal
end

-- Mirror danger_zone.destroy_decal, guarded: teardown can run while the world is being torn down.
local function destroy_ring(decal)
	if not (decal and Unit.is_valid(decal)) then
		return
	end
	local ok, world = pcall(Unit.world, decal)
	if ok and world then
		pcall(World.destroy_unit, world, decal)
	end
end

-- Run cb once the decal package is resident (danger_zone async load pattern, lines 50-55).
-- Guarded so we issue the async load ONCE, not every frame while it's pending.
local _package_requested = false
local function with_package(cb)
	local pm = Managers.package
	if not pm then return end
	if pm:has_loaded(PACKAGE_PATH) then
		cb()
		return
	end
	if not _package_requested then
		_package_requested = true
		pm:load(PACKAGE_PATH, "RitualDangerZones", function()
			cb()
		end)
	end
end

-- ##### Tripwires ####################################################################################
-- The rings above sit around the daemonhost and describe euclidean distance, which is NOT what the
-- game measures. The real check projects the daemonhost onto the main path and plants two wires at
-- (its path distance - 30) and (- 15); crossing them with the team's furthest-ahead player is what
-- starts the ritual ticking and then sends it to full speed. These decals mark those two points.
--
-- Tripwire decals are deliberately NOT linked to the daemonhost. A path point is a fixed spot on the
-- route, so linking it would drag the wire along with a teleporting host.

-- tripwires_by_unit[unit] = { far = <entry>, close = <entry> }, where <entry> is either
-- { decal = userdata, distance = number } or the boolean false, the "tripped, never redraw"
-- sentinel. Only teardown_tripwires clears a sentinel.
local tripwires_by_unit = mod:persistent_table("rdz_tripwires")

-- Hoisted so sync_tripwires does not allocate a fresh list per ritual unit per tick. This mod has
-- a history of Lua heap exhaustion, so allocations in the update path get removed.
local TRIPWIRE_IDS = { "far", "close" }

local TRIPWIRE_COLOR_BASE = { far = "tripwire_far_color", close = "tripwire_close_color" }
-- {r, g, b, a} in 0-100. Amber for "starts ticking", red for "full speed", matching the warning
-- stage colours. Unlike the site rings these do not overlap (they sit 15 path-metres apart) and they
-- are small, so distinct hues are safe and a visible alpha is required.
local TRIPWIRE_DEFAULT_RGBA = {
	far   = { 100, 65, 0, 25 },
	close = { 100, 10, 10, 35 },
}

-- Tripwires get their OWN projection depth, deliberately much deeper than the site rings' 0.1.
--
-- Depth is how far the decal projects vertically, and it is the only lever on both problems it
-- causes. 0.1 exists because the site rings are 30m and 15m in radius: at that size a shallow
-- projector still lands on plenty of floor, and anything deeper smeared colour up every wall in
-- range. Neither half of that reasoning transfers to a 3m ring. A 10cm projector box on a corridor
-- with grating, debris, a ramp or a single step can miss the walkable surface entirely and draw
-- nothing, and a ring this small cannot smear much even when it is deep.
--
-- Guarded against 0 for the same reason as the ring depth: DMF does not clamp a slider to its
-- declared range minimum, and a 0 Z-scale collapses the projector.
local TRIPWIRE_DEPTH_DEFAULT = 0.6
local function tripwire_depth()
	local d = mod:get("tripwire_projection_depth")
	if type(d) == "number" and d > 0 then
		return d
	end
	return TRIPWIRE_DEPTH_DEFAULT
end

local TRIPWIRE_RADIUS_DEFAULT = 3
local function tripwire_radius()
	local v = mod:get("tripwire_radius")
	-- DMF does not clamp a slider to its declared range minimum, so a user can drive this to 0.
	if type(v) == "number" and v > 0 then
		return v
	end
	return TRIPWIRE_RADIUS_DEFAULT
end

local function tripwires_enabled()
	local v = mod:get("tripwire_enabled")
	if v == nil then return true end
	return v
end

local function tripwire_rgba(wire_id)
	local base = TRIPWIRE_COLOR_BASE[wire_id]
	local d = TRIPWIRE_DEFAULT_RGBA[wire_id]
	local r = (mod:get(base .. "_r") or d[1]) / 100
	local g = (mod:get(base .. "_g") or d[2]) / 100
	local b = (mod:get(base .. "_b") or d[3]) / 100
	local a = (mod:get(base .. "_a") or d[4]) / 100
	return r, g, b, a
end

-- Spawn unlinked at a world position. Uses the daemonhost's world, which is the same world the
-- site rings spawn into.
local function spawn_tripwire(world, pos)
	local ok, decal = pcall(World.spawn_unit_ex, world, DECAL_PATH, nil, pos)
	if not ok or not decal then
		return nil
	end
	return decal
end

-- Move an existing tripwire decal. Returns false when the engine call is unavailable or fails, so
-- the caller can fall back to destroy-and-respawn rather than leaving a wire at a stale spot.
local function move_tripwire(decal, pos)
	if not (decal and Unit.is_valid(decal)) then
		return false
	end
	local ok = pcall(Unit.set_local_position, decal, 1, pos)
	return ok and true or false
end

-- Tolerates the boolean false sentinel: `entry and entry.decal` short-circuits on false, so nothing
-- is ever indexed on it.
local function destroy_tripwire_entry(entry)
	if entry and entry.decal then
		destroy_ring(entry.decal)
	end
end

-- Sync both wires for every live ritual.
--
-- A tripped wire is removed AND LATCHED OFF, by storing the boolean false in its slot. Both stages
-- latch in the game (nothing ever clears scratchpad.speed), so once the furthest-ahead player is
-- past a wire that wire can never matter again and redrawing it would tell the team "do not cross
-- this" about a ritual that is already running.
--
-- The sentinel is what makes that true, because `ahead` is a max over LIVING player units and drops
-- when the player who crossed the wire dies. Without the latch, `ahead` recomputes from teammates
-- further back and every wire they have not personally passed respawns in front of them, while the
-- warning banner correctly still shows the latched stage. With every player dead `ahead` is nil and
-- the whole map's wires would come back.
--
-- Note a wire can be latched off that you personally never reached, because a teammate ahead of you
-- tripped it. That is correct: it is already tripped, and walking over it yourself changes nothing.
local function sync_tripwires(ritual_units, path_model)
	if not tripwires_enabled() or not path_model or not path_model.available() then
		RingRenderer.teardown_all_tripwires()
		return
	end
	local ahead = path_model.ahead_distance()
	local radius = tripwire_radius()
	local live = {}

	for i = 1, #ritual_units do
		local unit = ritual_units[i]
		-- Liveness is membership in ritual_units, not a successful query this tick. A transient nil
		-- from wires() must not reach the teardown sweep below, or it would clear the latch and let
		-- tripped wires respawn.
		live[unit] = true
		local wires = path_model.wires(unit)
		local world = Unit.is_valid(unit) and Unit.world(unit)
		if wires and world then
			local entry_map = tripwires_by_unit[unit] or {}
			for j = 1, #TRIPWIRE_IDS do
				local wire_id = TRIPWIRE_IDS[j]
				local entry = entry_map[wire_id]
				-- entry == false means latched off by an earlier crossing. Skip the wire entirely:
				-- no query, no spawn, no styling, for the rest of the mission.
				if entry ~= false then
					local distance = wires[wire_id]
					local tripped = ahead and distance and ahead > distance
					if tripped or not distance then
						if entry then
							destroy_tripwire_entry(entry)
						end
						-- Latch only on a real crossing. A missing distance is a failed query, not a
						-- trip, so leave that slot nil and let it come back.
						--
						-- Written as an if/else, NOT as `tripped and false or nil`. That idiom is
						-- broken whenever the wanted value is itself false: `true and false` is
						-- false, and `false or nil` is then nil, so the sentinel would never be
						-- stored and every tripped wire would respawn on the next tick.
						if tripped then
							entry_map[wire_id] = false
						else
							entry_map[wire_id] = nil
						end
					else
						-- Rebuild the position every tick. An unboxed Vector3 is frame-temporary, so
						-- the scalar distance is what gets stored between ticks, never the position.
						local pos = path_model.position_at(distance)
						if pos then
							if entry and entry.decal and Unit.is_valid(entry.decal) then
								if entry.distance ~= distance and not move_tripwire(entry.decal, pos) then
									destroy_tripwire_entry(entry)
									entry = nil
								end
							else
								entry = nil
							end
							if not entry then
								local decal = spawn_tripwire(world, pos)
								entry = decal and { decal = decal } or nil
							end
							if entry then
								entry.distance = distance
								local r, g, b, a = tripwire_rgba(wire_id)
								style_decal(entry.decal, radius, r, g, b, a, tripwire_depth())
								entry_map[wire_id] = entry
							end
						end
					end
				end
			end
			tripwires_by_unit[unit] = entry_map
		end
	end

	for unit in pairs(tripwires_by_unit) do
		if not live[unit] then
			RingRenderer.teardown_tripwires(unit)
		end
	end
end

-- The only thing that clears a latched-off wire. Dropping the whole entry_map drops its false
-- sentinels with it. pairs() iterates false values without stopping (only a nil VALUE would end an
-- ipairs walk, and this is pairs over string keys), and destroy_tripwire_entry ignores them.
function RingRenderer.teardown_tripwires(unit)
	local entry_map = tripwires_by_unit[unit]
	if entry_map then
		for _, entry in pairs(entry_map) do
			destroy_tripwire_entry(entry)
		end
	end
	tripwires_by_unit[unit] = nil
end

-- Per-wire state for the rdz_path diagnostic. "Inconsistent tripwires" has several very different
-- causes that all look identical on screen (nothing drawn), so report which one is in play:
--   latched  = crossed already, deliberately never redrawn
--   drawn    = a live decal exists, so a missing ring on screen is a RENDERING problem (most likely
--              projection depth too shallow to reach the floor), not a logic problem
--   missing  = we wanted a wire here and no decal exists, so the spawn failed
function RingRenderer.tripwire_state(unit)
	local entry_map = tripwires_by_unit[unit]
	local out = {}
	for j = 1, #TRIPWIRE_IDS do
		local wire_id = TRIPWIRE_IDS[j]
		local entry = entry_map and entry_map[wire_id]
		if entry == false then
			out[wire_id] = "latched"
		elseif entry and entry.decal and Unit.is_valid(entry.decal) then
			out[wire_id] = "drawn"
		else
			out[wire_id] = "missing"
		end
	end
	return out
end

function RingRenderer.teardown_all_tripwires()
	for unit in pairs(tripwires_by_unit) do
		RingRenderer.teardown_tripwires(unit)
	end
end

function RingRenderer.sync(ritual_units, path_model)
	if #ritual_units == 0 then
		return
	end

	with_package(function()
		sync_tripwires(ritual_units, path_model)
		local defs = Detection.get_ring_defs()
		local alive = {}
		for i = 1, #ritual_units do
			local unit = ritual_units[i]
			alive[unit] = true
			-- Spawn into the UNIT's own world (danger_zone's approach), not a named world.
			local world = Unit.is_valid(unit) and Unit.world(unit)
			local pos = Detection.get_unit_position(unit) -- unboxed, finite
			if world and pos then
				local ring_map = decals_by_unit[unit] or {}
				for j = 1, #defs do
					local def = defs[j]
					if ring_enabled(def.id) then
						local decal = ring_map[def.id]
						if not (decal and Unit.is_valid(decal)) then
							decal = spawn_ring(world, unit, pos)
							ring_map[def.id] = decal
						end
						if decal then
							local r, g, b, a = ring_rgba(def.id)
							style_decal(decal, def.radius, r, g, b, a, projection_depth())
						end
					elseif ring_map[def.id] then
						destroy_ring(ring_map[def.id])
						ring_map[def.id] = nil
					end
				end
				decals_by_unit[unit] = ring_map
			end
		end
		for unit in pairs(decals_by_unit) do
			if not alive[unit] then
				RingRenderer.teardown(unit)
			end
		end
	end)
end

function RingRenderer.teardown(unit)
	local ring_map = decals_by_unit[unit]
	if ring_map then
		for _, decal in pairs(ring_map) do
			destroy_ring(decal)
		end
	end
	decals_by_unit[unit] = nil
	RingRenderer.teardown_tripwires(unit)
end

function RingRenderer.teardown_all()
	for unit in pairs(decals_by_unit) do
		RingRenderer.teardown(unit)
	end
	RingRenderer.teardown_all_tripwires()
end

return RingRenderer
