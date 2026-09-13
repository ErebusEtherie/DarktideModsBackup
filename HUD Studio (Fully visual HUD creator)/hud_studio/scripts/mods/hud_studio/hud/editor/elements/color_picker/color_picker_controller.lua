
local mod = get_mod("hud_studio")

if mod.hud_studio_color_picker_controller then
	return mod.hud_studio_color_picker_controller
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local ColorPicker = mod:core(mod.color_picker, "hud/editor/elements/color_picker/color_picker")
local Clipboard = mod:core(mod.hud_studio_clipboard, "engine/clipboard")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")

local PANEL = C.PANEL
local COLOR = C.COLOR

local function in_rect(px, py, r)
	return r and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local ColorPickerController = {}

function ColorPickerController.box(item)
	local sw = item.parts.swatch
	return { x = sw.x, y = sw.y + sw.h + 2, w = PANEL.PICKER_W, h = PANEL.PICKER_H }
end

function ColorPickerController.seed(ctrl)
	local h, s, l, a = mod.dl.colors.argb_to_hsla(ctrl.get())
	return { ctrl = ctrl, h = h, s = s, l = l, a = a }
end

function ColorPickerController.item(ctx)
	local state, form = ctx.state, ctx.form
	if not state or not form then
		return nil
	end
	for i = 1, #form.items do
		local it = form.items[i]
		if it.t == "field" and it.ctrl == state.ctrl then
			return it
		end
	end
	return nil
end

local SAVED_KEY = "__hs_saved_colors"

local saved_cache = nil

