local localizations = {
	mod_name = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
	},
	SortModMenu = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
	},
	["Sorted Mod Menu"] = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
	},
	mod_description = {
		en = "Sort the Mod Options menu in your preferred order. Close and open the menu to see changes",
		es = "Ordena el menú de opciones de mods en el orden que prefieras. Cierra y abre el menú para ver los cambios",
		ru = "Сортируйте меню настроек модов в удобном для вас порядке. Закройте и откройте меню, чтобы увидеть изменения",
		["zh-cn"] = "按您喜欢的顺序对模组选项菜单进行排序。关闭并重新打开菜单以查看更改",
		ja = "Modオプションメニューをお好みの順序に並び替えます。変更を確認するにはメニューを一度閉じてから再度開いてください",
	},
	searchbox_enabled = {
		en = "Enable Search Bar",
		es = "Habilitar barra de búsqueda",
		ru = "Включить строку поиска",
		["zh-cn"] = "启用搜索栏",
		ja = "検索バーを有効にする",
	},
	sort_order = {
		en = "Sort Order",
		es = "Orden de clasificación",
		ru = "Порядок сортировки",
		["zh-cn"] = "排序顺序",
		ja = "並び替え順序",
	},
	Ascending = {
		en = "Ascending",
		es = "Ascendente",
		ru = "По возрастанию",
		["zh-cn"] = "升序",
		ja = "昇順",
	},
	Descending = {
		en = "Descending",
		es = "Descendente",
		ru = "По убыванию",
		["zh-cn"] = "降序",
		ja = "降順",
	},
	None = {
		en = "None",
		es = "Ninguno",
		ru = "Нет",
		["zh-cn"] = "无",
		ja = "なし",
	},
	pinned_mods_group = {
		en = "Pinned Mods",
		es = "Mods Fijados",
		ru = "Закреплённые моды",
		["zh-cn"] = "置顶模组",
		ja = "ピン留めMod",
	},
	pinned_icon = {
		en = "Add Icon to Pinned Mods",
		es = "Añadir icono a los Mods Fijados",
		ru = "Добавить иконку к закреплённым модам",
		["zh-cn"] = "为置顶模组添加图标",
		ja = "ピン留めModにアイコンを追加",
	},
	["\u{e046}"] = {
		en = "\u{e046}"
	},
	["\u{e02b}"] = {
		en = "\u{e02b}"
	},
	["\u{e02a}"] = {
		en = "\u{e02a}"
	},
	["\u{e01e}"] = {
		en = "\u{e01e}"
	},
	["\u{e020}"] = {
		en = "\u{e020}"
	},
	["\u{e041}"] = {
		en = "\u{e041}"
	},
}

for i = 0, 9 do
	local tooltip = "Pin #" .. (i + 1) .. " (lower number = higher priority)"
	localizations[tooltip] = {
		en = tostring(tooltip)
	}
end

local dmf = get_mod("DMF")

for mod_name, mod in pairs(dmf.mods) do
	local displayed = mod:get_readable_name() or mod:localize("mod_name") or "error"
    localizations[displayed] = {
		en = tostring(displayed)
	}
end

for i = 0, 9 do
	localizations["pin_" .. i] = {
		en = "Pinned Mod " .. i + 1
	}
end


return localizations