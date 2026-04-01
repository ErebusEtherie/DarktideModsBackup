-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_npcs.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
local type, string, pairs, table = type, string, pairs, table

local function _minor_voice_match_key(s)
    return mod.strip_variant_suffix(mod.strip_past_prefix(s))
end

local function _expand_wwise_voices(wwise_voices)
    local out = {}
    local out_len = 0
    if type(wwise_voices) ~= "table" then return out end

    local count = #wwise_voices
    for i = 1, count do
        local entry = wwise_voices[i]
        if type(entry) == "string" then
            entry = mod.trim(entry)
            if entry ~= "" then
                if entry:find(",", 1, true) then
                    for token in string.gmatch(entry, "[^,]+") do
                        token = mod.trim(token)
                        if token ~= "" then
                            out_len = out_len + 1
                            out[out_len] = token
                        end
                    end
                else
                    out_len = out_len + 1
                    out[out_len] = entry
                end
            end
        end
    end
    return out
end

local function _canonical_group_key(class_name, entry)
    local key = nil
    if type(entry) == "table" and type(entry.vo_class_name) == "string" and entry.vo_class_name ~= "" then
        key = entry.vo_class_name
    else
        key = mod.strip_variant_suffix(class_name)
    end
    return mod.strip_past_prefix(key)
end

local function _best_voice_for_group(group_key, voices)
    if type(voices) ~= "table" or #voices == 0 then return nil end
    local count = #voices
    local SpeakerVoiceSettings = mod.try_require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

    for i = 1, count do
        local v = voices[i]
        local s = SpeakerVoiceSettings and SpeakerVoiceSettings[v]
        if type(s) == "table" and type(s.full_name) == "string" and s.full_name:find("^loc_") then
            return v
        end
    end

    for i = 1, count do
        local v = voices[i]
        local s = SpeakerVoiceSettings and SpeakerVoiceSettings[v]
        if type(s) == "table" and type(s.short_name) == "string" and s.short_name:find("^loc_") then
            return v
        end
    end

    if type(group_key) == "string" and group_key ~= "" then
        for i = 1, count do
            local v = voices[i]
            if type(v) == "string" and (mod.starts_with(v, group_key .. "_") or v == group_key) then
                return v
            end
        end

        for i = 1, count do
            local v = voices[i]
            if type(v) == "string" and v:find(group_key, 1, true) then
                return v
            end
        end
    end

    return voices[1]
end

local function _register_voice_mapping(map, voice, canonical_key)
    map[voice] = canonical_key
    local stripped = mod.strip_past_prefix(voice)
    map[stripped] = canonical_key
    map["past_" .. stripped] = canonical_key
end

local function _is_player_voice(player_set, voice, stripped_voice)
    return player_set[voice] or player_set[stripped_voice]
end

local function _is_major_voice(major_voice_to_class, major_voice_profile_set, voice, stripped_voice)
    return major_voice_to_class[voice] or major_voice_to_class[stripped_voice] or
        major_voice_profile_set[voice] or major_voice_profile_set[stripped_voice]
end

local function _pick_smaller_minor_group(source_key, source_pool_size, match_key, candidate_pools)
    if type(source_key) ~= "string" or source_key == "" then return source_key end
    if type(match_key) ~= "string" or match_key == "" then return source_key end
    if type(candidate_pools) ~= "table" or source_pool_size == nil then return source_key end

    local best_key = nil
    local best_size = nil
    local best_class_name = nil
    local candidate_count = #candidate_pools

    for i = 1, candidate_count do
        local candidate = candidate_pools[i]
        local candidate_key = candidate and candidate.key
        local candidate_size = candidate and candidate.voice_count
        local candidate_class_name = candidate and candidate.class_name
        local candidate_match_keys = candidate and candidate.match_keys

        if type(candidate_key) == "string" and candidate_key ~= "" and candidate_key ~= source_key and
            type(candidate_size) == "number" and candidate_size > 0 and candidate_size < source_pool_size and
            type(candidate_match_keys) == "table" and candidate_match_keys[match_key]
        then
            local is_better = false

            if not best_key then
                is_better = true
            elseif candidate_size < best_size then
                is_better = true
            elseif candidate_size == best_size then
                if candidate_key < best_key then
                    is_better = true
                elseif candidate_key == best_key and type(candidate_class_name) == "string" then
                    if type(best_class_name) ~= "string" or candidate_class_name < best_class_name then
                        is_better = true
                    end
                end
            end

            if is_better then
                best_key = candidate_key
                best_size = candidate_size
                best_class_name = candidate_class_name
            end
        end
    end

    return best_key or source_key
end

