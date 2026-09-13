---@class DarkLib
---@field str DL_Str

---@param mod mod
return function(mod)
	---@class DL_Str
	local Str = {}

	local DMF = get_mod("DMF")
	local _os = DMF.deepcopy(Mods.lua.os)

	function Str.format_number(value)
		local rounded = math.floor((value or 0) + 0.5)

		local sign = ""
		if rounded < 0 then
			sign = "-"
			rounded = -rounded
		end

		local digits = tostring(rounded)
		local tail = digits:sub(-3)
		digits = digits:sub(1, -4)

		while #digits > 0 do
			if #digits <= 3 then
				return sign .. digits .. "," .. tail
			end

			tail = digits:sub(-3) .. "," .. tail
			digits = digits:sub(1, -4)
		end

		return sign .. tail
	end

	---@param value number|nil
	---@return string
	function Str.format_compact(value)
		value = value or 0

		local sign = ""
		if value < 0 then
			sign = "-"
			value = -value
		end

		local scaled, suffix
		if value >= 1000000 then
			scaled, suffix = value / 1000000, "m"
		elseif value >= 10000 then
			scaled, suffix = value / 1000, "k"
		else
			return sign .. tostring(math.floor(value + 0.5))
		end

		local tenths = math.floor(scaled * 10 + 0.5)
		if scaled >= 100 or tenths % 10 == 0 then
			return sign .. tostring(math.floor(tenths / 10 + 0.5)) .. suffix
		end

		return sign .. string.format("%.1f%s", tenths / 10, suffix)
	end

	function Str.machine_to_human_text(text)
		return text:gsub("_", " "):gsub("(%a)([%w]*)", function(first_letter, rest_of_word)
			return first_letter:upper() .. rest_of_word
		end)
	end

	---@param seconds number|nil
	---@return string
	function Str.format_timer(seconds)
		seconds = math.max(0, math.ceil(seconds or 0))
		local minutes = math.floor(seconds / 60)
		return string.format("%d:%02d", minutes, seconds % 60)
	end

	---@param timestamp number|nil  unix seconds
	---@param short boolean|nil      compact suffixes (m/h/d/w/mo/y) instead of full words
	---@param now number|nil         reference time (defaults to os.time())
	---@return string
	function Str.format_time_ago(timestamp, short, now)
		if not timestamp or timestamp <= 0 then
			return ""
		end

		now = now or _os.time()
		local diff = now - timestamp
		if diff < 0 then
			diff = 0
		end

		local minute, hour, day = 60, 3600, 86400
		local week, month, year = day * 7, day * 30, day * 365

		local value, unit_long, unit_short
		if diff < minute then
			return short and "now" or "just now"
		elseif diff < hour then
			value, unit_long, unit_short = math.floor(diff / minute), "minute", "m"
		elseif diff < day then
			value, unit_long, unit_short = math.floor(diff / hour), "hour", "h"
		elseif diff < week then
			value, unit_long, unit_short = math.floor(diff / day), "day", "d"
		elseif diff < month then
			value, unit_long, unit_short = math.floor(diff / week), "week", "w"
		elseif diff < year then
			value, unit_long, unit_short = math.floor(diff / month), "month", "mo"
		else
			value, unit_long, unit_short = math.floor(diff / year), "year", "y"
		end

		if short then
			return string.format("%d%s ago", value, unit_short)
		end

		local plural = value == 1 and "" or "s"
		return string.format("%d %s%s ago", value, unit_long, plural)
	end

	---@param template string|nil
	---@param values table -- any table whose fields back the {placeholders}
	---@return string
	function Str.fill_template(template, values)
		if not template then
			return ""
		end

		return (
			template:gsub("{([%w_]+)}", function(key)
				local value = values[key]
				if value == nil then
					return "{" .. key .. "}"
				end
				if type(value) == "number" then
					return Str.format_number(value)
				end
				return tostring(value)
			end)
		)
	end

	---@param string string|nil
	---@param separator string|nil
	---@return table
	function Str.split(string, separator)
		separator = separator or ","
		local result = {}

		if not string or string == "" then
			return result
		end

		if separator == "" then
			for i = 1, #string do
				result[i] = string:sub(i, i)
			end
			return result
		end

		local pattern = "([^" .. separator .. "]+)"
		for part in string:gmatch(pattern) do
			table.insert(result, part)
		end

		return result
	end

	local function collect_join_parts(parts, value)
		if value == nil then
			return
		end

		if type(value) == "table" then
			for i = 1, #value do
				collect_join_parts(parts, value[i])
			end
		else
			parts[#parts + 1] = tostring(value)
		end
	end

	function Str.remove_duplicates(target, character)
		character = character:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
		return target:gsub("(" .. character .. ")+", "%1")
	end

	function Str.join(delimiter, ...)
		local parts = {}

		for i = 1, select("#", ...) do
			collect_join_parts(parts, (select(i, ...)))
		end

		return table.concat(parts, delimiter)
	end

	---@param text string
	---@param start_color rgb_table
	---@param end_color rgb_table
	function Str.rich_text_gradient(text, start_color, end_color)
		local visible_char_count = 0
		for i = 1, #text do
			if text:sub(i, i) ~= " " then
				visible_char_count = visible_char_count + 1
			end
		end

		start_color = mod.dl.colors.to_rgb(start_color)
		end_color = mod.dl.colors.to_rgb(end_color)

		local result = {}
		local visible_char_index = 0

		for i = 1, #text do
			local char = text:sub(i, i)

			if char == " " then
				table.insert(result, char)
			else
				local progress
				if visible_char_count <= 1 then
					progress = 0
				else
					progress = visible_char_index / (visible_char_count - 1)
				end

				local red = math.floor(start_color[1] + (end_color[1] - start_color[1]) * progress + 0.5)
				local green = math.floor(start_color[2] + (end_color[2] - start_color[2]) * progress + 0.5)
				local blue = math.floor(start_color[3] + (end_color[3] - start_color[3]) * progress + 0.5)

				table.insert(result, string.format("{#color(%d,%d,%d)}%s", red, green, blue, char))

				visible_char_index = visible_char_index + 1
			end
		end

		table.insert(result, "{#reset()}")

		return table.concat(result)
	end

	---@param text string
	---@param options { color?: rgb_table | argb_table, font?: string, size?: integer }
	function Str.rich_text(text, options)
		local rich_text = text or ""

		if not options or rich_text == "" then
			return rich_text
		end

		local tags = {}

		if options.font then
			tags[#tags + 1] = string.format("font(%s)", options.font)
		end

		if options.color then
			local rgb = mod.dl.colors.to_rgb(options.color)
			tags[#tags + 1] = string.format("color(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
		end

		if options.size then
			tags[#tags + 1] = string.format("size(%d)", options.size)
		end

		if #tags == 0 then
			return rich_text
		end

		return string.format("{#%s}%s{#reset()}", table.concat(tags, ";"), rich_text)
	end

	---@param text string
	---@return string
	function Str.strip_rich_text(text)
		if not text or text == "" or not text:find("{#", 1, true) then
			return text or ""
		end

		return (text:gsub("{#[^}]*}", ""))
	end

	return Str
end
