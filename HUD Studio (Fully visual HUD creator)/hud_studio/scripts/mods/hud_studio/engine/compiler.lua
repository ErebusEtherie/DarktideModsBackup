---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_compiler then
	return mod.hud_studio_compiler
end

local _loadstring = Mods.lua.loadstring
local setfenv = setfenv

---@class Compiler
local Compiler = {}

---@type table<table, table<string, function>>
local env_caches = setmetatable({}, { __mode = "k" })
---@type table<string, function>
local unbound_cache = {}

local function cache_for(env)
	if not env then
		return unbound_cache
	end
	local bucket = env_caches[env]
	if not bucket then
		bucket = {}
		env_caches[env] = bucket
	end
	return bucket
end

---@param source string        raw expression text (a function body)
---@param chunk_name string?   name surfaced in error messages
---@param env table?           the sandbox env this chunk will be bound to (see the cache note)
---@return function? fn         compiled chunk, or nil on syntax error
---@return string? err          loadstring's error message when fn is nil
function Compiler.compile(source, chunk_name, env)
	local cache = cache_for(env)
	local cached = cache[source]
	if cached then
		return cached
	end

	local fn, err = _loadstring(source, chunk_name or "hud_studio_expression")
	if not fn then
		return nil, err
	end

	cache[source] = fn
	return fn
end

---@param fn function
---@param env table
---@return function fn  the same chunk, now bound to env
function Compiler.bind(fn, env)
	return setfenv(fn, env)
end

function Compiler.clear()
	env_caches = setmetatable({}, { __mode = "k" })
	unbound_cache = {}
end

mod.hud_studio_compiler = Compiler

return Compiler
