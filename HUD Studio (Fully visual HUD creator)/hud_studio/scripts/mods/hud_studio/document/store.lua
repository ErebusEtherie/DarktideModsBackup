---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_store then
	return mod.hud_studio_store
end

local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local Serialize = mod:core(mod.hud_studio_serialize, "document/serialize")

local _io = Mods.lua.io
local _os = Mods.lua.os
local _loadstring = Mods.lua.loadstring

local REFERENCE = "hud_studio"

---@class LibraryEntry
---@field name string       on-disk name, also the filename under blocks/library/
---@field label string      display label, seeded from the block's own at save time
---@field kind "block"|"folder"  a single block, or a bundle of them saved as a folder
---@field block_count integer?   members, on folder entries only
---@field requires string[]?     mod ids the saved block (or any member of a saved folder) needs,

---@field saved_at string?  save stamp, absent where the sandbox exposes no clock

---@class Store
local Store = {}

---@return string
local function blocks_dir()
	return _os.getenv("APPDATA") .. "/Fatshark/Darktide/" .. REFERENCE .. "/blocks/"
end

local File = mod.dl.file

---@param name string
---@return string
local function block_path(name)
	return blocks_dir() .. name .. ".lua"
end

local function index_path()
	return blocks_dir() .. "index.lua"
end

local function canvas_path()
	return blocks_dir() .. "canvas.lua"
end

---@param path string
---@param chunk_name string
---@return table? value
---@return string? reason
local function read_table(path, chunk_name)
	local f = _io.open(path, "r")
	if not f then
		return nil, "no such file"
	end
	local text = f:read("*all")
	f:close()

	local chunk, err = _loadstring(text, chunk_name)
	if not chunk then
		return nil, err
	end

	local ok, value = pcall(chunk)
	if not ok then
		return nil, tostring(value)
	end
	if type(value) ~= "table" then
		return nil, "file did not return a table"
	end
	return value
end

---@param path string
---@param value table
---@return boolean ok
---@return string? reason
local function write_table(path, value)
	local ok, body = pcall(Serialize.to_source, value)
	if not ok then
		return false, "serialize failed: " .. tostring(body)
	end

	File.ensure_dir(File.dir_of(path))

	local f = _io.open(path, "w+")
	if not f then
		return false, "could not open file for writing"
	end
	f:write(body)
	f:close()
	return true
end

---@return string[]
function Store.list()
	local idx, _ = read_table(index_path(), "hud_studio_index")
	if not idx then
		return {}
	end
	local valid = Schema.validate_index(idx)
	if not valid then
		return {}
	end
	return idx.blocks
end

---@param names string[]
---@return boolean ok
---@return string? reason
function Store.write_index(names)
	local idx = { version = Schema.CURRENT_VERSION, blocks = names }
	local valid, reason = Schema.validate_index(idx)
	if not valid then
		return false, reason
	end
	return write_table(index_path(), idx)
end

---@return CanvasData? canvas
---@return string? reason
function Store.load_canvas()
	local canvas, reason = read_table(canvas_path(), "hud_studio_canvas")
	if not canvas then
		return nil, reason
	end
	local valid, why = Schema.validate_canvas(canvas)
	if not valid then
		return nil, why
	end
	return canvas
end

---@param canvas CanvasData
---@return boolean ok
---@return string? reason
function Store.save_canvas(canvas)
	local valid, reason = Schema.validate_canvas(canvas)
	if not valid then
		return false, reason
	end
	return write_table(canvas_path(), canvas)
end

---@param name string
---@return BlockData? block
---@return string? reason
function Store.load_block(name)
	if not Schema.is_valid_name(name) then
		return nil, "invalid block name"
	end
	local block, reason = read_table(block_path(name), "hud_studio_block:" .. name)
	if not block then
		return nil, reason
	end
	local valid, why = Schema.validate_block(block)
	if not valid then
		return nil, why
	end
	return Schema.migrate_block(block)
end

