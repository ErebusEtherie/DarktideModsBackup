local mod = get_mod("LoadingBar")
local LoadingBarStyles = mod:io_dofile("LoadingBar/scripts/mods/LoadingBar/loading_bar_styles")

local LoadingBarRender = {}

local BASE_LAYER = 990
local TEXT_LAYER = 8

local FILL_FAIL_LIMIT = 45

local fill_fail_streak = 0
local material_failure = false

local function get_resolution()
	local width, height, scale

	if rawget(_G, "RESOLUTION_LOOKUP") then
		scale = RESOLUTION_LOOKUP.scale
		width = RESOLUTION_LOOKUP.width
		height = RESOLUTION_LOOKUP.height
	else
		width, height = Application.back_buffer_size()
		scale = 1
	end

	return width, height, scale or 1
end

local function make_color(color, alpha_scale)
	local c = color or { 255, 255, 255, 255 }
	local alpha = c[1] * (alpha_scale or 1)

	return Color(math.clamp(alpha, 0, 255), c[2], c[3], c[4])
end

local material_cache = {}
local material_cache_gui = nil

local function material_handle(gui, path)
	if material_cache_gui ~= gui then

		material_cache = {}
		material_cache_gui = gui
	end

	local cached = material_cache[path]

	if cached ~= nil then
		return cached or nil
	end

	local ok, handle = pcall(Gui.create_material, gui, path)

	if not ok or not handle then
		material_cache[path] = false
		mod:info("could not create material %q: %s", path, tostring(handle))

		return nil
	end

	material_cache[path] = handle

	return handle
end

local function forget_failed_materials()
	for path, handle in pairs(material_cache) do
		if handle == false then
			material_cache[path] = nil
		end
	end
end

local function material_for(gui, layer, progress)
	if not layer.material then
		return nil
	end

	local handle = material_handle(gui, layer.material)

	if not handle then
		return nil
	end

	if layer.progression then

		pcall(Material.set_scalar, handle, "progression", progress)
	end

	return handle
end

local function draw_texture(gui, layer, rect, scale, progress, alpha)
	local pad_w = (layer.pad and layer.pad[1] or 0) * scale
	local pad_h = (layer.pad and layer.pad[2] or 0) * scale

	local position = Vector3(rect.x - pad_w * 0.5, rect.y - pad_h * 0.5, BASE_LAYER + (layer.layer or 0))
	local size = Vector2(rect.w + pad_w, rect.h + pad_h)
	local color = make_color(layer.color, alpha)

	if layer.kind == "rect" then
		Gui.rect(gui, position, size, color)

		return true
	end

	local material = material_for(gui, layer, progress)

	if not material then
		return false
	end

	return (pcall(Gui2.bitmap, gui, material, 0, position, size, { color = color }))
end

local function draw_fill(gui, layer, rect, scale, progress, alpha)
	local fill_width = rect.w * progress

	if fill_width <= 0.5 then
		return true
	end

	local position = Vector3(rect.x, rect.y, BASE_LAYER + (layer.layer or 0))
	local size = Vector2(fill_width, rect.h)
	local color = make_color(layer.color, alpha)

	if not layer.material then
		Gui.rect(gui, position, size, color)

		return true
	end

	local material = material_for(gui, layer, progress)

	if not material then
		return false
	end

	return (pcall(
		Gui2.bitmap_uv,
		gui,
		material,
		0,
		Vector2(0, 0),
		Vector2(progress, 1),
		position,
		size,
		{ color = color }
	))
end

local function draw_endcap(gui, layer, rect, scale, progress, alpha)
	local cap_alpha = alpha

	if layer.fade_in and layer.fade_in > 0 then
		cap_alpha = cap_alpha * math.clamp(progress / layer.fade_in, 0, 1)
	end

	if cap_alpha <= 0.01 then
		return true
	end

	local material = material_for(gui, layer, progress)

	if not material then
		return false
	end

	local pad_y = (layer.pad_y or 0) * scale
	local width = (layer.width or 32) * scale
	local offset_x = (layer.offset_x or 0) * scale

	local position = Vector3(
		rect.x + rect.w * progress + offset_x,
		rect.y - pad_y * 0.5,
		BASE_LAYER + (layer.layer or 0)
	)
	local size = Vector2(width, rect.h + pad_y)

	return (pcall(Gui2.bitmap, gui, material, 0, position, size, { color = make_color(layer.color, cap_alpha) }))
end

local function draw_centered_text(gui, text, rect, scale, alpha, y_offset)
	if not text or text == "" then
		return
	end

	local font_manager = Managers.font

	if not font_manager then
		return
	end

	local ok, font_data = pcall(font_manager.data_by_type, font_manager, "machine_medium")

	if not ok or not font_data then
		return
	end

	local font_type = font_data.path
	local font_size = 22 * scale
	local options = { shadow = true, color = Color(255 * alpha, 255, 235, 150) }

	local extents_ok, text_min, text_max = pcall(Gui2.slug_text_extents, gui, text, font_type, font_size, options)
	local text_width = 0

	if extents_ok and text_min and text_max then
		text_width = text_max.x - text_min.x
	end

	local position = Vector3(
		rect.x + rect.w * 0.5 - text_width * 0.5,
		rect.y + y_offset,
		BASE_LAYER + TEXT_LAYER
	)

	pcall(Gui2.slug_text, gui, text, font_type, font_size, position, Vector2(math.huge, math.huge), options)
end

function LoadingBarRender.draw(gui, progress, reason, opts)
	if not gui then
		return
	end

	opts = opts or {}

	local width, height, scale = get_resolution()

	local requested_id = opts.style_id or "heavy"
	local style_id = requested_id

	if material_failure and style_id ~= "fallback" then
		style_id = "fallback"
	end

	local style = LoadingBarStyles.get(style_id)

	local bar_scale = scale * (opts.scale or 1)
	local bar_w = style.bar_width * bar_scale
	local bar_h = style.bar_height * bar_scale
	local margin = (opts.bottom_margin or 90) * scale

	local rect = {
		x = width * 0.5 - bar_w * 0.5,
		y = height - margin - bar_h,
		w = bar_w,
		h = bar_h,
	}

	local alpha = opts.alpha or 1
	local p = math.clamp(progress or 0, 0, 1)

	local layers = style.layers
	local fill_drew = true

	for i = 1, #layers do
		local layer = layers[i]
		local kind = layer.kind

		if kind == "fill" then
			fill_drew = draw_fill(gui, layer, rect, bar_scale, p, alpha)
		elseif kind == "endcap" then
			draw_endcap(gui, layer, rect, bar_scale, p, alpha)
		else
			draw_texture(gui, layer, rect, bar_scale, p, alpha)
		end
	end

	if style_id == requested_id and requested_id ~= "fallback" then
		if fill_drew then
			fill_fail_streak = 0
		else
			fill_fail_streak = fill_fail_streak + 1

			if fill_fail_streak >= FILL_FAIL_LIMIT then
				material_failure = true
				mod:info("Bar art unavailable during loading; using the plain style for this loading screen.")
			end
		end
	end

	local label = nil

	if opts.show_reason and reason then
		label = reason
	end

	if opts.show_percentage then
		local pct = string.format("%d%%", math.floor(p * 100))
		label = label and (label .. "  -  " .. pct) or pct
	end

	if label then
		draw_centered_text(gui, label, rect, bar_scale, alpha, -(style.text_gap * bar_scale))
	end
end

function LoadingBarRender.reset_material_failure()
	material_failure = false
	fill_fail_streak = 0

	forget_failed_materials()
end

return LoadingBarRender
