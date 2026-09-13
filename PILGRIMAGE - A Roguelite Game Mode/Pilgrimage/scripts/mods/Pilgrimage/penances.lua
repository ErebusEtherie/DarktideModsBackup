-- penances.lua
--
-- Pilgrimage's own achievement system. Event-driven, persistent, feeds the
-- War Plans + preset unlock gates.
--
-- ===========================================================================
-- SCOPE
-- ===========================================================================
--
-- Penances are earned exactly once. Storage is a set of ids in settings; a
-- write is idempotent. On a triggering event, we walk the catalogue and
-- check each un-earned penance's condition. Any that pass are marked
-- earned, logged, and shown as notifications.
--
-- The game's OWN penance system is a separate thing on Fatshark's backend.
-- Nothing here talks to it: these are Pilgrimage-only, stored in our mod
-- settings, visible via /pil_penances and the Penances terminal tab.
--
-- ===========================================================================
-- TIER-INCLUSIVE RULE (v0.22.49, Session B)
-- ===========================================================================
--
-- Every penance that specifies a MINIMUM tier (e.g. "Complete Fanatic+")
-- must also fire on any harder tier. Kaizen: "Make sure all of these
-- penances are earnable at their designated tier and on harder ones too."
--
-- Implementation: penance.check reads data.plan_id and calls
-- `plan_at_least(data.plan_id, "fanatic")` rather than testing equality.
-- The tier ranking is defined in TIER_RANK below.
--
-- ===========================================================================
-- CLASS-NAME DISPLAY (v0.22.49)
-- ===========================================================================
--
-- Fatshark's internal archetype names are `adamant`, `broker`, `cryptic`.
-- The player-facing names are `Arbites`, `Hive Scum`, `Skitarii`. Any
-- penance description text uses the PUBLIC names via ARCHETYPE_PUBLIC.
--
-- ===========================================================================
-- SUB-PENANCES (v0.22.49)
-- ===========================================================================
--
-- Some penances are parents that unlock only when all their sub-penances
-- have been earned. Sub-penances are stored the same way as regular ones
-- (in KEY_EARNED) but the parent's `check` is a function that reads the
-- earned set and returns true when every sub-id has been earned.
--
-- Example: pilgrim_haneumann_parent (Discontinuing the Cycle) has two
-- subs: pilgrim_data_hymn (20 interrogators) and pilgrim_machine_spirit
-- (200 Voltaic Emitter disables). The parent's unlocks field points at
-- Magos Haneumann; when both subs are earned, the parent auto-grants on
-- the next observe pass, which fires the preset unlock.

local M = {}

local _mod
local _shared
local _event_log
local _run_state
local _wallet
local _shop
local _settings
-- Declared at the top (v0.14.1 boons lesson).
local _debug_log

local KEY_EARNED = "_penances_earned"

-- ===========================================================================
-- Constants
-- ===========================================================================

-- War Plan tier ranking. Higher = harder. Used by plan_at_least.
-- Values are ordinal; the actual gaps don't matter, only the ordering.
local TIER_RANK = {
	novitiate = 1,
	penitent  = 2,
	fanatic   = 3,
	-- v0.19.1 legacy: "zealot" was renamed to "fanatic". Old saves may still
	-- carry it in state; treat it as the same tier so a mid-transition run
	-- still triggers Fanatic-tier penances.
	zealot    = 3,
	martyr    = 4,
	saint     = 5,  -- reserved, unlocked by Orthus Vindicated
}
M.TIER_RANK = TIER_RANK

-- Fatshark internal archetype id → player-facing class name.
-- Used in penance description strings so a Skitarii penance isn't shown
-- to the player as "as cryptic".
local ARCHETYPE_PUBLIC = {
	veteran = "Veteran",
	zealot  = "Zealot",
	psyker  = "Psyker",
	ogryn   = "Ogryn",
	adamant = "Arbites",
	broker  = "Hive Scum",
	cryptic = "Skitarii",
}
M.ARCHETYPE_PUBLIC = ARCHETYPE_PUBLIC

