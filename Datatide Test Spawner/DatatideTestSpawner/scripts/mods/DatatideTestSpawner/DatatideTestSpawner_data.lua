local mod = get_mod("DatatideTestSpawner")

local mod_data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
}

mod.Buff_Notes = ""
mod.Test_Results = {
	weapon_name = "",
	test_time = 0,
	enemy_type = "",
	class = "",
	key_talents = "",
	blessing_1 = "",
	blessing_2 = "",
	perk_1 = "",
	perk_2 = "",
	test_notes = "",
	attack_combo = "",
	damage_taken = 0,
	test_weapon_damage = 1,
	combat_ability_used = false,
	buffs_applied = false,
	difficulty = "",
	build_name = "",	
	user = "",
	patch = ""
}

mod.weapon_name_removed_strings = {

	["\"Devil's Claw\" Sword Catachan"] = "Devil's Claw",

	["Assault Chainaxe Orestes"] = "Chainaxe",

	["Assault Chainsword Cadia"] = "Chainsword",

	["Heavy Eviscerator Tigrus"] = "Eviscerator",

	["Blaze Force Greatsword Covenant"] = "Force Greatsword",

	["Blaze Force Sword Deimos Mk IV"] = "Deimos Force Sword",
	["Blaze Force Sword Illisi Mk V"] = "Illisi Force Sword",
	["Blaze Force Sword Obscurus Mk II"] = "Obscurus Force Sword",

	["Combat Axe Achlys Mk VIII"] = "Achlys Combat Axe",
	["Combat Axe Antax Mk V"] = "Antax Combat Axe",
	["Combat Axe Rashad Mk III"] = "Rashad Combat Axe",

	["Combat Blade Catachan"] = "Combat Blade",

	["Duelling Sword Maccabian"] = "Duelling Sword",

	["Heavy Sword Turtolsky"] = "Heavy Sword",

	["Shock Maul Agni Mk Ia"] = "Agni Shock Maul",
	["Shock Maul Munitorum Mk III"] = "Munitorum Shock Maul",

	["Tactical Axe Atrox"] = "Tac Axe",

	["Crusher Indignatus"] = "Crusher",

	["Relic Blade Munitorum"] = "Relic Blade",

	["Thunder Hammer Crucis Mk II"] = "Crucis Thunder Hammer",
	["Thunder Hammer Ironhelm Mk IV"] = "Ironhelm Thunder Hammer",
	--
	["Kickback Lorenz"] = "Kickback",
	["Rumbler Lorenz"] = "Rumbler",

	["Grenadier Gauntlet Blastoom"] = "Grenadier Gauntlet",

	["Ripper Gun Foe%-Rend"] = "Ripper Gun",

	["Heavy Stubber Krourk Mk IIa"] =  "Krourk Heavy Stubber",
	["Heavy Stubber Achlys Mk II"] = "Achlys Heavy Stubber",
	["Heavy Stubber Gorgonum Mk IIIa"] = "Gorgonum Heavy Stubber",

	["Twin%-Linked Heavy Stubber Gorgonum Mk IV"] = "Gorgonum Twin-Linked Stubber",
	["Twin%-Linked Heavy Stubber Achlys Mk VII"] = "Achlys Twin-Linked Stubber",
	["Twin%-Linked Heavy Stubber Krourk Mk V"] = "Krourk Twin-Linked Stubber",

	["Voidstrike Force Staff Equinox"] = "Voidstrike Staff",
	["Voidblast Force Staff Equinox"] = "Voidblast Staff",
	["Electrokinetic Force Staff Nomanus"] = "Electrokinetic Staff",
	["Inferno Force Staff Rifthaven"] = "Inferno Staff",

	["Vigilant Autogun Agripinaa Mk IX"] = "Agripinaa Vigilant Autogun",
	["Vigilant Autogun Graia Mk VII"] = "Graia Vigilant Autogun",
	["Vigilant Autogun Columnus Mk III"] = "Columnus Vigilant Autogun",

	["Bolt Pistol Godwyn%-Branx"] = "Bolt Pistol",
	["Spearhead Boltgun Locke"] = "Boltgun",

	["Braced Autogun Graia Mk IV"] = "Graia Braced Autogun",
	["Braced Autogun Agripinaa Mk VIII"] = "Agripinaa Braced Autogun",
	["Braced Autogun Vraks Mk II"] = "Vraks Braced Autogun",

	["Heavy Laspistol Accatran MG Mk II"] = "Accatran Laspistol",
	["Heavy Laspistol Kantrael Mk X"] = "Kantrael Laspistol",

	["Quickdraw Stub Revolver Agripinaa Mk XIV"] = "Agripinaa Revolver",
	["Quickdraw Stub Revolver Zarona Mk IIa"] = "Zarona Revolver",

	["Recon Lasgun Accatran"] = "Recon Lasgun",

	["Combat Shotgun Agripinaa Mk VII"] = "Agripinaa Combat Shotgun",
	["Combat Shotgun Accatran Mk IX"] = "Accatran Combat Shotgun",
	["Combat Shotgun Zarona Mk VI"] = "Zarona Combat Shotgun",

	["Double%-Barrelled Shotgun Crucis Mk XI"] = "Crucis Double%-Barrelled Shotgun",

	["Infantry Autogun Columnus Mk VIII"] = "Columnus Infantry Autogun",
	["Infantry Autogun Vraks Mk V"] = "Vraks Infantry Autogun",
	["Infantry Autogun Agripinaa Mk I"] = "Agripinaa Infantry Autogun",

	["Infantry Lasgun Kantrael"] = "Infantry Lasgun",

	["Purgation Flamer Artemia"] = "Flamer",

	["Shredder Autopistol Ius"] = "Shredder",

	["Power Sword Achlys Mk VI"] = "Achlys Power Sword",
	["Power Sword Scandar Mk III"] = "Scandar Power Sword",

	["Sapper Shovel Munitorum"] = "Sapper Shovel",

	["Plasma Gun M35 Magnacore"] = "Plasma Gun",

	["Helbore Lasgun Lucius"] = "Helbore",

	["Delver's Pickaxe Branx Mk Ia"] = "Branx Pickaxe",
	["Delver's Pickaxe Borovian Mk III"] = "Borovian Pickaxe",
	["Delver's Pickaxe Karsolas Mk II"] = "Karsolas Pickaxe",

	["Bully Club \"Brunt Special\""] = "Bully Club",
	["Bully Club \"Brunt's Basher\""] = "Bully Club",
	["Bully Club \"Brunt's Pride\""] = "Bully Club",

	["Battle Maul & Slab Shield Orox Mk II & Mk III"] = "Slab Shield Mk III",

	["Cleaver Krourk"] = "Krourk Cleaver",
	["Cleaver Bull Butcher Mk III"] = "Bull Butcher Cleaver",

	["Power Maul Achlys Mk I"] = "Achlys Power Maul",
	["Power Maul Ogrys Mk IIc"] = "Ogrys Power Maul",

	["Latrine Shovel Brute%-Brainer"] = "Latrine Shovel"
}
mod.Talents_Grenades = {
	["Stunstorm Grenade"] = "blitz_talent",
	["Immolation Grenade"] = "blitz_talent",
	["Blades of Faith"] = "blitz_talent",

	["Shredder Frag Grenade"] = "blitz_talent",
	["Krak Grenade"] = "blitz_talent",
	["Smoke Grenade"] = "blitz_talent",

	["Brain Rupture"] = "blitz_talent",
	["Smite"] = "blitz_talent",
	["Assail"] = "blitz_talent",

	["Bombs Away!"] = "blitz_talent", 
	["Big Friendly Rock"] = "blitz_talent",
	["Frag Bomb"] = "blitz_talent",

	["Stun Grenade"] = "base_talent",	
	["Frag Grenade"] = "base_talent",	
	["Brain Burst"] = "base_talent",
	["Big Box of Hurt"] = "base_talent"
}
mod.Talents_Combat_Abilitys = {
	["Fury of the Faithful"] = "Fotf",
	["Chorus of Spiritual Fortitude"] = "Chorus",
	["Shroudfield"] = "Shroud",

	["Executioner's Stance"] = "Ex Stance",
	["Voice of Command"] = "VoC",
	["Infiltrate"] = "Infl",

	["Venting Shriek"] = "Vent",
	["Telekine Shield"] = "Shield",
	["Scrier's Gaze"] = "Scrier's",
	["Psykinetic's Wrath"] = "Base Combat Ability",

	["Indomitable"] = "Indom", 
	["Loyal Protector"] = "Taunt",
	["Point-Blank Barrage"] = "Point-Blank"
}
mod.Talents_Keystones = {
	["Blazing Piety"] = "BP",
	["Martyrdom"] = "Marty",
	["Inexorable Judgement"] = "IJ",

	["Marksman's Focus"] = "Marksman's",
	["Focus Target!"] = "Mark",
	["Weapons Specialist"] = "WS",

	["Warp Siphon"] = "Warp Charge",
	["Empowered Psionics"] = "EP",
	["Disrupt Destiny"] = "DD",

	["Heavy Hitter"] = "HH",
	["Feel No Pain"] = "FnP",
	["Burst Limiter Override"] = "Lucky Bullet"
}

