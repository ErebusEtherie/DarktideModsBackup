-- wallet.lua
--
-- The Pilgrimage currency: Ordos. Persistent balance, earned from playing.
--
-- ===========================================================================
-- WHY A CURRENCY EXISTS
-- ===========================================================================
--
-- Kaizen's design: give the run something to accumulate that survives it.
-- Currency will eventually buy pre-run boons and unlock permanent starting
-- benefits, and to do that meaningfully it has to have arrived by the time
-- the shop lands. This module is v0.18's earn side: display and tallying
-- only, no spending yet.
--
-- Named "Ordos" to fit with Darktide's existing currency vocabulary (Ordo
-- Dockets, Aquila). Short display "O" so it fits in HUD lines.
--
-- ===========================================================================
-- WHERE ORDOS COME FROM
-- ===========================================================================
--
-- Three earn sources, all event-driven:
--
--   1. Leg complete       Base 30, +10 per danger tier above Uprising, +25
--                         per scale-tier past Damnation. So a Malice leg is
--                         50, a Damnation leg 90, a Damnation-tier-3 leg
--                         165. Kaizen wanted higher-difficulty legs to earn
--                         more; this delivers it exactly.
--
--   2. Run complete       Bonus 100, +30 per leg completed. A three-leg run
--                         cleared is 100 + 90 = 190 on top of per-leg
--                         earnings. Rewards finishing rather than farming
--                         single legs.
--
--   3. Pickup materials   Plasteel and diamantine pickups convert to Ordos
--                         at the rate the game itself uses for their
--                         perceived value: small plasteel 1, large plasteel
--                         5, small diamantine 3, large diamantine 15. The
--                         real-currency version of these materials never
--                         credits (solo host, no backend session), so this
--                         gives them a REASON to collect during a run that
--                         otherwise ignores them. Kaizen's suggestion.
--
-- ===========================================================================
-- STORAGE
-- ===========================================================================
--
-- Balance in a plain settings key (_wallet_balance, number). History as a
-- bounded-list encoded string (_wallet_history) so /pil_wallet can show
-- WHERE the ordos came from, not just the total. Same encoding scheme
-- run_state uses.

local M = {}

local _mod
local _event_log
local _run_state
local _shared
local _fileio
-- v0.22.79: earn-multiplier penances (Coffers Bursting +5%, etc.)
local _penances
-- v0.22.80: Dynastic Largesse needs to know who's in the warband.
local _preset
local _bots
-- v0.22.81: The House Always Wins pickup doubling
local _boons
local _shop
-- Declared at the top, above every function, because a Lua function only
-- captures locals that exist above its definition (the v0.14.1 boons lesson).
local _debug_log

local KEY_BALANCE = "_wallet_balance"
local KEY_HISTORY = "_wallet_history"
-- v0.22.80: lifetime Ordos spent, for Theodora's unlock penance (A
-- Rogue Trader's Fortune: amass 20k OR spend a lifetime 20k). The
-- history table is capped, so a dedicated ever-growing counter is the
-- only reliable source for "spent across all time".
local KEY_TOTAL_SPENT = "_wallet_total_spent"

-- Cap the history so the settings string can never grow unbounded. 40 is
-- large enough to keep a full run's worth of transactions plus context.
local HISTORY_CAP = 40

-- The earn tables. Constants so they are one place to tune later.
M.LEG_BASE          = 30
M.LEG_PER_DANGER    = 10   -- multiplied by (danger - Uprising)
M.LEG_PER_SCALE     = 25   -- multiplied by scale_tier above Damnation
M.RUN_BASE          = 100
M.RUN_PER_LEG_DONE  = 30

M.PICKUP_VALUES = {
	plasteel_small   = 1,
	plasteel_large   = 5,
	diamantine_small = 3,
	diamantine_large = 15,
}

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

local function _load_balance()
	if not _mod then return 0 end
	local raw = _mod:get(KEY_BALANCE)
	local n = tonumber(raw) or 0
	if n < 0 then n = 0 end
	return math.floor(n)
end

local function _store_balance(n)
	if not _mod then return end
	_mod:set(KEY_BALANCE, math.floor(n), false)
end

-- History encoded as "source:amount:timestamp,..." bounded to HISTORY_CAP.
-- Timestamp is fixed_time (session seconds) so we can order and diff.
local function _load_history()
	if not _mod then return {} end
	local raw = _mod:get(KEY_HISTORY)
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for entry in string.gmatch(raw, "([^,]+)") do
		local source, amount, ts = string.match(entry, "^(.-):(%-?%d+):(%d+)$")
		if source and amount and ts then
			out[#out + 1] = {
				source = source,
				amount = tonumber(amount) or 0,
				t = tonumber(ts) or 0,
			}
		end
	end
	return out
