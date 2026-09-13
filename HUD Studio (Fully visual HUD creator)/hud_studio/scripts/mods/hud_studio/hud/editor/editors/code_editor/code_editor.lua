
local mod = get_mod("hud_studio")

if mod.editor_code_editor then
	return mod.editor_code_editor
end

local Session = mod:core(mod.hud_studio_session, "document/session")
local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Constants = mod:core(mod.editor_constants, "hud/editor/constants")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local IdePanel = mod:core(mod.ide_panel_component, "hud/editor/elements/ide/ide_panel")
local DocsTree = mod:core(mod.ide_docs_tree_component, "hud/editor/elements/ide/ide_docs_tree")
local FuncDesc = mod:core(mod.ide_func_desc_component, "hud/editor/elements/ide/ide_func_desc")

local PANEL = Constants.PANEL
local node_label = Geometry.node_label

local ERROR_LABEL = "ERROR: "

local CodeEditor = {}

local function selected(ctx)
	local block = ctx.sel_block and Session.block_at(ctx.sel_block)
	local node = block and ctx.sel_node and block.nodes[ctx.sel_node]
	return node, block
end

---@return table|nil
local function condition_record(ctx, ide)
	local rec
	if ide.block_conditions then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		rec = block and block.visible
	else
		local node = selected(ctx)
		rec = node and node.callbacks and node.callbacks.value and node.callbacks.value[ide.field]
	end
	local spec = rec and rec.conditions
	local row_index, slot = tostring(ide.condition_slot):match("^(%d+)%.(%w+)$")
	local row = spec and row_index and spec.rows[tonumber(row_index)]
	return row and row[slot] or nil
end

---@return table|nil
function CodeEditor.record(ctx)
	local ide = ctx.ide
	if not ide then
		return nil
	end
	if ide.condition_slot then
		return condition_record(ctx, ide)
	end
	if ide.block_visible then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		return block and block.visible
	end
	if ide.block_script then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		return block and block.script
	end
	if ide.block_scale then
		local block = ctx.sel_block and Session.block_at(ctx.sel_block)
		return block and block.scale
	end
	local node = selected(ctx)
	if not node or not node.callbacks then
		return nil
	end
	if ide.style then
		return node.callbacks.style
	end
	local rec = node.callbacks.value and node.callbacks.value[ide.field]
	if rec and ide.threshold_slot then
		return rec.thresholds and rec.thresholds[ide.threshold_slot]
	end
	return rec
end

---@return table|nil
function CodeEditor.body_ctrl(ctx)
	local rec = CodeEditor.record(ctx)
	if not rec then
		return nil
	end
	local ide = ctx.ide
	local slot = (ide.block_visible and "block_visible")
		or (ide.block_script and "block_script")
		or (ide.block_scale and "block_scale")
		or (ide.style and "style")
		or tostring(ide.field)
	if ide.threshold_slot then

		slot = slot .. "/" .. ide.threshold_slot
	elseif ide.condition_slot then

		slot = slot .. "/" .. ide.condition_slot
	end
	local token = "ide:" .. tostring(ctx.sel_block) .. ":" .. tostring(ctx.sel_node) .. ":" .. slot
	return {
		kind = "text",
		multiline = true,
		token = token,

		rebinds = true, 
		get = function()
			return rec.body or ""
		end,
		set = function(v)
			rec.body = (v ~= "" and v) or nil

			if ide and (ide.style or ide.block_visible or ide.block_scale) then
				rec.kind = "code"
			end
			ctx.commit(true)
		end,
	}
end

---@return boolean
function CodeEditor.dirty(ctx)
	if ctx.baseline == nil then
		return false
	end
	local rec = CodeEditor.record(ctx)
	if not rec then
		return false
	end
	local ctrl = CodeEditor.body_ctrl(ctx)
	local live = (ctrl and TextField.is_focused(ctrl.token)) and TextField.text() or (rec.body or "")
	return live ~= ctx.baseline
end

local function strip_error_prefix(error)
	return error:gsub("^.-%[[^%]]+%]:%d+:%s*", "")
end

