
local mod = get_mod("hud_studio")

if mod.tooltip_component then
	return mod.tooltip_component
end

local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local HudScale = mod:core(mod.hud_studio_scale, "blocks/hud_scale")

local TOOLTIP_Z = 800

local COLOR = {
	FILL = { 235, 20, 20, 20 },
	BORDER = { 255, 0, 0, 0 },
	TEXT = { 255, 232, 232, 232 },
}

local TEXT_SIZE = 14
local PADDING_X = 8
local PADDING_Y = 5
local CURSOR_OFFSET_X = 14 
local CURSOR_OFFSET_Y = 18

local GLYPH_WIDTH = TEXT_SIZE * 0.43

local Tooltip = {}

function Tooltip.draw(d, label)
	if not label or label == "" then
		return
	end

	local w = TextMetrics.measure(d.ui_renderer, label)

	local boxWidth = w + (PADDING_X * 2)
	local boxHeight = 22
	local boxX = d.cx + CURSOR_OFFSET_X
	local boxY = d.cy + CURSOR_OFFSET_Y

	local x_max = (RESOLUTION_LOOKUP.width * HudScale.pct()) - CURSOR_OFFSET_X - boxWidth
	if boxX >= x_max then
		boxX = d.cx - boxWidth - CURSOR_OFFSET_X
	end
	local y_max = (RESOLUTION_LOOKUP.height * HudScale.pct()) - CURSOR_OFFSET_Y - boxHeight
	if boxY >= y_max then
		boxY = d.cy - boxHeight - CURSOR_OFFSET_Y
	end

	d:rect(boxX - 1, boxY - 1, TOOLTIP_Z, boxWidth + 2, boxHeight + 2, COLOR.BORDER)
	d:rect(boxX, boxY, TOOLTIP_Z + 1, boxWidth, boxHeight, COLOR.FILL)
	d:text_left(label, TEXT_SIZE, boxX + PADDING_X, boxY, TOOLTIP_Z + 2, boxWidth, boxHeight, COLOR.TEXT)
end

mod.tooltip_component = Tooltip

return Tooltip
