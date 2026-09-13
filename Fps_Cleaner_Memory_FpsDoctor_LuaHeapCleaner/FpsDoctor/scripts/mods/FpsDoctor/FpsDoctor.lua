local mod = get_mod("FpsDoctor")
mod.name = "FpsDoctor"

local Gui = Gui
local World = World
local Managers = Managers
local Vector2 = Vector2
local Vector3 = Vector3
local Color = Color
local collectgarbage = collectgarbage
local tostring = tostring
local rawget = rawget
local pairs = pairs
local pcall = pcall
local string_format = string.format
local math_floor = math.floor
local math_max = math.max
local math_sqrt = math.sqrt

-- Every file-level ALL-CAPS tunable lives in this one table instead of its own
-- local: the chunk sat at 185/200 main-chunk locals, and in v1.6.4 mod.update
-- crossed LuaJIT's other parse limit -- 60 upvalues per function (62 captures
-- made loadstring return nil, so DMF called a nil chunk and the mod never
-- loaded). One shared table costs a single local and a single upvalue.
local K = {}

K.FONT_TYPE = "arial"

K.SAMPLE_MAX = 1000
local samples = {}
local sample_count = 0
local sample_idx = 1

local low_scratch = {}
local low_scratch_n = 0

K.PAUSE_FRAME_S = 0.5

local draw_fail_cooldown = 0
K.DRAW_FAIL_BACKOFF_FRAMES = 120

local stats = {
	fps = 0,
	avg_fps = 0,
	low_fps = 0,
	frame_ms = 0,
	heap_mb = 0,
	heap_rate = 0,
	-- Per-second frame-time extremes, for limiter detection (see K.HW_CAP_*).
	frame_min = 0,
	frame_max = 0,
	-- The last floor established by a MAP LOAD, which is the only floor measured
	-- after a double full collect. Lives here rather than as its own local
	-- because mod.update reads it and the 60-upvalue ceiling is close.
	map_floor = 0,
}

-- The one-second sampling window, in one table rather than four locals: every
-- one of them is captured by mod.update, and the 60-upvalue ceiling per function
-- is what stopped 1.6.4 from loading at all (see the note at the top).
--   sec    seconds accumulated toward the next 1 Hz tick
--   time   wall time and frame count of the current averaging window
--   reset  seconds accumulated toward the auto-reset of diagnostics
local win = { sec = 0, time = 0, frames = 0, reset = 0 }
local last_heap_kb = nil

local peak_heap_mb = 0
local floor_heap_mb = 0
local mission_start_heap_mb = 0
local mission_baseline_pending = false
local mission_hitches = 0
local mission_gc_hitches = 0

local gc_frame_ms = 0
K.GC_HITCH_ATTRIB_MS = 5

local periodic_acc = 0
local emergency_cooldown = 0
local in_gameplay = false

-- Deep clean: set while a loading screen already paid for the full collect, so
-- the mission-start path must not pay for it again on the first gameplay frame.
-- Per-load flags live in load_state below rather than as three more file-level
-- locals: mod.update captures them and the 60-upvalue ceiling is what broke
-- 1.6.4 (see the note at the top of the file).

-- Deferred loading clean. The deep clean and the loading GC boost used to run on
-- the FIRST frame of StateLoading -- which is also the window where the previous
-- world's engine objects die asynchronously underneath Lua (the same transition
-- window ensure_gui documents for guis). GC executed in that window sweeps and
-- finalizes userdata whose native side the engine is concurrently tearing down,
-- and a user crash report puts a loading-screen crash INSIDE the engine's own
-- per-frame stepper (Lua->collect_one_frame_of_garbage) -- exactly the code that
-- pays for whatever GC volume exists there. So the mod now keeps the first
-- QUIET_S seconds of every loading screen GC-quiet (no boost, no deep clean, no
-- mod stepping -- the engine's stock ~1 ms slice is the only collector, i.e.
-- vanilla exposure), and only then boosts and cleans. A load shorter than the
-- window simply falls back to the normal map_start drain.
--   deep_done  a loading screen already paid for the full collect, so the
--              mission-start path must not pay for it again
--   swept      the cache sweeps ran, so the deferred collect skips them
--   boosted    the engine GC boost is currently applied
local load_state = { active = false, t = 0, QUIET_S = 1.5,
	deep_done = false, swept = false, boosted = false }

-- Community reports put Psykhanium heap growth at up to +2500 MB/min (spawned
-- enemies + talent churn with no map transition to flush them), the single worst
-- allocator in the game. Sampled at 1 Hz; drives a shorter periodic interval.
local in_psykhanium = false

-- Set (1 Hz, diagnostics modes only) to the FrameRateManager reason currently
-- throttling the frame rate, nil when uncapped. Lets the overlay say WHY the fps
-- number is pinned at 60 instead of letting the player blame their hardware.
local fps_cap_reason = nil

-- Per-mod allocation profiler state. Declared here (not at the profiler code
-- block) because rebuild_lines reads the top-allocator pair as upvalues.
local profiler_active = false
local profiler_wrapped = {}
local profiler_alloc_kb = {}
local profiler_top_name = nil
local profiler_top_rate = 0

local gc_drain_active = false
local gc_drain_reason = nil
local gc_drain_before_mb = 0
local gc_drain_frames = 0
K.GC_DRAIN_MAX_FRAMES = 1800
K.DRAIN_STEP_KB = 32
K.DRAIN_MAX_STEPS = 24
K.FALLBACK_STEP_KB = 256

-- Escalation tier for drains that are losing the race against allocation. At the
-- default budget a drain processes well under 1 MB of heap per frame; a full cycle
-- over a 1.5 GB heap is gigabytes of mark+sweep work, so without escalation a big
-- drain times out incomplete forever while the heap keeps climbing toward the
-- engine's Lua arena limit (an OOM crash). Bigger debt payments amortize the
-- per-call overhead; the raised budget still runs under the spike gate.
K.ESCALATE_STEP_KB = 128
K.ESCALATE_BUDGET_US_MIN = 3000
K.EMERGENCY_BYPASS_MB = 256
local gc_drain_escalated = false
local gc_drain_chain = 0

-- Duty-cycle brake for the escalation tier (v1.6.5). 1.6.4 shipped the
-- pre-ceiling tier with no throttle whatsoever: it re-armed on +32 MB of growth
-- (PERIODIC_MIN_GROWTH_MB), read no cooldown, and its drains skipped both the
-- frame-spike gate and the headroom backoff at a 3 ms/frame floor. In a long
-- session whose post-cleanup floor has drifted up near the trigger line, that
-- combination is not a safety net any more -- it is a permanent 3 ms/frame tax
-- on every gameplay frame, which is exactly the FPS regression players reported
-- after 1.6.4. The tier stays (it is the only thing standing between a Havoc
-- fight and the synchronous ceiling collect), but now it is rate-limited:
--  * a real growth gate (PRE_CEILING_GROWTH_MB, not the periodic tier's 32 MB),
--  * a cooldown after EVERY escalated drain, complete or timed out (1.6.4's
--    timed-out drain published no floor and therefore restarted instantly),
--  * and a much longer cooldown when a completed cycle reclaimed almost
--    nothing: a heap that a full cycle cannot bring down is LIVE, so grinding
--    the collector over it buys frames-per-second losses and no memory back.
--    That case is what the floor-drift restart advice is for.
-- The escalation ladder, in order, as fractions of the configured ceiling:
--   0.88  paced threshold drain -- normal budget, spike-gated, headroom-scaled
--   0.90  escalate: promote that drain (or start one) with the raised budget
--   0.92  panic: one synchronous full collect, because the alternative is a crash
-- 1.6.4 had the escalation step at 0.85, i.e. BELOW the (clamped) paced tier at
-- 0.80's neighbour -- so the expensive tier was the FIRST responder and the cheap
-- paced drain never got to try. Escalation is a response to the paced drain
-- losing, so it now sits above it.
K.PRE_CEILING_FRAC = 0.90
-- Modest, because the futility check in finish_drain is the real answer to
-- "there is nothing here worth collecting" -- it MEASURES that instead of
-- guessing from the distance to the floor. A large guard here would just let the
-- heap sail into the 0.92 panic collect in exactly the sessions that need this.
K.PRE_CEILING_GROWTH_MB = 64
K.PRE_CEILING_COOLDOWN_S = 45
K.PRE_CEILING_FUTILE_FRAC = 0.10
K.PRE_CEILING_FUTILE_COOLDOWN_S = 300
-- Second, rate-independent route to the same verdict. The growth-rate test below
-- only recognises futility when allocation is quiet, which leaves the middle
-- ground -- a large live heap with ordinary churn -- re-arming the tier every
-- cooldown forever. Counting consecutive escalated drains that reclaimed almost
-- nothing catches that too: a session where allocation genuinely outruns the
-- collector still gets its first attempts (they demonstrably hold the heap
-- lower), and one where nothing is coming back stops after a few tries.
K.PRE_CEILING_FUTILE_STREAK = 3
-- ...but the streak route must not reach the storm case. Under Havoc- or
-- Psykhanium-level allocation an escalated drain legitimately shows little NET
-- reclaim -- it freed plenty and the fight refilled it while the cycle ran -- so
-- counting those as failures would switch the safety net off under exactly the
-- load it exists for. Above this growth rate only the drains themselves decide,
-- and the 45 s cooldown remains the only limit.
K.PRE_CEILING_FUTILE_MAX_RATE = 300.0
local tier = { cooldown = 0, futile = 0, misses = 0, warned = false, mode = nil }
-- Escalated drains are no longer exempt from per-frame politeness, only held to
-- a laxer standard than paced ones: they skip work on a frame that is already
-- 2.5x over budget (instead of 1.5x, or never), and the headroom backoff may
-- shrink them to half their budget but no further -- so they keep winning the
-- race against the allocator without landing 3-4 ms on top of the worst frames.
K.ESCALATE_SPIKE_MULT = 2.5
K.ESCALATE_MIN_SCALE = 0.5

-- Hard ceiling: the engine's Lua heap is a bounded arena (about 1 GB stock;
-- --lua-heap-mb-size raises it). Near the limit a synchronous full collect -- one
-- visible hitch -- is strictly better than the crash that follows.
K.CEILING_COLLECT_FRAC = 0.92
K.CEILING_COOLDOWN_S = 120
-- Where the smooth (paced) threshold drain is allowed to sit relative to the
-- ceiling. It MUST land below the 0.92 panic line -- with the stock presets
-- (threshold 1024, ceiling 1024) the raw threshold sat above it, so the smooth
-- drain could never fire before the synchronous collect it exists to prevent.
-- 1.6.4 clamped to 0.80, which pulled the paced drain down to 819 MB and the
-- adaptive tier to 614 MB: much earlier, much more often, on frames that were
-- fine. 0.88 keeps a real gap to the panic line without moving the whole
-- schedule 200 MB down the heap.
K.CEILING_THRESHOLD_FRAC = 0.88
local ceiling_cooldown = 0

-- Memory-speed scaling of GC step GRANULARITY (v1.6.5).
--
-- Every budgeted loop in this mod checks its clock BETWEEN collectgarbage
-- ("step", n) calls, never inside one -- so the cost of a single step is the
-- mod's own overshoot past its own budget. How much wall time one step costs is
-- a property of the machine's memory subsystem, not of the setting: the mark
-- phase is pointer chasing (latency bound) and the sweep is a linear walk
-- (bandwidth bound), so the same 128 KB step that costs ~0.3 ms on a DDR5 rig
-- can cost over a millisecond on DDR3 -- and that difference lands entirely on
-- the frames of the weakest machines, which is where the stutter reports come
-- from. Scaling the STEP SIZE by memory speed keeps the overshoot roughly
-- constant across hardware; the time budgets (what the player actually agreed
-- to spend per frame) are deliberately NOT touched.
--
-- Honesty about the presets: RAM class is a weak predictor. CAS latency in
-- nanoseconds barely moved across DDR3/DDR4/DDR5 (~10 ns at each generation's
-- common kits), so the gain comes from bandwidth and bank/sub-channel
-- parallelism, not from the headline MT/s. Hence sqrt() on the frequency ratio
-- rather than a linear one, a small per-generation factor, and a clamp -- and
-- hence "auto", which ignores the whole model and measures the real per-step
-- cost of the machine it is running on.
K.MEM_TYPE_FACTOR = { ddr3 = 0.85, ddr4 = 1.0, ddr5 = 1.15 }
K.MEM_REF_MTS = 3200
-- One slice should overshoot the frame's GC budget by at most this fraction of
-- it, so the target follows whatever budget the player chose instead of being a
-- fixed millisecond figure. (A fixed 0.5 ms target was tried first and was
-- useless: measured slices cost 0.08-0.21 ms on a desktop, so 0.5 ms permitted
-- every machine to take BIGGER slices -- the opposite of protecting the slow
-- ones.) Clamped so a tiny budget still gets usable slices and a huge one does
-- not turn a single slice into the whole frame.
K.MEM_STEP_BUDGET_FRAC = 0.20
K.MEM_STEP_TARGET_US_MIN = 120
K.MEM_STEP_TARGET_US_MAX = 400
-- Asymmetric on purpose. Downwards there is real protection to give a slow
-- machine (smaller slices, less overshoot per slice); upwards the only prize is
-- fewer C-call round-trips, so a fast machine is allowed a modest bonus and no
-- more -- an unbounded multiplier would just hand the overshoot back.
K.MEM_SCALE_MIN = 0.35
K.MEM_SCALE_MAX = 1.5
K.MEM_STEP_KB_MIN = 8
K.MEM_STEP_KB_MAX = 512
-- One step is enough to time a step. This was 4, which silently excluded every
-- machine the feature exists for: at a 1500 us budget a slow machine exhausts
-- the budget after two 64 KB slices, so a 4-step loop never happened there and
-- no sample was ever taken. The atomic-phase risk that motivated the higher
-- floor is handled by MEM_SAMPLE_SPIKE_FRAC instead, which is the more precise
-- guard anyway.
K.MEM_SAMPLE_MIN_STEPS = 1
-- A loop that happened to contain the end-of-mark atomic phase (which runs to
-- completion inside one step and can be tens of milliseconds) measured that
-- phase, not the memory subsystem. Once an estimate exists, reject samples far
-- above it. Downward moves are always accepted: they can only make slices
-- smaller, which is the safe direction to be wrong in.
K.MEM_SAMPLE_SPIKE_FRAC = 3.0
K.MEM_SAMPLE_TRUST_AFTER = 4
K.MEM_SAMPLE_MAX_US_PER_KB = 100.0
K.MEM_APPLY_EVERY = 8

-- Hardware advisor (see the long note above hardware_advice). It runs once per
-- session, a while into gameplay, so it judges by measurements rather than by
-- the first frame's zeros.
K.HW_DELAY_S = 45
-- Slider sets per class of machine, for use INSIDE whatever mode the player
-- picked -- the cheap fix, to try before any suggestion to change modes.
--
-- These are not guesses. Each was grid-searched in the simulator (budget x
-- stepmul over a three-mission session with a drifting floor, per hardware
-- class) and picked on two axes: average frame rate AND the share of frames the
-- mod spends over 1.5 ms, which is what a player feels as stutter. The
-- consistent result was that the aggressive preset's 1500 us budget is too big
-- everywhere: 800 beat it on both axes at 60-144 fps, and at 30-40 fps dropping
-- to 400 cut heavy frames from 35-37% to 7-8% while also gaining frame rate.
-- Larger slices (higher stepmul) pay off only on the slowest machines, where a
-- few big slices beat many small ones.
-- Keyed by mode, because the answer differs by mode: 'pacer' was grid-searched
-- the same way and its own 500/100 preset came out best or joint-best in every
-- class, so there is nothing to offer there and nothing is claimed. Only
-- aggressive ships values that the measurements disagree with.
K.HW_TUNE = {
	aggressive = {
		fast = { gc_budget_us = 800, gc_stepmul = 300 },
		mid  = { gc_budget_us = 800, gc_stepmul = 300 },
		weak = { gc_budget_us = 400, gc_stepmul = 300 },
		slow = { gc_budget_us = 400, gc_stepmul = 500 },
	},
}
-- Boundaries placed BETWEEN the frame rates people actually target (30, 60,
-- 120, 144, 165), not on them. With the line at 55 a machine aiming for 60 sat
-- on it, and ordinary frame-time variation flipped its class -- which would have
-- meant contradictory advice from one session to the next.
K.HW_CLASS_FPS = { fast = 100, mid = 50, weak = 32 }
-- Measured microseconds per KB of collector progress above which a machine is
-- treated as one class slower than its frame rate suggests: memory this slow
-- makes every slice expensive regardless of how many frames the CPU can push.
K.HW_SLOW_MEM_US_PER_KB = 3.0
-- Frame-rate limiter detection, and why it changes the answer completely.
--
-- With a limiter the frame time the mod sees is the LIMITER's, not the renderer's
-- -- a frame that drew in 3 ms and one that drew in 6 ms both arrive as 6.17 ms
-- at a 162 cap. So the mod cannot see how much slack a frame has, and the
-- arithmetic of its own cost inverts:
--   * while there is slack, GC time is absorbed by the limiter's wait and costs
--     exactly nothing (measured: 0.00% of frames pushed past a 162 cap at any
--     budget from 400 to 4000 us, with 4.0 ms of render in a 6.17 ms frame);
--   * once the renderer is close to the cap, what matters is how many frames get
--     touched AT ALL, because even a 200 us slice tips a frame that is 0.17 ms
--     from the limit. There, SMALLER slices are worse: they spread the same
--     cycle over more frames. Measured at 6.0 ms of render in a 6.17 ms frame:
--     400 us pushed 0.65% of frames past the cap, while 1500-4000 us pushed
--     0.10-0.11%.
-- Uncapped machines want the opposite (smaller slices, see K.HW_TUNE), so the
-- advisor must know which of the two a player is on. A limiter is recognisable
-- without any new API: it pins frame time to one value, so a second whose
-- frames all land within a hair of each other is a second under a limiter.
K.HW_CAP_SPREAD_FRAC = 0.12
K.HW_CAP_SECONDS = 3
-- Below this fraction of the configured limit, a settled floor means the tiers
-- can never fire and the stepping modes are paying for nothing.
K.HW_IDLE_FLOOR_FRAC = 0.5
-- Diagnostic log interval. Comparing two setups by feel is what makes questions
-- like "is the mod costing me frames" unanswerable; this writes the numbers to
-- the game log so two runs can be compared instead of remembered.
K.DIAG_LOG_S = 10
K.HW_FLOOR_TIGHT_FRAC = 0.80
K.HW_WEAK_FPS = 45
K.VRAM_TIGHT_GB = 4
K.VRAM_PRESSURE_FRAC = 0.90
local hw = { t = 0, done = false, capped = false, stable = 0, last_mean = 0, cap_ms = 0,
	-- diagnostic log accumulators (see K.DIAG_LOG_S)
	log_t = 0, log_frames = 0, log_gc_frames = 0, log_gc_ms = 0, log_hitches = 0,
	-- Heap at the start of the interval, and the worst frames within it: a hitch
	-- is only diagnosable if the line says how bad it was AND how much of it was
	-- the mod's own cleanup. Without the second number every hitch in the log is
	-- an accusation with no defendant.
	log_heap0 = 0, log_max_ms = 0, log_max_gc_ms = 0 }
local mem = { scale = 1.0, us_per_kb = 0, samples = 0, measured = false, logged = 0 }

K.PACER_STEP_KB = 16
K.PACER_MAX_STEPS = 8
K.AGGR_STEP_KB = 64
K.AGGR_MAX_STEPS = 16
K.AGGR_HEADROOM_MB = 48
K.PACER_BUDGET_IDLE_MULT = 3
K.PACER_SPIKE_MULT = 1.5
K.PACER_HEADROOM_MB = 24
local pacer_resume_mb = 0
local emergency_floor_mb = 0

-- Minimum gap the cleanup trigger keeps above the last measured floor, and the
-- fraction of the floor it scales with. See the comment at the use site for why
-- a flat 256 MB made the trigger unreachable on ordinary sessions.
K.THRESHOLD_FLOOR_GAP_MIN_MB = 96
K.THRESHOLD_FLOOR_GAP_FRAC = 0.35

