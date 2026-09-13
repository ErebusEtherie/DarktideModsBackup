-- Player-like behavior overhaul for substituted saved-character bots.
-- Uses vanilla movement/behavior components aggressively instead of waiting for
-- the default follower AI to decide when to engage, loot, and tag.

local M = {}

local _mod
local _is_enabled
local _fixed_time
local _Ammo
local _Health
local _VisualLoadout
local _Pickups
local _AbilityTemplates
local _FixedFrame
local _Blackboard
local _last_sprint_state_by_unit = setmetatable({}, { __mode = "k" })
local _last_item_tag_by_unit = setmetatable({}, { __mode = "k" })
local _last_enemy_tag_by_unit = setmetatable({}, { __mode = "k" })
local _last_dodge_by_unit = setmetatable({}, { __mode = "k" })
local _last_chest_scan_by_unit = setmetatable({}, { __mode = "k" })
local _last_chest_order_by_unit = setmetatable({}, { __mode = "k" })
local _last_pickup_scan_by_unit = setmetatable({}, { __mode = "k" })
local _last_target_seed_by_unit = setmetatable({}, { __mode = "k" })
local _last_weapon_special_by_unit = setmetatable({}, { __mode = "k" })
local _last_scout_refresh_by_unit = setmetatable({}, { __mode = "k" })
local _autonomy_state_by_unit = setmetatable({}, { __mode = "k" })
local _scout_state_by_unit = setmetatable({}, { __mode = "k" })
local _movement_flair_by_unit = setmetatable({}, { __mode = "k" })
local _stimm_state_by_unit = setmetatable({}, { __mode = "k" })
local _ability_state_by_unit = setmetatable({}, { __mode = "k" })
local _team_ability_use_t = {}
local _debug = {}
local _next_input_hook_retry_t = -math.huge
local _last_pickup_patch_t = -math.huge
local _warned = {}
local action_input_extension
local bot_input

M.INPUT_HOOK_VERSION = 4

SPRINT_FOLLOW_DISTANCE = 4
AMMO_SEARCH_THRESHOLD = 0.85
MEDICAE_HEALTH_THRESHOLD = 0.45
MEDICAE_WOUND_THRESHOLD = 0.2
DEPLOYABLE_HEALTH_THRESHOLD = 0.55
DEPLOYABLE_WOUND_THRESHOLD = 0.1
TAG_ITEM_COOLDOWN = 4
TAG_ENEMY_COOLDOWN = 3
DODGE_COOLDOWN = 1.2
CHEST_SCAN_COOLDOWN = 2
CHEST_ORDER_COOLDOWN = 8
PICKUP_SCAN_COOLDOWN = 1.5
PICKUP_SEARCH_RANGE = 55
PICKUP_OPEN_RANGE = 3.2
PICKUP_SKIP_IF_ENEMIES_WITHIN = 2
CHEST_SEARCH_RANGE = 45
CHEST_OPEN_RANGE = 3.2
CHEST_SKIP_IF_ENEMIES_WITHIN = 4
STIMM_PICKUP_PATCH_INTERVAL = 10
STIMM_USE_RETRY_DELAY = 6
STIMM_WIELD_TIMEOUT = 1.8
STIMM_AIM_ALLY_TIME = 0.45
STIMM_USE_TIMEOUT = 2.5
STIMM_ALLY_RANGE = 4
STIMM_COMBAT_ENEMY_COUNT = 4
STIMM_CORRUPTION_THRESHOLD = 0.15
STIMM_LOW_HEALTH_THRESHOLD = 0.45
GRENADE_USE_COOLDOWN = 3
UTILITY_USE_COOLDOWN = 6
ABILITY_WAIT_TIMEOUT = 2.5
GRENADE_HORDE_COUNT = 2
GRENADE_PRIORITY_MIN_DISTANCE = 2
UTILITY_HORDE_COUNT = 1
UTILITY_LOW_HEALTH_THRESHOLD = 0.65
TEAM_GRENADE_COOLDOWN = 2
TEAM_UTILITY_COOLDOWN = 4
TEAM_EMERGENCY_COOLDOWN = 1.2
GRENADE_ITEM_WIELD_TIMEOUT = 1.2
GRENADE_ITEM_STAGE_TIMEOUT = 2.5
TARGET_SEED_COOLDOWN = 0.35
TARGET_SEED_RANGE = 45
TARGET_SEED_PRIORITY_RANGE = 60
ENGAGE_LEASH_RANGE = 45
SCOUT_MIN_DISTANCE = 22
SCOUT_MAX_DISTANCE = 55
SCOUT_MAX_LEASH = 75
SCOUT_REACHED_DISTANCE = 3.5
SCOUT_REFRESH_MIN = 6
SCOUT_REFRESH_MAX = 12
SCOUT_DEST_REFRESH_COOLDOWN = 1
AUTONOMY_DIRECT_MOVE_COOLDOWN = 1.15
AUTONOMY_REACHED_DISTANCE = 3.2
AUTONOMY_ENEMY_MOVE_RANGE = 90
SLIDE_COOLDOWN_MIN = 4
SLIDE_COOLDOWN_MAX = 8
SLIDE_DURATION = 0.35
COMBAT_DODGE_COOLDOWN = 2.4
COMBAT_DODGE_RANGE = 7
WEAPON_SPECIAL_COOLDOWN = 2.5
WEAPON_SPECIAL_RANGE = 4
POXBURSTER_BREED_NAME = "chaos_poxwalker_bomber"

M.AUTONOMY_HOLD_DURATION = 5
M.AUTONOMY_REPATH_COOLDOWN = 0.35
M.AUTONOMY_LEASH_GRACE = 12
M.RESOURCE_SEARCH_RANGE = 95
M.PICKUP_CLAIM_DURATION = 8
M._pickup_claims = setmetatable({}, { __mode = "k" })
M.TARGET_CLAIM_DURATION = 3
M._target_claims = setmetatable({}, { __mode = "k" })

SUPPORTED_STIMMS = {
	syringe_ability_boost_pocketable = {
		kind = "combat",
	},
	syringe_power_boost_pocketable = {
		kind = "combat",
	},
	syringe_speed_boost_pocketable = {
		kind = "combat",
	},
	syringe_corruption_pocketable = {
		kind = "corruption",
	},
}

RESOURCE_PICKUPS = {
	small_metal = true,
	large_metal = true,
	small_platinum = true,
	large_platinum = true,
}

M._grenade_item_profiles = {
	psyker_chain_lightning = {
		start_input = "charge_heavy",
		followup_input = "shoot_heavy_hold",
		followup_delay = 0.8,
		release_input = "shoot_heavy_hold_release",
		release_delay = 0.9,
	},
	psyker_smite = {
		start_input = "charge_power_sticky",
		followup_input = "use_power",
		followup_delay = 1.2,
	},
	psyker_throwing_knives = {
		start_input = "shoot",
	},
	zealot_throwing_knives = {
		start_input = "shoot",
	},
	adamant_whistle = {
		start_input = "aim_pressed",
		release_input = "aim_released",
		release_delay = 0.2,
	},
	broker_missile_launcher = {
		start_input = "shoot_charge",
		release_input = "shoot_release",
		release_delay = 0.45,
	},
}

M._default_grenade_item_profile = {
	start_input = "aim_hold",
	release_input = "aim_released",
	release_delay = 0.45,
}

local function now()
	return _fixed_time and _fixed_time() or os.clock()
end

local function feature_enabled()
	return not _is_enabled or _is_enabled() ~= false
end

local function warn_once(key, message)
	if _warned[key] then
		return
	end

	_warned[key] = true

	if _mod and _mod.warning then
		_mod:warning(message)
	end
end

local function debug_count(key, amount)
	_debug[key] = (_debug[key] or 0) + (amount or 1)
end

local function player_by_unit(unit)
	local player_manager = Managers and Managers.player

	return player_manager and player_manager.player_by_unit and player_manager:player_by_unit(unit) or nil
end

local function is_custom_bot(unit)
	local player = unit and player_by_unit(unit)

	if not player or player:is_human_controlled() then
		return false
	end

	local profile = player.profile and player:profile()

	return profile and profile._ccb_resolved == true
end

function M.custom_bot_profile(unit)
	local player = unit and player_by_unit(unit)

	if not player or player:is_human_controlled() then
		return nil
	end

	local profile = player.profile and player:profile()

	if profile and profile._ccb_resolved == true then
		return profile
	end

	return nil
end

function M.learned_policy(unit)
	local behavior_learning = M._behavior_learning
	local profile = behavior_learning and M.custom_bot_profile(unit)

	return profile and behavior_learning.policy_for_profile and behavior_learning.policy_for_profile(profile) or nil
end

local function load_ammo()
	if _Ammo then
		return _Ammo
	end

	local ok, Ammo = pcall(require, "scripts/utilities/ammo")

	if ok then
		_Ammo = Ammo
	else
		warn_once("ammo", "Custom Character Bots: failed to load ammo utility for player-like bot behavior.")
	end

	return _Ammo
end

local function load_health()
	if _Health then
		return _Health
	end

	local ok, Health = pcall(require, "scripts/utilities/health")

	if ok then
		_Health = Health
	else
		warn_once("health", "Custom Character Bots: failed to load health utility for player-like bot behavior.")
	end

	return _Health
end

local function load_visual_loadout()
	if _VisualLoadout then
		return _VisualLoadout
	end

	local ok, VisualLoadout = pcall(require, "scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")

	if ok then
		_VisualLoadout = VisualLoadout
	else
		warn_once("visual_loadout", "Custom Character Bots: failed to load visual loadout utility for stimm support.")
	end

	return _VisualLoadout
end

local function load_pickups()
	if _Pickups then
		return _Pickups
	end

	local ok, Pickups = pcall(require, "scripts/settings/pickup/pickups")

	if ok then
		_Pickups = Pickups
	else
		warn_once("pickups", "Custom Character Bots: failed to load pickups table for stimm support.")
	end

	return _Pickups
end

local function load_ability_templates()
	if _AbilityTemplates then
		return _AbilityTemplates
	end

	local ok, AbilityTemplates = pcall(require, "scripts/settings/ability/ability_templates/ability_templates")

	if ok then
		_AbilityTemplates = AbilityTemplates
	else
		warn_once("ability_templates", "Custom Character Bots: failed to load ability templates for grenade/utility support.")
	end

	return _AbilityTemplates
end

local function load_fixed_frame()
	if _FixedFrame then
		return _FixedFrame
	end

	local ok, FixedFrame = pcall(require, "scripts/utilities/fixed_frame")

	if ok then
		_FixedFrame = FixedFrame
	else
		warn_once("fixed_frame", "Custom Character Bots: failed to load fixed frame utility for grenade/utility support.")
	end

	return _FixedFrame
end

local function load_blackboard()
	if _Blackboard then
		return _Blackboard
	end

	local ok, Blackboard = pcall(require, "scripts/extension_systems/blackboard/utilities/blackboard")

	if ok then
		_Blackboard = Blackboard
	else
		warn_once("blackboard", "Custom Character Bots: failed to load blackboard utility for player-like bot behavior.")
	end

	return _Blackboard
end

local function health_percent(unit)
	local Health = load_health()

	if Health and Health.current_health_percent then
		local ok, value = pcall(Health.current_health_percent, unit)

		if ok then
			return value
		end
	end

	return nil
end

local function permanent_damage_percent(unit)
	local Health = load_health()

	if Health and Health.permanent_damage_taken_percent then
		local ok, value = pcall(Health.permanent_damage_taken_percent, unit)

		if ok then
			return value
		end
	end

	return nil
end

local function ammo_percent(unit)
	local Ammo = load_ammo()

	if not (Ammo and Ammo.uses_ammo and Ammo.current_total_percentage) then
		return nil
	end

	local ok_uses, uses_ammo = pcall(Ammo.uses_ammo, unit)

	if not ok_uses or not uses_ammo then
		return nil
	end

	local ok_pct, value = pcall(Ammo.current_total_percentage, unit)

	return ok_pct and value or nil
end

local function inventory_component(unit)
	local unit_data_extension = unit and ScriptUnit.has_extension(unit, "unit_data_system")

	if not (unit_data_extension and unit_data_extension.read_component) then
		return nil
	end

	local ok, inventory = pcall(unit_data_extension.read_component, unit_data_extension, "inventory")

	return ok and inventory or nil
end

local function slot_is_empty(inventory, slot_name)
	return not inventory or inventory[slot_name] == nil or inventory[slot_name] == "not_equipped"
end

local function weapon_template_from_slot(unit, slot_name)
	local visual_loadout_extension = unit and ScriptUnit.has_extension(unit, "visual_loadout_system")

	if not visual_loadout_extension then
		return nil
	end

	if visual_loadout_extension.weapon_template_from_slot then
		local ok, template = pcall(visual_loadout_extension.weapon_template_from_slot, visual_loadout_extension, slot_name)

		if ok and template then
			return template
		end
	end

	local VisualLoadout = load_visual_loadout()

	if VisualLoadout and VisualLoadout.weapon_template_from_slot then
		local ok, template = pcall(VisualLoadout.weapon_template_from_slot, visual_loadout_extension, slot_name)

		if ok then
			return template
		end
	end

	return nil
end

local function pickup_name_from_template(template)
	return template and (template.swap_pickup_name or template.give_pickup_name or template.pickup_name or template.name) or nil
end