function M.public_class_name(archetype_id)
	return ARCHETYPE_PUBLIC[tostring(archetype_id or "")] or tostring(archetype_id or "")
end

-- Tier-inclusive helper. Returns true when `plan_id` is `min_tier` or harder.
-- Both sides normalised via TIER_RANK; unknown ids fail closed (return false).
function M.plan_at_least(plan_id, min_tier)
	local have = TIER_RANK[tostring(plan_id or "")]
	local need = TIER_RANK[tostring(min_tier or "")]
	if not have or not need then return false end
	return have >= need
end

-- ===========================================================================
-- Catalogue
-- ===========================================================================
--
-- id: internal, stable, used for settings storage AND as the war_plan /
--     preset unlock key. Never rename an id: a saved earned penance would
--     appear locked again on next boot.
-- name / description: shown in reports and the terminal tab.
-- category: "war_plan" | "preset" | "shop" | "vanity". Drives UI grouping
--           and filter buttons in the Penances tab.
-- trigger: event name we listen for. See emitter list at file bottom.
-- check: function(data, ctx) -> boolean. `data` is the observe payload;
--        `ctx` is { earned_ids_set } so parent penances can read
--        sub-penance state without a second _load_earned() call.
-- unlocks: optional, informational for the UI. Not enforced here; the
--          consuming module (Preset.is_unlocked, War Plans, etc.) reads
--          our M.is_earned() directly.
-- subs: optional list of sub-penance ids. Only for parent penances.
--       When present, the parent auto-grants when every sub is earned;
--       don't also write a `check` for parents (subs mechanism handles it).