K.SOFT_THRESHOLD_FRAC = 0.75
-- The adaptive tier exists for genuinely fast growth. At 8 MB/min it was a
-- hair-trigger: ordinary mission churn clears that in any fight, so the soft
-- tier fired on essentially every mission once the heap passed its line and the
-- "adaptive" drain became a permanent fixture rather than a response.
K.ADAPTIVE_RATE_MB_MIN = 20.0
K.EMERGENCY_COOLDOWN_S = 60
K.EMERGENCY_REARM_MB   = 64
K.PERIODIC_MIN_GROWTH_MB = 32
K.LEAK_WATCH_MB = 120
K.LEAK_LIKELY_MB = 300

-- Menu/view attribution. Building DMF's options list allocates heavily (a fresh
-- UIWidget per setting, no per-type caching), and the game's own full-screen
-- views are just as bad: opening the inventory clones the entire gear list,
-- cosmetics shops render icon atlases, and those 50-200 ms frames are NOT
-- gameplay. Counting them as mission stutters and letting them poison the 1% low
-- made the panel blame the game for what a menu did. Since 1.5 the bucket covers
-- ANY active full-screen view (has_active_view), with the DMF options view name
-- kept as a fallback probe for older builds. We only ever *attribute* here --
-- nothing about the cleanup schedule changes.
K.MENU_VIEW = "dmf_options_view"
local menu_open = false
local menu_base_mb = 0
-- Growth rate measured just before a view opened, in MB/min: the baseline the
-- menu's own charge is measured against (see accrue_menu_charge).
local menu_base_rate = 0
local menu_charge_mb = 0
local menu_hitches = 0
local menu_open_hitches = 0
local menu_open_mb = 0

-- Runaway allocation tier. rate_rgb saturates at 5 MB/min, so a normal +200 and a
-- pathological +2500 render as the same red. Gated on consecutive RAW samples, not
-- on stats.heap_rate: the EMA moves only 30% of one sample, so a single second
-- holding ~44 MB would already cross an 800 MB/min EMA test.
K.RUNAWAY_MB_MIN = 800
K.RUNAWAY_SAMPLES = 3
local runaway_streak = 0
local runaway_active = false

-- Session floor drift. floor_heap_mb is what remains right after a cleanup, so a
-- floor that keeps rising across level loads is the memory a cleanup did not bring
-- back down -- the one signal that maps to "restart the game". Telescoping
-- (latest - base) rather than a running sum, so a rejected sample cannot corrupt it.
local session_base_mb = 0
local session_last_floor_mb = 0
local session_loads = 0
local session_step_streak = 0
local session_advice_mult = 0

local _clock = nil

-- B5: os.clock in this VM (LuaJIT -> C clock()/CLOCKS_PER_SEC) ticks in whole
-- milliseconds on Windows, so the microsecond budgets below were quantized to
-- "0 or 1 ms" per read. The engine exports its own QPC pair, used by the game
-- itself for intra-frame time-slicing (gameplay_init_time_slice.lua,
-- settings_utils.lua): query_performance_counter() -> token,
-- time_since_query(token) -> float milliseconds with sub-ms precision. The
-- token is created and consumed within one frame and never cached across
-- frames (the v1.3.1 lesson about handle lifetimes).
-- IMPORTANT: a Lua chunk may declare at most 200 local variables, and this file
-- runs close to that ceiling. Exceeding it makes the WHOLE file fail to compile,
-- which DMF reports only as "attempt to call local 'func' (a nil value)" -- no
-- line number, no hint. So related state below shares one table instead of
-- taking a local slot each, and new state should follow that pattern.
local hires = { state = nil, start = nil, since = nil } -- state: nil untested, false unusable, true ok

-- flag_mb: value of the --lua-heap-mb-size launch option, 0 when not seen. It
-- sizes the engine's native Lua arena; whether launch options reach
-- Application.argv() is build-dependent, so this is detection, never a promise.
-- env_logged / sticker_checked: one-shot latches for the startup environment
-- log and the trait sticker book repair.
local once = { flag_mb = 0, env_logged = false, sticker_checked = false }

-- Engine-side memory sample for the optional overlay line (Memory.usage is the
-- same read-only API the game calls on every view open). Refreshed every 5 s.
local procmem = { mb = 0, vram = 0, budget = 0, tick = 0 }

-- Set by tick_menu_state on a heavy menu-close edge; consumed in the 1 Hz block
-- (where request_collect is in scope) to optionally start a paced drain.
local menu_drain_pending = 0

local _gui = nil
local _gui_world = nil
local _font_path = nil

local cfg = {}
K.CFG_KEYS = {
	"show_overlay", "show_fps", "show_low", "show_frame_ms", "show_heap",
	"show_mission", "show_hitch", "show_gc_mode", "anchor", "pos_x", "pos_y",
	"overlay_scale", "opacity_text", "opacity_bg", "hitch_ms",
	"gc_mode", "gc_pause", "gc_stepmul", "gc_budget_us", "smooth_collect",
	"periodic_minutes", "threshold_mb", "auto_reset", "auto_reset_minutes",
	"silent", "show_session", "restart_advice_mb",
	"heap_ceiling_mb", "deep_clean", "engine_gc", "uncap_menus",
	"fast_loading", "mod_profiler",
	"fix_hud_leaks", "menu_drain", "show_proc_mem", "dmf_release", "mute_telemetry",
	"mem_type", "mem_mts", "vram_gb", "hw_profile", "diag_log",
}

local line_text = {}
local line_r, line_g, line_b = {}, {}, {}
local line_count = 0
local panel_text_w = 0
local overlay_dirty = true
local rebuild_acc = 0
K.REBUILD_INTERVAL = 0.25
local built_font_px = 0

-- Overlay geometry/colour cache: recomputed only on the throttled rebuild and
-- reused every frame. One table rather than eight locals (see the 200-local
-- note above); every field is read inside draw_overlay_inner only.
local cached = { line_h = 0, pad = 0, a_text = 0, a_bg = 0, x = 0, top_y = 0, panel_w = 0, panel_h = 0 }

-- Scale implied by the player's declared RAM class. Returns nil for "auto",
-- which is handled by measurement instead (see mem_note_steps).
local function mem_scale_from_preset()
	local factor = K.MEM_TYPE_FACTOR[cfg.mem_type or "auto"]
	if not factor then return nil end
	local mts = cfg.mem_mts or K.MEM_REF_MTS
	if mts < 800 then mts = 800 end
	local scale = math_sqrt(mts / K.MEM_REF_MTS) * factor
	if scale < K.MEM_SCALE_MIN then scale = K.MEM_SCALE_MIN end
	if scale > K.MEM_SCALE_MAX then scale = K.MEM_SCALE_MAX end
	return scale
end

local function mem_refresh_scale()
	local preset = mem_scale_from_preset()
	if preset then
		mem.scale = preset
		mem.measured = false
		mem.samples = 0
		mem.us_per_kb = 0
		mem.logged = 0
	elseif not mem.measured then
		-- Back on auto with nothing measured yet: the stock step sizes are the
		-- reference point, so start there and let the samples move it.
		mem.scale = 1.0
	end
end

local function mem_step_kb(base_kb)
	local scale = mem.scale
	if scale == 1.0 then return base_kb end
	local kb = math_floor(base_kb * scale + 0.5)
	if kb < K.MEM_STEP_KB_MIN then kb = K.MEM_STEP_KB_MIN end
	if kb > K.MEM_STEP_KB_MAX then kb = K.MEM_STEP_KB_MAX end
	return kb
end

-- Steps are capped as well as budgeted. Shrinking the step size for a slow
-- machine without raising the cap would hand the decision to the cap instead of
-- the clock -- the machine we just protected from overshoot would also collect
-- less per frame. Scaling the cap the other way keeps the TIME BUDGET the
-- binding constraint on every machine.
local function mem_max_steps(base_steps)
	local scale = mem.scale
	if scale == 1.0 then return base_steps end
	local n = math_floor(base_steps / scale + 0.5)
	if n < 1 then n = 1 end
	if n > base_steps * 4 then n = base_steps * 4 end
	return n
end

local function mem_apply_measured()
	local stepmul = (cfg.gc_stepmul or 200) / 100.0
	if mem.us_per_kb <= 0 or stepmul <= 0 then return end
	local target_us = (cfg.gc_budget_us or 1000) * K.MEM_STEP_BUDGET_FRAC
	if target_us < K.MEM_STEP_TARGET_US_MIN then target_us = K.MEM_STEP_TARGET_US_MIN end
	if target_us > K.MEM_STEP_TARGET_US_MAX then target_us = K.MEM_STEP_TARGET_US_MAX end
	-- How many KB of collector progress one step may request before it costs
	-- more than the target overshoot, expressed as a multiple of the base step.
	local target_kb = target_us / mem.us_per_kb
	local base_units = K.AGGR_STEP_KB * stepmul
	if base_units <= 0 then return end
	local scale = target_kb / base_units
	if scale < K.MEM_SCALE_MIN then scale = K.MEM_SCALE_MIN end
	if scale > K.MEM_SCALE_MAX then scale = K.MEM_SCALE_MAX end
	mem.scale = mem.measured and (mem.scale * 0.7 + scale * 0.3) or scale
	mem.measured = true
	-- Log the first verdict and any material move afterwards, never every tick:
	-- this is the one number that explains why two machines with identical
	-- settings do different amounts of work per frame.
	if mem.logged <= 0 or mem.scale > mem.logged * 1.25 or mem.scale < mem.logged * 0.8 then
		mem.logged = mem.scale
		mod:info("Memory speed measured: %.2f us per KB of GC progress -> step size x%.2f (%d KB slices at the aggressive preset)",
			mem.us_per_kb, mem.scale, math_floor(K.AGGR_STEP_KB * mem.scale + 0.5))
	end
end

-- One sample per budgeted step loop: microseconds per KB of requested collector
-- progress, which is the machine's GC throughput as this mod experiences it.
-- Loops of fewer than MEM_SAMPLE_MIN_STEPS are dropped, and so are absurd
-- values: a loop that happened to contain the end-of-mark atomic phase (which
-- runs to completion inside a single step, unbudgetable) measured that phase,
-- not the memory subsystem.
local function mem_note_steps(step_kb, steps, elapsed_ms)
	if steps < K.MEM_SAMPLE_MIN_STEPS or elapsed_ms <= 0 then return end
	if (cfg.mem_type or "auto") ~= "auto" then return end
	local units = step_kb * ((cfg.gc_stepmul or 200) / 100.0)
	if units <= 0 then return end
	local us_per_kb = (elapsed_ms * 1000.0) / (steps * units)
	if us_per_kb <= 0 or us_per_kb > K.MEM_SAMPLE_MAX_US_PER_KB then return end
	if mem.samples >= K.MEM_SAMPLE_TRUST_AFTER and mem.us_per_kb > 0
			and us_per_kb > mem.us_per_kb * K.MEM_SAMPLE_SPIKE_FRAC then
		return
	end
	mem.us_per_kb = (mem.samples > 0) and (mem.us_per_kb * 0.85 + us_per_kb * 0.15) or us_per_kb
	mem.samples = mem.samples + 1
	if mem.samples % K.MEM_APPLY_EVERY == 0 then mem_apply_measured() end
end

local function refresh_cfg()
	for i = 1, #K.CFG_KEYS do
		local k = K.CFG_KEYS[i]
		cfg[k] = mod:get(k)
	end
	mem_refresh_scale()
	overlay_dirty = true
end

-- Pacer/aggressive philosophy: with a HIGH pause the VM's own allocation-triggered
-- auto-cycles (which run inside game allocation spikes, unpaced and unbudgeted)
-- essentially never start, so the LUA-SIDE collection happens in the mod's
-- per-frame budgeted steps. NOTE the engine's native GC stepper keeps running
-- its own 0.5-1 ms/frame slice regardless -- setpause only gates the VM's
-- allocation-triggered auto-cycles, not explicit native LUA_GCSTEP calls --
-- so the heap numbers on the panel reflect the mod's work PLUS the engine's.
-- A low pause is only right for balanced, where the VM's
-- auto-GC *is* the intended collector. Stepmul in the stepping modes scales the
-- work done per requested KB of debt (fewer C-call round-trips), which is pure
-- efficiency once auto-cycles are suppressed -- so aggressive runs a high value.
K.MODE_PRESETS = {
	balanced   = { gc_pause = 150, gc_stepmul = 200, gc_budget_us = 1000, periodic_minutes = 10, threshold_mb = 1024 },
	pacer      = { gc_pause = 400, gc_stepmul = 100, gc_budget_us = 500,  periodic_minutes = 10, threshold_mb = 1536 },
	-- threshold_mb 768, not 1024. With the old flat floor gap the difference was
	-- academic -- neither value was reachable on a normal session -- but with the
	-- gap made proportional this is now the number that decides when memory stops
	-- climbing. 768 MB is roughly twice a typical settled heap, so a quiet session
	-- still never triggers it, while a session that has drifted into three-figure
	-- growth gets cleaned instead of being left to drift toward the ceiling.
	-- The extras live HERE, in the preset, not as changed defaults in _data.lua:
	-- a preset key cannot leak into balanced, pacer, off or map_only, and
	-- balanced's behaviour is contractually fixed by a parity test. Each of the
	-- four earned its place in real session logs, and each is free on a weak
	-- machine -- none of them adds work to a gameplay frame:
	--   menu_drain     88 firings, 497 MB reclaimed, and zero hitches in any
	--                  window where a paced drain ran. Acts at a menu close.
	--   show_session   the mod measured the floor rising 137 -> 449 MB while every
	--                  mission verdict said "stable", and the panel never showed
	--                  it. Formats numbers that already exist.
	--   diag_log       the line that reported "worst frame 154.2 ms, worst cleanup
	--                  0.00 ms" -- i.e. proved a 154 ms freeze was not this mod.
	--                  Five integer adds per frame, one log line per 10 s.
	--   show_proc_mem  on a weak PC the real bottleneck is usually VRAM, and this
	--                  is the only line that shows it. Reads Memory.usage once
	--                  every 5 seconds inside the existing 1 Hz block.
	-- Deliberately NOT here: uncap_menus and fast_loading (both make a weak GPU
	-- render MORE frames -- of menus and loading screens respectively),
	-- mod_profiler (wraps every other mod's update), dmf_release (measured
	-- 341.6 -> 341.5 MB, i.e. nothing), mute_telemetry (six orders of magnitude
	-- off, and it makes the game's post_batch run every frame after five
	-- minutes), auto_reset (would erase the very numbers a diagnosis needs).
	aggressive = { gc_pause = 700, gc_stepmul = 300, gc_budget_us = 1500, periodic_minutes = 10, threshold_mb = 768,
	               deep_clean = true, engine_gc = true,
	               menu_drain = true, show_session = true, diag_log = true, show_proc_mem = true },
}

-- The extra diagnostics (menu attribution, runaway tier) are confined to the modes
-- that already opt into active management. "balanced" is the default and is held
-- unchanged in BOTH senses -- cleanup schedule and what the panel shows -- so a
-- player who never touched a setting sees exactly the v1.3.1 panel.
local function diag_extras()
	local mode = cfg.gc_mode or "balanced"
	return mode == "pacer" or mode == "aggressive"
end

-- How far above a fresh floor the heap may grow before per-frame stepping resumes.
-- Aggressive tolerates a wider band: its slices are larger, so waking less often
-- costs nothing while idle frames stay completely GC-free.
local function resume_headroom_mb()
	return (cfg.gc_mode == "aggressive") and K.AGGR_HEADROOM_MB or K.PACER_HEADROOM_MB
end

-- Returns true/false when the probe succeeded, or nil for "could not tell".
-- Managers.ui only exists inside StateGame. has_active_view reads the view
-- handler's top-view pointer (any full-screen view: inventory, shop, mission
-- board, DMF options); view_active is the narrower legacy fallback, one hash
-- lookup safe for any name string. A nil result must leave the flag alone --
-- treating "unknown" as "closed" would fabricate a close edge and file a bogus
-- report.
local function probe_menu_open()
	local ui = Managers.ui
	if not ui then return nil end
	if ui.has_active_view then
		local ok, active = pcall(ui.has_active_view, ui)
		if ok then return active and true or false end
	end
	if not ui.view_active then return nil end
	local ok, active = pcall(ui.view_active, ui, K.MENU_VIEW)
	if not ok then return nil end
	return active and true or false
end

local function resolve_clock()
	if _clock == nil then
		local lua_os = rawget(_G, "Mods") and Mods.lua and Mods.lua.os
		_clock = (lua_os and lua_os.clock) or (rawget(_G, "os") and os.clock) or false
	end
	return _clock
end

-- One-time probe of the engine's sub-ms timer (see the B5 note at the top).
-- The first sample is validated (a number, near zero right after the query) so
-- a build that repurposes these names degrades to the os.clock path instead of
-- feeding garbage into the budget loops. Never retried after failing.
local function hires_ok()
	if hires.state == nil then
		hires.state = false
		local app = rawget(_G, "Application")
		local start = app and app.query_performance_counter
		local since = app and app.time_since_query
		if type(start) == "function" and type(since) == "function" then
			local ok, t0 = pcall(start)
			if ok and t0 ~= nil then
				local ok2, ms = pcall(since, t0)
				if ok2 and type(ms) == "number" and ms >= 0 and ms < 100 then
					hires.start = start
					hires.since = since
					hires.state = true
					mod:info("High-res timer active (probe sample %.4f ms); GC budgets are now sub-ms accurate", ms)
				end
			end
		end
		if not hires.state then
			mod:info("High-res timer unavailable; GC budgets fall back to os.clock (~1 ms quantum)")
		end
	end
	return hires.state
end

-- game_mode_name is the game's own idiom for detecting the Psykhanium (see
-- pocketable.lua): "shooting_range" for the range, "training_grounds" for the
-- havoc/basic training variant. pcall because Managers.state.game_mode only
-- exists once gameplay init has run.
local function probe_psykhanium()
	local ok, name = pcall(function()
		local gm = Managers.state and Managers.state.game_mode
		return gm and gm:game_mode_name()
	end)
	if not ok then return false end
	return name == "shooting_range" or name == "training_grounds"
end

-- True while any full-screen view is open. Views own the caches the deep clean
-- releases, so cache sweeps outside a loading screen are gated on this.
local function view_open()
	local ui = Managers.ui
	if ui and ui.has_active_view then
		local ok, active = pcall(ui.has_active_view, ui)
		if ok then return active and true or false end
	end
	return false
end

-- Engine-side memory sample for the optional overlay line. Memory.usage("B")
-- is the exact call the game makes on every view open (base_view.lua), so the
-- cost at a 5 s cadence is negligible; vram_usage/vram_budget mirror the
-- telemetry code including its IS_WINDOWS gate. Read-only: nothing here can
-- change game state, and a build without the API just leaves the line hidden.
local function sample_process_memory()
	local mem = rawget(_G, "Memory")
	if mem and mem.usage then
		local ok, usage = pcall(mem.usage, "B")
		local used = ok and type(usage) == "table" and usage.used_memory
		if type(used) == "number" and used > 0 then
			procmem.mb = used / 1048576.0
		end
	end
	if rawget(_G, "IS_WINDOWS") and mem and mem.vram_usage and mem.vram_budget then
		local ok1, vu = pcall(mem.vram_usage)
		local ok2, vb = pcall(mem.vram_budget)
		if ok1 and ok2 and type(vu) == "number" and type(vb) == "number" and vb > 0 then
			procmem.vram = vu
			procmem.budget = vb
		end
	end
end

local function level_world()
	local world_manager = Managers.world
	if world_manager and world_manager:has_world("level_world") then
		return world_manager:world("level_world")
	end
	return nil
end