local function side_player_units(unit)
	local extension_manager = Managers and Managers.state and Managers.state.extension
	local ok, side_system = false, nil

	if extension_manager then
		ok, side_system = pcall(extension_manager.system, extension_manager, "side_system")
	end

	if not ok then
		return nil
	end

	local side = side_system and side_system.side_by_unit and side_system.side_by_unit[unit]

	return side and side.valid_player_units or nil
end

local function smart_tag_system()
	local extension_manager = Managers and Managers.state and Managers.state.extension

	if not extension_manager then
		return nil
	end

	local ok, system = pcall(extension_manager.system, extension_manager, "smart_tag_system")

	return ok and system or nil
end

local function extension_system(system_name)
	local extension_manager = Managers and Managers.state and Managers.state.extension

	if not extension_manager then
		return nil
	end

	local ok, system = pcall(extension_manager.system, extension_manager, system_name)

	return ok and system or nil
end

local function unit_data(unit, field_name)
	if not (unit and Unit and Unit.get_data) then
		return nil
	end

	local ok, value = pcall(Unit.get_data, unit, field_name)

	return ok and value or nil
end

local function target_already_tagged(target_unit)
	if not (target_unit and ScriptUnit and ScriptUnit.has_extension) then
		return false
	end

	local extension = ScriptUnit.has_extension(target_unit, "smart_tag_extension")
		or ScriptUnit.has_extension(target_unit, "smart_tag_system")

	if not (extension and extension.tag_id) then
		return false
	end

	local ok, tag_id = pcall(extension.tag_id, extension)

	return ok and tag_id ~= nil or false
end

local function tag_unit(unit, target_unit, reason, cooldown, state_by_unit)
	if not target_unit or target_already_tagged(target_unit) then
		return false
	end

	local t = now()
	local last = state_by_unit[unit]

	if last and last.unit == target_unit and t - last.t < cooldown then
		return false
	end

	local system = smart_tag_system()

	if not system then
		return false
	end

	local ok, err = pcall(system.set_contextual_unit_tag, system, unit, target_unit)

	if not ok then
		warn_once("item_tag", "Custom Character Bots: bot item tag failed: " .. tostring(err))

		return false
	end

	state_by_unit[unit] = {
		t = t,
		unit = target_unit,
	}

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: bot tagged %s.", tostring(reason or "target"))
	end

	return true
end

local function tag_item(unit, target_unit, reason)
	return tag_unit(unit, target_unit, reason, TAG_ITEM_COOLDOWN, _last_item_tag_by_unit)
end

local function tag_enemy(unit, target_unit, reason)
	return tag_unit(unit, target_unit, reason, TAG_ENEMY_COOLDOWN, _last_enemy_tag_by_unit)
end

local function any_teammate_needs_ammo(unit)
	local units = side_player_units(unit)

	if not units then
		return false
	end

	for i = 1, #units do
		local player_unit = units[i]

		if player_unit ~= unit and HEALTH_ALIVE[player_unit] then
			local pct = ammo_percent(player_unit)

			if pct and pct <= 0.5 then
				return true
			end
		end
	end

	return false
end

local function any_teammate_needs_health(unit)
	local units = side_player_units(unit)

	if not units then
		return false
	end

	for i = 1, #units do
		local player_unit = units[i]

		if player_unit ~= unit and HEALTH_ALIVE[player_unit] then
			local hp = health_percent(player_unit)
			local wound = permanent_damage_percent(player_unit)

			if hp and hp <= 0.55 or wound and wound >= 0.15 then
				return true
			end
		end
	end

	return false
end

local function count_nearby_enemies(unit)
	local perception_extension = unit and ScriptUnit.has_extension(unit, "perception_system")

	if not perception_extension then
		return 0
	end

	local ok, _units, num_enemies = pcall(perception_extension.enemies_in_proximity, perception_extension)

	return ok and num_enemies or 0
end

local function nearby_enemy_units(unit)
	local perception_extension = unit and ScriptUnit.has_extension(unit, "perception_system")

	if not perception_extension then
		return nil, 0
	end

	local ok, units, num_enemies = pcall(perception_extension.enemies_in_proximity, perception_extension)

	if not ok or not units or not num_enemies then
		return nil, 0
	end

	return units, num_enemies
end

local function target_breed(target_unit)
	local unit_data_extension = target_unit and ScriptUnit.has_extension(target_unit, "unit_data_system")

	if not (unit_data_extension and unit_data_extension.breed) then
		return nil
	end

	local ok, breed = pcall(unit_data_extension.breed, unit_data_extension)

	return ok and breed or nil
end

local function is_priority_enemy(target_unit)
	local breed = target_breed(target_unit)
	local tags = breed and breed.tags

	return breed and (breed.is_boss or tags and (tags.special or tags.elite or tags.monster or tags.captain)) or false
end

function M.target_claimed_by_other(target_unit, unit, t)
	local claim = target_unit and M._target_claims[target_unit]

	return claim and claim.unit ~= unit and t < (claim.until_t or -math.huge)
end

function M.claim_target(target_unit, unit, t)
	if target_unit then
		M._target_claims[target_unit] = {
			unit = unit,
			until_t = t + M.TARGET_CLAIM_DURATION,
		}
	end
end

local function current_target(unit, blackboard)
	local perception = blackboard and blackboard.perception

	if not perception then
		return nil
	end

	return perception.priority_target_enemy
		or perception.urgent_target_enemy
		or perception.opportunity_target_enemy
		or perception.target_enemy
end

local function target_distance(unit, target_unit)
	local unit_position = POSITION_LOOKUP[unit]
	local target_position = target_unit and POSITION_LOOKUP[target_unit]

	if not (unit_position and target_position) then
		return math.huge
	end

	return math.sqrt(Vector3.distance_squared(unit_position, target_position))
end

local function target_type_name(target_unit)
	local breed = target_breed(target_unit)
	local tags = breed and breed.tags

	if not breed then
		return "none"
	end

	if breed.is_boss or tags and tags.monster then
		return "monster"
	end

	if tags and tags.special then
		return "special"
	end

	if tags and tags.elite then
		return "elite"
	end

	return "normal"
end

local function enemy_is_targeting_unit(enemy_unit, unit)
	local enemy_blackboard = BLACKBOARDS and BLACKBOARDS[enemy_unit]
	local perception = enemy_blackboard and enemy_blackboard.perception

	return perception and perception.target_unit == unit or false
end

local function ability_extension(unit)
	return unit and ScriptUnit.has_extension(unit, "ability_system")
end

local function ability_component(unit, component_name)
	local unit_data_extension = unit and ScriptUnit.has_extension(unit, "unit_data_system")

	if not (unit_data_extension and unit_data_extension.read_component) then
		return nil
	end

	local ok, component = pcall(unit_data_extension.read_component, unit_data_extension, component_name)

	return ok and component or nil
end

local function ability_ready(unit, ability_type)
	local extension = ability_extension(unit)

	if not extension then
		return false
	end

	local ok_can, can_use = pcall(extension.can_use_ability, extension, ability_type)

	local ok_charges, charges = pcall(extension.remaining_ability_charges, extension, ability_type)

	if not ok_charges or charges == nil then
		return ok_can and can_use
	end

	return charges > 0
end

function M.ability_name_for_type(unit, ability_type)
	local extension = ability_extension(unit)

	if not extension then
		return nil
	end

	if ability_type == "grenade_ability" and extension.get_current_grenade_ability_name then
		local ok, name = pcall(extension.get_current_grenade_ability_name, extension)

		if ok and name then
			return name
		end
	end

	if ability_type == "combat_ability" and extension.get_current_ability_name then
		local ok, name = pcall(extension.get_current_ability_name, extension)

		if ok and name then
			return name
		end
	end

	if extension.ability_name then
		local ok, name = pcall(extension.ability_name, extension, ability_type)

		if ok then
			return name
		end
	end

	return nil
end

