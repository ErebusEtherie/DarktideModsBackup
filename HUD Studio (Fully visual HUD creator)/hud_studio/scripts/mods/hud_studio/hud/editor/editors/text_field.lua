---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_text_field then
	return mod.hud_studio_text_field
end

local Keyboard = rawget(_G, "Keyboard")
local Utf8 = rawget(_G, "Utf8")
local Clipboard = rawget(_G, "Clipboard")

local TAB_WIDTH = 4
local INDENT = string.rep(" ", TAB_WIDTH)

local function str_len(s)
	if Utf8 and Utf8.string_length then
		return Utf8.string_length(s)
	end
	return #s
end

local function str_insert(s, caret, chunk)
	if Utf8 and Utf8.string_insert then
		return Utf8.string_insert(s, caret, chunk)
	end
	return string.sub(s, 1, caret - 1) .. chunk .. string.sub(s, caret)
end

local function str_sub(s, i, j)
	if Utf8 and Utf8.sub_string then
		return Utf8.sub_string(s, i, j)
	end
	return string.sub(s, i, j)
end

local function str_delete(s, at, count)
	if Utf8 and Utf8.string_remove then
		return Utf8.string_remove(s, at, count)
	end
	return string.sub(s, 1, at - 1) .. string.sub(s, at + count)
end

local advance_of = nil
local advance_key = nil

