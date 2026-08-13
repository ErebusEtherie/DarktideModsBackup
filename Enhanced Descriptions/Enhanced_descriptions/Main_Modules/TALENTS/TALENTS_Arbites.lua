---@diagnostic disable: undefined-global
-- ARBITES TALENT MODULE -- МОДУЛЬ ТАЛАНТОВ АРБИТРЕС

local mod = get_mod("Enhanced_descriptions")

-- Using cached utilities - Используем кэшированные утилиты
local Utils = mod.get_utils()

-- Importing all necessary functions and constants - Импорт всех нужных функций и констант
local create_template = Utils.create_template
local loc_text = Utils.loc_text
local CKWord = Utils.CKWord
local CNumb = Utils.CNumb
local CPhrs = Utils.CPhrs
local CNote = Utils.CNote
local Dot_nc = Utils.DOT_NC or "•"
local Dot_red = Utils.DOT_RED or "•"
local Dot_green = Utils.DOT_GREEN or "•"

-- Localization of Arbites talents -- Локализации талантов арбитрес
local arbites_localizations = {
--[+ ++ARBITES - АРБИТЕС++ +]--
--[+ +BLITZ - БЛИЦ+ +]--
	--[+ BLITZ 0 - Arbites Grenade +]--	26.03.2026
	["loc_talent_ability_adamant_grenade_description"] = { -- charges: 4, +colors
		en = "Throw an "..CKWord("Arbites Grenade", "Arbites_gren_rgb").." that explodes after a short delay.\n"
			..Dot_nc.." {charges:%s} Max Grenades.\n"
			.."\n"
			..Dot_green.." Base "..CKWord("Damage", "Damage_rgb").." epicenter: "..CNumb("1500", "n_1500_rgb")..".\n"
			..Dot_green.." "..CKWord("Staggers", "Staggers_rgb").." all enemies except Mutants and enemies with an active Void shield.\n"
			..Dot_nc.." Max explosion radius: "..CNumb("10", "n_10_rgb").." meters.\n"
			..Dot_nc.." Above average armor "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_red.." Very low "..CKWord("Damage", "Damage_rgb").." vs Carapace.",
		ru = "Вы бросаете "..CKWord("Гранату арбитрес", "Arbites_gren_rgb_ru")..", которая взрывается после короткой задержки.\n" -- Граната арбитрес -- руоф Граната Арбитрес
			..Dot_nc.." Максимум {charges:%s} гранаты.\n"
			.."\n"
			..Dot_green.." Базовый "..CKWord("урон", "uron_rgb_ru").." в эпицентре: "..CNumb("1500", "n_1500_rgb")..".\n"
			..Dot_green.." "..CKWord("Ошеломляет", "Oshelomlaet_rgb_ru").." всех врагов кроме мутантов и врагов с активным пустотным щитом.\n"
			..Dot_nc.." Максимальный радиус взрыва: "..CNumb("10", "n_10_rgb").." метров.\n"
			..Dot_nc.." Средний "..CKWord("урон", "uron_rgb_ru").." по противоосколочной броне.\n"
			..Dot_red.." Слабый "..CKWord("урон", "uron_rgb_ru").." по панцирной броне.",
		["zh-tw"] = "投擲一枚"..CKWord("法務官手榴彈", "Arbites_gren_rgb_tw").."，短暫延遲後爆炸。\n"
			..Dot_nc.." {charges:%s} 最大手榴彈數量。\n"
			.."\n"
			..Dot_green.." 爆炸中心基礎"..CKWord("傷害", "Damage_rgb_tw").."："..CNumb("1500", "n_1500_rgb").."。\n"
			..Dot_green.." 使所有敵人"..CKWord("踉蹌", "Staggers_rgb_tw").."，\n"
			.."（變種人與有虛空護盾的敵人除外）\n"
			..Dot_nc.." 最大爆炸半徑："..CNumb("10", "n_10_rgb").." 米。\n"
			..Dot_nc.." 對護甲"..CKWord("傷害", "Damage_rgb_tw").."略高於平均值。\n"
			..Dot_red.." 對甲殼護甲"..CKWord("傷害", "Damage_rgb_tw").."極低。",
	},
	--[+ BLITZ 1 - Remote Detonation +]--	26.03.2026
	["loc_talent_ability_detonate_description"] = { -- max_charges: 3, cooldown: 50, s->seconds, +colors
		en = "Cause an Explosion at your Cyber-Mastiff's Location. "..CKWord("Staggering", "Staggering_rgb").." and "..CKWord("Electrocuting", "Electrcuting_rgb").." nearby Enemies.\n"
			..Dot_nc.." {max_charges:%s} Charges.\n"
			..Dot_nc.." Cooldown {cooldown:%s} seconds.\n"
			.."\n"
			..Dot_green.." Base "..CKWord("Damage", "Damage_rgb")..": ["..CNumb("600", "n_600_rgb").."-"..CNumb("200", "n_200_rgb").."].\n"
			.."\n"
			..Dot_green.." Forces a light "..CKWord("Stagger", "Stagger_rgb").." on all enemies within radius for "..CNumb("2.5", "n_2_5_rgb").." seconds.\n"
			..Dot_nc.." Max explosion radius: "..CNumb("4", "n_4_rgb").." meters.\n"
			-- ..Dot_nc.." Above average armor "..CKWord("Damage", "Damage_rgb")..".\n"
			-- ..Dot_red.." Very low "..CKWord("Damage", "Damage_rgb").." vs Carapace.\n"
			.."\n"
			..Dot_red.." Arbitrator cannot pick up grenade Ammo.",
		ru = "Создаёт взрыв в месте нахождения вашего кибермастифа, "..CKWord("ошеломляя", "oshelomlaa_rgb_ru").." и поражает "..CKWord("электрошоком", "elektroshokom_rgb_ru").." ближайших врагов.\n"
			..Dot_nc.." {max_charges:%s} заряда.\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунд.\n"
			.."\n"
			..Dot_green.." Базовый "..CKWord("урон", "uron_rgb_ru")..": ["..CNumb("600", "n_600_rgb").."-"..CNumb("200", "n_200_rgb").."].\n"
			.."\n"
			..Dot_green.." Наносит лёгкое "..CKWord("ошеломление", "oshelomlenie_rgb_ru").." всем врагам в радиусе на "..CNumb("2.5", "n_2_5_rgb").." секунды.\n"
			..Dot_nc.." Максимальный радиус взрыва: "..CNumb("4", "n_4_rgb").." метра.\n"
			-- ..Dot_nc.." Высокий "..CKWord("урон", "uron_rgb_ru").." по броне.\n"
			-- ..Dot_red.." Очень низкий "..CKWord("урон", "uron_rgb_ru").." по панцирной броне.\n"
			.."\n"
			..Dot_red.." Арбитратор не может подбирать гранаты.", -- Дистанционный подрыв
		["zh-tw"] = "在電子獒犬所在位置引發爆炸，\n"
			.."使附近敵人"..CKWord("踉蹌", "Staggering_rgb_tw").."並受到"..CKWord("電擊", "Electrocute_rgb_tw").."。\n"
			..Dot_nc.." {max_charges:%s} 充能次數。\n"
			..Dot_nc.." 冷卻時間 {cooldown:%s} 秒。\n"
			.."\n"
			..Dot_green.." 基礎"..CKWord("傷害", "Damage_rgb_tw").."：["..CNumb("600", "n_600_rgb").."-"..CNumb("200", "n_200_rgb").."]。\n"
			.."\n"
			..Dot_green.." 使範圍內所有敵人輕度"..CKWord("踉蹌", "Stagger_rgb_tw").." "..CNumb("2.5", "n_2_5_rgb").." 秒。\n"
			..Dot_nc.." 最大爆炸半徑："..CNumb("4", "n_4_rgb").." 米。\n"
			.."\n"
			..Dot_red.." 仲裁官無法拾取手榴彈彈藥。",
	},
	--[+ BLITZ 2 - Voltaic Shock Mine +]--	26.03.2026
	["loc_talent_ability_shock_mine_description"] = { -- talent_name: Voltaic Shock Min, duration: 15, range: 3, s->seconds, m->meters, +colors
		en = "Throw a {talent_name:%s} that activates as it lands.\n"
			.."For {duration:%s} seconds it will "..CKWord("Electrocute", "Electrocute_rgb").." all enemies within {range:%s} meters.",
		ru = "Вы бросаете "..CKWord("Вольтаическую шоковую мину", "Electro_mine_rgb_ru")..", которая активируется при приземлении.\n"
			.."В течение {duration:%s} секунд она будет поражать "..CKWord("электрошоком", "elektroshokom_rgb_ru").." всех врагов в радиусе {range:%s} метров.", -- Вольтаическая шоковая мина
		["zh-tw"] = "投擲一枚 {talent_name:%s}，落地後立刻啟動。\n"
			.."持續 {duration:%s} 秒，\n"
			.."對 {range:%s} 米範圍內的所有敵人施加"..CKWord("電擊", "Electrocute_rgb_tw").."。",
	},
	--[+ BLITZ 3 - Arbites Grenade +]--	26.03.2026
	["loc_talent_ability_adamant_grenade_improved_description"] = { -- talent_name: Arbites Grenade, charges: 4
		en = "Throw an {talent_name:%s} that explodes after a short delay.\n"
			..Dot_nc.." {charges:%s} Max Grenades.\n"
			..Dot_green.." This is an augmented version of {talent_name:%s}.",
		ru = "Вы бросаете "..CKWord("Гранату арбитрес", "Arbites_gren_rgb_ru")..", которая взрывается после короткой задержки.\n"
			..Dot_nc.." Максимум {charges:%s} гранаты.\n"
			..Dot_green.." Это улучшенная версия таланта {talent_name:%s}.",  -- Граната арбитрес -- руоф Граната Арбитрес
		["zh-tw"] = "投擲一枚 {talent_name:%s}，短暫延遲後爆炸。\n"
			..Dot_nc.." {charges:%s} 最大手榴彈數量。\n"
			..Dot_green.." 此為 {talent_name:%s} 的強化版本。",
	},
--[+ +AURA - АУРА+ +]--
	--[+ AURA 0 - Part of the Squad +]--	26.03.2026
	["loc_talent_adamant_companion_coherency_desc"] = { 
		en = "Your Cyber-Mastiff counts towards unit "..CKWord("Coherency", "Coherency_rgb")..".",
		ru = "Ваш кибермастиф учитывается как союзник под действием "..CKWord("сплочённости", "splochennosti_rgb_ru")..".", -- Часть отряда
		["zh-tw"] = "你的電子獒犬計入隊伍"..CKWord("協同", "Coherency_rgb_tw").."人數。",
	},
	--[+ AURA 1 - Part of the Squad +]--	26.03.2026
	["loc_talent_adamant_companion_coherency_alt_desc"] = { -- tdr: +7.5%, +colors
		en = Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb").." for you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".\n"
			.."\n"
			.."Your Cyber-Mastiff counts towards unit "..CKWord("Coherency", "Coherency_rgb")..".",
		ru = Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru").." для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".\n"
			.."\n"
			.."Ваш кибермастиф учитывается как союзник под действием "..CKWord("сплочённости", "splochennosti_rgb_ru")..".", -- Часть отряда
		["zh-tw"] = Dot_green.." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."，\n"
			.."對你與"..CKWord("協同", "Coherency_rgb_tw").."範圍內的隊友生效。\n"
			.."\n"
			.."你的電子獒犬計入隊伍"..CKWord("協同", "Coherency_rgb_tw").."人數。",
	},
	--[+ AURA 2 - Ruthless Efficiency +]--	26.03.2026
	["loc_talent_adamant_reload_speed_aura_desc"] = { -- reload_speed: +7.5%, +colors
		en = Dot_green.." {reload_speed:%s} Reload Speed for you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".",
		ru = Dot_green.." {reload_speed:%s} к скорости перезарядки для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".", -- Беспощадная эффективность -- руоф Беспощадная сила
		["zh-tw"] = Dot_green.." {reload_speed:%s} 裝填速度，\n"
			.."對你與"..CKWord("協同", "Coherency_rgb_tw").."範圍內的隊友生效。",
	},
	--[+ AURA 3 - Breaking Dissent +]--	26.03.2026
	["loc_talent_adamant_damage_vs_staggered_aura_alt_desc"] = { -- damage_vs_stagger: +10%, +colors
		en = Dot_green.." {damage_vs_stagger:%s} "..CKWord("Damage", "Damage_rgb").." vs "..CKWord("Staggered", "Staggered_rgb").." for you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".",
		ru = Dot_green.." {damage_vs_stagger:%s} к "..CKWord("урону", "uronu_rgb_ru").." по "..CKWord("ошеломлённым", "oshelomlennym_rgb_ru").." врагам для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".", -- Подавление инакомыслия -- руоф Преодоление разногласий
		["zh-tw"] = Dot_green.." {damage_vs_stagger:%s} 對"..CKWord("踉蹌", "Staggered_rgb_tw").."敵人的"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."對你與"..CKWord("協同", "Coherency_rgb_tw").."範圍內的隊友生效。",
	},
--[+ +ABILITIES - СПОСОБНОСТЬ+ +]--
	--[+ ABILITY 0 - Nuncio-Aquila +]--	26.03.2026
	["loc_talent_adamant_ability_nuncio_base_desc"] = { -- range: 7.5, toughness: 5%, damage_taken: +15%, duration: 20, cooldown: 60, m->meters, s->seconds, +colors
		en = "Deploy a {talent_name:%s} in a target direction that buffs Allies and debuffs Enemies within {range:%s} meters.\n"
			.."\n"
			.."Allies:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." per second.\n"
			.."\n"
			.."Enemies:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("Damage", "Damage_rgb").." Taken.\n"
			.."\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			..Dot_nc.." Cooldown {cooldown:%s} seconds.",
		ru = "Вы развёртываете "..CKWord("Нунцио-аквилу", "Nuncio_akvilu_rgb_ru").." в выбранном направлении, усиливая союзников и ослабляя врагов в радиусе {range:%s} метров.\n"
			.."\n"
			.."Усиление союзников:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается в секунду.\n"
			.."\n"
			.."Ослабление врагов:\n"
			..Dot_green.." {damage_taken:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунд.", -- Нунцио-аквила
		["zh-tw"] = "在指定方向部署 {talent_name:%s}，\n"
			.."對 {range:%s} 米範圍內的隊友提供增益，\n"
			.."對敵人施加減益。\n"
			.."\n"
			.."隊友：\n"
			..Dot_green.." 每秒恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			.."敵人：\n"
			..Dot_green.." 受到的"..CKWord("傷害", "Damage_rgb_tw").."增加 {damage_taken:%s}。\n"
			.."\n"
			..Dot_nc.." 持續 {duration:%s} 秒。\n"
			..Dot_nc.." 冷卻時間 {cooldown:%s} 秒。",
	},
	--[+ ABILITY 1 - Castigator's Stance +]--	26.03.2026
	["loc_talent_adamant_stance_ability_power_description"] = { -- talent_name: Castigator's Stance, duration: 10, strength: +20%, movement_speed: +15%, damage_taken: +70%, movement_reduction: 100%, cooldown: 50, s->seconds, +colors
		en = "Enter the {talent_name:%s} for {duration:%s} seconds, during which you have:\n"
			..Dot_green.." {strength:%s} "..CKWord("Strength", "Strength_rgb")..",\n"
			..Dot_green.." {movement_speed:%s} Movement Speed,\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_taken:%s} "..CKWord("Damage", "Damage_rgb").." Taken,\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{movement_reduction:%s} Movement Speed Penalty from Actions.\n"
			..Dot_green.." On activation you replenish all "..CKWord("Toughness", "Toughness_rgb")..".\n"
			..Dot_red.." You cannot Sprint.\n"
			.."\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.",
		ru = "Вы входите в "..CKWord("Стойку бичевателя", "Stojku_bicha_rgb_ru").." на {duration:%s} секунд, во время которой вы получаете:\n"
			..Dot_green.." {strength:%s} к "..CKWord("силе", "sile_rgb_ru")..",\n"
			..Dot_green.." {movement_speed:%s} к скорости движения,\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_taken:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{movement_reduction:%s} штрафа скорости движения от действий.\n"
			..Dot_green.." При активации восстанавливается вся "..CKWord("стойкость", "stoikost_rgb_ru")..".\n"
			..Dot_red.." Вы не можете бегать.\n"
			.."\n"
			..Dot_nc.." Базовое восстановление: {cooldown:%s} секунд.", -- Стойка карателя -- руоф Стойка бичевателя
		["zh-tw"] = "進入 {talent_name:%s} 狀態 {duration:%s} 秒，\n"
			.."期間獲得：\n"
			..Dot_green.." {strength:%s} "..CKWord("威力", "Strength_rgb_tw").."，\n"
			..Dot_green.." {movement_speed:%s} 移動速度，\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").." {damage_taken:%s} 受到的"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").." {movement_reduction:%s} 行動時移動速度懲罰。\n"
			..Dot_green.." 啟動時完全恢復"..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			..Dot_red.." 無法衝刺。\n"
			.."\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。",
	},
	--[+ ABILITY 1-1 - Blessed Armament +]--	26.03.2026
	["loc_talent_adamant_stance_ranged_kills_transfer_ammo_no_cd_desc"] = { -- stance_name: Castigator's Stance, ammo: 10%, s->seconds
		en = "During {stance_name:%s}, Ranged Kills replenish:\n"
			..Dot_green.." Up to {ammo:%s} of the total Ammo in your Clip from Reserve.\n"
			..Dot_green.." Rounded Up.\n"
			..Dot_nc.." Can occur once per Attack.",
		ru = "Во время действия таланта {stance_name:%s} убийства дальнобойными атаками восстанавливают:\n"
			..Dot_green.." До {ammo:%s} общего количества боеприпасов в магазине из резерва.\n"
			..Dot_green.." Округляется в большую сторону.\n"
			..Dot_nc.." Срабатывает раз за атаку.", -- Благословенное вооружение -- руоф Благословенное орудие
		["zh-tw"] = "在 {stance_name:%s} 期間，遠程擊殺可恢復彈藥：\n"
			..Dot_green.." 最多 {ammo:%s} 的備用彈藥至彈夾。\n"
			..Dot_green.." 向上取整計算。\n"
			..Dot_nc.." 每次攻擊最多觸發一次。",
	},
	--[+ ABILITY 1-2 - Writ of Execution +]--	26.03.2026
	["loc_talent_adamant_stance_elite_kills_stack_damage_desc"] = { -- stance_name: Castigator's Stance, damage: +7.5%, duration: 12, stacks: 6, s->seconds, +colors
		en = "During {stance_name:%s}, each Elite or Specialist Kill grants:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Maximum {stacks:%s} Stacks.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "Во время действия таланта {stance_name:%s} каждое убийство элитного врага или специалиста даёт:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			..Dot_nc.." Максимум {stacks:%s} зарядов.\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Ордер на казнь
		["zh-tw"] = "在 {stance_name:%s} 期間，\n"
			.."每次擊殺精英或專家可獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."。\n"
			..Dot_nc.." 最大 {stacks:%s} 層。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ ABILITY 1-3 - Bloodlust +]--	26.03.2026
	["loc_talent_adamant_stance_bloodlust_desc"] = { -- stance_name: Castigator's Stance, damage: +75%, +colors
		en = "During {stance_name:%s} your Cyber-Mastiff has:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "Во время действия таланта {stance_name:%s} ваш кибермастиф получает:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".", -- Жажда крови
		["zh-tw"] = "在 {stance_name:%s} 期間，\n"
			.."你的電子獒犬獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ ABILITY 2 - Nuncio-Aquila +]--	26.03.2026
	["loc_talent_ability_area_buff_drone_improved_description"] = { -- range: 7.5, toughness: 7.5%, suppression: +30%, impact: +30%, recoil: -25%, damage_taken: +15%, duration: 20, cooldown: 60, nuncio_name: Nuncio-Aquila, m->meters, s->seconds, +colors
		en = "Deploy a {nuncio_name:%s} in a target direction that buffs Allies and debuffs Enemies within {range:%s} meters.\n"
			.."\n"
			.."Allies:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." per second,\n"
			..Dot_green.." {suppression:%s} Suppression Dealt,\n"
			..Dot_green.." {impact:%s} "..CKWord("Impact", "Impact_rgb")..",\n"
			..Dot_green.." {recoil:%s} Recoil,\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity,\n"
			..Dot_green.." Slowdown Immunity,\n"
			..Dot_green.." Suppression Immunity.\n"
			.."\n"
			.."Enemies:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("Damage", "Damage_rgb").." Taken.\n"
			.."\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			..Dot_nc.." Cooldown: {cooldown:%s} seconds.\n"
			..Dot_green.." This is an augmented version of {nuncio_name:%s}.",
		ru = "Вы развёртываете "..CKWord("Нунцио-аквилу", "Nuncio_akvilu_rgb_ru").." в выбранном направлении, усиливая союзников и ослабляя врагов в радиусе {range:%s} метров.\n"
			.."\n"
			.."Усиления союзников:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается в секунду,\n"
			..Dot_green.." {suppression:%s} к подавлению врагов,\n"
			..Dot_green.." {impact:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru")..",\n"
			..Dot_green.." {recoil:%s} к отдаче оружия,\n"
			..Dot_green.." Иммунитет к замедлению,\n"
			..Dot_green.." Иммунитет к подавлению,\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru")..".\n"
			.."\n"
			.."Ослабление врагов:\n"
			..Dot_green.." {damage_taken:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунд.\n"
			..Dot_green.." Это улучшенная версия способности {nuncio_name:%s}.", -- Нунцио-аквила
		["zh-tw"] = "在指定方向部署 {nuncio_name:%s}，\n"
			.."對 {range:%s} 米範圍內的隊友提供增益，\n"
			.."對敵人施加減益。\n"
			.."\n"
			.."隊友：\n"
			..Dot_green.." 每秒恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."，\n"
			..Dot_green.." {suppression:%s} 壓制效果，\n"
			..Dot_green.." {impact:%s} "..CKWord("衝擊", "Impact_rgb_tw").."，\n"
			..Dot_green.." {recoil:%s} 後座力，\n"
			..Dot_green.." "..CKWord("眩暈", "Stun_rgb_tw").."免疫，\n"
			..Dot_green.." 減速免疫，\n"
			..Dot_green.." 壓制免疫。\n"
			.."\n"
			.."敵人：\n"
			..Dot_green.." 受到的"..CKWord("傷害", "Damage_rgb_tw").."增加 {damage_taken:%s}。\n"
			.."\n"
			..Dot_nc.." 持續 {duration:%s} 秒。\n"
			..Dot_nc.." 冷卻：{cooldown:%s} 秒。\n"
			..Dot_green.." 此為 {nuncio_name:%s} 的強化版本。",
	},
	--[+ ABILITY 2-1 - Inspiring Recitation +]--	26.03.2026
	["loc_talent_adamant_drone_buff_talent_alt_desc"] = { -- tdr: 30%, revive_speed: 30%, attack_speed: 10%, +colors
		en ="Affected Allies also gain:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..",\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{revive_speed:%s} Revive Speed and\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{attack_speed:%s} Attack Speed." ,
		ru = "Затронутые союзники также получают:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..",\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{revive_speed:%s} к скорости оживления и\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{attack_speed:%s} к скорости атаки.", -- Воодушевляющая проповедь -- руоф Вдохновляющая декламация
		["zh-tw"] = "受影響的隊友還額外獲得：\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."，\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {revive_speed:%s} 急救速度，\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {attack_speed:%s} 攻擊速度。",
	},
	--[+ ABILITY 2-2 - Fear of Justice +]--	26.03.2026
	["loc_talent_adamant_drone_debuff_talent_desc"] = { -- damage_reduction: 25%, attack_speed_reduction: 50%, +colors
		en = "Affected enemies also gain debuffs to their Melee Attacks:\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_reduction:%s} "..CKWord("Damage", "Damage_rgb")..",\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{attack_speed_reduction:%s} time between attacks.",
		ru = "Затронутые враги также получают ослабления для их атак ближнего боя:\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_reduction:%s} к "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{attack_speed_reduction:%s} к увеличению времени между атаками.", -- Страх перед Правосудием -- руоф Страх правосудия
		["zh-tw"] = "受影響的敵人的近戰攻擊還受到以下減益：\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").." {damage_reduction:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {attack_speed_reduction:%s} 攻擊間隔時間。",
	},
	--[+ ABILITY 3 - Break the Line +]--	26.03.2026
	["loc_ability_adamant_charge_blocking_desc"] = { -- damage: +25%, stagger: +50%, duration: 6, cooldown: 20, s->seconds, +colors
		en = "Charge forward and Bash, causing high "..CKWord("Stagger", "Stagger_rgb").." to enemies in front of you, and gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..",\n"
			..Dot_green.." {stagger:%s} "..CKWord("Impact", "Impact_rgb")..".\n"
			.."\n"
			..Dot_green.." During the Bash you count as Blocking.\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.",
		ru = "Вы делаете рывок вперёд и наносите удар, сильно "..CKWord("ошеломляющий", "oshelomlauschij_rgb_ru").." врагов перед вами, и получаете на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." {stagger:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." Во время рывка вы находитесь в состоянии блокирования.\n"
			..Dot_nc.." Базовое восстановление: {cooldown:%s} секунд.", -- Прорыв строя -- руоф Прорыв фронта
		["zh-tw"] = "向前衝刺並猛擊，\n"
			.."對前方敵人造成大量"..CKWord("踉蹌", "Stagger_rgb_tw").."，\n"
			.."並在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {stagger:%s} "..CKWord("衝擊", "Impact_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 衝撞期間視為格擋狀態。\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。",
	},
	--[+ ABILITY 3-1 - Commendation from Condemnation +]--	26.03.2026
	["loc_talent_adamant_charge_toughness_alt_description"] = { -- toughness: 20%, stamina: 15%, toughness_max: 100%, stamina_max: 75%, +colors
		en = "For each Elite, Specialist, or Monstrosity hit you replenish:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." and\n"
			..Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb")..".\n"
			.."Up to {toughness_max:%s} "..CKWord("Toughness", "Toughness_rgb").." and {stamina_max:%s} "..CKWord("Stamina", "Stamina_rgb")..".",
		ru = "За каждого элитного врага, специалиста или чудовища, поражённого рывком, восстанавливается:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." и\n"
			..Dot_green.." {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".\n"
			.."Вплоть до {toughness_max:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." и {stamina_max:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".", -- Похвала за осуждение -- руоф Не наказали - значит, похвалили???
		["zh-tw"] = "每命中一名精英、專家或巨獸，恢復：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."，\n"
			..Dot_green.." {stamina:%s} "..CKWord("耐力", "Stamina_rgb_tw").."。\n"
			.."上限：{toughness_max:%s} "..CKWord("韌性", "Toughness_rgb_tw").." 與 {stamina_max:%s} "..CKWord("耐力", "Stamina_rgb_tw").."。",
	},
	--[+ ABILITY 3-2 - Targeted Brutality +]--	26.03.2026
	["loc_talent_adamant_charge_cooldown_alt_description"] = { -- cooldown: 0.5, cooldown_elite: 1, max_cooldown: 5, s->seconds, +colors
		en = "At charge end, reduce "..CKWord("Cooldown", "Cd_rgb").." of your "..CKWord("Break the Line", "BreakZLine_rgb").." per hit during charge:\n"
			..Dot_green.." {cooldown_elite:%s} second per Elite/Specialist/Monstrosity,\n"
			..Dot_green.." {cooldown:%s} seconds per other enemy.\n"
			..Dot_nc.." Max reduction: {max_cooldown} seconds.",
		ru = "После рывка, сокращается время "..CKWord("восстановления", "vosstanovlenia_rgb_ru").." вашего "..CKWord("Прорыва вражеского строя", "BreakZLine_rgb_ru").." на:\n" -- Направленная жестокость
			..Dot_green.." {cooldown_elite:%s} секунду за каждого, поражённого рывком, элитного врага, специалиста или чудовища,\n"
			..Dot_green.." {cooldown:%s} секунды за каждого, поражённого рывком, обычного врага.\n"
			..Dot_nc.." Максимум {max_cooldown:%s} секунд за рывок.",
		["zh-tw"] = "衝刺結束後，依衝刺期間的命中數量\n"
			.."減少"..CKWord("突破防線", "BreakZLine_rgb_tw").." 的"..CKWord("冷卻", "Cd_rgb_tw").."時間：\n"
			..Dot_green.." 精英/專家/巨獸：每名減少 {cooldown_elite:%s} 秒，\n"
			..Dot_green.." 其他敵人：每名減少 {cooldown:%s} 秒。\n"
			..Dot_nc.." 最大減少量：{max_cooldown} 秒。",
	},
	--[+ ABILITY 3-3 - Kill Order +]--	26.03.2026
	["loc_talent_adamant_dog_damage_after_ability_desc"] = { -- companion_damage: +50%, duration: 12, s->seconds, +colors
		en = "After using your "..CKWord("Combat Ability", "Cmbt_abil_rgb").." your Cyber-Mastiff gain for {duration:%s} seconds:\n"
			..Dot_green.." {companion_damage:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "После использования вашей "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." ваш кибермастиф получает на {duration:%s} секунд:\n"
			..Dot_green.." {companion_damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".", -- Фас! -- руоф Приказ убивать
		["zh-tw"] = "使用"..CKWord("戰鬥技能", "Cmbt_abil_rgb_tw").." 後，\n"
			.."你的電子獒犬在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {companion_damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ ABILITY 3-4 - Engage +]--	26.03.2026
	["loc_talent_adamant_charge_longer_distance_desc"] = { -- charge_ability_name: Break the Line, distance: 7.5, m->meters
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{distance:%s} meters to the distance of {charge_ability_name:%s}.",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{distance:%s} метров к расстоянию способности {charge_ability_name:%s}.", -- Дальний прорыв -- руоф К бою
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").." {distance:%s} 米至 {charge_ability_name:%s} 的距離。",
	},
--[+ +KEYSTONES - КЛЮЧЕВОЙ ТАЛАНТ+ +]--
	--[+ KEYSTONE 1 - Unleashed Brutality +]--
	["loc_talent_adamant_cyber_mastiff_elites_desc"] = { -- damage: +25%, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." to Elite and Specialist Enemies dealt by your Cyber-Mastiff.\n"
			.."\n"
			.."Elite and Specialist Enemies become its Primary targets.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." элитным врагам и специалистам для вашего кибермастифа.\n"
			.."\n"
			.."Элитные враги и специалисты становятся его приоритетными целями.", -- Высвобожденнная жестокость
		["zh-tw"] = Dot_green.." {damage:%s} 電子獒犬對精英和專家的"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."精英和專家成為其優先目標。",
	},
	--[+ KEYSTONE 2 - Lone Wolf +]--
	["loc_talent_adamant_disable_companion_replenish_split_desc"] = { -- damage: +10%, attack_speed: +10%, tdr: +15%, charges: +1, time: 60, s->seconds, +colors
		en = "You are no longer accompanied by your Cyber-Mastiff, but gain:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..",\n"
			..Dot_green.." {attack_speed:%s} Attack Speed,\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			.."Blitz Ability:\n"
			..Dot_green.." {charges:%s} max charge.\n"
			..Dot_green.." "..CNumb("1", "n_1_rgb").." charge replenished every:\n"
			.."    "..Dot_green.." {grenade_time:%s} seconds - {grenade_blitz_name:%s},\n"
			.."    "..Dot_green.." {time_shock_mine:%s} seconds - {shock_mine_name:%s}.",
		ru = "Вам больше не помогает кибермастиф, но вы получаете:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки,\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Усиление Блица:\n"
			..Dot_green.." {charges:%s} заряд.\n"
			..Dot_green.." "..CNumb("1", "n_1_rgb").." заряд восстанавливается каждые:\n"
			.."    "..Dot_green.." {grenade_time:%s} секунд - {grenade_blitz_name:%s},\n"
			.."    "..Dot_green.." {time_shock_mine:%s} секунд - {shock_mine_name:%s}.", -- Одинокий волк
		["zh-tw"] = "你不再有電子獒犬陟同，但獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度，\n"
			..Dot_green.." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."。\n"
			.."\n"
			.."閃擊技能：\n"
			..Dot_green.." {charges:%s} 最大充能。\n"
			..Dot_green.." "..CNumb("1", "n_1_rgb").." 充能恢復間隔：\n"
			.."    "..Dot_green.." {grenade_time:%s} 秒 - {grenade_blitz_name:%s}，\n"
			.."    "..Dot_green.." {time_shock_mine:%s} 秒 - {shock_mine_name:%s}。",
	},
	--[+ KEYSTONE 3 - Go Get 'Em! +]--
	["loc_talent_adamant_cyber_mastiff_ranged_desc"] = { -- !damage!: +50%, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." to Ranged Enemies dealt by your Cyber-Mastiff.\n"
			.."\n"
			.."Ranged Enemies become its Primary targets.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." дальнобойным врагам для вашего кибермастифа.\n"
			.."\n"
			.."Дальнобойные враги становятся его приоритетными целями.", -- Взять их!
		["zh-tw"] = Dot_green.." {damage:%s} 電子獒犬對遠程敵人的"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."遠程敵人成為其優先目標。",
	},
	--[+ KEYSTONE 4 - Execution Order +]--
	["loc_talent_execution_order_description"] = { -- toughness: 15%, dog_damage: +150%, time: 8, damage: +10%, attack_speed: +10%, s->seconds, +colors
		en = "Periodically mark Elites, Specialists and Bosses for Mercy Sanction. Killing a "..CKWord("Marked Enemy", "Markedenemy_rgb").." replenishes:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			.."Your Cyber-Mastiff gains for {time:%s} seconds after attacking a "..CKWord("Marked Enemy", "Markedenemy_rgb")..":\n"
			..Dot_green.." {dog_damage:%s} Cyber-Mastiff "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."You gain for {time:%s} seconds after killing a "..CKWord("Marked Enemy", "Markedenemy_rgb")..":\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {attack_speed:%s} Attack Speed.",
		ru = "Периодически вы помечаете элитных врагов, специалистов и боссов для Санкции милосердия. Убийство "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru").." восстанавливает:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Ваш кибермастиф получает на {time:%s} секунд после атаки "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru")..":\n"
			..Dot_green.." {dog_damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."Вы получаете на {time:%s} секунд после убийства "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru")..":\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки.", -- Метка возмездия -- Приказ казнить
		["zh-tw"] = "定期為精英、專家和隊長標上「仁慈制裁」。\n"
			.."擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 可恢復：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			.."攻擊"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 後，\n"
			.."電子獒犬在 {time:%s} 秒內獲得：\n"
			..Dot_green.." {dog_damage:%s} 電子獒犬"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 後，\n"
			.."你在 {time:%s} 秒內獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度。",
	},
	--[+ KEYSTONE 4-1 - Efficient Killer +]--
	["loc_talent_execution_order_crit_description"] = { -- crit_chance: +10%, crit_damage: +25%, time: 8, s->seconds, +colors
		en = "On killing a "..CKWord("Marked Enemy", "Markedenemy_rgb")..", you gain:\n"
			..Dot_green.." {crit_chance:%s} "..CKWord("Crit Chance", "Crt_chance_rgb").." and\n"
			..Dot_green.." {crit_damage:%s} "..CKWord("Crit Damage", "Crt_dmg_r_rgb")..".\n"
			..Dot_nc.." Lasts {time:%s} seconds.",
		ru = "При убийстве "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru").." вы получаете:\n"
			..Dot_green.." {crit_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru").." и\n"
			..Dot_green.." {crit_damage:%s} к "..CKWord("критическому урону", "krit_uronu_rgb_ru")..".\n"
			..Dot_nc.." Длится {time:%s} секунд.", -- Эффективный убийца
		["zh-tw"] = "擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 後，你獲得：\n"
			..Dot_green.." {crit_chance:%s} "..CKWord("暴擊機率", "Crt_chance_rgb_tw").."，\n"
			..Dot_green.." {crit_damage:%s} "..CKWord("暴擊傷害", "Crt_dmg_r_rgb_tw").."。\n"
			..Dot_nc.." 持續 {time:%s} 秒。",
	},
	--[+ KEYSTONE 4-2 - Malocator +]--
	["loc_talent_execution_order_cdr_on_kill_description"] = { -- regen: +50%, time: 8, s->seconds, +colors
		en = Dot_green.." {regen:%s} "..CKWord("Cooldown", "Cd_rgb").." Regeneration for {time:%s} seconds after killing a "..CKWord("Marked Enemy", "Markedenemy_rgb")..".",
		ru = Dot_green.." {regen:%s} к "..CKWord("восстановлению способности", "vost_sposobnosti_rgb_ru").." на {time:%s} секунд после убийства "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru")..".", -- Малокатор
		["zh-tw"] = Dot_green.." 擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 後 {time:%s} 秒內，\n"
			.."{regen:%s} "..CKWord("冷卻", "Cd_rgb_tw").."恢復速度。",
	},
	--[+ KEYSTONE 4-3 - No Lenience +]--
	["loc_talent_execution_order_command_applies_brittleness_description"] = { -- rending: +10%, time: 8, s->seconds, +colors
		en = Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb").." for {time:%s} seconds after killing a "..CKWord("Marked Enemy", "Markedenemy_rgb")..".",
		ru = Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони на {time:%s} секунд после убийства "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru")..".", -- Нетерпимость
		["zh-tw"] = Dot_green.." 擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 後 {time:%s} 秒內，\n"
			.."{rending:%s} "..CKWord("撕裂", "Rending_rgb_tw").."。",
	},
	--[+ KEYSTONE 4-4 - Keeping Protocol +]--
	["loc_talent_execution_order_perma_buff_new_description"] = { -- damage: +1%, damage_red: +1%, max_stacks: 30, +colors
		en = "Killing a "..CKWord("Marked Enemy", "Markedenemy_rgb").." grants:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." vs Monstrosities and\n"
			..Dot_green.." {damage_red:%s} "..CKWord("Damage", "Damage_rgb").." Resistance vs Monstrosities.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Lasts until the end of the Mission.",
		ru = "Убийство "..CKWord("Отмеченного врага", "Markedenemy_rgb_ru").." даёт:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." чудовищам и\n"
			..Dot_green.." {damage_red:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." от чудовищ.\n"
			..Dot_nc.." Максимум {max_stacks:%s} зарядов.\n"
			..Dot_nc.." Длится до конца миссии.", -- Соблюдение протокола -- руоф Поддердание протокола
		["zh-tw"] = "擊殺"..CKWord("標記敵人", "Markedenemy_rgb_tw").." 可獲得：\n"
			..Dot_green.." {damage:%s} 對巨獸的"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {damage_red:%s} 對巨獸的"..CKWord("傷害", "Damage_rgb_tw").."抗性。\n"
			..Dot_nc.." 最多疊加 {max_stacks:%s} 次。\n"
			..Dot_nc.." 持續至任務結束。",
	},
	--[+ KEYSTONE 4-5 - Not Far Behind +]--
	["loc_talent_adamant_pinning_dog_bonus_moving_towards_description"] = { -- movement_speed: +10%, damage: +10%, time: 5, s->seconds, +colors
		en = "After Pounce you gain for {time:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {movement_speed:%s} Movement Speed.",
		ru = "После нападения вашего кибермастифа на врага вы получаете на {time:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {movement_speed:%s} к скорости движения.", -- В зоне досягаемости -- руоф Не так далеко позади
		["zh-tw"] = "電子獒犬撲倒敵人後，\n"
			.."你在 {time:%s} 秒內獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {movement_speed:%s} 移動速度。",
	},
	--[+ KEYSTONE 5 - Terminus Warrant +]--	26.03.2026
	["loc_talent_adamant_terminus_warrant_new_desc"] = { -- max_stacks: 20, weakspot_stacks: 3, melee_duration: 12, melee_strength: +10%, tdr: +20%, ranged_duration: 12, ranged_strength: +10%, ranged_cleave: +50%, suppression: +50%, +colors
		en = "Ranged Attacks grant Stacks of "..CKWord("Melee Justice", "Meleejust_rgb")..".\n"
			..Dot_nc.." Up to {max_stacks:%s} Stacks.\n"
			..Dot_nc.." Stacks have no duration.\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." Stack per Enemy Hit.\n"
			..Dot_green.." {weakspot_stacks:%s} Stacks per "..CKWord("Weakspot hit", "Weakspothit_rgb")..".\n"
			.."\n"
			.."Wielding your Primary Weapon spends your "..CKWord("Melee Justice", "Meleejust_rgb").." Stacks to grant you for {melee_duration:%s} seconds:\n"
			..Dot_green.." {melee_strength:%s} Melee "..CKWord("Strength", "Strength_rgb").." and\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			.."Melee Hits grant Stacks of "..CKWord("Ranged Justice", "Rangedjust_rgb")..".\n"
			..Dot_nc.." Up to {max_stacks:%s} Stacks.\n"
			..Dot_nc.." Stacks have no duration.\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." Stack per Enemy Hit.\n"
			..Dot_red.." Cyber-Mastiff attacks do not count.\n"
			.."\n"
			.."Wielding your Secondary Weapon spends your "..CKWord("Ranged Justice", "Rangedjust_rgb").." Stacks to grant you for {ranged_duration:%s} seconds:\n"
			..Dot_green.." {ranged_strength:%s} Ranged "..CKWord("Strength", "Strength_rgb")..",\n"
			..Dot_green.." {ranged_cleave:%s} Ranged "..CKWord("Cleave", "Cleave_rgb").." and\n"
			..Dot_green.." {suppression:%s} Suppression.\n"
			.."\n"
			..CNote("Pwr_note"),
		ru = "Дальнобойные атаки дают заряды "..CKWord("Судьи-рукопашника", "Meleejust_rgb_ru")..".\n"
			..Dot_nc.." До {max_stacks:%s} зарядов.\n"
			..Dot_nc.." У этих зарядов нет длительности.\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." заряд за попадание по врагу.\n"
			..Dot_green.." {weakspot_stacks:%s} заряда за попадание в "..CKWord("уязвимое место", "ujazvimoe_mesto_rgb_ru")..".\n"
			.."\n"
			.."При выборе оружия ближнего боя вы тратите заряды "..CKWord("Судьи-рукопашника", "Meleejust_rgb_ru").." и получаете на {melee_duration:%s} секунд:\n"
			..Dot_green.." {melee_strength:%s} к "..CKWord("силе", "sile_rgb_ru").." атак ближнего боя и\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Удары ближнего боя дают заряды "..CKWord("Судьи-стрелка", "Rangedjust_rgb_ru")..".\n"
			..Dot_nc.." До {max_stacks:%s} зарядов.\n"
			..Dot_nc.." У этих зарядов нет длительности.\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." заряд за попадание по врагу.\n"
			..Dot_red.." Атаки кибермастифа не учитываются.\n"
			.."\n"
			.."При выборе оружия дальнего боя вы тратите заряды "..CKWord("Судьи-стрелка", "Rangedjust_rgb_ru").." и получаете на {ranged_duration:%s} секунд:\n"
			..Dot_green.." {ranged_strength:%s} к "..CKWord("силе", "sile_rgb_ru").." атак дальнего боя,\n"
			..Dot_green.." {ranged_cleave:%s} к "..CKWord("прострелу", "prostrelu_rgb_ru").." врагов и\n"
			..Dot_green.." {suppression:%s} к подавлению врагов.\n"
			.."\n"
			..CNote("Pwr_note"), -- Ордер Терминус -- руоф Распоряжение «Терминус»
		["zh-tw"] = "遠程攻擊累積"..CKWord("近戰正義", "Meleejust_rgb_tw").."層數。\n"
			..Dot_nc.." 最多 {max_stacks:%s} 層。\n"
			..Dot_nc.." 層數無持續時間。\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." 層/命中。\n"
			..Dot_green.." "..CKWord("命中弱點", "Weakspothit_rgb_tw").." 得 {weakspot_stacks:%s} 層。\n"
			.."\n"
			.."切換至主武器時，消耗"..CKWord("近戰正義", "Meleejust_rgb_tw").."層數，\n"
			.." 在 {melee_duration:%s} 秒內獲得：\n"
			..Dot_green.." {melee_strength:%s} 近戰"..CKWord("威力", "Strength_rgb_tw").."，\n"
			..Dot_green.." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."。\n"
			.."\n"
			.."近戰命中累積"..CKWord("遠程正義", "Rangedjust_rgb_tw").."層數。\n"
			..Dot_nc.." 最多 {max_stacks:%s} 層。\n"
			..Dot_nc.." 層數無持續時間。\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." 層/命中。\n"
			..Dot_red.." 電子獒犬的攻擊不計入。\n"
			.."\n"
			.."切換至副武器時，消耗"..CKWord("遠程正義", "Rangedjust_rgb_tw").."層數，\n"
			.." 在 {ranged_duration:%s} 秒內獲得：\n"
			..Dot_green.." {ranged_strength:%s} 遠程"..CKWord("威力", "Strength_rgb_tw").."，\n"
			..Dot_green.." {ranged_cleave:%s} 遠程"..CKWord("順劈攻擊", "Cleave_rgb_tw").."，\n"
			..Dot_green.." {suppression:%s} 壓制效果。\n"
			.."\n"
			..CNote("Pwr_note"),
	},
	--[+ KEYSTONE 5-1 - Obstinate +]--	26.03.2026
	["loc_talent_adamant_terminus_warrant_cdr_desc"] = { -- stacks: 20, cdr: +33%, duration: 12, +colors
		en = "Spending {stacks:%s} Stacks grants you for {duration:%s} seconds:\n"
			..Dot_green.." {cdr:%s} "..CKWord("Ability Cooldown", "Ability_cd_rgb").." Regeneration.",
		ru = "Потратив {stacks:%s} зарядов вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {cdr:%s} "..CKWord("восстановления способности", "vost_sposobnosti_rgb_ru")..".", -- Непреклонный -- руоф Упрямый
		["zh-tw"] = "消耗 {stacks:%s} 層後，\n"
			.."在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {cdr:%s} "..CKWord("技能冷卻", "Ability_cd_rgb_tw").."恢復速度。",
	},
	--[+ KEYSTONE 5-2 - Terminal Decree +]--	26.03.2026
	["loc_talent_adamant_terminus_warrant_support_desc"] = { -- toughness: 1%, +colors
		en = "You and Allies in "..CKWord("Coherency", "Coherency_rgb").." replenish per Stack you spend:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_nc.." Up to "..CNumb("20", "pc_20_rgb").." "..CKWord("Toughness", "Toughness_rgb")..".",
		ru = "Вы и союзники в "..CKWord("сплочённости", "splochennosti_rgb_ru").." восстанавливаете за каждый потраченный вами заряд:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Вплоть до "..CNumb("20", "pc_20_rgb").." "..CKWord("Toughness", "Toughness_rgb")..".", -- Последний приговор -- руоф Окончательное постановление
		["zh-tw"] = "你與"..CKWord("協同", "Coherency_rgb_tw").."範圍內的隊友，\n"
			.."每消耗一層可恢復：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 最多恢復 "..CNumb("20", "pc_20_rgb").." "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ KEYSTONE 5-3 - Writ of Judgement +]--	26.03.2026
	["loc_talent_adamant_terminus_warrant_improved_combined_desc"] = { -- melee_stacks: 20, duration: 12, attack_speed: +10%, weakspot_damage: +10%, +colors
		en = "Spending {melee_stacks:%s} Stacks grants you for {duration:%s} seconds:\n"
			..Dot_green.." {attack_speed:%s} Attack Speed and\n"
			..Dot_green.." {crit_chance:%s} "..CKWord("Critical Hit Chance", "Crt_hit_chnc_rgb")..".",
		ru = "Потратив {melee_stacks:%s} зарядов вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки и\n"
			..Dot_green.." {crit_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru")..".", -- Судебный ордер -- руоф Судебное предписание
		["zh-tw"] = "消耗 {melee_stacks:%s} 層後，\n"
			.."在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度，\n"
			..Dot_green.." {crit_chance:%s} "..CKWord("暴擊命中機率", "Crt_hit_chnc_rgb_tw").."。",
	},
	--[+ KEYSTONE 6 - Forceful +]--	26.03.2026
	["loc_talent_adamant_forceful_base_alt_desc"] = { -- forceful_name: Forceful, duration: 5, stacks: 10, impact: +5%, dr: +2.5%, s->seconds, +colors
		en = CKWord("Staggering", "Staggering_rgb").." Hits and Blocked Attacks grant Stacks of "..CKWord("Forceful", "Forceful_rgb")..".\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			.."\n"
			.."Each Stack gives:\n"
			..Dot_green.." {impact:%s} "..CKWord("Impact", "Impact_rgb").." and\n"
			..Dot_green.." {dr:%s} "..CKWord("Damage", "Damage_rgb").." Resistance.\n"
			.."\n"
			..Dot_red.." Remove Stack on "..CKWord("Damage", "Damage_rgb").." taken.",
		ru = CKWord("Ошеломляющие", "Oshelomlauschie_rgb_ru").." удары и заблокированные атаки дают заряды "..CKWord("Неудержимости", "Forceful_rgb_ru")..".\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.\n"
			.."\n"
			.."Каждый заряд даёт:\n"
			..Dot_green.." {impact:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru").." и\n"
			..Dot_green.." {dr:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_red.." Заряды снимаются при получении "..CKWord("урона", "urona_rgb_ru")..".", -- Неудержимый -- руоф Напористый
		["zh-tw"] = CKWord("踉蹌", "Staggering_rgb_tw").." 命中與格擋攻擊，\n"
			.."累積"..CKWord("強力", "Forceful_rgb_tw").."層數。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。\n"
			..Dot_nc.." 最多疊加 {stacks:%s} 層。\n"
			.."\n"
			.."每層提供：\n"
			..Dot_green.." {impact:%s} "..CKWord("衝擊", "Impact_rgb_tw").."，\n"
			..Dot_green.." {dr:%s} "..CKWord("傷害", "Damage_rgb_tw").."抗性。\n"
			.."\n"
			..Dot_red.." 受到"..CKWord("傷害", "Damage_rgb_tw").."時移除一層。",
	},
	--[+ KEYSTONE 6-1 - Adamant Will +]--	26.03.2026
	["loc_talent_adamant_forceful_stun_immune_and_block_all_linger_desc"] = { -- duration: 3, s->seconds, +colors
		en = "While having "..CNumb("10", "n_10_rgb").." Stacks of "..CKWord("Forceful", "Forceful_rgb").." and for {duration:%s} seconds after dropping below "..CNumb("10", "n_10_rgb").." Stacks you gain:\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity and\n"
			..Dot_green.." Perfect blocks can block All Attacks.",
		ru = "Пока у вас "..CNumb("10", "n_10_rgb").." зарядов "..CKWord("Неудержимости", "Forceful_rgb_ru").." и на {duration:%s} секунды после того, как количество зарядов упадёт ниже "..CNumb("10", "n_10_rgb")..", вы получаете:\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru")..",\n"
			..Dot_green.." Идеальные блоки могут блокировать все атаки.", -- Адамантовая воля
		["zh-tw"] = "持有 "..CNumb("10", "n_10_rgb").." 層"..CKWord("強力", "Forceful_rgb_tw").."，\n"
			.."以及降至 "..CNumb("10", "n_10_rgb").." 層以下後 {duration:%s} 秒內，\n"
			.."你獲得：\n"
			..Dot_green.." "..CKWord("眩暈", "Stun_rgb_tw").."免疫，\n"
			..Dot_green.." 完美格擋可格擋所有攻擊。",
	},
	--[+ KEYSTONE 6-2 - Will of the Lex +]--	26.03.2026
	["loc_talent_adamant_forceful_toughness_regen_per_stack_desc"] = { -- toughness: +0.5%, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished each second per "..CKWord("Forceful", "Forceful_rgb").." Stack.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается каждую секунду за заряд "..CKWord("Неудержимости", "Forceful_rgb_ru")..".",
		["zh-tw"] = Dot_green.." 每層"..CKWord("強力", "Forceful_rgb_tw").."，\n"
			.."每秒恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ KEYSTONE 6-3 - Targets Acquired +]--	26.03.2026
	["loc_talent_adamant_forceful_melee_alt_desc"] = { -- duration: 3, attack_speed: +10%, cleave: +50%, s->seconds, +colors
		en = "While having "..CNumb("10", "n_10_rgb").." Stacks of "..CKWord("Forceful", "Forceful_rgb").." and for {duration:%s} seconds after dropping below "..CNumb("10", "n_10_rgb").." Stacks you gain:\n"
			..Dot_green.." {attack_speed:%s} Attack Speed and\n"
			..Dot_green.." {cleave:%s} "..CKWord("Cleave", "Cleave_rgb")..".",
		ru = "Пока у вас "..CNumb("10", "n_10_rgb").." зарядов "..CKWord("Неудержимости", "Forceful_rgb_ru").." и на {duration:%s} секунды после того, как количество зарядов упадёт ниже "..CNumb("10", "n_10_rgb")..", вы получаете:\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки и\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов.", -- Цели обнаружены
		["zh-tw"] = "持有 "..CNumb("10", "n_10_rgb").." 層"..CKWord("強力", "Forceful_rgb_tw").."，\n"
			.."以及降至 "..CNumb("10", "n_10_rgb").." 層以下後 {duration:%s} 秒內，\n"
			.."你獲得：\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度，\n"
			..Dot_green.." {cleave:%s} "..CKWord("順劈攻擊", "Cleave_rgb_tw").."。",
	},
	--[+ KEYSTONE 6-4 - Arbites Vigilant +]--	26.03.2026
	["loc_talent_adamant_forceful_ability_damage"] = { -- strength: +2.5%, duration: 10, s->seconds, +colors
		en = "On "..CKWord("Combat Ability", "Cmbt_abil_rgb").." use, you spend all Stacks and gain per Stack:\n"
			..Dot_green.." {strength:%s} "..CKWord("Strength", "Strength_rgb")..".\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "При использовании "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." вы тратите все заряды и получаете за каждый из них:\n"
			..Dot_green.." {strength:%s} к "..CKWord("силе", "sile_rgb_ru")..".\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Бдительный Арбитрес -- руоф Бдительность Арбитрес
		["zh-tw"] = "使用"..CKWord("戰鬥技能", "Cmbt_abil_rgb_tw").." 時，\n"
			.."消耗所有層數，每層獲得：\n"
			..Dot_green.." {strength:%s} "..CKWord("威力", "Strength_rgb_tw").."。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ KEYSTONE 6-5 - Judicial Force +]--	26.03.2026
	["loc_talent_adamant_forceful_stagger_on_low_high_desc"] = { -- low_stacks: 0, high_stacks: 10, cooldown: 5, s->seconds, +colors
		en = CKWord("Stagger", "Stagger_rgb").." nearby Enemies upon reaching {low_stacks:%s} Stacks or {high_stacks:%s} Stacks of "..CKWord("Forceful", "Forceful_rgb")..".\n"
			..Dot_nc.." Cooldown {cooldown:%s} seconds.\n"
			..Dot_nc.." Cooldown is separate for {low_stacks:%s} Stacks and for {high_stacks:%s} Stacks.",
		ru = "Вы "..CKWord("ошеломляете", "oshelomlaete_rgb_ru").." ближайших врагов при достижении вами {low_stacks:%s} или {high_stacks:%s} зарядов "..CKWord("Неудержимости", "Forceful_rgb_ru")..".\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунд.\n"
			..Dot_nc.." Восстановление раздельное для {low_stacks:%s} зарядов и для {high_stacks:%s} зарядов.", -- Сила правосудия -- руоф Судебная сила
		["zh-tw"] = CKWord("踉蹌", "Stagger_rgb_tw").." 附近敵人，\n"
			.."當"..CKWord("強力", "Forceful_rgb_tw").."層數達到 {low_stacks:%s} 或 {high_stacks:%s} 層時觸發。\n"
			..Dot_nc.." 冷卻時間 {cooldown:%s} 秒。\n"
			..Dot_nc.." {low_stacks:%s} 層與 {high_stacks:%s} 層的冷卻分開計算。",
	},
--[+ +PASSIVES - ПАССИВНЫЕ+ +]--
	--[+ Passive 1 - No Escape +]--	26.03.2026
	["loc_talent_adamant_elite_special_kills_offensive_boost_alt_desc"] = { -- damage: +10%, movement_speed: +10%, duration: 4, s->seconds, +colors
		en = "On Elite or Specialist Kill, gain:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {movement_speed:%s} Movement Speed.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "После убийства элитного врага или специалиста, вы получаете:\n" -- Не уйдёшь -- руоф Не сбежишь
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {movement_speed:%s} к скорости движения.\n"
			..Dot_nc.." Длится {duration:%s} секунды.",
		["zh-tw"] = "擊殺精英或專家後，獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {movement_speed:%s} 移動速度。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 2 - Withering Fire +]--	26.03.2026
	["loc_talent_adamant_damage_after_reloading_desc"] = { -- damage: +15%, duration: 5, s->seconds, +colors
		en = Dot_green.." {damage:%s} Ranged "..CKWord("Damage", "Damage_rgb").." for {duration:%s} seconds after Reloading.",
		ru = Dot_green.." {damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru").." на {duration:%s} секунд после перезарядки.", -- Истребляющий огонь -- Изнуряющий огонь
		["zh-tw"] = Dot_green.." 裝填後 {duration:%s} 秒內，\n"
			.."{damage:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 3 - Hammer of Judgement +]--	26.03.2026
	["loc_talent_adamant_multiple_hits_attack_speed_desc"] = { -- melee_attack_speed: +10%, duration: 3, hits: 3, s->seconds
		en = Dot_green.." {melee_attack_speed:%s} Melee Attack Speed for {duration:%s} seconds on hitting {hits:%s} or more enemies with a Melee Attack.",
		ru = Dot_green.." {melee_attack_speed:%s} к скорости атак ближнего боя на {duration:%s} секунды при попадании по {hits:%s} или более врагам атакой ближнего боя.", -- Молот Правосудия -- руоф Молот правосудия
		["zh-tw"] = Dot_green.." 近戰攻擊命中 {hits:%s} 名或更多敵人時，\n"
			.."{melee_attack_speed:%s} 近戰攻擊速度，\n"
			.."持續 {duration:%s} 秒。",
	},
	--[+ Passive 4 - Razor-Jaw Augment +]--	26.03.2026
	["loc_talent_adamant_dog_pounces_bleed_nearby_desc"] = { -- stacks: 8, +colors
		en = Dot_green.." {stacks:%s} Stacks of "..CKWord("Bleed", "Bleed_rgb").." applied to Enemies knocked away by your Cyber Mastiff's Pounce.",
		ru = Dot_green.." {stacks:%s} зарядов "..CKWord("кровотечения", "krovotechenia_rgb_ru").." применяется к врагам, опрокинутым вашим кибермастифом.", -- Аугментация челюсти-бритвы -- руоф Аугментация челюстей: бритва
		["zh-tw"] = Dot_green.." 電子獒犬撲倒並擊飛敵人時，\n"
			.."對其施加 {stacks:%s} 層"..CKWord("流血", "Bleed_rgb_tw").."。",
	},
	--[+ Passive 5 - Target Neutralised +]--
	["loc_talent_adamant_elite_special_kills_replenish_toughness_desc"] = { -- instant_toughness: 10%, toughness: 10%, duration: 4, s->seconds, +colors
		en = "On Elite or Specialist Kill you replenish:\n"
			..Dot_green.." {instant_toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." instantly and\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.",
		ru = "При убийстве элитного врага или специалиста вы восстанавливаете:\n"
			..Dot_green.." {instant_toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." мгновенно и\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.", -- Цель уничтожена -- руоф Цель нейтрализована
		["zh-tw"] = "擊殺精英或專家後，恢復：\n"
			..Dot_green.." {instant_toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."立即），\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."在 {duration:%s} 秒內）。",
	},
	--[+ Passive 6 - Up Close +]--	26.03.2026
	["loc_talent_adamant_close_kills_restore_toughness_desc"] = { -- toughness: 5%, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished after killing enemy within "..CNumb("12.5", "n_12_5_rgb").." meters.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается при убийстве на дистанции до "..CNumb("12.5", "n_12_5_rgb").." метров.", -- В упор -- руоф Лицом к лицу
		["zh-tw"] = Dot_green.." 在 "..CNumb("12.5", "n_12_5_rgb").." 米內擊殺敵人後，\n"
			.."恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 7 - Force of Will +]--	26.03.2026
	["loc_talent_adamant_staggers_replenish_toughness_melee_desc"] = { -- toughness: 10%, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished on "..CKWord("Staggering", "Staggering_rgb").." Melee Attack.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается при "..CKWord("ошеломлении", "oshelomlenii_rgb_ru").." врага атакой ближнего боя.", -- Сила воли
		["zh-tw"] = Dot_green.." 近戰攻擊使敵人"..CKWord("踉蹌", "Staggering_rgb_tw").." 時，\n"
			.."恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 8 - Retaliatory Force +]--	26.03.2026
	["loc_talent_adamant_perfect_block_damage_boost_alt_desc"] = { -- block_cost: 15%, damage: +15%, attack_speed: +15%, duration: 8, s->seconds, +colors
		en = Dot_green.." "..CNumb("-", "n_minus_rgb").."{block_cost:%s} Block Cost.\n"
			.."\n"
			.."On Perfect Block you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {attack_speed:%s} Attack Speed.",
		ru = Dot_green.." "..CNumb("-", "n_minus_rgb").."{block_cost:%s} затрат "..CKWord("выносливости", "vynoslivosti_rgb_ru").." на блок.\n" -- Сила возмездия
			.."\n"
			.."При идеальном блокировании вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки.",
		["zh-tw"] = Dot_green.." "..CNumb("-", "n_minus_rgb").." {block_cost:%s} 格擋消耗。\n"
			.."\n"
			.."完美格擋後 {duration:%s} 秒內，你獲得：\n"
			..Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度。",
	},
	--[+ Passive 9 - Man and Cyber-Mastiff +]--	26.03.2026
	["loc_talent_adamant_toughness_regen_near_companion_desc"] = { -- toughness: 5%, range: 8, m->meters, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished per second while Cyber-Mastiff is within {range:%s} meters of you.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается в секунду пока ваш кибермастиф в пределах {range:%s} метров от вас.", -- Человек и кибермастиф
		["zh-tw"] = Dot_green.." 電子獒犬在 {range:%s} 米範圍內時，\n"
			.."每秒恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 10 - Walk It Off +]--	26.03.2026
	["loc_talent_adamant_stamina_spent_replenish_toughness_desc"] = { -- stamina: 1, toughness: 15%, duration: 3, s->seconds, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished over {duration:%s} seconds per {stamina:%s} "..CKWord("Stamina", "Stamina_rgb").." spent.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается за {duration:%s} секунды за каждую единицу потраченной "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".", -- Заживёт на ходу -- руоф Остынь --{stamina:%s}
		["zh-tw"] = Dot_green.." 每消耗 {stamina:%s} "..CKWord("耐力", "Stamina_rgb_tw").."，\n"
			.."在 {duration:%s} 秒內恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 11 - Shield Plates +]--	26.03.2026
	["loc_talent_adamant_shield_plates_alt_desc"] = { -- toughness: 15%, duration: 3, perfect_toughness: 10%, cooldown: 1, s->second, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished over {duration:%s} seconds on successful Block.\n"
			.."\n"
			..Dot_green.." {perfect_toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." instantly replenished on Perfect Block.\n"
			.."\n"
			..Dot_nc.." Cooldown {cooldown:%s} second.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается за {duration:%s} секунды при успешном блоке.\n"
			.."\n"
			..Dot_green.." {perfect_toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." мгновенно восполняется при идеальном блоке.\n"
			.."\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунду.", -- Щитовые пластины -- руоф Пластинчатые щиты
		["zh-tw"] = Dot_green.." 成功格擋後，\n"
			.."{duration:%s} 秒內恢復 {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 完美格擋後，立即恢復 {perfect_toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 冷卻時間 {cooldown:%s} 秒。",
	},
	--[+ Passive 12 - Arbitrator Armour +]--	26.03.2026
	["loc_talent_adamant_armor_desc"] = { -- toughness: +25, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".", -- Броня арбитратора -- руоф Броня Арбитратора
		["zh-tw"] = Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 13 - Voltaic Mandibles Augment +]--	26.03.2026
	["loc_talent_adamant_dog_attacks_electrocute_desc"] = { -- duration: 5, s->seconds, +colors
		en = "Your Cyber-Mastiff "..CKWord("Electrocutes", "Electrocutes_rgb").." Enemies it attacks for {duration:%s} seconds.",
		ru = "Ваш кибермастиф поражает "..CKWord("электрошоком", "elektroshokom_rgb_ru").." врагов на {duration:%s} секунд при атаке.", -- Аугментация Вольтаические жвала -- руоф Аугментация челюстей: электрошок
		["zh-tw"] = "你的電子獒犬攻擊敵人時，\n"
			.."對其施加 {duration:%s} 秒"..CKWord("電擊", "Electrocutes_rgb_tw").."。",
	},
	--[+ Passive 14 - Ammo Belt +]--	26.03.2026
	["loc_talent_adamant_ammo_belt_desc"] = { -- ammo: +25%
		en = Dot_green.." {ammo:%s} Ammo Capacity.",
		ru = Dot_green.." {ammo:%s} к боезапасу.", -- Патронтаж -- руоф Поясная разгрузка
		["zh-tw"] = Dot_green.." {ammo:%s} 彈藥容量。",
	},
	--[+ Passive 15 - Concussive +]--	26.03.2026
	["loc_talent_adamant_melee_weakspot_hits_count_as_stagger_desc"] = { -- duration: 4, s->seconds, +colors
		en = "Melee "..CKWord("Weakspot Hits", "Weakspothits_rgb").." make the Enemy count as "..CKWord("Staggered", "Staggered_rgb").." for {duration:%s} seconds.",
		ru = "Попадания в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru").." в ближнем бою "..CKWord("ошеломляют", "oshelomlaut_rgb_ru").." врагов на {duration:%s} секунды.", -- Ошеломление -- руоф Сотрясение
		["zh-tw"] = "近戰"..CKWord("弱點命中", "Weakspothits_rgb_tw").." 使敵人，\n"
			.."被視為"..CKWord("踉蹌", "Staggered_rgb_tw").." {duration:%s} 秒。",
	},
	--[+ Passive 16 - Canine Morale +]--	26.03.2026
	["loc_talent_adamant_pinning_dog_kills_buff_allies_description"] = { -- tdr: +20%, toughness: +10%, duration: 5, s->seconds, +colors
		en = "Killing Pounced Targets grants for you and Allies in "..CKWord("Coherency", "Coherency_rgb").." for {duration:%s} seconds:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..",\n"
			..Dot_green.." "..CNumb("2%", "pc_2_rgb").." "..CKWord("Toughness", "Toughness_rgb").." per second, up to {toughness:%s}.",
		ru = "Убийство врага, прижатого кибермастифом к земле, даёт вам и союзникам в "..CKWord("сплочённости", "splochennosti_rgb_ru").." на {duration:%s} секунд:\n" -- Боевой настрой пса -- руоф Собачий настрой
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "Toughness_dmg_red_u_rgb_ru").." и\n"
			..Dot_green.." "..CNumb("2%", "pc_2_rgb").." восстановления "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду, вплоть до {toughness:%s}.",
		["zh-tw"] = "擊殺被撲倒的目標後，\n"
			.."你與"..CKWord("協同", "Coherency_rgb_tw").."範圍內的隊友在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."，\n"
			..Dot_green.." "..CNumb("2%", "pc_2_rgb").." "..CKWord("韌性", "Toughness_rgb_tw").." /秒，最多 {toughness:%s}。",
	},
	--[+ Passive 17 - Imposing Force +]--	26.03.2026
	["loc_talent_adamant_damage_reduction_after_elite_kill_desc"] = { -- damage_reduction: +25%, duration: 5, s->seconds, +colors
		en = Dot_green.." {damage_reduction:%s} "..CKWord("Damage", "Damage_rgb").." Resistance for {duration:%s} seconds after Elite or Specialist Kill.",
		ru = Dot_green.." {damage_reduction:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." на {duration:%s} секунд после убийства элитного врага или специалиста.", -- Давящая мощь -- руоф Впечатляющая сила
		["zh-tw"] = Dot_green.." 擊殺精英或專家後 {duration:%s} 秒內，\n"
			.."{damage_reduction:%s} "..CKWord("傷害", "Damage_rgb_tw").."抗性。",
	},
	--[+ Passive 18 - Suppression Force +]--	26.03.2026
	["loc_talent_adamant_staggered_enemies_deal_less_damage_desc"] = { -- damage: -20%, duration: 5, s->seconds, +colors
		en = "Enemies "..CKWord("Staggered", "Staggered_rgb").." by Melee Attacks, Pushes, and direct impacts of "..CKWord("Break the Line", "BreakZLine_rgb").." deal:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "Враги, "..CKWord("ошеломлённые", "oshelomlennye_rgb_ru").." вами с помощью атак ближнего боя, толчков или прямых столкновений способности "..CKWord("Прорыв вражеского строя", "BreakZLined_rgb_ru")..", наносят:\n"
			..Dot_green.." {damage:%s} "..CKWord("урона", "urona_rgb_ru")..".\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Сила подавления
		["zh-tw"] = "被近戰攻擊、推擊或"..CKWord("突破防線", "BreakZLine_rgb_tw").." 直接撞擊，\n"
			.."而"..CKWord("踉蹌", "Staggered_rgb_tw").." 的敵人，\n"
			.."其"..CKWord("傷害", "Damage_rgb_tw").." 降低 {damage:%s}。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 19 - Suppression Protocols +]--	26.03.2026
	["loc_talent_adamant_hitting_multiple_gives_tdr_desc"] = { -- hits: 3, tdr: +20%, duration: 5, s->seconds, +colors
		en = "Hitting {hits:%s} or more enemies with an Attack grants you for {duration:%s} seconds:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".",
		ru = "После попадания атакой по {hits:%s} или более врагам даёт вам на {duration:%s} секунд:\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "Toughness_dmg_red_u_rgb_ru")..".", -- Протоколы подавления
		["zh-tw"] = "單次攻擊命中 {hits:%s} 名或更多敵人後，\n"
			.."在 {duration:%s} 秒內獲得：\n"
			..Dot_green.." {tdr:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."。",
	},
	--[+ Passive 20 - Plasteel Plates +]--	26.03.2026
	["loc_talent_adamant_plasteel_plates_desc"] = { -- toughness: +25, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".", -- Пласталевые пластины -- руоф Пластины из пластали
		["zh-tw"] = Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 21 - Arbites Revelatum +]--	26.03.2026
	["loc_talent_adamant_dodge_grants_damage_desc"] = { -- damage: 15%, duration: 5, s->seconds, +colors
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} "..CKWord("Damage", "Damage_rgb").." for {duration:%s} seconds after Successful Dodge.",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." на {duration:%s} секунд при успешном уклонении.", -- Арбитрес Ревелатум
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."成功閃避後持續 {duration:%s} 秒。",
	},
	--[+ Passive 22 - Justified Measures +]--	26.03.2026
	["loc_talent_adamant_stacking_damage_desc"] = { -- damage: +3%, stacks: 5, duration: 5, s->seconds, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." on Successful Attack.\n"
			..Dot_nc.." Maximum {stacks:%s} Stacks.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." при успешной атаке.\n"
			..Dot_nc.." Максимум {stacks:%s} зарядов.\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Оправданные меры
		["zh-tw"] = Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."（成功攻擊時）。\n"
			..Dot_nc.." 最多 {stacks:%s} 層。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 23 - Hold the Line +]--	26.03.2026
	["loc_talent_adamant_staggers_reduce_damage_taken_alt_desc"] = { -- normal_stacks: 1, damage_taken_multiplier: +3%, max_stacks: 5, duration: 8, ogryn_stacks: 5, +colors
		en = CKWord("Staggering", "Staggering_rgb").." an Enemy grants {normal_stacks:%s} Stack of {damage_taken_multiplier:%s} "..CKWord("Damage", "Damage_rgb").." Resistance, on the next Melee hit taken.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			.."\n"
			..CKWord("Staggering", "Staggering_rgb").." Non-Human Sized Enemies grants {ogryn_stacks:%s} Stacks.",
		ru = CKWord("Ошеломление", "Oshelomlenie_rgb_ru").." врага даёт {normal_stacks:%s} заряд {damage_taken_multiplier:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." для следующего полученного удара в ближнем бою.\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			.."\n"
			..CKWord("Ошеломление", "Oshelomlenie_rgb_ru").." врагов больше человеческого роста даёт {ogryn_stacks:%s} зарядов.", -- Держи строй -- руоф Держать строй
		["zh-tw"] = CKWord("踉蹌", "Staggering_rgb_tw").." 敵人後，\n"
			.."  對你下次受到的近戰命中，\n"
			.."  獲得 {normal_stacks:%s} 層 {damage_taken_multiplier:%s} "..CKWord("傷害", "Damage_rgb_tw").."抗性。\n"
			..Dot_nc.." 最多 {max_stacks:%s} 層。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。\n"
			.."\n"
			..CKWord("踉蹌", "Staggering_rgb_tw").." 非人類體型的敵人可獲得 {ogryn_stacks:%s} 層。",
	},
	--[+ Passive 24 - Judicious Efficiency +]--	26.03.2026
	["loc_talent_adamant_elite_special_kills_reload_speed_desc"] = { -- reload_speed: 20%
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{reload_speed:%s} Reload Speed on next reload after Elite or Specialist Kill.",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{reload_speed:%s} к скорости следующей перезарядки после убийства элитного врага или специалиста.", -- Судейская эффективность -- руоф Разумная эффективность
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").."{reload_speed:%s} 下次裝填速度，\n"
			.."擊殺精英或專家後生效。",
	},
	--[+ Passive 25 - Rapid Movement +]--	26.03.2026
	["loc_talent_adamant_sprinting_sliding_description"] = { -- speed: +5%, duration: 5, stamina: +5%, cd: 0.75, s->seconds, +colors
		en = Dot_green.." {speed:%s} Sprint Speed for {duration:%s} seconds after Sliding.\n"
			.."\n"
			..Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb").." on Kill.\n"
			..Dot_nc.." Cooldown {cd:%s} seconds.",
		ru = Dot_green.." {speed:%s} к скорости бега на {duration:%s} секунд после подката.\n"
			.."\n"
			..Dot_green.." {stamina:%s} к "..CKWord("выносливости", "vynoslivosti_rgb_ru").." после убийства врага.\n"
			..Dot_nc.." Восстанавливается {cd:%s} секунды.", -- Быстрые движения -- руоф Быстрое перемещение
		["zh-tw"] = Dot_green.." 滑行後 {duration:%s} 秒內，\n"
			.."{speed:%s} 衝刺速度。\n"
			.."\n"
			..Dot_green.." 擊殺時恢復 {stamina:%s} "..CKWord("耐力", "Stamina_rgb_tw").."。\n"
			..Dot_nc.." 冷卻時間 {cd:%s} 秒。",
	},
	--[+ Passive 26 - Rebreather +]--	26.03.2026
	["loc_talent_adamant_rebreather_desc"] = { -- corruption: +20%, toxic_reduction: +75%, +colors
		en = Dot_green.." {corruption:%s} "..CKWord("Corruption", "Corruption_rgb").." Resistance and\n"
			..Dot_green.." {toxic_reduction:%s} Reduced "..CKWord("Damage", "Damage_rgb").." taken from Toxic Gas.",
		ru = Dot_green.." {corruption:%s} к сопротивлению "..CKWord("порче", "porche_rgb_ru").." и\n"
			..Dot_green.." {toxic_reduction:%s} к снижению "..CKWord("урона", "urona_rgb_ru")..", получаемого от токсичного газа.", -- Ребризер -- руоф Противогаз
		["zh-tw"] = Dot_green.." {corruption:%s} "..CKWord("腐敗", "Corruption_rgb_tw").."抗性，\n"
			..Dot_green.." {toxic_reduction:%s} 減少受到毒氣的"..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 27 - Cower, Miscreants! +]--	26.03.2026
	["loc_talent_adamant_damage_vs_suppressed_desc"] = { -- damage_vs_suppressed: +25%, +colors
		en = Dot_green.." {damage_vs_suppressed:%s} "..CKWord("Damage", "Damage_rgb").." vs Suppressed Enemies.",
		ru = Dot_green.." {damage_vs_suppressed:%s} к "..CKWord("урону", "uronu_rgb_ru").." подавленным врагам.", -- Трепещите, негодяи!
		["zh-tw"] = Dot_green.." {damage_vs_suppressed:%s} 對受壓制敵人的"..CKWord("傷害", "Damage_rgb_tw").."。",
	},

	--[+ Passive 28 - Target the Weak +]-- DOUBLE! OGRYN - Passive 45 - Hard Knocks
	-- ["loc_talent_ogryn_big_bully_heavy_hits_new_desc"] = {  },	26.03.2026

	--[+ Passive 29 - The Emperor's Fist +]--	12.04.2026
	["loc_talent_adamant_first_melee_hit_increased_damage_desc"] = { -- damage: +15%, impact: +30%, +colors
		en = "The First target hit by a Melee attack additionally receives:\n"
			..Dot_green.." {damage:%s} Melee "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {impact:%s} "..CKWord("Impact", "Impact_rgb")..".",
		ru = "Первая поражённая цель атаки ближнего боя получает дополнительно:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя и\n"
			..Dot_green.." {impact:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru")..".", -- Кулак Императора
		["zh-tw"] = "近戰攻擊命中的第一個目標，\n"
			.."額外受到：\n"
			..Dot_green.." {damage:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {impact:%s} "..CKWord("衝擊", "Impact_rgb_tw").."。",
	},
	--[+ Passive 30 - Zealous Dedication +]--	26.03.2026
	["loc_talent_adamant_crit_chance_on_kill_desc"] = { -- crit_chance: 2%, max_stacks: 8, duration: 10, s->seconds, +colors
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{crit_chance:%s} "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb").." on Kill.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{crit_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru").." при убийстве.\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Фанатичная преданность
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").." {crit_chance:%s} "..CKWord("暴擊打擊機率", "Crt_chnc_r_rgb_tw").."（擊殺時）。\n"
			..Dot_nc.." 最多 {max_stacks:%s} 層。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 31 - Street Smarts +]--	26.03.2026
	["loc_talent_adamant_dodge_improvement_desc"] = { -- dodge: +1, dodge_duration: +25%
		en = Dot_green.." {dodge:%s} Effective Dodges.\n"
			.."\n"
			..Dot_green.." {dodge_duration:%s} Dodge Duration, increased from "..CNumb("0.2", "n_0_2_rgb").." to "..CNumb("0.25", "n_0_25_rgb").." seconds.",
		ru = Dot_green.." {dodge:%s} эффективное уклонение.\n"
			.."\n"
			..Dot_green.." {dodge_duration:%s} к длительности уклонения.", -- Уличная хватка -- руоф Законы улицы
		["zh-tw"] = Dot_green.." {dodge:%s} 有效閃避次數。\n"
			.."\n"
			..Dot_green.." {dodge_duration:%s} 閃避持續時間，\n"
			.."由 "..CNumb("0.2", "n_0_2_rgb").." 秒增加至 "..CNumb("0.25", "n_0_25_rgb").." 秒。",
	},
	--[+ Passive 32 - Drive them Back +]--	26.03.2026
	["loc_talent_adamant_cleave_after_push_desc"] = { -- cleave: 75%, duration: 5, s->seconds, +colors
		en = "Pushing grants for {duration:%s} seconds:\n"
			..Dot_green.." {cleave:%s} "..CKWord("Cleave", "Cleave_rgb")..".",
		ru = "Отталкивание даёт на {duration:%s} секунд:\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru")..".", -- Натиск -- руоф Отбрось их
		["zh-tw"] = "推擊後 {duration:%s} 秒內，獲得：\n"
			..Dot_green.." {cleave:%s} "..CKWord("順劈攻擊", "Cleave_rgb_tw").."。",
	},
	--[+ Passive 33 - Target Selection +]--	26.03.2026
	["loc_talent_adamant_pinning_dog_elite_damage_description"] = { -- damage: +15%, time: 8, s->seconds, +colors
		en = "Killing a Pounced Elite or Specialist grants:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." vs Elites and Specialists.\n"
			..Dot_nc.." Lasts {time:%s} seconds.",
		ru = "Убийство элитного врага или специалиста, прижатого кибермастифом к земле, даёт:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." элитным врагам и специалистам.\n"
			..Dot_nc.." Длится {time:%s} секунд.", -- Выбор целей -- руоф Выбор цели
		["zh-tw"] = "擊殺被撲倒的精英或專家後，\n"
			..Dot_green.." {damage:%s} 對精英和專家的"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			..Dot_nc.." 持續 {time:%s} 秒。",
	},
	--[+ Passive 34 - Soulguilt Scan +]--	26.03.2026
	["loc_talent_adamant_stacking_weakspot_strength_duration_desc"] = { -- strength: 2%, max_stacks: 8, duration: 10, s->seconds, +colors
		en = CKWord("Weakspot Hits", "Weakspothits_rgb").." grants:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{strength:%s} "..CKWord("Weakspot", "Weakspot_rgb").." attacks strength.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = CKWord("уязвимое место", "ujazvimoe_mesto_rgb_ru").." даёт:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{strength:%s} к силе атак в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru")..".\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Поиск виновных душ
		["zh-tw"] = CKWord("弱點命中", "Weakspothits_rgb_tw").." 可獲得：\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {strength:%s} "..CKWord("弱點", "Weakspot_rgb_tw").."攻擊威力。\n"
			..Dot_nc.." 最多 {max_stacks:%s} 層。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 35 - Priority Endowment +]--	26.03.2026
	-- ! Double: Veteran - Passive 39 - Lock and Load !
	["loc_talent_adamant_clip_size_alt_desc"] = { -- clip_size: +15%
		en = Dot_green.." {clip_size:%s} Clip Size.\n"
			.."\n"
			..Dot_nc.." Rounded Up.",
		ru = Dot_green.." {clip_size:%s} к размеру магазина.\n"
			.."\n"
			..Dot_nc.." Округляется в большую сторону.", -- Приоритетное снабжение
		["zh-tw"] = Dot_green.." {clip_size:%s} 彈夾容量。\n"
			.."\n"
			..Dot_nc.." 向上取整計算。",
	},
	--[+ Passive 36 - Target Priority +]--	26.03.2026
	["loc_talent_adamant_increased_damage_to_high_health_desc"] = { -- damage: 15%, health: 75%, +colors
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} "..CKWord("Damage", "Damage_rgb").." to Enemies above {health:%s} "..CKWord("Health", "Health_rgb")..".",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." врагам со "..CKWord("здоровьем", "zdoroviem_rgb_ru").." выше {health:%s}.", -- Приоритет целей
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."對"..CKWord("生命", "Health_rgb_tw").." 高於 {health:%s} 的敵人生效。",
	},
	--[+ Passive 37 - Final Warning +]--	26.03.2026
	["loc_talent_adamant_ranged_damage_on_melee_stagger_desc"] = { -- damage: 15%, duration: 5, s->seconds, +colors
		en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} Ranged "..CKWord("Damage", "Damage_rgb").." on Melee "..CKWord("Staggering", "Staggering_rgb").." Hits.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru").." при "..CKWord("ошеломлении", "oshelomlenii_rgb_ru").." врагов ударами в ближнем бою.\n"
			..Dot_nc.." Длится {duration:%s} секунд.", -- Последнее предупреждение
		["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").." {damage:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."近戰"..CKWord("踉蹌", "Staggering_rgb_tw").."命中時觸發。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 38 - Weight of the Lex +]--	26.03.2026
	["loc_talent_adamant_heavy_attacks_increase_damage_desc"] = { -- damage: +15%, duration: 5, s->seconds, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." for {duration:%s} seconds after Heavy Melee Attack.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." на {duration:%s} секунд после заряженной атаки ближнего боя.", -- Вес Закона
		["zh-tw"] = Dot_green.." {damage:%s} "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."蓄力近戰攻擊後持續 {duration:%s} 秒。",
	},
	--[+ Passive 39 - Serrated Maw +]--	26.03.2026
	["loc_talent_adamant_dog_applies_brittleness_desc"] = { -- stacks: 6, +colors
		en = "Your Cyber-Mastiff applies on attack:\n"
			..Dot_green.." {stacks:%s} Stacks of "..CKWord("Brittleness", "Brittleness_rgb")..".",
		ru = "Ваш кибермастиф при атаке накладывает:\n"
			..Dot_green.." {stacks:%s} зарядов "..CKWord("хрупкости", "hrupkosti_rgb_ru")..".", -- Зазубренная пасть
		["zh-tw"] = "你的電子獒犬攻擊時施加：\n"
			..Dot_green.." {stacks:%s} 層"..CKWord("脆弱", "Brittleness_rgb_tw").."。",
	},
	--[+ Passive 40 - Prosecution Blow +]--	26.03.2026
	["loc_talent_adamant_crits_rend_alt_desc"] = { -- rending: +20%, +colors
		en = Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb").." on Ranged "..CKWord("Critical Strike", "Crit_strike_rgb")..".",
		ru = Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." при "..CKWord("критическом выстреле", "krit_vystrele_rgb_ru")..".", -- Карающий удар -- руоф Обвиняющий удар
		["zh-tw"] = Dot_green.." {rending:%s} "..CKWord("撕裂", "Rending_rgb_tw").."，\n"
			.."遠程"..CKWord("暴擊打擊", "Crit_strike_rgb_tw").."時觸發。",
	},
	--[+ Passive 41 - March +]--	26.03.2026
	["loc_talent_adamant_movement_speed_on_block_alt_desc"] = { -- movement_speed: +15%, duration: 3, s->seconds, +colors
		en = Dot_green.." {movement_speed:%s} Movement Speed on Ranged Hit.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = Dot_green.." {movement_speed:%s} к скорости движения после любой дальнобойной атаки.\n"
			..Dot_nc.." Длится {duration:%s} секунды.", -- Марш
		["zh-tw"] = Dot_green.." {movement_speed:%s} 移動速度，\n"
			.."遠程命中時觸發。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。",
	},
	--[+ Passive 42 - Monstrosity Hunter +]--	26.03.2026
	["loc_talent_adamant_monster_hunter_desc"] = { -- damage: +20%, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." to Ogryns and Monstrosities.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." огринам и чудовищам.", -- Охотник на чудовищ -- руоф Охота на чудовищ
		["zh-tw"] = Dot_green.." {damage:%s} 對歐格林和巨獸的"..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 43 - Strike Down +]--	26.03.2026
	["loc_talent_adamant_melee_attacks_on_staggered_rend_alt_desc"] = { -- rending: +15%, +colors
		en = Dot_green.." {rending:%s} Melee "..CKWord("Rending", "Rending_rgb").." on "..CKWord("Staggered", "Staggered_rgb").." Enemies.",
		ru = Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." в ближнем бою "..CKWord("ошеломлённым", "oshelomlennym_rgb_ru").." врагам.", -- Сокрушительный удар -- руоф Сбивающий удар
		["zh-tw"] = Dot_green.." {rending:%s} 近戰"..CKWord("撕裂", "Rending_rgb_tw").."，\n"
			.."對"..CKWord("踉蹌", "Staggered_rgb_tw").." 的敵人觸發。",
	},
	--[+ Passive 44 - True Grit +]--	26.03.2026
	["loc_talent_adamant_limit_dmg_taken_from_hits_desc"] = { -- limit: 50, +colors
		en = "Limit the Maximum "..CKWord("Health", "Health_rgb").." "..CKWord("Damage", "Damage_rgb").." Taken from an Attack to {limit:%s}.",
		ru = "Максимальный получаемый "..CKWord("урон", "uron_rgb_ru").." "..CKWord("здоровью", "zdoroviu_rgb_ru").." от атак снижается до {limit:%s}.", -- Настоящая закалка -- руоф Истинная выдержка
		["zh-tw"] = "將每次攻擊受到的最大"..CKWord("生命", "Health_rgb_tw").." "..CKWord("傷害", "Damage_rgb_tw").."，\n"
			.."限制為 {limit:%s}。",
	},
}

-- Creating templates -- Создаём шаблоны
local arbites_templates = {}

for loc_key, locales in pairs(arbites_localizations) do
	for locale, text in pairs(locales) do
		table.insert(arbites_templates, create_template(
			"arbites_" .. loc_key,
			{loc_key},
			{locale},
			loc_text(text)
		))
	end
end

return arbites_templates
