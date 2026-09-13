local mod = get_mod("HavocConditionManager")

mod:add_global_localize_strings({
	more_havoc_nurgle_blessing_title = {
		en = "Nurgle's Blessing",
		["zh-cn"] = "纳垢祝福",
		["zh-tw"] = "納垢祝福",
		ru = "Благословение Нургла",
	},
	more_havoc_nurgle_blessing_description = {
		en = "Enemies glow green, gain 35%% damage resistance and +25%% movement speed, ranged enemies attack faster and carry twice as much ammunition, and stagger resistance is greatly increased.",
		["zh-cn"] = "敌人周身泛绿，获得 35%% 伤害抗性、移速 +25%%，远程敌人的攻击动画加快且弹夹容量翻倍，踉跄抗性大幅提高。",
		["zh-tw"] = "敵人周身泛綠，獲得 35%% 傷害抗性、移速 +25%%，遠程敵人的攻擊動畫加快且彈匣容量翻倍，踉蹌抗性大幅提高。",
		ru = "Враги светятся зелёным, получают 35%% сопротивления урону и +25%% к скорости, дальние атаки ускорены, боезапас удвоен, устойчивость к stagger сильно повышена.",
	},
	more_havoc_monster_specials_title = {
		en = "Monster Specialists",
		["zh-cn"] = "怪物专家",
		["zh-tw"] = "怪物專家",
		ru = "Специалисты по монстрам",
	},
	more_havoc_monster_specials_description = {
		en = "Each special spawn has a 20%% chance to instead spawn a weakened boss with 40%% health. Up to 2 such bosses can be active at once, followed by a 90-180 second cooldown.",
		["zh-cn"] = "每次刷新特感时，有 20%% 几率改为刷新一只血量 40%% 的弱化 BOSS。最多可同时存在 2 只，达到上限后进入 90~180 秒冷却。",
		["zh-tw"] = "每次重新整理特感時，有 20%% 機率改為重新整理一隻血量 40%% 的弱化 BOSS。最多可同時存在 2 隻，達到上限後進入 90~180 秒冷卻。",
		ru = "При появлении специалиста есть 20%% шанс вместо него создать ослабленного босса с 40%% здоровья. Одновременно может быть до 2 таких боссов, затем перезарядка 90-180 секунд.",
	},
	more_havoc_monster_specials_weakened_suffix = {
		en = " (Weakened)",
		["zh-cn"] = "（虚弱）",
		["zh-tw"] = "（虛弱）",
		ru = " (ослаблен)",
	},
	more_havoc_assault_force_title = {
		en = "Assault Force",
		["zh-cn"] = "突击部队",
		["zh-tw"] = "突擊部隊",
		ru = "Штурмовой отряд",
	},
	more_havoc_assault_force_description = {
		en = "Always triggers coordinated strikes, increases special caps, speeds up special spawning, and challenge rating no longer stops specials from spawning.",
		["zh-cn"] = "必定触发协同突击，特感上限增加，特感刷新变快，挑战等级不再停止刷新特感",
		["zh-tw"] = "必定觸發協同突擊，特感上限增加，特感重新整理變快，挑戰等級不再停止重新整理特感",
		ru = "Всегда активирует скоординированные атаки, увеличивает лимиты специалистов, ускоряет их появление, а уровень угрозы больше не останавливает спавн специалистов.",
	},
	more_havoc_faction_switch_title = {
		en = "Faction Switch",
		["zh-cn"] = "阵营切换",
		["zh-tw"] = "陣營切換",
		ru = "Смена фракции",
	},
	more_havoc_faction_switch_description = {
		en = "Enemies may switch between renegade and cultist by travel distance.",
		["zh-cn"] = "敌人可能按路程在血痂和渣滓之间切换。",
		["zh-tw"] = "敵人可能按路程在血痂和渣滓之間切換。",
		ru = "Враги могут переключаться между отступниками и культистами по мере продвижения.",
	},
	more_havoc_faction_combined_title = {
		en = "Combined Faction",
		["zh-cn"] = "组合阵营",
		["zh-tw"] = "組合陣營",
		ru = "Комбинированная фракция",
	},
	more_havoc_faction_combined_description = {
		en = "Renegade and cultist enemies appear at the same time.",
		["zh-cn"] = "血痂和渣滓敌人会同时出现。",
		["zh-tw"] = "血痂和渣滓敵人會同時出現。",
		ru = "Враги-отступники и культисты появляются одновременно.",
	},
	more_old_rotten_armor_title = {
		en = "Rotten Armor (Old)",
		["zh-cn"] = "腐化装甲(旧版)",
		["zh-tw"] = "腐化裝甲(舊版)",
		ru = "Гнилая броня (старая)",
	},
	more_old_rotten_armor_description = {
		en = "Above 75%% health, Rotten Armor grants 75%% ranged damage reduction; below 75%%, it grants 50%% ranged damage reduction. Melee damage is not reduced. The Rotten Armor tide arrives in 4 waves of Executors, Maulers, and Berserkers.",
		["zh-cn"] = "生命值高于 75%% 时获得 75%% 远程减伤，低于 75%% 时获得 50%% 远程减伤；近战无减伤。腐盔潮改为每次 4 波，每波刷新粉碎者、血痂重锤兵、血痂狂战士各 2~8 个。",
		["zh-tw"] = "生命值高於 75%% 時獲得 75%% 遠端減傷，低於 75%% 時獲得 50%% 遠端減傷；近戰無減傷。腐盔潮改為每次 4 波，每波重新整理粉碎者、血痂重錘兵、血痂狂戰士各 2~8 個。",
		ru = "Выше 75%% здоровья «Гнилая броня» даёт 75%% сопротивления дальнему урону, ниже 75%% — 50%%. Ближний урон не снижается. Волна гнилой брони приходит 4 волнами с экзекуторами, молотобойцами и берсерками по 2-8 каждого.",
	},
	more_havoc_abhuman_title = {
		en = "Abhuman Mobilization",
		["zh-cn"] = "蛮子动员兵",
		["zh-tw"] = "蠻子動員兵",
		ru = "Мобилизация абьюманов",
	},
	more_havoc_abhuman_description = {
		en = "Faction is locked to the Renegade. Elite enemies are replaced with Ogryn elites, and periodic Ogryn elite trickle hordes spawn.",
		["zh-cn"] = "固定血痂阵营，精英敌人被替换为欧格林精英敌人，周期刷欧格林精英潮。",
		["zh-tw"] = "固定血痂陣營，精英敵人被替換為歐格林精英敵人，週期刷歐格林精英潮。",
		ru = "Фракция зафиксирована на отступниках. Элитные враги заменяются элитными огрейнами, периодически появляются волны огрейнов-элиты.",
	},
	more_havoc_elite_army_title = {
		en = "Unyielding Invasion",
		["zh-cn"] = "不屈入侵",
		["zh-tw"] = "不屈入侵",
		ru = "Непреклонное вторжение",
	},
	more_havoc_elite_army_description = {
		en = "Disables normal hordes, spawns more roaming enemies, makes events favor elites, and replaces lesser enemies with elites.",
		["zh-cn"] = "禁用普通尸潮，更多游荡敌人，事件更多精英，小怪替换为精英。",
		["zh-tw"] = "禁用普通屍潮，更多遊蕩敵人，事件更多精英，小怪替換為精英。",
		ru = "Отключает обычные орды, увеличивает число бродячих врагов, делает события более элитными и заменяет слабых врагов элитой.",
	},
	more_havoc_endless_hordes_title = {
		en = "Endless Hordes",
		["zh-cn"] = "无尽敌群",
		["zh-tw"] = "無盡敵群",
		ru = "Бесконечные орды",
	},
	more_havoc_endless_hordes_description = {
		en = "Disables normal hordes and spawns a large amount of extra hordes.",
		["zh-cn"] = "禁用普通尸潮，额外刷新大量尸潮。",
		["zh-tw"] = "禁用普通屍潮，額外重新整理大量屍潮。",
		ru = "Отключает обычные орды и создаёт большое количество дополнительных орд.",
	},
	more_havoc_barrel_grounds_title = {
		en = "Frenzied Explosions",
		["zh-cn"] = "纷乱爆燃",
		["zh-tw"] = "紛亂爆燃",
		ru = "Беспорядочные взрывы",
	},
	more_havoc_barrel_grounds_description = {
		en = "Turns all barrels into explosive barrels, periodically spawns shotgunners, berserkers, grenadiers, and poxwalkers, and shotgunners drop grenades on death with an 80%% chance.",
		["zh-cn"] = "所有桶变为爆炸桶，周期性刷霰弹手、狂战士、掷弹兵、自爆手，霰弹手死亡后80%%掉落手雷。",
		["zh-tw"] = "所有桶變為爆炸桶，週期性刷霰彈手、狂戰士、擲彈兵、自爆手，霰彈手死亡後80%%掉落手雷。",
		ru = "Все бочки становятся взрывными, периодически появляются дробовики, берсерки, гранатомётчики и трупные бомбардиры; дробовики с шансом 80%% роняют гранату при смерти.",
	},




})

