---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_drag_controller then
	return mod.hud_studio_drag_controller
end

local Session = mod:core(mod.hud_studio_session, "document/session")
local BlocksTree = mod:core(mod.hud_studio_blocks_tree, "hud/editor/models/blocks_tree")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local Block = mod:core(mod.hud_studio_block, "blocks/block")
local History = mod:core(mod.hud_studio_history, "document/history")

local index_of = Geometry.index_of
local node_extent = Geometry.node_extent

---@class DragController
local DragController = {}

---@class BlockDrag
---@field kind "block"
---@field index integer   index into Session.blocks() of the dragged block
---@field gx number       cursor's grab offset from the block origin, canvas space
---@field gy number
---@field sx number       start offset, so the release can tell a click from a move
---@field sy number

---@class NodeDrag
---@field kind "node"
---@field bi integer      block the node lives in
---@field block Block
---@field node Node
---@field gx number       grab offset from the node origin, relative to the block offset
---@field bs number                    the block's zoom, frozen at press (see Block:get_scale)
---@field gy number
---@field sx number       start offset, as BlockDrag
---@field sy number

---@class ResizeDrag
---@field kind "resize"
---@field bi integer
---@field block Block
---@field node Node
---@field gx number       grab offset from the bottom-right corner (snag-free grab)
---@field bs number                    the block's zoom, frozen at press (see Block:get_scale)
---@field gy number
---@field nx number       node top-left, screen px, fixed for the drag
---@field ny number
---@field sw number       size at press
---@field sh number

---@class RotateDrag
---@field kind "rotate"
---@field bi integer
---@field block Block
---@field node Node
---@field sy number       screen y at press
---@field sr number       node.values.rotation at press, degrees

---@class BlockScaleDrag
---@field kind "blockscale"
---@field index integer   index into Session.blocks(), for the save
---@field block Block
---@field sx number       screen x at press
---@field ss number       block.scale.value at press (1.0 when unauthored)

---@class PanelDrag
---@field kind "panel"
---@field panel table     the panel box, written live (x / y)
---@field gx number       cursor's grab offset from the panel's top-left
---@field gy number

---@class TextSelDrag
---@field kind "textsel"
---@field box table|nil          multiline only: the box being hit-tested
---@field box_x number|nil       single-line only: the box's left edge (scroll re-applied per frame)
---@field multiline boolean|nil
---@field word table|nil         anchor run { lo, hi } of a double-click-and-drag

---@class ColorPickDrag
---@field kind "colorpick"
---@field ctrl table      the colour control being edited
---@field region string   which picker region the press landed in
---@field box table       the picker box, for the per-frame hit-test

---@class NumStepDrag
---@field kind "numstep"
---@field ctrl table        the numeric control
---@field dir integer       step direction, 1 or -1
---@field repeat_at number  self._t the next auto-repeat step is due at
---@field dirty boolean|nil true once the repeat has stepped at least once (so release saves)

---@alias Drag BlockDrag|NodeDrag|ResizeDrag|RotateDrag|BlockScaleDrag|PanelDrag|TextSelDrag|ColorPickDrag|NumStepDrag|ReorderDrag

---@class DragCtx
---@field tree BlocksTree                        reorder autoscroll
---@field now number                             self._t, for numstep repeat timing
---@field ui_renderer table|nil                  textsel caret hit-testing (nil before the first draw)
---@field ctrl_held fun(): boolean               resize 1:1 lock, rotate snap
---@field save fun(bi: integer, what: string|nil)  write one block's file, reporting a failure
---@field save_canvas fun()                      folder reorder, on release
---@field commit_edit fun()                      colorpick / numstep, on release
---@field record_field fun(ctrl: table, before: any, after: any)  colorpick, on release
---@field store_panel_pos fun(panel: table)      panel, on release (to the mod settings)
---@field save_panel_pos fun(panel: table)       panel, per frame (to the live table)
---@field enter_edit_block fun(bi: integer)      block release, the "clicked, not moved" branch
---@field run_reorder fun(pass: function, drag: ReorderDrag, cy: number)
---@field extend_textsel fun(drag: TextSelDrag, index: integer)
---@field apply_colorpick fun(drag: ColorPickDrag, cx: number, cy: number)
---@field numeric_apply fun(ctrl: table, dir: integer)
---@field multiline_rc_at fun(box: table, cx: number, cy: number): integer, integer

