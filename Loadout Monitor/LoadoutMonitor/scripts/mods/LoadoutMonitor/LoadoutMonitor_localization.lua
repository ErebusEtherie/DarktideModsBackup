local mod = get_mod("LoadoutMonitor")
local locr = {}
local lid = Managers and Managers.localization and Managers.localization:language() or mod:get("user_lid") or "en"
local default_lid_order = {"en","zh-cn"}
local _io = Mods.lua.io
mod.color_text = function(R,G,B,text)
	return string.format("{#color(%s,%s,%s)}%s{#reset()}",R,G,B,text)
end
local dnt = function(text,R,G,B)
	local L_text = Localize(text)
	if not R and not G and not B then
		return L_text
	else
		return mod.color_text(R,G,B,L_text)
	end
end
local function generate_translation(t,prefix,suffix,lids)
	if type(t) ~= "table" then return end
	local prefix = prefix or ""
	local suffix = suffix or ""
	local full_id = ""
	for id,text in pairs(t) do
		full_id = prefix..id..suffix
		locr[full_id] = locr[full_id] or {}
		if type(text) == "table" and type(lids) == "table" and #lids == #text then
			for i = 1,#lids do
				locr[full_id][lids[i]] = text[i]
			end
		elseif type(text) == "string" and type(lids) == "string" then
			locr[full_id][lids] = text	
		end
	end
end
local generate_notable_talents_description = function(nt)
	return string.format("%s:\n%s: %s || %s\n%s: %s",nt,dnt("loc_class_veteran_name"),dnt("loc_talent_veteran_better_deployables",0,206,209),dnt("loc_talent_veteran_combat_ability_revives",255,215,0),dnt("loc_class_cryptic_name"),dnt("loc_talent_cryptic_servo_skull_inject_ally",77,255,46))
