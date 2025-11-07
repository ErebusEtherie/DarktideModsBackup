local Breeds = require("scripts/settings/breed/breeds")

-- Chinese localization provided by jcyl2023
localization = {
    -- Mod Info
    mod_description = {
        en = "For my Beloved!",
        ["zh-tw"] = "獻給我摯愛的人！",
        ["zh-cn"] = "独一无二的小真寻",
    },
    mod_name = {
        en = "Emperor's Guidance",
        ["zh-tw"] = "皇帝的指引",
        ["zh-cn"] = "捏头目标过滤",
    },
    enable_tooltip = {
        en = "Enable/Disable all enemies in this group.",
        ["zh-tw"] = "啟用/停用此組所有敵人。",
        ["zh-cn"] = "启用/停用此组敌人",
    },
    visibility_tooltip = {
        en = "Show/hide this group. Does not impact settings.",
        ["zh-tw"] = "顯示/隱藏此組，不影響設定。",
        ["zh-cn"] = "显示/隐藏此组，不影响设定",
    },
    -- Global Settings
    global_settings = {
        en = "Global Settings",
        ["zh-tw"] = "全域設定",
        ["zh-cn"] = "全局设定",
    },
    mod_enabled = {
        en = "Enable/Disable Mod",
        ["zh-tw"] = "啟用/停用模組",
        ["zh-cn"] = "模组启停",
    },
	mod_enable_toggle = {
        en = "Enable/Disable Mod (Toggle)",
        ["zh-tw"] = "啟用/停用模組 (切換)",
        ["zh-cn"] = "切换式模组启停",
    },
    mod_enable_verbose = {
        en = "Notify on Mod Enabled/Disabled",
        ["zh-tw"] = "模組狀態通知",
        ["zh-cn"] = "模组状态通知",
    },
    -- Filter Settings
    filter_settings = {
        en = "Filter Settings",
        ["zh-tw"] = "篩選設定",
        ["zh-cn"] = "筛选设定",
    },
    filter_primary = {
        en = "Filter Primary Fire",
        ["zh-tw"] = "將過濾器應用於主篩選",
        ["zh-cn"] = "过滤器优先级 高",
    },
    filter_secondary = {
        en = "Filter Secondary Fire",
        ["zh-tw"] = "將過濾器應用於次篩選",
        ["zh-cn"] = "过滤器优先级 低",
    },
    copy_primary_to_secondary = {
        en = "Use Primary Filter for Secondary",
        ["zh-tw"] = "次篩選使用主篩選設定",
        ["zh-cn"] = "低优先级沿用高优先级筛选设定",
    },
    copy_primary_to_secondary_tooltip = {
        en = "If enabled, secondary fire will use the filter list defined for primary fire, rather than its own unique filter.",
        ["zh-tw"] = "若啟用，次篩選將使用主篩選設定，而非獨立的篩選。",
        ["zh-cn"] = "次级筛选沿用主级筛选配置———高优先级",
    },
    -- Filter Selection
    filter_select = {
        en = "Filter Selection",
        ["zh-tw"] = "篩選器設定",
        ["zh-cn"] = "筛选器设置",
    },
    filter_select_primary = {
        en = "Primary Fire",
        ["zh-tw"] = "主開火",
        ["zh-cn"] = "主开火",
    },
    filter_select_secondary = {
        en = "Secondary Fire",
        ["zh-tw"] = "副開火",
        ["zh-cn"] = "副开火",
    },
    -- Group Names
    boss_group = {
        en = "Bosses",
        ["zh-tw"] = "首領",
        ["zh-cn"] = "Boss",
    },
    elite_group = {
        en = "Elites",
        ["zh-tw"] = "精英",
        ["zh-cn"] = "精英",
    },
    special_group = {
        en = "Specials",
        ["zh-tw"] = "特殊",
        ["zh-cn"] = "特殊",
    },
    fodder_group = {
        en = "Fodder",
        ["zh-tw"] = "雜兵",
        ["zh-cn"] = "炮灰",
    },
    -- Group Toggles
    global_group_toggle = {
        en = "ENABLE/DISABLE ALL",
        ["zh-tw"] = "啟用/停用全部！",  
        ["zh-cn"] = "启用/禁用全部！",  
    },
    boss_group_toggle = {
        en = "ENABLE/DISABLE BOSSES",
        ["zh-tw"] = "啟用/停用首領！",
        ["zh-cn"] = "启用/禁用Boss！",
    },
    elite_group_toggle = {
        en = "ENABLE/DISABLE ELITES",
        ["zh-tw"] = "啟用/停用精英！",
        ["zh-cn"] = "启用/禁用精英！",
    },
    special_group_toggle = {
        en = "ENABLE/DISABLE SPECIALS",
        ["zh-tw"] = "啟用/停用專家敵人！",
        ["zh-cn"] = "启用/禁用专家敌人！",
    },
    fodder_group_toggle = {
        en = "ENABLE/DISABLE FODDER",
        ["zh-tw"] = "啟用/停用雜兵！",
        ["zh-cn"] = "启用/禁用炮灰！",
    }
}

