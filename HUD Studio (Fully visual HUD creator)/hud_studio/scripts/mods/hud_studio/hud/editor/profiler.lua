---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_profiler then
	return mod.hud_studio_profiler
end

local Block = mod:core(mod.hud_studio_block, "blocks/block")

---@class Profiler
local Profiler = {}

local PROFILE_WINDOW = 180

local clock = os.clock

local profiling = false
local profile_frames = 0
local profile_total = 0
local profile_nodes = 0
local profile_kb = 0
local profile_armed = 0

local profile_draw_total = 0
local profile_draw_kb = 0

local profile_providers = 0
local provider_baseline = 0

local EMPTY_STATS = { provider_runs = 0 }

local eval_started, eval_heap = nil, nil
local draw_started, draw_heap = nil, nil

---@return boolean
function Profiler.enabled()
	return profiling
end

---@param evaluated table<integer, table|false|nil>
---@param count integer  number of blocks, i.e. the range to walk
---@return integer
local function node_count(evaluated, count)
	local n = 0
	for i = 1, count do
		local ev = evaluated[i]
		if type(ev) == "table" then
			n = n + #ev
		end
	end
	return n
end

local function reset()
	profile_frames, profile_total, profile_nodes, profile_kb, profile_armed = 0, 0, 0, 0, 0
	profile_draw_total, profile_draw_kb = 0, 0
	profile_providers = 0
	provider_baseline = (mod.hud_studio_source_stats or EMPTY_STATS).provider_runs
end

local function report()
	local mean_ms = (profile_total / profile_frames) * 1000
	local mean_nodes = profile_nodes / profile_frames
	local draw_ms = (profile_draw_total / profile_frames) * 1000
	mod.dl.log.echo(
		"[profile] eval %.3f ms + draw %.3f ms = %.3f ms/frame | %.1f nodes (%.2f us/node) | %.1f providers/frame | %.1f + %.1f KB/frame | armed %d%% of %d frames",
		mean_ms,
		draw_ms,
		mean_ms + draw_ms,
		mean_nodes,
		mean_nodes > 0 and ((mean_ms + draw_ms) * 1000 / mean_nodes) or 0,
		profile_providers / profile_frames,
		profile_kb / profile_frames,
		profile_draw_kb / profile_frames,
		(profile_armed / profile_frames) * 100,
		profile_frames
	)
	reset()
end

function Profiler.eval_begin()
	if not profiling then
		return
	end
	eval_started = clock()
	eval_heap = collectgarbage("count")
end

---@param evaluated table<integer, table|false|nil>
---@param count integer
function Profiler.eval_end(evaluated, count)
	if not profiling or not eval_started then
		return
	end

	local kb = collectgarbage("count") - eval_heap
	local elapsed = clock() - eval_started
	eval_started = nil

	profile_frames = profile_frames + 1
	profile_total = profile_total + elapsed
	profile_nodes = profile_nodes + node_count(evaluated, count)
	profile_kb = profile_kb + (kb > 0 and kb or 0)

	local source_stats = mod.hud_studio_source_stats
	if source_stats then
		profile_providers = profile_providers + (source_stats.provider_runs - provider_baseline)
		provider_baseline = source_stats.provider_runs
	end
	if Block.budget_armed() then
		profile_armed = profile_armed + 1
	end
	if profile_frames >= PROFILE_WINDOW then
		report()
	end
end

function Profiler.draw_begin()
	if not profiling then
		return
	end
	draw_started = clock()
	draw_heap = collectgarbage("count")
end

function Profiler.draw_end()
	if not profiling or not draw_started then
		return
	end
	local kb = collectgarbage("count") - draw_heap
	profile_draw_total = profile_draw_total + (clock() - draw_started)
	profile_draw_kb = profile_draw_kb + (kb > 0 and kb or 0)
	draw_started = nil
end

local _active_reference = nil

mod:command("hud_studio_profile", "toggle HUD Studio block-evaluation profiling", function(reference)
	profiling = not profiling
	reset()
	eval_started, draw_started = nil, nil

	if profiling then
		_active_reference = reference
	end

	Block.audit_scratch(profiling)
	mod.dl.log.echo(
		"[profile]%s evaluate + draw profiling, scratch audit %s",
		(_active_reference and string.format(" [%s]", _active_reference) or ""),
		(profiling and "ON" or "OFF")
	)
	if not profiling then
		_active_reference = nil
	end
end)

mod.hud_studio_profiler = Profiler

return Profiler
