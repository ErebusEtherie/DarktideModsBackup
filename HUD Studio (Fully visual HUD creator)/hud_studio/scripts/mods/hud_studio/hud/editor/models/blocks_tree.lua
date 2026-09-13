---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_blocks_tree then
	return mod.hud_studio_blocks_tree
end

local Session = mod:core(mod.hud_studio_session, "document/session")
local BlocksPanel = mod:core(mod.blocks_panel_component, "hud/editor/elements/blocks_panel/blocks_panel")
local EyeToggle = mod:core(mod.eye_toggle_component, "hud/editor/elements/row/eye_toggle")
local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")

local index_of = Geometry.index_of

local DEBUG_FOLDER_EYE = false

local COLLAPSED_KEY = "__hs_collapsed_blocks"

local FOLDERS_COLLAPSED_KEY = "__hs_collapsed_folders"

local AUTOSCROLL_MARGIN = 14 
local AUTOSCROLL_INTERVAL = 0.06

---@param key string
---@return table<string, boolean>
local function load_collapsed_names(key)
	local names = {}
	local stored = mod:get(key)
	if type(stored) ~= "string" then
		return names
	end
	for name in stored:gmatch("[^,]+") do
		names[name] = true
	end
	return names
end

---@class TreeRow
---@field kind "darktide"|"canvas"|"folder"|"slot"|"block"|"node"|"bin"|"delnode"
---@field bi integer|nil          block index into Session.blocks()
---@field ni integer|nil          node index within that block (real array index, whichever way rows read)
---@field folder string|nil       folder name, for folder / slot rows
---@field empty boolean|nil       slot row: its folder has no members
---@field depth integer|nil       indent level
---@field last boolean|nil        block row: last block of its folder (elbow vs tee in the guide)
---@field trunks table|nil        child row: which ancestor guide lines still run past it

---@class BlocksTree
---@field rows TreeRow[]                       flattened Blocks-tree rows, rebuilt per frame
---@field scroll integer                       rows scrolled off the top of the panel
---@field scroll_accum number                  fractional mouse-wheel accumulator for that scroll
---@field collapsed table<Block, boolean>      blocks whose node rows are folded (weak keys, by instance)
---@field collapsed_names table<string, true>  the same set as persisted: block name -> true
---@field collapsed_seeded table<Block, true>  blocks already seeded from collapsed_names (weak keys)
---@field collapsed_folders table<string, true> folded FOLDER rows, keyed by name
---@field open_bins table<Block, boolean>      blocks whose deleted-node bin is UNFOLDED (weak keys)
---@field hover_row integer|nil                row index under the cursor, or nil
---@field autoscroll_at number|nil             next time a held reorder drag steps the edge auto-scroll
---@field blocks_panel fun(): table            resolves the editor's Blocks panel
local BlocksTree = {}
BlocksTree.__index = BlocksTree

---@param blocks_panel fun(): table  resolves the editor's live Blocks panel (for its y)
---@return BlocksTree
function BlocksTree.new(blocks_panel)
	local self = setmetatable({}, BlocksTree)

	self.blocks_panel = blocks_panel

	self.rows = {}

	self.scroll = 0
	self.scroll_accum = 0

	self.collapsed = setmetatable({}, { __mode = "k" })
	self.collapsed_names = load_collapsed_names(COLLAPSED_KEY)
	self.collapsed_seeded = setmetatable({}, { __mode = "k" })

	self.collapsed_folders = load_collapsed_names(FOLDERS_COLLAPSED_KEY)

	self.open_bins = setmetatable({}, { __mode = "k" })

	self.hover_row = nil

	self.autoscroll_at = nil

	return self
end

function BlocksTree:seed_collapsed()
	local blocks = Session.blocks()
	for i = 1, #blocks do
		local block = blocks[i]
		if not self.collapsed_seeded[block] then
			self.collapsed_seeded[block] = true
			if block.name and self.collapsed_names[block.name] then
				self.collapsed[block] = true
			end
		end
	end
