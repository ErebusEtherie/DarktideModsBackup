
local mod = get_mod("hud_studio")

if mod.hud_studio_text_input_component then
	return mod.hud_studio_text_input_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local Caret = mod:core(mod.hud_studio_caret_component, "hud/editor/elements/field/caret")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")
local Format = mod:core(mod.editor_format, "hud/editor/format")

local COLOR = C.COLOR
local PANEL = C.PANEL

local FONT = TextMetrics.FONT
local CONTROL_SIZE = TextMetrics.CONTROL_FONT_SIZE
local EMPTY = {}

local NO_WRAP_W = 100000

local GRAD_MATERIAL = "content/ui/materials/gradients/gradient_horizontal"
local GRAD_W = 40
local GRAD_UV_RIGHT = { { 0, 0 }, { 1, 1 } }
local GRAD_UV_LEFT = { { 1, 0 }, { 0, 1 } }

local TextInput = {}

function TextInput.parts(x, y, w, h)
	return { box = { x = x, y = y, w = w, h = h } }
end

function TextInput.draw_multiline(d, ctrl, box, focused, z, opts)
	opts = opts or EMPTY

	if opts.bg then
		d:rect(box.x, box.y, z, box.w, box.h, opts.bg)
	end
	local format = opts.format

	local ui = d.ui_renderer
	local left = box.x + 4
	local top = box.y + PANEL.MULTILINE_PAD
	local lh = PANEL.MULTILINE_LINE_H
	local inner_w = box.w - 8

	local rows
	if focused then

		TextMetrics.wrap_width(ui, inner_w)
		rows = TextField.visual_rows()
	else
		rows = TextField.wrap_text(Format.value(ctrl.get()), TextMetrics.wrap_width(ui, inner_w))
	end

	local hover_row
	if
		(opts.hover_bg or opts.hover_caret)
		and d.cx
		and d.cy
		and d.cx >= box.x
		and d.cx <= box.x + box.w
		and d.cy >= top
		and d.cy < top + #rows * lh
	then
		local row = math.floor((d.cy - top) / lh) + 1
		if row >= 1 and row <= #rows then
			hover_row = row
			if opts.hover_bg then
				d:rect(box.x, top + (hover_row - 1) * lh, z, box.w, lh, opts.hover_bg)
			end
		end
	end
	if focused and opts.active_bg then
		local active_row = TextField.caret_rc()
		d:rect(box.x, top + (active_row - 1) * lh, z, box.w, lh, opts.active_bg)
	end

	local empty = (#rows == 1 and rows[1] == "")
	local color = (empty and not focused) and COLOR.CTRL_TEXT_MUTED or COLOR.CTRL_TEXT

	if focused then
		for r = 1, #rows do
			local slo, shi = TextField.selection_on_row(r)
			if slo then
				local ry = top + (r - 1) * lh
				local xlo = TextMetrics.row_col_x(ui, rows[r], slo)
				local xhi = TextMetrics.row_col_x(ui, rows[r], shi)
				Caret.selection_rect(d, left + xlo, ry, xhi - xlo, lh, z)
			end
		end
	end

	for r = 1, #rows do

		local line = format and format(rows[r]) or rows[r]
		d:text_left(line, CONTROL_SIZE, left, top + (r - 1) * lh, z + 1, inner_w, CONTROL_SIZE, color, FONT)
	end

	if hover_row and opts.hover_caret then
		local hover_col = TextMetrics.row_col_at_x(ui, rows[hover_row], left, d.cx)
		Caret.ghost_bar(
			d,
			left + TextMetrics.row_col_x(ui, rows[hover_row], hover_col),
			top + (hover_row - 1) * lh,
			lh,
			z + 2
		)
	end

	if focused then
		local cr, cc = TextField.caret_rc()
		Caret.bar(d, left + TextMetrics.row_col_x(ui, rows[cr] or "", cc), top + (cr - 1) * lh, lh, z + 2)
	end
end

function TextInput.draw(d, ctrl, box, focused, hovered, z, opts)
	opts = opts or EMPTY
	local lit = focused or hovered
	local bg = lit and (opts.bg_hover or COLOR.CTRL_BG_HOVER) or (opts.bg or COLOR.CTRL_BG)
	d:rect(box.x, box.y, z, box.w, box.h, bg)
	d:field_outline(box.x, box.y, box.x + box.w, box.y + box.h, z)

	if ctrl.multiline then

		TextInput.draw_multiline(d, ctrl, box, focused, z, { format = opts.format })
		return
	end

	local text = focused and TextField.text() or Format.value(ctrl.get())
	local empty = (text == "" and not focused)
	local color = empty and COLOR.CTRL_TEXT_MUTED or COLOR.CTRL_TEXT

	local left = box.x + 4
	local inner_w = box.w - 8
	local scroll_x = 0
	if focused then

		local ui = d.ui_renderer
		local caret_px = TextMetrics.measure(ui, TextField.text_before_caret())
		scroll_x = TextField.scroll_x()
		if caret_px < scroll_x then
			scroll_x = caret_px
		elseif caret_px > scroll_x + inner_w then
			scroll_x = caret_px - inner_w
		end
		local max_scroll = TextMetrics.measure(ui, text) - inner_w
		if max_scroll < 0 then
			max_scroll = 0
		end
		if scroll_x > max_scroll then
			scroll_x = max_scroll
		end
		if scroll_x < 0 then
			scroll_x = 0
		end
		TextField.set_scroll_x(scroll_x)

		Caret.selection_and_caret(d, box, left - scroll_x, z)
	end

	local slice, dx, clipped_left, clipped_right = TextMetrics.visible_window(d.ui_renderer, text, scroll_x, inner_w)
	local drawn = (opts.format and not empty) and opts.format(slice) or slice

	d:text_left(drawn, CONTROL_SIZE, left + dx - scroll_x, box.y, z + 1, NO_WRAP_W, box.h, color, FONT)

	if MaterialDeps.ready_to_draw(GRAD_MATERIAL) then
		if clipped_left then
			d:texture(GRAD_MATERIAL, box.x, box.y, z + 3, GRAD_W, box.h, bg, GRAD_UV_LEFT)
		end
		if clipped_right then
			d:texture(GRAD_MATERIAL, box.x + box.w - GRAD_W, box.y, z + 3, GRAD_W, box.h, bg, GRAD_UV_RIGHT)
		end
	end
end

mod.hud_studio_text_input_component = TextInput

return TextInput
