
local mod = get_mod("hud_studio")

if mod.blocks_panel_component then
	return mod.blocks_panel_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local PanelToolbar = mod:core(mod.panel_toolbar_component, "hud/editor/elements/blocks_panel/blocks_panel_toolbar")
local PanelTopToolbar = mod:core(mod.panel_top_toolbar_component, "hud/editor/elements/blocks_panel/blocks_panel_top_toolbar")
local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local DarktideCanvasRow = mod:core(mod.darktide_canvas_row_component, "hud/editor/elements/row/darktide_canvas_row")
local CanvasRow = mod:core(mod.canvas_row_component, "hud/editor/elements/row/canvas_row")
local BlockRow = mod:core(mod.block_row_component, "hud/editor/elements/row/block_row")
local NodeRow = mod:core(mod.node_row_component, "hud/editor/elements/row/node_row")
local FolderRow = mod:core(mod.folder_row_component, "hud/editor/elements/row/folder_row")
local BlankFolderRow = mod:core(mod.blank_folder_row_component, "hud/editor/elements/row/blank_folder_row")
local DeletedRow = mod:core(mod.deleted_row_component, "hud/editor/elements/row/deleted_row")

local COLOR = C.COLOR
local ROW_H = Row.ROW_H 
local ROW_INDENT = Row.ROW_INDENT 
local MAX_VISIBLE = 24 
local EMPTY = {} 
local SCROLLBAR_W = 3

---@param block Block|BlockData|nil
---@param node Node|nil
---@return string?
local function row_error(block, node)
	if not (block and block.row_error) then
		return nil
	end
	return block:row_error(node)
end

local BlocksPanel = {}

BlocksPanel.ROW_H = ROW_H
BlocksPanel.MAX_VISIBLE = MAX_VISIBLE

BlocksPanel.ROWS_TOP = PanelHeader.TITLE_H + PanelTopToolbar.HEIGHT

BlocksPanel.TOP_TOOLBAR_TOP = PanelHeader.TITLE_H

local function folder_of(block)
	local folder = block and block.folder
	if folder == "" then
		return nil
	end
	return folder
end

