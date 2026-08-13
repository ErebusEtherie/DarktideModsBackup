---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines

return {
	heading_statline_performance = { en = "Statline", ["zh-cn"] = "统计栏" },
	heading_markers_performance = { en = "Pop-ups", ["zh-cn"] = "弹出提示" },
	tab_performance = {
		en = "Performance",
		["zh-cn"] = "性能",
	},
	tab_performance_description = {
		en = "If you are experiencing stuttering or hitches, changing these settings might help.",
		["zh-cn"] = "如果你遇到卡顿或掉帧，调整这些设置可能会有帮助。",
	},
	max_active_markers = {
		en = "Max Popups",
		["zh-cn"] = "最大同时弹出数量",
	},
	max_active_markers_description = {
		en = lines("Max simultaneous popups (protects performance in hordes)."),
		["zh-cn"] = lines("同时显示的最大弹出提示数量（防止大规模刷怪时性能下降）。"),
	},
	statline_dps_update_hz = {
		en = "DPS Update Rate",
		["zh-cn"] = "DPS 更新频率",
	},
	statline_dps_update_hz_description = {
		en = lines(
			"How many times per second the DPS average is recalculated.",
			"The on-screen number still animates every frame; lower values reduce CPU use."
		),
		["zh-cn"] = lines(
			"每秒重新计算 DPS 平均值的次数。",
			"屏幕上的数字仍会每帧动画；降低此值可减少 CPU 占用。"
		),
	},
}
