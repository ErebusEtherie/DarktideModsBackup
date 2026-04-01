-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_breeds.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local Breeds = require("scripts/settings/breed/breeds")
local type, pairs, table = type, pairs, table

local function _breed_root_path(breed_name)
    return ("scripts/settings/breed/breeds/%s_breed"):format(breed_name)
end

local function _breed_nested_path(folder_name, breed_name)
    return ("scripts/settings/breed/breeds/%s/%s_breed"):format(folder_name, breed_name)
end

local function _resolve_breed_resource_path(breed_name)
    local root_path = _breed_root_path(breed_name)
    if mod.can_get(root_path) then
        return root_path
    end

    if mod.starts_with(breed_name, "chaos_") then
        local path = _breed_nested_path("chaos", breed_name)
        if mod.can_get(path) then return path end
    end

    if mod.starts_with(breed_name, "cultist_") then
        local path = _breed_nested_path("cultist", breed_name)
        if mod.can_get(path) then return path end
    end

    if mod.starts_with(breed_name, "renegade_") then
        local path = _breed_nested_path("renegade", breed_name)
        if mod.can_get(path) then return path end
    end

    if mod.starts_with(breed_name, "companion_") then
        local path = _breed_nested_path("companion", breed_name)
        if mod.can_get(path) then return path end
    end

    if breed_name == "attack_valkyrie" then
        local path = _breed_nested_path("valkyrie", breed_name)
        if mod.can_get(path) then return path end
    end

    return nil
end

local function _is_nested_breed_path(breed_name, breed_path)
    return type(breed_path) == "string" and breed_path ~= "" and breed_path ~= _breed_root_path(breed_name)
end

local function _resolve_breed_sounds_path(breed_name, breed_path)
    if type(breed_path) ~= "string" or breed_path == "" then
        return nil
    end

    local sounds_path = breed_path:gsub("_breed$", "_sounds")
    if sounds_path ~= breed_path and mod.can_get(sounds_path) then
        return sounds_path
    end

    local root_sounds_path = ("scripts/settings/breed/breeds/%s_sounds"):format(breed_name)
    if mod.can_get(root_sounds_path) then
        return root_sounds_path
    end

    return nil
end

local function _sorted_sound_event_list_from_table(events_tbl)
    local out = {}
    local out_len = 0
    local seen = {}

    if type(events_tbl) == "table" then
        for _, event_name in pairs(events_tbl) do
            if type(event_name) == "string" and event_name ~= "" and not seen[event_name] then
                seen[event_name] = true
                out_len = out_len + 1
                out[out_len] = event_name
            end
        end
    end

    table.sort(out)
    return out
end

local function _push_unique_string(dst, dst_len, seen, value)
    if type(value) == "string" and value ~= "" and not seen[value] then
        dst_len = dst_len + 1
        dst[dst_len] = value
        seen[value] = true
    end

    return dst_len
end

local function _breed_label(breed_data)
    if type(breed_data) ~= "table" or type(breed_data.display_name) ~= "string" then
        return nil
    end
    return mod.try_localize_loc_key(breed_data.display_name)
end

-- Performance Impact: Moderate (runs only once during initial mod setup).
mod.zipit2_build_breeds = function(D)
    do
        local breed_groups = {}
        local breed_classes_set = {}
        local breed_sound_event_to_groups = {}
        local breed_label_groups = {}

        for breed_name, breed_data in pairs(Breeds or {}) do
            if type(breed_name) == "string" and type(breed_data) == "table" then
                local breed_path = _resolve_breed_resource_path(breed_name)

                if _is_nested_breed_path(breed_name, breed_path) then
                    local label = _breed_label(breed_data)

                    if label then
                        local sounds_path = _resolve_breed_sounds_path(breed_name, breed_path)
                        local sound_data = sounds_path and mod.try_require(sounds_path) or nil
                        local sound_events = _sorted_sound_event_list_from_table(sound_data and sound_data.events or nil)
                        local bucket = breed_label_groups[label]

                        if not bucket then
                            bucket = {
                                label = label,
                                breed_names = {},
                                breed_names_len = 0,
                                breed_name_set = {},
                                sound_events = {},
                                sound_events_len = 0,
                                sound_event_set = {},
                            }
                            breed_label_groups[label] = bucket
                        end

                        bucket.breed_names_len = _push_unique_string(
                            bucket.breed_names,
                            bucket.breed_names_len,
                            bucket.breed_name_set,
                            breed_name
                        )

                        local event_count = #sound_events
                        for i = 1, event_count do
                            bucket.sound_events_len = _push_unique_string(
                                bucket.sound_events,
                                bucket.sound_events_len,
                                bucket.sound_event_set,
                                sound_events[i]
                            )
                        end
                    end
                end
            end
        end

        for _, bucket in pairs(breed_label_groups) do
            local breed_names = bucket.breed_names
            local sound_events = bucket.sound_events

            table.sort(breed_names)
            table.sort(sound_events)

            local group_key = breed_names[1]

            if group_key then
                local group = {
                    label = bucket.label,
                    breed_name = group_key,
                    breed_names = breed_names,
                    sound_events = sound_events,
                }

                breed_groups[group_key] = group
                breed_classes_set[group_key] = true

                local event_count = #sound_events
                for i = 1, event_count do
                    local event_name = sound_events[i]
                    local event_groups = breed_sound_event_to_groups[event_name]

                    if not event_groups then
                        event_groups = {}
                        breed_sound_event_to_groups[event_name] = event_groups
                    end

                    event_groups[group_key] = true
                end
            end
        end

        local breed_keys = mod.sorted_list_from_set(breed_classes_set)
        table.sort(breed_keys, function(a, b)
            local la = (breed_groups[a] and breed_groups[a].label) or a
            local lb = (breed_groups[b] and breed_groups[b].label) or b
            if la ~= lb then return la < lb end
            return a < b
        end)

        D.breed_groups = breed_groups
        D.breed_classes_set = breed_classes_set
        D.breed_classes = breed_keys
        D.breed_group_keys = breed_keys
        D.breed_sound_event_to_groups = breed_sound_event_to_groups
    end
end