-- Performance Impact: Moderate (runs only once during initial mod setup).
mod.zipit2_build_npcs = function(D)
    do
        local MissionGiverVoSettings = mod.try_require("scripts/settings/dialogue/mission_giver_vo_settings") or {}
        local overrides = MissionGiverVoSettings.overrides
        local major_voice_profile_set = {}

        if type(overrides) == "table" then
            for k, v in pairs(overrides) do
                if type(k) == "string" then major_voice_profile_set[mod.strip_past_prefix(k)] = true end
                if type(v) == "string" then major_voice_profile_set[mod.strip_past_prefix(v)] = true end
            end
            local count = #overrides
            for i = 1, count do
                local v = overrides[i]
                if type(v) == "string" then major_voice_profile_set[mod.strip_past_prefix(v)] = true end
            end
        end
        major_voice_profile_set["travelling_salesman_a"] = true
        major_voice_profile_set["travelling_salesman_b"] = true
        major_voice_profile_set["travelling_salesman_c"] = true
        major_voice_profile_set.none = nil

        local major_groups, major_voice_to_class, major_classes_set = {}, {}, {}
        local player_set = D.player_voice_set or {}

        for class_name, entry in pairs(DialogueBreedSettings or {}) do
            if type(class_name) == "string" and type(entry) == "table" then
                local key = _canonical_group_key(class_name, entry)
                local voices = _expand_wwise_voices(entry.wwise_voices)
                local has_major = false
                local has_minor = false
                local voices_count = #voices

                for i = 1, voices_count do
                    local v = voices[i]
                    if type(v) == "string" and v ~= "" and v ~= "voice_preview" then
                        local vb = mod.strip_past_prefix(v)
                        if major_voice_profile_set[vb] then
                            has_major = true
                        elseif not player_set[v] and not player_set[vb] then
                            has_minor = true
                        end
                    end
                end

                if has_major and not has_minor then
                    major_classes_set[key] = true
                    local g = major_groups[key]
                    if not g then
                        g = { voices = {}, voices_len = 0, source_classes = {} }
                        major_groups[key] = g
                    end
                    g.source_classes[mod.strip_past_prefix(class_name)] = true

                    for i = 1, voices_count do
                        local v = voices[i]
                        if type(v) == "string" and v ~= "" and v ~= "voice_preview" then
                            g.voices_len = g.voices_len + 1
                            g.voices[g.voices_len] = v
                            _register_voice_mapping(major_voice_to_class, v, key)
                        end
                    end
                end
            end
        end

        for key, g in pairs(major_groups) do
            local uniq = {}
            local out = {}
            local out_len = 0
            for i = 1, g.voices_len do
                local v = g.voices[i]
                if type(v) == "string" and v ~= "" and not uniq[v] then
                    uniq[v] = true
                    out_len = out_len + 1
                    out[out_len] = v
                end
            end
            table.sort(out)
            g.voices = out
            g.voices_len = nil

            local best = _best_voice_for_group(key, out)
            g.label = best and mod.speaker_label(best) or key
        end

        local major_keys = mod.sorted_list_from_set(major_classes_set)
        table.sort(major_keys, function(a, b)
            local la = (major_groups[a] and major_groups[a].label) or a
            local lb = (major_groups[b] and major_groups[b].label) or b
            if la ~= lb then return la < lb end
            return a < b
        end)

        D.major_groups = major_groups
        D.major_voice_to_class = major_voice_to_class
        D.major_classes_set = major_classes_set
        D.major_classes = major_keys
        D.major_group_keys = major_keys
        D.major_voice_profile_set = major_voice_profile_set
    end

    do
        local player_set = D.player_voice_set or {}
        local major_voice_to_class = D.major_voice_to_class or {}
        local major_voice_profile_set = D.major_voice_profile_set or {}
        local major_groups = D.major_groups or {}
        local major_classes_set = D.major_classes_set or {}

        local minor_groups, minor_classes_set, minor_voice_to_group = {}, {}, {}
        local minor_pool_candidates = {}
        local minor_pool_candidates_len = 0
        local minor_pool_candidate_by_class = {}

        -- Phase 1: Build minor voice candidates
        for class_name, entry in pairs(DialogueBreedSettings or {}) do
            if type(class_name) == "string" and type(entry) == "table" and entry.dialogue_memory_faction_name == "npc" then
                local key = _canonical_group_key(class_name, entry)
                local voices = _expand_wwise_voices(entry.wwise_voices)
                local voices_count = #voices
                local minor_voice_count = 0
                local match_keys = {}

                for i = 1, voices_count do
                    local v = voices[i]
                    if type(v) == "string" and v ~= "" and v ~= "voice_preview" then
                        local vb = mod.strip_past_prefix(v)
                        local is_major = _is_major_voice(major_voice_to_class, major_voice_profile_set, v, vb)
                        local is_player = _is_player_voice(player_set, v, vb)

                        if not is_player and not is_major then
                            minor_voice_count = minor_voice_count + 1
                            local match_key = _minor_voice_match_key(v)
                            if type(match_key) == "string" and match_key ~= "" then
                                match_keys[match_key] = true
                            end
                        end
                    end
                end

                if minor_voice_count > 0 then
                    minor_pool_candidates_len = minor_pool_candidates_len + 1
                    local candidate = {
                        class_name = class_name,
                        key = key,
                        voice_count = minor_voice_count,
                        match_keys = match_keys,
                    }
                    minor_pool_candidates[minor_pool_candidates_len] = candidate
                    minor_pool_candidate_by_class[class_name] = candidate
                end
            end
        end

        -- Phase 2: Map minor voices to their most specific internal group key
        local key_to_voices = {}
        for class_name, entry in pairs(DialogueBreedSettings or {}) do
            if type(class_name) == "string" and type(entry) == "table" and entry.dialogue_memory_faction_name == "npc" then
                local key = _canonical_group_key(class_name, entry)
                local voices = _expand_wwise_voices(entry.wwise_voices)
                local voices_count = #voices
                local source_candidate = minor_pool_candidate_by_class[class_name]
                local source_pool_size = source_candidate and source_candidate.voice_count or 0

                for i = 1, voices_count do
                    local v = voices[i]
                    if type(v) == "string" and v ~= "" and v ~= "voice_preview" then
                        local vb = mod.strip_past_prefix(v)
                        local is_major = _is_major_voice(major_voice_to_class, major_voice_profile_set, v, vb)
                        local is_player = _is_player_voice(player_set, v, vb)

                        if not is_player and not is_major then
                            local target_key = key
                            if source_pool_size > 0 then
                                target_key = _pick_smaller_minor_group(
                                    key,
                                    source_pool_size,
                                    _minor_voice_match_key(v),
                                    minor_pool_candidates
                                )
                            end

                            key_to_voices[target_key] = key_to_voices[target_key] or {}
                            key_to_voices[target_key][v] = true
                        elseif is_major and not major_voice_to_class[v] then
                            local target_group = mod.strip_variant_suffix(vb)
                            if major_classes_set[target_group] then
                                _register_voice_mapping(major_voice_to_class, v, target_group)
                                local g = major_groups[target_group]
                                if g and g.voices then
                                    g.voices[#g.voices + 1] = v
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Phase 3: Try to find a valid localized label for each group and bucket those that match
        local minor_label_buckets = {}
        local SpeakerVoiceSettings = mod.try_require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

        for key, v_map in pairs(key_to_voices) do
            local v_list = {}
            for v, _ in pairs(v_map) do
                v_list[#v_list + 1] = v
            end

            local best = _best_voice_for_group(key, v_list)
            local label = nil

            if best and SpeakerVoiceSettings then
                local s = SpeakerVoiceSettings[best]
                if type(s) == "table" then
                    local loc_key = s.full_name or s.short_name or s.display_name or s.name
                    label = mod.try_localize_loc_key(loc_key)
                end
            end

            -- Exclude if a valid localized string is not available,
            -- otherwise merge groups sharing the same label
            if type(label) == "string" and label ~= "" then
                local bucket = minor_label_buckets[label]
                if not bucket then
                    bucket = {
                        label = label,
                        keys = {},
                        voices = {}
                    }
                    minor_label_buckets[label] = bucket
                end

                bucket.keys[#bucket.keys + 1] = key
                for v, _ in pairs(v_map) do
                    bucket.voices[v] = true
                end
            end
        end

        -- Phase 4: Construct final canonical groups from the merged label buckets
        for label, bucket in pairs(minor_label_buckets) do
            table.sort(bucket.keys)
            local canonical_group_key = bucket.keys[1]

            local sorted_voices = {}
            for v, _ in pairs(bucket.voices) do
                sorted_voices[#sorted_voices + 1] = v
                _register_voice_mapping(minor_voice_to_group, v, canonical_group_key)
            end
            table.sort(sorted_voices)

            minor_classes_set[canonical_group_key] = true
            minor_groups[canonical_group_key] = {
                label = label,
                voices = sorted_voices
            }
        end

        local minor_keys = mod.sorted_list_from_set(minor_classes_set)
        table.sort(minor_keys, function(a, b)
            local la = (minor_groups[a] and minor_groups[a].label) or a
            local lb = (minor_groups[b] and minor_groups[b].label) or b
            if la ~= lb then return la < lb end
            return a < b
        end)

        D.minor_groups = minor_groups
        D.minor_classes_set = minor_classes_set
        D.minor_classes = minor_keys
        D.minor_group_keys = minor_keys
        D.minor_voice_to_group = minor_voice_to_group
    end
end
