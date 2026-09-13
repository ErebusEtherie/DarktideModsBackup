-- difficulty.lua
--
-- Per-leg difficulty ramping. Real enemy scaling, no player debuffs.
--
-- ===========================================================================
-- THE RAMP
-- ===========================================================================
--
--   leg 1: starting_difficulty (default Malice, mod option)
--   leg 2: +1 challenge
--   ...
--   until Damnation (cap)
--   then: Damnation + scale_tier 1
--   then: Damnation + scale_tier 2
--   then: Damnation + scale_tier 3   (cap)
--
-- ===========================================================================
-- ABOVE DAMNATION: WHAT SCALES, HOW WE DO IT
-- ===========================================================================
--
-- Kaizen's correction 2026-08-06: the earlier version added Havoc CIRCUMSTANCES
-- (mutator_havoc_tougher_skin etc). Those are just more curses. What he wanted
-- is the actual Havoc RANK scaling: enemy HP multipliers and attack-speed
-- buffs applied numerically to every minion, with no new mechanics.
--
-- Verified paths for coop_complete_objective missions (from source):
--
-- HP SCALING - minion_spawn_manager.lua:126 reads
--   circumstance_template.minion_health_modifier[challenge]
-- and passes it as additional_health_modifier when spawning any minion.
-- So writing this field on the pilgrimage_stacked template scales EVERY
-- minion's HP by that percentage. Same mechanism the shipped
-- live_event_elite_army circumstance uses.
--
-- ATTACK SPEED - havoc's own game_mode_extension_havoc._on_minion_unit_spawned
-- (line 259) calls buff_extension:add_internally_controlled_buff(
-- "havoc_melee_attack_speed_0X") on melee tags, and the same for ranged tags
-- with havoc_ranged_attack_speed_0X. These buff templates are shipped and
-- valid; the havoc extension is just the caller. Since our coop mission has
-- no havoc extension, we do the equivalent ourselves via a
-- minion_unit_spawned event hook (installed by launcher / wired here).
--
-- No player debuffs, no ammo pickup changes, no toughness regen changes.
-- Only enemy HP and enemy attack speed.
--
-- ===========================================================================
-- FIXED TIER TABLE (Kaizen: pick a fixed set)
-- ===========================================================================
--
--   Tier 0 (Damnation, no extra): baseline
--   Tier 1: +30% minion HP
--   Tier 2: +60% minion HP,  melee attack speed 02, ranged attack speed 02
--   Tier 3: +100% minion HP, melee attack speed 04, ranged attack speed 04

local M = {}

local _mod

M.DANGER_UPRISING   = 1
M.DANGER_MALICE     = 2
M.DANGER_HERESY     = 3
M.DANGER_DAMNATION  = 4

M.MIN_DANGER = M.DANGER_UPRISING
M.MAX_DANGER = M.DANGER_DAMNATION

M.DANGER_BY_NAME = {
	uprising  = M.DANGER_UPRISING,
	malice    = M.DANGER_MALICE,
	heresy    = M.DANGER_HERESY,
	damnation = M.DANGER_DAMNATION,
}

M.NAME_BY_DANGER = {
	[M.DANGER_UPRISING]  = "Uprising",
	[M.DANGER_MALICE]    = "Malice",
	[M.DANGER_HERESY]    = "Heresy",
	[M.DANGER_DAMNATION] = "Damnation",
}

-- The scale table. tier=0 is unused (means "no scaling"). Indexed 1..3.
-- health: percentage bonus to minion HP at challenge 5 (Damnation). Applied
-- via circumstance_template.minion_health_modifier[5] on pilgrimage_stacked.
-- melee_buff / ranged_buff: shipped buff template names that the havoc
-- extension itself uses (havoc_settings.lua:238-250). nil means "no buff".
M.SCALE_TIERS = {
	{ health = 0.30, melee_buff = nil,                          ranged_buff = nil                          },
	{ health = 0.60, melee_buff = "havoc_melee_attack_speed_02", ranged_buff = "havoc_ranged_attack_speed_02" },
	{ health = 1.00, melee_buff = "havoc_melee_attack_speed_04", ranged_buff = "havoc_ranged_attack_speed_04" },
}
M.MAX_SCALE_TIER = #M.SCALE_TIERS

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

function M.starting_difficulty()
	if not _mod or type(_mod.get) ~= "function" then return M.DANGER_MALICE end
	local name = _mod:get("starting_difficulty")
	if type(name) == "string" then
		local idx = M.DANGER_BY_NAME[name]
		if idx then return idx end
	end
	if type(name) == "number" and name >= M.MIN_DANGER and name <= M.MAX_DANGER then
		return math.floor(name)
	end
	return M.DANGER_MALICE
end

-- ---------------------------------------------------------------------------
-- The ramp
-- ---------------------------------------------------------------------------

function M.for_leg(leg, starting_difficulty)
	starting_difficulty = starting_difficulty or M.starting_difficulty()
	if not starting_difficulty or starting_difficulty < M.MIN_DANGER then
		starting_difficulty = M.MIN_DANGER
	end
	if starting_difficulty > M.MAX_DANGER then starting_difficulty = M.MAX_DANGER end

	local raw = starting_difficulty + (leg or 1) - 1
	local danger, scale_tier

	if raw <= M.MAX_DANGER then
		danger = raw
		scale_tier = 0
	else
		danger = M.MAX_DANGER
		scale_tier = raw - M.MAX_DANGER
		if scale_tier > M.MAX_SCALE_TIER then scale_tier = M.MAX_SCALE_TIER end
	end

	return {
		danger = danger,
		danger_name = M.NAME_BY_DANGER[danger],
		scale_tier = scale_tier,
		scale_settings = scale_tier > 0 and M.SCALE_TIERS[scale_tier] or nil,
	}
end

function M.danger_for_leg(leg, starting_difficulty)
	return M.for_leg(leg, starting_difficulty).danger
end

-- The HP-modifier array the coop game mode reads off the circumstance
-- template, indexed 1..6 by challenge. Only Damnation (challenge 5) gets a
-- non-zero value; every other challenge slot gets 0 so a lower-challenge
-- accidentally reading this template gets no scaling.
--
-- Returns nil when the scale_tier is 0 (no extra scaling wanted). The caller
-- (curses.lua's stacked_for) writes this onto pilgrimage_stacked when it's
-- non-nil.
function M.minion_health_modifier_for(scale_tier)
	if not scale_tier or scale_tier < 1 then return nil end
	if scale_tier > M.MAX_SCALE_TIER then scale_tier = M.MAX_SCALE_TIER end
	local settings = M.SCALE_TIERS[scale_tier]
	if not settings or not settings.health or settings.health <= 0 then return nil end
	-- Array indexed 1..6. Index 5 = Damnation, where scale tiers apply.
	-- Index 6 (auric) mirrors it so an auric-configured launch still scales.
	return { 0, 0, 0, 0, settings.health, settings.health }
end

-- Names of the shipped buff templates to add to spawned melee/ranged
-- minions at this scale tier. Returns two strings or two nils.
function M.spawn_buffs_for(scale_tier)
	if not scale_tier or scale_tier < 1 then return nil, nil end
	if scale_tier > M.MAX_SCALE_TIER then scale_tier = M.MAX_SCALE_TIER end
	local settings = M.SCALE_TIERS[scale_tier]
	if not settings then return nil, nil end
	return settings.melee_buff, settings.ranged_buff
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
end

return M
