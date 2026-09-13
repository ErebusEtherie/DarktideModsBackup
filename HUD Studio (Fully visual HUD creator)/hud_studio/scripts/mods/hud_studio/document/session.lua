---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_session then
	return mod.hud_studio_session
end

local Store = mod:core(mod.hud_studio_store, "document/store")
local Block = mod:core(mod.hud_studio_block, "blocks/block")
local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local History
local function history()
	History = History or mod:core(mod.hud_studio_history, "document/history")
	return History
end

local CHROME_MATERIALS = {
	"content/ui/materials/frames/frame_tile_1px", 
	"content/ui/materials/frames/line_thin_dashed_animated", 
	"content/ui/materials/frames/dropshadow_heavy", 
	"content/ui/materials/gradients/gradient_vertical", 
	"content/ui/materials/gradients/gradient_horizontal", 
	"content/ui/materials/hud/backgrounds/weapon_frame_arrow", 
	"content/ui/materials/icons/player_states/lugged", 
	"content/ui/materials/icons/item_types/eye_color", 
	"content/ui/materials/icons/circumstances/ventilation_purge_01", 
}

---@class SessionEntry : EditorDoc
---@field data BlockData
---@field block Block

---@class Session
local Session = {}

---@type BlockData[]
local datas = {}
---@type Block[]
local blocks = {}

---@type CanvasData
local canvas = Schema.empty_canvas()
local loaded = false

local EMPTY_NODES = {}

---@type Block?
Session.force_block = nil
---@type Block?
Session.force_hover_block = nil
---@type table<table, boolean>?
Session.force_nodes = nil

---@param block Block?
---@param nodes table<table, boolean>?
---@param hover_block Block?
function Session.set_force_visible(block, nodes, hover_block)
	Session.force_block = block
	Session.force_nodes = nodes
	Session.force_hover_block = hover_block
end

---@type table<table, boolean>
Session.hidden_blocks = {}

---@type table<table, number>
Session.block_scales = {}

---@param block Block?
---@return number
function Session.scale_of(block)
	if block == nil then
		return 1
	end
	local live = Session.block_scales[block]
	if live then
		return live
	end
	local rec = block.scale
	local static = rec and rec.value
	return (type(static) == "number" and static) or 1
end

---@param block Block?
---@return boolean
function Session.is_hidden(block)
	return block ~= nil and Session.hidden_blocks[block] == true
end

---@return boolean
function Session.hides_hidden_blocks()
	return Session.canvas().hide_hidden_in_editor == true
end

