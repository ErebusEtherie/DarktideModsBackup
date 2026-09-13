
local mod = get_mod("hud_studio")

if mod.panel_top_toolbar_component then
	return mod.panel_top_toolbar_component
end

local Button = mod:core(mod.hud_studio_button_component, "hud/editor/elements/button/button")
local EyeToggle = mod:core(mod.eye_toggle_component, "hud/editor/elements/row/eye_toggle")
local EditorIcons = mod:core(mod.editor_icons, "hud/editor/elements/icon/editor_icons")

local GEO = {
	PAD = 6, 
	ACTION_W = 25, 
}

local HEADING_FONT = mod.dl.fonts.validated("mono_tide_bold")
local HEADING_FONT_SIZE = 14

local COLOR = {
	STRIP = { 255, 83, 83, 83 }, 
	STRIP_LINE = { 150, 60, 60, 60 }, 
	ACTION_FACE = { 255, 69, 69, 69 }, 
}

local mod_name = mod:localize("mod_name")
local mod_ver = mod:localize("mod_ver")

local PanelTopToolbar = {}

PanelTopToolbar.HEIGHT = GEO.ACTION_W + GEO.PAD * 2

function PanelTopToolbar.draw(d, panel, z, toolbar_y, ctx)
	ctx = ctx or {}

	d:rect(panel.x, toolbar_y, z, panel.w, PanelTopToolbar.HEIGHT, COLOR.STRIP)
	d:rect(panel.x, toolbar_y + PanelTopToolbar.HEIGHT - 1, z + 10, panel.w, 1, COLOR.STRIP_LINE)

	local btn_y = toolbar_y + GEO.PAD

	local all_collapsed = ctx.all_collapsed == true
	local collapse_x = panel.x + GEO.PAD
	Button.draw(d, "blk_top_left", collapse_x, btn_y, z + 1, GEO.ACTION_W, GEO.ACTION_W, "", {
		color = COLOR.ACTION_FACE,
		tooltip = all_collapsed and mod:localize("toolbar_expand_all_tooltip")
			or mod:localize("toolbar_collapse_all_tooltip"),
		on_click = ctx.on_collapse_all,
	})
	EditorIcons.draw_collapse_expand_all_blocks(d, collapse_x, btn_y, z + 2, all_collapsed)

	local lib_x = panel.x + GEO.PAD + GEO.ACTION_W + GEO.PAD
	Button.draw(d, "blk_top_library", lib_x, btn_y, z + 1, GEO.ACTION_W, GEO.ACTION_W, "", {
		color = COLOR.ACTION_FACE,
		tooltip = mod:localize("panel_library_title_tooltip"),
		on_click = ctx.on_open_library,
	})
	EditorIcons.draw_library_icon(d, lib_x, btn_y, z + 2)

	local heading_x = lib_x + GEO.ACTION_W + GEO.PAD
	local heading_w = panel.w - (GEO.ACTION_W * 3) - (GEO.PAD * 5)

	d:text_center(
		mod_name .. " " .. mod_ver,
		HEADING_FONT_SIZE,
		heading_x,
		btn_y,
		z + 2,
		heading_w,
		PanelTopToolbar.HEIGHT - (GEO.PAD * 2),
		{ 150, 255, 255, 255 },
		HEADING_FONT
	)

	local hide_hidden = ctx.hide_hidden == true
	local x_right = panel.x + panel.w - GEO.PAD - GEO.ACTION_W
	Button.draw(d, "blk_top_right", x_right, btn_y, z + 1, GEO.ACTION_W, GEO.ACTION_W, "", {
		color = COLOR.ACTION_FACE,
		on_click = ctx.on_hide_hidden and function()
			ctx.on_hide_hidden(not hide_hidden)
		end,
	})

	local eye_inset = math.floor((GEO.ACTION_W - EyeToggle.SIZE) / 2) + 1
	EyeToggle.draw(
		d,
		"toggle_mod_canvas_hidden",
		{
			x = x_right + eye_inset,
			y = btn_y + eye_inset,
			w = EyeToggle.SIZE,
			h = EyeToggle.SIZE,
		},
		z + 6,
		{
			mode = "fixed",
			on = not hide_hidden,

			dynamic = false,
			tooltip = function(on)
				return on and mod:localize("canvas_hide_hidden_tooltip") or mod:localize("canvas_show_hidden_tooltip")
			end,
			on_toggle = ctx.on_hide_hidden and function(next_on)

				ctx.on_hide_hidden(not next_on)
			end,
		}
	)
end

mod.panel_top_toolbar_component = PanelTopToolbar

return PanelTopToolbar
