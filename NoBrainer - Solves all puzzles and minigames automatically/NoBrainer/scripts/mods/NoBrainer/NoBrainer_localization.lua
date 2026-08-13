local mod = get_mod("NoBrainer")

-- Traditional Chinese translation by SyuanTsai:
-- https://github.com/SyuanTsai/Warhammer-40-000-DARKTIDE-Mods
local localizations = {
	mod_name           = { en = "No Brainer", ["zh-tw"] = "免動腦" },
	mod_description    = { en = "Automates and enhances all Darktide minigames: Decode Symbols, Decode Search, Auspex Scan, Train Balance, Tree Drill, and Frequency Matching.", ["zh-tw"] = "自動化並強化 Darktide 所有小遊戲：符號解碼、搜尋解碼、占卜儀掃描、列車平衡、樹狀鑽探與頻率配對。" },
	language           = { en = "Language", ["zh-tw"] = "語言" },
	language_tooltip   = { en = "Select Automatic to follow the game's language. Manual Traditional Chinese requires Darktide's language to also be set to Traditional Chinese so the game loads a font with Chinese characters. Otherwise, the text may appear as squares. Restart the game after changing this setting.", ["zh-tw"] = "選擇自動以跟隨遊戲語言。手動選擇繁體中文時，Darktide 的語言也必須設為繁體中文，遊戲才會載入支援中文字元的字型，否則文字可能顯示為方框。變更此設定後請重新啟動遊戲。" },
	language_auto      = { en = "Automatic (Game Language)", ["zh-tw"] = "自動（遊戲語言）" },
	language_en        = { en = "English", ["zh-tw"] = "English" },
	language_zh_tw     = { en = "Traditional Chinese", ["zh-tw"] = "繁體中文" },
	servo_skull_group = { en = "Servo Skull", ["zh-tw"] = "伺服顱骨" },
	enable_servo_skull_auto_hack = { en = "Auto-Start Hacking", ["zh-tw"] = "自動開始駭入" },
	enable_servo_skull_auto_hack_tooltip = { en = "Automatically orders the Skitarius hacking servo skull to the nearest available minigame within the configured command range.", ["zh-tw"] = "在設定的指令範圍內，自動命令 Skitarius 的駭入伺服顱骨前往最近可用的小遊戲。" },
	servo_skull_require_line_of_sight = { en = "Require Line of Sight", ["zh-tw"] = "需要視線" },
	servo_skull_require_line_of_sight_tooltip = { en = "When enabled, the minigame must be visible before the servo skull is ordered. Disable to allow orders through walls, floors, and ceilings.", ["zh-tw"] = "啟用時，必須能直接看見小遊戲才會對伺服顱骨下達指令。停用後可穿過牆壁、地板與天花板下達指令。" },
	servo_skull_command_range = { en = "Command Range", ["zh-tw"] = "指令範圍" },
	servo_skull_command_range_tooltip = { en = "Maximum automatic command distance in metres. Defaults to the servo skull ability's normal 25-metre targeting range.", ["zh-tw"] = "自動下達指令的最大距離（公尺）。預設為伺服顱骨能力的一般 25 公尺鎖定範圍。" },

	decode_symbols_group      = { en = "Decode Symbols", ["zh-tw"] = "符號解碼" },
	enable_decode_highlight   = { en = "Highlight Solution", ["zh-tw"] = "標示解答" },
	enable_decode_highlight_tooltip = { en = "Highlights the correct columns for upcoming rows.", ["zh-tw"] = "標示接下來列的正確欄位。" },
	enable_decode_auto        = { en = "Auto-Solve", ["zh-tw"] = "自動解題" },
	enable_decode_auto_tooltip = { en = "Automatically presses interact when the cursor is on target.", ["zh-tw"] = "游標位於目標上時自動按下互動鍵。" },

	matching_group            = { en = "Decode Search (Matching)", ["zh-tw"] = "搜尋解碼（配對）" },
	enable_matching              = { en = "Highlight Match", ["zh-tw"] = "標示配對" },
	enable_matching_tooltip      = { en = "Highlights the region on the board that matches the target pattern.", ["zh-tw"] = "標示面板上符合目標圖案的區域。" },
	enable_expedition_auto_solve       = { en = "Auto-Solve", ["zh-tw"] = "自動解題" },
	enable_expedition_auto_solve_tooltip = { en = "Automatically moves the cursor to the target and submits.", ["zh-tw"] = "自動將游標移至目標並提交。" },
	expedition_solve_speed             = { en = "Auto-Solve Speed", ["zh-tw"] = "自動解題速度" },
	expedition_solve_speed_tooltip     = { en = "Auto-solve pace (1=moderate, 5=fastest). Every speed uses the same precise solver and diagonal movement.", ["zh-tw"] = "自動解題速度（1＝適中，5＝最快）。所有速度都使用相同的精準解題器與對角移動。" },

	scan_group                = { en = "Auspex Scan", ["zh-tw"] = "占卜儀掃描" },
	enable_scan               = { en = "Mark Scannable Objects", ["zh-tw"] = "標記可掃描物件" },
	enable_scan_tooltip       = { en = "Applies outline and highlight to scannable objects during auspex scanning.", ["zh-tw"] = "使用占卜儀掃描時，為可掃描物件套用輪廓與標示。" },
	enable_auto_scan          = { en = "Auto-Scan", ["zh-tw"] = "自動掃描" },
	enable_auto_scan_tooltip  = { en = "Automatically holds the scan action until completion when an active target is in range and line of sight.", ["zh-tw"] = "當啟用中的掃描目標進入範圍且位於視線內時，自動按住掃描動作直到完成。" },

	balance_group             = { en = "Train (Balance)", ["zh-tw"] = "列車（平衡）" },
	enable_balance            = { en = "Auto-Balance", ["zh-tw"] = "自動平衡" },
	enable_balance_tooltip    = { en = "Automatically steers the dot toward the center.", ["zh-tw"] = "自動將圓點導向中央。" },

	frequency_group                       = { en = "Frequency Matching", ["zh-tw"] = "頻率配對" },
	enable_frequency_highlight            = { en = "Show Directional Arrows", ["zh-tw"] = "顯示方向箭頭" },
	enable_frequency_highlight_tooltip    = { en = "Displays orange arrows indicating which direction to push the waveform toward the target.", ["zh-tw"] = "顯示橘色箭頭，指示應將波形往哪個方向推向目標。" },
	enable_frequency_auto                 = { en = "Auto-Solve", ["zh-tw"] = "自動解題" },
	enable_frequency_auto_tooltip         = { en = "Automatically steers the waveform toward the target and submits when aligned.", ["zh-tw"] = "自動將波形導向目標，對齊後提交。" },
	frequency_solve_speed                 = { en = "Auto-Solve Speed", ["zh-tw"] = "自動解題速度" },
	frequency_solve_speed_tooltip         = { en = "Auto-solve pace (1=normal manual pace, 5=fastest). Every speed uses the same precise deterministic steering.", ["zh-tw"] = "自動解題速度（1＝一般手動速度，5＝最快）。所有速度都使用相同的精準固定導引。" },

	drill_group               = { en = "Tree (Drill)", ["zh-tw"] = "樹狀圖（鑽探）" },
	enable_drill              = { en = "Highlight Correct Target", ["zh-tw"] = "標示正確目標" },
	enable_drill_tooltip      = { en = "Shows which node is the correct one by highlighting it white.", ["zh-tw"] = "將正確節點標示為白色。" },
	enable_drill_auto         = { en = "Auto-Solve", ["zh-tw"] = "自動解題" },
	enable_drill_auto_tooltip = { en = "Automatically moves to the correct node and submits.", ["zh-tw"] = "自動移至正確節點並提交。" },
	drill_solve_speed         = { en = "Auto-Solve Speed", ["zh-tw"] = "自動解題速度" },
	drill_solve_speed_tooltip = { en = "Auto-solve pace (1=normal manual pace, 5=fastest). Every speed uses the same precise solver.", ["zh-tw"] = "自動解題速度（1＝一般手動速度，5＝最快）。所有速度都使用相同的精準解題器。" },

}

local language = mod:get("language")
if language == "en" or language == "zh-tw" then
	for _, translations in pairs(localizations) do
		translations.en = translations[language] or translations.en
		translations["zh-tw"] = nil
	end
end

return localizations
