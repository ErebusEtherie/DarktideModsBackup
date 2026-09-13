---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_color then
	return mod.hud_studio_color
end

local Color = {}

function Color.rgba(value)
	if type(value) ~= "table" then
		return nil
	end
	for i = 1, 4 do
		if type(value[i]) ~= "number" then
			return nil
		end
	end
	return value
end

mod.hud_studio_color = Color
return Color
