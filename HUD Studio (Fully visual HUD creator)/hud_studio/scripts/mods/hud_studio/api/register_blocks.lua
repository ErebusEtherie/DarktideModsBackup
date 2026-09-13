---@class mod : DL_Mod
local mod = get_mod("hud_studio")

---@class ExternalBlockEntry
---@field relpath string path inside the registering mod's folder, no extension
---@field path string path from the mods root, i.e. what io_dofile takes
---@field label string the button face; required, an entry without one is rejected
---@field summary string?
---@field kind string? always nil for now -- only "block" (or no kind) may be registered
---@field version integer the author's content version for this entry, >= 1 (default 1)
---@field requires string[] mod ids this block needs at runtime
---@field tags string[] accepted and stored, not surfaced in v1

---@class ExternalBlockRegistration
---@field owner string the registering mod's id (mod:get_name())
---@field owner_label string
---@field author string
---@field entries ExternalBlockEntry[]
---@field manifest table? the manifest as the author gave it, re-normalised on every catalogue build

local MAX_ENTRIES_PER_MOD = 64
local MAX_LABEL_LENGTH = 48

local MAX_SUMMARY_LENGTH = 600

---@param text any
---@param limit integer
---@return string?
local function capped(text, limit)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	return #text > limit and text:sub(1, limit) or text
end

