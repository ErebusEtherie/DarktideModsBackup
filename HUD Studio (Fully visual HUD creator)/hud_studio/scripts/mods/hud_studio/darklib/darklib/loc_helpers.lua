

local FORMAT_SPEC = "^%%[-+0]*%d*%.?%d*[cdiouxXeEfgGqs]"

---@param mod mod
return function(mod)
	---@class DL_LocHelpers
	local LocHelpers = {}

	---@param localization_table table
	---@param sample_text? string
	LocHelpers.insert_font_type_localisation = function(localization_table, sample_text)
		for _, option in ipairs(mod.dl.fonts.font_types()) do
			local readable_font = mod.dl.str.machine_to_human_text(option.font_type)

			localization_table[option.font_type] = {
				en = sample_text or readable_font,
			}
		end
	end

	---@param a table
	---@param b table
	LocHelpers.merge_tables = function(a, b)
		for k, v in pairs(b) do
			a[k] = v
		end
		return a
	end

	---@param str string
	---@return string
	LocHelpers.escape_percent = function(str)
		if type(str) ~= "string" or not str:find("%", 1, true) then
			return str
		end

		local out = {}
		local i = 1

		while true do
			local at = str:find("%", i, true)

			if not at then
				out[#out + 1] = str:sub(i)
				break
			end

			out[#out + 1] = str:sub(i, at - 1)

			if str:sub(at + 1, at + 1) == "%" then

				out[#out + 1] = "%%"
				i = at + 2
			else

				local spec = str:match(FORMAT_SPEC, at)
				if spec then
					out[#out + 1] = spec
					i = at + #spec
				else
					out[#out + 1] = "%%"
					i = at + 1
				end
			end
		end

		return table.concat(out)
	end

	---@param localization table the accumulating table returned to DMF
	---@param lang_table table<string, table<string, string>> one lang file's entries
	LocHelpers.merge_localization = function(localization, lang_table)
		for key, translations in pairs(lang_table) do
			if type(translations) == "table" then
				local escaped = {}
				for language, str in pairs(translations) do
					escaped[language] = LocHelpers.escape_percent(str)
				end
				localization[key] = escaped
			else
				localization[key] = translations
			end
		end

		return localization
	end

	---@param text string
	LocHelpers.important = function(text)
		return mod.dl.str.rich_text("( ! ) " .. text, { color = mod.dl.colors.reg.ui.hud_red_light })
	end

	---@param ... string
	LocHelpers.description = function(...)
		local args = { ... }

		if #args == 0 then
			return ""
		end

		local result = "\n" .. tostring(args[1])

		for i = 2, #args do
			result = result .. "\n\n" .. tostring(args[i])
		end

		return result
	end

	---@param ... string
	LocHelpers.lines = function(...)
		local args = { ... }

		if #args == 0 then
			return ""
		end

		local result = "" .. tostring(args[1])

		for i = 2, #args do
			result = result .. "\n" .. tostring(args[i])
		end

		return result
	end

	return LocHelpers
end
