---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_scale then
	return mod.hud_studio_scale
end

---@class HudScale
local HudScale = {}

local DEFAULT = 100

local MIN_PCT = 0.05

---@return number
function HudScale.pct()
	local ok, data = pcall(function()
		return Managers.save:account_data()
	end)
	local settings = ok and data and data.interface_settings
	local hud_scale = (settings and settings.hud_scale) or DEFAULT
	local p = hud_scale / 100
	if p < MIN_PCT then
		p = MIN_PCT
	end
	return p
end

mod.hud_studio_scale = HudScale

return HudScale
