
local mod = get_mod("hud_studio")

if mod.panel_header_component then
	return mod.panel_header_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local CloseButton = mod:core(mod.close_button_component, "hud/editor/elements/button/close_button")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local TITLE_FONT = mod.dl.fonts.validated("proxima_nova_bold")
local TITLE_FONT_SIZE = 16
local GRADIENT = "content/ui/materials/gradients/gradient_vertical"

local COLOR = {
	TITLE_BAR = { 255, 66, 66, 66 }, 
	TITLE_BAR_ACTIVE = { 245, 50, 50, 50 }, 
	TITLE_TEXT = { 255, 255, 255, 255 },
	HR = { 255, 62, 62, 62 }, 
	GRADIENT_TOP = { 20, 255, 255, 255 }, 
	GRADIENT_BOTTOM = { 40, 0, 0, 0 }, 
}

local PanelHeader = {}

PanelHeader.TITLE_H = C.PANEL.TITLE_H
PanelHeader.PAD = C.PANEL.PAD
PanelHeader.CLOSE_W = C.PANEL.IDE_CLOSE_W

function PanelHeader.close_rect(panel)
	local size = PanelHeader.CLOSE_W
	return {
		x = panel.x + panel.w - size - 4,
		y = panel.y + math.floor((PanelHeader.TITLE_H - size) * 0.5),
		w = size,
		h = size,
	}
end

function PanelHeader.draw(d, panel, z, dragging, opts)
	local x, y, w = panel.x, panel.y, panel.w
	local title_h = PanelHeader.TITLE_H
	local title = (opts and opts.title) or panel.title

	local gradient_h = math.floor(title_h * 0.5)

	if MaterialDeps.ready_to_draw(GRADIENT) then
		d:texture(GRADIENT, x, y, z + 5, w, gradient_h, COLOR.GRADIENT_TOP, mod.dl.uv.flip_y())
		d:texture(GRADIENT, x, y + gradient_h, z + 5, w, gradient_h, COLOR.GRADIENT_BOTTOM)
	end

	d:rect(x, y, z + 1, w, title_h, dragging and COLOR.TITLE_BAR_ACTIVE or COLOR.TITLE_BAR)

	local title_w = w - PanelHeader.PAD * 2
	if opts and opts.close then
		title_w = title_w - PanelHeader.CLOSE_W
	end

	d:text_left_fit(
		title,
		TITLE_FONT_SIZE,
		x + PanelHeader.PAD,
		y,
		z + 2,
		title_w,
		title_h,
		COLOR.TITLE_TEXT,
		TITLE_FONT
	)

	if opts and opts.close then
		CloseButton.draw(d, PanelHeader.close_rect(panel), z + 6, { hover = opts.close.hover })
	end
end

mod.panel_header_component = PanelHeader

return PanelHeader
