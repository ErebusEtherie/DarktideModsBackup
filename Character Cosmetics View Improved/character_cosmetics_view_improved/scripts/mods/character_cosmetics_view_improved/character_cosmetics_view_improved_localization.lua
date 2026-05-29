local mod = get_mod("character_cosmetics_view_improved")
mod.version = "4.6.10"
mod:info("Character Cosmetics View Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

mod:add_global_localize_strings({

	loc_VPCC_preview = {
		en = "Preview",
		ru = "Показать на игроке",
		["zh-cn"] = "预览",
	},
	loc_VPCC_store = {
		en = "View In Store",
		ru = "Показать в магазине",
		["zh-cn"] = "在商店中查看",
	},
	loc_VPCC_wishlist = {
		en = "",
		["zh-cn"] = "",
	},
	loc_VPCC_in_store = {
		en = "",
		["zh-cn"] = "",
	},
	loc_VPCC_wishlist_added = {
		en = " has been added to your wishlist.",
		ru = " добавляется в список желаемого.",
		["zh-cn"] = "已被添加至愿望单",
	},
	loc_VPCC_wishlist_removed = {
		en = " has been removed from your wishlist.",
		ru = " убирается из списка желаемого.",
		["zh-cn"] = "已被从愿望单中移除",
	},
	loc_VPCC_wishlist_notification = {
		en = "The following cosmetic(s) from your wishlist are available for purchase: ",
		ru = "Следующие косметические предметы из вашего списка желаемого доступны для покупки: ",
		["zh-cn"] = "愿望单中的装饰品现已可购买",
	},
	loc_VPCC_show_all_commodores = {
		en = "Show Commodores: All",
		ru = "Премиумные вещи: Все",
		["zh-cn"] = "全部",
	},
	loc_VPCC_show_available_commodores = {
		en = "Show Commodores: Available",
		ru = "Премиумные вещи: Доступные",
		["zh-cn"] = "可用",
	},
	loc_VPCC_show_wishlisted_commodores = {
		en = "Show Commodores: Wishlisted",
	},
	loc_VPCC_show_no_commodores = {
		en = "Show Commodores: None",
		ru = "Премиумные вещи: Не показывать",
		["zh-cn"] = "不显示",
	},
})

mod.localisation = {
	mod_name = {
		en = "{#color("
			.. colours.title
			.. ")} "
			.. "{#color(76,255,201)}C{#color(73,251,202)}h{#color(70,247,204)}a{#color(68,243,206)}r{#color(65,239,208)}a{#color(62,236,210)}c{#color(60,232,212)}t{#color(57,228,214)}e{#color(55,224,215)}r {#color(52,221,217)}C{#color(49,217,219)}o{#color(47,213,221)}s{#color(44,209,223)}m{#color(41,206,225)}e{#color(39,202,227)}t{#color(36,198,228)}i{#color(34,194,230)}c{#color(31,191,232)}s {#color(28,187,234)}V{#color(26,183,236)}i{#color(23,179,238)}e{#color(20,176,240)}w {#color(18,172,241)}I{#color(15,168,243)}m{#color(13,164,245)}p{#color(10,161,247)}r{#color(7,157,249)}o{#color(5,153,251)}v{#color(2,149,253)}e{#color(0,146,255)}d{#reset()}",
		ru = "Улучшенный осмотр косметических предметов",
		["zh-cn"] = "角色装饰品视图改进",
	},
	mod_name_boring = {
		en = "Character Cosmetics View Improved",
	},
	mod_name_pizazz = {
		en = "{#color("
			.. colours.title
			.. ")} "
			.. "{#color(76,255,201)}C{#color(73,251,202)}h{#color(70,247,204)}a{#color(68,243,206)}r{#color(65,239,208)}a{#color(62,236,210)}c{#color(60,232,212)}t{#color(57,228,214)}e{#color(55,224,215)}r {#color(52,221,217)}C{#color(49,217,219)}o{#color(47,213,221)}s{#color(44,209,223)}m{#color(41,206,225)}e{#color(39,202,227)}t{#color(36,198,228)}i{#color(34,194,230)}c{#color(31,191,232)}s {#color(28,187,234)}V{#color(26,183,236)}i{#color(23,179,238)}e{#color(20,176,240)}w {#color(18,172,241)}I{#color(15,168,243)}m{#color(13,164,245)}p{#color(10,161,247)}r{#color(7,157,249)}o{#color(5,153,251)}v{#color(2,149,253)}e{#color(0,146,255)}d{#reset()}",
		ru = "Улучшенный осмотр косметических предметов",
		["zh-cn"] = "角色装饰品视图改进",
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
		ru = "Character Cosmetics View Improved - Отображает все премиумные-косметические предметы, доступные в магазине «Одеяние от Командора», на экране косметических предметов персонажа.",
		["zh-cn"] = "在角色装饰品画面中显示全部可通过「准将的服装」可获取的物品，并提供预览功能；当该物品在商店售卖时，你可以直接跳转到商店页；以及更多功能！",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
	},
	show_commodores = {
		en = "Show Commodores Vesture's Items?",
		ru = "Показывать предметы из магазина «Одеяние от Командора»?",
		["zh-cn"] = "是否显示「准将的服装」中的物品",
	},
	All = {
		en = "All",
		ru = "Все",
		["zh-cn"] = "全部",
	},
	OnlyAvailable = {
		en = "Only Available to Purchase",
		ru = "Только доступные для покупки",
		["zh-cn"] = "仅可购买",
	},
	OnlyWishlisted = {
		en = "Only Wishlisted Items",
	},
	None = {
		en = "None",
		ru = "Не показывать",
		["zh-cn"] = "不显示",
	},
	show_unobtainable = {
		en = "Show Unobtainable Cosmetics",
		ru = "Показывать недоступные косметические предметы",
		["zh-cn"] = "显示无法获取的装饰品",
	},
	display_commodores_price_in_inventory = {
		en = "Show Aquila price in inventory?",
	},
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
	},

	show_commodores_tooltip = {
		en = "Choose how much of the locked Commodore's Vestures items you wish to be shown in the character cosmetics screen.\n\nAll: See EVERY item, including those out of rotation.\nOnly Available: See only those in rotation\nNone: Show no commodore's items at all.",
	},
	show_unobtainable_tooltip = {
		en = "Toggle showing of unobtainable items. These are items that have been datamined, but have no set sources yet.\n\nThis mostly includes items that may come in future updates, or are debug/placeholders. ",
	},
	display_commodores_price_in_inventory_tooltip = {
		en = "Toggle displaying the aquila price of Commodore's Vestures items in the character cosmetics screen.",
	},
}

mod.toggle_pizazz = function()
	for key, values in pairs(mod.localisation) do
		if key == "mod_name" then
			for language, text in pairs(values) do
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
