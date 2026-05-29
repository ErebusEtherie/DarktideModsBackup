-- Cut_transmission_data.lua
return {
name = "{#color(93,101,50)}Cut Transmission{#reset()}",
description = "Automatically skips post-mission transmissions.",
is_togglable = true,
allow_rehooking = true,
options = {
widgets = {
{
setting_id = "skip_transmissions",
type = "checkbox",
default_value = true,
},
},
},
}