function M.add_unique_ability_input(inputs, input_name)
	if not input_name then
		return
	end

	for i = 1, #inputs do
		if inputs[i] == input_name then
			return
		end
	end

	inputs[#inputs + 1] = input_name
end

function M.ability_input_candidates(template, meta, component_name)
	local inputs = {}
	local activation = meta and meta.activation

	M.add_unique_ability_input(inputs, activation and activation.action_input)

	local hierarchy = template and template.action_input_hierarchy
	local first = hierarchy and hierarchy[1]

	M.add_unique_ability_input(inputs, first and first.input)

	local actions = template and template.actions

	if actions then
		for _, action in pairs(actions) do
			M.add_unique_ability_input(inputs, action.start_input)
		end
	end

	if component_name == "combat_ability_action" then
		M.add_unique_ability_input(inputs, "combat_ability_pressed")
		M.add_unique_ability_input(inputs, "ability_pressed")
		M.add_unique_ability_input(inputs, "stance_pressed")
		M.add_unique_ability_input(inputs, "aim_pressed")
	elseif component_name == "grenade_ability_action" then
		M.add_unique_ability_input(inputs, "aim_pressed")
		M.add_unique_ability_input(inputs, "ability_pressed")
		M.add_unique_ability_input(inputs, "grenade_ability")
	end

	return inputs
end

local function ability_activation(unit, component_name)
	local component = ability_component(unit, component_name)
	local template_name = component and component.template_name

	if not template_name or template_name == "none" then
		return nil, nil, nil
	end

	local AbilityTemplates = load_ability_templates()
	local template = AbilityTemplates and AbilityTemplates[template_name]
	local meta = template and template.ability_meta_data
	local activation = meta and meta.activation
	local inputs = M.ability_input_candidates(template, meta, component_name)

	if #inputs == 0 then
		return nil, nil, nil
	end

	activation = activation or {}
	activation.action_input = inputs[1]
	activation.candidate_inputs = inputs

	return template_name, activation, meta and meta.wait_action or nil
end

local function latest_fixed_time(t)
	local FixedFrame = load_fixed_frame()

	if FixedFrame and FixedFrame.get_latest_fixed_time then
		local ok, fixed_t = pcall(FixedFrame.get_latest_fixed_time)

		if ok and fixed_t then
			return fixed_t
		end
	end

	return t
end

local queue_ability_input

local function ability_input_valid(unit, component_name, action_input, used_input, t)
	local extension = ability_extension(unit)

	if not (extension and extension.action_input_is_currently_valid) then
		return true
	end

	local ok, is_valid = pcall(
		extension.action_input_is_currently_valid,
		extension,
		component_name,
		action_input,
		used_input,
		latest_fixed_time(t)
	)

	return ok and is_valid
end

function M.queue_first_valid_ability_input(unit, component_name, activation, t)
	local inputs = activation and activation.candidate_inputs or nil

	if not inputs then
		return queue_ability_input(unit, component_name, activation and activation.action_input, nil)
	end

	local preferred = activation and activation.action_input

	if preferred and queue_ability_input(unit, component_name, preferred, activation.used_input) then
		return true
	end

	for i = 1, #inputs do
		local action_input = inputs[i]

		if action_input ~= preferred and ability_input_valid(unit, component_name, action_input, activation.used_input, t) and queue_ability_input(unit, component_name, action_input, activation.used_input) then
			activation.action_input = action_input

			return true
		end
	end

	return false
end

queue_ability_input = function(unit, component_name, action_input, raw_input)
	local extension = action_input_extension(unit)

	if not (extension and extension.bot_queue_action_input and action_input) then
		debug_count("ability_queue_missing")

		return false
	end

	local parsers = extension._action_input_parsers

	if parsers and not parsers[component_name] then
		debug_count("ability_queue_missing_parser")

		return false
	end

	local ok, request_id = pcall(extension.bot_queue_action_input, extension, component_name, action_input, raw_input)

	debug_count(ok and request_id ~= nil and "ability_queue_ok" or "ability_queue_fail")

	return ok and request_id ~= nil
end

local function aim_at_target(unit, target_unit)
	local target_position = target_unit and POSITION_LOOKUP[target_unit]
	local input = target_position and bot_input(unit)

	if input and input.set_aim_position then
		pcall(input.set_aim_position, input, target_position)
	end
end

local function refresh_follow(blackboard)
	if not blackboard then
		return
	end

	local Blackboard = load_blackboard()
	local follow

	if Blackboard and Blackboard.write_component then
		local ok, component = pcall(Blackboard.write_component, blackboard, "follow")

		if ok then
			follow = component
		end
	end

	follow = follow or blackboard.follow

	if follow then
		follow.needs_destination_refresh = true
	end
end

local function unit_alive(unit)
	if not unit then
		return false
	end

	if ALIVE and ALIVE[unit] then
		return true
	end

	if Unit and Unit.alive then
		local ok, alive = pcall(Unit.alive, unit)

		return ok and alive or false
	end

	return false
end

local function enemies_nearby(unit, max_distance)
	local perception_extension = unit and ScriptUnit.has_extension(unit, "perception_system")

	if not perception_extension then
		return false
	end

	local ok, units, num_enemies = pcall(perception_extension.enemies_in_proximity, perception_extension)

	if not ok or not units or not num_enemies or num_enemies <= 0 then
		return false
	end

	local unit_position = POSITION_LOOKUP[unit]

	if not unit_position then
		return true
	end

	local max_distance_sq = max_distance * max_distance

	for i = 1, num_enemies do
		local enemy_unit = units[i]
		local enemy_position = enemy_unit and POSITION_LOOKUP[enemy_unit]

		if enemy_position and Vector3.distance_squared(unit_position, enemy_position) <= max_distance_sq then
			return true
		end
	end

	return false
end

local function unbox_vector(value)
	if not value then
		return nil
	end

	local ok, unboxed = pcall(function()
		return value:unbox()
	end)

	if ok and unboxed then
		return unboxed
	end

	if Vector3Box and Vector3Box.unbox then
		ok, unboxed = pcall(Vector3Box.unbox, value)

		if ok and unboxed then
			return unboxed
		end
	end

	return value
end

local function plain_vector(value)
	value = unbox_vector(value)

	if not value then
		return nil
	end

	if not (Vector3 and Vector3.to_elements) then
		return nil
	end

	local ok, x, y, z = pcall(Vector3.to_elements, value)

	if ok and x and y and z then
		return Vector3(x, y, z)
	end

	return nil
end

local function distance_between_units(a, b)
	local a_position = plain_vector(a and POSITION_LOOKUP[a])
	local b_position = plain_vector(b and POSITION_LOOKUP[b])

	if not (a_position and b_position) then
		return math.huge
	end

	local ok, distance_sq = pcall(Vector3.distance_squared, a_position, b_position)

	return ok and math.sqrt(distance_sq) or math.huge
end

local function vector_distance(a, b)
	if not (a and b) then
		return math.huge
	end

	a = plain_vector(a)
	b = plain_vector(b)

	if not (a and b) then
		return math.huge
	end

	local ok, distance_sq = pcall(Vector3.distance_squared, a, b)

	return ok and math.sqrt(distance_sq) or math.huge
end

local function patch_supported_pickups(t, force)
	if not force and t - _last_pickup_patch_t < STIMM_PICKUP_PATCH_INTERVAL then
		return
	end

	_last_pickup_patch_t = t

	local Pickups = load_pickups()
	local pickups_by_name = Pickups and Pickups.by_name

	if not pickups_by_name then
		return
	end

	local enabled = feature_enabled()

	for pickup_name in pairs(SUPPORTED_STIMMS) do
		local pickup_data = pickups_by_name[pickup_name]

		if pickup_data then
			pickup_data.slot_name = pickup_data.slot_name or pickup_data.inventory_slot_name or "slot_pocketable_small"
			pickup_data.bots_mule_pickup = enabled
		end
	end

	for pickup_name in pairs(RESOURCE_PICKUPS) do
		local pickup_data = pickups_by_name[pickup_name]

		if pickup_data then
			pickup_data.bots_mule_pickup = false
		end
	end
end

local function ensure_mule_pickup_slots(bot_group)
	local available_mule_pickups = bot_group and bot_group._available_mule_pickups
	local Pickups = load_pickups()
	local pickups_by_name = Pickups and Pickups.by_name

	if not (available_mule_pickups and pickups_by_name) then
		return
	end

	for _, pickup_data in pairs(pickups_by_name) do
		local slot_name = pickup_data and pickup_data.bots_mule_pickup and pickup_data.slot_name

		if slot_name and not available_mule_pickups[slot_name] then
			available_mule_pickups[slot_name] = {}
		end
	end
end

local function pickup_name_from_unit(pickup_unit)
	if not (pickup_unit and Unit and Unit.get_data) then
		return nil
	end

	local ok, pickup_name = pcall(Unit.get_data, pickup_unit, "pickup_type")

	return ok and pickup_name or nil
end

local function stimm_pickup_entry(pickup_unit)
	local pickup_name = pickup_name_from_unit(pickup_unit)

	return pickup_name and SUPPORTED_STIMMS[pickup_name] or nil, pickup_name
end

local function carried_stimm(unit)
	local inventory = inventory_component(unit)

	if slot_is_empty(inventory, "slot_pocketable_small") then
		return nil, nil, inventory
	end

	local template = weapon_template_from_slot(unit, "slot_pocketable_small")
	local pickup_name = pickup_name_from_template(template)
	local entry = pickup_name and SUPPORTED_STIMMS[pickup_name]

	return entry, pickup_name, inventory
end

function action_input_extension(unit)
	return unit and ScriptUnit.has_extension(unit, "action_input_system")
end

function bot_input(unit)
	local input_extension = unit and ScriptUnit.has_extension(unit, "input_system")

	if input_extension and input_extension.bot_unit_input then
		local ok, input = pcall(input_extension.bot_unit_input, input_extension)

		return ok and input or nil
	end

	return nil
end

local function queue_weapon_input(unit, action_input, raw_input)
	local extension = action_input_extension(unit)

	if not (extension and extension.bot_queue_action_input) then
		debug_count("weapon_queue_missing")

		return false
	end

	local ok, request_id = pcall(extension.bot_queue_action_input, extension, "weapon_action", action_input, raw_input)

	debug_count(ok and request_id ~= nil and "weapon_queue_ok" or "weapon_queue_fail")

	return ok and request_id ~= nil
end

local function queue_wield_stimm(unit)
	return queue_weapon_input(unit, "wield", "wield_4")
end

local function queue_use_stimm_self(unit)
	return queue_weapon_input(unit, "use_self", nil)
end

local function queue_use_stimm_ally(unit, ally_unit)
	local ally_position = ally_unit and POSITION_LOOKUP[ally_unit]

	if not ally_position then
		return false
	end

	local input = bot_input(unit)

	if input and input.set_aim_position then
		pcall(input.set_aim_position, input, ally_position)
	end

	queue_weapon_input(unit, "aim", nil)

	return queue_weapon_input(unit, "use_ally", nil)
end

local function stimm_target_score(stimm_kind, source_unit, target_unit)
	if not (target_unit and HEALTH_ALIVE[target_unit]) then
		return nil
	end

	local hp = health_percent(target_unit) or 1
	local corruption = permanent_damage_percent(target_unit) or 0

	if stimm_kind == "corruption" then
		if corruption < STIMM_CORRUPTION_THRESHOLD and hp > STIMM_LOW_HEALTH_THRESHOLD then
			return nil
		end

		return corruption * 10 + (1 - hp)
	end

	if count_nearby_enemies(source_unit) < STIMM_COMBAT_ENEMY_COUNT then
		return nil
	end

	local source_position = POSITION_LOOKUP[source_unit]
	local target_position = POSITION_LOOKUP[target_unit]

	if source_unit ~= target_unit and source_position and target_position then
		local range_sq = STIMM_ALLY_RANGE * STIMM_ALLY_RANGE

		if Vector3.distance_squared(source_position, target_position) > range_sq then
			return nil
		end
	end

	return 1 - hp
end

local function best_stimm_target(unit, stimm_kind)
	local units = side_player_units(unit)
	local best_unit = unit
	local best_score = stimm_target_score(stimm_kind, unit, unit)

	if units then
		for i = 1, #units do
			local ally_unit = units[i]

			if ally_unit ~= unit then
				local score = stimm_target_score(stimm_kind, unit, ally_unit)

				if score and (not best_score or score > best_score) then
					best_unit = ally_unit
					best_score = score
				end
			end
		end
	end

	return best_score and best_unit or nil
end

local function clear_stimm_state(unit, next_try_t)
	_stimm_state_by_unit[unit] = next_try_t and {
		stage = "cooldown",
		next_try_t = next_try_t,
	} or nil
end

local function nudge_stimm_pickups(unit, blackboard)
	local pickup = blackboard and blackboard.pickup

	if not pickup or not slot_is_empty(inventory_component(unit), "slot_pocketable_small") then
		return
	end

	local entry, pickup_name = stimm_pickup_entry(pickup.mule_pickup)

	if entry then
		tag_item(unit, pickup.mule_pickup, pickup_name)
	end
end

local function update_stimm_use(unit, blackboard, t)
	local state = _stimm_state_by_unit[unit]

	if state and state.stage == "cooldown" then
		if t < (state.next_try_t or -math.huge) then
			return
		end

		_stimm_state_by_unit[unit] = nil
		state = nil
	end

	local entry, pickup_name, inventory = carried_stimm(unit)

	if not entry then
		_stimm_state_by_unit[unit] = nil

		return
	end

	local target_unit = state and state.target_unit or best_stimm_target(unit, entry.kind)

	if not target_unit then
		clear_stimm_state(unit, t + STIMM_USE_RETRY_DELAY)

		return
	end

	if not state then
		state = {
			stage = "wield",
			pickup_name = pickup_name,
			target_unit = target_unit,
			deadline_t = t + STIMM_WIELD_TIMEOUT,
		}
		_stimm_state_by_unit[unit] = state

		if _mod and _mod:get("detailed_logging") then
			_mod:info("Custom Character Bots: preparing stimm %s.", tostring(pickup_name))
		end
	end

	if state.stage == "wield" then
		if inventory and inventory.wielded_slot == "slot_pocketable_small" then
			if state.target_unit ~= unit and HEALTH_ALIVE[state.target_unit] then
				state.stage = "aim_ally"
				state.deadline_t = t + STIMM_AIM_ALLY_TIME
			else
				state.stage = "use"
				state.deadline_t = t + STIMM_USE_TIMEOUT
			end
		else
			queue_wield_stimm(unit)

			if t > (state.deadline_t or -math.huge) then
				clear_stimm_state(unit, t + STIMM_USE_RETRY_DELAY)
			end

			return
		end
	end

	if state.stage == "aim_ally" then
		if not HEALTH_ALIVE[state.target_unit] then
			state.target_unit = unit
			state.stage = "use"
			state.deadline_t = t + STIMM_USE_TIMEOUT
		else
			local input = bot_input(unit)
			local ally_position = POSITION_LOOKUP[state.target_unit]

			if input and input.set_aim_position and ally_position then
				pcall(input.set_aim_position, input, ally_position)
			end

			queue_weapon_input(unit, "aim", nil)

			if t < (state.deadline_t or -math.huge) then
				return
			end

			state.stage = "use"
			state.deadline_t = t + STIMM_USE_TIMEOUT
		end
	end

	if state.stage == "use" then
		if state.target_unit ~= unit and HEALTH_ALIVE[state.target_unit] then
			queue_use_stimm_ally(unit, state.target_unit)
		else
			queue_use_stimm_self(unit)
		end

		if slot_is_empty(inventory_component(unit), "slot_pocketable_small") or t > (state.deadline_t or -math.huge) then
			clear_stimm_state(unit, t + STIMM_USE_RETRY_DELAY)
		end
	end
end

local function ally_needs_hard_aid(blackboard)
	local perception = blackboard and blackboard.perception
	local need_type = perception and perception.target_ally_need_type

	return perception
		and perception.target_ally_needs_aid
		and need_type ~= "in_need_of_attention_look"
		and need_type ~= "in_need_of_attention_stop"
end

local function name_has(name, pattern)
	return name and string.find(name, pattern, 1, true) ~= nil
end

local function name_has_any(name, patterns)
	if not name then
		return false
	end

	for i = 1, #patterns do
		if name_has(name, patterns[i]) then
			return true
		end
	end

	return false
end

local function ability_family(template_name, fallback)
	if name_has_any(template_name, { "krak", "rock", "knife", "assail" }) then
		return "single_target"
	end

	if name_has_any(template_name, { "frag", "fire", "flame", "shock", "cluster", "box", "mine" }) then
		return "area_control"
	end

	if name_has_any(template_name, { "smoke", "shield", "relic", "dome", "field" }) then
		return "defensive"
	end

	if name_has_any(template_name, { "smite", "chain_lightning", "chain", "lightning" }) then
		return "crowd_control"
	end

	if name_has_any(template_name, { "charge", "dash", "lunge" }) then
		return "charge"
	end

	if name_has_any(template_name, { "shout", "command", "taunt" }) then
		return "shout"
	end

	if name_has_any(template_name, { "stance", "mark", "focus", "ranged" }) then
		return "offense"
	end

	if name_has_any(template_name, { "stealth", "invisible" }) then
		return "stealth"
	end

	if name_has_any(template_name, { "whistle", "cyber", "mastiff", "dog" }) then
		return "companion"
	end

	return fallback or "generic"
end

local function ability_context(unit, blackboard)
	local target_unit = current_target(unit, blackboard)
	local nearby = count_nearby_enemies(unit)
	local hp = health_percent(unit) or 1
	local perception = blackboard and blackboard.perception
	local ally_aid = ally_needs_hard_aid(blackboard)
	local target_is_priority = target_unit and is_priority_enemy(target_unit)
	local distance = target_unit and target_distance(unit, target_unit) or math.huge
	local target_type = target_unit and target_type_name(target_unit) or nil

	return {
		target_unit = target_unit,
		target_distance = distance,
		target_type = target_type,
		target_is_priority = target_is_priority,
		nearby = nearby,
		hp = hp,
		ally_aid = ally_aid,
		ally_unit = perception and perception.target_ally or nil,
	}
end

local function team_ability_ready(team_key, t, cooldown, emergency)
	if emergency then
		cooldown = math.min(cooldown, TEAM_EMERGENCY_COOLDOWN)
	end

	return t - (_team_ability_use_t[team_key] or -math.huge) >= cooldown
end

local function record_team_ability(team_key, t)
	if team_key then
		_team_ability_use_t[team_key] = t
	end
end

local function should_use_grenade(unit, blackboard, template_name, t)
	local context = ability_context(unit, blackboard)
	local family = ability_family(template_name, "grenade")
	local team_key = "grenade:" .. family
	local emergency = context.ally_aid or context.hp <= 0.3
	local policy = M.learned_policy(unit) or {}
	local grenade_horde_count = policy.grenade_horde_count or GRENADE_HORDE_COUNT
	local utility_horde_count = policy.utility_horde_count or UTILITY_HORDE_COUNT
	local in_combat = context.target_unit ~= nil or context.nearby > 0

	if not team_ability_ready(team_key, t, TEAM_GRENADE_COOLDOWN, emergency) then
		return false, nil, nil
	end

	if family == "defensive" then
		if context.ally_aid then
			return true, context.ally_unit or context.target_unit, "defensive_rescue", team_key
		end

		if context.hp <= 0.55 and context.nearby > 0 then
			return true, context.target_unit, "defensive_low_health", team_key
		end

		if context.nearby >= utility_horde_count then
			return true, context.target_unit, "defensive_pressure", team_key
		end

		return false, nil, nil
	end

	if family == "crowd_control" then
		if context.target_is_priority and context.target_distance <= TARGET_SEED_PRIORITY_RANGE then
			return true, context.target_unit, "control_priority", team_key
		end

		if context.nearby >= 2 then
			return true, context.target_unit, "control_horde", team_key
		end

		if in_combat then
			return true, context.target_unit, "control_combat", team_key
		end

		return false, nil, nil
	end

	if family == "single_target" then
		if context.target_is_priority and context.target_distance >= GRENADE_PRIORITY_MIN_DISTANCE then
			return true, context.target_unit, "single_priority", team_key
		end

		if context.target_type and name_has_any(context.target_type, { "monster", "boss", "elite", "special" }) then
			return true, context.target_unit, "single_elite", team_key
		end

		if name_has(template_name, "assail") and context.nearby >= 2 then
			return true, context.target_unit, "assail_pressure", team_key
		end

		if in_combat and context.target_unit then
			return true, context.target_unit, "single_combat", team_key
		end

		return false, nil, nil
	end

	if context.target_is_priority and context.target_distance >= GRENADE_PRIORITY_MIN_DISTANCE then
		return true, context.target_unit, "priority", team_key
	end

	if context.nearby >= grenade_horde_count then
		return true, context.target_unit, "horde", team_key
	end

	if in_combat then
		return true, context.target_unit, "combat_opportunity", team_key
	end

	return false, nil, nil
end

local function should_use_utility(unit, blackboard, template_name, t)
	local context = ability_context(unit, blackboard)
	local family = ability_family(template_name, "utility")
	local team_key = "utility:" .. family
	local emergency = context.ally_aid or context.hp <= 0.3
	local policy = M.learned_policy(unit) or {}
	local grenade_horde_count = policy.grenade_horde_count or GRENADE_HORDE_COUNT
	local utility_horde_count = policy.utility_horde_count or UTILITY_HORDE_COUNT
	local in_combat = context.target_unit ~= nil or context.nearby > 0

	if not team_ability_ready(team_key, t, TEAM_UTILITY_COOLDOWN, emergency) then
		return false, nil, nil
	end

	if family == "charge" then
		if context.ally_aid then
			return true, context.ally_unit or context.target_unit, "charge_rescue", team_key
		end

		if context.target_is_priority and context.target_distance >= 5 and context.target_distance <= 25 then
			return true, context.target_unit, "charge_priority", team_key
		end

		if context.nearby >= grenade_horde_count or in_combat and context.target_distance >= 5 and context.target_distance <= 25 then
			return true, context.target_unit, "charge_pressure", team_key
		end

		return false, nil, nil
	end

	if family == "shout" or family == "defensive" then
		if context.ally_aid then
			return true, context.ally_unit or context.target_unit, family .. "_rescue", team_key
		end

		if context.hp <= UTILITY_LOW_HEALTH_THRESHOLD and context.nearby > 0 then
			return true, context.target_unit, family .. "_low_health", team_key
		end

		if context.nearby >= utility_horde_count then
			return true, context.target_unit, family .. "_pressure", team_key
		end

		if in_combat then
			return true, context.target_unit, family .. "_combat", team_key
		end

		return false, nil, nil
	end

	if family == "stealth" then
		if context.ally_aid then
			return true, context.ally_unit or context.target_unit, "stealth_rescue", team_key
		end

		if context.hp <= 0.4 and context.nearby > 0 then
			return true, context.target_unit, "stealth_low_health", team_key
		end

		if context.target_is_priority then
			return true, context.target_unit, "stealth_priority", team_key
		end

		return false, nil, nil
	end

	if family == "companion" then
		if context.target_is_priority then
			return true, context.target_unit, "companion_priority", team_key
		end

		if context.nearby >= 2 or in_combat then
			return true, context.target_unit, "companion_pressure", team_key
		end

		return false, nil, nil
	end

	if family == "offense" then
		if context.target_is_priority then
			return true, context.target_unit, "offense_priority", team_key
		end

		if context.nearby >= utility_horde_count then
			return true, context.target_unit, "offense_pressure", team_key
		end

		return false, nil, nil
	end

	if context.ally_aid then
		return true, context.ally_unit or context.target_unit, "ally_aid", team_key
	end

	if context.hp <= UTILITY_LOW_HEALTH_THRESHOLD and context.nearby > 0 then
		return true, context.target_unit, "low_health", team_key
	end

	if context.target_is_priority then
		return true, context.target_unit, "priority", team_key
	end

	if context.nearby >= utility_horde_count then
		return true, context.target_unit, "pressure", team_key
	end

	if in_combat then
		return true, context.target_unit, "combat_opportunity", team_key
	end

	return false, nil, nil
end

local ABILITY_FALLBACKS = {
	{
		key = "grenade",
		ability_type = "grenade_ability",
		component_name = "grenade_ability_action",
		cooldown = GRENADE_USE_COOLDOWN,
		should_use = should_use_grenade,
	},
	{
		key = "utility",
		ability_type = "combat_ability",
		component_name = "combat_ability_action",
		cooldown = UTILITY_USE_COOLDOWN,
		should_use = should_use_utility,
	},
}

local function ability_state(unit, key)
	local state = _ability_state_by_unit[unit]

	if not state then
		state = {}
		_ability_state_by_unit[unit] = state
	end

	local key_state = state[key]

	if not key_state then
		key_state = {
			next_try_t = -math.huge,
		}
		state[key] = key_state
	end

	return key_state
end

local function continue_ability_wait(unit, config, state, t)
	if not state.wait_action_input then
		return false
	end

	if t > (state.wait_deadline_t or -math.huge) then
		state.wait_action_input = nil
		state.next_try_t = t + config.cooldown

		return true
	end

	if t >= (state.wait_ready_t or -math.huge) then
		queue_ability_input(unit, config.component_name, state.wait_action_input, nil)
		state.wait_action_input = nil
		state.next_try_t = t + config.cooldown

		if _mod and _mod:get("detailed_logging") then
			_mod:info("Custom Character Bots: queued %s wait/release input.", config.key)
		end
	end

	return true
end

local function inventory_wielded_slot(unit)
	local inventory = inventory_component(unit)

	return inventory and inventory.wielded_slot or nil
end

local function queue_grenade_activation(unit, t)
	local _template_name, activation = ability_activation(unit, "grenade_ability_action")

	if activation and M.queue_first_valid_ability_input(unit, "grenade_ability_action", activation, t) then
		return true
	end

	return queue_ability_input(unit, "grenade_ability_action", "grenade_ability", nil)
		or queue_ability_input(unit, "grenade_ability_action", "ability_pressed", nil)
		or queue_weapon_input(unit, "grenade_ability", nil)
end

function M.grenade_item_profile(grenade_name)
	return M._grenade_item_profiles[grenade_name] or M._default_grenade_item_profile
end

function M.clear_grenade_item_state(state, next_try_t)
	state.grenade_item_stage = nil
	state.grenade_item_name = nil
	state.grenade_item_target = nil
	state.grenade_item_deadline_t = nil
	state.grenade_item_next_t = nil
	state.grenade_item_profile = nil
	state.grenade_item_team_key = nil

	if next_try_t then
		state.next_try_t = next_try_t
	end
end

function M.update_grenade_item_sequence(unit, blackboard, state, t)
	if state.grenade_item_stage then
		debug_count("grenade_sequence")
		local profile = state.grenade_item_profile or M._default_grenade_item_profile

		if t > (state.grenade_item_deadline_t or -math.huge) then
			M.clear_grenade_item_state(state, t + 1)

			return true
		end

		aim_at_target(unit, state.grenade_item_target)

		if state.grenade_item_stage == "wield" then
			if inventory_wielded_slot(unit) ~= "slot_grenade_ability" then
				queue_grenade_activation(unit, t)

				return true
			end

			state.grenade_item_stage = "start"
			state.grenade_item_next_t = t
			state.grenade_item_deadline_t = t + GRENADE_ITEM_STAGE_TIMEOUT
		end

		if state.grenade_item_stage == "start" and t >= (state.grenade_item_next_t or -math.huge) then
			if profile.start_input then
				queue_weapon_input(unit, profile.start_input, nil)
			end

			if profile.followup_input then
				state.grenade_item_stage = "followup"
				state.grenade_item_next_t = t + (profile.followup_delay or 0.4)
			elseif profile.release_input then
				state.grenade_item_stage = "release"
				state.grenade_item_next_t = t + (profile.release_delay or 0.4)
			else
				M.clear_grenade_item_state(state, t + GRENADE_USE_COOLDOWN)
			end

			return true
		end

		if state.grenade_item_stage == "followup" and t >= (state.grenade_item_next_t or -math.huge) then
			queue_weapon_input(unit, profile.followup_input, nil)

			if profile.release_input then
				state.grenade_item_stage = "release"
				state.grenade_item_next_t = t + (profile.release_delay or 0.4)
			else
				M.clear_grenade_item_state(state, t + GRENADE_USE_COOLDOWN)
			end

			return true
		end

		if state.grenade_item_stage == "release" and t >= (state.grenade_item_next_t or -math.huge) then
			queue_weapon_input(unit, profile.release_input, nil)
			M.clear_grenade_item_state(state, t + GRENADE_USE_COOLDOWN)

			return true
		end

		return true
	end

	if t < (state.next_try_t or -math.huge) or not ability_ready(unit, "grenade_ability") then
		return false
	end

	local grenade_name = M.ability_name_for_type(unit, "grenade_ability")
	local should_use, target_unit, reason, team_key = should_use_grenade(unit, blackboard, grenade_name or "grenade", t)

	if not should_use then
		debug_count("grenade_no_decision")

		return false
	end

	debug_count("grenade_decision")
	state.grenade_item_stage = "wield"
	state.grenade_item_name = grenade_name
	state.grenade_item_target = target_unit
	state.grenade_item_deadline_t = t + GRENADE_ITEM_WIELD_TIMEOUT
	state.grenade_item_profile = M.grenade_item_profile(grenade_name)
	state.grenade_item_team_key = team_key
	record_team_ability(team_key or "grenade:item", t)
	queue_grenade_activation(unit, t)

	if _mod and _mod:get("detailed_logging") then
		_mod:info(
			"Custom Character Bots: queued grenade/blitz item %s via %s.",
			tostring(grenade_name),
			tostring(reason)
		)
	end

	return true
end

local function update_ability_fallback(unit, blackboard, t)
	local behavior = blackboard and blackboard.behavior

	if behavior and (behavior.current_interaction_unit or behavior.interaction_unit or behavior.forced_pickup_unit) then
		return
	end

	for i = 1, #ABILITY_FALLBACKS do
		local config = ABILITY_FALLBACKS[i]
		local state = ability_state(unit, config.key)

		if continue_ability_wait(unit, config, state, t) then
			return
		end

		if config.key == "grenade" and M.update_grenade_item_sequence(unit, blackboard, state, t) then
			return
		end

		repeat
			if t < (state.next_try_t or -math.huge) then
				break
			end

			if not ability_ready(unit, config.ability_type) then
				state.next_try_t = t + 1.5

				break
			end

			local template_name, activation, wait_action = ability_activation(unit, config.component_name)

			if not template_name then
				state.next_try_t = t + 3

				break
			end

			local should_use, target_unit, reason, team_key = config.should_use(unit, blackboard, template_name, t)

			if not should_use then
				debug_count(config.key .. "_no_decision")
				state.next_try_t = t + 0.75

				break
			end

			debug_count(config.key .. "_decision")
			aim_at_target(unit, target_unit)

			if M.queue_first_valid_ability_input(unit, config.component_name, activation, t) then
				debug_count(config.key .. "_queued")
				state.next_try_t = t + config.cooldown
				record_team_ability(team_key or config.key, t)

				if wait_action and wait_action.action_input then
					state.wait_action_input = wait_action.action_input
					state.wait_ready_t = t + (activation.min_hold_time or 0)
					state.wait_deadline_t = t + ABILITY_WAIT_TIMEOUT
				end

				if _mod and _mod:get("detailed_logging") then
					_mod:info(
						"Custom Character Bots: queued %s %s via %s.",
						config.key,
						tostring(template_name),
						tostring(reason)
					)
				end

				return
			end

			state.next_try_t = t + 1.5

			break
		until true
	end
end

local function best_nearby_enemy(unit, t)
	local units, num_enemies = nearby_enemy_units(unit)

	if not units or num_enemies <= 0 then
		return nil, nil
	end

	local best_unit, best_score, best_distance

	for i = 1, num_enemies do
		local enemy_unit = units[i]

		if enemy_unit and unit_alive(enemy_unit) then
			local distance = target_distance(unit, enemy_unit)
			local max_range = is_priority_enemy(enemy_unit) and TARGET_SEED_PRIORITY_RANGE or TARGET_SEED_RANGE

			if distance <= max_range then
				local score = -distance

				local priority = is_priority_enemy(enemy_unit)

				if priority then
					score = score + 100
				end

				if enemy_is_targeting_unit(enemy_unit, unit) then
					score = score + 50
				end

				if not priority and M.target_claimed_by_other(enemy_unit, unit, t or now()) then
					score = score - 35
				end

				if not best_score or score > best_score then
					best_unit = enemy_unit
					best_score = score
					best_distance = distance
				end
			end
		end
	end

	return best_unit, best_distance
end

local function nudge_targeting(unit, blackboard, t)
	local perception = blackboard and blackboard.perception

	if not perception then
		return
	end

	local existing = current_target(unit, blackboard)
	local last_seed = _last_target_seed_by_unit[unit] or -math.huge

	if existing and unit_alive(existing) and target_distance(unit, existing) <= TARGET_SEED_PRIORITY_RANGE then
		if is_priority_enemy(existing) then
			return
		end

		if not M.target_claimed_by_other(existing, unit, t) then
			M.claim_target(existing, unit, t)

			if t - last_seed < 2 then
				return
			end
		end
	end

	if t - last_seed < TARGET_SEED_COOLDOWN then
		return
	end

	local target_unit, distance = best_nearby_enemy(unit, t)

	if not target_unit then
		return
	end

	debug_count("target_seed")
	_last_target_seed_by_unit[unit] = t
	M.claim_target(target_unit, unit, t)

	perception.target_enemy = target_unit
	perception.target_enemy_distance = distance or math.huge
	perception.target_enemy_type = target_type_name(target_unit)
	perception.target_enemy_reevaluation_t = math.min(perception.target_enemy_reevaluation_t or math.huge, t + 0.25)

	if is_priority_enemy(target_unit) then
		perception.priority_target_enemy = target_unit
	else
		perception.urgent_target_enemy = target_unit
		perception.opportunity_target_enemy = target_unit
	end

	refresh_follow(blackboard)
	tag_enemy(unit, target_unit, "enemy")

	if _mod and _mod:get("detailed_logging") then
		_mod:info(
			"Custom Character Bots: seeded bot target %s at %.1fm.",
			tostring(perception.target_enemy_type),
			distance or -1
		)
	end
end

local function pickup_settings_for_unit(pickup_unit)
	local pickup_name = unit_data(pickup_unit, "pickup_type")
	local Pickups = load_pickups()
	local settings = pickup_name and Pickups and Pickups.by_name and Pickups.by_name[pickup_name] or nil

	return pickup_name, settings
end

local function nearest_matching_pickup(unit, max_distance, predicate)
	local pickup_system = extension_system("pickup_system")
	local unit_to_extension_map = pickup_system and pickup_system._unit_to_extension_map
	local unit_position = plain_vector(POSITION_LOOKUP[unit])

	if not (unit_to_extension_map and unit_position) then
		return nil, nil, nil, nil
	end

	local best_unit, best_distance_sq, best_name, best_settings
	local max_distance_sq = max_distance * max_distance

	for pickup_unit in pairs(unit_to_extension_map) do
		local pickup_position = plain_vector(pickup_unit and POSITION_LOOKUP[pickup_unit])

		if pickup_position and unit_alive(pickup_unit) then
			local ok, distance_sq = pcall(Vector3.distance_squared, unit_position, pickup_position)

			if ok and distance_sq <= max_distance_sq and (not best_distance_sq or distance_sq < best_distance_sq) then
				local pickup_name, settings = pickup_settings_for_unit(pickup_unit)

				if pickup_name and predicate(pickup_unit, pickup_name, settings) then
					best_unit = pickup_unit
					best_distance_sq = distance_sq
					best_name = pickup_name
					best_settings = settings
				end
			end
		end
	end

	return best_unit, best_distance_sq, best_name, best_settings
end

local function pickup_is_health(pickup_name, settings)
	return pickup_name and string.find(pickup_name, "health", 1, true) ~= nil
		or settings and settings.group == "health"
end

local function pickup_is_grenade(pickup_name, settings)
	return pickup_name == "small_grenade"
		or pickup_name and string.find(pickup_name, "grenade", 1, true) ~= nil
		or settings and settings.group == "grenade"
end

local function pickup_is_resource(pickup_name, settings)
	return RESOURCE_PICKUPS[pickup_name] == true or settings and settings.group == "forge_material"
end

function M.pickup_claimed_by_other(pickup_unit, unit, t)
	local claim = pickup_unit and M._pickup_claims[pickup_unit]

	return claim and claim.unit ~= unit and t < (claim.until_t or -math.huge)
end

function M.claim_pickup(pickup_unit, unit, t, reason)
	if pickup_unit then
		M._pickup_claims[pickup_unit] = {
			unit = unit,
			reason = reason,
			until_t = t + M.PICKUP_CLAIM_DURATION,
		}
	end
end

local function bot_can_take_slot(unit, settings)
	local slot_name = settings and (settings.slot_name or settings.inventory_slot_name)

	return slot_name and slot_is_empty(inventory_component(unit), slot_name) or false
end

local function wants_pickup(unit, pickup_name, settings)
	if not pickup_name then
		return false
	end

	if pickup_name == "grimoire" then
		return false
	end

	if pickup_is_resource(pickup_name, settings) then
		return true
	end

	if settings and settings.group == "ammo" then
		local ammo = ammo_percent(unit)
		local policy = M.learned_policy(unit) or {}
		local ammo_threshold = policy.ammo_search_threshold or AMMO_SEARCH_THRESHOLD

		return ammo and ammo <= ammo_threshold or any_teammate_needs_ammo(unit)
	end

	if pickup_is_grenade(pickup_name, settings) then
		return ability_ready(unit, "grenade_ability") == false
	end

	if pickup_is_health(pickup_name, settings) then
		local hp = health_percent(unit)
		local wound = permanent_damage_percent(unit) or 0

		return hp and hp <= DEPLOYABLE_HEALTH_THRESHOLD or wound >= DEPLOYABLE_WOUND_THRESHOLD or any_teammate_needs_health(unit)
	end

	if settings and (settings.slot_name or settings.inventory_slot_name) then
		return bot_can_take_slot(unit, settings)
	end

	return false
end

local function nudge_nearby_pickups(unit, blackboard, t)
	local pickup = blackboard and blackboard.pickup
	local behavior = blackboard and blackboard.behavior
	local perception = blackboard and blackboard.perception

	if not (pickup and behavior) then
		return
	end

	if behavior.current_interaction_unit or behavior.interaction_unit or behavior.forced_pickup_unit then
		return
	end

	if perception and perception.target_ally_needs_aid and perception.target_ally_need_type ~= "in_need_of_attention_look" then
		return
	end

	local policy = M.learned_policy(unit) or {}
	local pickup_enemy_skip = policy.pickup_enemy_skip or PICKUP_SKIP_IF_ENEMIES_WITHIN
	local pickup_search_range = policy.pickup_search_range or PICKUP_SEARCH_RANGE

	if enemies_nearby(unit, pickup_enemy_skip) then
		return
	end

	local last_scan = _last_pickup_scan_by_unit[unit] or -math.huge

	if t - last_scan < PICKUP_SCAN_COOLDOWN then
		return
	end

	_last_pickup_scan_by_unit[unit] = t

	local pickup_unit, distance_sq, pickup_name, settings = nearest_matching_pickup(unit, pickup_search_range, function(candidate, name, data)
		return candidate ~= pickup.mule_pickup and not M.pickup_claimed_by_other(candidate, unit, t) and wants_pickup(unit, name, data)
	end)

	if not pickup_unit then
		return
	end

	local distance = math.sqrt(distance_sq)
	local slot_name = settings and (settings.slot_name or settings.inventory_slot_name)

	if (settings and settings.group == "ammo") or pickup_is_grenade(pickup_name, settings) then
		pickup.needs_ammo = true
		pickup.ammo_pickup = pickup_unit
		pickup.ammo_pickup_distance = distance
		pickup.ammo_pickup_valid_until = t + 6
	elseif pickup_is_health(pickup_name, settings) then
		pickup.needs_non_permanent_health = true
		pickup.allowed_to_take_health_pickup = true
		pickup.health_deployable = pickup_unit
		pickup.health_deployable_distance = distance
		pickup.health_deployable_valid_until = t + 6
	elseif slot_name or pickup_is_resource(pickup_name, settings) then
		M.claim_pickup(pickup_unit, unit, t, pickup_is_resource(pickup_name, settings) and "resource" or "pickup")
		pickup.mule_pickup = pickup_unit
		pickup.mule_pickup_distance = distance

		if distance <= PICKUP_OPEN_RANGE then
			behavior.interaction_unit = pickup_unit
			behavior.forced_pickup_unit = pickup_unit
		end
	else
		return
	end

	tag_item(unit, pickup_unit, pickup_name)
	refresh_follow(blackboard)

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: bot moving toward pickup %s.", tostring(pickup_name))
	end
end

local function nudge_looting(unit, blackboard, t)
	local pickup = blackboard and blackboard.pickup

	if not pickup then
		return
	end

	local ammo = ammo_percent(unit)
	local policy = M.learned_policy(unit) or {}
	local ammo_threshold = policy.ammo_search_threshold or AMMO_SEARCH_THRESHOLD

	if ammo and ammo <= ammo_threshold then
		pickup.needs_ammo = true

		if pickup.ammo_pickup then
			pickup.ammo_pickup_valid_until = math.max(pickup.ammo_pickup_valid_until or -math.huge, t + 6)
			refresh_follow(blackboard)
		end
	end

	local hp = health_percent(unit)
	local wound = permanent_damage_percent(unit) or 0
	local wants_heal = hp and hp <= DEPLOYABLE_HEALTH_THRESHOLD or wound >= DEPLOYABLE_WOUND_THRESHOLD

	if wants_heal then
		pickup.needs_non_permanent_health = true
		pickup.allowed_to_take_health_pickup = true

		if hp and hp <= 0.25 then
			pickup.force_use_health_pickup = true
		end

		if pickup.health_deployable then
			pickup.health_deployable_valid_until = math.max(pickup.health_deployable_valid_until or -math.huge, t + 6)
			refresh_follow(blackboard)
		end
	end
end

function M.nudge_resources(unit, blackboard, t)
	local pickup = blackboard and blackboard.pickup
	local behavior = blackboard and blackboard.behavior

	if not (pickup and behavior) then
		return
	end

	if behavior.current_interaction_unit or behavior.interaction_unit or behavior.forced_pickup_unit then
		return
	end

	if pickup.mule_pickup and unit_alive(pickup.mule_pickup) then
		return
	end

	local pickup_unit, distance_sq, pickup_name, settings = nearest_matching_pickup(unit, M.RESOURCE_SEARCH_RANGE, function(candidate, name, data)
		return not M.pickup_claimed_by_other(candidate, unit, t) and pickup_is_resource(name, data)
	end)

	if not pickup_unit then
		return
	end

	M.claim_pickup(pickup_unit, unit, t, "resource")
	pickup.mule_pickup = pickup_unit
	pickup.mule_pickup_distance = math.sqrt(distance_sq)
	tag_item(unit, pickup_unit, pickup_name)
	refresh_follow(blackboard)

	if pickup.mule_pickup_distance <= PICKUP_OPEN_RANGE then
		behavior.interaction_unit = pickup_unit
		behavior.forced_pickup_unit = pickup_unit
	end

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: bot claimed resource %s.", tostring(pickup_name))
	end
end

local function nudge_medicae(unit, blackboard)
	local health_station = blackboard and blackboard.health_station

	if not health_station then
		return
	end

	local hp = health_percent(unit)
	local wound = permanent_damage_percent(unit) or 0
	local policy = M.learned_policy(unit) or {}
	local medicae_threshold = policy.medicae_health_threshold or MEDICAE_HEALTH_THRESHOLD
	local should_use = hp and hp <= medicae_threshold or wound >= MEDICAE_WOUND_THRESHOLD

	if should_use then
		health_station.needs_health = true
		health_station.needs_health_queue_number = 1
		refresh_follow(blackboard)
	end
end

local function chest_is_open(chest_extension)
	if not chest_extension or not chest_extension.is_open then
		return true
	end

	local ok, is_open = pcall(chest_extension.is_open, chest_extension)

	return not ok or is_open
end

local function chest_has_interaction(target_unit)
	local interactee_extension = target_unit and ScriptUnit.has_extension(target_unit, "interactee_system")

	if not interactee_extension then
		return false
	end

	local ok_type, interaction_type = pcall(interactee_extension.interaction_type, interactee_extension)

	return ok_type and interaction_type ~= nil
end

local function nearest_unopened_chest(unit)
	local chest_system = extension_system("chest_system")
	local unit_to_extension_map = chest_system and chest_system._unit_to_extension_map

	if not unit_to_extension_map then
		return nil, nil
	end

	local unit_position = POSITION_LOOKUP[unit]

	if not unit_position then
		return nil, nil
	end

	local best_unit, best_distance_sq
	local max_distance_sq = CHEST_SEARCH_RANGE * CHEST_SEARCH_RANGE

	for chest_unit, chest_extension in pairs(unit_to_extension_map) do
		local chest_position = chest_unit and POSITION_LOOKUP[chest_unit]

		if chest_position and unit_alive(chest_unit) and not chest_is_open(chest_extension) and chest_has_interaction(chest_unit) then
			local distance_sq = Vector3.distance_squared(unit_position, chest_position)

			if distance_sq <= max_distance_sq and (not best_distance_sq or distance_sq < best_distance_sq) then
				best_unit = chest_unit
				best_distance_sq = distance_sq
			end
		end
	end

	return best_unit, best_distance_sq
end

local function clear_stale_chest_order(unit, pickup, behavior)
	local ordered = _last_chest_order_by_unit[unit]
	local chest_unit = ordered and ordered.unit

	if not chest_unit then
		return
	end

	local chest_extension = ScriptUnit.has_extension(chest_unit, "chest_system")

	if unit_alive(chest_unit) and not chest_is_open(chest_extension) then
		return
	end

	if pickup.mule_pickup == chest_unit then
		pickup.mule_pickup = nil
		pickup.mule_pickup_distance = math.huge
	end

	if behavior.interaction_unit == chest_unit then
		behavior.interaction_unit = nil
	end

	if behavior.forced_pickup_unit == chest_unit then
		behavior.forced_pickup_unit = nil
	end

	_last_chest_order_by_unit[unit] = nil
end

local function nudge_chests(unit, blackboard, t)
	local pickup = blackboard and blackboard.pickup
	local behavior = blackboard and blackboard.behavior
	local perception = blackboard and blackboard.perception

	if not (pickup and behavior) then
		return
	end

	clear_stale_chest_order(unit, pickup, behavior)

	if enemies_nearby(unit, CHEST_SKIP_IF_ENEMIES_WITHIN) then
		return
	end

	if behavior.current_interaction_unit then
		return
	end

	local existing_pickup = pickup.mule_pickup

	if behavior.interaction_unit and behavior.interaction_unit ~= existing_pickup then
		return
	end

	if behavior.forced_pickup_unit and behavior.forced_pickup_unit ~= existing_pickup then
		return
	end

	if perception and perception.target_ally_needs_aid and perception.target_ally_need_type ~= "in_need_of_attention_look" then
		return
	end

	if pickup.needs_ammo and pickup.ammo_pickup or pickup.needs_non_permanent_health and pickup.health_deployable then
		return
	end

	local stimm_entry = stimm_pickup_entry(pickup.mule_pickup)

	if stimm_entry then
		return
	end

	local scan_at = _last_chest_scan_by_unit[unit] or -math.huge

	if t - scan_at < CHEST_SCAN_COOLDOWN then
		return
	end

	_last_chest_scan_by_unit[unit] = t

	local chest_unit, distance_sq = nearest_unopened_chest(unit)

	if not chest_unit then
		return
	end

	local last_order = _last_chest_order_by_unit[unit]
	local should_announce = not last_order or last_order.unit ~= chest_unit or t - last_order.t >= CHEST_ORDER_COOLDOWN

	pickup.mule_pickup = chest_unit
	pickup.mule_pickup_distance = math.sqrt(distance_sq)

	if pickup.mule_pickup_distance <= CHEST_OPEN_RANGE then
		behavior.interaction_unit = chest_unit
		behavior.forced_pickup_unit = chest_unit
	end

	refresh_follow(blackboard)

	if should_announce then
		_last_chest_order_by_unit[unit] = {
			t = t,
			unit = chest_unit,
		}

		tag_item(unit, chest_unit, "container")

		if _mod and _mod:get("detailed_logging") then
			_mod:info("Custom Character Bots: bot moving to unopened chest.")
		end
	end
end

local function nudge_item_tags(unit, blackboard)
	local pickup = blackboard and blackboard.pickup
	local perception = blackboard and blackboard.perception

	local target_unit = current_target(unit, blackboard)

	if target_unit and unit_alive(target_unit) and is_priority_enemy(target_unit) then
		tag_enemy(unit, target_unit, "enemy")

		return
	end

	if pickup and pickup.ammo_pickup and any_teammate_needs_ammo(unit) then
		tag_item(unit, pickup.ammo_pickup, "ammo")

		return
	end

	if pickup and pickup.health_deployable and any_teammate_needs_health(unit) then
		tag_item(unit, pickup.health_deployable, "health")

		return
	end

	local health_station = perception and perception.target_level_unit

	if health_station and ScriptUnit.has_extension(health_station, "health_station_system") and any_teammate_needs_health(unit) then
		tag_item(unit, health_station, "medicae")
	end
end

local function current_wielded_weapon_template(unit)
	local inventory = inventory_component(unit)
	local wielded_slot = inventory and inventory.wielded_slot

	return wielded_slot and weapon_template_from_slot(unit, wielded_slot) or nil
end

local function template_has_action_input(template, input_name)
	local action_inputs = template and template.action_inputs

	return type(action_inputs) == "table" and action_inputs[input_name] ~= nil
end

local function nudge_weapon_special(unit, blackboard, t)
	local last_t = _last_weapon_special_by_unit[unit] or -math.huge

	if t - last_t < WEAPON_SPECIAL_COOLDOWN then
		return
	end

	local target = current_target(unit, blackboard)

	if not (target and unit_alive(target)) then
		return
	end

	local distance = target_distance(unit, target)

	if distance > WEAPON_SPECIAL_RANGE and not is_priority_enemy(target) then
		return
	end

	local template = current_wielded_weapon_template(unit)
	local candidates = {
		"special_action",
		"weapon_special",
		"special_action_start",
		"special_action_push",
		"special_action_pistol_whip",
		"stab",
		"bash",
	}

	for i = 1, #candidates do
		local input_name = candidates[i]

		if template_has_action_input(template, input_name) and queue_weapon_input(unit, input_name, nil) then
			_last_weapon_special_by_unit[unit] = t
			debug_count("weapon_special_queued")

			return
		end
	end

	debug_count("weapon_special_no_input")
	_last_weapon_special_by_unit[unit] = t + 1
end

local function has_live_enemy_goal(perception)
	local target = perception and (perception.priority_target_enemy or perception.urgent_target_enemy or perception.target_enemy)

	return target and unit_alive(target) or false
end

function M.follow_anchor_position(bot_group_data)
	if not bot_group_data then
		return nil
	end

	local follow_unit = bot_group_data.follow_unit

	if follow_unit and HEALTH_ALIVE[follow_unit] then
		return plain_vector(POSITION_LOOKUP[follow_unit])
	end

	return plain_vector(bot_group_data.follow_position)
end

function M.idle_anchor_position(unit, bot_group_data)
	return M.follow_anchor_position(bot_group_data) or plain_vector(POSITION_LOOKUP[unit])
end

local function should_scout(unit, bot_group_data, behavior, pickup, perception)
	local anchor_position = M.idle_anchor_position(unit, bot_group_data)

	if not anchor_position then
		return false
	end

	if behavior and (behavior.current_interaction_unit or behavior.interaction_unit or behavior.forced_pickup_unit) then
		return false
	end

	if perception and perception.target_ally_needs_aid and perception.target_ally_need_type ~= "in_need_of_attention_look" then
		return false
	end

	local policy = M.learned_policy(unit) or {}
	local max_leash = policy.scout_max_leash or SCOUT_MAX_LEASH
	local unit_position = plain_vector(POSITION_LOOKUP[unit])

	return unit_position and vector_distance(unit_position, anchor_position) <= max_leash
end

local function nudge_scout_refresh(self, unit, blackboard, t)
	local group_extension = self and self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local behavior = blackboard and blackboard.behavior
	local pickup = blackboard and blackboard.pickup
	local perception = blackboard and blackboard.perception

	if not should_scout(unit, bot_group_data, behavior, pickup, perception) then
		return
	end

	local last_refresh = _last_scout_refresh_by_unit[unit] or -math.huge

	if t - last_refresh < SCOUT_DEST_REFRESH_COOLDOWN then
		return
	end

	_last_scout_refresh_by_unit[unit] = t
	refresh_follow(blackboard)
end

local function scout_state(unit)
	local state = _scout_state_by_unit[unit]

	if not state then
		state = {
			next_pick_t = -math.huge,
		}
		_scout_state_by_unit[unit] = state
	end

	return state
end

function M.autonomy_state(unit)
	local state = _autonomy_state_by_unit[unit]

	if not state then
		state = {
			next_move_t = -math.huge,
			lane = math.random() * math.pi * 2,
		}
		_autonomy_state_by_unit[unit] = state
	end

	return state
end

function M.autonomy_allowed(unit, blackboard)
	local behavior = blackboard and blackboard.behavior
	local perception = blackboard and blackboard.perception

	if behavior and (behavior.current_interaction_unit or behavior.interaction_unit or behavior.forced_pickup_unit) then
		return false
	end

	if perception and perception.target_ally_needs_aid and perception.target_ally_need_type ~= "in_need_of_attention_look" then
		return false
	end

	return true
end

function M.clear_autonomy(unit)
	local state = _autonomy_state_by_unit[unit]

	if state then
		state.position = nil
		state.reason = nil
		state.until_t = -math.huge
	end
end

function M.active_autonomy_position(unit, blackboard, t)
	local state = _autonomy_state_by_unit[unit]

	if not state or not state.position or not (t < (state.until_t or -math.huge)) then
		return nil
	end

	if not M.autonomy_allowed(unit, blackboard) then
		M.clear_autonomy(unit)

		return nil
	end

	return plain_vector(state.position), state.reason
end

function M.force_autonomy_destination(self, unit, blackboard, destination, reason, t)
	debug_count("force_called")
	destination = plain_vector(destination)

	if not destination or not M.autonomy_allowed(unit, blackboard) then
		debug_count("force_blocked")
		M.clear_autonomy(unit)

		return false
	end

	local unit_position = plain_vector(POSITION_LOOKUP[unit])

	if not unit_position or vector_distance(unit_position, destination) <= AUTONOMY_REACHED_DISTANCE then
		debug_count("force_reached")
		M.clear_autonomy(unit)

		return false
	end

	local group_extension = self and self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local follow_position = M.idle_anchor_position(unit, bot_group_data)
	local policy = M.learned_policy(unit) or {}
	local max_leash = (policy.scout_max_leash or SCOUT_MAX_LEASH) + M.AUTONOMY_LEASH_GRACE

	if follow_position and vector_distance(destination, follow_position) > max_leash then
		debug_count("force_leash")
		M.clear_autonomy(unit)

		return false
	end

	local navigation_extension = self and self._navigation_extension or ScriptUnit.has_extension(unit, "navigation_system")

	if not (navigation_extension and navigation_extension.move_to) then
		debug_count("force_no_nav")

		return false
	end

	local follow_component = self and self._follow_component or blackboard and blackboard.follow

	if follow_component then
		if follow_component.destination and follow_component.destination.store then
			pcall(follow_component.destination.store, follow_component.destination, destination)
		end

		follow_component.moving_towards_follow_position = false
		follow_component.needs_destination_refresh = true
	end

	if self then
		self._follow_timer = -1
		self._using_navigation_destination_override = false
	end

	local state = M.autonomy_state(unit)

	if t >= (state.next_force_t or -math.huge) then
		local ok = pcall(navigation_extension.move_to, navigation_extension, destination)

		if not ok then
			debug_count("force_move_to_fail")

			return false
		end

		debug_count("force_move_to_ok")
		state.next_force_t = t + M.AUTONOMY_REPATH_COOLDOWN
	end

	state.position = destination
	state.reason = reason
	state.until_t = t + M.AUTONOMY_HOLD_DURATION
	refresh_follow(blackboard)
	debug_count("force_active")

	return true
end

function M.objective_position(unit)
	return plain_vector(unit and POSITION_LOOKUP[unit])
end

function M.current_autonomy_objective(unit, blackboard)
	local pickup = blackboard and blackboard.pickup
	local perception = blackboard and blackboard.perception

	if pickup then
		local pickup_unit = pickup.mule_pickup or pickup.ammo_pickup or pickup.health_deployable

		if pickup_unit and unit_alive(pickup_unit) then
			return pickup_unit, M.objective_position(pickup_unit), "pickup"
		end
	end

	local target_unit = current_target(unit, blackboard)

	if target_unit and unit_alive(target_unit) and target_distance(unit, target_unit) <= AUTONOMY_ENEMY_MOVE_RANGE then
		return target_unit, M.objective_position(target_unit), "enemy"
	end

	return nil, nil, nil
end

function M.direct_move_to(self, unit, blackboard, destination, reason, t)
	destination = plain_vector(destination)

	if not destination then
		return false
	end

	local unit_position = plain_vector(POSITION_LOOKUP[unit])

	if not unit_position or vector_distance(unit_position, destination) <= AUTONOMY_REACHED_DISTANCE then
		return false
	end

	local state = M.autonomy_state(unit)

	if t < (state.next_move_t or -math.huge) then
		return false
	end

	local navigation_extension = self and self._navigation_extension or ScriptUnit.has_extension(unit, "navigation_system")

	if not (navigation_extension and navigation_extension.move_to) then
		debug_count("direct_no_nav")

		return false
	end

	local ok = pcall(navigation_extension.move_to, navigation_extension, destination)

	if not ok then
		debug_count("direct_move_fail")

		return false
	end

	debug_count("direct_move_ok")
	state.next_move_t = t + AUTONOMY_DIRECT_MOVE_COOLDOWN
	state.reason = reason
	refresh_follow(blackboard)

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: autonomous move toward %s.", tostring(reason))
	end

	return true
end

local function choose_scout_position(unit, bot_group_data, perception, behavior, pickup, t)
	if not should_scout(unit, bot_group_data, behavior, pickup, perception) then
		_scout_state_by_unit[unit] = nil

		return nil
	end

	local state = scout_state(unit)
	local unit_position = plain_vector(POSITION_LOOKUP[unit])
	local follow_position = M.idle_anchor_position(unit, bot_group_data)

	if not (unit_position and follow_position) then
		return nil
	end

	if state.position and t < (state.expires_t or -math.huge) and vector_distance(unit_position, state.position) > SCOUT_REACHED_DISTANCE then
		state.position = plain_vector(state.position)

		if not state.position then
			_scout_state_by_unit[unit] = nil

			return nil
		end

		return state.position
	end

	if t < (state.next_pick_t or -math.huge) then
		return nil
	end

	local away_x = unit_position.x - follow_position.x
	local away_y = unit_position.y - follow_position.y
	local base_angle = math.atan2 and math.atan2(away_y, away_x) or math.atan(away_y, away_x)
	local autonomy = M.autonomy_state(unit)
	local lane = autonomy.lane or 0
	local angle = base_angle + lane + (math.random() - 0.5) * (math.pi * 0.45)
	local policy = M.learned_policy(unit) or {}
	local scout_min_distance = policy.scout_min_distance or SCOUT_MIN_DISTANCE
	local scout_max_distance = policy.scout_max_distance or SCOUT_MAX_DISTANCE
	local scout_max_leash = policy.scout_max_leash or SCOUT_MAX_LEASH
	local distance = scout_min_distance + math.random() * (scout_max_distance - scout_min_distance)
	local offset = Vector3(math.cos(angle) * distance, math.sin(angle) * distance, 0)
	local scout_position = plain_vector(unit_position + offset)

	if vector_distance(scout_position, follow_position) > scout_max_leash then
		local leash_angle = lane + math.random() * math.pi * 0.75
		local leash_distance = scout_min_distance + math.random() * (scout_max_leash - scout_min_distance)
		scout_position = plain_vector(follow_position + Vector3(math.cos(leash_angle) * leash_distance, math.sin(leash_angle) * leash_distance, 0))
	end

	if not scout_position then
		_scout_state_by_unit[unit] = nil

		return nil
	end

	debug_count("scout_pick")
	state.position = scout_position
	state.expires_t = t + SCOUT_REFRESH_MIN + math.random() * (SCOUT_REFRESH_MAX - SCOUT_REFRESH_MIN)
	state.next_pick_t = t + 1
	autonomy.lane = lane + 2.399963229728653

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: bot scouting %.1fm from player.", distance)
	end

	return scout_position
end

function M.nudge_autonomous_movement(self, unit, blackboard, t)
	local state = M.autonomy_state(unit)

	if state.position and t < (state.until_t or -math.huge) then
		if M.force_autonomy_destination(self, unit, blackboard, state.position, state.reason or "autonomy", t) then
			return
		end
	end

	local objective_unit, destination, reason = M.current_autonomy_objective(unit, blackboard)

	if objective_unit and destination then
		if M.force_autonomy_destination(self, unit, blackboard, destination, reason, t) then
			return
		end
	end

	local group_extension = self and self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local behavior = blackboard and blackboard.behavior
	local pickup = blackboard and blackboard.pickup
	local perception = blackboard and blackboard.perception
	local scout_position = choose_scout_position(unit, bot_group_data, perception, behavior, pickup, t)

	if scout_position then
		M.force_autonomy_destination(self, unit, blackboard, scout_position, "scout", t)
	end
end

function M.ensure_idle_autonomy(self, unit, blackboard, t)
	if M.active_autonomy_position(unit, blackboard, t) then
		return
	end

	if not M.autonomy_allowed(unit, blackboard) then
		return
	end

	local group_extension = self and self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local behavior = blackboard and blackboard.behavior
	local pickup = blackboard and blackboard.pickup
	local perception = blackboard and blackboard.perception
	local scout_position = choose_scout_position(unit, bot_group_data, perception, behavior, pickup, t)

	if scout_position then
		M.force_autonomy_destination(self, unit, blackboard, scout_position, "idle_scout", t)
	end
end

local function should_sprint(self, unit)
	debug_count("sprint_check")
	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]
	local autonomy_position = M.active_autonomy_position(unit, blackboard, now())
	local moving_forward = self and self._move and self._move.y >= 0.35
	local has_autonomy_run = autonomy_position ~= nil
	local group_extension = self and self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local follow_position = M.follow_anchor_position(bot_group_data)

	if follow_position then
		local unit_position = plain_vector(POSITION_LOOKUP[unit])

		if unit_position and follow_position then
			local ok, distance_sq = pcall(Vector3.distance_squared, unit_position, follow_position)

			if ok and distance_sq > SPRINT_FOLLOW_DISTANCE * SPRINT_FOLLOW_DISTANCE and (moving_forward or has_autonomy_run) then
				debug_count("sprint_true")

				return true
			end
		end
	end

	local perception = blackboard and blackboard.perception

	if perception and perception.target_ally_needs_aid and perception.target_ally_need_type ~= "in_need_of_attention_look" then
		debug_count("sprint_true")

		return true
	end

	if has_autonomy_run then
		debug_count("sprint_true")

		return true
	end

	local perception_extension = ScriptUnit.has_extension(unit, "perception_system")

	if perception_extension then
		local ok, _units, num_enemies = pcall(perception_extension.enemies_in_proximity, perception_extension)

		if ok and num_enemies == 0 and moving_forward then
			debug_count("sprint_true")

			return true
		end
	end

	debug_count("sprint_false")

	return false
