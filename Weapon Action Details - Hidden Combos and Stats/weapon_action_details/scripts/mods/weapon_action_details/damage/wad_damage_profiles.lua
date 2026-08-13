-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_damage_profiles.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local PowerLevelSettings = mod:original_require("scripts/settings/damage/power_level_settings")

local DEFAULT_POWER_LEVEL = PowerLevelSettings.default_power_level

function mod.selected_damage_profile(action, template_i, use_special_damage_profile)
    if not action then
        return nil
    end

    local damage_profile, special_damage_profile = Action.damage_template(action, template_i)

    return (use_special_damage_profile or action.activate_special_on_required_ammo) and special_damage_profile or
        damage_profile
end

function mod.selected_hit_stickyness_settings(action, use_special_damage_profile)
    if not action then
        return nil
    end

    if use_special_damage_profile then
        return action.hit_stickyness_settings_special_active or action.hit_stickyness_settings
    end

    return action.hit_stickyness_settings
end

function mod.sticky_damage_applies(hit_stickyness_settings, use_special_damage_profile)
    return hit_stickyness_settings and (use_special_damage_profile or hit_stickyness_settings.always_sticky) or false
end

function mod.sticky_damage_power_level(hit_stickyness_settings, damage)
    return damage.stat_power_level or damage.power_level or hit_stickyness_settings.stat_power_level or
        hit_stickyness_settings.power_level or DEFAULT_POWER_LEVEL
end

local function damage_profile_ignores_shield(damage_profile)
    return damage_profile and damage_profile.ignore_shield == true or false
end

local function damage_profile_is_shield_breaker(damage_profile)
    return damage_profile and damage_profile.shield_breaker == true or false
end

function mod.action_damage_profile_matches(action, use_special_damage_profile, check_func)
    if not action or type(check_func) ~= "function" then
        return false
    end

    local num_templates = Action.num_damage_templates(action)

    for template_i = 1, num_templates do
        if check_func(mod.selected_damage_profile(action, template_i, use_special_damage_profile)) then
            return true
        end

        local explosion_template = Action.explosion_template(action, template_i)
        local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

        if check_func(inner_damage_profile) then
            return true
        end
    end

    local hit_stickyness_settings = mod.selected_hit_stickyness_settings(action, use_special_damage_profile)

    if not mod.sticky_damage_applies(hit_stickyness_settings, use_special_damage_profile) then
        return false
    end

    local damage = hit_stickyness_settings.damage

    if type(damage) ~= "table" then
        return false
    end

    return check_func(damage.damage_profile) or check_func(damage.last_damage_profile)
end

function mod.action_backstab_bonus(action, use_special_damage_profile)
    local backstab_bonus

    mod.action_damage_profile_matches(action, use_special_damage_profile, function(damage_profile)
        local profile_backstab_bonus = damage_profile and damage_profile.backstab_bonus

        if type(profile_backstab_bonus) == "number" and profile_backstab_bonus > (backstab_bonus or 0) then
            backstab_bonus = profile_backstab_bonus
        end

        return false
    end)

    return backstab_bonus
end

function mod.action_damage_profile_ignores_shield(action, use_special_damage_profile)
    return mod.action_damage_profile_matches(action, use_special_damage_profile, damage_profile_ignores_shield)
end

function mod.action_damage_profile_is_shield_breaker(action, use_special_damage_profile)
    return mod.action_damage_profile_matches(action, use_special_damage_profile, damage_profile_is_shield_breaker)
end
