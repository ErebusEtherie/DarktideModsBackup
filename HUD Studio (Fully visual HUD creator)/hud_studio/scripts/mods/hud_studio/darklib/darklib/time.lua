local now = os.clock

---@class DarkLib
---@field time DL_Time

local _now = now()

return function(mod)
	---@class DL_Time
	local Time = {}

	function Time.tick()
		_now = now()
	end

	function Time.now()
		return _now
	end

	return Time
end