end

local function should_dodge_hazard(self, unit, t)
	local group_extension = self._group_extension
	local bot_group_data = group_extension and group_extension:bot_group_data()
	local threat_data = bot_group_data and bot_group_data.aoe_threat

	if not threat_data or not (t < (threat_data.expires or -math.huge)) then
		return false
	end

	local last_dodge = _last_dodge_by_unit[unit] or -math.huge

	return t - last_dodge >= DODGE_COOLDOWN
end

local function movement_flair_state(unit)
	local state = _movement_flair_by_unit[unit]

	if not state then
		state = {
			next_slide_t = -math.huge,
		}
		_movement_flair_by_unit[unit] = state
	end

	return state
end

local function should_crouch_slide(unit, sprinting, t)
	if not sprinting then
		return false
	end

	local state = movement_flair_state(unit)

	if t < (state.slide_until_t or -math.huge) then
		return true
	end

	if t < (state.next_slide_t or -math.huge) then
		return false
	end

	local target = current_target(unit, BLACKBOARDS and BLACKBOARDS[unit])
	local target_ok = not target or target_distance(unit, target) > COMBAT_DODGE_RANGE

	if not target_ok then
		return false
	end

	state.slide_until_t = t + SLIDE_DURATION
	state.next_slide_t = t + SLIDE_COOLDOWN_MIN + math.random() * (SLIDE_COOLDOWN_MAX - SLIDE_COOLDOWN_MIN)

	return true
