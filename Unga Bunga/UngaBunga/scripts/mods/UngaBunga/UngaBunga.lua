local mod = get_mod("UngaBunga")

-- Shared locals
local EMPTY_TABLE = {}
local cave_t = 0
local holding_primary = false
local hurty_stick = nil

-- Attack Keybind locals
local attack_bind = {}
local attack_bind_toggle = {}
local alt_attack = false
local alt_attack_toggle = false

-- Cancel Locals
local cancel_toggle_bind = {}
local cancel_toggle_bind_held = {}
local can_cancel = false
local cancel_mode = "special"
local cancel_override = false

-- Thrust locals
local in_thrust_we_trust = false
local stacks = 0

-- Mod Settings locals
local toggle_bind = {}
local mod_enabled = true
local verbose = false
local global = {
	max_stacks = 0,
	max_special_stacks = 0,
	split_specials = false,
	block_cancel = false, -- defunct, but kept for compatibility
	cancel = false,
	cancel_mode = "block"
}
local settings = {
	max_stacks = 0,
	max_special_stacks = 0,
	split_specials = false,
	block_cancel = false, -- defunct, but kept for compatibility
	cancel = false,
	cancel_mode = "block"
}
local weapons = {
	-- Chainaxe
	chainaxe_p1_m1                   = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	chainaxe_p1_m2                   = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Chainsword
	chainsword_p1_m1                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	chainsword_p1_m2                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Eviscerator
	chainsword_2h_p1_m1              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	chainsword_2h_p1_m2              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Combat Axe
	combataxe_p1_m1                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p1_m2                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p1_m3                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Tactical Axe
	combataxe_p2_m1                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p2_m2                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p2_m3                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Sapper Shovel
	combataxe_p3_m1                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p3_m2                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combataxe_p3_m3                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Cleaver
	ogryn_combatblade_p1_m1          = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_combatblade_p1_m2          = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_combatblade_p1_m3          = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Combat Knife
	combatknife_p1_m1                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatknife_p1_m2                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Devil's Claw
	combatsword_p1_m1                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p1_m2                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p1_m3                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Heavy Sword
	combatsword_p2_m1                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p2_m2                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p2_m3                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Duelling Sword
	combatsword_p3_m1                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p3_m2                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	combatsword_p3_m3                = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Force Sword
	forcesword_p1_m1                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	forcesword_p1_m2                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	forcesword_p1_m3                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Force Greatsword
	forcesword_2h_p1_m1              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	forcesword_2h_p1_m2              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Grenadier Gauntlet
	ogryn_gauntlet_p1_m1             = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Latrine Shovel
	ogryn_club_p1_m1                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_club_p1_m2                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_club_p1_m3                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Bully Club
	ogryn_club_p2_m1                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_club_p2_m2                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_club_p2_m3                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Pickaxe
	ogryn_pickaxe_2h_p1_m1           = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_pickaxe_2h_p1_m2           = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_pickaxe_2h_p1_m3           = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Power Maul
	ogryn_powermaul_p1_m1            = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_powermaul_p1_m2            = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	ogryn_powermaul_p1_m3            = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Slab Shield
	ogryn_powermaul_slabshield_p1_m1 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Shock Maul
	powermaul_p1_m1                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	powermaul_p1_m2                  = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Crusher
	powermaul_2h_p1_m1               = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Power Sword
	powersword_p1_m1                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	powersword_p1_m2                 = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Relic Sword
	powersword_2h_p1_m1              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	powersword_2h_p1_m2              = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	-- Thunder Hammer
	thunderhammer_2h_p1_m1           = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
	thunderhammer_2h_p1_m2           = { weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false },
}

