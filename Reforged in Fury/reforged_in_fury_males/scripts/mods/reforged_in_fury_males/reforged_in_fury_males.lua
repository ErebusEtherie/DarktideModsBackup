local mod = get_mod("reforged_in_fury_males")

-- Voice tables
local banisher_events_a = {
    "loc_zealot_male_a__ability_banisher_01",
    "loc_zealot_male_a__ability_banisher_02",
    "loc_zealot_male_a__ability_banisher_03",
    "loc_zealot_male_a__ability_banisher_04",
    "loc_zealot_male_a__ability_banisher_05",
    "loc_zealot_male_a__ability_banisher_06",
    "loc_zealot_male_a__ability_banisher_07",
    "loc_zealot_male_a__ability_banisher_08",
    "loc_zealot_male_a__ability_banisher_09",
    "loc_zealot_male_a__ability_banisher_10",
}

local banisher_impact_events_a = {
    "loc_zealot_male_a__ability_banisher_impact_01",
    "loc_zealot_male_a__ability_banisher_impact_02",
    "loc_zealot_male_a__ability_banisher_impact_03",
    "loc_zealot_male_a__ability_banisher_impact_04",
    "loc_zealot_male_a__ability_banisher_impact_05",
    "loc_zealot_male_a__ability_banisher_impact_06",
    "loc_zealot_male_a__ability_banisher_impact_07",
    "loc_zealot_male_a__ability_banisher_impact_08",
    "loc_zealot_male_a__ability_banisher_impact_09",
    "loc_zealot_male_a__ability_banisher_impact_10",
}

local maniac_events_a = {
    "loc_zealot_male_a__ability_maniac_01",
    "loc_zealot_male_a__ability_maniac_02",
    "loc_zealot_male_a__ability_maniac_03",
    "loc_zealot_male_a__ability_maniac_04",
    "loc_zealot_male_a__ability_maniac_05",
    "loc_zealot_male_a__ability_maniac_06",
    "loc_zealot_male_a__ability_maniac_07",
    "loc_zealot_male_a__ability_maniac_08",
    "loc_zealot_male_a__ability_maniac_09",
    "loc_zealot_male_a__ability_maniac_10",
    "loc_zealot_male_a__ability_maniac_11",
    "loc_zealot_male_a__ability_maniac_12",
    "loc_zealot_male_a__ability_maniac_13",
    "loc_zealot_male_a__ability_maniac_14",
    "loc_zealot_male_a__ability_maniac_15",
}

local banisher_events_b = {
    "loc_zealot_male_b__ability_banisher_01",
    "loc_zealot_male_b__ability_banisher_02",
    "loc_zealot_male_b__ability_banisher_03",
    "loc_zealot_male_b__ability_banisher_04",
    "loc_zealot_male_b__ability_banisher_05",
    "loc_zealot_male_b__ability_banisher_06",
    "loc_zealot_male_b__ability_banisher_07",
    "loc_zealot_male_b__ability_banisher_08",
    "loc_zealot_male_b__ability_banisher_09",
    "loc_zealot_male_b__ability_banisher_10",
}

local banisher_impact_events_b = {
    "loc_zealot_male_b__ability_banisher_impact_01",
    "loc_zealot_male_b__ability_banisher_impact_02",
    "loc_zealot_male_b__ability_banisher_impact_03",
    "loc_zealot_male_b__ability_banisher_impact_04",
    "loc_zealot_male_b__ability_banisher_impact_05",
    "loc_zealot_male_b__ability_banisher_impact_06",
    "loc_zealot_male_b__ability_banisher_impact_07",
    "loc_zealot_male_b__ability_banisher_impact_08",
    "loc_zealot_male_b__ability_banisher_impact_09",
    "loc_zealot_male_b__ability_banisher_impact_10",
}

local maniac_events_b = {
    "loc_zealot_male_b__ability_maniac_01",
    "loc_zealot_male_b__ability_maniac_02",
    "loc_zealot_male_b__ability_maniac_03",
    "loc_zealot_male_b__ability_maniac_04",
    "loc_zealot_male_b__ability_maniac_05",
    "loc_zealot_male_b__ability_maniac_06",
    "loc_zealot_male_b__ability_maniac_07",
    "loc_zealot_male_b__ability_maniac_08",
    "loc_zealot_male_b__ability_maniac_09",
    "loc_zealot_male_b__ability_maniac_10",
    "loc_zealot_male_b__ability_maniac_11",
    "loc_zealot_male_b__ability_maniac_12",
    "loc_zealot_male_b__ability_maniac_13",
    "loc_zealot_male_b__ability_maniac_14",
    "loc_zealot_male_b__ability_maniac_15",
}

local banisher_events_c = {
    "loc_zealot_male_c__ability_banisher_01",
    "loc_zealot_male_c__ability_banisher_02",
    "loc_zealot_male_c__ability_banisher_03",
    "loc_zealot_male_c__ability_banisher_04",
    "loc_zealot_male_c__ability_banisher_05",
    "loc_zealot_male_c__ability_banisher_06",
    "loc_zealot_male_c__ability_banisher_07",
    "loc_zealot_male_c__ability_banisher_08",
    "loc_zealot_male_c__ability_banisher_09",
    "loc_zealot_male_c__ability_banisher_10",
}

