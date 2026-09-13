
local mod = get_mod("hud_studio")

if mod.editor_geometry then
	return mod.editor_geometry
end

local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Session = mod:core(mod.hud_studio_session, "document/session")

---@param node Node
---@return string
local function node_label(node)
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

---@param node Node
---@return number w, number h
local function node_extent(node)
	local size = node.style and node.style.size
	if size then
		return size[1] or 0, size[2] or 0
	end

	if node.type == "text" then
		local fs = (node.style and node.style.font_size) or 22
		return C.NODE_EXTENT.text[1], math.ceil(fs * 1)
	end
	local ext = C.NODE_EXTENT[node.type] or C.NODE_EXTENT.default
	return ext[1], ext[2]
end

---@param block Block
---@param node Node
---@param scale number? design-space HUD zoom (default 1)
---@return number x0, number y0, number x1, number y1
local function node_bounds(block, node, dcx, dcy, scale)
	scale = scale or 1

	local inner = scale * Session.scale_of(block)
	local boff = block.offset or { 0, 0 }
	local noff = node.offset or { 0, 0 }
	local nx = dcx + (boff[1] or 0) * scale + (noff[1] or 0) * inner
	local ny = dcy + (boff[2] or 0) * scale + (noff[2] or 0) * inner
	local w, h = node_extent(node)
	w, h = w * inner, h * inner

	local pad = C.BLOCK_GRAB_PAD * scale
	return nx - pad, ny - pad, nx + w + pad, ny + h + pad
end

---@param node Node
---@return boolean
local function node_resizable(node)
	local nt = node and NodeTypes.get(node.type)
	local knobs = nt and nt.style_knobs
	if not knobs then
		return false
	end
	for i = 1, #knobs do
		if knobs[i] == "size" then
			return true
		end
	end
	return false
end

---@param scale number? design-space HUD zoom (default 1)
---@return number x0, number y0, number x1, number y1
local function resize_handle_bounds(block, node, dcx, dcy, scale)
	scale = scale or 1
	local x0, y0, x1, y1 = node_bounds(block, node, dcx, dcy, scale)

	local s = math.min(8 * scale, (x1 - x0) * 0.5, (y1 - y0) * 0.5)

	return x1 - s, y1 - s, x1, y1
end

---@param node Node
---@return boolean
local function node_rotatable(node)
	if not node then
		return false
	end
	local nt = NodeTypes.get(node.type)
	local fields = nt and nt.callbacks and nt.callbacks.value and nt.callbacks.value.fields
	if not fields then
		return false
	end
	local has_rotation = false
	for i = 1, #fields do
		if fields[i] == "rotation" then
			has_rotation = true
			break
		end
	end
	if not has_rotation then
		return false
	end
	local material = node.values and node.values.material
	if type(material) ~= "string" or material == "" then

		local bind = node.callbacks and node.callbacks.value and node.callbacks.value.material
		if not (bind and (bind.kind == "source" or bind.kind == "code")) then
			return false
		end
	end

	local rec = node.callbacks and node.callbacks.value and node.callbacks.value.rotation
	if rec and rec.kind ~= nil and rec.kind ~= "fixed" then
		return false
	end
	return true
end

---@param scale number? design-space HUD zoom (default 1)
---@return number x0, number y0, number x1, number y1
local function rotate_handle_bounds(block, node, dcx, dcy, scale)
	scale = scale or 1
	local _, y0, x1 = node_bounds(block, node, dcx, dcy, scale)
	local s = C.NODE_ROTATE_HANDLE * scale
	return x1 - s, y0, x1, y0 + s
end

---@param block Block
---@param scale number? design-space HUD zoom (default 1)
---@return number x0, number y0, number x1, number y1
local function block_bounds(block, dcx, dcy, scale)
	scale = scale or 1
	local boff = block.offset or { 0, 0 }
	local bx = dcx + (boff[1] or 0) * scale
	local by = dcy + (boff[2] or 0) * scale
	local nodes = block.nodes or {}

	local inner = scale * Session.scale_of(block)

	local pad = C.BLOCK_GRAB_PAD * scale
	if #nodes == 0 then
		local ext = C.NODE_EXTENT.default
		return bx - pad, by - pad, bx + ext[1] * inner + pad, by + ext[2] * inner + pad
	end

	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for i = 1, #nodes do
		local node = nodes[i]
		local noff = node.offset or { 0, 0 }
		local nx = bx + (noff[1] or 0) * inner
		local ny = by + (noff[2] or 0) * inner
		local w, h = node_extent(node)
		w, h = w * inner, h * inner
		if nx < x0 then
			x0 = nx
		end
		if ny < y0 then
			y0 = ny
		end
		if nx + w > x1 then
			x1 = nx + w
		end
		if ny + h > y1 then
			y1 = ny + h
		end
	end
	return x0 - pad, y0 - pad, x1 + pad, y1 + pad
end

---@param block Block?
---@return boolean
local function block_scalable(block)
	if not block then
		return false
	end
	local rec = block.scale
	return not (rec and rec.kind == "code")
end

---@param scale number? design-space HUD zoom (default 1)
---@return number x0, number y0, number x1, number y1
local function block_scale_handle_bounds(block, dcx, dcy, scale)
	scale = scale or 1
	local _, _, x1, y1 = block_bounds(block, dcx, dcy, scale)
	local s = C.BLOCK_SCALE_HANDLE * scale
	return x1, y1, x1 + s, y1 + s
end

local function point_in(px, py, x0, y0, x1, y1)
	return px >= x0 and px <= x1 and py >= y0 and py <= y1
end

---@param scale number? design-space HUD zoom (default 1)
---@return table x_button
local function exit_node_edit_rect(block, node, dcx, dcy, scale)
	scale = scale or 1
	local x0, y0, x1, y1 = node_bounds(block, node, dcx, dcy, scale)
	local size = 18 * scale
	local gap = 3 * scale
	local x_max = (RESOLUTION_LOOKUP.width * scale) - gap - size
	local y_min = 0 + size + gap
	local top = y0 - gap - size
	local bottom = y1 + gap
	local left = x0 - gap - size
	local right = x1 + gap
	local x = (right > x_max or top < y_min) and left or right
	local y = (top < y_min) and bottom or top

	return {
		x = x,
		y = y,
		w = size,
		h = size,
	}
end

local function in_rect(px, py, r)
	return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

---@return integer|nil
local function index_of(nodes, node)
	for i = 1, #nodes do
		if nodes[i] == node then
			return i
		end
	end
	return nil
end

local Geometry = {
	node_label = node_label,
	node_extent = node_extent,
	node_bounds = node_bounds,
	node_resizable = node_resizable,
	resize_handle_bounds = resize_handle_bounds,
	node_rotatable = node_rotatable,
	rotate_handle_bounds = rotate_handle_bounds,
	block_bounds = block_bounds,
	block_scalable = block_scalable,
	block_scale_handle_bounds = block_scale_handle_bounds,
	point_in = point_in,
	exit_node_edit_rect = exit_node_edit_rect,
	in_rect = in_rect,
	index_of = index_of,
}

mod.editor_geometry = Geometry

return Geometry
