---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_block_library then
	return mod.hud_studio_block_library
end

local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local Store = mod:core(mod.hud_studio_store, "document/store")
local Rebind = mod:core(mod.hud_studio_rebind, "document/rebind")

---@alias LibraryOrigin "mod"|"user"|"external"

---@class LibraryCatalogueEntry
---@field id string             "mod:<relpath>" | "user:<name>" | "ext:<owner>:<relpath>"
---@field origin LibraryOrigin
---@field kind "block"|"folder"  a single block, or a folder saved whole
---@field block_count integer?   members, on folder entries only
---@field name string           the relpath for mod/external entries, the file stem for user ones
---@field label string          short caption, the grid button face
---@field summary string?       one or two sentences, the details pane body
---@field tags string[]         authored keywords, shown in the details pane; user entries carry none
---@field saved_at string?      user entries only
---@field owner string?         mod and external entries: the registering mod's id
---@field owner_label string?   mod and external entries: that mod's display label
---@field author string?        mod and external entries: who the registering mod credits
---@field version integer?      mod and external entries: the author's content version for this

---@field path string?          mod and external entries: what io_dofile takes
---@field requires string[]?    mod and external entries: other mod ids the block's code reaches

---@class LibraryCategory
---@field kind "all"|"saved"|"mod"
---@field key string          ALL_CATEGORY / SAVED_CATEGORY / the owning mod's id
---@field label string        the button face; a mod's is its registered display label
---@field author string?      mod categories only: the author the registration credits
---@field shipped boolean?    mod categories only: true for OUR presets, false for a third party's

---@class LibraryDetails
---@field is_folder boolean
---@field block_count integer   1 for a single block, the member count for a folder
---@field node_count integer    summed across the members
---@field sources string[]      every source id the block reads, sorted
---@field bind_options string[] player slots offered as rebind targets ({} when none apply)
---@field bind_from string?     the slot the block was authored against, when exactly one is read

---@class BlockLibrary
local BlockLibrary = {}

local MOD_INDEX_PATH = "hud_studio/scripts/mods/hud_studio/node_library/index"

BlockLibrary.SAVED_CATEGORY = "Saved"
BlockLibrary.ALL_CATEGORY = "All"

local PLAYER_SLOTS = { "player_1", "player_2", "player_3", "player_4" }
local IS_PLAYER_SLOT = {}
for i = 1, #PLAYER_SLOTS do
	IS_PLAYER_SLOT[PLAYER_SLOTS[i]] = true
end

local function deep_copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, val in pairs(v) do
		out[k] = deep_copy(val)
	end
	return out
end

---@type LibraryCatalogueEntry[]?
local catalogue = nil

---@type table<string, BlockData>
local loaded = {}

---@type table<string, string>
local failed = {}

---@type table<string, table>?
local owners = nil

---@param requires string[]?
---@return string[]?
local function requires_copy(requires)
	if type(requires) ~= "table" or #requires == 0 then
		return nil
	end
	local out = {}
	for i = 1, #requires do
		out[i] = requires[i]
	end
	return out
end

---@return LibraryCatalogueEntry[]
local function read_mod_entries()
	local ok, manifest = pcall(mod.io_dofile, mod, MOD_INDEX_PATH)
	if not ok or type(manifest) ~= "table" then
		return {}
	end
	local registration = mod.normalise_block_manifest(mod:get_name(), manifest)
	if not registration then
		return {}
	end

	local out = {}
	for i = 1, #registration.entries do
		local entry = registration.entries[i]
		out[#out + 1] = {

			id = "mod:" .. entry.relpath,
			origin = "mod",

			owner = registration.owner,
			owner_label = registration.owner_label,
			author = registration.author,
			version = entry.version,

			kind = entry.kind or "block",
			name = entry.relpath,
			label = entry.label,
			summary = entry.summary,

			tags = entry.tags,
			requires = entry.requires,
			path = entry.path,
		}
	end
	return out
end

