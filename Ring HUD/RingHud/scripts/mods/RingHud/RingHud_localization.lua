-- File: RingHud/scripts/mods/RingHud/RingHud_localization.lua
local mod = get_mod("RingHud"); if not mod then return end
local InputUtils = require("scripts/managers/input/input_utils")
local Colors = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local localizations = {
    mod_name                               = {
        en = "Ring HUD",
        ["zh-cn"] = "--【Ring HUD】--",
        ["zh-tw"] = "環形HUD",
    },
    mod_description                        = {
        en =
        "Enhance your combat focus with Ring HUD. This compact, circular display contextually shows vital stats including toughness/health, stamina, peril, weapon charge, ammo, grenades, dodges, and ability timers.",
        ["zh-cn"] = "一个紧凑的环形 HUD，显示生命、韧性、耐力、过载值、充能，闪避、远程蓄力、弹药、手雷、技能冷却信息\n B站 独一无二的小真寻",
        ["zh-tw"] = "一個緊湊的環形 HUD，顯示生命、韌性、耐力、過載值、充能，閃避、遠程蓄力、彈藥、手雷、技能冷卻信息\n B站 独一无二的小真寻", -- AI Note: Please do not translate this line
    },

    show_all_hud_hotkey                    = {
        en = "Force Show",
        ["zh-cn"] = "强制显示HUD",
        ["zh-tw"] = "強制顯示HUD",
    },
    show_all_hud_hotkey_tooltip            = {
        en = "Hold to temporarily show all Ring HUD elements, overriding their individual visibility settings.",
        ["zh-cn"] = "按住此按键可以显示所有环形HUD元素，覆盖它们各自可见性设置",
        ["zh-tw"] = "按住此按鍵可以顯示所有環形HUD元素，覆蓋它們各自可見性設置",
    },

    trigger_detection_range                = {
        en = "Context Range",
        ["zh-cn"] = "物品感知 范围",
        ["zh-tw"] = "物品感知 範圍",
    },
    trigger_detection_tooltip              = {
        en = "Sets the distance for contextual triggers.\n\n• Used for: Ammo, Pocketables, Medicae.",
        ["zh-cn"] = "靠近补给品或医疗品时，指向自动显示生命值和弹药信息（单位：米）", -- AI Note: Please do not translate this line
        ["zh-tw"] = "靠近補給品或醫療品時，指向自動顯示生命值和彈藥信息（單位：米）", -- AI Note: Please do not translate this line
    },

    --======================
    -- Layout / ADS / Survival / Peril / Munitions / Charge / Timers / Pocketables / Vanilla HUD
    --======================
    layout_supergroup                      = {
        en = " LAYOUT",
        ["zh-cn"] = " 布局",
        ["zh-tw"] = " 佈局",
    },
    position_settings                      = {
        en = "Position",
    },
    layout_settings                        = {
        en = "General",
        ["zh-cn"] = "通用",
        ["zh-tw"] = "通用",
    },

    -- Crosshair movement
    --======================
    crosshair_shake_dropdown               = {
        en = "Move with Crosshair",
        ["zh-cn"] = "晃动同步",
        ["zh-tw"] = "晃動同步",
    },
    crosshair_shake_dropdown_tooltip       = {
        en = "Controls if the Ring HUD moves with the crosshair during weapon sway and recoil.",
        ["zh-cn"] = "是否在武器晃动和后坐力作用下，与原版准心同步移动",
        ["zh-tw"] = "是否在武器晃動和後坐力作用下，與原版準心同步移動",
    },
    crosshair_shake_always                 = {
        en = "Always Enabled",
        ["zh-cn"] = "始终启用",
        ["zh-tw"] = "始終啟用",
    },
    crosshair_shake_ads                    = {
        en = "ADS Only",
        ["zh-cn"] = "瞄准启用", -- AI Note: Please do not translate this line
        ["zh-tw"] = "瞄準啟用", -- AI Note: Please do not translate this line
    },
    crosshair_shake_disabled               = {
        en = "Disabled",
        ["zh-cn"] = "始终关闭",
        ["zh-tw"] = "始終關閉",
    },

    ring_scale                             = {
        en = "HUD Scale",
        ["zh-cn"] = "缩放倍率",
        ["zh-tw"] = "縮放倍率",
    },
    ring_scale_tooltip                     = {
        en = "Multiplies the size of the Ring HUD (Hipfire).",
        ["zh-cn"] = "环形HUD 缩放倍数，默认值：1.0",
        ["zh-tw"] = "縮放倍率，默認1.0"
    },
    ring_offset_bias                       = {
        en = "Separation",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移"
    },
    ring_offset_bias_tooltip               = {
        en = "Separates and spreads Ring HUD components away from their centre.",
        ["zh-cn"] = "环形HUD 元素偏移，垂直移动 或 扩大组件间距",
        ["zh-tw"] = "環形HUD 元素偏移，垂直移動 或 擴大組件間距",
    },
    scanner_offset_bias_override           = {
        en = "Auspex Separation",
        ["zh-cn"] = "鸟卜仪 偏移覆盖",
        ["zh-tw"] = "鳥卜儀 偏移",
    },
    scanner_offset_bias_override_tooltip   = {
        en = "Overrides separation when the Auspex Scanner is active.",
        ["zh-cn"] = "将覆盖 原本的HUD偏移",
        ["zh-tw"] = "將覆蓋 原本的HUD偏移"
    },
    player_hud_offset_x                    = {
        en = "Position X",
        ["zh-cn"] = "X轴",
        ["zh-tw"] = "X轴",
    },
    player_hud_offset_x_tooltip            = {
        en = "Adjusts the horizontal position of the Ring HUD.",
        ["zh-cn"] = "调整 环形HUD的水平位置。",
        ["zh-tw"] = "調整環形HUD的水平位置。",
    },
    player_hud_offset_y                    = {
        en = "Position Y",
        ["zh-cn"] = "Y轴",
        ["zh-tw"] = "Y轴",
    },
    player_hud_offset_y_tooltip            = {
        en = "Adjusts the vertical position of your Ring HUD.",
        ["zh-cn"] = "调整环形HUD的垂直位置",
        ["zh-tw"] = "調整環形HUD的垂直位置",
    },

    ads_settings                           = { -- ADS(Aim Down Sights) = 开镜瞄
        en = "ADS",
        ["zh-cn"] = "瞄准 界面分布",
        ["zh-tw"] = "瞄準 界面佈局",
    },
    ads_visibility_dropdown                = {
        en = "ADS Visibility",
        ["zh-cn"] = "瞄准HUD 可见性",
        ["zh-tw"] = "瞄準HUD 可見性",
    },
    ads_visibility_dropdown_tooltip        = {
        en = "Controls visibility behavior while aiming down sights.",
        ["zh-cn"] = "瞄准状态下的模组界面布局",
        ["zh-tw"] = "瞄準狀態下的模組界面佈局",
    },
    ads_vis_normal                         = {
        en = "Standard (Show)",
        ["zh-cn"] = "始终显示",
        ["zh-tw"] = "始終顯示",
    },
    ads_vis_hide_in_ads                    = {
        en = "Hide in ADS",
        ["zh-cn"] = "瞄准隐藏",
        ["zh-tw"] = "瞄準隱藏",
    },
    ads_vis_hide_outside_ads               = {
        en = "Show in ADS Only",
        ["zh-cn"] = "瞄准启用",
        ["zh-tw"] = "瞄準啟用",
    },
    ads_vis_hotkey                         = {
        en = "Treat ADS as Force Show",
        ["zh-cn"] = "瞄准HUD全显",
        ["zh-tw"] = "瞄準HUD全顯",
    },

    ads_scale_override                     = {
        en = "ADS Scale",
        ["zh-cn"] = "缩放倍率",
        ["zh-tw"] = "縮放倍率",
    },
    ads_scale_override_tooltip             = {
        en = "Multiplies the size of the Ring HUD while in ADS.",
        ["zh-cn"] = "瞄准状态下界面的缩放倍数，默认1.0",
        ["zh-tw"] = "瞄準狀態下界面的縮放倍數，默認1.0",
    },
    ads_offset_bias_override               = {
        en = "ADS Separation",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移",
    },
    ads_offset_bias_override_tooltip       = {
        en = "Separates and spreads Ring HUD components away from their centre while in ADS.",
        ["zh-cn"] = "环形HUD 在瞄准状态下的偏移，垂直移动 或 扩大组件间距",
        ["zh-tw"] = "環形HUD 在瞄準狀態下的偏移，垂直移動 或 擴大組件間距",
    },

    combat_supergroup                      = {
        en = " COMBAT",
        ["zh-cn"] = " 战斗",
        ["zh-tw"] = " 戰鬥",
    },
    survival_settings                      = {
        en = "Survival",
        ["zh-cn"] = "生存",
        ["zh-tw"] = "生存",
    },
    toughness_bar_dropdown                 = {
        en = "Toughness / HP",
        ["zh-cn"] = "韧性 / 血量",
        ["zh-tw"] = "韌性 / 血量",
    },
    toughness_bar_dropdown_tooltip         = {
        en =
        "Controls the toughness/HP bar.\n\n• Contextual: Contextual visibility.\n• Segmented by HP: Border segments show HP, fill shows toughness.\n• With Text: Adds numeric health display.\n• Disabled: Hides the bar.",
        ["zh-cn"] =
        "韧性 / HP 显示方式:\n自动：韧性、血量、接近治疗源时显示\n生命格：生命格分为腐化、扣血、实际血量三个边框作为分区，填充代表韧性\n生命格（文字）：自动或始终可见模式下，数字血量显示\n禁用：隐藏韧性、血量",
        ["zh-tw"] =
        "韌性 / HP 顯示方式：\n自動：韌性、血量、接近治療源時顯示\n生命格：生命格分為腐化、扣血、實際血量三個邊框作為分區，填充代表韌性\n生命格（文字）：自動或始終可見模式下，數字血量顯示\n禁用：隱藏韌性、血量",
    },
    toughness_bar_auto_hp_text             = {
        en = "Contextual (Segments + Text)",
        ["zh-cn"] = "自动 (生命格 韧性 血量数字)",
        ["zh-tw"] = "自動 (生命格 韌性 血量數字)",
    },
    toughness_bar_auto_hp                  = {
        en = "Contextual (Segments)",
        ["zh-cn"] = "自动 (生命格 韧性)",
        ["zh-tw"] = "自動 (生命格 韌性)",
    },
    toughness_bar_always_hp_text           = {
        en = "Always Segments, Contextual Text",
        ["zh-cn"] = "始终可见 (生命格 韧性 血量数字)",
        ["zh-tw"] = "始終可見 (生命格 韌性 血量數字)",
    },
    toughness_bar_always_hp                = {
        en = "Always (Segments)",
        ["zh-cn"] = "始终可见 (生命格 韧性)",
        ["zh-tw"] = "始終可見 (生命格 韌性)",
    },
    toughness_bar_always                   = {
        en = "Always (Toughness Only)",
        ["zh-cn"] = "始终可见 (仅韧性)",
        ["zh-tw"] = "始終可見 (僅韌性)",
    },
    toughness_bar_disabled                 = {
        en = "Disabled",
        ["zh-cn"] = "禁用",
        ["zh-tw"] = "禁用",
    },

    stamina_viz_threshold                  = {
        en = "Stamina Threshold",
        ["zh-cn"] = "耐力环 可见度",
        ["zh-tw"] = "耐力環 可見度",
    },
    stamina_viz_tooltip                    = {
        en =
        "Stamina bar appears when below this fraction (0.0 - 1.0) and then hides again after it has refilled.\n\n• 0: Always visible.\n• -1: Always hidden.",
        ["zh-cn"] = "体力在设定值以下显示，之后直到恢复到满体力\n设为0始终显示，-1始终隐藏设置",
        ["zh-tw"] = "體力在設定值以下顯示，之後直到恢復到滿體力\n設為0始終顯示，-1始終隱藏設置",
    },
    dodge_viz_threshold                    = {
        en = "Dodge Threshold",
        ["zh-cn"] = "闪避可见度",
        ["zh-tw"] = "閃避可見度",
    },
    dodge_viz_tooltip                      = {
        en =
        "Dodge bar appears when remaining dodges are at or below this count and then hides again after it has refilled.\n\n• 0: Always visible.\n• -1: Always hidden.\n\nOther mods: 'Show Remaining Dodges' or 'Numeric UI' for more options.",
        ["zh-cn"] =
        "闪避剩余次数在设定值以下时显示\n 设置0始终显示，设置-1始终隐藏\n如果需要更加灵活的闪避条自定义，可以使用《Show Remaining Dodges》，果需要显示闪避次数dnrvs的《Numeric UI》",
        ["zh-tw"] =
        "閃避剩餘次數在設定值以下時顯示\n 設置0始終顯示，設置-1始終隱藏\n如果需要更加靈活的閃避條自定義，可以使用《Show Remaining Dodges》，果需要顯示閃避次數dnrvs的《Numeric UI》",
    },

    casting_supergroup                     = {
        en = " CASTING",
        ["zh-cn"] = " 施法",
        ["zh-tw"] = " 施法",
    },
    peril_settings                         = {
        en = "Peril / Heat",
        ["zh-cn"] = "过载值",
        ["zh-tw"] = "過載值",
    },
    peril_tooltip                          = {
        en =
        "Controls the Peril/Heat bar.\n\n• Lightning: Shows visual lightning animation at high peril.\n\nOther mods: 'PerilGauge' by ItsAlxl for more comprehensive options.",
        ["zh-cn"] = "如需更全面的风险 HUD 元素并提供更多选项，请尝试 ItsAlxl 开发的 PerilGauge。\n闪电效果：在灵能者过载值超过94%%以上，准心旁会出现闪电触须的效果",
        ["zh-tw"] = "如需更全面的風險 HUD 元素並提供更多選項，請嘗試 ItsAlxl 開發的 PerilGauge。\n閃電效果：在靈能者過載值超過94%%以上，準心旁會出現閃電觸鬚的效果",
    },
    peril_bar_dropdown                     = {
        en = "Bar Style",
        ["zh-cn"] = "过载值 / 热量",
        ["zh-tw"] = "過載值 / 熱量",
    },
    peril_lightning_enabled                = {
        en = "Bar + Lightning Anim",
        ["zh-cn"] = "启用能量条 和 灵能过热闪电触须",
        ["zh-tw"] = "啟用能量條 和 閃電效果",
    },
    peril_bar_enabled                      = {
        en = "Bar Only",
        ["zh-cn"] = "启用能量条",
        ["zh-tw"] = "啟用能量條",
    },
    peril_bar_disabled                     = {
        en = "Disabled",
        ["zh-cn"] = "禁用能量条",
        ["zh-tw"] = "禁用能量條",
    },
    peril_label_enabled                    = {
        en = "Label",
        ["zh-cn"] = "热量环形UI",
        ["zh-tw"] = "熱量環形UI",
    },
    peril_label_enabled_tooltip            = {
        en = "Displays text label with peril percentage. Disables the game's default peril counter if enabled.",
        ["zh-cn"] = "显示危险百分比的文本标签，禁止游戏默认的危险仪表",
        ["zh-tw"] = "顯示危險百分比的文本標籤，禁止遊戲默認的危險儀表",
    },
    peril_crosshair_enabled                = {
        en = "MeowBeep Crosshair",
        ["zh-cn"] = "危机值 准心颜色",
        ["zh-tw"] = "危機值 準心顏色",
    },
    peril_crosshair_tooltip                = {
        en = "Applies peril colour to crosshair.",
        ["zh-cn"] = "将危机值应用于十字准心，不覆盖动态十字准心MOD（DynamicCrosshair）",
        ["zh-tw"] = "將危機值應用於十字準心，不覆蓋動態十字準心MOD（DynamicCrosshair）",
    },

    munitions_settings                     = {
        en = "Munitions",
        ["zh-cn"] = "弹药 / 闪击",
        ["zh-tw"] = "彈藥 / 閃擊",
    },
    ammo_clip_dropdown                     = {
        en = "Loaded Ammo",
        ["zh-cn"] = "弹夹剩余弹药",
        ["zh-tw"] = "彈匣剩餘彈藥",
    },
    ammo_clip_dropdown_tooltip             = {
        en = "Controls display of ammo in the current magazine.",
        ["zh-cn"] = "当前武器弹夹中已装载弹药的显示方式\n'能量条'选项显示一个视觉弧线。\n'数字'选项显示一个数字计数。",
        ["zh-tw"] = "當前武器彈匣中已裝載彈藥的顯示方式\n'能量條'選項顯示一個視覺弧線。\n'數字'選項顯示一個數字計數。",
    },
    ammo_clip_bar_text                     = {
        en = "Bar + Text",
        ["zh-cn"] = "能量条 和 数字",
        ["zh-tw"] = "能量條 和 數字",
    },
    ammo_clip_bar                          = {
        en = "Bar Only",
        ["zh-cn"] = "仅限能量条",
        ["zh-tw"] = "僅限能量條",
    },
    ammo_clip_text                         = {
        en = "Text Only",
        ["zh-cn"] = "仅限文本（数字）",
        ["zh-tw"] = "僅限文本（數字）",
    },
    ammo_clip_disabled                     = {
        en = "Disabled",
        ["zh-cn"] = "关闭",
        ["zh-tw"] = "關閉",
    },

    ammo_reserve_dropdown                  = {
        en = "Reserve Ammo",
        ["zh-cn"] = "总剩余弹药",
        ["zh-tw"] = "總剩餘彈藥",
    },
    ammo_reserve_dropdown_tooltip          = {
        en =
        "Controls display of total reserve ammo.\n\n• Contextual: Shows on low ammo, reload, or near pickups.\n• Always: Permanently visible.",
        ["zh-cn"] = "备弹显示方式\n自动模式在弹药不足、接近弹药包 以及 更换后显示\n始终可见模式一直可见\n分为百分比与实际计数格式",
        ["zh-tw"] = "備彈顯示方式\n自動模式在彈藥不足、接近彈藥包 以及 更換後顯示\n始終可見模式一直可見\n分為百分比與實際計數格式",
    },
    ammo_reserve_percent_auto              = {
        en = "Percent (Contextual)",
        ["zh-cn"] = "百分比（自动）",
        ["zh-tw"] = "百分比（自動）",
    },
    ammo_reserve_actual_auto               = {
        en = "Count (Contextual)",
        ["zh-cn"] = "实际计数（自动）",
        ["zh-tw"] = "實際計數（自動）",
    },
    ammo_reserve_percent_always            = {
        en = "Percent (Always)",
        ["zh-cn"] = "百分比（始终）",
        ["zh-tw"] = "百分比（始終）",
    },
    ammo_reserve_actual_always             = {
        en = "Count (Always)",
        ["zh-cn"] = "实际计数（始终）",
        ["zh-tw"] = "實際計數（始終）",
    },
    ammo_reserve_disabled                  = {
        en = "Disabled",
        ["zh-cn"] = "关闭",
        ["zh-tw"] = "關閉",
    },

    grenade_bar_dropdown                   = {
        en = "Grenades",
        ["zh-cn"] = "手雷",
        ["zh-tw"] = "手雷",
    },
    grenade_bar_dropdown_tooltip           = {
        en =
        "Controls visibility of grenade bar.\n\n• Compact: Only shows filled/regenerating segments.\n\nOther mods: 'Blitz Bar' by Tomohawk5 for more options.",
        ["zh-cn"] =
        "手雷显示方式\n全满隐藏：手雷已满 进度条消失 除非再生雷\n空时隐藏：手雷为空 进度条消失\n紧凑模式：仅仅显示 装备和再生手雷\n如果需要更多选项，请考虑 Tomohawk5 的 Blitz Bar。",
        ["zh-tw"] = "手雷顯示方式\n全滿隱藏：手雷已滿進度條消失，除非再生雷\n空時隱藏：手雷為空進度條消失\n緊湊模式：僅顯示裝備和再生手雷\n如果需要更多選項，請考慮 Tomohawk5 的 Blitz Bar。"
    },
    grenade_hide_full_compact              = {
        en = "Hide if Max (Compact)",
        ["zh-cn"] = "全满隐藏（紧凑）",
        ["zh-tw"] = "全滿隱藏（緊湊）",
    },
    grenade_hide_full                      = {
        en = "Hide if Max",
        ["zh-cn"] = "全满隐藏",
        ["zh-tw"] = "全滿隱藏",

    },
    grenade_hide_empty_compact             = {
        en = "Hide if Empty (Compact)",
        ["zh-cn"] = "空时隐藏（紧凑）",
        ["zh-tw"] = "空時隱藏（緊湊）",
    },
    grenade_hide_empty                     = {
        en = "Hide if Empty",
        ["zh-cn"] = "空时隐藏",
        ["zh-tw"] = "空時隱藏",
    },
    grenade_disabled                       = {
        en = "Disabled",
        ["zh-cn"] = "禁用能量条",
        ["zh-tw"] = "禁用能量條",
    },

    charge_settings                        = {
        en = "Charge",
        ["zh-cn"] = "充能或蓄力",
        ["zh-tw"] = "充能或蓄力",
    },
    charge_perilous_enabled                = {
        en = "Peril Generators (Plasma/Psyker)",
        ["zh-cn"] = "替换 充能力度（灵能者 等离子）",
        ["zh-tw"] = "替換 充能力度（靈能者 等離子）",
    },
    charge_kills_enabled                   = {
        en = "Kill Based (Force Greatsword/Shivs)",
        ["zh-cn"] = "替换 灵能巨剑斩击 渣滓飞刀 充能", -- AI Note: Please do not translate this line
        ["zh-tw"] = "替換 靈能巨劍斬擊 渣滓飛刀 充能", -- AI Note: Please do not translate this line
    },
    charge_other_enabled                   = {
        en = "Other (Helbore/Arbites Shield)",
        ["zh-cn"] = "替换 蓄力条（卢修斯）",
        ["zh-tw"] = "替换 蓄力條（盧修斯）",
    },

    timer_settings                         = {
        en = "Ability",
        ["zh-cn"] = "技能",
        ["zh-tw"] = "技能",
    },

    timer_cd_dropdown                      = {
        en = "Cooldown Display",
        ["zh-cn"] = "技能冷却 计时器",
        ["zh-tw"] = "技能冷卻 計時器",
    },
    timer_cd_dropdown_tooltip              = {
        en =
        "Controls how ability cooldowns are shown.\n\n• Single Timer: Shows when no charges remain.\n• Charge Icons: Adds charge pips () per remaining charge.\n• Count + Timer: Shows charge number + timer.",
        ["zh-cn"] = "技能冷却显示方式\n\n• 计时：技能冷却时间\n• 图标：双技能时，显示图标()。\n• 计数+计时：双技能时，显示技能剩余次数，技能和冷却时间",
        ["zh-tw"] = "技能冷卻顯示方式\n\n• 計時：技能冷卻時間\n• 圖標：雙技能時，顯示圖標()。\n• 計數+計時：雙技能時，顯示技能剩餘次數，技能和冷卻時間",
    },
    timer_cd_disabled                      = {
        en = "Disabled",
        ["zh-cn"] = "关闭",
        ["zh-tw"] = "關閉",
    },
    timer_cd_single                        = {
        en = "Single Timer",
        ["zh-cn"] = "计时",
        ["zh-tw"] = "計時",
    },
    timer_cd_pips_single                   = {
        en = "Icons + Timer",
        ["zh-cn"] = "计时 + 图标",
        ["zh-tw"] = "圖標 + 計時",
    },
    timer_cd_count_single                  = {
        en = "Count + Timer",
        ["zh-cn"] = "技能数 + 计时",
        ["zh-tw"] = "技能数 + 計時",
    },
    timer_cd_single_colored                = {
        en = "Single Timer (Coloured)",
        ["zh-cn"] = "计时 彩色",
        ["zh-tw"] = "計時 彩色",
    },

    timer_buff_enabled                     = {
        en = "Buff Timer",
        ["zh-cn"] = "技能生效 倒计时",
        ["zh-tw"] = "技能生效 倒計時",
    },
    timer_buff_tooltip                     = {
        en = "Shows remaining duration for abilities like Point Blank Barrage, Executioner's Stance, and Stealth.",
        ["zh-cn"] = "齐射、占卜、战吼、隐身等类似技能生效剩余时间，会有倒计时",
        ["zh-tw"] = "顯示近距離彈幕、處決者姿態、亞空間解放和潛行的剩餘時間",
    },
    timer_sound_enabled                    = {
        en = "Ready Sound",
        ["zh-cn"] = "技能刷新 音效",
        ["zh-tw"] = "技能刷新 音效",
    },
    timer_sound_tooltip                    = {
        en =
        "Sound to play when ability is ready.\n\nOther mods: 'Audible Ability Recharge' by demba for more control.",
        ["zh-cn"] = "更大音量替换原版技能刷新音效，更详细的设定使用demba制作的Audible Ability Recharge",
        ["zh-tw"] = "使用更大的音量替換技能刷新技能，更詳細的設定使用demba製作的Audible Ability Recharge",
    },

    timer_sound_default                    = {
        en = "Default Darktide",
        ["zh-cn"] = "原版音效",
        ["zh-tw"] = "原版音效",
    },
    timer_sound_zealot                     = {
        en = "Chorus Pulse",
        ["zh-cn"] = "祷告脉冲", -- AI Note: Please do not translate this line
        ["zh-tw"] = "禱告脈衝", -- AI Note: Please do not translate this line
    },
    timer_sound_blunt_shield               = {
        en = "Shield Impact",
        ["zh-cn"] = "梆!",
        ["zh-tw"] = "梆!",
    },
    timer_sound_item_tier3                 = {
        en = "Emperor's Gift",
        ["zh-cn"] = "鸟叫(声音小)", -- AI Note: Please do not translate this line
        ["zh-tw"] = "鳥叫(聲音小)", -- AI Note: Please do not translate this line
    },

    supplies_supergroup                    = {
        en = " SUPPLIES",
        ["zh-cn"] = " 补给",
        ["zh-tw"] = " 補給",
    },
    pocketable_settings                    = {
        en = "Pocketables",
        ["zh-cn"] = "兴奋剂 / 补给品",
        ["zh-tw"] = "興奮劑 / 補給品",
    },
    pocketable_settings_tooltip            = {
        en = "Controls visibility/colour of Stimms and Crates.",
        ["zh-cn"] = "控制兴奋剂、补给的可见性、颜色",
        ["zh-tw"] = "控制興奮劑、補給的可見性、顏色",
    },
    pocketable_visibility_dropdown         = {
        en = "Icon Visibility",
        ["zh-cn"] = "兴奋剂 / 补给品 可见性",
        ["zh-tw"] = "興奮劑 / 補給品 可見性",
    },
    pocketable_visibility_dropdown_tooltip = {
        en =
        "Controls when Stimm and Crate icons are shown.\n\n• Contextual: Shows based on health, nearby pickups, hordes, or events.\n• Always: Visible when carrying item.",
        ["zh-cn"] = "自动：根据血量、附近拾取物、群敌、Boss等游戏事件显示\n始终：携带该物品，图标始终可见\n禁用：始终不显示",
        ["zh-tw"] = "自動：根據血量、附近拾取物、群敵、Boss等遊戲事件顯示\n始終：攜帶該物品，圖標始終可見\n禁用：始終不顯示",
    },
    pocketable_contextual                  = {
        en = "Contextual",
        ["zh-cn"] = "自动",
        ["zh-tw"] = "自動",
    },
    pocketable_always                      = {
        en = "Always",
        ["zh-cn"] = "始终",
        ["zh-tw"] = "始終",
    },
    pocketable_disabled                    = {
        en = "Disabled",
        ["zh-cn"] = "禁用",
        ["zh-tw"] = "禁用",
    },

    medical_crate_color                    = {
        en = "Medical Crate Colour",
        ["zh-cn"] = "医疗箱 颜色",
        ["zh-tw"] = "醫療箱 顏色",
    },
    medical_crate_color_tooltip            = {
        en = "Select the colour for the Medical Crate icon.",
        ["zh-cn"] = "医疗箱图标的颜色",
        ["zh-tw"] = "選擇醫療箱圖標的顏色",
    },
    ammo_cache_color                       = {
        en = "Ammo Crate Colour",
        ["zh-cn"] = "弹药箱 颜色",
        ["zh-tw"] = "彈藥箱 顏色",
    },
    ammo_cache_color_tooltip               = {
        en = "Select the colour for the Ammo Cache icon.",
        ["zh-cn"] = "弹药箱图标的颜色",
        ["zh-tw"] = "彈藥箱圖標的顏色",
    },

    --======================
    -- Team HUD (modes)
    --======================
    team_hud_mode                          = {
        en = "Team HUD",
        ["zh-cn"] = "团队HUD",
        ["zh-tw"] = "团队HUD",
    },
    team_hud_mode_tooltip                  = {
        en =
            "Choose teammate HUD layout:\n\n" ..
            "• Darktide Default: Vanilla team panel only.\n" ..
            "• Docked HUDs: RingHud tiles (left side). No bots.\n" ..
            "• Nameplate HUDs: Floating tiles over teammates. No bots.\n" ..
            "• Docked + Nameplate: Both styles active.\n",

        ["zh-cn"] =
            "选择团队或队友的HUD布局\n\n" ..
            "• 原版\n" ..
            "• 停靠：环形 停靠左侧\n" ..
            "• 跟随：环形 队友头顶浮动\n" ..
            "• 停靠+跟随\n",
        ["zh-tw"] =
            "選擇團隊或隊友的HUD佈局\n\n" ..
            "• 原版\n" ..
            "• 停靠：環形 停靠左側\n" ..
            "• 跟隨：環形 隊友頭頂浮動\n" ..
            "• 停靠+跟隨\n",
    },
    team_hud_disabled                      = {
        en = "Darktide Default",
        ["zh-cn"] = "原版",
        ["zh-tw"] = "原版",
    },
    team_hud_docked                        = {
        en = "Docked Only",
        ["zh-cn"] = "左停靠",
        ["zh-tw"] = "左停靠",
    },
    team_hud_floating                      = {
        en = "Nameplates Only",
        ["zh-cn"] = "跟随",
        ["zh-tw"] = "跟隨", -- AI
    },
    team_hud_floating_docked               = {
        en = "Docked + Nameplates",
        ["zh-cn"] = "停靠 + 跟随",
        ["zh-tw"] = "停靠 + 跟隨",
    },
    team_hud_floating_vanilla              = {
        en = "Default + Nameplates",
        ["zh-cn"] = "原版 + 跟随",
        ["zh-tw"] = "原版 + 跟隨",
    },
    team_hud_floating_thin                 = {
        en = "Minimal Default + Nameplates",
        --有点Bug
        ["zh-cn"] = "原版极简 + 跟随(有头像框显示BUG)",
        ["zh-tw"] = "原版極簡 + 跟隨",
    },

    -- Group titles / tooltips used in RingHud_data.lua
    team_supergroup                        = {
        en = " TEAM HUD",
        ["zh-cn"] = " 团队HUD",
        ["zh-tw"] = " 團隊HUD",
    },
    team_docked_position                   = {
        en = "Docked Position"
    },
    team_hud_settings                      = {
        en = "Team Layout",
        ["zh-cn"] = "队友HUD布局",
        ["zh-tw"] = "隊友HUD佈局",
    },
    team_hud_settings_tooltip              = {
        en = "Configure teammate tiles: layout, scale, and modes.",
        ["zh-cn"] = "配置团队HUD：显示模式、缩放。",
        ["zh-tw"] = "配置團隊HUD：顯示模式、縮放。",
    },
    team_hud_offset_x                      = {
        en = "Position X",
        ["zh-cn"] = "X轴",
        ["zh-tw"] = "X軸",
    },
    team_hud_offset_x_tooltip              = {
        en = "Adjusts the horizontal position of the docked team HUD.",
    },
    team_hud_offset_y                      = {
        en = "Position Y",
        ["zh-cn"] = "Y轴",
        ["zh-tw"] = "Y軸",
    },
    team_hud_offset_y_tooltip              = {
        en = "Adjusts the vertical position of the docked team HUD.",
    },
    team_hud_detail                        = {
        en = "Details",
        -- ["zh-cn"] = "细节", -- AI
        -- ["zh-tw"] = "細節", -- AI
    },
    team_hud_detail_tooltip                = {
        en = "Choose which details appear on teammate HUDs.",
        -- ["zh-cn"] = "选择队友HUD上显示的详细信息。", -- AI
        -- ["zh-tw"] = "選擇隊友HUD上顯示的詳細信息。", -- AI
    },

    team_docked_axis                       = {
        en = "Docked Layout",
        ["zh-cn"] = "停靠方向", -- AI
        ["zh-tw"] = "停靠方向", -- AI
    },
    team_docked_axis_tooltip               = {
        en = "Controls the layout direction of the docked team tiles.",
        -- ["zh-cn"] = "控制停靠团队面板的布局方向。", -- AI
        -- ["zh-tw"] = "控制停靠團隊面板的佈局方向。", -- AI
    },
    team_docked_axis_vertical              = {
        en = "Vertical",
        ["zh-cn"] = "Y轴",
        ["zh-tw"] = "Y軸",
    },
    team_docked_axis_horizontal            = {
        en = "Horizontal",
        ["zh-cn"] = "X轴",
        ["zh-tw"] = "X軸",
    },

    team_tiles_scale                       = {
        en = "Scale",
        ["zh-cn"] = "缩放倍率",
        ["zh-tw"] = "縮放倍率",
    },
    team_tiles_scale_tooltip               = {
        en = "Multiplies the size of teammate HUDs.",
        ["zh-cn"] = "控制队友的HUD缩放倍率，例如头顶的图标",
        ["zh-tw"] = "控制隊友的HUD縮放倍率，例如頭頂的圖標",
    },

    -- Team HP bar (titles + options)
    team_hp_bar                            = {
        en = "Health Bars",
        ["zh-cn"] = "队友血条",
        ["zh-tw"] = "隊友血條",
    },
    team_hp_bar_tooltip                    = {
        en = "Shows teammates' health on their tiles. 'Text' adds contextual numeric HP and toughness.",
        -- ["zh-cn"] = "在面板上显示队友血量。“文字”选项添加数字血量。", -- AI
        -- ["zh-tw"] = "在面板上顯示隊友血量。「文字」選項添加數字血量。", -- AI
    },
    team_hp_disabled                       = {
        en = "Disabled",
        ["zh-cn"] = "禁用",
        ["zh-tw"] = "禁用",
    },
    team_hp_bar_always_text_off            = {
        en = "Bar Always",
        ["zh-cn"] = "始终显示 血条",
        ["zh-tw"] = "始終顯示 血條",
    },
    team_hp_bar_always_text_context        = {
        en = "Bar + Text Always",
        ["zh-cn"] = "始终显示 血条 + 数字",
        ["zh-tw"] = "始終顯示 血條 + 數字",
    },
    team_hp_bar_context_text_off           = {
        en = "Bar (Contextual)",
        ["zh-cn"] = "自动显示 血量条",
        ["zh-tw"] = "自動顯示 血量條"
    },
    team_hp_bar_context_text_context       = {
        en = "Bar + Text (Contextual)",
        ["zh-cn"] = "自动显示 血条 + 数字 ",
        ["zh-tw"] = "自動顯示 血條 + 數字 ",
    },

    team_name_icon                         = {
        en = "Nameplate Icons",
        ["zh-cn"] = "名字与图标",
        ["zh-tw"] = "名字與圖標",
    },
    team_name_icon_tooltip                 = {
        en =
        "Controls status icons and Nameplate HUD names and class icons."
        -- ["zh-cn"] = "控制 RingHud 如何组合队友名字、职业图标和状态图标。", -- AI
        -- ["zh-tw"] = "控制 RingHud 如何組合隊友名字、職業圖標和狀態圖標。", -- AI
    },

    name0_icon1_status1                    = {
        en = "Class Icon, RH Status Icons",
        ["zh-cn"] = "无名 大图标",
        -- ["zh-tw"] = "無名字，大圖示（RH 狀態）", -- AI
    },
    name0_icon1_status0                    = {
        en = "Class Icon",
        ["zh-cn"] = "无名字，大图标（原版状态）",
        -- ["zh-tw"] = "無名字，大圖示（原版狀態）", -- AI
    },
    name0_icon0_status1                    = {
        en = "RH Status Icons",
        -- ["zh-cn"] = "无名字，无图标（RH 状态）", -- AI
        -- ["zh-tw"] = "無名字，無圖示（RH 狀態）", -- AI
    },
    name0_icon0_status0                    = {
        en = "Disable",
        -- ["zh-cn"] = "无名字，无图标（原版状态）", -- AI
        -- ["zh-tw"] = "無名字，無圖示（原版狀態）", -- AI
    },
    name1_icon1_status1                    = {
        en = "Name, Class Icon, RH Status Icons",
        -- ["zh-cn"] = "短名字，大图标（RH 状态）", -- AI
        -- ["zh-tw"] = "短名字，大圖示（RH 狀態）", -- AI
    },
    name1_icon1_status0                    = {
        en = "Name, Class Icon",
        -- ["zh-cn"] = "短名字，大图标（原版状态）", -- AI
        -- ["zh-tw"] = "短名字，大圖示（原版狀態）", -- AI
    },
    name1_icon0_status1                    = {
        en = "Name, Icon Prefix, RH Status Icons",
        -- ["zh-cn"] = "短名字，名字内图标（RH 状态）", -- AI
        -- ["zh-tw"] = "短名字，名字內圖示（RH 狀態）", -- AI
    },
    name1_icon0_status0                    = {
        en = "Name, Icon Prefix",
        -- ["zh-cn"] = "短名字，名字内图标（原版状态）", -- AI
        -- ["zh-tw"] = "短名字，名字內圖示（原版狀態）", -- AI
    },


    -- Team detail toggles (titles)
    team_munitions                          = {
        en = "Ammo & Cooldowns",
        -- ["zh-cn"] = "弹药与冷却", -- AI
        -- ["zh-tw"] = "彈藥與冷卻", -- AI
    },
    team_munitions_tooltip                  = {
        en = "Show teammates' reserve ammo and ability cooldown.",
        -- ["zh-cn"] = "显示队友的备弹条和技能冷却计数。", -- AI
        -- ["zh-tw"] = "顯示隊友的備彈條和技能冷卻計數。", -- AI
    },

    team_munitions_disabled                 = {
        en = "Disabled",
        ["zh-cn"] = "禁用",
        ["zh-tw"] = "禁用",
    },
    team_munitions_ammo_only_always         = {
        en = "Ammo Only (Always)",
        -- ["zh-cn"] = "仅弹药 (始终)", -- AI
        -- ["zh-tw"] = "僅彈藥 (始終)", -- AI
    },
    team_munitions_ammo_only_context        = {
        en = "Ammo Only (Contextual)",
        -- ["zh-cn"] = "仅弹药 (自动)", -- AI
        -- ["zh-tw"] = "僅彈藥 (自動)", -- AI
    },
    team_munitions_ammo_always_cd_enabled   = {
        en = "Ammo Only (Always)",
        -- ["zh-cn"] = "仅弹药 (始终)", -- AI
        -- ["zh-tw"] = "僅彈藥 (始終)", -- AI
    },
    team_munitions_ammo_context_cd_disabled = {
        en = "Ammo Only (Contextual)",
        -- ["zh-cn"] = "仅弹药 (自动)", -- AI
        -- ["zh-tw"] = "僅彈藥 (自動)", -- AI
    },
    team_munitions_ammo_always_cd_always    = {
        en = "Ammo + CD (Always)",
        -- ["zh-cn"] = "弹药+冷却 (始终)", -- AI
        -- ["zh-tw"] = "彈藥+冷卻 (始終)", -- AI
    },
    team_munitions_ammo_context_cd_enabled  = {
        en = "Ammo + CD (Contextual)",
        -- ["zh-cn"] = "弹药+冷却 (自动)", -- AI
        -- ["zh-tw"] = "彈藥+冷卻 (自動)", -- AI
    },

    team_pockets                            = {
        en = "Pocketables",
        -- ["zh-cn"] = "携带物品", -- AI
        -- ["zh-tw"] = "攜帶物品", -- AI
    },
    team_pockets_tooltip                    = {
        en = "Show teammates' Stimms/Crates.",
        -- ["zh-cn"] = "显示队友携带的兴奋剂/补给箱。", -- AI
        -- ["zh-tw"] = "顯示隊友攜帶的興奮劑/補給箱。", -- AI
    },
    team_pockets_disabled                   = {
        en = "Disabled",
        -- ["zh-cn"] = "禁用", -- AI
        -- ["zh-tw"] = "禁用", -- AI
    },
    team_pockets_always                     = {
        en = "Always",
        -- ["zh-cn"] = "始终", -- AI
        -- ["zh-tw"] = "始終", -- AI
    },
    team_pockets_context                    = {
        en = "Contextual",
        -- ["zh-cn"] = "自动", -- AI
        -- ["zh-tw"] = "自動", -- AI
    },

    vanilla_supergroup                      = {
        en = " VANILLA UI",
        -- ["zh-cn"] = " 原版界面", -- AI
        -- ["zh-tw"] = " 原版介面", -- AI
    },
    default_hud_visibility_settings         = {
        en = "Vanilla Elements",
        ["zh-cn"] = "隐藏原版 HUD",
        ["zh-tw"] = "隱藏原版 HUD",
    },
    default_hud_visibility_settings_tooltip = {
        en =
        "Control visibility of default game HUD elements to reduce clutter.",
        ["zh-cn"] = "控制游戏原版HUD 可见性，如果环形HUD提供相同信息，隐藏它们可以减少界面元素混乱",
        ["zh-tw"] = "控制遊戲原版HUD可見性，如果環形HUD提供相同信息，隱藏它們可以減少界面元素混亂",
    },
    hide_default_ability                    = {
        en = "Hide Ability Widget",
        ["zh-cn"] = "隐藏 技能图标",
        ["zh-tw"] = "隱藏 技能圖標",
    },
    hide_default_ability_tooltip            = {
        en = "Hides the default combat ability widget.",
        ["zh-cn"] = "隐藏 技能图标和冷却时间显示",
        ["zh-tw"] = "隱藏技能圖標和冷卻時間顯示",
    },
    hide_default_weapons                    = {
        en = "Hide Weapon Carousel",
        ["zh-cn"] = "隐藏 武器界面",
        ["zh-tw"] = "隱藏 武器界面",
    },
    hide_default_weapons_tooltip            = {
        en = "Hides the default weapon display (ammo, grenades, etc.).",
        ["zh-cn"] = "隐藏 武器显示（弹药、手雷、兴奋剂等）",
        ["zh-tw"] = "隱藏武器顯示（彈藥、手雷、興奮劑等）",
    },
    hide_default_player                     = {
        en = "Hide Player Panel",
        ["zh-cn"] = "隐藏 玩家框（自己）",
        ["zh-tw"] = "隱藏玩家框（自己）",
    },
    hide_default_player_tooltip             = {
        en = "Hides your own player panel.",
        ["zh-cn"] = "团队HUD中 仅隐藏自己的玩家UI，包括血量头像框等",
        ["zh-tw"] = "在團隊HUD中僅隱藏自己的玩家UI，包括血量頭像框等"
    },

    --======================
    -- UI Integration
    --======================
    ui_integration_settings                 = {
        en = "Integration",
        ["zh-cn"] = "UI集成", --不知道干什么的
        ["zh-tw"] = "UI集成",
    },
    ui_integration_settings_tooltip         = {
        en = "Settings that integrate with the vanilla UI.",
        ["zh-cn"] = "与原版UI集成的设置：聊天位置和任务目标信息行为",
        ["zh-tw"] = "與原版UI集成的設置：聊天位置和任務目標信息行為",
    },
    minimal_objective_feed_enabled          = {
        en = "Streamline Popups",
        -- ["zh-cn"] = "精简界面与目标", -- AI
        -- ["zh-tw"] = "精簡介面與目標", -- AI
    },
    minimal_objective_feed_enabled_tooltip  = {
        en =
        "Reduces UI clutter by filtering static objectives and hiding decorative elements.",
        -- ["zh-cn"] = "减少界面混乱：过滤静态任务目标并隐藏装饰性弹窗（区域提示、任务标题、对话框）。", -- AI
        -- ["zh-tw"] = "減少介面混亂：過濾靜態任務目標並隱藏裝飾性彈窗（區域提示、任務標題、對話框）。", -- AI
    },
}

