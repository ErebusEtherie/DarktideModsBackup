---@type mod
local mod = get_mod("dopamine")

if mod.stim_tracker then
	return mod.stim_tracker
end

---@class StimTracker
local StimTracker = {}

local _ally_stims = 0

---@type fun(target: Unit)[]
local _on_ally_stim = {}

---@param callback fun(target: Unit)
function StimTracker.on_ally_stim(callback)
	_on_ally_stim[#_on_ally_stim + 1] = callback
end

mod.dl.game_hooks.hook_safe("ActionUseSyringe", "_report_use_to_stat_system", function(self, target)
	if self._player_unit ~= mod.dl.player.local_player_unit() then
		return
	end

	local settings = self._action_settings
	local used_on_ally = settings ~= nil and not settings.self_use

	if not used_on_ally or not target or target == self._player_unit then
		return
	end

	_ally_stims = _ally_stims + 1

	for i = 1, #_on_ally_stim do
		_on_ally_stim[i](target)
	end
end)

---@return integer
function StimTracker.ally_stims()
	return _ally_stims
end

function StimTracker.reset()
	_ally_stims = 0
end

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		StimTracker.reset()
	end
end)

mod.stim_tracker = StimTracker

return mod.stim_tracker
