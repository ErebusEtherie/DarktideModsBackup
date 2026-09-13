
local mod = get_mod("hud_studio")

if mod.blank_folder_row_component then
	return mod.blank_folder_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")

local Folder = {}

function Folder.draw(d, x, row_y, w, z, folder_is_empty, is_root)
	if folder_is_empty then
		local label = is_root and "drag blocks here to take them out of a folder" or "empty - drag blocks into here"
		d:text_center(label, 12, x, row_y, z + 1, w, Row.ROW_H, { 100, 255, 255, 255 })
	end
end

mod.blank_folder_row_component = Folder

return Folder
