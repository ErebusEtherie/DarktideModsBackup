local mod = get_mod("MuteImpacts")

-- ----------------------------------------------------
-- Sounds to Mute
-- ----------------------------------------------------
-- These are found manually, as there are too many exceptions when I tried using logical loops
--  Instead, I reserved that for localization
--  Since there, overzealous matching won't cause issues
-- Used as the base for all logic involving this
--  Kept ordered and has do_not_disable entry for the Mod Options
--  Copy is made for fast lookup in main logic using just key value pairs
-- internal_id: made up to match my localization key style
-- values: The actual wwise events
-- ----------------------------------------------------
local sounds_to_toggle = {
	-- --------------------------
    -- Force Staff 
	-- --------------------------
    -- left click
	{
        internal_id = "forcestaff_primary_fire",
        sound_event = "wwise/events/weapon/play_explosion_force_sml",
    },
    -- Bowling balls p4
    --  catches itself and husk
	{
        internal_id = "forcestaff_secondary_fire_explosion",
        sound_event = "wwise/events/weapon/play_explosion_force_med*",
        do_not_disable_by_default = true,
    },
	-- --------------------------
    -- Lasbeam Crack
	-- --------------------------
    {
        internal_id = "lasbeam_crack_player",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_nearby",
    },
    {
        internal_id = "lasbeam_crack_enemy_captain",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_imperial_guards",
    },
    {
        internal_id = "lasbeam_crack_enemy",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_nearby_husk",
    },
	-- --------------------------
    -- Lightning Sounds
	-- --------------------------
    {
        -- "play" and "stop"
        internal_id = "lightning_attack_hit",
        sound_event = "wwise/events/weapon/*_psyker_chain_lightning_hit",
        do_not_disable_by_default = true,
    },
	-- --------------------------
    -- Shock Maul Swings
	-- --------------------------
    {
        -- Includes the "_heavy" event too
        internal_id = "adamant_maul_swing",
        sound_event = "wwise/events/weapon/play_shockmaul_1h_p2_swing*",
    },
    {
        -- Includes the "_heavy" event too
        internal_id = "shock_maul_hit",
        sound_event = "wwise/events/weapon/play_powermaul_1h_hit",
        do_not_disable_by_default = true,
    },
	-- --------------------------
    -- NPC UI Sounds
	-- --------------------------
    {
        internal_id = "penance_reward_claim",
        sound_event = "wwise/events/ui/play_ui_penances.*claim",
    },
    {
        internal_id = "npc_menu_enter",
        sound_event = "wwise/events/ui/play_ui_npc.*enter",
    },
    --[[
    {
        internal_id = "crafting_interact_forge_button",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_button_fx",
    },
    ]]
    {
        internal_id = "crafting_interact_traits",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_.*_trait.*",
    },
    {
        internal_id = "crafting_interact_perk_reroll",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_reroll_perk",
    },
    {
        internal_id = "crafting_interact_upgrade",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_upgrade_item",
    },
    {
        internal_id = "crafting_interact_empower",
        sound_event = "wwise/events/ui/play_ui_empower_weapon.*", -- also has max
    },
	-- --------------------------
    -- Player Pox Gas Coughs
	-- --------------------------
    {
        internal_id = "player_gas_cough",
        -- sfx on "enter" and "exit"
        --sound_event = "wwise/events/player/play_player_gas.*",
        -- Voice coughing for all 
        sound_event = "wwise/events/player/play_.*vce_coughing.*",
    },
	-- --------------------------
    -- Melee hits
	-- --------------------------
    -- -------------
    -- Against Armor
    -- -------------
	{
        internal_id = "melee_hits_super_armor_no_damage_melee_slashing",
        sound_event = "wwise/events/weapon/play_hit_indicator_melee_slashing_super_armor_no_damage",
    },
    {
        internal_id = "melee_hits_super_armor_no_damage_melee",
        sound_event = "wwise/events/weapon/play_hit_indicator_melee_super_armor_no_damage",
    },
    {
        internal_id = "melee_hits_res_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_reduced_damage", -- for some reason these have no play_
    },
    {
        internal_id = "melee_hits_shield_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_shield", -- for some reason these have no play_
    },
    {
        internal_id = "melee_hits_no_damage_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_no_damage", -- for some reason these have no play_
    },
    {
        internal_id = "melee_hits_no_damage_sword",
        sound_event = "wwise/events/weapon/melee_hits_sword_no_damage", -- for some reason these have no play_
    },
    {
        internal_id = "melee_hits_armor_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_armor",
    },
    {
        -- accounting for play_ and no play
        internal_id = "melee_hits_armor_blunt",
        sound_event = "wwise/events/weapon/*melee_hits_blunt_armor",
    },
    {
        internal_id = "melee_hits_armor_sword",
        sound_event = "wwise/events/weapon/play_melee_hits_sword_armor",
    },
    {
        internal_id = "melee_hits_armor_knife",
        sound_event = "wwise/events/weapon/play_melee_hits_knife_armor",
    },
    -- -------------
    -- Reduced Damage
    -- -------------
    {
        internal_id = "melee_hits_res_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_res",
    },
    -- -------------
    -- Light Attacks
    -- -------------
    {
        internal_id = "melee_hits_light_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_light",
        do_not_disable_by_default = true,
    },
    -- -------------
    -- Heavy Attacks
    -- -------------
    {
        internal_id = "melee_hits_heavy_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_heavy",
        do_not_disable_by_default = true,
    },
    {
        internal_id = "melee_hits_heavy_blunt",
        sound_event = "wwise/events/weapon/*melee_hits_blunt_heavy",
        do_not_disable_by_default = true,
    },
	-- --------------------------
    -- Ranged damage
	-- --------------------------
    -- -------------
    -- Negated
    -- -------------
    {
        internal_id = "ranged_hits_no_damage_gen",
        sound_event = "wwise/events/weapon/play_bullet_hits_gen_damage_negated",
    },
    {
        internal_id = "ranged_hits_no_damage_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_damage_negated",
    },
    -- -------------
    -- Armored
    -- Regex match for armored, armored_reduced, etc
    -- -------------
    {
        internal_id = "ranged_hits_armored_gen",
        sound_event = "wwise/events/weapon/play_bullet_hits_gen_armored.*",
    },
    {
        internal_id = "ranged_hits_armored_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_armored.*",
    },
    -- -------------
    -- Unarmored
    -- -------------
    {
        internal_id = "ranged_hits_unarmored_gen",
        sound_event = "wwise/events/weapon/play_bullet_hits_gen_unarmored.*",
        do_not_disable_by_default = true,
    },
    {
        internal_id = "ranged_hits_unarmored_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_unarmored.*",
        do_not_disable_by_default = true,
    },
}

mod.sounds_to_toggle = sounds_to_toggle

-- ----------------------------------------------------
-- Making Lookup Table for Easier Searching
-- Mainly for fast lookup when changing a specific sound based on mod option
--  When order doesn't matter
--  When you just need the key value pair
-- ----------------------------------------------------
local sound_lookup_copy = Script.new_map( #sounds_to_toggle )
for _, sound_table in ipairs(sounds_to_toggle) do
    sound_lookup_copy[sound_table.internal_id] = sound_table.sound_event
end
mod.sound_lookup_copy = sound_lookup_copy