mod.Test_Names = {}
mod.Test_Data = {
	archivum_armoured_melee_elites = {
		test_data = {
			test_name = "Crushers & Maulers",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 8,
			group = {"DT_official", "Elites", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"renegade_executor",
			"renegade_executor",
			"renegade_executor",
			"renegade_executor",
			"chaos_ogryn_executor",
			"chaos_ogryn_executor",
			"chaos_ogryn_executor",
			"chaos_ogryn_executor"
		},
		enemy_XYZ = {
			{["x"] = -57.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -56.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -55.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -54.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -57.25, ["y"] = 101.25, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -56.25, ["y"] = 101.25, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -55.25, ["y"] = 101.25, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -54.25, ["y"] = 101.25, ["z"] = -0.40, ["rot"] = 180}
		}
	},
	archivum_rager_mixed = {
		test_data = {
			test_name = "Ragers & Bruisers",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 26,
			group = {"DT_official", "Elites", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",

			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",

			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",

			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",

			"cultist_berzerker",
			"cultist_berzerker",
			"cultist_berzerker",
			"cultist_berzerker",
			"cultist_berzerker",
			"cultist_berzerker"
		},
		enemy_XYZ = {
			{["x"] = -57.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00}
		}
	},
	archivum_renagade_rager_mixed = {
		test_data = {
			test_name = "Renagade Ragers & Bruisers",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 26,
			group = {"Elites", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",

			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",

			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",

			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",

			"renegade_berzerker",
			"renegade_berzerker",
			"renegade_berzerker",
			"renegade_berzerker",
			"renegade_berzerker",
			"renegade_berzerker"
		},
		enemy_XYZ = {
			{["x"] = -57.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.50, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.00, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 105.00, ["z"] = -0.40, ["rot"] = 180.00}
		}
	},
	archivum_large_horde = {
		test_data = {
			test_name = "Horde, Large",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 100,
			group = {"Horde", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",

			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",

			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",

			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker"
		},
		enemy_XYZ = {

			{["x"] = -57.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 104.20, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 104.90, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 105.60, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 106.30, ["z"] = -0.40, ["rot"] = 180.00},		
		}
	},
	archivum_large_mobian_horde = {
		test_data = {
			test_name = "Mobian Horde, Medium",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 75,
			group = {"DT_official", "Horde", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",

			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",

			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",

			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected",
			"chaos_armored_infected"
		},
		enemy_XYZ = {

			{["x"] = -57.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.7, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 101.4, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.1, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.8, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 103.5, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 104.2, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 104.9, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 105.6, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.75, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.75, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 106.3, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.92, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.58, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.25, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.92, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.58, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.25, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.92, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.58, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 107.00, ["z"] = -0.40, ["rot"] = 180.00}
		}
	},
	archivum_chaos_spawn = {
		test_data = {
			test_name = "Chaos Spawn",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"chaos_spawn"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = -10, ["z"] = 2.6, ["rot"] = 0}
		}
	},
	archivum_crusher_captain = {
		test_data = {
			test_name = "Crusher Captain",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"cultist_captain"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = -10, ["z"] = 2.6, ["rot"] = 0}
		}
	},	
	archivum_crushers_easy = {
		test_data = {
			test_name = "Two Crushers",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 2,
			group = {"Elites", "Easy"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"chaos_ogryn_executor",
			"chaos_ogryn_executor"
		},
		enemy_XYZ = {
			{["x"] = -57.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -54.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180}
		}
	},
	archivum_small_horde = {
		test_data = {
			test_name = "Horde, Small",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 50,
			group = {"Horde", "Easy"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",

			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",

			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker"
		},
		enemy_XYZ = {

			{["x"] = -57.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.00, ["z"] = -0.40, ["rot"] = 180.00},

			{["x"] = -57.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 100.70, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 101.40, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.10, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 102.80, ["z"] = -0.40, ["rot"] = 180.00},
			
			{["x"] = -57.25, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.95, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.65, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.35, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -56.05, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.75, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.45, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -55.15, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.85, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.55, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00},
			{["x"] = -54.25, ["y"] = 103.50, ["z"] = -0.40, ["rot"] = 180.00}	
		}
	},
	archivum_ragers_easy = {
		test_data = {
			test_name = "Two Ragers",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 2,
			group = {"Elites", "Easy"},
			player_invisible = false,
			player_XYZ = {["x"] = -55.5, ["y"] = 90.2, ["z"] = -0.4, ["rot"] = 0}
		},
		enemy_breeds = {
			"cultist_berzerker",
			"cultist_berzerker"
		},
		enemy_XYZ = {
			{["x"] = -56.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180},
			{["x"] = -55.25, ["y"] = 99.75, ["z"] = -0.40, ["rot"] = 180}
		}
	},
	archivum_rinda = {
		test_data = {
			test_name = "Melee Twin",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"renegade_twin_captain_two"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = -10, ["z"] = 2.6, ["rot"] = 0}
		}
	},
	archivum_plogryn = {
		test_data = {
			test_name = "Plague Ogryn",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"DT_official", "Boss", "Easy"},
			player_invisible = false,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"chaos_plague_ogryn"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = -10, ["z"] = 2.6, ["rot"] = 0}
		}
	},
	archivum_no_agro_plogryn = {
		test_data = {
			test_name = "Plogryn, No Agro",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "no_agro"},
			player_invisible = true,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"chaos_plague_ogryn"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = 7, ["z"] = 0.5, ["rot"] = 0}
		}
	},
	archivum_no_agro_chaos_spawn = {
		test_data = {
			test_name = "Chaos Spawn, No Agro",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "no_agro"},
			player_invisible = true,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"chaos_spawn"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = 7, ["z"] = 0.5, ["rot"] = 0}
		}
	},
	archivum_no_agro_crusher_captain = {
		test_data = {
			test_name = "No Agro Crusher Captain",
			test_map = "cm_archives",
			map_name = "Archivum Sychorax",
			kills_needed = 1,
			group = {"Boss", "no_agro"},
			player_invisible = true,
			player_XYZ = {["x"] = -166.5, ["y"] = 11.25, ["z"] = 0.5, ["rot"] = 180}
		},
		enemy_breeds = {
			"cultist_captain"
		},
		enemy_XYZ = {
			{["x"] = -166.5, ["y"] = 7, ["z"] = 0.5, ["rot"] = 0}
		}
	},	
	reginald_horde = {
		test_data = {
			test = "reginald_horde",
			test_name = "OG Horde",
			test_map = "km_enforcer",
			map_name = "Magistrati Oubliette",
			kills_needed = 100,
			group = {"Horde", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = 235.5, ["y"] = -168.5, ["z"] = 7.7, ["rot"] = 62.7}
		},
		enemy_breeds = {
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			"chaos_newly_infected",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			--
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker",
			"chaos_poxwalker"
		},
		enemy_XYZ = {
			{["x"] = 223.20, ["y"] = -163.70, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.24, ["y"] = -163.62, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.29, ["y"] = -163.53, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.33, ["y"] = -163.45, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.38, ["y"] = -163.37, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.42, ["y"] = -163.29, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.47, ["y"] = -163.20, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.51, ["y"] = -163.12, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.56, ["y"] = -163.04, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.60, ["y"] = -162.96, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.65, ["y"] = -162.87, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.69, ["y"] = -162.79, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.74, ["y"] = -162.71, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.78, ["y"] = -162.62, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.83, ["y"] = -162.54, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.87, ["y"] = -162.46, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.92, ["y"] = -162.38, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 223.96, ["y"] = -162.29, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.01, ["y"] = -162.21, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.05, ["y"] = -162.13, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.10, ["y"] = -162.04, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.14, ["y"] = -161.96, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.19, ["y"] = -161.88, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.23, ["y"] = -161.80, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.28, ["y"] = -161.71, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.32, ["y"] = -161.63, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.37, ["y"] = -161.55, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.41, ["y"] = -161.47, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.46, ["y"] = -161.38, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 224.50, ["y"] = -161.30, ["z"] = 7.70, ["rot"] = 242.70},
			--
			{["x"] = 226.90, ["y"] = -165.60, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.95, ["y"] = -165.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.01, ["y"] = -165.39, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.06, ["y"] = -165.29, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.12, ["y"] = -165.18, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.17, ["y"] = -165.08, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.22, ["y"] = -164.97, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.28, ["y"] = -164.87, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.33, ["y"] = -164.77, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.39, ["y"] = -164.66, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.44, ["y"] = -164.56, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.50, ["y"] = -164.45, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.55, ["y"] = -164.35, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.60, ["y"] = -164.25, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.66, ["y"] = -164.14, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.71, ["y"] = -164.04, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.77, ["y"] = -163.93, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.82, ["y"] = -163.83, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.88, ["y"] = -163.72, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.93, ["y"] = -163.62, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.98, ["y"] = -163.52, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.04, ["y"] = -163.41, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.09, ["y"] = -163.31, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.15, ["y"] = -163.20, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.20, ["y"] = -163.10, ["z"] = 7.70, ["rot"] = 242.70},	
			--
			{["x"] = 225.10, ["y"] = -164.80, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.14, ["y"] = -164.71, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.19, ["y"] = -164.62, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.23, ["y"] = -164.53, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.28, ["y"] = -164.44, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.32, ["y"] = -164.35, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.37, ["y"] = -164.26, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.41, ["y"] = -164.17, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.46, ["y"] = -164.08, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.50, ["y"] = -163.99, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.55, ["y"] = -163.90, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.59, ["y"] = -163.81, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.64, ["y"] = -163.72, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.68, ["y"] = -163.63, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.73, ["y"] = -163.54, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.77, ["y"] = -163.46, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.82, ["y"] = -163.37, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.86, ["y"] = -163.28, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.91, ["y"] = -163.19, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 225.95, ["y"] = -163.10, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.00, ["y"] = -163.01, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.04, ["y"] = -162.92, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.09, ["y"] = -162.83, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.13, ["y"] = -162.74, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.18, ["y"] = -162.65, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.22, ["y"] = -162.56, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.27, ["y"] = -162.47, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.31, ["y"] = -162.38, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.36, ["y"] = -162.29, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.40, ["y"] = -162.20, ["z"] = 7.70, ["rot"] = 242.70},
			--
			{["x"] = 228.60, ["y"] = -166.60, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.65, ["y"] = -166.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.71, ["y"] = -166.39, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.76, ["y"] = -166.29, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.82, ["y"] = -166.18, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.87, ["y"] = -166.08, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.93, ["y"] = -165.97, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.98, ["y"] = -165.87, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.03, ["y"] = -165.77, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.09, ["y"] = -165.66, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.14, ["y"] = -165.56, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.20, ["y"] = -165.45, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.25, ["y"] = -165.35, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.30, ["y"] = -165.25, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.36, ["y"] = -165.14, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.41, ["y"] = -165.04, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.47, ["y"] = -164.93, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.52, ["y"] = -164.83, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.57, ["y"] = -164.72, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.63, ["y"] = -164.62, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.68, ["y"] = -164.52, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.74, ["y"] = -164.41, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.79, ["y"] = -164.31, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.85, ["y"] = -164.20, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 229.90, ["y"] = -164.10, ["z"] = 7.70, ["rot"] = 242.70},							
		}
	},
	reginald_brusiers = {
		test_data = {
			test = "reginald_brusiers",
			test_name = "OG Brusiers",
			test_map = "km_enforcer",
			map_name = "Magistrati Oubliette",
			kills_needed = 20,
			group = {"Horde", "Easy"},
			player_invisible = false,
			player_XYZ = {["x"] = 235.5, ["y"] = -168.5, ["z"] = 7.7, ["rot"] = 62.7}
		},
		enemy_breeds = {
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			"cultist_melee",
			--
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee",
			"renegade_melee"
		},
		enemy_XYZ = {
			{["x"] = 226.90, ["y"] = -165.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.03, ["y"] = -165.24, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.17, ["y"] = -164.99, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.30, ["y"] = -164.73, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.43, ["y"] = -164.48, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.57, ["y"] = -164.22, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.70, ["y"] = -163.97, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.83, ["y"] = -163.71, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.97, ["y"] = -163.46, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.10, ["y"] = -163.20, ["z"] = 7.70, ["rot"] = 242.70},
			--
			{["x"] = 225.90, ["y"] = -165.10, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.03, ["y"] = -164.83, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.17, ["y"] = -164.57, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.30, ["y"] = -164.30, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.43, ["y"] = -164.03, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.57, ["y"] = -163.77, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.70, ["y"] = -163.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.83, ["y"] = -163.23, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.97, ["y"] = -162.97, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.10, ["y"] = -162.70, ["z"] = 7.70, ["rot"] = 242.70}					
		}
	},
	reginald_ragers = {
		test_data = {
			test = "reginald_ragers",
			test_name = "OG Ragers",
			test_map = "km_enforcer",
			map_name = "Magistrati Oubliette",
			kills_needed = 6,
			group = {"Elites", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = 235.5, ["y"] = -168.5, ["z"] = 7.7, ["rot"] = 62.7}
		},
		enemy_breeds = {
			"cultist_berzerker",
			"cultist_berzerker",
			"cultist_berzerker",
			"renegade_berzerker",
			"renegade_berzerker",
			"renegade_berzerker"
		},
		enemy_XYZ = {
			{["x"] = 226.90, ["y"] = -165.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.50, ["y"] = -164.35, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.10, ["y"] = -163.20, ["z"] = 7.70, ["rot"] = 242.70},
			--
			{["x"] = 225.90, ["y"] = -165.10, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 226.50, ["y"] = -163.90, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.10, ["y"] = -162.70, ["z"] = 7.70, ["rot"] = 242.70}						
		}
	},
	reginald_crushers = {
		test_data = {
			test = "reginald_crushers",
			test_name = "OG Crushers",
			test_map = "km_enforcer",
			map_name = "Magistrati Oubliette",
			kills_needed = 4,
			group = {"Elites", "Difficult"},
			player_invisible = false,
			player_XYZ = {["x"] = 235.5, ["y"] = -168.5, ["z"] = 7.7, ["rot"] = 62.7}
		},
		enemy_breeds = {
			"chaos_ogryn_executor",
			"chaos_ogryn_executor",
			"chaos_ogryn_executor",
			"chaos_ogryn_executor"
		},
		enemy_XYZ = {
			{["x"] = 226.90, ["y"] = -165.50, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.30, ["y"] = -164.73, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 227.70, ["y"] = -163.97, ["z"] = 7.70, ["rot"] = 242.70},
			{["x"] = 228.10, ["y"] = -163.20, ["z"] = 7.70, ["rot"] = 242.70}	
		}
	},
	no_agro_plogryn = {
		test_data = {
			test = "reginald_plogryn",
			test_name = "Plogryn, No Agro",
			test_map = "km_enforcer",
			map_name = "Magistrati Oubliette",
			kills_needed = 1,
			group = {"Boss", "no_agro"},
			player_invisible = true,
			player_XYZ = {["x"] = 235.2, ["y"] = -152.5, ["z"] = 1.8, ["rot"] = 290}
		},
		enemy_breeds = {
			"chaos_plague_ogryn"
		},
		enemy_XYZ = {
			{["x"] = 240.8, ["y"] = -149.9, ["z"] = 1.8, ["rot"] = 110}	
		}
	}
}

