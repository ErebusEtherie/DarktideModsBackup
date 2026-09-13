local mod = get_mod("reforged_in_fury_males")

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

local sound_durations_a = {
    -- Banisher
    2.300917, 2.455333, 2.603688, 2.809521, 3.143458, 3.083333, 3.488042, 3.056063, 2.870583, 3.073083,
    -- Banisher Impact
    2.567, 1.200229, 1.776313, 1.763542, 1.714958, 3.143104, 3.792229, 1.72375, 1.610583, 1.974604,
    -- Maniac
    2.893063, 2.494979, 2.280917, 2.103104, 2.006438, 2.591792, 2.176292, 2.529563, 1.687104, 2.888396, 
    2.479292, 2.381021, 2.534813, 1.967521, 3.007521,
}

local event_durations = {}
for i, event in ipairs(banisher_events_a) do event_durations[event] = sound_durations_a[i] end
for i, event in ipairs(banisher_impact_events_a) do event_durations[event] = sound_durations_a[i + #banisher_events_a] end
for i, event in ipairs(maniac_events_a) do event_durations[event] = sound_durations_a[i + #banisher_events_a + #banisher_impact_events_a] end

mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_a", function(gameplay_vo_zealot_male_a)
    if not gameplay_vo_zealot_male_a then
        --mod:echo("Failed to hook gameplay_vo_zealot_male_a: file is nil")
        return
    end

    local function apply_selected_voice()
        local ability_maniac = gameplay_vo_zealot_male_a.ability_maniac
        if not ability_maniac then
            --mod:echo("ability_maniac is missing in gameplay_vo_zealot_male_a!")
            return
        end

        local new_sound_events = {}
        local new_sound_durations = {}

        for i, event in ipairs(banisher_events_a) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(banisher_impact_events_a) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(maniac_events_a) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        if #new_sound_events == 0 then
            for i, event in ipairs(maniac_events_a) do
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
        if string.find(setting_id, "loc_zealot_male_a_") then
            apply_selected_voice()
        end
    end
end)

return {
    banisher_events = banisher_events_a,
    banisher_impact_events = banisher_impact_events_a,
    maniac_events = maniac_events_a,
}