-- launcher.lua
--
-- Starts a mission without matchmaking, and advances a run from one leg to the next.
--
-- This is the riskiest module in the mod. It tears down the current session and
-- rebuilds it, and getting the ordering wrong crashes the game rather than failing
-- politely. Every guard here earns its place.
--
-- ===========================================================================
-- THE LAUNCH CHAIN
-- ===========================================================================
--
--   Managers.multiplayer_session:reset(reason)
--   Managers.multiplayer_session:boot_singleplayer_session()
--   -- poll until the old session is actually leaving
--   Managers.mechanism:change_mechanism(mechanism_name, mission_context)
--   Managers.mechanism:trigger_event("all_players_ready")
--
-- Verified against decompiled 1.12.3:
--   multiplayer_session_manager.lua:136   boot_singleplayer_session
--   multiplayer_session_manager.lua:307   session_boot.leaving_game_session is set here
--   mechanism_manager.lua:239             change_mechanism(mechanism_name, context)
--   mechanism_adventure.lua:34-70         reads mission_name, challenge, resistance,
--                                         circumstance_name, side_mission, havoc_data
--                                         off the context
--
-- Two ordering rules, both learned from SoloPlay, both of which crash if broken:
--
--   1. You MUST wait for `_session_boot.leaving_game_session` before changing
--      mechanism. Tearing down the old session is asynchronous.
--
--   2. If a view is open you MUST close it and wait for
--      `Managers.ui:view_active(name)` to go false BEFORE launching. Doing it inline
--      crashes.
--
-- `trigger_event("all_players_ready")` is what kicks the mechanism state machine out
-- of its `*_selected` state into loading. Without it nothing happens and you sit
-- there.

local M = {}

local _mod
local _shared
local _missions
local _run_state
local _event_log
local _debug_log
local _settings
-- Declared here at the top, above every function, because a Lua function only
-- captures locals that exist above its definition (the v0.14.1 boons lesson).
local _curses
local _difficulty
local _shop
local _war_plans
local _terminal
local _realms_bridge

-- Set while a launch is in flight, so a second command or a stray keypress cannot
-- start two teardowns at once.
local _launching = false
local _launch_started_t = 0
local LAUNCH_TIMEOUT_S = 30

-- ---------------------------------------------------------------------------
-- Guards
-- ---------------------------------------------------------------------------

-- Where a launch is allowed from. The hub and the Psykhanium are both safe; being
-- inside a real mission is not, because we would be yanking other systems out from
-- under themselves mid-objective.
function M.can_launch()
	if _launching then return false, "a launch is already in progress" end
	local api = _mod and _mod.pilgrimage_route_api
	if api and api.ensure_character and not api.ensure_character() then
		return false, "operative not available yet"
	end
	if _realms_bridge and _realms_bridge.can_launch then
		local compatible, reason = _realms_bridge.can_launch()
		if not compatible then return false, reason end
	end

	local mode = _shared.game_mode_name()
	if not mode then return false, "no game mode yet" end

	if _shared.is_in_hub() then return true end
	if _shared.is_in_psykhanium() then return true end

	-- A running Realms host is not a Darktide "singleplay" host. Let its host
	-- advance the pilgrimage, then use Realms' own transition API below so the
	-- connected humans stay in the same player-hosted session.
	if _realms_bridge and _realms_bridge.is_host
		and _realms_bridge.is_host() then
		return true
	end

	-- Already inside a solo mission: allowed, because that is how a run advances
	-- from one leg to the next.
	if _shared.is_solo_host() then return true end

	return false, "not in the hub, the Psykhanium, or a solo session (mode: " .. tostring(mode) .. ")"
end

function M.is_launching()
	return _launching
end

-- ---------------------------------------------------------------------------
-- The launch itself
-- ---------------------------------------------------------------------------

local function clear_launching(reason)
	_launching = false
	_debug_log("launch_clear", _shared.fixed_time(),
		"launch flag cleared: " .. tostring(reason), 0, "info")
end