M.PENANCES = {

	-- =====================================================================
	-- War Plan progression (existing, kept from previous versions)
	-- =====================================================================

	-- v0.22.79: every penance now carries `unlocks_label`, a SHORT
	-- string for the Penances tab's condition column (~22 chars fit).
	-- The full description stays the click-to-inspect text. Kaizen's
	-- field feedback: "a lot of the penances don't say what they
	-- unlock".

	{
		id = "pilgrim_first_steps",
		name = "Pilgrim's First Steps",
		description = "Complete The Novitiate's Vow.",
		category = "war_plan",
		unlocks = "penitent",
		unlocks_label = "The Penitent's Path",
		trigger = "run_complete",
		check = function(data) return data.plan_id == "novitiate" end,
	},
	{
		id = "pilgrim_faithful",
		name = "Faithful Pilgrim",
		-- v0.28.52: the plan unlock stays here; the companion slot is
		-- represented separately by Sanctioned and migrated for old saves.
		description = "Complete The Penitent's Path.",
		category = "war_plan",
		unlocks = "fanatic",
		unlocks_label = "The Fanatic's Trial",
		trigger = "run_complete",
		check = function(data) return data.plan_id == "penitent" end,
	},
	{
		-- v0.19.1: name kept ("pilgrim_ascendant") so any earned penance
		-- from v0.19.0 stays valid.
		id = "pilgrim_ascendant",
		name = "Ascendant Pilgrim",
		-- v0.22.79: slot grant removed (slots redesign).
		description = "Complete The Fanatic's Trial.",
		category = "war_plan",
		unlocks = "martyr",  -- v0.22.49: corrected. Fanatic clear should unlock Martyr.
		unlocks_label = "The Martyr's Vigil",
		trigger = "run_complete",
		check = function(data)
			return data.plan_id == "fanatic" or data.plan_id == "zealot"
		end,
	},
	{
		id = "pilgrim_martyred",
		name = "The Martyred",
		description = "Complete The Martyr's Vigil. Peak pilgrim.",
		category = "war_plan",
		unlocks = nil,
		unlocks_label = "glory",
		trigger = "run_complete",
		check = function(data) return data.plan_id == "martyr" end,
	},

	-- =====================================================================
	-- Wallet
	-- =====================================================================

	{
		id = "pilgrim_flush",
		name = "Coffers Full",
		description = "Amass 1000 Ordos. Permanently increases all Ordos earnings by 5%.",
		category = "shop",
		unlocks_label = "+5% Ordos earnings",
		trigger = "wallet_update",
		check = function(data) return (data.balance or 0) >= 1000 end,
	},
	{
		id = "pilgrim_coffers_bursting",
		name = "Coffers Bursting",
		-- v0.22.79: the multiplier is now actually WIRED (wallet.lua
		-- applies it additively to every earn path).
		description = "Amass 5000 Ordos. Adds another 10% to all Ordos earnings, for 15% total with Coffers Full.",
		category = "shop",
		unlocks_label = "+10% Ordos earnings",
		trigger = "wallet_update",
		check = function(data) return (data.balance or 0) >= 5000 end,
	},

	-- =====================================================================
	-- Preset unlocks (Tier 3)
	-- =====================================================================
	--
	-- All tier-3 preset penances fire on run_complete. Higher tiers are
	-- accepted via plan_at_least. Archetype comparisons use INTERNAL ids
	-- (adamant/broker/cryptic) because that's what run_state stores; the
	-- description text uses the public names via ARCHETYPE_PUBLIC.

	{
		id = "pilgrim_unshakeable_faith",
		unlocks_label = "Sister Argenta",
		name = "Unshakeable Faith",
		description = "Complete a Fanatic+ pilgrimage as Zealot without ever being downed.",
		category = "preset",
		unlocks = "sister_argenta",
		trigger = "run_complete",
		check = function(data)
			if data.archetype ~= "zealot" then return false end
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			if data.ever_downed then return false end
			return true
		end,
	},

	-- Discontinuing the Cycle (parent for Haneumann). Auto-grants when
	-- both subs are earned; itself has no direct check function.
	{
		id = "pilgrim_haneumann_parent",
		unlocks_label = "Pasqal Haneumann",
		name = "Discontinuing the Cycle",
		description = "Complete both Data-Hymn and Machine Spirit Banishment.",
		category = "preset",
		unlocks = "magos_haneumann",
		trigger = "sub_penance_earned",
		subs = { "pilgrim_data_hymn", "pilgrim_machine_spirit" },
	},
	{
		id = "pilgrim_data_hymn",
		unlocks_label = "Discontinuing the Cycle",
		name = "Data-Hymn",
		description = "Complete 20 interrogations with your servo skulls, including those commanded by Skitarii bots.",
		category = "preset",
		trigger = "interrogator_hacked",
		check = function(data)
			return (data.total_interrogators_hacked or 0) >= 20
		end,
	},
	{
		id = "pilgrim_machine_spirit",
		unlocks_label = "Discontinuing the Cycle",
		name = "Machine Spirit Banishment",
		description = "Disable 200 ranged enemy weapons with your Voltaic Emitter or Arc Grenades.",
		category = "preset",
		-- v0.22.77: emitter WIRED. MinionState.apply_weapon_malfunction
		-- hook in Pilgrimage.lua counts ranged-breed disables while the
		-- human player is Skitarii; persistent counter in run_state.
		-- Counts the whole Skitarii electric arsenal (Discharge / Voltaic
		-- Emitter AND arc grenades); the seam carries no source info.
		trigger = "voltaic_weapon_disabled",
		check = function(data)
			return (data.total_voltaic_disables or 0) >= 200
		end,
	},

	{
		id = "pilgrim_dancing_on_the_web",
		unlocks_label = "Kibellah",
		name = "Dancing on the Web",
		description = "Complete a Martyr+ pilgrimage as Zealot while maintaining 3+ Martyrdom stacks for 80% of run time.",
		category = "preset",
		unlocks = "spinner_kibellah",
		trigger = "run_complete",
		check = function(data)
			if data.archetype ~= "zealot" then return false end
			if not M.plan_at_least(data.plan_id, "martyr") then return false end
			-- v0.22.77: emitter WIRED. The penance_time Tick task
			-- (bootstrap.lua) samples Martyrdom stacks once a second
			-- (recomputed from missing health segments, Fatshark's own
			-- formula) and run_state exposes martyrdom_time /
			-- active_time as martyrdom_time_pct in the snapshot.
			return (data.martyrdom_time_pct or 0) >= 0.8
		end,
	},

	{
		id = "pilgrim_warrant_served",
		unlocks_label = "Solomorne Anthar",
		name = "Warrant Served",
		description = "Complete a Fanatic+ pilgrimage as Arbites, dog credited with 50+ kills in the run.",
		category = "preset",
		unlocks = "solomorne",
		trigger = "run_complete",
		check = function(data)
			if data.archetype ~= "adamant" then return false end
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			-- v0.22.77: emitter WIRED. StatsManager record_private
			-- "hook_kill" events where the attacking unit's breed is
			-- companion_dog and the credited player is the local human.
			return (data.companion_kills or 0) >= 50
		end,
	},

	{
		id = "pilgrim_biolightning",
		unlocks_label = "Heinrix van Calox",
		name = "The Flesh Confesses",
		description = "Complete a Penitent+ pilgrimage as Psyker; electricity damage (Smite + kinetic staff + voltaic boons) is 30%+ of total run damage.",
		category = "preset",
		unlocks = "interrogator_heinrix",
		trigger = "run_complete",
		check = function(data)
			if data.archetype ~= "psyker" then return false end
			if not M.plan_at_least(data.plan_id, "penitent") then return false end
			-- v0.22.77: emitter WIRED. StatsManager record_private
			-- "hook_damage_dealt" events split by damage_type against
			-- the ELECTRIC_DAMAGE_TYPES set in Pilgrimage.lua (smite,
			-- electrocution, kinetic, arc_chain, shock family, ...).
			local elec = data.electricity_damage_dealt or 0
			local total = data.total_damage_dealt or 0
			if total <= 0 then return false end
			return (elec / total) >= 0.30
		end,
	},

	{
		id = "pilgrim_in_lord_captains_service",
		unlocks_label = "Abelard Werserian",
		name = "In Lord Captain's Service",
		description = "Complete a Fanatic+ mission (not run) without taking a single point of health damage.",
		category = "preset",
		unlocks = "seneschal_abelard",
		trigger = "mission_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			-- data.difficulty is the leg's danger name (uprising/malice/
			-- heresy/damnation). For a "Fanatic-tier mission" specifically,
			-- the mission's danger at play time must be Damnation (Fanatic's
			-- final ramp) or Damnation+ (Martyr and higher). Fall back to
			-- accepting plan_at_least("fanatic") if difficulty is missing.
			return (data.hp_damage_taken or 0) == 0
		end,
	},

	-- v0.22.80: Theodora and Idira unlock penances, specced by Kaizen
	-- 2026-08-10. Both thresholds flagged for the Ordos economy audit
	-- (Kaizen: "This number is subject to change, of course, in the
	-- economy pass").

	{
		id = "pilgrim_rogue_traders_fortune",
		name = "A Rogue Trader's Fortune",
		description = "Amass 20,000 Ordos, or spend a lifetime total of 20,000 Ordos. Wealth begets wealth.",
		category = "preset",
		unlocks = "theodora_von_valancius",
		unlocks_label = "Theodora von Valancius",
		trigger = "wallet_update",
		check = function(data)
			-- Either path: sitting on a fortune, or having burned one.
			if (data.balance or 0) >= 20000 then return true end
			return (data.total_spent or 0) >= 20000
		end,
	},

	{
		id = "pilgrim_unsanctioned_fury",
		name = "Unsanctioned Fury",
		description = "Complete a Fanatic+ mission as Psyker in which your Peril overload detonations destroyed 20 or more elite or specialist enemies.",
		category = "preset",
		unlocks = "idira_tlass",
		unlocks_label = "Idira Tlass",
		trigger = "mission_complete",
		check = function(data)
			if data.archetype ~= "psyker" then return false end
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.overload_elite_kills or 0) >= 20
		end,
	},

	{
		id = "pilgrim_silver_tongued",
		unlocks_label = "Jae Heydari",
		name = "Silver-Tongued",
		description = "Complete a Fanatic+ pilgrimage as Hive Scum without taking any ranged health damage.",
		category = "preset",
		unlocks = "princess_jae",
		trigger = "run_complete",
		check = function(data)
			if data.archetype ~= "broker" then return false end
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.ranged_hp_damage or 0) == 0
		end,
	},

	-- =====================================================================
	-- Tier 1/2 bot unlock scaffolding
	-- =====================================================================
	--
	-- Kaizen designing preset content per batch; these are the generic
	-- unlock triggers that specific presets can bind to. Each grants a
	-- preset slot's worth of choice, not a fixed preset. Preset content
	-- catalogue in preset.lua binds `unlock_penance` to these ids as it
	-- ships.

	{
		id = "pilgrim_first_recruit",
		unlocks_label = "Second Warband slot",
		name = "First Recruit",
		description = "Complete The Novitiate's Vow. Opens the second Warband slot.",
		category = "preset",
		trigger = "run_complete",
		check = function(data) return M.plan_at_least(data.plan_id, "novitiate") end,
	},
	{
		id = "pilgrim_second_recruit",
		unlocks_label = "Third Warband slot",
		name = "Second Recruit",
		description = "After completing Novitiate, own three different Living Tithe recruits. Opens the third Warband slot.",
		category = "preset",
		trigger = "recruit_update",
		check = function(data)
			if not M.is_earned("pilgrim_first_steps") then return false end
			return (data.tier1_owned or 0) >= 3
		end,
	},
	{
		id = "pilgrim_sanctioned",
		unlocks_label = "Fourth Warband slot",
		name = "Sanctioned",
		description = "Complete The Penitent's Path. Opens the fourth Warband slot.",
		category = "preset",
		trigger = "run_complete",
		check = function(data) return M.plan_at_least(data.plan_id, "penitent") end,
	},

	-- =====================================================================
	-- Warband slot unlocks
	-- =====================================================================
	--
	-- v0.28.52: slots 2-4 use First Recruit, Second Recruit and
	-- Sanctioned above. These two higher-tier Penances open slots 5 and 6.
	-- bots_slotted comes from the mission-start emitter recording
	-- Bots.spawn_target(), maxed across the run.

	{
		id = "pilgrim_full_muster",
		name = "Full Muster",
		description = "Complete a Fanatic+ pilgrimage with all four warband slots filled. Opens the fifth warband slot.",
		category = "preset",
		unlocks_label = "Fifth Warband slot",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.bots_slotted or 0) >= 4
		end,
	},
	{
		id = "pilgrim_emperors_six",
		name = "The Emperor Sends Six",
		description = "Complete a Martyr+ pilgrimage with five bots at your side. Opens the sixth and final warband slot.",
		category = "preset",
		unlocks_label = "Sixth Warband slot",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "martyr") then return false end
			return (data.bots_slotted or 0) >= 5
		end,
	},

	-- =====================================================================
	-- Meta / permanent unlocks
	-- =====================================================================

	{
		id = "pilgrim_the_devoted",
		unlocks_label = "Curse Reveal (soon)",
		name = "The Devoted",
		description = "Complete 10 Pilgrimage missions. Unlocks the Curse Reveal shop purchasable.",
		category = "shop",
		trigger = "mission_count",
		check = function(data) return (data.total_missions or 0) >= 10 end,
	},
	{
		id = "pilgrim_iron_will",
		unlocks_label = "Iconic slot (soon)",
		name = "Iron Will",
		description = "Complete a Martyr+ pilgrimage without buying a single shop item. Unlocks the Iconic bot slot.",
		category = "shop",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "martyr") then return false end
			return (data.shop_purchases or 0) == 0
		end,
	},
	{
		id = "pilgrim_zero_waste",
		unlocks_label = "bigger boon drafts",
		name = "Zero Waste",
		description = "Complete a Fanatic+ pilgrimage with 0 boons taken. Grants +1 to per-leg boon draft size.",
		category = "shop",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.boons_taken or 0) == 0
		end,
	},

	-- =====================================================================
	-- Vanity feats
	-- =====================================================================

	{
		id = "pilgrim_solo_sacrament",
		unlocks_label = "glory",
		name = "Solo Sacrament",
		description = "Complete a Fanatic+ pilgrimage with 0 bots slotted.",
		category = "vanity",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.bots_slotted or 0) == 0
		end,
	},
	{
		id = "pilgrim_curseborn",
		unlocks_label = "glory",
		name = "Curseborn",
		description = "Complete a Fanatic+ pilgrimage with 5+ curses stacked at run's end.",
		category = "vanity",
		trigger = "run_complete",
		check = function(data)
			if not M.plan_at_least(data.plan_id, "fanatic") then return false end
			return (data.curses_stacked or 0) >= 5
		end,
	},
	{
		id = "pilgrim_perfect_pilgrimage",
		unlocks_label = "glory",
		name = "The Perfect Pilgrimage",
		description = "Clear Martyr with 0 downs, 0 boons taken, all curses stacked (5+).",
		category = "vanity",
		trigger = "run_complete",
		check = function(data)
			if data.plan_id ~= "martyr" then return false end
			if data.ever_downed then return false end
			if (data.boons_taken or 0) > 0 then return false end
			return (data.curses_stacked or 0) >= 5
		end,
	},

	-- =====================================================================
	-- Saint tier gate
	-- =====================================================================

	{
		id = "pilgrim_orthus_vindicated",
		unlocks_label = "Saint War Plan",
		name = "Orthus Vindicated",
		description = "Clear the Orthus Offensive curated run. Unlocks the Saint War Plan + a permanent Ordos multiplier.",
		category = "war_plan",
		unlocks = "saint",
		-- v0.22.49: emitter NOT WIRED. Curated Runs system builds when
		-- Session (post-C) tackles it; when the ops-mechanism launch path
		-- exists, the Orthus completion will fire "curated_run_complete"
		-- with data.run_id == "orthus_offensive".
		trigger = "curated_run_complete",
		check = function(data) return data.run_id == "orthus_offensive" end,
	},
}

