local mod = get_mod("MuteImpacts")

mod.sounds_to_toggle = {
	forcestaff_primary_fire = "wwise/events/weapon/play_explosion_force_sml",
	super_armor_no_damage_melee_slashing = "wwise/events/weapon/play_hit_indicator_melee_slashing_super_armor_no_damage",
    super_armor_no_damage_melee = "wwise/events/weapon/play_hit_indicator_melee_super_armor_no_damage",
    melee_hits_no_damage_blunt = "wwise/events/weapon/play_melee_hits_blunt_no_damage",
    melee_hits_no_damage_sword = "wwise/events/weapon/play_melee_hits_sword_no_damage",
    melee_hits_armor_axe = "wwise/events/weapon/play_melee_hits_axe_armor",
    melee_hits_armor_blunt = "wwise/events/weapon/play_melee_hits_blunt_armor",
    melee_hits_armor_sword = "wwise/events/weapon/play_melee_hits_sword_armor",
    melee_hits_armor_knife = "wwise/events/weapon/play_melee_hits_knife_armor",
    ranged_hits_no_damage_gen = "wwise/events/weapon/play_bullet_hits_gen_damage_negated",
    ranged_hits_no_damage_laser = "wwise/events/weapon/play_bullet_hits_laser_damage_negated",
}