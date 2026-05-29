-- salvage_data.lua
local mod = get_mod("salvage")

local player_dropped_remnants_widget = {
setting_id = "mark_player_dropped_remnants",
type = "checkbox",
default_value = true,
}

local player_drop_warning_widget = {
setting_id = "player_drop_warning",
type = "checkbox",
default_value = false,
}

local fallen_comrades_widget = {
setting_id = "mark_fallen_comrades",
type = "dropdown",
default_value = "never",
options = {
{ text = "fallen_marker_never", value = "never" },
{ text = "fallen_marker_dead_only", value = "dead_only" },
{ text = "fallen_marker_downed_only", value = "downed_only" },
{ text = "fallen_marker_disabled_only", value = "disabled_only" },
{ text = "fallen_marker_dead_or_downed", value = "dead_or_downed" },
{ text = "fallen_marker_all", value = "all" },
},
}

local early_evacuation_warning_widget = {
setting_id = "warn_early_evacuation",
type = "checkbox",
default_value = true,
tooltip = "warn_early_evacuation_tooltip",
}

local reliquary_widget = {
setting_id = "enable_reliquaries",
type = "checkbox",
default_value = true,
tooltip = "enable_reliquaries_tooltip",
}

local salvage_widget = {
setting_id = "enable_salvage",
type = "checkbox",
default_value = true,
sub_widgets = {
{
setting_id = "salvage_blue_decal",
type = "checkbox",
default_value = true,
},
{
setting_id = "salvage_fire_360angle_01",
type = "checkbox",
default_value = false,
},
{
setting_id = "salvage_fire_trail_01",
type = "checkbox",
default_value = true,
},
{
setting_id = "salvage_staggering_pulse",
type = "checkbox",
default_value = false,
},
{
setting_id = "salvage_electricity_grenade_01",
type = "checkbox",
default_value = false,
},
{
setting_id = "salvage_daemonhost_shield",
type = "checkbox",
default_value = false,
},
},
}

local tech_remnants_widget = {
setting_id = "enable_tech_remnants",
type = "checkbox",
default_value = true,
sub_widgets = {
{
setting_id = "tech_remnants_green_decal",
type = "checkbox",
default_value = true,
},
{
setting_id = "tech_remnants_fire_360angle_01",
type = "checkbox",
default_value = false,
},
{
setting_id = "tech_remnants_fire_trail_01",
type = "checkbox",
default_value = false,
},
{
setting_id = "tech_remnants_staggering_pulse",
type = "checkbox",
default_value = false,
},
{
setting_id = "tech_remnants_electricity_grenade_01",
type = "checkbox",
default_value = false,
},
{
setting_id = "tech_remnants_daemonhost_shield",
type = "checkbox",
default_value = true,
},
},
}

local exit_widget = {
setting_id = "use_exit_icon",
type = "checkbox",
default_value = false,
sub_widgets = {
{
setting_id = "show_distance",
type = "checkbox",
default_value = true,
},
{
setting_id = "hide_if_close_to_exit_location",
type = "checkbox",
default_value = true,
tooltip = "hide_if_close_to_exit_location_tooltip",
},
{
setting_id = "three_mins_to_go",
type = "checkbox",
default_value = false,
tooltip = "three_mins_to_go_tooltip",
},
{
setting_id = "field_of_view",
type = "checkbox",
default_value = false,
tooltip = "field_of_view_tooltip",
},
},
}

return {
name = mod:localize("mod_name"),
description = mod:localize("mod_description"),
is_togglable = true,
options = {
widgets = {
player_dropped_remnants_widget,
player_drop_warning_widget,
early_evacuation_warning_widget,
reliquary_widget,
salvage_widget,
tech_remnants_widget,
exit_widget,
fallen_comrades_widget,
},
},
}
