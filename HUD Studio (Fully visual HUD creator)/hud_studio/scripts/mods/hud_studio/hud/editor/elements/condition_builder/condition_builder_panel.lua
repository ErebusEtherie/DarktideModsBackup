
local mod = get_mod("hud_studio")

if mod.condition_builder_panel_component then
	return mod.condition_builder_panel_component
end

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local Label = mod:core(mod.hud_studio_label_component, "hud/editor/elements/field/label")

local COLOR = {

	PILL_TRUE = { 255, 120, 220, 140 },
	PILL_FALSE = { 255, 60, 62, 70 },

	PILL_UNKNOWN = { 255, 44, 46, 52 },
	WHERE = { 150, 69, 69, 69 },
}

local ConditionBuilderPanel = {}

function ConditionBuilderPanel.draw(d, panel, z, lay, dragging, ctx)
	PanelBody.draw(d, panel, lay.frame.h, z)
	PanelHeader.draw(d, panel, z, dragging, {
		title = ctx.title,
		close = { hover = ctx.close_hover },
	})

	local body_z = z + 1

	local where = lay.rows[1] and lay.rows[1].cells.where
	if where then
		d:rect(where.x, where.y, body_z + 1, where.w, where.h, COLOR.WHERE)
		d:text_center(mod:localize("cb_if"), 14, where.x, where.y, body_z + 2, where.w, where.h, { 150, 220, 220, 220 })
		d:field_outline(where.x, where.y, where.x + where.w, where.y + where.h, body_z + 1)
	end

	local pills = lay.pills
	for i = 1, #pills do
		local pill = pills[i]
		local color = COLOR.PILL_UNKNOWN
		if pill.truth == true then
			color = COLOR.PILL_TRUE
		elseif pill.truth == false then
			color = COLOR.PILL_FALSE
		end
		d:rect(pill.rect.x, pill.rect.y + 4, body_z + 1, pill.rect.w, pill.rect.h - 8, color)
	end

	local labels = lay.labels
	for i = 1, #labels do
		local l = labels[i]
		Label.field(d, l, l.text, body_z + 1)
	end

	local items = lay.items
	for i = 1, #items do
		ctx.draw_field(items[i], body_z)
	end
end

mod.condition_builder_panel_component = ConditionBuilderPanel

return ConditionBuilderPanel