-- context      the table from missions.build_context
-- mechanism    the mechanism name read off the mission template
function M.launch_context(context, mechanism_name)
	local allowed, why = M.can_launch()
	if not allowed then
		return false, why
	end

	if type(context) ~= "table" or not context.mission_name then
		return false, "no mission context"
	end

	local session = Managers and Managers.multiplayer_session
	local mechanism_manager = Managers and Managers.mechanism
	local Promise = rawget(_G, "Promise")

	if not session then return false, "no multiplayer_session manager" end
	if not mechanism_manager then return false, "no mechanism manager" end
	if not Promise then return false, "Promise global unavailable" end

	mechanism_name = mechanism_name or "adventure"

	_launching = true
	_launch_started_t = _shared.fixed_time()

	_event_log.emit({
		t = _launch_started_t,
		event = "launch_begin",
		id = _event_log.next_id(),
		mission = context.mission_name,
		mechanism = mechanism_name,
		challenge = context.challenge,
		resistance = context.resistance,
		circumstance = context.circumstance_name,
	})

	_debug_log("launch", _launch_started_t,
		"launching " .. tostring(context.mission_name) ..
		" (" .. mechanism_name .. ")", 0, "info")

	-- Written down BEFORE the teardown starts, because the level load ahead
	-- wipes every byte of Lua memory on both sides. The mission-side guard
	-- (mutator_guard.lua) reads this back to verify the engine is running the
	-- circumstance this launch actually asked for, and to restore it if the
	-- engine lost it on the way through the load.
	if _run_state.record_launch then
		_run_state.record_launch(context.mission_name, context.circumstance_name)
	end

	-- Once the first Realms mission is running, Realms owns the transition.
	-- Resetting and booting another single-player session here would disconnect
	-- every guest. The public queue API exits the current gameplay cleanly,
	-- preserves the listen host, and opens Realms' preparation screen for the
	-- next leg.
	if _realms_bridge and _realms_bridge.is_host
		and _realms_bridge.is_host()
		and _realms_bridge.queue_mission_transition then
		local queued, queue_error =
			_realms_bridge.queue_mission_transition(context)
		if not queued then
			clear_launching("Realms transition rejected")
			_event_log.emit({
				t = _shared.fixed_time(), event = "launch_failed",
				id = _event_log.next_id(), reason = tostring(queue_error),
			})
			return false, tostring(queue_error)
		end

		clear_launching("Realms transition queued")
		return true
	end

	-- Persist before session teardown. Terminal clears this only after the next
	-- hub player is physics-safely moved beside it, regardless of mission result.
	if _terminal and type(_terminal.request_return) == "function" then
		-- false means PREPARED, not yet eligible for a return teleport. The
		-- mission-side terminal tick promotes it after confirming the exact leg.
		pcall(_terminal.request_return, false)
	end

	local ok, err = pcall(function()
		-- Pilgrimage uses SoloPlay's low-level launch sequence rather than
		-- start_singleplayer_session, so Realms would otherwise open its listener
		-- without knowing which mission it is preparing.
		if _realms_bridge and _realms_bridge.prepare_local_mission then
			_realms_bridge.prepare_local_mission(context.mission_name)
		end

		session:reset("Pilgrimage launching a solo session")
		session:boot_singleplayer_session()

		-- Poll until the previous session is genuinely on its way out. Changing
		-- mechanism before this point crashes on the ordinary SoloPlay path.
		--
		-- Realms needs two distinct stages. Its ready boot is the point at which the
		-- first mechanism change can safely make the old hub exit. After the Realms
		-- connection host is installed, the same context is submitted again; Realms
		-- then owns that clean copy and releases it after the Ready countdown.
		local realms_boot_launch = false
		Promise.until_true(function()
			local boot = session._session_boot
			if not boot then return false end
			if boot.leaving_game_session == true then return true end

			if boot.__class_name == "RealmsHostSessionBoot"
				and type(boot.state) == "function" then
				local state_ok, state_name = pcall(boot.state, boot)
				if state_ok and state_name == "ready" then
					realms_boot_launch = true
					return true
				end
			end

			return false
		end):next(function()
			local changed, change_err = pcall(function()
				mechanism_manager:change_mechanism(mechanism_name, context)
				mechanism_manager:trigger_event("all_players_ready")
			end)

			if not changed then
				_mod:error("Pilgrimage: change_mechanism failed: " .. tostring(change_err))
				_event_log.emit({
					t = _shared.fixed_time(), event = "launch_failed",
					id = _event_log.next_id(), reason = tostring(change_err),
				})
				clear_launching("mechanism change failed")
				return
			end

			if not realms_boot_launch then
				clear_launching("mechanism changed")
				return
			end

			-- The early request above is what visibly leaves the hub. Re-arm the
			-- mission after Realms becomes the installed host. If the hub game session
			-- still exists, Realms defers this request until teardown; if teardown has
			-- already finished, it applies it immediately. In both cases the Ready
			-- screen retains a fresh adventure_selected transition to release.
			Promise.until_true(function()
				return _realms_bridge and _realms_bridge.is_host
					and _realms_bridge.is_host() or false
			end):next(function()
				local rearmed, rearm_err = pcall(function()
					mechanism_manager:change_mechanism(mechanism_name, context)
					mechanism_manager:trigger_event("all_players_ready")
				end)
				if not rearmed then
					_mod:error("Pilgrimage: Realms mission re-arm failed: "
						.. tostring(rearm_err))
					_event_log.emit({
						t = _shared.fixed_time(), event = "launch_failed",
						id = _event_log.next_id(), reason = tostring(rearm_err),
					})
					clear_launching("Realms mission re-arm failed")
					return
				end
				_debug_log("realms_launch_rearmed", _shared.fixed_time(),
					"Realms owns the prepared transition for "
						.. tostring(context.mission_name), 0, "info")
				clear_launching("Realms mission re-armed")
			end)
		end)
	end)

	if not ok then
		clear_launching("threw")
		_mod:error("Pilgrimage: launch threw: " .. tostring(err))
		_event_log.emit({
			t = _shared.fixed_time(), event = "launch_failed",
			id = _event_log.next_id(), reason = tostring(err),
		})
		return false, tostring(err)
	end

	return true
