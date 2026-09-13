local mod = get_mod("no_more_overloads")

-- Keyword the game checks to suppress overload.
local BuffSettings = require("scripts/settings/buff/buff_settings")
local PSYCHIC_FORTRESS = BuffSettings.keywords.psychic_fortress
-- Empowered Psionics makes blitzes free (no peril, no overload) while active.
local EMPOWERED_GRENADE = BuffSettings.keywords.psyker_empowered_grenade

-- Peril is clamped to [0,1]. Direct actions only explode at the cap. Brain Rupture is different:
-- its target-LOCKED cast (sticky, or lock-on) auto-fires (use_power, unblockable), and the game
-- marks that fire safe when the peril at the LOCK moment is < the psyker extreme_threshold (0.97,
-- raised by peril-reduction talents via warp_charge_amount). So the mod blocks only the lock input
-- at/above that per-player threshold; a cast already locked below it stays safe and is NOT touched.
local PERIL_CAP = 0.999
local BRAIN_RUPTURE_EXTREME = 0.97
-- Small headroom below the per-player extreme threshold. The lock is re-checked against LIVE peril
-- in the input hook (peril climbs on the fixed frame between the render-frame update and the lock),
-- so this only needs to cover one fixed frame of climb, not the whole render/fixed gap.
local BRAIN_RUPTURE_HEADROOM = 0.003

-- Auto Fire Before Unsafe: fire a charging staff's charged shot this far below the block threshold,
-- so it lands (safely, since Peril is still < 1) instead of being blocked and quelled at the cap.
local AUTO_FIRE_MARGIN = 0.03
-- The charged-shot fire cannot start until the charge action has run this long (chain_time on the
-- fire transition, time-scaled). Auto Fire waits for it so the injected trigger actually STARTS the
-- shot rather than advancing the input parser one node deep with nothing to consume it (the strand).
-- p4 Trauma has no chain_time; gating it too only delays its auto-fire, never strands it.
local AUTO_FIRE_CHAIN_TIME = 0.5
-- Running-action names for a force staff's charge -- the node Auto Fire injects the fire from.
-- p1/p3/p4 use "action_charge", the p2 flame staff uses "action_charge_flame".
local STAFF_CHARGE_ACTIONS = { action_charge = true, action_charge_flame = true }
-- The charge action's fire-transition key per staff, probed to read its chain_time from the live
-- template: p2 trigger_charge_flame, p1 trigger_explosion, p3/p4 shoot_charged (p4's carries no
-- chain_time -- its fire is instant, so a sub-cap press is consumed sub-cap and stays safe).
local STAFF_FIRE_INPUTS = { "trigger_charge_flame", "trigger_explosion", "shoot_charged" }
-- Per-category overload cap. The Duelling Sword parry and the Force Sword fling are both
-- damage_target-style specials that explode from the Psyker extreme threshold (~0.97), not the
-- near-1.0 cap, so they block at 0.96. The Plasma Gun's fatal shot is the one fired at full
-- heat, so it blocks just under its own limit.
local CATEGORY_CAP = { force_sword = 0.96, duelling_sword = 0.96, plasma = 0.99 }
-- Plasma overheat is a separate, class-independent meter -- not Psyker Peril.
local OVERHEAT_CATEGORIES = { plasma = true }

