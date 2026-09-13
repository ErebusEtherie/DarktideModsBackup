-- Partly adapted from BetterBots (MIT License, Copyright (c) 2026 Matthias Humt).
-- Opportunistically queues weapon-special inputs for saved-loadout bots.

local M = {}

local _mod
local _is_enabled
local _armored_type
local _super_armor_type
local _armor
local _armed_state_by_unit = setmetatable({}, { __mode = "k" })

local SPECIAL_TARGET_DISTANCE = 3.25

local FIRE_ACTION_INPUTS = {
	shoot = true,
	shoot_braced = true,
	shoot_pressed = true,
	zoom_shoot = true,
	shoot_release_charged = true,
	zoom_shoot_release_charged = true,
}

local MELEE_ATTACK_INPUTS = {
	start_attack = true,
	light_attack = true,
	heavy_attack = true,
}

local CLEAR_ACTION_INPUTS = {
	reload = true,
	wield = true,
	vent = true,
	zoom = true,
	zoom_release = true,
}

local SUPPORTED_SHOTGUN_TEMPLATES = {
	shotgun_p1_m1 = true,
	shotgun_p1_m2 = true,
	shotgun_p1_m3 = true,
	shotgun_p4_m1 = true,
	shotgun_p4_m2 = true,
}

local SUPPORTED_RIPPERGUN_TEMPLATES = {
	ogryn_rippergun_p1_m1 = true,
	ogryn_rippergun_p1_m2 = true,
	ogryn_rippergun_p1_m3 = true,
}

local SUPPORTED_RANGED_SPECIAL_INPUTS = {
	autogun_p2_m1 = "special_action",
	autogun_p2_m2 = "special_action",
	autogun_p2_m3 = "special_action",
	bolter_p1_m1 = "special_action",
	bolter_p1_m2 = "special_action",
	boltpistol_p1_m1 = "special_action",
	boltpistol_p1_m2 = "special_action",
	dual_autopistols_p1_m1 = "weapon_special",
	flamer_p1_m1 = "special_action",
	laspistol_p1_m1 = "special_action_push",
	laspistol_p1_m3 = "special_action_push",
	ogryn_heavystubber_p1_m1 = "stab",
	ogryn_heavystubber_p1_m2 = "stab",
	ogryn_heavystubber_p1_m3 = "stab",
	ogryn_thumper_p1_m1 = "bash",
	stubrevolver_p1_m1 = "special_action_pistol_whip",
	stubrevolver_p1_m2 = "special_action_pistol_whip",
}

local SPECIAL_INPUT_PREFERENCE = {
	"special_action",
	"weapon_special",
	"special_action_start",
	"special_action_push",
	"stab",
	"bash",
}

local function unit_data_extension(unit)
	return unit and ScriptUnit.has_extension(unit, "unit_data_system") or nil
end

local function current_weapon_template_name(unit)
	local extension = unit_data_extension(unit)
	local weapon_action_component = extension and extension:read_component("weapon_action")

	return weapon_action_component and weapon_action_component.template_name or nil
end

local function current_wielded_slot_component(unit)
	local extension = unit_data_extension(unit)

	if not extension then
		return nil
	end

	local inventory_component = extension:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot

	return wielded_slot and extension:read_component(wielded_slot) or nil
end

local function current_target_enemy(unit)
	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]
	local perception = blackboard and blackboard.perception

	return perception and perception.target_enemy or nil
end

local function current_target_distance(unit)
	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]
	local perception = blackboard and blackboard.perception
	local distance = perception and perception.target_enemy_distance

	return type(distance) == "number" and distance or nil
end

local function current_target_breed(unit)
	local target_unit = current_target_enemy(unit)
	local extension = target_unit and ScriptUnit.has_extension(target_unit, "unit_data_system")

	if not extension or not extension.breed then
		return nil
	end

	return extension:breed()
end

local function armor_api()
	if _armor then
		return _armor
	end

	local global_armor = rawget(_G, "Armor")

	if global_armor then
		_armor = global_armor

		return _armor
	end

	local ok, armor = pcall(require, "scripts/utilities/attack/armor")

	if ok then
		_armor = armor
	elseif _mod and _mod.warning then
		_mod:warning("Custom Character Bots: failed to load armor utility for weapon specials.")
	end

	return _armor
end

local function current_target_armor(unit, target_breed)
	local armor = armor_api()
	local target_unit = current_target_enemy(unit)

	if not armor or not target_unit or not target_breed then
		return nil
	end

	return armor.armor_type(target_unit, target_breed)
end

local function is_priority_target(target_breed, target_armor)
	local tags = target_breed and target_breed.tags

	if not target_breed then
		return false
	end

	if target_breed.is_boss then
		return true
	end

	if tags and (tags.monster or tags.captain or tags.special or tags.elite) then
		return true
	end

	return (_armored_type and target_armor == _armored_type)
		or (_super_armor_type and target_armor == _super_armor_type)
end

