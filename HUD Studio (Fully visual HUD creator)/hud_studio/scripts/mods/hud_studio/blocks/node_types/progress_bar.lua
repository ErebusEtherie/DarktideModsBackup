---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Registry = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Thresholds = mod:core(mod.hud_studio_thresholds, "blocks/thresholds")
local DrawCalls = mod:core(mod.draw_calls, "hud/editor/elements/draw_calls")
local CompositeMaterial = mod:core(mod.hud_studio_composite_material, "blocks/composite_material")
local Color = mod:core(mod.hud_studio_color, "blocks/color")

local BG_COLOR = { 200, 20, 20, 20 }
local DEFAULT_SIZE = { 100, 20 }
local DEFAULT_ORIENTATION = "left_right"
local DEFAULT_SHAPE = "straight"

local SEGMENT_GAP = 3

local CURVED_MATERIAL = "content/ui/materials/effects/forcesword_bar"

local CURVED_ARC_TOP = 0.995
local CURVED_ARC_BOTTOM = 0.51

local CURVED_SEGMENT_GAP = 0.03

local CURVED_SEGMENTS_REVERSED = false

local CURVED_FIRST_SEGMENT_BIAS = 0.0

local CURVED_QUAD_SCALE_X = 2.75
local CURVED_QUAD_SCALE_Y = 2.75

local CURVED_QUAD_OFFSET_X = 0.425
local CURVED_QUAD_OFFSET_Y = 0.5

local CURVED_RADIUS = 0.65
local CURVED_THICKNESS = 0.04
local CURVED_OUTLINE_WIDTH = 0.01

local CURVED_FILL_INTENSITY = 1
local CURVED_INTENSITY_MAX = 2

local CURVED_OPACITY_FILL = 1.3
local CURVED_OPACITY_OUTLINE = 1.3

local CURVED_FILL_TEXTURE = "content/ui/textures/backgrounds/default_square"

local SEMI_DEGREES_PER_UNIT = 90 / (CURVED_ARC_TOP - CURVED_ARC_BOTTOM)

local SEMI_SWEEP = 180 / SEMI_DEGREES_PER_UNIT
local SEMI_ARC_TOP = CURVED_ARC_TOP
local SEMI_ARC_BOTTOM = SEMI_ARC_TOP - SEMI_SWEEP

local SEMI_ROTATION_TOP = 90
local SEMI_ROTATION_BOTTOM = -90

local SEMI_RADIUS_PER_QUAD = CURVED_RADIUS * 0.5

local SEMI_QUAD_DEEP = 1 / SEMI_RADIUS_PER_QUAD
local SEMI_QUAD_ACROSS = SEMI_QUAD_DEEP * 0.5
local SEMI_QUAD_SHIFT = 0.5

local UV = mod.dl.uv
local CURVED_ORIENTATIONS = {
	curved_top_left = { uvs = UV.flip_x(), offset_x = 1, offset_y = 1, reversed = false },
	curved_top_left_reversed = { uvs = UV.flip_x(), offset_x = 1, offset_y = 1, reversed = true },
	curved_top_right = { uvs = UV.none(), offset_x = -1, offset_y = 1, reversed = false },
	curved_top_right_reversed = { uvs = UV.none(), offset_x = -1, offset_y = 1, reversed = true },
	curved_bottom_left = { uvs = UV.flip_xy(), offset_x = 1, offset_y = -1, reversed = true },
	curved_bottom_left_reversed = { uvs = UV.flip_xy(), offset_x = 1, offset_y = -1, reversed = false },
	curved_bottom_right = { uvs = UV.flip_y(), offset_x = -1, offset_y = -1, reversed = true },
	curved_bottom_right_reversed = { uvs = UV.flip_y(), offset_x = -1, offset_y = -1, reversed = false },

	semicircle_right = {
		uvs = UV.none(),
		arc_top = SEMI_ARC_TOP,
		arc_bottom = SEMI_ARC_BOTTOM,
		quad_scale_x = SEMI_QUAD_DEEP,
		quad_scale_y = SEMI_QUAD_ACROSS,
		quad_offset_x = -SEMI_QUAD_SHIFT,
		quad_offset_y = 0,
		reversed = false,
	},
	semicircle_left = {
		uvs = UV.flip_x(),
		arc_top = SEMI_ARC_TOP,
		arc_bottom = SEMI_ARC_BOTTOM,
		quad_scale_x = SEMI_QUAD_DEEP,
		quad_scale_y = SEMI_QUAD_ACROSS,
		quad_offset_x = SEMI_QUAD_SHIFT,
		quad_offset_y = 0,
		reversed = false,
	},
	semicircle_top = {
		uvs = UV.none(),
		arc_top = SEMI_ARC_TOP,
		arc_bottom = SEMI_ARC_BOTTOM,
		rotation = SEMI_ROTATION_TOP,
		swap_axes = true,
		quad_scale_x = SEMI_QUAD_DEEP,
		quad_scale_y = SEMI_QUAD_ACROSS,
		quad_offset_x = 0,
		quad_offset_y = SEMI_QUAD_SHIFT,
		reversed = true,
	},
	semicircle_bottom = {
		uvs = UV.none(),
		arc_top = SEMI_ARC_TOP,
		arc_bottom = SEMI_ARC_BOTTOM,
		rotation = SEMI_ROTATION_BOTTOM,
		swap_axes = true,
		quad_scale_x = SEMI_QUAD_DEEP,
		quad_scale_y = SEMI_QUAD_ACROSS,
		quad_offset_x = 0,
		quad_offset_y = -SEMI_QUAD_SHIFT,
		reversed = false,
	},
}

