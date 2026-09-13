---@class AutoMarkMod:DMFMod
local mod                                  = get_mod("AutoMark")
local companion_cancel_mark_breed_settings = mod.companion_cancel_mark_breed_settings

local CYBER_MASTIFF_BREED_SETTING_IDS      = {
    companion_cancel_mark_breed_override = true,
    companion_range_limitation_breed = true,
    companion_mark_max_distance_breed = true,
    companion_mark_sticky_targeting_breed = true,
    companion_cancel_mark_breed_health_threshold = true,
    companion_cancel_mark_breed_time_threshold = true,
    companion_cancel_mark_breed_distance_threshold = true,
}

function mod:is_cyber_mastiff_breed_setting_id(setting_id)
    return CYBER_MASTIFF_BREED_SETTING_IDS[setting_id]
end

function mod:set_menu_cyber_mastiff_breed_settings(breed_name)
    local breed_settings = companion_cancel_mark_breed_settings[breed_name]
    mod:set("companion_cancel_mark_breed_override", breed_settings and breed_settings.override or false, false)
    mod:set("companion_range_limitation_breed", breed_settings and breed_settings.range_limitation or 0, false)
    mod:set("companion_mark_max_distance_breed", breed_settings and breed_settings.max_distance or 0, false)
    mod:set("companion_mark_sticky_targeting_breed", breed_settings and breed_settings.sticky_targeting or false, false)
    mod:set("companion_cancel_mark_breed_health_threshold", (breed_settings and breed_settings.health_threshold or 0) * 100, false)
    mod:set("companion_cancel_mark_breed_time_threshold", breed_settings and breed_settings.time_threshold or 0, false)
    mod:set("companion_cancel_mark_breed_distance_threshold", breed_settings and breed_settings.distance_threshold or 0, false)
end

function mod:set_cyber_mastiff_breed_setting(breed_name, setting_id, value)
    if companion_cancel_mark_breed_settings[breed_name] == nil then
        companion_cancel_mark_breed_settings[breed_name] = { override = false, range_limitation = 0, max_distance = 0, sticky_targeting = false, health_threshold = 0, time_threshold = 0, distance_threshold = 0 }
    end
    if setting_id == "companion_cancel_mark_breed_override" then
        companion_cancel_mark_breed_settings[breed_name].override = value
    elseif setting_id == "companion_range_limitation_breed" then
        companion_cancel_mark_breed_settings[breed_name].range_limitation = value
    elseif setting_id == "companion_mark_max_distance_breed" then
        companion_cancel_mark_breed_settings[breed_name].max_distance = value
    elseif setting_id == "companion_mark_sticky_targeting_breed" then
        companion_cancel_mark_breed_settings[breed_name].sticky_targeting = value
    elseif setting_id == "companion_cancel_mark_breed_health_threshold" then
        companion_cancel_mark_breed_settings[breed_name].health_threshold = value / 100
    elseif setting_id == "companion_cancel_mark_breed_time_threshold" then
        companion_cancel_mark_breed_settings[breed_name].time_threshold = value
    elseif setting_id == "companion_cancel_mark_breed_distance_threshold" then
        companion_cancel_mark_breed_settings[breed_name].distance_threshold = value
    end
    mod:set("companion_cancel_mark_breed_settings", companion_cancel_mark_breed_settings, false)
end

mod.reset_all_cyber_mastiff_breed_settings = function()
    table.clear(companion_cancel_mark_breed_settings)
    mod:set("companion_cancel_mark_breed_settings", companion_cancel_mark_breed_settings, false)
    mod:set("companion_cancel_mark_breed_name", mod:get("companion_cancel_mark_breed_name"), true)
end
