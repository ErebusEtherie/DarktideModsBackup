local mod = get_mod("AutoBlitz")
local ProfileUtils = require("scripts/utilities/profile_utils")

-- Settings
local grenades = {
	box     = { enabled = false, minimum = 1, throw_type = "overhand" },
	rock    = { enabled = false, minimum = 1, throw_type = "overhand" },
	nuke    = { enabled = false, minimum = 1, throw_type = "overhand" },
	frag    = { enabled = false, minimum = 1, throw_type = "overhand" },
	krak    = { enabled = false, minimum = 1, throw_type = "overhand" },
	smoke   = { enabled = false, minimum = 1, throw_type = "overhand" },
	flame   = { enabled = false, minimum = 1, throw_type = "overhand" },
	shock   = { enabled = false, minimum = 1, throw_type = "overhand" },
	mine    = { enabled = false, minimum = 1, throw_type = "overhand" },
	arbites = { enabled = false, minimum = 1, throw_type = "overhand" },
	dogsplosion = { 
		enabled = true, 
		minimum = 1, 
		use_threshold = false,
		enemy_threshold = 99, 
		elite_threshold = 0,
		special_threshold = 0,
		boss_threshold = 0,
		pounce_only = false, 
		enemy_types = "any", 
		allow_daemonhost = false, 
		require_tag = false,
		cooldown = 5
	},
	flask = { enabled = false, minimum = 1, throw_type = "overhand" },
	launcher = { enabled = false, minimum = 1, throw_type = "overhand" },
	arc = { enabled = false, minimum = 1, throw_type = "overhand" },
	skull = { enabled = false },
	medic = { enabled = false, minimum = 1, help_downed = false, help_hogtied = false, help_netted = false },
	shield = { enabled = false, minimum = 1, shield_threshold = 0, shield_type = "current_health" },
}

local BUFFER = {
	attacks = 0, -- Number of attacks in the buffer
	delta = 0, -- Time since last attack
	last = 0, -- Time of last attack
	health = 0, -- Total health damage from buffer
	toughness = 0, -- Total toughness damage from buffer
	max = 0 -- Highest single damage taken in buffer
}


-- Grenade Map
local gmap = {
	ogryn_grenade_box_cluster = "box",
	ogryn_grenade_box = "box",
	ogryn_grenade_friend_rock = "rock",
	ogryn_grenade_frag = "nuke",
	frag_grenade = "frag",
	krak_grenade = "krak",
	smoke_grenade = "smoke",
	fire_grenade = "flame",
	shock_grenade = "shock",
	shock_mine = "mine",
	adamant_grenade = "arbites",
	adamant_whistle = "dogsplosion",
	tox_grenade = "flask",
	missile_launcher = "launcher",
	arc_grenade = "arc",
}

-- Interruptions
local trying_to_throw_primary = false
local trying_to_throw_secondary = false
local interrupt = {
	quick_wield = true,
	wield_scroll_down = true,
	wield_scroll_up = true,
	wield_1 = true,
	wield_2 = true,
	wield_3 = true,
	wield_3_gamepad = true,
	wield_4 = true,
	wield_5 = true,
	combat_ability_pressed = true,
	action_one_hold = true,
}

-- Shared Locals
local allow_override = true
local cancel = false
local current_nade = "none"
local ready_to_throw = false
local aiming = false
local thrown = false

local KEYBIND = {
	using_keybind = false,
	throw_keybind_pressed = false,
}

local DOG = {
	ELIGIBLE = false,
	TAG = false,
	UNIT = nil,
	POUNCING = false,
	LAST_EXPLOSION = 0,
}

AWAKE_DAEMONHOSTS = {}

-- Debug
local debug = nil

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       DMF FUNCTIONS        │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Settings handler
mod.on_setting_changed = function(id)
	if id == "allow_override" then
		allow_override = mod:get("allow_override")
	elseif id == "auto_throw_keybind" then
		local keybind = mod:get("auto_throw_keybind")
		if keybind[1] ~= nil then
			KEYBIND.using_keybind = true
		end
	else
		local grenade, setting = string.match(id, "(.-)_(.*)")
		if grenades[grenade] ~= nil then
			grenades[grenade][setting] = mod:get(id)
		end
	end
