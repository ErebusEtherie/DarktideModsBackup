-- Author: ImperialSkoom
-- Notes:
-- The native sprint path was consistently more reliable than any helper-driven
-- fake sprint path we tested. Direct action start, sprint override, tap/held
-- helper routes, and queued early presses all introduced edge cases ranging
-- from wrong-branch heavies/lights to awkward movement pacing and input-hook
-- timing bugs. Future work should start from the main sprint route and only
-- add state-driven assists that prove they do not degrade that baseline feel.
local mod = get_mod("SprintRelicHeavy")

local HEALTH_ALIVE = HEALTH_ALIVE
local InputService = InputService
local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit

local RELIC_BLADE_WEAPONS = {
	powersword_2h_p1_m1 = true,
	powersword_2h_p1_m2 = true,
}

local MANUAL_OVERRIDE_DURATION = 0.20
local INTERRUPT_OVERRIDE_DURATION = 0.20
local DEFAULT_SPRINT_PRIME_DELAY = 0.02
local DEFAULT_BLOCK_CANCEL_HOLD = 0.10
local BLOCK_CANCEL_TIMEOUT = 0.25
local HEAVY_PRESS_RETRY = 0.08
local HEAVY_FAIL_TIMEOUT = 0.18
local WRONG_BRANCH_ABORT_TIME = 0.04
local SEEK_STAB_TIMEOUT = 0.45
local AUTO_FORWARD_PRIME_DELAY = 0.06
local DEBUG_NOTIFY_COOLDOWN = 0.20

local CROSSHAIR_GREEN = { 255, 64, 255, 96 }
local CROSSHAIR_RED = { 255, 255, 176, 72 }
local CROSSHAIR_WHITE = { 255, 255, 255, 255 }
local CROSSHAIR_YELLOW = { 255, 255, 220, 64 }

local INTERCEPTED_INPUTS = {
	action_one_hold = true,
	action_one_pressed = true,
	action_two_hold = true,
	weapon_extra_pressed = true,
	weapon_extra_hold = true,
	weapon_reload_hold = true,
	quick_wield = true,
	dodge = true,
	sprint = true,
	sprinting = true,
	hold_to_sprint = true,
	move_forward = true,
}

local cached_input = {
	sprint = false,
	sprinting = false,
	hold_to_sprint = false,
	move_forward = nil,
}

local controller = {
	override_until_t = 0,
	interrupt_until_t = 0,
	external_hold_override = false,
	sequence_state = "idle",
	sequence_started_t = 0,
	last_heavy_press_t = 0,
	release_started_t = 0,
	stab_consumed = false,
	stab_hit_confirmed = false,
	path_confirmed = false,
	attempt_id = 0,
	trace_attempt = nil,
	last_debug_signature = "",
	last_debug_notify_t = 0,
}

local player_weapon_extension = nil
local setting_enabled = true
local sprint_prime_delay = DEFAULT_SPRINT_PRIME_DELAY
local use_block_cancel = true
local block_cancel_hold = DEFAULT_BLOCK_CANCEL_HOLD
local debug_mode = false
local trace_mode = false

local function refresh_settings()
	local stored_enable_mod = mod:get("enable_mod")
	local stored_use_block_cancel = mod:get("use_block_cancel")
	local stored_debug_mode = mod:get("debug_mode")
	local stored_trace_mode = mod:get("trace_mode")

	setting_enabled = stored_enable_mod == nil and true or stored_enable_mod
	use_block_cancel = stored_use_block_cancel == nil and true or stored_use_block_cancel
	debug_mode = stored_debug_mode == nil and false or stored_debug_mode
	trace_mode = stored_trace_mode == nil and false or stored_trace_mode
end

local function gameplay_time()
	if not (Managers and Managers.time) then
		return 0
	end

	local ok, t = pcall(Managers.time.time, Managers.time, "gameplay")
	return ok and type(t) == "number" and t or 0
end

local function local_player()
	local player_manager = Managers and Managers.player
	return player_manager and player_manager:local_player_safe(1)
end

local function local_player_unit()
	local player = local_player()
	return player and player.player_unit
end

