

---@type mod
local mod = get_mod("dopamine")

if mod.event_manager then
	return mod.event_manager
end

local TimeWindow = mod:lib(mod.time_window, "lib/time_window")

local Constants = mod:core(mod.style_meter_constants, "hud/style_meter/constants").LOGIC
local EventRegistry = mod:core(mod.event_registry, "utils/event/registry")
local EventResolver = mod:core(mod.event_resolver, "utils/event/resolver")
local EventScoring = mod:core(mod.event_scoring, "utils/event/scoring")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local HitTrackers = mod:core(mod.hit_trackers, "utils/hit_trackers")
local Rumble = mod:core(mod.rumble, "utils/rumble")

local Persist = mod:persistent_table("session", { sp = 0 })
local PERSIST_SYNC_INTERVAL = 2 
local _persist_sync_timer = 0

---@class ActiveEvent
---@field id EventID
---@field label string|nil -- literal rich-text label (mutually exclusive with label_key)
---@field label_key string|nil -- localization key for the row label
---@field count integer -- how many times the event has stacked
---@field lifetime number -- remaining seconds before it expires
---@field max_lifetime number -- lifetime it was (re)seeded with, for the decay bar
---@field phase EventPhase
---@field phase_t number
---@field pulse_t number -- remaining pulse-highlight time
---@field slot integer|nil -- 1 = top row; kept through the exit animation
---@field slot_hint integer|nil -- last known slot, used by exiting-event snapshots
---@field ctx EventContext|nil -- context that last (re)fired the event

---@class SpPopup
---@field amount number
---@field phase SpPhase
---@field phase_t number

---@class ComboPopup
---@field amount number
---@field phase SpComboPhase
---@field phase_t number
---@field seed_display number|nil -- value the HUD adopts without counting up from zero
---@field kill_count integer|nil
---@field combo_earned number|nil -- SP earned during the combo (pre-bonus)
---@field sp_bonus number|nil -- finish bonus paid out at the end of the recap
---@field multiplier number|nil -- finish multiplier shown on the recap
---@field bonus_added boolean|nil -- guards paying the finish bonus exactly once

---@class EventManagerState
---@field active ActiveEvent[] -- events currently shown on the meter (slotted)
---@field exiting ActiveEvent[] -- events playing their exit animation
---@field target_sp number -- running SP total the HUD counter lerps toward
---@field sp_popup SpPopup|nil -- floating "+N" popup for ungrouped SP gains
---@field combo_popup ComboPopup|nil -- the single big end-of-combo recap popup
---@field event_rumble_pulse number
---@field event_rumble_amp number
---@field combo_sp_earned number -- SP accrued so far during the current qualifying combo
---@field multi_kill_times number[] -- timestamps of recent kills, for burst detection
---@field score_counts table<EventID, integer> -- counts for events not shown on the meter
---@field event_counts table<EventID, integer> -- per-mission fire count per event id (every fired event)
---@field is_sliding boolean
---@field slide_mult number
---@field target_style_mult number
---@field bonus_mult number -- additive bonus from a timed award (objective completion), 0 when none
---@field bonus_timer number -- seconds left on that bonus
---@field bonus_duration number -- the full length it was granted for, for the HUD's drain bar
---@field best_combo integer -- largest combo kill-streak this mission (for the summary)
---@type EventManagerState
local _state = {
	active = {},
	exiting = {},
	target_sp = 0,
	sp_popup = nil,
	combo_popup = nil,
	event_rumble_pulse = 0,
	event_rumble_amp = 0,
	combo_sp_earned = 0,
	multi_kill_times = {},
	score_counts = {},
	event_counts = {},
	is_sliding = false,
	slide_mult = 0,
	target_style_mult = 1,
	bonus_mult = 0,
	bonus_timer = 0,
	bonus_duration = 0,
	best_combo = 0,
}

_state.target_sp = Persist.sp or 0

local _event_listener = nil

---@class EventManager
local EventManager = {}

---@param listener fun(event_id: EventID, context: EventContext|nil)|nil
function EventManager.set_event_listener(listener)
	_event_listener = listener
end

---@return number
function EventManager.total_sp()
	return _state.target_sp
end

---@return table<EventID, integer>
function EventManager.event_counts()
	return _state.event_counts
end

---@return integer
function EventManager.best_combo()
	return _state.best_combo or 0
end

