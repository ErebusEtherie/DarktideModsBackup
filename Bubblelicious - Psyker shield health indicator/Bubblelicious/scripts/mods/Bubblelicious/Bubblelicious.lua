local mod = get_mod("Bubblelicious")

mod:io_dofile("Bubblelicious/scripts/mods/Bubblelicious/utils/helper")
mod:io_dofile("Bubblelicious/scripts/mods/Bubblelicious/utils/colors_decals")
local psyker_talents = require("scripts/settings/talent/talent_settings_psyker")
local shield_settings = psyker_talents.psyker_3.combat_ability

---------------------------------------------------------------------------------------------------------------------------------
-- Initiate User Settings -------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

mod.settings = mod:persistent_table("settings")
mod.player_unit, mod.bubble_count = nil, 0
local helper = mod.helper

mod.on_all_mods_loaded = function()
	local setting_names = {
		"show_as_non_psyker",
		"only_my_shields",
		"prioritize_closest_shield",
		"color_shift_enabled",
		"reflect_status_enabled",
		"border_pulse_enabled",
		"voiceline_enabled",
		"custom_colors_enabled",
	}

	for _, setting in ipairs(setting_names) do
		mod.settings[setting] = mod:get(setting)
	end

	mod.player_unit = helper.get_player_unit()
	mod.bubble_count = helper.count_bubbles(mod.ACTIVE_BUBBLES)
	mod.settings.glow_threshold  = mod:get("glow_threshold") / 100
	mod.settings.vline_threshold = mod:get("vline_threshold") / 100
	mod.settings.start_color = { 255, mod:get("start_color_red"), mod:get("start_color_green"), mod:get("start_color_blue") }
	mod.settings.mid_color   = { 255, mod:get("mid_color_red"),   mod:get("mid_color_green"),   mod:get("mid_color_blue")   }
	mod.settings.end_color   = { 255, mod:get("end_color_red"),   mod:get("end_color_green"),   mod:get("end_color_blue")   }
end

mod.on_setting_changed = function(setting)
	mod.settings[setting] = mod:get(setting)

	if setting:find("threshold") then
		mod.settings.glow_threshold  = mod:get("glow_threshold") / 100
		mod.settings.vline_threshold = mod:get("vline_threshold") / 100
		return
	end

	--color shifting must be enabled for outline/shield color change
	if setting == "reflect_status_enabled" then
		if mod:get("reflect_status_enabled") == true then
			mod:set("color_shift_enabled", true); mod.settings.color_shift_enabled = true; return
		end
	elseif setting == "color_shift_enabled" then
		if mod:get("color_shift_enabled") == false then
			mod:set("reflect_status_enabled", false); mod.settings.reflect_status_enabled = false; return
		end
	end

	if setting:find("start_color") then
		mod.settings.start_color = { 255, mod:get("start_color_red"), mod:get("start_color_green"), mod:get("start_color_blue") }
	elseif setting:find("mid_color") then
		mod.settings.mid_color   = { 255, mod:get("mid_color_red"),   mod:get("mid_color_green"),   mod:get("mid_color_blue")   }
	elseif setting:find("end_color") then
		mod.settings.end_color   = { 255, mod:get("end_color_red"),   mod:get("end_color_green"),   mod:get("end_color_blue")   }
	end
end

---------------------------------------------------------------------------------------------------------------------------------
-- HUD Element Registration -----------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

mod:register_hud_element({
	class_name = "HudElementBubblelicious",
	filename = "Bubblelicious/scripts/mods/Bubblelicious/HudElementBubblelicious",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
		"communication_wheel",
		"tactical_overlay"
	}
})

---------------------------------------------------------------------------------------------------------------------------------
-- Hooks: shield state/information functions ------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

local decal, colors, settings = mod.decal, mod.colors, mod.settings
local POLL_INTERVAL = 0.2 --time (secs) between shield hp & time updates
mod.ACTIVE_BUBBLES = mod:persistent_table("ACTIVE_BUBBLES") --for keeping track of alive/relevant shield(s)

