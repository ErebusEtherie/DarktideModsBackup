local localizations = {
	mod_name = {
		en = "Sorted Mod Menu",
		es = "Menú de Mods Ordenado",
		ru = "Отсортированное меню модов",
		["zh-cn"] = "排序模组菜单",
		ja = "ソート済みModメニュー",
    	ko = "정렬된 모드 메뉴",
	},
	mod_description = {
		en = "Sort the Mod Options menu alphabetically, hide mods from the list or turn of colourful text.",
		es = "Ordena alfabéticamente el menú de opciones de mods u oculta mods de la lista. Cierra y abre el menú para ver los cambios",
		ru = "Сортируйте меню настроек модов по алфавиту или скрывайте моды из списка. Закройте и откройте меню, чтобы увидеть изменения",
		["zh-cn"] = "按字母顺序排列模组选项菜单，或从列表中隐藏模组。关闭并重新打开菜单以查看更改",
		ja = "Modオプションメニューをアルファベット順に並び替え、リストからModを非表示にできます。変更を確認するにはメニューを一度閉じてから再度開いてください",
		ko = "모드 옵션 메뉴를 알파벳순으로 정렬하거나 목록에서 모드를 숨깁니다. 변경 사항을 확인하려면 메뉴를 닫았다가 다시 열어주세요",
	},
	modname_cleaned = {
		en = "Remove Colors & Glyphs from Mod Names",
		es = "Eliminar colores y glifos de los nombres de los mods",
		ru = "Удалить цвета и символы из названий модов",
		["zh-cn"] = "移除模组名称中的颜色代码和图标",
		ja = "MOD名から色コードとアイコンを削除する",
		ko = "모드 이름에서 색상 코드 및 아이콘 제거",
	},
	modname_cleaned_description = {
		en = "Hides color codes and special glyphs in mod names shown in the category list",
	},
	sort_order = {
		en = "Sort Order",
		es = "Orden de clasificación",
		ru = "Порядок сортировки",
		["zh-cn"] = "排序顺序",
		ja = "並び替え順序",
		ko = "정렬 순서",
	},
	sort_order_description = {
		en = "Alphabetical order of the mods in the category list.\nClose and open the menu to apply",
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
}

for i = 0, 9 do
	localizations["hidden_" .. i] = {
		en = "Hidden Mod " .. (i + 1),
		es = "Mod Oculto " .. (i + 1),
		ru = "Скрытый мод " .. (i + 1),
		["zh-cn"] = "隐藏模组 " .. (i + 1),
		ja = "非表示Mod " .. (i + 1),
		ko = "숨긴 모드 " .. (i + 1),
	}
	localizations["hidden_" .. i .. "_description"] = {
		en = "This mod will not be visible in the category list.\nClose and open the menu to apply",
		es = "Este mod no será visible en la lista de categorías.\nCierra y abre el menú para aplicar",
		ru = "Этот мод не будет отображаться в списке категорий.\nЗакройте и откройте меню для применения",
		["zh-cn"] = "该模组不会显示在类别列表中。\n关闭并重新打开菜单以生效",
		ja = "このModはカテゴリリストに表示されません。\n適用にはメニューを一度閉じて再度開いてください",
		ko = "이 모드는 카테고리 목록에 표시되지 않습니다.\n적용하려면 메뉴를 닫았다가 다시 열어주세요",
	}
end

return localizations
