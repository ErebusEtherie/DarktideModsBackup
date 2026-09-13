local mod = get_mod("HavocConditionManager")
local localization = {
	mod_name = {
		en = "Havoc Condition Manager",
		["zh-cn"] = "浩劫状况管理器",
		["zh-tw"] = "浩劫條件管理器",
	},
	mod_description = {
		en = "Adds duplicate-free Havoc selection, shared enemy effects, spawn-capacity modes, and per-category enemy multipliers to Solo Play.",
		["zh-cn"] = "为原版 Solo Play 添加不重复的多浩劫状况、同一敌人的共享效果、生成容量模式及分敌种生成倍率。",
		["zh-tw"] = "為原版 Solo Play 新增不重複的多浩劫條件、同一敵人的共享效果、生成容量模式及依敵種分類的生成倍率。",
	},
	open_condition_manager = {
		en = "Expanded local game interface",
		["zh-cn"] = "扩展本地游戏界面",
		["zh-tw"] = "擴充本機遊戲介面",
	},
	open = {
		en = "Open",
		["zh-cn"] = "打开",
		["zh-tw"] = "開啟",
	},
	spawn_generation_mode = {
		en = "Enemy generation mode",
		["zh-cn"] = "敌人生成模式",
		["zh-tw"] = "敵人生成模式",
	},
	spawn_generation_mode_description = {
		en = "Native keeps Darktide's shared limits. Additive preserves every condition's native schedule and adds their generation capacities.",
		["zh-cn"] = "原生模式保留 Darktide 的共享限制；容量相加模式保留各词条的原生生成计划，并叠加它们的生成容量。",
		["zh-tw"] = "原生模式保留 Darktide 的共享限制；容量相加模式保留各條件的原生生成計畫，並疊加它們的生成容量。",
	},
	spawn_generation_mode_native = {
		en = "Native logic and capacity",
		["zh-cn"] = "游戏原生刷怪逻辑和容量",
		["zh-tw"] = "遊戲原生生成邏輯和容量",
	},
	spawn_generation_mode_additive = {
		en = "Additive multi-condition logic and capacity",
		["zh-cn"] = "多词条拼接刷怪逻辑和容量",
		["zh-tw"] = "多條件拼接生成邏輯和容量",
	},
	spawn_multiplier_title = {
		en = "Enemy amount multipliers (1x = native)",
		["zh-cn"] = "敌人生成倍率（1倍 = 原生）",
		["zh-tw"] = "敵人生成倍率（1倍 = 原生）",
	},
	spawn_multiplier_common = {
		en = "Hordes / common",
		["zh-cn"] = "尸潮/普通敌人",
		["zh-tw"] = "屍潮/普通敵人",
	},
	spawn_multiplier_elite = {
		en = "Elites",
		["zh-cn"] = "精英敌人",
		["zh-tw"] = "精英敵人",
	},
	spawn_multiplier_special = {
		en = "Specialists",
		["zh-cn"] = "专家敌人",
		["zh-tw"] = "專家敵人",
	},
	spawn_multiplier_boss = {
		en = "Boss encounters",
		["zh-cn"] = "BOSS 遭遇",
		["zh-tw"] = "BOSS 遭遇",
	},
	default_text_select_to_add = {
		en = "Select a condition to add",
		["zh-cn"] = "选择要添加的状况",
		["zh-tw"] = "選擇要新增的條件",
	},
	default_text_select_to_remove = {
		en = "Select a condition to remove",
		["zh-cn"] = "选择要删除的状况",
		["zh-tw"] = "選擇要移除的條件",
	},
	label_add_havoc_circumstance = {
		en = "Add Havoc condition",
		["zh-cn"] = "添加浩劫状况",
		["zh-tw"] = "新增浩劫條件",
	},
	label_remove_havoc_circumstance = {
		en = "Remove Havoc condition",
		["zh-cn"] = "删除浩劫状况",
		["zh-tw"] = "移除浩劫條件",
	},
	label_selected_havoc_conditions = {
		en = "Selected Havoc conditions: %d / %d",
		["zh-cn"] = "已选择浩劫状况：%d / %d",
		["zh-tw"] = "已選擇浩劫條件：%d / %d",
	},
	message_havoc_condition_added = {
		en = "Added Havoc condition: %s",
		["zh-cn"] = "已添加浩劫状况：%s",
		["zh-tw"] = "已新增浩劫條件：%s",
	},
	message_havoc_condition_removed = {
		en = "Removed Havoc condition: %s",
		["zh-cn"] = "已删除浩劫状况：%s",
		["zh-tw"] = "已移除浩劫條件：%s",
	},
	message_havoc_condition_duplicate = {
		en = "That Havoc condition is already selected.",
		["zh-cn"] = "该浩劫状况已经添加。",
		["zh-tw"] = "該浩劫條件已經新增。",
	},
	message_havoc_condition_limit = {
		en = "A maximum of %d primary Havoc conditions is supported.",
		["zh-cn"] = "最多支持 %d 个主要浩劫状况。",
		["zh-tw"] = "最多支援 %d 個主要浩劫條件。",
	},
	message_havoc_condition_minimum = {
		en = "Keep at least one primary Havoc condition.",
		["zh-cn"] = "至少需要保留一个主要浩劫状况。",
		["zh-tw"] = "至少需要保留一個主要浩劫條件。",
	},
}

