---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.nodes_rect then
	return mod.nodes_rect
end

local Registry = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local DrawCalls = mod:core(mod.draw_calls, "hud/editor/elements/draw_calls")
local CompositeMaterial = mod:core(mod.hud_studio_composite_material, "blocks/composite_material")
local Color = mod:core(mod.hud_studio_color, "blocks/color")

---@class RectNode : NodeType
local Rect = {
	id = "rect",
	label = "Rectangle",
	bindable = { "visible", "offset", "color", "size", "material", "material_fallback", "color_fallback" },
	value_editor = { kind = "material_browser" },

	style_knobs = { "visible", "offset", "size", "color" },
	callbacks = {
		value = {

			fields = {
				"visible",
				"offset",
				"color",
				"size",
				"material",
				"uvs",
				"clip",
				"rotation",
				"material_fallback",
				"color_fallback",
			},
			scope = { "sources", "state", "block", "t", "dt" },
		},
		style = { scope = { "sources", "value", "state", "block", "t", "dt" } },
	},
}

local UV = mod.dl.uv

local uv_map = {
	flip_none = UV.none(),
	flip_x = UV.flip_x(),
	flip_y = UV.flip_y(),
	flip_xy = UV.flip_xy(),
}

function Rect.uv_name_to_value(uv_name)
	return uv_map[uv_name] or nil
end

local clip_builders = {
	clip_left = function(frac)
		return UV.clip_left(frac)
	end,
	clip_right = function(frac)
		return UV.clip_right(frac)
	end,
	clip_top = function(frac)
		return UV.clip_top(frac)
	end,
	clip_bottom = function(frac)
		return UV.clip_bottom(frac)
	end,
	clip_top_left = function(frac)
		return UV.clip_top_left(frac, frac)
	end,
	clip_top_right = function(frac)
		return UV.clip_top_right(frac, frac)
	end,
	clip_bottom_left = function(frac)
		return UV.clip_bottom_left(frac, frac)
	end,
	clip_bottom_right = function(frac)
		return UV.clip_bottom_right(frac, frac)
	end,
	clip_center = function(frac)
		return UV.clip_center(frac, frac)
	end,
	clip_inset = function(frac)
		return UV.inset(frac)
	end,
}

local flip_transforms = {
	flip_x = UV.flip_x_of,
	flip_y = UV.flip_y_of,
	flip_xy = UV.flip_xy_of,
}

local function resolve_clip(values, style)
	local coded = values.clip
	if type(coded) == "table" then
		return coded
	end
	local mode = values.clip_mode or (style and style.clip_mode)
	local builder = mode and clip_builders[mode]
	if not builder then
		return nil
	end
	local amount = values.clip_amount or (style and style.clip_amount) or 50
	local frac = amount / 100
	if frac < 0 then
		frac = 0
	elseif frac > 1 then
		frac = 1
	end
	return builder(frac)
end

local function resolve_uvs(values, style)
	local uvs = resolve_clip(values, style)
	local flip = values.uv or (style and style.uv)
	local transform = flip and flip_transforms[flip]
	if transform then
		uvs = transform(uvs or UV.none())
	end
	return uvs
end

local function has_fallback(values, style)
	return (values.material_fallback or (style and style.material_fallback)) ~= nil
		or (values.color_fallback or (style and style.color_fallback)) ~= nil
end

local function uses_material(node, values, style)
	local bind = node and node.callbacks and node.callbacks.value and node.callbacks.value.material
	if bind ~= nil then
		return bind.kind == "source"
	end
	return has_fallback(values, style)
end

local function drawable_material(material, ui_renderer)
	if CompositeMaterial.is_descriptor(material) then
		return CompositeMaterial.resolve(ui_renderer, material)
	end
	if type(material) ~= "string" or material == "" then
		return nil
	end
	return material
end

---@param values table
---@param style table?
---@return string|nil
function Rect.implicit_material(values, style)
	local material = values.material_fallback or (style and style.material_fallback)
	return CompositeMaterial.base(material)
end

function Rect.default_color()
	return {
		255,
		255,
		255,
		255,
	}
end

function Rect.default_color_fallback()
	return {
		0,
		255,
		255,
		255,
	}
end

function Rect.default_size()
	return {
		100,
		100,
	}
end

---@param ui_renderer table
---@param x number
---@param y number
---@param z number
---@param scale number
---@param values table
---@param style table?
---@param block_name string?
---@param node table?  the node being drawn; only needed to see whether `material` is bound
function Rect.draw(ui_renderer, x, y, z, scale, values, style, block_name, node)

	local d = DrawCalls.bind(ui_renderer)
	local color = Color.rgba(values.color) or (style and style.color) or Rect.default_color()
	if color[1] <= 0 then
		return
	end
	local size = values.size or (style and style.size) or Rect.default_size()
	local material = values.material or (style and style.material)
	local w = (size[1] or 0) * scale
	local h = (size[2] or 0) * scale

	material = drawable_material(material, ui_renderer)

	if material then

		local uvs = resolve_uvs(values, style)
		local rotation = values.rotation or (style and style.rotation)
		d:texture(material, x, y, z, w, h, color, uvs, rotation)
		return
	end

	if uses_material(node, values, style) then
		local fallback_color = Color.rgba(values.color_fallback)
			or (style and style.color_fallback)
			or Rect.default_color_fallback()
		local fallback = drawable_material(values.material_fallback or (style and style.material_fallback), ui_renderer)
		if fallback then
			d:texture(fallback, x, y, z, w, h, fallback_color)
		elseif fallback_color[1] > 0 then

			d:rect(x, y, z, w, h, fallback_color)
		end
		return
	end

	d:rect(x, y, z, w, h, color)
end

Registry.register(Rect)

mod.nodes_rect = Rect

return Rect
