---@type mod
local mod = get_mod("dopamine")

if mod.combo_state then
	return mod.combo_state
end

local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp

local BASE_UNIT = 1.0

local FuryMeterConstants = mod:core(mod.fury_meter_constants, "hud/fury_meter/constants")
local KillRate = mod:core(mod.kill_rate, "utils/kill_rate")

local MAX_FURY = FuryMeterConstants.LOGIC.MAX_FURY_PCT

---@class ComboState
local ComboState = {
	fury = 0,
	fatigue = 0,
	ghost = 0,
	ghost_timer = 0,
	grace_timer = 0,
	kills = 0,
	best_kills = 0,
	total_kills = 0,
	last_combo_kills = 0, 
	active = false,
	combo_time = 0, 
	fury_lock_timer = 0, 
	fury_gain_cooldown = 0, 
	fatigue_gain_cooldown = 0, 
	fury_damage_penalty_cooldown = 0,

	config = {
		fury_drain_seconds = 10,
		fury_low_drain_threshold_pct = 5,
		high_fatigue_threshold_pct = 85,
		fury_fatigue_drain_rate_pct = 300,
		fury_damage_penalty = 0.25,
		grace_duration = 0.25,
		fury_kill_mult = 1,
		fury_damage_mult = 0.3,
		fury_min_damage_gain = 2.5,
		fury_max_damage_gain = 15,
		fury_min_gain_mult = 0.1,
		grace_min_duration_mult = 0.05,
		fatigue_kill_mult = 0.1,
		fatigue_damage_mult = 0.15,
		fatigue_min_damage_gain = 0.1,
		fatigue_max_damage_gain = 4.0,
		fatigue_passive_per_second = 4,
		fatigue_passive_ramp_seconds = 120,
		fatigue_milestone_interval = 10,
		fatigue_milestone_reduction = 15,
		max_fury_fatigue_add = 20,
		grace_per_damage = 0.02,
		grace_max = 1.25,
		grace_drain_percent = 3,
		fury_damage_reference = 100,
		fury_max_lock_seconds = 4,
		dps_window_seconds = 1,
		dps_update_hz = 8,
		dps_display_decay_seconds = 1.5,
	},
}

local Dps = mod.dl.dps.new({
	dps_window_seconds = ComboState.config.dps_window_seconds,
	dps_update_hz = ComboState.config.dps_update_hz,
	dps_display_decay_seconds = ComboState.config.dps_display_decay_seconds,
})

local Kills = KillRate.new({ window_seconds = mod.dl.settings.statline_kpm_interval_seconds })

---@alias StatlineItem "none" | "current_combo" |"best_combo" |"last_combo" |"total_kills" |"kills_interval" |"dps" |"fatigue_pct" |"fury_pct"

local function statline_active(stat_id)
	local active = mod.dl.settings.statline_active_stats
	return active ~= nil and active[stat_id] == true
end

---@type EventManager
local _event_manager
local function get_event_manager()
	_event_manager = _event_manager or mod:core(mod.event_manager, "utils/event/manager")
	return _event_manager
end

function ComboState.set_config(new_values)
	local config = ComboState.config
	for key, value in pairs(new_values) do
		if value ~= nil and config[key] ~= nil then
			config[key] = value
		end
	end
end

local CONFIG_SETTING_KEYS = {
	"fury_drain_seconds",
	"fury_fatigue_drain_rate_pct",
	"fury_damage_penalty",
	"grace_duration",
	"fury_kill_mult",
	"fury_damage_mult",
	"fury_min_damage_gain",
	"fury_max_damage_gain",
	"fury_min_gain_mult",
	"grace_min_duration_mult",
	"fatigue_kill_mult",
	"fatigue_damage_mult",
	"fatigue_min_damage_gain",
	"fatigue_max_damage_gain",
	"fatigue_passive_per_second",
	"fatigue_passive_ramp_seconds",
	"fatigue_milestone_interval",
	"fatigue_milestone_reduction",
	"max_fury_fatigue_add",
	"grace_per_damage",
	"grace_max",
	"grace_drain_percent",
	"fury_damage_reference",
}

local CONFIG_DEFAULTS = {}
for i = 1, #CONFIG_SETTING_KEYS do
	local key = CONFIG_SETTING_KEYS[i]
	CONFIG_DEFAULTS[key] = ComboState.config[key]
end

