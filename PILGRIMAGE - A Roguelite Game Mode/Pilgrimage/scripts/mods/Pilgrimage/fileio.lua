-- fileio.lua
--
-- The single file-writing path for the whole mod, and a JSON encoder with no
-- external dependency.
--
-- ===========================================================================
-- WHY THIS FILE EXISTS, AND WHY THE EARLIER APPROACH WAS WRONG
-- ===========================================================================
--
-- Verified on Kaizen's install, 2026-08-04:
--
--   1. ALL DMF LOGGING IS DISABLED. user_settings.config has
--      logging_mode = "custom" with every output_mode_* set to 0. Reading DMF's
--      logging.lua, 0 means "Disabled" in its lookup table, so mod:echo, mod:info,
--      mod:warning, mod:error, mod:notify and mod:debug are ALL silent no-ops.
--      Not just for this mod. For every mod on the machine. That is why nothing
--      has ever printed.
--
--   2. THERE IS NO ./dump/ DIRECTORY and os.execute("mkdir dump") did not create
--      one. The earlier event log wrote to "./dump/pilgrimage_events_*.jsonl" and
--      therefore wrote nothing at all.
--
--   3. cjson IS NOT PRESENT. It appears nowhere in DMF and nothing on this install
--      uses it. The earlier event log refused to start without it, which was the
--      second reason it produced no output.
--
--   4. THE WORKING PATH IS "./../mods/<ModName>/<file>". Proven by files already on
--      disk: mods/FrameBench/bench_016_auto.txt and mods/DualSenseRumbleFix/
--      ds_diag.txt were both written this way. The game's working directory is the
--      binaries folder, so "./../mods" reaches the mod root. DMF's own io.lua
--      hardcodes exactly this: local _mod_directory = "./../mods".
--
-- So: write into our own mod folder, which already exists so no mkdir is needed,
-- and encode JSON ourselves.

local M = {}

local _mod

-- Trailing slash omitted deliberately; M.path adds it.
local MOD_DIR = "./../mods/Pilgrimage"

M.MOD_DIR = MOD_DIR

local function io_lib()
	local Mods = rawget(_G, "Mods")
	return Mods and Mods.lua and Mods.lua.io or nil
end

local function os_lib()
	local Mods = rawget(_G, "Mods")
	return Mods and Mods.lua and Mods.lua.os or nil
end

function M.available()
	return io_lib() ~= nil
end

function M.path(name)
	return MOD_DIR .. "/" .. tostring(name)
end

-- Wall-clock timestamp for log lines and filenames. Fixed-frame time resets every
-- mission so it is useless for either.
function M.timestamp()
	local os_l = os_lib()
	if os_l and os_l.date then
		local ok, text = pcall(os_l.date, "%Y-%m-%d %H:%M:%S")
		if ok and text then return text end
	end
	if os_l and os_l.time then
		local ok, value = pcall(os_l.time)
		if ok then return tostring(value) end
	end
	return "?"
end

function M.epoch()
	local os_l = os_lib()
	if os_l and os_l.time then
		local ok, value = pcall(os_l.time)
		if ok then return value end
	end
	return 0
end

-- Accepts a string or an array of lines.
local function to_text(content)
	if type(content) == "table" then
		local parts = {}
		for i = 1, #content do parts[i] = tostring(content[i]) end
		return table.concat(parts, "\n") .. "\n"
	end
	return tostring(content)
end

local function open_and_write(name, mode, content)
	local io_l = io_lib()
	if not io_l then return false, "Mods.lua.io unavailable" end

	local path = M.path(name)
	local ok, file, err = pcall(io_l.open, path, mode)
	if not ok then return false, tostring(file) end
	if not file then return false, tostring(err or "open returned nil") end

	local wrote, write_err = pcall(function()
		file:write(to_text(content))
		file:close()
	end)
	if not wrote then return false, tostring(write_err) end

	return true, path
end

function M.write(name, content)
	return open_and_write(name, "w", content)
end

function M.append(name, content)
	return open_and_write(name, "a", content)
end

function M.read(name)
	local io_l = io_lib()
	if not io_l then return nil, "Mods.lua.io unavailable" end
	local ok, file = pcall(io_l.open, M.path(name), "r")
	if not ok or not file then return nil, "could not open" end
	local content = file:read("*all")
	file:close()
	return content
end

-- ---------------------------------------------------------------------------
-- JSON encoding
--
-- Written by hand because cjson is not on this install. Small, and it only has to
-- handle what we actually emit: strings, finite numbers, booleans, flat-ish tables.
-- ---------------------------------------------------------------------------

local ESCAPES = {
	['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
	['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function escape_string(text)
	return (tostring(text):gsub('[%c"\\]', function(c)
		local mapped = ESCAPES[c]
		if mapped then return mapped end
		return string.format('\\u%04x', string.byte(c))
	end))
end

-- Reject inf and NaN. A NaN is the only value that does not equal itself, which is
-- how it gets detected here. Both would produce output no JSON reader accepts.
local function encode_number(value)
	if value ~= value then return "null" end
	if value == math.huge or value == -math.huge then return "null" end
	-- %.14g keeps integers looking like integers and avoids exponent noise.
	return string.format("%.14g", value)
end

local encode_value

-- A table is treated as an array when it has a positive length and no non-integer
-- keys. Everything else becomes an object.
local function is_array(value)
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then return false end
		count = count + 1
	end
	return count == #value and count > 0
end

encode_value = function(value, depth)
	depth = depth or 0
	if depth > 12 then return '"<too deep>"' end

	local kind = type(value)

	if value == nil then return "null" end
	if kind == "boolean" then return value and "true" or "false" end
	if kind == "number" then return encode_number(value) end
	if kind == "string" then return '"' .. escape_string(value) .. '"' end

	if kind == "table" then
		if is_array(value) then
			local parts = {}
			for i = 1, #value do parts[i] = encode_value(value[i], depth + 1) end
			return "[" .. table.concat(parts, ",") .. "]"
		end

		-- Sorted keys so two encodings of the same data are byte-identical, which
		-- makes logs diffable.
		local keys = {}
		for key in pairs(value) do
			if type(key) == "string" or type(key) == "number" then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

		local parts = {}
		for i = 1, #keys do
			local key = keys[i]
			parts[#parts + 1] = '"' .. escape_string(key) .. '":' ..
				encode_value(value[key], depth + 1)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end

	-- Functions, userdata, threads. Describe rather than fail.
	return '"<' .. kind .. '>"'
end

function M.encode_json(value)
	local ok, encoded = pcall(encode_value, value, 0)
	if not ok then return nil, tostring(encoded) end
	return encoded
end

function M.init(deps)
	_mod = deps.mod
end

return M
