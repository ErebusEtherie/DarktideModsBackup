local function cf(text, color_name)
    local color = Color[color_name](255, true)
    return string.format("{#color(%s,%s,%s)}", color[2], color[3], color[4]) .. text .. "{#color(203,203,203)}"
end

-- grenade defaults 手榴弹默认值
local box = 2
local arc = 3
local rock = 4
local nuke = 1
local frag = 3
local krak = 2
local smoke = 3
local flame = 3
local shock = 3
local shield = 3
local medic = 4
local mine = 2
local arbites = 4
local dogsplosion = 3
local flask = 3
local launcher = 2
-- grenade increases 手榴弹增加
local enhanced = 2
local grenadier = 1
 
return {
    -- Mod Details Mod详细信息
    mod_name = {
        en = "AutoBlitz",
        ["zh-cn"] = "自动释放闪击",
    },
    mod_description = {
        en = "GRENADE OUT",
        ["zh-cn"] = "自动投掷各类手雷与职业技能道具",
    },
    -- Debug
    debug = {
        en = "Debug",
        ["zh-cn"] = "调试模式",
    },
    -- Groups 角色分组
    adamant = {
        en = cf(Localize("loc_class_adamant_name"),"medium_violet_red"),
        ["zh-cn"] = cf("法务官","medium_violet_red"),
    },
    ogryn = {
        en = cf(Localize("loc_class_ogryn_name"),"ui_ogryn"),
        ["zh-cn"] = cf("欧格林","ui_ogryn"),
    },
    veteran = {
        en =cf(Localize("loc_class_veteran_name"),"ui_veteran"),
        ["zh-cn"] = cf("老兵","ui_veteran"),
    },
    zealot = {
        en = cf(Localize("loc_class_zealot_name"),"ui_zealot"),
        ["zh-cn"] = cf("狂信徒","ui_zealot"),
    },
    -- Global Settings 全局设置
    allow_override = {
        en = "Allow Player Override",
        ["zh-cn"] = "允许手动打断自动投掷",
    },
    auto_throw_keybind = {
        en = "Auto-Throw Keybind",
        ["zh-cn"] = "自动投掷触发按键",
    },
    auto_throw_keybind_tooltip = {
        en = "Swaps to and throws grenades. When set, AutoBlitz will not automatically throw grenades unless the keybind is pressed.",
        ["zh-cn"] = "切换至手雷栏并投掷。绑定按键后，模组仅在按下该键时才会自动投掷，不会自主触发。"
    },
    allow_override_tooltip = {
        en = "If enabled, auto-throw can be cancelled by swapping weapons or aiming.",
        ["zh-cn"] = "开启后，切换武器、开镜瞄准可打断正在执行的自动投掷动作。",
    },
    -- Grenade Throw Mode 投掷方式
    overhand = {
        en = "Overhand",
        ["zh-cn"] = "高抛投掷",
    },
    underhand = {
        en = "Underhand",
        ["zh-cn"] = "低抛投掷",
    },
    -- Box 欧格林-投弹完毕！
    box_enabled = {
        en = cf("Big Box of Hurt","ui_ogryn_text"),
        ["zh-cn"] = cf("投弹完毕！（欧格林）","ui_ogryn_text"),
    },
    box_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    box_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    box_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Boxes: \nStandard: %d\nEnhanced Blitz: %d", box, box + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", box, box + enhanced),
    },

    -- Rock 欧格林-友善大石头
    rock_enabled = {
        en = cf("Big Friendly Rock","ui_ogryn_text"),
        ["zh-cn"] = cf("友善大石头（欧格林）","ui_ogryn_text"),
    },
    rock_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    rock_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    rock_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Rocks: \nStandard: %d\nEnhanced Blitz: %d", rock, rock + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", rock, rock + enhanced),
    },
    -- Nuke 欧格林-破片炸弹
    nuke_enabled = {
        en = cf("Frag Bomb","ui_ogryn_text"),
        ["zh-cn"] = cf("破片炸弹（欧格林）","ui_ogryn_text"),
    },
    nuke_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    nuke_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    nuke_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Frag Bombs: \nStandard: %d\nEnhanced Blitz: %d", nuke, nuke + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", nuke, nuke + enhanced),
    },

    -- 老兵手雷
    -- Frag 粉碎破片手雷
    frag_enabled = {
        en = cf("Shredder Frag Grenade","ui_veteran_text"),
        ["zh-cn"] = cf("粉碎破片手雷（老兵）","ui_veteran_text"),
    },
    frag_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    frag_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    frag_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Shredder Frag Grenades: \nStandard/%s: %d/%s\nEnhanced Blitz: %d/%s\n",
        cf("Grenadier", "ui_veteran_text"), frag, cf(frag + grenadier, "ui_veteran_text"), frag + enhanced, cf(frag + grenadier + enhanced, "ui_veteran_text")),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准/%s：%d/%s\n强化闪击天赋：%d/%s\n",
        cf("掷弹兵", "ui_veteran_text"), frag, cf(frag + grenadier, "ui_veteran_text"), frag + enhanced, cf(frag + grenadier + enhanced, "ui_veteran_text")),
       
    },
    -- Krak 穿甲手雷
    krak_enabled = {
        en = cf("Krak Grenade","ui_veteran_text"),
        ["zh-cn"] = cf("穿甲手雷（老兵）","ui_veteran_text"),
    },
    krak_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    krak_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    krak_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Krak Grenades: \nStandard/%s: %d/%s\nEnhanced Blitz: %d/%s\n",
        cf("Grenadier", "ui_veteran_text"), krak, cf(krak + grenadier, "ui_veteran_text"), krak + enhanced, cf(krak + grenadier + enhanced, "ui_veteran_text")),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准/%s：%d/%s\n强化闪击天赋：%d/%s\n",
        cf("掷弹兵", "ui_veteran_text"), krak, cf(krak + grenadier, "ui_veteran_text"), krak + enhanced, cf(krak + grenadier + enhanced, "ui_veteran_text")),
    },
    -- Smoke 烟雾弹
    smoke_enabled = {
        en = cf("Smoke Grenade","ui_veteran_text"),
        ["zh-cn"] = cf("烟雾弹（老兵）","ui_veteran_text"),
    },
    smoke_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    smoke_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    smoke_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Smoke Grenades: \nStandard/%s: %d/%s\nEnhanced Blitz: %d/%s\n",
        cf("Grenadier", "ui_veteran_text"), smoke, cf(smoke + grenadier, "ui_veteran_text"), smoke + enhanced, cf(smoke + grenadier + enhanced, "ui_veteran_text")),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准/%s：%d/%s\n强化闪击天赋：%d/%s\n",
        cf("掷弹兵", "ui_veteran_text"), smoke, cf(smoke + grenadier, "ui_veteran_text"), smoke + enhanced, cf(smoke + grenadier + enhanced, "ui_veteran_text")),
    },
    -- Flame 狂信徒-焚化手雷
    flame_enabled = {
        en = cf("Immolation Grenade","ui_zealot_text"),
        ["zh-cn"] = cf("焚化手雷（狂信徒）","ui_zealot_text"),
    },
    flame_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    flame_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    flame_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Immolation Grenades: \nStandard: %d\nEnhanced Blitz: %d", flame, flame + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", flame, flame + enhanced),
    },
    -- Shock 狂信徒-眩晕风暴手雷
    shock_enabled = {
        en = cf("Stunstorm Grenade","ui_zealot_text"),
        ["zh-cn"] = cf("眩晕风暴手雷（狂信徒）","ui_zealot_text"),
    },
    shock_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    shock_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    shock_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum Stunstorm Grenades: \nStandard: %d\nEnhanced Blitz: %d", shock, shock + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", shock, shock + enhanced),
    },
    -- Mine 法务官-震荡地雷
    mine_enabled = {
        en = cf(Localize("loc_talent_ability_shock_mine"), "pale_violet_red"),
        ["zh-cn"] = cf("震荡地雷（法务官）", "pale_violet_red")
    },
    mine_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    mine_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    mine_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_ability_shock_mine"), mine, mine + enhanced),
        ["zh-cn"] = string.format("持有地雷达到该数量才会自动部署。\n最大部署次数：\n标准：%d\n强化闪击天赋：%d", mine, mine + enhanced),
    },
    -- Arbites Grenade 法务官手雷
    arbites_enabled = {
        en = cf(Localize("loc_talent_ability_adamant_grenade"), "pale_violet_red"),
        ["zh-cn"] = cf("法务官手雷", "pale_violet_red")
    },
    arbites_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    arbites_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    arbites_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_ability_adamant_grenade"), arbites, arbites + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", arbites, arbites + enhanced),
    },
    -- Dogsplosion 法务官-训犬远程引爆
    dogsplosion_enabled = {
        en = cf(Localize("loc_talent_ability_detonate"), "pale_violet_red"),
        ["zh-cn"] = cf("远程引爆（法务官）", "pale_violet_red")
    },
    dogsplosion_enabled_tooltip = {
        en = string.format("Automatically triggers %s when the conditions below are met. \n\nAt least one of the following settings must be enabled to use this feature: \nRequire Minimum Enemy Count \nRequire Pounce",cf(Localize("loc_talent_ability_detonate"), "pale_violet_red")),
        ["zh-cn"] = "满足下述条件时自动触发训犬引爆。\n必须开启以下至少一项才能生效：\n敌人数量阈值判定\n扑击触发判定"
    },
    dogsplosion_use_threshold = {
        en = "Require Minimum Enemy Count",
        ["zh-cn"] = "敌人数量阈值判定"
    },
    dogsplosion_use_threshold_tooltip = {
        en = "When enabled, detonation will only take place if ANY of the enemy counts below are met. \nOnly enemies within the detonation radius are counted.",
        ["zh-cn"] = "开启后，仅当满足任意一项敌人数量条件才会引爆。仅统计爆炸范围内的敌人。"
    },
    dogsplosion_enemy_threshold = {
        en = "Total Enemies",
        ["zh-cn"] = "总敌人数量"
    },
    dogsplosion_elite_threshold = {
        en = "Total Elites",
        ["zh-cn"] = "精英敌人数量"
    },
    dogsplosion_special_threshold = {
        en = "Total Specialists",
        ["zh-cn"] = "特感敌人数量"
    },
    dogsplosion_boss_threshold = {
        en = "Total Bosses",
        ["zh-cn"] = "首领敌人数量"
    },
    dogsplosion_allow_daemonhost = {
        en = "Allow Detonation Near Sleeping Daemonhosts",
        ["zh-cn"] = "允许在沉睡恶魔宿主附近引爆"
    },
    dogsplosion_pounce_only = {
        en = "Require Pounce",
        ["zh-cn"] = "扑击触发判定"
    },
    dogsplosion_require_tag = {
        en = "Require Tag",
        ["zh-cn"] = "需要指令标记"
    },
    dogsplosion_require_tag_tooltip = {
        en = string.format("This setting only applies when Require Pounce is enabled. \nIf enabled, a command tag must also be present when the pounce occurs."),
        ["zh-cn"] = "仅在开启「扑击触发判定」时生效。开启后，训犬扑击目标必须带有指令标记才会引爆。"
    },
    dogsplosion_cooldown = {
        en = "Cooldown",
        ["zh-cn"] = "引爆冷却时间"
    },
    dogsplosion_minimum = {
        en = "Minimum Charges",
        ["zh-cn"] = "最低充能层数阈值"
    },
    dogsplosion_minimum_tooltip = {
        en = string.format("Must have at least this many charges to auto-trigger.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_ability_detonate"), dogsplosion, dogsplosion + enhanced),
        ["zh-cn"] = string.format("充能层数达到该数值才会自动引爆。\n最大可储存层数：\n标准：%d\n强化闪击天赋：%d", dogsplosion, dogsplosion + enhanced),
    },
    -- Hive Scum 巢都渣滓
    broker = {
        en = cf(Localize("loc_class_broker_name"), "ui_toughness_default"),
        ["zh-cn"] = cf("巢都渣滓", "ui_toughness_default"),
    },
    flask_enabled = {
        en = cf(Localize("loc_talent_broker_blitz_tox_grenade"), "ui_toughness_medium"),
        ["zh-cn"] = cf("化学腐蚀手雷（巢都渣滓）", "ui_toughness_medium"),
    },
    flask_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    flask_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    flask_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_broker_blitz_tox_grenade"), flask, flask + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", flask, flask + enhanced),
    },
    launcher_enabled = {
        en = cf(Localize("loc_talent_broker_blitz_missile_launcher"), "ui_toughness_medium"),
        ["zh-cn"] = cf("火箭发射器（巢都渣滓）", "ui_toughness_medium"),
    },
    launcher_minimum = {
        en = "Minimum Missiles",
        ["zh-cn"] = "最低火箭数量阈值",
    },
    launcher_tooltip = {
        en = string.format("Must have at least this many missiles to auto-launch.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_broker_blitz_missile_launcher"), launcher, launcher + enhanced),
        ["zh-cn"] = string.format("持有火箭达到该数量才会自动发射。\n最大发射次数：\n标准：%d\n强化闪击天赋：%d", launcher, launcher + enhanced),
    },
    -- Skitarii 护教军
    cryptic = {
        en = cf(Localize("loc_class_cryptic_name"), "ui_toughness_buffed"),
        ["zh-cn"] = cf("护教军", "ui_toughness_buffed"),
    },
    skull_enabled = {
        en = cf(Localize("loc_talent_cryptic_servo_skull"), "citadel_golden_griffon"),
        ["zh-cn"] = cf("伺服头骨自动强化", "citadel_golden_griffon")
    },
    skull_enabled_tooltip = {
        en = "Automatically empowers the Servo-Skull when available. Only applies to the default Servo-Skull equipped when no blitz is selected.",
        ["zh-cn"] = "伺服头骨就绪时自动强化；仅作用于未选择闪击技能时携带的基础伺服头骨。"
    },
    purg_enabled = {
        en = cf(Localize("loc_talent_cryptic_servo_skull_flamethrower"), "citadel_golden_griffon"),
        ["zh-cn"] = cf("喷火伺服头骨", "citadel_golden_griffon"),
    },
    medic_enabled = {
        en = cf(Localize("loc_talent_cryptic_servo_skull_inject_ally"), "citadel_golden_griffon"),
        ["zh-cn"] = cf("医疗伺服头骨", "citadel_golden_griffon"),
    },
    help_hogtied = {
        en = "Automatically Rescue Hogtied Allies",
        ["zh-cn"] = "自动解救被束缚的队友"
    },
    help_netted = {
        en = "Automatically Rescue Netted Allies",
        ["zh-cn"] = "自动解救被网困住的队友"
    },
    help_downed = {
        en = "Automatically Rescue Downed Allies",
        ["zh-cn"] = "自动拉起倒地队友"
    },
    medic_minimum = {
        en = "Minimum Charges",
        ["zh-cn"] = "最低充能层数阈值"
    },
    medic_tooltip = {
        en = string.format("Must have at least this many charges to auto-deploy.\n\nMaximum %s Charges: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_cryptic_servo_skull_inject_ally"), medic, medic + enhanced),
        ["zh-cn"] = string.format("充能层数达标才会自动部署治疗头骨。\n最大储存层数：\n标准：%d\n强化闪击天赋：%d", medic, medic + enhanced),
    },
    arc_enabled = {
        en = cf(Localize("loc_talent_cryptic_arc_grenades"), "citadel_golden_griffon"),
        ["zh-cn"] = cf("电弧手雷", "citadel_golden_griffon"),
    },
    arc_throw_type = {
        en = "Throw Type",
        ["zh-cn"] = "投掷方式",
    },
    arc_minimum = {
        en = "Minimum Grenades",
        ["zh-cn"] = "最低持有数量阈值",
    },
    arc_tooltip = {
        en = string.format("Must have at least this many grenades to auto-throw.\n\nMaximum %s: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_cryptic_arc_grenades"), arc, arc + enhanced),
        ["zh-cn"] = string.format("持有手雷达到该数量才会自动投掷。\n最大投放次数：\n标准：%d\n强化闪击天赋：%d", arc, arc + enhanced),
    },
    shield_enabled = {
        en = cf(Localize("loc_talent_cryptic_grenade_ability_force_field"), "citadel_golden_griffon"),
        ["zh-cn"] = cf("折射力场发生器", "citadel_golden_griffon"),
    },
    shield_type = {
        en = "Auto-Deploy Trigger",
        ["zh-cn"] = "自动部署触发条件"
    },
    current_health = {
        en = "Current Health %%",
        ["zh-cn"] = "当前生命值百分比"
    },
    damage_taken = {
        en = "Damage Taken",
        ["zh-cn"] = "短时间承受伤害量"
    },
    shield_type_tooltip = {
        en = Localize("loc_talent_cryptic_grenade_ability_force_field") .. " will be automatically deployed when the trigger condition is met, as dictated by the Trigger Threshold setting.",
        ["zh-cn"] = "满足设定的触发阈值时，自动部署折射力场发生器。"
    },
    shield_threshold = {
        en = "Trigger Threshold",
        ["zh-cn"] = "触发阈值"
    },
    shield_threshold_tooltip = {
        en = string.format("%s: Refraction Emitter will deploy when health drops below this percentage due to Ranged damage.\n%s: Refraction Emitter will deploy when this much health damage has been received from Ranged sources within the past 2 seconds.\n\nRegardless of Threshold, Refraction Emitter will auto-deploy if the next instance of incoming Ranged damage would plausibly result in death.",cf("Current Health %%", "citadel_golden_griffon"),cf("Damage Taken", "citadel_golden_griffon")),
        ["zh-cn"] = string.format("%s：远程伤害使生命值低于该百分比时自动开盾。\n%s：2秒内受到对应数值远程伤害时自动开盾。\n无论阈值如何，若下一次远程伤害足以致死，会强制自动部署力场。",cf("当前生命值百分比", "citadel_golden_griffon"),cf("短时间承受伤害量", "citadel_golden_griffon"))
    },
    shield_minimum = {
        en = "Minimum Charges",
        ["zh-cn"] = "最低充能层数阈值",
    },
    shield_tooltip = {
        en = string.format("Must have at least this many charges to auto-deploy.\n\nMaximum %s Charges: \nStandard: %d\nEnhanced Blitz: %d", Localize("loc_talent_cryptic_grenade_ability_force_field"), shield, shield + enhanced),
        ["zh-cn"] = string.format("充能层数达标才会自动部署力场。\n最大储存层数：\n标准：%d\n强化闪击天赋：%d", shield, shield + enhanced),
    },
}
