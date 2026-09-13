local mod = get_mod("HavocConditionManager")
local M = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/spawn_scaling")
local Breeds = require("scripts/settings/breed/breeds")
local HordePacing = require("scripts/managers/pacing/horde_pacing/horde_pacing")
local SpecialsPacing = require("scripts/managers/pacing/specials_pacing/specials_pacing")
local MonsterPacing = require("scripts/managers/pacing/monster_pacing/monster_pacing")
local MinionSpawnManager = require("scripts/managers/minion/minion_spawn_manager")
local MutatorModifyHavoc = require("scripts/managers/mutator/mutators/mutator_modify_havoc")

-- The native constructor omits this existing template argument. Restore it;
-- do not change the buff values, breed pool or any generator/capacity setting.
mod:hook_safe(MutatorModifyHavoc,"init",function(self)
    if not mod.has_local_gameplay_authority() or not self._is_server then return end
    local data=self._template and self._template.init_modify_horde
    local game_mode=Managers.state.game_mode and Managers.state.game_mode:game_mode()
    local havoc=game_mode and game_mode:extension("havoc")
    if data and havoc then havoc:init_horde_buff(data) end
end)

local function active()
    local director = get_mod("HavocEnemyDirector")
    return mod.has_local_gameplay_authority() and not (director and director.is_active and director.is_active())
end
local function factors(category)
    if not category or not active() then return 1, 1 end
    return M.factors(mod:get(M.setting_ids[category]), mod:get("spawn_mode_" .. category))
end
local function copy(t)
    local result = {}
    for key, value in pairs(t or {}) do result[key] = value end
    return result
end
local function composition_category(value, seen, counts)
    if type(value) ~= "table" or seen[value] then return end
    seen[value] = true
    if value.name and Breeds[value.name] then
        local category = M.category_for_breed(Breeds[value.name])
        if category then counts[category] = (counts[category] or 0) + 1 end
    end
    for _, child in pairs(value) do composition_category(child, seen, counts) end
end
local function source_speed(composition, fallback)
    if not active() then return 1,1 end
    local counts, category, highest = {}, fallback, 0
    composition_category(composition, {}, counts)
    for _, candidate in ipairs({"common", "elite", "special", "boss"}) do
        if (counts[candidate] or 0) > highest then category, highest = candidate, counts[candidate] end
    end
    return factors(category)
end

mod.scale_native_horde = function(self)
    local speed = source_speed(self._current_compositions, "common")
    if speed == 1 then return end
    local old = self._next_horde_at
    if old then
        local lead = old - (self._next_horde_pre_stinger_at or old)
        self._next_horde_at = old / speed
        self._next_horde_pre_stinger_at = math.max(0, self._next_horde_at - lead)
    end
end
mod:hook(HordePacing, "add_trickle_horde", function(func, self, template)
    local speed = source_speed(template.horde_compositions, "common")
    if speed == 1 then return func(self, template) end
    local adjusted = copy(template)
    for _, key in ipairs({"trickle_horde_travel_distance_range", "trickle_horde_cooldown", "time_between_waves"}) do
        if type(template[key]) == "table" then adjusted[key] = {template[key][1] / speed, template[key][2] / speed} end
    end
    return func(self, adjusted)
end)
mod.scale_native_special_slot = function(self, slots, slot)
    local category = slot and M.category_for_breed(Breeds[slot.breed_name]) or "special"
    local speed = factors(category)
    if slot and slot.spawn_timer and speed ~= 1 then
        local lead = slot.foreshadow_stinger_timer and slot.spawn_timer - slot.foreshadow_stinger_timer
        slot.spawn_timer = slot.spawn_timer / speed
        if lead then slot.foreshadow_stinger_timer = math.max(0, slot.spawn_timer - lead) end
    end
end
mod:hook(MonsterPacing, "_update_timer", function(func, self, dt, ...)
    local speed = factors("boss")
    return func(self, dt * speed, ...)
end)

local spawn_types = {common = "hordes", elite = "hordes", special = "specials", boss = "monsters"}
local function capacity_allows(manager, category, breed_name)
    local pacing = Managers.state and Managers.state.pacing
    if not pacing or not pacing:spawn_type_enabled(spawn_types[category]) then return false end
    if manager:total_allocated_num_enemies() >= 145 then return false end
    if category ~= "special" and category ~= "boss" then return true end
    local category_count, breed_count = 0, 0
    for _, unit in ipairs(manager:spawned_minions()) do
        if HEALTH_ALIVE[unit] then
            local breed = ScriptUnit.extension(unit, "unit_data_system"):breed()
            if M.category_for_breed(breed) == category then category_count = category_count + 1 end
            if breed.name == breed_name then breed_count = breed_count + 1 end
        end
    end
    if category == "special" then
        local specials = pacing._specials_pacing
        local template = specials and specials._template
        local same_limit = specials and specials._optional_max_of_same_override and specials._optional_max_of_same_override[breed_name]
            or template and template.max_of_same and template.max_of_same[breed_name]
        if same_limit and breed_count >= same_limit then return false end
        return specials and category_count < (specials._max_alive_specials or 0)
    end
    local monster = pacing._monster_pacing
    local template = monster and monster._template
    if template and template.max_allowed_by_heat then
        local limits = pacing:get_table_entry_by_heat_stage(template.max_allowed_by_heat)
        if limits and limits.monsters and category_count >= limits.monsters then return false end
    end
    return true
end

mod:hook(SpecialsPacing,"_spawn_special",function(func,self,slot,...)
    if active() then
        local _,quantity=factors("special")
        local manager=Managers.state.minion_spawn
        local name=self:_get_breed_name(slot.breed_name)
        if quantity>1 and M.category_for_breed(Breeds[name])=="special"
            and not capacity_allows(manager,"special",name) then return false end
    end
    return func(self,slot,...)
end)

mod:hook(MinionSpawnManager, "spawn_minion", function(func, self, breed_name, position, rotation, side_id, params)
    if not active() or side_id ~= 2 or params and params.optional_mission_objective_id then
        return func(self, breed_name, position, rotation, side_id, params)
    end
    local resolved = self:replacement_breed(breed_name) or breed_name
    local category = M.category_for_breed(Breeds[resolved])
    local _, quantity = factors(category)
    if quantity == 1 then return func(self, breed_name, position, rotation, side_id, params) end
    local original_params = copy(params)
    local unit = func(self, breed_name, position, rotation, side_id, params)
    if not unit then return unit end
    self._hcm_count_remainders = self._hcm_count_remainders or {}
    local count
    count, self._hcm_count_remainders[category] = M.extra_count(quantity, self._hcm_count_remainders[category])
    for _ = 1, count do
        if not capacity_allows(self, category, resolved) then break end
        -- Repeat exactly this native request, without a new draw, queue or capacity.
        func(self, breed_name, position, rotation, side_id, copy(original_params))
    end
    return unit
end)