---@param event_id EventID
local function count_event(event_id)
	_state.event_counts[event_id] = (_state.event_counts[event_id] or 0) + 1
end

---@param event_id EventID
---@return integer|nil
local function find_active_index(event_id)
	for i = 1, #_state.active do
		if _state.active[i].id == event_id then
			return i
		end
	end

	return nil
end

---@param event_id EventID
---@return boolean
local function context_event_is_active(event_id)
	return find_active_index(event_id) ~= nil
end

---@param popup SpPopup
---@param amount number
local function refresh_sp_popup(popup, amount)
	popup.amount = popup.amount + amount

	if popup.phase ~= "out" then
		popup.phase = "hold"
		popup.phase_t = 0
	end
end

local function trigger_sp_rumble()

	Rumble.on_sp_gain()
end

---@param amplitude number|nil
local function trigger_event_rumble(amplitude)

	if mod.dl.settings.enable_rumble_global == false or mod.dl.settings.enable_rumble_on_gain == false then
		return
	end

	amplitude = amplitude or mod.constants.PULSE.AMP_MID
	if amplitude <= 0 then
		return
	end

	_state.event_rumble_pulse = mod.constants.PULSE.T
	_state.event_rumble_amp = math.max(_state.event_rumble_amp or 0, amplitude)
end

---@param event_id EventID
---@param count number|nil
---@return number bonus
local function event_mult_bonus(event_id, count)
	local per_count = Constants.EVENT_MULT and Constants.EVENT_MULT[event_id] or 0

	if per_count <= 0 then
		return 0
	end

	return per_count * math.max(count or 1, 1)
end

---@return number bonus
local function active_event_mult_bonus()
	local bonus = 0

	for i = 1, #_state.active do
		local event = _state.active[i]
		bonus = bonus + event_mult_bonus(event.id, event.count)
	end

	return bonus
end

---@return number
local function recompute_style_mult()
	return 1
		+ EventScoring.fury_mult_bonus(ComboState.fury)
		+ active_event_mult_bonus()
		+ (_state.slide_mult or 0)
		+ (_state.bonus_timer > 0 and _state.bonus_mult or 0)
end

local function refresh_style_mult()
	_state.target_style_mult = recompute_style_mult()
end

---@param amount number additive bonus
---@param duration number seconds
function EventManager.add_timed_mult(amount, duration)
	if amount <= 0 or duration <= 0 then
		return
	end

	if _state.bonus_timer > 0 and _state.bonus_mult > amount then
		amount = _state.bonus_mult
	end

	_state.bonus_mult = amount
	_state.bonus_timer = duration
	_state.bonus_duration = duration

	refresh_style_mult()
end

---@return number
function EventManager.style_multiplier()
	return _state.target_style_mult or 1
end

---@return boolean
local function combo_qualifies()
	return ComboState.active and (ComboState.kills or 0) >= ComboState.minimum_combo()
end

---@return number
function EventManager.scoring_multiplier()
	return EventManager.style_multiplier()
end

---@param kills number|nil
---@return number amplitude
local function combo_finish_rumble_amp(kills)
	local kill_factor = math.min((kills or 0) / Constants.COMBO_FINISH_RUMBLE_REF_KILLS, 1)
	local pulse = mod.constants.PULSE
	return pulse.AMP_MID + (pulse.AMP_MAX - pulse.AMP_MID) * kill_factor
end

---@param amount number
---@return number
local function apply_style_mult(amount)
	local multiplier = EventManager.scoring_multiplier()
	if multiplier > 1 then
		return math.floor(amount * multiplier)
	end

	return amount
end

---@param amount number
---@return number added
local function add_sp_direct(amount)
	if amount <= 0 then
		return 0
	end

	if mod.dl.settings.global_sp_multiplier and mod.dl.settings.global_sp_multiplier ~= 1 then
		amount = math.max(mod.dl.settings.global_sp_multiplier, 0.1) * amount
	end

	_state.target_sp = _state.target_sp + amount
	trigger_sp_rumble()
	return amount
end

---@param phase string|nil
---@return boolean
local function is_combo_popup_recap(phase)
	return phase == "recap"
end

local function clear_combo_popup_for_new_combo()
	local combo_popup = _state.combo_popup
	if not combo_popup then
		return
	end

	if is_combo_popup_recap(combo_popup.phase) and not combo_popup.bonus_added and (combo_popup.sp_bonus or 0) > 0 then
		add_sp_direct(combo_popup.sp_bonus)
	end

	_state.combo_popup = nil
