
local mod = get_mod("hud_studio")

if mod.threshold_designer_panel_component then
	return mod.threshold_designer_panel_component
end

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local ThresholdBar =
	mod:core(mod.hud_studio_threshold_bar_component, "hud/editor/elements/threshold_designer/threshold_bar")
local Label = mod:core(mod.hud_studio_label_component, "hud/editor/elements/field/label")
local Layout = mod:core(mod.hud_studio_threshold_designer, "hud/editor/elements/threshold_designer/threshold_designer")
local C = mod:core(mod.editor_constants, "hud/editor/constants")

local PCT_FONT_SIZE = 13

local COLOR = {
	SUFFIX_TEXT = C.COLOR.CTRL_TEXT_MUTED,
}

local ThresholdDesignerPanel = {}

function ThresholdDesignerPanel.draw(d, panel, z, lay, dragging, ctx)
	PanelBody.draw(d, panel, lay.frame.h, z)
	PanelHeader.draw(d, panel, z, dragging, {
		title = ctx.title,
		close = { hover = ctx.close_hover },
	})

	local body_z = z + 1

	ThresholdBar.draw(d, lay.list, lay.bar, body_z, lay.band_scale)

	local labels = lay.labels
	for i = 1, #labels do
		local l = labels[i]
		if l.group then
			Label.group(d, l.x, l.y, l.w, l.text, body_z + 1)
		else
			Label.field(d, l, l.text, body_z + 1)
		end
	end

	if lay.hint and lay.hint_text then
		Label.note(d, lay.hint, lay.hint_text, body_z + 1)
	end

	local items = lay.items
	for i = 1, #items do
		local it = items[i]
		ctx.draw_field(it, body_z)

		if it.pct then
			local box = it.parts.box
			d:text_left(
				"%",
				PCT_FONT_SIZE,
				box.x + box.w + 4,
				box.y,
				body_z + 1,
				Layout.PCT_SUFFIX_W - 4,
				box.h,
				COLOR.SUFFIX_TEXT
			)
		end
	end
end

mod.threshold_designer_panel_component = ThresholdDesignerPanel

return ThresholdDesignerPanel
