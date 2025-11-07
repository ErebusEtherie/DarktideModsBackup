local loc = {
	mod_name = {
		en = "Recolor Boss Health Bars",
		["zh-cn"] = "Boss血条上色",
		["zh-tw"] = "重繪Boss血條",
	},
	mod_description = {
		en = "Recolors the health bars of certain enemies, and allows more boss health bars to be shown on the screen at once",
		["zh-cn"] = "重新给特定敌人的血条上色，并允许在屏幕上同时显示更多Boss血条",
		["zh-tw"] = "重新染色敵人的血條，並允許螢幕上顯示更多的Boss血條",
	},
	color_daemonhost = {
		en = "Daemonhost",
		["zh-cn"] = "恶魔宿主",
		["zh-tw"] = "惡魔宿主",
	},
	color_hex_dh = {
		en = "Hexbound Daemonhost",
		["zh-cn"] = "咒缚恶魔宿主",
		["zh-tw"] = "魔咒惡魔宿主",
	},
	color_captain = {
		en = "Captains",
		["zh-cn"] = "连长",
		["zh-tw"] = "隊長",
	},
	color_twins = {
		en = "Twin captains",
		["zh-cn"] = "双子连长",
		["zh-tw"] = "雙子隊長",
	},
	color_weakened = {
		en = "Weakened monsters",
		["zh-cn"] = "虚弱怪物",
		["zh-tw"] = "虛弱的怪物",
	},
	color_others = {
		en = "Other monsters",
		["zh-cn"] = "其他怪物",
		["zh-tw"] = "其他怪物",
	},
	tooltip_color_toggle = {
		en = "\nUse the specified color instead of the color defined in \"Other monsters\"",
		["zh-cn"] = "\n使用指定颜色，而不是“其他怪物”中定义的颜色",
		["zh-tw"] = "\n使用指定顏色，而不是“其他怪物”中定義的顏色",
	},
	lines_amount = {
		en = "Max. number of lines of boss health bars",
		["zh-cn"] = "最多Boss血条行数",
		["zh-tw"] = "最大Boss血條行數",
	},
	columns_amount = {
		en = "Number of boss health bars per line",
		["zh-cn"] = "每行Boss血条数量",
		["zh-tw"] = "每行Boss血條數量",
	},
	tooltip_lines_amount = {
		en = "\nMaximum number of lines of boss health bars that can be shown on screen at once.\n\nEach line contains two boss health bars.",
		["zh-cn"] = "\n最多可以同时在屏幕上显示的Boss血条行数。\n\n每行包含两个Boss血条。",
		["zh-tw"] = "\n一次可以在螢幕上顯示的最大Boss血條行數。\n\n每行包含兩個Boss血條。\n\n行數的最大值受螢幕高度限制。",
	},
	two = {
		en = "2",
		["zh-tw"] = "2",
	},
	four = {
		en = "4",
		["zh-tw"] = "4",
	},
}

local unit_type_array = {
	"daemonhost",
	"hex_dh",
	"captain",
	"twins",
	"weakened",
	"others"
}

local loc_col = {
	alpha = {
		en = "Alpha",
		["zh-cn"] = "不透明度",
	},
	r = {
		en = "R",
		["zh-cn"] = "红色",
	},
	g = {
		en = "G",
		["zh-cn"] = "绿色",
	},
	b = {
		en = "B",
		["zh-cn"] = "蓝色",
	},
	toggle = {
		en = "Use special color",
		["zh-cn"] = "使用指定颜色",
	},
}

for _, unit_type in pairs(unit_type_array) do
	for _, col in pairs({"alpha","r","g","b", "toggle"}) do
		loc["color_"..unit_type.."_"..col] = loc_col[col]
	end
end

return loc