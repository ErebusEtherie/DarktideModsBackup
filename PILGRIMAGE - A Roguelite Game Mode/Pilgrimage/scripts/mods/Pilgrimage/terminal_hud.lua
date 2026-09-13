-- terminal_hud.lua
--
-- The "Press E" panel that appears when you walk up to the terminal.
--
-- WHY THIS IS A SEPARATE FILE AND A DIFFERENT SHAPE TO EVERYTHING ELSE
--
-- Every other module in this mod is a plain table with an init that receives its
-- dependencies. This one cannot be, because DMF hands the class name and file path to
-- the game's HUD system and the GAME constructs the object, on its own schedule, with
-- its own arguments. We never get to inject anything.
--
-- So it reaches back through the mod object for exactly one function,
-- mod.pilgrimage_terminal_prompt, set by terminal.lua's init. One read-only accessor,
-- called once per frame, returning either nil or a table it must not modify. That is the
-- entire contract between the two files.
--
-- WHAT IT ACTUALLY DOES
--
-- A HUD element draws in screen space, but the terminal is a thing in the world. So each
-- frame we take the terminal's world position and ask the camera where that lands on
-- screen:
--
--     Camera.world_to_screen(camera, world_position)  -> screen position, distance
--     Camera.inside_frustum(camera, world_position)   -> > 0 when it is on screen at all
--
-- and then move the panel's offset to sit just above that point. The frustum check is
-- what stops the panel appearing pinned to the edge of the screen when the terminal is
-- behind you: world_to_screen will happily return coordinates for a point that is
-- somewhere off in the wrong direction.
--
-- Every one of those calls is wrapped in pcall. The camera can be mid-transition, the
-- position can be degenerate, and a HUD element that throws does so sixty times a second
-- forever. Failure here has to mean "draw nothing this frame", never "stop the game".

local mod = get_mod("Pilgrimage")

local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIFontSettings      = require("scripts/managers/ui/ui_font_settings")
local UIHudSettings       = require("scripts/settings/ui/ui_hud_settings")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

require("scripts/ui/hud/elements/hud_element_base")

local get_hud_color = UIHudSettings.get_hud_color

local PANEL_WIDTH  = 320
local PANEL_HEIGHT = 76
local TOP_HEIGHT   = 30

-- How far above the projected point the panel sits, in screen pixels. Enough to clear
-- the world marker icon rather than overlapping it.
local VERTICAL_LIFT = 24

-- ---------------------------------------------------------------------------
-- Scenegraph
--
-- One node, anchored top-left of the screen. We then drive its offset directly every
-- frame from the projected world position. Anchoring top-left rather than centre means
-- the offset we compute is the panel's actual screen position with no extra arithmetic.
-- ---------------------------------------------------------------------------

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,

	prompt = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { PANEL_WIDTH, PANEL_HEIGHT },
		position = { 0, 0, 100 },
	},
}

-- ---------------------------------------------------------------------------
-- Text styles
--
-- table.clone on the game's own hud_body font settings, so the panel inherits the game's
-- font, outline and scaling behaviour rather than looking like something bolted on.
-- Cloned, not referenced, because these style tables are shared globals and mutating one
-- in place would restyle every HUD element in the game.
-- ---------------------------------------------------------------------------

local title_style = table.clone(UIFontSettings.hud_body)
title_style.font_size = 18
title_style.horizontal_alignment = "left"
title_style.vertical_alignment = "top"
title_style.text_horizontal_alignment = "left"
title_style.text_vertical_alignment = "center"
title_style.text_color = get_hud_color("color_tint_main_1", 255)
title_style.size = { PANEL_WIDTH - 24, TOP_HEIGHT }
title_style.offset = { 12, 0, 6 }

local action_style = table.clone(UIFontSettings.hud_body)
action_style.font_size = 22
action_style.horizontal_alignment = "left"
action_style.vertical_alignment = "bottom"
action_style.text_horizontal_alignment = "left"
action_style.text_vertical_alignment = "center"
action_style.text_color = get_hud_color("color_tint_main_1", 255)
action_style.size = { PANEL_WIDTH - 24, PANEL_HEIGHT - TOP_HEIGHT }
action_style.offset = { 12, 0, 6 }

