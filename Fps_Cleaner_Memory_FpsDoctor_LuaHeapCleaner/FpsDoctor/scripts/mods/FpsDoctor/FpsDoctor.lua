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
local string_format = string.format
local table_sort = table.sort
local math_floor = math.floor
local math_max = math.max

local FONT_TYPE = "arial"

local SAMPLE_MAX = 1000
local samples = {}
local sample_count = 0
local sample_idx = 1

local low_scratch = {}
local low_scratch_n = 0

local PAUSE_FRAME_S = 0.5

local draw_fail_cooldown = 0
local DRAW_FAIL_BACKOFF_FRAMES = 120

local stats = {
	fps = 0,
	avg_fps = 0,
	low_fps = 0,
	frame_ms = 0,
	heap_mb = 0,
	heap_rate = 0,
}

local one_sec = 0
local win_time = 0
local win_frames = 0
local last_heap_kb = nil

local peak_heap_mb = 0
local floor_heap_mb = 0
local mission_start_heap_mb = 0
local mission_baseline_pending = false
local mission_hitches = 0
local mission_gc_hitches = 0
local reset_acc = 0

local gc_frame_ms = 0
local GC_HITCH_ATTRIB_MS = 5

local periodic_acc = 0
local emergency_cooldown = 0
local in_gameplay = false

local gc_drain_active = false
local gc_drain_reason = nil
local gc_drain_before_mb = 0
local gc_drain_frames = 0
local GC_DRAIN_MAX_FRAMES = 1800
local DRAIN_STEP_KB = 32
local DRAIN_MAX_STEPS = 24
local FALLBACK_STEP_KB = 256

local PACER_PAUSE = 400
local PACER_STEPMUL = 100
local PACER_STEP_KB = 16
local PACER_MAX_STEPS = 8
local PACER_BUDGET_IDLE_MULT = 3
local PACER_SPIKE_MULT = 1.5
local PACER_HEADROOM_MB = 24
local pacer_resume_mb = 0
local emergency_floor_mb = 0

local SOFT_THRESHOLD_FRAC = 0.75
local ADAPTIVE_RATE_MB_MIN = 8.0
local EMERGENCY_COOLDOWN_S = 60
local EMERGENCY_REARM_MB   = 64
local PERIODIC_MIN_GROWTH_MB = 32
local LEAK_WATCH_MB = 120
local LEAK_LIKELY_MB = 300

local _clock = nil

local _gui = nil
local _gui_world = nil
local _font_path = nil

local cfg = {}
local CFG_KEYS = {
	"show_overlay", "show_fps", "show_low", "show_frame_ms", "show_heap",
	"show_mission", "show_hitch", "show_gc_mode", "anchor", "pos_x", "pos_y",
	"overlay_scale", "opacity_text", "opacity_bg", "hitch_ms",
	"gc_mode", "gc_pause", "gc_stepmul", "gc_budget_us", "smooth_collect",
	"periodic_minutes", "threshold_mb", "auto_reset", "auto_reset_minutes",
	"silent",
}

local line_text = {}
local line_r, line_g, line_b = {}, {}, {}
local line_count = 0
local panel_text_w = 0
local overlay_dirty = true
local rebuild_acc = 0
local REBUILD_INTERVAL = 0.25
local built_font_px = 0

-- overlay geometry/colour cache: recomputed only on the throttled rebuild, reused every frame
local cached_line_h = 0
local cached_pad = 0
local cached_a_text = 0
local cached_a_bg = 0
local cached_x = 0
local cached_top_y = 0
local cached_panel_w = 0
local cached_panel_h = 0

local function refresh_cfg()
	for i = 1, #CFG_KEYS do
		local k = CFG_KEYS[i]
		cfg[k] = mod:get(k)
	end
	overlay_dirty = true
end

local MODE_PRESETS = {
	balanced   = { gc_pause = 150, gc_stepmul = 200, gc_budget_us = 1000, periodic_minutes = 10, threshold_mb = 1024 },
	pacer      = { gc_pause = 150, gc_stepmul = 200, gc_budget_us = 500,  periodic_minutes = 10, threshold_mb = 1536 },
	aggressive = { gc_pause = 150, gc_stepmul = 300, gc_budget_us = 1500, periodic_minutes = 10, threshold_mb = 1024 },
}

