-- File: ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_audio.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local Vo = require("scripts/utilities/vo")
local ChatManager = require("scripts/managers/chat/chat_manager")
local ChatManagerConstants = require("scripts/foundation/managers/chat/chat_manager_constants")
local PlayerCharacterSoundEventAliases = require("scripts/settings/sound/player_character_sound_event_aliases")

local rawget, _G, type, pairs, os, string, tonumber, math = rawget, _G, type, pairs, os, string, tonumber, math
local WwiseWorld = rawget(_G, "WwiseWorld")
local os_clock = os.clock
local string_find = string.find
local Localize = Localize

local function _switches_include_selected_voice(switches)
    if type(switches) ~= "table" then
        return false
    end

    local count = #switches

    for i = 1, count do
        if switches[i] == "selected_voice" then
            return true
        end
    end

    return false
end

local function _collect_selected_voice_event_paths(value, out)
    if type(value) == "string" then
        if string_find(value, "wwise/events/player/play_", 1, true) == 1 then
            out[value] = true
        end

        return
    end

    if type(value) ~= "table" then
        return
    end

    for _, nested_value in pairs(value) do
        _collect_selected_voice_event_paths(nested_value, out)
    end
end

local function _build_player_nonverbal_sound_event_lookups()
    local alias_lookup = {}
    local path_lookup = {}

    for alias_name, alias_data in pairs(PlayerCharacterSoundEventAliases) do
        if type(alias_data) == "table" and _switches_include_selected_voice(alias_data.switch) then
            alias_lookup[alias_name] = true
            _collect_selected_voice_event_paths(alias_data.events, path_lookup)
        end
    end

    return alias_lookup, path_lookup
end

local PLAYER_NONVERBAL_SOUND_EVENT_ALIASES, PLAYER_NONVERBAL_SOUND_EVENT_PATHS =
    _build_player_nonverbal_sound_event_lookups()

local function _voice_profile_from_unit(unit)
    if not unit then
        return nil
    end

    local dialogue_extension = ScriptUnit.has_extension(unit, "dialogue_system")
    local voice_profile = dialogue_extension and dialogue_extension._vo_profile_name

    if type(voice_profile) == "string" and voice_profile ~= "" then
        return voice_profile
    end

    return nil
end

local function _local_player_unit()
    local _Managers = rawget(_G, "Managers")
    local player_manager = _Managers and _Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)

    return local_player and local_player.player_unit or nil
end

local function _chat_manager()
    local _Managers = rawget(_G, "Managers")

    return _Managers and _Managers.chat or nil
end

local function _current_game_mode_name()
    local _Managers = rawget(_G, "Managers")
    local state = _Managers and _Managers.state
    local game_mode_manager = state and state.game_mode

    if game_mode_manager and game_mode_manager.game_mode_name then
        return game_mode_manager:game_mode_name()
    end

    return false
end

local function _ensure_other_player_com_wheel_throttle_state()
    local current_game_mode = _current_game_mode_name() or false

    if mod._zipit2_other_player_com_wheel_throttle_game_mode ~= current_game_mode then
        mod._zipit2_other_player_com_wheel_throttle_game_mode = current_game_mode
        mod._zipit2_other_player_com_wheel_throttle_by_player = {}
    elseif type(mod._zipit2_other_player_com_wheel_throttle_by_player) ~= "table" then
        mod._zipit2_other_player_com_wheel_throttle_by_player = {}
    end

    return mod._zipit2_other_player_com_wheel_throttle_by_player
end

local function _should_throttle_other_player_com_wheel(unit, voice_profile, concept)
    local S = mod._zipit2_settings or {}
    local throttle_seconds = S.other_players_com_wheel_throttle_seconds or 0

    if throttle_seconds < 1 or not unit then
        return false
    end

    local local_player_unit = _local_player_unit()

    if unit == local_player_unit then
        return false
    end

    local D = mod._zipit2_discovery or {}
    local player_voice_set = D.player_voice_set or {}

    if not player_voice_set[voice_profile] then
        return false
    end

    if mod.zipit2_classify_player_voice_identifier(concept) ~= "com_wheel" then
        return false
    end

    local throttle_by_player = _ensure_other_player_com_wheel_throttle_state()
    local current_time = os_clock()
    local next_allowed_time = throttle_by_player[unit] or 0

    if current_time < next_allowed_time then
        return true
    end

    throttle_by_player[unit] = current_time + throttle_seconds

    return false
