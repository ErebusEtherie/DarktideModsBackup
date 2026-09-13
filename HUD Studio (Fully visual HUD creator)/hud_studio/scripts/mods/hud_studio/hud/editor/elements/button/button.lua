
local mod = get_mod("hud_studio")

if mod.hud_studio_button_component then
	return mod.hud_studio_button_component
end

local CursorState = mod:core(mod.cursor_state, "hud/editor/input/cursor_state")
local Tooltip = mod:core(mod.tooltip_component, "hud/editor/elements/tooltip/tooltip")

local COLOR = {
	NORMAL = { 255, 69, 69, 69 },
	HOVER = { 235, 48, 48, 48 },
	PRESSED = { 255, 112, 112, 112 },
	BORDER = { 255, 20, 20, 20 },
	TEXT = { 255, 232, 232, 232 },
	DISABLED = { 255, 34, 34, 34 },
	DISABLED_TEXT = { 255, 110, 110, 110 },
}

local FONT = mod.dl.fonts.validated("proxima_nova_bold")
local TEXT_PAD = 6

local Button = {}

function Button.draw(d, id, x, y, z, w, h, label, opts)
	opts = opts or {}

	if opts.disabled then
		d:rect(x, y, z + 1, w, h, opts.disabled_color or COLOR.DISABLED)
		if label then
			d:text_center_fit(
				label,
				opts.text_size or 13,
				x,
				y,
				z + 2,
				w,
				h,
				opts.disabled_text_color or COLOR.DISABLED_TEXT,
				opts.font_type or FONT,
				nil,
				TEXT_PAD
			)
		end
		d:field_outline(x, y, x + w, y + h, z)

		return false
	end

	local hovered, clicked, held = CursorState.test(d, id, x, y, w, h)

	local fill = (held and hovered and (opts.pressed or COLOR.PRESSED))
		or (hovered and (opts.hover or COLOR.HOVER))
		or (opts.color or COLOR.NORMAL)

	d:rect(x, y, z + 1, w, h, fill)
	if label then
		d:text_center_fit(
			label,
			opts.text_size or 13,
			x,
			y,
			z + 2,
			w,
			h,
			opts.text_color or COLOR.TEXT,
			opts.font_type or FONT,
			nil,
			TEXT_PAD
		)
	end
	if opts.material and opts.material.path or type(opts.material) == "string" then
		if type(opts.material) == "string" then
			d:texture(opts.material, x, y, z + 1, w, h, Color.white(255, true))
		elseif opts.material.path ~= "" then
			d:texture(
				opts.material.path,
				opts.material.x or x,
				opts.material.y or y,
				z + 1,
				opts.material.w or w,
				opts.material.h or h,
				opts.material.color or Color.white(255, true),
				opts.material.uv,
				opts.material.rotation
			)
		end
	end

	d:field_outline(x, y, x + w, y + h, z)

	if hovered and opts.tooltip then
		Tooltip.draw(d, opts.tooltip)
	end

	if clicked and opts.on_click then
		opts.on_click()
	end

	return clicked
end

mod.hud_studio_button_component = Button

return Button
