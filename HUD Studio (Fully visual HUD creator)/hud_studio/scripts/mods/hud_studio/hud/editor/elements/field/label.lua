
local mod = get_mod("hud_studio")

if mod.hud_studio_label_component then
	return mod.hud_studio_label_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local PAD = C.PANEL.PAD
local NOTE_LINE_H = C.PANEL.NOTE_LINE_H
local SECTION_FONT = mod.dl.fonts.validated("proxima_nova_bold")
local FONT = mod.dl.fonts.validated("proxima_nova_medium")

local COLOR = {
	TITLE_BAR = { 255, 66, 66, 66 }, 
	GRADIENT_TOP = { 20, 255, 255, 255 },
	GRADIENT_BOTTOM = { 40, 0, 0, 0 },
	FIELD_LABEL = { 255, 255, 255, 255 },
	NOTE_TEXT = { 255, 190, 190, 190 },
	CTRL_TEXT = { 255, 255, 255, 255 },
	CTRL_TEXT_MUTED = { 255, 200, 200, 200 },
	SECTION_BG_HOVER = { 255, 56, 56, 56 },
	SECTION_BG = { 255, 66, 66, 66 },
	SECTION_TEXT = { 255, 230, 230, 242 },
}

local GRADIENT = "content/ui/materials/gradients/gradient_vertical"

local FIELD_SIZE = 12 
local CONTROL_SIZE = 14 
local NOTE_SIZE = 13 
local GROUP_SIZE = 12

local SIDE_LABEL_SIZE = 13
local SECTION_SIZE = 12

local Label = {}

function Label.field(d, rect, text, z)
	d:text_left(text, FIELD_SIZE, rect.x, rect.y + 1, z, rect.w, FIELD_SIZE, COLOR.FIELD_LABEL, FONT)
end

function Label.readonly(d, cr, text, z)
	d:text_left(text, CONTROL_SIZE, cr.x, cr.y, z, cr.w, cr.h, COLOR.CTRL_TEXT_MUTED, FONT)
end

function Label.note(d, cr, text, z, lines)
	if not lines then
		d:text_left(text, NOTE_SIZE, cr.x, cr.y, z, cr.w, NOTE_SIZE, COLOR.NOTE_TEXT, FONT)
		return
	end
	for i = 1, #lines do
		local line_y = cr.y + (i - 1) * NOTE_LINE_H
		d:text_left(lines[i], NOTE_SIZE, cr.x, line_y, z, cr.w, NOTE_LINE_H, COLOR.NOTE_TEXT, FONT)
	end
end

function Label.group(d, x, y, w, text, z, box_h)
	if not box_h then
		d:text_left(text, GROUP_SIZE, x, y, z, w, GROUP_SIZE, COLOR.CTRL_TEXT, FONT)
		return
	end

	local text_y = y + math.floor((box_h - SIDE_LABEL_SIZE) * 0.5)
	d:text_left_fit(text, SIDE_LABEL_SIZE, x, text_y, z, w, SIDE_LABEL_SIZE, C.COLOR.CTRL_TEXT, FONT, nil, 0)
end

function Label.section_header(d, it, hovered, z)

	local gradient_h = math.floor(it.h * 0.3)

	if MaterialDeps.ready_to_draw(GRADIENT) then
		d:texture(GRADIENT, it.x, it.y, z + 5, it.w, gradient_h, COLOR.GRADIENT_BOTTOM, mod.dl.uv.flip_y())
		d:texture(GRADIENT, it.x, it.y + (it.h * 0.7), z + 5, it.w, gradient_h, COLOR.GRADIENT_BOTTOM)
	end

	d:rect(it.x, it.y, z, it.w, it.h, hovered and COLOR.SECTION_BG_HOVER or COLOR.SECTION_BG)

	d:caret(it.x, it.y, z + 5, it.open, COLOR.SECTION_TEXT)
	d:text_left(
		it.title,
		SECTION_SIZE,
		it.x + PAD + 14,
		it.y,
		z + 1,
		it.w - PAD * 2 - 16,
		it.h,
		COLOR.SECTION_TEXT,
		SECTION_FONT
	)
end

mod.hud_studio_label_component = Label

return Label
