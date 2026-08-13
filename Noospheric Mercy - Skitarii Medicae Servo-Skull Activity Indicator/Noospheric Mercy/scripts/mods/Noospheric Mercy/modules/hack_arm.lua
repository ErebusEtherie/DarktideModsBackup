local mod = get_mod("Noospheric Mercy")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")

local debug_getinfo = debug.getinfo
local string_format = string.format

local MINIGAME_EXTENSION_PATH = "scripts/extension_systems/minigame/minigame_extension"

local EXPECTED_ARITY = {
	set_active = 2,
}

local HackArm = {}

local _active = {}
local _broken = false
local _broken_reason = nil
local _checked = false

local function check_signatures(cls)
	for name, want in pairs(EXPECTED_ARITY) do
		local fn = cls[name]

		if type(fn) ~= "function" then
			return false, string_format("MinigameExtension.%s missing", name)
		end

		local info = debug_getinfo(fn, "u")

		if info and info.nparams and not info.isvararg and info.nparams ~= want then
			return false, string_format("MinigameExtension.%s arity %d (expected %d)", name, info.nparams, want)
		end
	end

	return true
end

function HackArm.register()
	if _checked then
		return
	end

	_checked = true

	local ok_require, MinigameExtension = pcall(require, MINIGAME_EXTENSION_PATH)

	if not ok_require or type(MinigameExtension) ~= "table" then
		_broken = true
		_broken_reason = "MinigameExtension module not found"
		mod:error(string_format("hack-detection API missing (%s); running always-on fallback, update the mod", _broken_reason))

		return
	end

	local ok_sig, reason = check_signatures(MinigameExtension)

	if not ok_sig then
		_broken = true
		_broken_reason = reason
		mod:error(string_format("hack-detection API changed (%s); running always-on fallback, update the mod", reason))

		return
	end

	mod:hook_safe(MinigameExtension, "set_active", function(self, enabled)
		local unit = self._unit

		if unit then
			_active[unit] = enabled and true or nil
		end
	end)

	Log.write("HACK arm hook attached (MinigameExtension.set_active)")
end

function HackArm.is_active()
	return next(_active) ~= nil
end

function HackArm.is_broken()
	return _broken
end

function HackArm.broken_reason()
	return _broken_reason
end

function HackArm.reset()
	for k in pairs(_active) do
		_active[k] = nil
	end
end

return HackArm