local function resolve_clock()
	if _clock == nil then
		local lua_os = rawget(_G, "Mods") and Mods.lua and Mods.lua.os
		_clock = (lua_os and lua_os.clock) or (rawget(_G, "os") and os.clock) or false
	end
	return _clock
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
	local font_data = Managers.font and Managers.font:data_by_type(FONT_TYPE)
	if font_data then _font_path = font_data.path end
	return _font_path
end

local function release_gui()
	_gui = nil
	_gui_world = nil
	_font_path = nil
end

local function compute_low_fps()
	local n = sample_count
	if n < 10 then return 0 end
	local tmp = low_scratch
	for i = 1, n do tmp[i] = samples[i] end
	for i = n + 1, low_scratch_n do tmp[i] = nil end
	low_scratch_n = n
	table_sort(tmp)
	local idx = math_floor(n * 0.99)
	if idx < 1 then idx = 1 end
	if idx > n then idx = n end
	local dt99 = tmp[idx]
	if dt99 and dt99 > 0 then return 1.0 / dt99 end
	return 0
end

local function reset_diagnostics()
	local heap_kb = collectgarbage("count")
	sample_count = 0
	sample_idx = 1
	mission_hitches = 0
	mission_gc_hitches = 0
	peak_heap_mb = heap_kb / 1024.0
	mission_start_heap_mb = heap_kb / 1024.0
	mission_baseline_pending = false
	stats.low_fps = 0
	stats.heap_rate = 0
	last_heap_kb = heap_kb
	win_time = 0
	win_frames = 0
	one_sec = 0
	reset_acc = 0
	overlay_dirty = true
end

local function rate_rgb(rate)
	if rate >= 5.0 then return 255, 90, 90 end
	if rate >= 1.5 then return 255, 215, 90 end
	return 150, 230, 150
end

local function delta_rgb(mb)
	if mb >= LEAK_LIKELY_MB then return 255, 90, 90 end
	if mb >= LEAK_WATCH_MB then return 255, 215, 90 end
	return 150, 230, 150
end

local function mission_verdict(net)
	if net >= LEAK_LIKELY_MB then return "likely leak" end
	if net >= LEAK_WATCH_MB then return "watch (growing)" end
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
		local r, g, b = rate_rgb(rate)
		push_line(string_format("Lua heap  %.0f MB  (%s%.1f MB/min)", stats.heap_mb, rate >= 0 and "+" or "", rate), r, g, b)
	end

	if cfg.show_mission then
		local delta = (mission_start_heap_mb > 0) and (stats.heap_mb - mission_start_heap_mb) or 0
		local r, g, b = delta_rgb(delta)
		if floor_heap_mb > 0 then
			push_line(string_format("peak %.0f  floor %.0f  d-mission %s%.0f MB", peak_heap_mb, floor_heap_mb, delta >= 0 and "+" or "", delta), r, g, b)
		else
			push_line(string_format("peak %.0f MB   d-mission %s%.0f MB", peak_heap_mb, delta >= 0 and "+" or "", delta), r, g, b)
		end
	end

	if cfg.show_hitch then
		local hitch_s
		if mission_gc_hitches > 0 then
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
		push_line("GC mode: " .. tostring(cfg.gc_mode or "balanced"), 175, 175, 175)
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
	if overlay_dirty or rebuild_acc >= REBUILD_INTERVAL or font_px ~= built_font_px then
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

		cached_x = to_right and (sw - panel_w - margin_x) or margin_x
		if to_bottom then
			cached_top_y = sh - margin_y - n * line_h
		else
			cached_top_y = margin_y
		end
		cached_line_h = line_h
		cached_pad = pad
		cached_a_text = a_text
		cached_a_bg = a_bg
		cached_panel_w = panel_w
		cached_panel_h = n * line_h + pad * 2
	end

	local n = line_count
	if n == 0 then return end

	local pad = cached_pad
	local x = cached_x
	local top_y = cached_top_y
	local line_h = cached_line_h

	Gui.rect(
		gui,
		Vector3(x - pad, top_y - pad, 899),
		Vector2(cached_panel_w, cached_panel_h),
		Color(cached_a_bg, 12, 12, 12)
	)

	local a_text = cached_a_text
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
		draw_fail_cooldown = DRAW_FAIL_BACKOFF_FRAMES
		mod:error("overlay draw failed, backing off %d frames: %s", DRAW_FAIL_BACKOFF_FRAMES, tostring(err))
	end
