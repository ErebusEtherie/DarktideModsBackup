
local mod = get_mod("hud_studio")

if mod.hud_studio_threshold_bar_component then
	return mod.hud_studio_threshold_bar_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Thresholds = mod:core(mod.hud_studio_thresholds, "blocks/thresholds")

local COLOR = {
	BORDER = C.COLOR.CTRL_BORDER,
}

local ThresholdBar = {}

function ThresholdBar.parts(x, y, w, h)
	return { box = { x = x, y = y, w = w, h = h } }
end

function ThresholdBar.draw(d, list, box, z, scale)
	local bands = Thresholds.bands(list, nil, scale)
	for i = 1, #bands do
		local b = bands[i]
		local bx = box.x + box.w * (b.lo / 100)
		local bw = box.w * ((b.hi - b.lo) / 100)
		d:rect(bx, box.y, z, bw, box.h, b.color)
	end
	d:outline(box.x, box.y, box.x + box.w, box.y + box.h, z + 1, COLOR.BORDER)
end

mod.hud_studio_threshold_bar_component = ThresholdBar

return ThresholdBar
