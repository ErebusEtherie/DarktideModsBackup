
local mod = get_mod("hud_studio")

if mod.hud_studio_dropdown_component then
	return mod.hud_studio_dropdown_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Format = mod:core(mod.editor_format, "hud/editor/format")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")

local COLOR = C.COLOR
local DROPDOWN_COLOR = {
	DROPDOWN_OPTION_HOVER = { 255, 60, 60, 60 },
	DROPDOWN_SECTION_TEXT = { 220, 25, 25, 25 }, 
	DROPDOWN_OPTION_SELECTED = { 255, 110, 110, 110 }, 
}
local PANEL = C.PANEL
local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local FONT_SECTION = mod.dl.fonts.validated("proxima_nova_bold")
local CONTROL_SIZE = 14
local MAX_Y_ADD = 75
local OPTION_H = PANEL.DROPDOWN_OPTION_H
local MAX_VISIBLE = PANEL.DROPDOWN_MAX_VISIBLE
local TEXT_PAD = 6

local TRIGGER_FIT_PAD = 14
local CHILD_INDENT = 18 
local SCROLLBAR_W = 3 
local TREE_COLOR = { 255, 120, 120, 120 } 
local CARET_CELL = 18 
local POPUP_EXTRA_W = 46 
local SEARCH_H = 26 
local SEARCH_PAD = 3 
local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")

local function design_screen()
	local inv = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1
	local screen_w = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local screen_h = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	return screen_w * inv, screen_h * inv
end

local Dropdown = {}

function Dropdown.options(ctrl)
	local o = ctrl.options
	if type(o) == "function" then
		return o() or {}
	end
	return o or {}
end

function Dropdown.selected_text(ctrl)
	local current = ctrl.get()
	local options = Dropdown.options(ctrl)
	local group_text 
	for i = 1, #options do
		local option = options[i]
		if Dropdown.is_group(option) then
			group_text = tostring(option.text)
		elseif Dropdown.is_selectable(option) and option.value == current then
			if option.child and group_text then
				return group_text .. "  " .. tostring(option.text)
			end
			return option.text
		end
	end
	if current == nil then
		return ""
	end
	return Format.value(current)
end

function Dropdown.parts(x, y, w, h)
	local aw = PANEL.STEP_W
	return {
		box = { x = x, y = y, w = w, h = h },
		arrow = { x = x + w - aw, y = y, w = aw, h = h },
	}
end

function Dropdown.popup_rect(box, count, max_count, heights, search)
	local visible = math.min(count, MAX_VISIBLE)
	local w = box.w + POPUP_EXTRA_W
	local window_h = visible * OPTION_H
	if heights then

		local sum = 0
		for i = 1, count do
			sum = sum + (heights[i] or OPTION_H)
		end
		window_h = math.min(sum, MAX_VISIBLE * OPTION_H)
	end
	local rows_y = search and SEARCH_H or 0
	local h = window_h + rows_y
	local max_h = math.min(max_count or count, MAX_VISIBLE) * OPTION_H + rows_y + MAX_Y_ADD 
	local screen_w, screen_h = design_screen()

	local x, y = box.x, box.y + box.h
	if y + max_h > screen_h then

		y = box.y
		if box.x + box.w + w <= screen_w then
			x = box.x + box.w
		elseif box.x - w >= 0 then
			x = box.x - w
		end
	end

	return {
		x = math.max(0, math.min(x, screen_w - w)),
		y = math.max(0, math.min(y, screen_h - max_h)),
		w = w,
		h = h,
		window_h = window_h, 
		oh = OPTION_H,
		visible = visible,
		rows_y = rows_y, 
	}
end

function Dropdown.search_rect(pr)
	return {
		x = pr.x + SEARCH_PAD,
		y = pr.y + SEARCH_PAD,
		w = pr.w - SEARCH_PAD * 2,
		h = SEARCH_H - SEARCH_PAD * 2,
	}
end

