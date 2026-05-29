local mod = get_mod("SteadyHands")

local WeaponMovementState = require("scripts/extension_systems/weapon/utilities/weapon_movement_state")

local presets = {
	vanilla_plus = {
		camera_recoil_scale = 75,
		weapon_recoil_scale = 80,
		ads_sway_scale = 85,
		hipfire_sway_scale = 90,
		recoil_blend_speed = 55,
		reduce_camera_shake = false,
		reduce_screen_bob = false,
	},
	balanced = {
		camera_recoil_scale = 45,
		weapon_recoil_scale = 50,
		ads_sway_scale = 55,
		hipfire_sway_scale = 65,
		recoil_blend_speed = 75,
		reduce_camera_shake = true,
		reduce_screen_bob = false,
	},
	minimal = {
		camera_recoil_scale = 18,
		weapon_recoil_scale = 20,
		ads_sway_scale = 22,
		hipfire_sway_scale = 30,
		recoil_blend_speed = 90,
		reduce_camera_shake = true,
		reduce_screen_bob = true,
	},
}

local runtime = {
	camera_recoil_mult = 0.45,
	weapon_recoil_mult = 0.50,
	ads_sway_mult = 0.55,
	hipfire_sway_mult = 0.65,
	smoothing = 0.75,
	reduce_camera_shake = true,
	reduce_screen_bob = false,
	debug_mode = false,
	echo_runtime_values = false,
	last_debug_t = 0,
}

local state_by_extension = setmetatable({}, { __mode = "k" })

local function clamp(v, min_v, max_v)
	if v < min_v then
		return min_v
	elseif v > max_v then
		return max_v
	end

	return v
end

local function clamp01(v)
	return clamp(v, 0, 1)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function safe_echo(text)
	if runtime.debug_mode then
		mod:echo("[SteadyHands] " .. tostring(text))
	end
end

local function setting_percent_to_mult(value)
	return clamp01((value or 100) / 100)
end

local function get_extension_state(c_self)
	local state = state_by_extension[c_self]

	if not state then
		state = {
			last_dt = 0.016,
			last_t = 0,
			smoothed_pitch = nil,
			smoothed_yaw = nil,
			prev_pitch = 0,
			prev_yaw = 0,
			prev_influence = nil,
			movement_state = "standing_still",
			is_ads = false,
		}

		state_by_extension[c_self] = state
	end

	return state
end

local function get_bool_field(tbl, key)
	if type(tbl) ~= "table" then
		return nil
	end

	local value = rawget(tbl, key)

	if type(value) == "boolean" then
		return value
	end

	return nil
end

local function detect_ads(c_self)
	local afc = rawget(c_self, "_alternate_fire_component")
	if type(afc) == "table" then
		local keys = {
			"is_active",
			"active",
			"alternate_fire_active",
			"is_aiming",
			"aiming",
			"in_alternate_fire",
		}

		for i = 1, #keys do
			local value = get_bool_field(afc, keys[i])
			if value ~= nil then
				return value
			end
		end
	end

	local fpc = rawget(c_self, "_first_person_component")
	if type(fpc) == "table" then
		local keys = {
			"is_aiming",
			"aiming",
			"ads",
			"in_ads",
		}

		for i = 1, #keys do
			local value = get_bool_field(fpc, keys[i])
			if value ~= nil then
				return value
			end
		end
	end

	return false
end

local function get_smoothing_alpha(dt)
	dt = dt or 0.016

	local smooth = runtime.smoothing
	local response_speed = lerp(24, 4, smooth)
	local alpha = 1 - math.exp(-response_speed * dt)

	return clamp01(alpha)
end

local function get_reset_alpha(dt)
	dt = dt or 0.016

	local smooth = runtime.smoothing
	local response_speed = lerp(30, 6, smooth)
	local alpha = 1 - math.exp(-response_speed * dt)

	return clamp01(alpha)
end

