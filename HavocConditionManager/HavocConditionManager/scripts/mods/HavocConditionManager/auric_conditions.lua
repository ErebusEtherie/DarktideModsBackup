local mod = get_mod("HavocConditionManager")
if mod.auric_conditions then return mod.auric_conditions end
local Templates = require("scripts/settings/circumstance/circumstance_templates")
local Mutators = require("scripts/settings/mutator/mutator_templates")
local Overrides = require("scripts/settings/circumstance/mission_overrides")
local Lookup = require("scripts/network_lookup/network_lookup").circumstance_templates
local Auric = {entries={}}
-- Individual mechanisms from vanilla flash_mission/high_flash_mission templates.
-- Shared engine mutator IDs remain unchanged; condition_compatibility loads each once.
local definitions = {
    {"high_intensity","高强度","High intensity",{"mutator_add_resistance"},
        "使用原版高强度的抵抗强度修正；不改变所选任务等级。","Applies the native high-intensity resistance modifier without changing the chosen mission tier."},
    {"auric_pacing","金级战斗节奏","Auric pacing",{"mutator_increase_terror_event_points","mutator_reduced_ramp_duration","mutator_auric_tension_modifier"},
        "采用金级大漩涡的事件预算、压力系数与更短的升压阶段；高强度可另行选择。","Uses Auric Maelstrom event budgets, tension and shorter ramp duration. High intensity is selected separately."},
    {"waves","突击部队（原版）","Shock troop gauntlet (vanilla)",{"mutator_waves_of_specials"},
        "专家敌人成批协同进攻，使用原版同类数量与间隔。参考适配版仍单独保留。","Specialists attack in coordinated waves using native limits and intervals. The adapted version remains separate."},
    {"hounds","狩猎场：猎犬群","Hunting grounds",{"mutator_chaos_hounds"},
        "生成成群猎犬，沿用原版波次、推进距离与冷却。","Spawns packs of hounds with native waves, travel distances and cooldowns."},
    {"mutants","变种人群","Waves of mutants",{"mutator_mutants"},
        "按原版大漩涡机制增加变种人波次。","Adds native Maelstrom waves of mutants."},
    {"bombers","瘟疫爆破者群","Waves of poxbursters",{"mutator_poxwalker_bombers"},
        "按原版大漩涡机制增加瘟疫爆破者波次。","Adds native Maelstrom waves of poxbursters."},
    {"snipers","狙击手增援","Sniper reinforcements",{"mutator_snipers"},
        "增加原版狙击手增援；可与环境选择中的迷雾组合。","Adds native sniper reinforcements; can be combined with fog in Environment."},
    {"monsters","怪物专家（原版）","Monstrous specialists (vanilla)",{"mutator_monster_specials"},
        "使用原版特感替换弱化怪物的概率、血量与上限。","Uses native chances, health modifiers and limits for specialists replaced by weakened monsters."},
    {"blessing","纳垢祝福（原版）","Nurgle's blessing (vanilla)",{"mutator_minion_nurgle_blessing"},
        "使用原版受祝福敌人的比例与强化效果，不使用参考版的浩劫等级加成。","Uses native blessed-enemy probabilities and buffs, without the adapted version's Havoc-rank scaling."},
    {"patrols","增加精英巡逻","More elite patrols",{"mutator_more_boss_patrols"},
        "缩短原版精英巡逻的推进距离；关闭额外投放时仍保留该词条要求的巡逻。","Shortens the distance between native elite patrols. This condition retains its patrols when extra spawns are disabled."},
    {"ogryns","增加欧格林","More Ogryns",{"mutator_more_ogryns"},
        "使用大漩涡的精英与欧格林标签额度加成。高级模式下仍受自定义单位池和上限约束。","Applies Maelstrom elite and Ogryn tag allowances. Advanced mode retains its custom pools and caps."},
    {"melee","近战敌军","Melee enemies",{"mutator_only_melee_roamers","mutator_only_melee_trickle_hordes","mutator_only_melee_terror_events"},
        "将原版巡逻、持续敌群和事件编组改为近战配置；特感不受此项限制。","Uses melee native roamer, trickle and event compositions. Specialists are not restricted by this option."},
    {"ranged","远程敌军","Ranged enemies",{"mutator_only_ranged_roamers","mutator_only_ranged_trickle_hordes"},
        "将原版巡逻与持续敌群改为远程配置；特感和任务专用角色不受此项限制。","Uses ranged native roamer and trickle compositions; specialists and scripted actors are unaffected."},
    {"traitor_guard","仅血痂阵营","Scab faction only",{"mutator_only_traitor_guard_faction"},
        "使用大漩涡的叛军阵营限制。与其他阵营替换同时启用时遵循原版覆盖规则。","Uses the Maelstrom traitor-guard faction restriction. Other faction replacements follow native override rules."},
    {"cultists","仅渣滓阵营","Dreg faction only",{"mutator_only_cultist_faction"},
        "使用大漩涡的邪教徒阵营限制。与其他阵营替换同时启用时遵循原版覆盖规则。","Uses the Maelstrom cultist faction restriction. Other faction replacements follow native override rules."},
    {"no_encampments","无驻军营地","No encampments",{"mutator_no_encampments"},
        "关闭原版驻军营地编组，保留其他遭遇来源。","Disables native encampment groups while retaining other encounter sources."},
    {"cooldown","战斗技能冷却缩减","Combat ability cooldown reduction",{"mutator_ability_cooldown_reduction"},
        "应用大漩涡原版的战斗技能冷却缩减增益。","Applies the native Maelstrom combat ability cooldown reduction."},
    {"blitz","闪击能力强化","Enhanced blitz abilities",{"mutator_enchanced_grenade_ability"},
        "应用大漩涡原版的手雷／闪击能力强化增益。","Applies the native Maelstrom grenade/blitz enhancement."},
    {"no_ammo","无弹药拾取","No ammo pickups",{},
        "采用近战大漩涡的无弹药拾取与更多手雷拾取配置。","Uses melee Maelstrom's no-ammo and increased-grenade pickup configuration.",{"no_ammo_pickups","more_grenade_pickups"}},
    {"barrels","无空桶","No empty hazard barrels",{},
        "使用大漩涡的危险物配置：桶生成点不再选择空桶。","Uses Maelstrom hazard settings: barrel spawn points no longer select empty barrels.",{"no_empty_hazards"}},
}
local traditional = {
    ["高强度"]="高強度",
    ["使用原版高强度的抵抗强度修正；不改变所选任务等级。"]="使用原版高強度的抵抗強度修正；不改變所選任務等級。",
    ["金级战斗节奏"]="金級戰鬥節奏",
    ["采用金级大漩涡的事件预算、压力系数与更短的升压阶段；高强度可另行选择。"]="採用金級大漩渦的事件預算、壓力系數與更短的升壓階段；高強度可另行選擇。",
    ["突击部队（原版）"]="突擊部隊（原版）",
    ["专家敌人成批协同进攻，使用原版同类数量与间隔。参考适配版仍单独保留。"]="專家敵人成批協同進攻，使用原版同類數量與間隔。參考適配版仍單獨保留。",
    ["狩猎场：猎犬群"]="狩獵場：獵犬群",
    ["生成成群猎犬，沿用原版波次、推进距离与冷却。"]="生成成群獵犬，沿用原版波次、推進距離與冷卻。",
    ["变种人群"]="變種人群",
    ["按原版大漩涡机制增加变种人波次。"]="按原版大漩渦機制增加變種人波次。",
    ["瘟疫爆破者群"]="瘟疫爆破者群",
    ["按原版大漩涡机制增加瘟疫爆破者波次。"]="按原版大漩渦機制增加瘟疫爆破者波次。",
    ["狙击手增援"]="狙擊手增援",
    ["增加原版狙击手增援；可与环境选择中的迷雾组合。"]="增加原版狙擊手增援；可與環境選擇中的迷霧組合。",
    ["怪物专家（原版）"]="怪物專家（原版）",
    ["使用原版特感替换弱化怪物的概率、血量与上限。"]="使用原版特感替換弱化怪物的機率、血量與上限。",
    ["纳垢祝福（原版）"]="納垢祝福（原版）",
    ["使用原版受祝福敌人的比例与强化效果，不使用参考版的浩劫等级加成。"]="使用原版受祝福敵人的比例與強化效果，不使用參考版的浩劫等級加成。",
    ["增加精英巡逻"]="增加精英巡邏",
    ["缩短原版精英巡逻的推进距离；关闭额外投放时仍保留该词条要求的巡逻。"]="縮短原版精英巡邏的推進距離；關閉額外投放時仍保留該詞條要求的巡邏。",
    ["增加欧格林"]="增加歐格林",
    ["使用大漩涡的精英与欧格林标签额度加成。高级模式下仍受自定义单位池和上限约束。"]="使用大漩渦的精英與歐格林標籤額度加成。高階模式下仍受自定義單位池和上限約束。",
    ["近战敌军"]="近戰敵軍",
    ["将原版巡逻、持续敌群和事件编组改为近战配置；特感不受此项限制。"]="將原版巡邏、持續敵群和事件編組改為近戰配置；特感不受此項限制。",
    ["远程敌军"]="遠程敵軍",
    ["将原版巡逻与持续敌群改为远程配置；特感和任务专用角色不受此项限制。"]="將原版巡邏與持續敵群改為遠程配置；特感和任務專用角色不受此項限制。",
    ["仅血痂阵营"]="僅血痂陣營",
    ["使用大漩涡的叛军阵营限制。与其他阵营替换同时启用时遵循原版覆盖规则。"]="使用大漩渦的叛軍陣營限制。與其他陣營替換同時啟用時遵循原版覆蓋規則。",
    ["仅渣滓阵营"]="僅渣滓陣營",
    ["使用大漩涡的邪教徒阵营限制。与其他阵营替换同时启用时遵循原版覆盖规则。"]="使用大漩渦的邪教徒陣營限制。與其他陣營替換同時啟用時遵循原版覆蓋規則。",
    ["无驻军营地"]="無駐軍營地",
    ["关闭原版驻军营地编组，保留其他遭遇来源。"]="關閉原版駐軍營地編組，保留其他遭遇來源。",
    ["战斗技能冷却缩减"]="戰鬥技能冷卻縮減",
    ["应用大漩涡原版的战斗技能冷却缩减增益。"]="應用大漩渦原版的戰鬥技能冷卻縮減增益。",
    ["闪击能力强化"]="閃擊能力強化",
    ["应用大漩涡原版的手雷／闪击能力强化增益。"]="應用大漩渦原版的手雷／閃擊能力強化增益。",
    ["无弹药拾取"]="無彈藥拾取",
    ["采用近战大漩涡的无弹药拾取与更多手雷拾取配置。"]="採用近戰大漩渦的無彈藥拾取與更多手雷拾取配置。",
    ["无空桶"]="無空桶",
    ["使用大漩涡的危险物配置：桶生成点不再选择空桶。"]="使用大漩渦的危險物配置：桶生成點不再選擇空桶。",
}
local strings={}
for index,definition in ipairs(definitions) do
    local id="hcm_auric_"..definition[1]
    local available=true
    for _,mutator in ipairs(definition[4]) do if not Mutators[mutator] then available=false end end
    for _,override in ipairs(definition[7] or {}) do if not Overrides[override] then available=false end end
    if available then
        local title,description=id.."_title",id.."_description"
        strings[title]={en=definition[3],["zh-cn"]=definition[2],["zh-tw"]=traditional[definition[2]]}
        strings[description]={en=definition[6],["zh-cn"]=definition[5],["zh-tw"]=traditional[definition[5]]}
        local mission_overrides=definition[7] and Overrides.merge(unpack(definition[7])) or {}
        Templates[id]={name=id,theme_tag="default",mutators=definition[4],mission_overrides=mission_overrides,
            ui={display_name=title,description=description,happening_display_name=title,
                icon="content/ui/materials/icons/circumstances/maelstrom_02",
                mission_board_icon="content/ui/materials/mission_board/circumstances/maelstrom_02"}}
        -- NetworkLookup raises on missing keys; registration must bypass __index.
        if rawget(Lookup,id)==nil then Lookup[#Lookup+1]=id; Lookup[id]=#Lookup end
        Auric.entries[id]={title=title,description=description,order=index}
    else
        mod:warning("Skipped unavailable Auric condition: %s",id)
    end
end
mod:add_global_localize_strings(strings)
Auric.localizations=strings
mod.auric_conditions=Auric
return Auric
