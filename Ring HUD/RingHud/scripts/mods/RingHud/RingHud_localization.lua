-- File: RingHud/RingHud_localization.lua
local mod = get_mod("RingHud"); if not mod then return end
local InputUtils = require("scripts/managers/input/input_utils")
local Colors = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local localizations = {
    mod_name                    = {
        en = "Ring HUD",
        ["zh-cn"] = "环形HUD",
        ["zh-tw"] = "環形HUD",
    },
    mod_description             = {
        en =
        "Enhance your combat focus with Ring HUD. This compact, circular display intelligently shows vital stats including toughness/health, stamina, peril, weapon charge, ammo, grenades, dodges, and ability timers, appearing contextually when most relevant to your actions.",
        ["zh-cn"] = "一个紧凑的环形 HUD，显示生命、韧性、耐力、过载值、充能，闪避、远程蓄力、弹药、手雷、技能冷却信息\n B站 独一无二的小真寻",
        ["zh-tw"] = "一個緊湊的環形 HUD，顯示生命、韌性、耐力、過載值、充能，閃避、遠程蓄力、彈藥、手雷、技能冷卻信息\n B站 獨一無二的小真尋",
    },

    show_all_hud_hotkey         = {
        en = "Force Show HUD Hotkey",
        ["zh-cn"] = "强制显示HUD",
        ["zh-tw"] = "強制顯示HUD",
    },
    show_all_hud_hotkey_tooltip = {
        en = "Hold this key to temporarily show all Ring HUD elements, overriding their individual visibility settings.",
        ["zh-cn"] = "按住此按键可以显示所有环形HUD元素，覆盖它们各自可见性设置",
        ["zh-tw"] = "按住此按鍵可以顯示所有環形HUD元素，覆蓋它們各自可見性設置",
    },

    trigger_detection_range     = {
        en = "Proximity Awareness Range",
        ["zh-cn"] = "物品感知 范围",
        ["zh-tw"] = "物品感知 範圍",
    },
    trigger_detection_tooltip   = {
        en = "Sets the distance (in meters) for context based automatic visibility rules.",
        ["zh-cn"] = "靠近补给品或医疗品时，自动显示生命值和弹药信息（单位：米）",
        ["zh-tw"] = "靠近補給品或醫療品時，自動顯示生命值和彈藥信息（單位：米）",
    },



    --======================
    -- Crosshair movement
    --======================
    crosshair_shake_dropdown               = {
        en = "Move with Crosshair",
        ["zh-cn"] = "晃动同步",
        ["zh-tw"] = "晃動同步",
    },
    crosshair_shake_dropdown_tooltip       = {
        en = "Controls if the Ring HUD moves along with the vanilla crosshair during weapon sway and recoil.",
        ["zh-cn"] = "是否在武器晃动和后坐力作用下，与原版准心同步移动",
        ["zh-tw"] = "是否在武器晃動和後坐力作用下，與原版準心同步移動",
    },
    crosshair_shake_always                 = {
        en = "Always Enabled",
        ["zh-cn"] = "始终启用",
        ["zh-tw"] = "始終啟用",
    },
    crosshair_shake_ads                    = {
        en = "Aim Down Sights Only",
        ["zh-cn"] = "瞄准启用",
        ["zh-tw"] = "瞄準啟用",
    },
    crosshair_shake_disabled               = {
        en = "Disabled",
        ["zh-cn"] = "始终关闭",
        ["zh-tw"] = "始終關閉",
    },

    --======================
    -- Layout / ADS / Survival / Peril / Munitions / Charge / Timers / Pocketables / Vanilla HUD
    --======================
    layout_settings                        = {
        en = "Layout",
        ["zh-cn"] = "界面分布",
        ["zh-tw"] = "界面分佈",
    },
    ring_scale                             = {
        en = "Ring HUD Scale",
        ["zh-cn"] = "缩放倍率",
        ["zh-tw"] = "縮放倍率",
    },
    ring_scale_tooltip                     = {
        en = "Multiplies the size of the Ring HUD when not in ADS. Default: 1.0.",
        ["zh-cn"] = "环形HUD 缩放倍数，默认值：1.0",
        ["zh-tw"] = "縮放倍率，默認1.0"
    },
    ring_offset_bias                       = {
        en = "Ring HUD Separation",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移"
    },
    ring_offset_bias_tooltip               = {
        en = "Separates and spreads Ring HUD components away from their centre.",
        ["zh-cn"] = "环形HUD 元素偏移，垂直移动 或 扩大组件间距",
        ["zh-tw"] = "環形HUD 元素偏移，垂直移動 或 擴大組件間距",
    },

    ads_settings                           = { -- ADS = 开镜瞄
        en = "ADS",
        ["zh-cn"] = "瞄准 界面分布",
        ["zh-tw"] = "瞄準 界面佈局",
    },
    ads_visibility_dropdown                = {
        en = "Visibility while ADS",
        ["zh-cn"] = "瞄准HUD可见性",
        ["zh-tw"] = "瞄準HUD可見性",
    },
    ads_visibility_dropdown_tooltip        = {
        en =
        "Controls whether the entire Ring HUD is shown or hidden depending on ADS state. “Treat ADS as Force Show” behaves like holding the hotkey while aiming.",
        ["zh-cn"] = "瞄准状态下的模组界面布局",
        ["zh-tw"] = "瞄準狀態下的模組界面佈局",
    },
    ads_vis_normal                         = {
        en = "Show normally (ADS & hipfire)",
        ["zh-cn"] = "始终显示",
        ["zh-tw"] = "始終顯示",
    },
    ads_vis_hide_in_ads                    = {
        en = "Hide while ADS",
        ["zh-cn"] = "瞄准隐藏",
        ["zh-tw"] = "瞄準隱藏",
    },
    ads_vis_hide_outside_ads               = {
        en = "Hide when not ADS",
        ["zh-cn"] = "腰射显示",
        ["zh-tw"] = "腰射顯示",
    },
    ads_vis_hotkey                         = {
        en = "Treat ADS as Force Show",
        ["zh-cn"] = "瞄准HUD全显",
        ["zh-tw"] = "瞄準HUD全顯",
    },

    ads_scale_override                     = {
        en = "Scale while ADS",
        ["zh-cn"] = "缩放倍率",
        ["zh-tw"] = "縮放倍率",
    },
    ads_scale_override_tooltip             = {
        en = "Multiplies the size of the Ring HUD while in ADS. Default: 1.0.",
        ["zh-cn"] = "瞄准状态下界面的缩放倍数，默认1.0",
        ["zh-tw"] = "瞄準狀態下界面的縮放倍數，默認1.0",
    },
    ads_offset_bias_override               = {
        en = "Separation while ADS",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移",
    },
    ads_offset_bias_override_tooltip       = {
        en = "Separates and spreads Ring HUD components away from their centre while in ADS.",
        ["zh-cn"] = "环形HUD 在瞄准状态下的偏移，垂直移动 或 扩大组件间距",
        ["zh-tw"] = "環形HUD 在瞄準狀態下的偏移，垂直移動 或 擴大組件間距",
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
        "Controls the toughness/HP bar.\n'Automatic': Shows based on toughness, health changes, or near healing sources.\n'Segmented by HP': Uses bar segments to show health status, while the fill shows toughness.\n'With Text': Adds a numeric health display to the corresponding 'Automatic' or 'Always' mode.\n'Disabled': Hides the bar.",
        ["zh-cn"] =
        "韧性 / HP 显示方式:\n自动：韧性、血量、接近治疗源时显示\n生命格：生命格分为腐化、扣血、实际血量三个边框作为分区，填充代表韧性\n生命格（文字）：自动或始终可见模式下，数字血量显示\n禁用：隐藏韧性、血量",
        ["zh-tw"] =
        "韌性 / HP 顯示方式：\n自動：韌性、血量、接近治療源時顯示\n生命格：生命格分為腐化、扣血、實際血量三個邊框作為分區，填充代表韌性\n生命格（文字）：自動或始終可見模式下，數字血量顯示\n禁用：隱藏韌性、血量",
    },
    toughness_bar_auto_hp_text             = {
        en = "Automatic (Segmented, with Text)",
        ["zh-cn"] = "自动 (生命格 韧性 血量数字)",
        ["zh-tw"] = "自動 (生命格 韌性 血量數字)",
    },
    toughness_bar_auto_hp                  = {
        en = "Automatic (Segmented by HP)",
        ["zh-cn"] = "自动 (生命格 韧性)",
        ["zh-tw"] = "自動 (生命格 韌性)",
    },
    toughness_bar_always_hp_text           = {
        en = "Always Visible (Segmented, with Text)",
        ["zh-cn"] = "始终可见 (生命格 韧性 血量数字)",
        ["zh-tw"] = "始終可見 (生命格 韌性 血量數字)",
    },
    toughness_bar_always_hp                = {
        en = "Always Visible (Segmented by HP)",
        ["zh-cn"] = "始终可见 (生命格 韧性)",
        ["zh-tw"] = "始終可見 (生命格 韌性)",
    },
    toughness_bar_always                   = {
        en = "Always Visible (Toughness Only)",
        ["zh-cn"] = "始终可见 (仅韧性)",
        ["zh-tw"] = "始終可見 (僅韌性)",
    },
    toughness_bar_disabled                 = {
        en = "Disabled",
        ["zh-cn"] = "禁用",
        ["zh-tw"] = "禁用",
    },

    stamina_viz_threshold                  = {
        en = "Stamina Visibility Threshold",
        ["zh-cn"] = "耐力环 可见度",
        ["zh-tw"] = "耐力環 可見度",
    },
    stamina_viz_tooltip                    = {
        en =
        "Stamina bar will become visible below this value and stay visible until refilled.\nWill hide default stamina bar.\nSet to 0 for always visible or a negative value to always hide.",
        ["zh-cn"] = "体力在设定值以下显示，之后直到恢复到满体力\n设为0始终显示，-1始终隐藏设置",
        ["zh-tw"] = "體力在設定值以下顯示，之後直到恢復到滿體力\n設為0始終顯示，-1始終隱藏設置",
    },
    dodge_viz_threshold                    = {
        en = "Dodge Visibility Threshold",
        ["zh-cn"] = "闪避可见度",
        ["zh-tw"] = "閃避可見度",
    },
    dodge_viz_tooltip                      = {
        en =
        "Dodge bar will become visible at or below this many dodges left.\nSet to 0 for always visible or -1 for always hidden.\nFor a more customizable dodge bar try Show Remaining Dodges by mrouzon. For a count of dodges use Numeric UI by dnrvs.",
        ["zh-cn"] =
        "闪避剩余次数在设定值以下时显示\n 设置0始终显示，设置-1始终隐藏\n如果需要更加灵活的闪避条自定义，可以使用《Show Remaining Dodges》，果需要显示闪避次数dnrvs的《Numeric UI》",
        ["zh-tw"] =
        "閃避剩餘次數在設定值以下時顯示\n 設置0始終顯示，設置-1始終隱藏\n如果需要更加靈活的閃避條自定義，可以使用《Show Remaining Dodges》，果需要顯示閃避次數dnrvs的《Numeric UI》",
    },

    peril_settings                         = {
        en = "Peril",
        ["zh-cn"] = "过载值",
        ["zh-tw"] = "過載值",
    },
    peril_tooltip                          = {
        en =
        "For a more comprehensive peril HUD element with more options, try PerilGauge by ItsAlxl.\nEnabling the label will disable the game's default peril counter.",
        ["zh-cn"] = "如需更全面的风险 HUD 元素并提供更多选项，请尝试 ItsAlxl 开发的 PerilGauge。\n闪电效果：在灵能者过载值超过94%%以上，准心旁会出现闪电触须的效果",
        ["zh-tw"] = "如需更全面的風險 HUD 元素並提供更多選項，請嘗試 ItsAlxl 開發的 PerilGauge。\n閃電效果：在靈能者過載值超過94%%以上，準心旁會出現閃電觸鬚的效果",
    },
    peril_bar_dropdown                     = {
        en = "Peril / Heat",
        ["zh-cn"] = "过载值 / 热量",
        ["zh-tw"] = "過載值 / 熱量",
    },
    peril_lightning_enabled                = {
        en = "Enable Bar and Lightning Animation",
        ["zh-cn"] = "启用能量条 和 闪电效果",
        ["zh-tw"] = "啟用能量條 和 閃電效果",
    },
    peril_bar_enabled                      = {
        en = "Enable Bar",
        ["zh-cn"] = "启用能量条",
        ["zh-tw"] = "啟用能量條",
    },
    peril_bar_disabled                     = {
        en = "Disable Bar",
        ["zh-cn"] = "禁用能量条",
        ["zh-tw"] = "禁用能量條",
    },
    peril_label_enabled                    = {
        en = "Enable Label",
        ["zh-cn"] = "热量环形UI",
        ["zh-tw"] = "熱量環形UI",
    },
    peril_label_enabled_tooltip            = {
        en = "Display text label with peril percentage. Disables the game's default peril counter if enabled.",
        ["zh-cn"] = "显示危险百分比的文本标签，禁止游戏默认的危险仪表",
        ["zh-tw"] = "顯示危險百分比的文本標籤，禁止遊戲默認的危險儀表",
    },
    peril_crosshair_enabled                = {
        en = "MeowBeep Crosshair",
        ["zh-cn"] = "危机值 准心颜色",
        ["zh-tw"] = "危機值 準心顏色",
    },
    peril_crosshair_tooltip                = {
        en = "Applies peril colour to crosshair. Does not override Dynamic Crosshair mod.",
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
        en =
        "Controls how loaded ammunition (in the current weapon's magazine) is displayed.\n'Bar' options show a visual arc.\n'Text' options show a numeric count.",
        ["zh-cn"] = "当前武器弹夹中已装载弹药的显示方式\n'能量条'选项显示一个视觉弧线。\n'数字'选项显示一个数字计数。",
        ["zh-tw"] = "當前武器彈匣中已裝載彈藥的顯示方式\n'能量條'選項顯示一個視覺弧線。\n'數字'選項顯示一個數字計數。",
    },
    ammo_clip_bar_text                     = {
        en = "Bar and Text",
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
        "Controls how reserve ammunition is displayed.\n'Auto' modes show when low, near ammo pickups, or after ammo changes.\n'Always' modes keep it visible.\n'Percentage' vs 'Actual' controls the numeric format.",
        ["zh-cn"] = "备弹显示方式\n自动模式在弹药不足、接近弹药包 以及 更换后显示\n始终可见模式一直可见\n分为百分比与实际计数格式",
        ["zh-tw"] = "備彈顯示方式\n自動模式在彈藥不足、接近彈藥包 以及 更換後顯示\n始終可見模式一直可見\n分為百分比與實際計數格式",
    },
    ammo_reserve_percent_auto              = {
        en = "Percentage (Auto)",
        ["zh-cn"] = "百分比（自动）",
        ["zh-tw"] = "百分比（自動）",
    },
    ammo_reserve_actual_auto               = {
        en = "Actual Count (Auto)",
        ["zh-cn"] = "实际计数（自动）",
        ["zh-tw"] = "實際計數（自動）",
    },
    ammo_reserve_percent_always            = {
        en = "Percentage (Always)",
        ["zh-cn"] = "百分比（始终）",
        ["zh-tw"] = "百分比（始終）",
    },
    ammo_reserve_actual_always             = {
        en = "Actual Count (Always)",
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
        "Controls the visibility and style of the grenade indicator arcs.\n'Hide When Max': Bar disappears when all grenades are full (unless one is regenerating).\n'Hide When Empty': Bar disappears when you have no grenades.\n'Compact': Only shows filled segments and the single next regenerating segment, if any.\n'Normal' (non-compact): Shows all potential grenade segments up to your maximum.\nFor a larger display with more options consider Blitz Bar by Tomohawk5.",
        ["zh-cn"] =
        "手雷显示方式\n全满隐藏：手雷已满 进度条消失 除非再生雷\n空时隐藏：手雷为空 进度条消失\n紧凑模式：仅仅显示 装备和再生手雷\n如果需要更多选项，请考虑 Tomohawk5 的 Blitz Bar。",
        ["zh-tw"] = "手雷顯示方式\n全滿隱藏：手雷已滿進度條消失，除非再生雷\n空時隱藏：手雷為空進度條消失\n緊湊模式：僅顯示裝備和再生手雷\n如果需要更多選項，請考慮 Tomohawk5 的 Blitz Bar。"
    },
    grenade_hide_full_compact              = {
        en = "Hide When Max, Compact",
        ["zh-cn"] = "全满隐藏（紧凑）",
        ["zh-tw"] = "全滿隱藏（緊湊）",
    },
    grenade_hide_full                      = {
        en = "Hide When Max",
        ["zh-cn"] = "全满隐藏",
        ["zh-tw"] = "全滿隱藏",

    },
    grenade_hide_empty_compact             = {
        en = "Hide When Empty, Compact",
        ["zh-cn"] = "空时隐藏（紧凑）",
        ["zh-tw"] = "空時隱藏（緊湊）",
    },
    grenade_hide_empty                     = {
        en = "Hide When Empty",
        ["zh-cn"] = "空时隐藏",
        ["zh-tw"] = "空時隱藏",
    },
    grenade_disabled                       = {
        en = "Disable Bar",
        ["zh-cn"] = "禁用能量条",
        ["zh-tw"] = "禁用能量條",
    },

    charge_settings                        = {
        en = "Charge",
        ["zh-cn"] = "充能或蓄力",
        ["zh-tw"] = "充能或蓄力",
    },
    charge_perilous_enabled                = {
        en = "Enable Bar (Psyker, Plasma)",
        ["zh-cn"] = "替换 充能力度（灵能者，等离子）",
        ["zh-tw"] = "替換 充能力度（靈能者，等離子）",
    },
    charge_kills_enabled                   = {
        en = "Enable Bar (Force Greatsword)",
        ["zh-cn"] = "替换 灵能巨剑斩击",
        ["zh-tw"] = "替換 靈能巨劍斬擊",
    },
    charge_other_enabled                   = {
        en = "Enable Bar (Helbore, Arbites Shield)",
        ["zh-cn"] = "替换 蓄力条（卢修斯）",
        ["zh-tw"] = "替换 蓄力條（盧修斯）",
    },

    timer_settings                         = {
        en = "Ability",
        ["zh-cn"] = "技能",
        ["zh-tw"] = "技能",
    },
    timer_cd_enabled                       = {
        en = "Enable Cooldown Timer",
        ["zh-cn"] = "技能冷却 计时器",
        ["zh-tw"] = "技能冷卻 計時器",
    },
    timer_cd_tooltip                       = {
        en = "Cooldown is hidden if you have ability charges left - hidden means ready to use.",
        ["zh-cn"] = "双技能时，技能有剩余次数时，隐藏冷却时间",
        ["zh-tw"] = "雙技能時，技能有剩餘次數時，隱藏冷卻時間",
    },
    timer_buff_enabled                     = {
        en = "Enable Buff Timer",
        ["zh-cn"] = "技能生效 倒计时",
        ["zh-tw"] = "技能生效 倒計時",
    },
    timer_buff_tooltip                     = {
        en = "Show remaining time for Point Blank Barrage, Executioner's Stance, Warp Unbound and stealth.",
        ["zh-cn"] = "齐射、占卜、战吼、隐身等类似技能生效剩余时间，会有倒计时",
        ["zh-tw"] = "顯示近距離彈幕、處決者姿態、亞空間解放和潛行的剩餘時間",
    },
    timer_sound_enabled                    = {
        en = "Enable Refresh Sound",
        ["zh-cn"] = "技能刷新 音效",
        ["zh-tw"] = "技能刷新 音效",
    },
    timer_sound_tooltip                    = {
        en =
        "Replaces the ability refresh sound with a louder one.\nFor a mod that gives more control over what sound plays, try Audible Ability Recharge by demba.",
        ["zh-cn"] = "更大音量替换原版技能刷新音效，更详细的设定使用demba制作的Audible Ability Recharge",
        ["zh-tw"] = "使用更大的音量替換技能刷新技能，更詳細的設定使用demba製作的Audible Ability Recharge",
    },

    pocketable_settings                    = {
        en = "Pocketables",
        ["zh-cn"] = "兴奋剂 / 补给品",
        ["zh-tw"] = "興奮劑 / 補給品",
    },
    pocketable_settings_tooltip            = {
        en = "Controls the visibility and appearance of pocketable items like Stimms and Crates.",
        ["zh-cn"] = "控制兴奋剂、补给的可见性、颜色",
        ["zh-tw"] = "控制興奮劑、補給的可見性、顏色",
    },
    pocketable_visibility_dropdown         = {
        en = "Pocketable Visibility",
        ["zh-cn"] = "兴奋剂 / 补给品 可见性",
        ["zh-tw"] = "興奮劑 / 補給品 可見性",
    },
    pocketable_visibility_dropdown_tooltip = {
        en =
        "Controls when Stimm and Crate icons are shown.\n'Contextual': Icons appear based on game events (low health, nearby pickups, hordes, bosses, mid or end events).\n'Always': Icons are always visible if you are carrying the item.\n'Disabled': Icons are never shown.",
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
        ["zh-tw"] = "醫療箱顏色",
    },
    medical_crate_color_tooltip            = {
        en = "Select the colour for the Medical Crate icon.",
        ["zh-cn"] = "选择医疗箱图标的颜色",
        ["zh-tw"] = "選擇醫療箱圖標的顏色",
    },
    ammo_cache_color                       = {
        en = "Ammo Cache Colour",
        ["zh-cn"] = "弹药箱 颜色",
        ["zh-tw"] = "彈藥箱顏色",
    },
    ammo_cache_color_tooltip               = {
        en = "Select the colour for the Ammo Cache icon.",
        ["zh-cn"] = "选择弹药箱图标的颜色",
        ["zh-tw"] = "選擇彈藥箱圖標的顏色",
    },

    --======================
    -- Team HUD (modes)
    --======================
    team_hud_mode                          = { en = "Team HUD mode" },
    team_hud_mode_tooltip                  = { en = "Choose how teammate widgets are displayed." },
    team_hud_disabled                      = { en = "Disabled" },
    team_hud_docked                        = { en = "Docked" },
    team_hud_floating                      = { en = "Floating" },
    team_hud_floating_docked               = { en = "Floating and Docked" },
    team_hud_floating_vanilla              = { en = "Floating and Vanilla" },

    -- Group titles / tooltips used in RingHud_data.lua
    team_hud_settings                      = { en = "Team HUD" },
    team_hud_settings_tooltip              = { en = "Configure teammate tiles: layout, scale, and modes." },
    team_hud_detail                        = { en = "Team HUD Detail" },
    team_hud_detail_tooltip                = { en = "Choose which details appear on teammate tiles." },

    team_tiles_scale                       = { en = "Team Tiles Scale" },
    team_tiles_scale_tooltip               = { en = "Multiplies the size of teammate tiles (floating and docked)." },

    -- Team HP bar (titles + options)
    team_hp_bar                            = { en = "Team Health Bars" },
    team_hp_bar_tooltip                    = {
        en = "Shows teammates' health on their tiles. 'Text' adds numeric HP."
    },
    team_hp_disabled                       = { en = "Disabled" },
    team_hp_bar_always                     = { en = "Bar Always" },
    team_hp_bar_text_always                = { en = "Bar and Text Always" },
    team_hp_bar_context                    = { en = "Bar (Contextual)" },
    team_hp_bar_text_context               = { en = "Bar and Text (Contextual)" },

    -- Team detail toggles (titles)
    team_munitions                         = { en = "Team Munitions" },
    team_munitions_tooltip                 = { en = "Show teammates' reserve ammo and blitz details." },
    team_munitions_disabled                = { en = "Disabled" },
    team_munitions_always                  = { en = "Always" },
    team_munitions_context                 = { en = "Contextual" },

    team_pockets                           = { en = "Team Pocketables" },
    team_pockets_tooltip                   = { en = "Show teammates' Stimms/Crates." },
    team_pockets_disabled                  = { en = "Disabled" },
    team_pockets_always                    = { en = "Always" },
    team_pockets_context                   = { en = "Contextual" },

    -- Team counters (already present; kept)
    team_counters                          = { en = "Team Counters" },
    team_counters_tooltip                  = {
        en =
        "Controls small counters on teammate tiles:\nAbility Cooldown (seconds)\nToughness (text).",
    },
    team_counters_disabled                 = { en = "Disabled" },
    team_counters_cd                       = { en = "Ability Cooldown Only" },
    team_counters_toughness                = { en = "Toughness Only" },
    team_counters_cd_toughness             = { en = "Cooldown and Toughness" },


    default_hud_visibility_settings         = {
        en = "Vanilla HUD Visibility",
        ["zh-cn"] = "隐藏原版 HUD",
        ["zh-tw"] = "隱藏原版 HUD",
    },
    default_hud_visibility_settings_tooltip = {
        en =
        "Control the visibility of default game HUD elements. Hiding them can reduce clutter if Ring HUD provides similar information.",
        ["zh-cn"] = "控制游戏原版HUD 可见性，如果环形HUD提供相同信息，隐藏它们可以减少界面元素混乱",
        ["zh-tw"] = "控制遊戲原版HUD可見性，如果環形HUD提供相同信息，隱藏它們可以減少界面元素混亂",
    },
    hide_default_ability                    = {
        en = "Hide Vanilla Ability HUD",
        ["zh-cn"] = "隐藏 技能图标",
        ["zh-tw"] = "隱藏 技能圖標",
    },
    hide_default_ability_tooltip            = {
        en = "Hides the game's default combat ability icon and cooldown display.",
        ["zh-cn"] = "隐藏 技能图标和冷却时间显示",
        ["zh-tw"] = "隱藏技能圖標和冷卻時間顯示",
    },
    hide_default_weapons                    = {
        en = "Hide Vanilla Weapon HUD",
        ["zh-cn"] = "隐藏 武器界面",
        ["zh-tw"] = "隱藏 武器界面",
    },
    hide_default_weapons_tooltip            = {
        en = "Hides the game's default weapon display (ammo, grenades, etc.).",
        ["zh-cn"] = "隐藏 武器显示（弹药、手雷、兴奋剂等）",
        ["zh-tw"] = "隱藏武器顯示（彈藥、手雷、興奮劑等）",
    },
    hide_default_player                     = {
        en = "Hide Vanilla Player Frame",
        ["zh-cn"] = "隐藏 玩家框（自己）",
        ["zh-tw"] = "隱藏玩家框（自己）",
    },
    hide_default_player_tooltip             = {
        en = "Hides your own player frame .",
        ["zh-cn"] = "团队HUD中 仅隐藏自己的玩家UI，包括血量头像框等",
        ["zh-tw"] = "在團隊HUD中僅隱藏自己的玩家UI，包括血量頭像框等"
    },
    --======================
    -- Chat (alignment)
    --======================
    chat_settings                           = { en = "Chat" },
    chat_alignment_in_mission               = { en = "Chat Box Position" },
    chat_align_top_left                     = { en = "Top • Left" },
    chat_align_top_center                   = { en = "Top • Center" },
    chat_align_top_right                    = { en = "Top • Right" },
    chat_align_center_left                  = { en = "Center • Left" },
    chat_align_center_right                 = { en = "Center • Right" },
    chat_align_bottom_left                  = { en = "Bottom • Left" },
    chat_align_bottom_center                = { en = "Bottom • Center" },
    chat_align_bottom_right                 = { en = "Bottom • Right" },

    --======================
    -- NEW: UI Integration group
    --======================
    ui_integration_settings                 = {
        en = "UI Integration",
        ["zh-cn"] = "界面整合",
        ["zh-tw"] = "介面整合",
    },
    ui_integration_settings_tooltip         = {
        en = "Settings that integrate with the vanilla UI: chat placement and objective feed behavior.",
    },
    minimal_objective_feed_enabled          = {
        en = "Minimalist Objective Feed",
    },
    minimal_objective_feed_enabled_tooltip  = {
        en =
        "Hide the mission objective feed unless there is actionable progress (progress bars, luggables, collect/side). When shown (and not during mid/end events), only keep interesting rows.",
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
    HEALTH_GREEN = "绿色",
    POWER_RED = "红色",
    SPEED_BLUE = "蓝色",
    COOLDOWN_YELLOW = "黄色",
    AMMO_ORANGE = "橙色",
    TOME_BLUE = "浅蓝",
    GRIMOIRE_PURPLE = "紫色",
    GENERIC_CYAN = "青色",
    GENERIC_WHITE = "白色",
}

local zh_tw_color_names = {
    HEALTH_GREEN = "綠色",
    POWER_RED = "紅色",
    SPEED_BLUE = "藍色",
    COOLDOWN_YELLOW = "黃色",
    AMMO_ORANGE = "橙色",
    TOME_BLUE = "淺藍",
    GRIMOIRE_PURPLE = "紫色",
    GENERIC_CYAN = "青色",
    GENERIC_WHITE = "白色",
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