-- Weapons with incorrect chain times
local INCORRECT_TIMES = {
	ogryn_powermaul_slabshield_p1_m1 = {
		action_right_heavy = {
			incorrect = 0.35,
			also_incorrect = 0.4,
			correct = 0.5,
			also_correct = 0.45
		}
	},
	ogryn_club_p2_m3 = {
		action_right_heavy = {
			incorrect = 0.5,
			correct = 0.55,
		}
	},
	combataxe_p2_m3 = {
		action_left_heavy = {
			incorrect = 0.25,
			correct = 0.3,
		}
	},
	powermaul_2h_p1_m1 = {
		action_right_heavy = {
			prev_incorrect = 0.35,
			prev_action = "action_left_light_pushfollow",
			prev_correct = 0.45,
		}
	}
}

-- Weapons with special actions incompatible with cancelling
local banned = {
	-- Gauntlet
	ogryn_gauntlet_p1_m1 = true,
	-- Shield
	ogryn_powermaul_slabshield_p1_m1 = true,
	-- Chain weapons
	chainaxe_p1_m1 = true,
	chainaxe_p1_m2 = true,
	chainsword_p1_m1 = true,
	chainsword_p1_m2 = true,
	chainsword_2h_p1_m1 = true,
	chainsword_2h_p1_m2 = true,
	-- Relic Blades
	powersword_2h_p1_m1 = true,
	powersword_2h_p1_m2 = true,
	-- Shovels (folding)
	ogryn_club_p1_m2 = true,
	ogryn_club_p1_m3 = true,
	combataxe_p3_m2 = true,
	combataxe_p3_m3 = true,
}

-- Weapons with damage window timings that do not align with chain timings
local broken = {
	-- Combat Knives
	combatknife_p1_m1 = true,
	combatknife_p1_m2 = true,
	-- Power Swords
	powersword_p1_m1 = true,
	powersword_p1_m2 = true,
	-- Cleaver Mk IV
	ogryn_combatblade_p1_m1 = true,
}

local INCORRECT_WINDOWS = {
	-- Combat Knife
	combatknife_p1_m1 = {
		action_left_heavy = {
			incorrect = 0.46666666666667,
			special = 0.25,
		},
		action_left_heavy_jab_combo = {
			incorrect = 0.46666666666667,
			special = 0.42,
		}
	},
	combatknife_p1_m2 = {
		action_left_heavy = {
			incorrect = 0.4,
			special = 0.25,
		},
		action_left_heavy_jab_combo = {
			incorrect = 0.46666666666667,
			special = 0.32,
		}
	},
	-- Power Sword
	powersword_p1_m1 = {
		action_left_heavy = {
			incorrect = 0.33333333333333,
			special = 0.25,
			block = 0.25,
		},
		action_right_heavy = {
			incorrect = 0.33333333333333,
			special = 0.25,
		}
	},
	powersword_p1_m2 = {
		action_left_heavy = {
			incorrect = 0.3,
			special = 0.20,
			block = 0.25,
		},
	},
	-- Cleaver Mk IV
	ogryn_combatblade_p1_m1 = {
		action_right_heavy = {
			incorrect = 0.3,
			special = 0.25,
		}
	},
}

-- debug local
local debug = nil

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       DMF FUNCTIONS        │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Get settings on mod load
mod.on_all_mods_loaded = function()
	-- Global Group settings
	for key, value in pairs(global) do
		if mod:get(key) == nil then
			mod:set(key, global[key], false)
		else
			global[key] = mod:get(key)
		end
	end
	-- Weapon Specific Group settings
	for key, value in pairs(weapons) do
		if mod:get(key) == nil then
			mod:set(key, {weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false})
		else
			weapons[key] = mod:get(key)
		end
		-- Compatibility check for older versions updating to new cancel settings - might not be necessary but shouldn't cause issues and may prevent crashes
		if weapons[key].weapon_cancel_mode == nil then
			weapons[key].weapon_cancel_mode = "block"
			mod:set(key, weapons[key], false)
		end
	end
	-- Individual Global settings
	toggle_bind = mod:get("toggle_bind")
	mod_enabled = mod:get("enabled")
	verbose = mod:get("verbose")
	attack_bind = mod:get("attack_bind")
	--attack_bind_toggle = mod:get("attack_bind_toggle")
	cancel_toggle_bind = mod:get("cancel_toggle")
	cancel_toggle_bind_held = mod:get("cancel_toggle_held")