local NUM_HOLD_DELAY = 0.5
local NUM_REPEAT_INTERVAL = 0.05

local function round_offset(off)
	if not off then
		return
	end
	off[1] = math.floor((off[1] or 0) + 0.5)
	off[2] = math.floor((off[2] or 0) + 0.5)
end

local function record_xy(block, tbl, from_x, from_y)
	History.record(
		History.call("set_xy", block, tbl, from_x, from_y),
		History.call("set_xy", block, tbl, tbl[1], tbl[2])
	)
end

local function moved_beyond_slop(off, sx, sy)
	return off
		and (
			math.abs((off[1] or 0) - sx) > C.BEGIN_DRAG_THRESHOLD
			or math.abs((off[2] or 0) - sy) > C.BEGIN_DRAG_THRESHOLD
		)
end

local function restore_offset(off, drag)
	if off then
		off[1] = drag.sx
		off[2] = drag.sy
	end
	return true
end

local KINDS = {}

KINDS.panel = {
	update = function(ctx, drag, cx, cy)
		drag.panel.x = cx - drag.gx
		drag.panel.y = cy - drag.gy
		ctx.save_panel_pos(drag.panel)
	end,

	release = function(ctx, drag)
		ctx.store_panel_pos(drag.panel)
	end,
}

KINDS.reorder = {
	update = function(ctx, drag, cx, cy)
		ctx.run_reorder(BlocksTree.update_node_reorder, drag, cy)
		ctx.tree:drag_autoscroll(cy, ctx.now)
	end,

	release = function(ctx, drag)
		History.resume()
		if not drag.changed then
			return
		end
		if drag.from_block and drag.from_ni then
			local to_block = Session.block_at(drag.bi)
			local _, to_ni = Session.node_index(to_block, drag.node)
			if to_block and to_ni then
				History.record(
					History.call("move_node_to", drag.from_block, drag.node, drag.from_ni),
					History.call("move_node_to", to_block, drag.node, to_ni)
				)
			end
		end
		for bi in pairs(drag.saves or { [drag.bi] = true }) do
			ctx.save(bi)
		end
	end,
}

KINDS.reorder_block = {

	update = function(ctx, drag, cx, cy)
		ctx.run_reorder(BlocksTree.update_block_reorder, drag, cy)
		ctx.tree:drag_autoscroll(cy, ctx.now)
	end,

	release = function(ctx, drag)
		History.resume()
		if drag.changed or drag.refiled then
			History.record(
				History.call(
					"restore_block_slot",
					drag.block,
					drag.from_folder,
					drag.from_index,
					drag.from_trashed_from
				),
				History.call(
					"restore_block_slot",
					drag.block,
					Session.folder_of(drag.block),
					index_of(Session.blocks(), drag.block),
					drag.block.trashed_from
				)
			)
		end
		for block in pairs(drag.refiled or {}) do
			ctx.save(index_of(Session.blocks(), block), "re-filed block")
		end
	end,
}

KINDS.reorder_folder = {

	update = function(ctx, drag, cx, cy)
		ctx.run_reorder(BlocksTree.update_folder_reorder, drag, cy)
		ctx.tree:drag_autoscroll(cy, ctx.now)
	end,

	release = function(ctx, drag)
		History.resume()
		if drag.changed then
			local order = Session.folder_order()
			for i = 1, #order do
				if order[i] == drag.folder then
					History.record(
						History.call("move_folder_to", drag.folder, drag.from_pos),
						History.call("move_folder_to", drag.folder, i)
					)
					break
				end
			end
			ctx.save_canvas()
		end
	end,
}

