-- File: ZipIt2/scripts/mods/ZipIt2/ZipIt2_data.lua
local mod = get_mod("ZipIt2")
if not mod then
    return {
        name = "ZipIt2",
        description = "Missing mod instance",
        is_togglable = true,
        options = { widgets = {} },
    }
end

local UiSettings                         = require("scripts/settings/ui/ui_settings")
local DialogueBreedSettings              = require("scripts/settings/dialogue/dialogue_breed_settings")
local SpeakerVoiceSettings               = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")
local Personalities                      = require("scripts/settings/character/personalities")

local type, string, table, pairs, ipairs = type, string, table, pairs, ipairs

local function _can_get(path)
    return Application and Application.can_get_resource and Application.can_get_resource("lua", path) == true
end

local function _try_require(path)
    if _can_get(path) then
        return require(path)
    end
    return nil
end

local function _try_localize_loc_key(key)
    if type(key) ~= "string" or key == "" then return nil end
    if key:sub(1, 4) ~= "loc_" then return nil end

    local val = nil
    local _Managers = rawget(_G, "Managers")
    if _G.Localize then
        val = _G.Localize(key)
    elseif _Managers and _Managers.localization then
        val = _Managers.localization:localize(key)
    end

    if type(val) == "string" and val ~= "" and val ~= ("<" .. key .. ">") then
        return val
    end
    return nil
end

local function _strip_past_prefix(s)
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

local function _trim(s)
    if type(s) ~= "string" then return s end
    return s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^['\"]", ""):gsub("['\"]$", "")
end

local function _strip_variant_suffix(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("_[a-z]$", ""))
end

local function _expand_wwise_voices(wwise_voices)
    local out = {}
    local out_len = 0
    if type(wwise_voices) ~= "table" then return out end

    local count = #wwise_voices
    for i = 1, count do
        local entry = wwise_voices[i]
        if type(entry) == "string" then
            entry = _trim(entry)
            if entry ~= "" then
                if entry:find(",", 1, true) then
                    for token in string.gmatch(entry, "[^,]+") do
                        token = _trim(token)
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

local function _sorted_list_from_set(set_tbl)
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

local function _canonical_group_key(class_name, entry)
    local key = nil
    if type(entry) == "table" and type(entry.vo_class_name) == "string" and entry.vo_class_name ~= "" then
        key = entry.vo_class_name
    else
        key = _strip_variant_suffix(class_name)
    end
    return _strip_past_prefix(key)
end

local function _speaker_label(voice_profile)
    if type(voice_profile) ~= "string" or voice_profile == "" then
        return mod:localize("label_unknown_voice")
    end

    local s = SpeakerVoiceSettings and SpeakerVoiceSettings[voice_profile]
    if type(s) == "table" then
        local loc_key = s.full_name or s.short_name or s.display_name or s.name
        local v = _try_localize_loc_key(loc_key)
        if v then return v end
    end
    return voice_profile
end

