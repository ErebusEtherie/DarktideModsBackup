
local mod = get_mod("hud_studio")

if mod.editor_format then
	return mod.editor_format
end

---@class Format
local Format = {}

local MAX_DECIMALS = 2
Format.MAX_DECIMALS = MAX_DECIMALS

local string_format = string.format
local math_floor = math.floor
local math_abs = math.abs
local math_huge = math.huge

---@param value any
---@param decimals number?   the caller's own precision, when it is FINER than the cap matters
---@return string
function Format.number(value, decimals)
	if type(value) ~= "number" then
		return tostring(value)
	end
	if value ~= value or value == math_huge or value == -math_huge then
		return tostring(value)
	end

	local places = decimals or MAX_DECIMALS
	if places > MAX_DECIMALS then
		places = MAX_DECIMALS
	elseif places < 0 then
		places = 0
	end

	local text = string_format("%." .. places .. "f", value)
	local rounded = tonumber(text) or value

	if rounded == math_floor(rounded) and math_abs(rounded) < 1e15 then

		return string_format("%d", rounded + 0)
	end

	if text:find("%.") then

		return (text:gsub("0+$", ""):gsub("%.$", ""))
	end
	return text
end

---@param value any
---@return string
function Format.value(value)
	if value == nil or value == false then
		return ""
	end
	if type(value) == "number" then
		return Format.number(value)
	end
	return tostring(value)
end

mod.editor_format = Format

return Format
