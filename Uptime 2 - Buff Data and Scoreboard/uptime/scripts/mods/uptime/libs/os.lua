-- File: uptime\scripts\mods\uptime\libs\os.lua
local mod = get_mod("uptime"); if not mod then return end
local DMF = get_mod("DMF")

local os = DMF:persistent_table("_os")
os.initialized = os.initialized or false
if not os.initialized then
    os = DMF.deepcopy(Mods.lua.os)
end

mod.lib.os = os
