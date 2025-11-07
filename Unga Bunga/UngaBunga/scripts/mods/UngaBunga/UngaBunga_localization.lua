local function cf(text, color_name)
	local color = Color[color_name](255, true)
	return string.format("{#color(%s,%s,%s)}", color[2], color[3], color[4]) .. text .. "{#color(203,203,203)}"
end

return {
	-- Mod Details
	mod_name = {
		en = "Unga Bunga",
		["zh-tw"] = "自動重擊",
	},
	mod_description = {
		en = "SMASHIN' EM UP GOOD, SAH",
		["zh-tw"] = "把他們狠狠砸爛，長官！",
	},
	-- Debug
	debug = {
		en = "Debug",
		["zh-tw"] = "除錯模式",
	},
	-- Groups
	global = {
		en = "Global Settings",
		["zh-tw"] = "全域設定",
	},
	keybinds = {
		en = "Keybind Settings",
		["zh-tw"] = "按鍵設定",
	},
	per_weapon = {
		en = "Individual Weapon Settings",
		["zh-tw"] = "個別武器設定",
	},
	-- Keybinds
	toggle_bind = {
		en = "Mod Toggle Keybind",
		["zh-tw"] = "模組開關按鍵",
	},
	toggle_bind_tooltip = {
		en = "When pressed, the mod's status (Enabled/Disabled) is inverted.",
		["zh-tw"] = "按下後，模組的狀態（啟用/禁用）將被反轉。",
	},
	toggle_bind_held = {
		en = "Mod Toggle Keybind (Held)",
		["zh-tw"] = "模組開關按鍵（長按）",
	},
	toggle_bind_held_tooltip = {
		en = "When pressed, the mod's status (Enabled/Disabled) is inverted; status is reverted when released.",
		["zh-tw"] = "按下後，模組的狀態（啟用/禁用）將被反轉；當釋放時，狀態將恢復。",
	},
	cancel_toggle_bind = {
		en = "Block/Special Cancel Keybind",
		["zh-tw"] = "阻擋/特殊取消按鍵",
	},
	cancel_toggle_bind_tooltip = {
		en = "When pressed, the mod will cancel heavy attack chains using blocks or special attacks.",
		["zh-tw"] = "按下後，模組將使用阻擋或特殊攻擊取消重型攻擊鏈。",
	},
	cancel_toggle_bind_held = {
		en = "Block/Special Cancel Keybind (Held)",
		["zh-tw"] = "阻擋/特殊取消按鍵（長按）",
	},
	cancel_toggle_bind_held_tooltip = {
		en = "When pressed, the mod will cancel heavy attack chains using blocks or special attacks; cancel behavior is reverted when released.",
		["zh-tw"] = "按下後，模組將使用阻擋或特殊攻擊取消重型攻擊鏈；當釋放時，取消行為將恢復。",
	},
	attack_bind = {
		en = "Attack Keybind (Held)",
		["zh-tw"] = "攻擊按鍵（長按）",
	},
	--[[ WIP ]
	attack_bind_toggle = {
		en = "Attack Keybind",
		["zh-tw"] = "攻擊按鍵",
	},
	--]]
	attack_bind_tooltip = {
		en = string.format("When pressed, the mod will manage heavy attacks as though the normal primary attack input is being pressed.\nIf this keybind is set, attacks made using the normal primary attack input are not modified by the mod.")
	},
	verbose = {
		en = "Notify on Toggle",
		["zh-tw"] = "開關通知",
	},
	verbose_tooltip = {
		en = "If enabled, a message will be displayed when non-held toggle keybinds are pressed.",
		["zh-tw"] = "若啟用，當非長按開關按鍵被按下時，將顯示一條消息。",
	},
	-- Global Settings
	general = {
		en = "General",
		["zh-tw"] = "一般設定",
	},
	enabled = {
		en = "Mod Enabled",
		["zh-tw"] = "模組啟用",
	},
	block_cancel = {
		en = "Block Cancel",
		["zh-tw"] = "阻擋取消",
	},
	block_cancel_tooltip = {
		en = "If enabled, the mod will block-cancel after attacks in order to only spam the first attack in the weapon's combo sequence.",
		["zh-tw"] = "若啟用，模組將在攻擊後阻擋取消，以便僅在武器的連擊序列中重複第一次攻擊。",
	},
	cancel = {
		en = "Block/Special Cancel",
		["zh-tw"] = "阻擋/特殊取消",
	},
	cancel_tooltip = {
		en = "If enabled, the mod will cancel heavy attack chains using blocks or special attacks.",
		["zh-tw"] = "若啟用，模組將使用阻擋或特殊攻擊取消重型攻擊鏈。",
	},
	cancel_mode = {
		en = "Cancel Mode",
		["zh-tw"] = "取消模式",
	},
	block = {
		en = "Block",
		["zh-tw"] = "阻擋",
	},
	special = {
		en = "Special",
		["zh-tw"] = "特殊",
	},
	-- Thrust Settings
	thrust = {
		en = "Thrust",
		["zh-tw"] = "推進",
	},
	max_stacks = {
		en = "Thrust Stacks",
		["zh-tw"] = "推進層數",
	},
	thrust_tooltip = {
		en = string.format("If set to 0 or thrust is not equipped, heavy attacks will initiate as soon as possible. Otherwise, they will be delayed until the specified number of stacks is reached.\n%s",
		cf("Also affects 'Slow and Steady' Blessing.","ui_disabled_text_color")),
		["zh-tw"] = string.format("若設為 0 或未裝備推進，重型攻擊將盡快啟動。否則，它們將延遲到達到指定的層數為止。\n%s",
		cf("也影響「緩慢而確實」祝福。","ui_disabled_text_color")),
	},
	stacks = {
		en = "Thrust Stacks",
		["zh-tw"] = "推進層數",
	},
	split_specials = {
		en = "Enable Special Thrust Stacks",
		["zh-tw"] = "啟用特殊推進層數",
	},
	split_specials_tooltip = {
		en = "If enabled, special attacks will use their own Thrust Stack settings, separate from regular attacks.",
		["zh-tw"] = "若啟用，特殊攻擊將使用獨立於一般攻擊的推進層數設定。",
	},
	max_special_stacks = {
		en = "Thrust Stacks (Special Attacks)",
		["zh-tw"] = "推進層數（特殊攻擊）",
	},
	thrust_special_tooltip = {
		en = "Functions identically to 'Thrust Stacks', but only applies to attacks made while in a weapon's 'special' state.",
		["zh-tw"] = "功能與「推進層數」相同，但僅適用於武器處於「特殊」狀態時的攻擊。",
	},
	-- Weapon Settings
	weapon_selector = {
		en = "Weapon Selection",
		["zh-tw"] = "武器選擇",
	},
	weapon_general = {
		en = "General",
		["zh-tw"] = "一般設定",
	},
	weapon_enabled = {
		en = "Weapon Override Enabled",
		["zh-tw"] = "武器覆蓋啟用",
	},
	weapon_enabled_tooltip = {
		en = "If enabled, these settings will be used instead of the global settings for the selected weapon.",
		["zh-tw"] = "若啟用，這些設定將用於所選武器，而不是全域設定。",
	},
	weapon_block_cancel = {
		en = "Block Cancel",
		["zh-tw"] = "阻擋取消",
	},
	weapon_cancel = {
		en = "Block/Special Cancel",
		["zh-tw"] = "阻擋/特殊取消",
	},
	weapon_cancel_mode = {
		en = "Cancel Mode",
		["zh-tw"] = "取消模式",
	},
	weapon_thrust = {
		en = "Thrust",
		["zh-tw"] = "推進",
	},
	weapon_max_stacks = {
		en = "Thrust Stacks",
		["zh-tw"] = "推進層數",
	},
	weapon_split_specials = {
		en = "Enable Special Thrust Stacks",
		["zh-tw"] = "啟用特殊推進層數",
	},
	weapon_max_special_stacks = {
		en = "Thrust Stacks (Special Attacks)",
		["zh-tw"] = "推進層數（特殊攻擊）",
	},
	reset_group = {
		en = "Reset Settings",
		["zh-tw"] = "重置設定",
	},
	reset = {
		en = "RESET ALL WEAPON SETTINGS",
		["zh-tw"] = "重置所有武器設定",
	},
	-- Weapon names
	-- OGRYN ONLY
	ogryn_combatblade_p1_m1 = {
		en = "Krourk Mk VI Cleaver",
		["zh-tw"] = "VI(六)型砍刀(克魯克)",
	},
	ogryn_combatblade_p1_m2 = {
		en = "Bull Butcher Mk III Cleaver",
		["zh-tw"] = "III(三)型砍刀(蠻牛屠夫)",
	},
	ogryn_combatblade_p1_m3 = {
		en = "Krourk Mk IV Cleaver",
		["zh-tw"] = "IV(四)型砍刀(克魯克)",
	},
	ogryn_gauntlet_p1_m1 = {
		en = "Blastoom Mk III Grenadier Gauntlet",
		["zh-tw"] = "III(三)型擲彈兵臂鎧(布拉斯托姆)",
	},
	ogryn_club_p1_m1 = {
		en = "Brute-Brainer Mk III Latrine Shovel",
		["zh-tw"] = "III(三)型廁所鏟(兇殘)",
	},
	ogryn_club_p1_m2 = {
		en = "Brute-Brainer Mk XIX Latrine Shovel",
		["zh-tw"] = "XIX(十九)型廁所鏟(兇殘)",
	},
	ogryn_club_p1_m3 = {
		en = "Brute-Brainer Mk V Latrine Shovel",
		["zh-tw"] = "V(五)型廁所鏟(兇殘)",
	},
	ogryn_club_p2_m1 = {
		en = "Brunt Special Mk I Bully Club",
		["zh-tw"] = "I(一)型惡霸棍棒(布倫特專用)",
	},
	ogryn_club_p2_m2 = {
		en = "Brunt's Pride Mk II Bully Club",
		["zh-tw"] = "II(二)型惡霸棍棒(布倫特得意之作)",
	},
	ogryn_club_p2_m3 = {
		en = "Brunt's Basher Mk IIIb Bully Club",
		["zh-tw"] = "IIIb(3B)型惡霸棍棒(布倫特猛擊)",
	},
	ogryn_pickaxe_2h_p1_m1 = {
		en = "Branx Mk Ia Pickaxe",
		["zh-tw"] = "Ia(1A)型戴維爾戰鎬(布蘭克斯)",
	},
	ogryn_pickaxe_2h_p1_m2 = {
		en = "Borovian Mk III Pickaxe",
		["zh-tw"] = "III(三)型戴維爾戰鎬(博羅維安)",
	},
	ogryn_pickaxe_2h_p1_m3 = {
		en = "Karsolas Mk II Pickaxe",
		["zh-tw"] = "II(二)型戴維爾戰鎬(卡索拉斯)",
	},
	ogryn_powermaul_p1_m1 = {
		en = "Achlys Mk I Power Maul",
		["zh-tw"] = "I(一)型動力鎚(阿克利斯)",
	},
	--[[ THESE WEAPONS AREN'T ACCESSIBLE IN-GAME YET
	ogryn_powermaul_p1_m2 = {
		en = "Ogrys Mk IIc Power Maul",
	},
	ogryn_powermaul_p1_m3 = {
		en = "??? Mk ??? Power Maul",
	},
	--]]
	ogryn_powermaul_slabshield_p1_m1 = {
		en = "Orox Mk II & Mk III Battle Maul & Slab Shield",
		["zh-tw"] = "Orox 第II(二)型 與 第III(三)型作戰大鎚與板盾",
	},
	-- PSYKER ONLY
	forcesword_p1_m1 = {
		en = "Obscurus Mk II Blaze Force Sword",
		["zh-tw"] = "II(二)型烈焰力場劍(朦朧)",
	},
	forcesword_p1_m2 = {
		en = "Deimos Mk IV Blaze Force Sword",
		["zh-tw"] = "IV(四)型烈焰力場劍(戴莫斯)",
	},
	forcesword_p1_m3 = {
		en = "Illsi Mk V Blaze Force Sword",
		["zh-tw"] = "V(五)型烈焰力場劍(伊利斯))",
	},
	forcesword_2h_p1_m1 = {
		en = "Covenant Mk VI Blaze Force Greatsword",
		["zh-tw"] = "VI(六)型烈焰力場巨劍(誓約)",
	},
	forcesword_2h_p1_m2 = {
		en = "Covenant Mk VIII Blaze Force Greatsword",
		["zh-tw"] = "VIII(八)型烈焰力場巨劍(誓約)",
	},
	-- VETERAN ONLY
	powersword_p1_m1 = {
		en = "Scandar Mk III Power Sword",
		["zh-tw"] = "III(三)型動力劍(斯干達)",
	},
	powersword_p1_m2 = {
		en = "Achlys Mk VI Power Sword",
		["zh-tw"] = "VI(六)型動力劍(阿克利斯)",
	},
	combataxe_p3_m1 = {
		en = "Munitorum Mk I Sapper Shovel",
		["zh-tw"] = "I(一)型工兵鏟(軍務部)",
	},
	combataxe_p3_m2 = {
		en = "Munitorum Mk III Sapper Shovel",
		["zh-tw"] = "III(三)型工兵鏟(軍務部)",
	},
	combataxe_p3_m3 = {
		en = "Munitorum Mk VII Sapper Shovel",
		["zh-tw"] = "VII(七)型工兵鏟(軍務部)",
	},
	-- ZEALOT ONLY
	chainsword_2h_p1_m1 = {
		en = "Tigrus Mk III Heavy Eviscerator",
		["zh-tw"] = "III(三)型重型開膛劍(泰格魯斯)",
	},
	chainsword_2h_p1_m2 = {
		en = "Tigrus Mk XV Heavy Eviscerator",
		["zh-tw"] = "XV(十五)型重型開膛劍(泰格魯斯)",
	},
	powermaul_2h_p1_m1 = {
		en = "Indignatus Mk IVe Crusher",
		["zh-tw"] = "IVe(4E)型碾壓者(憤怒)",
	},
	powersword_2h_p1_m1 = {
		en = "Munitorum Mk X Relic Blade",
		["zh-tw"] = "X(十)型上古神刃(軍務部)",
	},
	powersword_2h_p1_m2 = {
		en = "Munitorum Mk II Relic Blade",
		["zh-tw"] = "II(二)型上古神刃(軍務部)",
	},
	thunderhammer_2h_p1_m1 = {
		en = "Crucis Mk II Thunder Hammer",
		["zh-tw"] = "II(二)型雷鎚(十字星)",
	},
	thunderhammer_2h_p1_m2 = {
		en = "Ironhelm Mk IV Thunder Hammer",
		["zh-tw"] = "IV(四)型雷鎚(鐵盔)",
	},
	-- SHARED (HUMAN)
	chainaxe_p1_m1 = {
		en = "Orestes Mk IV Assault Chainaxe",
		["zh-tw"] = "IV(四)型突擊鏈斧(奧瑞斯特斯)",
	},
	chainaxe_p1_m2 = {
		en = "Orestes Mk XII Assault Chainaxe",
		["zh-tw"] = "XII(十二)型突擊鏈斧(奧瑞斯特斯)",
	},
	chainsword_p1_m1 = {
		en = "Cadia Mk IV Assault Chainsword",
		["zh-tw"] = "IV(四)型突擊鏈鋸劍(卡迪亞)",
	},
	chainsword_p1_m2 = {
		en = "Cadia Mk XIIIg Assault Chainsword",
		["zh-tw"] = "XIIIg(13G)型突擊鏈鋸劍(卡迪亞)",
	},
	combataxe_p1_m1 = {
		en = "Rashad Mk III Combat Axe",
		["zh-tw"] = "III(三)型戰鬥斧(拉沙德)",
	},
	combataxe_p1_m2 = {
		en = "Antax Mk V Combat Axe",
		["zh-tw"] = "V(五)型戰鬥斧(安塔克斯)",
	},
	combataxe_p1_m3 = {
		en = "Achlys Mk VIII Combat Axe",
		["zh-tw"] = "VIII(八)型戰鬥斧(阿克利斯)",
	},
	combataxe_p2_m1 = {
		en = "Atrox Mk II Tactical Axe",
		["zh-tw"] = "II(二)型戰術斧(埃托克斯)",
	},
	combataxe_p2_m2 = {
		en = "Atrox Mk IV Tactical Axe",
		["zh-tw"] = "IV(四)型戰術斧(埃托克斯)",
	},
	combataxe_p2_m3 = {
		en = "Atrox Mk VII Tactical Axe",
		["zh-tw"] = "VII(七)型戰術斧(埃托克斯)",
	},
	combatknife_p1_m1 = {
		en = "Catachan Mk III Combat Knife",
		["zh-tw"] = "III(三)型戰刃(卡塔昌)",
	},
	combatknife_p1_m2 = {
		en = "Catachan Mk VI Combat Knife",
		["zh-tw"] = "VI(六)型戰刃(卡塔昌)",
	},
	combatsword_p1_m1 = {
		en = "Catachan Mk I 'Devil's Claw' Sword",
		["zh-tw"] = "I(一)型「惡魔之爪」劍(卡塔昌)",
	},
	combatsword_p1_m2 = {
		en = "Catachan Mk IV 'Devil's Claw' Sword",
		["zh-tw"] = "IV(四)型「惡魔之爪」劍(卡塔昌)",
	},
	combatsword_p1_m3 = {
		en = "Catachan Mk VII 'Devil's Claw' Sword",
		["zh-tw"] = "VII(七)型「惡魔之爪」劍(卡塔昌)",
	},
	combatsword_p2_m1 = {
		en = "Turtolsky Mk VI Heavy Sword",
		["zh-tw"] = "VI(六)型重劍(圖妥斯基)",
	},
	combatsword_p2_m2 = {
		en = "Turtolsky Mk VII Heavy Sword",
		["zh-tw"] = "VII(七)型重劍(圖妥斯基)",
	},
	combatsword_p2_m3 = {
		en = "Turtolsky Mk IX Heavy Sword",
		["zh-tw"] = "IX(九)型重劍(圖妥斯基)",
	},
	combatsword_p3_m1 = {
		en = "Maccabian Mk II Duelling Sword",
		["zh-tw"] = "II(二)型決鬥劍(馬卡比安)",
	},
	combatsword_p3_m2 = {
		en = "Maccabian Mk IV Duelling Sword",
		["zh-tw"] = "IV(四)型決鬥劍(馬卡比安)",
	},
	combatsword_p3_m3 = {
		en = "Maccabian Mk V Duelling Sword",
		["zh-tw"] = "V(五)型決鬥劍(馬卡比安)",
	},
	powermaul_p1_m1 = {
		en = "Agni Mk Ia Shock Maul",
		["zh-tw"] = "Ia(1A)型電擊錘(阿格尼)",
	},
	powermaul_p1_m2 = {
		en = "Munitorum Mk III Shock Maul",
		["zh-tw"] = "III(三)型電擊錘(軍務部)",
	},
}


