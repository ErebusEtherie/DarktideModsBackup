
local mod = get_mod("hud_studio")

if mod.hud_studio_block_library_controller then
	return mod.hud_studio_block_library_controller
end

local Layout = mod:core(mod.hud_studio_block_library_layout, "hud/editor/elements/block_library/block_library_layout")
local LibraryPanel =
	mod:core(mod.block_library_panel_component, "hud/editor/elements/block_library/block_library_panel")
local BlockLibrary = mod:core(mod.hud_studio_block_library, "document/block_library")
local Store = mod:core(mod.hud_studio_store, "document/store")
local Session = mod:core(mod.hud_studio_session, "document/session")
local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local DragController = mod:core(mod.hud_studio_drag_controller, "hud/editor/input/drag_controller")

local in_rect = Geometry.in_rect

---@class BlockLibraryState
---@field cat integer          index into the category array
---@field scroll_row integer
---@field scroll_accum number  fractional wheel remainder (see handle_scroll)
---@field selected string?     the selected entry's id
---@field label string?        the rename field's live value, seeded from the entry's label
---@field bind_to string?      the slot the block will be re-pointed at on Add
---@field status string?       result of the last Add / Delete, shown in the caption
---@field confirm_armed boolean?  the delete confirmation dropdown sits on "Confirm Delete"
---@field confirm_open boolean?   its option popup is open

---@class BlockLibraryHover
---@field close boolean?
---@field cat integer?
---@field slot integer?
---@field rename boolean?
---@field confirm boolean?       over the delete confirmation dropdown's trigger
---@field confirm_option integer?  the popup row under the cursor

---@class BlockLibraryCtx
---@field state BlockLibraryState?
---@field panel table            the floating panel box { id, title, x, y, w }
---@field lay LibraryLayout?     this frame's geometry, nil before the first layout
---@field hover BlockLibraryHover
---@field drag table?            the editor's live drag, to spot a title-drag of this panel
---@field close fun()
---@field reveal fun(index: integer)  select the freshly inserted block and show it in the tree
---@field begin_drag fun(cx: number, cy: number)

---@class BlockLibraryController
local LibraryController = {}

---@param cat LibraryCategory?
---@return string
local function cat_caption(cat)
	if not cat then
		return "?"
	end
	if cat.kind == "all" then
		return mod:localize("lib_cat_all")
	elseif cat.kind == "saved" then
		return mod:localize("lib_cat_saved")
	end
	return cat.label
end

---@param cats LibraryCategory[]
---@return string[]
local function cat_captions(cats)
	local out = {}
	for i = 1, #cats do
		out[i] = cat_caption(cats[i])
	end
	return out
end

local RENAME_TOKEN = "block_library/name"

---@param focus_id string?  a catalogue entry id ("user:<name>" / "mod:<relpath>" / "ext:<owner>:<relpath>")
---@return BlockLibraryState
function LibraryController.open(focus_id)
	BlockLibrary.refresh()
	local state = { cat = 1, scroll_row = 0, scroll_accum = 0 }

	local focus = focus_id and BlockLibrary.get(focus_id)
	if focus then

		state.cat = BlockLibrary.category_index_of(focus)

		LibraryController.select_entry(state, focus)

		local entries = LibraryController.entries(state)
		for i = 1, #entries do
			if entries[i].id == focus.id then
				state.scroll_row = math.floor((i - 1) / Layout.COLS)
				break
			end
		end

		return state
	end

	local entries = BlockLibrary.entries_in(nil)
	if entries[1] then
		LibraryController.select_entry(state, entries[1])
	end
	return state
end

---@param ctx BlockLibraryCtx
function LibraryController.close(ctx)
	TextField.commit_if(RENAME_TOKEN)
	LibraryController.clear_hover(ctx)
end

---@param ctx BlockLibraryCtx
function LibraryController.clear_hover(ctx)
	local hover = ctx.hover
	hover.close = nil
	hover.cat = nil
	hover.slot = nil
	hover.rename = nil
	hover.confirm = nil
	hover.confirm_option = nil
end

local CONFIRM_OPTIONS = {
	{ text = mod:localize("lib_confirm_prompt"), value = false },
	{ text = mod:localize("lib_confirm_delete"), value = true },
}

---@param state BlockLibraryState
function LibraryController.reset_confirm(state)
	state.confirm_armed = nil
	state.confirm_open = nil
end

---@param state BlockLibraryState
---@return table ctrl
function LibraryController.confirm_ctrl(state)
	return {
		kind = "dropdown",
		options = CONFIRM_OPTIONS,
		get = function()
			return state.confirm_armed == true
		end,
		set = function(value)
			state.confirm_armed = value == true
		end,
	}
end

---@return LibraryCategory[]
function LibraryController.categories()
	return BlockLibrary.categories()
