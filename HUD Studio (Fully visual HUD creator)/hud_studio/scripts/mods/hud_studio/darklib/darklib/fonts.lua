

local FontDefinitions = nil

---@param mod mod
return function(mod)
	---@class DL_Fonts
	local Fonts = {}

	---@enum FS_Font
	Fonts.reg = {
		arial = "arial",
		friz_quadrata = "friz_quadrata",
		itc_novarese_bold = "itc_novarese_bold",
		itc_novarese_medium = "itc_novarese_medium",
		machine_medium = "machine_medium",
		mono_tide_bold = "mono_tide_bold",
		mono_tide_light = "mono_tide_light",
		mono_tide_medium = "mono_tide_medium",
		mono_tide_regular = "mono_tide_regular",
		proxima_nova_bold = "proxima_nova_bold",
		proxima_nova_light = "proxima_nova_light",
		proxima_nova_medium = "proxima_nova_medium",
		rexlia = "rexlia",
	}

	local _preferred_fallback_font = "proxima_nova_medium"

	local _font_types = {}

	local _font_exists = {}

	local ensure_font_definitions = function()
		FontDefinitions = FontDefinitions or require("scripts/managers/ui/ui_fonts_definitions")
		return FontDefinitions
	end

	function Fonts.font_types()
		if not ensure_font_definitions() then
			return {}
		end

		if #_font_types > 0 then
			return _font_types
		end

		local fonts = {}
		local i = 0

		for font_name, _ in next, FontDefinitions.fonts do
			i = i + 1
			_font_exists[font_name] = true
			fonts[i] = { font_type = font_name }
		end

		if not _font_exists[_preferred_fallback_font] then
			_preferred_fallback_font = "arial" 
		end

		table.sort(fonts, function(left_option, right_option)
			return left_option.font_type < right_option.font_type
		end)

		_font_types = fonts

		return fonts
	end

	Fonts.font_types()

	function Fonts.validated(...)
		for i = 1, select("#", ...) do
			local font_type = select(i, ...)
			if _font_exists[font_type] then
				return font_type
			end
		end

		return _preferred_fallback_font
	end

	function Fonts.exists(font_name)
		return _font_exists[font_name]
	end

	function Fonts.fallback()
		return _preferred_fallback_font
	end

	return Fonts
end
