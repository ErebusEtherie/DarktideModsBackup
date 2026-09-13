---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_condition_builder then
	return mod.hud_studio_condition_builder
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local PANEL = C.PANEL

---@class ConditionBuilder
local ConditionBuilder = {}

local TITLE_H = 26
local PAD = 8

local ROW_H = 24
local ROW_GAP = 6

local PILL_W = 12 
local PILL_INDENT = 3
local PILL_GAP = 6
local JOIN_W = 56 
local NOT_W = 54 
local OP_W = 100 
local DEL_W = 20 
local CELL_GAP = 6

local FOOTER_LABEL_W = 110
local FOOTER_NUM_W = 56
local FOOTER_GAP = 14
local BUTTON_H = 22

ConditionBuilder.TITLE_H = TITLE_H
ConditionBuilder.PAD = PAD
ConditionBuilder.ROW_H = ROW_H
ConditionBuilder.PILL_W = PILL_W

ConditionBuilder.MAX_ROWS = 10

---@param x number
---@param y number
---@param w number
---@param arity integer
---@param first boolean   this is row 1 (no join cell)
---@return table cells { pill, join?, where?, lhs, negate, op, rhs?, rhs2?, remove }
function ConditionBuilder.row_cells(x, y, w, arity, first)
	local cx = x
	local function take(cell_w)
		local r = { x = cx, y = y, w = cell_w, h = ROW_H }
		cx = cx + cell_w + CELL_GAP
		return r
	end

	local pill = { x = cx + PILL_INDENT, y = y + 2, w = PILL_W, h = ROW_H - 4 }
	cx = cx + PILL_W + PILL_GAP + PILL_GAP

	local join = take(JOIN_W)
	local where = nil
	if first then
		join, where = nil, join
	end

	local right_edge = x + w
	local remove = { x = right_edge - DEL_W, y = y, w = DEL_W, h = ROW_H }
	local free = right_edge - DEL_W - CELL_GAP - cx - (NOT_W + CELL_GAP) - (OP_W + CELL_GAP)
	local operand_count = 1 + arity
	local operand_w = math.floor((free - CELL_GAP * (operand_count - 1)) / operand_count)

	local lhs = take(operand_w)
	local negate = take(NOT_W)
	local op = take(OP_W)
	local rhs, rhs2 = nil, nil
	if arity >= 1 then

		rhs = arity == 1 and { x = cx, y = y, w = right_edge - DEL_W - CELL_GAP - cx, h = ROW_H } or take(operand_w)
	end
	if arity >= 2 then
		rhs2 = { x = cx, y = y, w = right_edge - DEL_W - CELL_GAP - cx, h = ROW_H }
	end

	return {
		pill = pill,
		join = join,
		where = where,
		negate = negate,
		lhs = lhs,
		op = op,
		rhs = rhs,
		rhs2 = rhs2,
		remove = remove,
	}
end

---@param x number
---@param y number
---@param w number
---@param rows table[]  { { arity = integer, expanded_h = number }, ... }
---@return table layout
function ConditionBuilder.layout(x, y, w, rows)
	local content_x = x + PAD
	local content_w = w - PAD * 2
	local cy = y + TITLE_H + PAD

	local out_rows = {}
	for i = 1, #rows do
		local spec = rows[i]
		local cells = ConditionBuilder.row_cells(content_x, cy, content_w, spec.arity or 0, i == 1)
		cy = cy + ROW_H
		local expanded = nil
		local expanded_h = spec.expanded_h or 0
		if expanded_h > 0 then

			local function column(cell)
				return cell and { x = cell.x, y = cy, w = cell.w, h = expanded_h } or nil
			end
			expanded = { h = expanded_h, lhs = column(cells.lhs), rhs = column(cells.rhs), rhs2 = column(cells.rhs2) }
			cy = cy + expanded_h
		end
		out_rows[i] = { cells = cells, expanded = expanded }
		cy = cy + ROW_GAP
	end
	cy = cy - ROW_GAP + PAD

	local add = { x = content_x, y = cy, w = content_w, h = BUTTON_H }
	cy = cy + BUTTON_H + PAD

	local footer_y = cy
	local linger = {
		label = { x = content_x, y = footer_y, w = FOOTER_LABEL_W, h = ROW_H },
		ctrl = { x = content_x + FOOTER_LABEL_W, y = footer_y, w = FOOTER_NUM_W, h = ROW_H },
	}
	local delay_x = content_x + FOOTER_LABEL_W + FOOTER_NUM_W + FOOTER_GAP
	local delay = {
		label = { x = delay_x, y = footer_y, w = FOOTER_LABEL_W, h = ROW_H },
		ctrl = { x = delay_x + FOOTER_LABEL_W, y = footer_y, w = FOOTER_NUM_W, h = ROW_H },
	}
	cy = cy + ROW_H + PAD

	return {
		frame = { x = x, y = y, w = w, h = cy - y },
		title = { x = x, y = y, w = w, h = TITLE_H },
		rows = out_rows,
		add = add,
		linger = linger,
		delay = delay,
	}
end

---@param group table|nil
---@param items table|nil    appended to; nil measures only
---@param labels table|nil   appended to; the control label lines
---@return number height
function ConditionBuilder.stack_operand(group, x, y, w, items, labels)
	if not group then
		return 0
	end
	local top = y

	local stack = { group.mode }
	for i = 1, #group.controls do
		local ctrl = group.controls[i]
		if not (ctrl.hidden and ctrl.hidden()) then
			stack[#stack + 1] = ctrl
		end
	end

	for i = 1, #stack do
		local ctrl = stack[i]
		if ctrl.label ~= nil and ctrl.label ~= "" then
			if labels then
				labels[#labels + 1] = { x = x, y = y, w = w, h = PANEL.FIELD_LABEL_H, text = ctrl.label }
			end
			y = y + PANEL.FIELD_LABEL_H
		end
		if items then
			items[#items + 1] = {
				t = "field",
				ctrl = ctrl,
				ctrl_rect = { x = x, y = y, w = w, h = PANEL.FIELD_H },

				label_rect = { x = x, y = y, w = w, h = 0 },
			}
		end
		y = y + PANEL.FIELD_H + PANEL.FIELD_GAP
	end

	return y - top
end

mod.hud_studio_condition_builder = ConditionBuilder

return ConditionBuilder
