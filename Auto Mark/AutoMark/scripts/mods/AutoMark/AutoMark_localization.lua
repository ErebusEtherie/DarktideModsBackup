local Breed      = require("scripts/utilities/breed")
local Breeds     = require("scripts/settings/breed/breeds")
local Archetypes = require("scripts/settings/archetype/archetypes")
local InputUtils = require("scripts/managers/input/input_utils")

local function color_text(text, color_name)
    local color = Color[color_name](255, true)
    return InputUtils.apply_color_to_input_text(text, color)
end

local function highlight(text)
    return color_text(text, "terminal_text_warning_light")
end

-- ###############################################################################################################
-- zh-tw Localization maintenance note:
-- For zh-tw updates, use the latest translation glossary as the source of truth:
-- https://github.com/SyuanTsai/Warhammer-40-000-DARKTIDE-Mods/blob/main/Referneces/Translation.md
-- Preserve existing context-specific translations when the glossary contains multiple valid terms.
-- ###############################################################################################################

local localization = {
    -- mod_name
    mod_name = {
        en = "Auto Mark",
        ["zh-cn"] = "智能标记",
        ["zh-tw"] = "智慧標記",
    },
    mod_description = {
        en = "Enhance your marking experience",
        ["zh-cn"] = "增强你的标记体验",
        ["zh-tw"] = "增強你的標記體驗",
    },
    -- mod_settings
    mod_settings = {
        en = "Mod Settings",
        ["zh-cn"] = "模组设置",
        ["zh-tw"] = "模組設定",
    },
    toggle_mod = {
        en = "Toggle Mod",
        ["zh-cn"] = "模组开关",
        ["zh-tw"] = "模組開關",
    },
    toggle_mod_keybind = {
        en = "Toggle Keybind",
        ["zh-cn"] = "模组开关按键",
        ["zh-tw"] = "模組開關按鍵",
    },
    toggle_mod_notify = {
        en = "Toggle Notification",
        ["zh-cn"] = "模组开关通知",
        ["zh-tw"] = "模組開關通知",
    },
    debug_mode = {
        en = "Debug Mode",
        ["zh-cn"] = "调试模式",
        ["zh-tw"] = "除錯模式",
    },
    -- arbites settings
    adamant_settings = {
        en = "Arbites Settings",
        ["zh-cn"] = "法务官设置",
        ["zh-tw"] = "法務官設定",
    },
    companion_mark_keybind = {
        en = "Cyber-Mastiff Mark Keybind",
        ["zh-cn"] = "智能獒犬标记按键",
        ["zh-tw"] = "電子獒犬標記按鍵",
    },
    companion_mark_keybind_description = {
        en = "Dedicated key for Cyber-Mastiff Mark. As Arbites, you can now use both normal enemy mark and Cyber-Mastiff mark at the same time.\n\n" ..
            "When " .. highlight("Companion Target Tag") ..
            " is set to " .. highlight("Press Once") ..
            ", this function becomes a normal enemy mark.",
        ["zh-cn"] = "智能獒犬标记专用按键，现在你可以作为法务官，同时使用普通敌人标记和智能獒犬标记了。\n\n" ..
            "当" .. highlight("伙伴目标标记") ..
            "设置为" .. highlight("按一次") ..
            "时，此功能变为普通敌人标记。",
        ["zh-tw"] = "電子獒犬標記專用按鍵，身為法務官，你現在可同時使用一般敵人標記與電子獒犬標記。\n\n" ..
            "當" .. highlight("同伴目標標記方式") ..
            "設為" .. highlight("按一次") ..
            "時，此功能會變為一般敵人標記。",
    },
    ignore_unaggroed = {
        en = "Ignore Unalerted Enemies",
        ["zh-cn"] = "忽略未警觉的敌人",
        ["zh-tw"] = "忽略未觸發警戒的敵人",
    },
    companion_mark_ignore_unaggroed_description = {
        en = "When enabled, Cyber-Mastiff Auto-Mark will not mark enemies that are not alerted.",
        ["zh-cn"] = "当启用时，智能獒犬自动标记将不会标记未警觉的敌人。",
        ["zh-tw"] = "當啟用時，電子獒犬自動標記將不會標記未觸發警戒的敵人。",
    },
    companion_mark_tagged_always_visible = {
        en = "Hunt Them Down",
        ["zh-cn"] = "追踪到底",
        ["zh-tw"] = "追蹤到底",
    },
    companion_mark_tagged_always_visible_description = {
        en = "When enabled, targets marked by any mark or chosen by Execution Order are always treated as visible by Cyber-Mastiff AUTO-MARK.",
        ["zh-cn"] = "开启后，被任意标记或处决指令选中的目标，智能獒犬自动标记将始终视其为可见。",
        ["zh-tw"] = "開啟後，被任意標記或處決指令選中的目標，智慧獒犬自動標記將始終視其為可見。",
    },
    threat_priority = {
        en = "Threat Priority",
        ["zh-cn"] = "威胁优先",
        ["zh-tw"] = "威脅優先",
    },
    threat_priority_tooltip = {
        en = "When enabled, Companion Auto-Mark prioritizes enemies targeting the player.",
        ["zh-cn"] = "开启后，伙伴自动标记将优先标记以玩家为攻击目标的敌人。",
        ["zh-tw"] = "開啟後，同伴自動標記將優先標記以玩家為攻擊目標的敵人。",
    },
    execution_order_priority = {
        en = "Execution Order Priority",
        ["zh-cn"] = "遵从处决指令",
        ["zh-tw"] = "遵從處決指令",
    },
    execution_order_priority_description = {
        en = "Arbites Cyber-Mastiff Auto-Mark prioritizes enemies chosen by Execution Order.",
        ["zh-cn"] = "遵从处决指令的选择，法务官智能獒犬自动标记将优先标记已被处决指令选中的敌人。",
        ["zh-tw"] = "遵從處決指令的選擇，法務官電子獒犬自動標記將優先標記已被處決指令選中的敵人。",
    },
    execution_order_force_mark = {
        en = "Execution Order Force Mark",
        ["zh-cn"] = "处决指令强制标记",
        ["zh-tw"] = "處決指令強制標記",
    },
    execution_order_force_mark_description = {
        en = "When enabled, targets chosen by Execution Order can be auto marked by Cyber-Mastiff even if their enemy type is set to ignored in priority settings.",
        ["zh-cn"] = "开启后，处决指令选中的目标，即便其敌人类型在优先级设置中被设为忽略，仍可被智能獒犬自动标记。",
        ["zh-tw"] = "開啟後，處決指令選中的目標，即便其敵人類型在優先度設定中被設為忽略，仍可被電子獒犬自動標記。",
    },
    companion_range_limitation = {
        en = "Companion Range Limitation",
        ["zh-cn"] = "伙伴范围限制",
        ["zh-tw"] = "伙伴範圍限制",
    },
    companion_range_limitation_tooltip = {
        en = "Restrict the maximum distance between your " .. highlight("companion") .. " and a target that can be marked by the Companion Auto-Mark.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.",
        ["zh-cn"] = "限制伙伴自动标记系统可标记的目标与你的" .. highlight("伙伴") .. "之间的最大距离。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。",
        ["zh-tw"] = "限制同伴自動標記系統可標記的目標與你的" .. highlight("同伴") .. "之間的最大距離。\n\n" ..
            "設為" .. highlight("0") .. "可停用",
    },
    companion_cancel_mark = {
        en = "Auto Cancel Cyber-Mastiff Mark",
        ["zh-cn"] = "自动取消智能獒犬标记",
        ["zh-tw"] = "自動取消電子獒犬標記",
    },
    companion_cancel_mark_human = {
        en = "Human",
        ["zh-cn"] = "人类",
        ["zh-tw"] = "人類",
    },
    companion_cancel_mark_human_description = {
        en = "Enable for human-sized enemies that can be pounced by your Cyber-Mastiff.",
        ["zh-cn"] = "在人类体型的敌人上启用，这些敌人可以被你的智能獒犬扑倒。",
        ["zh-tw"] = "對可被你的電子獒犬撲倒的人型敵人啟用。",
    },
    companion_cancel_mark_non_human = {
        en = "Non-Human",
        ["zh-cn"] = "非人类",
        ["zh-tw"] = "非人類",
    },
    companion_cancel_mark_non_human_description = {
        en = "Enable for non-human-sized enemies that cannot be pounced by your Cyber-Mastiff.",
        ["zh-cn"] = "在非人类体型的敌人上启用，这些敌人不能被你的智能獒犬扑倒。",
        ["zh-tw"] = "對無法被你的電子獒犬撲倒的非人型敵人啟用。",
    },
    health_threshold = {
        en = "Health Threshold",
        ["zh-cn"] = "生命阈值",
        ["zh-tw"] = "生命值門檻",
    },
    companion_health_threshold_tooltip = {
        en = "Cancel the Cyber-Mastiff mark when the health of your Cyber-Mastiff's current attack target falls below your selected health percentage.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "当你的智能獒犬的攻击目标的血量低于所选百分比时，取消该目标的智能獒犬标记。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "當你的電子獒犬目前攻擊目標的生命值低於設定百分比時，取消該目標的電子獒犬標記。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    time_threshold = {
        en = "Time Threshold",
        ["zh-cn"] = "时间阈值",
        ["zh-tw"] = "時間門檻",
    },
    companion_time_threshold_tooltip = {
        en = "Cancel the Cyber-Mastiff mark when your Cyber-Mastiff has been attacking its current target for longer than your selected duration (in seconds).\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "当你的智能獒犬攻击当前目标的持续时间超过所选时长（单位：秒）时，取消该目标的智能獒犬标记。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "當你的電子獒犬攻擊目前目標超過設定秒數時，取消該目標的電子獒犬標記。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    distance_threshold = {
        en = "Distance Threshold",
        ["zh-cn"] = "距离阈值",
        ["zh-tw"] = "距離門檻",
    },
    companion_distance_threshold_tooltip = {
        en = "Cancel the Cyber-Mastiff mark when the distance between you and your Cyber-Mastiff exceeds your selected distance (in meters).\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "当你与你的智能獒犬之间的距离超过所选距离（单位：米）时，取消智能獒犬标记。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "當你與你的電子獒犬之間的距離超過設定公尺時，取消電子獒犬標記。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    enemy_settings = {
        en = "Enemy Settings Override",
        ["zh-cn"] = "敌人设置覆盖",
        ["zh-tw"] = "敵人設定覆蓋",
    },
    enemy_settings_tooltip = {
        en = "Select an enemy to configure its individual settings, which override the settings above, except for the master toggles.",
        ["zh-cn"] = "选择一种敌人，为其配置其独立的设置，这些设置将覆盖上方的设置，除了总开关。",
        ["zh-tw"] = "選擇一種敵人以設定其個別設定。除了總開關外，個別設定會覆蓋上方的一般設定。",
    },
    enemy_settings_reset = {
        en = "Reset to Defaults",
        ["zh-cn"] = "重置为默认值",
        ["zh-tw"] = "重設為預設值",
    },
    enemy_settings_reset_tooltip = {
        en = "Reset all per-enemy individual settings to their default values.",
        ["zh-cn"] = "重置所有敌人的设置为默认值。",
        ["zh-tw"] = "將所有敵人的個別設定重設為預設值。",
    },
    enemy_settings_override = {
        en = "Override",
        ["zh-cn"] = "启用覆盖",
        ["zh-tw"] = "啟用覆蓋",
    },
    enemy_settings_override_tooltip = {
        en = "Apply dedicated settings for this enemy, which take priority over the general settings above, except for the master toggles.",
        ["zh-cn"] = "为这种敌人应用专用设置，这些设置将优先于上方的设置，除了总开关。",
        ["zh-tw"] = "為此敵人套用專用設定。除了總開關外，專用設定優先於上方的一般設定。",
    },
    companion_cancel_mark_breed_health_threshold_description = {
        en = "Set Auto Cancel Cyber-Mastiff Mark Health Threshold for this enemy.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "为所选敌人设置自动取消智能獒犬标记生命阈值。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "設定此敵人的自動取消電子獒犬標記生命值門檻。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    companion_cancel_mark_breed_time_threshold_description = {
        en = "Set Auto Cancel Cyber-Mastiff Mark Time Threshold for this enemy.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "为所选敌人设置自动取消智能獒犬标记时间阈值。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "設定此敵人的自動取消電子獒犬標記時間門檻。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    companion_cancel_mark_breed_distance_threshold_description = {
        en = "Set Auto Cancel Cyber-Mastiff Mark Distance Threshold for this enemy.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "为所选敌人设置自动取消智能獒犬标记距离阈值。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "設定此敵人的自動取消電子獒犬標記距離門檻。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    companion_mark_max_distance = {
        en = "Player Max Distance",
        ["zh-cn"] = "玩家最大距离",
        ["zh-tw"] = "玩家最大距離",
    },
    companion_mark_max_distance_tooltip = {
        en = "Restrict the maximum distance between " .. highlight("player") .. " and a target that can be marked by the Companion Auto-Mark.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.",
        ["zh-cn"] = "限制伙伴自动标记系统可标记的目标与" .. highlight("玩家") .. "之间的最大距离。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。",
        ["zh-tw"] = "限制同伴自動標記系統可標記的目標與" .. highlight("玩家") .. "之間的最大距離。\n\n" ..
            "設為" .. highlight("0") .. "可停用",
    },
    -- cryptic settings
    cryptic_settings = {
        en = "Skitarii Settings",
        ["zh-cn"] = "护教军设置",
        ["zh-tw"] = "護教軍設定",
    },
    servo_skull_mark_keybind = {
        en = "Servo-Skull Mark Keybind",
        ["zh-cn"] = "伺服颅骨标记按键",
        ["zh-tw"] = "伺服顱骨標記按鍵",
    },
    servo_skull_mark_keybind_description = {
        en = "Dedicated key for Servo-Skull Mark. As Skitarii, you can now use both normal enemy mark and Servo-Skull mark at the same time.\n\n" ..
            "When " .. highlight("Companion Target Tag") .. " is set to " .. highlight("Press Once") .. ", this function becomes a normal enemy mark.",
        ["zh-cn"] = "伺服颅骨标记专用按键，现在你可以作为护教军，同时使用普通敌人标记和伺服颅骨标记了。\n\n" ..
            "当" .. highlight("伙伴目标标记") .. "设置为" .. highlight("按一次") .. "时，此功能变为普通敌人标记。",
        ["zh-tw"] = "伺服顱骨標記專用按鍵。身為護教軍，你現在可同時使用一般敵人標記與伺服顱骨標記。\n\n" ..
            "當" .. highlight("同伴目標標記方式") .. "設為" .. highlight("按一次") .. "時，此功能會變為一般敵人標記。",
    },
    servo_skull_mark_ignore_unaggroed_description = {
        en = "When enabled, Servo-Skull Auto-Mark will not mark enemies that are not alerted.",
        ["zh-cn"] = "当启用时，伺服颅骨自动标记将不会标记未警觉的敌人。",
        ["zh-tw"] = "當啟用時，伺服顱骨自動標記將不會標記未觸發警戒的敵人。",
    },
    servo_skull_lose_sight_tolerance = {
        en = "Out of Sight Tolerance",
        ["zh-cn"] = "视野丢失容忍时间",
        ["zh-tw"] = "視野丟失容忍時間",
    },
    servo_skull_lose_sight_tolerance_tooltip = {
        en = "Cancel Servo-Skull marks when your Servo-Skull loses sight of the target for longer than your selected time (in seconds).\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "当你的伺服颅骨失去目标视野超过所选时间（单位：秒）时，取消伺服颅骨标记。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "當你的伺服顱骨失去目標視野超過設定秒數時，取消伺服顱骨標記。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    hack_mark_keybind = {
        en = "Data Interrogation Keybind",
        ["zh-cn"] = "数据查询按键",
        ["zh-tw"] = "資料查詢按鍵",
    },
    hack_mark_keybind_description = {
        en = "Dedicated key for Sending the Servo-Skull to hack the minigame.",
        ["zh-cn"] = "用于指派伺服颅骨黑入数据查询小游戏的专用按键。",
        ["zh-tw"] = "用於指派伺服顱骨黑入資料查詢小遊戲的專用按鍵。",
    },
    auto_hack = {
        en = "Auto Data Interrogation",
        ["zh-cn"] = "自动数据查询",
        ["zh-tw"] = "自動資料查詢",
    },
    auto_hack_description = {
        en = "Automatically sends your Servo-Skull to hack the minigame when you aim at a hackable objective",
        ["zh-cn"] = "当你瞄准一个数据查询小游戏时，自动派遣伺服颅骨前去黑入。",
        ["zh-tw"] = "當你瞄準一個資料查詢小遊戲時，自動派遣伺服顱骨前去黑入。",
    },
    disable_auto_hack_for_noospheric_command = {
        en = "Disable Auto Data Interrogation When Noospheric Command Talent is Equiped",
        ["zh-cn"] = "当装备星语指令时禁用自动数据查询",
        ["zh-tw"] = "當裝備心智網指令時停用自動資料查詢",
    },
    capacitance_retention = {
        en = "Capacitance Retention",
        ["zh-cn"] = "电容保留",
        ["zh-tw"] = "電容量保留",
    },
    capacitance_retention_description = {
        en = "While the Noospheric Command talent is active, all Servo-Skull Auto-Mark features (including Noospheric Command Boost) are disabled when remaining capacitance drops below the configured threshold.\n\n" ..
            "This threshold supports negative values (including -0):\n" ..
            "Non-negative values are checked directly against remaining capacitance.\n" ..
            "For negative values, the actual threshold equals maximum ability charges plus the configured value.\n\n" ..
            "Remaining capacitance is calculated as ability charge count plus current capacitance percentage.",
        ["zh-cn"] = "当装备星语指令天赋时，若剩余电容低于所选阈值，将禁用所有伺服颅骨自动标记功能，包括星语指令增强。\n\n" ..
            "本阈值支持设置为负值（含-0）：\n" ..
            "阈值为非负数时，直接以剩余电容数值判定。\n" ..
            "阈值为负数时，实际阈值等于技能最大充能次数加上设定值。\n\n" ..
            "剩余电容等于技能充能次数加上当前电容百分比。",
        ["zh-tw"] = "當啟用心智網指令時，若剩餘電容量低於所選門檻，將停用所有伺服顱骨自動標記功能，包含心智網指令強化。\n\n" ..
            "本門檻支援設定為負值（含-0）：\n" ..
            "門檻為非負數時，直接以剩餘電容量數值判定。\n" ..
            "門檻為負數時，實際門檻等於技能最大充能次數加上設定值。\n\n" ..
            "剩餘電容量等於技能充能次數加上當前電容量百分比。",
    },
    capacitance_retention_elite_threshold_description = {
        en = "Set Capacitance Retention Threshold for elites.",
        ["zh-cn"] = "为精英敌人设置电容保留阈值。",
        ["zh-tw"] = "設定精英敵人的電容保留門檻。",
    },
    capacitance_retention_special_threshold_description = {
        en = "Set Capacitance Retention Threshold for specialists.",
        ["zh-cn"] = "为专家敌人设置电容保留阈值。",
        ["zh-tw"] = "針對專家敵人的電容量，設定保留門檻。",
    },
    capacitance_retention_boss_threshold_description = {
        en = "Set Capacitance Retention Threshold for bosses.",
        ["zh-cn"] = "为Boss设置电容保留阈值。",
        ["zh-tw"] = "針對Boss的電容量，設定保留門檻。",
    },
    capacitance_retention_breed_threshold = {
        en = "Capacitance Retention",
        ["zh-cn"] = "电容保留",
        ["zh-tw"] = "電容量門檻",
    },
    capacitance_retention_breed_threshold_description = {
        en = "Set Capacitance Retention Threshold for this enemy.",
        ["zh-cn"] = "为所选敌人设置电容保留阈值。",
        ["zh-tw"] = "設定此敵人的電容保留門檻。",
    },
    noospheric_command_boost = {
        en = "Noospheric Command Boost",
        ["zh-cn"] = "星语指令增强",
        ["zh-tw"] = "心智網指令強化",
    },
    noospheric_command_boost_description = {
        en = "Automatically re-marks marked targets to extend the Noospheric Command effect.\n\n" ..
            "Re-marking occurs at intervals equal to the effect's duration, and only triggers when the target is within the Servo-Skull's line of sight.",
        ["zh-cn"] = "自动对已标记目标进行重复标记，以延长星语指令的效果。\n\n" ..
            "重复标记间隔为星语指令的持续时间，只有当目标在伺服颅骨视野内时才会进行标记。",
        ["zh-tw"] = "自動重新標記已標記目標，以延長心智網指令效果。\n\n" ..
            "重新標記間隔等同於效果持續時間，且僅在目標位於伺服顱骨視線內時觸發。",
    },
    noospheric_command_boost_elite_description = {
        en = "Enable Noospheric Command Boost for elites.",
        ["zh-cn"] = "为精英敌人启用星语指令增强",
        ["zh-tw"] = "為精英敵人啟用心智網指令強化。",
    },
    noospheric_command_boost_special_description = {
        en = "Enable Noospheric Command Boost for specialists.",
        ["zh-cn"] = "为专家敌人启用星语指令增强",
        ["zh-tw"] = "為專家敵人啟用心智網指令強化。",
    },
    noospheric_command_boost_boss_description = {
        en = "Enable Noospheric Command Boost for bosses.",
        ["zh-cn"] = "为Boss启用星语指令增强",
        ["zh-tw"] = "為Boss啟用心智網指令強化。",
    },
    noospheric_command_boost_breed_toggle = {
        en = "Noospheric Command",
        ["zh-cn"] = "星语指令",
        ["zh-tw"] = "心智網指令",
    },
    noospheric_command_boost_breed_toggle_description = {
        en = "Enable/Disable Noospheric Command Boost for this enemy.",
        ["zh-cn"] = "为所选敌人启用/禁用星语指令增强。",
        ["zh-tw"] = "為所選敵人啟用/停用心智網指令強化。",
    },
    -- veteran settings
    veteran_settings = {
        en = "Veteran Settings",
        ["zh-cn"] = "老兵设置",
        ["zh-tw"] = "老兵設定",
    },
    focus_target_overwrite = {
        en = "Focus Target Overwrite",
        ["zh-cn"] = "聚焦目标覆盖",
        ["zh-tw"] = "專注目標覆蓋",
    },
    focus_target_overwrite_description = {
        en = highlight("Off") .. ": Enemie marked by Focus Target will not be re-marked.\n" ..
            highlight("On") .. ": If the player's Focus Target stacks exceed those applied to the enemy, and the stack difference is greater than or equal to the option 'Focus Target Overwrite Delta' or the stacks are at max, the Focus Target mark will be reapplied.",
        ["zh-cn"] = highlight("关闭") .. "：已被聚焦目标标记的敌人，不会再次被标记。\n" ..
            highlight("开启") .. "：当玩家自身聚焦目标层数高于敌人已被施加的层数，且层数差大于等于下方选项「聚焦目标覆盖最小层数差」或自身层数已满时，将重新施加聚焦目标标记。",
        ["zh-tw"] = highlight("關閉") .. "：已被專注目標標記的敵人，不會再次被標記。\n" ..
            highlight("開啟") .. "：當玩家自身專注目標層數高於敵人已被施加的層數，且層數差大於等於下方選項「專注目標覆蓋最小層數差」或自身層數已滿時，將重新施加專注目標標記。",
    },
    focus_target_overwrite_delta = {
        en = "Focus Target Overwrite Delta",
        ["zh-cn"] = "聚焦目标覆盖最小层数差",
        ["zh-tw"] = "專注目標覆蓋最小層數差",
    },
    focus_target_ignore_unaggroed_description = {
        en = "When enabled, Focus Target will not mark enemies that are not alerted.",
        ["zh-cn"] = "当启用时，聚焦目标将不会标记未警觉的敌人。",
        ["zh-tw"] = "當啟用時，專注目標將不會標記未觸發警戒的敵人。",
    },
    focus_target_switch = {
        en = "Switch Target on Attack",
        ["zh-cn"] = "攻击时切换目标",
        ["zh-tw"] = "攻擊時切換目標",
    },
    focus_target_switch_description = {
        en = "When the player is attacking, the focus target mark will switch to the aimed target.",
        ["zh-cn"] = "当进行攻击时，聚焦目标将标记当前瞄准的敌人。",
        ["zh-tw"] = "進行攻擊時，專注目標將標記當前瞄準的敵人。",
    },
    focus_target_switch_override_manual = {
        en = "Override Manual",
        ["zh-cn"] = "覆盖手动标记",
        ["zh-tw"] = "覆蓋手動標記",
    },
    focus_target_switch_override_manual_description = {
        en = highlight("Off") .. ": Switch-Target stops when a manual mark is present.\n" ..
            highlight("On") .. ": Switch-Target continues to find new targets even when a manual mark is present.",
        ["zh-cn"] = highlight("关闭") .. "：手动标记存在时，切换目标将停止。\n" ..
            highlight("开启") .. "：即使当前标记为手动标记，切换目标也会继续寻找新的目标。",
        ["zh-tw"] = highlight("關閉") .. "：當存在手動標記時，切換目標會停止。\n" ..
            highlight("開啟") .. "：即使目前有手動標記，切換目標仍會持續尋找新目標。",
    },
    focus_target_switch_melee = {
        en = "Melee Weapon",
        ["zh-cn"] = "近战武器",
        ["zh-tw"] = "近戰武器",
    },
    focus_target_switch_range = {
        en = "Ranged Weapon",
        ["zh-cn"] = "远程武器",
        ["zh-tw"] = "遠程武器",
    },
    -- class settings
    auto_mark_settings = {
        en = "Auto Mark Settings",
        ["zh-cn"] = "自动标记设置",
        ["zh-tw"] = "自動標記設定",
    },
    class_selection = {
        en = "Class",
        ["zh-cn"] = "职业",
        ["zh-tw"] = "職業",
    },
    class_selection_description = {
        en = "Normal enemy marks for all classes, plus special marks for certain classes (Cyber-Mastiff, Servo-Skull, Focus Target).",
        ["zh-cn"] = "所有职业的普通敌人标记，以及某些职业的特殊标记（智能獒犬、伺服颅骨、聚焦目标）。",
        ["zh-tw"] = "所有職業的一般敵人標記，以及特定職業的特殊標記（電子獒犬、伺服顱骨、專注目標）。",
    },
    toggle_class = {
        en = "Toggle",
        ["zh-cn"] = "开关",
        ["zh-tw"] = "開關",
    },
    toggle_class_description = {
        en = "Toggle Auto-Mark for the selected mark type.",
        ["zh-cn"] = "开启/关闭所选标记类型的自动标记功能。",
        ["zh-tw"] = "啟用或停用所選標記類型的自動標記功能。",
    },
    interval = {
        en = "Interval",
        ["zh-cn"] = "间隔时间",
        ["zh-tw"] = "間隔時間",
    },
    interval_description = {
        en = "Minimum interval after a mark expires before Auto-Mark marks the next target.\n\nUnit: seconds.",
        ["zh-cn"] = "设置标记消失后，执行下一次标记的最短时间间隔。\n\n单位：秒。",
        ["zh-tw"] = "設定標記消失後，執行下一次標記的最短時間間隔。\n\n單位：秒。",
    },
    cooldown = {
        en = "Cooldown",
        ["zh-cn"] = "冷却时间",
        ["zh-tw"] = "冷卻時間",
    },
    cooldown_description = {
        en = "Cooldown after a mark is applied before Auto-Mark marks the next target.\n\nUnit: seconds.",
        ["zh-cn"] = "设置标记生成后，自动标记下一个目标前的冷却时间。\n\n单位：秒。",
        ["zh-tw"] = "設定標記生成後，自動標記下一個目標前的冷卻時間。\n\n單位：秒。",
    },
    reset_cooldown = {
        en = "Reset Cooldown",
        ["zh-cn"] = "刷新冷却",
        ["zh-tw"] = "重置冷卻",
    },
    reset_cooldown_description = {
        en = "Resets Auto-Mark cooldown when the last mark disappears.",
        ["zh-cn"] = "当上个标记消失时，刷新自动标记冷却时间。",
        ["zh-tw"] = "當上個標記消失時，重置自動標記冷卻時間。",
    },
    mark_limit = {
        en = "Mark Limit",
        ["zh-cn"] = "标记限制",
        ["zh-tw"] = "標記限制",
    },
    mark_limit_description = {
        en = "Stops Auto-Mark when the last mark is present.",
        ["zh-cn"] = "当上个标记存在时，停止自动标记。",
        ["zh-tw"] = "當上個標記存在時，停止自動標記。",
    },
    min_range = {
        en = "Min Range",
        ["zh-cn"] = "最小范围",
        ["zh-tw"] = "最小範圍",
    },
    min_range_description = {
        en = "Unit: Meters",
        ["zh-cn"] = "单位：米",
        ["zh-tw"] = "單位：公尺",
    },
    max_range = {
        en = "Max Range",
        ["zh-cn"] = "最大范围",
        ["zh-tw"] = "最大範圍",
    },
    max_range_description = {
        en = "Unit: Meters",
        ["zh-cn"] = "单位：米",
        ["zh-tw"] = "單位：公尺",
    },
    max_angle = {
        en = "Max Angle",
        ["zh-cn"] = "最大角度",
        ["zh-tw"] = "最大角度",
    },
    max_angle_description = {
        en = "Maximum angle in degrees between your crosshair and markable enemies. \n\nSet to " .. highlight("0") .. " to use vanilla raycast detection.",
        ["zh-cn"] = "可标记敌人与准星间的最大角度。\n\n设置为" .. highlight("0") .. "时将使用游戏原版射线检测。",
        ["zh-tw"] = "可標記敵人與準星間的最大角度。\n\n設為" .. highlight("0") .. "時將使用遊戲原版射線偵測。",
    },
    override_manual = {
        en = "Override Manual",
        ["zh-cn"] = "覆盖手动标记",
        ["zh-tw"] = "覆蓋手動標記",
    },
    override_manual_description = {
        en = highlight("Off") .. ": Auto-mark stops when a manual mark is present.\n" ..
            highlight("On") .. ": Auto-mark continues to find new targets even when a manual mark is present.",
        ["zh-cn"] = highlight("关闭") .. "：手动标记存在时，自动标记将停止。\n" ..
            highlight("开启") .. "：即使当前标记为手动标记，自动标记也会继续寻找新的目标。",
        ["zh-tw"] = highlight("關閉") .. "：當存在手動標記時，自動標記會停止。\n" ..
            highlight("開啟") .. "：即使目前有手動標記，自動標記仍會持續尋找新目標。",
    },
    priority_switch = {
        en = "Priority Switch",
        ["zh-cn"] = "优先级切换",
        ["zh-tw"] = "優先順序切換",
    },
    priority_switch_description = {
        en = "Switches to the aimed target if it has higher priority than the current marked target.",
        ["zh-cn"] = "当正在瞄准的目标优先级高于已被标记的目标时，切换至瞄准的目标。",
        ["zh-tw"] = "當正在瞄準的目標優先順序高於已標記的目標時，切換至瞄準的目標。",
    },
    toggle_elite = {
        en = "Toggle Elite",
        ["zh-cn"] = "精英开关",
        ["zh-tw"] = "精英開關",
    },
    toggle_elite_description = {
        en = "Enable/Disable Auto-Mark for elites.",
        ["zh-cn"] = "为精英敌人启用/禁用自动标记功能。",
        ["zh-tw"] = "啟用或停用精英敵人的自動標記功能。",
    },
    toggle_special = {
        en = "Toggle Specialist",
        ["zh-cn"] = "专家开关",
        ["zh-tw"] = "專家開關",
    },
    toggle_special_description = {
        en = "Enable/Disable Auto-Mark for specialists.",
        ["zh-cn"] = "为专家敌人启用/禁用自动标记功能。",
        ["zh-tw"] = "啟用或停用專家敵人的自動標記功能。",
    },
    toggle_boss = {
        en = "Toggle Boss",
        ["zh-cn"] = "Boss开关",
        ["zh-tw"] = "Boss開關",
    },
    toggle_boss_description = {
        en = "Enable/Disable Auto-Mark for bosses.",
        ["zh-cn"] = "为Boss启用/禁用自动标记功能。",
        ["zh-tw"] = "為Boss啟用或停用自動標記功能。",
    },
    toggle_other = {
        en = "Toggle Other",
        ["zh-cn"] = "其他开关",
        ["zh-tw"] = "其他開關",
    },
    toggle_other_description = {
        en = "Enable/Disable Auto-Mark for other enemies.",
        ["zh-cn"] = "为其他敌人启用/禁用自动标记功能。",
        ["zh-tw"] = "啟用或停用其他敵人的自動標記功能。",
    },
    priority_off = {
        en = "Off",
        ["zh-cn"] = "关闭",
        ["zh-tw"] = "關閉",
    },
    priority_lowest = {
        en = "Priority Lowest",
        ["zh-cn"] = "最低优先级",
        ["zh-tw"] = "最低優先",
    },
    priority_low = {
        en = "Priority Low",
        ["zh-cn"] = "低优先级",
        ["zh-tw"] = "低優先",
    },
    priority_medium = {
        en = "Priority Medium",
        ["zh-cn"] = "中优先级",
        ["zh-tw"] = "中優先",
    },
    priority_high = {
        en = "Priority High",
        ["zh-cn"] = "高优先级",
        ["zh-tw"] = "高優先",
    },
    priority_highest = {
        en = "Priority Highest",
        ["zh-cn"] = "最高优先级",
        ["zh-tw"] = "最高優先",
    },
    adamant_companion = {
        en = "Arbitrator Cyber-Mastiff",
        ["zh-cn"] = "法务官 智能獒犬",
        ["zh-tw"] = "法務官 電子獒犬",
    },
    veteran_focus_target = {
        en = "Veteran Focus Target",
        ["zh-cn"] = "老兵聚焦目标",
        ["zh-tw"] = "老兵專注目標",
    },
    cryptic_servo_skull = {
        en = "Skitarius Servo-Skull",
        ["zh-cn"] = "护教军士兵 伺服颅骨",
        ["zh-tw"] = "護教軍 伺服顱骨",
    },
    apply_to_all_classes = {
        en = "Apply to All Classes",
        ["zh-cn"] = "应用于所有职业",
        ["zh-tw"] = "套用至所有職業",
    },
    apply_button = {
        en = "Apply to All",
        ["zh-cn"] = "应用于所有职业",
        ["zh-tw"] = "套用至全部",
    },
    apply_button_description = {
        en =
        "Apply settings from the selected mark type to either all mark types or only normal enemy marks across all classes.",
        ["zh-cn"] = "将所选标记类型的设置应用于所有标记类型或者只应用于所有职业的普通敌人标记。",
        ["zh-tw"] = "將所選標記類型的設定套用到所有標記類型，或僅套用到所有職業的一般敵人標記。",
    },
    reset_auto_mark_settings = {
        en = "Reset Auto Mark Settings",
        ["zh-cn"] = "重置自动标记设置",
        ["zh-tw"] = "重置自動標記設定",
    },
    reset_button = {
        en = "Reset to Defaults",
        ["zh-cn"] = "重置为默认值",
        ["zh-tw"] = "重設為預設值",
    },
    reset_button_description = {
        en = "Reset mark settings to defaults for all mark types or the selected mark type.",
        ["zh-cn"] = "将所有标记类型或所选标记类型的设置重置为默认值。",
        ["zh-tw"] = "將所有標記類型或所選標記類型的設定重設為預設值。",
    },
    blank = {
        en = " ",
        ["zh-cn"] = " ",
        ["zh-tw"] = " ",
    },
    reset = {
        en = "Reset",
        ["zh-cn"] = "重置",
        ["zh-tw"] = "重設",
    },
    apply_to_normal = {
        en = "Apply to Normal Enemy Marks",
        ["zh-cn"] = "应用于普通敌人标记",
        ["zh-tw"] = "套用到一般敵人標記",
    },
    apply_to_all = {
        en = "Apply to All Mark Types",
        ["zh-cn"] = "应用于所有标记类型",
        ["zh-tw"] = "套用到所有標記類型",
    },
    reset_current = {
        en = "Reset Selected Mark Settings",
        ["zh-cn"] = "重置所选标记设置",
        ["zh-tw"] = "重設所選標記設定",
    },
    reset_all = {
        en = "Reset All Mark Settings",
        ["zh-cn"] = "重置所有标记设置",
        ["zh-tw"] = "重設所有標記設定",
    },
    tooltip_breed_priority = {
        en = "Set the marking priority for this enemy type. Auto-Mark prioritizes targets with higher priority values.\n\n" ..
            "Set to " .. highlight("0") .. " to ignore this enemy type.",
        ["zh-cn"] = "设置该类敌人的标记优先级。自动标记将优先标记优先级更高的目标。\n\n" ..
            "设置为" .. highlight("0") .. "以忽略此类敌人。",
        ["zh-tw"] = "設定該類敵人的標記優先度。自動標記將優先標記優先度較高的目標。\n\n" ..
            "設為" .. highlight("0") .. "可忽略此類敵人。",
    },
    elite = {
        en = "Elite",
        ["zh-cn"] = "精英",
        ["zh-tw"] = "精英",
    },
    elite_tooltip = {
        en = "Enable for elites.",
        ["zh-cn"] = "为精英敌人启用。",
        ["zh-tw"] = "為精英敵人啟用。",
    },
    special = {
        en = "Specialist",
        ["zh-cn"] = "专家",
        ["zh-tw"] = "專家",
    },
    special_tooltip = {
        en = "Enable for specialists.",
        ["zh-cn"] = "为专家敌人启用。",
        ["zh-tw"] = "為專家敵人啟用。",
    },
    boss = {
        en = "Boss",
        ["zh-cn"] = "Boss",
        ["zh-tw"] = "Boss",
    },
    boss_tooltip = {
        en = "Enable for bosses.",
        ["zh-cn"] = "为Boss敌人启用。",
        ["zh-tw"] = "為Boss敵人啟用。",
    },
    sticky_targeting = {
        en = "Mark Stickiness",
        ["zh-cn"] = "标记粘滞",
        ["zh-tw"] = "標記黏滯",
    },
    sticky_targeting_tooltip = {
        en = "Enable for the selected enemy type. If a marked enemy has Mark Stickiness enabled, AUTO-MARK will pause target switching caused by priority switch.",
        ["zh-cn"] = "为所选敌人类型启用标记粘滞。如果被标记的敌人开启了标记粘滞功能，自动标记会暂停因优先级切换导致的切换目标行为。",
        ["zh-tw"] = "為所選敵人類型啟用標記黏滯。如果被標記的敵人開啟了標記黏滯功能，自動標記會暫停因優先順序切換導致的切換目標行為。",
    },
    servo_skull_cancel_mark = {
        en = "Auto Cancel Servo-Skull Mark",
        ["zh-cn"] = "自动取消伺服颅骨标记",
        ["zh-tw"] = "自動取消伺服顱骨標記",
    },
    servo_skull_health_threshold_tooltip = {
        en = "Cancel the Servo-Skull mark when the health of your Servo-Skull's current attack target falls below your selected health percentage.\n\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " marks.",
        ["zh-cn"] = "当你的伺服颅骨的攻击目标的血量低于所选百分比时，取消该目标的伺服颅骨标记。\n\n" ..
            "设置为" .. highlight("0") .. "以禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
        ["zh-tw"] = "當你的伺服顱骨目前攻擊目標的生命值低於設定百分比時，取消該目標的伺服顱骨標記。\n\n" ..
            "設為" .. highlight("0") .. "可停用。\n" ..
            "不影響" .. highlight("手動") .. "標記。",
    },
    meter = {
        en = "m",
        ["zh-cn"] = "米",
        ["zh-tw"] = "公尺",
    },
    percent = {
        en = "%%",
    },
    degree = {
        en = "°",
    },
    stack = {
        en = "stack",
        ["zh-cn"] = "层",
        ["zh-tw"] = "层",
    },
    second = {
        en = "s",
        ["zh-cn"] = "秒",
        ["zh-tw"] = "秒",
    },
    hold_to_reset = {
        en = "to Reset",
        ["zh-cn"] = "重置",
        ["zh-tw"] = "重設",
    },
}

