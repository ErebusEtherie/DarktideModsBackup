--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Gas Outlines                                                                    │
│ Mod Description: Fixes bug where outlines don't show up in toxic gas.                     |
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]
local mod = get_mod("GasOutline")

mod:hook("OutlineSystem", "set_global_visibility", function(f, s, visible, ...)
    visible = true
    return f(s, visible, ...)
end)