end

---@param amount number
local function push_combo_popup(amount)
	if amount <= 0 then
		return
	end

	if _state.combo_popup and is_combo_popup_recap(_state.combo_popup.phase) then
		clear_combo_popup_for_new_combo()
	end

	local combo_popup = _state.combo_popup
	if not combo_popup then

		local combo_from_sp_popup = _state.sp_popup
		_state.sp_popup = nil

		if combo_from_sp_popup and combo_from_sp_popup.phase ~= EventEnums.SP_COMBO_PHASE.out then
			local carried_amount = combo_from_sp_popup.amount + amount
			_state.combo_popup = {
				amount = carried_amount,
				phase = combo_from_sp_popup.phase == EventEnums.SP_COMBO_PHASE.rise and EventEnums.SP_COMBO_PHASE.rise
					or EventEnums.SP_COMBO_PHASE.combo,
				phase_t = combo_from_sp_popup.phase == EventEnums.SP_COMBO_PHASE.rise and combo_from_sp_popup.phase_t
					or 0,
				seed_display = carried_amount,
			}
		else
			_state.combo_popup = {
				amount = amount,
				phase = EventEnums.SP_COMBO_PHASE.rise,
				phase_t = 0,
			}
		end
		return
	end

	if combo_popup.phase == EventEnums.SP_COMBO_PHASE.rise or combo_popup.phase == EventEnums.SP_COMBO_PHASE.combo then
		combo_popup.amount = combo_popup.amount + amount
	end
end

---@param amount number
local function push_sp_popup(amount)
	if amount <= 0 then
		return
	end

	if combo_qualifies() then
		push_combo_popup(amount)
		return
	end

	if _state.combo_popup then
		return
	end

	local popup = _state.sp_popup

	if popup and popup.phase ~= EventEnums.SP_PHASE.out then
		refresh_sp_popup(popup, amount)
		return
	end

	_state.sp_popup = {
		amount = amount,
		phase = EventEnums.SP_PHASE.rise,
		phase_t = 0,
	}
end

---@param amount number
---@return number added
local function add_sp(amount)
	if amount <= 0 then
		return 0
	end

	amount = apply_style_mult(amount)

	if combo_qualifies() then
		_state.combo_sp_earned = _state.combo_sp_earned + amount
	end

	if mod.dl.settings.global_sp_multiplier and mod.dl.settings.global_sp_multiplier ~= 1 then
		amount = math.max(mod.dl.settings.global_sp_multiplier, 0.1) * amount
	end

	_state.target_sp = _state.target_sp + amount
	push_sp_popup(amount)
	trigger_sp_rumble()
	return amount
end

---@param amount number|nil
---@return number added
function EventManager.add_reward(amount)
	amount = math.floor(amount or 0)
	if amount <= 0 then
		return 0
	end

	add_sp_direct(amount)
	push_sp_popup(amount)
	return amount
end

---@return table<integer, boolean>
local function occupied_exit_slots()
	local occupied = {}

	for i = 1, #_state.exiting do
		local slot = _state.exiting[i].slot
		if slot then
			occupied[slot] = true
		end
	end

	return occupied
end

local function resolve_slot_collisions_with_exiting()
	if #_state.exiting == 0 then
		return
	end

	local occupied = occupied_exit_slots()

	for i = 1, #_state.active do
		local event = _state.active[i]
		while occupied[event.slot] and event.slot < mod.dl.settings.max_event_slots do
			event.slot = event.slot + 1
		end
	end
end

local function bump_active_slots_for_insert()
	for i = 1, #_state.active do
		_state.active[i].slot = (_state.active[i].slot or i) + 1
	end
end

---@param event ActiveEvent
local function insert_active_at_top(event)
	bump_active_slots_for_insert()
	event.slot = 1
	table.insert(_state.active, 1, event)
	resolve_slot_collisions_with_exiting()
end

---@param index integer
local function remove_active_at(index)
	table.remove(_state.active, index)
end

