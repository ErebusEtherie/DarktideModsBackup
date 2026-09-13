

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local Camera = Camera
local Quaternion = Quaternion
local Managers = Managers
local Vector3 = Vector3
local Vector2 = Vector2
local Unit = Unit
local table_remove = table.remove
local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max

local draw_color = { 255, 255, 255, 255 }
local shadow_color = { 255, 0, 0, 0 }
local background_color = { 0, 0, 0, 0 }
local draw_pos = { 0, 0, 0 }
local shadow_pos = { 0, 0, 0 }
local tex_size = { 0, 0 }
local draw_opts = {}

local line_w = {}
local line_h = {}

local draw_size = { 0, 0 }

local GUI_ALIGN = {
	left = Gui.HorizontalAlignLeft,
	center = Gui.HorizontalAlignCenter,
	right = Gui.HorizontalAlignRight,
}

local anim_ctx = {}
local anim_out = {}

local function get_camera()
	local ui_manager = Managers.ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")

	return world_markers and world_markers:_get_camera() or nil
end

local function draw_marker(
	ui_renderer,
	animation,
	camera,
	marker,
	cam_pos,
	cam_fwd_x,
	cam_fwd_y,
	cam_fwd_z,
	inv_scale,
	z_base,
	dt,
	vertical_fov
)
	local style = marker.style
	local lines = marker.lines
	local line_count = #lines

	if line_count == 0 then
		return
	end

	local visible = marker.visible
	if visible ~= nil and visible <= 0 then
		return
	end

	local text_box = style.text_box_size

	local unit = marker.unit
	if unit and Unit.alive(unit) then
		marker.pos:store(Unit.world_position(unit, marker.unit_node))
	end

	local world_pos = marker.pos:unbox()
	local world_x, world_y, world_z = world_pos.x, world_pos.y, world_pos.z

	local world_lift = style.world_lift
	if world_lift and world_lift ~= 0 then
		world_z = world_z + world_lift
	end

	local to_marker_x = world_x - cam_pos.x
	local to_marker_y = world_y - cam_pos.y
	local to_marker_z = world_z - cam_pos.z

	if (to_marker_x * cam_fwd_x + to_marker_y * cam_fwd_y + to_marker_z * cam_fwd_z) <= 0 then
		return
	end

	local dist_to_camera = math_sqrt(to_marker_x * to_marker_x + to_marker_y * to_marker_y + to_marker_z * to_marker_z)
	local screen_pos = Camera.world_to_screen(camera, Vector3(world_x, world_y, world_z))
	local screen_x = screen_pos[1] * inv_scale
	local screen_y = screen_pos[2] * inv_scale

	local elapsed = marker.time
	local duration = marker.duration

	anim_ctx.animation = animation
	anim_ctx.dt = dt
	anim_ctx.elapsed = elapsed
	anim_ctx.duration = duration
	anim_ctx.progress = duration and (elapsed / duration) or 0
	anim_ctx.dist_to_camera = dist_to_camera
	anim_ctx.screen_x = screen_x
	anim_ctx.screen_y = screen_y
	anim_ctx.vertical_fov = vertical_fov

	anim_out.offset_x = 0
	anim_out.offset_y = 0
	anim_out.scale = 1
	anim_out.alpha = 1

	style.animate.update(marker, anim_out, anim_ctx)

	local alpha = anim_out.alpha * (marker.alpha_mult or 1) * (visible or 1)

	if alpha <= 0 then
		return
	end

	local scale = anim_out.scale * (marker.scale_mult or 1)

	local center_x = screen_x + anim_out.offset_x
	local center_y = screen_y + anim_out.offset_y

	local block_w = 0
	local block_h = 0
	for i = 1, line_count do
		local line = lines[i]
		local w, h

		if line.kind == "texture" then
			w, h = line.width * scale, line.height * scale
		else

			w, h = UIRenderer.text_size(ui_renderer, line.text, line.font, line.font_size * scale)
			w = w * inv_scale
			h = h * inv_scale
		end

		line_w[i] = w
		line_h[i] = h
		if w > block_w then
			block_w = w
		end
		block_h = block_h + h
		if i > 1 then
			block_h = block_h + line.gap
		end
	end

	local block_x = center_x - block_w * 0.5
	local block_y = center_y - block_h * 0.5
	local z = z_base + style.z_lift + style.z_layer

	local bg = style.background_color
	if bg then
		local pad = (style.background_padding or 0) * scale

		background_color[1] = (bg[1] or 255) * alpha
		background_color[2] = bg[2] or 0
		background_color[3] = bg[3] or 0
		background_color[4] = bg[4] or 0

		UIRenderer.draw_rect(
			ui_renderer,
			Vector3(block_x - pad, block_y - pad, z - 2),
			Vector2(block_w + pad * 2, block_h + pad * 2),
			background_color
		)
	end

	local cursor_y = block_y
	for i = 1, line_count do
		local line = lines[i]
		if i > 1 then
			cursor_y = cursor_y + line.gap
		end

		local w = line_w[i]
		local align = line.align

		local place_x = block_x
		local place_y = cursor_y

		if line.kind == "texture" then
			if align == "right" then
				place_x = block_x + (block_w - w)
			elseif align ~= "left" then
				place_x = block_x + (block_w - w) * 0.5
			end
		end

		local color = line.color
		draw_color[1] = (color[1] or 255) * alpha
		draw_color[2] = color[2] or 255
		draw_color[3] = color[3] or 255
		draw_color[4] = color[4] or 255

		draw_pos[1] = place_x
		draw_pos[2] = place_y
		draw_pos[3] = z

		if line.kind == "texture" then

			tex_size[1] = w
			tex_size[2] = line_h[i]

			if line.shadow then

				local shadow_offset = style.shadow_offset_base * scale
				shadow_pos[1] = place_x + shadow_offset
				shadow_pos[2] = place_y + shadow_offset
				shadow_pos[3] = z - 1
				shadow_color[1] = style.shadow_alpha * alpha
				UIRenderer.draw_texture(ui_renderer, line.texture, shadow_pos, tex_size, shadow_color)
			end

			UIRenderer.draw_texture(ui_renderer, line.texture, draw_pos, tex_size, draw_color)
		else
			local size = line.font_size * scale

			local gui_align = GUI_ALIGN[align] or GUI_ALIGN.center
			local slack = size
			local slack_shift = 0
			if gui_align == Gui.HorizontalAlignCenter then
				slack_shift = slack * 0.5
			elseif gui_align == Gui.HorizontalAlignRight then
				slack_shift = slack
			end

			draw_opts.horizontal_alignment = gui_align
			draw_size[1] = block_w + slack
			draw_size[2] = text_box[2]
			draw_pos[1] = place_x - slack_shift

			if line.shadow then

				local shadow_offset = size * style.shadow_offset_font_scale + style.shadow_offset_base * scale
				shadow_pos[1] = place_x - slack_shift + shadow_offset
				shadow_pos[2] = place_y + shadow_offset
				shadow_pos[3] = z - 1
				shadow_color[1] = style.shadow_alpha * alpha
				UIRenderer.draw_text(
					ui_renderer,
					line.text,
					size,
					line.font,
					shadow_pos,
					draw_size,
					shadow_color,
					draw_opts
				)
			end

			UIRenderer.draw_text(ui_renderer, line.text, size, line.font, draw_pos, draw_size, draw_color, draw_opts)
		end

		cursor_y = cursor_y + line_h[i]
	end