KINDS.textsel = {

	update = function(ctx, drag, cx, cy)
		if not (ctx.ui_renderer and TextField.any_focused()) then
			return
		end
		local index
		if drag.multiline then
			local row, col = ctx.multiline_rc_at(drag.box, cx, cy)
			index = TextField.index_at_rc(row, col)
		else

			local left_x = drag.box_x + 4 - TextField.scroll_x()
			index = TextMetrics.caret_index_at_x(ctx.ui_renderer, left_x, cx)
		end
		ctx.extend_textsel(drag, index)
	end,

}

KINDS.colorpick = {

	update = function(ctx, drag, cx, cy)
		ctx.apply_colorpick(drag, cx, cy)
	end,

	release = function(ctx, drag)
		History.resume()
		ctx.record_field(drag.ctrl, drag.start_value, drag.ctrl.get and drag.ctrl.get())
		ctx.commit_edit()
	end,
}

KINDS.numstep = {

	update = function(ctx, drag)
		if ctx.now >= drag.repeat_at then
			ctx.numeric_apply(drag.ctrl, drag.dir)
			drag.dirty = true
			drag.repeat_at = ctx.now + NUM_REPEAT_INTERVAL
		end
	end,

	release = function(ctx, drag)
		if drag.dirty then
			ctx.commit_edit()
		end
	end,
}

KINDS.node = {
	update = function(ctx, drag, cx, cy, ccx, ccy, dcx, dcy)
		local block, node = drag.block, drag.node
		local boff = block.offset or { 0, 0 }

		node.offset[1] = (ccx - dcx - (boff[1] or 0)) / drag.bs - drag.gx
		node.offset[2] = (ccy - dcy - (boff[2] or 0)) / drag.bs - drag.gy
	end,
	release = function(ctx, drag)
		local off = drag.node and drag.node.offset
		round_offset(off)
		if moved_beyond_slop(off, drag.sx, drag.sy) then
			record_xy(drag.block, off, drag.sx, drag.sy)
			ctx.save(drag.bi)
		end
	end,
	cancel = function(ctx, drag)
		return restore_offset(drag.node and drag.node.offset, drag)
	end,
}

KINDS.resize = {

	update = function(ctx, drag, cx, cy, ccx, ccy)
		local size = drag.node.style.size

		local new_w = ((ccx - drag.gx) - drag.nx) / drag.bs
		local new_h = ((ccy - drag.gy) - drag.ny) / drag.bs

		if ctx.ctrl_held() then
			new_w = math.max(new_w, new_h)
			new_h = new_w
		end
		size[1] = math.max(1, math.min(4000, math.floor(new_w + 0.5)))
		size[2] = math.max(1, math.min(4000, math.floor(new_h + 0.5)))
	end,

	release = function(ctx, drag)
		local size = drag.node.style and drag.node.style.size
		round_offset(size) 
		if size and (size[1] ~= drag.sw or size[2] ~= drag.sh) then
			record_xy(drag.block, size, drag.sw, drag.sh)
			ctx.save(drag.bi)
		end
	end,
}

KINDS.rotate = {

	update = function(ctx, drag, cx, cy)
		local delta = (drag.sy - cy) * C.NODE_ROTATE_DEG_PER_PX
		local deg = drag.sr + delta
		if ctx.ctrl_held() then
			deg = math.floor(deg / C.NODE_ROTATE_SNAP + 0.5) * C.NODE_ROTATE_SNAP
		else
			deg = math.floor(deg + 0.5)
		end
		drag.node.values.rotation = math.max(-360, math.min(360, deg))
	end,

	release = function(ctx, drag)
		local values = drag.node.values
		local deg = tonumber(values and values.rotation) or 0
		if deg ~= drag.sr then
			History.record(
				History.call("set_key", drag.block, values, "rotation", drag.sr),
				History.call("set_key", drag.block, values, "rotation", deg)
			)
			ctx.save(drag.bi)
		end
	end,
}