mod_data.options = {
	widgets = {
		{	["setting_id"] = "group_test_spawner",
			["type"] = "group",
			["sub_widgets"] = {
				{
					["setting_id"] = "keybind_spawn_test",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Spawn_Test",
					["tooltip"] = "spawn_test_tooltip"
				},	
				{
					["setting_id"] = "keybind_save_test",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Save_Test_Result",
					["tooltip"] = "save_test_tooltip"
				},
				{
					["setting_id"] = "test_group_dropdown",
					["type"] = "dropdown",
					["options"] = {
					{text = "test_selection_any",    value = "any"},
					{text = "test_selection_official",    value = "DT_official"},
					{text = "test_selection_elites",    value = "Elites"},
					{text = "test_selection_horde",    value = "Horde"},
					{text = "test_selection_boss",    value = "Boss"},
					{text = "test_selection_difficult",      value = "Difficult"},
					{text = "test_selection_easy", value = "Easy"},
					{text = "test_selection_no_agro",       value = "no_agro"},
					},
					["default_value"] = "any", -- Default first option is enabled. In this case regular_units
				},					
				{
					["setting_id"] = "keybind_next_test_selection",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Next_Test_Selection"
				},
				{
					["setting_id"] = "keybind_previous_test_selection",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Previous_Test_Selection"
				},
				{ -- if true all ragdolls will be cleaned up upon starting test
					["setting_id"] = "toggle_cleanup_ragdolls",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "toggle_cleanup_ragdolls_tooltip"
				},				
				{ -- if true scoreboard resets before each test
					["setting_id"] = "toggle_reset_scoreboard",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "reset_scoreboard_tooltip"
				},
				{ -- if true all buffs applied by testing utilites will be listed in notes
					["setting_id"] = "toggle_notes_buffs",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "buff_notes_tooltip"
				},				
				{ -- if true test will end if zero hp is reached
					["setting_id"] = "toggle_auto_fail",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "auto_fail_tooltip"
				},
				{ -- if true test will fail when until death is activated
					["setting_id"] = "toggle_until_death_fail",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "until_death_fail_tooltip"
				},
				{ -- Slider for Number of Autosaves Kept
					["setting_id"] = "autosave_slider",
					["type"] = "numeric",
					["default_value"] = 20,
					["range"] = {0, 100},
					["decimals_number"] = 0,
					["title"] = "autosave_slider",
					["tooltip"] = "autosave_slider_tooltip"
				},																	
			}
		},

		{	["setting_id"] = "group_utilities",
			["type"] = "group",
			["sub_widgets"] = {	
				{ 
					["setting_id"] = "keybind_position_at_cursor",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Position_at_Cursor"
				},
				{ 
					["setting_id"] = "keybind_echo_mission_name",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Echo_Mission_Name"
				},
				{ -- if true the game will call you bad
					["setting_id"] = "toggle_bad",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "toggle_bad_tooltip"
				},
			}
		},

		-- {	["setting_id"] = "group_debug",
		-- 	["type"] = "group",
		-- 	["sub_widgets"] = {	
		-- 		{ 
		-- 			["setting_id"] = "keybind_test_func_1",
		-- 			["type"] = "keybind",
		-- 			["keybind_trigger"] = "pressed",
		-- 			["keybind_type"] = "function_call",
		-- 			["default_value"] = {},
		-- 			["function_name"] = "Test_Func_1"
		-- 		},
		-- 		{ 
		-- 			["setting_id"] = "keybind_test_func_2",
		-- 			["type"] = "keybind",
		-- 			["keybind_trigger"] = "pressed",
		-- 			["keybind_type"] = "function_call",
		-- 			["default_value"] = {},
		-- 			["function_name"] = "Test_Func_2"
		-- 		},
		-- 		{ 
		-- 			["setting_id"] = "keybind_test_func_3",
		-- 			["type"] = "keybind",
		-- 			["keybind_trigger"] = "pressed",
		-- 			["keybind_type"] = "function_call",
		-- 			["default_value"] = {},
		-- 			["function_name"] = "Test_Func_3"
		-- 		}
		-- 	}
		-- }
	}
}
  
return mod_data