---@param text string
---@param wrap_w number|nil
---@return { start: integer, len: integer, hard: boolean }[]
local function build_rows_uncached(text, wrap_w)
	local rows = {}
	local n = str_len(text)
	local row_start = 1
	local row_w = 0
	local i = 1
	local wrapping = wrap_w ~= nil and advance_of ~= nil
	while i <= n do
		local ch = str_sub(text, i, i)
		if ch == "\n" then
			rows[#rows + 1] = { start = row_start, len = i - row_start, hard = true }
			i = i + 1
			row_start = i
			row_w = 0
		else

			local w = wrapping and advance_of(ch) or 0
			if wrapping and i > row_start and row_w + w > wrap_w then
				rows[#rows + 1] = { start = row_start, len = i - row_start, hard = false }
				row_start = i
				row_w = 0
			end
			row_w = row_w + w
			i = i + 1
		end
	end

	rows[#rows + 1] = { start = row_start, len = n - row_start + 1, hard = true }
	return rows
end

local ROWS_CACHE_MAX = 16
local _rows_cache = {}
local _rows_cache_count = 0
local _wrapped_cache = {}
local _wrapped_cache_count = 0

local function cache_get(cache, text, wrap_w)
	local by_text = cache[wrap_w or 0]
	return by_text and by_text[text]
end

local function cache_clear(cache)
	for key in pairs(cache) do
		cache[key] = nil
	end
end

local function cache_put(cache, count, text, wrap_w, value)
	if count >= ROWS_CACHE_MAX then
		cache_clear(cache)
		count = 0
	end
	local key = wrap_w or 0
	local by_text = cache[key]
	if not by_text then
		by_text = {}
		cache[key] = by_text
	end
	by_text[text] = value
	return count + 1
end

local function set_char_metrics(advance, key)
	advance_of = advance
	if key ~= advance_key then
		advance_key = key
		cache_clear(_rows_cache)
		cache_clear(_wrapped_cache)
		_rows_cache_count = 0
		_wrapped_cache_count = 0
	end
end

local function build_rows(text, wrap_w)
	local cached = cache_get(_rows_cache, text, wrap_w)
	if cached then
		return cached
	end
	local rows = build_rows_uncached(text, wrap_w)
	_rows_cache_count = cache_put(_rows_cache, _rows_cache_count, text, wrap_w, rows)
	return rows
end

local function wrap_text(text, wrap_w)
	text = tostring(text or "")
	local cached = cache_get(_wrapped_cache, text, wrap_w)
	if cached then
		return cached
	end
	local rows = build_rows(text, wrap_w)
	local out = {}
	for r = 1, #rows do
		local row = rows[r]
		out[r] = (row.len > 0) and str_sub(text, row.start, row.start + row.len - 1) or ""
	end
	_wrapped_cache_count = cache_put(_wrapped_cache, _wrapped_cache_count, text, wrap_w, out)
	return out
end

local _indices_ready
local _idx = {}
local function ensure_indices()
	if _indices_ready then
		return
	end
	_indices_ready = true
	if Keyboard and Keyboard.button_index then
		for _, name in ipairs({
			"enter",
			"numpad enter",
			"escape",
			"left shift",
			"right shift",
			"left ctrl",
			"right ctrl",
			"a",
			"c",
			"v",
			"x",
			"y",
			"z",
		}) do
			_idx[name] = Keyboard.button_index(name)
		end
	end
end

local function held(name)
	local i = _idx[name]
	return i ~= nil and Keyboard.button and Keyboard.button(i) > 0.5
end

local function pressed_idx(name)
	local i = _idx[name]
	return i ~= nil and Keyboard.pressed and Keyboard.pressed(i)
end

local function shift_down()
	return held("left shift") or held("right shift")
end

local function ctrl_down()
	return held("left ctrl") or held("right ctrl")
end

---@class TextFieldContext : EditorDoc
---@field token string
---@field text string
---@field caret integer                       1-based; 1 = before first char, len+1 = end
---@field anchor integer                       selection anchor; == caret means no selection
---@field on_commit fun(text: string)|nil
---@field multiline boolean                    Enter inserts \n (commit is Ctrl+Enter / click-away)
---@field wrap_w number|nil                    soft-wrap width in design px; nil = no wrap
---@field desired_col integer|nil              sticky column for successive Up/Down (see move_vertical)
---@field scroll_x number                       single-line horizontal scroll offset in design px (see scroll_x)

---@class TextField
local TextField = {}

---@param text string
---@param wrap_w number|nil  soft-wrap width in design px (nil -> no soft wrap)
---@return string[]
function TextField.wrap_text(text, wrap_w)
	return wrap_text(text, wrap_w)
end

---@param advance fun(ch: string): number
---@param key any
TextField.set_char_metrics = set_char_metrics

---@type TextFieldContext|nil
local ctx = nil

---@param token string
---@param initial string|nil
---@param on_commit fun(text: string)|nil
---@param opts { multiline: boolean?, wrap_w: number? }|nil
function TextField.focus(token, initial, on_commit, opts)
	local multiline = opts ~= nil and opts.multiline == true
	local text = initial ~= nil and tostring(initial) or ""
	if not multiline then

		text = text:gsub("[\r\n]", " ")
	end
	local n = str_len(text)
	ctx = {
		token = token,
		text = text,
		caret = n + 1,
		anchor = n + 1,
		on_commit = on_commit,
		multiline = multiline,
		wrap_w = opts and opts.wrap_w or nil,
		desired_col = nil,
		scroll_x = 0,
		undo_stack = {},
		redo_stack = {},
		undo_kind = nil,
	}
end

---@return number
function TextField.scroll_x()
	return ctx and ctx.scroll_x or 0
end

---@param x number
function TextField.set_scroll_x(x)
	if ctx then
		ctx.scroll_x = x
	end
end

---@param wrap_w number|nil
function TextField.set_wrap(wrap_w)
	if ctx then
		ctx.wrap_w = (wrap_w and wrap_w > 0) and wrap_w or nil
	end
end

---@return boolean
function TextField.is_multiline()
	return ctx ~= nil and ctx.multiline == true
end

---@return boolean
function TextField.any_focused()
	return ctx ~= nil
end

---@param token string
---@return boolean
function TextField.is_focused(token)
	return ctx ~= nil and ctx.token == token
end

---@return string|nil
function TextField.token()
	return ctx and ctx.token
end

---@return string
function TextField.text()
	return ctx and ctx.text or ""
end

---@return integer
function TextField.caret()
	return ctx and ctx.caret or 1
end

---@return integer
function TextField.length()
	return ctx and str_len(ctx.text) or 0
end

---@param n integer
---@return string
function TextField.prefix(n)
	if not ctx then
		return ""
	end
	if n <= 0 then
		return ""
	end
	return str_sub(ctx.text, 1, n)
end

---@return string
function TextField.text_before_caret()
	if not ctx then
		return ""
	end
	return str_sub(ctx.text, 1, ctx.caret - 1)
end

---@return boolean
function TextField.shift_down()
	ensure_indices()
	return shift_down()
end

---@return boolean
function TextField.has_selection()
	return ctx ~= nil and ctx.anchor ~= ctx.caret
end

---@return integer|nil lo, integer|nil hi
function TextField.selection_range()
	if not ctx or ctx.anchor == ctx.caret then
		return nil, nil
	end
	if ctx.anchor < ctx.caret then
		return ctx.anchor, ctx.caret
	end
	return ctx.caret, ctx.anchor
end

---@return string
function TextField.selected_text()
	local lo, hi = TextField.selection_range()
	if not lo then
		return ""
	end
	return str_sub(ctx.text, lo, hi - 1)
end

local function clamp_caret(pos)
	local n = str_len(ctx.text)
	if pos < 1 then
		return 1
	elseif pos > n + 1 then
		return n + 1
	end
	return pos
end

---@param index integer
---@param extend boolean|nil
function TextField.set_caret(index, extend)
	if not ctx then
		return
	end
	ctx.caret = clamp_caret(index)
	if not extend then
		ctx.anchor = ctx.caret
	end

	ctx.desired_col = nil

	ctx.undo_kind = nil
end

---@param anchor integer
---@param caret integer
function TextField.set_selection(anchor, caret)
	if not ctx then
		return
	end
	TextField.set_caret(anchor, false)
	TextField.set_caret(caret, true)
end

function TextField.select_all()
	if not ctx then
		return
	end
	ctx.anchor = 1
	ctx.caret = str_len(ctx.text) + 1
	ctx.desired_col = nil
end

local function ctx_rows()
	return build_rows(ctx.text, ctx.multiline and ctx.wrap_w or nil)
end

local function rc_to_index(rows, r, col)
	if r < 1 then
		r = 1
	elseif r > #rows then
		r = #rows
	end
	local row = rows[r]
	if col < 0 then
		col = 0
	elseif col > row.len then
		col = row.len
	end
	return row.start + col
end

---@return integer row, integer col
function TextField.caret_rc()
	if not ctx then
		return 1, 0
	end
	local rows = ctx_rows()
	local c = ctx.caret
	for r = 1, #rows do
		local row = rows[r]
		local e = row.start + row.len
		if row.hard then
			if c >= row.start and c <= e then
				return r, c - row.start
			end
		else
			if c >= row.start and c < e then
				return r, c - row.start
			end
		end
	end
	local last = rows[#rows]
	return #rows, last.len
end

---@return string[]
function TextField.visual_rows()
	if not ctx then
		return {}
	end
	return wrap_text(ctx.text, ctx.multiline and ctx.wrap_w or nil)
end

---@return integer
function TextField.row_count()
	if not ctx then
		return 0
	end
	return #ctx_rows()
end

---@param r integer
---@return integer|nil lo, integer|nil hi
function TextField.selection_on_row(r)
	if not ctx then
		return nil, nil
	end
	local lo, hi = TextField.selection_range()
	if not lo then
		return nil, nil
	end
	local rows = ctx_rows()
	local row = rows[r]
	if not row then
		return nil, nil
	end
	local rhi = row.start + row.len 
	local slo = (lo > row.start) and lo or row.start
	local shi = (hi < rhi) and hi or rhi
	if shi <= slo then
		return nil, nil
	end
	return slo - row.start, shi - row.start
end

---@param r integer
---@param col integer
---@param extend boolean|nil
function TextField.set_caret_rc(r, col, extend)
	if not ctx then
		return
	end
	TextField.set_caret(rc_to_index(ctx_rows(), r, col), extend)
end

---@param r integer
---@param col integer
---@return integer
function TextField.index_at_rc(r, col)
	if not ctx then
		return 1
	end
	return rc_to_index(ctx_rows(), r, col)
end

local function move_vertical(dir, extend)
	if not ctx then
		return
	end
	local rows = ctx_rows()
	local r, col = TextField.caret_rc()
	if ctx.desired_col == nil then
		ctx.desired_col = col
	end
	local tr = r + dir
	if tr < 1 then
		tr = 1
	elseif tr > #rows then
		tr = #rows
	end
	ctx.caret = clamp_caret(rc_to_index(rows, tr, ctx.desired_col))
	if not extend then
		ctx.anchor = ctx.caret
	end
end

local TEXT_UNDO_CAP = 100

local function snapshot(kind)
	if not ctx then
		return
	end
	local undo = ctx.undo_stack
	if kind and kind == ctx.undo_kind and #undo > 0 then
		return
	end
	ctx.undo_kind = kind
	undo[#undo + 1] = { text = ctx.text, caret = ctx.caret }
	if #undo > TEXT_UNDO_CAP then
		table.remove(undo, 1)
	end
	ctx.redo_stack = {}
end

local function restore(from, to)
	local snap = from[#from]
	if not snap then
		return false
	end
	from[#from] = nil
	to[#to + 1] = { text = ctx.text, caret = ctx.caret }
	ctx.text = snap.text
	ctx.caret = snap.caret
	ctx.anchor = snap.caret
	ctx.desired_col = nil
	ctx.undo_kind = nil
	return true
end

---@return boolean applied
function TextField.undo()
	return ctx ~= nil and restore(ctx.undo_stack, ctx.redo_stack)
end

---@return boolean applied
function TextField.redo()
	return ctx ~= nil and restore(ctx.redo_stack, ctx.undo_stack)
end

local function delete_selection(no_snap)
	local lo, hi = TextField.selection_range()
	if not lo then
		return false
	end
	if not no_snap then
		snapshot(nil)
	end
	ctx.text = str_delete(ctx.text, lo, hi - lo)
	ctx.caret = lo
	ctx.anchor = lo
	ctx.desired_col = nil
	return true
end

local function insert_chunk(chunk)
	if chunk == nil or chunk == "" then
		return
	end

	snapshot(str_len(chunk) == 1 and chunk ~= "\n" and "type" or nil)
	delete_selection(true)
	ctx.text = str_insert(ctx.text, ctx.caret, chunk)
	ctx.caret = ctx.caret + str_len(chunk)
	ctx.anchor = ctx.caret
	ctx.desired_col = nil
end

local WRAP_PAIRS = { ["{"] = "}", ["("] = ")" }

local function wrap_selection(open, close)
	local lo, hi = TextField.selection_range()
	if not lo then
		return false
	end
	snapshot(nil)
	local inner = str_sub(ctx.text, lo, hi - 1)
	ctx.text = str_insert(str_delete(ctx.text, lo, hi - lo), lo, open .. inner .. close)
	ctx.anchor = lo + 1
	ctx.caret = ctx.anchor + str_len(inner)
	ctx.desired_col = nil
	return true
end

local function sanitize(s, multiline)
	if multiline then
		s = s:gsub("\r\n", "\n"):gsub("\r", "\n")

		return (s:gsub("[%z\1-\9\11-\31\127]", ""))
	end
	return (s:gsub("[%z\1-\31\127]", ""))
end

function TextField.commit()
	if not ctx then
		return
	end
	local cb, text = ctx.on_commit, ctx.text
	ctx = nil
	if cb then
		cb(text)
	end
end

function TextField.cancel()
	ctx = nil
end

---@param token string
function TextField.commit_if(token)
	if ctx and ctx.token == token then
		TextField.commit()
	end
end

local function is_space_at(k)
	return str_sub(ctx.text, k, k):match("%s") ~= nil
end

local function spaces_before(caret)
	local count = 0
	local i = caret - 1
	while i >= 1 and count < TAB_WIDTH and str_sub(ctx.text, i, i) == " " do
		count = count + 1
		i = i - 1
	end
	return count
end

local function prev_word(caret)
	local i = caret
	if i <= 1 then
		return 1
	end
	local space = is_space_at(i - 1)
	while i > 1 and is_space_at(i - 1) == space do
		i = i - 1
	end
	return i
end

local function next_word(caret)
	local n = str_len(ctx.text)
	local i = caret
	if i > n then
		return n + 1
	end
	local space = is_space_at(i)
	while i <= n and is_space_at(i) == space do
		i = i + 1
	end
	return i
end

local function class_at(k)
	local char = str_sub(ctx.text, k, k)
	if char == "" then
		return nil
	elseif char:match("%s") then
		return "space"
	elseif char:match("[%w_]") then
		return "word"
	end
	return "punct"
end

local function prev_class_run(caret)
	local i = caret
	if i <= 1 then
		return 1
	end
	local class = class_at(i - 1)
	while i > 1 and class_at(i - 1) == class do
		i = i - 1
	end
	return i
end

---@param index integer|nil
---@return integer|nil lo, integer|nil hi
function TextField.word_range_at(index)
	if not ctx then
		return nil, nil
	end
	local n = str_len(ctx.text)
	if n == 0 then
		return nil, nil
	end
	local at = index or ctx.caret
	if at > n then
		at = n
	elseif at < 1 then
		at = 1
	end
	local class = class_at(at)
	local lo = at
	while lo > 1 and class_at(lo - 1) == class do
		lo = lo - 1
	end
	local hi = at
	while hi <= n and class_at(hi) == class do
		hi = hi + 1
	end
	return lo, hi
end

---@param index integer|nil
function TextField.select_word_at(index)
	local lo, hi = TextField.word_range_at(index)
	if not lo then
		return
	end

	ctx.anchor = lo
	ctx.caret = hi
	ctx.desired_col = nil
end

local function apply_commands()
	if not ctrl_down() then
		return false
	end
	if pressed_idx("a") then
		TextField.select_all()
		return true
	elseif pressed_idx("c") then
		if TextField.has_selection() and Clipboard and Clipboard.put then
			Clipboard.put(TextField.selected_text())
		end
		return true
	elseif pressed_idx("x") then
		if TextField.has_selection() then
			if Clipboard and Clipboard.put then
				Clipboard.put(TextField.selected_text())
			end
			delete_selection()
		end
		return true
	elseif pressed_idx("v") then
		if Clipboard and Clipboard.get then
			local paste = Clipboard.get()
			if paste and paste ~= "" then
				insert_chunk(sanitize(paste, ctx.multiline))
			end
		end
		return true
	end
	return false
end

local function move_caret(to, extend, collapse_edge)
	if not extend and collapse_edge and TextField.has_selection() then
		local lo, hi = TextField.selection_range()
		TextField.set_caret(collapse_edge == "lo" and lo or hi, false)
		return
	end
	TextField.set_caret(to, extend)
end

local function apply_keystrokes()
	if not (Keyboard and Keyboard.keystrokes) then
		return
	end
	local shift = shift_down()
	local ctrl = ctrl_down()
	local strokes = Keyboard.keystrokes()
	for i = 1, #strokes do
		local ks = strokes[i]
		if type(ks) == "string" then
			local b = string.byte(ks)
			if ks == "\t" then

				if not ctrl and ctx.multiline then
					insert_chunk(INDENT)
				end
			elseif b == 127 or b == 8 then

				if not delete_selection() and ctx.caret > 1 then
					local from = ctrl and prev_class_run(ctx.caret) or (ctx.caret - 1)
					snapshot("del")
					ctx.text = str_delete(ctx.text, from, ctx.caret - from)
					ctx.caret = from
					ctx.anchor = from
					ctx.desired_col = nil
				end
			else

				if not ctrl and (b == nil or b >= 32) and b ~= 127 then

					local close = WRAP_PAIRS[ks]
					if not (close and wrap_selection(ks, close)) then
						insert_chunk(ks)
					end
				end
			end
		elseif ks == Keyboard.TAB then

			if not ctrl and ctx.multiline then
				insert_chunk(INDENT)
			end
		elseif ks == Keyboard.BACKSPACE then
			if not delete_selection() and ctx.caret > 1 then

				local from
				if ctrl then
					from = prev_class_run(ctx.caret)
				elseif ctx.multiline and spaces_before(ctx.caret) == TAB_WIDTH then
					from = ctx.caret - TAB_WIDTH
				else
					from = ctx.caret - 1
				end
				snapshot("del")
				ctx.text = str_delete(ctx.text, from, ctx.caret - from)
				ctx.caret = from
				ctx.anchor = from
				ctx.desired_col = nil
			end
		elseif ks == Keyboard.DELETE then
			if not delete_selection() and ctx.caret <= str_len(ctx.text) then

				local to = ctrl and next_word(ctx.caret) or (ctx.caret + 1)
				snapshot("fwddel")
				ctx.text = str_delete(ctx.text, ctx.caret, to - ctx.caret)
				ctx.anchor = ctx.caret
			end
		elseif ks == Keyboard.LEFT then
			local to = ctrl and prev_word(ctx.caret) or ctx.caret - 1
			move_caret(to, shift, "lo")
		elseif ks == Keyboard.RIGHT then
			local to = ctrl and next_word(ctx.caret) or ctx.caret + 1
			move_caret(to, shift, "hi")
		elseif ks == Keyboard.HOME then

			if not ctrl then
				if ctx.multiline then
					local rows = ctx_rows()
					local r = TextField.caret_rc()
					move_caret(rows[r].start, shift, nil)
				else
					move_caret(1, shift, nil)
				end
			end
		elseif ks == Keyboard.END then
			if not ctrl then
				if ctx.multiline then
					local rows = ctx_rows()
					local r = TextField.caret_rc()
					move_caret(rows[r].start + rows[r].len, shift, nil)
				else
					move_caret(str_len(ctx.text) + 1, shift, nil)
				end
			end
		elseif ks == Keyboard.UP then
			move_vertical(-1, shift)
		elseif ks == Keyboard.DOWN then
			move_vertical(1, shift)
		end
	end
end

---@return string|nil
function TextField.update()
	if not ctx then
		return nil
	end
	ensure_indices()

	if pressed_idx("escape") then
		TextField.cancel()
		return "cancel"
	end

	local enter = pressed_idx("enter") or pressed_idx("numpad enter")
	if enter and (not ctx.multiline or ctrl_down()) then
		TextField.commit()
		return "commit"
	end

	if ctrl_down() then
		if pressed_idx("y") then
			TextField.redo()
		elseif pressed_idx("z") then
			if shift_down() then
				TextField.redo()
			else
				TextField.undo()
			end
		end
	end
	local ctrl_command = apply_commands() or (ctrl_down() and (held("z") or held("y")))
	if not ctrl_command then
		if enter and ctx.multiline then

			insert_chunk("\n")
		end
		apply_keystrokes()
	end
	return "editing"
end

mod.hud_studio_text_field = TextField

return TextField