local function ensure_gui()
	-- A screen gui is OWNED by the world it was created in: when that world is
	-- despawned (mission/hub exit, or the brief transition window into a loading
	-- state) the engine frees the gui, and any Lua handle we kept becomes a
	-- dangling pointer. Blindly trusting a cached handle is what crashed the game
	-- (Gui.rect dereferencing freed memory -> access violation) and, when the
	-- engine's shallow type-check caught the dead userdata first, produced the
	-- "bad argument #1 to 'rect' (Gui expected, got userdata)" Lua error.
	--
	-- So re-fetch the live level world every call and validate the cache against
	-- it: no world -> drop the cache and skip drawing; a *different* world (level
	-- swapped underneath us) -> recreate; the same live world -> reuse. This only
	-- allocates a new gui once per world, not per frame.
	local world = level_world()
	if not world then
		_gui = nil
		_gui_world = nil
		_font_path = nil
		return nil
	end
	if _gui and _gui_world == world then
		return _gui
	end
	-- World changed or first use. The previous world (if any) is already gone,
	-- so its gui went with it -- just overwrite the stale handle, never destroy it.
	_gui = World.create_screen_gui(world, "immediate")
	_gui_world = world
	_font_path = nil
	return _gui
end

local function ensure_font_path()
	if _font_path then return _font_path end
	local font_data = Managers.font and Managers.font:data_by_type(K.FONT_TYPE)
	if font_data then _font_path = font_data.path end
	return _font_path
end

local function release_gui()
	_gui = nil
	_gui_world = nil
	_font_path = nil
end

-- Top-K selection instead of a full copy+sort: only the K worst frames matter for
-- the 99th percentile (K = 11 at 1000 samples), so one pass with a tiny sorted
-- insertion buffer replaces ~10k comparisons and a 1000-element copy each second.
-- topk is kept ASCENDING; topk[1] is the K-th worst dt = the percentile sample.
local function compute_low_fps()
	local n = sample_count
	if n < 10 then return 0 end
	local idx = math_floor(n * 0.99)
	if idx < 1 then idx = 1 end
	if idx > n then idx = n end
	local k = n - idx + 1
	local topk = low_scratch
	local count = 0
	for i = 1, n do
		local dt = samples[i]
		if count < k then
			local j = count
			while j > 0 and topk[j] > dt do
				topk[j + 1] = topk[j]
				j = j - 1
			end
			topk[j + 1] = dt
			count = count + 1
		elseif dt > topk[1] then
			local j = 1
			while j < k and topk[j + 1] < dt do
				topk[j] = topk[j + 1]
				j = j + 1
			end
			topk[j] = dt
		end
	end
	for i = count + 1, low_scratch_n do topk[i] = nil end
	low_scratch_n = count
	local dt99 = topk[1]
	if dt99 and dt99 > 0 then return 1.0 / dt99 end
	return 0
end

local function reset_diagnostics()
	local heap_kb = collectgarbage("count")
	sample_count = 0
	sample_idx = 1
	mission_hitches = 0
	mission_gc_hitches = 0
	menu_hitches = 0
	menu_charge_mb = 0
	menu_open_hitches = 0
	menu_open_mb = 0
	menu_base_mb = heap_kb / 1024.0
	runaway_streak = 0
	runaway_active = false
	peak_heap_mb = heap_kb / 1024.0
	mission_start_heap_mb = heap_kb / 1024.0
	mission_baseline_pending = false
	stats.low_fps = 0
	stats.heap_rate = 0
	last_heap_kb = heap_kb
	win.time = 0
	win.frames = 0
	win.sec = 0
	win.reset = 0
	overlay_dirty = true
end

local function rate_rgb(rate)
	if rate >= 5.0 then return 255, 90, 90 end
	if rate >= 1.5 then return 255, 215, 90 end
	return 150, 230, 150
end

local function delta_rgb(mb)
	if mb >= K.LEAK_LIKELY_MB then return 255, 90, 90 end
	if mb >= K.LEAK_WATCH_MB then return 255, 215, 90 end
	return 150, 230, 150
end

local function mission_verdict(net)
	if net >= K.LEAK_LIKELY_MB then return "likely leak" end
	if net >= K.LEAK_WATCH_MB then return "watch (growing)" end
	return "stable"
end

local function text_extent_width(gui, text, font, font_size)
	local ok, mn, mx = pcall(Gui.slug_text_extents, gui, text, font, font_size)
	if ok and mn and mx then
		return mx[1] - mn[1]
	end
	return #text * font_size * 0.55
end

local function push_line(s, r, g, b)
	local n = line_count + 1
	line_count = n
	line_text[n] = s
	line_r[n] = r
	line_g[n] = g
	line_b[n] = b
end

local function rebuild_lines(gui, font, font_px)
	line_count = 0

	if cfg.show_fps then
		push_line(string_format("FPS %d  (avg %d)  non-fg", math_floor(stats.fps + 0.5), math_floor(stats.avg_fps + 0.5)), 235, 235, 235)
		-- Only rendered while the game is actively throttling, so it costs no
		-- panel space in normal play. "menu" is friendlier than "view_handler".
		if diag_extras() and fps_cap_reason then
			local label = fps_cap_reason == "view_handler" and "menu" or fps_cap_reason
			push_line(string_format("fps capped by game  (%s)", label), 255, 215, 90)
		end
	end

	if cfg.show_low then
		local low_warn = stats.low_fps > 0 and stats.avg_fps > 0 and stats.low_fps < stats.avg_fps * 0.7
		if low_warn then
			push_line(string_format("1%% low  %d fps", math_floor(stats.low_fps + 0.5)), 255, 215, 90)
		else
			push_line(string_format("1%% low  %d fps", math_floor(stats.low_fps + 0.5)), 175, 175, 175)
		end
	end

	if cfg.show_frame_ms then
		push_line(string_format("frame  %.1f ms", stats.frame_ms), 175, 175, 175)
	end

	if cfg.show_heap then
		local rate = stats.heap_rate
		if runaway_active then
			-- Magenta alone is not colour-blind-safe against the existing red tier,
			-- so the severity is also spelled out in words.
			push_line(string_format("Lua heap  %.0f MB  (+%.0f MB/min)  RUNAWAY", stats.heap_mb, rate), 255, 70, 255)
		else
			local r, g, b = rate_rgb(rate)
			push_line(string_format("Lua heap  %.0f MB  (%s%.1f MB/min)", stats.heap_mb, rate >= 0 and "+" or "", rate), r, g, b)
		end
	end

	if cfg.show_heap and cfg.mod_profiler and diag_extras() and profiler_top_name and profiler_top_rate >= 0.5 then
		push_line(string_format("top alloc  %s  +%.1f MB/min", tostring(profiler_top_name), profiler_top_rate), 200, 200, 255)
	end

	-- Engine-side memory: what the engine itself accounts for the whole game,
	-- plus VRAM against the driver budget. This is the number the Lua heap can
	-- never see -- the classic "script memory fine, FPS melting anyway" case is
	-- VRAM pressure, and it turns the line yellow at 90 percent of the budget.
	if cfg.show_proc_mem and procmem.mb > 0 then
		local s
		if procmem.budget > 0 then
			s = string_format("game mem %.1f GB   VRAM %.1f/%.1f GB", procmem.mb / 1024.0, procmem.vram / 1024.0, procmem.budget / 1024.0)
		else
			s = string_format("game mem %.1f GB", procmem.mb / 1024.0)
		end
		if procmem.budget > 0 and procmem.vram >= procmem.budget * 0.9 then
			push_line(s, 255, 215, 90)
		else
			push_line(s, 175, 175, 175)
		end
	end

	if cfg.show_mission then
		local delta = (mission_start_heap_mb > 0) and (stats.heap_mb - mission_start_heap_mb) or 0
		-- Discount menu churn so the delta describes the mission, not the option list.
		-- menu_charge_mb is defined as UNCOLLECTED menu garbage and is zeroed wherever
		-- a floor is re-established, so this can never drive the delta negative.
		if diag_extras() and menu_charge_mb > 0 then
			delta = delta - menu_charge_mb
		end
		local r, g, b = delta_rgb(delta)
		if floor_heap_mb > 0 then
			push_line(string_format("peak %.0f  floor %.0f  d-mission %s%.0f MB", peak_heap_mb, floor_heap_mb, delta >= 0 and "+" or "", delta), r, g, b)
		else
			push_line(string_format("peak %.0f MB   d-mission %s%.0f MB", peak_heap_mb, delta >= 0 and "+" or "", delta), r, g, b)
		end
	end

	if cfg.show_session then
		if session_loads >= 1 and session_base_mb > 0 then
			local drift = session_last_floor_mb - session_base_mb
			local r, g, b = delta_rgb(drift)
			push_line(string_format("floor drift  %s%.0f MB over %d level loads", drift >= 0 and "+" or "", drift, session_loads), r, g, b)
		elseif (cfg.gc_mode or "balanced") == "off" then
			-- A floor can only be read right after a cleanup, and "off" is
			-- contractually "never clean" -- so say so rather than showing nothing.
			push_line("floor drift  needs a cleanup mode", 175, 175, 175)
		else
			push_line("floor drift  measuring...", 175, 175, 175)
		end
	end

	if cfg.show_hitch then
		local hitch_s
		local show_menu = diag_extras() and menu_hitches > 0
		if mission_gc_hitches > 0 and show_menu then
			hitch_s = string_format("hitch %d (%d gc, %d menu)  (>%d ms)", mission_hitches, mission_gc_hitches, menu_hitches, cfg.hitch_ms or 50)
		elseif show_menu then
			hitch_s = string_format("hitch %d (%d menu)  (>%d ms)", mission_hitches, menu_hitches, cfg.hitch_ms or 50)
		elseif mission_gc_hitches > 0 then
			hitch_s = string_format("hitch %d (%d gc)  (>%d ms)", mission_hitches, mission_gc_hitches, cfg.hitch_ms or 50)
		else
			hitch_s = string_format("hitch %d  (>%d ms)", mission_hitches, cfg.hitch_ms or 50)
		end
		if mission_hitches > 0 then
			push_line(hitch_s, 255, 215, 90)
		else
			push_line(hitch_s, 175, 175, 175)
		end
	end

	if cfg.show_gc_mode then
		-- The memory-speed multiplier only ever moves step granularity, but a
		-- player who set the RAM preset by hand deserves to see that it took (and
		-- on "auto", what the machine actually measured). Diagnostics modes only,
		-- so the balanced panel is unchanged.
		if diag_extras() and mem.scale ~= 1.0 then
			push_line(string_format("GC mode: %s  (mem x%.2f %s)", tostring(cfg.gc_mode or "balanced"),
				mem.scale, mem.measured and "measured" or "preset"), 175, 175, 175)
		else
			push_line("GC mode: " .. tostring(cfg.gc_mode or "balanced"), 175, 175, 175)
		end
	end

	local maxw = 0
	for i = 1, line_count do
		local w = text_extent_width(gui, line_text[i], font, font_px)
		if w > maxw then maxw = w end
	end
	panel_text_w = maxw
end

local function draw_overlay_inner(dt)
	local gui = ensure_gui()
	if not gui then return end

	local font = ensure_font_path()
	if not font then return end

	local r = RESOLUTION_LOOKUP
	local scale = (r and r.scale) or 1.0
	local sw = (r and r.width) or 1920
	local sh = (r and r.height) or 1080

	local uscale = (cfg.overlay_scale or 100) / 100.0
	local s = scale * uscale
	local font_px = math_max(8, math_floor(9 * s + 0.5))

	rebuild_acc = rebuild_acc + dt
	if overlay_dirty or rebuild_acc >= K.REBUILD_INTERVAL or font_px ~= built_font_px then
		rebuild_lines(gui, font, font_px)
		built_font_px = font_px
		rebuild_acc = 0
		overlay_dirty = false

		-- Everything below depends only on cfg.*, RESOLUTION_LOOKUP and the
		-- rebuilt line metrics, so it is cached here and reused on the frames
		-- between rebuilds. refresh_cfg() sets overlay_dirty on any setting
		-- change, so a raw resolution change lags by at most REBUILD_INTERVAL.
		local line_h = math_floor(13 * s + 0.5)
		local pad = math_floor(4 * s + 0.5)
		local n = line_count
		local a_text = math_floor(255 * ((cfg.opacity_text or 100) / 100.0) + 0.5)
		local a_bg = math_floor(255 * ((cfg.opacity_bg or 60) / 100.0) + 0.5)
		local margin_x = math_floor((cfg.pos_x or 24) * scale + 0.5)
		local margin_y = math_floor((cfg.pos_y or 24) * scale + 0.5)
		local panel_w = panel_text_w + pad * 2
		local anchor = cfg.anchor or "top_left"
		local to_right = anchor == "top_right" or anchor == "bottom_right"
		local to_bottom = anchor == "bottom_left" or anchor == "bottom_right"

		cached.x = to_right and (sw - panel_w - margin_x) or margin_x
		if to_bottom then
			cached.top_y = sh - margin_y - n * line_h
		else
			cached.top_y = margin_y
		end
		cached.line_h = line_h
		cached.pad = pad
		cached.a_text = a_text
		cached.a_bg = a_bg
		cached.panel_w = panel_w
		cached.panel_h = n * line_h + pad * 2
	end

	local n = line_count
	if n == 0 then return end

	local pad = cached.pad
	local x = cached.x
	local top_y = cached.top_y
	local line_h = cached.line_h

	Gui.rect(
		gui,
		Vector3(x - pad, top_y - pad, 899),
		Vector2(cached.panel_w, cached.panel_h),
		Color(cached.a_bg, 12, 12, 12)
	)

	local a_text = cached.a_text
	for i = 1, n do
		local ly = top_y + line_h * (i - 1)
		Gui.slug_text(gui, line_text[i], font, font_px, Vector3(x, ly, 900), nil, Color(a_text, line_r[i], line_g[i], line_b[i]))
	end
end

local function draw_overlay(dt)
	if draw_fail_cooldown > 0 then
		draw_fail_cooldown = draw_fail_cooldown - 1
		return
	end
	local ok, err = pcall(draw_overlay_inner, dt)
	if not ok then
		release_gui()
		draw_fail_cooldown = K.DRAW_FAIL_BACKOFF_FRAMES
		mod:error("overlay draw failed, backing off %d frames: %s", K.DRAW_FAIL_BACKOFF_FRAMES, tostring(err))
	end
end

-- `single_pass` drops the second, floor-settling collect. The double collect
-- exists for an accurate floor (the second pass catches what the first pass's
-- finalizers and resurrected objects left behind), but in LuaJIT each pass is a
-- synchronous full-heap mark+atomic+sweep -- and a fullgc that catches the
-- incremental collector mid-mark first abandons that progress and sweeps the
-- whole heap before even starting its own cycle. Callers that fire MID-GAMEPLAY
-- as an emergency therefore trade floor accuracy for half the freeze.
local function do_full_collect(reason, single_pass)
	local clock = resolve_clock()
	local t0 = clock and clock()
	local before = collectgarbage("count") / 1024.0
	collectgarbage("collect")
	if not single_pass then
		collectgarbage("collect")
	end
	if t0 then gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0 end
	local after = collectgarbage("count") / 1024.0
	last_heap_kb = collectgarbage("count")
	stats.heap_mb = after
	floor_heap_mb = after
	emergency_floor_mb = after
	pacer_resume_mb = after + resume_headroom_mb()
	menu_charge_mb = 0
	menu_base_mb = after
	if not cfg.silent then
		mod:echo(string_format("[FpsDoctor] GC (%s): %.0f -> %.0f MB", reason, before, after))
	end
	mod:info("GC collect (%s): %.1f -> %.1f MB", reason, before, after)
end

local function reset_session_drift()
	session_base_mb = 0
	session_last_floor_mb = 0
	session_loads = 0
	session_step_streak = 0
	session_advice_mult = 0
end

-- Feeds one floor sample into the session chain. `trustworthy` is false when the
-- cleanup that produced `mb` did not finish its cycle, in which case the sample is
-- dropped: a partially collected heap is not a floor, and admitting it would show
-- drift that a completed cleanup would have taken back.
local function note_session_floor(mb, trustworthy)
	if not trustworthy or mb <= 0 then return end

	if session_base_mb <= 0 then
		session_base_mb = mb
		session_last_floor_mb = mb
		session_loads = 0
		session_step_streak = 0
		session_advice_mult = 0
		return
	end

	session_last_floor_mb = mb
	session_loads = session_loads + 1

	local drift = mb - session_base_mb
	local step = cfg.restart_advice_mb or 512
	if step <= 0 then return end

	if drift >= step then
		session_step_streak = session_step_streak + 1
	else
		session_step_streak = 0
		return
	end

	-- Fire on LEVEL as well as slope. Without the level gate the base is whatever
	-- the boot hub happened to sit at, before first-touch view modules are require()d
	-- and become permanently resident -- so a session settling from 120 to 640 MB
	-- would nag about growth that is simply the game finishing loading itself.
	local high_enough = session_last_floor_mb >= (cfg.threshold_mb or 1024) * K.SOFT_THRESHOLD_FRAC
	if not high_enough or session_step_streak < 2 or session_loads < 2 then return end

	local mult = math_floor(drift / step)
	if mult <= session_advice_mult then return end
	session_advice_mult = mult

	-- Report the observation, not a diagnosis. Under the default smooth cleanup the
	-- floor comes from a single incremental cycle while the mod treats a double full
	-- collect as authoritative, so "unreclaimable" is more than we can prove.
	if not cfg.silent then
		mod:echo(string_format("[FpsDoctor] Memory floor has risen %s%.0f MB over %d level loads and is now %.0f MB. Cleanup is not bringing it back down. If FPS has degraded, restarting the game is the only thing that resets this.",
			drift >= 0 and "+" or "", drift, session_loads, session_last_floor_mb))
	end
	mod:info("Session floor drift: %+.1f MB over %d level loads (%.1f -> %.1f)", drift, session_loads, session_base_mb, session_last_floor_mb)
end

local prev_map_floor_mb = 0
local function note_map_baseline(mb, trustworthy)
	if prev_map_floor_mb > 0 then
		local drift = mb - prev_map_floor_mb
		if not cfg.silent then
			mod:echo(string_format("[FpsDoctor] Floor drift since last map: %s%.0f MB", drift >= 0 and "+" or "", drift))
		end
		mod:info("Map floor drift: %+.1f MB (%.1f -> %.1f)", drift, prev_map_floor_mb, mb)
	end
	prev_map_floor_mb = mb
	stats.map_floor = mb
	note_session_floor(mb, trustworthy)
end

-- Driven from the existing 1 Hz sampler, so it adds no per-frame work. Accrual
-- re-baselines every tick, which makes it idempotent: menu_charge_mb only ever
-- represents menu growth that no cleanup has reclaimed yet.
-- Hoisted rather than a closure inside tick_menu_state: this runs inside the mod's
-- own heap sampler, and allocating there would perturb the rate being measured.
-- `elapsed_s` is how long this sample covers. The baseline subtraction is the
-- point: this used to attribute ALL heap growth during an open view to the view,
-- and in the player's logs that produced "+846 MB" for a single menu visit --
-- because another installed mod was allocating 53 MB/min the whole time the menu
-- sat open. Charging one component for the whole session's allocation is not
-- attribution, it is a coincidence of timing. What the menu is answerable for is
-- growth ABOVE what the session was already doing before it opened.
local function accrue_menu_charge(live_mb, elapsed_s)
	if live_mb > menu_base_mb then
		local grew = live_mb - menu_base_mb
		if menu_base_rate > 0 and elapsed_s and elapsed_s > 0 then
			local baseline = menu_base_rate * (elapsed_s / 60.0)
			grew = grew - baseline
			if grew < 0 then grew = 0 end
		end
		menu_charge_mb = menu_charge_mb + grew
		menu_open_mb = menu_open_mb + grew
	end
	menu_base_mb = live_mb
end

