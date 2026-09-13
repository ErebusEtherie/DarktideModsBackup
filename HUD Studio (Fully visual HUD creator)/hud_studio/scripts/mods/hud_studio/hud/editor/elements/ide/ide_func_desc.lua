
local mod = get_mod("hud_studio")

if mod.ide_func_desc_component then
	return mod.ide_func_desc_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local Button = mod:core(mod.hud_studio_button_component, "hud/editor/elements/button/button")

local PROSE = {
	style = mod:localize("ide_prose_style"),
	visible = mod:localize("ide_prose_visible"),
	script = mod:localize("ide_prose_script"),
	value = mod:localize("ide_prose_value"),
}

local RETURNS = {
	visible = "boolean  (true = shown, false / nil = hidden)",

	script = mod:localize("ide_return_block"),
	text = mod:localize("ide_return_text"),
	color = "{ a, r, g, b } 0..255",
	font_size = "number",
	size = "{ w, h }",
	shadow = "boolean",

	current = mod:localize("ide_return_current"),
	max = mod:localize("ide_return_max"),
}

local FONT_SIZE = 12
local LINE_H = 14 
local RET_GAP = 2 
local TOP_PAD = 3 
local NAME_PAD = 2

local RESET_W = 96
local RESET_H = 18
local RESET_GAP = 8 
local RESET_LABEL = mod:localize("ide_reset_button_text")

local COLOR = {
	PROSE = C.COLOR.NOTE_TEXT,
	RETURN = { 255, 130, 175, 140 }, 
	RULE = C.COLOR.PANEL_RULE,
}

local MEASURE_FONT_SIZE = 14
local MEASURE_SCALE = FONT_SIZE / MEASURE_FONT_SIZE

local function wrap_measured(ui_renderer, text, max_w)
	local rows = {}
	local line = ""
	for word in tostring(text):gmatch("%S+") do
		local cand = (line == "") and word or (line .. " " .. word)
		if line ~= "" and TextMetrics.measure(ui_renderer, cand) * MEASURE_SCALE > max_w then
			rows[#rows + 1] = line
			line = word
		else
			line = cand
		end
	end
	if line ~= "" then
		rows[#rows + 1] = line
	end
	if #rows == 0 then
		rows[1] = ""
	end
	return rows
end

local FuncDesc = {}

local function resolve(model)
	local rv = model.rv

	if rv == "style" then
		local knobs = model.node_type and model.node_type.style_knobs
		local shape = "table"
		if knobs and #knobs > 0 then
			shape = "{ " .. table.concat(knobs, ", ") .. " }"
		end
		return PROSE.style, shape
	end

	if rv == "visible" then
		return PROSE.visible, RETURNS.visible
	end

	if rv == "script" then
		return PROSE.script, RETURNS.script
	end

	return PROSE.value .. tostring(rv), RETURNS[rv]
end

function FuncDesc.prepare(model, x, y, w, ui_renderer)
	local prose, ret_text = resolve(model)

	local text_w = w - NAME_PAD * 2 - RESET_W - RESET_GAP
	local lines = wrap_measured(ui_renderer, prose, text_w)

	local h = TOP_PAD + #lines * LINE_H
	if ret_text and ret_text ~= "" then
		h = h + RET_GAP + LINE_H
	end

	local reset_rect = model.reset and { x = x + w - RESET_W, y = y + TOP_PAD, w = RESET_W, h = RESET_H } or nil
	local min_h = TOP_PAD + RESET_H
	if reset_rect and h < min_h then
		h = min_h
	end

	return {
		lines = lines,
		ret_text = ret_text,
		reset_rect = reset_rect,
		text_w = text_w,
		x = x,
		y = y,
		w = w,
		h = h,
	}
end

function FuncDesc.draw(d, lay, z, ctx)
	if not lay then
		return
	end

	d:rect(lay.x, lay.y, z, lay.w, 1, COLOR.RULE)

	local reset = lay.reset_rect
	if reset then
		Button.draw(d, "ide_reset_changes", reset.x, reset.y, z + 1, reset.w, reset.h, RESET_LABEL, {
			text_size = 12,
			tooltip = mod:localize("ide_reset_button_tooltip"),
			on_click = ctx and ctx.on_reset,
		})
	end

	local cursor_y = lay.y + TOP_PAD
	for i = 1, #lay.lines do
		d:text_left(lay.lines[i], FONT_SIZE, lay.x + NAME_PAD, cursor_y, z + 1, lay.text_w, LINE_H, COLOR.PROSE)
		cursor_y = cursor_y + LINE_H
	end

	if lay.ret_text and lay.ret_text ~= "" then
		cursor_y = cursor_y + RET_GAP
		d:text_left(
			mod:localize("ide_expected_return_label") .. lay.ret_text,
			FONT_SIZE,
			lay.x + NAME_PAD,
			cursor_y,
			z + 1,
			lay.w,
			LINE_H,
			COLOR.RETURN
		)
	end
end

mod.ide_func_desc_component = FuncDesc

return FuncDesc
