-- File: ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_dialogue.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
local DialogueExtension = require("scripts/extension_systems/dialogue/dialogue_extension")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")
local DialogueSystemSubtitle = require("scripts/extension_systems/dialogue/dialogue_system_subtitle")
local HudElementMissionSpeakerPopup = require(
    "scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup")

local type = type

local function _first_non_empty_string(...)
    local count = select("#", ...)

    for i = 1, count do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end

    return nil
end

local function _dialogue_identifier_from_event(event)
    if type(event) ~= "table" then
        return nil
    end

    return _first_non_empty_string(
        event.concept,
        event.dialogue_name,
        event.dialogue_event_name,
        event.currently_playing_subtitle,
        event.category,
        event.sound_event
    )
end

local function _dialogue_identifier_from_dialogue(dialogue)
    if type(dialogue) ~= "table" then
        return nil
    end

    return _first_non_empty_string(
        dialogue.concept,
        dialogue.dialogue_name,
        dialogue.dialogue_event_name,
        dialogue.currently_playing_subtitle,
        dialogue.category,
        dialogue.sound_event
    )
end

mod.zipit2_try_hook_mourningstar_dialogue_improved = mod.zipit2_try_hook_mourningstar_dialogue_improved or function()
    if mod._zipit2_mourningstar_show_hooked then
        return
    end

    local mourningstar_dialogue_improved = get_mod("Mourningstar_dialogue_improved")
    if not mourningstar_dialogue_improved or type(mourningstar_dialogue_improved.showCustomRadio) ~= "function" then
        return
    end

    mod._zipit2_mourningstar_show_hooked = true
    mod._zipit2_mourningstar_mod = mourningstar_dialogue_improved

    mod:hook(mourningstar_dialogue_improved, "showCustomRadio", function(func, ...)
        if not mod:is_enabled() then
            return func(...)
        end

        local playing_dialogue = mourningstar_dialogue_improved.playing_dialogue
        local speaker_name = playing_dialogue and playing_dialogue.speaker_name
        local identifier = _dialogue_identifier_from_dialogue(playing_dialogue)

        if mod.zipit2_should_suppress_muted_voice_ui(speaker_name, identifier) then
            return
        end

        return func(...)
    end)
end

mod.zipit2_register_dialogue_hooks = mod.zipit2_register_dialogue_hooks or function()
    if mod._zipit2_dialogue_hooks_registered then
        return
    end

    mod._zipit2_dialogue_hooks_registered = true

    mod.zipit2_try_hook_mourningstar_dialogue_improved()

    mod:hook(DialogueExtension, "play_event", function(func, self, event)
        mod.zipit2_try_hook_mourningstar_dialogue_improved()

        if not mod:is_enabled() then
            return func(self, event)
        end

        local voice_profile = self and self._vo_profile_name
        local identifier = _dialogue_identifier_from_event(event)

        if voice_profile and mod.zipit2_should_mute_voice_profile(voice_profile, identifier) then
            local st = mod._zipit2_state

            if st.in_lobby_view or st.in_mission_intro_view or st.in_briefing_state then
                st.blocked_briefing_vo = true
            end

            return
        end

        return func(self, event)
    end)

    mod:hook(DialogueSystemSubtitle, "add_playing_localized_dialogue", function(func, self, speaker_name, dialogue)
        mod.zipit2_try_hook_mourningstar_dialogue_improved()

        if not mod:is_enabled() then
            return func(self, speaker_name, dialogue)
        end

        local identifier = _dialogue_identifier_from_dialogue(dialogue)

        if mod.zipit2_should_suppress_muted_voice_ui(speaker_name, identifier) then
            return
        end

        return func(self, speaker_name, dialogue)
    end)

    mod:hook(HudElementMissionSpeakerPopup, "_sync_active_speaker",
        function(func, self, dt, t, ui_renderer, render_settings, input_service)
            mod.zipit2_try_hook_mourningstar_dialogue_improved()

            if not mod:is_enabled() or mod._zipit2_settings.subtitles_enabled then
                return func(self, dt, t, ui_renderer, render_settings, input_service)
            end

            local extension_manager = Managers.state.extension
            local dialogue_system = extension_manager and extension_manager:system("dialogue_system")

            if not dialogue_system then
                return
            end

            local mission_giver_speaker_name
            local playing_dialogues_array = dialogue_system:playing_dialogues_array()
            local mission_givers_settings = DialogueBreedSettings.mission_giver
            local mission_giver_voices = mission_givers_settings and mission_givers_settings.wwise_voices or {}

            for i = 1, #playing_dialogues_array do
                local currently_playing = playing_dialogues_array[i]
                local current_speaker_name = currently_playing and currently_playing.speaker_name
                local current_identifier = _dialogue_identifier_from_dialogue(currently_playing)

                if type(current_speaker_name) == "string"
                    and not mod.zipit2_should_suppress_muted_voice_ui(current_speaker_name, current_identifier)
                then
                    if current_speaker_name == self._speaker_name then
                        mission_giver_speaker_name = self._speaker_name
                        break
                    end

                    if table.contains(mission_giver_voices, current_speaker_name) then
                        local ww_route = currently_playing.wwise_route

                        if ww_route == 1 or ww_route == 21 then
                            mission_giver_speaker_name = current_speaker_name
                        end
                    end
                end
            end

            if mission_giver_speaker_name ~= self._speaker_name then
                self._speaker_name = mission_giver_speaker_name
                self:_mission_speaker_stop()
                self._is_speaking = false
            else
                return
            end

            if not mission_giver_speaker_name then
                return
            end

            local speaker_voice_settings = DialogueSpeakerVoiceSettings[mission_giver_speaker_name]
            local mission_giver_icon = speaker_voice_settings and speaker_voice_settings.icon
            local mission_giver_full_name = speaker_voice_settings and speaker_voice_settings.full_name
            local mission_giver_full_name_localized = self:_localize(mission_giver_full_name)

            self:_mission_speaker_start(mission_giver_full_name_localized, mission_giver_icon)
            self._is_speaking = true
        end)
end
