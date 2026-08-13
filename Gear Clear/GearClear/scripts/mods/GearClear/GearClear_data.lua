-- GearClear_data.lua
return {
name = "{#color(93,101,50)}Gear Clear{#reset()}",
description = "Discards unwanted gear from inventory and always keeps favourited items",
is_togglable = true,
options = {
widgets = {
{
setting_id = "ignore_good_gear_mode",
type = "checkbox",
default_value = true,
tooltip = "ignore_good_gear_mode_description",
},
},
},
}
