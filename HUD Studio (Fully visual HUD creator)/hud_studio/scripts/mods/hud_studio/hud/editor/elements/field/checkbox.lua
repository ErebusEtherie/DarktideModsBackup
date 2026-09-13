
local mod = get_mod("hud_studio")

if mod.hud_studio_checkbox_component then
	return mod.hud_studio_checkbox_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")

local COLOR = C.COLOR
local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local CONTROL_SIZE = 14

local INNER_INSET = 5

local LABEL_GAP = 6

local Checkbox = {}

function Checkbox.parts(x, y, w, h)
	return { box = { x = x, y = y, w = w, h = h } }
end

function Checkbox.draw(d, ctrl, parts, hovered, z)
	local box = parts.box
	local on = ctrl.get() and true or false

	d:field_outline(box.x, box.y, box.x + box.w, box.y + box.h, z)
	d:rect(box.x, box.y, z, box.w, box.h, hovered and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)

	local side = box.h - INNER_INSET * 2
	local inner_x = box.x + INNER_INSET
	local inner_y = box.y + INNER_INSET
	d:rect(inner_x, inner_y, z + 1, side, side, on and COLOR.CHECK_ON or COLOR.CHECK_OFF)

	local label_x = inner_x + side + LABEL_GAP
	d:text_left(
		on and "On" or "Off",
		CONTROL_SIZE,
		label_x,
		box.y,
		z + 1,
		box.x + box.w - label_x,
		box.h,
		COLOR.CTRL_TEXT,
		FONT
	)
end

mod.hud_studio_checkbox_component = Checkbox

return Checkbox
