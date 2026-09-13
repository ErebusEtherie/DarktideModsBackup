local rt

local COLORS = {
	dark = {
		base = { 255, 210, 210, 210 },
		base_bold = Color.terminal_text_warning_light(255, true),
		code = { 255, 63, 123, 217 },
	},
	light = {
		base = { 255, 30, 30, 30 },
		base_bold = { 255, 10, 10, 10 },
		code = { 255, 23, 83, 177 },
	},
}

---@class DarkLib
---@field md DL_Markdown

---@param mod mod
return function(mod)
	rt = mod.dl.str.rich_text

	---@class DL_Markdown
	local Markdown = {}

	local function sanitized(text)

		text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")

		return text
	end

	local function to_rt(text, color)
		if type(text) ~= "string" then
			return ""
		end

		return rt(text, { color = color })
	end

	function Markdown.to_rich_text(theme, text)
		text = type(text) == "string" and sanitized(text) or ""

		if text == "" then
			return text
		end

		local colors = COLORS[theme or "light"] or COLORS.light
		local result = {}

		local plain_start = 1
		local i = 1
		local length = #text

		local function add_plain(from, to)
			if from <= to then
				result[#result + 1] = text:sub(from, to)
			end
		end

		while i <= length do

			if text:sub(i, i + 1) == "**" then
				local close = text:find("**", i + 2, true)

				if close then
					add_plain(plain_start, i - 1)

					result[#result + 1] = to_rt(text:sub(i + 2, close - 1), colors.base_bold)

					i = close + 2
					plain_start = i
				else

					i = i + 2
				end

			elseif text:sub(i, i) == "`" then
				local close = text:find("`", i + 1, true)

				if close then
					add_plain(plain_start, i - 1)

					result[#result + 1] = to_rt(text:sub(i + 1, close - 1), colors.code)

					i = close + 1
					plain_start = i
				else

					i = i + 1
				end
			else
				i = i + 1
			end
		end

		add_plain(plain_start, length)

		return table.concat(result)
	end

	return Markdown
end