end

-- Settings handler
mod.on_setting_changed = function(id)
	-- Normal settings
	if global[id] ~= nil then
		global[id] = mod:get(id)
	-- Reset "button" for weapon settings
	elseif id == "reset" then
		-- Reset if reset is switched to "On"
		if mod:get(id) then
			for key, value in pairs(weapons) do
				weapons[key] = {weapon_enabled = false, weapon_block_cancel = false, weapon_cancel = false, weapon_cancel_mode = "block", weapon_max_stacks = 0, weapon_max_special_stacks = 0, weapon_split_specials = false}
				mod:set(key, weapons[key], false)
			end
			mod:set("weapon_selector", "chainaxe_p1_m1", false)
			mod:set("weapon_enabled", false, false)
			mod:set("weapon_block_cancel", false, false)
			mod:set("weapon_cancel", false, false)
			mod:set("weapon_cancel_mode", "block", false)
			mod:set("weapon_max_stacks", 0, false)
			mod:set("weapon_max_special_stacks", 0, false)
			mod:set("weapon_split_specials", false, false)
			mod:set(id, false, false)
		end
	-- Weapon settings
	elseif id == "weapon_selector" then
		local temp_weapon = mod:get("weapon_selector")
		mod:set("weapon_enabled", weapons[temp_weapon].weapon_enabled, false)
		mod:set("weapon_block_cancel", weapons[temp_weapon].weapon_block_cancel, false)
		mod:set("weapon_cancel", weapons[temp_weapon].weapon_cancel, false)
		mod:set("weapon_cancel_mode", weapons[temp_weapon].weapon_cancel_mode, false)
		mod:set("weapon_max_stacks", weapons[temp_weapon].weapon_max_stacks, false)
		mod:set("weapon_max_special_stacks", weapons[temp_weapon].weapon_max_special_stacks, false)
		mod:set("weapon_split_specials", weapons[temp_weapon].weapon_split_specials, false)
	elseif string.find(id, "weapon_") ~= nil then
			local temp_weapon = mod:get("weapon_selector")
			weapons[temp_weapon][id] = mod:get(id)
			mod:set(temp_weapon, weapons[temp_weapon], false)
	else
		-- Individual Global settings
		if id == "enabled" then
			mod_enabled = mod:get(id)
		elseif id == "verbose" then
			verbose = mod:get(id)
		elseif id == "toggle_bind" then
			toggle_bind = mod:get(id)
		elseif id == "attack_bind" then
			attack_bind = mod:get(id)
		elseif id == "attack_bind_toggle" then
			--attack_bind_toggle = mod:get(id)
		elseif id == "cancel_toggle_bind" then
			cancel_toggle_bind = mod:get(id)
		elseif id == "cancel_toggle_bind_held" then
			cancel_toggle_bind_held = mod:get(id)
		end
	end
