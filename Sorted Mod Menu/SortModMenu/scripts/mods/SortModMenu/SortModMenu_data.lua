local mod = get_mod("SortModMenu")

local dmf = get_mod("DMF")

-- Function to process keys for sorting
function mod.process_mod_name(s)
    -- Lowercase
    s = tostring(s):lower()
    -- Strip color coding
    s = s:gsub("{#[^}]+}", "")      
        :gsub("{#reset%(%)}", "")
    
    local result = ""
    for c in s:gmatch(".") do
        -- Only letters
        if c:match("[a-z]") then
            result = result .. c
        end
    end
    
    return result
end

function mod.strip_color_codes_and_glyphs(s)
    if type(s) ~= "string" then return s end
    
    s = s:gsub("{#[^}]+}", "")
    s = s:gsub("{#reset%(%)}", "")
    s = s:gsub("[^\1-\127]", "")
    s = s:gsub("%s%s+", " ")
    s = s:match("^%s*(.-)%s*$")
    
    return s
end
-- Strip color codes and glyphs from entry if desired
function mod.get_fresh_pin_options()
	local pin_options = {}
	table.insert(pin_options, {
		value = "None",
		text  = "None"
	})
	for mod_name, curr_mod in pairs(dmf.mods) do
		local displayed = curr_mod:get_readable_name() or curr_mod:localize("mod_name") or "error"
		if mod:get("modname_cleaned") == true then 
        	displayed = mod.strip_color_codes_and_glyphs(displayed)
        end
		if mod_name == "SortModMenu" or displayed == "SortModMenu" then
			displayed = "Sorted Mod Menu"
		end
		table.insert(pin_options, {
			value = displayed,
			text  = displayed
		})
	end

	table.sort(pin_options, function(a, b)
		if a.text == "None" or b.text == "None" then
			return a.text == "None"   -- "None" always comes before anything else
		end
		return mod.process_mod_name(a.text) < mod.process_mod_name(b.text)
	end)

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
		title         = "Pinned Mod " .. (i + 1),
        tooltip       = "Pin #" .. (i + 1) .. " (lower number = higher priority)",
        options       = pin_options,
        default_value = "None",
		localize      = false,
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
local hidden_mods = mod.get_fresh_pin_options()
-- We don't want the user to hide Sorted Mod Menu or everything breaks
for i, entry in ipairs(hidden_mods) do
    if entry.text == "Sorted Mod Menu" then
        table.remove(hidden_mods, i)
        break
    end
end
for i = 0, 9 do
    table.insert(hidden_group.sub_widgets, {
        setting_id    = "hidden_" .. i,
        type   		  = "dropdown",
		title         = "Hidden Mod " .. (i + 1),
        tooltip       = "This mod will not be visible in the mod list",
        options       = hidden_mods,
        default_value = "None",
		localize      = false,
    })
end
table.insert(widgets, hidden_group)

return {
	name = "Sorted Mod Menu", --mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
		localize = true,
	},
}
