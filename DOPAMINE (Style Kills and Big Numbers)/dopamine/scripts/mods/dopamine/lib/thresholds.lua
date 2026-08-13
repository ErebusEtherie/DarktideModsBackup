
---@param mod mod
return function(mod)
	if mod.thresholds then
		return mod.thresholds
	end

	---@class Thresholds
	local Thresholds = {}

	---@param value number|nil
	---@param tiers table[]
	---@param threshold_key string -- field naming each tier's threshold
	---@param value_key string -- field naming each tier's payload
	---@param default number -- returned when no tier is reached
	---@return number
	function Thresholds.pick(value, tiers, threshold_key, value_key, default)
		local result = default

		for i = 1, #tiers do
			local tier = tiers[i]
			if (value or 0) >= tier[threshold_key] then
				result = tier[value_key]
			end
		end

		return result
	end

	mod.thresholds = Thresholds

	return mod.thresholds
end