for _, name in ipairs({ "semicircle_right", "semicircle_left", "semicircle_bottom", "semicircle_top" }) do
	local base = CURVED_ORIENTATIONS[name]
	local twin = {}
	for key, value in pairs(base) do
		twin[key] = value
	end
	twin.reversed = not base.reversed
	CURVED_ORIENTATIONS[name .. "_reversed"] = twin
end

local CURVED_DEFAULT_ORIENTATION = "curved_top_left"

local CURVED_ORIENTATION_ORDER = {
	"curved_top_left",
	"curved_top_right",
	"curved_bottom_left",
	"curved_bottom_right",
	"curved_top_left_reversed",
	"curved_top_right_reversed",
	"curved_bottom_left_reversed",
	"curved_bottom_right_reversed",
	"semicircle_top",
	"semicircle_bottom",
	"semicircle_left",
	"semicircle_right",
	"semicircle_top_reversed",
	"semicircle_bottom_reversed",
	"semicircle_left_reversed",
	"semicircle_right_reversed",
}

local CURVED_PASS_COLOR = { 255, 255, 255, 255 }

local CURVED_DEFAULT_OUTLINE = { 255, 255, 255, 255 }

---@type NodeType
local ProgressBar = {
	id = "progress_bar",
	label = "Progress bar",
	bindable = {
		"visible",
		"offset",
		"current",
		"max",
		"color",
		"bg_color",
		"outline_color",
		"segments",
		"segment_gap",
		"orientation",
	},

	style_knobs = {
		"visible",
		"offset",
		"size",

		"shape",
		"orientation",
		"segments",
		"segment_gap",
		"color",
		"bg_color",
		"outline_color",
	},

	threshold_values = { current = "current", max = "max" },
	callbacks = {
		value = {

			fields = {
				"size",
				"visible",
				"offset",
				"current",
				"max",
				"color",
				"bg_color",
				"outline_color",
				"segments",
				"segment_gap",
				"orientation",
			},
			scope = { "sources", "state", "block", "t", "dt" },
		},
		style = { scope = { "sources", "value", "state", "block", "t", "dt" } },
	},
}

---@param values table
---@return number
local function resolve_fraction(values)
	local p
	if values.current ~= nil or values.max ~= nil then
		local current = tonumber(values.current) or 0
		local max = tonumber(values.max) or 0
		p = (max > 0) and (current / max) or 0
	else
		p = tonumber(values.progress) or 0
	end
	if p < 0 then
		return 0
	elseif p > 1 then
		return 1
	end
	return p
end

---@param values table
---@param style table?
---@return string
local function resolve_shape(values, style)
	return values.shape or (style and style.shape) or DEFAULT_SHAPE
end

---@param orientation string?
---@return table
local function resolve_curved_orientation(orientation)
	return CURVED_ORIENTATIONS[orientation] or CURVED_ORIENTATIONS[CURVED_DEFAULT_ORIENTATION]
end

---@return table  a fresh ARGB the caller may keep
function ProgressBar.default_color()
	return table.clone(Thresholds.DEFAULT_COLOR)
end

---@return number
function ProgressBar.default_segment_gap()
	return SEGMENT_GAP
end

---@return string[]
function ProgressBar.curved_orientations()
	return CURVED_ORIENTATION_ORDER
end

---@param shape string
---@return string
function ProgressBar.default_orientation(shape)
	if shape == "curved" then
		return CURVED_DEFAULT_ORIENTATION
	end
	return DEFAULT_ORIENTATION
end

---@param values table
---@param style table?
---@return string|nil
function ProgressBar.implicit_material(values, style)
	if resolve_shape(values, style) == "curved" then
		return CURVED_MATERIAL
	end
	return nil