end

local function do_full_collect(reason)
	local clock = resolve_clock()
	local t0 = clock and clock()
	local before = collectgarbage("count") / 1024.0
	collectgarbage("collect")
	collectgarbage("collect")
	if t0 then gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0 end
	local after = collectgarbage("count") / 1024.0
	last_heap_kb = collectgarbage("count")
	stats.heap_mb = after
	floor_heap_mb = after
	emergency_floor_mb = after
	pacer_resume_mb = after + PACER_HEADROOM_MB
	if not cfg.silent then
		mod:echo(string_format("[FpsDoctor] GC (%s): %.0f -> %.0f MB", reason, before, after))
	end
	mod:info("GC collect (%s): %.1f -> %.1f MB", reason, before, after)
end

local prev_map_floor_mb = 0
local function note_map_baseline(mb)
	if prev_map_floor_mb > 0 then
		local drift = mb - prev_map_floor_mb
		if not cfg.silent then
			mod:echo(string_format("[FpsDoctor] Floor drift since last map: %s%.0f MB", drift >= 0 and "+" or "", drift))
		end
		mod:info("Map floor drift: %+.1f MB (%.1f -> %.1f)", drift, prev_map_floor_mb, mb)
	end
	prev_map_floor_mb = mb
end

local function begin_drain(reason)
	gc_drain_active = true
	gc_drain_reason = reason
	gc_drain_before_mb = collectgarbage("count") / 1024.0
	gc_drain_frames = 0
end

-- Graduated backoff for the paced cleanup: returns a scale in (0, 1] that
-- shrinks the per-frame GC work as the current frame gets heavier, so the mod
-- naturally does LESS when the player has less headroom. 1.0 when the frame is
-- at or under the expected frame time (identical to the old full-budget path);
-- ramps to ~0 as it approaches the hard spike gate (PACER_SPIKE_MULT), which
-- still skips the work entirely. Only meaningful in-gameplay.
local function headroom_scale()
	if not in_gameplay or stats.fps <= 0 then return 1.0 end
	local expected = 1000.0 / stats.fps
	if expected <= 0 then return 1.0 end
	local ratio = stats.frame_ms / expected
	if ratio <= 1.0 then return 1.0 end
	local t = (ratio - 1.0) / (PACER_SPIKE_MULT - 1.0)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return 1.0 - t
end

local function finish_drain(completed)
	gc_drain_active = false
	local is_map_start = gc_drain_reason == "map_start"
	local after = collectgarbage("count") / 1024.0
	last_heap_kb = collectgarbage("count")
	stats.heap_mb = after
	-- Only trust `after` as a real floor when the GC cycle actually finished.
	-- map_start must always establish a floor/baseline (this is what balanced
	-- relies on), so it counts as authoritative regardless — keeping balanced's
	-- map-start path byte-for-byte identical to before.
	if completed or is_map_start then
		floor_heap_mb = after
		emergency_floor_mb = after
		pacer_resume_mb = after + PACER_HEADROOM_MB
	end
	if is_map_start and mission_baseline_pending then
		mission_start_heap_mb = after
		mission_baseline_pending = false
		note_map_baseline(after)
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
	gc_drain_reason = nil
end

local function tick_drain()
	if not gc_drain_active then return end

	if in_gameplay and stats.fps > 0 and stats.frame_ms > (1000.0 / stats.fps) * PACER_SPIKE_MULT then
		return
	end

	-- Count only frames that actually do GC work toward the max-frames cap, so
	-- spike-gated (skipped) frames do not exhaust the budget prematurely.
	gc_drain_frames = gc_drain_frames + 1

	-- The map_start drain (the only drain balanced ever runs) is deliberately
	-- left on the original full-budget, no-backoff path so balanced is unchanged.
	local is_map_start = gc_drain_reason == "map_start"

	local finished
	local clock = resolve_clock()
	if clock then
		local budget_us = cfg.gc_budget_us or 1000
		local max_steps = DRAIN_MAX_STEPS
		if not in_gameplay then
			budget_us = budget_us * PACER_BUDGET_IDLE_MULT
		elseif not is_map_start then
			local scale = headroom_scale()
			budget_us = budget_us * scale
			max_steps = math_max(1, math_floor(DRAIN_MAX_STEPS * scale + 0.5))
		end
		local budget = budget_us / 1000000.0
		local t0 = clock()
		local steps = 0
		repeat
			finished = collectgarbage("step", DRAIN_STEP_KB)
			steps = steps + 1
		until finished or steps >= max_steps or (clock() - t0) >= budget
		gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0
	else
		finished = collectgarbage("step", FALLBACK_STEP_KB)
	end

	if finished or gc_drain_frames >= GC_DRAIN_MAX_FRAMES then
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
	pacer_resume_mb = cur_mb + PACER_HEADROOM_MB