end
locr = {	
	mod_name = {
		en = "Loadout Monitor",
		["zh-cn"] = "配置监控器",
	},
	mod_description = {
		en = generate_notable_talents_description("Notable talents"),
		["zh-cn"] = generate_notable_talents_description("特别天赋"),
		},
	lobby_exhibition = {
		en = "In lobby",
		["zh-cn"] = "在准备大厅中",
	},
	lobby_exhibition_weapons = {
		en = "Display weapons",
		["zh-cn"] = "显示武器",
	},
	lobby_exhibition_Keystone = {
		en = "Display Keystone",
		["zh-cn"] = "显示基石",
	},
	lobby_exhibition_feats = {
		en = "Display feats",
		["zh-cn"] = "显示天赋",
	},
	lobby_weapon_font_size = {
		en = "Font size",
		["zh-cn"] = "字体大小",
	},
	lobby_weapon_offset = {
		en = "Offset Y",
		["zh-cn"] = "Y轴",
	},
	lobby_weapon_gap = {
		en = "Line space",
		["zh-cn"] = "间距",
	},
	setting_player_name_group = {
		en = "Player Name",
		["zh-cn"] = "玩家名",
	},
	display_player_name = {
		en = "Player Name",
		["zh-cn"] = "玩家名",
	},
	display_companion_name = {
		en = "Dog Name",
		["zh-cn"] = "伙伴名",
	},
	setting_offset_x = {
		en = "Offset X",
		["zh-cn"] = "X轴",
	},
	setting_offset_y = {
		en = "Offset Y",
		["zh-cn"] = "Y轴",
	},
	setting_player_feats_group = {
		en = "Feats",
		["zh-cn"] = "天赋",
	},
	player_notable_talents = {
		en = "Notable talents",
		["zh-cn"] = "特别天赋",
	},
	setting_player_notable_talents = {
		en = "Notable talents",
		["zh-cn"] = "特别天赋",
	},
	display_notable_talents = {
		en = "Display notable talents",
		["zh-cn"] = "特别天赋",
	},
	notable_talents_intensity = {
		en = "Intensity",
		["zh-cn"] = "亮度",
	},
	setting_player_class_group = {
		en = "Class",
		["zh-cn"] = "职业",
	},
	display_main_class = {
		en = "Display main class",
		["zh-cn"] = "主职业显示",
	},
	by_name = {
		en = "By class name",
		["zh-cn"] = "以职业名",
	},
	by_symbol = {
		en = "By class symbol",
		["zh-cn"] = "以职业符号",
	},
	by_both = {
		en = "Both",
		["zh-cn"] = "全部",
	},
	setting_hide = {
		en = "Hide",
		["zh-cn"] = "隐藏",
	},
	setting_display = {
		en = "Display",
		["zh-cn"] = "显示",
	},
	display_sub_class = {
		en = "Display sub class",
		["zh-cn"] = "显示子职业",
	},
	user_weapon_name_size = {
		en = "Font size",
		["zh-cn"] = "字体大小",
	},
	setting_font_size = {
		en = "Font size",
		["zh-cn"] = "字体大小",
	},
	setting_icon_size = {
		en = "Icon size",
		["zh-cn"] = "图标大小",
	},
	setting_separation = {
		en = "Separation",
		["zh-cn"] = "间距",
	},
	user_bless_offset = {
		en = "Blessing offset adjust",
		["zh-cn"] = "祝福位置偏移",
	},
	user_perk_offset = {
		en = "Perk offset adjust",
		["zh-cn"] = "专长位置偏移",
	},
	setting_weapon_name_group = {
		en = "Weapons",
		["zh-cn"] = "武器",
	},
	user_weapon_name_lenghth = {
		en = "Name lenghth thresh",
		["zh-cn"] = "武器名称长度限制",
	},
	user_weapon_name_lenghth_tip = {
		en = "Decrese font size when weapon name is too long",
		["zh-cn"] = "武器名称过长时缩小字体大小",
	},
	user_weapon_name_multiplier = {
		en = "Over-lenghth name size multiplier(%%)",
		["zh-cn"] = "过长名称缩放（%%）",
	},
	setting_perk_blessing_group = {
		en = "Perk & Blessing",
		["zh-cn"] = "专长与祝福",
	},
	blessing_level_rule = {
		en = "Display blessing level by",
		["zh-cn"] = "祝福等级显示方式",
	},
	perk_level_rule = {
		en = "Display perk level by",
		["zh-cn"] = "专长等级显示方式",
	},
	by_number = {
		en = "Number",
		["zh-cn"] = "数字",
	 },
	by_color = {
		en = "Color",
		["zh-cn"] = "颜色",
	},
	by_character = {
		en = "Character",
		["zh-cn"] = "字符",
	},
	setting_other_group = {
		en = "Other",
		["zh-cn"] = "其它",
	},
	left_panel_lift = {
		en = "Tactical overlay lifting",
		["zh-cn"] = "战术面板抬升",
	},
	left_panel_lift_tip = {
		en = "Lift mission name & danger level panel to work better with mods such as contracts overlay",
		["zh-cn"] = "抬升任务名&危险等级区域，以适配如Contracts Overlay一类的MOD",
	},
	echo_team_loadout_brief = {
		en = "Give a brief about equipped weapons",
		["zh-cn"] = "提供全队武器简报",
	},
	-- Perks or blessings
	-- Some of them may not available in game yet
	trait_weapon_trait_increase_power = {
		en = "PWR ", -- Power
		["zh-cn"] = "能量", -- 伤害与踉跄效果
	},
	trait_gadget_damage_reduction_vs_flamers = {
		en = "FLAM", -- Damage Resistance (Tox Flamers)
		["zh-cn"] = "火兵", -- 伤害抗性（剧毒火焰兵）
	},
	trait_gadget_damage_reduction_vs_mutants = {
		en = "MUTN", -- Damage Resistance (Mutants)
		["zh-cn"] = "变种", -- 伤害抗性（变种人）
	},
	trait_gadget_damage_reduction_vs_gunners = {
		en = "GUNR", -- Damage Resistance (Gunners)
		["zh-cn"] = "炮手", -- 伤害抗性（炮手）
	},
	trait_gadget_damage_reduction_vs_snipers = {
		en = "SNPR", -- Damage Resistance (Snipers)
		["zh-cn"] = "狙击", -- 伤害抗性（狙击手）
	},
	trait_gadget_damage_reduction_vs_bombers = {
		en = "BRST", -- Damage Resistance (Poxbursters).
		["zh-cn"] = "自爆", -- 伤害抗性（瘟疫爆者）。
	},
	trait_gadget_damage_reduction_vs_hounds = {
		en = "HOND", -- Damage Resistance (Pox Hounds)
		["zh-cn"] = "猎犬", -- 伤害抗性（瘟疫猎犬）
	},
	trait_gadget_damage_reduction_vs_grenadiers = {
		en = "BMBR", -- Damage Resistance (Bombers)
		["zh-cn"] = "雷兵", -- 伤害抗性（轰炸者）
	},
	trait_weapon_trait_melee_common_wield_increased_resistant_damage = {
		en = "UYLD", -- Damage (Unyielding Enemies)
		["zh-cn"] = "不屈", -- 伤害（不屈敌人）
	},
	trait_weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage = {
		en = "IFST", -- Damage (Infested Enemies)
		["zh-cn"] = "感染", -- 伤害（感染敌人）
	},
	trait_weapon_trait_melee_common_wield_increased_unarmored_damage = {
		en = "UAMR", -- Damage (Unarmoured Enemies)
		["zh-cn"] = "无甲", -- 伤害（无甲敌人）
	},
	trait_weapon_trait_melee_common_wield_increased_berserker_damage = {
		en = "MNAC", -- Damage (Maniacs)
		["zh-cn"] = "狂人", -- 伤害（狂人）
	},
	trait_weapon_trait_melee_common_wield_increased_super_armor_damage = {
		en = "CRPC", -- Damage (Carapace Armoured Enemies)
		["zh-cn"] = "硬壳", -- 伤害（硬壳装甲敌人）
	},
	trait_weapon_trait_melee_common_wield_increased_armored_damage = {
		en = "FLAK", -- Damage (Flak Armoured Enemies)
		["zh-cn"] = "防弹", -- 伤害（防弹装甲敌人）
	},
	trait_weapon_trait_ranged_common_wield_increased_resistant_damage = {
		en = "UYLD", -- Damage (Unyielding Enemies)
		["zh-cn"] = "不屈", -- 伤害（不屈敌人）
	},
	trait_weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage = {
		en = "IFST", -- Damage (Infested Enemies)
		["zh-cn"] = "感染", -- 伤害（感染敌人）
	},
	trait_weapon_trait_ranged_common_wield_increased_unarmored_damage = {
		en = "UAMR", -- Damage (Unarmoured Enemies)
		["zh-cn"] = "无甲", -- 伤害（无甲敌人）
	},
	trait_weapon_trait_ranged_common_wield_increased_berserker_damage = {
		en = "MNAC", -- Damage (Maniacs)
		["zh-cn"] = "狂人", -- 伤害（狂人）
	},
	trait_weapon_trait_ranged_common_wield_increased_super_armor_damage = {
		en = "CRPC", -- Damage (Carapace Armoured Enemies)
		["zh-cn"] = "硬壳", -- 伤害（硬壳装甲敌人）
	},
	trait_weapon_trait_ranged_common_wield_increased_armored_damage = {
		en = "FLAK", -- Damage (Flak Armoured Enemies)
		["zh-cn"] = "防弹", -- 伤害（防弹装甲敌人）
	},
	trait_weapon_trait_increase_stamina = {
		en = "STAM", -- Stamina
		["zh-cn"] = "体力", -- 体力
	},
	trait_gadget_stamina_regeneration = {
		en = "STRG", -- Stamina Regeneration
		["zh-cn"] = "体回", -- 体力恢复
	},
	trait_gadget_cooldown_reduction = {
		en = "ABRG", -- Combat Ability Regeneration
		["zh-cn"] = "技回", -- 作战技能恢复
	},
	trait_weapon_trait_increase_impact = {
		en = "IMPC", -- Impact (Melee)
		["zh-cn"] = "冲击", -- 冲击（近战）
	},
	trait_gadget_revive_speed_increase = {
		en = "RVIV", -- Revive Speed (Ally)
		["zh-cn"] = "友活", -- 复活速度（盟友）
	},
	trait_gadget_mission_credits_increase = {
		en = "ODKT", -- Ordo Dockets (Mission Rewards)
		["zh-cn"] = "金币", -- 审判庭双子币（任务奖励）
	},
	trait_gadget_mission_reward_gear_instead_of_weapon_increase = {
		en = "CURO", -- Chance of Curio as Mission Reward (instead of Weapon)
		["zh-cn"] = "珍品", -- 以珍品作为任务奖励（而非武器）的几率
	},
	trait_gadget_stamina_increase = {
		en = "STAM", -- Max Stamina
		["zh-cn"] = "体力", -- 最大体力
		ja = "活力", -- 最大スタミナ
		ru = "ВНСЛ", -- Выносливость
	},
	trait_gadget_inate_health_increase = {
		en = "HP", -- Max Health
		["zh-cn"] = "生命", -- 最大生命值
		ja = "体力", -- 最大ヘルス
		ru = "ЗДОР", -- Здоровье
	},
	trait_gadget_health_increase = {
		en = "HP", -- Max Health
		["zh-cn"] = "生命", -- 最大生命值
	},
	trait_gadget_block_cost_reduction = {
		en = "BLK ", -- Block Efficiency
		["zh-cn"] = "格挡", -- 格挡效益
	},
	trait_weapon_trait_reduced_block_cost = {
		en = "BLK ", -- Block Efficiency
		["zh-cn"] = "格挡", -- 格挡效益
	},
	trait_weapon_trait_increase_finesse = {
		en = "FNS ", -- Finesse
		["zh-cn"] = "娴熟", -- 武器娴熟
	},
	trait_gadget_inate_max_wounds_increase = {
		en = "WND ", -- Wound(s)
		["zh-cn"] = "伤口", -- 生命格
		ja = "傷口", -- 傷口
		ru = "РАНЫ", -- Дополнительные раны
	},
	trait_weapon_trait_reduce_sprint_cost = {
		en = "SPRT", -- Sprint Efficiency
		["zh-cn"] = "疾跑", -- 疾跑效益
	},
	trait_gadget_sprint_cost_reduction = {
		en = "SPRT", -- Sprint Efficiency
		["zh-cn"] = "疾跑", -- 疾跑效益
	},
	trait_gadget_mission_xp_increase = {
		en = "EXP ", -- Experience
		["zh-cn"] = "经验", -- 经验
	},
	trait_gadget_corruption_resistance = {
		en = "CRPT", -- Corruption Resistance
		["zh-cn"] = "腐抗", -- 腐化抗性
	},
	trait_gadget_permanent_damage_resistance = {
		en = "GRIM", -- Corruption Resistance (Grimoires)
		["zh-cn"] = "书抗", -- 腐化抗性（魔法书）
	},
	trait_weapon_trait_ranged_increased_reload_speed = {
		en = "RLD ", -- Reload Speed
		["zh-cn"] = "装弹", -- 装弹速度
	},
	trait_weapon_trait_increase_damage = {
		en = "DMG ", -- Melee Damage
		["zh-cn"] = "伤害", -- 近战伤害
	},
	trait_weapon_trait_increase_damage_specials = {
		en = "SPEC", -- Increased Melee Damage (Specialists)
		["zh-cn"] = "专家", -- 近战伤害加成（专家）
	},
	trait_weapon_trait_increase_damage_hordes = {
		en = "HORD", -- Melee Damage (Groaners, Poxwalkers)
		["zh-cn"] = "群怪", -- 近战伤害（呻吟者、瘟疫行者）
	},
	trait_weapon_trait_increase_damage_elites = {
		en = "ELTE", -- Melee Damage (Elites)
		["zh-cn"] = "精英", -- 近战伤害（精英）
	},
	trait_weapon_trait_increase_weakspot_damage = {
		en = "WEAK", -- Melee Weak Spot Damage
		["zh-cn"] = "弱点", -- 近战弱点伤害
	},
	trait_weapon_trait_increase_attack_speed = {
		en = "ATSP", -- Melee Attack Speed
		["zh-cn"] = "攻速", -- 近战攻击速度
	},
	trait_weapon_trait_increase_crit_damage = {
		en = "CRDM", -- Melee Critical Hit Damage
		["zh-cn"] = "暴伤", -- 近战暴击伤害
	},
	trait_weapon_trait_increase_crit_chance = {
		en = "CRCH", -- Melee Critical Hit Chance
		["zh-cn"] = "暴率", -- 近战暴击几率
	},
	trait_weapon_trait_ranged_increase_damage = {
		en = "DMG ", -- Ranged Damage
		["zh-cn"] = "伤害", -- 远程伤害
	},
	trait_weapon_trait_ranged_increase_damage_specials = {
		en = "SPEC", -- Ranged Damage (Specialists)
		["zh-cn"] = "专家", -- 远程伤害（专家）
	},
	trait_weapon_trait_ranged_increase_damage_hordes = {
		en = "HORD", -- Ranged Damage (Groaners, Poxwalkers)
		["zh-cn"] = "群怪", -- 远程伤害（呻吟者、瘟疫行者）
	},
	trait_weapon_trait_ranged_increase_damage_elites = {
		en = "ELTE", -- Ranged Damage (Elites)
		["zh-cn"] = "精英", -- 远程伤害（精英）
	},
	trait_weapon_trait_ranged_increase_weakspot_damage = {
		en = "WEAK", -- Ranged Weak Spot Damage
		["zh-cn"] = "弱点", -- 远程弱点伤害
	},
	trait_weapon_trait_ranged_increase_crit_damage = {
		en = "CRDM", -- Ranged Critical Hit Damage
		["zh-cn"] = "暴伤", -- 远程暴击伤害
	},
	trait_weapon_trait_ranged_increase_crit_chance = {
		en = "CRCH", -- Increase Ranged Critical Strike Chance
		["zh-cn"] = "暴率", -- 远程暴击几率增加
	},
	trait_gadget_inate_toughness_increase = {
		en = "TN", -- Toughness
		["zh-cn"] = "韧性", -- 韧性
		ja = "靭性", -- 最大タフネス
		ru = "СТЙК", -- Стойкость
	},
	trait_gadget_toughness_increase = {
		en = "TN", -- Toughness
		["zh-cn"] = "韧性", -- 韧性
	},
	trait_gadget_toughness_regen_delay = {
		en = "TNRG", -- Toughness Regeneration Speed
		["zh-cn"] = "韧回", -- 韧性回复速度
	},
	trait_weapon_trait_ranged_increase_stamina = {
		en = "STAM", -- Stamina (Weapon is Active)
		["zh-cn"] = "体力", -- （使用武器时）体力
	},
	
	endview_scoreboard_weapons = {
		en = "Scoreboard: weapons",
		["zh-cn"] = "计分板：武器",
	},
	endview_scoreboard_weapons_perk = {
		en = "Scoreboard: weapon perks",
		["zh-cn"] = "计分板：武器专长",
	},
	endview_scoreboard_weapons_blessing = {
		en = "Scoreboard: weapon blessings",
		["zh-cn"] = "计分板：武器祝福",
	},
	endview_scoreboard_feat = {
		en = "Scoreboard: feats",
		["zh-cn"] = "计分板：天赋",
	},
	endview_scoreboard_blank = {
		en = "Scoreboard: blank",
		["zh-cn"] = "计分板：空行",
	},
	endview_scoreboard = {
		en = "At the end of missions",
		["zh-cn"] = "在任务结算时显示",
	},
	row_scoreboard_weapon_melee = {
		en = "Melee weapon",
		["zh-cn"] = "近战武器",
	},
	row_scoreboard_weapon_range = {
		en = "Range weapon",
		["zh-cn"] = "远程武器",
	},
	row_scoreboard_player_feat = {
		en = "Feats",
		["zh-cn"] = "天赋",
	},
	row_scoreboard_blank = {
		en = " ",
		["zh-cn"] = " ",
	},
	row_scoreboard_perk = {
		en = "Perks",
		["zh-cn"] = "专长",
	},
	row_scoreboard_blessing = {
		en = "Blessings",
		["zh-cn"] = "祝福",
	},
	endview_scoreboard_length = {
		en = "Scoreboard: Row length",
		["zh-cn"] = "计分板：单行长度",
	},
	player_Feats_symbol_Ability = {
		en = "A",
		["zh-cn"] = "技",
	},
	player_Feats_symbol_Blitz = {
		en = "B",
		["zh-cn"] = "闪",
	},
	player_Feats_symbol_Aura = {
		en = "Ar",
		["zh-cn"] = "环",
	},
	player_Feats_symbol_Keystone = {
		en = "K",
		["zh-cn"] = "基",
	},
	setting_Feats_order_Ability = {
		en = "Ability",
		["zh-cn"] = "技能",
	},
	setting_Feats_order_Blitz = {
		en = "Blitz",
		["zh-cn"] = "闪击",
	},
	setting_Feats_order_Aura = {
		en = "Aura",
		["zh-cn"] = "光环",
	},
	setting_Feats_order_Keystone = {
		en = "Keystone",
		["zh-cn"] = "基石",
	},
	player_feats_display_type = {
		en = "Display type",
		["zh-cn"] = "显示方式",
	},
	

	user_custom_feats_abbreviation_description = {
		en = "1:Ability   2:Blitz   3:Aura   4:Keystone",
		["zh-cn"] = "1：技能   2：闪击   3：光环   4：基石",		
	},
	lobby_log_debug = {
		en = "Debug:lobby",
	},
}
for i = 1,4 do
	locr[string.format("player_Feats_order_%s",i)] = {
		en = "Slot: "..tostring(i),
		["zh-cn"] = "槽位："..tostring(i),
	}
