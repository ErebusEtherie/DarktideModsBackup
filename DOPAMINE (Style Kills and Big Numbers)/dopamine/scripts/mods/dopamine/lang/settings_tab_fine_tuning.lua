---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines

return {
	tab_fine_tuning = {
		en = "Fine Tuning",
		["zh-cn"] = "微调",
	},

	fury_min_damage_gain = {
		en = "Min. Fury per Hit",
		["zh-cn"] = "每次命中最小狂怒",
	},
	fury_min_damage_gain_description = {
		en = lines("Minimum fury % added by a qualifying damage hit (prevents tiny gains from fast attacks)."),
		["zh-cn"] = lines("有效伤害命中最少增加的狂怒百分比（防止快速攻击产生微小增益）。"),
	},
	fury_max_damage_gain = {
		en = "Max. Fury per Hit",
		["zh-cn"] = "每次命中最大狂怒",
	},
	fury_max_damage_gain_description = {
		en = lines("Maximum fury % added by a qualifying damage hit (caps huge single hits)."),
		["zh-cn"] = lines("有效伤害命中最多增加的狂怒百分比（防止单次巨额增益）。"),
	},
	fury_drain_seconds = {
		en = "Fury Drain Time",
		["zh-cn"] = "狂怒衰减时间",
	},
	fury_drain_seconds_description = {
		en = lines(
			"Seconds for fury to drain from 100% to 0% at the base rate (before grace and low-fury slowdown)."
		),
		["zh-cn"] = lines("狂怒从 100% 衰减到 0% 的基准时间（不包含宽恕期和低狂怒减速）。"),
	},
	max_fury_fatigue_add = {
		en = "Fatigue Added After Max Fury",
		["zh-cn"] = "满狂怒后增加疲劳",
	},
	max_fury_fatigue_add_description = {
		en = lines("Fatigue % added the moment the max fury lockout ends and fury drops from 100%. 0 = none."),
		["zh-cn"] = lines("满狂怒锁定结束、狂怒从 100% 掉落时增加的疲劳百分比。0 = 不增加。"),
	},

	fine_tuning_fatigue = {
		en = "Fatigue",
		["zh-cn"] = "疲劳",
	},
	fatigue_min_damage_gain = {
		en = "Min. Fatigue per Hit",
		["zh-cn"] = "每次命中最小疲劳",
	},
	fatigue_min_damage_gain_description = {
		en = lines("Minimum fatigue % added by a qualifying damage hit (prevents tiny gains from fast attacks)."),
		["zh-cn"] = lines("有效伤害命中最少增加的疲劳百分比（防止快速攻击产生微小增益）。"),
	},
	fatigue_max_damage_gain = {
		en = "Max. Fatigue per Hit",
		["zh-cn"] = "每次命中最大疲劳",
	},
	fatigue_max_damage_gain_description = {
		en = lines("Maximum fatigue % added by a qualifying damage hit (caps huge single hits)."),
		["zh-cn"] = lines("有效伤害命中最多增加的疲劳百分比（防止单次巨额增益）。"),
	},
	fury_fatigue_drain_rate_pct = {
		en = "High-Fatigue Fury Drain Rate",
		["zh-cn"] = "高疲劳时狂怒衰减速率",
	},
	fury_fatigue_drain_rate_pct_description = {
		en = lines(
			"Fury time-drain speed while fatigue is above the high-fatigue threshold, as a percentage of the normal drain rate. 150% = 1.5× faster; 100% = no change."
		),
		["zh-cn"] = lines(
			"疲劳值高于高疲劳阈值时狂怒的时间衰减速度（相对于正常衰减速率的百分比）。150% = 衰减加快 1.5 倍；100% = 无变化。"
		),
	},
	fury_min_gain_mult = {
		en = "Min. Fury Gain at Max Fatigue",
		["zh-cn"] = "满疲劳时最小狂怒增益",
	},
	fury_min_gain_mult_description = {
		en = lines(
			"Fury gain multiplier when above the high-fatigue threshold. Below the threshold, fury gain is unaffected."
		),
		["zh-cn"] = lines("高于高疲劳阈值时的狂怒增益倍率。低于阈值时狂怒增益不受影响。"),
	},

	fine_tuning_grace = {
		en = "Grace",
		["zh-cn"] = "宽恕",
	},
	grace_duration = {
		en = "Grace Duration (base)",
		["zh-cn"] = "宽恕持续时间（基础）",
	},
	grace_duration_description = {
		en = lines(
			"Flat grace seconds on each qualifying hit/kill. Total grace = (this + damage × Grace Per Damage) × fatigue, capped by Grace Max. Set to 0 to disable the flat portion."
		),
		["zh-cn"] = lines(
			"每次有效命中/击杀获得的固定宽恕秒数。总宽恕 =（此值 + 伤害 × 每点伤害宽恕）× 疲劳值，上限为最大宽恕时间。设为 0 可禁用固定部分。"
		),
	},
	grace_max = {
		en = "Grace Max Duration",
		["zh-cn"] = "最大宽恕持续时间",
	},
	grace_max_description = {
		en = lines("Upper clamp on total grace from any single hit or kill."),
		["zh-cn"] = lines("单次命中或击杀所能获得的最高宽恕时间上限。"),
	},
	grace_min_duration_mult = {
		en = "Min. Grace Duration at Max Fatigue",
		["zh-cn"] = "满疲劳时最小宽恕倍率",
	},
	grace_min_duration_mult_description = {
		en = lines(
			"Grace duration multiplier at 100% fatigue. At 0% fatigue the multiplier is 1.0 (full grace)."
		),
		["zh-cn"] = lines("疲劳值为 100% 时的宽恕持续时间倍率。疲劳值为 0% 时倍率为 1.0（完整宽恕）。"),
	},
}
