local mod = get_mod("Compass Range Finder")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "display",
				type = "group",
				title = "mod_compass_range_finder_display_title",
				sub_widgets = {
					{
						setting_id = "distance_font_size",
						type = "numeric",
						default_value = 22,
						range = {12, 40},
						title = "mod_compass_range_finder_font_size_title",
						tooltip = "mod_compass_range_finder_font_size_description",
					},
					{
						setting_id = "distance_angle_window_degrees",
						type = "numeric",
						default_value = 20,
						range = {1, 45},
						title = "mod_compass_range_finder_angle_window_title",
						tooltip = "mod_compass_range_finder_angle_window_description",
					},
					{
						setting_id = "distance_horizontal_position",
						type = "numeric",
						default_value = 0.5,
						decimals_number = 2,
						range = {0, 1},
						title = "mod_compass_range_finder_horizontal_position_title",
						tooltip = "mod_compass_range_finder_horizontal_position_description",
					},
					{
						setting_id = "distance_vertical_position",
						type = "numeric",
						default_value = 0.12,
						range = {0, 1},
						decimals_number = 2,
						title = "mod_compass_range_finder_vertical_position_title",
						tooltip = "mod_compass_range_finder_vertical_position_description",
					},
				},
			},
		},
	},
}