end

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │      CUSTOM FUNCTIONS      │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- CAN THIS WEAPON HEAVY ATTACK?
mod.unga = function()
	local bonehead = false
	local manager = Managers.player
	-- If we have a player unit
	if manager and manager:local_player_safe(1) then
		local unit = manager:local_player(1).player_unit
		-- And that unit has a weapon
		if unit and ScriptUnit.has_extension(unit, "weapon_system") then
			local weapon = ScriptUnit.extension(unit, "weapon_system")
			local inventory = weapon._inventory_component
			local wielded_weapon = weapon:_wielded_weapon(inventory, weapon._weapons)
			if wielded_weapon then
				local weapon_template = wielded_weapon and wielded_weapon.weapon_template
				local actions = weapon_template and weapon_template.actions
				-- And that weapon has any heavy attack actions
				if actions then
					for key, value in pairs(actions) do
						if string.find(key, "heavy") then
							bonehead = true
							break
						end
					end
				end
				-- Set thrust
				in_thrust_we_trust = false
				local traits = wielded_weapon and wielded_weapon.item and wielded_weapon.item.__master_item and wielded_weapon.item.__master_item.traits
				if traits then
					-- Set weapon while we're here
					hurty_stick = wielded_weapon.item.__master_item.weapon_template
					for _, trait_data in ipairs(traits) do
						local trait = trait_data.id
						if string.find(trait, "power_bonus_based_on_charge_time") or string.find(trait, "toughness_on_hit_based_on_charge_time") then
							in_thrust_we_trust = true
							break
						end
					end
				end
				-- Set current settings
				if weapons[hurty_stick] and weapons[hurty_stick].weapon_enabled then
					-- Use weapon-specific settings
					settings.block_cancel = weapons[hurty_stick].weapon_block_cancel
					settings.cancel = weapons[hurty_stick].weapon_cancel
					settings.cancel_mode = weapons[hurty_stick].weapon_cancel_mode
					settings.max_stacks = weapons[hurty_stick].weapon_max_stacks
					settings.max_special_stacks = weapons[hurty_stick].weapon_max_special_stacks
					settings.split_specials = weapons[hurty_stick].weapon_split_specials
				else
					-- Use global settings
					settings.block_cancel = global.block_cancel
					settings.cancel = global.cancel
					settings.cancel_mode = global.cancel_mode
					settings.max_stacks = global.max_stacks
					settings.max_special_stacks = global.max_special_stacks
					settings.split_specials = global.split_specials
				end
				-- Cancel override
				if cancel_override then
					settings.cancel = not settings.cancel	
				end
				debug = {settings, global, weapons[hurty_stick] or "No Weapon"}
			end
		end
	end
	return bonehead
end

