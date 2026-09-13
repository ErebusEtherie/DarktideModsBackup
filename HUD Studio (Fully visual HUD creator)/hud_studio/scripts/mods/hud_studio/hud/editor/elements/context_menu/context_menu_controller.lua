
local mod = get_mod("hud_studio")

if mod.hud_studio_context_menu_controller then
	return mod.hud_studio_context_menu_controller
end

local ContextMenu = mod:core(mod.hud_studio_context_menu, "hud/editor/elements/context_menu/context_menu_panel")

local ContextMenuController = {}

function ContextMenuController.interact(ctx, cx, cy, pressed)
	local state = ctx.state
	if not state then
		return false
	end
	local rect = ContextMenu.rect(state.x, state.y, state.items)
	local inside = cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h
	if pressed and not inside then

		ctx.close()
	end
	return true
end

function ContextMenuController.draw_popup(d, ctx, z)
	local state = ctx.state
	if not state then
		return
	end
	ContextMenu.draw(d, state, z, { invoke = ctx.invoke })
end

mod.hud_studio_context_menu_controller = ContextMenuController

return ContextMenuController
