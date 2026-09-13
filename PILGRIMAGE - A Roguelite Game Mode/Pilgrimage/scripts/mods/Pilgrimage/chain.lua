-- chain.lua
--
-- Turns a queue of missions into a run: detect that a leg ended, record how it ended,
-- and launch the next one.
--
-- ===========================================================================
-- WHERE THE OUTCOME COMES FROM
-- ===========================================================================
--
-- game_mode_manager.lua:381-411. Every frame the manager asks the game mode whether
-- the run is over, and on the first yes it records the outcome and announces it:
--
--     local end_conditions_met, outcome = game_mode:evaluate_end_conditions()
--     if end_conditions_met then self:_set_end_conditions_met(outcome) end
--
--     GameModeManager._set_end_conditions_met = function (self, outcome)
--         self._end_conditions_met = true
--         self._end_conditions_met_outcome = outcome
--         ...
--         Managers.mechanism:trigger_event("game_mode_end", outcome, session_id)
--
-- We hook `_set_end_conditions_met` with hook_safe, so we observe the outcome without
-- being able to interfere with it. Outcome values come from
-- NetworkLookup.game_mode_outcomes; we treat anything that is not a win as a loss
-- rather than hardcoding the vocabulary.
--
-- ===========================================================================
-- WHY WE DO NOT LAUNCH IMMEDIATELY
-- ===========================================================================
--
-- End conditions fire while you are still standing in the level, before the outro
-- cinematic and the end-of-round screen. Tearing the session down at that moment
-- would cut off the cinematic Kaizen confirmed plays correctly.
--
-- So we RECORD the outcome, let the game do its normal end sequence all the way back
-- to the Mourningstar, and launch the next leg from there. That gives:
--
--     play -> outro_win -> end screen -> Mourningstar -> next leg loads
--
-- which is the chapter-break feel, and it uses the game's own flow rather than
-- fighting it.

local M = {}

local _mod
local _shared
local _hooks
local _missions
local _run_state
local _launcher
local _event_log
local _settings
local _curses
local _difficulty
local _wallet
local _penances
local _shop
local _boons
local _debug_log

local SENTINEL = "__pilgrimage_chain_installed"

-- Set when a leg ends, consumed when we get back to the hub.
local _pending = nil

-- Rising-edge detector for arriving in the hub.
local _was_in_hub = false

-- Small delay after reaching the hub before launching, so the hub finishes settling
-- and the player sees where they are for a moment.
local HUB_SETTLE_S = 3
local _hub_arrived_t = nil

-- ---------------------------------------------------------------------------
-- Outcome capture
-- ---------------------------------------------------------------------------

-- The engine's own vocabulary, read from NetworkLookup at runtime rather than
-- assumed. Anything not recognised as a win counts as a loss, which is the safe
-- direction: a run should not silently continue past a failure.
local function outcome_is_win(outcome)
	if outcome == nil then return false end
	local text = tostring(outcome):lower()
	return text == "won" or text == "win" or text == "success" or text == "completed"
end

M.outcome_is_win = outcome_is_win

-- ---------------------------------------------------------------------------
-- Is this end OURS?
--
-- The hook fires whenever ANY game mode decides it is finished. That includes the
-- Psykhanium, which ends its own mode when you walk out of it.
--
-- With no gate, walking out of the Psykhanium mid-run looked exactly like finishing a
-- leg: a pending result was recorded, and the moment the Mourningstar settled the chain
-- advanced the run and launched a mission the player never asked for. That is the
-- teleport-out-of-the-Psykhanium bug, and the same hole would let any manually launched
-- mission advance the pilgrimage too.
--
-- Three checks, cheapest first. The mission name is the real one: the game mode name
-- cannot tell a pilgrimage leg apart from a mission the player queued themselves, but
-- the mission name can.
-- ---------------------------------------------------------------------------

function M.is_run_mission()
	if _shared.is_in_hub() then return false, "in hub" end
	if _shared.is_in_psykhanium() then return false, "in psykhanium" end

	local expected = _run_state.current_mission()
	local actual = _shared.mission_name()

	-- No name available. Fall through rather than block, because the two checks above
	-- already cover the reported failure and refusing here would break leg tracking
	-- entirely on any build where the mission manager is shaped differently.
	if not expected or not actual then return true, "unverified" end

	if actual ~= expected then
		return false, "different mission: " .. tostring(actual)
	end

	return true, "match"
end

