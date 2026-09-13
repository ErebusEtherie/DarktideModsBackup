
local mod = get_mod("hud_studio")

if mod.hud_studio_browser_controller then
	return mod.hud_studio_browser_controller
end

local MaterialBrowser =
mod:core(mod.hud_studio_material_browser, "hud/editor/elements/material_browser/material_browser")
local BrowserPanel =
	mod:core(mod.browser_panel_component, "hud/editor/elements/material_browser/material_browser_panel")
local BrowserLoader = mod:core(mod.hud_studio_browser_loader, "assets/browser_loader")
local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")
local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local DragController = mod:core(mod.hud_studio_drag_controller, "hud/editor/input/drag_controller")

local in_rect = Geometry.in_rect

---@class MaterialBrowserCategory
---@field id string        the category id, also its localization key
---@field label string     localized caption for the button
---@field mats string[]    material paths, in grid order

---@class MaterialBrowserState
---@field cat integer         index into the category array
---@field scroll_row integer  grid rows scrolled off the top
---@field scroll_accum number fractional wheel delta not yet worth a whole row

---@class MaterialBrowserHover
---@field close boolean?   the title bar's close (x) button
---@field cat integer?     index of the hovered category button
---@field slot integer?    index of the hovered grid slot

---@class MaterialBrowserCtx
---@field state MaterialBrowserState?      nil when the browser is closed
---@field cats MaterialBrowserCategory[]   every category, in column order
---@field panel table              the floating panel box { id, title, x, y, w }
---@field lay BrowserLayout?       this frame's geometry, nil before the first layout
---@field hover MaterialBrowserHover       reset by interact each pass, read by draw
---@field node Node?               the selected node, whose `material` the grid assigns to
---@field drag table?              the editor's live drag, to spot a title-drag of this panel
---@field close fun()              close the panel and release its preview packages
---@field assign fun(material: string)  write the material onto the selected node and persist
---@field begin_drag fun(cx: number, cy: number)  arm a title-bar drag from the press position

---@class MaterialBrowserController
local BrowserController = {}

---@param ctx MaterialBrowserCtx
---@return MaterialBrowserCategory|nil
function BrowserController.cur_cat(ctx)
	return ctx.state and ctx.cats[ctx.state.cat]
end

---@param cats MaterialBrowserCategory[]
---@param material string|nil   the node's current material; any non-string is treated as unset
---@return integer|nil
function BrowserController.cat_index_of(cats, material)
	if type(material) ~= "string" or material == "" then
		return nil
	end
	for i = 1, #cats do
		local mats = cats[i].mats
		for j = 1, #mats do
			if mats[j] == material then
				return i
			end
		end
	end
	return nil
end

---@param ctx MaterialBrowserCtx
---@return BrowserLayout|nil  nil when the browser is shut or its category has gone away
function BrowserController.layout(ctx)
	if not ctx.state then
		return nil
	end
	local cat = BrowserController.cur_cat(ctx)
	if not cat then
		return nil
	end
	local panel = ctx.panel
	local lay = MaterialBrowser.layout(panel.x, panel.y, panel.w, #ctx.cats)
	lay.n_mats = #cat.mats
	lay.max_scroll = MaterialBrowser.max_scroll(lay.n_mats, lay.grid.visible_rows)
	if ctx.state.scroll_row > lay.max_scroll then
		ctx.state.scroll_row = lay.max_scroll
	end
	return lay
end

---@param ctx MaterialBrowserCtx
---@param material string|nil  the node's current material, or nil when it has none
---@return MaterialBrowserState
function BrowserController.open(ctx, material)
	local ci = BrowserController.cat_index_of(ctx.cats, material) or 1
	local cat = ctx.cats[ci]
	BrowserLoader.load_set(cat and cat.mats or {})
	return { cat = ci, scroll_row = 0, scroll_accum = 0 }
end

---@param ctx MaterialBrowserCtx
function BrowserController.close(ctx)
	BrowserController.clear_hover(ctx)
	BrowserLoader.release_all()
end

---@param ctx MaterialBrowserCtx
function BrowserController.clear_hover(ctx)
	local hover = ctx.hover
	hover.close = nil
	hover.cat = nil
	hover.slot = nil
end

---@param ctx MaterialBrowserCtx
---@param ci integer  index of the category to open
function BrowserController.select_cat(ctx, ci)
	local state = ctx.state
	if not state or state.cat == ci then
		return
	end

	local cat = ctx.cats[ci]
	BrowserLoader.load_set(cat and cat.mats or {})
	state.cat = ci
	state.scroll_row = 0
	state.scroll_accum = 0
end

---@param ctx MaterialBrowserCtx
---@param view_input table?  the input service to read "scroll_axis" from
function BrowserController.handle_scroll(ctx, view_input)
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

---@param ctx MaterialBrowserCtx
---@param cx number   cursor x, design px
---@param cy number   cursor y, design px
---@param pressed boolean  this frame saw the press, rather than just a hover
---@return boolean consumed
function BrowserController.interact(ctx, cx, cy, pressed)
	local lay, state = ctx.lay, ctx.state
	if not lay then
		return false
	end
	BrowserController.clear_hover(ctx)

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
				BrowserController.select_cat(ctx, i)
			end
			return true
		end
	end

	local cat = BrowserController.cur_cat(ctx)
	local base = state.scroll_row * lay.grid.cols
	for s = 1, #lay.grid.slots do
		local mat = cat and cat.mats[base + s]
		if mat and in_rect(cx, cy, lay.grid.slots[s]) then
			ctx.hover.slot = s
			if pressed then
				ctx.assign(mat)
			end
			return true
		end
	end

	if in_rect(cx, cy, lay.frame) then

		if pressed then
			TextField.commit()
		end
		return true
	end
	return false
end

---@param node Node
---@param material string
---@param field string|nil the value slot to fill; defaults to the primary `material`
function BrowserController.assign(node, material, field)
	node.values = node.values or {}
	node.values[field or "material"] = material
	MaterialDeps.require(material)
end

---@param d Draw
---@param ctx MaterialBrowserCtx
---@param z number
function BrowserController.draw(d, ctx, z)
	local lay, state = ctx.lay, ctx.state
	if not lay or not state then
		return
	end

	local cat = BrowserController.cur_cat(ctx)
	local title =
		mod:localize("panel_texture_browser_title_dynamic", (cat and cat.label) or "?", (cat and #cat.mats) or 0)
	local node = ctx.node
	local cur_mat = node and node.values and node.values.material
	local dragging = DragController.is_panel_drag(ctx.drag, ctx.panel)

	BrowserPanel.draw(d, ctx.panel, z, lay, dragging, {
		title = title,
		close_hover = ctx.hover.close,
		cats = ctx.cats,
		cat = cat,
		cat_index = state.cat,
		cur_material = cur_mat,
		hover_cat = ctx.hover.cat,
		hover_slot = ctx.hover.slot,
		scroll_row = state.scroll_row,
	})
end

mod.hud_studio_browser_controller = BrowserController

return BrowserController
