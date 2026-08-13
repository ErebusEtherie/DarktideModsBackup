return {
	mod_name = {
		en = "Weapon XP Farm",
		["zh-cn"] = "速刷武器熟练度"
	},
	mod_description = {
		en = "Buy and consecrate weapons from Brunt's Armoury in large amounts for Mastery farming.",
		["zh-cn"] = "在布伦特军械库批量购买并圣化武器，快速提升武器熟练度。\n注意：会真实消耗玩家库存的游戏币与材料，请量力而行。"
	},
	open_key = {
		en = "Open Menu Key",
		["zh-cn"] = "打开菜单按键"
	},
	open_key_tooltip = {
		en = "Key to open (or toggle) the Weapon XP Farm menu.",
		["zh-cn"] = "打开或切换武器熟练度速刷菜单的按键。"
	},

	-- ── Shared / rarities ────────────────────────────────────────────────────
	rarity_1 = { en = "Profane",      ["zh-cn"] = "亵渎级" },
	rarity_2 = { en = "Redeemed",     ["zh-cn"] = "救赎级" },
	rarity_3 = { en = "Anointed",     ["zh-cn"] = "涂油级" },
	rarity_4 = { en = "Exalted",      ["zh-cn"] = "崇高级" },
	rarity_5 = { en = "Transcendent", ["zh-cn"] = "超凡级" },
	res_credits    = { en = "Credits",    ["zh-cn"] = "信用点" },
	res_plasteel   = { en = "Plasteel",   ["zh-cn"] = "塑钢" },
	res_diamantine = { en = "Diamantine", ["zh-cn"] = "金刚砂" },
	base_rarity_prefix = {
		en = "|  Base Rarity: ",
		["zh-cn"] = "｜ 基础品质："
	},

	-- ── Page 1: weapon select ────────────────────────────────────────────────
	title = {
		en = "WEAPON XP FARM",
		["zh-cn"] = "武器熟练度速刷"
	},
	loading = {
		en = "Loading store data...",
		["zh-cn"] = "正在加载商店数据…"
	},
	loading_short = {
		en = "Loading...",
		["zh-cn"] = "加载中…"
	},
	loading_store = {
		en = "Loading Brunt's Armoury data...",
		["zh-cn"] = "正在加载布伦特军械库数据…"
	},
	no_weapons = {
		en = "No weapons available in the store for your class.",
		["zh-cn"] = "商店暂无当前职业可用的武器。"
	},
	status_no_player = {
		en = "Error: no local player.",
		["zh-cn"] = "错误：未找到本地玩家。"
	},
	status_store_error = {
		en = "Error processing store. Check logs.",
		["zh-cn"] = "处理商店数据出错，请查看日志。"
	},
	status_store_unavailable = {
		en = "Store unavailable. Open from hub and retry.",
		["zh-cn"] = "商店不可用，请在主舰中打开后重试。"
	},
	tab_melee = {
		en = "MELEE",
		["zh-cn"] = "近战"
	},
	tab_ranged = {
		en = "RANGED",
		["zh-cn"] = "远程"
	},
	mastery_fmt = {
		en = "Mastery %s",
		["zh-cn"] = "熟练度 %s"
	},
	select_one_hint = {
		en = "Select 1 item to proceed",
		["zh-cn"] = "选择 1 件武器以继续"
	},
	current_resources = {
		en = "Current resources:",
		["zh-cn"] = "当前资源："
	},
	btn_next = {
		en = "NEXT >",
		["zh-cn"] = "下一步 >"
	},
	btn_exit = {
		en = "EXIT",
		["zh-cn"] = "退出"
	},

	-- ── Page 2: configure ────────────────────────────────────────────────────
	mode_store = {
		en = "STORE MODE",
		["zh-cn"] = "商店模式"
	},
	mode_inventory = {
		en = "INVENTORY MODE",
		["zh-cn"] = "库存模式"
	},
	auto_max_mastery = {
		en = "Auto Max Mastery",
		["zh-cn"] = "自动满级熟练度"
	},
	auto_max_mastery_hint = {
		en = "Buys exact weapons to reach mastery lvl 20 automatically",
		["zh-cn"] = "自动购买所需数量的武器，直至熟练度达到 20 级"
	},
	auto_sacrifice = {
		en = "Auto Sacrifice Weapons",
		["zh-cn"] = "自动献祭武器"
	},
	auto_sacrifice_hint = {
		en = "Upgrades & sacrifices inventory weapons for XP \xe2\x80\x94 no store purchases",
		["zh-cn"] = "升级并献祭库存武器获取熟练度——不进行商店购买"
	},
	manual_amount = {
		en = "Manual Amount",
		["zh-cn"] = "手动数量"
	},
	manual_amount_hint = {
		en = "Use +/\xe2\x88\x92 buttons or slider to set exact weapon count",
		["zh-cn"] = "使用 +/− 按钮或滑条设置精确购买数量"
	},
	manual_count = {
		en = "Manual Count",
		["zh-cn"] = "手动数量"
	},
	manual_count_hint = {
		en = "Use +/\xe2\x88\x92 buttons or slider to set how many weapons to sacrifice",
		["zh-cn"] = "使用 +/− 按钮或滑条设置要献祭的武器数量"
	},
	inv_filter_label = {
		en = "Select weapons from inventory with rarity:",
		["zh-cn"] = "从库存中选择以下品质的武器："
	},
	filter_any = {
		en = "Any Rarity",
		["zh-cn"] = "任意品质"
	},
	filter_redeemed_plus = {
		en = "Redeemed+",
		["zh-cn"] = "救赎级+"
	},
	filter_anointed_plus = {
		en = "Anointed+",
		["zh-cn"] = "涂油级+"
	},
	filter_exalted_plus = {
		en = "Exalted+",
		["zh-cn"] = "崇高级+"
	},
	filter_transcendent_only = {
		en = "Transcendent only",
		["zh-cn"] = "仅超凡级"
	},
	amount_short = {
		en = "Amount:",
		["zh-cn"] = "数量："
	},
	auto_display = {
		en = "AUTO",
		["zh-cn"] = "自动"
	},
	inv_calc_label = {
		en = "Count inventory toward mastery goal",
		["zh-cn"] = "将库存计入熟练度目标"
	},
	inv_calc_q = {
		en = "Count inventory toward mastery goal?",
		["zh-cn"] = "将库存计入熟练度目标？"
	},
	inv_calc_hint = {
		en = "Subtracts inventory weapons at target rarity or above from buy count. Profane not counted.",
		["zh-cn"] = "从购买数量中扣除已达目标品质及以上的库存武器（不含亵渎级）。"
	},
	upgrade_label = {
		en = "Consecrate to Rarity",
		["zh-cn"] = "圣化品质"
	},
	upgrade_step_fmt = {
		en = "Step %d  \xe2\x86\x92  %s",
		["zh-cn"] = "第 %d 步  \xe2\x86\x92  %s"
	},
	upg_hint_fmt = {
		en = "Min. Rarity required for Sacrifice: %s",
		["zh-cn"] = "献祭所需最低品质：%s"
	},
	upg_hint_any = {
		en = "any rarity",
		["zh-cn"] = "任意品质"
	},
	need_fmt = {
		en = "Need %s weapons to reach mastery lvl %d",
		["zh-cn"] = "还需 %s 把武器以达到 %d 级熟练度"
	},
	need_scanning_fmt = {
		en = "Need %s weapons to reach mastery lvl %d \xe2\x80\x94 scanning inventory...",
		["zh-cn"] = "还需 %s 把武器以达到 %d 级熟练度——正在扫描库存…"
	},
	need_buy_fmt = {
		en = "Need %s weapons to reach mastery lvl %d \xe2\x80\x94 buy %s (%d in inventory)",
		["zh-cn"] = "还需 %s 把武器以达到 %d 级——需购买 %s（库存已有 %d）"
	},
	skipped_fmt = {
		en = "%d skipped: %s",
		["zh-cn"] = "已跳过 %d 把：%s"
	},
	skipped_fav_fmt = {
		en = "%d favorites",
		["zh-cn"] = "%d 把已收藏"
	},
	skipped_below_fmt = {
		en = "%d below %s rarity",
		["zh-cn"] = "%d 把低于%s"
	},
	scanning_inventory = {
		en = "Scanning inventory...",
		["zh-cn"] = "正在扫描库存…"
	},
	checking_inventory = {
		en = "Checking inventory...",
		["zh-cn"] = "正在检查库存…"
	},
	store_inv_notice_fmt = {
		en = "You have %d weapon(s) of this type in inventory",
		["zh-cn"] = "库存中已有 %d 把此类武器"
	},
	order_summary = {
		en = "Order Summary",
		["zh-cn"] = "订单摘要"
	},
	estimated_cost = {
		en = "Estimated Cost:",
		["zh-cn"] = "预计消耗："
	},
	ord_weapons_fmt = {
		en = "Weapons: %s",
		["zh-cn"] = "武器数量：%s"
	},
	auto_tag = {
		en = "(auto)",
		["zh-cn"] = "（自动）"
	},
	ord_credits_fmt = {
		en = "Credits:       %s",
		["zh-cn"] = "信用点：　　%s"
	},
	ord_plasteel_fmt = {
		en = "Plasteel:      %s",
		["zh-cn"] = "塑钢：　　　%s"
	},
	ord_diamantine_fmt = {
		en = "Diamantine:  %s",
		["zh-cn"] = "金刚砂：　　%s"
	},
	cost_note = {
		en = "* Consecration costs scale with item rating.",
		["zh-cn"] = "* 圣化消耗随物品等级提升。"
	},
	confirm_label = {
		en = "Is everything correct?",
		["zh-cn"] = "确认配置无误？"
	},
	hint_open_armory = {
		en = "Open Armory once to populate weapon data",
		["zh-cn"] = "请先打开一次武器库以载入武器数据"
	},
	hint_no_weapons = {
		en = "No matching weapons found",
		["zh-cn"] = "未找到符合条件的武器"
	},
	hint_no_resources = {
		en = "Not enough resources!",
		["zh-cn"] = "资源不足！"
	},
	hint_tick_checkbox = {
		en = "Please tick the checkbox",
		["zh-cn"] = "请勾选确认框"
	},
	btn_proceed = {
		en = "BUY",
		["zh-cn"] = "购买"
	},
	btn_proceed_inv = {
		en = "PROCEED",
		["zh-cn"] = "继续"
	},
	btn_back = {
		en = "< BACK",
		["zh-cn"] = "< 返回"
	},

	-- ── Page 3: processing / done ────────────────────────────────────────────
	processing_header = {
		en = "Working...",
		["zh-cn"] = "正在处理…"
	},
	processing_buying = {
		en = "Purchasing %d / %d...",
		["zh-cn"] = "购买中 %d / %d…"
	},
	consecrating_step_fmt = {
		en = "Consecrating item %d (step %d/%d)...",
		["zh-cn"] = "正在圣化物品 %d（第 %d/%d 步）…"
	},
	processing_fmt = {
		en = "Processing %d / %d...",
		["zh-cn"] = "处理中 %d / %d…"
	},
	stopped_hdr = {
		en = "Stopped \xe2\x80\x94 not enough resources.",
		["zh-cn"] = "已停止——资源不足。"
	},
	stopped_inv_fmt = {
		en = "%d/%d processed. Ran out of Plasteel or Diamantine \xe2\x80\x94 remaining skipped.",
		["zh-cn"] = "已处理 %d/%d。塑钢或金刚砂不足——其余已跳过。"
	},
	stopped_store_fmt = {
		en = "%d/%d purchased. Ran out of Plasteel or Diamantine \xe2\x80\x94 remaining items skipped.",
		["zh-cn"] = "已购买 %d/%d。塑钢或金刚砂不足——其余已跳过。"
	},
	done_errors_hdr = {
		en = "Done with errors.",
		["zh-cn"] = "完成，但有错误。"
	},
	errors_count_fmt = {
		en = "%d error(s). See below.",
		["zh-cn"] = "%d 个错误，详见下方。"
	},
	done_hdr = {
		en = "Done!",
		["zh-cn"] = "完成！"
	},
	done_processed_fmt = {
		en = "Processed %d weapon(s) \xe2\x80\x94 ready to sacrifice.",
		["zh-cn"] = "已处理 %d 把武器——可以献祭了。"
	},
	done_purchased_fmt = {
		en = "Purchased %d weapon(s) successfully.",
		["zh-cn"] = "已成功购买 %d 把武器。"
	},
	craft_hint1 = {
		en = "Open Crafting Station and AUTO SELECT your new weapons for Sacrifice?",
		["zh-cn"] = "打开工作台并自动选择新购武器进行献祭？"
	},
	craft_hint2 = {
		en = "Only just-purchased weapons will be selected.  Auto-Sacrifice will NOT be performed.",
		["zh-cn"] = "只会选中刚购买的武器，不会自动执行献祭。"
	},
	btn_open_select = {
		en = "OPEN & SELECT",
		["zh-cn"] = "打开并选择"
	},
	btn_close = {
		en = "CLOSE",
		["zh-cn"] = "关闭"
	},

	-- ── Blessing points (Mastery screen button + chat messages) ──────────────
	spend_all_fmt = {
		en = "Spend All (%s pts)",
		["zh-cn"] = "全部消耗（%s 点）"
	},
	echo_spent_fmt = {
		en = "[WXF] Unlocked %d blessing(s) for %d point(s) \xe2\x80\x94 %d left. Saved when you close this screen.",
		["zh-cn"] = "[WXF] 已解锁 %d 个祝福，消耗 %d 点——剩余 %d 点。关闭此界面后自动保存。"
	},
	echo_nothing_fmt = {
		en = "[WXF] Nothing to unlock \xe2\x80\x94 everything affordable is already owned (%d point(s) unspent).",
		["zh-cn"] = "[WXF] 没有可解锁的祝福——可负担的祝福均已拥有（剩余 %d 点未使用）。"
	},
	echo_cannot_spend_fmt = {
		en = "[WXF] Could not spend points: %s",
		["zh-cn"] = "[WXF] 无法消耗点数：%s"
	},
	echo_open_mastery = {
		en = "[WXF] Open the Mastery screen first, then use Spend All",
		["zh-cn"] = "[WXF] 请先打开熟练度界面，再使用“全部消耗”"
	},
	echo_open_mastery_btn = {
		en = "[WXF] Open the Mastery screen and select a weapon first, then use this button.",
		["zh-cn"] = "[WXF] 请先打开熟练度界面并选中武器，再使用此按钮。"
	},
	echo_select_weapon = {
		en = "[WXF] Select a weapon in the Mastery screen first",
		["zh-cn"] = "[WXF] 请先在熟练度界面选择武器"
	},
	echo_no_traits = {
		en = "[WXF] No traits found \xe2\x80\x94 select a weapon in the Mastery screen first",
		["zh-cn"] = "[WXF] 未找到祝福数据——请先在熟练度界面选择武器"
	},
	echo_inv_scanned_fmt = {
		en = "[WXF] Inventory scanned: %d weapons cached.",
		["zh-cn"] = "[WXF] 库存扫描完成：已缓存 %d 把武器。"
	},
}