local banisher_impact_events_c = {
    "loc_zealot_male_c__ability_banisher_impact_01",
    "loc_zealot_male_c__ability_banisher_impact_02",
    "loc_zealot_male_c__ability_banisher_impact_03",
    "loc_zealot_male_c__ability_banisher_impact_04",
    "loc_zealot_male_c__ability_banisher_impact_05",
    "loc_zealot_male_c__ability_banisher_impact_06",
    "loc_zealot_male_c__ability_banisher_impact_07",
    "loc_zealot_male_c__ability_banisher_impact_08",
    "loc_zealot_male_c__ability_banisher_impact_09",
    "loc_zealot_male_c__ability_banisher_impact_10",
}

local maniac_events_c = {
    "loc_zealot_male_c__ability_maniac_01",
    "loc_zealot_male_c__ability_maniac_02",
    "loc_zealot_male_c__ability_maniac_03",
    "loc_zealot_male_c__ability_maniac_04",
    "loc_zealot_male_c__ability_maniac_05",
    "loc_zealot_male_c__ability_maniac_06",
    "loc_zealot_male_c__ability_maniac_07",
    "loc_zealot_male_c__ability_maniac_08",
    "loc_zealot_male_c__ability_maniac_09",
    "loc_zealot_male_c__ability_maniac_10",
    "loc_zealot_male_c__ability_maniac_11",
    "loc_zealot_male_c__ability_maniac_12",
    "loc_zealot_male_c__ability_maniac_13",
    "loc_zealot_male_c__ability_maniac_14",
    "loc_zealot_male_c__ability_maniac_15",
}

-- Unified apply function
local function apply_selected_voice(voice_table, label, banisher_list, banisher_impact_list, maniac_list)
    if not voice_table or not voice_table.ability_maniac then
        mod:echo("Voice table broken for " .. label)
        return
    end

    local new_sound_events = {}

    -- Banisher
    for _, event in ipairs(banisher_list or {}) do
        if mod:get(event) then
            table.insert(new_sound_events, event)
        end
    end

    -- Banisher Impact
    for _, event in ipairs(banisher_impact_list or {}) do
        if mod:get(event) then
            table.insert(new_sound_events, event)
        end
    end

    -- Maniac
    for _, event in ipairs(maniac_list or {}) do
        if mod:get(event) then
            table.insert(new_sound_events, event)
        end
    end

    local ability_maniac = voice_table.ability_maniac
    ability_maniac.sound_events = new_sound_events
    ability_maniac.sound_events_n = #new_sound_events
    ability_maniac.randomize_indexes_n = 0
    ability_maniac.randomize_indexes = {}

    mod:echo(label .. " updated. Total selected: " .. #new_sound_events)
end

local male_a_tbl
local male_b_tbl
local male_c_tbl

-- Hook Male A
mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_a", function(tbl)
    male_a_tbl = tbl
    apply_selected_voice(tbl, "Male Agitator", banisher_events_a, banisher_impact_events_a, maniac_events_a)
end)

-- Hook Male B
mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_b", function(tbl)
    male_b_tbl = tbl
    apply_selected_voice(tbl, "Male Fanatic", banisher_events_b, banisher_impact_events_b, maniac_events_b)
end)

-- Hook Male C
mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_c", function(tbl)
    male_c_tbl = tbl
    apply_selected_voice(tbl, "Male Judge", banisher_events_c, banisher_impact_events_c, maniac_events_c)
end)

-- Centralized setting change handling
mod.on_setting_changed = function(setting)
    if setting:find("loc_zealot_male_a_") and male_a_tbl then
        apply_selected_voice(male_a_tbl, "Male Agitator", banisher_events_a, banisher_impact_events_a, maniac_events_a)
    elseif setting:find("loc_zealot_male_b_") and male_b_tbl then
        apply_selected_voice(male_b_tbl, "Male Fanatic", banisher_events_b, banisher_impact_events_b, maniac_events_b)
    elseif setting:find("loc_zealot_male_c_") and male_c_tbl then
        apply_selected_voice(male_c_tbl, "Male Judge", banisher_events_c, banisher_impact_events_c, maniac_events_c)
    end
end

--[[local male_agitator = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_a")
local male_fanatic = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_b")
local male_judge = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_c")

local banisher_events_a = male_agitator.banisher_events_a
local banisher_impact_events_a = male_agitator.banisher_impact_events_a
local maniac_events_a = male_agitator.maniac_events_a

local banisher_events_b = male_fanatic.banisher_events_b
local banisher_impact_events_b = male_fanatic.banisher_impact_events_b
local maniac_events_b = male_fanatic.maniac_events_b

local banisher_events_c = male_judge.banisher_events_c
local banisher_impact_events_c = male_judge.banisher_impact_events_c
local maniac_events_c = male_judge.maniac_events_c]]--