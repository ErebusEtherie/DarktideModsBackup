local mod = get_mod("LessDoT")
local MOD_ENABLED = true
BREEDS = {
    horde = true,
    roamer = true,
    elite = true,
    special = true,
    monster = true,
    captain = true,
}
local EFFECTS = {
    bleed = {
        KEYWORDS = { buff_bleeding = true },
        BREEDS = table.clone(BREEDS),
    },
    burn = {
        KEYWORDS = {
            buff_burning = true,
            buff_burning_stack_lvl02 = true,
            buff_burning_stack_lvl03 = true,
            buff_burning_stack_lvl04 = true,
            buff_burning_green = true,
            buff_warpfire = true,
        },
        BREEDS = table.clone(BREEDS),
    },
    lightning = {
        KEYWORDS = { buff_chainlightning = true },
        BREEDS = table.clone(BREEDS),
    }
}

-- Settings
mod.on_all_mods_loaded = function()
    for name, table in pairs(EFFECTS) do
        for breed, _ in pairs(BREEDS) do
            table.BREEDS[breed] = mod:get(name.."_"..breed)
            -- Subcategories
            table.BREEDS["roamer"] = mod:get(name.."_horde")
            table.BREEDS["captain"] = mod:get(name.."_monster")
        end
    end
end

mod.on_enabled = function()
    MOD_ENABLED = true
end

mod.on_disabled = function()
    MOD_ENABLED = false
end

mod.on_setting_changed = function(setting)
    local setting_category = setting:match("([^_]+)")
    local setting_breed = setting:match("_(.+)")
    EFFECTS[setting_category].BREEDS[setting_breed] = mod:get(setting)
    -- Subcategories
    if setting_breed == "horde" then
        EFFECTS[setting_category].BREEDS["roamer"] = mod:get(setting)
    elseif setting_breed == "monster" then
        EFFECTS[setting_category].BREEDS["captain"] = mod:get(setting)
    end
end

-- Breed check - returns list of usable effects to apply, or nil if none are allowed
mod.allowed = function(extension, effects)
    local unit_data = ScriptUnit.has_extension(extension._unit, "unit_data_system")
    local breed = unit_data and unit_data:breed()
    local potential_effects = {}
    if breed then
        -- Multiple effects can be applied at once, check for any banned particles and rebuild effect list to only include allowed effects
        for _, effect in pairs(effects) do
            local vfx = effect.vfx
            if vfx and vfx.particle_effect then
                local effect_name = vfx.particle_effect:match("([^/]+)$")
                local banned = false
                for _, category in pairs(EFFECTS) do
                    if category.KEYWORDS[effect_name] then
                        for name, _ in pairs(breed.tags) do
                            if category.BREEDS[name] == false then
                                banned = true
                                break
                            end
                        end
                        if banned then
                            break
                        end
                    end
                end
                if not banned then
                    table.insert(potential_effects, effect)
                end
            end
        end
    end
    return #potential_effects > 0 and potential_effects or nil
end

-- Hooks
mod:hook(CLASS.MinionBuffExtension, "_start_node_effects", function(func, self, fx_name, node_effects)
    if not MOD_ENABLED then return func(self, fx_name, node_effects) end
    local allowed_effects = mod.allowed(self, node_effects)
    if allowed_effects then return func(self, fx_name, allowed_effects) end
end)
mod:hook(CLASS.MinionBuffExtension, "_stop_node_effects", function(func, self, fx_name, node_effects)
    if not MOD_ENABLED then return func(self, fx_name, node_effects) end
    local allowed_effects = mod.allowed(self, node_effects)
    if allowed_effects then return func(self, fx_name, allowed_effects) end
end)

