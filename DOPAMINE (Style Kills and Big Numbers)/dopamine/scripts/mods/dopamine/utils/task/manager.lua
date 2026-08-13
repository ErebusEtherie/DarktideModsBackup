

---@type mod
local mod = get_mod("dopamine")

if mod.task_manager then
	return mod.task_manager
end

local Constants = mod:core(mod.task_constants, "hud/task/constants").LOGIC
local ShuffleBag = mod:lib(mod.shuffle_bag, "lib/shuffle_bag")

local TaskRegistry = mod:core(mod.task_registry, "utils/task/registry")
local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local TaskEnums = mod:core(mod.task_enums, "utils/task/enums")
local HordeSignal = mod:core(mod.horde_signal, "hooks/horde_signal")
local Layout = mod:core(mod.layout, "hud/layout")

---@return boolean
local function tasks_enabled()
	return Layout.tasks_enabled()
end

local math_random = math.random
local math_max = math.max
local math_min = math.min

---@class TaskManagerState
---@field tasks ActiveTask[] -- active tasks, slot order (index 1 = top row)
---@field clock number -- monotonic seconds from dt
---@field last_trigger_time number -- clock time of last trigger
---@field check_timer number -- counts up to CHECK_INTERVAL
---@field next_uid integer -- unique id per active task (HUD slide keying)
---@field bag TaskID[] -- shuffled task-id queue, non-repeating
---@field manual_index integer -- registry index for the dev cycle keybind
---@field task_last_fired table<TaskID, number> -- clock time each task last fired
---@type TaskManagerState
local _state = {
	tasks = {},
	clock = 0,
	last_trigger_time = -math.huge,
	check_timer = 0,
	next_uid = 1,
	bag = {},
	manual_index = 1,
	task_last_fired = {},
}

local AMBIENT_TASK_CAP = Constants.MAX_ACTIVE_TASKS - Constants.PRIORITY_RESERVED_SLOTS

---@class TaskManager
local TaskManager = {}

