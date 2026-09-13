---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local description = mod.dl.loc_helpers.description

local mint_green = { 255, 41, 255, 224 }

return {
	mod_name = {
		en = mod.dl.str.rich_text(" HUD Studio", { color = mint_green }),
	},
	mod_ver = {
		en = "1.3",
	},
	mod_description = {
		en = description("Build your own HUD using a fully visual editor and integrated code editor."),
	},

	settings_group_editor_group = {
		en = "Editor",
	},
	settings_group_news_group = {
		en = "Mod News",
	},
	settings_group_debug = {
		en = "Debug",
	},

	news_section_features = {
		en = "Features",
	},
	news_section_breaking_changes = {
		en = "Breaking Changes",
	},
	news_section_bug_fixes = {
		en = "Bug Fixes",
	},
	news_section_hotfixes = {
		en = "Hotfixes",
	},
	news_close_hint = {
		en = "Click anywhere to close",
	},
}
