-- File: scripts/mods/SimpleBuffFilter/SimpleBuffFilter_localization.lua
local mod = get_mod("SimpleBuffFilter")

local loc = {
    tbuff_mod_name = {
        en = "Simple Buff Filter",
        ru = "Простой фильтр баффов",
        ["zh-cn"] = "Buff 效果过滤器",
    },
    tbuff_mod_desc = {
        en = "Learns buffs as you play. Then filters them in missions or the Psykhanium.",
        ru = "Simple Buff Filter - Изучает баффы по мере игры. Затем фильтрует их в миссиях или Псайканиуме.",
        ["zh-cn"] = "增益图标显示过滤显示，支持多配置，分组游戏内重复增益，直接显示增益名称，而不是函数名，并自动适应学习",
    },
    bars_opacity = {
        en = "Opacity", --alpha
        ru = "Прозрачность",
        de = "Opazität",
        fr = "Opacité",
        it = "Opacità",
        es = "Opacidad",
        pl = "Nieprzezroczystość",
        ["zh-cn"] = "不透明度",
    },
}

return loc
