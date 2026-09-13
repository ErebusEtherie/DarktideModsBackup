-- Character-specific behavior memory for Custom Character Bots.
-- This is deliberately lightweight: learn tendencies as stable weights, then
-- let the bot behavior layer bias its existing choices with those weights.

local M = {}

local _mod
local _fixed_time
local _profile_id
local _is_enabled
local _learning
local _last_sample_t = -math.huge
local _last_save_t = -math.huge
local _last_unit
local _last_position
local _last_position_t
local _last_motion_by_unit = setmetatable({}, { __mode = "k" })
local _Health
local _warned = {}

local SAMPLE_INTERVAL = 0.35
local SAVE_INTERVAL = 30
local SAVE_PATH = "./../mods/CustomCharacterBots/behavior_learning.json"

local function now()
	if _fixed_time then
		return _fixed_time()
	end

	return Managers and Managers.time and Managers.time:time("gameplay") or os.clock()
end

local function enabled()
	if _is_enabled then
		local ok, result = pcall(_is_enabled)

		return ok and result == true
	end

	return _mod and _mod:get("enable_behavior_learning") == true
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

local function clamp(value, min_value, max_value)
	value = tonumber(value) or min_value

	if value < min_value then
		return min_value
	end

	if value > max_value then
		return max_value
	end

	return value
end

local function file_io()
	return Mods and Mods.lua and Mods.lua.io
end

local function json()
	return rawget(_G, "cjson")
end

local function load_health()
	if _Health then
		return _Health
	end

	local ok, Health = pcall(require, "scripts/utilities/health")

	if ok then
		_Health = Health
	end

	return _Health
end

local function load_disk_data()
	local io = file_io()
	local cjson = json()

	if not (io and cjson and cjson.decode) then
		return nil
	end

	local file = io.open(SAVE_PATH, "r")

	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	if not content or content == "" then
		return nil
	end

	local ok, decoded = pcall(cjson.decode, content)

	if ok and type(decoded) == "table" then
		return decoded
	end

	warn_once("load", "Custom Character Bots: behavior learning save could not be read.")

	return nil
end

local function save_disk_data(force)
	local t = now()

	if not force and t - _last_save_t < SAVE_INTERVAL then
		return
	end

	local io = file_io()
	local cjson = json()

	if not (io and cjson and cjson.encode) then
		warn_once("save_api", "Custom Character Bots: behavior learning disk save is unavailable in this session.")

		return
	end

	local ok, encoded = pcall(cjson.encode, _learning)

	if not ok or not encoded then
		warn_once("encode", "Custom Character Bots: behavior learning data could not be encoded.")

		return
	end

	local file = io.open(SAVE_PATH, "w+")

	if not file then
		warn_once("open", "Custom Character Bots: behavior learning save file could not be opened.")

		return
	end

	file:write(encoded)
	file:close()

	_last_save_t = t
end

local function local_player()
	local player_manager = Managers and Managers.player

	if not player_manager then
		return nil
	end

	if player_manager.local_player_safe then
		local ok, player = pcall(player_manager.local_player_safe, player_manager, 1)

		if ok then
			return player
		end
	end

	if player_manager.local_player then
		local ok, player = pcall(player_manager.local_player, player_manager, 1)

		if ok then
			return player
		end
	end

	return nil
end

local function player_profile(player)
	if not player then
		return nil
	end

	if player.profile then
		local ok, profile = pcall(player.profile, player)

		if ok then
			return profile
		end
	end

	return player._profile
end

local function character_id(profile)
	if _profile_id then
		local ok, id = pcall(_profile_id, profile)

		if ok and id and id ~= "<missing-id>" then
			return tostring(id)
		end
	end

	return profile and tostring(profile.character_id or profile.id or profile.name or "<missing-id>") or nil
end

local function player_unit(player)
	if not player then
		return nil
	end

	if player.player_unit then
		return player.player_unit
	end

	if player.unit then
		local ok, unit = pcall(player.unit, player)

		if ok then
			return unit
		end
	end

	return nil
end

local function unit_data(unit)
	local unit_data_extension = ScriptUnit and ScriptUnit.has_extension and ScriptUnit.has_extension(unit, "unit_data_system")

	if not unit_data_extension or not unit_data_extension.read_component then
		return nil
	end

	return unit_data_extension
end

local function read_component(unit, component_name)
	local unit_data_extension = unit_data(unit)

	if not unit_data_extension then
		return nil
	end

	local ok, component = pcall(unit_data_extension.read_component, unit_data_extension, component_name)

	return ok and component or nil
end

