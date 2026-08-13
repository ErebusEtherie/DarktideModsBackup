---@type mod
local mod = get_mod("dopamine")

if mod.update_loop then
	return mod.update_loop
end

local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local Runtime = mod:core(mod.runtime, "utils/runtime")
local Rumble = mod:core(mod.rumble, "utils/rumble")
local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local TaskManager = mod:core(mod.task_manager, "utils/task/manager")
local StatsManager = mod:core(mod.stats_manager, "utils/stats/manager")
local HordeSignal = mod:core(mod.horde_signal, "hooks/horde_signal")

local MovementHandler = mod:core(mod.movement_handler, "hooks/movement_handler")
local ObjectiveMarkers = mod:core(mod.objective_markers, "hooks/objective_markers")
local ObjectiveTime = mod:core(mod.objective_time, "hooks/objective_time")
local TeammateRescue = mod:core(mod.teammate_rescue, "hooks/teammate_rescue")

local Coherency = mod:core(mod.coherency, "hooks/coherency")
local Finesse = mod:core(mod.finesse, "hooks/finesse")

local DamagePoll = mod.dl.damage_poll.shared("player")

DamagePoll:on_damage_taken(function(state)
	ComboState.on_damage(state.lost)
end)

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if from_reload then
		return
	end

	Runtime.clear_all(true)
	StatsManager.reset()

	mod.dl.on_hit.reset_stats()
end)

mod.dl.gameplay.while_in_gameplay(function(dt)
	DamagePoll:tick() 
	ObjectiveTime.tick(dt) 
	ComboState.update(dt)
	Rumble.tick(dt) 
	MovementHandler.tick(dt)
	EventManager.tick(dt)
	HordeSignal.tick(dt) 
	TaskManager.tick(dt)
	ObjectiveMarkers.tick(dt) 
	TeammateRescue.tick(dt) 
	Coherency.tick(dt) 
	Finesse.tick(dt) 
	mod.dl.on_hit.tick(dt) 
	StatsManager.tick(dt) 
end)

mod.dl.gameplay.on_leave_gameplay(function()
	Runtime.clear_markers()
	ComboState.reset(true)
	EventManager.reset()
	TaskManager.reset()
	StatsManager.reset()
	mod.dl.on_hit.reset_stats()
	MovementHandler.reset()
	ObjectiveTime.reset()
	DamagePoll:reset()
end)

mod.update = function(dt)
	mod.dl_hud.mod_menu.manager.tick()
	mod.dl.gameplay.tick(dt)
end

local UpdateLoop = {}

mod.update_loop = UpdateLoop

return UpdateLoop
