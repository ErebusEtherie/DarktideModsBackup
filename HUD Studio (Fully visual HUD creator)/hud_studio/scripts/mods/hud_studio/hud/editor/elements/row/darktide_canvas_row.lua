
local mod = get_mod("hud_studio")

if mod.darktide_canvas_row_component then
	return mod.darktide_canvas_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")

local Darktide = {}

function Darktide.draw(d, x, row_y, w, z, selected, hovered)
	Row.draw(d, x, row_y, w, z, {
		label = mod:localize("dt_canvas_row_title"),
		selected = selected,
		hovered = hovered,
	})
	d:text_left("", 19, x + 10, row_y + 6, z + 10, 16, 16, { 255, 175, 175, 175 })
end

mod.darktide_canvas_row_component = Darktide

return Darktide