-- Experimental (dmf_release): frees the widget build the DMF options view
-- retains by design. The view's chunk is re-executed on every open (the engine
-- require()s the view path and DMF redirects that into a non-caching
-- io_dofile), so the PREVIOUS execution's module-locals -- _widgets_by_name
-- (the full widget map of the last build: every setting of every mod) and the
-- last-selected-category pair -- stay reachable as upvalues of the class
-- methods stored in the global CLASSES table, and the GC cannot take them.
-- Writing nil into those upvalue cells after the view has CLOSED releases
-- roughly one full options build (order of a few MB with many mods installed).
-- Why this is safe: every DMF reader of these locals is nil-guarded, the next
-- open re-executes the chunk creating FRESH locals and closures (the cleared
-- cells are never read again), only plain Lua table/nil writes are involved
-- (no engine handles -- the v1.3.1 lesson does not apply), and every lookup is
-- strictly name-based, so any DMF refactor degrades this into a silent no-op.
-- These upvalue names are unique to dmf_options_view.lua across the entire
-- game source and DMF (verified), so scanning all class methods cannot touch
-- anything else.
K.DMF_SCRUB_UPVALUES = {
	_widgets_by_name = true,
	_last_selected_category_entry = true,
	_last_selected_category_widget = true,
}

local function scrub_dmf_options_retention()
	local dbg = rawget(_G, "debug")
	if not dbg or type(dbg.getupvalue) ~= "function" or type(dbg.setupvalue) ~= "function" then return end
	local classes = rawget(_G, "CLASSES") or rawget(_G, "CLASS")
	local view = classes and classes.DMFOptionsView
	if not view then return end
	-- Never touch a live view: only proceed when the options view is closed.
	local ui = Managers.ui
	if ui and ui.view_active then
		local ok, active = pcall(ui.view_active, ui, K.MENU_VIEW)
		if not ok or active then return end
	end
	local cleared = 0
	for _, fn in pairs(view) do
		if type(fn) == "function" then
			local i = 1
			while true do
				local ok, name, value = pcall(dbg.getupvalue, fn, i)
				if not ok or name == nil then break end
				if K.DMF_SCRUB_UPVALUES[name] and value ~= nil then
					if pcall(dbg.setupvalue, fn, i, nil) then
						cleared = cleared + 1
					end
				end
				i = i + 1
			end
		end
	end
	if cleared > 0 then
		mod:info("DMF options retention released (%d upvalue cells cleared)", cleared)
	end
end

local function tick_menu_state(live_mb, one_sec_elapsed)
	local open = probe_menu_open()
	if open == nil then return end

	if open then
		if not menu_open then
			menu_open = true
			menu_base_mb = live_mb
			menu_open_mb = 0
			menu_open_hitches = 0
			-- What the session was already growing at, before the view opened.
			menu_base_rate = stats.heap_rate > 0 and stats.heap_rate or 0
		else
			accrue_menu_charge(live_mb, one_sec_elapsed)
		end
	elseif menu_open then
		accrue_menu_charge(live_mb, one_sec_elapsed)
		menu_open = false
		if menu_open_mb >= 1.0 or menu_open_hitches > 0 then
			-- The bucket now covers EVERY full-screen view, and ordinary inventory
			-- browsing allocates a few MB each visit -- echoing that would spam the
			-- chat all session. Speak up only for genuinely heavy visits; the log
			-- keeps the full record either way.
			if not cfg.silent and (menu_open_mb >= 16.0 or menu_open_hitches >= 3) then
				mod:echo(string_format("[FpsDoctor] Menus: +%.0f MB and %d stutters while a menu was open -- that is UI churn (option lists, inventory clones, icon rendering), not the mission.", menu_open_mb, menu_open_hitches))
			end
			mod:info("Menu/view closed: +%.1f MB, %d hitches", menu_open_mb, menu_open_hitches)
		end
		-- Release DMF's retained widget build first, then let the close-edge
		-- drain (consumed in the 1 Hz block) actually collect it: refs die
		-- before the sweep instead of surviving until the next full cycle.
		if cfg.dmf_release then
			pcall(scrub_dmf_options_retention)
		end
		-- Hand the accrued growth to the drain trigger; captured BEFORE the
		-- reset below. Consumed where request_collect is in scope.
		menu_drain_pending = menu_open_mb
		menu_open_mb = 0
		menu_open_hitches = 0
	end
end

local function begin_drain(reason)
	gc_drain_active = true
	gc_drain_reason = reason
	gc_drain_before_mb = collectgarbage("count") / 1024.0
	gc_drain_frames = 0
	gc_drain_escalated = false
	gc_drain_chain = 0
end

-- Graduated backoff for the paced cleanup: returns a scale in (0, 1] that
-- shrinks the per-frame GC work as the current frame gets heavier, so the mod
-- naturally does LESS when the player has less headroom. 1.0 when the frame is
-- at or under the expected frame time (identical to the old full-budget path);
-- ramps to ~0 as it approaches the hard spike gate (PACER_SPIKE_MULT), which
-- still skips the work entirely. Only meaningful in-gameplay.
-- What one frame is ALLOWED to take. Normally that is the reciprocal of the
-- measured frame rate -- but under a limiter that measure is self-referential:
-- if the mod's own work settles the achieved rate at 120, the EMA follows it
-- down, 8.3 ms becomes "expected", and the backoff that exists to notice heavy
-- frames sees nothing wrong. The latched cap period is immune to that, because
-- it is the fastest pinned frame time the session ever showed.
local function expected_frame_ms()
	if hw.capped and hw.cap_ms > 0 then return hw.cap_ms end
	if stats.fps <= 0 then return 0 end
	return 1000.0 / stats.fps
end

local function headroom_scale()
	if not in_gameplay then return 1.0 end
	local expected = expected_frame_ms()
	if expected <= 0 then return 1.0 end
	local ratio = stats.frame_ms / expected
	if ratio <= 1.0 then return 1.0 end
	local t = (ratio - 1.0) / (K.PACER_SPIKE_MULT - 1.0)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return 1.0 - t
end

local function finish_drain(completed)
	gc_drain_active = false
	local is_map_start = gc_drain_reason == "map_start"
	local after = collectgarbage("count") / 1024.0
	last_heap_kb = collectgarbage("count")
	stats.heap_mb = after
	-- A cycle that completed almost immediately, or reclaimed almost nothing, was
	-- likely an auto-cycle already in flight when the drain began: its mark phase
	-- predates the request, so garbage created since then survived and `after`
	-- would overstate the floor. Chain exactly one more full cycle and only then
	-- publish -- mirroring why do_full_collect collects twice. Aggressive only:
	-- balanced's map_start path stays byte-for-byte as before. NOT in-mission:
	-- the engine's own per-frame stepper keeps a cycle in flight essentially
	-- always, so in combat the low-reclaim arm fired on most drains and each
	-- chained cycle ended in one more un-budgetable atomic pause mid-fight --
	-- there, a slightly overstated floor is the cheaper error by far.
	if completed and (cfg.gc_mode or "balanced") == "aggressive" and gc_drain_chain == 0
			and not in_gameplay
			and (gc_drain_frames < 30 or (gc_drain_before_mb - after) < gc_drain_before_mb * 0.1) then
		local reason, before, esc = gc_drain_reason, gc_drain_before_mb, gc_drain_escalated
		begin_drain(reason)
		gc_drain_before_mb = before
		gc_drain_chain = 1
		gc_drain_escalated = esc
		return
	end
	-- Only trust `after` as a real floor when the GC cycle actually finished.
	-- map_start must always establish a floor/baseline (this is what balanced
	-- relies on), so it counts as authoritative regardless — keeping balanced's
	-- map-start path byte-for-byte identical to before.
	if completed or is_map_start then
		floor_heap_mb = after
		emergency_floor_mb = after
		pacer_resume_mb = after + resume_headroom_mb()
		menu_charge_mb = 0
		menu_base_mb = after
	end
	if is_map_start and mission_baseline_pending then
		mission_start_heap_mb = after
		mission_baseline_pending = false
		-- Only a drain that actually finished its cycle produced a real floor. A
		-- map_start drain that exhausted GC_DRAIN_MAX_FRAMES still publishes above
		-- (balanced depends on that), but it must not enter the session chain.
		note_map_baseline(after, completed and true or false)
	end
	if completed or is_map_start then
		if not cfg.silent then
			mod:echo(string_format("[FpsDoctor] GC (%s): %.0f -> %.0f MB", gc_drain_reason, gc_drain_before_mb, after))
		end
		mod:info("GC drain (%s): %.1f -> %.1f MB", gc_drain_reason, gc_drain_before_mb, after)
	else
		if not cfg.silent then
			mod:echo(string_format("[FpsDoctor] GC (%s): incomplete, ~%.0f MB (will retry)", gc_drain_reason, after))
		end
		mod:info("GC drain (%s): incomplete after %d frames, heap ~%.1f MB", gc_drain_reason, gc_drain_frames, after)
	end

	-- Rate-limit the escalation tier (see the K.PRE_CEILING_* note). This runs
	-- for EVERY escalated drain, completed or timed out: a timed-out drain
	-- publishes no floor, so in 1.6.4 its trigger condition was still true on the
	-- very next frame and the tier restarted immediately, forever.
	if gc_drain_escalated then
		local reclaimed = gc_drain_before_mb - after
		-- A completed cycle that gave back almost nothing has two very different
		-- causes, and only one of them is a reason to stop:
		--   * the heap is LIVE -- there was nothing to reclaim. More collection
		--     cannot help; only a restart can, and saying so is the floor-drift
		--     line's job. Back off hard rather than grinding every frame for
		--     nothing.
		--   * the ALLOCATOR IS WINNING -- the cycle did free a lot, but a fight
		--     (or the Psykhanium) refilled the heap while it ran, so before-vs-
		--     after understates it. That is the case the escalation tier exists
		--     for, and backing off there would be exactly wrong.
		-- The measured growth rate separates them: it is near zero in the first
		-- case and enormous in the second.
		local unproductive = completed and reclaimed < gc_drain_before_mb * K.PRE_CEILING_FUTILE_FRAC
		if unproductive then
			tier.misses = tier.misses + 1
		elseif completed then
			tier.misses = 0
		end
		if unproductive and (stats.heap_rate < K.ADAPTIVE_RATE_MB_MIN
				or (tier.misses >= K.PRE_CEILING_FUTILE_STREAK
					and stats.heap_rate < K.PRE_CEILING_FUTILE_MAX_RATE)) then
			tier.futile = K.PRE_CEILING_FUTILE_COOLDOWN_S
			local misses = tier.misses
			tier.misses = 0
			mod:info("Escalated drain (%s) reclaimed only %.1f MB of %.1f MB at %.1f MB/min growth (unproductive attempt %d) -- backing the escalation tier off for %d s",
				tostring(gc_drain_reason), reclaimed, gc_drain_before_mb, stats.heap_rate,
				misses, K.PRE_CEILING_FUTILE_COOLDOWN_S)
			if not cfg.silent and not tier.warned then
				tier.warned = true
				mod:echo(string_format("[FpsDoctor] Script memory is %.0f MB and a full cleanup reclaimed only %.0f MB of it -- this memory is in use, not garbage. Further cleaning would cost frame rate and give nothing back, so it is being paused. Restarting the game is what resets this.",
					after, reclaimed))
			end
		end
		tier.cooldown = K.PRE_CEILING_COOLDOWN_S
	end
	gc_drain_reason = nil
end

local function tick_drain()
	if not gc_drain_active then return end

	-- Escalated drains are held to a LAXER spike gate, not exempted from it.
	-- They exist because the heap is outrunning the paced work, and heavy fights
	-- are precisely when every frame reads as a "spike" -- gating them at the
	-- paced 1.5x threshold stalls the drain until the ceiling collect fires, a
	-- far worse frame than 3 ms of GC. The mark window matters too: the longer a
	-- cycle is stretched under heavy mutation, the more of the hot working set
	-- the write barriers push onto the GC's gray-again list, and the bigger the
	-- un-budgetable atomic step at the end of the mark phase (it runs to
	-- completion inside a single collectgarbage("step") call; the budget check
	-- only runs between steps). Finishing escalated cycles FAST therefore also
	-- shrinks the very hitches being fought. But 1.6.4's total exemption put
	-- 3-4 ms on top of frames that were ALREADY 3x over budget, which is where
	-- the micro-freeze reports came from -- so a frame that far gone is still
	-- left alone (ESCALATE_SPIKE_MULT).
	if in_gameplay then
		local expected = expected_frame_ms()
		local mult = gc_drain_escalated and K.ESCALATE_SPIKE_MULT or K.PACER_SPIKE_MULT
		if expected > 0 and stats.frame_ms > expected * mult then
			return
		end
	end

	-- Count only frames that actually do GC work toward the max-frames cap, so
	-- spike-gated (skipped) frames do not exhaust the budget prematurely.
	gc_drain_frames = gc_drain_frames + 1

	-- The map_start drain (the only drain balanced ever runs) is deliberately
	-- left on the original full-budget, no-backoff, os.clock path so balanced is
	-- byte-for-byte unchanged.
	--
	-- ...but ONLY while it is a plain map_start drain. A map_start drain can be
	-- promoted to escalated by the pre-ceiling tier, and escalation is reachable
	-- in pacer and aggressive only -- never in balanced, which returns from
	-- manage_gc long before that tier. So an ESCALATED map_start drain is not a
	-- balanced-mode drain and does not need the exemptions that exist to protect
	-- balanced. It used to get the worst of both paths: 128 KB steps (four times
	-- the normal size) budgeted against os.clock's 1 ms quantum, with no headroom
	-- backoff and stock step sizes. Now it is treated as what it is -- an
	-- escalated drain -- and gets the sub-ms timer, memory-scaled slices and the
	-- headroom floor like every other one.
	local is_map_start = gc_drain_reason == "map_start"
	local legacy_map_start = is_map_start and not gc_drain_escalated

	local finished
	local use_hires = not legacy_map_start and hires_ok()
	local clock = not use_hires and resolve_clock() or nil
	if use_hires or clock then
		local budget_us = cfg.gc_budget_us or 1000
		local max_steps = K.DRAIN_MAX_STEPS
		local step_kb = K.DRAIN_STEP_KB
		if gc_drain_escalated then
			step_kb = K.ESCALATE_STEP_KB
			if budget_us < K.ESCALATE_BUDGET_US_MIN then budget_us = K.ESCALATE_BUDGET_US_MIN end
		end
		-- Step granularity follows the machine's memory speed; a plain map_start
		-- drain keeps the stock sizes so balanced stays byte-for-byte as it was.
		if not legacy_map_start then
			max_steps = mem_max_steps(max_steps)
			step_kb = mem_step_kb(step_kb)
		end
		if not in_gameplay then
			budget_us = budget_us * K.PACER_BUDGET_IDLE_MULT
		elseif not legacy_map_start then
			-- Escalated drains get a FLOOR under the headroom backoff rather than
			-- an exemption from it: shrinking their budget to nothing under load
			-- is how a drain ends up losing to the allocator, but 1.6.4's flat
			-- full budget meant the heaviest frames paid the most GC.
			local scale = headroom_scale()
			if gc_drain_escalated and scale < K.ESCALATE_MIN_SCALE then
				scale = K.ESCALATE_MIN_SCALE
			end
			budget_us = budget_us * scale
			max_steps = math_max(1, math_floor(max_steps * scale + 0.5))
		end
		if use_hires then
			local budget_ms = budget_us / 1000.0
			local t0 = hires.start()
			local steps = 0
			repeat
				finished = collectgarbage("step", step_kb)
				steps = steps + 1
			until finished or steps >= max_steps or hires.since(t0) >= budget_ms
			local spent = hires.since(t0)
			gc_frame_ms = gc_frame_ms + spent
			if not legacy_map_start then mem_note_steps(step_kb, steps, spent) end
		else
			local budget = budget_us / 1000000.0
			local t0 = clock()
			local steps = 0
			repeat
				finished = collectgarbage("step", step_kb)
				steps = steps + 1
			until finished or steps >= max_steps or (clock() - t0) >= budget
			-- os.clock only resolves whole milliseconds here (see the B5 note), so
			-- this path feeds the frame counter but never the memory-speed sample.
			gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0
		end
	else
		finished = collectgarbage("step", K.FALLBACK_STEP_KB)
	end

	-- An escalated drain is fighting a heap that outgrew the trigger by a wide
	-- margin; cutting it off at the normal frame cap would just retry the same
	-- oversized job forever. It gets four times the runway instead.
	local max_frames = gc_drain_escalated and K.GC_DRAIN_MAX_FRAMES * 4 or K.GC_DRAIN_MAX_FRAMES
	if finished or gc_drain_frames >= max_frames then
		finish_drain(finished)
	end
end

local function pacer_cycle_done()
	local cur_kb = collectgarbage("count")
	local cur_mb = cur_kb / 1024.0
	stats.heap_mb = cur_mb
	floor_heap_mb = cur_mb
	emergency_floor_mb = cur_mb
	last_heap_kb = cur_kb
	pacer_resume_mb = cur_mb + resume_headroom_mb()
	menu_charge_mb = 0
	menu_base_mb = cur_mb
end

-- One budgeted slice of incremental GC per frame. Shared by 'pacer' and
-- 'aggressive': the modes differ only in slice size (step KB / step cap) and the
-- resume headroom above the floor. With a high gc_pause the VM's own auto-cycles
-- essentially never start, so this slice is where the Lua-side collection
-- happens -- under the mod's clock, on frames that can afford it. (The engine's
-- native stepper still runs its own 0.5-1 ms/frame slice in parallel; see the
-- MODE_PRESETS note.)
local function tick_incremental(step_kb, max_steps_base)
	if gc_drain_active then return end
	local expected = expected_frame_ms()
	if in_gameplay and expected > 0 and stats.frame_ms > expected * K.PACER_SPIKE_MULT then
		return
	end
	-- Live heap read: the resume gate reacts immediately instead of waiting up
	-- to ~1s for the display's heap sample to refresh.
	local live_mb = collectgarbage("count") / 1024.0
	if pacer_resume_mb > 0 and live_mb < pacer_resume_mb then return end

	local budget_us = cfg.gc_budget_us or 1000
	if not in_gameplay then
		budget_us = budget_us * K.PACER_BUDGET_IDLE_MULT
	end

	-- Graduated backoff: do less as the frame gets heavier (1.0 when the frame
	-- is at/under expected, so this matches the old behaviour when there is
	-- headroom). Never below one step, so a heavy map is not starved of cleanup
	-- and the threshold_mb backstop stays authoritative.
	local scale = headroom_scale()
	local max_steps = math_max(1, math_floor(mem_max_steps(max_steps_base) * scale + 0.5))
	budget_us = budget_us * scale
	step_kb = mem_step_kb(step_kb)

	-- Sub-ms budget when the engine timer is present (B5); os.clock otherwise.
	-- Only pacer/aggressive ever reach this function, so balanced is untouched.
	local use_hires = hires_ok()
	local clock = not use_hires and resolve_clock() or nil
	if not use_hires and not clock then
		if collectgarbage("step", step_kb) then
			pacer_cycle_done()
		end
		return
	end

	local steps = 0
	local finished
	if use_hires then
		local budget_ms = budget_us / 1000.0
		local t0 = hires.start()
		repeat
			finished = collectgarbage("step", step_kb)
			steps = steps + 1
		until finished or steps >= max_steps or hires.since(t0) >= budget_ms
		local spent = hires.since(t0)
		gc_frame_ms = gc_frame_ms + spent
		mem_note_steps(step_kb, steps, spent)
	else
		local budget = budget_us / 1000000.0
		local t0 = clock()
		repeat
			finished = collectgarbage("step", step_kb)
			steps = steps + 1
		until finished or steps >= max_steps or (clock() - t0) >= budget
		gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0
	end
	if finished then
		pacer_cycle_done()
	end
end

local gc_tuned = false
local tuned_pause = nil
local tuned_stepmul = nil
local orig_pause = nil
local orig_stepmul = nil

local function apply_tuning(pause, stepmul)
	if orig_pause == nil then
		-- In Lua 5.1 setpause/setstepmul return the PREVIOUS value; capture the
		-- engine's real defaults on the first tune so we can restore them exactly
		-- rather than assuming stock 200/200. Fall back to 200 if the VM does not
		-- return a sane previous value.
		local p = collectgarbage("setpause", pause)
		local s = collectgarbage("setstepmul", stepmul)
		orig_pause = (type(p) == "number" and p > 0) and p or 200
		orig_stepmul = (type(s) == "number" and s > 0) and s or 200
	else
		collectgarbage("setpause", pause)
		collectgarbage("setstepmul", stepmul)
	end
	gc_tuned = true
	tuned_pause = pause
	tuned_stepmul = stepmul
	mod:info("GC tuned: pause=%d stepmul=%d", pause, stepmul)
