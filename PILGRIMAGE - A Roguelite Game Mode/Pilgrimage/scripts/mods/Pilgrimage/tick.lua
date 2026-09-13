-- tick.lua
--
-- The mod's only per-frame entry point. Everything that wants recurring work
-- registers here instead of adding its own update hook.
--
-- BetterBots gets away with no central scheduler because its work is bounded by the
-- number of bots (three). An expedition mode does world-level work: scanning for the
-- terminal, checking objective state, driving the run controller. That is unbounded,
-- so we want an explicit frequency ladder and a per-frame cap.
--
-- Three things this gives us:
--
--   1. Frequency tiers. A task registered with interval 0.5 runs twice a second, not
--      sixty times. Most of what this mod does does not need frame rate.
--
--   2. Automatic de-phasing. Tasks registered at the same interval get a staggered
--      initial offset, so ten half-second tasks do not all fire on the same frame and
--      produce a visible hitch.
--
--   3. Per-frame budget with round-robin. If more work comes due than the budget
--      allows, we run what fits and resume from where we stopped next frame, so
--      nothing starves.
--
-- Every task is pcall'd and instrumented, so one misbehaving task cannot kill the
-- others and every task shows up by name in /pil_perf.

local M = {}

local _mod
local _perf
local _shared
local _debug_log

local _tasks = {}
local _cursor = 1
local _stagger_seed = 0

-- How many DUE tasks we are willing to run in one frame. Frame-rate tasks
-- (interval 0) are exempt and always run.
local DEFAULT_BUDGET = 4
local _budget = DEFAULT_BUDGET

function M.init(deps)
	_mod = deps.mod
	_perf = deps.perf
	_shared = deps.shared
	_debug_log = deps.debug_log
end

-- name       display name, used as the perf tag and in logs
-- interval_s 0 means every frame; anything else is the minimum gap between runs
-- fn         function(t, dt)
-- opts.when  optional gate, function() -> boolean. Checked before fn runs, and it is
--            checked cheaply every time the task comes due, so it should be a simple
--            table lookup or state read, not real work.
function M.register(name, interval_s, fn, opts)
	opts = opts or {}

	-- Give each task a different starting offset within its own interval so tasks
	-- registered together do not all come due on the same frame.
	_stagger_seed = _stagger_seed + 1
	local offset = interval_s > 0 and (interval_s * ((_stagger_seed * 0.37) % 1.0)) or 0

	_tasks[#_tasks + 1] = {
		name = name,
		interval = interval_s or 0,
		fn = fn,
		when = opts.when,
		next_t = offset,
		runs = 0,
		errors = 0,
		last_error = nil,
	}

	return _tasks[#_tasks]
end

function M.set_budget(n)
	_budget = math.max(1, n or DEFAULT_BUDGET)
end

local function _run(task, t, dt)
	if task.when and not task.when() then return false end

	local t0 = _perf.begin()
	local ok, err = pcall(task.fn, t, dt)
	_perf.finish("tick." .. task.name, t0)

	task.runs = task.runs + 1

	if not ok then
		task.errors = task.errors + 1
		task.last_error = tostring(err)
		-- Throttled so a task failing every frame does not flood the chat.
		_debug_log("tick_error:" .. task.name, t,
			"task '" .. task.name .. "' failed: " .. tostring(err), 5, "info")
	end

	return true
end

function M.update(t, dt)
	local count = #_tasks
	if count == 0 then return end

	_perf.mark_frame()

	local budget_left = _budget

	-- Pass one: frame-rate tasks. These are exempt from the budget by definition,
	-- so keep the list of them short.
	for i = 1, count do
		local task = _tasks[i]
		if task.interval <= 0 then
			_run(task, t, dt)
		end
	end

	-- Pass two: interval tasks, resuming from wherever we ran out of budget last
	-- frame so no task can be permanently starved by an earlier one.
	for _ = 1, count do
		if budget_left <= 0 then break end

		if _cursor > count then _cursor = 1 end
		local task = _tasks[_cursor]
		_cursor = _cursor + 1

		if task.interval > 0 and t >= task.next_t then
			-- Set the next deadline BEFORE running, so a task that throws still
			-- backs off rather than retrying every frame.
			task.next_t = t + task.interval
			if _run(task, t, dt) then
				budget_left = budget_left - 1
			end
		end
	end
end

-- Reset all deadlines. Called on mission start, because fixed-frame time restarts
-- from zero and stale future deadlines would stall every task.
function M.reset(t)
	t = t or 0
	for i = 1, #_tasks do
		local task = _tasks[i]
		task.next_t = t + (task.interval > 0 and (task.interval * ((i * 0.37) % 1.0)) or 0)
		task.runs = 0
		task.errors = 0
		task.last_error = nil
	end
	_cursor = 1
end

function M.tasks()
	return _tasks
end

return M
