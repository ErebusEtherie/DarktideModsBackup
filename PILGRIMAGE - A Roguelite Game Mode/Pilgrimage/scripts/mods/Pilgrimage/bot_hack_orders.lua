-- bot_hack_orders.lua
--
-- Makes Skitarii bots (Magos Haneumann + any other cryptic preset
-- Kaizen adds later) auto-dispatch their servo skull at stalled data
-- interrogators.
--
-- ===========================================================================
-- WHY THIS EXISTS
-- ===========================================================================
--
-- Fatshark's bot behavior tree does not interact with mission objective
-- props. Bots follow, shoot, revive, use grenades, but they never plant a
-- data interrogator, hack a device, or start any interactable minigame.
-- Better Bots agrees with that design and stays out of objective
-- interaction too.
--
-- The Skitarii's servo skull is a rare exception because it does not
-- require the player to physically stand at the interactable. In
-- vanilla, a Skitarii double-taps ping ("companion order") on a
-- decoding interactable, and the game's smart tag template
-- `hacking_over_here_companion` fires
-- CompanionServoSkullAbility.start_hacking_ability, which flies the
-- skull to the target and completes the minigame automatically.
--
-- That mechanism is entirely data-driven: whoever calls
-- SmartTagSystem:set_contextual_unit_tag(tagger, target, alternate=true)
-- with a Skitarii tagger and a decoding target gets the skull dispatch,
-- no matter whether the tagger is a human clicking Q or a bot doing it
-- programmatically. So we can bolt objective completion onto Skitarii
-- bots without ever touching a behavior tree.
--
-- ===========================================================================
-- DETECTION
-- ===========================================================================
--
-- Every tick (2s cadence via tick.lua) we iterate
--   Managers.state.extension:system("interactee_system"):unit_to_extension_map()
-- filter to entries whose interaction_type() == "decoding" and whose
-- can_interact(interactor, "decoding") is true, then for each candidate
-- pick the nearest Skitarii bot with a live servo skull and issue the
-- contextual tag.
--
-- Cooldowns:
--   Per interactable: 12s (skull flight + hack + a buffer, so we don't
--                          fire twice while the skull is still working)
--   Per bot:           4s (skull channel; a spammed tag would just cancel
--                          the previous order)
--
-- Distance: only tag interactables within 40m of the bot. Line of sight
-- is NOT required because the skull flies over walls and around corners
-- (it is a companion, not a projectile).
--
-- ===========================================================================
-- FAIL-SAFES
-- ===========================================================================
--
-- Every call into the extension system is pcall-guarded. On any failure
-- we back off that (interactable, bot) pair for 30s and log once. The
-- game must never be blocked or crash because our scanner miscounted.
-- Missing extensions, missing special_rules table, missing companion
-- spawner, all silently no-op.
--
-- Kill switch: settings toggle `enable_bot_hack_orders` (default on).
-- If the checkbox is off, the tick task does nothing.

local M = {}

local _mod
local _shared
local _debug_log

-- Weak-keyed cooldowns so unit death cleans them up automatically.
local _interactable_cooldown_until = setmetatable({}, { __mode = "k" })
local _bot_cooldown_until          = setmetatable({}, { __mode = "k" })
local _failure_backoff_until       = setmetatable({}, { __mode = "k" })

local INTERACTABLE_COOLDOWN_S = 12.0
local BOT_COOLDOWN_S          = 4.0
local FAILURE_BACKOFF_S       = 30.0
local MAX_TAG_DISTANCE_M      = 40.0
local MAX_TAG_DISTANCE_SQ     = MAX_TAG_DISTANCE_M * MAX_TAG_DISTANCE_M

-- Cached at first use. False means "attempted to load and failed, do
-- not retry every tick"; nil means "not attempted yet".
local _servo_skull_hack_rule

