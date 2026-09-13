return {
	gamemodes = {
		meatgrinder = true,
		mission = true,
	},
	grid_cols = 0,
	grid_rows = 0,
	label = "Dodge and Status Bars",
	localizations = {},
	name = "dodge_and_status_bars",
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
				189,
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
				segment_gap = 3,
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
					text = {
						field = "status.health_percent",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_2",
			label = "Health",
			offset = {
				135.25,
				188.75,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				font_size = 14,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					44,
					16,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
				text2 = "%",
				value_mode = "chain",
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
			id = "progress_bar_1",
			label = "Toughness Bar",
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
					125,
					225,
					234,
				},
				size = {
					207,
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
						body = "local blue = { 255, 125, 225, 234 }\
local gold = { 255, 247, 226, 20 }\
color = sources.player_1.status.has_golden_toughness and gold or blue",
						kind = "code",
					},
					text = {
						field = "status.toughness_percent",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_1",
			label = "Toughness",
			offset = {
				134,
				172,
			},
			style = {
				color = {
					255,
					125,
					225,
					234,
				},
				font_size = 14,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					45,
					13,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
				text2 = "%",
				value_mode = "chain",
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
			id = "progress_bar_2",
			label = "Stamina Bar",
			offset = {
				-76.5,
				156,
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
					207,
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
						kind = "fixed",
						thresholds = {
							current = {
								body = "",
								field = "equipment.ammo_mag_remaining",
								kind = "fixed",
								source = "player_1",
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
								{
									color = {
										255,
										57,
										109,
										127,
									},
									pct = 50,
								},
							},
							max = {
								field = "equipment.ammo_mag_max",
								kind = "fixed",
								source = "player_1",
								value = 1,
							},
						},
					},
					text = {
						body = "text = sources.player_1.status.stamina_percent * 100",
						field = "status.stamina_percent",
						kind = "source",
						source = "player_1",
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
			id = "text_3",
			label = "Stamina %",
			offset = {
				134.25,
				154.5,
			},
			players = {
				player_1 = {
					alive = true,
				},
			},
			style = {
				color = {
					255,
					95,
					235,
					101,
				},
				font_size = 14,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					48,
					11,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
				text2 = "%",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				style = {
					body = "",
					kind = "off",
				},
				value = {
					color = {
						body = "local normal = {255, 255, 255, 255}\
local orange = { 255, 255, 161, 52 }\
local red = { 255, 230, 55, 55 }\
local dodges = sources.player_1.status.dodges\
if dodges == 0 then\
    color = orange\
elseif dodges <= 0 then\
    color = red\
else\
    color = normal\
end",
						kind = "thresholds",
						thresholds = {
							current = {
								field = "status.dodges",
								kind = "source",
								source = "player_1",
								value = 0,
							},
							list = {
								{
									color = {
										255,
										251,
										53,
										53,
									},
									pct = -1,
								},
								{
									color = {
										255,
										255,
										128,
										33,
									},
									pct = 0,
								},
								{
									color = {
										255,
										255,
										255,
										255,
									},
									pct = 1,
								},
							},
							max = {
								field = "status.dodges_max",
								kind = "source",
								source = "player_1",
								value = 100,
							},
							scale = "number",
						},
					},
					text = {
						body = "dodges = sources.player_1.status.dodges\
if dodges < 0 then\
    text = 0\
else\
    text = dodges\
end",
						field = "status.dodges_clamped",
						kind = "source",
						source = "player_1",
					},
					text3 = {
						field = "status.dodges_max",
						kind = "fixed",
						source = "player_1",
					},
				},
			},
			id = "dodge_counter_copy_copy",
			label = "Dodge Counter",
			offset = {
				-122,
				157,
			},
			style = {
				align = "center",
				color = {
					255,
					198,
					255,
					49,
				},
				font_size = 53,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					44,
					46,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				mode2 = "fixed",
				mode3 = "fixed",
				text = "Text",
			},
		},
	},
	offset = {
		-241,
		-288,
	},
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