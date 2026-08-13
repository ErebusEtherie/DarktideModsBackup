

---@enum UseBreedsBreedID
local id_registry = {
	chaos_armored_hound = "chaos_armored_hound",
	chaos_beast_of_nurgle = "chaos_beast_of_nurgle",
	chaos_daemonhost = "chaos_daemonhost",
	chaos_hound = "chaos_hound",
	chaos_hound_mutator = "chaos_hound_mutator",
	chaos_lesser_mutated_poxwalker = "chaos_lesser_mutated_poxwalker",
	chaos_mutated_poxwalker = "chaos_mutated_poxwalker",
	chaos_newly_infected = "chaos_newly_infected",
	chaos_armored_infected = "chaos_armored_infected",
	chaos_ogryn_bulwark = "chaos_ogryn_bulwark",
	chaos_ogryn_executor = "chaos_ogryn_executor",
	chaos_ogryn_gunner = "chaos_ogryn_gunner",
	chaos_ogryn_houndmaster = "chaos_ogryn_houndmaster",
	chaos_plague_ogryn = "chaos_plague_ogryn",
	chaos_poxwalker = "chaos_poxwalker",
	chaos_poxwalker_bomber = "chaos_poxwalker_bomber",
	chaos_spawn = "chaos_spawn",
	cultist_assault = "cultist_assault",
	cultist_berzerker = "cultist_berzerker",
	cultist_captain = "cultist_captain",
	cultist_flamer = "cultist_flamer",
	cultist_grenadier = "cultist_grenadier",
	cultist_gunner = "cultist_gunner",
	cultist_melee = "cultist_melee",
	cultist_mutant = "cultist_mutant",
	cultist_mutant_mutator = "cultist_mutant_mutator",
	cultist_ritualist = "cultist_ritualist",
	cultist_shocktrooper = "cultist_shocktrooper",
	cultist_vanguard = "cultist_vanguard",
	renegade_assault = "renegade_assault",
	renegade_berzerker = "renegade_berzerker",
	renegade_captain = "renegade_captain",
	renegade_executor = "renegade_executor",
	renegade_flamer = "renegade_flamer",
	renegade_grenadier = "renegade_grenadier",
	renegade_gunner = "renegade_gunner",
	renegade_melee = "renegade_melee",
	renegade_netgunner = "renegade_netgunner",
	renegade_plasma_gunner = "renegade_plasma_gunner",
	renegade_radio_operator = "renegade_radio_operator",
	renegade_rifleman = "renegade_rifleman",
	renegade_shocktrooper = "renegade_shocktrooper",
	renegade_sniper = "renegade_sniper",
	renegade_twin_captain = "renegade_twin_captain",
	renegade_twin_captain_two = "renegade_twin_captain_two",
	renegade_vanguard = "renegade_vanguard",
}

---@enum UseBreedsBreedEnName
local en_name_registry = {
	["Mutator Mutant"] = "Mutator Mutant",
	["Armoured Pox Hound"] = "Armoured Pox Hound",
	["Beast of Nurgle"] = "Beast of Nurgle",
	["Daemonhost"] = "Daemonhost",
	["Pox Hound"] = "Pox Hound",
	["Mutated Pox Hound"] = "Mutated Pox Hound",
	["Mutated Poxwalker"] = "Mutated Poxwalker",
	["Tentacled Poxwalker"] = "Tentacled Poxwalker",
	["Groaner"] = "Groaner",
	["Armored Groaner"] = "Armored Groaner",
	["Bulwark"] = "Bulwark",
	["Crusher"] = "Crusher",
	["Reaper"] = "Reaper",
	["Pack Master"] = "Pack Master",
	["Plague Ogryn"] = "Plague Ogryn",
	["Poxwalker"] = "Poxwalker",
	["Poxburster"] = "Poxburster",
	["Chaos Spawn"] = "Chaos Spawn",
	["Dreg Stalker"] = "Dreg Stalker",
	["Dreg Rager"] = "Dreg Rager",
	["Admonition Champion"] = "Admonition Champion",
	["Tox Flamer"] = "Tox Flamer",
	["Tox Bomber"] = "Tox Bomber",
	["Dreg Gunner"] = "Dreg Gunner",
	["Dreg Bruiser"] = "Dreg Bruiser",
	["Mutant"] = "Mutant",
	["Ritualist"] = "Ritualist",
	["Dreg Shotgunner"] = "Dreg Shotgunner",
	["Scab Stalker"] = "Scab Stalker",
	["Scab Rager"] = "Scab Rager",
	["Scab Captain"] = "Scab Captain",
	["Mauler"] = "Mauler",
	["Scab Flamer"] = "Scab Flamer",
	["Bomber"] = "Bomber",
	["Scab Gunner"] = "Scab Gunner",
	["Scab Bruiser"] = "Scab Bruiser",
	["Trapper"] = "Trapper",
	["Plasma Gunner"] = "Plasma Gunner",
	["Scab Radio Operator"] = "Scab Radio Operator",
	["Scab Shooter"] = "Scab Shooter",
	["Scab Shotgunner"] = "Scab Shotgunner",
	["Sniper"] = "Sniper",
	["Rodin Karnak"] = "Rodin Karnak",
	["Rinda Karnak"] = "Rinda Karnak",
	["Dreg Vanguard"] = "Dreg Vanguard",
	["Scab Vanguard"] = "Scab Vanguard",
}

