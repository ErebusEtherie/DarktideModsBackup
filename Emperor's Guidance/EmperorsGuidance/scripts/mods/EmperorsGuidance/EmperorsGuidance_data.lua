local mod = get_mod("EmperorsGuidance")
local Breeds = require("scripts/settings/breed/breeds")

-- Filter widget template structure
local filter = {
	setting_id   = "filter_settings",
	type		 = "group",
	sub_widgets  = {
		{
			setting_id = "filter_select",
			type       = "dropdown",
			default_value = "primary",
			options = {
				{ value = "primary", text = "filter_select_primary" },
				{ value = "secondary", text = "filter_select_secondary" },
			}
		},
		{
			setting_id = "global_group_toggle",
			type       = "checkbox",
			default_value = false,
		}
	}
}

-- Give each breed a toggle within its respective group, placed inside filter widget
local function add(tbl, breed_name, group)
	local group_nonexistent = true
	for _, widget in ipairs(tbl.sub_widgets) do
		if widget.setting_id == group then
			group_nonexistent = false
			widget.sub_widgets[#widget.sub_widgets + 1] = {
				setting_id = breed_name,
				type = "checkbox",
				default_value = false,
			}
		end
		if not group_nonexistent then
			break
		end
	end
	if group_nonexistent then
		tbl.sub_widgets[#tbl.sub_widgets + 1] = {
			setting_id = group,
			type       = "group",
			sub_widgets = {
				{
					setting_id = breed_name,
					type       = "checkbox",
					default_value = false,
				}
			}
		}
	end
end

for breed_name, breed in pairs(Breeds) do
    if breed.tags.minion and not breed.tags.companion then
		if breed.tags.elite then
			add(filter, breed_name, "elite_group")
		elseif breed.tags.special or breed.tags.ritualist then
			add(filter, breed_name, "special_group")
		elseif breed.tags.monster or breed.tags.captain or breed.tags.cultist_captain then
			add(filter, breed_name, "boss_group")
		else
			add(filter, breed_name, "fodder_group")
		end
	end
end

-- Sort each group by setting_id (breed_name)
local function sort_group_subwidgets(tbl)
	for _, group in ipairs(tbl.sub_widgets) do
		if group.type == "group" and group.sub_widgets then
			table.sort(group.sub_widgets, function(a, b)
				return a.setting_id < b.setting_id
			end)
		end
	end
end
sort_group_subwidgets(filter)

-- Add group toggles
for _, group in ipairs(filter.sub_widgets) do
	if group.type == "group" and group.sub_widgets then
		table.insert(group.sub_widgets, 1, {
			setting_id = group.setting_id .. "_toggle",
			type = "checkbox",
			default_value = false,
		})
	end
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			-- Filters
			{
				setting_id  = "global_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "mod_enabled",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "mod_enable_toggle",
						type          = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "toggle_mod",
					},
					{
						setting_id    = "mod_enable_verbose",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "filter_primary",
						type          = "checkbox",
						default_value = false
					},
					{
						setting_id    = "filter_secondary",
						type          = "checkbox",
						default_value = false
					},
					{
						setting_id    = "copy_primary_to_secondary",
						type          = "checkbox",
						tooltip	      = "copy_primary_to_secondary_tooltip",
						default_value = true
					},
					--[[]	
					{
						setting_id      = "debug",
						type            = "keybind",
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "debug",
						default_value   = {}
					}
					--]]
				}
			},
			filter,
		}
	}
}