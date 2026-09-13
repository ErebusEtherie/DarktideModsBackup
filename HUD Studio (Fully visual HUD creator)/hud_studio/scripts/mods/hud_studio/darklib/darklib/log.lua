---@class DarkLib
---@field log DL_Log

---@param mod mod
return function(mod)
	---@class DL_Log
	local Log = {}

	local File = mod.dl.file

	---@type string?
	local log_path = nil
	local started = false

	---@return string
	function Log.path()
		if log_path == nil then
			log_path = File.appdata("logs\\" .. (File.stamp() or "session") .. ".txt")
		end
		return log_path
	end

	---@param message string
	---@param ... any  string.format arguments
	function Log.write(message, ...)
		local text = message
		if select("#", ...) > 0 then
			local ok, formatted = pcall(string.format, message, ...)
			text = ok and formatted or tostring(message)
		end

		local time = File.stamp("%H:%M:%S")
		local line = (time and ("[" .. time .. "] ") or "") .. tostring(text) .. "\n"

		local path = Log.path()
		if not started then
			started = true

			line = ("=== " .. mod:get_name() .. " log, " .. (File.stamp() or "unknown time") .. " ===\n") .. line
		end

		local ok, err = File.append(path, line)
		if not ok then

			mod:error("[DarkLib | log] could not write %s: %s", tostring(path), tostring(err))

			mod:echo("%s", tostring(text))
		end
	end

	local format_debug = function(message, ...)
		local text = message
		if select("#", ...) > 0 then
			local ok, formatted = pcall(string.format, message, ...)
			text = ok and formatted or tostring(message)
		end
		return tostring(text)
	end

	---@param message string
	---@param ... any
	function Log.echo(message, ...)
		local text = format_debug(message, ...)
		mod:echo("%s", text)
		Log.write(text)
	end

	---@param message string
	---@param ... any
	function Log.info(message, ...)
		local text = format_debug(message, ...)
		mod:info("%s", text)
		Log.write(text)
	end

	---@param message string
	---@param ... any
	function Log.notify(message, ...)
		local text = format_debug(message, ...)
		mod:notify("%s", text)
		Log.write(text)
	end

	---@param message string
	---@param ... any
	function Log.error(message, ...)
		local text = format_debug(message, ...)
		mod:error("%s", text)
		Log.write("[error] " .. text)
	end

	return Log
end
