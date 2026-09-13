-- event_log.lua
--
-- Structured diagnostics as newline-delimited JSON, written into the mod's own
-- folder: mods/Pilgrimage/events_<timestamp>.jsonl
--
-- Rewritten for v0.3.0 after verifying the install. The v0.1 version wrote to
-- "./dump/" (a directory that does not exist and could not be created) and refused
-- to start without cjson (which is not present). It produced nothing. See fileio.lua
-- for the full findings.
--
-- Now: fileio owns the path and the JSON encoding, so this file only handles
-- buffering, flush policy and session lifecycle. It has no external dependency and
-- cannot silently disable itself.
--
-- Flush policy: whichever comes first, 200 buffered events or 10 seconds. The
-- buffer is ALWAYS cleared after a flush attempt, even a failed one, so a
-- permanently unwritable disk costs us events rather than unbounded memory.

local M = {}

local _mod
local _shared
local _fileio

local _enabled = false
local _file_name = nil

local _buffer = {}
local _last_flush_t = 0
local _flush_interval_s = 10
local _flush_max_events = 200

local _sequence = 0
local _write_failures = 0

-- Forward declarations. Lua resolves locals by position in the file, so anything
-- defined below is nil to code above it. This exact mistake shipped in v0.1.1 and
-- would have crashed on disabling the log.
local _flush
local _open

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_fileio = deps.fileio
end

function M.is_available()
	return _fileio.available()
end

function M.is_enabled()
	return _enabled and _fileio.available()
end

function M.next_id()
	_sequence = _sequence + 1
	return _sequence
end

function M.file_name()
	return _file_name
end

_open = function()
	-- Wall clock, because fixed-frame sim time restarts at zero every mission and
	-- would collide across sessions.
	_file_name = "events_" .. tostring(_fileio.epoch()) .. ".jsonl"
end

_flush = function()
	if #_buffer == 0 or not _file_name then return end

	local lines = {}
	local dropped = 0

	for i = 1, #_buffer do
		local encoded, err = _fileio.encode_json(_buffer[i])
		if encoded then
			lines[#lines + 1] = encoded
		else
			dropped = dropped + 1
			-- Keep a breadcrumb rather than losing the fact entirely.
			lines[#lines + 1] = '{"event":"encode_failure","detail":"' ..
				tostring(err):gsub('"', "'") .. '"}'
		end
	end

	local ok, err = _fileio.append(_file_name, lines)
	if not ok then
		_write_failures = _write_failures + 1
	end

	-- Unconditional, so memory stays bounded even if every write fails.
	_buffer = {}
end

function M.set_enabled(enabled)
	local was_enabled = _enabled
	_enabled = enabled == true

	if _enabled and not was_enabled then
		M.ensure_session()
	elseif was_enabled and not _enabled then
		_flush()
		_file_name = nil
	end
end

-- Open a file if one is not already open. Safe to call repeatedly.
function M.ensure_session(t, extra)
	if not M.is_enabled() then return false end
	if _file_name then return false end
	M.start_session(t or _shared.fixed_time(), extra)
	return true
end

function M.emit(event)
	if not M.is_enabled() then return end
	if type(event) ~= "table" then return end

	_buffer[#_buffer + 1] = event

	if #_buffer >= _flush_max_events then
		_flush()
	end
end

function M.try_flush(t)
	if not M.is_enabled() then return end
	if #_buffer == 0 then return end
	if t - _last_flush_t < _flush_interval_s then return end
	_last_flush_t = t
	_flush()
end

function M.start_session(t, extra)
	if not M.is_enabled() then return end

	-- Flush the outgoing session before repointing at a new file, or its tail is
	-- orphaned in the buffer.
	if _file_name and #_buffer > 0 then
		_flush()
	end

	_open()
	_last_flush_t = t or 0
	_sequence = 0

	local event = {
		t = t or 0,
		wall = _fileio.timestamp(),
		event = "session_start",
		mod_version = _mod.version,
		game_mode = _shared.game_mode_name(),
		solo_host = _shared.is_solo_host(),
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do event[k] = v end
	end
	M.emit(event)

	-- Write immediately so the file exists on disk the moment logging is on, rather
	-- than only after the first flush interval. Makes "did it work" answerable.
	_flush()
end

function M.end_session(t)
	if not M.is_enabled() then return end
	M.emit({
		t = t or 0,
		wall = _fileio.timestamp(),
		event = "session_end",
		write_failures = _write_failures,
	})
	_flush()
	_file_name = nil
end

function M.stats()
	return {
		enabled = M.is_enabled(),
		available = M.is_available(),
		file = _file_name,
		buffered = #_buffer,
		sequence = _sequence,
		write_failures = _write_failures,
	}
end

return M
