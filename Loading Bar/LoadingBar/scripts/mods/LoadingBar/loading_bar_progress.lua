local mod = get_mod("LoadingBar")

local Progress = {}

local CALIBRATION_SETTING = "lb_calibration"
local MIN_ALPHA = 0.15
local SESSION_GAP = 0.5
local EASE_RATE = 6.0

local PHASES = {
	{ id = "network", lo = 0.00, hi = 0.10, default_time = 2.0 },
	{ id = "despawn", lo = 0.10, hi = 0.18, default_time = 1.5 },
	{ id = "global",  lo = 0.18, hi = 0.42, default_time = 6.0 },
	{ id = "mission", lo = 0.42, hi = 0.90, default_time = 20.0 },
	{ id = "sync",    lo = 0.90, hi = 1.00, default_time = 4.0 },
}

local GENERIC_PHASE = { id = "generic", lo = 0.0, hi = 0.90, default_time = 25.0 }

local TERMINAL_PHASE = { id = "terminal", lo = 0.90, hi = 1.0, default_time = 1.0, terminal = true }

local PHASE_INDEX = {}
for i = 1, #PHASES do
	PHASE_INDEX[PHASES[i].id] = i
end

local STATE_TO_PHASE = {
	waiting_for_network = "network",
	waiting_for_despawn = "despawn",
}
local LOADING_STATE_TO_PHASE = {
	loading_global_packages = "global",
	loading_mission = "mission",
}

local observed = {
	state = nil,
	loading_state = nil,
	active = false,
}

local state = {
	display = 0,
	anchor = 0,
	phase = nil,
	phase_started = 0,
	phase_sub = 0,
	peak_inflight = 0,
	last_draw = -math.huge,
	last_update = 0,
	session_active = false,
	saw_real_phase = false,

	kind = "other",
	phase_kind = nil,
	cal = nil,
	slices = nil,
	dirty = false,
}

local function now()
	local ok, t = pcall(function()
		return Managers.time:time("main")
	end)

	if ok and type(t) == "number" then
		return t
	end

	return os.clock()
end

local function count_keys(t)
	if not t then
		return 0
	end

	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end

	return n
end

local function count_inflight()
	local package_manager = Managers.package

	if not package_manager then
		return 0
	end

	return count_keys(package_manager._async_packages) + count_keys(package_manager._queued_async_packages)
end

local function load_calibration()
	if state.cal then
		return state.cal
	end

	local stored = mod:get(CALIBRATION_SETTING)
	local cal = {}

	if type(stored) == "table" then
		for key, value in pairs(stored) do
			if type(key) == "string" and type(value) == "number" then
				cal[key] = value
			end
		end
	end

	state.cal = cal

	return cal
end

local function duration_key(kind, phase_id)
	return kind .. ":" .. phase_id
end

local function duration_for(kind, phase_id, fallback)
	local cal = load_calibration()
	local value = cal[duration_key(kind, phase_id)]

	if type(value) == "number" and value > 0 then
		return value
	end

	local legacy = cal[phase_id]

	if type(legacy) == "number" and legacy > 0 then
		return legacy
	end

	return fallback
end

local function record_duration(kind, phase_id, elapsed)
	if not kind or not phase_id or not elapsed then
		return
	end

	if elapsed <= 0.05 or elapsed > 600 then
		return
	end

	local cal = load_calibration()
	local key = duration_key(kind, phase_id)
	local count_key = "n:" .. key
	local count = cal[count_key] or 0
	local alpha = math.max(1 / (count + 1), MIN_ALPHA)
	local previous = cal[key]

	if type(previous) ~= "number" or previous <= 0 then
		previous = elapsed
	end

	cal[key] = previous + (elapsed - previous) * alpha

	cal[count_key] = math.min(count + 1, 50)
	state.dirty = true
end

local function save_calibration()
	if not state.dirty or not state.cal then
		return
	end

	mod:set(CALIBRATION_SETTING, state.cal)
	state.dirty = false
end

local MIN_SLICE = 0.05