end

---@return TreeRow[]
function BlocksTree:build_rows()
	self:seed_collapsed()
	local collapsed = self.collapsed
	local collapsed_folders = self.collapsed_folders
	local bins = self.open_bins
	return BlocksPanel.build_rows(Session.blocks(), function(block)
		return collapsed[block] == true
	end, {
		order = Session.folder_order(),

		trash = Session.TRASH_FOLDER,
		collapsed = function(name)
			return collapsed_folders[name] == true
		end,

		bin_open = function(block)
			return bins[block] == true
		end,
	})
end

---@return TreeRow[]
function BlocksTree:rebuild()
	self.rows = self:build_rows()
	return self.rows
end

---@return TreeRow[]
function BlocksTree:current_rows()
	return self.rows or self:build_rows()
end

---@param cy number  cursor y, design px
---@return number fpos      cursor position in flat rows
---@return TreeRow[] rows   this frame's row list
---@return number top       design-px y of the first visible row
function BlocksTree:row_pos(cy)
	local panel = self.blocks_panel()
	local top = panel.y + BlocksPanel.ROWS_TOP
	return (cy - top) / BlocksPanel.ROW_H + (self.scroll or 0), self:current_rows(), top
end

---@param panel table      the Blocks panel box { x, y, w, ... }
---@param flat_row integer
---@return number
function BlocksTree:row_y(panel, flat_row)
	local vis_idx = flat_row - (self.scroll or 0)
	return panel.y + BlocksPanel.ROWS_TOP + (vis_idx - 1) * BlocksPanel.ROW_H
end

---@param flat_row integer
---@return number
function BlocksTree:row_indent(flat_row)
	local r = self.rows and self.rows[flat_row]
	return ((r and r.depth) or 0) * Row.ROW_INDENT
end

---@param panel table
---@param flat_row integer
---@return table rect
function BlocksTree:row_eye_rect(panel, flat_row)
	return EyeToggle.rect(panel.x, self:row_y(panel, flat_row), panel.w, BlocksPanel.ROW_H)
end

---@param panel table
---@param flat_row integer
---@return table rect
function BlocksTree:row_caret_rect(panel, flat_row)
	return Row.caret_rect(panel.x, self:row_y(panel, flat_row), self:row_indent(flat_row))
end

---@class RowSpan
---@field start integer  first row of the run
---@field stop integer   last row of the run

---@param kind "block"|"folder"
---@return table<any, RowSpan>
function BlocksTree:spans(kind)
	local rows = self:current_rows()
	local spans = {}
	if kind == "block" then
		for i = 1, #rows do
			local bi = rows[i].bi
			if bi then
				local span = spans[bi]
				if span then
					span.stop = i
				else
					spans[bi] = { start = i, stop = i }
				end
			end
		end
		return spans
	end

	local current = nil
	for i = 1, #rows do
		local row = rows[i]
		if row.kind == "folder" then
			current = row.folder
			spans[current] = { start = i, stop = i }
		elseif row.kind == "slot" and row.root then

			current = nil
		elseif current and (row.kind == "slot" or row.depth ~= nil and row.depth > 0) then
			spans[current].stop = i
		elseif row.kind ~= "node" then
			current = nil 
		end
	end
	return spans
end

---@param span RowSpan|nil
---@return number|nil
function BlocksTree.midpoint(span)
	if not span then
		return nil
	end
	return ((span.start - 1) + span.stop) / 2
end

---@param block Block|nil
---@return boolean
function BlocksTree:bin_open(block)
	return block ~= nil and self.open_bins[block] == true
end

---@param block Block|nil
function BlocksTree:toggle_bin_open(block)
	if not block then
		return
	end
	self.open_bins[block] = (not self.open_bins[block]) or nil
end

---@param name string
---@return boolean
function BlocksTree:folder_collapsed(name)
	return self.collapsed_folders[name] == true
end

