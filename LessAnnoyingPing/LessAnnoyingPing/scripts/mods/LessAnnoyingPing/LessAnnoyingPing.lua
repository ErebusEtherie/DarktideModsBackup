local mod = get_mod("LessAnnoyingPing")

mod.is_hooked = false
mod.last_ping_time = os.clock()
mod.delay = 0.500
mod.last_game_object_id = 0
mod.replace_sound = true
mod.same_target_skip = true
mod.same_target_delay = 0
mod.enable_debug_mode = false

local function get_settings()
	mod.delay = mod:get("setting_delay") / 1000.0
	mod.replace_sound = mod:get("setting_sound_replace")
	mod.same_target_skip = mod:get("setting_skip_same_target")
	mod.skip_self_sound = mod:get("setting_skip_self_sound")
	mod.sound_to_play = mod:get("setting_sound_to_play")
	mod.same_target_delay = mod:get("setting_delay_same") / 1000.0
	mod.enable_debug_mode = mod:get("setting_enable_debug_mode")

	if mod.enable_debug_mode then
		mod:dump(mod)
	end
end

mod.on_setting_changed = function()
	get_settings()
end

local function print_debug(...)
	if mod.enable_debug_mode then
		print("[LessAnnoyingPing]", ...)
	end
end

mod.on_enabled = function()
	print_debug("Enabling hooks")
	--prob not needed
	mod:enable_all_hooks()
end

mod.on_disabled = function()
	print_debug("Disabling hooks")
	--prob not needed
	mod:disable_all_hooks()
end

mod:hook_require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging", function(HudElementSmartTagging)
	if not mod.is_hooked then
		get_settings()
		mod.is_hooked = true
		print_debug("Hooking LessAnnoyingPing")
		-- place last in load order to call hook first (LIFO)
		mod:hook(HudElementSmartTagging, "_play_tag_sound", function(orig_func, self, tag_instance, event_name)
			local game_object_id = Managers.state.unit_spawner:game_object_id(tag_instance:target_unit())
			if mod.skip_self_sound then
				local player_self = self._parent:player()
				local tagger_player = tag_instance:tagger_player()
				local is_my_tag = tagger_player and tagger_player:unique_id() == player_self:unique_id()
				--print_debug("is_my_tag", is_my_tag, tagger_player:unique_id(), player_self:unique_id())
				if is_my_tag then
					return
				end
			end
			local ping_time_diff = os.clock() - mod.last_ping_time
			if
				mod.same_target_skip
				and (game_object_id == mod.last_game_object_id)
				and (ping_time_diff < mod.same_target_delay)
			then
				print_debug("pinged too soon", ping_time_diff) --skip
				return
			end
			mod.last_game_object_id = game_object_id
			--print_debug("game_object_id",game_object_id)
			if
				mod.replace_sound
				and (
					event_name == "wwise/events/ui/play_smart_tag_location_threat_enter"
					or event_name == "wwise/events/ui/play_smart_tag_location_threat_enter_others"
				)
			then
				--event_name = "wwise/events/ui/play_smart_tag_location_default_enter"
				event_name = mod.sound_to_play
				--SEE scripts\settings\ui\ui_sound_events.lua for list of sound events
			end

			if ping_time_diff >= mod.delay then
				print_debug("game_object_id", game_object_id, ping_time_diff)
				mod.last_ping_time = os.clock()
				-- call original/next function in hook chain
				return orig_func(self, tag_instance, event_name)
			end
		end)
	end
end)