local _config_scratch = {}
function ComboState.sync_config_from_settings()
	for i = 1, #CONFIG_SETTING_KEYS do
		local key = CONFIG_SETTING_KEYS[i]
		local value = mod:get(key)
		if value == nil then
			value = CONFIG_DEFAULTS[key]
		end
		_config_scratch[key] = value
	end
	ComboState.set_config(_config_scratch)
end

ComboState.sync_config_from_settings()
mod.dl.settings.hook_settings_changed(function(_setting_id)
	ComboState.sync_config_from_settings()
end)

local freeze_reasons = {}
local freeze_count = 0

function ComboState.set_frozen(reason, active)
	local held = freeze_reasons[reason] == true
	active = active == true

	if held == active then
		return
	end

	freeze_reasons[reason] = active or nil
	freeze_count = freeze_count + (active and 1 or -1)
end

function ComboState.is_frozen()
	return freeze_count > 0
end

local function clear_freezes()
	for reason in pairs(freeze_reasons) do
		freeze_reasons[reason] = nil
	end
	freeze_count = 0
end

local function log_gains(event, fury, fatigue)
	if mod.dl.settings.debug_log_fury_fatigue_gain then
		mod:echo(string.format("%s %d | %d", event, fury, fatigue))
	end
end

function ComboState.minimum_combo()
	return 8
end

function ComboState.reset(reset_mission_stats)

	clear_freezes()

	ComboState.fury = 0
	ComboState.ghost = 0
	ComboState.ghost_timer = 0
	ComboState.grace_timer = 0
	ComboState.kills = 0
	ComboState.active = false
	ComboState.combo_time = 0
	ComboState.fury_lock_timer = 0
	ComboState.fury_gain_cooldown = 0
	ComboState.fatigue_gain_cooldown = 0
	ComboState.fury_damage_penalty_cooldown = 0

	if reset_mission_stats then
		ComboState.fatigue = 0
		ComboState.best_kills = 0
		ComboState.total_kills = 0
		ComboState.last_combo_kills = 0
		Dps:reset()
		Kills:reset()
	end
end

local function break_combo()
	local kills = ComboState.kills
	if kills > 0 then

		if kills >= ComboState.minimum_combo() then
			ComboState.last_combo_kills = kills
		end
		get_event_manager().on_combo_break(kills)
	end

	ComboState.fury = 0
	ComboState.fatigue = 0
	ComboState.ghost = 0
	ComboState.ghost_timer = 0
	ComboState.grace_timer = 0
	ComboState.kills = 0
	ComboState.active = false
	ComboState.combo_time = 0
	ComboState.fury_lock_timer = 0
	ComboState.fury_gain_cooldown = 0
	ComboState.fatigue_gain_cooldown = 0
	ComboState.fury_damage_penalty_cooldown = 0
end

local function gain_throttle_seconds()
	local throttle = FuryMeterConstants.LOGIC.DAMAGE_GAIN_THROTTLE
	if not throttle or throttle <= 0 then
		return 0
	end
	return throttle
end

local function tick_gain_cooldowns(dt)
	if ComboState.fury_gain_cooldown > 0 then
		ComboState.fury_gain_cooldown = math_max(0, ComboState.fury_gain_cooldown - dt)
	end
	if ComboState.fatigue_gain_cooldown > 0 then
		ComboState.fatigue_gain_cooldown = math_max(0, ComboState.fatigue_gain_cooldown - dt)
	end
	if ComboState.fury_damage_penalty_cooldown > 0 then
		ComboState.fury_damage_penalty_cooldown = math_max(0, ComboState.fury_damage_penalty_cooldown - dt)
	end
end

local function damage_penalty_throttle_seconds()
	local throttle = FuryMeterConstants.LOGIC.DAMAGE_PENALTY_THROTTLE
	if not throttle or throttle <= 0 then
		return 0
	end

	return throttle
end

local function damage_penalty_allowed()
	local throttle = damage_penalty_throttle_seconds()
	return throttle <= 0 or ComboState.fury_damage_penalty_cooldown <= 0
end

local function mark_damage_penalty()
	local throttle = damage_penalty_throttle_seconds()
	if throttle > 0 then
		ComboState.fury_damage_penalty_cooldown = throttle
	end
end

local function fury_gain_allowed()
	local throttle = gain_throttle_seconds()
	return throttle <= 0 or ComboState.fury_gain_cooldown <= 0
end

local function fatigue_gain_allowed()
	local throttle = gain_throttle_seconds()
	return throttle <= 0 or ComboState.fatigue_gain_cooldown <= 0
