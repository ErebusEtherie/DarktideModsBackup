return {
	grid_cols = 0,
	grid_rows = 0,
	label = "Ability Container",
	localizations = {},
	name = "Ability_Container",
	nodes = {
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
			label = "Icon",
			offset = {
				42,
				13,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					100,
					100,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "identity.id",
										kind = "source",
										source = "player_1",
									},
									negate = true,
									op = "==",
									rhs = {
										kind = "fixed",
										value = "cryptic",
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "rect_2",
			label = "Drop Shadow",
			offset = {
				28,
				-3,
			},
			style = {
				color = {
					83,
					0,
					0,
					0,
				},
				size = {
					128,
					135,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/frames/talents/hex_frame_glow",
			},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "ability.icon_frame",
						kind = "fixed",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "identity.id",
										kind = "source",
										source = "player_1",
									},
									negate = true,
									op = "==",
									rhs = {
										kind = "fixed",
										value = "cryptic",
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "rect_4",
			label = "Frame",
			offset = {
				11,
				15,
			},
			style = {
				color = {
					255,
					204,
					221,
					184,
				},
				size = {
					161,
					98,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/icons/talents/menu/combat_talent_terminal_frame",
			},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "ability.icon_frame",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "identity.id",
										kind = "source",
										source = "player_1",
									},
									op = "==",
									rhs = {
										kind = "fixed",
										value = "cryptic",
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "rect_5",
			label = "Frame (Skitarii)",
			offset = {
				24,
				-17,
			},
			style = {
				color = {
					255,
					204,
					221,
					184,
				},
				size = {
					137,
					159,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "ability.is_ready",
										kind = "source",
										source = "player_1",
									},
									op = "true",
								},
								{
									join = "and",
									lhs = {
										field = "identity.id",
										kind = "source",
										source = "player_1",
									},
									negate = true,
									op = "==",
									rhs = {
										kind = "fixed",
										value = "cryptic",
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "rect_3",
			label = "Ability Ready Shine",
			offset = {
				18,
				-18,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					147,
					164,
				},
			},
			type = "rect",
			values = {
				material = "content/ui/materials/effects/hud/combat_talent_glow",
			},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "ability.icon_frame_glow",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "identity.id",
										kind = "source",
										source = "player_1",
									},
									op = "==",
									rhs = {
										kind = "fixed",
										value = "cryptic",
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "rect_5_copy",
			label = "Ability Ready Shine (Skitarii)",
			offset = {
				24,
				-17,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					137,
					159,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					text = {
						field = "ability.cooldown_seconds_to_next_charge",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "ability.cooldown_seconds_to_next_charge",
										kind = "source",
										source = "player_1",
									},
									op = ">=",
									rhs = {
										kind = "fixed",
										value = 1,
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "text_1_copy",
			label = "Ability Timer",
			offset = {
				43,
				48,
			},
			style = {
				align = "center",
				color = {
					255,
					211,
					221,
					210,
				},
				font_size = 30,
				shadow = true,
				size = {
					97,
					23,
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
					text = {
						field = "ability.charges",
						kind = "source",
						source = "player_1",
					},
					visible = {
						conditions = {
							rows = {
								{
									join = "and",
									lhs = {
										field = "ability.max_charges",
										kind = "source",
										source = "player_1",
									},
									op = ">=",
									rhs = {
										kind = "fixed",
										value = 2,
									},
								},
							},
						},
						kind = "conditions",
					},
				},
			},
			id = "text_1",
			label = "Ability Count",
			offset = {
				59,
				-16,
			},
			style = {
				align = "center",
				color = {
					255,
					211,
					221,
					210,
				},
				font_size = 24,
				shadow = true,
				size = {
					63,
					24,
				},
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
			},
		},
	},
	offset = {
		379,
		112,
	},
	version = 1,
}