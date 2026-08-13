

---@type mod
local mod = get_mod("dopamine")

local Layout = mod:core(mod.layout, "hud/layout")
local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/layout_debug/definitions")
local Constants = mod:core(mod.constants, "hud/constants")

local THICKNESS = 2
local Z = 50

local WIDTH = {}
for _, box in ipairs(Definitions.boxes) do
	WIDTH[box.id] = box.width
end

local HudLayoutDebug = class("HudLayoutDebug", "HudElementBase")

HudLayoutDebug.init = function(self, parent, draw_layer, start_scale)
	HudLayoutDebug.super.init(self, parent, draw_layer + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})
end

HudLayoutDebug._set_box = function(self, id, side, top_y, height, visible)
	local width = WIDTH[id]
	local halign = side == "left" and "left" or "right"

	self:set_scenegraph_position("node_" .. id, Layout.margin_x(halign), top_y, Z, halign, "top")

	local alpha = (visible and height > 0) and 255 or 0
	local style = self._widgets_by_name["box_" .. id].style

	local function put(edge, ox, oy, ow, oh)
		local st = style[id .. "_" .. edge]
		st.offset[1] = ox
		st.offset[2] = oy
		st.size[1] = ow
		st.size[2] = oh
		st.color[1] = alpha
	end

	put("top", 0, 0, width, THICKNESS)
	put("bottom", 0, height - THICKNESS, width, THICKNESS)
	put("left", 0, 0, THICKNESS, height)
	put("right", width - THICKNESS, 0, THICKNESS, height)
end

HudLayoutDebug.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudLayoutDebug.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local on = mod.dl.settings.debug_layout_boxes == true
	local score_on = on and Layout.score_enabled()
	local fury_on = on and Layout.fury_slotted()
	local task_on = on and Layout.tasks_enabled()
	local stats_on = on and Layout.stats_enabled()
	local score_side = Layout.score_side()
	local fury_side = Layout.fury_side()
	local objective_side = Layout.objective_side()
	local stats_side = Layout.stats_side()

	self:_set_box("fury", fury_side, Layout.fury_top_y(), Layout.fury_height(), fury_on)
	self:_set_box("style", score_side, Layout.style_top_y(), Layout.style_height(), score_on)
	self:_set_box("task", objective_side, Layout.task_track_top_y(), Layout.task_track_height(), task_on)
	self:_set_box("stats", stats_side, Layout.stats_top_y(), Layout.stats_height(), stats_on)
end

return HudLayoutDebug