---@return table|nil
function CodeEditor.layout(ctx)
	local ide = ctx.ide
	if not ide then
		return nil
	end
	local node, block = selected(ctx)

	local block_visible = ide.block_visible
	local block_script = ide.block_script
	local block_scale = ide.block_scale
	local no_node = block_visible
		or block_script
		or block_scale
		or (ide.condition_slot and ide.block_conditions)
		or false
	if no_node then
		block = ctx.sel_block and Session.block_at(ctx.sel_block)
	end
	if not node and not no_node then
		return nil
	end
	if no_node and not block then
		return nil
	end

	local node_type = node and NodeTypes.get(node.type)

	local rv = (block_visible and "visible")
		or (block_script and "script")
		or (block_scale and "scale")
		or (ide.style and "style")
		or tostring(ide.field)
	local error_key = rv
	if ide.threshold_slot then
		rv = ide.threshold_slot
		error_key = error_key .. "/" .. ide.threshold_slot
	elseif ide.condition_slot then

		rv = "value"
		error_key = no_node and ide.condition_slot or (error_key .. "/" .. ide.condition_slot)
	end

	local fn = block_script and "block_script" or (rv .. "_func")

	local scope
	if no_node then

		scope = Visibility.BLOCK_SCOPE
	elseif node_type and node_type.callbacks then
		if ide.style then
			scope = node_type.callbacks.style and node_type.callbacks.style.scope
		else
			scope = node_type.callbacks.value and node_type.callbacks.value.scope
		end
	end
	scope = scope or { "t", "dt", "state", "block" }

	local p = ctx.panel
	local ui_renderer = ctx.ui_renderer
	local x, y, w = p.x, p.y, p.w
	local pad = PANEL.PAD

	local title = { x = x, y = y, w = w, h = PANEL.TITLE_H }

	local cy = y + PANEL.TITLE_H + pad

	local docs = ui_renderer
			and DocsTree.prepare(
				{ scope = scope, node_type = node_type, path = ctx.docs_path },
				x + pad,
				cy,
				w - pad * 2,
				ui_renderer
			)
		or nil
	if docs then
		cy = cy + docs.h + 6
	end

	local desc = ui_renderer
			and FuncDesc.prepare(
				{ rv = rv, node_type = node_type, reset = CodeEditor.dirty(ctx) },
				x + pad,
				cy,
				w - pad * 2,
				ui_renderer
			)
		or nil
	if desc then
		cy = cy + desc.h + 6
	end

	local error_text = block and block.binding_error and block:binding_error(not no_node and node or nil, error_key)
	local err = nil
	if error_text and ui_renderer then

		local content_w = w - pad * 2
		local wrap_w = TextMetrics.wrap_width(ui_renderer, content_w)
		local wrapped = TextField.wrap_text(ERROR_LABEL .. strip_error_prefix(error_text), wrap_w)
		local lines = {}
		for i = 1, #wrapped do
			lines[i] = wrapped[i]
		end
		err = { x = x + pad, y = cy, w = content_w, lines = lines }
		cy = cy + #lines * PANEL.IDE_SIG_H + 6
	end

	local sig = { x = x + pad, y = cy }
	cy = cy + (PANEL.IDE_SIG_H * 2)

	local body_x = x + pad + PANEL.IDE_BODY_INDENT
	local body_w = w - pad * 2 - PANEL.IDE_BODY_INDENT
	local ctrl = CodeEditor.body_ctrl(ctx)
	local rows = PANEL.IDE_MIN_ROWS
	if ctrl and ui_renderer then
		local rr = TextMetrics.multiline_rows(ui_renderer, ctrl, body_w - 8)
		if #rr > rows then
			rows = #rr
		end
	end
	local body_h = rows * PANEL.MULTILINE_LINE_H + PANEL.MULTILINE_PAD * 2
	local body = { x = body_x, y = cy - 2, w = body_w, h = body_h }
	cy = cy + body_h + 2

	local ret = { x = body_x, y = cy }
	cy = cy + PANEL.IDE_SIG_H
	local end_line = { x = x + pad, y = cy }
	cy = cy + PANEL.IDE_SIG_H + pad + 4

	local end_undo_redo_warning = { x = x + pad, y = cy }
	cy = cy + PANEL.IDE_FLUFF_H + pad

	local end_fluff = { x = x + pad, y = cy }
	cy = cy + PANEL.IDE_FLUFF_H + pad

	local end_warning = { x = x + pad, y = cy }
	cy = cy + (PANEL.IDE_FLUFF_H * 2)

	local field_label
	if block_visible then
		field_label = "Visible"
	elseif block_script then
		field_label = "Script"
	elseif block_scale then
		field_label = "Zoom"
	elseif ide.style then
		field_label = "Style"
	else
		field_label = (tostring(ide.field):gsub("^%l", string.upper):gsub("_", " "))
		if ide.threshold_slot then

			field_label = field_label .. " > " .. (ide.threshold_slot:gsub("^%l", string.upper))
		elseif ide.condition_slot then

			local row_index, slot = tostring(ide.condition_slot):match("^(%d+)%.(%w+)$")
			field_label = field_label
				.. " > Row "
				.. (row_index or "?")
				.. " "
				.. (slot or "?"):gsub("^%l", string.upper)
		end
	end

	local title_text
	if no_node then
		title_text = mod:localize("ide_panel_title")
			.. string.format(" - %s > %s", (block and block.name) or "?", field_label)
	else
		title_text = mod:localize("ide_panel_title")
			.. string.format(" - %s > %s > %s", (block and block.name) or "?", node_label(node), field_label)
	end

	return {
		frame = { x = x, y = y, w = w, h = cy - y },
		title = title,
		title_text = title_text,
		docs = docs,
		desc = desc,
		error = err,
		sig = sig,
		sig_text = "function " .. fn .. "(" .. table.concat(scope, ", ") .. ")",

		declare_text = block_script and mod:localize("ide_block_script_declare") or ("local " .. rv .. " = nil"),
		body = body,
		body_token = ctrl and ctrl.token,
		ret = ret,
		ret_text = block_script and mod:localize("ide_block_script_return") or ("return " .. rv),
		end_undo_redo_warning = end_undo_redo_warning,
		end_line = end_line,
		end_fluff = end_fluff,
		end_warning = end_warning,
	}
end

function CodeEditor.draw(d, ctx, lay, dragging, z, close_hover)
	if not lay then
		return
	end

	local ctrl = CodeEditor.body_ctrl(ctx)

	IdePanel.draw(d, ctx.panel, z, lay, dragging, {
		title = lay.title_text,
		close_hover = close_hover,
		ctrl = ctrl,
		focused = ctrl ~= nil and TextField.is_focused(ctrl.token),
	})

	if lay.docs then
		DocsTree.draw(d, lay.docs, z + 2, { cx = d.cx, cy = d.cy })
	end

	if lay.desc then
		FuncDesc.draw(d, lay.desc, z + 2, { on_reset = ctx.on_reset })
	end
end

mod.editor_code_editor = CodeEditor

return CodeEditor
