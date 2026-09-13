return {
	gamemodes = {
		meatgrinder = true,
		mission = true,
	},
	grid_cols = 0,
	grid_rows = 0,
	label = "Fancy Player Panel 1",
	localizations = {},
	name = "fancy_player_panel_1",
	nodes = {
		{
			id = "rect_3",
			label = "Glow",
			offset = {
				-505,
				63,
			},
			style = {
				color = {
					68,
					114,
					192,
					113,
				},
				size = {
					1116,
					137,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			id = "rect_6",
			label = "Backing Color",
			offset = {
				-492,
				76,
			},
			style = {
				color = {
					128,
					11,
					28,
					12,
				},
				size = {
					1091,
					165,
				},
			},
			type = "rect",
			values = {},
		},
		{
			id = "rect_5",
			label = "Terminal Texture Left",
			offset = {
				-493,
				75,
			},
			style = {
				color = {
					255,
					83,
					216,
					107,
				},
				size = {
					1097,
					162,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/buttons/background_selected_faded",
			},
		},
		{
			id = "rect_5_copy_copy",
			label = "Terminal Texture Right",
			offset = {
				-498,
				75,
			},
			style = {
				color = {
					255,
					83,
					216,
					107,
				},
				size = {
					1097,
					162,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/buttons/background_selected_faded",
				uv = "flip_x",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.ranged_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										80,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										49,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_2",
			label = "Ranged Inner Shadow",
			offset = {
				-138,
				85,
			},
			style = {
				color = {
					49,
					175,
					211,
					171,
				},
				size = {
					291,
					73,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/inner_shadow_medium",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.ranged_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										222,
										236,
										133,
										60,
									},
									pct = 0,
								},
								{
									color = {
										255,
										152,
										195,
										154,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_8_copy",
			label = "Ranged Frame",
			offset = {
				-138,
				85,
			},
			style = {
				color = {
					255,
					152,
					195,
					154,
				},
				size = {
					291,
					74,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/line_thin_detailed_02",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.ranged_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										255,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
					material = {
						field = "equipment.ranged_icon",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_9_copy",
			label = "Ranged Icon",
			offset = {
				-113,
				75,
			},
			style = {
				color = {
					255,
					175,
					211,
					171,
				},
				size = {
					253,
					92,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.ammo_rounds_remaining_percent",
								kind = "source",
								source = "player_1",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										228,
										84,
										84,
									},
									pct = 0,
								},
								{
									color = {
										255,
										214,
										231,
										207,
									},
									pct = 25,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
					text = {
						field = "equipment.ammo_reserve",
						kind = "source",
						source = "player_1",
					},
					visible = {
						field = "equipment.ranged_uses_ammo",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3_copy",
			label = "Ranged Reserve",
			offset = {
				-134,
				142,
			},
			style = {
				align = "left",
				font_size = 15,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					64,
					14,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.ammo_rounds_remaining_percent",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										228,
										84,
										84,
									},
									pct = 0,
								},
								{
									color = {
										255,
										214,
										231,
										207,
									},
									pct = 25,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
					text = {
						field = "equipment.ammo_mag_remaining",
						kind = "source",
						source = "player_1",
					},
					text3 = {
						field = "equipment.ammo_mag_max",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "equipment.ranged_uses_ammo",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_1_copy",
			label = "Ranged Mag",
			offset = {
				-133,
				90,
			},
			style = {
				align = "left",
				font_size = 18,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					123,
					20,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				mode3 = "fixed",
				text = "Text",
				text2 = "/",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "fixed",
						thresholds = {
							current = {
								field = "equipment.ammo_rounds_remaining_percent",
								kind = "source",
								source = "player_1",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										228,
										84,
										84,
									},
									pct = 0,
								},
								{
									color = {
										255,
										228,
										152,
										84,
									},
									pct = 25,
								},
								{
									color = {
										255,
										255,
										255,
										255,
									},
									pct = 40,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "number",
						},
					},
					text = {
						field = "equipment.ranged_special_charges",
						kind = "fixed",
						source = "player_1",
					},
					text2 = {
						field = "equipment.ranged_special_charges",
						kind = "source",
						source = "player_1",
					},
					visible = {
						field = "equipment.ranged_uses_special_charges",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3_copy_copy",
			label = "Ranged Special Charges",
			offset = {
				84,
				90,
			},
			style = {
				align = "right",
				color = {
					255,
					214,
					231,
					207,
				},
				font_size = 15,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					64,
					14,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				mode2 = "fixed",
				text = "x",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.melee_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										80,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										49,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_2_copy",
			label = "Melee Inner Shadow",
			offset = {
				171,
				85,
			},
			style = {
				color = {
					49,
					175,
					211,
					171,
				},
				size = {
					291,
					73,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/inner_shadow_medium",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.melee_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										222,
										236,
										133,
										60,
									},
									pct = 0,
								},
								{
									color = {
										255,
										152,
										195,
										154,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_8",
			label = "Melee Frame",
			offset = {
				171,
				85,
			},
			style = {
				color = {
					255,
					152,
					195,
					154,
				},
				size = {
					291,
					74,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/line_thin_detailed_02",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "equipment.melee_is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										255,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
					material = {
						field = "equipment.melee_icon",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_9",
			label = "Melee Icon",
			offset = {
				191,
				75,
			},
			style = {
				color = {
					255,
					175,
					211,
					171,
				},
				size = {
					253,
					92,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "fixed",
						thresholds = {
							current = {
								field = "equipment.ammo_rounds_remaining_percent",
								kind = "source",
								source = "player_1",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										228,
										84,
										84,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
					text = {
						field = "equipment.ranged_special_charges",
						kind = "fixed",
						source = "player_1",
					},
					text2 = {
						field = "equipment.melee_special_charges",
						kind = "source",
						source = "player_1",
					},
					visible = {
						field = "equipment.melee_uses_special_charges",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3_copy_copy_copy",
			label = "Melee Special Charges",
			offset = {
				393,
				90,
			},
			style = {
				align = "right",
				color = {
					255,
					214,
					231,
					207,
				},
				font_size = 15,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					64,
					14,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				mode2 = "fixed",
				text = "x",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "blitz.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										80,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										49,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_2_copy_2",
			label = "Blitz Inner Shadow",
			offset = {
				513,
				85,
			},
			style = {
				color = {
					49,
					175,
					211,
					171,
				},
				size = {
					74,
					73,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/inner_shadow_medium",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "blitz.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										96,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										78,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_10",
			label = "Blitz Counter Glow",
			offset = {
				471,
				74,
			},
			style = {
				color = {
					84,
					175,
					211,
					171,
				},
				size = {
					44,
					98,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			id = "rect_10_copy_3",
			label = "Blitz Charge Glow",
			offset = {
				461,
				74,
			},
			style = {
				color = {
					51,
					175,
					211,
					171,
				},
				size = {
					28,
					98,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "blitz.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										222,
										236,
										133,
										60,
									},
									pct = 0,
								},
								{
									color = {
										255,
										152,
										195,
										154,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_8_copy_2",
			label = "Blitz Frame",
			offset = {
				513,
				85,
			},
			style = {
				color = {
					255,
					152,
					195,
					154,
				},
				size = {
					74,
					74,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/line_thin_detailed_02",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "blitz.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										255,
										175,
										211,
										171,
									},
									pct = 1,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "boolean",
						},
					},
					current = {
						field = "blitz.count",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "blitz.max_count",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "blitz.max_count",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy",
			label = "Blitz Counter Bar",
			offset = {
				483,
				86,
			},
			style = {
				color = {
					255,
					245,
					180,
					55,
				},
				orientation = "bottom_top",
				segment_gap = 3,
				size = {
					20,
					74,
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					current = {
						field = "blitz.progress_percent_to_next_charge",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_2",
			label = "Blitz Charge Bar",
			offset = {
				473,
				86,
			},
			style = {
				bg_color = {
					69,
					0,
					0,
					0,
				},
				color = {
					208,
					136,
					181,
					131,
				},
				orientation = "bottom_top",
				size = {
					5,
					74,
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "blitz.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										255,
										175,
										211,
										171,
									},
									pct = 1,
								},
							},
							max = {
								field = "blitz.max_count",
								kind = "source",
								source = "player_1",
								value = 100,
							},
							scale = "boolean",
						},
					},
					material = {
						field = "blitz.icon",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_1",
			label = "Blitz Icon",
			offset = {
				514,
				83,
			},
			style = {
				color = {
					255,
					174,
					217,
					153,
				},
				size = {
					73,
					73,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								field = "pocketables.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										80,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										49,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
					material = {
						field = "deployables.icon",
						kind = "fixed",
						source = "player_1",
					},
				},
			},
			id = "rect_2_copy_3",
			label = "Pocketable Inner Shadow",
			offset = {
				-483,
				85,
			},
			style = {
				color = {
					49,
					175,
					211,
					171,
				},
				size = {
					72,
					75,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/inner_shadow_medium",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						field = "pocketables.color",
						kind = "thresholds",
						source = "player_1",
						thresholds = {
							current = {
								field = "pocketables.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										222,
										236,
										133,
										60,
									},
									pct = 0,
								},
								{
									color = {
										255,
										152,
										195,
										154,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
				},
			},
			id = "rect_8_copy_copy",
			label = "Pocketable Frame",
			offset = {
				-483,
				85,
			},
			style = {
				color = {
					255,
					152,
					195,
					154,
				},
				size = {
					72,
					75,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/line_thin_detailed_02",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						field = "deployables.color",
						kind = "thresholds",
						source = "player_1",
						thresholds = {
							current = {
								field = "pocketables.is_equipped",
								kind = "source",
								source = "player_1",
								value = false,
							},
							list = {
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 0,
								},
								{
									color = {
										255,
										175,
										211,
										171,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "boolean",
						},
					},
					material = {
						field = "pocketables.icon",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_4",
			label = "Pocketable Icon",
			offset = {
				-484,
				83,
			},
			style = {
				color = {
					255,
					175,
					211,
					171,
				},
				size = {
					77,
					77,
				},
			},
			type = "rect",
			values = {
				color_fallback = {
					255,
					175,
					211,
					171,
				},
				material_fallback = "content/ui/materials/hud/interactions/icons/forge",
			},
		},
		{
			id = "rect_10_copy_copy",
			label = "Stamina Glow",
			offset = {
				-413,
				73,
			},
			style = {
				color = {
					101,
					95,
					235,
					101,
				},
				size = {
					274,
					34,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							current = {
								kind = "fixed",
								value = 0,
							},
							list = {
								{
									color = {
										111,
										120,
										220,
										255,
									},
									pct = 0,
								},
								{
									color = {
										129,
										245,
										222,
										41,
									},
									pct = 101,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
				},
			},
			id = "rect_10_copy_copy_copy",
			label = "Toughness Glow",
			offset = {
				-413,
				93,
			},
			style = {
				color = {
					101,
					95,
					235,
					101,
				},
				size = {
					274,
					34,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			id = "rect_10_copy",
			label = "Health Glow",
			offset = {
				-413,
				112,
			},
			style = {
				color = {
					81,
					255,
					255,
					255,
				},
				size = {
					274,
					34,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "fixed",
						thresholds = {
							list = {
								{
									color = {
										255,
										120,
										220,
										255,
									},
									pct = 0,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "percent",
						},
					},
					current = {
						field = "status.health_percent",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.health_max",
						kind = "fixed",
						source = "player_1",
					},
					segments = {
						field = "status.wounds_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_copy_2",
			label = "Health bar",
			offset = {
				-401,
				124,
			},
			style = {
				bg_color = {
					140,
					0,
					0,
					0,
				},
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					250,
					10,
				},
				thresholds = {
					{
						color = {
							255,
							243,
							87,
							87,
						},
						pct = 0,
					},
					{
						color = {
							255,
							245,
							245,
							245,
						},
						pct = 25,
					},
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "fixed",
						thresholds = {
							list = {
								{
									color = {
										255,
										120,
										220,
										255,
									},
									pct = 0,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "percent",
						},
					},
					current = {
						field = "status.corruption_percent",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.health_max",
						kind = "fixed",
						source = "player_1",
					},
					segments = {
						field = "status.wounds_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_copy_copy",
			label = "Corruption bar",
			offset = {
				-401,
				124,
			},
			style = {
				bg_color = {
					0,
					0,
					0,
					0,
				},
				color = {
					255,
					174,
					81,
					220,
				},
				orientation = "right_left",
				segment_gap = 3,
				size = {
					250,
					10,
				},
				thresholds = {
					{
						color = {
							255,
							177,
							120,
							255,
						},
						pct = 0,
					},
				},
			},
			type = "progress_bar",
			values = {
				current = 68,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							list = {
								{
									color = {
										255,
										120,
										220,
										255,
									},
									pct = 0,
								},
								{
									color = {
										255,
										245,
										222,
										41,
									},
									pct = 101,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "percent",
						},
					},
					current = {
						field = "status.toughness_percent",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.toughness_max",
						kind = "fixed",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_2",
			label = "Toughness Bar",
			offset = {
				-401,
				105,
			},
			style = {
				bg_color = {
					140,
					0,
					0,
					0,
				},
				color = {
					255,
					125,
					225,
					234,
				},
				size = {
					250,
					10,
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						kind = "thresholds",
						thresholds = {
							list = {
								{
									color = {
										255,
										95,
										235,
										101,
									},
									pct = 0,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
						},
					},
					current = {
						body = "",
						field = "status.stamina_percent",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.stamina_max",
						kind = "source",
						source = "player_1",
					},
					thresholds = {
						body = "",
						kind = "fixed",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "state.alive",
						kind = "conditions",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_2_copy",
			label = "Stamina Bar",
			offset = {
				-401,
				85,
			},
			players = {
				player_1 = {
					alive = true,
				},
			},
			style = {
				bg_color = {
					140,
					0,
					0,
					0,
				},
				color = {
					255,
					95,
					235,
					101,
				},
				segment_gap = 5,
				segments = 5,
				size = {
					250,
					10,
				},
				thresholds = {
					{
						color = {
							255,
							95,
							235,
							101,
						},
						pct = 0,
					},
					{
						color = {
							255,
							95,
							235,
							101,
						},
						pct = 0,
					},
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						field = "pocketables.color",
						kind = "source",
						source = "player_1",
					},
					material = {
						field = "pocketables.icon_small",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "deployables.held",
						kind = "conditions",
						source = "player_1",
					},
				},
			},
			id = "rect_1_copy",
			label = "Pocketable Icon",
			offset = {
				-169,
				143,
			},
			style = {
				color = {
					118,
					169,
					169,
					169,
				},
				size = {
					18,
					18,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/icons/pocketables/hud/small/party_medic_crate",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						field = "stimms.held_color",
						kind = "source",
						source = "player_1",
						thresholds = {
							current = {
								kind = "fixed",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										120,
										220,
										255,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
					material = {
						field = "stimms.icon_small",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "stimms.held",
						kind = "conditions",
						source = "player_1",
					},
				},
			},
			id = "rect_1_copy",
			label = "Stimm Icon",
			offset = {
				-195,
				141,
			},
			style = {
				color = {
					118,
					169,
					169,
					169,
				},
				size = {
					21,
					21,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/icons/pocketables/hud/small/party_syringe_ability",
			},
		},
		{
			callbacks = {
				value = {
					color = {
						field = "deployables.color",
						kind = "fixed",
						source = "player_1",
						thresholds = {
							current = {
								kind = "fixed",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										120,
										220,
										255,
									},
									pct = 0,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
				},
			},
			id = "rect_10_copy_2",
			label = "Ability Bar Glow",
			offset = {
				-147,
				160,
			},
			style = {
				color = {
					79,
					236,
					133,
					60,
				},
				size = {
					375,
					35,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/frame_glow_01",
			},
		},
		{
			id = "rect_7",
			label = "Ability Bar Frame",
			offset = {
				-156,
				170,
			},
			style = {
				color = {
					211,
					255,
					255,
					255,
				},
				size = {
					394,
					34,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/mission_board/mission_frame_selected_corner",
			},
		},
		{
			callbacks = {
				value = {
					current = {
						field = "ability.progress_percent_to_max_charges",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "ability.max_charges",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1",
			label = "Ability Bar",
			offset = {
				-135,
				172,
			},
			style = {
				color = {
					222,
					237,
					127,
					50,
				},
				segment_gap = 10,
				size = {
					352,
					11,
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			id = "rect_1",
			label = "Top Decorative Frame",
			offset = {
				-508,
				126,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					1117,
					164,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/training_grounds_lower",
			},
		},
	},
	offset = {
		-18,
		472,
	},
	version = 1,
}