end

local function _should_mute_player_nonverbal_sound_event(event_name)
    local S = mod._zipit2_settings or {}

    if S.player_nonverbal_sounds_enabled ~= false then
        return false
    end

    if type(event_name) ~= "string" or event_name == "" then
        return false
    end

    if PLAYER_NONVERBAL_SOUND_EVENT_ALIASES[event_name] then
        return true
    end

    if PLAYER_NONVERBAL_SOUND_EVENT_PATHS[event_name] then
        return true
    end

    return false
end

local function _should_mute_enemy_generic_vo(unit, breed_name_or_nil)
    local voice_profile = _voice_profile_from_unit(unit)

    if type(breed_name_or_nil) == "string" and breed_name_or_nil ~= "" then
        return mod.zipit2_should_mute_enemy_dialogue_breed(
            voice_profile,
            { enemy_tag = breed_name_or_nil },
            nil,
            nil
        )
    end

    return mod.zipit2_should_mute_enemy_dialogue_breed(voice_profile, nil, nil, nil)
end

local function _get_chat_channel_by_tag(channel_tag)
    local _Managers = rawget(_G, "Managers")
    local chat_manager = _Managers and _Managers.chat
    local channels = chat_manager and chat_manager:connected_chat_channels()

    if channels then
        for channel_handle, channel in pairs(channels) do
            if channel.tag == channel_tag then
                return channel, channel_handle
            end
        end
    end
end

local function _trigger_selected_wheel_option_tag(option)
    local hud_element = mod.zipit2_hud_element_smart_tagging
    local tag_type = option and option.tag_type

    if not hud_element or not tag_type then
        return
    end

    local force_update_targets = true
    local raycast_data = hud_element:_find_raycast_targets(force_update_targets)
    local hit_position = raycast_data and raycast_data.static_hit_position

    if hit_position then
        hud_element:_trigger_smart_tag(tag_type, nil, Vector3Box.unbox(hit_position))
    end
end

local function _trigger_selected_wheel_option_chat(option)
    local chat_message_data = option and option.chat_message_data

    if type(chat_message_data) ~= "table" then
        return
    end

    local text = chat_message_data.text
    local channel_tag = chat_message_data.channel
    local channel, channel_handle = _get_chat_channel_by_tag(channel_tag)

    if channel then
        Managers.chat:send_loc_channel_message(channel_handle, text, nil)
    end
end

local function _trigger_selected_wheel_option_voice(option, player_unit)
    local voice_event_data = option and option.voice_event_data

    if type(voice_event_data) ~= "table" or not player_unit then
        return
    end

    local concept = voice_event_data.voice_tag_concept
    local trigger_id = voice_event_data.voice_tag_id

    if type(concept) == "string" and concept ~= "" and type(trigger_id) == "string" and trigger_id ~= "" then
        Vo.on_demand_vo_event(player_unit, concept, trigger_id)
    end
end

local function _register_selected_wheel_option_telemetry(option)
    local voice_event_data = option and option.voice_event_data
    local trigger_id = voice_event_data and voice_event_data.voice_tag_id
    local _Managers = rawget(_G, "Managers")
    local telemetry_reporters = _Managers and _Managers.telemetry_reporters

    if telemetry_reporters and type(trigger_id) == "string" and trigger_id ~= "" then
        local reporter = telemetry_reporters:reporter("com_wheel")

        if reporter then
            reporter:register_event(trigger_id)
        end
    end
end

local function _voice_chat_settings_table()
    local user_setting = Application.user_setting

    if type(user_setting) ~= "function" then
        return nil
    end

    return user_setting("sound_settings")
end

local function _voice_chat_saved_slider_value()
    local sound_settings = _voice_chat_settings_table()
    local value = sound_settings and sound_settings.options_voip_volume_slider_v2

    if value == nil then
        return 50
    end

    value = tonumber(value) or 0

    if value < 0 then
        return 0
    end

    if value > 100 then
        return 100
    end

    return value
end

local function _voice_chat_saved_render_volume()
    local value = _voice_chat_saved_slider_value()

    if value <= 0.01 then
        return 0
    end

    return math.lerp(25, 75, value / 100)
end

local function _voice_chat_saved_mode()
    local user_setting = Application.user_setting
    local value = type(user_setting) == "function" and user_setting("sound_settings", "voice_chat") or nil

    if value == 0 or value == 1 or value == 2 then
        return value
    end

    if IS_WINDOWS then
        return 2
    end

    return 1