local function clear(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
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

local BLOCK_COPY_NUDGE = 16
local NODE_COPY_NUDGE = 8

local MATERIAL_SLOTS = { "material", "material_fallback" }

---@param node Node
---@param mats string[]
local function collect_node_materials(node, mats)
	local values, style = node.values, node.style
	for i = 1, #MATERIAL_SLOTS do
		local slot = MATERIAL_SLOTS[i]
		local m = (values and values[slot]) or (style and style[slot])
		if type(m) == "string" and m ~= "" then
			mats[#mats + 1] = m
		end
	end
end

---@param nodes Node[]
local function require_node_materials(nodes)
	local mats = {}
	for j = 1, #nodes do
		local node = nodes[j]
		collect_node_materials(node, mats)
	end
	if #mats > 0 then
		MaterialDeps.require_all(mats)
	end
end

---@return string[]
local function index_names()
	local names = {}
	for i = 1, #datas do
		names[i] = datas[i].name
	end
	return names
end

Session.TRASH_FOLDER = Schema.TRASH_FOLDER

---@param name any
---@return boolean
function Session.is_trash_folder(name)
	return name == Schema.TRASH_FOLDER
end

---@param block Block|BlockData|nil
---@return boolean
function Session.is_trashed(block)
	return Session.folder_of(block) == Schema.TRASH_FOLDER
end

---@param block Block|BlockData|nil
---@return string?
function Session.folder_of(block)
	local folder = block and block.folder
	if type(folder) ~= "string" or folder == "" then
		return nil
	end
	return folder
end

---@param block Block|BlockData|nil
---@return boolean
function Session.is_mod_block(block)
	return type(block) == "table" and type(block.origin) == "table"
end

---@param name string?
---@return FolderData?
function Session.folder_record(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return Session.canvas().folders[name]
end

---@param name string?
---@return boolean
function Session.folder_exists(name)
	return Session.folder_record(name) ~= nil
end

---@param name string?
---@return boolean
function Session.folder_shown(name)
	if Session.is_trash_folder(name) then

		return false
	end
	local rec = Session.folder_record(name)
	return not (rec and rec.visible == false)
end

---@param block Block|BlockData|nil
---@return boolean
function Session.folder_hidden(block)
	local folder = Session.folder_of(block)
	if not folder then
		return false
	end
	return not Session.folder_shown(folder)
end

---@return boolean changed  the arrays were reordered (the caller rewrites the index)
local function normalize_folders()
	local n = #blocks
	if n == 0 then
		return false
	end

	local user_runs = {} 
	local trash = {} 
	local root = {} 
	for i = 1, n do
		local block = blocks[i]
		local entry = { data = datas[i], block = block }
		local folder = Session.folder_of(block)
		if Session.is_trash_folder(folder) then
			trash[#trash + 1] = entry
		elseif folder then
			local run = user_runs[folder]
			if not run then
				run = {}
				user_runs[folder] = run
			end
			run[#run + 1] = entry
		else
			root[#root + 1] = entry
		end
	end

	local ordered = {}
	local function append(run)
		for j = 1, #run do
			ordered[#ordered + 1] = run[j]
		end
	end

	append(trash)

	append(root)

	local order = Session.folder_order()
	local placed = {}
	for k = #order, 1, -1 do
		local run = user_runs[order[k]]
		if run then
			placed[order[k]] = true
			append(run)
		end
	end

	for name, run in pairs(user_runs) do
		if not placed[name] then
			append(run)
		end
	end

	local changed = false
	for i = 1, n do
		if blocks[i] ~= ordered[i].block then
			changed = true
			break
		end
	end
	if not changed then
		return false
	end
	for i = 1, n do
		datas[i] = ordered[i].data
		blocks[i] = ordered[i].block
	end
	return true
end

---@return boolean ok
---@return string? reason
function Session.renormalize()
	if not normalize_folders() then
		return true
	end
	return Store.write_index(index_names())
end

local function adopt_block_folders()
	local folders = canvas.folders

	folders[Schema.TRASH_FOLDER] = folders[Schema.TRASH_FOLDER] or {}
	for i = 1, #blocks do
		local folder = Session.folder_of(blocks[i])
		if folder and not folders[folder] then
			folders[folder] = {}
		end
	end
end

function Session.reload()

	history().reset()
	clear(datas)
	clear(blocks)

	for block in pairs(Session.hidden_blocks) do
		Session.hidden_blocks[block] = nil
	end
	for block in pairs(Session.block_scales) do
		Session.block_scales[block] = nil
	end

	local loaded_datas = Store.load_all()
	for i = 1, #loaded_datas do
		local data = loaded_datas[i]

		local mig = data.nodes
		if mig then
			for j = 1, #mig do
				if mig[j].type == "texture" then
					mig[j].type = "rect"
				end
			end
		end
		local ok, block = pcall(Block.new, data)
		if ok and block then
			datas[#datas + 1] = data
			blocks[#blocks + 1] = block
		else
			mod.dl.log.error("failed to instantiate block '%s': %s", tostring(data.name), tostring(block))
		end
	end

	local mats = {}
	for i = 1, #CHROME_MATERIALS do
		mats[#mats + 1] = CHROME_MATERIALS[i]
	end
	for i = 1, #blocks do
		local ns = blocks[i].nodes
		for j = 1, #ns do
			collect_node_materials(ns[j], mats)
		end
	end
	if #mats > 0 then
		MaterialDeps.require_all(mats)
	end

	local loaded_canvas = Store.load_canvas()
	canvas.version = Schema.CURRENT_VERSION
	canvas.grid_rows = (loaded_canvas and loaded_canvas.grid_rows) or 0
	canvas.grid_cols = (loaded_canvas and loaded_canvas.grid_cols) or 0

	canvas.vanilla = (loaded_canvas and loaded_canvas.vanilla) or {}

	canvas.hide_hidden_in_editor = (loaded_canvas and loaded_canvas.hide_hidden_in_editor) or nil

	local loaded_buffs_offset = loaded_canvas and loaded_canvas.buffs_offset
	if
		type(loaded_buffs_offset) == "table"
		and type(loaded_buffs_offset[1]) == "number"
		and type(loaded_buffs_offset[2]) == "number"
	then
		canvas.buffs_offset = { loaded_buffs_offset[1], loaded_buffs_offset[2] }
	else
		canvas.buffs_offset = nil
	end

	canvas.folders = Schema.sanitize_folders(loaded_canvas and loaded_canvas.folders)

	loaded = true

	adopt_block_folders()
	if normalize_folders() then

		local iok, ireason = Store.write_index(index_names())
		if not iok then
			mod.dl.log.error("failed to write block index after folder normalize: %s", tostring(ireason))
		end
	end
end

---@return integer changed
function Session.refresh_requires()
	if not loaded then
		return 0
	end
	local changed = 0
	for i = 1, #blocks do
		if blocks[i]:refresh_requires() then
			changed = changed + 1
		end
	end
	return changed
end

---@return Block[]
function Session.blocks()
	if not loaded then
		Session.reload()
	end
	return blocks
end

---@return integer
function Session.count()
	if not loaded then
		Session.reload()
	end
	return #blocks
end

---@param i integer
---@return Block?
function Session.block_at(i)
	return blocks[i]
end

---@param block Block|BlockData|nil
---@return integer?
function Session.index_of(block)
	if block == nil then
		return nil
	end
	for i = 1, #blocks do
		if blocks[i] == block or datas[i] == block then
			return i
		end
	end
	return nil
end

---@param block Block|nil
---@param node Node|nil
---@return integer? bi
---@return integer? ni
function Session.node_index(block, node)
	if block == nil then
		for bi = 1, #blocks do
			local found_bi, found_ni = Session.node_index(blocks[bi], node)
			if found_ni then
				return found_bi, found_ni
			end
		end
		return nil, nil
	end
	local bi = Session.index_of(block)
	local nodes = bi and blocks[bi].nodes
	if not nodes then
		return nil, nil
	end
	for ni = 1, #nodes do
		if nodes[ni] == node then
			return bi, ni
		end
	end
	return bi, nil
end

---@param i integer
---@return BlockData?
function Session.block_data(i)
	return datas[i]
end

---@return CanvasData
function Session.canvas()
	if not loaded then
		Session.reload()
	end
	return canvas
end

---@return boolean ok
---@return string? reason
function Session.save_canvas()
	return Store.save_canvas(canvas)
end

---@param tr table?
---@return table? pruned
local function prune_transition(tr)
	if tr and not tr.fade_in and not tr.fade_out then
		return nil
	end
	return tr
end

---@param i integer
---@return boolean ok
---@return string? reason
function Session.save(i)
	local data, block = datas[i], blocks[i]
	if not data or not block then
		return false, "no block at index " .. tostring(i)
	end

	local off = block.offset
	data.offset[1] = off[1]
	data.offset[2] = off[2]

	data.visible = block.visible

	data.scale = block.scale

	data.script = block.script

	block.transition = prune_transition(block.transition)
	data.transition = block.transition

	local nodes = block.nodes
	for n = 1, #nodes do
		local style = nodes[n].style
		if style then
			style.transition = prune_transition(style.transition)
		end
	end

	data.gamemodes = block.gamemodes
	data.classes = block.classes

	data.players = block.players

	data.folder = block.folder

	data.trashed_from = block.trashed_from
	data.deleted_nodes = block.deleted_nodes
	data.grid_rows = block.grid_rows
	data.grid_cols = block.grid_cols

	data.requires = block.requires
	data.tags = block.tags
	data.summary = block.summary
	data.mod_version = block.mod_version
	data.export_mod = block.export_mod

	data.origin = block.origin

	return Store.save_block(data)
end

---@return integer? index
---@return string? reason
function Session.add_block()
	if not loaded then
		Session.reload()
	end
	local existing = {}
	for i = 1, #datas do
		existing[datas[i].name] = true
	end
	local n, name = 1, nil
	repeat
		name = "block_" .. n
		n = n + 1
	until not existing[name]

	local data = Schema.empty_block(name)
	local ok, block = pcall(Block.new, data)
	if not ok or not block then
		return nil, tostring(block)
	end

	datas[#datas + 1] = data
	blocks[#blocks + 1] = block

	local sok, sreason = Store.save_block(data)
	if not sok then
		mod.dl.log.error("failed to save new block '%s': %s", name, tostring(sreason))
	end
	local iok, ireason = Store.write_index(index_names())
	if not iok then
		mod.dl.log.error("failed to write block index: %s", tostring(ireason))
	end

	history().record(history().call("remove_block", data), history().call("insert_block", data, #blocks))
	return #blocks
end

---@param data BlockData
---@param at_index integer?
---@return integer? index
---@return string? reason
function Session.insert_block(data, at_index)
	if not loaded then
		Session.reload()
	end
	if type(data) ~= "table" then
		return nil, "no block data"
	end

	local existing = {}
	for n = 1, #datas do
		existing[datas[n].name] = true
	end
	local base = Schema.slugify(data.label or data.name or "")
	if base == "" then
		base = "block"
	end
	local name, suffix = base, 2
	while existing[name] do
		name = base .. "_" .. suffix
		suffix = suffix + 1
	end
	data.name = name

	local ok, block = pcall(Block.new, data)
	if not ok or not block then
		return nil, tostring(block)
	end

	local at = at_index or (#blocks + 1)
	if at < 1 then
		at = 1
	elseif at > #blocks + 1 then
		at = #blocks + 1
	end
	table.insert(datas, at, data)
	table.insert(blocks, at, block)

	local new_i = at
	if normalize_folders() then
		for n = 1, #blocks do
			if blocks[n] == block then
				new_i = n
				break
			end
		end
	end

	require_node_materials(block.nodes or {})

	local sok, sreason = Store.save_block(data)
	if not sok then
		mod.dl.log.error("failed to save block '%s': %s", name, tostring(sreason))
	end
	local iok, ireason = Store.write_index(index_names())
	if not iok then
		mod.dl.log.error("failed to write block index: %s", tostring(ireason))
	end
	history().record(history().call("remove_block", data), history().call("insert_block", data, new_i))
	return new_i
end

local PLACEMENT_KEYS = { "name", "offset", "scale", "folder", "trashed_from", "visible" }

---@param bi integer
---@param data BlockData
---@param origin BlockOrigin  the entry's provenance at its NEW version
---@return boolean ok
---@return string? reason
function Session.update_block(bi, data, origin)
	local old = datas[bi]
	if not old or not blocks[bi] then
		return false, "no block at index " .. tostring(bi)
	end
	if type(data) ~= "table" then
		return false, "no block data"
	end

	for k = 1, #PLACEMENT_KEYS do
		local key = PLACEMENT_KEYS[k]
		data[key] = old[key]
	end
	data.origin = origin

	local ok, block = pcall(Block.new, data)
	if not ok or not block then
		return false, tostring(block)
	end

	datas[bi] = data
	blocks[bi] = block

	Session.set_force_visible(nil, nil, nil)
	require_node_materials(block.nodes or {})

	return Session.save(bi)
end

---@param i integer
---@return integer? index
---@return string? reason
function Session.duplicate_block(i)
	if not loaded then
		Session.reload()
	end
	local src = datas[i]
	if not src then
		return nil, "no block at index " .. tostring(i)
	end

	local data = deep_copy(src)

	if data.origin and data.origin.requires and not data.requires then
		data.requires = deep_copy(data.origin.requires)
	end
	data.origin = nil

	local src_label = src.label or src.name
	data.label = src_label .. " copy"

	local nudge = not mod:get("editor_duplicate_in_place") and BLOCK_COPY_NUDGE or 0

	data.offset = data.offset or { 0, 0 }
	data.offset[1] = (data.offset[1] or 0) + nudge
	data.offset[2] = (data.offset[2] or 0) + nudge

	return Session.insert_block(data, i + 1)
end

---@param bi integer
---@param ni integer
---@return integer? new_ni
---@return string? reason
function Session.duplicate_node(bi, ni)
	local block = blocks[bi]
	if not block or not block.nodes or not block.nodes[ni] then
		return nil, "no node " .. tostring(ni) .. " in block " .. tostring(bi)
	end
	if Session.is_mod_block(block) then
		return nil, "mod blocks cannot be edited"
	end
	local src = block.nodes[ni]
	local copy = deep_copy(src)

	local base = tostring(src.id or src.type or "node") .. "_copy"
	local function id_taken(candidate)
		for n = 1, #block.nodes do
			if block.nodes[n].id == candidate then
				return true
			end
		end
		return false
	end
	local id, suffix = base, 2
	while id_taken(id) do
		id = base .. "_" .. suffix
		suffix = suffix + 1
	end
	copy.id = id

	local nudge = not mod:get("editor_duplicate_in_place") and NODE_COPY_NUDGE or 0

	copy.offset = copy.offset or { 0, 0 }
	copy.offset[1] = (copy.offset[1] or 0) + nudge
	copy.offset[2] = (copy.offset[2] or 0) + nudge

	table.insert(block.nodes, ni + 1, copy)
	history().record(history().call("remove_node", block, copy), history().call("insert_node", block, copy, ni + 1))
	block:recompile()

	require_node_materials({ copy })

	local ok, reason = Session.save(bi)
	if not ok then
		mod.dl.log.error("failed to save block: %s", tostring(reason))
	end
	return ni + 1
end

---@param i integer
---@return boolean ok
---@return string? reason
function Session.remove_block(i)
	local data = datas[i]
	if not data then
		return false, "no block at index " .. tostring(i)
	end
	table.remove(datas, i)
	table.remove(blocks, i)
	local iok, ireason = Store.write_index(index_names())
	if not iok then
		return false, ireason
	end

	history().record(history().call("insert_block", data, i), history().call("remove_block", data))
	return true
end

---@param from integer
---@param to integer
---@return integer? index
---@return string? reason
function Session.move_block(from, to)
	local n = #blocks
	if from < 1 or from > n then
		return nil, "no block at index " .. tostring(from)
	end
	to = math.max(1, math.min(n, to))
	if to == from then
		return from
	end
	local block = blocks[from]
	table.insert(datas, to, table.remove(datas, from))
	table.insert(blocks, to, table.remove(blocks, from))
	local iok, ireason = Store.write_index(index_names())
	if not iok then
		return nil, ireason
	end

	history().record(history().call("move_block", block, from), history().call("move_block", block, to))
	return to
end

---@param from integer
---@param count integer
---@param to integer
---@return integer? index  the run's new first index
---@return string? reason
function Session.move_block_range(from, count, to)
	local n = #blocks
	if count == nil or count < 1 then
		return nil, "count must be >= 1"
	end
	if from < 1 or from + count - 1 > n then
		return nil, "no run of " .. tostring(count) .. " blocks at " .. tostring(from)
	end
	to = math.max(1, math.min(n - count + 1, to))
	if to == from then
		return from
	end

	local head = blocks[from]

	local run_datas, run_blocks = {}, {}
	for j = 1, count do
		run_datas[j] = table.remove(datas, from)
		run_blocks[j] = table.remove(blocks, from)
	end
	for j = count, 1, -1 do
		table.insert(datas, to, run_datas[j])
		table.insert(blocks, to, run_blocks[j])
	end

	local iok, ireason = Store.write_index(index_names())
	if not iok then
		return nil, ireason
	end
	history().record(
		history().call("move_block_range", head, count, from),
		history().call("move_block_range", head, count, to)
	)
	return to
end

---@param name string?
---@return integer? first
---@return integer? last
function Session.folder_bounds(name)
	if type(name) ~= "string" or name == "" then
		return nil, nil
	end
	local first, last
	for i = 1, #blocks do
		if Session.folder_of(blocks[i]) == name then
			first = first or i
			last = i
		end
	end
	return first, last
end

---@return string[]
function Session.folder_order()
	local folders = Session.canvas().folders
	local out = {}
	for name in pairs(folders) do

		if not Session.is_trash_folder(name) then
			out[#out + 1] = name
		end
	end
	table.sort(out, function(a, b)
		local ia, ib = folders[a].index, folders[b].index
		if ia ~= ib then
			if ia == nil then
				return false
			end
			if ib == nil then
				return true
			end
			return ia < ib
		end
		return a < b
	end)
	return out
end

---@param name string
---@param dir integer  -1 up, +1 down
---@return boolean moved
function Session.move_folder(name, dir)
	if Session.is_trash_folder(name) then
		return false 
	end
	local order = Session.folder_order()
	local pos
	for i = 1, #order do
		if order[i] == name then
			pos = i
			break
		end
	end
	local target = pos and (pos + dir)
	if not target or target < 1 or target > #order then
		return false
	end
	order[pos], order[target] = order[target], order[pos]

	history().record(history().call("move_folder_to", name, pos), history().call("move_folder_to", name, target))
	local folders = Session.canvas().folders
	for i = 1, #order do
		folders[order[i]].index = i
	end
	local ok, reason = Session.renormalize()
	if not ok then
		mod.dl.log.error("failed to reorder folders: %s", tostring(reason))
	end
	return true
end

---@param name string
---@return boolean ok
---@return string? reason
function Session.folder_create(name)
	if not Schema.is_valid_folder_name(name) then
		return false, "not a valid folder name"
	end
	local folders = Session.canvas().folders
	if folders[name] then
		return false, "a folder called '" .. name .. "' already exists"
	end

	local min_index = 1
	for _, rec in pairs(folders) do
		if rec.index and rec.index < min_index then
			min_index = rec.index
		end
	end
	folders[name] = { index = min_index - 1 }
	history().record(history().call("folder_remove", name), history().call("folder_create", name))
	return Session.save_canvas()
end

---@param old string
---@param new string
---@return boolean ok
---@return string? reason
function Session.folder_rename(old, new)
	if Session.is_trash_folder(old) then
		return false, "the trash folder cannot be renamed"
	end
	if not Schema.is_valid_folder_name(new) then
		return false, "not a valid folder name"
	end
	local folders = Session.canvas().folders
	local rec = folders[old]
	if not rec then
		return false, "no folder called '" .. tostring(old) .. "'"
	end
	if new == old then
		return true
	end
	if folders[new] then
		return false, "a folder called '" .. new .. "' already exists"
	end

	folders[new] = rec
	folders[old] = nil
	for i = 1, #blocks do
		if Session.folder_of(blocks[i]) == old then
			blocks[i].folder = new
			local ok, reason = Session.save(i)
			if not ok then
				mod.dl.log.error("failed to save block after folder rename: %s", tostring(reason))
			end
		end
	end
	return Session.save_canvas()
end

---@param name string
---@return boolean ok
---@return string? reason
function Session.folder_remove(name)
	if Session.is_trash_folder(name) then
		return false, "the trash folder cannot be removed"
	end
	local folders = Session.canvas().folders
	if not folders[name] then
		return false, "no folder called '" .. tostring(name) .. "'"
	end

	local members = {}
	for i = 1, #blocks do
		if Session.folder_of(blocks[i]) == name then
			members[#members + 1] = blocks[i]
		end
	end
	for m = 1, #members do
		local bi
		for i = 1, #blocks do
			if blocks[i] == members[m] then
				bi = i
				break
			end
		end
		local ok, reason = bi and Session.trash_block(bi)
		if not ok then
			mod.dl.log.error("failed to trash block on folder remove: %s", tostring(reason))
		end
	end

	folders[name] = nil

	history().record(history().call("folder_create", name), history().call("folder_remove", name))
	return Session.save_canvas()
end

---@param name string
---@param visible boolean
---@return boolean ok
---@return string? reason
function Session.set_folder_visible(name, visible)
	if Session.is_trash_folder(name) then
		return false, "the trash folder is always hidden"
	end
	local rec = Session.folder_record(name)
	if not rec then
		return false, "no folder called '" .. tostring(name) .. "'"
	end

	local was = rec.visible ~= false
	if visible == false then
		rec.visible = false
	else
		rec.visible = nil
	end
	history().record(
		history().call("set_folder_visible", name, was),
		history().call("set_folder_visible", name, visible)
	)
	return Session.save_canvas()
end

---@param bi integer
---@param folder string|nil
---@return integer? index
---@return string? reason
function Session.set_block_folder(bi, folder)
	local block = blocks[bi]
	if not block then
		return nil, "no block at index " .. tostring(bi)
	end
	if folder ~= nil and not Session.canvas().folders[folder] then
		return nil, "no folder called '" .. tostring(folder) .. "'"
	end
	if Session.folder_of(block) == folder then
		return bi
	end
	local from_folder = Session.folder_of(block)

	if Session.is_trash_folder(folder) then
		block.trashed_from = Session.folder_of(block)
	else
		block.trashed_from = nil
	end

	local dest
	if folder then
		local _, last = Session.folder_bounds(folder)
		block.folder = folder
		if last then
			dest = (last > bi) and last or (last + 1)
		elseif Session.is_trash_folder(folder) then

			dest = 1
		else

			dest = #blocks
		end
	else
		block.folder = nil
		dest = #blocks
	end

	local new_i = bi
	if dest ~= bi then
		local moved = Session.move_block(bi, dest)
		if not moved then
			return nil, "failed to reorder into folder"
		end
		new_i = moved
	end

	local ok, reason = Session.save(new_i)
	if not ok then
		return nil, reason
	end

	history().record(
		history().call("set_block_folder", block, from_folder),
		history().call("set_block_folder", block, folder)
	)
	return new_i
end

---@param bi integer
---@return boolean ok
---@return string? reason
function Session.trash_block(bi)
	local block = blocks[bi]
	if not block then
		return false, "no block at index " .. tostring(bi)
	end
	if Session.is_trashed(block) then
		return true
	end
	local new_i, reason = Session.set_block_folder(bi, Schema.TRASH_FOLDER)
	if not new_i then
		return false, reason
	end
	return true
end

---@param bi integer
---@return integer? index
---@return string? reason
function Session.restore_block(bi)
	local block = blocks[bi]
	if not block then
		return nil, "no block at index " .. tostring(bi)
	end
	if not Session.is_trashed(block) then
		return bi
	end
	local home = block.trashed_from
	if home and not Session.canvas().folders[home] then
		home = nil 
	end
	return Session.set_block_folder(bi, home)
end

---@return integer[]
function Session.trash_indices()
	local out = {}
	for i = #blocks, 1, -1 do
		if Session.is_trashed(blocks[i]) then
			out[#out + 1] = i
		end
	end
	return out
end

---@return integer
function Session.trash_count()
	local n = 0
	for i = 1, #blocks do
		if Session.is_trashed(blocks[i]) then
			n = n + 1
		end
	end
	return n
end

---@return integer removed
function Session.empty_trash()
	local indices = Session.trash_indices()
	for k = 1, #indices do
		local ok, reason = Session.remove_block(indices[k])
		if not ok then
			mod.dl.log.error("failed to empty trash: %s", tostring(reason))
		end
	end
	return #indices
end

---@param block Block|nil
---@return Node[]
function Session.deleted_nodes(block)
	return (block and block.deleted_nodes) or EMPTY_NODES
end

---@param bi integer
---@param ni integer
---@return boolean ok
---@return string? reason
function Session.delete_node(bi, ni)
	local block = blocks[bi]
	if not block or not block.nodes or not block.nodes[ni] then
		return false, "no node " .. tostring(ni) .. " on block " .. tostring(bi)
	end
	if Session.is_mod_block(block) then
		return false, "mod blocks cannot be edited"
	end

	local node = table.remove(block.nodes, ni)
	local bin = block.deleted_nodes
	if not bin then
		bin = {}
		block.deleted_nodes = bin
	end

	table.insert(bin, 1, node)
	block:recompile()

	local ok, reason = Session.save(bi)
	if not ok then
		return false, reason
	end
	history().record(history().call("restore_node", block, node), history().call("delete_node", block, node))
	return true
end

---@param bi integer
---@param di integer
---@return integer? ni
---@return string? reason
function Session.restore_node(bi, di)
	local block = blocks[bi]
	if Session.is_mod_block(block) then
		return nil, "mod blocks cannot be edited"
	end
	local bin = block and block.deleted_nodes
	if not bin or not bin[di] then
		return nil, "no deleted node " .. tostring(di) .. " on block " .. tostring(bi)
	end

	local node = table.remove(bin, di)
	if #bin == 0 then
		block.deleted_nodes = nil 
	end
	block.nodes[#block.nodes + 1] = node
	block:recompile()

	require_node_materials({ node })

	local ok, reason = Session.save(bi)
	if not ok then
		return nil, reason
	end
	history().record(history().call("delete_node", block, node), history().call("restore_node", block, node))
	return #block.nodes
end

---@param bi integer
---@param di integer
---@return boolean ok
---@return string? reason
function Session.purge_node(bi, di)
	local block = blocks[bi]
	if Session.is_mod_block(block) then
		return false, "mod blocks cannot be edited"
	end
	local bin = block and block.deleted_nodes
	if not bin or not bin[di] then
		return false, "no deleted node " .. tostring(di) .. " on block " .. tostring(bi)
	end
	table.remove(bin, di)
	if #bin == 0 then
		block.deleted_nodes = nil
	end
	return Session.save(bi)
end

---@param name string
---@param exclude_i integer
---@return boolean
local function name_taken(name, exclude_i)
	for n = 1, #datas do
		if n ~= exclude_i and datas[n].name == name then
			return true
		end
	end
	return false
end

---@param block Block
---@param label string
---@return boolean ok
---@return string? reason
function Session.set_block_label(block, label)

	if Session.is_mod_block(block) then
		return false, "mod blocks cannot be renamed"
	end
	local i
	for n = 1, #blocks do
		if blocks[n] == block then
			i = n
			break
		end
	end
	if not i then
		return false, "block is not in the active session"
	end
	local data = datas[i]

	local was = block.label or ""

	local trimmed = tostring(label or ""):gsub("^%s+", ""):gsub("%s+$", "")
	block.label = (trimmed ~= "" and trimmed) or nil
	data.label = block.label

	local base = Schema.slugify(trimmed)
	if base == "" then
		base = "block"
	end
	local name, suffix = base, 2
	while name_taken(name, i) do
		name = base .. "_" .. suffix
		suffix = suffix + 1
	end
	local renamed = name ~= data.name
	data.name = name
	block.name = name

	local sok, sreason = Store.save_block(data)
	if not sok then
		return false, sreason
	end
	if renamed then
		local iok, ireason = Store.write_index(index_names())
		if not iok then
			return false, ireason
		end
	end

	history().record(history().call("set_block_label", block, was), history().call("set_block_label", block, trimmed))
	return true
end

mod.hud_studio_session = Session

return Session
