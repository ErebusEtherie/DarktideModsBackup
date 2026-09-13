
---@param module DLH_MissionSpeaker
return function(module)
	if module.manager then
		return module.manager
	end

	local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
	local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

	---@class DLH_MissionSpeakerState
	---@field visible boolean whether the recreated panel is shown / sliding in
	---@field speaker_id string? the currently shown speaker
	---@field subtitle string? subtitle line value, hidden if nil
	---@field subtitle_visible boolean whether the subtitle caption is revealed
	---@field native_speaker_is_active boolean whether the native mission speaker is active/visible
	---@field align_side "left"|"right" which screen edge the panel docks to
	---@field offset_y number vertical anchor offset (drop from the top) in design px
	---@field test_subtitle string? forced subtitle line for testing, overrides `subtitle`
	local State = {
		visible = false,
		speaker_id = nil,
		subtitle = nil,
		subtitle_visible = false,
		native_speaker_is_active = false,
		align_side = "right",
		offset_y = 0,
		test_subtitle = nil,
	}

	module.state = State

	---@class DLH_MissionSpeakerManager
	local Manager = {}

	function Manager.configure(config)
		config = config or {}
		if config.align_side ~= nil then
			module.state.align_side = config.align_side
		end
		if config.offset_y ~= nil then
			module.state.offset_y = config.offset_y
		end
		if config.test_subtitle ~= nil then
			module.state.test_subtitle = config.test_subtitle
		end
	end

	function Manager.set_visible(visible)
		module.state.visible = visible == true
	end

	function Manager.is_visible()
		return module.state.visible == true
	end

	function Manager.current_id()
		return module.state.speaker_id or module.constants.LOGIC.DEFAULT_SPEAKER
	end

	function Manager.resolve_speaker(speaker_id)
		local voice_settings = speaker_id and DialogueSpeakerVoiceSettings[speaker_id]

		return {
			icon = (voice_settings and voice_settings.icon) or module.constants.LOGIC.DEFAULT_PORTRAIT,
			full_name = voice_settings and voice_settings.full_name or module.constants.LOGIC.DEFAULT_SPEAKER,
		}
	end

	function Manager.set_speaker(speaker_id)
		local speaker = Manager.resolve_speaker(speaker_id)

		if speaker then
			module.state.speaker_id = speaker_id
		end
	end

	function Manager.cycle_active_speakers()
		local count = #module.constants.LOGIC.SPEAKERS

		if count == 0 then
			return
		end

		local start_index = module.constants.LOGIC.SPEAKER_INDEX[module.manager.current_id()] or 0
		local next_index = (start_index % count) + 1
		local next_speaker = module.constants.LOGIC.SPEAKERS[next_index]

		if next_speaker then
			Manager.set_speaker(next_speaker.id)
			Manager.set_visible(true)
		end
	end

	function Manager.subtitle()
		local test_sub = module.state.test_subtitle

		if test_sub and test_sub ~= "" then
			return test_sub
		end

		return module.state.subtitle
	end

	function Manager.set_subtitle(subtitle)
		module.state.subtitle = type(subtitle) == "string" and subtitle or nil
	end

	function Manager.reset()
		module.state.visible = false
		module.state.speaker_id = nil
		module.state.subtitle = nil
		module.state.subtitle_visible = false
		module.state.native_speaker_is_active = false
	end

	function Manager.set_game_speaker_active(active)
		module.state.native_speaker_is_active = active == true
	end

	function Manager.is_game_speaker_active()
		return module.state.native_speaker_is_active == true
	end

	local DEBUG_SPEAKER = "sergeant_a"

	local MISSION_GIVER_ROUTES = { [1] = true, [21] = true }

	local MISSION_GIVER_VOICES = {}
	do
		local voices = DialogueBreedSettings.mission_giver and DialogueBreedSettings.mission_giver.wwise_voices
		if voices then
			for i = 1, #voices do
				MISSION_GIVER_VOICES[voices[i]] = true
			end
		end
	end

	local _show_native = false
	local _timer = 0
	local SPEAKER_POLL_INTERVAL = 0.15

	function Manager.poll_native_speaker_state(dt)

		_timer = _timer - dt
		if _timer <= 0 then
			_timer = SPEAKER_POLL_INTERVAL
			module.manager.set_game_speaker_active(module.manager.native_is_active())
		end
	end

	local function get_dialogue_system()
		local _state = Managers.state
		local extension = _state and _state.extension
		if not extension then
			return nil
		end
		return extension:system("dialogue_system")
	end

	function Manager.native_is_active()
		local system = get_dialogue_system()
		if not system or not system.playing_dialogues_array then
			return false
		end

		local ok, playing = pcall(system.playing_dialogues_array, system)
		if not ok or not playing then
			return false
		end

		for i = 1, #playing do
			local dialogue = playing[i]
			if
				dialogue
				and MISSION_GIVER_ROUTES[dialogue.wwise_route]
				and MISSION_GIVER_VOICES[dialogue.speaker_name]
			then
				return true
			end
		end

		return false
	end

	function Manager.toggle_native_hud()
		_show_native = not _show_native
	end

	function Manager.hook_native_speaker_system(mod)
		mod.dl.game_hooks.hook(
			CLASS.HudElementMissionSpeakerPopup,
			"_sync_active_speaker",
			function(func, self, dt, t, ui_renderer, render_settings, input_service)
				if not _show_native then
					return func(self, dt, t, ui_renderer, render_settings, input_service)
				end

				if self._speaker_name ~= DEBUG_SPEAKER then
					self._speaker_name = DEBUG_SPEAKER

					local voice_settings = DialogueSpeakerVoiceSettings[DEBUG_SPEAKER]
					local full_name = self:_localize(voice_settings and voice_settings.full_name)
					local icon = voice_settings and voice_settings.icon

					self:_mission_speaker_start(full_name, icon)
					self._is_speaking = true
				end
			end
		)
	end

	module.manager = Manager

	return Manager
end
