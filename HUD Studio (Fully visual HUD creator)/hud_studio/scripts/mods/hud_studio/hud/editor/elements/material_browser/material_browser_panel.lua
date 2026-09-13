
local mod = get_mod("hud_studio")

if mod.browser_panel_component then
	return mod.browser_panel_component
end

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local BrowserLoader = mod:core(mod.hud_studio_browser_loader, "assets/browser_loader")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Pixel = mod:core(mod.hud_studio_pixel, "blocks/pixel")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local LABEL_FONT_SIZE = 15

local BROWSER_TINT = { 255, 255, 255, 255 }

local COLOR = {
	ROW_SELECTED = C.COLOR.ROW_SELECTED, 
	ROW_TEXT = C.COLOR.ROW_TEXT,
	CTRL_BG = C.COLOR.CTRL_BG, 
	CTRL_BG_HOVER = C.COLOR.CTRL_BG_HOVER,
	CTRL_BORDER = C.COLOR.CTRL_BORDER, 
	THUMB_BG = { 235, 10, 10, 14 }, 
	SWATCH_BG = { 50, 130, 130, 138 }, 
	SLOT_SELECTED = { 255, 120, 180, 255 }, 
	SLOT_HOVER = C.COLOR.TITLE_TEXT, 
	SCROLL_THUMB = C.COLOR.SCROLL_THUMB, 
}

local BrowserPanel = {}

function BrowserPanel.draw(d, panel, z, lay, dragging, ctx)
	PanelBody.draw(d, panel, lay.frame.h, z)
	PanelHeader.draw(d, panel, z, dragging, {
		title = ctx.title,
		close = { hover = ctx.close_hover },
	})

	local body_z = z + 1

	for i = 1, #lay.cats do
		local r = lay.cats[i]
		local active = ctx.cat_index == i
		local hovered = ctx.hover_cat == i
		local bg = active and COLOR.ROW_SELECTED or (hovered and COLOR.CTRL_BG_HOVER or COLOR.CTRL_BG)
		d:rect(r.x, r.y, body_z, r.w, r.h, bg)
		d:text_left(ctx.cats[i].label, LABEL_FONT_SIZE, r.x + 6, r.y, z + 2, r.w - 12, r.h, COLOR.ROW_TEXT)
		d:field_outline(r.x, r.y, r.w + r.x, r.h + r.y, body_z)
	end

	local cat = ctx.cat
	local cur_mat = ctx.cur_material
	local base = ctx.scroll_row * lay.grid.cols
	for s = 1, #lay.grid.slots do
		local r = lay.grid.slots[s]
		local mat = cat and cat.mats[base + s]
		if mat then
			d:rect(r.x, r.y, body_z, r.w, r.h, COLOR.THUMB_BG)
			if BrowserLoader.is_available(mat) then

				local thumb_x, thumb_y, thumb_w, thumb_h = Pixel.rect(r.x + 2, r.y + 2, r.w - 4, r.h - 4)

				if
					not pcall(
						UIRenderer.draw_texture,
						d.ui_renderer,
						mat,
						Vector3(thumb_x, thumb_y, z + 2),
						Vector2(thumb_w, thumb_h),
						BROWSER_TINT
					)
				then
					d:rect(r.x, r.y, z + 2, r.w, r.h, COLOR.SWATCH_BG)
				else

					BrowserLoader.pin_material(mat)
				end
			else

				d:rect(r.x, r.y, z + 2, r.w, r.h, COLOR.SWATCH_BG)
			end
			local selected = type(cur_mat) == "string" and cur_mat == mat
			local hovered = ctx.hover_slot == s
			local border = selected and COLOR.SLOT_SELECTED or (hovered and COLOR.SLOT_HOVER or COLOR.CTRL_BORDER)
			d:outline(r.x, r.y, r.x + r.w, r.y + r.h, z + 3, border)
		end
	end

	if lay.max_scroll and lay.max_scroll > 0 then
		local sb = lay.scrollbar
		d:rect(sb.x, sb.y, body_z, sb.w, sb.h, COLOR.CTRL_BG)
		local total_rows = math.ceil(lay.n_mats / lay.grid.cols)
		local thumb_h = math.max(24, sb.h * lay.grid.visible_rows / total_rows)
		local frac = ctx.scroll_row / lay.max_scroll
		d:rect(sb.x, sb.y + (sb.h - thumb_h) * frac, z + 2, sb.w, thumb_h, COLOR.SCROLL_THUMB)
	end
end

mod.browser_panel_component = BrowserPanel

return BrowserPanel
