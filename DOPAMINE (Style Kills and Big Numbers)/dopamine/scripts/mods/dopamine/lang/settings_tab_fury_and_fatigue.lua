---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines

return {
	tab_fury_and_fatigue = {
		en = "Fury & Fatigue",
		["zh-cn"] = "狂怒 & 疲劳",
	},

	fatigue_tuning = {
		en = "Fatigue",
		["zh-cn"] = "疲劳",
	},
	fatigue_kill_mult = {
		en = "Fatigue on Kill",
		["zh-cn"] = "击杀疲劳倍率",
	},
	fatigue_kill_mult_description = {
		en = lines("Multiplier on the base 1% fatigue added per kill."),
		["zh-cn"] = lines("每击杀一次的基础 1% 疲劳的倍率。"),
	},
	fatigue_damage_mult = {
		en = "Fatigue on Damage",
		["zh-cn"] = "伤害疲劳倍率",
	},
	fatigue_damage_mult_description = {
		en = lines("Multiplier on the base 1% fatigue added per qualifying damage hit."),
		["zh-cn"] = lines("每次有效伤害命中的基础 1% 疲劳的倍率。"),
	},
	fatigue_milestone_interval = {
		en = "Every __ kills...",
		["zh-cn"] = "每 __ 次击杀...",
	},
	fatigue_milestone_interval_description = {
		en = lines("Every how many kills will you lose the below-specified amount of fatigue %"),
		["zh-cn"] = lines("每多少次击杀会减少下方指定的疲劳百分比"),
	},
	fatigue_milestone_reduction = {
		en = "...lose __%% fatigue",
		["zh-cn"] = "...减少 __%% 疲劳",
	},
	fatigue_milestone_reduction_description = {
		en = lines("Fatigue % removed every N chain kills (see above)"),
		["zh-cn"] = lines("每 N 次连击击杀减少的疲劳百分比（见上方）"),
	},
	breed_relief_elite_fatigue = {
		en = "Lose __%% Fatigue on Elite Kill",
		["zh-cn"] = "精英击杀减少 __%% 疲劳",
	},
	breed_relief_elite_fatigue_description = {
		en = lines("Fatigue % removed when killing an elite-class enemy."),
		["zh-cn"] = lines("击杀精英级敌人时减少的疲劳百分比。"),
	},
	breed_relief_special_fatigue = {
		en = "Lose __%% Fatigue on Special Kill",
		["zh-cn"] = "特殊敌人击杀减少 __%% 疲劳",
	},
	breed_relief_special_fatigue_description = {
		en = lines("Fatigue % removed when killing a special"),
		["zh-cn"] = lines("击杀特殊敌人时减少的疲劳百分比。"),
	},

	fatigue_timer = {
		en = "Fatigue Timer",
		["zh-cn"] = "疲劳计时器",
	},
	fatigue_passive_ramp_seconds = {
		en = "Max-Fatigue Timer",
		["zh-cn"] = "积累计时器",
	},
	fatigue_passive_ramp_seconds_description = {
		en = lines(
			"Each combo chain has a hidden timer.",
			"The amount of fatigue %/second added increases linearly from 0-100% as this timer progresses"
		),
		["zh-cn"] = lines(
			"每个连击链都有一个隐藏计时器。",
			"随着计时器推进，每秒增加的疲劳百分比从 0% 线性增长到 100%。"
		),
	},
	fatigue_passive_per_second = {
		en = "Max-Fatigue Fury Drain",
		["zh-cn"] = "最大疲劳",
	},
	fatigue_passive_per_second_description = {
		en = lines("Fatigue % per second at max combo timer"),
		["zh-cn"] = lines("在最大连击计时器时每秒增加的疲劳百分比。"),
	},

	grace_tuning = {
		en = "Grace",
		["zh-cn"] = "宽恕",
	},
	grace_per_damage = {
		en = "Grace per Damage",
		["zh-cn"] = "每点伤害宽恕",
	},
	grace_per_damage_description = {
		en = lines("Extra grace seconds per point of damage on hit/kill."),
		["zh-cn"] = lines("每次命中/击杀时每点伤害额外获得的宽恕秒数。"),
	},
	grace_drain_percent = {
		en = "Grace Drain",
		["zh-cn"] = "宽恕期衰减",
	},
	grace_drain_percent_description = {
		en = lines(
			"How much fury still drains during grace, as a % of the current drain rate.",
			"0% = frozen;",
			"100% = no slowdown."
		),
		["zh-cn"] = lines(
			"宽恕期内狂怒仍会以当前衰减速率的百分之多少继续流失。",
			"0% = 完全冻结；",
			"100% = 无减速。"
		),
	},
}
