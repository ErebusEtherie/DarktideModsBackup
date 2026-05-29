local localization = {
    mod_title = { en = "Damage Tracker", ["zh-cn"] = "伤害追踪器" },
    mod_description = { en = "Tracks damage on your HUD with static totals and floating combat text.", ["zh-cn"] = "在HUD上追踪你的战术伤害总计，并提供动态浮动战斗文本。" },

    main_tracking_setting = { en = "Static Damage Tracking (Totals)", ["zh-cn"] = "面板伤害追踪 (总计数据)" },
    tracking_mode = { en = "Tracking Mode", ["zh-cn"] = "追踪模式" },
    display_format = { en = "Display Format", ["zh-cn"] = "显示格式" },
    main_text_size = { en = "Unified Text Size", ["zh-cn"] = "统一字体大小" },
    main_x = { en = "Panel X Position", ["zh-cn"] = "面板 X 轴位置" },
    main_y = { en = "Panel Y Position", ["zh-cn"] = "面板 Y 轴位置" },

    mode_combined = { en = "Combined (Default)", ["zh-cn"] = "默认 (直伤和DoT合并计算)" },
    mode_separated = { en = "Separated (Two Lines)", ["zh-cn"] = "分离 (直伤+DoT 双行显示)" },
    mode_direct_only = { en = "Direct Only", ["zh-cn"] = "仅直伤" },
    mode_dot_only = { en = "DoT Only", ["zh-cn"] = "仅DoT" },

    combined_color = { en = "[Combined] Color", ["zh-cn"] = "[合并计算] 颜色" },
    combined_icon = { en = "[Combined] Icon", ["zh-cn"] = "[合并计算] 图标" },
    direct_color = { en = "[Direct] Color", ["zh-cn"] = "[直伤] 颜色" },
    direct_icon = { en = "[Direct] Icon", ["zh-cn"] = "[直伤] 图标" },
    dot_color = { en = "[DoT] Color", ["zh-cn"] = "[DoT] 颜色" },
    dot_icon = { en = "[DoT] Icon", ["zh-cn"] = "[DoT] 图标" },

    floating_text_setting = { en = "Floating Combat Text (FCT)", ["zh-cn"] = "浮动战斗文本 (FCT)" },
    floating_mode = { en = "FCT Mode", ["zh-cn"] = "显示模式" },
    floating_style = { en = "Animation Style", ["zh-cn"] = "动画形式" },
    fct_style_fixed = { en = "Fixed Aggregation", ["zh-cn"] = "固定" },
    fct_style_follow = { en = "Follow Entity", ["zh-cn"] = "跟随" },
    
    floating_weapon_filter = { en = "Weapon Filter", ["zh-cn"] = "武器过滤" },
    floating_x = { en = "FCT Origin X (Fixed)", ["zh-cn"] = "浮动起始 X 位置(固定)" },
    floating_y = { en = "FCT Origin Y (Fixed)", ["zh-cn"] = "浮动起始 Y 位置(固定)" },
    fct_offset_head = { en = "FCT Head Offset (follow)", ["zh-cn"] = "浮动头部偏移(跟随)" },
    fct_offset_body = { en = "FCT Body Offset (follow)", ["zh-cn"] = "浮动身体偏移(跟随)" },
    fct_distance_scaling = { en = "Distance Scaling (Follow)", ["zh-cn"] = "距离缩放(跟随)" },
    fct_distance_reference = { en = "Reference Distance", ["zh-cn"] = "参考距离" },
    fct_los_check = { en = "Wall Inspection(Follow)", ["zh-cn"] = "墙体检测(跟随)" },

    fct_mode_finesse = { en = "Crit/Weakspot Only", ["zh-cn"] = "仅限技巧伤害 (弱点/暴击)" },
    fct_mode_all_direct = { en = "All Direct (No DoT)", ["zh-cn"] = "所有直接伤害 (无DoT)" },
    fct_mode_all = { en = "All Damage", ["zh-cn"] = "全局伤害" },

    weapon_filter_both = { en = "Both Melee & Ranged", ["zh-cn"] = "默认 (近战与远程)" },
    weapon_filter_melee = { en = "Melee Only", ["zh-cn"] = "仅限近战" },
    weapon_filter_ranged = { en = "Ranged Only", ["zh-cn"] = "仅限远程" },

    pure_crit_color = { en = "[Crit] Color", ["zh-cn"] = "[非弱点暴击] 颜色" },
    pure_crit_size = { en = "[Crit] Base Size", ["zh-cn"] = "[非弱点暴击] 基础字号" },
    pure_crit_icon = { en = "[Crit] Icon", ["zh-cn"] = "[非弱点暴击] 图标" },

    pure_weakspot_color = { en = "[Weakspot] Color", ["zh-cn"] = "[弱点] 颜色" },
    pure_weakspot_size = { en = "[Weakspot] Base Size", ["zh-cn"] = "[弱点] 基础字号" },
    pure_weakspot_icon = { en = "[Weakspot] Icon", ["zh-cn"] = "[弱点] 图标" },

    weakspot_crit_color = { en = "[Weakspot+Crit] Color", ["zh-cn"] = "[弱点暴击] 颜色" },
    weakspot_crit_size = { en = "[Weakspot+Crit] Base Size", ["zh-cn"] = "[弱点暴击] 基础字号" },
    weakspot_crit_icon = { en = "[Weakspot+Crit] Icon", ["zh-cn"] = "[弱点暴击] 图标" },

    normal_color = { en = "[Normal] Color", ["zh-cn"] = "[普通直伤] 颜色" },
    normal_size = { en = "[Normal] Base Size", ["zh-cn"] = "[普通直伤] 基础字号" },
    normal_icon = { en = "[Normal] Icon", ["zh-cn"] = "[普通直伤] 图标" },

    fct_dot_color = { en = "[DoT] Color", ["zh-cn"] = "[DoT] 颜色" },
    fct_dot_size = { en = "[DoT] Base Size", ["zh-cn"] = "[DoT] 基础字号" },
    fct_dot_icon = { en = "[DoT] Icon", ["zh-cn"] = "[DoT] 图标" },

    mode_disabled = { en = "Disabled", ["zh-cn"] = "禁用" },
    mode_total_only = { en = "Total Only", ["zh-cn"] = "仅显示总计" },
    mode_single_only = { en = "Single Hit Only", ["zh-cn"] = "仅显示单次" },
    mode_both = { en = "Total + Single Hit", ["zh-cn"] = "总计 + 单次" },

    enable_overkill_damage = { en = "Damage settlement includes overkill", ["zh-cn"] = "伤害结算包含溢出伤害" },
    use_k_format = { en = "Use K-Format (e.g. 1.2k)", ["zh-cn"] = "使用K格式缩写 (如 1.2k)" },

    icon_none = { en = "None", ["zh-cn"] = "无" },
    icon_weapons = { en = "Weapons", ["zh-cn"] = "武器" },
    icon_difficulty_skull_heresy = { en = "Trimmed Skull", ["zh-cn"] = "边饰颅骨" },
    icon_difficulty_skull_uprising = { en = "Skull", ["zh-cn"] = "头骨" },
    icon_objective_main = { en = "Ball Spur", ["zh-cn"] = "球刺" },
    icon_incapacitated = { en = "Exclamation", ["zh-cn"] = "感叹号" },
    icon_dead = { en = "Deadly Skull", ["zh-cn"] = "致命头骨" },
    icon_pocketable_syringe_power = { en = "Brain Burst", ["zh-cn"] = "脑部爆裂" },
    icon_scars = { en = "Scars", ["zh-cn"] = "爪痕" },
    icon_mission_type_01 = { en = "Blade", ["zh-cn"] = "利刃" },
    icon_preset_19 = { en = "Boom", ["zh-cn"] = "爆炸" },
}
return localization