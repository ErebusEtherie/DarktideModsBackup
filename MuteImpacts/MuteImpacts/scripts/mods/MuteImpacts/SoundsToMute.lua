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
    -- Psyker
	-- --------------------------
	-- -------------
    -- Force Staff
	-- -------------
    -- left click
	{
        internal_id = "forcestaff_primary_fire",
        sound_event = "wwise/events/weapon/play_explosion_force_sml",
        group_name = "mod_option_group_psyker_staff",
    },
    -- The projectile woooosh from left click
    {
        internal_id = "forcestaff_primary_fire_woosh",
        sound_event = "wwise/events/weapon/play_psyker_smite_fire$",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
    -- The little *ttzzzz* in the projectile trail
    {
        internal_id = "forcestaff_primary_fire_woosh_projectile",
        sound_event = "wwise/events/weapon/play_psyker_smite_fire_projectile*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
    -- Foot blasts p1 and Bowling balls p4
    --  catches itself and husk
	{
        internal_id = "forcestaff_secondary_fire_explosion",
        sound_event = "wwise/events/weapon/play_explosion_force_med*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
    -- Purgatus left click
    --  It has the sound in play and stop
	{
        internal_id = "forcestaff_flames_primary_fire_play",
        sound_event = "wwise/events/weapon/play_forcestaff_warp_fire_loop_3d.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
	{
        internal_id = "forcestaff_flames_primary_fire_stop",
        sound_event = "wwise/events/weapon/stop_forcestaff_warp_fire_loop_3d.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
    -- Purgatus right click
    --  main sound is play_forcestaff_warp_fire_loop_3d
	{
        internal_id = "forcestaff_flames_secondary_fire",
        sound_event = "wwise/events/weapon/play_forcestaff_warp_fire$",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_staff",
    },
	-- -------------
    -- Other
	-- -------------
    -- Warning Warp (50%)
    {
        internal_id = "warp_peril_warning",
        sound_event = "wwise/events/player/play_warp_charge_build_up_warning",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_misc",
    },
    -- Critical Warp (97%)
    {
        internal_id = "warp_peril_critical",
        sound_event = "wwise/events/player/play_warp_charge_build_up_critical",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_misc",
    },
    -- Force Sword Blocking and Brain Burst tzzztztztzzz
	{
        internal_id = "psyker_smite_charge",
        sound_event = "wwise/events/weapon/play_psyker_smite_charge",
        -- do_not_disable_by_default = true,
        group_name = "mod_option_group_psyker_misc",
    },
	-- --------------------------
    -- Skitussy
	-- --------------------------
	{
        internal_id = "skitussy_skull_charge",
        sound_event = "wwise/events/weapon/play_servoskull_weapon_lasgun_charge",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
	{
        internal_id = "skitussy_skull_fire",
        sound_event = "wwise/events/weapon/play_servoskull_weapon_lasgun_fire",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
    -- Ability use FFFPSFPS
	{
        internal_id = "skitussy_discharge",
        sound_event = "wwise/events/player/play_player_ability_discharge",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
    -- Voltaic Discharge bzzzzt with 2+ capacitance
	{
        internal_id = "skitussy_voltaic_loop_start",
        sound_event = "wwise/events/player/play_ability_cryptic_voltaic_buff_loop",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
	{
        internal_id = "skitussy_voltaic_loop_stop",
        sound_event = "wwise/events/player/stop_ability_cryptic_voltaic_buff_loop",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
    -- Integrated Refractor Field
    --  Gets play and stop
    --  If you only turn off the stop, it'll play endlessly even after ending, until it hears the actual stop event
    --  If you only turn off the play, it'll just play the stop sound
	{
        internal_id = "skitussy_bubble_wrap_start",
        sound_event = "wwise/events/player/play_ability_active_cryptic_forcefield",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
	{
        internal_id = "skitussy_bubble_wrap_stop",
        sound_event = "wwise/events/player/stop_ability_active_cryptic_forcefield",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_skitussy",
    },
	-- --------------------------
    -- Dog
	-- --------------------------
	{
        internal_id = "adamant_dog_footstep",
        sound_event = "wwise/events/player/play_npc_dog_footstep.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "adamant_dog_scuff",
        sound_event = "wwise/events/player/play_npc_dog_scuff.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "adamant_dog_attack",
        sound_event = "wwise/events/player/play_adamant_dog_vce_attack.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "adamant_dog_bark",
        sound_event = "wwise/events/player/play_adamant_dog_vce_bark.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "adamant_dog_bite",
        sound_event = "wwise/events/weapon/play_companion_bite.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "hound_breathe",
        sound_event = "wwise/events/minions/play_.*_hound.*vce_breath",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "hound_bark",
        sound_event = "wwise/events/minions/play_.*_hound.*vce_bark",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "hound_growl",
        sound_event = "wwise/events/minions/play_.*_hound.*vce_growl",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "hound_footstep",
        sound_event = "wwise/events/minions/play_.*_hound.*step",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "enemy_hound_wave_stinger",
        sound_event = "wwise/events/minions/play_chaos_hound_spawn_stinger_circumstance",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	{
        internal_id = "enemy_hound_group",
        sound_event = "wwise/events/minions/.*_chaos_hound_group_sound",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_dog",
    },
	-- --------------------------
    -- Lasbeam Crack
    -- and other nearby shots (I'm keeping the name for legacy setting conservation)
	-- --------------------------
    {
        internal_id = "lasbeam_crack_player",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_nearby",
        group_name = "mod_option_group_lasbeam_crack",
    },
    {
        internal_id = "lasbeam_crack_enemy_captain",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_imperial_guards",
        group_name = "mod_option_group_lasbeam_crack",
    },
    {
        internal_id = "lasbeam_crack_enemy",
        sound_event = "wwise/events/weapon/play_weapon_lasgun_crack_beam_nearby_husk",
        group_name = "mod_option_group_lasbeam_crack",
    },
    {
        internal_id = "bolter_flyby",
        sound_event = "wwise/events/weapon/play_shared_combat_weapon_bolter_bullet_flyby",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_lasbeam_crack",
    },
    -- Also used by skitarii weapons
    {
        internal_id = "plasma_flyby",
        sound_event = "wwise/events/weapon/play_shared_combat_weapon_plasma_flyby",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_lasbeam_crack",
    },
	-- --------------------------
    -- Lightning Sounds
	-- --------------------------
    {
        -- "play" and "stop"
        internal_id = "lightning_attack_hit",
        sound_event = "wwise/events/weapon/*_psyker_chain_lightning_hit",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_electrocution",
    },
	-- --------------------------
    -- Shock Maul Swings
	-- --------------------------
    {
        -- Includes the "_heavy" event too
        internal_id = "adamant_maul_swing",
        sound_event = "wwise/events/weapon/play_shockmaul_1h_p2_swing*",
        group_name = "mod_option_group_electrocution",
    },
    {
        -- Includes the "_heavy" event too
        internal_id = "shock_maul_hit",
        sound_event = "wwise/events/weapon/play_powermaul_1h_hit",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_electrocution",
    },
	-- --------------------------
    -- NPC UI Sounds
	-- --------------------------
    {
        internal_id = "penance_reward_claim",
        sound_event = "wwise/events/ui/play_ui_penances.*claim",
        group_name = "mod_option_group_npc_shop_ui",
    },
    {
        internal_id = "npc_menu_enter",
        sound_event = "wwise/events/ui/play_ui_npc.*enter",
        group_name = "mod_option_group_npc_shop_ui",
    },
    --[[
    {
        internal_id = "crafting_interact_forge_button",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_button_fx",
        group_name = "mod_option_group_npc_shop_ui",
    },
    ]]
    {
        internal_id = "crafting_interact_traits",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_.*_trait.*",
        group_name = "mod_option_group_npc_shop_ui",
    },
    {
        internal_id = "crafting_interact_perk_reroll",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_reroll_perk",
        group_name = "mod_option_group_npc_shop_ui",
    },
    {
        internal_id = "crafting_interact_upgrade",
        sound_event = "wwise/events/ui/play_ui_npc_interacts_forge_upgrade_item",
        group_name = "mod_option_group_npc_shop_ui",
    },
    {
        internal_id = "crafting_interact_empower",
        sound_event = "wwise/events/ui/play_ui_empower_weapon.*", -- also has max
        group_name = "mod_option_group_npc_shop_ui",
    },
	-- --------------------------
    -- Player Voice
	-- --------------------------
    -- Pox Gas Coughs
    {
        internal_id = "player_gas_cough",
        -- sfx on "enter" and "exit"
        --sound_event = "wwise/events/player/play_player_gas.*",
        -- Voice coughing for all 
        sound_event = "wwise/events/player/play_.*vce_coughing.*",
        group_name = "mod_option_group_player_voice",
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
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_super_armor_no_damage_melee",
        sound_event = "wwise/events/weapon/play_hit_indicator_melee_super_armor_no_damage",
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_res_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_reduced_damage", -- for some reason these have no play_
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_shield_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_shield", -- for some reason these have no play_
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_no_damage_blunt",
        sound_event = "wwise/events/weapon/melee_hits_blunt_no_damage", -- for some reason these have no play_
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_no_damage_sword",
        sound_event = "wwise/events/weapon/melee_hits_sword_no_damage", -- for some reason these have no play_
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_armor_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_armor",
        group_name = "mod_option_group_melee_hits",
    },
    {
        -- accounting for play_ and no play
        internal_id = "melee_hits_armor_blunt",
        sound_event = "wwise/events/weapon/*melee_hits_blunt_armor",
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_armor_sword",
        sound_event = "wwise/events/weapon/play_melee_hits_sword_armor",
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_armor_knife",
        sound_event = "wwise/events/weapon/play_melee_hits_knife_armor",
        group_name = "mod_option_group_melee_hits",
    },
    -- -------------
    -- Reduced Damage
    -- -------------
    {
        internal_id = "melee_hits_res_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_res",
        group_name = "mod_option_group_melee_hits",
    },
    -- -------------
    -- Light Attacks
    -- -------------
    {
        internal_id = "melee_hits_light_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_light",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_melee_hits",
    },
    -- -------------
    -- Heavy Attacks
    -- -------------
    {
        internal_id = "melee_hits_heavy_axe",
        sound_event = "wwise/events/weapon/play_melee_hits_axe_heavy",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_melee_hits",
    },
    {
        internal_id = "melee_hits_heavy_blunt",
        sound_event = "wwise/events/weapon/*melee_hits_blunt_heavy",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_melee_hits",
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
        group_name = "mod_option_group_ranged_hits",
    },
    {
        internal_id = "ranged_hits_no_damage_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_damage_negated",
        group_name = "mod_option_group_ranged_hits",
    },
    -- -------------
    -- Armored
    -- Regex match for armored, armored_reduced, etc
    -- -------------
    {
        internal_id = "ranged_hits_armored_gen",
        sound_event = "wwise/events/weapon/play_bullet_hits_gen_armored.*",
        group_name = "mod_option_group_ranged_hits",
    },
    {
        internal_id = "ranged_hits_armored_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_armored.*",
        group_name = "mod_option_group_ranged_hits",
    },
    -- -------------
    -- Unarmored
    -- -------------
    {
        internal_id = "ranged_hits_unarmored_gen",
        sound_event = "wwise/events/weapon/play_bullet_hits_gen_unarmored.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_ranged_hits",
    },
    {
        internal_id = "ranged_hits_unarmored_laser",
        sound_event = "wwise/events/weapon/play_bullet_hits_laser_unarmored.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_ranged_hits",
    },
	-- --------------------------
    -- Misc
	-- --------------------------
    -- UI click
    {
        internal_id = "ui_click",
        sound_event = "wwise/events/ui/play_ui_click$",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_misc",
    },
    -- EVERYTHING
    {
        internal_id = "anything_and_everything",
        sound_event = "wwise/events/.*",
        do_not_disable_by_default = true,
        group_name = "mod_option_group_misc",
    },
}

mod.sounds_to_toggle = sounds_to_toggle

-- ----------------------------------------------------
-- Making Lookup group_namele for Easier Searching
-- Mainly for fast lookup when changing a specific sound based on mod option
--  When order doesn't matter
--  When you just need the key value pair
-- ----------------------------------------------------
local sound_lookup_copy = Script.new_map( #sounds_to_toggle )
for i = 1, #sounds_to_toggle do
    local table_containing_sound = sounds_to_toggle[i]
    sound_lookup_copy[table_containing_sound.internal_id] = table_containing_sound.sound_event
end
mod.sound_lookup_copy = sound_lookup_copy