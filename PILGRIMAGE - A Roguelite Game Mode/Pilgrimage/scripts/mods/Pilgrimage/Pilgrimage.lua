-- Pilgrimage.lua
--
-- Entry point. Responsibilities, and nothing else:
--   * load the three pre-bootstrap modules
--   * own the throttled debug logger that every other module uses
--   * run bootstrap
--   * own every DMF lifecycle callback
--   * own every engine hook (consolidated, so DMF cannot silently drop one)
--
-- Feature logic does not live here. It lives in modules, and gets wired up in
-- bootstrap.lua.

local mod = get_mod("Pilgrimage")

local ROOT = "Pilgrimage/scripts/mods/Pilgrimage/"

-- v0.22.75 (Session I): Tier 1 + Tier 2 preset content, tier-grouped
-- party picker with pagination and the "None, leave slot empty"
-- binding, custom titles for the new tiers, and bot voice fx filters
-- (Heavy Combat Servitor). Versions 0.22.68-0.22.74 were burned on
-- the shelved cutscene-extras hunt and rolled back to the 0.22.67
-- baseline; 0.22.75 is the first version built on the restored state.
-- v0.22.76: picker section headers are now real dividers (no bar, no
-- hover highlight, no hover/click sounds, bracketed uppercase label)
-- per Kaizen's first field test of v0.22.75.
-- v0.22.77 (Session B phase 2): complex penance emitters (damage-dealt
-- split via StatsManager, companion kills, Martyrdom uptime poll,
-- Voltaic weapon disables) + the Penances terminal tab.
-- v0.22.78: Heinrix voice → Agitator Male (cross-class, PP v5.21
-- cross-class ability support); new Tier 3 preset Cassia Orsellio.
-- v0.22.79: field-report fixes and the slots redesign. Freeze fix
-- (in-mission stat saves no longer force settings-file flushes),
-- penance unlock labels always visible, Ordos earn multiplier and Zero
-- Waste draft size actually wired, slots 3-4 moved to Emporium
-- purchases with slots 5-6 penance-gated (Full Muster, The Emperor
-- Sends Six), bots_slotted stat finally recorded (fixes Solo Sacrament
-- auto-earn).
-- v0.22.80: Theodora + Idira unlock penances (A Rogue Trader's
-- Fortune, Unsanctioned Fury) and their signature kits (Idira: Warp
-- Torrent / Unstable Wake / Overwhelmed Not Consumed / Thrice-Bound
-- Soul / Perilous Vessel; Theodora: Duellist's Poise + wallet-side
-- Dynastic Largesse).
-- v0.22.81 (Session F foothold / Boons v2): six custom boons
-- (Unlimited Power, Krieg Doctrine, Blood Debt, Redline Cogitator,
-- The House Always Wins, The Bigger They Are), permanent Ordos
-- purchases slotted into the new Boon Loadout (1 slot base, Doctrine
-- Slot expansions in the Emporium), active from run start, excluded
-- from drafts. Fifth terminal tab "Loadout".
-- v0.22.82: UI rework per field feedback (Emporium pagination with
-- category headers, Loadout tab moved left of Party, loadout rebuilt
-- on the party-slot model with a paginated boon picker) + Unlimited
-- Power fix (Smite channel relabelled smite-typed so the multiplier
-- branch applies).
-- v0.22.83: Unlimited Power third implementation (conditional stat
-- buff on wielding Smite; dead relabel hook removed), Emporium prices
-- visible on non-buyable rows.
-- v0.22.84: Unlimited Power FOURTH implementation (Kaizen's lockdown
-- design): flat 10x damage, weapon wield inputs blocked, auto-snap
-- back to Smite via the InputService seam, Peril-gated.
-- v0.27.5: NPC Look bridge v2. Public NPC Look 2.1.1 now receives
-- cinematic extra-slot visibility and mission-teardown package retention
-- in memory, without replacing or redistributing NPC Look files.
-- v0.28.0: Boons v2 Wave B begins with the Unkillable reaction cluster:
-- Hard to Finish, Last Reserve, Brace for It, and Refusal Response.
-- v0.28.1: Wave B timed triggers: Hot Blood, Pyre Tithe, Reactive
-- Chemistry, Clean Holster, Fan the Hammer, Afterimage, and
-- Executioner's Rhythm. Credited ailment deaths use their native server
-- event; hidden child buffs own duration refreshes and stack caps.
-- v0.28.2: Overwhelming Mind's synthetic Shrieks now play the native
-- ability sound, mission drafts can add distinct relevant Legendaries
-- alongside the pre-run pick, and three Tier 2 capture targets join the
-- preset catalogue.
-- v0.28.3: Wave B nearby-state cluster. Copper Nerves, Faraday Soul
-- and Entropy Feast count current ailments within 8 metres and reconcile
-- network-synchronized hidden stat stacks every half second.
-- v0.28.4: Wave B hit/application cluster. Seven family boons use native
-- hit, dodge and sweep events, target-side ailment stacks, one non-additive
-- elemental damage gate, and synchronized timed child stats.
-- v0.28.5: Wave B icons use the field-proven Hordes family palette;
-- Tougher Skin gets an Adventure-safe fixed-rank buff and launch migration;
-- bot wound audit confirms the universal/tier baseline adds no duplicate.
-- v0.28.6: Legendary secondary damage borrows a shipped network profile,
-- preventing missing damage-profile lookup crashes from arcs and replays.
-- v0.28.8: LOUDER! fortifies the team on all three native Taunt waves;
-- bots use a stable three-wound baseline before build-specific additions;
-- all three v0.28.2 capture targets appear in the debug dropdown.
-- v0.28.9: Perilous Vessel enters the authentic Psyker overload action and
-- consumes a wound through its Crystalline Will-style survival branch;
-- Moving Target and Deadeye Drift add synchronized movement-state damage.
-- v0.28.11: Flashover, Closed Circuit and Thermal Shock complete the
-- approved elemental capstone batch. A narrow minion-ailment observer owns
-- cross-element timing; secondary damage retains the network-safe profile.
-- Pyromancer and Dynamo now draw only their pure Fire/Electric families.
-- v0.28.12: Afflictor adds a target-debuff damage curve. Draft compatibility
-- uses explicit multi-tags, allowing independently useful mixed-element cards
-- without offering pure shock or two-element requirements to Pyromancer.
-- v0.28.16: corrected Serpent FF, melee-lock returns and preset/return fixes.
-- v0.28.17: added Conduit plus the cross-ailment reaction and duration batch.
-- v0.28.18: corrected the terminal return flag lifecycle, clarified exact
-- Legendary loadout requirements, and retired Conduit from new selections
-- pending its approved redesign.
-- v0.28.15: Goliath/Bulwark identity split and melee-only Executioner.
-- v0.28.14: retroactive NPC Look voice filters and terminal-return placement.
-- v0.28.13: preset capture stores VoxFilter pins plus gear-derived baselines;
-- same-class parties are enabled behind a retained rollback switch; Heavy
-- Combat Servitor is melee-only with no blitz; Idira gains a native-action
-- field diagnostic while her unchanged 10% passive remains under observation.
-- v0.28.21: fixes Entropy Feast buff-array crashes, first-leg Sticky
-- Poxburster dead mutators, Hazard Pay's premature lethal check, late hub
-- spawn resets and stalled-interrogator servo-skull orders.
-- v0.28.22: Hazard Pay becomes a latched top-priority friendly-fire mode;
-- adds session-only mid-mission boon laboratory commands and FF status.
-- v0.28.23: optional Pilgrimage-owned Better Bots navigation bridge.
-- v0.28.24: heavy-only Goliath tuning and reliable native terminal return.
-- v0.28.25: action-scoped Goliath offense and strict optional Better Bots
-- navigation isolation after the first guard remained crashable in the field.
-- v0.28.26: closes the Fire, Electric and Cowboy family batch with Backdraft,
-- Fireproofed, Capacitance Feedback, First to Draw and Dead Man's Chamber.
-- v0.28.27: makes movement-conditioned ranged stats array-safe and arms the
-- native terminal return before options-menu mission exits.
-- v0.28.28: makes Dead Man's Chamber accept Darktide's hitscan-first and
-- projectile-first event ordering, including replacement-shot damage.
-- v0.28.29: completes the Critical family with Opening Cut, Weakpoint
-- Cartography, Coup de Grace and Failure Analysis.
-- v0.28.30: adds six Unstoppable family boons and Belt-Fed Believer for
-- Point-Blank Barrage, using native sprint, stagger, stamina and ammo systems.
-- v0.28.32: adds Pilgrim's Momentum, Chorus Everlasting, Harrowing Rebuke
-- and Fly Trap, plus a costly second run-scoped Legendary loadout slot.
-- v0.28.34: guards the end-of-round face animation when cosmetic bridges
-- intentionally produce a character model without a separate face unit.
-- v0.28.35: Harrowing Rebuke deterministically treats Carapace as Flak and
-- gives later Assail shards +50% against the same heavy target for two seconds.
-- v0.28.37: the hub return uses its persistent mission-confirmed request even
-- when Darktide creates the new local HumanPlayer with no wanted spawn point.
-- v0.28.38: adds Flak Cannon, Overdose, Voltaic Ripples and Red Harvest through
-- the Missile Launcher, Stimm Supply, personal force field and Chordclaw paths.
-- v0.28.39: reduces only Red Harvest's sticky single-stab bonus from 20% to
-- 10% maximum health. The non-sticky triple stab remains at 12% per hit.
-- v0.28.40: completes the Red Harvest retune by reducing each non-sticky
-- triple-combo stab from 12% to 8% maximum health.
-- v0.28.41: adds the Veteran and Zealot Blitz Legendary batch.
-- v0.28.42: completes the planned Blitz Legendary catalogue with Bigger Boom
-- Doctrine, Chain of Custody, Lights Out Forever and Tesla Doctrine.
-- v0.28.43: renames the two grenade Legendaries to Red Hail and The Big One
-- while retaining their save-compatible internal identifiers.
-- v0.28.44: gives the Ogryn Frag Legendary its final community-facing title,
-- Rubert Ogrynheimer, without changing its internal identifier or behavior.
-- v0.28.45: redesigns the six original Doctrines and adds Second Reading,
-- Munitorum Dispensation, Overkill Dividend, Shared Dosage, Pilgrim's Wager
-- and Unbroken Record.
-- v0.28.46: corrects Overdose's Stimm Supply relevance gate to use the
-- combat-ability group consumed by both Pilgrimage and Fatshark's catalogue.
-- v0.28.47: replaces Flak Cannon's radius boost with native cover bypass and
-- makes Duty Unto Death retain carried objectives through ordinary damage.
-- v0.28.48: fills the remaining first-choice combat-ability gaps with No
-- Witnesses for Infiltrate, Warp Resonance for Venting Shriek, and End of the
-- Line for Bull Rush. Each extends the ability's native lifetime events.
-- v0.28.49: adds seven Afflictor family boons across Bleed, Toxin,
-- Brittleness and Exposed, moves push-Taunt into Bulwark, and adds six Tier 2
-- capture targets for the Sicarian, Arbites and Ogryn roster expansion.
-- v0.28.50: begins the Penance audit. Final-run observers now retain the
-- pre-clear curse snapshot, Machine Spirit Banishment accurately names both
-- qualifying Skitarii tools, and the diagnostic report exposes reward wiring.
-- v0.28.51: Dancing on the Web's time sample now requires the exact loaded
-- Pilgrimage assignment, excluding Psykhanium and unrelated mission time.
-- v0.28.52: wires Living Tithe ownership, the slots 1-4 Penance curve,
-- Coffers income, mission-count Devotion, draft rejection and exact servo-skull
-- completion tracking.
-- v0.28.55: bundles Rho-32's complete Recon Marksman capture and gives his
-- single-shot ACD build Reinforced Focus Litanies.
-- v0.28.56: bundles every intentionally captured companion, formalizes the
-- weak and silent Tier 1 rules, and sources uncaptured base-class recruits
-- from Better Bots' stock profiles without changing Better Bots itself.
-- v0.28.57: gives companions presentation-safe personal subtitle names,
-- removes the HUD-only [BOT] suffix, replaces mechanical class labels with
-- per-preset public families, and supports exceptional bots owning multiple
-- fixed Legendaries. Refreshes Lady Steel, Your Host and Jocasta captures.
-- v0.28.58: completes fixed Legendary coverage for every captured Tier 2 and
-- Tier 3 companion, promotes Epione Spes to Tier 3, and implements the eight
-- approved signature packages for Dorian, Severin, Canis-Alpha, Magleviathan,
-- Lady Steel, Your Host, Epione and Jocasta.
-- v0.28.59: adds role designations to the Party overview, removes the bot tag
-- through BotPlayer's local presentation name, and consumes the terminal return
-- request on the hub spawner's first query instead of a later game-state tick.
-- v0.28.60: adds the opt-in Kasrkin hotshot vertical slice: a 1.2-second
-- precision shot, roughly 1,800 raw damage on the captured roll, strong
-- Carapace and finesse scaling, long falloff, and an 8-round captured magazine.
-- v0.28.61: replaces the one-off hotshot switch with a master custom weapon
-- balance gate and an exact Meat Grinder-only testing extension.
-- v0.28.62: keeps ADS responsive after firing and adds the hotshot's field-test
-- drawbacks: four rounds, -15% movement while wielded, and one effective dodge.
-- v0.28.63: adds the first focused weapon batch: two-shot +35% Kickback with
-- 1.6-second reload, numerical Heavy Sword rescue, modest Shredder cleave,
-- and a three-second cooldown on the affected Ogryn Power Maul mark.
-- v0.28.65: transforms the explosive Plasma Gun Mk II into an opt-in
-- handheld Plasma Cannon while preserving the established Mk I.
-- v0.28.68: adds the Vindicator flamer transformation and an optional,
-- non-persistent EWC visual-default bridge for the three transformed marks.
-- v0.28.69: adds safe per-preset and all-preset commands that remove personal
-- bot captures and reveal the bundled defaults without touching progression.
-- v0.28.70: integrates Pilgrimage-owned Hide Weapon, Karnak sword and Traitor
-- Plasma skins through standard EWC, keeps Syn's Edits external, and adds
-- chainsword audio to the Vindicator shove.
-- v0.28.71: restores the four genuinely selected More Dakka capture parts as
-- optional, piece-by-piece enhancements while leaving the addon unbundled.
-- First-person NPC-source visibility moved to First Person Body, which owns
-- the general rendering concern.
-- v0.28.72: enables custom weapon balancing and its appearance layer by
-- default. The appearance and Meat Grinder switches now sit beneath the
-- balance master, while the existing runtime gate keeps looks impossible
-- whenever balancing itself is disabled. The Hotshot's body-shot damage is
-- reduced and its finesse raised, preserving a built Crusher-headshot payoff
-- without deleting Reapers or Bulwarks through ordinary body hits.
-- v0.28.73: adds complete Simplified Chinese coverage for the mod-options and
-- preset-capture localization catalogue, with a regression guard for future
-- untranslated entries.
-- v0.28.74: experimental Realms shell. Adds exact internal-version admission,
-- host-authoritative session overrides for weapon balance and cheat settings,
-- a three-guest Realm terminal tab, and human-seat suppression of matching bot
-- slots without erasing their saved presets.
-- v0.28.75: fixes the first Realms launch deadlock, admits first-leg guests in
-- Realms' preparation screen, and retains the Realm through later mission legs.
-- v0.28.76: field-rejected circular wait for the old hub game session to vanish.
-- v0.28.77: waits only for the installed Realms host, then lets Realms defer the
-- mechanism change while the old hub gameplay session exits.
-- v0.28.78: restores the field-proven early lobby transition, then re-arms the
-- mission after Realms installs its host so Ready can release a clean transition.
-- v0.28.79: transforms the Godwyn-Branx Mk VI Bolt Pistol into a compact
-- Plasma Pistol with owned damage, blast, presentation and nonlethal heat.
-- Six rapid shots stay below the cap; the seventh fires, overheats and starts
-- a 2.5-second automatic vent without a self-damaging explosion.
-- v0.28.80: retunes the field-tested Plasma Pistol's damage, cooling delay and
-- lockout. Recasts the former Hotshot as the ballistic Vraks Headhunter,
-- removes las-only talent compatibility, slows its cadence, and reduces its
-- ordinary and Unyielding damage without changing the four-round handling.
-- v0.28.81: adds the first Hunter Stubber pass for the Ogryn's precise Achlys Mk II,
-- improving aimed cadence, direct damage, impact and armour performance while
-- retaining the mark's existing ammunition economy and penetrating shot.
-- v0.28.82: gives every Ripper mark stronger damage, cleave and distinct armour
-- conversion, accelerates Ripper and selected Stubber reloads, expands their
-- reserves, and increases both Spearhead Boltgun marks' reserve ammunition.
-- v0.28.83: the Grenadier Gauntlet's successful special explosion consumes
-- every loaded shell and gains 50% damage per additional shell consumed.
-- v0.28.84: tempers the Ogryn Hunter Stubber and turns the Gauntlet's close
-- internal blast into a universal high-damage finisher while preserving its outer blast.
-- v0.28.85: replaces the unsupported Mod Options title ornament with the font-safe
-- star already rendered elsewhere on that screen.
-- v0.28.86: separates the Thunder Hammers into an execution mark and a
-- line-breaker mark. The line-breaker now powers multiple sweeps during a
-- timed six-second mode, followed by an eight-second recharge.
-- v0.28.87: compares that economy against the Relic Blade and gives the
-- line-breaker eight powered seconds followed by six seconds of recharge.
-- v0.28.88: restores the complete weapon-rebalance module after its new
-- timed-special helper was mistakenly addressed through the game's require
-- path instead of Pilgrimage's DMF mod-file loader.
-- v0.28.89: gives the Ironhelm timed mode a Relic-Blade-style meter which
-- fills during its powered window and drains during cooldown.
-- v0.28.90: converts both original Power Swords and every revved chain weapon
-- to timed modes, keeps folding shovels transformed until manually toggled,
-- and guarantees latched chain stagger against every non-monstrosity.
-- v0.28.91: retunes revved chain weapons to eight seconds active and 4.5
-- seconds cooling, with powered expiry deferred until a live latch releases.
-- v0.28.93: isolates new powered-mode validation failures so one unsupported
-- weapon cannot disable the established rebalance, and records exact failures.
-- v0.28.94: recognizes Heavy Eviscerator activation by behavior, restores
-- atomic powered-mode validation, gives timed modes a progress-driven HUD bar,
-- and restores the folding shovel's active idle pose after every attack.
-- v0.28.95: restores the original powered-mode bar and derives its ready state
-- from special timestamps instead of the HUD's stale discrete-charge view.
mod.version = "0.28.146"

-- v0.26.4: keep Pilgrimage out of the chat window at the mod-object level.
-- Shared.notify bypasses these methods and continues to produce the intended
-- notification-feed popups. Genuine warnings and errors still reach the game
-- log through Fatshark's Log API, but DMF can no longer mirror them into chat.
local function _log_without_chat(level, message, ...)
	local Log = rawget(_G, "Log")
	local writer = Log and Log[level]
	if type(writer) ~= "function" then return end
	local ok, formatted = pcall(string.format, tostring(message), ...)
	pcall(writer, "Pilgrimage", "%s", ok and formatted or tostring(message))
end

mod.echo = function() end
mod.echo_localized = function() end
mod.notify = function() end
mod.warning = function(_, message, ...)
	_log_without_chat("warning", message, ...)
end
mod.error = function(_, message, ...)
	_log_without_chat("error", message, ...)
end
mod.info = function() end
mod.debug = function() end

-- ---------------------------------------------------------------------------
-- Pre-bootstrap modules
--
-- Hooks must be installed before anything registers a hook. LogLevels and Shared
-- are needed by the logger below, which bootstrap itself wants.
-- ---------------------------------------------------------------------------

local Hooks     = mod:io_dofile(ROOT .. "hooks")
Hooks.install(mod)

local LogLevels = mod:io_dofile(ROOT .. "log_levels")
local Shared    = mod:io_dofile(ROOT .. "shared")

-- ---------------------------------------------------------------------------
-- Debug logging
--
-- One function, injected into every module. Two things make it safe to call from
-- per-frame code:
--
--   * the level check happens FIRST, so when logging is off the caller pays for one
--     table lookup and a comparison, and the message string is never built. That is
--     why callers should pass an already-built string only when they have to, and
--     why every call site in hot code sits behind `if debug_enabled() then`.
--
--   * `key` is a throttle bucket. Two calls with the same key inside min_interval_s
--     collapse into one. Compose the key so it is semantically unique, usually
--     "<what>:<subject>", so two different subjects do not throttle each other.
--
-- _log_level is cached in an upvalue and refreshed on setting change and mission
-- start. It is never re-read per call.
-- ---------------------------------------------------------------------------

local DEBUG_LOG_INTERVAL_S = 2
local _log_level = 0
local _last_log_t_by_key = {}

local function _debug_enabled()
	return _log_level > 0
end