---@return LibraryCatalogueEntry[]
local function read_external_entries()
	local ok, registrations = pcall(mod.external_block_registrations)
	if not ok or type(registrations) ~= "table" then
		mod.dl.log.error("block library: could not read external registrations: %s", tostring(registrations))
		return {}
	end

	local out = {}
	for i = 1, #registrations do
		local reg = registrations[i]

		local read_ok, reason = pcall(function()
			for e = 1, #reg.entries do
				local entry = reg.entries[e]
				out[#out + 1] = {

					id = "ext:" .. reg.owner .. ":" .. entry.relpath,
					origin = "external",

					kind = entry.kind == "folder" and "folder" or "block",
					name = entry.relpath,
					label = entry.label,
					summary = entry.summary,
					tags = {},
					owner = reg.owner,
					owner_label = reg.owner_label or reg.owner,
					author = reg.author,
					version = entry.version,
					requires = entry.requires,
					path = entry.path,
				}
			end
		end)
		if not read_ok then
			mod.dl.log.error("block library: skipped registration from '%s': %s", tostring(reg.owner), tostring(reason))
		end
	end
	return out
end

---@param entry LibraryCatalogueEntry
---@return BlockData? block
---@return string? reason
local function load_registered_block(entry)
	if type(entry.path) ~= "string" or not Schema.is_valid_relpath(entry.path) then
		return nil, "invalid registered path"
	end
	local ok, data = pcall(mod.io_dofile, mod, entry.path)
	if not ok then
		return nil, tostring(data)
	end
	if type(data) ~= "table" then
		return nil, "registered block did not return a table"
	end

	if data.kind == "folder" then
		if type(data.blocks) ~= "table" then
			return nil, "folder record has no blocks"
		end
		for i = 1, #data.blocks do
			local member_valid, member_why = Schema.validate_block(data.blocks[i])
			if not member_valid then
				return nil, string.format("block %d: %s", i, tostring(member_why))
			end
			data.blocks[i] = Schema.migrate_block(data.blocks[i])
		end
		return data
	end

	local valid, why = Schema.validate_block(data)
	if not valid then
		return nil, why
	end
	return Schema.migrate_block(data)
end

---@return LibraryCatalogueEntry[]
local function read_user_entries()
	local rows = Store.list_library()
	local out = {}
	for i = 1, #rows do
		out[#out + 1] = {
			id = "user:" .. rows[i].name,
			origin = "user",
			kind = rows[i].kind or "block",
			block_count = rows[i].block_count,
			name = rows[i].name,
			label = rows[i].label or rows[i].name,
			tags = {},

			requires = rows[i].requires,
			saved_at = rows[i].saved_at,
		}
	end
	return out
end

