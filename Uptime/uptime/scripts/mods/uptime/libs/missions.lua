local mod = get_mod("uptime")
local Missions = mod:original_require("scripts/settings/mission/mission_templates")
local Danger = mod:original_require("scripts/settings/difficulty/danger_settings")
local Circumstance = mod:original_require("scripts/settings/circumstance/circumstance_templates")

function localize_mission(id)
    local mission_settings = Missions[id]
    if mission_settings then
        return Localize(mission_settings.mission_name)
    else
        return nil
    end
end

function localize_difficulty(difficulty)
    local danger = Danger[tonumber(difficulty)]
    if danger then
        return Localize(danger.display_name)
    else
        return nil
    end
end

function localize_modifier(modifier)
    local circumstance = Circumstance[modifier]
    if circumstance and circumstance.ui then
        return Localize(circumstance.ui.display_name)
    else
        return nil
    end
end

mod.lib.missions = {
    localize_name = localize_mission,
    localize_difficulty = localize_difficulty,
    localize_modifier = localize_modifier,
}