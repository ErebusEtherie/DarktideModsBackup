local mod = get_mod("AutoBlitz")

return {
	name         = mod:localize("mod_name"),
	description  = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			--[[]
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
				setting_id = "allow_override",
				tooltip = "allow_override_tooltip",
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "auto_throw_keybind",
				tooltip = "auto_throw_keybind_tooltip",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "throw_grenade"
			},
			{
				setting_id = "adamant",
				type = "group",
				sub_widgets = {
					{
						setting_id = "mine_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "mine_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "mine_minimum",
						tooltip = "mine_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 4},
						unit_text     = "stacks"
					},
					{
						setting_id = "arbites_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "arbites_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "arbites_minimum",
						tooltip = "arbites_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
					{
						setting_id = "dogsplosion_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "dogsplosion_use_threshold",
						type = "checkbox",
						tooltip = "dogsplosion_use_threshold_tooltip",
						default_value = false,
					},
					{
						setting_id = "dogsplosion_enemy_threshold",
						type = "numeric",
						default_value = 0,
						range         = {0, 40},
					},
					{
						setting_id = "dogsplosion_elite_threshold",
						type = "numeric",
						default_value = 0,
						range         = {0, 20},
					},
					{
						setting_id = "dogsplosion_special_threshold",
						type = "numeric",
						default_value = 0,
						range         = {0, 20},
					},
					{
						setting_id = "dogsplosion_boss_threshold",
						type = "numeric",
						default_value = 0,
						range         = {0, 10},
					},
					{
						setting_id = "dogsplosion_allow_daemonhost",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "dogsplosion_pounce_only",
						type = "checkbox",
						default_value = true
					},
					{
						setting_id = "dogsplosion_require_tag",
						type = "checkbox",
						tooltip = "dogsplosion_require_tag_tooltip",
						default_value = true
					},
					{
						setting_id = "dogsplosion_cooldown",
						type = "numeric",
						default_value = 60,
						range         = {1, 120},
					},
					{
						setting_id = "dogsplosion_minimum",
						tooltip = "dogsplosion_minimum_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
				}
			},
			{
				setting_id = "broker",
				type = "group",
				sub_widgets = {
					{
						setting_id = "flask_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "flask_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "flask_minimum",
						tooltip = "flask_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
					--[[]]
					{
						setting_id = "launcher_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "launcher_minimum",
						tooltip = "launcher_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
					--]]
				}
			},
			{
				setting_id = "ogryn",
				type = "group",
				sub_widgets = {
					{
						setting_id = "box_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "box_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "box_minimum",
						tooltip = "box_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 4},
						unit_text     = "stacks"
					},
					{
						setting_id = "rock_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "rock_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "rock_minimum",
						tooltip = "rock_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
					{
						setting_id = "nuke_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "nuke_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "nuke_minimum",
						tooltip = "nuke_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 3},
						unit_text     = "stacks"
					},
				}
			},
			{
				setting_id = "cryptic",
				type = "group",
				sub_widgets = {
					{
						setting_id = "skull_enabled",
						type = "checkbox",
						default_value = false,
						tooltip = "skull_enabled_tooltip"
					},

					--[[]
					{
						setting_id = "medic_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "help_downed",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "help_hogtied",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "help_netted",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "medic_minimum",
						tooltip = "medic_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
					--]]
					--[[]]
					{
						setting_id = "arc_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "arc_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "arc_minimum",
						tooltip = "arc_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
					{
						setting_id = "shield_enabled",
						type = "checkbox",
						default_value = false
					},
					--[[]
					{
						setting_id = "shield_ignore_toughness",
						type = "checkbox",
						tooltip = "shield_ignore_toughness_tooltip",
						default_value = false
					},
					--]]
					{
						setting_id = "shield_type",
						tooltip = "shield_type_tooltip",
						type = "dropdown",
						default_value = "current_health",
						options = {
							{ text = "current_health", value = "current_health" },
							{ text = "damage_taken", value = "damage_taken" },
						}
					},
					{
						setting_id = "shield_threshold",
						tooltip = "shield_threshold_tooltip",
						type = "numeric",
						default_value = 0,
						range         = {0, 100},
					},
					{
						setting_id = "shield_minimum",
						tooltip = "shield_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					}
					--]]
				}
			},
			{
				setting_id = "veteran",
				type = "group",
				sub_widgets = {
					{
						setting_id = "frag_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "frag_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "frag_minimum",
						tooltip = "frag_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
					{
						setting_id = "krak_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "krak_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "krak_minimum",
						tooltip = "krak_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
					{
						setting_id = "smoke_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "smoke_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "smoke_minimum",
						tooltip = "smoke_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 6},
						unit_text     = "stacks"
					},
				}
			},
			{
				setting_id = "zealot",
				type = "group",
				sub_widgets = {
					{
						setting_id = "flame_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "flame_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "flame_minimum",
						tooltip = "flame_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
					{
						setting_id = "shock_enabled",
						type = "checkbox",
						default_value = false
					},
					{
						setting_id = "shock_throw_type",
						type = "dropdown",
						default_value = "overhand",
						options = {
							{ text = "overhand", value = "overhand" },
							{ text = "underhand", value = "underhand" },
						}
					},
					{
						setting_id = "shock_minimum",
						tooltip = "shock_tooltip",
						type = "numeric",
						default_value = 1,
						range         = {1, 5},
						unit_text     = "stacks"
					},
				}
			},
		}
	}
}