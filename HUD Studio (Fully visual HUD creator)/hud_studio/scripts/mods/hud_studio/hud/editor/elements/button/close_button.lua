
local mod = get_mod("hud_studio")

if mod.close_button_component then
	return mod.close_button_component
end

local CursorState = mod:core(mod.cursor_state, "hud/editor/input/cursor_state")

local COLOR = {
	BG = { 255, 223, 48, 48 }, 
	BG_HOVER = { 255, 175, 30, 30 },
	TEXT = { 255, 255, 255, 255 },
}

local FONT = {
	X = mod.dl.fonts.validated("proxima_nova_bold"),
}

local GLYPH_SIZE = 13

local CloseButton = {}

function CloseButton.draw(d, rect, z, opts)
	opts = opts or {}

	local hover, clicked
	if opts.id then
		hover, clicked = CursorState.test(d, opts.id, rect.x, rect.y, rect.w, rect.h)
	else
		hover = opts.hover
	end

	d:rect(rect.x, rect.y, z + 1, rect.w, rect.h, hover and COLOR.BG_HOVER or COLOR.BG)
	d:text_center("X", GLYPH_SIZE, rect.x, rect.y, z + 2, rect.w, rect.h, COLOR.TEXT, FONT.X)

	if clicked and opts.on_click then
		opts.on_click()
	end

	return clicked or false
end

mod.close_button_component = CloseButton

return CloseButton
