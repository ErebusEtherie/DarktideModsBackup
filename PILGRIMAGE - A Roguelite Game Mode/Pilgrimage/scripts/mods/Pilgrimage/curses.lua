-- curses.lua
--
-- Every leg of a pilgrimage carries a curse: one of the game's own mission
-- circumstances, assigned when the route is generated and shown in the preview before
-- you commit. Same seed, same gauntlet.
--
-- ---------------------------------------------------------------------------
-- Why circumstances
-- ---------------------------------------------------------------------------
--
-- Darktide already ships the whole system: darkness, toxic gas, hunting grounds,
-- ventilation purge, the Havoc mutators, and so on, each a named template with its own
-- localization, icon and spawn logic. The launcher already threads a circumstance name
-- into the mission context. So a curse costs us a NAME, not a system.
--
-- ---------------------------------------------------------------------------
-- Curation policy, per Kaizen
-- ---------------------------------------------------------------------------
--
-- Buff the enemy or change the conditions. NEVER debuff the player.
--
-- Havoc's explicit modifiers (tox gas, cranial corruption, stimmed minions...) are
-- fine and popular; its implicit rank scaling (less ammo from crates, lower health and
-- toughness) is disliked and is deliberately absent. Conveniently the implicit scaling
-- is not a circumstance at all, it lives in the Havoc rank system, so it cannot leak in
-- through this file. The two circumstances that DO reproduce it,
-- mutator_increased_difficulty and mutator_highest_difficulty, are excluded on purpose.
--
-- Also excluded:
--   * _less_resistance / _more_resistance variants: same curse, different enemy
--     budget. The base version is the curse; density is the danger setting's job.
--   * twins / expedition / solo variants: tied to specific mission scripting.
--   * cosmetic reskins (noir, dawn, ember, hub events): a curse must change play.
-- ---------------------------------------------------------------------------

local M = {}

local _mod
local _shared
local _event_log
-- v0.22.47: added so stacked_for can log dropped-mutator warnings.
-- Missing before because curses.lua didn't need diagnostic logging;
-- the guard on this being nil is because init may not have wired it.
local _debug_log
local _passives
-- Declared at the top, above every function, because a Lua function only
-- captures locals that exist above its definition (the v0.14.1 boons lesson).
local _run_state

-- Where the game's circumstance table comes from. Same fanout as missions.lua uses;
-- the handler in Pilgrimage.lua calls receive_templates when the file is required.
M.CIRCUMSTANCE_TEMPLATES_PATH = "scripts/settings/circumstance/circumstance_templates"

local _templates = nil

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_event_log = deps.event_log
	_run_state = deps.run_state
	_debug_log = deps.debug_log
	_passives = deps.passives
	if _passives and type(_passives.register_template_source) == "function" then
		_passives.register_template_source(M.SAFE_BUFF_TEMPLATES)
	end
end

-- v0.22.92: Pilgrimage's own curses. Registered into the game's live
-- CircumstanceTemplates table the moment it arrives, so pool(),
-- stack_curses() and the launcher treat them exactly like vanilla
-- circumstances. Zero mutators, nil ui: the same field-proven shape as
-- the health-modifier-only stacked circumstance. Their EFFECTS live
-- Pilgrimage-side, keyed on the curse name being in the run's curse
-- prefix (The Serpent Below: traitor-bot friendly fire policy in
-- Pilgrimage.lua).
-- v0.24.1 (FB-5, user crash report GUID 29e6f071): Pilgrimage's own
-- MUTATOR templates, registered into the game's live MutatorTemplates
-- aggregator the same way the curse circumstances register below.
--
-- Why: our "Shambling Pyres" curse pointed at the vanilla circumstance
-- common_minion_on_fire, whose mutator (mutator_common_minions_on_fire)
-- is class mutator_modify_havoc. That class's init calls
-- game_mode():extension("havoc"):init_horde_buff(), and the "havoc"
-- extension only exists in the Havoc game mode, so ANY normal mission
-- carrying it crashed at load ("attempt to index a nil value",
-- mutator_modify_havoc.lua:11). Repeatable, map-independent.
--
-- The replacement delivers the same fantasy through MutatorBase's own
-- per-spawn machinery: random_spawn_buff_templates applies the vanilla
-- common_minion_on_fire BUFF to walker breeds as they spawn
-- (mutator_base.lua line 208: breed_chance > math.random(), so 1 =
-- always), no havoc extension involved.
local CUSTOM_MUTATOR_TEMPLATES = {
	pilgrim_minions_on_fire = {
		class = "scripts/managers/mutator/mutators/mutator_base",
		random_spawn_buff_templates = {
			buffs = { "common_minion_on_fire" },
			breed_chances = {
				chaos_poxwalker = 1,
				chaos_newly_infected = 1,
			},
		},
	},
}

-- v0.28.5: the vanilla havoc_toughened_skin buff asks the Havoc game-mode
-- extension for a rank when it starts. Pilgrimage runs Adventure missions,
-- so that extension is nil and the first affected enemy crashes mission load.
-- A fixed 0.5 ranged-damage multiplier matches the vanilla rank-40 result
-- without consulting Havoc state. It rides the existing Passives registry so
-- it is a normal synchronized buff as far as the minion extension is concerned.
M.SAFE_BUFF_TEMPLATES = {
	{
		id = "pilgrim_toughened_skin",
		buff_template = "pilgrim_toughened_skin",
		custom = {
			stat_buffs = {
				ranged_damage_taken_multiplier = 0.5,
			},
		},
	},
}

-- Stored routes keep their original curse ids. Resolve the one unsafe id at
-- launch time rather than rewriting player data, so saves made by older builds
-- recover automatically and actual Havoc missions remain untouched.
local CURSE_REPLACEMENTS = {
	mutator_havoc_tougher_skin = "pilgrim_tougher_skin",
	-- The shipped Havoc circumstance still contains
	-- mutator_armored_bombers, which no longer exists in the current
	-- MutatorTemplates registry. A first-leg curse bypasses stacked_for's
	-- dead-name filter, so route it through an Adventure-safe copy too.
	mutator_havoc_sticky_poxbursters = "pilgrim_sticky_poxbursters",
}