end

local curved_descriptors = setmetatable({}, { __mode = "k" })

---@type table<table, table<number, table<number, table>>>
local curved_arc_cache = setmetatable({}, { __mode = "k" })

---@param count number
---@param orientation table  a CURVED_ORIENTATIONS entry: supplies the sweep and the direction
---@param reversed boolean  walk the sweep from its far end, so segment 1 is still the first to fill
---@param gap number  blank arc fraction between segments (see curved_gap_fraction)
---@return table  count entries of { top, bottom }, in fill order
local function curved_segment_arcs(count, orientation, reversed, gap)
	local by_gap = curved_arc_cache[orientation]
	if not by_gap then
		by_gap = {}
		curved_arc_cache[orientation] = by_gap
	end
	local by_count = by_gap[gap]
	if not by_count then
		by_count = {}
		by_gap[gap] = by_count
	end
	local cached = by_count[count]
	if cached then
		return cached
	end

	local arcs = {}
	local arc_top = orientation.arc_top or CURVED_ARC_TOP
	local arc_bottom = orientation.arc_bottom or CURVED_ARC_BOTTOM
	local sweep = arc_top - arc_bottom
	local paint = sweep - (count - 1) * gap
	if paint < 0 then
		paint = 0
	end
	local each = paint / count

	local first_extra, rest_less = 0, 0
	if count > 1 and CURVED_FIRST_SEGMENT_BIAS ~= 0 then
		first_extra = CURVED_FIRST_SEGMENT_BIAS
		rest_less = CURVED_FIRST_SEGMENT_BIAS / (count - 1)

		if each + first_extra < 0 or each - rest_less < 0 then
			first_extra, rest_less = 0, 0
		end
	end

	local bottom = arc_bottom

	for i = 1, count do

		local is_first = reversed and (i == count) or (not reversed and i == 1)
		local top = bottom + each + (is_first and first_extra or -rest_less)

		if i == count then
			top = arc_top
		end
		arcs[reversed and (count - i + 1) or i] = { top, bottom }
		bottom = top + gap
	end

	by_count[count] = arcs
	return arcs
end

---@param values table
---@param style table?
---@return number
local function resolve_segment_gap(values, style)
	local gap = tonumber(values.segment_gap or (style and style.segment_gap))
	if not gap or gap < 0 then
		return SEGMENT_GAP
	end
	return gap
end

---@param gap_px number
---@param orientation table  a CURVED_ORIENTATIONS entry
---@return number
local function curved_gap_fraction(gap_px, orientation)
	local fraction = CURVED_SEGMENT_GAP * (gap_px / SEGMENT_GAP)
	local sweep = (orientation.arc_top or CURVED_ARC_TOP) - (orientation.arc_bottom or CURVED_ARC_BOTTOM)
	return (fraction > sweep) and sweep or fraction
end

local CURVED_OVERLAY_KEY = "overlay"

local CURVED_BACKGROUND_KEY = "background"

---@param index number  1-based segment
---@return string
local function curved_background_key(index)
	return CURVED_BACKGROUND_KEY .. index
end

---@param style table
---@param index number|string  1-based segment, or an overlay / background key; each needs its own descriptor (see above)
---@param silence_outline boolean?  never draw this ring's outline (see below)
---@return table
local function curved_descriptor(style, index, silence_outline)
	local per_node = curved_descriptors[style]
	if not per_node then
		per_node = {}
		curved_descriptors[style] = per_node
	end

	local descriptor = per_node[index]
	if not descriptor then
		descriptor = {
			material = CURVED_MATERIAL,
			values = {
				amount = 0,
				glow_on_off = 0,
				lightning_opacity = 0,
				arc_top_bottom = { CURVED_ARC_TOP, CURVED_ARC_BOTTOM },
				fill_outline_opacity = { CURVED_OPACITY_FILL, CURVED_OPACITY_OUTLINE },
				outline_color = { 1, 1, 1, 1 },
				fillcolor = { 1, 1, 1, 1 },
				SizeThicknessOutline = { CURVED_RADIUS, CURVED_THICKNESS, CURVED_OUTLINE_WIDTH },
			},
		}

		descriptor.values.fillTex = CURVED_FILL_TEXTURE

		if silence_outline then
			descriptor.outline_silenced = true
			descriptor.values.fill_outline_opacity[2] = 0
		end
		per_node[index] = descriptor
	end
	return descriptor
end

