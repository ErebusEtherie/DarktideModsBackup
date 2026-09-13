

---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local Block = mod:core(mod.hud_studio_block, "blocks/block")
local Context = mod:core(mod.hud_studio_context, "engine/context")
local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Session = mod:core(mod.hud_studio_session, "document/session")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")
local CompositeMaterial = mod:core(mod.hud_studio_composite_material, "blocks/composite_material")
local HudScale = mod:core(mod.hud_studio_scale, "blocks/hud_scale")

local Profiler = mod:core(mod.hud_studio_profiler, "hud/editor/profiler")

local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")

local time = mod.dl.time

local ZERO = { 0, 0 }
local EMPTY = {}

local NODE_Z_STEP = 2

local merged_style = setmetatable({}, { __mode = "k" })

---@param node Node
---@param patch table|nil   this frame's evaluated style patch, nil when the node has no binding
---@return table|nil
local function effective_style(node, patch)
	local base = node.style
	if not patch or next(patch) == nil then
		return base
	end
	local out = merged_style[node]
	if not out then
		out = {}
		merged_style[node] = out
	else

		for k in pairs(out) do
			out[k] = nil
		end
	end
	if base then
		for k, v in pairs(base) do
			out[k] = v
		end
	end
	for k, v in pairs(patch) do
		out[k] = v
	end
	return out
end

local HudCanvas = class("HudCanvas", "HudElementBase")

HudCanvas.init = function(self, parent, draw_layer, start_scale)
	HudCanvas.super.init(self, parent, draw_layer, start_scale, {

		scenegraph_definition = {
			screen = UIWorkspaceSettings.screen,
		},

		widget_definitions = {
			canvas = UIWidget.create_definition({
				{
					pass_type = "logic",
					style_id = "canvas",
					value = function(...)
						self:_draw(...)
					end,
					style = {
						horizontal_alignment = "left",
						vertical_alignment = "top",
						offset = { 0, 0, 1 },
					},
				},
			}, "screen"),
		},
	})

	---@type table<integer, table>
	self._evaluated = {}
	self._frame = 0

	Session.reload()
	---@type Block[]
	self._blocks = Session.blocks()
end

---@param ui_renderer table
HudCanvas.destroy = function(self, ui_renderer)
	CompositeMaterial.release_renderer(ui_renderer)
	HudCanvas.super.destroy(self, ui_renderer)
end

HudCanvas.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	self._frame = self._frame + 1

	time.tick()

	local ctx = Context.build(dt, t)

	local Gameplay = mod.dl.gameplay
	local game_mode_name = Gameplay and Gameplay.game_mode_name()
	if game_mode_name == "shooting_range" then
		ctx.gamemode = "meatgrinder"
	else
		ctx.gamemode = (Gameplay and Gameplay.is_in_gameplay()) and "mission" or "mourningstar"
	end
	local Player = mod.dl.player
	local local_player = Player and Player.local_player and Player.local_player()
	ctx.archetype = local_player and mod.dl.archetypes.resolve(Player.archetype_name(local_player)) or nil

	if ctx.gamemode ~= self._last_gamemode then
		self._last_gamemode = ctx.gamemode
		Block.arm_budget()
	end
	Block.tick_budget(mod.hud_studio_editor_active == true)

	Registry.begin_frame(self._frame, ctx)

	local force_block = Session.force_block
	local force_hover_block = Session.force_hover_block
	ctx.force_nodes = Session.force_nodes

	local hide_hidden = Session.hides_hidden_blocks()
	local hidden = Session.hidden_blocks
	local block_scales = Session.block_scales

	Profiler.eval_begin()

	for b = 1, #self._blocks do
		local block = self._blocks[b]

		local folder_off = Session.folder_hidden(block)

		local blocked = block:missing_requires() ~= nil
		local visible = false
		if not blocked and not folder_off then
			local ok_vis, result = pcall(block.is_visible, block, ctx)

			visible = not (ok_vis and result == false)
		end

		hidden[block] = (not visible) or nil
		if not visible and (blocked or hide_hidden or (block ~= force_block and block ~= force_hover_block)) then
			self._evaluated[b] = false

			block_scales[block] = nil
		else
			local ok, evaluated = pcall(block.evaluate, block, ctx)
			self._evaluated[b] = ok and evaluated or nil

			local ok_scale, block_scale = pcall(block.get_scale, block, ctx)
			block_scales[block] = (ok_scale and block_scale) or 1
		end
	end

	Profiler.eval_end(self._evaluated, #self._blocks)

	HudCanvas.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudCanvas._draw = function(self, pass, ui_renderer, ui_style, ui_content, position, size)
	local blocks = self._blocks
	if #blocks == 0 then
		return
	end

	Profiler.draw_begin()

	local scale = HudScale.pct()
	local block_scales = Session.block_scales

	local inv_scale = ui_renderer.inverse_scale or 1
	local screen_w = ((RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) and RESOLUTION_LOOKUP.width * inv_scale)
		or size[1]
	local screen_h = ((RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) and RESOLUTION_LOOKUP.height * inv_scale)
		or size[2]
	local center_x = screen_w * 0.5
	local center_y = screen_h * 0.5

	local z_base = position[3] or 1

	local node_z = z_base

	for b = 1, #blocks do
		local block = blocks[b]
		local evaluated = self._evaluated[b]

		if evaluated ~= false then
			local nodes = block.nodes
			local block_off = block.offset or ZERO
			local bx = center_x + (block_off[1] or 0) * scale
			local by = center_y + (block_off[2] or 0) * scale

			local block_scale = block_scales[block] or 1
			local node_scale = scale * block_scale

			local block_fade = block:get_fade_state()

			for i = 1, #nodes do
				local node = nodes[i]
				local z = node_z
				node_z = node_z + NODE_Z_STEP
				local node_type = NodeTypes.get(node.type)
				local ev = evaluated and evaluated[i]

				local style = effective_style(node, ev and ev.style)

				local hidden = (ev and ev.hidden) or (style and style.visible == false)
				if node_type and node_type.draw and not hidden then
					local values = (ev and ev.values) or node.values or EMPTY

					local node_off = values.offset or (ev and ev.style and ev.style.offset) or node.offset or ZERO
					local x = bx + (node_off[1] or 0) * node_scale
					local y = by + (node_off[2] or 0) * node_scale

					local draw_it = true

					local mat = CompositeMaterial.base(values.material or (style and style.material))

					if not mat and node_type.implicit_material then
						mat = node_type.implicit_material(values, style)
					end
					if mat and not MaterialDeps.ready_to_draw(mat) then
						draw_it = false
					end

					if draw_it then

						local rs = ui_renderer.render_settings
						local prev_alpha = rs.alpha_multiplier or 1
						local node_fade = ev and ev.node_fade or 1
						rs.alpha_multiplier = prev_alpha * block_fade * node_fade
						pcall(node_type.draw, ui_renderer, x, y, z, node_scale, values, style, block.name, node)
						rs.alpha_multiplier = prev_alpha
					end
				end
			end
		end
	end

	Profiler.draw_end()
end

return HudCanvas
