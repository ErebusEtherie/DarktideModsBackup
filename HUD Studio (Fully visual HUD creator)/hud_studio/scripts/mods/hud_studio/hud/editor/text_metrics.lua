---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_text_metrics then
	return mod.hud_studio_text_metrics
end

local UIRenderer = require("scripts/managers/ui/ui_renderer")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")

local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")
local Utf8 = rawget(_G, "Utf8")

local FONT = mod.dl.fonts.validated("proxima_nova_medium")
local CONTROL_FONT_SIZE = 14

local function ui_scale(ui_renderer)
	return (ui_renderer and ui_renderer.scale) or (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1
end

local function inverse_scale(ui_renderer, scale)
	return (ui_renderer and ui_renderer.inverse_scale)
		or (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale)
		or (scale ~= 0 and 1 / scale)
		or 1
end

---@class TextMetrics
local TextMetrics = {}

local _advance_ui = nil
local _advance_scale = nil
local _advance_fn = nil

TextMetrics.FONT = FONT
TextMetrics.CONTROL_FONT_SIZE = CONTROL_FONT_SIZE

local MEASURE_SENTINEL = "|"

---@param ui_renderer UIRenderer
---@param text string
---@return number

local MEASURE_CACHE_MAX = 4096
local _measure_cache = {}
local _measure_cache_count = 0
local _measure_cache_scale = nil
local _sentinel_pair_w = nil

local function reset_measure_cache(scale)
	_measure_cache = {}
	_measure_cache_count = 0
	_measure_cache_scale = scale
	_sentinel_pair_w = nil
end

function TextMetrics.measure(ui_renderer, text)
	text = tostring(text)
	if text == "" then
		return 0
	end
	local scale = ui_scale(ui_renderer)
	if scale ~= _measure_cache_scale then
		reset_measure_cache(scale)
	end
	local cached = _measure_cache[text]
	if cached then
		return cached
	end

	local inv = inverse_scale(ui_renderer, scale)
	local size = CONTROL_FONT_SIZE * scale

	local ok1, w_guarded =
		pcall(UIRenderer.text_size, ui_renderer, MEASURE_SENTINEL .. text .. MEASURE_SENTINEL, FONT, size)
	local ok2 = true
	if _sentinel_pair_w == nil then
		local w_pair
		ok2, w_pair = pcall(UIRenderer.text_size, ui_renderer, MEASURE_SENTINEL .. MEASURE_SENTINEL, FONT, size)
		if ok2 and type(w_pair) == "number" then
			_sentinel_pair_w = w_pair
		end
	end

	local width
	if ok1 and ok2 and type(w_guarded) == "number" and _sentinel_pair_w then
		local w = w_guarded - _sentinel_pair_w
		width = (w > 0 and w or 0) * inv
	else

		return #text * CONTROL_FONT_SIZE * 0.5
	end

	if _measure_cache_count >= MEASURE_CACHE_MAX then
		reset_measure_cache(scale)
	end
	_measure_cache[text] = width
	_measure_cache_count = _measure_cache_count + 1
	return width
end

---@param ui_renderer UIRenderer
---@param content_w number
---@return number wrap_w
function TextMetrics.wrap_width(ui_renderer, content_w)
	local scale = ui_scale(ui_renderer)
	if ui_renderer ~= _advance_ui or scale ~= _advance_scale then
		_advance_ui = ui_renderer
		_advance_scale = scale
		_advance_fn = function(ch)
			return TextMetrics.measure(ui_renderer, ch)
		end
	end
	TextField.set_char_metrics(_advance_fn, scale)
	return content_w
end

---@param ui_renderer UIRenderer
---@param s string
---@param col integer
---@return number
function TextMetrics.row_col_x(ui_renderer, s, col)
	if col <= 0 then
		return 0
	end
	local prefix = (Utf8 and Utf8.sub_string and Utf8.sub_string(s, 1, col)) or string.sub(s, 1, col)
	return TextMetrics.measure(ui_renderer, prefix)
end

local function sub(s, i, j)
	return (Utf8 and Utf8.sub_string and Utf8.sub_string(s, i, j)) or string.sub(s, i, j)
end

local function len(s)
	return (Utf8 and Utf8.string_length and Utf8.string_length(s)) or #s
end

---@param ui_renderer UIRenderer
---@param text string
---@param scroll_x number
---@param inner_w number
---@return string sub, number dx, boolean clipped_left, boolean clipped_right
function TextMetrics.visible_window(ui_renderer, text, scroll_x, inner_w)
	text = tostring(text or "")
	local n = len(text)
	if n == 0 then
		return "", 0, false, false
	end

	if scroll_x <= 0 and TextMetrics.measure(ui_renderer, text) <= inner_w then
		return text, 0, false, false
	end
	local right = scroll_x + inner_w

	local start_i = 0
	for i = 0, n do
		if TextMetrics.measure(ui_renderer, sub(text, 1, i)) >= scroll_x then
			start_i = i
			break
		end
		start_i = i
	end

	local end_i = n
	for i = start_i, n do
		if TextMetrics.measure(ui_renderer, sub(text, 1, i)) > right then
			end_i = i - 1
			break
		end
		end_i = i
	end
	if end_i < start_i then
		end_i = start_i
	end
	local dx = TextMetrics.measure(ui_renderer, sub(text, 1, start_i))
	return sub(text, start_i + 1, end_i), dx, start_i > 0, end_i < n
end

---@param ui_renderer UIRenderer
---@param left_x number
---@param caret_index integer
---@return number
function TextMetrics.caret_x(ui_renderer, left_x, caret_index)
	return left_x + TextMetrics.measure(ui_renderer, TextField.prefix(caret_index - 1))
end

---@param ui_renderer UIRenderer
---@param left_x number
---@param target_x number
---@return integer
function TextMetrics.caret_index_at_x(ui_renderer, left_x, target_x)
	local n = TextField.length()
	local best_i, best_d = 0, math.huge
	for i = 0, n do
		local d = math.abs((left_x + TextMetrics.measure(ui_renderer, TextField.prefix(i))) - target_x)
		if d < best_d then
			best_d = d
			best_i = i
		end
	end
	return best_i + 1
end

---@param ui_renderer UIRenderer
---@param ctrl table
---@param content_w number
---@return string[] rows, number wrap_w
function TextMetrics.multiline_rows(ui_renderer, ctrl, content_w)
	local wrap_w = TextMetrics.wrap_width(ui_renderer, content_w)
	local text = TextField.is_focused(ctrl.token) and TextField.text() or tostring(ctrl.get() or "")
	local rows = TextField.wrap_text(text, wrap_w)
	return rows, wrap_w
end

---@param ui_renderer UIRenderer
---@param s string
---@param left_x number
---@param cx number
---@return integer col
function TextMetrics.row_col_at_x(ui_renderer, s, left_x, cx)
	local n = (Utf8 and Utf8.string_length and Utf8.string_length(s)) or #s

	local lo, hi = 0, n
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if left_x + TextMetrics.row_col_x(ui_renderer, s, mid) <= cx then
			lo = mid
		else
			hi = mid - 1
		end
	end
	if lo >= n then
		return n
	end
	local x_lo = left_x + TextMetrics.row_col_x(ui_renderer, s, lo)
	local x_hi = left_x + TextMetrics.row_col_x(ui_renderer, s, lo + 1)
	return (math.abs(cx - x_hi) < math.abs(cx - x_lo)) and (lo + 1) or lo
end

---@param ui_renderer UIRenderer
---@param left_x number
---@param top number
---@param line_h number
---@param cx number
---@param cy number
---@return integer row, integer col
function TextMetrics.multiline_rc_at(ui_renderer, left_x, top, line_h, cx, cy)
	local row = math.floor((cy - top) / line_h) + 1
	if row < 1 then
		row = 1
	end
	local rows = TextField.visual_rows()
	if #rows == 0 then
		return 1, 0
	end
	if row > #rows then
		row = #rows
	end
	return row, TextMetrics.row_col_at_x(ui_renderer, rows[row], left_x, cx)
end

mod.hud_studio_text_metrics = TextMetrics

return TextMetrics
