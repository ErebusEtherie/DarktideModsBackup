---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines
local important = mod.dl.loc_helpers.important

local function fury_rank_color(rank)
	return mod.constants.COLOR.FURY_RANK[rank] or mod.constants.COLOR.UI_FOREGROUND
end

local function fury_ranks_short()
	return mod.dl.str.join(
		"  ",
		mod.dl.str.rich_text("D", { color = fury_rank_color("D") }),
		mod.dl.str.rich_text("C", { color = fury_rank_color("C") }),
		mod.dl.str.rich_text("B", { color = fury_rank_color("B") }),
		mod.dl.str.rich_text("A", { color = fury_rank_color("A") }),
		mod.dl.str.rich_text("S", { color = fury_rank_color("S") }),
		mod.dl.str.rich_text("SS", { color = fury_rank_color("SS") }),
		mod.dl.str.rich_text("SSS", { color = fury_rank_color("SSS") }),
		mod.dl.str.rich_text("X", { color = fury_rank_color("X") })
	)
end

local loc = {
	tab_customisation = {
		en = "Customise",
		["zh-cn"] = "自定义",
	},

	headings_customisation_events = {
		en = "Style Events",
		["zh-cn"] = "风格事件",
	},
	max_event_slots = {
		en = "Max Events",
		["zh-cn"] = "最大事件数",
	},
	max_event_slots_description = {
		en = lines(
			"Maximum number of events in the event track",
			important("Note: This increases the height of the panel")
		),
		["zh-cn"] = lines(
			"事件轨道中显示的最大事件数量",
			important("注意：这会增加面板的高度")
		),
	},
	enable_breed_kill_events = {
		en = "Generic Kill Events",
		["zh-cn"] = "通用击杀事件",
	},
	enable_breed_kill_events_description = {
		en = lines(
			"Kills on specials and elites will be logged to the track, similar to the killfeed",
			important("Note: Recommended to increase Max Events (See above), as you will see a lot more events logged.")
		),
		["zh-cn"] = lines(
			"精英和特殊敌人的击杀会像击杀信息一样记录到轨道上",
			important(
				"注意：建议增加最大事件数（见上方），因为你会看到更多事件被记录。"
			)
		),
	},
	enable_colored_breed_kills = {
		en = important("Colored Generic Kill Events"),
		["zh-cn"] = important("为通用击杀事件着色"),
	},
	enable_colored_breed_kills_description = {
		en = lines(
			"If Generic Kill Events are enabled, they will be colored",
			"",
			important("Note: REQUIRES MOD RELOAD (CTRL+SHIFT+R)")
		),
		["zh-cn"] = lines(
			"如果启用了通用击杀事件，它们将显示为彩色",
			"",
			important("注意：需要重新加载模组（CTRL+SHIFT+R）")
		),
	},

	headings_customisation_tasks = {
		en = "Kill List",
		["zh-cn"] = "击杀清单",
	},
	task_track_theme = {
		en = "Kill List Theme",
		["zh-cn"] = "击杀清单主题",
	},
	task_track_theme_description = {
		en = lines("Visual style of the panel.", "Simple uses a plain black gradient panel"),
		["zh-cn"] = lines("面板的视觉风格。", "Simple 使用纯黑色渐变面板"),
	},
	task_track_theme_simple = {
		en = "Simple",
		["zh-cn"] = "简洁",
	},
	task_track_theme_ui = {
		en = "UI",
		["zh-cn"] = "界面风格",
	},

	heading_popups_customisation = {
		en = "Pop-ups",
		["zh-cn"] = "弹出提示",
	},
	enable_kill_markers_description = {
		en = lines("Show a floating pop-up on kill (Recommended)"),
		["zh-cn"] = lines("击杀时显示浮动弹出提示（推荐开启）"),
	},
	enable_immersive_markers = {
		en = "Immersive Markers",
		["zh-cn"] = "沉浸式标记",
	},
	enable_immersive_markers_description = {
		en = lines("Pop-ups in the distance will appear slightly smaller, giving a better effect."),
		["zh-cn"] = lines("远处的弹出提示会显示得略小一些，以获得更好的效果。"),
	},
	marker_fade_duration = {
		en = "Duration",
		["zh-cn"] = "弹出提示持续时间",
	},
	marker_fade_duration_description = {
		en = lines("How long +1 pop-ups stay on screen"),
		["zh-cn"] = lines("+1 等弹出提示在屏幕上停留的时间"),
	},

	heading_customisation_fury_rank = {
		en = "Fury Rank",
		["zh-cn"] = "狂怒等级",
	},
	enable_fury_rank_text = {
		en = "Show Rank",
		["zh-cn"] = "显示等级",
	},
	enable_fury_rank_text_description = {
		en = "Show the current rank above the fury bar",
		["zh-cn"] = "在狂怒条上方显示当前等级",
	},
	enable_class_specific_fury_ranks = {
		en = "Class-specific Ranks",
		["zh-cn"] = "职业专属等级",
	},
	enable_class_specific_fury_ranks_description = {
		en = "Display class-flavoured ranks rather than the generic base ones.",
		["zh-cn"] = "显示职业特色的等级名称，而非通用基础名称。",
	},

	heading_customisation_fury_bar = {
		en = "Fury Bar",
		["zh-cn"] = "狂怒条",
	},
	fury_meter_theme = {
		en = "Theme",
		["zh-cn"] = "主题风格",
	},
	fury_meter_theme_description = {
		en = lines(
			"Visual style of the bar.",
			"",
			"Gritty uses a textured back-plate",
			"UI mimics the in-game UI and might be less visually distracting"
		),
		["zh-cn"] = lines(
			"狂怒条的视觉风格。",
			"",
			"Gritty 使用纹理背景板",
			"UI 风格模仿游戏内界面，视觉干扰较小"
		),
	},
	fury_meter_theme_gritty = {
		en = "Gritty",
		["zh-cn"] = "粗糙风格",
	},
	fury_meter_theme_ui = {
		en = "UI",
		["zh-cn"] = "界面风格",
	},

	heading_customisation_statline = {
		en = "Statline",
		["zh-cn"] = "状态栏",
	},

	statline_stat_none = {
		en = "None",
		["zh-cn"] = "无",
	},
	statline_stat_current_combo = {
		en = "Current Combo",
		["zh-cn"] = "当前连击",
	},
	statline_stat_best_combo = {
		en = "Best Combo",
		["zh-cn"] = "最佳连击",
	},
	statline_stat_last_combo = {
		en = "Last Combo",
		["zh-cn"] = "上次连击",
	},
	statline_stat_total_kills = {
		en = "Total Kills",
		["zh-cn"] = "总击杀数",
	},
	statline_stat_kills_interval = {
		en = "Kills / Interval",
		["zh-cn"] = "击杀 / 时间段",
	},
	statline_stat_dps = {
		en = "DPS",
		["zh-cn"] = "DPS",
	},
	statline_stat_fatigue_pct = {
		en = "Fatigue %%",
		["zh-cn"] = "疲劳 %%",
	},
	statline_stat_fury_pct = {
		en = "Fury %%",
		["zh-cn"] = "狂怒 %%",
	},
	statline_kpm_interval_seconds = {
		en = "Kills Interval (secs)",
		["zh-cn"] = "击杀时间窗口（秒）",
	},
	statline_kpm_interval_seconds_description = {
		en = lines(
			'Trailing window for the "Kills / Interval" statline entry.',
			"Shows how many kills you landed in the last N seconds."
		),
		["zh-cn"] = lines(
			"“击杀 / 时间段”统计项的时间窗口。",
			"显示最近 N 秒内你获得的击杀数量。"
		),
	},

	heading_fury_colors = {
		en = "Fury Colors",
		["zh-cn"] = "狂怒颜色",
	},
	fury_color_stop_1 = {
		en = "0-20%%",
		["zh-cn"] = "0-20%%",
	},
	fury_color_stop_2 = {
		en = "20-40%%",
		["zh-cn"] = "20-40%%",
	},
	fury_color_stop_3 = {
		en = "40-60%%",
		["zh-cn"] = "40-60%%",
	},
	fury_color_stop_4 = {
		en = "60-80%%",
		["zh-cn"] = "60-80%%",
	},
	fury_color_stop_5 = {
		en = "80-100%%",
		["zh-cn"] = "80-100%%",
	},
	fury_color_stop_6 = {
		en = "100-133%%",
		["zh-cn"] = "100-133%%",
	},
	fury_color_stop_7 = {
		en = "133-166%%",
		["zh-cn"] = "133-166%%",
	},
	fury_color_stop_8 = {
		en = "166-200%%",
		["zh-cn"] = "166-200%%",
	},
	fury_color_stop_9 = {
		en = "MAX",
		["zh-cn"] = "最大",
	},

	color_option_default = {
		en = "Default",
		["zh-cn"] = "默认",
	},

	dopamine_rank_d = {
		en = "Rank D",
		["zh-cn"] = "D 级",
	},
	dopamine_rank_c = {
		en = "Rank C",
		["zh-cn"] = "C 级",
	},
	dopamine_rank_b = {
		en = "Rank B",
		["zh-cn"] = "B 级",
	},
	dopamine_rank_a = {
		en = "Rank A",
		["zh-cn"] = "A 级",
	},
	dopamine_rank_s = {
		en = "Rank S",
		["zh-cn"] = "S 级",
	},
	dopamine_rank_ss = {
		en = "Rank SS",
		["zh-cn"] = "SS 级",
	},
	dopamine_rank_sss = {
		en = "Rank SSS",
		["zh-cn"] = "SSS 级",
	},
	dopamine_rank_x = {
		en = "Rank X",
		["zh-cn"] = "X 级",
	},
	dopamine_white = {
		en = "Dopamine White",
		["zh-cn"] = "Dopamine 白色",
	},
	dopamine_green = {
		en = "Dopamine Green",
		["zh-cn"] = "Dopamine 绿色",
	},
	dopamine_orange = {
		en = "Dopamine Orange",
		["zh-cn"] = "Dopamine 橙色",
	},
	dopamine_yellow = {
		en = "Dopamine Yellow",
		["zh-cn"] = "Dopamine 黄色",
	},
	dopamine_red = {
		en = "Dopamine Red",
		["zh-cn"] = "Dopamine 红色",
	},

	heading_stat_chart_customisation = {
		en = "Stat Chart",
		["zh-cn"] = "统计图表",
	},
	stat_chart_bar_color = { en = "Bar Color", ["zh-cn"] = "柱状图颜色" },
	stat_chart_bar_color_description = {
		en = lines("The fill color of the stat chart bars."),
		["zh-cn"] = lines("统计图表柱状的填充颜色。"),
	},
	stat_chart_cycle_keybind = {
		en = "Cycle Stat Chart Metric",
		["zh-cn"] = "切换统计图表指标",
	},
	stat_chart_cycle_keybind_description = {
		en = lines("Cycles the stat chart between the tracked metrics (damage dealt, kills)."),
		["zh-cn"] = lines("在已追踪的指标之间切换统计图表（造成伤害、击杀数）。"),
	},
}

for key in pairs(mod.dl.colors.reg.gw) do
	loc[key] = {
		en = "GW " .. mod.dl.str.machine_to_human_text(key),
	}
end

return loc
