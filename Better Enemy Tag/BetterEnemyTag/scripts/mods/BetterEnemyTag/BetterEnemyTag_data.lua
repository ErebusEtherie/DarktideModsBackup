local mod = get_mod("BetterEnemyTag")

local icon_options = {
	{
		text = "default",
		value = "default",
	},
	{
		text       = "Skull",
		value      = "content/ui/materials/hud/interactions/icons/enemy",
		icon       = "content/ui/materials/hud/interactions/icons/enemy",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Priority_Skull",
		value      = "content/ui/materials/hud/interactions/icons/enemy_priority",
		icon       = "content/ui/materials/hud/interactions/icons/enemy_priority",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Cracked_Skull",
		value      = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power",
		icon       = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Auric_Skull",
		value      = "content/ui/materials/icons/difficulty/difficulty_skull_auric",
		icon       = "content/ui/materials/icons/difficulty/difficulty_skull_auric",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Servo_Skull",
		value      = "content/ui/materials/icons/throwables/hud/cryptic_servo_skull_order_shooting",
		icon       = "content/ui/materials/icons/throwables/hud/cryptic_servo_skull_order_shooting",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Cyber_Mastiff",
		value      = "content/ui/materials/icons/throwables/hud/adamant_whistle",
		icon       = "content/ui/materials/icons/throwables/hud/adamant_whistle",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Eagle",
		value      = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
		icon       = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Exclamation",
		value      = "content/ui/materials/icons/player_states/incapacitated",
		icon       = "content/ui/materials/icons/player_states/incapacitated",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Attention",
		value      = "content/ui/materials/hud/interactions/icons/attention",
		icon       = "content/ui/materials/hud/interactions/icons/attention",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Radar",
		value      = "content/ui/materials/backgrounds/scanner/scanner_map_radar",
		icon       = "content/ui/materials/backgrounds/scanner/scanner_map_radar",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Circle",
		value      = "content/ui/materials/hud/interactions/icons/default",
		icon       = "content/ui/materials/hud/interactions/icons/default",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Rhombus_1",
		value      = "content/ui/materials/hud/interactions/icons/objective_secondary",
		icon       = "content/ui/materials/hud/interactions/icons/objective_secondary",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Rhombus_2",
		value      = "content/ui/materials/hud/interactions/icons/objective_side",
		icon       = "content/ui/materials/hud/interactions/icons/objective_side",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Rhombus_3",
		value      = "content/ui/materials/icons/system/page_indicator_02_idle",
		icon       = "content/ui/materials/icons/system/page_indicator_02_idle",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Target_1",
		value      = "content/ui/materials/icons/presets/preset_14",
		icon       = "content/ui/materials/icons/presets/preset_14",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
	{
		text       = "Target_2",
		value      = "content/ui/materials/icons/mission_types/mission_type_02",
		icon       = "content/ui/materials/icons/mission_types/mission_type_02",
		icon_style = { color = { 255, 255, 255, 255 } },
	},
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id  = "general_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "reduce_screen_margin",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "enhanced_distance_scale",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "disable_aim_scale_up",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "hide_distance_text",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "hide_off_screen_icon",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
					},
					{
						setting_id    = "fade_when_aim",
						type          = "checkbox",
						default_value = true,
						sub_widgets   = {
							{
								setting_id      = "opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
							},
						}
					},
					{
						setting_id    = "sync_outline_color",
						type          = "checkbox",
						default_value = false,
						title         = "sync_outline_color",
					}
				}
			},
			{
				setting_id  = "normal_tag_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_normal_tag_settings",
						type          = "checkbox",
						title         = "override_tag_settings",
						default_value = false,
						sub_widgets   = {
							{
								setting_id      = "normal_tag_opacity_normal",
								type            = "numeric",
								title           = "opacity_normal",
								default_value   = 1,
								range           = { 0, 1 },
								decimals_number = 2,
							},
							{
								setting_id    = "normal_tag_fade_when_aim",
								type          = "checkbox",
								title         = "fade_when_aim",
								default_value = true,
								sub_widgets   = {
									{
										setting_id      = "normal_tag_opacity_aim",
										type            = "numeric",
										title           = "opacity_aim",
										default_value   = 0.5,
										range           = { 0, 1 },
										decimals_number = 2,
									},
								}
							},
							{
								setting_id    = "normal_tag_sync_outline_color",
								type          = "checkbox",
								title         = "sync_outline_color",
								default_value = false,
							},
						}
					},
					{
						setting_id  = "normal_tag_icon_settings",
						type        = "group",
						title       = "icon_settings",
						sub_widgets = {
							{
								setting_id    = "normal_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = table.clone(icon_options),
							},
							{
								setting_id    = "normal_tag_use_slot_color",
								type          = "checkbox",
								title         = "use_slot_color",
								default_value = false,
							},
							{
								setting_id    = "override_normal_tag_color",
								type          = "checkbox",
								title         = "override_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "normal_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 246, 69, 69 },
										has_alpha     = false
									}
								},
							},
							{
								setting_id    = "override_teammate_normal_tag_color",
								type          = "checkbox",
								title         = "override_teammate_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "teammate_normal_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 246, 69, 69 },
										has_alpha     = false
									},
								}
							},
						}
					},
				}
			},
			{
				setting_id  = "veteran_tag_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_veteran_tag_settings",
						type          = "checkbox",
						title         = "override_tag_settings",
						default_value = false,
						sub_widgets   = {
							{
								setting_id      = "veteran_tag_opacity_normal",
								type            = "numeric",
								title           = "opacity_normal",
								default_value   = 1,
								range           = { 0, 1 },
								decimals_number = 2,
							},
							{
								setting_id    = "veteran_tag_fade_when_aim",
								type          = "checkbox",
								title         = "fade_when_aim",
								default_value = true,
								sub_widgets   = {
									{
										setting_id      = "veteran_tag_opacity_aim",
										type            = "numeric",
										title           = "opacity_aim",
										default_value   = 0.5,
										range           = { 0, 1 },
										decimals_number = 2,
									},
								}
							},
							{
								setting_id    = "veteran_tag_sync_outline_color",
								type          = "checkbox",
								title         = "sync_outline_color",
								default_value = false,
							},
						}
					},
					{
						setting_id  = "veteran_tag_icon_settings",
						type        = "group",
						title       = "icon_settings",
						sub_widgets = {
							{
								setting_id    = "veteran_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = table.clone(icon_options),
							},
							{
								setting_id    = "veteran_tag_use_slot_color",
								type          = "checkbox",
								title         = "use_slot_color",
								default_value = false,
							},
							{
								setting_id    = "override_veteran_tag_color",
								type          = "checkbox",
								title         = "override_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "veteran_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 255, 204, 100 },
										has_alpha     = false
									},
								}
							},
							{
								setting_id    = "override_teammate_veteran_tag_color",
								type          = "checkbox",
								title         = "override_teammate_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "teammate_veteran_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 255, 204, 100 },
										has_alpha     = false
									},
								}
							},
						}
					},
				}
			},
			{
				setting_id  = "companion_tag_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_companion_tag_settings",
						type          = "checkbox",
						title         = "override_tag_settings",
						default_value = false,
						sub_widgets   = {
							{
								setting_id      = "companion_tag_opacity_normal",
								type            = "numeric",
								title           = "opacity_normal",
								default_value   = 1,
								range           = { 0, 1 },
								decimals_number = 2,
							},
							{
								setting_id    = "companion_tag_fade_when_aim",
								type          = "checkbox",
								title         = "fade_when_aim",
								default_value = true,
								sub_widgets   = {
									{
										setting_id      = "companion_tag_opacity_aim",
										type            = "numeric",
										title           = "opacity_aim",
										default_value   = 0.5,
										range           = { 0, 1 },
										decimals_number = 2,
									},
								}
							},
							{
								setting_id    = "companion_tag_sync_outline_color",
								type          = "checkbox",
								title         = "sync_outline_color",
								default_value = false,
							},
						}
					},
					{
						setting_id  = "companion_tag_icon_settings",
						type        = "group",
						title       = "icon_settings",
						sub_widgets = {
							{
								setting_id    = "companion_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = table.clone(icon_options),
							},
							{
								setting_id    = "companion_tag_use_slot_color",
								type          = "checkbox",
								title         = "use_slot_color",
								default_value = false,
							},
							{
								setting_id    = "override_companion_tag_color",
								type          = "checkbox",
								title         = "override_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "companion_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 184, 20, 96 },
										has_alpha     = false
									},
								}
							},
							{
								setting_id    = "override_teammate_companion_tag_color",
								type          = "checkbox",
								title         = "override_teammate_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "teammate_companion_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 184, 20, 96 },
										has_alpha     = false
									},
								}
							},
						}
					},
				}
			},
			{
				setting_id  = "servo_skull_tag_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_servo_skull_tag_settings",
						type          = "checkbox",
						title         = "override_tag_settings",
						default_value = false,
						sub_widgets   = {
							{
								setting_id      = "servo_skull_tag_opacity_normal",
								type            = "numeric",
								title           = "opacity_normal",
								default_value   = 1,
								range           = { 0, 1 },
								decimals_number = 2,
							},
							{
								setting_id    = "servo_skull_tag_fade_when_aim",
								type          = "checkbox",
								title         = "fade_when_aim",
								default_value = true,
								sub_widgets   = {
									{
										setting_id      = "servo_skull_tag_opacity_aim",
										type            = "numeric",
										title           = "opacity_aim",
										default_value   = 0.5,
										range           = { 0, 1 },
										decimals_number = 2,
									},
								}
							},
							{
								setting_id    = "servo_skull_tag_sync_outline_color",
								type          = "checkbox",
								title         = "sync_outline_color",
								default_value = false,
							},
						}
					},
					{
						setting_id  = "servo_skull_tag_icon_settings",
						type        = "group",
						title       = "icon_settings",
						sub_widgets = {
							{
								setting_id    = "servo_skull_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = table.clone(icon_options),
							},
							{
								setting_id    = "servo_skull_tag_use_slot_color",
								type          = "checkbox",
								title         = "use_slot_color",
								default_value = false,
							},
							{
								setting_id    = "override_servo_skull_tag_color",
								type          = "checkbox",
								title         = "override_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "servo_skull_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 184, 20, 96 },
										has_alpha     = false
									},
								}
							},
							{
								setting_id    = "override_teammate_servo_skull_tag_color",
								type          = "checkbox",
								title         = "override_teammate_tag_color",
								default_value = false,
								sub_widgets   = {
									{
										setting_id    = "teammate_servo_skull_tag_color",
										type          = "color",
										title         = "tag_color",
										default_value = { 255, 184, 20, 96 },
										has_alpha     = false
									},
								}
							},
						}
					},
				}
			},
		}
	}
}
