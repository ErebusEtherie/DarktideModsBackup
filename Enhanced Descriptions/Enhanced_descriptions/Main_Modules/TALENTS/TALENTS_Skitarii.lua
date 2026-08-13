---@diagnostic disable: undefined-global
-- SKITARII TALENT MODULE -- МОДУЛЬ ТАЛАНТОВ СКИТАРИЯ

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

-- Localization of Skitarii talents -- Локализации талантов скитария
local skitarii_localizations = {
--[+ ++SKITARII - СКИТАРИЙ++ +]--
--[+ +BLITZ - БЛИЦ+ +]--
	--[+ BLITZ - БЛИЦ - 0 - Servo-Skull +]--	17.07.2026
	["loc_talent_cryptic_servo_skull_base_burn_desc"] = { -- +colors
		en = "You are accompanied by a "..CKWord("Servo-Skull", "Servoskull_rgb").." that you can order by double-tapping your Tag input. You can order it to Shoot at nearby Enemies. You can also order it to complete a data interrogation.\n"
			.."\n"
			.."Activating the Blitz empowers your "..CKWord("Servo-Skull", "Servoskull_rgb").." and it gains for {duration:%s} seconds:\n"
			..Dot_green.." {attack_speed:%s} Fire Rate,\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Cooldown {cooldown:%s} seconds.\n"
			.."\n"
			.."Its Attacks apply:\n"
			..Dot_green.." {burn_stacks:%s} Stack of "..CKWord("Burn", "Burn_rgb")..".\n"
			..Dot_nc.." Up to {max_stacks:%s} Stacks.\n"
			.."\n"
			.."Burning enemies receive for {debuff_duration:%s} seconds:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..CPhrs("Can_be_refr"),
		ru = "Вас сопровождает "..CKWord("сервочереп", "servocherep_rgb_ru")..", которому вы можете отдавать приказы двойным нажатием кнопки метки. Вы можете приказать ему стрелять в ближайших врагов или отправить расшифровывать данные.\n"
			.."\n"
			.."Активация блица усиливает ваш "..CKWord("сервочереп", "servocherep_rgb_ru")..", и он получает на {duration:%s} секунд:\n"
			..Dot_green.." {attack_speed:%s} к скорострельности,\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			..Dot_nc.." Восстанавливается {cooldown:%s} секунд.\n"
			.."\n"
			.."Его атаки накладывают:\n"
			..Dot_green.." {burn_stacks:%s} заряд "..CKWord("горения", "gorenia_rgb_ru")..".\n"
			..Dot_nc.." Вплоть до {max_stacks:%s} зарядов.\n"
			.."\n"
			.."Горящие враги получают в течение {debuff_duration:%s} секунд:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("урона", "urona_rgb_ru")..".\n"
			..CPhrs("Can_be_refr"),
	},
	--[+ BLITZ - БЛИЦ - 1 - Artificer Servo-Skull - Сервочереп-техник] +]--	17.07.2026
	["loc_talent_cryptic_servo_skull_improved_clarified_desc"] = { -- +colors
		en = "You are accompanied by a "..CKWord("Servo-Skull", "Servoskull_rgb").." that you can order by Double Tapping your Tag input.\n"
			.."You can order it to Shoot at nearby Enemies.\n"
			.."You can also order it to complete a data interrogation.\n"
			.."\n"
			.."The Activated bonuses from the "..CKWord("Servo-Skull", "Servoskull_rgb").." Blitz base Ability are now permanent.\n"
			.."\n"
			.."Your "..CKWord("Servo-Skull", "Servoskull_rgb").." gains:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("100%", "pc_100_rgb").." Fire Rate,\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb").." "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."Its Attacks apply:\n"
			..Dot_green.." {burn_stacks:%s} Stack of "..CKWord("Burn", "Burn_rgb")..".\n"
			..Dot_nc.." Up to "..CNumb("8", "n_8_rgb").." Stacks.\n"
			.."\n"
			.."Burning enemies receive for {debuff_duration:%s} seconds:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..CPhrs("Can_be_refr"),
		ru = "Вас сопровождает "..CKWord("сервочереп", "servocherep_rgb_ru")..", которому вы можете отдавать приказы двойным нажатием кнопки метки.\n"
			.."Вы можете приказать ему стрелять в ближайших врагов.\n"
			.."Вы также можете отправить его на расшифровку данных.\n"
			.."\n"
			.."Усиления от активации базового блица "..CKWord("сервочерепа", "servocherep_rgb_ru").." теперь постоянны.\n"
			.."\n"
			.."Ваш "..CKWord("сервочереп", "servocherep_rgb_ru").." получает:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("100%", "pc_100_rgb").." к скорострельности,\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb").." к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."Его атаки накладывают:\n"
			..Dot_green.." {burn_stacks:%s} заряд "..CKWord("горения", "gorenia_rgb_ru")..".\n"
			..Dot_nc.." Вплоть до "..CNumb("8", "n_8_rgb").." зарядов.\n"
			.."\n"
			.."Горящие враги получают в течение {debuff_duration:%s} секунд:\n"
			..Dot_green.." {damage_taken:%s} "..CKWord("урона", "urona_rgb_ru")..".\n"
			..CPhrs("Can_be_refr"),
	},
		--[+ BLITZ - БЛИЦ - 1-1 - Medicae Servo-Skull - Сервочереп-медик +]--	17.07.2026
		["loc_talent_cryptic_servo_skull_inject_ally_revive_desc"] = { -- talent_name: , : 4, +colors
			en = "You have an additional "..CKWord("Servo-Skull", "Servoskull_rgb").." equipped with "..CKWord("Adapted Medicae Syringes", "AdMedSyringe_rgb")..". Target a Knocked Down, Hogtied, or Netted Ally to inject them.\n"
				.."\n"
				.."The injection Revives them, as well as granting them per second:\n"
				..Dot_green.." {toughness_per_second:%s} "..CKWord("Toughness", "Toughness_rgb").." and\n"
				..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
				..Dot_nc.." Lasts for {duration:%s} seconds.",
			ru = "У вас есть дополнительный "..CKWord("сервочереп", "servocherep_rgb_ru").." со встроенными "..CKWord("адаптированными медике-шприцами", "AdMedSyringe_rgb_ru")..". Выберите целью сбитого с ног, связанного или опутанного сетью союзника, чтобы сделать ему инъекцию.\n"
				.."\n"
				.."Инъекция оживляет его, а также даёт ему за каждую секунду:\n"
				..Dot_green.." {toughness_per_second:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." и\n"
				..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
				..Dot_nc.." Длится {duration:%s} секунд.",
		},
		--[+ BLITZ - БЛИЦ - 1-2 - Purgator Servo-Skull - Сервочереп-очиститель +]--	17.07.2026
		["loc_talent_cryptic_servo_skull_flamethrower_desc"] = { -- talent_name: Arc Grenades, : 8, : 12, m->meters, s->seconds, +colors
			en = "You have an additional "..CKWord("Servo-Skull", "Servoskull_rgb").." equipped with a "..CKWord("Flamer", "Flamer_rgb")..".\n"
				.."\n"
				.."Target an Area to deploy it.\n"
				.."\n"
				.."Use your Primary Action to switch between\n"
				..Dot_nc.." Dispersed or\n"
				..Dot_nc.." Focused Fire Mode.",
			ru = "У вас есть дополнительный "..CKWord("сервочереп", "servocherep_rgb_ru")..", оснащённый "..CKWord("огнемётом", "Flamer_rgb_ru")..".\n"
				.."\n"
				.."Укажите область для его размещения.\n"
				.."\n"
				.."Удерживая кнопку блица, нажимайте кнопку основного действия, чтобы переключаться между режимами огня:\n"
				..Dot_nc.." По области и\n"
				..Dot_nc.." Направленный.",
		},
		--[+ BLITZ - БЛИЦ - 1-3 - Noospheric Command - Ноосферная команда +]--	17.07.2026
		["loc_talent_cryptic_servo_skull_improved_tagging_fire_rate_cost_desc"] = { -- talent_name: Arc Grenades, : 8, : 12, m->meters, s->seconds, +colors
			en = "Ordering your "..CKWord("Servo-Skull", "Servoskull_rgb").." to attack an Enemy will greatly increase its Fire Rate for {duration:%s} seconds.\n"
				.."\n"
				..Dot_red.." Costs {capacitance:%s} "..CKWord("Capacitance", "Capacitance_rgb")..".",
			ru = "Вы приказываете вашему "..CKWord("сервочерепу", "servocherepu_rgb_ru").." атаковать врага, что значительно увеличивает его скорострельность на {duration:%s} секунды.\n"
				.."\n"
				..Dot_red.." Тратится {capacitance:%s} "..CKWord("ёмкости", "emkosti_rgb_ru")..".",
		},

	--[+ BLITZ - БЛИЦ - 2 - Arc Grenades - Электродуговые гранаты +]--	17.07.2026
	["loc_talent_cryptic_arc_grenades_desc"] = { -- talent_name: Arc Grenades, : 4, +colors
		en = "Throw an "..CKWord("Arc Grenade", "Arcgren_rgb")..", creating an electrical explosion that "..CKWord("Arcs", "Arcs_rgb").." {number:%s} times.\n"
				.."\n"
				..CKWord("Arcs", "Arcs_rgb").." prioritising Armoured and Specialist Enemies, dealing massive "..CKWord("Damage", "Damage_rgb").." and "..CKWord("Impact", "Impact_rgb")..".",
		ru = "Вы бросаете "..CKWord("Электродуговую гранату", "Arcgren_rgb_ru")..", создающую электрический взрыв, который поражает врагов "..CKWord("электродугами", "elektrodugami_rgb_ru").." {number:%s} раза.\n"
				.."\n"
				..CKWord("Электродуги", "Elektrodugi_rgb_ru").." отдают приоритет бронированным врагам и специалистам, нанося им огромный "..CKWord("урон", "uron_rgb_ru").." и "..CKWord("ошеломление", "oshelomlenie_rgb_ru")..".",
	},
		--[+ BLITZ - БЛИЦ - 2-1 - Overcharged Arc Grenades - Перегруженные электродуговые гранаты +]--	17.07.2026
		["loc_talent_cryptic_arc_grenades_brittleness_desc"] = { -- talent_name: Arc Grenades, : 4, +colors
			en = Dot_green.." "..CNumb("+", "n_plus_rgb").."{number:%s} "..CKWord("Arcs", "Arcs_rgb").." created by your {talent_name:%s}.\n"
				.."\n"
				.."The "..CKWord("Arcs", "Arcs_rgb").." apply to enemies on hit:\n"
				..Dot_green.." {stacks:%s} Stacks of "..CNumb("2.5%", "pc_2_5_rgb").." "..CKWord("Brittleness", "Brittleness_rgb")..".",
			ru = Dot_green.." "..CNumb("+", "n_plus_rgb").."{number:%s} к количеству "..CKWord("электродуг", "elektrodug_rgb_ru")..", которые создают ваши {talent_name:%s}.\n"
				.."\n"
				.."Враги, при поражении "..CKWord("электродугами", "elektrodugami_rgb_ru")..", получают:\n"
				..Dot_green.." {stacks:%s} зарядов "..CNumb("2.5%", "pc_2_5_rgb").." "..CKWord("хрупкости", "hrupkosti_rgb_ru").." брони.",
		},
		--[+ BLITZ - БЛИЦ - 2-2 - Enhanced Arc Grenades - Улучшенные электродуговые гранаты +]--	17.07.2026
		["loc_talent_cryptic_arc_grenades_weapon_malfunction_desc"] = { -- talent_name: Arc Grenades, : 8, : 12, m->meters, s->seconds, +colors
			en = "Your {talent_name:%s} also cause Ranged Enemies within {range:%s} meters to have their Ranged weapons Malfunction, making them unable to use them for {duration:%s} seconds.",
			ru = "Ваши {talent_name:%s} также блокируют на {duration:%s} секунд дальнобойное оружие у стрелков в радиусе {range:%s} метров.",
		},

	--[+ BLITZ - БЛИЦ - 3 - Integrated Refraction Emitter - Встроенный рефракционный излучатель +]--	17.07.2026
	["loc_talent_cryptic_grenade_ability_force_field_clarified_desc"] = { -- +colors
		en = "Surround yourself in a shield that absorbs all incoming Ranged "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Lasts {duration:%s} seconds.\n"
			.."\n"
			.."Upon activation, and again when it ends, cause an electric explosion around you, applying "..CKWord("Electrocution", "Electrocution_rgb").." to enemies within {range:%s} meters.",
		ru = "Вы окружаете себя щитом, поглощающим весь входящий "..CKWord("урон", "uron_rgb_ru").." дальнего боя.\n"
			..Dot_nc.." Длится {duration:%s} секунд.\n"
			.."\n"
			.."При активации и по окончании действия вокруг вас происходит электрический взрыв, накладывающий "..CKWord("электрошок", "elektroshok_rgb_ru").." на врагов в радиусе {range:%s} метров.",
	},
		--[+ BLITZ - БЛИЦ - 3-1 - Overcharged Refraction Emitter - Перегруженный рефракционный излучатель +]--	17.07.2026
		["loc_talent_cryptic_force_field_duration_increase_desc"] = { -- talent_name: Arc Grenades, : 4, +colors
			en = Dot_green.." Increase the field duration to {increased_duration:%s} seconds.\n"
				.."\n"
				..Dot_green.." In addition, you "..CKWord("Electrocute", "Electrocute_rgb").." nearby enemies an additional time at the midpoint of its duration.",
			ru = Dot_green.." Увеличивает длительность действия поля до {increased_duration:%s} секунд.\n"
				.."\n"
				..Dot_green.." Кроме того, вы поражаете "..CKWord("электрошоком", "elektroshokom_rgb_ru").." ближайших врагов дополнительный раз в середине действия поля.",
		},
		--[+ BLITZ - БЛИЦ - 3-2 - Voltaic Resistance - Вольтаическое сопротивление +]--	17.07.2026
		["loc_talent_cryptic_force_field_arcs_desc"] = { -- talent_name: Arc Grenades, : 8, : 12, m->meters, s->seconds, +colors
			en = "When your Refraction Emitter ends, shoot up to {max_arcs:%s} "..CKWord("Arcs", "Arcs_rgb").." towards enemies in front of you, based on the number of attacks absorbed.",
			ru = "Когда ваш рефракционный излучатель заканчивает действие, он выпускает до {max_arcs:%s} "..CKWord("электродуг", "elektrodug_rgb_ru").." во врагов перед вами, в зависимости от количества поглощённых атак.",
		},
		--[+ BLITZ - БЛИЦ - 3-3 - Kinetic Repulsion - Кинетическое отталкивание +]--	17.07.2026
		["loc_talent_cryptic_force_field_health_damage_limit_desc"] = { -- talent_name: Arc Grenades, : 8, : 12, m->meters, s->seconds, +colors
			en = "Limit all "..CKWord("Health", "Health_rgb").." "..CKWord("Damage", "Damage_rgb").." Taken while {force_field_name:%s} is active to {limit:%s}.",
			ru = "Пока активен блиц {force_field_name:%s}, весь получаемый "..CKWord("урон", "uron_rgb_ru").." "..CKWord("здоровью", "zdoroviu_rgb_ru").." ограничивается до {limit:%s} единиц.",
		},