---@param list any
---@return string[]
local function string_list(list)
	local out = {}
	if type(list) == "table" then
		for i = 1, #list do
			if type(list[i]) == "string" and list[i] ~= "" then
				out[#out + 1] = list[i]
			end
		end
	end
	return out
end

---@param owner_mod DL_Mod
---@return string?
local function localized_mod_name(owner_mod)
	local dmf = get_mod("DMF")
	if not dmf or type(dmf.quick_localize) ~= "function" then
		return nil
	end
	local ok, name = pcall(dmf.quick_localize, owner_mod, "mod_name")
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

---@param version any
---@return integer
local function version_of(version)
	if type(version) ~= "number" or version ~= version or version < 1 then
		return 1
	end
	return math.floor(version)
end

---@param file any
---@return string?
local function normalise_relpath(file)
	if type(file) ~= "string" then
		return nil
	end
	local path = file:gsub("\\", "/"):gsub("%.lua$", "")
	return path
end

---@param path string
---@return table?
local function block_file_at(path)
	local ok, data = pcall(mod.io_dofile, mod, path)
	return (ok and type(data) == "table") and data or nil
end

---@param owner_mod DL_Mod the registering mod instance, NOT its name -- get_mod("my_mod")
---@param manifest table  { author = string?, label = string?, blocks = (string|table)[] }
---@return boolean ok
function mod.register_blocks(owner_mod, manifest)
	if type(owner_mod) ~= "table" or type(owner_mod.get_name) ~= "function" then
		mod.dl.log.error("register_blocks: first argument must be the registering mod instance, e.g. get_mod('my_mod')")
		return false
	end

	local registration = mod.normalise_block_manifest(owner_mod:get_name(), manifest, localized_mod_name(owner_mod))
	if not registration then
		return false
	end

	registration.manifest = manifest

	owner_mod.hud_studio_blocks = registration
	mod:info("register_blocks: '%s' registered %d block(s)", registration.owner, #registration.entries)
	return true
end

---@param owner string
---@param manifest table
---@param owner_name string? the mod's own localized display name, used when the manifest names none
---@param quiet boolean?  suppress the author-facing error lines (see `report`)
---@return ExternalBlockRegistration?
function mod.normalise_block_manifest(owner, manifest, owner_name, quiet)

	local report = quiet and function() end or mod.dl.log.error

	if type(manifest) ~= "table" or type(manifest.blocks) ~= "table" then
		report("register_blocks: '%s' passed no `blocks` array", owner)
		return nil
	end

	local Schema = mod:core(mod.hud_studio_schema, "document/schema")

	local entries = {}
	for i = 1, #manifest.blocks do
		if #entries >= MAX_ENTRIES_PER_MOD then
			report(
				"register_blocks: '%s' registered more than %d blocks -- the rest were dropped",
				owner,
				MAX_ENTRIES_PER_MOD
			)
			break
		end
		local entry = manifest.blocks[i]

		local relpath = normalise_relpath(type(entry) == "table" and entry.file or entry)

		local file = relpath and Schema.is_valid_relpath(relpath) and block_file_at(owner .. "/" .. relpath) or nil
		local entry_field = function(key)
			if file and file[key] ~= nil then
				return file[key]
			end
			return type(entry) == "table" and entry[key] or nil
		end

		local label = capped(entry_field("label"), MAX_LABEL_LENGTH)
		if not relpath or not Schema.is_valid_relpath(relpath) then
			report(
				"register_blocks: '%s' entry %d is not a usable block path (got %s). An entry is the path "
					.. "to a block file inside your own mod, with no .lua extension.",
				owner,
				i,
				tostring(type(entry) == "table" and entry.file or entry)
			)
		elseif not file then
			report(
				"register_blocks: '%s' entry %d -- block file '%s.lua' could not be loaded, or did "
					.. "not return a table. Re-export it from hud_studio's Export to Mod section.",
				owner,
				i,
				owner .. "/" .. relpath
			)
		elseif not label then
			report(
				"register_blocks: '%s' entry %d -- block file '%s.lua' has no usable `label`, which "
					.. "is required. Set it in hud_studio's Export to Mod section and re-export.",
				owner,
				i,
				owner .. "/" .. relpath
			)

		elseif entry_field("kind") ~= nil and entry_field("kind") ~= "block" then
			report(
				"register_blocks: '%s' entry %d ('%s') has kind='%s' -- only 'block' (or no kind) is "
					.. "supported in this release, folder bundles cannot be registered yet",
				owner,
				i,
				relpath,
				tostring(entry_field("kind"))
			)
		else
			entries[#entries + 1] = {
				relpath = relpath,

				path = owner .. "/" .. relpath,
				label = label,
				summary = capped(entry_field("summary"), MAX_SUMMARY_LENGTH),

				kind = entry_field("kind") == "folder" and "folder" or nil,

				version = version_of(file and file.mod_version or (type(entry) == "table" and entry.version)),

				requires = string_list(entry_field("requires")),

				tags = string_list(entry_field("tags")),
			}
		end
	end

	return {
		owner = owner,

		owner_label = capped(manifest.label, MAX_LABEL_LENGTH) or capped(owner_name, MAX_LABEL_LENGTH) or owner,
		author = capped(manifest.author, MAX_LABEL_LENGTH) or "?",
		entries = entries,
	}
end

---@param reg ExternalBlockRegistration
---@param owner_mod DL_Mod
---@return ExternalBlockRegistration
local function renormalised(reg, owner_mod)
	if type(reg.manifest) ~= "table" then

		return reg
	end
	local ok, fresh = pcall(mod.normalise_block_manifest, reg.owner, reg.manifest, localized_mod_name(owner_mod), true)
	if not ok or type(fresh) ~= "table" or #fresh.entries == 0 then
		return reg
	end
	fresh.manifest = reg.manifest

	owner_mod.hud_studio_blocks = fresh
	return fresh
end

---@return ExternalBlockRegistration[]
function mod.external_block_registrations()
	local dmf = get_mod("DMF")
	local found = {}
	for _, other in pairs(dmf and dmf.mods or {}) do
		if other ~= mod and type(other) == "table" then
			local reg = rawget(other, "hud_studio_blocks")
			if type(reg) == "table" and type(reg.entries) == "table" then

				local ok, enabled = pcall(other.is_enabled, other)
				if ok and enabled then
					found[#found + 1] = renormalised(reg, other)
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.owner < b.owner
	end)
	return found
end

---@param ids string[]?
---@return string[] missing
function mod.missing_required_mods(ids)
	local missing = {}
	if type(ids) ~= "table" then
		return missing
	end
	for i = 1, #ids do
		local id = ids[i]
		if type(id) == "string" and id ~= "" then
			local other = get_mod(id)

			local ok, enabled = false, false
			if other then
				ok, enabled = pcall(other.is_enabled, other)
			end
			if not other or not ok or not enabled then
				missing[#missing + 1] = id
			end
		end
	end
	return missing
end

---@param entry ExternalBlockEntry
---@return string
local function probe_entry(entry)
	local ok, data = pcall(mod.io_dofile, mod, entry.path)
	if not ok then
		return string.format("  FAIL io_dofile %s -- %s", entry.path, tostring(data))
	end
	if type(data) ~= "table" then
		return string.format("  FAIL %s returned %s, not a table", entry.path, type(data))
	end

	local Schema = mod:core(mod.hud_studio_schema, "document/schema")

	if data.kind == "folder" then
		local members = type(data.blocks) == "table" and data.blocks or nil
		if not members then
			return string.format("  FAIL %s is kind='folder' but has no `blocks` table", entry.path)
		end
		local schema = "valid"
		for i = 1, #members do
			local valid, why = Schema.validate_block(members[i])
			if not valid then
				schema = string.format("INVALID block %d: %s", i, tostring(why))
				break
			end
		end
		return string.format(
			"  OK   %s -> folder label=%s blocks=%d schema=%s",
			entry.path,
			tostring(data.label),
			#members,
			schema
		)
	end

	local valid, why = Schema.validate_block(data)
	return string.format(
		"  OK   %s -> name=%s label=%s nodes=%d schema=%s",
		entry.path,
		tostring(data.name),
		tostring(data.label),
		#(data.nodes or {}),
		valid and "valid" or ("INVALID: " .. tostring(why))
	)
end

function mod.hud_studio_register_probe_command()
	mod:command("hud_studio_probe", "hud_studio: test-load every externally registered block", function()
		local lines = {}
		local registrations = mod.external_block_registrations()
		for i = 1, #registrations do
			local reg = registrations[i]
			lines[#lines + 1] = string.format("[%s by %s] %d entries", reg.owner, reg.author, #reg.entries)
			for j = 1, #reg.entries do
				local ok, line = pcall(probe_entry, reg.entries[j])
				lines[#lines + 1] = ok and line
					or string.format("  FAIL %s -- %s", reg.entries[j].path, tostring(line))
			end
		end
		if #lines == 0 then
			lines[1] = "no enabled mods have called hud_studio.register_blocks"
		end
		for i = 1, #lines do
			mod.dl.log.echo(lines[i])
			mod:info(lines[i])
		end
	end)
end
