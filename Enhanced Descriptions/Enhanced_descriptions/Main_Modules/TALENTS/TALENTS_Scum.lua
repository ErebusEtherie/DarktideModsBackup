---@diagnostic disable: undefined-global
-- HIVE SCUM TALENT MODULE -- МОДУЛЬ ТАЛАНТОВ ОТРЕБЬЯ УЛЬЯ

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

-- Localization of hive Scum talents -- Локализации талантов отребья улья
local scum_localizations = {
--[+ ++HIVE SCUM - ОТРЕБЬЕ УЛЬЯ++ +]--
--[+ +BLITZ - БЛИЦ+ +]--
	--[+ BLITZ 0 - Blinder +]--	26.03.2026
	["loc_talent_broker_blitz_flash_grenade_desc"] = { -- Grenade(s)->Grenade, num_kills: 20, num_charges: 1, max_charges: 3, +colors
		en = "Quick to use Grenade that "..CKWord("Staggers", "Staggers_rgb").." enemies.\n"
			.."\n"
			..Dot_green.." {num_charges:%s} Grenade generated every {num_kills:%s} Kills within "..CNumb("12.5", "n_12_5_rgb").." meters.\n"
			..Dot_nc.." Maximum Grenades: {max_charges:%s}.\n"
			..Dot_nc.." Max explosion radius: "..CNumb("3.5", "n_3_5_rgb").." meters.\n"
			.."\n"
			..Dot_green.." "..CKWord("Staggers", "Staggers_rgb").." all enemies except for Mutants, Monstrosties, female Twin and Captains only without Void shield.\n"
			..Dot_nc.." Replenishes all grenades per grenade pickup.",
		ru = "Вы бросаете быстродействующую гранату, которая "..CKWord("ошеломляет", "oshelomlaet_rgb_ru").." врагов.\n"
			.."\n"
			..Dot_green.." Вы получаете {num_charges:%s} гранату за каждые {num_kills:%s} убийств в радиусе "..CNumb("12.5", "n_12_5_rgb").." метров от вас.\n"
			..Dot_nc.." Максимум гранат: {max_charges:%s}.\n"
			..Dot_nc.." Максимальный радиус взрыва: "..CNumb("3.5", "n_3_5_rgb").." метра.\n"
			-- .."\n"
			..Dot_green.." "..CKWord("Ошеломляет", "Oshelomlaet_rgb_ru").." всех врагов, кроме мутантов, чудовищ, сестры из близнецов и капитанов только без пустотного щита.\n"
			..Dot_nc.." Все гранаты пополняются из подобранного ящика гранат.", -- Ослепитель
		["zh-tw"] = "快速使用的手雷，"..CKWord("踉蹌", "Staggers_rgb_tw").." 敵人。\n"
			.."\n"
			..Dot_green.." 每 "..CNumb("12.5", "n_12_5_rgb").." 米內擊殺 {num_kills:%s} 次補充 {num_charges:%s} 個手雷，最多 {max_charges:%s} 個。\n"
			..Dot_nc.." 最大爆炸半徑： "..CNumb("3.5", "n_3_5_rgb").." 米。\n"
			.."\n"
			..Dot_green.." "..CKWord("踉蹌", "Staggers_rgb_tw").." 除變種人、巨獸、雙子和沒有虛空盾的隊長以外所有敵人。\n"
			..Dot_nc.." 拾取手雷時補充全部。",
	},
	--[+ BLITZ 1 - Blackout +]--	26.03.2026
	["loc_talent_broker_blitz_flash_grenade_improved_desc"] = { -- Grenade(s)->Grenade, num_kills: 20, num_charges: 1, max_charges: 5, talent_name: Blinder, +colors
		en = "Quick to use Grenade that "..CKWord("Staggers", "Staggers_rgb").." enemies.\n"
			..Dot_green.." This is an augmented version of {talent_name:%s}.\n"
			.."\n"
			..Dot_green.." {num_charges:%s} Grenade generated every {num_kills:%s} Kills within "..CNumb("12.5", "n_12_5_rgb").." meters.\n"
			..Dot_nc.." Maximum Grenades: {max_charges:%s}.\n"
			..Dot_nc.." Max explosion radius: "..CNumb("3.5", "n_3_5_rgb").." meters.\n"
			.."\n"
			..Dot_green.." "..CKWord("Staggers", "Staggers_rgb").." all enemies except for Mutants, Monstrosties, female Twin and Captains only without Void shield.\n"
			..Dot_nc.." Replenishes all grenades per grenade pickup.",
		ru = "Вы бросаете быстродействующую гранату, которая "..CKWord("ошеломляет", "oshelomlaet_rgb_ru").." врагов.\n"
			..Dot_green.." Это улучшенная версия таланта {talent_name:%s}.\n"
			.."\n"
			..Dot_green.." Вы получаете {num_charges:%s} гранату за каждые {num_kills:%s} убийств в радиусе "..CNumb("12.5", "n_12_5_rgb").." метров от вас.\n"
			..Dot_nc.." Максимум гранат: {max_charges:%s}.\n"
			..Dot_nc.." Максимальный радиус взрыва: "..CNumb("3.5", "n_3_5_rgb").." метров.\n"
			.."\n"
			..Dot_green.." "..CKWord("Ошеломляет", "Oshelomlaet_rgb_ru").." всех врагов, кроме мутантов, чудовищ, сестры из близнецов и капитанов только без пустотного щита.\n"
			..Dot_nc.." Все гранаты пополняются из подобранного ящика гранат.", -- Затмение
		["zh-tw"] = "快速使用的手雷，"..CKWord("踉蹌", "Staggers_rgb_tw").." 敵人。\n"
			..Dot_green.." 為 {talent_name:%s} 的增強版本。\n"
			.."\n"
			..Dot_green.." 每 "..CNumb("12.5", "n_12_5_rgb").." 米內擊殺 {num_kills:%s} 次補充 {num_charges:%s} 個手雷，最多 {max_charges:%s} 個。\n"
			..Dot_nc.." 最大爆炸半徑： "..CNumb("3.5", "n_3_5_rgb").." 米。\n"
			.."\n"
			..Dot_green.." "..CKWord("踉蹌", "Staggers_rgb_tw").." 除變種人、巨獸、雙子和沒有虛空盾的隊長以外所有敵人。\n"
			..Dot_nc.." 拾取手雷時補充全部。",
	},
	--[+ BLITZ 2 - Boom Bringer +]--	26.03.2026
	["loc_talent_broker_blitz_missile_launcher_desc"] = { -- max_charges: , +colors
		en = "High powered missile launcher.\n"
			.."\n"
			..Dot_nc.." Max Missiles: {max_charges:%s}.\n"
			..Dot_nc.." Max Explosion radius: "..CNumb("7", "n_7_rgb").." meters.\n"
			..Dot_nc.." Max travel time: "..CNumb("1.5", "n_1_5_rgb").." seconds.\n"
			.."\n"
			..Dot_nc.." Projectile impact base "..CKWord("Damage", "Damage_rgb")..": "..CNumb("1800", "n_1800_rgb")..".\n"
			..Dot_green.." Armor "..CKWord("Damage", "Damage_rgb").." modifiers:\n"
			.."_______________________________\n"
			.."Carapace                                         |      "..CNumb("1.1", "n_1_1_rgb").."\n"
			.."Unarmoured, Flak, Void Shield    |        "..CNumb("1", "n_1_rgb").."\n"
			.."Maniac                                             |    "..CNumb("0.9", "n_0_9_rgb").."\n"
			.."Unyielding                                       |  "..CNumb("0.75", "n_0_75_rgb").."\n"
			.."Infested                                            | "..CNumb("0.25", "n_0_25_rgb").."\n"
			.."_______________________________\n"
			..Dot_green.." Ignores Bulwark shield.\n"
			..CPhrs("Cant_Crit")
			.."\n"
			..Dot_green.." Explosion base "..CKWord("Damage", "Damage_rgb")..": ["..CNumb("2800", "n_2800_rgb").."-"..CNumb("1300", "n_1300_rgb").."].\n"
			..Dot_green.." Armor "..CKWord("Damage", "Damage_rgb").." modifiers:\n"
			.."_______________________________\n"
			.."Carapace                                         |    "..CNumb("2.4", "n_2_4_rgb").."\n"
			.."Flak, Unyielding                             |        "..CNumb("2", "n_2_rgb").."\n"
			.."Maniac                                             |   "..CNumb("1.35", "n_1_35_rgb").."\n"
			.."Unarmoured                                   |   "..CNumb("1.25", "n_1_25_rgb").."\n"
			.."Void Shield                                      |      "..CNumb("1.1", "n_1_1_rgb").."\n"
			.."Infested                                            |  "..CNumb("0.75", "n_0_75_rgb").."\n"
			.."_______________________________\n"
			.."\n"
			..Dot_green.." Very high "..CKWord("Stagger", "Stagger_rgb").." against all enemies except for Mutants and Twins/Captains without Void shield.\n"
			..Dot_nc.." Replenishes all missiles per grenade pickup.",
		ru = "Мощный гранатомёт.\n"
			.."\n"
			..Dot_nc.." Максимум зарядов: {max_charges:%s}.\n"
			..Dot_nc.." Максимальный радиус взрыва: "..CNumb("7", "n_7_rgb").." метров.\n"
			..Dot_nc.." Максимальное время полёта: "..CNumb("1.5", "n_1_5_rgb").." секунды.\n"
			.."\n"
			..Dot_nc.." Базовый "..CKWord("урон", "uron_rgb_ru").." от попадания: "..CNumb("1800", "n_1800_rgb")..".\n"
			-- ..Dot_green.." Хороший "..CKWord("урон", "uron_rgb_ru").." по броне.\n"
			..Dot_green.." Игнорирует щит бастиона.\n"
			..CPhrs("Cant_Crit")
			.."\n"
			..Dot_green.." Базовый "..CKWord("урон", "uron_rgb_ru").." от взрыва: ["..CNumb("2800", "n_2800_rgb").."-"..CNumb("1300", "n_1300_rgb").."].\n"
			-- ..Dot_green.." Высокий "..CKWord("урон", "uron_rgb_ru").." против несгибаемых, противоосколочной и панцирной брони.\n"
			.."\n"
			..Dot_green.." Очень высокое "..CKWord("ошеломление", "oshelomlenie_rgb_ru").." против всех врагов, кроме мутантов, близнецов и капитанов без пустотного щита.\n"
			..Dot_nc.." Все заряды пополняются из подобранного ящика гранат.", -- Бабахер
		["zh-tw"] = "高功率火箭發射器。\n"
			.."\n"
			..Dot_nc.." 最多彈藥：{max_charges:%s}。最大爆炸半徑： "..CNumb("7", "n_7_rgb").." 米。\n"
			.."\n"
			..Dot_nc.." 射擊基礎"..CKWord("傷害", "Damage_rgb_tw").."： "..CNumb("1800", "n_1800_rgb").."。\n"
			..Dot_green.." 無視城牆護盾。\n"
			..CPhrs("Cant_Crit")
			.."\n"
			..Dot_green.." 爆炸基礎"..CKWord("傷害", "Damage_rgb_tw").."：["..CNumb("2800", "n_2800_rgb").." - "..CNumb("1300", "n_1300_rgb").."]。\n"
			..Dot_green.." 除變種人、隊長/雙子（沒有虛空盾）外，對所有敵人造成极高"..CKWord("踉蹌", "Stagger_rgb_tw").."。\n"
			..Dot_nc.." 拾取手雷時補充全部火箭。",
	},
	--[+ BLITZ 3 - Chem Grenade +]--	26.03.2026
	["loc_talent_broker_blitz_tox_grenade_desc_02"] = { -- toxin: Chem Toxin, max_charges: 3, +colors
		en = "Thrown grenade containing a "..CKWord("Chem Toxin", "Chem_Tox_rgb")..". The canister breaks open when it explodes, spilling its contents out across an area.\n"
			.."\n"
			..Dot_nc.." Max Grenades: {max_charges:%s}.\n"
			..Dot_nc.." Fuse time: "..CNumb("5", "n_5_rgb").." seconds, "..CNumb("1.5", "n_1_5_rgb").." seconds on impact.\n"
			..Dot_nc.." Initial explosion radius: "..CNumb("4", "n_4_rgb").." meters.\n"
			..Dot_nc.." Toxic area: "..CNumb("10", "n_10_rgb").." meters.\n"
			..Dot_nc.." Lasts: "..CNumb("15", "n_15_rgb").." seconds.\n"
			..Dot_nc.." Replenishes all grenades per grenade pickup.\n"
			.."\n"
			.."Toxin application:\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." Stack of "..CKWord("Chem Toxin", "Chem_Tox_rgb").." per "..CNumb("0.35", "n_0_35_rgb").." seconds, up to "..CNumb("6", "n_6_rgb")..".\n"
			..Dot_nc.." "..CNumb("+", "n_plus_rgb")..CNumb("1", "n_1_rgb").." Stack when enemies leaving the toxic area.\n"
			.."\n"
			.." Enemies debuff:\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb")..CNumb("50%", "pc_50_rgb").." "..CKWord("Hit mass", "Hit_mass_rgb").." against Melee attacks.\n"
			..Dot_nc.." Lasts: "..CNumb("1", "n_1_rgb").." second.\n"
			..CPhrs("Can_be_refr").."\n"
			..CPhrs("Doesnt_Stack_Scm_eff").."\n"
			.."\n"
			.."Toxin explosion:\n"
			..Dot_nc.." The explosion occurs only if the enemy dies within "..CNumb("12", "n_12_rgb").." seconds of receiving the last Stack.\n"
			..Dot_nc.." Explosion radius: "..CNumb("2.5", "n_2_5_rgb").." meters.\n"
			..Dot_green.." Explosion base "..CKWord("Damage", "Damage_rgb")..": ["..CNumb("200", "n_200_rgb").."-"..CNumb("100", "n_100_rgb").."].\n"
			..Dot_nc.." Average armor "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_red.." Low "..CKWord("Damage", "Damage_rgb").." vs Flak.",
		ru = "Вы бросаете контейнер, который разбивается и разливает "..CKWord("Хим-токсин", "Chem_Tox_rgb_ru").." по области при взрыве.\n"
			.."\n"
			..Dot_nc.." Максимум гранат: {max_charges:%s}.\n"
			..Dot_nc.." Время до взрыва: "..CNumb("5", "n_5_rgb").." секунд.\n"
			-- ..Dot_nc.." Первоначальный радиус взрыва: "..CNumb("4", "n_4_rgb").." метра.\n"
			..Dot_nc.." Токсичная область: "..CNumb("10", "n_10_rgb").." метров.\n"
			..Dot_nc.." Длится: "..CNumb("15", "n_15_rgb").." секунд.\n"
			..Dot_nc.." Все гранаты пополняются из подобранного ящика гранат.\n"
			.."\n"
			.."Наложение токсина:\n"
			..Dot_nc.." "..CNumb("1", "n_1_rgb").." заряд "..CKWord("Хим-токсина", "Chem_Toxa_rgb_ru").." накладывается каждые "..CNumb("0.35", "n_0_35_rgb").." секунды, вплоть до "..CNumb("6", "n_6_rgb").." зарядов.\n"
			..Dot_nc.." "..CNumb("+", "n_plus_rgb")..CNumb("1", "n_1_rgb").." заряд, когда враги покидают токсичную область.\n"
			.."\n"
			.."Ослабление врагов:\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb")..CNumb("50%", "pc_50_rgb").." "..CKWord("ударной массы", "udarn_massy_rgb_ru").." для атак ближнего боя.\n"
			..Dot_nc.." Длится: "..CNumb("1", "n_1_rgb").." секунду.\n"
			..CPhrs("Can_be_refr").."\n"
			..CPhrs("Doesnt_Stack_Scm_eff").."\n"
			.."\n"
			.."Взрыв токсина:\n"
			..Dot_nc.." Взрыв происходит только если враг умирает в течение "..CNumb("12", "n_12_rgb").." секунд после получения последнего заряда.\n"
			..Dot_nc.." Радиус взрыва: "..CNumb("2.5", "n_2_5_rgb").." метра.\n"
			..Dot_green.." Базовый "..CKWord("урон", "uron_rgb_ru").." от взрыва: ["..CNumb("200", "n_200_rgb").."-"..CNumb("100", "n_100_rgb").."].\n"
			..Dot_nc.." Средний "..CKWord("урон", "uron_rgb_ru").." по броне.\n"
			..Dot_red.." Низкий "..CKWord("урон", "uron_rgb_ru").." по противоосколочной брони.", -- Хим-граната
		["zh-tw"] = "投擲載有"..CKWord("化學毒素", "Chem_Tox_rgb_tw").." 的容器，爆炸時散布內容。\n"
			.."\n"
			..Dot_nc.." 最多 {max_charges:%s} 個。引爆 5 秒，擊擊後 1.5 秒。毒素區得 "..CNumb("10", "n_10_rgb").." 米，持續 15 秒。\n"
			..Dot_nc.." 拾取手雷時補充全部。\n"
			.."\n"
			.."毒素施加：\n"
			..Dot_nc.." 每 0.35 秒 1 層"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."，最多 6 層。敵人離開毒素區時額外 +1 層。\n"
			.."\n"
			.."敵人減益：\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb")..CNumb("50%", "pc_50_rgb").." "..CKWord("順劈目標", "Hit_mass_rgb_tw").."，近戰攻擊時。持續 1 秒。\n"
			..CPhrs("Can_be_refr").."\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同效果疊加。\n"
			.."\n"
			.."毒素爆炸：\n"
			..Dot_nc.." 敵人在最後一層後 12 秒內死亡才會觸發。爆炸半徑 2.5 米。\n"
			..Dot_green.." 爆炸基礎"..CKWord("傷害", "Damage_rgb_tw").."：["..CNumb("200", "n_200_rgb").." - "..CNumb("100", "n_100_rgb").."]。",
	},
