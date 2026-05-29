-- File: RingHud/scripts/mods/RingHud/RingHud_localization.lua
local mod = get_mod("RingHud"); if not mod then return end
local InputUtils = require("scripts/managers/input/input_utils")
local TextUtils = require("scripts/utilities/ui/text")
local Colors = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local Localize = Localize
local localizations = {
    mod_name                         = {
        en = "Ring HUD",
        ["zh-cn"] = "--【Ring HUD】--",
        ["zh-tw"] = "環形HUD",
    },
    mod_description                  = {
        en =
        "Enhance your combat focus with Ring HUD. This compact, circular display dynamically shows vital stats including toughness/health, stamina, peril, weapon charge, ammo, grenades, dodges, and ability timers.",
        ["zh-cn"] = "一个紧凑的环形 HUD，显示生命、韧性、耐力、过载值、充能，闪避、远程蓄力、弹药、手雷、技能冷却信息\n B站 独一无二的小真寻",
        ["zh-tw"] = "一個緊湊的環形 HUD，顯示生命、韌性、耐力、過載值、充能，閃避、遠程蓄力、彈藥、手雷、技能冷卻信息\n B站 独一无二的小真寻", -- AI Note: Please do not translate this line
    },

    show_all_hud_hotkey              = {
        en = "Force Show",
        ["zh-cn"] = "强制显示HUD",
        ["zh-tw"] = "強制顯示HUD",
    },
    show_all_hud_hotkey_tooltip      = {
        en = "Hold to temporarily show all Ring HUD elements, overriding their individual visibility settings.",
        ["zh-cn"] = "按住此按键可以显示所有环形HUD元素，覆盖它们各自可见性设置",
        ["zh-tw"] = "按住此按鍵可以顯示所有環形HUD元素，覆蓋它們各自可見性設置",
    },

    trigger_detection_range          = {
        -- loc_weapon_stats_display_effective_range
        en = "Context Range",
        ["zh-cn"] = "物品感知 范围",
        ["zh-tw"] = "物品感知 範圍",
    },
    trigger_detection_tooltip        = {
        en = "Sets the distance for dynamic triggers.\n\n• Used for: Ammo, Pocketables, Medicae.",
        ["zh-cn"] = "靠近补给品或医疗品时，指向自动显示生命值和弹药信息（单位：米）", -- AI Note: Please do not translate this line
        ["zh-tw"] = "靠近補給品或醫療品時，指向自動顯示生命值和彈藥信息（單位：米）", -- AI Note: Please do not translate this line
    },

    minimal_objective_feed_enabled   = {
        en = "Streamline Popups",
    },

    layout_supergroup                = {
        en = "LAYOUT", -- TextUtils.localize_to_upper(" -- [ ] Localize
        ["zh-cn"] = "布局",
        ["zh-tw"] = "佈局",
    },
    position_settings                = {
        en = " Position",
    },
    layout_settings                  = {
        en = " General", -- [ ] Localize
        ["zh-cn"] = " 通用",
        ["zh-tw"] = " 通用",
    },

    crosshair_shake_dropdown         = {
        en = "Move with Crosshair",
        ["zh-cn"] = "晃动同步",
        ["zh-tw"] = "晃動同步",
    },
    crosshair_shake_dropdown_tooltip = {
        en = "Controls if the Ring HUD moves with the crosshair during weapon sway and recoil.",
        ["zh-cn"] = "是否在武器晃动和后坐力作用下，与原版准心同步移动",
        ["zh-tw"] = "是否在武器晃動和後坐力作用下，與原版準心同步移動",
    },
    crosshair_shake_always           = { en = Localize("loc_setting_checkbox_on") },
    crosshair_shake_ads              = { en = Localize("loc_ranged_attack_secondary_ads") },
    crosshair_shake_disabled         = { en = Localize("loc_setting_checkbox_off") },

    ring_scale                       = { en = Localize("loc_interface_setting_hud_scale") },
    ring_offset_bias                 = {
        en = "Radius (" .. Localize("loc_setting_mix_preset_flat") .. ")",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移"
    },
    ring_offset_bias_tooltip         = {
        en = "Separates and spreads Ring HUD components away from their centre.",
        ["zh-cn"] = "环形HUD 元素偏移，垂直移动 或 扩大组件间距",
        ["zh-tw"] = "環形HUD 元素偏移，垂直移動 或 擴大組件間距",
    },
    scanner_offset_bias_override     = {
        en = "Radius (" .. Localize("loc_auspex_input_description_scan_wield_scanner") .. ")",
        ["zh-cn"] = "鸟卜仪 偏移覆盖",
        ["zh-tw"] = "鳥卜儀 偏移",
    },
    player_hud_offset_x              = { en = "X" },
    player_hud_offset_y              = { en = "Y" },
    text_settings                    = {
        en = " Text",
    },
    player_hud_font                  = {
        en = "Player HUD Font",
    },
    player_hud_font_tooltip          = {
        en =
        "Select the font used for text elements on the player ring (Health, Ammo, etc).\n\nDoes not affect Ability Buff timers.",
    },

    player_hud_text_size             = { en = Localize("loc_interface_setting_subtitle_font_size") },

    player_hud_text_offset           = {
        en = "Radius",
    },
    player_hud_text_offset_tooltip   = {
        en = "Adjusts the distance of text elements from the center of the ring. Additive with 'Separation'.",
    },

    ads_settings                     = { en = " " .. Localize("loc_ranged_attack_secondary_ads") },
    ads_visibility_dropdown          = {
        en = "ADS Visibility", -- [ ] Localize
        ["zh-cn"] = "瞄准HUD 可见性",
        ["zh-tw"] = "瞄準HUD 可見性",
    },
    ads_vis_normal                   = {
        en = Localize("loc_setting_mix_preset_flat"),
    },
    ads_vis_hide_in_ads              = {
        en = "Hide in ADS", -- [ ] Localize
        ["zh-cn"] = "瞄准隐藏",
        ["zh-tw"] = "瞄準隱藏",
    },
    ads_vis_hide_outside_ads         = {
        en = "Show in ADS Only", -- [ ] Localize
        ["zh-cn"] = "瞄准启用",
        ["zh-tw"] = "瞄準啟用",
    },
    ads_vis_hotkey                   = {
        en = "Treat ADS as Force Show",
        ["zh-cn"] = "瞄准HUD全显",
        ["zh-tw"] = "瞄準HUD全顯",
    },

    ads_scale_override               = { en = Localize("loc_interface_setting_hud_scale") },
    ads_offset_bias_override         = {
        en = "Radius (" .. Localize("loc_ranged_attack_secondary_ads") .. ")",
        ["zh-cn"] = "HUD偏移",
        ["zh-tw"] = "HUD偏移",
    },

    combat_supergroup                = {
        en = TextUtils.localize_to_upper("loc_keybind_category_combat"),
    },
    survival_settings                = {
        en = " " .. Localize("loc_achievement_category_defensive_label"),
    },
    toughness_bar_dropdown           = { en = Localize("loc_toughness_damage_tutorial") .. " / " .. Localize("loc_corruption_tutorial") },
    toughness_bar_dropdown_tooltip   = {
        en =
        "Controls the toughness/HP bar.\n\n• Dynamic: Dynamic visibility.\n• Segmented by HP: Border segments show HP, fill shows toughness.\n• With Text: Adds numeric health display.\n• Disabled: Hides the bar.",
        ["zh-cn"] =
        "韧性 / HP 显示方式:\n自动：韧性、血量、接近治疗源时显示\n生命格：生命格分为腐化、扣血、实际血量三个边框作为分区，填充代表韧性\n生命格（文字）：自动或始终可见模式下，数字血量显示\n禁用：隐藏韧性、血量",
        ["zh-tw"] =
        "韌性 / HP 顯示方式：\n自動：韌性、血量、接近治療源時顯示\n生命格：生命格分為腐化、扣血、實際血量三個邊框作為分區，填充代表韌性\n生命格（文字）：自動或始終可見模式下，數字血量顯示\n禁用：隱藏韌性、血量",
    },
    toughness_bar_auto_hp_text       = {
        en = "Dynamic (Segments and Text)",
        ["zh-cn"] = "自动 (生命格 韧性 血量数字)",
        ["zh-tw"] = "自動 (生命格 韌性 血量數字)",
    },
    toughness_bar_auto_hp            = {
        en = "Dynamic (Segments)",
        ["zh-cn"] = "自动 (生命格 韧性)",
        ["zh-tw"] = "自動 (生命格 韌性)",
    },
    toughness_bar_always_hp_text     = {
        en = "Always Segments, Dynamic Text",
        ["zh-cn"] = "始终可见 (生命格 韧性 血量数字)",
        ["zh-tw"] = "始終可見 (生命格 韌性 血量數字)",
    },
    toughness_bar_always_hp          = {
        en = "Always (Segments)",
        ["zh-cn"] = "始终可见 (生命格 韧性)",
        ["zh-tw"] = "始終可見 (生命格 韌性)",
    },
    toughness_bar_always_text_always = {
        en = "Always (Toughness and HP Text)",
    },
    toughness_bar_always             = {
        en = "Always (Toughness Only)",
        ["zh-cn"] = "始终可见 (仅韧性)",
        ["zh-tw"] = "始終可見 (僅韌性)",
    },
    toughness_bar_disabled           = { en = Localize("loc_setting_checkbox_off") },

    stamina_viz_threshold            = {
        en = "Stamina Threshold",
        ["zh-cn"] = "耐力环 可见度",
        ["zh-tw"] = "耐力環 可見度",
    },
    stamina_viz_tooltip              = {
        en =
        "Stamina bar appears when below this fraction (0.0 - 1.0) and then hides again after it has refilled.  If the visibility threshold is 0.1 or less, will hide at 0.5s.\n\n• 0: Always visible.\n• -0.01: Always hidden.",
        ["zh-cn"] = "体力在设定值以下显示，之后直到恢复到满体力\n设为0始终显示，-0.01始终隐藏设置",
        ["zh-tw"] = "體力在設定值以下顯示，之後直到恢復到滿體力\n設為0始終顯示，-0.01始終隱藏設置",
    },
    dodge_viz_threshold              = {
        en = "Dodge Threshold",
        ["zh-cn"] = "闪避可见度",
        ["zh-tw"] = "閃避可見度",
    },
    dodge_viz_tooltip                = {
        en =
        "Dodge bar appears when remaining dodges are at or below this count and then hides again after it has refilled.\n\n• 0: Always visible.\n• -1: Always hidden.\n\nOther mods: 'Show Remaining Dodges' or 'Numeric UI' for more options.",
        ["zh-cn"] =
        "闪避剩余次数在设定值以下时显示\n 设置0始终显示，设置-1始终隐藏\n如果需要更加灵活的闪避条自定义，可以使用《Show Remaining Dodges》，果需要显示闪避次数dnrvs的《Numeric UI》",
        ["zh-tw"] =
        "閃避剩餘次數在設定值以下時顯示\n 設置0始終顯示，設置-1始終隱藏\n如果需要更加靈活的閃避條自定義，可以使用《Show Remaining Dodges》，果需要顯示閃避次數dnrvs的《Numeric UI》",
    },

    casting_supergroup               = {
        en = "CASTING", -- TextUtils.localize_to_upper -- [ ] Localize
        ["zh-cn"] = "施法",
        ["zh-tw"] = "施法",
    },
    -- peril_settings                   = { en = " " .. Localize("loc_stats_display_warp_resist_stat") .. " / " .. Localize("loc_stats_display_heat_management_powersword_2h") },
    peril_settings                   = { en = " " .. Localize("loc_weapon_stats_display_peril_decay") .. " / " .. Localize("loc_weapon_stats_display_heat_decay") },
    peril_tooltip                    = {
        en =
        "Controls the Peril/Heat bar.\n\n• Lightning: Shows visual lightning animation at high peril.\n\nOther mods: 'PerilGauge' by ItsAlxl for more comprehensive options.",
        ["zh-cn"] = "如需更全面的风险 HUD 元素并提供更多选项，请尝试 ItsAlxl 开发的 PerilGauge。\n闪电效果：在灵能者过载值超过94%%以上，准心旁会出现闪电触须的效果",
        ["zh-tw"] = "如需更全面的風險 HUD 元素並提供更多選項，請嘗試 ItsAlxl 開發的 PerilGauge。\n閃電效果：在靈能者過載值超過94%%以上，準心旁會出現閃電觸鬚的效果",
    },
    peril_bar_dropdown               = {
        en = "Bar Style",
        ["zh-cn"] = "过载值 / 热量",
        ["zh-tw"] = "過載值 / 熱量",
    },
    peril_lightning_enabled          = {
        en = "Bar and Lightning Anim",
        ["zh-cn"] = "启用能量条 和 灵能过热闪电触须",
        ["zh-tw"] = "啟用能量條 和 閃電效果",
    },
    peril_bar_enabled                = {
        en = "Bar Only",
        ["zh-cn"] = "启用能量条",
        ["zh-tw"] = "啟用能量條",
    },
    peril_bar_disabled               = { en = Localize("loc_setting_checkbox_off") },
    peril_label_enabled              = {
        en = "Label",
        ["zh-cn"] = "热量环形UI",
        ["zh-tw"] = "熱量環形UI",
    },
    peril_label_enabled_tooltip      = {
        en = "Displays text label with peril percentage. Disables the game's default peril counter if enabled.",
        ["zh-cn"] = "显示危险百分比的文本标签，禁止游戏默认的危险仪表",
        ["zh-tw"] = "顯示危險百分比的文本標籤，禁止遊戲默認的危險儀表",
    },
    peril_crosshair_enabled          = {
        en = "MeowBeep Crosshair",
        ["zh-cn"] = "危机值 准心颜色",
        ["zh-tw"] = "危機值 準心顏色",
    },
    peril_crosshair_tooltip          = {
        en = "Applies peril colour to crosshair.",
        ["zh-cn"] = "将危机值应用于十字准心，不覆盖动态十字准心MOD（DynamicCrosshair）",
        ["zh-tw"] = "將危機值應用於十字準心，不覆蓋動態十字準心MOD（DynamicCrosshair）",
    },

    munitions_settings               = { en = " " .. Localize("loc_glossary_term_ammunition") .. " / " .. Localize("loc_talents_category_tactical") },
    ammo_clip_dropdown               = { en = Localize("loc_weapon_stats_display_clip_size") },
    ammo_clip_dropdown_tooltip       = {
        en =
        "Controls display of ammo in the current magazine.\n\n• Normal: Hides when not in use.\n• Always: Always visible.\n• Forecast: Shows shots remaining based on ammo consumption.",
        ["zh-cn"] = "当前武器弹夹中已装载弹药的显示方式\n'能量条'选项显示一个视觉弧线。\n'数字'选项显示一个数字计数。",
        ["zh-tw"] = "當前武器彈匣中已裝載彈藥的顯示方式\n'能量條'選項顯示一個視覺弧線。\n'數字'選項顯示一個數字計數。",
    },
    ammo_clip_bar_text               = {
        en = "Bar and Text",
        ["zh-cn"] = "能量条 和 数字",
        ["zh-tw"] = "能量條 和 數字",
    },
    ammo_clip_bar                    = {
        en = "Bar",
        ["zh-cn"] = "仅限能量条",
        ["zh-tw"] = "僅限能量條",
    },
    ammo_clip_text                   = {
        en = "Text",
        ["zh-cn"] = "仅限文本（数字）",
        ["zh-tw"] = "僅限文本（數字）",
    },
    ammo_clip_bar_text_always        = {
        en = "Bar and Text (Always)",
    },
    ammo_clip_bar_always             = {
        en = "Bar (Always)",
    },
    ammo_clip_text_always            = {
        en = "Text (Always)",
    },
    ammo_clip_bar_forecast           = {
        en = "Bar and Forecast",
    },
    ammo_clip_forecast               = {
        en = "Forecast",
    },
    ammo_clip_bar_forecast_always    = {
        en = "Bar and Forecast (Always)",
    },
    ammo_clip_forecast_always        = {
        en = "Forecast (Always)",
    },
    ammo_clip_bar_forecast_ads       = {
        en = "Bar and Forecast (ADS)",
        ["zh-cn"] = "能量条 和 预测 (瞄准)",
        ["zh-tw"] = "能量條 和 預測 (瞄準)",
    },
    ammo_clip_bar_ads                = {
        en = "Bar (ADS)",
        ["zh-cn"] = "仅限能量条 (瞄准)",
        ["zh-tw"] = "僅限能量條 (瞄準)",
    },
    ammo_clip_disabled               = { en = Localize("loc_setting_checkbox_off") },

    ammo_reserve_dropdown            = { en = Localize("loc_weapon_stats_display_reserve_ammo") },
    ammo_reserve_dropdown_tooltip    = {
        en =
        "Controls display of total reserve ammo.\n\n• Dynamic: Shows on low ammo, reload, or near pickups.\n• Always: Permanently visible.\n• Forecast: Shows shots remaining based on ammo consumption.",
        ["zh-cn"] = "备弹显示方式\n自动模式在弹药不足、接近弹药包 以及 更换后显示\n始终可见模式一直可见\n分为百分比与实际计数格式",
        ["zh-tw"] = "備彈顯示方式\n自動模式在彈藥不足、接近彈藥包 以及 更換後顯示\n始終可見模式一直可見\n分為百分比與實際計數格式",
    },
    ammo_reserve_percent_auto        = {
        en = "Percent (Dynamic)",
        ["zh-cn"] = "百分比（自动）",
        ["zh-tw"] = "百分比（自動）",
    },
    ammo_reserve_actual_auto         = {
        en = "Count (Dynamic)",
        ["zh-cn"] = "实际计数（自动）",
        ["zh-tw"] = "實際計數（自動）",
    },
    ammo_reserve_percent_always      = {
        en = "Percent",
        ["zh-cn"] = "百分比（始终）",
        ["zh-tw"] = "百分比（始終）",
    },
    ammo_reserve_actual_always       = {
        en = "Count",
        ["zh-cn"] = "实际计数（始终）",
        ["zh-tw"] = "實際計數（始終）",
    },
    ammo_reserve_forecast_auto       = {
        en = "Forecast (Dynamic)",
    },
    ammo_total_percent_auto          = {
        en = "Total Percent (Dynamic)",
        ["zh-cn"] = "总弹药百分比（自动）",
        ["zh-tw"] = "總彈藥百分比（自動）",
    },
    ammo_total_percent_always        = {
        en = "Total Percent (Always)",
        ["zh-cn"] = "总弹药百分比（始终）",
        ["zh-tw"] = "總彈藥百分比（始終）",
    },
    ammo_reserve_forecast_always     = {
        en = "Forecast",
    },
    ammo_reserve_disabled            = { en = Localize("loc_setting_checkbox_off") },

    grenade_bar_dropdown             = { en = Localize("loc_pickup_consumable_small_grenade_01") },
    grenade_bar_dropdown_tooltip     = {
        en =
        "Controls visibility of grenade bar and shivs charges (if enabled).\n\n• Compact: Only shows filled/regenerating segments.\n\nOther mods: 'Blitz Bar' by Tomohawk5 for more options.",
        ["zh-cn"] =
        "手雷显示方式\n全满隐藏：手雷已满 进度条消失 除非再生雷\n空时隐藏：手雷为空 进度条消失\n紧凑模式：仅仅显示 装备和再生手雷\n如果需要更多选项，请考虑 Tomohawk5 的 Blitz Bar。",
        ["zh-tw"] = "手雷顯示方式\n全滿隱藏：手雷已滿進度條消失，除非再生雷\n空時隱藏：手雷為空進度條消失\n緊湊模式：僅顯示裝備和再生手雷\n如果需要更多選項，請考慮 Tomohawk5 的 Blitz Bar。"
    },
    grenade_hide_full_compact        = {
        en = "Hide if Max (Compact)",
        ["zh-cn"] = "全满隐藏（紧凑）",
        ["zh-tw"] = "全滿隱藏（緊湊）",
    },
    grenade_hide_full                = {
        en = "Hide if Max",
        ["zh-cn"] = "全满隐藏",
        ["zh-tw"] = "全滿隱藏",
    },
    grenade_hide_empty_compact       = {
        en = "Hide if Empty (Compact)",
        ["zh-cn"] = "空时隐藏（紧凑）",
        ["zh-tw"] = "空時隱藏（緊湊）",
    },
    grenade_hide_empty               = {
        en = "Hide if Empty",
        ["zh-cn"] = "空时隐藏",
        ["zh-tw"] = "空時隱藏",
    },
    grenade_disabled                 = { en = Localize("loc_setting_checkbox_off") },

    charge_settings                  = { en = " " .. Localize("loc_weapon_keyword_charged_attack") },
    charge_perilous_enabled          = { en = Localize("loc_weapon_family_plasmagun_p1_m1") .. "/" .. Localize("loc_class_psyker_name") },
    charge_kills_enabled             = { en = Localize("loc_weapon_family_forcesword_2h_p1_m1") .. "/" .. Localize("loc_weapon_family_dual_shivs_p1_m1") },
    charge_other_enabled             = {
        en = Localize("loc_weapon_family_lasgun_p2_m1") .. "/"
            .. Localize("loc_trait_bespoke_power_bonus_based_on_charge_time") .. "/"
            ..
            Localize("loc_weapon_family_ogryn_powermaul_p1_m1") ..
            "/" .. Localize("loc_settings_menu_group_other_settings")
    },

    timer_settings                   = { en = " " .. Localize("loc_glossary_term_class_ability") },
    timer_cd_dropdown                = {
        en = Localize("loc_game_mode_expedition_objective_header_time") ..
            " (" .. Localize("loc_glossary_term_class_ability") .. ")",
    },
    timer_cd_dropdown_tooltip        = {
        en =
        "Controls how ability cooldowns are shown.\n\n• Single Timer: Shows when no charges remain.\n• Charge Icons: Adds charge pips () per remaining charge.\n• Count and Timer: Shows charge number and timer.",
        ["zh-cn"] = "技能冷却显示方式\n\n• 计时：技能冷却时间\n• 图标：双技能时，显示图标()。\n• 计数+计时：双技能时，显示技能剩余次数，技能和冷却时间",
        ["zh-tw"] = "技能冷卻顯示方式\n\n• 計時：技能冷卻時間\n• 圖標：雙技能時，顯示圖標()。\n• 計數+計時：雙技能時，顯示技能剩餘次數，技能和冷卻時間",
    },
    timer_cd_disabled                = { en = Localize("loc_setting_checkbox_off") },
    timer_cd_single                  = {
        en = "Single Timer", -- [ ] Localize
        ["zh-cn"] = "计时",
        ["zh-tw"] = "計時",
    },
    timer_cd_pips_single             = {
        en = "Icons and Timer", -- [ ] Localize
        ["zh-cn"] = "计时 + 图标",
        ["zh-tw"] = "圖標 + 計時",
    },
    timer_cd_count_single            = {
        en = "Count and Timer",
        ["zh-cn"] = "技能数 + 计时",
        ["zh-tw"] = "技能数 + 計時",
    },
    timer_cd_single_colored          = {
        en = "Single Timer (Coloured)",
        ["zh-cn"] = "计时 彩色",
        ["zh-tw"] = "計時 彩色",
    },

    timer_buff_dropdown              = {
        en = Localize("loc_game_mode_expedition_objective_header_time") ..
            " (" .. Localize("loc_settings_menu_group_buff_interface_settings") .. ")",
    },
    timer_buff_dropdown_tooltip      = {
        en = string.format(
            "Controls the display of remaining duration for active buffs.\n\n" ..
            "• Ability: Tracks active ability durations (%s, %s, %s and Stealth).\n\n" ..
            "• Talents: Also tracks specific talents:\n" ..
            "  - %s\n" ..
            "  - %s\n" ..
            "  - %s\n" ..
            "  - %s",
            Localize("loc_talent_ogryn_combat_ability_special_ammo"),
            Localize("loc_talent_veteran_2_combat_ability"),
            Localize("loc_class_broker_name"),
            Localize("loc_talent_zealot_resist_death"),
            Localize("loc_talent_adamant_bullet_rain"),
            Localize("loc_talent_psyker_empowered_ability"),
            Localize("loc_talent_broker_passive_stun_immunity_on_toughness_broken")
        ),
    },
    timer_buff_disabled              = { en = Localize("loc_setting_checkbox_off") },
    timer_buff_ability_only          = { en = Localize("loc_glossary_term_class_ability") },
    timer_buff_all                   = { en = Localize("loc_glossary_term_class_ability") .. " + " .. Localize("loc_alias_talent_builder_view_title_summary") },

    timer_sound_enabled              = { en = Localize("loc_setting_notification_type_notification") .. " (" .. Localize("loc_settings_menu_category_sound") .. ")" },
    timer_sound_tooltip              = {
        en =
        "Sound to play when ability is ready.\n\nOther mods: 'Audible Ability Recharge' by demba for more control.",
        ["zh-cn"] = "更大音量替换原版技能刷新音效，更详细的设定使用demba制作的Audible Ability Recharge",
        ["zh-tw"] = "使用更大的音量替換技能刷新技能，更詳細的設定使用demba製作的Audible Ability Recharge",
    },

    timer_sound_default              = { en = Localize("loc_setting_mix_preset_flat") },
    timer_sound_zealot               = { en = Localize("loc_talent_zealot_bolstering_prayer") },
    timer_sound_blunt_shield         = {
        en = "Shield Impact", -- [ ] Localize(ogryn Slam talent)+"!"
        ["zh-cn"] = "梆!",
        ["zh-tw"] = "梆!",
    },
    timer_sound_item_tier3           = { en = Localize("loc_eor_card_title_random_reward") },

    supplies_supergroup              = { en = TextUtils.localize_to_upper("loc_action_interaction_pickup") },
    pocketable_settings              = { en = " " .. Localize("loc_healing_self_and_others") },
    pocketable_visibility_dropdown   = {
        en = "Icon Visibility", -- [ ] Localize
        ["zh-cn"] = "兴奋剂 / 补给品 可见性",
        ["zh-tw"] = "興奮劑 / 補給品 可見性",
    },
    pocketable_contextual            = { en = Localize("loc_setting_dodge_stamina_hud_both_dynamic") },
    pocketable_always                = { en = Localize("loc_setting_checkbox_on") },
    pocketable_disabled              = { en = Localize("loc_setting_checkbox_off") },
    medical_crate_color              = { en = Localize("loc_pickup_pocketable_medical_crate_01") },
    ammo_cache_color                 = { en = Localize("loc_pickup_pocketable_ammo_crate_01") },

    team_hud_mode                    = {
        en = "Team HUD", -- [ ] Localize
        ["zh-cn"] = "团队HUD",
        ["zh-tw"] = "团队HUD",
    },
    team_hud_mode_tooltip            = {
        en =
            "Choose teammate HUD layout:\n\n" ..
            "• Darktide Default: Vanilla team panel only.\n" ..
            "• Docked HUDs: RingHud tiles (left side). No bots.\n" ..
            "• Nameplate HUDs: Floating tiles over teammates. No bots.\n",
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
    team_hud_disabled                = { en = Localize("loc_setting_mix_preset_flat") },
    team_hud_docked                  = {
        en = "Docked", -- [ ] Localize (static?)
        ["zh-cn"] = "左停靠",
        ["zh-tw"] = "左停靠",
    },
    team_hud_floating                = { en = Localize("loc_settings_menu_group_nameplate_settings") },
    team_hud_floating_docked         = {
        en = "Docked and Nameplates", -- [ ] Localize
        ["zh-cn"] = "停靠 + 跟随",
        ["zh-tw"] = "停靠 + 跟隨",
    },
    team_hud_floating_vanilla        = {
        en = Localize("loc_setting_mix_preset_flat") .. " + " .. Localize("loc_settings_menu_group_nameplate_settings") },
    team_hud_floating_thin           = {
        en = "Minimal Default and Nameplates",
        --有点Bug
        ["zh-cn"] = "原版极简 + 跟随(有头像框显示BUG)",
        ["zh-tw"] = "原版極簡 + 跟隨",
    },

    team_supergroup                  = { en = TextUtils.localize_to_upper("loc_achievement_category_teamplay_label") },
    team_docked_position             = {
        en = " Docked Position"
    },
    team_hud_settings                = { en = " " .. Localize("loc_main_menu_warband_count") },
    team_hud_offset_x                = { en = "X" },
    team_hud_offset_y                = { en = "Y" },

    team_hud_detail                  = { en = " " .. Localize("loc_lobby_entry_inspect") },

    team_docked_axis                 = {
        en = "Direction", -- [ ] Localize
        ["zh-cn"] = "停靠方向", -- AI
        ["zh-tw"] = "停靠方向", -- AI
    },
    team_docked_axis_vertical        = { en = "  " },
    team_docked_axis_horizontal      = { en = "  " },
    team_tiles_scale                 = { en = Localize("loc_interface_setting_hud_scale") },

    team_hp_bar                      = {
        en = "Health Bars",
        ["zh-cn"] = "队友血条",
        ["zh-tw"] = "隊友血條",
    },
    team_hp_disabled                 = { en = Localize("loc_setting_checkbox_off") },
    team_hp_bar_always_text_off      = {
        en = "Bar Always",
        ["zh-cn"] = "始终显示 血条",
        ["zh-tw"] = "始終顯示 血條",
    },
    team_hp_bar_always_text_context  = {
        en = "Bar and Text Always",
        ["zh-cn"] = "始终显示 血条 + 数字",
        ["zh-tw"] = "始終顯示 血條 + 數字",
    },
    team_hp_bar_context_text_off     = {
        en = "Bar (" .. Localize("loc_setting_dodge_stamina_hud_both_dynamic") .. ")",
        ["zh-cn"] = "自动显示 血量条",
        ["zh-tw"] = "自動顯示 血量條"
    },
    team_hp_bar_context_text_context = {
        en = "Bar and Text (" .. Localize("loc_setting_dodge_stamina_hud_both_dynamic") .. ")",
        ["zh-cn"] = "自动显示 血条 + 数字 ",
        ["zh-tw"] = "自動顯示 血條 + 數字 ",
    },

    team_name_icon                   = {
        en = "Nameplate Icons", -- [ ] Localize
        ["zh-cn"] = "名字与图标",
        ["zh-tw"] = "名字與圖標",
    },

    name0_icon1_status1              = {
        en = "Class Icon, RH Status Icons", -- [ ] Localize
        ["zh-cn"] = "无名 大图标",
    },
    name0_icon1_status0              = {
        en = "Class Icon", -- [ ] Localize
        ["zh-cn"] = "无名字，大图标（原版状态）",
    },
    name0_icon0_status1              = {
        en = "RH Status Icons", -- [ ] Localize
    },
    name0_icon0_status0              = { en = Localize("loc_setting_checkbox_off") },
    name1_icon1_status1              = {
        en = "Name, Class Icon, RH Status Icons", -- [ ] Localize
    },
    name1_icon1_status0              = {
        en = "Name, Class Icon", -- [ ] Localize
    },
    name1_icon0_status1              = {
        en = "Name, Icon Prefix, RH Status Icons", -- [ ] Localize
    },
    name1_icon0_status0              = {
        en = "Name, Icon Prefix",
    },


    team_munitions                          = {
        en = Localize("loc_glossary_term_ammunition") .. " + "
            .. Localize("loc_glossary_term_class_ability")
    },

    team_munitions_disabled                 = { en = Localize("loc_setting_checkbox_off") },
    team_munitions_ammo_always_cd_enabled   = { en = Localize("loc_glossary_term_ammunition") },
    team_munitions_ammo_context_cd_disabled = {
        en = Localize("loc_glossary_term_ammunition") .. " ("
            .. Localize("loc_setting_dodge_stamina_hud_both_dynamic") .. ")"
    },
    team_munitions_ammo_always_cd_always    = {
        en = Localize("loc_glossary_term_ammunition") .. " + "
            .. Localize("loc_glossary_term_class_ability")
    },
    team_munitions_ammo_context_cd_enabled  = {
        en = Localize("loc_glossary_term_ammunition") .. " + "
            .. Localize("loc_glossary_term_class_ability") .. " ("
            .. Localize("loc_setting_dodge_stamina_hud_both_dynamic") .. ")"
    },

    team_pockets                            = {
        en = "Pocketables", -- [ ] Localize
    },
    team_pockets_disabled                   = { en = Localize("loc_setting_checkbox_off") },
    team_pockets_always                     = { en = Localize("loc_setting_checkbox_on") },
    team_pockets_context                    = { en = Localize("loc_setting_dodge_stamina_hud_both_dynamic") },

    vanilla_supergroup                      = { en = TextUtils.localize_to_upper("loc_setting_mix_preset_flat") },
    default_hud_visibility_settings         = { en = " " .. Localize("loc_settings_menu_category_interface") },
    hide_default_ability                    = {
        en = "Hide Ability Widget",
        ["zh-cn"] = "隐藏 技能图标",
        ["zh-tw"] = "隱藏 技能圖標",
    },
    hide_default_weapons                    = {
        en = "Hide Weapon Carousel",
        ["zh-cn"] = "隐藏 武器界面",
        ["zh-tw"] = "隱藏 武器界面",
    },
    hide_default_player                     = {
        en = "Hide Player Panel",
        ["zh-cn"] = "隐藏 玩家框（自己）",
        ["zh-tw"] = "隱藏玩家框（自己）",
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
    GENERIC_CYAN             = "青色", -- AI Note: Please do not translate this line
}

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
