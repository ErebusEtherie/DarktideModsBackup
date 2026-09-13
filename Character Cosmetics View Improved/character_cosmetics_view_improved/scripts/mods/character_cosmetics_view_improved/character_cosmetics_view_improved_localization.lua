local mod = get_mod("character_cosmetics_view_improved")
mod.version = "4.7.06"
mod:info("Character Cosmetics View Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

-- Colors for the gradient of the mod name
local gradient_start = { 76, 255, 201 }
local gradient_end = { 0, 146, 255 }

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function utf8_chars(s)
	local chars = {}
	for char in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
		table.insert(chars, char)
	end
	return chars
end

mod.gradientText = function(text, startColor, endColor, colorSpaces)
	local result = ""
	local chars = utf8_chars(text)
	local visibleIndex = 0

	for _, char in ipairs(chars) do
		if colorSpaces or char ~= " " then
			visibleIndex = visibleIndex + 1
		end
	end

	local currentIndex = 0

	for _, char in ipairs(chars) do
		if not colorSpaces and char == " " then
			result = result .. char
		else
			currentIndex = currentIndex + 1
			local t = (visibleIndex <= 1) and 0 or (currentIndex - 1) / (visibleIndex - 1)

			local r = math.floor(lerp(startColor[1], endColor[1], t))
			local g = math.floor(lerp(startColor[2], endColor[2], t))
			local b = math.floor(lerp(startColor[3], endColor[3], t))

			result = result .. string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
		end
	end

	result = "{#color(" .. colours.title .. ")}" .. result .. "{#reset()}"
	return result
end

--local name = mod.gradientText("Alf's DMF Extensions", { 255, 255, 0 }, { 255, 0, 255 }, true)
--Clipboard.put(name)
--mod:echo(name)

local mod_name = {
	en = "Character Cosmetics View Improved",
	ru = "Улучшенный осмотр косметических предметов",
	["zh-cn"] = "角色装饰品视图改进",
	["zh-tw"] = "角色裝飾品視圖改進",
}

mod:add_global_localize_strings({

	loc_VPCC_preview = {
		en = "Preview",
		ru = "Показать на игроке",
		["zh-cn"] = "预览",
		["zh-tw"] = "預覽",
	},
	loc_VPCC_store = {
		en = "View In Store",
		ru = "Показать в магазине",
		["zh-cn"] = "在商店中查看",
		["zh-tw"] = "在商店中查看",
	},
	loc_VPCC_wishlist = {
		en = "",
		ru = "",
		["zh-cn"] = "",
		["zh-tw"] = "",
	},
	loc_VPCC_in_store = {
		en = "",
		ru = "",
		["zh-cn"] = "",
		["zh-tw"] = "",
	},
	loc_VPCC_wishlist_added = {
		en = " has been added to your wishlist.",
		ru = " добавляется в список желаемого.",
		["zh-cn"] = "已被添加至愿望单",
		["zh-tw"] = "已被添加至願望單",
	},
	loc_VPCC_wishlist_removed = {
		en = " has been removed from your wishlist.",
		ru = " убирается из списка желаемого.",
		["zh-cn"] = "已被从愿望单中移除",
		["zh-tw"] = "已被從願望單中移除",
	},
	loc_VPCC_wishlist_notification = {
		en = "The following cosmetic(s) from your wishlist are available for purchase: ",
		ru = "Следующие косметические предметы из вашего списка желаемого доступны для покупки: ",
		["zh-cn"] = "愿望单中的装饰品现已可购买",
		["zh-tw"] = "願望單中的裝飾品現已可購買",
	},
	loc_VPCC_show_all_commodores = {
		en = "Show Commodores: All",
		ru = "Премиумные вещи: Все",
		["zh-cn"] = "全部",
		["zh-tw"] = "全部",
	},
	loc_VPCC_show_available_commodores = {
		en = "Show Commodores: Available",
		ru = "Премиумные вещи: Доступные",
		["zh-cn"] = "可用",
		["zh-tw"] = "可用",
	},
	loc_VPCC_show_wishlisted_commodores = {
		en = "Show Commodores: Wishlisted",
		ru = "Премиумные вещи: В списке желаемого",
		["zh-cn"] = "愿望单",
		["zh-tw"] = "願望單",
	},
	loc_VPCC_show_no_commodores = {
		en = "Show Commodores: None",
		ru = "Премиумные вещи: Не показывать",
		["zh-cn"] = "不显示",
		["zh-tw"] = "不顯示",
	},
})

mod.localisation = {
	mod_name = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
		["zh-tw"] = mod_name["zh-tw"],
	},
	mod_name_pizazz = {
		en = mod.gradientText(mod_name["en"], { 76, 255, 201 }, { 0, 146, 255 }, true),
		ru = mod.gradientText(mod_name["ru"], { 76, 255, 201 }, { 0, 146, 255 }, true),
		["zh-cn"] = mod.gradientText(mod_name["zh-cn"], { 76, 255, 201 }, { 0, 146, 255 }, true),
		["zh-tw"] = mod.gradientText(mod_name["zh-tw"], { 76, 255, 201 }, { 0, 146, 255 }, true),
	},
	mod_name_boring = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
		["zh-tw"] = mod_name["zh-tw"],
	},
	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "See all Commodore's Vestures items, data mined items, wishlisting and more, to improve the character cosmetics screen."
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Author: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Version: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
		ru = "{#color("
			.. colours.text
			.. ")}"
			.. "Character Cosmetics View Improved - Отображает все премиум-предметы из магазина «Одеяния от Командора» и добавляет удобные функции."
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Автор: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Версия: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
		["zh-cn"] = "{#color("
			.. colours.text
			.. ")}"
			.. "显示「准将的服装」所有物品，并增加预览、愿望单等功能。"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}作者: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}版本: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
		["zh-tw"] = "{#color("
			.. colours.text
			.. ")}"
			.. "顯示「準將的服裝」所有物品，並增加預覽、願望單等功能。"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}作者: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}版本: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
		ru = "Включить красочное название",
		["zh-cn"] = "启用名称特效",
		["zh-tw"] = "啟用名稱特效",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
		ru = "Включает радужный эффект на тексте названия мода. Требуется перезагрузка.\nЕсли включено, вы получите небольшой эйфорический опыт каждый раз, когда прокручиваете меню модов,\nЕсли выключено - вы будете Джоном Дарктайдом и не будете иметь радужных посыпок (но я всё равно буду любить вас).",
		["zh-cn"] = "切换模组名称文本上的彩虹颜色效果。需要重新加载。\n启用后，每次滚动模组菜单时您都会获得小小的愉悦体验，\n禁用后 - 您将是一个普通暗潮玩家，没有彩虹糖（但我仍然爱您）。",
		["zh-tw"] = "切換模組名稱文字上的彩虹顏色效果。需要重新載入。\n啟用後，每次滾動模組選單時您都會獲得小小的愉悅體驗，\n停用後 - 您將是一個普通暗潮玩家，沒有彩虹糖（但我仍然愛您）。",
	},
	show_commodores = {
		en = "Show Commodores Vesture's Items?",
		ru = "Показывать предметы из магазина «Одеяния от Командора»?",
		["zh-cn"] = "是否显示「准将的服装」中的物品",
		["zh-tw"] = "是否顯示「準將的服裝」中的物品",
	},
	All = {
		en = "All",
		ru = "Все",
		["zh-cn"] = "全部",
		["zh-tw"] = "全部",
	},
	OnlyAvailable = {
		en = "Only Available to Purchase",
		ru = "Только доступные для покупки",
		["zh-cn"] = "仅可购买",
		["zh-tw"] = "僅可購買",
	},
	OnlyWishlisted = {
		en = "Only Wishlisted Items",
		ru = "Только в списке желаемого",
		["zh-cn"] = "仅愿望单中的物品",
		["zh-tw"] = "僅願望單中的物品",
	},
	None = {
		en = "None",
		ru = "Не показывать",
		["zh-cn"] = "不显示",
		["zh-tw"] = "不顯示",
	},
	show_unobtainable = {
		en = "Show Unobtainable Cosmetics",
		ru = "Показывать недоступные косметические предметы",
		["zh-cn"] = "显示无法获取的装饰品",
		["zh-tw"] = "顯示無法取得的裝飾品",
	},
	display_commodores_price_in_inventory = {
		en = "Show Aquila price in inventory?",
		ru = "Показывать цену в аквилах в инвентаре?",
		["zh-cn"] = "在库存中显示鹰币价格？",
		["zh-tw"] = "在庫存中顯示鷹幣價格？",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Основные настройки{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}常规设置{#reset()}",
		["zh-tw"] = "{#color(" .. colours.title .. ")}常規設定{#reset()}",
	},

	show_commodores_tooltip = {
		en = "Choose how much of the locked Commodore's Vestures items you wish to be shown in the character cosmetics screen.\n\nAll: See EVERY item, including those out of rotation.\nOnly Available: See only those in rotation\nNone: Show no commodore's items at all.",
		ru = "Выберите, сколько заблокированных предметов из магазина «Одеяния от Командора» вы хотите показывать на экране косметики персонажа.\n\nВсе: Показывать ВСЕ предметы, включая те, что не в ротации.\nТолько доступные: Показывать только те, что в ротации.\nНе показывать: Не показывать предметы Командора вообще.",
		["zh-cn"] = "选择您希望在角色装饰品屏幕上显示多少锁定的「准将的服装」物品。\n\n全部：查看所有物品，包括不在轮换中的物品。\n仅可购买：仅查看轮换中的物品\n不显示：不显示任何准将的物品。",
		["zh-tw"] = "選擇您希望在角色裝飾品畫面上顯示多少鎖定的「準將的服裝」物品。\n\n全部：查看所有物品，包括不在輪換中的物品。\n僅可購買：僅查看輪換中的物品\n不顯示：不顯示任何準將的物品。",
	},
	show_unobtainable_tooltip = {
		en = "Toggle showing of unobtainable items. These are items that have been datamined, but have no set sources yet.\n\nThis mostly includes items that may come in future updates, or are debug/placeholders. ",
		ru = "Включить отображение недоступных предметов. Это предметы, которые были найдены в данных игры, но пока не имеют источников.\n\nВ основном это предметы, которые могут появиться в будущих обновлениях, или отладочные/заглушки.",
		["zh-cn"] = "切换显示无法获取的物品。这些是已被数据挖掘但尚无确定来源的物品。\n\n主要包括可能在未来更新中出现的物品，或调试/占位物品。",
		["zh-tw"] = "切換顯示無法取得的物品。這些是已被資料探勘但尚無確定來源的物品。\n\n主要包括可能在未來更新中出現的物品，或除錯/占位物品。",
	},
	display_commodores_price_in_inventory_tooltip = {
		en = "Toggle displaying the aquila price of Commodore's Vestures items in the character cosmetics screen.",
		ru = "Включить отображение цены в аквилах предметов из магазина «Одеяния от Командора» на экране косметики персонажа.",
		["zh-cn"] = "切换在角色装饰品屏幕上显示「准将的服装」物品的鹰币价格。",
		["zh-tw"] = "切換在角色裝飾品畫面上顯示「準將的服裝」物品的鷹幣價格。",
	},
}

mod.toggle_pizazz = function()
	for key, values in pairs(mod.localisation) do
		if key == "mod_name" then
			for language, _ in pairs(values) do
				if mod:get("mod_name_pizazz_toggle") then
					mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
				else
					mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
				end
			end
		end
	end
end

mod.toggle_pizazz()

return mod.localisation