local function evict_bottom()
	local bottom_event = _state.active[#_state.active]
	if not bottom_event then
		return
	end

	if bottom_event.id == EventEnums.EVENT_ID.berserk then
		HitTrackers.Berserk:reset()
	end

	if bottom_event.id == EventEnums.EVENT_ID.mag_dump then
		HitTrackers.MagDump:reset()
	end

	bottom_event.phase = EventEnums.EVENT_PHASE.exit_evict
	bottom_event.phase_t = 0
	_state.exiting[#_state.exiting + 1] = bottom_event
	remove_active_at(#_state.active)
end

---@param definition Event
---@return number lifetime
local function resolve_lifetime(definition)
	if mod.dl.settings.debug_enable_permanent_events then
		return Constants.EVENTS_LIFETIME.DEBUG
	end
	return definition.lifetime or Constants.EVENTS_LIFETIME.DEFAULT
end

---@param definition Event
---@param context EventContext|nil
---@return ActiveEvent
local function create_event(definition, context)
	local lifetime = resolve_lifetime(definition)
	---@type ActiveEvent
	local event = {
		id = definition.id,
		label = definition.label,
		label_key = definition.label_key,
		count = 1,
		lifetime = lifetime,
		max_lifetime = lifetime,
		phase = EventEnums.EVENT_PHASE.active,
		phase_t = 0,
		pulse_t = mod.constants.PULSE.T,
		slot = 1,
		ctx = context,
	}
	return event
end

---@param event ActiveEvent
---@param definition Event
---@param context EventContext|nil
local function refresh_event(event, definition, context)
	event.count = event.count + 1
	event.lifetime = resolve_lifetime(definition)
	event.max_lifetime = event.lifetime
	event.phase = EventEnums.EVENT_PHASE.active
	event.phase_t = 0
	event.pulse_t = mod.constants.PULSE.T
	event.ctx = context
end

---@param event ActiveEvent|{ count: integer }
---@param event_id EventID
---@param context EventContext
local function apply_event_count(event, event_id, context)
	if event_id == EventEnums.EVENT_ID.multi_kill and context.kills_in_burst then
		event.count = context.kills_in_burst
	elseif event_id == EventEnums.EVENT_ID.berserk and context.hit_count then
		event.count = HitTrackers.Berserk:hits_since_threshold(context.hit_count)
	elseif event_id == EventEnums.EVENT_ID.mag_dump and context.hit_count then
		event.count = HitTrackers.MagDump:hits_since_threshold(context.hit_count)
	end
end

---@return integer burst_size
local function record_multi_kill_burst()
	local time_manager = Managers.time
	local now = time_manager and time_manager:time("gameplay") or 0

	return TimeWindow.push(_state.multi_kill_times, now, Constants.MULTI_KILL_WINDOW)
end

---@param event_id EventID
---@param old_count number
---@param new_count number
---@param context EventContext
---@return number delta
local function add_cashout_delta(event_id, old_count, new_count, context)
	if new_count <= old_count then
		return 0
	end

	local delta = EventScoring.sp_cashout(event_id, new_count, context)
		- EventScoring.sp_cashout(event_id, old_count, context)
	if delta > 0 then
		add_sp(delta)
	end

	return delta
end

---@param definition Event|nil
---@return boolean
local function shows_in_meter(definition)
	return definition and definition.show_in_meter ~= false
end

---@param event_id EventID
---@return integer
local function event_count(event_id)
	local active_index = find_active_index(event_id)
	if active_index then
		return _state.active[active_index].count
	end

	return _state.score_counts[event_id] or 0
end

---@param event_id EventID
---@param context EventContext
---@return number sp_reward
local function trigger_event_id(event_id, context)
	local definition = EventRegistry.by_id(event_id)
	if not definition then
		return 0
	end

	count_event(event_id)

	local active_index = find_active_index(event_id)
	local old_count = event_count(event_id)
	local trigger_sp = EventScoring.sp_trigger(event_id, old_count + 1, context)
	local added_sp = add_sp(trigger_sp)

	if active_index then

		local event = _state.active[active_index]
		refresh_event(event, definition, context)
		apply_event_count(event, event_id, context)
		trigger_event_rumble()
		local cashout_sp = add_cashout_delta(event_id, old_count, event.count, context)
		refresh_style_mult()
		return added_sp + cashout_sp
	end

	if not shows_in_meter(definition) then

		local scratch_event = { count = old_count + 1 }
		apply_event_count(scratch_event, event_id, context)
		_state.score_counts[event_id] = scratch_event.count
		local cashout_sp = add_cashout_delta(event_id, old_count, scratch_event.count, context)
		return added_sp + cashout_sp
	end

	local event = create_event(definition, context)
	apply_event_count(event, event_id, context)
	local cashout_sp = add_cashout_delta(event_id, 0, event.count, context)

	if #_state.active >= mod.dl.settings.max_event_slots then
		evict_bottom()
	end

	insert_active_at_top(event)
	trigger_event_rumble()
	refresh_style_mult()
	return added_sp + cashout_sp
end

---@param kills integer
---@param context EventContext|table
local function insert_combo_finish_event(kills, context)
	local definition = EventRegistry.by_id(EventEnums.EVENT_ID.combo_finish)
	if not definition then
		return
	end

	count_event(EventEnums.EVENT_ID.combo_finish)

	local active_index = find_active_index(EventEnums.EVENT_ID.combo_finish)
	if active_index then
		local event = _state.active[active_index]
		event.count = kills
		event.lifetime = resolve_lifetime(definition)
		event.max_lifetime = event.lifetime
		event.phase = EventEnums.EVENT_PHASE.active
		event.phase_t = 0
		event.pulse_t = mod.constants.PULSE.T
		event.ctx = context
		trigger_event_rumble(combo_finish_rumble_amp(kills))
		return
	end

	local event = create_event(definition, context)
	event.count = kills

	if #_state.active >= mod.dl.settings.max_event_slots then
		evict_bottom()
	end

	insert_active_at_top(event)
	trigger_event_rumble(combo_finish_rumble_amp(kills))
end

---@param combo_popup ComboPopup
---@param kill_count integer
---@param earned_sp number
local function begin_combo_finish_recap(combo_popup, kill_count, earned_sp)
	local context = {
		kill_count = kill_count,
		combo_sp_earned = earned_sp,
	}

	insert_combo_finish_event(kill_count, context)

	_state.sp_popup = nil

	combo_popup.phase = "recap"
	combo_popup.phase_t = 0
	combo_popup.kill_count = kill_count
	combo_popup.combo_earned = earned_sp
	combo_popup.amount = earned_sp
	combo_popup.bonus_added = false
end

---@class EventKillDistance
---@field metres number|nil                          -- distance from player, or nil if unknown
---@field between fun(a: number, b: number): boolean  -- nil-safe range test (false when metres is nil)

---@class EventContext
---@field hit_weakspot boolean                        -- kill: killing blow hit a weakspot
---@field breed_taxonomy UseBreedsBreedTaxonomy|nil            -- kill: using darklib breeds taxonomy table
---@field breed_data FatsharkBreedData|nil                    -- kill/hit: affected minion's breed
---@field damage number                               -- kill: killing-blow damage
---@field attack_type "melee"|"ranged"|nil            -- kill/hit: attack type
---@field kill_distance EventKillDistance             -- kill: distance helper (always structured)
---@field kills_in_burst number                       -- kill: kills inside the multi-kill window
---@field hit_count number|nil                        -- hit: running hit count (berserk/mag_dump)
---@field is_sliding boolean                          -- kill: player was sliding
---@field event_is_active fun(event_id: EventID): boolean -- is an event row currently on the meter

---@param metres number|nil
---@return EventKillDistance
local function make_kill_distance(metres)
	return {
		metres = metres,
		between = function(a, b)
			if metres == nil then
				return false
			end
			local min, max = math.min(a, b), math.max(a, b)
			return metres >= min and metres <= max
		end,
	}
end

---@return EventContext
local function default_context()
	return {
		hit_weakspot = false,
		breed_data = nil,
		damage = 0,
		attack_type = nil,
		kill_distance = make_kill_distance(nil),
		kills_in_burst = 0,
		hit_count = nil,
		is_sliding = false,
		event_is_active = context_event_is_active,
	}
end

---@param raw_context { hit_weakspot: boolean|nil,

---@return EventContext
function EventManager.make_context(raw_context)
	raw_context = raw_context or {}

	local context = default_context()
	local breed_data = raw_context.breed_data

	context.hit_weakspot = raw_context.hit_weakspot or false
	context.breed_taxonomy = breed_data and mod.dl.breeds.breed_taxonomy(breed_data) or nil
	context.breed_data = breed_data
	context.damage = raw_context.damage or 0
	context.attack_type = raw_context.attack_type
	context.kill_distance = make_kill_distance(raw_context.distance)
	context.kills_in_burst = record_multi_kill_burst()
	context.is_sliding = _state.is_sliding

	return context
end

---@param hit_count number
---@param breed_data FatsharkBreedData|nil
---@return EventContext
function EventManager.make_hit_context(hit_count, breed_data)
	local context = default_context()

	context.hit_count = hit_count
	context.breed_data = breed_data

	return context
end

---@param signal_name SignalID
---@param context EventContext|nil
---@return integer sp_reward
function EventManager.signal(signal_name, context)
	context = context or default_context()

	local event_ids = EventResolver.resolve(context, signal_name)
	local sp_reward = 0

	for i = 1, #event_ids do
		sp_reward = sp_reward + (trigger_event_id(event_ids[i], context) or 0)
		if _event_listener then
			_event_listener(event_ids[i], context)
		end
	end

	return sp_reward
end

---@param event_id EventID
---@param context EventContext
---@return integer
function EventManager.trigger(event_id, context)
	local awarded = trigger_event_id(event_id, context) or 0
	if _event_listener then
		_event_listener(event_id, context)
	end
	return awarded
end

function EventManager.on_successful_dodge()
	EventManager.signal(EventEnums.SIGNAL_ID.dodge)
end

function EventManager.on_perfect_block()
	EventManager.signal(EventEnums.SIGNAL_ID.perfect_block)
end

function EventManager.on_parry()
	EventManager.signal(EventEnums.SIGNAL_ID.parry)
end

function EventManager.on_slide_start()
	_state.slide_mult = 0
	_state.is_sliding = true
	refresh_style_mult()
end

---@param sliding boolean
---@param dt number|nil
function EventManager.set_sliding(sliding, dt)
	if sliding then
		_state.slide_mult = (_state.slide_mult or 0) + (Constants.SLIDE_MULT_RATE or 0) * (dt or 0)
		refresh_style_mult()
		return
	end

	if (_state.slide_mult or 0) > 0 then
		_state.slide_mult = 0
		refresh_style_mult()
	end
end

function EventManager.on_slide_end()
	_state.slide_mult = 0
	_state.is_sliding = false
	refresh_style_mult()
end

---@param kill_count integer|nil
function EventManager.on_combo_break(kill_count)
	local earned_sp = _state.combo_sp_earned
	_state.combo_sp_earned = 0

	if kill_count and kill_count > (_state.best_combo or 0) then
		_state.best_combo = kill_count
	end

	local min_combo = ComboState.minimum_combo()
	local combo_popup = _state.combo_popup

	if not kill_count or kill_count < min_combo then
		if combo_popup then
			_state.sp_popup = nil
			combo_popup.amount = earned_sp
			combo_popup.phase = "wait"
			combo_popup.phase_t = 0
		end
		return
	end

	if combo_popup then
		combo_popup.sp_bonus = EventScoring.sp_combo_finish(earned_sp, kill_count)
		combo_popup.multiplier = EventScoring.combo_finish_multiplier(kill_count)
		begin_combo_finish_recap(combo_popup, kill_count, earned_sp)
		return
	end

	local context = {
		kill_count = kill_count,
		combo_sp_earned = earned_sp,
	}
	insert_combo_finish_event(kill_count, context)
end

---@param event ActiveEvent
local function finish_exiting(event)
	local freed_slot = event.slot

	for i = #_state.exiting, 1, -1 do
		if _state.exiting[i] == event then
			table.remove(_state.exiting, i)
			break
		end
	end

	if freed_slot then
		for i = 1, #_state.active do
			if _state.active[i].slot > freed_slot then
				_state.active[i].slot = _state.active[i].slot - 1
			end
		end

		resolve_slot_collisions_with_exiting()
	end
end

---@param event ActiveEvent
local function expire_event(event)
	if event.id == EventEnums.EVENT_ID.berserk then
		HitTrackers.Berserk:reset()
	end
	if event.id == EventEnums.EVENT_ID.mag_dump then
		HitTrackers.MagDump:reset()
	end

	event.phase = EventEnums.EVENT_PHASE.exit_expire
	event.phase_t = 0
	_state.exiting[#_state.exiting + 1] = event
end

---@param dt number|nil
function EventManager.tick(dt)
	dt = dt or 0

	for i = #_state.active, 1, -1 do
		local event = _state.active[i]
		event.lifetime = event.lifetime - dt

		if event.pulse_t > 0 then
			event.pulse_t = math.max(0, event.pulse_t - dt)
		end

		if event.lifetime <= 0 then
			remove_active_at(i)
			expire_event(event)
		end
	end

	if _state.bonus_timer > 0 then
		_state.bonus_timer = _state.bonus_timer - dt

		if _state.bonus_timer <= 0 then
			_state.bonus_timer = 0
			_state.bonus_mult = 0
			_state.bonus_duration = 0
		end
	end

	refresh_style_mult()

	for i = #_state.exiting, 1, -1 do
		local event = _state.exiting[i]
		event.phase_t = event.phase_t + dt

		if event.phase_t >= mod.constants.TRAN_SLIDE.T_FAST then
			finish_exiting(event)
		end
	end

	local popup = _state.sp_popup
	if popup then
		popup.phase_t = popup.phase_t + dt

		if popup.phase == EventEnums.SP_PHASE.rise then
			if popup.phase_t >= mod.constants.TRAN_SLIDE.T_FAST then
				popup.phase = EventEnums.SP_PHASE.hold
				popup.phase_t = 0
			end
		elseif popup.phase == EventEnums.SP_PHASE.hold then
			if popup.phase_t >= Constants.SP_POPUP_HOLD_TIME then
				popup.phase = EventEnums.SP_PHASE.wait
				popup.phase_t = 0
			end
		elseif popup.phase == EventEnums.SP_PHASE.wait then
			if popup.phase_t >= Constants.SP_POPUP_OUT_WAIT then
				popup.phase = EventEnums.SP_PHASE.out
				popup.phase_t = 0
			end
		elseif popup.phase == EventEnums.SP_PHASE.out then
			if popup.phase_t >= mod.constants.TRAN_SLIDE.T_SLOW then
				_state.sp_popup = nil
			end
		end
	end

	local combo_popup = _state.combo_popup
	if combo_popup then
		if _state.sp_popup then
			_state.sp_popup = nil
		end

		combo_popup.phase_t = combo_popup.phase_t + dt

		if combo_popup.phase == EventEnums.SP_COMBO_PHASE.rise then
			if combo_popup.phase_t >= mod.constants.TRAN_SLIDE.T_FAST then
				combo_popup.phase = EventEnums.SP_COMBO_PHASE.combo
				combo_popup.phase_t = 0
			end
		elseif combo_popup.phase == EventEnums.SP_COMBO_PHASE.combo then

		elseif combo_popup.phase == EventEnums.SP_COMBO_PHASE.recap then
			if combo_popup.phase_t >= Constants.SP_COMBO_RECAP_LERP_TIME then
				if not combo_popup.bonus_added then
					add_sp_direct(combo_popup.sp_bonus or 0)
					combo_popup.bonus_added = true
				end
				combo_popup.phase = EventEnums.SP_COMBO_PHASE.out
				combo_popup.phase_t = 0
			end
		elseif combo_popup.phase == EventEnums.SP_COMBO_PHASE.wait then
			if combo_popup.phase_t >= Constants.SP_POPUP_OUT_WAIT then
				combo_popup.phase = EventEnums.SP_COMBO_PHASE.out
				combo_popup.phase_t = 0
			end
		elseif combo_popup.phase == EventEnums.SP_COMBO_PHASE.out then
			if combo_popup.phase_t >= mod.constants.TRAN_SLIDE.T_SLOW then
				_state.combo_popup = nil
			end
		end
	end

	if _state.event_rumble_pulse > 0 then
		_state.event_rumble_pulse = math.max(0, _state.event_rumble_pulse - dt)
		if _state.event_rumble_pulse <= 0 then
			_state.event_rumble_amp = 0
		end
	end

	_persist_sync_timer = _persist_sync_timer + dt
	if _persist_sync_timer >= PERSIST_SYNC_INTERVAL then
		_persist_sync_timer = _persist_sync_timer - PERSIST_SYNC_INTERVAL
		Persist.sp = _state.target_sp
	end
end

---@param destination table
---@param event ActiveEvent
---@param slot_index integer
---@return ActiveEvent destination
local function copy_event_into(destination, event, slot_index)
	destination.id = event.id
	destination.label = event.label
	destination.label_key = event.label_key
	destination.count = event.count
	destination.lifetime = event.lifetime
	destination.max_lifetime = event.max_lifetime
	destination.phase = event.phase
	destination.phase_t = event.phase_t
	destination.pulse_t = event.pulse_t
	destination.slot_hint = slot_index
	return destination
end

local _snapshot_events = {}
local _snapshot_exiting = {}
local _snapshot_sp_popup = {}
local _snapshot_combo_popup = {}
local _event_copy_pool = {}
local _event_copy_pool_used = 0

---@return table
local function event_copy_from_pool()
	_event_copy_pool_used = _event_copy_pool_used + 1
	local copy = _event_copy_pool[_event_copy_pool_used]
	if not copy then
		copy = {}
		_event_copy_pool[_event_copy_pool_used] = copy
	end
	return copy
end

---@class StyleMeterSnapshot
---@field events table<integer, ActiveEvent> -- active-event copies, keyed by slot
---@field exiting ActiveEvent[] -- exiting-event copies, sequential
---@field sp_popup SpPopup|nil
---@field combo_popup ComboPopup|nil
---@field target_sp number
---@field event_rumble_pulse number
---@field event_rumble_amp number
---@field target_style_mult number
---@field style_mult_base number
---@type StyleMeterSnapshot
local _snapshot = {
	events = _snapshot_events,
	exiting = _snapshot_exiting,
}

---@return StyleMeterSnapshot
function EventManager.snapshot()
	_event_copy_pool_used = 0

	local events_by_slot = _snapshot_events
	for slot in pairs(events_by_slot) do
		events_by_slot[slot] = nil
	end
	for i = 1, #_state.active do
		local event = _state.active[i]
		local slot = event.slot or i
		event.slot = slot
		events_by_slot[slot] = copy_event_into(event_copy_from_pool(), event, slot)
	end

	local exiting = _snapshot_exiting
	local exiting_count = #_state.exiting
	for i = 1, exiting_count do
		local event = _state.exiting[i]
		local slot = event.slot or event.slot_hint or 0
		exiting[i] = copy_event_into(event_copy_from_pool(), event, slot)
	end
	for i = exiting_count + 1, #exiting do
		exiting[i] = nil
	end

	local sp_popup = nil
	if _state.sp_popup then
		local live_popup = _state.sp_popup
		sp_popup = _snapshot_sp_popup
		if live_popup then
			sp_popup.amount = live_popup.amount
			sp_popup.phase = live_popup.phase
			sp_popup.phase_t = live_popup.phase_t
		end
	end

	local combo_popup = nil
	if _state.combo_popup then
		local live_combo_popup = _state.combo_popup
		if live_combo_popup then
			combo_popup = _snapshot_combo_popup
			combo_popup.amount = live_combo_popup.amount
			combo_popup.combo_earned = live_combo_popup.combo_earned
			combo_popup.phase = live_combo_popup.phase
			combo_popup.phase_t = live_combo_popup.phase_t
			combo_popup.kill_count = live_combo_popup.kill_count
			combo_popup.multiplier = live_combo_popup.multiplier
			combo_popup.sp_bonus = live_combo_popup.sp_bonus
			combo_popup.seed_display = live_combo_popup.seed_display
		end
	end

	local snapshot = _snapshot
	snapshot.sp_popup = sp_popup
	snapshot.combo_popup = combo_popup
	snapshot.target_sp = _state.target_sp
	snapshot.event_rumble_pulse = _state.event_rumble_pulse
	snapshot.event_rumble_amp = _state.event_rumble_amp
	snapshot.target_style_mult = _state.target_style_mult
	snapshot.style_mult_base = 1

	snapshot.bonus_mult = _state.bonus_mult
	snapshot.bonus_mult_active = _state.bonus_timer > 0
	snapshot.bonus_mult_fraction = _state.bonus_duration > 0 and (_state.bonus_timer / _state.bonus_duration) or 0

	return snapshot
end

function EventManager.reset()
	HitTrackers.reset_all()

	_state.active = {}
	_state.exiting = {}
	_state.target_sp = 0
	_state.sp_popup = nil
	_state.combo_popup = nil
	_state.event_rumble_pulse = 0
	_state.event_rumble_amp = 0
	_state.combo_sp_earned = 0
	_state.multi_kill_times = {}
	_state.score_counts = {}
	_state.event_counts = {}
	_state.slide_mult = 0
	_state.target_style_mult = 1
	_state.bonus_mult = 0
	_state.bonus_timer = 0
	_state.bonus_duration = 0
	_state.best_combo = 0

	Persist.sp = 0
	_persist_sync_timer = 0
end

mod.event_manager = EventManager

return EventManager
