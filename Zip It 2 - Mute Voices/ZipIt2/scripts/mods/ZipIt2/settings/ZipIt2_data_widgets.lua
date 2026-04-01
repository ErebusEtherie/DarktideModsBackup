-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_widgets.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local UiSettings = require("scripts/settings/ui/ui_settings")

local type, string, table, pairs = type, string, table, pairs

local function _briefing_mode_options()
    return {
        { text = Localize("loc_setting_dodge_stamina_hud_both_always"),   value = "off",         localize = false },
        { text = mod:localize("briefing_mute_mode_lobby_only"),           value = "lobby_only",  localize = false },
        { text = mod:localize("briefing_mute_mode_rejoin_only"),          value = "rejoin_only", localize = false },
        { text = Localize("loc_setting_dodge_stamina_hud_disabled_both"), value = "both",        localize = false },
    }
end

local function _ping_sound_mode_options()
    return {
        { text = Localize("loc_setting_checkbox_on"),                  value = "all",   localize = false },
        { text = Localize("loc_setting_voice_chat_presets_mic_muted"), value = "muted", localize = false },
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
    local txt_muted = Localize("loc_setting_voice_chat_presets_mic_muted")
    local txt_all = Localize("loc_setting_aim_assist_new_full")
    local txt_com = Localize("loc_ingame_com_wheel")
    local txt_combat = Localize("loc_achievement_category_tactical_label")
    local txt_social = Localize("loc_social_view_display_name")

    return {
        { text = txt_muted,                         value = "muted",            localize = false },
        { text = txt_com,                           value = "com_wheel",        localize = false },
        { text = txt_combat,                        value = "combat",           localize = false },
        { text = txt_social,                        value = "social",           localize = false },
        { text = txt_com .. " + " .. txt_combat,    value = "com_wheel_combat", localize = false },
        { text = txt_com .. " + " .. txt_social,    value = "com_wheel_social", localize = false },
        { text = txt_combat .. " + " .. txt_social, value = "combat_social",    localize = false },
        { text = txt_all,                           value = "all",              localize = false },
    }
end

local function _global_voice_preset_options()
    return {
        { text = Localize("loc_setting_aim_assist_new_full"),            value = "enable_all",  localize = false },
        { text = Localize("loc_setting_voice_chat_presets_mic_muted"),   value = "disable_all", localize = false },
        { text = Localize("loc_setting_graphics_quality_option_custom"), value = "custom",      localize = false },
    }
end

local function _com_wheel_option_text(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local loc_key = entry.display_name_loc or entry.loc_key or entry.display_name
    if type(loc_key) == "string" and loc_key ~= "" then
        return mod.try_localize_loc_key(loc_key) or loc_key
    end

    local value = entry.value
    if type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

local function _com_wheel_option_value(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local value = entry.value
    if type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

local function _com_wheel_options(D)
    local src = D.com_wheel_options or {}
    local out = {}
    local out_len = 0
    local count = #src

    for i = 1, count do
        local entry = src[i]
        local value = _com_wheel_option_value(entry)
        local text = _com_wheel_option_text(entry)

        if value and text then
            out_len = out_len + 1
            out[out_len] = {
                text = text,
                value = value,
                localize = false,
            }
        end
    end

    return out
end

local function _default_com_wheel_option_value(D)
    local src = D.com_wheel_options or {}
    local count = #src
    local first_value = nil

    for i = 1, count do
        local entry = src[i]
        local value = _com_wheel_option_value(entry)

        if value then
            if not first_value then
                first_value = value
            end

            if value == "thanks" then
                return value
            end
        end
    end

    return first_value or "thanks"
end

local function _add_checkbox(dst, dst_len, setting_id, title, default_value)
    dst[dst_len + 1] = {
        setting_id = setting_id,
        type = "checkbox",
        default_value = default_value == true,
        title = title,
        text = title,
        localize = false,
    }

    return dst_len + 1
end

local function _add_dropdown(dst, dst_len, setting_id, title, default_value, options)
    dst[dst_len + 1] = {
        setting_id = setting_id,
        type = "dropdown",
        default_value = default_value,
        title = title,
        text = title,
        options = options,
        localize = false,
    }

    return dst_len + 1
end

local function _add_keybind(dst, dst_len, setting_id, title, function_name)
    dst[dst_len + 1] = {
        setting_id = setting_id,
        type = "keybind",
        title = title,
        text = title,
        keybind_trigger = "pressed",
        keybind_type = "function_call",
        function_name = function_name,
        default_value = {},
        localize = false,
    }

    return dst_len + 1
end

local function _push_setting_id(bucket_name, setting_id)
    local ids = mod._zipit2_setting_ids
    local bucket = ids and ids[bucket_name]
    if type(bucket) == "table" then
        local len_key = bucket_name .. "_len"
        ids[len_key] = ids[len_key] + 1
        bucket[ids[len_key]] = setting_id
    end
end

local function _archetype_title(archetype)
    local D = mod._zipit2_discovery or {}
    local loc = D.archetype_name_loc and D.archetype_name_loc[archetype]

    local name = (loc and mod.try_localize_loc_key(loc)) or archetype
    local glyph = (UiSettings.archetype_font_icon_simple and UiSettings.archetype_font_icon_simple[archetype]) or ""

    if glyph ~= "" then
        return glyph .. " " .. name
    end

    return name
end

local function _breed_title(group_key, group)
    return (group and group.label) or group_key
end

mod.zipit2_build_widgets = function()
    local widgets = {}
    local widgets_len = 0
    local D = mod._zipit2_discovery or {}

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
        breed = {},
        breed_len = 0,
    }

    do
        widgets_len = _add_dropdown(
            widgets,
            widgets_len,
            "global_voice_preset",
            Localize("loc_setting_mix_presets"),
            "custom",
            _global_voice_preset_options()
        )
        _push_setting_id("top_level", "global_voice_preset")

        widgets_len = _add_checkbox(
            widgets,
            widgets_len,
            "subtitles_enabled",
            Localize("loc_interface_setting_subtitle_enabled"),
            false
        )
        _push_setting_id("top_level", "subtitles_enabled")

        widgets_len = _add_dropdown(
            widgets,
            widgets_len,
            "ping_sound_mode",
            Localize("loc_settings_menu_group_com_wheel_settings"),
            "all",
            _ping_sound_mode_options()
        )
        _push_setting_id("top_level", "ping_sound_mode")

        widgets_len = _add_dropdown(
            widgets,
            widgets_len,
            "briefing_mute_mode",
            mod:localize("briefing_mute_mode_name"),
            "rejoin_only",
            _briefing_mode_options()
        )
        _push_setting_id("top_level", "briefing_mute_mode")

        widgets_len = _add_keybind(
            widgets,
            widgets_len,
            "keybind_selected_wheel_option",
            mod:localize("selected_wheel_option_hotkey_name"),
            "zipit2_trigger_selected_wheel_option"
        )
        _push_setting_id("top_level", "keybind_selected_wheel_option")

        widgets_len = _add_dropdown(
            widgets,
            widgets_len,
            "selected_wheel_option",
            mod:localize("selected_wheel_option_name"),
            _default_com_wheel_option_value(D),
            _com_wheel_options(D)
        )
        _push_setting_id("top_level", "selected_wheel_option")
    end

    do
        local player_by_arch = D.player_by_arch or {}
        local voice_display = D.player_voice_display or {}
        local archetypes_count = #(D.archetypes or {})

        for i = 1, archetypes_count do
            local archetype = D.archetypes[i]
            local voices = player_by_arch[archetype]

            if type(voices) == "table" and #voices > 0 then
                local sub, sub_len = {}, 0
                local voice_count = #voices

                for j = 1, voice_count do
                    local voice = voices[j]
                    local sid = "mute_player__" .. voice
                    local label = voice_display[voice] or voice

                    sub_len = _add_dropdown(sub, sub_len, sid, label, "all", _player_mode_options())
                    _push_setting_id("player", sid)
                end

                widgets_len = widgets_len + 1
                widgets[widgets_len] = {
                    setting_id = "group_player_" .. archetype,
                    type = "group",
                    title = _archetype_title(archetype),
                    localize = false,
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
                local voice_count = #voices

                for j = 1, voice_count do
                    local voice = voices[j]
                    local sid = "mute_player__" .. voice
                    local label = voice_display[voice] or voice

                    sub_len = _add_dropdown(sub, sub_len, sid, label, "all", _player_mode_options())
                    _push_setting_id("player", sid)
                end

                widgets_len = widgets_len + 1
                widgets[widgets_len] = {
                    setting_id = "group_player_" .. archetype,
                    type = "group",
                    title = _archetype_title(archetype),
                    localize = false,
                    sub_widgets = sub,
                }
            end
        end
    end

    do
        local groups = D.major_groups or {}
        local classes = D.major_classes or {}
        local classes_count = #classes

        for i = 1, classes_count do
            local key = classes[i]
            local g = groups[key]
            local title = (g and g.label) or key
            local voices = (g and g.voices) or nil
            local voice_count = (type(voices) == "table" and #voices) or 0
            local sub, sub_len = {}, 0

            local sid_brief = ("mute_major__%s__briefings"):format(key)
            local sid_chatter = ("mute_major__%s__chatter"):format(key)

            sub_len = _add_checkbox(
                sub,
                sub_len,
                sid_brief,
                mod:localize("major_npc_briefings_name"),
                true
            )
            sub_len = _add_dropdown(
                sub,
                sub_len,
                sid_chatter,
                mod:localize("major_npc_chatter_name"),
                "none",
                _major_chatter_mode_options()
            )

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
                setting_id = "group_major_" .. key,
                type = "group",
                title = title,
                subtitle = subtitle,
                localize = false,
                sub_widgets = sub,
            }
        end
    end

    do
        local groups = D.minor_groups or {}
        local classes = D.minor_classes or {}
        local classes_count = #classes
        local sub, sub_len = {}, 0

        for i = 1, classes_count do
            local key = classes[i]
            local g = groups[key]
            local title = (g and g.label) or key
            local sid = "mute_minor__" .. key

            sub_len = _add_checkbox(sub, sub_len, sid, title, true)
            _push_setting_id("minor", sid)
        end

        widgets_len = widgets_len + 1
        widgets[widgets_len] = {
            setting_id = "group_minor_npcs",
            type = "group",
            title = Localize("loc_tactical_overlay_build_other"),
            subtitle = "",
            localize = false,
            sub_widgets = sub,
        }
    end

    do
        local groups = D.breed_groups or {}
        local classes = D.breed_classes or {}
        local classes_count = #classes
        local sub, sub_len = {}, 0

        for i = 1, classes_count do
            local key = classes[i]
            local g = groups[key]
            local title = _breed_title(key, g)
            local sid = "mute_breed__" .. key

            sub_len = _add_checkbox(sub, sub_len, sid, title, true)
            _push_setting_id("breed", sid)
        end

        widgets_len = widgets_len + 1
        widgets[widgets_len] = {
            setting_id = "group_breed_voices",
            type = "group",
            title = Localize("loc_achievement_category_heretics_label"),
            subtitle = "",
            localize = false,
            sub_widgets = sub,
        }
    end

    for key, _ in pairs(mod._zipit2_setting_ids) do
        if string.find(key, "_len$") then
            mod._zipit2_setting_ids[key] = nil
        end
    end

    return widgets
end

return mod.zipit2_build_widgets