local function _best_voice_for_group(group_key, voices)
    if type(voices) ~= "table" or #voices == 0 then return nil end
    local count = #voices

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
            if type(v) == "string" and (v:sub(1, #group_key + 1) == (group_key .. "_") or v == group_key) then
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

local function _voices_preview(voices, max_items)
    if type(voices) ~= "table" or #voices == 0 then return "" end
    max_items = tonumber(max_items) or 6
    if max_items < 1 then max_items = 1 end

    local out = {}
    local out_len = 0
    local n = math.min(#voices, max_items)
    for i = 1, n do
        out_len = out_len + 1
        out[out_len] = voices[i]
    end
    if #voices > n then
        out_len = out_len + 1
        out[out_len] = "..."
    end

    return table.concat(out, ", ")
end

local function _gender_suffix_for_personality(opt, voice_profile)
    local genders = opt and opt.visibility and opt.visibility.genders
    if type(genders) == "table" and #genders == 1 then
        local g = genders[1]
        if g == "male" then
            return " (male)"
        elseif g == "female" then
            return " (female)"
        end
    end

    if type(voice_profile) == "string" then
        if voice_profile:find("_male_", 1, true) or voice_profile:find("_male$") then
            return " (male)"
        elseif voice_profile:find("_female_", 1, true) or voice_profile:find("_female$") then
            return " (female)"
        end
    end
    return ""
end

local function _register_voice_mapping(map, voice, canonical_key)
    map[voice] = canonical_key
    local stripped = _strip_past_prefix(voice)
    map[stripped] = canonical_key
    map["past_" .. stripped] = canonical_key
end

local function _briefing_mode_options()
    return {
        { text = Localize("loc_setting_dodge_stamina_hud_both_always"),   value = "off",         localize = false },
        { text = mod:localize("briefing_mute_mode_lobby_only"),           value = "lobby_only",  localize = false },
        { text = mod:localize("briefing_mute_mode_rejoin_only"),          value = "rejoin_only", localize = false },
        { text = Localize("loc_setting_dodge_stamina_hud_disabled_both"), value = "both",        localize = false },
    }
end

local function _major_chatter_mode_options()
    return {
        { text = Localize("loc_setting_dodge_stamina_hud_both_always"),   value = "none",    localize = false },
        { text = Localize("loc_mission_name_hub_ship"),                   value = "hub",     localize = false },
        { text = Localize("loc_achievement_category_missions_label"),     value = "mission", localize = false },
        { text = Localize("loc_setting_dodge_stamina_hud_disabled_both"), value = "both",    localize = false },
    }
end

local function _player_mode_options()
    return {
        { text = Localize("loc_setting_dodge_stamina_hud_both_always"),   value = "none", localize = false },
        { text = Localize("loc_setting_dodge_stamina_hud_disabled_both"), value = "both", localize = false },
    }
end

if type(mod._zipit2_discovery) ~= "table" then
    local D = {}

    do
        local archetypes = {}
        local archetypes_len = 0
        local archetype_set = {}

        local src = (UiSettings and (UiSettings.archetype_font_icon or UiSettings.archetype_font_icon_simple)) or {}
        if type(src) == "table" then
            for arch, _ in pairs(src) do
                if type(arch) == "string" and arch ~= "" then
                    archetype_set[arch] = true
                end
            end
        end

        for arch in pairs(archetype_set) do
            archetypes_len = archetypes_len + 1
            archetypes[archetypes_len] = arch
        end

        local arch_loc, arch_order = {}, {}
        for i = 1, archetypes_len do
            local arch = archetypes[i]
            local ad = _try_require(("scripts/settings/archetype/archetypes/%s_archetype"):format(arch))
            if type(ad) == "table" then
                if type(ad.archetype_name) == "string" and ad.archetype_name:find("^loc_") then
                    arch_loc[arch] = ad.archetype_name
                end
                if ad.ui_selection_order ~= nil then
                    arch_order[arch] = tonumber(ad.ui_selection_order)
                end
            end
        end

        table.sort(archetypes, function(a, b)
            local oa, ob = arch_order[a] or 999, arch_order[b] or 999
            if oa ~= ob then return oa < ob end
            return a < b
        end)

        D.archetypes = archetypes
        D.archetype_name_loc = arch_loc
        D.archetype_ui_order = arch_order
    end

    do
        local player_by_arch, all_player_set = {}, {}
        local voice_display_loc, voice_display, voice_to_arch = {}, {}, {}

        for _, opt in pairs(Personalities or {}) do
            if type(opt) == "table" then
                local voice = opt.character_voice
                if type(voice) == "string" and voice ~= "" then
                    all_player_set[voice] = true

                    local base_label = nil
                    local disp_loc = opt.display_name
                    if type(disp_loc) == "string" and disp_loc:find("^loc_") then
                        voice_display_loc[voice] = disp_loc
                        base_label = _try_localize_loc_key(disp_loc) or disp_loc
                    else
                        base_label = _speaker_label(voice)
                    end

                    voice_display[voice] = base_label .. _gender_suffix_for_personality(opt, voice)

                    local vis = opt.visibility
                    local archetypes = vis and vis.archetypes
                    local arch = (type(archetypes) == "table" and archetypes[1]) or (voice:match("^([^_]+)_") or voice)

                    voice_to_arch[voice] = arch
                    player_by_arch[arch] = player_by_arch[arch] or {}
                    local list = player_by_arch[arch]
                    list[#list + 1] = voice
                end
            end
        end

        for _, list in pairs(player_by_arch) do
            table.sort(list, function(a, b)
                local la, lb = voice_display[a] or a, voice_display[b] or b
                if la ~= lb then return la < lb end
                return a < b
            end)
        end

        D.player_by_arch = player_by_arch
        D.player_voice_set = all_player_set
        D.player_voice_display_loc = voice_display_loc
        D.player_voice_display = voice_display
        D.player_voice_to_archetype = voice_to_arch
    end

    do
        local MissionGiverVoSettings = _try_require("scripts/settings/dialogue/mission_giver_vo_settings") or {}
        local overrides = MissionGiverVoSettings.overrides
        local major_voice_profile_set = {}

        if type(overrides) == "table" then
            for k, v in pairs(overrides) do
                if type(k) == "string" then major_voice_profile_set[_strip_past_prefix(k)] = true end
                if type(v) == "string" then major_voice_profile_set[_strip_past_prefix(v)] = true end
            end
            local count = #overrides
            for i = 1, count do
                local v = overrides[i]
                if type(v) == "string" then major_voice_profile_set[_strip_past_prefix(v)] = true end
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
                        local vb = _strip_past_prefix(v)
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
                    g.source_classes[_strip_past_prefix(class_name)] = true

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
            g.label = best and _speaker_label(best) or key
        end

        local major_keys = _sorted_list_from_set(major_classes_set)
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

        for class_name, entry in pairs(DialogueBreedSettings or {}) do
            if type(class_name) == "string" and type(entry) == "table" then
                if entry.dialogue_memory_faction_name == "npc" then
                    local key = _canonical_group_key(class_name, entry)
                    local voices = _expand_wwise_voices(entry.wwise_voices)
                    local any = false
                    local voices_count = #voices

                    for i = 1, voices_count do
                        local v = voices[i]
                        if type(v) == "string" and v ~= "" and v ~= "voice_preview" then
                            local vb = _strip_past_prefix(v)
                            local is_major = major_voice_to_class[v] or major_voice_to_class[vb] or
                                major_voice_profile_set[v] or major_voice_profile_set[vb]

                            if not player_set[v] and not player_set[vb] and not is_major then
                                any = true
                                _register_voice_mapping(minor_voice_to_group, v, key)

                                local g = minor_groups[key]
                                if not g then
                                    g = { voices = {}, voices_len = 0 }
                                    minor_groups[key] = g
                                end
                                g.voices_len = g.voices_len + 1
                                g.voices[g.voices_len] = v
                            elseif is_major and not major_voice_to_class[v] then
                                -- Map orphaned major voices residing in mixed minor groups into their target major group
                                local target_group = _strip_variant_suffix(vb)
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

                    if any then minor_classes_set[key] = true end
                end
            end
        end

        for key, g in pairs(minor_groups) do
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
            g.label = best and _speaker_label(best) or key
        end

        local minor_keys = _sorted_list_from_set(minor_classes_set)
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

    mod._zipit2_discovery = D
end

mod._zipit2_group_keys = {
    major = (mod._zipit2_discovery and mod._zipit2_discovery.major_group_keys) or {},
    minor = (mod._zipit2_discovery and mod._zipit2_discovery.minor_group_keys) or {},
}

-- ============================================================================
-- DMF Widgets (dynamic)
-- ============================================================================

local widgets = {}
local widgets_len = 0
local invert_hint = mod:localize("checkbox_invert_hint")

mod._zipit2_setting_ids = {
    top_level = {},
    top_level_len = 0,
    player = {},
    player_len = 0,
    major = {},
    major_len = 0,
    major_briefing = {},
    major_briefing_len = 0,
    major_chatter = {},
    major_chatter_len = 0,
    minor = {},
    minor_len = 0,
}

local function _add_checkbox(dst, dst_len, setting_id, title, description, default_value)
    dst[dst_len + 1] = {
        setting_id    = setting_id,
        type          = "checkbox",
        default_value = default_value == true,
        title         = title,
        text          = title,
        description   = description,
        localize      = false,
    }
    return dst_len + 1
end

local function _add_dropdown(dst, dst_len, setting_id, title, description, default_value, options)
    dst[dst_len + 1] = {
        setting_id    = setting_id,
        type          = "dropdown",
        default_value = default_value,
        title         = title,
        text          = title,
        description   = description,
        options       = options,
        localize      = false,
    }
    return dst_len + 1
end

local function _push_setting_id(bucket_name, setting_id)
    local ids = mod._zipit2_setting_ids
    local b = ids and ids[bucket_name]
    if type(b) == "table" then
        local len_key = bucket_name .. "_len"
        ids[len_key] = ids[len_key] + 1
        b[ids[len_key]] = setting_id
    end
end

local function _archetype_title(archetype)
    local D = mod._zipit2_discovery or {}
    local loc = D.archetype_name_loc and D.archetype_name_loc[archetype]
    local name = (loc and _try_localize_loc_key(loc)) or archetype
    local glyph = (UiSettings.archetype_font_icon_simple and UiSettings.archetype_font_icon_simple[archetype]) or ""
    if glyph ~= "" then return glyph .. " " .. name end
    return name
end

do
    widgets_len = _add_dropdown(widgets, widgets_len, "briefing_mute_mode", mod:localize("briefing_mute_mode_name"),
        mod:localize("briefing_mute_mode_desc"), "rejoin_only", _briefing_mode_options())
    _push_setting_id("top_level", "briefing_mute_mode")
end

do
    local D = mod._zipit2_discovery or {}
    local player_by_arch = D.player_by_arch or {}
    local voice_display = D.player_voice_display or {}
    local archetypes_count = #(D.archetypes or {})

    for i = 1, archetypes_count do
        local archetype = D.archetypes[i]
        local voices = player_by_arch[archetype]

        if type(voices) == "table" and #voices > 0 then
            local sub, sub_len = {}, 0
            local v_count = #voices

            for j = 1, v_count do
                local voice = voices[j]
                local sid = "mute_player__" .. voice
                local label = voice_display[voice] or voice
                sub_len = _add_dropdown(sub, sub_len, sid, label, voice, "none", _player_mode_options())
                _push_setting_id("player", sid)
            end

            widgets_len = widgets_len + 1
            widgets[widgets_len] = {
                setting_id  = "group_player_" .. archetype,
                type        = "group",
                title       = _archetype_title(archetype),
                subtitle    = invert_hint,
                localize    = false,
                sub_widgets = sub,
            }
        end
    end

    do
        local seen = {}
        for i = 1, archetypes_count do
            seen[D.archetypes[i]] = true
        end

        local extras = {}
        local extras_len = 0
        for arch, voices in pairs(player_by_arch) do
            if not seen[arch] and type(voices) == "table" and #voices > 0 then
                extras_len = extras_len + 1
                extras[extras_len] = arch
            end
        end
        table.sort(extras)

        for i = 1, extras_len do
            local archetype = extras[i]
            local voices = player_by_arch[archetype]
            local sub, sub_len = {}, 0
            local v_count = #voices

            for j = 1, v_count do
                local voice = voices[j]
                local sid = "mute_player__" .. voice
                local label = voice_display[voice] or voice
                sub_len = _add_dropdown(sub, sub_len, sid, label, voice, "none", _player_mode_options())
                _push_setting_id("player", sid)
            end

            widgets_len = widgets_len + 1
            widgets[widgets_len] = {
                setting_id  = "group_player_" .. archetype,
                type        = "group",
                title       = _archetype_title(archetype),
                subtitle    = invert_hint,
                localize    = false,
                sub_widgets = sub,
            }
        end
    end
end

do
    local D = mod._zipit2_discovery or {}
    local groups = D.major_groups or {}
    local classes = D.major_classes or {}
    local classes_count = #classes

    for i = 1, classes_count do
        local key          = classes[i]
        local g            = groups[key]
        local title        = (g and g.label) or key
        local voices       = (g and g.voices) or nil
        local voice_count  = (type(voices) == "table" and #voices) or 0
        local sub, sub_len = {}, 0

        local sid_brief    = ("mute_major__%s__briefings"):format(key)
        local sid_chatter  = ("mute_major__%s__chatter"):format(key)

        sub_len            = _add_checkbox(sub, sub_len, sid_brief, mod:localize("major_npc_briefings_name"),
            mod:localize("major_npc_briefings_desc"), true)
        sub_len            = _add_dropdown(sub, sub_len, sid_chatter, mod:localize("major_npc_chatter_name"),
            mod:localize("major_npc_chatter_desc"), "none", _major_chatter_mode_options())

        _push_setting_id("major", sid_brief)
        _push_setting_id("major", sid_chatter)
        _push_setting_id("major_briefing", sid_brief)
        _push_setting_id("major_chatter", sid_chatter)

        local subtitle = key
        if voice_count > 0 then
            subtitle = subtitle .. " (" .. tostring(voice_count) .. ")"
        end

        widgets_len = widgets_len + 1
        widgets[widgets_len] = {
            setting_id  = "group_major_" .. key,
            type        = "group",
            title       = title,
            subtitle    = subtitle,
            localize    = false,
            sub_widgets = sub,
        }
    end
end

do
    local D = mod._zipit2_discovery or {}
    local groups = D.minor_groups or {}
    local classes = D.minor_classes or {}
    local classes_count = #classes

    local sub, sub_len = {}, 0

    for i = 1, classes_count do
        local key = classes[i]
        local g = groups[key]
        local title = (g and g.label) or key
        local voices = (g and g.voices) or nil
        local voice_count = (type(voices) == "table" and #voices) or 0
        local sid = "mute_minor__" .. key

        local preview = _voices_preview(voices, 6)
        local desc = key
        if voice_count > 0 then desc = desc .. " (" .. tostring(voice_count) .. ")" end
        if preview ~= "" then desc = desc .. "  |  " .. preview end

        sub_len = _add_checkbox(sub, sub_len, sid, title, desc, true)
        _push_setting_id("minor", sid)
    end

    widgets_len = widgets_len + 1
    widgets[widgets_len] = {
        setting_id  = "group_minor_npcs",
        type        = "group",
        title       = Localize("loc_tactical_overlay_build_other"),
        subtitle    = "",
        localize    = false,
        sub_widgets = sub,
    }
end

for k, _ in pairs(mod._zipit2_setting_ids) do
    if string.find(k, "_len$") then
        mod._zipit2_setting_ids[k] = nil
    end
end

return {
    name         = mod:localize("mod_name"),
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options      = { localize = false, widgets = widgets },
}
