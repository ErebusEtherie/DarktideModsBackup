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
        ru = "Улучшенное передвижение",
    },
    mod_description = {
        en = "Enhance Your Movement Experience",
        ["zh-cn"] = "增强你的移动体验",
        ru = "Better Movement - Улучшите свой опыт передвижения",
    },
    mod_settings = {
        en = "Mod Settings",
        ["zh-cn"] = "模组设置",
        ru = "Настройки мода",
    },
    debug_enabled = {
        en = "Enable Debug Mode",
        ["zh-cn"] = "启用调试模式",
        ru = "Включить режим отладки",
    },
    sprint_settings = {
        en = "Sprint Settings",
        ["zh-cn"] = "疾跑设置",
        ru = "Настройки спринта",
    },
    better_sprint = {
        en = "Better Sprint",
        ["zh-cn"] = "更好的疾跑",
        ru = "Улучшенный спринт",
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
        ru = "Нажмите " .. highlight("клавишу спринта") .. " для активации "
            .. highlight("непрерывного бега") .. ". Непрерывный бег прекращается, когда вы "
            .. highlight("отпускаете клавишу движения вперёд") .. " или выполняете действия, такие как "
            .. highlight("перезарядка") .. " или "
            .. highlight("стрельба") .. ".",
    },
    always_sprint = {
        en = "Always Sprint",
        ["zh-cn"] = "始终疾跑",
        ru = "Всегда бежать",
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
        ru = "Работает с " .. highlight("Улучшенным спринтом") .. ". При включении действия, такие как "
            .. highlight("перезарядка") .. " и "
            .. highlight("стрельба") .. ", "
            .. highlight("больше не прерывают") .. " непрерывный бег.",
    },
    toggle_sprint = {
        en = "Toggle Sprint",
        ["zh-cn"] = "切换疾跑",
        ru = "Переключение спринта",
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
        ru = "Работает с " .. highlight("Улучшенным спринтом") .. ". При включении "
            .. highlight("отпускание клавиши вперёд") .. " не "
            .. highlight("останавливает") .. " непрерывный бег. "
            .. highlight("Клавиша спринта") .. " будет "
            .. highlight("переключать") .. " состояние непрерывного бега.",
    },
    hold_to_sprint = {
        en = "Hold to Sprint",
        ["zh-cn"] = "按住疾跑",
        ru = "Удержание для спринта",
    },
    hold_to_sprint_description = {
        en = "Works with " .. highlight("Better Sprint") .. ". When enabled, it functions "
            .. highlight("identically to the vanilla game") .. "'s hold-to-sprint, with the added fix for "
            .. highlight("unintended action cancellation") .. ".",
        ["zh-cn"] = "与" .. highlight("更好的疾跑") .. "搭配使用，开启后，功能与"
            .. highlight("原版游戏的按住疾跑") .. "完全一致，额外修复了"
            .. highlight("某些武器动作意外取消") .. "的问题。",
        ru = "Работает с " .. highlight("Улучшенным спринтом") .. ". При включении работает "
            .. highlight("идентично оригинальной игре") .. " (удержание для спринта), с дополнительным исправлением "
            .. highlight("непреднамеренной отмены действий") .. ".",
    },
    hold_to_walk = {
        en = "Hold to Walk",
        ["zh-cn"] = "按住慢走",
        ru = "Удержание для ходьбы",
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
        ru = "Работает с " .. highlight("Улучшенным спринтом") .. ". При включении "
            .. highlight("непрерывный бег") .. " включён по умолчанию. "
            .. highlight("Удерживайте клавишу спринта") .. " для перехода в "
            .. highlight("режим ходьбы") .. ".",
    },
    dodge_settings = {
        en = "Dodge Settings",
        ["zh-cn"] = "闪避设置",
        ru = "Настройки уклонения",
    },
    prevent_accidental_jump = {
        en = "No Accidental Jump",
        ["zh-cn"] = "阻止意外跳跃",
        ru = "Без случайных прыжков",
    },
    prevent_accidental_jump_description = {
        en = "Prevents " .. highlight("accidental jump") .. " during " .. highlight("dodging") .. ".\n\n"
            .. highlight("Recommended") ..
            " for players who use the " .. highlight("same key") .. " for both jumping and dodging.\n\n"
            .. highlight("Disable") .. " this option if you use a " .. highlight("separate jump key") .. ".",
        ["zh-cn"] = "防止" .. highlight("闪避") .. "时" .. highlight("意外跳跃") .. "。\n\n"
            .. "推荐" .. highlight("跳跃和闪避使用相同按键") .. "的玩家开启。\n\n"
            .. "如使用" .. highlight("单独跳跃按键") .. "请" .. highlight("关闭") .. "。",
        ru = "Предотвращает " .. highlight("случайный прыжок") .. " во время " .. highlight("уклонения") .. ".\n\n"
            .. highlight("Рекомендуется") ..
            " для игроков, использующих " .. highlight("одну и ту же клавишу") .. " для прыжка и уклонения.\n\n"
            .. highlight("Отключите") .. " эту опцию, если вы используете " .. highlight("отдельную клавишу прыжка") .. ".",
    },
    sprint_dodge = {
        en = "Sprint Dodge",
        ["zh-cn"] = "疾跑闪避",
        ru = "Уклонение во время бега",
    },
    sprint_dodge_description = {
        en = highlight("Allows dodging while sprinting") .. " when the "
            .. highlight("Dodge on Diagonal Forward") .. " option is enabled.",
        ["zh-cn"] = highlight("疾跑状态下也可以闪避") .. "，需要开启游戏内"
            .. highlight("向斜前方闪避") .. "选项。",
        ru = highlight("Позволяет уклоняться во время спринта") .. ", если включена опция "
            .. highlight("Уклонение по диагонали вперёд") .. ".",
    },
    easy_dodge_slide = {
        en = "Easy Dodge Slide",
        ["zh-cn"] = "轻松闪避滑铲",
        ru = "Лёгкое скольжение после уклонения",
    },
    easy_dodge_slide_description = {
        en = "Triggers " .. highlight("dodge-slide") .. " by "
            .. highlight("pressing the dodge key again") .. " while dodging.",
        ["zh-cn"] = highlight("闪避过程中再次按下闪避键") .. "触发" .. highlight("闪避滑铲") .. "。",
        ru = "Активирует " .. highlight("скольжение после уклонения") .. " путём "
            .. highlight("повторного нажатия клавиши уклонения") .. " во время уклонения.",
    },
    hold_dodge_slide = {
        en = "Hold Dodge Slide",
        ["zh-cn"] = "按住闪避滑铲",
        ru = "Удержание для скольжения после уклонения",
    },
    hold_dodge_slide_description = {
        en = "Triggers " .. highlight("dodge-slide") .. " by "
            .. highlight("holding the dodge key") .. ".",
        ["zh-cn"] = highlight("闪避过程中按住闪避键") .. "触发" .. highlight("闪避滑铲") .. "。",
        ru = "Активирует " .. highlight("скольжение после уклонения") .. " путём "
            .. highlight("удержания клавиши уклонения") .. ".",
    },
    hold_dodge_slide_duration = {
        en = "Hold Duration",
        ["zh-cn"] = "按住时间",
        ru = "Время удержания",
    },
    hold_dodge_slide_duration_description = {
        en = "The minimum duration to hold the dodge key to trigger a " .. highlight("dodge-slide") .. ".",
        ["zh-cn"] = "触发" .. highlight("闪避滑铲") .. "所需的最短按住闪避键时间。",
        ru = "Минимальное время удержания клавиши уклонения для активации " .. highlight("уклонения-скольжения") .. ".",
    },
    hold_dodge_slide_guarantee_slide = {
        en = "Guarantee Slide",
        ["zh-cn"] = "保证滑铲",
        ru = "Гарантированное скольжение",
    },
    hold_dodge_slide_guarantee_slide_description = {
        en = "When enabled, if the slide input " .. highlight("window") .. " during a dodge is shorter than your configured hold duration (for example, a Hive Scum's dodge time is shortened after picking the Nimble talent), the crouch input is sent at the very end of the window to ensure the dodge-slide triggers reliably.",
        ["zh-cn"] = "开启后，当闪避过程中的滑铲输入" .. highlight("窗口") .. "短于设定的按住时间时（例如巢都渣滓点选灵活天赋后闪避时间会缩短），在输入窗口的最后时刻输入蹲下指令，确保闪避滑铲稳定触发。",
        ru = "Когда включено, если " .. highlight("окно") .. " ввода скольжения во время уклонения короче заданного времени удержания (например, время уклонения Мрази Улья сокращается после выбора таланта Ловкач), команда приседания вводится в самый конец окна, гарантируя надёжное срабатывание уклонения-скольжения.",
    },
    keep_dodging = {
        en = "Keep Dodging",
        ["zh-cn"] = "连续闪避",
        ru = "Продолжать уклоняться",
    },
    keep_dodging_description = {
        en = highlight("Hold dodge key") .. " to perform " .. highlight("continuous dodge") .. ".",
        ["zh-cn"] = highlight("按住闪避键") .. "以进行" .. highlight("连续闪避") .. "。",
        ru = highlight("Удерживайте клавишу уклонения") .. " для выполнения " .. highlight("непрерывного уклонения") .. ".",
    },
    crouch_settings = {
        en = "Crouch Settings",
        ["zh-cn"] = "蹲伏设置",
        ru = "Настройки приседания",
    },
    better_toggle_crouch = {
        en = "Better Toggle Crouch",
        ["zh-cn"] = "更好的切换蹲伏",
        ru = "Улучшенное переключение приседания",
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
        ru = "Объединяет преимущества " .. highlight("переключения приседания") .. " и " .. highlight("удержания для приседания") .. ".\n"
            .. "Обеспечивает стандартное переключение приседания во время ходьбы.\n"
            .. highlight("Автоматически выходит из приседания") .. " при уклонении, а после скольжения выходит из приседания "
            .. highlight("немедленно при отпускании клавиши") .. ".\n"
            .. highlight("Рекомендуется") .. ", если вы используете " .. highlight("Лёгкое скольжение после уклонения") .. ", "
            .. highlight("Удержание для скольжения после уклонения") .. " или " .. highlight("Лёгкое скольжение во время спринта")
            .. " и предпочитаете " .. highlight("переключение приседания") .. ".",
    },
    easy_sprint_slide = {
        en = "Easy Sprint Slide",
        ["zh-cn"] = "轻松疾跑滑铲",
        ru = "Лёгкое скольжение во время спринта",
    },
    easy_sprint_slide_description = {
        en = "Triggers " .. highlight("slide") .. " by "
            .. highlight("pressing the dodge key while sprinting") .. ".\n\n"
            .. highlight("Recommended") .. " when jump and dodge are bound to "
            .. highlight("separate keys") .. ".",
        ["zh-cn"] = highlight("疾跑过程中按下闪避键") .. "可触发" .. highlight("滑铲") .. "。\n\n"
            .. "推荐" .. highlight("跳跃和闪避使用不同按键") .. "的玩家开启。",
        ru = "Активирует " .. highlight("скольжение") .. " путём "
            .. highlight("нажатия клавиши уклонения во время спринта") .. ".\n\n"
            .. highlight("Рекомендуется") .. ", когда прыжок и уклонение привязаны к "
            .. highlight("разным клавишам") .. ".",
    },
    misc_settings = {
        en = "Misc Settings",
        ["zh-cn"] = "其他设置",
        ru = "Прочие настройки",
    },
    auto_vault = {
        en = "Auto Vault",
        ["zh-cn"] = "自动翻越",
        ru = "Автоматическое перелезание",
    },
    auto_vault_description = {
        en = highlight("Automatically vaults") .. " in mid-air, no need to "
            .. highlight("hold the jump key") .. ".",
        ["zh-cn"] = "在空中时" .. highlight("自动触发翻越") .. "，无需"
            .. highlight("按住跳跃键") .. "。",
        ru = highlight("Автоматически перелезает") .. " в воздухе, не нужно "
            .. highlight("удерживать клавишу прыжка") .. ".",
    },
    no_sprinting_stamina = {
        en = "Conserve Stamina",
        ["zh-cn"] = "保存体力",
        ru = "Экономия выносливости",
    },
    no_sprinting_stamina_description = {
        en = "Pause sprinting during consecutive melee attacks to regenerate stamina. This does not apply to "
            .. highlight("Hold to Sprint") .. ".",
        ["zh-cn"] = "在连续近战攻击过程中暂停疾跑，以恢复体力。对" .. highlight("按住疾跑") .. "无效。",
        ru = "Приостанавливает бег во время серии атак ближнего боя для восстановления выносливости. Не работает с "
            .. highlight("Удержанием для спринта") .. ".",
    },
    luggable_keep_push = {
        en = "Luggable Hold to Push",
        ["zh-cn"] = "按住推击",
        ru = "Удержание для толчка с переносимым предметом",
    },
    luggable_keep_push_description = {
        en = "When carrying any "
            .. highlight("luggable") .. " item, "
            .. highlight("holding")
            .. " the secondary action key will queue repeated push commands. This guarantees that the player will reliably "
            .. highlight("exit") .. " the sprint state and successfully perform a " .. highlight("push action."),
        ["zh-cn"] = "当" .. highlight("搬运任务物品") .. "时，"
            .. highlight("按住") .. "次要按键将可以连续使用推击，以保证玩家可以稳定"
            .. highlight("退出") .. "疾跑状态并使出" .. highlight("推击动作。"),
        ru = "При переноске любого "
            .. highlight("переносимого") .. " предмета "
            .. highlight("удержание")
            .. " клавиши вторичного действия будет ставить в очередь повторяющиеся команды толчка. Это гарантирует, что игрок надежно "
            .. highlight("выйдет") .. " из состояния бега и успешно выполнит " .. highlight("толчок."),
    },
    second = {
        en = "s",
        ["zh-cn"] = "秒",
        ru = "с",
    },
}