local function slot_kind(unit)
	local unit_data_extension = unit_data(unit)

	if not unit_data_extension then
		return nil
	end

	local ok, inventory = pcall(unit_data_extension.read_component, unit_data_extension, "inventory")

	if not ok or not inventory then
		return nil
	end

	local slot = inventory.wielded_slot

	if slot == "slot_primary" then
		return "melee"
	elseif slot == "slot_secondary" then
		return "ranged"
	elseif slot == "slot_grenade_ability" then
		return "grenade"
	elseif slot == "slot_combat_ability" then
		return "ability"
	end

	return slot
end

local function health_ratio(unit)
	local Health = load_health()

	if Health and Health.current_health_percent then
		local ok, ratio = pcall(Health.current_health_percent, unit)

		if ok and ratio then
			return clamp(ratio, 0, 1)
		end
	end

	local health_extension = ScriptUnit and ScriptUnit.has_extension and ScriptUnit.has_extension(unit, "health_system")

	if health_extension and health_extension.current_health_percent then
		local ok, ratio = pcall(health_extension.current_health_percent, health_extension)

		if ok and ratio then
			return clamp(ratio, 0, 1)
		end
	end

	return nil
end

local function movement_snapshot(unit)
	local movement_state = read_component(unit, "movement_state")
	local sprint_state = read_component(unit, "sprint_character_state")
	local character_state = read_component(unit, "character_state")
	local locomotion = read_component(unit, "locomotion")
	local method = movement_state and movement_state.method or character_state and character_state.state_name or "unknown"
	local speed = 0

	if locomotion and locomotion.velocity_current then
		local ok, value = pcall(function()
			return Vector3.length(Vector3.flat(locomotion.velocity_current))
		end)

		if ok and value then
			speed = value
		end
	end

	return {
		method = method,
		state = character_state and character_state.state_name or "unknown",
		crouching = movement_state and movement_state.is_crouching == true,
		dodging = movement_state and movement_state.is_dodging == true or method == "dodging",
		sprinting = sprint_state and (sprint_state.is_sprinting == true or sprint_state.is_sprint_jumping == true),
		speed = speed,
	}
end

local function update_average(current, count, value)
	if not value then
		return current
	end

	return ((current or value) * math.max(count - 1, 0) + value) / math.max(count, 1)
end

local function increment(map, key, amount)
	if not key then
		return
	end

	map[key] = (map[key] or 0) + (amount or 1)
end

local function action_bucket(id, action_name, action_settings)
	local action_kind = action_settings and action_settings.kind or ""
	local name = tostring(action_name or "")

	if id == "combat_ability_action" then
		return "combat_ability"
	elseif id == "grenade_ability_action" then
		return "grenade_blitz"
	elseif id == "pocketable_ability_action" then
		return "pocketable"
	elseif string.find(name, "heavy", 1, true) or string.find(action_kind, "heavy", 1, true) then
		return "heavy_attack"
	elseif string.find(name, "light", 1, true) or string.find(action_kind, "light", 1, true) then
		return "light_attack"
	elseif string.find(name, "special", 1, true) or string.find(action_kind, "special", 1, true) then
		return "weapon_special"
	elseif string.find(name, "shoot", 1, true) or string.find(action_kind, "shoot", 1, true) or string.find(action_kind, "ranged", 1, true) then
		return "ranged_attack"
	elseif string.find(name, "push", 1, true) or string.find(action_kind, "push", 1, true) then
		return "push"
	elseif string.find(name, "wield", 1, true) then
		return "wield"
	end

	return id == "weapon_action" and "weapon_action" or tostring(id or "unknown")
end

local function learned_profile(id, profile)
	_learning.profiles = _learning.profiles or {}

	local entry = _learning.profiles[id]

	if not entry then
		entry = {
			id = id,
			name = profile and profile.name or id,
			samples = 0,
			slot_time = {},
			action_counts = {},
			action_kind_counts = {},
			action_bucket_counts = {},
			weapon_action_counts = {},
			ability_action_counts = {},
			used_input_counts = {},
			movement_time = {},
			movement_counts = {},
			avg_combat_speed = 0,
			avg_speed = 0,
			avg_health = 1,
			min_health = 1,
			updated_at = 0,
		}
		_learning.profiles[id] = entry
	end

	entry.slot_time = entry.slot_time or {}
	entry.action_counts = entry.action_counts or {}
	entry.action_kind_counts = entry.action_kind_counts or {}
	entry.action_bucket_counts = entry.action_bucket_counts or {}
	entry.weapon_action_counts = entry.weapon_action_counts or {}
	entry.ability_action_counts = entry.ability_action_counts or {}
	entry.used_input_counts = entry.used_input_counts or {}
	entry.movement_time = entry.movement_time or {}
	entry.movement_counts = entry.movement_counts or {}
	entry.min_health = entry.min_health or 1

	if profile and profile.name then
		entry.name = profile.name
	end

	return entry
