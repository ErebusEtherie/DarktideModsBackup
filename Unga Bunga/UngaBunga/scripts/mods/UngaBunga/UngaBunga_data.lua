local mod = get_mod("UngaBunga")

return {
	name         = mod:localize("mod_name"),
	description  = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			--[[ Debug ]
			{
				setting_id      = "debug",
				type            = "keybind",
				default_value   = {},
				keybind_trigger = "pressed",
				keybind_type    = "function_call",
				function_name   = "debug",
			},
			--]]
			{
				setting_id  = "global",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "enabled",
						type          = "checkbox",
						default_value = true
					},
					{
						setting_id    = "verbose",
						type          = "checkbox",
						tooltip       = "verbose_tooltip",
						default_value = false
					},
					--[[ Deprecated ]
					{
						setting_id    = "block_cancel",
						type          = "checkbox",
						tooltip       = "block_cancel_tooltip",
						default_value = false
					},
					--]]
					{
						setting_id    = "cancel",
						type          = "checkbox",
						tooltip       = "cancel_tooltip",
						default_value = false
					},
					{
						setting_id    = "cancel_mode",
						type          = "dropdown",
						default_value = "block",
						options = {
							{text = "block", value = "block"},
							{text = "special", value = "special"}
						}
					},
					{
						setting_id    = "max_stacks",
						type          = "numeric",
						tooltip       = "thrust_tooltip",
						default_value = 0,
						range         = {0, 3},
						unit_text     = "stacks"
					},
					{
						setting_id    = "split_specials",
						type          = "checkbox",
						tooltip       = "split_specials_tooltip",
						default_value = false
					},
					{
						setting_id    = "max_special_stacks",
						type          = "numeric",
						tooltip       = "thrust_special_tooltip",
						default_value = 0,
						range         = {0, 3},
						unit_text     = "special_stacks"
					}
				}
			},
			{
				setting_id  = "keybinds",
				type	    = "group",
				sub_widgets = {
					{
						setting_id      = "toggle_bind",
						type            = "keybind",
						tooltip         = "toggle_bind_tooltip",
						default_value   = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "toggle"
					},
					{
						setting_id      = "toggle_bind_held",
						type            = "keybind",
						tooltip         = "toggle_bind_held_tooltip",
						default_value   = {},
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "toggle_silent"
					},
					{
						setting_id      = "cancel_toggle_bind",
						type            = "keybind",
						tooltip         = "cancel_toggle_bind_tooltip",
						default_value   = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "toggle_cancel"
					},
					{
						setting_id      = "cancel_toggle_bind_held",
						type            = "keybind",
						tooltip         = "cancel_toggle_bind_held_tooltip",
						default_value   = {},
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "toggle_cancel_silent"
					},
					--[[ WIP ]
					{
						setting_id      = "attack_bind_toggle",
						type            = "keybind",
						default_value   = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "attack_toggle"
					},
					--]]
					{
						setting_id      = "attack_bind",
						type            = "keybind",
						tooltip		    = "attack_bind_tooltip",
						default_value   = {},
						keybind_trigger = "held",
						keybind_type    = "function_call",
						function_name   = "attack"
					},
					
				}
			},
			{
				setting_id  = "per_weapon",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "weapon_selector",
						type          = "dropdown",
						default_value = "chainaxe_p1_m1",
						options = {
							--[[]]
							-- Chainaxe
							{text = "chainaxe_p1_m1", value = "chainaxe_p1_m1"},
							{text = "chainaxe_p1_m2", value = "chainaxe_p1_m2"},
							-- Chainsword
							{text = "chainsword_p1_m1", value = "chainsword_p1_m1"},
							{text = "chainsword_p1_m2", value = "chainsword_p1_m2"},
							-- Eviscerator
							{text = "chainsword_2h_p1_m1", value = "chainsword_2h_p1_m1"},
							{text = "chainsword_2h_p1_m2", value = "chainsword_2h_p1_m2"},
							-- Combat Axe
							{text = "combataxe_p1_m1", value = "combataxe_p1_m1"},
							{text = "combataxe_p1_m2", value = "combataxe_p1_m2"},
							{text = "combataxe_p1_m3", value = "combataxe_p1_m3"},
							-- Tactical Axe
							{text = "combataxe_p2_m1", value = "combataxe_p2_m1"},
							{text = "combataxe_p2_m2", value = "combataxe_p2_m2"},
							{text = "combataxe_p2_m3", value = "combataxe_p2_m3"},
							-- Sapper Shovel
							{text = "combataxe_p3_m1", value = "combataxe_p3_m1"},
							{text = "combataxe_p3_m2", value = "combataxe_p3_m2"},
							{text = "combataxe_p3_m3", value = "combataxe_p3_m3"},
							-- Cleaver
							{text = "ogryn_combatblade_p1_m1", value = "ogryn_combatblade_p1_m1"},
							{text = "ogryn_combatblade_p1_m2", value = "ogryn_combatblade_p1_m2"},
							{text = "ogryn_combatblade_p1_m3", value = "ogryn_combatblade_p1_m3"},
							-- Combat Knife
							{text = "combatknife_p1_m1", value = "combatknife_p1_m1"},
							{text = "combatknife_p1_m2", value = "combatknife_p1_m2"},
							-- Devil's Claw
							{text = "combatsword_p1_m1", value = "combatsword_p1_m1"},
							{text = "combatsword_p1_m2", value = "combatsword_p1_m2"},
							{text = "combatsword_p1_m3", value = "combatsword_p1_m3"},
							-- Heavy Sword
							{text = "combatsword_p2_m1", value = "combatsword_p2_m1"},
							{text = "combatsword_p2_m2", value = "combatsword_p2_m2"},
							{text = "combatsword_p2_m3", value = "combatsword_p2_m3"},
							-- Duelling Sword
							{text = "combatsword_p3_m1", value = "combatsword_p3_m1"},
							{text = "combatsword_p3_m2", value = "combatsword_p3_m2"},
							{text = "combatsword_p3_m3", value = "combatsword_p3_m3"},
							-- Force Sword
							{text = "forcesword_p1_m1", value = "forcesword_p1_m1"},
							{text = "forcesword_p1_m2", value = "forcesword_p1_m2"},
							{text = "forcesword_p1_m3", value = "forcesword_p1_m3"},
							-- Force Greatsword
							{text = "forcesword_2h_p1_m1", value = "forcesword_2h_p1_m1"},
							{text = "forcesword_2h_p1_m2", value = "forcesword_2h_p1_m2"},
							-- Grenadier Gauntlet
							{text = "ogryn_gauntlet_p1_m1", value = "ogryn_gauntlet_p1_m1"},
							-- Latrine Shovel
							{text = "ogryn_club_p1_m1", value = "ogryn_club_p1_m1"},
							{text = "ogryn_club_p1_m2", value = "ogryn_club_p1_m2"},
							{text = "ogryn_club_p1_m3", value = "ogryn_club_p1_m3"},
							-- Bully Club
							{text = "ogryn_club_p2_m1", value = "ogryn_club_p2_m1"},
							{text = "ogryn_club_p2_m2", value = "ogryn_club_p2_m2"},
							{text = "ogryn_club_p2_m3", value = "ogryn_club_p2_m3"},
							-- Pickaxe
							{text = "ogryn_pickaxe_2h_p1_m1", value = "ogryn_pickaxe_2h_p1_m1"},
							{text = "ogryn_pickaxe_2h_p1_m2", value = "ogryn_pickaxe_2h_p1_m2"},
							{text = "ogryn_pickaxe_2h_p1_m3", value = "ogryn_pickaxe_2h_p1_m3"},
							-- Power Maul
							{text = "ogryn_powermaul_p1_m1", value = "ogryn_powermaul_p1_m1"},
							--[[] THESE WEAPONS AREN'T ACCESSIBLE IN-GAME YET
							{text = "ogryn_powermaul_p1_m2", value = "ogryn_powermaul_p1_m2"},
							{text = "ogryn_powermaul_p1_m3", value = "ogryn_powermaul_p1_m3"},
							--]]
							-- Slab Shield
							{text = "ogryn_powermaul_slabshield_p1_m1", value = "ogryn_powermaul_slabshield_p1_m1"},
							-- Shock Maul
							{text = "powermaul_p1_m1", value = "powermaul_p1_m1"},
							{text = "powermaul_p1_m2", value = "powermaul_p1_m2"},
							-- Crusher
							{text = "powermaul_2h_p1_m1", value = "powermaul_2h_p1_m1"},
							-- Power Sword
							{text = "powersword_p1_m1", value = "powersword_p1_m1"},
							{text = "powersword_p1_m2", value = "powersword_p1_m2"},
							-- Relic Sword
							{text = "powersword_2h_p1_m1", value = "powersword_2h_p1_m1"},
							{text = "powersword_2h_p1_m2", value = "powersword_2h_p1_m2"},
							-- Thunder Hammer
							{text = "thunderhammer_2h_p1_m1", value = "thunderhammer_2h_p1_m1"},
							{text = "thunderhammer_2h_p1_m2", value = "thunderhammer_2h_p1_m2"},
							--]]
						}
					},
					{
						setting_id    = "weapon_enabled",
						type          = "checkbox",
						tooltip       = "weapon_enabled_tooltip",
						default_value = false
					},
					--[[ Deprecated ]
					{
						setting_id    = "weapon_block_cancel",
						type          = "checkbox",
						tooltip       = "block_cancel_tooltip",
						default_value = false
					},
					--]]
					{
						setting_id    = "weapon_cancel",
						type          = "checkbox",
						tooltip       = "cancel_tooltip",
						default_value = false
					},
					{
						setting_id    = "weapon_cancel_mode",
						type          = "dropdown",
						default_value = "block",
						options = {
							{text = "block", value = "block"},
							{text = "special", value = "special"}
						}
					},
					{
						setting_id    = "weapon_max_stacks",
						type          = "numeric",
						tooltip       = "thrust_tooltip",
						default_value = 0,
						range         = {0, 3},
						unit_text     = "stacks"
					},
					{
						setting_id    = "weapon_split_specials",
						type          = "checkbox",
						tooltip       = "split_specials_tooltip",
						default_value = false
					},
					{
						setting_id    = "weapon_max_special_stacks",
						type          = "numeric",
						tooltip       = "thrust_special_tooltip",
						default_value = 0,
						range         = {0, 3},
						unit_text     = "special_stacks"
					}
				}
			},
			{
				setting_id    = "reset_group",
				type          = "group",
				sub_widgets   = {
					{
						setting_id    = "reset",
						type          = "checkbox",
						default_value = false
					}
				}
			}
		}
	}
}