local function ui_using_input()
	return Managers and Managers.ui and Managers.ui:using_input() or false
end

local function in_hub()
	local state_manager = Managers and Managers.state
	local game_mode_manager = state_manager and state_manager.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
	return game_mode_name == "hub"
end

local function reset_controller()
	controller.override_until_t = 0
	controller.interrupt_until_t = 0
	controller.external_hold_override = false
	controller.sequence_state = "idle"
	controller.sequence_started_t = 0
	controller.last_heavy_press_t = 0
	controller.release_started_t = 0
	controller.stab_consumed = false
	controller.stab_hit_confirmed = false
	controller.path_confirmed = false
	controller.attempt_id = 0
	controller.trace_attempt = nil
	controller.last_debug_signature = ""
	controller.last_debug_notify_t = 0
	cached_input.sprint = false
	cached_input.sprinting = false
	cached_input.hold_to_sprint = false
	cached_input.move_forward = nil
end

local function reset_sequence()
	controller.sequence_state = "idle"
	controller.sequence_started_t = 0
	controller.last_heavy_press_t = 0
	controller.release_started_t = 0
	controller.stab_consumed = false
	controller.stab_hit_confirmed = false
	controller.path_confirmed = false
	controller.trace_attempt = nil
end

local function cache_input(action_name, value)
	if INTERCEPTED_INPUTS[action_name] then
		cached_input[action_name] = value
	end
end

local function raw_input_value(input_service, action_name)
	local action_rule = input_service and input_service._actions and input_service._actions[action_name]

	if not action_rule then
		return nil
	end

	if action_rule.filter then
		return action_rule.eval_func(action_rule.eval_obj, action_rule.eval_param)
	end

	local out = action_rule.default_func()
	local action_type = action_rule.type
	local action_type_data = action_type and InputService.ACTION_TYPES[action_type]
	local combiner = action_type_data and action_type_data.combine_func

	if not combiner then
		return out
	end

	for _, cb in ipairs(action_rule.callbacks) do
		out = combiner(out, cb())
	end

	return out
end

local function manual_override_active()
	return gameplay_time() < (controller.override_until_t or 0)
end

local function trigger_manual_override()
	controller.override_until_t = gameplay_time() + MANUAL_OVERRIDE_DURATION
end

local function interrupt_override_active()
	return gameplay_time() < (controller.interrupt_until_t or 0)
end

local function trigger_interrupt_override()
	controller.interrupt_until_t = gameplay_time() + INTERRUPT_OVERRIDE_DURATION
end

local function set_external_hold_override(active)
	controller.external_hold_override = active and true or false
end

local function toggle_mod_enabled()
	setting_enabled = not setting_enabled
	mod:set("enable_mod", setting_enabled, true)

	if not setting_enabled then
		reset_sequence()
	end

	mod:notify(string.format(
		"SprintRelicHeavy: %s",
		setting_enabled and "Enabled" or "Disabled"
	))
end

local function current_weapon_template()
	if not player_weapon_extension then
		return nil
	end

	local inventory = player_weapon_extension._inventory_component
	local wielded_slot = inventory and inventory.wielded_slot
	local wielded_weapon = wielded_slot and player_weapon_extension._weapons and player_weapon_extension._weapons[wielded_slot]

	return wielded_weapon and wielded_weapon.weapon_template
end

local function is_relic_blade()
	local player_unit = local_player_unit()

	if not player_unit or not HEALTH_ALIVE[player_unit] or not Unit.alive(player_unit) then
		return false
	end

	local weapon_template = current_weapon_template()
	local keywords = weapon_template and weapon_template.keywords

	if not weapon_template or not keywords or not table.array_contains(keywords, "melee") then
		return false
	end

	return RELIC_BLADE_WEAPONS[weapon_template.name] == true
end

local function read_component(component_name)
	local player_unit = local_player_unit()
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	return unit_data_extension and unit_data_extension:read_component(component_name)
end

local function is_sprinting()
	local sprint_component = read_component("sprint_character_state")
	return sprint_component and sprint_component.is_sprinting or false
end

local function is_blocking()
	local block_component = read_component("block")
	return block_component and block_component.is_blocking or false
end