-- ---------------------------------------------------------------------------
-- Widget
--
-- Five passes, drawn back to front by the z value in each offset:
--   background  the game's own interaction panel material, so it matches vanilla prompts
--   top_strip   a tinted bar behind the title, to separate it from the action line
--   frame       a dropshadow, which is what stops the panel dissolving into a bright wall
--   title       "PILGRIMAGE"
--   action      "E  Open the pilgrimage terminal", key glyph included
-- ---------------------------------------------------------------------------

local widget_definitions = {
	prompt = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "background",
			value = "content/ui/materials/hud/backgrounds/interaction_background",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = get_hud_color("color_tint_main_4", 230),
				offset = { 0, 0, 0 },
			},
		},
		{
			pass_type = "rect",
			style_id = "top_strip",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "top",
				size = { PANEL_WIDTH, TOP_HEIGHT },
				color = { 180, 121, 136, 109 },
				offset = { 0, 0, 1 },
			},
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/dropshadow_medium",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = { 255, 0, 0, 0 },
				size_addition = { 20, 20 },
				offset = { 0, 0, 3 },
			},
		},
		{
			pass_type = "text",
			style_id = "title",
			value = "",
			value_id = "title",
			style = title_style,
		},
		{
			pass_type = "text",
			style_id = "action",
			value = "",
			value_id = "action",
			style = action_style,
		},
	}, "prompt"),
}

local Definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}

-- ---------------------------------------------------------------------------

local PilgrimageTerminalHud = class("PilgrimageTerminalHud", "HudElementBase")

PilgrimageTerminalHud.init = function(self, parent, draw_layer, start_scale)
	PilgrimageTerminalHud.super.init(self, parent, draw_layer, start_scale, Definitions)

	-- Start hidden. The first update decides whether to show it, and a panel that
	-- flashes on screen for one frame at load is a bug report waiting to happen.
	self._widgets_by_name.prompt.visible = false
end

-- Projects a world position to screen space. Returns nil when the point is not usable
-- this frame, which is the normal case most of the time.
local function _project(parent, world_position)
	local ok_camera, camera = pcall(function()
		return parent and parent.player_camera and parent:player_camera()
	end)
	if not ok_camera or not camera then return nil end

	-- inside_frustum first. It is the cheap rejection, and it is the one that stops the
	-- panel appearing when the terminal is behind the camera.
	local ok_frustum, inside = pcall(Camera.inside_frustum, camera, world_position)
	if not ok_frustum or type(inside) ~= "number" or inside <= 0 then return nil end

	local ok_screen, screen_position, distance = pcall(Camera.world_to_screen, camera, world_position)
	if not ok_screen or not screen_position then return nil end
	if type(distance) ~= "number" or distance <= 0 then return nil end

	local x, y = screen_position.x, screen_position.y
	if type(x) ~= "number" or type(y) ~= "number" then return nil end

	-- NaN and infinity guards. x ~= x is the standard NaN test, and a NaN offset
	-- propagates into the renderer where it is much harder to diagnose than here.
	if x ~= x or y ~= y then return nil end
	if x == math.huge or x == -math.huge then return nil end
	if y == math.huge or y == -math.huge then return nil end

	return x, y
end

PilgrimageTerminalHud.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	PilgrimageTerminalHud.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local widget = self._widgets_by_name.prompt
	local visible = false

	-- The single point of contact with the rest of the mod. nil means "nothing to show",
	-- which covers the mod being disabled, not being in the hub, and standing too far
	-- away, so this file does not need to know about any of those.
	local data = mod.pilgrimage_terminal_prompt and mod.pilgrimage_terminal_prompt() or nil

	if data and data.world_position then
		local x, y = _project(self._parent, data.world_position)

		if x then
			-- inverse_scale converts from real pixels to the UI's own coordinate space,
			-- so the panel lands in the right place regardless of the player's HUD scale
			-- setting or resolution.
			local inverse_scale = ui_renderer and ui_renderer.inverse_scale or 1

			widget.offset[1] = x * inverse_scale - PANEL_WIDTH * 0.5
			widget.offset[2] = y * inverse_scale - PANEL_HEIGHT - VERTICAL_LIFT

			widget.content.title  = data.top_text or ""
			widget.content.action = data.bottom_text or ""
			widget.dirty = true

			visible = true
		end
	end

	-- Only touch visible and dirty when something actually changed. Marking a widget
	-- dirty forces the renderer to rebuild it, and doing that every frame for a panel
	-- that is not even on screen is pure waste.
	if widget.visible ~= visible then
		widget.visible = visible
		widget.dirty = true
	end
end

return PilgrimageTerminalHud