function BlocksTree:store_collapsed_folders()
	local names = {}
	for name, folded in pairs(self.collapsed_folders) do
		if folded then
			names[#names + 1] = name
		end
	end

	table.sort(names)
	mod:set(FOLDERS_COLLAPSED_KEY, table.concat(names, ","))
end

---@param name string
function BlocksTree:toggle_folder_collapsed(name)
	self.collapsed_folders[name] = (not self.collapsed_folders[name]) or nil
	self:store_collapsed_folders()
end

function BlocksTree:store_collapsed()
	local blocks = Session.blocks()
	local names = {}
	for i = 1, #blocks do
		local block = blocks[i]
		if self.collapsed[block] and block.name then
			names[#names + 1] = block.name
		end
	end
	mod:set(COLLAPSED_KEY, table.concat(names, ","))

	local by_name = {}
	for i = 1, #names do
		by_name[names[i]] = true
	end
	self.collapsed_names = by_name
end

---@return boolean
function BlocksTree:all_collapsed()
	local blocks = Session.blocks()
	if #blocks == 0 then
		return false
	end
	for i = 1, #blocks do
		if not self.collapsed[blocks[i]] then
			return false
		end
	end
	return true
end

function BlocksTree:toggle_collapse_all()
	self:seed_collapsed()
	local collapse = not self:all_collapsed()
	local blocks = Session.blocks()
	for i = 1, #blocks do
		self.collapsed[blocks[i]] = collapse or nil
	end
	self:store_collapsed()
end

---@param name string
---@param next_on boolean
function BlocksTree:toggle_folder_visible(name, next_on)
	local was = Session.folder_shown(name)
	local ok, reason = Session.set_folder_visible(name, next_on and true or false)
	if not ok then
		mod.dl.log.error("failed to toggle folder '%s': %s", tostring(name), tostring(reason))
	end

	if DEBUG_FOLDER_EYE then
		mod.dl.log.echo(
			string.format(
				"[folder eye] %s: was=%s want=%s ok=%s reason=%s now=%s record=%s",
				tostring(name),
				tostring(was),
				tostring(next_on and true or false),
				tostring(ok),
				tostring(reason),
				tostring(Session.folder_shown(name)),
				tostring(Session.folder_record(name))
			)
		)
	end
end

---@class ReorderDrag
---@field kind "reorder"|"reorder_block"|"reorder_folder"
---@field bi integer|nil        node drag: the block the node currently lives in (follows it across blocks)
---@field node Node|nil         node drag: the dragged node, tracked by reference
---@field block Block|nil       block drag: the dragged block, by reference -- a move shifts every index
---@field folder string|nil     folder drag: the dragged folder's name
---@field locked boolean|nil    folder drag: a mod or trash folder, pinned by the normalize pass
---@field dir 1|-1|nil          node drag: remembered direction of travel (see the note in update_node_reorder)
---@field last_cy number|nil    node drag: the cy `dir` was last sampled at
---@field changed boolean|nil   something actually moved, so the release must save
---@field saves table<integer, true>|nil  block indices whose files the release must write
---@field refiled table<Block, true>|nil  blocks whose folder membership this drag rewrote

---@class ReorderCtx
---@field sel_block integer|nil   selected block index
---@field sel_node integer|nil    selected node within it; nil = block-level
---@field edit_block integer|nil  block in node-editing mode

---@param ctx ReorderCtx
---@param drag ReorderDrag
---@param cy number
function BlocksTree:update_node_reorder(ctx, drag, cy)
	local block = Session.block_at(drag.bi)
	if not block then
		return
	end
	local nodes = block.nodes
	local cur = index_of(nodes, drag.node)
	if not cur then
		return
	end

	local fpos, rows = self:row_pos(cy)

	local last_cy = drag.last_cy
	if last_cy and math.abs(cy - last_cy) >= 1 then
		drag.dir = cy > last_cy and 1 or -1
		drag.last_cy = cy
	elseif not last_cy then
		drag.last_cy = cy
	end

	local over = math.floor(fpos) + 1

	local row = rows[over]
	local dest_bi, target = nil, nil
	if row and row.kind == "node" then
		dest_bi, target = row.bi, row.ni
	elseif row and row.kind == "block" and self.collapsed[Session.block_at(row.bi)] then

		local step = drag.dir
		if not step then
			local own_row = nil
			for idx = 1, #rows do
				local r = rows[idx]
				if r.kind == "node" and r.bi == drag.bi and r.ni == cur then
					own_row = idx
					break
				end
			end
			step = own_row and (over < own_row and -1 or 1) or nil
		end
		if step then
			for idx = over + step, step < 0 and 1 or #rows, step do
				local r = rows[idx]
				if r.kind == "node" then

					dest_bi, target = r.bi, r.ni
					break
				elseif r.kind == "block" then
					if not self.collapsed[Session.block_at(r.bi)] then

						dest_bi, target = r.bi, step < 0 and 1 or math.huge
						break
					end

				elseif r.kind ~= "folder" and r.kind ~= "slot" then
					break 
				end

			end
		end
	elseif row then
		dest_bi, target = row.bi, math.huge 
	else

		local first_row, top_ni, bottom_ni = nil, nil, nil
		for idx = 1, #rows do
			local r = rows[idx]
			if r.kind == "node" and r.bi == drag.bi then
				first_row = first_row or idx
				top_ni = top_ni or r.ni
				bottom_ni = r.ni
			end
		end
		dest_bi = drag.bi
		target = (first_row and over < first_row) and top_ni or bottom_ni
	end
	local dest = dest_bi and Session.block_at(dest_bi)
	if not dest or not target then
		return
	end

	if Session.is_mod_block(dest) or Session.is_mod_block(block) then
		return
	end

	if dest_bi == drag.bi then

		if math.min(target, #nodes) == cur then
			return
		end
		table.remove(nodes, cur)
		target = math.min(target, #nodes + 1)
		table.insert(nodes, target, drag.node)
		block:recompile()
	else
		table.remove(nodes, cur)
		target = math.min(target, #dest.nodes + 1)
		table.insert(dest.nodes, target, drag.node)
		block:recompile()
		dest:recompile()

		if self.collapsed[dest] then
			self.collapsed[dest] = nil
			self:store_collapsed()
		end
		if ctx.edit_block == drag.bi then
			ctx.edit_block = dest_bi
		end
		drag.saves = drag.saves or {}
		drag.saves[drag.bi] = true
		drag.saves[dest_bi] = true
		drag.bi = dest_bi
	end

	drag.changed = true

	if ctx.sel_node then
		ctx.sel_block = dest_bi
		ctx.sel_node = index_of(dest.nodes, drag.node)
	end
end

---@param ctx ReorderCtx
---@param drag ReorderDrag
---@param cy number
function BlocksTree:update_block_reorder(ctx, drag, cy)
	local cur = index_of(Session.blocks(), drag.block)
	if not cur then
		return
	end
	local fpos, rows = self:row_pos(cy)

	local block_spans = self:spans("block")

	local function swap_to(new_index, new_folder, keep_folder)
		local new_i = Session.move_block(cur, new_index)
		if not new_i then
			return
		end
		drag.changed = true
		if ctx.sel_block == cur then
			ctx.sel_block = new_i
		end
		if not keep_folder and new_folder ~= Session.folder_of(drag.block) then

			if Session.is_trash_folder(new_folder) then
				drag.block.trashed_from = Session.folder_of(drag.block)
			else
				drag.block.trashed_from = nil
			end
			drag.block.folder = new_folder
			drag.refiled = drag.refiled or {}
			drag.refiled[drag.block] = true
		end

		self:rebuild()
	end

	local floor_i = 1
	local ceil_i = Session.count()

	local slot_index = math.floor(fpos) + 1
	local hovered = rows[slot_index]
	if hovered and hovered.kind == "slot" and hovered.root then

		if Session.folder_of(drag.block) ~= nil then
			local _, trash_last = Session.folder_bounds(Session.TRASH_FOLDER)
			swap_to(math.max((trash_last or 0) + 1, floor_i), nil)
		end
		return
	end
	if hovered and hovered.kind == "slot" and Session.folder_of(drag.block) ~= hovered.folder then

		local dest = floor_i
		for i = slot_index + 1, #rows do
			if rows[i].bi then
				dest = math.max(rows[i].bi, floor_i)
				break
			end
		end
		swap_to(dest, hovered.folder)
		return
	end

	local folder_spans = self:spans("folder")

	---@param ni integer      the neighbouring block index
	---@param up boolean      travelling toward the front (higher indices)
	local function neighbour(ni, up)
		local other = Session.folder_of(Session.block_at(ni))
		if other and not block_spans[ni] then
			local first, last = Session.folder_bounds(other)
			local header = folder_spans[other]
			if not (first and header) then
				return nil
			end
			return BlocksTree.midpoint(header), up and last or first, nil, true
		end
		if not block_spans[ni] then
			return nil
		end
		return BlocksTree.midpoint(block_spans[ni]), ni, other, false
	end

	if cur < ceil_i then
		local mid, dest, folder, keep = neighbour(cur + 1, true)
		if mid and fpos < mid then
			swap_to(dest, folder, keep)
			return
		end
	end
	if cur > floor_i then
		local mid, dest, folder, keep = neighbour(cur - 1, false)
		if mid and fpos > mid and dest >= floor_i then
			swap_to(dest, folder, keep)
		end
	end
end

---@param ctx ReorderCtx
---@param drag ReorderDrag
---@param cy number
function BlocksTree:update_folder_reorder(ctx, drag, cy)
	if drag.locked then
		return 
	end
	local fpos = self:row_pos(cy)

	local folder_spans = self:spans("folder")

	local order = Session.folder_order()
	local pos
	for i = 1, #order do
		if order[i] == drag.folder then
			pos = i
			break
		end
	end
	if not pos then
		return
	end

	local selected = ctx.sel_block and Session.block_at(ctx.sel_block)
	local function step(dir)
		if Session.move_folder(drag.folder, dir) then
			drag.changed = true
			if selected then
				ctx.sel_block = index_of(Session.blocks(), selected) or ctx.sel_block
			end
			self:rebuild()
		end
	end

	local below = order[pos + 1]
	local mid = below and BlocksTree.midpoint(folder_spans[below])
	if mid and fpos > mid then
		step(1)
		return
	end
	local above = order[pos - 1]
	mid = above and BlocksTree.midpoint(folder_spans[above])
	if mid and fpos < mid then
		step(-1)
	end
end

---@param cy number   cursor y, design px
---@param now number  this frame's clock (HudEditor._t)
function BlocksTree:drag_autoscroll(cy, now)
	local rows = self:current_rows()
	local max_scroll = BlocksPanel.max_scroll(#rows)
	if max_scroll <= 0 then
		self.autoscroll_at = nil
		return
	end
	local panel = self.blocks_panel()
	local top = panel.y + BlocksPanel.ROWS_TOP
	local bottom = top + BlocksPanel.visible_rows(#rows) * BlocksPanel.ROW_H
	local scroll = self.scroll or 0

	local dir = 0
	if cy < top + AUTOSCROLL_MARGIN and scroll > 0 then
		dir = -1
	elseif cy > bottom - AUTOSCROLL_MARGIN and scroll < max_scroll then
		dir = 1
	end
	if dir == 0 then
		self.autoscroll_at = nil
		return
	end

	if not self.autoscroll_at then
		self.autoscroll_at = now 
	end
	if now >= self.autoscroll_at then
		self.scroll = math.max(0, math.min(max_scroll, scroll + dir))
		self.autoscroll_at = now + AUTOSCROLL_INTERVAL
	end
end

BlocksTree.DEBUG_FOLDER_EYE = DEBUG_FOLDER_EYE

mod.hud_studio_blocks_tree = BlocksTree

return BlocksTree