local function sprint_requested()
	return cached_input.sprint or cached_input.hold_to_sprint or cached_input.sprinting or is_sprinting()
end

local function live_sprint_input_requested()
	return cached_input.sprint or cached_input.hold_to_sprint or cached_input.sprinting
end

local function helper_trigger_requested()
	return setting_enabled and live_sprint_input_requested()
end

local function moving_forward_requested()
	return type(cached_input.move_forward) == "number" and cached_input.move_forward > 0
end

local function using_auto_forward()
	return helper_trigger_requested() and not moving_forward_requested()
end

local function current_weapon_action_component()
	return player_weapon_extension and player_weapon_extension._weapon_action_component or nil
end

local function current_action_name()
	local weapon_action_component = current_weapon_action_component()
	return weapon_action_component and weapon_action_component.current_action_name or "none"
end

local function current_action_start_t()
	local weapon_action_component = current_weapon_action_component()
	return weapon_action_component and weapon_action_component.start_t or 0
end

local function current_action_t()
	return gameplay_time() - current_action_start_t()
end

local function current_action_settings()
	local weapon_template = current_weapon_template()
	local action_name = current_action_name()
	local actions = weapon_template and weapon_template.actions
	return actions and action_name and actions[action_name] or nil
end

local function current_sweep_state()
	local action_sweep_component = read_component("action_sweep")
	return action_sweep_component and action_sweep_component.sweep_state or "before_damage_window"
end

local function sprint_stab_action_active()
	return current_action_name() == "action_sprint_heavy_stab"
end

local function sprint_stab_windup_active()
	return current_action_name() == "action_melee_start_sprint"
end

local function on_sprint_stab_path()
	return sprint_stab_windup_active() or sprint_stab_action_active()
end

local function sprint_stab_boost_active()
	local action_name = current_action_name()
	local action_t = current_action_t()

	if action_name == "action_melee_start_sprint" then
		return action_t >= 0.50
	elseif action_name == "action_sprint_heavy_stab" then
		return action_t >= 0.15 and action_t <= 0.45
	end

	return false
end

local function wrong_attack_branch_active(action_name)
	return (string.find(action_name or "", "action_heavy_") or string.find(action_name or "", "action_light_"))
		and action_name ~= "action_sprint_heavy_stab"
		and action_name ~= "action_melee_start_sprint"
end

local function heavy_chain_time()
	local action_settings = current_action_settings()
	local allowed_chain_actions = action_settings and action_settings.allowed_chain_actions
	local heavy_chain = allowed_chain_actions and (allowed_chain_actions.heavy_attack or allowed_chain_actions.special_action_heavy)
	return heavy_chain and heavy_chain.chain_time or nil
end

local function heavy_chain_ready()
	local chain_time = heavy_chain_time()
	return chain_time ~= nil and current_action_t() >= chain_time or false
end

local function block_chain_time()
	local action_settings = current_action_settings()
	local allowed_chain_actions = action_settings and action_settings.allowed_chain_actions
	local block_chain = allowed_chain_actions and allowed_chain_actions.block
	return block_chain and block_chain.chain_time or nil
end

local function block_chain_ready()
	local chain_time = block_chain_time()
	return chain_time ~= nil and current_action_t() >= chain_time or false
end

local function windup_release_ready()
	return sprint_stab_windup_active() and heavy_chain_ready()
end

local function helper_startup_ready()
	return true
end

local function trace_log(message, ...)
	if not trace_mode then
		return
	end

	mod:echo("[RelicTrace] " .. string.format(message, ...))
end

local function attempt_source_label()
	return "sprint"
end

local function live_charge_hold_requested()
	return setting_enabled and live_sprint_input_requested()
end

local function start_trace_attempt(now)
	controller.attempt_id = controller.attempt_id + 1
	controller.trace_attempt = {
		id = controller.attempt_id,
		source = attempt_source_label(),
		start_t = now,
		windup_t = nil,
		ready_t = nil,
		stab_t = nil,
		hit_t = nil,
		consumed_t = nil,
	}
end

local function mark_trace_time(field_name, now)
	local attempt = controller.trace_attempt

	if attempt and attempt[field_name] == nil then
		attempt[field_name] = now
	end
