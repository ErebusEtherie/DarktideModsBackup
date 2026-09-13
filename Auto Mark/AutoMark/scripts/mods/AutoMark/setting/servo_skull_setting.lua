---@class AutoMarkMod:DMFMod
local mod                               = get_mod("AutoMark")
local noospheric_command_breed_settings = mod.noospheric_command_breed_settings

local SERVO_SKULL_BREED_SETTING_IDS     = {
    noospheric_command_boost_breed_override = true,
    servo_skull_range_limitation_breed = true,
    noospheric_command_boost_breed_toggle = true,
    capacitance_retention_breed_threshold = true,
    servo_skull_mark_sticky_targeting_breed = true,
    servo_skull_cancel_mark_breed_time_threshold = true,
    servo_skull_cancel_mark_breed_health_threshold = true,
}

function mod:is_servo_skull_breed_setting_id(setting_id)
    return SERVO_SKULL_BREED_SETTING_IDS[setting_id]
end

function mod:set_menu_servo_skull_breed_settings(breed_name)
    local breed_settings = noospheric_command_breed_settings[breed_name]
    mod:set("noospheric_command_boost_breed_override", breed_settings and breed_settings.override or false, false)
    mod:set("servo_skull_range_limitation_breed", breed_settings and breed_settings.range_limitation or 0, false)
    mod:set("noospheric_command_boost_breed_toggle", breed_settings and breed_settings.toggle or false, false)
    mod:set("capacitance_retention_breed_threshold", (breed_settings and breed_settings.threshold or 0) * 100, false)
    mod:set("servo_skull_mark_sticky_targeting_breed", breed_settings and breed_settings.sticky_targeting or false, false)
    mod:set("servo_skull_cancel_mark_breed_time_threshold", breed_settings and breed_settings.time_threshold or 0, false)
    mod:set("servo_skull_cancel_mark_breed_health_threshold", (breed_settings and breed_settings.health_threshold or 0) * 100, false)
end

function mod:set_servo_skull_breed_setting(breed_name, setting_id, value)
    if noospheric_command_breed_settings[breed_name] == nil then
        noospheric_command_breed_settings[breed_name] = { override = false, range_limitation = 0, toggle = false, threshold = 0, threshold_negative_zero = false, sticky_targeting = false, time_threshold = 0, health_threshold = 0 }
    end
    if setting_id == "noospheric_command_boost_breed_override" then
        noospheric_command_breed_settings[breed_name].override = value
    elseif setting_id == "servo_skull_range_limitation_breed" then
        noospheric_command_breed_settings[breed_name].range_limitation = value
    elseif setting_id == "noospheric_command_boost_breed_toggle" then
        noospheric_command_breed_settings[breed_name].toggle = value
    elseif setting_id == "capacitance_retention_breed_threshold" then
        noospheric_command_breed_settings[breed_name].threshold = value / 100
        if value == -0 and 1 / value < 0 then
            noospheric_command_breed_settings[breed_name].threshold_negative_zero = true
        else
            noospheric_command_breed_settings[breed_name].threshold_negative_zero = false
        end
    elseif setting_id == "servo_skull_mark_sticky_targeting_breed" then
        noospheric_command_breed_settings[breed_name].sticky_targeting = value
    elseif setting_id == "servo_skull_cancel_mark_breed_time_threshold" then
        noospheric_command_breed_settings[breed_name].time_threshold = value
    elseif setting_id == "servo_skull_cancel_mark_breed_health_threshold" then
        noospheric_command_breed_settings[breed_name].health_threshold = value / 100
    end
    mod:set("noospheric_command_breed_settings", noospheric_command_breed_settings, false)
end

mod.reset_all_servo_skull_breed_settings = function()
    table.clear(noospheric_command_breed_settings)
    mod:set("noospheric_command_breed_settings", noospheric_command_breed_settings, false)
    mod:set("noospheric_command_boost_breed_name", mod:get("noospheric_command_boost_breed_name"), true)
end