-- MANUAL LOCALIZATION FOR ENEMIES THE GAME LACKS NAMES FOR
local manual = {
    chaos_mutated_poxwalker = {
        en = "Mutated Poxwalker",
        ["zh-tw"] = "變異瘟疫行屍",
        ["zh-cn"] = "变异瘟疫行者（炮灰）"
    },
    chaos_lesser_mutated_poxwalker = {
        en = "Lesser Mutated Poxwalker",
        ["zh-tw"] = "次級變異瘟疫行屍",
        ["zh-cn"] = "次级变异瘟疫行者（炮灰）"
    }
}

-- SEMI-AUTOMATED SUFFIX LOCALIZATION FOR "MUTATOR" ENEMIES
local en_suffix    = " (Variant)"
local zh_tw_suffix = "（變體）"
local zh_cn_suffix = "（变体）"

--------------------------------------------------------------------------
-- PLEASE DO NOT EDIT BEYOND THIS POINT IF YOU ARE ADDING LOCALIZATIONS --
--------------------------------------------------------------------------

local manual_localization = {
    chaos_mutated_poxwalker = true,
    chaos_lesser_mutated_poxwalker = true
}

-- Automated localization for enemy names
for breed_name, breed in pairs(Breeds) do
	if breed.tags.minion and not breed.tags.companion then
		local display_name = Localize(breed.display_name)
        local skip = false         -- Unlocalized, do not add to localization
        local special_case = false -- Unlocalized, add manual localization
        if not display_name or string.find(display_name, "unlocalized") then
            -- Locate closest match for mutator enemies
            if string.find(breed_name, "mutator") then
                for alt_breed_name, _ in pairs(Breeds) do
                    if not string.find(alt_breed_name, "mutator") then
                        local base_name = breed_name:gsub("mutator_", "")
                        if string.find(alt_breed_name, base_name, 1, true) then
                            display_name = Localize(Breeds[alt_breed_name].display_name)
                            break
                        end
                    end
                end
            end
            -- Skip items that cannot be localized
            if not display_name or string.find(display_name, "unlocalized") then
                if manual_localization[breed_name] then
                    special_case = true
                end
                skip = true
            end
        end
        if special_case or not skip then
            local primary = breed_name
            --local secondary = breed_name .. "0secondary"
            -- Unlocalized enemies
            if manual_localization[breed_name] then
                localization[primary]   = manual[breed_name]
                --localization[secondary] = manual[breed_name]
            -- Mutator enemies
            elseif string.find(breed_name, "mutator") then
                localization[primary] = {
			        en        = display_name .. en_suffix,
                    ["zh-tw"] = display_name .. zh_tw_suffix,
                    ["zh-cn"] = display_name .. zh_cn_suffix
                }
                --localization[secondary] = {
                --    en        = display_name .. en_suffix,
                --    ["zh-tw"] = display_name .. zh_tw_suffix,
                --    ["zh-cn"] = display_name .. zh_cn_suffix
                --}
            -- Standard enemies
            else
                localization[primary] = {
                    en = display_name
                }
                --localization[secondary] = {
                --    en = display_name
                --}
            end
        end
	end
end

return localization