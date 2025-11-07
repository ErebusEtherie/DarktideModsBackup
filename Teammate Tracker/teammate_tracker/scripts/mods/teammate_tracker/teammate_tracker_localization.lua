return {
	mod_name = {
		en = "Teammate Tracker",
		["zh-cn"] = "队友追踪器",
	},
	mod_description = {
		en = "Display the win/loss records of teammates and yourself. If you haven't imported any scoreboard history, this setting will have no effect. Type /tt_scoreboard in chat to import scoreboard records.",
		["zh-cn"] = "显示队友和自己的胜负记录。如果你没有导入过计分板的历史记录，计分板设置里的开关不会发生任何事情。在聊天框输入/tt_scoreboard导入计分板。",
	},
	
	-- display style
	group_display_style_title = {
		en = "Display Style",
		["zh-cn"] = "显示样式",
	},

	display_style_title = {
		en = "Display Style",
		["zh-cn"] = "显示样式",
	},
	display_style_tooltip = {
		en = 
			"Classic: 						+255 -107 !6\n" ..
			"Show wins only (win only): 	255\n" ..
			"Win/Loss Ratio: 				2.26\n" ..
			"Win/Loss Ratio (exclude left):	2.38 !6\n" ..
			"Win Rate (%%): 				69.3%%\n" ..
			"Win Rate (%% only): 			70.4%% !6",
		["zh-cn"] = 
			"经典：					+255 -107 !6\n" ..
			"仅显示胜场：			255\n" ..
			"胜负比：				2.26\n" ..
			"胜负比（不含早退）：	2.38 !6\n" ..
			"胜率：					69.3%%\n" ..
			"胜率（不含退）：		70.4%% !6",
	},

	display_style_text_full = {
		en = "Classic",
		["zh-cn"] = "经典",
	},
	display_style_text_win_only = {
		en = "Show wins only",
		["zh-cn"] = "仅显示胜场",
	},
	display_style_ratio_include_left = {
		en = "Win/Loss Ratio",
		["zh-cn"] = "胜负比",
	},
	display_style_ratio_exclude_left = {
		en = "Win/Loss Ratio (exclude left)",
		["zh-cn"] = "胜负比（不含早退）",
	},
	display_style_percentage_include_left = {
		en = "Win Rate",
		["zh-cn"] = "胜率",
	},
	display_style_percentage_exclude_left = {
		en = "Win Rate (exclude left)",
		["zh-cn"] = "胜率（不含早退）",
	},

	show_no_record_title = {
		en = "Show new player marker",
		["zh-cn"] = "显示新玩家标记",
	},
	show_no_record_tooltip = {
		en = "Display 'new!' if a player has no record with you.",
		["zh-cn"] = "当玩家从未与你一起游戏时，显示“new!”作为标识。",
	},
	difficulty_therehold_title = {
		en = "Minimum Difficulty",
		["zh-cn"] = "最低难度",
	},
	difficulty_therehold_tooltip = {
		en = "Only records missions with difficulty greater than or equal to this value.",
		["zh-cn"] = "仅记录难度大于或等于该数值的对局。",
	},
	
	-- self
  	group_self_title = {
		en = "Self Settings",
		["zh-cn"] = "个人设置",
	},
	
	show_self_title = {
		en = "Show Self",
		["zh-cn"] = "显示自己",
	},
	show_self_tooltip = {
		en = "Show your own wins, losses, and early quits.",
		["zh-cn"] = "显示你自己的胜,负,早退场信息。",
	},
	split_self_by_class_title = {
		en = "Split Self by Class",
		["zh-cn"] = "按职业区分",
	},
	split_self_by_class_tooltip = {
		en = "Track wins, losses and early quits separately for each class.",
		["zh-cn"] = "分别统计在不同职业下的胜,负,早退场信息。",
	},
	-- show_self_loss_left_title = {
		-- en = "Show losses and leaves",
		-- ["zh-cn"] = "显示失败和早退场信息",
	-- },
	-- show_self_loss_left_tooltip = {
		-- en = "Show loss and early quit information. If disabled, only win information will be shown.",
		-- ["zh-cn"] = "显示失败和早退场信息，关闭则只显示胜场信息。",
	-- },
	self_day_therehold_title = {
		en = "Time Filter",
		["zh-cn"] = "时间过滤",
	},
	self_day_therehold_tooltip = {
		en = "Only records within this time range will be included.",
		["zh-cn"] = "仅包含在该时间范围内的自身战绩。",
	},
	self_day_therehold_all_time = {
		en = "All Time",
		["zh-cn"] = "全部时间",
	},
	self_day_therehold_last_1_day = {
		en = "Last 1 Day",
		["zh-cn"] = "最近 1 天",
	},
	self_day_therehold_last_7_days = {
		en = "Last 7 Days",
		["zh-cn"] = "最近 7 天",
	},
	self_day_therehold_last_30_days = {
		en = "Last 30 Days",
		["zh-cn"] = "最近 30 天",
	},
	
	-- others
	group_others_title = {
		en = "Others Settings",
		["zh-cn"] = "其他人设置",
	},
	
	show_others_title = {
		en = "Show Others",
		["zh-cn"] = "显示其他人",
	},
	show_others_tooltip = {
		en = "Show other players' wins, losses, and early quits.",
		["zh-cn"] = "显示其他玩家的胜,负,早退场信息。",
	},
	split_others_by_class_title = {
		en = "Split Self by Class",
		["zh-cn"] = "按职业区分",
	},
	split_others_by_class_tooltip = {
		en = "Track wins, losses and early quits separately for each class.",
		["zh-cn"] = "分别统计在不同职业下的胜,负,早退场信息。",
	},
	-- show_others_loss_left_title = {
		-- en = "Show losses and leaves",
		-- ["zh-cn"] = "显示失败和早退场信息",
	-- },
	-- show_others_loss_left_tooltip = {
		-- en = "Show loss and early quit information. If disabled, only win information will be shown.",
		-- ["zh-cn"] = "显示失败和早退场信息，关闭则只显示胜场信息。",
	-- },
	others_day_therehold_title = {
		en = "Time Filter",
		["zh-cn"] = "时间过滤",
	},
	others_day_therehold_tooltip = {
		en = "Only records within this time range will be included.",
		["zh-cn"] = "仅包含在该时间范围内的自身战绩。",
	},
	others_day_therehold_all_time = {
		en = "All Time",
		["zh-cn"] = "全部时间",
	},
	others_day_therehold_last_1_day = {
		en = "Last 1 Day",
		["zh-cn"] = "最近 1 天",
	},
	others_day_therehold_last_7_days = {
		en = "Last 7 Days",
		["zh-cn"] = "最近 7 天",
	},
	others_day_therehold_last_30_days = {
		en = "Last 30 Days",
		["zh-cn"] = "最近 30 天",
	},

	-- elements display
	group_display_section_title = {
		en = "Enable Display in Sections",
		["zh-cn"] = "按界面启用数据显示",
	},
	
	tt_display_end_view_title = {
		en = "Results Screen",
		["zh-cn"] = "结算界面",
	},
	tt_display_end_view_tooltip = {
		en = "Enable stat display on the results screen after a mission ends.",
		["zh-cn"] = "启用后，在任务结束后的结算界面显示战绩。",
	},
	tt_display_inventory_title = {
		en = "Inventory",
		["zh-cn"] = "库存",
	},
	tt_display_inventory_tooltip = {
		en = "Enable stat display in the inventory or loadout interface.",
		["zh-cn"] = "启用后，在库存或装备界面显示战绩。",
	},
	tt_display_lobby_title = {
		en = "Lobby",
		["zh-cn"] = "小队大厅",
	},
	tt_display_lobby_tooltip = {
		en = "Enable stat display in the mission preparation lobby before deployment.",
		["zh-cn"] = "启用后，在出发前的小队准备大厅界面显示战绩。",
	},
	tt_display_nameplate_title = {
		en = "Nameplates",
		["zh-cn"] = "名称标签",
	},
	tt_display_nameplate_tooltip = {
		en = "Enable stat display on floating nameplates above players’ heads.",
		["zh-cn"] = "启用后，在玩家头顶的名称标签上显示战绩。",
	},
	tt_display_main_menu_title = {
		en = "Character Select Screen",
		["zh-cn"] = "角色选择界面",
	},
	tt_display_main_menu_tooltip = {
		en = "Enable stat display in the character selection screen of the main menu.",
		["zh-cn"] = "启用后，在主菜单的角色选择界面显示战绩。",
	},
	tt_display_inspect_player_title = {
		en = "Inspect Operative",
		["zh-cn"] = "检视特工",
	},
	tt_display_inspect_player_tooltip = {
		en = "Enable stat display when inspecting an operative’s profile.",
		["zh-cn"] = "启用后，在检视特工档案时显示战绩。",
	},
	tt_display_team_panel_title = {
		en = "Team HUD",
		["zh-cn"] = "团队 HUD",
	},
	tt_display_team_panel_tooltip = {
		en = "Enable stat display in the left-bottom HUD panel during mission.",
		["zh-cn"] = "启用后，在战斗中左下角团队面板显示战绩。",
	},
	tt_display_social_menu_title = {
		en = "Social Menu",
		["zh-cn"] = "社交菜单",
	},
	tt_display_social_menu_tooltip = {
		en = "Enable stat display in the social menu interface.",
		["zh-cn"] = "启用后，在社交菜单界面显示战绩。",
	},
	tt_display_group_finder_title = {
		en = "Party Finder",
		["zh-cn"] = "寻找队伍",
	},
	tt_display_group_finder_tooltip = {
		en = "Enable stat display in the party finder interface.",
		["zh-cn"] = "启用后，在寻找队伍界面显示战绩。",
	},

	-- scoreboard option
	scoreboard_title = {
		en = "Scoreboard option",
		["zh-cn"] = "计分板设置",
	},
	
	enable_scoreboard_records_title = {
		en = "Enable scoreboard records",
		["zh-cn"] = "启用计分板记录",
	},
	enable_scoreboard_records_tooltip = {
		en = "Includes stats from scoreboard records when enabled. If split by class is enabled, stats will be counted for all agents of the same class, since the scoreboard cannot distinguish between them.",
		["zh-cn"] = "开启会包含来自计分板的战绩；当启用职业区分的时候，计分板的战绩会统计到所有相同职业的特工，因为计分板无法分辨相同职业的特工。",
	},
	
	-- scoreboard cmd messages
	scoreboard_written = {
		en = "A total of %%d records have been written to teammate_tracker_history.txt.",
		["zh-cn"] = "共 %%d 条记录已写入 teammate_tracker_history.txt。",
	},
	scoreboard_none = {
		en = "No scoreboard files were added.",
		["zh-cn"] = "未添加任何 scoreboard 历史记录。",
	},
	scoreboard_possible_reason = {
		en = "Possible reasons:",
		["zh-cn"] = "可能的原因：",
	},
	scoreboard_reason_imported = {
		en = "- History files may have already been imported.",
		["zh-cn"] = "- 历史文件可能已经导入过。",
	},
	scoreboard_reason_early = {
		en = "- Match history is earlier than scoreboard records.",
		["zh-cn"] = "- 计分板的记录早于历史记录。",
	},
}