function M.on_game_mode_end(outcome)
	if not _run_state.is_active() then return end

	local ours, why = M.is_run_mission()
	if not ours then
		_debug_log("leg_end_ignored", _shared.fixed_time(),
			"game mode ended but it is not our leg (" .. tostring(why) .. ")", 0, "info")

		_event_log.emit({
			t = _shared.fixed_time(),
			event = "leg_end_ignored",
			id = _event_log.next_id(),
			reason = tostring(why),
			outcome = tostring(outcome),
		})
		return
	end

	local mission = _run_state.current_mission()
	local win = outcome_is_win(outcome)

	_pending = {
		mission = mission,
		outcome = tostring(outcome),
		result = win and "complete" or "failed",
	}
	-- A result can wait for the hub while the player changes operative or the
	-- VM reloads. Keep that debt with its run, not in one account-wide local.
	_mod:set("_run_pending_mission", _pending.mission or "", false)
	_mod:set("_run_pending_outcome", _pending.outcome, false)
	_mod:set("_run_pending_result", _pending.result, false)

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "leg_ended",
		id = _event_log.next_id(),
		mission = mission,
		outcome = tostring(outcome),
		result = _pending.result,
	})

	_debug_log("leg_end", _shared.fixed_time(),
		"leg ended: " .. tostring(mission) .. " -> " .. tostring(outcome), 0, "info")
end

function M.pending()
	return _pending
end

function M.clear_pending()
	_pending = nil
	if _mod then
		_mod:set("_run_pending_mission", "", false)
		_mod:set("_run_pending_outcome", "", false)
		_mod:set("_run_pending_result", "", false)
	end
end

-- ---------------------------------------------------------------------------
-- Hook installation
-- ---------------------------------------------------------------------------

function M.install(GameModeManager)
	if not GameModeManager then return end
	if _hooks.claim(GameModeManager, SENTINEL) then return end

	-- hook_safe: observe only. We must never be able to stop the game deciding a
	-- mission is over.
	_mod:hook_safe(GameModeManager, "_set_end_conditions_met", function(self, outcome)
		M.on_game_mode_end(outcome)
	end)
end

M.GAME_MODE_MANAGER_PATH = "scripts/managers/game_mode/game_mode_manager"

-- ---------------------------------------------------------------------------
-- Shared "leg complete" side-effects
--
-- Called by both the auto-chain path (tick) and the manual skip. Handles
-- currency for the finished leg, then advances the run; on run-end also
-- credits the run bonus, fires penance observers, emits the event log,
-- and notifies. Returns the next mission name, or nil when the run ended.
--
-- Kaizen's 2026-08-06 request: skip should count in every way that
-- succeeding a leg does. Before this refactor, only the auto-chain path
-- awarded currency and penances; /pil_skip advanced the queue but never
-- unlocked the next War Plan tier. Now both go through here.
-- ---------------------------------------------------------------------------

