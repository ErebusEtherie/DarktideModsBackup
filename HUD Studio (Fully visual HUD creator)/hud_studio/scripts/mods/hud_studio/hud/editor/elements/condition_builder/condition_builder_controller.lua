
local mod = get_mod("hud_studio")

if mod.hud_studio_cb_controller then
	return mod.hud_studio_cb_controller
end

local Conditions = mod:core(mod.hud_studio_conditions, "blocks/conditions")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Layout = mod:core(mod.hud_studio_condition_builder, "hud/editor/elements/condition_builder/condition_builder")
local NodeForm = mod:core(mod.hud_studio_node_form, "hud/editor/forms/node_form")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local Numeric = mod:core(mod.hud_studio_numeric_component, "hud/editor/elements/field/numeric")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local Format = mod:core(mod.editor_format, "hud/editor/format")
local History = mod:core(mod.hud_studio_history, "document/history")

---@class CbController
local CbController = {}

---@param block table|nil   the Block, when the target is block-level visibility
---@param node Node|nil     the node, when the target is a node's visible field
---@return table|nil spec
function CbController.spec(block, node, field)
	if node then
		return NodeForm.condition_spec(node, field)
	end
	return block and Visibility.block_conditions(block) or nil
end

---@return integer
function CbController.row_count(spec)
	return math.min(#spec.rows, Layout.MAX_ROWS)
end

---@return boolean
function CbController.can_add(spec)
	return #spec.rows < Layout.MAX_ROWS
end

---@return table row
local function ensure_row(spec, i)
	for j = 1, i do
		if not spec.rows[j] then
			spec.rows[j] = Conditions.default_row()
		end
	end
	return spec.rows[i]
end
CbController.ensure_row = ensure_row

function CbController.remove_row(spec, i)
	table.remove(spec.rows, i)
end

---@param mutate fun(spec: table): boolean|nil
---@return boolean edited
function CbController.edit_rows(block, spec, mutate)
	local before = History.copy(spec.rows)
	if mutate(spec) == false then
		return false
	end
	History.record(
		History.call("set_rows", block, spec, before),
		History.call("set_rows", block, spec, History.copy(spec.rows))
	)
	return true
end

local function row_op(spec, i)
	local row = spec.rows[i]
	return Conditions.op(row and row.op) or Conditions.op(Conditions.DEFAULT_OP)
end

---@return integer
function CbController.row_arity(spec, i)
	return row_op(spec, i).arity
end

local JOIN_OPTIONS = {
	{ value = "and", text = mod:localize("cb_join_and") },
	{ value = "or", text = mod:localize("cb_join_or") },
}

local function join_ctrl(spec, i)
	return {
		kind = "dropdown",

		rebinds = true,
		options = function()
			return JOIN_OPTIONS
		end,
		get = function()
			local row = spec.rows[i]
			return (row and row.join == "or") and "or" or "and"
		end,
		set = function(v)
			ensure_row(spec, i).join = (v == "or") and "or" or "and"
		end,
	}
end

local function negate_ctrl(spec, i)
	return {
		kind = "button",
		text = function()
			local row = spec.rows[i]
			return (row and row.negate) and mod:localize("cb_is_not") or mod:localize("cb_is")
		end,

		cb_negate = i,
	}
end

function CbController.toggle_negate(spec, i)
	local row = ensure_row(spec, i)
	row.negate = (not row.negate) or nil
end

local function op_ctrl(spec, i)
	local function lhs_type()
		local row = spec.rows[i]
		return NodeForm.condition_operand_type(row and row.lhs)
	end
	return {
		kind = "dropdown",

		rebinds = true,
		options = function()
			local ops = Conditions.ops_for(lhs_type())
			local out = {}
			for k = 1, #ops do
				out[k] = { value = ops[k].id, text = mod:localize(ops[k].loc) }
			end
			return out
		end,
		get = function()
			local row = spec.rows[i]
			return Conditions.coerce_op(lhs_type(), row and row.op)
		end,
		set = function(v)
			ensure_row(spec, i).op = v
		end,
	}
end

local function operand_ctrl(spec, i, slot, cache)
	return {
		kind = "button",
		text = function()
			local row = spec.rows[i]
			return NodeForm.condition_operand_summary(row and row[slot])
		end,

		cb_expand = { row = i, slot = slot },
		selected = function()
			return cache.expanded == i
		end,
	}
end

local function remove_ctrl(spec, i)
	return {
		kind = "button",
		text = mod:localize("cb_remove_row"),
		cb_remove = i,
	}
end

function CbController.toggle(cache, row)
	cache.expanded = (cache.expanded ~= row) and row or nil

	cache.operand_groups = nil
	cache.operand_groups_arity = nil
end

local function add_ctrl()
	return { kind = "button", text = mod:localize("cb_add_condition"), cb_add = true }
end

local function seconds_ctrl(spec, key, token)
	return {
		kind = "text",
		token = token,
		get = function()
			local v = spec[key]
			return Format.value(v)
		end,
		set = function(v)
			local n = tonumber(v)
			spec[key] = (n and n > 0) and n or nil
		end,
	}
end

function CbController.ctrls(cache, block, node, field, spec, row_count)

	if cache.block ~= block or cache.node ~= node or cache.field ~= field or cache.spec ~= spec then
		cache.block, cache.node, cache.field, cache.spec = block, node, field, spec
		cache.join, cache.negate, cache.op = {}, {}, {}
		cache.lhs, cache.rhs, cache.rhs2, cache.remove = {}, {}, {}, {}
		cache.expanded = nil
		cache.operand_groups = nil
		cache.operand_groups_arity = nil
		cache.add = nil
		cache.linger, cache.delay = nil, nil
	end
	local prefix = "cb/" .. tostring(node and (node.id or node.type) or "block") .. "/" .. field
	cache.add = cache.add or add_ctrl()
	cache.linger = cache.linger or seconds_ctrl(spec, "linger", prefix .. "/linger")
	cache.delay = cache.delay or seconds_ctrl(spec, "delay", prefix .. "/delay")
	for i = 1, row_count do
		cache.join[i] = cache.join[i] or join_ctrl(spec, i)
		cache.negate[i] = cache.negate[i] or negate_ctrl(spec, i)
		cache.op[i] = cache.op[i] or op_ctrl(spec, i)
		cache.lhs[i] = cache.lhs[i] or operand_ctrl(spec, i, "lhs", cache)
		cache.rhs[i] = cache.rhs[i] or operand_ctrl(spec, i, "rhs", cache)
		cache.rhs2[i] = cache.rhs2[i] or operand_ctrl(spec, i, "rhs2", cache)
		cache.remove[i] = cache.remove[i] or remove_ctrl(spec, i)
	end
	return cache
end

local function control_parts(kind, r)
	if kind == "dropdown" then
		return Dropdown.parts(r.x, r.y, r.w, r.h)
	elseif kind == "numeric" then
		return Numeric.parts(r.x, r.y, r.w, r.h)
	elseif kind == "text" then
		return TextInput.parts(r.x, r.y, r.w, r.h)
	elseif kind == "button" or kind == "checkbox" then
		return { box = { x = r.x, y = r.y, w = r.w, h = r.h } }
	end
	return nil
end

local function item(ctrl, rect)
	return {
		t = "field",
		ctrl = ctrl,
		parts = control_parts(ctrl.kind, rect),
		ctrl_rect = rect,
		label_rect = { x = rect.x, y = rect.y, w = rect.w, h = 0 },
	}
end

---@return table|nil lay
function CbController.layout(panel, block, node, field, cache, truth_of)
	local spec = CbController.spec(block, node, field)
	if not spec then
		return nil
	end
	local row_count = CbController.row_count(spec)
	CbController.ctrls(cache, block, node, field, spec, row_count)

	if cache.expanded and cache.expanded > row_count then
		CbController.toggle(cache, nil)
	end

	local prefix = "cb/" .. tostring(node and (node.id or node.type) or "block") .. "/" .. field

	local expanded = cache.expanded

	local expanded_arity = expanded and CbController.row_arity(spec, expanded) or nil
	if expanded and (not cache.operand_groups or cache.operand_groups_arity ~= expanded_arity) then
		local groups = {}
		local slots = { "lhs", "rhs", "rhs2" }
		for k = 1, 1 + expanded_arity do
			local slot = slots[k]
			groups[slot] = NodeForm.condition_operand_group(node, prefix, field, spec, expanded, slot) or nil
		end
		cache.operand_groups = groups
		cache.operand_groups_arity = expanded_arity
	end
	local operand_groups = cache.operand_groups or nil

	local row_specs = {}
	for i = 1, row_count do
		local arity = CbController.row_arity(spec, i)
		local expanded_h = 0
		if expanded == i and operand_groups then

			for _, group in pairs(operand_groups) do
				expanded_h = math.max(expanded_h, Layout.stack_operand(group, 0, 0, 0, nil, nil))
			end
		end
		row_specs[i] = { arity = arity, expanded_h = expanded_h }
	end

	local geo = Layout.layout(panel.x, panel.y, panel.w, row_specs)

	local items, labels, pills = {}, {}, {}
	for i = 1, row_count do
		local row = geo.rows[i]
		local cells = row.cells
		local arity = row_specs[i].arity

		pills[i] = { rect = cells.pill, truth = truth_of and truth_of(i) }

		if cells.join then
			items[#items + 1] = item(cache.join[i], cells.join)
		end
		items[#items + 1] = item(cache.lhs[i], cells.lhs)
		items[#items + 1] = item(cache.negate[i], cells.negate)
		items[#items + 1] = item(cache.op[i], cells.op)
		if arity >= 1 and cells.rhs then
			items[#items + 1] = item(cache.rhs[i], cells.rhs)
		end
		if arity >= 2 and cells.rhs2 then
			items[#items + 1] = item(cache.rhs2[i], cells.rhs2)
		end
		items[#items + 1] = item(cache.remove[i], cells.remove)

		if row.expanded and operand_groups then
			local band = row.expanded
			for _, slot in ipairs({ "lhs", "rhs", "rhs2" }) do
				local group, column = operand_groups[slot], band[slot]
				if group and column then
					Layout.stack_operand(group, column.x, column.y, column.w, items, labels)
				end
			end
		end
	end

	for i = 1, #items do
		local it = items[i]
		if not it.parts then
			it.parts = control_parts(it.ctrl.kind, it.ctrl_rect)
		end
	end

	items[#items + 1] = item(cache.add, geo.add)
	items[#items + 1] = item(cache.linger, geo.linger.ctrl)
	items[#items + 1] = item(cache.delay, geo.delay.ctrl)
	labels[#labels + 1] = {
		x = geo.linger.label.x,
		y = geo.linger.label.y,
		w = geo.linger.label.w,
		h = geo.linger.label.h,
		text = mod:localize("cb_linger"),
		tooltip = mod:localize("cb_linger_tooltip"),
	}
	labels[#labels + 1] = {
		x = geo.delay.label.x,
		y = geo.delay.label.y,
		w = geo.delay.label.w,
		h = geo.delay.label.h,
		text = mod:localize("cb_delay"),
		tooltip = mod:localize("cb_delay_tooltip"),
	}

	geo.items = items
	geo.labels = labels
	geo.pills = pills
	return geo
end

mod.hud_studio_cb_controller = CbController

return CbController
