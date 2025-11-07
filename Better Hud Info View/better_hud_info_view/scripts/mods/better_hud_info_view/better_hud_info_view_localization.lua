return {
	mod_name = {
		en = "Better HUD Info View",
		["zh-cn"] = "HUD 信息可视优化",
		["zh-tw"] = "HUD 資訊視覺優化",
		ru = "Улучшенный вид информации в HUD",
	},
	mod_description = {
		en = "HUD Information Display Tweaks (Buff, Mission, Circumstance).",
		["zh-cn"] = "调整左侧祝福垂直位置；任务标题，任务板，计分板位置；调整特殊情况，浩劫词条位置和字体大小。",
		["zh-tw"] = "調整左側增益垂直位置、任務標題；任務版、記分板、浩劫磁條與字體大小。",
		ru = "Better HUD Info View - Настройки отображения информации в HUD (усиление, миссия, обстоятельства).",
	},

	-- 左侧 Buff 面板
	left_buff_panel = {
		en = "Left Buff Panel",
		["zh-cn"] = "左侧 Buff 面板",
		["zh-tw"] = "左側 Buff 面板",
		ru = "Панель усилений слева",
	},
	mortis_toggle = {
		en = "Only show Buff in Mortis Trials",
		["zh-cn"] = "仅在死灵试炼中显示 Buff",
		["zh-tw"] = "僅在死神試煉中顯示Buff",
		ru = "Показывать усиления только в Испытаниях Мортис",
	},
	mortis_toggle_description = {
		en = "If enabled, the buff panel will only be shown in Mortis Trials. If disabled, the buff panel will be hidden in all game modes. Note: Buff panel height cannot be adjusted while this setting is enabled",
		["zh-cn"] = "启用后，仅在死灵试炼中显示 Buff 面板；禁用后，所有模式下都隐藏 Buff 面板。注：启用时无法调节Buff面板高度",
		["zh-tw"] = "啟用後，僅在死靈試煉中顯示增益面板；禁用後，所有模式下都隱藏增益面板。注意：啟用時無法調整增益面板高度",
		ru = "- Если включено, панель баффов будет отображаться только в Испытаниях Мортис.\n- Если отключено, панель баффов будет скрыта во всех режимах игры.\n\nПримечание: высота панели баффов не может быть изменена, пока эта настройка включена!",
	},
	left_buff_offset_y = {
		en = "Left Buff Y Offset",
		["zh-cn"] = "左侧 Buff 垂直偏移上负下正",
		["zh-tw"] = "左側 Buff 垂直偏移（上負下正",
		ru = "Панель усилений слева - смещение по высоте",
	},
	left_buff_offset_y_description = {
		en = "Negative 1000 means the buff panel moves down and disappears. Set to 0 to restore it to the original position",
		["zh-cn"] = "负1000代表将Buff面板下移使其隐藏，设置为0可恢复原始位置",
		["zh-tw"] = "負1000代表將增益面板下移使其隱藏，設置為0可恢復原始位置",
		ru = "-1000 означает, что панель усиления опустится вниз и исчезнет. Значение 0 вернёт в исходное положение.",
	},

	-- 地图标题
	map_info = {
		en = "Map Information",
		["zh-cn"] = "地图信息",
		["zh-tw"] = "地圖資訊",
		ru = "Информация о карте",
	},
	mission_offset_x = {
		en = "Map Name X Offset",
		["zh-cn"] = "地图标题 水平偏移左负右正",
		["zh-tw"] = "地圖標題水平偏移（左負右正）",
		ru = "Название карты - смещение по ширине",
	},
	mission_offset_y = {
		en = "Map Name Y Offset",
		["zh-cn"] = "地图标题 垂直偏移上负下正",
		["zh-tw"] = "地圖標題垂直偏移（上負下正）",
		ru = "Название карты - смещение по высоте",
	},

	-- 任务
	mission_info = {
		en = "Mission Information",
		["zh-cn"] = "任务信息",
		["zh-tw"] = "任務資訊",
		ru = "Информация о миссии",
	},
	circumstance_offset_x = {
		en = "Mission Circumstance X Offset",
		["zh-cn"] = "任务词条 水平偏移左负右正",
		["zh-tw"] = "任務詞綴 水平偏移（左負右正）",
		ru = "Обстоятельства миссии - смещение по ширине",
	},
	circumstance_offset_y = {
		en = "Mission Circumstance Y Offset",
		["zh-cn"] = "任务词条 垂直偏移上负下正",
		["zh-tw"] = "任務詞綴 垂直偏移（上負下正）",
		ru = "Обстоятельства миссии - смещение по высоте",
	},
	circumstance_name_font_size = {
		en = "Circumstance Title Font Size",
		["zh-cn"] = "任务词条 标题字体大小",
		["zh-tw"] = "任務詞綴 標題字體大小",
		ru = "Размер шрифта заголовка обстоятельства миссии",
	},
	circumstance_name_font_size_description = {
		en = "Default value is 24",
		["zh-cn"] = "默认值为24",
		["zh-tw"] = "預設值為24",
		ru = "24 - значение по умолчанию",
	},
	circumstance_description_font_size = {
		en = "Circumstance Description Font Size",
		["zh-cn"] = "任务词条 描述字体大小",
		["zh-tw"] = "任務詞綴 描述字體大小",
		ru = "Размер шрифта описания обстоятельства миссии",
	},
	circumstance_description_font_size_description = {
		en = "Default value is 24",
		["zh-cn"] = "默认值为24",
		["zh-tw"] = "預設值為24",
		ru = "24 - значение по умолчанию",
	},
	danger_offset_x = {
		en = "Mission Danger Info X Offset",
		["zh-cn"] = "任务等级 水平偏移左负右正",
		["zh-tw"] = "任務資訊 水平偏移（左負右正）",
		ru = "Инфо о опасностях миссии - смещение по ширине",
	},
	danger_offset_y = {
		en = "Mission Danger Info Y Offset",
		["zh-cn"] = "任务等级 垂直偏移上负下正",
		["zh-tw"] = "任務危險資訊垂直偏移（上負下正）",
		ru = "Инфо о опасностях миссии - смещение по высоте",
	},

	-- 浩劫
	havoc_info = {
		en = "Havoc Information",
		["zh-cn"] = "浩劫信息",
		["zh-tw"] = "浩劫資訊",
		ru = "Информация о Хавоке",
	},
	havoc_offset_x = {
		en = "Havoc Circumstance X Offset",
		["zh-cn"] = "浩劫词条 水平偏移左负右正",
		["zh-tw"] = "浩劫詞綴 水平偏移（左負右正）",
		ru = "Обстоятельства Хавока - смещение по ширине",
	},
	havoc_offset_y = {
		en = "Havoc Circumstance Y Offset",
		["zh-cn"] = "浩劫词条 垂直偏移上负下正",
		["zh-tw"] = "浩劫詞綴 垂直偏移（上負下正）",
		ru = "Обстоятельства Хавока - смещение по высоте",
	},
	havoc_name_font_size = {
		en = "Havoc Title Font Size",
		["zh-cn"] = "浩劫词条 标题字体大小",
		["zh-tw"] = "浩劫詞綴 標題字體大小",
		ru = "Размер шрифта заголовка Хавока",
	},
	havoc_name_font_size_description = {
		en = "Default value is 24",
		["zh-cn"] = "默认值为24",
		["zh-tw"] = "預設值為24",
		ru = "24 - значение по умолчанию",
	},
	havoc_description_font_size = {
		en = "Havoc Description Font Size",
		["zh-cn"] = "浩劫词条 描述字体大小",
		["zh-tw"] = "浩劫詞綴描述字體大小",
		ru = "Размер шрифта описания Хавока",
	},
	havoc_description_font_size_description = {
		en = "Default value is 20",
		["zh-cn"] = "默认值为20",
		["zh-tw"] = "預設值為20",
		ru = "20 - значение по умолчанию",
	},
	havoc_rank_offset_x = {
		en = "Havoc Rank X Offset",
		["zh-cn"] = "浩劫等级 水平偏移左负右正",
		["zh-tw"] = "浩劫等級水平偏移（左負右正）",
		ru = "Ранг Хавока - смещение по ширине",
	},
	havoc_rank_offset_y = {
		en = "Havoc Rank Y Offset",
		["zh-cn"] = "浩劫等级 垂直偏移上负下正",
		["zh-tw"] = "浩劫等級垂直偏移（上負下正）",
		ru = "Ранг Хавока - смещение по высоте",
	},

	-- 材料
	material_info = {
		en = "Materials Information",
		["zh-cn"] = "材料信息",
		["zh-tw"] = "材料資訊",
		ru = "Информация о ресурсах",
	},
	plasteel_offset_x = {
		en = "Plasteel X Offset",
		["zh-cn"] = "塑钢 水平偏移左负右正",
		["zh-tw"] = "塑鋼 水平偏移（左負右正）",
		ru = "Пласталь - смещение по ширине",
	},
	plasteel_offset_y = {
		en = "Plasteel Y Offset",
		["zh-cn"] = "塑钢 垂直偏移上负下正",
		["zh-tw"] = "塑鋼 垂直偏移（上負下正）",
		ru = "Пласталь - смещение по высоте",
	},
	diamantine_offset_x = {
		en = "Diamantine X Offset",
		["zh-cn"] = "金刚砂 水平偏移左负右正",
		["zh-tw"] = "金剛晶石 水平偏移（左負右正）",
		ru = "Диамантин - смещение по ширине",
	},
	diamantine_offset_y = {
		en = "Diamantine Y Offset",
		["zh-cn"] = "金刚砂 垂直偏移上负下正",
		["zh-tw"] = "金剛晶石 垂直偏移（上負下正）",
		ru = "Диамантин - смещение по высоте",
	},
	
	-- 右侧任务板
	right_board = {
		en = "Right Board Information",
		["zh-cn"] = "右侧任务板信息",
		["zh-tw"] = "右側任務板資訊",
		ru = "Информация на панели справа",
	},
	right_board_offset_x = {
		en = "Right Board X Offset",
		["zh-cn"] = "任务板 水平偏移左负右正",
		["zh-tw"] = "任務板水平偏移（左負右正）",
		ru = "Правая панель - смещение по ширине",
	},
	right_board_offset_y = {
		en = "Right Board Y Offset",
		["zh-cn"] = "任务板 垂直偏移上负下正",
		["zh-tw"] = "任務板垂直偏移（上負下正）",
		ru = "Правая панель - смещение по высоте",
	},
	
	-- 计分板
	scoreboard = {
		en = "Scoreboard Information",
		["zh-cn"] = "计分板信息",
		["zh-tw"] = "計分板資訊",
		ru = "Информация о Таблице результатов",
	},
	scoreboard_offset_x_description = { 
		en = " If you don't have scoreboard, this will not affect anything",
		["zh-cn"] = "如果你没有计分板mod，滑轮不会有任何效果",
		["zh-tw"] = "如果你沒有計分板mod，卷軸不會有任何效果",
		ru = "Если у вас нет Таблицы результатов, эта настройка ни на что не повлияет",
	},
	scoreboard_offset_x = {
		en = "Scoreboard X Offset",
		["zh-cn"] = "计分板 水平偏移左负右正",
		["zh-tw"] = "計分板 水平偏移（左負右正）",
		ru = "Таблица результатов - смещение по ширине",
	},
	scoreboard_offset_y = {
		en = "Scoreboard Y Offset",
		["zh-cn"] = "计分板 垂直偏移上负下正",
		["zh-tw"] = "計分板 垂直偏移（上負下正）",
		ru = "Таблица результатов - смещение по высоте",
	},
	scoreboard_offset_y_description = { 
		en = " If you don't have scoreboard, this will not affect anything", 
		["zh-cn"] = "如果你没有计分板mod，滑轮不会有任何效果",
		["zh-tw"] = "如果你沒有計分板mod，卷軸不會有任何效果",
		ru = "Если у вас нет Таблицы результатов, эта настройка ни на что не повлияет",
	},
}