--[+ +AURA - АУРЫ+ +]--
	--[+ AURA 0 - Gunslinger +]--	26.03.2026
	["loc_talent_broker_aura_gunslinger_desc"] = { -- ammo: 5%, +colors
		en = Dot_green.." {ammo:%s} of the Ammo from any pickup collected by you or Allies in "..CKWord("Coherency", "Coherency_rgb").." is replenished to each of you.\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"),
		ru = Dot_green.." {ammo:%s} патронов с любого найденного боекомплекта, подобранного вами или союзниками в "..CKWord("сплочённости", "splochennosti_rgb_ru")..", восполняется каждому из вас.\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"), -- Стрелок
		["zh-tw"] = Dot_green.." 你或"..CKWord("協同", "Coherency_rgb_tw").." 盟友拾取彈藥時，每人都分到 {ammo:%s}。\n"
			.."\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同光環疊加。",
	},
	--[+ AURA 1 - Gunslinger Improved +]--	26.03.2026
	["loc_talent_broker_aura_gunslinger_improved_desc"] = { -- ammo: 10%, talent: Gunslinger, +colors
		en = Dot_green.." {ammo:%s} of the Ammo from any pickup collected by you or Allies in "..CKWord("Coherency", "Coherency_rgb").." is replenished to each of you.\n"
			..Dot_green.." This is an augmented version of {talent:%s}.\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"),
		ru = Dot_green.." {ammo:%s} патронов с любого найденного боекомплекта, подобранного вами или союзниками в "..CKWord("сплочённости", "splochennosti_rgb_ru")..", восполняется каждому из вас.\n"
			..Dot_green.." Это улучшенная версия таланта {talent:%s}.\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"), -- Улучшенный стрелок
		["zh-tw"] = Dot_green.." 你或"..CKWord("協同", "Coherency_rgb_tw").." 盟友拾取彈藥時，每人都分到 {ammo:%s}。\n"
			..Dot_green.." 為 {talent:%s} 的增強版本。\n"
			.."\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同光環疊加。",
	},
	--[+ AURA 2 - Ruffian +]--	26.03.2026
	["loc_talent_broker_aura_ruffian_desc"] = { -- melee_damage: +10%, talent_name: , +colors
		en = Dot_green.." {melee_damage:%s} Melee "..CKWord("Damage", "Damage_rgb").." for you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"),
		ru = Dot_green.." {melee_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." в ближнем бою для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"), -- Хулиган
		["zh-tw"] = Dot_green.." {melee_damage:%s} 對你和"..CKWord("協同", "Coherency_rgb_tw").." 盟友的近戰"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同光環疊加。",
	},
	--[+ AURA 3 - Anarchist +]--	30.12.2025
	["loc_talent_broker_aura_anarchist_desc"] = { -- critical_chance: +5%, +colors
		en = Dot_green.." {critical_chance:%s} "..CKWord("Critical Chance", "Crit_chance_rgb").." for you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"),
		ru = Dot_green.." {critical_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru").." для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_Aura"), -- Анархист
		["zh-tw"] = Dot_green.." {critical_chance:%s} 對你和"..CKWord("協同", "Coherency_rgb_tw").." 盟友的"..CKWord("暴擊機率", "Crit_chance_rgb_tw").."。\n"
			.."\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同光環疊加。",
	},
