---@class BetterEnemyTagMod:DMFMod
local mod = get_mod("BetterEnemyTag")

local localization = {
	mod_name = {
		en = "Better Enemy Tag",
		["zh-cn"] = "更好的敌人标签",
	},
	mod_description = {
		en = "Make Enemy Tags Look Better",
		["zh-cn"] = "让标签再次伟大",
	},
	general_settings = {
		en = "General Settings",
		["zh-cn"] = "一般设置",
	},
	reduce_screen_margin = {
		en = "Reduce Screen Margin",
		["zh-cn"] = "减少屏幕边距",
	},
	reduce_screen_margin_description = {
		en = "Expand the screen-space displayable range of enemy tags",
		["zh-cn"] = "扩大敌人标签在屏幕空间上的可显示范围",
	},
	enhanced_distance_scale = {
		en = "Enhanced Distance Scale",
		["zh-cn"] = "增强距离缩放",
	},
	enhanced_distance_scale_description = {
		en = "Make enemy tags shrink more noticeably as they get farther away",
		["zh-cn"] = "使敌人标签在远距离缩小得更明显",
	},
	disable_aim_scale_up = {
		en = "Disable Aim Scale Up",
		["zh-cn"] = "禁用瞄准缩放",
	},
	disable_aim_scale_up_description = {
		en = "Prevent enemy tags from scaling up when aiming at them",
		["zh-cn"] = "防止敌人标签在瞄准时变大",
	},
	hide_distance_text = {
		en = "Hide Distance Text",
		["zh-cn"] = "隐藏距离文本",
	},
	hide_off_screen_icon = {
		en = "Hide Off-Screen Icons",
		["zh-cn"] = "隐藏屏幕边缘外的敌人标签",
	},
	opacity_normal = {
		en = "Tag Opacity",
		["zh-cn"] = "标签不透明度",
	},
	fade_when_aim = {
		en = "Fade When Aim",
		["zh-cn"] = "瞄准时淡出",
	},
	opacity_aim = {
		en = "Opacity",
		["zh-cn"] = "不透明度",
	},
	sync_outline_color = {
		en = "Match Outline to Tag Color",
		["zh-cn"] = "轮廓颜色跟随标记",
	},
	icon_settings = {
		en = "Icon Settings",
		["zh-cn"] = "图标设置",
	},
	tag_icon = {
		en = "Tag Icon",
		["zh-cn"] = "标签图标",
	},
	tag_color = {
		en = "Color",
		["zh-cn"] = "颜色",
	},
	use_slot_color = {
		en = "Use Player Slot Color",
		["zh-cn"] = "使用玩家槽位颜色",
	},
	override_tag_color = {
		en = "Override Tag Color",
		["zh-cn"] = "覆盖标签颜色",
	},
	override_teammate_tag_color = {
		en = "Override Teammate Tag Color",
		["zh-cn"] = "覆盖队友标签颜色",
	},
	normal_tag_settings = {
		en = "Normal Tag Settings",
		["zh-cn"] = "普通标签设置",
	},
	veteran_tag_settings = {
		en = "Focus Target Tag Settings",
		["zh-cn"] = "聚焦目标标签设置",
	},
	companion_tag_settings = {
		en = "Cyber-Mastiff Tag Settings",
		["zh-cn"] = "智能獒犬标签设置",
	},
	servo_skull_tag_settings = {
		en = "Servo-Skull Tag Settings",
		["zh-cn"] = "伺服颅骨标签设置",
	},
	override_tag_settings = {
		en = "Override Tag Settings",
		["zh-cn"] = "覆盖标签设置",
	},
	default = {
		en = "Default",
		["zh-cn"] = "默认值",
	},
	Skull = {
		en = "Skull",
		["zh-cn"] = "颅骨",
	},
	Priority_Skull = {
		en = "Priority Skull",
		["zh-cn"] = "插剑颅骨",
	},
	Cracked_Skull = {
		en = "Cracked Skull",
		["zh-cn"] = "破碎颅骨",
	},
	Auric_Skull = {
		en = "Auric Skull",
		["zh-cn"] = "锐金颅骨",
	},
	Servo_Skull = {
		en = "Servo-Skull",
		["zh-cn"] = "伺服颅骨",
	},
	Cyber_Mastiff = {
		en = "Cyber-Mastiff",
		["zh-cn"] = "智能獒犬",
	},
	Eagle = {
		en = "Eagle",
		["zh-cn"] = "鹰",
	},
	Exclamation = {
		en = "Exclamation",
		["zh-cn"] = "感叹号",
	},
	Attention = {
		en = "Attention",
		["zh-cn"] = "注意",
	},
	Radar = {
		en = "Radar",
		["zh-cn"] = "雷达",
	},
	Circle = {
		en = "Circle",
		["zh-cn"] = "圆",
	},
	Rhombus_1 = {
		en = "Rhombus 1",
		["zh-cn"] = "四边形 1",
	},
	Rhombus_2 = {
		en = "Rhombus 2",
		["zh-cn"] = "四边形 2",
	},
	Rhombus_3 = {
		en = "Rhombus 3",
		["zh-cn"] = "四边形 3",
	},
	Target_1 = {
		en = "Target 1",
		["zh-cn"] = "目标 1",
	},
	Target_2 = {
		en = "Target 2",
		["zh-cn"] = "目标 2",
	},
}

function mod:make_text_colorful(text, red, green, blue)
	return "{#color(" .. red .. "," .. green .. "," .. blue .. ")}" .. text .. "{#reset()}"
end

function mod:get_localization()
	return localization
end

local colored_localization = table.clone(localization)
for key, translations in pairs(colored_localization) do
	if string.find(key, "_tag_color") then
		local red   = mod:get(key .. "_red")
		local green = mod:get(key .. "_green")
		local blue  = mod:get(key .. "_blue")

		if red ~= nil and green ~= nil and blue ~= nil then
			for language, text in pairs(translations) do
				text = text:gsub("{#color%(%d+,%d+,%d+%)%}", ""):gsub("{#reset%(%)%}", "")
				text = mod:make_text_colorful(text, red, green, blue)
				colored_localization[key][language] = text
			end
		end
	end
end

return colored_localization
