return {
	grid_cols = 0,
	grid_rows = 0,
	label = "True Level Name",
	localizations = {},
	name = "True_Level_Name",
	nodes = {
		{
			callbacks = {
				value = {
					text = {
						field = "profile.tl_display_name",
						kind = "source",
						source = "player_1",
					},
				},
			},
			id = "text_1",
			label = "True Level Name",
			offset = {
				44,
				19,
			},
			style = {
				shadow = true,
			},
			type = "text",
			values = {
				mode = "fixed",
				text = "Text",
			},
		},
	},
	offset = {
		-378,
		9,
	},
	version = 1,
}