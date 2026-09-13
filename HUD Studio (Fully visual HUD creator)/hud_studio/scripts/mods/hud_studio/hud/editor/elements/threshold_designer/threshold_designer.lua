---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_threshold_designer then
	return mod.hud_studio_threshold_designer
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local PANEL = C.PANEL

---@class ThresholdDesigner
local ThresholdDesigner = {}

local TITLE_H = 26
local PAD = 8

local BAR_H = 40 
local ROW_H = 24
local ROW_GAP = 8
local PCT_W = 60 
local PCT_SUFFIX_W = 18 
local ROW_GAP_X = 12 
local COL_GAP = 12

ThresholdDesigner.TITLE_H = TITLE_H
ThresholdDesigner.PAD = PAD
ThresholdDesigner.PCT_SUFFIX_W = PCT_SUFFIX_W

ThresholdDesigner.HINT_H = 16

ThresholdDesigner.MAX_ROWS = 16

---@return table left  { x, w }
---@return table right { x, w }
function ThresholdDesigner.columns(x, w)
	local content_x = x + PAD
	local content_w = w - PAD * 2
	local col_w = math.floor((content_w - COL_GAP) / 2)
	return { x = content_x, w = col_w }, { x = content_x + col_w + COL_GAP, w = content_w - col_w - COL_GAP }
end

---@return table column { x, w }
function ThresholdDesigner.full_column(x, w)
	return { x = x + PAD, w = w - PAD * 2 }
end

---@return number
function ThresholdDesigner.ratio_y(y)
	return y + TITLE_H + PAD + BAR_H + PAD
end

---@param x number
---@param y number
---@param w number
---@param row_count integer
---@param ratio_h number
---@param hint_h number
---@param scale_h number
---@return table layout
function ThresholdDesigner.layout(x, y, w, row_count, ratio_h, hint_h, scale_h)
	local content_x = x + PAD
	local content_w = w - PAD * 2
	local cy = y + TITLE_H + PAD

	local bar = { x = content_x, y = cy, w = content_w, h = BAR_H }
	cy = cy + BAR_H + PAD

	local ratio = { x = content_x, y = cy, w = content_w, h = ratio_h }
	cy = cy + ratio_h

	local hint = nil
	if hint_h > 0 then
		hint = { x = content_x, y = cy, w = content_w, h = hint_h }
		cy = cy + hint_h + PAD
	end

	local scale = nil
	if scale_h > 0 then
		scale = {
			label = { x = content_x, y = cy, w = content_w, h = PANEL.FIELD_LABEL_H },
			ctrl = { x = content_x, y = cy + PANEL.FIELD_LABEL_H, w = content_w, h = scale_h },
		}
		cy = cy + PANEL.FIELD_LABEL_H + scale_h + PAD
	end

	local value_x = content_x + PCT_W + PCT_SUFFIX_W + ROW_GAP_X
	local value_w = content_x + content_w - value_x

	local rows = {}
	for i = 1, row_count do
		rows[i] = {
			pct = { x = content_x, y = cy, w = PCT_W, h = ROW_H },
			suffix_x = content_x + PCT_W,
			value = { x = value_x, y = cy, w = value_w, h = ROW_H },
		}
		cy = cy + ROW_H + ROW_GAP
	end
	cy = cy - ROW_GAP + PAD

	return {
		frame = { x = x, y = y, w = w, h = cy - y },
		title = { x = x, y = y, w = w, h = TITLE_H },
		bar = bar,
		ratio = ratio,
		hint = hint,
		scale = scale,
		rows = rows,
	}
end

---@param rect table    the control rect { x, y, w, h }
---@param items table[] { { value, text }, ... }
---@return table parts  { items = { { value, box }, ... }, height, label_rect }
function ThresholdDesigner.scale_parts(rect, items)
	local out = {}
	local n = #items
	local col_w = math.floor(rect.w / n)
	for i = 1, n do
		out[i] = {
			value = items[i].value,

			box = {
				x = rect.x + col_w * (i - 1),
				y = rect.y,
				w = (i == n) and (rect.w - col_w * (n - 1)) or col_w,
				h = rect.h,
			},
		}
	end
	return { items = out, height = rect.h, label_rect = { x = rect.x, y = rect.y, w = 0, h = rect.h } }
end

---@param group table|nil          from NodeForm.threshold_input_group
---@param items table|nil          appended to; nil measures only
---@param labels table|nil         appended to; the group / control label lines
---@return number height
function ThresholdDesigner.stack_group(group, x, y, w, items, labels)
	if not group then
		return 0
	end
	local top = y

	if labels then
		labels[#labels + 1] = { x = x, y = y, w = w, h = PANEL.FIELD_LABEL_H, text = group.label, group = true }
	end
	y = y + PANEL.FIELD_LABEL_H

	local stack = { group.mode }
	for i = 1, #group.controls do
		local c = group.controls[i]
		if not (c.hidden and c.hidden()) then
			stack[#stack + 1] = c
		end
	end

	for i = 1, #stack do
		local ctrl = stack[i]
		local has_label = ctrl.label ~= nil and ctrl.label ~= ""
		if has_label then
			if labels then
				labels[#labels + 1] = { x = x, y = y, w = w, h = PANEL.FIELD_LABEL_H, text = ctrl.label }
			end
			y = y + PANEL.FIELD_LABEL_H
		end
		if items then
			items[#items + 1] = {
				t = "field",
				ctrl = ctrl,
				ctrl_rect = { x = x, y = y, w = w, h = PANEL.FIELD_H },

				label_rect = { x = x, y = y, w = w, h = 0 },
			}
		end
		y = y + PANEL.FIELD_H + PANEL.FIELD_GAP
	end

	return y - top
end

mod.hud_studio_threshold_designer = ThresholdDesigner

return ThresholdDesigner
