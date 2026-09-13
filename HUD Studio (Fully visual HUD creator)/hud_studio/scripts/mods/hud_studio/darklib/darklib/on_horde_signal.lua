---@class DarkLib
---@field on_horde_signal DL_OnHordeSignal

local STINGER_EVENTS = {
	["wwise/events/minions/play_signal_horde_poxwalkers_2d"] = true,
	["wwise/events/minions/play_minion_horde_poxwalker_ambush_2d"] = true,
}

---@alias DL_OnHordeSignal_Callback fun()

---@param mod mod
return function(mod)

	---@class DL_OnHordeSignal
	local OnHordeSignal = {}

	---@type table<number, DL_OnHordeSignal_Callback>
	local _hooks = {}

	local _hooked_game = false

	local function fire()
		for i = 1, #_hooks do
			_hooks[i]()
		end
	end

	local function register_game_hook()

		mod.dl.game_hooks.hook_safe(CLASS.FxSystem, "trigger_wwise_event", function(self, event_name)
			if STINGER_EVENTS[event_name] then
				fire()
			end
		end)

		mod.dl.game_hooks.hook_safe(CLASS.FxSystem, "rpc_trigger_wwise_event", function(self, channel_id, event_id)
			local event_name = NetworkLookup.sound_events[event_id]
			if event_name and STINGER_EVENTS[event_name] then
				fire()
			end
		end)

		_hooked_game = true
	end

	---@param callback DL_OnHordeSignal_Callback
	function OnHordeSignal.execute(callback)
		if not _hooked_game then
			register_game_hook()
		end

		_hooks[#_hooks + 1] = callback
	end

	return OnHordeSignal
end