-- bubble 'constructor'
mod:hook_safe(CLASS.ForceFieldExtension, "init", function(self, _ext_context, unit, _ext_data, game_session, game_object_id)
	local show_non_psyker = false

	if not helper.player_is_psyker() then
		if settings.show_as_non_psyker then
			show_non_psyker = true --flag to skip ownership test for non-psyker
		else
			return --early exit. player is non-psyker & doesn't want to see indicator
		end
	end

	--check if bubble belongs to us
	mod.player_unit = helper.get_player_unit()
	local is_my_bubble = self.owner_unit == mod.player_unit

	if not show_non_psyker then
		if settings.only_my_shields and not is_my_bubble then return end
		--early exit. don't track this bubble (it belongs to another psyker)
	end

	colors.set_progress_colors() --update colors to default or custom colors
	local is_bubble = self:is_sphere_shield()
	local max_health = is_bubble and shield_settings.sphere_health or shield_settings.health

	mod.ACTIVE_BUBBLES[self._unit] = {
		unit			= self._unit,
		owner_unit		= self.owner_unit,
		is_bubble		= is_bubble,
		is_my_bubble	= is_my_bubble,
		current_hp		= 1, --normalized hp
		rem_health 		= max_health,
		max_health 		= max_health,
		rem_uptime		= self._max_duration,
		max_uptime 		= self._max_duration,
		position		= self._position, --stored as Vector3Box internally
		g_session 		= game_session,
		g_obj_id 		= game_object_id,
		last_poll_time 	= -math.huge,
		start_time 		= Managers.time:time("main"), --for finding latest bubble
		has_played_vo	= not settings.voiceline_enabled, --flip to quickly exit voiceline check
		color			= { 255, 255, 255, 255 }
	}

	if settings.color_shift_enabled and settings.reflect_status_enabled and is_bubble then
		decal.initialize(mod.ACTIVE_BUBBLES[self._unit], false)
	end

	mod.bubble_count = helper.count_bubbles(mod.ACTIVE_BUBBLES)
end)

-- throttling polling to make a bit less of a performance impact
mod:hook_safe(CLASS.ForceFieldExtension, "fixed_update", function(self, _unit, _dt, currtime)
	local bubble = mod.ACTIVE_BUBBLES[self._unit]
	if not bubble then return end
	if (currtime - bubble.last_poll_time) <= POLL_INTERVAL then return end

	if not self._is_server then
		--FIXME: right after a shield is spawned, can return 0 for a few frames, wrongly triggering a voiceline
		bubble.rem_health = GameSession.game_object_field(bubble.g_session, bubble.g_obj_id, "health")
	else
		bubble.rem_health = self._health_extension and self._health_extension:current_health() or 1
	end

	bubble.last_poll_time = currtime
	bubble.rem_uptime = self:remaining_duration()
	bubble.current_hp = bubble.rem_health / bubble.max_health

	if settings.color_shift_enabled then
		colors.manage_colors(bubble)

		if settings.reflect_status_enabled then
			decal.set_color(bubble)
		end
	end
end)

local destroy_bubble = function(unit)
	local bubble = mod.ACTIVE_BUBBLES[unit]
	if not bubble then return end

	decal.destroy(bubble)
	mod.ACTIVE_BUBBLES[unit] = nil
	mod.bubble_count = helper.count_bubbles(mod.ACTIVE_BUBBLES)
end

-- upon shield death nullify it for garbage collection
mod:hook_safe(CLASS.ForceFieldExtension, "on_death", function(self)
	destroy_bubble(self._unit)
end)

-- clean up shields belonging to psykers that left the game
mod:hook_safe(CLASS.SessionClient, "rpc_peer_left_session", function(_self, _channel_id, peer_id)
	local is_psyker, gone_player_unit = helper.player_is_psyker(peer_id)
	if not is_psyker then return end

	for key, bubble in pairs(mod.ACTIVE_BUBBLES) do
		if bubble.owner_unit == gone_player_unit then
			destroy_bubble(key)
		end
	end
end)

-- clear bubble table & destroy decals when the inventory is opened
-- otherwise, indicator & decals will remain visible indefinitely
mod:hook_safe(CLASS.InventoryView, "init", function()
	decal.destroy_all(mod.ACTIVE_BUBBLES)
	table.clear(mod.ACTIVE_BUBBLES)
	mod.bubble_count = 0
end)

-- clear bubble table on exiting match
mod.on_game_state_changed = function(status, state)
	if status == "exit" and state == "GameplayStateRun" then
		table.clear(mod.ACTIVE_BUBBLES)
		mod.bubble_count = 0
	end
end