---@enum UseBreedsBreedIdToEnName
local id_to_en_name = {
	[id_registry["chaos_armored_hound"]] = en_name_registry["Armoured Pox Hound"],
	[id_registry["chaos_beast_of_nurgle"]] = en_name_registry["Beast of Nurgle"],
	[id_registry["chaos_daemonhost"]] = en_name_registry["Daemonhost"],
	[id_registry["chaos_hound"]] = en_name_registry["Pox Hound"],
	[id_registry["chaos_hound_mutator"]] = en_name_registry["Mutated Pox Hound"],
	[id_registry["chaos_lesser_mutated_poxwalker"]] = en_name_registry["Mutated Poxwalker"],
	[id_registry["chaos_mutated_poxwalker"]] = en_name_registry["Tentacled Poxwalker"],
	[id_registry["chaos_newly_infected"]] = en_name_registry["Groaner"],
	[id_registry["chaos_armored_infected"]] = en_name_registry["Armored Groaner"],
	[id_registry["chaos_ogryn_bulwark"]] = en_name_registry["Bulwark"],
	[id_registry["chaos_ogryn_executor"]] = en_name_registry["Crusher"],
	[id_registry["chaos_ogryn_gunner"]] = en_name_registry["Reaper"],
	[id_registry["chaos_ogryn_houndmaster"]] = en_name_registry["Pack Master"],
	[id_registry["chaos_plague_ogryn"]] = en_name_registry["Plague Ogryn"],
	[id_registry["chaos_poxwalker"]] = en_name_registry["Poxwalker"],
	[id_registry["chaos_poxwalker_bomber"]] = en_name_registry["Poxburster"],
	[id_registry["chaos_spawn"]] = en_name_registry["Chaos Spawn"],
	[id_registry["cultist_assault"]] = en_name_registry["Dreg Stalker"],
	[id_registry["cultist_berzerker"]] = en_name_registry["Dreg Rager"],
	[id_registry["cultist_captain"]] = en_name_registry["Admonition Champion"],
	[id_registry["cultist_flamer"]] = en_name_registry["Tox Flamer"],
	[id_registry["cultist_grenadier"]] = en_name_registry["Tox Bomber"],
	[id_registry["cultist_gunner"]] = en_name_registry["Dreg Gunner"],
	[id_registry["cultist_melee"]] = en_name_registry["Dreg Bruiser"],
	[id_registry["cultist_mutant"]] = en_name_registry["Mutant"],
	[id_registry["cultist_mutant_mutator"]] = en_name_registry["Mutator Mutant"],
	[id_registry["cultist_ritualist"]] = en_name_registry["Ritualist"],
	[id_registry["cultist_shocktrooper"]] = en_name_registry["Dreg Shotgunner"],
	[id_registry["cultist_vanguard"]] = en_name_registry["Dreg Vanguard"],
	[id_registry["renegade_assault"]] = en_name_registry["Scab Stalker"],
	[id_registry["renegade_berzerker"]] = en_name_registry["Scab Rager"],
	[id_registry["renegade_captain"]] = en_name_registry["Scab Captain"],
	[id_registry["renegade_executor"]] = en_name_registry["Mauler"],
	[id_registry["renegade_flamer"]] = en_name_registry["Scab Flamer"],
	[id_registry["renegade_grenadier"]] = en_name_registry["Bomber"],
	[id_registry["renegade_gunner"]] = en_name_registry["Scab Gunner"],
	[id_registry["renegade_melee"]] = en_name_registry["Scab Bruiser"],
	[id_registry["renegade_netgunner"]] = en_name_registry["Trapper"],
	[id_registry["renegade_plasma_gunner"]] = en_name_registry["Plasma Gunner"],
	[id_registry["renegade_radio_operator"]] = en_name_registry["Scab Radio Operator"],
	[id_registry["renegade_rifleman"]] = en_name_registry["Scab Shooter"],
	[id_registry["renegade_shocktrooper"]] = en_name_registry["Scab Shotgunner"],
	[id_registry["renegade_sniper"]] = en_name_registry["Sniper"],
	[id_registry["renegade_twin_captain"]] = en_name_registry["Rodin Karnak"],
	[id_registry["renegade_twin_captain_two"]] = en_name_registry["Rinda Karnak"],
	[id_registry["renegade_vanguard"]] = en_name_registry["Scab Vanguard"],
}

