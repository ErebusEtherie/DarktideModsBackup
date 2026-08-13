local mod = get_mod("GetOutOfTheWay")

local DEFAULT_NODE_NAME = "j_spine"

local RESCUE_STATES = {
	hogtied = true,
	knocked_down = true,
	ledge_hanging = true,
	netted = true,
}

local SUPPORT_ITEM_TEMPLATES = {
	ammo_cache_pocketable = true,
	medical_crate_pocketable = true,
	syringe_ability_boost_pocketable = true,
	syringe_corruption_pocketable = true,
	syringe_power_boost_pocketable = true,
	syringe_speed_boost_pocketable = true,
}

local player_fade_profiles = {}
local rescue_visibility_active = {}
local support_item_visibility_active = false
local fade_system_instance

local function should_override_fade(owner, unit, breed_name)
	if owner.player_unit == unit then
		return owner.remote and (not mod:get("only_ogryn") or breed_name == "ogryn")
	end

	if breed_name == "companion_dog" then
		if not owner.remote then
			return mod:get("apply_to_my_cyber_mastiff")
		end

		if mod:get("only_ogryn") then
			return false
		end

		return mod:get("apply_to_cyber_mastiff")
	end

	if breed_name == "companion_servo_skull" then
		if not owner.remote then
			return mod:get("apply_to_my_servo_skull")
		end

		if mod:get("only_ogryn") then
			return false
		end

		return mod:get("apply_to_servo_skull")
	end

	return false
end

local function replace_fade_registration(unit, profile)
	local native_fade_system = fade_system_instance and fade_system_instance._fade_system

	if not native_fade_system or not unit or (ALIVE and not ALIVE[unit]) then
		return false
	end

	Fade.unregister_unit(native_fade_system, unit)
	Fade.register_unit(
		native_fade_system,
		unit,
		profile.min_distance,
		profile.max_distance,
		profile.max_height_difference,
		profile.node_name
	)

	return true
end

local function apply_player_fade_profile(unit)
	local profiles = player_fade_profiles[unit]

	if not profiles then
		return false
	end

	local use_official_profile = support_item_visibility_active
		or rescue_visibility_active[unit] == true
	local profile = use_official_profile and profiles.official or profiles.normal

	return replace_fade_registration(unit, profile)
end

local function set_rescue_visibility(unit, visible)
	local profiles = player_fade_profiles[unit]
	local is_active = rescue_visibility_active[unit] == true

	if not profiles or is_active == visible then
		return
	end

	if visible and not mod:get("keep_rescue_targets_visible") then
		return
	end

	local previous_state = rescue_visibility_active[unit]

	rescue_visibility_active[unit] = visible or nil

	if not apply_player_fade_profile(unit) then
		rescue_visibility_active[unit] = previous_state
	end
end

local function is_holding_support_item()
	if not mod:get("keep_allies_visible_while_holding_support_items") then
		return false
	end

	local player_manager = Managers and Managers.player
	local player = player_manager and player_manager:local_player_safe(1)
	local player_unit = player and player.player_unit

	if not player_unit or ALIVE and not ALIVE[player_unit] then
		return false
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local inventory = unit_data_extension
		and unit_data_extension.read_component
		and unit_data_extension:read_component("inventory")
	local wielded_slot = inventory and inventory.wielded_slot

	if wielded_slot ~= "slot_pocketable" and wielded_slot ~= "slot_pocketable_small" then
		return false
	end

	local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	local weapon_template = visual_loadout_extension
		and visual_loadout_extension:weapon_template_from_slot(wielded_slot)

	return weapon_template and SUPPORT_ITEM_TEMPLATES[weapon_template.name] == true or false
end

mod.update = function(dt)
	local active = is_holding_support_item()

	if active == support_item_visibility_active then
		return
	end

	support_item_visibility_active = active

	for unit, _ in pairs(player_fade_profiles) do
		apply_player_fade_profile(unit)
	end
end

mod:hook(CLASS.FadeSystem, "on_add_extension", function(func, self, world, unit, extension_name)
	local state = Managers.state
	local player_unit_spawn = state and state.player_unit_spawn
	local owner = player_unit_spawn and player_unit_spawn:owner(unit)

	if not owner then
		return func(self, world, unit, extension_name)
	end

	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	local fade = breed and breed.fade
	local breed_name = breed and breed.name
	local override_fade = fade and should_override_fade(owner, unit, breed_name)
	local registered_min_distance = override_fade
		and (mod:get("min_distance") or fade.min_distance)
	local registered_max_distance = override_fade
		and math.max(registered_min_distance, mod:get("max_distance") or fade.max_distance)
	local registered_max_height_difference = override_fade
		and math.max(registered_min_distance, mod:get("max_height_difference") or fade.max_height_difference)
	local registered_node_name = fade and fade.node_name or DEFAULT_NODE_NAME
	local official_profile = override_fade and {
		min_distance = fade.min_distance,
		max_distance = fade.max_distance,
		max_height_difference = fade.max_height_difference,
		node_name = registered_node_name,
	}
	local extension

	if override_fade then
		local old_min_distance = fade.min_distance
		local old_max_distance = fade.max_distance
		local old_max_height_difference = fade.max_height_difference

		fade.min_distance = registered_min_distance
		fade.max_distance = registered_max_distance
		fade.max_height_difference = registered_max_height_difference

		local success, extension_or_error = xpcall(
			func,
			debug.traceback,
			self,
			world,
			unit,
			extension_name
		)

		fade.min_distance = old_min_distance
		fade.max_distance = old_max_distance
		fade.max_height_difference = old_max_height_difference

		if not success then
			error(extension_or_error, 0)
		end

		extension = extension_or_error
	else
		extension = func(self, world, unit, extension_name)
	end

	fade_system_instance = self

	if override_fade and owner.player_unit == unit and owner.remote then
		player_fade_profiles[unit] = {
			normal = {
				min_distance = registered_min_distance,
				max_distance = registered_max_distance,
				max_height_difference = registered_max_height_difference,
				node_name = registered_node_name,
			},
			official = official_profile,
		}

		local character_state = unit_data_extension
			and unit_data_extension.read_component
			and unit_data_extension:read_component("character_state")

		if character_state and RESCUE_STATES[character_state.state_name] then
			set_rescue_visibility(unit, true)
		end

		if support_item_visibility_active and rescue_visibility_active[unit] ~= true then
			apply_player_fade_profile(unit)
		end
	end

	return extension
end)

mod:hook_safe(CLASS.FadeSystem, "on_remove_extension", function(self, unit, extension_name)
	player_fade_profiles[unit] = nil
	rescue_visibility_active[unit] = nil
end)

local function on_rescue_state_enter(self, unit)
	set_rescue_visibility(unit, true)
end

local function on_rescue_state_exit(self, unit, t, next_state)
	if not RESCUE_STATES[next_state] then
		set_rescue_visibility(unit, false)
	end
end

for _, state_class in ipairs({
	CLASS.PlayerCharacterStateKnockedDown,
	CLASS.PlayerCharacterStateNetted,
	CLASS.PlayerCharacterStateLedgeHanging,
	CLASS.PlayerCharacterStateHogtied,
}) do
	mod:hook_safe(state_class, "on_enter", on_rescue_state_enter)
	mod:hook_safe(state_class, "on_exit", on_rescue_state_exit)
end
