-- overlay_hud.lua
--
-- The pilgrimage panel on the TACTICAL OVERLAY (hold TAB): assignment, live
-- conditions, what comes next. Kaizen's ask: a simple translucent
-- terminal-like window, unobtrusive, to the side, overlapping nothing.
--
-- ===========================================================================
-- WHY IT APPEARS AND DISAPPEARS WITH THE OVERLAY, FOR FREE
-- ===========================================================================
--
-- The game's own overlay element toggles a HUD VISIBILITY GROUP named
-- "tactical_overlay" (hud_visibility_groups.lua:79 checks
-- hud:tactical_overlay_active(), which follows the hold input). Registering
-- this element under that group means the game shows and hides it exactly in
-- step with the vanilla overlay, with no input reading and no state of ours.
--
-- ===========================================================================
-- WHERE IT SITS, AND WHY EXACTLY THERE
-- ===========================================================================
--
-- Measured from hud_element_tactical_overlay_definitions.lua (1920x1080 UI
-- space): the LEFT column (mission info + indulgences) owns x 25..625 at
-- variable depth; the RIGHT column's grid is 450 wide, right-aligned at -15,
-- vertically CENTERED at 550 tall, so its content spans y 265..815 and its
-- header sits above it from roughly y 221. The centre belongs to Kaizen's
-- scoreboard mod. The bottom band is player HUD.
--
-- That leaves the TOP-RIGHT CORNER, y 0..~210 over the contracts column,
-- reliably empty while the overlay is up: above the contracts header, clear
-- of the scoreboard, clear of the base HUD's ability/ammo cluster (bottom
-- right). The panel matches the contracts column's width (450) and right
-- margin (-15) so it reads as part of the same layout rather than a sticker.
--
-- The panel only draws during an ACTIVE pilgrimage run; outside a run the
-- overlay looks exactly vanilla.
--
-- Same construction constraints as terminal_hud.lua: the GAME builds this
-- object, so dependencies cannot be injected. It reaches back through the mod
-- object for exactly one accessor, mod.pilgrimage_overlay_lines (set by
-- bootstrap), called once per frame while the overlay is held, returning nil
-- or { title, lines = { { text, color } } }.

local mod = get_mod("Pilgrimage")

local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIFontSettings      = require("scripts/managers/ui/ui_font_settings")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

require("scripts/ui/hud/elements/hud_element_base")

local PANEL_WIDTH  = 450
local PANEL_RIGHT_MARGIN = -15
-- v0.17.4: PANEL_TOP moved from 10 to 70. Kaizen's overlay screenshot showed
-- the panel hugging the very top of the screen, overlapping the currency /
-- resources indicators (0 grimoires, 0 scriptures) that sit around y=40 in
-- the shipped HUD. 70 clears them and gives visual breathing room. Panel
-- still ends at y = 70 + 30 + 6*22 + 10 = 242, well above the contracts
-- column that starts around y=265.
local PANEL_TOP = 70
local TITLE_HEIGHT = 30
local LINE_HEIGHT = 22
-- v0.17.4: MAX_LINES reduced from 8 to 6. Screen safety math: 8 lines could
-- push the panel bottom to y = 10 + 30 + 8*20 + 8 = 208 which was fine at
-- the old top of 10, but at the new top of 70 the maximum ends at y=242.
-- Also there was never anything sensible to say in 8 lines: assignment +
-- current curse + up to 3 stacked lines + ground truth + "then" + boons =
-- 7 items max, and stacked overflow already collapses into "+N more stacked"
-- past position 3, so 6 is the honest cap.
local MAX_LINES = 6
local PAD_BOTTOM = 10

-- ---------------------------------------------------------------------------
-- Scenegraph: one right-anchored, top-aligned node. The node is sized for the
-- maximum panel; the drawn background rect is resized to the lines actually
-- in use, so a short panel does not carry a tall empty box.
-- ---------------------------------------------------------------------------

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,

	pilgrimage_overlay = {
		parent = "screen",
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = { PANEL_WIDTH, TITLE_HEIGHT + MAX_LINES * LINE_HEIGHT + PAD_BOTTOM },
		position = { PANEL_RIGHT_MARGIN, PANEL_TOP, 55 },
	},
}

-- ---------------------------------------------------------------------------
-- Styles. Cloned from the game's hud_body font settings so the panel inherits
-- the HUD's font and outline instead of looking bolted on (the terminal_hud
-- lesson). Cloned, never referenced: these tables are shared globals.
-- ---------------------------------------------------------------------------