return {
	mod_name = {
		en = "Solo Play More Havoc Circumstances",
		["zh-cn"] = "SoloPlay 额外浩劫词条",
		["zh-tw"] = "SoloPlay 額外浩劫詞條",
		ru = "Solo Play: больше условий «Верной смерти»",
	},
	mod_description = {
		en = "Extension for Solo Play. Adds up to 10 extra Havoc condition dropdowns to the Solo Play local game view (up to 12 circumstances in total). Adds Nurgle's Blessing, Monster Specialists, and Assault Force as real Havoc circumstances, plus an old Rotten Armor variant, selectable from the first two Havoc slots or the extra page, written into havoc_data and shown in the Tab tactical panel. The enemy faction dropdown also gains Switch and Combined options for mixed or simultaneous enemy faction appearances. All extra circumstances default to None.",
		["zh-cn"] = "SoloPlay 扩展。在 SoloPlay 本地游戏界面的浩劫模式中额外增加最多 10 个浩劫状况下拉框（总计最多 12 个词条），并加入会写入 havoc_data、显示在 Tab 战术面板的“纳垢祝福”、“怪物专家”和“突击部队”浩劫词条，并新增“腐化装甲(旧版)”词条；这些词条可在前两个浩劫槽或第 2 页选择。敌人阵营新增“切换”和“组合”选项，可分别实现血痂/渣滓按路程切换或同时出现。所有额外词条默认均为“无”。",
		["zh-tw"] = "SoloPlay 擴充。在 SoloPlay 本機遊戲介面的浩劫模式中額外增加最多 10 個浩劫條件下拉選單（總計最多 12 個詞條），並加入會寫入 havoc_data、顯示在 Tab 戰術面板的「納垢祝福」、「怪物專家」和「突擊部隊」浩劫詞條，並新增「腐化裝甲(舊版)」詞條；這些詞條可在前兩個浩劫槽或第 2 頁選擇。敵人陣營新增「切換」和「組合」選項，可分別實現血痂/渣滓按路程切換或同時出現。所有額外詞條預設皆為「無」。",
		ru = "Расширение для Solo Play. Добавляет до 10 дополнительных условий «Верной смерти» в локальное меню (до 12 условий всего), а также «Благословение Нургла», «Специалистов по монстрам» и «Штурмовой отряд» и старый вариант «Гнилой брони» как настоящие условия, доступные в первых двух слотах или на второй странице, записываемые в havoc_data и отображаемые на тактической панели Tab. В выборе фракции также добавлены варианты «Переключение» и «Комбинированная» для смены фракции по мере продвижения или одновременного появления обеих фракций. Все дополнительные условия по умолчанию отключены.",
	},
	extra_circumstance_count = {
		en = "Extra Havoc conditions",
		["zh-cn"] = "额外浩劫状况数量",
		["zh-tw"] = "額外浩劫條件數量",
		ru = "Доп. условий «Верной смерти»",
	},
	extra_circumstance_count_description = {
		en = "Number of additional Havoc condition dropdowns shown on page 2.\n0 disables them, 10 gives you 12 selectable circumstances in total.\nAll extra circumstances default to None.",
		["zh-cn"] = "第 2 页显示的额外浩劫状况下拉框数量。\n0 为关闭，10 表示总计可选 12 个词条。\n所有额外词条默认均为“无”。",
		["zh-tw"] = "第 2 頁顯示的額外浩劫條件下拉選單數量。\n0 為關閉，10 表示總計可選 12 個詞條。\n所有額外詞條預設皆為「無」。",
		ru = "Сколько дополнительных условий показывать на второй странице.\n0 — выключено, 10 — всего 12 выбираемых условий.\nВсе дополнительные условия по умолчанию отключены.",
	},
	nurgle_blessing_rank_scaling = {
		en = "Nurgle's Blessing: +0.5%% per Havoc rank",
		["zh-cn"] = "纳垢祝福：概率随浩劫层数提高",
		["zh-tw"] = "納垢祝福：機率隨浩劫層數提高",
		ru = "Благословение Нургла: +0,5%% за ранг",
	},
	nurgle_blessing_rank_scaling_description = {
		en = "When enabled, the added Nurgle's Blessing trigger chance increases by 0.5%% per Havoc rank. Disabled by default; when disabled, the blessing uses the original base trigger chances.",
		["zh-cn"] = "开启后，“纳垢祝福”的触发概率随浩劫等级每级提高 0.5%%。默认关闭；关闭时使用原版基础概率。",
		["zh-tw"] = "開啟後，「納垢祝福」的觸發機率隨浩劫等級每級提高 0.5%%。預設關閉；關閉時使用原版基礎機率。",
		ru = "При включении шанс срабатывания добавленного «Благословения Нургла» растёт на 0,5%% за ранг «Верной смерти». По умолчанию выключено; когда выключено, используются базовые шансы.",
	},
	monster_specials_melee_twin_captain = {
		en = "Monster Specialists boss: Melee Twin Captain",
		["zh-cn"] = "怪物专家 BOSS：近战双子中尉",
		["zh-tw"] = "怪物專家 BOSS：近戰雙子中尉",
		ru = "Босс «Специалистов по монстрам»: ближний бой, близнецы-капитаны",
	},
	monster_specials_melee_twin_captain_description = {
		en = "When enabled, Monster Specialists can replace a special with the melee Renegade Twin Captain (renegade_twin_captain_two) at full health. Disabled by default.",
		["zh-cn"] = "开启后，“怪物专家”生成的 BOSS 池中会加入近战双子中尉（renegade_twin_captain_two），保持原版满血，不应用 40%% 血量削减。默认关闭。",
		["zh-tw"] = "開啟後，「怪物專家」生成的 BOSS 池中會加入近戰雙子中尉（renegade_twin_captain_two），保持原版滿血，不套用 40%% 血量削減。預設關閉。",
		ru = "При включении «Специалисты по монстрам» могут заменить специалиста на близнеца-капитана ближнего боя (renegade_twin_captain_two) с полным здоровьем. По умолчанию выключено.",
	},
	monster_specials_ranged_twin_captain = {
		en = "Monster Specialists boss: Ranged Twin Captain",
		["zh-cn"] = "怪物专家 BOSS：远程双子中尉",
		["zh-tw"] = "怪物專家 BOSS：遠端雙子中尉",
		ru = "Босс «Специалистов по монстрам»: дальний бой, близнецы-капитаны",
	},
	monster_specials_ranged_twin_captain_description = {
		en = "When enabled, Monster Specialists can replace a special with the ranged Renegade Twin Captain (renegade_twin_captain) at full health. Disabled by default.",
		["zh-cn"] = "开启后，“怪物专家”生成的 BOSS 池中会加入远程双子中尉（renegade_twin_captain），保持原版满血，不应用 40%% 血量削减。默认关闭。",
		["zh-tw"] = "開啟後，「怪物專家」生成的 BOSS 池中會加入遠端雙子中尉（renegade_twin_captain），保持原版滿血，不套用 40%% 血量削減。預設關閉。",
		ru = "При включении «Специалисты по монстрам» могут заменить специалиста на близнеца-капитана дальнего боя (renegade_twin_captain) с полным здоровьем. По умолчанию выключено.",
	},
	monster_specials_houndmaster = {
		en = "Monster Specialists boss: Houndmaster",
		["zh-cn"] = "怪物专家 BOSS：猎群之主",
		["zh-tw"] = "怪物專家 BOSS：獵群之主",
		ru = "Босс «Специалистов по монстрам»: Хозяин гончих",
	},
	monster_specials_houndmaster_description = {
		en = "When enabled, Monster Specialists can replace a special with the Chaos Ogryn Houndmaster (chaos_ogryn_houndmaster) using the usual weakened-boss 40%% health. Its boss health bar shows \"Houndmaster (Weakened)\". Disabled by default.",
		["zh-cn"] = "开启后，“怪物专家”生成的 BOSS 池中会加入猎群之主（chaos_ogryn_houndmaster），并使用与其他默认 BOSS 相同的 40%% 弱化血量加成；BOSS 血条名称显示为“猎群之主（虚弱）”。默认关闭。",
		["zh-tw"] = "開啟後，「怪物專家」生成的 BOSS 池中會加入獵群之主（chaos_ogryn_houndmaster），並使用與其他預設 BOSS 相同的 40%% 弱化血量加成；BOSS 血條名稱顯示為「獵群之主（虛弱）」。預設關閉。",
		ru = "При включении «Специалисты по монстрам» могут заменить специалиста на Хозяина гончих (chaos_ogryn_houndmaster) с обычным для ослабленных боссов здоровьем 40%%. На полосе здоровья он отображается как «Хозяин гончих (ослаблен)». По умолчанию выключено.",
	},
	monster_specials_logging = {
		en = "Monster Specialists logging",
		["zh-cn"] = "怪物专家日志",
		["zh-tw"] = "怪物專家日誌",
		ru = "Журнал специалистов по монстрам",
	},
	monster_specials_logging_description = {
		en = "Log every Monster Specialists roll and spawned unit. Disabled by default because per-spawn logging hurts performance.",
		["zh-cn"] = "记录怪物专家的每次判定和实际生成的怪物。默认关闭，因为每次刷怪都写日志会影响性能。",
		["zh-tw"] = "記錄怪物專家的每次判定和實際生成的怪物。預設關閉，因為每次刷怪都寫日誌會影響效能。",
		ru = "Записывать в журнал каждый бросок «Специалистов по монстрам» и созданных монстров. По умолчанию выключено, так как постоянная запись влияет на производительность.",
	},
	option_nurgle_blessing = {
		en = "Nurgle's Blessing",
		["zh-cn"] = "纳垢祝福",
		["zh-tw"] = "納垢祝福",
		ru = "Благословение Нургла",
	},
	option_monster_specials = {
		en = "Monster Specialists",
		["zh-cn"] = "怪物专家",
		["zh-tw"] = "怪物專家",
		ru = "Специалисты по монстрам",
	},
	option_assault_force = {
		en = "Assault Force",
		["zh-cn"] = "突击部队",
		["zh-tw"] = "突擊部隊",
		ru = "Штурмовой отряд",
	},
	option_old_rotten_armor = {
		en = "Rotten Armor (Old)",
		["zh-cn"] = "腐化装甲(旧版)",
		["zh-tw"] = "腐化裝甲(舊版)",
		ru = "Гнилая броня (старая)",
	},
	option_abhuman = {
		en = "Abhuman Mobilization",
		["zh-cn"] = "蛮子动员兵",
		["zh-tw"] = "蠻子動員兵",
		ru = "Мобилизация абьюманов",
	},
	option_elite_army = {
		en = "Unyielding Invasion",
		["zh-cn"] = "不屈入侵",
		["zh-tw"] = "不屈入侵",
		ru = "Непреклонное вторжение",
	},
	option_endless_hordes = {
		en = "Endless Hordes",
		["zh-cn"] = "无尽敌群",
		["zh-tw"] = "無盡敵群",
		ru = "Бесконечные орды",
	},
	option_barrel_grounds = {
		en = "Frenzied Explosions",
		["zh-cn"] = "纷乱爆燃",
		["zh-tw"] = "紛亂爆燃",
		ru = "Беспорядочные взрывы",
	},




	option_faction_switch = {
		en = "Switch",
		["zh-cn"] = "切换",
		["zh-tw"] = "切換",
		ru = "Переключение",
	},
	option_faction_combined = {
		en = "Combined",
		["zh-cn"] = "组合",
		["zh-tw"] = "組合",
		ru = "Комбинированная",
	},
	faction_switch_guaranteed = {
		en = "Switch faction: Guaranteed faction switch by travel distance",
		["zh-cn"] = "切换阵营：按路程必定切换阵营",
		["zh-tw"] = "切換陣營：按路程必定切換陣營",
		ru = "Смена фракции: гарантированная смена фракции по мере продвижения",
	},
	faction_switch_guaranteed_description = {
		en = "When enabled, selecting the Switch faction option guarantees that enemies switch between renegade and cultist by travel distance.",
		["zh-cn"] = "开启后，选择“切换”阵营时，敌人必定按路程在血痂和渣滓之间切换。",
		["zh-tw"] = "開啟後，選擇「切換」陣營時，敵人必定按路程在血痂和渣滓之間切換。",
		ru = "При включении, при выборе опции «Переключение» враги гарантированно меняются между отступниками и культистами по мере продвижения.",
	},
	faction_combined_within_wave = {
		en = "Combined faction: within-wave random mixing",
		["zh-cn"] = "组合阵营：波内随机混合",
		["zh-tw"] = "組合陣營：波內隨機混合",
		ru = "Комбинированная фракция: смешивание внутри волны",
	},
	faction_combined_within_wave_description = {
		en = "When disabled, mixed factions use wave-level random mixing. When enabled, mixed factions use within-wave random mixing.",
		["zh-cn"] = "未开启时为波次随机混合，开启时为波内随机混合。",
		["zh-tw"] = "未開啟時為波次隨機混合，開啟時為波內隨機混合。",
		ru = "При выключении используется случайное смешивание по волнам, при включении — случайное смешивание внутри волны.",
	},
	default_text_none = {
		en = "None",
		["zh-cn"] = "无",
		["zh-tw"] = "無",
		ru = "Нет",
	},
	page_title_extra_circumstances = {
		en = "Extra Havoc Conditions",
		["zh-cn"] = "额外浩劫词条",
		["zh-tw"] = "額外浩劫詞條",
		ru = "Доп. условия «Верной смерти»",
	},
	page_hint_extra_circumstances = {
		en = "Use the arrow on the left to return and start the game.",
		["zh-cn"] = "点击左侧箭头返回第 1 页开始游戏。",
		["zh-tw"] = "點選左側箭頭返回第 1 頁開始遊戲。",
		ru = "Нажмите стрелку слева, чтобы вернуться и начать игру.",
	},
	page_indicator = {
		en = "Page %d / %d",
		["zh-cn"] = "第 %d / %d 页",
		["zh-tw"] = "第 %d / %d 頁",
		ru = "Стр. %d / %d",
	},
	label_extra_circumstance = {
		en = "Havoc Condition %d",
		["zh-cn"] = "浩劫状况 %d",
		["zh-tw"] = "浩劫條件 %d",
		ru = "Условие «Верной смерти» %d",
	},
	msg_missing_soloplay = {
		en = "HavocConditionManager requires Solo Play (2.6.0 or newer) and must be loaded after it.",
		["zh-cn"] = "HavocConditionManager 需要 Solo Play（2.6.0 或更新），并且必须排在其后加载。",
		["zh-tw"] = "HavocConditionManager 需要 Solo Play（2.6.0 或更新），且必須排在其後載入。",
		ru = "HavocConditionManager требует Solo Play (2.6.0 или новее) и должен загружаться после него.",
	},
}