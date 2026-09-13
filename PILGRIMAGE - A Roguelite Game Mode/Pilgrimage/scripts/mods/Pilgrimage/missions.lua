-- missions.lua
--
-- The mission catalogue and the run generator.
--
-- Reads the game's own MissionTemplates rather than carrying a hardcoded list, so a
-- Fatshark content patch adds missions to Pilgrimage for free and never leaves us
-- pointing at a mission that no longer exists.
--
-- ===========================================================================
-- WHY WE CHAIN REGULAR MISSIONS RATHER THAN USING THE EXPEDITION MECHANISM
-- ===========================================================================
--
-- Expeditions is already a Chaos Wastes clone: `exp_wastes` -> the "wastes" expedition
-- template, with 6 location levels, 4 safe zones, ~40 opportunity modules and a seeded
-- generator that takes a section count and a circumstance.
--
-- But its locations are assembled from slot metadata BAKED INTO THE LEVEL FILES.
-- scripts/utilities/expedition.lua:92 queries for them:
--
--     local raw_query = "AND json_extract(properties, '$.expedition') IS NOT NULL"
--     local masterdata_by_levels = get_masterdata_by_levels(raw_query)
--
-- A normal mission level carries no `expedition` property and no
-- ExpeditionLevelSlotTemplate components, and those are placed in Fatshark's level
-- editor. No mod can add them. So arbitrary missions can never be expedition locations.
--
-- Chaining full missions costs a loading screen per leg, and gains every mission in the
-- game, from any zone, in any order.
--
-- ===========================================================================
-- ZONES DO NOT CONSTRAIN CHAINING
-- ===========================================================================
--
-- Missions are grouped into 13 zone files purely for organisation. `zone_id` and
-- `wwise_state` only affect grouping and which music set plays. Every leg is a full
-- level load regardless, so a mission from `dust` followed by one from `watertown` is
-- exactly as easy as two from the same zone.
--
-- Note also that `spawn_settings.next_mission` on a mission template is NOT a chaining
-- hook. player_manager.lua:608 reads it as `player:set_wanted_spawn_point(...)`, which
-- only decides where you appear in the Mourningstar afterwards.

local M = {}

local _mod
local _shared
local _debug_log

local MISSION_TEMPLATES_PATH = "scripts/settings/mission/mission_templates"
local CIRCUMSTANCE_TEMPLATES_PATH = "scripts/settings/circumstance/circumstance_templates"
local DANGER_SETTINGS_PATH = "scripts/settings/difficulty/danger_settings"

local _mission_templates
local _circumstance_templates
local _danger_settings

-- Missions we never want in a run, whatever the filter says.
local MISSION_DENYLIST = {
	-- Two-phase boss fight with its own pacing; disruptive mid-run and SoloPlay
	-- denylists it for havoc for the same reason.
	km_enforcer_twins = true,
}

-- v0.22.46 attempted to allowlist Rolling Steel + No Man's Land past the
-- operations wall, but Kaizen's in-game playtest surfaced two hard blockers
-- (v0.22.48, 2026-08-08):
--
--   * Rolling Steel: Valkyrie doors never open. The mission's intro
--     cinematic expects the operations mechanism to drive it; launched via
--     adventure the intro handshake never completes and the player can't
--     disembark to actually start.
--   * No Man's Land: hard crash in mutator_spawner.lua:70 —
--     `bad argument #1 to 'spawn_locations' (table expected, got nil)`.
--     Operations missions don't publish the spawn-location table adventure
--     mutators expect, and lots of curses build on mutator_spawner.
--
-- Even without curses (i.e. curses_stacking off, no circumstance) Rolling
-- Steel still won't launch cleanly through adventure — the intro is the
-- deeper problem. Both missions require a real `mechanism_name = "operations"`
-- launch path, which is new engine surface the Curated Run system will need
-- anyway. So they get parked in RESERVED_MISSIONS: still known-valid, still
-- reachable by future features, but never drafted into normal pool.
--
-- OPERATIONS_ALLOWLIST stays defined (empty) so the code path in
-- is_playable() below still has a clean home for any future operations
-- mission that DOES work through adventure.
local OPERATIONS_ALLOWLIST = {}

