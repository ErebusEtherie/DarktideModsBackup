-- bot_identity_ui.lua
--
-- Presentation-only identity for Pilgrimage companions.
--
-- Darktide bakes the grey [BOT] suffix into a bot's synchronized profile name,
-- and subtitles normally identify AI players by their voice/class short name.
-- Rewriting either network value would be needlessly invasive. Instead, this
-- module changes only local presentation strings:
--
--   * squad panel names lose the generated [BOT] suffix;
--   * the class line becomes the preset's public faction/family designation;
--   * subtitles use the preset's individual display name.
--
-- All three paths require the _pilgrimage_preset sentinel. Vanilla bots, human
-- players and bots owned by another mod retain their ordinary presentation.

local M = {}

local _mod
local _hooks
local _preset
local _debug_log = function() end

local function _profile_for_player(player)
	if not player then return nil end

	if type(player.profile) == "function" then
		local ok, profile = pcall(player.profile, player)
		if ok and type(profile) == "table" then return profile end
	end

	return type(player._profile) == "table" and player._profile or nil
end

local function _preset_for_player(player)
	local profile = _profile_for_player(player)
	local preset_id = profile and profile._pilgrimage_preset

	if type(preset_id) ~= "string" or preset_id == "" then return nil end
	return _preset and _preset.get and _preset.get(preset_id) or nil
end

local function _player_for_unit(unit)
	if not unit then return nil end

	local managers = rawget(_G, "Managers")
	local state = managers and managers.state
	local spawn_manager = state and state.player_unit_spawn
	if not spawn_manager then return nil end

	local ok_is_player, is_player = pcall(
		spawn_manager.is_player_unit, spawn_manager, unit)
	if not ok_is_player or not is_player then return nil end

	local ok_owner, player = pcall(spawn_manager.owner, spawn_manager, unit)
	return ok_owner and player or nil
end

local function _strip_bot_suffix(name)
	if type(name) ~= "string" then return name end

	-- Fatshark's generated suffix currently has the form
	-- " {#color(...)}[BOT]{#reset()}". Match the rich-text wrapper rather than
	-- the localized word BOT, so non-English clients are covered as well.
	local clean = name:gsub(
		"%s*{#color%b()}%[[^%]]+%]{#reset%b()}%s*$", "")

	-- Plain fallback for UI paths or other mods that remove the colour markup.
	clean = clean:gsub("%s*%[[Bb][Oo][Tt]%]%s*$", "")
	return clean
end

local function _install_player_panel(HudElementPlayerPanelBase)
	if not HudElementPlayerPanelBase
		or _hooks.claim(HudElementPlayerPanelBase,
			"_pilgrimage_bot_identity_ui") then
		return
	end

	_mod:hook(HudElementPlayerPanelBase, "_set_player_name",
		function(func, self, name, current_level)
			if _preset_for_player(self and self._player) then
				name = _strip_bot_suffix(name)
			end
			return func(self, name, current_level)
		end)

	_mod:hook(HudElementPlayerPanelBase, "_set_character_text",
		function(func, self, character_title, ui_renderer)
			local preset = _preset_for_player(self and self._player)
			if preset and _preset.hud_designation then
				local public_designation = _preset.hud_designation(preset)
				if type(public_designation) == "string"
					and public_designation ~= "" then
					character_title = public_designation
				end
			end
			return func(self, character_title, ui_renderer)
		end)
end

local function _install_bot_player(BotPlayer)
	if not BotPlayer or type(BotPlayer.name) ~= "function"
		or _hooks.claim(BotPlayer, "_pilgrimage_bot_identity_name") then
		return
	end

	_mod:hook(BotPlayer, "name", function(func, self)
		local preset = _preset_for_player(self)
		local display_name = preset and preset.display_name
		if type(display_name) == "string" and display_name ~= "" then
			-- ProfileSynchronizerHost appends the localized grey bot tag to the
			-- synchronized display_name. Returning the authored name here changes
			-- every local name consumer consistently without rewriting the profile
			-- or its network data.
			return display_name
		end
		return func(self)
	end)
end

local function _install_subtitles(ConstantElementSubtitles)
	if not ConstantElementSubtitles
		or _hooks.claim(ConstantElementSubtitles,
			"_pilgrimage_bot_identity_subtitles") then
		return
	end

	local DialogueSpeakerVoiceSettings = require(
		"scripts/settings/dialogue/dialogue_speaker_voice_settings")

	_mod:hook(ConstantElementSubtitles, "_add_subtitle",
		function(func, self, currently_playing, secondary_subtitle)
			local player = currently_playing and _player_for_unit(
				currently_playing.currently_playing_unit)
			local preset = _preset_for_player(player)
			local display_name = preset and preset.display_name
			local speaker_name = currently_playing
				and currently_playing.speaker_name
			local voice_settings = speaker_name
				and DialogueSpeakerVoiceSettings[speaker_name]
			local short_name = voice_settings and voice_settings.short_name

			if type(display_name) ~= "string" or display_name == ""
				or type(short_name) ~= "string" then
				return func(self, currently_playing, secondary_subtitle)
			end

			-- The original method localizes the voice's class short-name. For this
			-- one synchronous call, intercept only that exact localization key and
			-- return the companion name. The dialogue event and NetworkLookup key
			-- are never modified.
			local own_localize = rawget(self, "_localize")
			local inherited_localize = self._localize
			self._localize = function(instance, key, ...)
				if key == short_name then return display_name end
				return inherited_localize(instance, key, ...)
			end

			local ok, result = pcall(
				func, self, currently_playing, secondary_subtitle)
			self._localize = own_localize

			if not ok then error(result) end
			return result
		end)
end

function M.init(deps)
	_mod = deps.mod
	_hooks = deps.hooks
	_preset = deps.preset
	_debug_log = deps.debug_log or _debug_log

	_hooks.require_now(
		"scripts/ui/hud/elements/player_panel_base/hud_element_player_panel_base",
		_install_player_panel)
	_hooks.require_now(
		"scripts/managers/player/bot_player",
		_install_bot_player)
	_hooks.require_now(
		"scripts/ui/constant_elements/elements/subtitles/constant_element_subtitles",
		_install_subtitles)

	_debug_log("bots", 0,
		"companion HUD and subtitle identity hooks installed", 0, "info")
end

return M
