---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Registry = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local Pixel = mod:core(mod.hud_studio_pixel, "blocks/pixel")
local Color = mod:core(mod.hud_studio_color, "blocks/color")

local UIRenderer = require("scripts/managers/ui/ui_renderer")
local Vector3 = Vector3
local Vector2 = Vector2

local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")

local DEFAULT_FONT = "proxima_nova_bold"
local DEFAULT_FONT_SIZE = 22
local DEFAULT_COLOR = { 255, 255, 255, 255 }

local BOX = { 1000, 100 }

local DEFAULT_ALIGN = "left"

local Gui = rawget(_G, "Gui")
local GUI_H_ALIGN = {
	left = Gui and Gui.HorizontalAlignLeft,
	center = Gui and Gui.HorizontalAlignCenter,
	right = Gui and Gui.HorizontalAlignRight,
}

local DRAW_OPTIONS = {
	vertical_alignment = Gui and Gui.VerticalAlignTop,
}

---@type NodeType
local Text = {
	id = "text",
	label = "Text",
	bindable = { "visible", "offset", "text", "color", "font_size", "size", "shadow", "align" },

	value_editor = { kind = "text", modes = { "fixed", "localized" } },

	style_knobs = { "visible", "offset", "size", "color", "font_type", "font_size", "shadow", "align" },
	callbacks = {

		value = {
			fields = { "visible", "offset", "size", "text", "color", "font_size", "shadow", "align" },
			scope = { "sources", "state", "block", "t", "dt" },
		},
		style = { scope = { "sources", "value", "state", "block", "t", "dt" } },
	},
}

local MAX_SEGMENTS = 10

local SEGMENTS = {}
for i = 1, MAX_SEGMENTS do
	local suffix = (i == 1) and "" or tostring(i)
	SEGMENTS[i] = {
		value = "text" .. suffix,
		loc = "loc_id" .. suffix,
		mode = "mode" .. suffix,
		decimals = "decimals" .. suffix,
	}
end

local DECIMAL_FMT = {}
for decimal_places = 0, 5 do
	DECIMAL_FMT[decimal_places] = "%." .. decimal_places .. "f"
end

local _segment_buffer = {}

local _localized_by_block = {}

---@param block_name string?
---@param key string           bare authoring key, pre-namespacing
---@return string
local function localize_segment(block_name, key)
	local block_key = block_name or ""
	local by_key = _localized_by_block[block_key]
	if by_key == nil then
		by_key = {}
		_localized_by_block[block_key] = by_key
	end
	local resolved = by_key[key]
	if resolved == nil then

		local namespaced = key
		if block_key ~= "" then
			local UserLoc = mod.hud_studio_user_loc
			namespaced = (UserLoc and UserLoc.key(block_key, key)) or (block_key .. "." .. key)
		end
		resolved = mod:localize(namespaced)
		by_key[key] = resolved
	end
	return resolved
end

---@param segment table         one SEGMENTS entry (precomputed slot names)
---@param values table
---@param block_name string?
---@param style table?          the node's static style, holding the per-segment decimals knobs
---@return string?
local function resolve_segment(segment, values, block_name, style)
	local raw
	if values[segment.mode] == "localized" then
		local key = values[segment.loc]
		if key ~= nil and key ~= "" then
			raw = localize_segment(block_name, key)
		end
	else
		raw = values[segment.value]
	end
	if raw == nil then
		return nil
	end
	if type(raw) == "number" then

		local decimals = math.clamp(math.floor(tonumber(style and style[segment.decimals]) or 0), 0, 5)
		return string.format(DECIMAL_FMT[decimals], raw)
	end
	return tostring(raw)
end

---@param ui_renderer table
---@param x number
---@param y number
---@param z number
---@param scale number
---@param values table
---@param style table?
---@param block_name string?  owning block's name, used to namespace a localized key
function Text.draw(ui_renderer, x, y, z, scale, values, style, block_name)
	local color = Color.rgba(values.color) or (style and style.color) or DEFAULT_COLOR
	if color[1] <= 0 then
		return
	end

	local text
	if values.value_mode == "chain" then
		local count = 0
		for i = 1, MAX_SEGMENTS do
			local part = resolve_segment(SEGMENTS[i], values, block_name, style)
			if part ~= nil and part ~= "" then
				count = count + 1
				_segment_buffer[count] = part
			end
		end
		if count == 0 then
			return
		end
		text = (count == 1) and _segment_buffer[1] or table.concat(_segment_buffer, "", 1, count)
	else
		text = resolve_segment(SEGMENTS[1], values, block_name, style)
		if text == nil then
			return
		end
	end

	local font = (style and style.font_type) or DEFAULT_FONT

	local render_scale = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1
	local font_size = (tonumber(values.font_size) or (style and style.font_size) or DEFAULT_FONT_SIZE)
		* scale
		* render_scale

	local size = values.size or (style and style.size)
	local box_w = (size and size[1]) or BOX[1]
	local box_h = (size and size[2]) or BOX[2]

	local shadow_on = values.shadow
	if shadow_on == nil then
		shadow_on = style and style.shadow
	end
	DRAW_OPTIONS.shadow = shadow_on and true or nil

	local align = values.align or (style and style.align) or DEFAULT_ALIGN
	if align ~= "center" and align ~= "right" then
		align = "left"
	end
	DRAW_OPTIONS.horizontal_alignment = GUI_H_ALIGN[align]

	local draw_x = x
	if not size then
		if align == "center" then
			draw_x = x - box_w * scale * 0.5
		elseif align == "right" then
			draw_x = x - box_w * scale
		end
	end

	UIRenderer.draw_text(
		ui_renderer,
		tostring(text),
		font_size,
		font,
		Vector3(Pixel.snap(draw_x), Pixel.snap(y), z),
		Vector2(box_w * scale, box_h * scale),
		color,
		DRAW_OPTIONS
	)
end

Registry.register(Text)

return Text