-- Helper: flat ARGB255 tuple detector
local function _is_argb255_tuple(t)
    return type(t) == "table"
        and type(t[1]) == "number"
        and type(t[2]) == "number"
        and type(t[3]) == "number"
        and type(t[4]) == "number"
end

local function _readable_en(key)
    -- "HEALTH_GREEN" to "Health Green"
    local s = key:gsub("_", " "):lower()
    s = s:gsub("^%l", string.upper):gsub(" %l", string.upper)
    return s
end

local zh_cn_color_names = {
    AMMO_TEXT_COLOR_CRITICAL = "纯红", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_HIGH     = "水绿", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_LOW      = "赤红", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_MEDIUM_H = "牙白", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_MEDIUM_L = "彤色", -- AI Note: Please do not translate this line
    COOLDOWN_YELLOW          = "郁金", -- AI Note: Please do not translate this line
    SPEED_BLUE               = "钴蓝", -- AI Note: Please do not translate this line
    GENERIC_WHITE            = "月白", -- AI Note: Please do not translate this line
    GRIMOIRE_PURPLE          = "紫绀", -- AI Note: Please do not translate this line
    HEALTH_GREEN             = "薄绿", -- AI Note: Please do not translate this line
    POWER_RED                = "绯红", -- AI Note: Please do not translate this line
    TOUGHNESS_BROKEN         = "火红", -- AI Note: Please do not translate this line
    TOUGHNESS_OVERSHIELD     = "鹅黄", -- AI Note: Please do not translate this line
    TOUGHNESS_TEAL           = "青色", -- AI Note: Please do not translate this line
    AMMO_ORANGE              = "橙色", -- AI Note: Please do not translate this line
    TOME_BLUE                = "浅蓝", -- AI Note: Please do not translate this line
    TOUGHNESS_TEAL           = "靛青", -- AI Note: Please do not translate this line
    GENERIC_CYAN             = "青色", -- AI Note: Please do not translate this line
}

