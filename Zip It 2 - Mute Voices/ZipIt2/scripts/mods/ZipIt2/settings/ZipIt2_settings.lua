-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_settings.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local type, string = type, string

-- ---------------------------------------------------------------------------
-- Settings cache (single read on init; only updated via mod.on_setting_changed)
-- ---------------------------------------------------------------------------
mod._zipit2_settings = mod._zipit2_settings or {
    global_voice_preset = "custom",
    subtitles_enabled = false,
    ping_sound_mode = "all",
    briefing_mute_mode = "rejoin_only",
    selected_wheel_option = "thanks",
    player_mode = {},
    minor_enabled = {},
    breed_enabled = {},
    major = {},
}

local S = mod._zipit2_settings

S.player_mode = S.player_mode or {}
S.minor_enabled = S.minor_enabled or {}
S.breed_enabled = S.breed_enabled or {}
S.major = S.major or {}

local function _ensure_major_state(class_key)
    local state = S.major[class_key]

    if not state then
        state = { briefings_enabled = true, chatter = "none" }
        S.major[class_key] = state
    end

    return state
end

local function _sanitize_global_voice_preset(value)
    if value == "enable_all" or value == "disable_all" or value == "custom" then
        return value
    end

    return "custom"
end

local function _sanitize_ping_sound_mode(value)
    if value == "all" or value == "muted" then
        return value
    end

    -- Legacy migration: Catch old values config settings to gracefully migrate existing users
    if value == "com_wheel" or value == "both" then
        return "muted"
    end

    return "all"
end

local function _sanitize_player_mode(value)
    local valid = {
        all = true,
        muted = true,
        com_wheel = true,
        combat = true,
        social = true,
        com_wheel_combat = true,
        com_wheel_social = true,
        combat_social = true
    }

    if valid[value] then
        return value
    end

    -- Legacy migration mapping from older versions
    if value == "none" then return "all" end
    if value == "combat" then return "com_wheel_social" end
    if value == "social" then return "com_wheel_combat" end
    if value == "both" then return "com_wheel" end

    return "all"
end

local function _default_selected_wheel_option()
    local D = mod._zipit2_discovery or {}
    local default_value = D.com_wheel_default_option

    if type(default_value) == "string" and default_value ~= "" then
        return default_value
    end

    return "thanks"
end

local function _sanitize_selected_wheel_option(value)
    local D = mod._zipit2_discovery or {}
    local option_by_value = D.com_wheel_option_by_value

    if type(value) == "string" and value ~= "" and type(option_by_value) == "table" and option_by_value[value] then
        return value
    end

    return _default_selected_wheel_option()
end

local function _set_global_voice_preset(value)
    value = _sanitize_global_voice_preset(value)

    if S.global_voice_preset == value then
        return
    end

    S.global_voice_preset = value

    mod._zipit2_syncing_global_voice_preset = true
    mod:set("global_voice_preset", value, true)
    mod._zipit2_syncing_global_voice_preset = false
end

local function _apply_global_voice_preset(value)
    local ids = mod._zipit2_setting_ids

    if type(ids) ~= "table" then
        return
    end

    local enable_all = value == "enable_all"
    local disable_all = value == "disable_all"

    if not enable_all and not disable_all then
        return
    end

    mod._zipit2_applying_global_voice_preset = true

    local player_value = enable_all and "all" or "muted"
    local ping_sound_value = enable_all and "all" or "muted"
    local briefing_value = enable_all and "off" or "both"
    local major_briefing_value = enable_all
    local major_chatter_value = enable_all and "none" or "both"
    local minor_value = enable_all
    local breed_value = enable_all

    if type(ids.player) == "table" then
        local count = #ids.player

        for i = 1, count do
            mod:set(ids.player[i], player_value, true)
        end
    end

    mod:set("ping_sound_mode", ping_sound_value, true)
    mod:set("briefing_mute_mode", briefing_value, true)

    if type(ids.major_briefing) == "table" then
        local count = #ids.major_briefing

        for i = 1, count do
            mod:set(ids.major_briefing[i], major_briefing_value, true)
        end
    end

    if type(ids.major_chatter) == "table" then
        local count = #ids.major_chatter

        for i = 1, count do
            mod:set(ids.major_chatter[i], major_chatter_value, true)
        end
    end

    if type(ids.minor) == "table" then
        local count = #ids.minor

        for i = 1, count do
            mod:set(ids.minor[i], minor_value, true)
        end
    end

    if type(ids.breed) == "table" then
        local count = #ids.breed

        for i = 1, count do
            mod:set(ids.breed[i], breed_value, true)
        end
    end

    mod._zipit2_applying_global_voice_preset = false
end