end

local function trace_delta(attempt, field_name)
	local event_t = attempt and attempt[field_name]
	local start_t = attempt and attempt.start_t

	if not event_t or not start_t then
		return "n/a"
	end

	return string.format("%.3f", event_t - start_t)
end

local function trace_attempt_result(result, now)
	local attempt = controller.trace_attempt

	if not trace_mode or not attempt then
		controller.trace_attempt = nil
		return
	end

	trace_log(
		"#%d src=%s result=%s start->windup=%s start->ready=%s start->stab=%s start->hit=%s start->consumed=%s end=%.3f",
		attempt.id,
		attempt.source,
		result,
		trace_delta(attempt, "windup_t"),
		trace_delta(attempt, "ready_t"),
		trace_delta(attempt, "stab_t"),
		trace_delta(attempt, "hit_t"),
		trace_delta(attempt, "consumed_t"),
		now - attempt.start_t
	)

	controller.trace_attempt = nil
end

local function debug_signature()
	local chain_time = heavy_chain_time()
	local current_t = current_action_t()
	local rounded_action_t = string.format("%.2f", current_t)
	local rounded_chain_time = chain_time and string.format("%.2f", chain_time) or "n/a"

	return table.concat({
		current_action_name(),
		controller.sequence_state,
		current_sweep_state(),
		rounded_action_t,
		rounded_chain_time,
		tostring(heavy_chain_ready()),
		tostring(is_sprinting()),
	}, "|")
end

local function maybe_debug_notify()
	if not debug_mode or not mod:is_enabled() or in_hub() or not is_relic_blade() then
		return
	end

	local now = gameplay_time()
	local signature = debug_signature()

	if signature == controller.last_debug_signature then
		return
	end

	if now < controller.last_debug_notify_t + DEBUG_NOTIFY_COOLDOWN then
		controller.last_debug_signature = signature
		return
	end

	controller.last_debug_signature = signature
	controller.last_debug_notify_t = now

	local chain_time = heavy_chain_time()
	local action_name = current_action_name()
	local sweep_state = current_sweep_state()
	local message = string.format(
		"RelicDbg: %s | seq=%s | sweep=%s | t=%.2f | heavy_chain=%s | ready=%s | sprint=%s",
		action_name,
		controller.sequence_state,
		sweep_state,
		current_action_t(),
		chain_time and string.format("%.2f", chain_time) or "n/a",
		heavy_chain_ready() and "yes" or "no",
		is_sprinting() and "yes" or "no"
	)

	mod:notify(message)
end

local function trigger_requested()
	return setting_enabled and live_sprint_input_requested()
end

local function assist_input_requested()
	return setting_enabled and live_sprint_input_requested()
end

local function sequence_is_active()
	return controller.sequence_state ~= "idle"
end

local function sequence_should_stay_latched()
	local state = controller.sequence_state

	return state == "windup_path"
		or state == "stab_path"
		or state == "block_cancel"
		or state == "waiting_ready"
end

local function should_run()
	if not mod:is_enabled() then
		return false
	end

	if not setting_enabled then
		return false
	end

	if ui_using_input() or in_hub() or not is_relic_blade() then
		return false
	end

	if interrupt_override_active() then
		return false
	end

	if sequence_is_active()
		and not controller.path_confirmed
		and (manual_override_active() or controller.external_hold_override) then
		return false
	end

	if sequence_is_active() and (trigger_requested() or sequence_should_stay_latched()) then
		return true
	end

	if not trigger_requested() then
		return false
	end

	if manual_override_active() then
		return false
	end

	if controller.external_hold_override then
		return false
	end

	return true
end

local function should_force_sprint(state)
	if not assist_input_requested() then
		return false
	end

	if state == "priming_sprint" or state == "seeking_stab" then
		return true
	end

	return false
end

local function should_force_forward(state)
	if not assist_input_requested() or moving_forward_requested() then
		return false
	end

	return state ~= "idle" and state ~= "block_cancel"
end

