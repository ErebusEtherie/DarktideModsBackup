---@type mod
local mod = get_mod("dopamine")

if mod.coherency then
	return mod.coherency
end

local ScriptUnit = ScriptUnit

---@class Coherency
local Coherency = {}

local _coherency_time = 0

---@return boolean
local function in_coherency()
	local unit = mod.dl.player.local_player_unit()
	if not unit then
		return false
	end

	local extension = ScriptUnit.has_extension(unit, "coherency_system")

	return extension ~= nil and extension:num_units_in_coherency() >= 1
end

---@param dt number
function Coherency.tick(dt)
	if in_coherency() then
		_coherency_time = _coherency_time + dt
	end
end

---@return number
function Coherency.time()
	return _coherency_time
end

function Coherency.reset()
	_coherency_time = 0
end

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		Coherency.reset()
	end
end)

mod.coherency = Coherency

return mod.coherency
