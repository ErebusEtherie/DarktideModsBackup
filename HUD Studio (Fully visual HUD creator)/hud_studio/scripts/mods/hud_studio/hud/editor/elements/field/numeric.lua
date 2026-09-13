
local mod = get_mod("hud_studio")

if mod.hud_studio_numeric_component then
	return mod.hud_studio_numeric_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local Caret = mod:core(mod.hud_studio_caret_component, "hud/editor/elements/field/caret")
local Format = mod:core(mod.editor_format, "hud/editor/format")

local COLOR = C.COLOR
local STEP_W = C.PANEL.STEP_W
local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local CONTROL_SIZE = 14

local Numeric = {}

Numeric.STEP_W = STEP_W

function Numeric.parts(x, y, w, h)
	local bw = STEP_W
	return {
		minus = { x = x, y = y, w = bw, h = h },
		plus = { x = x + w - bw, y = y, w = bw, h = h },
		value = { x = x + bw, y = y, w = w - bw * 2, h = h },
	}
end

function Numeric.draw(d, ctrl, parts, focused, hovered, z)
	local minus, plus, box = parts.minus, parts.plus, parts.value

	local sum_w = minus.w + plus.w + box.w

	d:field_outline(minus.x, minus.y, minus.x + sum_w, minus.y + minus.h, z)

	d:rect(minus.x, minus.y, z, minus.w, minus.h, COLOR.STEP_BG)
	d:text_center("-", CONTROL_SIZE, minus.x, minus.y, z + 1, minus.w, minus.h, COLOR.STEP_TEXT, FONT)
	d:rect(plus.x, plus.y, z, plus.w, plus.h, COLOR.STEP_BG)
	d:text_center("+", CONTROL_SIZE, plus.x, plus.y, z + 1, plus.w, plus.h, COLOR.STEP_TEXT, FONT)

	d:rect(box.x, box.y, z, box.w, box.h, (focused or hovered) and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)
	if focused then

		Caret.selection_and_caret(d, box, box.x + 4, z)
		d:text_left(TextField.text(), CONTROL_SIZE, box.x + 4, box.y, z + 1, box.w - 8, box.h, COLOR.CTRL_TEXT, FONT)
	else

		d:text_center(Format.number(ctrl.get() or 0), CONTROL_SIZE, box.x, box.y, z + 1, box.w, box.h, COLOR.CTRL_TEXT, FONT)
	end
end

mod.hud_studio_numeric_component = Numeric

return Numeric
