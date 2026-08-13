-- huntsalvage_data.lua
return {
name = "{#color(93,101,50)}Hunt the Salvage{#reset()}",
description = "Shows closest salvage pick-up and how many remain in a zone",
is_togglable = true,
options = {
widgets = {
{
setting_id = "enable_mod",
type = "checkbox",
default_value = true,
display_name = "enable_mod",
},
{
setting_id = "highlight_next_salvage",
type = "checkbox",
default_value = true,
display_name = "highlight_next_salvage",
sub_widgets = {
{
setting_id = "show_distance_to_next_salvage",
type = "checkbox",
default_value = true,
display_name = "show_distance_to_next_salvage",
},
},
},
{
setting_id = "show_counter",
type = "checkbox",
default_value = true,
display_name = "show_counter",
},
{
setting_id = "show_total_as_well",
type = "checkbox",
default_value = false,
display_name = "show_total_as_well",
},
{
setting_id = "last_sanctuary_warning",
type = "checkbox",
default_value = true,
display_name = "last_sanctuary_warning",
},
},
},
}