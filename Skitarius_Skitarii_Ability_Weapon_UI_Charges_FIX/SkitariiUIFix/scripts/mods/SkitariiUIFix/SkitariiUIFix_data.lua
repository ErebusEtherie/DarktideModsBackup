local mod = get_mod("SkitariiUIFix")

local color_options = {
	{ text = "color_green",  value = "green" },
	{ text = "color_red",    value = "red" },
	{ text = "color_pink",   value = "pink" },
	{ text = "color_purple", value = "purple" },
	{ text = "color_white",  value = "white" },
	{ text = "color_yellow", value = "yellow" },
	{ text = "color_orange", value = "orange" },
	{ text = "color_cyan",   value = "cyan" },
}

local mirror_options = {
	{ text = "mirror_none",       value = "none" },
	{ text = "mirror_horizontal", value = "horizontal" },
	{ text = "mirror_vertical",   value = "vertical" },
	{ text = "mirror_both",       value = "both" },
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "ability_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "ability_enabled",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "ability_skitarii_only",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "ability_percent_position",
						type = "dropdown",
						default_value = "icon",
						options = {
							{ text = "ability_pos_icon",    value = "icon" },
							{ text = "ability_pos_charges", value = "charges" },
						},
					},
					{
						setting_id = "ability_color",
						type = "dropdown",
						default_value = "green",
						options = color_options,
					},
					{
						setting_id = "ability_font_size",
						type = "numeric",
						default_value = 28,
						range = { 14, 60 },
						step_size_value = 1,
					},
					{
						setting_id = "ability_percent_offset_x",
						type = "numeric",
						default_value = 0,
						range = { -300, 300 },
						step_size_value = 2,
					},
					{
						setting_id = "ability_percent_offset_y",
						type = "numeric",
						default_value = 0,
						range = { -300, 300 },
						step_size_value = 2,
					},
				},
			},
			{
				setting_id = "wc_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "wc_enabled",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "wc_mode",
						type = "dropdown",
						default_value = "recolor",
						options = {
							{ text = "wc_mode_recolor", value = "recolor" },
							{ text = "wc_mode_numbers", value = "numbers" },
							{ text = "wc_mode_vanilla", value = "vanilla" },
						},
					},
					{
						setting_id = "wc_offset_x",
						type = "numeric",
						default_value = 0,
						range = { -800, 800 },
						step_size_value = 5,
					},
					{
						setting_id = "wc_offset_y",
						type = "numeric",
						default_value = 0,
						range = { -800, 800 },
						step_size_value = 5,
					},
					{
						setting_id = "wc_mirror",
						type = "dropdown",
						default_value = "none",
						options = mirror_options,
					},
					{
						setting_id = "wc_rotation",
						type = "numeric",
						default_value = 0,
						range = { 0, 355 },
						step_size_value = 5,
					},
					{
						setting_id = "wc_color",
						type = "dropdown",
						default_value = "white",
						options = color_options,
					},
					{
						setting_id = "wc_fill_contrast",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "wc_fill_color",
						type = "dropdown",
						default_value = "white",
						options = color_options,
					},
					{
						setting_id = "wc_no_fade_fill",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "wc_no_fade_outline",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "wc_font_size",
						type = "numeric",
						default_value = 48,
						range = { 20, 140 },
						step_size_value = 2,
					},
					{
						setting_id = "wc_number_opacity",
						type = "numeric",
						default_value = 75,
						range = { 10, 100 },
						step_size_value = 5,
					},
				},
			},
			{
				setting_id = "order_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "order_keybind",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "order_skull_target",
					},
					{
						setting_id = "order_cooldown",
						type = "numeric",
						default_value = 0.3,
						range = { 0.1, 1 },
						step_size_value = 0.1,
						decimals_number = 1,
					},
					{
						setting_id = "order_block_dome",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "order_edge_tolerance",
						type = "numeric",
						default_value = 0.25,
						range = { 0, 1 },
						step_size_value = 0.05,
						decimals_number = 2,
					},
					{
						setting_id = "order_block_smoke",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "order_debug",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "skull_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "skull_enabled",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "skull_always_show",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "skull_seconds_mode",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "skull_offset_x",
						type = "numeric",
						default_value = 0,
						range = { -800, 800 },
						step_size_value = 5,
					},
					{
						setting_id = "skull_offset_y",
						type = "numeric",
						default_value = 0,
						range = { -800, 800 },
						step_size_value = 5,
					},
					{
						setting_id = "skull_mirror",
						type = "dropdown",
						default_value = "horizontal",
						options = mirror_options,
					},
					{
						setting_id = "skull_rotation",
						type = "numeric",
						default_value = 0,
						range = { 0, 355 },
						step_size_value = 5,
					},
					{
						setting_id = "skull_color",
						type = "dropdown",
						default_value = "cyan",
						options = color_options,
					},
					{
						setting_id = "skull_outline_opacity",
						type = "numeric",
						default_value = 100,
						range = { 10, 100 },
						step_size_value = 5,
					},
					{
						setting_id = "skull_fill_color",
						type = "dropdown",
						default_value = "cyan",
						options = color_options,
					},
					{
						setting_id = "skull_fill_opacity",
						type = "numeric",
						default_value = 90,
						range = { 10, 100 },
						step_size_value = 5,
					},
					{
						setting_id = "skull_font_size",
						type = "numeric",
						default_value = 26,
						range = { 14, 60 },
						step_size_value = 1,
					},
				},
			},
		},
	},
}
