---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_serialize then
	return mod.hud_studio_serialize
end

---@class Serialize
local Serialize = {}

local string_format = string.format
local table_concat = table.concat

local function is_identifier(key)
	return type(key) == "string" and string.match(key, "^[%a_][%w_]*$") ~= nil
end

local path = {}

local function path_string()
	if #path == 0 then
		return "<root>"
	end
	return table_concat(path)
end

local function number_source(n)
	if n ~= n or n == math.huge or n == -math.huge then
		error("cannot serialize a non-finite number at " .. path_string(), 0)
	end
	if math.floor(n) == n and math.abs(n) < 1e15 then
		return string_format("%d", n)
	end
	return string_format("%.17g", n)
end

local encode_value

local function is_array(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	for i = 1, count do
		if t[i] == nil then
			return false, 0
		end
	end
	return true, count
end

---@param t table
---@param indent string current indentation
local function encode_table(t, indent)
	local inner = indent .. "\t"
	local array, count = is_array(t)

	local parts = {}

	if array then
		if count == 0 then
			return "{}"
		end
		for i = 1, count do
			path[#path + 1] = "[" .. i .. "]"
			parts[#parts + 1] = inner .. encode_value(t[i], inner)
			path[#path] = nil
		end
	else

		local keys = {}
		for k in pairs(t) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		if #keys == 0 then
			return "{}"
		end
		for i = 1, #keys do
			local k = keys[i]
			local key_src
			if is_identifier(k) then
				key_src = k
			elseif type(k) == "number" then
				key_src = "[" .. number_source(k) .. "]"
			elseif type(k) == "string" then
				key_src = "[" .. string_format("%q", k) .. "]"
			else
				error("cannot serialize a table key of type " .. type(k) .. " at " .. path_string(), 0)
			end
			path[#path + 1] = (#path > 0 and "." or "") .. tostring(k)
			parts[#parts + 1] = inner .. key_src .. " = " .. encode_value(t[k], inner)
			path[#path] = nil
		end
	end

	return "{\n" .. table_concat(parts, ",\n") .. ",\n" .. indent .. "}"
end

---@param v any
---@param indent string
---@return string
encode_value = function(v, indent)
	local vt = type(v)
	if vt == "nil" then
		return "nil"
	elseif vt == "boolean" then
		return v and "true" or "false"
	elseif vt == "number" then
		return number_source(v)
	elseif vt == "string" then
		return string_format("%q", v)
	elseif vt == "table" then
		return encode_table(v, indent)
	end
	error("cannot serialize a value of type " .. vt .. " at " .. path_string(), 0)
end

---@param value table
---@return string
function Serialize.to_source(value)
	if type(value) ~= "table" then
		error("expected a table to serialize", 0)
	end

	path = {}
	return "return " .. encode_table(value, "")
end

mod.hud_studio_serialize = Serialize

return Serialize
