-- perf.lua
--
-- A tag-bucketed wall-clock profiler. Off by default, driven by a mod setting.
--
-- The point of this file is to make "is this fast enough" a question with an answer
-- instead of a guess. Every piece of per-frame work in the mod gets wrapped like:
--
--     local t0 = Perf.begin()
--     do_the_work()
--     Perf.finish("run_controller.tick", t0)
--
-- When profiling is off, `begin` returns nil immediately and `finish` bails on the
-- nil, so the cost of leaving instrumentation in permanently is two function calls.
--
-- Results are normalised to microseconds per frame, which is the number that actually
-- correlates with a framerate drop.

local M = {}

local _mod
local _shared

local _enabled = false
local _setting_id = "enable_perf"

local _tag_stats = {}
local _total_s = 0
local _total_calls = 0
local _frames = 0

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	M.sync_setting()
end

function M.sync_setting()
	if not _mod then return end
	_enabled = _mod:get(_setting_id) == true
end

function M.is_enabled()
	return _enabled
end

function M.reset()
	_tag_stats = {}
	_total_s = 0
	_total_calls = 0
	_frames = 0
end

-- Called once at mission start. Re-reads the setting so toggling it between missions
-- takes effect, and clears counters so each mission is measured on its own.
function M.enter_run()
	M.sync_setting()
	M.reset()
end

function M.mark_frame()
	if not _enabled then return end
	_frames = _frames + 1
end

function M.begin()
	if not _enabled then return nil end
	return os.clock()
end

-- opts.include_total = false marks this as a CHILD span: it still gets its own line
-- in the report, but is not added to the grand total. Without this, a function and
-- the things it calls would both be counted and the total would be meaningless.
function M.finish(tag, start_clock, elapsed_s, opts)
	if not tag then return end
	if not start_clock and not elapsed_s then return end

	local duration_s = elapsed_s or (os.clock() - start_clock)

	local stats = _tag_stats[tag]
	if not stats then
		stats = { total_s = 0, calls = 0 }
		_tag_stats[tag] = stats
	end
	stats.total_s = stats.total_s + duration_s
	stats.calls = stats.calls + 1

	if not (opts and opts.include_total == false) then
		_total_s = _total_s + duration_s
		_total_calls = _total_calls + 1
	end
end

-- Convenience wrapper for one-off measurement of a whole call.
function M.measure(tag, fn, ...)
	if not _enabled then return fn(...) end
	local t0 = os.clock()
	local a, b, c = fn(...)
	M.finish(tag, t0)
	return a, b, c
end

function M.report()
	local tags = {}
	for tag, stats in pairs(_tag_stats) do
		tags[#tags + 1] = {
			tag = tag,
			total_s = stats.total_s,
			calls = stats.calls,
			us_per_call = stats.calls > 0 and (stats.total_s / stats.calls * 1e6) or 0,
		}
	end

	-- Sort by cost descending, ties broken by name, so two reports from two runs can
	-- be diffed against each other.
	table.sort(tags, function(a, b)
		if a.total_s == b.total_s then return a.tag < b.tag end
		return a.total_s > b.total_s
	end)

	return {
		frames = _frames,
		total_calls = _total_calls,
		total_ms = _total_s * 1000,
		us_per_frame = _frames > 0 and (_total_s / _frames * 1e6) or nil,
		tags = tags,
	}
end

function M.format_report(prefix)
	prefix = prefix or "Pilgrimage perf:"
	local report = M.report()
	local lines = {}

	if report.us_per_frame then
		lines[#lines + 1] = string.format(
			"%s %.1f us/frame total (%d frames, %d calls, %.3f ms total)",
			prefix, report.us_per_frame, report.frames, report.total_calls, report.total_ms)
	else
		lines[#lines + 1] = string.format(
			"%s no frames sampled (%d calls, %.3f ms total)",
			prefix, report.total_calls, report.total_ms)
	end

	for i = 1, #report.tags do
		local entry = report.tags[i]
		lines[#lines + 1] = string.format(
			"  %s  %.3f ms total (%d calls, %.1f us/call)",
			entry.tag, entry.total_s * 1000, entry.calls, entry.us_per_call)
	end

	return lines
end

function M.echo_report()
	if not _enabled then
		_mod:echo("Pilgrimage: profiling is off (enable it in mod options).")
		return
	end
	local lines = M.format_report()
	for i = 1, #lines do
		_mod:echo(lines[i])
	end
end

return M
