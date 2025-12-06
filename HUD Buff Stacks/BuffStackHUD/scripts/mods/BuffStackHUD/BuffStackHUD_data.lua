local mod = get_mod("BuffStackHUD")

local color_option = {}

local _is_duplicated = function(a, color_name)
    local join = function(t)
        return string.format("%s,%s,%s", t[2], t[3], t[4])
    end

    for i, table in ipairs(color_option) do
        local b = Color[table.text](255, true)

        if join(a) == join(b) then
			if color_name < table.text then
				-- Make sure we use the name with the earliest appearance on alphabatical order.
				table.text = color_name
			end
            return true
        end
    end

    return false
end


for i, name in ipairs(Color.list) do
    if not _is_duplicated(Color[name](255, true), name) then
        color_option[#color_option + 1] = { text = name, value = name }
    end
end

table.sort(color_option, function(a, b)
    return a.text < b.text
end)

local widgets = {
}
local lock_options = {}
lock_options[1] = { text = "Slot not Reserved", value = "" }

for _, buff_name in ipairs(mod.buff_names) do
	widgets[#widgets + 1] = {
		setting_id = "group_" .. buff_name,
		type = "group",
		sub_widgets = {
			{
				setting_id = "enable_" .. buff_name,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "showlabel_" .. buff_name,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "color_" .. buff_name,
				type = "dropdown",
				default_value = "dark_magenta",
				options = table.clone(color_option)
			}
		}
	}
	lock_options[#lock_options + 1] = {
		text = "group_" .. buff_name,
		value = buff_name,
	}
end

for group_name, _ in pairs(mod.group_overrides) do
	widgets[#widgets + 1] = {
		setting_id = "group_g_" .. group_name,
		type = "group",
		sub_widgets = {
			{
				setting_id = "enable_g_" .. group_name,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "showlabel_g_" .. group_name,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "color_g_" .. group_name,
				type = "dropdown",
				default_value = "dark_magenta",
				options = table.clone(color_option)
			}
		}
	}
	lock_options[#lock_options + 1] = {
		text = "group_g_" .. group_name,
		value = "g_" .. group_name,
	}
end

local lock_settings = {}

for i = 1, mod.buff_max do
	lock_settings[#lock_settings + 1] = {
		setting_id = "lock_slot_" .. i,
		type = "dropdown",
		default_value = "",
		options = table.clone(lock_options)
	}
end

widgets[#widgets + 1] = {
	setting_id = "lock_slot_group",
	type = "group",
	sub_widgets = lock_settings,
}

widgets[#widgets + 1] = {
	setting_id = "hud_element_settings_group",
	type = "group",
	sub_widgets = {
		{
			setting_id = "stack_font_size",
			type = "numeric",
			default_value = 30,
			range = { 5, 50 },
			decimals_number = 0,
		},
		{
			setting_id = "label_font_size",
			type = "numeric",
			default_value = 15,
			range = { 5, 50 },
			decimals_number = 0,
		},
	},
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets
	}
}