local reference = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/reference_localization")
for key,value in pairs(reference) do
	if key ~= "mod_name" and key ~= "mod_description" then localization[key] = value end
end
localization.mod_name = { en = "Havoc Condition Manager", ["zh-cn"] = "浩劫词条管理器", ["zh-tw"]="浩劫詞條管理器" }
localization.mod_description = { en = "Havoc conditions and spawn multipliers. Framework toggles apply immediately in the hub, or next mission during a run.", ["zh-cn"] = "浩劫词条与刷怪倍率。框架开关在大厅立即生效，任务中切换则在下一局生效。", ["zh-tw"]="浩劫詞條與刷怪倍率。框架開關在大廳立即生效，任務中切換則在下一局生效。" }
localization.toggle_next_mission = { en = "Switch saved. The current mission keeps its configuration; the new state applies next mission.", ["zh-cn"] = "开关已保存；当前任务保持原配置，下一局应用新的开关状态。", ["zh-tw"]="開關已儲存；目前任務保持原配置，下一局套用新的開關狀態。" }
localization.page_home = { en = "Mission setup", ["zh-cn"] = "任务设置", ["zh-tw"]="任務設定" }
localization.page_conditions = { en = "Havoc conditions", ["zh-cn"] = "浩劫词条", ["zh-tw"]="浩劫詞條" }
localization.page_spawn = { en = "Enemy multipliers", ["zh-cn"] = "敌人生成倍率", ["zh-tw"]="敵人生成倍率" }
localization.select_all = { en = "Select all", ["zh-cn"] = "添加全部", ["zh-tw"]="新增全部" }
localization.clear_all = { en = "Clear selection", ["zh-cn"] = "清空所选词条", ["zh-tw"]="清空所選詞條" }
localization.selected_count = { en = "Selected", ["zh-cn"] = "已选", ["zh-tw"]="已選" }
localization.mode_label = { en = "Adjustment mode (click to switch)", ["zh-cn"] = "调整方式（点击切换）", ["zh-tw"]="調整方式（點選切換）" }
localization.mode_quantity = { en = "Quantity only", ["zh-cn"] = "只调整数量", ["zh-tw"]="只調整數量" }
localization.mode_speed = { en = "Speed only", ["zh-cn"] = "只调整速度", ["zh-tw"]="只調整速度" }
localization.mode_mixed = { en = "Mixed", ["zh-cn"] = "混合调整", ["zh-tw"]="混合調整" }
localization.conditions_note = { en = "Click a condition to add or remove it. No slot limit. Native replacement and shared-effect rules still apply.", ["zh-cn"] = "点击词条添加或删除，翻页查看全部。保留原版同源效果的覆盖规则；环境与难度仍在任务页设置。", ["zh-tw"]="點選詞條新增或刪除，翻頁檢視全部。保留原版同源效果的覆蓋規則；環境與難度仍在任務頁設定。" }
localization.spawn_note = { en = "1x uses the original path. Native capacity and spawn gates still apply. Shared waves share a timer; static map enemies have no respawn timer. Mixed splits the factor between speed and count. Changes apply to the next mission.", ["zh-cn"] = "1 倍使用原版流程，原版容量和暂停条件继续生效。混合波次共用计时器，地图驻守敌人没有重生计时器。混合调整将倍率分配给速度和数量；下局生效。", ["zh-tw"]="1 倍使用原版流程，原版容量和暫停條件繼續生效。混合波次共用計時器，地圖駐守敵人沒有重生計時器。混合調整將倍率分配給速度和數量；下局生效。" }
localization.option_faction_switch = { en = "Switching factions", ["zh-cn"] = "阵营交替", ["zh-tw"]="陣營交替" }
localization.option_faction_combined = { en = "Combined factions", ["zh-cn"] = "阵营合流", ["zh-tw"]="陣營合流" }
for key,value in pairs(mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/ui_localization")) do localization[key]=value end
return localization