---@type table<string, UseBreedsBreedID>
local en_name_to_id = {}
for id, en_name in pairs(id_to_en_name) do
	en_name_to_id[en_name] = id
end

local ar = function(head, torso)
	return { head = head, torso = torso }
end

local breed_by_taxonomy = {
	category = {
		elite = {
			chaos_ogryn_bulwark = true, 
			chaos_ogryn_executor = true, 
			chaos_ogryn_gunner = true, 
			cultist_berzerker = true, 
			cultist_gunner = true, 
			cultist_shocktrooper = true, 
			renegade_berzerker = true, 
			renegade_executor = true, 
			renegade_gunner = true, 
			renegade_plasma_gunner = true, 
			renegade_radio_operator = true, 
			renegade_shocktrooper = true, 
		},
		special = {
			chaos_armored_hound = true, 
			chaos_hound = true, 
			chaos_hound_mutator = true, 
			chaos_poxwalker_bomber = true, 
			cultist_flamer = true, 
			cultist_grenadier = true, 
			cultist_mutant = true, 
			cultist_mutant_mutator = true, 
			cultist_ritualist = true, 
			renegade_flamer = true, 
			renegade_grenadier = true, 
			renegade_netgunner = true, 
			renegade_sniper = true, 
		},
		boss = {
			chaos_beast_of_nurgle = true, 
			chaos_daemonhost = true, 
			chaos_plague_ogryn = true, 
			chaos_spawn = true, 
			chaos_ogryn_houndmaster = true, 
			cultist_captain = true, 
			renegade_captain = true, 
			renegade_twin_captain = true, 
			renegade_twin_captain_two = true, 
		},
		regular = {
			chaos_lesser_mutated_poxwalker = true, 
			chaos_mutated_poxwalker = true, 
			chaos_armored_infected = true, 
			chaos_newly_infected = true, 
			chaos_poxwalker = true, 
			cultist_melee = true, 
			renegade_melee = true, 
			cultist_assault = true, 
			renegade_assault = true, 
			renegade_rifleman = true, 
			cultist_vanguard = true, 
			renegade_vanguard = true, 
		},
	},
	combat_style = {
		ranged = {
			chaos_ogryn_gunner = true, 
			cultist_assault = true, 
			cultist_gunner = true, 
			cultist_shocktrooper = true, 
			renegade_assault = true, 
			renegade_gunner = true, 
			renegade_plasma_gunner = true, 
			renegade_radio_operator = true, 
			renegade_rifleman = true, 
			renegade_shocktrooper = true, 
			renegade_twin_captain = true, 
			renegade_sniper = true, 
		},
		area_denial = {
			cultist_flamer = true, 
			renegade_flamer = true, 
			cultist_grenadier = true, 
			renegade_grenadier = true, 
			chaos_poxwalker_bomber = true, 
		},
		melee = {
			chaos_plague_ogryn = true, 
			chaos_beast_of_nurgle = true, 
			chaos_daemonhost = true, 
			chaos_spawn = true, 
			chaos_lesser_mutated_poxwalker = true, 
			chaos_mutated_poxwalker = true, 
			chaos_poxwalker = true, 
			chaos_armored_infected = true, 
			chaos_newly_infected = true, 
			chaos_ogryn_bulwark = true, 
			renegade_executor = true, 
			chaos_ogryn_executor = true, 
			cultist_berzerker = true, 
			cultist_captain = true, 
			cultist_melee = true, 
			cultist_vanguard = true, 
			renegade_berzerker = true, 
			renegade_captain = true, 
			renegade_melee = true, 
			renegade_twin_captain_two = true, 
			renegade_vanguard = true, 
		},
		disabler = {
			chaos_armored_hound = true, 
			chaos_hound = true, 
			chaos_hound_mutator = true, 
			chaos_ogryn_houndmaster = true, 
			cultist_mutant = true, 
			cultist_mutant_mutator = true, 
			renegade_netgunner = true, 
		},
		ritualist = {
			cultist_ritualist = true, 
		},
	},
	group = {
		melee_horde = {
			chaos_lesser_mutated_poxwalker = true, 
			chaos_mutated_poxwalker = true, 
			chaos_armored_infected = true, 
			chaos_newly_infected = true, 
			chaos_poxwalker = true, 
		},
		melee_bruiser = {
			renegade_melee = true, 
			cultist_melee = true, 
		},
		melee_shield = {
			chaos_ogryn_bulwark = true, 
			cultist_vanguard = true, 
			renegade_vanguard = true, 
		},
		melee_carapace = {
			chaos_ogryn_executor = true, 
			renegade_executor = true, 
		},
		ragers = {
			cultist_berzerker = true, 
			renegade_berzerker = true, 
		},
		flamers = {
			cultist_flamer = true, 
			renegade_flamer = true, 
		},
		bombers = {
			cultist_grenadier = true, 
			renegade_grenadier = true, 
		},
		vanguards = {
			cultist_vanguard = true,
			renegade_vanguard = true,
		},
		shotgunners = {
			cultist_shocktrooper = true, 
			renegade_shocktrooper = true, 
		},
		snipers = {
			renegade_sniper = true, 
		},
		gunners = {
			chaos_ogryn_gunner = true, 
			cultist_gunner = true, 
			renegade_gunner = true, 
			renegade_plasma_gunner = true, 
		},
		shooters = {
			renegade_assault = true, 
			cultist_assault = true, 
			renegade_rifleman = true, 
		},
		hounds = {
			chaos_armored_hound = true, 
			chaos_hound_mutator = true, 
			chaos_hound = true, 
		},
		mutants = {
			cultist_mutant = true, 
			cultist_mutant_mutator = true, 
		},
	},
	faction = {
		dreg = {
			cultist_assault = true, 
			cultist_berzerker = true, 
			cultist_captain = true, 
			cultist_flamer = true, 
			cultist_grenadier = true, 
			cultist_gunner = true, 
			cultist_melee = true, 
			cultist_mutant = true, 
			cultist_mutant_mutator = true, 
			cultist_ritualist = true, 
			cultist_shocktrooper = true, 
			cultist_vanguard = true, 
		},
		scab = {
			renegade_assault = true, 
			renegade_berzerker = true, 
			renegade_captain = true, 
			renegade_executor = true, 
			renegade_flamer = true, 
			renegade_grenadier = true, 
			renegade_gunner = true, 
			renegade_melee = true, 
			renegade_netgunner = true, 
			renegade_plasma_gunner = true, 
			renegade_radio_operator = true, 
			renegade_rifleman = true, 
			renegade_shocktrooper = true, 
			renegade_sniper = true, 
			renegade_twin_captain = true, 
			renegade_twin_captain_two = true, 
			renegade_vanguard = true, 
		},
		chaos = {
			chaos_armored_hound = true, 
			chaos_beast_of_nurgle = true, 
			chaos_daemonhost = true, 
			chaos_hound_mutator = true, 
			chaos_hound = true, 
			chaos_lesser_mutated_poxwalker = true, 
			chaos_mutated_poxwalker = true, 
			chaos_newly_infected = true, 
			chaos_armored_infected = true, 
			chaos_ogryn_bulwark = true, 
			chaos_ogryn_executor = true, 
			chaos_ogryn_gunner = true, 
			chaos_ogryn_houndmaster = true, 
			chaos_plague_ogryn = true, 
			chaos_poxwalker = true, 
			chaos_poxwalker_bomber = true, 
			chaos_spawn = true, 
		},
	},
}

