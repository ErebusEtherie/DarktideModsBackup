
local mod = get_mod("hud_studio")

if mod.panel_toolbar_component then
	return mod.panel_toolbar_component
end

local Button = mod:core(mod.hud_studio_button_component, "hud/editor/elements/button/button")
local Icons = mod:core(mod.editor_icons, "hud/editor/elements/icon/editor_icons")

local GEO = {
	HEIGHT = 29, 
	PAD = 6, 
	BTN_W = 40, 
	BTN_GAP = 4, 
	SEP_W = 1, 
	SEP_GAP = 6, 
	ACTION_W = 24, 
	ACTION_GAP = 4, 
}

local COLOR = {
	STRIP = { 255, 83, 83, 83 }, 
	STRIP_LINE = { 255, 60, 60, 60 }, 
	SEP = { 255, 60, 60, 60 }, 
	FACE = { 5, 255, 255, 255 }, 
	ACTION_FACE = { 255, 69, 69, 69 }, 
	TEXT = { 255, 232, 232, 232 },
	TEXT_DISABLED = { 150, 232, 232, 232 },
}

local PLUS = mod.dl.str.rich_text("+", { size = 14 })

local NODE_BUTTONS = {
	{ which = "text", label = PLUS .. "TXT" },
	{ which = "rect", label = PLUS .. "RECT" },
	{ which = "progress_bar", label = PLUS .. "PRG" },
}

local PanelToolbar = {}

PanelToolbar.HEIGHT = GEO.HEIGHT

local function draw_copy(d, x, btn_y, z, disabled, on_copy)
	Button.draw(d, "blk_copy", x, btn_y, z + 1, GEO.ACTION_W, GEO.ACTION_W, "", {
		color = COLOR.ACTION_FACE,
		disabled = disabled,
		disabled_color = COLOR.ACTION_FACE,
		tooltip = mod:localize("copy_selection_tooltip"),
		on_click = on_copy,
	})

	Icons.draw_copy_icon(d, x, btn_y, z, disabled, nil, COLOR.ACTION_FACE)
end

local function draw_delete(d, x, btn_y, z, disabled, on_delete)
	Button.draw(d, "blk_delete", x, btn_y, z + 1, GEO.ACTION_W, GEO.ACTION_W, "", {
		color = COLOR.ACTION_FACE,
		disabled = disabled,
		disabled_color = COLOR.ACTION_FACE,
		tooltip = mod:localize("delete_selection_tooltip"),
		on_click = on_delete,
	})

	Icons.draw_trash_icon(d, x, btn_y, z, disabled)
end

function PanelToolbar.draw(d, panel, z, toolbar_y, ctx)

	d:rect(panel.x, toolbar_y, z, panel.w, GEO.HEIGHT + GEO.PAD, COLOR.STRIP)
	d:rect(panel.x, toolbar_y, z + 10, panel.w, 1, COLOR.STRIP_LINE)

	local btn_y = toolbar_y + GEO.PAD
	local btn_h = GEO.HEIGHT - GEO.PAD

	local lx = panel.x + GEO.PAD

	Button.draw(d, "blk_add_folder", lx, btn_y, z + 1, GEO.ACTION_W, btn_h, "", {
		color = COLOR.ACTION_FACE,
		tooltip = mod:localize("add_folder_tooltip"),
		on_click = ctx.on_add_folder,
	})

	Icons.draw_add_folder_icon(d, lx, btn_y, z, false)

	lx = lx + GEO.ACTION_W + GEO.SEP_GAP

	d:rect(lx, btn_y, z + 11, GEO.SEP_W, btn_h, COLOR.SEP)
	lx = lx + GEO.SEP_W + GEO.SEP_GAP

	Button.draw(d, "blk_add_block", lx, btn_y, z + 1, GEO.ACTION_W, btn_h, "", {
		color = COLOR.ACTION_FACE,
		tooltip = mod:localize("add_block_tooltip"),
		on_click = ctx.on_add_block,
	})

	Icons.draw_add_block_icon(d, lx, btn_y, z, false)

	lx = lx + GEO.ACTION_W + GEO.SEP_GAP

	d:rect(lx, btn_y, z + 11, GEO.SEP_W, btn_h, COLOR.SEP)
	lx = lx + GEO.SEP_W + GEO.SEP_GAP

	local sel_block = ctx.selected_block
	local node_btn_disabled = sel_block == nil

	for i = 1, #NODE_BUTTONS do
		local b = NODE_BUTTONS[i]
		Button.draw(d, "blk_add_node_" .. b.which, lx, btn_y, z + 1, GEO.ACTION_W, btn_h, "", {
			color = COLOR.ACTION_FACE,
			disabled = node_btn_disabled,
			disabled_color = COLOR.ACTION_FACE,
			tooltip = mod:localize("add_" .. b.which .. "_tooltip"),
			on_click = function()
				ctx.on_add_node(sel_block, b.which)
			end,
		})

		if b.which == "progress_bar" then
			Icons.draw_add_progress_bar_node_icon(d, lx, btn_y, z, node_btn_disabled)
		elseif b.which == "rect" then
			Icons.draw_add_rect_node_icon(d, lx, btn_y, z, node_btn_disabled)
		elseif b.which == "text" then
			Icons.draw_add_text_node_icon(d, lx, btn_y, z, node_btn_disabled)
		end

		lx = lx + GEO.ACTION_W + GEO.BTN_GAP
	end

	local x_delete = panel.x + panel.w - GEO.PAD - GEO.ACTION_W
	local x_copy = x_delete - GEO.ACTION_GAP - GEO.ACTION_W
	draw_copy(d, x_copy, btn_y, z, node_btn_disabled, ctx.on_copy)
	draw_delete(d, x_delete, btn_y, z, node_btn_disabled, ctx.on_delete)
end

mod.panel_toolbar_component = PanelToolbar

return PanelToolbar