local function begin_attempt(now)
	controller.sequence_state = "priming_sprint"
	controller.sequence_started_t = now
	controller.last_heavy_press_t = 0
	controller.release_started_t = 0
	controller.stab_consumed = false
	controller.stab_hit_confirmed = false
	controller.path_confirmed = false
	start_trace_attempt(now)
end

local function update_sequence_state()
	local now = gameplay_time()
	local action_name = current_action_name()
	local sweep_state = current_sweep_state()
	local state = controller.sequence_state

	if not should_run() then
		if controller.trace_attempt then
			trace_attempt_result("cancelled", now)
		end
		reset_sequence()
		return controller.sequence_state
	end

	if state == "idle" then
		begin_attempt(now)
	elseif state == "priming_sprint" then
		if sprint_stab_windup_active() then
			mark_trace_time("windup_t", now)
			controller.sequence_state = "windup_path"
			controller.path_confirmed = windup_release_ready()
			if controller.path_confirmed then
				mark_trace_time("ready_t", now)
			end
		elseif sprint_stab_action_active() then
			mark_trace_time("stab_t", now)
			controller.sequence_state = "stab_path"
			controller.path_confirmed = true
		else
			local prime_delay = sprint_prime_delay

			-- Treat the helper hotkey like a full sprint+forward intent so it keeps
			-- the fast route even when the player is not manually holding W.
			if using_auto_forward() then
				prime_delay = math.max(prime_delay, AUTO_FORWARD_PRIME_DELAY)
			end

			if now >= controller.sequence_started_t + prime_delay
				and helper_startup_ready() then
				controller.sequence_state = "seeking_stab"
				controller.last_heavy_press_t = 0
			end
		end
	elseif state == "seeking_stab" then
		if sprint_stab_windup_active() then
			mark_trace_time("windup_t", now)
			controller.sequence_state = "windup_path"
			controller.path_confirmed = windup_release_ready()
			if controller.path_confirmed then
				mark_trace_time("ready_t", now)
			end
		elseif sprint_stab_action_active() then
			mark_trace_time("stab_t", now)
			controller.sequence_state = "stab_path"
			controller.path_confirmed = true
		elseif wrong_attack_branch_active(action_name) and current_action_t() >= WRONG_BRANCH_ABORT_TIME then
			trace_attempt_result("wrong_branch", now)
			controller.sequence_state = "waiting_ready"
		elseif now >= controller.sequence_started_t + sprint_prime_delay + SEEK_STAB_TIMEOUT then
			if trigger_requested() then
				trace_attempt_result("seek_timeout_retry", now)
				begin_attempt(now)
			else
				trace_attempt_result("seek_timeout", now)
				reset_sequence()
			end
		end
	elseif state == "windup_path" then
		if sprint_stab_action_active() then
			mark_trace_time("stab_t", now)
			controller.sequence_state = "stab_path"
			controller.path_confirmed = true
		elseif action_name ~= "action_melee_start_sprint" then
			trace_attempt_result("windup_lost", now)
			controller.sequence_state = "waiting_ready"
		elseif windup_release_ready() then
			controller.path_confirmed = true
			mark_trace_time("ready_t", now)
		end
	elseif state == "stab_path" then
		if action_name == "action_sprint_heavy_stab" and sweep_state ~= "before_damage_window" then
			controller.stab_consumed = true
			mark_trace_time("consumed_t", now)
		end

		if use_block_cancel and controller.stab_hit_confirmed and block_chain_ready() then
			controller.sequence_state = "block_cancel"
			controller.release_started_t = now
		elseif action_name ~= "action_melee_start_sprint" and action_name ~= "action_sprint_heavy_stab" then
			trace_attempt_result(controller.stab_hit_confirmed and "hit_complete" or controller.stab_consumed and "stab_complete" or "stab_lost", now)
			controller.sequence_state = "waiting_ready"
		elseif controller.stab_consumed then
			if not use_block_cancel then
				trace_attempt_result("stab_complete", now)
				controller.sequence_state = "waiting_ready"
			end
		end
	elseif state == "block_cancel" then
		if (action_name == "action_block" or is_blocking()) and now >= controller.release_started_t + block_cancel_hold then
			trace_attempt_result(controller.stab_hit_confirmed and "hit_block_cancel" or "block_cancel", now)
			controller.sequence_state = "waiting_ready"
		elseif now >= controller.release_started_t + BLOCK_CANCEL_TIMEOUT then
			trace_attempt_result(controller.stab_hit_confirmed and "hit_block_timeout" or "block_timeout", now)
			controller.sequence_state = "waiting_ready"
		end
	elseif state == "waiting_ready" and action_name == "none" then
		if trigger_requested() then
			begin_attempt(now)
		else
			reset_sequence()
		end
	end

	return controller.sequence_state
