-- File: weapon_action_details/scripts/mods/weapon_action_details/wad_localization_glossary.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

-- ============================================================================
-- VANILLA DARKTIDE LOCALIZATION GLOSSARY
-- ============================================================================
-- Values are vanilla Darktide localization keys. English comments document the
-- current English label; notes identify keys deliberately borrowed by WAD for a
-- different but useful meaning. Never display the English comments directly.
-- Pass the key to Localize(...) so the player's selected language is respected.
--
-- Constant names mirror the vanilla key without the leading "loc_" prefix. This
-- keeps glossary searches predictable and avoids ambiguous semantic aliases.
--
mod.WAD_LOC = {
    -- CORE UI, ACTION INPUTS, AND TRANSITIONS
    ACTION_INTERACTION_INSERT                                            = "loc_action_interaction_insert",        -- English: "Insert"
    ACTION_INTERACTION_UNLOCK                                            = "loc_action_interaction_unlock",        -- English: "Unlock"
    BASIC_RELOAD_INPUT                                                   = "loc_basic_reload_input",               -- English: "Reload"
    BASIC_TRAINING_TITLE                                                 = "loc_basic_training_title",             -- English: "Basic Training"
    BLOCK                                                                = "loc_block",                            -- English: "Block"
    CHAIN_LIGHT                                                          = "loc_chain_light",                      -- English: "Chained Attacks"
    CONTINUE                                                             = "loc_continue",                         -- English: "Continue"
    GROUP_FINDER_REFRESH_GROUP_LIST_BUTTON                               = "loc_group_finder_refresh_group_list_button", -- English: "Refresh"
    INPUT_HOLD                                                           = "loc_input_hold",                       -- English: "Hold"
    INPUT_RELEASE                                                        = "loc_input_release",                    -- English: "Release"
    INVENTORY_WEAPON_BUTTON_MARKS                                        = "loc_inventory_weapon_button_marks",    -- English: "Marks"
    ITEM_INFORMATION_ACTIONS                                             = "loc_item_information_actions",         -- English: "Actions"
    KEYBIND_CATEGORY_COMBAT                                              = "loc_keybind_category_combat",          -- English: "Combat"
    MAIN_MENU_PLAY_BUTTON                                                = "loc_main_menu_play_button",            -- English: "Start"
    OBJECTIVE_PSYKHANIUM_PULL_POWER_LEVER_01_HEADER                      = "loc_objective_psykhanium_pull_power_lever_01_header", -- English: "Pull the Lever"
    PUSHING                                                              = "loc_pushing",                          -- English: "Push"
    PUSH_FOLLOW_UP                                                       = "loc_push_follow_up",                   -- English: "Push Follow-up"
    TRAINING_GROUNDS_CHOICE_QUIT                                         = "loc_training_grounds_choice_quit",     -- English: "Leave"
    TRAINING_GROUNDS_VIEW_OPTION_ENTER                                   = "loc_training_grounds_view_option_enter", -- English: "Enter"
    UNLOCKED                                                             = "loc_unlocked",                         -- English: "Unlocked"
    UNTAG_SMART_TAG                                                      = "loc_untag_smart_tag",                  -- English: "Cancel"
    WEAPON_INVENTORY_INSPECT_BUTTON                                      = "loc_weapon_inventory_inspect_button",  -- English: "Inspect"

    -- MOVEMENT, WIELDING, AND VIEW INPUTS
    ALIAS_VIEW_NAVIGATE_DOWN                                             = "loc_alias_view_navigate_down", -- English: "Down"
    ALIAS_VIEW_NAVIGATE_LEFT                                             = "loc_alias_view_navigate_left", -- English: "Left"
    ALIAS_VIEW_NAVIGATE_RIGHT                                            = "loc_alias_view_navigate_right", -- English: "Right"
    ALIAS_VIEW_NAVIGATE_UP                                               = "loc_alias_view_navigate_up", -- English: "Up"
    INGAME_CROUCH                                                        = "loc_ingame_crouch", -- English: "Crouch"
    INGAME_DODGE                                                         = "loc_ingame_dodge", -- English: "Dodge"
    INGAME_QUICK_WIELD                                                   = "loc_ingame_quick_wield", -- English: "Swap Weapon"
    INGAME_SLIDE                                                         = "loc_ingame_slide", -- English: "Slide"
    INGAME_SPRINT                                                        = "loc_ingame_sprint", -- English: "Sprint"
    INGAME_WEAPON_EXTRA                                                  = "loc_ingame_weapon_extra", -- English: "Weapon Special Action"
    INGAME_WIELD_3_4_GAMEPAD                                             = "loc_ingame_wield_3_4_gamepad", -- English: "Wield/Swap Item"
    INPUT_LEGEND_ZOOM_IN                                                 = "loc_input_legend_zoom_in", -- English: "Zoom In"
    INPUT_LEGEND_ZOOM_OUT                                                = "loc_input_legend_zoom_out", -- English: "Zoom Out"

    -- ATTACK TYPES, STANCES, AND MELEE ARCHETYPES
    CLASS_PSYKER_NAME                                                    = "loc_class_psyker_name", -- English: "Psyker"
    ITEM_WEAPON_VARIANT_ASSAULT                                          = "loc_item_weapon_variant_assault", -- English: "Assault"
    ITEM_WEAPON_VARIANT_DEMOLITION                                       = "loc_item_weapon_variant_demolition", -- English: "Blast"
    ITEM_WEAPON_VARIANT_KILLSHOT                                         = "loc_item_weapon_variant_killshot", -- English: "Sniper"
    ITEM_WEAPON_VARIANT_LINESMAN                                         = "loc_item_weapon_variant_linesman", -- English: "Vanguard"
    ITEM_WEAPON_VARIANT_NINJAFENCER                                      = "loc_item_weapon_variant_ninjafencer", -- English: "Assassin"
    ITEM_WEAPON_VARIANT_SMITER                                           = "loc_item_weapon_variant_smiter", -- English: "Executioner"
    ITEM_WEAPON_VARIANT_TANK                                             = "loc_item_weapon_variant_tank", -- English: "Relentless"
    RANGED_ATTACK_PRIMARY                                                = "loc_ranged_attack_primary", -- English: "Hip Fire"
    RANGED_ATTACK_SECONDARY_ADS                                          = "loc_ranged_attack_secondary_ads", -- English: "Aim Down Sights"
    RANGED_ATTACK_SECONDARY_BRACED                                       = "loc_ranged_attack_secondary_braced", -- English: "Braced"
    WEAPON_ACTION_TITLE_HEAVY                                            = "loc_weapon_action_title_heavy", -- English: "Heavy Attack"
    WEAPON_ACTION_TITLE_LIGHT                                            = "loc_weapon_action_title_light", -- English: "Light Attack"
    WEAPON_ACTION_TITLE_SPECIAL                                          = "loc_weapon_action_title_special", -- English: "Special Action"
    WEAPON_STATS_DISPLAY_BRACED                                          = "loc_weapon_stats_display_braced", -- English: "Braced Fire"
    WEAPON_STATS_DISPLAY_HIP_FIRE                                        = "loc_weapon_stats_display_hip_fire", -- English: "Hip Fire"

    -- WEAPON SPECIALS AND SPECIAL-ACTION INPUTS
    INPUT_DESCRIPTION_VENT                                               = "loc_input_description_vent",             -- English: "Vent Peril"
    WEAPON_SPECIAL                                                       = "loc_weapon_special",                     -- English: "Weapon Special"
    WEAPON_SPECIAL_ACTION_THROW                                          = "loc_weapon_special_action_throw",        -- English: "Throw"
    WEAPON_SPECIAL_ACTIVATE                                              = "loc_weapon_special_activate",            -- English: "Activate"
    WEAPON_SPECIAL_BAYONET                                               = "loc_weapon_special_bayonet",             -- English: "Bayonet Attack"
    WEAPON_SPECIAL_DEFENSIVE_STANCE                                      = "loc_weapon_special_defensive_stance",    -- English: "Defensive Stance"
    WEAPON_SPECIAL_FIST_ATTACK                                           = "loc_weapon_special_fist_attack",         -- English: "Punch"
    WEAPON_SPECIAL_FLASHLIGHT                                            = "loc_weapon_special_flashlight",          -- English: "Torch"
    WEAPON_SPECIAL_HOOK_PULL                                             = "loc_weapon_special_hook_pull",           -- English: "Pull"
    WEAPON_SPECIAL_MODE_SWITCH                                           = "loc_weapon_special_mode_switch",         -- English: "Switch Mode"
    WEAPON_SPECIAL_PARRY                                                 = "loc_weapon_special_parry",               -- English: "Parry"
    WEAPON_SPECIAL_SPECIAL_AMMO                                          = "loc_weapon_special_special_ammo",        -- English: "Special Ammo"
    WEAPON_SPECIAL_SPECIAL_ATTACK                                        = "loc_weapon_special_special_attack",      -- English: "Special Melee Attack"
    WEAPON_SPECIAL_WEAPON_BASH                                           = "loc_weapon_special_weapon_bash",         -- English: "Bash"
    WEAPON_SPECIAL_WEAPON_POWERUP_DUAL_STUBPISTOLS_P1                    = "loc_weapon_special_weapon_powerup_dual_stubpistols_p1", -- English: "Trickster"
    WEAPON_SPECIAL_WEAPON_VENT                                           = "loc_weapon_special_weapon_vent",         -- English: "Vent Heat"

    -- WEAPON KEYWORDS AND GENERAL LABELS
    GLOSSARY_TERM_CHARGE                                                 = "loc_glossary_term_charge",                                                 -- English: "Charge"
    INTERFACE_SETTING_CHAT_BUBBLES_LIFETIME_MULTIPLIER                   = "loc_interface_setting_chat_bubbles_lifetime_multiplier",                   -- English: "Duration"
    WEAPON_KEYWORD_CHARGED_ATTACK                                        = "loc_weapon_keyword_charged_attack",                                        -- English: "Charged Attack"
    WEAPON_KEYWORD_EXPLOSIVE                                             = "loc_weapon_keyword_explosive",                                             -- English: "Explosive"
    WEAPON_KEYWORD_HIGH_CLEAVE                                           = "loc_weapon_keyword_high_cleave",                                           -- English: "Cleaving Strike"
    WEAPON_KEYWORD_HIGH_DAMAGE                                           = "loc_weapon_keyword_high_damage",                                           -- English: "High Damage"
    WEAPON_KEYWORD_HEAVY_SPECIAL_WINDUP                                  = "loc_weapon_keyword_heavy_special_windup",                                  -- English: "Enhanced Actuators"
    WEAPON_KEYWORD_HEAVY_WINDUP                                          = "loc_weapon_keyword_heavy_windup",                                          -- English: "Charged Swings"
    WEAPON_KEYWORD_MELEE_POWER_BONUS_SCALED_ON_SPECIAL_CHARGES           =
    "loc_weapon_keyword_melee_power_bonus_scaled_on_special_charges",                                                                                  -- English: "Power Channeling"
    WEAPON_KEYWORD_MELEE_POWER_BONUS_SCALED_ON_SPECIAL_CHARGES_MOUSEOVER =
    "loc_weapon_keyword_melee_power_bonus_scaled_on_special_charges_mouseover",                                                                        -- English: "Gain Melee Power Bonus, scaling on available Special charges."
    WEAPON_KEYWORD_SHOCK_WEAPON                                          = "loc_weapon_keyword_shock_weapon",                                          -- English: "Shock"
    WEAPON_KEYWORD_SPRAY_N_PRAY                                          = "loc_weapon_keyword_spray_n_pray",                                          -- English: "Torrent"
    TERM_GLOSSARY_BROKER_TOXIN                                           = "loc_term_glossary_broker_toxin",                                           -- English: "Chem Toxin"
    WEAPON_INVENTORY_TRAITS_TITLE_TEXT                                   = "loc_weapon_inventory_traits_title_text",                                   -- English: "Blessings"
    WEAPON_STAT_TITLE_AMMO                                               = "loc_weapon_stat_title_ammo",                                               -- English: "Ammo"

    -- FIRE MODES
    WEAPON_STATS_FIRE_MODE_BURST                                         = "loc_weapon_stats_fire_mode_burst", -- English: "Burst-fire"
    WEAPON_STATS_FIRE_MODE_FULL_AUTO                                     = "loc_weapon_stats_fire_mode_full_auto", -- English: "Fully Automatic"
    WEAPON_STATS_FIRE_MODE_PROJECTILE                                    = "loc_weapon_stats_fire_mode_projectile", -- English: "Projectile"
    WEAPON_STATS_FIRE_MODE_SEMI_AUTO                                     = "loc_weapon_stats_fire_mode_semi_auto", -- English: "Semi-automatic"
    WEAPON_STATS_FIRE_MODE_SHOTGUN                                       = "loc_weapon_stats_fire_mode_shotgun", -- English: "Shotgun"

    -- ARMOUR TYPES AND HIT ZONES
    WEAPON_DETAILS_BODY                                                  = "loc_weapon_details_body",          -- English: "Body"
    WEAPON_DETAILS_CRIT                                                  = "loc_weapon_details_crit",          -- English: "Critical"
    WEAPON_DETAILS_CRIT_HS                                               = "loc_weapon_details_crit_hs",       -- English: "Critical Weakspot"
    WEAPON_DETAILS_WEAKSPOT                                              = "loc_weapon_details_weakspot",      -- English: "Weakspot"
    GLOSSARY_ARMOUR_TYPE_RESISTANT                                       = "loc_glossary_armour_type_resistant", -- English: "Unyielding"
    WEAPON_STATS_DISPLAY_ARMORED                                         = "loc_weapon_stats_display_armored", -- English: "Flak Armoured"
    WEAPON_STATS_DISPLAY_BERZERKER                                       = "loc_weapon_stats_display_berzerker", -- English: "Maniac"
    WEAPON_STATS_DISPLAY_DISGUSTINGLY_RESILIENT                          = "loc_weapon_stats_display_disgustingly_resilient", -- English: "Infested"
    WEAPON_STATS_DISPLAY_SUPER_ARMOR                                     = "loc_weapon_stats_display_super_armor", -- English: "Carapace Armoured"
    WEAPON_STATS_DISPLAY_UNARMORED                                       = "loc_weapon_stats_display_unarmored", -- English: "Unarmoured"

    -- DAMAGE, CONTROL, AND ATTACK STAT LABELS
    STAGGER                                                              = "loc_stagger",                       -- English: "Stagger"
    STAGGER_OBJECTIVE_2                                                  = "loc_stagger_objective_2",           -- English: "Stagger Large Enemy"
    STATS_DISPLAY_AP_STAT                                                = "loc_stats_display_ap_stat",         -- English: "Penetration"
    STATS_DISPLAY_BURN_STAT                                              = "loc_stats_display_burn_stat",       -- English: "Burn"
    STATS_DISPLAY_CLEAVE_DAMAGE_AND_TARGETS_STAT                         = "loc_stats_display_cleave_damage_and_targets_stat", -- English: "Cleave Efficiency"
    STATS_DISPLAY_CLEAVE_TARGETS_STAT                                    = "loc_stats_display_cleave_targets_stat", -- English: "Cleave Targets"
    STATS_DISPLAY_CONTROL_STAT_MELEE                                     = "loc_stats_display_control_stat_melee", -- English: "Crowd Control"
    STATS_DISPLAY_CRIT_STAT                                              = "loc_stats_display_crit_stat",       -- English: "Critical Bonus"
    STATS_DISPLAY_DAMAGE_STAT                                            = "loc_stats_display_damage_stat",     -- English: "Damage"
    STATS_DISPLAY_DEFENSE_STAT                                           = "loc_stats_display_defense_stat",    -- English: "Defences"
    STATS_DISPLAY_FINESSE_STAT                                           = "loc_stats_display_finesse_stat",    -- English: "Finesse"
    STATS_DISPLAY_FIRST_SAW_DAMAGE                                       = "loc_stats_display_first_saw_damage", -- English: "Shredder"
    WEAPON_STATS_ATTACK_PATTERN                                          = "loc_weapon_stats_attack_pattern",   -- English: "Attack Patterns"
    WEAPON_STATS_DISPLAY_ACCUMULATIVE_STAGGER                            = "loc_weapon_stats_display_accumulative_stagger", -- English: "Accumulative Stagger"
    WEAPON_STATS_DISPLAY_ARC_DAMAGE                                      = "loc_weapon_stats_display_arc_damage", -- English: "Arc Damage"
    WEAPON_STATS_DISPLAY_ATTACK_CHAINS                                   = "loc_weapon_stats_display_attack_chains", -- English: "Attack Chains"
    WEAPON_STATS_DISPLAY_ATTACK_SPEED                                    = "loc_weapon_stats_display_attack_speed", -- English: "Attack Speed"
    WEAPON_STATS_DISPLAY_CLEAVE_MASS_DAMAGE                              = "loc_weapon_stats_display_cleave_mass_damage", -- English: "Cleave Damage Distribution"

    -- RANGE, BLAST, SUPPRESSION, AND BALLISTICS
    STATS_DISPLAY_RANGE_STAT                                             = "loc_stats_display_range_stat",    -- English: "Range"
    WEAPON_STATS_DISPLAY_AREA_SUPPRESSION                                = "loc_weapon_stats_display_area_suppression", -- English: "Area Suppression"
    WEAPON_STATS_DISPLAY_AREA_SUPPRESSION_SIZE                           = "loc_weapon_stats_display_area_suppression_size", -- English: "Area Suppression Radius"
    WEAPON_STATS_DISPLAY_BLAST_RADIUS                                    = "loc_weapon_stats_display_blast_radius", -- English: "Blast Radius"
    WEAPON_STATS_DISPLAY_EFFECTIVE_RANGE                                 = "loc_weapon_stats_display_effective_range", -- English: "Effective Range"
    WEAPON_STATS_DISPLAY_FAR                                             = "loc_weapon_stats_display_far",    -- English: "(Far)"
    WEAPON_STATS_DISPLAY_INNER_BLAST                                     = "loc_weapon_stats_display_inner_blast", -- English: "Epicentre"
    WEAPON_STATS_DISPLAY_INNER_BLAST_RADIUS                              = "loc_weapon_stats_display_inner_blast_radius", -- English: "Epicentre Radius"
    WEAPON_STATS_DISPLAY_NEAR                                            = "loc_weapon_stats_display_near",   -- English: "(Near)"
    WEAPON_STATS_DISPLAY_OUTER_BLAST                                     = "loc_weapon_stats_display_outer_blast", -- English: "Outer Blast"
    WEAPON_STATS_DISPLAY_RADIUS                                          = "loc_weapon_stats_display_radius", -- English: "Area of Effect"
    WEAPON_STATS_DISPLAY_RATE_OF_FIRE                                    = "loc_weapon_stats_display_rate_of_fire", -- English: "Rate of Fire"
    WEAPON_STATS_DISPLAY_RECOIL                                          = "loc_weapon_stats_display_recoil", -- English: "Recoil"
    WEAPON_STATS_DISPLAY_SUPPRESSION                                     = "loc_weapon_stats_display_suppression", -- English: "Suppression"

    -- RESOURCE, SPEED, MOBILITY, AND LIMIT LABELS
    EXPERTISE_CRAFTING_MODIFIERS_MAX                                     = "loc_expertise_crafting_modifiers_max", -- English: "Max"
    EXPLOSION_ON_OVERHEAT_LOCKOUT                                        = "loc_explosion_on_overheat_lockout", -- English: "Overload"
    SETTINGS_MENU_HIGH                                                   = "loc_settings_menu_high",     -- English: "High"
    SETTINGS_MENU_LOW                                                    = "loc_settings_menu_low",      -- English: "Low"
    SETTINGS_MENU_MEDIUM                                                 = "loc_settings_menu_medium",   -- English: "Medium"
    STATS_DISPLAY_RELOAD_SPEED_STAT                                      = "loc_stats_display_reload_speed_stat", -- English: "Reload Speed"
    STATS_DISPLAY_STAMINA_TITLE                                          = "loc_stats_display_stamina_title", -- English: "Stamina"
    STATS_DISPLAY_VENT_SPEED                                             = "loc_stats_display_vent_speed", -- English: "Quell Speed"
    WEAPON_STATS_DISPLAY_BLOCK_EFFICIENCY                                = "loc_weapon_stats_display_block_efficiency", -- English: "Blocking Cost"
    WEAPON_STATS_DISPLAY_BURN_APPLY_RATE                                 = "loc_weapon_stats_display_burn_apply_rate", -- English: "Damage Over Time Application Rate"
    WEAPON_STATS_DISPLAY_CHARGE_SPEED                                    = "loc_weapon_stats_display_charge_speed", -- English: "Charge Speed"
    WEAPON_STATS_DISPLAY_DODGE_DISTANCE                                  = "loc_weapon_stats_display_dodge_distance", -- English: "Dodge Distance"
    WEAPON_STATS_DISPLAY_DODGE_SPEED                                     = "loc_weapon_stats_display_dodge_speed", -- English: "Dodge Speed"
    WEAPON_STATS_DISPLAY_EFFECTIVE_DODGES                                = "loc_weapon_stats_display_effective_dodges", -- English: "Dodge Limit"
    WEAPON_STATS_DISPLAY_HEAT_DECAY                                      = "loc_weapon_stats_display_heat_decay", -- English: "Heat Dissipation"
    WEAPON_STATS_DISPLAY_HEAT_GENERATION                                 = "loc_weapon_stats_display_heat_generation", -- English: "Heat Generation"
    WEAPON_STATS_DISPLAY_MAX_BURN_STACKS                                 = "loc_weapon_stats_display_max_burn_stacks", -- English: "Max Damage Over Time Stacks"
    WEAPON_STATS_DISPLAY_PERIL_COST                                      = "loc_weapon_stats_display_peril_cost", -- English: "Peril Generation"
    WEAPON_STATS_DISPLAY_PERIL_DECAY                                     = "loc_weapon_stats_display_peril_decay", -- English: "Peril Decay"
    WEAPON_STATS_DISPLAY_PUSH_COST                                       = "loc_weapon_stats_display_push_cost", -- English: "Push Cost"
    WEAPON_STATS_DISPLAY_SPRINT_SPEED                                    = "loc_weapon_stats_display_sprint_speed", -- English: "Sprint Speed"
    WEAPON_STATS_DISPLAY_STAMINA                                         = "loc_weapon_stats_display_stamina", -- English: "Stamina"
    WEAPON_STATS_DISPLAY_UNLIMITED                                       = "loc_weapon_stats_display_unlimited", -- English: "Unlimited"

    -- DAMAGE MODE AND CATEGORY LABELS
    SETTING_MELEE                                                        = "loc_setting_melee", -- English: "Melee"
    SETTING_RANGED                                                       = "loc_setting_ranged", -- English: "Ranged"

    -- BORROWED VANILLA LABELS
    ABILITY_OGRYN_OBJECTIVE_2                                            = "loc_ability_ogryn_objective_2",              -- English: "Stagger Large Enemy"
    EXPEDITIONS_PICKUP_DESCRIPTION_FORCE_FIELD_POCKETABLE                = "loc_expeditions_pickup_description_force_field_pocketable", -- English: "Void Shell"
    TALENT_BROKER_BLITZ_FLASH_GRENADE                                    = "loc_talent_broker_blitz_flash_grenade",      -- English: "Blinder"
    TALENT_CRIT_CHANCE_LOW                                               = "loc_talent_crit_chance_low",                 -- English: "Critical Chance Boost"
    TALENT_MENU_TOOLTIP_BUTTON_HINT_REMOVE_LEVEL_FIRST                   = "loc_talent_menu_tooltip_button_hint_remove_level_first", -- English: "Deactivate"
    TALENT_ZEALOT_INCREASED_BACKSTAB_DAMAGE                              = "loc_talent_zealot_increased_backstab_damage", -- English: "Backstab Damage"
    TALENT_ZEALOT_STACKING_MELEE_DAMAGE_AFTER_DODGE                      = "loc_talent_zealot_stacking_melee_damage_after_dodge", -- English: "Riposte"
    TG_WEAPON_SPECIAL_COMBATBLADE                                        = "loc_tg_weapon_special_combatblade",          -- English: "Uppercut"
    TRAIT_BESPOKE_BLEED_ON_ACTIVATED_HIT                                 = "loc_trait_bespoke_bleed_on_activated_hit",   -- English: "Bloodletter"
    TRAIT_BESPOKE_BLEED_ON_NON_WEAKSPOT_HIT                              = "loc_trait_bespoke_bleed_on_non_weakspot_hit", -- English: "Lacerate"
    TRAIT_BESPOKE_POWER_BONUS_BASED_ON_CHARGE_TIME                       = "loc_trait_bespoke_power_bonus_based_on_charge_time", -- English: "Thrust"
    TRAIT_BESPOKE_POWER_BONUS_BASED_ON_CHARGE_TIME_DESC                  = "loc_trait_bespoke_power_bonus_based_on_charge_time_desc", -- English: "Up to {power_level:%s} Strength based on the charge time of your heavy attacks. Stacks {stacks:%s} times."
    TRAIT_BESPOKE_REND_ARMOR_ON_CHARGED_SHOTS                            = "loc_trait_bespoke_rend_armor_on_charged_shots", -- English: "Armourbane"
    WEAPON_FAMILY_COMBATAXE_P2_M1                                        = "loc_weapon_family_combataxe_p2_m1",          -- English: "Tactical Axe"
}