---@type table<UseBreedsBreedID, UseBreedsBreedArmor>
local breed_armor = {
	chaos_beast_of_nurgle = ar("monstrosity", "monstrosity"), 
	chaos_daemonhost = ar("monstrosity", "monstrosity"), 
	chaos_plague_ogryn = ar("monstrosity", "monstrosity"), 
	chaos_spawn = ar("monstrosity", "monstrosity"), 
	chaos_ogryn_bulwark = ar("unyielding", "unyielding"), 
	chaos_ogryn_gunner = ar("unyielding", "flak"), 
	chaos_ogryn_executor = ar("carapace", "carapace"), 
	renegade_executor = ar("carapace", "flak"), 
	chaos_lesser_mutated_poxwalker = ar("infested", "infested"), 
	chaos_mutated_poxwalker = ar("infested", "infested"), 
	chaos_poxwalker = ar("infested", "infested"), 
	chaos_poxwalker_bomber = ar("infested", "infested"), 
	chaos_armored_hound = ar("carapace", "flak"), 
	chaos_hound_mutator = ar("infested", "infested"), 
	chaos_hound = ar("infested", "infested"), 
	cultist_berzerker = ar("maniac", "maniac"), 
	cultist_mutant = ar("maniac", "maniac"), 
	cultist_mutant_mutator = ar("maniac", "maniac"), 
	renegade_netgunner = ar("maniac", "maniac"), 
	chaos_armored_infected = ar("unarmored", "flak"), 
	renegade_captain = ar("flak", "flak"), 
	renegade_grenadier = ar("unarmored", "flak"), 
	chaos_ogryn_houndmaster = ar("carapace", "unyielding"), 
	renegade_assault = ar("flak", "flak"), 
	renegade_flamer = ar("maniac", "maniac"), 
	renegade_gunner = ar("flak", "flak"), 
	renegade_melee = ar("unarmored", "flak"), 
	renegade_plasma_gunner = ar("carapace", "flak"), 
	renegade_radio_operator = ar("flak", "flak"), 
	renegade_rifleman = ar("flak", "flak"), 
	renegade_shocktrooper = ar("flak", "flak"), 
	renegade_twin_captain = ar("carapace", "flak"), 
	renegade_twin_captain_two = ar("carapace", "flak"), 
	renegade_vanguard = ar("flak", "flak"), 
	chaos_newly_infected = ar("unarmored", "unarmored"), 
	renegade_sniper = ar("unarmored", "unarmored"), 
	cultist_gunner = ar("unarmored", "flak"), 
	cultist_shocktrooper = ar("flak", "flak"), 
	cultist_assault = ar("unarmored", "unarmored"), 
	cultist_captain = ar("flak", "flak"), 
	cultist_flamer = ar("maniac", "maniac"), 
	cultist_grenadier = ar("unarmored", "unarmored"), 
	cultist_melee = ar("flak", "unarmored"), 
	cultist_ritualist = ar("unarmored", "unarmored"), 
	cultist_vanguard = ar("flak", "unarmored"), 
}

