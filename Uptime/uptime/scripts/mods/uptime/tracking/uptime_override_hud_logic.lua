local mod = get_mod("uptime")
--[[
The HUD only keeps track of a certain number of buffs. Any buff beyond that is simply ignored.
This includes buff that are not currently shown (e.g. because they have zero stacks). So this limit is reached
quite quickly, which causes important buffs (e.g. many keystones) to not show up.
]]
mod:hook_require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_settings", function(settings)
    settings.max_buffs = 40
end)