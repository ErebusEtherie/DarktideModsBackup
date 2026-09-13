local mod = get_mod("Guaranteed_Special_joERodman")

local WIELD_INPUTS = {
	quick_wield = "quick",
	wield_1 = "primary",
	wield_2 = "secondary",
	wield_3 = "pocketable",
	wield_4 = "pocketable_small",
	wield_5 = "device",
	grenade_ability_pressed = "grenade",
}

local SLOT_FOR_REQUEST = {
	quick = nil,
	primary = "slot_primary",
	secondary = "slot_secondary",
	pocketable = "slot_pocketable",
	pocketable_small = "slot_pocketable_small",
	device = "slot_device",
	grenade = "slot_grenade_ability",
}

local REQUEST_FOR_SLOT = {
	slot_primary = "primary",
	slot_secondary = "secondary",
	slot_pocketable = "pocketable",
	slot_pocketable_small = "pocketable_small",
	slot_device = "device",
	slot_grenade_ability = "grenade",
}

local ACTIVE_STATES = {
	dodging = true,
	falling = true,
	jumping = true,
	ledge_vaulting = true,
	lunging = true,
	sliding = true,
	sprinting = true,
	stunned = true,
	walking = true,
}

local QUICK_BLITZES = {
	zealot_throwing_knives = true,
	broker_flash_grenade = true,
	broker_flash_grenade_improved = true,
	cryptic_servo_skull_order_base = true,
	cryptic_force_field = true,
}

local RETRY_INTERVAL = 0.05
local PLAYER_SPECIAL_QUEUE_TIME = 0.25

local queued_wields = {}
local special_queued = false
local player_special_queued = false
local player_special_queue_expires_at = 0
local current_slot = ""
local character_state = ""
local grenade_ability = ""
local is_in_hub = false
local last_wield_retry = 0

local settings = {
	enable_guaranteed_special = mod:get("enable_guaranteed_special"),
	queue_limit = mod:get("queue_limit"),
	enable_quick_grenades = mod:get("enable_quick_grenades"),
}

local function now()
	return Managers.time and Managers.time:time("main") or 0
end

local function is_local_player(self)
	return self._player and self._player.viewport_name == "player1"
end

local function clear_wields()
	table.clear(queued_wields)
end

local function clear_player_special()
	player_special_queued = false
	player_special_queue_expires_at = 0
end

local function player_special_is_queued()
	if player_special_queued and now() >= player_special_queue_expires_at then
		clear_player_special()
	end

	return player_special_queued
end

local function remove_wield(request)
	for index, queued_request in ipairs(queued_wields) do
		if queued_request == request then
			table.remove(queued_wields, index)
			return
		end
	end
end

local function enqueue_wield(request)
	table.insert(queued_wields, request)
	local limit = settings.queue_limit or 3
	while #queued_wields > limit do
		table.remove(queued_wields, 1)
	end
end

local function queued_wield_is_due(request)
	if queued_wields[1] ~= request then
		return false
	end

	local requested_slot = SLOT_FOR_REQUEST[request]
	if requested_slot and current_slot == requested_slot then
		remove_wield(request)
		return false
	end

	if now() - last_wield_retry < RETRY_INTERVAL then
		return false
	end

	last_wield_retry = now()
	return true
end

local function refresh_hub_state()
	local game_mode = Managers.state.game_mode
	is_in_hub = game_mode and game_mode:game_mode_name() == "hub" or false
end

local function refresh_character_state(self)
	character_state = self._state_current and self._state_current.name or ""
	if not ACTIVE_STATES[character_state] then
		clear_wields()
		special_queued = false
		clear_player_special()
	end
end

local function refresh_equipped_abilities(self)
	local equipped = self._equipped_abilities
	grenade_ability = equipped and equipped.grenade_ability and equipped.grenade_ability.name or ""
end

local function refresh_wielded_slot(self)
	current_slot = self._inventory_component and self._inventory_component.wielded_slot or ""
	remove_wield("quick")
	remove_wield(REQUEST_FOR_SLOT[current_slot])
end

mod.on_setting_changed = function(setting_id)
	settings[setting_id] = mod:get(setting_id)
	if setting_id == "enable_guaranteed_special" and not settings.enable_guaranteed_special then
		special_queued = false
		clear_player_special()
	end
