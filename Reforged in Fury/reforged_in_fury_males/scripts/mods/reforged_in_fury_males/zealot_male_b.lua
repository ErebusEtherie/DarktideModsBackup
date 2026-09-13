local mod = get_mod("reforged_in_fury_males")

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

local sound_durations_b = {
    -- Banisher
    2.295417, 2.041896, 4.004063, 3.237021, 4.500417, 3.951917, 3.764521, 3.690583, 3.517417, 3.641417,
    -- Banisher Impact
    2.058458, 1.825188, 3.572021, 1.986438, 1.953021, 1.530271, 1.36025, 1.413771, 0.813104, 0.850813,
    -- Maniac
    2.466708, 2.538396, 2.890563, 2.132938, 1.577604, 1.815271, 2.028563, 5.450229, 1.856542, 1.658521, 
    2.345313, 3.104729, 2.292292, 3.091, 3.235813,
}

local event_durations = {}
for i, event in ipairs(banisher_events_b) do event_durations[event] = sound_durations_b[i] end
for i, event in ipairs(banisher_impact_events_b) do event_durations[event] = sound_durations_b[i + #banisher_events_b] end
for i, event in ipairs(maniac_events_b) do event_durations[event] = sound_durations_b[i + #banisher_events_b + #banisher_impact_events_b] end

mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_b", function(gameplay_vo_zealot_male_b)
    if not gameplay_vo_zealot_male_b then
        --mod:echo("Failed to hook gameplay_vo_zealot_male_b: file is nil")
        return
    end

    local function apply_selected_voice()
        local ability_maniac = gameplay_vo_zealot_male_b.ability_maniac
        if not ability_maniac then
            --mod:echo("ability_maniac is missing in gameplay_vo_zealot_male_b!")
            return
        end

        local new_sound_events = {}
        local new_sound_durations = {}

        for i, event in ipairs(banisher_events_b) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(banisher_impact_events_b) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(maniac_events_b) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        if #new_sound_events == 0 then
            for i, event in ipairs(maniac_events_b) do
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        ability_maniac.sound_events = new_sound_events
        ability_maniac.sound_events_n = #new_sound_events
        ability_maniac.sound_events_duration = new_sound_durations
        ability_maniac.randomize_indexes_n = 0
        ability_maniac.randomize_indexes = {}

    end

    apply_selected_voice()

    mod.on_setting_changed = function(setting_id)
        if string.find(setting_id, "loc_zealot_male_b_") then
            apply_selected_voice()
        end
    end
end)

return {
    banisher_events = banisher_events_b,
    banisher_impact_events = banisher_impact_events_b,
    maniac_events = maniac_events_b,
}