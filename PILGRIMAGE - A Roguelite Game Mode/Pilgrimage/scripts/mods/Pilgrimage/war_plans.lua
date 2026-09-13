-- war_plans.lua
--
-- The pilgrimage tree: named routes with fixed lengths and starting
-- difficulties, unlocked by penances.
--
-- ===========================================================================
-- WHY WAR PLANS EXIST
-- ===========================================================================
--
-- Before v0.19 every pilgrimage was the same shape: N legs (mod option),
-- fixed starting difficulty, curses drawn from the pool. There was no reason
-- to play a HARDER pilgrimage; the game could not offer one you had earned.
--
-- Kaizen's design: named tiers unlocked by completion. Fresh install has
-- one 2-leg plan available. Clear it and the next tier unlocks: a longer
-- pilgrimage at a higher starting difficulty. By the top tier the ramp
-- takes you into the enemy-only Havoc scaling built in v0.18.
--
-- Tree branching (a "War Plan" node graph where a leg has two possible
-- successors) is the next step in this feature. v0.19 lays the CATALOGUE
-- and UNLOCK plumbing; every plan is still a linear queue. That is enough
-- to prove out the progression side without the UI cost.
--
-- ===========================================================================
-- THE CATALOGUE
-- ===========================================================================
--
--   novitiate    2 legs, Malice start   (Malice, Heresy)
--   penitent     3 legs, Malice start   (Malice, Heresy, Damnation)
--   fanatic      4 legs, Heresy start   (Heresy, Damnation, D+T1, D+T2)
--   martyr       5 legs, Damnation      (Damnation, D+T1, D+T2, D+T3, D+T3)
--
-- v0.19.1: tier 3 renamed Zealot -> Fanatic. Zealot is an in-game class;
-- reusing the name for a difficulty tier was going to get confusing.
--
-- Fresh install: novitiate is always available. Each subsequent plan is
-- gated on completing the previous one (penance ids in penances.lua).
--
-- Difficulty per leg comes from difficulty.lua's ramp, so a plan just
-- names a starting_difficulty and leg_count; the ramp is applied by the
-- launcher exactly as before.

local M = {}

local _mod
local _missions
local _curses
local _difficulty
local _penances
-- Declared at the top, above every function (v0.14.1 boons lesson).
local _debug_log

-- The plan table. Order matters: `available()` returns them in this order
-- so cycling through the terminal always shows plans in ascending tier.
--
-- unlock_penance is the id in penances.lua that must be earned to unlock
-- this plan. nil means "always available" (novitiate).
-- v0.20.3: min_tier / max_tier bracket which curse tiers this plan is
-- allowed to draw from. Before this the tier was decided by the leg's
-- ratio within the run (leg 1 = t1, leg 3/3 = t3 regardless of plan),
-- which made Novitiate roll tier 1 AND tier 3 in the same 2-leg run
-- (leg 2 of 2 was ratio 1.0). The new model treats the War Plan as the
-- difficulty container: the plan says which tiers it draws from, and
-- individual legs ramp inside that range.
--
--   min_tier == max_tier    flat plan, every leg draws from that tier
--                           (Novitiate: 1, Fanatic: 2)
--   min_tier <  max_tier    ramp: leg 1 draws from min_tier, last leg
--                           draws from max_tier, middle legs
--                           interpolate (see curses._severity_for)
M.PLANS = {
	{
		id = "novitiate",
		name = "The Novitiate's Vow",
		description = "Two assignments. A first taste of the pilgrim's road.",
		leg_count = 2,
		starting_difficulty_name = "malice",
		unlock_penance = nil,
		min_tier = 1,
		max_tier = 1,
	},
	{
		id = "penitent",
		name = "The Penitent's Path",
		description = "Three assignments culminating in Damnation. The ramp begins here.",
		leg_count = 3,
		starting_difficulty_name = "malice",
		unlock_penance = "pilgrim_first_steps",
		min_tier = 1,
		max_tier = 2,
	},
	{
		-- v0.19.1: was "zealot" (Kaizen: Zealot is a class in this game).
		-- Renamed to "fanatic" AT THE ID LEVEL, because settings that stored
		-- selected_war_plan="zealot" fall back to the default (novitiate)
		-- with a warning, which is acceptable for a rename this early in
		-- the mod's lifetime. Anyone mid-run at v0.19.0 gets bumped to
		-- Novitiate for the next selection; no earned penances are lost.
		id = "fanatic",
		name = "The Fanatic's Trial",
		description = "Four assignments, starting at Heresy. Damnation early, scaling after.",
		leg_count = 4,
		starting_difficulty_name = "heresy",
		unlock_penance = "pilgrim_faithful",
		min_tier = 2,
		max_tier = 2,
	},
	{
		id = "martyr",
		name = "The Martyr's Vigil",
		description = "Five assignments from Damnation up. Enemy Havoc scaling all through. Auric Intensity always active.",
		leg_count = 5,
		starting_difficulty_name = "damnation",
		unlock_penance = "pilgrim_ascendant",
		min_tier = 2,
		max_tier = 3,
		-- v0.22.99 (Kaizen): Auric Intensity is a standing feature of
		-- this plan, not a roll. Applied to EVERY leg on top of the
		-- rolled curses (curses.FORCED_BY_PLAN mirrors this list; both
		-- must name the plan for the wiring to engage). Also passed to
		-- curses.assign as an exclusion so no leg wastes its roll on it.
		forced_curses = { "pilgrim_auric_intensity" },
	},
}