---@return TaskID[]
local function all_task_ids()
	local all_tasks = TaskRegistry.all()
	local ids = {}
	for i = 1, #all_tasks do
		if not all_tasks[i].priority then
			ids[#ids + 1] = all_tasks[i].id
		end
	end
	return ids
end

local function refill_bag()
	ShuffleBag.refill(_state.bag, all_task_ids())
end

---@param candidates TaskDefinition[]
---@param task_id TaskID
---@return TaskDefinition|nil
local function candidate_contains(candidates, task_id)
	for i = 1, #candidates do
		if candidates[i].id == task_id then
			return candidates[i]
		end
	end

	return nil
end

---@param candidates TaskDefinition[]
---@return TaskDefinition|nil
local function pick_candidate(candidates)
	return ShuffleBag.draw(_state.bag, function(task_id)
		return candidate_contains(candidates, task_id)
	end, refill_bag)
end

---@param task ActiveTask
local function insert_task(task)
	task.uid = _state.next_uid
	_state.next_uid = _state.next_uid + 1
	task.phase = TaskEnums.TASK_PHASE.enter
	task.phase_t = 0
	task.slot = #_state.tasks + 1

	if task.task_type == TaskEnums.TASK_TYPE_ID.achieve_score_count then
		task.start_sp = EventManager.total_sp()
	end

	_state.tasks[#_state.tasks + 1] = task
end

---@param definition TaskDefinition
local function fire_task(definition)
	_state.task_last_fired[definition.id] = _state.clock
	_state.last_trigger_time = _state.clock
	insert_task(TaskRegistry.create_objective_event(definition))
end

---@param predicate nil|fun(task: ActiveTask): boolean
---@return integer
local function count_live_tasks(predicate)
	local live = 0
	for i = 1, #_state.tasks do
		local task = _state.tasks[i]
		if task.phase ~= TaskEnums.TASK_PHASE.exit and (predicate == nil or predicate(task)) then
			live = live + 1
		end
	end
	return live
end

---@param task ActiveTask
---@return boolean
local function is_priority_task(task)
	return task.priority == true
end

---@param task ActiveTask
---@return boolean
local function is_ambient_task(task)
	return not task.priority
end

---@return boolean
local function manual_mode()
	return mod.dl.settings.debug_trigger_tasks_manually == true
end

---@type TaskContext
local _context = { time = 0 }

---@param task_id TaskID
---@return number|nil
local function seconds_since_task(task_id)
	local fired = _state.task_last_fired[task_id]
	if fired == nil then
		return nil
	end
	return _state.clock - fired
end

---@param task_id TaskID
---@return boolean
local function task_is_active(task_id)
	for i = 1, #_state.tasks do
		if _state.tasks[i].id == task_id then
			return true
		end
	end
	return false
end

_context.seconds_since_task = seconds_since_task
_context.task_is_active = task_is_active

---@return TaskContext
local function make_context()
	_context.time = _state.clock
	_context.seconds_since_horde = HordeSignal.seconds_since_last()
	return _context
end

---@param candidates TaskDefinition[]
---@param want_priority boolean
---@param out TaskDefinition[]
---@return TaskDefinition[] out
local function filter_by_priority(candidates, want_priority, out)
	for i = #out, 1, -1 do
		out[i] = nil
	end
	for i = 1, #candidates do
		if (candidates[i].priority == true) == want_priority then
			out[#out + 1] = candidates[i]
		end
	end
	return out
end

local _ambient_scratch = {}

---@param context TaskContext
local function maybe_trigger(context)
	if manual_mode() then
		return
	end

	if _state.clock - _state.last_trigger_time < Constants.TRIGGER_COOLDOWN then
		return
	end

	if count_live_tasks(is_ambient_task) >= AMBIENT_TASK_CAP then
		return
	end

	local candidates = filter_by_priority(TaskRegistry.candidates(context), false, _ambient_scratch)
	if #candidates == 0 then
		return
	end

	local definition = pick_candidate(candidates)
	if not definition then
		return
	end

	fire_task(definition)
end

local _priority_scratch = {}

---@param context TaskContext
local function maybe_trigger_priority(context)
	if manual_mode() then
		return
	end

	if count_live_tasks(is_priority_task) >= Constants.PRIORITY_RESERVED_SLOTS then
		return
	end

	if count_live_tasks() >= Constants.MAX_ACTIVE_TASKS then
		return
	end

	local candidates = filter_by_priority(TaskRegistry.candidates(context), true, _priority_scratch)
	if #candidates == 0 then
		return
	end

	local definition = candidates[math_random(#candidates)]

	fire_task(definition)

	if definition.trigger_key == TaskEnums.TRIGGER_KEY.horde then
		HordeSignal.consume()
	end
end

---@return TaskDefinition|nil
function TaskManager.selected_definition()
	return TaskRegistry.all()[_state.manual_index]
end

---@return TaskDefinition|nil
function TaskManager.cycle_selection()
	local all_tasks = TaskRegistry.all()
	if #all_tasks == 0 then
		return nil
	end

	_state.manual_index = (_state.manual_index % #all_tasks) + 1
	return all_tasks[_state.manual_index]
end

---@return boolean triggered
function TaskManager.trigger_selected()
	if count_live_tasks() >= Constants.MAX_ACTIVE_TASKS then
		return false
	end

	local definition = TaskRegistry.all()[_state.manual_index]
	if not definition then
		return false
	end

	if not definition.can_duplicate and task_is_active(definition.id) then
		return false
	end

	fire_task(definition)
	return true
end

---@return boolean
local function trigger_rumble_enabled()
	return mod.dl.settings.enable_rumble_global ~= false
end

---@param task ActiveTask
---@param status "done" | "fail"
local function resolve_task(task, status)
	task.status = status
	task.phase = status == "done" and TaskEnums.TASK_PHASE.resolve_done or TaskEnums.TASK_PHASE.resolve_fail
	task.phase_t = 0
	task.rumble_pulse = trigger_rumble_enabled() and Constants.TASK_RUMBLE_PULSE_TIME or 0

	if status == "done" then

		local reward = math.floor((task.sp_reward or 0) * (task.sp_multiplier or 1))
		if reward > 0 then
			EventManager.add_reward(reward)
		end

		local definition = TaskRegistry.by_id(task.id)
		if definition then
			TaskRegistry.note_completion(definition)
		end
	end
end

---@param task ActiveTask
---@return boolean
local function task_is_counting(task)
	return task.phase == TaskEnums.TASK_PHASE.active or task.phase == TaskEnums.TASK_PHASE.enter
end

---@param task ActiveTask
local function check_completion(task)
	if not task_is_counting(task) then
		return
	end

	if (task.current_count or 0) >= (task.target_count or 0) then
		resolve_task(task, "done")
	end
end

---@param event_id EventID
---@param ctx EventContext|nil
function TaskManager.on_style_event(event_id, ctx)
	for i = 1, #_state.tasks do
		local task = _state.tasks[i]

		if
			task.task_type == TaskEnums.TASK_TYPE_ID.trigger_event_count
			and task_is_counting(task)
			and task.event_id == event_id
		then
			local breed_ok = true
			local breed = ctx and ctx.breed_data

			if breed and task.breed_filter then
				breed_ok = mod.dl.breeds.is_any(breed, task.breed_filter)
			end

			if breed_ok then
				task.current_count = (task.current_count or 0) + 1
				check_completion(task)
			end
		end
	end
end

local function update_score_tasks()
	local total_sp = EventManager.total_sp()

	for i = 1, #_state.tasks do
		local task = _state.tasks[i]
		if task.task_type == TaskEnums.TASK_TYPE_ID.achieve_score_count and task_is_counting(task) then
			task.current_count = math_max(0, math.floor(total_sp - (task.start_sp or 0)))
			check_completion(task)
		end
	end
end

---@param dt number
local function update_timers(dt)
	for i = 1, #_state.tasks do
		local task = _state.tasks[i]
		if task.timer_enabled and task_is_counting(task) then
			task.timer_remaining = math_max(0, (task.timer_remaining or 0) - dt)
			if task.timer_remaining <= 0 then
				resolve_task(task, "fail")
			end
		end
	end
end

---@param index integer
local function remove_task_at(index)
	table.remove(_state.tasks, index)
	for i = 1, #_state.tasks do
		_state.tasks[i].slot = i
	end
end

---@param dt number
local function advance_task_phases(dt)
	for i = #_state.tasks, 1, -1 do
		local task = _state.tasks[i]
		task.phase_t = task.phase_t + dt

		if task.rumble_pulse and task.rumble_pulse > 0 then
			task.rumble_pulse = math_max(0, task.rumble_pulse - dt)
		end

		if task.phase == TaskEnums.TASK_PHASE.enter then
			if task.phase_t >= Constants.TASK_ENTER_TIME then
				task.phase = TaskEnums.TASK_PHASE.active
				task.phase_t = 0
			end
		elseif task.phase == TaskEnums.TASK_PHASE.resolve_done or task.phase == TaskEnums.TASK_PHASE.resolve_fail then
			if task.phase_t >= Constants.TASK_RESOLVE_TIME then
				task.phase = TaskEnums.TASK_PHASE.exit
				task.phase_t = 0
			end
		elseif task.phase == TaskEnums.TASK_PHASE.exit then
			if task.phase_t >= Constants.TASK_EXIT_TIME then
				remove_task_at(i)
			end
		end
	end
end

---@param dt number|nil
function TaskManager.tick(dt)
	dt = dt or 0

	if not tasks_enabled() then
		if #_state.tasks > 0 then
			TaskManager.reset()
		end
		return
	end

	_state.clock = _state.clock + dt

	update_score_tasks()
	update_timers(dt)
	advance_task_phases(dt)

	local context = make_context()

	maybe_trigger_priority(context)

	_state.check_timer = _state.check_timer + dt
	if _state.check_timer >= Constants.CHECK_INTERVAL then
		_state.check_timer = _state.check_timer - Constants.CHECK_INTERVAL
		maybe_trigger(context)
	end
end

---@class TaskSnapshot
---@field tasks ActiveTask[] -- shallow copies, index-aligned to the live track
---@field count integer -- populated entries in `tasks`

local _snapshot_tasks = {}
---@type TaskSnapshot
local _snapshot = { tasks = _snapshot_tasks, count = 0 }

---@param destination table
---@param task ActiveTask
---@return ActiveTask destination
local function copy_task_into(destination, task)
	destination.uid = task.uid
	destination.id = task.id
	destination.task_type = task.task_type
	destination.event_label = task.event_label
	destination.breed_name = task.breed_name
	destination.breed_en_name = task.breed_en_name
	destination.tier = task.tier
	destination.target_count = task.target_count
	destination.current_count = task.current_count
	destination.sp_reward = task.sp_reward
	destination.sp_multiplier = task.sp_multiplier
	destination.timer_enabled = task.timer_enabled
	destination.timer_remaining = task.timer_remaining
	destination.phase = task.phase
	destination.phase_t = task.phase_t
	destination.status = task.status
	destination.rumble_pulse = task.rumble_pulse
	destination.slot = task.slot
	return destination
end

---@return TaskSnapshot
function TaskManager.snapshot()
	local count = #_state.tasks

	for i = 1, count do
		_snapshot_tasks[i] = copy_task_into(_snapshot_tasks[i] or {}, _state.tasks[i])
	end
	for i = count + 1, #_snapshot_tasks do
		_snapshot_tasks[i] = nil
	end

	_snapshot.count = count
	return _snapshot
end

function TaskManager.reset()
	local tasks = _state.tasks
	for i = #tasks, 1, -1 do
		tasks[i] = nil
	end

	_state.clock = 0
	_state.last_trigger_time = -math.huge
	_state.check_timer = 0

	for task_id in pairs(_state.task_last_fired) do
		_state.task_last_fired[task_id] = nil
	end

	HordeSignal.reset()

	for i = #_state.bag, 1, -1 do
		_state.bag[i] = nil
	end

	local all_tasks = TaskRegistry.all()
	for i = 1, #all_tasks do
		all_tasks[i].completion_count = nil
		all_tasks[i].max_completion_count = nil
	end
end

function TaskManager.init()
	EventManager.set_event_listener(function(event_id, context)
		TaskManager.on_style_event(event_id, context)
	end)
end

TaskManager.init()

mod.__debug__cycle_objective = function(self, is_pressed)
	if is_pressed == false then
		return
	end

	local definition = TaskManager.cycle_selection()
	if definition then
		mod:echo("DEBUG: objective queued -> %s (%s)", definition.id, definition.task_type)
	end
end

mod.__debug__trigger_task = function(self, is_pressed)
	if is_pressed == false then
		return
	end

	if not TaskManager.trigger_selected() then
		mod:echo("DEBUG: could not trigger objective (track full)")
	end
end

mod.task_manager = TaskManager

return TaskManager