-- v0.24.1: mutator-level replacements applied when building the stacked
-- circumstance's union. Covers RUNS ALREADY IN FLIGHT whose stored curse
-- list still says common_minion_on_fire: with stacking on (the default)
-- the leg launches our synthetic template, so swapping the lethal
-- mutator here fixes existing saves without touching their stored names.
local MUTATOR_REPLACEMENTS = {
	mutator_common_minions_on_fire = "pilgrim_minions_on_fire",
	mutator_tough_skin_enemies = "pilgrim_tough_skin_enemies",
}

local function _register_custom_mutators()
	local ok, MutatorTemplates = pcall(require, "scripts/settings/mutator/mutator_templates")
	if not ok or type(MutatorTemplates) ~= "table" then return end

	-- Preserve Fatshark's current breed-chance table and minion-mutator class;
	-- only replace the buff whose start function requires a Havoc rank.
	local original = MutatorTemplates.mutator_tough_skin_enemies
	local random = type(original) == "table" and original.random_spawn_buff_templates
	local chances = type(random) == "table" and random.breed_chances or {}
	CUSTOM_MUTATOR_TEMPLATES.pilgrim_tough_skin_enemies = {
		class = (type(original) == "table" and original.class)
			or "scripts/managers/mutator/mutators/mutator_minion_nurgle_blessing",
		random_spawn_buff_templates = {
			buffs = { "pilgrim_toughened_skin" },
			breed_chances = chances,
		},
	}
	for name, template in pairs(CUSTOM_MUTATOR_TEMPLATES) do
		if not MutatorTemplates[name] then MutatorTemplates[name] = template end
	end
end

local CUSTOM_CURSE_TEMPLATES = {
	pilgrim_serpent_below = { mutators = {} },

	-- v0.24.1: Shambling Pyres, now safe. See CUSTOM_MUTATOR_TEMPLATES
	-- above for the crash this replaces. ui nil per the custom-curse
	-- shape; the catalogue label owns display.
	pilgrim_shambling_pyres = {
		mutators = { "pilgrim_minions_on_fire" },
	},

	-- Safe Adventure-mode equivalent of the Havoc Tougher Skin
	-- circumstance. Presentation continues to come from the catalogue's
	-- existing Tougher Skin row.
	pilgrim_tougher_skin = {
		mutators = { "pilgrim_tough_skin_enemies" },
	},

	-- Keep the live Sticky Poxburster mutator and drop the retired armored
	-- bomber companion mutator. This is used even on assignment one, before
	-- curse stacking has a reason to build pilgrimage_stacked.
	pilgrim_sticky_poxbursters = {
		mutators = { "mutator_havoc_sticky_poxburster" },
	},

	-- v0.22.99: AURIC INTENSITY (Kaizen 2026-08-11). Unlike the serpent
	-- this one is pure vanilla machinery: the exact mutator bundle the
	-- game's Auric mission board variants carry (verified against dt-src
	-- 1.12.3; the high_/_more_resistance circumstance variants all ship
	-- {add_resistance, increase_terror_event_points, reduced_ramp_
	-- duration(_low), auric_tension_modifier}), plus mutator_enable_auric
	-- (Havoc's is_auric flag on the PacingManager, mutator_havoc_
	-- templates.lua) so engine systems that key on is_auric see a true
	-- Auric mission. All five names live in template files pulled by the
	-- game's MutatorTemplates aggregator, so they resolve outside their
	-- home game modes. reduced_ramp_duration_low (x0.75) is the
	-- regular-Auric-board grade; Auric Maelstrom uses the full
	-- mutator_reduced_ramp_duration (x0.5), kept as a tuning option for
	-- the economy/difficulty pass. ui stays nil per the custom-curse
	-- shape; the catalogue label owns all Pilgrimage-side display.
	pilgrim_auric_intensity = {
		mutators = {
			"mutator_add_resistance",
			"mutator_increase_terror_event_points",
			"mutator_reduced_ramp_duration_low",
			"mutator_auric_tension_modifier",
			"mutator_enable_auric",
		},
	},
}

-- v0.22.99: curses that are ALWAYS ON for a given War Plan, applied on
-- top of the rolled per-leg curses (they never consume a leg's roll and
-- never count against the severity budget). war_plans.generate_route
-- passes the same list into assign() as an exclusion so the roll cannot
-- waste a leg on a curse the plan already guarantees; reroll_for_leg
-- excludes them the same way; stacked_for folds them into every leg's
-- stacked circumstance. "saint" is pre-wired for the future fifth plan.
M.FORCED_BY_PLAN = {
	martyr = { "pilgrim_auric_intensity" },
	saint  = { "pilgrim_auric_intensity" },
}

