-- SMOG_data.lua
local mod = get_mod("SMOG")
return {
name = mod:localize("mod_name"),
description = mod:localize("mod_description"),
is_togglable = true,
options = {
widgets = {
{
setting_id = "auto_clean_on_start",
type = "checkbox",
title = "auto_clean_on_start",
default_value = true,
},
{
setting_id = "auto_clean_every_ten_minutes",
type = "checkbox",
title = "auto_clean_every_ten_minutes",
default_value = false,
},
{
setting_id = "silent_running",
type = "checkbox",
title = "silent_running",
tooltip = "silent_running_tooltip",
default_value = false,
},
},
},
}
