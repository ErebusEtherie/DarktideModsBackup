---@type mod
local mod = get_mod("dopamine")

mod:io_dofile("dopamine/scripts/mods/dopamine/bootstrap")

local files = {
	"events",
	"fury_levels",
	"labels",
	"mod",
	"global_stats",
	"breeds_shortnames",

	"settings_tab_missions",
	"settings_tab_accessibility",
	"settings_tab_difficulty",
	"settings_tab_performance",
	"settings_tab_layout",
	"settings_mission_summary",
	"settings_tab_customisation",
	"settings_tab_fonts",
	"settings_tab_fury_and_fatigue",
	"settings_tab_fine_tuning",
	"settings_tab_debug",
}

local localization = {}

for i = 1, #files do
	local lang_table = mod:io_dofile("dopamine/scripts/mods/dopamine/lang/" .. files[i])

	mod.dl.loc_helpers.merge_localization(localization, lang_table)
end

mod.dl.loc_helpers.insert_font_type_localisation(localization)

localization.mod_version = { en = "1.8" }

return localization
