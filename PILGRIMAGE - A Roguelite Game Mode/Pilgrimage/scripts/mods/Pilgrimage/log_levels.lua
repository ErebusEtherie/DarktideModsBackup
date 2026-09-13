-- log_levels.lua
--
-- Severity ladder for diagnostics. Kept as its own tiny module so both the entry
-- file and the options file can read it without pulling in anything heavier.
--
-- "off" is level 0. A call is emitted when its own level is at or below the active
-- level, so setting "trace" shows everything and "info" shows only the important
-- lines.

local M = {}

local LEVELS = {
	info  = 1,
	debug = 2,
	trace = 3,
}

M.LEVELS = LEVELS

M.OPTIONS = {
	{ text = "log_level_off",   value = "off" },
	{ text = "log_level_info",  value = "info" },
	{ text = "log_level_debug", value = "debug" },
	{ text = "log_level_trace", value = "trace" },
}

-- Turn whatever is stored in settings into a number.
-- `true` is accepted for backwards compatibility in case this ever started life as
-- a checkbox, which is exactly the migration BetterBots had to do.
function M.resolve_setting(value)
	if value == true then return LEVELS.debug end
	if type(value) ~= "string" then return 0 end
	return LEVELS[value] or 0
end

function M.should_log(active_level, call_level)
	if not active_level or active_level <= 0 then return false end
	local wanted = LEVELS[call_level or "debug"] or LEVELS.debug
	return wanted <= active_level
end

return M
