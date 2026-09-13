local mod = get_mod("BrokerStimTimer")



local widgets = {
	{
		setting_id = "display_group",
		type = "group",
		tab = mod:localize("general"),
		sub_widgets = {
			{
				setting_id = "track_standard_stims",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "font_size",
				type = "numeric",
				default_value = 25,
				range = { 10, 100 },
			},
			{
				setting_id = "icon_size",
				type = "numeric",
				default_value = 55,
				range = { 16, 128 },
			},
			{
				setting_id = "show_decimals",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "link_all_positions",
				type = "checkbox",
				default_value = true,
			},
		}
	},
	{
		setting_id = "shared_position_group",
		type = "group",
		tab = mod:localize("general"),
		sub_widgets = {
			{
				setting_id = "shared_icon_x",
				type = "numeric",
				default_value = 765,
				range = { 0, 3840 },
			},
			{
				setting_id = "shared_icon_y",
				type = "numeric",
				default_value = 620,
				range = { 0, 1080 },
			},
			{
				setting_id = "shared_text_x",
				type = "numeric",
				default_value = 761,
				range = { 0, 3840 },
			},
			{
				setting_id = "shared_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
		}
	},
		{
			setting_id = "ready_group",
			type = "group",
			tab = mod:localize("ready_group"),
			sub_widgets = {
				{
					setting_id = "ready_color",
					type = "color",
					default_value = { 255, 74, 177, 85 },
				},
				{
					setting_id = "ready_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
			{
				setting_id = "ready_icon_y",
				type = "numeric",
				default_value = 620,
				range = { 0, 1080 },
			},
			{
				setting_id = "ready_show_icon",
				type = "checkbox",
				default_value = true,
			},
		}
	},
		{
			setting_id = "active_group",
			type = "group",
			tab = mod:localize("active_group"),
			sub_widgets = {
				{
					setting_id = "active_color",
					type = "color",
					default_value = { 255, 226, 199, 126 },
				},
				{
					setting_id = "active_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
				{
					setting_id = "active_icon_y",
					type = "numeric",
					default_value = 620,
					range = { 0, 1080 },
				},
				{
					setting_id = "active_text_x",
					type = "numeric",
					default_value = 561,
					range = { 0, 3840 },
				},
			{
				setting_id = "active_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
			{
				setting_id = "active_show_icon",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "active_show_timer",
				type = "checkbox",
				default_value = true,
			},
		}
	},
		{
			setting_id = "cooldown_group",
			type = "group",
			tab = mod:localize("cooldown_group"),
			sub_widgets = {
				{
					setting_id = "cooldown_color",
					type = "color",
					default_value = { 255, 246, 69, 69 },
				},
				{
					setting_id = "cooldown_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
				{
					setting_id = "cooldown_icon_y",
					type = "numeric",
					default_value = 620,
					range = { 0, 1080 },
				},
				{
					setting_id = "cooldown_text_x",
					type = "numeric",
					default_value = 561,
					range = { 0, 3840 },
				},
			{
				setting_id = "cooldown_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
			{
				setting_id = "cooldown_show_icon",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "cooldown_show_timer",
				type = "checkbox",
				default_value = true,
			},
		}
	},
}



return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}