function ColorPickerController.saved()
	if saved_cache then
		return saved_cache
	end
	local list = {}
	local stored = mod:get(SAVED_KEY)
	if type(stored) == "string" then
		for entry in stored:gmatch("[^;]+") do
			local bytes = {}
			for n in entry:gmatch("%d+") do
				bytes[#bytes + 1] = math.min(tonumber(n), 255)
			end
			if #bytes == 4 then
				list[#list + 1] = bytes
			end
		end
	end
	saved_cache = list
	return list
end

local function store_saved(list)
	local entries = {}
	for i = 1, #list do
		local c = list[i]
		entries[i] = string.format("%d,%d,%d,%d", c[1], c[2], c[3], c[4])
	end
	saved_cache = list
	mod:set(SAVED_KEY, table.concat(entries, ";"))
end

function ColorPickerController.save_color(state, box)
	if not state then
		return
	end
	local lay = ColorPicker.layout(box.x, box.y, box.w, box.h)
	local list = ColorPickerController.saved()
	local color = mod.dl.colors.hsla_to_argb(state.h, state.s, state.l, state.a)
	for i = 1, #list do
		local c = list[i]
		if c[1] == color[1] and c[2] == color[2] and c[3] == color[3] and c[4] == color[4] then
			state.saved_index = i
			return
		end
	end
	if #list >= ColorPicker.saved_capacity(lay.saved) then
		mod.dl.log.notify(mod:localize("cp_saved_full"))
		return
	end
	list[#list + 1] = color
	store_saved(list)
	state.saved_index = #list
end

function ColorPickerController.delete_color(state)
	local index = state and state.saved_index
	if not index then
		return
	end
	local list = ColorPickerController.saved()
	if list[index] then
		table.remove(list, index)
		store_saved(list)
	end
	state.saved_index = nil
end

function ColorPickerController.pick_saved(state, index)
	local color = ColorPickerController.saved()[index]
	if not color or not state then
		return nil
	end
	state.h, state.s, state.l, state.a = mod.dl.colors.argb_to_hsla(color)
	state.saved_index = index

	return { color[1], color[2], color[3], color[4] }
end

function ColorPickerController.press_region(box, cx, cy)
	local lay = ColorPicker.layout(box.x, box.y, box.w, box.h)
	if in_rect(cx, cy, lay.hue) then
		return "hue"
	elseif in_rect(cx, cy, lay.alpha) then
		return "alpha"
	elseif in_rect(cx, cy, lay.sl) then
		return "sl"
	elseif in_rect(cx, cy, lay.button) then
		return "button"
	elseif in_rect(cx, cy, lay.saved) then
		local index = ColorPicker.saved_hit(lay.saved, cx, cy, #ColorPickerController.saved())
		return index and "saved" or nil, index
	end
	return nil
end

function ColorPickerController.apply(state, drag, cx, cy)
	if not state then
		return
	end

	state.saved_index = nil
	local lay = ColorPicker.layout(drag.box.x, drag.box.y, drag.box.w, drag.box.h)
	if drag.region == "hue" then
		state.h = ColorPicker.pos_to_hue(lay.hue, cy)
	elseif drag.region == "alpha" then
		state.a = ColorPicker.pos_to_alpha(lay.alpha, cy)
	else
		state.s, state.l = ColorPicker.pos_to_sl(lay.sl, cx, cy)
	end
	drag.ctrl.set(mod.dl.colors.hsla_to_argb(state.h, state.s, state.l, state.a))
end

function ColorPickerController.copy(ctrl)
	local color = ctrl.get()
	if not color then
		return
	end
	local text = string.format("{ %d, %d, %d, %d }", color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0)
	if Clipboard.copy(text) then
		mod.dl.log.notify(mod:localize("cp_copied", text))
	end
end

function ColorPickerController.paste(ctx, ctrl)
	local text = Clipboard.paste()
	if text == "" then
		return
	end

	local bytes = {}
	for n in string.gmatch(text, "%-?%d+") do
		bytes[#bytes + 1] = tonumber(n)
		if #bytes > 4 then
			break 
		end
	end

	if #bytes ~= 4 then
		mod.dl.log.notify(mod:localize("cp_clipboard_not_colour"))
		return
	end
	for i = 1, 4 do
		if bytes[i] < 0 or bytes[i] > 255 then
			mod.dl.log.notify(mod:localize("cp_values_out_of_range"))
			return
		end
	end

	ctx.edit(ctrl, bytes)
	mod.dl.log.notify(mod:localize("cp_pasted", bytes[1], bytes[2], bytes[3], bytes[4]))
end

local function draw_knob(d, x, y, z)
	local r = PANEL.PICKER_KNOB
	d:outline(x - r, y - r, x + r, y + r, z, COLOR.CTRL_BORDER)
	d:outline(x - r + 1, y - r + 1, x + r - 1, y + r - 1, z + 1, COLOR.TITLE_TEXT)
end

local function draw_saved(d, lay, state, z)
	local list = ColorPickerController.saved()
	local capacity = ColorPicker.saved_capacity(lay.saved)
	for i = 1, capacity do
		local slot = ColorPicker.saved_slot(lay.saved, i)
		local color = list[i]
		d:rect(slot.x, slot.y, z, slot.w, slot.h, color and COLOR.CTRL_TEXT_MUTED or COLOR.CTRL_BG)
		if color then
			d:rect(slot.x, slot.y, z + 1, slot.w, slot.h, color)
		end
		local border = (state.saved_index == i and COLOR.FOCUS_BORDER)
			or (color and d:in_rect(slot.x, slot.y, slot.w, slot.h) and COLOR.CTRL_TEXT_HOVER)
			or COLOR.CTRL_BORDER
		d:outline(slot.x, slot.y, slot.x + slot.w, slot.y + slot.h, z + 2, border)
	end

	local btn = lay.button
	local hovered = d:in_rect(btn.x, btn.y, btn.w, btn.h)
	d:rect(btn.x, btn.y, z, btn.w, btn.h, hovered and COLOR.STEP_BG_HOVER or COLOR.STEP_BG)
	d:outline(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h, z + 1, COLOR.CTRL_BORDER)
	local label = state.saved_index and mod:localize("cp_delete_colour") or mod:localize("cp_save_colour")
	d:text_center(label, 12, btn.x, btn.y, z + 2, btn.w, btn.h, COLOR.STEP_TEXT)
end

function ColorPickerController.draw_popup(d, ctx, z)
	local state = ctx.state
	if not state then
		return
	end
	local item = ColorPickerController.item(ctx)
	if not item then
		return
	end
	local box = ColorPickerController.box(item)
	local lay = ColorPicker.layout(box.x, box.y, box.w, box.h)

	PanelBody.draw(d, box, box.h, z, {
		full = true,
	})

	local cells = ColorPicker.build_cells(lay, state.h, state.s, state.l, state.a, { sl = 14, slider = 24 })
	for i = 1, #cells.sl do
		local c = cells.sl[i]
		d:rect(c.x, c.y, z + 1, c.w, c.h, c.color)
	end
	for i = 1, #cells.hue do
		local c = cells.hue[i]
		d:rect(c.x, c.y, z + 1, c.w, c.h, c.color)
	end
	d:rect(lay.alpha.x, lay.alpha.y, z + 1, lay.alpha.w, lay.alpha.h, COLOR.CTRL_TEXT_MUTED)
	for i = 1, #cells.alpha do
		local c = cells.alpha[i]
		d:rect(c.x, c.y, z + 2, c.w, c.h, c.color)
	end

	d:outline(lay.sl.x, lay.sl.y, lay.sl.x + lay.sl.w, lay.sl.y + lay.sl.h, z + 3, COLOR.CTRL_BORDER)
	d:outline(lay.hue.x, lay.hue.y, lay.hue.x + lay.hue.w, lay.hue.y + lay.hue.h, z + 3, COLOR.CTRL_BORDER)
	d:outline(lay.alpha.x, lay.alpha.y, lay.alpha.x + lay.alpha.w, lay.alpha.y + lay.alpha.h, z + 3, COLOR.CTRL_BORDER)

	draw_knob(d, cells.knobs.sl.x, cells.knobs.sl.y, z + 4)
	draw_knob(d, cells.knobs.hue.x, cells.knobs.hue.y, z + 4)
	draw_knob(d, cells.knobs.alpha.x, cells.knobs.alpha.y, z + 4)

	draw_saved(d, lay, state, z + 1)

	d:outline(box.x, box.y, box.x + box.w, box.y + box.h, z + 5)
end

mod.hud_studio_color_picker_controller = ColorPickerController

return ColorPickerController
