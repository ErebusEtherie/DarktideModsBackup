local mod = get_mod("MuteImpacts")

-- ################################
-- Local References for Performance
-- ################################
local pairs = pairs
local table = table
local table_insert = table.insert

mod:io_dofile("MuteImpacts/scripts/mods/MuteImpacts/SoundsToMute")
local sounds_to_toggle = mod.sounds_to_toggle

-- ################################
-- Widget Creation
-- ################################
local final_widgets = {}
for setting_name, _ in pairs(sounds_to_toggle) do 
	table_insert(final_widgets, {
		setting_id = setting_name,
        type = "checkbox",
        default_value = true,
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