end

-- Load handler
mod.on_all_mods_loaded = function()
	local archetype = mod.check_archetype()
	DOG.ELIGIBLE = archetype and (archetype == "adamant" or archetype == "cryptic") or false
	allow_override = mod:get("allow_override")
	local keybind = mod:get("auto_throw_keybind")
	if keybind[1] ~= nil then
		KEYBIND.using_keybind = true
	end
	for k, v in pairs(grenades) do
		grenades[k].enabled = mod:get(k .. "_enabled")
		grenades[k].minimum = mod:get(k .. "_minimum")
		grenades[k].throw_type = mod:get(k .. "_throw_type") or "overhand"
	end
	-- Dogsplosion
	grenades.dogsplosion.use_threshold = mod:get("dogsplosion_use_threshold")
	grenades.dogsplosion.enemy_threshold = mod:get("dogsplosion_enemy_threshold")
	grenades.dogsplosion.enemy_threshold = mod:get("dogsplosion_enemy_threshold")
	grenades.dogsplosion.elite_threshold = mod:get("dogsplosion_elite_threshold")
	grenades.dogsplosion.special_threshold = mod:get("dogsplosion_special_threshold")
	grenades.dogsplosion.boss_threshold = mod:get("dogsplosion_boss_threshold")
	grenades.dogsplosion.pounce_only = mod:get("dogsplosion_pounce_only")
	grenades.dogsplosion.allow_daemonhost = mod:get("dogsplosion_allow_daemonhost")
	grenades.dogsplosion.require_tag = mod:get("dogsplosion_require_tag")
	grenades.dogsplosion.cooldown = mod:get("dogsplosion_cooldown")
	-- Skull (Base)
	grenades.skull.enabled = mod:get("base_skull_enabled")
	-- Skull (Medic)
	grenades.medic.help_downed = mod:get("medic_help_downed")
	grenades.medic.help_hogtied = mod:get("medic_help_hogtied")
	grenades.medic.help_netted = mod:get("medic_help_netted")
	-- Shield
	grenades.shield.shield_threshold = mod:get("shield_threshold")
	grenades.shield.shield_type = mod:get("shield_type")
	mod.clear_buffer()
end

mod.on_game_state_changed = function()
	local archetype = mod.check_archetype()
	DOG.ELIGIBLE = archetype and (archetype == "adamant" or archetype == "cryptic") or false
	DOG.UNIT = nil
	mod.clear_buffer()
end

mod.update = function()
	-- Reset dog upon despawn
	if DOG.UNIT then
		if not Unit.alive(DOG.UNIT) then
			DOG.UNIT = nil
		end
	end
	-- Only try to fetch the dog for arbitrators
	-- This will still mean fetch_dog() is running every frame for Lone Wolf users, which is pretty bad but should be negligible performance-wise
	-- Everyone else should only have it run for <1sec max
	if DOG.UNIT == nil and DOG.ELIGIBLE then
		DOG.UNIT = mod.fetch_dog()
	end
	mod.update_buffer()
end

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │      CUSTOM FUNCTIONS      │ --
-- │                            │ --
-- └────────────────────────────┘ --

mod.update_buffer = function()
	if BUFFER.attacks == 0 then return end
	local limit = 2
	local time = Managers.time:time("gameplay")
	BUFFER.delta = time - BUFFER.last
	if BUFFER.delta > limit then
		BUFFER.attacks = 0
		BUFFER.health = 0
		BUFFER.toughness = 0
		BUFFER.max = 0
	end
end

mod.clear_buffer = function()
	BUFFER.last = 0
	BUFFER.delta = 0
	BUFFER.attacks = 0
	BUFFER.health = 0
	BUFFER.toughness = 0
	BUFFER.max = 0
end

-- Tells the mod that the throw keybind has been pressed (and in turn should throw a grenade)
mod.throw_grenade = function()
	-- Exit if already queued up or wielding a grenade
	if KEYBIND.throw_keybind_pressed or mod.wielding_grenade_slot() then return end
	-- Do not queue up a throw when in menus or out of grenades
	if not Managers.ui:using_input() and mod.has_grenades() then
		KEYBIND.throw_keybind_pressed = true
	end