end

local function is_crosshair_hit_indicator_style(style_name)
	return type(style_name) == "string" and string.find(style_name, "^hit_") ~= nil
end

local function clone_color(color)
	return { color[1], color[2], color[3], color[4] }
end

local function crosshair_state_color()
	if not mod:is_enabled() or in_hub() or not is_relic_blade() then
		return nil
	end

	local state = controller.sequence_state
	local action_name = current_action_name()
	local sweep_state = current_sweep_state()

	if windup_release_ready()
		or action_name == "action_sprint_heavy_stab" and sweep_state == "before_damage_window" then
		return CROSSHAIR_GREEN
	end

	if action_name == "action_sprint_heavy_stab" and sweep_state ~= "before_damage_window"
		or state == "block_cancel"
		or state == "waiting_ready" then
		return CROSSHAIR_RED
	end

	if state == "priming_sprint"
		or state == "seeking_stab"
		or state == "windup_path"
		or sprint_stab_windup_active()
		or sprint_stab_boost_active() then
		return CROSSHAIR_GREEN
	end

	return CROSSHAIR_WHITE
end

local function apply_crosshair_tint(widget, tint_color)
	if not widget or not widget.style then
		return
	end

	widget.content = widget.content or {}
	local tint_cache = widget.content.sprint_relic_stab_tint_cache

	if not tint_cache then
		tint_cache = {}
		widget.content.sprint_relic_stab_tint_cache = tint_cache
	end

	for style_name, style_data in pairs(widget.style) do
		local color = style_data and style_data.color

		if color and not is_crosshair_hit_indicator_style(style_name) then
			if tint_color then
				if not tint_cache[style_name] then
					tint_cache[style_name] = clone_color(color)
				end

				color[1] = tint_color[1]
				color[2] = tint_color[2]
				color[3] = tint_color[3]
				color[4] = tint_color[4]
			else
				local original_color = tint_cache[style_name]

				if original_color then
					color[1] = original_color[1]
					color[2] = original_color[2]
					color[3] = original_color[3]
					color[4] = original_color[4]
					tint_cache[style_name] = nil
				end
			end
		end
	end
end

