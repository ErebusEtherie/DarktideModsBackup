return {
    kill = {
        broad_attack_types = {
            melee = {
                melee = true,
                push = true,
            },
            ranged = {
                explosion = true,
                ranged = true,
                shout = true,
            },
        },
        split_profiles = {
            default_chain_lighting_attack = {
                broad = { "warp" },
                specific = { "electric" },
                reason = "profile split table: chain lightning attack",
                source = "kill_classification",
            },
            default_chain_lighting_interval = {
                broad = { "warp" },
                specific = { "electric" },
                reason = "profile split table: chain lightning interval",
                source = "kill_classification",
            },
            psyker_smite_kill = {
                broad = {},
                specific = { "warp" },
                reason = "profile split table: psyker smite",
                source = "kill_classification",
            },
            default_warpfire_assault_burst = {
                broad = { "ranged" },
                specific = { "warp" },
                reason = "profile split table: warpfire burst",
                source = "kill_classification",
            },
            force_staff_ball = {
                broad = { "ranged" },
                specific = { "warp" },
                reason = "profile split table: force staff projectile",
                source = "kill_classification",
            },
            combat_blade_light_smiter = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: combat blade smiter",
                source = "kill_classification",
            },
            combat_blade_light_smiter_stab = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: combat blade stab",
                source = "kill_classification",
            },
            heavy_combatsword_p3_smiter_stab = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: heavy combatsword stab",
                source = "kill_classification",
            },
            light_sword_active_p2 = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: active power sword",
                source = "kill_classification",
            },
            heavy_sword_smiter_active_p2 = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: active heavy sword smiter",
                source = "kill_classification",
            },
            heavy_sword_smiter_p2 = {
                broad = { "melee" },
                specific = { "sharp" },
                reason = "profile split table: heavy sword smiter",
                source = "kill_classification",
            },
            adamant_companion_human_pounce = {
                broad = { "melee" },
                specific = {},
                reason = "profile split table: companion pounce",
                source = "kill_classification",
            },
            adamant_companion_ogryn_pounce = {
                broad = { "melee" },
                specific = {},
                reason = "profile split table: companion pounce",
                source = "kill_classification",
            },
            krak_grenade = {
                broad = {},
                specific = { "explosive" },
                reason = "profile split table: krak grenade",
                source = "kill_classification",
            },
            close_krak_grenade = {
                broad = {},
                specific = { "explosive" },
                reason = "profile split table: krak grenade",
                source = "kill_classification",
            },
            flame_grenade_liquid_area_fire_burning = {
                broad = {},
                specific = { "burn" },
                reason = "profile split table: flame grenade burning",
                source = "kill_classification",
            },
            psyker_heavy_swings_shock = {
                broad = { "melee" },
                specific = {},
                reason = "profile split table: shield club shock",
                source = "kill_classification",
            },
        },
        exact_profiles = {
            bleed = {
                bleeding = true,
                psyker_stun = true,
            },
            blunt = {
                broker_missile_launcher_impact = true,
                ogryn_club_light_linesman = true,
                ogryn_club_light_tank = true,
            },
            burn = {
                burning = true,
                flame_grenade_liquid_area_fire_burning = true,
                liquid_area_fire_burning = true,
                liquid_area_fire_burning_barrel = true,
            },
            electric = {
                default_chain_lighting_interval = true,
                powermaul_p2_stun_interval = true,
                powermaul_p2_stun_interval_basic = true,
                psyker_protectorate_spread_chain_lightning_interval = true,
                shock_grenade_stun_interval = true,
                shockmaul_stun_interval_damage = true,
            },
            explosive = {
                barrel_explosion = true,
                barrel_explosion_close = true,
                broker_missile_launcher_explosion = true,
                broker_missile_launcher_explosion_close = true,
                fire_barrel_explosion = true,
                fire_barrel_explosion_close = true,
                poxwalker_explosion = true,
                poxwalker_explosion_close = true,
            },
            sharp = {
                light_combatsword_linesman = true,
                light_combatsword_smiter = true,
            },
            toxin = {
                horde_mode_self_propagating_toxin = true,
                toxin_variant_1 = true,
                toxin_variant_2 = true,
                toxin_variant_3 = true,
            },
            warp = {
                light_force_sword_2h_linesman = true,
                warpfire = true,
            },
        },
    },
    death = {
        loc_breed_display_name_chaos_ogryn_bulwark = "bulwark",
        loc_breed_display_name_chaos_ogryn_executor = "crusher",

        loc_breed_display_name_chaos_ogryn_gunner = "gunner",
        loc_breed_display_name_cultist_gunner = "gunner",
        loc_breed_display_name_renegade_gunner = "gunner",

        loc_breed_display_name_cultist_berzerker = "rager",
        loc_breed_display_name_renegade_berzerker = "rager",

        loc_breed_display_name_cultist_shocktrooper = "shotgunner",
        loc_breed_display_name_renegade_shocktrooper = "shotgunner",

        loc_breed_display_name_renegade_executor = "mauler",

        loc_breed_display_name_renegade_plasma_gunner = "sniper",
        loc_breed_display_name_renegade_radio_operator = "sniper",
        loc_breed_display_name_renegade_sniper = "sniper",

        loc_breed_display_name_chaos_ogryn_houndmaster = "hound",
        loc_breed_display_name_chaos_armored_hound = "hound",
        loc_breed_display_name_chaos_hound = "hound",

        loc_breed_display_name_chaos_poxwalker_bomber = "poxburster",

        loc_breed_display_name_renegade_flamer = "flamer",
        loc_breed_display_name_cultist_flamer = "tox_flamer",

        loc_breed_display_name_renegade_grenadier = "bomber",
        loc_breed_display_name_cultist_grenadier = "tox_bomber",

        loc_breed_display_name_cultist_mutant = "mutant",
        loc_breed_display_name_renegade_netgunner = "trapper",

        loc_breed_display_name_chaos_beast_of_nurgle = "beast_of_nurgle",
        loc_breed_display_name_chaos_daemonhost = "daemonhost",
        loc_breed_display_name_chaos_plage_ogryn = "plague_ogryn",
        loc_breed_display_name_chaos_spawn = "chaos_spawn",
    },
}
