-- bootstrap.lua
--
-- Module loading and dependency injection. This file is deliberately explicit and
-- deliberately boring: it IS the load-order documentation.
--
-- Three phases:
--
--   1. LOAD    every module, in dependency order, via mod:io_dofile.
--   2. INIT    each module receives everything it needs as a named `deps` table.
--   3. WIRE    late-bound references, for the cases where A needs B and B needs A.
--
-- The rule that makes this scale: modules NEVER call get_mod("Pilgrimage") and never
-- reach for a sibling module directly. Everything arrives through deps. That keeps
-- coupling visible in this one file, and it means a module can be exercised outside
-- the game by handing it stubs.
--
-- A note on mod:io_dofile: unlike require, it does NOT cache. Every call re-executes
-- the file and hands back a brand new table. That is what makes DMF's /reload work,
-- but it also means loading the same module twice gives you two independent copies
-- with independent state. Load each one exactly once, here.

local M = {}

local ROOT = "Pilgrimage/scripts/mods/Pilgrimage/"

local function load_module(mod, filename)
	local module = mod:io_dofile(ROOT .. filename)
	assert(module, "Pilgrimage: failed to load module '" .. filename .. "'")
	return module
end

function M.load_and_init(ctx)
	local mod = ctx.mod

	-- -----------------------------------------------------------------------
	-- Phase 1: load
	-- -----------------------------------------------------------------------

	local modules = {
		-- Pre-loaded by the entry file, because they are needed before bootstrap runs.
		Hooks     = ctx.hooks,
		LogLevels = ctx.log_levels,
		Shared    = ctx.shared,
	}

	modules.FileIO   = load_module(mod, "fileio")
	modules.Settings = load_module(mod, "settings")
	modules.RealmsBridge = load_module(mod, "realms_bridge")
	modules.Perf     = load_module(mod, "perf")
	modules.EventLog  = load_module(mod, "event_log")
	modules.Tick      = load_module(mod, "tick")
	modules.RunState  = load_module(mod, "run_state")
	modules.CharacterRuns = load_module(mod, "character_runs")
	modules.MissionIncidents = load_module(mod, "mission_incidents")
	modules.Missions  = load_module(mod, "missions")
	modules.Launcher  = load_module(mod, "launcher")
	modules.Curses    = load_module(mod, "curses")
	modules.Escape    = load_module(mod, "escape")
	modules.Chain     = load_module(mod, "chain")
	modules.HitProbe  = load_module(mod, "hitprobe")
	modules.Probe     = load_module(mod, "probe")
	modules.Weapons   = load_module(mod, "weapons")
	modules.WeaponCounterTimedMode =
		load_module(mod, "weapon_counter_timed_mode")
	-- This helper is a mod-owned Lua file, so it must be executed through
	-- DMF's io_dofile path before weapon_rebalance assigns its registered
	-- class name to the transformed weapon templates. A plain game require cannot see
	-- files under mods/Pilgrimage and would abort the whole bootstrap.
	modules.WeaponSpecialTimedCooldown =
		load_module(mod, "weapon_special_timed_cooldown")
	modules.WeaponSpecialPersistentShovel =
		load_module(mod, "weapon_special_persistent_shovel")
	modules.WeaponOgrynHeavy = load_module(mod, "weapon_ogryn_heavy")
	modules.WeaponRumbler = load_module(mod, "weapon_rumbler")
	modules.WeaponMelta = load_module(mod, "weapon_melta")
	modules.EWCShootGuard = load_module(mod, "ewc_shoot_guard")
	modules.WeaponRebalance = load_module(mod, "weapon_rebalance")
	modules.EWCOwnedContent = load_module(mod, "ewc_owned_content")
	modules.WeaponVisuals = load_module(mod, "weapon_visuals")
	modules.Boons     = load_module(mod, "boons")
	modules.DoctrineRuntime = load_module(mod, "doctrine_runtime")
	modules.Terminal  = load_module(mod, "terminal")
	modules.Icons     = load_module(mod, "icons")
	modules.MutatorGuard = load_module(mod, "mutator_guard")
	modules.FxGuard   = load_module(mod, "fx_guard")
	modules.Difficulty = load_module(mod, "difficulty")
	modules.ScalingHook = load_module(mod, "scaling_hook")
	modules.Wallet    = load_module(mod, "wallet")
	modules.Penances  = load_module(mod, "penances")
	modules.WarPlans  = load_module(mod, "war_plans")
	modules.Shop      = load_module(mod, "shop")
	modules.Bots      = load_module(mod, "bots")
	modules.Preset    = load_module(mod, "preset")
	modules.BotIdentityUI = load_module(mod, "bot_identity_ui")
	modules.Passives  = load_module(mod, "passives")
	modules.Voices    = load_module(mod, "voices")
	-- v0.22.45: Skitarii bots auto-dispatch servo skull at stalled
	-- decoding interactables (data interrogators). Zero dependencies
	-- on any other module besides shared + debug_log, so ordering
	-- here doesn't matter beyond "after Bots so we know they exist".
	modules.BotHackOrders = load_module(mod, "bot_hack_orders")
	modules.BetterBotsBridge = load_module(mod, "betterbots_bridge")
	modules.Debug     = load_module(mod, "debug")

	-- -----------------------------------------------------------------------
	-- Phase 2: init
	--
	-- Ordering matters here in exactly one way: a module must be initialised before
	-- another module's init calls into it. Settings first, because everything reads
	-- settings.
	--
	-- Feature gates are passed as CLOSURES, never as snapshotted booleans, so a
	-- setting change takes effect immediately without any invalidation logic.
	-- -----------------------------------------------------------------------

	modules.Shared.init({
		mod = mod,
	})
	modules.CharacterRuns.init({mod=mod, shared=modules.Shared, run_keys=modules.RunState.KEY})

	modules.FileIO.init({
		mod = mod,
	})

	modules.Settings.init({
		mod        = mod,
		log_levels = modules.LogLevels,
	})

	modules.RealmsBridge.init({
		mod       = mod,
		settings  = modules.Settings,
		shared    = modules.Shared,
		run_state = modules.RunState,
		debug_log = ctx.debug_log,
	})

	modules.Perf.init({
		mod    = mod,
		shared = modules.Shared,
	})

	modules.EventLog.init({
		mod    = mod,
		shared = modules.Shared,
		fileio = modules.FileIO,
	})

	modules.Tick.init({
		mod       = mod,
		perf      = modules.Perf,
		shared    = modules.Shared,
		debug_log = ctx.debug_log,
	})

	modules.RunState.init({
		mod       = mod,
		character_runs = modules.CharacterRuns,
		event_log = modules.EventLog,
		shared    = modules.Shared,
	})

	modules.Missions.init({
		mod       = mod,
		shared    = modules.Shared,
		debug_log = ctx.debug_log,
	})

	modules.Curses.init({
		mod       = mod,
		shared    = modules.Shared,
		event_log = modules.EventLog,
		-- v0.28.5: registers the safe fixed-rank Tougher Skin buff through
		-- the one shared buff-template registration seam.
		passives  = modules.Passives,
		-- For rebuilding the stacked circumstance in a fresh Lua VM: the run
		-- lives in settings, and run_state is the door to it.
		run_state = modules.RunState,
		-- v0.22.47: for the "dropped unknown mutator" warning in stacked_for.
		debug_log = ctx.debug_log,
	})

	modules.Launcher.init({
		mod       = mod,
		shared    = modules.Shared,
		missions  = modules.Missions,
		run_state = modules.RunState,
		event_log = modules.EventLog,
		settings  = modules.Settings,
		curses    = modules.Curses,
		difficulty = modules.Difficulty,
		shop      = modules.Shop,
		war_plans = modules.WarPlans,
		terminal  = modules.Terminal,
		realms_bridge = modules.RealmsBridge,
		debug_log = ctx.debug_log,
	})

	modules.Escape.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		event_log = modules.EventLog,
		terminal  = modules.Terminal,
		debug_log = ctx.debug_log,
	})

	-- v0.19.2: penances MUST be passed here. finalize_leg_completion gates
	-- the observer call on `if _penances and _penances.observe then`, so
	-- forgetting this dep is silent: legs complete, Ordos land, but no
	-- penance ever fires, which locks every War Plan tier past novitiate.
	-- Kaizen hit that exact symptom in 0.19.1.
	--
	-- modules.Penances is the table reference from load_module; Penances.init
	-- runs later in this file but that's fine, because Chain only reads the
	-- reference. All that matters is that the module TABLE exists here, and
	-- it does.
	modules.Chain.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		missions  = modules.Missions,
		run_state = modules.RunState,
		launcher  = modules.Launcher,
		event_log = modules.EventLog,
		settings  = modules.Settings,
		curses    = modules.Curses,
		difficulty = modules.Difficulty,
		wallet    = modules.Wallet,
		penances  = modules.Penances,
		shop      = modules.Shop,
		-- v0.25.0: legendary unlock promotion on leg completion.
		boons     = modules.Boons,
		debug_log = ctx.debug_log,
	})

	modules.HitProbe.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		fileio    = modules.FileIO,
		debug_log = ctx.debug_log,
	})

	modules.Probe.init({
		mod    = mod,
		shared = modules.Shared,
	})

	modules.Weapons.init({
		mod       = mod,
		shared    = modules.Shared,
		event_log = modules.EventLog,
		debug_log = ctx.debug_log,
	})

	modules.WeaponCounterTimedMode.init({
		mod   = mod,
		hooks = modules.Hooks,
		heavy = modules.WeaponOgrynHeavy,
	})

	modules.WeaponOgrynHeavy.init({ mod = mod, shared = modules.Shared,
		hooks = modules.Hooks, passives = modules.Passives, realms = modules.RealmsBridge, settings = modules.Settings })
	modules.WeaponMelta.init({ mod = mod, hooks = modules.Hooks, fileio = modules.FileIO,
		heavy = modules.WeaponOgrynHeavy, settings = modules.Settings })
	modules.EWCShootGuard.init({ mod = mod })
	modules.WeaponRumbler.init({ mod = mod, hooks = modules.Hooks })
	modules.WeaponRebalance.init({
		rumbler   = modules.WeaponRumbler,
		melta     = modules.WeaponMelta,
		heavy     = modules.WeaponOgrynHeavy,
		mod       = mod,
		settings  = modules.Settings,
		run_state = modules.RunState,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		event_log = modules.EventLog,
		passives  = modules.Passives,
		debug_log = ctx.debug_log,
	})

	-- This runs before EWC's all-mods-loaded merge, so standard EWC sees
	-- Pilgrimage's owned skin catalogue as an ordinary external plugin.
	modules.EWCOwnedContent.init({
		mod       = mod,
		debug_log = ctx.debug_log,
	})

	modules.WeaponVisuals.init({
		mod       = mod,
		settings  = modules.Settings,
		debug_log = ctx.debug_log,
	})

	modules.Boons.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		icons     = modules.Icons,
		run_state = modules.RunState,
		event_log = modules.EventLog,
		missions  = modules.Missions,
		-- v0.22.81 (Boon Loadout): wallet for purchases, shop for slot
		-- expansions, passives to register custom-boon templates on
		-- the shared buff_templates hook.
		wallet    = modules.Wallet,
		shop      = modules.Shop,
		passives  = modules.Passives,
		debug_log = ctx.debug_log,
	})

	modules.DoctrineRuntime.init({
		mod       = mod,
		shared    = modules.Shared,
		boons     = modules.Boons,
		debug_log = ctx.debug_log,
	})

	modules.Terminal.init({
		mod       = mod,
		shared    = modules.Shared,
		run_state = modules.RunState,
		hooks     = modules.Hooks,
		settings  = modules.Settings,
		event_log = modules.EventLog,
		fileio    = modules.FileIO,
		probe     = modules.Probe,
		debug_log = ctx.debug_log,
	})

	modules.Icons.init({
		mod       = mod,
		shared    = modules.Shared,
	})

	modules.MutatorGuard.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		run_state = modules.RunState,
		curses    = modules.Curses,
		event_log = modules.EventLog,
		debug_log = ctx.debug_log,
	})

	modules.FxGuard.init({
		mod       = mod,
		hooks     = modules.Hooks,
		shared    = modules.Shared,
		event_log = modules.EventLog,
		debug_log = ctx.debug_log,
	})

	-- World is an engine global, not a require path, so its hook installs
	-- here rather than through a fanout. Safe on every reload: the module
	-- guards against double-installing.
	modules.FxGuard.install_world()

	modules.Difficulty.init({
		mod = mod,
	})

	modules.ScalingHook.init({
		mod       = mod,
		shared    = modules.Shared,
		run_state = modules.RunState,
		difficulty = modules.Difficulty,
		event_log = modules.EventLog,
		debug_log = ctx.debug_log,
	})

	modules.Wallet.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		event_log = modules.EventLog,
		run_state = modules.RunState,
		fileio    = modules.FileIO,
		-- v0.22.79: earn-multiplier penances (read at earn time only).
		penances  = modules.Penances,
		-- v0.22.80: Dynastic Largesse (Theodora slotted = +50% earns).
		preset    = modules.Preset,
		bots      = modules.Bots,
		-- v0.22.81: House Always Wins pickup doubling.
		boons     = modules.Boons,
		debug_log = ctx.debug_log,
	})

	-- Penances knows nothing about War Plans directly; War Plans depends
	-- on Penances (for unlock checks). So Penances inits first.
	modules.Penances.init({
		mod       = mod,
		shared    = modules.Shared,
		event_log = modules.EventLog,
		run_state = modules.RunState,
		wallet    = modules.Wallet,
		shop      = modules.Shop,
		settings  = modules.Settings,
		debug_log = ctx.debug_log,
	})

	modules.WarPlans.init({
		mod       = mod,
		missions  = modules.Missions,
		curses    = modules.Curses,
		difficulty = modules.Difficulty,
		penances  = modules.Penances,
		debug_log = ctx.debug_log,
	})

	modules.Shop.init({
		mod       = mod,
		shared    = modules.Shared,
		event_log = modules.EventLog,
		wallet    = modules.Wallet,
		penances  = modules.Penances,
		-- v0.22.81: House Always Wins price tax (read-only at price time).
		boons     = modules.Boons,
		-- v0.22.88: enemy bans read the upcoming leg for the tier-1
		-- kill-target gate.
		run_state = modules.RunState,
		missions  = modules.Missions,
		debug_log = ctx.debug_log,
	})

	-- v0.21.0: Bots depends on Penances (slot progression) and Shop (5/6
	-- unlocks). Init runs the Better Bots / Custom Character Bots
	-- detection at boot, which produces notify banners the player sees
	-- on the first screen after load.
	modules.Bots.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		penances  = modules.Penances,
		shop      = modules.Shop,
		-- v0.22.75: None-bound slot accounting. Preset.init runs
		-- after this, which is fine: Bots only calls
		-- preset.none_count at spawn time, never during init.
		preset    = modules.Preset,
		realms_bridge = modules.RealmsBridge,
		debug_log = ctx.debug_log,
	})

	-- v0.22.0: bot presets. Depends on Penances for unlock gating
	-- (Sister Argenta locks behind pilgrim_unshakeable_faith, though
	-- enforcement of that penance is deferred to v0.22.x). Init before
	-- Debug so /pil_preset_* commands can reach the module.
	modules.Preset.init({
		mod       = mod,
		shared    = modules.Shared,
		hooks     = modules.Hooks,
		penances  = modules.Penances,
		shop      = modules.Shop,
		realms_bridge = modules.RealmsBridge,
		debug_log = ctx.debug_log,
	})

	-- Companion identity is presentation-only. It reads the stable preset
	-- sentinel installed by Preset and rewrites only the local squad HUD and
	-- subtitle labels, leaving synchronized profile/dialogue data untouched.
	modules.BotIdentityUI.init({
		mod       = mod,
		hooks     = modules.Hooks,
		preset    = modules.Preset,
		debug_log = ctx.debug_log,
	})

	-- v0.22.21: bot passives. Registers custom buff templates via
	-- mod:hook_require on Fatshark's buff_templates so our entries land
	-- in the shared registry before any unit tries to spawn a buff of
	-- that name. Runs before Debug so /pil_passives_* can reach it.
	modules.Passives.init({
		mod       = mod,
		shared    = modules.Shared,
		debug_log = ctx.debug_log,
	})

	-- v0.22.28: bot preset voices. Syncs preset.selected_voice into
	-- Personality Picker's per-slot bot voice setting so PP's own
	-- extensions_ready hook handles the runtime override + audio loading.
	-- Depends on Preset (reads slot bindings) and PP (target of the write).
	modules.Voices.init({
		mod       = mod,
		shared    = modules.Shared,
		preset    = modules.Preset,
		debug_log = ctx.debug_log,
	})

	-- v0.22.45: init BotHackOrders so it can start scanning for
	-- stalled decoding interactables once bots are alive.
	modules.BotHackOrders.init({
		mod       = mod,
		shared    = modules.Shared,
		debug_log = ctx.debug_log,
	})

	modules.BetterBotsBridge.init({
		mod       = mod,
		hooks     = modules.Hooks,
		settings  = modules.Settings,
		shared    = modules.Shared,
		run_state = modules.RunState,
		debug_log = ctx.debug_log,
	})

	modules.Debug.init({
		mod       = mod,
		shared    = modules.Shared,
		perf      = modules.Perf,
		event_log = modules.EventLog,
		run_state = modules.RunState,
		settings  = modules.Settings,
		tick      = modules.Tick,
		probe     = modules.Probe,
		weapons   = modules.Weapons,
		weapon_rebalance = modules.WeaponRebalance,
		fileio    = modules.FileIO,
		missions  = modules.Missions,
		launcher  = modules.Launcher,
		escape    = modules.Escape,
		chain     = modules.Chain,
		hitprobe  = modules.HitProbe,
		terminal  = modules.Terminal,
		icons     = modules.Icons,
		curses    = modules.Curses,
		boons     = modules.Boons,
		mutator_guard = modules.MutatorGuard,
		fx_guard  = modules.FxGuard,
		difficulty = modules.Difficulty,
		wallet    = modules.Wallet,
		scaling_hook = modules.ScalingHook,
		war_plans = modules.WarPlans,
		penances  = modules.Penances,
		shop      = modules.Shop,
		bots      = modules.Bots,
		preset    = modules.Preset,
		passives  = modules.Passives,
		voices    = modules.Voices,
	})

	-- -----------------------------------------------------------------------
	-- Phase 3: wire
	--
	-- The route view is the one thing in the mod that cannot receive injected
	-- dependencies. DMF registers it by class name and file path, and the GAME
	-- constructs it when the view opens, so there is no call of ours to inject into.
	--
	-- Rather than let the view reach into mod._modules and couple itself to everything,
	-- we build it a small purpose-made table with exactly what it needs. Four functions,
	-- listed in one place, so the coupling stays visible and deliberate.
	-- -----------------------------------------------------------------------

	-- Bumped on every Reroll so two presses inside the same wall-clock second cannot
	-- produce the same seed.
	local _reroll_counter = 0

	-- v0.20.1: the previewed seed persists across terminal opens.
	--
	-- Before this, opening the terminal without an active run called
	-- generate() with no seed, which rolled a fresh seed every time.
	-- The consequence was that any shop purchase made against the
	-- previewed leg (Skip, Reroll) could not be verified visually,
	-- because closing and reopening the terminal reshuffled the whole
	-- route out from under it. Rerolling now requires pressing the
	-- Reroll button explicitly, matching what the button visually implies.
	--
	-- Persisted in settings so a game restart does not lose the previewed
	-- seed either. Legit no-preview state is 0; anything else is a
	-- previously-rolled seed we should reuse.
	local KEY_PREVIEW_SEED = "_preview_seed"

	local function _load_preview_seed()
		local raw = mod:get(KEY_PREVIEW_SEED)
		local n = tonumber(raw) or 0
		return n > 0 and n or nil
	end

	local function _store_preview_seed(seed)
		mod:set(KEY_PREVIEW_SEED, math.floor(seed or 0), false)
	end

	local function _fresh_seed()
		_reroll_counter = _reroll_counter + 1
		return modules.Missions.mix_seed(
			modules.FileIO.epoch() * 977 + _reroll_counter * 7919)
	end

	-- v0.23.4: the fixed seed moved from a ten-digit options slider to the
	-- /pil_seed chat command, but it still lives in the same run_seeded and
	-- run_seed settings. When pinned, that seed outranks both the persisted
	-- preview seed and the Reroll button, so the pinned road is the road.
	local function _pinned_seed()
		if not modules.Settings.run_seeded() then return nil end
		local seed = modules.Settings.configured_seed()
		return seed > 0 and seed or nil
	end

	local function _build_pending_draft()
		local state = modules.RunState.get()
		if not state.active or not modules.RunState.draft_pending() then return nil end
		local count = 3
		if modules.Shop and modules.Shop.is_active("draft_extra") then count = count + 1 end
		if modules.Penances and modules.Penances.is_earned
			and modules.Penances.is_earned("pilgrim_zero_waste") then
			count = count + 1
		end
		local draft_leg = state.draft
		local leak_chance = modules.RunState.legendary_leak_chance(draft_leg)
		local seed = modules.Boons.draft_seed(state.seed, draft_leg)
		local owned = state.boons
		if modules.RunState.second_reading_used(draft_leg) then
			owned = {}
			for name, stacks in pairs(state.boons or {}) do owned[name] = stacks end
			local discarded = modules.Boons.draft(count, seed, state.boons, leak_chance)
			for i = 1, #discarded do owned[discarded[i]] = 1 end
			seed = modules.Missions.mix_seed(seed + 104729)
		end
		local names = modules.Boons.draft(count, seed, owned, leak_chance)
		if #names == 0 then return nil end
		local offered_legendary = false
		for i = 1, #names do
			if modules.Boons.is_legendary(names[i]) then
				offered_legendary = true
				break
			end
		end
		modules.RunState.record_legendary_offer(draft_leg, leak_chance,
			offered_legendary)
		local out = {}
		for i = 1, #names do out[i] = modules.Boons.info(names[i]) end
		return out
	end

	mod.pilgrimage_route_api = {
		ensure_character = function() return modules.CharacterRuns.refresh("gameplay") end,
		-- Experimental Realms shell. The view gets a read-only mirror of the
		-- connected human roster and effective host rules. Realms itself remains
		-- responsible for joining and final mission readiness.
		realm = {
			installed = function() return modules.RealmsBridge.is_installed() end,
			active = function() return modules.RealmsBridge.is_active() end,
			role = function() return modules.RealmsBridge.role() end,
			host_name = function() return modules.RealmsBridge.host_name() end,
			guest_slots = function() return modules.RealmsBridge.guest_slots() end,
			rules = function() return modules.RealmsBridge.rules() end,
			can_launch = function() return modules.RealmsBridge.can_launch() end,
		},

		-- Generate the route to preview. On terminal open, we WANT the
		-- same seed we last previewed, so the player can close and reopen
		-- the terminal without losing the state they were reasoning about.
		-- Only a Reroll press asks for a genuinely new seed via
		-- reroll_preview() below.
		--
		-- v0.19.0: the route shape (leg count, starting difficulty) is
		-- decided by the currently selected War Plan rather than a single
		-- mod option. The `count` arg is ignored when a plan is selected;
		-- kept in the signature for backward compatibility with any older
		-- caller. War Plans internally still uses missions.generate_queue
		-- and curses.assign, so the same seed produces the same route.
		--
		-- v0.20.1: if the caller passes an explicit seed (tests, or a
		-- future shared-code path), that wins; otherwise we reuse the
		-- persisted preview seed, and only mint a fresh one when there
		-- is no preview yet at all.
		generate = function(count, seed)
			-- v0.23.4: an explicit caller seed still wins (tests), then the
			-- /pil_seed pin, then the persisted preview, then a fresh roll.
			if not seed then
				seed = _pinned_seed()
			end
			if not seed then
				seed = _load_preview_seed()
				if not seed then
					seed = _fresh_seed()
					_store_preview_seed(seed)
				end
			else
				_store_preview_seed(seed)
			end

			local plan_id = modules.WarPlans.selected_id()
			local route = modules.WarPlans.generate_route(plan_id, seed)

			return {
				queue = route.queue,
				seed = route.seed,
				curses = route.curses,
				plan_id = route.plan_id,
				plan_name = route.plan_name,
				starting_difficulty = route.starting_difficulty,
			}
		end,

		-- v0.20.1: explicit Reroll. Forces a new seed regardless of what
		-- is stored. The route view calls this from _on_reroll_pressed
		-- instead of the passive generate() so opening the terminal is
		-- never confused with pressing the button.
		reroll_preview = function()
			-- v0.23.4: a pinned seed makes Reroll a no-op by definition.
			-- Saying so beats silently returning the identical route,
			-- which would read as a broken button.
			local pinned = _pinned_seed()
			if pinned then
				modules.Shared.notify("Pilgrimage: seed is pinned to "
					.. tostring(pinned) .. ", Reroll is disabled (/pil_seed off to unpin)")
				local plan_id_p = modules.WarPlans.selected_id()
				local route_p = modules.WarPlans.generate_route(plan_id_p, pinned)
				return {
					queue = route_p.queue,
					seed = route_p.seed,
					curses = route_p.curses,
					plan_id = route_p.plan_id,
					plan_name = route_p.plan_name,
					starting_difficulty = route_p.starting_difficulty,
				}
			end
			local seed = _fresh_seed()
			_store_preview_seed(seed)
			local plan_id = modules.WarPlans.selected_id()
			local route = modules.WarPlans.generate_route(plan_id, seed)
			return {
				queue = route.queue,
				seed = route.seed,
				curses = route.curses,
				plan_id = route.plan_id,
				plan_name = route.plan_name,
				starting_difficulty = route.starting_difficulty,
			}
		end,

		-- The list of unlocked plans, for a future terminal picker. Each
		-- entry is { id, name, description, leg_count, is_selected }.
		available_plans = function()
			local out = {}
			local selected = modules.WarPlans.selected_id()
			local plans = modules.WarPlans.available()
			for i = 1, #plans do
				local p = plans[i]
				out[i] = {
					id = p.id, name = p.name, description = p.description,
					leg_count = p.leg_count,
					starting_difficulty_name = p.starting_difficulty_name,
					is_selected = (p.id == selected),
				}
			end
			return out
		end,

		-- Change the selected plan. Silently ignored if locked. The next
		-- terminal open (or the current preview if the view re-generates)
		-- picks up the change.
		select_plan = function(id) return modules.WarPlans.select(id) end,

		-- The boon draft owed at the current leg, or nil when nothing is owed. Seeded off
		-- the run seed and the leg number, so the same run always offers the same three
		-- choices and a crash mid-draft cannot be used to reroll into a better one.
		--
		-- v0.20.0: if the Emporium's "Extra Boon Draft" consumable is active,
		-- we offer FOUR choices instead of three. The consumable stays hot
		-- until the player actually PICKS one (see choose_boon), because
		-- opening the draft screen and closing it should not spend the buy.
		pending_draft = function()
			return _build_pending_draft()
		end,

		can_reroll_draft = function()
			local state = modules.RunState.get()
			return state.active and modules.RunState.draft_pending()
				and modules.Boons.custom_boon_active("pilgrim_doctrine_second_reading")
				and not modules.RunState.second_reading_used(state.draft)
		end,

		reroll_draft = function()
			local state = modules.RunState.get()
			if not state.active or not modules.RunState.draft_pending()
				or not modules.Boons.custom_boon_active("pilgrim_doctrine_second_reading")
				or not modules.RunState.use_second_reading(state.draft) then
				return nil
			end
			return _build_pending_draft()
		end,

		-- Take one of the three (or four). The others are gone: a draft you can revisit
		-- is a shopping list, not a choice. Consumes the extra-draft SKU HERE, not on
		-- draft display, so opening the screen without choosing does not spend the buy.
		choose_boon = function(name)
			local result = modules.Boons.choose(name)
			if result and modules.Shop and modules.Shop.is_active("draft_extra") then
				modules.Shop.consume("draft_extra")
			end
			return result
		end,

		-- Decline the entire offer. This resolves the pending draft without
		-- adding a boon, which makes Zero Waste achievable through normal UI.
		-- Extra Boon Draft is consumed because its expanded offer was used.
		reject_boon = function()
			local state = modules.RunState.get()
			if not state.active or not modules.RunState.draft_pending() then
				return false
			end
			modules.RunState.clear_draft()
			if modules.Shop and modules.Shop.is_active("draft_extra") then
				modules.Shop.consume("draft_extra")
			end
			return true
		end,

		-- The view uses this to decide what to do after a boon is taken: show the route
		-- in the Mourningstar, close in a mission.
		in_hub = function()
			return modules.Shared.is_in_hub()
		end,

		-- A curse name for the route rows. Empty string for an uncursed leg.
		curse_name = function(name)
			return modules.Curses.display_name(name)
		end,

		-- The circumstance's own icon material for the route rows, or nil. The view
		-- probes residency before drawing it; an unloaded material is a crash, not a
		-- placeholder, so nil means "text only" and that is fine.
		curse_icon = function(name)
			return modules.Curses.icon(name)
		end,

		-- 1 nuisance, 2 changes the leg, 3 ends runs. 0 for uncursed/unknown. The
		-- view colours the condition column with it.
		curse_severity = function(name)
			return modules.Curses.severity_of(name)
		end,

		-- true / false / nil(no probe). The view treats anything but true as "do
		-- not draw". Dispatches on the path: curated curse icons are a mix of
		-- circumstance MATERIALS and status TEXTURES, and each kind has its own
		-- probe.
		icon_resident = function(path)
			if type(path) ~= "string" then return nil end
			if path:find("/materials/", 1, true) then
				return modules.Icons.material_resident(path)
			end
			return modules.Icons.texture_resident(path)
		end,

		-- Turns an internal mission id into something a person can read.
		display_name = function(name)
			return modules.Missions.display_name(name)
		end,

		-- The run in progress, or nil. The view uses this to switch between "here is a
		-- route you could take" and "here is the route you are already on".
		current = function()
			local state = modules.RunState.get()
			if not state.active then return nil end
			local plan = state.plan_id and state.plan_id ~= ""
				and modules.WarPlans.get(state.plan_id) or nil
			return {
				active = true,
				queue  = state.queue,
				curses = state.curse_queue,
				index  = state.index,
				seed   = state.seed,
				plan_id   = state.plan_id,
				plan_name = plan and plan.name or nil,
			}
		end,

		-- Commit. resuming = true means the run already exists and we only need to
		-- launch the leg it is sitting on, which is what happens if you open the
		-- terminal partway through a pilgrimage.
		--
		-- v0.19.0: the War Plan chosen for this preview sets both the
		-- starting difficulty and the plan_id captured in the run.
		--
		-- v0.20.0: the Blitz setting is CAPTURED here at run start and
		-- lives in the run state for the run's lifetime. Toggling the mod
		-- option mid-run cannot change the mode of a run in progress.
		begin = function(queue, seed, resuming, curses, plan_id)
			if not modules.CharacterRuns.ready() then return false, "operative not available" end
			if not resuming then
				plan_id = plan_id or modules.WarPlans.selected_id()
				local plan = modules.WarPlans.get(plan_id)
				local starting_diff
				if plan and modules.Difficulty and modules.Difficulty.DANGER_BY_NAME then
					starting_diff = modules.Difficulty.DANGER_BY_NAME[plan.starting_difficulty_name]
				end
				if not starting_diff then
					starting_diff = modules.Difficulty and modules.Difficulty.starting_difficulty() or 0
				end
				local blitz = modules.Settings.blitz_mode_enabled()
				modules.RunState.start(queue, seed, curses, starting_diff, plan_id, blitz)
				-- v0.24.0/v0.25.0: lock the Archetype AND the Legendary
				-- in for this run, and clear pending legendary unlocks
				-- from any earlier run. Resuming runs keep their stamps.
				pcall(modules.Boons.on_run_begin)
			end

			local ok, err = modules.Launcher.launch_current_leg()
			if not ok then
				modules.Shared.notify("Pilgrimage: could not launch, " .. tostring(err), "alert")
			end
			return ok, err
		end,

		-- v0.20.0: Continue button. Launches the leg the run is currently
		-- sitting on. This is what the non-Blitz terminal uses to advance
		-- between legs; chain.tick has already run finalize_leg_completion
		-- when the previous leg ended, so run_state.index has already moved.
		continue = function()
			local state = modules.RunState.get()
			if not state.active then return false, "no run" end
			local ok, err = modules.Launcher.launch_current_leg()
			if not ok then
				modules.Shared.notify("Pilgrimage: could not launch, " .. tostring(err), "alert")
			end
			return ok, err
		end,

		-- v0.20.0: abandon during a run, either from Blitz's locked terminal
		-- or from normal terminal's own button. Wraps RunState.abandon which
		-- also clears run-scoped state; consumables are shared with the run
		-- so they die here too.
		abandon = function()
			modules.RunState.abandon("terminal")
			if modules.Shop and modules.Shop.clear_run_consumables then
				modules.Shop.clear_run_consumables()
			end
			modules.Shared.notify("Pilgrimage: run abandoned.")
			return true
		end,

		-- v0.20.0: whether THIS run is under Blitz. The view uses this to
		-- lock the terminal down to Continue+Abandon when true.
		is_blitz = function()
			local state = modules.RunState.get()
			return state.active and state.blitz == true
		end,

		-- v0.20.0: the Emporium's read/write surface. Kept small and
		-- deliberate, same discipline as the rest of route_api.
		--
		-- v0.20.1: fog helpers added so route_view can ask "is leg N
		-- supposed to be visible right now" without needing to know
		-- the horizon math.
		shop = {
			balance = function() return modules.Shop.balance() end,
			skus    = function() return modules.Shop.all() end,
			-- v0.22.33: expose get() so the view can check sku.pending
			-- before ever calling buy(). Buying a "coming soon" SKU
			-- used to silently succeed on the wallet debit path because
			-- can_buy didn't gate on `pending`; view now short-circuits.
			get     = function(id) return modules.Shop.get(id) end,
			by_category = function(cat) return modules.Shop.by_category(cat) end,
			is_active   = function(id) return modules.Shop.is_active(id) end,
			is_unlocked = function(id) return modules.Shop.is_unlocked(id) end,
			can_buy     = function(id) return modules.Shop.can_buy(id) end,
			buy         = function(id) return modules.Shop.buy(id) end,
			-- v0.22.81: the price actually charged (House Always Wins
			-- taxes the Emporium +50% while slotted). The tab renders
			-- THIS, never sku.cost, so display always matches debit.
			effective_cost = function(id) return modules.Shop.effective_cost(id) end,
			stack_count = function(id) return modules.Shop.stack_count(id) end,
			reveals_bought = function() return modules.Shop.reveals_bought() end,
			-- Fog: "is leg L visible given current leg C". Route view
			-- calls this per row rather than replicating the horizon.
			leg_visible = function(leg, current)
				return modules.Shop.leg_visible(leg, current)
			end,
			-- For labelling penance-gated locks in the UI.
			penance_name = function(pid)
				local pen = modules.Penances and modules.Penances.get
					and modules.Penances.get(pid) or nil
				return pen and pen.name or pid
			end,
		},

		-- v0.22.31: party surface for the Party tab. Everything the
		-- terminal needs to render the bot roster and let the user cycle
		-- through their bound preset per slot, without the view reaching
		-- into preset / bots directly.
		party = {
			-- Number of active bot slots (2 by default, up to 6 via
			-- penances + Emporium unlocks). The Party tab draws exactly
			-- this many rows.
			slot_count = function() return modules.Bots.slot_count() end,
			max_slots  = function() return modules.Bots.MAX_SLOTS end,

			-- List of every registered preset in catalogue order, each
			-- entry {id, display_name, unlocked}. "unlocked" respects
			-- unlock_penance; a locked preset stays in the list so the
			-- user can see it exists, but the tab greys the label.
			presets = function()
				local out = {}
				local presets = modules.Preset.all()
				for i = 1, #presets do
					local p = presets[i]
					out[i] = {
						id            = p.id,
						display_name  = p.display_name or p.id,
						role_designation = p.role_designation or "",
						fixed_legendary = p.fixed_legendary,
						fixed_legendaries = p.fixed_legendaries,
						unlocked      = modules.Preset.is_unlocked(p.id) ~= false,
						tier          = p.tier or 0,
						-- v0.22.42: expose archetype for the picker's
						-- one-per-class grey-out. Picker keys on
						-- (archetype_name, currently-bound elsewhere)
						-- to disable presets that would collide with an
						-- already-bound slot.
						archetype_name = p.archetype_name,
					}
				end
				return out
			end,

			-- v0.22.42: which archetype (if any) is bound to a slot.
			-- Picker reads this once per open to determine grey-out.
			-- Same call the class-uniqueness gate in bind_slot uses,
			-- exposed here so the view can preview the conflict
			-- BEFORE the user clicks a locked entry.
			slot_archetypes = function()
				return modules.Preset.slot_archetypes()
			end,

			-- The old same-class safety lock remains switchable in preset.lua,
			-- but is disabled while isolated same-class bots are field-tested.
			class_lock_enabled = function()
				return modules.Preset.class_lock_enabled()
			end,

			-- What preset (if any) is bound to a specific slot. Nil and the
			-- explicit "none" sentinel both mean an empty slot.
			binding_for_slot = function(slot)
				if not slot then return nil end
				return modules.Preset.slot_bindings()[slot]
			end,

			human_occupant = function(slot)
				return modules.RealmsBridge.human_occupant_for_bot_slot(slot)
			end,

			-- Rotate the slot's binding to the next preset in the list.
			-- Retained for API compatibility even though the Party tab uses
			-- a picker. Cycle order: empty -> preset[1] -> ... -> empty.
			-- Locked presets are skipped over so the tab never lands on
			-- one the game will not spawn.
			cycle_slot = function(slot)
				if not slot then return end
				local presets = modules.Preset.all()
				local current = modules.Preset.slot_bindings()[slot]
					or modules.Preset.NONE_BINDING or "none"

				-- Build the cycle: explicit empty, then every unlocked
				-- preset in catalogue order. Locked ones drop out here
				-- so the cycle never surfaces them.
				local cycle = { modules.Preset.NONE_BINDING or "none" }
				for i = 1, #presets do
					if modules.Preset.is_unlocked(presets[i].id) ~= false then
						cycle[#cycle + 1] = presets[i].id
					end
				end

				local at = 1
				for i = 1, #cycle do
					if cycle[i] == current then at = i; break end
				end
				local next_i = at % #cycle + 1
				local next_id = cycle[next_i]

				if next_id == (modules.Preset.NONE_BINDING or "none") then
					modules.Preset.bind_slot(slot,
						modules.Preset.NONE_BINDING or "none")
				elseif next_id then
					modules.Preset.bind_slot(slot, next_id)
				end
				return next_id
			end,
		},

		-- v0.22.81 (Boon Loadout), reshaped v0.22.82 to the slot-map
		-- model (Kaizen: mimic the party slot system). Slot rows on
		-- the tab, a picker for choosing, buy inside the picker.
		loadout = {
			slots     = function() return modules.Boons.loadout_slots() end,
			max_slots = function() return 4 end,

			-- v0.24.0 (Boons v2): Archetype slot accessors. The view's
			-- Loadout tab renders the slot and cycles the selection;
			-- everything stays behind this API per the coupling rule.
			archetype_unlocked = function()
				return modules.Boons.archetype_slot_unlocked()
			end,
			archetype_cost = function()
				local sku = modules.Shop.get and modules.Shop.get("archetype_slot")
				return sku and sku.cost or 1500
			end,
			selected_archetype = function()
				local id = modules.Boons.selected_archetype_id()
				local a = id and modules.Boons.archetype_get(id) or nil
				return a and { id = a.id, name = a.name, short = a.short,
					description = a.description } or nil
			end,
			-- v0.24.1: cycling REPLACED with a proper picker (Kaizen:
			-- the same mistake the capture dropdown already taught us;
			-- lists, not cycles). The view renders these entries.
			archetypes = function()
				local out = {}
				local all = modules.Boons.archetype_all()
				local selected = modules.Boons.selected_archetype_id()
				for i = 1, #all do
					local a = all[i]
					local unlocked = modules.Boons.archetype_is_unlocked(a.id)
					out[#out + 1] = {
						id          = a.id,
						name        = a.name,
						short       = a.short or "",
						description = a.description or "",
						selected    = (a.id == selected),
						unlocked    = unlocked,
						gate         = not unlocked and "test access (penance pending)" or nil,
					}
				end
				return out
			end,
			select_archetype = function(id)
				return modules.Boons.set_selected_archetype(id)
			end,
			-- v0.24.1: the view greys the whole Loadout tab out mid-run.
			loadout_locked = function()
				return modules.RunState.is_active()
			end,

			-- v0.25.0: Legendary slot accessors. Names are hordes buff
			-- template ids; display comes through Boons.info (the
			-- game's own presentation table). usable = present in the
			-- CURRENT character's pool, so the picker can grey out a
			-- psyker legendary while a Veteran is selected.
			legendaries = function(slot_index)
				local out = {}
				local ids = modules.Boons.legendary_unlocked_ids()
				slot_index = tonumber(slot_index) == 2 and 2 or 1
				local slot = slot_index == 2
					and modules.Boons.temporary_legendary_slot()
					or modules.Boons.legendary_slot()
				local other = slot_index == 2
					and modules.Boons.legendary_slot()
					or modules.Boons.temporary_legendary_slot()
				local pool = modules.Boons.pool()
				local in_pool = {}
				for i = 1, #pool do in_pool[pool[i]] = true end
				for i = 1, #ids do
					local name = ids[i]
					local title, desc = name, ""
					local ok_i, info = pcall(modules.Boons.info, name)
					if ok_i and info then
						title = (info.title and info.title ~= "") and info.title or name
						desc = info.description or ""
					end
					out[#out + 1] = {
						id          = name,
						name        = title,
						description = desc,
						section     = modules.Boons.legendary_archetype(name),
						usable      = in_pool[name] == true,
						inert_reason = in_pool[name] ~= true
							and modules.Boons.legendary_inert_reason(name) or nil,
						selected    = (name == slot),
						equipped_other = (name == other),
					}
				end
				return out
			end,
			select_legendary = function(id, slot_index)
				if tonumber(slot_index) == 2 then
					return modules.Boons.set_temporary_legendary_slot(id)
				end
				return modules.Boons.set_legendary_slot(id)
			end,
			selected_legendary = function(slot_index)
				local id = tonumber(slot_index) == 2
					and modules.Boons.temporary_legendary_slot()
					or modules.Boons.legendary_slot()
				if not id then return nil end
				local title = id
				local ok_i, info = pcall(modules.Boons.info, id)
				if ok_i and info and info.title and info.title ~= "" then title = info.title end
				return { id = id, name = title }
			end,
			run_legendary = function(slot_index)
				local id = tonumber(slot_index) == 2
					and modules.Boons.active_temporary_legendary()
					or modules.Boons.active_legendary()
				if not id then return nil end
				local title = id
				local ok_i, info = pcall(modules.Boons.info, id)
				if ok_i and info and info.title and info.title ~= "" then title = info.title end
				return { id = id, name = title }
			end,
			temporary_legendary_unlocked = function()
				return modules.Boons.temporary_legendary_slot_unlocked()
			end,
			temporary_legendary_cost = function()
				local sku = modules.Shop.get and modules.Shop.get("temp_slot")
				return sku and sku.cost or 2000
			end,
			-- The archetype LOCKED into the active run (differs from the
			-- selection when the player changes it mid-run; the run
			-- keeps its stamp).
			run_archetype = function()
				local id = modules.Boons.active_archetype_id()
				local a = id and modules.Boons.archetype_get(id) or nil
				return a and { id = a.id, name = a.name } or nil
			end,
			binding_for_slot = function(slot)
				return modules.Boons.binding_for_boon_slot(slot)
			end,
			bind = function(slot, id)
				return modules.Boons.bind_boon_slot(slot, id)
			end,
			buy = function(id) return modules.Boons.buy_custom(id) end,
			get = function(id)
				local b = modules.Boons.custom_get(id)
				return b and { id = b.id, name = b.name or b.id } or nil
			end,
			list = function()
				local out = {}
				local all = modules.Boons.custom_all()
				for i = 1, #all do
					local b = all[i]
					out[#out + 1] = {
						id          = b.id,
						name        = b.name or b.id,
						description = b.description or "",
						short       = b.short or "",
						cost        = b.cost or 0,
						archetype   = b.archetype,
						owned       = modules.Boons.is_owned(b.id),
						bound_slot  = modules.Boons.slot_of(b.id),
					}
				end
				return out
			end,
		},

		-- v0.22.77 (Session B phase 2): Penances tab API. One read-only
		-- list; the view groups by category and paginates. Each entry
		-- carries everything the row needs so the view never touches
		-- the Penances module directly.
		penances = {
			list = function()
				local out = {}
				local all = modules.Penances.all and modules.Penances.all() or {}
				for i = 1, #all do
					local p = all[i]

					-- v0.22.79: an explicit short unlocks_label on the
					-- penance def wins outright (every penance has one
					-- now). The resolver below stays as a fallback for
					-- future entries that forget to set it.
					local parts = {}
					if p.unlocks_label then
						parts[#parts + 1] = p.unlocks_label
					elseif p.unlocks then
						local preset = modules.Preset.get and modules.Preset.get(p.unlocks) or nil
						local plan = not preset and modules.WarPlans.get
							and modules.WarPlans.get(p.unlocks) or nil
						local target = (preset and (preset.display_name or p.unlocks))
							or (plan and (plan.name or p.unlocks))
							or tostring(p.unlocks)
						parts[#parts + 1] = "unlocks " .. target
					end
					if p.also_grants then
						parts[#parts + 1] = tostring(p.also_grants)
					end

					out[#out + 1] = {
						id           = p.id,
						name         = p.name or p.id,
						description  = p.description or "",
						category     = p.category or "vanity",
						earned       = modules.Penances.is_earned
							and modules.Penances.is_earned(p.id) == true or false,
						unlocks_label = #parts > 0 and table.concat(parts, "; ") or nil,
					}
				end
				return out
			end,
		},

		-- v0.22.51 (Session H): War Plan picker API. Small deliberate
		-- surface, same discipline as party/shop. The view reads it
		-- from _refresh_war_plan_pick.
		war_plans = {
			-- Every plan in order (novitiate → penitent → fanatic →
			-- martyr, plus saint once we ship it), each row carrying
			-- the flags the picker needs to render it.
			list = function()
				local plans = modules.WarPlans.all and modules.WarPlans.all() or {}
				local out = {}
				for i = 1, #plans do
					local p = plans[i]
					local unlocked = modules.WarPlans.is_unlocked(p.id) == true
					-- Resolve the gate penance's human name so the
					-- picker row can say "locked - Faithful Pilgrim"
					-- instead of "locked - pilgrim_faithful". Field on
					-- the plan is `unlock_penance` per war_plans.lua.
					local gate = nil
					if not unlocked and p.unlock_penance then
						local pen = modules.Penances.get and modules.Penances.get(p.unlock_penance) or nil
						gate = pen and pen.name or p.unlock_penance
					end
					out[#out + 1] = {
						id           = p.id,
						display_name = p.name or p.id,
						unlocked     = unlocked,
						gate_penance = gate,
					}
				end
				return out
			end,
			selected_id = function() return modules.WarPlans.selected_id() end,
			select = function(id) return modules.WarPlans.select(id) end,
			is_unlocked = function(id) return modules.WarPlans.is_unlocked(id) end,
		},

		-- v0.20.1: helpers the route view needs to render "SKIP purchased"
		-- or "REROLL: <new curse>" badges on the current-leg row. Both
		-- read state without mutating it, so calling from the view frame
		-- loop is safe.
		--
		-- v0.20.3: reroll_for_leg now takes the plan's tier range so a
		-- reroll on Novitiate cannot land on a tier-3 curse. Preview uses
		-- the currently selected plan; mid-run uses the run's captured
		-- plan_id so the preview matches what would actually be rolled.
		curse_after_reroll = function(seed, leg)
			if not modules.Curses or not modules.Curses.reroll_for_leg then
				return nil
			end
			local state = modules.RunState.get()
			local plan_id
			if state.active and state.plan_id and state.plan_id ~= "" then
				plan_id = state.plan_id
			else
				plan_id = modules.WarPlans.selected_id()
			end
			local plan = modules.WarPlans.get(plan_id)
			local min_tier = plan and plan.min_tier
			local max_tier = plan and plan.max_tier
			local total = plan and plan.leg_count or leg or 1
			-- v0.22.35: mid-run preview excludes curses already in the
			-- queue so the badge on the route row shows the ACTUAL
			-- landing curse (which drops duplicates), not a stale
			-- pick that would get filtered at launch time.
			local exclude = state.active and state.curse_queue or nil
			return modules.Curses.reroll_for_leg(seed, leg, min_tier, max_tier, total, exclude)
		end,
	}

	-- -----------------------------------------------------------------------
	-- The tactical overlay panel's data feed.
	--
	-- Same contract shape as pilgrimage_terminal_prompt: the GAME constructs
	-- the HUD element (overlay_hud.lua), so nothing can be injected into it;
	-- it reaches back for this one accessor. Called once per frame WHILE THE
	-- OVERLAY IS HELD, so everything here is either a cached-table read or a
	-- string.format; the one Localize call sits behind a cache.
	--
	-- Returns nil (draw nothing) outside an active run or with the setting
	-- off. Line shape: { text = string, color = {a, r, g, b} }.
	-- -----------------------------------------------------------------------

	local OVERLAY_TITLE = "PILGRIMAGE"
	local COLOUR_BODY = { 255, 210, 210, 210 }
	local COLOUR_DIM  = { 255, 150, 150, 150 }
	local COLOUR_OK   = { 255, 130, 200, 130 }
	local COLOUR_WARN = { 255, 230, 120, 100 }
	-- The route view's severity ramp, same values: 1 stays dim, 2 warms to the
	-- UI's gold, 3 leans red because it is the reason runs end.
	local SEVERITY_COLOURS = {
		[1] = { 255, 170, 170, 170 },
		[2] = { 255, 255, 226, 168 },
		[3] = { 255, 230, 120, 100 },
	}

	-- Localize is not free and mission names do not change; cache per id.
	local _mission_label_cache = {}
	local function _mission_label(name)
		if not name then return "?" end
		local cached = _mission_label_cache[name]
		if not cached then
			cached = modules.Missions.display_name(name)
			_mission_label_cache[name] = cached
		end
		return cached
	end

	mod.pilgrimage_overlay_lines = function()
		if mod:get("enable_overlay_panel") == false then return nil end

		local state = modules.RunState.get()
		if not state.active then return nil end

		local in_hub = modules.Shared.is_in_hub()
		local index, total = state.index, #state.queue
		local mission = state.queue[index]
		if not mission then return nil end

		local lines = {}
		local function add(text, colour)
			lines[#lines + 1] = { text = text, color = colour }
		end

		-- Line budget: MAX_LINES = 6 in overlay_hud.lua. This function must
		-- NEVER add a seventh line, so the shape below is fixed at exactly 5
		-- or 6 lines regardless of stack depth. Each line either fits its
		-- content or shortens it; nothing scrolls off.
		--
		-- 1. Assignment N of M: <mission>
		-- 2. Now: <current curse>          (severity-colored, or "None" line)
		-- 3. Also: <count> stacked         (only when a stack exists; skipped otherwise)
		-- 4. <M modifiers live> / WARNING  (only in-mission; skipped in hub)
		-- 5. Next: <mission> (<curse>)     (or "Final assignment")
		-- 6. Boons N  Seed X

		-- v0.19.1: append the danger name computed by difficulty.for_leg,
		-- so a Malice leg says "Malice" on screen and Kaizen never has to
		-- guess whether the ramp landed where he expected. Small text.
		local diff = modules.Difficulty and modules.Difficulty.for_leg
			and modules.Difficulty.for_leg(index, state.starting_difficulty) or nil
		local danger_note = ""
		if diff and diff.danger_name then
			danger_note = "  (" .. diff.danger_name
			if diff.scale_tier and diff.scale_tier > 0 then
				danger_note = danger_note .. " +T" .. diff.scale_tier
			end
			danger_note = danger_note .. ")"
		end
		add(string.format("%sAssignment %d of %d:  %s%s",
			in_hub and "Next:  " or "", index, total, _mission_label(mission), danger_note),
			COLOUR_BODY)

		local current = modules.RunState.current_curse()
		if current then
			add("Now:  " .. modules.Curses.display_name(current),
				SEVERITY_COLOURS[modules.Curses.severity_of(current)] or COLOUR_BODY)
		else
			add("Now:  no condition this assignment", COLOUR_DIM)
		end

		-- Stacked earlier curses collapsed onto ONE line so a 4-curse stack
		-- doesn't push everything else off the panel. Kaizen's screenshot
		-- showed the box was already at capacity at 3 curses; hard-limiting
		-- to one line keeps the panel a fixed shape regardless of stack size.
		if modules.Curses.stacking_enabled() then
			local prefix = modules.RunState.curse_prefix() or {}
			local extras = {}
			-- v0.22.99: plan-forced curses (Martyr/Saint Auric Intensity)
			-- ride every leg outside the rolled queue; list them first so
			-- the panel shows why the mission is hotter than its curse.
			if modules.Curses.forced_for_run then
				local ok_f, forced = pcall(modules.Curses.forced_for_run)
				if ok_f and type(forced) == "table" then
					for i = 1, #forced do
						extras[#extras + 1] = modules.Curses.display_name(forced[i])
					end
				end
			end
			for i = index - 1, 1, -1 do
				local name = prefix[i]
				if type(name) == "string" and name ~= "" and name ~= "default" then
					extras[#extras + 1] = modules.Curses.display_name(name)
				end
			end
			if #extras > 0 then
				local text
				if #extras == 1 then
					text = "Also:  " .. extras[1] .. "  (stacked)"
				elseif #extras == 2 then
					text = "Also:  " .. extras[1] .. ", " .. extras[2] .. "  (stacked)"
				else
					text = string.format("Also:  %s, %s +%d more  (stacked)",
						extras[1], extras[2], #extras - 2)
				end
				add(text, COLOUR_DIM)
			end
		end

		if not in_hub and current then
			local guard = modules.MutatorGuard.last_report()
			local record = modules.RunState.launch_record()
			if guard and record and guard.mission == record.mission
				and guard.mission == mission then
				if #guard.mutators > 0 then
					add(string.format("%d modifier%s live", #guard.mutators,
						#guard.mutators == 1 and "" or "s"), COLOUR_OK)
				else
					add("WARNING: no modifiers loaded", COLOUR_WARN)
				end
			end
		end

		local next_mission = state.queue[index + 1]
		if next_mission then
			local next_curse = state.curse_queue[index + 1]
			local next_label = ""
			if next_curse and next_curse ~= "default" then
				next_label = "  (" .. modules.Curses.display_name(next_curse) .. ")"
			end
			add(string.format("Then:  %s%s", _mission_label(next_mission), next_label), COLOUR_DIM)
		else
			add("Final assignment", COLOUR_DIM)
		end

		local boons = 0
		for _, stacks in pairs(state.boons) do
			boons = boons + (tonumber(stacks) or 0)
		end
		local ordos = modules.Wallet and modules.Wallet.balance() or 0
		add(string.format("Boons %d   Ordos %d   Seed %d",
			boons, ordos, state.seed or 0), COLOUR_DIM)

		return { title = OVERLAY_TITLE, lines = lines }
	end

	-- -----------------------------------------------------------------------
	-- Recurring work. Everything that needs a heartbeat registers here, in one
	-- place, so the frequency ladder is visible at a glance.
	-- -----------------------------------------------------------------------

	modules.Tick.register("event_log_flush", 5, function(t)
		modules.EventLog.try_flush(t)
	end)

	modules.Tick.register("perf_sync", 2, function()
		modules.Perf.sync_setting()
	end)

	-- Clears a stuck launch flag. Without it a launch whose promise never resolves
	-- would block every future launch for the rest of the session.
	modules.Tick.register("launch_watchdog", 2, function(t)
		modules.Launcher.tick(t)
	end)

	-- Advances a run once you are back in the Mourningstar after a leg.
	modules.Tick.register("chain", 1, function(t)
		modules.Chain.tick(t)
	end)

	-- Drives the terminal: finds the prop, keeps its marker alive, decides whether the
	-- prompt is up, and watches the interact key. Four times a second is well above what
	-- the eye needs for a prompt appearing and far below the cost of doing it per frame.
	-- Offers the boon draft a few seconds into a leg. Cheap: three boolean checks and an
	-- early-out in every case except the one frame it actually opens the view.
	modules.Tick.register("boon_draft", 0.5, function(t)
		modules.Boons.draft_tick(t)
	end)

	-- Asks the engine to keep the Mortis Trials buff icon package resident, so boon
	-- icons draw as art rather than as the placeholder hexagon. Idempotent and it
	-- early-outs on a boolean once it has succeeded, so this is a no-op forever after
	-- the first few seconds. It is a tick rather than a one-shot at init because the
	-- package manager does not exist yet when mods load.
	--
	-- v0.17.3: interval shortened from 5s to 1s. Fresh boot spent 0-5 seconds
	-- showing placeholder hexagons before the first patch pass; 1s gets the
	-- HUD showing real art in ~1s from state entry. Cost per no-op tick is one
	-- table pair check (icons.ensure early-outs on _attempted).
	modules.Tick.register("icons", 1, function(t)
		modules.Icons.ensure()
		modules.Icons.ensure_custom()
		-- Writes the loaded custom textures over the hordes buff templates' dead
		-- hud_icon strings, which is what makes the GAME's own buff stack and
		-- tactical overlay draw them. Internally guarded: it only walks the
		-- template table when a new texture arrived since the last walk.
		modules.Icons.patch_templates()
	end)

	modules.Tick.register("terminal", 0.25, function(t)
		modules.Terminal.tick(t)
	end)

	-- v0.22.77 (Session B phase 2): the penance time poll. Once a second,
	-- while a run is active and the player is inside the exact mission
	-- assigned by the Pilgrimage route (not the hub, Psykhanium, a loading
	-- screen, or an unrelated mission launched while a run remains active), it accumulates
	-- observed play time and, for a Zealot running the Martyrdom
	-- keystone, the seconds spent at 3+ Martyrdom stacks. Those two
	-- counters are the numerator/denominator of Dancing on the Web's 80%
	-- requirement. This task is ALSO the periodic save point that folds
	-- the deferred damage-dealt / companion-kill counters into DMF
	-- settings (see run_state.add_damage_dealt).
	--
	-- Martyrdom stacks are NOT read from the buff (stack count isn't
	-- exposed); they're recomputed exactly the way Fatshark's own
	-- zealot_buff_templates does it: missing health segments =
	-- max_wounds - calculate_num_segments(max(damage_taken,
	-- permanent_damage_taken), max_health, max_wounds). The keystone
	-- presence check (any active buff whose template name starts with
	-- "zealot_martyrdom") stops a non-Martyrdom Zealot from farming the
	-- uptime by just being wounded.
	local _penance_time_last_t = nil
	local _health_util = nil
	modules.Tick.register("penance_time", 1, function(t)
		local prev = _penance_time_last_t
		_penance_time_last_t = t

		if not modules.RunState.is_active() then return end
		if modules.Shared.is_in_hub() or modules.Shared.is_in_psykhanium() then return end
		if not modules.Shared.game_mode_name() then return end

		-- v0.28.51: a game-mode name is too broad. Ordinary missions and
		-- Pilgrimage assignments both use coop_complete_objective, so compare
		-- the real loaded mission against the route's current assignment.
		-- This also fails closed if either name is unavailable during load.
		local expected_mission = modules.RunState.current_mission()
		local actual_mission = modules.Shared.mission_name()
		if type(expected_mission) ~= "string" or expected_mission == ""
			or actual_mission ~= expected_mission then
			return
		end

		local Managers = rawget(_G, "Managers")
		local player = Managers and Managers.player
			and Managers.player:local_player_safe(1)
		local unit = player and player.player_unit
		if not unit then
			-- No live unit (dead/despawned/loading): don't count this
			-- gap, and don't let it accumulate into the next sample.
			return
		end

		-- Clamped delta so a long hitch or a missed schedule slot never
		-- injects a large lump of "time" in one sample.
		local delta = prev and (t - prev) or 0
		if delta <= 0 then return end
		if delta > 3 then delta = 3 end

		local martyrdom_active = false
		local state = modules.RunState.get()
		if (state.stat_archetype or "") == "zealot" then
			pcall(function()
				local ScriptUnit = rawget(_G, "ScriptUnit")
				if not ScriptUnit then return end
				local he = ScriptUnit.has_extension(unit, "health_system")
				local be = ScriptUnit.has_extension(unit, "buff_system")
				if not he or not be then return end

				-- Keystone present? Any active zealot_martyrdom* buff
				-- counts (the passive family: toughness / toughness
				-- modifier / cdr variants).
				local has_keystone = false
				local buffs = be._buffs_by_index
				if type(buffs) == "table" then
					for _, instance in pairs(buffs) do
						local ok_tpl, tpl = pcall(function() return instance:template() end)
						local name = ok_tpl and tpl and tpl.name or nil
						if type(name) == "string" and name:find("^zealot_martyrdom") then
							has_keystone = true
							break
						end
					end
				end
				if not has_keystone then return end

				if _health_util == nil then
					-- VoxFilter-style lazy require with a false cache on
					-- failure, so a bad require is not retried per tick
					-- and an error string can't masquerade as the module.
					local ok_h, h = pcall(require, "scripts/utilities/health")
					_health_util = (ok_h and h) or false
				end
				if not _health_util or not _health_util.calculate_num_segments then return end

				local max_wounds = he:max_wounds()
				local max_health = he:max_health()
				local damage_taken = he:damage_taken()
				local permanent = he:permanent_damage_taken()
				local current_wounds = _health_util.calculate_num_segments(
					math.max(damage_taken, permanent), max_health, max_wounds)
				local stacks = (max_wounds or 0) - (current_wounds or 0)
				martyrdom_active = stacks >= 3
			end)
		end

		modules.RunState.add_combat_time(delta, martyrdom_active)
	end)

	-- The one frame-rate task in the mod, and it earns it. "interact_pressed" is true for
	-- a single frame, so a 4Hz poll misses it almost every time, which is exactly why
	-- pressing E did nothing in 0.9.0. Interval 0 means every frame; the task early-outs
	-- on one boolean whenever the prompt is not showing.
	modules.Tick.register("terminal_input", 0, function(t)
		modules.Terminal.input_tick(t)
	end)

	-- Retries a settings write to disk that was throttled or that failed to verify.
	-- Cheap: it early-outs on a boolean when there is nothing outstanding, which is
	-- almost always.
	-- v0.22.20: auto-apply NPC Look to Pilgrimage bots. Cheap early-out
	-- when NPC Look isn't installed (or the patched entry point is
	-- missing), and each bot only pumps until its apply lands cleanly.
	--
	-- v0.22.34: 0.5s -> 1.5s. Kaizen reported ~10-20s of mission-start
	-- hitching; the pump was calling NPC Look's expensive equip_all
	-- 40x per bot inside its retry window. At 1.5s each bot fires
	-- equip_all a third as often. The extras finish loading at NPC
	-- Look's pace regardless; we just stop hammering it while it works.
	-- v0.22.39: pump interval stays at 1.5s but MAX_RETRIES bumped from
	-- 15 back up to 40 (see preset.NPCLOOK_APPLY_MAX_RETRIES). Four
	-- distinct preset cosmetic sets loading at once needed longer than
	-- the 22.5s ceiling gave us.
	modules.Tick.register("npclook_bot_apply", 1.5, function()
		modules.Preset.pump_npclook_apply()
	end)

	-- v0.22.21: auto-apply Pilgrimage bot passives. Same interval, same
	-- pump-until-applied pattern. Cheap after all bots are done because
	-- the pump early-outs on the "applied" set once every passive for
	-- a unit has landed. Depends on custom buff templates being
	-- registered, which happens at Passives.init above.
	modules.Tick.register("passives_bot_apply", 0.5, function()
		modules.Passives.pump(modules.Preset)
	end)

	-- v0.22.45: bot servo skull auto-dispatch. Scans for stalled
	-- decoding interactables and tags them so any Skitarii bot's skull
	-- flies over and hacks the minigame. 2s interval: fast enough for
	-- the bot to react to a fresh interrogator before the player
	-- notices, slow enough that the map iteration cost is trivial.
	-- The module gates internally on enable_bot_hack_orders + presence
	-- of at least one Skitarii bot, so a solo run with no cryptic
	-- preset bound to any slot pays only the "get bot list" cost.
	modules.Tick.register("bot_hack_orders", 2, function(t, dt)
		modules.BotHackOrders.tick(t, dt)
	end)

	modules.Tick.register("run_state_flush", 3, function(t)
		modules.RunState.flush_tick(t)
	end)

	-- One-second session maintenance is enough for rule changes and disconnect
	-- cleanup. Roster rendering reads Managers.player directly and therefore does
	-- not need a frame-rate network poll.
	modules.Tick.register("realms_bridge", 1, function()
		modules.RealmsBridge.tick()
	end)

	modules.CharacterRuns.set_callbacks(function()
		-- Preserve dirty combat counters before changing the storage namespace.
		-- Defer the disk flush to DMF's state-change save, avoiding login stalls.
		modules.RunState.save(false, true)
	end, function()
		modules.RunState.load()
		modules.Boons.reset_leg()
		modules.Chain.reset()
		local managers = rawget(_G, "Managers")
		local ui = managers and managers.ui
		if ui and ui.close_view and ui.view_active then
			pcall(function()
				if ui:view_active(modules.Terminal.VIEW_NAME) then
					ui:close_view(modules.Terminal.VIEW_NAME)
				end
			end)
		end
	end)
	modules.Tick.register("character_runs", 1, function()
		-- Covers a late player profile and in-hub operative changes. No file IO.
		if not modules.CharacterRuns.ready() or modules.Shared.is_in_hub()
			or modules.Shared.is_in_psykhanium() then
			modules.CharacterRuns.refresh("gameplay")
		end
	end)
	modules.MissionIncidents.init({mod=mod, shared=modules.Shared,
		events=modules.EventLog, run=modules.RunState})
	modules.Tick.register("mission_incidents", 1, modules.MissionIncidents.tick)
	return modules
end

return M
