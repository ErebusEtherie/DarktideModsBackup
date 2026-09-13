---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local function load(name)
	mod:io_dofile("hud_studio/scripts/mods/hud_studio/sources/" .. name)
end

local sources = {
	"players", 
}

for i = 1, #sources do
	load(sources[i])
end