-- Forced curses for a plan id, filtered to templates that actually exist
-- on this build (same graceful degradation as pool()).
function M.forced_for_plan(plan_id)
	local forced = plan_id and M.FORCED_BY_PLAN[plan_id]
	if type(forced) ~= "table" then return {} end
	local out = {}
	for i = 1, #forced do
		local name = forced[i]
		if _templates == nil or _templates[name] ~= nil then
			out[#out + 1] = name
		end
	end
	return out
end

-- Forced curses for the ACTIVE run (empty when no run or the run's plan
-- forces nothing). Safe against a missing run_state wire.
function M.forced_for_run()
	if not _run_state or type(_run_state.get) ~= "function" then return {} end
	local ok, state = pcall(_run_state.get)
	if not ok or type(state) ~= "table" or not state.active then return {} end
	return M.forced_for_plan(state.plan_id)
end

function M.receive_templates(templates)
	if type(templates) == "table" then _templates = templates end
	if _templates then
		for name, template in pairs(CUSTOM_CURSE_TEMPLATES) do
			if not _templates[name] then _templates[name] = template end
		end
	end
	-- v0.24.1: mutator registration rides the same per-VM arrival, so a
	-- fresh Lua VM (every level load) gets pilgrim_minions_on_fire back
	-- before the mutator manager resolves the mission's mutator list.
	_register_custom_mutators()

	-- A level load rebuilds the game's Lua VM, so a fresh CircumstanceTemplates
	-- table arrives WITHOUT the synthetic stacked circumstance a mid-run launch
	-- depends on. Re-register it the moment the new table reaches us, rebuilt
	-- from the settings-persisted run. Without this, every assignment from 2 on
	-- launches under a name the engine cannot find and falls back to "default":
	-- a mission with no curse at all, discovered by Kaizen as half a mission of
	-- "Heinous Rituals" with no daemonhosts in it.
	pcall(M.ensure_registered)
end

-- Rebuilds and registers the stacked circumstance for the CURRENT run state, if
-- the run needs one. Safe to call at any time; declines exactly like stacked_for.
-- Called on template arrival (above) and by mutator_guard as a last resort in
-- case the engine consumes the name before the fanout has fired.
function M.ensure_registered()
	if not _run_state or type(_run_state.curse_prefix) ~= "function" then return nil end
	local prefix = _run_state.curse_prefix()
	if not prefix then return nil end
	return M.stacked_for(prefix)
end

-- ---------------------------------------------------------------------------
-- The catalogue
--
-- severity 1 is a nuisance, 2 changes how you play the leg, 3 is the reason the run
-- ends. label is the DISPLAYED name and always wins: several of these circumstances
-- ship with dev-placeholder localization ("Circumstance more specials"), so the
-- game's own strings cannot be trusted. Localize is only a fallback for names
-- outside this catalogue.
--
-- havoc = true marks entries borrowed from Havoc's template file. They are ordinary
-- circumstances structurally, but they have only ever shipped inside Havoc missions,
-- so they are the most likely to misbehave in a normal one. The setting
-- curses_havoc_pool switches them off in one place if they do.
-- ---------------------------------------------------------------------------

-- Labels are the names players already know, taken from the mission board, the
-- Maelstrom modifier lists and the Havoc UI, verified against the circumstance
-- templates (which mutators each internal name actually runs). Three of these
-- circumstances (snipers, poxwalker bombers, mutants) never shipped standalone;
-- in the game files they borrow Hunting Grounds' entire UI block, so their
-- "known" names come from the shipped conditions built on the same mutators.
-- v0.20.3: catalogue expansion.
--
-- Three flag kinds sit on each entry:
--   havoc      This is a Havoc rotator (mutator_havoc_*). Always present in
--              the game. Gated by curses_havoc_pool setting.
--   live_event This came from a live-event template. May or may not still
--              have working mutators in the current shipping build; the
--              template exists (so M.pool() returns it), but individual
--              mutators inside it may be retired. Gated by
--              curses_live_event_pool. Set to false to isolate tests.
--
-- The v0.20.3 rebalance also moves Ventilation Purge and Shambling Pyres
-- down from severity 2 to severity 1 (Kaizen: "the more cosmetic ones
-- should go into tier ones"), and adds Dawn (`dawn_circumstance_template`,
-- pure lighting shift, zero mutators) as another tier 1 filler. Noir was
-- considered but pulled: black-and-white filter is severe enough to sit
-- behind a penance-unlock in the future permanent-unlock pool.
local CATALOGUE = {
	-- ===============================================================
	-- Severity 1: a tax. Novitiate lives here. Penitent starts here.
	-- ===============================================================

	{ name = "snipers_01",             severity = 1, label = "Sniper Gauntlet",
	  icon = "special_waves_03" },
	{ name = "poxwalker_bombers_01",   severity = 1, label = "Bubonic Bursters",
	  icon = "nurgle_manifestation_01" },
	{ name = "mutants_01",             severity = 1, label = "Waves of Mutants",
	  icon = "special_waves_02" },
	-- v0.20.3: was severity 2. Yellow visibility filter is a minor tax,
	-- not a "leg is about the curse" thing. Fits tier 1 in feel.
	{ name = "ventilation_purge_01",   severity = 1, label = "Ventilation Purge",
	  icon = "ventilation_purge_01" },
	-- v0.20.3: was severity 2. Cosmetic "enemies are on fire" visual.
	-- The game files point common_minion_on_fire at Nurgle Manifestation's
	-- icon.
	-- v0.24.1: repointed from the vanilla common_minion_on_fire
	-- circumstance to our safe custom one (see CUSTOM_MUTATOR_TEMPLATES;
	-- the vanilla mutator crashes every non-Havoc mission at load).
	{ name = "pilgrim_shambling_pyres",  severity = 1, label = "Shambling Pyres", havoc = true,
	  icon = "nurgle_manifestation_01" },
	-- v0.20.3 new: dawn. Confirmed zero-mutator, theme_tag only. Purely a
	-- lighting shift. No thematic icon match in the standalone icon set;
	-- shares the generic live-event glyph, which reads as "special mode"
	-- and is fine for a filler.
	{ name = "dawn",                   severity = 1, label = "Dawn Light",
	  icon = "content/ui/materials/icons/circumstances/live_event_01",
	  live_event = true },

	-- ===============================================================
	-- Severity 2: the leg is about the curse. Penitent's back end.
	-- Fanatic sits entirely here.
	-- ===============================================================

	-- v0.22.92: Pilgrimage's first CUSTOM curse (design session with
	-- Kaizen: friendly fire as a trade-off, traitor flavor). The
	-- template is registered by receive_templates above (zero
	-- mutators); the effect lives in Pilgrimage.lua: one bot in the
	-- warband, seeded from the run, gets SYMMETRIC friendly fire with
	-- the player. Their stray fire wounds you; yours wounds them; you
	-- are not told who it is. Curses stack for the rest of the run,
	-- so the serpent stays once rolled.
	{ name = "pilgrim_serpent_below",  severity = 2, label = "The Serpent Below",
	  icon = "content/ui/materials/icons/circumstances/live_event_01" },
	-- v0.22.99: the Auric board's intensity package as a rollable tier-2
	-- curse (Kaizen: "let's make it into a Tier 2 modifier"). ALSO always
	-- on for Martyr and Saint via FORCED_BY_PLAN above, where it never
	-- consumes the leg's roll. Icon: the Auric Maelstrom glyph.
	{ name = "pilgrim_auric_intensity", severity = 2, label = "Auric Intensity",
	  icon = "content/ui/materials/icons/circumstances/maelstrom_02" },
	{ name = "darkness_01",            severity = 2, label = "Power Supply Interruption",
	  icon = "darkness_01" },
	{ name = "more_specials_01",       severity = 2, label = "Shock Troop Gauntlet",
	  icon = "special_waves_01" },
	{ name = "hunting_grounds_01",     severity = 2, label = "Hunting Grounds",
	  icon = "hunting_grounds_01" },
	-- v0.20.3: renamed from "Endless Hordes". "Shamblerot Vectorium" is a
	-- Death Guard tabletop detachment name; ours is a pox-swarm surge, not
	-- genuinely endless. The live-event "Endless Hordes" (below, T2) is
	-- the actually-endless one, so it gets the direct name.
	{ name = "more_hordes_01",         severity = 2, label = "Shamblerot Vectorium",
	  icon = "more_resistance_01" },
	{ name = "mutator_stimmed_minions", severity = 2, label = "Contaminated Stimms", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_stimmed_minions" },
	-- v0.20.3 Havoc adds. In-game Havoc modifier names used directly
	-- where they exist. Kaizen renamed armored_infected -> "Infected 21st"
	-- for flavor (21st Moebian is the traitor regiment the armored
	-- infected represent thematically).
	--
	-- v0.20.4 icon polish: icons taken directly from
	-- havoc_circumstance_template.lua rather than pattern-generated.
	-- Fatshark reuses icons across modifiers (both duplicating_enemies
	-- and sticky_poxbursters point at nurgle_manifestation_01), so the
	-- paths do not always match the modifier name.
	{ name = "mutator_havoc_armored_infected", severity = 2, label = "Infected 21st", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_moebian21st" },
	{ name = "mutator_havoc_tougher_skin",    severity = 2, label = "Tougher Skin", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_skin" },
	{ name = "mutator_havoc_sticky_poxbursters", severity = 2, label = "Sticky Poxbursters", havoc = true,
	  icon = "nurgle_manifestation_01" },
	{ name = "mutator_encroaching_garden",    severity = 2, label = "Encroaching Garden", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_encroaching_garden" },
	{ name = "bolstering_minions_01",         severity = 2, label = "Bolstering Minions", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rampaging_enemies" },
	-- v0.20.3 Live-event adds. Names from Kaizen's naming pass.
	--
	-- v0.20.4 icon polish: every live-event template in Fatshark's source
	-- shares one generic icon ("live_event_01", an Inquisition "I"
	-- glyph). That made all our live-event curses look identical in the
	-- route view. We pick from the standalone circumstance icons that
	-- best match the modifier's THEME instead, using icon paths already
	-- proven-resident by other catalogue entries.
	-- v0.20.5 rename: was "Ordnance Cache". In-game testing showed the
	-- actual behavior is Cranial Corruption (mutator_headshot_parasite_enemies)
	-- plus enemies dropping shocktrooper grenades on death that push you
	-- back (mutator_drop_shocktrooper_grenade_on_death), plus extra
	-- shocktroopers, grenadiers, and poxbursters. Zero literal fire
	-- barrels involved; the "barrel" in the internal id is misleading.
	-- Kaizen: "Explosive Faith" fits the Nurgle-corruption plus explosive
	-- death-gift theme without pretending it's an ordnance dump.
	{ name = "barrel_grounds",         severity = 2, label = "Explosive Faith", live_event = true,
	  icon = "nurgle_manifestation_01" },
	{ name = "leftover",               severity = 2, label = "Nurgle's Faithful", live_event = true,
	  icon = "nurgle_manifestation_01" },
	{ name = "saints_core",            severity = 2, label = "Ministorum Saints", live_event = true,
	  icon = "content/ui/materials/icons/circumstances/live_event_01" },
	{ name = "endless_hordes",         severity = 2, label = "Endless Hordes", live_event = true,
	  icon = "more_resistance_01" },

	-- ===============================================================
	-- Severity 3: survive it. Martyr's back half.
	-- ===============================================================

	{ name = "toxic_gas_01",           severity = 3, label = "Toxic Gas",
	  icon = "nurgle_manifestation_01" },
	{ name = "assault_01",             severity = 3, label = "Assault",
	  icon = "assault_01" },
	{ name = "nurgle_manifestation_01", severity = 3, label = "Nurgle's Blessing",
	  icon = "nurgle_manifestation_01" },
	{ name = "more_monsters_01",       severity = 3, label = "Roaming Monstrosities",
	  icon = "more_resistance_01" },
	{ name = "flash_mission_01",       severity = 3, label = "Monstrous Specialists",
	  icon = "maelstrom_01" },
	{ name = "mutator_havoc_enemies_parasite_headshot", severity = 3, label = "Cranial Corruption", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_parasite" },
	{ name = "mutator_havoc_duplicating_enemies", severity = 3, label = "Duplicating Enemies", havoc = true,
	  icon = "nurgle_manifestation_01" },
	{ name = "mutator_havoc_chaos_rituals", severity = 3, label = "Heinous Rituals", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals" },
	-- v0.20.3 Havoc adds. v0.20.4: icons from source, not pattern-guessed.
	{ name = "mutator_havoc_rotten_armor",     severity = 3, label = "Rotten Armor", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor" },
	{ name = "mutator_havoc_enemies_corrupted", severity = 3, label = "Corrupted Enemies", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle" },
	{ name = "mutator_havoc_thorny_armor",     severity = 3, label = "Thorny Armor", havoc = true,
	  icon = "nurgle_manifestation_01" },
	{ name = "mutator_havoc_enraged",          severity = 3, label = "Enraged", havoc = true,
	  icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_final_toll" },
	-- v0.20.3 Live-event adds. v0.20.4: themed icons (see block above).
	-- Kaizen: "Barren should be Stripped Bare".
	{ name = "barren",                 severity = 3, label = "Stripped Bare", live_event = true,
	  icon = "content/ui/materials/icons/circumstances/live_event_01" },
	{ name = "abhuman_01",             severity = 3, label = "Ogryn's Fury", live_event = true,
	  icon = "special_waves_02" },
	{ name = "elite_army",             severity = 3, label = "Purge Detachment", live_event = true,
	  icon = "special_waves_01" },
	{ name = "rations_core",           severity = 3, label = "Stolen Rations", live_event = true,
	  icon = "assault_01" },
}

M.CATALOGUE = CATALOGUE

-- ---------------------------------------------------------------------------
-- Pool
--
-- Filtered at ask time rather than at load, because the templates arrive whenever the
-- game happens to require the file, and a name that does not exist on THIS build must
-- never reach the launcher: build_context would fall back to "default" silently and
-- the player would be promised a curse that never appears.
-- ---------------------------------------------------------------------------

local function _havoc_allowed()
	if not _mod then return true end
	local value = _mod:get("curses_havoc_pool")
	-- Unset means allowed. The setting exists to switch the Havoc borrowings OFF if
	-- they misbehave, not as a gate that must be found and enabled first.
	return value ~= false
end

-- v0.20.3: same shape as _havoc_allowed for the live-event pool.
-- Same policy: unset means allowed. Kaizen can turn this off in mod
-- options to isolate whether an in-game issue is coming from a
-- live-event curse whose mutators no longer resolve in the current
-- shipping build (retired between patches).
local function _live_event_allowed()
	if not _mod then return true end
	local value = _mod:get("curses_live_event_pool")
	return value ~= false
end

-- Returns { [1] = {entries of severity 1}, [2] = ..., [3] = ... } containing only
-- curses this build actually has. verified=false in the result marks the situation
-- where the template table has not arrived yet and existence cannot be checked.
function M.pool()
	local by_severity = { {}, {}, {} }
	local verified = _templates ~= nil

	for i = 1, #CATALOGUE do
		local entry = CATALOGUE[i]
		local allowed = true
		if entry.havoc and not _havoc_allowed() then allowed = false end
		if entry.live_event and not _live_event_allowed() then allowed = false end
		local exists = not verified or _templates[entry.name] ~= nil

		if allowed and exists then
			local bucket = by_severity[entry.severity]
			bucket[#bucket + 1] = entry
		end
	end

	return by_severity, verified
end

-- ---------------------------------------------------------------------------
-- Assignment
--
-- Own PRNG, same LCG shape missions.lua uses, so the assignment is deterministic from
-- the run seed alone and reproducible across game restarts. Not shared with
-- missions.lua on purpose: drawing from one stream would mean adding a curse changes
-- which MISSIONS a seed produces, and every seed anyone has ever shared would break.
-- ---------------------------------------------------------------------------

local PRNG_MULTIPLIER = 1103515245
local PRNG_INCREMENT = 12345
local PRNG_MODULUS = 2147483648

local function _stir(x)
	x = (x * PRNG_MULTIPLIER + PRNG_INCREMENT) % PRNG_MODULUS
	x = math.floor(x / 65536) + (x % 65536) * 32768
	return x % PRNG_MODULUS
end

local function _next(seed, count)
	local stirred = _stir(seed)
	if count < 1 then return stirred, 1 end
	return stirred, 1 + math.floor((stirred / PRNG_MODULUS) * count)
end

-- Which severity a given leg deserves.
--
-- v0.20.3: replaced the old ratio-based ramp (leg-1 / total-1 mapped to
-- fixed tier cutoffs) with a plan-driven range. The War Plan says "this
-- run draws from tiers min..max", and legs interpolate linearly across
-- that range. A flat plan (min == max) always returns that tier.
--
-- Kaizen's reasoning: before, Novitiate (2 legs) rolled leg 1 at tier 1
-- and leg 2 at tier 3 because leg 2 was ratio 1.0. The plan is what
-- decides the difficulty band, not the leg index within an arbitrary
-- run length.
--
-- Legacy signature (leg, total) with no tier args is preserved as a
-- fallback so callers that never learned about tier ranges still get
-- the old ramp shape rather than crashing.
local function _severity_for(leg, total, min_tier, max_tier)
	if min_tier and max_tier then
		if min_tier == max_tier then return min_tier end
		local span = max_tier - min_tier + 1
		local index = math.floor((leg - 1) * span / math.max(total, 1))
		if index >= span then index = span - 1 end
		return min_tier + index
	end

	-- Pre-v0.20.3 fallback.
	if total <= 1 then return 2 end
	local ratio = (leg - 1) / (total - 1)
	if ratio < 0.34 then return 1 end
	if ratio < 0.75 then return 2 end
	return 3
end

M.severity_for = _severity_for

-- Returns a list of curse names, one per leg, or names of "default" where the pool has
-- nothing to offer (empty catalogue on this build, everything filtered out).
--
-- No repeats until a severity bucket is exhausted, because drawing Darkness three
-- times in one run reads as a bug even when the dice were fair.
-- v0.22.99: optional exclude_set (array of names or {name=true} set).
-- war_plans passes the plan's forced_curses here so a Martyr leg can
-- never roll Auric Intensity, which the plan already guarantees; that
-- roll would otherwise be a wasted slot. Excluded names are dropped
-- from BOTH the fresh pass and the bucket-exhausted fallback, because
-- a forced curse repeating via the fallback is exactly as wasted.
function M.assign(leg_count, seed, min_tier, max_tier, exclude_set)
	leg_count = math.max(1, math.min(leg_count or 3, 20))

	local exclude = {}
	if type(exclude_set) == "table" then
		for k, v in pairs(exclude_set) do
			if type(k) == "string" and v == true then
				exclude[k] = true
			elseif type(v) == "string" and v ~= "" and v ~= "default" then
				exclude[v] = true
			end
		end
	end

	local by_severity = M.pool()
	local out = {}
	local used = {}
	local x = _stir((seed or 0) + 5501)

	for leg = 1, leg_count do
		local severity = _severity_for(leg, leg_count, min_tier, max_tier)

		-- Collect what is drawable at this severity, preferring unused. Falling DOWN a
		-- tier when a bucket is empty, never up: a build missing its nasty circumstances
		-- should get an easier run, not a harder one.
		local picked = nil
		for tier = severity, 1, -1 do
			local bucket = by_severity[tier]

			local eligible = {}
			for i = 1, #bucket do
				if not exclude[bucket[i].name] then eligible[#eligible + 1] = bucket[i] end
			end

			local fresh = {}
			for i = 1, #eligible do
				if not used[eligible[i].name] then fresh[#fresh + 1] = eligible[i] end
			end
			local candidates = (#fresh > 0) and fresh or eligible

			if #candidates > 0 then
				local index
				x, index = _next(x, #candidates)
				picked = candidates[index]
				break
			end
		end

		if picked then
			used[picked.name] = true
			out[leg] = picked.name
		else
			out[leg] = "default"
		end
	end

	return out
end

-- v0.20.0: single-leg reroll for the Emporium's Reroll Condition SKU.
--
-- The whole-run assign() cannot be reused for this because it's stateful
-- across legs (used-set forbids repeats). A reroll of leg N should not
-- consult what legs N+1... would draw, and must be reproducible from the
-- same (run_seed, leg) pair so the same purchase in a shared-seed run
-- always lands on the same replacement.
--
-- The re-seed mixes the run seed with the leg number and a distinct salt
-- so a reroll cannot happen to produce the SAME curse the leg already had
-- unless the pool is degenerate at that severity.
-- v0.20.3: takes the same (min_tier, max_tier) the run's plan uses, so
-- a reroll on Novitiate cannot accidentally hand you a tier-3 curse.
-- Callers that don't know the range (legacy) get the pre-v0.20.3
-- ratio-based fallback via _severity_for's own guard.
-- v0.22.35: accepts an optional `exclude_set` of curse names that
-- shouldn't be picked (curses already present in the run's queue).
-- Kaizen reported the reroll landing on Explosive Faith when Explosive
-- Faith was already the prior leg's curse; letting the reroll produce
-- a duplicate defeats the purpose of stacking. Now we walk the tier
-- from severity down and skip any candidate whose name is in the
-- exclude set; if a whole tier gets excluded, we drop to the next
-- tier. Falls back to "default" only if every tier of every eligible
-- curse is already taken, which should be vanishingly rare with the
-- 138-entry pool.
function M.reroll_for_leg(run_seed, leg, min_tier, max_tier, total, exclude_set)
	total = math.max(total or leg or 1, 1)
	local severity = _severity_for(leg or 1, total, min_tier, max_tier)

	local by_severity = M.pool()

	-- Salt chosen so run 42 leg 2 does not collide with run 44 leg 0.
	-- 5501 is what assign() uses; 8807 is a different arbitrary prime.
	local x = _stir((run_seed or 0) + (leg or 1) * 8807 + 4813)

	-- Normalise exclude_set. Accept either a set-style table
	-- ({name = true}) or an array of names; internal code paths use
	-- an array (run_state.curse_queue), so translate here.
	local exclude = {}
	if type(exclude_set) == "table" then
		for k, v in pairs(exclude_set) do
			if type(k) == "string" and v == true then
				exclude[k] = true
			elseif type(v) == "string" and v ~= "" and v ~= "default" then
				exclude[v] = true
			end
		end
	end

	-- v0.22.99: a reroll must never land on a curse the run's plan
	-- already forces (Martyr/Saint Auric Intensity); that would waste
	-- the purchase exactly like rerolling onto a stacked duplicate.
	local forced = M.forced_for_run()
	for i = 1, #forced do
		exclude[forced[i]] = true
	end

	for tier = severity, 1, -1 do
		local bucket = by_severity[tier]
		if bucket and #bucket > 0 then
			-- Build a filtered view of this tier that skips excluded
			-- names. Kept per-tier so we naturally drop to the next
			-- tier when a whole one is exhausted.
			local filtered = {}
			for i = 1, #bucket do
				if not exclude[bucket[i].name] then
					filtered[#filtered + 1] = bucket[i]
				end
			end
			if #filtered > 0 then
				local index
				x, index = _next(x, #filtered)
				return filtered[index].name
			end
		end
	end

	return "default"
end

-- ---------------------------------------------------------------------------
-- Presentation
-- ---------------------------------------------------------------------------

local function _catalogue_entry(name)
	-- The safe Adventure-mode replacement keeps the original catalogue row
	-- for labels, severity and icon presentation.
	if name == "pilgrim_tougher_skin" then
		name = "mutator_havoc_tougher_skin"
	end
	for i = 1, #CATALOGUE do
		if CATALOGUE[i].name == name then return CATALOGUE[i] end
	end
	return nil
end

-- A short human name. OUR label first, the game's localization only as a fallback for
-- a name outside the catalogue.
--
-- The order used to be the other way round, and Kaizen's first screenshot showed why
-- that was wrong: several of these circumstances have never been player-facing, so
-- their "localization" is a dev placeholder. more_specials_01 rendered as literally
-- "Circumstance more specials". A string existing in the loc table says nothing about
-- it being fit to print. We curate all eighteen labels, so the curated label wins.
--
-- "default" renders as empty, because an uncursed assignment should say nothing rather
-- than "Curse: default".
function M.display_name(name)
	if not name or name == "" or name == "default" then return "" end
	name = CURSE_REPLACEMENTS[name] or name

	local entry = _catalogue_entry(name)
	if entry then return entry.label end

	local template = _templates and _templates[name]
	local loc_key = template and template.ui and template.ui.display_name

	local Localize = rawget(_G, "Localize")
	if loc_key and loc_key ~= "" and type(Localize) == "function" then
		local ok, text = pcall(Localize, loc_key)
		if ok and type(text) == "string" and text ~= "" and text:sub(1, 1) ~= "<" then
			return text
		end
	end

	return tostring(name)
end

function M.severity_of(name)
	name = CURSE_REPLACEMENTS[name] or name
	local entry = _catalogue_entry(name)
	return entry and entry.severity or 0
end

-- The icon material the terminal draws next to an assignment, a MATERIAL path
-- like "content/ui/materials/icons/circumstances/hunting_grounds_01".
--
-- CURATED FIRST, exactly like the labels, and for the same reason: the game's
-- template icons lie. snipers/poxwalker_bombers/mutants borrow Hunting Grounds'
-- whole ui block (a hound icon on a Poxburster curse, which Kaizen spotted
-- immediately), more_witches wears darkness_01, more_specials wears the literal
-- "placeholder" triangle. Each catalogue entry names the shipped icon that fits
-- what the curse DOES; the template's ui.icon is only a fallback for names
-- outside the catalogue. Callers still probe residency before drawing; a missing
-- material is an engine assert, not a placeholder. Returns nil for "default" and
-- unknown names.
local CIRCUMSTANCE_ICON_BASE = "content/ui/materials/icons/circumstances/"

function M.icon(name)
	if not name or name == "" or name == "default" then return nil end
	local original_name = name
	name = CURSE_REPLACEMENTS[name] or name

	local entry = _catalogue_entry(name)
	if not entry and original_name ~= name then entry = _catalogue_entry(original_name) end
	if entry and type(entry.icon) == "string" and entry.icon ~= "" then
		-- A full content path (a status TEXTURE rather than a circumstance
		-- material) passes through untouched; short names are circumstance
		-- material stems.
		if entry.icon:find("content/", 1, true) == 1 then return entry.icon end
		return CIRCUMSTANCE_ICON_BASE .. entry.icon
	end

	local template = _templates and _templates[name]
	local ui = template and template.ui

	if type(ui) ~= "table" then return nil end
	if type(ui.icon) == "string" and ui.icon ~= "" then return ui.icon end

	return nil
end

function M.exists(name)
	if name == "default" then return true end
	if not _templates then return nil end
	name = CURSE_REPLACEMENTS[name] or name
	return _templates[name] ~= nil
end

function M.launchable_name(name)
	return CURSE_REPLACEMENTS[name] or name
end

-- ---------------------------------------------------------------------------
-- Stacking
--
-- Kaizen's rule: curses accumulate across the run the way boons do. Assignment 3
-- runs its own curse PLUS the mutators of assignments 1 and 2.
--
-- The engine gives a mission exactly ONE circumstance slot, but the slot is not
-- the limit: MutatorManager._load_mutators has a Havoc branch that walks a LIST
-- of circumstances and appends every template's mutators into one load
-- (mutator_manager.lua:30-42). Stacking multiple circumstances' mutators is a
-- supported engine path; only the front door takes a single name.
--
-- So we go through the front door with a SYNTHETIC circumstance: before each
-- launch, register a template under our own name whose mutator list is the
-- deduped union of every curse up to the current assignment, wearing the CURRENT
-- curse's ui/audio/dialogue (the newest curse defines the leg's ambience).
-- Registration mutates the CircumstanceTemplates table itself, which is safe and
-- sufficient because require caches: the table we received through the fanout is
-- the same object MutatorManager reads (mutator_manager.lua:3). One reusable
-- name, re-registered before every launch, because only one mission runs at a
-- time, and re-registered on demand after a game restart because the launcher
-- asks for it on every resume.
-- ---------------------------------------------------------------------------

M.STACKED_NAME = "pilgrimage_stacked"

-- Fatshark's navigation plugin reproducibly crashes in fm_cargo's opening
-- foundry section when More Hordes is stacked on top of Auric Intensity. Two
-- different run seeds failed in the same native gwnav call path after paired
-- 60-70 enemy far-vector waves and repeated ambush waves. Keep the saved curse
-- and every other mutator intact, but omit this one mutator on this one map.
-- The exclusion is evaluated while building the synthetic template, so it also
-- protects an already-active run the next time that leg launches.
local MISSION_MUTATOR_EXCLUSIONS = {
	fm_cargo = {
		mutator_more_hordes = true,
	},
}

local _last_stack = nil

function M.stacking_enabled()
	if not _mod or type(_mod.get) ~= "function" then return true end
	local ok, value = pcall(_mod.get, _mod, "curses_stacking")
	if not ok or value == nil then return true end
	return value == true
end

-- The list of real, launchable curses inside a run prefix. Exposed separately so
-- the mission banner and the debug command can agree with the launcher about
-- what is actually stacked.
function M.stack_curses(curse_list)
	if type(curse_list) ~= "table" then return {} end
	local real = {}
	for i = 1, #curse_list do
		local name = curse_list[i]
		name = CURSE_REPLACEMENTS[name] or name
		if type(name) == "string" and name ~= "" and name ~= "default"
			and _templates and _templates[name] then
			real[#real + 1] = name
		end
	end
	return real
end

-- Builds and registers the synthetic stacked circumstance for a run prefix (the
-- curses of assignments 1..current, in order). Returns the registered name, or
-- nil when the plain single-circumstance path is correct instead: stacking off,
-- templates not arrived, fewer than two real curses in play, or nothing to run.
function M.stacked_for(curse_list, extras)
	_last_stack = nil

	if not M.stacking_enabled() then return nil end
	if not _templates then return nil end

	local real = M.stack_curses(curse_list)

	-- v0.22.99: fold the run's plan-forced curses (Martyr/Saint Auric
	-- Intensity) into every leg's stack. Inserted at the FRONT of the
	-- list so real[#real] (the current leg's rolled curse) keeps
	-- ownership of the leg's ui/audio/dialogue; the union loop below
	-- walks newest-first, so front position just appends the forced
	-- mutators after the rolled ones. Deduped in case the same curse
	-- was also rolled earlier in the run (possible on pre-v0.22.99
	-- routes or via lower plans, where it is a normal roll).
	local forced = M.forced_for_run()
	local forced_present = false
	if #forced > 0 then
		local have = {}
		for i = 1, #real do have[real[i]] = true end
		for i = #forced, 1, -1 do
			if not have[forced[i]] then
				table.insert(real, 1, forced[i])
				have[forced[i]] = true
				forced_present = true
			end
		end
	end

	-- v0.18.0: even with 0 or 1 real curses in the queue, we still build
	-- pilgrimage_stacked if `extras` carry a scaling modifier that the
	-- launcher wants applied (above-Damnation enemy HP). Historically we
	-- required >=2 curses because there was nothing to add otherwise.
	-- v0.22.99: a plan-forced curse also justifies the build on its own
	-- (a curse_skip leg on Martyr still runs Auric Intensity).
	local health_modifier = extras and extras.minion_health_modifier or nil

	if #real < 2 and not health_modifier and not forced_present then return nil end

	-- Fall back to the first real curse when there IS only one, or to the
	-- previous default when there is none. current_template ends up nil in
	-- the zero-curse case, so every read from it is guarded below.
	local current = real[#real]
	local current_template = current and _templates[current] or nil

	-- Union, first-seen order, so the current curse's own mutators keep the
	-- positions the game would have given them and earlier curses append after.
	--
	-- v0.22.47: filter every mutator name against the game's live
	-- MutatorTemplates table before including it. When Fatshark removes or
	-- renames a mutator between patches (e.g. `mutator_armored_bombers` in
	-- 2026-08-08's patch — still referenced by the Havoc circumstance
	-- template we borrow from, but no longer registered), the game's own
	-- _load_mutators loop crashes with "attempt to index local
	-- 'mutator_template' (a nil value)" at mutator_manager.lua:52
	-- (Fatshark has no defensive nil check on `MutatorTemplates[name]`).
	-- Skipping the dead names here is safer than passing them through:
	-- we lose one mutator's effect but keep the mission playable.
	local MutatorTemplates
	do
		local ok, m = pcall(require, "scripts/settings/mutator/mutator_templates")
		-- An EMPTY table means we're running in the test harness (or the
		-- require stub) and can't actually validate names; treat it the
		-- same as require failing entirely and fail open. Only when the
		-- table both loaded AND has entries do we trust it enough to
		-- drop unknowns.
		if ok and type(m) == "table" and next(m) ~= nil then
			MutatorTemplates = m
		end
	end
	local dropped = {}
	local mutators, seen = {}, {}
	local mission_name = extras and extras.mission_name
	local mission_exclusions = mission_name and MISSION_MUTATOR_EXCLUSIONS[mission_name]
	local excluded = {}
	for i = #real, 1, -1 do
		local list = _templates[real[i]].mutators
		if type(list) == "table" then
			for j = 1, #list do
				local mutator = list[j]
				-- v0.24.1: swap known-lethal mutators for our safe
				-- equivalents BEFORE dedupe/existence checks, so runs
				-- started before the fix stop crashing on their next leg.
				mutator = MUTATOR_REPLACEMENTS[mutator] or mutator
				if not seen[mutator] then
					seen[mutator] = true
					if mission_exclusions and mission_exclusions[mutator] then
						excluded[#excluded + 1] = mutator
					-- Only reject when we successfully loaded the registry
					-- AND the name is definitively absent. If the require
					-- failed for any reason we let the mutator through
					-- rather than silently swallowing everything (fail
					-- open on unknown, fail closed on known-missing).
					elseif MutatorTemplates and MutatorTemplates[mutator] == nil then
						dropped[#dropped + 1] = mutator
					else
						mutators[#mutators + 1] = mutator
					end
				end
			end
		end
	end
	if #dropped > 0 and _debug_log then
		_debug_log("curses_stacked_dropped", 0,
			"dropped " .. #dropped .. " unknown mutator(s) from stacked template: "
			.. table.concat(dropped, ", "), 60, "warn")
	end
	if #excluded > 0 and _debug_log then
		_debug_log("curses_stacked_map_exclusion", 0,
			"excluded " .. table.concat(excluded, ", ") .. " from "
			.. tostring(mission_name) .. " after a reproducible native navigation crash",
			60, "warn")
	end

	-- If mutators is empty AND no scale is being applied, there is nothing
	-- worth stacking (would produce a plain "default" outcome). Bail so the
	-- launcher takes the plain single-curse path.
	if #mutators == 0 and not health_modifier then return nil end

	local template = {
		mutators = mutators,
		ui = current_template and current_template.ui or nil,
		theme_tag = current_template and current_template.theme_tag or nil,
		wwise_state = current_template and current_template.wwise_state or nil,
		wwise_event_init = current_template and current_template.wwise_event_init or nil,
		wwise_event_stop = current_template and current_template.wwise_event_stop or nil,
		dialogue_id = current_template and current_template.dialogue_id or nil,
		-- Only the current curse's mission overrides. Merging overrides from
		-- every stacked curse is undefined territory (two curses could disagree
		-- about the same field); the newest curse wins whole.
		mission_overrides = current_template and current_template.mission_overrides or nil,
	}

	-- v0.18.0: the difficulty ramp's enemy HP scaling. The coop game mode
	-- reads circumstance_template.minion_health_modifier[challenge] on every
	-- minion spawn (minion_spawn_manager.lua:126). Writing it here scales
	-- every enemy at that challenge by the given percentage. Attack speed
	-- rides a separate hook (scaling_hook.lua).
	if health_modifier then
		template.minion_health_modifier = health_modifier
	end

	_templates[M.STACKED_NAME] = template

	_last_stack = {
		name = M.STACKED_NAME,
		curses = real,
		mutators = mutators,
		health_modifier = health_modifier,
	}

	-- Native navigation crashes do not leave a Lua call stack. Record the exact
	-- mission, curse and mutator composition once when the synthetic circumstance
	-- is built, so a user's ordinary console log can distinguish two visually
	-- identical `pilgrimage_stacked` missions without enabling verbose tracing.
	if _mod and type(_mod.info) == "function" then
		local curse_text = #real > 0 and table.concat(real, ",") or "none"
		local mutator_text = #mutators > 0 and table.concat(mutators, ",") or "none"
		local health_text = health_modifier and tostring(health_modifier) or "none"
		pcall(_mod.info, _mod,
			"[PilgrimageStack] mission=%s curses=%s mutators=%s health=%s",
			tostring(mission_name or "unknown"), curse_text, mutator_text, health_text)
	end
	return M.STACKED_NAME
end

-- What the last stacked_for call built, or nil when it declined. The banner and
-- /pil_stack read this; it is intentionally cleared on every call so stale data
-- from a previous leg cannot leak into the next.
function M.last_stack()
	return _last_stack
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

function M.status()
	local by_severity, verified = M.pool()
	return {
		templates_loaded = _templates ~= nil,
		verified = verified,
		pool_1 = #by_severity[1],
		pool_2 = #by_severity[2],
		pool_3 = #by_severity[3],
		catalogue = #CATALOGUE,
		havoc_allowed = _havoc_allowed(),
	}
end

return M
