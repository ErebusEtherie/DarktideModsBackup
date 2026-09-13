
local mod = get_mod("hud_studio")

if mod.outlines_component then
	return mod.outlines_component
end

local Session = mod:core(mod.hud_studio_session, "document/session")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local CloseButton = mod:core(mod.close_button_component, "hud/editor/elements/button/close_button")

local node_label = Geometry.node_label
local node_bounds = Geometry.node_bounds
local node_resizable = Geometry.node_resizable
local node_rotatable = Geometry.node_rotatable
local resize_handle_bounds = Geometry.resize_handle_bounds
local rotate_handle_bounds = Geometry.rotate_handle_bounds
local block_bounds = Geometry.block_bounds
local block_scalable = Geometry.block_scalable
local block_scale_handle_bounds = Geometry.block_scale_handle_bounds
local exit_node_edit_rect = Geometry.exit_node_edit_rect

local FONT = mod.dl.fonts.validated("proxima_nova_bold")
local LABEL_FONT_SIZE = 15
local LABEL_W = 300 
local LABEL_H = 20

local COLOR = {
	BLOCK_OUTLINE = mod.dl.colors.to_argb(75, { 255, 255, 255 }),
	BLOCK_OUTLINE_ACTIVE = mod.dl.colors.to_argb(125, { 255, 255, 255 }),
	BLOCK_LABEL = mod.dl.colors.to_argb(200, { 255, 255, 255 }),

	BLOCK_SCALE_HANDLE = mod.dl.colors.to_argb(160, { 255, 255, 255 }),

	BLOCK_OUTLINE_MOD = mod.dl.colors.to_argb(75, { 255, 255, 255 }),
	BLOCK_OUTLINE_MOD_ACTIVE = mod.dl.colors.to_argb(125, { 255, 255, 255 }),

	NODE_OUTLINE_SELECTED = mod.dl.colors.to_argb(200, { 8, 232, 195 }),
	NODE_ROTATE_HANDLE = mod.dl.colors.to_argb(100, { 8, 232, 195 }),
	NODE_LABEL = mod.dl.colors.to_argb(255, { 8, 232, 195 }),
}

local Outlines = {}

function Outlines.draw(d, ctx, dcx, dcy, z, scale)
	scale = scale or 1
	local blocks = Session.blocks()

	local hover_row = ctx.hover_row
	local hover_row_bi
	if hover_row and hover_row.kind == "block" then
		hover_row_bi = hover_row.bi
	end

	local on_canvas = ctx.on_canvas or function()
		return true
	end

	local hovered_bi = ctx.hover_block or hover_row_bi
	local active_bi = hovered_bi or ctx.sel_block

	for i = 1, #blocks do
		local block = blocks[i]
		if on_canvas(block) then
			local x0, y0, x1, y1 = block_bounds(block, dcx, dcy, scale)

			local active = active_bi == i
			if Session.is_mod_block(block) then
				d:outline_dashed(
					x0,
					y0,
					x1,
					y1,
					z,
					active and COLOR.BLOCK_OUTLINE_MOD_ACTIVE or COLOR.BLOCK_OUTLINE_MOD
				)
			else
				d:outline(x0, y0, x1, y1, z, active and COLOR.BLOCK_OUTLINE_ACTIVE or COLOR.BLOCK_OUTLINE)
			end

			if active and ctx.edit_block ~= i and block_scalable(block) then
				local hx0, hy0, hx1, hy1 = block_scale_handle_bounds(block, dcx, dcy, scale)
				d:rect(hx0, hy0, z, hx1 - hx0, hy1 - hy0, COLOR.BLOCK_SCALE_HANDLE)
			end

			local node_active = hovered_bi ~= i and ctx.sel_block == i and ctx.sel_node ~= nil
			if active and not node_active then
				local caption = block.label or block.name or "?"
				d:text_left(
				caption,
					LABEL_FONT_SIZE,
					x0,
					y0 - LABEL_H,
					z,
					LABEL_W,
					LABEL_H,
					COLOR.BLOCK_LABEL,
					FONT,
					true
				)
			end
		end
	end

	local ob, on
	local node_hovered = false 
	if ctx.edit_block and ctx.hover_node then
		ob = Session.block_at(ctx.edit_block)
		on = ob and ob.nodes[ctx.hover_node]
		node_hovered = on ~= nil
	end
	if not on and hover_row and hover_row.kind == "node" then
		ob = Session.block_at(hover_row.bi)
		on = ob and ob.nodes[hover_row.ni]
	end
	if not on and ctx.sel_block and ctx.sel_node then
		ob = Session.block_at(ctx.sel_block)
		on = ob and ob.nodes[ctx.sel_node]
	end

	if ob and not on_canvas(ob) then
		ob, on, node_hovered = nil, nil, false
	end

	local editing_block = ctx.edit_block and Session.block_at(ctx.edit_block) or nil

	local sel_ob = ctx.sel_block and Session.block_at(ctx.sel_block) or nil
	local selected_node = sel_ob and ctx.sel_node and sel_ob.nodes[ctx.sel_node] or nil

	if on then
		local x0, y0, x1, y1 = node_bounds(ob, on, dcx, dcy, scale)
		d:outline_dashed(x0, y0, x1, y1, z + 1, COLOR.NODE_OUTLINE_SELECTED)

		d:text_left(node_label(on), LABEL_FONT_SIZE, x0, y1, z, LABEL_W, LABEL_H, COLOR.NODE_LABEL, FONT, true)

		local editing = editing_block == ob
		if editing and on == selected_node then
			local r = exit_node_edit_rect(ob, on, dcx, dcy, scale)
			CloseButton.draw(d, r, z + 2, { id = "exit_node_edit", on_click = ctx.on_exit_edit })
		end

		local show_handles = editing and node_hovered
		if show_handles and node_resizable(on) then
			local rx0, ry0, rx1, ry1 = resize_handle_bounds(ob, on, dcx, dcy, scale)
			d:rect(rx0, ry0, z + 2, rx1 - rx0, ry1 - ry0, COLOR.NODE_OUTLINE_SELECTED)
		end
		if show_handles and node_rotatable(on) then
			local tx0, ty0, tx1, ty1 = rotate_handle_bounds(ob, on, dcx, dcy, scale)
			d:rect(tx0, ty0, z + 2, tx1 - tx0, ty1 - ty0, COLOR.NODE_ROTATE_HANDLE)
		end
	end
end

mod.outlines_component = Outlines

return Outlines
