

---@type mod
local mod = get_mod("dopamine")

if mod.layout_probe then
	return mod.layout_probe
end

---@class LayoutProbe
local LayoutProbe = {}

local _state = {}

---@param tag string
---@param t number? gameplay clock; nil disables the interval leg
---@return boolean
function LayoutProbe.should_log(tag, t, burst, interval)
	local s = _state[tag]
	if not s then
		s = { count = 0, last_t = -1e9 }
		_state[tag] = s
	end

	s.count = s.count + 1

	if s.count <= (burst or 5) then
		s.last_t = t or 0
		return true
	end

	if t and (t - s.last_t) >= (interval or 2) then
		s.last_t = t
		return true
	end

	return false
end

---@param tag string
function LayoutProbe.reset(tag)
	_state[tag] = nil
end

---@param n table?
---@return string
function LayoutProbe.node(n)
	if not n then
		return "<nil>"
	end

	local pos = n.position or {}
	local world = n.world_position or {}
	local size = n.size or {}

	return string.format(
		"id=%s halign=%s valign=%s pos=(%s,%s) world=(%s,%s) size=(%s,%s) scale=%s",
		tostring(n),
		tostring(n.horizontal_alignment),
		tostring(n.vertical_alignment),
		tostring(pos[1]),
		tostring(pos[2]),
		tostring(world[1]),
		tostring(world[2]),
		tostring(size[1]),
		tostring(size[2]),
		tostring(n.scale)
	)
end

---@param sg table?
---@param render_scale number?
---@return string
function LayoutProbe.graph(sg, render_scale)
	if not sg then
		return "<nil>"
	end

	local res_w = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width
	local res_h = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height
	local res_scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale

	return string.format(
		"is_static=%s dirty=%s n_hier=%s res=(%s,%s) res_scale=%s render_scale=%s",
		tostring(rawget(sg, "is_static")),
		tostring(rawget(sg, "dirty")),
		tostring(rawget(sg, "n_hierarchical_scenegraph")),
		tostring(res_w),
		tostring(res_h),
		tostring(res_scale),
		tostring(render_scale)
	)
end

---@param element table the HUD element (stores the latch on itself)
---@param node_id string
---@param halign string?
function LayoutProbe.mark_alignment_dirty(element, node_id, halign)
	local latch = element._probe_last_halign
	if not latch then
		latch = {}
		element._probe_last_halign = latch
	end

	if latch[node_id] == halign then
		return false
	end

	latch[node_id] = halign

	local sg = element._ui_scenegraph
	if not sg then
		return false
	end

	local is_static = rawget(sg, "is_static")
	if not is_static then
		mod:info(
			"[PROBE] %s alignment -> %s (scenegraph not static; cached path unused, dirty not set)",
			tostring(node_id),
			tostring(halign)
		)
		return false
	end

	rawset(sg, "dirty", true)

	mod:info("[PROBE] %s alignment -> %s, marked static scenegraph dirty", tostring(node_id), tostring(halign))
	return true
end

mod.layout_probe = LayoutProbe

return LayoutProbe
