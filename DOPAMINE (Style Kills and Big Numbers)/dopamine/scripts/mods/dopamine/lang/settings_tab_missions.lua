
local mod = get_mod("dopamine")

local lines, important = mod.dl.loc_helpers.lines, mod.dl.loc_helpers.important

return {
	tab_missions = {
		en = "MISSIONS",
	},
	heading_missions = {
		en = "Missions",
	},
	enable_mission_summary = {
		en = "Enable Mission Summary",
	},
	enable_mission_summary_description = {
		en = "Toggles whether the mission summary is shown at the end of each mission",
	},
	heading_danger_zone = {
		en = important("Danger Zone"),
	},
	heading_danger_zone_description = {
		en = "Here you can wipe your mission history. This will wipe all mission stats saved by Dopamine, which you access in the 'Missions' menu. This is irreversible.",
	},
	confirmed = {
		en = "I understand this is completely irreversible",
		["zh-cn"] = "",
	},
	unconfirmed = {
		en = "- Select -",
		["zh-cn"] = "",
	},
	wipe_history_confirmation = {
		en = "Confirm you want to do delete your data",
	},
	wipe_history = {
		en = "Delete My Dopamine Mission Data (Irreversible)",
	},
}
