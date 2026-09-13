-- weakspots_data.lua
local mod = get_mod("weakspots")
return {
name = mod:localize("mod_name"),
description = mod:localize("mod_description"),
is_togglable = true,
options = {
widgets = {
{
setting_id = "marker_range",
type = "dropdown",
default_value = 20,
options = {
{text = "marker_range_10", value = 10},
{text = "marker_range_20", value = 20},
{text = "marker_range_30", value = 30},
{text = "marker_range_40", value = 40},
},
},
{
setting_id = "boss_only",
type = "checkbox",
default_value = false,
tooltip = "boss_only_tooltip",
},
},
},
}