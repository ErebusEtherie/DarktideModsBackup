---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_sandbox then
	return mod.hud_studio_sandbox
end

local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")

---@class Sandbox
local Sandbox = {}

local SAFE_GLOBALS = {
	math = math,
	string = string,
	table = table,
	tostring = tostring,
	tonumber = tonumber,
	pairs = pairs,
	ipairs = ipairs,
	select = select,
	type = type,

	mod = mod,

	get_mod = get_mod,

	Unit = rawget(_G, "Unit"),
	ScriptUnit = rawget(_G, "ScriptUnit"),
	Managers = rawget(_G, "Managers"),
	Color = rawget(_G, "Color"),
}

local RESERVED = {
	value = true,
	values = true,
	style = true,
	block = true,
	state = true,
	t = true,
	dt = true,
	sources = true,
}

Sandbox.RESERVED = RESERVED

local LOGGERS = {
	echo = true,
	notify = true,
	info = true,
	warning = true,
	error = true,
	debug = true,
}

local function hud_studio_log(method, prefix, fmt, ...)
	if not LOGGERS[method] then
		return
	end
	local msg
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, tostring(fmt), ...)
		msg = ok and formatted or tostring(fmt)
	else
		msg = tostring(fmt)
	end
	mod[method](mod, prefix .. " " .. msg)
end

local sources_proxy = setmetatable({}, {
	__index = function(_, id)
		return Registry.resolve(id)
	end,
})

---@return table env
function Sandbox.build()
	local env = {}
	for k, v in pairs(SAFE_GLOBALS) do
		env[k] = v
	end

	env.__hud_studio_log = hud_studio_log

	env.sources = sources_proxy

	setmetatable(env, {
		__index = function(_, key)
			return Registry.resolve(key)
		end,
	})

	return env
end

mod.hud_studio_sandbox = Sandbox

return Sandbox