end

mod.on_all_mods_loaded = refresh_hub_state
mod.on_game_state_changed = refresh_hub_state

mod:hook_safe("GameplayStateRun", "on_enter", function()
	clear_wields()
	special_queued = false
	clear_player_special()
	refresh_hub_state()
end)

mod:hook_safe("GameplayStateRun", "on_exit", function()
	clear_wields()
	special_queued = false
	clear_player_special()
end)

mod:hook_safe("PlayerUnitWeaponExtension", "fixed_update", function(self)
	if is_local_player(self) then
		refresh_wielded_slot(self)
	end
end)

mod:hook_safe("PlayerUnitWeaponExtension", "on_slot_wielded", function(self)
	if is_local_player(self) then
		refresh_wielded_slot(self)
	end
end)

mod:hook_safe("PlayerUnitWeaponExtension", "server_correction_occurred", function(self)
	if is_local_player(self) then
		refresh_wielded_slot(self)
	end
end)

mod:hook_safe("CharacterStateMachine", "fixed_update", function(self)
	if self._unit_data_extension and self._unit_data_extension._player.viewport_name == "player1" then
		refresh_character_state(self)
	end
end)

mod:hook_safe("CharacterStateMachine", "_change_state", function(self)
	if self._unit_data_extension and self._unit_data_extension._player.viewport_name == "player1" then
		refresh_character_state(self)
	end
end)

mod:hook_safe("PlayerUnitAbilityExtension", "fixed_update", function(self)
	if is_local_player(self) then
		refresh_equipped_abilities(self)
	end
end)

mod:hook_safe("PlayerUnitAbilityExtension", "_equip_ability", function(self)
	if is_local_player(self) then
		refresh_equipped_abilities(self)
	end
end)

mod:hook("PlayerUnitWeaponExtension", "can_wield", function(func, self, slot_name)
	local can_wield = func(self, slot_name)
	if is_local_player(self) and not can_wield then
		remove_wield(REQUEST_FOR_SLOT[slot_name])
	end
	return can_wield
end)

mod:hook("PlayerUnitAbilityExtension", "can_wield", function(func, self, slot_name, previous_check)
	local can_wield = func(self, slot_name, previous_check)
	if is_local_player(self) and not can_wield then
		remove_wield(REQUEST_FOR_SLOT[slot_name])
	end
	return can_wield
end)

mod:hook("PlayerUnitWeaponExtension", "action_input_is_currently_valid", function(func, self, component_name, action_input, used_input, fixed_t)
	local valid = func(self, component_name, action_input, used_input, fixed_t)
	if is_local_player(self) and special_queued and valid and used_input == "weapon_extra_pressed" then
		special_queued = false
	end
	return valid
end)

mod:hook("PlayerUnitAbilityExtension", "action_input_is_currently_valid", function(func, self, component_name, action_input, used_input, fixed_t)
	local valid = func(self, component_name, action_input, used_input, fixed_t)
	if is_local_player(self) and player_special_is_queued() and valid and used_input == "combat_ability_pressed" then
		player_special_queued = false
	end
	return valid
end)

local function input_hook(func, self, action_name)
	local original = func(self, action_name)
	local pressed = original == true or type(original) == "number" and original > 0

	if is_in_hub or not ACTIVE_STATES[character_state] then
		return original
	end

	local wield_request = WIELD_INPUTS[action_name]
	if wield_request then
		if pressed then
			local is_quick_blitz = action_name == "grenade_ability_pressed" and QUICK_BLITZES[grenade_ability]
			if not is_quick_blitz or settings.enable_quick_grenades then
				enqueue_wield(wield_request)
			end
		end
		return original or queued_wield_is_due(wield_request)
	end

	if action_name == "weapon_extra_pressed" then
		if settings.enable_guaranteed_special and pressed then
			special_queued = true
		end
		return original or special_queued
	end

	if action_name == "combat_ability_pressed" then
		if settings.enable_guaranteed_special and pressed then
			player_special_queued = true
			player_special_queue_expires_at = now() + PLAYER_SPECIAL_QUEUE_TIME
		end
		return original or player_special_is_queued()
	end

	return original
end

mod:hook("InputService", "_get", input_hook)
mod:hook("InputService", "_get_simulate", input_hook)
