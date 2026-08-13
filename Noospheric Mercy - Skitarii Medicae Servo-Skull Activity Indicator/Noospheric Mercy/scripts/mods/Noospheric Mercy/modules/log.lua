local mod = get_mod("Noospheric Mercy")
local Settings = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/settings")

local Log = {}

local string_format = string.format

local function now()
	local time_manager = Managers.time

	if time_manager and time_manager.has_timer and time_manager:has_timer("gameplay") then
		return time_manager:time("gameplay")
	end

	return 0
end

function Log.enabled()
	return Settings.get("verbose_logging")
end

function Log.write(message, ...)
	if not Settings.get("verbose_logging") then
		return
	end

	if select("#", ...) > 0 then
		local ok, formatted = pcall(string_format, message, ...)
		message = ok and formatted or message
	end

	mod:info(string_format("[t=%.2f] %s", now(), tostring(message)))
end

return Log