end

local function mark_fury_gain()
	local throttle = gain_throttle_seconds()
	if throttle > 0 then
		ComboState.fury_gain_cooldown = throttle
	end
end

local function mark_fatigue_gain()
	local throttle = gain_throttle_seconds()
	if throttle > 0 then
		ComboState.fatigue_gain_cooldown = throttle
	end
end

local function fury_locked()
	return ComboState.fury_lock_timer > 0
end

local function apply_max_fury_fatigue()
	local add = ComboState.config.max_fury_fatigue_add
	if add and add > 0 then
		ComboState.fatigue = math_min(100, ComboState.fatigue + add)
	end
end

local function apply_max_fury_peak()
	ComboState.fury = MAX_FURY

	local lock_seconds = ComboState.config.fury_max_lock_seconds
	if lock_seconds and lock_seconds > 0 then
		ComboState.fury_lock_timer = lock_seconds
	else

		ComboState.fury_lock_timer = 0
		apply_max_fury_fatigue()
	end
end

local function high_fatigue_threshold()
	local threshold = ComboState.config.high_fatigue_threshold_pct

	if not threshold or threshold <= 0 then
		return nil
	end

	return threshold
end

local function high_fatigue_blend()
	local threshold = high_fatigue_threshold()

	if not threshold or ComboState.fatigue <= threshold then
		return 0
	end

	local span = 100 - threshold

	if span <= 0 then
		return 1
	end

	local blend = (ComboState.fatigue - threshold) / span

	if blend <= 0 then
		return 0
	elseif blend >= 1 then
		return 1
	end

	return blend
end

local function fury_gain_mult()
	local config = ComboState.config
	local fatigue_blend = high_fatigue_blend()

	return 1 - fatigue_blend * (1 - config.fury_min_gain_mult)
end

local function grace_duration_mult()
	local config = ComboState.config
	local fatigue_fraction = ComboState.fatigue / 100
	return 1 - fatigue_fraction * (1 - config.grace_min_duration_mult)
end

local function damage_reference()
	local reference = ComboState.config.fury_damage_reference

	if not reference or reference <= 0 then
		reference = 50
	end

	return reference
end

local function fury_from_damage(damage)
	local config = ComboState.config
	local raw_gain = BASE_UNIT * config.fury_damage_mult * (damage / damage_reference()) * fury_gain_mult()
	return math_max(config.fury_min_damage_gain, math_min(raw_gain, config.fury_max_damage_gain))
end

local function fatigue_from_damage(damage)
	local config = ComboState.config
	local raw_gain = BASE_UNIT * config.fatigue_damage_mult * (damage / damage_reference())
	return math_max(config.fatigue_min_damage_gain, math_min(raw_gain, config.fatigue_max_damage_gain))
end

local function passive_fatigue_gain(dt)
	local config = ComboState.config
	local rate = config.fatigue_passive_per_second

	if not rate or rate <= 0 then
		return 0
	end

	local ramp_seconds = config.fatigue_passive_ramp_seconds
	local ramp_mult = 1

	if ramp_seconds and ramp_seconds > 0 then
		ramp_mult = math_min(ComboState.combo_time / ramp_seconds, 1)
	end

	return rate * ramp_mult * dt
end

local function fury_low_drain_mult()
	local threshold = FuryMeterConstants.LOGIC.LOW_FURY_DRAIN_RATE_REDUCTION_THRESHOLD_PCT

	if not threshold or threshold <= 0 or ComboState.fury > threshold then
		return 1
	end

	local rate_pct = FuryMeterConstants.LOGIC.LOW_FURY_DRAIN_RATE_REDUCTION_MAX_PCT
	if rate_pct == nil then
		rate_pct = 25
	end

	if rate_pct < 0 then
		rate_pct = 0
	elseif rate_pct > 100 then
		rate_pct = 100
	end

	local t = ComboState.fury / threshold
	local rate = rate_pct + (100 - rate_pct) * t

	return rate / 100
end

local function fury_fatigue_drain_mult()
	local config = ComboState.config
	local threshold = high_fatigue_threshold()

	if not threshold or ComboState.fatigue <= threshold then
		return 1
	end

	local rate_pct = config.fury_fatigue_drain_rate_pct
	if rate_pct == nil then
		rate_pct = 300
	end

	if rate_pct < 0 then
		rate_pct = 0
	end

	return rate_pct / 100
