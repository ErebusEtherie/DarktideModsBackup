local MissionBuffsAllowedBuffs = require("scripts/managers/mission_buffs/mission_buffs_allowed_buffs")

local HordesBuffsData = require("scripts/settings/buff/hordes_buffs/hordes_buffs_data")

local mod = get_mod("MortisBuffManager")

local Catalog = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_catalog")



local localization = {
	mortis_settings_group = {
		["en"] = "Mortis Buff settings",
		["zh-cn"] = "死灵 Buff 设置", ["zh-tw"]="死靈 Buff 設定",
	},
	enable_custom_mortis_buffs = {
		["en"] = "Enable custom Mortis Buffs",
		["zh-cn"] = "启用自定义死灵 Buff", ["zh-tw"]="啟用自訂死靈 Buff",
	},
	enable_custom_mortis_buffs_desc = {
		["en"] = "The host selects a global mode: preselection, mission-progress draft or personal kill competition. Native Mortis reward selection is replaced while this feature is active.",
		["zh-cn"] = "房主设置全局玩法：开局预选、地图进度抽选或个人击杀竞争。功能生效时接管原版死灵奖励选择。", ["zh-tw"]="房主設定全域玩法：開局預選、地圖進度抽選或個人擊殺競爭。功能生效時接管原版死靈獎勵選擇。",
	},
	enable_local_mortis_buffs = {
		["en"] = "Apply selected Buffs to me",
		["zh-cn"] = "对自己应用所选 Buff", ["zh-tw"]="對自己應用所選 Buff",
	},
	enable_local_mortis_buffs_desc = {
		["en"] = "Applies the current character's saved selection to the host/solo player.",
		["zh-cn"] = "把当前角色保存的选择应用给房主/单人玩家。", ["zh-tw"]="把當前角色儲存的選擇應用給房主/單人玩家。",
	},
	enable_realms_mortis_buffs = {
		["en"] = "Allow Realms guests to select Buffs",
		["zh-cn"] = "允许 Realms 客机自选 Buff", ["zh-tw"]="允許 Realms 客機自選 Buff",
	},
	enable_realms_mortis_buffs_desc = {
		["en"] = "Guests submit only their own selection. The host revalidates it against their actual character and abilities.",
		["zh-cn"] = "客机只能提交自己的选择；房主会根据其实际角色与已装备技能再次验证。", ["zh-tw"]="客機只能提交自己的選擇；房主會根據其實際角色與已裝備技能再次驗證。",
	},
	mortis_buff_limit = {
		["en"] = "Maximum selected Buffs per player",
		["zh-cn"] = "每名玩家最多自选 Buff 数", ["zh-tw"]="每名玩家最多自選 Buff 數",
	},
	mortis_buff_limit_desc = {
		["en"] = "The host's limit is authoritative for Realms guests. Maximum 99. Buffs are checked in the talent-tree UI.",
		["zh-cn"] = "Realms 联机时以房主的上限为准，最高 99 个；Buff 请使用 /mortisbuffs 打开死灵页后勾选。", ["zh-tw"]="Realms 聯機時以房主的上限為準，最高 99 個；Buff 請使用 /mortisbuffs 開啟死靈頁後勾選。",
	},
	mortis_talent_ui_open = {
		["en"] = "Mortis Trials Buffs",
		["zh-cn"] = "死灵试炼 Buff", ["zh-tw"]="死靈試煉 Buff",
	},
	mortis_talent_ui_open_count = {
		["en"] = "Mortis Trials Buffs %d/%d",
		["zh-cn"] = "死灵试炼 Buff %d/%d", ["zh-tw"]="死靈試煉 Buff %d/%d",
	},
	mortis_talent_ui_title = {
		["en"] = "MORTIS TRIALS BUFFS",
		["zh-cn"] = "死灵试炼 BUFF 自选", ["zh-tw"]="死靈試煉 BUFF 自選",
	},
	mortis_talent_ui_direct_apply = {
		["en"] = "Selected %d/%d. The local host applies these at mission start; native drafts are disabled in Mortis Trials.",
		["zh-cn"] = "已选择 %d/%d；本地房主会在任务开局应用，死灵试炼中的原生抽选同时关闭。", ["zh-tw"]="已選擇 %d/%d；本地房主會在任務開局應用，死靈試煉中的原生抽選同時關閉。",
	},
	mortis_talent_ui_waiting_host = {
		["en"] = "Selected %d/%d. Waiting for the Realms host's rules.",
		["zh-cn"] = "已选择 %d/%d；正在等待 Realms 房主规则。", ["zh-tw"]="已選擇 %d/%d；正在等待 Realms 房主規則。",
	},
	mortis_talent_ui_host_disabled = {
		["en"] = "Selected %d/%d. This Realms host has disabled guest Buff selection.",
		["zh-cn"] = "已选择 %d/%d；当前 Realms 房主未允许客机自选 Buff。", ["zh-tw"]="已選擇 %d/%d；當前 Realms 房主未允許客機自選 Buff。",
	},
	mortis_talent_ui_apply_disabled = {
		["en"] = "Selected %d/%d. Enable 'Apply selected Buffs to me' before entering.",
		["zh-cn"] = "已选择 %d/%d；进服前请开启“对自己应用所选 Buff”。", ["zh-tw"]="已選擇 %d/%d；進服前請開啟“對自己應用所選 Buff”。",
	},
	mortis_talent_ui_abilities_waiting = {
		["en"] = "Selected %d/%d. Character abilities are still initializing; reopen the tree shortly.",
		["zh-cn"] = "已选择 %d/%d；角色技能尚未初始化，请稍后使用 /mortisbuffs 重新打开死灵页。", ["zh-tw"]="已選擇 %d/%d；角色技能尚未初始化，請稍後使用 /mortisbuffs 重新開啟死靈頁。",
	},
	mortis_talent_ui_assets_loading = {
		["en"] = "Selected %d/%d. Loading the native Mortis mission icons...",
		["zh-cn"] = "已选择 %d/%d；正在载入原生死灵试炼图标资源……", ["zh-tw"]="已選擇 %d/%d；正在載入原生死靈試煉圖示資源……",
	},
	mortis_talent_ui_assets_failed = {
		["en"] = "Selected %d/%d. The native Mortis mission icon package could not be loaded; see the log.",
		["zh-cn"] = "已选择 %d/%d；原生死灵试炼图标资源包加载失败，请查看日志。", ["zh-tw"]="已選擇 %d/%d；原生死靈試煉圖示資源包載入失敗，請檢視日誌。",
	},
	mortis_talent_ui_page = {
		["en"] = "%d / %d",
		["zh-cn"] = "%d / %d", ["zh-tw"]="%d / %d",
	},
	mortis_talent_ui_previous = {
		["en"] = "Previous",
		["zh-cn"] = "上一页", ["zh-tw"]="上一頁",
	},
	mortis_talent_ui_next = {
		["en"] = "Next",
		["zh-cn"] = "下一页", ["zh-tw"]="下一頁",
	},
	mortis_talent_ui_scroll_position = {
		["en"] = "%d-%d / %d  ·  Scroll or drag the bar",
		["zh-cn"] = "%d–%d / %d  ·  滚轮滚动或拖动右侧滚动条", ["zh-tw"]="%d–%d / %d  ·  滾輪滾動或拖動右側捲軸",
	},
	mortis_talent_ui_no_compatible_buffs = {
		["en"] = "No Buffs match the current character setup",
		["zh-cn"] = "当前角色构筑没有可用 Buff", ["zh-tw"]="當前角色構築沒有可用 Buff",
	},
	mortis_talent_ui_source_class_class = {
		["en"] = "Current class only",
		["zh-cn"] = "仅当前职业", ["zh-tw"]="僅當前職業",
	},
	mortis_talent_ui_source_class_grenade = {
		["en"] = "Current class · equipped Blitz",
		["zh-cn"] = "当前职业·已装备闪击", ["zh-tw"]="當前職業·已裝備閃擊",
	},
	mortis_talent_ui_source_class_combat = {
		["en"] = "Current class · equipped ability",
		["zh-cn"] = "当前职业·已装备战斗技能", ["zh-tw"]="當前職業·已裝備戰鬥技能",
	},
	mortis_talent_ui_source_class_talent = {
		["en"] = "Current class · selected talent",
		["zh-cn"] = "当前职业·已选天赋", ["zh-tw"]="當前職業·已選天賦",
	},
	mortis_talent_ui_source_generic = {
		["en"] = "Native shared legendary",
		["zh-cn"] = "原生公共传奇", ["zh-tw"]="原生公共傳奇",
	},
	mortis_talent_ui_source_family = {
		["en"] = "Shared route Buff · %s",
		["zh-cn"] = "路线公共 Buff·%s", ["zh-tw"]="路線公共 Buff·%s",
	},
	mortis_talent_ui_source_stale = {
		["en"] = "Incompatible saved choice",
		["zh-cn"] = "旧构筑残留", ["zh-tw"]="舊構築殘留",
	},
	mortis_talent_ui_family_fire = {
		["en"] = "Fire",
		["zh-cn"] = "烈火", ["zh-tw"]="烈火",
	},
	mortis_talent_ui_family_unkillable = {
		["en"] = "Unkillable",
		["zh-cn"] = "不屈", ["zh-tw"]="不屈",
	},
	mortis_talent_ui_family_cowboy = {
		["en"] = "Gunslinger",
		["zh-cn"] = "枪手", ["zh-tw"]="槍手",
	},
	mortis_talent_ui_family_electric = {
		["en"] = "Electric",
		["zh-cn"] = "电击", ["zh-tw"]="電擊",
	},
	mortis_talent_ui_family_elementalist = {
		["en"] = "Elementalist",
		["zh-cn"] = "元素", ["zh-tw"]="元素",
	},
	mortis_talent_ui_family_critical = {
		["en"] = "Critical",
		["zh-cn"] = "暴击", ["zh-tw"]="暴擊",
	},
	mortis_talent_ui_family_unstoppable = {
		["en"] = "Unstoppable",
		["zh-cn"] = "势不可挡", ["zh-tw"]="勢不可擋",
	},
	mortis_talent_ui_family_label = {
		["en"] = "Native route",
		["zh-cn"] = "原生路线", ["zh-tw"]="原生路線",
	},
	mortis_talent_ui_context = {
		["en"] = "Current class: %s · Routes above are shared themes, not classes; exclusive rewards are filtered to this class and equipped abilities.",
		["zh-cn"] = "当前职业：%s · 上方是通用强化路线，并非职业；专属奖励只显示当前职业及已装备技能可用项。", ["zh-tw"]="當前職業：%s · 上方是通用強化路線，並非職業；專屬獎勵只顯示當前職業及已裝備技能可用項。",
	},
	mortis_talent_ui_unknown_archetype = {
		["en"] = "initializing",
		["zh-cn"] = "初始化中", ["zh-tw"]="初始化中",
	},
	mortis_talent_ui_family_selected = {
		["en"] = "%s",
		["zh-cn"] = "%s", ["zh-tw"]="%s",
	},
	mortis_talent_ui_family_pruned = {
		["en"] = "Changing the Mortis family removed %d Buff(s) that are not in the new native pool.",
		["zh-cn"] = "切换流派后，已移除 %d 个不属于新原生池的 Buff。", ["zh-tw"]="切換流派後，已移除 %d 個不屬於新原生池的 Buff。",
	},
	mortis_talent_ui_clear = {
		["en"] = "Clear all",
		["zh-cn"] = "全部清空", ["zh-tw"]="全部清空",
	},
	mortis_talent_ui_close = {
		["en"] = "Close",
		["zh-cn"] = "关闭", ["zh-tw"]="關閉",
	},
	mortis_talent_ui_incompatible_suffix = {
		["en"] = "  [incompatible with current build]",
		["zh-cn"] = "  [与当前构筑不兼容]", ["zh-tw"]="  [與當前構築不相容]",
	},
	mortis_talent_ui_detail_hint = {
		["en"] = "Hover over a Buff to view its details",
		["zh-cn"] = "将光标移到 Buff 上以查看详情", ["zh-tw"]="將游標移到 Buff 上以檢視詳情",
	},
	mortis_talent_ui_detail_selected = {
		["en"] = "SELECTED — click to remove",
		["zh-cn"] = "已选择——点击取消", ["zh-tw"]="已選擇——點選取消",
	},
	mortis_talent_ui_detail_not_selected = {
		["en"] = "Not selected — click to add",
		["zh-cn"] = "未选择——点击添加", ["zh-tw"]="未選擇——點選新增",
	},
	mortis_talent_ui_detail_incompatible = {
		["en"] = "Incompatible with the current build",
		["zh-cn"] = "与当前构筑不兼容", ["zh-tw"]="與當前構築不相容",
	},
	mortis_talent_ui_no_description = {
		["en"] = "No localized description is available for this Buff.",
		["zh-cn"] = "该 Buff 暂无可用的本地化说明。", ["zh-tw"]="該 Buff 暫無可用的本地化說明。",
	},
	mortis_buff_to_add = {
		["en"] = "Buff to add",
		["zh-cn"] = "要添加的 Buff", ["zh-tw"]="要新增的 Buff",
	},
	mortis_buff_to_add_desc = {
		["en"] = "Choose a Buff, then press Add. Incompatible class/ability Buffs are rejected.",
		["zh-cn"] = "选择 Buff 后点击添加；与当前职业或技能不兼容的 Buff 会被拒绝。", ["zh-tw"]="選擇 Buff 後點選新增；與當前職業或技能不相容的 Buff 會被拒絕。",
	},
	mortis_buff_to_remove = {
		["en"] = "Buff to remove",
		["zh-cn"] = "要删除的 Buff", ["zh-tw"]="要刪除的 Buff",
	},
	mortis_buff_to_remove_desc = {
		["en"] = "Choose a Buff, then press Remove. Selecting a Buff that is not saved changes nothing.",
		["zh-cn"] = "选择 Buff 后点击删除；若该 Buff 未保存，则不会改变选择。", ["zh-tw"]="選擇 Buff 後點選刪除；若該 Buff 未儲存，則不會改變選擇。",
	},
	mortis_option_none = {
		["en"] = "Select a Buff...",
		["zh-cn"] = "请选择 Buff……", ["zh-tw"]="請選擇 Buff……",
	},
	mortis_add_button = {
		["en"] = "Add selected Buff",
		["zh-cn"] = "添加所选 Buff", ["zh-tw"]="新增所選 Buff",
	},
	mortis_add_button_button = {
		["en"] = "Add",
		["zh-cn"] = "添加", ["zh-tw"]="新增",
	},
	mortis_remove_button = {
		["en"] = "Remove selected Buff",
		["zh-cn"] = "删除所选 Buff", ["zh-tw"]="刪除所選 Buff",
	},
	mortis_remove_button_button = {
		["en"] = "Remove",
		["zh-cn"] = "删除", ["zh-tw"]="刪除",
	},
	mortis_show_button = {
		["en"] = "Show current selection",
		["zh-cn"] = "查看当前选择", ["zh-tw"]="檢視當前選擇",
	},
	mortis_show_button_button = {
		["en"] = "Show",
		["zh-cn"] = "查看", ["zh-tw"]="檢視",
	},
	mortis_clear_button = {
		["en"] = "Clear current selection",
		["zh-cn"] = "清空当前选择", ["zh-tw"]="清空當前選擇",
	},
	mortis_clear_button_button = {
		["en"] = "Clear all",
		["zh-cn"] = "全部清空", ["zh-tw"]="全部清空",
	},
	mortis_character_unavailable = {
		["en"] = "The current character is not available. Open this setting after entering the Mourningstar.",
		["zh-cn"] = "当前角色尚不可用，请进入哀星号后再操作此设置。", ["zh-tw"]="當前角色尚不可用，請進入哀星號後再操作此設定。",
	},
	mortis_selection_added = {
		["en"] = "Added: %s",
		["zh-cn"] = "已添加：%s", ["zh-tw"]="已新增：%s",
	},
	mortis_selection_removed = {
		["en"] = "Removed: %s",
		["zh-cn"] = "已删除：%s", ["zh-tw"]="已刪除：%s",
	},
	mortis_selection_duplicate = {
		["en"] = "Already selected: %s",
		["zh-cn"] = "已在选择中：%s", ["zh-tw"]="已在選擇中：%s",
	},
	mortis_selection_missing = {
		["en"] = "Not currently selected: %s",
		["zh-cn"] = "当前未选择：%s", ["zh-tw"]="當前未選擇：%s",
	},
	mortis_selection_incompatible = {
		["en"] = "Incompatible with the current character or equipped abilities: %s",
		["zh-cn"] = "与当前角色或已装备技能不兼容：%s", ["zh-tw"]="與當前角色或已裝備技能不相容：%s",
	},
	mortis_selection_full = {
		["en"] = "The current selection has reached the %d-Buff limit.",
		["zh-cn"] = "当前选择已达到 %d 个 Buff 的上限。", ["zh-tw"]="當前選擇已達到 %d 個 Buff 的上限。",
	},
	mortis_selection_unknown = {
		["en"] = "Select a valid Buff first.",
		["zh-cn"] = "请先选择一个有效 Buff。", ["zh-tw"]="請先選擇一個有效 Buff。",
	},
	mortis_selection_storage_error = {
		["en"] = "The Buff choice could not be saved for the current character.",
		["zh-cn"] = "无法为当前角色保存该 Buff 选择。", ["zh-tw"]="無法為當前角色儲存該 Buff 選擇。",
	},
	mortis_selection_cleared = {
		["en"] = "The current character's Mortis Buff selection was cleared.",
		["zh-cn"] = "已清空当前角色的死灵试炼 Buff 选择。", ["zh-tw"]="已清空當前角色的死靈試煉 Buff 選擇。",
	},
	mortis_selection_empty = {
		["en"] = "The current character has no selected Mortis Buffs.",
		["zh-cn"] = "当前角色没有已选择的死灵试炼 Buff。", ["zh-tw"]="當前角色沒有已選擇的死靈試煉 Buff。",
	},
	mortis_selection_summary = {
		["en"] = "Selected Mortis Buffs (%d): %s",
		["zh-cn"] = "已选择的死灵试炼 Buff（%d）：%s", ["zh-tw"]="已選擇的死靈試煉 Buff（%d）：%s",
	},
	mortis_selection_rejected = {
		["en"] = "The host rejected the Mortis Buff selection: %s",
		["zh-cn"] = "房主拒绝了死灵试炼 Buff 选择：%s", ["zh-tw"]="房主拒絕了死靈試煉 Buff 選擇：%s",
	},
}

