-- excise-vault-scope_data.lua
local mod = get_mod("excise-vault-scope")
local marker_size_options = {
{ text = "small", value = "Small" },
{ text = "medium", value = "Medium" },
{ text = "large", value = "Large" },
}
local marker_distance_options = {
{ text = "near_in_vault", value = "Near" },
{ text = "far_whole_room", value = "Far" },
}
return {
name = mod:localize("mod_name"),
description = mod:localize("mod_description"),
is_togglable = true,
options = {
widgets = {
{
setting_id = "marker_settings",
type = "group",
sub_widgets = {
{
setting_id = "marker_max_distance",
type = "dropdown",
title = "marker_max_distance",
default_value = "Far",
options = marker_distance_options,
},
{
setting_id = "marker_size",
type = "dropdown",
title = "marker_size",
default_value = "Medium",
options = marker_size_options,
},
{
setting_id = "countdown",
type = "checkbox",
title = "countdown",
default_value = false,
},
{
setting_id = "indicate_level",
type = "checkbox",
title = "indicate_level",
default_value = false,
},
{
setting_id = "mark_final_button",
type = "checkbox",
title = "mark_final_button",
default_value = true,
},
{
setting_id = "include_cypher_ident_mid_event",
type = "checkbox",
title = "include_cypher_ident_mid_event",
default_value = true,
},
},
},
},
},
}
