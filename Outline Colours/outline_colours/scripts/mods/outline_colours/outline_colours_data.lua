local mod = get_mod("outline_colours")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets =
		{
			{
				setting_id = "smart_tagged_enemy_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "smart_tagged_enemy_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 2,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "smart_tagged_enemy_r",
						title = "title_r",
						type = "numeric",
						default_value = 1,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "smart_tagged_enemy_g",
						title = "title_g",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "smart_tagged_enemy_b",
						title = "title_b",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			{
				setting_id = "veteran_smart_tag_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "veteran_smart_tag_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 1,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "veteran_smart_tag_r",
						title = "title_r",
						type = "numeric",
						default_value = 1,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "veteran_smart_tag_g",
						title = "title_g",
						type = "numeric",
						default_value = 0.8,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "veteran_smart_tag_b",
						title = "title_b",
						type = "numeric",
						default_value = 0.4,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			{
				setting_id = "special_target_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "special_target_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 2,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "special_target_r",
						title = "title_r",
						type = "numeric",
						default_value = 0.8,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "special_target_g",
						title = "title_g",
						type = "numeric",
						default_value = 0.75,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "special_target_b",
						title = "title_b",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			{
				setting_id = "smart_tagged_enemy_passive_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "smart_tagged_enemy_passive_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 1,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "smart_tagged_enemy_passive_r",
						title = "title_r",
						type = "numeric",
						default_value = 0.8,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "smart_tagged_enemy_passive_g",
						title = "title_g",
						type = "numeric",
						default_value = 0.75,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "smart_tagged_enemy_passive_b",
						title = "title_b",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			-- Doesn't work
			{
				setting_id = "psyker_marked_target_group",
				type = "group",
				sub_widgets =
				{
					{
					  setting_id = "psyker_marked_target_priority",
			     tooltip = "priority_tooltip",
			     title = "priority_title",
						type = "numeric",
						default_value = 1,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "psyker_marked_target_r",
			     title = "title_r",
						type = "numeric",
						default_value = 1,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "psyker_marked_target_g",
			     title = "title_g",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "psyker_marked_target_b",
			     title = "title_b",
						type = "numeric",
						default_value = 0,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			{
				setting_id = "player_outline_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "player_outline_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 3,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "player_outline_r",
						title = "title_r",
						type = "numeric",
						default_value = 0.4,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "player_outline_g",
						title = "title_g",
						type = "numeric",
						default_value = 0.85,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "player_outline_b",
						title = "title_b",
						type = "numeric",
						default_value = 0.90,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
			{
				setting_id = "player_outline_downed_group",
				type = "group",
				sub_widgets =
				{
					{
						setting_id = "player_outline_downed_priority",
						tooltip = "priority_tooltip",
						title = "priority_title",
						type = "numeric",
						default_value = 2,
						range = {1, 10},
						decimals_number = 0
					},
					{
						setting_id = "player_outline_downed_r",
						title = "title_r",
						type = "numeric",
						default_value = 1,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "player_outline_downed_g",
						title = "title_g",
						type = "numeric",
						default_value = 0.8,
						range = {0, 1},
						decimals_number = 2
					},
					{
						setting_id = "player_outline_downed_b",
						title = "title_b",
						type = "numeric",
						default_value = 0.1,
						range = {0, 1},
						decimals_number = 2
					},
				}
			},
		},
	},
}
