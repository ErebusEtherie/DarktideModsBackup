-- @Author: 我是派蒙啊
-- @Date:   2024-06-15 12:43:08
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-10-22 13:53:28
local mod = get_mod("PlasmaGunLagFix")

local skip = {
	OveheatDebug = true,
	CharacterSheet = true,
	PresenceManager = true,
	PlayerUnitDataExtension = true,
	PlayerUnitVisualLoadoutExtension = true,
}

local nolog = function (f, name, ...)
	if skip[name] then return end
	return f(name, ...)
end

local OLog = {}

OLog.info = Log.info
OLog.error = Log.error
OLog.exception = Log.exception
OLog.print_exception = Crashify.print_exception

Log.info = function (...)
	nolog(OLog.info, ...)
end
Log.error = function (...)
	nolog(OLog.error, ...)
end
Log.exception = function (...)
	nolog(OLog.exception, ...)
end
Crashify.print_exception = function (...)
	nolog(OLog.print_exception, ...)
end