end

local function should_combat_dodge(unit, t)
	local target = current_target(unit, BLACKBOARDS and BLACKBOARDS[unit])

	if not (target and unit_alive(target) and target_distance(unit, target) <= COMBAT_DODGE_RANGE) then
		return false
	end

	local last_dodge = _last_dodge_by_unit[unit] or -math.huge

	return t - last_dodge >= COMBAT_DODGE_COOLDOWN
end

function M.apply_post_input_update(self, unit, _dt, t)
	debug_count("post_input_called")

	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		debug_count("post_input_skipped")

		return
	end

	debug_count("post_input_custom")

	t = t or now()

	local move_x, move_y = M.move_axes_for_input(self, unit, t)

	if move_x and move_y and self._move then
		self._move.x = move_x
		self._move.y = move_y
		debug_count("post_input_move_override")
	end

	local input = self._input
	local sprinting = should_sprint(self, unit)

	if input then
		input.hold_to_sprint = true
		input.sprinting = sprinting
		input.crouching = input.crouching or should_crouch_slide(unit, sprinting, t)
	end

	if sprinting then
		debug_count("post_input_sprint_true")
	end

	if should_dodge_hazard(self, unit, t) or should_combat_dodge(unit, t) then
		self:dodge()

		if input then
			input.dodge = true
		end

		_last_dodge_by_unit[unit] = t
		debug_count("post_input_dodge")
	end