end

---@param state BlockLibraryState?
---@return LibraryCatalogueEntry[]
function LibraryController.entries(state)
	local cats = BlockLibrary.categories()
	local cat = state and cats[state.cat]
	return BlockLibrary.entries_in(cat)
end

---@param state BlockLibraryState
---@param entry LibraryCatalogueEntry
function LibraryController.select_entry(state, entry)
	state.selected = entry.id
	state.label = entry.label
	state.status = nil
	LibraryController.reset_confirm(state)

	local data = BlockLibrary.load(entry.id)

	if not data then
		state.status = mod:localize("lib_status_could_not_load")
	end
	local details = data and BlockLibrary.details(data)
	state.bind_to = details and details.bind_from or nil

	TextField.commit_if(RENAME_TOKEN)
end

---@param state BlockLibraryState
---@param ci integer
function LibraryController.select_cat(state, ci)
	if state.cat == ci then
		return
	end
	state.cat = ci
	state.scroll_row = 0
	state.scroll_accum = 0
end

---@param state BlockLibraryState?
---@return table? header  { label, author }
function LibraryController.header(state)
	local cats = BlockLibrary.categories()
	local cat = state and cats[state.cat]
	if not cat or cat.kind ~= "mod" or cat.shipped then
		return nil
	end
	return { label = cat.label, author = cat.author }
end

---@param state BlockLibraryState?
---@return table? details
function LibraryController.details(state)
	local id = state and state.selected
	if not id then
		return nil
	end
	local entry = BlockLibrary.get(id)
	local data = entry and BlockLibrary.load(id)
	if not entry or not data then
		return nil
	end
	local derived = BlockLibrary.details(data)

	local tags_line = nil
	if entry.origin == "user" then
		tags_line = derived.is_folder and mod:localize("lib_saved_folder") or mod:localize("lib_saved_block")
	elseif #entry.tags > 0 then
		tags_line = mod:localize("lib_tags_line", table.concat(entry.tags, ", "))
	end

	local sources_line = mod:localize("lib_reads_nothing")
	if #derived.sources > 0 then
		sources_line = mod:localize("lib_reads_line", table.concat(derived.sources, ", "))
	end

	local nodes_line = mod:localize(
		(derived.node_count == 1) and "lib_node_count_one" or "lib_node_count_many",
		derived.node_count
	)
	if derived.is_folder then
		local blocks_line = mod:localize(
			(derived.block_count == 1) and "lib_block_count_one" or "lib_block_count_many",
			derived.block_count
		)
		nodes_line = mod:localize("lib_folder_count_line", blocks_line, nodes_line)
	end

	local missing = BlockLibrary.missing_requires(entry)
	local requires_line = nil
	if #missing > 0 then
		requires_line = mod:localize("lib_requires_missing", table.concat(missing, ", "))
	elseif entry.requires and #entry.requires > 0 then
		requires_line = mod:localize("lib_requires_line", table.concat(entry.requires, ", "))
	end

	return {
		origin = entry.origin,
		is_folder = derived.is_folder,
		requires_line = requires_line,
		requires_missing = #missing > 0,
		update_count = #LibraryController.updatable(entry),
		label = entry.label,
		summary = entry.summary,
		tags_line = tags_line,
		nodes_line = nodes_line,
		sources_line = sources_line,
		saved_line = entry.saved_at and mod:localize("lib_saved_line", entry.saved_at) or nil,
		bind_options = derived.bind_options,
		bind_from = derived.bind_from,
	}
end

