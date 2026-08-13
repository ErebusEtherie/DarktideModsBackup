local math_clamp = math.clamp
local math_sin = math.sin
local math_pi = math.pi

---@class DarkLib
---@field animation DL_Animation

return function(mod)
	---@class DL_Animation
	local Animation = {}

	function Animation.rumble_pulse_time()
		return 0.35
	end

	function Animation.fade(t, duration, fade_in, fade_out)
		if t <= 0 or t >= duration then
			return 0
		end

		if fade_in > 0 and t < fade_in then
			return t / fade_in
		end

		local out_start = duration - fade_out

		if fade_out > 0 and t > out_start then
			return math_clamp(1 - (t - out_start) / fade_out, 0, 1)
		end

		return 1
	end

	function Animation.pop_scale(t, pop_time, overshoot)
		if t >= pop_time or pop_time <= 0 then
			return 1
		end

		local progress = t / pop_time

		return 1 + overshoot * math_sin(progress * math_pi) * (1 - progress)
	end

	function Animation.rumble(t, amplitude)
		if amplitude <= 0 then
			return 0, 0
		end

		local offset_x = (math_sin(t * 53.0) + math_sin(t * 97.0)) * 0.5 * amplitude
		local offset_y = (math_sin(t * 61.0) + math_sin(t * 89.0)) * 0.5 * amplitude

		return offset_x, offset_y
	end

	function Animation.ease_out(x, power)
		if x <= 0 then
			return 0
		elseif x >= 1 then
			return 1
		end

		return 1 - (1 - x) ^ (power or 2)
	end

	function Animation.ease_in(x, power)
		if x <= 0 then
			return 0
		elseif x >= 1 then
			return 1
		end

		return x ^ (power or 2)
	end

	return Animation
end
