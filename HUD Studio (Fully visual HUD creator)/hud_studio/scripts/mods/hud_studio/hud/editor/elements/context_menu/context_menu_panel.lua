
local mod = get_mod("hud_studio")

if mod.hud_studio_context_menu then
	return mod.hud_studio_context_menu
end

local CursorState = mod:core(mod.cursor_state, "hud/editor/input/cursor_state")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local Icons = mod:core(mod.editor_icons, "hud/editor/elements/icon/editor_icons")

local GEO = {
	WIDTH = 220, 
	ROW_H = 24, 
	SEP_H = 7, 
	PAD_V = 4, 
	LABEL_INSET = 12, 
}

local COLOR = {
	ROW_HOVER = { 235, 90, 90, 90 }, 
	TEXT = { 255, 225, 225, 225 },
	TEXT_HOVER = { 255, 245, 245, 245 },
	SEP = { 255, 40, 40, 40 }, 
}

local NODE_TYPES = {
	{ type = "text", label = "Text", icon_draw = Icons.draw_add_text_node_icon },
	{ type = "rect", label = "Rect", icon_draw = Icons.draw_add_rect_node_icon },
	{ type = "progress_bar", label = "Progress Bar", icon_draw = Icons.draw_add_progress_bar_node_icon },
}

local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local TEXT_SIZE = 14

local ContextMenu = {}

ContextMenu.WIDTH = GEO.WIDTH
ContextMenu.ROW_H = GEO.ROW_H

function ContextMenu.items(scope, vis_mode, vis_on, vis_dynamic, locked, trashed)
	if scope == "canvas" then
		return { { id = "add_block", label = "Insert Block" } }
	end

	if scope == "trash" then
		return { { id = "empty_trash", label = "Empty Trash", icon_draw = Icons.draw_trash_icon } }
	end

	if scope == "delnode" then
		return {
			{ id = "restore_node", label = "Restore Node" },
			{ sep = true },
			{ id = "purge_node", label = "Delete Node Permanently", icon_draw = Icons.draw_trash_icon },
		}
	end

	if scope == "folder" then

		local items = {
			{ id = "visibility", label = vis_on and "Hide Folder" or "Show Folder" },
			{ sep = true },
			{ id = "add_block", label = "Insert Block", icon_draw = Icons.draw_add_block_icon },
			{ sep = true },
			{ id = "rename_folder", label = "Rename Folder" },
			{ id = "delete_folder", label = "Delete Folder", icon_draw = Icons.draw_trash_icon },
		}
		items[#items + 1] = { sep = true }
		items[#items + 1] = { id = "save_folder_to_library", label = "Save Folder to Library" }
		return items
	end

	local is_block = scope == "block"
	local noun = is_block and "Block" or "Node"

	local vis_label
	if vis_mode == "code" then
		vis_label = "Edit Visibility Code"
	elseif vis_dynamic then

		vis_label = "Visibility Controlled Dynamically"
	elseif vis_on then
		vis_label = "Hide " .. noun
	else
		vis_label = "Show " .. noun
	end

	local items = {
		{ id = "visibility", label = vis_label },
		{ sep = true },
	}

	if is_block and not locked then
		for i = 1, #NODE_TYPES do
			local t = NODE_TYPES[i]
			items[#items + 1] =
				{ id = "add_node_" .. t.type, label = "Insert " .. t.label .. " Node", icon_draw = t.icon_draw }
		end
		items[#items + 1] = { sep = true }
	end

	if trashed then
		items[#items + 1] = { id = "restore_block", label = "Restore Block" }
		items[#items + 1] = { sep = true }
	end

	local rest = {
		{
			id = "delete",
			label = (trashed and "Delete " .. noun .. " Permanently") or ("Delete " .. noun),
			icon_draw = Icons.draw_trash_icon,
		},
		{ id = "duplicate", label = "Duplicate " .. noun, icon_draw = Icons.draw_copy_icon },
		{ sep = true },
		{ id = "move_forward", label = "Move Forward" },
		{ id = "move_backward", label = "Move Backward" },
		{ id = "move_back", label = "Move to Back" },
		{ id = "move_front", label = "Move to Front" },
	}
	for i = 1, #rest do
		items[#items + 1] = rest[i]
	end

	if is_block and not trashed then
		items[#items + 1] = { sep = true }
		items[#items + 1] = { id = "save_to_library", label = "Save to Library" }
	end
	return items
end

function ContextMenu.height(items)
	local h = GEO.PAD_V * 2
	for i = 1, #items do
		h = h + (items[i].sep and GEO.SEP_H or GEO.ROW_H)
	end
	return h
end

function ContextMenu.rect(x, y, items)
	return { x = x, y = y, w = GEO.WIDTH, h = ContextMenu.height(items) }
end

function ContextMenu.draw(d, menu, z, ctx)
	local items = menu.items
	local rect = ContextMenu.rect(menu.x, menu.y, items)

	PanelBody.draw(d, { x = rect.x, y = rect.y, w = rect.w }, rect.h, z, { full = true })

	local row_y = rect.y + GEO.PAD_V
	for i = 1, #items do
		local item = items[i]
		local icon_inset = 0
		if item.sep then

			d:hr(
				rect.x + GEO.LABEL_INSET,
				row_y + math.floor(GEO.SEP_H / 2),
				rect.w - GEO.LABEL_INSET * 2,
				z + 1,
				COLOR.SEP
			)
			row_y = row_y + GEO.SEP_H
		else
			local hovered, clicked =
				CursorState.test(d, "hud_studio_ctxmenu_row_" .. item.id, rect.x, row_y, rect.w, GEO.ROW_H)
			if hovered then
				d:rect(rect.x, row_y, z + 1, rect.w, GEO.ROW_H, COLOR.ROW_HOVER)
			end
			if item.icon_draw then
				item.icon_draw(d, rect.x + GEO.LABEL_INSET - 4, row_y, z, false, nil, { 255, 84, 84, 84 })
				icon_inset = 24
			end

			d:text_left(
				item.label,
				TEXT_SIZE,
				rect.x + GEO.LABEL_INSET + icon_inset,
				row_y,
				z + 2,
				rect.w - GEO.LABEL_INSET,
				GEO.ROW_H,
				hovered and COLOR.TEXT_HOVER or COLOR.TEXT,
				FONT
			)
			if clicked and ctx.invoke then
				ctx.invoke(item.id)
			end
			row_y = row_y + GEO.ROW_H
		end
	end
end

mod.hud_studio_context_menu = ContextMenu

return ContextMenu
