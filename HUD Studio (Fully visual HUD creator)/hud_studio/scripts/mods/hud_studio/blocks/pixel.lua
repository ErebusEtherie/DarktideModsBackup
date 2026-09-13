---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_pixel then
	return mod.hud_studio_pixel
end

local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")
local floor = math.floor

---@class Pixel
local Pixel = {}

local function render_scale()
	return (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1
end

---@param v number
---@return number
function Pixel.snap(v)
	local scale = render_scale()
	return floor(v * scale + 0.5) / scale
end

---@param x number
---@param y number
---@param w number
---@param h number
---@return number x, number y, number w, number h
function Pixel.rect(x, y, w, h)
	local scale = render_scale()
	local x0 = floor(x * scale + 0.5)
	local y0 = floor(y * scale + 0.5)
	local x1 = floor((x + w) * scale + 0.5)
	local y1 = floor((y + h) * scale + 0.5)
	return x0 / scale, y0 / scale, (x1 - x0) / scale, (y1 - y0) / scale
end

mod.hud_studio_pixel = Pixel

return Pixel
