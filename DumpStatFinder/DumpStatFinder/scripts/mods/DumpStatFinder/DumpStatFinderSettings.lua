local dump_stat_display_name_list = {
	"grenadier_gauntlets/loc_glossary_term_melee_damage",
	"loc_stats_display_vent_speed",
	"force_staffs/loc_stats_display_warp_resist_stat",
	"loc_stats_display_mobility_stat",
	"loc_stats_display_defense_stat",
	"combat_swords/loc_stats_display_defense_stat",
	"plasma_rifles/loc_stats_display_charge_speed",
	"plasma_rifles/loc_stats_display_ammo_stat",
	"ripperguns/loc_stats_display_control_stat_ranged",
	"ripperguns/loc_stats_display_ammo_stat",
	"ogryn_heavystubbers/loc_stats_display_control_stat_ranged",
	"power_swords/loc_stats_display_cleave_targets_stat",
	"lasguns/loc_stats_display_ammo_stat",
	"force_swords_2h/loc_stats_display_warp_resist_stat",
	"ogryn_heavystubbers_p2/loc_stats_display_control_stat_ranged",
	"ogryn_heavystubbers_p2/loc_stats_display_range_stat",
	"recon_lasguns/loc_stats_display_control_stat_ranged",
}

local dump_stat_filter_list = {
	{
		pattern = "grenadier_gauntlets",
		stat = "melee_damage",
	},
	{
		pattern = "*",
		stat = "mobility",
	},
	{
		pattern = "*",
		stat = "defense",
	},
	{
		pattern = "*",
		stat = "vent_speed",
	},
	{
		pattern = "plasma_rifles",
		stat = "charge_speed",
		min = 60,
		max = 62,
	},
	{
		pattern = "plasma_rifles",
		stat = "charge_speed",
		min = 69,
		max = 69,
		stat2 = "heat_management",
		min2 = 71,
		max2 = 71,
	},
	{
		pattern = "ripperguns",
		stat = "ranged_control",
	},
	{
		pattern = "ogryn_heavystubbers",
		stat = "ranged_control",
	},
	{
		pattern = "ogryn_heavystubbers",
		stat = "ranged_control",
	},
	{
		pattern = "power_swords",
		stat = "cleave_targets",
	},
}

local friendly_names = {
	["melee_damage"] = "loc_glossary_term_melee_damage",
	["vent_speed"] = "loc_stats_display_vent_speed",
	["mobility"] = "loc_stats_display_mobility_stat",
	["defense"] = "loc_stats_display_defense_stat",
	["charge_speed"] = "loc_stats_display_charge_speed",
	["ammo"] = "loc_stats_display_ammo_stat",
	["ranged_control"] = "loc_stats_display_control_stat_ranged",
	["stagger_ranged"] = "loc_stats_display_control_stat_ranged",
	["cleave_targets"] = "loc_stats_display_cleave_targets_stat",
	["cleave_damage"] = "loc_stats_display_cleave_damage_stat",
	["heat_management"] = "loc_stats_display_heat_management",
	["warp_resist"] = "loc_stats_display_warp_resist_stat",
	["power"] = "loc_stats_display_power_stat",
}

