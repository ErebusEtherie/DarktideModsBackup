-- File: weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details_localization.lua
local mod = get_mod("weapon_action_details")

return {
    mod_name = {
        en = "Weapon Action Details",
        ["zh-cn"] = "武器动作详情",
    },
    mod_description = {
        en = "Adds an actions tab to the inventory weapon details attack patterns panel.",
        ["zh-cn"] = "在仓库里对近战武器进行监视，选择查看攻击破甲（E），可以在攻击模式面板，查看新增的动作、特殊动作标签页。",
    },
    ignore_shield = {
        en = "Ignores Shields",
    },
    shield_breaker = {
        en = "Shield Breaker",
    },
    elite_special_stop = {
        en = "Elite/Specialist Stop",
    },
    first_shot = {         -- [ ] TODO find alternative from game loc keys
        en = "First Shot", -- Being used for Trickster on dual stub pistols
    },
    repeat_interval = {    -- [ ] TODO find alternative from game loc keys
        en = "Repeat",     -- Being used for Trickster on dual stub pistols
    },
    death_explosion = {
        en = "Death Explosion", -- [ ] TODO find alternative from game loc keys
    },
    toxin_death_explosion_description = {
        en = "On Death: Creates a damaging explosion.", -- [ ] TODO find alternative from game loc keys
    },
    gas_death_burst = {
        en = "Gas Death Burst", -- [ ] TODO find alternative from game loc keys
    },
    toxin_death_gas_description = {
        en = "On Death: Applies 1 %s stack to enemies in the gas burst.", -- [ ] TODO find alternative from game loc keys
    },
    brittleness_per_stack = {
        en = "Brittleness per Stack", -- [ ] TODO find alternative from game loc keys
    },
}
