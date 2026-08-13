---@type mod
local mod = get_mod("dopamine")

if mod.task_enums then
	return mod.task_enums
end

---@enum TaskID
local TASK_ID = {
	cull_hounds = "cull_hounds",
	cull_flamers = "cull_flamers",
	cull_shotgunners = "cull_shotgunners",
	cull_gunners = "cull_gunners",
	cull_the_swarm = "cull_the_swarm",
	headshot_kills = "headshot_kills",
	melee_kills = "melee_kills",
	ranged_kills = "ranged_kills",
	slide_kill_streak = "slide_kill_streak",
}

---@enum TriggerKey
local TRIGGER_KEY = {
	horde = "horde",
}

---@enum TaskType
local TASK_TYPE_ID = {
	achieve_score_count = "achieve_score_count",
	trigger_event_count = "trigger_event_count",
}

---@enum TaskPhase
local TASK_PHASE = {
	resolve_done = "resolve_done",
	resolve_fail = "resolve_fail",
	active = "active",
	enter = "enter",
	exit = "exit",
}

---@class TaskEnums
local TaskEnums = {
	TASK_ID = TASK_ID,
	TASK_TYPE_ID = TASK_TYPE_ID,
	TASK_PHASE = TASK_PHASE,
	TRIGGER_KEY = TRIGGER_KEY,
}

mod.task_enums = TaskEnums

return mod.task_enums
