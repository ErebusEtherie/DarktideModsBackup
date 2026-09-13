
local mod = get_mod("hud_studio")

if mod.block_library_panel_component then
	return mod.block_library_panel_component
end

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local Button = mod:core(mod.hud_studio_button_component, "hud/editor/elements/button/button")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local C = mod:core(mod.editor_constants, "hud/editor/constants")

local LABEL_FONT_SIZE = 15 
local HEADING_FONT_SIZE = 17
local BODY_FONT_SIZE = 13
local LINE_H = 16 
local POPUP_Z_OFFSET = 20

local HEADING_FONT = mod.dl.fonts.validated("proxima_nova_bold")

local COLOR = {
	ROW_SELECTED = C.COLOR.ROW_SELECTED,
	ROW_TEXT = C.COLOR.ROW_TEXT,
	CTRL_BG = C.COLOR.CTRL_BG,
	CTRL_BG_HOVER = C.COLOR.CTRL_BG_HOVER,
	CELL_SELECTED = { 255, 120, 180, 255 },
	TITLE_TEXT = C.COLOR.TITLE_TEXT,
	NOTE_TEXT = C.COLOR.NOTE_TEXT,

	WARN_TEXT = { 255, 235, 180, 70 },
	SCROLL_THUMB = C.COLOR.SCROLL_THUMB,
	PANEL_RULE = C.COLOR.PANEL_RULE,
}

local BlockLibraryPanel = {}

---@param d Draw
---@param text string
---@param rect Rect
---@param z number
---@param color number[]
---@return number lines_drawn
local function draw_wrapped(d, text, rect, z, color)
	if not text or text == "" then
		return 0
	end
	local rows = TextField.wrap_text(text, rect.w)
	local drawn = 0
	for i = 1, #rows do
		local y = rect.y + (i - 1) * LINE_H
		if y + LINE_H > rect.y + rect.h then
			break
		end
		d:text_left(rows[i], BODY_FONT_SIZE, rect.x, y, z, rect.w, LINE_H, color)
		drawn = i
	end
	return drawn
end

function BlockLibraryPanel.draw(d, panel, z, lay, dragging, ctx)
	PanelBody.draw(d, panel, lay.frame.h, z)
	PanelHeader.draw(d, panel, z, dragging, {
		title = ctx.title,
		close = { hover = ctx.close_hover },
	})

	local body_z = z + 1
	local text_z = z + 2

	for i = 1, #lay.cats do
		local r = lay.cats[i]
		local active = ctx.cat_index == i
		local hovered = ctx.hover_cat == i
		local bg = active and COLOR.ROW_SELECTED or (hovered and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)
		d:rect(r.x, r.y, body_z, r.w, r.h, bg)
		d:text_left(ctx.cats[i], LABEL_FONT_SIZE, r.x + 6, r.y, text_z, r.w - 12, r.h, COLOR.ROW_TEXT)
		d:field_outline(r.x, r.y, r.x + r.w, r.y + r.h, body_z)
	end

	if lay.header and ctx.header then
		BlockLibraryPanel.draw_header(d, z, lay.header, ctx.header)
	end

	local base = ctx.scroll_row * lay.grid.cols
	for s = 1, #lay.grid.slots do
		local r = lay.grid.slots[s]
		local entry = ctx.entries[base + s]
		if entry then
			local selected = ctx.selected_id == entry.id
			local hovered = ctx.hover_slot == s
			local bg = selected and COLOR.ROW_SELECTED or (hovered and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)
			d:rect(r.x, r.y, body_z, r.w, r.h, bg)
			d:text_left_fit(
				entry.label,
				LABEL_FONT_SIZE,
				r.x + 6,
				r.y,
				text_z,
				r.w - 12,
				r.h,
				COLOR.ROW_TEXT,
				nil,
				nil,
				4
			)
			if selected then
				d:outline(r.x, r.y, r.x + r.w, r.y + r.h, z + 3, COLOR.CELL_SELECTED)
			else
				d:field_outline(r.x, r.y, r.x + r.w, r.y + r.h, body_z)
			end
		end
	end

	if lay.max_scroll and lay.max_scroll > 0 then
		local sb = lay.scrollbar
		d:rect(sb.x, sb.y, body_z, sb.w, sb.h, COLOR.CTRL_BG)
		local total_rows = math.ceil(lay.n_entries / lay.grid.cols)
		local thumb_h = math.max(24, sb.h * lay.grid.visible_rows / total_rows)
		local frac = ctx.scroll_row / lay.max_scroll
		d:rect(sb.x, sb.y + (sb.h - thumb_h) * frac, text_z, sb.w, thumb_h, COLOR.SCROLL_THUMB)
	end

	BlockLibraryPanel.draw_details(d, z, lay.details, ctx)
end

---@param d Draw
---@param z number
---@param hr LibraryHeaderRects
---@param header table   { label, author }
function BlockLibraryPanel.draw_header(d, z, hr, header)
	local body_z = z + 1
	local text_z = z + 2

	d:rect(hr.x, hr.y, body_z, hr.w, hr.h, COLOR.CTRL_BG)

	local heading = header.author and mod:localize("lib_mod_header_by", header.label, header.author)
		or header.label
	d:text_left_fit(
		heading,
		LABEL_FONT_SIZE,
		hr.heading.x + 6,
		hr.heading.y,
		text_z,
		hr.heading.w - 12,
		hr.heading.h,
		COLOR.TITLE_TEXT,
		HEADING_FONT,
		nil,
		2
	)
	draw_wrapped(
		d,
		mod:localize("lib_mod_disclaimer"),
		{ x = hr.disclaimer.x + 6, y = hr.disclaimer.y, w = hr.disclaimer.w - 12, h = hr.disclaimer.h },
		text_z,
		COLOR.NOTE_TEXT
	)
	d:field_outline(hr.x, hr.y, hr.x + hr.w, hr.y + hr.h, body_z)
