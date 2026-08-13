-- File: uptime/scripts/mods/uptime/libs/damage_categories.lua
local mod = get_mod("uptime"); if not mod then return end

local Breeds = mod:original_require("scripts/settings/breed/breeds")

local pairs = pairs
local type = type

local CATEGORY_HORDE = "horde"
local CATEGORY_ELITE = "elite"
local CATEGORY_SPECIAL = "special"
local CATEGORY_BOSS = "boss"

local breed_categories = {}

local function breed_category_from_data(breed)
    if not breed then
        return nil
    end

    -- All monsters are bosses, but not all bosses are monsters; is_boss is the authoritative boss flag.
    if breed.is_boss then
        return CATEGORY_BOSS
    end

    local tags = breed.tags

    if not tags then
        return nil
    end

    if tags.special then
        return CATEGORY_SPECIAL
    elseif tags.elite then
        return CATEGORY_ELITE
    elseif tags.horde then
        return CATEGORY_HORDE
    end

    return nil
end

if type(Breeds) == "table" then
    for breed_name, breed in pairs(Breeds) do
        local category = breed_category_from_data(breed)

        if category then
            breed_categories[breed.name or breed_name] = category
        end
    end
end

local function target_category(breed)
    if type(breed) == "table" then
        local category = breed_category_from_data(breed)

        if category then
            return category
        end

        breed = breed.name
    end

    if not breed then
        return CATEGORY_HORDE
    end

    return breed_categories[breed] or CATEGORY_HORDE
end

local dot_profiles = {
    bleeding = true,
    psyker_stun = true,
    burning = true,
    flame_grenade_liquid_area_fire_burning = true,
    liquid_area_fire_burning_barrel = true,
    liquid_area_fire_burning = true,
    phosphor_burning = true,
    warpfire = true,
    shockmaul_stun_interval_damage = true,
    powermaul_p2_stun_interval = true,
    powermaul_p2_stun_interval_basic = true,
    -- powermaul_shield_block_special = true, -- melee
    shock_grenade_stun_interval = true,
    -- psyker_protectorate_spread_chain_lightning_interval = true, -- blitz
    default_chain_lighting_interval = true,
    psyker_smite_kill = true,
    toxin_variant_1 = true,
    toxin_variant_2 = true,
    toxin_variant_3 = true,
    horde_mode_self_propagating_toxin = true,
}

local blitz_types = {
    psyker_test = true,
}

local blitz_profiles = {
    psyker_smite_kill = true,
    psyker_protectorate_channel_chain_lightning_activated = true,
    psyker_protectorate_spread_chain_lightning_interval = true,
    psyker_protectorate_chain_lighting = true,
    psyker_protectorate_chain_lighting_fast = true,
    psyker_throwing_knives = true,
    psyker_throwing_knives_aimed = true,
    psyker_throwing_knives_aimed_pierce = true,
    psyker_throwing_knives_psychic_fortress = true,
    zealot_throwing_knives = true,
    psyker_heavy_swings_shock = true,
    whistle_explosion = true,
    close_whistle_explosion = true,
    shock_grenade = true,
    shock_grenade_stun_interval = true,
    adamant_grenade = true,
    adamant_grenade_impact = true,
    close_adamant_grenade = true,
    shock_mine_self_destruct = true,
    krak_grenade = true,
    krak_grenade_impact = true,
    close_krak_grenade = true,
    close_frag_grenade = true,
    frag_grenade = true,
    frag_grenade_impact = true,
    ogryn_grenade = true,
    close_ogryn_grenade = true,
    ogryn_grenade_impact = true,
    ogryn_box_cluster_frag_grenade = true,
    ogryn_box_cluster_close_frag_grenade = true,
    ogryn_grenade_box_impact = true,
    ogryn_grenade_box_cluster_impact = true,
    ogryn_friendly_rock_impact = true,
    broker_flash_grenade = true,
    broker_flash_grenade_impact = true,
    broker_flash_grenade_close = true,
    broker_missile_launcher_explosion_close = true,
    broker_missile_launcher_explosion = true,
    broker_missile_launcher_impact = true,
    missile_launcher_knockback = true,
    arc_grenade_chain_jump_damage = true,
    force_field_chain_jump_damage = true,
    default_companion_servo_skull_lasgun_killshot = true,
    improved_companion_servo_skull_lasgun_killshot = true,
    companion_servo_skull_flamer = true,

}

local melee_types = {
    melee = true,
    push = true,
}

local melee_profiles = {
    -- powermaul_p2_stun_interval = true,
    -- powermaul_p2_stun_interval_basic = true,
    powermaul_shield_block_special = true,
    powermaul_p3_arc_chain_lightning_link_damage = true,
    chain_lightning_killing_blow = true,
}

return {
    target_category = target_category,

    is_horde = function(breed)
        return target_category(breed) == CATEGORY_HORDE
    end,

    is_elite = function(breed)
        return target_category(breed) == CATEGORY_ELITE
    end,

    is_special = function(breed)
        return target_category(breed) == CATEGORY_SPECIAL
    end,

    is_boss = function(breed)
        return target_category(breed) == CATEGORY_BOSS
    end,

    is_dot = function(profile)
        return profile and dot_profiles[profile] or false
    end,

    is_blitz = function(attack_type, profile)
        return attack_type and blitz_types[attack_type] or profile and blitz_profiles[profile] or false
    end,

    is_melee = function(attack_type, profile)
        return attack_type and melee_types[attack_type] or profile and melee_profiles[profile] or false
    end,
}