end

-- Returns the player archetype, or nil if the player has not spawned
mod.check_archetype = function()
	local archetype
    local player = Managers.player:local_player_safe(1)
    if player then
        local profile = player:profile()
        if profile then
            archetype = profile.archetype and profile.archetype.name
        end
    end
    return archetype
end

mod.quick_throw = function()
	local archetype = mod.check_archetype()
	if archetype == "zealot" then
		local grenade = mod.check_grenade()
		if grenade and grenade == "zealot_throwing_knives" then
			return true
		end
	end
	if archetype == "broker" then
		local grenade = mod.check_grenade()
		if grenade and grenade == "quick_flash_grenade" then
			return true
		end
	end
	if archetype == "cryptic" then
		local grenade = mod.check_grenade()
		if not grenade or grenade ~= "arc_grenade" then
			return true
		end
	end
	return false
end

mod.check_grenade = function()
	local player = Managers and Managers.player and Managers.player:local_player_safe(1)
    if not player then return nil end
    local player_unit = player and player.player_unit
    local weapon_extension = player_unit and ScriptUnit.has_extension(player_unit, "weapon_system")
    local weapons = weapon_extension and weapon_extension._weapons
    local weapon = weapons and weapons.slot_grenade_ability
    local weapon_template = weapon and weapon.weapon_template
    local name = weapon_template and weapon_template.name
    return name
end

-- Check if the player is using a weapon this mod should care about - returns true if a valid grenade is currently wielded
mod.check_weapon = function()
	local manager = Managers.player
	-- If we have a player unit
	if manager and manager:local_player_safe(1) then
		local unit = manager:local_player(1).player_unit
		-- And that unit has a weapon system
		if unit and ScriptUnit.has_extension(unit, "weapon_system") then			
			local weapon = ScriptUnit.extension(unit, "weapon_system")
			local inventory = weapon._inventory_component
			local wielded_weapon = weapon:_wielded_weapon(inventory, weapon._weapons)
			-- And that system is wielding a weapon
			if wielded_weapon then
				local weapon_template = wielded_weapon and wielded_weapon.weapon_template
				-- And that weapon is a grenade
				if weapon_template.name and gmap[weapon_template.name] ~= nil then
					current_nade = gmap[weapon_template.name]
					return true
				end
			end
		end
	end
	current_nade = "none"
	return false
end

-- Returns true if currently wielding a grenade, regardless of kind
mod.wielding_grenade_slot = function()
	local player = Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	local visual_loadout = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	local wielded_slot = visual_loadout and visual_loadout._inventory_component and visual_loadout._inventory_component.wielded_slot
	return wielded_slot and wielded_slot == "slot_grenade_ability"
end

-- Returns true if the player has the dogsplosion equipped
mod.check_dogsplosion = function()
	if not DOG.UNIT then return false end
	local player = Managers.player:local_player(1)
    local player_unit = player and player.player_unit
    local talent_extension = player_unit and ScriptUnit.extension(player_unit, "talent_system")
	if talent_extension and talent_extension:has_special_rule("adamant_whistle") then
		return true
	end
	return false
end

-- thank you to andrelizzz123 for getting a better method of finding the dog
mod.get_dog_from_spawner = function(player_unit)
	if not player_unit then return nil end
	local dog_spawner = player_unit and ScriptUnit.has_extension(player_unit, "companion_spawner_system")
	if not dog_spawner then return nil end
	-- I am just assuming this is efficient enough rather than messing with it
	if type(dog_spawner.companion_unit) == "function" then
		return dog_spawner:companion_unit()
	end
	if type(dog_spawner.companion_units) == "function" then
		local companions = dog_spawner:companion_units()
		if type(companions) == "table" then
			for _, companion in pairs(companions) do
				if companion and Unit.alive(companion) then
					return companion
				end
			end
		end
	end
	local companion = rawget(dog_spawner, "_companion_unit") or rawget(dog_spawner, "companion_unit")
	if companion and Unit.alive(companion) then
		return companion
	end
	local companions = rawget(dog_spawner, "_companion_units") or rawget(dog_spawner, "companion_units")
	if type(companions) == "table" then
		for _, unit in pairs(companions) do
			if unit and Unit.alive(unit) then
				return unit
			end
		end
	end
	return nil