function M.finalize_leg_completion(t, result)
	local finishing_state = _run_state.get()
	local wager_active = _boons and _boons.custom_boon_active
		and _boons.custom_boon_active("pilgrim_doctrine_pilgrims_wager") == true
	-- Currency for the leg we just cleared. Read the difficulty at THIS
	-- state.index (before advance), because that's the leg that was played.
	if _wallet and _difficulty then
		local diff = _difficulty.for_leg(finishing_state.index,
			finishing_state.starting_difficulty)
		if diff then
			_wallet.earn_leg_complete(diff.danger, diff.scale_tier, wager_active)
		end
	end

	-- Snapshot the run BEFORE advance() so we know its plan_id even after
	-- it deactivates. The plan_id drives which penance the completion
	-- awards, so losing it here silently locks the next tier.
	local finishing_plan = finishing_state.plan_id or ""

	-- v0.22.49 (Session B): mission_complete emitter, fires for EVERY leg
	-- (success and failure), even mid-run. Carries the per-mission stat
	-- snapshot before advance() wipes it. Used by penances like
	-- In Lord Captain's Service ("clear a Fanatic mission without taking
	-- any HP damage") that gate on per-mission rather than per-run state.
	-- v0.25.0: a successfully finished leg promotes any legendaries
	-- drafted this run into the permanent collection (Penitent+ only;
	-- the gate lives in boons so the rule has one home).
	if _boons and _boons.promote_pending_legendaries and result == "complete" then
		pcall(_boons.promote_pending_legendaries)
	end
	local mission_snap = (_run_state.stat_snapshot and _run_state.stat_snapshot()) or {}
	if _boons and _boons.on_mission_completed and result == "complete" then
		pcall(_boons.on_mission_completed, mission_snap.mission_ever_downed == true)
	end

	-- The Devoted counts successful missions, not whole runs. Increment before
	-- the trigger so the tenth leg grants immediately on the results transition.
	if result == "complete" and _run_state.persist_add then
		pcall(_run_state.persist_add, "total_missions_completed", 1)
		local total_missions = _run_state.persist_get
			and _run_state.persist_get("total_missions_completed") or 0
		if _penances and _penances.observe then
			pcall(_penances.observe, "mission_count", {
				total_missions = total_missions,
			})
		end
	end

	if _penances and _penances.observe and result == "complete" then
		local snap = mission_snap
		local diff = _difficulty and _difficulty.for_leg(
			finishing_state.index, finishing_state.starting_difficulty) or nil
		pcall(_penances.observe, "mission_complete", {
			plan_id           = finishing_plan,
			mission           = snap.mission_name,
			-- Danger name (uprising/malice/heresy/damnation/...) at the
			-- point the leg was played. Nil if difficulty resolution
			-- failed for any reason; penance checks should default-safe.
			difficulty        = diff and diff.danger or nil,
			hp_damage_taken   = snap.mission_hp_damage,
			archetype         = snap.archetype,
			ever_downed       = snap.ever_downed,
			-- v0.22.80: Idira's Unsanctioned Fury counter.
			overload_elite_kills = snap.mission_overload_elite_kills,
		})
	end

	local next_mission = _run_state.advance(result or "complete")

	if next_mission then
		return next_mission
	end

	-- Run just ended.
	local legs_done = 0
	local finished_state = _run_state.get()
	for _ in pairs(finished_state.legs_done or {}) do legs_done = legs_done + 1 end
	if _wallet then
		_wallet.earn_run_complete(legs_done, wager_active)
		if _wallet.settle_wager then _wallet.settle_wager(true) end
	end

	if _penances and _penances.observe then
		-- v0.22.49 (Session B): payload extended with the full stat
		-- snapshot so penance checks can reach archetype, ever_downed,
		-- damage, boons_taken, curses_stacked, etc. without a second
		-- run_state lookup. Snapshot BEFORE advance() wiped things.
		-- v0.28.50: reuse the pre-advance snapshot. advance() clears
		-- run-scoped boons and curses when the final leg closes, so taking a
		-- second snapshot here reduced curses_stacked to zero and made
		-- Curseborn / The Perfect Pilgrimage impossible to earn.
		local snap = mission_snap
		local payload = {
			plan_id   = finishing_plan,
			legs_done = legs_done,
			balance   = _wallet and _wallet.balance() or 0,
			result    = result,
			-- Flatten the snapshot into the payload so existing check
			-- functions can read data.archetype / data.ever_downed
			-- without knowing the snapshot exists.
			archetype        = snap.archetype,
			ever_downed      = snap.ever_downed,
			downs            = snap.downs,
			boons_taken      = snap.boons_taken,
			hp_damage_taken  = snap.hp_damage_taken,
			ranged_hp_damage = snap.ranged_hp_damage,
			shop_purchases   = snap.shop_purchases,
			bots_slotted     = snap.bots_slotted,
			curses_stacked   = snap.curses_stacked,
			-- v0.22.77 (Session B phase 2): the four data feeds that make
			-- Dancing on the Web, Warrant Served and Biolightning earnable.
			martyrdom_time_pct       = snap.martyrdom_time_pct,
			companion_kills          = snap.companion_kills,
			electricity_damage_dealt = snap.electricity_damage_dealt,
			total_damage_dealt       = snap.total_damage_dealt,
		}
		pcall(_penances.observe, "run_complete", payload)
		pcall(_penances.observe, "wallet_update", {
			balance = _wallet and _wallet.balance() or 0,
			-- v0.22.80: Theodora's fortune reads lifetime spend too.
			total_spent = _wallet and _wallet.total_spent and _wallet.total_spent() or 0,
		})
		-- v0.22.49: bump the persistent "runs completed" counter and
		-- fire a run_count trigger so multi-run penances (e.g. The
		-- Devoted at 10) can observe it.
		if _run_state.persist_add then
			pcall(_run_state.persist_add, "total_runs_completed", 1)
		end
		local total_runs = (_run_state.persist_get and _run_state.persist_get("total_runs_completed")) or 0
		pcall(_penances.observe, "run_count", { total_runs = total_runs })
	end

	-- v0.20.0: consumables die with the run. A curse-reroll bought and
	-- never used does not carry to the next pilgrimage. Design intent is
	-- that consumables are per-run leverage, not a savings account.
	if _shop and _shop.clear_run_consumables then
		pcall(_shop.clear_run_consumables)
	end

	_event_log.emit({
		t = t or (_shared and _shared.fixed_time() or 0),
		event = "run_complete",
		id = _event_log.next_id(),
		last_result = result,
		plan_id = finishing_plan,
	})

	local balance = _wallet and _wallet.balance() or nil
	if balance then
		_shared.notify(string.format("Pilgrimage: run complete. Ordos: %d", balance))
	else
		_shared.notify("Pilgrimage: run complete")
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- The tick that actually advances the run
-- ---------------------------------------------------------------------------