local function should_use_close_special(unit)
	local distance = current_target_distance(unit)

	if type(distance) ~= "number" or distance > SPECIAL_TARGET_DISTANCE then
		return false
	end

	local target_breed = current_target_breed(unit)
	local target_armor = current_target_armor(unit, target_breed)

	return is_priority_target(target_breed, target_armor)
end

local function weapon_templates()
	local ok, templates = pcall(require, "scripts/settings/equipment/weapon_templates/weapon_templates")

	return ok and templates or nil
end

local function action_input_exists(template_name, input_name)
	local templates = weapon_templates()
	local template = templates and templates[template_name]
	local action_inputs = template and template.action_inputs

	return type(action_inputs) == "table" and action_inputs[input_name] ~= nil
end

local function first_supported_special_input(template_name)
	for _, input_name in ipairs(SPECIAL_INPUT_PREFERENCE) do
		if action_input_exists(template_name, input_name) then
			return input_name
		end
	end

	return nil
end

function M.init(deps)
	deps = deps or {}
	_mod = deps.mod
	_is_enabled = deps.is_enabled
	_armored_type = deps.ARMOR_TYPE_ARMORED
	_super_armor_type = deps.ARMOR_TYPE_SUPER_ARMOR
	_armor = nil
	_armed_state_by_unit = setmetatable({}, { __mode = "k" })
end

function M.rewrite_weapon_action_input(unit, action_input, raw_input)
	if (_is_enabled and not _is_enabled()) or not unit then
		return action_input, raw_input
	end

	local template_name = current_weapon_template_name(unit)

	if not template_name then
		return action_input, raw_input
	end

	if SUPPORTED_SHOTGUN_TEMPLATES[template_name] and FIRE_ACTION_INPUTS[action_input] then
		local active = _armed_state_by_unit[unit]

		if active and active.template_name == template_name then
			return action_input, raw_input
		end

		local slot_component = current_wielded_slot_component(unit)

		if not (slot_component and slot_component.special_active) then
			local target_breed = current_target_breed(unit)
			local target_armor = current_target_armor(unit, target_breed)

			if is_priority_target(target_breed, target_armor) and action_input_exists(template_name, "special_action") then
				return "special_action", raw_input
			end
		end
	end

	if SUPPORTED_RIPPERGUN_TEMPLATES[template_name] and FIRE_ACTION_INPUTS[action_input] and should_use_close_special(unit) then
		if action_input_exists(template_name, "stab") then
			return "stab", raw_input
		end
	end

	local ranged_special_input = SUPPORTED_RANGED_SPECIAL_INPUTS[template_name]

	if ranged_special_input and FIRE_ACTION_INPUTS[action_input] and should_use_close_special(unit) then
		if action_input_exists(template_name, ranged_special_input) then
			return ranged_special_input, raw_input
		end
	end

	if MELEE_ATTACK_INPUTS[action_input] and should_use_close_special(unit) then
		local slot_component = current_wielded_slot_component(unit)

		if slot_component and slot_component.special_active then
			return action_input, raw_input
		end

		local active = _armed_state_by_unit[unit]

		if active and active.template_name == template_name then
			return action_input, raw_input
		end

		local special_input = first_supported_special_input(template_name)

		if special_input then
			return special_input, raw_input
		end
	end

	return action_input, raw_input
end

function M.observe_queued_weapon_action(unit, action_input, original_action_input)
	if (_is_enabled and not _is_enabled()) or not unit then
		return
	end

	local template_name = current_weapon_template_name(unit)

	if not template_name then
		return
	end

	local active = _armed_state_by_unit[unit]

	if active and active.template_name ~= template_name then
		_armed_state_by_unit[unit] = nil
		active = nil
	end

	if SUPPORTED_SHOTGUN_TEMPLATES[template_name] then
		if action_input == "special_action" and FIRE_ACTION_INPUTS[original_action_input] then
			_armed_state_by_unit[unit] = {
				template_name = template_name,
				action_input = action_input,
			}

			if _mod and _mod:get("detailed_logging") then
				_mod:info(
					"Custom Character Bots: loaded special shell for %s before %s.",
					tostring(template_name),
					tostring(original_action_input)
				)
			end

			return
		end

		if active and FIRE_ACTION_INPUTS[action_input] then
			_armed_state_by_unit[unit] = nil
		end
	end

	if action_input ~= original_action_input and MELEE_ATTACK_INPUTS[original_action_input] then
		_armed_state_by_unit[unit] = {
			template_name = template_name,
			action_input = action_input,
		}

		if _mod and _mod:get("detailed_logging") then
			_mod:info(
				"Custom Character Bots: queued weapon special %s for %s before %s.",
				tostring(action_input),
				tostring(template_name),
				tostring(original_action_input)
			)
		end

		return
	end

	if action_input ~= original_action_input and FIRE_ACTION_INPUTS[original_action_input] then
		if _mod and _mod:get("detailed_logging") then
			_mod:info(
				"Custom Character Bots: queued weapon special %s for %s instead of %s.",
				tostring(action_input),
				tostring(template_name),
				tostring(original_action_input)
			)
		end
	end

	if CLEAR_ACTION_INPUTS[action_input] then
		_armed_state_by_unit[unit] = nil
	end
end

return M