end

local function _store_history(entries)
	if not _mod then return end
	local parts = {}
	local first = math.max(1, #entries - HISTORY_CAP + 1)
	for i = first, #entries do
		local e = entries[i]
		-- The source is user-facing; strip separators to keep the encoding safe.
		local source = tostring(e.source or ""):gsub("[,:]", "_")
		if source == "" then source = "unknown" end
		parts[#parts + 1] = source .. ":" .. tostring(math.floor(e.amount or 0))
			.. ":" .. tostring(math.floor(e.t or 0))
	end
	_mod:set(KEY_HISTORY, table.concat(parts, ","), false)
end

-- ---------------------------------------------------------------------------
-- Core: earning
-- ---------------------------------------------------------------------------

function M.balance()
	return _load_balance()
end

-- v0.22.80: lifetime Ordos spent (never resets).
function M.total_spent()
	if not _mod then return 0 end
	return tonumber(_mod:get(KEY_TOTAL_SPENT)) or 0
end

-- v0.22.80: wallet-state penance trigger, fired after every balance
-- movement (earn AND spend) so wallet penances (Coffers Full/Bursting,
-- A Rogue Trader's Fortune) land the moment their threshold is
-- crossed instead of waiting for the run-end wallet_update. observe
-- walks the catalogue against a parsed settings string, no disk I/O,
-- so per-pickup frequency is fine.
local function _observe_wallet(balance)
	if not _penances or type(_penances.observe) ~= "function" then return end
	pcall(_penances.observe, "wallet_update", {
		balance = balance,
		total_spent = M.total_spent(),
	})
end

function M.history()
	return _load_history()
end

-- Adds to the wallet, logs to history, emits an event. Amount 0 or negative
-- is silently dropped, since v0.18 has no spending path.
function M.add(amount, source)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end
	source = tostring(source or "unknown")

	local balance = _load_balance() + amount
	_store_balance(balance)

	local hist = _load_history()
	hist[#hist + 1] = {
		source = source,
		amount = amount,
		t = _shared and _shared.fixed_time and _shared.fixed_time() or 0,
	}
	_store_history(hist)

	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "ordos_earned",
			id = _event_log.next_id(),
			amount = amount,
			source = source,
			balance = balance,
		})
	end

	_debug_log("wallet", 0, string.format("+%d Ordos (%s), balance %d",
		amount, source, balance), 0, "info")

	_observe_wallet(balance)  -- v0.22.80

	return balance
end

-- ---------------------------------------------------------------------------
-- Spending
--
-- v0.20.0: the shop lands. spend() debits atomically: if the balance is
-- short, nothing changes and it returns false. Callers must gate on the
-- return before granting whatever they bought, so a race with another
-- Ordos-spending path cannot double-spend.
--
-- The debit is recorded in history as a NEGATIVE amount so /pil_wallet can
-- show both directions on the same timeline. HISTORY_CAP still applies.
-- ---------------------------------------------------------------------------

function M.spend(amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return true end  -- free is fine, no-op

	local balance = _load_balance()
	if balance < amount then return false end

	balance = balance - amount
	_store_balance(balance)

	local hist = _load_history()
	hist[#hist + 1] = {
		source = tostring(reason or "spend"),
		amount = -amount,  -- negative marks a debit
		t = _shared and _shared.fixed_time and _shared.fixed_time() or 0,
	}
	_store_history(hist)

	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared and _shared.fixed_time() or 0,
			event = "ordos_spent",
			id = _event_log.next_id(),
			amount = amount,
			reason = tostring(reason or ""),
			balance = balance,
		})
	end

	_debug_log("wallet", 0, string.format("-%d Ordos (%s), balance %d",
		amount, reason or "", balance), 0, "info")

	-- v0.22.80: grow the lifetime-spent counter and re-check wallet
	-- penances (Theodora's fortune can land on a big purchase).
	if _mod then
		_mod:set(KEY_TOTAL_SPENT, M.total_spent() + amount, false)
	end
	_observe_wallet(balance)

	return true
end

-- ---------------------------------------------------------------------------
-- Named earn events, so the callers (chain.lua, run_state.lua, pickup hook)
-- do not need to know the formulas.
-- ---------------------------------------------------------------------------

-- danger and scale_tier come from difficulty.for_leg.
-- ---------------------------------------------------------------------------
-- v0.22.79: permanent earn multiplier from penances. ADDITIVE stacking
-- per the locked 2026-08-08 decision ("Let's make [multipliers] additive
-- for now"): each earned multiplier penance contributes its bonus to a
-- single sum, so two +5% penances give x1.10, not x1.1025. Applied to
-- the EARN paths only, never to spends, refunds, or debug grants (which
-- call M.add directly). Read live so a penance earned mid-session takes
-- effect on the very next earn.
-- ---------------------------------------------------------------------------

local MULTIPLIER_PENANCES = {
	{ id = "pilgrim_flush", bonus = 0.05 },
	{ id = "pilgrim_coffers_bursting", bonus = 0.10 },
	{ id = "pilgrim_orthus_vindicated", bonus = 0.05 },  -- Saint gate, future
}

-- v0.22.80: earn bonuses granted by having a specific preset in the
-- warband. Theodora's Dynastic Largesse: +50% Ordos earned while the
-- Lord Captain travels with you (Kaizen upgraded from the proposed
-- 10%). Additive with the penance multipliers per the locked rule.
local SLOTTED_PRESET_MULTIPLIERS = {
	{ preset_id = "theodora_von_valancius", bonus = 0.5 },  -- Dynastic Largesse
}

-- True when the preset is bound to an ACTIVE slot (within slot_count)
-- and unlocked, i.e. it will actually spawn. A binding parked on a
-- locked slot or a locked preset earns nothing.
local function _preset_in_warband(preset_id)
	if not _preset or type(_preset.slot_bindings) ~= "function" then return false end
	local ok_map, map = pcall(_preset.slot_bindings)
	if not ok_map or type(map) ~= "table" then return false end
	local limit = 6
	if _bots and type(_bots.slot_count) == "function" then
		local ok_count, count = pcall(_bots.slot_count)
		if ok_count and count then limit = count end
	end
	for slot, id in pairs(map) do
		if id == preset_id and slot <= limit then
			if type(_preset.is_unlocked) == "function" then
				return _preset.is_unlocked(preset_id) ~= false
			end
			return true
		end
	end
	return false
end

local function _earn_multiplier()
	local mult = 1.0
	if _penances and _penances.is_earned then
		for i = 1, #MULTIPLIER_PENANCES do
			local entry = MULTIPLIER_PENANCES[i]
			if _penances.is_earned(entry.id) then
				mult = mult + entry.bonus
			end
		end
	end
	for i = 1, #SLOTTED_PRESET_MULTIPLIERS do
		local entry = SLOTTED_PRESET_MULTIPLIERS[i]
		if _preset_in_warband(entry.preset_id) then
			mult = mult + entry.bonus
		end
	end
	-- v0.22.92: Hazard Pay contract, +50% while active (additive, per
	-- the locked stacking rule). The contract is consumed at the
	-- hub transition AFTER leg payouts, so completion earnings catch it.
	if _shop and _shop.is_active then
		local ok, active = pcall(_shop.is_active, "hazard_pay")
		if ok and active then mult = mult + 0.5 end
	end
	return mult
end

-- Exposed for /pil_wallet diagnostics and the economy audit.
function M.earn_multiplier()
	return _earn_multiplier()
end

local function _apply_multiplier(amount)
	return math.floor((tonumber(amount) or 0) * _earn_multiplier())
end

local function _wager_active(explicit)
	if explicit ~= nil then return explicit == true end
	return _boons and _boons.custom_boon_active
		and _boons.custom_boon_active("pilgrim_doctrine_pilgrims_wager") == true
end

-- Only ordinary mission earnings pass through this gate. Debug grants,
-- penance rewards and other direct M.add callers remain fully exempt.
local function _credit_mission_earn(amount, source, explicit_wager)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	if _wager_active(explicit_wager) and _run_state
		and _run_state.wager_withhold then
		local stake = _run_state.wager_withhold(amount)
		if stake > 0 then
			amount = amount - stake
		end
	end
	return M.add(amount, source)
end

function M.earn_leg_complete(danger, scale_tier, wager_active)
	danger = tonumber(danger) or 2
	scale_tier = tonumber(scale_tier) or 0
	local amount = M.LEG_BASE
		+ M.LEG_PER_DANGER * math.max(0, danger - 1)  -- 1 = Uprising baseline
		+ M.LEG_PER_SCALE  * math.max(0, scale_tier)
	amount = _apply_multiplier(amount)
	return _credit_mission_earn(amount,
		string.format("leg_complete:d%d+s%d", danger, scale_tier), wager_active)
end

-- Called on a full run completion (not a mid-run abandonment).
function M.earn_run_complete(legs_completed, wager_active)
	local amount = M.RUN_BASE + M.RUN_PER_LEG_DONE * math.max(0, legs_completed or 0)
	amount = _apply_multiplier(amount)
	return _credit_mission_earn(amount,
		string.format("run_complete:x%d", legs_completed or 0), wager_active)
end

-- Fired from the pickup hook. type is "plasteel" or "diamantine", size is
-- "small" or "large". Anything unknown is skipped.
function M.earn_pickup(type_name, size_name)
	local key = tostring(type_name) .. "_" .. tostring(size_name)
	local value = M.PICKUP_VALUES[key]
	if not value then return end
	-- v0.22.81: The House Always Wins doubles pickup earnings while
	-- slotted with a run active. Applied BEFORE the percentage
	-- multipliers, so the +5%s work on the doubled base.
	if _boons and _boons.custom_boon_active
		and _boons.custom_boon_active("pilgrim_boon_house_wins") then
		value = value * 2
	end
	return _credit_mission_earn(_apply_multiplier(value), "pickup:" .. key)
end

function M.settle_wager(success)
	if not _run_state or not _run_state.clear_wager_escrow then return 0 end
	local stake = _run_state.clear_wager_escrow()
	if success == true and stake > 0 then
		M.add(stake * 2, "pilgrims_wager:payout")
	end
	return stake
end

-- ---------------------------------------------------------------------------
-- Hook installation: the pickup system. Verified from source:
--   scripts/settings/pickup/pickups/consumable/small_metal_pickup.lua:15
--   scripts/settings/pickup/pickups/consumable/large_metal_pickup.lua:15
--   scripts/settings/pickup/pickups/consumable/small_platinum_pickup.lua:14
--   scripts/settings/pickup/pickups/consumable/large_platinum_pickup.lua:15
-- All call PickupSystem:register_material_collected(pickup_unit,
-- interactor_unit, type, size, ...). Hook-safe: pure observation.
-- ---------------------------------------------------------------------------

local _hooks
local _installed = false

function M.install_pickup_system(PickupSystem)
	if _installed then return end
	if not _hooks or not _mod then return end
	if _hooks.claim(PickupSystem, "__pilgrimage_wallet") then
		_installed = true
		return
	end
	_installed = true

	-- Only count when the mission is a Pilgrimage leg. In a matchmade public
	-- mission (shouldn't happen because we solo-host, but the guard costs
	-- nothing) we do nothing. Also skip when no run is active: a Psykhanium
	-- pickup shouldn't credit.
	_mod:hook_safe(PickupSystem, "register_material_collected",
		function(self, pickup_unit, interactor_unit, type_name, size_name)
			if not (_run_state and _run_state.is_active()) then return end
			if not (_shared and _shared.is_solo_host()) then return end

			-- Only credit when the pickup was OURS. In solo bots exist and
			-- they could technically trigger callbacks; guard on the local
			-- player being the interactor.
			local player_manager = Managers and Managers.player
			if player_manager and interactor_unit then
				local ok, player = pcall(player_manager.player_by_unit, player_manager, interactor_unit)
				if ok and player and player.is_human_controlled
					and not player:is_human_controlled() then
					return
				end
			end

			M.earn_pickup(type_name, size_name)
		end)
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

function M.summary()
	local hist = _load_history()
	local by_source = {}
	for i = 1, #hist do
		local e = hist[i]
		local key = e.source:match("^([^:]+)") or e.source
		by_source[key] = (by_source[key] or 0) + e.amount
	end
	return {
		balance  = _load_balance(),
		entries  = #hist,
		by_source = by_source,
	}
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_event_log = deps.event_log
	_run_state = deps.run_state
	_fileio = deps.fileio
	-- v0.22.79: optional (only read at earn time), so init order vs
	-- Penances does not matter.
	_penances = deps.penances
	-- v0.22.80: optional, same reasoning (Dynastic Largesse).
	_preset = deps.preset
	_bots = deps.bots
	-- v0.22.81: optional (House Always Wins).
	_boons = deps.boons
	-- v0.22.92: Hazard Pay reads the shop at earn time only.
	_shop = deps.shop
	_debug_log = deps.debug_log or function() end
end

return M