end

-- Returns the player's dog unit if it exists, otherwise nil
mod.fetch_dog = function()
	local manager = Managers.player
	-- If we have a player unit
	if manager and manager:local_player_safe(1) then
		local player = manager:local_player_safe(1)
		local player_unit = player and player.player_unit
		local profile = player and player:profile()
		-- And that unit should have a dog
		local should_dog = profile and ProfileUtils.has_companion(profile)
		if should_dog then
			local dog = mod.get_dog_from_spawner(player_unit)
			-- And there is in fact a dog
			if dog then
				return dog
			end
		end
	end
end

mod.has_grenades = function()
	local player = Managers.player:local_player(1)
    local player_unit = player and player.player_unit
    local ability_system = player_unit and ScriptUnit.extension(player_unit, "ability_system")
	local charges = ability_system and ability_system:remaining_ability_charges("grenade_ability") or 0
	return charges > 0
end

-- Returns the number of enemies in range of the dog, as well as counts of elites, specialists, bosses, and whether a sleeping daemonhost is in range
mod.dog_radar = function(dog)
	if not dog then return 0, 0, 0, 0, false end
	local radius = 5 -- Max range for dogsplosion
	local radius_dh = 7 -- Max range for daemonhost check
	local results = {}
	local broadphase_system = Managers.state.extension:system("broadphase_system")
	local broadphase = broadphase_system.broadphase
	local side_system = Managers.state.extension:system("side_system")
	local side = side_system.side_by_unit[dog]
	local safe_to_check = Unit.alive(dog) and Unit.world(dog)
	local from_position
	if safe_to_check then
		from_position = Unit.world_position(dog, 1)
	end
	if broadphase and side and from_position then
		local enemy_side_names = side:relation_side_names("enemy")
		local enemies_in_radius = broadphase.query(broadphase, from_position, radius, results, enemy_side_names)
		local daemonhosts_in_range = broadphase.query(broadphase, from_position, radius_dh, results, enemy_side_names)
		local daemonhost_in_range = false
		local elites = 0
		local specialists = 0
		local bosses = 0
		for index = 1, enemies_in_radius do
			local enemy_unit = results[index]
			if enemy_unit and Unit.alive(enemy_unit) then
				local unit_data = ScriptUnit.has_extension(enemy_unit, "unit_data_system")
				local target_breed = unit_data and unit_data:breed()
				if target_breed.tags and target_breed.tags.elite then
					elites = elites + 1
				elseif target_breed.tags and target_breed.tags.special then
					specialists = specialists + 1
				elseif target_breed.tags and (target_breed.tags.captain or target_breed.tags.monster or target_breed.tags.cultist_captain) then
					bosses = bosses + 1
				end
			end
		end
		for index = 1, daemonhosts_in_range do
			local daemonhost_unit = results[index]
			if daemonhost_unit and Unit.alive(daemonhost_unit) then
				local unit_data = ScriptUnit.has_extension(daemonhost_unit, "unit_data_system")
				local target_breed = unit_data and unit_data:breed()
				if target_breed.tags and target_breed.tags.witch and not AWAKE_DAEMONHOSTS[daemonhost_unit] then
					daemonhost_in_range = true
					break
				end
			end
		end
		return enemies_in_radius or 0, elites, specialists, bosses, daemonhost_in_range
	end
	return 0, 0, 0, 0, false
end

