local mod = get_mod("testing_utilities")

local mod_data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
}

mod.dt_buff_applied = true
mod.dt_buff_stacks = ""

mod.dt_marty_applied = false
mod.dt_marty_stacks = ""

mod_data.options = {
	widgets = {
		{	["setting_id"] = "group_buff_properties",
			["type"] = "group",
			["sub_widgets"] = {
				{ -- Toggle Infinite Buffs
					["setting_id"] = "toggle_infinite_buffs",
					["type"] = "checkbox",
					["default_value"] = false, -- Deflault first option is enabled. In this case false
					["tooltip"] = "infinite_buffs_tooltip"
				},			
				{ -- Slider for Desired Disrupt Destiny Buff Stacks
					["setting_id"] = "desired_DD_stacks",
					["type"] = "numeric",
					["default_value"] = 15,
					["range"] = {1, 25},
					["decimals_number"] = 0,
					["title"] = "desired_DD_stacks",
					["tooltip"] = "buff_slider_tooltip"
				},			
				{ -- Slider for Desired Warp Siphon Buff Stacks
					["setting_id"] = "desired_WS_stacks",
					["type"] = "numeric",
					["default_value"] = 6,
					["range"] = {1, 6},
					["decimals_number"] = 0,
					["title"] = "desired_WS_stacks",
					["tooltip"] = "buff_slider_tooltip"
				},	
				{ -- Slider for Desired Inexorable Judgment Buff Stacks
					["setting_id"] = "desired_IJ_stacks",
					["type"] = "numeric",
					["default_value"] = 15,
					["range"] = {1, 15},
					["decimals_number"] = 0,
					["title"] = "desired_IJ_stacks",
					["tooltip"] = "buff_slider_tooltip"
				},
				{ -- Slider for Desired Wounds of Health Remaining
					["setting_id"] = "desired_wounds_remaining",
					["type"] = "numeric",
					["default_value"] = 2,
					["range"] = {1, 7},
					["decimals_number"] = 0,
					["title"] = "desired_wounds_remaining",
					["tooltip"] = "desired_wounds_tooltip"
				},
				{ -- Toggle 100% HP w/out Martyrdom
					["setting_id"] = "toggle_non_marty_hp",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					["tooltip"] = "non_marty_hp_tooltip"
				}								
			}
		},

		{	["setting_id"] = "group_reset_functions",
			["type"] = "group",
			["sub_widgets"] = {
				{ -- Keybind to Reset Character
					["setting_id"] = "keybind_reset_character",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Reset_Character"
				},
				{ -- Keybind to Remove Mod Buffs
					["setting_id"] = "keybind_remove_buffs",
					["type"] = "keybind",
					["keybind_trigger"] = "pressed",
					["keybind_type"] = "function_call",
					["default_value"] = {},
					["function_name"] = "Remove_Mod_Buffs",
					["tooltip"] = "remove_buffs_tooltip"
				},				
				{ -- Toggle Set Buffs
					["setting_id"] = "toggle_buff_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				},
				{ -- Toggle Set Health
					["setting_id"] = "toggle_health_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				},			
				{ -- Toggle Set Toughness
					["setting_id"] = "toggle_toughness_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				},
				{ -- Toggle Set Combat Ability
					["setting_id"] = "toggle_combat_ability_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case false
				},
				{ -- Toggle Set Grenade Ability
					["setting_id"] = "toggle_grenade_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case false
				},
				{ -- Toggle Set Peril
					["setting_id"] = "toggle_peril_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case false
				},
				{ -- Toggle Reset Weapon Heat
					["setting_id"] = "toggle_weapon_heat_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case false
				},	
				{ -- Toggle Reset Weapon Ammo
					["setting_id"] = "toggle_weapon_ammo_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case false
				},											
				{ -- Toggle Despawn All Units
					["setting_id"] = "toggle_despawn_units",
					["type"] = "checkbox",
					["default_value"] = false -- Default first option is enabled. In this case false
				},
				-- { -- Toggle 100% HP w/out Martyrdom
				-- 	["setting_id"] = "toggle_non_marty_hp",
				-- 	["type"] = "checkbox",
				-- 	["default_value"] = true -- Default first option is enabled. In this case true
				-- },				
				-- { -- Slider for Desired Wounds of Health Remaining
				-- 	["setting_id"] = "desired_wounds_remaining",
				-- 	["type"] = "numeric",
				-- 	["default_value"] = 2,
				-- 	["range"] = {1, 7},
				-- 	["decimals_number"] = 0,
				-- 	["title"] = "desired_wounds_remaining",
				-- }
				-- { -- Slider for Desired % of Toughness on Reset
				-- 	["setting_id"] = "desired_toughness_percentage",
				-- 	["type"] = "numeric",
				-- 	["default_value"] = 100,
				-- 	["range"] = {0, 100},
				-- 	["decimals_number"] = 0,
				-- 	["title"] = "desired_toughness_percentage",
				-- }						
			}		
		},

		{	["setting_id"] = "group_buff_toggles",
			["type"] = "group",
			["sub_widgets"] = {
				{ -- Toggle DD
					["setting_id"] = "toggle_DD_buff_handling",
					["type"] = "checkbox",
					["default_value"] = true, -- Default first option is enabled. In this case true
					-- ["tooltip"] = "infinite_buffs_tooltip"
				},
				{ -- Toggle Warp Siphon
					["setting_id"] = "toggle_WS_buff_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				},
				{ -- Toggle IJ
					["setting_id"] = "toggle_IJ_buff_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				},
				{ -- Toggle BP
					["setting_id"] = "toggle_BP_buff_handling",
					["type"] = "checkbox",
					["default_value"] = true -- Default first option is enabled. In this case true
				}					
				-- { -- Toggle Until Death
				-- 	["setting_id"] = "toggle_until_death_buff_handling",
				-- 	["type"] = "checkbox",
				-- 	["default_value"] = true -- Default first option is enabled. In this case true
				-- }											
			}
		},

		-- {	["setting_id"] = "group_misc_settings",
		-- 	["type"] = "group",
		-- 	["sub_widgets"] = {
		-- 		{ -- Report Variable Keybind
		-- 			["setting_id"] = "keybind_test_func_1",
		-- 			["type"] = "keybind",
		-- 			["keybind_trigger"] = "pressed",
		-- 			["keybind_type"] = "function_call",
		-- 			["default_value"] = {},
		-- 			["function_name"] = "test_func_1"
		-- 		},

		-- 		{ -- Report Variable Keybind
		-- 			["setting_id"] = "test_func_2",
		-- 			["type"] = "keybind",
		-- 			["keybind_trigger"] = "pressed",
		-- 			["keybind_type"] = "function_call",
		-- 			["default_value"] = {},
		-- 			["function_name"] = "test_func_2"
		-- 		}								
		-- 	}
		-- }
	}
}

return mod_data	
