---@class DarkLib
---@field file DL_File

---@param mod mod
return function(mod)
	---@class DL_File
	local File = {}

	local _io = Mods.lua.io
	local _os = Mods.lua.os

	local _mod_directory = ".\\..\\mods\\"

	---@type table<string, boolean>
	local ensured = {}

	---@param path string?
	---@return string?
	function File.sanitize_path(path)
		if not path then
			return path
		end

		return (path:gsub("/+", "\\"):gsub("\\+$", ""))
	end

	---@param path string
	---@return boolean
	---@return string? err
	function File.exists(path)
		path = File.sanitize_path(path)
		local ok, err, code = _os.rename(path, path)
		if not ok then
			if code == 13 then
				return true
			end
			return false, err
		end
		return true
	end

	---@param path string
	---@return boolean
	function File.is_dir(path)
		return (File.exists(File.sanitize_path(path) .. "\\"))
	end

	---@param path string?
	---@return boolean
	function File.is_file_path(path)
		local last = tostring(path or ""):match("[^\\/]+$")
		return last ~= nil and last:find("%.[^%.]+$") ~= nil
	end

	---@param path string
	---@return string
	function File.dir_of(path)
		local sanitized = File.sanitize_path(path)
		if not File.is_file_path(sanitized) then
			return sanitized
		end
		return sanitized:match("^(.*)\\[^\\]*$") or sanitized
	end

	---@param path string
	---@return boolean
	function File.file_exists(path)
		local f = _io.open(File.sanitize_path(path), "r")
		if f == nil then
			return false
		end
		_io.close(f)
		return true
	end

	---@param dir string
	function File.ensure_dir(dir)
		local win_path = File.sanitize_path(dir)
		if ensured[win_path] then
			return
		end
		if not File.exists(win_path) then
			_os.execute('mkdir "' .. win_path .. '"')
		end
		ensured[win_path] = true
	end

	---@param path string
	---@return string? text
	---@return string? reason
	function File.read(path)
		local f = _io.open(File.sanitize_path(path), "r")
		if not f then
			return nil, "no such file"
		end
		local text = f:read("*all")
		f:close()
		return text
	end

	---@param path string
	---@param text string
	---@param mode "w"|"a"|nil
	---@return boolean ok
	---@return string? err
	function File.write(path, text, mode)
		path = File.sanitize_path(path)
		if path then

			File.ensure_dir(File.dir_of(path))
		end
		local f, err = _io.open(path, mode or "w")
		if not f then
			return false, err
		end
		f:write(text)
		f:close()
		return true
	end

	---@param path string
	---@param text string
	---@return boolean ok
	---@return string? err
	function File.append(path, text)
		return File.write(path, text, "a")
	end

	---@param base string  already ends in "\"
	---@param path string?
	---@return string
	local function resolved(base, path)
		if path == nil or path == "" then
			return base
		end

		local full = File.sanitize_path(base .. path)
		return File.is_file_path(full) and full or (full .. "\\")
	end

	---@param path string?
	---@return string
	function File.appdata(path)
		return resolved(_os.getenv("APPDATA") .. "\\Fatshark\\Darktide\\" .. mod:get_name() .. "\\", path)
	end

	---@param path string?
	---@return string
	function File.mods(path)
		return resolved(_mod_directory, path)
	end

	---@param format string?  defaults to "%Y-%m-%d_%H-%M-%S"
	---@return string?
	function File.stamp(format)
		if type(_os.date) ~= "function" then
			return nil
		end
		local ok, stamp = pcall(_os.date, format or "%Y-%m-%d_%H-%M-%S")
		if ok and type(stamp) == "string" then
			return stamp
		end
		return nil
	end

	return File
end