local function is_localization_valid(text)
    return not string.find(text, "unlocalized")
end

local function add_breed_localization(breed_name, breed_data, is_passive)
    local text = Localize(breed_data.is_boss and type(breed_data.boss_display_name) == "string" and breed_data.boss_display_name or breed_data.display_name)
    if is_localization_valid(text) then
        if is_passive then
            localization[breed_name .. "_passive"] = {
                en = text .. " (Dormant)",
                ["zh-cn"] = text .. "（休眠）",
                ["zh-tw"] = text .. "（休眠）",
            }
        elseif breed_name == "chaos_mutator_ritualist" then
            localization[breed_name] = {
                en = "Hexbound " .. text,
                ["zh-cn"] = "咒缚" .. text,
                ["zh-tw"] = "魔縛" .. text,
            }
        elseif breed_name ~= "chaos_mutator_daemonhost" and string.find(breed_name, "mutator") then
            localization[breed_name] = {
                en = text .. " (Mutator)",
                ["zh-cn"] = text .. "（变异体）",
                ["zh-tw"] = text .. "（變異體）",
            }
        else
            localization[breed_name] = { en = text }
        end
    else
        localization[breed_name] = { en = breed_name }
    end
end

for breed_name, breed_data in pairs(Breeds) do
    if Breed.is_minion(breed_data) and breed_data.unit_template_name == "minion" and breed_data.smart_tag_target_type == "breed" and breed_data.faction_name ~= "imperium" then
        add_breed_localization(breed_name, breed_data)
        if breed_data.tags.witch then
            add_breed_localization(breed_name, breed_data, true)
        end
    end
end

for class_name, archetype in pairs(Archetypes) do
    local text = Localize(archetype.archetype_name)
    localization[class_name] = {
        en = text
    }
end

return localization
