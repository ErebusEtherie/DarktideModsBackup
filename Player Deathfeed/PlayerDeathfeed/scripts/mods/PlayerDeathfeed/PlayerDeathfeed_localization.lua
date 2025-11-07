
local InputUtils = require("scripts/managers/input/input_utils")

local localizations = {
	mod_name = {
		en = "Player Deathfeed",
	},
	mod_description = {
		en = "Shows player downs and deaths in killfeed and/or popup notifications.",
	},
	killfeed = {
		en = "Killfeed Options:",
	},
	show_killfeed = {
		en = "Report in Killfeed",
	},
	report_down_feed = {
		en = "Report: Knockdowns",
	},
	report_death_feed = {
		en = "Report: Deaths",
	},
	show_type_feed = {
		en = "Show: Attack Information",
	},
	show_damage_feed = {
		en = "Show: Damage Amount",
	},
	notification = {
		en = "Notification Options:",
	},
	show_notification = {
		en = "Report in Notifications",
	},
	report_down_notification = {
		en = "Report: Knockdowns",
	},
	dead_color = {
		en = "Background Color: Death",
	},
	knock_color = {
		en = "Background Color: Knock Down",
	},
	report_death_notification = {
		en = "Report: Deaths",
	},
	show_type_note = {
		en = "Show Attack Information",
	},
	show_damage_note = {
		en = "Show Damage Amount",
	},
	show_disabled_note = {
		en = "Show Disabled State",
	},
	note_time = {
		en = "Notification Display Duration (sec)",
	},
	detailed_notification = {
		en = "Detailed Report",
	},
	detailed_description = {
		en = "On: Shows all damge taken during the reporting period.\nOff: Shows only the killing blow.",
	},
	damage_window = {
		en = "Detailed Report Recording Period (sec)",
	},
	echo = {
		en = "Echo",
	},
	echo_feed = {
		en = "Echo Killfeed in Private Chat",
	},
	echo_note = {
		en = "Echo Notification in Private Chat",
	},
	
	-- Missing monster Locs
	loc_breed_display_name_chaos_lesser_mutated_poxwalker = {
		en = "Lesser Mutated Poxwalker",
	},
	loc_breed_display_name_chaos_mutated_poxwalker = {
		en = "Mutated Poxwalker",
	},
	
	-- Missing Disabled Locs maybe?
	--Damge Profile Names
	flamer_backpack_explosion_close = {
		en = "Backpack Explosion",
	},
	flamer_backpack_explosion = {
		en = "Backpack Explosion",
	},
	barrel_explosion_close = {
		en = "Barrel",
	},
	barrel_explosion = {
		en = "Barrel",
	},
	liquid_area_fire_burning = {
		en = "Fire",
	},
	liquid_area_fire_burning = {
		en = "Fire",
	},
	liquid_area_fire_burning_barrel = {
		en = "Barrel Fire",
	},
	flame_grenade_liquid_area_fire_burning = {
		en = "Fire",
	},
	grenadier_liquid_fire_burning = {
		en = "Fire",
	},
	cultist_flamer_liquid_fire_burning = {
		en = "Fire",
	},
	renegade_flamer_liquid_fire_burning = {
		en = "Fire",
	},
--	burning = {
--		en = "Fire",
--	},
	corruptor_liquid_corruption = {
		en = "Corruption Liquid",
	},
--	warpfire = {
--		en = " ",
--	},
	protectorate_force_field = {
		en = " ",
	},
	killing_blow = {
		en = " ",
	},
	trait_powersword_2h_p1_trade_overheat_lockout_for_damage = {
		en = " ",
	},
	plasma_overheat = {
		en = " ",
	},
	knocked_down_tick = {
		en = "Bleeding Out",
	},
	netted_tick = {
		en = "Netted",
	},
	grimoire_tick = {
		en = "Grimoire",
	},
	overheat_exploding_tick = {
		en = "Plasma Overheat",
	},
	warp_charge_exploding_tick = {
		en = "Perils of the Warp",
	},
	falling_light = {
		en = "Short Fall",
	},
	falling_heavy = {
		en = "Long Fall",
	},
	kill_volume_and_off_navmesh = {
		en = "Yeeted",
	},
	kill_volume_with_gibbing = {
		en = " ",
	},
	poxwalker = {
		en = "Basic Melee",
	},
	mutated_poxwalker = {
		en = "Basic Melee",
	},
	lesser_mutated_poxwalker = {
		en = "Basic Melee",
	},
	melee_fighter_default = {
		en = "Basic Melee",
	},
	melee_bruiser_default = {
		en = "Basic Melee",
	},
	horde_melee_default = {
		en = "Basic Melee",
	},
	melee_berzerker_combo = {
		en = "Melee Combo",
	},
	renegade_captain_melee_default = {
		en = "Basic Melee",
	},
	renegade_captain_power_sword_melee_sweep = {
		en = "Sweep",
	},
	renegade_captain_powermaul_ground_slam = {
		en = "Ground Slam",
	},
	renegade_captain_powermaul_melee_cleave = {
		en = "Cleave",
	},
	renegade_captain_charge = {
		en = "Charge",
	},
	twin_dash = {
		en = "Dash",
	},
	twin_dash_light = {
		en = "Light Dash",
	},
	renegade_captain_minion_charge_push = {
		en = "Charge Push",
	},
	melee_roamer_default = {
		en = "Basic Melee",
	},
	chaos_spawn_combo = {
		en = "Melee Combo",
	},
	chaos_spawn_combo_heavy = {
		en = "Heavy Melee Combo",
	},
	monster_slam = {
		en = "Slam",
	},
	chaos_spawn_claw = {
		en = "Claw",
	},
	chaos_plague_ogryn_scythe = {
		en = "Scythe",
	},
	chaos_plague_ogryn_catapult = {
		en = "Catapult",
	},
	chaos_spawn_grab_smash = {
		en = "Grab Smash",
	},
	chaos_plague_ogryn_charge = {
		en = "Charge",
	},
	chaos_plague_ogryn_minion_charge_push = {
		en = " ",
	},
	chaos_plague_ogryn_plague_stomp = {
		en = "Plague Stomp",
	},
	renegade_captain_punch = {
		en = "Punch",
	},
	renegade_captain_kick = {
		en = "Kick",
	},
	renegade_captain_bolt_pistol = {
		en = "Bolt Pistol",
	},
	renegade_captain_bolt_pistol_kill_explosion = {
		en = "Bolt Pistol Explosion",
	},
	renegade_captain_bolt_pistol_stop_explosion = {
		en = "Bolt Pistol Explosion",
	},
	renegade_captain_plasma_pistol = {
		en = "Plasma Pistol",
	},
	renegade_captain_void_shield_explosion = {
		en = "Void Shield Explosion",
	},
	minion_instakill = {
		en = "Insta Gib",
	},
	renegade_grenadier_fire_grenade_impact_close = {
		en = "Grenade Impact",
	},
	renegade_grenadier_fire_grenade_impact = {
		en = "Grenade Impact",
	},
	renegade_grenadier_grenade_blunt = {
		en = "Grenade Impact",
	},
	poxwalker_explosion = {
		en = "Pox Explosion",
	},
	poxwalker_explosion_close = {
		en = "Pox Explosion",
	},
	default_rifleman = {
		en = "Basic Melee?",
	},
	renegade_rifleman = {
		en = "Basic Melee?",
	},
	renegade_rifleman_single_shot = {
		en = "Single Shot",
	},
	assaulter_auto_burst = {
		en = "Auto Burst",
	},
	assaulter_las_burst = {
		en = "Las Burst",
	},
	shocktrooper_shotgun = {
		en = "Shotgun",
	},
	sniper_bullet = {
		en = "Sniper Bullet",
	},
	gunner_aimed = {
		en = "Aimed Shot",
	},
	gunner_spray_n_pray = {
		en = "Spray and Pray",
	},
	gunner_sweep = {
		en = "Sweep",
	},
	renegade_captain_spray = {
		en = "Spray",
	},
	renegade_captain_shotgun = {
		en = "Shotgun",
	},
	renegade_captain_frag_grenade_close = {
		en = "Frag Grenade",
	},
	renegade_captain_frag_grenade = {
		en = "Frag Grenade",
	},
	renegade_shocktrooper_frag_grenade_close = {
		en = "Frag Grenade",
	},
	renegade_shocktrooper_frag_grenade = {
		en = "Frag Grenade",
	},
	chaos_hound_pounce = {
		en = "Pounce",
	},
	chaos_hound_initial_pounce = {
		en = "Pounce Impact",
	},
	daemonhost_grab = {
		en = "Soul Grab",
	},
	melee_executor_cleave = {
		en = "Overhead Slam",
	},
	melee_executor_default = {
		en = "Basic Melee",
	},
	chaos_ogryn_executor_default = {
		en = "Basic Melee",
	},
	chaos_ogryn_executor_push = {
		en = "Push",
	},
	chaos_ogryn_executor_pommel = {
		en = "Pommel",
	},
	chaos_ogryn_executor_punch = {
		en = "Punch",
	},
	chaos_ogryn_executor_kick = {
		en = "Kick",
	},
	chaos_ogryn_executor_cleave = {
		en = "Overhead Slam",
	},
	daemonhost_melee = {
		en = "Basic Melee",
	},
	daemonhost_offtarget_melee = {
		en = "Offtarget Melee",
	},
	daemonhost_melee_combo = {
		en = "Melee Combo",
	},
	daemonhost_warp_sweep = {
		en = "Warp Sweep",
	},
	bulwark_shield_push = {
		en = "Shield Push",
	},
	bulwark_melee = {
		en = "Basic Melee",
	},
	chaos_ogryn_gunner_bullet = {
		en = "Gunner Bullet",
	},
	cultist_flamer_impact = {
		en = "Flame Impact",
	},
	renegade_flamer_impact = {
		en = "Flame Impact",
	},
	horde_flame_impact = {
		en = "Flame Impact",
	},
	cultist_mutant_minion_charge_push = {
		en = " ",
	},
	chaos_hound_push = {
		en = "Push",
	},
	chaos_ogryn_gunner_melee = {
		en = "Basic Melee",
	},
	cultist_mutant_smash = {
		en = "Smash",
	},
	renegade_captain_toughness_depleted = {
		en = " ",
	},
	renegade_captain_offtarget_melee = {
		en = "Offtarget Melee",
	},
	mutator_green_corruption = {
		en = "Corruption",
	},
	mutator_corruption = {
		en = "Corruption",
	},
	mutator_gas_normal_damage = {
		en = "Pox Gas",
	},
	beast_of_nurgle_slime_liquid = {
		en = "Nurgle Slime",
	},
	beast_of_nurgle_hit_by_vomit = {
		en = "Nurgle Vomit",
	},
	beast_of_nurgle_tail_whip = {
		en = "Tail Whip",
	},
	beast_of_nurgle_melee_friendly_fire = {
		en = "Nurfle Friendly Fire ",
	},
	beast_of_nurgle_self_gib = {
		en = "Self Gib ",
	},
	havoc_self_gib = {
		en = "Self Gib ",
	},
	flamer_implosion = {
		en = "Flamer Implosion",
	},
	toxic_gas_mutator = {
		en = "Tox Gas",
	},
	cultist_grenadier_gas = {
		en = "Grenade Gas",
	},
	toxic_gas = {
		en = "Tox Gas",
	},
	twin_grenade_explosion = {
		en = "Grenade",
	},
	twin_captain_two_aoe_sweep = {
		en = "Sweep",
	},
	twin_captain_two_melee_default = {
		en = "Basic Melee",
	},
	forcesword_explosion = {
		en = "Forcesword Explosion",
	},
	forcesword_explosion_outer = {
		en = "Forcesword Explosion",
	},
}

local function readable(text)
    local readable_string = ""
    local tokens = string.split(text, "_")
    for i, token in ipairs(tokens) do
        local first_letter = string.sub(token, 1, 1)
        token = string.format("%s%s", string.upper(first_letter), string.sub(token, 2))
        readable_string = string.trim(string.format("%s %s", readable_string, token))
    end

    return readable_string
end

local color_names = Color.list
for i, color_name in ipairs(color_names) do
	local color_values = Color[color_name](100, true)
	local text = InputUtils.apply_color_to_input_text(readable(color_name), color_values)
	localizations[color_name] = {
		en = text
	}
end

return localizations