end

local function _desired_local_mic_muted(chat_manager)
    if mod.zipit2_is_voice_chat_output_muted and mod.zipit2_is_voice_chat_output_muted() then
        return true
    end

    local voice_chat_mode = _voice_chat_saved_mode()

    if voice_chat_mode == 0 then
        return true
    end

    if voice_chat_mode == 1 then
        return false
    end

    local input_service = chat_manager and chat_manager._input_service

    if input_service and input_service:has("voip_push_to_talk") and input_service:get("voip_push_to_talk") then
        return false
    end

    return true
end

local function _apply_voice_chat_render_volume_to_connected_sessions(render_volume)
    local Vivox = rawget(_G, "Vivox")

    if not Vivox or type(Vivox.session_set_local_render_volume) ~= "function" then
        return
    end

    local chat_manager = _chat_manager()
    local channels = chat_manager and chat_manager:connected_voip_channels()

    if type(channels) ~= "table" then
        return
    end

    for session_handle, _ in pairs(channels) do
        Vivox.session_set_local_render_volume(session_handle, render_volume)
    end
end

local function _apply_current_voice_chat_output_volume()
    local is_temporarily_muted = mod.zipit2_is_voice_chat_output_muted and mod.zipit2_is_voice_chat_output_muted()
    local render_volume = is_temporarily_muted and 0 or _voice_chat_saved_render_volume()

    _apply_voice_chat_render_volume_to_connected_sessions(render_volume)
end

local function _apply_current_local_mic_state(chat_manager)
    if not chat_manager or type(chat_manager.mute_local_mic) ~= "function" then
        return
    end

    chat_manager:mute_local_mic(_desired_local_mic_muted(chat_manager))
end

local function _refresh_voice_chat_for_game_mode(chat_manager)
    local current_game_mode = _current_game_mode_name() or false

    if mod._zipit2_voice_chat_output_game_mode ~= current_game_mode then
        mod._zipit2_voice_chat_output_game_mode = current_game_mode

        if type(mod.zipit2_reset_voice_chat_output_mute) == "function" then
            mod.zipit2_reset_voice_chat_output_mute()
        end
    end

    _apply_current_voice_chat_output_volume()
    _apply_current_local_mic_state(chat_manager or _chat_manager())
end

mod.zipit2_execute_voice_chat_toggle = mod.zipit2_execute_voice_chat_toggle or function()
    if not mod:is_enabled() then
        return
    end

    local is_muted = mod.zipit2_is_voice_chat_output_muted and mod.zipit2_is_voice_chat_output_muted() == true
    local new_muted = not is_muted

    if type(mod.zipit2_set_voice_chat_output_muted) == "function" then
        mod.zipit2_set_voice_chat_output_muted(new_muted)
    end

    local chat_manager = _chat_manager()

    _apply_current_voice_chat_output_volume()
    _apply_current_local_mic_state(chat_manager)

    if new_muted then
        mod:echo(" " ..
            Localize("loc_settings_menu_group_voice_chat_settings") ..
            " - " .. Localize("loc_setting_voice_chat_presets_mic_muted"))
    else
        mod:echo(" " ..
            Localize("loc_settings_menu_group_voice_chat_settings") ..
            " - " .. Localize("loc_setting_checkbox_on"))
    end
end

mod.zipit2_execute_selected_wheel_option = mod.zipit2_execute_selected_wheel_option or function()
    local player_unit = _local_player_unit()

    if not player_unit or not ALIVE[player_unit] then
        return
    end

    local D = mod._zipit2_discovery or {}
    local S = mod._zipit2_settings or {}
    local option_by_value = D.com_wheel_option_by_value or {}
    local selected_value = S.selected_wheel_option
    local option = option_by_value[selected_value] or option_by_value[D.com_wheel_default_option]

    if type(option) ~= "table" then
        return
    end

    _trigger_selected_wheel_option_tag(option)
    _trigger_selected_wheel_option_chat(option)
    _trigger_selected_wheel_option_voice(option, player_unit)
    _register_selected_wheel_option_telemetry(option)
end

