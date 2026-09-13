

---@param Module DLH_SettingsMenu
return function(Module)
	if Module.layout_manager then
		return Module.layout_manager
	end

	local LayoutManager = {}

	local C = Module.constants

	local CONTENT_Y = C.TITLE_HEIGHT + C.CONTENT_TOP_GAP

	local CTRL_Y = C.LABEL_HEIGHT + 4

	local DESC_Y = C.HEADING_FONT_SIZE + 4

	local CELL_H = math.max(C.CELL_HEIGHT, CTRL_Y + C.CONTROL_HEIGHT)

	local UNIT_H = (CELL_H - (C.ROW_UNITS - 1) * C.CELL_GUTTER_Y) / C.ROW_UNITS

	local function content_x()
		if Module.has_tabs then
			return C.CONTENT_PAD + C.TAB_COL_WIDTH + C.TAB_COL_GAP
		end
		return C.CONTENT_PAD
	end

	local SCROLL_GUTTER = C.SCROLLBAR_WIDTH + C.SCROLLBAR_GAP

	---@param tab DLH_SettingsMenuTab | nil nil means "the full band" (the baked default)
	---@return number
	function LayoutManager.tab_header_height(tab)
		if not Module.has_tabs then
			return 0
		end
		if not tab then
			return C.TAB_HEADER_HEIGHT
		end
		if tab.description_text then
			return C.TAB_HEADER_HEIGHT
		end
		if tab.title_text then
			return C.TAB_TITLE_HEIGHT
		end
		return 0
	end

	---@param header_h number | nil defaults to the full band
	---@return number x, number grid_y, number cell_w, number unit_h, number content_h
	local function grid_metrics(header_h)
		local left_inset = content_x()
		local grid_y = CONTENT_Y + (header_h or LayoutManager.tab_header_height(nil))

		local content_w = C.PANEL_WIDTH - left_inset - C.CONTENT_PAD - SCROLL_GUTTER

		local content_h = C.PANEL_HEIGHT - grid_y - C.CONTENT_PAD - C.CONTENT_BOTTOM_PAD
		local cell_w = (content_w - (C.GRID_COLS - 1) * C.CELL_GUTTER_X) / C.GRID_COLS
		return left_inset, grid_y, cell_w, UNIT_H, content_h
	end

	---@return number
	function LayoutManager.unit_step()
		return UNIT_H + C.CELL_GUTTER_Y
	end

	---@param units number
	---@return number
	function LayoutManager.span_height(units)
		return units * UNIT_H + (units - 1) * C.CELL_GUTTER_Y
	end

	---@param height number
	---@return number
	function LayoutManager.units_for_height(height)
		return (height + C.CELL_GUTTER_Y) / LayoutManager.unit_step()
	end

	---@return number
	function LayoutManager.button_row_units()
		return LayoutManager.units_for_height(C.CONTROL_HEIGHT)
	end

	---@param header_h number | nil
	---@return number
	function LayoutManager.visible_units(header_h)
		local _, _, _, _, content_h = grid_metrics(header_h)
		return math.max(C.ROW_UNITS, math.floor((content_h + C.CELL_GUTTER_Y) / LayoutManager.unit_step()))
	end

	---@param header_h number | nil
	---@return number
	function LayoutManager.viewport_height(header_h)
		return LayoutManager.span_height(LayoutManager.visible_units(header_h))
	end

	---@param header_h number | nil
	---@return number top, number bottom
	function LayoutManager.viewport_bounds(header_h)
		local _, grid_y = grid_metrics(header_h)
		return grid_y, grid_y + LayoutManager.viewport_height(header_h)
	end

	---@param header_h number | nil
	---@return DLH_SettingsMenuRect
	function LayoutManager.scrollbar_rect(header_h)
		local _, grid_y = grid_metrics(header_h)
		return {
			x = C.PANEL_WIDTH - C.CONTENT_PAD - C.SCROLLBAR_WIDTH,
			y = grid_y,
			w = C.SCROLLBAR_WIDTH,
			h = LayoutManager.viewport_height(header_h),
		}
	end

	---@class DLH_SettingsMenuRect
	---@field x number
	---@field y number
	---@field w number
	---@field h number

	---@param index number 1-based tab position
	---@return DLH_SettingsMenuRect
	function LayoutManager.tab_rect(index)
		return {
			x = C.CONTENT_PAD,
			y = CONTENT_Y + (index - 1) * (C.TAB_HEIGHT + C.TAB_GAP),
			w = C.TAB_COL_WIDTH,
			h = C.TAB_HEIGHT,
		}
	end

	---@param tab DLH_SettingsMenuTab | nil
	---@return DLH_SettingsMenuRect
	function LayoutManager.tab_header_rect(tab)
		local x = content_x()
		return {
			x = x,
			y = CONTENT_Y,
			w = C.PANEL_WIDTH - x - C.CONTENT_PAD,
			h = LayoutManager.tab_header_height(tab),
		}
	end

	---@param tab DLH_SettingsMenuTab | nil
	---@return { title: DLH_SettingsMenuRect, description: DLH_SettingsMenuRect }
	function LayoutManager.tab_header_parts(tab)
		local rect = LayoutManager.tab_header_rect(tab)
		local w = rect.w
		return {
			title = { x = 0, y = 0, w = w, h = math.min(C.TAB_TITLE_HEIGHT, rect.h) },
			description = {
				x = 0,
				y = C.TAB_TITLE_HEIGHT,
				w = w,
				h = math.max(0, rect.h - C.TAB_TITLE_HEIGHT),
			},
		}
	end

	---@param header_h number | nil
	---@return DLH_SettingsMenuRect
	function LayoutManager.cell_rect(col, row, col_span, row_span, header_h)
		col_span = col_span or 1
		row_span = row_span or C.ROW_UNITS

		local x, grid_y, cell_w, unit_h = grid_metrics(header_h)

		return {
			x = x + (col - 1) * (cell_w + C.CELL_GUTTER_X),
			y = grid_y + (row - 1) * (unit_h + C.CELL_GUTTER_Y),
			w = col_span * cell_w + (col_span - 1) * C.CELL_GUTTER_X,
			h = row_span * unit_h + (row_span - 1) * C.CELL_GUTTER_Y,
		}
	end

	---@param cell_w number
	---@return DLH_SettingsMenuRect
	local function label_rect(cell_w)
		return { x = 0, y = 0, w = cell_w, h = C.LABEL_HEIGHT }
	end

	---@param cell_w number
	---@return DLH_SettingsMenuRect
	local function row_rect(cell_w)
		return { x = 0, y = CTRL_Y, w = cell_w, h = C.CONTROL_HEIGHT }
	end

	---@param cell_w number
	---@return DLH_SettingsMenuRect
	local function reset_icon_rect(cell_w)
		local s = C.RESET_ICON_SIZE
		return { x = cell_w - s, y = (C.LABEL_HEIGHT - s) * 0.5, w = s, h = s }
	end

	---@param cell_w number
	---@return { label: DLH_SettingsMenuRect, row: DLH_SettingsMenuRect, minus: DLH_SettingsMenuRect, plus: DLH_SettingsMenuRect, value: DLH_SettingsMenuRect }
	function LayoutManager.numeric_parts(cell_w)
		local btn = C.STEP_BUTTON_WIDTH
		return {
			label = label_rect(cell_w),
			reset = reset_icon_rect(cell_w),
			row = row_rect(cell_w),
			minus = { x = 0, y = CTRL_Y, w = btn, h = C.CONTROL_HEIGHT },
			plus = { x = cell_w - btn, y = CTRL_Y, w = btn, h = C.CONTROL_HEIGHT },
			value = { x = btn, y = CTRL_Y, w = cell_w - btn * 2, h = C.CONTROL_HEIGHT },
		}
	end

	---@param cell_w number
	---@return { label: DLH_SettingsMenuRect, row: DLH_SettingsMenuRect, fill: DLH_SettingsMenuRect, state: DLH_SettingsMenuRect }
	function LayoutManager.checkbox_parts(cell_w)
		local box = C.CONTROL_HEIGHT
		local inset = C.CHECK_FILL_INSET
		local gap = 10
		return {
			label = label_rect(cell_w),
			reset = reset_icon_rect(cell_w),
			row = row_rect(cell_w),
			fill = { x = inset, y = CTRL_Y + inset, w = box - inset * 2, h = box - inset * 2 },
			state = { x = box + gap, y = CTRL_Y, w = cell_w - box - gap, h = box },
		}
	end

	---@param cell_w number
	---@return { label: DLH_SettingsMenuRect, row: DLH_SettingsMenuRect, box: DLH_SettingsMenuRect, clear: DLH_SettingsMenuRect }
	function LayoutManager.keybind_parts(cell_w)
		local clear = C.STEP_BUTTON_WIDTH
		local gap = 6
		return {
			label = label_rect(cell_w),
			reset = reset_icon_rect(cell_w),
			row = row_rect(cell_w),
			box = { x = 0, y = CTRL_Y, w = cell_w - clear - gap, h = C.CONTROL_HEIGHT },
			clear = { x = cell_w - clear, y = CTRL_Y, w = clear, h = C.CONTROL_HEIGHT },
		}
	end

	---@param cell_w number
	---@return { label: DLH_SettingsMenuRect, row: DLH_SettingsMenuRect, value: DLH_SettingsMenuRect, arrow: DLH_SettingsMenuRect }
	function LayoutManager.dropdown_parts(cell_w)
		local btn = C.STEP_BUTTON_WIDTH
		local pad = C.DROPDOWN_TEXT_PAD
		return {
			label = label_rect(cell_w),
			reset = reset_icon_rect(cell_w),
			row = row_rect(cell_w),
			value = { x = pad, y = CTRL_Y, w = cell_w - btn - pad * 2, h = C.CONTROL_HEIGHT },
			arrow = { x = cell_w - btn, y = CTRL_Y, w = btn, h = C.CONTROL_HEIGHT },
		}
	end

	---@param cell_w number
	---@param has_label boolean | nil whether the button drew a label above its row
	---@return { label: DLH_SettingsMenuRect, row: DLH_SettingsMenuRect, caption: DLH_SettingsMenuRect }
	function LayoutManager.button_parts(cell_w, has_label)
		local row = has_label and row_rect(cell_w) or { x = 0, y = 0, w = cell_w, h = C.CONTROL_HEIGHT }
		return {
			label = label_rect(cell_w),
			row = row,
			caption = { x = 0, y = row.y, w = cell_w, h = row.h },
		}
	end

	---@param option_count number
	---@return number
	function LayoutManager.dropdown_visible_options(option_count)
		return math.min(option_count, C.DROPDOWN_MAX_VISIBLE)
	end

	---@param index number 1-based slot, top to bottom
	---@param width number
	---@return DLH_SettingsMenuRect
	function LayoutManager.dropdown_option_rect(index, width)
		return {
			x = 0,
			y = (index - 1) * C.DROPDOWN_OPTION_HEIGHT,
			w = width,
			h = C.DROPDOWN_OPTION_HEIGHT,
		}
	end

	---@param cell_w number
	---@param has_description boolean | nil
	---@return { heading: DLH_SettingsMenuRect, description: DLH_SettingsMenuRect | nil }
	function LayoutManager.heading_parts(cell_w, has_description)
		local total = C.CONTROL_HEIGHT
		if not has_description then

			local heading_h = LayoutManager.span_height(C.HEADING_ROW_UNITS)
			return {
				heading = { x = 0, y = 0, w = cell_w, h = heading_h },

				rule = { x = 0, y = heading_h * 0.5 - 0.5, w = cell_w, h = 2 },
			}
		end

		local heading_h = DESC_Y
		return {
			heading = { x = 0, y = 0, w = cell_w, h = heading_h },
			description = { x = 0, y = heading_h + 16, w = cell_w, h = total - heading_h },
			rule = { x = 0, y = heading_h * 0.5 - 0.5, w = cell_w, h = 1 },
		}
	end

	---@param tab DLH_SettingsMenuTab | nil
	---@return DLH_SettingsMenuRect
	function LayoutManager.tab_reset_rect(tab)
		local header = LayoutManager.tab_header_rect(tab)
		local w = C.RESET_TAB_WIDTH
		return {
			x = header.x + header.w - SCROLL_GUTTER - w,
			y = header.y,
			w = w,
			h = C.TAB_TITLE_HEIGHT,
		}
	end

	---@return DLH_SettingsMenuRect
	function LayoutManager.reset_all_rect()
		local h = C.TAB_HEIGHT
		return {
			x = C.CONTENT_PAD,
			y = C.PANEL_HEIGHT - C.CONTENT_PAD - h,
			w = C.TAB_COL_WIDTH,
			h = h,
		}
	end

	---@return DLH_SettingsMenuRect
	function LayoutManager.fancy_transitions_rect()
		local reset = LayoutManager.reset_all_rect()
		local h = C.TAB_HEIGHT
		return {
			x = reset.x,
			y = reset.y - C.TAB_GAP - h,
			w = reset.w,
			h = h,
		}
	end

	---@param rect DLH_SettingsMenuRect
	---@param px number
	---@param py number
	---@return boolean
	function LayoutManager.point_in(rect, px, py)
		return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
	end

	Module.layout_manager = LayoutManager

	return LayoutManager
end
