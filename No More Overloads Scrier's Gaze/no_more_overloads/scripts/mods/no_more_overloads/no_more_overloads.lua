local mod = get_mod("no_more_overloads")

-- Keyword the game checks to suppress overload.
local BuffSettings = require("scripts/settings/buff/buff_settings")
local PSYCHIC_FORTRESS = BuffSettings.keywords.psychic_fortress
-- Empowered Psionics makes blitzes free (no peril, no overload) while active.
local EMPOWERED_GRENADE = BuffSettings.keywords.psyker_empowered_grenade

local PERIL_CAP = 0.999
local BRAIN_RUPTURE_EXTREME = 0.97
local BRAIN_RUPTURE_HEADROOM = 0.003

-- ============================================================================
-- Dynamic Gaze Hysteresis with Configurable Quell Watchdog & Rapid-Fire Exit
-- ============================================================================
local GAZE_TIER1_CUTOFF = 30.0
local GAZE_TIER2_CUTOFF = 55.0

local GAZE_TRIGGER_TIER1 = 0.95
local GAZE_TRIGGER_TIER2 = 0.85
local GAZE_TRIGGER_TIER3 = 0.82

local GAZE_RELEASE_TIER1 = 0.82
local GAZE_RELEASE_TIER2 = 0.65
local GAZE_RELEASE_TIER3 = 0.50

local GAZE_EXIT_GRACE_DURATION = 1.2 -- Grace window preventing post-Gaze input clamp

local AUTO_FIRE_MARGIN = 0.03
local CATEGORY_CAP = { force_sword = 0.96, duelling_sword = 0.96, plasma = 0.99 }
local OVERHEAT_CATEGORIES = { plasma = true }

local IMMUNITY_LEAD = 1.25
local MAX_PING_LEAD = 0.5
local CONCLUDE_MARGIN = 0.15
local FIRE_LATCH_TIMEOUT = 0.5
local WIELD_VENT_GUARD = 0.45

local IDLE_GAME_MODES = { hub = true, prologue_hub = true }

local RECOVERY_ABILITIES = {
	psyker_overcharge_stance = true,          -- Scrier's Gaze
	psyker_discharge_shout = true,            -- Psykinetic's Wrath
	psyker_discharge_shout_improved = true,   -- Venting Shriek
}

local CATEGORY_INPUTS = {
	staff       = { pressed = { "action_one_pressed" }, held = { "action_one_hold", "action_two_hold" } },
	blitz       = { pressed = { "action_one_pressed" }, held = { "action_one_hold", "action_two_hold" } },
	force_sword = { pressed = { "weapon_extra_pressed" }, held = {} },
	gun         = { pressed = { "weapon_extra_pressed" }, held = { "weapon_extra_hold" } },
	duelling_sword = { pressed = { "weapon_extra_pressed" }, held = { "weapon_extra_hold" } },
	plasma = { pressed = { "action_one_pressed" }, held = {} },
}
local FS_HELD_PUSH = { "weapon_extra_hold", "action_one_hold" }
local BR_HELD = { "action_one_hold" }

local CAST_HOLDS = { "action_one_hold", "action_two_hold", "weapon_extra_hold" }

local VENTABLE = { staff = true, blitz = true }
local STAFF_RELEASE = { "action_one_hold", "action_two_hold" }

