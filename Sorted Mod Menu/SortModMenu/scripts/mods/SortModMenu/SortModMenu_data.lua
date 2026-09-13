local mod = get_mod("SortModMenu")

local dmf = get_mod("DMF")
local ffi = Mods.lua.ffi

if not rawget(_G, "_sortmodmenu_ffi_cdef_done") then
	pcall(function()
		ffi.cdef([[
            typedef unsigned short SortModMenu_WORD;
            typedef unsigned short SortModMenu_WCHAR;

            int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SortModMenu_WCHAR* lpWideCharStr, int cchWideChar);
            int GetStringTypeW(unsigned long dwInfoType, const SortModMenu_WCHAR* lpSrcStr, int cchSrc, SortModMenu_WORD* lpCharType);
        ]])
	end)
	_G._sortmodmenu_ffi_cdef_done = true
end

local kernel32 = ffi.load("kernel32")
local CP_UTF8 = 65001
local CT_CTYPE1 = 1
local C1_PUNCT = 0x0010
local C1_ALPHA = 0x0100

local unicode_type_cache = {}
mod._clear_unicode_cache = function()
	unicode_type_cache = {}
end

local UNICODE_CACHE_MAX = 256

-- Windows API lookup of character class flags (letter/punctuation) for a UTF-8 char,
-- cached because it is called for every character while sorting.
local function get_unicode_type_flags(char)
	local cached = unicode_type_cache[char]
	if cached ~= nil then
		return cached
	end

	local wide_length = kernel32.MultiByteToWideChar(CP_UTF8, 0, char, #char, nil, 0)
	if wide_length == 0 then
		return nil
	end

	local wide = ffi.new("SortModMenu_WCHAR[?]", wide_length)
	local converted = kernel32.MultiByteToWideChar(CP_UTF8, 0, char, #char, wide, wide_length)
	if converted == 0 then
		return nil
	end

	local types = ffi.new("SortModMenu_WORD[?]", wide_length)
	local typed = kernel32.GetStringTypeW(CT_CTYPE1, wide, wide_length, types)
	if typed == 0 then
		return nil
	end

	local type_flags = tonumber(types[0])

	-- Evict cache when it grows past the limit
	local count = 0
	for _ in pairs(unicode_type_cache) do
		count = count + 1
		if count >= UNICODE_CACHE_MAX then
			unicode_type_cache = {}
			break
		end
	end

	unicode_type_cache[char] = type_flags
	return type_flags
end

local function is_unicode_letter(char)
	local type_flags = get_unicode_type_flags(char)
	return type_flags and bit.band(type_flags, C1_ALPHA) ~= 0
end

local function is_unicode_letter_or_punctuation(char)
	local type_flags = get_unicode_type_flags(char)
	return type_flags and (bit.band(type_flags, C1_ALPHA) ~= 0 or bit.band(type_flags, C1_PUNCT) ~= 0)
end

local function next_char(s, index)
	local _, next_index = Utf8.location(s, index)
	return s:sub(index, next_index - 1), next_index
end

local function is_process_name_char(char)
	return #char == 1 and char:match("[a-z0-9]") ~= nil or #char > 1 and is_unicode_letter(char)
end

local function is_display_name_char(char)
	return #char == 1 or is_unicode_letter_or_punctuation(char)
end

-- Lowercased name reduced to letters/digits (everything else becomes a space),
-- used as the sort key and for matching hidden-mod entries.
function mod.process_mod_name(s)
	s = tostring(s):lower()
	s = s:gsub("{#[^}]+}", "")

	local result = {}
	local index = 1
	local length = #s

	while index <= length do
		local char, next_index = next_char(s, index)

		if is_process_name_char(char) then
			result[#result + 1] = char
		else
			result[#result + 1] = " "
		end

		index = next_index
	end

	local processed = table.concat(result)
	processed = processed:gsub("%s%s+", " ")
	processed = processed:match("^%s*(.-)%s*$") or ""

	return processed
end

-- Removes color codes and glyph characters, trims/collapses whitespace.
function mod.strip_color_codes_and_glyphs(s)
	if type(s) ~= "string" then
		return s
	end

	s = s:gsub("{#[^}]+}", "")

	local result = {}
	local index = 1
	local length = #s

	while index <= length do
		local char, next_index = next_char(s, index)

		if is_display_name_char(char) then
			result[#result + 1] = char
		end

		index = next_index
	end

	local cleaned = table.concat(result)
	cleaned = cleaned:gsub("%s%s+", " ")
	cleaned = cleaned:match("^%s*(.-)%s*$") or ""

	return cleaned
end

-- ####################################################################################################################
-- ##### Options widgets ##############################################################################################
-- ####################################################################################################################

local MAX_HIDDEN_MODS = 10

-- Dropdown entries ("None" + every other loaded mod) for one hidden-mod slot.
local function get_mod_dropdown_options(include_self)
	local options = {
		{
			value = "None",
			text = mod:localize("None"),
		},
	}

	for mod_name, curr_mod in pairs(dmf.mods) do
		if include_self ~= false or mod_name ~= "SortModMenu" then
			local displayed = curr_mod:get_readable_name() or curr_mod:localize("mod_name") or "error"
			if mod:get("modname_cleaned") == true then
				displayed = mod.strip_color_codes_and_glyphs(displayed)
			end
			if mod_name == "SortModMenu" then
				displayed = mod:localize("mod_name")
			end
			options[#options + 1] = {
				value = displayed,
				text = displayed,
			}
		end
	end

	table.sort(options, function(a, b)
		if a.value == "None" or b.value == "None" then
			return a.value == "None"
		end
		return mod.process_mod_name(a.text) < mod.process_mod_name(b.text)
	end)

	options.localize = false

	return options
end

-- This mod's full settings widget list.
local function build_option_widgets()
	local widgets = {
		{
			setting_id = "sort_order",
			type = "dropdown",
			options = {
				{
					value = "Ascending",
					text = "Ascending",
				},
				{
					value = "Descending",
					text = "Descending",
				},
			},
			default_value = "Ascending",
		},
		{
			setting_id = "modname_cleaned",
			type = "checkbox",
			default_value = false,
		},
	}

	local hidden_group = {
		setting_id = "hidden_mods_group",
		type = "group",
		sub_widgets = {},
	}
	local hidden_options = get_mod_dropdown_options(false)

	for i = 0, MAX_HIDDEN_MODS - 1 do
		hidden_group.sub_widgets[#hidden_group.sub_widgets + 1] = {
			setting_id = "hidden_" .. i,
			type = "dropdown",
			title = "hidden_" .. i,
			tooltip = "hidden_" .. i .. "_description",
			options = hidden_options,
			default_value = "None",
		}
	end

	widgets[#widgets + 1] = hidden_group

	return widgets
end

mod.get_mod_dropdown_options = get_mod_dropdown_options
mod.build_option_widgets = build_option_widgets

local option_widgets = build_option_widgets()

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = option_widgets,
		localize = true,
	},
}