-- Missions that are known valid but excluded from the normal draft pool,
-- reserved for future features (Curated Runs, special events).
--
-- op_train / op_no_mans_land: broken through the adventure pipeline (see
-- OPERATIONS_ALLOWLIST above). Kept here so the future Curated Run system
-- knows they exist and can launch them via the operations mechanism.
--
-- op_orthus (Orthus Offensive): template id not confirmed in the source
-- dump on disk; when Kaizen verifies the live id, add it here.
local RESERVED_MISSIONS = {
	op_train        = true,
	op_no_mans_land = true,
	-- op_orthus = true,   -- awaiting template id verification
}

-- Objective sets that are not real missions.
local OBJECTIVE_DENYLIST = {
	hub = true,
	onboarding = true,
	training_grounds = true,
	expedition_loading = true,
}

-- ---------------------------------------------------------------------------
-- Table access
-- ---------------------------------------------------------------------------

local function templates()
	if _mission_templates then return _mission_templates end
	local ok, value = pcall(require, MISSION_TEMPLATES_PATH)
	if ok and type(value) == "table" then _mission_templates = value end
	return _mission_templates
end

local function circumstances()
	if _circumstance_templates then return _circumstance_templates end
	local ok, value = pcall(require, CIRCUMSTANCE_TEMPLATES_PATH)
	if ok and type(value) == "table" then _circumstance_templates = value end
	return _circumstance_templates
end

local function dangers()
	if _danger_settings then return _danger_settings end
	local ok, value = pcall(require, DANGER_SETTINGS_PATH)
	if ok and type(value) == "table" then _danger_settings = value end
	return _danger_settings
end

M.templates = templates
M.circumstances = circumstances
M.dangers = dangers

-- Called from the entry file's consolidated hook so we capture the live table the
-- moment the game loads it, without forcing an early require.
function M.receive_templates(value)
	if type(value) == "table" then _mission_templates = value end
end

function M.receive_dangers(value)
	if type(value) == "table" then _danger_settings = value end
end

function M.receive_circumstances(value)
	if type(value) == "table" then _circumstance_templates = value end
end

M.DANGER_SETTINGS_PATH = DANGER_SETTINGS_PATH
M.CIRCUMSTANCE_TEMPLATES_PATH = CIRCUMSTANCE_TEMPLATES_PATH

M.MISSION_TEMPLATES_PATH = MISSION_TEMPLATES_PATH

-- ---------------------------------------------------------------------------
-- Classification
-- ---------------------------------------------------------------------------

-- The filter SoloPlay uses to decide what counts as a normal playable mission, and it
-- matches what the mission board offers.
--
-- v0.22.46: added operations-allowlist path. The base rule still rejects
-- mission_type == "operations" (Operations mode's category), because most of
-- those aren't adventure-shaped. But two of them (Rolling Steel, No Man's
-- Land) are real full-length missions worth including, so an allowlist entry
-- rescues them explicitly. RESERVED_MISSIONS is checked BEFORE the allowlist
-- so a name in both would still be excluded from the pool (reserved wins).
function M.is_playable(name, template)
	if type(template) ~= "table" then return false end
	if MISSION_DENYLIST[name] then return false end
	if RESERVED_MISSIONS[name] then return false end
	if template.objectives and OBJECTIVE_DENYLIST[template.objectives] then return false end

	if template.mechanism_name ~= "adventure" then return false end
	if template.game_mode_name ~= "coop_complete_objective" then return false end

	-- Operations wall + explicit allowlist rescue.
	if template.mission_type == "operations" then
		return OPERATIONS_ALLOWLIST[name] == true
	end

	return true
end

-- v0.22.46: introspection helpers for tests + debug commands. A future
-- Curated Run module reads M.is_reserved(name) to enumerate what's set aside
-- for it, without having to know the pool-filter internals.
function M.is_reserved(name)
	return RESERVED_MISSIONS[name] == true
end

