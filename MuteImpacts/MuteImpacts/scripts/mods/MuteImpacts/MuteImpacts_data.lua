local mod = get_mod("MuteImpacts")

-- ################################
-- Local References for Performance
-- ################################
local table = table
local table_insert = table.insert
local table_contains = table.contains

mod:io_dofile("MuteImpacts/scripts/mods/MuteImpacts/SoundsToMute")
local sounds_to_toggle = mod.sounds_to_toggle

-- ################################
-- Widget Creation
-- ################################
-- This is an overly complicated way of creating groups while keeping SoundsToMute as a 2d array
-- Basically, each sound has a "flag" for which group it should go in
-- 		Groups are created in final_widgets
--		then widget_group_name_map is string:int pairs associating the group name with where it would go in final_widgets (which is an array)
-- This unfortunately makes it awkward to pre-declare the table size
local final_widgets = Script.new_map( #sounds_to_toggle / 2 ) -- will have empty widgets at the end, but DMF ignores thoses
local widget_group_name_map = {}
local final_widgets_iterator = 1 -- Keep this at one. Iterate elsewhere for clarity

-- Staring with a "General Settings tab"
final_widgets[final_widgets_iterator] = {
	setting_id = "mod_option_group_mod_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "show_warning_skitussy_bubble_wrap",
			type = "checkbox",
			default_value = true,
		},
	},
}
final_widgets_iterator = final_widgets_iterator + 1

-- Adding settings for toggling sounds
for i = 1, #sounds_to_toggle do 
	local setting_table = sounds_to_toggle[i]
	local current_group_name = setting_table.group_name

	-- Have not created a group for this
	if not widget_group_name_map[current_group_name] then
		-- Creating the group
		final_widgets[final_widgets_iterator] = final_widgets[final_widgets_iterator] or {
			setting_id = current_group_name or "mod_option_group_misc",
			type = "checkbox",
			tooltip = "mod_option_tooltip_show_group",
			default_value = true,
			sub_widgets = {},
		}

		-- Putting the sound into the group
		table_insert(final_widgets[final_widgets_iterator].sub_widgets, {
			setting_id = setting_table.internal_id,
			tooltip = mod:localize("mod_option_tooltip_sound_event_prefix")..setting_table.sound_event,
			type = "checkbox",
			default_value = not setting_table.do_not_disable_by_default,
		})

		-- Making a reference to the group in the map, then preparing iterator for next group
		widget_group_name_map[current_group_name] = final_widgets_iterator
		final_widgets_iterator = final_widgets_iterator + 1
	else
		-- Putting the sound into the existing group
		local index_of_final_widget_to_use = widget_group_name_map[current_group_name]
		table_insert(final_widgets[index_of_final_widget_to_use].sub_widgets, {
			setting_id = setting_table.internal_id,
			tooltip = mod:localize("mod_option_tooltip_sound_event_prefix")..setting_table.sound_event,
			type = "checkbox",
			default_value = not setting_table.do_not_disable_by_default,
		})
	end
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = final_widgets,
	},
}
