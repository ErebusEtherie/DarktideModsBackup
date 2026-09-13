
local mod = get_mod("hud_studio")

if mod.ide_code_rich_text then
	return mod.ide_code_rich_text
end

local COLOR = {
	COMMENT = { 255, 99, 113, 118 },
	DECLARATION = { 255, 189, 120, 199 },
	TYPE = { 255, 229, 192, 123 },
	TOKEN = { 255, 194, 108, 98 },
	FUNCTION = { 255, 86, 175, 221 },
	STRING = { 255, 126, 173, 101 },
	IDE_BG = { 255, 40, 44, 52 },
	PARENTHESES = { 255, 209, 141, 78 },
	SYMBOL = { 255, 171, 173, 155 },
	BRACKET = { 255, 199, 154, 87 },
	PRIMITIVE = { 255, 199, 154, 87 },
}

local DECLARATIONS = {
	["function"] = true,
	["local"] = true,
	["if"] = true,
	["then"] = true,
	["return"] = true,
	["end"] = true,
	["for"] = true,
	["while"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["repeat"] = true,
	["until"] = true,
	["break"] = true,
	["in"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
}

local CodeRichText = {}

CodeRichText.colors = COLOR

local function rich(text, color)
	return mod.dl.str.rich_text(text, { color = color })
end

function CodeRichText.format_string(str)
	local result = {}

	local i = 1
	local length = #str

	local expecting_function_name = false

	local expecting_local_identifier = false

	local function_call_depth = 0

	local square_bracket_depth = 0

	while i <= length do
		local char = str:sub(i, i)

		if char == "-" and str:sub(i + 1, i + 1) == "-" then
			local start = i

			i = i + 2

			while i <= length do
				if str:sub(i, i) == "\n" then
					break
				end

				i = i + 1
			end

			table.insert(result, rich(str:sub(start, i - 1), COLOR.COMMENT))
		elseif char == "[" then
			table.insert(result, rich(char, COLOR.BRACKET))

			i = i + 1
		elseif char == "]" then
			table.insert(result, rich(char, COLOR.BRACKET))

			i = i + 1
		elseif char == "}" or char == "{" then
			table.insert(result, rich(char, COLOR.BRACKET))

			i = i + 1

		elseif char == "'" or char == '"' then
			local quote = char
			local start = i

			i = i + 1

			while i <= length do
				local current = str:sub(i, i)

				if current == "\\" then
					i = i + 2

				elseif current == quote then
					i = i + 1
					break
				else
					i = i + 1
				end
			end

			table.insert(result, rich(str:sub(start, i - 1), COLOR.STRING))

		elseif char:match("[%a_]") then
			local start = i

			i = i + 1

			while i <= length do
				local current = str:sub(i, i)

				if current:match("[%w_]") then
					i = i + 1
				else
					break
				end
			end

			local word = str:sub(start, i - 1)

			if expecting_function_name then
				table.insert(result, rich(word, COLOR.FUNCTION))

				expecting_function_name = false

			elseif DECLARATIONS[word] then
				table.insert(result, rich(word, COLOR.DECLARATION))

				if word == "function" then
					expecting_function_name = true

				elseif word == "local" then
					expecting_local_identifier = true
				end

			elseif function_call_depth > 0 then
				table.insert(result, rich(word, COLOR.TOKEN))

			else

				local lookahead = i

				while lookahead <= length and str:sub(lookahead, lookahead):match("%s") do
					lookahead = lookahead + 1
				end

				if str:sub(lookahead, lookahead) == "(" then
					table.insert(result, rich(word, COLOR.FUNCTION))
				elseif word == "true" or word == "false" or word == "nil" then
					table.insert(result, rich(word, COLOR.PRIMITIVE))
				else
					table.insert(result, rich(word, COLOR.TOKEN))
				end
			end

		elseif char:match("%d") then
			local start = i

			while i <= length and str:sub(i, i):match("%d") do
				i = i + 1
			end

			if str:sub(i, i) == "." and str:sub(i + 1, i + 1):match("%d") then
				i = i + 1

				while i <= length and str:sub(i, i):match("%d") do
					i = i + 1
				end
			end

			table.insert(result, rich(str:sub(start, i - 1), COLOR.PRIMITIVE))

		elseif char == "(" then
			table.insert(result, rich(char, COLOR.PARENTHESES))

			local previous = i - 1

			while previous > 0 and str:sub(previous, previous):match("%s") do
				previous = previous - 1
			end

			local previous_char = str:sub(previous, previous)

			if previous_char:match("[%w_]") then
				function_call_depth = function_call_depth + 1
			end

			expecting_local_identifier = false

			i = i + 1

		elseif char == ")" then
			table.insert(result, rich(char, COLOR.PARENTHESES))

			if function_call_depth > 0 then
				function_call_depth = function_call_depth - 1
			end

			expecting_local_identifier = false

			i = i + 1

		elseif
			char == ","
			or char == "="
			or char == "."
			or char == "~"
			or char == ">"
			or char == "<"
			or char == ":"
			or char == "and"
			or char == "not"
		then
			table.insert(result, rich(char, COLOR.SYMBOL))

			i = i + 1

		else
			table.insert(result, char)

			if expecting_local_identifier then
				if not char:match("%s") and char ~= "," then
					expecting_local_identifier = false
				end
			end

			i = i + 1
		end
	end

	return table.concat(result)
end

mod.ide_code_rich_text = CodeRichText

return CodeRichText
