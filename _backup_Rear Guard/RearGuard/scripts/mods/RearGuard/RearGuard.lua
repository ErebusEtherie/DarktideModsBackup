-- Author: ImperialSkoom

local mod = get_mod("RearGuard")

local BACKSTAB_MELEE_EVENTS = {
	["wwise/events/player/play_backstab_indicator_melee"] = true,
	["wwise/events/player/play_backstab_indicator_melee_elite"] = true,
}

local block_until_t = 0
local next_trigger_t = 0
local dodge_until_t = 0
local parry_press_queued = false

local DEFAULT_BLOCK_DURATION = 0.18
local DEFAULT_DODGE_QUEUE_DURATION = 0.08
local DEFAULT_TRIGGER_COOLDOWN = 0.1

local function main_time()
	if Managers and Managers.time then
		return Managers.time:time("main")
	end

	return 0
end

local function local_player_unit()
	local player_manager = Managers and Managers.player
	local player = player_manager and player_manager:local_player_safe(1)

	return player and player.player_unit
end

local function is_melee_equipped()
	local player_unit = local_player_unit()
	local weapon_extension = player_unit and ScriptUnit.has_extension(player_unit, "weapon_system")
	local inventory = weapon_extension and weapon_extension._inventory_component

	if inventory and inventory.wielded_slot == "slot_primary" then
		return true
	end

	local wielded_weapon = weapon_extension and weapon_extension:_wielded_weapon(inventory, weapon_extension._weapons)
	local weapon_template = wielded_weapon and wielded_weapon.weapon_template
	local keywords = weapon_template and weapon_template.keywords

	return keywords and table.array_contains(keywords, "melee") or false
end

local function wielded_weapon_template()
	local player_unit = local_player_unit()
	local weapon_extension = player_unit and ScriptUnit.has_extension(player_unit, "weapon_system")
	local inventory = weapon_extension and weapon_extension._inventory_component
	local wielded_weapon = weapon_extension and weapon_extension:_wielded_weapon(inventory, weapon_extension._weapons)

	return wielded_weapon and wielded_weapon.weapon_template or nil
end

local function should_use_weapon_special()
	local weapon_template = wielded_weapon_template()
	local weapon_name = weapon_template and weapon_template.name

	if not weapon_name then
		return false
	end

	return string.find(weapon_name, "^combatsword_p1_m%d+$") ~= nil
		or string.find(weapon_name, "^combatsword_p3_m%d+$") ~= nil
end

local function wielded_slot_name()
	local player_unit = local_player_unit()
	local weapon_extension = player_unit and ScriptUnit.has_extension(player_unit, "weapon_system")
	local inventory = weapon_extension and weapon_extension._inventory_component

	return inventory and inventory.wielded_slot or nil
end

local function is_ranged_or_blitz_active()
	local slot_name = wielded_slot_name()

	return slot_name == "slot_secondary" or slot_name == "slot_grenade_ability"
end

local function can_force_block()
	if is_ranged_or_blitz_active() then
		return false
	end

	return is_melee_equipped()
end

local function should_trigger_for_event(wwise_event_name)
	return BACKSTAB_MELEE_EVENTS[wwise_event_name] and mod:get("trigger_on_melee") or false
end

local function response_mode()
	return mod:get("response_mode") or "block"
end

local function numeric_setting(setting_id, default_value, min_value)
	local value = tonumber(mod:get(setting_id))

	if not value then
		return default_value
	end

	if min_value and value < min_value then
		return min_value
	end

	return value
end

local function block_duration()
	return numeric_setting("block_duration", DEFAULT_BLOCK_DURATION, 0)
end

local function dodge_queue_duration()
	return numeric_setting("dodge_queue_duration", DEFAULT_DODGE_QUEUE_DURATION, 0)
end

local function trigger_cooldown()
	return numeric_setting("trigger_cooldown", DEFAULT_TRIGGER_COOLDOWN, 0)
end

local function set_response_mode(mode)
	mod:set("response_mode", mode)
end

