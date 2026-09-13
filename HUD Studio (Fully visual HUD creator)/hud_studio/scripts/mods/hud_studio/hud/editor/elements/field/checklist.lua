
local mod = get_mod("hud_studio")

if mod.hud_studio_checklist_component then
	return mod.hud_studio_checklist_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")

local COLOR = C.COLOR
local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local CAPTION_SIZE = 13

local LABEL_COL_W = C.PANEL.LABEL_COL_W

local LINE_H = 20
local INDICATOR = 12

local CAPTION_GAP = 5
local CELL_MARGIN = 14
local CHAR_W = 7

local Checklist = {}

Checklist.LINE_H = LINE_H

local function cell_width(text)
	return INDICATOR + CAPTION_GAP + math.ceil(#tostring(text or "") * CHAR_W) + CELL_MARGIN
end

function Checklist.parts(x, y, w, items, list_gap)
	local list_offset = LABEL_COL_W + (list_gap or 0)
	local list_x = x + list_offset
	local list_w = math.max(1, w - list_offset)

	local out = {}
	local col = 0 
	local row = 0
	items = items or {}
	for i = 1, #items do
		local it = items[i]
		local cw = math.min(cell_width(it.text), list_w)
		if col > 0 and col + cw > list_w then

			row = row + 1
			col = 0
		end
		out[#out + 1] = {
			value = it.value,
			box = { x = list_x + col, y = y + row * LINE_H, w = cw, h = LINE_H },
		}
		col = col + cw
	end

	local rows = (#items > 0) and (row + 1) or 1
	return {
		items = out,
		height = rows * LINE_H,
		label_rect = { x = x, y = y, w = LABEL_COL_W, h = LINE_H },
	}
end

function Checklist.draw(d, ctrl, parts, hovered, z)
	local lr = parts.label_rect
	d:text_left(ctrl.left_label or "", CAPTION_SIZE, lr.x, lr.y, z + 1, lr.w, lr.h, COLOR.CTRL_TEXT, FONT)

	for i = 1, #parts.items do
		local item = parts.items[i]
		local box = item.box
		local on = ctrl.is_on(item.value) and true or false

		local iy = box.y + (box.h - INDICATOR) / 2
		d:field_outline(box.x, iy, box.x + INDICATOR, iy + INDICATOR, z)
		d:rect(box.x, iy, z, INDICATOR, INDICATOR, hovered and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)
		local inset = 3
		d:rect(
			box.x + inset,
			iy + inset,
			z + 1,
			INDICATOR - inset * 2,
			INDICATOR - inset * 2,
			on and COLOR.CHECK_ON or COLOR.CHECK_OFF
		)

		local cx = box.x + INDICATOR + CAPTION_GAP
		d:text_left(
			ctrl.items[i].text,
			CAPTION_SIZE,
			cx,
			box.y,
			z + 1,
			box.x + box.w - cx,
			box.h,
			on and COLOR.CTRL_TEXT or COLOR.CTRL_TEXT_MUTED,
			FONT
		)
	end
end

mod.hud_studio_checklist_component = Checklist

return Checklist