---@return BlockData[]
function Store.load_all()
	local out = {}
	local names = Store.list()
	for i = 1, #names do
		local block = Store.load_block(names[i])
		if block then
			out[#out + 1] = block
		end
	end
	return out
end

---@param block BlockData
---@return boolean ok
---@return string? reason
function Store.save_block(block)
	local valid, reason = Schema.validate_block(block)
	if not valid then
		return false, reason
	end
	return write_table(block_path(block.name), block)
end

---@return string?
local function stamp_now()
	if type(_os.date) == "function" then
		local ok, stamp = pcall(_os.date, "%Y-%m-%d %H:%M")
		if ok and type(stamp) == "string" then
			return stamp
		end
	end
	if type(_os.time) == "function" then
		local ok, epoch = pcall(_os.time)
		if ok and epoch then
			return tostring(epoch)
		end
	end
	return nil
end

---@return string
local function library_dir()
	return blocks_dir() .. "library/"
end

---@param name string
---@return string
local function library_path(name)
	return library_dir() .. name .. ".lua"
end

local function library_index_path()
	return library_dir() .. "index.lua"
end

---@return LibraryEntry[]
local function read_library_index()
	local idx = read_table(library_index_path(), "hud_studio_library_index")
	if type(idx) ~= "table" or type(idx.entries) ~= "table" then
		return {}
	end
	local out = {}
	for i = 1, #idx.entries do
		local entry = idx.entries[i]
		if type(entry) == "table" and Schema.is_valid_name(entry.name) then
			out[#out + 1] = {
				name = entry.name,
				label = type(entry.label) == "string" and entry.label or entry.name,

				kind = entry.kind == "folder" and "folder" or "block",
				block_count = type(entry.block_count) == "number" and entry.block_count or nil,
				requires = type(entry.requires) == "table" and entry.requires or nil,
				saved_at = type(entry.saved_at) == "string" and entry.saved_at or nil,
			}
		end
	end
	return out
end

---@param entries LibraryEntry[]
---@return boolean ok
---@return string? reason
local function write_library_index(entries)
	return write_table(library_index_path(), { version = Schema.CURRENT_VERSION, entries = entries })
end

---@return LibraryEntry[]
function Store.list_library()
	return read_library_index()
end

---@param name string
---@return BlockData? block
---@return string? reason
function Store.load_library(name)
	if not Schema.is_valid_name(name) then
		return nil, "invalid block name"
	end
	local record, reason = read_table(library_path(name), "hud_studio_library:" .. name)
	if not record then
		return nil, reason
	end

	if record.kind == "folder" then
		if type(record.blocks) ~= "table" then
			return nil, "folder record has no blocks"
		end
		for i = 1, #record.blocks do
			local valid, why = Schema.validate_block(record.blocks[i])
			if not valid then
				return nil, string.format("block %d: %s", i, tostring(why))
			end
			record.blocks[i] = Schema.migrate_block(record.blocks[i])
		end
		return record
	end

	local valid, why = Schema.validate_block(record)
	if not valid then
		return nil, why
	end
	return Schema.migrate_block(record)
end

---@param block BlockData
---@param name string?
---@param label string?
---@return boolean ok
---@return string? reason

---@param block BlockData
---@param name string
---@return BlockData
local function library_copy(block, name)
	local stored = {}
	for k, v in pairs(block) do
		stored[k] = v
	end
	stored.name = name
	stored.folder = nil
	stored.trashed_from = nil

	if stored.origin then
		if stored.origin.requires and not stored.requires then
			local requires = {}
			for i = 1, #stored.origin.requires do
				requires[i] = stored.origin.requires[i]
			end
			stored.requires = requires
		end
		stored.origin = nil
	end
	return stored
end

---@param blocks BlockData[]
---@return string[]?
local function folder_requires(blocks)
	local seen, out = {}, {}
	for i = 1, #blocks do
		local requires = blocks[i].requires
		if type(requires) == "table" then
			for r = 1, #requires do
				local id = requires[r]
				if type(id) == "string" and id ~= "" and not seen[id] then
					seen[id] = true
					out[#out + 1] = id
				end
			end
		end
	end
	return #out > 0 and out or nil
end

---@param entry LibraryEntry
---@return boolean ok
---@return string? reason
local function put_library_entry(entry)
	local entries = read_library_index()
	local replaced = false
	for i = 1, #entries do
		if entries[i].name == entry.name then
			entries[i] = entry
			replaced = true
			break
		end
	end
	if not replaced then
		entries[#entries + 1] = entry
	end
	return write_library_index(entries)
end

function Store.save_library(block, name, label)
	if type(block) ~= "table" then
		return false, "no block data"
	end
	name = name or block.name
	if not Schema.is_valid_name(name) then
		return false, "invalid library name"
	end

	local stored = library_copy(block, name)

	local valid, reason = Schema.validate_block(stored)
	if not valid then
		return false, reason
	end

	local ok, why = write_table(library_path(name), stored)
	if not ok then
		return false, why
	end

	return put_library_entry({
		name = name,
		label = label or block.label or name,
		kind = "block",

		requires = stored.requires,
		saved_at = stamp_now(),
	})
end

---@param path string
---@return string
function Store.display_path(path)
	return (tostring(path or ""):gsub("^%.[\\/]%.%.[\\/]", ""))
end

---@param name string  the on-disk block name, already slugified
---@param mod_name string  already slugified
---@return string path        full path the write would take
---@return string relpath     the path to register the block under
---@return boolean mod_exists whether `mod_name` is a real mod (its own source folder is there)
---@return boolean file_exists whether a file is already sitting at `path`
function Store.export_target(name, mod_name)
	local relpath = "scripts/mods/" .. mod_name .. "/" .. name

	local path = File.mods(mod_name .. "/" .. relpath .. ".lua")

	local mod_exists = File.is_dir(File.mods(mod_name .. "/scripts/mods/" .. mod_name))
	return path, relpath, mod_exists, mod_exists and File.file_exists(path) or false
end

---@param block BlockData
---@param name string  the on-disk name, already slugified (the library name is reused)
---@param mod_name string
---@return boolean ok
---@return string relpath_or_reason
function Store.export_to_mod(block, name, mod_name)
	if type(block) ~= "table" then
		return false, "no block data"
	end
	if not Schema.is_valid_name(name) then
		return false, "invalid block name"
	end
	if not Schema.is_valid_name(mod_name) then
		return false, "invalid mod name"
	end

	local path, relpath, mod_exists = Store.export_target(name, mod_name)
	if not mod_exists then
		return false, "mod does not exist"
	end

	local stored = library_copy(block, name)

	local valid, reason = Schema.validate_block(stored)
	if not valid then
		return false, tostring(reason)
	end

	local ok, why = write_table(path, stored)
	if not ok then
		return false, tostring(why)
	end

	return true, relpath
end

---@param blocks BlockData[]
---@param name string
---@param label string?
---@return boolean ok
---@return string? reason
function Store.save_library_folder(blocks, name, label)
	if type(blocks) ~= "table" or #blocks == 0 then
		return false, "the folder is empty"
	end
	if not Schema.is_valid_name(name) then
		return false, "invalid library name"
	end

	local stored = { kind = "folder", label = label or name, blocks = {} }
	for i = 1, #blocks do
		local member = library_copy(blocks[i], blocks[i].name)
		local valid, reason = Schema.validate_block(member)
		if not valid then
			return false, string.format("block %d (%s): %s", i, tostring(blocks[i].name), tostring(reason))
		end
		stored.blocks[i] = member
	end

	local ok, why = write_table(library_path(name), stored)
	if not ok then
		return false, why
	end

	return put_library_entry({
		name = name,
		label = stored.label,
		kind = "folder",
		block_count = #stored.blocks,

		requires = folder_requires(stored.blocks),
		saved_at = stamp_now(),
	})
end

---@param name string
---@return boolean
function Store.library_exists(name)
	local entries = read_library_index()
	for i = 1, #entries do
		if entries[i].name == name then
			return true
		end
	end
	return false
end

---@param name string
---@return boolean ok
---@return string? reason
function Store.delete_library(name)
	if not Schema.is_valid_name(name) then
		return false, "invalid library name"
	end
	local entries = read_library_index()
	local kept, found = {}, false
	for i = 1, #entries do
		if entries[i].name == name then
			found = true
		else
			kept[#kept + 1] = entries[i]
		end
	end
	if not found then
		return false, "no saved block named " .. name
	end

	if type(_os.remove) == "function" then
		pcall(_os.remove, library_path(name))
	end
	return write_library_index(kept)
end

mod.hud_studio_store = Store

return Store