---@class FatsharkBreedTags

---@field minion boolean?
---@field player boolean?
---@field ogryn boolean?
---@field human boolean?
---@field poxwalker boolean?
---@field companion boolean?
---@field cryptic boolean?

---@field elite boolean?
---@field special boolean?
---@field captain boolean?
---@field cultist_captain boolean?
---@field monster boolean?
---@field witch boolean?
---@field bulwark boolean?

---@field melee boolean?
---@field close boolean?
---@field far boolean?
---@field roamer boolean?
---@field horde boolean?
---@field disabler boolean?
---@field sniper boolean?
---@field bomber boolean?
---@field scrambler boolean?
---@field ritualist boolean?
---@field mutator boolean?
---@field exclude_for_havoc_speed_buff boolean?

---@class FatsharkBreedData
---@field name UseBreedsBreedID internal id, e.g. "renegade_gunner"
---@field breed_type "companion"|"living_prop"|"minion"|"objective_prop"|"player"|"prop"
---@field display_name string localization key e.g. "loc_breed_display_name_renegade_gunner"
---@field faction_name string coarse faction, e.g. "chaos"
---@field sub_faction_name string? e.g. "renegade" | "cultist"
---@field tags FatsharkBreedTags? threat/behaviour flags
---@field armor_type string? ArmorSettings.types value
---@field challenge_rating number?
---@field base_height number?
---@field run_speed number?
---@field walk_speed number?
---@field ranged boolean?
---@field flying boolean?
---@field power_level_type table<string, string>?
---@field hit_mass number?