--[+ +AURA - АУРЫ+ +]--
	--[+ AURA - АУРА - 0 - Resurgence - Возрождение +]--	17.07.2026
	["loc_talent_cryptic_coherency_regen_aura_desc"] = { -- damage_reduction: +7.5%, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Coherency", "Coherency_rgb").." "..CKWord("Toughness", "Toughness_rgb").." regenerated by you and Allies in "..CKWord("Coherency", "Coherency_rgb").." regardless of enemy proximity.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." от "..CKWord("сплочённости", "splochennosti_rgb_ru").." восстанавливается вам и союзникам в "..CKWord("сплочённости", "splochennosti_rgb_ru").." независимо от близости врагов.",
	},
	--[+ AURA - АУРА - 1 - Resurgence - Возрождение +]--	17.07.2026
	["loc_talent_cryptic_coherency_regen_aura_improved_desc"] = { -- damage_reduction: +15%, talent_name: The Emperor's Will, +colors
		en = Dot_green.." {toughness_flat:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_green.." {toughness:%s} "..CKWord("Coherency", "Coherency_rgb").." "..CKWord("Toughness", "Toughness_rgb").." regenerated by you and Allies in "..CKWord("Coherency", "Coherency_rgb")..",  regardless of enemy proximity.\n",
		ru = Dot_green.." {toughness_flat:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." от "..CKWord("сплочённости", "splochennosti_rgb_ru").." восстанавливается вам и союзникам в "..CKWord("сплочённости", "splochennosti_rgb_ru").." независимо от близости врагов.",
	},
	--[+ AURA - АУРА - 2 - Ammunition Deposit - Запас боеприпасов +]--	17.07.2026
	["loc_talent_cryptic_ammo_aura_toughness_desc"] = { -- corruption: 1.5, interval: 1, s->second, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_green.." {ammo:%s} Ammo Reserve to you and Allies in "..CKWord("Coherency", "Coherency_rgb")..".\n",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." {ammo:%s} к запасу боеприпасов для вас и союзников в "..CKWord("сплочённости", "splochennosti_rgb_ru")..".",
	},
	--[+ AURA - АУРА - 3 - Foe-Render Creed - Кредо терзателя врагов +]--	17.07.2026
	["loc_talent_cryptic_aura_weapon_improved_desc"] = { -- stamina_cost_multiplier: -15%, stamina_delay: 0.15, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			.."You and Allies in "..CKWord("Coherency", "Coherency_rgb").." gain:\n"
			..Dot_green.." {cleave:%s} "..CKWord("Cleave", "Cleave_rgb").." and\n"
			..Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb")..".\n",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Вы и союзники в "..CKWord("сплочённости", "splochennosti_rgb_ru").." получаете:\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов и\n"
			..Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони.",
	},

