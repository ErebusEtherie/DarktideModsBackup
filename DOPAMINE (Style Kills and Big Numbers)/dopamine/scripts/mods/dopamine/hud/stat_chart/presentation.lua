

---@type mod
local mod = get_mod("dopamine")

if mod.stat_chart_presentation then
	return mod.stat_chart_presentation
end

local Constants = mod:core(mod.stat_chart_constants, "hud/stat_chart/constants").PRESENTATION
local Layout = mod:core(mod.layout, "hud/layout")

---@class StatChartLayout
---@field left boolean            -- true when the chart docks to the LEFT screen edge
---@field halign "left"|"right"
---@field root_valign "top"
---@field root_margin_x number    -- signed inset of the root from the docked edge
---@field offset_y number         -- root drop from hud/layout.lua
---@field text_pad_x number       -- signed row-text inset from the panel's outer edge
---@field exit_slide_sign 1|-1    -- direction a row slides on enter/exit (reserved for row animation)

---@class StatChartPresentation
local StatChartPresentation = {}

---@return StatChartLayout
function StatChartPresentation.layout_side()
	local left = Layout.stats_side() == "left"

	local root_margin_x = Layout.margin_x(left and "left" or "right")

	return {
		left = left,
		halign = left and "left" or "right",
		root_valign = "top",
		root_margin_x = root_margin_x,
		offset_y = Layout.stats_top_y(),
		text_pad_x = left and Constants.TEXT_PAD_X or -Constants.TEXT_PAD_X,
		exit_slide_sign = left and -1 or 1,
	}
end

---@return boolean
function StatChartPresentation.chart_enabled()
	return Layout.stats_enabled()
end

---@return string
function StatChartPresentation.title_text()
	return mod:localize(mod.stats_manager.metric().title_key)
end

---@return argb_table
function StatChartPresentation.bar_color()
	return mod.dl.settings.stat_chart_bar_color or mod.constants.COLOR.NUMBERS.YELLOW
end

local ROWS_TOP_OFFSET = Constants.TITLE_AREA_HEIGHT + Constants.PANEL_VERTICAL_PAD

---@param slot_index integer -- 1 = top row (largest value)
---@return number y
function StatChartPresentation.row_top_y(slot_index)
	return ROWS_TOP_OFFSET + (slot_index - 1) * Constants.ROW_HEIGHT
end

---@return number top_y, number height
function StatChartPresentation.panel_layout()
	local height = Constants.MAX_ROWS * Constants.ROW_HEIGHT
		+ Constants.PANEL_VERTICAL_PAD * 2
		+ Constants.TITLE_AREA_HEIGHT
	return 0, height
end

---@return number y
function StatChartPresentation.title_y()
	return Constants.TITLE_TOP_PAD
end

---@param style table|nil -- a widget text style pass
---@param layout StatChartLayout
function StatChartPresentation.apply_text_align(style, layout)
	if not style then
		return
	end
	style.horizontal_alignment = layout.halign
	style.text_horizontal_alignment = layout.halign
end

---@param style table|nil -- a widget panel/bar style pass (anchored to the docked edge)
---@param layout StatChartLayout
function StatChartPresentation.apply_panel_align(style, layout)
	if not style then
		return
	end
	style.horizontal_alignment = layout.halign
end

---@param style table|nil
---@param layout StatChartLayout
function StatChartPresentation.apply_panel_texture_uv(style, layout)
	if not style then
		return
	end
	if not style.uvs then
		style.uvs = { { 0, 0 }, { 1, 1 } }
	end
	local uvs = style.uvs
	if layout.left then
		uvs[1][1], uvs[1][2], uvs[2][1], uvs[2][2] = 1, 0, 0, 1
	else
		uvs[1][1], uvs[1][2], uvs[2][1], uvs[2][2] = 0, 0, 1, 1
	end
end

---@param value number
---@param max_value number
---@return number
function StatChartPresentation.bar_fraction(value, max_value)
	if not max_value or max_value <= 0 then
		return 0
	end
	return math.clamp(value / max_value, 0, 1)
end

---@param value number|nil
---@return string
function StatChartPresentation.format_value(value)
	return mod.dl.str.format_number(value or 0)
end

mod.stat_chart_presentation = StatChartPresentation

return mod.stat_chart_presentation