--[+ +ABILITIES - СПОСОБНОСТИ+ +]--
	--[+ ABILITY 0 - Desperado +]--	26.03.2026
	["loc_talent_broker_ability_focus_desc"] = { -- talent_name: Enhanced Desperado, duration: 10, sprint_movement_speed: +20%, cooldown: 45, s->seconds, +colors
		en = "Replenish all "..CKWord("Toughness", "Toughness_rgb")..", swaps to and reloads your Ranged Weapon, entering {talent_name:%s} for {duration:%s} seconds.\n"
			.."\n"
			.."For the duration you gain:\n"
			..Dot_green.." {sprint_movement_speed:%s} Sprint Speed,\n"
			..Dot_green.." Sprinting cost no "..CKWord("Stamina", "Stamina_rgb")..",\n"
			..Dot_green.." Immunity to Ranged Attacks,\n"
			..Dot_green.." Immunity to Suppression,\n"
			..Dot_green.." Reloading consumes no Ammo from your Reserve.\n"
			.."\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.",
		ru = "Вы восполняете всю "..CKWord("стойкость", "stoikost_rgb_ru")..", берёте в руки ваше перезаряженное дальнобойное оружие, входя в режим "..CKWord("Безбашенного", "Desperady_rgb_ru").." на {duration:%s} секунд.\n"
			.."\n"
			.."На время действия вы получаете:\n"
			..Dot_green.." {sprint_movement_speed:%s} к скорости бега,\n"
			..Dot_green.." Бег не тратит "..CKWord("выносливость", "vynoslivost_rgb_ru")..",\n"
			..Dot_green.." Иммунитет к дальнобойным атакам,\n"
			..Dot_green.." Иммунитет к подавлению,\n"
			..Dot_green.." Перезарядка не тратит боеприпасы из резерва.\n"
			-- .."\n"
			..Dot_nc.." Восстановление: {cooldown:%s} секунд.", -- Безбашенный
		["zh-tw"] = "補滿"..CKWord("韌性", "Toughness_rgb_tw").."，切換並換彈遠程武器，進入 {talent_name:%s} {duration:%s} 秒。\n"
			.."\n"
			.."期間獲得：\n"
			..Dot_green.." {sprint_movement_speed:%s} 衝刺速度，\n"
			..Dot_green.." 衝刺不消耗"..CKWord("耐力", "Stamina_rgb_tw").."，\n"
			..Dot_green.." 免疫遠程攻擊，\n"
			..Dot_green.." 免疫壓制，\n"
			..Dot_green.." 換彈不消耗備用彈藥。\n"
			.."\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。",
	},
	--[+ ABILITY 1 - Enhanced Desperado +]--	26.03.2026
	["loc_talent_broker_ability_focus_improved_desc"] = { -- talent_name: Enhanced Desperado, duration: 10, sprint_movement_speed: +20%, duration_extend: 1, duration_max: 20, cooldown: 45, s->seconds, +colors
		en = "Replenish all "..CKWord("Toughness", "Toughness_rgb")..", swaps to and reloads your Ranged Weapon, entering {talent_name:%s} for {duration:%s} seconds.\n"
			..Dot_green.." This is an augmented version of {default_talent:%s}.\n"
			.."\n"
			.."For the duration you gain:\n"
			..Dot_green.." {sprint_movement_speed:%s} Sprint Speed,\n"
			..Dot_green.." Sprinting cost no "..CKWord("Stamina", "Stamina_rgb")..",\n"
			..Dot_green.." Immunity to Ranged Attacks,\n"
			..Dot_green.." Immunity to Suppression,\n"
			..Dot_green.." Reloading consumes no Ammo from your Reserve.\n"
			.."\n"
			.."Highlights enemies within "..CNumb("12.5", "n_12_5_rgb").." meters.\n"
			.."\n"
			.."Ranged Weapon Kills on highlighted enemies extend the {talent_name:%s} duration:\n"
			..Dot_green.." First {duration_max:%s} seconds: "..CNumb("+", "n_plus_rgb").."{duration_extend:%s} second per kill.\n"
			..Dot_green.." After {duration_max:%s} seconds: "..CNumb("+", "n_plus_rgb")..CNumb("0.2", "n_0_2_rgb").." seconds per kill.\n"
			..Dot_nc.." Effect diminishes further every {duration_max:%s} seconds.\n"
			..CPhrs("Can_proc_mult_str")
			.."\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.",
		ru = "Вы восполняете всю "..CKWord("стойкость", "stoikost_rgb_ru")..", берёте в руки ваше перезаряженное дальнобойное оружие, входя в режим "..CKWord("Безбашенного", "Desperady_rgb_ru").." на {duration:%s} секунд.\n"
			..Dot_green.." Это улучшенная версия таланта {default_talent:%s}.\n"
			.."\n"
			.."На время действия вы получаете:\n"
			..Dot_green.." {sprint_movement_speed:%s} к скорости бега,\n"
			..Dot_green.." Бег не тратит "..CKWord("выносливость", "vynoslivost_rgb_ru")..",\n"
			..Dot_green.." Иммунитет к дальнобойным атакам,\n"
			..Dot_green.." Иммунитет к подавлению,\n"
			..Dot_green.." Перезарядка не тратит боеприпасы из резерва.\n"
			.."\n"
			.."Враги в радиусе "..CNumb("12.5", "n_12_5_rgb").." метров подсвечиваются.\n"
			.."\n"
			.."Убийства подсвеченных врагов оружием дальнего боя продлевают время действия способности {talent_name:%s}:\n"
			..Dot_green.." Первые {duration_max:%s} секунд: "..CNumb("+", "n_plus_rgb").."{duration_extend:%s} секунда за убийство.\n"
			..Dot_green.." После {duration_max:%s} секунд: "..CNumb("+", "n_plus_rgb")..CNumb("0.2", "n_0_2_rgb").." секунды за убийство.\n"
			..Dot_nc.." Эффект ослабевает дальше каждые {duration_max:%s} секунд.\n"
			..CPhrs("Can_proc_mult_str")
			.."\n"
			..Dot_nc.." Базовое время восстановления: {cooldown:%s} секунд.", -- Улучшенный Безбашенный
		["zh-tw"] = "補滿"..CKWord("韌性", "Toughness_rgb_tw").."，切換並換彈遠程武器，進入 {talent_name:%s} {duration:%s} 秒。\n"
			..Dot_green.." 為 {default_talent:%s} 的增強版本。\n"
			.."\n"
			.."期間獲得：\n"
			..Dot_green.." {sprint_movement_speed:%s} 衝刺速度，衝刺不消耗"..CKWord("耐力", "Stamina_rgb_tw").."，免疫遠程攻擊和壓制，換彈不消耗備用彈藥。\n"
			.."\n"
			.."12.5 米內的敵人會被標出。\n"
			.."\n"
			.."遠程擊殺標出敵人延長 {talent_name:%s}：\n"
			..Dot_green.." 前 {duration_max:%s} 秒：每次擊殺 +{duration_extend:%s} 秒。\n"
			..Dot_green.." 超過 {duration_max:%s} 秒後：每次 +0.2 秒。\n"
			..Dot_nc.." 效果每 {duration_max:%s} 秒進一步衰減。\n"
			..CPhrs("Can_proc_mult_str")
			.."\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。",
	},
	--[+ ABILITY 1-1 - Pick Your Targets +]--	26.03.2026
	["loc_talent_broker_ability_focus_sub_2_desc"] = { -- rending: +15%, focus: Enhanced Desperado, damage: +3%, stacks: 5, +colors
		en = "While {focus:%s} is active, you gain:\n"
			..Dot_green.." {rending:%s} Ranged "..CKWord("Rending", "Rending_rgb")..".\n"
			.."\n"
			.."Additionally, killing highlighted enemies also grants Stacks.\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			..Dot_nc.." Stacks lasts "..CNumb("3", "n_3_rgb").." seconds.\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."Per Stack you gain:\n"
			..Dot_green.." {damage:%s} Ranged "..CKWord("Damage", "Damage_rgb")..", up to {rending:%s}.\n"
			.."\n"
			..CNote("Rend_note"),
		ru = "Пока активен {focus:%s}, вы получаете:\n"
			..Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони для дальнобойных атак.\n"
			.."\n"
			.."Убийства подсвеченных врагов также дают заряды.\n"
			..Dot_nc.." Суммируется {stacks:%s} раз.\n"
			..Dot_nc.." Заряды длятся "..CNumb("3", "n_3_rgb").." секунды.\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."За каждый заряд вы получаете:\n"
			..Dot_green.." {damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru")..", до {rending:%s}.\n"
			.."\n"
			..CNote("Rend_note"),
		["zh-tw"] = "{focus:%s} 啟用期間獲得：\n"
			..Dot_green.." {rending:%s} 遠程"..CKWord("撕裂", "Rending_rgb_tw").."。\n"
			.."\n"
			.."擊殺標出敵人也給予層數。最多 {stacks:%s} 層，持續 3 秒。\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."每層獲得：\n"
			..Dot_green.." {damage:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."，最多 {rending:%s}。\n"
			.."\n"
			..CNote("Rend_note"),
	},
	--[+ ABILITY 1-2 - Focused Resolve +]--	26.03.2026
	["loc_talent_broker_ability_focus_sub_3_desc"] = { -- cooldown_base: 0.5, cooldown_elite: 1, cooldown_max: 5, s->seconds, +colors
		en = "Killing a highlighted enemy restores "..CKWord("Ability Cooldown", "Ability_cd_rgb")..":\n"
			..Dot_green.." Regular enemy: {cooldown_base:%s} seconds.\n"
			..Dot_green.." Elite or Specialist: {cooldown_elite:%s} second.\n"
			.."\n"
			..Dot_nc.." Maximum: {cooldown_max:%s} seconds.\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
		ru = "Убийство подсвеченного врага сокращает время восстановления "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..":\n"
			..Dot_green.." Обычный враг: "..CNumb("-", "n_minus_rgb").."{cooldown_base:%s} секунды.\n"
			..Dot_green.." Элита или специалист: "..CNumb("-", "n_minus_rgb").."{cooldown_elite:%s} секунда.\n"
			.."\n"
			..Dot_nc.." Максимум: "..CNumb("-", "n_minus_rgb").."{cooldown_max:%s} секунд.\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
		["zh-tw"] = "擊殺標出敵人恢復"..CKWord("技能冷卻", "Ability_cd_rgb_tw").."：\n"
			..Dot_green.." 普通敵人：{cooldown_base:%s} 秒。\n"
			..Dot_green.." 精英或特殊：{cooldown_elite:%s} 秒。\n"
			.."\n"
			..Dot_nc.." 最多 {cooldown_max:%s} 秒。\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
	},
	--[+ ABILITY 2 - Rampage! +]--	26.03.2026
	["loc_talent_broker_ability_punk_rage_desc_3"] = { -- talent_name: Rampage!, duration: 10, power: +50%, attack_speed: +20%, damage_taken: 25%, rage_duration_extend: 0.3, rage_duration_max: 20, exhaust_duration: 7, exhaust_damage_taken: +25%, exhaust_stamina_regeneration: -75%, cooldown: 30, s->seconds, +colors
		en = "Replenish all "..CKWord("Toughness", "Toughness_rgb").." and enter {talent_name:%s} for {duration:%s} seconds.\n"
			.."\n"
			.."For the duration, gain:\n"
			..Dot_green.." {power:%s} Melee "..CKWord("Strength", "Strength_rgb")..",\n"
			..Dot_green.." {attack_speed:%s} Melee Attack Speed,\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage_taken:%s} "..CKWord("Damage", "Damage_rgb").." Reduction,\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity and\n"
			..Dot_green.." Slowdown Immunity.\n"
			.."\n"
			.."Duration Extension on Melee Strike:\n"
			..Dot_green.." First {rage_duration_max:%s} seconds: "..CNumb("+", "n_plus_rgb").."{rage_duration_extend:%s} seconds per hit.\n"
			..Dot_green.." After {rage_duration_max:%s} seconds: "..CNumb("+", "n_plus_rgb")..CNumb("0.15", "n_0_15_rgb").." seconds per hit.\n"
			..Dot_nc.." Effect diminishes further every {rage_duration_max:%s} seconds.\n"
			..CPhrs("Can_proc_mult_str")
			.."\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.\n"
			..Dot_red.." Cooldown paused while {talent_name:%s} active.\n"
			.."\n"
			..CNote("Pwr_note"),
		ru = "Вы восполняете всю "..CKWord("стойкость", "stoikost_rgb_ru").." и на {duration:%s} секунд впадаете в {talent_name:%s}\n"
			.."\n"
			.."На время действия вы получаете:\n"
			..Dot_green.." {power:%s} к "..CKWord("силе", "sile_rgb_ru").." атак ближнего боя,\n"
			..Dot_green.." {attack_speed:%s} к скорости атак ближнего боя,\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_taken:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru").." и\n"
			..Dot_green.." Иммунитет к замедлению.\n"
			.."\n"
			.."Продление времени за удары в ближнем бою:\n"
			..Dot_green.." В первые {rage_duration_max:%s} секунд: "..CNumb("+", "n_plus_rgb").."{rage_duration_extend:%s} секунды.\n"
			..Dot_green.." После {rage_duration_max:%s} секунд: "..CNumb("+", "n_plus_rgb")..CNumb("0.15", "n_0_15_rgb").." секунды.\n"
			..Dot_nc.." Эффект продолжает ослабевать каждые {rage_duration_max:%s} секунд.\n"
			..CPhrs("Can_proc_mult")
			.."\n"
			..Dot_nc.." Базовое время восстановления: {cooldown:%s} секунд.\n"
			..Dot_red.." Время восстановления приостанавливается, пока {talent_name:%s} активно.\n"
			.."\n"
			..CNote("Pwr_note"),
		["zh-tw"] = "補滿"..CKWord("韌性", "Toughness_rgb_tw").." 並進入 {talent_name:%s} {duration:%s} 秒。\n"
			.."\n"
			.."期間獲得：\n"
			..Dot_green.." {power:%s} 近戰"..CKWord("威力", "Strength_rgb_tw").."，\n"
			..Dot_green.." {attack_speed:%s} 近戰攻擊速度，\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").." {damage_taken:%s} 傷害抑制，\n"
			..Dot_green.." "..CKWord("眩暈", "Stun_rgb_tw").." 免疫 和 慢速免疫。\n"
			.."\n"
			.."近戰命中延長持續時間：\n"
			..Dot_green.." 前 {rage_duration_max:%s} 秒：每次 +{rage_duration_extend:%s} 秒。\n"
			..Dot_green.." 超過 {rage_duration_max:%s} 秒後：每次 +0.15 秒。\n"
			..CPhrs("Can_proc_mult")
			.."\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。\n"
			..Dot_red.." {talent_name:%s} 啟用期間將暫停冷卻。\n"
			.."\n"
			..CNote("Pwr_note"),
	},
	--[+ ABILITY 2-1 - Channelled Aggression +]--	26.03.2026
	["loc_talent_broker_ability_punk_rage_sub_1_desc_02"] = { -- rending: +25%, punk_rage: Rampage!, ability_progress: 50%, +colors
		en = "While {punk_rage:%s} is active Heavy Attacks gain:\n"
			..Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb")..".\n"
			.."\n"
			..CNote("Rend_note"),
		ru = "Пока активно {punk_rage:%s} тяжёлые атаки получают:\n"
			..Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони.\n"
			.."\n"
			..CNote("Rend_note"),
		["zh-tw"] = "{punk_rage:%s} 啟用期間，重型攻擊獲得：\n"
			..Dot_green.." {rending:%s} "..CKWord("撕裂", "Rending_rgb_tw").."。\n"
			.."\n"
			..CNote("Rend_note"),
	},
	--[+ ABILITY 2-2 - Boiling Blood +]--	26.03.2026
	["loc_talent_broker_ability_punk_rage_sub_4_desc"] = { -- punk_rage: Rampage!, rage_duration_extend_elites: 1, rage_duration_max_upgrade: 30, +colors
		en = Dot_green.." Melee Strikes against Elites, Specials, Monstrosities extend the duration of {punk_rage:%s} from "..CNumb("0.3", "n_0_3_rgb").." to {rage_duration_extend_elites:%s} second.\n"
			.."\n"
			..Dot_green.." Additionally, the time before extending becomes diminished is now {rage_duration_max_upgrade:%s} seconds.",
		ru = Dot_green.." Удары в ближнем бою по элитным врагам, специалистам и чудовищам продлевают время действия способности {punk_rage:%s} с "..CNumb("0.3", "n_0_3_rgb").." до {rage_duration_extend_elites:%s} секунды.\n"
			.."\n"
			..Dot_green.." Дополнительно, ослабление эффекта продления времени за удары в ближнем бою увеличивается до {rage_duration_max_upgrade:%s} секунд.",
		["zh-tw"] = Dot_green.." 近戰命中精英、專家或巨獸時，{punk_rage:%s} 延長從 0.3 延長至 {rage_duration_extend_elites:%s} 秒。\n"
			.."\n"
			..Dot_green.." 效果縮減時間增加至 {rage_duration_max_upgrade:%s} 秒。",
	},
	--[+ ABILITY 2-3 - Forge's Bellow +]--	26.03.2026
	["loc_talent_broker_ability_punk_rage_sub_3_desc_02"] = { -- punk_rage: Rampage!, : +50%, duration: 5, s->seconds
		en = "Empowers {punk_rage:%s} to release a "..CKWord("Shout", "Shout_rgb").." on activation.\n"
			..Dot_nc.." Radius: "..CNumb("4.5", "n_4_5_rgb").." meters.\n"
			..Dot_nc.." Duration: {duration:%s} seconds.\n"
			.."\n"
			.."The "..CKWord("Shout", "Shout_rgb").." debuffs all enemies it strikes:\n"
			..Dot_green.." {attack_speed_reduction:%s} time between their attacks.\n"
			..Dot_green.." Inflicts "..CKWord("Stagger", "Stagger_rgb")..".\n"
			.."\n"
			.."The "..CKWord("Shout", "Shout_rgb").." repeats when {punk_rage:%s} ends.\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_eff"),
		ru = "Усиливает способность {punk_rage:%s}, заставляя вас издавать "..CKWord("Крик", "Shout_rgb_ru").." при активации.\n"
			..Dot_nc.." Радиус: "..CNumb("4.5", "n_4_5_rgb").." метра.\n"
			..Dot_nc.." Длится: {duration:%s} секунд.\n"
			.."\n"
			..CKWord("Крик", "Shout_rgb_ru").." ослабляет всех врагов, которых поражает:\n"
			..Dot_green.." {attack_speed_reduction:%s} к времени между их атаками.\n"
			..Dot_green.." Наносит "..CKWord("ошеломление", "oshelomlenie_rgb_ru")..".\n"
			.."\n"
			.."Этот "..CKWord("Крик", "Shout_rgb_ru").." повторяется после окончания действия способности {punk_rage:%s}\n"
			.."\n"
			..CPhrs("Doesnt_Stack_Scm_eff"),
		["zh-tw"] = "啟用 {punk_rage:%s} 時釋放一次大吼，半徑 4.5 米，持續 {duration:%s} 秒。\n"
			.."大吼對命中敵人施加減益：\n"
			..Dot_green.." {attack_speed_reduction:%s} 攻擊間隔時間。\n"
			..Dot_green.." "..CKWord("踉蹌", "Stagger_rgb_tw").."。\n"
			.."{punk_rage:%s} 結束時再重複一次。\n"
			..Dot_red.." 不與其他"..CKWord("巢都敗類", "cls_scm_rgb_tw").." 的相同效果疊加。",
	},
	--[+ ABILITY 2-4 - Pulverising Strikes +]--	26.03.2026
	["loc_talent_broker_ability_punk_rage_sub_2_desc"] = { -- punk_rage: Rampage!, cleave: +50%, melee_power: +2.5%, max_stacks: 10, s->seconds, +colors
		en = "While {punk_rage:%s} is active:\n"
			..Dot_green.." {cleave:%s} "..CKWord("Cleave", "Cleave_rgb")..".\n"
			.."\n"
			.."Every second while {punk_rage:%s} is active grants Stacks, up to {max_stacks:%s}.\n"
			.."\n"
			.."Per stack, you gain:\n"
			..Dot_green.." {melee_power:%s} Melee "..CKWord("Strength", "Strength_rgb")..", up to "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb")..".",
		ru = "Пока активно {punk_rage:%s} вы получаете:\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов.\n"
			.."\n"
			.."Каждую секунду, пока активно {punk_rage:%s}, вам даются заряды, вплоть до {max_stacks:%s}.\n"
			.."\n"
			.."За каждый заряд вы получаете:\n"
			..Dot_green.." {melee_power:%s} к "..CKWord("силе", "sile_rgb_ru").." атак ближнего боя, вплоть до "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb")..".",
		["zh-tw"] = "{punk_rage:%s} 啟用期間：\n"
			..Dot_green.." {cleave:%s} "..CKWord("順劈攻擊", "Cleave_rgb_tw").."。\n"
			.."\n"
			.."每秒增加一層，最多 {max_stacks:%s} 層。每層獲得：\n"
			..Dot_green.." {melee_power:%s} 近戰"..CKWord("威力", "Strength_rgb_tw").."，最多 +25%。",
	},
	--[+ ABILITY 3 - Stimm Supply +]--	26.03.2026
	["loc_talent_broker_ability_stimm_field_desc_3"] = { -- duration: 20, total_corruption_heal: 40, stimm_field: Stimm Supply, cooldown: 60, s->seconds, +colors
		en = "Deploy a refitted Medi-Pack on the ground, bolstering you and your Allies for {duration:%s} seconds.\n"
			.."\n"
			..Dot_nc.." Radius: "..CNumb("3", "n_3_rgb").." meters.\n"
			.."\n"
			.."Operatives breathing the Pack's gas heal "..CKWord("Corruption", "Corruption_rgb").." over time and become immune to it.\n"
			..Dot_green.." Removes "..CNumb("0.5", "n_0_5_rgb").." "..CKWord("Corruption Damage", "Corruptdmg_rgb").." every "..CNumb("0.25", "n_0_25_rgb").." seconds for all Allies in range. Up to {total_corruption_heal:%s}.\n"
			..Dot_green.." Heals "..CKWord("Corruption Damage", "Corruptdmg_rgb").." up to the next "..CKWord("Health", "Health_rgb").." segment.\n"
			.."\n"
			.."Additionally, if you have a Stimm equipped, {stimm_field:%s} will copy its contents and disperse them into the air, granting its effects to any nearby Allies.\n"
			.."\n"
			..Dot_nc.." Base Cooldown: {cooldown:%s} seconds.\n"
			..Dot_red.." While the {stimm_field:%s} is active, cooldown is paused and cannot be reduced.",
		ru = "Размещает переоборудованный медпак на земле, укрепляя вас и ваших союзников на {duration:%s} секунд.\n"
			.."\n"
			..Dot_nc.." Радиус: "..CNumb("3", "n_3_rgb").." метра.\n"
			.."\n"
			.."Оперативники, вдыхающие газ из медпака, лечат "..CKWord("порчу", "porchu_rgb_ru").." и получают иммунитет к ней на время.\n"
			..Dot_green.." Удаляет "..CNumb("0.5", "n_0_5_rgb").." "..CKWord("урона от порчи", "porchi_uron_rgb_ru").." каждые "..CNumb("0.25", "n_0_25_rgb").." секунды для всех союзников в радиусе. До {total_corruption_heal:%s}.\n"
			..Dot_green.." Лечит "..CKWord("урон от порчи", "porchi_uron_rgb_ru").." вплоть до следующего сегмента "..CKWord("здоровья", "zdorovia_rgb_ru")..".\n"
			.."\n"
			.."Дополнительно, если у вас экипирован стим, {stimm_field:%s} скопирует его содержимое и рассеет его в воздухе, предоставляя его эффекты всем ближайшим союзникам.\n"
			.."\n"
			..Dot_nc.." Базовое время восстановления: {cooldown:%s} секунд.\n"
			..Dot_red.." Пока {stimm_field:%s} активен, время восстановления останавливается и не может быть уменьшен.",
		["zh-tw"] = "在地面放置改裝醫包，加強你和盟友 {duration:%s} 秒。半徑 3 米。\n"
			.."\n"
			.."吸入氣體的成員治癒"..CKWord("腐敗", "Corruption_rgb_tw").." 並獲得免疫。\n"
			..Dot_green.." 每 0.25 秒移除 0.5 "..CKWord("腐敗傷害", "Corruptdmg_rgb_tw").."，最多 {total_corruption_heal:%s}。\n"
			..Dot_green.." 治癒"..CKWord("腐敗傷害", "Corruptdmg_rgb_tw").." 至下一個"..CKWord("生命", "Health_rgb_tw").." 段。\n"
			.."\n"
			.."若裝備了興奮劑，{stimm_field:%s} 會複製其內容並散布到空氣中，賦予附近盟友效果。\n"
			.."\n"
			..Dot_nc.." 基礎冷卻：{cooldown:%s} 秒。\n"
			..Dot_red.." {stimm_field:%s} 啟用期間暫停冷卻且不可縮短。",
	},
	--[+ ABILITY 3-1 - Practiced Deployment +]--	26.03.2026
	["loc_talent_broker_ability_stimm_field_sub_3_desc"] = { -- stimm_field: Stimm Supply
		en = "Resets {stimm_field:%s}"..CNumb("'s", "n__s_rgb").." cooldown when you:\n"
			..Dot_green.." Pick up a stimm,\n"
			..Dot_green.." Receive a stimm from an Ally,\n"
			..Dot_green.." The "..CKWord("Cartel Special Stimm", "Cartel_Stimm_rgb").." comes off cooldown.\n"
			.."\n"
			.."Activation Blocked by:\n"
			..Dot_red.." An active {stimm_field:%s}.\n"
			..Dot_red.." Swapping an equipped stimm for another one.",
		ru = "Сбрасывается время восстановления {stimm_field:%s}, когда вы:\n"
			..Dot_green.." Подбираете стим,\n"
			..Dot_green.." Получаете стим от союзника,\n"
			..Dot_green.." У "..CKWord("Особого стима Картеля", "Cartel_Stimm_rgb_ru").." заканчивается время восстановления.\n"
			.."\n"
			.."Активация заблокирована при:\n"
			..Dot_red.." Активном {stimm_field:%s}.\n"
			..Dot_red.." Замене экипированного стима на другой.",
		["zh-tw"] = "以下情況重置 {stimm_field:%s} 冷卻：\n"
			..Dot_green.." 拾取興奮劑，\n"
			..Dot_green.." 從盟友接受興奮劑，\n"
			..Dot_green.." 卡特爾特殊興奮劑冷卻結束。\n"
			.."\n"
			.."啟用被阻止情況：\n"
			..Dot_red.." {stimm_field:%s} 啟用期間。\n"
			..Dot_red.." 替換已裝備的興奮劑。",
	},
	--[+ ABILITY 3-2 - Booby Trap +]--	26.03.2026
	["loc_talent_broker_ability_stimm_field_sub_2_desc"] = { -- stimm_field: Stimm Supply, stacks: 7, toxin: Chem Toxin
		en = "Once its duration ends, {stimm_field:%s} explodes, infecting nearby Enemies with {stacks:%s} stacks of "..CKWord("Chem Toxin", "Chem_Tox_rgb")..".\n"
			.."\n"
			..Dot_nc.." Radius: "..CNumb("3", "n_3_rgb").." meters.\n"
			.."\n"
			..Dot_green.." Base "..CKWord("Damage", "Damage_rgb")..": "..CNumb("200", "n_200_rgb")..".",
		ru = "По истечении времени действия {stimm_field:%s} взрывается, заражая ближайших врагов {stacks:%s} зарядами "..CKWord("Хим-токсина", "Chem_Toxa_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Радиус: "..CNumb("3", "n_3_rgb").." метра.\n"
			.."\n"
			..Dot_green.." Базовый "..CKWord("урон", "uron_rgb_ru")..": "..CNumb("200", "n_200_rgb")..".",
		["zh-tw"] = "{stimm_field:%s} 持續時間結束時爆炸，對附近敵人施加 {stacks:%s} 層"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."。\n"
			..Dot_nc.." 半徑 3 米。\n"
			.."\n"
			..Dot_green.." 基礎"..CKWord("傷害", "Damage_rgb_tw").."： "..CNumb("200", "n_200_rgb").."。",
	},
	--[+ ABILITY 3-3 - Fast Acting Stimms +]--	26.03.2026
	["loc_talent_broker_ability_stimm_field_sub_1_desc"] = { -- stimm_field: Stimm Supply, duration: 5, linger_duration: 15, s->seconds, +colors
		en = Dot_red.." Duration of {stimm_field:%s} reduced from "..CNumb("20", "n_20_rgb").." to {duration:%s} seconds.\n"
			.."\n"
			..Dot_green.." Lingering effect continues for {linger_duration:%s} seconds after leaving the area.",
		ru = Dot_red.." Длительность способности {stimm_field:%s} сокращается с "..CNumb("20", "n_20_rgb").." до {duration:%s} секунд.\n"
			.."\n"
			..Dot_green.." Но его эффекты сохраняются {linger_duration:%s} секунд после выхода из области.",
		["zh-tw"] = Dot_red.." {stimm_field:%s} 持續時間從 20 秒縮短至 {duration:%s} 秒。\n"
			.."\n"
			..Dot_green.." 髖區後 {linger_duration:%s} 秒內持續生效。",
	},
--[+ +KEYSTONES - КЛЮЧЕВЫЕ+ +]--
	--[+ KEYSTONE 0-1 - Alley Rat +]--	26.03.2026
	["loc_talent_broker_passive_longer_dodges_desc"] = { -- dodge_distance_modifier: +50%
		en = Dot_green.." {dodge_distance_modifier:%s} Dodge Distance.",
		ru = Dot_green.." {dodge_distance_modifier:%s} к расстоянию уклонения.", -- Уличная крыса
		["zh-tw"] = Dot_green.." {dodge_distance_modifier:%s} 閃避距離。",
	},
	--[+ KEYSTONE 0-2 - Nimble +]--	26.03.2026
	["loc_talent_broker_passive_improved_dodges_desc_02"] = { -- dodge_distance_modifier: +25%, dodge_linger_time: +0.15, s->seconds, +colors
		en = Dot_green.." {dodge_distance_modifier:%s} Dodge Speed.\n"
			.."\n"
			..Dot_green.." {dodge_linger_time:%s} seconds Dodge linger time.",
		ru = Dot_green.." {dodge_distance_modifier:%s} к скорости уклонения.\n"
			.."\n"
			..Dot_green.." {dodge_linger_time:%s} секунды к длительности уклонения.",
		["zh-tw"] = Dot_green.." {dodge_distance_modifier:%s} 閃避速度。\n"
			.."\n"
			..Dot_green.." {dodge_linger_time:%s} 秒閃避持續時間。",
	},
	--[+ KEYSTONE 1 - Vulture’s Mark +]--	30.03.2026
	["loc_talent_broker_keystone_vultures_mark_on_kill_desc"] = { -- duration: 8, max_stacks: 3, ranged_damage: +5%, movement_speed: +5%, crit_chance: +5%, toughness: 15%, s->seconds, +colors
		en = "Killing Special or Elite enemy with a Ranged weapon grants you a Stacks of "..CKWord("Vulture's Mark", "VultsMark_rgb")..".\n"
			.."\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.." Per Stack you gain:\n"
			..Dot_green.." {ranged_damage:%s} Ranged "..CKWord("Damage", "Damage_rgb")..",\n"
			..Dot_green.." {movement_speed:%s} Movement Speed, and\n"
			..Dot_green.." {crit_chance:%s} Ranged "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb")..".\n"
			.."\n"
			.." While at Max Stacks, Special and Elite Ranged Kills restore to you and Allies in "..CKWord("Coherency", "Coherency_rgb")..":\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".",
		ru = "Убийство элитного врага или специалиста дальнобойным оружием даёт вам заряд "..CKWord("Метки стервятника", "VultsMark_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раза.\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.." За каждый заряд вы получаете:\n"
			..Dot_green.." {ranged_damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru")..",\n"
			..Dot_green.." {movement_speed:%s} к скорости движения, и\n"
			..Dot_green.." {crit_chance:%s} к "..CKWord("шансу критического выстрела", "sh_krit_vystrela_rgb_ru")..".\n"
			.."\n"
			.." При максимальных зарядах, убийства элитных врагов и специалистов оружием дальнего боя восстанавливают вам и союзникам в "..CKWord("сплочённости", "splochennosti_rgb_ru")..":\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".", -- Метка стервятника
		["zh-tw"] = "遠程武器擊殺特殊或精英敵人獲得一層"..CKWord("禿鷹標記", "VultsMark_rgb_tw").."。\n"
			..Dot_nc.." 持續 {duration:%s} 秒。最多 {max_stacks:%s} 層。\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.."每層獲得：\n"
			..Dot_green.." {ranged_damage:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."，\n"
			..Dot_green.." {movement_speed:%s} 移動速度，\n"
			..Dot_green.." {crit_chance:%s} 遠程"..CKWord("暴擊機率", "Crt_hit_chnc_rgb_tw").."。\n"
			.."\n"
			.."滿層時，遠程擊殺特殊或精英敵人恢復你和"..CKWord("協同", "Coherency_rgb_tw").." 盟友：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ KEYSTONE 1-1 - Vulture's Push +]--	26.03.2026
	["loc_talent_broker_keystone_vultures_mark_aoe_stagger_desc"] = { -- +colors
		en = "Killing Elite or Special enemies with Ranged Attacks creates a non-damaging explosion that "..CKWord("Staggers", "Staggers_rgb").." barely anything at your location.\n"
			.."\n"
			..Dot_nc.." Radius "..CNumb("3", "n_3_rgb").." meters.",
		ru = "Убийство элитных врагов или специалистов атаками дальнего боя создаёт не наносящий "..CKWord("урон", "uron_rgb_ru").." взрыв, который почти не "..CKWord("ошеломляет", "oshelomlaet_rgb_ru").." врагов вокруг вас.\n"
			.."\n"
			..Dot_nc.." Радиус "..CNumb("3", "n_3_rgb").." метров.",
		["zh-tw"] = "遠程擊殺精英或專家時，在你所在位置中心 3 米內造成不造成傷害的爆炸，"..CKWord("踉蹌", "Staggers_rgb_tw").." 附近敵人。",
	},
	--[+ KEYSTONE 1-2 - Vulture's Dodge +]--	26.03.2026
	["loc_talent_broker_keystone_vultures_mark_dodge_on_ranged_crit_desc"] = { -- duration: 1, s->second, +colors
		en = "Ranged "..CKWord("Critical Strikes", "Crit_strikes_rgb").." grant for {duration:%s} second:\n"
			..Dot_green.." Immunity to All attacks.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		ru = CKWord("Критические удары", "Krit_udary_rgb_ru").." в дальнем бою дают на {duration:%s} секунду:\n"
			..Dot_green.." Иммунитет ко всем атакам.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		["zh-tw"] = "遠程"..CKWord("暴擊打擊", "Crit_strikes_rgb_tw").." 獲得 {duration:%s} 秒：\n"
			..Dot_green.." 免疫所有攻擊。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
	},
	--[+ KEYSTONE 1-3 - Patient Hunter +]--	26.03.2026
	["loc_talent_broker_keystone_vultures_mark_increased_duration_desc"] = { -- duration: 12, s->seconds, +colors
		en = Dot_green.." Increases duration of "..CKWord("Vulture's Mark", "VultsMark_rgb").." from "..CNumb("8", "n_8_rgb").." to {duration:%s} seconds.",
		ru = Dot_green.." Увеличена длительность "..CKWord("Метки стервятника", "VultsMark_rgb_ru").." с "..CNumb("8", "n_8_rgb").." до {duration:%s} секунд.",
		["zh-tw"] = Dot_green.." "..CKWord("禿鷹標記", "VultsMark_rgb_tw").." 持續時間從 8 秒增加至 {duration:%s} 秒。",
	},
	--[+ KEYSTONE 2 - Adrenaline Frenzy +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_desc"] = { -- adrenaline: Adrenaline, on_crit: +1, duration: 2, max_stacks: 30, frenzy: Adrenaline Frenzy, melee_damage: +25%, attack_speed: +10%, frenzy_duration: 10, s->seconds, +colors
		en = "Melee Hits grants you a Stacks of "..CKWord("Adrenaline", "Adren_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Stacks last {duration:%s} seconds and are dropped one by one.\n"
			..CPhrs("Can_proc_mult")
			-- ..CPhrs("Can_be_refr").."\n"
			.."\n"
			..CKWord("Critical", "Critical_rgb").." Melee Hits grants:\n"
			..Dot_green.." {on_crit:%s} additional Stack.\n"
			.."\n"
			.."At Max Stacks, remove All Stacks of "..CKWord("Adrenaline", "Adren_rgb").." and gain {frenzy:%s} for {frenzy_duration:%s} seconds.\n"
			.."\n"
			.."{frenzy:%s} grants:\n"
			..Dot_green.." {melee_damage:%s} Melee "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {attack_speed:%s} Attack Speed.",
		ru = "Попадания в ближнем бою дают вам заряды "..CKWord("Адреналина", "Adren_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." Заряды длятся {duration:%s} секунды и сбрасываются по одному.\n"
			..CPhrs("Can_proc_mult")
			.."\n"
			..CKWord("Критические", "Kriticheskie_rgb_ru").." попадания в ближнем бою дают:\n"
			..Dot_green.." {on_crit:%s} дополнительный заряд.\n"
			.."\n"
			.."При максимальных зарядах, удаляются все заряды "..CKWord("Адреналина", "Adren_rgb_ru").." и вы получаете {frenzy:%s} на {frenzy_duration:%s} секунд.\n"
			.."\n"
			.."{frenzy:%s} даёт:\n"
			..Dot_green.." {melee_damage:%s} "..CKWord("урона", "uronu_rgb_ru").." в ближнем бою и\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки.", -- Адреналиновое безумие
		["zh-tw"] = "近戰命中獲得"..CKWord("腎上腺素", "Adren_rgb_tw").." 層數。最多 {max_stacks:%s} 層，持續 {duration:%s} 秒，逐一衰減。\n"
			.."\n"
			..CKWord("暴擊", "Critical_rgb_tw").." 近戰命中額外 +{on_crit:%s} 層。\n"
			.."\n"
			.."滿層時，消耗所有"..CKWord("腎上腺素", "Adren_rgb_tw").." 層數，獲得 {frenzy:%s} {frenzy_duration:%s} 秒。\n"
			.."{frenzy:%s} 提供：\n"
			..Dot_green.." {melee_damage:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").." 和\n"
			..Dot_green.." {attack_speed:%s} 攻擊速度。",
	},
	--[+ KEYSTONE 2-1 - Adrenaline Assassin +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_sub_1_desc"] = { -- stacks: +2, +colors
		en = CKWord("Weakspot Hits", "Weakspothits_rgb").." now grants:\n"
			..Dot_green.." {stacks:%s} additional Stacks of "..CKWord("Adrenaline", "Adren_rgb")..". Increases from "..CNumb("1", "n_1_rgb").." to "..CNumb("3", "n_3_rgb").." Stacks.\n"
			.."\n"
			..Dot_red.." Regular Melee Hits grants none.\n"
			.."\n"
			..Dot_green.." Non-"..CKWord("Weakspot", "Weakspot_rgb").." Melee hits that are "..CKWord("Critical", "Critical_rgb").." still generate {stacks:%s} Stacks.",
		ru = "Попадания в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru").." теперь дают:\n"
			..Dot_green.." {stacks:%s} дополнительных заряда "..CKWord("Адреналина", "Adren_rgb_ru")..". Увеличено с "..CNumb("1", "n_1_rgb").." до "..CNumb("3", "n_3_rgb").." зарядов.\n"
			.."\n"
			..Dot_red.." Обычные попадания в ближнем бою не дают зарядов.\n"
			.."\n"
			..Dot_green.." Попадания в ближнем бою не по "..CKWord("уязвимым местам", "ujazvimym_mestam_rgb_ru")..", но "..CKWord("критическими ударами", "krit_udarami_rgb_ru")..", всё ещё дают {stacks:%s} заряда.",
		["zh-tw"] = CKWord("弱點", "Weakspot_rgb_tw").." 命中現在給予 {stacks:%s} 額外"..CKWord("腎上腺素", "Adren_rgb_tw").." 層，從 1 增至 3 層。\n"
			..Dot_red.." 普通近戰命中不給予。\n"
			..Dot_green.." 非弱點卻暴擊的近戰命中，仍給予 {stacks:%s} 層。",
	},
	--[+ KEYSTONE 2-2 - Adrenaline Smiter +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_sub_2_desc"] = { -- stacks: +4, adrenaline: Adrenaline, elite_stacks: +10, +colors
		en = "Killing Blows now grants:\n"
			..Dot_green.." {stacks:%s} additional Stacks of "..CKWord("Adrenaline", "Adren_rgb")..". Increases from "..CNumb("1", "n_1_rgb").." to "..CNumb("5", "n_5_rgb").." Stacks.\n"
			.."\n"
			.."Elite Killing Blows grants:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("14", "n_14_rgb").." additional Stacks.\n"
			.."Increases to "..CNumb("15", "n_15_rgb").." Stacks.\n"
			.."\n"
			.."If the Attack is "..CKWord("Critical", "Critical_rgb")..", generates additional:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("1", "n_1_rgb").." Stack of "..CKWord("Adrenaline", "Adren_rgb").." per Enemy killed.\n"
			.."\n"
			..Dot_red.." Non-Killing Blows grants none.",
		ru = "Смертельные удары теперь дают:\n"
			..Dot_green.." {stacks:%s} дополнительных заряда "..CKWord("Адреналина", "Adren_rgb_ru")..". Увеличено с "..CNumb("1", "n_1_rgb").." до "..CNumb("5", "n_5_rgb").." зарядов.\n"
			.."\n"
			.."Смертельные удары по элитным врагам дают:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("14", "n_14_rgb").." дополнительных зарядов. Увеличено до "..CNumb("15", "n_15_rgb").." зарядов.\n"
			.."\n"
			..CKWord("Критические удары", "Krit_udary_rgb_ru").." дают:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("1", "n_1_rgb").." дополнительный заряд, в дополнение к другим зарядам "..CKWord("Адреналина", "Adren_rgb_ru").." за каждого убитого врага.\n"
			.."\n"
			..Dot_red.." Не смертельные удары не дают ничего.",
		["zh-tw"] = "譴殺現在給予 {stacks:%s} 額外"..CKWord("腎上腺素", "Adren_rgb_tw").." 層，從 1 增至 5 層。\n"
			.."譴殺精英額外 +14 層，增至 15 層。\n"
			..CKWord("暴擊", "Critical_rgb_tw").." 譴殺額外 +1 層/敵人。\n"
			..Dot_red.." 非譴殺不給予層數。",
	},
	--[+ KEYSTONE 2-3 - Stoked Rage +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_sub_3_desc"] = { -- frenzy: Adrenaline Frenzy, duration: 20, +colors
		en = Dot_green.." Increases duration of {frenzy:%s} from "..CNumb("10", "n_10_rgb").." to {duration:%s} seconds.",
		ru = Dot_green.." Увеличена длительность таланта {frenzy:%s} с "..CNumb("10", "n_10_rgb").." до {duration:%s} секунд.",
		["zh-tw"] = Dot_green.." {frenzy:%s} 持續時間從 10 秒增加至 {duration:%s} 秒。",
	},
	--[+ KEYSTONE 2-4 - Adrenaline Unbound +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_sub_5_desc"] = { -- frenzy: Adrenaline Frenzy, toughness: 5%, +colors
		en = "While {frenzy:%s} is active, you replenish:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." per second.",
		ru = "Пока активен {frenzy:%s}, вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду.",
		["zh-tw"] = "{frenzy:%s} 啟用期間，{toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").." /秒恢復。",
	},
	--[+ KEYSTONE 2-5 - Uncontrolled Aggression +]--	26.03.2026
	["loc_talent_broker_keystone_adrenaline_junkie_sub_4_desc"] = { -- adrenaline: Adrenaline, duration: 4, +colors
		en = Dot_green.." Increases duration of "..CKWord("Adrenaline", "Adren_rgb").." from "..CNumb("2", "n_2_rgb").." to {duration:%s} seconds.",
		ru = Dot_green.." Увеличена длительность "..CKWord("Адреналина", "Adren_rgb_ru").." с "..CNumb("2", "n_2_rgb").." до {duration:%s} секунд.",
		["zh-tw"] = Dot_green.." "..CKWord("腎上腺素", "Adren_rgb_tw").." 持續時間從 2 秒增加至 {duration:%s} 秒。",
	},
	--[+ KEYSTONE 3 - Chemical Dependency +]--	26.03.2026
	["loc_talent_broker_keystone_chemical_dependency_desc"] = { -- dependency: Dependency, duration: 90, : +10%, : 3, +colors
		en = "Using a Stimm grants you a Stack of {dependency:%s} for {duration:%s} seconds.\n"
			.."\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."Per Stack gain:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{cooldown_reduction:%s} "..CKWord("Ability Cooldown", "Ability_cd_rgb").." Reduction.",
		ru = "Использование стима даёт вам заряд "..CKWord("Зависимости", "Depend_rgb_ru").." на {duration:%s} секунд.\n"
			.."\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раза.\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."За каждый заряд вы получаете:\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").."{cooldown_reduction:%s} от времени "..CKWord("восстановления способности", "vost_sposobnosti_rgb_ru")..".", -- Зависимость от химии - Химическая зависимость
		["zh-tw"] = "使用興奮劑獲得 {dependency:%s} 層，持續 {duration:%s} 秒。最多 {max_stacks:%s} 層。\n"
			..CPhrs("Can_be_refr_drop_1").."\n"
			.."\n"
			.."每層獲得：\n"
			..Dot_green.." "..CNumb("-", "n_minus_rgb").." {cooldown_reduction:%s} "..CKWord("技能冷卻", "Ability_cd_rgb_tw").." 減少。",
	},
	--[+ KEYSTONE 3-1 - Chem Enhanced +]--	26.03.2026
	["loc_talent_broker_keystone_chemical_dependency_sub_1_desc"] = { -- dependency: Dependency, critical_chance: +5%, +colors
		en = Dot_green.." {critical_chance:%s} "..CKWord("Critical Hit Chance", "Crt_hit_chnc_rgb").." per Stack of {dependency:%s}.",
		ru = Dot_green.." {critical_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru").." за каждый заряд "..CKWord("Зависимости", "Depend_rgb_ru")..".",
		["zh-tw"] = Dot_green.." 每層 {dependency:%s} {critical_chance:%s} "..CKWord("暴擊命中機率", "Crt_hit_chnc_rgb_tw").."。",
	},
	--[+ KEYSTONE 3-2 - Chem Fortified +]--	26.03.2026
	["loc_talent_broker_keystone_chemical_dependency_sub_2_desc"] = { -- toughness: 50%, toughness: +5%, dependency: Dependency, +colors
		en = "Using a Stimm replenishes:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_green.." {toughness_damage_reduction:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb").." per Stack of {dependency:%s}.",
		ru = "Использование стима восстанавливает:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikost_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." {toughness_damage_reduction:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru").." за каждый заряд "..CKWord("Зависимости", "Depend_rgb_ru")..".",
		["zh-tw"] = "使用興奮劑恢復：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 每層 {dependency:%s} {toughness_damage_reduction:%s} "..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."。",
	},
	--[+ KEYSTONE 3-3 - Maxed Out Chems +]--	26.03.2026
	["loc_talent_broker_keystone_chemical_dependency_sub_3_desc"] = { -- : , +colors
		en = Dot_red.." Duration of {dependency:%s} Stacks reduced from "..CNumb("90", "n_90_rgb").." to {duration:%s} seconds.\n"
			.."\n"
			..Dot_green.." Max Stacks are increased from "..CNumb("3", "n_3_rgb").." to {max_stacks:%s}.",
		ru = Dot_red.." Длительность зарядов "..CKWord("Зависимости", "Depend_rgb_ru").." уменьшена с "..CNumb("90", "n_90_rgb").." до {duration:%s} секунд.\n"
			.."\n"
			..Dot_green.." Максимальное количество зарядов увеличено с "..CNumb("3", "n_3_rgb").." до {max_stacks:%s}.",
		["zh-tw"] = Dot_red.." {dependency:%s} 層數持續時間從 90 秒減短至 {duration:%s} 秒。\n"
			.."\n"
			..Dot_green.." 最大層數從 3 增加至 {max_stacks:%s}。",
	},
--[+ +PASSIVES - ПАССИВНЫЕ+ +]--
	--[+ Passive 1 - Voice of Tertium +]--	26.03.2026
	["loc_talent_broker_passive_restore_toughness_on_close_ranged_kill_desc"] = { -- toughness: +8%, toughness_elites: +15%, +colors
		en = "On Ranged Kill within "..CNumb("12.5", "n_12_5_rgb").." meters replenish:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			.."Elites and Specials instead replenish:\n"
			..Dot_green.." {toughness_elites:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
		ru = "При убийстве врага дальнобойной атакой в пределах "..CNumb("12.5", "n_12_5_rgb").." метров восполняется:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Элитные враги и специалисты восполняют:\n"
			..Dot_green.." {toughness_elites:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
		["zh-tw"] = "在 "..CNumb("12.5", "n_12_5_rgb").." 米內以遠程擊殺時，恢復：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			.."精英與專家敵人改為恢復：\n"
			..Dot_green.." {toughness_elites:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..CPhrs("Can_proc_mult_str"),
	},
	--[+ Passive 2 - Quick and Deadly +]--	26.03.2026
	["loc_talent_broker_passive_close_range_damage_on_dodge_desc"] = { -- damage_near: +15%, duration: 3, +colors
		en = "After a Successful Dodge you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage_near:%s} "..CKWord("Damage", "Damage_rgb").." against targets within "..CNumb("12.5", "n_12_5_rgb").." meters.\n"
			-- .."\n"
			.."_______________________________\n"
			.."Distance ("..CNumb("m", "n_meter_rgb").."):   "..CNumb("1", "n_1_rgb").."| "..CNumb("12.5", "n_12_5_rgb").."|   "..CNumb("15", "n_15_rgb").."|  "..CNumb("20", "n_20_rgb").."|   "..CNumb("25", "n_25_rgb").."| "..CNumb("30", "n_30_rgb")..CNumb("+", "n_plus_rgb").."\n"
			..CKWord("Damage", "Damage_rgb").." ("..CNumb("%", "pc_rgb").."):  "..CNumb("15", "n_15_rgb").."|    "..CNumb("15", "n_15_rgb").."| "..CKWord("~13", "n__13_rgb").."|   "..CKWord("~9", "n__9_rgb").."|   "..CKWord("~4", "n__4_rgb").."|   "..CNumb("0", "n_0_rgb").."\n"
			.."_______________________________\n"
			-- .."\n"
			-- ..CPhrs("Can_proc_mult_str")
			.."\n"
			.."Procs on successfully Dodging:\n"
			..Dot_nc.." Enemy Melee or Ranged attacks (except Gunners, Reaper, Sniper),\n"
			..Dot_nc.." Disabler attacks (Pox Hound jump, Trapper net, Mutant grab).",
		ru = "После успешного уклонения,вы получаете на {duration:%s} секунды:\n"
			..Dot_green.." {damage_near:%s} к "..CKWord("урону", "uronu_rgb_ru").." по целям в пределах "..CNumb("12.5", "n_12_5_rgb").." метров.\n"
			-- .."\n"
			.."_______________________________\n"
			.."Дистанция ("..CNumb("м", "n_metr_rgb").."):  "..CNumb("1", "n_1_rgb").."| "..CNumb("12.5", "n_12_5_rgb").."|  "..CNumb("15", "n_15_rgb").."| "..CNumb("20", "n_20_rgb").."| "..CNumb("25", "n_25_rgb").."| "..CNumb("30", "n_30_rgb")..CNumb("+", "n_plus_rgb").."\n"
			..CKWord("Урон", "Uron_rgb_ru").." ("..CNumb("%", "pc_rgb").."):          "..CNumb("15", "n_15_rgb").."|    "..CNumb("15", "n_15_rgb").."| "..CKWord("~13", "n__13_rgb").."| "..CKWord("~9", "n__9_rgb").."|  "..CKWord("~4", "n__4_rgb").."|   "..CNumb("0", "n_0_rgb").."\n"
			.."_______________________________\n"
			-- .."\n"
			-- ..CPhrs("Can_proc_mult_str")
			.."\n"
			.."Срабатывает при успешном уклонении от:\n"
			..Dot_nc.." Атак врагов в ближнем или дальнем бою (кроме стрельбы пулемётчика, жнеца, снайпера),\n"
			..Dot_nc.." Атак обездвиживающих врагов (прыжок чумной гончей, сетка скаба-ловца, захват мутанта).",
		["zh-tw"] = "成功閃避後，獲得 {duration:%s} 秒：\n"
			..Dot_green.." 對 "..CNumb("12.5", "n_12_5_rgb").." 米內目標造成 {damage_near:%s} "..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."_______________________________\n"
			.."距離 ("..CNumb("m", "n_meter_rgb").."):   "..CNumb("1", "n_1_rgb").."| "..CNumb("12.5", "n_12_5_rgb").."|   "..CNumb("15", "n_15_rgb").."|  "..CNumb("20", "n_20_rgb").."|   "..CNumb("25", "n_25_rgb").."| "..CNumb("30", "n_30_rgb")..CNumb("+", "n_plus_rgb").."\n"
			..CKWord("傷害", "Damage_rgb_tw").." ("..CNumb("%", "pc_rgb").."):  "..CNumb("15", "n_15_rgb").."|    "..CNumb("15", "n_15_rgb").."| "..CKWord("~13", "n__13_rgb").."|   "..CKWord("~9", "n__9_rgb").."|   "..CKWord("~4", "n__4_rgb").."|   "..CNumb("0", "n_0_rgb").."\n"
			.."_______________________________\n"
			.."\n"
			.."成功閃避下列攻擊時觸發：\n"
			..Dot_nc.." 敵人的近戰或遠程攻擊\n"
			.."   （砲手、收割者、狙擊手除外），\n"
			..Dot_nc.." 控制敵人的攻擊\n"
			.."   （瘟疫獵犬撲擊、陷阱兵網、突變者抓取）。",
	},
	--[+ Passive 3 - Precision Violence +]--	30.12.2025
	["loc_talent_broker_passive_restore_toughness_on_weakspot_kill_desc"] = { -- default: 4%, weakspot: 8%, critical: 12%, +colors
		en = "Melee Hits replenish:\n"
			..Dot_green.." {default:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			.."Melee "..CKWord("Critical Strikes", "Crit_strikes_rgb").." and "..CKWord("Weakspot Hits", "Weakspothits_rgb").." replenish:\n"
			..Dot_green.." {weakspot:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..CKWord("Critical", "Critical_rgb").." "..CKWord("Weakspot Hits", "Weakspothits_rgb").." replenish:\n"
			..Dot_green.." {critical:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_red.." Procs once per Melee Attack regardless of how many enemies have been hit.",
		ru = "Удары в ближнем бою восполняют:\n"
			..Dot_green.." {default:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..CKWord("Критические удары", "Krit_udary_rgb_ru").." и попадания в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru").." восполняют:\n"
			..Dot_green.." {weakspot:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..CKWord("Критические удары", "Krit_udary_rgb_ru").." в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru").." восполняют:\n"
			..Dot_green.." {critical:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_red.." Срабатывает раз за атаку ближнего боя независимо от количества поражённых врагов.",
		["zh-tw"] = "近戰命中恢復：\n"
			..Dot_green.." {default:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			.."近戰"..CKWord("暴擊打擊", "Crit_strikes_rgb_tw")
			.."與"..CKWord("弱點命中", "Weakspothits_rgb_tw").."恢復：\n"
			..Dot_green.." {weakspot:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..CKWord("暴擊", "Critical_rgb_tw").." "
			..CKWord("弱點命中", "Weakspothits_rgb_tw").."恢復：\n"
			..Dot_green.." {critical:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_red.." 每次近戰攻擊只觸發一次，"
			.."不受命中敵人數量影響。",
	},
	--[+ Passive 4 - In Your Face +]--	26.03.2026
	["loc_talent_broker_passive_close_ranged_damage_desc"] = { -- damage_near: +25%, range_near: 12.5, damage_far: +10%, range_far: 30, +colors
		en = Dot_green.." {damage_near:%s} Ranged "..CKWord("Damage", "Damage_rgb").." against targets within {range_near:%s} meters.\n"
			.."\n"
			..Dot_nc.." Scaling down to a minimum of {damage_far:%s} "..CKWord("Damage", "Damage_rgb").." at {range_far:%s} meters and beyond.",
		ru = Dot_green.." {damage_near:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru").." по целям в пределах {range_near:%s} метров.\n"
			.."\n"
			..Dot_nc.." Уменьшается до {damage_far:%s} к "..CKWord("урону", "uronu_rgb_ru").." на дистанции от {range_far:%s} метров и далее.", -- В харю
		["zh-tw"] = Dot_green.." 對 {range_near:%s} 米內目標造成 {damage_near:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 逐漸降低，至 {range_far:%s} 米及更遠時，"
			.."最低為 {damage_far:%s} "..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 5 - Calling for a Time Out +]--	26.03.2026
	["loc_talent_broker_passive_reduced_toughness_damage_during_reload_desc"] = { -- duration: 4, toughness_damage_taken_modifier: -25%, +colors
		en = "While Reloading and for {duration:%s} seconds after a Reload is finished, grants:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{toughness_damage_taken_modifier:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".",
		ru = "При перезарядке и на {duration:%s} секунды после её завершения вы получаете:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{toughness_damage_taken_modifier:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".",
		["zh-tw"] = "裝填期間與裝填完成後 {duration:%s} 秒，獲得：\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{toughness_damage_taken_modifier:%s} "
			..CKWord("韌性傷害減免", "Tghns_dmg_red_rgb_tw").."。",
	},
	--[+ Passive 6 - Burst of Energy +]--	26.03.2026
	["loc_talent_broker_passive_stun_immunity_on_toughness_broken_desc"] = { -- duration: 6, toughness: +50%, cooldown: 10, +colors
		en = "When "..CKWord("Toughness", "Toughness_rgb").." is broken you gain:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." and\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity for {duration:%s} seconds.\n"
			.."\n"
			..Dot_nc.." Cooldown: {cooldown:%s} seconds.",
		ru = "При потере всей "..CKWord("стойкости", "stoikosti_rgb_ru").." вы получаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." и\n"
			..Dot_green.." Иммунитет к "..CKWord("оглушению", "oglusheniu_rgb_ru").." на {duration:%s} секунд.\n"
			.."\n"
			..Dot_nc.." Восстановление: {cooldown:%s} секунд.",
		["zh-tw"] = CKWord("韌性", "Toughness_rgb_tw").."被擊破時，獲得：\n"
			..Dot_green.." {toughness:%s} "..CKWord("韌性", "Toughness_rgb_tw").."，並\n"
			..Dot_green.." {duration:%s} 秒"..CKWord("眩暈", "Stun_rgb_tw").."免疫。\n"
			.."\n"
			..Dot_nc.." 冷卻：{cooldown:%s} 秒。",
	},
	--[+ Passive 7 - Sticky Hands +]--	26.03.2026
	["loc_talent_broker_passive_reduce_swap_time_desc"] = { -- wield_speed: +40%, recoil: -10%, spread: -30%, +colors
		en = Dot_green.." {wield_speed:%s} Swap Speed.\n"
			.."\n"
			.."While firing from the hip or bracing you gain:\n"
			..Dot_green.." {recoil:%s} Recoil and\n"
			..Dot_green.." {spread:%s} Spread.\n"
			.."\n"
			..Dot_nc.." Can be braced: Autopistol, Braced Autoguns, Dual Autopistols and Dual Stub Pistols.\n"
			.."\n"
			..Dot_nc.." Swap Speed reduces the time of wielding actions when Swapping item slots (Weapons, Grenades, Stimms, Medpacks, Ammo crates, Books, etc).",
		ru = Dot_green.." {wield_speed:%s} к скорости смены оружия и предметов.\n"
			.."\n"
			.."При стрельбе от бедра или во время прицеливания вы получаете:\n"
			..Dot_green.." {recoil:%s} к отдаче и\n"
			..Dot_green.." {spread:%s} к разбросу.\n"
			.."\n"
			..Dot_nc.." Прицеливание работает у: автопистолета, усиленного автомата, парных автопистолетов, парных стаб-пистолетов.\n"
			.."\n"
			..Dot_nc.." Скорость смены оружия и предметов сокращает время действий при смене слотов (оружие, гранаты, стимы, медпаки, ящики с боеприпасами, книги и т.д.).",
		["zh-tw"] = Dot_green.." {wield_speed:%s} 切換速度。\n"
			.."\n"
			.."腰射或架槍射擊時，獲得：\n"
			..Dot_green.." {recoil:%s} 後座力，並\n"
			..Dot_green.." {spread:%s} 擴散。\n"
			.."\n"
			..Dot_nc.." 可架槍武器：自動手槍、架勢自動槍、"
			.."雙持自動手槍與雙持短管手槍。\n"
			.."\n"
			..Dot_nc.." 切換速度會縮短切換物品欄位時的取出動作\n"
			.."   （武器、手雷、興奮劑、醫療包、彈藥箱、書籍等）。",
	},
	--[+ Passive 8 - A Tertium Welcome +]--	26.03.2026
	["loc_talent_broker_passive_first_target_damage_desc"] = { -- damage: +15%, +colors
		en = Dot_green.." {damage:%s} Melee "..CKWord("Damage", "Damage_rgb").." on first Enemy hit with each attack.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя по первому врагу при каждой атаке.",
		["zh-tw"] = Dot_green.." 每次攻擊命中的第一個敵人，"
			.."受到 {damage:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 9 - Speedloader +]--	26.03.2026
	["loc_talent_broker_passive_reload_speed_on_close_kill_desc"] = { -- reload_speed: +30%, duration: 8, +colors
		en = "On Ranged Kill within "..CNumb("12.5", "n_12_5_rgb").." meters you gain for {duration:%s} seconds:\n"
			..Dot_green.." {reload_speed:%s} Reload Speed.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		ru = "При убийстве врага дальнобойной атакой в пределах "..CNumb("12.5", "n_12_5_rgb").." метров вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {reload_speed:%s} к скорости перезарядки.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		["zh-tw"] = "在 "..CNumb("12.5", "n_12_5_rgb").." 米內以遠程擊殺時，獲得 {duration:%s} 秒：\n"
			..Dot_green.." {reload_speed:%s} 裝填速度。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
	},
	--[+ Passive 10 - Float Like a Butterfly +]--	26.03.2026
	["loc_talent_broker_passive_ninja_grants_crit_chance_desc"] = { -- duration: 3, critical_strike_chance: +20%, +colors
		en = "Perfect Blocks and Successful Dodges grants for {duration:%s} seconds:\n"
			..Dot_green.." {critical_strike_chance:%s} "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb")..".\n"
			.."\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.."Procs on perfect Block.\n"
			.."\n"
			.."Procs on successfully Dodging:\n"
			..Dot_nc.." Enemy Melee or Ranged attacks (except Gunners, Reaper, Sniper),\n"
			..Dot_nc.." Disabler attacks (Pox Hound jump, Trapper net, Mutant grab).",
		ru = "Идеальные блоки и успешные уклонения дают на {duration:%s} секунды:\n"
			..Dot_green.." {critical_strike_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.."Срабатывает при идеальном блоке.\n"
			.."\n"
			.."Срабатывает при успешном уклонении от:\n"
			..Dot_nc.." Атак врагов в ближнем или дальнем бою (кроме стрельбы пулемётчика, жнеца, снайпера),\n"
			..Dot_nc.." Атак обездвиживающих врагов (прыжок чумной гончей, сетка скаба-ловца, захват мутанта).",
		["zh-tw"] = "完美格擋與成功閃避會獲得 {duration:%s} 秒：\n"
			..Dot_green.." {critical_strike_chance:%s} "..CKWord("暴擊打擊機率", "Crt_chnc_r_rgb_tw").."。\n"
			.."\n"
			..CPhrs("Can_be_refr").."\n"
			.."\n"
			.."完美格擋時觸發。\n"
			.."\n"
			.."成功閃避下列攻擊時觸發：\n"
			..Dot_nc.." 敵人的近戰或遠程攻擊\n"
			.."   （砲手、收割者、狙擊手除外），\n"
			..Dot_nc.." 控制敵人的攻擊\n"
			.."   （瘟疫獵犬撲擊、陷阱兵網、突變者抓取）。",
	},
	--[+ Passive 11 - Regained Posture +]--	26.03.2026
	["loc_talent_broker_passive_stamina_on_successful_dodge_desc"] = { -- stamina: +10%, +colors
		en = Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb").." on Successful Dodge.\n"
			.."\n"
			.."Procs on successfully Dodging:\n"
			..Dot_nc.." Enemy Melee or Ranged attacks (except Gunners, Reaper, Sniper),\n"
			..Dot_nc.." Disabler attacks (Pox Hound jump, Trapper net, Mutant grab).",
		ru = Dot_green.." {stamina:%s} к "..CKWord("выносливости", "vynoslivosti_rgb_ru").." при успешном уклонении.\n"
			.."\n"
			.."Срабатывает при успешном уклонении от:\n"
			..Dot_nc.." Атак врагов в ближнем или дальнем бою (кроме стрельбы пулемётчика, жнеца, снайпера),\n"
			..Dot_nc.." Атак обездвиживающих врагов (прыжок чумной гончей, сетка скаба-ловца, захват мутанта).",
		["zh-tw"] = Dot_green.." 成功閃避時獲得 {stamina:%s} "..CKWord("耐力", "Stamina_rgb_tw").."。\n"
			.."\n"
			.."成功閃避下列攻擊時觸發：\n"
			..Dot_nc.." 敵人的近戰或遠程攻擊\n"
			.."   （砲手、收割者、狙擊手除外），\n"
			..Dot_nc.." 控制敵人的攻擊\n"
			.."   （瘟疫獵犬撲擊、陷阱兵網、突變者抓取）。",
	},
	--[+ Passive 12 - Tis but a Scratch +]--	26.03.2026
	["loc_talent_broker_passive_replenish_toughness_on_ranged_toughness_damage_desc"] = { -- toughness: 30%, duration: 3, +colors
		en = "Taking a Ranged "..CKWord("Toughness Damage", "Tghns_dmg_rgb")..", while "..CKWord("Toughness", "Toughness_rgb").." is above "..CNumb("0", "n_0_rgb")..", replenishes:\n"
			..Dot_green.." "..CNumb("10%", "pc_10_rgb").." "..CKWord("Toughness", "Toughness_rgb").." per second for {duration:%s} seconds, up to {toughness:%s}.\n"
			.."\n"
			..Dot_nc.." Losing all "..CKWord("Toughness", "Toughness_rgb").." cancels the effect.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		ru = "Получение дальнобойного "..CKWord("урона стойкости", "stoikosti_urona_rgb_ru")..", при "..CKWord("стойкости", "stoikosti_rgb_ru").." выше "..CNumb("0", "n_0_rgb")..", восполняет:\n"
			..Dot_green.." "..CNumb("10%", "pc_10_rgb").." "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду в течение {duration:%s} секунд, вплоть до {toughness:%s}.\n"
			.."\n"
			..Dot_nc.." Потеря всей "..CKWord("стойкости", "stoikosti_rgb_ru").." отменяет эффект.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		["zh-tw"] = "在"..CKWord("韌性", "Toughness_rgb_tw").."高於 "..CNumb("0", "n_0_rgb").." 時，"
			.."受到遠程"..CKWord("韌性傷害", "Tghns_dmg_rgb_tw").."會恢復：\n"
			..Dot_green.." 每秒 "..CNumb("10%", "pc_10_rgb").." "..CKWord("韌性", "Toughness_rgb_tw").."，"
			.."持續 {duration:%s} 秒，最高 {toughness:%s}。\n"
			.."\n"
			..Dot_nc.." 失去所有"..CKWord("韌性", "Toughness_rgb_tw").."會取消此效果。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
	},
	--[+ Passive 13 - Slippery Customer +]--	26.03.2026
	-- ["loc_talent_broker_passive_dodge_melee_on_slide_desc"] = {
		-- en = "While sliding, you count as Dodging against Melee Attacks.",
		-- ru = "При подкате вы входите в состояние уклонения от атак ближнего боя.",
	-- },
	--[+ Passive 14 - Ramping Backstabs +]--	26.03.2026
	["loc_talent_broker_passive_ramping_backstabs_desc"] = { -- power: +10%, stacks: 5, +colors
		en = "Backstabs grant per Stack:\n"
			..Dot_green.." {power:%s} Melee "..CKWord("Strength", "Strength_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			..Dot_nc.." Up to "..CNumb("+", "n_plus_rgb")..CNumb("50%", "n_50_rgb").." Melee "..CKWord("Strength", "Strength_rgb")..".\n"
			.."\n"
			..Dot_red.." Regular Melee Hits will instead Remove All Stacks.",
		ru = "Удары в спину дают за каждый заряд:\n"
			..Dot_green.." {power:%s} к "..CKWord("силе", "sile_rgb_ru").." в ближнем бою.\n"
			.."\n"
			..Dot_nc.." Суммируется {stacks:%s} раз.\n"
			..Dot_nc.." До "..CNumb("+", "n_plus_rgb")..CNumb("50%", "n_50_rgb").." к "..CKWord("силе", "sile_rgb_ru")..".\n"
			.."\n"
			..Dot_red.." Обычные удары в ближнем бою снимают все заряды.",
		["zh-tw"] = "背刺每層提供：\n"
			..Dot_green.." {power:%s} 近戰"..CKWord("威力", "Strength_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 可疊加 {stacks:%s} 層。\n"
			..Dot_nc.." 最高 "..CNumb("+", "n_plus_rgb")..CNumb("50%", "n_50_rgb").." 近戰"..CKWord("威力", "Strength_rgb_tw").."。\n"
			.."\n"
			..Dot_red.." 一般近戰命中會改為移除所有層數。",
	},
	--[+ Passive 15 - Sample Collector +]--	26.03.2026
	["loc_talent_broker_passive_stimm_cd_on_kill_desc"] = { -- restore: 1%, restore_toxined: 2%, +colors
		en = "Killing an enemy with any Attack reduces the remaining "..CKWord("Cooldown", "Cd_rgb").." of "..CKWord("Cartel Special Stimm", "Cartel_Stimm_rgb")..".\n"
			.."\n"
			.."Reduction amount per kill:\n"
			..Dot_green.." Any attack: "..CNumb("-", "n_minus_rgb").."{restore:%s}.\n"
			..Dot_green.." "..CKWord("Chem Toxin", "Chem_Tox_rgb").." tick: "..CNumb("-", "n_minus_rgb").."{restore_toxined:%s}.\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
			-- .."\n"
			-- ..Dot_nc.." This Talent only works after "..CKWord("Cartel Special Stimm", "Cartel_Stimm_rgb").."'s active effect has ended.",
		ru = "Убийство врага любой атакой сокращает оставшееся время восстановления "..CKWord("Особого стима Картеля", "Cartel_Stimm_rgb_ru")..".\n"
			.."\n"
			.."Сокращение восстановления за убийство врага:\n"
			..Dot_green.." Любой атакой: "..CNumb("-", "n_minus_rgb").."{restore:%s}.\n"
			..Dot_green.." "..CKWord("Хим-токсином", "Chem_Toxom_rgb_ru")..": "..CNumb("-", "n_minus_rgb").."{restore_toxined:%s}.\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
			-- .."\n"
			-- ..Dot_nc.." Этот талант срабатывает только после окончания действия "..CKWord("Особого стима Картеля", "Cartel_Stimm_rgb_ru")..".",
		["zh-tw"] = "以任何攻擊擊殺敵人時，縮短"
			..CKWord("卡特爾特製興奮劑", "Cartel_Stimm_rgb_tw").."剩餘"..CKWord("冷卻", "Cd_rgb_tw").."。\n"
			.."\n"
			.."每次擊殺的縮短量：\n"
			..Dot_green.." 任意攻擊： "..CNumb("-", "n_minus_rgb").."{restore:%s}。\n"
			..Dot_green.." "..CKWord("化學毒素", "Chem_Tox_rgb_tw").."跳傷： "..CNumb("-", "n_minus_rgb").."{restore_toxined:%s}。\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
	},
	--[+ Passive 16 - Jittery +]--	26.03.2026
	["loc_talent_broker_passive_improved_dodges_at_full_stamina_desc"] = { -- stamina: 75%, dodge_cooldown_reset_modifier: +40%, +colors
		en = "While "..CKWord("Stamina", "Stamina_rgb").." is above {stamina:%s}:\n"
			..Dot_green.." {dodge_cooldown_reset_modifier:%s} Dodge Recovery Speed.\n"
			.."\n"
			..Dot_green.." Apply after the regular Dodge.\n"
			..Dot_red.." Does not apply after Dodge-slide.",
		ru = "При "..CKWord("выносливости", "vynoslivosti_rgb_ru").." выше {stamina:%s} вы получаете:\n"
			..Dot_green.." {dodge_cooldown_reset_modifier:%s} к скорости восстановления уклонений.\n"
			.."\n"
			..Dot_green.." Применяется после обычного уклонения.\n"
			..Dot_red.." Не применяется после уклонения с подкатом.",
		["zh-tw"] = CKWord("耐力", "Stamina_rgb_tw").."高於 {stamina:%s} 時：\n"
			..Dot_green.." {dodge_cooldown_reset_modifier:%s} 閃避恢復速度。\n"
			.."\n"
			..Dot_green.." 會在一般閃避後套用。\n"
			..Dot_red.." 不會在滑步閃避後套用。",
	},
	--[+ Passive 17 - Long Lasting +]--	26.03.2026
	["loc_talent_broker_passive_stimm_increased_duration_desc"] = { -- duration_increase: +5, +colors
		en = Dot_green.." {duration_increase:%s} seconds to base duration of "..CKWord("Celerity Stimm", "Celerity_Stimm_rgb")..", "..CKWord("Combat Stimm", "Combat_Stimm_rgb")..", "..CKWord("Concentration Stimm", "Conc_Stimm_rgb")..", and "..CKWord("Cartel Special Stimm", "Cartel_Stimm_rgb")..". Increases from "..CNumb("15", "n_15_rgb").." to "..CNumb("20", "n_20_rgb").." seconds.\n"
			.."\n"
			..Dot_nc.." Only increases the duration of Stimms that are applied to you.\n"
			.."\n"
			..Dot_red.." Does not increase the "..CNumb("8", "n_8_rgb").." seconds duration of "..CKWord("Med Stimm", "Med_Stimm_rgb")..".",
		ru = Dot_green.." {duration_increase:%s} секунд к базовой длительности "..CKWord("Стима скорости", "Celerity_Stimm_rgb_ru")..", "..CKWord("Боевого стима", "Combat_Stimm_rgb_ru")..", "..CKWord("Стима концентрации", "Conc_Stimm_rgb_ru").." и "..CKWord("Особого стима Картеля", "Cartel_Stimm_rgb_ru")..". Увеличивается с "..CNumb("15", "n_15_rgb").." до "..CNumb("20", "n_20_rgb").." секунд.\n"
			.."\n"
			..Dot_nc.." Увеличивает длительность только стимов, применённых к вам.\n"
			.."\n"
			..Dot_red.." Не увеличивает "..CNumb("8", "n_8_rgb").."-секундную длительность "..CKWord("Мед стима", "Med_Stimm_rgb_ru")..".",
		["zh-tw"] = Dot_green.." "..CKWord("敏捷興奮劑", "Celerity_Stimm_rgb_tw").."、"
			..CKWord("戰鬥興奮劑", "Combat_Stimm_rgb_tw").."、"
			..CKWord("專注興奮劑", "Conc_Stimm_rgb_tw").."與"
			..CKWord("卡特爾特製興奮劑", "Cartel_Stimm_rgb_tw")
			.."的基礎持續時間 {duration_increase:%s} 秒。\n"
			..Dot_nc.." 從 "..CNumb("15", "n_15_rgb").." 秒提高至 "..CNumb("20", "n_20_rgb").." 秒。\n"
			.."\n"
			..Dot_nc.." 只會提高套用在你身上的興奮劑持續時間。\n"
			.."\n"
			..Dot_red.." 不會提高"..CKWord("醫療興奮劑", "Med_Stimm_rgb_tw")
			.."的 "..CNumb("8", "n_8_rgb").." 秒持續時間。",
	},
	--[+ Passive 18 - Blessed Stimms +]--	26.03.2026
	["loc_talent_broker_passive_stimm_cleanse_on_kill_desc"] = { -- cleanse_amount: 1%, cleanse_threshold: 50%, +colors
		en = "While Stimmed, Kills clear:\n"
			..Dot_green.." {cleanse_amount:%s} "..CKWord("Corruption", "Corruption_rgb")..".\n"
			.."\n"
			..Dot_green.." Heals {cleanse_threshold:%s} "..CKWord("Corruption Damage", "Corruptdmg_rgb").." up to the next "..CKWord("Health", "Health_rgb").." segment.\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
		ru = "Под действием стимов убийства снимают:\n"
			..Dot_green.." {cleanse_amount:%s} "..CKWord("порчи", "porchi_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." Лечит {cleanse_threshold:%s} "..CKWord("урона от порчи", "porchi_urona_rgb_ru").." до следующего сегмента "..CKWord("здоровья", "zdorovia_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
		["zh-tw"] = "受興奮劑影響時，擊殺會清除：\n"
			..Dot_green.." {cleanse_amount:%s} "..CKWord("腐敗", "Corruption_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 治療 {cleanse_threshold:%s} "..CKWord("腐敗傷害", "Corruptdmg_rgb_tw")
			.."，直到下一個"..CKWord("生命值", "Health_rgb_tw").."分段。\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
	},
	--[+ Passive 19 - Swift Endurance +]--	26.03.2026
	["loc_talent_broker_passive_stamina_grants_atk_speed_desc"] = { -- attack_speed_increase: +2%, +colors
		en = Dot_green.." {attack_speed_increase:%s} Melee Attack Speed for each current "..CKWord("Stamina", "Stamina_rgb")..".",
		ru = Dot_green.." {attack_speed_increase:%s} к скорости атак ближнего боя за каждую единицу текущей "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".",
		["zh-tw"] = Dot_green.." 目前每有一格"..CKWord("耐力", "Stamina_rgb_tw")
			.."，獲得 {attack_speed_increase:%s} 近戰攻擊速度。",
	},
	--[+ Passive 20 - Punching Above One's Weight +]--	26.03.2026
	["loc_talent_broker_passive_damage_vs_elites_monsters_desc"] = { -- multiplier: +15%, +colors
		en = Dot_green.." {multiplier:%s} "..CKWord("Damage", "Damage_rgb").." against Elites and Monstrosities.\n"
			.."\n"
			..Dot_nc.." Breeds with Elite or Monster tag: Beast of Nurgle, Bulwark, Chaos Spawn, Crusher, Daemonhost, Gunners, Mauler, Pack Master, Plague Ogryn, Plasma Gunner, Radio Operator, Ragers, Reaper, Shotgunners.",
		ru = Dot_green.." {multiplier:%s} к "..CKWord("урону", "uronu_rgb_ru").." по элитным врагам и чудовищам.\n"
			.."\n"
			..Dot_nc.." Типы элитных врагов и чудовищ: Зверь Нургла, Отродье Хаоса, Чумной огрин, бастион, берсерк, демонхост, жнец, загонщик, крушитель, палач, плазмомётчик, пулемётчики, радист, скабы с дробовиками.",
		["zh-tw"] = Dot_green.." 對精英與巨獸造成 {multiplier:%s} "..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 具有精英或巨獸標籤的品種：納垢巨獸、"
			.."堡壘、混沌魔物、粉碎者、惡魔宿主、砲手、"
			.."大槌、群主、瘟疫歐格林、電漿槍手、"
			.."通訊兵、狂怒者、收割者、霰彈兵。",
	},
	--[+ Passive 21 - Hive City Brawler +]--	26.03.2026
	["loc_talent_broker_passive_dr_damage_tradeoff_on_stamina_desc"] = { -- damage_increase: 20%, damage_reduction: 20%, +colors
		en = Dot_green.." Up to "..CNumb("+", "n_plus_rgb").."{damage_increase:%s} Melee "..CKWord("Damage", "Damage_rgb").." depending on spent "..CKWord("Stamina", "Stamina_rgb")..".\n"
			.."\n"
			..Dot_green.." Up to "..CNumb("+", "n_plus_rgb").."{damage_reduction:%s} "..CKWord("Damage", "Damage_rgb").." Reduction, depending on available "..CKWord("Stamina", "Stamina_rgb")..".",
		ru = Dot_green.." До "..CNumb("+", "n_plus_rgb").."{damage_increase:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя в зависимости от потраченной "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." До "..CNumb("+", "n_plus_rgb").."{damage_reduction:%s} к "..CKWord("снижению урона", "snu_ur_stoikosti_rgb_ru").." в зависимости от оставшейся "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".",
		["zh-tw"] = Dot_green.." 依消耗的"..CKWord("耐力", "Stamina_rgb_tw")
			.."，最高獲得 "..CNumb("+", "n_plus_rgb").."{damage_increase:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 依可用的"..CKWord("耐力", "Stamina_rgb_tw")
			.."，最高獲得 "..CNumb("+", "n_plus_rgb").."{damage_reduction:%s} "..CKWord("傷害", "Damage_rgb_tw").."減免。",
	},
	--[+ Passive 22 - Cheap Shots +]--	26.03.2026
	["loc_talent_broker_passive_damage_vs_heavy_staggered_desc_02"] = { -- power_light: +10%, power_heavy: +15%, +colors
		en = Dot_green.." {power_light:%s} "..CKWord("Strength", "Strength_rgb").." against "..CKWord("Staggered", "Staggered_rgb").." Enemies.\n"
			.."\n"
			..Dot_green.." {power_heavy:%s} "..CKWord("Strength", "Strength_rgb").." against Medium and Heavy "..CKWord("Staggered", "Staggered_rgb").." Enemies.\n"
			.."\n"
			..CNote("Pwr_note"),
		ru = Dot_green.." {power_light:%s} к "..CKWord("силе", "sile_rgb_ru").." против "..CKWord("ошеломлённых", "oshelomlennyh_rgb_ru").." врагов.\n"
			.."\n"
			..Dot_green.." {power_heavy:%s} к "..CKWord("силе", "sile_rgb_ru").." против средне и сильно "..CKWord("ошеломлённых", "oshelomlennyh_rgb_ru").." врагов.\n"
			.."\n"
			..CNote("Pwr_note"),
		["zh-tw"] = Dot_green.." 對"..CKWord("踉蹌", "Staggered_rgb_tw").."敵人造成 {power_light:%s} "..CKWord("威力", "Strength_rgb_tw").."。\n"
			.."\n"
			..Dot_green.." 對中度與重度"..CKWord("踉蹌", "Staggered_rgb_tw")
			.."敵人造成 {power_heavy:%s} "..CKWord("威力", "Strength_rgb_tw").."。\n"
			.."\n"
			..CNote("Pwr_note"),
	},
	--[+ Passive 23 - Battering Strikes +]--	26.03.2026
	["loc_talent_broker_passive_melee_cleave_on_melee_kill_desc"] = { -- duration: 5, multiplier: +10%, max_stacks: 5, +colors
		en = "Melee Kills grant for {duration:%s} seconds, per Stack:\n"
			..Dot_green.." {multiplier:%s} Melee "..CKWord("Cleave", "Cleave_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Up to "..CNumb("+", "n_plus_rgb")..CNumb("50%", "pc_50_rgb").." Melee "..CKWord("Cleave", "Cleave_rgb")..".\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
		ru = "Убийства атаками ближнего боя дают на {duration:%s} секунд, за каждый заряд:\n"
			..Dot_green.." {multiplier:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов в ближнем бою.\n"
			.."\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." До "..CNumb("+", "n_plus_rgb")..CNumb("50%", "pc_50_rgb").." к "..CKWord("рассечению", "rassecheniu_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
		["zh-tw"] = "近戰擊殺會使每層提供 {duration:%s} 秒：\n"
			..Dot_green.." {multiplier:%s} 近戰"..CKWord("順劈攻擊", "Cleave_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 可疊加 {max_stacks:%s} 層。\n"
			..Dot_nc.." 最高 "..CNumb("+", "n_plus_rgb")..CNumb("50%", "pc_50_rgb").." 近戰"..CKWord("順劈攻擊", "Cleave_rgb_tw").."。\n"
			.."\n"
			..CPhrs("Can_proc_mult"),
	},
	--[+ Passive 24 - Coated Weaponry +]--	26.03.2026
	["loc_talent_broker_passive_melee_attacks_apply_toxin_desc"] = { -- stacks: 1, toxin: Chem Toxin, +colors
		en = Dot_green.." {stacks:%s} Stack of "..CKWord("Chem Toxin", "Chem_Tox_rgb").." applied to enemies by Melee "..CKWord("Critical Strikes", "Crit_strikes_rgb")..".\n"
			.."\n"
			..CPhrs("Can_appl_thr_shldsb"),
		ru = Dot_green.." {stacks:%s} заряд "..CKWord("Хим-токсина", "Chem_Toxa_rgb_ru").." накладывается на врагов "..CKWord("критическими ударами", "krit_udarami_rgb_ru").." в ближнем бою.\n"
			.."\n"
			..CPhrs("Can_appl_thr_shldsb"),
		["zh-tw"] = Dot_green.." 近戰"..CKWord("暴擊打擊", "Crit_strikes_rgb_tw")
			.."會對敵人施加 {stacks:%s} 層"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."。\n"
			.."\n"
			..CPhrs("Can_appl_thr_shldsb"),
	},
	--[+ Passive 25 - Ammo Jack +]--	26.03.2026
	["loc_talent_broker_passive_extended_mag_desc"] = { -- clip_size: +15%, +colors
		en = Dot_green.." {clip_size:%s} Clip Size.\n"
			..Dot_nc.." Rounded up.",
		ru = Dot_green.." {clip_size:%s} к ёмкости магазина.\n"
			..Dot_nc.." Округляется в большую сторону.",
		["zh-tw"] = Dot_green.." {clip_size:%s} 彈匣容量。\n"
			..Dot_nc.." 無條件進位。",
	},
	--[+ Passive 26 - Pickpocket +]--	26.03.2026
	["loc_talent_broker_passive_low_ammo_regen_desc_04"] = { -- ammo_threshold: 20%, +colors
		en = "While current Ammo in reserve is below {ammo_threshold:%s}, killing an Elite or Specialist Enemy with Melee Attack sets the Ammo count in reserve to:\n"
			..Dot_green.." {ammo_threshold:%s} of Max Ammo.",
		ru = "При запасе боеприпасов ниже {ammo_threshold:%s}, убийство элитных врагов или специалистов атакой ближнего боя восстанавливает запас боеприпасов до:\n"
			..Dot_green.." {ammo_threshold:%s} от максимального запаса.",
		["zh-tw"] = "目前備用彈藥低於 {ammo_threshold:%s} 時，\n"
			.."以近戰攻擊擊殺精英或專家敵人會將備用彈藥設為：\n"
			..Dot_green.." 最大彈藥的 {ammo_threshold:%s}。",
	},
	--[+ Passive 27 - Hyper-Critical +]--	26.03.2026
	["loc_talent_broker_passive_melee_crit_instakill_desc"] = { -- threshold: 2, +colors
		en = CKWord("Critical", "Critical_rgb").." Melee Attacks instantly kill Human Sized Enemies if their current "..CKWord("Health", "Health_rgb").." is less than {threshold:%s} times the amount of "..CKWord("Damage", "Damage_rgb").." of the "..CKWord("Critical Strikes", "Crit_strikes_rgb")..".\n"
			.."\n"
			..Dot_nc.." ["..CKWord("Crit Damage", "Crt_dmg_r_rgb").."] x {threshold:%s}] "..CNumb(">", "n_greater_rgb").." ["..CKWord("Health", "Health_rgb").."]\n"
			.."\n"
			..Dot_nc.." Breeds that are NOT considered 'human-sized': Beast of Nurgle, Bulwark, Captains/Twins, Chaos Spawn, Crusher, Daemonhost, Pack Master, Plague Ogryn, Reaper.",
		ru = CKWord("Критические удары", "Krit_udary_rgb_ru").." мгновенно убивают врагов человеческого размера, если "..CKWord("урон критического удара", "krit_udar_uron_rgb_ru")..", умноженный на {threshold:%s}, больше, чем текущее "..CKWord("здоровье", "zdorovie_rgb_ru").." врага.\n"
			.."\n"
			.."["..CKWord("Крит. урон", "Krt_uron_rgb_ru").." x {threshold:%s}] "..CNumb(">", "n_greater_rgb").." ["..CKWord("Здоровье", "Zdorovie_rgb_ru").."]\n"
			.."\n"
			..Dot_nc.." Типы врагов НЕ человеческого размера: Зверь Нургла, Отродье Хаоса, Чумной огрин, бастион, демонхост, жнец, загонщик, капитаны/близнецы, крушитель.",
		["zh-tw"] = CKWord("暴擊打擊", "Crit_strike_rgb_tw").."會立即擊殺人類體型敵人，\n"
			.."前提是敵人目前"..CKWord("生命", "Health_rgb_tw").."低於該次"..CKWord("暴擊打擊", "Crit_strike_rgb_tw").."的"..CKWord("傷害", "Damage_rgb_tw").." x {threshold:%s}。\n"
			.."\n"
			..Dot_nc.." ["..CKWord("暴擊傷害", "Crit_dmg_r_rgb_tw").." x {threshold:%s}] "..CNumb(">", "n_greater_rgb").." ["..CKWord("生命", "Health_rgb_tw").."]\n"
			.."\n"
			..Dot_nc.." 不視為「人類體型」的敵人：\n"
			.."   "..Dot_nc.." 納垢巨獸、堡壘、隊長/雙子、\n"
			.."   "..Dot_nc.." 混沌魔物、碾壓者、惡魔宿主、\n"
			.."   "..Dot_nc.." 獸群領主、瘟疫歐格林、收割者。",
	},
	--[+ Passive 28 - The Sweet Spot +]--	26.03.2026
	["loc_talent_broker_passive_increased_weakspot_damage_desc"] = { -- weakspot_damage: +25%, +colors
		en = Dot_green.." {weakspot_damage:%s} "..CKWord("Weakspot Damage", "Weakspot_dmg_rgb")..".",
		ru = Dot_green.." {weakspot_damage:%s} к "..CKWord("урону по уязвимым местам", "u_mestam_uronu_rgb_ru")..".",
		["zh-tw"] = Dot_green.." {weakspot_damage:%s} "..CKWord("弱點傷害", "Weakspot_dmg_rgb_tw").."。",
	},
	--[+ Passive 29 - Unload +]--	26.03.2026
	["loc_talent_broker_passive_damage_on_reload_desc"] = { -- damage: +2%, duration: 7, ammo_per_stack: 10%, damage_per_stack: +2%, +colors
		en = "Reloading your Ranged Weapon grants for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} Ranged "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."Each {ammo_per_stack:%s} of magazine spent during the duration grants:\n"
			..Dot_green.." {damage_per_stack:%s} additional Ranged "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Rounded down\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		ru = "Перезарядка дальнобойного оружия даёт на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."Каждые {ammo_per_stack:%s} потраченных боеприпасов из магазина за время действия дают дополнительно:\n"
			..Dot_green.." {damage_per_stack:%s} дальнобойного "..CKWord("урона", "urona_rgb_ru")..".\n"
			..Dot_nc.." Округляется в меньшую сторону\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		["zh-tw"] = "裝填你的遠程武器後，\n"
			.."獲得 {duration:%s} 秒：\n"
			..Dot_green.." {damage:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."效果期間每消耗彈匣 {ammo_per_stack:%s}，\n"
			.."額外獲得：\n"
			..Dot_green.." {damage_per_stack:%s} 遠程"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			..Dot_nc.." 無條件捨去。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
	},
	--[+ Passive 30 - Hyper-Violence +]--	26.03.2026
	["loc_talent_broker_passive_melee_damage_carry_over_desc"] = { -- percentage: +25%, duration: 1, +colors
		en = "On Kill gain a {duration:%s}-second Buff that adds flat "..CKWord("Damage", "Damage_rgb").." to your next Melee Attack.\n"
			.."\n"
			.."Flat "..CKWord("Damage", "Damage_rgb").." buff equal to:\n"
			..Dot_green.." {percentage:%s} of your Overkill "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			..Dot_nc.." [Overkill "..CKWord("Damage", "Damage_rgb").."] "..CNumb("=", "n_equal_rgb").." ["..CKWord("Damage", "Damage_rgb").." Dealt] "..CNumb("-", "n_minus_rgb").." [Enemy's remaining "..CKWord("Health", "Health_rgb").."].\n"
			.."\n"
			..Dot_nc.." The Buff's duration refreshes only if your new Overkill "..CKWord("Damage", "Damage_rgb").." is greater than the previous one.",
		ru = "При убийстве вы получаете на {duration:%s} секунду усиление, добавляющее фиксированный "..CKWord("урон", "uron_rgb_ru").." к следующей атаке ближнего боя.\n"
			.."\n"
			.."Фиксированный "..CKWord("урон", "uron_rgb_ru").." равен:\n"
			..Dot_green.." {percentage:%s} от избыточного "..CKWord("урона", "urona_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." [Избыточный "..CKWord("урон", "uron_rgb_ru").."] "..CNumb("=", "n_equal_rgb").." [Нанесённый "..CKWord("урон", "uron_rgb_ru").."] "..CNumb("-", "n_minus_rgb").." ["..CKWord("Здоровье", "Zdorovie_rgb_ru").." врага оставшееся]\n"
			.."\n"
			..Dot_nc.." Длительность усиления обновляется только если новый избыточный "..CKWord("урон", "uron_rgb_ru").." больше предыдущего.",
		["zh-tw"] = "擊殺時獲得 {duration:%s} 秒增益，\n"
			.."使下次近戰攻擊附加固定"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."固定"..CKWord("傷害", "Damage_rgb_tw").."等於：\n"
			..Dot_green.." 你過量"..CKWord("傷害", "Damage_rgb_tw").."的 {percentage:%s}。\n"
			.."\n"
			..Dot_nc.." [過量"..CKWord("傷害", "Damage_rgb_tw").."] "..CNumb("=", "n_equal_rgb").." [造成的"..CKWord("傷害", "Damage_rgb_tw").."] "..CNumb("-", "n_minus_rgb").." [敵人剩餘"..CKWord("生命", "Health_rgb_tw").."]。\n"
			.."\n"
			..Dot_nc.." 只有新的過量"..CKWord("傷害", "Damage_rgb_tw").."高於前一次時，\n"
			.."   才會刷新增益持續時間。",
	},
	--[+ Passive 31 - Street Tough +]--	26.03.2026
	["loc_talent_broker_passive_knockback_on_taking_melee_damage_desc_02"] = { -- movement_speed: +10%, duration: 3, cooldown: 8, +colors
		en = "When taking Melee "..CKWord("Damage", "Damage_rgb")..", knock All nearby Enemies around you backwards and gain for {duration:%s} seconds:\n"
			..Dot_green.." {movement_speed:%s} Movement Speed.\n"
			.."\n"
			..Dot_nc.." Can only trigger once every {cooldown:%s} seconds.",
		ru = "При получении "..CKWord("урона", "urona_rgb_ru").." в ближнем бою, вы отбрасываете всех врагов назад и получаете на {duration:%s} секунды:\n"
			..Dot_green.." {movement_speed:%s} к скорости движения.\n"
			.."\n"
			..Dot_nc.." Срабатывает раз в {cooldown:%s} секунд.",
		["zh-tw"] = "受到近戰"..CKWord("傷害", "Damage_rgb_tw").."時，\n"
			.."擊退你周圍所有附近敵人，\n"
			.."並獲得 {duration:%s} 秒：\n"
			..Dot_green.." {movement_speed:%s} 移動速度。\n"
			.."\n"
			..Dot_nc.." 每 {cooldown:%s} 秒只能觸發一次。",
	},
	--[+ Passive 32 - Battering Momentum +]--	26.03.2026
	["loc_talent_broker_passive_cleave_on_cleave_desc"] = { -- min_targets: 3, multiplier: +50%, +colors
		en = "Hitting {min_targets:%s} or more Enemies with a single Melee Attack grants:\n"
			..Dot_green.." {multiplier:%s} "..CKWord("Cleave", "Cleave_rgb").." for your next Melee Attack.",
		ru = "Попадание по {min_targets:%s} или более врагам атакой ближнего боя даёт:\n"
			..Dot_green.." {multiplier:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов для следующей атаки ближнего боя.",
		["zh-tw"] = "單次近戰攻擊命中 {min_targets:%s} 個以上敵人時，\n"
			.."獲得：\n"
			..Dot_green.." 下次近戰攻擊 {multiplier:%s} "..CKWord("順劈攻擊", "Cleave_rgb_tw").."。",
	},
	--[+ Passive 33 - Extra Pouches +]--	26.03.2026
	["loc_talent_broker_passive_increased_blitz_ammo_desc"] = { -- ammo: +1, +colors
		en = Dot_green.." {ammo:%s} Blitz Charge.",
		ru = Dot_green.." {ammo:%s} заряд блица.",
		["zh-tw"] = Dot_green.." {ammo:%s} 閃擊技能充能。",
	},
	--[+ Passive 34 - Pocket Toxin +]--	26.03.2026
	["loc_talent_broker_passive_blitz_inflicts_toxin_desc_02"] = { -- blinder_stacks: 3, missile_launcher_stacks: 6, chem_grenade_stacks: 10, +colors
		en = "Blitz explosions infect Enemies with Stacks of "..CKWord("Chem Toxin", "Chem_Tox_rgb").." differently, depending on your chosen Blitz:\n"
			..Dot_green.." {blinder:%s}: {blinder_stacks:%s} Stacks to all targets within "..CNumb("3.5", "n_3_5_rgb").." meters radius.\n"
			..Dot_green.." {missile_launcher:%s}: {missile_launcher_stacks:%s} Stacks to all targets within "..CNumb("7", "n_7_rgb").." meters radius.\n"
			..Dot_green.." {chem_grenade:%s}: {chem_grenade_stacks:%s} Stacks to all targets within "..CNumb("4", "n_4_rgb").." meters radius.",
		ru = "Взрывы ваших блицов заражают врагов зарядами "..CKWord("Хим-токсина", "Chem_Toxa_rgb_ru").." в зависимости от выбранного блица:\n"
			..Dot_green.." {blinder:%s}: {blinder_stacks:%s} заряда всем целям в радиусе "..CNumb("3.5", "n_3_5_rgb").." метров.\n"
			..Dot_green.." {missile_launcher:%s}: {missile_launcher_stacks:%s} зарядов всем целям в радиусе "..CNumb("7", "n_7_rgb").." метров.\n"
			..Dot_green.." {chem_grenade:%s}: {chem_grenade_stacks:%s} зарядов всем целям в радиусе "..CNumb("4", "n_4_rgb").." метров.",
		["zh-tw"] = "閃擊技能爆炸會依你選擇的閃擊技能，\n"
			.."以不同方式使敵人感染"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."層數：\n"
			..Dot_green.." {blinder:%s}：對 "..CNumb("3.5", "n_3_5_rgb").." 米半徑內所有目標施加 {blinder_stacks:%s} 層。\n"
			..Dot_green.." {missile_launcher:%s}：對 "..CNumb("7", "n_7_rgb").." 米半徑內所有目標施加 {missile_launcher_stacks:%s} 層。\n"
			..Dot_green.." {chem_grenade:%s}：對 "..CNumb("4", "n_4_rgb").." 米半徑內所有目標施加 {chem_grenade_stacks:%s} 層。",
	},
	--[+ Passive 35 - Splash Damage +]--	26.03.2026
	["loc_talent_broker_passive_toxin_spread_on_kills_desc_02"] = { -- max_targets: 10, radius: 4, toxin_stacks: 2, +colors
		en = "Killing an Elite Enemy with a Melee Attack infects up to {max_targets:%s} enemies within {radius:%s} meters of the target with {toxin_stacks:%s} Stacks of "..CKWord("Chem Toxin", "Chem_Tox_rgb")..".",
		ru = "Убийсто элитного врага атакой ближнего боя заражает до {max_targets:%s} врагов в радиусе {radius:%s} метров от цели {toxin_stacks:%s} зарядами "..CKWord("Хим-токсина", "Chem_Toxa_rgb_ru")..".",
		["zh-tw"] = "以近戰攻擊擊殺精英敵人時，\n"
			.."使目標 {radius:%s} 米內最多 {max_targets:%s} 名敵人\n"
			.."感染 {toxin_stacks:%s} 層"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."。",
	},
	--[+ Passive 36 - Toxic Renewal +]--	26.03.2026
	["loc_talent_broker_passive_replenish_toughness_while_toxined_enemies_in_proximity_desc"] = { -- toughness_amount: 1%, range: 15, max_enemies: 10, m->meters, +colors
		en = "For each "..CKWord("Chem Toxin", "Chem_Tox_rgb").."-infected Enemy within {range:%s} meters you replenish:\n"
			..Dot_green.." {toughness_amount:%s} "..CKWord("Toughness", "Toughness_rgb").." per second.\n"
			.."\n"
			..Dot_nc.." Up to {max_enemies:%s}"..CNumb("%", "pc_rgb").." "..CKWord("Toughness", "Toughness_rgb").." per second.",
		ru = "За каждого заражённого "..CKWord("Хим-токсином", "Chem_Toxom_rgb_ru").." врага в радиусе {range:%s} метров вы восполняете:\n"
			..Dot_green.." {toughness_amount:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду.\n"
			.."\n"
			..Dot_nc.." Вплоть до {max_enemies:%s}"..CNumb("%", "pc_rgb").." "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду.",
		["zh-tw"] = "{range:%s} 米內每有一名感染"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."的敵人，\n"
			.."你會恢復：\n"
			..Dot_green.." 每秒 {toughness_amount:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 最多每秒 {max_enemies:%s}"..CNumb("%", "pc_rgb").." "..CKWord("韌性", "Toughness_rgb_tw").."。",
	},
	--[+ Passive 37 - Toxin Mania +]--	26.03.2026
	["loc_talent_broker_damage_after_toxined_enemies_desc"] = { -- damage: +5%, damage_max: +15%, +colors
		en = Dot_green.." {damage:%s} base "..CKWord("Damage", "Damage_rgb").." for each "..CKWord("Chem Toxin", "Chem_Tox_rgb").."-infected enemy within "..CNumb("12.5", "n_12_5_rgb").." meters.\n"
			.."\n"
			..Dot_nc.." Stacks "..CNumb("3", "n_3_rgb").." times.\n"
			..Dot_nc.." Up to {damage_max:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = Dot_green.." {damage:%s} к базовому "..CKWord("урону", "uronu_rgb_ru").." за каждого врага, заражённого "..CKWord("Хим-токсином", "Chem_Toxom_rgb_ru")..", в пределах "..CNumb("12.5", "n_12_5_rgb").." метров.\n"
			.."\n"
			..Dot_nc.." Суммируется "..CNumb("3", "n_3_rgb").." раза.\n"
			..Dot_nc.." До {damage_max:%s} к "..CKWord("урону", "uronu_rgb_ru")..".",
		["zh-tw"] = Dot_green.." "..CNumb("12.5", "n_12_5_rgb").." 米內每有一名感染"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."的敵人，\n"
			.."獲得 {damage:%s} 基礎"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			..Dot_nc.." 可疊加 "..CNumb("3", "n_3_rgb").." 次。\n"
			..Dot_nc.." 最高 {damage_max:%s} "..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 38 - Moving Target +]--	26.03.2026
	["loc_talent_broker_passive_increased_ranged_dodges_desc"] = { -- extra_consecutive_dodges: +1
		en = "While wielding your Ranged Weapon, you gain:\n"
			..Dot_green.." {extra_consecutive_dodges:%s} Effective Dodge.",
		ru = "Пока у вас в руках оружие дальнего боя вы получаете:\n"
			..Dot_green.." {extra_consecutive_dodges:%s} уклонение.",
		["zh-tw"] = "持有遠程武器時，獲得：\n"
			..Dot_green.." {extra_consecutive_dodges:%s} 有效閃避。",
	},
	--[+ Passive 39 - Channelled Devastation +]--	26.03.2026
	["loc_talent_broker_passive_crit_grants_damage_desc"] = { -- critical_chance: 1%, melee_damage: +0.5%, max_stacks: 30, max_melee_damage: +15%, +colors
		en = "Each {critical_chance:%s} of your current "..CKWord("Critical Hit Chance", "Crit_chance_rgb").." grants a Stack of {melee_damage:%s} Melee "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Up to {max_melee_damage:%s} Melee "..CKWord("Damage", "Damage_rgb")..".",
		ru = "Каждый {critical_chance:%s} вашего текущего "..CKWord("шанса критического удара", "sha_krit_udara_rgb_ru").." даёт заряд {melee_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя.\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			..Dot_nc.." Вплоть до {max_melee_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя.",
		["zh-tw"] = "你目前每有 {critical_chance:%s} "..CKWord("暴擊機率", "Crit_chance_rgb_tw").."，\n"
			.."就獲得一層 {melee_damage:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").."。\n"
			..Dot_nc.." 可疊加 {max_stacks:%s} 次。\n"
			..Dot_nc.." 最高 {max_melee_damage:%s} 近戰"..CKWord("傷害", "Damage_rgb_tw").."。",
	},
	--[+ Passive 40 - Virulent Strain +]--	26.03.2026
	["loc_talent_broker_passive_toxin_infected_enemies_take_increased_damage_desc"] = { -- damage_taken: +10%, duration: 5, +colors
		en = "When you infect enemies with "..CKWord("Chem Toxin", "Chem_Tox_rgb").." they gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("Damage", "Damage_rgb").." Taken from all sources.",
		ru = "Когда вы заражаете врагов "..CKWord("Хим-токсином", "Chem_Toxom_rgb_ru").." они получают на {duration:%s} секунд:\n"
			..Dot_green.." {damage_taken:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru").." из любых источников.",
		["zh-tw"] = "當你使敵人感染"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."時，\n"
			.."敵人獲得 {duration:%s} 秒：\n"
			..Dot_green.." 來自所有來源的承受"..CKWord("傷害", "Damage_rgb_tw").." {damage_taken:%s}。",
	},
	--[+ Passive 41 - Targeted Toxin +]--	26.03.2026
	["loc_talent_broker_passive_reduced_damage_by_toxined_desc"] = { -- default: -15%, monster: -30%, +colors
		en = "Enemies you infect with "..CKWord("Chem Toxin", "Chem_Tox_rgb").." deal:\n"
			..Dot_green.." {default:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."Monstrosities deal:\n"
			..Dot_green.." {monster:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "Враги, заражённые вами "..CKWord("Хим-токсином", "Chem_Toxom_rgb_ru")..", наносят:\n"
			..Dot_green.." {default:%s} "..CKWord("урона", "urona_rgb_ru")..".\n"
			.."\n"
			.."Чудовища наносят:\n"
			..Dot_green.." {monster:%s} "..CKWord("урона", "urona_rgb_ru")..".",
		["zh-tw"] = "你感染"..CKWord("化學毒素", "Chem_Tox_rgb_tw").."的敵人造成：\n"
			..Dot_green.." {default:%s} "..CKWord("傷害", "Damage_rgb_tw").."。\n"
			.."\n"
			.."巨獸造成：\n"
			..Dot_green.." {monster:%s} "..CKWord("傷害", "Damage_rgb_tw").."。",
	},


--[+ +STIMM LAB - СТИМ ЛАБА+ +]--
	--[+ Barrage I-IV / Tank / Regain +]--	26.03.2026
		["loc_talent_buff_toughness_on_stimm"] = { -- toughness_amount: 6.25%, +colors
			en = Dot_green.." {toughness_amount:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished on Stimm use."
			.."\n",
			ru = Dot_green.." {toughness_amount:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается при использовании стима."
			.."\n",
			["zh-tw"] = Dot_green.." 使用興奮劑時恢復 {toughness_amount:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。"
			.."\n",
		},
		["loc_talent_stat_toughness_replenish_modifier"] = { -- toughness_replenish_modifier: +5%, +colors
			en = Dot_green.." {toughness_replenish_modifier:%s} "..CKWord("Toughness", "Toughness_rgb").." Replenishment by Melee kills, Talents, and select Weapon Blessings.\n"
			..CPhrs("Dont_intw_coher_toughn").."\n",
			ru = Dot_green.." {toughness_replenish_modifier:%s} к восстановлению "..CKWord("стойкости", "stoikosti_rgb_ru").." от убийств в ближнем бою, талантов и благословений оружия.\n"
			..CPhrs("Dont_intw_coher_toughn").."\n",
			["zh-tw"] = Dot_green.." 近戰擊殺、天賦與部分武器祝福造成的"..CKWord("韌性", "Toughness_rgb_tw").."恢復 {toughness_replenish_modifier:%s}。\n"
			..CPhrs("Dont_intw_coher_toughn").."\n",
		},
		["loc_talent_stat_damage_taken_multiplier"] = { -- damage_taken_multiplier: -4%, +colors
			en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage_taken_multiplier:%s} "..CKWord("Damage", "Damage_rgb").." Reduction.",
			ru = Dot_green.." "..CNumb("-", "n_minus_rgb").."{damage_taken_multiplier:%s} к получаемому "..CKWord("урону", "uronu_rgb_ru")..".",
			["zh-tw"] = Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage_taken_multiplier:%s} "..CKWord("傷害", "Damage_rgb_tw").."減免。",
		},
		["loc_talent_buff_toughness_during_stimm"] = { -- toughness_amount: +5%, interval: 1, +colors
			en = Dot_green.." {toughness_amount:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished per second.\n" -- {interval:%s}
			..Dot_red.." Disabled while knocked down.",
			ru = Dot_green.." {toughness_amount:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается каждую секунду.\n" -- {interval:%s}
			..Dot_red.." Не работает пока вы сбиты с ног.",
			["zh-tw"] = Dot_green.." 每秒恢復 {toughness_amount:%s} "..CKWord("韌性", "Toughness_rgb_tw").."。\n" -- {interval:%s}
			..Dot_red.." 被擊倒時停用。",
		},
	--[+ Wildfire I-V / Fury I-II / Vultoprene I-II +]--
		["loc_talent_stat_power_level"] = { -- power_level: +4%, +colors
			en = Dot_green.." {power_level:%s} "..CKWord("Strength", "Strength_rgb").." of Melee and Ranged attacks, DoTs, and explosions.\n"
				..CNote("Pwr_note")
				.."\n",
			ru = Dot_green.." {power_level:%s} к "..CKWord("силе", "sile_rgb_ru").." атак ближнего боя, дальнобойных атак, эффектов урона со временем и взрывов.\n"
				..CNote("Pwr_note")
				.."\n",
			["zh-tw"] = Dot_green.." 近戰與遠程攻擊、持續傷害、爆炸的"..CKWord("威力", "Strength_rgb_tw").." {power_level:%s}。\n"
				..CNote("Pwr_note")
				.."\n",
		},
		["loc_talent_stat_finesse_modifier_bonus"] = { -- finesse_modifier_bonus: +10%, +colors
			en = Dot_green.." {finesse_modifier_bonus:%s} "..CKWord("Finesse", "Finesse_rgb")..".\n"
				..CNote("Fns_note"),
			ru = Dot_green.." {finesse_modifier_bonus:%s} к "..CKWord("ловкости", "lovkosti_rgb_ru")..".\n"
				..CNote("Fns_note"),
			["zh-tw"] = Dot_green.." {finesse_modifier_bonus:%s} "..CKWord("靈巧", "Finesse_rgb_tw").."。\n"
				..CNote("Fns_note"),
		},
		["loc_talent_stat_rending_multiplier"] = { -- rending_multiplier: +5%, +colors
			en = Dot_green.." {rending_multiplier:%s} "..CKWord("Rending", "Rending_rgb")..".\n"
				..CNote("Rend_note"),
			ru = Dot_green.." {rending_multiplier:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони.\n"
				..CNote("Rend_note"),
			["zh-tw"] = Dot_green.." {rending_multiplier:%s} "..CKWord("撕裂", "Rending_rgb_tw").."。\n"
				..CNote("Rend_note"),
		},
		["loc_talent_stat_critical_strike_chance"] = { -- critical_strike_chance: +5%, +colors
			en = Dot_green.." {critical_strike_chance:%s} "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb")..".\n",
			ru = Dot_green.." {critical_strike_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru")..".",
			["zh-tw"] = Dot_green.." {critical_strike_chance:%s} "..CKWord("暴擊機率", "Crit_chance_rgb_tw").."。\n",
		},
	--[+ Spur I-V +]--
		["loc_talent_stat_attack_speed"] = { -- attack_speed: +4%, +colors
			en = Dot_green.." {attack_speed:%s} Attack Speed."
			.."\n",
			ru = Dot_green.." {attack_speed:%s} к скорости атаки."
				.."\n",
			["zh-tw"] = Dot_green.." {attack_speed:%s} 攻擊速度。"
			.."\n",
		},
		["loc_talent_stat_wield_speed"] = { -- wield_speed: +25%, +colors
			en = Dot_green.." {wield_speed:%s} Swap Speed.\n"
				..Dot_nc.." This reduces the time of wielding actions when Swapping item slots (Weapons, Grenades, Stimms, Medpacks, Ammo crates, Books, etc)."
			.."\n",
			ru = Dot_green.." {wield_speed:%s} к скорости смены оружия и предметов.\n"
				..Dot_nc.." Этот талант сокращает время затрачиваемое на смену слотов предметов (оружие, гранаты, стимуляторы, медпаки, ящики с боеприпасами, книги и т.д.)."
			.."\n",
			["zh-tw"] = Dot_green.." {wield_speed:%s} 切換速度。\n"
				..Dot_nc.." 這會縮短切換物品欄位時，裝備動作所需的時間（武器、手雷、興奮劑、醫療包、彈藥箱、書籍等）。"
			.."\n",
		},
		["loc_talent_stat_stamina_cost_multiplier"] = { -- stamina_cost_multiplier: -15%, +colors
			en = Dot_green.." {stamina_cost_multiplier:%s} "..CKWord("Stamina", "Stamina_rgb").." Cost.\n"
				..Dot_nc.." Includes "..CKWord("Stamina", "Stamina_rgb").." drain by Blocking, Pushing, Sprinting, Jumping while Sprinting, Dodge-cancelling sticky attacks.",
			ru = Dot_green.." {stamina_cost_multiplier:%s} к затратам "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".\n"
				..Dot_nc.." Включает затраты "..CKWord("выносливости", "vynoslivosti_rgb_ru").." на блокирование, отталкивание, бег, прыжки во время бега и отмену атак уклонениями.",
			["zh-tw"] = Dot_green.." {stamina_cost_multiplier:%s} "..CKWord("耐力", "Stamina_rgb_tw").."消耗。\n"
				..Dot_nc.." 包含格擋、推擊、衝刺、衝刺時跳躍，以及以閃避取消黏著攻擊造成的"..CKWord("耐力", "Stamina_rgb_tw").."消耗。",
		},
		["loc_talent_keyword_stun_immune"] = { -- +colors
			en = "Grants:\n"
				..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity.",
			ru =  "Даёт:\n"
				..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru")..".",
			["zh-tw"] = "賦予：\n"
				..Dot_green.." "..CKWord("眩暈", "Stun_rgb_tw").."免疫。",
		},
		["loc_talent_keyword_slowdown_immune"] = {
			en = Dot_green.." Slowdown Immunity.\n"
				.."\n"
				..Dot_red.." {#color(255, 35, 5)}BUG{#reset()}\n"
				.."Both Immunity effects do not apply.",
			ru = Dot_green.." Иммунитет к замедлению.\n"
				.."\n"
				..Dot_red.." {#color(255, 35, 5)}СЛОМАНО{#reset()}\n"
				.."Оба иммунитета не применяются.",
			["zh-tw"] = Dot_green.." 緩速免疫。\n"
				.."\n"
				..Dot_red.." {#color(255, 35, 5)}BUG{#reset()}\n"
				.."兩種免疫效果都不會套用。",
		},
	--[+ Reflex +]--
		["loc_talent_stat_reload_speed"] = { -- reload_speed: +30%, +colors
			en = Dot_green.." {reload_speed:%s} Reload Speed.\n",
			ru = Dot_green.." {reload_speed:%s} к скорости перезарядки.\n",
			["zh-tw"] = Dot_green.." {reload_speed:%s} 裝填速度。\n",
		},
		["loc_talent_stat_recoil_modifier"] = { -- recoil_modifier: -50%, +colors
			en = Dot_green.." {recoil_modifier:%s} Recoil.",
			ru = Dot_green.." {recoil_modifier:%s} к отдаче.",
			["zh-tw"] = Dot_green.." {recoil_modifier:%s} 後座力。",
		},
	--[+ Fervor +]--
		["loc_talent_stat_movement_speed"] = { -- movement_speed: +10%, +colors
			en = Dot_green.." {movement_speed:%s} Movement Speed.\n",
			ru = Dot_green.." {movement_speed:%s} к скорости движения.\n",
			["zh-tw"] = Dot_green.." {movement_speed:%s} 移動速度。\n",
		},
		["loc_talent_stat_dodge_distance_modifier"] = { -- dodge_distance_modifier: +5%, +colors
			en = Dot_green.." {dodge_distance_modifier:%s} Dodge Distance.\n",
			ru = Dot_green.." {dodge_distance_modifier:%s} к дистанции уклонений.\n",
			["zh-tw"] = Dot_green.." {dodge_distance_modifier:%s} 閃避距離。\n",
		},
		["loc_talent_stat_dodge_speed_multiplier"] = { -- dodge_speed_multiplier: +5%, +colors
			en = Dot_green.." {dodge_speed_multiplier:%s} Dodge Speed.\n",
			ru = Dot_green.." {dodge_speed_multiplier:%s} к скорости уклонений.\n",
			["zh-tw"] = Dot_green.." {dodge_speed_multiplier:%s} 閃避速度。\n",
		},
		["loc_talent_stat_dodge_cooldown_reset_modifier"] = { -- dodge_cooldown_reset_modifier: +5%, +colors
			en = Dot_green.." {dodge_cooldown_reset_modifier:%s} Dodge Recovery Speed.\n"
				..Dot_nc.." Apply after the regular Dodge.\n"
				..Dot_red.." Does not apply after Dodge-slide.",
			ru = Dot_green.." {dodge_cooldown_reset_modifier:%s} к скорости восстановления уклонений.\n"
				..Dot_nc.." Применяется после обычного уклонения.\n"
				..Dot_red.." Не применяется после уклонения с подкатом.",
			["zh-tw"] = Dot_green.." {dodge_cooldown_reset_modifier:%s} 閃避恢復速度。\n"
				..Dot_nc.." 於一般閃避後套用。\n"
				..Dot_red.." 不會於滑步閃避後套用。",
		},
	--[+ Kalma I-V +]--
		["loc_talent_stat_combat_ability_cooldown_regen_modifier"] = { -- combat_ability_cooldown_regen_modifier: +6.25%, +colors
			en = Dot_green.." {combat_ability_cooldown_regen_modifier:%s} "..CKWord("Cooldown", "Cd_rgb").." Regeneration.",
			ru = Dot_green.." {combat_ability_cooldown_regen_modifier:%s} к восстановлению "..CKWord("способности", "sposobnosti_rgb_ru")..".",
			["zh-tw"] = Dot_green.." {combat_ability_cooldown_regen_modifier:%s} "..CKWord("冷卻", "Cd_rgb_tw").."恢復。",
		},
	--[+ Hypex +]--
		["loc_talent_buff_cooldown_on_melee_kills"] = { -- duration: -4%, cooldown: -4%, +colors
			en = "While active, Melee Kills grants for {duration:%s} second:\n"
			..Dot_green.." {cooldown:%s} "..CKWord("Ability Cooldown", "Ability_cd_rgb").." Regeneration.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
			ru = "Когда активно, убийства в ближнем бою дают на {duration:%s} секунду:\n"
			..Dot_green.." {cooldown:%s} к восстановлению "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_be_refr"),
			["zh-tw"] = "啟用時，近戰擊殺會賦予 {duration:%s} 秒：\n"
			..Dot_green.." {cooldown:%s} "..CKWord("技能冷卻", "Ability_cd_rgb_tw").."恢復。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		},
	--[+ Klay +]--
		["loc_talent_buff_cooldown_on_ranged_kills"] = { -- duration: -4%, cooldown: -4%, +colors
			en = "While active, Ranged Kills grants for {duration:%s} second:\n"
			..Dot_green.." {cooldown:%s} "..CKWord("Ability Cooldown", "Ability_cd_rgb").." Regeneration.\n"
			.."\n"
			..CPhrs("Can_be_refr"),
			ru = "Когда активно, убийства в дальнем бою дают на {duration:%s} секунду:\n"
			..Dot_green.." {cooldown:%s} к восстановлению "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Can_be_refr"),
			["zh-tw"] = "啟用時，遠程擊殺會賦予 {duration:%s} 秒：\n"
			..Dot_green.." {cooldown:%s} "..CKWord("技能冷卻", "Ability_cd_rgb_tw").."恢復。\n"
			.."\n"
			..CPhrs("Can_be_refr"),
		},
}

-- Creating templates -- Создаём шаблоны
local scum_templates = {}

for loc_key, locales in pairs(scum_localizations) do
	for locale, text in pairs(locales) do
		table.insert(scum_templates, create_template(
			"scum_" .. loc_key,
			{loc_key},
			{locale},
			loc_text(text)
		))
	end
end

return scum_templates
