local Detection = {}

-- === Field-name verification (1.12.x "Skitarii", Aussiemon/Darktide-Source-Code @ master) ===
-- Verified against the decompiled source. Deviations from RitualZones' port are called out:
--  * is_ritual_active: CHANGED. "mutator_havoc_chaos_rituals" is NOT in the circumstances
--    whitelist (havoc_settings.lua) in the current game; it is a mutator_spawner-class entry.
--    Detect it via Managers.state.mutator:mutator("mutator_havoc_chaos_rituals"). We check that
--    first and keep the circumstances scan only as a harmless fallback. (This is likely a root
--    cause of RitualZones' "features that don't work anymore".)
--  * find_ritual_units: CONFIRMED. side_system + alive_units_by_tag("enemy","witch") + breed
--    "chaos_mutator_daemonhost" (distinct from chaos_daemonhost; both carry tag "witch"). The
--    mutator _alive_monsters cross-check now scans BOTH "mutator_monster_spawner" and the ritual
--    spawner "mutator_havoc_chaos_rituals".
--  * get_ring_defs: CONFIRMED values (far 30, close 15) but there is no reliable global
--    DaemonhostActions. We require() the settings module directly:
--    scripts/settings/breed/breed_actions/chaos/chaos_mutator_daemonhost_actions.
--    The 55m trigger ring (and its havoc_mutator_local_settings lookup) was removed: a 110m disc
--    smeared onto every wall in range and it was already off by default.
-- ==========================================================================================

-- require() a game settings module by path, cached by the engine; nil on failure (path drift).
local function safe_require(path)
	local ok, value = pcall(require, path)
	if ok then
		return value
	end
	return nil
end

-- Ritual mutator name (Havoc "Heinous Rituals"); the daemonhost spawner key, used for ritual-active
-- detection and the _alive_monsters cross-check.
local RITUAL_MUTATOR = "mutator_havoc_chaos_rituals"

-- Static settings, resolved lazily (module require is cached; retries harmlessly until loaded).
local function daemonhost_actions()
	return safe_require("scripts/settings/breed/breed_actions/chaos/chaos_mutator_daemonhost_actions")
end

local function is_finite_number(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- CRITICAL (spec §12a): since the Skitarii patch, positions can arrive BOXED (Vector3Box, a
-- userdata). Vector3.x/World APIs reject a box with "Vector3 expected, got userdata". Unbox
-- anything that carries an :unbox() method; pass a plain Vector3 through unchanged. All field
-- access is pcall-guarded because indexing a plain Vector3 userdata can itself error.
local function unbox_if_boxed(v)
	if v == nil then
		return nil
	end
	local ok, unbox_fn = pcall(function()
		return v.unbox
	end)
	if ok and type(unbox_fn) == "function" then
		local ok2, unboxed = pcall(unbox_fn, v)
		if ok2 and unboxed ~= nil then
			return unboxed
		end
	end
	return v
end

-- Ported from RitualZones.lua:2013 (is_finite_vector), hardened: unbox first, and pcall the
-- Vector3.x probe so a stray box/nil returns false instead of crashing the update loop.
local function is_finite_vector(vec)
	vec = unbox_if_boxed(vec)
	if not vec or not Vector3 or not Vector3.x then
		return false
	end
	local ok, x = pcall(Vector3.x, vec)
	if not ok then
		return false
	end
	return is_finite_number(x)
		and is_finite_number(Vector3.y(vec))
		and is_finite_number(Vector3.z(vec))
end

local function unit_is_alive(unit)
	return unit and Unit.alive(unit)
end

-- Ported from RitualZones.lua:2022 (get_unit_position). Returns a plain (UNBOXED), finite Vector3
-- ready to hand to World.spawn_unit_ex (which is exactly how danger_zone uses POSITION_LOOKUP).
function Detection.get_unit_position(unit)
	local pos = unbox_if_boxed(POSITION_LOOKUP[unit])
	if pos and is_finite_vector(pos) then
		return pos
	end
	if Unit and Unit.world_position then
		local ok, value = pcall(Unit.world_position, unit, 1)
		if ok then
			value = unbox_if_boxed(value)
			if value and is_finite_vector(value) then
				return value
			end
		end
	end
	return nil
end

-- Ported from RitualZones.lua:2319 (get_monster_position). CRITICAL unbox guard (spec §12a):
-- monster.position may be a BOXED Vector3 (userdata); unbox before any engine call.
function Detection.get_monster_position(monster)
	if not monster then
		return nil
	end
	local position = monster.position
	if position and position.unbox then
		local ok, value = pcall(position.unbox, position)
		if ok and is_finite_vector(value) then
			return value
		end
	end
	if is_finite_vector(position) then
		return position
	end
	return nil
end

-- CHANGED from RitualZones.lua:426 (is_havoc_ritual_active). Primary check is the ritual mutator's
-- presence (the current game does NOT list it in circumstances); circumstances scan is a fallback.
function Detection.is_ritual_active()
	if not Managers or not Managers.state then
		return false
	end

	-- Primary: the Havoc chaos-rituals mutator is registered/active in the mutator manager.
	local mutator_manager = Managers.state.mutator
	if mutator_manager and mutator_manager.mutator then
		local ok, mutator = pcall(mutator_manager.mutator, mutator_manager, RITUAL_MUTATOR)
		if ok and mutator then
			return true
		end
	end

	-- Fallback: older/other builds that surfaced it in the parsed havoc circumstances array.
	local difficulty = Managers.state.difficulty
	if difficulty and difficulty.get_parsed_havoc_data then
		local ok, havoc_data = pcall(difficulty.get_parsed_havoc_data, difficulty)
		if ok and havoc_data and havoc_data.circumstances then
			for i = 1, #havoc_data.circumstances do
				if havoc_data.circumstances[i] == RITUAL_MUTATOR then
					return true
				end
			end
		end
	end

	return false
end

-- Ported from RitualZones.lua:3715 (find_ritual_units). Client-safe: scans the enemy side +
-- the monster-spawner mutator for live chaos_mutator_daemonhost units. No RPC, no cache.
function Detection.find_ritual_units()
	local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
	if not side_system then
		return {}
	end
	local player_side = side_system:get_side_from_name("heroes")
	if not player_side then
		return {}
	end

	-- Read the witch-tagged enemies, then fall back to the full enemy scan when that set reads empty.
	-- Do NOT "optimize" this into "skip the fallback whenever the tag API exists": alive_units_by_tag's
	-- return shape feeds numbers into the unit iteration below, which throws
	-- "bad argument #1 to 'alive' (userdata expected, got number)" every frame. The fallback is
	-- load-bearing, not merely a no-daemonhost guard. The 0.2s update throttle already covers the
	-- per-frame cost this scan used to incur (that was the actual perf fix).
	local enemy_units = nil
	if player_side.alive_units_by_tag then
		enemy_units = player_side:alive_units_by_tag("enemy", "witch")
	end
	local count = enemy_units and (enemy_units.size or #enemy_units) or 0
	if count == 0 then
		enemy_units = player_side:relation_units("enemy") or {}
	end
	enemy_units = enemy_units or {}
	local ritual_units = {}
	local seen = {}

	local function add_ritual_unit(unit, skip_breed_check)
		if not unit or seen[unit] or not unit_is_alive(unit) then
			return
		end
		if skip_breed_check then
			ritual_units[#ritual_units + 1] = unit
			seen[unit] = true
			return
		end
		if ScriptUnit.has_extension(unit, "unit_data_system") then
			local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
			local breed = unit_data_extension and unit_data_extension:breed()
			if breed and breed.name == "chaos_mutator_daemonhost" then
				ritual_units[#ritual_units + 1] = unit
				seen[unit] = true
			end
		end
	end

	count = enemy_units.size or #enemy_units
	if count > 0 then
		for i = 1, count do
			add_ritual_unit(enemy_units[i])
		end
	else
		for key, value in pairs(enemy_units) do
			local unit = key
			if type(unit) ~= "userdata" then
				unit = value
			end
			add_ritual_unit(unit)
		end
	end

	-- Cross-check the monster-spawner mutators' _alive_monsters. Scan both the generic spawner and
	-- the ritual spawner, since the ritual daemonhosts may be tracked under either name.
	local mutator_manager = Managers.state.mutator
	if mutator_manager and mutator_manager.mutator then
		local mutator_names = { "mutator_monster_spawner", RITUAL_MUTATOR }
		for n = 1, #mutator_names do
			local ok, mutator = pcall(mutator_manager.mutator, mutator_manager, mutator_names[n])
			if ok and mutator and mutator._alive_monsters then
				for i = 1, #mutator._alive_monsters do
					local monster = mutator._alive_monsters[i]
					if monster and monster.breed_name == "chaos_mutator_daemonhost" then
						add_ritual_unit(monster.spawned_unit, true)
					end
				end
			end
		end
	end

	return ritual_units
end

-- Ported from RitualZones.lua:2345 (get_ring_defs). Radii from static settings, resolved via
-- require() (values confirmed 1.12.x: far 30, close 15). The 55m trigger ring was removed: a 110m
-- disc smeared onto every wall in range and it was already off by default.
function Detection.get_ring_defs()
	local rings = {}

	local actions = daemonhost_actions()
	local passive = (actions and actions.passive) or {}
	local far_distance = passive.far_distance_offset
	local close_distance = passive.close_distance_offset

	if far_distance and far_distance > 0 then
		rings[#rings + 1] = { id = "ritual_start", radius = far_distance, color = "orange" }
	end
	if close_distance and close_distance > 0 then
		rings[#rings + 1] = { id = "ritual_speedup", radius = close_distance, color = "yellow" }
	end

	return rings
end

return Detection
