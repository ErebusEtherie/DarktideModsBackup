---@type mod
local mod = get_mod("dopamine")

local labels = {
	font = {
		en = "Font",
		["zh-cn"] = "字体",
	},
	task_track_title = {
		en = "KILL LIST",
		["zh-cn"] = "击杀清单",
	},
	style_multiplier_label = {
		en = "Multiplier",
		["zh-cn"] = "倍率",
	},
	statline_combo_label = {
		en = "COMBO",
		["zh-cn"] = "连击",
	},
	statline_best_label = {
		en = "BEST",
		["zh-cn"] = "最佳",
	},
	statline_last_label = {
		en = "LAST",
		["zh-cn"] = "上次",
	},
	statline_total_label = {
		en = "KILLS",
		["zh-cn"] = "总击杀",
	},
	statline_kills_interval_label = {
		en = "KP/S",
		["zh-cn"] = "KP/S",
	},
	statline_dps_label = {
		en = "DPS",
		["zh-cn"] = "DPS",
	},
	statline_fatigue_label = {
		en = "FATIGUE",
		["zh-cn"] = "疲劳",
	},
	statline_fury_label = {
		en = "FURY",
		["zh-cn"] = "狂怒",
	},

	style_points = {
		en = "Style Points",
		["zh-cn"] = "风格点数",
	},
	fury_bar = {
		en = "Fury Bar",
		["zh-cn"] = "狂怒条",
	},
	theme = {
		en = "Theme",
		["zh-cn"] = "主题",
	},
	fury = { en = "Fury", ["zh-cn"] = "狂怒" },
	master_toggle = {
		en = "Master Toggle",
		["zh-cn"] = "总开关",
	},
	width = {
		en = "Width",
		["zh-cn"] = "宽度",
	},
	height = {
		en = "Height",
		["zh-cn"] = "高度",
	},
	duration = {
		en = "Duration",
		["zh-cn"] = "持续时间",
	},
	slot_none = {
		en = "- None -",
		["zh-cn"] = "- 无 -",
	},
	author = {
		en = "AUTHOR",
		["zh-cn"] = "作者",
	},
	version = {
		en = "VERSION",
		["zh-cn"] = "版本",
	},
	access_granted = {
		en = "- ACCESS GRANTED -",
		["zh-cn"] = "- 访问授权 -",
	},
	terminated = {
		en = "- TERMINATED -",
		["zh-cn"] = "- 已终止 -",
	},
	total = {
		en = "TOTAL",
		["zh-cn"] = "总计",
	},
	kills = {
		en = "KILLS",
		["zh-cn"] = "击杀",
	},
	damage = {
		en = "DAMAGE",
		["zh-cn"] = "伤害",
	},
	misc = {
		en = "MISC",
		["zh-cn"] = "杂项",
	},
	career = {
		en = "CAREER",
		["zh-cn"] = "职业",
	},
	ranged = {
		en = "RANGED",
		["zh-cn"] = "远程",
	},
	melee = {
		en = "MELEE",
		["zh-cn"] = "近战",
	},

	stat_chart_metric_damage = {
		en = "DAMAGE DEALT",
		["zh-cn"] = "造成伤害",
	},
	stat_chart_metric_kills = {
		en = "KILLS",
		["zh-cn"] = "击杀数",
	},
	transitions = {
		en = "TRANSITIONS",
		["zh-cn"] = "过渡",
	},
}

for seconds = 5, 60, 5 do
	labels["statline_kills_interval_label_" .. seconds] = {
		en = "KP/" .. seconds .. "s",
		["zh-cn"] = "KP/" .. seconds .. "秒",
	}
end

return labels
