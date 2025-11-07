local mod = get_mod("teammate_tracker")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
			{
				setting_id = "group_display_style",
				type = "group",
				title = "group_display_style_title",
				sub_widgets = {
					{
						setting_id = "display_style",
						type = "dropdown",
						default_value = "text_full",
						options = {
							{text = "display_style_text_full", value = "text_full"},
							{text = "display_style_text_win_only", value = "text_win_only"},
							{text = "display_style_ratio_include_left", value = "ratio_include_left"},
							{text = "display_style_ratio_exclude_left", value = "ratio_exclude_left"},
							{text = "display_style_percentage_include_left", value = "percentage_include_left"},
							{text = "display_style_percentage_exclude_left", value = "percentage_exclude_left"},
						},
						title = "display_style_title",
						tooltip = "display_style_tooltip"
					},
					{
						setting_id = "show_no_record",
						type = "checkbox",
						default_value = true,
						title = "show_no_record_title",
						tooltip = "show_no_record_tooltip"
					},
					{
						setting_id = "difficulty_therehold",
						type = "numeric",
						default_value = 1,
						range = {1, 5},
						step_size = 1,
						title = "difficulty_therehold_title",
						tooltip = "difficulty_therehold_tooltip"
					},
				}
			},
            {
                setting_id = "group_self",
                type = "group",
                title = "group_self_title",
                sub_widgets = {
                    {
                        setting_id = "show_self",
                        type = "checkbox",
                        default_value = true,
                        title = "show_self_title",
                        tooltip = "show_self_tooltip"
                    },
                    {
                        setting_id = "split_self_by_class",
                        type = "checkbox",
                        default_value = true,
                        title = "split_self_by_class_title",
                        tooltip = "split_self_by_class_tooltip"
                    },
					-- {
                        -- setting_id = "show_self_loss_left",
                        -- type = "checkbox",
                        -- default_value = true,
                        -- title = "show_self_loss_left_title",
                        -- tooltip = "show_self_loss_left_tooltip"
                    -- },
					{
						setting_id = "self_day_therehold",
						type = "dropdown",
						default_value = 0,
						options = {
							{text = "self_day_therehold_all_time", value = 0},
							{text = "self_day_therehold_last_1_day", value = 1},
							{text = "self_day_therehold_last_7_days", value = 7},
							{text = "self_day_therehold_last_30_days", value = 30},
						},
						title = "self_day_therehold_title",
						tooltip = "self_day_therehold_tooltip"
					},
                }
            },
            {
                setting_id = "group_others",
                type = "group",
                title = "group_others_title",
                sub_widgets = {
                    {
                        setting_id = "show_others",
                        type = "checkbox",
                        default_value = true,
                        title = "show_others_title",
                        tooltip = "show_others_tooltip"
                    },
					{
                        setting_id = "split_others_by_class",
                        type = "checkbox",
                        default_value = false,
                        title = "split_others_by_class_title",
                        tooltip = "split_others_by_class_tooltip"
                    },
					-- {
                        -- setting_id = "show_others_loss_left",
                        -- type = "checkbox",
                        -- default_value = true,
                        -- title = "show_others_loss_left_title",
                        -- tooltip = "show_others_loss_left_tooltip"
                    -- },
					{
						setting_id = "others_day_therehold",
						type = "dropdown",
						default_value = 0,
						options = {
							{text = "others_day_therehold_all_time", value = 0},
							{text = "others_day_therehold_last_1_day", value = 1},
							{text = "others_day_therehold_last_7_days", value = 7},
							{text = "others_day_therehold_last_30_days", value = 30},
						},
						title = "others_day_therehold_title",
						tooltip = "others_day_therehold_tooltip"
					},
                }
            },
			{
				setting_id = "group_display_section",
				type = "group",
				title = "group_display_section_title",
				sub_widgets = {
					{
						setting_id = "tt_display_end_view",
						type = "checkbox",
						default_value = true,
						title = "tt_display_end_view_title",
						tooltip = "tt_display_end_view_tooltip"
					},
					{
						setting_id = "tt_display_inventory",
						type = "checkbox",
						default_value = false,
						title = "tt_display_inventory_title",
						tooltip = "tt_display_inventory_tooltip"
					},
					{
						setting_id = "tt_display_lobby",
						type = "checkbox",
						default_value = true,
						title = "tt_display_lobby_title",
						tooltip = "tt_display_lobby_tooltip"
					},
					{
						setting_id = "tt_display_nameplate",
						type = "checkbox",
						default_value = false,
						title = "tt_display_nameplate_title",
						tooltip = "tt_display_nameplate_tooltip"
					},
					{
						setting_id = "tt_display_main_menu",
						type = "checkbox",
						default_value = true,
						title = "tt_display_main_menu_title",
						tooltip = "tt_display_main_menu_tooltip"
					},
					{
						setting_id = "tt_display_inspect_player",
						type = "checkbox",
						default_value = true,
						title = "tt_display_inspect_player_title",
						tooltip = "tt_display_inspect_player_tooltip"
					},
					{
						setting_id = "tt_display_team_panel",
						type = "checkbox",
						default_value = true,
						title = "tt_display_team_panel_title",
						tooltip = "tt_display_team_panel_tooltip"
					},
					{
						setting_id = "tt_display_social_menu",
						type = "checkbox",
						default_value = true,
						title = "tt_display_social_menu_title",
						tooltip = "tt_display_social_menu_tooltip"
					},
					{
						setting_id = "tt_display_group_finder",
						type = "checkbox",
						default_value = true,
						title = "tt_display_group_finder_title",
						tooltip = "tt_display_group_finder_tooltip"
					},
				}
			},
            {
                setting_id = "scoreboard",
                type = "group",
                title = "scoreboard_title",
                sub_widgets = {
                    {
                        setting_id = "enable_scoreboard_records",
                        type = "checkbox",
                        default_value = true,
                        title = "enable_scoreboard_records_title",
                        tooltip = "enable_scoreboard_records_tooltip"
                    },
                }
            }
        }
    }
}