end

local function restore_default_gc()
	if not gc_tuned then return end
	local rp = orig_pause or 200
	local rs = orig_stepmul or 200
	collectgarbage("setpause", rp)
	collectgarbage("setstepmul", rs)
	gc_tuned = false
	tuned_pause = nil
	tuned_stepmul = nil
	mod:info("GC restored (pause=%d stepmul=%d)", rp, rs)
end

-- Engine-side GC controller. Independently of the Lua-side collectgarbage knobs,
-- the engine runs its own native per-frame GC stepper, configured at boot via
-- Script.configure_garbage_collection(...) from DevParameters.gc_* -- including
-- FORCE_FULL_COLLECT_GARBAGE_LEVEL = 1, the trigger for the ENGINE's own
-- stop-the-world full collect mid-mission: the exact hitch this mod exists to
-- prevent. Raising that level hands full-collect duty to the mod's paced drains
-- and the ceiling backstop. Fully guarded: on a build without the API this does
-- nothing, and a failed attempt is never retried per-frame.
local engine_gc_tuned = false
local engine_gc_failed = false

local function apply_engine_gc(on)
	local S = rawget(_G, "Script")
	if not S or not S.configure_garbage_collection or not S.FORCE_FULL_COLLECT_GARBAGE_LEVEL then
		engine_gc_failed = true
		return
	end
	if on and not engine_gc_tuned then
		if engine_gc_failed then return end
		local ok = pcall(S.configure_garbage_collection, S.FORCE_FULL_COLLECT_GARBAGE_LEVEL, 2)
		if ok then
			engine_gc_tuned = true
			mod:info("Engine GC: forced full collects suppressed (garbage level 1 -> 2)")
		else
			engine_gc_failed = true
			mod:info("Engine GC: configure call failed, leaving engine defaults alone")
		end
	elseif not on and engine_gc_tuned then
		local dev = rawget(_G, "DevParameters")
		local default_level = (dev and dev.gc_force_full_collect_garbage_level) or 1
		pcall(S.configure_garbage_collection, S.FORCE_FULL_COLLECT_GARBAGE_LEVEL, default_level)
		engine_gc_tuned = false
		mod:info("Engine GC: defaults restored")
	end
end

-- While a loading screen is up, the engine's own GC stepper may spend more than
-- its stock 1 ms/frame -- nobody is watching the frame rate there, and every MB
-- it cleans is one the mission does not have to. Stock Stingray ships this
-- stepper at 10 ms/frame and Darktide dials it down to 1 at boot, so 4 ms stays
-- well inside the engine's design envelope. The boost is deliberately modest
-- since the collect_one_frame_of_garbage crash report (see load_state): every
-- extra millisecond the engine spends in GC during loading is extra exposure to
-- whatever the engine itself does wrong in that window, and the mod's own deep
-- clean (a full synchronous collect) already does the heavy lifting. The old
-- MINIMUM_COLLECT_TIME_MS raise is gone for the same reason -- it forced GC work
-- even while the engine's garbage estimate said there was nothing to do.
-- Restored from the game's own DevParameters defaults on loading exit / mission
-- start / mod disable.
local function set_loading_gc_boost(on)
	local S = rawget(_G, "Script")
	if not S or not S.configure_garbage_collection or not S.MAXIMUM_COLLECT_TIME_MS then return end
	if on and not load_state.boosted then
		if pcall(S.configure_garbage_collection, S.MAXIMUM_COLLECT_TIME_MS, 4) then
			load_state.boosted = true
		end
	elseif not on and load_state.boosted then
		local dev = rawget(_G, "DevParameters")
		local default_ms = (dev and dev.gc_maximum_collect_time_ms) or 1
		pcall(S.configure_garbage_collection, S.MAXIMUM_COLLECT_TIME_MS, default_ms)
		load_state.boosted = false
	end
end

-- Releases game-side memory that a plain collect can never reclaim because the
-- game itself keeps referencing it. Every block is pcall-guarded and uses the
-- game's own sanctioned reset paths, so an API change in a future patch degrades
-- to "that block silently does nothing" rather than an error. `in_loading` marks
-- the loading-screen call: some sweeps are only safe when no HUD exists at all.
local function sweep_game_caches(in_loading)
	local store_n, social_n, data_n = 0, 0, 0
	local telemetry_flushed = false

	-- Localization string cache: every localized string ever displayed is pinned
	-- (key + fully processed value; ~1-3 MB after a long hub session). The game
	-- itself resets it at StateLoading.on_exit, so this is its own sanctioned
	-- pattern -- doing it BEFORE our full collect lets the strings die in it.
	pcall(function()
		local loc = Managers.localization
		if loc and loc.reset_cache then loc:reset_cache() end
	end)

	-- Account gear list: the raw backend inventory (every owned weapon, curio and
	-- cosmetic with full override trees) sits resident from first fetch until the
	-- game quits -- multi-MB on hoarder accounts -- and every consumer deep-clones
	-- it on fetch. invalidate_gear_cache is the official nil-safe API (gentler
	-- than reset(): no promise cancellation); the next inventory open refetches
	-- once. Gear data is never needed mid-mission.
	pcall(function()
		local gear = Managers.data_service and Managers.data_service.gear
		if gear and gear.invalidate_gear_cache then gear:invalidate_gear_cache() end
	end)

	-- Recent-player bookkeeping: every account the presence stream ever saw gets
	-- a permanent PlayerInfo in _players_by_account_id (append-only; the game
	-- never prunes it and SocialService.reset is a no-op on Steam). Entries that
	-- carry player intent survive: friends, blocked, party members, and anyone
	-- muted this session (PlayerInfo is the ONLY store of session mutes).
	pcall(function()
		local social = Managers.data_service and Managers.data_service.social
		local by_id = social and social._players_by_account_id
		if not by_id then return end
		local keep = {}
		local function keep_list(list)
			if type(list) == "table" then
				for _, pi in pairs(list) do keep[pi] = true end
			end
		end
		keep_list(social._friends_list)
		keep_list(social._blocked_accounts_list)
		keep_list(social._blocked_players_list)
		keep_list(social._party_members)
		local dead = nil
		for account_id, pi in pairs(by_id) do
			if not keep[pi] then
				local muted = (pi.is_text_muted and pi:is_text_muted()) or (pi.is_voice_muted and pi:is_voice_muted())
				local special = (pi.is_blocked and pi:is_blocked()) or (pi.is_party_member and pi:is_party_member())
				if not muted and not special then
					dead = dead or {}
					dead[#dead + 1] = account_id
				end
			end
		end
		if dead then
			for i = 1, #dead do
				by_id[dead[i]] = nil
				social_n = social_n + 1
			end
		end
	end)

	-- NEVER sweep UrlLoaderManager textures. This block used to destroy every
	-- cached URL texture that had no download in flight, and that was wrong on
	-- two counts. First, UrlLoaderManager is REFERENCE COUNTED and the game
	-- already destroys every texture whose count reaches zero -- in its update,
	-- every single frame (url_loader_manager.lua:112-122) -- so a texture still
	-- present here is by definition one that something is still holding.
	-- Second, url_loader is shared: other mods load their own images through it
	-- (SpideySense's arrows, crosshair mods, ...). Calling the private
	-- _destroy_texture_data bypassed the refcount and ran Backend.unload_texture
	-- on GPU resources those mods were actively drawing, which killed the render
	-- device outright: "Resource type 0 is not available in bindless" at
	-- d3d12_render_device.cpp, a hard CTD with no Lua error. There is no way to
	-- tell a genuinely stranded texture from one in active use, so this stays
	-- gone. Freeing engine textures is simply not this mod's business.

	-- Premium store pages + wallets. StoreService.reset() is the game's own
	-- logout-time sweep: it drops _store_cache (full storefront payloads held for
	-- up to an hour) and resets the wallets cache. reset(), never invalidate() --
	-- invalidate immediately re-fires the backend requests it just cleared.
	pcall(function()
		local store = Managers.data_service and Managers.data_service.store
		if store and store.reset then
			local cache = store._store_cache
			if cache then
				for _ in pairs(cache) do store_n = store_n + 1 end
			end
			store:reset()
		end
	end)

	-- NEVER sweep the crafting trait sticker book. CraftingService.reset() wipes
	-- _trait_sticker_book_cache, and that cache is the one exception to the rule
	-- every other sweep here relies on: it has NO lazy refetch. Its only reader
	-- is cached_trait_sticker_book(), a cache-only lookup that quietly returns an
	-- empty table when the entry is gone, and the only thing that ever fills it
	-- is warm_trait_sticker_book_cache() -- called once, during login. Clearing
	-- it therefore made every blessing the player owns read as "never seen"
	-- until the game was restarted: a blank blessings grid in the Masteries tab,
	-- and blessings shown as unknown in crafting and item tooltips. This block
	-- used to call reset() here and must not come back.

	-- The four data services below have NO reset() method, so even the game's
	-- own logout sweep (DataServiceManager.reset is by-presence) skips them and
	-- their caches live until the process exits. All four repopulate lazily
	-- with a single backend call on next use -- no request storm -- and hold
	-- plain Lua tables only (no engine handles anywhere in these sweeps).

	-- Mastery track definitions: every weapon pattern's full track (tiers,
	-- rewards, claims) -- the largest of these caches after a Mastery UI visit.
	-- ONLY _mastery_tracks is cleared: the lazy warmup keys on exactly
	-- table.is_empty(_mastery_tracks) and refills all three tables together,
	-- while the id maps stay because crafting's extract flow reads get_track_id
	-- without going through the warmup.
	pcall(function()
		local mastery = Managers.data_service and Managers.data_service.mastery
		local tracks = mastery and mastery._mastery_tracks
		if tracks then
			for k in pairs(tracks) do
				tracks[k] = nil
				data_n = data_n + 1
			end
		end
	end)

	-- Penance track: fulfilled promises pinned forever (the catch handler
	-- self-cleans rejects only). Pending ones stay -- dropping one would spawn
	-- a duplicate request. Views hold their own derived promises via :next(),
	-- and cancel does not propagate to the parent, so dropping the cache entry
	-- cannot break an open view.
	pcall(function()
		local pt = Managers.data_service and Managers.data_service.penance_track
		local pc = pt and pt._promise_cache
		if pc then
			for track_id, p in pairs(pc) do
				if type(p) == "table" and p.is_fulfilled and p:is_fulfilled() then
					pc[track_id] = nil
					data_n = data_n + 1
				end
			end
		end
	end)

	-- News mail payloads (up to 100 mails per category, retained forever).
	-- _cached_promise is left alone: pending promises null themselves out on
	-- completion, and the resolve handler recreates the _cached_data entry.
	pcall(function()
		local news = Managers.data_service and Managers.data_service.news
		local news_cache = news and news._cached_data
		if news_cache then
			for k in pairs(news_cache) do
				news_cache[k] = nil
				data_n = data_n + 1
			end
		end
	end)

	-- Group Finder tag catalogue: SocialService.reset() never clears it. The
	-- getter lazily refetches on nil (one call on next Group Finder open).
	pcall(function()
		local social = Managers.data_service and Managers.data_service.social
		if social and social._cached_group_finder_tags ~= nil then
			social._cached_group_finder_tags = nil
			data_n = data_n + 1
		end
	end)

	-- Expedition track cache, cleared with the same statement the service uses
	-- itself when the track expires. Only when loading into a regular mission
	-- (mechanism "adventure"): the hub re-warms it immediately on entry, so
	-- clearing there only adds backend calls, and expedition missions read it
	-- mid-run. The nodes+result guard skips a cache that is mid-population.
	pcall(function()
		if not in_loading then return end
		local mech = Managers.mechanism
		local name = mech and mech.mechanism_name and mech:mechanism_name()
		if name ~= "adventure" then return end
		local exp = Managers.data_service and Managers.data_service.expedition
		local data = exp and exp._cached_data
		if data and data.nodes and data.result then
			for k in pairs(data) do
				data[k] = nil
				data_n = data_n + 1
			end
		end
	end)

	-- End-of-round report (full EOR of all players plus both xp tables). The
	-- game clears it itself, but only when the NEXT gameplay session
	-- initializes -- clearing it at the START of the loading screen lets it die
	-- in the free full collect that follows. The is_fetching gate is MANDATORY:
	-- clearing mid-fetch breaks _parse_report, whose catch handler kicks the
	-- player from the multiplayer session. Its readers (end view, score/victory
	-- states) all live in states that precede StateLoading.
	pcall(function()
		if not in_loading then return end
		local pm = Managers.progression
		if pm and pm.clear_session_report and pm.is_fetching_session_report and not pm:is_fetching_session_report() then
			pm:clear_session_report()
		end
	end)

	-- Flush buffered telemetry at a hitch-tolerant moment instead of letting its
	-- 5-minute timer fire mid-combat. batch_in_flight guards double-posting; the
	-- telemetry_events check matters because post_batch calls into it.
	pcall(function()
		local tm = Managers.telemetry
		if tm and tm.post_batch and tm.batch_in_flight and Managers.telemetry_events and not tm:batch_in_flight() then
			tm:post_batch()
			telemetry_flushed = true
		end
	end)

	-- NEVER sweep icon-renderer bookkeeping either. This block used to delete
	-- request entries in _requests_by_size that looked fully released (no
	-- references, not spawned, not spawning, no atlas slot). Reading the
	-- generator closely shows that state can only come from an unload with
	-- keep_reference, and that path deliberately leaves references_lookup
	-- populated (render_target_icon_generator_base.lua:292-294) while the
	-- non-keep path deletes the entry itself (:310). So every entry this sweep
	-- could match is one the game can still resolve by reference id -- and
	-- unload_request_reference dereferences the result with NO nil check (:266),
	-- so a later unload of that reference would throw. The GPU side is already
	-- reclaimed by the game anyway: the atlas slot is freed at :301 before the
	-- entry is kept. A version that also required references_lookup to be empty
	-- would match nothing at all. Not worth it; the leftover is a small table.

	return store_n, social_n, data_n, telemetry_flushed
end

-- Repair for saves damaged by the sticker-book sweep that 1.6.0 shipped (see the
-- long note in sweep_game_caches). Anyone whose cache was already emptied would
-- otherwise have to restart the game to get their blessings back, so the mod
-- asks the game to refill it using the game's own warm-up call -- exactly what
-- login does. Runs at most once per session, only when the cache is genuinely
-- empty and the backend is authenticated; if it is too early to tell, the flag
-- stays unset and the check simply happens again on the next state change.
local function repair_trait_sticker_book()
	if once.sticker_checked then return end
	pcall(function()
		local backend = Managers.backend
		if not backend or not backend.authenticated or not backend:authenticated() then
			-- Not logged in yet: leave the flag unset and retry later.
			return
		end
		local crafting = Managers.data_service and Managers.data_service.crafting
		local cache = crafting and crafting._trait_sticker_book_cache
		if not cache or type(cache.is_empty) ~= "function" or type(crafting.warm_trait_sticker_book_cache) ~= "function" then
			once.sticker_checked = true
			return
		end
		if not cache:is_empty() then
			once.sticker_checked = true
			return
		end
		once.sticker_checked = true
		crafting:warm_trait_sticker_book_cache()
		mod:info("Trait sticker book cache was empty -- requested a refill so blessings display correctly again")
	end)
end

-- The full deep clean: game caches (when no view owns them, or always inside a
-- loading screen where none can) followed by an instant full collect to actually
-- reclaim what the sweeps unpinned. `allow_with_views` doubles as the loading-
-- screen marker for the sweeps that are only safe with no view in existence.
local function deep_clean(reason, allow_with_views)
	local sweep_ok = allow_with_views or not view_open()
	local store_n, social_n, data_n, telemetry_flushed = 0, 0, 0, false
	if sweep_ok then
		store_n, social_n, data_n, telemetry_flushed = sweep_game_caches(allow_with_views)
	end
	do_full_collect(reason)
	if not cfg.silent then
		if sweep_ok then
			mod:echo(string_format("[FpsDoctor] Deep clean: gear+loc caches, store %d, %d stale player entries, %d service cache entries%s.",
				store_n, social_n, data_n, telemetry_flushed and ", telemetry flushed" or ""))
		else
			mod:echo("[FpsDoctor] Deep clean: a menu is open, cleaned memory only (game caches skipped).")
		end
	end
	mod:info("Deep clean (%s): store=%d players=%d datasvc=%d telemetry=%s sweeps=%s",
		reason, store_n, social_n, data_n, tostring(telemetry_flushed), tostring(sweep_ok))
end

-- ---------------------------------------------------------------------------
-- Per-mod allocation profiler ("which mod is eating memory"). Opt-in. Wraps each
-- DMF mod's update() with two collectgarbage("count") reads -- DMF's dispatcher
-- re-reads mod.update every frame, so wrapping and unwrapping take effect
-- immediately and are fully reversible. What this measures is ALLOCATION RATE in
-- the mod's update, not retention: a GC step inside the window makes the delta
-- negative, so negatives are discarded, and mods that allocate in hooks rather
-- than update are invisible to it. Still: the classic leaker (scoreboard-style
-- mods accreting tables every frame) shows up within seconds.
-- (State lives at the top of the file -- rebuild_lines displays it.)
local function profiler_get_dmf_mods()
	local ok, dmf = pcall(get_mod, "DMF")
	if not ok or not dmf then return nil end
	local mods = dmf.mods
	if type(mods) ~= "table" then return nil end
	return mods
end

local function profiler_wrap()
	local mods = profiler_get_dmf_mods()
	if not mods then return end
	for name, m in pairs(mods) do
		if type(m) == "table" and type(m.update) == "function"
				and not profiler_wrapped[name] and name ~= "FpsDoctor" then
			local orig = m.update
			local acc = profiler_alloc_kb
			-- Varargs, not (dt): anything DMF passes beyond the first argument now
			-- or later must reach the wrapped mod untouched. A wrapper that
			-- silently drops arguments would break the OTHER mod and be blamed on
			-- this one.
			local wrapper = function(...)
				local before = collectgarbage("count")
				orig(...)
				local d = collectgarbage("count") - before
				if d > 0 then
					acc[name] = (acc[name] or 0) + d
				end
			end
			profiler_wrapped[name] = { orig = orig, wrapper = wrapper }
			m.update = wrapper
		end
	end
	profiler_active = true
end

local function profiler_unwrap()
	local mods = profiler_get_dmf_mods()
	for name, entry in pairs(profiler_wrapped) do
		local m = mods and mods[name]
		-- Restore only if our wrapper is still installed; if another mod (or a
		-- reload) replaced update meanwhile, clobbering it would break them.
		if m and m.update == entry.wrapper then
			m.update = entry.orig
		end
		profiler_wrapped[name] = nil
	end
	profiler_alloc_kb = {}
	profiler_active = false
	profiler_top_name = nil
	profiler_top_rate = 0
end

-- 1 Hz: convert the accumulated KB into MB/min, remember the biggest allocator.
-- EMA when the leader is unchanged, so one busy second does not pin a mod to the
-- top slot forever; an actual runaway re-wins every tick anyway.
local function profiler_tick(elapsed_s)
	if elapsed_s <= 0 then return end
	local top_name, top_kb = nil, 0
	for name, kb in pairs(profiler_alloc_kb) do
		if kb > top_kb then top_name, top_kb = name, kb end
		profiler_alloc_kb[name] = 0
	end
	if top_name then
		local rate = (top_kb / 1024.0) / elapsed_s * 60.0
		if top_name == profiler_top_name then
			profiler_top_rate = profiler_top_rate * 0.7 + rate * 0.3
		else
			profiler_top_name = top_name
			profiler_top_rate = rate
		end
		if profiler_top_rate >= 1.0 then
			-- Another mod's name, so also not ours to trust with a percent sign.
			mod:info("Mod profiler: top allocator %s at %.1f MB/min",
				(tostring(profiler_top_name):gsub("%%", " pct")), profiler_top_rate)
		end
	end
end

local function request_collect(reason)
	if cfg.smooth_collect or in_gameplay then
		if not gc_drain_active then begin_drain(reason) end
	else
		do_full_collect(reason)
	end
end

local function manage_gc(dt)
	local mode = cfg.gc_mode or "balanced"

	-- Pacer qualifies too: the engine's forced full collect (garbage ~= live
	-- set) is reachable in long hub sessions under pacer's high pause, and both
	-- safety nets that replace it -- emergency drains and the ceiling backstop --
	-- are active in pacer. Balanced never opts in (engine_gc is preset-off there).
	local want_engine = ((mode == "aggressive" or mode == "pacer") and cfg.engine_gc) and true or false
	if engine_gc_tuned ~= want_engine then apply_engine_gc(want_engine) end

	if mode == "off" or mode == "map_only" then return end

	-- All stepping modes now honour the sliders; the presets carry each mode's
	-- real values (pacer 400/100, aggressive 700/300), so what the options UI
	-- shows is what actually runs.
	local pause = cfg.gc_pause or 150
	local stepmul = cfg.gc_stepmul or 200
	if not gc_tuned or tuned_pause ~= pause or tuned_stepmul ~= stepmul then
		apply_tuning(pause, stepmul)
	end

	if mode == "balanced" then return end

	-- Live heap for the cleanup decisions below. stats.heap_mb is only sampled
	-- once per second (for the display/peak); reading collectgarbage("count")
	-- here is O(1) and lets triggers fire on the true current heap instead of
	-- data up to ~1s stale. stats.heap_mb itself is left on its display cadence.
	local live_mb = collectgarbage("count") / 1024.0

	if emergency_cooldown > 0 then emergency_cooldown = emergency_cooldown - dt end
	if ceiling_cooldown > 0 then ceiling_cooldown = ceiling_cooldown - dt end
	if tier.cooldown > 0 then tier.cooldown = tier.cooldown - dt end
	if tier.futile > 0 then tier.futile = tier.futile - dt end

	-- Hard ceiling backstop. The engine's Lua heap is a bounded arena; crossing it
	-- is an out-of-memory crash that no pacing can undo. Near the limit the mod
	-- stops being polite: one synchronous full collect (a visible hitch) beats a
	-- crash, so this bypasses every cooldown except its own and abandons any
	-- in-flight drain (which has provably lost the race).
	local ceiling = cfg.heap_ceiling_mb or 1024
	if ceiling > 0 and ceiling_cooldown <= 0 and live_mb >= ceiling * K.CEILING_COLLECT_FRAC then
		ceiling_cooldown = K.CEILING_COOLDOWN_S
		emergency_cooldown = K.EMERGENCY_COOLDOWN_S
		gc_drain_active = false
		gc_drain_reason = nil
		if not cfg.silent then
			mod:echo(string_format("[FpsDoctor] Script memory %.0f MB is near the game's limit (~%d MB) -- cleaning instantly to avoid an out-of-memory crash.", live_mb, ceiling))
		end
		-- Mid-mission this is already the worst frame of the session; the second,
		-- floor-settling pass would double it for nothing a fight cares about.
		do_full_collect("ceiling", in_gameplay)
		return
	end

	-- Pre-ceiling escalation tier. With the stock presets the hard threshold
	-- (1024 MB) sits ABOVE the ceiling trigger (92% of 1024 = ~942 MB), so the
	-- escalation machinery below could never engage before the panic collect:
	-- between the adaptive tier and the ceiling there was no defense at all,
	-- and under Havoc-level load the paced drains (spike-gated, headroom-scaled)
	-- lose the race -- the heap sailed straight into the synchronous collect,
	-- which is exactly the mid-fight freeze players reported. This tier starts
	-- (or promotes to) an ESCALATED drain at PRE_CEILING_FRAC of the ceiling,
	-- ignoring the emergency cooldown, because escalated drains keep making real
	-- progress during exactly the fights that starve a normal drain (tick_drain).
	--
	-- It has its OWN cooldown (v1.6.5), and that is the whole difference between
	-- a safety net and a permanent tax: 1.6.4 re-armed this on the periodic
	-- tier's +32 MB of growth with no cooldown at all, so a session sitting
	-- anywhere in this band ran escalated drains back to back, every frame,
	-- indefinitely. The growth gate is now sized for real garbage, and
	-- finish_drain sets tier.cooldown after every escalated drain -- a long one
	-- when a completed cycle proved the heap is live rather than dirty.
	if ceiling > 0 and tier.futile <= 0 and live_mb >= ceiling * K.PRE_CEILING_FRAC
			and live_mb >= floor_heap_mb + K.PRE_CEILING_GROWTH_MB then
		if gc_drain_active then
			-- Promoting a drain that is ALREADY running is the "we are cleaning
			-- and still losing" case: it starts no new work, it only lets the
			-- work in flight finish faster. That is never the pathology, so the
			-- short cooldown does not gate it -- only a proven-futile verdict does.
			gc_drain_escalated = true
			return
		elseif tier.cooldown <= 0 then
			emergency_cooldown = K.EMERGENCY_COOLDOWN_S
			begin_drain("pre_ceiling")
			gc_drain_escalated = true
			return
		end
		-- Cooling down: fall through to the ordinary tiers below rather than
		-- returning, so the paced defense still gets its turn.
	end

	if mode == "aggressive" then
		periodic_acc = periodic_acc + dt
		local interval = (cfg.periodic_minutes or 10) * 60.0
		-- The Psykhanium allocates faster than anything else in the game (community
		-- reports up to +2500 MB/min) and has no map transitions to flush it, so
		-- the timer tightens to 2 minutes there. Skipped as usual if nothing grew.
		if in_psykhanium and interval > 120.0 then interval = 120.0 end
		if periodic_acc >= interval then
			periodic_acc = 0
			if live_mb >= floor_heap_mb + K.PERIODIC_MIN_GROWTH_MB then
				emergency_cooldown = K.EMERGENCY_COOLDOWN_S
				request_collect("periodic")
			end
		end
	end

	local threshold = cfg.threshold_mb or 1024
	-- Floor-relative trigger: once caches push the post-cleanup floor near the
	-- configured value, a fixed threshold would fire a full-heap cycle every few
	-- dozen MB of growth, forever -- maximum GC cost exactly where GC helps least.
	-- Anchoring to the floor keeps a sane gap between cleanups; the ceiling
	-- backstop above still owns the crash case.
	--
	-- The gap used to be a flat 256 MB, and that flat number was what made the
	-- cleanup trigger unreachable for an ordinary session: a player whose floor
	-- sits at 260 MB could not ask for cleanup below 516 MB no matter what they
	-- set the slider to, so a heap drifting between 300 and 490 MB was never
	-- touched by this tier at all. Proportional is the right shape -- the reason
	-- for the gap is "do not re-collect over trivial growth", and what counts as
	-- trivial scales with the heap. At a 260 MB floor the gap is now 96 MB
	-- instead of 256; at a 900 MB floor it is 315, slightly wider than before.
	local eff_threshold = threshold
	if threshold > 0 and floor_heap_mb > 0 then
		local gap = floor_heap_mb * K.THRESHOLD_FLOOR_GAP_FRAC
		if gap < K.THRESHOLD_FLOOR_GAP_MIN_MB then gap = K.THRESHOLD_FLOOR_GAP_MIN_MB end
		if eff_threshold < floor_heap_mb + gap then
			eff_threshold = floor_heap_mb + gap
		end
	end
	-- The soft (adaptive) tier keys off the PRE-clamp value on purpose: the clamp
	-- below exists to stop the HARD trigger from hiding above the panic line, and
	-- letting it drag the soft tier down with it would move the adaptive drain
	-- ~90 MB earlier in every session as a side effect nobody asked for.
	local soft_threshold = eff_threshold * K.SOFT_THRESHOLD_FRAC
	-- The paced defense must engage BELOW the ceiling's panic line: with the
	-- stock presets (threshold 1024 = ceiling 1024) the raw threshold lands
	-- above 92% of the ceiling, so the smooth drain could never fire before the
	-- synchronous collect it exists to prevent. The clamp keeps a real gap
	-- between "start cleaning smoothly" and "freeze the frame to survive"
	-- without dragging the whole schedule far down the heap (see the constant).
	if ceiling > 0 and eff_threshold > ceiling * K.CEILING_THRESHOLD_FRAC then
		eff_threshold = ceiling * K.CEILING_THRESHOLD_FRAC
	end

	if gc_drain_active then
		-- The heap kept climbing straight through an in-flight drain: promote it
		-- to the escalation tier in place rather than waiting for it to time out.
		if not gc_drain_escalated and threshold > 0 and live_mb >= eff_threshold + K.EMERGENCY_BYPASS_MB then
			gc_drain_escalated = true
		end
		return
	end

	-- A runaway allocator does not respect the 60 s cooldown window: the hard
	-- trigger may bypass it once growth has blown well past the threshold.
	local bypass = threshold > 0 and live_mb >= eff_threshold + K.EMERGENCY_BYPASS_MB

	if emergency_cooldown > 0 and not bypass then return end

	-- Rearm margin scales with the floor so a large-but-stable heap is not
	-- re-collected over trivial growth.
	local rearm = math_max(K.EMERGENCY_REARM_MB, floor_heap_mb * 0.15)
	if not bypass and live_mb < emergency_floor_mb + rearm then return end

	if threshold > 0 then
		if live_mb >= eff_threshold then
			emergency_cooldown = K.EMERGENCY_COOLDOWN_S
			request_collect("threshold")
			if bypass and gc_drain_active then gc_drain_escalated = true end
		elseif live_mb >= soft_threshold and stats.heap_rate >= K.ADAPTIVE_RATE_MB_MIN then
			emergency_cooldown = K.EMERGENCY_COOLDOWN_S
			request_collect("adaptive")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Hardware advisor.