end

local function apply_grace(damage)
	local config = ComboState.config
	local grace_seconds = (config.grace_duration + damage * config.grace_per_damage) * grace_duration_mult()

	if grace_seconds <= 0 then
		return
	end

	if grace_seconds > config.grace_max then
		grace_seconds = config.grace_max
	end

	if grace_seconds > ComboState.grace_timer then
		ComboState.grace_timer = grace_seconds
	end
end

local function bump_ghost()
	if ComboState.fury > ComboState.ghost then
		ComboState.ghost = ComboState.fury
	end
end

local function update_ghost_trail(dt, ghost_decay)
	if ComboState.ghost <= ComboState.fury then
		ComboState.ghost = ComboState.fury
		return
	end

	if ComboState.ghost_timer > 0 then
		ComboState.ghost_timer = ComboState.ghost_timer - dt
		return
	end

	local follow_step = math_min(ghost_decay * dt, 1)
	ComboState.ghost = ComboState.ghost + (ComboState.fury - ComboState.ghost) * follow_step
	if ComboState.ghost - ComboState.fury < 0.002 then
		ComboState.ghost = ComboState.fury
	end
end

local function add_fury(amount)
	if amount <= 0 then
		return
	end

	if fury_locked() then
		ComboState.fury = MAX_FURY
		local lock_seconds = ComboState.config.fury_max_lock_seconds
		if lock_seconds and lock_seconds > 0 then
			ComboState.fury_lock_timer = lock_seconds
		end
		bump_ghost()
		return
	end

	if not fury_gain_allowed() then
		return
	end

	if not ComboState.active then
		ComboState.combo_time = 0
	end

	local previous_fury = ComboState.fury
	ComboState.active = true
	ComboState.fury = math_min(MAX_FURY, ComboState.fury + amount)
	mark_fury_gain()

	if ComboState.fury >= MAX_FURY and previous_fury < MAX_FURY then
		apply_max_fury_peak()
	end

	bump_ghost()
end

local function add_fatigue(amount)
	if amount <= 0 then
		return
	end

	if not fatigue_gain_allowed() then
		return
	end

	ComboState.fatigue = math_min(100, ComboState.fatigue + amount)
	mark_fatigue_gain()
end

local function apply_milestone_fatigue_relief()
	local config = ComboState.config
	local interval = config.fatigue_milestone_interval
	local kills = ComboState.kills
	local relief = config.fatigue_milestone_reduction

	if not interval or interval <= 0 or not relief or relief <= 0 then
		return
	end

	if kills >= interval and kills % interval == 0 then
		ComboState.fatigue = math_max(0, ComboState.fatigue - relief)
	end
end

function ComboState.apply_fatigue_relief(fatigue_reduction, ramp_seconds)
	if fatigue_reduction and fatigue_reduction > 0 then
		ComboState.fatigue = math_max(0, ComboState.fatigue - fatigue_reduction)
	end

	if ramp_seconds and ramp_seconds > 0 then
		ComboState.combo_time = math_max(0, ComboState.combo_time - ramp_seconds)
	end
end

function ComboState.on_kill(damage)
	local config = ComboState.config
	damage = damage or 0

	if statline_active("dps") then
		Dps:record_damage(damage)
	end

	if statline_active("kills_interval") then
		Kills:record_kill()
	end

	ComboState.kills = ComboState.kills + 1
	ComboState.total_kills = ComboState.total_kills + 1

	if ComboState.kills > ComboState.best_kills then
		ComboState.best_kills = ComboState.kills
	end

	local fury_gain = BASE_UNIT * config.fury_kill_mult * fury_gain_mult()
	fury_gain = fury_gain + fury_from_damage(damage)
	local fatigue_gain = BASE_UNIT * config.fatigue_kill_mult + fatigue_from_damage(damage)

	log_gains("KILL:", fury_gain, fatigue_gain)

	add_fury(fury_gain)
	add_fatigue(fatigue_gain)
	apply_milestone_fatigue_relief()
	apply_grace(damage)
end

function ComboState.on_hit_enemy(damage)
	local config = ComboState.config
	damage = damage or 0

	if damage < FuryMeterConstants.LOGIC.MINIMUM_DAMAGE_FOR_FURY then
		return
	end

	if statline_active("dps") then
		Dps:record_damage(damage)
	end

	local fury_gain, fatigue_gain = fury_from_damage(damage), fatigue_from_damage(damage)

	log_gains("HIT:", fury_gain, fatigue_gain)

	add_fury(fury_gain)
	add_fatigue(fatigue_gain)
	apply_grace(damage)