end

function M.update_behavior(self, unit, blackboard, _dt, t)
	debug_count("update_called")

	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		debug_count("update_skipped")

		return
	end

	debug_count("update_custom")

	if self.set_stay_near_player then
		self:set_stay_near_player(false)
	end

	t = t or now()

	M.ensure_bot_unit_input_hooks(t)
	patch_supported_pickups(t)
	nudge_targeting(unit, blackboard, t)
	nudge_looting(unit, blackboard, t)
	M.nudge_resources(unit, blackboard, t)
	nudge_medicae(unit, blackboard)
	nudge_nearby_pickups(unit, blackboard, t)
	nudge_stimm_pickups(unit, blackboard)
	update_stimm_use(unit, blackboard, t)
	update_ability_fallback(unit, blackboard, t)
	nudge_weapon_special(unit, blackboard, t)
	nudge_chests(unit, blackboard, t)
	nudge_item_tags(unit, blackboard)
	nudge_scout_refresh(self, unit, blackboard, t)
	M.nudge_autonomous_movement(self, unit, blackboard, t)
	M.ensure_idle_autonomy(self, unit, blackboard, t)
end

function M.update_perception(unit, blackboard, _dt, t)
	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		return
	end

	nudge_targeting(unit, blackboard, t or now())
end

function M.update_movement_target(self, unit, _dt, t)
	debug_count("movement_target_called")

	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		debug_count("movement_target_skipped")

		return
	end

	debug_count("movement_target_custom")
	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]

	t = t or now()
	M.ensure_idle_autonomy(self, unit, blackboard, t)

	local autonomy_position, reason = M.active_autonomy_position(unit, blackboard, t)

	if autonomy_position then
		debug_count("movement_target_active")
		M.force_autonomy_destination(self, unit, blackboard, autonomy_position, reason or "autonomy", t)
	end
