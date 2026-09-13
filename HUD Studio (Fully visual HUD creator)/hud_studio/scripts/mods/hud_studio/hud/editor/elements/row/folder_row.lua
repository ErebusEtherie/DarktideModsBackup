
local mod = get_mod("hud_studio")

if mod.folder_row_component then
	return mod.folder_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local Session = mod:core(mod.hud_studio_session, "document/session")

local Folder = {}

local eye_ids = {}

local function id_for(store, name)
	local id = store[name]
	if not id then
		id = {}
		store[name] = id
	end
	return id
end

function Folder.label(name)
	if type(name) ~= "string" or name == "" then
		return "?"
	end
	if Session.is_trash_folder(name) then

		local count = Session.trash_count()
		if count > 0 then
			return mod:localize("f_row_title_filled", count) 
		end
		return mod:localize("f_row_title")
	end
	return name
end

function Folder.draw(d, name, x, row_y, w, z, selected, hovered, on_toggle, collapsed, editing)

	local is_trash = Session.is_trash_folder(name)

	Row.draw(d, x, row_y, w, z, {
		label = Folder.label(name),

		folder = { open = not collapsed },
		selected = selected,
		hovered = hovered,
		editing = editing,

		eye = not is_trash and {
			id = id_for(eye_ids, name),
			is_block = true,

			dynamic = false,
			on = Session.folder_shown(name),
			on_toggle = on_toggle,
			tooltip = function(on)
				return on and "Hide Folder (hides every block in it)" or "Show Folder"
			end,
		} or nil,
	})
end

mod.folder_row_component = Folder

return Folder
