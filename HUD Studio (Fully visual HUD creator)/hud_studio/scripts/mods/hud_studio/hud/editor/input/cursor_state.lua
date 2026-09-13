
local mod = get_mod("hud_studio")

if mod.cursor_state then
	return mod.cursor_state
end

local CursorState = {}

function CursorState.test(d, id, x, y, w, h)
	local inside = d:in_rect(x, y, w, h)

	if inside then
		d.hot_id = id
	end

	local hovered = inside and d.hot_id_prev == id

	if hovered and d.pressed then
		d.active_id = id
	end

	local held = d.active_id == id
	local clicked = false

	if held and not d.hold then
		if hovered then
			clicked = true
		end
		d.active_id = nil
	end

	return hovered, clicked, held
end

mod.cursor_state = CursorState

return CursorState