-- Similar to dog radar, but only checks for daemonhosts and does not care about enemy counts
mod.daemon_radar = function(dog)
	local radius = 7 -- Max range for daemonhost check
	local results = {}
	local broadphase_system = Managers.state.extension:system("broadphase_system")
	local broadphase = broadphase_system.broadphase
	local side_system = Managers.state.extension:system("side_system")
	local side = side_system.side_by_unit[dog]
	local safe_to_check = Unit.alive(dog) and Unit.world(dog)
	local from_position
	if safe_to_check then
		from_position = Unit.world_position(dog, 1)
	end
	local daemonhost_in_range = false
	if broadphase and side and from_position then
		local enemy_side_names = side:relation_side_names("enemy")
		local enemies_in_radius = broadphase.query(broadphase, from_position, radius, results, enemy_side_names)
		for index = 1, enemies_in_radius do
			local daemonhost_unit = results[index]
			if daemonhost_unit and Unit.alive(daemonhost_unit) then
				local unit_data = ScriptUnit.has_extension(daemonhost_unit, "unit_data_system")
				local target_breed = unit_data and unit_data:breed()
				if target_breed.tags and target_breed.tags.witch and not AWAKE_DAEMONHOSTS[daemonhost_unit] then
					daemonhost_in_range = true
					break
				end
			end
		end
	end
	return daemonhost_in_range
end

mod.get_dogsplosion_charges = function()
	if not DOG.UNIT then return false end
	local player = Managers.player:local_player_safe(1)
    local player_unit = player and player.player_unit
    local ability_system = player_unit and ScriptUnit.extension(player_unit, "ability_system")
	local charges = ability_system and ability_system:remaining_ability_charges("grenade_ability") or 0
	return charges
end

mod.check_shield = function()
	local player_manager = Managers and Managers.player
	if player_manager then
		local player = player_manager:local_player_safe(1)
		local player_unit = player and player.player_unit
		local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
		if ability_extension and ability_extension._equipped_abilities.grenade_ability then
			blitz = ability_extension._equipped_abilities.grenade_ability.ability_template
			if blitz and blitz == "cryptic_force_field" then
				return true
			end
		end
	end
	return false
end

mod.panic = function()
	if not grenades.shield.enabled then return false end
	-- Ignore if downed/disabled
	local DISABLED_STATES = {
		catapulted = true,
		consumed = true,
		dead = true,
		grabbed = true,
		hogtied = true,
		knocked_down = true,
		ledge_hanging = true,
		mutant_charged = true,
		netted = true,
		pounced = true,
		vortex_grabbed = true,
		warp_grabbed = true,
	}
	local player = Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
	if character_state_component and DISABLED_STATES[character_state_component.state_name] then
		return false
	end

	local shield_type = grenades.shield.shield_type
	local threshold = grenades.shield.shield_threshold

	-- Damage check
	if threshold > 0 and shield_type == "damage_taken" then
		local total_damage = 0
		total_damage = BUFFER.health
		if total_damage >= threshold then
			return true
		end
	end

	local toughness = player_unit and ScriptUnit.has_extension(player_unit, "toughness_system")
	local current_toughness = toughness and toughness:current_toughness_percent_visual() * 100
	local shield_broken = (current_toughness and current_toughness == 0) and true or false
	local health = player_unit and ScriptUnit.has_extension(player_unit, "health_system")
	local current_health = health and health:current_health_percent() * 100
	local current_health_raw = health and health:current_health()

	-- Health check
	if threshold > 0 and shield_type == "current_health" then
		local health_below_threshold = (current_health and current_health <= threshold) and true or false
		local any_ranged_damage_taken = BUFFER.health + BUFFER.toughness
		if shield_broken and health_below_threshold and any_ranged_damage_taken then
			return true
		end
	end

	-- Emergency check
	if shield_broken and BUFFER.max > 0 and BUFFER.max > current_health_raw then
		return true
	end
	return false
end

-- Checks if the BASE skull ability is on cooldown. TRUE = ready to use / FALSE = on cooldown
mod.base_skull_ready = function()
	if not DOG.UNIT or not grenades.skull.enabled then return false end
	local player = Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	local talent_extension = player_unit and ScriptUnit.has_extension(player_unit, "talent_system")
	if not talent_extension then return false end
	local base_skull = talent_extension:has_special_rule("cryptic_servo_skull_hack") and not talent_extension:has_special_rule("cryptic_servo_skull_improved")
	if base_skull then
		return mod.has_grenades()
	else
		return false
	end
end