local function _cache_all_settings_once()
    S.player_mode = {}
    S.minor_enabled = {}
    S.breed_enabled = {}
    S.major = {}

    S.global_voice_preset = _sanitize_global_voice_preset(mod:get("global_voice_preset"))
    S.subtitles_enabled = mod:get("subtitles_enabled")
    S.ping_sound_mode = _sanitize_ping_sound_mode(mod:get("ping_sound_mode"))
    S.selected_wheel_option = _sanitize_selected_wheel_option(mod:get("selected_wheel_option"))

    local mode = mod:get("briefing_mute_mode")
    S.briefing_mute_mode = (type(mode) == "string" and mode ~= "") and mode or "rejoin_only"

    local ids = mod._zipit2_setting_ids

    if type(ids) ~= "table" then
        return
    end

    if type(ids.player) == "table" then
        local count = #ids.player

        for i = 1, count do
            local setting_id = ids.player[i]
            local voice = string.sub(setting_id, 14) -- #"mute_player__" + 1

            S.player_mode[voice] = _sanitize_player_mode(mod:get(setting_id))
        end
    end

    if type(ids.major_briefing) == "table" then
        local count = #ids.major_briefing

        for i = 1, count do
            local setting_id = ids.major_briefing[i]
            local class_key = string.match(setting_id, "^mute_major__(.+)__briefings$")

            if class_key then
                _ensure_major_state(class_key).briefings_enabled = mod:get(setting_id) == true
            end
        end
    end

    if type(ids.major_chatter) == "table" then
        local count = #ids.major_chatter

        for i = 1, count do
            local setting_id = ids.major_chatter[i]
            local class_key = string.match(setting_id, "^mute_major__(.+)__chatter$")

            if class_key then
                local v = mod:get(setting_id)

                if v ~= "none" and v ~= "hub" and v ~= "mission" and v ~= "both" then
                    v = "none"
                end

                _ensure_major_state(class_key).chatter = v
            end
        end
    end

    if type(ids.minor) == "table" then
        local count = #ids.minor

        for i = 1, count do
            local setting_id = ids.minor[i]
            local group_key = string.sub(setting_id, 13) -- #"mute_minor__" + 1

            S.minor_enabled[group_key] = mod:get(setting_id) == true
        end
    end

    if type(ids.breed) == "table" then
        local count = #ids.breed

        for i = 1, count do
            local setting_id = ids.breed[i]
            local group_key = string.sub(setting_id, 13) -- #"mute_breed__" + 1

            S.breed_enabled[group_key] = mod:get(setting_id) == true
        end
    end
end

_cache_all_settings_once()

function mod.on_setting_changed(setting_id)
    if setting_id == "global_voice_preset" then
        local value = _sanitize_global_voice_preset(mod:get(setting_id))

        S.global_voice_preset = value

        if mod._zipit2_syncing_global_voice_preset then
            return
        end

        if value == "enable_all" or value == "disable_all" then
            _apply_global_voice_preset(value)
        end

        return
    end

    if setting_id == "subtitles_enabled" then
        S.subtitles_enabled = mod:get(setting_id)
        return
    end

    if setting_id == "ping_sound_mode" then
        S.ping_sound_mode = _sanitize_ping_sound_mode(mod:get(setting_id))

        if not mod._zipit2_applying_global_voice_preset then
            _set_global_voice_preset("custom")
        end

        return
    end

    if setting_id == "briefing_mute_mode" then
        local mode = mod:get(setting_id)

        mode = (type(mode) == "string" and mode ~= "") and mode or "rejoin_only"
        S.briefing_mute_mode = mode

        if not mod._zipit2_applying_global_voice_preset then
            _set_global_voice_preset("custom")
        end

        return
    end

    if setting_id == "selected_wheel_option" then
        S.selected_wheel_option = _sanitize_selected_wheel_option(mod:get(setting_id))
        return
    end

    if type(setting_id) ~= "string" then
        return
    end

    if string.find(setting_id, "mute_player__", 1, true) == 1 then
        local voice = string.sub(setting_id, 14)

        S.player_mode[voice] = _sanitize_player_mode(mod:get(setting_id))

        if not mod._zipit2_applying_global_voice_preset then
            _set_global_voice_preset("custom")
        end

        return
    end

    if string.find(setting_id, "mute_minor__", 1, true) == 1 then
        local group_key = string.sub(setting_id, 13)

        S.minor_enabled[group_key] = mod:get(setting_id) == true

        if not mod._zipit2_applying_global_voice_preset then
            _set_global_voice_preset("custom")
        end

        return
    end

    if string.find(setting_id, "mute_breed__", 1, true) == 1 then
        local group_key = string.sub(setting_id, 13)

        S.breed_enabled[group_key] = mod:get(setting_id) == true

        if not mod._zipit2_applying_global_voice_preset then
            _set_global_voice_preset("custom")
        end

        return
    end

    if string.find(setting_id, "mute_major__", 1, true) == 1 then
        local class_key, suffix = string.match(setting_id, "^mute_major__(.+)__([a-z]+)$")

        if not class_key or not suffix then
            return
        end

        if suffix == "briefings" then
            local enabled = mod:get(setting_id) == true

            _ensure_major_state(class_key).briefings_enabled = enabled

            if not mod._zipit2_applying_global_voice_preset then
                _set_global_voice_preset("custom")
            end

            return
        end

        if suffix == "chatter" then
            local v = mod:get(setting_id)

            if v ~= "none" and v ~= "hub" and v ~= "mission" and v ~= "both" then
                v = "none"
            end

            _ensure_major_state(class_key).chatter = v

            if not mod._zipit2_applying_global_voice_preset then
                _set_global_voice_preset("custom")
            end

            return
        end
    end
end
