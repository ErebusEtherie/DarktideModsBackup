---@class DarkLib
---@field debug DL_Debug

---@param mod mod
return function(mod)
	---@class DL_Debug
	local Debugger = {}

	local _dumped_once = {}

	Debugger.dump_once = function(key, data)
		if _dumped_once[key] then
			return
		end

		mod:echo("DUMP: " .. key)
		mod:dump(data)

		_dumped_once[key] = true
	end

	return Debugger
end
