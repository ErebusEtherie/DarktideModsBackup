-- salvage.lua
local mod = get_mod("salvage")
local exits = Mods.file.dofile("salvage/scripts/mods/salvage/salvage_exits")
local core = Mods.file.dofile("salvage/scripts/mods/salvage/salvage_core")
if type(core) == "function" then
core(mod, exits)
end
