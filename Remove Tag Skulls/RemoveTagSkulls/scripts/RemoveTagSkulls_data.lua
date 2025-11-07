--[[
    Author: Igromanru
    Mod Name: Remove Tag Skulls
]]
local mod = get_mod("RemoveTagSkulls")

local SettingNames = mod:io_dofile("RemoveTagSkulls/scripts/setting_names")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets =
		{
			{
				setting_id = SettingNames.RemoveTagSkull,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = SettingNames.RemoveVeteranTagSkull,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = SettingNames.RemoveAdamantTagSkull,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = SettingNames.KeepDaemonhostMarker,
				type = "checkbox",
				default_value = true
			},
		},
	},
}