local function _text_style(font_size, y_offset)
	local style = table.clone(UIFontSettings.hud_body)
	style.font_size = font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "top"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "center"
	style.text_color = { 255, 200, 200, 200 }
	style.size = { PANEL_WIDTH - 24, LINE_HEIGHT }
	style.offset = { 14, y_offset, 58 }
	return style
end

local title_style = _text_style(19, 5)
title_style.size = { PANEL_WIDTH - 24, TITLE_HEIGHT }
title_style.text_color = { 255, 255, 226, 168 }

-- ---------------------------------------------------------------------------
-- Widget: translucent near-black background (the game's terminal panels are
-- the same idea), a thin gold accent down the left edge, a title, and a fixed
-- pool of line slots filled per frame. A fixed pool rather than dynamic
-- widgets because the HUD rebuilds widgets when marked dirty, and eight text
-- passes with empty strings cost nothing.
-- ---------------------------------------------------------------------------

local passes = {
	{
		pass_type = "rect",
		style_id = "background",
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { PANEL_WIDTH, TITLE_HEIGHT + MAX_LINES * LINE_HEIGHT + PAD_BOTTOM },
			color = { 160, 8, 10, 8 },
			offset = { 0, 0, 55 },
		},
	},
	{
		pass_type = "rect",
		style_id = "accent",
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { 3, TITLE_HEIGHT + MAX_LINES * LINE_HEIGHT + PAD_BOTTOM },
			color = { 200, 255, 226, 168 },
			offset = { 0, 0, 57 },
		},
	},
	{
		pass_type = "text",
		style_id = "title",
		value = "PILGRIMAGE",
		value_id = "title",
		style = title_style,
	},
}

for i = 1, MAX_LINES do
	passes[#passes + 1] = {
		pass_type = "text",
		style_id = "line_" .. i,
		value = "",
		value_id = "line_" .. i,
		style = _text_style(16, TITLE_HEIGHT + (i - 1) * LINE_HEIGHT),
	}
end

local widget_definitions = {
	pilgrimage_overlay = UIWidget.create_definition(passes, "pilgrimage_overlay"),
}

local Definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}

-- ---------------------------------------------------------------------------

local PilgrimageOverlayHud = class("PilgrimageOverlayHud", "HudElementBase")

PilgrimageOverlayHud.init = function(self, parent, draw_layer, start_scale)
	PilgrimageOverlayHud.super.init(self, parent, draw_layer, start_scale, Definitions)

	-- Start hidden; the first update decides. A panel flashing at load is a
	-- bug report waiting to happen (the terminal_hud lesson).
	self._widgets_by_name.pilgrimage_overlay.visible = false
	self._signature = nil
end

PilgrimageOverlayHud.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	PilgrimageOverlayHud.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local widget = self._widgets_by_name.pilgrimage_overlay

	-- The one point of contact with the rest of the mod. nil covers: no active
	-- run, the setting off, the mod half-loaded. All of it means "vanilla
	-- overlay, draw nothing".
	local ok, data = pcall(function()
		return mod.pilgrimage_overlay_lines and mod.pilgrimage_overlay_lines() or nil
	end)
	if not ok then data = nil end

	local visible = data ~= nil

	if visible then
		local content = widget.content
		local style = widget.style

		content.title = data.title or "PILGRIMAGE"

		-- Signature: rebuild the widget only when something actually changed.
		-- Marking dirty every frame forces a rebuild every frame, for a panel
		-- that mostly shows the same six lines for a whole mission.
		local signature = content.title
		local used = 0

		for i = 1, MAX_LINES do
			local line = data.lines and data.lines[i]
			local id = "line_" .. i
			local text = line and line.text or ""

			content[id] = text
			if line and line.color then
				local colour = style[id].text_color
				colour[1] = line.color[1]
				colour[2] = line.color[2]
				colour[3] = line.color[3]
				colour[4] = line.color[4]
				signature = signature .. "\28" .. tostring(line.color)
			end
			signature = signature .. "\29" .. text

			if text ~= "" then used = i end
		end

		-- Shrink the box to the content. The line slots below stay empty and
		-- invisible; only the rects need resizing.
		local height = TITLE_HEIGHT + used * LINE_HEIGHT + PAD_BOTTOM
		style.background.size[2] = height
		style.accent.size[2] = height
		signature = signature .. "\30" .. tostring(height)

		if signature ~= self._signature then
			self._signature = signature
			widget.dirty = true
		end
	end

	if widget.visible ~= visible then
		widget.visible = visible
		widget.dirty = true
	end
end

return PilgrimageOverlayHud