function M.reserved_names()
	local out = {}
	for name in pairs(RESERVED_MISSIONS) do out[#out + 1] = name end
	table.sort(out)
	return out
end

function M.operations_allowlist_names()
	local out = {}
	for name in pairs(OPERATIONS_ALLOWLIST) do out[#out + 1] = name end
	table.sort(out)
	return out
end

-- Sorted list of playable mission names.
function M.playable()
	local all = templates()
	local out = {}
	if not all then return out end

	for name, template in pairs(all) do
		if M.is_playable(name, template) then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

-- The player-facing name. Mission templates carry a localisation key in
-- `mission_name` (e.g. "loc_mission_name_hm_strain"); the table key itself
-- ("hm_strain") is an internal id nobody outside the code recognises.
--
-- Falls back to the internal id when Localize is unavailable or returns nothing
-- useful, so this can never produce an empty label.
function M.display_name(name)
	local all = templates()
	local template = all and all[name]
	if not template then return tostring(name) end

	local key = template.mission_name
	if type(key) ~= "string" or key == "" then return tostring(name) end

	local Localize = rawget(_G, "Localize")
	if type(Localize) ~= "function" then return tostring(name) end

	local ok, text = pcall(Localize, key)
	if not ok or type(text) ~= "string" or text == "" then return tostring(name) end

	-- A missing localisation entry comes back wrapped in angle brackets.
	if text:sub(1, 1) == "<" then return tostring(name) end

	return text
end

-- "Chasm Terminus (hm_strain)" — the readable name plus the id, for anywhere the
-- id still matters (logs, bug reports, typing another command).
function M.label(name)
	local display = M.display_name(name)
	if display == tostring(name) then return tostring(name) end
	return display .. " (" .. tostring(name) .. ")"
end

function M.exists(name)
	local all = templates()
	return all ~= nil and all[name] ~= nil
end

function M.info(name)
	local all = templates()
	local template = all and all[name]
	if not template then return nil end

	return {
		name = name,
		zone_id = template.zone_id,
		mission_type = template.mission_type,
		mechanism_name = template.mechanism_name,
		game_mode_name = template.game_mode_name,
		level = template.level,
		objectives = template.objectives,
		wwise_state = template.wwise_state,
		-- Explicit booleans. `a and a.b ~= nil` yields nil rather than false when a
		-- is nil, which reads as "unknown" downstream instead of "no".
		has_intro = (template.cinematics ~= nil and template.cinematics.intro_abc ~= nil),
		has_outro = (template.cinematics ~= nil and template.cinematics.outro_win ~= nil),
		display = template.mission_name,
	}
end

-- Group playable missions by zone, for the terminal UI and for run variety rules.
function M.by_zone()
	local all = templates()
	local out = {}
	if not all then return out end

	for name, template in pairs(all) do
		if M.is_playable(name, template) then
			local zone = template.zone_id or "unknown"
			out[zone] = out[zone] or {}
			out[zone][#out[zone] + 1] = name
		end
	end
	for _, list in pairs(out) do table.sort(list) end
	return out
end

-- ---------------------------------------------------------------------------
-- Deterministic run generation
--
-- WHY WE OWN THE GENERATOR INSTEAD OF USING math.next_random
--
-- The first version called math.next_random(seed, 1, n) directly. Kaizen rerolled the
-- route repeatedly and leg 1 came out identical every single time, while the displayed
-- seed only changed in its last few digits.
--
-- Both symptoms have one cause. The seed came from the wall clock, so two rerolls a
-- second apart differ by 1, and math.next_random is an engine LCG whose first output is
-- strongly correlated with the seed it is handed. Feed it 1785874741 and 1785874742 and
-- the first value out is often the same bucket.
--
-- The game hits this too and solves it by hashing the input first:
--
--     broker_stimm_builder_view.lua:544
--     math.next_random(tonumber(Application.make_hash(a, b), 16))
--
-- We go one step further and own the generator outright, for three reasons:
--
--   1. it can be TESTED. math.next_random is a C function; whether adjacent seeds
--      decorrelate is unverifiable from Lua, and this bug is exactly the kind that
--      unverifiable code hides.
--   2. the seed is USER FACING. A player sharing "seed 1785874741" should get the same
--      route on any machine and after any game patch. An engine PRNG could change.
--   3. it is about fifteen lines.
--
-- No bitwise operators anywhere below. LuaJIT has them, plain Lua 5.1 does not, and the
-- test harness runs under both.
-- ---------------------------------------------------------------------------

local PRNG_MODULUS    = 2147483648   -- 2^31
local PRNG_MULTIPLIER = 1103515245
local PRNG_INCREMENT  = 12345

-- One round of "advance, then stir". The half-swap is what an xor would normally do for
-- us: it moves high bits into low positions, so the low bits we actually sample stop
-- being a near-copy of the seed's low bits. Three rounds is enough that flipping the
-- lowest bit of the input changes the output completely, which is the property the old
-- code lacked and the whole reason leg 1 never moved.
local function _stir(x)
	x = (x * PRNG_MULTIPLIER + PRNG_INCREMENT) % PRNG_MODULUS
	x = math.floor(x / 65536) + (x % 65536) * 32768
	return x % PRNG_MODULUS
end

-- Turns any number, including a timestamp, into a well spread 31 bit seed.
function M.mix_seed(value)
	local x = math.floor(math.abs(tonumber(value) or 0)) % PRNG_MODULUS
	for _ = 1, 3 do x = _stir(x) end
	return x
end

-- Returns next_seed, value where lo <= value <= hi. Same shape as math.next_random, so
-- call sites did not have to change.
local function next_random(seed, lo, hi)
	local next_seed = _stir(seed)

	if not lo then return next_seed, next_seed end
	hi = hi or lo

	local span = hi - lo + 1
	if span < 1 then return next_seed, lo end

	-- Sample from the HIGH bits. The low bits of an LCG have short periods, which is the
	-- classic reason "seed % n" behaves badly for small n, and n here is the number of
	-- candidate missions, which is small.
	local value = lo + math.floor((next_seed / PRNG_MODULUS) * span)
	if value > hi then value = hi end

	return next_seed, value
end

M.next_random = next_random

-- Pick `count` missions without repeating until the pool is exhausted, and avoid
-- putting two missions from the same zone back to back where the pool allows it.
function M.generate_queue(count, seed, options)
	options = options or {}
	count = math.max(1, math.min(count or 3, 20))

	local pool = M.playable()
	if #pool == 0 then return {}, seed end

	if options.zone then
		local filtered = {}
		local all = templates()
		for i = 1, #pool do
			if all[pool[i]].zone_id == options.zone then filtered[#filtered + 1] = pool[i] end
		end
		if #filtered > 0 then pool = filtered end
	end

	local all = templates()
	local remaining = {}
	for i = 1, #pool do remaining[i] = pool[i] end

	local queue = {}
	local last_zone

	-- The seed the CALLER gave us is the shareable one and is echoed back unchanged.
	-- What drives the generator is its mixed form, so two timestamps a second apart
	-- produce two completely unrelated routes rather than the same first leg.
	local given_seed = seed
	seed = M.mix_seed(seed)

	for _ = 1, count do
		if #remaining == 0 then
			-- Pool exhausted, refill. A run longer than the mission list repeats.
			for i = 1, #pool do remaining[i] = pool[i] end
		end

		-- Prefer a different zone from the previous leg, but never fail over it.
		local candidates = {}
		for i = 1, #remaining do
			if not last_zone or all[remaining[i]].zone_id ~= last_zone then
				candidates[#candidates + 1] = i
			end
		end
		if #candidates == 0 then
			for i = 1, #remaining do candidates[i] = i end
		end

		local value
		seed, value = next_random(seed, 1, #candidates)
		local chosen_index = candidates[value]
		local chosen = remaining[chosen_index]

		queue[#queue + 1] = chosen
		last_zone = all[chosen].zone_id
		table.remove(remaining, chosen_index)
	end

	return queue, given_seed
end

-- ---------------------------------------------------------------------------
-- Mission context
--
-- The table handed to Managers.mechanism:change_mechanism. Verified against
-- MechanismAdventure.init (mechanism_adventure.lua:34-70), which reads exactly these
-- fields off the context when it is not a dedicated mission server.
--
-- Note the game already defends one of them for us: an unknown circumstance_name logs
-- an error and falls back to "default" rather than crashing. We validate anyway.
-- ---------------------------------------------------------------------------

function M.build_context(mission_name, danger_level, circumstance_name, extra)
	local all = templates()
	local template = all and all[mission_name]
	if not template then
		return nil, "unknown mission '" .. tostring(mission_name) .. "'"
	end

	-- DangerSettings is a plain 1..5 array. Entry fields we use: challenge,
	-- resistance, name ("uprising", "malice", ...), display_name.
	local danger = dangers()
	local danger_entry = danger and danger[danger_level or 3]
	if not danger_entry or danger_entry.challenge == nil then
		return nil, "unknown danger level " .. tostring(danger_level)
	end

	circumstance_name = circumstance_name or "default"
	local circumstance_table = circumstances()
	if circumstance_name ~= "default" and circumstance_table
		and not circumstance_table[circumstance_name] then
		circumstance_name = "default"
	end

	local context = {
		mission_name = mission_name,
		challenge = danger_entry.challenge,
		resistance = danger_entry.resistance,
		circumstance_name = circumstance_name,
		side_mission = "default",
	}

	if type(extra) == "table" then
		for key, value in pairs(extra) do context[key] = value end
	end

	-- The mechanism name is read off the template, never hardcoded, because
	-- different mission families use different mechanisms.
	return context, nil, template.mechanism_name
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_debug_log = deps.debug_log or function() end
end

return M
