---@type mod
local mod = get_mod("dopamine")

if mod.rumble then
	return mod.rumble
end

local ComboState = mod:core(mod.combo_state, "utils/combo_state")

local math_clamp = math.clamp
local math_max = math.max

---@class Rumble
local Rumble = {}

local _fury_gain_pulse = 0
local _sp_gain_pulse = 0
local _previous_fury = 0

local function gain_rumble_on()
	return mod.dl.settings.enable_rumble_global ~= false and mod.dl.settings.enable_rumble_on_gain ~= false
end

---@param dt number
function Rumble.tick(dt)
	local fury = ComboState.fury

	if gain_rumble_on() and fury > _previous_fury + 0.05 then
		_fury_gain_pulse = mod.constants.PULSE.T
	end

	_previous_fury = fury

	if _fury_gain_pulse > 0 then
		_fury_gain_pulse = math_max(0, _fury_gain_pulse - dt)
	end
	if _sp_gain_pulse > 0 then
		_sp_gain_pulse = math_max(0, _sp_gain_pulse - dt)
	end
end

function Rumble.on_sp_gain()
	if gain_rumble_on() then
		_sp_gain_pulse = mod.constants.PULSE.T
	end
end

---@return number
function Rumble.common_amp()
	if mod.dl.settings.enable_rumble_global == false then
		return 0
	end

	local pulse = mod.constants.PULSE
	local period = pulse.T
	if period <= 0 then
		return 0
	end

	local fury_amp = pulse.AMP_LOW * math_clamp(_fury_gain_pulse / period, 0, 1)
	local sp_amp = pulse.AMP_MID * math_clamp(_sp_gain_pulse / period, 0, 1)
	return math_max(fury_amp, sp_amp)
end

mod.rumble = Rumble

return Rumble
