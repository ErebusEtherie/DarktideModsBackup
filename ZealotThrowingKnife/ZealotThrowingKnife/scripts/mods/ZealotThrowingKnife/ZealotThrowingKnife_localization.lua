local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local mod = get_mod("ZealotThrowingKnife")

local localizations = {
	mod_name = {
		en = "Zealot Auto Throwing Knife",
		["zh-tw"] = "狂信徒自動投擲飛刀",
		["zh-cn"] = "狂信徒自动投掷飞刀",
	},
	mod_description = {
		en = "Automatically throw knife when switching to ranged weapons as Zealot while holding a throwing knife.",
		["zh-tw"] = "當狂信徒持有投擲飛刀時，切換到遠程武器時自動投擲飛刀。",
		["zh-cn"] = "当狂信徒持有投掷飞刀时，切换到远程武器时自动投掷飞刀。",
	},
	-- Global settings
	mod_enabled = {
		en = "Mod Enabled",
		["zh-tw"] = "啟用模組",
		["zh-cn"] = "启用模组",
	},
	mod_enabled_tooltip = {
		en = "Toggle the entire mod on or off",
		["zh-tw"] = "開啟或關閉整個模組",
		["zh-cn"] = "开启或关闭整个模组",
	},
	mod_enable_toggle = {
		en = "Toggle Key",
		["zh-tw"] = "切換鍵",
		["zh-cn"] = "切换键",
	},
	mod_enable_toggle_tooltip = {
		en = "Keybind to quickly toggle the mod on or off",
		["zh-tw"] = "快速開啟或關閉模組的按鍵綁定",
		["zh-cn"] = "快速开启或关闭模组的按键绑定",
	},
	switch_ranged_no_throw = {
		en = "Switch to Ranged (No Throw)",
		["zh-tw"] = "切換到遠程武器（不投擲）",
		["zh-cn"] = "切换到远程武器（不投掷）",
	},
	switch_ranged_no_throw_tooltip = {
		en = "Switch to ranged weapon without auto-throwing knife. Only works for weapons with auto-throw enabled.",
		["zh-tw"] = "切換到遠程武器但不自動投擲飛刀。僅對啟用了自動投擲的武器生效。",
		["zh-cn"] = "切换到远程武器但不自动投掷飞刀。仅对启用了自动投掷的武器生效。",
	},
	mod_enable_verbose = {
		en = "Enable Notifications",
		["zh-tw"] = "啟用通知",
		["zh-cn"] = "启用通知",
	},
	mod_enable_verbose_tooltip = {
		en = "Show notifications when toggling the mod",
		["zh-tw"] = "切換模組時顯示通知",
		["zh-cn"] = "切换模组时显示通知",
	},
	mod_enable_debug = {
		en = "Enable Debug Mode",
		["zh-tw"] = "啟用調試模式",
		["zh-cn"] = "启用调试模式",
	},
	mod_enable_debug_tooltip = {
		en = "Show detailed debug logs in the console",
		["zh-tw"] = "在控制台顯示詳細的調試日誌",
		["zh-cn"] = "在控制台显示详细的调试日志",
	},
	-- Mod Control Settings
	mod_control_settings = {
		en = "MOD CONTROL SETTINGS",
		["zh-tw"] = "模組啟停設定",
		["zh-cn"] = "模组启停设置",
	},
	-- Global settings
	global_settings = {
		en = "Mod Settings",
		["zh-tw"] = "模組設定",
		["zh-cn"] = "模组设置",
	},
	-- Debug
	enable_debug = {
		en = "DEBUG MODE",
		["zh-tw"] = "開發模式",
		["zh-cn"] = "调试模式",
	},
	enable_debug_tooltip = {
		en = "Enable debug logging to console. Use for troubleshooting.",
		["zh-tw"] = "啟用控制台調試日誌，用於故障排查。",
		["zh-cn"] = "启用控制台调试日志，用于故障排查。",
	},
	-- Keybinds
	mod_settings = {
		en = "MOD SETTINGS",
		["zh-tw"] = "模組啟停設定",
		["zh-cn"] = "模组启停设置",
	},
	mod_enable_held = {
		en = "TOGGLE MOD (HELD)",
		["zh-tw"] = "切換模組啟停（按住）",
		["zh-cn"] = "切换模组启停（按住）",
	},
	mod_enable_pressed = {
		en = "TOGGLE MOD (PRESSED)",
		["zh-tw"] = "切換模組啟停（按下）",
		["zh-cn"] = "切换模组启停（按下）",
	},
	-- Weapon Settings
	weapon_settings = {
		en = "WEAPON SETTINGS",
		["zh-tw"] = "武器設定",
		["zh-cn"] = "武器设置",
	},
	global_enabled = {
		en = "ENABLE MOD",
		["zh-tw"] = "啟用模組",
		["zh-cn"] = "启用模组",
	},
	group_stubrevolver = {
		en = "STUB REVOLVER",
		["zh-tw"] = "短管左輪",
		["zh-cn"] = "短管左轮",
	},
	group_shotgun = {
		en = "SHOTGUNS",
		["zh-tw"] = "霰彈槍",
		["zh-cn"] = "霰弹枪",
	},
	group_laspistol = {
		en = "LASPISTOL",
		["zh-tw"] = "激光手槍",
		["zh-cn"] = "激光手枪",
	},
	group_lasgun = {
		en = "LASGUN",
		["zh-tw"] = "激光槍",
		["zh-cn"] = "激光枪",
	},
	group_flamer = {
		en = "FLAMER",
		["zh-tw"] = "火焰噴射器",
		["zh-cn"] = "火焰喷射器",
	},
	group_bolter = {
		en = "BOLTER",
		["zh-tw"] = "爆彈槍",
		["zh-cn"] = "爆弹枪",
	},
	group_boltpistol = {
		en = "BOLTPISTOL",
		["zh-tw"] = "爆彈手槍",
		["zh-cn"] = "爆弹手枪",
	},
	group_autopistol = {
		en = "AUTOPISTOL",
		["zh-tw"] = "自動手槍",
		["zh-cn"] = "自动手枪",
	},
	group_autogun = {
		en = "AUTOGUN",
		["zh-tw"] = "自動步槍",
		["zh-cn"] = "自动步枪",
	},
	reset_all_enabled = {
		en = "ENABLE ALL WEAPONS",
		["zh-tw"] = "啟用所有武器",
		["zh-cn"] = "启用所有武器",
	},
	disable_all_enabled = {
		en = "DISABLE ALL WEAPONS",
		["zh-tw"] = "禁用所有武器",
		["zh-cn"] = "禁用所有武器",
	},
}

--------------------------------------------------------------------------
-- Auto-generate weapon localizations using Skitarius method
--------------------------------------------------------------------------

local family_prefix = "loc_weapon_family_"
local pattern_prefix = "loc_weapon_pattern_"
local mark_prefix = "loc_weapon_mark_"
local Localize = Localize

for weapon, _ in pairs(WeaponTemplates) do
    local localized_family = Localize(family_prefix .. weapon)
    local localized_pattern = Localize(pattern_prefix .. weapon)
    if not localized_pattern or string.find(localized_pattern, "unlocalized") then
        -- Some weapons use WRONG WEAPON NAME for localization because whoever changed how data is stored in this update is a moron
        local alt_pattern = weapon:gsub("_m%d+", "_m1") -- fallback to first mark
        localized_pattern = Localize(pattern_prefix .. alt_pattern)
    end
    local localized_mark = Localize(mark_prefix .. weapon)
    local localized = localized_family and localized_pattern and localized_mark and string.format("%s %s %s", localized_pattern, localized_mark, localized_family)
    if localized and not string.find(localized, "unlocalized") then
        localizations[weapon] = {
            en = localized
        }
    end
end

return localizations
