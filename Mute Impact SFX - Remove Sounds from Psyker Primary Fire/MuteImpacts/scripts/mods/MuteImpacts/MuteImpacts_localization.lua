local mod = get_mod("MuteImpacts")

-- ################################
-- Local References for Performance
-- ################################
local pairs = pairs

-- ################################
-- Localization
-- ################################
-- ################
-- Manual Localization
-- For Mod Info and Exceptions
-- ################
local localizations = {
	mod_name = {
		en = "Silence Obnoxious Sounds (SOS)",
	},
	mod_description = {
		-- en = "pipe down skittle squad",
		en = "Mute impact SFX and such",
	},
	missing_audio_plugin_error = {
		en = "Audio Plugin not detected!",
	},
	-- -------------------------
	-- One-off Sounds
	-- -------------------------
	forcestaff_primary_fire = {
		en = "Force Staff Primary Fire",
	},
	lasbeam_crack_player = {
		en = "Lasbeam Crack (Player)",
	},
	lasbeam_crack_enemy_captain = {
		en = "Lasbeam Crack (Rodin Karnak)",
	},
	lasbeam_crack_enemy = {
		en = "Lasbeam Crack (Other Scab Enemies)",
	},
	penance_reward_claim = {
		en = "Claiming Penance Rewards",
	},
	npc_menu_enter = {
		en = "Unique NPC Menu Entry SFX",
	},
	crafting_interact_forge_button = {
		en = "Shrine of the Omnissiah: Button Press",
	},
	crafting_interact_traits = {
		en = "Shrine of the Omnissiah: Blessings",
	},
	crafting_interact_perk_reroll = {
		en = "Shrine of the Omnissiah: Perk Reroll",
	},
	crafting_interact_upgrade = {
		en = "Shrine of the Omnissiah: Consecrate Item",
	},
	crafting_interact_empower = {
		en = "Shrine of the Omnissiah: Empower Item",
	},
	player_gas_cough = {
		en = "Coughing from Pox Gas",
	},
}

-- ################
-- Automatic Localization for Options
-- ################
local localizations_to_reuse = {
	armor_type = {
		super_armor = {
			en = "Carapace",
		},
	},
	damage_done = {
		no_damage = {
			en = "No Damage",
		},
		res = {
			en = "Damage Reduced",
		},
		armor = {
			en = "Armored Hit",
		},
		unarmor = {
			en = "Unarmored Hit",
		},
		armor_break = {
			en = "Armor Broken",
		},
		light = {
			en = "Light Attack",
		},
		heavy = {
			en = "Heavy Attack",
		},
	},
	-- Melee
	damage_type = {
		melee_slashing = {
			en = "Melee Slashing",
		},
		melee = {
			en = "Melee",
		},
	},
	melee_hits = {
		en = "Melee Hits",
	},
	melee_weapon_types = {
		blunt = {
			en = "Blunt",
		},
		sword = {
			en = "Sword",
		},
		axe = {
			en = "Axe",
		},
		knife = {
			en = "Knife",
		},
		human_punch = {
			en = "Human Punch",
		},
		ogryn_punch = {
			en = "Ogryn Punch",
		},
	},
	-- Ranged
	ranged_hits = {
		en = "Ranged Hits",
	},
	ranged_weapon_types = {
		gen = {
			en = "General",
		},
		laser = {
			en = "Laser",
		},
	},
}
localizations_to_reuse.damage_done.armored = localizations_to_reuse.damage_done.armor
localizations_to_reuse.damage_done.unarmored = localizations_to_reuse.damage_done.unarmor

-- Automatic localization formatting
-- 	since these have certain patterns, I'm doing it like this instead of pasting it over and over again
--	these localize the keys found in SoundsToMute.lua
--  they will create more localizations than necessary, but that is no problem
for damage_done, damage_done_localization in pairs(localizations_to_reuse.damage_done) do
	-- -------------------------
	-- Carapace negation
	-- -------------------------
	for armor_type, armor_type_localization in pairs(localizations_to_reuse.armor_type) do
		for damage_type, damage_type_localization in pairs(localizations_to_reuse.damage_type) do
			localizations["melee_hits_"..armor_type.."_"..damage_done.."_"..damage_type] = {
				-- super_armor_no_damage_melee_slashing = "Carapace: No Damage (Melee Slashing)"
				en = armor_type_localization["en"]..": "..damage_done_localization["en"].." ("..damage_type_localization["en"]..")"
			}
		end 
	end 
	-- -------------------------
	-- Melee hits against armor
	-- -------------------------
	for weapon_type, weapon_type_localization in pairs(localizations_to_reuse.melee_weapon_types) do
		localizations["melee_hits_"..damage_done.."_"..weapon_type] = {
			-- melee_hits_blunt_no_damage = "Melee Hit: No Damage (Blunt)"
			en = localizations_to_reuse.melee_hits["en"]..": "..damage_done_localization["en"].." ("..weapon_type_localization["en"]..")"
		}
	end
	-- -------------------------
	-- Ranged hits against armor
	-- -------------------------
	for weapon_type, weapon_type_localization in pairs(localizations_to_reuse.ranged_weapon_types) do
		localizations["ranged_hits_"..damage_done.."_"..weapon_type] = {
			-- ranged_hits_laser_no_damage = "Ranged Hit: No Damage (Laser)"
			en = localizations_to_reuse.ranged_hits["en"]..": "..damage_done_localization["en"].." ("..weapon_type_localization["en"]..")"
		}
	end
end 

return localizations