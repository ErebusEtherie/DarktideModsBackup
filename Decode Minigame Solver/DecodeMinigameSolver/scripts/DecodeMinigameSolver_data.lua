--[[
    Author: Igromanru
    Date: 20.11.2024
    Mod Name: Decode Minigame Solver
]]
local mod = get_mod("DecodeMinigameSolver")

local SettingNames = mod:io_dofile("DecodeMinigameSolver/scripts/setting_names")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets =
		{
			{
				setting_id = SettingNames.EnableMod,
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = SettingNames.InteractCooldown,
				tooltip = SettingNames.InteractCooldownTooltip,
				type = "numeric",
				default_value = 150,
				range = { 50, 300 },
				decimals_number = 0
			},
			{
				setting_id = SettingNames.TargetPrecision,
				tooltip = SettingNames.TargetPrecisionTooltip,
				type = "numeric",
				default_value = 4,
				range = { 1, 4 },
				decimals_number = 0
			},
		},
	},
}
