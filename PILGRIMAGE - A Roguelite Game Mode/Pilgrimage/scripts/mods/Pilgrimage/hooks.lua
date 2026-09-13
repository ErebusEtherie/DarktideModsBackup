-- hooks.lua
--
-- Hook plumbing. This is the very first module loaded, before bootstrap, because
-- everything else depends on it.
--
-- Two problems it solves:
--
-- 1. DMF's `hook_require(path, cb)` only fires if the game has not already required
--    that file. If it has, your callback never runs and the feature silently does
--    nothing. `hook_require_now` also fires immediately for already-loaded modules.
--
-- 2. DMF keys hook_require registrations by (path, mod_name) and SILENTLY DISCARDS
--    duplicates. So if two of our modules both hook the same engine path, one of them
--    just vanishes with no error. We detect that and hard-error at load time, naming
--    both call sites, so a silent feature disappearance becomes an obvious crash.

local M = {}

local _mod
local _callsite_by_path = {}

-- debug.getinfo walks the Lua call stack. Level 1 is this function, 2 is our caller,
-- and so on. We take the level from the caller so a wrapper function can report the
-- REAL originating line rather than itself.
local function _callsite(caller_level)
	local info = debug.getinfo(caller_level, "Sl")
	return string.format("%s:%s",
		info and info.short_src or "?",
		info and info.currentline or 0)
end

local function _record(path, caller_level)
	local here = _callsite(caller_level)
	local first = _callsite_by_path[path]
	if first then
		error(string.format(
			"Pilgrimage: duplicate hook_require for %s at %s (first registered at %s). " ..
			"DMF silently discards the second one. Consolidate them into a single " ..
			"callback that fans out.",
			tostring(path), here, first))
	end
	_callsite_by_path[path] = here
end

-- Wrap each callback so a throw inside it is reported rather than swallowed by
-- whatever called us.
local function _run_callback(path, callback, target)
	local ok, err = pcall(callback, target)
	if not ok then
		_mod:error("Pilgrimage: hook_require callback failed for " ..
			tostring(path) .. ": " .. tostring(err))
	end
end

function M.install(mod)
	_mod = mod

	-- Keep a reference to the untouched DMF method. Guarded so a /reload does not
	-- wrap our own wrapper.
	if not mod._raw_hook_require then
		mod._raw_hook_require = mod.hook_require
	end
	local original = mod._raw_hook_require

	function mod:hook_require(path, callback, caller_level)
		_record(path, caller_level or 3)
		return original(self, path, callback)
	end

	function mod:hook_require_now(path, callback, caller_level)
		_record(path, caller_level or 3)

		local result = original(self, path, function(target)
			_run_callback(path, callback, target)
		end)

		-- package.loaded is Lua's require cache. A non-nil, non-false entry means the
		-- game already required this file, so our callback above will never fire and
		-- we have to invoke it by hand.
		local loaded = package.loaded and package.loaded[path]
		if loaded ~= nil and loaded ~= false then
			if type(loaded) ~= "table" then
				local message = "Pilgrimage: hook_require_now cached module is " ..
					type(loaded) .. " for " .. tostring(path)
				mod:error(message)
				error(message)
			end
			_run_callback(path, callback, loaded)
		end

		return result
	end
end

-- Convenience wrapper for use inside modules. The caller_level of 4 skips this
-- function's own frame so duplicate errors point at the module, not at hooks.lua.
function M.require_now(path, callback)
	if _mod.hook_require_now then
		return _mod:hook_require_now(path, callback, 4)
	end
	return _mod:hook_require(path, callback)
end

-- Idempotence guard for installing hooks onto a class or a data table.
--
-- Returns true if we have ALREADY installed on this target (so the caller should
-- bail out), false if this is the first time (and marks it).
--
-- rawget, not a plain `target[key]` lookup, is deliberate: Darktide classes have a
-- metatable with __index pointing at their base class, so a plain lookup would find
-- the PARENT's sentinel and we would skip installing on the child.
function M.claim(target, key)
	if not target then return true end
	if rawget(target, key) then return true end
	target[key] = true
	return false
end

-- Fan-out helper for engine paths that more than one of our modules cares about.
-- The entry file owns one hook_require_now per path and calls this with a list of
-- { name, fn } pairs. Each is pcall'd separately, so one broken feature does not
-- take the others down with it.
function M.fanout(path, handlers)
	M.require_now(path, function(target)
		if not target then return end
		for i = 1, #handlers do
			local entry = handlers[i]
			local ok, err = pcall(entry[2], target)
			if not ok then
				_mod:error(string.format(
					"Pilgrimage: %s hook install failed for %s: %s",
					tostring(entry[1]), tostring(path), tostring(err)))
			end
		end
	end)
end

return M