function M.tick(t)
	local in_hub = _shared.is_in_hub()

	-- Rising edge: we just arrived in the hub.
	if in_hub and not _was_in_hub then
		_hub_arrived_t = t
	elseif not in_hub then
		_hub_arrived_t = nil
	end
	_was_in_hub = in_hub

	if not in_hub then return end
	if not _pending then return end
	if not _run_state.is_active() then M.clear_pending() return end
	if _launcher.is_launching() then return end

	if not _hub_arrived_t or t - _hub_arrived_t < HUB_SETTLE_S then return end

	-- v0.20.0: the mode gate. If this run is NOT in Blitz mode, we do
	-- everything up to the point of launching, then STOP. Currency lands,
	-- penances fire, the run advances, but the next mission does not
	-- auto-load. The player lands back at the terminal with the run one
	-- leg further along, and starts the next assignment when they choose
	-- to via the Continue button.
	--
	-- The run's blitz flag is captured at start (see run_state.start) so a
	-- mid-run mod-option flip cannot switch modes underfoot.
	local run = _run_state.get()
	local is_blitz = run.blitz == true

	local pending = _pending
	M.clear_pending()

	-- A FAILED LEG ENDS THE RUN.
	--
	-- A pilgrimage you can fail your way through leg by leg is not a run, it is a
	-- mission queue. Death has to cost the whole thing, or none of the boons, curses
	-- or route choices carry any weight.
	--
	-- The leg is still recorded before the run closes, so the history shows where and
	-- how it ended rather than just vanishing.
	if pending.result ~= "complete" then
		local state = _run_state.get()
		local reached = state.index
		local total = #state.queue
		local failed_mission = pending.mission

		-- advance() records the result into legs_done. end_run() then deactivates
		-- WITHOUT wiping, so /pil_run and status.txt can still show the route, the
		-- seed and exactly which leg killed it. abandon() would clear all of that.
		if _wallet and _wallet.settle_wager then _wallet.settle_wager(false) end
		_run_state.advance(pending.result)
		_run_state.end_run("failed")

		_event_log.emit({
			t = t,
			event = "run_failed",
			id = _event_log.next_id(),
			mission = failed_mission,
			outcome = pending.outcome,
			reached_leg = reached,
			total_legs = total,
		})

		_shared.notify(string.format("Pilgrimage failed on assignment %d of %d: %s",
			reached, total, _missions.display_name(failed_mission)), "alert")
		_shared.notify("Start a new run to try again.")

		-- v0.22.97 (2026-08-11 field report): consumables die with the
		-- run on FAILURE too. This branch returns before the completion
		-- path further down, so its clear_run_consumables call never
		-- ran here and a Vanguard ban plus a scout-ahead survived a
		-- failed leg into the next run.
		if _shop and _shop.clear_run_consumables then
			pcall(_shop.clear_run_consumables)
		end

		return
	end

	local next_mission = M.finalize_leg_completion(t, pending.result)
	if not next_mission then return end

	-- Non-Blitz path: DO NOT launch. Notify the player that the next
	-- assignment is ready and hand control back to them. The Route tab's
	-- Continue button is what actually launches from here.
	if not is_blitz then
		_shared.notify(string.format(
			"Pilgrimage: %s ready. Visit the terminal.",
			_missions.display_name(next_mission)))
		return
	end

	-- Blitz path: preserve the old auto-launch behavior.
	_shared.notify(M.leg_banner(next_mission))

	local ok, err = _launcher.launch_current_leg()
	if not ok then
		_shared.notify("Pilgrimage: could not launch next leg, " .. tostring(err), "alert")
		_event_log.emit({
			t = t, event = "chain_launch_failed", id = _event_log.next_id(),
			reason = tostring(err),
		})
	end
end

-- ---------------------------------------------------------------------------
-- Skip
--
-- Marks the current leg as finished and launches the next one straight away, from
-- wherever you happen to be. This exists so a change can be tested without playing
-- fifteen minutes of mission first.
-- ---------------------------------------------------------------------------