KINDS.blockscale = {

	update = function(ctx, drag, cx)
		local factor = drag.ss + (cx - drag.sx) * C.BLOCK_SCALE_PER_PX
		if ctx.ctrl_held() then
			factor = math.floor(factor / C.BLOCK_SCALE_SNAP + 0.5) * C.BLOCK_SCALE_SNAP
		end
		factor = math.floor(factor * 100 + 0.5) / 100
		drag.block.scale.value = math.max(Block.SCALE_MIN, math.min(Block.SCALE_MAX, factor))
	end,

	release = function(ctx, drag)
		local rec = drag.block.scale
		local changed = rec ~= nil and rec.value ~= drag.ss

		if Block.scale_is_default(rec) then
			drag.block.scale = nil
		end
		if changed then

			History.record(
				History.call("set_key", drag.block, rec, "value", drag.ss),
				History.call("set_key", drag.block, rec, "value", rec.value)
			)
			History.record(
				History.call("set_block_scale", drag.block, drag.had_scale and rec or nil),
				History.call("set_block_scale", drag.block, drag.block.scale)
			)
			ctx.save(drag.index)
		end
	end,
}

KINDS.block = {
	update = function(ctx, drag, cx, cy, ccx, ccy, dcx, dcy)
		local block = Session.block_at(drag.index)
		if block then
			local off = block.offset
			off[1] = (ccx - dcx) - drag.gx
			off[2] = (ccy - dcy) - drag.gy
		end
	end,
	release = function(ctx, drag)
		local block = Session.block_at(drag.index)
		local off = block and block.offset
		round_offset(off)
		if moved_beyond_slop(off, drag.sx, drag.sy) then
			record_xy(block, off, drag.sx, drag.sy)
			ctx.save(drag.index)
		else

			ctx.enter_edit_block(drag.index)
		end
	end,
	cancel = function(ctx, drag)
		local block = Session.block_at(drag.index)
		return restore_offset(block and block.offset, drag)
	end,
}

---@param panel table
---@param cx number
---@param cy number
---@return PanelDrag
DragController.panel = function(panel, cx, cy)
	return { kind = "panel", panel = panel, gx = cx - panel.x, gy = cy - panel.y }
end

---@return BlockDrag
DragController.block = function(index, off, ccx, ccy, dcx, dcy)
	return {
		kind = "block",
		index = index,
		gx = (ccx - dcx) - off[1],
		gy = (ccy - dcy) - off[2],

		sx = off[1],
		sy = off[2],
	}
end

---@return NodeDrag
DragController.node = function(block, node, bi, ccx, ccy, dcx, dcy)
	local block_scale = Session.scale_of(block)
	local boff = block.offset or { 0, 0 }
	local noff = node.offset
	if not noff then
		noff = { 0, 0 }
		node.offset = noff
	end
	return {
		kind = "node",
		bi = bi,
		block = block,
		node = node,

		bs = block_scale,
		gx = (ccx - dcx - (boff[1] or 0)) / block_scale - noff[1],
		gy = (ccy - dcy - (boff[2] or 0)) / block_scale - noff[2],
		sx = noff[1],
		sy = noff[2],
	}
end

---@return ResizeDrag
DragController.resize = function(block, node, bi, ccx, ccy, dcx, dcy)
	local boff = block.offset or { 0, 0 }
	local noff = node.offset or { 0, 0 }
	local start_w, start_h = node_extent(node)
	local style = node.style
	if not style then
		style = {}
		node.style = style
	end
	if not style.size then
		style.size = { start_w, start_h }
	end

	local block_scale = Session.scale_of(block)
	local nx = dcx + (boff[1] or 0) + (noff[1] or 0) * block_scale
	local ny = dcy + (boff[2] or 0) + (noff[2] or 0) * block_scale
	return {
		kind = "resize",
		bi = bi,
		block = block,
		node = node,
		bs = block_scale,
		gx = ccx - (nx + start_w * block_scale),
		gy = ccy - (ny + start_h * block_scale),
		nx = nx,
		ny = ny,
		sw = start_w,
		sh = start_h,
	}
end