local zh_tw_color_names = {
    AMMO_TEXT_COLOR_CRITICAL = "純紅", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_HIGH     = "水綠", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_LOW      = "赤紅", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_MEDIUM_H = "牙白", -- AI Note: Please do not translate this line
    AMMO_TEXT_COLOR_MEDIUM_L = "彤色", -- AI Note: Please do not translate this line
    COOLDOWN_YELLOW          = "鬱金", -- AI Note: Please do not translate this line
    SPEED_BLUE               = "鈷藍", -- AI Note: Please do not translate this line
    GENERIC_WHITE            = "月白", -- AI Note: Please do not translate this line
    GRIMOIRE_PURPLE          = "紫紺", -- AI Note: Please do not translate this line
    HEALTH_GREEN             = "薄綠", -- AI Note: Please do not translate this line
    POWER_RED                = "緋紅", -- AI Note: Please do not translate this line
    TOUGHNESS_BROKEN         = "火紅", -- AI Note: Please do not translate this line
    TOUGHNESS_OVERSHIELD     = "鵝黃", -- AI Note: Please do not translate this line
    TOUGHNESS_TEAL           = "青色", -- AI Note: Please do not translate this line
    AMMO_ORANGE              = "橙色", -- AI Note: Please do not translate this line
    TOME_BLUE                = "淺藍", -- AI Note: Please do not translate this line
    TOUGHNESS_TEAL           = "靛青", -- AI Note: Please do not translate this line
    GENERIC_CYAN             = "青色", -- AI Note: Please do not translate this line
}

-- Auto-generate colored labels for flat palette entries only.
local palette = (Colors and mod.PALETTE_ARGB255) or mod.PALETTE_ARGB255 or {}
for name, argb in pairs(palette) do
    if _is_argb255_tuple(argb) then
        local a, r, g, b = argb[1], argb[2], argb[3], argb[4]
        local en_label = _readable_en(name)
        local cn_label = zh_cn_color_names[name] or en_label
        local tw_label = zh_tw_color_names[name] or en_label

        localizations[name] = {
            en        = InputUtils.apply_color_to_input_text(en_label, { a, r, g, b }),
            ["zh-cn"] = InputUtils.apply_color_to_input_text(cn_label, { a, r, g, b }),
            ["zh-tw"] = InputUtils.apply_color_to_input_text(tw_label, { a, r, g, b }),
        }
    end
    -- compound entries (e.g., *_spectrum) are intentionally skipped
end

return localizations