local InputHandlerSettings = require("scripts/managers/player/player_game_states/input_handler_settings")
local QUELL_KEEP = {
	jump = true, crouch = true, sprint = true, sprint_hold = true, dodge = true, weapon_reload_pressed = true,
}
local QUELL_INTERRUPTS = {}
do
	local ephemeral = InputHandlerSettings.ephemeral_actions
	for i = 1, #ephemeral do
		local name = ephemeral[i]
		if not QUELL_KEEP[name] and not string.find(name, "_release", 1, true) then
			QUELL_INTERRUPTS[#QUELL_INTERRUPTS + 1] = name
		end
	end
end

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

local cfg = {}

local function refresh_settings()
	cfg.block_staffs        = mod:get("block_staffs")
	cfg.block_blitzes       = mod:get("block_blitzes")
	cfg.block_force_swords  = mod:get("block_force_swords")
	cfg.block_guns          = mod:get("block_guns")
	cfg.block_crystalline   = mod:get("block_crystalline")
	cfg.block_duelling_swords = mod:get("block_duelling_swords")
	cfg.block_plasma        = mod:get("block_plasma")

	cfg.auto_quell           = mod:get("auto_quell")
	cfg.auto_quell_interrupt = mod:get("auto_quell_interrupt")
	cfg.auto_quell_hold      = mod:get("auto_quell_hold")
	cfg.auto_plasma_vent           = mod:get("auto_plasma_vent")
	cfg.auto_plasma_vent_interrupt = mod:get("auto_plasma_vent_interrupt")
	cfg.auto_plasma_vent_hold      = mod:get("auto_plasma_vent_hold")
	cfg.auto_ability         = mod:get("auto_ability")
	cfg.when_to_use          = mod:get("when_to_use")
	cfg.min_peril            = mod:get("min_peril")
	cfg.recover_window       = mod:get("recover_window")
	cfg.auto_fire_before_unsafe = mod:get("auto_fire_before_unsafe")

	-- Configurable Gaze Quell Watchdog Slider (0.0 to 3.0 seconds)
	local max_quell = mod:get("max_gaze_quell_duration")
	cfg.max_gaze_quell_duration = (max_quell ~= nil) and max_quell or 1.0

	cfg.show_unsafe        = mod:get("show_unsafe")
	cfg.show_safe          = mod:get("show_safe")
	cfg.unsafe_color       = { 255, mod:get("unsafe_r"), mod:get("unsafe_g"), mod:get("unsafe_b") }
	cfg.safe_color         = { 255, mod:get("safe_r"), mod:get("safe_g"), mod:get("safe_b") }
	cfg.font_size          = mod:get("font_size")
	cfg.pos_x              = mod:get("pos_x")
	cfg.pos_y              = mod:get("pos_y")

	local uw = mod:get("unsafe_word")
	cfg.word_unsafe = (not uw or uw == "default") and mod:localize("txt_unsafe") or uw
	local sw = mod:get("safe_word")
	cfg.word_safe = (not sw or sw == "default") and mod:localize("txt_safe") or sw
end

mod.on_all_mods_loaded = refresh_settings
mod.on_setting_changed = refresh_settings
refresh_settings()

mod._sc_visible = false
mod._sc_text = nil
mod._sc_color = nil
mod._sc_font_size = cfg.font_size
mod._sc_offset_x = cfg.pos_x
mod._sc_offset_y = cfg.pos_y

mod._sc_block_active = false
mod._sc_pressed = EMPTY
mod._sc_held = EMPTY
mod._sc_release = EMPTY
mod._sc_fire_request = false
mod._sc_quell = false
mod._sc_cast_held = false
mod._sc_quell_interrupted = false
mod._sc_plasma_vent = false
mod._sc_plasma_vent_interrupted = false
mod._sc_wield_guard = 0
mod._sc_last_slot = false
mod._sc_br_boundary = math.huge
mod._sc_fire_charged = false
mod._sc_live_threshold = math.huge

local gaze_forcing_quell = false
local gaze_active_timer = 0
local gaze_quell_duration = 0
local gaze_aborted = false
local gaze_exit_grace = 0

mod:register_hud_element({
	class_name = "HudElementNoMoreOverloads",
	filename = "no_more_overloads/scripts/mods/no_more_overloads/HudElementNoMoreOverloads",
	use_hud_scale = true,
	visibility_groups = { "alive" },
})

local last_ping = 0
mod:hook_safe("PingReporter", "_take_measure", function (self)
	local measures = self._measures
	local latest = measures and measures[#measures]
	if latest then
		last_ping = latest / 1000
	end
end)

local function local_player()
	local pm = Managers.player
	if not pm or not pm.local_player_safe then
		return nil
	end
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
	if combat_sword and p3 then
		return "duelling_sword"
	end
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

local function has_scriers_gaze(buff_ext)
	local buffs = (buff_ext.buffs and buff_ext:buffs()) or buff_ext._buffs_by_index
	if not buffs then
		return false
	end
	for _, buff in pairs(buffs) do
		local template = buff.template and buff:template()
		local name = template and template.name
		if name == "psyker_overcharge_stance" or name == "psyker_overcharge_stance_improved" then
			return true
		end
	end
	return false
end

local function has_crystalline_will(unit)
	local talent_ext = ScriptUnit.has_extension(unit, "talent_system")
	if not talent_ext then
		return false
	end
	return talent_ext:has_special_rule("psyker_no_knock_down_overload") and true or false
end

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

local fire_latched = false
local latch_timer = 0
local latch_saw_unusable = false
local autofire_latched = false

local function update_auto_ability(unit, overloading, peril, dt)
	if not cfg.auto_ability then
		fire_latched = false
		return
	end
	local ability_ext = ScriptUnit.has_extension(unit, "ability_system")
	if not ability_ext or not ability_ext:ability_is_equipped("combat_ability")
		or not RECOVERY_ABILITIES[ability_ext:ability_name("combat_ability")] then
		fire_latched = false
		return
	end
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

local function update_vent(state, unsafe, allowed, minimum, hold_amount, interrupted, dt)
	if not allowed then
		state.hold_timer = 0
		state.cancelled = false
		return false
	end
	if interrupted then
		state.cancelled = true
		state.hold_timer = 0
	end
	if unsafe then
		if state.cancelled then
			return false
		end
		state.hold_timer = minimum and 0 or hold_amount
		return true
	end
	state.cancelled = false
	if state.hold_timer > 0 then
		state.hold_timer = state.hold_timer - dt
		return true
	end
	return false
end

local quell_state = { hold_timer = 0, cancelled = false }
local plasma_vent_state = { hold_timer = 0, cancelled = false }
local last_gaze_state = false

local function clear_state()
	mod._sc_visible = false
	mod._sc_block_active = false
	mod._sc_pressed = EMPTY
	mod._sc_held = EMPTY
	mod._sc_release = EMPTY
	mod._sc_fire_request = false
	mod._sc_quell = false
	mod._sc_cast_held = false
	mod._sc_quell_interrupted = false
	mod._sc_plasma_vent = false
	mod._sc_plasma_vent_interrupted = false
	mod._sc_fire_charged = false
	fire_latched = false
	autofire_latched = false
	quell_state.hold_timer = 0
	quell_state.cancelled = false
	plasma_vent_state.hold_timer = 0
	plasma_vent_state.cancelled = false
	mod._sc_wield_guard = 0
	mod._sc_last_slot = false
	mod._sc_br_boundary = math.huge
	mod._sc_live_threshold = math.huge
	last_gaze_state = false
	gaze_forcing_quell = false
	gaze_active_timer = 0
	gaze_quell_duration = 0
	gaze_aborted = false
	gaze_exit_grace = 0
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
		local inv = unit_data:read_component("inventory")
		local slot_name = inv and inv.wielded_slot
		local slot = slot_name and slot_name ~= "none" and unit_data:read_component(slot_name)
		peril = slot and slot.overheat_current_percentage or 0
		charging = slot and slot.overheat_state == "increasing" or false
		overloading = slot and slot.overheat_state == "exploding" or false
		immune, effectively_immune, force_conclude, crystalline, cd = false, false, false, false, math.huge
	else
		local warp_charge = unit_data:read_component("warp_charge")
		peril = warp_charge.current_percentage or 0
		charging = warp_charge.state == "increasing"
		overloading = warp_charge.state == "exploding"
		immune = buff_ext:has_keyword(PSYCHIC_FORTRESS)
		cd = cfg.auto_ability and recovery_cooldown(unit) or math.huge
		crystalline = has_crystalline_will(unit)
		local ping_lead = math.min(last_ping, MAX_PING_LEAD)
		local imm_remaining = immune and immunity_remaining(buff_ext) or math.huge
		local lead = IMMUNITY_LEAD + ping_lead
		effectively_immune = immune and imm_remaining >= lead
		force_conclude = immune and imm_remaining < ping_lead + CONCLUDE_MARGIN
	end

	local scriers_active = has_scriers_gaze(buff_ext)

	-- Handle Gaze active timer and the post-Gaze exit grace transition
	if not scriers_active then
		if last_gaze_state then
			-- Transition frame: Gaze terminated, begin burst grace window
			gaze_exit_grace = GAZE_EXIT_GRACE_DURATION
		elseif gaze_exit_grace > 0 then
			gaze_exit_grace = math.max(0, gaze_exit_grace - dt)
		end
		gaze_forcing_quell = false
		gaze_active_timer = 0
		gaze_quell_duration = 0
		gaze_aborted = false
	else
		gaze_active_timer = gaze_active_timer + dt
		gaze_exit_grace = 0
	end
	last_gaze_state = scriers_active

	-- Dynamic Gaze Thresholds
	local current_gaze_threshold
	local current_gaze_release

	if gaze_active_timer >= GAZE_TIER2_CUTOFF then      -- 55s+
		current_gaze_threshold = GAZE_TRIGGER_TIER3
		current_gaze_release   = GAZE_RELEASE_TIER3
	elseif gaze_active_timer >= GAZE_TIER1_CUTOFF then  -- 30s - 55s
		current_gaze_threshold = GAZE_TRIGGER_TIER2
		current_gaze_release   = GAZE_RELEASE_TIER2
	else                                                -- 0s - 30s
		current_gaze_threshold = GAZE_TRIGGER_TIER1
		current_gaze_release   = GAZE_RELEASE_TIER1
	end

	-- Quell Watchdog Engine using dynamic config setting (0.0 to 3.0s)
	local max_quell_time = cfg.max_gaze_quell_duration or 1.0

	if scriers_active and not gaze_aborted then
		if not gaze_forcing_quell then
			if peril >= current_gaze_threshold then
				gaze_forcing_quell = true
				gaze_quell_duration = 0
			end
		else
			gaze_quell_duration = gaze_quell_duration + dt

			if gaze_quell_duration >= max_quell_time then
				-- Continuous quell exceeded slider limit: abort quelling and fire through to 100%
				gaze_aborted = true
				gaze_forcing_quell = false
				gaze_quell_duration = 0
				gaze_exit_grace = GAZE_EXIT_GRACE_DURATION
			elseif peril <= current_gaze_release then
				-- Normal clean exit
				gaze_forcing_quell = false
				gaze_quell_duration = 0
			end
		end
	else
		gaze_forcing_quell = false
		gaze_quell_duration = 0
	end

	local threshold
	if is_brain_rupture then
		if EMPOWERED_GRENADE and buff_ext:has_keyword(EMPOWERED_GRENADE) then
			threshold = math.huge
		else
			local stat_buffs = buff_ext:stat_buffs()
			local warp_charge_amount = (stat_buffs and stat_buffs.warp_charge_amount) or 1
			threshold = 1 - (1 - BRAIN_RUPTURE_EXTREME) * warp_charge_amount - BRAIN_RUPTURE_HEADROOM
		end
	elseif scriers_active and not gaze_aborted then
		threshold = current_gaze_threshold
	else
		threshold = CATEGORY_CAP[category] or PERIL_CAP
	end

	local at_cap = category ~= nil and not effectively_immune and peril >= threshold
	local unsafe = (at_cap and cd > cfg.recover_window) or overloading or gaze_forcing_quell

	-- Suppress the hard weapon block during Gaze AND throughout the post-Gaze burst grace window
	local suppress_block = scriers_active or (gaze_exit_grace > 0)
	local block_active = unsafe and not overloading and block_toggle_for(category)
		and not (crystalline and not cfg.block_crystalline) and not suppress_block
	mod._sc_block_active = block_active
	
	mod._sc_live_threshold = block_active and threshold or math.huge

	local br_armed = is_brain_rupture and not effectively_immune and cd > cfg.recover_window
		and not overloading and block_toggle_for(category)
		and not (crystalline and not cfg.block_crystalline)
	mod._sc_br_boundary = br_armed and threshold or math.huge
	
	local sets = category and CATEGORY_INPUTS[category]
	mod._sc_pressed = (block_active and sets) and sets.pressed or EMPTY
	
	local held = EMPTY
	if gaze_forcing_quell then
		held = { "action_one_hold", "action_two_hold" }
	elseif block_active and not charging and sets then
		held = sets.held
	end
	
	if is_brain_rupture then
		local weapon_action = unit_data:read_component("weapon_action")
		local action_name = weapon_action and weapon_action.current_action_name
		local in_locked_cast = action_name == "action_charge_target_sticky"
			or action_name == "action_charge_target_lock_on"
		held = (block_active and not in_locked_cast) and BR_HELD or EMPTY
	elseif held ~= EMPTY and category == "force_sword" and not gaze_forcing_quell then
		held = EMPTY
	elseif category == "staff" and mod._sc_cast_held and not gaze_forcing_quell then
		held = EMPTY
	end
	mod._sc_held = held
	mod._sc_release = (block_active and force_conclude and category == "staff") and STAFF_RELEASE or EMPTY

	local quell_allowed = (not overloading and not immune and VENTABLE[category]) or scriers_active

	if gaze_forcing_quell then
		mod._sc_quell = true
	else
		local quell_interrupted = mod._sc_quell_interrupted
		mod._sc_quell_interrupted = false
		mod._sc_quell = update_vent(quell_state, unsafe, quell_allowed,
			cfg.auto_quell_interrupt and mod._sc_cast_held, cfg.auto_quell_hold, quell_interrupted, dt)
	end

	local plasma_vent_allowed = cfg.auto_plasma_vent and is_overheat and not overloading or false
	local plasma_vent_interrupted = mod._sc_plasma_vent_interrupted
	mod._sc_plasma_vent_interrupted = false
	mod._sc_plasma_vent = update_vent(plasma_vent_state, unsafe, plasma_vent_allowed,
		false, cfg.auto_plasma_vent_hold, plasma_vent_interrupted, dt)

	if not is_overheat and not scriers_active then
		update_auto_ability(unit, overloading, peril, dt)
	end

	local autofire = cfg.auto_fire_before_unsafe and category == "staff" and charging
		and not overloading and block_toggle_for(category) and not effectively_immune
		and cd > cfg.recover_window and not (crystalline and not cfg.block_crystalline)
		and peril < threshold and peril >= threshold - AUTO_FIRE_MARGIN
	if autofire then
		if not autofire_latched then
			mod._sc_fire_charged = true
			autofire_latched = true
		end
	else
		autofire_latched = false
	end

	if unsafe and cfg.show_unsafe then
		mod._sc_visible = true
		mod._sc_text = cfg.word_unsafe
		mod._sc_color = cfg.unsafe_color
	elseif not unsafe and cfg.show_safe then
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
	
	local cast_held = false
	for i = 1, #CAST_HOLDS do
		if get_input(input_cache, lookup, CAST_HOLDS[i], index) then
			cast_held = true
			break
		end
	end
	mod._sc_cast_held = cast_held

	local pressed = mod._sc_pressed
	for i = 1, #pressed do
		set_input(input_cache, lookup, pressed[i], index, false)
	end
	local held = mod._sc_held
	for i = 1, #held do
		set_input(input_cache, lookup, held[i], index, false)
	end
	local release = mod._sc_release
	for i = 1, #release do
		set_input(input_cache, lookup, release[i], index, false)
	end

	if gaze_forcing_quell then
		set_input(input_cache, lookup, "action_one_pressed", index, false)
		set_input(input_cache, lookup, "action_one_hold", index, false)
		set_input(input_cache, lookup, "action_two_hold", index, false)
		set_input(input_cache, lookup, "weapon_extra_pressed", index, false)
	end

	if mod._sc_wield_guard > 0 then
		local guard_player = local_player()
		local guard_unit = guard_player and guard_player.player_unit
		if guard_unit and ALIVE[guard_unit] then
			local guard_ud = ScriptUnit.has_extension(guard_unit, "unit_data_system")
			if guard_ud then
				local wc = guard_ud:read_component("warp_charge")
				if wc and (wc.current_percentage or 0) >= 0.95 then
					set_input(input_cache, lookup, "action_one_pressed", index, false)
					set_input(input_cache, lookup, "action_one_hold", index, false)
					set_input(input_cache, lookup, "action_two_hold", index, false)
					set_input(input_cache, lookup, "weapon_extra_pressed", index, false)
				end
			end
		end
	end

	if mod._sc_live_threshold < math.huge then
		local live_player = local_player()
		local live_unit = live_player and live_player.player_unit
		if live_unit and ALIVE[live_unit] then
			local category, is_br = classify(live_unit)
			if not is_br and category ~= "force_sword" and category ~= "staff" then
				local live_ud = ScriptUnit.has_extension(live_unit, "unit_data_system")
				if live_ud then
					local wc = live_ud:read_component("warp_charge")
					if wc and (wc.current_percentage or 0) >= mod._sc_live_threshold then
						local active_pressed = mod._sc_pressed
						for i = 1, #active_pressed do
							set_input(input_cache, lookup, active_pressed[i], index, false)
						end
						set_input(input_cache, lookup, "action_one_hold", index, false)
						set_input(input_cache, lookup, "action_two_hold", index, false)
					end
				end
			end
		end
	end

	if mod._sc_br_boundary < math.huge then
		local br_player = local_player()
		local br_unit = br_player and br_player.player_unit
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

	if mod._sc_quell and not quell_interrupt_now then
		local is_sprinting = get_input(input_cache, lookup, "sprint", index) or get_input(input_cache, lookup, "sprint_hold", index)
		local hold_vent = mod._sc_wield_guard <= 0 and not is_sprinting
		set_input(input_cache, lookup, "weapon_reload_hold", index, hold_vent)
	end

	if mod._sc_plasma_vent and not plasma_vent_interrupt_now then
		local vent_player = local_player()
		local vent_unit = vent_player and vent_player.player_unit
		if vent_unit and ALIVE[vent_unit] and classify(vent_unit) == "plasma" then
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
	if mod._sc_fire_charged then
		set_input(input_cache, lookup, "action_one_pressed", index, true)
		mod._sc_fire_charged = false
	end
end)

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
	if not mod._sc_block_active or self._action_component_name ~= "weapon_action" then
		return
	end
	if self._player ~= local_player() then
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