local function rebuild_slices()
	local kind = state.kind or "other"
	local total = 0

	for i = 1, #PHASES do
		local phase = PHASES[i]

		total = total + math.max(duration_for(kind, phase.id, phase.default_time), 0.01)
	end

	local slices = {}
	local spare = 1 - MIN_SLICE * #PHASES
	local cursor = 0

	for i = 1, #PHASES do
		local phase = PHASES[i]
		local duration = math.max(duration_for(kind, phase.id, phase.default_time), 0.01)
		local width = MIN_SLICE + duration / total * spare

		slices[phase.id] = {
			lo = cursor,
			hi = math.min(cursor + width, 1),
		}

		cursor = cursor + width
	end

	slices[PHASES[#PHASES].id].hi = 1

	state.slices = slices
end

local function slice_for(phase)
	local slice = state.slices and state.slices[phase.id]

	if slice then
		return slice.lo, slice.hi
	end

	return phase.lo, phase.hi
end

local function phase_by_id(id)
	local index = PHASE_INDEX[id]

	if index then
		return PHASES[index]
	end

	if id == GENERIC_PHASE.id then
		return GENERIC_PHASE
	end

	if id == TERMINAL_PHASE.id then
		return TERMINAL_PHASE
	end
end

local function resolve_phase()
	if observed.active then
		local mapped = STATE_TO_PHASE[observed.state]

		if mapped then
			return phase_by_id(mapped)
		end

		if observed.state == "loading" then
			local sub = LOADING_STATE_TO_PHASE[observed.loading_state]

			return phase_by_id(sub or "mission")
		end

		return PHASES[1]
	end

	local unit_spawner = Managers.state and Managers.state.unit_spawner

	if unit_spawner then
		local ok, synced = pcall(unit_spawner.fully_hot_join_synced, unit_spawner)

		if ok and synced == false then
			return phase_by_id("sync")
		end

		if ok and state.saw_real_phase then
			return TERMINAL_PHASE
		end
	end

	return GENERIC_PHASE
end

local function begin_session()

	if state.phase and state.phase_started then
		record_duration(state.phase_kind, state.phase.id, state.last_draw - state.phase_started)
		save_calibration()
	end

	state.display = 0
	state.anchor = 0
	state.phase = nil
	state.phase_sub = 0
	state.peak_inflight = 0
	state.session_active = true
	state.saw_real_phase = false
	state.last_update = now()

	rebuild_slices()
end

local function enter_phase(phase, t)

	if state.phase then
		record_duration(state.phase_kind, state.phase.id, t - state.phase_started)
		save_calibration()
	end

	state.phase = phase
	state.phase_started = t

	state.phase_kind = state.kind or "other"
	state.phase_sub = 0
	state.peak_inflight = 0

	if PHASE_INDEX[phase.id] then
		state.saw_real_phase = true
	end
end

local function compute_phase_sub(phase, t)

	if phase.terminal then
		state.phase_sub = 1

		return 1
	end

	local elapsed = math.max(t - state.phase_started, 0)
	local expected = duration_for(state.kind or "other", phase.id, phase.default_time)

	local inflight = count_inflight()

	if inflight > state.peak_inflight then
		state.peak_inflight = inflight
	end

	local sub_packages

	if state.peak_inflight > 0 then
		sub_packages = 1 - inflight / state.peak_inflight
	end

	local sub_time = math.min(0.9, elapsed / (elapsed + math.max(expected, 0.1)))

	local sub = math.max(sub_packages or 0, sub_time)

	if sub > state.phase_sub then
		state.phase_sub = sub
	end

	return state.phase_sub
end

function Progress.update()
	local t = now()
	local session_started = false

	if not state.session_active or (t - state.last_draw) > SESSION_GAP then
		begin_session()

		session_started = true
	end

	state.last_draw = t

	local dt = math.clamp(t - state.last_update, 0, 0.5)
	state.last_update = t

	local phase = resolve_phase()

	if phase ~= state.phase then
		enter_phase(phase, t)
	end

	local lo, hi = slice_for(phase)
	local sub = compute_phase_sub(phase, t)
	local anchor = lo + (hi - lo) * sub

	if anchor > state.anchor then
		state.anchor = anchor
	end

	local blend = 1 - math.exp(-EASE_RATE * dt)
	local eased = state.display + (state.anchor - state.display) * blend

	state.display = math.clamp(math.max(eased, state.display), 0, math.min(hi, 1))

	return state.display, session_started
end

local function kind_from_mission(mission_name)
	if type(mission_name) ~= "string" then
		return nil
	end

	local missions = rawget(_G, "Missions")
	local mission = missions and missions[mission_name]

	if not mission then
		return nil
	end

	return mission.is_hub and "hub" or "mission"
end

function Progress.set_observed(loading_state_active, current_state, current_loading_state, mission_name)
	observed.active = loading_state_active
	observed.state = current_state
	observed.loading_state = current_loading_state

	local kind = kind_from_mission(mission_name)

	if kind and kind ~= state.kind then
		state.kind = kind

		if state.session_active then
			rebuild_slices()
		end
	end
end

function Progress.reset_calibration()
	state.cal = {}
	state.slices = nil
	state.dirty = false
	mod:set(CALIBRATION_SETTING, {})
end

return Progress
