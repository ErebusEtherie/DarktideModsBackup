-- File: uptime\scripts\mods\uptime\libs\missions.lua
local mod = get_mod("uptime"); if not mod then return end
local Missions = mod:original_require("scripts/settings/mission/mission_templates")
local Danger = mod:original_require("scripts/settings/difficulty/danger_settings")
local Circumstance = mod:original_require("scripts/settings/circumstance/circumstance_templates")

local HAVOC_CIRCUMSTANCE_SEPARATOR = " • "

local function localize_mission(id)
    local mission_settings = Missions[id]
    if mission_settings then
        return Localize(mission_settings.mission_name)
    else
        return nil
    end
end

local function localize_difficulty(difficulty)
    if not difficulty then
        return nil
    end

    local difficulty_number = tonumber(difficulty)
    local danger = difficulty_number and Danger[difficulty_number]

    if danger then
        return Localize(danger.display_name)
    else
        return tostring(difficulty)
    end
end

local function trim_string(value)
    return value and string.gsub(value, "^%s*(.-)%s*$", "%1") or nil
end

local function localize_single_modifier(modifier)
    local circumstance = modifier and Circumstance[modifier]

    if circumstance and circumstance.ui then
        return Localize(circumstance.ui.display_name)
    end

    return nil
end

local function add_localized_modifier(localized_modifiers, modifier)
    modifier = trim_string(modifier)

    if not modifier or modifier == "" then
        return
    end

    local localized_modifier = localize_single_modifier(modifier)

    localized_modifiers[#localized_modifiers + 1] = localized_modifier or modifier
end

local function localize_concatenated_modifiers(modifier)
    local localized_modifiers = {}
    local start_index = 1

    while true do
        local separator_start, separator_end = string.find(modifier, HAVOC_CIRCUMSTANCE_SEPARATOR, start_index, true)

        if not separator_start then
            add_localized_modifier(localized_modifiers, string.sub(modifier, start_index))
            break
        end

        add_localized_modifier(localized_modifiers, string.sub(modifier, start_index, separator_start - 1))
        start_index = separator_end + 1
    end

    if #localized_modifiers > 0 then
        return table.concat(localized_modifiers, HAVOC_CIRCUMSTANCE_SEPARATOR)
    end

    return nil
end

local function localize_modifier(modifier)
    if not modifier then
        return nil
    end

    if string.find(modifier, HAVOC_CIRCUMSTANCE_SEPARATOR, 1, true) then
        return localize_concatenated_modifiers(modifier)
    end

    return localize_single_modifier(modifier)
end

mod.lib.missions = {
    localize_name = localize_mission,
    localize_difficulty = localize_difficulty,
    localize_modifier = localize_modifier,
}
