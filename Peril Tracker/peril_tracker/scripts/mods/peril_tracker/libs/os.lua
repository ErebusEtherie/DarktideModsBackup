local mod = get_mod("peril_tracker")
local DMF = get_mod("DMF")

local os = DMF:persistent_table("_peril_os")
os.initialized = os.initialized or false
if not os.initialized then
    os = DMF.deepcopy(Mods.lua.os)
end

mod.lib_os = os
