---@type mod
local mod = get_mod("dopamine")

if mod.finesse then
	return mod.finesse
end

local DamagePoll = mod.dl.damage_poll.shared("player")

---@class Finesse
local Finesse = {}

local _health_lost = 0

local _downs = 0

local _was_down = false

DamagePoll:on_damage_taken(function(state)
	_health_lost = _health_lost + (state.health_lost or 0)
end)

function Finesse.tick()
	local unit = mod.dl.player.local_player_unit()
	local state = unit and mod.dl.player.character_state(unit) or nil
	local down = state == "knocked_down"

	if down and not _was_down then
		_downs = _downs + 1
	end

	_was_down = down
end

---@return number
function Finesse.health_lost()
	return _health_lost
end

---@return integer
function Finesse.downs()
	return _downs
end

function Finesse.reset()
	_health_lost = 0
	_downs = 0
	_was_down = false
end

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		Finesse.reset()
	end
end)

mod.finesse = Finesse

return mod.finesse
