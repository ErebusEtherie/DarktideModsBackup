-- File: ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_audio.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local Vo = require("scripts/utilities/vo")

local rawget, _G, type, pairs = rawget, _G, type, pairs
local WwiseWorld = rawget(_G, "WwiseWorld")

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

        local voice_profile = _voice_profile_from_unit(unit)

        if voice_profile then
            if mod.zipit2_should_mute_voice_profile(voice_profile, concept) then
                return
            end
        elseif mod.zipit2_should_mute_on_demand_sound_event(concept) then
            return
        end

        return func(unit, concept, trigger_id, target_unit)
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

            if mod.zipit2_should_mute_breed_sound_event(event_name) then
                return
            end

            return func(wwise_world, event_name, ...)
        end)
    end
end