end

function M.observe_action_input(unit, id, action_input, _raw_input)
	if not enabled() or not unit or not action_input then
		return
	end

	local player_manager = Managers and Managers.player
	local player = player_manager and player_manager.player_by_unit and player_manager:player_by_unit(unit)

	if not (player and player.is_human_controlled and player:is_human_controlled()) then
		return
	end

	local profile = player_profile(player)
	local id_value = character_id(profile)

	if not id_value then
		return
	end

	local entry = learned_profile(id_value, profile)
	local key = tostring(id or "unknown") .. ":" .. tostring(action_input)

	increment(entry.action_counts, key)
	increment(entry.used_input_counts, tostring(action_input))
	entry.updated_at = now()
	save_disk_data(false)
end

function M.observe_started_action(unit, id, action_name, action_settings, used_input, t)
	if not enabled() or not unit or not action_name then
		return
	end

	local player_manager = Managers and Managers.player
	local player = player_manager and player_manager.player_by_unit and player_manager:player_by_unit(unit)

	if not (player and player.is_human_controlled and player:is_human_controlled()) then
		return
	end

	local profile = player_profile(player)
	local id_value = character_id(profile)

	if not id_value then
		return
	end

	local entry = learned_profile(id_value, profile)
	local bucket = action_bucket(id, action_name, action_settings)
	local action_kind = action_settings and action_settings.kind or "unknown"

	increment(entry.action_counts, tostring(id or "unknown") .. ":" .. tostring(action_name))
	increment(entry.action_kind_counts, tostring(action_kind))
	increment(entry.action_bucket_counts, bucket)

	if id == "weapon_action" then
		increment(entry.weapon_action_counts, tostring(action_name))
	else
		increment(entry.ability_action_counts, tostring(id or "unknown") .. ":" .. tostring(action_name))
	end

	if used_input then
		increment(entry.used_input_counts, tostring(used_input))
	end

	entry.updated_at = t or now()
	save_disk_data(false)
end

function M.update()
	if not enabled() then
		return
	end

	local t = now()

	if t - _last_sample_t < SAMPLE_INTERVAL then
		return
	end

	_last_sample_t = t

	local player = local_player()
	local unit = player_unit(player)

	if not unit or not (HEALTH_ALIVE and HEALTH_ALIVE[unit]) then
		return
	end

	if player.is_human_controlled and not player:is_human_controlled() then
		return
	end

	local profile = player_profile(player)
	local id = character_id(profile)

	if not id then
		return
	end

	local entry = learned_profile(id, profile)
	local samples = (entry.samples or 0) + 1
	local slot = slot_kind(unit)
	local movement = movement_snapshot(unit)

	entry.samples = samples
	entry.updated_at = t

	if slot and slot ~= "slot_unarmed" and slot ~= "none" then
		entry.slot_time[slot] = (entry.slot_time[slot] or 0) + SAMPLE_INTERVAL
	end

	local hp = health_ratio(unit)
	entry.avg_health = update_average(entry.avg_health or hp or 1, samples, hp)
	entry.min_health = hp and math.min(entry.min_health or 1, hp) or entry.min_health

	if movement.method then
		increment(entry.movement_time, movement.method, SAMPLE_INTERVAL)
	end

	if movement.sprinting then
		increment(entry.movement_time, "sprinting", SAMPLE_INTERVAL)
	end

	if movement.crouching then
		increment(entry.movement_time, "crouching", SAMPLE_INTERVAL)
	end

	if movement.speed and movement.speed > 0.5 then
		entry.avg_combat_speed = update_average(entry.avg_combat_speed or 0, samples, movement.speed)
	end

	local motion_state = _last_motion_by_unit[unit] or {}

	if movement.dodging and not motion_state.dodging then
		increment(entry.movement_counts, "dodge")
	end

	if movement.sprinting and not motion_state.sprinting then
		increment(entry.movement_counts, "sprint_start")
	end

	if movement.crouching and not motion_state.crouching then
		increment(entry.movement_counts, "crouch_start")
	end

	if movement.state and movement.state ~= motion_state.state then
		increment(entry.movement_counts, "state:" .. tostring(movement.state))
	end

	motion_state.dodging = movement.dodging
	motion_state.sprinting = movement.sprinting
	motion_state.crouching = movement.crouching
	motion_state.state = movement.state
	_last_motion_by_unit[unit] = motion_state

	local position = POSITION_LOOKUP and POSITION_LOOKUP[unit]

	if unit ~= _last_unit then
		_last_position = nil
		_last_position_t = nil
		_last_unit = unit
	end

	if position and _last_position and _last_position_t and t > _last_position_t then
		local ok, distance = pcall(Vector3.distance, position, _last_position)

		if ok and distance then
			entry.avg_speed = update_average(entry.avg_speed or 0, samples, distance / math.max(t - _last_position_t, 0.1))
		end
	end

	if position then
		local ok_copy, position_copy = pcall(function()
			return Vector3(position.x, position.y, position.z)
		end)

		_last_position = ok_copy and position_copy or position
	else
		_last_position = nil
	end

	_last_position_t = t

	save_disk_data(false)