--
-- What the numbers a player can tell the mod are actually good for -- and what
-- they are not. Being straight about this matters, because the appealing version
-- of this feature ("tell me your PC and I will pick the right mode") mostly
-- cannot be honoured: the settings that matter depend on what the session DOES,
-- not on what the hardware IS, and the mod can measure the former.
--
--  * RAM class and speed: they size one slice of cleanup work. That is already
--    wired up (see the MEM_ block) and the live measurement supersedes whatever
--    was declared. They do NOT indicate a cleanup mode.
--  * VRAM: nothing to do with garbage collection. Video memory is not the Lua
--    heap and no cleanup setting moves it by a byte. It is worth asking about
--    for one reason: a player whose frames are being eaten by VRAM pressure
--    should be told that, instead of being handed GC settings that cannot help.
--  * Frame time (measured): what a per-frame budget in MICROSECONDS really
--    costs. 1500 us is 6% of a 25 ms frame and 22% of a 7 ms one.
--  * The Lua arena size and the session's memory floor (both measured): the
--    dominant lever by a wide margin. When the floor drifts up to the mod's
--    ceiling, every tier is permanently triggered and the panic collect fires
--    over and over -- in simulation that is a 3-7 SECOND freeze plus 7-11% of
--    frame time, and simply moving the ceiling above the floor removes the
--    freeze entirely and halves the cost. No RAM spec can tell us that; the
--    floor can, and the mod already tracks it.
--
-- Mode advice comes from measured frame time, on measured grounds: on a weak
-- machine with a correctly sized ceiling, pacer costs about a third of
-- aggressive's frame time for the same protection (37.6 vs 36.2 fps in
-- simulation) while letting the heap sit ~130 MB higher. On mid and fast
-- machines every mode lands within ~1 fps, so aggressive's extras are free.
-- Which slider set fits this machine. Frame rate decides the class; a memory
-- subsystem measured as slow (or declared as DDR3) drops it one class further,
-- because a slice costs what the memory says it costs, not what the CPU says.
local function hw_class()
	local fps = stats.avg_fps > 0 and stats.avg_fps or stats.fps
	local order = { "fast", "mid", "weak", "slow" }
	local idx = 4
	if fps >= K.HW_CLASS_FPS.fast then idx = 1
	elseif fps >= K.HW_CLASS_FPS.mid then idx = 2
	elseif fps >= K.HW_CLASS_FPS.weak then idx = 3 end
	local slow_mem = (mem.measured and mem.us_per_kb >= K.HW_SLOW_MEM_US_PER_KB)
		or (cfg.mem_type == "ddr3")
	if slow_mem and idx < 4 then idx = idx + 1 end
	return order[idx], fps
end

local function hardware_advice()
	local profile = cfg.hw_profile or "advise"
	if profile == "off" then return end
	local apply = profile == "apply"
	local said = 0
	local function say(fmt, ...)
		local msg = string_format(fmt, ...)
		mod:info("Hardware advice: %s", msg)
		if not cfg.silent then mod:echo("[FpsDoctor] " .. msg) end
		said = said + 1
	end

	local ceiling = cfg.heap_ceiling_mb or 1024
	-- A floor is what remained after a cleanup. With cleanup off nothing ever
	-- established one, and calling the live heap a floor would put a false
	-- sentence in front of the player ("memory that survives every cleanup" when
	-- no cleanup ran). So track whether it is real: the advice that talks about a
	-- floor is skipped when it is not, and the "cleanup is off" branch covers
	-- that case instead.
	local floor = session_last_floor_mb
	if floor <= 0 then floor = floor_heap_mb end
	local floor_known = floor > 0
	if not floor_known then floor = stats.heap_mb end
	local mode = cfg.gc_mode or "balanced"

	-- 1. Arena vs ceiling. The detected launch option is proof the arena really
	-- is bigger, so raising the mod's ceiling to match is safe to do outright --
	-- and it is the single most valuable change available. Without that proof the
	-- ceiling must NOT be raised: it would hand out frames now and an
	-- out-of-memory crash later.
	if once.flag_mb > 0 and once.flag_mb > ceiling then
		if apply then
			mod:set("heap_ceiling_mb", once.flag_mb, false)
			ceiling = once.flag_mb
			say("Script memory limit raised to %d MB to match the --lua-heap-mb-size %d you launch with. The cleanup now has room to work below the limit instead of fighting it.",
				once.flag_mb, once.flag_mb)
		else
			say("You launch with --lua-heap-mb-size %d but the mod's script memory limit is %d MB. Raise it to %d in Mod Options -- with the limit set too low the cleanup fights a limit that is not really there, which costs frames.",
				once.flag_mb, ceiling, once.flag_mb)
		end
	elseif floor_known and ceiling > 0 and floor >= ceiling * K.HW_FLOOR_TIGHT_FRAC then
		-- No bigger arena detected and the floor is already crowding the ceiling.
		-- This is the case that produces multi-second freezes, and the fix is a
		-- launch option the mod cannot set for the player.
		say("Memory that survives every cleanup is now %.0f MB, against a limit of %d MB. That close to the limit the cleanup cannot win and starts costing frames instead. Two things help, in order: restart the game to clear it, and add   --lua-heap-mb-size 2048   to the game's launch options (Steam: Properties, Launch Options), then set the mod's script memory limit to 2048.",
			floor, ceiling)
	end

	-- 2. Video memory. Never a GC matter; only ever a "this is your real
	-- bottleneck" matter. The declared size is a fallback for builds where the
	-- driver budget is not readable.
	if procmem.mb <= 0 then pcall(sample_process_memory) end
	local vram_declared = tonumber(cfg.vram_gb) or 0
	local vram_used_gb = procmem.vram / 1024.0
	local vram_budget_gb = procmem.budget / 1024.0
	if vram_budget_gb > 0 and vram_used_gb >= vram_budget_gb * K.VRAM_PRESSURE_FRAC then
		if apply and not cfg.show_proc_mem then
			mod:set("show_proc_mem", true, false)
		end
		say("Video memory is at %.1f of %.1f GB. That is your bottleneck, not script memory -- no cleanup setting can move VRAM. Lower texture quality or resolution scale first; the panel's memory line is now showing VRAM so you can watch it.",
			vram_used_gb, vram_budget_gb)
	elseif vram_declared > 0 and vram_declared <= K.VRAM_TIGHT_GB and vram_budget_gb <= 0 then
		if apply and not cfg.show_proc_mem then
			mod:set("show_proc_mem", true, false)
		end
		say("With %d GB of video memory, stutter on busy maps is usually VRAM rather than script memory. The panel's memory line is on so you can tell the two apart: if VRAM sits near its limit while script memory is flat, cleanup settings will not help.",
			vram_declared)
	end

	-- 3. THE SLIDERS OF THE MODE THE PLAYER IS ALREADY IN. This is deliberately
	-- the first thing offered and the mode change the last: moving two sliders is
	-- cheap, reversible, keeps everything else about the chosen mode, and in the
	-- measurements it recovers most of what a mode change would.
	local class, fps = hw_class()
	local by_mode = K.HW_TUNE[mode]
	local tune = by_mode and by_mode[class]
	local budget_us = cfg.gc_budget_us or 1000
	local stepmul = cfg.gc_stepmul or 200
	local tuned_sliders = false
	if tune and hw.capped then
		-- A frame limiter inverts the advice (see K.HW_CAP_*), so the smaller
		-- slices below would be the wrong move here. Say what is actually true of
		-- a capped machine instead, and leave the sliders alone.
		-- The LATCHED cap period, not the current average. Printing the average
		-- here told a player with a 162 fps limiter that their frames were "pinned
		-- at 12.35 ms" -- which is 81 fps, the rate they happened to be averaging
		-- at that moment. A diagnostic sentence that reports a number the player
		-- can check has to report the right one.
		local cap_ms = hw.cap_ms > 0 and hw.cap_ms
			or (stats.avg_fps > 0 and 1000.0 / stats.avg_fps or 0)
		say("Your frame rate is capped (fastest frame seen: %.2f ms, about %.0f fps). That changes what this mod costs you: while the frame has slack the cleanup is absorbed by the limiter's wait and costs nothing at all, and when the frame is already at the cap even a fifth of a millisecond tips it -- so with a cap, FEWER and BIGGER cleanup slices beat many small ones, the opposite of an uncapped machine. Do not lower 'Smooth cleanup speed' here. If you see regular dips, the frame is at its limit: lower a graphics setting, or use the Balanced mode, which spends no frame time at all.",
			cap_ms, cap_ms > 0 and (1000.0 / cap_ms) or 0)
		-- Deliberately NOT setting tuned_sliders: this branch offered no sliders,
		-- so the "if stutter is still there after those two sliders" follow-up
		-- would refer to advice that was never given -- and it would point at the
		-- Continuous mode, whose preset LOWERS the budget 1500 -> 500, the exact
		-- opposite of the bigger slices this same paragraph prescribes for a
		-- capped machine. The player's log has all three lines at one timestamp.
	elseif tune then
		-- Never RAISE a mode's budget: pacer's own preset is already frugal, and
		-- the point of this is to spend less per frame, not more.
		local want_budget = tune.gc_budget_us
		if want_budget > budget_us then want_budget = budget_us end
		local want_stepmul = tune.gc_stepmul
		local budget_off = budget_us > want_budget * 1.25
		local stepmul_off = stepmul ~= want_stepmul
		if budget_off or stepmul_off then
			if apply then
				if budget_off then mod:set("gc_budget_us", want_budget, false) end
				if stepmul_off then mod:set("gc_stepmul", want_stepmul, false) end
				say("Tuned the %s mode for a '%s' machine (%.0f fps): cleanup speed %d us, cleanup intensity %d. Same mode, same schedule -- it just takes smaller bites, which is what stutter is made of.",
					mode, class, fps, want_budget, want_stepmul)
			else
				say("Try this FIRST, it keeps your mode and is two sliders: set 'Smooth cleanup speed' to %d (now %d) and 'Advanced: cleanup intensity' to %d (now %d). For a %.0f fps machine that measured smoother AND slightly faster than the stock values in testing.",
					want_budget, budget_us, want_stepmul, stepmul, fps)
			end
			tuned_sliders = true
		end
	end

	-- 4. Mode. Advisory even under 'apply' unless the player asked for apply --
	-- the mod's standing promise is that a mode you picked yourself sticks.
	if tuned_sliders then
		-- The sliders above are the thing to try first, and a mode change is the
		-- NEXT step only if that did not settle it -- so it is not done here, in
		-- either mode. Under 'apply' doing both would have been worse than
		-- useless: switching modes rewrites the sliders from the new mode's
		-- preset, so the tuning that was just applied would be silently undone in
		-- the same pass.
		say("If stutter is still there after those two sliders, THEN try switching the cleanup mode -- Continuous costs less per frame than Aggressive, and Balanced costs nothing at all but lets memory climb. Change one thing at a time and give each a mission.")
	elseif fps > 0 and fps < K.HW_WEAK_FPS and mode == "aggressive" then
		if apply then
			mod:set("gc_mode", "pacer", false)
			local preset = K.MODE_PRESETS.pacer
			if preset then
				for id, value in pairs(preset) do mod:set(id, value, false) end
			end
			say("Cleanup mode switched to Continuous: at %.0f fps it costs about a third of what Aggressive does per frame for the same protection, in exchange for script memory settling a little higher.",
				fps)
		else
			say("At %.0f fps, the Continuous mode costs about a third of Aggressive's frame time for the same protection (script memory settles a little higher). Worth trying if frames matter more to you than the lowest possible memory.",
				fps)
		end
	end

	-- Its own `if`, deliberately. This was an `elseif` after the slider advice --
	-- and branch 3 sets tuned_sliders for every aggressive machine (either the
	-- capped branch or because the stock 1500 us budget differs from its class),
	-- so the one observation that matters most to a player whose memory never
	-- moves was unreachable for exactly that player. Two independent facts about
	-- a session deserve two independent tests.
	if floor_known and ceiling > 0 and floor <= ceiling * K.HW_IDLE_FLOOR_FRAC
			and (mode == "pacer" or mode == "aggressive") then
		-- Nothing to clean. Saying so is more useful than tuning the cleaning: a
		-- session that settles this far below the limit will never reach any tier,
		-- so the per-frame machinery is pure cost, however small.
		say("Script memory settles at %.0f MB against a limit of %d MB -- it never gets close, so there is nothing here for the cleanup to do. The '%s' mode is not buying you anything on this session; Balanced spends no frame time at all and would cost you nothing in memory. Worth trying if you are chasing the last few frames.",
			floor, ceiling, mode)
	elseif (mode == "off" or mode == "map_only") and stats.heap_rate >= K.ADAPTIVE_RATE_MB_MIN
			and ceiling > 0 and floor >= ceiling * 0.6 then
		say("Cleanup is set to '%s' while script memory is %.0f MB and growing %.0f MB/min. Nothing here will reclaim it -- if frames degrade over a session, one of the cleanup modes is what changes that.",
			mode, stats.heap_mb, stats.heap_rate)
	end

	if said > 0 then
		refresh_cfg()
	else
		mod:info("Hardware advice: nothing to change (mode %s, floor %.0f MB, ceiling %d MB, %.0f fps)",
			mode, floor, ceiling, fps)
	end