end

local function advance_marker(marker, dt)
	marker.time = marker.time + dt

	local visible_fn = marker.style.visible_fn
	if visible_fn then
		local target = visible_fn(marker) and 1 or 0
		local fade_time = marker.style.visible_fade_time

		if not fade_time or fade_time <= 0 then
			marker.visible = target
		else
			local step = dt / fade_time
			local current = marker.visible or 1

			if target > current then
				marker.visible = math_min(target, current + step)
			else
				marker.visible = math_max(target, current - step)
			end
		end
	end

	return marker.duration ~= nil and marker.time >= marker.duration
end

local function markers_draw_function(self, pass, ui_renderer, ui_style, ui_content, position, size)

	local module = self._module
	local markers = module.state.markers
	local marker_count = #markers

	if marker_count == 0 then
		return
	end

	local dt = ui_renderer.dt
	local animation = self._mod.dl.animation
	local inv_scale = ui_renderer.inverse_scale
	local z_base = position[3]

	local camera = get_camera()

	if not camera then

		for i = marker_count, 1, -1 do
			if advance_marker(markers[i], dt) then
				table_remove(markers, i)
			end
		end
		return
	end

	local cam_pos = Camera.world_position(camera)
	local cam_fwd = Quaternion.forward(Camera.world_rotation(camera))
	local cam_fwd_x, cam_fwd_y, cam_fwd_z = cam_fwd.x, cam_fwd.y, cam_fwd.z

	local vertical_fov = Camera.vertical_fov(camera)

	for i = 1, marker_count do
		draw_marker(
			ui_renderer,
			animation,
			camera,
			markers[i],
			cam_pos,
			cam_fwd_x,
			cam_fwd_y,
			cam_fwd_z,
			inv_scale,
			z_base,
			dt,
			vertical_fov
		)
	end

	for i = marker_count, 1, -1 do
		if advance_marker(markers[i], dt) then
			table_remove(markers, i)
		end
	end
end

local HudMarkers = class("DarkLibHudMarker@" .. tostring({}), "HudElementBase")

HudMarkers.init = function(self, parent, draw_layer, start_scale, context)
	local mod = get_mod(context.mod_name)

	self._mod = mod

	self.__class_name = context.class_name

	self._module = mod.dl_hud.__hud_modules["marker"]

	self._definitions = self._module.hud_definitions

	HudMarkers.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = self._definitions.scenegraph_definition,
		widget_definitions = self._definitions.widget_definitions(function(...)
			markers_draw_function(self, ...)
		end),
	})
end

HudMarkers.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudMarkers.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudMarkers
