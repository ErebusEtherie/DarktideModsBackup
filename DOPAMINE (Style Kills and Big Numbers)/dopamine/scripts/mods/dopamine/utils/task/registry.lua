

---@type mod
local mod = get_mod("dopamine")

if mod.task_registry then
	return mod.task_registry
end

local Constants = mod:core(mod.task_constants, "hud/task/constants").LOGIC
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local TaskEnums = mod:core(mod.task_enums, "utils/task/enums")

local math_random = math.random

---@class TaskContext
---@field time number -- manager clock
---@field seconds_since_horde number|nil -- since last horde stinger, nil if none pending
---@field seconds_since_task fun(task_id: TaskID): number|nil -- nil if never fired
---@field task_is_active fun(task_id: TaskID): boolean

---@class TaskTier
---@field tier integer
---@field target_count integer
---@field sp_reward integer
---@field sp_multiplier number
---@field timer number|nil

---@class TaskDefinition
---@field id TaskID
---@field task_type TaskType
---@field event_label string
---@field event_id EventID | nil
---@field pick_random_from_breed_fitler boolean|nil -- select 1 random breed from breed_filter
---@field breed_name string|nil
---@field breed_filter table|nil
---@field random_timer boolean|nil
---@field objective TaskTier[]
---@field candidate_function fun(context: TaskContext): boolean
---@field priority boolean|nil -- fires into reserved slot, ignores ambient cadence/cooldown
---@field can_duplicate boolean|nil -- allow firing while an instance is active (default: no)
---@field trigger_key TriggerKey|nil -- signal the manager consumes on fire
---@field completion_count integer|nil -- completions this session (stamped lazily)
---@field max_completion_count integer|nil -- = #objective (stamped lazily)

---@class ActiveTask
---@field id TaskID
---@field task_type TaskType
---@field event_id EventID | nil
---@field event_label string
---@field breed_name string|nil
---@field breed_en_name string|nil
---@field breed_filter table|nil
---@field tier integer
---@field target_count integer
---@field sp_reward integer
---@field sp_multiplier number
---@field timer number|nil
---@field current_count integer
---@field timer_enabled boolean
---@field timer_remaining number|nil
---@field uid integer|nil -- assigned on insert into the track
---@field phase TaskPhase|nil
---@field phase_t number|nil
---@field slot integer|nil
---@field status "done"|"fail"|nil
---@field start_sp number|nil -- achieve_score_count baseline SP total
---@field rumble_pulse number|nil -- remaining resolve-rumble time
---@field priority boolean|nil -- copied from the definition; whether this occupies a reserved slot

---@type TaskDefinition[]
local TASKS = {
	{
		id = TaskEnums.TASK_ID.cull_hounds,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.hound_kill,
		random_timer = false,
		can_duplicate = false,
		event_label = "{target_count} Hounds",
		objective = {
			{ tier = 1, target_count = 5, sp_reward = 5000, sp_multiplier = 1 },
			{ tier = 2, target_count = 10, sp_reward = 10000, sp_multiplier = 1 },
			{ tier = 3, target_count = 15, sp_reward = 25000, sp_multiplier = 1 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.cull_flamers,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.flamer_kill,
		random_timer = false,
		can_duplicate = false,
		event_label = "{target_count} Flamers",
		objective = {
			{ tier = 1, target_count = 5, sp_reward = 5000, sp_multiplier = 1, timer = 120 },
			{ tier = 2, target_count = 10, sp_reward = 10000, sp_multiplier = 1, timer = 150 },
			{ tier = 3, target_count = 15, sp_reward = 25000, sp_multiplier = 1, timer = 180 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.cull_gunners,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.gunner_kill,
		random_timer = false,
		can_duplicate = false,
		event_label = "{target_count} Gunners",
		objective = {
			{ tier = 1, target_count = 5, sp_reward = 5000, sp_multiplier = 1, timer = 120 },
			{ tier = 2, target_count = 10, sp_reward = 10000, sp_multiplier = 1, timer = 150 },
			{ tier = 3, target_count = 15, sp_reward = 25000, sp_multiplier = 1, timer = 180 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.cull_shotgunners,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.shotgunner_kill,
		random_timer = false,
		can_duplicate = false,
		event_label = "{target_count} Shotgunners",
		objective = {
			{ tier = 1, target_count = 5, sp_reward = 5000, sp_multiplier = 1, timer = 120 },
			{ tier = 2, target_count = 10, sp_reward = 10000, sp_multiplier = 1, timer = 150 },
			{ tier = 3, target_count = 15, sp_reward = 25000, sp_multiplier = 1, timer = 180 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.melee_kills,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.melee_kill,
		random_timer = true,
		event_label = "{target_count} melee kills",
		objective = {
			{ tier = 2, target_count = 15, sp_reward = 5000, sp_multiplier = 1, timer = 90 },
			{ tier = 2, target_count = 30, sp_reward = 15000, sp_multiplier = 1, timer = 90 },
			{ tier = 3, target_count = 50, sp_reward = 30000, sp_multiplier = 1, timer = 150 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.ranged_kills,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.ranged_kill,
		random_timer = true,
		event_label = "{target_count} ranged kills",
		objective = {
			{ tier = 2, target_count = 15, sp_reward = 5000, sp_multiplier = 1, timer = 90 },
			{ tier = 2, target_count = 30, sp_reward = 15000, sp_multiplier = 1, timer = 90 },
			{ tier = 3, target_count = 50, sp_reward = 30000, sp_multiplier = 1, timer = 150 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{
		id = TaskEnums.TASK_ID.headshot_kills,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.generic_headshot,
		random_timer = true,
		event_label = "{target_count} headshots",
		objective = {
			{ tier = 1, target_count = 10, sp_reward = 5000, sp_multiplier = 1, timer = 90 },
			{ tier = 2, target_count = 25, sp_reward = 15000, sp_multiplier = 1, timer = 150 },
			{ tier = 3, target_count = 50, sp_reward = 25000, sp_multiplier = 1, timer = 150 },
		},
		candidate_function = function(context)
			return context ~= nil
		end,
	},
	{

		id = TaskEnums.TASK_ID.cull_the_swarm,
		task_type = TaskEnums.TASK_TYPE_ID.trigger_event_count,
		event_id = EventEnums.EVENT_ID.generic_kill,
		breed_filter = mod.dl.breeds.where_any("group.melee_horde", "group.melee_bruiser", "group.vanguards"),
		random_timer = false,
		priority = true,
		trigger_key = TaskEnums.TRIGGER_KEY.horde,
		event_label = "Purge the swarm [{target_count} kills]",
		objective = {
			{ tier = 1, target_count = 15, sp_reward = 5000, sp_multiplier = 1, timer = 90 },
			{ tier = 2, target_count = 25, sp_reward = 15000, sp_multiplier = 1, timer = 120 },
			{ tier = 3, target_count = 50, sp_reward = 30000, sp_multiplier = 1, timer = 150 },
		},
		candidate_function = function(context)
			local seconds_since_horde = context.seconds_since_horde
			return seconds_since_horde ~= nil and seconds_since_horde >= Constants.HORDE_TASK_DELAY
		end,
	},
}

---@class TaskRegistry
local Registry = {}

---@return TaskDefinition[]
function Registry.all()
	return TASKS
end

---@param template string|nil
---@param task ActiveTask|table
---@return string
function Registry.fill_label(template, task)
	return mod.dl.str.fill_template(template, task)
end

---@param task_id TaskID
---@return TaskDefinition|nil
function Registry.by_id(task_id)
	for i = 1, #TASKS do
		if TASKS[i].id == task_id then
			return TASKS[i]
		end
	end

	return nil
end

---@param tier integer|nil
---@return string|nil
function Registry.difficulty(tier)
	return Constants.DIFFICULTY[tier or 0]
end

---@param tier integer|nil
---@return string|nil
function Registry.difficulty_icon(tier)
	return Constants.DIFFICULTY_ICON[tier or 0]
end

---@param definition TaskDefinition
local function ensure_completion_fields(definition)
	if definition.max_completion_count == nil then
		definition.max_completion_count = #definition.objective
	end
	if definition.completion_count == nil then
		definition.completion_count = 0
	end
end

---@param definition TaskDefinition
---@return TaskTier tier_data, integer tier_index
local function tier_for(definition)
	local index = math.min(definition.completion_count + 1, #definition.objective)
	return definition.objective[index], index
end

---@param definition TaskDefinition
---@return boolean
function Registry.is_exhausted(definition)
	ensure_completion_fields(definition)
	return definition.completion_count >= definition.max_completion_count
end

---@param definition TaskDefinition
function Registry.note_completion(definition)
	ensure_completion_fields(definition)
	definition.completion_count = definition.completion_count + 1
end

---@param context TaskContext
---@return TaskDefinition[]
function Registry.candidates(context)
	local candidates = {}

	for i = 1, #TASKS do
		local definition = TASKS[i]
		if
			not Registry.is_exhausted(definition)
			and (definition.can_duplicate or not context.task_is_active(definition.id))
			and definition.candidate_function(context)
		then
			candidates[#candidates + 1] = definition
		end
	end

	return candidates
end

---@param definition TaskDefinition
---@return ActiveTask
function Registry.create_objective_event(definition)
	ensure_completion_fields(definition)

	local tier_data, tier_index = tier_for(definition)
	local timer = tier_data.timer
	local timer_enabled = timer ~= nil
		and (not definition.random_timer or math_random() < Constants.RANDOM_TIMER_CHANCE)

	local breed_en_name = nil
	if definition.breed_filter and definition.pick_random_from_breed_fitler then

		breed_en_name = mod.dl.breeds.name_en(definition.breed_filter[math.random(1, #definition.breed_filter)])
	end

	local active_task = {
		id = definition.id,
		task_type = definition.task_type,
		event_id = definition.event_id,
		event_label = definition.event_label,
		breed_name = definition.breed_name,
		breed_en_name = breed_en_name,
		breed_filter = definition.breed_filter,
		priority = definition.priority,

		tier = tier_data.tier or tier_index,
		target_count = tier_data.target_count,
		sp_reward = tier_data.sp_reward,
		sp_multiplier = tier_data.sp_multiplier or 1,
		timer = timer,

		current_count = 0,
		timer_enabled = timer_enabled,
		timer_remaining = timer_enabled and timer or nil,
	}

	return active_task
end

mod.task_registry = Registry

return Registry