---@alias UseBreedsBreedCategory "elite" | "special" | "boss" | "regular"
---@alias UseBreedsBreedCombatStyle "ranged" | "melee" | "disabler" | "ritualist"
---@alias UseBreedsBreedArmorClass "unyielding" | "monstrosity" | "carapace" | "maniac" | "flak" | "infested" | "unarmored"
---@alias UseBreedsBreedArmorLocation "head" | "torso"
---@alias UseBreedsBreedGroup "melee_horde" | "vanguards" | "melee_bruiser" | "melee_shield" | "melee_carapace" | "ragers" | "snipers" | "flamers" | "bombers" | "shotgunners"  | "gunners" | "shooters" | "hounds" | "mutants"
---@alias UseBreedsBreedFaction "dreg" | "scab" | "chaos"

---@class UseBreedsBreedArmor
---@field head UseBreedsBreedArmorClass
---@field torso UseBreedsBreedArmorClass

---@alias UseBreedsBreedToken UseBreedsBreedID | UseBreedsBreedEnName | FatsharkBreedData

---@alias UseBreedsBreedTaxonomyPath

---@alias UseBreedsBreedArmorPath

---@alias UseBreedsBreedSelector UseBreedsBreedTaxonomyPath | UseBreedsBreedArmorPath | UseBreedsBreedArmorClass | UseBreedsBreedID | UseBreedsBreedEnName

---@class UseBreedsBreedTaxonomy
---@field category UseBreedsBreedCategory
---@field combat_style UseBreedsBreedCombatStyle
---@field group UseBreedsBreedGroup
---@field faction UseBreedsBreedFaction
---@field armor UseBreedsBreedArmor
---@field en_name UseBreedsBreedEnName

---@type table<UseBreedsBreedID, UseBreedsBreedTaxonomy>
local breed_taxonomies = {}

for section, groups in pairs(breed_by_taxonomy) do
	for group, ids in pairs(groups) do
		for id, _ in pairs(ids) do
			breed_taxonomies[id] = breed_taxonomies[id] or {}

			breed_taxonomies[id][section] = group
			breed_taxonomies[id].en_name = id_to_en_name[id]
		end
	end
end

for id, armor in pairs(breed_armor) do
	breed_taxonomies[id] = breed_taxonomies[id] or {}
	breed_taxonomies[id].armor = armor
end

local FS_ScriptUnit = ScriptUnit

---@param ref UseBreedsBreedToken | nil
---@return UseBreedsBreedID | nil
local function resolve_id(ref)
	if type(ref) == "table" then
		return ref.name
	end

	return en_name_to_id[ref] or ref
end

---@param id UseBreedsBreedID | nil
---@param token UseBreedsBreedSelector
---@return boolean
local function id_matches_token(id, token)
	if not id or type(token) ~= "string" or token == "" then
		return false
	end

	if token == id or en_name_to_id[token] == id then
		return true
	end

	local dot = string.find(token, ".", 1, true)
	if not dot then

		local armor = breed_armor[id]
		return armor ~= nil and (armor.head == token or armor.torso == token)
	end

	local section = string.sub(token, 1, dot - 1)
	local group = string.sub(token, dot + 1)

	if section == "head" or section == "torso" then
		local armor = breed_armor[id]
		return armor ~= nil and armor[section] == group
	end

	local sets = breed_by_taxonomy[section]
	local set = sets and sets[group]
	return (set and set[id]) or false