local function _fetch_special_rule()
	if _servo_skull_hack_rule ~= nil then
		return _servo_skull_hack_rule or nil
	end
	local ok, mod = pcall(require, "scripts/settings/ability/special_rules_settings")
	if not ok or type(mod) ~= "table" then
		_servo_skull_hack_rule = false
		return nil
	end
	local rules = mod.special_rules
	local value = rules and rules.cryptic_servo_skull_hack
	if value == nil then
		_servo_skull_hack_rule = false
		return nil
	end
	_servo_skull_hack_rule = value
	return value
end

-- ===========================================================================
-- Enablement
-- ===========================================================================
--
-- Cheap gate: DMF checkbox. Called every tick, so it's a raw settings
-- read with no logging. Default handled in settings.lua.

local function _enabled()
	if not _mod or type(_mod.get) ~= "function" then return true end
	local v = _mod:get("enable_bot_hack_orders")
	if v == nil then return true end
	return v == true
end

-- ===========================================================================
-- Bot enumeration
-- ===========================================================================

local function _iter_bot_units()
	-- Managers.player:bot_players() returns { [unique_id] = BotPlayer }.
	-- Each BotPlayer exposes :player_unit(), which is nil early in the
	-- spawn cycle and after death; the caller must handle both.
	local Managers = rawget(_G, "Managers")
	local player_manager = Managers and Managers.player
	if not player_manager or type(player_manager.bot_players) ~= "function" then
		return function() return nil end
	end
	local ok, bots = pcall(player_manager.bot_players, player_manager)
	if not ok or type(bots) ~= "table" then
		return function() return nil end
	end
	local list = {}
	for _, bot in pairs(bots) do
		if bot and type(bot.player_unit) == "function" then
			local ok_unit, unit = pcall(bot.player_unit, bot)
			if ok_unit and unit then
				list[#list + 1] = unit
			end
		end
	end
	local idx = 0
	return function()
		idx = idx + 1
		return list[idx]
	end
end

-- Returns the servo skull companion unit for this bot, or nil.
--
-- We check three things because any one being missing means the bot
-- either isn't a Skitarii or doesn't have the servo skull blitz
-- equipped:
--   1. talent_system extension is present AND has the special rule
--      (cryptic_servo_skull_hack). This gates on the blitz being
--      slotted; a Skitarii running arc grenades won't pass.
--   2. companion_spawner_system extension is present.
--   3. spawned_unit_lookup(rule) returns a live unit. The skull can
--      be dead / not yet spawned briefly.
local function _bot_servo_skull(bot_unit)
	local rule = _fetch_special_rule()
	if not rule then return nil end
	local talent_ext = ScriptUnit.has_extension(bot_unit, "talent_system")
	if not talent_ext or type(talent_ext.has_special_rule) ~= "function" then
		return nil
	end
	local ok_has, has = pcall(talent_ext.has_special_rule, talent_ext, rule)
	if not ok_has or not has then return nil end

	local spawner_ext = ScriptUnit.has_extension(bot_unit, "companion_spawner_system")
	if not spawner_ext or type(spawner_ext.spawned_unit_lookup) ~= "function" then
		return nil
	end
	local ok_lookup, skull = pcall(spawner_ext.spawned_unit_lookup, spawner_ext, rule)
	if not ok_lookup or not skull then return nil end
	local ALIVE = rawget(_G, "ALIVE")
	if ALIVE and not ALIVE[skull] then return nil end
	return skull
end

-- ===========================================================================
-- Interactable enumeration
-- ===========================================================================

local function _iter_decoding_interactables()
	local Managers = rawget(_G, "Managers")
	local extension_manager = Managers and Managers.state and Managers.state.extension
	if not extension_manager or type(extension_manager.system) ~= "function" then
		return function() return nil end
	end
	local ok_sys, system = pcall(extension_manager.system, extension_manager, "interactee_system")
	if not ok_sys or not system then
		return function() return nil end
	end
	-- ExtensionSystemBase exposes unit_to_extension_map(): { unit → ext }.
	-- If Fatshark ever renames this, everything below silently no-ops.
	local map
	if type(system.unit_to_extension_map) == "function" then
		local ok, m = pcall(system.unit_to_extension_map, system)
		if ok then map = m end
	end
	if not map then
		-- Direct field access as a fallback (v1.12.x has both).
		map = system._unit_to_extension_map
	end
	if type(map) ~= "table" then
		return function() return nil end
	end

	local ALIVE = rawget(_G, "ALIVE")
	local pending = {}
	for unit, ext in pairs(map) do
		if unit and ext
			and (not ALIVE or ALIVE[unit])
			and type(ext.interaction_type) == "function"
		then
			local ok_type, itype = pcall(ext.interaction_type, ext)
			if ok_type and itype == "decoding" then
				-- A decoding interaction also exists while a decoder is being
				-- installed for the first time. Pilgrimage must only repair an
				-- interrogator that has already started and then stalled.
				local decoder_ext = ScriptUnit.has_extension(unit,
					"decoder_device_system")
				local interrupted = false
				if decoder_ext and type(decoder_ext.decoding_interrupted) == "function" then
					local ok_interrupted, value = pcall(
						decoder_ext.decoding_interrupted, decoder_ext)
					interrupted = ok_interrupted and value == true
				end
				if interrupted then
					pending[#pending + 1] = { unit = unit, ext = ext }
				end
			end
		end
	end
	local idx = 0
	return function()
		idx = idx + 1
		local entry = pending[idx]
		if not entry then return nil end
		return entry.unit, entry.ext
	end
end

-- ===========================================================================
-- Distance + eligibility
-- ===========================================================================

local function _sqr_distance(a_unit, b_unit)
	local Unit = rawget(_G, "Unit")
	local POSITION_LOOKUP = rawget(_G, "POSITION_LOOKUP")
	local pa = POSITION_LOOKUP and POSITION_LOOKUP[a_unit] or nil
	local pb = POSITION_LOOKUP and POSITION_LOOKUP[b_unit] or nil
	if not pa and Unit and Unit.alive and Unit.alive(a_unit) then
		pa = Unit.world_position(a_unit, 1)
	end
	if not pb and Unit and Unit.alive and Unit.alive(b_unit) then
		pb = Unit.world_position(b_unit, 1)
	end
	if not pa or not pb then return nil end
	local dx = pa.x - pb.x
	local dy = pa.y - pb.y
	local dz = pa.z - pb.z
	return dx * dx + dy * dy + dz * dz
end

-- Can this interactable currently accept a NEW decoding interaction?
-- Fatshark's can_interact(unit, "decoding") returns false while someone
-- (human or skull) is already decoding, and also false when the
-- interactable is not yet armed / already completed. So this single
-- check covers "not busy" + "not done" + "ready for someone".
local function _can_be_hacked(interactable_unit, interactee_ext)
	if type(interactee_ext.can_interact) ~= "function" then return false end
	-- Fatshark's servo-skull validator deliberately passes the target unit
	-- as the interactor here. Passing the bot makes this test fail even though
	-- a human double-ping on the same stalled interrogator succeeds.
	local ok, can = pcall(interactee_ext.can_interact, interactee_ext,
		interactable_unit, "decoding")
	return ok and can == true
end

-- ===========================================================================
-- Dispatch
-- ===========================================================================

local function _dispatch(bot_unit, interactable_unit, t)
	local Managers = rawget(_G, "Managers")
	local extension_manager = Managers and Managers.state and Managers.state.extension
	local ok_sys, smart_tag_system = pcall(extension_manager.system, extension_manager, "smart_tag_system")
	if not ok_sys or not smart_tag_system then return false, "no_smart_tag_system" end
	if type(smart_tag_system.set_contextual_unit_tag) ~= "function" then
		return false, "api_missing"
	end
	-- alternate="companion_order" selects the companion-order branch in
	-- SmartTagExtension:contextual_tag_template, which for a Skitarii
	-- tagger + decoding target resolves to hacking_over_here_companion.
	-- That template's start() function calls
	-- CompanionServoSkullAbility.start_hacking_ability, which sets the
	-- skull's whistle_component.current_hack_target and transitions it
	-- into the hacking state. No further input needed from us.
	local ok_call, err = pcall(
		smart_tag_system.set_contextual_unit_tag,
		smart_tag_system,
		bot_unit,
		interactable_unit,
		"companion_order"
	)
	if not ok_call then
		return false, tostring(err)
	end
	return true, nil
end

-- ===========================================================================
-- Tick entry point
-- ===========================================================================

local _last_run_summary_logged_t = 0

function M.tick(t, _dt)
	if not _enabled() then return end
	local rule = _fetch_special_rule()
	if not rule then return end

	-- Cheap early-out: no bots present (menu, hub) means the extension
	-- map iteration is wasted work.
	local first_bot_unit
	do
		local iter = _iter_bot_units()
		first_bot_unit = iter()
		if not first_bot_unit then return end
	end

	-- Collect Skitarii bots with a live servo skull, exactly once
	-- per tick.
	local skitarii_bots = {}
	do
		for bot_unit in _iter_bot_units() do
			if _bot_servo_skull(bot_unit) then
				skitarii_bots[#skitarii_bots + 1] = bot_unit
			end
		end
	end
	if #skitarii_bots == 0 then return end

	local dispatched = 0
	local considered = 0
	for interactable_unit, interactee_ext in _iter_decoding_interactables() do
		considered = considered + 1

		if (_interactable_cooldown_until[interactable_unit] or 0) <= t
			and (_failure_backoff_until[interactable_unit] or 0) <= t
		then
			-- Pick the nearest eligible bot for this interactable.
			local best_bot, best_dist_sq
			for i = 1, #skitarii_bots do
				local bot = skitarii_bots[i]
				if (_bot_cooldown_until[bot] or 0) <= t then
					local d = _sqr_distance(bot, interactable_unit)
					if d and d <= MAX_TAG_DISTANCE_SQ then
						if not best_dist_sq or d < best_dist_sq then
							best_dist_sq = d
							best_bot = bot
						end
					end
				end
			end

			if best_bot and _can_be_hacked(interactable_unit, interactee_ext) then
				local ok, err = _dispatch(best_bot, interactable_unit, t)
				if ok then
					_interactable_cooldown_until[interactable_unit] = t + INTERACTABLE_COOLDOWN_S
					_bot_cooldown_until[best_bot]                   = t + BOT_COOLDOWN_S
					dispatched = dispatched + 1
					_debug_log("bot_hack_orders", t,
						"dispatched servo skull hack (bot=" .. tostring(best_bot)
						.. ", target=" .. tostring(interactable_unit) .. ")",
						0, "info")
				else
					_failure_backoff_until[interactable_unit] = t + FAILURE_BACKOFF_S
					_debug_log("bot_hack_orders_fail", t,
						"dispatch failed on " .. tostring(interactable_unit)
						.. " (" .. tostring(err) .. "); backing off " .. FAILURE_BACKOFF_S .. "s",
						30, "warn")
				end
			end
		end
	end

	-- Throttled visibility log so /pil_log_level trace can see the
	-- scanner running without spamming.
	if considered > 0 and (t - _last_run_summary_logged_t) >= 30 then
		_last_run_summary_logged_t = t
		_debug_log("bot_hack_orders_scan", t,
			"scan: " .. tostring(considered) .. " decoding interactable(s), "
			.. tostring(dispatched) .. " tag(s) dispatched, "
			.. tostring(#skitarii_bots) .. " Skitarii bot(s) with skull",
			0, "trace")
	end
end

-- ===========================================================================
-- Init
-- ===========================================================================

function M.init(deps)
	_mod       = deps.mod
	_shared    = deps.shared
	_debug_log = deps.debug_log or function() end
	-- Fresh cooldown tables per init so a mission restart doesn't
	-- carry over old (now stale) cooldowns.
	_interactable_cooldown_until = setmetatable({}, { __mode = "k" })
	_bot_cooldown_until          = setmetatable({}, { __mode = "k" })
	_failure_backoff_until       = setmetatable({}, { __mode = "k" })
end

return M
