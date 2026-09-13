local Timer = {}

-- timer_state[unit] = { started=bool, start_time=number, samples={ {t=,pct=}, ... } }
local timer_state = {}

-- Tunables (settings-overridable in Task 5; safe defaults here).
local SAMPLE_WINDOW = 1.5        -- seconds of HP samples used for the rate estimate
local NEAR_COMPLETE_PCT = 85     -- % at/above which status = near_complete
local NEAR_COMPLETE_ETA = 10     -- seconds ETA at/below which status = near_complete
local RATE_EPS = 0.01            -- %/s deadband: |rate| below this = stalled/contested

-- Below this fill, the ritual has demonstrably started: the game drops the daemonhost to 1 HP the
-- moment it triggers, so anything short of full health means the bar is live. Used as a one-way latch
-- rather than a per-tick test, so a ritual that has climbed back up near full is still recognised as
-- running and can still report near-complete.
local RUNNING_BELOW_PCT = 99

local function is_finite_number(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function gameplay_time()
	if not (Managers.time and Managers.time.time) then
		return nil
	end
	local ok, v = pcall(Managers.time.time, Managers.time, "gameplay")
	if ok and v ~= nil then
		return v
	end
	ok, v = pcall(Managers.time.time, Managers.time, "main")
	if ok and v ~= nil then
		return v
	end
	return nil
end

-- Ritual fill = the invulnerable daemonhost's HP climbing 0..1 toward 1. Return 0..100.
--
-- This mapping is only valid ONCE THE RITUAL HAS TRIGGERED. Verified in
-- bt_chaos_mutator_daemonhost_passive_action.lua: _setup_progress_bar runs at trigger time and does
-- add_damage(max_health - 1), slamming the daemonhost to 1 HP, after which _update_progress_bar lerps
-- it back to max as the ritual fills. A daemonhost that has NOT triggered was never damaged and sits
-- at FULL health, which reads as 100 percent filled. See the running latch in Timer.update.
local function ritual_percent(unit)
	if not ScriptUnit.has_extension(unit, "health_system") then
		return nil
	end
	local he = ScriptUnit.extension(unit, "health_system")
	local ok, pct = pcall(he.current_health_percent, he)
	if ok and is_finite_number(pct) then
		return pct * 100
	end
	return nil
end

-- Fresh state for a new ritual. Deliberately does NOT mark it running: the boss encounter starts in
-- the same function that drops the health, so on this tick the fill can still read full, and
-- baselining from that value would poison has_progressed for the rest of the ritual. The health latch
-- in Timer.update decides when the ritual is live.
function Timer.on_encounter_start(unit)
	timer_state[unit] = { start_time = gameplay_time(), samples = {} }
end

function Timer.on_encounter_end(unit)
	timer_state[unit] = nil
end

-- Smoothed fill rate (%/second) over the trailing window; nil if not enough data.
local function fill_rate(samples)
	if #samples < 2 then
		return nil
	end
	local first, last = samples[1], samples[#samples]
	local dt = last.t - first.t
	if dt <= 0 then
		return nil
	end
	return (last.pct - first.pct) / dt
end

-- Returns (eta_seconds|nil, status). status in "filling"|"contested"|"near_complete"|"idle".
function Timer.update(unit)
	local now = gameplay_time()
	local percent = ritual_percent(unit)
	if not now or not percent then
		return nil, "idle"
	end

	local data = timer_state[unit]
	if not data then
		data = { start_time = now, samples = {} }
		timer_state[unit] = data
	end

	-- Idempotent within a tick: marker and warning both call this per unit per frame. Sampling
	-- twice at the same timestamp doubles the health-lookup work and the sample stream, so return
	-- the cached result when we have already sampled at this exact time.
	if data.last_t == now then
		return data.last_eta, data.last_status
	end

	-- Has this ritual actually started? A daemonhost standing untriggered is at FULL health, which the
	-- fill model would otherwise read as 100 percent complete and report as near-complete. Latch on
	-- the first sub-full reading: the game guarantees a drop to 1 HP at trigger time, so seeing
	-- anything below full is proof the bar is live. Once latched it stays latched, so a ritual filling
	-- back up toward full is still recognised and can still report near-complete.
	--
	-- Also covers joining mid-ritual, where the encounter-start event was never seen but the fill is
	-- already part way up.
	if not data.running and percent < RUNNING_BELOW_PCT then
		data.running = true
		-- Baseline from here, not from anything observed before the ritual existed. Sampling the
		-- pre-trigger full-health reading would set first_pct to 100 and leave has_progressed unable
		-- ever to clear first_pct + 0.5, silently disabling the cultist-damage override.
		data.samples = {}
		data.first_pct = nil
		data.max_pct = nil
	end

	if not data.running then
		data.last_t = now
		data.last_eta = nil
		data.last_status = "idle"
		return nil, "idle"
	end

	-- Track the first and highest observed fill so has_progressed can answer "did this ritual
	-- actually advance", independent of the geometric stage prediction. samples is a trailing
	-- window and is not usable for this: it forgets the starting value.
	if data.first_pct == nil then
		data.first_pct = percent
	end
	if data.max_pct == nil or percent > data.max_pct then
		data.max_pct = percent
	end

	local s = data.samples
	s[#s + 1] = { t = now, pct = percent }
	while #s > 1 and (now - s[1].t) > SAMPLE_WINDOW do
		table.remove(s, 1)
	end

	local rate = fill_rate(s)
	local eta = nil
	local status

	if rate and rate > RATE_EPS then
		eta = (100 - percent) / rate
		status = "filling"
	elseif rate then
		-- rate known and at/below the deadband: stalled or pushed back = contested.
		status = "contested"
	else
		-- not enough samples yet (first frame(s)): a fresh ritual is filling; no ETA.
		status = "filling"
	end

	if percent >= NEAR_COMPLETE_PCT or (eta and eta <= NEAR_COMPLETE_ETA) then
		status = "near_complete"
	end

	data.last_t = now
	data.last_eta = eta
	data.last_status = status

	return eta, status
end

-- Ground truth: has this ritual's fill actually advanced since we started watching it?
--
-- The warning's stage is otherwise a prediction from path geometry, and that prediction misses at
-- least one real trigger: damaging any chanting cultist below 95% health sends the ritual straight
-- to full speed with no wire crossing at all (_check_damage in the daemonhost passive action).
-- The 0.5 point margin keeps health jitter from reading as progress.
function Timer.has_progressed(unit)
	local data = timer_state[unit]
	if not data or data.first_pct == nil or data.max_pct == nil then
		return false
	end
	return data.max_pct > data.first_pct + 0.5
end

function Timer.teardown_all()
	timer_state = {}
end

return Timer