local _by_id = {}
for i = 1, #M.PENANCES do _by_id[M.PENANCES[i].id] = M.PENANCES[i] end

-- ===========================================================================
-- Storage
-- ===========================================================================

local function _load_earned()
	local raw = _mod and _mod:get(KEY_EARNED) or nil
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for id in string.gmatch(raw, "([^,]+)") do
		if _by_id[id] then out[id] = true end
	end
	return out
end

local function _store_earned(set)
	if not _mod then return end
	local ids = {}
	for id in pairs(set) do
		if _by_id[id] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	_mod:set(KEY_EARNED, table.concat(ids, ","), false)
end

-- ===========================================================================
-- Public API
-- ===========================================================================

function M.get(id)
	return _by_id[id]
end

function M.all()
	return M.PENANCES
end

function M.by_category(category)
	local out = {}
	for i = 1, #M.PENANCES do
		if M.PENANCES[i].category == category then
			out[#out + 1] = M.PENANCES[i]
		end
	end
	return out
end

function M.is_earned(id)
	if not id then return false end
	local earned = _load_earned()
	return earned[id] == true
end

function M.earned_ids()
	local out = {}
	local set = _load_earned()
	for id in pairs(set) do out[#out + 1] = id end
	table.sort(out)
	return out
end

-- Grant a penance directly. Used by /pil_grant_penance for testing, and by
-- systems that award outside the trigger loop. `silent` is reserved for
-- save migrations: it persists the exact same earned state and cascade but
-- avoids presenting an old reward as a newly completed feat on login.
-- Idempotent.
function M.grant(id, reason, silent)
	if not _by_id[id] then return false, "unknown penance" end
	local earned = _load_earned()
	if earned[id] then return false, "already earned" end

	earned[id] = true
	_store_earned(earned)

	local penance = _by_id[id]
	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "penance_earned",
			id = _event_log.next_id(),
			penance = id,
			penance_name = penance.name,
			reason = tostring(reason or ""),
		})
	end

	_debug_log("penance", 0, "earned: " .. penance.name .. " (" .. id .. ")", 0, "info")

	if not silent and _shared and _shared.notify then
		_shared.notify(string.format("Penance earned: %s", penance.name))
		if penance.unlocks then
			-- v0.22.53: resolve `unlocks` to a human display name when
			-- it's a preset id. Kaizen: "when it says 'Unlocked:
			-- character', it should say their display name, like
			-- Seneschal Abelard, not seneschal_abelard." Lookup order:
			-- ask the Preset module for its display_name, ask WarPlans
			-- (for tier unlocks like "penitent"), fall back to the raw
			-- id if neither resolves.
			local label = penance.unlocks
			local mod_ref = _mod
			if mod_ref and mod_ref._modules then
				local Preset = mod_ref._modules.Preset
				if Preset and Preset.get then
					local preset_data = Preset.get(penance.unlocks)
					if preset_data and preset_data.display_name then
						label = preset_data.display_name
					end
				end
				-- Only fall through to WarPlans if the preset lookup
				-- didn't resolve. WarPlans stores its own display names
				-- keyed by plan id.
				if label == penance.unlocks then
					local WarPlans = mod_ref._modules.WarPlans
					if WarPlans and WarPlans.get then
						local plan_data = WarPlans.get(penance.unlocks)
						if plan_data and plan_data.name then
							label = plan_data.name
						end
					end
				end
			end
			_shared.notify(string.format("Unlocked: %s", label))
		end
		-- v0.22.50: surface secondary effects (like Warband slot expansions
		-- from Faithful/Ascendant) that aren't captured by `unlocks`. Kept
		-- as a free-form string so the description isn't parsed for meaning.
		if penance.also_grants then
			_shared.notify(string.format("Also granted: %s", penance.also_grants))
		end
	end

	-- v0.22.49: cascade to parent penances. If this id is a sub of any
	-- parent, and all of that parent's subs are now earned, grant the
	-- parent too. Recursion is bounded because parents can't be their
	-- own subs (catalogue-checked at test time).
	for i = 1, #M.PENANCES do
		local candidate = M.PENANCES[i]
		if candidate.subs and not earned[candidate.id] then
			local complete = true
			for j = 1, #candidate.subs do
				if not earned[candidate.subs[j]] and candidate.subs[j] ~= id then
					complete = false
					break
				end
			end
			if complete then
				M.grant(candidate.id, "sub_penance_completed", silent)
			end
		end
	end

	-- A veteran player may already own enough Living Tithe recruits before
	-- finishing Novitiate. Re-evaluate Second Recruit the instant First Steps
	-- lands, so its slot unlock is not delayed until another shop purchase.
	if id == "pilgrim_first_steps" and _shop and _shop.living_tithe_owned_count then
		M.observe("recruit_update", {
			tier1_owned = _shop.living_tithe_owned_count(),
		})
	end

	return true
