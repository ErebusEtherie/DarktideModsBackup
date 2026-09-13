
local mod = get_mod("hud_studio")

if mod.hud_studio_rgba_component then
	return mod.hud_studio_rgba_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Tooltip = mod:core(mod.tooltip_component, "hud/editor/elements/tooltip/tooltip")

local COLOR = C.COLOR
local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local LABEL_SIZE = 13
local GAP = 6

local Rgba = {}

function Rgba.parts(x, y, w, h)
	local paste_x = x + w - h
	local text_x = x + h + GAP
	return {
		swatch = { x = x, y = y, w = h, h = h },
		text = { x = text_x, y = y, w = paste_x - GAP - text_x, h = h },
		paste = { x = paste_x, y = y, w = h, h = h },
	}
end

function Rgba.draw(d, ctrl, parts, ctx, z)
	local sw = parts.swatch
	local color = ctrl.get()
	d:rect(sw.x, sw.y, z, sw.w, sw.h, color or { 255, 255, 255, 255 })

	local label = color and string.format("A%d R%d G%d B%d", color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0)
		or "unset"

	local text = parts.text
	local copy_hover = color ~= nil and ctx.copy_hover
	d:text_left(
		label,
		LABEL_SIZE,
		text.x,
		text.y,
		z + 1,
		text.w,
		text.h,
		copy_hover and COLOR.CTRL_TEXT_HOVER or COLOR.CTRL_TEXT_MUTED,
		FONT
	)
	if copy_hover then
		Tooltip.draw(d, mod:localize("color_picker_copy_tooltip"))
	end

	local paste = parts.paste
	d:text_center(
		"P",
		LABEL_SIZE,
		paste.x,
		paste.y,
		z + 1,
		paste.w,
		paste.h,
		ctx.paste_hover and COLOR.CTRL_TEXT_HOVER or COLOR.CTRL_TEXT_MUTED,
		FONT
	)
	if ctx.paste_hover then
		Tooltip.draw(d, mod:localize("color_picker_paste_tooltip"))
	end
end

mod.hud_studio_rgba_component = Rgba

return Rgba
