
local mod = get_mod("hud_studio")

if mod.panel_body_component then
	return mod.panel_body_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local COLOR = {
	BODY = { 255, 84, 84, 84 }, 
}

local TITLE_H = C.PANEL.TITLE_H

local add_w, add_h = 7, 7
local shadow_material = "content/ui/materials/frames/dropshadow_heavy"

local PanelBody = {}

function PanelBody.draw(d, panel, height, z, opts)
	opts = opts or {}

	if MaterialDeps.ready_to_draw(shadow_material) then
		d:texture(
			shadow_material,
			panel.x - add_w,
			panel.y - add_h,
			z,
			panel.w + (add_w * 2),
			height + (add_h * 2),
			Color.black(80, true)
		)
	end

	local top_gap = opts.full and 0 or TITLE_H
	d:rect(panel.x, panel.y + top_gap, z, panel.w, height - top_gap, opts.color or COLOR.BODY)
end

mod.panel_body_component = PanelBody

return PanelBody
