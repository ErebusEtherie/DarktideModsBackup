
local mod = get_mod("hud_studio")

if mod.swatch_component then
	return mod.swatch_component
end

local RectNode = mod:core(mod.nodes_rect, "blocks/node_types/rect")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")
local CompositeMaterial = mod:core(mod.hud_studio_composite_material, "blocks/composite_material")

local Swatch = {}

local COLOR = {
	BG = { 50, 130, 130, 138 },
	rect = { 255, 255, 255, 255 },
	progress_bar = { 255, 120, 220, 255 },
	text = { 255, 230, 230, 230 },
	texture = { 255, 255, 255, 255 },
}

local FONT = {
	default = mod.dl.fonts.validated("arial"),
	text = mod.dl.fonts.validated("itc_novarese_medium"),
}

function Swatch.draw(d, spec, x, y, z, size, opts)
	local node_type = spec.type
	opts = opts or {}

	local color = spec.color or COLOR[node_type] or Color.white(255, true)
	local font = FONT[node_type] or FONT.default

	d:rect(x, y, z, size, size, opts.bg or COLOR.BG)
	d:outline(x, y, x + size, y + size, z + 5, Color.black(80, true))

	local material = spec.material
	local base = CompositeMaterial.base(material)
	local has_material = (type(base) == "string" and base ~= "")

	if has_material then

		if MaterialDeps.ready_to_draw(base) then
			local uvs = RectNode.uv_name_to_value(spec.uv) or nil
			local drawable = material
			if CompositeMaterial.is_descriptor(material) then
				drawable = CompositeMaterial.resolve(d.ui_renderer, material)
			end

			if drawable then
				d:texture(drawable, x + 2, y + 2, z + 1, size - 4, size - 4, color, uvs)
			end
		end
	elseif node_type == "rect" then
		d:rect(x + 1, y + 1, z, size - 2, size - 2, color)
	elseif node_type == "progress_bar" then
		local bar_h = math.floor(size * 0.2)
		d:rect(x + 2, y + math.floor((size - bar_h) * 0.4), z + 1, size - 4, bar_h, Color.black(75, true))
		d:rect(x + 2, y + math.floor((size - bar_h) * 0.4), z + 1, size * 0.6, bar_h, color)
	elseif node_type == "text" then
		local font_size = size - 2

		d:text_left("T", font_size, x + 4, y, z + 1, font_size, font_size, color, font, true)
	end
end

mod.swatch_component = Swatch

return Swatch
