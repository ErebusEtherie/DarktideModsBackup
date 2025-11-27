local mod = get_mod("crusher_attack_indicator")
local version = "1.0.0"

local localizations = {
	mod_name = {
		["en"] = "Crusher Cleave Indicator",
		["zh-cn"] = "粉碎者横扫指示器",
		["ru"] = "Индикатор замаха Крушителя",
	},
	mod_description = {
		["en"] = "Shows colored rings for Crusher cleave attacks. Yellow for warning, Red for the actual attack. Optional persistent yellow ring. Version: " .. version,
		["zh-cn"] = "显示粉碎者横扫攻击的彩色指示环 - 黄色为警告，红色为实际攻击。可选常驻黄色环。版本：" .. version,
		["ru"] = "Показывает цветные кольца для атак Крушителя - Жёлтый для предупреждения, Красный для самой атаки. Опциональное постоянное жёлтое кольцо. Версия: " .. version,
	},
    enabled = {
        ["en"] = "Enabled",
        ["zh-cn"] = "启用",
        ["ru"] = "Включено",
    },
    persistent_yellow = {
        ["en"] = "Always Show Yellow Ring", 
        ["zh-cn"] = "始终显示黄色环",
        ["ru"] = "Всегда показывать жёлтое кольцо",
    },
    persistent_yellow_tooltip = {
        ["en"] = "Show yellow ring around crushers at all times (not just during attacks)",
        ["zh-cn"] = "始终在粉碎者周围显示黄色环（不仅限于攻击期间）",
        ["ru"] = "Показывать жёлтое кольцо вокруг крушителей постоянно (не только во время атак)",
    },
    ring_radius = {
        ["en"] = "Ring Radius",
        ["zh-cn"] = "指示环半径", 
        ["ru"] = "Радиус кольца",
    },
    ring_radius_tooltip = {
        ["en"] = "Radius of the indicator rings",
        ["zh-cn"] = "指示环的半径大小",
        ["ru"] = "Радиус индикаторных колец",
    },
    warning_settings = {
        ["en"] = "Yellow Warning Ring Settings",
        ["zh-cn"] = "黄色警告环设置",
        ["ru"] = "Настройки жёлтого предупреждающего кольца",
    },
    warning_color_red = {
        ["en"] = "Red",
        ["zh-cn"] = "红色",
        ["ru"] = "Красный",
    },
    warning_color_red_tooltip = {
        ["en"] = "Yellow Warning - Red Component",
        ["zh-cn"] = "黄色警告 - 红色分量",
        ["ru"] = "Жёлтое предупреждение - Красная составляющая",
    },
    warning_color_green = {
        ["en"] = "Green", 
        ["zh-cn"] = "绿色",
        ["ru"] = "Зелёный",
    },
    warning_color_green_tooltip = {
        ["en"] = "Yellow Warning - Green Component",
        ["zh-cn"] = "黄色警告 - 绿色分量", 
        ["ru"] = "Жёлтое предупреждение - Зелёная составляющая",
    },
    warning_color_blue = {
        ["en"] = "Blue",
        ["zh-cn"] = "蓝色",
        ["ru"] = "Синий", 
    },
    warning_color_blue_tooltip = {
        ["en"] = "Yellow Warning - Blue Component",
        ["zh-cn"] = "黄色警告 - 蓝色分量",
        ["ru"] = "Жёлтое предупреждение - Синяя составляющая",
    },
    warning_color_alpha = {
        ["en"] = "Opacity",
        ["zh-cn"] = "不透明度",
        ["ru"] = "Прозрачность",
    },
    warning_color_alpha_tooltip = {
        ["en"] = "Yellow Warning - Opacity",
        ["zh-cn"] = "黄色警告 - 不透明度",
        ["ru"] = "Жёлтое предупреждение - Прозрачность",
    },
    attack_settings = {
        ["en"] = "Red Attack Ring Settings", 
        ["zh-cn"] = "红色攻击环设置",
        ["ru"] = "Настройки красного атакующего кольца",
    },
    attack_color_red = {
        ["en"] = "Red",
        ["zh-cn"] = "红色", 
        ["ru"] = "Красный",
    },
    attack_color_red_tooltip = {
        ["en"] = "Red Attack - Red Component",
        ["zh-cn"] = "红色攻击 - 红色分量",
        ["ru"] = "Красная атака - Красная составляющая",
    },
    attack_color_green = {
        ["en"] = "Green",
        ["zh-cn"] = "绿色",
        ["ru"] = "Зелёный",
    },
    attack_color_green_tooltip = {
        ["en"] = "Red Attack - Green Component", 
        ["zh-cn"] = "红色攻击 - 绿色分量",
        ["ru"] = "Красная атака - Зелёная составляющая",
    },
    attack_color_blue = {
        ["en"] = "Blue",
        ["zh-cn"] = "蓝色",
        ["ru"] = "Синий",
    },
    attack_color_blue_tooltip = {
        ["en"] = "Red Attack - Blue Component",
        ["zh-cn"] = "红色攻击 - 蓝色分量", 
        ["ru"] = "Красная атака - Синяя составляющая",
    },
    attack_color_alpha = {
        ["en"] = "Opacity",
        ["zh-cn"] = "不透明度",
        ["ru"] = "Прозрачность",
    },
    attack_color_alpha_tooltip = {
        ["en"] = "Red Attack - Opacity",
        ["zh-cn"] = "红色攻击 - 不透明度",
        ["ru"] = "Красная атака - Прозрачность",
    },
}

return localizations