-- CAN WE HEAVY ATTACK RIGHT NOW?
mod.bunga = function(club)
	-- Short-circuit if not attacking
	if not club then
		return club
	end
	local player_unit = Managers.player:local_player(1).player_unit
	local unit_data = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
	local handler = weapon_ext._action_handler
	local handler_data = handler._registered_components.weapon_action
	local component_data = handler_data and handler_data.component and handler_data.component.__data and handler_data.component.__data[1]
	local combo = component_data and component_data.combo_count
	local previous = component_data and component_data.previous_action_name
	local running_action = handler_data.running_action
	
	-- If we are in the middle of an attack windup
	if running_action then
		local action_settings = running_action:action_settings()
		local allowed_chain_actions = action_settings.allowed_chain_actions or EMPTY_TABLE
		local chain_action = allowed_chain_actions.heavy_attack
		local chain_action_name = chain_action and chain_action.action_name
		-- And that attack could theoretically transition into a heavy attack
		if chain_action then
			local component = handler_data.component
			local special_stick = component.special_active_at_start
			local start_t = component.start_t
			local time_scale = component.time_scale
			local current_action_t = cave_t - start_t
			local running_action_state = running_action:running_action_state(cave_t, current_action_t)
			local chain_time, chain_until, chain_validated
			-- Check the time requirements for the heavy attack
			local chain_time = chain_action.chain_time
			-- Manual correction for some wonky chain actions (must be handled prior to accounting for time scale)
			if INCORRECT_TIMES[hurty_stick] and INCORRECT_TIMES[hurty_stick][chain_action_name] then
				-- Weapons with one incorrect time
				local incorrect_time = INCORRECT_TIMES[hurty_stick][chain_action_name].incorrect or 0
				local also_incorrect_time = INCORRECT_TIMES[hurty_stick][chain_action_name].also_incorrect or 0
				-- Weapons with two incorrect times
				local correct_time = INCORRECT_TIMES[hurty_stick][chain_action_name].correct or 0
				local also_correct_time = INCORRECT_TIMES[hurty_stick][chain_action_name].also_correct or 0
				-- Weapons with conditionally incorrect times based on previous actions
				local prev_incorrect_time = INCORRECT_TIMES[hurty_stick][chain_action_name].prev_incorrect or 0
				local prev_correct_time = INCORRECT_TIMES[hurty_stick][chain_action_name].prev_correct or "ignore"
				local prev_action = INCORRECT_TIMES[hurty_stick][chain_action_name].prev_action or 0

				-- Weapons with one incorrect time: Tac Axe MkVII, Bully Club MkIIIb
				if chain_time == incorrect_time then
					chain_time = correct_time
				-- Weapons with two incorrect times: Slab Shield
				elseif chain_time == also_incorrect_time then
					chain_time = also_correct_time
				-- Weapons with conditionally incorrect times: Crusher
				elseif previous == prev_action and chain_time == prev_incorrect_time then
					chain_time = prev_correct_time
				end
			end		

			--------------------------------------------------------------------------------------------------------------------
			-- Debug: Print chain action time requirements (useful for finding incorrect times)
			--mod:echo("Template: %s, Action: %s, Time: %s, Previous: %s", hurty_stick, chain_action_name, chain_time, previous)
			--------------------------------------------------------------------------------------------------------------------

			chain_validated = not chain_time or (chain_time and chain_time < current_action_t or not not chain_until and current_action_t < chain_until) and true
			local running_action_state_requirement = chain_action.running_action_state_requirement
			if running_action_state_requirement and (not running_action_state or not running_action_state_requirement[running_action_state]) then
				chain_validated = false
			end
			local override = false
			-- Thrust
			if in_thrust_we_trust then
				-- Special actions take priority
				if special_stick and settings.split_specials then
					if stacks < settings.max_special_stacks then
						override = true
					end
				elseif stacks < settings.max_stacks then
					override = true
				end
			end
			-- Release input if ready for a heavy and not waiting for Thrust, otherwise hold
			local action_is_validated = chain_validated and not override
			return not action_is_validated
		end
	end
	return club
end

-- Mod Toggle keybind
mod.toggle = function()
	if not Managers.ui:using_input() then
		mod:set("enabled", not mod:get("enabled"), false)
		mod_enabled = mod:get("enabled")
		if verbose then
			mod:echo("Auto-heavy %s.", mod_enabled and "enabled" or "disabled")
		end
	end
end

-- Mod Toggle keybind (held)
mod.toggle_silent = function()
	mod:set("enabled", not mod:get("enabled"), false)
	mod_enabled = mod:get("enabled")
end

-- Attack keybind
mod.attack = function()
	alt_attack = not alt_attack
end

-- WIP
mod.attack_toggle = function()
	mod:echo("huh")
	if not Managers.ui:using_input() then
		alt_attack = not alt_attack
		mod:echo("Bind: %s, Alt: %s",attack_bind_toggle[1], alt_attack)
		if verbose then
			mod:echo("Auto-heavy Toggle %s.", alt_attack and "enabled" or "disabled")
		end
	end
end

-- Cancel keybind
mod.toggle_cancel = function()
	if not Managers.ui:using_input() then
		if weapons[hurty_stick] and weapons[hurty_stick].weapon_enabled then
			weapons[hurty_stick].weapon_cancel = not weapons[hurty_stick].weapon_cancel
			-- Update UI if weapon is selected
			if mod:get("weapon_selector") == hurty_stick then
				mod:set("weapon_cancel", weapons[hurty_stick].weapon_cancel, false)
				settings.cancel = weapons[hurty_stick].weapon_cancel
			end
			if verbose then
				mod:echo("Heavy-Cancel %s.", weapons[hurty_stick].weapon_cancel and "enabled" or "disabled")
			end
		else
			mod:set("cancel", not mod:get("cancel"), false)
			global.cancel = mod:get("cancel")
			settings.cancel = global.cancel
			if verbose then
				mod:echo("Heavy-Cancel %s.", mod:get("cancel") and "enabled" or "disabled")
			end
		end
	end
