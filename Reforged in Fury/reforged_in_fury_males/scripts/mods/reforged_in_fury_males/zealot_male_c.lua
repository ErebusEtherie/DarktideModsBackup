local mod = get_mod("reforged_in_fury_males")

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

local sound_durations_c = {
    -- Banisher
    2.475813, 2.845667, 3.167208, 2.931729, 2.814229, 3.651688, 2.564667, 2.744563, 2.326813, 2.92625,
    -- Banisher Impact 
    1.138604, 1.646875, 1.661438, 2.244979, 2.676875, 1.284083, 3.201958, 2.815188, 1.35775, 2.140604,
    -- Maniac
    2.436104, 2.94925, 2.748646, 2.338854, 2.338792, 2.243167, 2.446771, 2.341625, 2.984271, 2.558792, 
    2.278292, 2.536667, 1.773, 2.366292, 2.356708,
}

local event_durations = {}
for i, event in ipairs(banisher_events_c) do event_durations[event] = sound_durations_c[i] end
for i, event in ipairs(banisher_impact_events_c) do event_durations[event] = sound_durations_c[i + #banisher_events_c] end
for i, event in ipairs(maniac_events_c) do event_durations[event] = sound_durations_c[i + #banisher_events_c + #banisher_impact_events_c] end

mod:hook_require("dialogues/generated/gameplay_vo_zealot_male_c", function(gameplay_vo_zealot_male_c)
    if not gameplay_vo_zealot_male_c then
        --mod:echo("Failed to hook gameplay_vo_zealot_male_c: file is nil")
        return
    end

    local function apply_selected_voice()
        local ability_maniac = gameplay_vo_zealot_male_c.ability_maniac
        if not ability_maniac then
            --mod:echo("ability_maniac is missing in gameplay_vo_zealot_male_c!")
            return
        end

        local new_sound_events = {}
        local new_sound_durations = {}

        for i, event in ipairs(banisher_events_c) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(banisher_impact_events_c) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        for i, event in ipairs(maniac_events_c) do
            local setting_id = event
            if mod:get(setting_id) then
                table.insert(new_sound_events, event)
                table.insert(new_sound_durations, event_durations[event])
            end
        end

        if #new_sound_events == 0 then
            for i, event in ipairs(maniac_events_c) do
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
        if string.find(setting_id, "loc_zealot_male_c_") then
            apply_selected_voice()
        end
    end
end)

return {
    banisher_events = banisher_events_c,
    banisher_impact_events = banisher_impact_events_c,
    maniac_events = maniac_events_c,
}