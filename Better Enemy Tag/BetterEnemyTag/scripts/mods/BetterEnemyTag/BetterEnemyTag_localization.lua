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
	display_settings = {
		en = "Display Settings",
		["zh-cn"] = "显示设置",
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
		en = "Enemy Tag Opacity",
		["zh-cn"] = "敌人标签不透明度",
	},
	fade_when_aim = {
		en = "Fade When Aim",
		["zh-cn"] = "瞄准时淡出",
	},
	opacity_aim = {
		en = "Opacity",
		["zh-cn"] = "不透明度",
	},
	normal_tag_color = {
		en = "Normal Tag Color",
		["zh-cn"] = "普通标签颜色",
	},
	veteran_tag_color = {
		en = "Veteran Focus Target Tag Color",
		["zh-cn"] = "老兵聚焦目标标签颜色",
	},
	companion_tag_color = {
		en = "Arbites Companion Tag Color",
		["zh-cn"] = "法务官伙伴标签颜色",
	},
	override_tag_color = {
		en = "Override Tag Color",
		["zh-cn"] = "覆盖标签颜色",
	},
	red = {
		en = "Red",
		["zh-cn"] = "红色",
	},
	green = {
		en = "Green",
		["zh-cn"] = "绿色",
	},
	blue = {
		en = "Blue",
		["zh-cn"] = "蓝色",
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