end

function M.policy_for_profile(profile)
	if not enabled() or not profile then
		return nil
	end

	local id = character_id(profile)
	local entry = id and _learning and _learning.profiles and _learning.profiles[id]

	if not entry or (entry.samples or 0) < 20 then
		return nil
	end

	local slot_time = entry.slot_time or {}
	local melee_time = slot_time.melee or 0
	local ranged_time = slot_time.ranged or 0
	local combat_time = math.max(melee_time + ranged_time, 1)
	local ranged_ratio = ranged_time / combat_time
	local aggression = clamp((entry.avg_speed or 0) / 5, 0, 1)
	local cautious = clamp(1 - math.min(entry.avg_health or 1, entry.min_health or 1), 0, 1)
	local action_counts = entry.action_counts or {}
	local buckets = entry.action_bucket_counts or {}
	local ability_uses = buckets.combat_ability or 0
	local grenade_uses = buckets.grenade_blitz or 0
	local dodge_count = (entry.movement_counts and entry.movement_counts.dodge) or 0

	if ability_uses == 0 then
		ability_uses = (action_counts["combat_ability_action:pressed"] or 0)
			+ (action_counts["combat_ability_action:action_pressed"] or 0)
	end

	if grenade_uses == 0 then
		grenade_uses = (action_counts["grenade_ability_action:pressed"] or 0)
			+ (action_counts["grenade_ability_action:action_pressed"] or 0)
	end

	return {
		ranged_preference = ranged_ratio,
		scout_min_distance = 22 + aggression * 10 + math.min(dodge_count, 10) * 0.4,
		scout_max_distance = 42 + aggression * 22 + math.min(dodge_count, 10) * 0.7,
		scout_max_leash = 68 + aggression * 22,
		pickup_search_range = 45 + aggression * 18,
		pickup_enemy_skip = aggression > 0.6 and 4 or 2,
		ammo_search_threshold = ranged_ratio > 0.55 and 0.72 or 0.88,
		medicae_health_threshold = 0.42 + cautious * 0.16,
		grenade_horde_count = grenade_uses > 4 and 2 or 3,
		utility_horde_count = ability_uses > 4 and 1 or 2,
	}
end

function M.status_lines()
	local lines = {}
	local profiles = _learning and _learning.profiles or {}

	for _, entry in pairs(profiles) do
		local slot_time = entry.slot_time or {}
		local melee_time = slot_time.melee or 0
		local ranged_time = slot_time.ranged or 0
		local total = math.max(melee_time + ranged_time, 1)
		local buckets = entry.action_bucket_counts or {}
		local movement_counts = entry.movement_counts or {}
		lines[#lines + 1] = string.format(
			"%s: %d samples, %.0f%% ranged, speed %.1f, hp %.0f%%, dodges %d, abilities %d, blitz %d, heavy %d",
			tostring(entry.name or entry.id),
			tonumber(entry.samples or 0),
			(ranged_time / total) * 100,
			tonumber(entry.avg_speed or 0),
			tonumber((entry.avg_health or 1) * 100),
			tonumber(movement_counts.dodge or 0),
			tonumber(buckets.combat_ability or 0),
			tonumber(buckets.grenade_blitz or 0),
			tonumber(buckets.heavy_attack or 0)
		)
	end

	return lines
end

function M.reset()
	_learning.profiles = {}
	save_disk_data(true)
end

function M.init(deps)
	deps = deps or {}
	_mod = deps.mod
	_fixed_time = deps.fixed_time
	_profile_id = deps.profile_id
	_is_enabled = deps.is_enabled
	_warned = {}
	_last_motion_by_unit = setmetatable({}, { __mode = "k" })
	_learning = _mod and _mod.persistent_table and _mod:persistent_table("behavior_learning", {
		version = 1,
		profiles = {},
	}) or {
		version = 1,
		profiles = {},
	}

	local disk = load_disk_data()

	if disk and type(disk.profiles) == "table" then
		_learning.version = disk.version or 1
		_learning.profiles = disk.profiles
	end
end

function M.on_unload()
	save_disk_data(true)
end

return M
