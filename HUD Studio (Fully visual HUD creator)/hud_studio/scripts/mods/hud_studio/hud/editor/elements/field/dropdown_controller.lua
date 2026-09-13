
local mod = get_mod("hud_studio")

if mod.hud_studio_dropdown_controller then
	return mod.hud_studio_dropdown_controller
end

local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")

local DropdownController = {}

local collapsed_by_ctrl = setmetatable({}, { __mode = "k" })

local function collapsed_set(ctrl)
	local set = collapsed_by_ctrl[ctrl]
	if not set then
		set = Dropdown.default_collapsed(Dropdown.options(ctrl), ctrl.get())
		collapsed_by_ctrl[ctrl] = set
	end
	return set
end

local SEARCH_TOKEN = "hud_studio_dropdown_search"

local function searchable(ctrl)
	return ctrl ~= nil and ctrl.searchable == true
end

local function query(state)
	if not (state and searchable(state.ctrl) and TextField.is_focused(SEARCH_TOKEN)) then
		return ""
	end
	return TextField.text()
end

local function visible_options(ctrl, state)
	local options = Dropdown.options(ctrl)
	return Dropdown.filter(options, query(state)) or Dropdown.visible_options(options, collapsed_set(ctrl))
end

local function unfocus_search()
	if TextField.is_focused(SEARCH_TOKEN) then
		TextField.cancel()
	end
end

local function toggle_group(state, option)
	local key = Dropdown.group_key(option)
	if not key then
		return
	end
	local set = collapsed_set(state.ctrl)
	set[key] = (not set[key]) or nil

	state.row_h = nil
	state.scroll = math.min(state.scroll or 0, Dropdown.max_scroll(#visible_options(state.ctrl, state)))
	state.scroll_accum = 0
end

function DropdownController.open_state(ctrl)
	local options = visible_options(ctrl, nil)
	local selected = Dropdown.selected_index(options, ctrl.get())
	if searchable(ctrl) then

		TextField.focus(SEARCH_TOKEN, "")
	end
	return { ctrl = ctrl, scroll = Dropdown.centered_scroll(#options, selected), scroll_accum = 0, query = "" }
end

function DropdownController.update(ctx)
	local state = ctx.state
	if not state then
		unfocus_search()
		return
	end
	if not searchable(state.ctrl) then
		return
	end
	if not TextField.is_focused(SEARCH_TOKEN) then
		ctx.close()
		return
	end
	local current = TextField.text()
	if current ~= state.query then
		state.query = current
		state.row_h = nil
		state.scroll = 0
		state.scroll_accum = 0
	end
end

function DropdownController.item(ctx)
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

function DropdownController.interact(ctx, cx, cy, pressed)
	local state = ctx.state
	local item = DropdownController.item(ctx)
	if not item then

		unfocus_search()
		ctx.close()
		return false
	end
	local box = item.parts.box
	local search = searchable(state.ctrl)
	local options = visible_options(state.ctrl, state)
	ctx.set_hover(nil)

	local max_count = #Dropdown.options(state.ctrl)
	local index, option = Dropdown.option_at(box, options, state.scroll or 0, cx, cy, max_count, state.row_h, search)
	if option then
		ctx.set_hover(index)
		if pressed then
			if Dropdown.is_section(option) then

			elseif Dropdown.is_group(option) then

				toggle_group(state, option)
			else
				unfocus_search()
				ctx.close()

				ctx.edit(state.ctrl, option.value)
			end
		end
		return true
	end

	local pr = Dropdown.popup_rect(box, #options, max_count, state.row_h, search)
	if cx >= pr.x and cx <= pr.x + pr.w and cy >= pr.y and cy <= pr.y + pr.h then

		return true
	end

	if pressed and not (cx >= box.x and cx <= box.x + box.w and cy >= box.y and cy <= box.y + box.h) then
		unfocus_search()
		ctx.close()
		return true
	end
	return false
end

function DropdownController.handle_scroll(ctx, view_input)
	local state = ctx.state
	if not state then
		return
	end
	local item = DropdownController.item(ctx)
	if not item then
		return
	end
	local max_scroll = Dropdown.max_scroll(#visible_options(state.ctrl, state), state.row_h)
	if max_scroll <= 0 then
		state.scroll = 0
		state.scroll_accum = 0
		return
	end
	local axis = view_input and view_input:get("scroll_axis")
	local delta = axis and axis[2] or 0
	if delta ~= 0 then
		state.scroll_accum = (state.scroll_accum or 0) + delta
	end
	while state.scroll_accum >= 1 do
		state.scroll = state.scroll - 1
		state.scroll_accum = state.scroll_accum - 1
	end
	while state.scroll_accum <= -1 do
		state.scroll = state.scroll + 1
		state.scroll_accum = state.scroll_accum + 1
	end
	if state.scroll < 0 then
		state.scroll = 0
	elseif state.scroll > max_scroll then
		state.scroll = max_scroll
	end
end

function DropdownController.draw_popup(d, ctx, z)
	local state = ctx.state
	if not state then
		return
	end
	local item = DropdownController.item(ctx)
	if not item then
		return
	end
	local options = visible_options(state.ctrl, state)
	local search
	if searchable(state.ctrl) then

		state.search_ctrl = state.search_ctrl
			or {
				token = SEARCH_TOKEN,
				get = function()
					return query(state)
				end,
			}
		search = { ctrl = state.search_ctrl, focused = TextField.is_focused(SEARCH_TOKEN) }
	end
	Dropdown.draw_popup(
		d,
		item.parts.box,
		options,
		ctx.hover,
		z,
		state.scroll,
		collapsed_set(state.ctrl),
		Dropdown.selected_index(options, state.ctrl.get()),
		#Dropdown.options(state.ctrl),
		state,
		search
	)
end

mod.hud_studio_dropdown_controller = DropdownController

return DropdownController
