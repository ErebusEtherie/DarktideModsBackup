-- World-marker template for RitualDangerZones (icon + live text label, anchored to a unit).
-- Injected into HudElementWorldMarkers._marker_templates by marker.lua (there is no public
-- register-template API; the base game's template list is a hard-coded require path).
-- NOTE: `create_widget_defintion` is misspelled in the real engine API and MUST match exactly.
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

-- The game's own Heinous Rituals circumstance icon (path supplied by a Nexus user, 2026-07-23).
-- A bad material path fails silently in this engine (blank or missing-texture box), not with a
-- crash, so if it does not render in game, revert this one string to:
-- "content/ui/materials/icons/difficulty/difficulty_skull_uprising"
local DEFAULT_ICON = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals"
local DEFAULT_ICON_COLOR = { 255, 200, 60, 60 }   -- { alpha, r, g, b }
local DEFAULT_TEXT_COLOR = { 255, 255, 255, 255 } -- { alpha, r, g, b }
local BASE_FONT_SIZE = 20
local DEFAULT_FONT = "proxima_nova_bold"

template.name = "ritual_danger_zone"        -- marker_type string passed to add_world_marker_unit
template.size = { 64, 64 }
template.unit_node = 1
template.max_distance = 200
template.min_distance = 0
template.position_offset = { 0, 0, 1.2 }     -- world-space offset from the unit node (z-up)
template.check_line_of_sight = false          -- false = visible through walls
template.screen_clamp = false

template.create_widget_defintion = function(self, scenegraph_id)
	local size = self.size
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "icon",
			value = DEFAULT_ICON,
			value_id = "icon",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { size[1], size[2] },
				default_size = { size[1], size[2] },
				offset = { 0, 0, 0 },
				color = DEFAULT_ICON_COLOR,
			},
			visibility_function = function(content)
				return content.icon ~= nil
			end,
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			value = "",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "top",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				font_type = DEFAULT_FONT,
				font_size = 20,
				text_color = DEFAULT_TEXT_COLOR,
				default_text_color = DEFAULT_TEXT_COLOR,
				offset = { 0, size[2] * 0.5 + 4, 1 },
				size = { 200, 24 },
			},
		},
	}, scenegraph_id)
end

template.on_enter = function(widget, marker)
	local data = marker.data or {}
	widget.content.icon = data.icon or DEFAULT_ICON
	widget.content.label = data.text or ""
	widget.style.icon.color = data.color or DEFAULT_ICON_COLOR
	-- Scaled from this template's own base, so the marker stays smaller than the banner.
	widget.style.label.font_size = BASE_FONT_SIZE * (data.text_scale or 1)
end

template.update_function = function(_parent, _ui_renderer, widget, marker, _template_instance, _dt, _t)
	local data = marker.data or {}
	widget.content.icon = data.icon or DEFAULT_ICON
	widget.content.label = data.text or ""
	widget.style.icon.color = data.color or DEFAULT_ICON_COLOR
	-- Scaled from this template's own base, so the marker stays smaller than the banner.
	widget.style.label.font_size = BASE_FONT_SIZE * (data.text_scale or 1)
	return false
end

return template
