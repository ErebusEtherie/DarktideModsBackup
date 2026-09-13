
local mod = get_mod("hud_studio")

if mod.hud_studio_caret_component then
	return mod.hud_studio_caret_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")

local COLOR = {
	SELECTION = { 150, 90, 130, 210 },
	CARET = { 255, 255, 255, 255 }, 
	CARET_GHOST = { 100, 255, 255, 255 }, 
}
local CARET_W = C.PANEL.CARET_W

local Caret = {}

Caret.CARET_W = CARET_W

function Caret.selection_and_caret(d, box, left_x, z)
	local ui = d.ui_renderer
	local x0 = box.x + 4
	local x1 = box.x + box.w - 4
	local lo, hi = TextField.selection_range()
	if lo then
		local xlo = math.max(x0, TextMetrics.caret_x(ui, left_x, lo))
		local xhi = math.min(x1, TextMetrics.caret_x(ui, left_x, hi))
		if xhi > xlo then
			d:rect(xlo, box.y + 3, z, xhi - xlo, box.h - 6, COLOR.SELECTION)
		end
	end
	local caret_x = TextMetrics.caret_x(ui, left_x, TextField.caret())
	if caret_x >= x0 and caret_x <= x1 then
		d:rect(caret_x, box.y + 3, z + 2, CARET_W, box.h - 6, COLOR.CARET)
	end
end

function Caret.selection_rect(d, x, y, w, h, z)
	d:rect(x, y, z, math.max(1, w), h, COLOR.SELECTION)
end

function Caret.bar(d, x, y, h, z)
	d:rect(x, y, z, CARET_W, h, COLOR.CARET)
end

function Caret.ghost_bar(d, x, y, h, z)
	d:rect(x, y, z, CARET_W, h, COLOR.CARET_GHOST)
end

mod.hud_studio_caret_component = Caret

return Caret
