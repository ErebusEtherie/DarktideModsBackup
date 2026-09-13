
local mod = get_mod("hud_studio")

if mod.node_row_component then
	return mod.node_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Block = mod:core(mod.hud_studio_block, "blocks/block")
local Color = mod:core(mod.hud_studio_color, "blocks/color")

local EMPTY = {}

local Node = {}

---@return any
local function resolved(ev_values, ev_style, values, style, field)
	local v = ev_values[field]
	if v ~= nil then
		return v
	end
	v = ev_style[field]
	if v ~= nil then
		return v
	end
	v = values[field]
	if v ~= nil then
		return v
	end
	return style[field]
end

function Node.draw(
	d,
	node,
	x,
	row_y,
	w,
	z,
	selected,
	hovered,
	last,
	on_toggle,
	on_set_state,
	editing,
	script_error,
	indent,
	trunks
)
	local values = node.values or {}
	local style = node.style or {}

	local ev = Block.last_eval(node)
	local ev_values = (ev and ev.values) or EMPTY
	local ev_style = (ev and ev.style) or EMPTY

	Row.draw(d, x, row_y, w, z, {
		label = Node.label(node),
		swatch = {
			type = node.type,

			color = Color.rgba(resolved(ev_values, ev_style, values, style, "color")),
			material = resolved(ev_values, ev_style, values, style, "material"),
			uv = resolved(ev_values, ev_style, values, style, "uv"),
		},
		selected = selected,
		hovered = hovered,
		editing = editing,
		indent = indent or Row.ROW_INDENT,
		tree = { last = last, trunks = trunks },
		eye = {
			id = node,
			is_block = false,
			dynamic = Visibility.node_is_dynamic(node),
			on = Visibility.node_shown(node),
			state = Visibility.node_eye_state(node),
			on_toggle = on_toggle,
			on_set_state = on_set_state,
			error = script_error,
		},
	})
end

function Node.label(node)
	if not node then
		return "?"
	end
	if node.label and node.label ~= "" then
		return node.label
	end
	local nt = NodeTypes.get(node.type)
	if nt and nt.label then
		return nt.label
	end
	return node.type or node.id or "?"
end

mod.node_row_component = Node

return Node