local function _debug_log(key, t, message, min_interval_s, level)
	if not LogLevels.should_log(_log_level, level) then return end

	t = t or 0
	local interval = min_interval_s or DEBUG_LOG_INTERVAL_S
	local last = _last_log_t_by_key[key]
	if last and t - last < interval then return end
	_last_log_t_by_key[key] = t

	-- mod:echo treats the argument as a format string, so % has to be escaped.
	mod:echo("Pilgrimage: " .. tostring(message):gsub("%%", "%%%%"))
end

local function _refresh_log_level()
	local Settings = mod._modules and mod._modules.Settings
	if Settings then
		_log_level = Settings.log_level()
	else
		_log_level = LogLevels.resolve_setting(mod:get("log_level"))
	end
end

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------

-- Loaded here as well as inside route_view.lua. mod:io_dofile does not cache, so these
-- are two separate copies of the same pure-data table. That is wasteful but harmless,
-- and it is the price of the view file being constructed by the game rather than by us.
local RouteViewDefinitions = mod:io_dofile(ROOT .. "route_view_definitions")

local Bootstrap = mod:io_dofile(ROOT .. "bootstrap")

local modules = Bootstrap.load_and_init({
	mod           = mod,
	hooks         = Hooks,
	log_levels    = LogLevels,
	shared        = Shared,
	debug_log     = _debug_log,
	debug_enabled = _debug_enabled,
	fixed_time    = Shared.fixed_time,
})

-- Exposed so other mods, and our own commands, can reach modules for inspection.
-- Nothing inside the mod should read this; modules get their deps injected.
mod._modules = modules

local Settings = modules.Settings
local RealmsBridge = modules.RealmsBridge
local Perf     = modules.Perf
local EventLog = modules.EventLog
local Tick     = modules.Tick
local RunState = modules.RunState
local Weapons  = modules.Weapons
local WeaponCounterTimedMode = modules.WeaponCounterTimedMode
local WeaponRebalance = modules.WeaponRebalance
local EWCOwnedContent = modules.EWCOwnedContent
local WeaponVisuals = modules.WeaponVisuals
local Missions = modules.Missions
local Escape   = modules.Escape
local Chain    = modules.Chain
local HitProbe = modules.HitProbe
local Boons    = modules.Boons
local DoctrineRuntime = modules.DoctrineRuntime
local Terminal = modules.Terminal
local Curses   = modules.Curses
local Debug    = modules.Debug
local FileIO   = modules.FileIO
local BetterBotsBridge = modules.BetterBotsBridge
local MutatorGuard = modules.MutatorGuard
local Preset   = modules.Preset
local Voices   = modules.Voices

_refresh_log_level()
Debug.register_commands()

-- ---------------------------------------------------------------------------
-- Boot log
--
-- Appended on every load and every /reload, before anything else can go wrong.
-- This is the answer to "did the mod even load", and it needs no command, no
-- setting, and no working chat. If mods/Pilgrimage/boot.log has no line for the
-- current time, the mod did not run at all.
-- ---------------------------------------------------------------------------

FileIO.append("boot.log", string.format(
	"%s  loaded v%s  |  game_mode=%s  solo=%s  modules=%d  io=%s\n",
	FileIO.timestamp(),
	tostring(mod.version),
	tostring(Shared.game_mode_name()),
	tostring(Shared.is_solo_host()),
	(function() local n = 0 for _ in pairs(modules) do n = n + 1 end return n end)(),
	tostring(FileIO.available())))

-- ---------------------------------------------------------------------------
-- Engine hooks
--
-- All hooks live here, in one place. When two future modules both want the same
-- engine path, they do NOT each register a hook_require: DMF would silently discard
-- the second one. Instead they hand a handler to Hooks.fanout below, and the entry
-- file owns the single registration.
--
-- The shape, for when more than one module wants the same path:
--
--   Hooks.fanout("scripts/settings/buff/buff_templates", {
--       { "boons", function(templates) modules.Boons.inject(templates) end },
--       { "curses", function(templates) modules.Curses.inject(templates) end },
--   })
-- ---------------------------------------------------------------------------

-- v0.26.1: Skirmisher's reload clause. The movement stat on the
-- Archetype removes reload slowdown, but ActionAvailability separately
-- rejects reload actions during sprint. Open only the three reload kinds
-- the current weapon-action movement code recognizes, and only while the
-- run-stamped Skirmisher buff is actually present on this player.
do
	local ok_availability, ActionAvailability = pcall(require,
		"scripts/extension_systems/weapon/utilities/action_availability")
	if ok_availability and ActionAvailability
		and type(ActionAvailability.available_in_sprint) == "function" then
		local SKIRMISHER_RELOAD_KINDS = {
			reload_shotgun = true,
			reload_state = true,
			ranged_load_special = true,
		}
		mod:hook(ActionAvailability, "available_in_sprint",
			function(func, action_settings, buff_extension)
				local available, allowed_by_buff = func(action_settings, buff_extension)
				if available then return available, allowed_by_buff end
				local kind = action_settings and action_settings.kind
				if not SKIRMISHER_RELOAD_KINDS[kind] or not buff_extension
					or type(buff_extension.has_buff_using_buff_template) ~= "function" then
					return available, allowed_by_buff
				end
				local ok_has, has = pcall(buff_extension.has_buff_using_buff_template,
					buff_extension, "pilgrim_arch_skirmisher")
				if ok_has and has then return true, true end
				return available, allowed_by_buff
			end)
	end
end

-- Capture the weapon template table the moment the game loads it. Using
-- hook_require_now rather than a plain require means we get it whether or not the
-- game has already loaded it by the time we run, and we never force an early load.
Hooks.fanout(Weapons.WEAPON_TEMPLATES_PATH, {
	{ "weapons", function(templates) Weapons.receive_templates(templates) end },
	{ "weapon_rebalance", function(templates)
		WeaponRebalance.receive_weapon_templates(templates)
	end },
})

Hooks.fanout(WeaponRebalance.AMMO_TEMPLATES_PATH, {
	{ "weapon_rebalance_ammo", function(templates)
		WeaponRebalance.receive_ammo_templates(templates)
	end },
})

Hooks.fanout(WeaponRebalance.DODGE_TEMPLATES_PATH, {
	{ "weapon_rebalance_dodge", function(templates)
		WeaponRebalance.receive_dodge_templates(templates)
	end },
})

-- Chain weapons mark only their powered latch damage profiles. This narrow
-- result hook turns those contacts into the game's sticky stagger for every
-- non-monstrosity while preserving all native monster reactions.
Hooks.fanout(WeaponRebalance.STAGGER_CALCULATION_PATH, {
	{ "weapon_rebalance_chain_stagger", function(StaggerCalculation)
		WeaponRebalance.install_stagger_calculation(StaggerCalculation)
	end },
})

-- The Meat Grinder launch button exposes its destination before StateLoading.
-- Arming here is early enough to change the ammo template before the player's
-- weapon instance copies it, while the exact tg_shooting_range check prevents
-- custom balance from leaking into tutorials or ordinary missions.
Hooks.fanout(WeaponRebalance.TRAINING_GROUNDS_VIEW_PATH, {
	{ "weapon_rebalance_meat_grinder", function(TrainingGroundsOptionsView)
		WeaponRebalance.install_training_grounds_view(TrainingGroundsOptionsView)
	end },
})

-- The Ironhelm uses a private counter type because the charge remains the
-- gameplay authority while the HUD needs a continuous two-phase timer. The
-- custom template reuses the Relic Blade material without giving the hammer a
-- fake overheat system.
Hooks.fanout("scripts/extension_systems/weapon/special_classes/weapon_special_self_disorientation", {
	{ "weapon_rebalance_legacy_ironhelm", function(NativeSpecial)
		modules.WeaponSpecialTimedCooldown.install_legacy_ironhelm(
			NativeSpecial, mod, WeaponRebalance.owned_ironhelm_tweak)
	end },
})

Hooks.fanout(WeaponCounterTimedMode.HUD_ELEMENT_PATH, {
	{ "weapon_counter_timed_mode", function(HudElementWeaponCounter)
		WeaponCounterTimedMode.install(HudElementWeaponCounter)
	end },
})

Hooks.fanout(Missions.MISSION_TEMPLATES_PATH, {
	{ "missions", function(templates) Missions.receive_templates(templates) end },
})

Hooks.fanout(Missions.DANGER_SETTINGS_PATH, {
	{ "missions_danger", function(settings) Missions.receive_dangers(settings) end },
})

Hooks.fanout(Missions.CIRCUMSTANCE_TEMPLATES_PATH, {
	{ "missions_circumstance", function(templates) Missions.receive_circumstances(templates) end },
	{ "curses", function(templates) Curses.receive_templates(templates) end },
})

-- Restores the "Leave Mission" button in a solo-launched mission. Without this there
-- is no way out of a Pilgrimage mission through the escape menu at all: the vanilla
-- entry is gated on host_type == mission_server and we are singleplay.
Hooks.fanout(Escape.CONTENT_LIST_PATH, {
	{ "escape", function(content_list) Escape.install(content_list) end },
})

-- Observes mission end so a run can advance. hook_safe only, so we can never stop
-- the game deciding a mission is over.
-- Two modules want GameModeManager, and this is exactly the case Hooks.fanout exists for.
-- Registering hook_require twice for one path does NOT give you two callbacks: DMF keys
-- them by (path, mod_name) and silently discards the second, so the module that happened
-- to register later would simply never run. One registration, two handlers.
Hooks.fanout(Chain.GAME_MODE_MANAGER_PATH, {
	{ "chain", function(GameModeManager) Chain.install(GameModeManager) end },
	{ "boons", function(GameModeManager) Boons.install(GameModeManager) end },
})

-- Diagnostic for the bots-trigger-your-hit-markers bug. Installed always, but the
-- hook early-outs on a disabled flag, so it costs one comparison per attack until
-- /pil_hits turns recording on.
Hooks.fanout(HitProbe.ATTACK_REPORT_PATH, {
	{ "hitprobe", function(AttackReportManager) HitProbe.install(AttackReportManager) end },
})

-- v0.27.0 custom Legendary seams. Gameplay logic remains in boons.lua;
-- this entry file only guarantees one hook owner per engine module.
Hooks.fanout("scripts/extension_systems/ability/player_unit_ability_extension", {
	{ "boons_omnissian_ability", function(PlayerUnitAbilityExtension)
		Boons.install_omnissian_ability_extension(PlayerUnitAbilityExtension)
	end },
})

Hooks.fanout("scripts/settings/buff/archetype_buff_templates/cryptic_buff_templates", {
	{ "boons_omnissian_templates", function(templates)
		Boons.install_omnissian_templates(templates)
	end },
})

Hooks.fanout("scripts/settings/buff/archetype_buff_templates/adamant_buff_templates", {
	{ "boons_adamant_legendaries", function(templates)
		Boons.install_adamant_legendary_templates(templates)
	end },
})

Hooks.fanout(
	"scripts/extension_systems/proximity/side_relation_gameplay_logic/proximity_shock_mine",
	{
		{ "boons_voltaic_web", function(ProximityShockMine)
			Boons.install_voltaic_web_mine(ProximityShockMine)
		end },
	}
)

Hooks.fanout("scripts/utilities/attack/explosion", {
	{ "boons_legendary_explosions", function(Explosion)
		Boons.install_flak_cannon_explosion(Explosion)
	end },
})

Hooks.fanout(
	"scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension",
	{
		{ "boons_duty_unto_death_luggable", function(PlayerUnitVisualLoadoutExtension)
			Boons.install_duty_unto_death_luggable(PlayerUnitVisualLoadoutExtension)
		end },
	}
)

Hooks.fanout("scripts/extension_systems/liquid_area/liquid_area_extension", {
	{ "boons_tesla_doctrine_liquid", function(LiquidAreaExtension)
		Boons.install_tesla_liquid_area_extension(LiquidAreaExtension)
	end },
})

Hooks.fanout("scripts/extension_systems/smoke_fog/smoke_fog_extension", {
	{ "boons_toxic_fog", function(SmokeFogExtension)
		Boons.install_toxic_fog_smoke(SmokeFogExtension)
	end },
})

Hooks.fanout(
	"scripts/extension_systems/proximity/side_relation_gameplay_logic/proximity_broker_stimm_field",
	{
		{ "boons_overdose_stimm_field", function(ProximityBrokerStimmField)
			Boons.install_overdose_stimm_field(ProximityBrokerStimmField)
		end },
	}
)

Hooks.fanout(
	"scripts/extension_systems/health/cryptic_personal_force_field_unit_health_extension",
	{
		{ "boons_voltaic_ripples_force_field", function(ForceFieldHealthExtension)
			Boons.install_voltaic_ripples_force_field(ForceFieldHealthExtension)
		end },
	}
)

Hooks.fanout("scripts/extension_systems/ability/utilities/shout_ability", {
	{ "boons_legendary_shouts", function(ShoutAbility)
		Boons.install_shout_ability(ShoutAbility)
	end },
})

Hooks.fanout("scripts/settings/buff/archetype_buff_templates/psyker_buff_templates", {
	{ "boons_overwhelming_mind", function(templates)
		Boons.install_overwhelming_mind_templates(templates)
	end },
})

Hooks.fanout("scripts/settings/buff/archetype_buff_templates/veteran_buff_templates", {
	{ "boons_no_witnesses", function(templates)
		Boons.install_no_witnesses_templates(templates)
	end },
})

Hooks.fanout("scripts/extension_systems/weapon/actions/modules/psyker_smite_targeting_action_module", {
	{ "boons_unwarded_targeting", function(TargetingModule)
		Boons.install_brain_rupture_targeting(TargetingModule)
	end },
})

Hooks.fanout("scripts/utilities/attack/attack", {
	{ "boons_legendary_attack", function(Attack)
		Boons.install_legendary_attack(Attack)
	end },
	{ "doctrine_attack", function(Attack)
		DoctrineRuntime.install_attack(Attack)
	end },
})

Hooks.fanout("scripts/extension_systems/weapon/actions/action_zealot_channel", {
	{ "boons_chorus_everlasting", function(ActionZealotChannel)
		Boons.install_zealot_channel(ActionZealotChannel)
	end },
})

Hooks.fanout(
	"scripts/extension_systems/health/psyker_force_field_unit_health_extension",
	{
		{ "boons_fly_trap_health", function(PsykerForceFieldUnitHealthExtension)
			Boons.install_fly_trap_health(PsykerForceFieldUnitHealthExtension)
		end },
	}
)

-- Grudge Engine responds only after Darktide has accepted a genuine stagger
-- and entered its native stunned state. The boon module then applies the
-- five-second retaliation effect and its ten-second cooldown marker.
Hooks.fanout(
	"scripts/extension_systems/character_state_machine/character_states/player_character_state_stunned",
	{
		{ "boons_grudge_engine", function(PlayerCharacterStateStunned)
			if not PlayerCharacterStateStunned
				or PlayerCharacterStateStunned.__pilgrimage_grudge_hooked then return end
			PlayerCharacterStateStunned.__pilgrimage_grudge_hooked = true
			mod:hook_safe(PlayerCharacterStateStunned, "on_enter", function(self, unit)
				pcall(Boons.trigger_grudge_engine, unit)
			end)
		end },
	}
)

Hooks.fanout("scripts/utilities/attack/damage_calculation", {
	{ "boons_family_damage_calculation", function(DamageCalculation)
		Boons.install_family_damage_calculation(DamageCalculation)
	end },
	{ "doctrine_damage_calculation", function(DamageCalculation)
		DoctrineRuntime.install_damage_calculation(DamageCalculation)
	end },
})

Hooks.fanout("scripts/utilities/attack/damage_taken_calculation", {
	{ "double_barrel_execute", function(Calculation)
		WeaponRebalance.install_double_barrel_hit_result(Calculation)
	end },
})

Hooks.fanout("scripts/ui/hud/elements/crosshair/templates/crosshair_template_shotgun", {
	{ "double_barrel_crosshair", function(Template)
		WeaponRebalance.install_double_barrel_crosshair(Template)
	end },
})

Hooks.fanout("scripts/utilities/ammo", {
	{ "doctrine_ammo", function(Ammo)
		DoctrineRuntime.install_ammo(Ammo)
	end },
})

Hooks.fanout("scripts/extension_systems/interaction/interactions/ammunition_interaction", {
	{ "doctrine_ammo_crate", function(AmmunitionInteraction)
		DoctrineRuntime.install_ammunition_interaction(AmmunitionInteraction)
	end },
})

Hooks.fanout("scripts/settings/buff/syringe_buff_templates", {
	{ "doctrine_shared_dosage", function(templates)
		DoctrineRuntime.install_syringe_templates(templates)
	end },
})

Hooks.fanout("scripts/extension_systems/projectile_damage/projectile_damage_extension", {
	{ "rumbler_remote_fuse", function(ProjectileDamageExtension)
		modules.WeaponRumbler.install_projectiles(ProjectileDamageExtension)
	end },
	{ "boons_special_delivery", function(ProjectileDamageExtension)
		Boons.install_special_delivery_projectiles(ProjectileDamageExtension)
	end },
})

-- The curse guard: verifies (and when the engine lost it, restores) the launched
-- circumstance at the two places the mission consumes it, and records the ground
-- truth of which mutators actually loaded. A level load wipes the Lua VM on both
-- sides, so the stacked circumstance registered in the hub does not exist in the
-- mission's fresh template table without this; see mutator_guard.lua for the
-- full story.
Hooks.fanout("scripts/managers/mutator/mutator_manager", {
	{ "mutator_guard", function(MutatorManager)
		modules.MutatorGuard.install_mutator_manager(MutatorManager)
	end },
})

-- v0.21.0: bot slot count override. TrueSoloQoL uses the same hook to
-- disable bots; we use it to expand the slot count based on Pilgrimage's
-- own progression. Solo-host guard lives inside install() so the hook is
-- registered even in coop but no-ops when a real host is present.
Hooks.fanout(modules.Bots.SPAWN_MANAGER_PATH, {
	{ "bots", function(PlayerUnitSpawnManager) modules.Bots.install(PlayerUnitSpawnManager) end },
})

-- v0.21.5: widen the party HUD to seat 1 local + 6 bots. This hooks the
-- settings TABLE (not the handler class), so it runs before the handler
-- reads max_panels and before the definitions file's scenegraph loop
-- generates the per-player positions.
Hooks.fanout(modules.Bots.TEAM_PANEL_SETTINGS_PATH, {
	{ "bots_hud", function(settings) modules.Bots.install_hud_widen(settings) end },
})