end
local def_abb = {
	--veteran
	veteran_combat_ability_elite_and_special_outlines = {"ES","刽",},
	veteran_combat_ability_stagger_nearby_enemies = {"VoC","令",},
	veteran_invisibility_on_combat_ability = {"Inf","渗",},
	
	veteran_grenade_apply_bleed = {"F","碎",},
	veteran_krak_grenade = {"K","穿",},
	veteran_smoke_grenade = {"S","烟",},
	
	veteran_aura_gain_ammo_on_elite_kill_improved = {"Amo","回",},
	veteran_increased_damage_coherency = {"Dmg","伤",},
	veteran_movement_speed_coherency = {"Spe","速",},
	
	veteran_snipers_focus = {"MF","专",},
	veteran_improved_tag = {"FT","聚",},
	veteran_weapon_switch_passive = {"WS","武",},
	--zealot
	zealot_attack_speed_post_ability = {"FF","冲",},
	zealot_bolstering_prayer = {"CSF","祷",},
	zealot_stealth = {"Sf","隐",},
	
	zealot_improved_stun_grenade = {"S","晕",},
	zealot_flame_grenade = {"I","燃",},
	zealot_throwing_knives = {"B","刃",},
	
	zealot_toughness_damage_reduction_coherency_improved = {"Bene","赐",},
	zealot_corruption_healing_coherency_improved = {"BoP","纯",},
	zealot_always_in_coherency = {"Z","孤",},
	zealot_stamina_cost_multiplier_aura = {"L","狂",},
	
	zealot_fanatic_rage = {"BP","炽",},
	zealot_martyrdom = {"M","殉",},
	zealot_quickness_passive = {"IJ","审",},
	--psyker
	psyker_shout_vent_warp_charge = {"VS","啸",},
	psyker_combat_ability_force_field = {"TS","盾",},
	psyker_combat_ability_stance = {"SG","凝",},
	
	psyker_brain_burst_improved = {"B","脑",},
	psyker_grenade_chain_lightning = {"S","电",},
	psyker_grenade_throwing_knives = {"A","袭",},
	
	psyker_aura_damage_vs_elites = {"KP","伤",},
	psyker_cooldown_aura_improved = {"SP","回",},
	psyker_aura_crit_chance_aura = {"Pr","暴",},
	
	psyker_passive_souls_from_elite_kills = {"WP","虹",},
	psyker_empowered_ability = {"EP","强",},
	psyker_new_mark_passive = {"DD","命",},
	--ogryn
	ogryn_longer_charge = {"I","冲",},
	ogryn_taunt_shout = {"L","护",},
	ogryn_special_ammo = {"P","弹",},
	
	ogryn_grenade_friend_rock = {"BR","石",},
	ogryn_grenade_frag = {"FG","雷",},
	ogryn_box_explodes = {"BA","盒",},
	
	ogryn_melee_damage_coherency_improved = {"B","伤",},
	ogryn_toughness_regen_aura = {"S","韧",},
	ogryn_damage_vs_suppressed_coherency = {"C","压",},
	
	ogryn_passive_heavy_hitter = {"HH","重",},
	ogryn_carapace_armor = {"FNP","痛",},
	ogryn_leadbelcher_no_ammo_chance = {"BLO","覆",},
	--adamant
	adamant_stance = {"CS","惩",},
	adamant_area_buff_drone_improved = {"NA","谕",},
	adamant_charge = {"BL","突",},
	
	adamant_whistle = {"RD","引",},
	adamant_shock_mine = {"SM","电",},
	adamant_grenade_improved = {"AG","雷",},
	
	adamant_companion_coherency = {"PoS","协",},
	adamant_reload_speed_aura = {"RE","效",},
	adamant_damage_vs_staggered_aura = {"BD","压",},
	
	adamant_execution_order = {"EO","处",},
	adamant_terminus_warrant = {"TW","终",},
	adamant_forceful = {"F","力",},

	adamant_companion_focus_elite = {"UB","野",},
	adamant_disable_companion = {"LW","独",},
	adamant_companion_focus_ranged = {"GGM","追",},
	--broker
	broker_ability_focus_improved = {"Desp","亡",},
	broker_ability_punk_rage = {"Ram","怒",},
	broker_ability_stimm_field = {"Sup","箱",},
	 
	broker_blitz_flash_grenade_improved = {"BO","熄",},
	broker_blitz_missile_launcher = {"RPG","爆",},
	broker_blitz_tox_grenade = {"CG","化",},
	
	broker_aura_gunslinger_improved = {"Gun","枪",},
	broker_coherency_melee_damage = {"Ruf","恶",},
	broker_coherency_anarchist = {"Anar","叛",},

	broker_keystone_vultures_mark_on_kill = {"VM","掠",},
	broker_keystone_adrenaline_junkie = {"AF","肾",},
	broker_keystone_chemical_dependency = {"CD","化",},
	--cryptic
	cryptic_chordclaw = {"Claw","爪",},
	cryptic_discharge = {"VE","电流",},
	cryptic_precision_stance = {"ACD","高级",},
	
	cryptic_servo_skull_improved = {"S","头骨",},
	cryptic_grenade_ability_arc_grenade = {"Arc","电弧"},
	cryptic_grenade_ability_force_field = {"IRE","折射"},
	
	cryptic_coherency_regen_aura_improved = {"Res","振",},
	cryptic_aura_weapon_improved = {"FRC","裂",},
	cryptic_ammo_aura = {"AD","弹",},
	
	cryptic_redline = {"RC","红线",},
	cryptic_dissector = {"FP","剥皮",},
	cryptic_overload_keystone = {"PO","过载",},
	-- = {"","",},
}
local highlights = {
	veteran_better_deployables = {"FI","箱"},
	veteran_combat_ability_revive_nearby_allies = {"Rv","活"},
	cryptic_servo_skull_inject_ally = {"MS","疗"},
}
generate_translation(def_abb,"def_","",default_lid_order)
generate_translation(highlights,"highlight_","",default_lid_order)

if lid and type(lid) == "string" then
	local _mod_directory = "./../mods/"
	local my_lid = "LoadoutMonitor/scripts/mods/LoadoutMonitor/LoadoutMonitor_localization_" .. lid
	local file = _io.open(_mod_directory .. my_lid .. ".lua","r")
	if file ~= nil then
		file:close()
		my_lid = mod:io_dofile(my_lid)
		if my_lid.common then
			local myl_nt = my_lid.common.player_notable_talents or my_lid.common.setting_player_notable_talents
			if my_nt then
				my_lid.common.mod_description = generate_notable_talents_description(myl_nt)
			end
			generate_translation(my_lid.common,nil,nil,lid)			
		end
		if my_lid.talents then generate_translation(my_lid.talents,"def_",nil,lid) end
		if my_lid.notable then generate_translation(my_lid.notable,"highlight_",nil,lid) end
	end
end
return locr


--[[
 = {
	en = "",
	["zh-cn"] = "",
},
--]]