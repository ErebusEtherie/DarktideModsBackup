local InputUtils = require("scripts/managers/input/input_utils")

local Color      = Color

local function color_text(text, color_name)
    local color = Color[color_name](255, true)
    return InputUtils.apply_color_to_input_text(text, color)
end

local function highlight(text)
    return color_text(text, "terminal_text_warning_light")
end

return {
    mod_name = {
        en = "Better Movement",
        ["zh-cn"] = "流畅移动",
    },
    mod_description = {
        en = "Enhance Your Movement Experience",
        ["zh-cn"] = "增强你的移动体验",
    },
    mod_settings = {
        en = "Mod Settings",
        ["zh-cn"] = "模组设置",
    },
    debug_enabled = {
        en = "Enable Debug Mode",
        ["zh-cn"] = "启用调试模式",
    },
    sprint_settings = {
        en = "Sprint Settings",
        ["zh-cn"] = "疾跑设置",
    },
    better_sprint = {
        en = "Better Sprint",
        ["zh-cn"] = "更好的疾跑",
    },
    better_sprint_description = {
        en = "Press the " .. highlight("sprint key") .. " to activate "
            .. highlight("continuous sprint") .. ". Continuous sprint stops when you "
            .. highlight("release the forward key") .. ", or perform actions like "
            .. highlight("reloading") .. " or "
            .. highlight("shooting") .. ".",
        ["zh-cn"] = "按下" .. highlight("疾跑键") .. "进入"
            .. highlight("持续疾跑") .. "状态，"
            .. highlight("松开前方向键") .. "，执行"
            .. highlight("换弹") .. "、"
            .. highlight("射击") .. "等动作将会"
            .. highlight("退出") .. "持续疾跑状态。",
    },
    always_sprint = {
        en = "Always Sprint",
        ["zh-cn"] = "始终疾跑",
    },
    always_sprint_description = {
        en = "Works with " .. highlight("Better Sprint") .. ". When enabled, actions such as "
            .. highlight("reloading") .. " and "
            .. highlight("shooting") .. " will "
            .. highlight("no longer interrupt") .. " continuous sprint.",
        ["zh-cn"] = "与" .. highlight("更好的疾跑") .. "搭配使用。开启后，"
            .. highlight("换弹") .. "、"
            .. highlight("射击") .. "等动作"
            .. highlight("不再会打断") .. "持续疾跑状态。",
    },
    toggle_sprint = {
        en = "Toggle Sprint",
        ["zh-cn"] = "切换疾跑",
    },
    toggle_sprint_description = {
        en = "Works with " .. highlight("Better Sprint") .. ". When enabled, "
            .. highlight("releasing the forward key") .. " won't "
            .. highlight("stop") .. " continuous sprint. The "
            .. highlight("sprint key") .. " will "
            .. highlight("toggle") .. " the continuous sprint state.",
        ["zh-cn"] = "与" .. highlight("更好的疾跑") .. "搭配使用。开启后，"
            .. highlight("松开前方向键") .. "不再"
            .. highlight("退出持续疾跑") .. "，"
            .. highlight("疾跑键") .. "改为"
            .. highlight("切换") .. "持续疾跑。",
    },
    hold_to_sprint = {
        en = "Hold to Sprint",
        ["zh-cn"] = "按住疾跑",
    },
    hold_to_sprint_description = {
        en = "Works with " .. highlight("Better Sprint") .. ". When enabled, it functions "
            .. highlight("identically to the vanilla game") .. "'s hold-to-sprint, with the added fix for "
            .. highlight("unintended action cancellation") .. ".",
        ["zh-cn"] = "与" .. highlight("更好的疾跑") .. "搭配使用，开启后，功能与"
            .. highlight("原版游戏的按住疾跑") .. "完全一致，额外修复了"
            .. highlight("某些武器动作意外取消") .. "的问题。",
    },
    hold_to_walk = {
        en = "Hold to Walk",
        ["zh-cn"] = "按住慢走",
    },
    hold_to_walk_description = {
        en = "Works with " .. highlight("Better Sprint") .. ". When enabled, "
            .. highlight("continuous sprint") .. " is enabled by default. "
            .. highlight("Hold the sprint key") .. " to enter "
            .. highlight("walk mode") .. ".",
        ["zh-cn"] = "与" .. highlight("更好的疾跑") .. "搭配使用，开启后默认处于"
            .. highlight("持续疾跑") .. "状态，"
            .. highlight("按住疾跑键") .. "进入"
            .. highlight("慢走模式") .. "。",
    },
    dodge_settings = {
        en = "Dodge Settings",
        ["zh-cn"] = "闪避设置",
    },
    prevent_accidental_jump = {
        en = "No Accidental Jump",
        ["zh-cn"] = "阻止意外跳跃",
    },
    prevent_accidental_jump_description = {
        en = "Prevents " .. highlight("accidental jump") .. " during " .. highlight("dodging") .. ".\n"
            .. highlight("Recommended") ..
            " for players who use the " .. highlight("same key") .. " for both jumping and dodging.\n"
            .. highlight("Disable") .. " this option if you use a " .. highlight("separate jump key") .. ".",
        ["zh-cn"] = "防止" .. highlight("闪避") .. "时" .. highlight("意外跳跃") .. "。\n"
            .. "推荐" .. highlight("跳跃和闪避使用相同按键") .. "的玩家开启。\n"
            .. "如使用" .. highlight("单独跳跃按键") .. "请" .. highlight("关闭") .. "。",
    },
    sprint_dodge = {
        en = "Sprint Dodge",
        ["zh-cn"] = "疾跑闪避",
    },
    sprint_dodge_description = {
        en = highlight("Allows dodging while sprinting") .. " when the "
            .. highlight("Dodge on Diagonal Forward") .. " option is enabled.",
        ["zh-cn"] = highlight("疾跑状态下也可以闪避") .. "，需要开启游戏内"
            .. highlight("向斜前方闪避") .. "选项。",
    },
    easy_dodge_slide = {
        en = "Easy Dodge Slide",
        ["zh-cn"] = "轻松闪避滑铲",
    },
    easy_dodge_slide_description = {
        en = "Triggers " .. highlight("dodge-slide") .. " by "
            .. highlight("pressing the dodge key again") .. " while dodging.",
        ["zh-cn"] = highlight("闪避过程中再次按下闪避键") .. "触发" .. highlight("闪避滑铲") .. "。",
    },
    hold_dodge_slide = {
        en = "Hold Dodge Slide",
        ["zh-cn"] = "按住闪避滑铲",
    },
    hold_dodge_slide_description = {
        en = "Triggers " .. highlight("dodge-slide") .. " by "
            .. highlight("holding the dodge key") .. ".",
        ["zh-cn"] = highlight("闪避过程中按住闪避键") .. "触发" .. highlight("闪避滑铲") .. "。",
    },
    keep_dodging = {
        en = "Keep Dodging",
        ["zh-cn"] = "连续闪避",
    },
    keep_dodging_description = {
        en = highlight("Hold dodge key") .. " to perform " .. highlight("continuous dodge") .. ".",
        ["zh-cn"] = highlight("按住闪避键") .. "以进行" .. highlight("连续闪避") .. "。",
    },
    movement_settings = {
        en = "Movement Settings",
        ["zh-cn"] = "移动设置",
    },
    crouch_settings = {
        en = "Crouch Settings",
        ["zh-cn"] = "蹲伏设置",
    },
    better_toggle_crouch = {
        en = "Better Toggle Crouch",
        ["zh-cn"] = "更好的切换蹲伏",
    },
    better_toggle_crouch_description = {
        en = "Combines the benefits of " .. highlight("toggle crouch") .. " and " .. highlight("hold-to-crouch") .. ".\n"
            .. "Provides vanilla-style toggle crouch while walking.\n"
            .. highlight("Automatically exits crouch") .. " when dodging, and exits crouch "
            .. highlight("immediately on key release") .. " after a slide.\n"
            .. highlight("Recommended") .. " if you use " .. highlight("Easy Dodge-Slide") .. ", "
            .. highlight("Hold Dodge-Slide") .. ", or " .. highlight("Easy Sprint-Slide")
            .. " and prefer " .. highlight("toggle crouch") .. ".",
        ["zh-cn"] = "结合" .. highlight("切换蹲伏") .. "与" .. highlight("长按蹲伏") .. "的优点，行走时实现与原版一致的切换蹲伏。\n"
            .. highlight("闪避") .. "时会自动退出蹲伏，" .. highlight("滑铲结束") .. "后" .. highlight("松开蹲伏键") .. "可以立刻退出蹲伏。\n"
            .. "如果你开启了" .. highlight("轻松闪避滑铲") .. "、" .. highlight("按住闪避滑铲") .. "或" .. highlight("轻松疾跑滑铲") .. "，"
            .. "且喜欢" .. highlight("切换蹲伏") .. "则建议开启此选项。",
    },
    easy_sprint_slide = {
        en = "Easy Sprint Slide",
        ["zh-cn"] = "轻松疾跑滑铲",
    },
    easy_sprint_slide_description = {
        en = "Triggers " .. highlight("slide") .. " by "
            .. highlight("pressing the dodge key while sprinting") .. ".\n"
            .. highlight("Recommended") .. " when jump and dodge are bound to "
            .. highlight("separate keys") .. ".",
        ["zh-cn"] = highlight("疾跑过程中按下闪避键") .. "可触发" .. highlight("滑铲") .. "。\n"
            .. "推荐" .. highlight("跳跃和闪避使用不同按键") .. "的玩家开启。",
    },
    auto_vault = {
        en = "Auto Vault",
        ["zh-cn"] = "自动翻越",
    },
    auto_vault_description = {
        en = highlight("Automatically vaults") .. " in mid-air, no need to "
            .. highlight("hold the jump key") .. ".",
        ["zh-cn"] = "在空中时" .. highlight("自动触发翻越") .. "，无需"
            .. highlight("按住跳跃键") .. "。",
    },
}
