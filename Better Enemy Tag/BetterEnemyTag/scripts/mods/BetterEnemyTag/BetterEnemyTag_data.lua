local mod = get_mod("BetterEnemyTag")

local function get_icon_options()
	return {
		{
			text = "default",
			value = "default",
		},
		{
			text = "Skull",
			value = "content/ui/materials/hud/interactions/icons/enemy",
			icon = "content/ui/materials/hud/interactions/icons/enemy",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Priority_Skull",
			value = "content/ui/materials/hud/interactions/icons/enemy_priority",
			icon = "content/ui/materials/hud/interactions/icons/enemy_priority",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Cracked_Skull",
			value = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power",
			icon = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Auric_Skull",
			value = "content/ui/materials/icons/difficulty/difficulty_skull_auric",
			icon = "content/ui/materials/icons/difficulty/difficulty_skull_auric",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Servo_Skull",
			value = "content/ui/materials/icons/throwables/hud/cryptic_servo_skull_order_shooting",
			icon = "content/ui/materials/icons/throwables/hud/cryptic_servo_skull_order_shooting",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Cyber_Mastiff",
			value = "content/ui/materials/icons/throwables/hud/adamant_whistle",
			icon = "content/ui/materials/icons/throwables/hud/adamant_whistle",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Eagle",
			value = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
			icon = "content/ui/materials/backgrounds/scanner/scanner_decoration_eagle",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Exclamation",
			value = "content/ui/materials/icons/player_states/incapacitated",
			icon = "content/ui/materials/icons/player_states/incapacitated",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Attention",
			value = "content/ui/materials/hud/interactions/icons/attention",
			icon = "content/ui/materials/hud/interactions/icons/attention",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Radar",
			value = "content/ui/materials/backgrounds/scanner/scanner_map_radar",
			icon = "content/ui/materials/backgrounds/scanner/scanner_map_radar",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Circle",
			value = "content/ui/materials/hud/interactions/icons/default",
			icon = "content/ui/materials/hud/interactions/icons/default",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Rhombus_1",
			value = "content/ui/materials/hud/interactions/icons/objective_secondary",
			icon = "content/ui/materials/hud/interactions/icons/objective_secondary",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Rhombus_2",
			value = "content/ui/materials/hud/interactions/icons/objective_side",
			icon = "content/ui/materials/hud/interactions/icons/objective_side",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Rhombus_3",
			value = "content/ui/materials/icons/system/page_indicator_02_idle",
			icon = "content/ui/materials/icons/system/page_indicator_02_idle",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Target_1",
			value = "content/ui/materials/icons/presets/preset_14",
			icon = "content/ui/materials/icons/presets/preset_14",
			icon_colour = { 255, 255, 255, 255 },
		},
		{
			text = "Target_2",
			value = "content/ui/materials/icons/mission_types/mission_type_02",
			icon = "content/ui/materials/icons/mission_types/mission_type_02",
			icon_colour = { 255, 255, 255, 255 },
		},
	}
