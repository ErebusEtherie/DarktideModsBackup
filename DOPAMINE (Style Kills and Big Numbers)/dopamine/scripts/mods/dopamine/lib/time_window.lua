

---@param mod mod
return function(mod)
	if mod.time_window then
		return mod.time_window
	end

	---@class TimeWindow
	local TimeWindow = {}

	---@param window number[] -- ascending timestamps; mutated in place
	---@param timestamp number -- the new (latest) timestamp
	---@param max_age number -- window length in the same unit as the timestamps
	---@return integer count
	function TimeWindow.push(window, timestamp, max_age)
		window[#window + 1] = timestamp

		local cutoff = timestamp - max_age
		local write_index = 1

		for read_index = 1, #window do
			if window[read_index] >= cutoff then
				window[write_index] = window[read_index]
				write_index = write_index + 1
			end
		end

		for i = write_index, #window do
			window[i] = nil
		end

		return #window
	end

	mod.time_window = TimeWindow

	return mod.time_window
end
