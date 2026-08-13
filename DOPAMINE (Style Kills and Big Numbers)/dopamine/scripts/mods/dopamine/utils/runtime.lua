---@type mod
local mod = get_mod("dopamine")

if mod.runtime then
	return mod.runtime
end

---@class RuntimeState
---@field rumble_t number? shared gameplay clock for rumble phase (written by the fury meter, read by the kill markers)
---@type RuntimeState
mod.runtime_state = mod.runtime_state or {
	rumble_t = nil,
}

local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local TaskManager = mod:core(mod.task_manager, "utils/task/manager")

local MovementHandler = mod:core(mod.movement_handler, "hooks/movement_handler")
local ObjectiveMarkers = mod:core(mod.objective_markers, "hooks/objective_markers")
local ObjectiveTime = mod:core(mod.objective_time, "hooks/objective_time")
local TeammateRescue = mod:core(mod.teammate_rescue, "hooks/teammate_rescue")

local DamagePoll = mod.dl.damage_poll.shared("player")

---@class Runtime
local Runtime = {}

function Runtime.clear_markers()
	mod.dl_hud.marker.clear()
end

function Runtime.clear_all(reset_mission_stats)
	ComboState.reset(reset_mission_stats)
	EventManager.reset()
	TaskManager.reset()
	MovementHandler.reset()

	ObjectiveTime.reset()

	ObjectiveMarkers.reset()
	TeammateRescue.reset()
	Runtime.clear_markers()

	DamagePoll:reset()
end

mod.runtime = Runtime

return Runtime
