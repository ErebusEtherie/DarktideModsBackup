return {
	gamemodes = {
		meatgrinder = true,
		mission = true,
	},
	grid_cols = 0,
	grid_rows = 0,
	label = "Dodge Counters",
	localizations = {},
	name = "dodge_counters",
	nodes = {
		{
			callbacks = {
				value = {
					color = {
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
										228,
										84,
										84,
									},
									pct = 0,
								},
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 1,
								},
								{
									color = {
										255,
										243,
										244,
										243,
									},
									pct = 2,
								},
							},
							max = {
								field = "status.dodges_max",
								kind = "source",
								source = "player_1",
								value = 10,
							},
							scale = "number",
						},
					},
					text = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_1",
			label = "Dodge Counter",
			offset = {
				42,
				15,
			},
			style = {
				align = "center",
				font_size = 36,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					56,
					39,
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
								field = "status.dodges",
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
										234,
										149,
										90,
									},
									pct = 1,
								},
								{
									color = {
										255,
										243,
										244,
										243,
									},
									pct = 2,
								},
							},
							max = {
								field = "status.dodges_max",
								kind = "source",
								source = "player_1",
								value = 10,
							},
							scale = "number",
						},
					},
					text = {
						field = "status.dodges_clamped",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_1_copy",
			label = "Dodge Counter (Min. 0)",
			offset = {
				106,
				15,
			},
			style = {
				align = "center",
				font_size = 36,
				font_type = "mono_tide_bold",
				shadow = true,
				size = {
					56,
					39,
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
							list = {
								{
									color = {
										255,
										228,
										84,
										84,
									},
									pct = 1,
								},
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 2,
								},
								{
									color = {
										255,
										244,
										244,
										244,
									},
									pct = 3,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "number",
						},
					},
					current = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_2",
			label = "Horizontal Counter 2",
			offset = {
				16,
				106,
			},
			style = {
				color = {
					255,
					120,
					220,
					255,
				},
				orientation = "center",
				segment_gap = 4,
				size = {
					182,
					18,
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
										228,
										84,
										84,
									},
									pct = 1,
								},
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 2,
								},
								{
									color = {
										255,
										244,
										244,
										244,
									},
									pct = 3,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "number",
						},
					},
					current = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1",
			label = "Horizontal Counter 1",
			offset = {
				16,
				68,
			},
			style = {
				color = {
					255,
					120,
					220,
					255,
				},
				segment_gap = 4,
				size = {
					182,
					18,
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
										228,
										84,
										84,
									},
									pct = 1,
								},
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 2,
								},
								{
									color = {
										255,
										244,
										244,
										244,
									},
									pct = 3,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "number",
						},
					},
					current = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_3_copy",
			label = "Vertical Counter 2",
			offset = {
				-117,
				-14,
			},
			style = {
				color = {
					255,
					120,
					220,
					255,
				},
				orientation = "center_vertical",
				segment_gap = 4,
				size = {
					20,
					138,
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
										228,
										84,
										84,
									},
									pct = 1,
								},
								{
									color = {
										255,
										234,
										149,
										90,
									},
									pct = 2,
								},
								{
									color = {
										255,
										244,
										244,
										244,
									},
									pct = 3,
								},
							},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "number",
						},
					},
					current = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy_3",
			label = "Vertical Counter 1",
			offset = {
				-83,
				-15,
			},
			style = {
				color = {
					255,
					120,
					220,
					255,
				},
				orientation = "bottom_top",
				segment_gap = 4,
				size = {
					20,
					138,
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
							list = {},
							mirror = {
								current = "current",
								max = "max",
							},
							scale = "number",
						},
					},
					current = {
						field = "status.dodges",
						kind = "source",
						source = "player_1",
					},
					max = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
					segments = {
						field = "status.dodges_max",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_1_copy",
			label = "Curved Counter",
			offset = {
				-41,
				-62,
			},
			style = {
				bg_color = {
					197,
					111,
					10,
					10,
				},
				color = {
					255,
					231,
					54,
					54,
				},
				orientation = "curved_top_left",
				outline_color = {
					0,
					0,
					0,
					0,
				},
				segment_gap = 4,
				shape = "curved",
				size = {
					155,
					186,
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
						field = "status.dodge_refresh_percent",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "progress_bar_2",
			offset = {
				-117,
				-100,
			},
			style = {
				color = {
					255,
					234,
					149,
					90,
				},
				size = {
					273,
					22,
				},
			},
			type = "progress_bar",
			values = {
				current = 60,
				max = 100,
			},
		},
		{
			id = "text_2",
			offset = {
				-118,
				-144,
			},
			style = {
				shadow = true,
			},
			type = "text",
			values = {
				text = "Dodge refresh:",
			},
		},
		{
			callbacks = {
				value = {
					text = {
						field = "status.dodge_refresh_seconds",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3",
			offset = {
				52,
				-128,
			},
			style = {
				align = "right",
				decimals = 2,
				shadow = true,
				size = {
					107,
					25,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
				text2 = "s",
				value_mode = "chain",
			},
		},
		{
			callbacks = {
				value = {
					text = {
						field = "status.dodge_refresh_percent",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_3_copy",
			offset = {
				109,
				-104,
			},
			style = {
				align = "right",
				decimals = 0,
				shadow = true,
				size = {
					107,
					25,
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
	},
	offset = {
		-45,
		-116,
	},
	version = 1,
}