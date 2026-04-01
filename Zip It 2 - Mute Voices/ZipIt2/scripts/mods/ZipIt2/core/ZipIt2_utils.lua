-- File: ZipIt2/scripts/mods/ZipIt2/core/ZipIt2_utils.lua
local mod = get_mod("ZipIt2")
if not mod then return end

local type, string, rawget, table, pairs, _G = type, string, rawget, table, pairs, _G

mod.starts_with = function(value, prefix)
    return type(value) == "string" and type(prefix) == "string" and value:sub(1, #prefix) == prefix
end

mod.trim = function(s)
    if type(s) ~= "string" then return s end
    return s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^['\"]", ""):gsub("['\"]$", "")
end

mod.strip_past_prefix = function(s)
    if type(s) == "string" then
        if s == "fx" then return "training_ground_psyker_a" end
        if s:sub(1, 11) == "past_young_" then
            return s:sub(12)
        elseif s:sub(1, 5) == "past_" then
            return s:sub(6)
        end
    end
    return s
end

mod.strip_variant_suffix = function(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("_[a-z]$", ""))
end

mod.sorted_list_from_set = function(set_tbl)
    local out = {}
    local out_len = 0
    for k, v in pairs(set_tbl or {}) do
        if v then
            out_len = out_len + 1
            out[out_len] = k
        end
    end
    table.sort(out)
    return out
end

mod.can_get = function(path)
    local Application = rawget(_G, "Application")
    return Application and Application.can_get_resource and Application.can_get_resource("lua", path) == true
end

mod.try_require = function(path)
    if mod.can_get(path) then
        return require(path)
    end
    return nil
end

mod.try_localize_loc_key = function(key)
    if type(key) ~= "string" or key == "" then return nil end
    if key:sub(1, 4) ~= "loc_" then return nil end

    local val = nil
    local _Managers = rawget(_G, "Managers")
    if _G.Localize then
        val = _G.Localize(key)
    elseif _Managers and _Managers.localization then
        val = _Managers.localization:localize(key)
    end

    if type(val) ~= "string" or val == "" then return nil end
    if val == ("<" .. key .. ">") then return nil end
    if val == ("<unlocalized \"" .. key .. "\": string not found>") then return nil end
    if string.find(val, "<unlocalized \"", 1, true) == 1 then return nil end

    return val
end

mod.speaker_label = function(voice_profile)
    if type(voice_profile) ~= "string" or voice_profile == "" then
        return mod:localize("label_unknown_voice")
    end

    local SpeakerVoiceSettings = mod.try_require("scripts/settings/dialogue/dialogue_speaker_voice_settings")
    local s = SpeakerVoiceSettings and SpeakerVoiceSettings[voice_profile]
    if type(s) == "table" then
        local loc_key = s.full_name or s.short_name or s.display_name or s.name
        local v = mod.try_localize_loc_key(loc_key)
        if v then return v end
    end
    return voice_profile
end