local selectable_buffs = Catalog.all_selectable(MissionBuffsAllowedBuffs, HordesBuffsData)

local function readable_identifier(buff_name)
	local text = tostring(buff_name):gsub("^hordes_buff_", ""):gsub("_", " ")

	return text:gsub("(%a)([%w']*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end)
end

for i = 1, #selectable_buffs do
	local buff_name = selectable_buffs[i]
	local buff_data = HordesBuffsData[buff_name]
	local display_name

	if buff_data and buff_data.title and buff_data.title ~= "" and rawget(_G, "Localize") then
		local success, localized_title = pcall(Localize, buff_data.title)

		if success and type(localized_title) == "string" and localized_title ~= "" and localized_title ~= "<" .. buff_data.title .. ">" then
			display_name = localized_title
		end
	end

	display_name = display_name or readable_identifier(buff_name)
	localization["mortis_option_" .. buff_name] = {
		["en"] = display_name,
		["zh-cn"] = display_name,
        ["zh-tw"] = display_name,
	}
end

localization.mod_name = { en = "Mortis Trials Buff Manager", ["zh-cn"] = "死灵试炼 Buff 管理器", ["zh-tw"]="死靈試煉 Buff 管理器" }
localization.toggle_mod_name = localization.mod_name
localization.mod_description = { en = "Independent mortis buffs for local and Realms sessions.", ["zh-cn"] = "独立的死灵试炼 Buff 管理器，支持本地及 Realms 会话。", ["zh-tw"]="獨立的死靈試煉 Buff 管理器，支援本地及 Realms 會話。" }

localization["mortis_mode"] = { ["en"] = "Reward mode", ["zh-cn"] = "奖励模式", ["zh-tw"] = "獎勵模式" }
localization["mortis_mode_desc"] = { ["en"] = "Global host rule: preselect Buffs, earn rewards through map progress, or earn personal kill rewards. After the opening route choice, each round automatically grants one remaining route Buff and offers a public / class Buff choice.", ["zh-cn"] = "房主统一设置：开局预选、地图进度或个人击杀奖励。开局选择路线，后续每轮自动发放一个未获得的路线 Buff，并提供一次公共／职业 Buff 三选一。", ["zh-tw"] = "房主統一設定：開局預選、地圖進度或個人擊殺獎勵。開局選擇路線，後續每輪自動發放一個未獲得的路線 Buff，並提供一次公共／職業 Buff 三選一。" }
localization["mortis_mode_preselect"] = { ["en"] = "Preselection", ["zh-cn"] = "预选模式", ["zh-tw"] = "預選模式" }
localization["mortis_mode_draft"] = { ["en"] = "Progress mode", ["zh-cn"] = "进度模式", ["zh-tw"] = "進度模式" }
localization["mortis_mode_competition"] = { ["en"] = "Competition", ["zh-cn"] = "竞争模式", ["zh-tw"] = "競爭模式" }
localization["mortis_buff_limit"] = { ["en"] = "Preselection points / reward rounds", ["zh-cn"] = "预选点数／奖励次数", ["zh-tw"] = "預選點數／獎勵次數" }
localization["mortis_buff_limit_desc"] = { ["en"] = "Shared host setting. Preselection: 0–99 points. Progress: fixed 10 rounds (opening route + 9 paired rewards, up to 19 Buffs); this control is disabled. Competition: 0–99 reward rounds including the opening route choice. Automatic route Buffs do not use an extra round. Drag the slider or click the number to type / paste.", ["zh-cn"] = "房主全局设置。预选：0–99 点；进度：固定 10 次（开局路线＋9 次双奖励，最多 19 个 Buff），此控件置灰；竞争：0–99 次奖励，包含开局路线选择。自动路线 Buff 不额外占用次数。可拖动滑动条或点击数字输入／粘贴。", ["zh-tw"] = "房主全域設定。預選：0–99 點；進度：固定 10 次（開局路線＋9 次雙獎勵，最多 19 個 Buff），此控制項停用；競爭：0–99 次獎勵，包含開局路線選擇。自動路線 Buff 不額外占用次數。可拖動滑動條或點選數字輸入／貼上。" }
localization["mortis_competition_group"] = { ["en"] = "Competition: kill progress", ["zh-cn"] = "竞争模式：击杀进度", ["zh-tw"] = "競爭模式：擊殺進度" }
localization["mortis_kill_horde"] = { ["en"] = "Horde / regular enemy (%%)", ["zh-cn"] = "尸潮／普通敌人（%%）", ["zh-tw"] = "屍潮／普通敵人（%%）" }
localization["mortis_kill_special"] = { ["en"] = "Special (%%)", ["zh-cn"] = "特感（%%）", ["zh-tw"] = "特感（%%）" }
localization["mortis_kill_elite"] = { ["en"] = "Elite (%%)", ["zh-cn"] = "精英（%%）", ["zh-tw"] = "精英（%%）" }
localization["mortis_kill_boss"] = { ["en"] = "Boss (%%)", ["zh-cn"] = "普通 Boss（%%）", ["zh-tw"] = "普通 Boss（%%）" }
localization["mortis_kill_weight_desc"] = { ["en"] = "Host-wide progress per kill, 0–100%% with two decimals. Each 100%% earns one round: an automatic remaining route Buff plus a public / class Buff choice. Route exhaustion leaves the choice available. Overflow is retained. Click to type / paste; Enter / click away saves, Esc cancels.", ["zh-cn"] = "房主统一设置每次击杀进度，0–100%%，支持两位小数。每满 100%% 获得一轮：自动发放一个未获得的路线 Buff，并提供公共／职业 Buff 三选一。路线耗尽后仍有三选一。保留溢出进度。点击数字输入／粘贴，回车／点其他处保存，Esc 取消。", ["zh-tw"] = "房主統一設定每次擊殺進度，0–100%%，支援兩位小數。每滿 100%% 獲得一輪：自動發放一個未獲得的路線 Buff，並提供公共／職業 Buff 三選一。路線耗盡後仍有三選一。保留溢位進度。點選數字輸入／貼上，回車／點其他處儲存，Esc 取消。" }
localization["mortis_global_controls"] = { ["en"] = "Mortis · all players", ["zh-cn"] = "死灵 · 全体玩家", ["zh-tw"] = "死靈 · 全體玩家" }
localization["mortis_global_help"] = { ["en"] = "Shared preselection points · 0–99", ["zh-cn"] = "全局预选点数 · 0–99", ["zh-tw"] = "全域預選點數 · 0–99" }
localization["mortis_number_help"] = { ["en"] = "Type or paste · Enter / click away: save · Esc: cancel", ["zh-cn"] = "输入或粘贴 · 回车／点其他处保存 · Esc 取消", ["zh-tw"] = "輸入或貼上 · Enter／點其他處儲存 · Esc 取消" }
localization["mortis_on"] = { ["en"] = "Enabled", ["zh-cn"] = "开启", ["zh-tw"] = "開啟" }
localization["mortis_off"] = { ["en"] = "Disabled", ["zh-cn"] = "关闭", ["zh-tw"] = "關閉" }
localization["mortis_pool_empty"] = { ["en"] = "No further compatible Buffs", ["zh-cn"] = "没有更多兼容 Buff", ["zh-tw"] = "沒有更多相容 Buff" }
localization["mortis_draft_header"] = { ["en"] = "Legendary choice · %ds · Queued %d · Buffs %d/%d", ["zh-cn"] = "传奇三选一 · %d 秒 · 排队 %d 次 · 已获 %d/%d", ["zh-tw"] = "傳奇三選一 · %d 秒 · 排隊 %d 次 · 已獲 %d/%d" }
localization["mortis_draft_sending"] = { ["en"] = "Confirming with host · %ds · Queued %d · Buffs %d/%d", ["zh-cn"] = "等待主机确认 · %d 秒 · 排队 %d 次 · 已获 %d/%d", ["zh-tw"] = "等待主機確認 · %d 秒 · 排隊 %d 次 · 已獲 %d/%d" }
localization["mortis_draft_chosen"] = { ["en"] = "ACQUIRED", ["zh-cn"] = "已获得", ["zh-tw"] = "已獲得" }
localization["mortis_auto_award"] = { ["en"] = "AUTOMATICALLY ACQUIRED", ["zh-cn"] = "自动获得", ["zh-tw"] = "自動獲得" }
localization["mortis_competition_progress"] = { ["en"] = "Kill progress %.2f%% · Buffs %d/%d", ["zh-cn"] = "击杀进度 %.2f%% · 已获 Buff %d/%d", ["zh-tw"] = "擊殺進度 %.2f%% · 已獲 Buff %d/%d" }
localization["mortis_competition_percentage"] = { ["en"] = "%.2f%%", ["zh-cn"] = "%.2f%%", ["zh-tw"] = "%.2f%%" }
localization["mortis_competition_hud_style"] = { ["en"] = "Competition HUD style", ["zh-cn"] = "竞争进度显示样式", ["zh-tw"] = "競爭進度顯示樣式" }
localization["mortis_competition_hud_style_desc"] = { ["en"] = "Local display preference: small bar, bar + percentage, percentage only, or hidden. Shown at the lower centre of the combat HUD, including during a choice. Changes immediately without changing host rules or rewards.", ["zh-cn"] = "仅影响自己的显示：小型进度条、进度条＋百分比、仅百分比或不显示。位于作战画面下方中央，抽选期间也保留。切换立即生效，不改变房主规则或奖励。", ["zh-tw"] = "僅影響自己的顯示：小型進度條、進度條＋百分比、僅百分比或不顯示。位於作戰畫面下方中央，抽選期間也保留。切換立即生效，不改變房主規則或獎勵。" }
localization["mortis_competition_hud_bar"] = { ["en"] = "Small bar", ["zh-cn"] = "小型进度条", ["zh-tw"] = "小型進度條" }
localization["mortis_competition_hud_bar_percent"] = { ["en"] = "Small bar + percentage", ["zh-cn"] = "小型进度条＋百分比", ["zh-tw"] = "小型進度條＋百分比" }
localization["mortis_competition_hud_percent"] = { ["en"] = "Percentage only", ["zh-cn"] = "仅百分比", ["zh-tw"] = "僅百分比" }
localization["mortis_competition_hud_hidden"] = { ["en"] = "Hidden", ["zh-cn"] = "不显示", ["zh-tw"] = "不顯示" }
localization["mortis_talent_draft_locked"] = { ["en"] = "Mission rewards · Buffs %d/%d", ["zh-cn"] = "局内奖励 · 已获 %d/%d", ["zh-tw"] = "局內獎勵 · 已獲 %d/%d" }
localization["mortis_talent_preselect_locked"] = { ["en"] = "Preselect before the mission", ["zh-cn"] = "请在进入任务前预选", ["zh-tw"] = "請在進入任務前預選" }
localization["mortis_filter_all"] = { ["en"] = "All", ["zh-cn"] = "全部", ["zh-tw"] = "全部" }
localization["mortis_filter_selected"] = { ["en"] = "Selected", ["zh-cn"] = "已选", ["zh-tw"] = "已選" }
localization["mortis_filter_class"] = { ["en"] = "Class", ["zh-cn"] = "职业", ["zh-tw"] = "職業" }
localization["mortis_filter_generic"] = { ["en"] = "General", ["zh-cn"] = "通用", ["zh-tw"] = "通用" }
localization["mortis_filter_family"] = { ["en"] = "Family", ["zh-cn"] = "流派", ["zh-tw"] = "流派" }
localization["mod_description"] = {
    ["en"] = "Open /mortisbuffs in chat. Choose Mortis rewards and load DIY talents in the shared character workspace. Supports SoloPlay and Realms.",
    ["zh-cn"] = "聊天输入 /mortisbuffs，在统一角色界面中预选死灵奖励、加载 DIY 天赋。支持 SoloPlay 与 Realms，也可设置 DMF 快捷键。",
    ["zh-tw"] = "聊天輸入 /mortisbuffs，在統一角色介面中預選死靈獎勵、載入 DIY 天賦。支援 SoloPlay 與 Realms，也可設定 DMF 快捷鍵。",
}
localization["mortis_talent_ui_direct_apply"] = { ["en"] = "Selected %d / %d · Choose before entering the mission", ["zh-cn"] = "已选 %d / %d · 请在进入任务前完成预选", ["zh-tw"] = "已選 %d / %d · 請在進入任務前完成預選" }
localization["mortis_deploy_label"] = { ["en"] = "Mortis Buffs: %s", ["zh-cn"] = "死灵 Buff：%s", ["zh-tw"] = "死靈 Buff：%s" }
localization["mortis_deploy_ready"] = { ["en"] = "Ready", ["zh-cn"] = "已就绪", ["zh-tw"] = "已就緒" }
localization["mortis_deploy_connecting"] = { ["en"] = "Waiting for handshake", ["zh-cn"] = "等待通信确认", ["zh-tw"] = "等待通訊確認" }
localization["mortis_deploy_loading_assets"] = { ["en"] = "Loading native Mortis resources", ["zh-cn"] = "正在加载死灵资源", ["zh-tw"] = "正在載入死靈資源" }
localization["mortis_deploy_incompatible"] = { ["en"] = "Missing mod / incompatible protocol", ["zh-cn"] = "未安装或协议不兼容", ["zh-tw"] = "未安裝或協定不相容" }
localization["mortis_deploy_unavailable"] = { ["en"] = "No response; check installation and version", ["zh-cn"] = "未响应，请检查安装与版本", ["zh-tw"] = "未回應，請檢查安裝與版本" }
localization["mortis_deploy_disconnected"] = { ["en"] = "Connection lost; rewards suspended", ["zh-cn"] = "连接中断，已暂停发放", ["zh-tw"] = "連線中斷，已暫停發放" }
localization["mortis_deploy_disabled"] = { ["en"] = "Mod disabled on this player", ["zh-cn"] = "该玩家已关闭模组", ["zh-tw"] = "該玩家已關閉模組" }
localization["mortis_peer_warning"] = { ["en"] = "Mortis Buffs · %s: %s. Other players can continue.", ["zh-cn"] = "死灵 Buff · %s：%s。其他玩家可以继续。", ["zh-tw"] = "死靈 Buff · %s：%s。其他玩家可以繼續。" }
localization["mortis_kill_weakened_boss"] = { ["en"] = "Weakened boss (%%)", ["zh-cn"] = "虚弱 Boss（%%）", ["zh-tw"] = "虛弱 Boss（%%）" }

localization["mortis_kill_captain"] = { ["en"] = "Captain / twins (%%)", ["zh-cn"] = "连长／双子 Boss（%%）", ["zh-tw"] = "連長／雙子 Boss（%%）" }

localization["mortis_route_description"] = { ["en"] = "Start with: %s. Future route rewards follow this path.", ["zh-cn"] = "选择本局路线。开局获得：%s。后续路线奖励遵循此选择。", ["zh-tw"] = "選擇本局路線。開局獲得：%s。後續路線獎勵遵循此選擇。" }

localization["mortis_route_header"] = { ["en"] = "Choose your route · %ds · Queued %d · Buffs %d/%d", ["zh-cn"] = "选择路线 · %d 秒 · 排队 %d 次 · 已获 %d/%d", ["zh-tw"] = "選擇路線 · %d 秒 · 排隊 %d 次 · 已獲 %d/%d" }

localization["mortis_progress_help"] = { ["en"] = "Fixed 10 rounds · up to 19 Buffs · final milestone 80%%", ["zh-cn"] = "固定 10 次 · 最多 19 个 Buff · 最后节点 80%%", ["zh-tw"] = "固定 10 次 · 最多 19 個 Buff · 最後節點 80%%" }


localization["mortis_limit_preselect"] = { ["en"] = "Preselection point limit", ["zh-cn"] = "预选点数上限", ["zh-tw"] = "預選點數上限" }

localization["mortis_limit_draft"] = { ["en"] = "Progress rewards (fixed)", ["zh-cn"] = "进度奖励次数（固定）", ["zh-tw"] = "進度獎勵次數（固定）" }

localization["mortis_limit_competition"] = { ["en"] = "Competition reward rounds", ["zh-cn"] = "竞争奖励次数", ["zh-tw"] = "競爭獎勵次數" }

localization["mortis_competition_help"] = { ["en"] = "Reward rounds · 0–99 · includes opening route", ["zh-cn"] = "奖励次数 · 0–99 · 包含开局路线", ["zh-tw"] = "獎勵次數 · 0–99 · 包含開局路線" }


localization.workspace_mortis = { ["en"] = "Mortis Buffs", ["zh-cn"] = "死灵天赋", ["zh-tw"] = "死靈天賦" }
localization.workspace_close_native = { ["en"] = "Close the original inventory before opening the custom workspace.", ["zh-cn"] = "请先关闭原版装备界面，再打开自定义配装窗口。", ["zh-tw"] = "請先關閉原版裝備介面，再開啟自訂配裝視窗。" }
localization.workspace_close = { ["en"] = "Close", ["zh-cn"] = "关闭", ["zh-tw"] = "關閉" }
localization.workspace_command = { ["en"] = "Open the shared workspace: Mortis Buffs.", ["zh-cn"] = "打开统一配装窗口：死灵天赋。", ["zh-tw"] = "開啟統一配裝視窗：死靈天賦。" }
localization.open_workspace_bind = { ["en"] = "Open Mortis Buffs (optional shortcut)", ["zh-cn"] = "打开死灵天赋（可选按键）", ["zh-tw"] = "開啟死靈天賦（選用快捷鍵）" }
localization.open_workspace_bind_desc = { ["en"] = "Enable custom Mortis Buffs in Mod Options → Mortis Buff Manager and choose a reward mode. In preselection mode, type /mortisbuffs in chat before the mission. Click a talent to select or remove it; My selection lists saved choices and native/DIY points. Hover for details. No key binding is required; an optional shortcut is available here.", ["zh-cn"] = "在 Mod Options → 死灵试炼 Buff 管理器中开启自定义死灵 Buff，并选择奖励模式。预选模式下，在任务开始前于聊天栏输入 /mortisbuffs。点击天赋即可选取或取消；「我的预选」独立列出保存的选择与原生／DIY 点数，悬停查看详情。无需绑定按键，也可在此设置快捷键。", ["zh-tw"] = "在 Mod Options → 死靈試煉 Buff 管理器中開啟自訂死靈 Buff，並選擇獎勵模式。預選模式下，在任務開始前於聊天欄輸入 /mortisbuffs。點選天賦即可選取或取消；「我的預選」獨立列出儲存的選擇與原生／DIY 點數，懸停檢視詳情。無需綁定按鍵，也可在此設定快捷鍵。" }

localization.workspace_unavailable = { ["en"] = "No editing page is currently available. Enable the relevant feature in DMF and enter a supported session. Mortis preselection is unavailable during missions and in progress or competition mode.", ["zh-cn"] = "当前没有可编辑的页面。请在 DMF 开启对应功能，并进入支持的会话。任务中以及进度、竞争模式下无法编辑死灵预选。", ["zh-tw"] = "目前沒有可編輯的頁面。請在 DMF 開啟對應功能，並進入支援的連線模式。任務中以及進度、競爭模式下無法編輯死靈預選。" }

for key,value in pairs(mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy/diy_localization")) do localization[key]=value end
return localization