end

-- Convenience: build the context and launch in one call.
function M.launch(mission_name, danger_level, circumstance_name, extra)
	local context, err, mechanism_name =
		_missions.build_context(mission_name, danger_level, circumstance_name, extra)
	if not context then return false, err end
	return M.launch_context(context, mechanism_name)
end

-- ---------------------------------------------------------------------------
-- Run advancement
--
-- Deliberately NOT automatic yet. Auto-chaining fires on mission end, and a bug there
-- would drag someone into a mission they did not ask for. It stays behind a setting
-- that defaults off until the single-launch path is proven in game.
-- ---------------------------------------------------------------------------

function M.launch_current_leg()
	local state = _run_state.get()
	if not state.active then return false, "no active run" end

	local mission_name = _run_state.current_mission()
	if not mission_name then return false, "run has no current mission" end

	if not _missions.exists(mission_name) then
		return false, "mission '" .. tostring(mission_name) .. "' no longer exists in this game version"
	end

	-- Per-leg difficulty ramp (v0.18.0). state.starting_difficulty was set
	-- at run start; the ramp climbs from there. Above Damnation, the extra
	-- scaling rides two channels: enemy HP goes into pilgrimage_stacked's
	-- minion_health_modifier (read by minion_spawn_manager), enemy attack
	-- speed is applied per-spawn by scaling_hook.
	local diff = _difficulty and _difficulty.for_leg
		and _difficulty.for_leg(state.index, state.starting_difficulty)
		or nil
	local danger = (diff and diff.danger) or state.danger or 3
	local scale_tier = (diff and diff.scale_tier) or 0

	-- v0.20.0 / v0.22.34: shop consumables that shape THIS leg's curse.
	--
	--   curse_skip   PERMANENTLY replace THIS leg's curse with "default"
	--                in state.curse_queue. Kaizen's spec: "whatever
	--                modifier you skip, it doesn't get applied to the
	--                run at all, while those that were not skipped still
	--                do." So skip mutates the queue at this index and
	--                every future leg's stacking-prefix computation
	--                naturally excludes it (curses.stack_curses filters
	--                "default" entries out). Consumed on apply.
	--
	--   curse_reroll re-rolls THIS leg's curse from the pool, using a
	--                per-leg re-seed so the same run always re-rolls to
	--                the same replacement. Only applies to this leg; the
	--                original curse still contributes to stacking on
	--                future legs (skip is the tool for a permanent
	--                removal).
	--
	-- Both consume on apply. Refunds are not offered; a run that ends
	-- before you play the leg you bought a modifier for is a run that
	-- spent its Ordos on something it did not enjoy, which is the same
	-- rule as the boons. But if you never LAUNCH (leave the terminal
	-- without pressing Begin/Continue), the purchase is unspent and
	-- stays in the shop's active set across sessions.
	local override_curse = nil

	if _shop then
		if _shop.is_active("curse_skip") then
			-- Rewrite the queue permanently. current_curse() will now
			-- return nil for this leg, prefix() will emit "default" at
			-- this index (which stack_curses drops), and later legs
			-- get the correct reduced stacking automatically.
			if _run_state.set_curse_at then
				_run_state.set_curse_at(state.index, "default")
			end
			_shop.consume("curse_skip")
			_debug_log("launcher", 0,
				string.format("Skip consumed: leg %d curse permanently set to default",
					state.index), 0, "info")
		elseif _shop.is_active("curse_reroll") then
			if _curses and _curses.reroll_for_leg then
				-- v0.20.3: honor the plan's tier range so the reroll
				-- draws from the same pool the run started with. If
				-- the run has no plan (legacy) we pass nil and the
				-- reroll falls back to its own severity logic.
				local plan = _war_plans and state.plan_id
					and state.plan_id ~= ""
					and _war_plans.get(state.plan_id) or nil
				local min_tier = plan and plan.min_tier
				local max_tier = plan and plan.max_tier
				local total = plan and plan.leg_count or #state.queue
					-- v0.22.35: pass state.curse_queue as an exclude set so
				-- the reroll never lands on a curse already present in
				-- the run (which would silently duplicate itself into
				-- stacking on the next leg). "default" entries in the
				-- queue are auto-filtered inside reroll_for_leg.
				override_curse = _curses.reroll_for_leg(state.seed, state.index,
					min_tier, max_tier, total, state.curse_queue)
			end
			_shop.consume("curse_reroll")
		end
	end

	-- Note: no `skip_curse` branch below anymore. Skip already mutated
	-- the queue; the normal prefix / stacking path picks that up and
	-- naturally emits "default" for the skipped leg. Fewer special
	-- cases, one source of truth (state.curse_queue).
	local prefix = _run_state.curse_prefix and _run_state.curse_prefix() or nil
	if override_curse and prefix and #prefix > 0 then
		-- Replace the tail of the prefix (the current leg) with the
		-- reroll override. Stacking still folds in earlier legs' curses.
		prefix[#prefix] = override_curse
	end

	-- The mission name travels with the synthetic circumstance request so
	-- curses.lua can apply narrow map-specific safety exclusions without
	-- changing the saved route or curse. This is metadata only; difficulty
	-- scaling still uses the same health-modifier field as before.
	local extras = { mission_name = mission_name }
	if scale_tier > 0 and _difficulty then
		extras.minion_health_modifier = _difficulty.minion_health_modifier_for(scale_tier)
	end

	-- stacked_for now folds in the HP-scaling modifier when passed extras,
	-- and builds pilgrimage_stacked even for a single curse if there's
	-- scaling to add. Below Damnation with no stack, it declines and we
	-- fall through to the plain single-curse path.
	local stacked = _curses and _curses.stacked_for
		and _curses.stacked_for(prefix, extras)
	local circumstance = override_curse or _run_state.current_curse()
		or state.circumstance or "default"
	if _curses and type(_curses.launchable_name) == "function" then
		circumstance = _curses.launchable_name(circumstance)
	end
	circumstance = stacked or circumstance

	return M.launch(mission_name, danger, circumstance)
end

function M.advance_and_launch(result)
	local next_mission = _run_state.advance(result or "complete")
	if not next_mission then
		_event_log.emit({
			t = _shared.fixed_time(), event = "run_complete", id = _event_log.next_id(),
		})
		_shared.notify("Pilgrimage: run complete")
		return false, "run finished"
	end
	return M.launch_current_leg()
end

-- ---------------------------------------------------------------------------
-- Watchdog
--
-- If a launch never completes (the promise never resolves because the session got
-- stuck) the flag would block every future launch for the rest of the session.
-- Registered as a tick task by bootstrap.
-- ---------------------------------------------------------------------------

function M.tick(t)
	if not _launching then return end
	if t - _launch_started_t < LAUNCH_TIMEOUT_S then return end

	clear_launching("timed out after " .. LAUNCH_TIMEOUT_S .. "s")
	_shared.notify("Pilgrimage: launch timed out", "alert")
	_event_log.emit({
		t = t, event = "launch_timeout", id = _event_log.next_id(),
	})
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_missions = deps.missions
	_run_state = deps.run_state
	_event_log = deps.event_log
	_settings = deps.settings
	_curses = deps.curses
	_difficulty = deps.difficulty
	_shop = deps.shop
	_war_plans = deps.war_plans
	_terminal = deps.terminal
	_realms_bridge = deps.realms_bridge
	_debug_log = deps.debug_log or function() end
end

return M
