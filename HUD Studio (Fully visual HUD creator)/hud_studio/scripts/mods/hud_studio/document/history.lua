---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_history then
	return mod.hud_studio_history
end

local Session
local function session()
	Session = Session or mod:core(mod.hud_studio_session, "document/session")
	return Session
end

---@class History
local History = {}

local unpack = table.unpack or unpack

local UNDO_CAP = 500

local MERGE_WINDOW = 0.3

local stack = {}

local cursor = 0

local depth = 0
local open_step = nil

local applying = false

local suspended = 0

local now_t = 0
local last_push_t = nil

---@param op string
---@return table call
function History.call(op, ...)
	return { n = select("#", ...) + 1, op, ... }
end

---@generic T
---@param v T
---@return T
function History.copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, item in pairs(v) do
		out[k] = History.copy(item)
	end
	return out
end

function History.reset()
	stack = {}
	cursor = 0
	depth = 0
	open_step = nil
	applying = false
	last_push_t = nil
end

function History.begin()
	if applying then
		return
	end
	depth = depth + 1
end

local function push_step(step)

	for i = #stack, cursor + 1, -1 do
		stack[i] = nil
	end
	stack[#stack + 1] = step
	cursor = #stack
	if #stack > UNDO_CAP then
		table.remove(stack, 1)
		cursor = cursor - 1
	end
end

function History.commit()
	if applying or depth == 0 then
		return
	end
	depth = depth - 1
	if depth > 0 then
		return
	end
	local step = open_step
	open_step = nil
	if step and #step > 0 then
		push_step(step)
	end
end

function History.suspend()
	suspended = suspended + 1
end

function History.resume()
	if suspended > 0 then
		suspended = suspended - 1
	end
end

function History.resume_all()
	suspended = 0
end

---@return boolean
function History.is_suspended()
	return suspended > 0
end

---@param t number
function History.set_time(t)
	now_t = t or 0
end

local NO_MERGE = { set_shown = true, set_eye = true, checklist = true }

local SUBJECT_TAIL = { set_key = 3, set_xy = 3, set_rows = 3 }

local function merges(prev, entry)
	if not prev or not last_push_t or (now_t - last_push_t) > MERGE_WINDOW then
		return false
	end
	if NO_MERGE[entry.redo[1]] then
		return false
	end
	if prev.redo[1] ~= entry.redo[1] or prev.redo[2] ~= entry.redo[2] or prev.redo.n ~= entry.redo.n then
		return false
	end

	local tail = SUBJECT_TAIL[entry.redo[1]]
	return tail == nil or prev.redo[tail] == entry.redo[tail]
end

---@param undo table  History.call(...) to go back
---@param redo table  History.call(...) to go forward
function History.record(undo, redo)
	if applying or suspended > 0 then
		return
	end
	local entry = { undo = undo, redo = redo }

	local open_prev = open_step and open_step[#open_step]
	local top = stack[cursor]
	local prev = open_prev or (top and #top == 1 and top[1] or nil)
	if merges(prev, entry) then

		prev.redo = redo
	elseif depth > 0 then
		open_step = open_step or {} 
		open_step[#open_step + 1] = entry
	else
		push_step({ entry })
	end
	last_push_t = now_t
end

local function apply(call)
	local fn = History.ops[call[1]]
	if not fn then
		mod.dl.log.error("history: no op '%s'", tostring(call[1]))
		return
	end
	fn(unpack(call, 2, call.n))
end

---@return boolean
function History.can_undo()
	return cursor > 0
end

---@return boolean
function History.can_redo()
	return cursor < #stack
end

local function replay(step, side, backwards)
	applying = true
	if backwards then
		for i = #step, 1, -1 do
			apply(step[i][side])
		end
	else
		for i = 1, #step do
			apply(step[i][side])
		end
	end
	applying = false
	last_push_t = nil
end

---@return boolean applied
function History.undo()
	if applying or cursor == 0 then
		return false
	end
	replay(stack[cursor], "undo", true)
	cursor = cursor - 1
	return true
end

---@return boolean applied
function History.redo()
	if applying or cursor >= #stack then
		return false
	end
	cursor = cursor + 1
	replay(stack[cursor], "redo", false)
	return true
end

---@return integer cursor
---@return integer count
function History.state()
	return cursor, #stack
end

local function report(what, ok, reason)
	if not ok then
		mod.dl.log.error("history: %s failed: %s", what, tostring(reason))
	end
end

local function save_owner(block)
	if not block then
		report("save_canvas", session().save_canvas())
		return
	end
	local i = session().index_of(block)
	if i then
		report("save", session().save(i))
	end
end

History.ops = {

	field = function(ctrl, value, rebinds, block)
		ctrl.set(value)
		if rebinds and block then
			block:recompile()
		end
		save_owner(block)
	end,

	checklist = function(ctrl, value, block)
		ctrl.toggle(value)
		save_owner(block)
	end,

	set_xy = function(block, tbl, x, y)
		tbl[1] = x
		tbl[2] = y
		save_owner(block)
	end,

	set_key = function(block, tbl, key, value)
		tbl[key] = value
		save_owner(block)
	end,

	set_block_scale = function(block, rec)
		block.scale = rec
		save_owner(block)
	end,

	set_shown = function(block, node, on)
		local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
		if node then
			Visibility.set_node_shown(node, on)
		else
			Visibility.set_block_shown(block, on)
		end
		save_owner(block)
	end,

	set_eye = function(block, node, state)
		local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
		if node then
			Visibility.set_node_eye_state(node, state)
		else
			Visibility.set_block_eye_state(block, state)
		end
		save_owner(block)
	end,

	set_rows = function(block, spec, rows)
		spec.rows = History.copy(rows)
		block:recompile()
		save_owner(block)
	end,

	insert_node = function(block, node, at)
		table.insert(block.nodes, math.min(math.max(at, 1), #block.nodes + 1), node)
		block:recompile()
		save_owner(block)
	end,

	remove_node = function(block, node)
		local _, ni = session().node_index(block, node)
		if ni then
			table.remove(block.nodes, ni)
			block:recompile()
			save_owner(block)
		end
	end,

	move_block = function(block, to)
		local i = session().index_of(block)
		if i then
			local moved, reason = session().move_block(i, to)
			report("move_block", moved, reason)
		end
	end,

	move_block_range = function(block, count, to)
		local i = session().index_of(block)
		if i then
			local moved, reason = session().move_block_range(i, count, to)
			report("move_block_range", moved, reason)
		end
	end,

	set_block_folder = function(block, folder)
		local i = session().index_of(block)
		if i then
			local moved, reason = session().set_block_folder(i, folder)
			report("set_block_folder", moved, reason)
		end
	end,

	set_block_label = function(block, label)
		report("set_block_label", session().set_block_label(block, label))
	end,

	trash_block = function(block)
		local i = session().index_of(block)
		if i then
			report("trash_block", session().trash_block(i))
		end
	end,

	restore_block = function(block)
		local i = session().index_of(block)
		if i then
			local new_i, reason = session().restore_block(i)
			report("restore_block", new_i, reason)
		end
	end,

	remove_block = function(block)
		local i = session().index_of(block)
		if i then
			report("remove_block", session().remove_block(i))
		end
	end,

	insert_block = function(data, at)
		local i, reason = session().insert_block(data, at)
		report("insert_block", i, reason)
	end,

	restore_block_slot = function(block, folder, index, trashed_from)
		local i = session().index_of(block)
		if not i then
			return
		end
		if session().folder_of(block) ~= folder then
			i = session().set_block_folder(i, folder) or i
		end
		block.trashed_from = trashed_from
		if i ~= index then
			report("restore_block_slot", session().move_block(i, index))
			i = session().index_of(block) or i
		end
		report("save", session().save(i))
	end,

	move_folder_to = function(name, index)
		local order = session().folder_order()
		local pos
		for i = 1, #order do
			if order[i] == name then
				pos = i
				break
			end
		end
		while pos and pos ~= index do
			local dir = index > pos and 1 or -1
			if not session().move_folder(name, dir) then
				break
			end
			pos = pos + dir
		end
		report("save_canvas", session().save_canvas())
	end,

	move_node_to = function(block, node, index)
		local from_bi, from_ni = session().node_index(nil, node)
		if not from_ni then
			return
		end
		local from_block = session().block_at(from_bi)
		table.remove(from_block.nodes, from_ni)
		table.insert(block.nodes, math.min(math.max(index, 1), #block.nodes + 1), node)
		if from_block ~= block then
			from_block:recompile()
			save_owner(from_block)
		end
		block:recompile()
		save_owner(block)
	end,

	set_folder_visible = function(name, visible)
		report("set_folder_visible", session().set_folder_visible(name, visible))
	end,

	folder_create = function(name)
		report("folder_create", session().folder_create(name))
	end,

	folder_remove = function(name)
		report("folder_remove", session().folder_remove(name))
	end,

	delete_node = function(block, node)
		local bi, ni = session().node_index(block, node)
		if bi and ni then
			report("delete_node", session().delete_node(bi, ni))
		end
	end,

	restore_node = function(block, node)
		local bi = session().index_of(block)
		local bin = session().deleted_nodes(block)
		for di = 1, #bin do
			if bin[di] == node then
				local ni, reason = session().restore_node(bi, di)
				report("restore_node", ni, reason)
				return
			end
		end
	end,

	rebind = function(block, from, to, code)
		local Rebind = mod:core(mod.hud_studio_rebind, "document/rebind")
		Rebind.run(block, from, to, code)
		block:recompile()
		save_owner(block)
	end,
}

mod.hud_studio_history = History

return History
