
local mod = get_mod("hud_studio")

if mod.deleted_row_component then
	return mod.deleted_row_component
end

local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local NodeRow = mod:core(mod.node_row_component, "hud/editor/elements/row/node_row")

local Deleted = {}

local chip_ids = setmetatable({}, { __mode = "k" })

local function chip_id(node)
	local id = chip_ids[node]
	if not id then
		id = {}
		chip_ids[node] = id
	end
	return id
end

function Deleted.draw_header(d, count, x, row_y, w, z, hovered, collapsed, indent, trunks)
	Row.draw(d, x, row_y, w, z, {
		label = "Deleted Nodes (" .. tostring(count) .. ")",
		caret = { open = not collapsed },
		hovered = hovered,
		indent = indent,
		tree = { last = true, trunks = trunks },
	})
end

function Deleted.draw_node(d, node, x, row_y, w, z, hovered, last, indent, trunks)
	Row.draw(d, x, row_y, w, z, {

		label = NodeRow.label(node),
		swatch = { type = node.type },
		hovered = hovered,
		indent = indent,
		tree = { last = last, trunks = trunks },
		chip = {
			id = chip_id(node),
			text = "[DELETED]",
			tooltip = "Deleted. Right-click to restore it, or to delete it for good.",
			show = true,
		},
	})
end

mod.deleted_row_component = Deleted

return Deleted
