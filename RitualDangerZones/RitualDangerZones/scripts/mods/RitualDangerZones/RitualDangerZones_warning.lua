-- Prominent, screen-clamped world-marker template for the ritual proximity warning.
-- Mirrors RitualDangerZones_marker.lua (the proven injection path) but larger, colored by stage,
-- and pulsing. Injected into HudElementWorldMarkers._marker_templates by warning.lua.
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

-- Intentionally NOT the Heinous Rituals circumstance icon the locator marker switched to. The two
-- surfaces say different things: the skull reads as an alert, the ritual icon reads as a location.
-- Leave them different.
-- Fallback only. The live icon arrives per marker in data.icon and matches the locator marker's
-- chosen icon, because this banner REPLACES that marker while it is up: a different icon at the
-- handoff reads as the marker glitching into something else rather than one thing escalating.
local WARN_ICON = "content/ui/materials/icons/difficulty/difficulty_skull_uprising"
local DEFAULT_COLOR = { 255, 255, 180, 40 }       -- { alpha, r, g, b } amber
local DEFAULT_TEXT_COLOR = { 255, 255, 255, 255 }
local BASE_FONT_SIZE = 28
local FONT = "proxima_nova_bold"

template.name = "ritual_danger_warning"
template.size = { 128, 128 }
template.unit_node = 1
-- Matches the locator marker's cap. Do NOT lower this back toward the old 30 m trigger radius: since
-- 1.3.0 the warning is driven by main-path distance, so it fires while the player can be a long way
-- from the daemonhost in a straight line (a teammate ahead trips the wire, or the ritual sits off the
-- path). A tight cap here silently hides the warning in precisely the case it exists for.
template.max_distance = 200
template.min_distance = 0
template.position_offset = { 0, 0, 1.6 }
template.check_line_of_sight = false   -- visible through walls
template.screen_clamp = true           -- off-screen edge arrow (directional)
template.screen_margins = { 0.05, 0.05 }

template.create_widget_defintion = function(self, scenegraph_id)
	local size = self.size
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "icon",
			value = WARN_ICON,
			value_id = "icon",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { size[1], size[2] },
				default_size = { size[1], size[2] },
				offset = { 0, 0, 0 },
				color = DEFAULT_COLOR,
			},
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
				font_type = FONT,
				font_size = 28,
				text_color = DEFAULT_TEXT_COLOR,
				default_text_color = DEFAULT_TEXT_COLOR,
				offset = { 0, size[2] * 0.5 + 6, 1 },
				size = { 340, 32 },
			},
		},
	}, scenegraph_id)
end

template.on_enter = function(widget, marker)
	local data = marker.data or {}
	widget.content.icon = data.icon or WARN_ICON
	widget.content.label = data.text or ""
	widget.style.icon.color = data.color or DEFAULT_COLOR
	widget.style.label.text_color = data.text_color or DEFAULT_TEXT_COLOR
	-- Scaled from this template's own base, so the marker stays smaller than the banner.
	widget.style.label.font_size = BASE_FONT_SIZE * (data.text_scale or 1)
end

-- Re-read data each tick (live stage color and text) and pulse the icon for attention.
template.update_function = function(_parent, _ui_renderer, widget, marker, _template_instance, _dt, t)
	local data = marker.data or {}
	-- Icon is re-read here as well as in on_enter, so changing the icon setting mid-mission applies
	-- to a banner that is already on screen instead of only to the next one.
	widget.content.icon = data.icon or WARN_ICON
	widget.content.label = data.text or ""
	widget.style.icon.color = data.color or DEFAULT_COLOR
	widget.style.label.text_color = data.text_color or DEFAULT_TEXT_COLOR
	-- Scaled from this template's own base, so the marker stays smaller than the banner.
	widget.style.label.font_size = BASE_FONT_SIZE * (data.text_scale or 1)
	-- Derive the pulse base from the configured warning size (passed in data.size), so the
	-- "Warning size" setting actually changes the icon. Speedup stage renders 25% larger.
	local base = data.size or 120
	if data.stage == "speedup" then
		base = base * 1.25
	end
	local pulse = 1 + 0.12 * math.sin((t or 0) * 6)
	local s = base * pulse
	widget.style.icon.size = { s, s }
	return false
end

return template