mod.zipit2_register_audio_hooks = mod.zipit2_register_audio_hooks or function()
    if mod._zipit2_audio_hooks_registered then
        return
    end

    mod._zipit2_audio_hooks_registered = true

    mod:hook_safe("HudElementSmartTagging", "update", function(self)
        mod.zipit2_hud_element_smart_tagging = self
    end)

    mod:hook_safe("HudElementSmartTagging", "destroy", function(self)
        if mod.zipit2_hud_element_smart_tagging == self then
            mod.zipit2_hud_element_smart_tagging = nil
        end
    end)

    mod:hook(Vo, "on_demand_vo_event", function(func, unit, concept, trigger_id, target_unit)
        if not mod:is_enabled() then
            return func(unit, concept, trigger_id, target_unit)
        end

        if mod.zipit2_should_mute_bot and mod.zipit2_should_mute_bot(unit) then
            return
        end

        local voice_profile = _voice_profile_from_unit(unit)

        if voice_profile then
            if mod.zipit2_should_mute_voice_profile(voice_profile, concept) then
                return
            end

            if _should_throttle_other_player_com_wheel(unit, voice_profile, concept) then
                return
            end
        elseif mod.zipit2_should_mute_on_demand_sound_event(concept) then
            return
        end

        return func(unit, concept, trigger_id, target_unit)
    end)

    mod:hook(Vo, "enemy_generic_vo_event", function(func, unit, trigger_id, breed_name_or_nil, target_distance)
        if not mod:is_enabled() then
            return func(unit, trigger_id, breed_name_or_nil, target_distance)
        end

        if _should_mute_enemy_generic_vo(unit, breed_name_or_nil) then
            return
        end

        return func(unit, trigger_id, breed_name_or_nil, target_distance)
    end)

    mod:hook(Vo, "enemy_alerted_idle_event", function(func, unit, breed_name)
        if not mod:is_enabled() then
            return func(unit, breed_name)
        end

        if _should_mute_enemy_generic_vo(unit, breed_name) then
            return
        end

        return func(unit, breed_name)
    end)

    mod:hook(ChatManager, "mute_local_mic", function(func, self, mute, ...)
        if mod:is_enabled() and mod.zipit2_is_voice_chat_output_muted and mod.zipit2_is_voice_chat_output_muted() then
            mute = true
        end

        return func(self, mute, ...)
    end)

    mod:hook(ChatManager, "mic_volume_changed", function(func, self, ...)
        local result = func(self, ...)

        if mod:is_enabled() then
            _apply_current_voice_chat_output_volume()
        end

        return result
    end)

    mod:hook(ChatManager, "_handle_event", function(func, self, message, ...)
        local result = func(self, message, ...)

        if not mod:is_enabled() then
            return result
        end

        local Vivox = rawget(_G, "Vivox")
        local media_stream_updated = Vivox and Vivox.EventType_MEDIA_STREAM_UPDATED

        if message and message.event == media_stream_updated then
            local session_handle = message.session_handle
            local session = self._sessions and session_handle and self._sessions[session_handle]
            local session_media_state = session and session.session_media_state

            if session_media_state == ChatManagerConstants.ChannelConnectionState.CONNECTED then
                _refresh_voice_chat_for_game_mode(self)
            end
        end

        return result
    end)

    mod:hook("HudElementSmartTagging", "_play_tag_sound", function(func, self, tag_instance, event_name)
        if not mod:is_enabled() then
            return func(self, tag_instance, event_name)
        end

        if mod.zipit2_should_mute_ping_tag_sounds() then
            return
        end

        return func(self, tag_instance, event_name)
    end)

    mod:hook("SmartTagSystem", "reply_tag", function(func, self, tag_id, replier_unit, reply_name)
        if not mod:is_enabled() then
            return func(self, tag_id, replier_unit, reply_name)
        end

        if reply_name == "dibs" then
            local tag = self._all_tags[tag_id]
            if tag then
                self:cancel_tag(tag_id, tag._tagger_unit)
                self:set_tag(tag._template.name, replier_unit, tag._target_unit)
                return
            end
        end

        return func(self, tag_id, replier_unit, reply_name)
    end)

    if WwiseWorld and type(WwiseWorld.trigger_resource_event) == "function" then
        mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
            if not mod:is_enabled() then
                return func(wwise_world, event_name, ...)
            end

            if _should_mute_player_nonverbal_sound_event(event_name) then
                return
            end

            if mod.zipit2_should_mute_breed_sound_event(event_name) then
                return
            end

            return func(wwise_world, event_name, ...)
        end)
    end
end
