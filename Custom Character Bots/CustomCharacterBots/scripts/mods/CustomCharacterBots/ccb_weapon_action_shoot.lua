-- Adapted from BetterBots (MIT License, Copyright (c) 2026 Matthias Humt).
-- Keeps bot shoot scratchpads aligned with the currently wielded player weapon.

local M = {}

local function find_action_for_start_input(actions, input_name)
	for action_name, action in pairs(actions or {}) do
		if action.start_input == input_name then
			return action_name, action
		end
	end

	return nil, nil
end

local function find_unaim_action_for_action(weapon_template, action)
	local actions = weapon_template and weapon_template.actions or {}
	local unaim_input = action and action.stop_input

	if unaim_input then
		local unaim_action_name = find_action_for_start_input(actions, unaim_input)

		return unaim_input, unaim_action_name
	end

	for input_name, chain_entry in pairs((action and action.allowed_chain_actions) or {}) do
		local action_name = chain_entry and chain_entry.action_name
		local target_action = action_name and actions[action_name]

		if target_action and target_action.kind == "unaim" then
			return input_name, action_name
		end
	end

	return nil, nil
end

local function has_hold_start_input(weapon_template, input_name)
	local input_def = weapon_template and weapon_template.action_inputs and weapon_template.action_inputs[input_name]
	local seq = input_def and input_def.input_sequence
	local first = seq and seq[1]

	return first and first.input == "action_two_hold" and first.value == true
end

local function weapon_template_supports_input(weapon_template, input_name)
	return type(input_name) == "string"
		and type(weapon_template and weapon_template.action_inputs) == "table"
		and weapon_template.action_inputs[input_name] ~= nil
end

local DIRECT_FIRE_INPUT_PREFERENCE = { "shoot_pressed", "shoot_charge", "shoot" }

local function find_direct_fire_input(weapon_template)
	local action_inputs = weapon_template and weapon_template.action_inputs or {}
	local actions = weapon_template and weapon_template.actions or {}
	local candidates = {}

	for input_name, input_def in pairs(action_inputs) do
		local seq = input_def and input_def.input_sequence
		local first = seq and seq[1]

		if first and first.input == "action_one_pressed" and first.value == true and not first.hold_input then
			local action_name = find_action_for_start_input(actions, input_name)

			if action_name then
				candidates[#candidates + 1] = input_name
			end
		end
	end

	for _, preferred in ipairs(DIRECT_FIRE_INPUT_PREFERENCE) do
		for _, input_name in ipairs(candidates) do
			if input_name == preferred then
				return input_name
			end
		end
	end

	return candidates[1]
end

local function clear_stale_aim_inputs(weapon_template, scratchpad)
	local changed = false

	if scratchpad.aim_action_input and not weapon_template_supports_input(weapon_template, scratchpad.aim_action_input) then
		scratchpad.aim_action_input = nil
		scratchpad.aim_action_name = nil
		changed = true
	end

	if scratchpad.unaim_action_input and (
		scratchpad.aim_action_input == nil
		or not weapon_template_supports_input(weapon_template, scratchpad.unaim_action_input)
	) then
		scratchpad.unaim_action_input = nil
		scratchpad.unaim_action_name = nil
		changed = true
	end

	return changed
end

local function find_aim_chain(weapon_template, aim_fire_input)
	for action_name, action in pairs(weapon_template and weapon_template.actions or {}) do
		local start_input = action.start_input

		if start_input and has_hold_start_input(weapon_template, start_input) then
			local chain_entry = (action.allowed_chain_actions or {})[aim_fire_input]

			if chain_entry then
				local unaim_input, unaim_action_name = find_unaim_action_for_action(weapon_template, action)

				return start_input, action_name, unaim_input, unaim_action_name
			end
		end
	end

	return nil, nil, nil, nil
end

function M.normalize(weapon_template, scratchpad)
	if type(weapon_template) ~= "table" or type(scratchpad) ~= "table" then
		return false
	end

	local changed = false

	if weapon_template.name == "ogryn_gauntlet_p1_m1" then
		local gauntlet_fields = {
			fire_action_input = "zoom_shoot",
			aim_fire_action_input = "zoom_shoot",
			aim_action_input = "zoom",
			aim_action_name = "action_zoom",
			unaim_action_input = "zoom_release",
			unaim_action_name = "action_unzoom",
			max_range_sq = 28 * 28,
		}

		for key, value in pairs(gauntlet_fields) do
			if scratchpad[key] ~= value then
				scratchpad[key] = value
				changed = true
			end
		end

		if not scratchpad.aiming_shot then
			scratchpad.aiming_shot = true
			scratchpad.aim_done_t = 0
			changed = true
		end
	end

	if weapon_template.name and string.find(weapon_template.name, "^lasgun_p2_") then
		local helbore_fields = {
			fire_action_input = "shoot_release_charged",
			aim_fire_action_input = "zoom_shoot_release_charged",
			aim_action_input = "zoom",
			aim_action_name = "action_zoom",
			unaim_action_input = "zoom_release",
			unaim_action_name = "action_unzoom",
			charge_action_input = "zoom_shoot_hold",
			can_charge_shot = true,
			always_charge_before_firing = true,
			minimum_charge_time = 0.2,
			charge_shot_delay = 0.05,
			max_range_sq = 45 * 45,
			max_range_sq_charged = 60 * 60,
		}

		for key, value in pairs(helbore_fields) do
			if scratchpad[key] ~= value then
				scratchpad[key] = value
				changed = true
			end
		end
	end

	if scratchpad.fire_action_input and not weapon_template_supports_input(weapon_template, scratchpad.fire_action_input) then
		local fire_input = find_direct_fire_input(weapon_template)

		if fire_input then
			scratchpad.fire_action_input = fire_input
			changed = true
		end
	end

	if
		scratchpad.aim_fire_action_input
		and not weapon_template_supports_input(weapon_template, scratchpad.aim_fire_action_input)
		and weapon_template_supports_input(weapon_template, scratchpad.fire_action_input)
	then
		scratchpad.aim_fire_action_input = scratchpad.fire_action_input
		changed = true
	end

	if scratchpad.aim_fire_action_input then
		local aim_input, aim_action_name, unaim_input, unaim_action_name =
			find_aim_chain(weapon_template, scratchpad.aim_fire_action_input)

		if aim_input then
			if scratchpad.aim_action_input ~= aim_input then
				scratchpad.aim_action_input = aim_input
				changed = true
			end

			if aim_action_name and scratchpad.aim_action_name ~= aim_action_name then
				scratchpad.aim_action_name = aim_action_name
				changed = true
			end

			if unaim_input and scratchpad.unaim_action_input ~= unaim_input then
				scratchpad.unaim_action_input = unaim_input
				changed = true
			end

			if unaim_action_name and scratchpad.unaim_action_name ~= unaim_action_name then
				scratchpad.unaim_action_name = unaim_action_name
				changed = true
			end
		end
	end

	return clear_stale_aim_inputs(weapon_template, scratchpad) or changed
end

function M.supports_input(weapon_template, input_name)
	return weapon_template_supports_input(weapon_template, input_name)
end

return M
