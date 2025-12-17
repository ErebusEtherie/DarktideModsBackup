--[[
    Author: Igromanru
    Date: 20.11.2024
    Mod Name: Decode Minigame Solver
]]
local mod = get_mod("DecodeMinigameSolver")

local SettingNames = mod:io_dofile("DecodeMinigameSolver/scripts/setting_names")

return {
  mod_name =
  {
    en = "Decode Minigame Solver",
  },
  mod_description =
  {
    en = "Passes the Decode Symbol Minigame automatically",
    ["zh-cn"] = "自动通过解码符号小游戏",
    ru = "Автоматически проходит мини-игру с символами декодирования",
  },
  [SettingNames.EnableMod] = {
    en = "Enable",
    ["zh-cn"] = "启用",
    ru = "Включить",
  },
  [SettingNames.InteractCooldown] = {
    en = "Interaction Cooldown",
    ["zh-cn"] = "交互冷却时间",
    ru = "Ожидание взаимодействия",
  },
  [SettingNames.InteractCooldownTooltip] = {
    en = "Wait time between interactions in milliseconds. Default: 150",
    ["zh-cn"] = "两次交互之间的等待时间（毫秒）。默认值：150",
    ru = "Время ожидания между взаимодействиями в миллисекундах. По умолчанию: 150",
  },
  [SettingNames.TargetPrecision] = {
    en = "Target Precision",
    ["zh-cn"] = "目标精度",
    ru = "Точность цели",
  },
  [SettingNames.TargetPrecisionTooltip] = {
    en = "The bigger the value, the smaller the detection window when the cursor is positioned on the symbol. Default: 4",
    ["zh-cn"] = "数值越大，当光标定位在符号上时，检测窗口越小。默认值：4",
    ru = "Чем больше значение, тем меньше окно обнаружения, когда курсор находится на символе. По умолчанию: 4",
  },
}
