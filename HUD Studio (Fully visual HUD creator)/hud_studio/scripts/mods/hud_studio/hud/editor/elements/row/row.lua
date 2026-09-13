
local mod = get_mod("hud_studio")

if mod.row_component then
	return mod.row_component
end

local Swatch = mod:core(mod.swatch_component, "hud/editor/elements/row/swatch")
local EyeToggle = mod:core(mod.eye_toggle_component, "hud/editor/elements/row/eye_toggle")
local CursorState = mod:core(mod.cursor_state, "hud/editor/input/cursor_state")
local Tooltip = mod:core(mod.tooltip_component, "hud/editor/elements/tooltip/tooltip")
local EditorIcons = mod:core(mod.editor_icons, "hud/editor/elements/icon/editor_icons")

local ROW_FONT_SIZE = 13
local CHIP_FONT_SIZE = 12 
local CHIP_STACK_FONT_SIZE = 11 
local LABEL_FONT = mod.dl.fonts.validated("arial")

local GEO = {
	ROW_H = 30,
	ROW_INDENT = 28,
	SWATCH_PAD = 6,
	SWATCH_SIZE = 0, 
	CHIP_W = 62, 
	CHIP_H = 16,

	CHIP_STACK_H = 13,
	CHIP_GAP = 6, 
	ROW_INDENT_HALF = 0,
	ROW_H_HALF = 0,
}

GEO.SWATCH_SIZE = GEO.ROW_H - math.floor(GEO.SWATCH_PAD * 2)
GEO.ROW_H_HALF = GEO.ROW_H / 2
GEO.ROW_INDENT_HALF = GEO.ROW_INDENT / 2

local COLOR = {
	TEXT = { 255, 255, 255, 255 },
	TREE = { 255, 120, 120, 120 },
	NORMAL = { 255, 83, 83, 83 },
	HOVER = { 255, 100, 100, 100 },
	SELECTED = { 255, 107, 107, 107 },

	CHIP = { 255, 250, 190, 90 },
}

local Row = {}

Row.ROW_H = GEO.ROW_H
Row.ROW_INDENT = GEO.ROW_INDENT

local CARET_HALF = 12.5
local FOLDER_HALF = 15

function Row.caret_rect(x, row_y, indent)
	return {
		x = x + (indent or 0) + GEO.SWATCH_PAD,
		y = row_y + GEO.SWATCH_PAD,
		w = GEO.SWATCH_SIZE,
		h = GEO.SWATCH_SIZE,
	}
end

function Row.label_rect(x, row_y, w, indent, has_eye, has_chip)
	local swatch_x = x + (indent or 0) + GEO.SWATCH_PAD
	local label_x = swatch_x + GEO.SWATCH_SIZE + GEO.SWATCH_PAD
	local eye_reserve = has_eye and (EyeToggle.SIZE + EyeToggle.RIGHT_PAD + GEO.SWATCH_PAD) or 0
	local chip_reserve = has_chip and (GEO.CHIP_W + GEO.CHIP_GAP) or 0
	return {
		x = label_x,
		y = row_y,
		w = w - (label_x - x) - GEO.SWATCH_PAD - eye_reserve - chip_reserve,
		h = GEO.ROW_H,
	}
end

function Row.chip_rect(x, row_y, w, index, count)
	count = count or 1
	index = index or 1
	local eye = EyeToggle.rect(x, row_y, w, GEO.ROW_H)
	local h = count > 1 and GEO.CHIP_STACK_H or GEO.CHIP_H
	local stack_h = h * count
	return {
		x = eye.x - GEO.CHIP_GAP - GEO.CHIP_W,
		y = row_y + math.floor((GEO.ROW_H - stack_h) / 2) + (index - 1) * h,
		w = GEO.CHIP_W,
		h = h,
	}
end

function Row.draw(d, x, row_y, w, z, opts)
	local indent = opts.indent or 0

	local fill = (opts.selected and COLOR.SELECTED) or (opts.hovered and COLOR.HOVER) or COLOR.NORMAL
	local fill_x = x + indent
	d:rect(fill_x, row_y, z + 1, w - indent, GEO.ROW_H, fill)
	d:outline(fill_x, row_y, x + w, row_y + GEO.ROW_H, z + 10)

	local swatch_x = fill_x + GEO.SWATCH_PAD
	local swatch_y = row_y + GEO.SWATCH_PAD
	if opts.caret then

		d:caret(
			swatch_x + GEO.SWATCH_SIZE / 2 - CARET_HALF,
			swatch_y + GEO.SWATCH_SIZE / 2 - CARET_HALF,
			z + 2,
			opts.caret.open,
			COLOR.TEXT
		)
	elseif opts.folder then
		EditorIcons.draw_folder_icon(
			d,
			swatch_x + GEO.SWATCH_SIZE / 2 - FOLDER_HALF,
			swatch_y + GEO.SWATCH_SIZE / 2 - FOLDER_HALF + 2,
			z,
			false,
			nil,
			opts.folder.open
		)
	elseif opts.swatch then
		Swatch.draw(d, opts.swatch, swatch_x, swatch_y, z + 2, GEO.SWATCH_SIZE)
	end

	if opts.tree then

		local trunks = opts.tree.trunks
		if trunks then
			for level = 1, #trunks do
				if trunks[level] then
					d:rect(
						x + (level - 1) * GEO.ROW_INDENT + GEO.ROW_INDENT_HALF,
						row_y,
						z + 5,
						1,
						GEO.ROW_H,
						COLOR.TREE
					)
				end
			end
		end

		local stem_x = fill_x - GEO.ROW_INDENT_HALF

		d:rect(stem_x, row_y + GEO.ROW_H_HALF, z + 5, GEO.ROW_INDENT_HALF, 1, COLOR.TREE)

		d:rect(stem_x, row_y, z + 5, 1, GEO.ROW_H_HALF, COLOR.TREE)
		if not opts.tree.last then

			d:rect(stem_x, row_y + GEO.ROW_H_HALF, z + 5, 1, GEO.ROW_H_HALF, COLOR.TREE)
		end
	end

	if not opts.editing then
		local lr = Row.label_rect(x, row_y, w, indent, opts.eye ~= nil, opts.chip ~= nil or opts.chips ~= nil)
		d:text_left(opts.label, ROW_FONT_SIZE, lr.x, lr.y, z + 2, lr.w, lr.h, COLOR.TEXT, LABEL_FONT)
	end

	local chips = opts.chips
	if chips or opts.chip then
		local list = chips or { opts.chip }
		local count = 0
		for c = 1, #list do
			if list[c] and list[c].show then
				count = count + 1
			end
		end
		local index = 0
		for c = 1, #list do
			local chip = list[c]
			if chip and chip.show then
				index = index + 1
				local cr = Row.chip_rect(x, row_y, w, index, count)

				local draw_text = count > 1 and d.text_center or d.text_left
				draw_text(
					d,
					chip.text,
					count > 1 and CHIP_STACK_FONT_SIZE or CHIP_FONT_SIZE,
					cr.x,
					cr.y,
					z + 2,
					cr.w,
					cr.h,
					chip.color or COLOR.CHIP,
					LABEL_FONT
				)
				if chip.tooltip and CursorState.test(d, chip.id, cr.x, cr.y, cr.w, cr.h) then
					Tooltip.draw(d, chip.tooltip)
				end
			end
		end
	end

	if opts.eye then
		EyeToggle.draw(d, opts.eye.id, EyeToggle.rect(x, row_y, w, GEO.ROW_H), z + 6, opts.eye)
	end
end

mod.row_component = Row

return Row