---@param entry LibraryCatalogueEntry?
---@return integer[] indices
function LibraryController.updatable(entry)
	local out = {}
	if not entry or entry.kind == "folder" then
		return out
	end
	local blocks = Session.blocks()
	for i = 1, #blocks do
		if BlockLibrary.has_update(blocks[i].origin, entry) then
			out[#out + 1] = i
		end
	end
	return out
end

---@param want string
---@return string
local function unique_folder_name(want)
	if want == "" then
		want = "folder"
	end
	if not Session.folder_exists(want) then
		return want
	end
	local suffix = 2
	while Session.folder_exists(want .. "_" .. suffix) do
		suffix = suffix + 1
	end
	return want .. "_" .. suffix
end

---@param ctx BlockLibraryCtx
function LibraryController.add(ctx)
	local state = ctx.state
	local details = LibraryController.details(state)
	if not state or not details then
		return
	end

	local blocks, skipped, is_folder =
		BlockLibrary.prepare(state.selected, state.label, details.bind_from, state.bind_to)
	if not blocks then
		state.status = mod:localize("lib_status_could_not_load")
		mod.dl.log.error("block library: could not prepare '%s': %s", tostring(state.selected), tostring(skipped))
		return
	end

	local folder = nil
	if is_folder then

		local want = state.label or details.label or ""
		folder = unique_folder_name(Schema.is_valid_folder_name(want) and want or Schema.slugify(want))
		local ok, reason = Session.folder_create(folder)
		if not ok then
			state.status = mod:localize("lib_status_add_failed")
			mod.dl.log.error("block library: could not create folder '%s': %s", folder, tostring(reason))
			return
		end
	end

	local last_index, added = nil, 0
	for i = 1, #blocks do
		local index, reason = Session.insert_block(blocks[i])
		if index then

			if folder then
				local moved = Session.set_block_folder(index, folder)
				index = moved or index
			end
			last_index = index
			added = added + 1
		else
			mod.dl.log.error("block library: could not add '%s': %s", tostring(state.selected), tostring(reason))
		end
	end

	if added == 0 then
		state.status = mod:localize("lib_status_add_failed")
		return
	end

	if skipped and skipped > 0 then
		state.status = mod:localize("lib_status_added_skipped", skipped)
	elseif is_folder then
		state.status = mod:localize("lib_status_added_folder", added, folder)
	else
		state.status = mod:localize("lib_status_added")
	end
	ctx.reveal(last_index)
end

---@param ctx BlockLibraryCtx
function LibraryController.update(ctx)
	local state = ctx.state
	local entry = state and state.selected and BlockLibrary.get(state.selected)
	local targets = LibraryController.updatable(entry)
	if #targets == 0 then
		return
	end

	local origin = BlockLibrary.origin_of(entry)
	local updated, last_index = 0, nil

	for t = #targets, 1, -1 do
		local bi = targets[t]

		local blocks, reason = BlockLibrary.prepare(state.selected)
		if not blocks or not blocks[1] then
			mod.dl.log.error("block library: could not load update for '%s': %s", tostring(state.selected), tostring(reason))
			break
		end
		local ok, why = Session.update_block(bi, blocks[1], origin)
		if ok then
			updated = updated + 1
			last_index = bi
		else
			mod.dl.log.error("block library: could not update block %d: %s", bi, tostring(why))
		end
	end

	if updated == 0 then
		state.status = mod:localize("lib_status_update_failed")
		return
	end
	state.status = mod:localize("lib_status_updated", updated)
	ctx.reveal(last_index)
end

---@param ctx BlockLibraryCtx
function LibraryController.delete(ctx)
	local state = ctx.state
	local entry = state and state.selected and BlockLibrary.get(state.selected)
	if not entry or entry.origin ~= "user" then
		return
	end
	if not state.confirm_armed then

		return
	end

	LibraryController.reset_confirm(state)

	local ok, reason = Store.delete_library(entry.name)
	if not ok then
		state.status = mod:localize("lib_status_delete_failed")
		mod.dl.log.error("block library: could not delete '%s': %s", entry.name, tostring(reason))
		return
	end

	BlockLibrary.refresh()
	state.selected = nil
	state.status = mod:localize("lib_status_deleted")
	local entries = LibraryController.entries(state)
	if entries[1] then
		LibraryController.select_entry(state, entries[1])
		state.status = mod:localize("lib_status_deleted")
	end
end

---@param ctx BlockLibraryCtx
---@return LibraryLayout?
function LibraryController.layout(ctx)
	local state = ctx.state
	if not state then
		return nil
	end
	local cats = BlockLibrary.categories()
	if state.cat > #cats then
		state.cat = 1
	end

	local details = LibraryController.details(state)
	local n_bind = details and #details.bind_options or 0

	local can_update = details == nil or details.origin ~= "user"

	local panel = ctx.panel
	local lay =
		Layout.layout(panel.x, panel.y, panel.w, #cats, n_bind, LibraryController.header(state) ~= nil, can_update)
	lay.n_entries = #LibraryController.entries(state)
	lay.max_scroll = Layout.max_scroll(lay.n_entries, lay.grid.visible_rows)
	if state.scroll_row > lay.max_scroll then
		state.scroll_row = lay.max_scroll
	end
	return lay
end

---@param ctx BlockLibraryCtx
---@param view_input table?
function LibraryController.handle_scroll(ctx, view_input)
	local lay, state = ctx.lay, ctx.state
	if not lay or not state then
		return
	end
	local max_scroll = lay.max_scroll or 0
	if max_scroll <= 0 then
		state.scroll_row = 0
		state.scroll_accum = 0
		return
	end
	local axis = view_input and view_input:get("scroll_axis")
	local delta = axis and axis[2] or 0
	if delta ~= 0 then
		state.scroll_accum = state.scroll_accum + delta
	end
	while state.scroll_accum >= 1 do
		state.scroll_row = state.scroll_row - 1
		state.scroll_accum = state.scroll_accum - 1
	end
	while state.scroll_accum <= -1 do
		state.scroll_row = state.scroll_row + 1
		state.scroll_accum = state.scroll_accum + 1
	end
	if state.scroll_row < 0 then
		state.scroll_row = 0
	elseif state.scroll_row > max_scroll then
		state.scroll_row = max_scroll
	end
end

---@param ctx BlockLibraryCtx
---@param cx number
---@param cy number
---@param pressed boolean
---@return boolean consumed
function LibraryController.interact(ctx, cx, cy, pressed)
	local lay, state = ctx.lay, ctx.state
	if not lay or not state then
		return false
	end
	LibraryController.clear_hover(ctx)

	if in_rect(cx, cy, PanelHeader.close_rect(ctx.panel)) then
		ctx.hover.close = true
		if pressed then
			ctx.close()
		end
		return true
	end
	if in_rect(cx, cy, lay.title) then
		if pressed then
			ctx.begin_drag(cx, cy)
		end
		return true
	end

	for i = 1, #lay.cats do
		if in_rect(cx, cy, lay.cats[i]) then
			ctx.hover.cat = i
			if pressed then
				LibraryController.select_cat(state, i)
			end
			return true
		end
	end

	local entries = LibraryController.entries(state)
	local base = state.scroll_row * lay.grid.cols
	for s = 1, #lay.grid.slots do
		local entry = entries[base + s]
		if entry and in_rect(cx, cy, lay.grid.slots[s]) then
			ctx.hover.slot = s
			if pressed then
				LibraryController.select_entry(state, entry)
			end
			return true
		end
	end

	if state.confirm_open then

		local options = CONFIRM_OPTIONS
		local index, option = Dropdown.option_at(lay.details.confirm, options, 0, cx, cy)
		if option then
			ctx.hover.confirm_option = index
			if pressed then
				state.confirm_armed = option.value == true
				state.confirm_open = nil
			end
			return true
		end
		if pressed and not in_rect(cx, cy, lay.details.confirm) then
			state.confirm_open = nil
		end
	end

	local details = LibraryController.details(state)
	if details and details.origin == "user" and in_rect(cx, cy, lay.details.confirm) then
		ctx.hover.confirm = true
		if pressed then
			state.confirm_open = (not state.confirm_open) or nil
		end
		return true
	end

	if in_rect(cx, cy, lay.details.rename) then
		ctx.hover.rename = true
		if pressed and not TextField.is_focused(RENAME_TOKEN) then

			TextField.focus(RENAME_TOKEN, state.label or "", function(text)
				state.label = text
			end)
		end
		return true
	end

	if in_rect(cx, cy, lay.frame) then

		if pressed then
			TextField.commit()
		end
		return true
	end
	return false
end

---@param d Draw
---@param ctx BlockLibraryCtx
---@param z number
function LibraryController.draw(d, ctx, z)
	local lay, state = ctx.lay, ctx.state
	if not lay or not state then
		return
	end

	local cats = BlockLibrary.categories()
	local entries = LibraryController.entries(state)
	local details = LibraryController.details(state)

	local title = mod:localize("panel_library_title_dynamic", cat_caption(cats[state.cat]), #entries)
	if state.status then
		title = mod:localize("panel_library_title_status", title, state.status)
	end

	LibraryPanel.draw(d, ctx.panel, z, lay, DragController.is_panel_drag(ctx.drag, ctx.panel), {
		title = title,
		close_hover = ctx.hover.close,
		cats = cat_captions(cats),
		cat_index = state.cat,
		header = LibraryController.header(state),
		hover_cat = ctx.hover.cat,
		hover_slot = ctx.hover.slot,
		entries = entries,
		selected_id = state.selected,
		scroll_row = state.scroll_row,
		details = details,
		rename_ctrl = LibraryController.rename_ctrl(state),
		rename_focused = TextField.is_focused(RENAME_TOKEN),
		rename_hovered = ctx.hover.rename,
		bind_to = state.bind_to,
		confirm_ctrl = LibraryController.confirm_ctrl(state),
		confirm_open = state.confirm_open == true,
		confirm_hovered = ctx.hover.confirm == true,
		confirm_hover_index = ctx.hover.confirm_option,
		confirm_armed = state.confirm_armed == true,
		can_add = details ~= nil,
		on_add = function()
			LibraryController.add(ctx)
		end,
		on_bind = function(slot)
			state.bind_to = slot
		end,
		on_delete = function()
			LibraryController.delete(ctx)
		end,
		on_update = function()
			LibraryController.update(ctx)
		end,
	})
end

---@param state BlockLibraryState
---@return table ctrl
function LibraryController.rename_ctrl(state)
	return {
		token = RENAME_TOKEN,
		get = function()
			return state.label or ""
		end,
		set = function(text)
			state.label = text
		end,
	}
end

mod.hud_studio_block_library_controller = LibraryController

return LibraryController