end

-- Cancel keybind (held)
mod.toggle_cancel_silent = function()
	cancel_override = not cancel_override
end


-- ┌────────────────────────────┐ --
-- │                            │ --
-- │         SAFE HOOKS         │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Get ActionHandler's update time for heavy checking and real-time special status
mod:hook_safe(CLASS.ActionHandler, "update", function (self, dt, t)
	cave_t = t
end)

-- Check thrust stacks if present
mod:hook_safe("SteppedStatBuff","update_stat_buffs",function(self, current_stat_buffs, t)
    local buffs = self._template_context.buff_extension._buffs
	for index, value in ipairs (buffs) do
		local name = buffs[index]._template.name
		if string.find(name,"windup_increases_power_child") ~= nil or string.find(name, "toughness_on_hit_based_on_charge_time") ~= nil then
			stacks = buffs[index]._template_context.stack_count - 1
			break
		end
	end
end)

-- Cancellation flag management for heavies and special attacks
mod:hook_safe(CLASS.ActionSweep, "_exit_damage_window", function (self, t, num_hit_enemies, aborted)
	local action_settings = self._action_settings
	local name = action_settings and action_settings.name
	if name then
		-- Allow cancellation upon completion of a heavy attack
		if string.find(name, "heavy") then
			-- Ignore this cancellation flag for weapons with fucked up window timings
			if settings.cancel_mode == "block" and settings.cancel then
				if not broken[hurty_stick] then
					can_cancel = true
				end
			elseif settings.cancel_mode == "special" and settings.cancel then
				if not broken[hurty_stick] and not banned[hurty_stick] then
					can_cancel = true
				end
			end
		-- Revert to standard behavior upon completion of a special attack
		elseif string.find(name, "special") then
			can_cancel = false
		end
	end
	
end)

-- Cancellation flag management for special activations
mod:hook_safe(CLASS.ActionActivateSpecial, "fixed_update", function (self, dt, t, time_in_action)
	local EPSILON = 1e-05
	-- Determine time needed to trigger special active state
	local action_settings = self._action_settings
	local activation_time = action_settings.activation_time
	-- Get frame data for time check
	local fixed_time_step = Managers.state.game_session.fixed_time_step
	local first_trigger_time_fixed = math.round(activation_time / fixed_time_step) * fixed_time_step
	local first_trigger_diff = math.abs(time_in_action - first_trigger_time_fixed)
	-- Determine state
	local first_trigger_frame = first_trigger_diff < EPSILON
	local past_first_trigger = not first_trigger_frame and first_trigger_time_fixed < time_in_action
	-- Revert to standard behavior upon activation
	if first_trigger_frame or past_first_trigger then
		can_cancel = false
	end
end)

