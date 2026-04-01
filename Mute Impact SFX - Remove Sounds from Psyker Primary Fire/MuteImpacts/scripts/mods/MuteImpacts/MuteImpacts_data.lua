local mod = get_mod("MuteImpacts")

-- ################################
-- Local References for Performance
-- ################################
local pairs = pairs
local ipairs = ipairs
local table = table
local table_insert = table.insert
local table_contains = table.contains

mod:io_dofile("MuteImpacts/scripts/mods/MuteImpacts/SoundsToMute")
local sounds_to_toggle = mod.sounds_to_toggle

-- ################################
-- Widget Creation
-- ################################
local final_widgets = {}

for _, setting_table in ipairs(sounds_to_toggle) do 
	table_insert(final_widgets, {
		setting_id = setting_table.internal_id,
        type = "checkbox",
        default_value = not setting_table.do_not_disable_by_default,
	})
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = final_widgets,
	},
}