end

function M.move_axes_for_input(self, unit, t)
	debug_count("move_input_called")

	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		debug_count("move_input_skipped")

		return nil, nil
	end

	debug_count("move_input_custom")
	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]

	t = t or now()
	M.ensure_idle_autonomy(self, unit, blackboard, t)

	local autonomy_position = M.active_autonomy_position(unit, blackboard, t)

	if not autonomy_position then
		debug_count("move_input_no_destination")

		return nil, nil
	end

	local navigation_extension = self and self._navigation_extension

	if navigation_extension and navigation_extension.is_in_transition and navigation_extension:is_in_transition() then
		return nil, nil
	end

	local unit_position = plain_vector(POSITION_LOOKUP[unit])

	if not unit_position or vector_distance(unit_position, autonomy_position) <= AUTONOMY_REACHED_DISTANCE then
		debug_count("move_input_reached")

		return nil, nil
	end

	local ok, move_x, move_y = pcall(function()
		local first_person = self and self._first_person_component
		local rotation = first_person and first_person.rotation or Unit.local_rotation(unit, 1)
		local direction = Vector3.normalize(Vector3.flat(autonomy_position - unit_position))
		local right = Vector3.normalize(Vector3.flat(Quaternion.right(rotation)))
		local forward = Vector3.normalize(Vector3.flat(Quaternion.forward(rotation)))

		return Vector3.dot(right, direction), math.max(Vector3.dot(forward, direction), 0.65)
	end)

	if not ok then
		debug_count("move_input_vector_fail")

		return nil, nil
	end

	debug_count("move_input_vector_ok")
	return move_x, move_y
end

function M.install_bot_unit_input_hooks(BotUnitInput)
	local installed = false

	if not BotUnitInput then
		return false
	end

	if rawget(BotUnitInput, "__ccb_playerlike_extensions_ready_patch") ~= M.INPUT_HOOK_VERSION
		and type(BotUnitInput.extensions_ready) == "function"
	then
		BotUnitInput.__ccb_playerlike_extensions_ready_patch = M.INPUT_HOOK_VERSION

		_mod:hook_safe(BotUnitInput, "extensions_ready", function(self, _world, unit)
			self._ccb_playerlike_unit = unit
		end)

		installed = true
	end

	if rawget(BotUnitInput, "__ccb_playerlike_post_update_patch") ~= M.INPUT_HOOK_VERSION and type(BotUnitInput.update) == "function" then
		BotUnitInput.__ccb_playerlike_post_update_patch = M.INPUT_HOOK_VERSION

		_mod:hook(BotUnitInput, "update", function(func, self, unit, dt, t)
			if type(func) == "function" then
				func(self, unit, dt, t)
			end

			M.apply_post_input_update(self, unit, dt, t)
		end)

		installed = true
	end

	if rawget(BotUnitInput, "__ccb_playerlike_sprint_patch") == M.INPUT_HOOK_VERSION then
		return installed
	end

	if type(BotUnitInput._update_movement) ~= "function" then
		return installed
	end

	BotUnitInput.__ccb_playerlike_sprint_patch = M.INPUT_HOOK_VERSION

	_mod:hook(BotUnitInput, "_update_movement", function(func, self, unit, input, dt, t)
		if type(func) == "function" then
			func(self, unit, input, dt, t)
		end

		if not feature_enabled() or not is_custom_bot(unit) then
			return
		end

		local sprinting = should_sprint(self, unit)
		local move_x, move_y = M.move_axes_for_input(self, unit, t)

		if move_x and move_y then
			self._move.x = move_x
			self._move.y = move_y
			input.move = self._move
		end

		input.hold_to_sprint = true
		input.sprinting = sprinting
		input.crouching = input.crouching or should_crouch_slide(unit, sprinting, t)

		if should_dodge_hazard(self, unit, t) or should_combat_dodge(unit, t) then
			self:dodge()
			input.dodge = true
			_last_dodge_by_unit[unit] = t
		end

		local previous = _last_sprint_state_by_unit[unit]

		if previous ~= sprinting then
			_last_sprint_state_by_unit[unit] = sprinting

			if _mod and _mod:get("detailed_logging") then
				_mod:info("Custom Character Bots: sprint %s.", sprinting and "started" or "stopped")
			end
		end
	end)

	return true
