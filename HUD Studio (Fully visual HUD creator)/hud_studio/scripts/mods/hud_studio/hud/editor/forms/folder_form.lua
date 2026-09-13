---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_folder_form then
	return mod.hud_studio_folder_form
end

local Session = mod:core(mod.hud_studio_session, "document/session")
local Store = mod:core(mod.hud_studio_store, "document/store")
local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")

local FolderForm = {}

---@param ref table { name: string }  the editor's live handle on which folder is selected
local function name_row(ref)
	return {
		kind = "text",
		label = mod:localize("field_label_name"),
		token = "folder/name",
		get = function()
			return ref.name or ""
		end,
		set = function(v)
			if v == "" or v == ref.name then
				return
			end
			local ok, reason = Session.folder_rename(ref.name, v)
			if not ok then
				mod.dl.log.error("failed to rename folder: %s", tostring(reason))
				return
			end

			ref.name = v
		end,
	}
end

---@param ref table
local function name_note_row(ref)
	local is_trash = Session.is_trash_folder(ref.name)
	return {
		kind = "note",
		wrap = true,
		value = function()
			return mod:localize("f_form_trash_note", Session.trash_count())
		end,
	}
end

local library_save = { folder = nil, name = nil }

local LIBRARY_NAME_TOKEN = "folder/library_name"

local function library_save_name()
	local typed = library_save.name
	if typed and typed ~= "" then
		return Schema.slugify(typed)
	end
	return Schema.slugify(library_save.folder or "")
end

local function library_save_button_text()
	if TextField.is_focused(LIBRARY_NAME_TOKEN) then
		return mod:localize("lib_save_form_await_blur")
	end
	local name = library_save_name()
	if name == "" then
		return mod:localize("lib_save_form_missing_name")
	end
	if Store.library_exists(name) then
		return mod:localize("lib_save_form_overwrite", name)
	end
	return mod:localize("lib_save_form_save_folder")
end

local function library_save_group()
	return {
		group = true,
		field = "save_folder_to_library",
		label = mod:localize("lib_save_form_save"),
		mode = {
			kind = "text",
			token = LIBRARY_NAME_TOKEN,
			get = function()
				return library_save.name or ""
			end,
			set = function(v)
				library_save.name = v
			end,
		},
		controls = {
			{
				kind = "button",
				text = library_save_button_text,
				action = "save_folder_to_library_form",
				disabled = function()
					return TextField.is_focused(LIBRARY_NAME_TOKEN) or library_save_name() == ""
				end,
			},
			{
				kind = "button",
				trailing = true,
				text = mod:localize("browse_ellipsis"),
				tooltip = mod:localize("lib_open_tooltip"),
				action = "open_block_library",
			},
		},
	}
end

---@return string? folder, string name
function FolderForm.pending_library_save()
	return library_save.folder, library_save_name()
end

---@param ref table { name: string }
---@return FormSection[]
function FolderForm.build(ref)
	local is_trash = Session.is_trash_folder(ref.name)

	if library_save.folder ~= ref.name then
		library_save.folder, library_save.name = ref.name, nil
	end

	local rows = { (not is_trash) and name_row(ref) or name_note_row(ref) }

	if not is_trash then
		rows[#rows + 1] = library_save_group()
	end

	return {
		{
			key = "folder",
			title = is_trash and mod:localize("f_form_trash_title") or mod:localize("f_form_title"),
			flat = true,
			rows = rows,
		},
	}
end

mod.hud_studio_folder_form = FolderForm

return FolderForm
