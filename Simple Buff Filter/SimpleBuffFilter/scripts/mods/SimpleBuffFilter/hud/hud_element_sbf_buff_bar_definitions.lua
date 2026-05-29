-- File: scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar_definitions.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

local VanillaDefs = require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions")

-- Return a deep clone so the new HUD elements do not share memory references with the vanilla bar
return table.clone(VanillaDefs)