end

local function tick_pacer()
	if gc_drain_active then return end
	if in_gameplay and stats.fps > 0 and stats.frame_ms > (1000.0 / stats.fps) * PACER_SPIKE_MULT then
		return
	end
	-- Live heap read: the pacer resume gate reacts immediately instead of
	-- waiting up to ~1s for the display's heap sample to refresh.
	local live_mb = collectgarbage("count") / 1024.0
	if pacer_resume_mb > 0 and live_mb < pacer_resume_mb then return end

	local budget_us = cfg.gc_budget_us or 1000
	if not in_gameplay then
		budget_us = budget_us * PACER_BUDGET_IDLE_MULT
	end

	-- Graduated backoff: do less as the frame gets heavier (1.0 when the frame
	-- is at/under expected, so this matches the old behaviour when there is
	-- headroom). Never below one step, so a heavy map is not starved of cleanup
	-- and the threshold_mb backstop stays authoritative.
	local scale = headroom_scale()
	local max_steps = math_max(1, math_floor(PACER_MAX_STEPS * scale + 0.5))
	budget_us = budget_us * scale

	local clock = resolve_clock()
	if not clock then
		if collectgarbage("step", PACER_STEP_KB) then
			pacer_cycle_done()
		end
		return
	end

	local budget = budget_us / 1000000.0
	local t0 = clock()
	local steps = 0
	local finished
	repeat
		finished = collectgarbage("step", PACER_STEP_KB)
		steps = steps + 1
	until finished or steps >= max_steps or (clock() - t0) >= budget
	gc_frame_ms = gc_frame_ms + (clock() - t0) * 1000.0
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

local function request_collect(reason)
	if cfg.smooth_collect or in_gameplay then
		if not gc_drain_active then begin_drain(reason) end
	else
		do_full_collect(reason)
	end
end

local function manage_gc(dt)
	local mode = cfg.gc_mode or "balanced"
	if mode == "off" or mode == "map_only" then return end

	if mode == "pacer" then
		if not gc_tuned or tuned_pause ~= PACER_PAUSE or tuned_stepmul ~= PACER_STEPMUL then
			apply_tuning(PACER_PAUSE, PACER_STEPMUL)
		end
	else
		local pause = cfg.gc_pause or 150
		local stepmul = cfg.gc_stepmul or 200
		if not gc_tuned or tuned_pause ~= pause or tuned_stepmul ~= stepmul then
			apply_tuning(pause, stepmul)
		end
	end

	if mode == "balanced" then return end

	-- Live heap for the cleanup decisions below. stats.heap_mb is only sampled
	-- once per second (for the display/peak); reading collectgarbage("count")
	-- here is O(1) and lets triggers fire on the true current heap instead of
	-- data up to ~1s stale. stats.heap_mb itself is left on its display cadence.
	local live_mb = collectgarbage("count") / 1024.0

	if emergency_cooldown > 0 then emergency_cooldown = emergency_cooldown - dt end

	if mode == "aggressive" then
		periodic_acc = periodic_acc + dt
		local interval = (cfg.periodic_minutes or 10) * 60.0
		if periodic_acc >= interval then
			periodic_acc = 0
			if live_mb >= floor_heap_mb + PERIODIC_MIN_GROWTH_MB then
				emergency_cooldown = EMERGENCY_COOLDOWN_S
				request_collect("periodic")
			end
		end
	end

	if gc_drain_active or emergency_cooldown > 0 then return end

	if live_mb < emergency_floor_mb + EMERGENCY_REARM_MB then return end

	local threshold = cfg.threshold_mb or 1024
	if threshold > 0 then
		if live_mb >= threshold then
			emergency_cooldown = EMERGENCY_COOLDOWN_S
			request_collect("threshold")
		elseif live_mb >= threshold * SOFT_THRESHOLD_FRAC and stats.heap_rate >= ADAPTIVE_RATE_MB_MIN then
			emergency_cooldown = EMERGENCY_COOLDOWN_S
			request_collect("adaptive")
		end
	end
