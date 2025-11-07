local mod = get_mod("DumpStatFinder")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local _debug_render_scenegraph_text_options = {
	shadow = true,
	horizontal_alignment = Gui.HorizontalAlignCenter,
	vertical_alignment = Gui.VerticalAlignCenter,
}

local function debug_render_scenegraph(ui_renderer, scenegraph, n_scenegraph)
	local draw_color = Color.maroon(64, true)
	local draw_text_color = Color.white(255, true)
	local font_size = 16
	local font_type = "arial"

	ui_renderer.render_settings.material_flags = 0

	for i = 1, n_scenegraph do
		local draw = true
		local scenegraph_object = scenegraph[i]
		local size = Vector2(unpack(scenegraph_object.size))
		local scenegraph_object_scale = scenegraph_object.scale
		local scenegraph_object_parent = scenegraph_object.parent

		if not scenegraph_object_parent and not scenegraph_object_scale or scenegraph_object_scale == "fit" then
			local inverse_scale = ui_renderer.inverse_scale
			local w, h = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height

			size[1] = w * inverse_scale
			size[2] = h * inverse_scale
			draw = false
		end

		-- local color = draw_color

		-- if scenegraph_object.debug_mark then
		-- 	color = Color.green(64, true)
		-- end

		-- if draw then
		-- 	UIRenderer.draw_rect(ui_renderer, Vector3(unpack(scenegraph_object.world_position)), size, color)
		-- end

		if draw then
			local position = Vector3(
				scenegraph_object.world_position[1] - 20,
				scenegraph_object.world_position[2] - 20,
				scenegraph_object.world_position[3] + 100
			)

			UIRenderer.draw_text(
				ui_renderer,
				scenegraph_object.name,
				font_size,
				font_type,
				position,
				size,
				draw_text_color,
				_debug_render_scenegraph_text_options
			)
		end

		local children = scenegraph_object.children

		if children then
			debug_render_scenegraph(ui_renderer, children, #children)
		end
	end
end

mod.debug_scenegraph = false
mod:command("debug_scene", "", function()
	mod.debug_scenegraph = not mod.debug_scenegraph
end)

local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")

mod:hook_safe(UIRenderer, "begin_pass", function(self, ui_scenegraph, input_service, dt, render_settings)
	if mod.debug_scenegraph then
		debug_render_scenegraph(self, ui_scenegraph.hierarchical_scenegraph, ui_scenegraph.n_hierarchical_scenegraph)
	end
end)