end

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
						default_value = false,
						title         = "override_tag_settings",
					},
					{
						setting_id      = "normal_tag_opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
						title           = "opacity_normal",
					},
					{
						setting_id    = "normal_tag_fade_when_aim",
						type          = "checkbox",
						default_value = true,
						title         = "fade_when_aim",
						sub_widgets   = {
							{
								setting_id      = "normal_tag_opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
								title           = "opacity_aim",
							},
						}
					},
					{
						setting_id    = "normal_tag_sync_outline_color",
						type          = "checkbox",
						default_value = false,
						title         = "sync_outline_color",
					},
					{
						setting_id  = "normal_tag_icon_settings",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "normal_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = get_icon_options(),
							},
							{
								setting_id    = "normal_tag_use_slot_color",
								type          = "checkbox",
								default_value = false,
								title         = "use_slot_color",
							},
						}
					},
					{
						setting_id  = "normal_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_normal_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "normal_tag_color_red",
								type          = "numeric",
								default_value = 246,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "normal_tag_color_green",
								type          = "numeric",
								default_value = 69,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "normal_tag_color_blue",
								type          = "numeric",
								default_value = 69,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
					},
					{
						setting_id  = "teammate_normal_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_teammate_normal_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "teammate_normal_tag_color_red",
								type          = "numeric",
								default_value = 246,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "teammate_normal_tag_color_green",
								type          = "numeric",
								default_value = 69,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "teammate_normal_tag_color_blue",
								type          = "numeric",
								default_value = 69,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
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
						default_value = false,
						title         = "override_tag_settings",
					},
					{
						setting_id      = "veteran_tag_opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
						title           = "opacity_normal",
					},
					{
						setting_id    = "veteran_tag_fade_when_aim",
						type          = "checkbox",
						default_value = true,
						title         = "fade_when_aim",
						sub_widgets   = {
							{
								setting_id      = "veteran_tag_opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
								title           = "opacity_aim",
							},
						}
					},
					{
						setting_id    = "veteran_tag_sync_outline_color",
						type          = "checkbox",
						default_value = false,
						title         = "sync_outline_color",
					},
					{
						setting_id  = "veteran_tag_icon_settings",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "veteran_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = get_icon_options(),
							},
							{
								setting_id    = "veteran_tag_use_slot_color",
								type          = "checkbox",
								default_value = false,
								title         = "use_slot_color",
							},
						}
					},
					{
						setting_id  = "veteran_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_veteran_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "veteran_tag_color_red",
								type          = "numeric",
								default_value = 255,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "veteran_tag_color_green",
								type          = "numeric",
								default_value = 204,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "veteran_tag_color_blue",
								type          = "numeric",
								default_value = 100,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
					},
					{
						setting_id  = "teammate_veteran_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_teammate_veteran_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "teammate_veteran_tag_color_red",
								type          = "numeric",
								default_value = 255,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "teammate_veteran_tag_color_green",
								type          = "numeric",
								default_value = 204,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "teammate_veteran_tag_color_blue",
								type          = "numeric",
								default_value = 100,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
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
						default_value = false,
						title         = "override_tag_settings",
					},
					{
						setting_id      = "companion_tag_opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
						title           = "opacity_normal",
					},
					{
						setting_id    = "companion_tag_fade_when_aim",
						type          = "checkbox",
						default_value = true,
						title         = "fade_when_aim",
						sub_widgets   = {
							{
								setting_id      = "companion_tag_opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
								title           = "opacity_aim",
							},
						}
					},
					{
						setting_id    = "companion_tag_sync_outline_color",
						type          = "checkbox",
						default_value = false,
						title         = "sync_outline_color",
					},
					{
						setting_id  = "companion_tag_icon_settings",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "companion_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = get_icon_options(),
							},
							{
								setting_id    = "companion_tag_use_slot_color",
								type          = "checkbox",
								default_value = false,
								title         = "use_slot_color",
							},
						}
					},
					{
						setting_id  = "companion_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_companion_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "companion_tag_color_red",
								type          = "numeric",
								default_value = 184,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "companion_tag_color_green",
								type          = "numeric",
								default_value = 20,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "companion_tag_color_blue",
								type          = "numeric",
								default_value = 96,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
					},
					{
						setting_id  = "teammate_companion_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_teammate_companion_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "teammate_companion_tag_color_red",
								type          = "numeric",
								default_value = 184,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "teammate_companion_tag_color_green",
								type          = "numeric",
								default_value = 20,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "teammate_companion_tag_color_blue",
								type          = "numeric",
								default_value = 96,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
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
						default_value = false,
						title         = "override_tag_settings",
					},
					{
						setting_id      = "servo_skull_tag_opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
						title           = "opacity_normal",
					},
					{
						setting_id    = "servo_skull_tag_fade_when_aim",
						type          = "checkbox",
						default_value = true,
						title         = "fade_when_aim",
						sub_widgets   = {
							{
								setting_id      = "servo_skull_tag_opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
								title           = "opacity_aim",
							},
						}
					},
					{
						setting_id    = "servo_skull_tag_sync_outline_color",
						type          = "checkbox",
						default_value = false,
						title         = "sync_outline_color",
					},
					{
						setting_id  = "servo_skull_tag_icon_settings",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "servo_skull_tag_icon_path",
								type          = "dropdown",
								title         = "tag_icon",
								default_value = "default",
								options       = get_icon_options(),
							},
							{
								setting_id    = "servo_skull_tag_use_slot_color",
								type          = "checkbox",
								default_value = false,
								title         = "use_slot_color",
							},
						}
					},
					{
						setting_id  = "servo_skull_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_servo_skull_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "servo_skull_tag_color_red",
								type          = "numeric",
								default_value = 184,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "servo_skull_tag_color_green",
								type          = "numeric",
								default_value = 20,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "servo_skull_tag_color_blue",
								type          = "numeric",
								default_value = 96,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
					},
					{
						setting_id  = "teammate_servo_skull_tag_color",
						type        = "group",
						sub_widgets = {
							{
								setting_id    = "override_teammate_servo_skull_tag_color",
								type          = "checkbox",
								default_value = false,
								title         = "override_tag_color",
							},
							{
								setting_id    = "teammate_servo_skull_tag_color_red",
								type          = "numeric",
								default_value = 184,
								range         = { 0, 255 },
								title         = "red",
							},
							{
								setting_id    = "teammate_servo_skull_tag_color_green",
								type          = "numeric",
								default_value = 20,
								range         = { 0, 255 },
								title         = "green",
							},
							{
								setting_id    = "teammate_servo_skull_tag_color_blue",
								type          = "numeric",
								default_value = 96,
								range         = { 0, 255 },
								title         = "blue",
							},
						},
					},
				}
			},
		}
	}
}
