return {
	grid_cols = 0,
	grid_rows = 0,
	label = "Portrait, Frame and Insignia",
	localizations = {},
	name = "Portrait_Frame_and_Insignia",
	nodes = {
		{
			callbacks = {
				value = {
					material = {
						field = "profile.insignia",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_2",
			label = "Insignia",
			offset = {
				-182,
				147,
			},
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
				size = {
					40,
					94,
				},
			},
			type = "rect",
			values = {},
		},
		{
			callbacks = {
				value = {
					material = {
						field = "profile.portrait",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "rect_1",
			label = "Portrait",
			offset = {
				-137,
				143,
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
	},
	offset = {
		-411,
		-59,
	},
	version = 1,
}