---@return RotateDrag
DragController.rotate = function(block, node, bi, cy)
	local values = node.values
	if not values then
		values = {}
		node.values = values
	end
	return {
		kind = "rotate",
		bi = bi,
		block = block,
		node = node,
		sy = cy,
		sr = tonumber(values.rotation) or 0,
	}
end

---@return BlockScaleDrag
DragController.block_scale = function(block, index, cx)
	local rec = block.scale
	local had_scale = rec ~= nil
	if not rec then
		rec = { kind = "fixed", value = Block.SCALE_DEFAULT }
		block.scale = rec
	end
	local start = tonumber(rec.value)
	if not start then
		start = Block.SCALE_DEFAULT
		rec.value = start
	end
	return {
		kind = "blockscale",
		index = index,
		block = block,

		had_scale = had_scale,
		sx = cx,
		ss = start,
	}
end

---@return ReorderDrag
DragController.reorder_node = function(bi, node)

	History.suspend()
	local block = Session.block_at(bi)
	local _, ni = Session.node_index(block, node)
	return { kind = "reorder", bi = bi, node = node, changed = false, from_block = block, from_ni = ni }
end

---@return ReorderDrag
DragController.reorder_block = function(block)
	History.suspend()
	return {
		kind = "reorder_block",
		block = block,
		changed = false,

		from_folder = Session.folder_of(block),
		from_index = index_of(Session.blocks(), block),
		from_trashed_from = block.trashed_from,
	}
end

---@return ReorderDrag
DragController.reorder_folder = function(name, locked)
	History.suspend()
	local order = Session.folder_order()
	local from_pos
	for i = 1, #order do
		if order[i] == name then
			from_pos = i
			break
		end
	end
	return { kind = "reorder_folder", folder = name, locked = locked, changed = false, from_pos = from_pos }
end

---@param box table
---@param multiline boolean|nil
---@return TextSelDrag
DragController.textsel = function(box, multiline)
	if multiline then
		return { kind = "textsel", multiline = true, box = box }
	end
	return { kind = "textsel", box_x = box.x }
end

---@return ColorPickDrag
DragController.colorpick = function(ctrl, region, box)

	History.suspend()
	local start = ctrl.get and ctrl.get()
	if type(start) == "table" then
		local copy = {}
		for i = 1, #start do
			copy[i] = start[i]
		end
		start = copy
	end
	return { kind = "colorpick", ctrl = ctrl, region = region, box = box, start_value = start }
end

---@return NumStepDrag
DragController.numstep = function(ctrl, dir, now)
	return { kind = "numstep", ctrl = ctrl, dir = dir, repeat_at = now + NUM_HOLD_DELAY }
end

---@param ctx DragCtx
---@param drag Drag
---@param cx number    design-space cursor x (editor chrome)
---@param cy number    design-space cursor y
---@param ccx number   canvas-space cursor x (zoom divided out)
---@param ccy number   canvas-space cursor y
---@param dcx number   design-space screen centre x
---@param dcy number   design-space screen centre y
DragController.update = function(ctx, drag, cx, cy, ccx, ccy, dcx, dcy)
	local entry = drag and KINDS[drag.kind]
	if entry and entry.update then
		entry.update(ctx, drag, cx, cy, ccx, ccy, dcx, dcy)
	end
end

---@param drag Drag|nil        HudEditor._drag, which is usually nil
---@param panel table
---@return boolean
DragController.is_panel_drag = function(drag, panel)
	return drag ~= nil and drag.kind == "panel" and drag.panel == panel
end

---@param ctx DragCtx
---@param drag Drag
DragController.release = function(ctx, drag)
	local entry = drag and KINDS[drag.kind]
	if entry and entry.release then
		entry.release(ctx, drag)
	end
end

---@param ctx DragCtx
---@param drag Drag
---@return boolean cancelled  true when a move was cancelled (so Escape is consumed here)
DragController.cancel = function(ctx, drag)
	local entry = drag and KINDS[drag.kind]
	if entry and entry.cancel then
		return entry.cancel(ctx, drag) and true or false
	end
	return false
end

mod.hud_studio_drag_controller = DragController

return DragController
