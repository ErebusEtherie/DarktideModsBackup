local mod = get_mod("Noospheric Mercy")

local Settings = {}

local KEYS = {
	"broadcast_enabled",
	"broadcast_only_when_multiple",
	"show_others",
	"rescue_marker_enabled",
	"hack_marker_enabled",
	"outline_priority",
	"verbose_logging",
}

local _values = mod:persistent_table("noospheric_mercy_settings_cache", {})

function Settings.refresh()
	for i = 1, #KEYS do
		local key = KEYS[i]
		_values[key] = mod:get(key)
	end
end

function Settings.get(key)
	return _values[key]
end

Settings.refresh()

return Settings
