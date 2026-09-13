

local mod = get_mod("hud_studio")

if mod.color_picker then
	return mod.color_picker
end

---@class ColorPicker
local ColorPicker = {}

local floor = math.floor

local function clamp01(v)
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end

ColorPicker.PAD = 8
ColorPicker.SLIDER_W = 16
ColorPicker.GAP = 8

ColorPicker.SAVED_COLS = 4
ColorPicker.SWATCH = 18
ColorPicker.SWATCH_GAP = 3
ColorPicker.BUTTON_H = 18

---@return number
function ColorPicker.saved_w()
	local cols, sz, g = ColorPicker.SAVED_COLS, ColorPicker.SWATCH, ColorPicker.SWATCH_GAP
	return cols * sz + (cols - 1) * g
end

---@return { sl: table, hue: table, alpha: table, saved: table, button: table }
function ColorPicker.layout(x, y, w, h)
	local p, sw, gap = ColorPicker.PAD, ColorPicker.SLIDER_W, ColorPicker.GAP
	local inner_h = h - p * 2
	local saved_w = ColorPicker.saved_w()
	local sl_w = w - p * 2 - sw * 2 - gap * 3 - saved_w
	local sl = { x = x + p, y = y + p, w = sl_w, h = inner_h }
	local hue = { x = sl.x + sl.w + gap, y = y + p, w = sw, h = inner_h }
	local alpha = { x = hue.x + hue.w + gap, y = y + p, w = sw, h = inner_h }
	local button_h = ColorPicker.BUTTON_H
	local saved = { x = alpha.x + alpha.w + gap, y = y + p, w = saved_w, h = inner_h - button_h - gap }
	local button = { x = saved.x, y = saved.y + saved.h + gap, w = saved_w, h = button_h }
	return { sl = sl, hue = hue, alpha = alpha, saved = saved, button = button }
end

---@return integer
function ColorPicker.saved_capacity(saved)
	local sz, g = ColorPicker.SWATCH, ColorPicker.SWATCH_GAP
	local rows = floor((saved.h + g) / (sz + g))
	if rows < 0 then
		rows = 0
	end
	return rows * ColorPicker.SAVED_COLS
end

---@return table { x, y, w, h }
function ColorPicker.saved_slot(saved, index)
	local sz, g, cols = ColorPicker.SWATCH, ColorPicker.SWATCH_GAP, ColorPicker.SAVED_COLS
	local col = (index - 1) % cols
	local row = floor((index - 1) / cols)
	return { x = saved.x + col * (sz + g), y = saved.y + row * (sz + g), w = sz, h = sz }
end

---@return integer|nil
function ColorPicker.saved_hit(saved, cx, cy, count)
	for i = 1, math.min(count, ColorPicker.saved_capacity(saved)) do
		local r = ColorPicker.saved_slot(saved, i)
		if cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + r.h then
			return i
		end
	end
	return nil
end

---@return number s, number l
function ColorPicker.pos_to_sl(sl, cx, cy)
	local s = sl.w > 0 and (cx - sl.x) / sl.w or 0
	local l = sl.h > 0 and 1 - (cy - sl.y) / sl.h or 0
	return clamp01(s), clamp01(l)
end

---@return number x, number y
function ColorPicker.sl_to_pos(sl, s, l)
	return sl.x + clamp01(s) * sl.w, sl.y + (1 - clamp01(l)) * sl.h
end

---@return number h
function ColorPicker.pos_to_hue(hue, cy)
	local h = hue.h > 0 and (cy - hue.y) / hue.h or 0
	return clamp01(h)
end

---@return number x, number y
function ColorPicker.hue_to_pos(hue, h)
	return hue.x + hue.w * 0.5, hue.y + clamp01(h) * hue.h
end

---@return number a
function ColorPicker.pos_to_alpha(alpha, cy)
	local a = alpha.h > 0 and 1 - (cy - alpha.y) / alpha.h or 0
	return clamp01(a)
end

---@return number x, number y
function ColorPicker.alpha_to_pos(alpha, a)
	return alpha.x + alpha.w * 0.5, alpha.y + (1 - clamp01(a)) * alpha.h
end

local function bands(start, length, n)
	local edges = {}
	for i = 0, n do
		edges[i] = floor(start + length * i / n + 0.5)
	end
	return edges
end

---@param lay table            result of ColorPicker.layout
---@param h number
---@param s number
---@param l number
---@param a number
---@param opts table|nil
---@return { sl: table[], hue: table[], alpha: table[], knobs: table }
function ColorPicker.build_cells(lay, h, s, l, a, opts)
	opts = opts or {}
	local n = opts.sl or 12
	local m = opts.slider or 24
	local sl, hue, alpha = lay.sl, lay.hue, lay.alpha

	local sl_cells = {}
	local xs = bands(sl.x, sl.w, n)
	local ys = bands(sl.y, sl.h, n)
	for j = 0, n - 1 do
		local l_v = n > 1 and 1 - j / (n - 1) or 1
		for i = 0, n - 1 do
			local s_v = n > 1 and i / (n - 1) or 0
			sl_cells[#sl_cells + 1] = {
				x = xs[i],
				y = ys[j],
				w = xs[i + 1] - xs[i],
				h = ys[j + 1] - ys[j],
				color = mod.dl.colors.hsla_to_argb(h, s_v, l_v, 1),
			}
		end
	end

	local hue_cells = {}
	local alpha_cells = {}
	local hys = bands(hue.y, hue.h, m)
	for k = 0, m - 1 do
		local t = (k + 0.5) / m
		hue_cells[#hue_cells + 1] = {
			x = hue.x,
			y = hys[k],
			w = hue.w,
			h = hys[k + 1] - hys[k],
			color = mod.dl.colors.hsla_to_argb(t, 1, 0.5, 1),
		}

		alpha_cells[#alpha_cells + 1] = {
			x = alpha.x,
			y = hys[k],
			w = alpha.w,
			h = hys[k + 1] - hys[k],
			color = mod.dl.colors.hsla_to_argb(h, s, l, 1 - t),
		}
	end

	local slkx, slky = ColorPicker.sl_to_pos(sl, s, l)
	local hkx, hky = ColorPicker.hue_to_pos(hue, h)
	local akx, aky = ColorPicker.alpha_to_pos(alpha, a)

	return {
		sl = sl_cells,
		hue = hue_cells,
		alpha = alpha_cells,
		knobs = {
			sl = { x = slkx, y = slky },
			hue = { x = hkx, y = hky },
			alpha = { x = akx, y = aky },
		},
	}
end

mod.color_picker = ColorPicker

return ColorPicker
