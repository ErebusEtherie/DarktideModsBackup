
local mod = get_mod("hud_studio")

if mod.hud_studio_ide_controller then
	return mod.hud_studio_ide_controller
end

local CodeEditor = mod:core(mod.editor_code_editor, "hud/editor/editors/code_editor/code_editor")

local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")

local Session = mod:core(mod.hud_studio_session, "document/session")

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")

local DocsTree = mod:core(mod.ide_docs_tree_component, "hud/editor/elements/ide/ide_docs_tree")

local Clipboard = mod:core(mod.hud_studio_clipboard, "engine/clipboard")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")

local in_rect = Geometry.in_rect

---@class IdeTarget
---@field field string?           a value field's code binding (the common case)
---@field style boolean?          the selected node's whole-node style patch
---@field block_visible boolean?  the selected block's own visibility record
---@field block_script boolean?   the selected block's block script
---@field block_scale boolean?    the selected block's own zoom binding
---@field threshold_slot string?  "current" | "max" -- the field's threshold sub-binding
---@field condition_slot string?  "<row>.<slot>" -- one rule operand on the conditions payload
---@field block_conditions boolean? the rule list hangs off block.visible, not a node field

---@class IdeHover
---@field close boolean?  the title bar's close (x) button

---@class IdeCtx
---@field ide IdeTarget?        the open target, nil when the editor is shut
---@field lay table?            this frame's laid-out geometry (see CodeEditor.layout)
---@field panel table           the floating panel box { id, title, x, y, w }
---@field docs_path string[]    breadcrumb into the field-docs tree (empty == root level)
---@field sel_block integer?    the selected block index
---@field sel_node integer?     the selected node index within that block
---@field ui_renderer table?    nil on a rendererless layout pass (docs / desc are skipped)
---@field commit fun(recompile: boolean)  persist the edited binding, recompiling when asked
---@field baseline string?      the body as it was when this target was opened ("" == no body)
---@field set_baseline fun(text: string|nil)  re-pin the baseline (open, and after a reset)
---@field on_reset fun()        the Reset Changes button's handler
---@field hover IdeHover        reset by interact each pass, read by draw
---@field begin_drag fun(cx: number, cy: number)  arm a title-bar drag from the press position
---@field press_textbox fun(ctrl: table, box: table, cx: number, cy: number, multiline: boolean)

---@class IdeController
local IdeController = {}

local function selected(ctx)
	local block = ctx.sel_block and Session.block_at(ctx.sel_block)
	local node = block and ctx.sel_node and block.nodes[ctx.sel_node]
	return node, block
end

---@param ctx IdeCtx
---@return table|nil
function IdeController.body_ctrl(ctx)
	return CodeEditor.body_ctrl(ctx)
end

---@param ctx IdeCtx
---@return table|nil
function IdeController.layout(ctx)
	return CodeEditor.layout(ctx)
end

---@param ctx IdeCtx
function IdeController.snapshot_baseline(ctx)
	local rec = CodeEditor.record(ctx)
	ctx.set_baseline((rec and rec.body) or "")
end

---@param ctx IdeCtx
---@return boolean restored
function IdeController.reset(ctx)
	local rec = CodeEditor.record(ctx)
	if not rec or not ctx.baseline then
		return false
	end
	local ctrl = CodeEditor.body_ctrl(ctx)
	if ctrl and TextField.is_focused(ctrl.token) then
		TextField.cancel()
	end

	rec.body = (ctx.baseline ~= "" and ctx.baseline) or nil
	ctx.commit(true)
	return true
end

---@param ctx IdeCtx
---@param ctrl table  the button / menu control that asked for the editor (its ide_* fields)
---@return IdeTarget
function IdeController.open(ctx, ctrl)

	local docs_path = ctx.docs_path
	for i = #docs_path, 1, -1 do
		docs_path[i] = nil
	end

	local target
	if ctrl.ide_block_visible then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		if block then

			local rec = block.visible or {}
			rec.kind = "code"
			rec.body = rec.body or ""
			block.visible = rec
		end
		target = { block_visible = true }
	elseif ctrl.ide_block_script then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		if block then

			local rec = block.script or {}
			rec.body = rec.body or ""
			block.script = rec
		end
		target = { block_script = true }
	elseif ctrl.ide_block_scale then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		if block then

			local rec = block.scale or {}
			rec.kind = "code"
			rec.body = rec.body or ""
			block.scale = rec
		end
		target = { block_scale = true }
	elseif ctrl.ide_style then
		local node = selected(ctx)
		if node then
			node.callbacks = node.callbacks or {}
			local s = node.callbacks.style or {}

			s.kind = "code"
			s.body = s.body or ""
			node.callbacks.style = s
		end
		target = { style = true }
	else

		target = {
			field = ctrl.ide_field,
			threshold_slot = ctrl.ide_threshold_slot,
			condition_slot = ctrl.ide_condition_slot,
			block_conditions = ctrl.ide_block_conditions,
		}
	end

	ctx.ide = target
	IdeController.snapshot_baseline(ctx)
	return target
end

---@param ctx IdeCtx
---@param cx number
---@param cy number
---@param pressed boolean
---@return boolean consumed
---@return boolean? close_pressed
function IdeController.interact(ctx, cx, cy, pressed)
	local lay = ctx.lay
	if not lay then
		return false
	end
	ctx.hover.close = nil

	if in_rect(cx, cy, PanelHeader.close_rect(ctx.panel)) then
		ctx.hover.close = true
		return true, pressed or nil
	end
	if in_rect(cx, cy, lay.title) then
		if pressed then
			ctx.begin_drag(cx, cy)
		end
		return true
	end

	if lay.docs then
		local action, handled = DocsTree.hit(lay.docs, cx, cy)
		if handled then
			if pressed then
				TextField.commit()
				local path = ctx.docs_path
				if action and action.back then
					path[#path] = nil
				elseif action and action.descend then
					path[#path + 1] = action.descend
				elseif action and action.copy then
					if Clipboard.copy(action.copy) then
						mod.dl.log.notify("Copied %s", action.copy)
					end
				end
			end
			return true
		end
	end
	if in_rect(cx, cy, lay.body) then
		if pressed then
			local ctrl = IdeController.body_ctrl(ctx)
			if ctrl then
				ctx.press_textbox(ctrl, lay.body, cx, cy, false)
			end
		end
		return true
	end
	if in_rect(cx, cy, lay.frame) then

		if pressed then
			TextField.commit()
		end
		return true
	end
	return false
end

mod.hud_studio_ide_controller = IdeController

return IdeController
