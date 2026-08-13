---@class DarkLib
---@field settings DL_Settings

---@param mod mod
return function(mod)
	---@class DL_Settings : DL_ModSettings
	local Settings = {}

	---@class DL_SettingsDefaults : DL_ModSettings
	Settings.defaults = {}

	---@type table<string, any>
	local _cache = {}
	---@type table<string, fun(): any>
	local _derived = {}

	---@param callback fun(setting_id: string): any
	Settings.hook_settings_changed = function(callback)
		if type(callback) ~= "function" then
			return
		end

		local existing_callback = mod.on_setting_changed

		mod.on_setting_changed = function(setting_id)
			callback(setting_id)
			if existing_callback then
				existing_callback(setting_id)
			end
		end
	end

	---@param defaults table
	Settings.register_defaults = function(defaults)
		if type(defaults) == "table" then
			Settings.defaults = defaults
		end
	end

	Settings.invalidate_settings = function()
		for key in pairs(_cache) do
			_cache[key] = nil
		end
	end

	---@param key string
	---@param resolver fun(): any
	Settings.derive = function(key, resolver)
		_derived[key] = resolver
	end

	---@param prefix string
	---@return number[]
	Settings.color = function(prefix)
		return {
			Settings[prefix .. "_A"],
			Settings[prefix .. "_R"],
			Settings[prefix .. "_G"],
			Settings[prefix .. "_B"],
		}
	end

	Settings.hook_settings_changed(function(setting_id)
		_cache[setting_id] = nil
		for key in pairs(_derived) do
			_cache[key] = nil
		end
	end)

	local function is_color_default(value)
		return type(value) == "table" and type(value[1]) == "number"
	end

	local function resolve(name)
		local derive = _derived[name]
		if derive then
			local derived_value = derive()

			return derived_value
		end

		local default = Settings.defaults[name]
		local live_value = mod:get(name)
		local value

		if is_color_default(default) then
			if type(live_value) == "string" and live_value ~= "" then
				value = mod.dl.colors.from_string(live_value) or mod.dl.colors.to_argb(255, default)
			else
				value = mod.dl.colors.to_argb(255, default)
			end

		elseif live_value == nil or (live_value == "" and type(default) == "string") then
			value = default

		elseif default ~= nil and type(live_value) ~= type(default) then
			mod.dl.report(
				"settings",
				"resolve",
				0,
				("setting '%s' is %s, expected %s (from default) - using default"):format(
					name,
					type(live_value),
					type(default)
				)
			)
			value = default
		else
			value = live_value
		end

		return value
	end

	setmetatable(Settings, {
		__index = function(_, name)

			local cached = _cache[name]
			if cached ~= nil then
				return cached
			end

			local value = resolve(name)
			_cache[name] = value
			return value
		end,
	})

	return Settings
end