local weapon_groups = {
	chain_swords = {
		"chainsword_p1_m1",
		"chainsword_p1_m2",
		"chainsword_2h_p1_m1",
		"chainsword_2h_p1_m2",
	},
	chain_swords_1h = {
		"chainsword_p1_m1",
		"chainsword_p1_m2",
	},
	eviscerators = {
		"chainsword_2h_p1_m1",
		"chainsword_2h_p1_m2",
	},

	chain_axes = {
		"chainaxe_p1_m1",
		"chainaxe_p1_m2",
	},
	combat_axes = {
		"combataxe_p1_m1",
		"combataxe_p1_m2",
		"combataxe_p1_m3",
		"combataxe_p2_m1",
		"combataxe_p2_m2",
		"combataxe_p2_m3",
		"combataxe_p3_m1",
		"combataxe_p3_m2",
		"combataxe_p3_m3",
	},
	combat_blades = {
		"ogryn_combatblade_p1_m1",
		"ogryn_combatblade_p1_m2",
		"ogryn_combatblade_p1_m3",
	},
	combat_knives = {
		"combatknife_p1_m1",
		"combatknife_p1_m2",
	},
	combat_swords = {
		"combatsword_p1_m1",
		"combatsword_p1_m2",
		"combatsword_p1_m3",
		"combatsword_p2_m1",
		"combatsword_p2_m2",
		"combatsword_p2_m3",
		"combatsword_p3_m1",
		"combatsword_p3_m2",
		"combatsword_p3_m3",
	},
	force_swords = {
		"forcesword_p1_m1",
		"forcesword_p1_m2",
		"forcesword_p1_m3",
	},
	force_swords_2h = {
		"forcesword_2h_p1_m1",
		"forcesword_2h_p1_m2",
		"forcesword_2h_p1_m3",
	},

	ogryn_clubs = {
		"ogryn_club_p1_m1",
		"ogryn_club_p1_m2",
		"ogryn_club_p1_m3",
		"ogryn_club_p2_m1",
		"ogryn_club_p2_m2",
		"ogryn_club_p2_m3",
	},

	ogryn_power_mauls = {
		"ogryn_powermaul_p1_m1",
		"ogryn_powermaul_p1_m2",
		"ogryn_powermaul_p1_m3",
	},
	ogryn_powermaul_slabshield = {
		"ogryn_powermaul_slabshield_p1_m1",
	},
	ogryn_axes_2h = {
		"ogryn_pickaxe_2h_p1_m1",
		"ogryn_pickaxe_2h_p1_m2",
		"ogryn_pickaxe_2h_p1_m3",
	},
	power_mauls = {
		"powermaul_p1_m1",
		"powermaul_p1_m2",
	},
	power_mauls_2h = {
		"powermaul_2h_p1_m1",
	},
	power_swords = {
		"powersword_p1_m1",
		"powersword_p1_m2",
	},
	power_swords_2h = {
		"powersword_2h_p1_m1",
		"powersword_2h_p1_m2",
		"powersword_2h_p1_m3",
	},

	thunder_hammers = {
		"thunderhammer_2h_p1_m1",
		"thunderhammer_2h_p1_m2",
	},
	autoguns = {
		"autogun_p1_m1",
		"autogun_p1_m2",
		"autogun_p1_m3",
		"autogun_p2_m1",
		"autogun_p2_m2",
		"autogun_p2_m3",
		"autogun_p3_m1",
		"autogun_p3_m2",
		"autogun_p3_m3",
	},
	infantry_autoguns = {
		"autogun_p1_m1",
		"autogun_p1_m2",
		"autogun_p1_m3",
	},
	vigilant_autoguns = {
		"autogun_p3_m1",
		"autogun_p3_m2",
		"autogun_p3_m3",
	},
	braced_autoguns = {
		"autogun_p2_m1",
		"autogun_p2_m2",
		"autogun_p2_m3",
	},

	autopistols = {
		"autopistol_p1_m1",
	},
	bolters = {
		"bolter_p1_m1",
	},
	bolt_pistols = {
		"boltpistol_p1_m1",
	},
	flamers = {
		"flamer_p1_m1",
	},

	force_staffs = {
		"forcestaff_p1_m1",
		"forcestaff_p2_m1",
		"forcestaff_p3_m1",
		"forcestaff_p4_m1",
	},
	grenadier_gauntlets = {
		"ogryn_gauntlet_p1_m1",
	},
	lasguns = {
		"lasgun_p1_m1",
		"lasgun_p1_m2",
		"lasgun_p1_m3",
		"lasgun_p2_m1",
		"lasgun_p2_m2",
		"lasgun_p2_m3",
		"lasgun_p3_m1",
		"lasgun_p3_m2",
		"lasgun_p3_m3",
	},
	infantry_lasguns = {
		"lasgun_p1_m1",
		"lasgun_p1_m2",
		"lasgun_p1_m3",
	},
	helbore_lasguns = {
		"lasgun_p2_m1",
		"lasgun_p2_m2",
		"lasgun_p2_m3",
	},
	recon_lasguns = {
		"lasgun_p3_m1",
		"lasgun_p3_m2",
		"lasgun_p3_m3",
	},
	laspistols = {
		"laspistol_p1_m1",
		"laspistol_p1_m3",
	},
	ogryn_heavystubbers = {
		"ogryn_heavystubber_p1_m1",
		"ogryn_heavystubber_p1_m2",
		"ogryn_heavystubber_p1_m3",

		"ogryn_heavystubber_p2_m1",
		"ogryn_heavystubber_p2_m2",
		"ogryn_heavystubber_p2_m3",
	},
	ogryn_heavystubbers_p2 = {

		"ogryn_heavystubber_p2_m1",
		"ogryn_heavystubber_p2_m2",
		"ogryn_heavystubber_p2_m3",
	},

	plasma_rifles = {
		"plasmagun_p1_m1",
	},
	ripperguns = {
		"ogryn_rippergun_p1_m1",
		"ogryn_rippergun_p1_m2",
		"ogryn_rippergun_p1_m3",
	},

	thumpers = {
		"ogryn_thumper_p1_m1",
		"ogryn_thumper_p1_m2",
	},
	shotguns = {
		"shotgun_p1_m1",
		"shotgun_p1_m2",
		"shotgun_p1_m3",
		"shotgun_p2_m1",
	},
	stub_pistols = {
		"stubrevolver_p1_m1",
		"stubrevolver_p1_m2",
	},
}
return {
	weapon_groups = weapon_groups,
	dump_stat_display_name_list = dump_stat_display_name_list,
}
