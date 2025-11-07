-- ┌────────────────────────────┐ --
-- │                            │ --
-- │  My Beloved says... KILL!  │ --
-- │                            │ --
-- │         By Norkkom         │ --  
-- │                            │ --
-- └────────────────────────────┘ --

local mod = get_mod("EmperorsGuidance")
local Breeds = require("scripts/settings/breed/breeds")

-- ┌────────────┐ --
-- │            │ --
-- │  SETTINGS  │ --
-- │            │ --
-- └────────────┘ --

-- Shared locals (if you touch these and crash it's on you)
local current_weapon = "none"
local holding_primary = false
local holding_secondary = false
local initated_via_secondary = false
local filter_category = 1
local locked = false
local locked_heretic = "none"
local server_target = "none"
local mod_version = 127

-- Target eligibility for primary/secondary fire
local BREEDING_TARGETS = {}

-- Mapping of group -> breeds
local BREEDING_GROUPS = {
    boss_group_toggle = {},
    elite_group_toggle = {},
    special_group_toggle = {},
    fodder_group_toggle = {},
    global_group_toggle = {}
}

-- Lookup table for setting IDs
local BREEDING_LOOKUP = {}

-- Filter selection map
local filter_map = {
    primary = 1,
    secondary = 2
}

-- TARGET/GROUP setup
for breed_name, breed in pairs(Breeds) do
    if breed.tags.minion and not breed.tags.companion then
        -- BREEDING TARGETS
        if BREEDING_TARGETS[breed_name] == nil then
            BREEDING_TARGETS[breed_name] = {false, false}
        end
        -- BREEDING LOOKUP
        BREEDING_LOOKUP[breed_name] = true
        -- BREEDING GROUPS
        BREEDING_GROUPS.global_group_toggle[#BREEDING_GROUPS.global_group_toggle + 1] = breed_name
		if breed.tags.elite then
			BREEDING_GROUPS.elite_group_toggle[#BREEDING_GROUPS.elite_group_toggle + 1] = breed_name
		elseif breed.tags.special or breed.tags.ritualist then
			BREEDING_GROUPS.special_group_toggle[#BREEDING_GROUPS.special_group_toggle + 1] = breed_name
		elseif breed.tags.monster or breed.tags.captain or breed.tags.cultist_captain then
			BREEDING_GROUPS.boss_group_toggle[#BREEDING_GROUPS.boss_group_toggle + 1] = breed_name
		else
			BREEDING_GROUPS.fodder_group_toggle[#BREEDING_GROUPS.fodder_group_toggle + 1] = breed_name
		end
    end
end

-- Generic settings
local settings = {
    mod_enabled = true,
    mod_enable_verbose = false,
    filter_primary = true,
    filter_secondary = true,
    copy_primary_to_secondary = true
}

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       DMF FUNCTIONS        │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Re-assigning table vars on load both to limit future mod:get() calls and to handle the copy_primary_to_secondary setting
mod.on_all_mods_loaded = function()
    -- Target settings
    mod.migrate_from_old_versions()
    BREEDING_TARGETS = mod:get("targets") or BREEDING_TARGETS
    -- Update UI
    local filter = filter_map[mod:get("filter_select") or 1]
    if filter then
        for _, breed in pairs(BREEDING_GROUPS.global_group_toggle) do
            if not BREEDING_TARGETS[breed] then
                BREEDING_TARGETS[breed] = {}
            end
            mod:set(breed, BREEDING_TARGETS[breed][filter], false)
        end
    end
    -- Generic settings
    settings.mod_enabled = mod:get("mod_enabled")
    settings.mod_enabled_verbose = mod:get("mod_enable_verbose")
    settings.filter_primary = mod:get("filter_primary")
    settings.filter_secondary = mod:get("filter_secondary")
    settings.copy_primary_to_secondary = mod:get("copy_primary_to_secondary")
    mod.refresh_current_weapon()
end

-- Settings change handler
mod.on_setting_changed = function(id)
    -- Generic settings
    if settings[id] ~= nil then
        settings[id] = mod:get(id)
    -- Filter selection
    elseif id == "filter_select" then
        local filter = filter_map[mod:get("filter_select") or 1]
        if filter then
            for _, breed in pairs(BREEDING_GROUPS.global_group_toggle) do
                
                mod:set(breed, BREEDING_TARGETS[breed][filter], false)
            end
        end
    -- Breed toggles
    elseif BREEDING_LOOKUP[id] then
        local filter = filter_map[mod:get("filter_select") or 1]
        if filter then
            BREEDING_TARGETS[id][filter] = mod:get(id)
        end
        mod:set("targets", BREEDING_TARGETS, false)
    -- Group toggles
    elseif BREEDING_GROUPS[id] then
        mod.toggle_group(id)
    end
end

-- Reset weapon on game state change so we don't crash in the hub etc.
mod.on_game_state_changed = function(status, state)
    current_weapon = "none"
end
                                                                                                 
-- ┌────────────────────────────┐ --
-- │                            │ --
-- │      CUSTOM FUNCTIONS      │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Migrate settings between incompatible versions
mod.migrate_from_old_versions = function()
    local cached_version = mod:get("mod_version")

    -- Update settings to compacted list format for versions below 1.2.7
    if not cached_version or cached_version < 127 then
        -- Use old setting format to set targets
        for _, v in pairs(BREEDING_GROUPS.global_group_toggle) do
            BREEDING_TARGETS[v] = {mod:get(v.."0primary") or false, mod:get(v.."0secondary") or false}
        end
        -- Store target data to new format
        mod:set("targets", BREEDING_TARGETS, false)
        -- Remove old settings
        for _, v in pairs(BREEDING_GROUPS.global_group_toggle) do
            mod:set(v.."0primary", nil, false)
            mod:set(v.."0secondary", nil, false)
        end
        -- Set new version to 127 (not current version in case additional patches are needed)
        mod:set("mod_version", 127, false)
        cached_version = 127
    end

    -- Patching complete, update mod version to current
    if cached_version ~= mod_version then
        mod:set("mod_version", mod_version, false)
    end
end

-- Set a group of breeds to true or false dependent on their current aggregate state
mod.toggle_group = function(group)
    -- Tally how many are enabled to determine whether this toggle should be enabling or disabling the group
    local enabled, total = 0, 0
    local filter = filter_map[mod:get("filter_select") or 1]
    for _, breed in ipairs(BREEDING_GROUPS[group]) do
        total = total + 1
        if BREEDING_TARGETS[breed] and BREEDING_TARGETS[breed][filter] then
            enabled = enabled + 1
        end
    end
    -- Set desired state to true if less than or equal to 50% are enabled, false otherwise
    local toggle_state = (enabled / total) * 100 <= 50 and true or false
    -- Toggle
    for _, breed in ipairs(BREEDING_GROUPS[group]) do
        BREEDING_TARGETS[breed][filter] = toggle_state
        mod:set(breed, toggle_state, false)
    end
    mod:set("targets", BREEDING_TARGETS, false)
    mod:set(group, false, false)
end

-- Fetch weapon name (should only be done on mod reload as the wield hook is better in every way)
mod.refresh_current_weapon = function()
    local player_manager = Managers and Managers.player
    if player_manager then
        local player = player_manager:local_player_safe(1)
        local player_unit = player and player.player_unit
        local visual_loadout = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
        wielded_slot = visual_loadout and visual_loadout._inventory_component and visual_loadout._inventory_component.wielded_slot
        -- Only check grenade slot as weapons will be updated upon next weapon swap anyway
        if wielded_slot and wielded_slot == "slot_grenade_ability" then
            weapon_name = visual_loadout._inventory_component.__data[1].slot_grenade_ability
            current_weapon = weapon_name and weapon_name:match("([^/]+)$")
        end
    end
end

-- Check for breedable status by category (primary/secondary)
mod.breedable = function(target, category)
    if not target or not category then
        return false
    end
    if BREEDING_TARGETS[target] ~= nil and BREEDING_TARGETS[target][category] ~= nil then
        return BREEDING_TARGETS[target][category]
    else 
        return false
    end
end

-- Setup for breedability check
mod.breeder = function(val, category)
    -- copy_primary_to_secondary override
    if (holding_secondary or initated_via_secondary) and not settings.copy_primary_to_secondary then
        category = 2
    end
    -- If locked don't eval target validity
    if locked then
        return val
    elseif mod.breedable(server_target, category) then
        return val
    else
        return false
    end
end

mod.toggle_mod = function()
    if not Managers.ui:using_input() then
		if settings.mod_enabled then
            settings.mod_enabled = false
        else
            settings.mod_enabled = true
        end
		if settings.mod_enabled_verbose then
			mod:echo("%s.", settings.mod_enabled and "Enabled" or "Disabled")
		end
	end
end

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │         SAFE HOOKS         │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Get constant updates from Player smart targeting system to see what the server considers targeted
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "targeting_data", function(self)
    if current_weapon == "psyker_smite" then
        local smart_unit = self._targeting_data and self._targeting_data.unit
        if smart_unit then
            server_target = ScriptUnit.has_extension(smart_unit, "unit_data_system") and ScriptUnit.has_extension(smart_unit, "unit_data_system"):breed() and ScriptUnit.has_extension(smart_unit, "unit_data_system"):breed().name
        else
            server_target = "none"
        end
    end
end)

-- When the Brain Burst smart targeting system is initiated, check if we started it via secondary fire
mod:hook_safe(CLASS.ActionSmiteTargeting, "start", function (self, action_settings, t, time_scale, action_start_params)
    if holding_secondary then
        initated_via_secondary = true
    end
end)

-- When Brain Burst attempts a lock, check if we should also consider it a lock
mod:hook_safe(CLASS.ActionSmiteTargeting, "fixed_update", function (self, dt, t, time_in_action)
    local heretic = self._action_module_target_finder.target_unit_1
    if heretic then
        local heretic_data = ScriptUnit.has_extension(heretic, "unit_data_system")
        if heretic_data then
            if mod.breeder(heretic_data:breed().name, filter_category) then
                locked = true
                locked_heretic = heretic
            end
        end
    end
end)

-- Reset flags once Brain Burst ends (either via detonation or manual release)
mod:hook_safe(CLASS.ActionSmiteTargeting, "finish", function (self, reason, data, t, time_in_action, action_settings, next_action_params)
    locked = false
    initated_via_secondary = false
end)

-- Get weapon on swap
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, ...)
    if self._player == Managers.player:local_player(1) then
        local wep_template = self._weapons[slot_name].weapon_template
        current_weapon = wep_template.name
    end
end)

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       STANDARD HOOKS       │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Input interception
mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
    if settings.mod_enabled then
        if action_name == "action_one_hold" and current_weapon == "psyker_smite" then
            -- Get primary input and set holding_primary flag
            local worker = false
            local action_rule = self._actions[action_name]
            local action_type = action_rule.type
            local combiner = InputService.ACTION_TYPES[action_type].combine_func
            for _, cb in ipairs(action_rule.callbacks) do
                worker = combiner(worker, cb())
            end
            holding_primary = worker
            -- Reset lock if not holding primary fire or the locked target died
            if not_holding_primary or not HEALTH_ALIVE[locked_heretic] then
                locked = false
            end
            -- Primary filter
            if settings.filter_primary then
                filter_category = 1
                if mod.breeder(holding_primary, filter_category) then
                    return func(self, action_name)
                else
                    return false
                end
            -- Secondary filter
            elseif settings.filter_secondary then
                filter_category = 2
                if mod.breeder(holding_primary, filter_category) then
                    return func(self, action_name)
                else
                    return false
                end
            end
        elseif action_name == "action_two_hold" and current_weapon == "psyker_smite" then
            -- Get secondary input and set holding_secondary flag
            local worker = false
            local action_rule = self._actions[action_name]
            local action_type = action_rule.type
            local combiner = InputService.ACTION_TYPES[action_type].combine_func
            for _, cb in ipairs(action_rule.callbacks) do
                worker = combiner(worker, cb())
            end
            holding_secondary = worker
        end
    end
    return func(self, action_name)
end)