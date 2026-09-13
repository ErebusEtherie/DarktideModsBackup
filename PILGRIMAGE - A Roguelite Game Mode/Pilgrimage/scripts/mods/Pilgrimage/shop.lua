-- shop.lua
--
-- The Emporium: where Ordos become gameplay. v1 ships consumable run modifiers
-- (curse reroll, curse skip, extra boon draft) plus the permanent-unlock
-- plumbing that the Majoris pool and cosmetic system will fill in later.
--
-- ===========================================================================
-- WHY THIS EXISTS
-- ===========================================================================
--
-- Before this, Ordos accumulated forever with nothing to spend them on. Every
-- Novitiate clear dropped ~250 into a pile you could look at and nothing else.
-- The shop turns that pile into a decision surface.
--
-- ===========================================================================
-- TWO KINDS OF PURCHASE
-- ===========================================================================
--
--   consumable   Buys a flag stored in _shop_consumables. Consumed by the
--                gameplay system it affects (launcher for curse reroll/skip,
--                bootstrap's pending_draft for extra slot) at the moment it
--                takes effect, then cleared. Also wiped whenever a run ends.
--
--   permanent    Buys a flag stored in _shop_unlocked. Persists across runs
--                forever. v1 ships the plumbing but no actual permanent SKUs,
--                because those need the Majoris pool and the loadout slots
--                to land first.
--
-- Some SKUs are penance-gated instead of Ordos-priced: the shop shows them as
-- "Locked, complete X" rather than a price tag. The unlock is still stored in
-- _shop_unlocked, but the transaction bypasses the wallet.
--
-- ===========================================================================
-- STORAGE
-- ===========================================================================
--
-- Two comma-separated lists in settings, same encoding as _penances_earned.
-- All ids are validated against the catalogue on load so a stale saved id
-- from a removed SKU does not silently linger.

local M = {}

local _mod
local _shared
local _event_log
local _wallet
local _penances
-- v0.22.81: House Always Wins price tax
local _boons
-- v0.22.88: enemy bans (upcoming-leg kill-target gate)
local _run_state
local _missions
-- Declared at the top of the file, above every function that reads it.
-- Lua closures only capture locals that exist above them at parse time
-- (the v0.14.1 boons scoping lesson).
local _debug_log

local KEY_CONSUMABLES = "_shop_consumables"
local KEY_UNLOCKED    = "_shop_unlocked"
-- v0.20.1: stackable SKUs need a COUNT, not just a presence bit. Kept in
-- a separate key so the existing set-encoded consumables key does not have
-- to change shape and break any earlier-version save that referenced it.
-- Format is "id:count,id:count".
local KEY_STACKS      = "_shop_stacks"

-- ===========================================================================
-- Catalogue
-- ===========================================================================
--
-- id         internal, stable, used as the storage key. NEVER rename an id.
-- name       display label.
-- description one line explaining what the buy does.
-- cost       Ordos price. nil for penance-gated SKUs.
-- kind       "consumable" (per-run) or "permanent" (forever).
-- category   grouping for the shop UI. Currently "consumable" or "permanent".
-- pending    true = SKU is in the catalogue but its consumer hook does not
--            exist yet. Shown greyed out with a "Coming soon" note.
-- unlock_penance  optional. Requires this penance id to be visible AT ALL.
--                 Locked SKUs display "Locked, complete X" and cannot be
--                 bought until the gate opens.
-- ===========================================================================

M.SKUS = {
	-- --- Consumables ------------------------------------------------------

	{
		id          = "curse_reroll",
		name        = "Reroll Condition",
		description = "Before the next assignment launches, re-roll its condition from the pool.",
		cost        = 100,
		kind        = "consumable",
		category    = "consumable",
	},

	{
		id          = "curse_skip",
		name        = "Skip Condition",
		description = "The next assignment runs with no condition. One-off, this leg only.",
		cost        = 150,
		kind        = "consumable",
		category    = "consumable",
	},

	{
		id          = "draft_extra",
		name        = "Extra Boon Draft",
		description = "The next boon draft shows four choices instead of three.",
		cost        = 80,
		kind        = "consumable",
		category    = "consumable",
	},

	{
		-- v0.20.1: fog of war. The route defaults to showing you the
		-- current leg and one step ahead; everything past that renders
		-- as "Assignment N: ?". Buy this to peel back one more leg.
		-- Stackable: three buys reveal three legs deeper.
		--
		-- Not "consumed" by any gameplay system. The stack count itself
		-- is the effect; it applies while it exists and dies when the
		-- run ends (clear_run_consumables clears both stores).
		id          = "reveal_next",
		name        = "Scout Ahead",
		description = "Reveal the next hidden assignment on your route. Stacks with itself.",
		cost        = 50,
		kind        = "consumable",
		category    = "consumable",
		stackable   = true,
	},

	{
		-- The stable id is retained from the dormant loadout-slot placeholder
		-- so an old settings file remains valid. It now opens a second
		-- pre-run Legendary slot for one pilgrimage and is priced as a major
		-- power purchase rather than an ordinary route convenience.
		id          = "temp_slot",
		name        = "Temporary Legendary Slot",
		description = "For this pilgrimage, unlock a second pre-run Legendary slot.",
		cost        = 2000,
		kind        = "consumable",
		category    = "consumable",
	},

	{
		-- v0.22.91 (Session C part 2): LIVE. The consumer is a watcher
		-- tick in Pilgrimage.lua: when the local player enters the
		-- knocked_down state with this active, it sets force_assist on
		-- the assisted_state_input component, the engine's own
		-- no-rescuer assist (Assist._update_force_assist, fast anim),
		-- and consumes the SKU. Host-authority, which Pilgrimage is.
		id          = "auto_revive",
		name        = "Emergency Prayer",
		description = "Once this run, the moment you are knocked down, you rise on your own. The Emperor protects.",
		cost        = 250,
		kind        = "consumable",
		category    = "consumable",
	},

	{
		-- v0.22.92: Hazard Pay. The friendly-fire SKU it replaces made
		-- no sense as a purchase (Kaizen); FF as a POWER price moved to
		-- the Sanctioned Discord boon, and FF as a MONEY price became
		-- this: a free contract that turns friendly fire fully ON,
		-- both directions, everyone, for the next assignment, and pays
		-- +50% Ordos on everything earned during it (wallet
		-- _earn_multiplier, additive per the locked stacking rule).
		-- Consumed when the leg ends (hub-transition watcher in
		-- Pilgrimage.lua).
		id          = "hazard_pay",
		name        = "Hazard Pay Contract",
		description = "No charge. Next assignment: friendly fire is live, both ways, everyone. All Ordos earned that assignment +50%.",
		cost        = 0,
		kind        = "consumable",
		category    = "consumable",
	},

	-- --- Enemy bans (Session C, v0.22.88) ---------------------------------
	--
	-- Kaizen's design, re-confirmed 2026-08-10: per-run consumables that
	-- remove a breed family from spawning for the rest of the run. One
	-- ban per tier per run (no double-monster-ban, no dogs+trappers).
	-- Higher tier = bigger threat = higher price; all prices flagged for
	-- the Ordos economy audit.
	--
	-- Enforcement lives in Pilgrimage.lua: a hook on
	-- MinionSpawnManager.spawn_minion, the single funnel every pacing
	-- system, mutator and horde spawner goes through (verified in
	-- dt-src: monster/specials/roamer pacing and the minion_spawner
	-- extension all call it). Policy per SKU:
	--   ban_skip = true  -> the spawn is dropped outright (monsters:
	--                       a rerolled monster would still be a monster
	--                       fight, which is not what 500 Ordos bought).
	--   otherwise        -> the breed is substituted with faction trash
	--                       (rifleman / assaulter / newly infected), so
	--                       pacing unit counts stay sane and no caller
	--                       ever sees a nil unit.
	--
	-- DELIBERATE exclusions, do not "fix": circumstance-objective
	-- variants keep their own breeds and stay spawnable, or a curse could
	-- be bought empty. chaos_mutator_daemonhost (Heinous Rituals
	-- hexbound), chaos_hound_mutator (hound-ambush circumstances),
	-- renegade_flamer_mutator. This IS the design's Heinous Rituals
	-- caveat, falling out of breed naming for free.
	--
	-- Tier 1 additionally refuses purchase while the upcoming assignment
	-- is an assassination (mission_type check): kill-target missions need
	-- their bosses.

	{
		id          = "ban_plague_ogryn",
		name        = "Writ of Exclusion: Plague Ogryn",
		description = "No Plague Ogryns spawn this run.",
		cost        = 500,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 1,
		ban_skip    = true,
		ban_breeds  = { "chaos_plague_ogryn" },
	},
	{
		id          = "ban_beast_of_nurgle",
		name        = "Writ of Exclusion: Beast of Nurgle",
		description = "No Beasts of Nurgle spawn this run.",
		cost        = 500,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 1,
		ban_skip    = true,
		ban_breeds  = { "chaos_beast_of_nurgle" },
	},
	{
		id          = "ban_chaos_spawn",
		name        = "Writ of Exclusion: Chaos Spawn",
		description = "No Chaos Spawn spawn this run.",
		cost        = 500,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 1,
		ban_skip    = true,
		ban_breeds  = { "chaos_spawn" },
	},
	{
		id          = "ban_daemonhost",
		name        = "Writ of Exclusion: Daemonhost",
		description = "No ambient Daemonhosts this run. Ritual-bound daemonhosts are beyond the Emporium's reach.",
		cost        = 500,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 1,
		ban_skip    = true,
		ban_breeds  = { "chaos_daemonhost" },
	},

	{
		id          = "ban_trappers",
		name        = "Writ of Exclusion: Trappers",
		description = "Trappers are replaced with common gunfodder this run.",
		cost        = 350,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 2,
		ban_breeds  = { "renegade_netgunner" },
	},
	{
		id          = "ban_dogs",
		name        = "Writ of Exclusion: Hounds",
		description = "Pox and armored hounds are replaced with common gunfodder this run. Hound-ambush conditions keep their packs.",
		cost        = 350,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 2,
		ban_breeds  = { "chaos_hound", "chaos_armored_hound" },
	},
	{
		id          = "ban_poxbursters",
		name        = "Writ of Exclusion: Poxbursters",
		description = "Poxbursters are replaced with common gunfodder this run.",
		cost        = 350,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 2,
		ban_breeds  = { "chaos_poxwalker_bomber" },
	},

	{
		id          = "ban_flamers",
		name        = "Writ of Exclusion: Flamers",
		description = "Scab and Dreg flamers are replaced with common gunfodder this run.",
		cost        = 250,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 3,
		ban_breeds  = { "renegade_flamer", "cultist_flamer" },
	},
	{
		id          = "ban_snipers",
		name        = "Writ of Exclusion: Snipers",
		description = "Snipers are replaced with common gunfodder this run.",
		cost        = 250,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 3,
		ban_breeds  = { "renegade_sniper" },
	},
	{
		id          = "ban_bombers",
		name        = "Writ of Exclusion: Bombers",
		description = "Scab and Dreg bombers are replaced with common gunfodder this run.",
		cost        = 250,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 3,
		ban_breeds  = { "renegade_grenadier", "cultist_grenadier" },
	},
	{
		id          = "ban_crushers",
		name        = "Writ of Exclusion: Crushers",
		description = "Crushers are replaced with common gunfodder this run.",
		cost        = 250,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 3,
		ban_breeds  = { "chaos_ogryn_executor" },
	},
	{
		id          = "ban_bulwarks",
		name        = "Writ of Exclusion: Bulwarks",
		description = "Bulwarks are replaced with common gunfodder this run.",
		cost        = 250,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 3,
		ban_breeds  = { "chaos_ogryn_bulwark" },
	},

	{
		id          = "ban_ragers",
		name        = "Writ of Exclusion: Ragers",
		description = "Scab and Dreg ragers are replaced with common gunfodder this run.",
		cost        = 150,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 4,
		ban_breeds  = { "renegade_berzerker", "cultist_berzerker" },
	},
	{
		id          = "ban_maulers",
		name        = "Writ of Exclusion: Maulers",
		description = "Maulers are replaced with common gunfodder this run.",
		cost        = 150,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 4,
		ban_breeds  = { "renegade_executor" },
	},
	{
		id          = "ban_heavy_gunners",
		name        = "Writ of Exclusion: Heavy Gunners",
		description = "Scab and Dreg heavy gunners are replaced with common gunfodder this run.",
		cost        = 150,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 4,
		ban_breeds  = { "renegade_gunner", "cultist_gunner" },
	},
	{
		id          = "ban_reapers",
		name        = "Writ of Exclusion: Reapers",
		description = "Reapers are replaced with common gunfodder this run.",
		cost        = 150,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 4,
		ban_breeds  = { "chaos_ogryn_gunner" },
	},
	{
		id          = "ban_vanguards",
		name        = "Writ of Exclusion: Vanguards",
		description = "Scab and Dreg vanguards are replaced with common gunfodder this run.",
		cost        = 150,
		kind        = "consumable",
		category    = "ban",
		ban_tier    = 4,
		ban_breeds  = { "renegade_vanguard", "cultist_vanguard" },
	},

	-- --- Permanent unlocks ------------------------------------------------
	--
	-- v0.22.79 REDESIGN (Kaizen, 2026-08-10): slot progression flipped.
	-- The FIRST two expansions (slots 3 and 4) are now the Ordos
	-- Legacy slot products from the v0.22.79 progression shape. v0.28.52
	-- hides them from the Emporium but retains their stable IDs so an
	-- existing purchase still opens its matching slot without stacking
	-- with the replacement Penance.

	{
		id          = "bot_slot_3",
		name        = "Third Warband Slot",
		description = "Expand the pilgrim's warband. Permanent, adds a third bot slot.",
		cost        = 2000,
		kind        = "permanent",
		category    = "permanent",
		hidden      = true, -- legacy ownership remains valid; no longer sold
	},

	{
		id          = "bot_slot_4",
		name        = "Fourth Warband Slot",
		description = "Expand the pilgrim's warband. Permanent, adds a fourth bot slot.",
		cost        = 4000,
		kind        = "permanent",
		category    = "permanent",
		hidden      = true, -- legacy ownership remains valid; no longer sold
	},

	-- Living Tithe. The baseline Moebian Conscript is free and therefore
	-- has no SKU. The remaining Tier 1 recruits are deliberately cheap,
	-- low-power permanent purchases that build the early Warband roster.
	{
		id = "living_tithe_preacher", name = "Living Tithe: Militarum Preacher",
		description = "Acquire the Militarum Preacher Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "militarum_preacher",
	},
	{
		id = "living_tithe_grog", name = "Living Tithe: Grog",
		description = "Acquire the Grog Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "grog",
	},
	{
		id = "living_tithe_psyker", name = "Living Tithe: Black Ship Fodder",
		description = "Acquire the Black Ship Fodder Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "black_ship_fodder",
	},
	{
		id = "living_tithe_deputy", name = "Living Tithe: Moebian Deputy",
		description = "Acquire the Moebian Deputy Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "moebian_deputy",
	},
	{
		id = "living_tithe_cartel", name = "Living Tithe: Cartel Recruit",
		description = "Acquire the Cartel Recruit Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "cartel_recruit",
	},
	{
		id = "living_tithe_skitarius", name = "Living Tithe: Sk1tar1us 2137",
		description = "Acquire the Sk1tar1us 2137 Tier 1 bot preset.",
		cost = 100, kind = "permanent", category = "permanent",
		living_tithe = true, preset_id = "skitarius_2137",
	},

	-- v0.22.81 (Boon Loadout): loadout slot expansions. Base is 1
	-- slot; these open slots 2 and 3. Slot 4 is reserved for a future
	-- penance per the locked decision (at least one expansion is
	-- Ordos-purchasable, the rest penances). Prices flagged for the
	-- economy audit.
	{
		id          = "boon_slot_2",
		name        = "Second Doctrine Slot",
		description = "A second slot in the Boon Loadout. Permanent.",
		cost        = 1500,
		kind        = "permanent",
		category    = "permanent",
	},
	{
		id          = "boon_slot_3",
		name        = "Third Doctrine Slot",
		description = "A third slot in the Boon Loadout. Permanent.",
		cost        = 3000,
		kind        = "permanent",
		category    = "permanent",
	},
	{
		-- v0.24.0 (Boons v2): opens the dedicated Archetype slot in the
		-- Boon Loadout. The archetype choice itself is free once the
		-- slot exists, and locks in at run start. Economy-pass price.
		id          = "archetype_slot",
		name        = "Archetype Authorization",
		description = "Opens the Archetype slot in the Boon Loadout. An Archetype is a run identity: one major effect, one cost, and the road's boon drafts are curated to match it. Permanent.",
		cost        = 1500,
		kind        = "permanent",
		category    = "permanent",
	},
}

local _by_id = {}
for i = 1, #M.SKUS do _by_id[M.SKUS[i].id] = M.SKUS[i] end

-- ===========================================================================
-- Storage helpers
-- ===========================================================================

local function _load_set(key)
	local raw = _mod and _mod:get(key) or nil
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for id in string.gmatch(raw, "([^,]+)") do
		if _by_id[id] then out[id] = true end
	end
	return out
end

local function _store_set(key, set)
	if not _mod then return end
	local ids = {}
	for id in pairs(set) do
		if _by_id[id] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	_mod:set(key, table.concat(ids, ","), false)
end

local function _load_consumables() return _load_set(KEY_CONSUMABLES) end
local function _load_unlocked()    return _load_set(KEY_UNLOCKED) end

-- v0.20.1: stackable counts. Same encoding pattern as run_state uses for
-- boon stacks. Anything that doesn't parse or points at a removed SKU is
-- silently dropped, matching how _load_set treats stale ids.
local function _load_stacks()
	local raw = _mod and _mod:get(KEY_STACKS) or nil
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for entry in string.gmatch(raw, "([^,]+)") do
		local id, count = string.match(entry, "^(.-):(%d+)$")
		if id and count and _by_id[id] then
			out[id] = tonumber(count) or 0
		end
	end
	return out
end

local function _store_stacks(map)
	if not _mod then return end
	local ids = {}
	for id, count in pairs(map) do
		if _by_id[id] and count and count > 0 then
			ids[#ids + 1] = id .. ":" .. tostring(math.floor(count))
		end
	end
	table.sort(ids)
	_mod:set(KEY_STACKS, table.concat(ids, ","), false)
end

-- ===========================================================================
-- Public API: reads
-- ===========================================================================

function M.get(id) return _by_id[id] end
function M.all()   return M.SKUS end

-- Balance passthrough so views can ask the shop rather than reaching to
-- wallet directly. One coupling surface for the UI to depend on.
function M.balance()
	return _wallet and _wallet.balance() or 0
end

function M.is_active(id)
	if not id then return false end
	local sku = _by_id[id]
	if sku and sku.stackable then
		-- Return a real boolean, not nil, so callers that compare with
		-- == false work as expected. The `and ... > 0` chain would
		-- short-circuit to nil when the count is missing.
		local count = _load_stacks()[id]
		return count ~= nil and count > 0
	end
	return _load_consumables()[id] == true
end

-- v0.20.1: how many times has a stackable SKU been bought this run. Zero
-- for anything not stackable or not bought. The reveal system multiplies
-- fog radius by this.
function M.stack_count(id)
	if not id then return 0 end
	local sku = _by_id[id]
	if not sku or not sku.stackable then return 0 end
	return _load_stacks()[id] or 0
end

function M.is_unlocked(id)
	if not id then return false end
	return _load_unlocked()[id] == true
end

-- The baseline Veteran counts as the first owned Tier 1 recruit. Each
-- permanent Living Tithe purchase adds one. Penances read this live, so
-- ownership cannot drift away from the Emporium save data.
function M.living_tithe_owned_count()
	local count = 1
	for i = 1, #M.SKUS do
		local sku = M.SKUS[i]
		if sku.living_tithe and M.is_unlocked(sku.id) then
			count = count + 1
		end
	end
	return count
end

-- Save migration helper. It preserves a previously bound or captured Tier 1
-- preset without charging the player when the new ownership gates arrive.
function M.grant_permanent(id)
	local sku = _by_id[id]
	if not sku or sku.kind ~= "permanent" then return false end
	local set = _load_unlocked()
	if set[id] then return true end
	set[id] = true
	_store_set(KEY_UNLOCKED, set)
	return true
end

function M.active_ids()
	local out = {}
	for id in pairs(_load_consumables()) do out[#out + 1] = id end
	table.sort(out)
	return out
end

function M.unlocked_ids()
	local out = {}
	for id in pairs(_load_unlocked()) do out[#out + 1] = id end
	table.sort(out)
	return out
end

-- ===========================================================================
-- Purchase gating
--
-- Returns true or false + reason. UI uses this to grey out and label locked
-- SKUs; buy() runs the same check internally so the API cannot be bypassed
-- by skipping the UI (a bad terminal or a debug command still can't cheat).
-- ===========================================================================

function M.can_buy(id)
	local sku = _by_id[id]
	if not sku then return false, "unknown item" end

	-- v0.22.33: pending SKUs (their consumer hook not wired yet) must
	-- refuse to buy. Otherwise the wallet debits, the SKU flag writes
	-- to _shop_consumables, and Ordos vanish for a purchase that does
	-- nothing. Caught by Kaizen buying "Temporary Loadout Slot" from
	-- the terminal and seeing his balance drop.
	if sku.pending then
		return false, "coming soon"
	end

	if sku.unlock_penance and _penances and _penances.is_earned then
		if not _penances.is_earned(sku.unlock_penance) then
			return false, "locked (requires penance)"
		end
	end

	if sku.kind == "consumable" then
		-- Stackable consumables can always be bought again while funded.
		-- Non-stackable ones are one-per-run.
		if not sku.stackable and M.is_active(id) then
			return false, "already active this run"
		end
		if id == "temp_slot" and _run_state and _run_state.is_active
			and _run_state.is_active() then
			return false, "buy before starting a pilgrimage"
		end

		-- v0.22.35: reroll is nonsense to buy while skip is active,
		-- because skip already zeroes the current leg's curse; rerolling
		-- would just spin the wheel on a slot that's been removed. Kaizen
		-- flagged this: he bought reroll while skip was active and it
		-- rerolled the SKIPPED slot into an already-present curse. Refuse
		-- the buy outright; reroll opens back up on the next leg (where
		-- skip is gone, having been consumed at launch).
		if id == "curse_reroll" and M.is_active("curse_skip") then
			return false, "skip is active this leg"
		end

		-- v0.22.88: enemy-ban rules. ONE ban per tier per run (Kaizen:
		-- no double-monster-ban, no dogs+trappers), and tier 1 bans are
		-- off the shelf while the upcoming assignment is an
		-- assassination (kill-target missions need their bosses).
		if sku.category == "ban" then
			for i = 1, #M.SKUS do
				local other = M.SKUS[i]
				if other.category == "ban" and other.ban_tier == sku.ban_tier
					and other.id ~= id and M.is_active(other.id) then
					return false, "tier " .. tostring(sku.ban_tier) .. " ban already active"
				end
			end
			-- v0.22.90 (Kaizen): the tier-1 kill-target gate is GONE.
			-- Kill targets are captain-family breeds (renegade_captain,
			-- cultist_captain, the twin captains; dt-src monster_pacing
			-- "captains" spawn type), none of which are bannable, so a
			-- monster ban can never touch a kill objective. The
			-- next_leg_has_kill_target helper below stays for future
			-- SKUs that genuinely depend on the upcoming mission type.
		end
	elseif sku.kind == "permanent" then
		if M.is_unlocked(id) then
			return false, "already unlocked"
		end
	end

	local price = M.effective_cost(sku)
	if price > 0 then
		if M.balance() < price then
			return false, "not enough Ordos"
		end
	end

	return true
end

-- v0.22.81: the price actually charged. The House Always Wins loadout
-- boon taxes the Emporium +50% while slotted with a run active. All
-- purchase paths and the Emporium tab's price strings go through here
-- so the displayed price is always the charged price.
function M.effective_cost(sku_or_id)
	local sku = type(sku_or_id) == "table" and sku_or_id or _by_id[sku_or_id]
	if not sku then return 0 end
	local price = sku.cost or 0
	if price > 0 and _boons and _boons.custom_boon_active
		and _boons.custom_boon_active("pilgrim_boon_house_wins") then
		price = math.floor(price * 1.5)
	end
	return price
end

-- ===========================================================================
-- Purchase
--
-- Two paths, sharing the wallet debit:
--   consumable  writes into _shop_consumables, wiped on run end
--   permanent   writes into _shop_unlocked, kept forever
--
-- Wallet spend happens BEFORE the flag write. If the debit fails (a race
-- with another Ordos-spending path) the flag never gets written, so we
-- cannot end up with a paid-for-but-lost purchase or an owned-but-unpaid
-- one. Kaizen's design: no ghost purchases.
-- ===========================================================================

function M.buy(id)
	local ok, reason = M.can_buy(id)
	if not ok then return false, reason end

	local sku = _by_id[id]
	-- v0.22.81: charge the effective (House-taxed) price, matching
	-- what can_buy checked and the tab displayed.
	local price = M.effective_cost(sku)

	if price > 0 then
		local spent = _wallet and _wallet.spend
			and _wallet.spend(price, "shop:" .. id)
		if not spent then
			return false, "wallet refused the debit"
		end
	end

	if sku.kind == "consumable" then
		if sku.stackable then
			local stacks = _load_stacks()
			stacks[id] = (stacks[id] or 0) + 1
			_store_stacks(stacks)
		else
			local set = _load_consumables()
			set[id] = true
			_store_set(KEY_CONSUMABLES, set)
		end
	else
		local set = _load_unlocked()
		set[id] = true
		_store_set(KEY_UNLOCKED, set)
	end

	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "shop_purchase",
			id = _event_log.next_id(),
			sku = id,
			kind = sku.kind,
			cost = price,
			balance_after = M.balance(),
		})
	end

	_debug_log("shop", 0, string.format("bought %s (%s, %d O)", sku.name, sku.kind, price), 0, "info")

	if _shared and _shared.notify then
		_shared.notify(string.format("Purchased: %s (-%d Ordos)", sku.name, price))
	end

	if sku.living_tithe and _penances and _penances.observe then
		_penances.observe("recruit_update", {
			tier1_owned = M.living_tithe_owned_count(),
		})
	end

	return true
end

-- ===========================================================================
-- Consumption
--
-- Called by the gameplay system that respects the flag, at the moment it
-- takes effect. Returns true if the flag was consumed (so the caller can
-- act on it), false if it was not set.
--
-- Consuming clears the flag AND emits a shop_consumed event so the log
-- shows the pairing: bought at t=100, consumed at t=380.
-- ===========================================================================

function M.consume(id)
	if not _by_id[id] then return false end
	local set = _load_consumables()
	if not set[id] then return false end

	set[id] = nil
	_store_set(KEY_CONSUMABLES, set)

	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "shop_consumed",
			id = _event_log.next_id(),
			sku = id,
		})
	end

	_debug_log("shop", 0, "consumed " .. id, 0, "info")
	return true
end

-- Called by chain.finalize_leg_completion when a run ends. Wipes every
-- consumable, whether it was consumed or not: a curse-reroll bought and
-- never used does not carry to the next run, and scout-ahead reveals
-- from the finished run do not extend into the next one. Design intent
-- is that consumables die with the run, so hoarding across runs is
-- impossible.
function M.clear_run_consumables()
	if not _mod then return end
	_mod:set(KEY_CONSUMABLES, "", false)
	_mod:set(KEY_STACKS, "", false)
	_debug_log("shop", 0, "cleared run consumables and stacks", 0, "info")
end

-- ===========================================================================
-- Enemy bans (v0.22.88)
-- ===========================================================================

-- True when the upcoming leg's mission is an assassination. Read from
-- the game's own mission template (missions.info surfaces mission_type),
-- so new kill-target missions are covered without a hardcoded list.
-- v0.22.90: no longer consumed by the ban SKUs (kill targets are
-- captains, which are not bannable); kept for future mission-type-
-- gated SKUs (stratagems, run-only boons).
function M.next_leg_has_kill_target()
	if not (_run_state and _run_state.current_mission and _missions and _missions.info) then
		return false
	end
	local mission_name = _run_state.current_mission()
	if not mission_name then return false end
	local info = _missions.info(mission_name)
	return (info and info.mission_type) == "assassination"
end

-- breed_name -> policy for every breed covered by an ACTIVE ban this
-- run. Policy is the string "skip" (drop the spawn: monsters) or true
-- (substitute with faction trash; the substitution table lives with the
-- spawn hook in Pilgrimage.lua). Consumed by that hook's rebuild tick.
function M.active_ban_breeds()
	local out = {}
	for i = 1, #M.SKUS do
		local sku = M.SKUS[i]
		if sku.category == "ban" and sku.ban_breeds and M.is_active(sku.id) then
			local policy = sku.ban_skip and "skip" or true
			for j = 1, #sku.ban_breeds do
				out[sku.ban_breeds[j]] = policy
			end
		end
	end
	return out
end

-- Revoke a permanent unlock. Debug-only; the shop UI never surfaces this.
function M.revoke_unlock(id)
	if not _by_id[id] then return false, "unknown" end
	local set = _load_unlocked()
	if not set[id] then return false, "not unlocked" end
	set[id] = nil
	_store_set(KEY_UNLOCKED, set)
	return true
end

-- ===========================================================================
-- Fog of war
--
-- v0.20.1: the route view no longer shows the whole pilgrimage upfront.
-- Only the current leg and the next one are visible by default; deeper
-- legs render as "Assignment N: ?" until a Scout Ahead purchase peels
-- them back. This exists because knowing the whole route in advance makes
-- the Emporium's per-leg SKUs (Reroll, Skip) pointless: you can already
-- see whether the future is worth reshaping.
--
-- Formula:
--
--   Pre-run (current_leg == 0)  visible if leg <= 1 + reveals_bought
--     -> fresh preview shows leg 1 only. One reveal peels back leg 2, etc.
--   Mid-run (current_leg >= 1)  visible if leg <= current_leg + 1 + reveals
--     -> the leg you are on plus the next one, always. Reveals push deeper.
--
-- Past legs (leg < current) are always visible: you already played them,
-- hiding them retroactively would just be confusing.
-- ===========================================================================

function M.reveals_bought()
	return M.stack_count("reveal_next")
end

function M.leg_visible(leg_index, current_leg)
	if type(leg_index) ~= "number" then return false end
	current_leg = tonumber(current_leg) or 0

	-- Legs you have already played are visible unconditionally.
	if current_leg > 0 and leg_index < current_leg then return true end

	local reveals = M.reveals_bought()
	local horizon
	if current_leg <= 0 then
		-- Pre-run: only leg 1 by default, plus reveals.
		horizon = 1 + reveals
	else
		-- Mid-run: current plus one lookahead, plus reveals.
		horizon = current_leg + 1 + reveals
	end
	return leg_index <= horizon
end

-- ===========================================================================
-- Grouping helpers for the UI
-- ===========================================================================

-- Every SKU in a category, in catalogue order. The UI walks these lists to
-- draw the shop tab, so ordering matters for what shows up first.
function M.by_category(category)
	local out = {}
	for i = 1, #M.SKUS do
		if M.SKUS[i].category == category and not M.SKUS[i].hidden then
			out[#out + 1] = M.SKUS[i]
		end
	end
	return out
end

function M.categories()
	return { "consumable", "permanent" }
end

-- ===========================================================================

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_event_log = deps.event_log
	_wallet = deps.wallet
	_penances = deps.penances
	-- v0.22.81: optional, read at price time only (House tax).
	_boons = deps.boons
	-- v0.22.88: enemy bans read the upcoming leg (kill-target gate).
	_run_state = deps.run_state
	_missions = deps.missions
	_debug_log = deps.debug_log or function() end
end

return M