function Dropdown.filter(options, query)
	if not query or query == "" then
		return nil
	end
	local needle = query:lower()
	local matches = {}
	local group_text 
	for i = 1, #options do
		local option = options[i]
		if Dropdown.is_group(option) then
			group_text = tostring(option.text)
		elseif Dropdown.is_selectable(option) then
			local label = (option.child and group_text) and (group_text .. "  " .. tostring(option.text))
				or tostring(option.text)
			if label:lower():find(needle, 1, true) then
				matches[#matches + 1] = { value = option.value, text = label }
			end
		end
	end
	return matches
end

function Dropdown.group_key(option)
	return option and option.group == true and tostring(option.text) or nil
end

function Dropdown.visible_options(options, collapsed)
	if not collapsed or not next(collapsed) then
		return options
	end
	local shown = {}
	local hiding = false
	for i = 1, #options do
		local option = options[i]
		local key = Dropdown.group_key(option)
		if key then

			hiding = collapsed[key] == true
			shown[#shown + 1] = option
		elseif not (option.child and hiding) then
			shown[#shown + 1] = option
		end
	end
	return shown
end

function Dropdown.default_collapsed(options, current)
	local collapsed = {}
	local group 
	local active 
	for i = 1, #options do
		local option = options[i]
		local key = Dropdown.group_key(option)
		if key then
			group = key
			collapsed[key] = true
		elseif group and Dropdown.is_selectable(option) and option.value == current then
			active = group
		end
	end
	if active then
		collapsed[active] = nil
	end
	return collapsed
end

function Dropdown.caret_rect(pr, oy, h)
	return { x = pr.x + TEXT_PAD, y = oy + ((h or OPTION_H) - CARET_CELL) / 2, w = CARET_CELL, h = CARET_CELL }
end

function Dropdown.selected_index(options, current)
	for i = 1, #options do
		local option = options[i]
		if Dropdown.is_selectable(option) and option.value == current then
			return i
		end
	end
	return nil
end

function Dropdown.centered_scroll(count, index)
	if not index then
		return 0
	end
	local scroll = index - math.ceil(MAX_VISIBLE / 2)
	return math.max(0, math.min(scroll, Dropdown.max_scroll(count)))
end

function Dropdown.max_scroll(count, heights)
	if not heights then
		return math.max(0, count - MAX_VISIBLE)
	end
	local window_h = MAX_VISIBLE * OPTION_H
	local sum = 0
	for i = count, 1, -1 do
		sum = sum + (heights[i] or OPTION_H)
		if sum > window_h then

			return i
		end
	end
	return 0
end

function Dropdown.row_heights(ui_renderer, options, w)
	local heights = {}
	for i = 1, #options do
		local option = options[i]
		local indent = Dropdown.row_indent(option)
		local text_w = TextMetrics.measure(ui_renderer, option.text)
		heights[i] = (text_w > w - TEXT_PAD * 2 - indent) and OPTION_H * 2 or OPTION_H
	end
	return heights
end

function Dropdown.row_layout(count, heights, scroll, window_h)
	local rows = {}
	local y = 0
	local i = (scroll or 0) + 1
	while i <= count do
		local h = (heights and heights[i]) or OPTION_H
		if y + h > window_h then

			break
		end
		rows[#rows + 1] = { index = i, y = y, h = h }
		y = y + h
		i = i + 1
	end
	return rows
end

function Dropdown.option_at(box, options, scroll, cx, cy, max_count, heights, search)
	scroll = scroll or 0
	local pr = Dropdown.popup_rect(box, #options, max_count, heights, search)
	if not (cx >= pr.x and cx <= pr.x + pr.w) then
		return nil, nil
	end
	local rows = Dropdown.row_layout(#options, heights, scroll, pr.window_h)
	for r = 1, #rows do
		local row = rows[r]
		local oy = pr.y + pr.rows_y + row.y
		if cy >= oy and cy <= oy + row.h then
			return row.index, options[row.index]
		end
	end
	return nil, nil
end

function Dropdown.is_group(option)
	return option ~= nil and option.group == true
end

function Dropdown.is_section(option)
	return option ~= nil and option.section == true
end

function Dropdown.is_selectable(option)
	return option ~= nil and option.value ~= nil and not option.group and not option.section
end

function Dropdown.row_indent(option)
	if Dropdown.is_group(option) then
		return CARET_CELL
	elseif option and option.child then
		return CHILD_INDENT
	end
	return 0
end

function Dropdown.draw(d, ctrl, parts, open, hovered, z)
	local box, arrow = parts.box, parts.arrow
	d:field_outline(box.x, box.y, box.x + box.w, box.y + box.h, z)
	d:rect(box.x, box.y, z, box.w, box.h, (open or hovered) and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)

	d:text_left_fit(
		Dropdown.selected_text(ctrl),
		CONTROL_SIZE,
		box.x + 4,
		box.y,
		z + 1,
		box.w - arrow.w - 6,
		box.h,
		COLOR.CTRL_TEXT,
		FONT,
		nil,
		TRIGGER_FIT_PAD
	)
	d:rect(arrow.x, arrow.y, z + 1, arrow.w, arrow.h, COLOR.STEP_BG)
	d:text_center("v", CONTROL_SIZE, arrow.x, arrow.y, z + 2, arrow.w, arrow.h, COLOR.STEP_TEXT, FONT)
end

local function draw_section_tree(d, oy, gutter_x, z, row_h)
	d:rect(gutter_x + CHILD_INDENT / 2, oy, z, 1, row_h or OPTION_H, TREE_COLOR)
end

local function draw_child_tree(d, oy, gutter_x, z, last, row_h)
	local half_h = (row_h or OPTION_H) / 2
	local half_w = CHILD_INDENT / 2
	local mid_x = gutter_x + half_w
	d:rect(mid_x, oy + half_h, z, half_w, 1, TREE_COLOR) 
	d:rect(mid_x, oy, z, 1, half_h, TREE_COLOR) 
	if not last then
		d:rect(mid_x, oy + half_h, z, 1, half_h, TREE_COLOR) 
	end
end

function Dropdown.draw_popup(
	d,
	box,
	options,
	hover_index,
	z,
	scroll,
	collapsed,
	selected_index,
	max_count,
	state,
	search
)
	scroll = scroll or 0
	local count = #options
	local w = box.w + POPUP_EXTRA_W

	local heights = state and Dropdown.row_heights(d.ui_renderer, options, w) or nil
	if state then
		state.row_h = heights
	end
	local pr = Dropdown.popup_rect(box, count, max_count, heights, search ~= nil)

	PanelBody.draw(d, pr, pr.h, z, {
		full = true,
	})

	if search then
		local sr = Dropdown.search_rect(pr)
		TextInput.draw(d, search.ctrl, sr, search.focused, false, z + 1)
		if search.ctrl.get() == "" then
			d:text_left(
				mod:localize("dropdown_search_hint"),
				CONTROL_SIZE,
				sr.x + 4,
				sr.y,
				z + 3,
				sr.w - 8,
				sr.h,
				COLOR.CTRL_TEXT_MUTED,
				FONT
			)
		end
	end

	local rows = Dropdown.row_layout(count, heights, scroll, pr.window_h)
	for r = 1, #rows do
		local row = rows[r]
		local i = row.index
		local option = options[i]
		local oy = pr.y + pr.rows_y + row.y
		if hover_index == i and not Dropdown.is_section(option) then
			d:rect(pr.x, oy, z + 1, pr.w, row.h, DROPDOWN_COLOR.DROPDOWN_OPTION_HOVER)
		elseif selected_index == i then

			d:rect(pr.x, oy, z + 1, pr.w, row.h, DROPDOWN_COLOR.DROPDOWN_OPTION_SELECTED)
		end
		local indent = Dropdown.row_indent(option)
		if Dropdown.is_section(option) then
			draw_section_tree(d, oy, pr.x + TEXT_PAD, z + 2, row.h)
		elseif option.child then
			local next_option = options[i + 1]
			local last = not (next_option and next_option.child)
			draw_child_tree(d, oy, pr.x + TEXT_PAD, z + 2, last, row.h)
		end
		local group_key = Dropdown.group_key(option)
		if group_key then

			local cell = Dropdown.caret_rect(pr, oy, row.h)
			d:caret(cell.x - 5, cell.y - 2, z + 5, not collapsed or collapsed[group_key] ~= true, COLOR.STEP_TEXT)
		end

		local text_color = COLOR.CTRL_TEXT
		if option.section then
			text_color = DROPDOWN_COLOR.DROPDOWN_SECTION_TEXT
		elseif option.group then
			text_color = COLOR.STEP_TEXT
		end
		d:text_left(
			option.text,
			option.section and 13 or CONTROL_SIZE,
			pr.x + TEXT_PAD + indent,
			oy,
			z + 2,
			pr.w - TEXT_PAD * 2 - indent,
			row.h,
			text_color,
			option.section and FONT_SECTION or FONT
		)
	end

	local max_scroll = Dropdown.max_scroll(count, heights)
	if max_scroll > 0 then
		local sb_x = pr.x + pr.w - SCROLLBAR_W - 1
		local sb_y = pr.y + pr.rows_y
		d:rect(sb_x, sb_y, z + 2, SCROLLBAR_W, pr.window_h, COLOR.CTRL_BG)
		local thumb_h = math.max(OPTION_H, pr.window_h * #rows / count)
		local frac = scroll / max_scroll
		d:rect(sb_x, sb_y + (pr.window_h - thumb_h) * frac, z + 2, SCROLLBAR_W, thumb_h, COLOR.SCROLL_THUMB)
	end

	d:outline(pr.x, pr.y, pr.x + pr.w, pr.y + pr.h, z + 6)
end

mod.hud_studio_dropdown_component = Dropdown

return Dropdown