---@param slot table
---@param argb table
---@param intensity number
local function write_color_slot(slot, argb, intensity)
	for channel = 1, 3 do
		local value = ((argb[channel + 1] or 255) / 255) * intensity
		slot[channel] = (value > CURVED_INTENSITY_MAX) and CURVED_INTENSITY_MAX or value
	end
	slot[4] = 1
end

---@param ui_renderer table
---@param descriptor table
---@param uvs table
---@param fill_argb table
---@param outline_argb table
---@param rotation number?  degrees, spun about the quad centre; nil/0 takes Draw:texture's unrotated path
local function draw_curved_ring(ui_renderer, descriptor, uvs, fill_argb, outline_argb, x, y, z, w, h, rotation)
	write_color_slot(descriptor.values.fillcolor, fill_argb, CURVED_FILL_INTENSITY)
	write_color_slot(descriptor.values.outline_color, outline_argb, 1)

	local opacity = descriptor.values.fill_outline_opacity
	opacity[1] = CURVED_OPACITY_FILL * ((fill_argb[1] or 255) / 255)
	opacity[2] = descriptor.outline_silenced and 0 or CURVED_OPACITY_OUTLINE * ((outline_argb[1] or 255) / 255)

	local material = CompositeMaterial.resolve(ui_renderer, descriptor)
	if not material then
		return
	end

	DrawCalls.bind(ui_renderer):texture(material, x, y, z, w, h, CURVED_PASS_COLOR, uvs, rotation)
end

---@param ui_renderer table
---@param x number
---@param y number
---@param z number
---@param w number
---@param h number
---@param fill_argb table
---@param outline_argb table
---@param bg_argb table?  the background pass's colour, or nil to draw no background
---@param fraction number
---@param segments number
---@param gap number  blank arc fraction between segments
---@param orientation table  a CURVED_ORIENTATIONS entry
---@param style table
local function draw_curved(
	ui_renderer,
	x,
	y,
	z,
	w,
	h,
	fill_argb,
	outline_argb,
	bg_argb,
	fraction,
	segments,
	gap,
	orientation,
	style
)

	local quad_w, quad_h, quad_x, quad_y
	if orientation.quad_scale_x then

		local scale_w = orientation.swap_axes and h or w
		local scale_h = orientation.swap_axes and w or h
		quad_w = scale_w * orientation.quad_scale_x
		quad_h = scale_h * orientation.quad_scale_y
		quad_x = x + (w - quad_w) * 0.5 + w * orientation.quad_offset_x
		quad_y = y + (h - quad_h) * 0.5 + h * orientation.quad_offset_y
	else
		quad_w = w * CURVED_QUAD_SCALE_X
		quad_h = h * CURVED_QUAD_SCALE_Y
		quad_x = x + (w - quad_w) * 0.5 + w * CURVED_QUAD_OFFSET_X * orientation.offset_x
		quad_y = y + (h - quad_h) * 0.5 + h * CURVED_QUAD_OFFSET_Y * orientation.offset_y
	end

	local reversed = orientation.reversed ~= CURVED_SEGMENTS_REVERSED
	local arcs = curved_segment_arcs(segments, orientation, reversed, gap)

	local overlay_arc_top, overlay_arc_bottom

	for i = 1, segments do
		local descriptor = curved_descriptor(style, i)
		local arc = arcs[i]
		descriptor.values.arc_top_bottom[1] = arc[1]
		descriptor.values.arc_top_bottom[2] = arc[2]

		if bg_argb then
			local background = curved_descriptor(style, curved_background_key(i), true)
			background.values.arc_top_bottom[1] = arc[1]
			background.values.arc_top_bottom[2] = arc[2]
			background.values.amount = 1
			draw_curved_ring(
				ui_renderer,
				background,
				orientation.uvs,
				bg_argb,
				bg_argb,
				quad_x,
				quad_y,
				z,
				quad_w,
				quad_h,
				orientation.rotation
			)
		end

		local amount = fraction * segments - (i - 1)
		if amount < 0 then
			amount = 0
		elseif amount > 1 then
			amount = 1
		end

		if reversed and amount > 0 and amount < 1 then
			local span = arc[1] - arc[2]
			overlay_arc_top = arc[1]
			overlay_arc_bottom = arc[1] - span * amount
			amount = 0
		end

		descriptor.values.amount = amount
		draw_curved_ring(
			ui_renderer,
			descriptor,
			orientation.uvs,
			fill_argb,
			outline_argb,
			quad_x,
			quad_y,
			z + 1,
			quad_w,
			quad_h,
			orientation.rotation
		)
	end

	if overlay_arc_top then
		local overlay = curved_descriptor(style, CURVED_OVERLAY_KEY, true)
		overlay.values.arc_top_bottom[1] = overlay_arc_top
		overlay.values.arc_top_bottom[2] = overlay_arc_bottom
		overlay.values.amount = 1
		draw_curved_ring(
			ui_renderer,
			overlay,
			orientation.uvs,
			fill_argb,
			outline_argb,
			quad_x,
			quad_y,
			z + 1,
			quad_w,
			quad_h,
			orientation.rotation
		)
	end
