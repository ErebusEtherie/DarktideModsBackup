return {
	gamemodes = {
		meatgrinder = true,
		mission = true,
	},
	grid_cols = 0,
	grid_rows = 0,
	label = "Compact Player Panel",
	localizations = {},
	name = "Compact_Player_Panel",
	nodes = {
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
			id = "progress_bar_1_copy",
			label = "Health bar",
			offset = {
				-76,
				189.25,
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
				segment_gap = 4,
				size = {
					207,
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
						field = "ability.progress_percent_to_max_charges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "ability.max_charges",
						kind = "fixed",
						source = "player_1",
					},
					segments = {
						field = "ability.max_charges",
						kind = "source",
						source = "player_1",
					},
					thresholds = {
						body = "",
						kind = "fixed",
					},
				},
			},
			id = "progress_bar_3",
			label = "Ability Charge Bar",
			offset = {
				-76,
				173,
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
					57,
					223,
					186,
				},
				segment_gap = 3,
				size = {
					207,
					4,
				},
				thresholds = {
					{
						color = {
							255,
							248,
							80,
							63,
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
			id = "progress_bar_1_copy_copy",
			label = "Corruption bar",
			offset = {
				-76,
				189,
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
				segment_gap = 5,
				size = {
					207,
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
						body = "",
						field = "pocketables.color",
						kind = "thresholds",
						source = "player_1",
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
						body = "",
						field = "status.toughness_percent",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.toughness_regular_max",
						kind = "fixed",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1",
			label = "Toughness Bar",
			offset = {
				-76,
				180,
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
					207,
					6,
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
					text = {
						field = "identity.text_icon",
						kind = "source",
						source = "player_1",
					},
					text2 = {
						field = "profile.name",
						kind = "fixed",
						source = "player_1",
					},
					text3 = {
						field = "profile.name",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3",
			label = "Class - Ability",
			offset = {
				-77,
				149,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				font_size = 18,
				font_type = "proxima_nova_bold",
				shadow = true,
			},
			type = "text",
			values = {
				mode = "fixed",
				mode2 = "fixed",
				mode3 = "fixed",
				text = "Text",
				text2 = " ",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "pocketables.icon_small",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "pocketables.deployable_is_held",
						kind = "conditions",
						source = "player_1",
					},
				},
			},
			id = "rect_2_copy_2_copy",
			label = "Pocketable Icon",
			offset = {
				-77,
				203,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					15,
					15,
				},
			},
			type = "rect",
			values = {
				color_fallback = {
					84,
					255,
					255,
					255,
				},
				material_fallback = "content/ui/materials/icons/pocketables/hud/small/party_ammo_crate",
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
			id = "rect_2_copy_2_copy_copy",
			label = "Stimm Icon",
			offset = {
				-60,
				203,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					15,
					15,
				},
			},
			type = "rect",
			values = {
				color_fallback = {
					83,
					255,
					255,
					255,
				},
				material_fallback = "content/ui/materials/icons/pocketables/hud/small/party_syringe_ability",
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
								field = "blitz.count",
								kind = "source",
								source = "player_1",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										243,
										93,
										93,
									},
									pct = 0,
								},
								{
									color = {
										255,
										245,
										186,
										61,
									},
									pct = 1,
								},
								{
									color = {
										255,
										255,
										255,
										255,
									},
									pct = 50,
								},
							},
							max = {
								field = "blitz.max_count",
								kind = "source",
								source = "player_1",
								value = 100,
							},
							scale = "percent",
						},
					},
					material = {
						field = "blitz.icon",
						kind = "fixed",
						source = "player_1",
					},
					visible = {
						field = "blitz.is_throwable",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_2_copy",
			label = "Blitz Icon",
			offset = {
				118,
				202,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					15,
					15,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/hud/icons/party_throwable",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					color = {
						body = "",
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
										243,
										93,
										93,
									},
									pct = 0,
								},
								{
									color = {
										255,
										228,
										182,
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
									pct = 50,
								},
							},
							max = {
								kind = "fixed",
								value = 100,
							},
							scale = "percent",
						},
					},
					visible = {
						field = "equipment.ranged_uses_ammo",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_2",
			label = "Ammo Icon",
			offset = {
				102,
				203,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					14,
					14,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/hud/icons/party_ammo",
				rotation = 0,
			},
		},
		{
			callbacks = {
				value = {
					text = {
						field = "state.seconds_until_rescuable",
						kind = "fixed",
						source = "player_1",
					},
					text2 = {
						field = "state.seconds_until_rescuable",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {},
						},
						field = "state.dead",
						kind = "conditions",
						source = "player_1",
					},
				},
			},
			id = "text_4_copy",
			label = "Rescue In...",
			offset = {
				-129,
				225,
			},
			players = {
				player_1 = {
					dead = true,
				},
			},
			style = {
				align = "right",
				color = {
					255,
					255,
					255,
					255,
				},
				font_size = 18,
				font_type = "mono_tide_bold",
				size = {
					260,
					16,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				mode2 = "fixed",
				text = "Rescue: ",
				text3 = " sec",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "ability.icon",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_1",
			label = "Ability Icon",
			offset = {
				-134,
				152,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					49,
					49,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/icons/talents/veteran_2/veteran_2_combat",
			},
		},
	},
	offset = {
		-246,
		-272,
	},
	script = {},
	version = 1,
	visible = {
		conditions = {
			rows = {},
		},
		field = "state.alive",
		kind = "conditions",
		source = "player_1",
	},
}