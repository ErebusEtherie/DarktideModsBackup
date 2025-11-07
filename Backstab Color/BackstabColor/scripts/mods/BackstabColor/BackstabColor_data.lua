local mod = get_mod("BackstabColor")
local t = 1
local attack_types = {"backstab","flanking"}
local result_types = {"damage_normal","damage_crit","death"}
local color_order = {"opacity","R","G","B"}

local widgets = {
	{
		setting_id = "smart_toggle_group",
		type = "group",
		sub_widgets = {
			{
				setting_id = "smart_toggle_backstab",
				type = "checkbox",		
				default_value = false,
			},
			{
				setting_id = "smart_toggle_flanking",
				type = "checkbox",		
				default_value = false,
			},
		},
	},
	{
		setting_id = "color_settings_group",
		type = "group",
		sub_widgets = {},
	},
}

for p = 1,#attack_types do
	for i = 1,#result_types do
		widgets[2].sub_widgets[t] = {
			setting_id = attack_types[p].."_"..result_types[i],
			type = "checkbox",
			default_value = false,
		}
		for o = 1,4 do
			widgets[2].sub_widgets[t + o] = {
				setting_id = string.format("%s_%s_%s",attack_types[p],result_types[i],color_order[o]),
				type = "numeric",
				default_value = 255,
				title = color_order[o],
				range = { 0, 255 },
			}
		end
		t = t + 5
	end
end
return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
