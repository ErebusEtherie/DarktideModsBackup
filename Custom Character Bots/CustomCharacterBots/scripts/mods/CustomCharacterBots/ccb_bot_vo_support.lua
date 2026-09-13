-- Lightweight squad VO and smart-tag support for substituted saved-character bots.

local M = {}

local _mod
local _is_enabled
local _fixed_time
local _Vo
local _Ammo
local _Health
local _VoQueryConstants
local _warned = {}

local _state_by_unit = setmetatable({}, { __mode = "k" })
local _last_tagged_by_unit = setmetatable({}, { __mode = "k" })

local AMMO_THRESHOLD = 0.2
local HEALTH_THRESHOLD = 0.35
local RESOURCE_COOLDOWN = 45
local THANK_YOU_COOLDOWN = 8
local TAG_COOLDOWN = 8
local TAG_FAILURE_BACKOFF = 2

local PERCEPTION_SLOTS = {
	"priority_target_enemy",
	"urgent_target_enemy",
	"opportunity_target_enemy",
	"target_enemy",
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

local function load_vo()
	if _Vo then
		return _Vo
	end

	local ok, Vo = pcall(require, "scripts/utilities/vo")

	if ok then
		_Vo = Vo
	else
		warn_once("vo", "Custom Character Bots: failed to load VO utility for bot voice lines.")
	end

	return _Vo
end

local function load_ammo()
	if _Ammo then
		return _Ammo
	end

	local ok, Ammo = pcall(require, "scripts/utilities/ammo")

	if ok then
		_Ammo = Ammo
	else
		warn_once("ammo", "Custom Character Bots: failed to load ammo utility for bot voice lines.")
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
		warn_once("health", "Custom Character Bots: failed to load health utility for bot voice lines.")
	end

	return _Health
end

local function load_vo_constants()
	if _VoQueryConstants then
		return _VoQueryConstants
	end

	local ok, VoQueryConstants = pcall(require, "scripts/settings/dialogue/vo_query_constants")

	if ok then
		_VoQueryConstants = VoQueryConstants
	else
		warn_once("vo_constants", "Custom Character Bots: failed to load VO constants for bot voice lines.")
	end

	return _VoQueryConstants
end

local function state(unit)
	local unit_state = _state_by_unit[unit]

	if unit_state then
		return unit_state
	end

	unit_state = {
		ammo_t = -math.huge,
		health_t = -math.huge,
		thanks_t = -math.huge,
		tag_t = -math.huge,
		tag_failure_t = -math.huge,
	}
	_state_by_unit[unit] = unit_state

	return unit_state
end

local function player_by_unit(unit)
	local player_manager = Managers and Managers.player

	return player_manager and player_manager.player_by_unit and player_manager:player_by_unit(unit) or nil
end

local function is_custom_bot(unit)
	if not unit then
		return false
	end

	local player = player_by_unit(unit)

	if not player or player:is_human_controlled() then
		return false
	end

	local profile = player.profile and player:profile()

	return profile and profile._ccb_resolved == true
end

local function trigger_com_wheel(unit, trigger_id)
	local Vo = load_vo()
	local constants = load_vo_constants()
	local concept = constants and constants.concepts and constants.concepts.on_demand_com_wheel

	if not Vo or not concept or not trigger_id then
		return false
	end

	local ok, err = pcall(Vo.on_demand_vo_event, unit, concept, trigger_id)

	if not ok then
		warn_once("vo_trigger", "Custom Character Bots: bot VO trigger failed: " .. tostring(err))
	end

	return ok
end

local function trigger_tag_vo(unit, target_unit, breed_name)
	local Vo = load_vo()
	local constants = load_vo_constants()
	local concept = constants and constants.concepts and constants.concepts.on_demand_vo_tag_enemy

	if not Vo or not concept or not breed_name then
		return false
	end

	local ok, err = pcall(Vo.on_demand_vo_event, unit, concept, breed_name, target_unit)

	if not ok then
		warn_once("tag_vo_trigger", "Custom Character Bots: bot tag VO trigger failed: " .. tostring(err))
	end

	return ok
end

local function target_breed(target_unit)
	local extension = target_unit and ScriptUnit.has_extension(target_unit, "unit_data_system")

	if not extension or not extension.breed then
		return nil
	end

	return extension:breed()
end

local function is_special_or_elite(target_unit)
	local breed = target_breed(target_unit)
	local tags = breed and breed.tags

	if not breed then
		return false
	end

	return breed.is_boss or (tags and (tags.special or tags.elite or tags.monster or tags.captain))
end

local function choose_tag_target(blackboard)
	local perception = blackboard and blackboard.perception

	if not perception then
		return nil
	end

	for i = 1, #PERCEPTION_SLOTS do
		local target_unit = perception[PERCEPTION_SLOTS[i]]

		if target_unit and Unit.alive(target_unit) and is_special_or_elite(target_unit) then
			return target_unit
		end
	end

	return nil
end

local function smart_tag_system()
	local extension_manager = Managers and Managers.state and Managers.state.extension

	if not extension_manager then
		return nil
	end

	local ok, system = pcall(extension_manager.system, extension_manager, "smart_tag_system")

	if ok then
		return system
	end

	return nil
end

local function target_already_tagged(target_unit)
	local extension = target_unit and ScriptUnit.has_extension(target_unit, "smart_tag_system")

	return extension and extension:tag_id() ~= nil
end

local function update_resource_vo(unit, unit_state, t)
	local constants = load_vo_constants()
	local trigger_ids = constants and constants.trigger_ids

	if not trigger_ids then
		return
	end

	local Ammo = load_ammo()

	if Ammo and Ammo.uses_ammo and Ammo.current_total_percentage then
		local ok_uses, uses_ammo = pcall(Ammo.uses_ammo, unit)
		local ok_pct, ammo_pct = false, nil

		if ok_uses and uses_ammo then
			ok_pct, ammo_pct = pcall(Ammo.current_total_percentage, unit)
		end

		if ok_pct and type(ammo_pct) == "number" and ammo_pct <= AMMO_THRESHOLD and t - unit_state.ammo_t >= RESOURCE_COOLDOWN then
			if trigger_com_wheel(unit, trigger_ids.com_wheel_vo_need_ammo) then
				unit_state.ammo_t = t
			end
		end
	end

	local Health = load_health()

	if Health and Health.current_health_percent then
		local ok_health, health_pct = pcall(Health.current_health_percent, unit)

		if ok_health and type(health_pct) == "number" and health_pct <= HEALTH_THRESHOLD and t - unit_state.health_t >= RESOURCE_COOLDOWN then
			if trigger_com_wheel(unit, trigger_ids.com_wheel_vo_need_health) then
				unit_state.health_t = t
			end
		end
	end
end

local function update_tagging(unit, blackboard, unit_state, t)
	if t - unit_state.tag_t < TAG_COOLDOWN or t - unit_state.tag_failure_t < TAG_FAILURE_BACKOFF then
		return
	end

	local target_unit = choose_tag_target(blackboard)

	if not target_unit then
		return
	end

	local last_tag = _last_tagged_by_unit[unit]

	if last_tag and last_tag.target == target_unit and Unit.alive(target_unit) and target_already_tagged(target_unit) then
		return
	end

	if target_already_tagged(target_unit) then
		return
	end

	local system = smart_tag_system()

	if not system then
		return
	end

	local ok, err = pcall(system.set_contextual_unit_tag, system, unit, target_unit)

	if not ok then
		unit_state.tag_failure_t = t
		warn_once("smart_tag", "Custom Character Bots: bot smart-tag failed: " .. tostring(err))

		return
	end

	local breed = target_breed(target_unit)
	local breed_name = breed and breed.name

	trigger_tag_vo(unit, target_unit, breed_name)

	_last_tagged_by_unit[unit] = {
		target = target_unit,
	}
	unit_state.tag_t = t

	if _mod and _mod:get("detailed_logging") then
		_mod:info("Custom Character Bots: bot tagged %s.", tostring(breed_name or target_unit))
	end
end

function M.update_bot(unit, blackboard)
	if not feature_enabled() or not is_custom_bot(unit) or not HEALTH_ALIVE[unit] then
		return
	end

	local t = now()
	local unit_state = state(unit)

	update_resource_vo(unit, unit_state, t)
	update_tagging(unit, blackboard, unit_state, t)
end

function M.on_revived(interactor_unit, revived_unit)
	if not feature_enabled() or not is_custom_bot(revived_unit) then
		return
	end

	local t = now()
	local unit_state = state(revived_unit)

	if t - unit_state.thanks_t < THANK_YOU_COOLDOWN then
		return
	end

	local constants = load_vo_constants()
	local trigger_ids = constants and constants.trigger_ids

	if trigger_ids and trigger_com_wheel(revived_unit, trigger_ids.com_wheel_vo_thank_you) then
		unit_state.thanks_t = t

		if _mod and _mod:get("detailed_logging") then
			_mod:info("Custom Character Bots: bot thanked reviver %s.", tostring(interactor_unit))
		end
	end
end

function M.on_stimmed(stimmer_unit, stimmed_unit, notification_type)
	if stimmer_unit == stimmed_unit or not feature_enabled() or not is_custom_bot(stimmed_unit) then
		return
	end

	if notification_type ~= "stimmed" and notification_type ~= "cleansed" then
		return
	end

	local t = now()
	local unit_state = state(stimmed_unit)

	if t - unit_state.thanks_t < THANK_YOU_COOLDOWN then
		return
	end

	local constants = load_vo_constants()
	local trigger_ids = constants and constants.trigger_ids

	if trigger_ids and trigger_com_wheel(stimmed_unit, trigger_ids.com_wheel_vo_thank_you) then
		unit_state.thanks_t = t

		if _mod and _mod:get("detailed_logging") then
			_mod:info("Custom Character Bots: bot thanked stimmer %s.", tostring(stimmer_unit))
		end
	end
end

function M.init(deps)
	deps = deps or {}
	_mod = deps.mod
	_is_enabled = deps.is_enabled
	_fixed_time = deps.fixed_time
	_warned = {}
	_state_by_unit = setmetatable({}, { __mode = "k" })
	_last_tagged_by_unit = setmetatable({}, { __mode = "k" })
end

return M