function M.skip(result)
	if not _run_state.is_active() then return false, "no active run" end
	if _launcher.is_launching() then return false, "a launch is already in progress" end

	M.clear_pending()

	local from = _run_state.current_mission()
	local t = _shared.fixed_time()

	-- v0.19.1: skip goes through finalize_leg_completion, so it awards
	-- Ordos AND fires the penance observer AND emits the run_complete
	-- event on the final leg. Before this, /pil_skip would advance the
	-- queue without unlocking the next War Plan tier, defeating the point
	-- of using it as a test shortcut.
	-- Manual recovery must use the same successful-completion observers as a
	-- natural win. Keep leg_skipped below for diagnostics, not as reward status.
	local completion_result = (result == nil or result == "skipped") and "complete" or result
	local next_mission = M.finalize_leg_completion(t, completion_result)

	_event_log.emit({
		t = t,
		event = "leg_skipped",
		id = _event_log.next_id(),
		from = from,
		to = next_mission,
	})

	if not next_mission then
		-- Note already sent by finalize_leg_completion; nothing more to say.
		return true, "run finished"
	end

	_shared.notify(M.leg_banner(next_mission))

	return _launcher.launch_current_leg()
end

-- "Leg 2 of 3: Chasm Terminus". The player should never have to read an internal
-- mission id to know where they are.
function M.leg_banner(mission_name)
	local state = _run_state.get()
	local text = string.format("Pilgrimage, assignment %d of %d: %s",
		state.index or 0, #state.queue,
		_missions.display_name(mission_name or _run_state.current_mission()))

	-- Announce the curse with the destination. The player agreed to it at the preview;
	-- this is the reminder of what they agreed to, arriving as the loading starts.
	-- With stacking on, also say how many earlier curses ride along, because the
	-- screen otherwise gives no sign that stacking did anything.
	if _curses then
		local curse = _run_state.current_curse and _run_state.current_curse() or nil
		local label = curse and _curses.display_name(curse) or ""

		local stacked = 0
		if _curses.stacking_enabled and _curses.stacking_enabled()
			and _curses.stack_curses and _run_state.curse_prefix then
			local real = _curses.stack_curses(_run_state.curse_prefix())
			if #real >= 2 then stacked = #real - 1 end
		end

		if label ~= "" and stacked > 0 then
			text = text .. " [" .. label .. ", +" .. stacked .. " stacked]"
		elseif label ~= "" then
			text = text .. " [" .. label .. "]"
		elseif stacked > 0 then
			text = text .. " [+" .. stacked .. " stacked curses]"
		end

		-- v0.22.99: plan-forced curses (Martyr/Saint Auric Intensity)
		-- ride every leg without occupying a roll, so the banner names
		-- them separately or they would be invisible.
		if _curses.forced_for_run then
			local ok_f, forced = pcall(_curses.forced_for_run)
			if ok_f and type(forced) == "table" and #forced > 0 then
				local names = {}
				for i = 1, #forced do
					names[i] = _curses.display_name(forced[i])
				end
				text = text .. " [" .. table.concat(names, ", ") .. ", always on]"
			end
		end
	end

	return text
end

-- ---------------------------------------------------------------------------

function M.status()
	local run = _run_state and _run_state.get() or nil
	return {
		blitz_setting = _settings.blitz_mode_enabled(),
		blitz_run     = run and run.blitz == true or false,
		pending = _pending and _pending.mission or nil,
		pending_result = _pending and _pending.result or nil,
		in_hub = _was_in_hub,
		hub_settle_remaining = _hub_arrived_t
			and math.max(0, HUB_SETTLE_S - (_shared.fixed_time() - _hub_arrived_t)) or nil,
	}
end

-- Called on mission start so a stale edge from the previous level cannot fire.
function M.reset()
	_was_in_hub = false
	_hub_arrived_t = nil
	_pending = nil
	if _mod then
		local mission = _mod:get("_run_pending_mission")
		local result = _mod:get("_run_pending_result")
		if type(mission)=="string" and mission~=""
			and (result=="complete" or result=="failed") then
			_pending = {mission=mission, result=result, outcome=_mod:get("_run_pending_outcome")}
		end
	end
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_missions = deps.missions
	_run_state = deps.run_state
	_launcher = deps.launcher
	_event_log = deps.event_log
	_settings = deps.settings
	_curses = deps.curses
	_difficulty = deps.difficulty
	_wallet = deps.wallet
	_penances = deps.penances
	_shop = deps.shop
	_boons = deps.boons
	_debug_log = deps.debug_log or function() end
end

return M