local function get_visual_multiplier(state, recoil_settings)
	local recoil_mult = (runtime.camera_recoil_mult + runtime.weapon_recoil_mult) * 0.5
	local sway_mult = state.is_ads and runtime.ads_sway_mult or runtime.hipfire_sway_mult

	local influence_mult = 1

	if type(recoil_settings) == "table" and type(recoil_settings.new_influence_percent) == "number" then
		local influence = recoil_settings.new_influence_percent

		if state.prev_influence == nil then
			state.prev_influence = influence
		end

		local delta = math.abs(influence - state.prev_influence)

		if delta > 0.0001 then
			local damp = clamp01(1 - delta * 0.6)
			influence_mult = lerp(damp, 1, 0.35)
		end

		state.prev_influence = influence
	end

	local movement_mult = 1

	if state.movement_state == "crouch_still" or state.movement_state == "crouching_still" then
		movement_mult = 0.95
	elseif state.movement_state == "walking" or state.movement_state == "moving" then
		movement_mult = 0.92
	elseif state.movement_state == "running" or state.movement_state == "sprinting" then
		movement_mult = 0.88
	elseif state.movement_state == "in_air" then
		movement_mult = 0.90
	end

	return recoil_mult * sway_mult * influence_mult * movement_mult
end

local function update_runtime_from_settings()
	local preset_mode = mod:get("preset_mode") or "balanced"

	if preset_mode ~= "custom" and presets[preset_mode] then
		local p = presets[preset_mode]

		runtime.camera_recoil_mult = setting_percent_to_mult(p.camera_recoil_scale)
		runtime.weapon_recoil_mult = setting_percent_to_mult(p.weapon_recoil_scale)
		runtime.ads_sway_mult = setting_percent_to_mult(p.ads_sway_scale)
		runtime.hipfire_sway_mult = setting_percent_to_mult(p.hipfire_sway_scale)
		runtime.smoothing = setting_percent_to_mult(p.recoil_blend_speed)
		runtime.reduce_camera_shake = p.reduce_camera_shake
		runtime.reduce_screen_bob = p.reduce_screen_bob
	else
		runtime.camera_recoil_mult = setting_percent_to_mult(mod:get("camera_recoil_scale"))
		runtime.weapon_recoil_mult = setting_percent_to_mult(mod:get("weapon_recoil_scale"))
		runtime.ads_sway_mult = setting_percent_to_mult(mod:get("ads_sway_scale"))
		runtime.hipfire_sway_mult = setting_percent_to_mult(mod:get("hipfire_sway_scale"))
		runtime.smoothing = setting_percent_to_mult(mod:get("recoil_blend_speed"))
		runtime.reduce_camera_shake = mod:get("reduce_camera_shake")
		runtime.reduce_screen_bob = mod:get("reduce_screen_bob")
	end

	runtime.debug_mode = mod:get("debug_mode")
	runtime.echo_runtime_values = mod:get("echo_runtime_values")

	safe_echo(string.format(
		"Runtime applied | cam=%.2f weapon=%.2f ads=%.2f hip=%.2f smooth=%.2f",
		runtime.camera_recoil_mult,
		runtime.weapon_recoil_mult,
		runtime.ads_sway_mult,
		runtime.hipfire_sway_mult,
		runtime.smoothing
	))
end

local function cycle_preset_value(current)
	if current == "vanilla_plus" then
		return "balanced"
	elseif current == "balanced" then
		return "minimal"
	elseif current == "minimal" then
		return "custom"
	else
		return "vanilla_plus"
	end
end

function mod.cycle_preset_hotkey()
	local current = mod:get("preset_mode") or "balanced"
	local next_value = cycle_preset_value(current)

	mod:set("preset_mode", next_value)
	update_runtime_from_settings()

	mod:echo("Steady Hands preset: " .. tostring(next_value))
end

function mod.dump_debug_hotkey()
	mod:echo("=== Steady Hands Debug Dump ===")
	mod:echo(string.format(
		"Runtime | cam=%.2f weapon=%.2f ads=%.2f hip=%.2f smooth=%.2f shake=%s bob=%s",
		runtime.camera_recoil_mult,
		runtime.weapon_recoil_mult,
		runtime.ads_sway_mult,
		runtime.hipfire_sway_mult,
		runtime.smoothing,
		tostring(runtime.reduce_camera_shake),
		tostring(runtime.reduce_screen_bob)
	))
