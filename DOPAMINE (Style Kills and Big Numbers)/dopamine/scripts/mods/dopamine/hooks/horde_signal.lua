

---@type mod
local mod = get_mod("dopamine")

if mod.horde_signal then
	return mod.horde_signal
end

local _signal_t = nil
local _clock = 0

---@class HordeSignal
local HordeSignal = {}

---@param dt number|nil
function HordeSignal.tick(dt)
	_clock = _clock + (dt or 0)
end

function HordeSignal.reset()
	_signal_t = nil
	_clock = 0
end

---@return number|nil
function HordeSignal.seconds_since_last()
	if _signal_t == nil then
		return nil
	end
	return _clock - _signal_t
end

function HordeSignal.consume()
	_signal_t = nil
end

local function note_stinger()
	_signal_t = _clock
end

mod.dl.on_horde_signal.execute(note_stinger)

mod.horde_signal = HordeSignal

return HordeSignal