end

function ComboState.on_damage(damage_fraction)

	if not ComboState.active or damage_fraction <= 0 or fury_locked() or ComboState.is_frozen() then
		return
	end

	if not damage_penalty_allowed() then
		return
	end

	local penalty = damage_fraction * ComboState.config.fury_damage_penalty * 100
	if penalty <= 0 then
		return
	end

	bump_ghost()

	ComboState.fury = math_max(0, ComboState.fury - penalty)
	ComboState.ghost_timer = FuryMeterConstants.PRESENTATION.DECAY_GHOST_HOLD_TIME

	mark_damage_penalty()

	if ComboState.fury <= 0 then
		break_combo()
	end
end

function ComboState.apply_debug_override()
	if not mod.dl.settings.debug_lock_fury_fatigue then
		return false
	end

	local min_kills = ComboState.minimum_combo()
	local fury = math_clamp(mod.dl.settings.debug_fury_pct or 0, 0, MAX_FURY + 1)
	local fatigue = math_clamp(mod.dl.settings.debug_fatigue_pct or 0, 0, 100)

	ComboState.active = true
	ComboState.fury = fury
	ComboState.fatigue = fatigue

	if fury >= MAX_FURY + 1 then
		ComboState.fury_lock_timer = 0
		ComboState.ghost = MAX_FURY
	elseif fury >= MAX_FURY then
		ComboState.fury = MAX_FURY
		ComboState.fury_lock_timer = 60
		ComboState.ghost = MAX_FURY
	else
		ComboState.fury_lock_timer = 0
		ComboState.ghost = fury
	end

	if ComboState.kills < min_kills then
		ComboState.kills = min_kills
	end

	return true
end

function ComboState.update(dt)

	if statline_active("dps") then
		Dps:advance_clock(dt)
		Dps:tick(dt)
	end

	if statline_active("kills_interval") then
		Kills.config.window_seconds = mod.dl.settings.statline_kpm_interval_seconds
		Kills:tick(dt)
	end

	tick_gain_cooldowns(dt)

	if ComboState.apply_debug_override() then
		if ComboState.active then
			ComboState.combo_time = ComboState.combo_time + dt
		end
		return false
	end

	if not ComboState.active then
		return false
	end

	if ComboState.is_frozen() then
		update_ghost_trail(dt, FuryMeterConstants.PRESENTATION.DECAY_GHOST_SPEED)
		return false
	end

	if fury_locked() then
		ComboState.fury_lock_timer = ComboState.fury_lock_timer - dt
		ComboState.fury = MAX_FURY
		ComboState.ghost = ComboState.fury
		ComboState.combo_time = ComboState.combo_time + dt
		ComboState.fatigue = math_min(100, ComboState.fatigue + passive_fatigue_gain(dt))

		if ComboState.fury_lock_timer <= 0 then
			ComboState.fury_lock_timer = 0
			apply_max_fury_fatigue()
		end

		return false
	end

	local config = ComboState.config

	local drain_seconds = config.fury_drain_seconds

	if not drain_seconds or drain_seconds <= 0 then
		drain_seconds = 7.5
	end

	local drain_mult = 1
	if ComboState.grace_timer > 0 then
		ComboState.grace_timer = ComboState.grace_timer - dt
		drain_mult = config.grace_drain_percent / 100
	end

	drain_mult = drain_mult * fury_low_drain_mult()
	drain_mult = drain_mult * fury_fatigue_drain_mult()

	local drain = (100 / drain_seconds) * drain_mult * dt
	ComboState.fury = ComboState.fury - drain

	ComboState.combo_time = ComboState.combo_time + dt
	ComboState.fatigue = math_min(100, ComboState.fatigue + passive_fatigue_gain(dt))

	if ComboState.fury <= 0 then
		break_combo()
		return true
	end

	update_ghost_trail(dt, FuryMeterConstants.PRESENTATION.DECAY_GHOST_SPEED)

	return false
end

function ComboState.at_max_fury()

	if ComboState.fury >= MAX_FURY + 1 then
		return true
	end

	return fury_locked()
end

function ComboState.dps()
	return Dps:value()
end

function ComboState.kills_in_window()
	return Kills:value()
end

mod.combo_state = ComboState

return ComboState
