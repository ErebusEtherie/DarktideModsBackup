local mod = get_mod("cooldown_analysis")
local Missions = mod:original_require("scripts/settings/mission/mission_templates")

local function localize_mission(id)
    local mission_settings = Missions[id]
    if mission_settings then
        return Localize(mission_settings.mission_name)
    else
        return nil
    end
end

mod.lib_missions = {
    localize_name = localize_mission,
}
