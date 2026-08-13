---@type mod
local mod = get_mod("dopamine")
local lines, important = mod.dl.loc_helpers.lines, mod.dl.loc_helpers.important

return {
	tab_difficulty = {
		en = "Difficulty",
	},
	fury_damage_penalty = {
		en = "Fury Hit Penalty",
		["zh-cn"] = "受击惩罚",
	},
	fury_damage_penalty_description = {
		en = lines(
			"How much Fury % you lose per Health+Toughness % lost",
			"",
			"30% health+toughness lost @ 0.5 = 15% Fury lost"
		),
		["zh-cn"] = lines(
			"每损失1%生命+韧性时损失多少狂怒百分比",
			"",
			"损失30%生命+韧性 @ 0.5 = 损失15%狂怒"
		),
	},
	fury_damage_reference = {
		en = "Fury Damage Reference",
		["zh-cn"] = "狂怒伤害参考",
	},
	fury_damage_reference_description = {
		en = lines(
			"Reference damage for scaling fury.",
			"",
			"Lower: easier to maintain fury",
			"Higher: harder to maintain fury"
		),
		["zh-cn"] = lines(
			"用于缩放狂怒的参考伤害值。",
			"",
			"数值越低：越容易维持狂怒",
			"数值越高：越难维持狂怒"
		),
	},
	global_sp_multiplier = {
		en = "Global Points Multiplier",
		["zh-cn"] = "全局点数倍率",
	},
	global_sp_multiplier_description = {
		en = lines("Increase/decrease the amount of points earned from every source"),
		["zh-cn"] = "增加/减少从所有来源获得的点数",
	},
	fury_damage_mult = { en = "Fury Damage Multiplier", ["zh-cn"] = "狂怒伤害倍率", },
	fury_damage_mult_description = {
		en = lines("Multiplier on the base 1% fury added per qualifying damage hit."),
		["zh-cn"] = lines("每次有效伤害命中的基础 1% 狂怒的倍率。"),
	},
}
