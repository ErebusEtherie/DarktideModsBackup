--[[
Title: Color My Stamina
Author: Miles
Date: 03/24/2026
Repository: https://github.com/Burzah/ColorMyStamina
Version: 1.0.0
--]]

local mod = get_mod("ColorMyStamina")

local color_options = {}
for _, color_name in ipairs(Color.list) do
    color_options[#color_options + 1] = {
        text  = color_name,
        value = color_name,
    }
end
table.sort(color_options, function(a, b) return a.text < b.text end)

local function get_color_options()
    return table.clone(color_options)
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            { setting_id = "base_color",  type = "dropdown", default_value = "green",  options = get_color_options() },
            { setting_id = "threshold_1", type = "numeric",  default_value = 100, range = {0, 100} },
            { setting_id = "color_1",     type = "dropdown", default_value = "green",  options = get_color_options() },
            { setting_id = "threshold_2", type = "numeric",  default_value = 75,  range = {0, 100} },
            { setting_id = "color_2",     type = "dropdown", default_value = "yellow", options = get_color_options() },
            { setting_id = "threshold_3", type = "numeric",  default_value = 50,  range = {0, 100} },
            { setting_id = "color_3",     type = "dropdown", default_value = "orange", options = get_color_options() },
            { setting_id = "threshold_4", type = "numeric",  default_value = 25,  range = {0, 100} },
            { setting_id = "color_4",     type = "dropdown", default_value = "red",    options = get_color_options() },
        }
    }
}