-- v0.22.0: bot preset spawn hook. Registered AFTER Better Bots' own
-- add_bot hook so we wrap it: our pre-hook mutates the profile
-- (setting character_id + name, which triggers BB's escape hatch),
-- then BB sees the "already-real character" and passes through.
Hooks.fanout(modules.Preset.SYNCHRONIZER_HOST_PATH, {
	{ "preset", function(BotSynchronizerHost) modules.Preset.install(BotSynchronizerHost) end },
})

Hooks.fanout("scripts/managers/circumstance/circumstance_manager", {
	{ "mutator_guard_circumstance", function(CircumstanceManager)
		modules.MutatorGuard.install_circumstance_manager(CircumstanceManager)
	end },
})

-- The fx guard: boon (hordes) buff effects reference particles that ship only
-- with the Mortis Trials level packages, and spawning a particle the mission
-- never loaded is a hard engine error (the 2026-08-05 mid-mission crash).
-- These hooks skip provably-unloadable particles at every spawn choke point
-- the hordes buffs use; the World.create_particles deep net installs in
-- bootstrap because World is a global, not a require path.
Hooks.fanout("scripts/extension_systems/fx/fx_system", {
	{ "fx_guard_system", function(FxSystem)
		modules.FxGuard.install_fx_system(FxSystem)
	end },
})

-- v0.22.59 (2026-08-09): REVERT v0.22.58 UIProfileSpawner.spawn_profile
-- hook.
--
-- The v0.22.58 fanout registered a global hook on
-- UIProfileSpawner:spawn_profile so it could feed NPC-Look-decorated
-- profiles to the bot cutscene. In practice the spawner is used in
-- many more places than just the intro cinematic (Character Select,
-- Barber, terminal preview, hub NPCs, portrait strips), and even the
-- fast-path bail (profile._pilgrimage_preset check) still executed
-- inside a mod:hook wrapper on every spawn call. Field report:
--
--   1. Mourningstar terminal became inaccessible. Console spam of
--      scripts/foundation/managers/package/package_manager.lua:250
--      "attempt to index local 'load_call_item' (a nil value)" every
--      frame, blocking the terminal view.
--   2. Bots' *in-mission* looks regressed to the loading-screen
--      partial state, i.e. worse than the v0.22.57 baseline.
--   3. Portrait icons still not fixed.
--
-- Rolling this hook back restores the pre-v0.22.58 behaviour: the
-- terminal works, in-mission bots look the way they did in v0.22.57,
-- and we're back to the known set of unresolved cosmetic gaps we had
-- before this attempt (intro cutscene partial, portrait icons
-- vanilla). A different entry point (likely mutating the profile at
-- CutsceneCharacterExtension.assign_player_loadout time, restoring
-- afterwards) will be tried in a follow-up version once we've
-- confirmed this revert stops the bleeding.

-- v0.22.60 (2026-08-09): diagnostic-only observability for the intro
-- cinematic bot path. NO behaviour change.
--
-- v0.22.61 (2026-08-09): output routed through mod:echo directly
-- instead of _debug_log so the probe still emits when Kaizen's Log
-- level is Off (the default). Per-uid throttle keeps it to one line
-- per bot per session, so a party of four bots produces four lines
-- total, not a per-frame stream.
--
-- Why: v0.22.58's fix was aimed at the wrong layer. preset.lua ALREADY
-- registers a spawn_profile hook on UIProfileSpawner that decorates
-- Pilgrimage bot profiles via npclook_profile_with_look (see
-- preset.lua _pilgrimage_decorate_bot_profile_for_ui at ~L1591 and
-- the _hook_now install at ~L1702). NPCLook itself hooks
-- UIProfileSpawner:spawn_profile / update / spawned to run its
-- extras-slot runtime that spawns the alt-head + extra armour units
-- Kaizen sees missing on Pasqal and Abelard. So the base decoration
-- path is in place; something in the extras-sync chain is bailing for
-- the cutscene spawner instance and only for it.
--
-- Rather than shoot another blind fix, this hook wraps
-- CutsceneCharacterExtension.assign_player_loadout as a pure
-- observer: it passes every arg through to the original untouched,
-- then, once, records what the game handed the spawner and whether
-- the profile the spawner is now holding carries the expected
-- decoration markers (npclook_extra_slots count, still-present
-- _pilgrimage_preset sentinel). One line per cutscene bot spawn,
-- gated on log level info+ so a normal Off/Info user sees nothing
-- extra. To capture: set Pilgrimage -> Log level to Info (or higher)
-- in the Mods menu, start a mission that runs an intro cinematic
-- with a Pilgrimage bot in the party, then share the log lines
-- tagged [pil][cutscene_probe] with me.
Hooks.fanout(
	"scripts/extension_systems/cutscene_character/cutscene_character_extension",
	{
		{ "cutscene_probe", function(CutsceneCharacterExtension)
			if not CutsceneCharacterExtension then return end
			if rawget(CutsceneCharacterExtension, "__pilgrimage_cutscene_probe_hooked") then
				return
			end
			CutsceneCharacterExtension.__pilgrimage_cutscene_probe_hooked = true

			-- Per-uid + per-scene throttle. Cutscene bot spawns are
			-- rare (once per intro cinematic per party member), so a
			-- session budget of ~1 line per (uid, scene) is enough to
			-- diagnose without flooding chat.
			local _probe_seen = {}

			mod:hook(CutsceneCharacterExtension, "assign_player_loadout",
				function(func, self, player_unique_id, items, cutscene_companion_extension)
					-- Look up what the game will pass to spawn_profile.
					local preset_id, has_stored, before_extras
					local get_mod = rawget(_G, "get_mod")
					local pcall_ok = pcall(function()
						local player = Managers and Managers.player
							and Managers.player:player_from_unique_id(player_unique_id)
						local profile = player and player:profile()
						if type(profile) ~= "table" then return end
						preset_id = profile._pilgrimage_preset
						local extras = profile.npclook_extra_slots
						before_extras = type(extras) == "table" and #extras or -1
						if type(preset_id) == "string" and preset_id ~= "" then
							local pil = get_mod and get_mod("Pilgrimage")
							local Preset = pil and pil._modules and pil._modules.Preset
							if Preset and type(Preset.has_stored_look_state) == "function" then
								has_stored = Preset.has_stored_look_state(preset_id)
							end
						end
					end)

					-- Call the vanilla implementation unchanged.
					local ret = func(self, player_unique_id, items, cutscene_companion_extension)

					-- After the spawner has stored its loading_profile_data,
					-- probe what actually landed there. Wrapped in pcall so a
					-- weird spawner shape never crashes the game path.
					pcall(function()
						local ps = self and self._profile_spawner
						local lpd = ps and ps._loading_profile_data
						local stored_profile = lpd and lpd.profile
						local stored_preset = type(stored_profile) == "table"
							and stored_profile._pilgrimage_preset
						local stored_extras = type(stored_profile) == "table"
							and stored_profile.npclook_extra_slots
						local after_extras = type(stored_extras) == "table"
							and #stored_extras or -1
						local ref_name = ps and ps._reference_name or "?"
						local scene = self._cinematic_name or "?"

						local probe_key = tostring(player_unique_id) .. "|" .. tostring(scene)
						if _probe_seen[probe_key] then return end
						_probe_seen[probe_key] = true

						mod:echo(string.format(
							"Pilgrimage: [cutscene_probe] uid=%s preset=%s " ..
							"stored_look=%s pre_extras=%d post_extras=%d " ..
							"post_preset=%s scene=%s ref=%s pcall=%s",
							tostring(player_unique_id),
							tostring(preset_id),
							tostring(has_stored),
							before_extras or -2,
							after_extras or -2,
							tostring(stored_preset),
							tostring(scene),
							tostring(ref_name),
							tostring(pcall_ok)))
					end)

					return ret
				end)
		end },
	}
)

-- v0.22.52 (2026-08-09): custom bot title hook. Bot presets can carry a
-- `custom_title` field (string, for now; future shape: { text, color,
-- rarity }); when set, apply_source_to_profile writes
-- profile._pilgrimage_custom_title on the bot's profile. Here we hook
-- both public reader functions the game uses to display a character
-- title and swap only the TEXT when that marker is present. The rarity
-- + colour formatting the game applies (from
-- profile.loadout.slot_character_title.rarity via RaritySettings) stays
-- untouched, so a bot's title renders in the source character's
-- original colour palette.
--
-- Both hook targets are ProfileUtils functions; ProfileUtils is a local
-- table inside scripts/utilities/profile_utils.lua that's returned from
-- the module. Hooks.fanout on the module path gives us the table
-- reference the moment the file loads.
Hooks.fanout(
	"scripts/utilities/profile_utils",
	{
		{ "custom_title", function(ProfileUtils)
			if not ProfileUtils then return end
			if rawget(ProfileUtils, "__pilgrimage_custom_title_hooked") then return end
			ProfileUtils.__pilgrimage_custom_title_hooked = true

			-- v0.22.56: two marker shapes now:
			--   string           -> "keep source's colour" (splice into
			--                       any existing {#color(...)} markup
			--                       the game returned; wholesale swap if
			--                       no markup present)
			--   { text, color }  -> "force this colour" (always emit
			--                       "{#color(r,g,b)}text{#reset()}"
			--                       regardless of what the game returned)
			--
			-- Kaizen field test proved the "keep source's colour" path
			-- yields plain white for at least one title item (Blessed
			-- Sororitas source didn't carry rarity markup in the return
			-- value), so the table form was promoted from "future
			-- extension" to shipping.
			local function _extract_text_from(marker)
				if type(marker) == "string" then return marker end
				if type(marker) == "table" then return marker.text end
				return nil
			end

			local function _wrap_with_custom(original_return, marker)
				local custom_text = _extract_text_from(marker)
				if not custom_text or custom_text == "" then return original_return end

				-- Explicit colour wins outright.
				if type(marker) == "table" and type(marker.color) == "table" then
					local c = marker.color
					return string.format(
						"{#color(%d,%d,%d)}%s{#reset()}",
						math.floor(c[1] or 255), math.floor(c[2] or 255), math.floor(c[3] or 255),
						custom_text)
				end

				-- Otherwise splice into whatever markup the game returned.
				if type(original_return) ~= "string" then return custom_text end
				local prefix_end = original_return:find("}", 1, true)
				local reset_start = original_return:find("{#reset", 1, true)
				if prefix_end and reset_start and prefix_end < reset_start then
					return original_return:sub(1, prefix_end)
						.. custom_text
						.. original_return:sub(reset_start)
				end
				return custom_text
			end

			-- character_title returns the coloured text used in the HUD
			-- (with rarity markup when the user's colour mode enables it).
			mod:hook(ProfileUtils, "character_title", function(func, profile, ...)
				local original = func(profile, ...)
				if type(profile) ~= "table" then return original end
				local custom = profile._pilgrimage_custom_title
				if not custom then return original end
				return _wrap_with_custom(original, custom)
			end)

			-- character_title_no_color returns the plain text (no colour
			-- markup) used in menus / places that draw their own colour.
			mod:hook(ProfileUtils, "character_title_no_color", function(func, profile, ...)
				local original = func(profile, ...)
				if type(profile) ~= "table" then return original end
				local custom = profile._pilgrimage_custom_title
				if not custom then return original end
				return _extract_text_from(custom) or original
			end)
		end },
	}
)

-- v0.22.49 (Session B): HP-damage penance emitter. Hooks
-- PlayerUnitHealthExtension.add_damage AFTER the game processes the hit
-- (hook_safe → post-hook). Filters for the local human (bots take damage
-- too, and their damage does NOT count toward Silver-Tongued / In Lord
-- Captain's Service). The is_ranged branch reads the attack_type argument
-- and matches attack_settings.attack_types.ranged (constant string
-- "ranged"). Damage amount is the RAW HP damage applied (already clamped
-- to the remaining HP by the engine); we don't need permanent_damage
-- separately because both penances gate on any HP loss.
Hooks.fanout(
	"scripts/extension_systems/health/player_unit_health_extension",
	{
		{ "penance_damage_emitter", function(PlayerUnitHealthExtension)
			if not PlayerUnitHealthExtension then return end
			if rawget(PlayerUnitHealthExtension, "__pilgrimage_damage_hooked") then return end
			PlayerUnitHealthExtension.__pilgrimage_damage_hooked = true
			-- v0.22.81 (Blood Debt): halve all healing the human player
			-- receives while the Blood Debt loadout boon is in force,
			-- EXCEPT the boon's own melee-kill heal (marker-guarded so
			-- it isn't taxed by its own curse). A modifying hook, not
			-- hook_safe, because the heal amount itself changes.
			mod:hook(PlayerUnitHealthExtension, "add_heal",
				function(orig, self, heal_amount, heal_type)
					local ok, taxed = pcall(function()
						local Boons = modules and modules.Boons
						if not Boons then return nil end
						if Boons._blood_debt_self_heal then return nil end
						if not Boons.custom_boon_active
							or not Boons.custom_boon_active("pilgrim_boon_blood_debt") then
							return nil
						end
						-- Only the human player's own healing is taxed;
						-- bots keep full heals.
						local unit
						if type(self.unit) == "function" then
							local ok_u, u = pcall(self.unit, self)
							if ok_u then unit = u end
						end
						unit = unit or self._unit
						if not unit then return nil end
						local spawn = Managers.state and Managers.state.player_unit_spawn
						if not spawn or type(spawn.owner) ~= "function" then return nil end
						local ok_owner, player = pcall(spawn.owner, spawn, unit)
						if not ok_owner or not player then return nil end
						local is_human = type(player.is_human_controlled) == "function"
							and pcall(player.is_human_controlled, player)
							and player:is_human_controlled()
						if not is_human then return nil end
						return (tonumber(heal_amount) or 0) * 0.5
					end)
					if ok and taxed then heal_amount = taxed end
					return orig(self, heal_amount, heal_type)
				end)

			mod:hook_safe(PlayerUnitHealthExtension, "add_damage",
				function(self, damage_amount, _permanent_damage, _hit_actor, _damage_profile, attack_type)
					pcall(function()
						if not RunState.is_active() then return end
						local amount = tonumber(damage_amount) or 0
						if amount <= 0 then return end
						-- Bot damage doesn't count. Fetch the player
						-- for this unit through the spawn manager
						-- (same lookup as the knocked_down hook).
						local unit
						if type(self.unit) == "function" then
							local ok_u, u = pcall(self.unit, self)
							if ok_u then unit = u end
						end
						unit = unit or self._unit
						if not unit then return end
						local spawn = Managers.state and Managers.state.player_unit_spawn
						if not spawn or type(spawn.owner) ~= "function" then return end
						local ok_owner, player = pcall(spawn.owner, spawn, unit)
						if not ok_owner or not player then return end
						local is_human
						if type(player.is_human_controlled) == "function" then
							is_human = pcall(player.is_human_controlled, player)
								and player:is_human_controlled()
						end
						if not is_human then return end
						local is_ranged = attack_type == "ranged"
						RunState.add_hp_damage_taken(amount, is_ranged)
					end)
				end)
		end },
	}
)

-- v0.22.49 (Session B): downed penance emitter. Hooks
-- PlayerCharacterStateKnockedDown.on_enter, which fires every time any
-- player unit (human or bot) transitions into the knocked-down state.
-- We filter for the local human via player_manager and forward to
-- RunState.mark_downed, which bumps stat_ever_downed + stat_downs. Guarded
-- on active run + human-controlled so a bot going down or a menu preview
-- can't trip it.
Hooks.fanout(
	"scripts/extension_systems/character_state_machine/character_states/player_character_state_knocked_down",
	{
		{ "penance_downed_emitter", function(PlayerCharacterStateKnockedDown)
			if not PlayerCharacterStateKnockedDown then return end
			if rawget(PlayerCharacterStateKnockedDown, "__pilgrimage_downed_hooked") then return end
			PlayerCharacterStateKnockedDown.__pilgrimage_downed_hooked = true
			mod:hook_safe(PlayerCharacterStateKnockedDown, "on_enter", function(self, unit)
				pcall(function()
					if not RunState.is_active() then return end
					-- Only humans count. Bots go down all the time and
					-- would spam the emitter into meaninglessness for
					-- penances like Unshakeable Faith.
					local spawn = Managers.state and Managers.state.player_unit_spawn
					if not spawn or type(spawn.owner) ~= "function" then return end
					local ok_owner, player = pcall(spawn.owner, spawn, unit)
					if not ok_owner or not player then return end
					local is_human
					if type(player.is_human_controlled) == "function" then
						is_human = pcall(player.is_human_controlled, player) and player:is_human_controlled()
					end
					if not is_human then return end
					RunState.mark_downed()
					if Boons and Boons.on_local_player_downed then
						Boons.on_local_player_downed(unit)
					end
				end)
			end)
		end },
	}
)

-- v0.22.77 (Session B phase 2): damage-dealt + companion-kill emitter.
-- Fatshark's Attack.execute funnels every player-attributed hit into
-- Managers.stats:record_private("hook_damage_dealt", attacking_player,
-- attack_table) and every player-attributed kill into
-- record_private("hook_kill", ...). The attack_table carries damage_dealt,
-- damage_type and attacking_unit (verified against dt-src attack.lua
-- _record_stats), which is everything Biolightning (electricity share of
-- total damage) and Warrant Served (dog kill attribution) need, in ONE
-- seam. Post-hook via hook_safe; the game's own stat handling is
-- untouched. Companion kills reach this seam because the companion
-- spawner registers the dog with player_unit_spawn ownership, so the
-- kill is attributed to the owning player with the dog as attacking_unit.
local ELECTRIC_DAMAGE_TYPES = {
	-- The electricity family for Biolightning ("Smite + kinetic staff +
	-- voltaic boons"). Names from dt-src damage_settings.damage_types.
	smite             = true,  -- Psyker Smite channel
	electrocution     = true,  -- electric boon procs, voltaic effects
	kinetic           = true,  -- Psyker kinetic/voltaic staff
	arc_chain         = true,  -- arc jumps (electric family boons)
	shock_mine        = true,
	galvanic          = true,  -- Skitarii galvanic weapons
	arc_rifle         = true,
	blunt_shock       = true,  -- shock maul family, thematically electric
	blunt_shock_active = true,
	shock_stuck       = true,
	pellet_shock      = true,
}

Hooks.fanout(
	"scripts/managers/stats/stats_manager",
	{
		{ "penance_stats_emitter", function(StatsManager)
			if not StatsManager then return end
			if rawget(StatsManager, "__pilgrimage_stats_hooked") then return end
			StatsManager.__pilgrimage_stats_hooked = true
			mod:hook_safe(StatsManager, "record_private",
				function(self, stat_name, player, attack_table)
					-- Cheapest checks first: this fires for every stat
					-- event in the game.
					if stat_name == "hook_cryptic_servo_skull_hacking_completed" then
						pcall(function()
							if not RunState.is_active() then return end
							RunState.persist_add("total_interrogators_hacked", 1)
							local Penances = modules and modules.Penances
							if Penances and Penances.observe then
								Penances.observe("interrogator_hacked", {
									total_interrogators_hacked = RunState.persist_get(
										"total_interrogators_hacked"),
								})
							end
						end)
						return
					end
					if stat_name ~= "hook_damage_dealt" and stat_name ~= "hook_kill" then return end
					pcall(function()
						if not RunState.is_active() then return end
						if type(attack_table) ~= "table" then return end
						local is_human
						if player and type(player.is_human_controlled) == "function" then
							is_human = pcall(player.is_human_controlled, player)
								and player:is_human_controlled()
						end
						if not is_human then return end

						if stat_name == "hook_damage_dealt" then
							local amount = tonumber(attack_table.damage_dealt) or 0
							if amount <= 0 then return end
							local is_electric = ELECTRIC_DAMAGE_TYPES[attack_table.damage_type] == true
							RunState.add_damage_dealt(amount, is_electric)
						else
							-- hook_kill. Two counters read this event;
							-- their conditions are mutually exclusive
							-- (a dog kill's attacking unit is the dog,
							-- an overload kill's is the player), but
							-- both are checked so neither shadows the
							-- other.

							-- 1. Warrant Served: kills where the
							-- attacking unit is the player's companion
							-- dog, not the player themselves.
							local attacking_unit = attack_table.attacking_unit
							if attacking_unit then
								local ud = ScriptUnit.has_extension
									and ScriptUnit.has_extension(attacking_unit, "unit_data_system")
								if ud and type(ud.breed) == "function" then
									local ok_breed, breed = pcall(ud.breed, ud)
									if ok_breed and type(breed) == "table"
										and breed.name == "companion_dog" then
										RunState.add_companion_kill()
										return
									end
								end
							end

							-- 2. v0.22.80, Unsanctioned Fury (Idira):
							-- elite/specialist kills by the Peril
							-- overload detonation. The overload
							-- explosion reports damage profile
							-- "plasma_overheat" with attack_type
							-- "explosion" (warp_charge_overload
							-- template, verified in dt-src). The same
							-- profile serves plasma-gun overheat
							-- blasts, so the counter only runs while
							-- the human player is a Psyker, who cannot
							-- wield plasma; that makes the profile
							-- unambiguous.
							if attack_table.attack_type ~= "explosion" then return end
							if attack_table.damage_profile_name ~= "plasma_overheat" then return end
							local state = RunState.get()
							if (state.stat_archetype or "") ~= "psyker" then return end
							local Breeds = rawget(_G, "Breeds")
							local target_breed = Breeds and attack_table.target_breed_name
								and Breeds[attack_table.target_breed_name] or nil
							local tags = type(target_breed) == "table" and target_breed.tags or nil
							if not tags or not (tags.elite or tags.special) then return end
							RunState.add_overload_elite_kill()
						end
					end)
				end)
		end },
	}
)

-- v0.22.77 (Session B phase 2): Voltaic weapon-disable emitter for
-- Machine Spirit Banishment. The game's weapon-disable mechanic is
-- MinionState.apply_weapon_malfunction(unit, t), called by the Skitarii
-- electric procs (cryptic_discharge_weapon_malfunction from the Voltaic
-- Emitter / Discharge ability, cryptic_arc_grenades_weapon_malfunction
-- from arc grenades). The function carries no attacker, so attribution
-- is by gate: only counted while the HUMAN player is playing Skitarii
-- (cryptic) in an active run, and only when the disabled minion is a
-- ranged breed (breed.ranged, matching the penance text "weapons of
-- ranged enemies"). NOTE for Kaizen: this counts the whole Skitarii
-- electric arsenal (Discharge + arc grenades), not the Discharge
-- ability alone; the seam has no way to tell them apart. Flagged in the
-- roadmap open questions.
Hooks.fanout(
	"scripts/utilities/minion_state",
	{
		{ "voltaic_disable_emitter", function(MinionState)
			if not MinionState then return end
			if rawget(MinionState, "__pilgrimage_voltaic_hooked") then return end
			MinionState.__pilgrimage_voltaic_hooked = true
			mod:hook_safe(MinionState, "apply_weapon_malfunction", function(unit, _t)
				pcall(function()
					if not RunState.is_active() then return end
					local state = RunState.get()
					if (state.stat_archetype or "") ~= "cryptic" then return end
					if not unit then return end
					local ud = ScriptUnit.has_extension
						and ScriptUnit.has_extension(unit, "unit_data_system")
					if not ud or type(ud.breed) ~= "function" then return end
					local ok_breed, breed = pcall(ud.breed, ud)
					if not ok_breed or type(breed) ~= "table" then return end
					if not breed.ranged then return end
					RunState.persist_add("total_voltaic_disables", 1)
					local Penances = modules and modules.Penances
					if Penances and Penances.observe then
						pcall(Penances.observe, "voltaic_weapon_disabled", {
							total_voltaic_disables = RunState.persist_get("total_voltaic_disables"),
						})
					end
				end)
			end)
		end },
	}
)

-- ---------------------------------------------------------------------------
-- GENERIC WEAPON LOCKDOWN SYSTEM (v0.22.87). Kaizen: "Do make a note
-- on how to make that so you are locked to one weapon only, like you
-- did with Smite... we will for sure use this system for other
-- modifiers." Unlimited Power no longer uses it (weapons are
-- equippable again as of v0.22.87), so the registry below is EMPTY,
-- the hook early-outs at the cost of one table-length check per
-- filtered input, and the whole proven mechanism stays ready.
--
-- Seam (copied from The Emperor Protects, field-proven on Kaizen's
-- install): a modifying hook on InputService._get that suppresses or
-- forces individual input actions. Two layers per lockdown:
--  1. BLOCK the weapon wield inputs (wield_1 melee, wield_2 ranged,
--     quick_wield, wield scrolls). Pocketables (wield_3/4), the
--     device (wield_5) and luggables are untouched, so medkits,
--     stims, auspex and objective carries all still work.
--  2. AUTO-SNAP: leaving the locked slot (the game auto-returns to a
--     weapon after some actions through internal paths no input block
--     can stop) forces the lockdown's snap input so the locked slot
--     comes straight back up. For warp-cost slots, gate the snap
--     below critical Peril or it can chain into an overload death.
--
-- To lock a player to one slot again, insert a config:
--   WEAPON_LOCKDOWNS[#WEAPON_LOCKDOWNS + 1] = {
--     active = function() return <boolean, cheap, pcall-safe> end,
--     locked_slot = "slot_grenade_ability", -- slot allowed to stay up
--     snap_input = "grenade_ability_pressed", -- input forced to re-raise
--     peril_gate = 0.85, -- optional; skip snap at/above this warp charge
--   }
-- Blocked inputs and weapon slots are shared across configs; a config
-- only decides when it is active and what it snaps back to. The
-- Unlimited Power shape this generalizes lived here v0.22.84-86 and
-- is preserved in git-less history via the roadmap version log.

local WEAPON_LOCKDOWNS = {}

local LOCKDOWN_BLOCKED_WIELD_INPUTS = {
	wield_1 = true,
	wield_2 = true,
	quick_wield = true,
	wield_scroll_down = true,
	wield_scroll_up = true,
}

local LOCKDOWN_WEAPON_SLOTS = {
	slot_primary = true,
	slot_secondary = true,
}

local function _active_lockdown()
	for i = 1, #WEAPON_LOCKDOWNS do
		local config = WEAPON_LOCKDOWNS[i]
		local ok, active = pcall(config.active)
		if ok and active then return config end
	end
	return nil
end

-- v0.22.87: Unlimited Power's "is the boon actually live on this
-- psyker" check, kept for the channel-flag patch and the probe (the
-- input lockdown that used to consume it is retired).
local function _up_boon_live()
	local Boons = modules and modules.Boons
	if not Boons or not Boons.custom_boon_active
		or not Boons.custom_boon_active("pilgrim_boon_unlimited_power") then
		return false
	end
	local Shared = modules and modules.Shared
	if not Shared or Shared.is_in_hub() or Shared.is_in_psykhanium() then
		return false
	end
	local state = RunState.get()
	if (state.stat_archetype or "") ~= "psyker" then return false end
	-- v0.22.85 (Kaizen): "active only if smite is in the talent tree."
	-- Without this, a psyker running Assail or Brain Burst would get
	-- locked to THAT blitz at x100, which is not the boon. Same check
	-- the apply-time gate in boons.lua uses.
	--
	-- v0.22.86: the blitz players call Smite is INTERNALLY
	-- psyker_chain_lightning; the template named psyker_smite is
	-- Brain Burst. v0.22.85 shipped the wrong name for one evening.
	-- Kaizen caught it ("smite does deal damage... it is not 0"),
	-- which also killed v0.22.85's wrong root cause: the real channel
	-- tick profile (psyker_protectorate_channel_chain_lightning_
	-- activated) has attack power 20 scaled by the ramping
	-- attack_charge and IS multiplied by the damage stat, so no
	-- profile patching is needed at all; the x100 stat is enough once
	-- it actually lands, and /pil_up_probe proves whether it does.
	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	if not unit or not Boons.blitz_template_name
		or Boons.blitz_template_name(unit) ~= "psyker_chain_lightning" then
		return false
	end
	return true
end

local function _up_local_player_components()
	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	if not unit then return nil end
	local ok_ud, ud = pcall(ScriptUnit.extension, unit, "unit_data_system")
	if not ok_ud or not ud then return nil end
	local ok_inv, inventory = pcall(ud.read_component, ud, "inventory")
	local ok_wc, warp_charge = pcall(ud.read_component, ud, "warp_charge")
	return (ok_inv and inventory or nil), (ok_wc and warp_charge or nil)
end

if rawget(_G, "CLASS") and CLASS.InputService then
	mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
		-- Dormant when no lockdown is registered: one length check.
		if #WEAPON_LOCKDOWNS == 0 then
			return func(self, action_name)
		end
		-- Cheap first gates: only the inputs we care about pay more
		-- than a table lookup.
		if LOCKDOWN_BLOCKED_WIELD_INPUTS[action_name] then
			local ok, blocked = pcall(function()
				local config = _active_lockdown()
				if not config then return false end
				local inventory = _up_local_player_components()
				-- v0.22.94: callback-shaped configs decide per input +
				-- inventory (first user: Blood Debt's melee-only rule).
				if config.should_block then
					return config.should_block(action_name, inventory) and true or false
				end
				-- Wielding a pocketable/device/luggable: let wield
				-- inputs work so the player can put it away.
				if inventory and not LOCKDOWN_WEAPON_SLOTS[inventory.wielded_slot]
					and inventory.wielded_slot ~= config.locked_slot then
					return false
				end
				return true
			end)
			if ok and blocked then
				return false
			end
		else
			-- Pay the pcall only for inputs some config snaps to.
			local is_snap_input = false
			for i = 1, #WEAPON_LOCKDOWNS do
				local c = WEAPON_LOCKDOWNS[i]
				if c.snap_input == action_name then
					is_snap_input = true
					break
				end
				local snap_list = c.snap_inputs
				if snap_list then
					for j = 1, #snap_list do
						if snap_list[j] == action_name then
							is_snap_input = true
							break
						end
					end
					if is_snap_input then break end
				end
			end
			if not is_snap_input then
				return func(self, action_name)
			end
			local ok, force = pcall(function()
				local config = _active_lockdown()
				if not config then return false end
				local inventory, warp_charge = _up_local_player_components()
				-- v0.22.94: callback-shaped snap. Returns the input the
				-- config wants forced right now, or nil.
				if config.snap then
					return config.snap(inventory, warp_charge) == action_name
				end
				if action_name ~= config.snap_input then
					return false
				end
				if not inventory or not LOCKDOWN_WEAPON_SLOTS[inventory.wielded_slot] then
					return false
				end
				-- Never force a warp-cost raise at critical Peril.
				if config.peril_gate then
					local peril = warp_charge and warp_charge.current_percentage or 0
					return peril < config.peril_gate
				end
				return true
			end)
			if ok and force then
				return true
			end
		end
		return func(self, action_name)
	end)
end

-- v0.28.15: EXECUTIONER is a genuinely melee-only Archetype. This uses the

-- same field-proven input and auto-snap seam: the ranged wield
-- input is refused, and any internal game path which restores the ranged
-- weapon is corrected to melee on the next input read. Abilities, blitzes,
-- devices, pocketables and carried objectives remain available.
WEAPON_LOCKDOWNS[#WEAPON_LOCKDOWNS + 1] = {
	active = function()
		local Boons = modules and modules.Boons
		if not Boons or not Boons.active_archetype_id
			or Boons.active_archetype_id() ~= "pilgrim_arch_executioner" then
			return false
		end
		local Shared = modules and modules.Shared
		return Shared ~= nil and not Shared.is_in_hub()
			and not Shared.is_in_psykhanium()
	end,
	should_block = function(action_name, inventory)
		local slot = inventory and inventory.wielded_slot
		if action_name == "wield_2" then return true end
		if action_name == "quick_wield" then
			return slot == "slot_primary"
		end
		if action_name == "wield_scroll_down" or action_name == "wield_scroll_up" then
			return true
		end
		return false
	end,
	snap_inputs = { "wield_1" },
	snap = function(inventory, warp_charge)
		if inventory and inventory.wielded_slot == "slot_secondary" then
			return "wield_1"
		end
		return nil
	end,
}

-- ---------------------------------------------------------------------------
-- v0.22.94 (Kaizen): PER-BOT WEAPON BANS. Preset entries may carry
-- weapon_ban = "melee" | "ranged"; the banned slot is refused at the
-- bot brain's own switching seam. BtBotInventorySwitchAction.run reads
-- action_data.wanted_slot (a SHARED tree table), so the hook swaps the
-- field, calls through, and restores it; single-threaded Lua makes the
-- swap safe. Redirecting rather than refusing means a bot standing in
-- the banned slot converges onto the allowed one at the next switch.
-- Bot identity: profile.character_id carries the pilgrim_<preset_id>
-- mangle (preset.lua line 1873), cached per unit in a weak table.

local WEAPON_BAN_SLOTS = {
	melee = "slot_primary",
	ranged = "slot_secondary",
}
local _bot_ban_by_character_id = nil
local _bot_blitz_ban_by_character_id = nil
local _bot_ban_unit_cache = setmetatable({}, { __mode = "k" })
local _bot_blitz_ban_unit_cache = setmetatable({}, { __mode = "k" })

-- Self-contained on purpose: the FF block's _player_for_unit is
-- declared LATER in this file, and a function only captures locals
-- that exist above it at parse time (the v0.14.1 scoping lesson).
local function _bot_ban_player_for_unit(unit)
	if not unit then return nil end
	local spawn_manager = Managers.state and Managers.state.player_unit_spawn
	if not spawn_manager then return nil end
	local ok, player = pcall(spawn_manager.owner, spawn_manager, unit)
	return ok and player or nil
end

local function _ensure_bot_restriction_registry()
	if not _bot_ban_by_character_id or not _bot_blitz_ban_by_character_id then
		_bot_ban_by_character_id = {}
		_bot_blitz_ban_by_character_id = {}
		local Preset = modules and modules.Preset
		local catalogue = Preset and Preset.all and Preset.all() or {}
		for i = 1, #catalogue do
			local entry = catalogue[i]
			local character_id = "pilgrim_" .. tostring(entry.id)
			local banned = entry.weapon_ban and WEAPON_BAN_SLOTS[entry.weapon_ban]
			if banned then
				_bot_ban_by_character_id[character_id] = banned
			end
			if entry.blitz_ban then _bot_blitz_ban_by_character_id[character_id] = true end
		end
	end
end

local function _bot_banned_slot(unit)
    local cached = _bot_ban_unit_cache[unit]
    if cached ~= nil then
        return cached or nil
    end
	_ensure_bot_restriction_registry()
	local banned = false
	local player = _bot_ban_player_for_unit(unit)
	if player then
		local ok_h, is_human = pcall(player.is_human_controlled, player)
		if ok_h and not is_human then
			local ok_p, profile = pcall(player.profile, player)
			local character_id = ok_p and profile and profile.character_id
			banned = character_id and _bot_ban_by_character_id[character_id] or false
		end
	end
	_bot_ban_unit_cache[unit] = banned
	return banned or nil
end

local function _bot_blitz_banned(unit)
	local cached = _bot_blitz_ban_unit_cache[unit]
	if cached ~= nil then return cached end
	_ensure_bot_restriction_registry()
	local banned = false
	local player = _bot_ban_player_for_unit(unit)
	if player then
		local ok_h, is_human = pcall(player.is_human_controlled, player)
		if ok_h and not is_human then
			local ok_p, profile = pcall(player.profile, player)
			local character_id = ok_p and profile and profile.character_id
			banned = character_id
				and _bot_blitz_ban_by_character_id[character_id] == true or false
		end
	end
	_bot_blitz_ban_unit_cache[unit] = banned
	return banned
end

if rawget(_G, "CLASS") and CLASS.BtBotInventorySwitchAction then
	mod:hook(CLASS.BtBotInventorySwitchAction, "run",
		function(func, self, unit, breed, blackboard, scratchpad, action_data, dt, t)
			local ok, banned = pcall(_bot_banned_slot, unit)
			if ok and banned and action_data.wanted_slot == banned then
				local original = action_data.wanted_slot
				local allowed = banned == "slot_primary" and "slot_secondary" or "slot_primary"
				action_data.wanted_slot = allowed
				local a, b = func(self, unit, breed, blackboard, scratchpad, action_data, dt, t)
				action_data.wanted_slot = original
				return a, b
			end
			return func(self, unit, breed, blackboard, scratchpad, action_data, dt, t)
		end)
end

-- The game calls a bot's blitz its "grenade_ability", even for rocks,
-- grenades and Psyker powers. Return done before the action queues input for a
-- preset that bans blitzes. The combat_ability branch is deliberately untouched.
if rawget(_G, "CLASS") and CLASS.BtBotActivateAbilityAction then
	mod:hook(CLASS.BtBotActivateAbilityAction, "run",
		function(func, self, unit, breed, blackboard, scratchpad, action_data, dt, t)
			if action_data and action_data.ability_component_name == "grenade_ability" then
				local ok, banned = pcall(_bot_blitz_banned, unit)
				if ok and banned then return "done" end
			end
			return func(self, unit, breed, blackboard, scratchpad, action_data, dt, t)
		end)
end

-- ---------------------------------------------------------------------------
-- v0.22.94: boot-time audit for the hand-kept capture dropdown (it went
-- stale once and hid Cassia). Compares the settings dropdown's values
-- against the live catalogue and yells about any drift, once, at boot.

Tick.register("capture_dropdown_audit", 30, function()
	if mod._capture_audit_done then return end
	mod._capture_audit_done = true
	local Preset = modules and modules.Preset
	local catalogue = Preset and Preset.all and Preset.all() or {}
	-- io_dofile appends .lua itself. Supplying the extension here made it
	-- request Pilgrimage_data.lua.lua on every install.
	local ok_dof, data = pcall(mod.io_dofile, mod, "Pilgrimage/scripts/mods/Pilgrimage/Pilgrimage_data")
	if not ok_dof or type(data) ~= "table" then return end
	local values = {}
	local function walk(widgets)
		for i = 1, #(widgets or {}) do
			local w = widgets[i]
			if w.setting_id == "capture_target_preset" and w.options then
				for j = 1, #w.options do values[w.options[j].value] = true end
			end
			walk(w.sub_widgets)
		end
	end
	walk(data.options and data.options.widgets)
	if not next(values) then return end
	local missing = {}
	for i = 1, #catalogue do
		local id = catalogue[i].id
		if id and not values[id] then missing[#missing + 1] = tostring(id) end
	end
	if #missing > 0 then
		mod:echo("Pilgrimage: capture dropdown is missing preset(s): "
			.. table.concat(missing, ", ") .. " (update Pilgrimage_data.lua)")
	end
end)

-- ---------------------------------------------------------------------------
-- v0.22.87: Unlimited Power's channel-flag patch. The Smite channel
-- tick profile (psyker_protectorate_channel_chain_lightning_activated)
-- ships WITHOUT the chain_lightning flag that gates the
-- chain_lightning_damage stat (damage_calculation.lua line 509); the
-- electrocuted DoT profile has it, the channel does not. While the
-- boon is live we set the flag in place so the boon's +49.9 reaches
-- the channel ticks, and clear it the moment the boon stops. Same
-- shared-settings-table technique as ever: the actions captured a
-- reference to this exact table, so a field write reaches them.
-- Vanilla side effect while flagged: Empowered Psionics'
-- chain_lightning_damage would also touch channel ticks; it only ever
-- coexists with the boon's own bucket, documented in boons.lua.

local _up_channel_flagged = false

local function _up_patch_channel_flag(active)
	local ok, DamageProfileTemplates =
		pcall(require, "scripts/settings/damage/damage_profile_templates")
	if not ok or type(DamageProfileTemplates) ~= "table" then return end
	local profile = DamageProfileTemplates.psyker_protectorate_channel_chain_lightning_activated
	if not profile then return end
	if active and not _up_channel_flagged then
		profile.chain_lightning = true
		_up_channel_flagged = true
	elseif not active and _up_channel_flagged then
		profile.chain_lightning = nil
		_up_channel_flagged = false
	end
end

-- ---------------------------------------------------------------------------
-- v0.22.87: CORRUPTOR BANE, Kaizen's hidden always-on helper (no boon
-- slot, no UI): "increase the damage to corruptors by 10x... this is
-- the hardest objective to complete when playing with bots." Two
-- entity kinds, both covered:
--  * the eye clusters (level-prop pustules, unit corruptor_bulb),
--    reachable as each corruptor arm's _target_units list;
--  * the big eye itself (the corruptor unit, corruptor_system
--    extension).
-- A 2s tick collects both into a weak-keyed set; a hook on
-- HealthExtension.add_damage (the props' health class; same seam
-- family as the Blood Debt heal hook) multiplies incoming damage for
-- units in the set while a Pilgrimage run is active. Host-authority
-- only, which Pilgrimage always is. Bots still won't TARGET them;
-- this buys the player enough damage to beat the regrowth solo.

local CORRUPTOR_BANE_MULTIPLIER = 10
local _corruptor_units = setmetatable({}, { __mode = "k" })

-- v0.22.93: the second half of the corruptor helper. Kaizen: "you have
-- very little time to kill them before they regenerate." True bot
-- targeting was assessed and SHELVED: bot threat selection is breed-
-- and-side-based, so level props are structurally invisible to it, and
-- reaching them means behavior-tree surgery (recorded in the roadmap;
-- same discipline as the cutscene-extras CEILING). Instead: the arm's
-- regrowth speed is read live from the shared CorruptorSettings table
-- per difficulty (corruptor_arm_extension.lua line 174,
-- animation_speed_multiplier.regrowth = {0.25..1.5} by challenge), so
-- the proven in-place patch halves it while a run is active, doubling
-- the window on top of Bane's x10, and restores the originals after.
-- v0.28.15: Executioner cannot switch to a ranged weapon, so it receives
-- the approved three-times-normal window. This SELECTS a 1/3 scale instead
-- of stacking on the general 1/2 scale, avoiding an unintended 6x window.
local CORRUPTOR_REGROWTH_SCALE = 0.5
local EXECUTIONER_CORRUPTOR_REGROWTH_SCALE = 1 / 3
local _regrowth_patched = false
local _regrowth_originals = nil

local function _current_corruptor_regrowth_scale()
	local Boons = modules and modules.Boons
	if Boons and Boons.active_archetype_id
		and Boons.active_archetype_id() == "pilgrim_arch_executioner" then
		return EXECUTIONER_CORRUPTOR_REGROWTH_SCALE
	end
	return CORRUPTOR_REGROWTH_SCALE
end

local function _patch_corruptor_regrowth(active)
	local ok, CorruptorSettings = pcall(require, "scripts/settings/corruptor/corruptor_settings")
	if not ok or type(CorruptorSettings) ~= "table" then return end
	local speeds = CorruptorSettings.animation_speed_multiplier
	local regrowth = speeds and speeds.regrowth
	if type(regrowth) ~= "table" then return end
	if active and not _regrowth_patched then
		local scale = _current_corruptor_regrowth_scale()
		_regrowth_originals = {}
		for i = 1, #regrowth do
			_regrowth_originals[i] = regrowth[i]
			regrowth[i] = regrowth[i] * scale
		end
		_regrowth_patched = true
	elseif not active and _regrowth_patched then
		if _regrowth_originals then
			for i = 1, #regrowth do
				regrowth[i] = _regrowth_originals[i] or regrowth[i]
			end
		end
		_regrowth_originals = nil
		_regrowth_patched = false
	end
end

Tick.register("corruptor_bane", 2, function()
	local Shared = modules and modules.Shared
	if not Shared or Shared.is_in_hub() then
		_patch_corruptor_regrowth(false)
		return
	end
	if not RunState.is_active() then
		_patch_corruptor_regrowth(false)
		return
	end
	_patch_corruptor_regrowth(true)
	local ext_manager = Managers.state and Managers.state.extension
	if not ext_manager then return end

	local ok_c, corruptor_system = pcall(ext_manager.system, ext_manager, "corruptor_system")
	if ok_c and corruptor_system and corruptor_system.unit_to_extension_map then
		local ok_map, map = pcall(corruptor_system.unit_to_extension_map, corruptor_system)
		if ok_map and type(map) == "table" then
			for unit in pairs(map) do
				_corruptor_units[unit] = true
			end
		end
	end

	local ok_a, arm_system = pcall(ext_manager.system, ext_manager, "corruptor_arm_system")
	if ok_a and arm_system and arm_system.unit_to_extension_map then
		local ok_map, map = pcall(arm_system.unit_to_extension_map, arm_system)
		if ok_map and type(map) == "table" then
			for _, arm_extension in pairs(map) do
				local targets = arm_extension and arm_extension._target_units
				if type(targets) == "table" then
					for i = 1, #targets do
						local target = targets[i]
						if target then _corruptor_units[target] = true end
					end
				end
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- v0.23.3 (FB-2, player suggestion): TESTING / CHEAT MODE.
-- State cached by a 1s tick so per-damage-event reads never touch
-- settings. Effects while cheat_mode is on and not in the hub:
--   invulnerable  local player's health extension set_invulnerable,
--                 the engine API Improved Meat Grinder field-proves.
--                 Applied and RESTORED through a tracked set so we only
--                 ever clear a flag we ourselves set (another mod's god
--                 mode is left alone).
--   one_shot      local player's damage to minions and props massively
--                 multiplied, riding the same HealthExtension.add_damage
--                 hook Corruptor Bane already owns (minions use the
--                 HealthExtension class too, minion_unit_template line
--                 184).
-- Penance earning is suspended while cheat_mode is on (penances.observe
-- gate). Works in missions AND the Psykhanium: testing is the point.
local CHEAT_ONE_SHOT_MULTIPLIER = 1000
local _cheat = { on = false, invulnerable = false, one_shot = false }
local _cheat_invuln_set_by_us = setmetatable({}, { __mode = "k" })

Tick.register("cheat_mode", 1, function()
	_cheat.on = Settings and Settings.cheat_mode_enabled
		and Settings.cheat_mode_enabled() or false
	local Shared_m = modules and modules.Shared
	local in_hub = Shared_m and Shared_m.is_in_hub and Shared_m.is_in_hub()
	local active = _cheat.on and not in_hub

	local inv = Settings and Settings.cheat_invulnerable_enabled
		and Settings.cheat_invulnerable_enabled() or false
	local osk = Settings and Settings.cheat_one_shot_enabled
		and Settings.cheat_one_shot_enabled() or false
	_cheat.invulnerable = active and inv or false
	_cheat.one_shot = active and osk or false

	-- Invulnerability apply / restore on the LOCAL player only.
	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	if not unit then return end
	local ok_e, ext = pcall(ScriptUnit.has_extension, unit, "health_system")
	if not ok_e or not ext or type(ext.set_invulnerable) ~= "function" then return end
	if _cheat.invulnerable then
		if not _cheat_invuln_set_by_us[ext] then
			local ok_s = pcall(ext.set_invulnerable, ext, true)
			if ok_s then _cheat_invuln_set_by_us[ext] = true end
		end
	elseif _cheat_invuln_set_by_us[ext] then
		pcall(ext.set_invulnerable, ext, false)
		_cheat_invuln_set_by_us[ext] = nil
	end
end)

if rawget(_G, "CLASS") and CLASS.HealthExtension then
	mod:hook(CLASS.HealthExtension, "add_damage",
		function(func, self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit)
			if type(damage_amount) == "number" and damage_amount > 0 then
				if _corruptor_units[self._unit] and RunState.is_active() then
					damage_amount = damage_amount * CORRUPTOR_BANE_MULTIPLIER
				end
				-- v0.23.3: one-shot cheat, local player's hits only.
				if _cheat.one_shot and attacking_unit ~= nil then
					local lp = Managers.player and Managers.player:local_player_safe(1)
					if lp and lp.player_unit == attacking_unit then
						damage_amount = damage_amount * CHEAT_ONE_SHOT_MULTIPLIER
					end
				end
			end
			return func(self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit)
		end)
end

-- ---------------------------------------------------------------------------
-- v0.22.88 (Session C): ENEMY BAN enforcement. The Emporium's Writs of
-- Exclusion (shop.lua, category "ban") remove a breed family from the
-- rest of the run. Single seam: MinionSpawnManager.spawn_minion is the
-- funnel every spawn path goes through (monster/specials/roamer pacing,
-- mutators, and the minion_spawner extension hordes ride; verified in
-- dt-src). Policies, decided at purchase-data level in shop.lua:
--   "skip"  monsters and daemonhosts; the spawn is dropped. The known
--           nil-tolerance risk is monster_pacing's bookkeeping, which
--           appends the result to arrays (nil append = no-op) and
--           guards with HEALTH_ALIVE; field-test item.
--   true    substituted with faction trash so pacing counts stay sane
--           and no caller ever holds a nil unit: renegades become
--           riflemen, cultists become assaulters, everything else
--           becomes the newly infected.
-- The banned-breed map is rebuilt by a 2s tick (bans are bought at the
-- hub terminal; they cannot change mid-mission) and only ever populated
-- during a Pilgrimage run mission, so normal play never pays more than
-- one next() check per spawn.

local BAN_TRASH_SUBSTITUTES = {
	renegade = "renegade_rifleman",
	cultist  = "cultist_assault",
}
local BAN_DEFAULT_SUBSTITUTE = "chaos_newly_infected"

local _banned_breed_map = {}

-- v0.22.92: the friendly fire POLICY, computed once per tick so the
-- per-attack hooks never pay a settings read. Three sources, from the
-- Kaizen design session that killed the buy-a-downside SKU:
--   discord  Sanctioned Discord boon: your attacks wound your warband;
--            theirs wound nobody. Asymmetric, the price of +100% dmg.
--   serpent  The Serpent Below curse: ONE seeded bot has symmetric FF
--            with the human. Their strays wound you, yours wound them,
--            everyone else is untouched. You are not told who.
--   hazard   Hazard Pay contract: FF fully on, both directions,
--            everyone, this assignment, in exchange for +50% Ordos.
local _ff = {
	discord = false,
	serpent = false,
	hazard = false,
	mode = "off",
	traitor_unit = nil,
	was_in_mission = false,
}

-- Friendly-fire sources can overlap, but enforcement must have one answer.
-- Hazard Pay is the broadest contract and therefore wins outright. Discord
-- comes next, then Serpent's single-traitor rule. Keeping this as one mode
-- prevents two independent booleans from being interpreted differently by
-- the early attack gate and the later damage filter.
local function _refresh_ff_mode()
	if _ff.hazard then
		_ff.mode = "hazard"
	elseif _ff.discord then
		_ff.mode = "discord"
	elseif _ff.serpent then
		_ff.mode = "serpent"
	else
		_ff.mode = "off"
	end
	return _ff.mode
end

local function _reset_ff_state()
	_ff.discord, _ff.serpent, _ff.hazard = false, false, false
	_ff.mode = "off"
	_ff.traitor_unit = nil
	_ff.was_in_mission = false
end

-- Deterministic traitor pick: bot player units sorted by account/slot
-- identity, index seeded from the run seed + current leg, so the same
-- run always accuses the same bot and a restart cannot reroll it.
local function _pick_traitor_unit()
	local players = Managers.player and Managers.player:players()
	if not players then return nil end
	local bots = {}
	for _, player in pairs(players) do
		local ok_h, is_human = pcall(player.is_human_controlled, player)
		if ok_h and not is_human and player.player_unit then
			bots[#bots + 1] = player
		end
	end
	if #bots == 0 then return nil end
	table.sort(bots, function(a, b)
		local an = tostring(a._unique_id or a.__unique_id or a)
		local bn = tostring(b._unique_id or b.__unique_id or b)
		return an < bn
	end)
	local state = RunState.get()
	local seed = (tonumber(state.seed) or 0) + (tonumber(state.index) or 0)
	local pick = (seed % #bots) + 1
	return bots[pick].player_unit
end

Tick.register("enemy_bans", 2, function()
	local Chain = modules and modules.Chain
	local Shop = modules and modules.Shop
	local Boons = modules and modules.Boons
	local Shared = modules and modules.Shared
	if not Shop or not Shop.active_ban_breeds then return end
	local in_run_mission = Chain and Chain.is_run_mission and Chain.is_run_mission()
	if not RunState.is_active() then
		if next(_banned_breed_map) then _banned_breed_map = {} end
		_reset_ff_state()
		return
	end
	if not in_run_mission then
		-- Mission identity can be briefly unavailable while the level is
		-- streaming. Holding the last policy outside the hub avoids a two-second
		-- window where Serpent or vanilla rules can appear to replace Hazard.
		-- Consumption is only safe after the hub has actually loaded.
		local in_hub = Shared and Shared.is_in_hub and Shared.is_in_hub()
		if not in_hub then return end
		if next(_banned_breed_map) then _banned_breed_map = {} end
		-- v0.22.92: Hazard Pay is one assignment long. Consume it at
		-- the mission->hub transition, AFTER the leg's payouts have
		-- run (they happen during mission end, before the hub loads,
		-- so the wallet's +50% catches them).
		if _ff.hazard and _ff.was_in_mission and Shop.consume then
			pcall(Shop.consume, "hazard_pay")
		end
		_reset_ff_state()
		return
	end
	_ff.was_in_mission = true
	local ok, map = pcall(Shop.active_ban_breeds)
	if ok and type(map) == "table" then
		_banned_breed_map = map
	end

	-- v0.28.45: Sanctioned Discord became Crossfire Catechism. It has
	-- no friendly-fire clause, so only Hazard Pay and Serpent Below can
	-- open the player-damage gate now.
	_ff.discord = false

	local ok_h, hazard = pcall(Shop.is_active, "hazard_pay")
	-- Latch the contract for the whole assignment. A failed settings read must
	-- never narrow all-party Hazard Pay into Serpent's one-bot relationship.
	if ok_h and hazard then _ff.hazard = true end

	_ff.serpent = false
	local ok_p, prefix = pcall(RunState.curse_prefix)
	if ok_p and type(prefix) == "table" then
		for i = 1, #prefix do
			if prefix[i] == "pilgrim_serpent_below" then
				_ff.serpent = true
				break
			end
		end
	end
	if _ff.serpent then
		local ok_t, unit = pcall(_pick_traitor_unit)
		_ff.traitor_unit = ok_t and unit or nil
	else
		_ff.traitor_unit = nil
	end
	_refresh_ff_mode()
end)

if rawget(_G, "CLASS") and CLASS.MinionSpawnManager then
	mod:hook(CLASS.MinionSpawnManager, "spawn_minion",
		function(func, self, breed_name, position, rotation, side_id, ...)
			if next(_banned_breed_map) ~= nil then
				local policy = _banned_breed_map[breed_name]
				if policy == "skip" then
					_debug_log("bans", 0, "suppressed spawn of " .. tostring(breed_name), 0, "info")
					return nil
				elseif policy then
					local prefix = string.match(tostring(breed_name), "^(%a+)_")
					local substitute = BAN_TRASH_SUBSTITUTES[prefix] or BAN_DEFAULT_SUBSTITUTE
					_debug_log("bans", 0, "substituted " .. tostring(breed_name)
						.. " with " .. substitute, 0, "info")
					breed_name = substitute
				end
			end
			return func(self, breed_name, position, rotation, side_id, ...)
		end)
end

-- ---------------------------------------------------------------------------
-- v0.22.92: friendly fire enforcement, shared by all three policies.
-- Two layers:
--  1. CLASS.DifficultyManager.friendly_fire_enabled returns true for
--     player targets while ANY policy is live. This is the runtime
--     manager method that utilities/attack/friendly_fire.lua delegates
--     to per damage event, so it IS reachable, unlike the frozen
--     pre-mod utilities (fanout lesson); vanilla returns false for
--     player targets always (difficulty_manager.lua line 122).
--  2. The engine gate is symmetric, so the directional filter on
--     CLASS.PlayerUnitHealthExtension.add_damage decides per attack:
--       hazard    everything passes, both directions.
--       discord   human attacker passes; bot attacker zeroed.
--       serpent   human -> traitor passes; traitor -> human passes;
--                 every other player pairing zeroed unless another
--                 live policy allows it.
--     Zero is passed through rather than the call swallowed, so
--     last-attacker bookkeeping stays consistent.

local function _player_for_unit(unit)
	if not unit then return nil end
	local spawn_manager = Managers.state and Managers.state.player_unit_spawn
	if not spawn_manager then return nil end
	local ok, player = pcall(spawn_manager.owner, spawn_manager, unit)
	return ok and player or nil
end

-- v0.22.97: second resolution path with no spawn-manager dependency,
-- walk Managers.player's list and match player_unit directly (same
-- iteration _pick_traitor_unit already relies on).
local function _player_for_unit_scan(unit)
	if not unit then return nil end
	local pm = Managers.player
	if not pm or not pm.players then return nil end
	local ok, players = pcall(pm.players, pm)
	if not ok or type(players) ~= "table" then return nil end
	for _, player in pairs(players) do
		if player and player.player_unit == unit then
			return player
		end
	end
	return nil
end

-- v0.22.97: attacker resolution, owner lookup first, list scan second.
-- Returns player_or_nil plus a tag naming which path resolved, for the
-- ff_diag lines (the 2026-08-11 field report's prime suspect is this
-- resolution failing for bot attackers and the filter stepping aside).
local function _resolve_ff_player(unit)
	local player = _player_for_unit(unit)
	if player then return player, "owner" end
	player = _player_for_unit_scan(unit)
	if player then return player, "scan" end
	return nil, "none"
end

-- v0.22.97: engine-grade attacker classification. The engine's own
-- FriendlyFire.is_enabled keys on breed_type == "player" (utilities/
-- breed.lua, BreedSettings.types), so a player-breed attacker now
-- ALWAYS engages the filter even when neither player lookup resolves.
-- Minion attackers fail this check and stay untouched, as they must.
local function _unit_is_player_breed(unit)
	if not unit then return false end
	local ok, ext = pcall(ScriptUnit.has_extension, unit, "unit_data_system")
	if not ok or not ext then return false end
	local ok_b, breed = pcall(ext.breed, ext)
	return (ok_b and type(breed) == "table" and breed.breed_type == "player") or false
end

local function _unit_is_human(unit)
	local player = _resolve_ff_player(unit)
	if not player then return false end
	local ok, is_human = pcall(player.is_human_controlled, player)
	return ok and is_human or false
end

-- v0.22.94 shipped a single x0.05 chip scale after a bot instantly
-- downed Kaizen. The 2026-08-11 field report showed x0.05 also makes
-- player->bot damage invisible: a ~150 shotgun blast becomes ~7 and
-- lands on bot toughness, which regenerates it away. v0.22.97 per
-- Kaizen: asymmetric. Bots stay chip damage against the human; the
-- human hits bots at half value, enough to break toughness and put
-- visible damage on their health bars. Economy-pass values.
local FF_SCALE_HUMAN_ATTACKER = 0.5
local FF_SCALE_BOT_ATTACKER = 0.05

local function _ff_attack_allowed(attacking_unit, target_unit, attacker_is_human)
	if _ff.mode == "hazard" then return true end
	if _ff.mode == "discord" and attacker_is_human then return true end
	if _ff.mode == "serpent" and _ff.traitor_unit then
		if attacker_is_human and target_unit == _ff.traitor_unit then return true end
		if attacking_unit == _ff.traitor_unit and _unit_is_human(target_unit) then return true end
	end
	return false
end

-- v0.28.16: make the unit-aware utility the primary friendly-fire gate. The
-- DifficultyManager API only receives two booleans ("target is player" and
-- "target is minion"), so opening it for Serpent necessarily makes every bot
-- hittable unless a later health hook manages to zero the damage. That later
-- hook is retained as defence in depth, but this utility sees both units and
-- can reject the wrong bot before an attack becomes a damage event at all.
local ok_friendly_fire, FriendlyFire = pcall(
	require,
	"scripts/utilities/attack/friendly_fire"
)
if ok_friendly_fire and type(FriendlyFire) == "table"
	and type(FriendlyFire.is_enabled) == "function" then
	mod:hook(FriendlyFire, "is_enabled",
		function(func, attacking_unit, target_unit, attack_type)
			if _ff.mode ~= "off"
				and _unit_is_player_breed(attacking_unit)
				and _unit_is_player_breed(target_unit) then
				local attacker_is_human = _unit_is_human(attacking_unit)
				return _ff_attack_allowed(
					attacking_unit,
					target_unit,
					attacker_is_human
				)
			end
			return func(attacking_unit, target_unit, attack_type)
		end)
end

-- v0.22.97 FF DIAGNOSTIC. mod:echo is invisible on this install (DMF
-- logging_mode custom), so this follows the proven bot_spawn_diag.txt
-- shape: append-only file next to the mod folder. Lines are only
-- produced while an FF policy is live (plus one boot line), and each
-- line kind is capped so a runaway can never grow the file unbounded.
-- Delete the file freely between tests; every write reopens it.
local FF_DIAG_PATH = "./../mods/Pilgrimage/ff_diag.txt"
local FF_DIAG_CAPS = { boot = 5, gate = 60, dmg = 400, probe = 40, ["class"] = 20 }
local _ff_diag_counts = { boot = 0, gate = 0, dmg = 0, probe = 0, ["class"] = 0 }
-- Set at hook registration below, flushed lazily by the first write of
-- any kind, so the boot summary lands even if the io layer was not
-- ready at mod-load time (a missing boot line must mean "hooks did not
-- register", never "file io raced the loader").
local _ff_diag_pending_boot = nil

-- v0.23.0 (Nexus beta): every file-writing diagnostic is now gated
-- behind one opt-in setting, default OFF, so public installs never
-- accumulate log files in the mod folder. Toggle: /pil_diagnostics on.
-- The dev install keeps the FF hunt alive by turning it on.
local function _diagnostics_enabled()
	local ok, v = pcall(mod.get, mod, "diagnostics_enabled")
	return ok and v == true
end

local function _ff_diag_raw(line)
	if not _diagnostics_enabled() then return false end
	local Mods = rawget(_G, "Mods")
	local io_l = Mods and Mods.lua and Mods.lua.io
	local os_l = Mods and Mods.lua and Mods.lua.os
	if not io_l then return false end
	local timestamp = "?"
	if os_l and os_l.date then
		local ok_t, txt = pcall(os_l.date, "%Y-%m-%d %H:%M:%S")
		if ok_t and txt then timestamp = txt end
	end
	local ok = pcall(function()
		local file = io_l.open(FF_DIAG_PATH, "a")
		if file then
			file:write("[" .. timestamp .. "] " .. line .. "\n")
			file:close()
		end
	end)
	return ok
end

local function _ff_diag(kind, line)
	local cap = FF_DIAG_CAPS[kind] or 0
	local count = _ff_diag_counts[kind] or 0
	if count >= cap then return end
	if _ff_diag_pending_boot and kind ~= "boot" then
		local boot_line = _ff_diag_pending_boot
		_ff_diag_pending_boot = nil
		_ff_diag_counts.boot = (_ff_diag_counts.boot or 0) + 1
		_ff_diag_raw(boot_line)
	end
	if _ff_diag_raw(line) then
		_ff_diag_counts[kind] = count + 1
	end
end

-- Short tag for a unit in diag lines: HUMAN, the bot's pilgrim_ id,
-- or the raw unit tostring when no player resolves at all.
local function _ff_unit_tag(unit)
	local player = _resolve_ff_player(unit)
	if player then
		local ok_h, is_human = pcall(player.is_human_controlled, player)
		if ok_h and is_human then return "HUMAN" end
		local ok_p, profile = pcall(player.profile, player)
		local cid = ok_p and profile and profile.character_id
		if cid then return tostring(cid) end
	end
	return tostring(unit)
end

if rawget(_G, "CLASS") and CLASS.DifficultyManager then
	mod:hook(CLASS.DifficultyManager, "friendly_fire_enabled",
		function(func, self, target_is_player, target_is_minion)
			if target_is_player and _ff.mode ~= "off" then
				-- Only ally-vs-ally checks reach here: the engine
				-- short-circuits (not is_ally) before consulting
				-- FriendlyFire.is_enabled, so this stays low-volume.
				_ff_diag("gate", "gate open (player target) d="
					.. tostring(_ff.discord) .. " s=" .. tostring(_ff.serpent)
					.. " h=" .. tostring(_ff.hazard)
					.. " mode=" .. tostring(_ff.mode))
				return true
			end
			return func(self, target_is_player, target_is_minion)
		end)
end

-- v0.22.98: SHARED FILTER BODY. The v0.22.97 field test (ff_diag
-- 2026-08-11) proved the CLASS.PlayerUnitHealthExtension.add_damage
-- hook never fires on Kaizen's install even while the gate hook on
-- DifficultyManager provably does: gate lines logged at the exact
-- seconds bot shots landed, zero dmg lines, boot line confirming both
-- hooks registered. Conclusion: something in the ~150-mod install
-- intercepts add_damage above the class table (raw method replacement
-- or instance-level override by another mod). Enforcement therefore
-- moves to INSTANCE level (below), which wins over any class-table
-- manipulation; the class hook stays as a sentinel and fallback.
--
-- _ff_inner guards double-application: when the instance wrapper has
-- already filtered a call, the class hook (if the chain beneath the
-- wrapper reaches it) must pass through untouched.
local _ff_inner = false
local _ff_damage_pre_scaled_depth = 0

local function _ff_apply_filter(target_unit, damage_amount, permanent_damage, attacking_unit, src)
	if not (_ff.mode ~= "off"
		and attacking_unit and attacking_unit ~= target_unit
		and _unit_is_player_breed(target_unit)) then
		return damage_amount, permanent_damage, nil
	end
	-- v0.22.97: a player-BREED attacker always engages the filter; the
	-- player-object resolution only decides direction (human vs bot).
	local attacker_player, how = _resolve_ff_player(attacking_unit)
	local attacker_is_player = attacker_player ~= nil
		or _unit_is_player_breed(attacking_unit)
	if not attacker_is_player then
		-- Non-player attackers (minions) fall through untouched; no
		-- log, they are the hot path during a mission.
		return damage_amount, permanent_damage, nil
	end
	local attacker_is_human = false
	if attacker_player then
		local ok_h, is_human = pcall(attacker_player.is_human_controlled, attacker_player)
		attacker_is_human = (ok_h and is_human) or false
	else
		-- Breed says player but no player object found: last-resort
		-- humanity check against the local player's own unit (host is
		-- the only human in Pilgrimage runs).
		local lp = Managers.player and Managers.player:local_player_safe(1)
		attacker_is_human = (lp and lp.player_unit == attacking_unit) or false
	end
	local dmg_in = tonumber(damage_amount) or 0
	local branch
	local scale
	if _ff_attack_allowed(attacking_unit, target_unit, attacker_is_human) then
		scale = attacker_is_human and FF_SCALE_HUMAN_ATTACKER
			or FF_SCALE_BOT_ATTACKER
		damage_amount = dmg_in * scale
		permanent_damage = (tonumber(permanent_damage) or 0) * scale
		branch = attacker_is_human and "scaled_human" or "scaled_bot"
	else
		scale = 0
		damage_amount = 0
		permanent_damage = 0
		branch = "zeroed"
	end
	_ff_diag("dmg", "src=" .. tostring(src)
		.. " atk=" .. _ff_unit_tag(attacking_unit)
		.. " tgt=" .. _ff_unit_tag(target_unit)
		.. " resolve=" .. tostring(how)
		.. " human=" .. tostring(attacker_is_human)
		.. " in=" .. string.format("%.1f", dmg_in)
		.. " out=" .. string.format("%.1f", tonumber(damage_amount) or 0)
		.. " branch=" .. branch)
	return damage_amount, permanent_damage, scale
end

-- Debug-facing snapshot. It exposes booleans and unit identity only, never
-- mutable state, so the test command can explain policy precedence without
-- being able to alter live combat rules.
mod._friendly_fire_status = function()
	local Shop = modules and modules.Shop
	local purchased = false
	if Shop and Shop.is_active then
		local ok, value = pcall(Shop.is_active, "hazard_pay")
		purchased = ok and value == true
	end
	return {
		mode = _ff.mode,
		discord = _ff.discord,
		serpent = _ff.serpent,
		hazard = _ff.hazard,
		hazard_purchased = purchased,
		traitor = _ff.traitor_unit and _ff_unit_tag(_ff.traitor_unit) or "none",
		was_in_mission = _ff.was_in_mission,
	}
end

-- HealthExtension.add_damage is too late to decide friendly-fire lethality:
-- Damage.deal_damage has already calculated will_die and emitted the proc that
-- drives Until Death. Scale health at that earlier seam, then suppress the
-- legacy extension filter for the nested health write. Toughness stays on its
-- existing engine path because attack_result was already classified before
-- this function and must not be made inconsistent with the amount it carries.
local ok_damage_utility, DamageUtility = pcall(
	require,
	"scripts/utilities/attack/damage"
)
if ok_damage_utility and type(DamageUtility) == "table"
	and type(DamageUtility.deal_damage) == "function" then
	mod:hook(DamageUtility, "deal_damage",
		function(func, unit, breed_or_nil, attacking_unit,
				attacking_unit_owner_unit, attack_result, attack_type,
				damage_profile, damage, permanent_damage, toughness_damage,
				hit_actor, attack_direction, hit_zone_name,
				herding_template_or_nil, is_critical_strike, damage_type,
				hit_world_position_or_nil, wounds_shape_or_nil, instakill,
				damage_absorbed)
			local owner = attacking_unit_owner_unit or attacking_unit
			local scale
			damage, permanent_damage, scale = _ff_apply_filter(unit,
				damage, permanent_damage, owner, "deal")
			local pre_scaled = scale ~= nil
			if pre_scaled then
				_ff_damage_pre_scaled_depth = _ff_damage_pre_scaled_depth + 1
			end
			local ok, result = pcall(func, unit, breed_or_nil, attacking_unit,
				attacking_unit_owner_unit, attack_result, attack_type,
				damage_profile, damage, permanent_damage, toughness_damage,
				hit_actor, attack_direction, hit_zone_name,
				herding_template_or_nil, is_critical_strike, damage_type,
				hit_world_position_or_nil, wounds_shape_or_nil, instakill,
				damage_absorbed)
			if pre_scaled then
				_ff_damage_pre_scaled_depth = math.max(0,
					_ff_damage_pre_scaled_depth - 1)
			end
			if not ok then error(result, 0) end
			return result
		end)
end

if rawget(_G, "CLASS") and CLASS.PlayerUnitHealthExtension then
	mod:hook(CLASS.PlayerUnitHealthExtension, "add_damage",
		function(func, self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit)
			if _ff_inner or _ff_damage_pre_scaled_depth > 0 then
				-- Instance wrapper already filtered this call; also a
				-- useful signal that the class chain IS reachable
				-- beneath the wrapper on this install.
				_ff_diag("class", "class hook fired beneath instance wrap (chain intact)")
			else
				damage_amount, permanent_damage = _ff_apply_filter(
					self._unit, damage_amount, permanent_damage, attacking_unit, "class")
			end
			return func(self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit)
		end)
end

-- v0.22.98: INSTANCE-LEVEL ENFORCEMENT. rawset an add_damage override
-- directly onto each player unit's live health extension. Lua reads
-- instance fields before the metatable chain, so this runs no matter
-- what any other mod did to the class table, and `original` (resolved
-- through the chain at wrap time) preserves every other mod's hooks.
-- Extensions are per-mission objects, so the pump below re-wraps fresh
-- instances each mission; the marker field makes wrapping idempotent.
local function _ff_wrap_health_extension(unit)
	if not unit then return end
	local ok_e, ext = pcall(ScriptUnit.has_extension, unit, "health_system")
	if not ok_e or not ext then return end
	if rawget(ext, "_pilgrimage_ff_wrap") then return end
	local original = ext.add_damage
	if type(original) ~= "function" then return end
	local had_override = rawget(ext, "add_damage") ~= nil
	rawset(ext, "_pilgrimage_ff_wrap", true)
	rawset(ext, "add_damage",
		function(self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit, ...)
			if _ff_damage_pre_scaled_depth == 0 then
				damage_amount, permanent_damage = _ff_apply_filter(
					self._unit, damage_amount, permanent_damage, attacking_unit, "inst")
			end
			_ff_inner = true
			local ok, r1, r2, r3 = pcall(original, self, damage_amount,
				permanent_damage, hit_actor, damage_profile, attack_type,
				attack_direction, attacking_unit, ...)
			_ff_inner = false
			if not ok then error(r1, 0) end
			return r1, r2, r3
		end)
	-- Identity probe: names the culprit class/override situation once
	-- per wrapped instance, so the next ff_diag readout explains WHY
	-- the class hook was or was not being reached.
	local mt = getmetatable(ext)
	local class_tbl = rawget(_G, "CLASS") and CLASS.PlayerUnitHealthExtension
	_ff_diag("probe", "wrapped " .. _ff_unit_tag(unit)
		.. " ext_class=" .. tostring(mt and mt.__class_name)
		.. " mt_is_pu_health=" .. tostring(mt ~= nil and mt == class_tbl)
		.. " prior_instance_override=" .. tostring(had_override))
end

-- v0.25.1 (augentism's tip, verified against level_loader.lua:57): kick
-- the async Mortis FX package load once per mission VM while a run is
-- up. FxGuard.ensure_fx_package is idempotent (single state latch), so
-- a 5s cadence costs one function call and two table reads per tick
-- after the first. Boon visuals bridge through the residency gates
-- until the load lands, then spawn for real.
Tick.register("fx_full_visuals", 5, function()
	local Chain = modules and modules.Chain
	local in_run_mission = Chain and Chain.is_run_mission and Chain.is_run_mission()
	if not in_run_mission or not RunState.is_active() then return end
	local FxGuard = modules and modules.FxGuard
	if FxGuard and FxGuard.ensure_fx_package then
		pcall(FxGuard.ensure_fx_package)
	end
end)

Tick.register("ff_instance_guard", 2, function()
	local Chain = modules and modules.Chain
	local in_run_mission = Chain and Chain.is_run_mission and Chain.is_run_mission()
	if not in_run_mission or not RunState.is_active() then return end
	local pm = Managers.player
	if not pm or not pm.players then return end
	local ok, players = pcall(pm.players, pm)
	if not ok or type(players) ~= "table" then return end
	for _, player in pairs(players) do
		local unit = player and player.player_unit
		if unit then
			_ff_wrap_health_extension(unit)
		end
	end
end)

-- One boot line proves the FF layers registered on this install (if a
-- CLASS entry was nil at load, its block above silently skipped and
-- this line is the tell). Written immediately when file io is up,
-- otherwise queued and flushed by the first runtime diag line.
do
	local boot_line = "v0.22.98 ff layers: class_hook="
		.. tostring((rawget(_G, "CLASS") and CLASS.PlayerUnitHealthExtension) ~= nil)
		.. " diffmgr=" .. tostring((rawget(_G, "CLASS") and CLASS.DifficultyManager) ~= nil)
		.. " instance_guard=true scales human=" .. tostring(FF_SCALE_HUMAN_ATTACKER)
		.. " bot=" .. tostring(FF_SCALE_BOT_ATTACKER)
	if _ff_diag_raw(boot_line) then
		_ff_diag_counts.boot = (_ff_diag_counts.boot or 0) + 1
	else
		_ff_diag_pending_boot = boot_line
	end
end

-- ---------------------------------------------------------------------------
-- v0.22.91 (Session C part 2): EMERGENCY PRAYER consumer. The engine
-- carries a native no-rescuer assist: setting force_assist on the
-- assisted_state_input component makes the Assist utility complete a
-- fast self-rescue with no interactor (assist.lua line 189,
-- CharacterStateAssistSettings.force_assist_duration). When the local
-- player hits knocked_down with the SKU active, we set the flag once,
-- consume the purchase, and latch until the state is left so a single
-- down never double-consumes. Host-authority component write.

local _prayer_latched = false

-- v0.22.96: the aura engine's pump. Passives module owns all logic;
-- this gates it to live run missions and clears lingering aura buffs
-- on the way out. READS + buff add/remove only, no run_state writes.
Tick.register("aura_engine", 1, function()
	local Passives = modules and modules.Passives
	if not Passives or not Passives.update_auras then return end
	local Shared = modules and modules.Shared
	if not Shared or Shared.is_in_hub() or not RunState.is_active() then
		pcall(Passives.reset_auras)
		return
	end
	pcall(Passives.update_auras)
end)

Tick.register("emergency_prayer", 0.5, function()
	local Shared = modules and modules.Shared
	local Shop = modules and modules.Shop
	if not Shared or Shared.is_in_hub() then return end
	if not RunState.is_active() then return end
	if not Shop or not Shop.is_active then return end

	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	if not unit then return end

	local ok_ud, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")
	if not ok_ud or not unit_data then return end
	local ok_cs, character_state = pcall(unit_data.read_component, unit_data, "character_state")
	if not ok_cs or not character_state then return end

	local state_name = character_state.state_name
	if state_name ~= "knocked_down" then
		_prayer_latched = false
		return
	end
	if _prayer_latched then return end

	local ok_active, active = pcall(Shop.is_active, "auto_revive")
	if not ok_active or not active then return end

	local ok_w, assisted = pcall(unit_data.write_component, unit_data, "assisted_state_input")
	if not ok_w or not assisted then return end

	assisted.force_assist = true
	_prayer_latched = true
	pcall(Shop.consume, "auto_revive")
	if Shared and Shared.notify then
		pcall(Shared.notify, "Emergency Prayer answered. The Emperor protects.", "default")
	end
	_debug_log("prayer", 0, "emergency prayer fired (force_assist set)", 0, "info")
end)

-- v0.22.85: one slow tick owns the boon reconciler
-- (Boons.ensure_applied re-offers anything a run should have; grant()
-- dedupes, so a healthy state costs one table walk). It heals the
-- ordering hole where apply_all fired before the run was active or
-- before the loadout extension could answer the blitz gate. READS
-- ONLY, no run_state writes (2-second-freeze lesson). v0.22.87: also
-- drives the channel-flag patch state machine (right profile this
-- time; see _up_patch_channel_flag).
Tick.register("up_lockdown", 1, function()
	local ok_live, live = pcall(_up_boon_live)
	if not ok_live then live = false end
	_up_patch_channel_flag(live and true or false)

	local Shared = modules and modules.Shared
	if not Shared or Shared.is_in_hub() then return end
	if not RunState.is_active() then return end
	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	local Boons = modules and modules.Boons
	if unit and Boons and Boons.ensure_applied then
		pcall(Boons.ensure_applied, unit)
	end
end)

-- v0.22.85: field diagnostic for Unlimited Power. Every gate and both
-- effect channels in one line, so "it does nothing" becomes a specific
-- broken link instead of a guess.
mod:command("pil_up_probe", "Pilgrimage: Unlimited Power diagnostic", function()
	local out = {}
	local Boons = modules and modules.Boons
	local state = RunState.get()
	out[#out + 1] = "unlocked=" .. tostring(Boons and Boons.is_legendary_unlocked
		and Boons.is_legendary_unlocked("pilgrim_boon_unlimited_power") or false)
	out[#out + 1] = "selected=" .. tostring(Boons and Boons.legendary_slot
		and Boons.legendary_slot() == "pilgrim_boon_unlimited_power" or false)
	out[#out + 1] = "run_legendary=" .. tostring(Boons and Boons.active_legendary
		and Boons.active_legendary() or "none")
	out[#out + 1] = "run_active=" .. tostring(RunState.is_active())
	out[#out + 1] = "archetype=" .. tostring(state.stat_archetype or "?")

	local ok_bt, buff_templates = pcall(require, "scripts/settings/buff/buff_templates")
	out[#out + 1] = "template_registered=" .. tostring(ok_bt
		and type(buff_templates) == "table"
		and buff_templates.pilgrim_boon_unlimited_power ~= nil)

	local player = Managers.player and Managers.player:local_player_safe(1)
	local unit = player and player.player_unit
	if unit then
		out[#out + 1] = "blitz=" .. tostring(Boons and Boons.blitz_template_name
			and Boons.blitz_template_name(unit) or "?")
		out[#out + 1] = "buff_applied=" .. tostring(Boons and Boons.applied
			and Boons.applied()["pilgrim_boon_unlimited_power"] ~= nil)
		local ok_ext, buff_ext = pcall(ScriptUnit.extension, unit, "buff_system")
		if ok_ext and buff_ext and type(buff_ext.stat_buffs) == "function" then
			local ok_sb, sb = pcall(buff_ext.stat_buffs, buff_ext)
			-- Aggregated multipliers, base 1 each. v0.22.87 healthy
			-- values while UP is live: damage 0.1, chain 50.9,
			-- smite 50.9 (they share one additive bucket at damage
			-- time: 1 - 0.9 + 49.9 = x50 on Smite, x0.1 elsewhere).
			out[#out + 1] = "stat_damage=" .. tostring(ok_sb and sb and sb.damage or "?")
			out[#out + 1] = "stat_chain=" .. tostring(ok_sb and sb and sb.chain_lightning_damage or "?")
			out[#out + 1] = "stat_smite=" .. tostring(ok_sb and sb and sb.smite_damage or "?")
		else
			out[#out + 1] = "stat_damage=no_buff_ext"
		end
	else
		out[#out + 1] = "no_player_unit"
	end

	-- v0.22.87: the channel-flag patch state (expect true while UP is
	-- live, false otherwise) and the corruptor bane set size (nonzero
	-- only near an active corruptor objective).
	out[#out + 1] = "channel_flag=" .. tostring(_up_channel_flagged)
	local corruptor_count = 0
	for _ in pairs(_corruptor_units) do corruptor_count = corruptor_count + 1 end
	out[#out + 1] = "corruptors_tracked=" .. tostring(corruptor_count)

	-- Informational: the real Smite channel tick profile's base attack
	-- power (vanilla 20; we do not touch it as of v0.22.86).
	local ok_dp, DamageProfileTemplates =
		pcall(require, "scripts/settings/damage/damage_profile_templates")
	local profile = ok_dp and type(DamageProfileTemplates) == "table"
		and DamageProfileTemplates.psyker_protectorate_channel_chain_lightning_activated
	out[#out + 1] = "channel_attack=" .. tostring(profile
		and profile.power_distribution and profile.power_distribution.attack or "?")

	mod:echo("UP probe: " .. table.concat(out, "  "))
end)

Hooks.fanout("scripts/extension_systems/fx/player_unit_fx_extension", {
	{ "fx_guard_player", function(PlayerUnitFxExtension)
		modules.FxGuard.install_player_fx(PlayerUnitFxExtension)
	end },
	{ "melta_muzzle_audio", function(PlayerUnitFxExtension)
		modules.WeaponMelta.install_player_fx(PlayerUnitFxExtension)
	end },
})

Hooks.fanout("scripts/extension_systems/buff/player_unit_buff_extension", {
	{ "fx_guard_buff", function(PlayerUnitBuffExtension)
		modules.FxGuard.install_buff_extension(PlayerUnitBuffExtension)
	end },
})

-- Node effects (minion ailment visuals and buff auras): sanitised on the BASE
-- class so both the player and minion buff extensions inherit the guard.
Hooks.fanout("scripts/extension_systems/buff/buff_extension_base", {
	{ "fx_guard_buff_base", function(BuffExtensionBase)
		modules.FxGuard.install_buff_base(BuffExtensionBase)
		modules.MissionIncidents.observe_buff_pool(BuffExtensionBase)
	end },
})

-- Fire/shock application ordering lives on the minion extension, after the
-- target has accepted a real stack. This makes Flashover and Thermal Shock
-- work for weapons, talents, DoTs and Pilgrimage boons without guessing which
-- on_hit proc runs first.
Hooks.fanout("scripts/extension_systems/buff/minion_buff_extension", {
	{ "boons_family_ailments", function(MinionBuffExtension)
		modules.Boons.install_family_ailment_observer(MinionBuffExtension)
	end },
})

-- The telekine dome boon spawns the psyker's force-field UNIT; gated on unit
-- residency because spawning an unloaded unit faults like an unloaded
-- particle. The one boon whose gameplay (not just visuals) is affected.
Hooks.fanout("scripts/settings/buff/hordes_buffs/hordes_buffs_utilities", {
	{ "fx_guard_dome", function(HordesBuffsUtilities)
		modules.FxGuard.install_hordes_utilities(HordesBuffsUtilities)
	end },
})

-- The wallet's pickup-counting hook. PickupSystem:register_material_collected
-- is what small/large_metal_pickup and small/large_platinum_pickup all call
-- when the player picks up plasteel or diamantine; hooking there gives us a
-- clean per-pickup callback with type + size, no unit inspection needed.
Hooks.fanout("scripts/extension_systems/pickups/pickup_system", {
	{ "wallet_pickups", function(PickupSystem)
		modules.Wallet.install_pickup_system(PickupSystem)
	end },
})

-- World markers live in tables on the HUD element instance, and the game rebuilds that
-- element while a level settles. Every rebuild silently deletes our terminal marker
-- while we still hold its id, which is why the icon was missing on a fresh boot and
-- only appeared after a mission. The terminal invalidates its id whenever a new
-- element is born and re-adds on the next tick.
Hooks.fanout(Terminal.WORLD_MARKERS_PATH, {
	{ "terminal_markers", function(HudElementWorldMarkers) Terminal.install(HudElementWorldMarkers) end },
})

-- ---------------------------------------------------------------------------
-- UI registration
--
-- Both of these are constructed by the GAME, not by us, which is why neither gets its
-- dependencies injected the way every module does. They reach back through the mod
-- object for one narrow, purpose-built accessor each:
--
--     mod.pilgrimage_terminal_prompt   set by terminal.lua, read by the HUD element
--     mod.pilgrimage_route_api         set by bootstrap, read by the route view
--
-- Registering them here rather than inside their own files keeps every "the game will
-- call this" entry point in one file, same as the engine hooks above.
-- ---------------------------------------------------------------------------

-- The proximity prompt. visibility_groups "alive" means it draws during normal play and
-- hides in the places the rest of the HUD hides, so we inherit the correct behaviour
-- during cutscenes and menus instead of reimplementing it.
mod:register_hud_element({
	class_name = "PilgrimageTerminalHud",
	filename   = "Pilgrimage/scripts/mods/Pilgrimage/terminal_hud",
	visibility_groups = { "alive" },
	use_hud_scale = true,
})

-- The tactical overlay panel: assignment, live conditions, what comes next,
-- top-right corner while TAB is held. "tactical_overlay" is the game's own
-- visibility group for the overlay (hud_visibility_groups.lua:79), so the
-- panel appears and vanishes in step with the vanilla overlay with no input
-- handling of ours. use_hud_scale false to share the overlay's coordinate
-- space; the placement is measured against ITS scenegraph, not the HUD's.
mod:register_hud_element({
	class_name = "PilgrimageOverlayHud",
	filename   = "Pilgrimage/scripts/mods/Pilgrimage/overlay_hud",
	visibility_groups = { "tactical_overlay" },
	use_hud_scale = false,
})

-- The route view. The package line loads the shared UI materials our widgets reference:
-- without it the panel frames and button textures resolve to nothing and the view draws
-- as bare text. options_view is the usual choice because it pulls in the common terminal
-- styling rather than anything specific to a particular menu.
-- WITHOUT THIS THE GAME HARD CRASHES, and it is not obvious why.
--
-- UIViewHandler loads a view with a plain require(view_settings.path). DMF hooks require,
-- but its hook only redirects to io_dofile for paths registered here
-- (dmf/modules/core/require.lua:63). Anything else goes to the engine's require, which
-- resolves against the game's compiled bundles, where a mod file does not exist.
--
-- The failure is nasty because the handler registers the view as ACTIVE before it
-- constructs it, so a throw leaves an active view with a nil instance, and the next
-- frame's hotkey check dereferences it with no nil guard. The crash surfaces in vanilla
-- UI code with nothing pointing back here.
mod:add_require_path("Pilgrimage/scripts/mods/Pilgrimage/route_view")
mod:add_require_path("Pilgrimage/scripts/mods/Pilgrimage/route_view_definitions")

mod:register_view({
	view_name = "pilgrimage_route_view",
	view_settings = {
		init_view_function = function() return true end,
		class             = "PilgrimageRouteView",
		path              = "Pilgrimage/scripts/mods/Pilgrimage/route_view",
		package           = "packages/ui/views/options_view/options_view",

		display_name      = "Pilgrimage",

		-- false means the world keeps rendering behind the view. The terminal is a thing
		-- in the Mourningstar and it should still feel like you are standing at it.
		disable_game_world = false,
		game_world_blur    = 0.6,

		-- Loaded EVERYWHERE, because the boon draft is offered a few seconds into each
		-- leg, not only at the terminal. A view that is hub-only simply does not open in
		-- a mission, and it fails quietly rather than erroring, which would have made
		-- this very annoying to diagnose.
		load_always = true,
		load_in_hub = true,

		-- state_bound false means the view is not torn down by a game state change on
		-- its own. We close it explicitly.
		state_bound = false,

		enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
		exit_sound_events  = { "wwise/events/ui/play_ui_back_short" },

		scenegraph_definition = RouteViewDefinitions.scenegraph_definition,
		widget_definitions    = RouteViewDefinitions.widget_definitions,
	},
	view_transitions = {},
	view_options = {
		close_all      = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

-- ---------------------------------------------------------------------------
-- DMF lifecycle callbacks
-- ---------------------------------------------------------------------------

-- v0.23.0: NPC Look runtime bridge. Installs Pilgrimage's five
-- npclook_* API functions onto a VANILLA NPC Look at runtime (in
-- memory, via upvalue harvesting), so public installs do not need the
-- hand-patched NPCLook.lua the dev install carries. Steps aside
-- automatically when the API already exists (patched copy today, the
-- author's official version once upstreamed). Failure degrades to the
-- normal no-NPCLook behaviour: bots in base gear.
local NPCLookBridge = mod:io_dofile(ROOT .. "npclook_bridge")

-- ---------------------------------------------------------------------------
-- v0.23.6 (Kaizen correction of v0.23.5): CHANGE OPERATIVE lives in the
-- ESC MENU, not the terminal. The game already HAS the button: the escape
-- menu's change-character entry (icon .../escape/change_character, text
-- loc_exit_to_main_menu_display_name) jumps to character select via
-- multiplayer_session:leave("exit_to_main_menu"), behind the game's own
-- confirm popup. Vanilla's validation_function only shows it in the hub,
-- onboarding and training grounds (system_view_content_list.lua). This
-- wraps that validation IN PLACE so the entry ALSO shows during a mission
-- while a pilgrimage run is active. Everything else stays Fatshark's:
-- their button, their icon, their popup, their leave flow.
--
-- Why it is safe and live: SystemView re-runs every entry's
-- validation_function each update and rebuilds the list when an answer
-- changes (system_view.lua line 229), so the entry appears the moment the
-- wrapped validation starts saying yes, no reload needed. require()
-- returns the game's cached content-list table, so mutating the entry
-- mutates what the view reads. RUN SAFETY is the same as everywhere else:
-- chain.lua only records a leg result from the end-conditions event, and
-- leaving fires none, so the run stays parked on the current leg and
-- Continue relaunches it after the operative change.
-- ---------------------------------------------------------------------------
local function _install_escape_menu_operative_entry()
	local ok_cl, ContentList = pcall(require,
		"scripts/ui/views/system_view/system_view_content_list")
	if not ok_cl or type(ContentList) ~= "table"
		or type(ContentList.default) ~= "table" then
		return false, "content list unavailable"
	end
	for i = 1, #ContentList.default do
		local entry = ContentList.default[i]
		if type(entry) == "table"
			and entry.text == "loc_exit_to_main_menu_display_name"
			and type(entry.validation_function) == "function" then
			if entry._pilgrimage_wrapped then return true, "already" end
			local original_validation = entry.validation_function
			local original_trigger = entry.trigger_function
			entry._pilgrimage_wrapped = true
			if type(original_trigger) == "function" then
				entry.trigger_function = function(...)
					-- Changing operative also tears down the active mission without
					-- set_last_mission. Arm the same native terminal return used by
					-- the Leave Mission button before showing Fatshark's popup.
					if Terminal and type(Terminal.arm_return_spawn) == "function" then
						pcall(Terminal.arm_return_spawn)
					end
					return original_trigger(...)
				end
			end
			entry.validation_function = function()
				local can_show, is_disabled = original_validation()
				-- Vanilla already shows it (hub, onboarding, training
				-- grounds): change nothing.
				if can_show then return can_show, is_disabled end
				-- Our addition: a mission leg of an active pilgrimage.
				local ok_r, active = pcall(RunState.is_active)
				if not ok_r or not active then return can_show, is_disabled end
				local gm = Managers.state and Managers.state.game_mode
				if not gm then return can_show, is_disabled end
				local ok_n, name = pcall(gm.game_mode_name, gm)
				if not ok_n or name == "hub" or name == "prologue_hub" then
					return can_show, is_disabled
				end
				-- Mirror vanilla's own disabled conditions (mid-teardown;
				-- matchmaking never applies to a solo run but the check is
				-- kept for symmetry and guarded).
				local disabled = false
				local ok_s, state = pcall(gm.game_mode_state, gm)
				if ok_s and state == "leaving_game" then disabled = true end
				return true, disabled
			end
			return true, "wrapped"
		end
	end
	return false, "entry not found in content list"
end

mod.on_all_mods_loaded = function()
	local guard_ok, _, guard_detail = pcall(modules.EWCShootGuard.refresh)
	if not guard_ok then mod:warning("EWC shoot guard could not initialize")
	else mod:info("EWC shoot guard: %s", tostring(guard_detail)) end
	_refresh_log_level()
	_debug_log("boot", 0, "loaded v" .. mod.version, 0, "info")
	if RealmsBridge then
		local call_ok, installed, detail = pcall(RealmsBridge.try_install)
		local result = call_ok and tostring(detail or installed)
			or ("error: " .. tostring(installed))
		_debug_log("realms_bridge", 0, "Realms bridge: " .. result, 0,
			(call_ok and (installed or detail == "Realms not installed"))
				and "info" or "warn")
	end
	if EWCOwnedContent then
		local call_ok, installed, detail = pcall(EWCOwnedContent.try_install_effects)
		_debug_log("ewc_owned_content", 0,
			"owned EWC effects: " .. tostring(call_ok and detail or installed),
			0, call_ok and "info" or "warn")
	end
	if WeaponVisuals then
		local call_ok, bridge_ok, detail = pcall(WeaponVisuals.try_install)
		local result = call_ok and tostring(detail)
			or ("error: " .. tostring(bridge_ok))
		_debug_log("weapon_visuals", 0,
			"weapon visual bridge: " .. result, 0,
			(call_ok and (bridge_ok
				or detail == "Extended Weapon Customization not installed"))
				and "info" or "warn")
	end
	if NPCLookBridge then
		-- try_install returns (bridge_ok, detail); pcall prepends its own
		-- execution status. Keep all three values or a successful native
		-- bridge is misread as detail=true and reported as inactive.
		local call_ok, bridge_ok, detail = pcall(NPCLookBridge.try_install)
		local result
		if not call_ok then
			result = "error: " .. tostring(bridge_ok)
		elseif bridge_ok then
			result = tostring(detail)
		else
			result = "inactive: " .. tostring(detail)
		end
		_debug_log("npclook_bridge", 0, "npclook bridge: " .. result, 0, "info")
		-- A hard failure is worth a visible one-time notification: the
		-- user installed NPC Look expecting bot outfits and would
		-- otherwise silently not get them.
		if (not call_ok) or (not bridge_ok and detail ~= "NPC Look not installed") then
			Shared.notify("Pilgrimage: NPC Look bridge inactive (" .. result
				.. "); bots will use default gear", "alert")
		end
	end
	-- v0.23.6: ESC-menu change-operative entry. Failure is logged, not
	-- fatal: the game plays identically without it, minus the shortcut.
	local ok_e, why = _install_escape_menu_operative_entry()
	_debug_log("escape_menu", 0, "change-operative entry: "
		.. tostring(why) .. (ok_e and "" or " (INACTIVE)"), 0, ok_e and "info" or "warn")
end

-- ---------------------------------------------------------------------------
-- v0.24.1 CRASH GUARD (FB-5, user report GUID 29e6f071, repeatable):
-- MutatorModifyHavoc.init calls game_mode():extension("havoc"):
-- init_horde_buff(), and the "havoc" extension exists ONLY in the Havoc
-- game mode, so any normal mission whose circumstance carries such a
-- mutator dies at load with "attempt to index a nil value"
-- (mutator_modify_havoc.lua:11). The primary fix lives in curses.lua
-- (Shambling Pyres repointed to a safe custom mutator, and the stacked
-- union swaps the lethal mutator for runs already in flight). This
-- guard is the LAST layer: runs with curse stacking OFF still launch
-- raw vanilla circumstances we cannot rewrite, and future borrowed
-- circumstances may hide the same class. The class file is required
-- lazily by the mutator manager, so hook_require is the right seam
-- (CLASS.MutatorModifyHavoc may not exist at mod load). Real Havoc
-- missions are untouched: there the extension resolves and the pcall
-- succeeds identically to vanilla.
-- ---------------------------------------------------------------------------
mod:hook_require("scripts/managers/mutator/mutators/mutator_modify_havoc",
	function(MutatorModifyHavoc)
		if type(MutatorModifyHavoc) ~= "table" then return end
		if MutatorModifyHavoc.__pilgrimage_guarded then return end
		MutatorModifyHavoc.__pilgrimage_guarded = true
		local original_init = MutatorModifyHavoc.init
		MutatorModifyHavoc.init = function(self, is_server, network_event_delegate,
				mutator_template, nav_world, world, level_seed)
			local ok, err = pcall(original_init, self, is_server, network_event_delegate,
				mutator_template, nav_world, world, level_seed)
			if not ok then
				-- The original errors AFTER its super.init line only when
				-- the havoc extension is missing; re-run base init so the
				-- object is complete, then continue with the mutator inert.
				pcall(function()
					MutatorModifyHavoc.super.init(self, is_server, network_event_delegate,
						mutator_template, nav_world, world, level_seed)
				end)
				_debug_log("mutator_guard", 0,
					"MutatorModifyHavoc init survived outside Havoc (" .. tostring(err) .. ")",
					0, "warn")
			end
		end
	end)

-- v0.23.0 CRASH FIX (Kaizen field crash 2026-08-11, opening the
-- tactical overlay): hud_element_tactical_overlay._add_player_buffs
-- looks every buff whose template carries buff_category "hordes_buff"
-- up in HordesBuffsData and indexes the result WITHOUT a nil guard on
-- the first read (line 372, buff_data.is_family_buff). Pilgrimage's
-- custom boon/passive templates use that category so they render on the
-- hordes buff HUD, but their names naturally have no entry in
-- Fatshark's data table, so opening the overlay with any such buff on a
-- unit crashed to desktop (the v0.22.96 aura batch put the first such
-- buffs on the PLAYER, which is why this only surfaced now; the
-- skip_tactical_overlay template flag is checked too late in the
-- overlay code to help). Fix: register a minimal entry per custom
-- template, the exact placeholder shape Fatshark itself ships for
-- hordes_buff_damage_immunity_after_game_end. Level loads rebuild the
-- Lua VM and its tables, and this file re-runs with them; the latched
-- tick retries until the Passives templates are registered, then stops.
-- v0.23.2 (Kaizen beta-day report): the v0.23.0 minimal entries fixed
-- the crash but rendered as raw template names plus the engine's
-- '<unlocalized "">' complaint in the hordes buff panel (empty title
-- shows buff_name; empty description goes through the localizer and
-- misses). Entries now carry REAL loc keys, with the strings served
-- through DMF's add_global_localize_strings: DMF hooks
-- CLASS.LocalizationManager.localize and the global Localize is a
-- closure over that same method (localization_manager.lua line 124),
-- so both the buff panel and the tactical overlay resolve them. Boon
-- titles/descriptions come from the Boons catalogue; passive templates
-- get a prettified name. Percent signs are doubled because DMF runs
-- every localized string through string.format.
local function _pretty_buff_name(name)
	local text = tostring(name)
		:gsub("^pilgrim_boon_", ""):gsub("^pilgrim_", ""):gsub("_", " ")
	return (text:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local function _format_safe(text)
	return (tostring(text or ""):gsub("%%", "%%%%"))
end

local _hordes_ui_synced = false
Tick.register("hordes_ui_sync", 5, function()
	if _hordes_ui_synced then return end
	local ok_bt, buff_templates = pcall(require, "scripts/settings/buff/buff_templates")
	local ok_hd, hordes_data = pcall(require, "scripts/settings/buff/hordes_buffs/hordes_buffs_data")
	if not ok_bt or type(buff_templates) ~= "table" then return end
	if not ok_hd or type(hordes_data) ~= "table" then return end

	-- buff_template name -> catalogue entry, for proper boon display.
	local display_by_template = {}
	local Boons = modules and modules.Boons
	if Boons and Boons.custom_all then
		local ok_c, customs = pcall(Boons.custom_all)
		if ok_c and type(customs) == "table" then
			for i = 1, #customs do
				local c = customs[i]
				if type(c) == "table" and type(c.buff_template) == "string" then
					display_by_template[c.buff_template] = c
				end
			end
		end
	end
	-- v0.24.0: archetype packages display with their catalogue names in
	-- the hordes buff panel and tactical overlay, same as Doctrines.
	if Boons and Boons.archetype_all then
		local ok_a, archs = pcall(Boons.archetype_all)
		if ok_a and type(archs) == "table" then
			for i = 1, #archs do
				local a = archs[i]
				if type(a) == "table" and type(a.buff_template) == "string" then
					display_by_template[a.buff_template] = a
				end
			end
		end
	end
	-- v0.28.5: family boons are custom templates too. Including them here
	-- gives the tactical overlay the authored title and short description,
	-- rather than its generic signature-effect fallback.
	if Boons and Boons.family_all then
		local ok_f, families = pcall(Boons.family_all)
		if ok_f and type(families) == "table" then
			for i = 1, #families do
				local family = families[i]
				if type(family) == "table" and type(family.buff_template) == "string" then
					display_by_template[family.buff_template] = family
				end
			end
		end
	end

	local found_any_pilgrim = false
	local added = 0
	for name, template in pairs(buff_templates) do
		if type(name) == "string" and name:find("pilgrim", 1, true) == 1
			and type(template) == "table" then
			found_any_pilgrim = true
			if template.buff_category == "hordes_buff" and hordes_data[name] == nil then
				local catalogue = display_by_template[name]
				local title_text = (catalogue and catalogue.name) or _pretty_buff_name(name)
				local desc_text = (catalogue and catalogue.description)
					or "A Pilgrimage signature effect."
				local title_key = "loc_" .. name .. "_title"
				local desc_key = "loc_" .. name .. "_description"
				pcall(mod.add_global_localize_strings, mod, {
					[title_key] = { en = _format_safe(title_text) },
					[desc_key] = { en = _format_safe(desc_text) },
				})
				hordes_data[name] = {
					name = name,
					title = title_key,
					description = desc_key,
					icon = template.hud_icon or "",
					is_family_buff = false,
				}
				added = added + 1
			end
		end
	end
	-- Latch only once our templates are visible, so a run before the
	-- Passives injection simply retries on the next tick.
	if found_any_pilgrim then
		_hordes_ui_synced = true
		if added > 0 then
			_debug_log("hordes_ui_sync", 0, "registered " .. added
				.. " HordesBuffsData entries with localized display", 0, "info")
		end
	end
end)

-- v0.23.0: diagnostics toggle without needing the options screen (the
-- widget also exists in Pilgrimage_data, but a chat command survives
-- data-file drift and works mid-session).
mod:command("pil_diagnostics", "Pilgrimage: toggle diagnostic file logging (on/off)", function(arg)
	local turn_on
	if arg == "on" then turn_on = true
	elseif arg == "off" then turn_on = false
	else
		local ok_g, v = pcall(mod.get, mod, "diagnostics_enabled")
		Shared.notify("Pilgrimage diagnostics: "
			.. (((ok_g and v == true) and "ON") or "OFF")
			.. " (use /pil_diagnostics on|off)")
		return
	end
	pcall(mod.set, mod, "diagnostics_enabled", turn_on, false)
	Shared.notify("Pilgrimage diagnostics " .. (turn_on and "ON" or "OFF"))
end)

-- v0.26.1: reversible test access. These commands change one override flag;
-- they never write ownership, legendary unlocks, penance completion, or shop
-- purchases, so turning the flag off restores the player's real progression.
mod:command("pil_test_unlock_all", "Pilgrimage: temporarily unlock all test content", function()
	local Boons = modules and modules.Boons
	if not Boons or not Boons.set_test_unlocks then return end
	local ok, why = Boons.set_test_unlocks(true)
	if ok then
		Shared.notify("Pilgrimage test access ON: all Doctrines, Legendaries, Archetypes and 4 slots available. Progression is unchanged.")
	else
		Shared.notify("Could not enable test access: " .. tostring(why or "unknown"))
	end
end)

mod:command("pil_test_unlock_reset", "Pilgrimage: restore normal progression locks", function()
	local Boons = modules and modules.Boons
	if not Boons or not Boons.set_test_unlocks then return end
	local ok, why = Boons.set_test_unlocks(false)
	if ok then
		Shared.notify("Pilgrimage test access OFF. Normal progression restored.")
	else
		Shared.notify("Could not disable test access: " .. tostring(why or "unknown"))
	end
end)

mod:command("pil_test_unlock_status", "Pilgrimage: show temporary test-access state", function()
	local Boons = modules and modules.Boons
	local enabled = Boons and Boons.test_unlocks_enabled and Boons.test_unlocks_enabled()
	Shared.notify("Pilgrimage test access: " .. (enabled and "ON" or "OFF"))
end)

mod:command("pil_npclook_bridge", "Pilgrimage: NPC Look bridge status", function()
	if not NPCLookBridge then
		Shared.notify("NPC Look bridge module not loaded")
		return
	end
	-- Safe to re-run: try_install is idempotent (native/already short-
	-- circuit before any work).
	local call_ok, bridge_ok, detail = pcall(NPCLookBridge.try_install)
	local st = NPCLookBridge.status() or {}
	local result
	if not call_ok then
		result = "error: " .. tostring(bridge_ok)
	elseif bridge_ok then
		result = tostring(detail)
	else
		result = "inactive: " .. tostring(detail)
	end
	Shared.notify(string.format("NPC Look bridge: %s (state=%s%s%s%s%s)",
		result,
		tostring(st.state),
		st.api and (", api=" .. tostring(st.api)) or "",
		st.visibility and (", visibility=" .. tostring(st.visibility)) or "",
		st.teardown and (", teardown=" .. tostring(st.teardown)) or "",
		st.scanned and (", scanned=" .. tostring(st.scanned)) or "",
		st.reason and (", " .. tostring(st.reason)) or ""))
end)

mod:command("pil_nav_guard", "Pilgrimage: Better Bots navigation bridge status", function()
	Shared.notify("Better Bots navigation bridge: " .. BetterBotsBridge.summary())
end)

-- ---------------------------------------------------------------------------
-- v0.23.4: NOTIFICATION TRACER (Kaizen field report, 2026-08-11).
--
-- An empty RED popup flashes at launch. Red means message_type "alert", and
-- an alert renders data.text; empty red therefore means someone fired an
-- alert with a nil or empty text. It is NOT Pilgrimage's own path: since
-- v0.22.16 Shared.notify substitutes a visible placeholder ("Pilgrimage:
-- (empty notification, please report)") for empty messages, and an audit
-- found no notification call in this mod that bypasses Shared.notify.
--
-- So this observes EVERY notification entering the game's feed and, while
-- diagnostics are on, writes who sent what to notify_diag.txt, including a
-- Lua traceback. The traceback names the calling file, which names the mod.
-- hook_safe observes without altering behaviour; caps keep the file small.
-- ---------------------------------------------------------------------------
local NOTIFY_DIAG_PATH = "./../mods/Pilgrimage/notify_diag.txt"
local NOTIFY_DIAG_CAP = 60
local _notify_diag_count = 0

-- Same append-only file shape as _ff_diag_raw, different file, so the
-- notification trace never interleaves with the FF hunt's readout.
local function _notify_diag_write(text)
	local Mods = rawget(_G, "Mods")
	local io_l = Mods and Mods.lua and Mods.lua.io
	local os_l = Mods and Mods.lua and Mods.lua.os
	if not io_l then return false end
	local timestamp = "?"
	if os_l and os_l.date then
		local ok_t, txt = pcall(os_l.date, "%Y-%m-%d %H:%M:%S")
		if ok_t and txt then timestamp = txt end
	end
	local ok = pcall(function()
		local file = io_l.open(NOTIFY_DIAG_PATH, "a")
		if file then
			file:write("[" .. timestamp .. "] " .. text .. "\n")
			file:close()
		end
	end)
	return ok
end

local function _notify_diag_describe(data)
	if type(data) == "string" then
		return string.format("string %q", data)
	end
	if type(data) ~= "table" then
		return type(data) .. " " .. tostring(data)
	end
	-- Alerts carry data.text; other types vary. Report the fields that
	-- decide what the player sees, plus a shallow key list for the rest.
	local parts = {}
	if data.text ~= nil then
		parts[#parts + 1] = string.format("text=%q", tostring(data.text))
	end
	if data.texts ~= nil then
		parts[#parts + 1] = "texts=" .. tostring(#data.texts) .. " entries"
	end
	local keys = {}
	for k in pairs(data) do
		keys[#keys + 1] = tostring(k)
		if #keys >= 8 then break end
	end
	parts[#parts + 1] = "keys={" .. table.concat(keys, ",") .. "}"
	return "table " .. table.concat(parts, " ")
end

if rawget(_G, "CLASS") and CLASS.ConstantElementNotificationFeed then
	mod:hook_safe(CLASS.ConstantElementNotificationFeed, "event_add_notification_message",
		function(self, message_type, data, callback, sound_event, done_callback, delay)
			if not _diagnostics_enabled() then return end
			if _notify_diag_count >= NOTIFY_DIAG_CAP then return end
			_notify_diag_count = _notify_diag_count + 1
			local line = "notify type=" .. tostring(message_type)
				.. " " .. _notify_diag_describe(data)
			-- The traceback is the payload: its topmost non-engine frame
			-- names the file (and so the mod) that fired the notification.
			local tb = "traceback unavailable"
			local Mods = rawget(_G, "Mods")
			local dbg = (Mods and Mods.lua and Mods.lua.debug) or rawget(_G, "debug")
			if dbg and dbg.traceback then
				local ok_tb, txt = pcall(dbg.traceback, "", 2)
				if ok_tb and txt then tb = txt end
			end
			_notify_diag_write(line .. "\n" .. tb .. "\n----")
		end)
end

-- ---------------------------------------------------------------------------
-- v0.23.4: /pil_seed (Kaizen settings audit). The old fixed-seed UI was a
-- ten-digit SLIDER, which was, in Kaizen's words, sadistic. The widgets are
-- gone from the options screen; typing the seed in chat replaces them.
--   /pil_seed            show the current state (fixed seed or free roll)
--   /pil_seed <number>   pin every future route preview to that seed
--   /pil_seed off        back to random seeds
-- The pinned seed is stored in the same run_seeded/run_seed settings the
-- slider used (Settings.run_seeded/configured_seed still read them), and the
-- route preview machinery in bootstrap consults them before its own
-- persisted preview seed, so the terminal shows the pinned route at once.
-- ---------------------------------------------------------------------------
mod:command("pil_seed", "Pilgrimage: pin the run seed (number | off | empty shows)", function(arg)
	if arg == nil or arg == "" then
		local fixed = mod:get("run_seeded") == true
		local seed = tonumber(mod:get("run_seed")) or 0
		if fixed and seed > 0 then
			Shared.notify("Pilgrimage seed pinned to " .. tostring(seed)
				.. " (use /pil_seed off to unpin)")
		else
			Shared.notify("Pilgrimage seed: random (use /pil_seed <number> to pin one)")
		end
		return
	end
	if arg == "off" then
		mod:set("run_seeded", false, false)
		Shared.notify("Pilgrimage seed unpinned, routes roll randomly again")
		return
	end
	local n = tonumber(arg)
	-- Whole positive number, capped to the same 2^31-2 bound the old
	-- slider enforced, so downstream 32-bit seed math never overflows.
	if not n or n < 1 or n ~= math.floor(n) or n > 2147483646 then
		Shared.notify("Pilgrimage: /pil_seed wants a whole number between 1 and 2147483646, or 'off'", "alert")
		return
	end
	mod:set("run_seed", n, false)
	mod:set("run_seeded", true, false)
	-- Also stamp the preview-seed slot so a terminal already showing a
	-- route flips to the pinned one on next open without a Reroll.
	mod:set("_preview_seed", n, false)
	Shared.notify("Pilgrimage seed pinned to " .. tostring(n)
		.. ". The Route tab will preview this exact road.")
end)

-- Called every frame by DMF. The only per-frame entry point in the mod; everything
-- else registers a task with the tick scheduler.
mod.update = function(dt)
	modules.MissionIncidents.update(dt)
	local t = Shared.fixed_time()
	Tick.update(t, dt)
	Boons.update(t)
	modules.WeaponOgrynHeavy.update(t)
end

-- v0.22.31: keybind handler. Bound in Pilgrimage_data.lua via the
-- `capture_all_keybind` widget with function_name pointing here. Reads
-- the `capture_target_preset` setting to know which preset to capture
-- INTO (a keybind can't take arguments, and asking every session would
-- be worse), then does the same work as /pil_preset_capture_all:
--   1. read the currently-selected character_id (Preset.selected_character_id)
--   2. bind that character to the preset (set_source_character)
--   3. pack + store the full profile (capture_profile_for)
--   4. snapshot the live NPC Look and store it (capture_current_look_for)
-- Any failure notifies with a specific reason instead of silent no-op,
-- because a keybind press that does nothing looks like a broken bind.
-- v0.23.3 (FB-3): terminal-open keybind, unbound by default. Bound in
-- Pilgrimage_data.lua via the terminal_keybind widget. Terminal.open()
-- carries its own preflight, input-claim guard and failure reporting
-- (terminal_error.txt), so this handler only needs to exist and be safe
-- to call from any game state.
mod.pilgrimage_terminal_hotkey = function()
	local Terminal = modules and modules.Terminal
	if not Terminal or type(Terminal.open) ~= "function" then
		Shared.notify("Pilgrimage: terminal module not ready", "alert")
		return
	end
	local ok, opened, reason = pcall(Terminal.open)
	if not ok then
		Shared.notify("Pilgrimage: terminal open failed, " .. tostring(opened), "alert")
	elseif opened == false and reason then
		-- input_is_claimed etc.; quiet unless it is a real refusal worth
		-- knowing about. "input claimed" fires when a menu is already up,
		-- which a keybind press in a menu naturally hits; stay silent.
		if reason ~= "input claimed" then
			Shared.notify("Pilgrimage: terminal did not open (" .. tostring(reason) .. ")")
		end
	end
end

mod.pilgrimage_capture_all_hotkey = function()
	local preset_id = mod:get("capture_target_preset")
	if not preset_id or preset_id == "" or preset_id == "none" then
		Shared.notify(
			"Capture keybind: set a target preset in Mod Options -> Debug shortcuts first.",
			"alert")
		return
	end
	if not Preset.get or not Preset.get(preset_id) then
		Shared.notify("Capture keybind: unknown preset " .. tostring(preset_id), "alert")
		return
	end

	local char_id = Preset.selected_character_id and Preset.selected_character_id()
	if not char_id then
		Shared.notify(
			"Capture keybind: could not read selected character. Open Character Select first.",
			"alert")
		return
	end

	local ok_char, err_char = Preset.set_source_character(preset_id, char_id)
	if not ok_char then
		Shared.notify("Capture keybind: bind failed, " .. tostring(err_char), "alert")
		return
	end
	Preset.request_profile_fetch()

	local ok_prof, err_prof = Preset.capture_profile_for(preset_id, char_id)
	if not ok_prof then
		Shared.notify("Capture keybind: profile snapshot failed, " .. tostring(err_prof), "alert")
		-- keep going, look capture may still succeed
	end

	local extras = Preset.capture_optional_for(preset_id, char_id)

	local ok_look, err_look = Preset.capture_current_look_for(preset_id)
	if not ok_look then
		Shared.notify("Capture keybind: NPC Look snapshot failed, " .. tostring(err_look), "alert")
		return
	end

	local voice_text = extras.personality.ok and "personality" or "no PP"
	local ewc_text = extras.ewc.ok
		and (tostring(extras.ewc.count or 0) .. " EWC weapons") or "no EWC"
	local filter_value = extras.voice_filter and extras.voice_filter.value
	local filter_text = extras.voice_filter and extras.voice_filter.ok
		and ("Vox " .. tostring(filter_value and filter_value.key or "default"))
		or "Vox default"
	Shared.notify(string.format(
		"Captured %s: character, look, %s, %s, %s.",
		preset_id, voice_text, ewc_text, filter_text))
end

-- status is "enter" or "exit", state is a game state name such as "GameplayStateRun"
-- or "StateLoading".
mod.on_game_state_changed = function(status, state)
	if status == "enter" and state == "StateMainMenu" then
		modules.CharacterRuns.refresh("menu")
	elseif status == "enter" and state == "StateLoading" then
		modules.CharacterRuns.refresh("loading")
	elseif status == "enter" and state == "GameplayStateRun" then
		modules.CharacterRuns.refresh("entered")
	end
	-- v0.22.8: kick a profile fetch when the character-select-adjacent
	-- states enter, so preset.lua's ProfilesService:fetch_all_profiles
	-- hook can populate the profile cache used to substitute bot
	-- profiles. Tertium does the same thing at the same trigger.
	--
	-- v0.22.10: also reset the preset spawn counter on StateLoading
	-- enter. The Lua VM DOES survive across missions in current DMF
	-- (an old comment in preset.lua saying otherwise was wrong), so
	-- without an explicit reset the counter accumulates across
	-- missions and per-slot bindings past mission 1 stop matching.
	-- Also clears the per-mission "apply failed" dedupe set so a stale
	-- warning from the previous mission doesn't suppress a fresh one.
	if status == "enter" and (state == "StateLoading" or state == "StateMainMenu") then
		modules.MissionIncidents.reset()
		-- Direct weapon rebalance data has to be in place before player and bot
		-- weapon instances copy their private ammo tables during level loading.
		-- Every loading pass begins with a revert, so a crash or abandoned load
		-- cannot leak the prototype into a later ordinary mission.
		pcall(function()
			RunState.load()
			if state == "StateLoading" then
				WeaponRebalance.prepare_for_loading()
			else
				WeaponRebalance.revert()
			end
		end)
		pcall(function() Preset.request_profile_fetch() end)
		pcall(function() Preset.reset_spawn_counter() end)
		-- v0.22.28: push preset bot voices into Personality Picker so PP's
		-- own DialogueSystem.extensions_ready hook applies vo_profile +
		-- loads audio for each bot as its dialogue extension comes up.
		-- StateLoading fires BEFORE any bot's dialogue extension is
		-- initialized, so this is early enough. No-op if PP is not
		-- installed.
		pcall(function() Voices.sync_pp() end)
	end

	if status == "enter" and state == "GameplayStateRun" then
		-- EWC can register deferred shooting hooks after mod startup.
		-- Refresh once at mission entry, not in a recurring polling loop.
		modules.EWCShootGuard.refresh()
		BetterBotsBridge.reset()
		_refresh_log_level()

		Perf.enter_run()

		-- Fixed-frame time restarts from zero each mission, so every scheduled
		-- deadline in the tick list is now in the far future. Reset them.
		local t = Shared.fixed_time()
		Tick.reset(t)

		-- Clear the log throttle IN PLACE, not by reassigning the table. Other
		-- modules may hold a reference to this exact table as an upvalue, and
		-- reassigning would orphan every one of them. This applies to every shared
		-- table in the mod and it is the single easiest way to introduce a bug that
		-- looks like "the feature just stopped working".
		for key in pairs(_last_log_t_by_key) do
			_last_log_t_by_key[key] = nil
		end

		-- Re-read the run from settings. Anything the previous mission wrote is
		-- here; anything it held in Lua is gone.
		RunState.load()
		Chain.reset()
		pcall(function() WeaponRebalance.ensure_applied() end)

		-- Drop the terminal's unit handle and marker id. Both belong to the level we
		-- just left, and a stale unit handle passed to Unit.* is a hard engine fault
		-- rather than a Lua error we could catch.
		Terminal.teardown()

		-- New leg, so the draft is offered again. Without this the flag survives from the
		-- previous leg and the offer silently never appears.
		Boons.reset_leg()

		-- v0.17.3: force an immediate icons resolution pass on state entry
		-- rather than waiting up to a second for the next tick. Fixes the
		-- window where the player buff HUD shows placeholder hexagons for
		-- the first frames of a fresh mission after quit-and-relaunch. All
		-- three calls are idempotent; the tick still runs and keeps trying.
		pcall(function()
			modules.Icons.ensure()
			modules.Icons.ensure_custom()
			modules.Icons.patch_templates()
		end)

		-- v0.18.0: register the enemy attack-speed listener on the
		-- mission's fresh event manager. Reset first because the previous
		-- mission's registration flag is stale (event manager is gone with
		-- the previous VM).
		pcall(function()
			modules.ScalingHook.reset()
			modules.ScalingHook.ensure()
		end)

		EventLog.set_enabled(Settings.event_log_enabled())
		EventLog.start_session(t, {
			run_active = RunState.is_active(),
			run_summary = RunState.summary(),
		})

		-- The curse ground-truth banner. Shown HERE rather than from the guard
		-- hook, because the hook fires during gameplay init when the
		-- notification feed is not listening yet and a message would vanish.
		-- Only for legs of an active run, and only when the mission the guard
		-- observed is the mission the launcher recorded, so a hub load or a
		-- matchmade mission can never wear a pilgrimage banner.
		--
		-- v0.22.16: silenced the "curse active: X (N modifiers)" banner
		-- (it duplicated what the tactical overlay already shows) and the
		-- "0 modifiers" warning that was mostly cosmetic. The alert-level
		-- guard.note notification is preserved because it signals real
		-- misconfiguration (missing template, mutator manager not
		-- installed) that should still surface.
		local guard = MutatorGuard.last_report()
		local record = RunState.launch_record()
		if guard and record and guard.mission == record.mission and RunState.is_active() then
			if guard.note then
				Shared.notify("Pilgrimage: " .. guard.note, "alert")
			end
		end

		-- Only a recorded mission starts new mission statistics. Reading the
		-- saved run above remains unconditional, including in the hub.
		-- Queue these related writes in memory; DMF persists them together
		-- immediately after this state-change callback returns.
		pcall(function()
			if not RunState.is_active() then return end
			if Shared.is_in_hub() or Shared.is_in_psykhanium() then return end
			local mission_name = Shared.mission_name()
			local launch = RunState.launch_record()
			if not mission_name or not launch or launch.mission ~= mission_name then return end
			local Managers = rawget(_G, "Managers")
			local player_manager = Managers and Managers.player
			if not player_manager or type(player_manager.local_player_safe) ~= "function" then
				return
			end
			local ok_p, player = pcall(player_manager.local_player_safe, player_manager, 1)
			if not ok_p or not player then return end
			local ok_prof, profile = pcall(player.profile, player)
			if not ok_prof or type(profile) ~= "table" then return end
			local archetype = profile.archetype
			local archetype_name = type(archetype) == "table" and archetype.name or nil
			if type(archetype_name) == "string" and archetype_name ~= "" then
				RunState.set_archetype(archetype_name, true)
			end
			-- Reset per-mission counters against the mission we're
			-- about to play.
			RunState.mission_start_stats(mission_name, true)
			-- v0.22.79: record how many bots this mission fields (the
			-- spawn target: active slots minus None bindings). Maxed
			-- across the run by set_bots_slotted. This was NEVER wired
			-- before: stat_bots_slotted stayed 0, which made Solo
			-- Sacrament ("0 bots slotted") auto-earnable on any Fanatic+
			-- clear, and the new slot penances (Full Muster, The
			-- Emperor Sends Six) need the real number.
			local Bots = modules and modules.Bots
			if Bots and type(Bots.spawn_target) == "function" then
				local ok_target, target = pcall(Bots.spawn_target)
				if ok_target then
					RunState.set_bots_slotted(target, true)
				end
			end
		end)

		_debug_log("state:gameplay", t,
			"entered gameplay, " .. RunState.summary(), 0, "info")
	end

	-- Reset happens on ENTER, not on exit, because exit paths are unreliable: a
	-- crash, a disconnect or a forced return to the hub may never fire one.
	if status == "exit" and state == "GameplayStateRun" then
		if Perf.is_enabled() then
			local lines = Perf.format_report("Pilgrimage perf (mission):")
			for i = 1, #lines do mod:echo(lines[i]) end
		end
		EventLog.end_session(Shared.fixed_time())

		-- Weapon patches are run-scoped. Leaving them applied would leak modified
		-- damage into the next session, including a public one, which is exactly
		-- the failure mode the solo gate exists to prevent. The sole exception is
		-- the exact hub-to-Meat-Grinder launch we armed at its Launch button. That
		-- handoff is consumed here once; leaving the Grinder follows normal cleanup.
		Weapons.revert_all()
		if not WeaponRebalance.consume_prepared_transition() then
			WeaponRebalance.revert()
		end
	end
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "log_level" then
		_refresh_log_level()
	elseif setting_id == "enable_perf" then
		Perf.sync_setting()
	elseif setting_id == "enable_event_log" then
		EventLog.set_enabled(Settings.event_log_enabled())
	elseif setting_id == "cheat_mode" then
		-- v0.23.3 (FB-2): the toggle must announce its penance
		-- consequence both ways, or a forgotten cheat session reads
		-- as "penances are broken".
		local on = Settings.cheat_mode_enabled()
		Shared.notify(on
			and "Pilgrimage: CHEAT MODE ON. Penance earning is suspended."
			or "Pilgrimage: cheat mode off. Penance earning resumed.",
			on and "alert" or nil)
	elseif setting_id == "betterbots_navigation_guard" then
		BetterBotsBridge.reset()
		Shared.notify("Pilgrimage: Better Bots navigation guard " ..
			(Settings.betterbots_navigation_guard_enabled() and "enabled" or "disabled"))
	elseif setting_id == "custom_weapon_sounds" then
		modules.WeaponMelta.on_audio_settings_changed()
		modules.WeaponOgrynHeavy.on_audio_settings_changed()
	elseif setting_id == "custom_weapon_balancing"
		or setting_id == "custom_weapon_balancing_meat_grinder"
		or setting_id == "custom_weapon_visuals" then
		Shared.notify("Pilgrimage: custom weapon balancing settings updated. " ..
			"The change takes effect on the next Pilgrimage mission or Meat Grinder load.")
	end

	if RealmsBridge and (setting_id == "cheat_mode"
		or setting_id == "cheat_invulnerable"
		or setting_id == "cheat_one_shot"
		or setting_id == "custom_weapon_balancing"
		or setting_id == "custom_weapon_balancing_meat_grinder") then
		RealmsBridge.broadcast_rules_if_changed()
	end
end

mod.on_disabled = function()
	modules.EWCShootGuard.restore()
	EventLog.set_enabled(false)
	WeaponRebalance.revert()
	if Settings and Settings.clear_session_overrides then
		Settings.clear_session_overrides()
	end
end

mod.on_enabled = function()
	pcall(modules.EWCShootGuard.try_install)
	_refresh_log_level()
	EventLog.set_enabled(Settings.event_log_enabled())
end

-- ---------------------------------------------------------------------------
-- Hot-reload resurrection
--
-- File-scope code runs again on /reload. If we were mid-mission with logging on,
-- restore it rather than making the user leave and re-enter.
-- ---------------------------------------------------------------------------

if Shared.game_mode_name() and Settings.event_log_enabled() then
	EventLog.set_enabled(true)
	EventLog.start_session(Shared.fixed_time(), { reloaded = true })
end

return mod
