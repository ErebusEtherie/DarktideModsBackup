---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines

return {
	tab_debug = {
		en = "Debug",
		["zh-cn"] = "调试",
	},

	heading_debug_events = {
		en = "Events",
		["zh-cn"] = "事件",
	},
	debug_enable_permanent_events = {
		en = "Debug: Permanent Events",
		["zh-cn"] = "调试：永久事件",
	},

	heading_debug_fury = {
		en = "Fury / Fatigue",
		["zh-cn"] = "狂怒 / 疲劳",
	},
	debug_lock_fury_toggle = {
		en = "Debug: Toggle Fury Lock",
		["zh-cn"] = "调试：切换狂怒锁定",
	},
	debug_add_10_fury = {
		en = "Debug: Add 10% Fury",
		["zh-cn"] = "调试：增加 10% 狂怒",
	},
	debug_take_10_fury = {
		en = "Debug: Remove 10% Fury",
		["zh-cn"] = "调试：减少 10% 狂怒",
	},
	debug_log_fury_fatigue_gain = {
		en = "Debug: Log Fury & Fatigue Gain",
		["zh-cn"] = "调试：记录狂怒与疲劳增益",
	},
	debug_lock_fury_fatigue = {
		en = "Debug: Lock Fury & Fatigue",
		["zh-cn"] = "调试：锁定狂怒 & 疲劳",
	},
	debug_lock_fury_fatigue_description = {
		en = lines(
			"While in a mission, pin fury and fatigue to the debug % values below and keep the combo active. Set fury to 101% to preview max-fury effects."
		),
		["zh-cn"] = lines(
			"在任务中时，将狂怒和疲劳值锁定为下方调试百分比，并保持连击状态。将狂怒设置为 101% 可预览满狂怒效果。"
		),
	},
	debug_fury_pct = {
		en = "Debug Fury %%",
		["zh-cn"] = "调试狂怒 %%",
	},
	debug_fatigue_pct = {
		en = "Debug Fatigue %%",
		["zh-cn"] = "调试疲劳 %%",
	},
	debug_show_test_callout = {
		en = "Debug: Show Test Callout",
		["zh-cn"] = "调试：显示测试提示",
	},
	debug_show_test_callout_description = {
		en = lines(
			"Always show a test fury rank callout above the bar (use with debug lock to preview callouts)."
		),
		["zh-cn"] = lines("始终在狂怒条上方显示测试等级提示（配合调试锁定功能可预览提示效果）。"),
	},

	debug_tasks = {
		en = "Tasks",
		["zh-cn"] = "任务",
	},
	debug_trigger_tasks_manually = {
		en = "Debug: Trigger Tasks Manually",
		["zh-cn"] = "调试：手动触发任务",
	},
	debug_cycle_objective_keybind = {
		en = "Debug: Cycle Tasks",
		["zh-cn"] = "调试：循环任务",
	},
	debug_trigger_objective_keybind = {
		en = "Debug: Trigger Task",
		["zh-cn"] = "调试：触发任务",
	},

	debug_layout = {
		en = "Layout",
		["zh-cn"] = "布局",
	},
	debug_layout_boxes = {
		en = "Debug: Show Layout Boxes",
		["zh-cn"] = "调试：显示布局框",
	},
	debug_layout_boxes_description = {
		en = lines(
			"Draw a 1px outline around each HUD cluster's computed bounding box (fury, style, task track) so you can see exactly where the layout places them."
		),
		["zh-cn"] = lines(
			"在每个 HUD 组件（狂怒、风格、任务追踪）的计算边界框周围绘制 1 像素轮廓，以便你能精确看到布局放置的位置。"
		),
	},
	debug_toggle_mission_speaker_speaker = {
		en = "Debug: Toggle Mission Speaker",
		["zh-cn"] = "调试：切换任务播报员",
	},

	debug_mission_summary = {
		en = "Mission Summary",
		["zh-cn"] = "任务总结",
	},
	debug_simulate_end_mission = {
		en = "Debug: Simulate End Of Mission",
		["zh-cn"] = "调试：模拟任务结束",
	},
	debug_create_dummy_entry = {
		en = "Debug: Create Dummy High Score",
		["zh-cn"] = "调试：创建虚拟高分",
	},

	debug_callout_text = {
		en = mod.dl.str.rich_text("D", { color = mod.dl.colors.reg.gw.blue_horror }) .. "EBUG CALLOUT",
		["zh-cn"] = mod.dl.str.rich_text("D", { color = mod.dl.colors.reg.gw.blue_horror }) .. "调试提示",
	},
}
