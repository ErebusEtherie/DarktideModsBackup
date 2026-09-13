-- World-marker template for RespawnRewind (icon + live text label). Injected into
-- HudElementWorldMarkers._marker_templates by markers.lua (no public register API). Reused for both
-- the active-beacon marker, the run-back marker and the practice set; icon/text/color/size come from
-- marker.data and are re-read every frame, so a settings change lands on markers already on screen.
-- NOTE: `create_widget_defintion` is misspelled in the real engine API and MUST match exactly.
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}

local DEFAULT_ICON = "content/ui/materials/icons/difficulty/difficulty_skull_uprising"
local DEFAULT_ICON_COLOR = { 255, 120, 200, 255 }  -- { alpha, r, g, b }
local DEFAULT_TEXT_COLOR = { 255, 255, 255, 255 }
local DEFAULT_FONT = "proxima_nova_bold"

template.name = "respawn_rewind"
template.size = { 64, 64 }
template.unit_node = 1
template.max_distance = 400
template.min_distance = 0
template.position_offset = { 0, 0, 1.2 }
template.check_line_of_sight = false
template.screen_clamp = true
template.screen_margins = { 0.05, 0.05 }

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
				size = { 240, 24 },
			},
		},
	}, scenegraph_id)
end

-- Size arrives through marker.data as well, so the Marker size slider reaches markers that already
-- exist. The widget is built once, at add time, from the template's size, and this template has no
-- scale_settings, so the base HUD never touches its size again. Without this a size change did
-- nothing until the next mission's HUD init, and nothing at all for markers already on screen.
-- The label offset tracks the icon so the text keeps sitting just under it. Only writes when the
-- value actually differs, so the per-frame cost is one comparison.
local function apply_size(widget, size)
	local icon_style = widget.style.icon
	local current = icon_style.size
	if current[1] == size and current[2] == size then
		return
	end
	current[1] = size
	current[2] = size
	local default_size = icon_style.default_size
	if default_size then
		default_size[1] = size
		default_size[2] = size
	end
	local label_offset = widget.style.label.offset
	if label_offset then
		label_offset[2] = size * 0.5 + 4
	end
end

local function apply_data(widget, data)
	widget.content.icon = data.icon or DEFAULT_ICON
	widget.content.label = data.text or ""
	widget.style.icon.color = data.color or DEFAULT_ICON_COLOR
	if type(data.size) == "number" then
		apply_size(widget, data.size)
	end
end

template.on_enter = function(widget, marker)
	apply_data(widget, marker.data or {})
end

template.update_function = function(_parent, _ui_renderer, widget, marker, _template_instance, _dt, _t)
	apply_data(widget, marker.data or {})
	return false
end

return template