local function response_mode_localization_id(mode)
	if mode == "dodge" then
		return "response_mode_dodge"
	end

	if mode == "both" then
		return "response_mode_both"
	end

	return "response_mode_block"
end

local function is_valid_other_unit(value, player_unit)
	if type(value) ~= "userdata" then
		return false
	end

	local ok, is_valid = pcall(Unit.is_valid, value)
	return ok and is_valid and value ~= player_unit
end

local function can_trigger_response()
	return main_time() >= next_trigger_t
end

local function begin_trigger_cooldown()
	next_trigger_t = main_time() + trigger_cooldown()
end

local function mark_block_window()
	block_until_t = math.max(block_until_t, main_time() + block_duration())
	parry_press_queued = should_use_weapon_special()
end

local function queue_dodge()
	dodge_until_t = math.max(dodge_until_t, main_time() + dodge_queue_duration())
end

local function should_force_block()
	local mode = response_mode()

	if mode ~= "block" and mode ~= "both" then
		return false
	end

	if not mod:is_enabled() then
		return false
	end

	if block_until_t <= main_time() then
		return false
	end

	if Managers.ui and Managers.ui:using_input() then
		return false
	end

	if not can_force_block() then
		return false
	end

	local player_unit = local_player_unit()

	return player_unit and Unit.alive(player_unit) or false
end

local function should_force_weapon_special()
	return should_force_block() and should_use_weapon_special()
end

local function should_force_dodge()
	local mode = response_mode()

	if mode ~= "dodge" and mode ~= "both" then
		return false
	end

	if not mod:is_enabled() or dodge_until_t <= main_time() then
		return false
	end

	if Managers.ui and Managers.ui:using_input() then
		return false
	end

	local player_unit = local_player_unit()

	return player_unit and Unit.alive(player_unit) or false
end

local function input_hook(func, self, action_name)
	local value = func(self, action_name)

	if action_name == "weapon_extra_pressed" and should_force_weapon_special() and parry_press_queued then
		parry_press_queued = false
		return true
	end

	if action_name == "weapon_extra_hold" and should_force_weapon_special() then
		return true
	end

	if action_name == "action_two_hold" and should_force_block() and not should_use_weapon_special() then
		return true
	end

	if action_name == "dodge" and should_force_dodge() then
		dodge_until_t = 0
		return true
	end

	return value
end

mod.on_all_mods_loaded = function()
	mod:hook_safe(WwiseWorld, "trigger_resource_event", function(_wwise_world, wwise_event_name, unit_or_position_or_id)
		if not should_trigger_for_event(wwise_event_name) then
			return
		end

		if not can_trigger_response() then
			return
		end

		local player_unit = local_player_unit()
		if not player_unit then
			return
		end

		if is_valid_other_unit(unit_or_position_or_id, player_unit) then
			return
		end

		local mode = response_mode()
		local triggered_response = false

		if mode == "dodge" or mode == "both" then
			queue_dodge()
			triggered_response = true
		end

		if mode == "block" or mode == "both" then
			if can_force_block() then
				mark_block_window()
				triggered_response = true
			end
		end

		if triggered_response then
			begin_trigger_cooldown()
		end
	end)

	mod:hook(CLASS.InputService, "_get", input_hook)
	mod:hook(CLASS.InputService, "_get_simulate", input_hook)
end

mod.update = function()
	if block_until_t > 0 and block_until_t <= main_time() then
		block_until_t = 0
		parry_press_queued = false
	end

	if dodge_until_t > 0 and dodge_until_t <= main_time() then
		dodge_until_t = 0
	end
end

mod.cycle_response_mode = function()
	local mode = response_mode()
	local new_mode = "block"

	if mode == "block" then
		new_mode = "dodge"
	elseif mode == "dodge" then
		new_mode = "both"
	end

	set_response_mode(new_mode)
	mod:echo_localized("response_mode_switched", mod:localize(response_mode_localization_id(new_mode)))
end

mod.on_disabled = function()
	block_until_t = 0
	next_trigger_t = 0
	dodge_until_t = 0
end