end

function mod.update(dt)
	if not mod:is_enabled() then return end
	if type(dt) ~= "number" or dt <= 0 then return end
	if dt > PAUSE_FRAME_S then
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

	if stats.frame_ms > (cfg.hitch_ms or 50) then
		mission_hitches = mission_hitches + 1
		if gc_prev_ms >= GC_HITCH_ATTRIB_MS then
			mission_gc_hitches = mission_gc_hitches + 1
		end
	end

	samples[sample_idx] = dt
	sample_idx = sample_idx + 1
	if sample_idx > SAMPLE_MAX then sample_idx = 1 end
	if sample_count < SAMPLE_MAX then sample_count = sample_count + 1 end

	one_sec = one_sec + dt
	win_time = win_time + dt
	win_frames = win_frames + 1
	if one_sec >= 1.0 then
		stats.avg_fps = (win_time > 0) and (win_frames / win_time) or 0
		win_time = 0
		win_frames = 0
		stats.low_fps = compute_low_fps()

		local heap_kb = collectgarbage("count")
		stats.heap_mb = heap_kb / 1024.0
		if stats.heap_mb > peak_heap_mb then peak_heap_mb = stats.heap_mb end
		if last_heap_kb then
			local rate = ((heap_kb - last_heap_kb) / 1024.0) / one_sec * 60.0
			stats.heap_rate = stats.heap_rate * 0.7 + rate * 0.3
		end
		last_heap_kb = heap_kb
		one_sec = 0
	end

	if cfg.auto_reset then
		reset_acc = reset_acc + dt
		if reset_acc >= (cfg.auto_reset_minutes or 10) * 60.0 then
			reset_diagnostics()
		end
	else
		reset_acc = 0
	end

	manage_gc(dt)
	tick_drain()
	if (cfg.gc_mode or "balanced") == "pacer" then
		tick_pacer()
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
	if state_name ~= "StateGameplay" then return end

	if status == "enter" then
		in_gameplay = true
		if (cfg.gc_mode or "balanced") ~= "off" then
			if cfg.smooth_collect then
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
				note_map_baseline(stats.heap_mb)
			end
		else
			mission_start_heap_mb = collectgarbage("count") / 1024.0
			mission_baseline_pending = false
		end
		mission_hitches = 0
		mission_gc_hitches = 0
		sample_count = 0
		sample_idx = 1
		win_time = 0
		win_frames = 0
		one_sec = 0
		periodic_acc = 0
		emergency_floor_mb = 0
		stats.heap_rate = 0
		last_heap_kb = collectgarbage("count")
		overlay_dirty = true
	elseif status == "exit" then
		in_gameplay = false
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
		local preset = MODE_PRESETS[mode]
		if preset then
			for id, value in pairs(preset) do
				mod:set(id, value, false)
			end
		end
	end
	refresh_cfg()
	if setting_id == "gc_mode" then
		local mode = cfg.gc_mode or "balanced"
		periodic_acc = 0
		emergency_cooldown = 0
		emergency_floor_mb = 0
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
		elseif MODE_PRESETS[mode] and not cfg.silent then
			mod:echo(string_format("[FpsDoctor] Cleanup sliders set to recommended values for '%s'", mode))
		end
	end
end

function mod.on_enabled(initial_call)
	refresh_cfg()
end

function mod.on_unload(exit_game)
	release_gui()
	restore_default_gc()
end

function mod.on_disabled(initial_call)
	release_gui()
	restore_default_gc()
end

function mod.toggle_overlay()
	local v = not cfg.show_overlay
	cfg.show_overlay = v
	mod:set("show_overlay", v, true)
end

function mod.force_gc()
	do_full_collect("manual")
end

function mod.reset_stats()
	reset_diagnostics()
	if not cfg.silent then
		mod:echo("[FpsDoctor] Diagnostics reset (peak, stutters, lows).")
	end
end

refresh_cfg()
