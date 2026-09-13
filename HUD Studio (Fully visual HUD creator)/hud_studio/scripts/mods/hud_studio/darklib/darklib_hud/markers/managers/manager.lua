

local Vector3Box = Vector3Box
local Unit = Unit
local table_remove = table.remove

---@param module DLH_Marker
---@param mod DL_Mod
return function(module, mod)
	if module.manager then
		return module.manager
	end

	---@type DLH_MarkerStyle
	local DEFAULTS = {
		font = "proxima_nova_medium",
		font_size = 24,
		color = { 255, 255, 255, 255 },
		lifetime = 1.25,

		text_box_size = { 300, 80 },
		z_lift = 10,
		z_layer = 0,

		texture_size = { 32, 32 },
		texture_color = { 255, 255, 255, 255 },

		shadow_alpha = 150,
		shadow_offset_base = 1,
		shadow_offset_font_scale = 0.01,

		background_padding = 3,

		line_gap = 0,

		max_active = 30,

		persistent = false,

		visible_fade_time = 0.15,

		world_lift = 0,

		max_distance = 0,
		fade_in_distance = 10,

		scale_near_distance = 0,
		scale_far_distance = 0,
		scale_near = 1,
		scale_far = 0.5,

	}

	local State = {
		markers = {},
		styles = {},
	}

	module.state = State

	---@class DLH_MarkerManager
	local Manager = {}

	local function build_style(out, style)
		for key in pairs(out) do
			out[key] = nil
		end
		for key, value in pairs(DEFAULTS) do
			out[key] = value
		end
		if style then
			for key, value in pairs(style) do
				out[key] = value
			end
		end

		local animator = out.animate
		if animator ~= nil and (type(animator) ~= "table" or type(animator.update) ~= "function") then
			mod.dl_hud.report(
				"markers/animate/animate.lua",
				"register_style",
				"style `animate` must come from mod.dl_hud.marker.animate.*(); falling back to animate.pop_fade()"
			)
			out.animate = nil
		end

		if out.animate == nil then
			out.animate = module.animate.pop_fade()
		end

		if out.visible_fn ~= nil and type(out.visible_fn) ~= "function" then
			mod.dl_hud.report(
				"markers/managers/manager.lua",
				"register_style",
				"style `visible_fn` must be a function(marker) -> boolean; ignoring it"
			)
			out.visible_fn = nil
		end

		return out
	end

	function Manager.register_style(key, style)
		State.styles[key] = build_style(State.styles[key] or {}, style)
		return State.styles[key]
	end

	function Manager.has_style(key)
		return State.styles[key] ~= nil
	end

	local function resolve_lines(style, opts)
		local out = {}
		local specs = style.lines

		if not specs then
			local text = opts.text
			if text ~= nil and text ~= "" then
				out[1] = {
					kind = "text",
					text = tostring(text),
					font = opts.font or style.font,
					font_size = opts.font_size or style.font_size,
					color = opts.color or style.color,
					align = opts.align or "center",
					gap = 0,
					shadow = true,
				}
			end
			return out
		end

		local fire_lines = opts.lines

		for i = 1, #specs do
			local spec = specs[i]
			local id = spec.id or i

			local content = fire_lines and fire_lines[id]

			if content == nil and i == 1 then
				content = opts.text
			end

			local text, o_color, o_font, o_size, o_align, o_texture, o_tex_size
			if type(content) == "table" then
				text = content.text
				o_color, o_font, o_size, o_align = content.color, content.font, content.font_size, content.align
				o_texture, o_tex_size = content.texture, content.size
			elseif content ~= nil then
				text = content
			end

			local texture = o_texture or spec.texture

			if texture then
				local size = o_tex_size or spec.size or style.texture_size
				out[#out + 1] = {
					kind = "texture",
					texture = texture,
					width = size[1],
					height = size[2],
					color = o_color or spec.color or style.texture_color,
					align = o_align or spec.align or "center",
					gap = spec.gap or style.line_gap or 0,

					shadow = spec.shadow == true,
				}
			elseif text ~= nil and text ~= "" then
				out[#out + 1] = {
					kind = "text",
					text = tostring(text),
					font = o_font or spec.font or style.font,
					font_size = o_size or spec.font_size or style.font_size,
					color = o_color or spec.color or style.color,
					align = o_align or spec.align or "center",
					gap = spec.gap or style.line_gap or 0,
					shadow = spec.shadow ~= false,
				}
			end
		end

		return out
	end

	local function style_census(style)
		local markers = State.markers
		local count, oldest = 0, nil

		for i = 1, #markers do
			if markers[i].style == style then
				count = count + 1

				oldest = oldest or i
			end
		end

		return count, oldest
	end

	function Manager.fire(key, opts)
		local style = State.styles[key]
		if not style then
			return nil
		end

		opts = opts or {}

		local unit = opts.unit
		local world_pos = opts.world_pos

		local unit_node = nil

		if unit then
			if not Unit.alive(unit) then
				return nil
			end

			local node_name = opts.unit_node
			unit_node = node_name and Unit.has_node(unit, node_name) and Unit.node(unit, node_name) or 1
			world_pos = Unit.world_position(unit, unit_node)
		end

		if not world_pos then
			return nil
		end

		local markers = State.markers
		local count, oldest = style_census(style)

		if count >= style.max_active then

			if style.persistent then
				return nil
			end

			while oldest and count >= style.max_active do
				table_remove(markers, oldest)
				count, oldest = style_census(style)
			end
		end

		local duration = nil
		if not style.persistent then
			duration = opts.lifetime or style.lifetime
		end

		local marker = {
			style = style,
			pos = Vector3Box(world_pos),

			unit = unit,

			unit_node = unit_node,

			data = opts.data,
			time = 0,
			duration = duration,
			scale_mult = opts.scale_mult or 1,
			alpha_mult = opts.alpha_mult or 1,

			lines = resolve_lines(style, opts),
		}

		if style.visible_fn then
			marker.visible = style.visible_fn(marker) and 1 or 0
		else
			marker.visible = 1
		end

		local animator = style.animate
		if animator.spawn then
			animator.spawn(marker, opts)
		end

		markers[#markers + 1] = marker

		return marker
	end

	function Manager.remove(handle)
		if not handle then
			return false
		end

		local markers = State.markers
		for i = 1, #markers do
			if markers[i] == handle then
				table_remove(markers, i)
				return true
			end
		end

		return false
	end

	function Manager.is_active(handle)
		if not handle then
			return false
		end

		local markers = State.markers
		for i = 1, #markers do
			if markers[i] == handle then
				return true
			end
		end

		return false
	end

	function Manager.clear(key)
		local markers = State.markers

		if key == nil then
			for i = #markers, 1, -1 do
				markers[i] = nil
			end
			return
		end

		local style = State.styles[key]
		if not style then
			return
		end

		for i = #markers, 1, -1 do
			if markers[i].style == style then
				table_remove(markers, i)
			end
		end
	end

	module.manager = Manager

	return Manager
end
