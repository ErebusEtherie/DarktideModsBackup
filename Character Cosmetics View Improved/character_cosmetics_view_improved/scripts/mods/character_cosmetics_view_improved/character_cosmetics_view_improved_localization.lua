local mod = get_mod("character_cosmetics_view_improved")

mod:add_global_localize_strings(
    {
        loc_VPCC_preview = {
            en = "Preview",
            ru = "Показать на игроке",
            ["zh-cn"] = "预览"
        },
        loc_VPCC_store = {
            en = "View In Store",
            ru = "Показать в магазине",
            ["zh-cn"] = "在商店中查看"
        },
        loc_VPCC_wishlist = {
            en = "",
            ["zh-cn"] = ""
        },
        loc_VPCC_in_store = {
            en = "",
            ["zh-cn"] = ""
        },
        loc_VPCC_wishlist_added = {
            en = " has been added to your wishlist.",
            ru = " добавляется в список желаемого.",
            ["zh-cn"] = "已被添加至愿望单"
        },
        loc_VPCC_wishlist_removed = {
            en = " has been removed from your wishlist.",
            ru = " убирается из списка желаемого.",
            ["zh-cn"] = "已被从愿望单中移除"
        },
        loc_VPCC_wishlist_notification = {
            en = "The following cosmetic(s) from your wishlist are available for purchase: ",
            ru = "Следующие косметические предметы из вашего списка желаемого доступны для покупки: ",
            ["zh-cn"] = "愿望单中的装饰品现已可购买"
        },
        loc_VPCC_show_all_commodores = {
            en = "Show Commodores: All",
            ru = "Премиумные вещи: Все",
            ["zh-cn"] = "全部"
        },
        loc_VPCC_show_available_commodores = {
            en = "Show Commodores: Available",
            ru = "Премиумные вещи: Доступные",
            ["zh-cn"] = "可用"
        },
        loc_VPCC_show_no_commodores = {
            en = "Show Commodores: None",
            ru = "Премиумные вещи: Не показывать",
            ["zh-cn"] = "不显示"
        }
    }
)

return {
    mod_name = {
        en = "Character Cosmetics View Improved",
        ru = "Улучшенный осмотр косметических предметов",
        ["zh-cn"] = "角色装饰品视图改进"
    },
    mod_description = {
        en = "Displays all premium cosmetics available through Commodore's Vestures in the character cosmetics screen, and allows you to preview them, and go directly to the items in the store (If they are in the current rotation) and much more!",
        ru = "Character Cosmetics View Improved - Отображает все премиумные-косметические предметы, доступные в магазине «Одеяние от Командора», на экране косметических предметов персонажа.",
        ["zh-cn"] = "在角色装饰品画面中显示全部可通过「准将的服装」可获取的物品，并提供预览功能；当该物品在商店售卖时，你可以直接跳转到商店页；以及更多功能！"
    },
    show_commodores = {
        en = "Show Commodores Vesture's Items?",
        ru = "Показывать предметы из магазина «Одеяние от Командора»?",
        ["zh-cn"] = "是否显示「准将的服装」中的物品"
    },
    All = {
        en = "All",
        ru = "Все",
        ["zh-cn"] = "全部"
    },
    OnlyAvailable = {
        en = "Only Available to Purchase",
        ru = "Только доступные для покупки",
        ["zh-cn"] = "仅可购买"
    },
    None = {
        en = "None",
        ru = "Не показывать",
        ["zh-cn"] = "不显示"
    },
    show_unobtainable = {
        en = "Show Unobtainable Cosmetics",
        ru = "Показывать недоступные косметические предметы",
        ["zh-cn"] = "显示无法获取的装饰品"
    },
    display_commodores_price_in_inventory = {
        en = "Show Aquila price in inventory?",
    }
}
