
local mod = get_mod("hud_studio")

if mod.grid_component then
	return mod.grid_component
end

local COLOR = {
	GRID = { 255, 240, 70, 150 },
}

local Grid = {}

function Grid.draw(d, x, y, w, h, rows, cols, z, color)
	if (rows <= 0 and cols <= 0) or w <= 0 or h <= 0 then
		return
	end

	local line_px = 1

	if cols > 0 then
		for col = 1, cols do
			local x = math.floor(x + w * (col / (cols + 1)))
			d:rect(x, y, z, line_px, h, color or COLOR.GRID)
		end
	end

	if rows > 0 then
		for row = 1, rows do
			local y = math.floor(y + h * (row / (rows + 1)))
			d:rect(x, y, z, w, line_px, color or COLOR.GRID)
		end
	end
end

mod.grid_component = Grid

return Grid
