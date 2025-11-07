local mod = get_mod("Bubblelicious")

mod:io_dofile("Bubblelicious/scripts/mods/Bubblelicious/utils/audio")
local Definitions = mod:io_dofile("Bubblelicious/scripts/mods/Bubblelicious/Bubblelicious_definitions")
local HudElementBubblelicious = class("HudElementBubblelicious", "HudElementBase")

HudElementBubblelicious.init = function(self, parent, draw_layer, start_scale, ...)
	HudElementBubblelicious.super.init(self, parent, draw_layer, start_scale, Definitions)

	mod.player_unit = mod.helper.get_player_unit()
end

-----------------------------------------------------------------------------------------------------------
-- HUD Update functions -----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------

-- variables for HUD update use
local ACTIVE_BUBBLES = mod.ACTIVE_BUBBLES
local infinity, round, sine = math.huge, math.round, math.sin
local HUD_POLL_INTERVAL = 0.05 --time (secs) between hud element updates (0 for max smoothness)
local last_hud_poll_time = -infinity --failsafe (-∞)
local player_pos = Vector3Box(Vector3(0, 0, 0)) --avoid creating a new Vector3Box every call
local vec3distance, unit_position, is_valid = Vector3.distance_squared, Unit.local_position, Unit.is_valid
local settings, framesettings, colors, decal = mod.settings, mod.hudsettings.frame, mod.colors, mod.decal

local latest_bubble = function()
	local latest_time, latest_bubble = -infinity, nil

	for _, bubble in pairs(ACTIVE_BUBBLES) do
		if bubble.start_time > latest_time then
			latest_bubble = bubble
			latest_time = bubble.start_time
		end
	end

	return latest_bubble
end

local closest_bubble = function()
	if not is_valid(mod.player_unit) then
		mod.player_unit = mod.helper.get_player_unit()
		if not is_valid(mod.player_unit) then return latest_bubble() end --fallback
	end

	player_pos:store(unit_position(mod.player_unit, 1))
	local closest_dist, closest_bubble = infinity, nil

	for _, bubble in pairs(ACTIVE_BUBBLES) do
		local dist = vec3distance(player_pos:unbox(), bubble.position:unbox())

		if dist < closest_dist then
			closest_dist = dist
			closest_bubble = bubble
		end
	end

	return closest_bubble
end

local get_relevant_bubble = function()
	--most common condition (cheapest)
	if mod.bubble_count == 1 then
		local _, bubble = next(ACTIVE_BUBBLES)
		return bubble
	end

	if settings.prioritize_closest_shield then return closest_bubble()
	else return latest_bubble() end
end

local update_widget_visuals = function(bubble, current_hp, widget, time)
	local below_threshold = current_hp <= settings.glow_threshold
	local wstyle = widget.style

	widget.visible = true
	widget.content.counter_text = round(bubble.rem_uptime)
	wstyle.ability_frame_container.material_values.progress = current_hp
	wstyle.ability_frame_inner.color = framesettings.frame_border_color
	wstyle.ability_frame_glow.color = framesettings.glow_color
	wstyle.ability_frame_container.color = colors.tint4
	wstyle.counter_text.text_color = framesettings.frame_border_color
	wstyle.ability_frame_glow.visible = below_threshold

	--pulse/breath effect logic
	if below_threshold and settings.border_pulse_enabled then
		local bubble_decal = bubble.decal
		local multiplier = sine(time * 3)
		local scale_mult = 1.130 + (0.130 * multiplier)
		local pulsed_size = framesettings.size * scale_mult

		wstyle.ability_frame_glow.size[1] = pulsed_size
		wstyle.ability_frame_glow.size[2] = pulsed_size

		if bubble_decal then
			decal.resize(bubble, bubble_decal, 1 + (0.05 * multiplier))
		end
	end

	--apply color shift/gradient
	if settings.color_shift_enabled then
		framesettings.glow_color = bubble.color
		framesettings.frame_border_color = bubble.color
	else
		framesettings.glow_color = colors.noshift
		framesettings.frame_border_color = colors.noshift
	end
end

local check_and_play_voiceline = function(bubble, current_hp, time)
	if bubble.has_played_vo then return end --early exit if already played
	if not bubble.is_my_bubble then return end --early exit if not our bubble
	if (time - bubble.start_time) < 1.5 then return end --dirty fix for premature voiceline trigger

	if settings.voiceline_enabled and current_hp <= settings.vline_threshold then
		mod.voicelines.play_shield_failing_voiceline()
		bubble.has_played_vo = true
	end
end

HudElementBubblelicious.update = function(self, dt, time, ui_renderer, render_settings, input_service)
	HudElementBubblelicious.super.update(self, dt, time, ui_renderer, render_settings, input_service)
	if (time - last_hud_poll_time) <= HUD_POLL_INTERVAL then return end

	last_hud_poll_time = time
	local bubblewidget = self._widgets_by_name.icon

	if mod.bubble_count <= 0 then
		bubblewidget.visible = false
		return
	end

	local active_bubble = get_relevant_bubble()

	if not active_bubble then
		bubblewidget.visible = false
		return
	end

	local current_hp = active_bubble.current_hp
	update_widget_visuals(active_bubble, current_hp, bubblewidget, time)
	check_and_play_voiceline(active_bubble, current_hp, time)
end

return HudElementBubblelicious