end

function mod.update(dt)
	if not mod:is_enabled() then return end
	if type(dt) ~= "number" or dt <= 0 then return end
	if dt > K.PAUSE_FRAME_S then
		gc_frame_ms = 0
		return
	end

	local gc_prev_ms = gc_frame_ms
	gc_frame_ms = 0

	local inst = 1.0 / dt
	if stats.fps <= 0 then
		stats.fps = inst
	else
		stats.fps = stats.fps * 0.9 + inst * 0.1
	end
	stats.frame_ms = dt * 1000.0
	-- Spread of frame times within the current second: a limiter pins it to
	-- nearly zero, which is how the advisor tells a capped machine from a free one.
	if stats.frame_min <= 0 or stats.frame_ms < stats.frame_min then stats.frame_min = stats.frame_ms end
	if stats.frame_ms > stats.frame_max then stats.frame_max = stats.frame_ms end

	local extras = diag_extras()
	local on_menu = extras and menu_open

	if stats.frame_ms > (cfg.hitch_ms or 50) then
		-- Re-probe only on frames that are already expensive, so a normal frame pays
		-- nothing. If the probe cannot tell, fall back to the 1 Hz flag.
		if extras then
			local live = probe_menu_open()
			if live ~= nil then on_menu = live end
		end
		if on_menu then
			menu_hitches = menu_hitches + 1
			menu_open_hitches = menu_open_hitches + 1
		else
			mission_hitches = mission_hitches + 1
			if gc_prev_ms >= K.GC_HITCH_ATTRIB_MS then
				mission_gc_hitches = mission_gc_hitches + 1
			end
		end
	end

	-- in_gameplay, because the EMIT was gated on it but the counting was not.
	-- The window's CLOCK only advanced during gameplay while its counters ran
	-- everywhere, so frames from boot, title, loading screens and the
	-- end-of-round scoreboard were divided by a gameplay-only elapsed time. That
	-- is what produced lines like "avg 701.0 fps, 7048 frames in 10s": not a real
	-- frame rate -- the wall-clock bound on the worst such line is about 130 fps
	-- -- but a division artifact, and it dragged the hitch count with it (9 of
	-- the 11 hitches on that line happened before gameplay began).
	if cfg.diag_log and in_gameplay then
		hw.log_frames = hw.log_frames + 1
		if gc_prev_ms > 0 then
			hw.log_gc_frames = hw.log_gc_frames + 1
			hw.log_gc_ms = hw.log_gc_ms + gc_prev_ms
		end
		if stats.frame_ms > (cfg.hitch_ms or 50) then hw.log_hitches = hw.log_hitches + 1 end
		if stats.frame_ms > hw.log_max_ms then hw.log_max_ms = stats.frame_ms end
		if gc_prev_ms > hw.log_max_gc_ms then hw.log_max_gc_ms = gc_prev_ms end
	end

	-- A menu build frame would otherwise sit in the ring buffer for ~17 s and drag
	-- the 99th-percentile 1% low down, i.e. the number the panel presents as the
	-- real stutter figure would be describing the menu instead of the game.
	if not on_menu then
		samples[sample_idx] = dt
		sample_idx = sample_idx + 1
		if sample_idx > K.SAMPLE_MAX then sample_idx = 1 end
		if sample_count < K.SAMPLE_MAX then sample_count = sample_count + 1 end
	end

	win.sec = win.sec + dt
	win.time = win.time + dt
	win.frames = win.frames + 1
	if win.sec >= 1.0 then
		stats.avg_fps = (win.time > 0) and (win.frames / win.time) or 0
		win.time = 0
		win.frames = 0
		-- The percentile is display-only; skip the selection pass entirely when
		-- nothing shows it. (Re-enabling just waits one second for fresh data.)
		if cfg.show_overlay and cfg.show_low then
			stats.low_fps = compute_low_fps()
		else
			stats.low_fps = 0
		end

		-- Limiter verdict for the second just ended, then reset the window.
		if stats.frame_max > 0 and stats.frame_min > 0 then
			local spread = stats.frame_max - stats.frame_min
			local mean = (stats.frame_max + stats.frame_min) * 0.5
			-- A limiter pins frame time to ONE value and holds it there, so both
			-- tests have to pass: the second's frames landed together, and they
			-- landed on the same value as the previous second's. Stability within
			-- one second alone is not enough -- a quiet moment in a mission looks
			-- like that too, and calling it a limiter would invert the advice for
			-- a player who has none.
			local same_as_before = hw.last_mean > 0
				and mean <= hw.last_mean * 1.02 and mean >= hw.last_mean * 0.98
			-- Only gameplay seconds with NO throttle active may count. Observed in
			-- the wild: the verdict latched at "fastest frame 16.70 ms, about
			-- 60 fps" on a machine whose limiter is 162 -- because the game's own
			-- view throttle pins frame time to exactly 60 fps (frame_rate_manager
			-- sets target_fps = 60), and a menu or the hub at boot produces a
			-- pinned pattern indistinguishable from a limiter. fps_cap_reason is
			-- already sampled every second for the panel and is non-nil exactly
			-- when the game is throttling, so it is the right gate.
			local throttled = fps_cap_reason ~= nil
			if in_gameplay and not throttled
					and spread <= stats.frame_max * K.HW_CAP_SPREAD_FRAC and same_as_before then
				hw.stable = hw.stable + 1
			else
				hw.stable = 0
			end
			-- LATCHED, not recomputed. A limiter does not come and go: once three
			-- consecutive pinned seconds have been seen, this machine has one for
			-- the rest of the session. Recomputing it meant a single dipping second
			-- reset the counter and the machine read as uncapped -- and the player
			-- who most needs the capped-machine advice is exactly the one whose
			-- frames are already dipping. The advisor reads this flag once, at the
			-- 45 s mark, to decide between two OPPOSITE recommendations, so a flag
			-- that flickers is worse than no flag.
			if hw.stable >= K.HW_CAP_SECONDS then hw.capped = true end
			-- The cap's period is the FASTEST pinned frame time seen: a limiter is a
			-- floor nothing beats, so the minimum is the cap, and it cannot drift
			-- downward as the mod's own work slows the achieved rate.
			if hw.stable >= K.HW_CAP_SECONDS and (hw.cap_ms <= 0 or mean < hw.cap_ms) then
				hw.cap_ms = mean
			end
			hw.last_mean = mean
		end
		stats.frame_min = 0
		stats.frame_max = 0

		local heap_kb = collectgarbage("count")
		stats.heap_mb = heap_kb / 1024.0
		if stats.heap_mb > peak_heap_mb then peak_heap_mb = stats.heap_mb end
		if last_heap_kb then
			local rate = ((heap_kb - last_heap_kb) / 1024.0) / win.sec * 60.0
			stats.heap_rate = stats.heap_rate * 0.7 + rate * 0.3
			if extras and in_gameplay and rate >= K.RUNAWAY_MB_MIN then
				runaway_streak = runaway_streak + 1
			else
				runaway_streak = 0
			end
			runaway_active = runaway_streak >= K.RUNAWAY_SAMPLES
		end
		last_heap_kb = heap_kb
		in_psykhanium = (in_gameplay and probe_psykhanium()) or false
		fps_cap_reason = nil
		if extras then
			-- _get_top_reason is a pure read over the reasons table (no side
			-- effects); pcall in case a patch renames it.
			local fr = Managers.frame_rate
			if fr and fr._get_top_reason then
				local ok, reason_name, _, throttled = pcall(fr._get_top_reason, fr)
				if ok and throttled then
					fps_cap_reason = reason_name or "default"
				end
			end
			tick_menu_state(stats.heap_mb, win.sec)
			-- Close-edge drain (opt-in): menu churn above the threshold gets a
			-- normal paced drain right away instead of waiting for the next
			-- threshold/periodic trigger. Reuses the whole drain machinery
			-- (budget, spike gate, headroom backoff); reachable only in
			-- pacer/aggressive because tick_menu_state runs only there.
			if menu_drain_pending > 0 then
				local grew = menu_drain_pending
				menu_drain_pending = 0
				-- 8 MB: enough to skip ordinary inventory visits, low enough to
				-- catch a mod-options build.
				if cfg.menu_drain and grew >= 8.0 and not gc_drain_active then
					emergency_cooldown = K.EMERGENCY_COOLDOWN_S
					request_collect("menu_close")
				end
			end
		elseif menu_open then
			-- Mode changed out from under an open menu: drop the state silently
			-- rather than leaving a stale flag that would mis-tag later frames.
			menu_open = false
			menu_charge_mb = 0
			menu_open_mb = 0
			menu_open_hitches = 0
			menu_drain_pending = 0
		end
		-- Engine-side memory line: sampled every 5th second, and immediately on
		-- the first tick after the line is enabled so it never shows stale zeros.
		if cfg.show_overlay and cfg.show_proc_mem then
			procmem.tick = procmem.tick + 1
			if procmem.tick >= 5 or procmem.mb == 0 then
				procmem.tick = 0
				sample_process_memory()
			end
		end
		-- Hardware advice, once per session and only after enough gameplay for the
		-- floor, the frame rate and the memory-speed measurement to mean
		-- something. Not while a menu is open: the frame time there is not the
		-- frame time being advised about.
		if not hw.done and in_gameplay and not menu_open then
			hw.t = hw.t + win.sec
			if hw.t >= K.HW_DELAY_S then
				hw.done = true
				pcall(hardware_advice)
			end
		end
		-- One line per interval, with everything needed to compare two runs: the
		-- frame rate, the stutter figure, how often the mod worked and for how long,
		-- where memory sits, and the settings in force.
		if cfg.diag_log and in_gameplay then
			hw.log_t = hw.log_t + win.sec
			if hw.log_heap0 <= 0 then hw.log_heap0 = stats.heap_mb end
			if hw.log_t >= K.DIAG_LOG_S and hw.log_frames > 0 then
				local shown_floor = (stats.map_floor > 0 and stats.map_floor or floor_heap_mb)
				if stats.heap_mb > 0 and shown_floor > stats.heap_mb then shown_floor = stats.heap_mb end
				-- "pct", not "%", on purpose -- do not "fix" this back.
				-- DMF formats a log line once (protected by pcall) and then hands
				-- the finished text to the game's print, which formats it AGAIN
				-- and is not protected. So a literal % surviving into the final
				-- text is a hard crash, not a bad-looking line: LuaJIT rejects
				-- "% l" as an invalid option, the error is raised inside our
				-- update callback, and the mod manager then dies trying to print
				-- an error message that also contains "% l". 1.6.5 shipped
				-- "1%% low" here and crashed every player whose DMF routes mod
				-- output through the developer console. No log line of ours needs
				-- the character, so it does not get to have it.
				mod:info("DIAG %ds: avg %.1f fps, 1pct low %.1f fps, %d frames (%.1f pct with cleanup, %.2f ms/s), %d hitches >%d ms (worst frame %.1f ms, worst cleanup %.2f ms), heap %.0f MB (floor %.0f, %+.0f MB/min), mode %s budget %d stepmul %d%s",
					math_floor(hw.log_t + 0.5),
					(hw.log_frames / hw.log_t), stats.low_fps, hw.log_frames,
					100.0 * hw.log_gc_frames / hw.log_frames,
					hw.log_gc_ms / hw.log_t,
					hw.log_hitches, cfg.hitch_ms or 50,
					hw.log_max_ms, hw.log_max_gc_ms,
					-- The floor as DISPLAYED: the last map-load floor when there is
					-- one (measured after a double full collect, unlike a periodic
					-- drain's single incremental cycle), and never above the heap it
					-- is meant to bound.
					stats.heap_mb, shown_floor,
					-- Growth over THIS interval, not an exponential average of the
					-- last single second printed as though it described ten -- the
					-- old field's sign disagreed with the interval's own heap change
					-- on a fifth of the lines in the player's logs.
					(stats.heap_mb - hw.log_heap0) * (60.0 / hw.log_t),
					tostring(cfg.gc_mode or "balanced"), cfg.gc_budget_us or 0,
					cfg.gc_stepmul or 0,
					hw.capped and string_format(", frame rate capped @ %.2f ms", hw.cap_ms) or "")
				hw.log_t = 0
				hw.log_heap0 = 0
				hw.log_frames = 0
				hw.log_gc_frames = 0
				hw.log_gc_ms = 0
				hw.log_hitches = 0
				hw.log_max_ms = 0
				hw.log_max_gc_ms = 0
			end
		end
		if cfg.mod_profiler and extras then
			-- Re-scan every second so mods loaded/reloaded later get wrapped too.
			profiler_wrap()
			profiler_tick(win.sec)
		elseif profiler_active then
			profiler_unwrap()
		end
		win.sec = 0
	end

	if cfg.auto_reset then
		win.reset = win.reset + dt
		if win.reset >= (cfg.auto_reset_minutes or 10) * 60.0 then
			reset_diagnostics()
		end
	else
		win.reset = 0
	end

	-- Quiet window at the start of every loading screen (see load_state): the
	-- mod adds NO GC work of its own while the previous world's engine objects
	-- are still dying -- no boost, no deep clean, no stepping, no drains. Once
	-- the window closes, the boost and the deferred deep clean fire and the
	-- loading screen absorbs their cost exactly as before.
	if load_state.active then
		load_state.t = load_state.t + dt
		if load_state.t < load_state.QUIET_S then
			return
		end
		load_state.active = false
		set_loading_gc_boost(true)
		-- The sweeps already ran at StateLoading enter; this is the collect that
		-- had to wait out the teardown window. Skipping the sweeps here also
		-- keeps them from running twice per loading screen.
		if load_state.swept then
			do_full_collect("loading")
		else
			deep_clean("loading", true)
		end
		load_state.deep_done = true
	end

	manage_gc(dt)
	tick_drain()
	local mode_now = cfg.gc_mode or "balanced"
	if mode_now == "pacer" then
		tick_incremental(K.PACER_STEP_KB, K.PACER_MAX_STEPS)
	elseif mode_now == "aggressive" then
		tick_incremental(K.AGGR_STEP_KB, K.AGGR_MAX_STEPS)
	end

	-- Only draw while a gameplay world is actually live (hub or mission).
	-- StateGameplay "exit" clears in_gameplay before the engine despawns
	-- level_world, so this keeps the overlay off during the loading/teardown
	-- transition -- exactly the window where the owning world dies underneath a
	-- cached gui. ensure_gui() revalidates the world too; this is the cheap
	-- outer guard. Outside a gameplay world there is no level_world to draw into
	-- anyway, so this removes no case that previously rendered.
	if cfg.show_overlay and in_gameplay then
		draw_overlay(dt)
	end
end

function mod.on_game_state_changed(status, state_name)
	if not mod:is_enabled() then return end

	-- The loading screen is the game's own sanctioned moment for dropping Lua
	-- caches (StateLoading.on_exit is where IT resets the localization cache):
	-- the previous world is already destroyed, the frame is capped, and a
	-- multi-ms collect is invisible. This is where the deep clean lives.
	if state_name == "StateLoading" then
		if status == "enter" then
			-- Loading screens run under the game's default 60 fps throttle (the
			-- 'gameplay' full-rate reason was relinquished at mission cleanup),
			-- and the package manager polls/pops its async queue once per FRAME --
			-- so the cap is also a cap on streaming turnaround. Priority 3
			-- outranks every vanilla reason.
			if cfg.fast_loading then
				pcall(function()
					Managers.frame_rate:request_full_frame_rate("fps_doctor_loading", 3)
				end)
			end
			-- Off is contractually "never clean". Every other mode honours an
			-- explicit opt-in (the aggressive preset turns it on; elsewhere it is
			-- off unless the player checked it themselves).
			if (cfg.gc_mode or "balanced") ~= "off" and cfg.deep_clean then
				gc_drain_active = false
				gc_drain_reason = nil
				-- The CACHE SWEEPS run right now. They are plain Lua table writes
				-- against the game's own data services -- no collection, no engine
				-- handles -- so the teardown window that the collect has to wait
				-- out (see load_state) never applied to them. Deferring them along
				-- with the collect was a mistake with a very specific victim: on a
				-- fast NVMe machine a loading screen can be over in under
				-- QUIET_S, and then StateGameplay cleared load_state and the deep
				-- clean never happened AT ALL. Measured: with loads of 1.0-1.4 s
				-- the deep clean ran three times out of three in 1.6.3 and zero
				-- times in 1.6.4. Sweeping here restores it, and doing it early
				-- also unpins that memory before the engine's own stepper spends
				-- the loading screen collecting.
				local ok, store_n, social_n, data_n = pcall(sweep_game_caches, true)
				if ok then
					load_state.swept = true
					mod:info("Loading sweeps: store=%s players=%s datasvc=%s",
						tostring(store_n), tostring(social_n), tostring(data_n))
				end
				-- The COLLECT (and the engine GC boost) still wait out the
				-- teardown transition: armed here, fired from mod.update once
				-- QUIET_S seconds of loading have passed. A load shorter than that
				-- simply lets the map_start drain collect what the sweeps unpinned.
				load_state.active = true
				load_state.t = 0
			end
		elseif status == "exit" then
			pcall(function()
				Managers.frame_rate:relinquish_request("fps_doctor_loading")
			end)
			-- The loading screen ended before the quiet window elapsed, so the
			-- deferred collect never ran. Do it HERE rather than dropping it: the
			-- window existed to stay clear of the teardown at the START of loading,
			-- and this is the far end of the same screen -- still not a gameplay
			-- frame, so it costs the player nothing. Without this a fast machine
			-- lost the collect entirely and paid for it later, in-mission, through
			-- the paced drain -- which on a frame-rate-capped setup is exactly
			-- where it hurts.
			if load_state.active and load_state.swept then
				load_state.active = false
				do_full_collect("loading_end")
				load_state.deep_done = true
			end
			load_state.active = false
			set_loading_gc_boost(false)
		end
		return
	end

	if state_name ~= "StateGameplay" then return end

	if status == "enter" then
		in_gameplay = true
		-- Safety net: neither the loading boost nor a pending deferred clean may
		-- ever survive into a mission (a missed StateLoading exit would otherwise
		-- leave the engine spending 4 ms/frame on GC in combat, or fire a deep
		-- clean's synchronous collect mid-fight).
		load_state.active = false
		set_loading_gc_boost(false)
		-- Same reasoning as the two lines above, and it was missing: a
		-- fps_doctor_loading request that outlived its loading screen would keep
		-- the game's throttle lifted for the whole mission, which silently uncaps
		-- the in-mission ESC menu. Harmless in direction, wrong in principle.
		pcall(function() Managers.frame_rate:relinquish_request("fps_doctor_loading") end)
		local was_deep = load_state.deep_done
		load_state.deep_done = false
		-- Whether the sweeps ran is per-load state; the mission that just started
		-- gets its own answer next time.
		load_state.swept = false
		if (cfg.gc_mode or "balanced") == "off" then
			mission_start_heap_mb = collectgarbage("count") / 1024.0
			mission_baseline_pending = false
		elseif was_deep then
			-- The deep clean already double-collected on the loading screen;
			-- repeating that here would only stretch the first gameplay frame.
			-- Publish the settled heap as the authoritative floor and baseline.
			local cur = collectgarbage("count") / 1024.0
			stats.heap_mb = cur
			floor_heap_mb = cur
			pacer_resume_mb = cur + resume_headroom_mb()
			mission_start_heap_mb = cur
			mission_baseline_pending = false
			note_map_baseline(cur, true)
		elseif cfg.smooth_collect then
			gc_drain_active = false
			begin_drain("map_start")
			mission_baseline_pending = true
			-- Provisional baseline so the overlay's per-mission delta reads
			-- ~0 during the drain instead of the previous mission's baseline
			-- (which could briefly flash a false "leak" colour). finish_drain
			-- overwrites this with the true post-drain floor.
			mission_start_heap_mb = collectgarbage("count") / 1024.0
		else
			gc_drain_active = false
			do_full_collect("map_start")
			mission_start_heap_mb = stats.heap_mb
			mission_baseline_pending = false
			-- do_full_collect double-collects, so this floor is authoritative.
			note_map_baseline(stats.heap_mb, true)
		end
		mission_hitches = 0
		mission_gc_hitches = 0
		menu_hitches = 0
		menu_open = false
		menu_charge_mb = 0
		menu_open_mb = 0
		menu_open_hitches = 0
		menu_base_mb = collectgarbage("count") / 1024.0
		runaway_streak = 0
		runaway_active = false
		sample_count = 0
		sample_idx = 1
		win.time = 0
		win.frames = 0
		win.sec = 0
		periodic_acc = 0
		-- A new level is fresh evidence: whatever the escalation tier concluded
		-- about the previous mission's heap (including a futility back-off) is
		-- re-measured rather than carried over. tier.warned is NOT reset -- the
		-- restart advice is worth saying once per session, not once per map.
		tier.cooldown = 0
		tier.futile = 0
		tier.misses = 0
		-- Start the measurement window with the mission, not with whatever was
		-- left over from the loading screen.
		hw.log_t = 0
		hw.log_heap0 = 0
		hw.log_frames = 0
		hw.log_gc_frames = 0
		hw.log_gc_ms = 0
		hw.log_hitches = 0
		hw.log_max_ms = 0
		hw.log_max_gc_ms = 0
		emergency_floor_mb = was_deep and floor_heap_mb or 0
		stats.heap_rate = 0
		last_heap_kb = collectgarbage("count")
		overlay_dirty = true
		-- Well after login, so the game's own warm-up has long since run: a cache
		-- that is still empty here was emptied by the 1.6.0 sweep, not by timing.
		repair_trait_sticker_book()
	elseif status == "exit" then
		in_gameplay = false
		menu_open = false
		runaway_streak = 0
		runaway_active = false
		if mission_start_heap_mb > 0 and not mission_baseline_pending then
			-- "Off" is contractually "never clean", so it must not force a GC
			-- here. Other modes settle the heap with a full collect so the floor
			-- and leak verdict are accurate.
			local cleans = (cfg.gc_mode or "balanced") ~= "off"
			if cleans then
				collectgarbage("collect")
				collectgarbage("collect")
			end
			local cur = collectgarbage("count") / 1024.0
			last_heap_kb = collectgarbage("count")
			stats.heap_mb = cur
			if cleans then
				floor_heap_mb = cur
			end
			local net = cur - mission_start_heap_mb
			local verdict = mission_verdict(net)
			if not cfg.silent then
				mod:echo(string_format("[FpsDoctor] Mission heap: %.0f -> %.0f MB (%s%.0f) -- %s", mission_start_heap_mb, cur, net >= 0 and "+" or "", net, verdict))
			end
			mod:info("Mission heap: %.1f -> %.1f MB (%+.1f) -- %s", mission_start_heap_mb, cur, net, verdict)
		end
		release_gui()
	end
end

function mod.on_setting_changed(setting_id)
	if setting_id == "gc_mode" then
		local mode = mod:get("gc_mode") or "balanced"
		local preset = K.MODE_PRESETS[mode]
		if preset then
			for id, value in pairs(preset) do
				mod:set(id, value, false)
			end
		end
	end
	refresh_cfg()
	-- Re-arm the advisor when the player changes what it advises on, so a new
	-- answer follows a new input instead of waiting for the next session.
	if setting_id == "hw_profile" or setting_id == "vram_gb"
			or setting_id == "mem_type" or setting_id == "mem_mts" then
		hw.done = false
		hw.t = 0
	end
	if setting_id == "gc_mode" or setting_id == "smooth_collect" then
		-- A floor left by one incremental cycle and one left by a double full collect
		-- are not comparable, so the chain restarts instead of mixing the two.
		reset_session_drift()
	end
	if setting_id == "gc_mode" then
		local mode = cfg.gc_mode or "balanced"
		periodic_acc = 0
		emergency_cooldown = 0
		emergency_floor_mb = 0
		-- Only when the mode actually CHANGED. These cooldowns are the whole
		-- rate limit on the escalation tier, and "re-pick the cleanup mode" is
		-- exactly what a player does when they suspect the mod -- so treating a
		-- no-op re-selection as a reason to throw away a back-off the mod had just
		-- decided was warranted would re-arm a 3 ms/frame drain for no reason.
		if mode ~= tier.mode then
			tier.mode = mode
			tier.cooldown = 0
			tier.futile = 0
			tier.misses = 0
			tier.warned = false
		end
		-- Drop any accrued menu discount. It is only *displayed* while the mode opts
		-- into the extra diagnostics, so leaving it would be invisible now but would
		-- silently re-apply a stale number if the player switched back later.
		menu_open = false
		menu_charge_mb = 0
		menu_open_mb = 0
		menu_open_hitches = 0
		menu_hitches = 0
		if mode == "off" then
			-- Abandon any in-flight smooth drain so "Off" actually stops cleaning
			-- immediately instead of stepping GC for up to GC_DRAIN_MAX_FRAMES.
			-- (Not for map_only: a pending map_start drain must finish so it can
			-- settle the mission baseline.)
			gc_drain_active = false
			gc_drain_reason = nil
		end
		if mode == "off" or mode == "map_only" then
			restore_default_gc()
		elseif K.MODE_PRESETS[mode] and not cfg.silent then
			mod:echo(string_format("[FpsDoctor] Cleanup sliders set to recommended values for '%s'", mode))
		end
	end
end

-- One-time environment log: VM identity and launch options. Read-only, info
-- level, runs once per process. The --lua-heap-mb-size detection is best
-- effort (whether launcher options reach argv is build-dependent); when the
-- flag IS seen and exceeds the configured ceiling, the player gets one precise
-- hint to raise the ceiling setting to match their actual arena size.
local function log_environment()
	if once.env_logged then return end
	once.env_logged = true
	pcall(function()
		local j = rawget(_G, "jit")
		local version = (j and j.version) or "no jit table"
		local status = (j and j.status and tostring(j.status())) or "n/a"
		local tnew = (rawget(_G, "table") and table.new) and "yes" or "no"
		mod:info("VM: %s (jit on: %s, table.new: %s)", tostring(version), status, tnew)
	end)
	pcall(function()
		local app = rawget(_G, "Application")
		if not app or not app.argv then return end
		local argv = { app.argv() }
		for i = 1, #argv do
			argv[i] = tostring(argv[i])
		end
		if #argv > 0 then
			-- The command line is outside our control, so strip any percent out of
			-- it rather than trusting that no player ever has one in a launch
			-- option or a path. See the DIAG line for why a bare % is fatal.
			mod:info("argv: %s", (table.concat(argv, " "):gsub("%%", " pct")))
		end
		for i = 1, #argv do
			local a = argv[i]
			if a:find("lua-heap-mb-size", 1, true) then
				local n = tonumber(a:match("(%d+)")) or tonumber(argv[i + 1] or "")
				if n and n >= 512 and n <= 8192 then
					once.flag_mb = n
					mod:info("Detected --lua-heap-mb-size %d", n)
				end
				break
			end
		end
	end)
	if once.flag_mb > 0 and (cfg.heap_ceiling_mb or 0) > 0 and once.flag_mb > cfg.heap_ceiling_mb and not cfg.silent then
		mod:echo(string_format("[FpsDoctor] Launch option --lua-heap-mb-size %d detected, but the mod's script memory limit is set to %d MB. Consider raising 'Script memory limit' to %d in Mod Options.",
			once.flag_mb, cfg.heap_ceiling_mb, once.flag_mb))
	end
end

function mod.on_enabled(initial_call)
	refresh_cfg()
	-- One-time migration to the new default: 'aggressive' is now the mode the
	-- mod ships with, and existing installs are switched over ONCE so every
	-- player gets it -- fresh installs pick it up from _data.lua defaults, and
	-- this flag guarantees a later manual mode change is never overridden again.
	-- Existing aggressive installs get the same four, once. Gated on already
	-- being on aggressive so no other mode is touched, and latched so a later
	-- manual change is never overridden.
	if not mod:get("migrated_aggressive_extras_v165")
			and (mod:get("gc_mode") or "balanced") == "aggressive" then
		mod:set("migrated_aggressive_extras_v165", true, false)
		mod:set("menu_drain", true, false)
		mod:set("show_session", true, false)
		mod:set("diag_log", true, false)
		mod:set("show_proc_mem", true, false)
		refresh_cfg()
		mod:info("Enabled the aggressive extras that measurably do something and cost no frame time: cleanup after menus, floor-drift line, measurement log, video-memory line")
	end
	if not mod:get("migrated_default_aggressive_v16") then
		mod:set("migrated_default_aggressive_v16", true, false)
		mod:set("gc_mode", "aggressive", false)
		for id, value in pairs(K.MODE_PRESETS.aggressive) do
			mod:set(id, value, false)
		end
		refresh_cfg()
		reset_session_drift()
		periodic_acc = 0
		emergency_cooldown = 0
		emergency_floor_mb = 0
		mod:info("Migrated cleanup mode to the new default 'aggressive'")
		if not cfg.silent then
			mod:echo("[FpsDoctor] Cleanup mode is now 'aggressive' by default (paced per-frame cleanup, deep clean on loading screens, engine tuning). You can pick any other mode in Mod Options at any time -- your choice will stick.")
		end
	end
	-- Migration from <=1.4.x saves. The old pacer preset wrote 150/200 into the
	-- sliders while the code silently applied 400/100 constants; the sliders are
	-- live in pacer now, so saves carrying the old placeholder pair get the real
	-- values. Old aggressive (150/300) moves to the restructured preset (700/300
	-- plus deep clean and engine tuning) -- only the exact preset pair is touched,
	-- hand-tuned values are left alone.
	local mode = mod:get("gc_mode")
	if mode == "pacer" and mod:get("gc_pause") == 150 and mod:get("gc_stepmul") == 200 then
		mod:set("gc_pause", 400, false)
		mod:set("gc_stepmul", 100, false)
		refresh_cfg()
	elseif mode == "aggressive" and mod:get("gc_pause") == 150 and mod:get("gc_stepmul") == 300 then
		mod:set("gc_pause", 700, false)
		mod:set("gc_stepmul", 300, false)
		mod:set("deep_clean", true, false)
		mod:set("engine_gc", true, false)
		refresh_cfg()
	end
	log_environment()
end

function mod.on_unload(exit_game)
	release_gui()
	restore_default_gc()
	apply_engine_gc(false)
	load_state.active = false
	set_loading_gc_boost(false)
	profiler_unwrap()
	pcall(function() Managers.frame_rate:relinquish_request("fps_doctor_loading") end)
	menu_open = false
	runaway_active = false
end

function mod.on_disabled(initial_call)
	release_gui()
	restore_default_gc()
	apply_engine_gc(false)
	load_state.active = false
	set_loading_gc_boost(false)
	profiler_unwrap()
	pcall(function() Managers.frame_rate:relinquish_request("fps_doctor_loading") end)
	-- Drop the menu latch: if the mod is toggled off while the options view is up,
	-- a stale flag would mis-tag frames after it is toggled back on.
	menu_open = false
	runaway_active = false
end

function mod.toggle_overlay()
	local v = not cfg.show_overlay
	cfg.show_overlay = v
	mod:set("show_overlay", v, true)
end

function mod.force_gc()
	do_full_collect("manual")
end

function mod.deep_clean_now()
	deep_clean("manual", false)
end

function mod.reset_stats()
	reset_diagnostics()
	if not cfg.silent then
		mod:echo("[FpsDoctor] Diagnostics reset (peak, stutters, lows).")
	end
end

-- The game caps FPS at 60 whenever any full-screen view is open (UIViewHandler
-- requests a throttled frame rate at priority 2 -- above gameplay). Returning
-- false here makes its caller relinquish the request on the next update, so the
-- lift also applies cleanly to an already-open view; turning the setting off
-- re-throttles the same way. The hook is inert unless the user opts in.
if rawget(_G, "CLASS") then
	mod:hook(CLASS.UIViewHandler, "_should_throttle_frame_rate", function(func, self, ...)
		if cfg.uncap_menus then
			return false
		end
		return func(self, ...)
	end)

	-- Two verified widget leaks in the game's own HUD. Both elements create a
	-- uniquely-named widget per entry via _create_widget (which registers it in
	-- _widgets_by_name) and remove the entry WITHOUT ever unregistering the
	-- name, so the map grows for the lifetime of the HUD: world markers (one
	-- widget per nameplate/interaction/tag/chat-bubble marker) and the combat
	-- feed (one widget per kill notification). The game itself never calls
	-- UIWidget.destroy for these widgets (HudElementBase.destroy tears down
	-- only the definitions array), and nothing anywhere reads them back by
	-- name, so removing the map entry skips no teardown -- it is exactly what
	-- the base class's own _unregister_widget_name (used by the notification
	-- feed element) exists for. Pure Lua-table bookkeeping: no engine handles
	-- involved. Hooks are inert unless the setting is on; if a patch renames
	-- these methods, the type checks skip installation entirely.
	-- BY NAME, not by table. This is the difference between a fix that runs and a
	-- fix that does not exist: HUD element classes are not in CLASS at mod load
	-- time -- they appear when the first HUD is built -- so reading
	-- CLASS.HudElementWorldMarkers here yielded nil, the type() guard below
	-- skipped installation, and this leak fix silently never installed. Three
	-- sessions of the player's logs prove it: FpsDoctor logs exactly two hooks at
	-- boot (_should_throttle_frame_rate, register_event) and never these, while
	-- Healthbars, true_level and scoreboard hook the very same classes and log
	-- "[HudElementWorldMarkers.x] needs to be delayed" -- DMF's string form, which
	-- waits for the class and then installs. The patch-safety check moves into the
	-- handler, where the method either exists or the handler returns.
	mod:hook_safe("HudElementWorldMarkers", "_unregister_marker", function(self, marker)
		if not cfg.fix_hud_leaks then return end
		if type(self._unregister_widget_name) ~= "function" then return end
		local widget = marker and marker.widget
		local name = widget and widget.name
		local by_name = name and self._widgets_by_name
		-- Identity check: only drop the entry if it still points at THIS
		-- widget, so a future rename/reuse scheme can never be broken by us.
		if by_name and by_name[name] == widget then
			self:_unregister_widget_name(name)
		end
	end)
	mod:hook("HudElementCombatFeed", "_remove_notification", function(func, self, notification_id, ...)
		-- The widget must be looked up BEFORE the original runs: the original
		-- removes the notification entry that maps id -> widget.
		local name
		if cfg.fix_hud_leaks and notification_id
				and type(self._notification_by_id) == "function"
				and type(self._unregister_widget_name) == "function" then
			local notification = self:_notification_by_id(notification_id)
			local widget = notification and notification.widget
			name = widget and widget.name
		end
		func(self, notification_id, ...)
		local by_name = name and self._widgets_by_name
		if by_name and by_name[name] then
			self:_unregister_widget_name(name)
		end
	end)

	-- A leak the game only fixes in its own automated-test build. LobbyView
	-- registers itself on Managers.event in init and unregisters in on_exit --
	-- but that unregister sits inside `if GameParameters.testify then`
	-- (lobby_view.lua:772-774), so in a retail build it never runs. The event
	-- manager tried to make this weak and got the mode wrong: it sets
	-- __mode = "v" on a table whose KEY is the object and whose value is a
	-- callback-name string (event_manager.lua:15-19), so the key is held
	-- strongly and nothing is ever collected. Every mission-board lobby the
	-- player backs out of therefore pins one whole LobbyView -- widgets,
	-- definitions, spawn slots, mission data -- for the rest of the process.
	-- The player's own logs count them at shutdown: 14, 7 and 4 leaked
	-- event_lobby_vote_started registrations in three sessions, which is memory
	-- no amount of collecting can return, and matches a floor that rises
	-- linearly with uptime through 54 full collects.
	-- What this does is byte-for-byte what the game itself does under testify,
	-- so a closed view cannot need the event, and it costs one table write per
	-- lobby close. Grouped under fix_hud_leaks: same kind of fix, same setting.
	mod:hook_safe("LobbyView", "on_exit", function(self)
		if not cfg.fix_hud_leaks then return end
		pcall(function() Managers.event:unregister(self, "event_lobby_vote_started") end)
	end)
	mod:hook_safe("ConstantElementHavocStatus", "destroy", function(self)
		if not cfg.fix_hud_leaks then return end
		pcall(function() Managers.event:unregister(self, "event_havoc_status_refreshed") end)
	end)

	-- Opt-in telemetry mute. register_event is the single funnel every gameplay
	-- telemetry event passes through before being buffered (up to 16000 events)
	-- and serialized/posted every 5 minutes; crash reporting (Crashify) is a
	-- separate system and is not affected. Muting drops the buffer growth and
	-- the periodic serialization hiccup at the cost of Fatshark not receiving
	-- this client's performance telemetry -- hence strictly opt-in, default off.
	local tm = CLASS.TelemetryManager
	if tm and type(tm.register_event) == "function" then
		mod:hook(tm, "register_event", function(func, self, ...)
			if cfg.mute_telemetry then
				return
			end
			return func(self, ...)
		end)
	end
end

refresh_cfg()
