local mod = get_mod("RecolorBossHealthBars")

mod.default_color = { 255, 255, 0, 0 }

local unit_type_array = {
	"daemonhost",
	"hex_dh",
	"captain",
	"twins",
	"weakened",
	"others"
}

local default_colors = function(unit_type)
    if unit_type == "daemonhost" or unit_type == "hex_dh" then
        return({
            r = 202,
            g = 62,
            b = 255,
        })
    elseif unit_type == "captain" then
        return({
            r = 66,
            g = 190,
            b = 66,
        })
    elseif unit_type == "twins" then
        return({
            r = 212,
            g = 212,
            b = 0,
        })
    elseif unit_type == "weakened" then
        return({
            r = 255,
            g = 122,
            b = 0,
        })
    elseif unit_type == "dying_boss" then
        return({
            r = 255,
            g = 255,
            b = 255,
        })
    else
		return({
            r = 255,
            g = 0,
            b = 0,
        })
	end
end

local color_widget = function(unit_type)
    local res = {
        setting_id = "color_"..unit_type,
        type = "group",
        sub_widgets = { }
    }
    if unit_type ~= "others" then
        table.insert(res.sub_widgets, {
            setting_id = "color_"..unit_type.."_toggle",
            tooltip = "tooltip_color_toggle",
            type = "checkbox",
            default_value = true,
        }) 
    end
    for _, col in pairs({"r","g","b"}) do
        table.insert(res.sub_widgets, {
            setting_id = "color_"..unit_type.."_"..col,
            type = "numeric",
            default_value = default_colors(unit_type)[col],
            range = {0, 255},
        })
    end
    return(res)
end

local dying_boss_toggle_widget_per_type = function(unit_type)
-- An on/off toggle for whether the health bars of a given unit type should be recolored when they're dying
-- Only called for dh, hexdh, captain, and twins
    return {
        setting_id = "dying_color_toggle_"..unit_type,
        tooltip = "tooltip_dying_color_toggle", -- Need loc
        type = "checkbox",
        default_value = true,
    }
end

local dying_boss_toggles_widget = {
    setting_id = "dying_boss_toggles",
    type = "group",
    sub_widgets = { }
}
--for _, unit_type in pairs({"daemonhost", "hex_dh", "captain", "twins"}) do
-- The health bars of captains and twins seem to disappear instantly when they die
for _, unit_type in pairs({"daemonhost", "hex_dh"}) do
    table.insert(dying_boss_toggles_widget.sub_widgets, dying_boss_toggle_widget_per_type(unit_type))
end

local dying_boss_color_widget = {
    setting_id = "dying_boss_color",
    type = "group",
    sub_widgets = { }
}
for _, col in pairs({"r","g","b"}) do
    -- The color that the health bar of chosen bosses will have during their dying animation
    table.insert(dying_boss_color_widget.sub_widgets, {
        setting_id = "dying_boss_color_"..col,
        --tooltip = "tooltip_dying_boss_color", -- Need loc
        type = "numeric",
        default_value = default_colors("dying_boss")[col],
        range = {0, 255},
    })
end

local lines_widget = {
    setting_id = "lines_amount",
    tooltip = "tooltip_lines_amount",
    type = "numeric",
    default_value = 3,
    range = {1,6},
}

local columns_dropdown = { }
for _, i in pairs({
    "two",
    "four"
}) do
    table.insert(columns_dropdown, {text = i, value = i})
end
local columns_widget = {
    setting_id = "columns_amount",
    --tooltip = "tooltip_columns_amount",
    type = "dropdown",
    default_value = "four",
    options = table.clone(columns_dropdown),
}


-----------------------
-- Creating the widgets

local widgets = {}
mod.setting_names = {}

table.insert(widgets, lines_widget)
table.insert(mod.setting_names, "lines_amount")

table.insert(widgets, columns_widget)
table.insert(mod.setting_names, "columns_amount")

for _, unit_type in pairs(unit_type_array) do
    -- Add widget
	table.insert(widgets, color_widget(unit_type))
    -- Record setting names for caching
    table.insert(mod.setting_names, "color_"..unit_type)
    for _, col in pairs({"toggle", "r","g","b"}) do
        table.insert(mod.setting_names, "color_"..unit_type.."_"..col)
    end
end

table.insert(widgets, dying_boss_toggles_widget)
--for _, unit_type in pairs({"daemonhost", "hex_dh", "captain", "twins"}) do
-- The health bars of captains and twins seem to disappear instantly when they die
for _, unit_type in pairs({"daemonhost", "hex_dh"}) do
    table.insert(mod.setting_names, "dying_color_toggle_"..unit_type)
end

table.insert(widgets, dying_boss_color_widget)
for _, col in pairs({"toggle", "r","g","b"}) do
    table.insert(mod.setting_names, "dying_boss_color_"..col)
end

table.insert(widgets, {
    setting_id = "debugging",
    tooltip = "tooltip_debugging", -- Need loc
    type = "checkbox",
    default_value = false,
})
table.insert(mod.setting_names, "debugging")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
    options = {
        widgets = widgets
    }
}