-- Cancellation flag management for broken weapons
mod:hook_safe(CLASS.ActionSweep, "fixed_update", function (self, dt, t, time_in_action)
	local action_settings = self._action_settings
	local name = action_settings and action_settings.name
	if string.find(name, "heavy") and settings.cancel then
		if broken[hurty_stick] then
			local damage_window_start = action_settings.damage_window_start
			local damage_window_end = action_settings.damage_window_end
			local action_time_offset = action_settings.action_time_offset or 0
			local time_scale = self._weapon_action_component.time_scale
			-- Manual Window Adjustments >:(
			if settings.cancel_mode == "special" and INCORRECT_WINDOWS[hurty_stick] and INCORRECT_WINDOWS[hurty_stick][name] then
				damage_window_end = INCORRECT_WINDOWS[hurty_stick][name].special or damage_window_end
			elseif settings.cancel_mode == "block" and INCORRECT_WINDOWS[hurty_stick] and INCORRECT_WINDOWS[hurty_stick][name] then
				damage_window_end = INCORRECT_WINDOWS[hurty_stick][name].block or damage_window_end
			end
			-- Attack Speed Compensation
			damage_window_start = damage_window_start / time_scale
			damage_window_end = damage_window_end / time_scale
			action_time_offset = action_time_offset / time_scale
			time_in_action = time_in_action + action_time_offset
			local ready = time_in_action >= damage_window_end

			---------------------------------------------------------------------------------------------------------
			-- Debug: Prints damage window timing + attack name (useful for finding incorrect windows)
			-- mod:echo("Weapon: %s, Attack: %s, End Time: %s", hurty_stick, name, action_settings.damage_window_end)
			---------------------------------------------------------------------------------------------------------

			if ready then
				can_cancel = true
			end
		end
	end
end)

-- ┌────────────────────────────┐ --
-- │                            │ --
-- │       STANDARD HOOKS       │ --
-- │                            │ --
-- └────────────────────────────┘ --

-- Input interception
mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
    if action_name == "action_one_hold" then
        -- Get primary input and set holding_primary flag
        local worker = false
        local action_rule = self._actions[action_name]
		local action_type = action_rule.type
		local combiner = InputService.ACTION_TYPES[action_type].combine_func
		for _, cb in ipairs(action_rule.callbacks) do
			worker = combiner(worker, cb())
		end
        holding_primary = worker
		
		if mod_enabled == true then
			-- Standard input
			if not attack_bind[1] then
				-- Reset cancellation flag when not holding attack
				if not holding_primary then
					can_cancel = false
				end
				-- Forcibly disable attack input when cancelling to prevent deadlock between attack input and special input
				if settings.cancel and can_cancel and mod.unga() then
					return false
				end
				if holding_primary and mod.unga() then
					local caveman = mod.bunga(holding_primary)
					if caveman ~= holding_primary then
						return caveman
					end
				end
			-- Custom input
			else 
				-- Reset cancellation flag when not holding attack
				if not alt_attack then
					can_cancel = false
				end
				-- Forcibly disable attack input when cancelling to prevent deadlock between attack input and special input
				if settings.cancel and can_cancel and mod.unga() then
					return false
				end
				if not alt_attack then
					allowed_to_block = false
				elseif alt_attack and mod.unga() then
					local caveman = mod.bunga(alt_attack)
					return caveman
				end
			end
		end
    end
	if action_name == "action_two_hold" then
		if mod_enabled == true and mod.unga() and settings.cancel and holding_primary and can_cancel and settings.cancel_mode == "block" then
			local player_unit = Managers.player:local_player(1).player_unit
			local unit_data = ScriptUnit.has_extension(player_unit, "unit_data_system")
			local block_component = unit_data:read_component("block")
			local blocking = block_component.is_blocking
			if not blocking then
				return true
			-- Revert to standard behavior once blocking is active for block cancelling
			else
				can_cancel = false
			end
		end
	end
	if action_name == "weapon_extra_pressed" then
		if mod_enabled == true and mod.unga() and settings.cancel and holding_primary and can_cancel and settings.cancel_mode == "special" then
			local player_unit = Managers.player:local_player(1).player_unit
			local unit_data = ScriptUnit.has_extension(player_unit, "unit_data_system")
			local block_component = unit_data:read_component("block")
			local blocking = block_component.is_blocking
			local perfect = block_component.is_perfect_blocking
			-- Revert to standard behavior after perfect window of parries for special cancelling
			if blocking and not perfect then
				can_cancel = false
			end
			return true
		end
	end
    return func(self, action_name)
end)

-- ┌───────────────────┐ --
-- │                   │ --
-- │       DEBUG       │ --
-- │                   │ --
-- └───────────────────┘ --

mod.debug = function()
	if type(debug) == "table" then
		mod:dtf(debug)
		mod:echo("Debug table sent to inspector")
	elseif debug then
		mod:echo(debug)
	else
		mod:echo("Debug var is nil")
	end
end