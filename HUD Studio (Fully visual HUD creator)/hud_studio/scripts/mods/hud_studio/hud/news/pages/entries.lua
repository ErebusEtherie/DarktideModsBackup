---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Page = mod:core(mod.hud_studio_news_page_data, "hud/news/pages/page_data")

return {

	Page.new({
		version = 1.3,
		major = true,
		date = "2026-09-12",
		title = "Undo and Redo Update",
		lines = {
			"New: `Portrait (No Frame)` icon field",
		},
		features = {
			{
				name = "Undo and Redo",
				lines = {
					"Press `CTRL + Z` to **undo**",
					"Press `CTRL + SHIFT + Z` to **redo**",
					"You'll be notified when you undo/redo",
				},
			},
			{
				name = "News Page",
				lines = {
					"This page will open **once**, when you attempt to open the editor after an update",
					"Go to the **settings to disable these entirely**, or assign a **bind to open the view on demand**.",
				},
			},
		},
		bug_fixes = {
			"Fixed `Skitarii Servo Skull` Blitz icons not displaying",
		},
	}),
	Page.new({
		version = "1.2.8.1",
		date = "2026-09-12",
		title = "Minor Update",
		lines = {
			"New: `Progress to Max Charges %`",
		},
	}),

	Page.new({
		version = "1.2.8.1",
		date = "2026-09-12",
		title = "Minor Update",

		bug_fixes = {
			"Fixed icons and levels not working for players 2..4",
		},
		lines = {
			"New: `Special Charge Seconds Remaining` and `Special Charge Progress [%]`",
		},
	}),

	Page.new({
		version = "0-0-0-0",
		date = "....-..-..",
		title = "- Version History Starts Here -",
	}),
}