end

function M.install_bot_unit_input_get_hook(BotUnitInput)
	if not BotUnitInput or rawget(BotUnitInput, "__ccb_playerlike_move_get_patch") == M.INPUT_HOOK_VERSION then
		return false
	end

	if type(BotUnitInput.get) ~= "function" then
		return false
	end

	BotUnitInput.__ccb_playerlike_move_get_patch = M.INPUT_HOOK_VERSION
	BotUnitInput.__ccb_playerlike_behavior_dispatch = M

	_mod:hook(BotUnitInput, "get", function(func, self, action)
		local behavior = rawget(BotUnitInput, "__ccb_playerlike_behavior_dispatch") or M
		local player = self and self._player
		local unit = self and self._ccb_playerlike_unit or player and player.player_unit

		if action == "move" then
			if behavior and behavior.move_axes_for_input and unit then
				local move_x, move_y = behavior.move_axes_for_input(self, unit, now())

				if move_x and move_y then
					debug_count("get_move_override")

					return Vector3(move_x, move_y, 0)
				end
			end
		elseif action == "hold_to_sprint" and unit and feature_enabled() and is_custom_bot(unit) then
			debug_count("get_hold_to_sprint")

			return true
		elseif action == "sprinting" and unit and feature_enabled() and is_custom_bot(unit) then
			local sprinting = should_sprint(self, unit)

			if sprinting then
				debug_count("get_sprinting_true")

				return true
			end
		elseif action == "crouching" and unit and feature_enabled() and is_custom_bot(unit) then
			local sprinting = should_sprint(self, unit)

			if should_crouch_slide(unit, sprinting, now()) then
				debug_count("get_crouching_true")

				return true
			end
		end

		if type(func) == "function" then
			return func(self, action)
		end

		return nil
	end)

	return true
end

function M.ensure_bot_unit_input_hooks(t)
	if t < (_next_input_hook_retry_t or -math.huge) then
		return
	end

	_next_input_hook_retry_t = t + 2

	local ok, BotUnitInput = pcall(require, "scripts/extension_systems/input/bot_unit_input")

	if not ok or not BotUnitInput then
		return
	end

	BotUnitInput.__ccb_playerlike_behavior_dispatch = M
	M.install_bot_unit_input_get_hook(BotUnitInput)
	M.install_bot_unit_input_hooks(BotUnitInput)
end

function M.install_bot_group_hooks(BotGroup)
	if not BotGroup or rawget(BotGroup, "__ccb_playerlike_pickup_patch") then
		return
	end

	BotGroup.__ccb_playerlike_pickup_patch = true

	_mod:hook_safe(BotGroup, "init", function(self)
		patch_supported_pickups(now(), true)
		ensure_mule_pickup_slots(self)
	end)

	if type(BotGroup._update_mule_pickups) == "function" then
		_mod:hook(BotGroup, "_update_mule_pickups", function(func, self, ...)
			patch_supported_pickups(now(), true)
			ensure_mule_pickup_slots(self)

			return func(self, ...)
		end)
	end
end

local function with_engage_leash(action_data, callback)
	if not action_data then
		return callback()
	end

	local original_override = action_data.override_engage_range_to_follow_position
	local original_challenge = action_data.override_engage_range_to_follow_position_challenge
	local original_engage = action_data.engage_range

	action_data.override_engage_range_to_follow_position = math.max(original_override or 0, ENGAGE_LEASH_RANGE)
	action_data.override_engage_range_to_follow_position_challenge = math.max(original_challenge or 0, ENGAGE_LEASH_RANGE)

	if action_data.engage_range_near_follow_position then
		action_data.engage_range = math.max(original_engage or 0, action_data.engage_range_near_follow_position)
	end

	local ok, result = pcall(callback)

	action_data.override_engage_range_to_follow_position = original_override
	action_data.override_engage_range_to_follow_position_challenge = original_challenge
	action_data.engage_range = original_engage

	if not ok then
		error(result, 0)
	end

	return result
end

function M.install_bot_melee_action_hooks(BtBotMeleeAction)
	if not BtBotMeleeAction then
		return
	end

	if type(BtBotMeleeAction._allow_engage) == "function" then
	_mod:hook(
		BtBotMeleeAction,
		"_allow_engage",
		function(
			func,
			self,
			self_unit,
			target_unit,
			target_position,
			target_breed,
			scratchpad,
			action_data,
			already_engaged,
			aim_position,
			follow_position
		)
			if type(func) ~= "function" then
				return false
			end

			if not feature_enabled() or not is_custom_bot(self_unit) then
				return func(
					self,
					self_unit,
					target_unit,
					target_position,
					target_breed,
					scratchpad,
					action_data,
					already_engaged,
					aim_position,
					follow_position
				)
			end

			return with_engage_leash(action_data, function()
				return func(
					self,
					self_unit,
					target_unit,
					target_position,
					target_breed,
					scratchpad,
					action_data,
					already_engaged,
					aim_position,
					follow_position
				)
			end)
		end
	)
	end

	if type(BtBotMeleeAction._is_in_engage_range) == "function" then
	_mod:hook(
		BtBotMeleeAction,
		"_is_in_engage_range",
		function(func, self, self_position, target_position, action_data, follow_position)
			if type(func) ~= "function" then
				return false
			end

			local unit = self and self._unit

			if not feature_enabled() or not is_custom_bot(unit) then
				return func(self, self_position, target_position, action_data, follow_position)
			end

			return with_engage_leash(action_data, function()
				return func(self, self_position, target_position, action_data, follow_position)
			end)
		end
	)
	end

	if type(BtBotMeleeAction._should_defend) == "function" then
		_mod:hook(BtBotMeleeAction, "_should_defend", function(func, self, unit, target_unit, scratchpad)
			if type(func) ~= "function" then
				return false
			end

			local result = func(self, unit, target_unit, scratchpad)

			if scratchpad then
				scratchpad._ccb_bot_unit = unit
			end

			if result or not feature_enabled() or not is_custom_bot(unit) then
				return result
			end

			local data_ext = target_unit and ScriptUnit.has_extension(target_unit, "unit_data_system")
			local target_breed = data_ext and data_ext:breed()

			if target_breed and target_breed.name == POXBURSTER_BREED_NAME then
				return true
			end

			return false
		end)
	end

	if type(BtBotMeleeAction._should_push) == "function" then
		_mod:hook(
			BtBotMeleeAction,
			"_should_push",
			function(func, self, defense_meta_data, scratchpad, in_melee_range, target_unit, target_breed, fixed_t)
				if type(func) ~= "function" then
					return false
				end

				local unit = scratchpad and scratchpad._ccb_bot_unit

				if feature_enabled()
					and unit
					and is_custom_bot(unit)
					and target_breed
					and target_breed.name == POXBURSTER_BREED_NAME
					and in_melee_range
				then
					local push_action_input = defense_meta_data and defense_meta_data.push_action_input
					local weapon_extension = scratchpad and scratchpad.weapon_extension

					if push_action_input
						and weapon_extension
						and weapon_extension.action_input_is_currently_valid
						and weapon_extension:action_input_is_currently_valid("weapon_action", push_action_input, nil, fixed_t)
					then
						return true, push_action_input
					end
				end

				return func(self, defense_meta_data, scratchpad, in_melee_range, target_unit, target_breed, fixed_t)
			end
		)
	end
end

function M.install_bot_behavior_destination_hooks(BotBehaviorExtension)
	if not BotBehaviorExtension then
		return
	end

	if type(BotBehaviorExtension._refresh_destination) ~= "function" then
		return
	end

	_mod:hook(
		BotBehaviorExtension,
		"_refresh_destination",
		function(
			func,
			self,
			t,
			self_position,
			previous_destination,
			hold_position,
			hold_position_max_distance_sq,
			bot_group_data,
			navigation_extension,
			follow_component,
			perception_component
		)
			if type(func) ~= "function" then
				return nil
			end

			local unit = self and self._unit

			if not feature_enabled() or not is_custom_bot(unit) then
				return func(
					self,
					t,
					self_position,
					previous_destination,
					hold_position,
					hold_position_max_distance_sq,
					bot_group_data,
					navigation_extension,
					follow_component,
					perception_component
				)
			end

			local blackboard = BLACKBOARDS and BLACKBOARDS[unit]
			local behavior = blackboard and blackboard.behavior
			local pickup = blackboard and blackboard.pickup
			local state = M.autonomy_state(unit)
			local autonomy_position = state.position and t < (state.until_t or -math.huge) and plain_vector(state.position) or nil
			local scout_position = autonomy_position

			if not scout_position then
				scout_position = choose_scout_position(unit, bot_group_data, perception_component, behavior, pickup, t or now())
			end

			if not scout_position then
				return func(
					self,
					t,
					self_position,
					previous_destination,
					hold_position,
					hold_position_max_distance_sq,
					bot_group_data,
					navigation_extension,
					follow_component,
					perception_component
				)
			end

			local original_follow_position = bot_group_data.follow_position
			bot_group_data.follow_position = scout_position

			local ok, result = pcall(
				func,
				self,
				t,
				self_position,
				previous_destination,
				hold_position,
				hold_position_max_distance_sq,
				bot_group_data,
				navigation_extension,
				follow_component,
				perception_component
			)

			bot_group_data.follow_position = original_follow_position

			if not ok then
				error(result, 0)
			end

			return result
		end
	)
end

function M.debug_lines()
	local keys = {
		"update_called",
		"update_skipped",
		"update_custom",
		"movement_target_called",
		"movement_target_skipped",
		"movement_target_custom",
		"movement_target_active",
		"scout_pick",
		"force_called",
		"force_active",
		"force_move_to_ok",
		"force_move_to_fail",
		"force_no_nav",
		"force_blocked",
		"force_leash",
		"force_reached",
		"move_input_called",
		"move_input_skipped",
		"move_input_custom",
		"move_input_no_destination",
		"move_input_vector_ok",
		"post_input_called",
		"post_input_skipped",
		"post_input_custom",
		"post_input_move_override",
		"post_input_sprint_true",
		"post_input_dodge",
		"get_move_override",
		"get_hold_to_sprint",
		"get_sprinting_true",
		"get_crouching_true",
		"sprint_check",
		"sprint_true",
		"sprint_false",
		"target_seed",
		"grenade_decision",
		"grenade_no_decision",
		"grenade_sequence",
		"utility_decision",
		"utility_no_decision",
		"utility_queued",
		"ability_queue_ok",
		"ability_queue_fail",
		"ability_queue_missing",
		"ability_queue_missing_parser",
		"weapon_queue_ok",
		"weapon_queue_fail",
		"weapon_queue_missing",
		"weapon_special_queued",
		"weapon_special_no_input",
	}
	local lines = {}

	for i = 1, #keys do
		local key = keys[i]
		lines[#lines + 1] = string.format("%s=%s", key, tostring(_debug[key] or 0))
	end

	return lines
end

function M.reset_debug()
	_debug = {}
end

function M.init(deps)
	deps = deps or {}
	_mod = deps.mod
	_is_enabled = deps.is_enabled
	_fixed_time = deps.fixed_time
	M._behavior_learning = deps.behavior_learning
	_warned = {}
	_last_sprint_state_by_unit = setmetatable({}, { __mode = "k" })
	_last_item_tag_by_unit = setmetatable({}, { __mode = "k" })
	_last_enemy_tag_by_unit = setmetatable({}, { __mode = "k" })
	_last_dodge_by_unit = setmetatable({}, { __mode = "k" })
	_last_chest_scan_by_unit = setmetatable({}, { __mode = "k" })
	_last_chest_order_by_unit = setmetatable({}, { __mode = "k" })
	_last_pickup_scan_by_unit = setmetatable({}, { __mode = "k" })
	_last_target_seed_by_unit = setmetatable({}, { __mode = "k" })
	_last_scout_refresh_by_unit = setmetatable({}, { __mode = "k" })
	_autonomy_state_by_unit = setmetatable({}, { __mode = "k" })
	_scout_state_by_unit = setmetatable({}, { __mode = "k" })
	_movement_flair_by_unit = setmetatable({}, { __mode = "k" })
	_stimm_state_by_unit = setmetatable({}, { __mode = "k" })
	_ability_state_by_unit = setmetatable({}, { __mode = "k" })
	_team_ability_use_t = {}
	_debug = {}
	_last_pickup_patch_t = -math.huge
	patch_supported_pickups(now())
end

return M
