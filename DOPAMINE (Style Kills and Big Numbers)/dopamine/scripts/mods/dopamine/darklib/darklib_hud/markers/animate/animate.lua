

local math_sin = math.sin
local math_cos = math.cos
local math_tan = math.tan
local math_rad = math.rad

---@param module DLH_Marker
return function(module)
	if module.animate then
		return module.animate
	end

	---@class DLH_MarkerAnimateLib
	local Animate = {}

	local function with_defaults(defaults, opts)
		local out = {}
		for key, value in pairs(defaults) do
			out[key] = value
		end
		if opts then
			for key, value in pairs(opts) do
				out[key] = value
			end
		end
		return out
	end

	local function distance_alpha(style, dist)
		local max_distance = style.max_distance

		if max_distance <= 0 then
			return 1
		end

		if dist >= max_distance then
			return 0
		end

		local fade_in_distance = style.fade_in_distance
		if fade_in_distance > max_distance then
			fade_in_distance = max_distance
		end

		local full_alpha_at = max_distance - fade_in_distance
		if fade_in_distance > 0 and dist > full_alpha_at then
			return 1 - (dist - full_alpha_at) / fade_in_distance
		end

		return 1
	end

	Animate.distance_alpha = distance_alpha

	local function distance_ramp(dist, near_distance, far_distance, near_value, far_value)
		if dist <= near_distance then
			return near_value
		end

		if dist >= far_distance then
			return far_value
		end

		local span = far_distance - near_distance
		if span <= 0 then
			return far_value
		end

		return near_value + (far_value - near_value) * ((dist - near_distance) / span)
	end

	Animate.distance_ramp = distance_ramp

	local function distance_scale(style, dist)
		local far_distance = style.scale_far_distance

		if far_distance <= 0 then
			return 1
		end

		return distance_ramp(dist, style.scale_near_distance, far_distance, style.scale_near, style.scale_far)
	end

	Animate.distance_scale = distance_scale

	---@type DLH_MarkerPopFadeOpts
	local POP_FADE_DEFAULTS = {
		fade_in_time = 0.125,
		fade_out_time = 0.375,

		spawn_radius = 46,
		rise = 12,
		pop_time = 0.25,
		pop_overshoot = 0.5,

		near_distance = 5,
		near_lift = 150,

		fan_arc = 70,
		fan_step = 40,

		spread_near_distance = 0,
		spread_far_distance = 0,
		spread_near = 1,
		spread_far = 1.5,

		reference_fov = 65,
	}

	function Animate.pop_fade(opts)
		local o = with_defaults(POP_FADE_DEFAULTS, opts)

		local fan_angle = 0

		local reference_half_tan = math_tan(math_rad(o.reference_fov) * 0.5)

		local cached_fov, cached_factor = nil, 1

		local function fov_factor(vertical_fov)
			if not vertical_fov or vertical_fov <= 0 then
				return 1
			end

			if vertical_fov ~= cached_fov then
				cached_fov = vertical_fov
				cached_factor = reference_half_tan / math_tan(vertical_fov * 0.5)
			end

			return cached_factor
		end

		local function spread_factor(dist)
			local far_distance = o.spread_far_distance

			if far_distance <= 0 then
				return 1
			end

			return distance_ramp(dist, o.spread_near_distance, far_distance, o.spread_near, o.spread_far)
		end

		local function next_fan_direction()
			local rad = math_rad(fan_angle)
			local dir_x, dir_y = math_sin(rad), -math_cos(rad)

			local next_angle = fan_angle + o.fan_step
			fan_angle = next_angle > o.fan_arc and -o.fan_arc or next_angle

			return dir_x, dir_y
		end

		---@type DLH_MarkerAnimator
		return {
			spawn = function(marker, fire_opts)
				local dir_x, dir_y

				if fire_opts.fan_dir_x ~= nil and fire_opts.fan_dir_y ~= nil then
					dir_x, dir_y = fire_opts.fan_dir_x, fire_opts.fan_dir_y
				else
					dir_x, dir_y = next_fan_direction()
				end

				marker.dir_x = dir_x
				marker.dir_y = dir_y
				marker.radius = o.spawn_radius
			end,

			update = function(marker, out, ctx)

				if ctx.duration then
					local fade_in = o.fade_in_time
					local fade_out = o.fade_out_time

					local total = fade_in + fade_out
					if total > ctx.duration then
						local fit = ctx.duration / total
						fade_in = fade_in * fit
						fade_out = fade_out * fit
					end

					out.alpha = ctx.animation.fade(ctx.elapsed, ctx.duration, fade_in, fade_out)
				end

				out.alpha = out.alpha * distance_alpha(marker.style, ctx.dist_to_camera)

				if out.alpha <= 0 then

					return
				end

				local dist_scale = distance_scale(marker.style, ctx.dist_to_camera)

				out.scale = ctx.animation.pop_scale(ctx.elapsed, o.pop_time, o.pop_overshoot) * dist_scale

				local travel = ((marker.radius or 0) + ctx.progress * o.rise)
					* spread_factor(ctx.dist_to_camera)
					* fov_factor(ctx.vertical_fov)

				out.offset_x = (marker.dir_x or 0) * travel
				out.offset_y = (marker.dir_y or 0) * travel

				if o.near_distance > 0 and o.near_lift > 0 and ctx.dist_to_camera < o.near_distance then
					out.offset_y = out.offset_y - o.near_lift * (1 - ctx.dist_to_camera / o.near_distance)
				end
			end,
		}
	end

	---@type DLH_MarkerStaticOpts
	local STATIC_DEFAULTS = {
		fade_in_time = 0.2,

		near_distance = 0,
		near_lift = 0,
	}

	function Animate.static(opts)
		local o = with_defaults(STATIC_DEFAULTS, opts)

		---@type DLH_MarkerAnimator
		return {
			update = function(marker, out, ctx)
				if o.fade_in_time > 0 and ctx.elapsed < o.fade_in_time then
					out.alpha = ctx.elapsed / o.fade_in_time
				end

				if o.near_distance > 0 and o.near_lift > 0 and ctx.dist_to_camera < o.near_distance then
					out.offset_y = out.offset_y - o.near_lift * (1 - ctx.dist_to_camera / o.near_distance)
				end

				out.alpha = out.alpha * distance_alpha(marker.style, ctx.dist_to_camera)
				out.scale = distance_scale(marker.style, ctx.dist_to_camera)
			end,
		}
	end

	module.animate = Animate

	return Animate
end