-- Roadmap: a fifth secret tier "The Saint" — unlocked far past martyr and
-- requiring accumulated permanent boons to be tackleable. Not implemented in
-- v0.19; noted here so the design intent isn't lost. When it lands it
-- inherits forced_curses = { "pilgrim_auric_intensity" } (curses.lua's
-- FORCED_BY_PLAN already carries a "saint" entry).

M.DEFAULT_ID = "novitiate"

local _by_id = {}
for i = 1, #M.PLANS do _by_id[M.PLANS[i].id] = M.PLANS[i] end

-- ---------------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------------

function M.get(id)
	return _by_id[id]
end

function M.all()
	return M.PLANS
end

-- The id of the plan currently selected in settings, falling back to the
-- default when nothing is set or the selection is stale (unknown id, or
-- the plan has since been locked, which cannot happen in v0.19 but is a
-- safety anyway for future updates).
function M.selected_id()
	local raw = _mod and _mod:get("selected_war_plan")
	if type(raw) == "string" and _by_id[raw] and M.is_unlocked(raw) then
		return raw
	end
	return M.DEFAULT_ID
end

function M.selected()
	return M.get(M.selected_id())
end

-- Sets the selection. Returns true on success, false + reason on refusal.
function M.select(id)
	local plan = _by_id[id]
	if not plan then return false, "unknown plan '" .. tostring(id) .. "'" end
	if not M.is_unlocked(id) then
		return false, "locked, complete " .. tostring(plan.unlock_penance)
	end
	if _mod then _mod:set("selected_war_plan", id, false) end
	return true
end

-- ---------------------------------------------------------------------------
-- Unlock state
-- ---------------------------------------------------------------------------

function M.is_unlocked(id)
	local plan = _by_id[id]
	if not plan then return false end
	if not plan.unlock_penance then return true end
	if not _penances or not _penances.is_earned then return false end
	return _penances.is_earned(plan.unlock_penance) == true
end

function M.locked_reason(id)
	local plan = _by_id[id]
	if not plan then return "unknown plan" end
	if not plan.unlock_penance then return nil end
	if M.is_unlocked(id) then return nil end
	local penance = _penances and _penances.get and _penances.get(plan.unlock_penance)
	local penance_name = penance and penance.name or plan.unlock_penance
	return "Locked. Complete: " .. tostring(penance_name)
end

-- Every unlocked plan, in tier order. First element is always novitiate.
function M.available()
	local out = {}
	for i = 1, #M.PLANS do
		if M.is_unlocked(M.PLANS[i].id) then
			out[#out + 1] = M.PLANS[i]
		end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Route generation
--
-- Delegates to missions.generate_queue and curses.assign, using the plan's
-- leg_count. Returns the same shape the terminal already consumes:
--   { queue, seed, curses, starting_difficulty, plan_id, plan_name }
-- so the existing "begin pilgrimage" path is a one-line update.
-- ---------------------------------------------------------------------------

function M.generate_route(id, seed)
	local plan = _by_id[id] or _by_id[M.DEFAULT_ID]

	local queue = _missions.generate_queue(plan.leg_count, seed)
	-- v0.20.3: hand the plan's tier range to curses.assign so the pool
	-- restriction lives with the plan definition and never has to be
	-- inferred from leg count. A plan with min_tier=max_tier=1 (Novitiate)
	-- gets tier-1 curses only; a mixed plan (Penitent 1-2, Martyr 2-3)
	-- ramps across its range.
	-- v0.22.99: the plan's forced (always-on) curses are excluded from
	-- the roll; they apply to every leg via curses.stacked_for instead.
	-- Plans without forced_curses pass nil and draw exactly as before,
	-- so existing shared seeds keep their routes.
	local curses = _curses and _curses.assign
		and _curses.assign(#queue, seed, plan.min_tier, plan.max_tier,
			plan.forced_curses) or nil
	local starting = _difficulty and _difficulty.DANGER_BY_NAME
		and _difficulty.DANGER_BY_NAME[plan.starting_difficulty_name]
		or (_difficulty and _difficulty.DANGER_MALICE) or 2

	return {
		queue = queue,
		seed = seed,
		curses = curses,
		starting_difficulty = starting,
		plan_id = plan.id,
		plan_name = plan.name,
		leg_count = plan.leg_count,
		min_tier = plan.min_tier,
		max_tier = plan.max_tier,
	}
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_missions = deps.missions
	_curses = deps.curses
	_difficulty = deps.difficulty
	_penances = deps.penances
	_debug_log = deps.debug_log or function() end
end

return M