end

mod.on_setting_changed = function()
	update_runtime_from_settings()
end

mod.on_enabled = function()
	update_runtime_from_settings()
end

mod.on_disabled = function()
end

update_runtime_from_settings()

mod:hook_safe("PlayerUnitWeaponRecoilExtension", "fixed_update", function(c_self, unit, dt, t)
	local state = get_extension_state(c_self)

	state.last_dt = dt or state.last_dt or 0.016
	state.last_t = t or state.last_t or 0
	state.is_ads = detect_ads(c_self)

	local movement_state_component = rawget(c_self, "_movement_state_component")
	local inair_state_component = rawget(c_self, "_inair_state_component")
	local locomotion_component = rawget(c_self, "_locomotion_component")

	if movement_state_component and locomotion_component and inair_state_component then
		local ok, movement_state = pcall(
			WeaponMovementState.translate_movement_state_component,
			movement_state_component,
			locomotion_component,
			inair_state_component
		)

		if ok and movement_state then
			state.movement_state = movement_state
		end
	end

	if runtime.echo_runtime_values and t and t - runtime.last_debug_t > 5 then
		runtime.last_debug_t = t
		safe_echo("fixed_update active | movement=" .. tostring(state.movement_state) .. " ads=" .. tostring(state.is_ads))
	end
end)

mod:hook("PlayerUnitWeaponRecoilExtension", "_update_offset", function(func, c_self, recoil_component, recoil_control_component, recoil_settings, t, ...)
	func(c_self, recoil_component, recoil_control_component, recoil_settings, t, ...)

	if type(recoil_component) ~= "table" then
		return
	end

	local state = get_extension_state(c_self)
	local dt = state.last_dt or 0.016

	local raw_pitch = recoil_component.pitch_offset or 0
	local raw_yaw = recoil_component.yaw_offset or 0

	local visual_mult = get_visual_multiplier(state, recoil_settings)

	local desired_pitch = raw_pitch * visual_mult
	local desired_yaw = raw_yaw * visual_mult

	local prev_pitch = state.smoothed_pitch
	local prev_yaw = state.smoothed_yaw

	if prev_pitch == nil then
		prev_pitch = desired_pitch
	end

	if prev_yaw == nil then
		prev_yaw = desired_yaw
	end

	local pitch_is_resetting = math.abs(desired_pitch) < math.abs(prev_pitch)
	local yaw_is_resetting = math.abs(desired_yaw) < math.abs(prev_yaw)

	local pitch_alpha = pitch_is_resetting and get_reset_alpha(dt) or get_smoothing_alpha(dt)
	local yaw_alpha = yaw_is_resetting and get_reset_alpha(dt) or get_smoothing_alpha(dt)

	local smoothed_pitch = lerp(prev_pitch, desired_pitch, pitch_alpha)
	local smoothed_yaw = lerp(prev_yaw, desired_yaw, yaw_alpha)

	if runtime.reduce_camera_shake then
		smoothed_pitch = smoothed_pitch * 0.9
		smoothed_yaw = smoothed_yaw * 0.9
	end

	recoil_component.pitch_offset = smoothed_pitch
	recoil_component.yaw_offset = smoothed_yaw

	state.prev_pitch = raw_pitch
	state.prev_yaw = raw_yaw
	state.smoothed_pitch = smoothed_pitch
	state.smoothed_yaw = smoothed_yaw

	if runtime.echo_runtime_values and t and t - runtime.last_debug_t > 5 then
		runtime.last_debug_t = t
		safe_echo(string.format(
			"_update_offset | raw_pitch=%.4f raw_yaw=%.4f final_pitch=%.4f final_yaw=%.4f mult=%.3f movement=%s ads=%s",
			raw_pitch,
			raw_yaw,
			smoothed_pitch,
			smoothed_yaw,
			visual_mult,
			tostring(state.movement_state),
			tostring(state.is_ads)
		))
	end
end)