-- TO DO
--[[]
mod.find_medic_target = function()
	local player = Managers.player:local_player_safe(1)
	local unit_data_extension = player and player.player_unit and ScriptUnit.has_extension(player.player_unit, "unit_data_system")
	local target_finder = unit_data_extension and unit_data_extension:read_component("action_module_ability_target_finder")
	if target_finder then
		mod:echo(target_finder)
		if target_finder.target_unit_1 then
			mod:echo(target_finder.target_unit_1)
		end
	end
end
--]]

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │         SAFE HOOKS         │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Determine when the dog is biting something
mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
	local player = Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	if attacking_unit == player_unit then
		if damage_profile.companion_pounce then
			if grenades.dogsplosion.require_tag and not DOG.TAG then
				return
			end
			if DOG.LAST_EXPLOSION + grenades.dogsplosion.cooldown < Managers.time:time("main") then
				DOG.POUNCING = true
			end
		end
		if damage_profile.name == "adamant_whistle_explosion" then
			DOG.POUNCING = false
			DOG.LAST_EXPLOSION = Managers.time:time("main")
		end
	end
end)

-- Determine whether or not the dog is currently being commanded to pounce
mod:hook_safe(CLASS.SmartTagSystem, "update", function(self, context, dt, t, ...)
	local player = Managers.player:local_player_safe(1)
	local desired_tag = "unit_threat_adamant"
	local has_tag = false
	for _, tag in pairs(self._all_tags) do
		local template = tag and tag._template
		if template and template.marker_type and string.find(template.marker_type, "unit_threat") then
			local tagger_player = tag:tagger_player()
			local marker = template.marker_type
			-- Add new tags which belong to other players to DOG.TAGS.ALLY
			if tagger_player and tagger_player == player and marker == desired_tag then
				has_tag = true
				break
			end
		end
	end
	DOG.TAG = has_tag
end)

-- Determine when daemonhosts are aggroed and track them due to lack of access to enemy AI as client
mod:hook_safe(CLASS.HudElementBossHealth, "update", function (self, dt, t, ui_renderer, render_settings, input_service)
    local is_active = self._is_active
	if not is_active then
		return
	end
	local active_targets_array = self._active_targets_array
    local num_active_targets = #active_targets_array
	local num_health_bars_to_update = math.min(num_active_targets, self._max_health_bars)
	for i = 1, num_health_bars_to_update do
		local target = active_targets_array[i]
		local unit = target.unit
		local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
		local target_breed = unit_data and unit_data:breed()
        if ALIVE[unit] and target_breed and target_breed.tags.witch then
			AWAKE_DAEMONHOSTS[unit] = true
        end
    end
end)

-- Check if the grenade throw has completed
mod:hook_safe(CLASS.ActionThrowGrenade, "_spawn_projectile", function(self)
	thrown = true
end)

-- Determine when grenade aiming begins
mod:hook_safe(CLASS.ActionAimProjectile, "start", function(self, action_settings, t, time_scale, action_start_params)
	aiming = true
end)