---@return LibraryCatalogueEntry[]
function BlockLibrary.catalogue()
	if catalogue then
		return catalogue
	end
	local out = read_user_entries()
	local shipped = read_mod_entries()
	for i = 1, #shipped do
		out[#out + 1] = shipped[i]
	end
	local external = read_external_entries()
	for i = 1, #external do
		out[#out + 1] = external[i]
	end
	catalogue = out
	return catalogue
end

function BlockLibrary.refresh()
	catalogue = nil
	loaded = {}
	failed = {}
	owners = nil
end

---@param id string?
---@return { label: string, author: string?, installed: boolean }
function BlockLibrary.owner_info(id)
	id = tostring(id or "?")
	if not owners then
		owners = {}
		local entries = BlockLibrary.catalogue()
		for i = 1, #entries do
			local entry = entries[i]
			if entry.owner and not owners[entry.owner] then
				owners[entry.owner] = {
					label = entry.owner_label or entry.owner,
					author = entry.author,
					installed = true,
				}
			end
		end
	end
	local known = owners[id]
	if known then
		return known
	end

	local gone = { label = id, installed = false }
	owners[id] = gone
	return gone
end

---@param id string
---@return LibraryCatalogueEntry?
function BlockLibrary.get(id)
	local entries = BlockLibrary.catalogue()
	for i = 1, #entries do
		if entries[i].id == id then
			return entries[i]
		end
	end
	return nil
end

---@return LibraryCategory[]
function BlockLibrary.categories()
	local entries = BlockLibrary.catalogue()
	local out = { { kind = "all", key = BlockLibrary.ALL_CATEGORY, label = BlockLibrary.ALL_CATEGORY } }

	local has_user = false
	for i = 1, #entries do
		if entries[i].origin == "user" then
			has_user = true
			break
		end
	end
	if has_user then
		out[#out + 1] = { kind = "saved", key = BlockLibrary.SAVED_CATEGORY, label = BlockLibrary.SAVED_CATEGORY }
	end

	local seen_owner = {}
	for i = 1, #entries do
		local entry = entries[i]
		if (entry.origin == "mod" or entry.origin == "external") and not seen_owner[entry.owner] then
			seen_owner[entry.owner] = true
			out[#out + 1] = {
				kind = "mod",
				key = entry.owner,
				label = entry.owner_label or entry.owner,
				author = entry.author,

				shipped = entry.origin == "mod",
			}
		end
	end
	return out
end

---@param category LibraryCategory?
---@return LibraryCatalogueEntry[]
function BlockLibrary.entries_in(category)
	local entries = BlockLibrary.catalogue()
	local kind = category and category.kind or "all"
	if kind == "all" then
		return entries
	end

	local key = category.key
	local out = {}
	for i = 1, #entries do
		local entry = entries[i]
		if kind == "saved" then
			if entry.origin == "user" then
				out[#out + 1] = entry
			end
		elseif kind == "mod" then

			if entry.owner == key and entry.origin ~= "user" then
				out[#out + 1] = entry
			end
		end
	end
	return out
end

---@param entry LibraryCatalogueEntry
---@return integer index  into BlockLibrary.categories()
function BlockLibrary.category_index_of(entry)
	local cats = BlockLibrary.categories()
	for i = 1, #cats do
		local cat = cats[i]
		if
			(cat.kind == "saved" and entry.origin == "user")
			or (cat.kind == "mod" and entry.origin ~= "user" and entry.owner == cat.key)
		then
			return i
		end
	end
	return 1
end

---@param id string
---@return BlockData? data
---@return string? reason
function BlockLibrary.load(id)
	local cached = loaded[id]
	if cached then
		return cached
	end

	local why = failed[id]
	if why then
		return nil, why
	end
	local entry = BlockLibrary.get(id)
	if not entry then
		local reason = "no library entry " .. tostring(id)
		failed[id] = reason
		return nil, reason
	end

	local data, reason
	if entry.origin == "user" then
		data, reason = Store.load_library(entry.name)
	else

		data, reason = load_registered_block(entry)
	end
	if not data then
		reason = tostring(reason)
		failed[id] = reason
		mod.dl.log.error("block library: could not load '%s': %s", entry.id, reason)
		return nil, reason
	end

	entry.kind = BlockLibrary.is_folder(data) and "folder" or "block"

	loaded[id] = data
	return data
end

---@param record table?
---@return boolean
function BlockLibrary.is_folder(record)
	return type(record) == "table" and record.kind == "folder" and type(record.blocks) == "table"
end

---@param record table
---@return BlockData[]
function BlockLibrary.blocks_of(record)
	return BlockLibrary.is_folder(record) and record.blocks or { record }
end

---@param record table   BlockData or a folder bundle
---@return LibraryDetails
function BlockLibrary.details(record)
	local blocks = BlockLibrary.blocks_of(record)

	local seen, sources, node_count = {}, {}, 0
	for i = 1, #blocks do
		node_count = node_count + #(blocks[i].nodes or {})
		local used = Rebind.sources_used(blocks[i])
		for u = 1, #used do
			if not seen[used[u]] then
				seen[used[u]] = true
				sources[#sources + 1] = used[u]
			end
		end
	end
	table.sort(sources)

	local slots = {}
	for i = 1, #sources do
		if IS_PLAYER_SLOT[sources[i]] then
			slots[#slots + 1] = sources[i]
		end
	end

	return {
		is_folder = BlockLibrary.is_folder(record),
		block_count = #blocks,
		node_count = node_count,
		sources = sources,
		bind_options = #slots == 1 and PLAYER_SLOTS or {},
		bind_from = #slots == 1 and slots[1] or nil,
	}
end

---@param id string
---@param label string?     display label; insert_block slugifies it into a unique on-disk name
---@param bind_from string?
---@param bind_to string?
---@return BlockData[]? blocks   one block, or a folder's members in tree order
---@return string|integer? reason_or_skipped
---@return boolean? is_folder    true when the caller should file the blocks into a new folder
function BlockLibrary.prepare(id, label, bind_from, bind_to)
	local source, reason = BlockLibrary.load(id)
	if not source then
		return nil, reason
	end
	local entry = BlockLibrary.get(id)

	local is_folder = BlockLibrary.is_folder(source)
	local blocks = {}
	for i, block in ipairs(BlockLibrary.blocks_of(source)) do
		blocks[i] = deep_copy(block)

		blocks[i].folder = nil
		blocks[i].trashed_from = nil

		blocks[i].origin = BlockLibrary.origin_of(entry)
	end

	if label and label ~= "" and not is_folder then
		blocks[1].label = label
	end

	local skipped = 0
	if bind_from and bind_to and bind_from ~= bind_to then
		for i = 1, #blocks do
			local _, n = Rebind.run(blocks[i], bind_from, bind_to, true)
			skipped = skipped + n
		end
	end
	return blocks, skipped, is_folder
end

---@param entry LibraryCatalogueEntry?
---@return BlockOrigin?
function BlockLibrary.origin_of(entry)
	if not entry or entry.origin == "user" or not entry.owner then
		return nil
	end
	return {
		mod = entry.owner,
		file = entry.name,
		version = entry.version or 1,

		requires = requires_copy(entry.requires),
	}
end

---@param origin BlockOrigin?
---@param entry LibraryCatalogueEntry?
---@return boolean
function BlockLibrary.origin_matches(origin, entry)
	if type(origin) ~= "table" or not entry then
		return false
	end
	return origin.mod == entry.owner and origin.file == entry.name
end

---@param origin BlockOrigin?
---@param entry LibraryCatalogueEntry?
---@return boolean
function BlockLibrary.has_update(origin, entry)
	if not BlockLibrary.origin_matches(origin, entry) then
		return false
	end
	return (entry.version or 1) > (origin.version or 1)
end

---@param entry LibraryCatalogueEntry?
---@return string[] missing
function BlockLibrary.missing_requires(entry)
	if not entry then
		return {}
	end
	return mod.missing_required_mods(entry.requires)
end

---@param data BlockData
---@param name string
---@return boolean ok
---@return string name_or_reason  the slugified name on success, the failure reason otherwise
function BlockLibrary.save(data, name)
	local slug = Schema.slugify(name or "")
	if slug == "" then
		return false, "no name"
	end
	local ok, reason = Store.save_library(data, slug, data and (data.label or data.name) or slug)
	if not ok then
		return false, tostring(reason)
	end
	BlockLibrary.refresh()
	return true, slug
end

---@param name string
---@param mod_name string
---@return string path
---@return boolean mod_exists
---@return boolean file_exists
function BlockLibrary.export_target(name, mod_name)
	local slug = Schema.slugify(name or "")
	local mod_slug = Schema.slugify(mod_name or "")
	if slug == "" or mod_slug == "" then
		return "", false, false
	end
	local path, _, mod_exists, file_exists = Store.export_target(slug, mod_slug)

	return Store.display_path(path), mod_exists, file_exists
end

---@param data BlockData
---@param name string
---@param mod_name string
---@return boolean ok
---@return string relpath_or_reason  the path to register the block under, or the failure reason
function BlockLibrary.export_to_mod(data, name, mod_name)
	local slug = Schema.slugify(name or "")
	if slug == "" then
		return false, "no name"
	end
	local mod_slug = Schema.slugify(mod_name or "")
	if mod_slug == "" then
		return false, "no mod name"
	end
	return Store.export_to_mod(data, slug, mod_slug)
end

---@param blocks BlockData[]
---@param name string
---@param label string?
---@return boolean ok
---@return string name_or_reason
function BlockLibrary.save_folder(blocks, name, label)
	local slug = Schema.slugify(name or "")
	if slug == "" then
		return false, "no name"
	end
	local ok, reason = Store.save_library_folder(blocks, slug, label or slug)
	if not ok then
		return false, tostring(reason)
	end
	BlockLibrary.refresh()
	return true, slug
end

---@param data BlockData?
---@return string
function BlockLibrary.default_save_name(data)
	return Schema.slugify((data and (data.label or data.name)) or "")
end

mod.hud_studio_block_library = BlockLibrary

return BlockLibrary
