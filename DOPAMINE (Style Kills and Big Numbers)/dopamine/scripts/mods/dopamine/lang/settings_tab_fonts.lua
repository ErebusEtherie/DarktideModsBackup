---@type mod
local mod = get_mod("dopamine")
local lines = mod.dl.loc_helpers.lines

return {
	tab_fonts = {
		en = "Fonts",
		["zh-cn"] = "字体",
	},
	heading_style_meter_fonts = {
		en = "Style Meter",
		["zh-cn"] = "风格计量器",
	},
	heading_fury_fonts = {
		en = "Fury",
		["zh-cn"] = "字体",
	},
	heading_marker_fonts = {
		en = "Pop-ups",
		["zh-cn"] = "字体",
	},
	style_meter_font_type = {
		en = "Events Font",
		["zh-cn"] = "风格 HUD 字体",
	},
	style_meter_font_type_description = {
		en = lines("Font for the style kills in the style HUD."),
		["zh-cn"] = lines("风格 HUD 中风格击杀显示所使用的字体。"),
	},
	events_font_size = {
		en = "Events Scale",
		["zh-cn"] = "事件轨道缩放",
	},
	events_font_size_description = {
		en = lines("Scales the whole style event track (rows, multiplier, spacing) up or down."),
		["zh-cn"] = lines("整体缩放风格事件轨道（行、倍率、间距）。"),
	},
	sp_counter_font_size = {
		en = "SP Counter Scale",
		["zh-cn"] = "风格点数缩放",
	},
	sp_counter_font_size_description = {
		en = lines("Scales the STYLE POINTS counter, its label, and the +SP pop-ups up or down."),
		["zh-cn"] = lines("缩放风格点数计数器、标签以及 +SP 弹出提示的大小。"),
	},
	fury_rank_font_type = {
		en = "Fury Level Font",
		["zh-cn"] = "狂怒等级字体",
	},
	fury_rank_font_type_description = {
		en = lines("Font name for Fury Level"),
		["zh-cn"] = lines("狂怒等级显示所使用的字体名称。"),
	},
	fury_rank_font_size = {
		en = "Fury Level Font Size",
		["zh-cn"] = "狂怒等级字体大小",
	},
	fury_rank_font_size_description = {
		en = lines("Font size for Fury Level"),
		["zh-cn"] = lines("狂怒等级的字体大小"),
	},
	marker_font_type = {
		en = "Pop-up Font",
		["zh-cn"] = "弹出提示字体",
	},
	marker_font_type_description = {
		en = lines("Font name for pop-ups."),
		["zh-cn"] = lines("弹出提示所使用的字体名称。"),
	},
	marker_font_size = {
		en = "Pop-up Font Size",
		["zh-cn"] = "弹出提示字体大小",
	},
	marker_font_size_description = {
		en = lines("Font size for pop-ups"),
		["zh-cn"] = lines("弹出提示的字体大小"),
	},
	statline_font_size = {
		en = "Statline Font Size",
		["zh-cn"] = "数据栏字体大小",
	},
	statline_font_size_description = {
		en = lines("Font size for the stats below the fury bar"),
		["zh-cn"] = lines("狂怒条下方数据的字体大小"),
	},
}
