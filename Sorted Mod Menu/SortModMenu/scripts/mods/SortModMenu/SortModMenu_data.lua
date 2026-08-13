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
-- Clear cache on reload to prevent stale entries from growing unboundedly
mod._clear_unicode_cache = function() unicode_type_cache = {} end

local function strip_color_codes(s)
    s = s:gsub("{#[^}]+}", "")
    return s
end

local function normalize_spaces(s)
    s = s:gsub("%s%s+", " ")
    s = s:match("^%s*(.-)%s*$") or ""
    return s
end

local UNICODE_CACHE_MAX = 256
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

    -- Evict oldest entries if cache exceeds limit
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

-- Function to process keys for sorting
function mod.process_mod_name(s)
    -- Lowercase
    s = tostring(s):lower()
    -- Strip color coding
    s = strip_color_codes(s)

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

    return normalize_spaces(table.concat(result))
end

function mod.strip_color_codes_and_glyphs(s)
    if type(s) ~= "string" then return s end

    s = strip_color_codes(s)

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

    return normalize_spaces(table.concat(result))
end

-- Strip color codes and glyphs from entry if desired
function mod.get_fresh_pin_options(include_self)
	local pin_options = {}
	table.insert(pin_options, {
		value = "None",
		text  = mod:localize("None")
	})
	for mod_name, curr_mod in pairs(dmf.mods) do
		if include_self ~= false or mod_name ~= "SortModMenu" then
			local displayed = curr_mod:get_readable_name() or curr_mod:localize("mod_name") or "error"
			if mod:get("modname_cleaned") == true then 
	        	displayed = mod.strip_color_codes_and_glyphs(displayed)
	        end
			if mod_name == "SortModMenu" then
				displayed = mod:localize("mod_name")
			end
			table.insert(pin_options, {
				value = displayed,
				text  = displayed
			})
		end
	end

	table.sort(pin_options, function(a, b)
		if a.value == "None" or b.value == "None" then
			return a.value == "None"   -- "None" always comes before anything else
		end
		return mod.process_mod_name(a.text) < mod.process_mod_name(b.text)
	end)

	pin_options.localize = false

	return pin_options
end



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
			}
		},
		default_value = "Ascending",
	},
	{
		setting_id = "pinned_icon",
		type = "dropdown",
		options = {
			{
				value = "None",
				text = "None",
			},
			{
				value = "\u{e046}",
				text = "\u{e046}",
			},
			{
				value = "\u{e02b}",
				text = "\u{e02b}",
			},
			{
				value = "\u{e02a}",
				text = "\u{e02a}",
			},
			{
				value = "\u{e01e}",
				text = "\u{e01e}",
			},
			{
				value = "\u{e020}",
				text = "\u{e020}",
			},
			{
				value = "\u{e041}",
				text = "\u{e041}",
			},
		},
		default_value = "\u{e046}",
	},
	{
		setting_id = "searchbox_enabled",
		type = "checkbox",
		default_value = true,
	},
	{
		setting_id = "modname_cleaned",
		type = "checkbox",
		default_value = false
	},
}

-- Create the pins group
local pins_group = {
    setting_id    = "pinned_mods_group",
    type = "group",
	sub_widgets   = {},
}

-- Add all 10 pin dropdowns inside the group
local pin_options = mod.get_fresh_pin_options()
for i = 0, 9 do
    table.insert(pins_group.sub_widgets, {
        setting_id    = "pin_" .. i,
        type   		  = "dropdown",
		title         = "pin_" .. i,
        tooltip       = "pin_" .. i .. "_description",
        options       = pin_options,
        default_value = "None",
    })
end

-- Finally, add the group to the main widgets list
table.insert(widgets, pins_group)

-- Add the ability to hide up to 10 different mods from the list
local hidden_group = {
    setting_id    = "hidden_mods_group",
    type = "group",
	sub_widgets   = {},
}
local hidden_mods = mod.get_fresh_pin_options(false)
for i = 0, 9 do
    table.insert(hidden_group.sub_widgets, {
        setting_id    = "hidden_" .. i,
        type   		  = "dropdown",
		title         = "hidden_" .. i,
        tooltip       = "hidden_" .. i .. "_description",
        options       = hidden_mods,
        default_value = "None",
    })
end
table.insert(widgets, hidden_group)

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
		localize = true,
	},
}