function BlocksPanel.build_rows(blocks, is_collapsed, folders)
	local rows = {}
	local bin_open = folders and folders.bin_open
	rows[#rows + 1] = { kind = "darktide" }
	rows[#rows + 1] = { kind = "canvas" }

	local folder_collapsed = folders and folders.collapsed
	local function collapsed_folder(name)
		return folder_collapsed ~= nil and folder_collapsed(name) == true
	end

	local members, root = {}, {}
	for bi = #blocks, 1, -1 do
		local folder = folder_of(blocks[bi])
		if folder then
			local run = members[folder]
			if not run then
				run = {}
				members[folder] = run
			end
			run[#run + 1] = bi
		else
			root[#root + 1] = bi
		end
	end

	local function emit_block(bi, depth, last)
		local block = blocks[bi]
		rows[#rows + 1] = { kind = "block", bi = bi, depth = depth, last = last }
		if is_collapsed and is_collapsed(block) then
			return
		end
		local nodes = block.nodes or {}
		local trunks = depth > 0 and { not last } or nil
		for ni = #nodes, 1, -1 do
			rows[#rows + 1] = { kind = "node", bi = bi, ni = ni, depth = depth + 1, trunks = trunks }
		end

		local bin = block.deleted_nodes
		if bin and #bin > 0 then
			rows[#rows + 1] = { kind = "bin", bi = bi, depth = depth + 1, trunks = trunks }
			if bin_open and bin_open(block) then

				local del_trunks = depth > 0 and { not last, false } or { false }
				for di = 1, #bin do
					rows[#rows + 1] = {
						kind = "delnode",
						bi = bi,
						di = di,
						depth = depth + 2,
						trunks = del_trunks,
						last = di == #bin,
					}
				end
			end
		end
	end

	local function emit_folder(name)
		rows[#rows + 1] = { kind = "folder", folder = name }
		if collapsed_folder(name) then
			return 
		end
		local run = members[name]
		local count = run and #run or 0
		for k = 1, count do
			emit_block(run[k], 1, k == #run)
		end

		rows[#rows + 1] = { kind = "slot", folder = name, empty = count == 0 }
	end

	local order = (folders and folders.order) or nil
	for i = 1, (order and #order or 0) do
		emit_folder(order[i])
	end
	for k = 1, #root do
		emit_block(root[k], 0, false)
	end

	if order and #order > 0 then
		rows[#rows + 1] = { kind = "slot", folder = nil, root = true, empty = #root == 0 }
	end
	local trash = folders and folders.trash
	if trash then
		emit_folder(trash)
	end
	return rows
end

function BlocksPanel.visible_rows(row_count)
	return math.max(1, math.min(row_count, MAX_VISIBLE))
end

function BlocksPanel.max_scroll(row_count)
	return math.max(0, row_count - MAX_VISIBLE)
end

function BlocksPanel.height(row_count)
	return BlocksPanel.ROWS_TOP + PanelToolbar.HEIGHT + BlocksPanel.visible_rows(row_count) * ROW_H + PanelHeader.PAD
end

function BlocksPanel.toolbar_y(panel, row_count)
	return panel.y + BlocksPanel.ROWS_TOP + BlocksPanel.visible_rows(row_count) * ROW_H
end

function BlocksPanel.body_region(panel, row_count, py, scroll)
	scroll = scroll or 0
	local visible = BlocksPanel.visible_rows(row_count)
	local rows_top = panel.y + BlocksPanel.ROWS_TOP
	local rows_bottom = rows_top + visible * ROW_H
	if py < rows_top then
		return "toolbar", nil 
	end
	if py < rows_bottom then
		local vis_idx = math.floor((py - rows_top) / ROW_H) + 1
		local flat = vis_idx + scroll
		local row = (flat >= 1 and flat <= row_count) and flat or nil
		return "body", row
	end
	return "toolbar", nil
end

function BlocksPanel.draw(d, panel, z, height, dragging, ctx)
	PanelBody.draw(d, panel, height, z, { color = { 255, 60, 60, 60 } })
	PanelHeader.draw(d, panel, z, dragging)

	local body_z = z + 1
	local x, y, w = panel.x, panel.y, panel.w
	local rows = ctx.rows
	local count = #rows
	local scroll = ctx.scroll or 0
	local visible = BlocksPanel.visible_rows(count)
	local top = y + BlocksPanel.ROWS_TOP

	PanelTopToolbar.draw(d, panel, body_z, y + BlocksPanel.TOP_TOOLBAR_TOP, {
		all_collapsed = ctx.all_collapsed,
		on_collapse_all = ctx.on_collapse_all,
		on_open_library = ctx.on_open_library,
		hide_hidden = ctx.hide_hidden,
		on_hide_hidden = ctx.on_hide_hidden,
	})

	for vis = 1, visible do
		local idx = vis + scroll
		local r = rows[idx]
		if r then
			local ry = top + (vis - 1) * ROW_H
			local block = ctx.blocks[r.bi]

			if r.kind == "darktide" then
				DarktideCanvasRow.draw(d, x, ry, w, body_z, ctx.sel_darktide == true, ctx.hover_row == idx)
			elseif r.kind == "canvas" then
				CanvasRow.draw(d, x, ry, w, body_z, ctx.sel_canvas == true, ctx.hover_row == idx)
			elseif r.kind == "folder" then

				local folder = r.folder
				FolderRow.draw(
					d,
					folder,
					x,
					ry,
					w,
					body_z,
					ctx.sel_folder == folder,
					ctx.hover_row == idx,
					ctx.on_toggle_folder and function(next_on)
						ctx.on_toggle_folder(folder, next_on)
					end,
					ctx.is_folder_collapsed and ctx.is_folder_collapsed(folder),
					ctx.rename_row == idx
				)
			elseif r.kind == "slot" then

				BlankFolderRow.draw(d, x, ry, w, body_z, r.empty, r.root)
			elseif r.kind == "bin" then
				DeletedRow.draw_header(
					d,
					#((block and block.deleted_nodes) or EMPTY),
					x,
					ry,
					w,
					body_z,
					ctx.hover_row == idx,
					not (ctx.is_bin_open and ctx.is_bin_open(block)),
					(r.depth or 1) * ROW_INDENT,
					r.trunks
				)
			elseif r.kind == "delnode" then
				local deleted = block and block.deleted_nodes and block.deleted_nodes[r.di]
				if deleted then
					DeletedRow.draw_node(
						d,
						deleted,
						x,
						ry,
						w,
						body_z,
						ctx.hover_row == idx,
						r.last == true,
						(r.depth or 2) * ROW_INDENT,
						r.trunks
					)
				end
			elseif r.kind == "block" then
				local selected = ctx.sel_block == r.bi and ctx.sel_node == nil
				if block then
					local bi = r.bi
					local on_toggle = ctx.on_toggle_visible
						and function(next_on)
							ctx.on_toggle_visible(bi, nil, next_on)
						end
					local on_set_state = ctx.on_set_visible_state
						and function(state)
							ctx.on_set_visible_state(bi, nil, state)
						end
					local collapsed = ctx.is_collapsed and ctx.is_collapsed(block)
					local editing = ctx.rename_row == idx
					BlockRow.draw(
						d,
						block,
						x,
						ry,
						w,
						body_z,
						selected,
						ctx.hover_row == idx,
						on_toggle,
						on_set_state,
						collapsed,
						editing,
						row_error(block, nil),
						ctx.hide_hidden,

						ctx.is_hidden ~= nil and ctx.is_hidden(block) or false,
						(r.depth or 0) * ROW_INDENT,
						r.last
					)
				end
			else

				local selected = ctx.sel_block == r.bi and ctx.sel_node == r.ni
				local node = block and block.nodes[r.ni]
				local next_r = rows[idx + 1]

				local next_kind = next_r and next_r.kind
				local is_last = next_kind ~= "node" and next_kind ~= "bin" and next_kind ~= "delnode"
				if node then
					local bi, ni = r.bi, r.ni
					local on_toggle = ctx.on_toggle_visible
						and function(next)
							ctx.on_toggle_visible(bi, ni, next)
						end
					local on_set_state = ctx.on_set_visible_state
						and function(state)
							ctx.on_set_visible_state(bi, ni, state)
						end
					local editing = ctx.rename_row == idx
					NodeRow.draw(
						d,
						node,
						x,
						ry,
						w,
						body_z,
						selected,
						ctx.hover_row == idx,
						is_last,
						on_toggle,
						on_set_state,
						editing,
						row_error(block, node),
						(r.depth or 1) * ROW_INDENT,
						r.trunks
					)
				end
			end
		end
	end

	local max_scroll = BlocksPanel.max_scroll(count)
	if max_scroll > 0 then
		local sb_x = x + w - SCROLLBAR_W - 1
		local sb_y = top
		local sb_h = visible * ROW_H
		d:rect(sb_x + 1, sb_y, body_z, SCROLLBAR_W, sb_h, COLOR.CTRL_BG)
		local thumb_h = math.max(ROW_H, sb_h * visible / count)
		local frac = scroll / max_scroll
		d:rect(sb_x + 1, sb_y + (sb_h - thumb_h) * frac, body_z + 10, SCROLLBAR_W, thumb_h, COLOR.SCROLL_THUMB)
	end

	PanelToolbar.draw(d, panel, body_z, top + visible * ROW_H, {
		selected_block = ctx.sel_block,
		on_add_folder = ctx.on_add_folder,
		on_add_block = ctx.on_add_block,
		on_add_node = ctx.on_add_node,
		on_copy = ctx.on_copy,
		on_delete = ctx.on_delete,
	})
end

mod.blocks_panel_component = BlocksPanel

return BlocksPanel