-- Overload immunity (psychic_fortress) is server-synced and lags the client by up to
-- ~RTT, so the block engages this base lead plus the measured ping before it expires.
-- The lead also covers the longest single peril cast (the flame staff's ~1.15s burst)
-- so a cast started near the end of Warp Unbound still concludes while still immune.
local IMMUNITY_LEAD = 1.25
local MAX_PING_LEAD = 0.5

-- Extra lead used only to force an in-progress *held* cast to conclude before Warp
-- Unbound expires. Releasing ends the cast within a frame, so this only needs to cover
-- latency plus a small safety margin (unlike starting a fresh cast, which uses the
-- larger lead above and must run its full duration before the overload check).
local CONCLUDE_MARGIN = 0.15

-- Safety timeout that clears the auto-use one-shot latch if an activation never lands.
local FIRE_LATCH_TIMEOUT = 0.5

-- After a weapon swap, hold the vent input false for this long so the parser gets a clean
-- reload release + re-press edge. The staff/force-sword `vent` action-input node only exits on
-- vent_release (weapon_reload_hold == false) or a wield; holding reload across a swap can strand
-- the parser on that node (vent never restarts, peril stuck, quell stuck on). Covers the 0.2s
-- wield action plus margin.
local WIELD_VENT_GUARD = 0.3

-- Hubs where the mod stays idle (no Peril there).
local IDLE_GAME_MODES = { hub = true, prologue_hub = true }

-- Combat abilities that can halt an overload in time (recast to re-immunise / vent).
local RECOVERY_ABILITIES = {
	psyker_overcharge_stance = true,          -- Scrier's Gaze
	psyker_discharge_shout = true,            -- Psykinetic's Wrath
	psyker_discharge_shout_improved = true,   -- Venting Shriek
}
-- Per-ability auto-use toggle governing each recovery ability (one on/off per skill). Keys match
-- RECOVERY_ABILITIES; values are the setting ids. Lets you auto-use some abilities but keep others
-- (e.g. Scrier's) in reserve for offence rather than spending them defensively.
local AUTO_USE_SETTING = {
	psyker_overcharge_stance = "auto_use_scriers",         -- Scrier's Gaze
	psyker_discharge_shout = "auto_use_wrath",             -- Psykinetic's Wrath
	psyker_discharge_shout_improved = "auto_use_shriek",   -- Venting Shriek
}

-- Raw inputs that start a peril-gaining action, per weapon category. Presses are
-- edges (always safe to swallow); holds are swallowed only when not mid-charge,
-- since forcing a held input false reads as a release and would fire the charge.
local CATEGORY_INPUTS = {
	staff       = { pressed = { "action_one_pressed" }, held = { "action_one_hold" } },
	blitz       = { pressed = { "action_one_pressed" }, held = { "action_one_hold", "action_two_hold" } },
	-- Force swords only overload on the special (weapon_extra); action_one is free
	-- light/heavy melee, blocked only during the peril push follow-up (handled below).
	force_sword = { pressed = { "weapon_extra_pressed" }, held = { "weapon_extra_hold" } },
	gun         = { pressed = { "weapon_extra_pressed" }, held = { "weapon_extra_hold" } },
	-- Duelling sword: the parry special (weapon_extra) self-charges Peril and overloads near 97%.
	duelling_sword = { pressed = { "weapon_extra_pressed" }, held = { "weapon_extra_hold" } },
	-- Plasma gun: only the shot fired at full heat detonates, so swallow the fire edge (never a
	-- held release, which would itself fire a held charge). Bracing and venting are left alone.
	plasma = { pressed = { "action_one_pressed" }, held = {} },
}
-- Force-sword hold set while a push is running: also swallow the peril fling follow-up.
local FS_HELD_PUSH = { "weapon_extra_hold", "action_one_hold" }
-- Brain Rupture: only action_one_hold starts a target-locked (auto-firing) cast; action_two is the
-- default charge, which never auto-fires and is left alone.
local BR_HELD = { "action_one_hold" }

-- Weapon attack/charge holds. Held (not pressed) while quelling, they cap the vent to its
-- minimum -- enough to trim the overload without over-venting the charge.
local CAST_HOLDS = { "action_one_hold", "action_two_hold", "weapon_extra_hold" }

-- Categories that quell Peril on reload. The laspistol reloads its magazine instead (skipped), and
-- the duelling sword has no reload vent. Blitzes (Brain Rupture / Smite / Assail) all vent on reload.
-- ("Vent" is the engine's internal name for quelling.)
local VENTABLE = { staff = true, force_sword = true, blitz = true }

-- Staff hold inputs to force false when Warp Unbound is about to expire mid-cast:
-- releasing action_two ends the flame staff's sustained charged-flame stream, and
-- releasing action_one fires a held staff charge. Concluding while still immune runs
-- the finish-time overload check under immunity, so it cannot explode. Forcing an
-- input that is not currently held is a harmless no-op.
local STAFF_RELEASE = { "action_one_hold", "action_two_hold" }

-- Automatic Quelling yields to a fresh action: a deliberate key PRESS drops the forced vent, but
-- merely holding a key (a cast or charge you are riding out) does not, so it keeps venting at the
-- cap. Built from the engine's press/edge actions, minus movement keys and reload.
local InputHandlerSettings = require("scripts/managers/player/player_game_states/input_handler_settings")
local Sprint = require("scripts/extension_systems/character_state_machine/character_states/utilities/sprint")
local QUELL_KEEP = {
	jump = true, crouch = true, sprint = true, weapon_reload_pressed = true,
}
local QUELL_INTERRUPTS = {}
do
	-- Release edges (letting go of a key) are not actions, so skip them alongside QUELL_KEEP.
	local ephemeral = InputHandlerSettings.ephemeral_actions
	for i = 1, #ephemeral do
		local name = ephemeral[i]
		if not QUELL_KEEP[name] and not string.find(name, "_release", 1, true) then
			QUELL_INTERRUPTS[#QUELL_INTERRUPTS + 1] = name
		end
	end
end

-- Plasma Venting mirrors quelling but holds the weapon special (weapon_extra), so a tap of THAT
-- key is the player venting too and must not self-interrupt; the reload key, by contrast, is a
-- distinct plasma action and does interrupt. Same construction as QUELL_INTERRUPTS otherwise.
local PLASMA_VENT_KEEP = {
	jump = true, crouch = true, sprint = true, weapon_extra_pressed = true,
}
local PLASMA_VENT_INTERRUPTS = {}
do
	local ephemeral = InputHandlerSettings.ephemeral_actions
	for i = 1, #ephemeral do
		local name = ephemeral[i]
		if not PLASMA_VENT_KEEP[name] and not string.find(name, "_release", 1, true) then
			PLASMA_VENT_INTERRUPTS[#PLASMA_VENT_INTERRUPTS + 1] = name
		end
	end
end

local EMPTY = {}

-- ---------------------------------------------------------------------------
-- Settings cache.
-- ---------------------------------------------------------------------------
local cfg = {}

-- Mirrors the Mod Options layout: blocking, auto recovery, indicator.
local function refresh_settings()
	-- Relaxed (default) blocks only when an overload would be unrecoverable (a ready recovery ability
	-- makes it SAFE, so it is allowed); Strict blocks every action at the cap regardless. Anything but
	-- "strict" is Relaxed, so a ready ability is trusted by default.
	cfg.blocking_strict    = mod:get("blocking_type") == "strict"
	cfg.block_staffs       = mod:get("block_staffs")
	cfg.block_blitzes      = mod:get("block_blitzes")
	cfg.block_force_swords = mod:get("block_force_swords")
	cfg.block_guns         = mod:get("block_guns")
	cfg.block_crystalline  = mod:get("block_crystalline")
	cfg.block_duelling_swords = mod:get("block_duelling_swords")
	cfg.block_plasma       = mod:get("block_plasma")

	cfg.auto_quell           = mod:get("auto_quell")
	cfg.auto_quell_trigger   = mod:get("auto_quell_trigger") or 100
	cfg.auto_quell_interrupt = mod:get("auto_quell_interrupt")
	cfg.auto_quell_hold      = mod:get("auto_quell_hold")
	cfg.auto_plasma_vent           = mod:get("auto_plasma_vent")
	cfg.auto_plasma_vent_interrupt = mod:get("auto_plasma_vent_interrupt")
	cfg.auto_plasma_vent_hold      = mod:get("auto_plasma_vent_hold")
	cfg.auto_ability         = mod:get("auto_ability")
	cfg.auto_use_scriers     = mod:get("auto_use_scriers")
	cfg.auto_use_shriek      = mod:get("auto_use_shriek")
	cfg.auto_use_wrath       = mod:get("auto_use_wrath")
	cfg.when_to_use          = mod:get("when_to_use")
	cfg.min_peril            = mod:get("min_peril")
	cfg.recover_window       = mod:get("recover_window")
	cfg.auto_fire_before_unsafe = mod:get("auto_fire_before_unsafe")

	cfg.show_unsafe        = mod:get("show_unsafe")
	cfg.show_safe          = mod:get("show_safe")
	cfg.unsafe_color       = { 255, mod:get("unsafe_r"), mod:get("unsafe_g"), mod:get("unsafe_b") }
	cfg.safe_color         = { 255, mod:get("safe_r"), mod:get("safe_g"), mod:get("safe_b") }
	cfg.font_size          = mod:get("font_size")
	cfg.pos_x              = mod:get("pos_x")
	cfg.pos_y              = mod:get("pos_y")

	-- "default" means fall back to the localized SAFE / UNSAFE word.
	local uw = mod:get("unsafe_word")
	cfg.word_unsafe = (not uw or uw == "default") and mod:localize("txt_unsafe") or uw
	local sw = mod:get("safe_word")
	cfg.word_safe = (not sw or sw == "default") and mod:localize("txt_safe") or sw
end

mod.on_all_mods_loaded = refresh_settings
mod.on_setting_changed = refresh_settings
refresh_settings()

-- Render state the HUD element reads each frame.
mod._sc_visible = false
mod._sc_text = nil
mod._sc_color = nil
mod._sc_font_size = cfg.font_size
mod._sc_offset_x = cfg.pos_x
mod._sc_offset_y = cfg.pos_y
-- Input-hook state.
-- Live block boundary: the Peril at/above which the cached input sets engage, re-tested on the fixed
-- frame; huge means the block is disarmed. Category/overheat are cached alongside it so the hooks can
-- confirm the same weapon is still wielded and read the right meter.
mod._sc_block_boundary = math.huge
mod._sc_block_category = nil
mod._sc_block_overheat = false
mod._sc_pressed = EMPTY
mod._sc_held = EMPTY
mod._sc_release = EMPTY
mod._sc_fire_request = false
mod._sc_quell = false
mod._sc_cast_held = false
mod._sc_quell_interrupted = false
mod._sc_plasma_vent = false
mod._sc_plasma_vent_interrupted = false
-- Weapon-swap tracking for the vent-unstick guard.
mod._sc_wield_guard = 0
mod._sc_last_slot = false
-- Live Brain Rupture lock boundary read by the input hook; huge disables the live re-check.
mod._sc_br_boundary = math.huge
-- Auto Fire arming (set on the render frame); the actual inject is gated live in the input hook.
mod._sc_autofire_armed = false

mod:register_hud_element({
	class_name = "HudElementNoMoreOverloads",
	filename = "no_more_overloads/scripts/mods/no_more_overloads/HudElementNoMoreOverloads",
	use_hud_scale = true,
	visibility_groups = { "alive" },
})

-- Latest round-trip ping in seconds, used to make the immunity lead ping-independent.
local last_ping = 0
mod:hook_safe("PingReporter", "_take_measure", function (self)
	local measures = self._measures
	local latest = measures and measures[#measures]
	if latest then
		last_ping = latest / 1000
	end
end)

-- Current fixed-frame time. The input hook (_parse_input) is not passed t, but needs it to measure
-- how long the running charge has lasted (t - weapon_action.start_t) for Auto Fire's chain_time gate.
-- hook_safe runs AFTER fixed_update, so _parse_input reads this one fixed frame stale -- intentional:
-- it under-states elapsed time, so the gate can only trigger late, never early (never before the fire
-- is actually valid, so it never strands the parser). Both t and start_t are client fixed-frame seconds.
local last_fixed_t = 0
mod:hook_safe("HumanInputHandler", "fixed_update", function (self, dt, t)
	last_fixed_t = t
end)

-- ---------------------------------------------------------------------------
-- Read helpers.
-- ---------------------------------------------------------------------------
local function local_player()
	local pm = Managers.player
	if not pm or not pm.local_player_safe then
		return nil
	end
	-- Safe variant returns nil before the connection is up; plain local_player would index a nil peer.
	return pm:local_player_safe(1)
end

local function in_active_session()
	local state = Managers.state
	local game_mode = state and state.game_mode
	if not game_mode or not game_mode.game_mode_name then
		return false
	end
	local name = game_mode:game_mode_name()
	return name ~= nil and not IDLE_GAME_MODES[name]
end

-- The living local player unit and its archetype. Peril weapons gate on "psyker" in update; the
-- plasma gun runs for any archetype, since its overheat is class-independent.
local function get_local_unit()
	local player = local_player()
	if not player then
		return nil
	end
	local unit = player.player_unit
	if not unit or not ALIVE[unit] then
		return nil
	end
	local archetype = player.archetype_name and player:archetype_name() or nil
	return unit, archetype
end

-- Returns the wielded weapon's category ("staff" / "force_sword" / "gun" / "blitz" /
-- "duelling_sword" / "plasma") and whether it is Brain Rupture, or nil when nothing
-- overload-relevant is wielded. Keyword-based.
local function classify(unit)
	local weapon_ext = ScriptUnit.has_extension(unit, "weapon_system")
	local template = weapon_ext and weapon_ext:weapon_template()
	local kws = template and template.keywords
	if not kws then
		return nil
	end
	local combat_sword, p3
	for i = 1, #kws do
		local k = kws[i]
		if k == "force_staff" then return "staff" end
		if k == "force_sword" then return "force_sword" end
		if k == "laspistol" then return "gun" end
		if k == "plasma_rifle" then return "plasma" end
		if k == "combat_sword" then combat_sword = true end
		if k == "p3" then p3 = true end
	end
	-- Duelling Sword: combatsword_p3 (Maccabian, all three marks) is the only combat sword whose
	-- Psyker parry self-charges Peril; its special overloads near the 0.97 extreme threshold. Its
	-- keywords are exactly { melee, combat_sword, p3 }, so those two flags pin it uniquely -- the
	-- Devil's Claw (p1) and p2 combat swords have no peril parry and are left alone.
	if combat_sword and p3 then
		return "duelling_sword"
	end
	-- Legacy engine naming: template "psyker_smite" is the in-game Brain Rupture, and
	-- in-game Smite is "psyker_chain_lightning".
	if #kws == 1 and kws[1] == "psyker" then
		return "blitz", template.name == "psyker_smite"
	end
	return nil
end

local function block_toggle_for(category)
	if category == "staff" then return cfg.block_staffs end
	if category == "blitz" then return cfg.block_blitzes end
	if category == "force_sword" then return cfg.block_force_swords end
	if category == "gun" then return cfg.block_guns end
	if category == "duelling_sword" then return cfg.block_duelling_swords end
	if category == "plasma" then return cfg.block_plasma end
	return false
end

-- Seconds until the equipped combat ability can halt an overload; huge if it can't.
-- Compared against the cooldown tolerance (auto-use gates on can_use_ability instead).
local function recovery_cooldown(unit)
	local ability_ext = ScriptUnit.has_extension(unit, "ability_system")
	if not ability_ext or not ability_ext:ability_is_equipped("combat_ability") then
		return math.huge
	end
	if not RECOVERY_ABILITIES[ability_ext:ability_name("combat_ability")] then
		return math.huge
	end
	return ability_ext:remaining_ability_cooldown("combat_ability") or math.huge
end

-- Whether the wielded combat ability is a recovery ability whose per-ability auto-use is ON. Governs
-- both auto-firing it AND (via cd) whether its readiness lets you cast at the cap -- so turning a
-- skill's auto-use off makes the mod block those overloads instead of spending that skill.
local function auto_use_enabled(unit)
	if not cfg.auto_ability then
		return false
	end
	local ability_ext = ScriptUnit.has_extension(unit, "ability_system")
	if not ability_ext or not ability_ext:ability_is_equipped("combat_ability") then
		return false
	end
	local setting = AUTO_USE_SETTING[ability_ext:ability_name("combat_ability")]
	return (setting and cfg[setting]) or false
end

-- Crystalline Will makes overload non-lethal.
local function has_crystalline_will(unit)
	local talent_ext = ScriptUnit.has_extension(unit, "talent_system")
	if not talent_ext then
		return false
	end
	return talent_ext:has_special_rule("psyker_no_knock_down_overload") and true or false
end

-- Seconds of psychic_fortress immunity left; huge if a source is indefinite (the active stance).
local function immunity_remaining(buff_ext)
	local buffs = (buff_ext.buffs and buff_ext:buffs()) or buff_ext._buffs_by_index
	if not buffs then
		return math.huge
	end
	local max_remaining = 0
	for _, buff in pairs(buffs) do
		local template = buff.template and buff:template()
		local keywords = template and template.keywords
		if keywords then
			local fortress = false
			for i = 1, #keywords do
				if keywords[i] == PSYCHIC_FORTRESS then
					fortress = true
					break
				end
			end
			if fortress then
				local duration = buff.duration and buff:duration()
				local progress = buff.duration_progress and buff:duration_progress()
				if duration and progress and duration > 0 then
					local remaining = duration * progress
					if remaining > max_remaining then
						max_remaining = remaining
					end
				else
					return math.huge
				end
			end
		end
	end
	return max_remaining
end

-- ---------------------------------------------------------------------------
-- Auto Ability Use: request a one-frame combat-ability press to recover, latched so it fires once
-- per readiness. Reactive fires the instant an overload starts; Proactive fires as soon as the
-- ability is off cooldown, after the current cast/charge concludes.
-- ---------------------------------------------------------------------------
local fire_latched = false
local latch_timer = 0
local latch_saw_unusable = false
-- Auto Fire Before Unsafe one-shot latch: fire the charged shot once per pre-unsafe charge episode.
local autofire_latched = false
-- Last fixed frame's Peril while an armed staff is wielded; false when untracked. Its one-frame
-- delta is the live climb rate the pre-gate fire-press prediction scales out to the chain gate.
local staff_prev_peril = false

local function update_auto_ability(unit, overloading, peril, dt)
	if not auto_use_enabled(unit) then
		fire_latched = false
		return
	end
	-- auto_use_enabled confirmed a recovery ability is equipped with its auto-use on.
	local ability_ext = ScriptUnit.has_extension(unit, "ability_system")
	local can_use = ability_ext:can_use_ability("combat_ability")

	if fire_latched then
		latch_timer = latch_timer + dt
		if not can_use then
			latch_saw_unusable = true
		end
		if (latch_saw_unusable and can_use) or latch_timer > FIRE_LATCH_TIMEOUT then
			fire_latched = false
		end
	end

	-- Both modes fire on an actual overload to halt it; Proactive additionally fires once the
	-- ability is off cooldown, the current cast/charge has ended, and Peril is over the threshold.
	local trigger = overloading
	if cfg.when_to_use == "proactive" then
		trigger = trigger or (not mod._sc_cast_held and peril >= cfg.min_peril / 100)
	end

	if trigger and can_use and not fire_latched then
		mod._sc_fire_request = true
		fire_latched = true
		latch_timer = 0
		latch_saw_unusable = false
	end
end

-- ---------------------------------------------------------------------------
-- Automatic Quelling: hold the vent input while UNSAFE, following through for a configured extra
-- duration afterwards (0 = stop the instant UNSAFE clears). While UNSAFE it ALWAYS vents; a held
-- cast/charge trims the follow-through to nothing; a fresh action press cancels only the follow-
-- through (never the UNSAFE vent itself).
-- ---------------------------------------------------------------------------
-- Shared vent driver for Automatic Quelling (Psyker Peril -> reload key) and Automatic Plasma
-- Venting (plasma overheat -> weapon special). One weapon is wielded at a time, so the two are
-- mutually exclusive per frame; each keeps its own { hold_timer, band_latch } state and the caller
-- injects the matching key. `venting_needed` is UNSAFE-at-the-cap; `band_needed` is the custom
-- quell-trigger band (peril at/above the configured start, below the cap) -- interruptible, unlike
-- the cap vent; `interrupted` is the fresh-press flag the input hook raised; `minimum` trims the
-- follow-through while a cast/charge is held; `hold_amount` is the post-UNSAFE follow-through.
local function update_vent(state, venting_needed, band_needed, allowed, minimum, hold_amount, interrupted, dt)
	if not allowed then
		state.hold_timer = 0
		state.band_latch = false
		return false
	end
	if venting_needed then
		-- UNSAFE at the cap: always vent -- this is the life-saving vent and an interrupt must never
		-- cancel it (that was the "stuck at 100%" bug). Top up the follow-through so it starts full
		-- once UNSAFE clears; a held cast/charge trims that to nothing so it does not over-vent.
		state.hold_timer = minimum and 0 or hold_amount
		state.band_latch = false
		return true
	end
	-- Below the cap: the interrupt cancels the follow-through and silences the custom band -- it can
	-- never stop the UNSAFE vent above.
	if interrupted then
		state.hold_timer = 0
		state.band_latch = true
	end
	if band_needed then
		-- Custom trigger band: vent until interrupted; the latch then holds until the band is left
		-- (peril past either edge) so the player can act freely instead of fighting the vent.
		if not state.band_latch then
			return true
		end
	else
		state.band_latch = false
	end
	if state.hold_timer > 0 then
		state.hold_timer = state.hold_timer - dt
		return true
	end
	return false
end

local quell_state = { hold_timer = 0, band_latch = false }
local plasma_vent_state = { hold_timer = 0, band_latch = false }

-- ---------------------------------------------------------------------------
-- Per-frame engine.
-- ---------------------------------------------------------------------------
local function clear_state()
	mod._sc_visible = false
	mod._sc_block_boundary = math.huge
	mod._sc_block_category = nil
	mod._sc_block_overheat = false
	mod._sc_pressed = EMPTY
	mod._sc_held = EMPTY
	mod._sc_release = EMPTY
	mod._sc_fire_request = false
	mod._sc_quell = false
	mod._sc_cast_held = false
	mod._sc_quell_interrupted = false
	mod._sc_plasma_vent = false
	mod._sc_plasma_vent_interrupted = false
	mod._sc_autofire_armed = false
	fire_latched = false
	autofire_latched = false
	staff_prev_peril = false
	quell_state.hold_timer = 0
	quell_state.band_latch = false
	plasma_vent_state.hold_timer = 0
	plasma_vent_state.band_latch = false
	mod._sc_wield_guard = 0
	mod._sc_last_slot = false
	mod._sc_br_boundary = math.huge
end

mod.update = function (dt)
	if not mod:is_enabled() or not in_active_session() then
		clear_state()
		return
	end

	local unit, archetype = get_local_unit()
	if not unit then
		clear_state()
		return
	end

	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local buff_ext = ScriptUnit.has_extension(unit, "buff_system")
	if not unit_data or not buff_ext then
		clear_state()
		return
	end

	-- Detect weapon swaps: after one, open a brief reload-false window (WIELD_VENT_GUARD) so the
	-- auto-quell vent gets a clean release + re-press edge and cannot stick (see the input hook).
	local wield_inv = unit_data:read_component("inventory")
	local wielded_slot = wield_inv and wield_inv.wielded_slot
	if wielded_slot ~= mod._sc_last_slot then
		mod._sc_last_slot = wielded_slot
		mod._sc_wield_guard = WIELD_VENT_GUARD
	elseif mod._sc_wield_guard > 0 then
		mod._sc_wield_guard = math.max(0, mod._sc_wield_guard - dt)
	end

	local category, is_brain_rupture = classify(unit)
	local is_overheat = category and OVERHEAT_CATEGORIES[category] or false

	-- Peril weapons stay Psyker-only, unchanged. The plasma gun overheats on any class, but only
	-- when at least one of its bonus features (input block or auto-vent) is on; with both off the
	-- mod ignores it. Blocking and venting each gate on their own toggle downstream, so either one
	-- alone keeps the branch alive -- mirroring how the peril branch never depends on a block toggle.
	if is_overheat then
		if not cfg.block_plasma and not cfg.auto_plasma_vent then
			clear_state()
			return
		end
	elseif archetype ~= "psyker" then
		clear_state()
		return
	end

	local peril, charging, overloading
	local immune, effectively_immune, force_conclude, crystalline, cd
	if is_overheat then
		-- Overheat lives on the wielded weapon's inventory slot, read like the game's own
		-- Overheat.slot_percentage -- not the Psyker warp_charge component.
		local inv = unit_data:read_component("inventory")
		local slot_name = inv and inv.wielded_slot
		local slot = slot_name and slot_name ~= "none" and unit_data:read_component(slot_name)
		peril = slot and slot.overheat_current_percentage or 0
		charging = slot and slot.overheat_state == "increasing" or false
		overloading = slot and slot.overheat_state == "exploding" or false
		-- No Psyker concept applies: never immune, never Crystalline, no recovery ability.
		immune, effectively_immune, force_conclude, crystalline, cd = false, false, false, false, math.huge
	else
		local warp_charge = unit_data:read_component("warp_charge")
		peril = warp_charge.current_percentage or 0
		charging = warp_charge.state == "increasing"
		overloading = warp_charge.state == "exploding"
		immune = buff_ext:has_keyword(PSYCHIC_FORTRESS)
		-- Blocking type decides whether a ready recovery ability counts as "safe". Strict never trusts
		-- it (huge cd -> always block/quell at the cap); Relaxed trusts real readiness (drop the block
		-- when the ability is within the cooldown tolerance). Independent of Auto Ability Use, which now
		-- only decides who FIRES the ability, not whether the overload is allowed.
		cd = cfg.blocking_strict and math.huge or recovery_cooldown(unit)
		crystalline = has_crystalline_will(unit)
		-- Count the last (lead) seconds of immunity as already gone, so the block engages
		-- before Warp Unbound expires. The lead scales with ping so the margin covers RTT.
		local ping_lead = math.min(last_ping, MAX_PING_LEAD)
		local imm_remaining = immune and immunity_remaining(buff_ext) or math.huge
		local lead = IMMUNITY_LEAD + ping_lead
		effectively_immune = immune and imm_remaining >= lead
		-- Warp Unbound is within a latency-sized margin of expiring: force any in-progress
		-- held staff cast to conclude NOW, while immunity still holds. Without this, a
		-- sustained cast (notably the flame staff's charged-flame stream) that outlives the
		-- buff runs its finish-time overload check with immunity gone and explodes.
		force_conclude = immune and imm_remaining < ping_lead + CONCLUDE_MARGIN
	end

	local threshold
	if is_brain_rupture then
		-- Match the game's own guard: a Brain Rupture fire is safe when the lock happened below
		-- 1 - (1 - extreme)*warp_charge_amount (peril-reduction talents raise this). Block only
		-- at/above that per-player threshold, with a little headroom for input lag. Empowered
		-- Psionics makes the cast free (no peril, no overload), so never block then.
		if EMPOWERED_GRENADE and buff_ext:has_keyword(EMPOWERED_GRENADE) then
			threshold = math.huge
		else
			local stat_buffs = buff_ext:stat_buffs()
			local warp_charge_amount = (stat_buffs and stat_buffs.warp_charge_amount) or 1
			threshold = 1 - (1 - BRAIN_RUPTURE_EXTREME) * warp_charge_amount - BRAIN_RUPTURE_HEADROOM
		end
	else
		threshold = CATEGORY_CAP[category] or PERIL_CAP
	end

	-- At the overload point: a peril weapon is up, no effective immunity, at the cap.
	local at_cap = category ~= nil and not effectively_immune and peril >= threshold
	-- UNSAFE = an overload here would be unrecoverable (recovery ability further off
	-- than the cooldown tolerance), or an overload is already in progress.
	local unsafe = (at_cap and cd > cfg.recover_window) or overloading

	-- Block the wielded category's peril inputs when its toggle is on and it isn't an allowed
	-- Crystalline Will self-explode. Never while already exploding. Everything EXCEPT the peril
	-- comparison is settled here; the comparison itself is redone live on the fixed frame (see
	-- block_engaged_now), because this render-frame pass can be skipped entirely across the moment
	-- peril crosses the cap: gameplay_state_run's fixed loop runs every outstanding fixed frame
	-- back-to-back, so at sub-tickrate framerates (or through any hitch) peril can cross AND the cast
	-- can start with no mod.update in between. That was the missed flame-staff block.
	local block_armed = category ~= nil and not effectively_immune and not overloading
		and cd > cfg.recover_window and block_toggle_for(category)
		and not (crystalline and not cfg.block_crystalline)
	mod._sc_block_boundary = block_armed and threshold or math.huge
	mod._sc_block_category = category
	mod._sc_block_overheat = is_overheat
	-- Brain Rupture's lock gets its own live re-check on top, since it must also skip a cast that has
	-- already locked safely (a running-action test the generic gate has no business making).
	local br_armed = is_brain_rupture and block_armed
	mod._sc_br_boundary = br_armed and threshold or math.huge
	local sets = category and CATEGORY_INPUTS[category]
	mod._sc_pressed = (block_armed and sets) and sets.pressed or EMPTY
	local held = (block_armed and not charging and sets) and sets.held or EMPTY
	if is_brain_rupture then
		-- Brain Rupture's only overload route is a target-LOCKED cast (sticky from idle, or lock-on
		-- chained off the default action_two charge) whose lock snapshot is >= the threshold; both
		-- start on action_one_hold, so block just that. But never while ALREADY inside a running
		-- locked cast: it locked safely below the threshold and auto-fires safely, so interrupting
		-- it is wrong. The default action_two charge never auto-fires and is left entirely alone.
		local weapon_action = unit_data:read_component("weapon_action")
		local action_name = weapon_action and weapon_action.current_action_name
		local in_locked_cast = action_name == "action_charge_target_sticky"
			or action_name == "action_charge_target_lock_on"
		held = (block_armed and not in_locked_cast) and BR_HELD or EMPTY
	elseif held ~= EMPTY and category == "force_sword" then
		-- Force sword: also block the push follow-up (peril fling) without blocking free melee.
		local weapon_action = unit_data:read_component("weapon_action")
		if weapon_action and weapon_action.current_action_name == "action_push" then
			held = FS_HELD_PUSH
		end
	end
	mod._sc_held = held
	-- Release-to-conclude inputs, applied only in the last moments of Warp Unbound (staff only).
	-- Forced false in the input cache (below) but deliberately NOT queue-gated, so the release the
	-- game derives from them survives to finish the cast safely.
	mod._sc_release = (block_armed and force_conclude and category == "staff") and STAFF_RELEASE or EMPTY

	-- Automatic Quelling: while genuinely UNSAFE (at the cap, unrecoverable) with a
	-- ventable weapon, hold the reload/vent input to quell Peril and pull the player
	-- out of danger, then follow through for the configured hold. Skipped under active
	-- immunity (nothing to fear yet) and for Crystalline Will self-explodes.
	local quell_allowed = cfg.auto_quell and not overloading and not immune
		and VENTABLE[category] and not (crystalline and not cfg.block_crystalline) or false
	-- Custom quell trigger: start quelling at the configured percentage instead of only at the cap.
	-- Clamped to the category's own threshold, so 100 (default) = exactly the UNSAFE point and the
	-- band never activates (the cap vent handles it) -- stock behaviour. The band inherits UNSAFE's
	-- recoverability gate, and (interrupt on) yields to a held cast/charge: forcing reload mid-charge
	-- would cancel the charge into venting.
	local quell_threshold = math.min(cfg.auto_quell_trigger * 0.01, threshold)
	local quell_band = category ~= nil and not effectively_immune and peril >= quell_threshold
		and cd > cfg.recover_window and not overloading
		and not (cfg.auto_quell_interrupt and mod._sc_cast_held) or false
	-- The held-cast minimum belongs to the interrupt feature, so it only applies when that is on.
	local quell_interrupted = mod._sc_quell_interrupted
	mod._sc_quell_interrupted = false
	mod._sc_quell = update_vent(quell_state, unsafe, quell_band, quell_allowed,
		cfg.auto_quell_interrupt and mod._sc_cast_held, cfg.auto_quell_hold, quell_interrupted, dt)

	-- Automatic Plasma Venting: the overheat mirror of quelling. Holds the weapon special
	-- (weapon_extra) to vent heat while the plasma gun is UNSAFE. Only the plasma overheat branch
	-- vents this way; the game itself gates the vent to when the gun is idle with heat, so an
	-- injected hold mid-charge is a harmless no-op.
	local plasma_vent_allowed = cfg.auto_plasma_vent and is_overheat and not overloading or false
	local plasma_vent_interrupted = mod._sc_plasma_vent_interrupted
	mod._sc_plasma_vent_interrupted = false
	-- Unlike quelling, the plasma vent is meant to OVERRIDE a held brace/charge (the input hook
	-- force-releases it), so a held key must NOT trim the follow-through -- it always runs the full
	-- configured duration. Hence no cast-held minimum here (pass false).
	mod._sc_plasma_vent = update_vent(plasma_vent_state, unsafe, false, plasma_vent_allowed,
		false, cfg.auto_plasma_vent_hold, plasma_vent_interrupted, dt)

	-- Auto-use fires the recovery ability: Reactive on the overload, Proactive on cooldown (above).
	-- Skipped for the plasma gun -- the Psyker combat ability does nothing for weapon overheat.
	if not is_overheat then
		update_auto_ability(unit, overloading, peril, dt)
	end

	-- Auto Fire Before Unsafe: land a charging staff's charged shot/stream just before Peril crosses
	-- the block threshold, instead of blocking + quelling it (which wastes the charge and can loop).
	-- Arming ONLY here (render frame), under the same conditions as the block. The actual inject is
	-- gated LIVE in the input hook on: the running charge action, fixed-frame Peril in the pre-cap
	-- band, and the fire chain_time having elapsed -- so it fires only when the shot will truly start
	-- this frame and below the cap. That is what keeps it from stranding the parser or firing at 100%.
	-- The trailing Peril pre-gate just keeps the hook's per-frame reads to the near-cap window.
	mod._sc_autofire_armed = cfg.auto_fire_before_unsafe and category == "staff"
		and not overloading and block_toggle_for(category) and not effectively_immune
		and cd > cfg.recover_window and not (crystalline and not cfg.block_crystalline)
		and peril >= threshold - AUTO_FIRE_MARGIN * 2

	-- SAFE / UNSAFE indicator. Show honest recoverability, NOT the block state: under Strict the block
	-- fires at the cap even when the recovery ability is ready, but the readout must not claim UNSAFE
	-- then (you CAN recover). So read the real ability readiness here, independent of Blocking type.
	local shown_unsafe = overloading or (at_cap and (is_overheat or recovery_cooldown(unit) > cfg.recover_window))
	if shown_unsafe and cfg.show_unsafe then
		mod._sc_visible = true
		mod._sc_text = cfg.word_unsafe
		mod._sc_color = cfg.unsafe_color
	elseif not shown_unsafe and cfg.show_safe then
		mod._sc_visible = true
		mod._sc_text = cfg.word_safe
		mod._sc_color = cfg.safe_color
	else
		mod._sc_visible = false
	end
	mod._sc_font_size = cfg.font_size
	mod._sc_offset_x = cfg.pos_x
	mod._sc_offset_y = cfg.pos_y
end

-- ---------------------------------------------------------------------------
-- Input capture hook: swallow the wielded category's cast inputs, and inject the
-- auto-use combat-ability press. This is the local player's own _input_cache, which
-- is both read by local prediction and sent to the server, so edits are desync-safe.
-- ---------------------------------------------------------------------------
local function set_input(cache, lookup, name, index, value)
	local idx = lookup[name]
	local slot = idx and cache[idx]
	if slot then
		slot[index] = value
	end
end

local function get_input(cache, lookup, name, index)
	local idx = lookup[name]
	local slot = idx and cache[idx]
	return slot and slot[index]
end

-- Live block gate, run on the FIXED frame by both input hooks. mod.update settles everything but the
-- peril comparison (mod._sc_block_boundary, huge when disarmed); this redoes just that comparison
-- against the current component value. Timing is exact rather than merely fresher: within a fixed
-- frame the peril meter is only written by the weapon system (extension order: input -> action_input
-- -> character_state_machine -> weapon), and both hooks run ahead of it, so this reads precisely the
-- value the game will snapshot into starting_percentage when it starts the cast later this same frame.
local function block_engaged_now()
	if mod._sc_block_boundary >= math.huge then
		return false
	end
	local player = local_player()
	local unit = player and player.player_unit
	if not unit or not ALIVE[unit] then
		return false
	end
	-- Re-confirm the same category is still wielded: the boundary is cached on the render frame, so a
	-- mid-hitch swap must not force the old weapon's inputs onto the new one.
	if classify(unit) ~= mod._sc_block_category then
		return false
	end
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data then
		return false
	end
	local peril
	if mod._sc_block_overheat then
		local inv = unit_data:read_component("inventory")
		local slot_name = inv and inv.wielded_slot
		local slot = slot_name and slot_name ~= "none" and unit_data:read_component(slot_name)
		peril = slot and slot.overheat_current_percentage or 0
	else
		local warp_charge = unit_data:read_component("warp_charge")
		peril = warp_charge and warp_charge.current_percentage or 0
	end
	return peril >= mod._sc_block_boundary
end

-- True while the local player is pressing an interrupt-worthy action this frame. The set holds
-- only press/edge inputs, so merely holding a cast or charge key never stops the vent.
local function player_taking_action(cache, lookup, index, interrupts)
	for i = 1, #interrupts do
		if get_input(cache, lookup, interrupts[i], index) then
			return true
		end
	end
	return false
end

mod:hook_safe("HumanInputHandler", "_parse_input", function (self, input_cache, input_service, index)
	local lookup = self._action_lookup
	if not lookup then
		return
	end
	-- Read the genuine input BEFORE the block below zeroes the cast key: a fresh action PRESS
	-- interrupts the vent (so casting still counts), while merely holding a key never does. The
	-- two vent modes use different keep-sets (reload is the quell key; the special is the plasma
	-- vent key), so each is checked against its own interrupt list.
	local quell_interrupt_now = mod._sc_quell and cfg.auto_quell_interrupt
		and player_taking_action(input_cache, lookup, index, QUELL_INTERRUPTS)
	if quell_interrupt_now then
		mod._sc_quell_interrupted = true
	end
	local plasma_vent_interrupt_now = mod._sc_plasma_vent and cfg.auto_plasma_vent_interrupt
		and player_taking_action(input_cache, lookup, index, PLASMA_VENT_INTERRUPTS)
	if plasma_vent_interrupt_now then
		mod._sc_plasma_vent_interrupted = true
	end
	-- Track whether a weapon attack/charge is held: it never interrupts the vent, but feeds the
	-- minimum follow-through (interrupt toggle only) and Proactive's wait-for-the-cast.
	local cast_held = false
	for i = 1, #CAST_HOLDS do
		if get_input(input_cache, lookup, CAST_HOLDS[i], index) then
			cast_held = true
			break
		end
	end
	mod._sc_cast_held = cast_held
	-- The cached sets are what the wielded category blocks once at the cap; the cap test itself is
	-- live, so a peril crossing that mod.update never observed still blocks this frame.
	if block_engaged_now() then
		local pressed = mod._sc_pressed
		for i = 1, #pressed do
			set_input(input_cache, lookup, pressed[i], index, false)
		end
		local held = mod._sc_held
		for i = 1, #held do
			set_input(input_cache, lookup, held[i], index, false)
		end
		-- Force a release to conclude an in-progress cast while Warp Unbound still holds.
		local release = mod._sc_release
		for i = 1, #release do
			set_input(input_cache, lookup, release[i], index, false)
		end
	end
	-- Staff charge, pre-gate fire press: the game QUEUES a fire press made before the charge has run
	-- the fire's chain_time and consumes it the instant the gate opens -- with Peril snapshotted
	-- THEN, not at press time. Peril keeps climbing meanwhile, so a press accepted below the cap can
	-- execute at exactly 100% (starting_percentage 1.0 -> overload at stream end). Once queued it is
	-- beyond reach: the authority replays the RAW inputs through its own parser (client queue edits
	-- do not replicate -- hence overloads in missions but not the psykhanium), and the engine's stop
	-- path peeks only the queue head, which the queued press itself occupies. So the press must die
	-- HERE: predict Peril at gate-open (live one-frame climb x frames remaining) and swallow the
	-- press when it could only land at the cap. A press at low Peril still fires safely at gate-open.
	local staff_tracked = false
	if mod._sc_block_boundary < math.huge and mod._sc_block_category == "staff" then
		local sp_player = local_player()
		local sp_unit = sp_player and sp_player.player_unit
		local sp_ud = sp_unit and ALIVE[sp_unit] and classify(sp_unit) == "staff"
			and ScriptUnit.has_extension(sp_unit, "unit_data_system")
		if sp_ud then
			local warp = sp_ud:read_component("warp_charge")
			local live = (warp and warp.current_percentage) or 0
			-- Measured per-fixed-frame climb: absorbs tier lerps, talents and stat buffs (p1 at
			-- perfect stats charges 30%/s where p2 basic is 12.5%/s, so no constant fits all).
			local climb = staff_prev_peril and math.max(0, live - staff_prev_peril) or 0
			staff_prev_peril = live
			staff_tracked = true
			if get_input(input_cache, lookup, "action_one_pressed", index) then
				local wa = sp_ud:read_component("weapon_action")
				local action_name = wa and wa.current_action_name
				if action_name and STAFF_CHARGE_ACTIONS[action_name] then
					local weapon_ext = ScriptUnit.has_extension(sp_unit, "weapon_system")
					local template = weapon_ext and weapon_ext:weapon_template()
					local actions = template and template.actions
					local action = actions and actions[action_name]
					local chains = action and action.allowed_chain_actions
					local chain_time, fire_settings = 0, nil
					if chains then
						for i = 1, #STAFF_FIRE_INPUTS do
							local fire = chains[STAFF_FIRE_INPUTS[i]]
							if fire then
								chain_time = fire.chain_time or 0
								fire_settings = fire.action_name and actions[fire.action_name]
								break
							end
						end
					end
					local sprint_comp = sp_ud:read_component("sprint_character_state")
					if fire_settings and not fire_settings.allowed_during_sprint
						and not fire_settings.buff_keywords
						and sprint_comp and Sprint.is_sprinting(sprint_comp) then
						-- Surge's charged fire cannot start while sprinting, and sprinting also
						-- refreshes the buffered press's lifetime every frame -- a press made while
						-- sprint-charging defers UNBOUNDED and executes the frame sprint ends, at
						-- whatever Peril has climbed to (unknowable now). Swallow it; a fresh press
						-- after sprint goes through the normal live and predictive gates.
						set_input(input_cache, lookup, "action_one_pressed", index, false)
					elseif climb > 0 then
						-- Same inverted-timescale rule as Auto Fire (staff charges are all inverted
						-- kinds). last_fixed_t is a frame stale, overstating the wait -- safe direction.
						local ts = wa.time_scale or 1
						local gate = (ts < 1) and (chain_time * ts) or (chain_time / ts)
						local remaining = gate - (last_fixed_t - (wa.start_t or last_fixed_t))
						if remaining > 0 then
							local fixed_dt = (Managers.state.game_session and Managers.state.game_session.fixed_time_step) or 0.02
							-- +2 frames: covers the stale rate sample and any decay bled into it.
							local predicted = live + climb * (remaining / fixed_dt + 2)
							if predicted >= mod._sc_block_boundary then
								set_input(input_cache, lookup, "action_one_pressed", index, false)
							end
						end
					end
				end
			end
		end
	end
	-- A gap in tracking (swap, immunity, disarm) invalidates the sample; never diff across it.
	if not staff_tracked then
		staff_prev_peril = false
	end
	-- Brain Rupture: re-block the lock (action_one_hold) against LIVE peril, so a fixed-frame climb
	-- between the render-frame update and this parse cannot let a lock-on snapshot land unsafe. Skip
	-- while inside a running locked cast -- it locked safely below the boundary and must not be cut.
	if mod._sc_br_boundary < math.huge then
		local br_player = local_player()
		local br_unit = br_player and br_player.player_unit
		-- Re-confirm Brain Rupture is still wielded this frame: the boundary is cached on the render
		-- frame, so a mid-hitch swap must not force action_one_hold onto the new weapon (mirrors the
		-- plasma-vent live re-classify below). classify's 2nd return is the is_brain_rupture flag.
		if br_unit and ALIVE[br_unit] and select(2, classify(br_unit)) then
			local br_ud = ScriptUnit.has_extension(br_unit, "unit_data_system")
			if br_ud then
				local weapon_action = br_ud:read_component("weapon_action")
				local action_name = weapon_action and weapon_action.current_action_name
				if action_name ~= "action_charge_target_sticky" and action_name ~= "action_charge_target_lock_on" then
					local warp_charge = br_ud:read_component("warp_charge")
					if warp_charge and (warp_charge.current_percentage or 0) >= mod._sc_br_boundary then
						set_input(input_cache, lookup, "action_one_hold", index, false)
					end
				end
			end
		end
	end
	-- Automatic Quelling: hold reload to bleed off Peril whenever quelling is on (update_vent already
	-- decided: it vents unconditionally while UNSAFE, and lets an interrupt cancel only the below-cap
	-- follow-through -- so nothing gates the inject here). Mutually exclusive with the plasma vent.
	if mod._sc_quell then
		-- Just after a weapon swap, force reload false so the parser gets a clean vent_release +
		-- re-press edge; holding reload across the swap can strand it on the [vent] node (stuck
		-- venting until another swap).
		local hold_vent = mod._sc_wield_guard <= 0
		set_input(input_cache, lookup, "weapon_reload_hold", index, hold_vent)
	end
	-- weapon_extra_hold is also the peril special on force/duelling swords, so a stale vent flag
	-- surviving a weapon swap must never inject it onto the new weapon. Re-confirm a plasma is
	-- actually wielded this frame before forcing anything (only runs while venting, so cheap).
	if mod._sc_plasma_vent and not plasma_vent_interrupt_now then
		local vent_player = local_player()
		local vent_unit = vent_player and vent_player.player_unit
		if vent_unit and ALIVE[vent_unit] and classify(vent_unit) == "plasma" then
			-- The vent only starts from an idle weapon (Overheat.can_vent); a HELD brace keeps the gun
			-- in its charge action, so without this the vent waits for the player to let go. With hold-
			-- to-ADS, brace_release is action_two_hold=false (plasmagun action_inputs), so force that:
			-- the charge concludes, the gun idles, and the injected vent takes over -- giving the vent
			-- priority over the held brace. Safe: a plasma fires on action_one_pressed (shoot_braced),
			-- never on brace-release; a fresh re-press still interrupts via PLASMA_VENT_INTERRUPTS.
			-- Toggle-ADS has no held key to override, so only touch the brace for hold-to-ADS.
			if not get_input(input_cache, lookup, "toggle_ads", index) then
				set_input(input_cache, lookup, "action_two_hold", index, false)
			end
			set_input(input_cache, lookup, "weapon_extra_hold", index, true)
		end
	end
	if mod._sc_fire_request then
		set_input(input_cache, lookup, "combat_ability_pressed", index, true)
		mod._sc_fire_request = false
	end
	-- Auto Fire Before Unsafe: inject the charged-shot trigger (action_one_pressed while action_two is
	-- held) ONLY when it will genuinely start the shot this frame: a staff charge is running, live Peril
	-- is in the pre-cap band, and the charge has passed its fire chain_time. A press the action handler
	-- won't consume still advances the parser one node deep with nothing running -- the stuck-input
	-- strand -- so gating on a real start (and re-confirming a staff is wielded, for mid-frame swaps)
	-- avoids it. Fires once per charge episode; the latch resets whenever we leave the fire window.
	local in_fire_window = false
	if mod._sc_autofire_armed then
		local af_player = local_player()
		local af_unit = af_player and af_player.player_unit
		local af_ud = af_unit and ALIVE[af_unit] and classify(af_unit) == "staff"
			and ScriptUnit.has_extension(af_unit, "unit_data_system")
		local wa = af_ud and af_ud:read_component("weapon_action")
		local action_name = wa and wa.current_action_name
		if action_name and STAFF_CHARGE_ACTIONS[action_name] then
			local warp = af_ud:read_component("warp_charge")
			local live_peril = (warp and warp.current_percentage) or 0
			-- Inverted-timescale chain validation: the fire cannot start until the charge has run
			-- chain_time, scaled by the action's time_scale.
			local ts = wa.time_scale or 1
			local gate = (ts < 1) and (AUTO_FIRE_CHAIN_TIME * ts) or (AUTO_FIRE_CHAIN_TIME / ts)
			if live_peril < PERIL_CAP and live_peril >= PERIL_CAP - AUTO_FIRE_MARGIN
				and (last_fixed_t - (wa.start_t or last_fixed_t)) >= gate then
				in_fire_window = true
				if not autofire_latched then
					set_input(input_cache, lookup, "action_one_pressed", index, true)
					autofire_latched = true
				end
			end
		end
	end
	if not in_fire_window then
		autofire_latched = false
	end
end)

-- ---------------------------------------------------------------------------
-- Queue gate: an input captured just under the cap can sit buffered in the weapon
-- action queue and fire after Peril ticks to the cap. Re-check queued entries at
-- consume time and null out any still blocked. CLIENT-LOCAL ONLY: the authority
-- replays the raw inputs through its own parser, so this holds solely where the
-- local client is the authority (psykhanium); in missions the pre-send swallows
-- in _parse_input above are the real guard, this is best-effort cleanup.
-- ---------------------------------------------------------------------------
-- Only START inputs are queue-gated. mod._sc_release is intentionally excluded: those
-- inputs force a *release*, and the game queues the resulting conclude action (e.g. the
-- flame staff's cancel_flame) under the same raw input -- nulling it here would strand
-- the cast running until it overloads.
local function raw_is_blocked(raw)
	local pressed = mod._sc_pressed
	for i = 1, #pressed do
		if pressed[i] == raw then return true end
	end
	local held = mod._sc_held
	for i = 1, #held do
		if held[i] == raw then return true end
	end
	return false
end

mod:hook_safe("ActionInputParser", "fixed_update", function (self, unit, dt, t, fixed_frame)
	if mod._sc_block_boundary >= math.huge or self._action_component_name ~= "weapon_action" then
		return
	end
	if self._player ~= local_player() then
		return
	end
	-- Same live cap test as the capture hook. Re-run rather than shared: this hook sits after the
	-- talent system's peril decay, so its read is the more accurate one when the meter is falling.
	if not block_engaged_now() then
		return
	end
	local queue = self._action_input_queue and self._action_input_queue[self._ring_buffer_index]
	if not queue then
		return
	end
	local no_action = self._NO_ACTION_INPUT
	local no_raw = self._NO_RAW_INPUT
	for i = 1, self._MAX_ACTION_INPUT_QUEUE do
		local entry = queue[i]
		if not entry or entry[1] == no_action then
			break
		end
		if entry[2] and raw_is_blocked(entry[2]) then
			entry[1] = no_action
			entry[2] = no_raw
		end
	end
end)
