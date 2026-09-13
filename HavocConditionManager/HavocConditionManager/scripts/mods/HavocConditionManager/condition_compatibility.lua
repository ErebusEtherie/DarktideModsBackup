local mod = get_mod("HavocConditionManager")
local Templates = require("scripts/settings/circumstance/circumstance_templates")
local MutatorManager = require("scripts/managers/mutator/mutator_manager")
local GameModeExtensionHavoc = require("scripts/managers/game_mode/game_mode_extensions/game_mode_extension_havoc")
local CircumstanceManager = require("scripts/managers/circumstance/circumstance_manager")
local HealthStationSystem = require("scripts/extension_systems/health_station/health_station_system")

local function active_data()
    if not mod.has_local_gameplay_authority() then return end
    local difficulty = Managers.state.difficulty
    return difficulty and difficulty:get_parsed_havoc_data()
end

local function mission_overrides(original)
    local data=active_data()
    if not data then return original end
    local result=table.clone_instance(original or {})
    for _,id in ipairs(data.circumstances or {}) do
        local template=Templates[id]
        if template and template.mission_overrides then table.merge_recursive(result,template.mission_overrides) end
    end
    return result
end
mod:hook(CircumstanceManager,"mission_overrides",function(func,self)
    return mission_overrides(func(self))
end)
mod:hook(HealthStationSystem,"_fetch_settings",function(func,self,mission,circumstance_name)
    local original=func(self,mission,circumstance_name)
    local combined=mission_overrides({health_station=original})
    return combined.health_station
end)

-- The native Havoc loader concatenates lists without removing duplicate mutators.
-- Keep its generators and templates; use its existing single-mutator loader once per ID.
mod:hook(MutatorManager, "_load_mutators", function(func, self, circumstance_name)
    local data = active_data()
    if not data then return func(self, circumstance_name) end
    local seen = {}
    for _, id in ipairs(data.circumstances or {}) do
        local template = Templates[id]
        for _, name in ipairs(template and template.mutators or {}) do
            if not seen[name] then
                seen[name] = true
                self:load_mutator_from_name(name)
            end
        end
    end
end)

local function add_pickups(destination, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = destination[key] or {}
            add_pickups(destination[key], value)
        elseif type(value) == "number" then
            destination[key] = (destination[key] or 0) + value
        end
    end
end

-- PickupSystem already applies the main circumstance before Havoc adjustments.
-- Add only the other conditions, retaining native additive pickup semantics.
mod:hook(GameModeExtensionHavoc, "get_havoc_pickup_overrides", function(func, self)
    local original = func(self)
    local data = active_data()
    if not data then return original end
    local manager = Managers.state.circumstance
    local primary = manager and manager:circumstance_name()
    local seen, result = {}, nil
    local primary_template = primary and Templates[primary]
    local primary_pickups = primary_template and primary_template.mission_overrides
    primary_pickups = primary_pickups and primary_pickups.pickup_settings
    if primary_pickups then seen[primary_pickups] = true end
    for _, id in ipairs(data.circumstances or {}) do
        local template = Templates[id]
        local overrides = template and template.mission_overrides
        local pickups = overrides and overrides.pickup_settings
        if id ~= primary and pickups and not seen[pickups] then
            seen[pickups] = true
            result = result or table.clone_instance(original or {})
            add_pickups(result, pickups)
        end
    end
    return result or original
end)

-- Used by the existing barrel hook, so DMF registers only one hook on that method.
mod.get_havoc_hazard_settings = function()
    local data = active_data()
    if not data then return end
    local settings
    for _, id in ipairs(data.circumstances or {}) do
        local template = Templates[id]
        local overrides = template and template.mission_overrides
        if overrides and overrides.hazard_prop_settings then
            settings = overrides.hazard_prop_settings
        end
    end
    return settings
end