end

-- Revoke a penance. /pil_reset_penance uses this; nothing else should.
function M.revoke(id)
	if not _by_id[id] then return false, "unknown penance" end
	local earned = _load_earned()
	if not earned[id] then return false, "not earned" end
	earned[id] = nil
	_store_earned(earned)
	return true
end

-- ===========================================================================
-- Trigger loop
-- ===========================================================================
--
-- Wire the emitter into M.observe(trigger, data) from wherever the event
-- happens:
--
--   run_complete             chain.lua on run end (see finalize_leg_completion)
	--   wallet_update            wallet.lua on any earn/spend
	--   mission_complete         chain.lua on each successful leg
	--   mission_count            chain.lua after each successful leg
	--   run_count                chain.lua after incrementing total_runs_completed
	--   recruit_update           shop.lua after a Living Tithe purchase
	--   interrogator_hacked      exact servo-skull completion stat event
--   sub_penance_earned       fires implicitly through M.grant's cascade
--   voltaic_weapon_disabled  Pilgrimage.lua after a Skitarii weapon malfunction
--   curated_run_complete     NOT WIRED (Curated Run system, future session)

function M.observe(trigger, data)
	if not trigger then return end
	-- v0.23.3 (FB-2, player suggestion): while cheat mode is ON, penance
	-- EARNING is suspended entirely. Nothing already earned is touched,
	-- and the /pil_grant_penance debug command still works; only
	-- trigger-driven awards pause. The toggle notification lives in
	-- Pilgrimage.lua's on_setting_changed.
	if _settings and _settings.cheat_mode_enabled
		and _settings.cheat_mode_enabled() then return end
	data = data or {}
	local earned = _load_earned()
	for i = 1, #M.PENANCES do
		local penance = M.PENANCES[i]
		-- Parents don't fire on triggers; they're granted by M.grant's
		-- cascade when the last sub is earned. Skip them here.
		if penance.subs then
			-- nothing
		elseif penance.trigger == trigger and not earned[penance.id] then
			local ok, result = pcall(penance.check, data)
			if ok and result == true then
				M.grant(penance.id, trigger)
			end
		end
	end
