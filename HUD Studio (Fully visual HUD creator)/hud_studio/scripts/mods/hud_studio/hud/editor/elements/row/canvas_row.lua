
local mod = get_mod("hud_studio")

if mod.canvas_row_component then
	return mod.canvas_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")

local Canvas = {}

function Canvas.draw(d, x, row_y, w, z, selected, hovered)
	Row.draw(d, x, row_y, w, z, {
		label = mod:localize("canvas_row_title"),
		selected = selected,
		hovered = hovered,
	})
	d:text_left("MOD\n HUD", 6, x + 9, row_y + 6, z + 10, 18, 18, { 255, 175, 175, 175 })
end

mod.canvas_row_component = Canvas

return Canvas
