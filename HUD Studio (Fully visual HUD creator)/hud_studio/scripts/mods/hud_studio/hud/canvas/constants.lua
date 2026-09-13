---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.canvas_constants then
	return mod.canvas_constants
end

local Constants = {

	CLASS_NAME = "HudCanvas",

	VISIBILITY_GROUPS = { "alive", "dead", "communication_wheel" },
}

mod.canvas_constants = Constants

return Constants