end

---@class DarkLib
---@field breeds DL_Breeds

---@param mod table
return function(mod)
	---@class DL_Breeds
	local Breeds = {
		id_registry = id_registry,
		breed_by_taxonomy = breed_by_taxonomy,
	}

	local function ensure_script_unit()
		FS_ScriptUnit = FS_ScriptUnit or _G.ScriptUnit
		return FS_ScriptUnit ~= nil
	end

	---@param unit any | nil
	---@return FatsharkBreedData|nil breed
	function Breeds.data_from_unit(unit)
		if not unit or not ensure_script_unit() then
			return nil
		end

		local unit_data_extension = FS_ScriptUnit.has_extension(unit, "unit_data_system")

		return unit_data_extension and unit_data_extension:breed() or nil
	end

	---@param unit_or_data FatsharkBreedData | Unit | nil
	function Breeds.is_minion(unit_or_data)
		if type(unit_or_data) == "userdata" then
			return Breeds.data_from_unit(unit_or_data).breed_type == "minion"
		end
		if type(unit_or_data) == "table" then
			return unit_or_data.breed_type == "minion"
		end
		return false
	end

	---@param token UseBreedsBreedToken | nil
	---@return string | nil
	function Breeds.name_en(token)
		return token and id_to_en_name[resolve_id(token)] or nil
	end

	---@param token FatsharkBreedData | UseBreedsBreedEnName
	---@return string | nil
	function Breeds.id(token)
		if token and type(token) == "table" then
			return resolve_id(token)
		end
		return type(token) == "string" and en_name_to_id[token] or nil
	end

	local function keys(set)
		local out = {}
		for id in pairs(set) do
			out[#out + 1] = id
		end
		table.sort(out)
		return out
	end

	local function copy(list)
		local out = {}
		for i = 1, #list do
			out[i] = list[i]
		end
		return out
	end

	---@param location UseBreedsBreedArmorLocation | nil
	---@param class string
	---@return UseBreedsBreedID[]
	local function armor_ids(location, class)
		local out = {}
		for id, armor in pairs(breed_armor) do
			local match = location and armor[location] == class
				or (not location and (armor.head == class or armor.torso == class))
			if match then
				out[#out + 1] = id
			end
		end
		table.sort(out)
		return out
	end

	local ids_cache = {}

	---@param token UseBreedsBreedSelector
	---@return UseBreedsBreedID[]
	local function ids_for_token(token)
		if type(token) ~= "string" then
			return {}
		end

		local cached = ids_cache[token]
		if cached then
			return cached
		end

		local id = id_registry[token] or en_name_to_id[token]
		if id then
			cached = { id }
			ids_cache[token] = cached
			return cached
		end

		local dot = string.find(token, ".", 1, true)
		if not dot then

			cached = armor_ids(nil, token)
			ids_cache[token] = cached
			return cached
		end

		local section = string.sub(token, 1, dot - 1)
		local group = string.sub(token, dot + 1)

		if section == "head" or section == "torso" then
			cached = armor_ids(section, group)
			ids_cache[token] = cached
			return cached
		end

		local sets = breed_by_taxonomy[section]
		local set = sets and sets[group]
		if not set then
			cached = {}
			ids_cache[token] = cached
			return cached
		end

		cached = keys(set)
		ids_cache[token] = cached
		return cached
	end

	---@param ... UseBreedsBreedSelector | UseBreedsBreedSelector[]
	---@return UseBreedsBreedID[]
	function Breeds.where(...)
		if select("#", ...) == 1 and type((...)) == "table" then
			return Breeds.where(unpack((...)))
		end

		local n = select("#", ...)
		if n == 0 then
			return {}
		end

		if n <= 1 then
			return copy(ids_for_token(...))
		end

		local rest = {}
		for i = 2, n do
			local set = {}
			for _, id in ipairs(ids_for_token((select(i, ...)))) do
				set[id] = true
			end
			rest[#rest + 1] = set
		end

		local out = {}
		for _, id in ipairs(ids_for_token((select(1, ...)))) do
			local all = true
			for k = 1, #rest do
				if not rest[k][id] then
					all = false
					break
				end
			end
			if all then
				out[#out + 1] = id
			end
		end

		return out
	end

	---@param ... UseBreedsBreedSelector | UseBreedsBreedSelector[]
	---@return UseBreedsBreedID[]
	function Breeds.where_any(...)
		if select("#", ...) == 1 and type((...)) == "table" then
			return Breeds.where_any(unpack((...)))
		end

		local n = select("#", ...)

		if n <= 1 then
			return copy(ids_for_token(...))
		end

		local seen = {}
		local out = {}
		for i = 1, n do
			for _, id in ipairs(ids_for_token((select(i, ...)))) do
				if not seen[id] then
					seen[id] = true
					out[#out + 1] = id
				end
			end
		end

		table.sort(out)
		return out
	end

	function Breeds.is(token, ...)
		if select("#", ...) == 1 and type((...)) == "table" then
			return Breeds.is(token, unpack((...)))
		end

		local id = resolve_id(token)
		local n = select("#", ...)
		if not id or n == 0 then
			return false
		end

		for i = 1, n do
			if not id_matches_token(id, (select(i, ...))) then
				return false
			end
		end

		return true
	end

	function Breeds.is_any(token, ...)
		if select("#", ...) == 1 and type((...)) == "table" then
			return Breeds.is_any(token, unpack((...)))
		end

		local id = resolve_id(token)
		if not id then
			return false
		end

		for i = 1, select("#", ...) do
			if id_matches_token(id, (select(i, ...))) then
				return true
			end
		end

		return false
	end

	function Breeds.unit_is(unit, ...)
		return unit ~= nil and Breeds.is(Breeds.data_from_unit(unit), ...)
	end

	function Breeds.unit_is_any(unit, ...)
		return unit ~= nil and Breeds.is_any(Breeds.data_from_unit(unit), ...)
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedTaxonomy | nil
	function Breeds.breed_taxonomy(token)
		local taxonomy_table = token and breed_taxonomies[resolve_id(token)] or nil
		return taxonomy_table or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedCategory | nil
	function Breeds.breed_category(token)
		local taxonomy = Breeds.breed_taxonomy(token)
		return taxonomy and taxonomy.category or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedCombatStyle | nil
	function Breeds.breed_attack(token)
		local taxonomy = Breeds.breed_taxonomy(token)
		return taxonomy and taxonomy.combat_style or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedGroup | nil
	function Breeds.breed_group(token)
		local taxonomy = Breeds.breed_taxonomy(token)
		return taxonomy and taxonomy.group or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedFaction | nil
	function Breeds.breed_faction(token)
		local taxonomy = Breeds.breed_taxonomy(token)
		return taxonomy and taxonomy.faction or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedArmor | nil
	function Breeds.breed_armor_class(token)
		return breed_armor[resolve_id(token)] or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedArmorClass | nil
	function Breeds.breed_head_armor(token)
		local armor = breed_armor[resolve_id(token)]
		return armor and armor.head or nil
	end

	---@param token UseBreedsBreedToken | nil
	---@return UseBreedsBreedArmorClass | nil
	function Breeds.breed_torso_armor(token)
		local armor = breed_armor[resolve_id(token)]
		return armor and armor.torso or nil
	end

	---@param token UseBreedsBreedToken | nil
	function Breeds.try_localise(token)
		local id = token and (token.display_name or ("loc_breed_display_name_" .. resolve_id(token)))

		if type(id) ~= "string" or id == "" or id == "loc_" then
			return nil
		end

		if id:sub(1, 23) ~= "loc_breed_display_name_" then
			id = "loc_breed_display_name_" .. id
		end

		local _G = _G
		local val = nil
		local _Managers = rawget(_G, "Managers")
		if _G.Localize then
			val = _G.Localize(id)
		elseif _Managers and _Managers.localization then
			val = _Managers.localization:localize(id)
		end

		if type(val) ~= "string" or val == "" then
			return nil
		end
		if val == ("<" .. id .. ">") then
			return nil
		end
		if val == ('<unlocalized "' .. id .. '": string not found>') then
			return nil
		end
		if string.find(val, '<unlocalized "', 1, true) == 1 then
			return nil
		end

		return val
	end

	return Breeds
end
