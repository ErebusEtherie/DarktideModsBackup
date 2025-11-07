--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Auto Tag                                                                        │
│ Mod Description: Automatically tags enemies in crosshair, with a cooldown.                |
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]

local mod = get_mod("AutoTag")


local tag = false
local cooldown = 0.0






-- local names = {
--     "cultist_flamer",
--     "renegade_flamer", 
--     "renegade_netgunner",
--     "renegade_sniper",
--     "cultist_grenadier",
--     "renegade_grenadier",
--     "renegade_gunner",
--     "renegade_shocktrooper",
--     "chaos_hound",
--     "chaos_ogryn_executor",
--     "chaos_ogryn_gunner",
--     "chaos_poxwalker_bomber",
--     "cultist_gunner",
--     "cultist_shocktrooper"
-- }

-- local isTarget = function(name)
--     for _, n in ipairs(names) do
--         if n == name then return true end
--     end
--     return false
-- end




local taggedTarget = nil
local manual = false

mod:hook("SmartTag", "destroy", function(f, s, ...)
    if s._tagger_unit == Managers.player:local_player_safe(1).player_unit and taggedTarget == s._target_unit then 
        -- taggedTarget = nil
        if mod:get("refresh") then cooldown = 0 end
        manual = false
    end
    return f(s, ...)
end)


mod:hook_safe("SmartTag", "validate_target_unit", function(target_unit)
    if not Unit.is_valid(target_unit) then return end
    -- if taggedTarget then 
    --     if not HEALTH_ALIVE[taggedTarget] then 
    --         if mod:get("refresh") then cooldown = 0 end
    --         taggedTarget = nil
    --         manual = false
    --     end 
    -- end
    local target_type = Unit.get_data(target_unit, "smart_tag_target_type")
    local unit_data = ScriptUnit.has_extension(target_unit, "unit_data_system")
	local target_breed = unit_data and unit_data:breed()
    local name = target_breed and target_breed.name
    if target_type == "breed" and target_unit ~= taggedTarget and cooldown <= 0 and not manual then
        tag = true
    elseif target_type == "pickup" then
        tag = false
    end
end)

-- mod:hook("SmartTagSystem", "_server_check_tag_group_limit", function(f, s, ...)
-- end)

mod:hook_safe("SmartTag", "init", function(s, tag_id, template, tagger_unit, target_unit, ...)
    if cooldown > 0.5 and not mod:get("manualoverride") then 
        manual = true
    end
    if tagger_unit == Managers.player:local_player_safe(1).player_unit then
        cooldown = mod:get("cd")
        tag = false
        taggedTarget = target_unit
    end
end)

mod:hook("InputService", "_get", function(f, s, action_name)
    if cooldown <= 0 and tag and action_name == "smart_tag" then
        cooldown = 0.05
        return true 
    end
    return f(s, action_name)
end)

function mod.update(dt)
    if cooldown > 0 then cooldown = cooldown - dt end
end