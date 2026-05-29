local localizations = {
	mod_name = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
    	ko = "정렬된 모드 메뉴",
	},
	SortModMenu = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
		ko = "정렬된 모드 메뉴",
	},
	["Sorted Mod Menu"] = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
		ko = "정렬된 모드 메뉴",
	},
	mod_description = {
		en = "Sort the Mod Options menu. Pin mods to the top of the list, or hide them. Close and open the menu to see changes",
		es = "Ordena el menú de opciones de mods en el orden que prefieras. Cierra y abre el menú para ver los cambios",
		ru = "Сортируйте меню настроек модов в удобном для вас порядке. Закройте и откройте меню, чтобы увидеть изменения",
		["zh-cn"] = "按您喜欢的顺序对模组选项菜单进行排序。关闭并重新打开菜单以查看更改",
		ja = "Modオプションメニューをお好みの順序に並び替えます。変更を確認するにはメニューを一度閉じてから再度開いてください",
		ko = "모드 옵션 메뉴를 원하는 순서대로 정렬합니다. 변경 사항을 확인하려면 메뉴를 닫았다가 다시 열어주세요",
		ko = "검색 바 활성화",
	},
	searchbox_enabled = {
		en = "Enable Search Bar",
		es = "Habilitar barra de búsqueda",
		ru = "Включить строку поиска",
		["zh-cn"] = "启用搜索栏",
		ja = "検索バーを有効にする",
		ko = "검색창 활성화",
	},
	modname_cleaned = {
		en = "Remove Colors & Glyphs from Mod Names",
		es = "Eliminar colores y glifos de los nombres de los mods",
		ru = "Удалить цвета и символы из названий модов",
		["zh-cn"] = "移除模组名称中的颜色代码和图标",
		ja = "MOD名から色コードとアイコンを削除する",
		ko = "모드 이름에서 색상 코드 및 아이콘 제거",
	},
	sort_order = {
		en = "Sort Order",
		es = "Orden de clasificación",
		ru = "Порядок сортировки",
		["zh-cn"] = "排序顺序",
		ja = "並び替え順序",
		ko = "정렬 순서",
	},
	Ascending = {
		en = "Ascending",
		es = "Ascendente",
		ru = "По возрастанию",
		["zh-cn"] = "升序",
		ja = "昇順",
		ko = "오름차순",
	},
	Descending = {
		en = "Descending",
		es = "Descendente",
		ru = "По убыванию",
		["zh-cn"] = "降序",
		ja = "降順",
		ko = "내림차순",
	},
	None = {
		en = "None",
		es = "Ninguno",
		ru = "Нет",
		["zh-cn"] = "无",
		ja = "なし",
		ko = "없음",
	},
	hidden_mods_group = {
		en = "Hidden Mods",
		es = "Mods Ocultos",
		ru = "Скрытые моды",
		["zh-cn"] = "隐藏模组",
		ja = "非表示Mod",
		ko = "숨긴 모드",
	},
	pinned_mods_group = {
		en = "Pinned Mods",
		es = "Mods Fijados",
		ru = "Закреплённые моды",
		["zh-cn"] = "置顶模组",
		ja = "ピン留めMod",
		ko = "고정된 모드",
	},
	pinned_icon = {
		en = "Add Icon to Pinned Mods",
		es = "Añadir icono a los Mods Fijados",
		ru = "Добавить иконку к закреплённым модам",
		["zh-cn"] = "为置顶模组添加图标",
		ja = "ピン留めModにアイコンを追加",
		ko = "고정된 모드에 아이콘 추가",
	},
	["\u{e046}"] = {
		en = "\u{e046}",
		es = "\u{e046}",
		ru = "\u{e046}",
		["zh-cn"] = "\u{e046}",
		ja = "\u{e046}",
		ko = "\u{e046}",
	},
	["\u{e02b}"] = {
		en = "\u{e02b}",
		es = "\u{e02b}",
		ru = "\u{e02b}",
		["zh-cn"] = "\u{e02b}",
		ja = "\u{e02b}",
		ko = "\u{e02b}",
	},
	["\u{e02a}"] = {
		en = "\u{e02a}",
		es = "\u{e02a}",
		ru = "\u{e02a}",
		["zh-cn"] = "\u{e02a}",
		ja = "\u{e02a}",
		ko = "\u{e02a}",
	},
	["\u{e01e}"] = {
		en = "\u{e01e}",
		es = "\u{e01e}",
		ru = "\u{e01e}",
		["zh-cn"] = "\u{e01e}",
		ja = "\u{e01e}",
		ko = "\u{e01e}",
	},
	["\u{e020}"] = {
		en = "\u{e020}",
		es = "\u{e020}",
		ru = "\u{e020}",
		["zh-cn"] = "\u{e020}",
		ja = "\u{e020}",
		ko = "\u{e020}",
	},
	["\u{e041}"] = {
		en = "\u{e041}",
		es = "\u{e041}",
		ru = "\u{e041}",
		["zh-cn"] = "\u{e041}",
		ja = "\u{e041}",
		ko = "\u{e041}",
	},
}

for i = 0, 9 do
	local tooltip = "Pin #" .. (i + 1) .. " (lower number = higher priority)"
	localizations[tooltip] = {
		en = tooltip, 
		es = "Pin #" .. (i + 1) .. " (número más bajo = mayor prioridad)",
		ru = "Pin #" .. (i + 1) .. " (меньшее число = выше приоритет)",
		["zh-cn"] = "置顶 #" .. (i + 1) .. "（数字越小，优先级越高）",
		ja = "ピン #" .. (i + 1) .. "（数字が小さいほど優先度が高い）",
		ko = "고정 #" .. (i + 1) .. " (숫자가 낮을수록 우선순위가 높음)",
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
		en = "Pinned Mod " .. (i + 1),
		es = "Mod Fijado " .. (i + 1),
		ru = "Закреплённый мод " .. (i + 1),
		["zh-cn"] = "置顶模组 " .. (i + 1),
		ja = "ピン留めMod " .. (i + 1),
		ko = "고정된 모드 " .. (i + 1),
	}
end


return localizations