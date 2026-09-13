-- Adapted from BetterBots (MIT License, Copyright (c) 2026 Matthias Humt).
-- Holds weapon input for automatic or beam-style ranged weapons after a bot fires.

local STALE_WINDOW_S = 0.25
local TEMPLATE_REFRESH_INTERVAL_S = 0.10

local M = {}

local _mod
local _fixed_time = function()
	return 0
end
local _is_enabled
local _active_state_by_unit = setmetatable({}, { __mode = "k" })
local _warned_errors = {}

local CLEAR_ACTION_INPUTS = {
	reload = true,
	brace_reload = true,
	wield = true,
	vent = true,
	vent_release = true,
	shoot_release = true,
	shoot_braced_release = true,
	zoom_release = true,
	brace_release = true,
	cancel_flame = true,
	charge_release = true,
}

local SHOOT_AND_ZOOM_HOLD = {
	shoot = { action_one_hold = true },
	zoom_shoot = { action_one_hold = true },
}

local ZOOM_ONLY_HOLD = {
	zoom_shoot = { action_one_hold = true },
}

local SUSTAINED_TEMPLATE_ACTIONS = {
	flamer_p1_m1 = {
		shoot_braced = { action_one_hold = true },
	},
	forcestaff_p2_m1 = {
		trigger_charge_flame = { action_two_hold = true },
	},
	lasgun_p3_m1 = SHOOT_AND_ZOOM_HOLD,
	lasgun_p3_m2 = SHOOT_AND_ZOOM_HOLD,
	lasgun_p3_m3 = SHOOT_AND_ZOOM_HOLD,
	autogun_p1_m1 = SHOOT_AND_ZOOM_HOLD,
	autogun_p1_m2 = SHOOT_AND_ZOOM_HOLD,
	autogun_p1_m3 = SHOOT_AND_ZOOM_HOLD,
	autogun_p2_m1 = SHOOT_AND_ZOOM_HOLD,
	autogun_p2_m2 = SHOOT_AND_ZOOM_HOLD,
	autogun_p2_m3 = SHOOT_AND_ZOOM_HOLD,
	autopistol_p1_m1 = SHOOT_AND_ZOOM_HOLD,
	dual_autopistols_p1_m1 = SHOOT_AND_ZOOM_HOLD,
	bolter_p1_m2 = {
		shoot_pressed = { action_one_hold = true },
	},
	ogryn_heavystubber_p1_m1 = SHOOT_AND_ZOOM_HOLD,
	ogryn_heavystubber_p1_m2 = SHOOT_AND_ZOOM_HOLD,
	ogryn_heavystubber_p1_m3 = SHOOT_AND_ZOOM_HOLD,
	ogryn_heavystubber_p2_m1 = SHOOT_AND_ZOOM_HOLD,
	ogryn_heavystubber_p2_m2 = SHOOT_AND_ZOOM_HOLD,
	ogryn_heavystubber_p2_m3 = SHOOT_AND_ZOOM_HOLD,
	ogryn_rippergun_p1_m1 = ZOOM_ONLY_HOLD,
	ogryn_rippergun_p1_m2 = ZOOM_ONLY_HOLD,
}

local function copy_table(src)
	local dst = {}

	for key, value in pairs(src or {}) do
		dst[key] = value
	end

	return dst
end

local function current_weapon_template_name(unit)
	local unit_data_extension = unit and ScriptUnit.has_extension(unit, "unit_data_system")

	if not unit_data_extension then
		return nil
	end

	local weapon_action = unit_data_extension:read_component("weapon_action")

	return weapon_action and weapon_action.template_name or nil
end

local function live_weapon_template_name(unit, state, current_template_name)
	local now = _fixed_time()

	if current_template_name ~= nil then
		state.live_template_name = current_template_name
		state.live_template_t = now

		return current_template_name
	end

	if state.live_template_t and now - state.live_template_t < TEMPLATE_REFRESH_INTERVAL_S then
		return state.live_template_name
	end

	local live_template_name = current_weapon_template_name(unit)
	state.live_template_name = live_template_name
	state.live_template_t = now

	return live_template_name
end

function M.init(deps)
	deps = deps or {}
	_mod = deps.mod
	_fixed_time = deps.fixed_time or _fixed_time
	_is_enabled = deps.is_enabled
	_active_state_by_unit = setmetatable({}, { __mode = "k" })
end

function M.resolve_state(unit, template_name, action_input)
	local actions = SUSTAINED_TEMPLATE_ACTIONS[template_name]
	local hold_inputs = actions and actions[action_input]

	if not hold_inputs then
		return nil
	end

	return {
		unit = unit,
		template_name = template_name,
		live_template_name = template_name,
		action_input = action_input,
		hold_inputs = copy_table(hold_inputs),
		last_seen_t = _fixed_time(),
		live_template_t = _fixed_time(),
	}
end

function M.clear(unit)
	_active_state_by_unit[unit] = nil
end

function M.observe_weapon_action_input(unit, template_name, action_input)
	if not unit or not template_name then
		return nil
	end

	if CLEAR_ACTION_INPUTS[action_input] then
		M.clear(unit)
		return nil
	end

	local state = M.resolve_state(unit, template_name, action_input)

	if state then
		_active_state_by_unit[unit] = state
		return state
	end

	local active = _active_state_by_unit[unit]

	if active and active.template_name == template_name and active.action_input ~= action_input then
		M.clear(unit)
	end

	return nil
end

function M.observe_queued_weapon_action(unit, action_input)
	return M.observe_weapon_action_input(unit, current_weapon_template_name(unit), action_input)
end

function M.update_actions(unit, input, current_template_name)
	local state = _active_state_by_unit[unit]

	if not state then
		return
	end

	local live_template_name = live_weapon_template_name(unit, state, current_template_name)

	if live_template_name ~= state.template_name then
		M.clear(unit)
		return
	end

	if _fixed_time() - state.last_seen_t > STALE_WINDOW_S then
		M.clear(unit)
		return
	end

	for hold_input, value in pairs(state.hold_inputs) do
		input[hold_input] = value
	end
end

function M.install_bot_unit_input_hooks(BotUnitInput)
	_mod:hook(BotUnitInput, "update", function(func, self, unit, dt, t)
		self._ccb_player_unit = unit

		return func(self, unit, dt, t)
	end)

	_mod:hook(BotUnitInput, "_update_actions", function(func, self, input)
		func(self, input)

		if _is_enabled and not _is_enabled() then
			return
		end

		local ok, err = pcall(M.update_actions, self._ccb_player_unit, input)

		if not ok then
			local key = tostring(err)

			if not _warned_errors[key] then
				_warned_errors[key] = true
				_mod:warning("Custom Character Bots sustained-fire hook error: " .. key)
			end
		end
	end)
end

return M