-- Determine when grenade aiming ends
mod:hook_safe(CLASS.ActionAimProjectile, "finish", function(self, reason, data, t, time_in_action)
	aiming = false
end)

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       STANDARD HOOKS       │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Input Interception
mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
	-- Dogsplosion
	if action_name == "grenade_ability_pressed" then
		local dogsplosion = mod.check_dogsplosion()
		local shield = mod.check_shield()
		local skull = mod.base_skull_ready()
		-- Force this action when the throw keybind is pressed
		if KEYBIND.using_keybind and KEYBIND.throw_keybind_pressed then
			-- Reset immediately if using dogsplosion as it cannot be "equipped"
			if dogsplosion or shield or mod.quick_throw() then
				KEYBIND.throw_keybind_pressed = false
			end
			return true
		end
		-- Force this action for automatic dogsplosion, dependent on settings and context
		if dogsplosion and grenades.dogsplosion.enabled then
			-- Initially assume we can dogsplode
			local allowed_to_explode = true
			-- Check thresholds if enabled
			if grenades.dogsplosion.use_threshold then
				local threshold_met = false
				local nearby_enemies, nearby_elites, nearby_specialists, nearby_bosses, daemonhost_in_range = mod.dog_radar(DOG.UNIT)

				--//////////////// DEBUG ////////////////--
				local debug_printout = false
				if debug_printout then
					local cooldown = DOG.LAST_EXPLOSION + grenades.dogsplosion.cooldown - Managers.time:time("main")
					mod:echo("--------------------------------------------------")
					mod:echo("--------------------------------------------------")
					mod:echo("TOTAL: %s, ELITES: %s, SPECIALISTS: %s, BOSSES: %s", nearby_enemies or 0, nearby_elites or 0, nearby_specialists or 0, nearby_bosses or 0)
					mod:echo("SLEEPY DAEMONHOST NEARBY: %s", daemonhost_in_range)
					mod:echo("COOLDOWN REMAINING: %s", cooldown and cooldown > 0 and cooldown or 0)
					mod:echo("--------------------------------------------------")
					mod:echo("--------------------------------------------------")
				end
				--////////////// END DEBUG //////////////--

				local thresholds = {
					enemy = {count = nearby_enemies, threshold = grenades.dogsplosion.enemy_threshold},
					elite = {count = nearby_elites, threshold = grenades.dogsplosion.elite_threshold},
					special = {count = nearby_specialists, threshold = grenades.dogsplosion.special_threshold},
					boss = {count = nearby_bosses, threshold = grenades.dogsplosion.boss_threshold},
				}
				-- Allow explosion if any of the thresholds are met/exceeded
				for _, value in pairs(thresholds) do
					if value.threshold and value.threshold > 0 and value.count >= value.threshold then
						threshold_met = true
						break
					end
				end
				
				-- Override allowance if a daemonhost is nearby without player approval
				if daemonhost_in_range and not grenades.dogsplosion.allow_daemonhost then
					threshold_met = false
				end
				-- Adjust approval based on thresholds
				allowed_to_explode = threshold_met
			-- Otherwise only check daemonhosts, provided the player has requested it
			elseif not grenades.dogsplosion.allow_daemonhost then
				local daemonhost_in_range = mod.daemon_radar(DOG.UNIT)
				allowed_to_explode = not daemonhost_in_range
			end
			-- Override allowance if the player requires a pounce and the dog is not pouncing
			if grenades.dogsplosion.pounce_only and not DOG.POUNCING then
				allowed_to_explode = false
			end
			-- Override allowance if not enough charges
			local charges = mod.get_dogsplosion_charges()
			if charges < grenades.dogsplosion.minimum then
				allowed_to_explode = false
			end
			-- Execute dogsplosion if still allowed and there is no active cooldown
			local cooldown_remaining = DOG.LAST_EXPLOSION + grenades.dogsplosion.cooldown - Managers.time:time("main")
			if cooldown_remaining <= 0 and allowed_to_explode then
				DOG.LAST_EXPLOSION = Managers.time:time("main")
				DOG.POUNCING = false
				return true
			end
		end
		-- Base Servo Skull
		if skull and grenades.skull.enabled then
			return true
		end
		-- Medicae Servo Skull
		if grenades.medic.enabled then
		end
		-- Integrated Refraction Emitter
		if shield and grenades.shield.enabled then
			local player = Managers.player:local_player(1)
			local player_unit = player and player.player_unit
			local ability_system = player_unit and ScriptUnit.extension(player_unit, "ability_system")
			local charges = ability_system and ability_system:remaining_ability_charges("grenade_ability") or 0
			if charges >= grenades.shield.minimum then
				return mod.panic()
			end
		end
	end
	-- Throw
    if action_name == "action_one_pressed" then
		if ready_to_throw and not thrown and not cancel then
			local allowed = mod.check_weapon()
			if allowed then
				if grenades[current_nade] then
					if grenades[current_nade].throw_type == "overhand" then
						trying_to_throw_primary = true
						return true
					elseif grenades[current_nade].throw_type == "underhand" and aiming then
						trying_to_throw_primary = true
						return true
					else
						trying_to_throw_primary = false
					end
				end
			end
		end
    end
	-- Aim
	if action_name == "action_two_hold" then
		local worker = false
        local action_rule = self._actions[action_name]
		local action_type = action_rule.type
		local combiner = InputService.ACTION_TYPES[action_type].combine_func
		for _, cb in ipairs(action_rule.callbacks) do
			worker = combiner(worker, cb())
		end
        if allow_override and worker and not cancel then
			cancel = true
		end
		
		if ready_to_throw and not thrown and not cancel then
			local allowed = mod.check_weapon()
			if allowed then
				if grenades[current_nade] and grenades[current_nade].throw_type == "underhand" then
					trying_to_throw_secondary = true
					return true
				else
					trying_to_throw_secondary = false
				end
			end
		end
	end
	-- Other interrupting actions
	if interrupt[action_name] then
		local worker = false
        local action_rule = self._actions[action_name]
		local action_type = action_rule.type
		local combiner = InputService.ACTION_TYPES[action_type].combine_func
		for _, cb in ipairs(action_rule.callbacks) do
			worker = combiner(worker, cb())
		end
		if allow_override and worker and not cancel then
			cancel = true
		elseif not allow_override and ready_to_throw and not thrown and not cancel and (trying_to_throw_primary or trying_to_throw_secondary) then
			return false
		end
	end
    return func(self, action_name)