end

-- ===========================================================================
-- Catalogue self-check (called from init)
-- ===========================================================================
--
-- Fatshark-style sanity: catch id typos and broken sub references at load
-- time instead of at first-observe time. Logs one warning per issue; never
-- errors, so a bad catalogue doesn't take the whole mod down.

local function _validate_catalogue()
	local issues = 0
	for i = 1, #M.PENANCES do
		local p = M.PENANCES[i]
		if type(p.id) ~= "string" or p.id == "" then
			_debug_log("penances_validate", 0, "entry " .. i .. " missing id", 0, "warn")
			issues = issues + 1
		end
		if p.subs then
			for j = 1, #p.subs do
				local sub_id = p.subs[j]
				if not _by_id[sub_id] then
					_debug_log("penances_validate", 0,
						"parent " .. p.id .. " references unknown sub " .. tostring(sub_id),
						0, "warn")
					issues = issues + 1
				elseif _by_id[sub_id].subs then
					_debug_log("penances_validate", 0,
						"parent " .. p.id .. " references parent as sub: " .. sub_id,
						0, "warn")
					issues = issues + 1
				end
			end
		end
		if p.unlocks and type(p.unlocks) ~= "string" then
			_debug_log("penances_validate", 0,
				"entry " .. p.id .. " has non-string unlocks", 0, "warn")
			issues = issues + 1
		end
	end
	if issues == 0 then
		_debug_log("penances_validate", 0, "catalogue OK (" .. #M.PENANCES .. " entries)", 0, "info")
	end
end

-- ===========================================================================

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_event_log = deps.event_log
	_run_state = deps.run_state
	_wallet = deps.wallet
	_shop = deps.shop
	_settings = deps.settings
	_debug_log = deps.debug_log or function() end

	_validate_catalogue()

	-- Older saves may have cleared these War Plans before the dedicated slot
	-- Penances existed. Mirror that proven progression silently, preserving
	-- their current Warband capacity without manufacturing new gameplay credit.
	local earned = _load_earned()
	local migrated = false
	if earned.pilgrim_first_steps and not earned.pilgrim_first_recruit then
		earned.pilgrim_first_recruit = true
		migrated = true
	end
	if earned.pilgrim_faithful and not earned.pilgrim_sanctioned then
		earned.pilgrim_sanctioned = true
		migrated = true
	end
	if migrated then _store_earned(earned) end
end

return M