end

---@param d Draw
---@param z number
---@param dr LibraryDetailsRects
---@param ctx table
function BlockLibraryPanel.draw_details(d, z, dr, ctx)
	local body_z = z + 1
	local text_z = z + 2
	local details = ctx.details

	d:rect(dr.x - 6, dr.y, body_z, 1, dr.h, COLOR.PANEL_RULE)

	if not details then
		d:text_left(
			mod:localize("lib_details_empty"),
			BODY_FONT_SIZE,
			dr.x,
			dr.heading.y,
			text_z,
			dr.w,
			dr.heading.h,
			COLOR.NOTE_TEXT
		)
		return
	end

	d:text_left_fit(
		details.label,
		HEADING_FONT_SIZE,
		dr.x,
		dr.heading.y,
		text_z,
		dr.w,
		dr.heading.h,
		COLOR.TITLE_TEXT,
		HEADING_FONT,
		nil,
		0
	)

	d:text(
		details.summary,
		BODY_FONT_SIZE,
		dr.summary.x,
		dr.summary.y,
		text_z,
		dr.summary.w,
		dr.summary.h,
		COLOR.ROW_TEXT,
		nil,
		false,
		{ "top", "left" }
	)

	local line = 0
	local function meta_line(text, color)
		local y = dr.meta.y + line * LINE_H
		if text and y + LINE_H <= dr.meta.y + dr.meta.h then
			d:text_left(text, BODY_FONT_SIZE, dr.meta.x, y, text_z, dr.meta.w, LINE_H, color or COLOR.NOTE_TEXT)
			line = line + 1
		end
	end
	meta_line(details.tags_line)
	meta_line(details.nodes_line)
	meta_line(details.sources_line)

	meta_line(details.requires_line, details.requires_missing and COLOR.WARN_TEXT or nil)
	meta_line(details.saved_line)

	if #dr.bind_slots > 0 then
		d:text_left(
			mod:localize("lib_read_from"),
			BODY_FONT_SIZE,
			dr.bind_label.x,
			dr.bind_label.y,
			text_z,
			dr.bind_label.w,
			dr.bind_label.h,
			COLOR.ROW_TEXT
		)
		for i = 1, #dr.bind_slots do
			local r = dr.bind_slots[i]
			local slot = details.bind_options[i]
			local active = ctx.bind_to == slot
			Button.draw(d, "lib_bind_" .. i, r.x, r.y, body_z, r.w, r.h, "P" .. i, {
				color = active and COLOR.ROW_SELECTED or nil,
				on_click = function()
					ctx.on_bind(slot)
				end,
			})
		end
	end

	d:text_left(
		mod:localize("field_label_name"),
		BODY_FONT_SIZE,
		dr.rename_label.x,
		dr.rename_label.y,
		text_z,
		dr.rename_label.w,
		dr.rename_label.h,
		COLOR.ROW_TEXT
	)
	TextInput.draw(d, ctx.rename_ctrl, dr.rename, ctx.rename_focused, ctx.rename_hovered, body_z)

	local add_face = details.is_folder and mod:localize("lib_add_folder_to_canvas")
		or mod:localize("lib_add_to_canvas")
	Button.draw(d, "lib_add", dr.add.x, dr.add.y, body_z, dr.add.w, dr.add.h, add_face, {
		disabled = not ctx.can_add,
		on_click = ctx.on_add,
	})

	if details.update_count and details.update_count > 0 then
		local update_face = mod:localize("lib_update_to_current", details.update_count)
		Button.draw(d, "lib_update", dr.update.x, dr.update.y, body_z, dr.update.w, dr.update.h, update_face, {
			on_click = ctx.on_update,
		})
	end

	if details.origin == "user" then

		local del_face = details.is_folder and mod:localize("lib_delete_folder") or mod:localize("lib_delete")
		local confirm_parts = Dropdown.parts(dr.confirm.x, dr.confirm.y, dr.confirm.w, dr.confirm.h)
		Dropdown.draw(d, ctx.confirm_ctrl, confirm_parts, ctx.confirm_open, ctx.confirm_hovered, body_z)
		Button.draw(d, "lib_delete", dr.delete.x, dr.delete.y, body_z, dr.delete.w, dr.delete.h, del_face, {
			disabled = not ctx.confirm_armed,
			on_click = ctx.on_delete,
		})
		if ctx.confirm_open then

			Dropdown.draw_popup(
				d,
				dr.confirm,
				Dropdown.options(ctx.confirm_ctrl),
				ctx.confirm_hover_index,
				z + POPUP_Z_OFFSET,
				0,
				nil,
				Dropdown.selected_index(Dropdown.options(ctx.confirm_ctrl), ctx.confirm_ctrl.get())
			)
		end
	end
end

mod.block_library_panel_component = BlockLibraryPanel

return BlockLibraryPanel