end)

-- Swap Check
mod:hook(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(func, self, slot_name, t, skip_wield_action)
	-- Ignore this action if using the throw keybind
	if KEYBIND.using_keybind then
		-- If using the keybind, but it wasn't pressed, ignore this action to prevent auto-throwing
		if not KEYBIND.throw_keybind_pressed then
			return func(self, slot_name, t, skip_wield_action)
		end
		-- If using the keybind and it was pressed, reset the keybind state
		KEYBIND.throw_keybind_pressed = false
	end
	cancel = false
	if slot_name == "slot_grenade_ability" then
		local weapon = self:_wielded_weapon(self._inventory_component, self._weapons)
		local grenade = weapon and weapon.weapon_template and weapon.weapon_template.name
		local ammo = self._ability_extension and self._ability_extension:remaining_ability_charges("grenade_ability")
		if gmap[grenade] and type(ammo) == "number" then
			local settings = grenades[gmap[grenade]]
			if settings.enabled and ammo >= settings.minimum then
				ready_to_throw = true
				thrown = false
			else
				ready_to_throw = false
				thrown = false
			end
		end
		return func(self, slot_name, t, skip_wield_action)
	else
		ready_to_throw = false
		thrown = false
	end
	return func(self, slot_name, t, skip_wield_action)
end)

-- Toughness monitoring
mod:hook(CLASS.PlayerUnitToughnessExtension, "add_damage", function(func, self, damage_amount, attack_result, hit_actor, damage_profile, attack_type, attack_direction, hit_world_position_or_nil)
    local actual_damage = func(self, damage_amount, attack_result, hit_actor, damage_profile, attack_type, attack_direction, hit_world_position_or_nil)
	if attack_type and attack_type == "ranged" then
		BUFFER.toughness = BUFFER.toughness + actual_damage
		BUFFER.attacks = BUFFER.attacks + 1
		BUFFER.last = Managers.time:time("gameplay")
		if BUFFER.max < actual_damage then
			BUFFER.max = actual_damage
		end
	end
    return actual_damage
end)
-- Health monitoring
mod:hook(CLASS.PlayerUnitHealthExtension, "add_damage", function(func, self, damage_amount, permanent_damage, hit_actor, damage_profile, attack_type, attack_direction, attacking_unit)
	local actual_damage = func(self, damage_amount, permanent_damage, hit_actor, damage_profile, attack_type, attack_direction, attacking_unit)
	if attack_type and attack_type == "ranged" then
		BUFFER.health = BUFFER.health + actual_damage
		BUFFER.attacks = BUFFER.attacks + 1
		BUFFER.last = Managers.time:time("gameplay")
		if BUFFER.max < actual_damage then
			BUFFER.max = actual_damage
		end
	end
	return actual_damage
end)

-- ┌───────────────────┐ --
-- │                   │ --
-- │       DEBUG       │ --
-- │                   │ --
-- └───────────────────┘ --

mod.debug = function()
	if type(debug) == "table" then
		mod:dtf(debug)
		mod:echo("Debug table sent to inspector")
	elseif debug then
		mod:echo(debug)
	else
		mod:echo("Debug var is nil")
	end
end