end

---@param ui_renderer table
---@param x number
---@param y number
---@param z number
---@param scale number
---@param values table
---@param style table?
function ProgressBar.draw(ui_renderer, x, y, z, scale, values, style)
	local p = resolve_fraction(values)

	local fill_color = Color.rgba(values.color) or (style and style.color) or Thresholds.DEFAULT_COLOR
	local bg_color = Color.rgba(values.bg_color) or (style and style.bg_color) or BG_COLOR

	local draw_fill = fill_color[1] > 0
	local draw_bg = bg_color[1] > 0

	if not draw_fill and not draw_bg then
		return
	end

	local size = values.size or (style and style.size) or DEFAULT_SIZE
	local w = size[1] * scale
	local h = size[2] * scale

	local segments = math.floor(tonumber(values.segments or (style and style.segments)) or 1)
	if segments < 1 then
		segments = 1
	end

	local segment_gap = resolve_segment_gap(values, style)

	local orientation = values.orientation or (style and style.orientation)

	if style and resolve_shape(values, style) == "curved" then
		local outline_argb = Color.rgba(values.outline_color) or style.outline_color or CURVED_DEFAULT_OUTLINE

		local bg_argb = Color.rgba(values.bg_color) or style.bg_color
		if bg_argb and (bg_argb[1] or 255) <= 0 then
			bg_argb = nil
		end
		local curved = resolve_curved_orientation(orientation)
		draw_curved(
			ui_renderer,
			x,
			y,
			z,
			w,
			h,
			fill_color,
			outline_argb,
			bg_argb,
			p,
			segments,
			curved_gap_fraction(segment_gap, curved),
			curved,
			style
		)
		return
	end

	orientation = orientation or DEFAULT_ORIENTATION
	local is_center = orientation == "center" or orientation == "center_vertical"

	if is_center then
		segments = segments * 2
	end

	local vertical, u0, u1
	if orientation == "top_bottom" or orientation == "center_vertical" then

		vertical, u0, u1 = true, y, y + h
	elseif orientation == "bottom_top" then
		vertical, u0, u1 = true, y + h, y
	elseif orientation == "right_left" then
		vertical, u0, u1 = false, x + w, x
	else 
		vertical, u0, u1 = false, x, x + w
	end

	local fill_lo, fill_hi
	if is_center then
		fill_lo, fill_hi = 0.5 - p * 0.5, 0.5 + p * 0.5
	else
		fill_lo, fill_hi = 0, p
	end

	local d = DrawCalls.bind(ui_renderer)
	local function draw_band(a, b, color, z_offset)
		if b <= a then
			return
		end
		local pa = u0 + (u1 - u0) * a
		local pb = u0 + (u1 - u0) * b
		local lo = (pa < pb) and pa or pb
		local hi = (pa < pb) and pb or pa
		if vertical then
			d:rect(x, lo, z + z_offset, w, hi - lo, color)
		else
			d:rect(lo, y, z + z_offset, hi - lo, h, color)
		end
	end

	local axis_length = vertical and h or w
	local gap_fraction = 0
	if segments > 1 and axis_length > 0 then
		gap_fraction = (segment_gap * scale) / axis_length
	end
	local cell_fraction = (1 - gap_fraction * (segments - 1)) / segments
	if cell_fraction < 0 then
		cell_fraction = 0
	end

	local cell_content = 1 / segments
	for i = 0, segments - 1 do
		local cell_start = i * (cell_fraction + gap_fraction)
		local cell_end = cell_start + cell_fraction
		if draw_bg then
			draw_band(cell_start, cell_end, bg_color, 0)
		end
		local content_lo = i * cell_content
		local content_hi = content_lo + cell_content
		local slice_lo = (content_lo > fill_lo) and content_lo or fill_lo
		local slice_hi = (content_hi < fill_hi) and content_hi or fill_hi
		if draw_fill and slice_hi > slice_lo then
			local from = (slice_lo - content_lo) / cell_content
			local to = (slice_hi - content_lo) / cell_content
			draw_band(cell_start + from * cell_fraction, cell_start + to * cell_fraction, fill_color, 1)
		end
	end
end

Registry.register(ProgressBar)

mod.nodes_progress_bar = ProgressBar
return ProgressBar
