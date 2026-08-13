---@type mod
local mod = get_mod("dopamine")

local lines = mod.dl.loc_helpers.lines
local important = mod.dl.loc_helpers.important

local loc = {
	tab_layout = {
		en = "Layout",
		["zh-cn"] = "布局",
	},
	heading_margin_editor = {
    en = "Margin Editor",
    ["zh-cn"] = "边距编辑器",
},
	heading_margin_editor_description = {
		en = "Click the button below to open the margin editor, which lets you position elements wherever you want on the screen.",
		["zh-cn"] = "点击下方按钮打开边距编辑器，你可以将元素放置到屏幕上任意位置。",
	},

	margin_editor_toggle_keybind = {
		en = "Open Margin Editor",
		["zh-cn"] = "切换边距编辑器",
	},

	slot_element_score = {
		en = "Style Meter",
		["zh-cn"] = "风格计量表",
	},
	slot_element_objective = {
		en = "Objectives",
		["zh-cn"] = "任务目标",
	},
	slot_element_fury = {
		en = "Fury Bar",
		["zh-cn"] = "狂怒条",
	},
	slot_element_stats = {
		en = "Stat Chart",
		["zh-cn"] = "统计图表",
	},

	heading_layout_left = {
		en = "Left Side",
		["zh-cn"] = "左侧",
	},

	chat_reposition = {
		en = important("Chat Repositioning"),
		["zh-cn"] = important("聊天框位置调整"),
	},
	chat_reposition_description = {
		en = lines(
			"When either HUD element sits on the Left, the chat needs to be moved down slightly.",
			"",
			"Recommended unless you are using CustomHUD."
		),
		["zh-cn"] = lines(
			"当左侧有HUD元素时，聊天框需要稍微向下移动。",
			"",
			"推荐开启，除非你在使用 CustomHUD。"
		),
	},

	killfeed_disable = {
		en = important("Killfeed Disabling"),
		["zh-cn"] = important("击杀信息禁用"),
	},
	killfeed_disable_description = {
		en = lines(
			"When either HUD element sits on the Left, the killfeed needs to be disabled.",
			"",
			"Recommended unless you are using CustomHUD."
		),
		["zh-cn"] = lines(
			"当左侧有HUD元素时，需要禁用原版击杀信息。",
			"",
			"推荐开启，除非你在使用 CustomHUD。"
		),
	},
	killfeed_disable_on = {
		en = "Disable my killfeed",
		["zh-cn"] = "禁用我的击杀信息",
	},
	killfeed_disable_off = {
		en = "Leave my killfeed alone!",
		["zh-cn"] = "不要禁用我的击杀信息！",
	},

	heading_layout_center = {
		en = "Center",
		["zh-cn"] = "中央",
	},
	slot_center = {
		en = "Center",
		["zh-cn"] = "中间",
	},

	heading_layout_right = {
		en = "Right Side",
		["zh-cn"] = "右侧",
	},

	mission_speaker_reposition = {
		en = important("Mission Speaker Repositioning"),
		["zh-cn"] = important("任务播报位置调整"),
	},
	mission_speaker_reposition_description = {
		en = lines(
			"When a HUD element sits on the Right, the mission speaker popup needs to be moved down slightly.",
			"",
			"Recommended unless you are using CustomHUD."
		),
		["zh-cn"] = lines(
			"当右侧有HUD元素时，任务播报弹窗需要稍微向下移动。",
			"",
			"推荐开启，除非你在使用 CustomHUD。"
		),
	},

	hud_reposition_on = {
    en = "Adjust my HUD for me",
    ["zh-cn"] = "帮我调整 HUD",
},
hud_reposition_off = {
    en = "Leave my HUD alone!",
    ["zh-cn"] = "别动我的 HUD！",
},

}

for n = 1, 4 do
	loc["slot_" .. n] = {
		en = "Slot " .. n,
		["zh-cn"] = "槽位 " .. n,
	}
end

return loc