local function input_hook(func, self, action_name)
	local raw_value = INTERCEPTED_INPUTS[action_name] and raw_input_value(self, action_name) or nil
	local value = func(self, action_name)

	if self.type ~= "Ingame" or not INTERCEPTED_INPUTS[action_name] then
		return value
	end

	cache_input(action_name, value)

	local state = update_sequence_state()
	local now = gameplay_time()

	if action_name == "action_one_hold" then
		local external_primary_hold = value and not raw_value

		if external_primary_hold and not sequence_is_active() then
			set_external_hold_override(true)
			trigger_manual_override()
			return value
		elseif not value and not raw_value and not sequence_is_active() then
			set_external_hold_override(false)
		end
	end

	if action_name == "action_one_hold" and value and not sequence_is_active() then
		trigger_manual_override()
		return value
	end

	if action_name == "action_one_hold" and not value and not sequence_is_active() then
		set_external_hold_override(false)
	end

	if action_name == "action_one_pressed" and value and not sequence_is_active() then
		trigger_manual_override()
		return value
	end

	local raw_active = raw_value == true or raw_value == 1
	local dodge_interrupt = action_name == "dodge" and raw_active and not (live_sprint_input_requested() and moving_forward_requested())
	local manual_primary_interrupt = (action_name == "action_one_hold" or action_name == "action_one_pressed")
		and raw_active
		and sequence_is_active()
		and not controller.path_confirmed

	if manual_primary_interrupt then
		trigger_manual_override()
		reset_sequence()
		return value
	end

	if ((action_name == "action_two_hold"
		or action_name == "weapon_extra_pressed"
		or action_name == "weapon_extra_hold"
		or action_name == "weapon_reload_hold"
		or action_name == "quick_wield")
		and raw_active)
		or dodge_interrupt then
		trigger_interrupt_override()
		reset_sequence()
		return value
	end

	if (action_name == "action_two_hold"
		or action_name == "weapon_extra_pressed"
		or action_name == "weapon_extra_hold"
		or action_name == "weapon_reload_hold"
		or action_name == "quick_wield")
		and value then
		trigger_manual_override()
		return value
	end

	if action_name == "move_forward" and should_force_forward(state) and not ui_using_input() and not in_hub() then
		return 1
	end

	if (action_name == "sprint" or action_name == "sprinting" or action_name == "hold_to_sprint")
		and should_force_sprint(state) then
		return true
	end

	if action_name == "action_one_pressed"
		and state == "seeking_stab"
		and current_action_name() == "none"
		and helper_startup_ready()
		and now >= controller.last_heavy_press_t + HEAVY_PRESS_RETRY then
		controller.last_heavy_press_t = now
		return true
	end

	if action_name == "action_one_hold"
		and ((state == "seeking_stab"
				and helper_startup_ready()
				and assist_input_requested()
				and not wrong_attack_branch_active(current_action_name()))
			or (state == "windup_path"
				and (not windup_release_ready() or live_charge_hold_requested()))) then
		return true
	end

	if action_name == "action_two_hold" and state == "block_cancel" then
		return true
	end

	if action_name == "action_one_hold"
		and (state == "priming_sprint"
			or state == "block_cancel"
			or state == "waiting_ready") then
		return false
	end

	return value
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self)
	local player = local_player()

	if player and self._player == player then
		player_weapon_extension = self
		reset_controller()
	end
end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit)
	local player_unit = local_player_unit()

	if player_unit and unit == player_unit then
		player_weapon_extension = self
	end
end)

mod:hook_safe(CLASS.HudElementCrosshair, "update", function(self)
	apply_crosshair_tint(self._widget, crosshair_state_color())
	maybe_debug_notify()
end)

mod:hook_safe(CLASS.AttackReportManager, "_process_attack_result", function(self, buffer_data)
	if not use_block_cancel or not mod:is_enabled() or in_hub() or not is_relic_blade() then
		return
	end

	local player_unit = local_player_unit()
	local attacking_unit = buffer_data and buffer_data.attacking_unit
	local damage = buffer_data and buffer_data.damage or 0
	local did_damage = damage > 0

	if attacking_unit ~= player_unit or not did_damage then
		return
	end

	if controller.sequence_state == "stab_path"
		and (current_action_name() == "action_sprint_heavy_stab" or controller.stab_consumed) then
		controller.stab_hit_confirmed = true
		mark_trace_time("hit_t", gameplay_time())
	end
end)

mod:hook(CLASS.InputService, "_get", input_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_hook)
mod:hook("SkitariusOmnissiah", "omnissiah", function(func, self, queried_input, user_value)
	local outcome = func(self, queried_input, user_value)
	local bind_manager = self.bind_manager
	local engram = self.engram
	local skitarius_melee_override = bind_manager
		and bind_manager.override_primary
		and bind_manager:override_primary()
		and engram
		and engram.TYPE == "MELEE"
		and engram:current_command() ~= nil

	if queried_input == "action_one_hold" or queried_input == "action_one_pressed" then
		if skitarius_melee_override and outcome then
			set_external_hold_override(true)
			trigger_manual_override()
		elseif queried_input == "action_one_hold" and not outcome then
			set_external_hold_override(false)
		end
	end

	return outcome
end)

function mod.toggle_mod_enabled(pressed)
	if pressed then
		toggle_mod_enabled()
	end
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "enable_mod"
		or setting_id == "use_block_cancel"
		or setting_id == "debug_mode"
		or setting_id == "trace_mode" then
		refresh_settings()
		reset_sequence()
	end
end

mod.on_disabled = function()
	player_weapon_extension = nil
	refresh_settings()
	reset_controller()
end

refresh_settings()