--[+ +ABILITIES - СПОСОБНОСТИ+ +]--
	--[+ ABILITY - СПОСОБНОСТЬ - 0 - Voltaic Expander - Вольтаический расширитель +]--	17.07.2026
	["loc_talent_cryptic_discharge_base_desc"] = { -- +colors
		en = "Unleash an "..CKWord("Electric Discharge", "ElectrDisch_rgb").." around you. Enemies within {range:%s} meters are "..CKWord("Electrocuted", "Electrocuted_rgb").." for {duration:%s} seconds, "..CKWord("Stunning", "Stunning_rgb").." them and dealing "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."When using {talent_name:%s} at {charge_two:%s} charges, extend the Range to {range_two:%s} meters.\n"
			.."\n"
			.."When using {talent_name:%s} at {charge_three:%s} charges or above, extend the Range to {range_three:%s} meters.",
		ru = "Вы выпускаете "..CKWord("Электрический разряд", "ElectrDisch_rgb_ru").." вокруг себя и враги в радиусе {range:%s} метров поражаются "..CKWord("электрошоком", "elektroshokom_rgb_ru").." на {duration:%s} секунды, "..CKWord("ошеломляются", "oshelomlautsa_rgb_ru").." и получают "..CKWord("урон", "uron_rgb_ru")..".\n"
			.."\n"
			.."При использовании способности {talent_name:%s} с {charge_two:%s} и более зарядами, радиус поражения увеличивается до {range_two:%s} метров.\n"
			.."\n"
			.."При использовании способности {talent_name:%s} с {charge_three:%s} и более зарядами, радиус поражения увеличивается до {range_three:%s} метров.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 1 - Voltaic Emitter - Вольтаический излучатель +]--	17.07.2026
	["loc_talent_cryptic_discharge_desc"] = { -- toughness: 50%, attack_speed: +20%, time: 10, damage: +25%, cooldown: 30, talent_name: Chastise the Wicked, &->and, s->seconds, +colors
		en = "Unleash an "..CKWord("Electric Discharge", "ElectrDisch_rgb").." around you. Enemies within {range:%s} meters are "..CKWord("Electrocuted", "Electrocuted_rgb").." for {duration:%s} seconds, "..CKWord("Stunning", "Stunning_rgb").." them and dealing "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."When using {talent_name:%s} at {charge_two:%s} charges or above, Ranged Enemies, within {far_range:%s} meters, have their weapons Malfunction for {malfunction_duration:%s} seconds.\n"
			.."\n"
			.."When using {talent_name:%s} at {charge_three:%s} charges or above, for the next {buff_duration:%s} seconds your attacks "..CKWord("Electrocute", "Electrocute_rgb").." enemies hit for {short_duration:%s} seconds, dealing "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."This is an enhanced version of the "..CKWord("Voltaic Expander", "VoltaicExpander_rgb").." Ability.",
		ru = "Вы выпускаете "..CKWord("Электрический разряд", "ElectrDisch_rgb_ru").." вокруг себя и враги в радиусе {range:%s} метров поражаются "..CKWord("электрошоком", "elektroshokom_rgb_ru").." на {duration:%s} секунды, "..CKWord("ошеломляются", "oshelomlautsa_rgb_ru").." и получают "..CKWord("урон", "uron_rgb_ru")..".\n"
			.."\n"
			.."При использовании способности {talent_name:%s} с {charge_two:%s} и более зарядами, у стрелков в радиусе {far_range:%s} метров выходит из строя оружие на {malfunction_duration:%s} секунд.\n"
			.."\n"
			.."При использовании способности {talent_name:%s} с {charge_three:%s} и более зарядами, в течение {buff_duration:%s} секунд ваши атаки поражают врагов "..CKWord("электрошоком", "elektroshokom_rgb_ru").." на {short_duration:%s} секунды, нанося "..CKWord("урон", "uron_rgb_ru")..".\n"
			.."\n"
			.."Это улучшенная версия способности "..CKWord("Вольтаический расширитель", "VoltaicExpander_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 1-1 - Voltaic Overcharge - Вольтаическая перегруз +]--	17.07.2026
	["loc_talent_cryptic_discharge_toughness_desc"] = { -- duration: 5, talent_name: Fury of the Faithful, cooldown: +20%, s->seconds, +colors
		en = "{ability_name:%s} restores:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").."\n"
			.."Plus an additional:\n"
			..Dot_green.." {toughness_per_hit:%s} "..CKWord("Toughness", "Toughness_rgb").." per each enemy hit by the "..CKWord("Electric Discharge", "ElectrDisch_rgb")..".",
		ru = "Способность {ability_name:%s} восстанавливает:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").."\n"
			.."И дополнительно:\n"
			..Dot_green.." {toughness_per_hit:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." за каждого врага, поражённого "..CKWord("Электрическим разрядом", "ElectrDischom_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 1-2 - Voltaic Motivator - Вольтаический мотиватор +]--	17.07.2026
	["loc_talent_cryptic_discharge_two_charge_bonus_desc"] = { -- talent_name: Fury of the Faithful, charges: 2
		en = "When using {talent_name:%s} at {charge:%s} charge or above, gain for {duration:%s} seconds:\n"
			..Dot_green.." {attack_speed:%s} Attack Speed.",
		ru = "При использовании способности {talent_name:%s} с {charge:%s} и более зарядами, вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {attack_speed:%s} к скорости атаки.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 1-3 - Voltaic Arcs - Вольтаические электродуги +]--	17.07.2026
	["loc_talent_cryptic_discharge_arc_bonus_desc"] = { -- talent_name: Fury of the Faithful, charges: 2
		en = "When using {ability_name:%s}, you release {num_arcs:%s} forward-facing "..CKWord("Arcs", "Arcs_rgb").." per Charge spent.\n"
			.."\n"
			.."Each "..CKWord("Arc", "Arc_rgb").." deals high "..CKWord("Damage", "Damage_rgb").." and "..CKWord("Impact", "Impact_rgb")..".",
		ru = "При использовании способности {ability_name:%s} вы выпускаете {num_arcs:%s} направленных вперёд "..CKWord("электродуг", "elektrodug_rgb_ru").." за каждый потраченный заряд.\n"
			.."\n"
			.."Каждая "..CKWord("электродуга", "elektroduga_rgb_ru").." наносит высокий "..CKWord("урон", "uron_rgb_ru").." и "..CKWord("ошеломление", "oshelomlenie_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 2 - Chordclaw Strike - Удар аккордовыми когтями +]--	17.07.2026
	["loc_talent_cryptic_chordclaw_desc"] = { -- interval: 0.8, toughness: 45%, flat_toughness: +20, max_toughness: +100, cooldown: 60, s->seconds, +colors
		en = "Perform a Powerful Heavy Melee Attack using a "..CKWord("Chordclaw", "Chordclaw_rgb")..".\n"
			.."\n"
			.."The Attack is a Guaranteed "..CKWord("Critical Strike", "Crit_strike_rgb").." and has:\n"
			..Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb")..".",
		ru = "Вы выполняете мощную тяжёлую атаку ближнего боя с помощью "..CKWord("Аккордовых когтей", "Chordclaw_rgb_ru")..".\n"
			.."\n"
			.."Атака гарантированно будет "..CKWord("критическим ударом", "krit_udarom_rgb_ru").." и даёт:\n"
			..Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 2-1 - Satiated Steel - Насыщенная сталь +]--	17.07.2026
	["loc_talent_cryptic_chordclaw_capacitance_restoration_desc"] = { -- stacks: 5, toughness: +30%, duration: 10, s->seconds, +colors
		en = CKWord("Chordclaw", "Chordclaw_rgb").." Kills restore over {duration:%s} seconds:\n"
			..Dot_green.." {capacitance_percent:%s} "..CKWord("Capacitance", "Capacitance_rgb")..".",
		ru = "Убийства "..CKWord("Аккордовыми когтями", "Chordclaws_rgb_ru").." восстанавливают в течение {duration:%s} секунд:\n"
			..Dot_green.." {capacitance_percent:%s} "..CKWord("ёмкости", "emkosti_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 2-2 - Axial Slash - Горизонтальный разрез +]--	17.07.2026
	["loc_talent_cryptic_chordclaw_horizontal_swipe_desc"] = { -- stacks: 5, damage: +20%, duration: 10, s->seconds, +colors
		en = "Your "..CKWord("Chordclaw", "Chordclaw_rgb").." now executes a Horizontal Sweep attack.",
		ru = "Ваши "..CKWord("Аккордовые когти", "Chordclawe_rgb_ru").." теперь делают горизонтальный рассекающий удар.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 2-3 - Probing Strikes - Зондирующие удары +]--	17.07.2026
	["loc_talent_cryptic_chordclaw_quick_stab_combo_desc"] = { -- stacks: 5, damage: +20%, duration: 10, s->seconds, +colors
		en = "Your "..CKWord("Chordclaw", "Chordclaw_rgb").." now executes {num_stab:%s} Quick Stab attacks, that apply:\n"
			..Dot_green.." {bleed_stacks:%s} Stack of "..CKWord("Bleed", "Bleed_rgb")..".",
		ru = "Ваши "..CKWord("Аккордовые когти", "Chordclawe_rgb_ru").." теперь делают {num_stab:%s} быстрые колющие атаки, накладывающие:\n"
			..Dot_green.." {bleed_stacks:%s} зарядов "..CKWord("кровотечения", "krovotechenia_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 2-4 - Slice and Dice - Нарежь и измельчи +]--	17.07.2026
	["loc_talent_cryptic_chordclaw_consecutive_bonus_desc"] = { -- stacks: 5, damage: +20%, duration: 10, s->seconds, +colors
		en = "Using the "..CKWord("Chordclaw", "Chordclaw_rgb").." Ability grants Stacks.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Stacks last {duration:%s} seconds.\n"
			.."\n"
			.."Per Stack you gain:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} "..CKWord("Damage", "Damage_rgb").." to your "..CKWord("Chordclaw", "Chordclaw_rgb")..".\n"
			.."\n"
			..CPhrs("Cant_be_refr"),
		ru = "Использование способности "..CKWord("Аккордовые когти", "Chordclawe_rgb_ru").." даёт заряды.\n"
			..Dot_nc.." Суммируется до {max_stacks:%s} раз.\n"
			..Dot_nc.." Заряды длятся {duration:%s} секунд.\n"
			.."\n"
			.."За каждый заряд вы получаете:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." для ваших "..CKWord("Аккордовых когтей", "Chordclaw_rgb_ru")..".\n"
			.."\n"
			..CPhrs("Cant_be_refr"),
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3 - Advanced Combat Doctrines - Передовые боевые доктрины +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_drain_cost_desc"] = { -- duration: 3, movement_speed: +20%, backstab_damage: +100%, finesse_damage: +100%, crit_chance: +100%, cooldown: 30, s->seconds, &->and, +colors
		en = "Spend {capacitance_instant:%s} "..CKWord("Capacitance", "Capacitance_rgb").." and Swap to your Secondary Weapon.\n"
			.."Your weapon locks onto enemies close to your targeting reticule, granting you inhuman accuracy.\n"
			.."Activation increases the remaining "..CKWord("Cooldown", "Cd_rgb").." of a Charge by "..CNumb("25%", "pc_25_rgb").." (default: "..CNumb("12.5", "n_12_5_rgb").." seconds).\n"
			.."\n"
			.."While active, you gain:\n"
			..Dot_green.." {spread:%s} Spread and\n"
			..Dot_green.." {recoil:%s} Recoil.\n"
			.."but you drain:\n"
			..Dot_red.." {capacitance_drain:%s} "..CKWord("Capacitance", "Capacitance_rgb").." per second, and also\n"
			..Dot_red.." {capacitance_shot:%s} "..CKWord("Capacitance", "Capacitance_rgb").." per shot.\n"
			..Dot_green.." Drain is paused while reloading.\n"
			.."\n"
			.."While Ability active, it increases the remaining "..CKWord("Cooldown", "Cd_rgb").." by:\n"
			..Dot_red.." "..CNumb("10%", "pc_10_rgb").." per second,\n"
			..Dot_red.." "..CNumb("1%", "pc_1_rgb").." per shot fired.\n"
			.."\n"
			.."The Ability ends if you reach:\n"
			..Dot_red.." {zero_capacitance:%s} "..CKWord("Capacitance", "Capacitance_rgb").." and\n"
			..Dot_red.." {zero_charges:%s} Charges, or\n"
			..Dot_red.." Switch Weapon, or\n"
			..Dot_red.." Reactivate Ability.\n"
			.."\n"
			..Dot_nc.." Only usable if you have at least {charge_min:%s} Charge available.\n"
			..Dot_nc.." No Cooldown.",
		ru = "Вы тратите {capacitance_instant:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." и переключитесь на оружие дальнего боя. Ваше оружие наводится на врагов рядом с прицелом, обеспечивая нечеловеческую точность.\n"
			.."Активация увеличивает оставшееся время "..CKWord("восстановления", "vosstanovlenia_rgb_ru").." заряда на "..CNumb("25%", "pc_25_rgb").." (по умолчанию: "..CNumb("12.5", "n_12_5_rgb").." секунд).\n"
			.."\n"
			.."Пока активна способность, вы получаете:\n"
			..Dot_green.." {spread:%s} к разбросу и\n"
			..Dot_green.." {recoil:%s} к отдаче.\n"
			.."но тратите:\n"
			..Dot_red.." {capacitance_drain:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." в секунду и ещё\n"
			..Dot_red.." {capacitance_shot:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." за каждый выстрел.\n"
			..Dot_green.." Расход останавливается во время перезарядки.\n"
			.."\n"
			.."Пока активна способность, оставшееся время "..CKWord("восстановления", "vosstanovlenia_rgb_ru").." увеличивается:\n"
			..Dot_red.." на "..CNumb("10%", "pc_10_rgb").." в секунду и ещё\n"
			..Dot_red.." на "..CNumb("1%", "pc_1_rgb").." за каждый выстрел.\n"
			.."\n"
			.."Способность прекращает действие, если вы достигнете:\n"
			..Dot_red.." {zero_capacitance:%s} "..CKWord("Ёмкости", "emkosti_rgb_ru").." и\n"
			..Dot_red.." {zero_charges:%s} зарядов, или\n"
			..Dot_red.." Смените оружие, или\n"
			..Dot_red.." Активируете способность снова.\n"
			.."\n"
			..Dot_nc.." Можно использовать только при наличии хотя бы {charge_min:%s} заряда.\n"
			..Dot_nc.." Без восстановления.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3-1 - Restoration Protocol - Протокол восстановления +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_toughness_suppression_desc"] = { -- talent_name: Shroudfield, duration: 2, buff_duration: 5, threat: -75%, damage: 50%, s->seconds, +colors
		en = "{talent_name:%s} restores for its duration:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." per second.\n"
			.."\n"
			..Dot_green.." On activation, instantly clears all Suppression.",
		ru = "Способность {talent_name:%s} восстанавливает на время действия:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в секунду.\n"
			.."\n"
			..Dot_green.." При активации мгновенно снимает всё подавление, наложенное врагами на вас.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3-2 - Writ of Ammunition Enumeration - Приказ Учёта боеприпасов +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_fire_rate_increased_desc"] = { -- toughness: 40%, time: 5, damage: +20%, time: 5, s->seconds, +colors
		en = "While {talent_name:%s} is active you gain:\n"
			..Dot_green.." {fire_rate:%s} "..CKWord("Fire Rate", "FireRate_rgb")..".\n"
			.."\n"
			.."After {duration:%s} seconds, this increases to:\n"
			..Dot_green.." {fire_rate_increased:%s} "..CKWord("Fire Rate", "FireRate_rgb")..".",
		ru = "Пока активна способность {talent_name:%s}, вы получаете:\n"
			..Dot_green.." {fire_rate:%s} к скорострельности.\n"
			.."\n"
			.."Через {duration:%s} секунды это значение увеличивается до:\n"
			..Dot_green.." {fire_rate_increased:%s} к скорострельности.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3-3 - Calculated Priority - Рассчитанный приоритет +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_damage_on_elite_kill_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = "While {talent_name:%s} is active, Elite Kills grant per Stack:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			..Dot_nc.." Up to "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb").." "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			..Dot_nc.." Stacks last {duration:%s} seconds.\n"
			.."\n"
			..CPhrs("Can_be_refr").."\n"
			..CPhrs("Can_proc_mult_str"),
		ru = "Пока активна способность {talent_name:%s}, убийства элитных врагов дают за каждый заряд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			..Dot_nc.." Вплоть до "..CNumb("+", "n_plus_rgb")..CNumb("25%", "pc_25_rgb").." к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.\n"
			..Dot_nc.." Заряды длятся {duration:%s} секунд.\n"
			.."\n"
			..CPhrs("Can_be_refr").."\n"
			..CPhrs("Can_proc_mult_str"),
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3-4 - Readiness Doctrines - Доктрины готовности +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_reload_speed_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = "While {ability_name:%s} is active, and for {duration:%s} seconds after it ends, you gain:\n"
			..Dot_green.." {reload_speed:%s} Reload Speed.",
		ru = "Пока активна способность {ability_name:%s} и в течение {duration:%s} секунд после её окончания, вы получаете:\n"
			..Dot_green.." {reload_speed:%s} к скорости перезарядки.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 3-5 - Piercing Sight - Пронзающий взгляд +]--	17.07.2026
	["loc_talent_cryptic_precision_stance_crit_cleave_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = "While {talent_name:%s} is active you gain:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{cleave:%s} Ranged "..CKWord("Cleave", "Cleave_rgb").." and\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{crit_chance:%s} Ranged "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb")..".\n"
			.."\n"
			.."After {duration:%s} seconds, these increase to:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{increased_cleave:%s} Ranged "..CKWord("Cleave", "Cleave_rgb").." and\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{increased_crit_chance:%s} Ranged "..CKWord("Critical Strike Chance", "Crt_chnc_r_rgb")..".",
		ru = "Пока активна способность {talent_name:%s} вы получаете:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{cleave:%s} к "..CKWord("прострелу", "prostrelu_rgb_ru").." и\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{crit_chance:%s} к "..CKWord("шансу критического выстрела", "sh_krit_vystrela_rgb_ru")..".\n"
			.."\n"
			.."Через {duration:%s} секунды эти значения увеличиваются до:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{increased_cleave:%s} к "..CKWord("прострелу", "prostrelu_rgb_ru").." и\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{increased_crit_chance:%s} к "..CKWord("шансу критического выстрела", "sh_krit_vystrela_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 4 - Capacitor Reclamation Loop - Контур восстановления конденсатора +]--	17.07.2026
	["loc_talent_cryptic_multi_hits_grant_power_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = "On hitting {number:%s} or more enemies with a single Attack, you restore:\n"
			..Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb")..".",
		ru = "При попадании по {number:%s} или более врагам одной атакой, вы восстанавливаете:\n"
			..Dot_green.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 5 - Augmented Power-Cycle - Усиленный силовой цикл +]--	17.07.2026
	["loc_talent_cryptic_increased_passive_cooldown_regen_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb").." generated per second.",
		ru = Dot_green.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." генерируется в секунду.",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 6 - Flux Conduit Build-Up - Проводник накопления потока +]--	17.07.2026
	["loc_talent_cryptic_crits_grant_power_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb").." generated over {duration:%s} seconds on "..CKWord("Critical Hits", "Crit_hits_rgb")..".",
		ru = Dot_green.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." генерируется в течение {duration:%s} секунд при "..CKWord("критических ударах", "krit_udarah_rgb_ru")..".",
	},
	--[+ ABILITY - СПОСОБНОСТЬ - 7 - Reactor Coil Recharge - Перезарядка катушки реактора +]--	17.07.2026
	["loc_talent_cryptic_weakspot_kills_grant_power_desc"] = { -- talent_name: Shroudfield, damage: +50%, damage_2: +50%, cooldown: 25%, &->and, +colors
		en = Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb").." generated on "..CKWord("Weakspot", "Weakspot_rgb").." Kills.",
		ru = Dot_green.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru").." генерируется при убийствах в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru")..".",
	},
--[+ +KEYSTONES - КЛЮЧЕВЫЕ+ +]--
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 1 - Redline Capacitors - Конденсаторы предельной нагрузки +]--	17.07.2026
	["loc_talent_cryptic_redline_charge_stacking_clarified_desc"] = { -- crit_chance: +15%, duration: 8, max_stacks: 25, radius: 25, m->meters, s->seconds, +colors
		en = "Spending or gaining a "..CKWord("Combat Ability", "Cmbt_abil_rgb").." charge grants you for {duration:%s} seconds:\n"
			..Dot_green.." {capacitance:%s} "..CKWord("Capacitance", "Capacitance_rgb").." generation and\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			..Dot_nc.." Stacks decay one at a time.\n"
			.."\n"
			..Dot_green.." {max_charges:%s} Max Ability Charges.",
		ru = "Трата или получение "..CKWord("Заряда", "Charga_rgb_ru").." даёт вам на {duration:%s} секунд:\n"
			..Dot_green.." {capacitance:%s} к генерации "..CKWord("ёмкости", "emkosti_rgb_ru").." и\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Суммируется до {max_stacks:%s} раз.\n"
			..Dot_nc.." Заряды сбрасываются по одному.\n"
			.."\n"
			..Dot_green.." {max_charges:%s} к максимуму зарядов способности.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 1-1 - Advanced Power Management - Улучшенное управление питанием +]--	17.07.2026
	["loc_talent_cryptic_redline_strength_clarified_desc"] = { -- crit_chance: +10%, talent_name: Blazing Piety, +colors
		en = "On "..CKWord("Combat Ability", "Cmbt_abil_rgb").." use, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {strength:%s} "..CKWord("Strength", "Strength_rgb").." per "..CKWord("Combat Ability", "Cmbt_abil_rgb").." charge you had on use.",
		ru = "При использовании "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {strength:%s} к "..CKWord("силе", "sile_rgb_ru").." за каждый имеющийся "..CKWord("Заряд", "Charge_rgb_ru").." на момент активации.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 1-2 - Resource Optimisation Canticles  - Славословие оптимизации ресурсов +]--	17.07.2026
	["loc_talent_cryptic_redline_stacks_clarified_desc"] = { -- crit_chance: +10%, talent_name: Blazing Piety, +colors
		en = Dot_green.." {charges:%s} Max "..CKWord("Combat Ability", "Cmbt_abil_rgb").." charges.\n"
			.."\n"
			..Dot_green.." {redline_stack:%s} Max {talent_name:%s} Stacks.",
		ru = Dot_green.." {charges:%s} к максимуму зарядов "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." {redline_stack:%s} к максимуму зарядов таланта {talent_name:%s}.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 1-3 - Capacitory Limit Override - Обход лимита ёмкости +]--	17.07.2026
	["loc_talent_cryptic_redline_rending_clarified_desc"] = { -- toughness: 50%, toughness_damage_reduction: +25%, toughness_small: 2%, +colors
		en = "While at {stacks:%s} {talent_name:%s} Stacks or above you gain:\n"
			..Dot_green.." {rending:%s} "..CKWord("Rending", "Rending_rgb")..".",
		ru = "При наличии {stacks:%s} или более зарядов таланта {talent_name:%s} вы получаете:\n"
			..Dot_green.." {rending:%s} к "..CKWord("пробиванию", "probivaniu_rgb_ru").." брони.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 1-4 - Surge-Extension - Расширение импульса +]--	17.07.2026
	["loc_talent_cryptic_redline_toughness_clarified_desc"] = { -- cooldown_regen: +100%, duration: 3, +colors
		en = "Gaining a {talent_name:%s} Stack replenishes:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.",
		ru = "Получение заряда таланта {talent_name:%s} восстанавливает:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 2 - Power Overload - Перегрузка питания +]--	17.07.2026
	["loc_talent_cryptic_overload_keystone_coherency_desc"] = { -- damage: +10%, max_wounds: 5, +colors
		en = "Kills by you and Allies in "..CKWord("Coherency", "Coherency_rgb").." grant:\n"
			..Dot_nc.." {low_stack:%s} Stack of {talent_name:%s}.\n"
			..Dot_nc.." {elite_stacks:%s} Stacks on Elite and Specialist Kills.\n"
			..Dot_nc.." Max {max_stacks:%s} Stacks.\n"
			.."\n"
			.."Reaching max Stacks triggers an "..CKWord("Overload", "Overload_rgb").." and resets to {zero:%s} Stacks.\n"
			.."\n"
			.."The "..CKWord("Overload", "Overload_rgb").." grants you and Allies in "..CKWord("Coherency", "Coherency_rgb").." for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".",
		ru = "Убийства совершённые вами или союзниками в "..CKWord("сплочённости", "splochennosti_rgb_ru").." дают:\n"
			..Dot_nc.." {low_stack:%s} заряд таланта {talent_name:%s}.\n"
			..Dot_nc.." {elite_stacks:%s} заряда вы получаете за убийство элитного врага или специалиста.\n"
			..Dot_nc.." Максимум {max_stacks:%s} зарядов.\n"
			.."\n"
			.."Достижение максимума зарядов вызывает "..CKWord("Перегрузку", "Overloadu_rgb_ru").." и сбрасывает заряды до {zero:%s}.\n"
			.."\n"
			..CKWord("Перегрузка", "Overloada_rgb_ru").." даёт вам и союзникам в пределах "..CKWord("сплочённости", "splochennosti_rgb_ru").." на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 2-1 - Critical Power Overload - Критическая перегрузка питания +]--	17.07.2026
	["loc_talent_cryptic_overload_keystone_bigger_explosion_desc"] = { -- talent_name: Martyrdom, toughness_damage_reduction: +7.5%, +colors
		en = "The "..CKWord("Overload", "Overload_rgb").." now applies "..CKWord("Electrocution", "Electrocution_rgb").." to enemies in melee range.\n"
			.."\n"
			.."Affected enemies take for {duration:%s} seconds:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage_taken:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "Теперь "..CKWord("Перегрузка", "Overloada_rgb_ru").." также накладывает "..CKWord("электрошок", "elektroshok_rgb_ru").." на врагов в радиусе ближнего боя.\n"
			.."\n"
			.."Поражённые враги получают в течение {duration:%s} секунд:\n"
			..Dot_green.." "..CNumb("+", "n_plus_rgb").."{damage_taken:%s} "..CKWord("урона", "urona_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 2-2 - Invigorating Overload - Оживляющая перегрузка +]--	17.07.2026
	["loc_talent_cryptic_overload_keystone_toughness_stamina_desc"] = { -- talent_name: Martyrdom, corruption_resistance: +10%, +colors
		en = "When the "..CKWord("Overload", "Overload_rgb").." occurs, you and Allies in "..CKWord("Coherency", "Coherency_rgb").." restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." and\n"
			..Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb")..".",
		ru = "При возникновении "..CKWord("Перегрузки", "Overloadki_rgb_ru").." вы и союзники в "..CKWord("сплочённости", "splochennosti_rgb_ru").." восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." и\n"
			..Dot_green.." {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 2-3 - Static Capacitor Drain - Статический разряд конденсатора +]--	17.07.2026
	["loc_talent_cryptic_overload_keystone_permastack_desc"] = { -- talent_name: Martyrdom, attack_speed: +6%, +colors
		en = "After "..CKWord("overloading", "overloading_rgb").." {first_threshold:%s} times, you gain:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."After "..CKWord("overloading", "overloading_rgb").." {second_threshold:%s} times, you gain:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			.."After "..CKWord("overloading", "overloading_rgb").." {third_threshold:%s} times, you gain:\n"
			..Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb").." generation.\n"
			.."\n"
			..Dot_nc.." Bonuses last until death.",
		ru = "После получения "..CKWord("перегрузки", "overloading_rgb_ru").." в {first_threshold:%s} раз вы получаете:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."После получения "..CKWord("перегрузки", "Overload_rgb_ru").." в {second_threshold:%s} раз вы получаете:\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			.."После получения "..CKWord("перегрузки", "Overload_rgb_ru").." в {third_threshold:%s} раз вы получаете:\n"
			..Dot_green.." {power:%s} к генерации "..CKWord("ёмкости", "emkosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Бонусы действуют до смерти.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 2-4 - Powerdrive - Силовой привод +]--	17.07.2026
	["loc_talent_cryptic_overload_keystone_abilities_desc"] = { -- talent_name: Martyrdom, toughness_modifier: 5%, +colors
		en = "Per each "..CKWord("Combat Ability", "Cmbt_abil_rgb").." charge spent, you gain:\n"
			..Dot_green.." {stacks:%s} Stacks of "..CKWord("Power Overload", "PowerOverload_rgb")..".",
		ru = "За каждый потраченный заряд "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." вы получаете:\n"
			..Dot_green.." {stacks:%s} зарядов таланта "..CKWord("Перегрузка питания", "PowerOverload_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 3 - Flensing Protocols - Протоколы свежевания +]--	17.07.2026
	["loc_talent_cryptic_dissector_desc"] = { -- talent_name: Martyrdom, cooldown_regen: +50%, current_health: 25%, +colors
		en = "You have up to {max_stacks:%s} Stacks of {talent_name:%s}.\n"
			.."\n"
			.."Each Stack grants:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." and\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			.."Taking Damage removes:\n"
			..Dot_red.." {removed_stacks:%s} Stack.\n"
			..Dot_nc.." Can only occur once every second.\n" -- {icd:%s}
			.."\n"
			.."Elite and Specialist Kills restore:\n"
			..Dot_green.." {elite_special_stack:%s} Stacks and\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".",
		ru = "У вас может быть до {max_stacks:%s} зарядов таланта {talent_name:%s}.\n"
			.."\n"
			.."Каждый заряд даёт:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			.."Получение "..CKWord("урона", "urona_rgb_ru").." снимает:\n"
			..Dot_red.." {removed_stacks:%s} заряд.\n"
			..Dot_nc.." Срабатывает раз в секунду.\n" -- {icd:%s}
			.."\n"
			.."Убийства элитных врагов и специалистов восстанавливают:\n"
			..Dot_green.." {elite_special_stack:%s} заряда и\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 3-1 - Servo-Sinew Surge - Импульс сервосухожилий +]--	17.07.2026
	["loc_talent_cryptic_dissector_crit_attack_speed_desc"] = { -- toughness: 0.4%, +colors
		en = "Each Stack also grants:\n"
			..Dot_green.." {crit_chance:%s} "..CKWord("Critical Hit Chance", "Crt_hit_chnc_rgb").." and\n"
			..Dot_green.." {attack_speed:%s} Melee Attack Speed.",
		ru = "Каждый заряд также даёт:\n"
			..Dot_green.." {crit_chance:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru").." и\n"
			..Dot_green.." {attack_speed:%s} к скорости атак ближнего боя.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 3-2 - Higher Purpose - Высшая цель +]--	17.07.2026
	["loc_talent_cryptic_dissector_power_desc"] = { -- stacks: 3, +colors
		en = "Elite and Specialist Kills restore an additional:\n"
			..Dot_green.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb")..".",
		ru = "Убийства элитных врагов и специалистов восстанавливают дополнительно:\n"
			..Dot_green.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru")..".",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 3-3 - Enhanced Capacitance Protocols - Усиленные протоколы ёмкости +]--	17.07.2026
	["loc_talent_cryptic_dissector_ability_stacks_desc"] = { -- duration: 10, +colors
		en = Dot_green.." Using an "..CKWord("Ability", "Ability_rgb").." replenishes All Stacks.",
		ru = Dot_green.." Использование "..CKWord("способности", "sposobnosti_rgb_ru").." восполняет все заряды.",
	},
	--[+ KEYSTONE - КЛЮЧЕВОЙ ТАЛАНТ - 3-4 - Honed Dissector - Отточенный диссектор +]--	17.07.2026
	["loc_talent_cryptic_dissector_max_stacks_desc"] = { -- cooldown: +75%, duration: 2, +colors
		en = Dot_green.." Increase Max Stacks to {max_stacks:%s}.",
		ru = Dot_green.." Максимум зарядов увеличивается до {max_stacks:%s}.",
	},
--[+ +PASSIVES - ПАССИВНЫЕ+ +]--
	--[+ PASSIVES - ПАССИВНЫЙ - 1 - Overcharge Transfer Lattice - Решётка переноса перегрузки +]--	17.07.2026
	["loc_talent_cryptic_electrocution_defense_desc"] = { -- damage: +25%, +colors
		en = "When an Enemy hits you with a Melee Attack, they and Enemies within {range:%s} meters are "..CKWord("Electrocuted", "Electrocuted_rgb")..".\n"
			.."\n"
			..Dot_nc.." Cooldown: {cooldown:%s} seconds.",
		ru = "Когда враг попадает по вам атакой ближнего боя, он и враги в радиусе {range:%s} метров поражаются "..CKWord("электрошоком", "elektroshokom_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Восстановление: {cooldown:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 2 - Retribution Conduit - Проводник возмездия +]--	17.07.2026
	["loc_talent_cryptic_damage_vs_electrocuted_scaling_on_charge_desc"] = { -- damage: +5%, max_stacks: 5, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." vs "..CKWord("Electrocuted", "Electrocuted_rgb")..".\n"
			.."\n"
			..Dot_green.." {more_damage:%s} more "..CKWord("Damage", "Damage_rgb").." per current "..CKWord("Combat Ability", "Cmbt_abil_rgb").." сharge.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." против поражённых "..CKWord("электрошоком", "elektroshokom_rgb_ru").." врагов.\n"
			.."\n"
			..Dot_green.." {more_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." дополнительно за каждый заряд "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 3 - Kinetic Energy Distribution - Распределение кинетической энергии +]--	17.07.2026
	["loc_talent_cryptic_toughness_on_damage_taken_desc"] = { -- damage: +25%, +colors
		en = "On taking "..CKWord("Damage", "Damage_rgb")..", you restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.\n"
			.."\n"
			..Dot_nc.." Cooldown: {cooldown:%s} seconds.",
		ru = "При получении "..CKWord("урона", "urona_rgb_ru")..", вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.\n"
			.."\n"
			..Dot_nc.." Восстановление: {cooldown:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 4 - System Shock - Системный шок +]--	17.07.2026
	["loc_talent_cryptic_electrocution_applies_brittleness_desc"] = { -- toughness: 4%, +colors
		en = Dot_green.." {stacks:%s} Stacks of "..CNumb("2.5%", "pc_2_5_rgb").." "..CKWord("Brittleness", "Brittleness_rgb").." applied to enemies on "..CKWord("Electrocution", "Electrocution_rgb")..".",
		ru = Dot_green.." {stacks:%s} заряда "..CNumb("2.5%", "pc_2_5_rgb").." "..CKWord("хрупкости", "hrupkosti_rgb_ru").." накладывается на врагов при поражении их "..CKWord("электрошоком", "elektroshokom_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 5 - Entropic Transfer - Энтропийный перенос +]--	17.07.2026
	["loc_talent_cryptic_electrocution_toughness_desc"] = { -- toughness: +2.5%, range: 5, more_toughness: +1%, monster_count: 5, max: +7.5%, +colors
		en = "On "..CKWord("Electrocuting", "Electrocuting_rgb").." an Enemy, you restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.",
		ru = "При поражении врага "..CKWord("электрошоком", "elektroshokom_rgb_ru")..", вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 6 - Weakness Analysis Doctrine - Доктрина анализа уязвимостей +]--	17.07.2026
	["loc_talent_cryptic_afflicted_increased_damage_desc"] = { -- toughness: +100%, +colors
		en = "Hitting an Enemy afflicted with any of the following effects grants for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			.."Effects:\n"
			..Dot_nc.." "..CKWord("Electrocuted", "Electrocuted_rgb")..",\n"
			..Dot_nc.." "..CKWord("Soulblaze", "Soulblaze_rgb")..",\n"
			..Dot_nc.." "..CKWord("Burn", "Burn_rgb")..",\n"
			..Dot_nc.." "..CKWord("Bleed", "Bleed_rgb")..",\n"
			..Dot_nc.." "..CKWord("Chem Toxin", "Chem_Tox_rgb")..".\n"
			.."\n"
			..Dot_nc.." Triggers on both Melee and Ranged attacks.",
		ru = "Попадание по врагу, поражённому любым из нижеследующих эффектов, даёт на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."Эффекты:\n"
			..Dot_nc.." "..CKWord("Электрошок", "Elektroshok_rgb_ru")..",\n"
			..Dot_nc.." "..CKWord("Горение души", "Gorenie_dushi_rgb_ru")..",\n"
			..Dot_nc.." "..CKWord("Горение", "Gorenie_rgb_ru")..",\n"
			..Dot_nc.." "..CKWord("Кровотечение", "Krovotechenie_rgb_ru")..",\n"
			..Dot_nc.." "..CKWord("Хим-токсин", "Chem_Tox_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Срабатывает для атак ближнего и дальнего боя.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 7 - Voltaic Burst - Вольтаическая вспышка +]--	17.07.2026
	["loc_talent_cryptic_electrocution_push_desc"] = { -- toughness: 15%, +colors
		en = "Pushing an Enemy applies "..CKWord("Electrocution", "Electrocution_rgb")..", dealing "..CKWord("Damage", "Damage_rgb").." and "..CKWord("Stunning", "Stunning_rgb").." them.\n"
			.."\n"
			..Dot_nc.." Cooldown: {cooldown:%s} seconds.",
		ru = "Отталкивание врагов накладывает на них "..CKWord("электрошок", "elektroshok_rgb_ru")..", наносит "..CKWord("урон", "uron_rgb_ru").." и "..CKWord("оглушает", "oglushaet_rgb_ru").." их.\n"
			.."\n"
			..Dot_nc.." Восстановление: {cooldown:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 8 - Ablative Wards - Абляционные барьеры +]--	17.07.2026
	["loc_talent_cryptic_corruption_resistance_doom_desc"] = { -- toughness: 10%, +colors
		en = Dot_green.." {corruption_resistance:%s} "..CKWord("Corruption", "Corruption_rgb").." Resistance.\n"
			.."\n"
			..Dot_red.." {corruption_damage_flat:%s} "..CKWord("Corruption Damage", "Corruptdmg_rgb").." taken every {interval:%s} seconds.",
		ru = Dot_green.." {corruption_resistance:%s} к сопротивлению "..CKWord("порче", "porche_rgb_ru")..".\n"
			.."\n"
			..Dot_red.." {corruption_damage_flat:%s} "..CKWord("урона от порчи", "porchi_urona_rgb_ru").." накладывается каждые {interval:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 9 - Shockline Breach Protocol - Протокол прорыва шоковой линии +]--	17.07.2026
	["loc_talent_cryptic_pushing_grants_cleave_alt_desc"] = { -- damage: +20%, &->and, +colors
		en = "On Pushing an Enemy, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {cleave:%s} Melee "..CKWord("Cleave", "Cleave_rgb")..".",
		ru = "При отталкивании врага вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов в ближнем бою.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 10 - Galvanized Coating - Оцинкованное покрытие +]--	17.07.2026
	["loc_talent_cryptic_stun_dr_power_desc"] = { -- damage: +50%, duration: 3, s->seconds, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." Resistance.\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity.\n"
			.."\n"
			.."Taking Melee "..CKWord("Damage", "Damage_rgb").." spends:\n"
			..Dot_red.." {power:%s} "..CKWord("Capacitance", "Capacitance_rgb")..".",
		ru = Dot_green.." {damage:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru")..".\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru")..".\n"
			.."\n"
			.."Получение "..CKWord("урона", "urona_rgb_ru").." в ближнем бою тратит:\n"
			..Dot_red.." {power:%s} "..CKWord("ёмкости", "emkosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 11 - Electro-Strike Conduit - Проводник электроудара +]--	17.07.2026
	["loc_talent_cryptic_melee_crits_electrocute_first_desc"] = { -- active_duration: 5, cooldown_duration: 120, s->seconds, +colors
		en = "Melee "..CKWord("Critical Hits", "Crit_hits_rgb").." "..CKWord("Electrocute", "Electrocute_rgb").." the first Enemy hit.",
		ru = CKWord("Критические удары", "Krit_udary_rgb_ru").." в ближнем бою накладывают "..CKWord("электрошок", "elektroshok_rgb_ru").." на первого поражённого врага.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 12 - Data Sensor Protocol - Протокол сенсора данных +]--	17.07.2026
	["loc_talent_cryptic_ally_coherency_defenses_desc"] = { -- damage: +4%, time: 5, amount: 5, s->seconds, +colors
		en = "When you or an Ally in "..CKWord("Coherency", "Coherency_rgb").." take "..CKWord("Toughness Damage", "Tghns_dmg_rgb")..", they restore:\n"
			..Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb")..".\n"
			..Dot_nc.." Cooldown: {stamina_cd:%s} seconds.\n"
			.."\n"
			.."When you or an Ally in "..CKWord("Coherency", "Coherency_rgb").." take "..CKWord("Health", "Health_rgb").." "..CKWord("Damage", "Damage_rgb")..", they restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			..Dot_nc.." Cooldown: {toughness_cd:%s} seconds.",
		ru = "Когда вы или союзник в "..CKWord("сплочённости", "splochennosti_rgb_ru").." получаете "..CKWord("урон стойкости", "stoikosti_uron_rgb_ru")..", вы восстанавливаете:\n"
			..Dot_green.." {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".\n"
			..Dot_nc.." Восстановление: {stamina_cd:%s} секунд.\n"
			.."\n"
			.."Когда вы или союзник в "..CKWord("сплочённости", "splochennosti_rgb_ru").." получаете "..CKWord("урон", "uron_rgb_ru").." "..CKWord("здоровью", "zdoroviu_rgb_ru")..", вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			..Dot_nc.." Восстановление: {toughness_cd:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 13 - Salvation Doctrine - Доктрина спасения +]--	17.07.2026
	["loc_talent_cryptic_revive_speed_and_dr_desc"] = { -- talent_name: Until Death, max_health: 25%, melee_multiplier: 3, +colors
		en = Dot_green.." {damage_reduction:%s} "..CKWord("Damage", "Damage_rgb").." Resistance while Reviving an Ally.\n"
			.."\n"
			..Dot_green.." {revive_speed:%s} Revive Speed.",
		ru = Dot_green.." {damage_reduction:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." во время оживления союзника.\n"
			.."\n"
			..Dot_green.." {revive_speed:%s} к скорости оживления.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 14 - Precision Combat Augurs - Точные боевые авгуры +]--	17.07.2026
	["loc_talent_cryptic_next_attack_all_damage_on_dodge_desc"] = { -- movement_speed: +15%, time: 2, s->seconds, +colors
		en = Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb").." for your Next Attack on Successful Dodge.",
		ru = Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." для вашей следующей атаки при успешном уклонении.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 15 - Hybrid Combat Covenant - Завет о гибридном бое +]--	17.07.2026
	["loc_talent_cryptic_hybrid_damage_desc"] = { -- damage: +20%, s->seconds, +colors
		en = Dot_green.." {ranged_damage:%s} Ranged "..CKWord("Damage", "Damage_rgb").." for {duration:%s} seconds on Melee Kill.\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			.."\n"
			..Dot_green.." {melee_damage:%s} Melee "..CKWord("Damage", "Damage_rgb").." for {duration_two:%s} seconds on Ranged Kill.\n"
			..Dot_nc.." Stacks {max_stacks:%s} times.\n"
			.."\n"
			..Dot_nc.." Stacks decay one at a time.",
		ru = Dot_green.." {ranged_damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru").." на {duration:%s} секунд за убийство в ближнем бою.\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.\n"
			.."\n"
			..Dot_green.." {melee_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." ближнего боя на {duration_two:%s} секунд за убийство в дальнем бою.\n"
			..Dot_nc.." Суммируется {max_stacks:%s} раз.\n"
			.."\n"
			..Dot_nc.." Заряды сбрасываются по одному.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 16 - Auto-Repair Doctrines - Доктрины самопочинки +]--	17.07.2026
	["loc_talent_cryptic_toughness_per_charge_desc"] = { -- min_hits: 2, impact_modifier: +8%, time: 8, max_stacks: 5, s->seconds, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished per second.\n"
			.."\n"
			..Dot_green.." {toughness_per_charge:%s} additional "..CKWord("Toughness", "Toughness_rgb").." per current "..CKWord("Combat Ability", "Cmbt_abil_rgb").." сharge.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается в секунду.\n"
			.."\n"
			..Dot_green.." {toughness_per_charge:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается дополнительно за каждый текущий заряд "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 17 - Power Overflow - Переполнение питания +]--	17.07.2026
	["loc_talent_cryptic_shared_toughness_desc"] = { -- num_enemies: 2, range: 5, damage: +2%, cleave: +10%, stacks: 5, s->seconds, +colors
		en = "When at Full "..CKWord("Toughness", "Toughness_rgb")..":\n"
			..Dot_green.." {toughness_share:%s} of excess "..CKWord("Toughness", "Toughness_rgb").." Replenished is distributed to each Ally in "..CKWord("Coherency", "Coherency_rgb")..".",
		ru = "При полной "..CKWord("стойкости", "stoikosti_rgb_ru").." между союзниками в "..CKWord("сплочённости", "splochennosti_rgb_ru").." распределяется:\n"
			..Dot_green.." {toughness_share:%s} от избыточной восстанавливаемой "..CKWord("стойкости", "stoikosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 18 - Sequenced Charge - Последовательный заряд +]--	17.07.2026
	["loc_talent_cryptic_strength_on_charge_gain_desc"] = { -- damage_reduction: +60%, duration: 4, cooldown: 8, s->seconds, +colors
		en = "On gaining a "..CKWord("Combat Ability", "Cmbt_abil_rgb").." сharge, you gain:\n"
			..Dot_green.." {strength:%s} "..CKWord("Strength", "Strength_rgb")..".\n"
			.."\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "При получении заряда "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..", вы получаете:\n"
			..Dot_green.." {strength:%s} к "..CKWord("силе", "sile_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Длится {duration:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 19 - Target Prioritization Psalms - Псалмы приоритизации целей +]--	17.07.2026
	["loc_talent_cryptic_specials_marking_desc"] = { -- damage: +15%, +colors
		en = "Specialists that get within {range:%s} meters of you are Marked.",
		ru = "Специалисты, оказавшиеся в радиусе {range:%s} метров от вас, помечаются.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 20 - Moebian Conductor - Моэбианский проводник +]--	17.07.2026
	["loc_talent_cryptic_damage_on_ability_desc"] = { -- ammo: +5%, stacks: 5
		en = "On "..CKWord("Combat Ability", "Cmbt_abil_rgb").." use, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "При использовании "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 21 - Superior Defence Engrams - Улучшенные энграммы защиты +]--	17.07.2026
	["loc_talent_cryptic_ranged_stacking_toughness_desc"] = { -- attack_speed: +10%
		en = "Ranged Kills grant Stacks.\n"
			.."\n"
			.."Each Stack replenishes per second:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb")..".\n"
			.."\n"
			..Dot_nc.." Max {max_stacks:%s} Stacks.\n"
			..Dot_nc.." Lasts {duration:%s} seconds.",
		ru = "Убийства в дальнем бою дают заряды.\n"
			.."\n"
			.."Каждый заряд восстанавливает в секунду:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Максимум {max_stacks:%s} зарядов.\n"
			..Dot_nc.." Длится {duration:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 22 - Superior Tracking Litanies - Улучшенные литании отслеживания +]--	17.07.2026
	["loc_talent_cryptic_no_braced_movement_penalty_desc"] = { -- revive_speed: +25%, duration: 5, movement_speed: +10%, tdr: 15%
		en = "While bracing or aiming down sights you gain:\n"
			..Dot_green.." {spread:%s} Spread and\n"
			..Dot_green.." {movement_speed_modifier:%s} Movement Speed penalty.",
		ru = "При прицеливании вы получаете:\n"
			..Dot_green.." {spread:%s} к разбросу и\n"
			..Dot_green.." {movement_speed_modifier:%s} к штрафу скорости движения.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 23 - Omnissian Recharge Litany - Литания восстановления Омниссии +]--	17.07.2026
	["loc_talent_cryptic_multi_hits_restore_toughness_desc"] = { -- damage: +25%, duration: 2.5, s->seconds, +colors
		en = "On hitting {number:%s} or more enemies with a single Attack, you restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.",
		ru = "При попадании по {number:%s} или более врагам одной атакой, вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 24 - Residual Current Buffer - Буфер остаточного тока +]--	17.07.2026
	["loc_talent_cryptic_tdr_based_on_charge_base_desc"] = { -- linger_time: 2, block_cost: +50%, cooldown: 8, dodges: 3, s->seconds, +colors
		en = Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			..Dot_green.." {tdr_per_charge:%s} additional "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb").." per current "..CKWord("Combat Ability", "Cmbt_abil_rgb").." сharge.",
		ru = Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_green.." {tdr_per_charge:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru").." дополнительно за каждый текущий заряд "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 25 - Power Redistribution Uplink - Аплинк перераспределения питания +]--	17.07.2026
	["loc_talent_cryptic_crits_grant_tdr_desc"] = { -- stamina: 50%, cooldown: 12, s->seconds, +colors
		en = "On "..CKWord("Critical Hits", "Crit_hits_rgb")..", you restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").."\n"
			.."and gain for {duration:%s} seconds:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".",
		ru = "При "..CKWord("критических ударах", "krit_udarah_rgb_ru").." вы восстанавливаете:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").."\n"
			.."и получаете на {duration:%s} секунды:\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 25 - Binary Ballistics Protocol - Бинарный баллистический протокол +]--	17.07.2026
	["loc_talent_cryptic_elite_kills_toughness_desc"] = { -- damage: +15%, +colors
		en = "Elite Kills restore:\n"
			..Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." over {duration:%s} seconds.",
		ru = "Убийства элитных врагов восстанавливают:\n"
			..Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." в течение {duration:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 26 - Threat Detection Imperative - Императив обнаружения угроз +]--	17.07.2026
	["loc_talent_cryptic_ranged_kills_tdr_desc"] = { -- cooldown: 8, s->seconds
		en = "Ranged Kills grant Stacks.\n"
			.."\n"
			.."Each Stack grants for {duration:%s} seconds:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			..Dot_nc.." Max {stacks:%s} Stacks.\n"
			..Dot_nc.." Stacks decay one at a time.",
		ru = "Убийства в дальнем бою дают заряды.\n"
			.."\n"
			.."Каждый заряд даёт на {duration:%s} секунд:\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Максимум {stacks:%s} зарядов.\n"
			..Dot_nc.." Заряды сбрасываются по одному.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 27 - Assassination Protocols - Протоколы устранения +]--	17.07.2026
	["loc_talent_cryptic_ranged_vs_bfg_desc"] = { -- spread: -75%, recoil: -50%, duration: 3, s->seconds, +colors
		en = Dot_green.." {damage:%s} Ranged "..CKWord("Damage", "Damage_rgb").." vs Ogryns, Monstrosities and Captains.",
		ru = Dot_green.." {damage:%s} к дальнобойному "..CKWord("урону", "uronu_rgb_ru").." по огринам, чудовищам и капитанам.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 28 - Evasive Servo Recovery - Восстановление серво-уклонения +]--	17.07.2026
	["loc_talent_cryptic_successful_dodge_stamina_desc"] = { -- impact_modifier: +50%, +colors
		en = "On Successful Dodge, you restore:\n"
			..Dot_green.." {stamina:%s} "..CKWord("Stamina", "Stamina_rgb")..".",
		ru = "При успешном уклонении вы восстанавливаете:\n"
			..Dot_green.." {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 29 - Channelled Motive Force - Направленная движущая сила +]--	17.07.2026
	["loc_talent_cryptic_stamina_increases_damage_desc"] = { -- crit_chance: +10%, duration: 3, max_stacks: 3, s->seconds, +colors
		en = "On spending at least {stamina:%s} "..CKWord("Stamina", "Stamina_rgb")..", you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".",
		ru = "Если вы потратили как минимум {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru")..", вы получаете на {duration:%s} секунды:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 30 - Last Stand Relay - Реле последнего рубежа +]--	17.07.2026
	["loc_talent_cryptic_crit_chance_based_on_charge_zero_desc"] = { -- toughness_damage_reduction: +50%, time: 4, s->seconds, +colors
		en = Dot_green.." {crit_chance_low:%s} "..CKWord("Critical Hit Chance", "Crt_hit_chnc_rgb")..".\n"
			.."\n"
			.."When at {low_charges:%s} "..CKWord("Combat Ability", "Cmbt_abil_rgb").." сharges you gain:\n"
			..Dot_green.." {crit_chance_high:%s} "..CKWord("Critical Hit Chance", "Crt_hit_chnc_rgb")..".",
		ru = Dot_green.." {crit_chance_low:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru")..".\n"
			.."\n"
			.."При {low_charges:%s} зарядах "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru").." вы получаете:\n"
			..Dot_green.." {crit_chance_high:%s} к "..CKWord("шансу критического удара", "sh_krit_udara_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 31 - Ammo-Cell Augury - Авгурия ячейки боеприпасов +]--	17.07.2026
	["loc_talent_cryptic_ammo_reserve_desc"] = { -- attack_speed: +10%, duration: 5, s->seconds
		en = Dot_green.." {ammo:%s} Ammo Reserve.",
		ru = Dot_green.." {ammo:%s} к запасу боеприпасов.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 32 - Galvanic Marking Array - Гальванический маркировочный массив +]--	17.07.2026
	["loc_talent_cryptic_elite_kills_damage_desc"] = { -- damage_reduction: 40%, +colors
		en = "Ranged Elite Kills grant Stacks.\n"
			.."\n"
			.."Each Stack grants for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			..Dot_nc.." Max {stacks:%s} Stacks.\n"
			..Dot_nc.." Stacks decay one at a time.",
		ru = "Убийства элитных врагов в дальнем бою дают заряды.\n"
			.."\n"
			.."Каждый заряд даёт на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Максимум {stacks:%s} заряда.\n"
			..Dot_nc.." Заряды сбрасываются по одному.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 33 - Rad-Sink - Радиационный сток +]--	17.07.2026
	["loc_talent_cryptic_stacking_ranged_damage_desc"] = { -- damage: +50%, cooldown: 8, +colors
		en = "After {duration:%s} seconds without shooting, each additional second spent not shooting grants:\n"
			..Dot_green.." {ranged_damage:%s} Ranged "..CKWord("Damage", "Damage_rgb").." on your next Shot.\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.",
		ru = "Если вы не стреляли {duration:%s} секунду, то каждая последующая секунда без стрельбы даёт:\n"
			..Dot_green.." {ranged_damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." для вашего следующего выстрела.\n"
			.."\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 34 - Servo-Core Recharge Engine - Двигатель перезарядки сервоядра +]--	17.07.2026
	["loc_talent_cryptic_weakspot_kills_restore_toughness_desc"] = { -- damage_resistance: +15%, duration: 4, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." replenished on "..CKWord("Weakspot", "Weakspot_rgb").." Kill.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается при убийстве в "..CKWord("уязвимое место", "ujazvimoe_mesto_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 35 - Voltaic Restoration - Вольтаическое восстановление +]--	17.07.2026
	["loc_talent_cryptic_coherency_toughness_on_ability_desc"] = { -- damage_taken: +15%, duration: 5, +colors
		en = Dot_green.." {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." restored to you and Allies in "..CKWord("Coherency", "Coherency_rgb").." on "..CKWord("Combat Ability", "Cmbt_abil_rgb").." use.",
		ru = Dot_green.." {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается вам и союзникам в "..CKWord("сплочённости", "splochennosti_rgb_ru").." при использовании "..CKWord("боевой способности", "boev_sposobnosti_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 36 - Protectorate Protocol - Протокол протектората +]--	17.07.2026
	["loc_talent_cryptic_disabled_allies_defense_post_boost_desc"] = { -- damage: 10%, toughness: 15%, duration: 5, +colors
		en = "While an Ally in "..CKWord("Coherency", "Coherency_rgb").." is Incapacitated, they have until freed:\n"
			..Dot_green.." {damage_resistance:%s} "..CKWord("Damage", "Damage_rgb").." Resistance.\n"
			.."\n"
			.."If you free them, they gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage_resistance_post:%s} "..CKWord("Damage", "Damage_rgb").." Resistance and\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity.",
		ru = "Пока союзник в "..CKWord("сплочённости", "splochennosti_rgb_ru").." выведен из строя, он получает до освобождения:\n"
			..Dot_green.." {damage_resistance:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			.."Если вы освобождаете его, он получает на {duration:%s} секунд:\n"
			..Dot_green.." {damage_resistance_post:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." и\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 37 - Gunsmith - Оружейный мастер +]--	17.07.2026
	["loc_talent_cryptic_auto_reload_desc"] = { -- stamina: 10%, cooldown: 1, +colors
		en = Dot_green.." {reload_speed:%s} Reload Speed.\n"
			.."\n"
			.."After {duration:%s} seconds without shooting, each additional second reloads:\n"
			..Dot_green.." {reload_percent:%s} of your Clip from Reserve.",
		ru = Dot_green.." {reload_speed:%s} к скорости перезарядки.\n"
			.."\n"
			.."Если вы не стреляли {duration:%s} секунд, то за каждую последующую секунду перезаряжается:\n"
			..Dot_green.." {reload_percent:%s} магазина из резерва.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 38 - Ammunition-Restoration Pod - Капсула восстановления боеприпасов +]--	17.07.2026
	["loc_talent_cryptic_passive_ammo_replenishment_desc"] = {
		en = Dot_green.." {percent:%s} of your Max Ammo Reserve replenished every {interval:%s} seconds.",
		ru = Dot_green.." {percent:%s} от максимального запаса боеприпасов восстанавливается каждые {interval:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 39 - Adaptive Combat Calibration - Адаптивная боевая калибровка +]--	17.07.2026
	["loc_talent_cryptic_melee_cleave_and_impact_desc"] = { -- health_segment: +2
		en = "While above {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." you gain:\n"
			..Dot_green.." {cleave:%s} Melee "..CKWord("Cleave", "Cleave_rgb")..".\n"
			.."\n"
			.."While below {toughness:%s} "..CKWord("Toughness", "Toughness_rgb").." you gain:\n"
			..Dot_green.." {impact:%s} Melee "..CKWord("Impact", "Impact_rgb")..".",
		ru = "При {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." или выше вы получаете:\n"
			..Dot_green.." {cleave:%s} к "..CKWord("рассечению", "rassecheniu_rgb_ru").." врагов в ближнем бою.\n"
			.."\n"
			.."При {toughness:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." или ниже вы получаете:\n"
			..Dot_green.." {impact:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru").." в ближнем бою.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 40 - Progressive Plating Matrix - Прогрессивная матрица бронирования +]--	17.07.2026
	["loc_talent_cryptic_stacking_tdr_desc"] = { -- damage_reduction: 20%, time: 4, s->seconds, +colors
		en = "On Hit, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {tdr:%s} "..CKWord("Toughness Damage Reduction", "Tghns_dmg_red_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.\n"
			..Dot_nc.." Max one Stack per Attack.",
		ru = "При попадании по врагу вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {tdr:%s} к "..CKWord("снижению урона стойкости", "snu_ur_stoikosti_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.\n"
			..Dot_nc.." Не более одного заряда за атаку.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 41 - Sureshot Cogitator Sync - Синхронизация когитатора точности +]--	17.07.2026
	["loc_talent_cryptic_weakspot_damage_desc"] = { -- range: 8, cooldown: 5
		en = Dot_green.." {weakspot_damage:%s} "..CKWord("Weakspot Damage", "Weakspot_dmg_rgb")..".",
		ru = Dot_green.." {weakspot_damage:%s} к "..CKWord("урону по уязвимым местам", "u_mestam_uronu_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 42 - Ablative Motion Routines - Процедуры абляционных движений +]--	17.07.2026
	["loc_talent_cryptic_mobile_defense_desc"] = { -- sprint_speed: +10%, sprint_cost: -10%, duration: 1
		en = Dot_green.." {damage_resistance:%s} "..CKWord("Damage", "Damage_rgb").." Resistance while Sprinting or Sliding.",
		ru = Dot_green.." {damage_resistance:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru").." во время бега или подката.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 43 - Target-Neutralization Feedback - Обратная связь нейтрализации цели +]--	17.07.2026
	["loc_talent_cryptic_stun_suppression_immune_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = CKWord("Weakspot", "Weakspot_rgb").." kills grant for {duration:%s} seconds:\n"
			..Dot_green.." "..CKWord("Stun", "Stun_rgb").." Immunity and\n"
			..Dot_green.." Suppression Immunity.",
		ru = "Убийства в "..CKWord("уязвимые места", "ujazvimye_mesta_rgb_ru").." дают на {duration:%s} секунды:\n"
			..Dot_green.." Иммунитет к "..CKWord("ошеломлению", "oshelomleniu_rgb_ru").." и\n"
			..Dot_green.." Иммунитет к подавлению.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 44 - Uncapped Arrestor - Неограниченный разрядник +]--	17.07.2026
	["loc_talent_cryptic_melee_attacks_give_melee_attack_speed_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = "Successful Melee Attacks grant for {duration:%s} seconds:\n"
			..Dot_green.." {melee_attack_speed:%s} Melee Attack Speed.\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.",
		ru = "Успешные атаки ближнего боя дают на {duration:%s} секунды:\n"
			..Dot_green.." {melee_attack_speed:%s} к скорости атак ближнего боя.\n"
			.."\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 45 - Force Distribution Actuators - Актуаторы распределения силы +]--	17.07.2026
	["loc_talent_cryptic_push_stagger_stamina_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = "When at or above {stamina:%s} "..CKWord("Stamina", "Stamina_rgb").." your Pushes have:\n"
			..Dot_green.." {push_strength:%s} "..CKWord("Impact", "Impact_rgb")..".",
		ru = "При {stamina:%s} "..CKWord("выносливости", "vynoslivosti_rgb_ru").." или выше, ваши отталкивания получают:\n"
			..Dot_green.." {push_strength:%s} к "..CKWord("выведению из равновесия", "vyved_ravnovesia_rgb_ru")..".",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 46 - Sustained Assault Doctrine - Доктрина непрерывной атаки +]--	17.07.2026
	["loc_talent_cryptic_stacking_melee_damage_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = "On successful Melee Attack, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage:%s} "..CKWord("Damage", "Damage_rgb")..".\n"
			.."\n"
			..Dot_nc.." Stacks {stacks:%s} times.",
		ru = "При успешной атаке ближнего боя вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Суммируется до {stacks:%s} раз.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 47 - Slaughter Protocol - Протокол бойни +]--	17.07.2026
	["loc_talent_cryptic_toughness_replenishment_on_kill_bonus_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = Dot_green.." {toughness_percent:%s} "..CKWord("Toughness", "Toughness_rgb").." Replenishment on Melee Kill.\n"
			.."\n"
			..Dot_green.." {toughness_percent_improved:%s} "..CKWord("Toughness", "Toughness_rgb").." when at {zero_charges:%s} Charges.",
		ru = Dot_green.." {toughness_percent:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." восстанавливается за убийство в ближнем бою.\n"
			.."\n"
			..Dot_green.." {toughness_percent_improved:%s} "..CKWord("стойкости", "stoikosti_rgb_ru").." при {zero_charges:%s} зарядах.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 48 - Adaptive Combat Engram - Адаптивная боевая энграмма +]--	17.07.2026
	["loc_talent_cryptic_dr_on_toughness_break_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = "On "..CKWord("Toughness", "Toughness_rgb").." break, you gain for {duration:%s} seconds:\n"
			..Dot_green.." {damage_resistance:%s} "..CKWord("Damage", "Damage_rgb").." Resistance.\n"
			.."\n"
			..Dot_nc.." Can only occur once every {cooldown:%s} seconds.",
		ru = "При пробитии "..CKWord("стойкости", "stoikosti_rgb_ru").." вы получаете на {duration:%s} секунд:\n"
			..Dot_green.." {damage_resistance:%s} к сопротивлению "..CKWord("урону", "uronu_rgb_ru")..".\n"
			.."\n"
			..Dot_nc.." Срабатывает раз в {cooldown:%s} секунд.",
	},
	--[+ PASSIVES - ПАССИВНЫЙ - 49 - Hydraulic Inpact - Гидроудар +]--	17.07.2026
	["loc_talent_cryptic_better_heavies_desc"] = { -- damage: +5%, stacks: 3, duration: 8
		en = Dot_green.." Uninterruptible while charging Melee Attacks.\n"
			.."\n"
			..Dot_green.." {damage:%s} Heavy Melee "..CKWord("Damage", "Damage_rgb")..".",
		ru = Dot_green.." Вы получаете Непрерываемость во время заряжания атак ближнего боя.\n"
			.."\n"
			..Dot_green.." {damage:%s} к "..CKWord("урону", "uronu_rgb_ru").." тяжёлых атак ближнего боя.",
	},
}

-- Creating templates -- Создаём шаблоны
local skitarii_templates = {}

for loc_key, locales in pairs(skitarii_localizations) do
	for locale, text in pairs(locales) do
		table.insert(skitarii_templates, create_template(
			"skitarii_" .. loc_key,
			{loc_key},
			{locale},
			loc_text(text)
		))
	end
end

return skitarii_templates
