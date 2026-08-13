return {
	mod_name = {
		en = "Servo-Skull & Hound Commander",
		ru = "Servo-Skull & Hound Commander — командир сервочерепа и мастифа",
	},
	mod_description = {
		en = "Companion assistant for the Skitarii servo-skull and the Arbites cyber-mastiff: auto-attack orders with threat priorities, daemonhost protection, ability charge gate, manual order guard (skull cooldown / psyker shields), heal order aim-snap with per-class revive priorities and green outline on downed allies.",
		ru = "Помощник компаньона Скитария (сервочереп) и Арбитра (кибермастиф): авто-приказы атаки с приоритетами угроз, защита от демонхостов, гейт по зарядам способности, защита ручного приказа (КД черепа / щиты псайкера), доворот прицела для лечения с приоритетами воскрешения по классам и зелёная подсветка павших союзников.",
	},
	group_auto = {
		en = "Auto-attack",
		ru = "Авто-атака",
	},
	auto_enabled = {
		en = "Enable auto-attack",
		ru = "Включить авто-атаку",
	},
	auto_enabled_desc = {
		en = "The mod periodically orders the servo-skull to shoot the highest-priority enemy (same as double-tagging it yourself).",
		ru = "Мод периодически приказывает сервочерепу стрелять по самой приоритетной цели (то же самое, что двойная метка вручную).",
	},
	auto_toggle_key = {
		en = "Auto-attack toggle key",
		ru = "Клавиша вкл/выкл авто-атаки",
	},
	auto_toggle_key_desc = {
		en = "Toggle auto-attack mid-mission to take full manual control of the skull.",
		ru = "Переключайте авто-атаку посреди миссии, чтобы полностью управлять черепом вручную.",
	},
	auto_interval = {
		en = "Re-order interval (sec)",
		ru = "Интервал приказа по цели (сек)",
	},
	auto_interval_desc = {
		en = "How often the mod re-issues the order to the CURRENT target (keeps it focused and refreshes the fire-rate buff). This does NOT switch targets — see 'Target hold time' below. Example: 1.2 = re-order the same enemy every 1.2s.",
		ru = "Как часто мод переотдаёт приказ по ТЕКУЩЕЙ цели (держит фокус и обновляет бафф скорострельности). Смену цели НЕ регулирует — см. «Время удержания цели» ниже. Пример: 1.2 = переприказ по той же цели каждые 1.2с.",
	},
	switch_interval = {
		en = "Target hold time (sec)",
		ru = "Время удержания цели (сек)",
	},
	switch_interval_desc = {
		en = "Minimum seconds to stay on the current target before switching to a higher-priority one. The skull always switches instantly when the current target dies or leaves range. Set high to commit hard to a target; 0 = switch to the best target as soon as one appears.",
		ru = "Минимум секунд держаться за текущую цель, прежде чем переключиться на более приоритетную. На мёртвую/ушедшую цель череп переключается мгновенно в любом случае. Больше = крепче держит цель; 0 = переключаться на лучшую сразу, как появится.",
	},
	auto_max_distance = {
		en = "Max target distance (m)",
		ru = "Макс. дистанция цели (м)",
	},
	auto_max_distance_desc = {
		en = "Targets beyond this distance are ignored (snipers and bombers are exempt). Skull damage falls off heavily past 15 m.",
		ru = "Цели дальше этой дистанции игнорируются (кроме снайперов и бомберов). Урон черепа сильно падает после 15 м.",
	},
	auto_cone_angle = {
		en = "View cone for new targets (degrees)",
		ru = "Конус обзора для новых целей (градусы)",
	},
	auto_cone_angle_desc = {
		en = "New targets are only acquired inside this cone around your camera direction — roughly what you can see on screen. 360 = look direction ignored (targets picked all around you). The current target is kept and re-ordered even if it leaves the cone.",
		ru = "Новые цели берутся только внутри этого конуса вокруг направления взгляда — примерно то, что вы видите на экране. 360 = направление взгляда не учитывается (цели берутся вокруг вас). Текущая цель удерживается и переприказывается, даже если вышла из конуса.",
	},
	aim_switch_enabled = {
		en = "Switch to the enemy you aim at",
		ru = "Переключаться на цель под прицелом",
	},
	aim_switch_enabled_desc = {
		en = "While auto-attack is on, whatever enemy your crosshair is on (the exact unit the tag key would pick) instantly becomes the skull's target — no double-tag needed. This is a pure manual-style override: it IGNORES the priority table, the view cone, the max distance limit and the force field / smoke / wall checks AND the Poxburster forbidden radius. Point at it and it gets marked. While you keep aiming at it the skull holds it; look away and normal priority logic (with all its checks) resumes. Note: with the Improved Tagging talent, the charge gate can still pause this — use panic mode to override that.",
		ru = "При включённой авто-атаке враг под прицелом (ровно та цель, что выбрала бы клавиша метки) мгновенно становится целью черепа — двойная метка не нужна. Это чистый ручной оверрайд: он ИГНОРИРУЕТ таблицу приоритетов, конус обзора, лимит макс. дистанции и проверки поля / дыма / стен, А ТАКЖЕ запретный радиус взрывунов. Навёл — пометилось. Пока держите под прицелом, череп держит цель; отвели взгляд — снова обычная логика приоритетов (со всеми проверками). Примечание: с талантом улучшенной метки гейт по зарядам всё ещё может ставить это на паузу — используйте паник-режим, чтобы его обойти.",
	},
	ignore_unaggroed = {
		en = "Ignore unalerted enemies",
		ru = "Игнорировать непотревоженных врагов",
	},
	ignore_unaggroed_desc = {
		en = "Don't auto-acquire enemies that haven't noticed anyone yet (they have no combat target) — the skull won't drag sleeping patrols and ambient mobs into a fight early. The current target is never dropped because of this, and aiming at an enemy directly (option above) overrides the filter — deliberate aim counts as intent.",
		ru = "Не брать в цели врагов, которые ещё никого не заметили (у них нет боевой цели) — череп не будет раньше времени втягивать в бой спящие патрули и фоновых мобов. Текущая цель из-за этого никогда не сбрасывается, а прямое наведение прицела (опция выше) фильтр обходит — осознанный прицел значит намерение.",
	},
	auto_block_shield = {
		en = "Auto: don't order through force fields",
		ru = "Авто: не приказывать сквозь силовые поля",
	},
	auto_block_shield_desc = {
		en = "Skip targets when a psyker shield/dome is involved in any way: the line crosses it, the target stands inside one, or the skull is inside one. The skull's shots cannot penetrate fields and do not work inside domes either.",
		ru = "Пропускать цели, если силовое поле псайкера замешано хоть как-то: линия пересекает стенку/купол, цель стоит внутри купола или сам череп внутри. Выстрелы черепа поля не пробивают и внутри куполов тоже не работают.",
	},
	auto_block_smoke = {
		en = "Auto: don't order through smoke",
		ru = "Авто: не приказывать сквозь дым",
	},
	auto_block_smoke_desc = {
		en = "Skip targets when a veteran smoke cloud is on the skull-to-target line (or the skull stands in one). The servo-skull cannot see or shoot through smoke, so such orders are wasted. Pox gas and other clouds do NOT block shots and are not affected by this.",
		ru = "Пропускать цели, если дым ветерана на линии череп→цель (или череп стоит в дыму). Сервочереп не видит и не стреляет сквозь дым, поэтому такие приказы теряются. Pox-газ и прочие облака выстрелы НЕ блокируют и этой настройкой не затрагиваются.",
	},
	auto_in_training = {
		en = "Attack in training areas (Psykhanium)",
		ru = "Атака в тренировочных зонах (Псайканум)",
	},
	auto_in_training_desc = {
		en = "Off by default. The Meat Grinder / Psykhanium shooting range (tg_shooting_range) is flagged non-aggressive by the game and keeps the servo-skull passive there. When ON, the mod still sends orders — they may work if the skull has line of sight, but the game may ignore them. Real missions are unaffected either way.",
		ru = "По умолчанию выкл. Тир Meat Grinder / Псайканум (tg_shooting_range) помечен игрой как неагрессивный и держит сервочереп пассивным. При ВКЛ мод всё равно шлёт приказы — они могут сработать, если у черепа есть прямая видимость, но игра может их игнорировать. На реальные миссии не влияет в любом случае.",
	},
	debug_enabled = {
		en = "Debug messages",
		ru = "Отладочные сообщения",
	},
	debug_enabled_desc = {
		en = "Print chosen targets, block reasons and tag confirmation to chat. ORDER CONFIRMED = the order's tag actually appeared in the game's tag list (_all_tags); ORDER NOT CONFIRMED = the game rejected/ignored the order call.",
		ru = "Писать в чат выбранные цели, причины блокировок и подтверждение тегов. ORDER CONFIRMED = тег приказа реально появился в списке тегов игры (_all_tags); ORDER NOT CONFIRMED = игра отклонила/проигнорировала вызов приказа.",
	},
	group_dog = {
		en = "Cyber-Mastiff (Adeptus Arbites)",
		ru = "Кибермастиф (Адептус Арбитрес)",
	},
	group_dog_desc = {
		en = "Everything in the Auto-attack group applies to the Arbites mastiff as well (enable/toggle key, aim switch, unalerted filter, manual pause, training areas, debug) and so does the whole Target priorities table — the dog takes orders through exactly the same double-tag as the servo-skull. Only the engagement envelope is separate, and lives here, because the dog has to physically reach its target. Force field / smoke / wall checks are always skipped for it (it walks around walls), it cannot revive anyone, and the charge gate does not apply — Arbites orders are free.",
		ru = "Всё из группы «Авто-атака» действует и для мастифа Арбитра (вкл/клавиша, переключение по прицелу, фильтр непотревоженных, пауза после ручного приказа, тренировочные зоны, отладка), и вся таблица «Приоритеты целей» — тоже: пёс получает приказы ровно той же двойной меткой, что и сервочереп. Отдельный только «конверт» вовлечения, и он здесь, потому что пёс должен физически добраться до цели. Проверки силового поля / дыма / стен для него всегда пропускаются (он обходит стены), воскрешать он не умеет, а гейт по зарядам не применяется — у Арбитра приказы бесплатны.",
	},
	dog_max_distance = {
		en = "Mastiff: max target distance (m)",
		ru = "Мастиф: макс. дистанция цели (м)",
	},
	dog_max_distance_desc = {
		en = "The Arbites mastiff runs to whatever it is pointed at, so it needs its own reach setting: a dog sent across the room leaves you alone and arrives late. Snipers and bombers get NO exemption from this limit (unlike the skull) for the same reason. The game itself puts no distance cap on an ordered target, so the slider goes up to 100 m if you want a hunter rather than a bodyguard — but the default 25 m is what keeps it next to you.",
		ru = "Мастиф Арбитра бежит к цели ножками, поэтому у него свой параметр радиуса: пёс, отправленный через всю комнату, оставляет вас одного и прибегает поздно. Снайперы и бомберы для него НЕ исключение из лимита (в отличие от черепа) по той же причине. Сама игра дистанцию приказанной цели ничем не ограничивает, поэтому ползунок доходит до 100 м, если нужен охотник, а не телохранитель — но именно дефолтные 25 м держат пса рядом с вами.",
	},
	dog_cone_angle = {
		en = "Mastiff: view cone for new targets (degrees)",
		ru = "Мастиф: конус обзора для новых целей (градусы)",
	},
	dog_cone_angle_desc = {
		en = "Same idea as the servo-skull view cone, but wider by default (180) — the dog is a bodyguard and you usually want it to answer threats at your flanks, not only what you are staring at. 360 = look direction ignored. The current target is kept even if it leaves the cone.",
		ru = "То же, что конус обзора сервочерепа, но по умолчанию шире (180) — пёс работает телохранителем, и обычно нужно, чтобы он реагировал на угрозы с флангов, а не только на то, куда вы смотрите. 360 = направление взгляда не учитывается. Текущая цель удерживается, даже если вышла из конуса.",
	},
	dog_interval = {
		en = "Mastiff: re-order interval (sec)",
		ru = "Мастиф: интервал приказа по цели (сек)",
	},
	dog_interval_desc = {
		en = "How often the order on the CURRENT target is re-issued. Orders are free for the Arbites (no charge cost), so this is only about keeping the dog pinned on the target. Re-orders can be sparse for the dog: the game's order tag lives 25 s, so even the 15 s maximum refreshes it without a gap, and a NEW target is always ordered instantly regardless of this value. Range 4-15 s, default 4.",
		ru = "Как часто переотдаётся приказ по ТЕКУЩЕЙ цели. У Арбитра приказы бесплатны (не тратят заряды), так что это только про удержание пса на цели. Псу редкие переприказы не вредят: тег приказа в игре живёт 25 с, поэтому даже максимум в 15 с обновляет его без разрыва, а НОВАЯ цель приказывается мгновенно независимо от этого значения. Диапазон 4-15 с, дефолт 4.",
	},
	dog_switch_interval = {
		en = "Mastiff: target hold time (sec)",
		ru = "Мастиф: время удержания цели (сек)",
	},
	dog_switch_interval_desc = {
		en = "Minimum seconds before switching to a higher-priority target. Longer than the skull's default on purpose: every switch throws away the distance the dog has already covered, so the dog cannot be set below 2.5 s (the skull can go to zero). It still switches instantly when the target dies or leaves range.",
		ru = "Минимум секунд до переключения на более приоритетную цель. Специально больше, чем у черепа: каждое переключение обнуляет уже пройденный псом путь, поэтому псу нельзя поставить меньше 2.5 с (черепу можно и ноль). На мёртвую/ушедшую цель переключение всё равно мгновенное.",
	},
	dog_skip_game_excluded = {
		en = "Mastiff: skip targets the game keeps it away from",
		ru = "Мастиф: пропускать цели, от которых его держит игра",
	},
	dog_skip_game_excluded_desc = {
		en = "The game's own mastiff target selection deliberately ignores a few breeds — Poxbursters, gunships and hazards. A whistle order bypasses that filter, so this option re-applies it. Leave it on unless you specifically want to pounce Poxbursters.",
		ru = "Собственный выбор целей мастифа в игре намеренно игнорирует несколько типов — взрывунов, ганшипы и хазарды. Приказ свистком этот фильтр обходит, и данная опция возвращает его. Оставьте включённым, если специально не хотите прыжков по взрывунам.",
	},
	group_daemonhost = {
		en = "Daemonhost protection",
		ru = "Защита от демонхостов",
	},
	group_daemonhost_desc = {
		en = "A dedicated off-switch for Daemonhosts, separate from the boss/captain priority. It exists for the case where somebody else wakes or shoots the Daemonhost and your companion joins in — which makes the Daemonhost come for YOU. Covers all three paths an order can take: the priority table, the aim-switch override, and your own double-tap.",
		ru = "Отдельный выключатель для демонхостов, независимый от приоритета боссов/капитанов. Существует для случая, когда демонхоста будит или атакует кто-то другой, а ваш компаньон подключается — и демонхост идёт за ВАМИ. Покрывает все три пути приказа: таблицу приоритетов, оверрайд по прицелу и вашу собственную двойную метку.",
	},
	dh_block_auto = {
		en = "Never auto-order onto a Daemonhost",
		ru = "Никогда не приказывать авто-атаку по демонхосту",
	},
	dh_block_auto_desc = {
		en = "On by default. Daemonhosts are excluded from every automatic order path, including the 'Switch to the enemy you aim at' override which otherwise ignores the whole priority table. Turn this OFF only if you deliberately want the companion to help fight an awakened Daemonhost — a sleeping one is still never ordered on (the game refuses such orders anyway) and its priority then comes from the 'Bosses / captains' slider.",
		ru = "По умолчанию вкл. Демонхосты исключены из всех путей автоматического приказа, включая оверрайд «Переключаться на цель под прицелом», который иначе игнорирует всю таблицу приоритетов. Выключайте ТОЛЬКО если сознательно хотите, чтобы компаньон помогал драться с разбуженным демонхостом — по спящему приказ не пойдёт всё равно (игра такие приказы отклоняет), а приоритет тогда берётся из ползунка «Боссы / капитаны».",
	},
	dh_block_manual = {
		en = "Block manual order on a Daemonhost",
		ru = "Блокировать ручной приказ по демонхосту",
	},
	dh_block_manual_desc = {
		en = "On by default. Your own double-tag on a Daemonhost becomes a regular ping instead of an attack order. This is the one order that cannot be taken back — a stray double-tap on a Daemonhost your team is walking past aggroes it onto you.",
		ru = "По умолчанию вкл. Ваша собственная двойная метка по демонхосту становится обычной меткой, а не приказом атаки. Это единственный приказ, который нельзя отменить: случайный двойной тап по демонхосту, мимо которого проходит команда, агрит его на вас.",
	},
	dh_divert = {
		en = "Keep the companion busy near an awakened Daemonhost",
		ru = "Занимать компаньона рядом с разбуженным демонхостом",
	},
	dh_divert_desc = {
		en = "On by default, and the actual fix for 'someone woke the Daemonhost and my skull started shooting it'. An ordered target pins the companion — the game's own target selection only gets a say while the companion has no order. So while a Daemonhost is inside the distance below, if nothing in your priority table qualifies, the mod orders the companion onto the nearest ordinary alerted enemy instead (ignoring the priority table, never a Daemonhost and never a Poxburster) purely to keep that window shut. If there is no other alerted enemy in range, nothing can be done — the game is then free to pick the Daemonhost by itself.",
		ru = "По умолчанию вкл. — это и есть настоящее решение проблемы «кто-то разбудил демонхоста, и мой череп начал по нему стрелять». Отданный приказ прибивает компаньона к цели, а собственный выбор целей игры срабатывает только пока приказа нет. Поэтому пока демонхост в пределах дистанции ниже и в вашей таблице приоритетов нет подходящей цели, мод приказывает компаньону атаковать ближайшего обычного потревоженного врага (игнорируя таблицу приоритетов, никогда не демонхоста и не взрывуна) — только чтобы закрыть это окно. Если другого потревоженного врага в радиусе нет, сделать нельзя ничего: игра свободна выбрать демонхоста сама.",
	},
	dh_dist = {
		en = "— Daemonhost watch radius (m)",
		ru = "— радиус наблюдения за демонхостом (м)",
	},
	dh_dist_desc = {
		en = "Distance from you at which a Daemonhost switches the protection on. The servo-skull's own target selection reaches about 20 m, so 25 m keeps a margin.",
		ru = "Дистанция от вас, на которой демонхост включает защиту. Собственный выбор целей сервочерепа достаёт примерно на 20 м, поэтому 25 м оставляют запас.",
	},
	dh_include_sleeping = {
		en = "— also react to sleeping Daemonhosts",
		ru = "— реагировать и на спящих демонхостов",
	},
	dh_include_sleeping_desc = {
		en = "Off by default: a sleeping Daemonhost is harmless and the protection only engages once one is awake. Turn it on if you want the guard active while sneaking past a sleeping one too — useful together with 'Stop auto-attack entirely', so nothing of yours makes noise near it.",
		ru = "По умолчанию выкл.: спящий демонхост безобиден, и защита включается только когда он разбужен. Включите, если хотите, чтобы защита работала и при прокрадывании мимо спящего — полезно вместе с «Полностью останавливать авто-атаку», чтобы рядом с ним ничего вашего не шумело.",
	},
	dh_divert_interval = {
		en = "— keep-busy re-order interval (sec)",
		ru = "— интервал переприказа «занять» (сек)",
	},
	dh_divert_interval_desc = {
		en = "Re-order interval used ONLY for these keep-busy orders, so the pin can be refreshed faster than your normal interval without spending charges on ordinary targets.",
		ru = "Интервал переприказа, применяемый ТОЛЬКО к этим приказам «занять» — чтобы обновлять привязку чаще обычного интервала, не тратя заряды на обычные цели.",
	},
	dh_override_gate = {
		en = "— ignore the charge gate for keep-busy orders",
		ru = "— игнорировать гейт зарядов для приказов «занять»",
	},
	dh_override_gate_desc = {
		en = "Off by default. Only matters with the Improved Tagging talent, where orders cost combat ability charge: with the gate active the companion can fall silent exactly when you need it pinned away from the Daemonhost. Turning this on spends charge to hold the pin — same idea as the disabler override in the charge gate group.",
		ru = "По умолчанию выкл. Имеет смысл только с талантом улучшенной метки, где приказы тратят заряд боевой способности: при активном гейте компаньон может замолчать ровно тогда, когда его нужно держать в стороне от демонхоста. Включение тратит заряд, чтобы удержать привязку — та же идея, что оверрайд по дизейблерам в группе гейта.",
	},
	dh_full_stop = {
		en = "Stop auto-attack entirely near a Daemonhost",
		ru = "Полностью останавливать авто-атаку у демонхоста",
	},
	dh_full_stop_desc = {
		en = "Off by default, and it OVERRIDES the keep-busy option above. While a Daemonhost is inside the watch radius, no automatic orders are sent at all. Read this carefully: a companion with no order is exactly the state in which the game's own target selection is free to pick the awakened Daemonhost, so as a Daemonhost guard this is usually WORSE than keeping it busy. It is here for the case you want a truly silent companion — for instance together with 'also react to sleeping Daemonhosts' while the team sneaks past. Your own manual orders still work.",
		ru = "По умолчанию выкл., и ПЕРЕКРЫВАЕТ опцию «занимать» выше. Пока демонхост в радиусе наблюдения, автоматические приказы не отправляются вообще. Важно понимать: компаньон без приказа — это ровно то состояние, в котором собственный выбор целей игры свободен взять разбуженного демонхоста, поэтому как защита от демонхоста это обычно ХУЖЕ, чем «занимать». Опция здесь для случая, когда нужен действительно молчащий компаньон — например вместе с «реагировать и на спящих», пока команда прокрадывается мимо. Ваши ручные приказы продолжают работать.",
	},
	dh_notify = {
		en = "Chat message when the protection engages",
		ru = "Сообщение в чат при включении защиты",
	},
	dh_notify_desc = {
		en = "Locally announces when Daemonhost protection turns on and off, so it is obvious why the companion started behaving differently.",
		ru = "Локально сообщает, когда защита от демонхостов включается и выключается — чтобы было понятно, почему компаньон начал вести себя иначе.",
	},
	group_gate = {
		en = "Combat ability charge gate",
		ru = "Гейт по зарядам боевой способности",
	},
	gate_enabled = {
		en = "Pause auto-attack on low charges",
		ru = "Пауза авто-атаки при малом заряде",
	},
	gate_enabled_desc = {
		en = "Only matters with the Improved Tagging talent (orders are free without it). Auto-attack pauses while your combat ability reserve is below the threshold.",
		ru = "Имеет смысл только с талантом улучшенной метки (без него приказы бесплатны). Авто-атака встаёт на паузу, пока запас боевой способности ниже порога.",
	},
	gate_charges = {
		en = "Keep charges",
		ru = "Держать зарядов",
	},
	gate_charges_desc = {
		en = "Whole-charge part of the reserve to keep. Auto-attack runs while (charges + recharge progress) >= (this + percent/100). Minimum possible reserve = 0 charges + 1%%. 4 and 5 are for extra-charge builds (Redline / Power Generation): the threshold is always clamped to your actual maximum, so picking more charges than your talents grant simply means 'keep a full bar' instead of switching auto-attack off forever.",
		ru = "Целые заряды запаса, который держать. Авто-атака работает, пока (заряды + прогресс восстановления) >= (это + процент/100). Минимально возможный запас = 0 зарядов + 1%%. Варианты 4 и 5 — для билдов с доп. зарядами (Redline / Power Generation): порог всегда ограничивается вашим реальным максимумом, поэтому выбор большего числа зарядов, чем дают таланты, означает просто «держать полную шкалу», а не выключает авто-атаку навсегда.",
	},
	gate_charges_0 = { en = "0", ru = "0" },
	gate_charges_1 = { en = "1", ru = "1" },
	gate_charges_2 = { en = "2", ru = "2" },
	gate_charges_3 = { en = "3", ru = "3" },
	gate_charges_4 = { en = "4", ru = "4" },
	gate_charges_5 = { en = "5", ru = "5" },
	gate_percent = {
		en = "Extra charge fraction (%%)",
		ru = "Доп. доля заряда (%%)",
	},
	gate_percent_desc = {
		en = "Fractional part added on top of the charges above. Example: charges=1, 50%% means keep at least 1.5 charges. Minimum: charges=0, 1%%.",
		ru = "Дробная часть поверх зарядов выше. Пример: зарядов=1, 50%% — держать минимум 1.5 заряда. Минимум: зарядов=0, 1%%.",
	},
	gate_override_disablers = {
		en = "Ignore the gate for disablers in range",
		ru = "Игнорировать гейт при дизейблерах рядом",
	},
	gate_override_disablers_desc = {
		en = "Automatic panic for disablers: while a Trapper is within its net distance or a Hound within its leap distance (the distance sliders in Priorities), the charge gate is bypassed and the skull keeps ordering even at 0 charges. Only the gate is bypassed — priorities and force field / smoke / wall checks still apply.",
		ru = "Автоматическая паника при дизейблерах: пока траппер в пределах дистанции сети или собака в пределах дистанции прыжка (ползунки дистанций в приоритетах), гейт по зарядам обходится, и череп приказывает даже при 0 зарядов. Обходится только гейт — приоритеты и проверки поля / дыма / стен действуют по-прежнему.",
	},
	group_panic = {
		en = "Panic mode",
		ru = "Паник-режим",
	},
	panic_key = {
		en = "Panic mode key",
		ru = "Клавиша паник-режима",
	},
	panic_key_desc = {
		en = "Press to trigger panic mode. While panic is active the skull attacks targets ignoring the charge gate entirely — it keeps ordering even at 0 charges and 0%%. Everything else (priorities, force field / smoke / wall checks) still applies. Pressing the key again always turns panic off.",
		ru = "Нажмите, чтобы включить паник-режим. Пока паника активна, череп атакует цели, полностью игнорируя гейт по зарядам — приказывает даже при 0 зарядов и 0%%. Всё остальное (приоритеты, проверки поля / дыма / стен) продолжает действовать. Повторное нажатие клавиши всегда выключает панику.",
	},
	panic_hold = {
		en = "Panic until pressed again",
		ru = "Паника до повторного нажатия",
	},
	panic_hold_desc = {
		en = "When on, the panic key latches: one press turns panic on and it stays on until you press the key again. Takes priority over the timed toggle below. If both toggles are off, the key also works this way.",
		ru = "Когда включено, клавиша паники работает как фиксатор: одно нажатие включает панику, и она держится до повторного нажатия. Имеет приоритет над таймером ниже. Если оба тогглера выключены — клавиша тоже работает так.",
	},
	panic_timed = {
		en = "Panic for a set time",
		ru = "Паника на заданное время",
	},
	panic_timed_desc = {
		en = "When on (and 'until pressed again' is off), one press runs panic for the number of seconds below, then it turns off automatically. Pressing the key again during that time turns panic off early.",
		ru = "Когда включено (а «до повторного нажатия» выключено), одно нажатие запускает панику на указанное ниже число секунд, затем она выключается сама. Повторное нажатие в это время выключает панику досрочно.",
	},
	panic_duration = {
		en = "Panic duration (sec)",
		ru = "Длительность паники (сек)",
	},
	panic_duration_desc = {
		en = "How many seconds timed panic lasts (only used when 'Panic for a set time' is on).",
		ru = "Сколько секунд длится паника по таймеру (используется только при включённом «Паника на заданное время»).",
	},
	group_manual = {
		en = "Manual orders",
		ru = "Ручные приказы",
	},
	manual_pause_enabled = {
		en = "Manual order pauses auto-attack",
		ru = "Ручной приказ ставит авто-атаку на паузу",
	},
	manual_pause_enabled_desc = {
		en = "Your own double-tag always wins: the mod stops ordering for a while after your last manual order.",
		ru = "Ваш собственный приказ всегда важнее: мод перестаёт приказывать на время после вашей последней ручной метки.",
	},
	manual_pause_time = {
		en = "Pause after manual order (sec)",
		ru = "Пауза после ручного приказа (сек)",
	},
	manual_pause_time_desc = {
		en = "Auto-attack resumes this many seconds after your last manual order.",
		ru = "Авто-атака возобновляется через столько секунд после последнего ручного приказа.",
	},
	manual_block_busy = {
		en = "Block manual order while skull is busy",
		ru = "Блокировать ручной приказ, пока череп занят",
	},
	manual_block_busy_desc = {
		en = "Off by default. The skull's shot cooldown cycles every ~3s and an order placed during it is NOT wasted (the skull fires when ready), so blocking on cooldown is pointless. When ON, this only downgrades your order to a ping while the skull is truly busy (hacking / healing / flaming) and cannot shoot.",
		ru = "По умолчанию выкл. Перезарядка выстрела черепа циклится каждые ~3с, и приказ во время неё НЕ теряется (череп выстрелит, когда будет готов), поэтому блок по КД бессмысленен. Когда ВКЛ — понижает приказ до метки только пока череп реально занят (взлом / лечение / огнемёт) и не может стрелять.",
	},
	manual_block_shield = {
		en = "Block manual order through force fields",
		ru = "Блокировать ручной приказ сквозь силовые поля",
	},
	manual_block_shield_desc = {
		en = "If a psyker shield/dome is involved in any way (the line crosses it, the target is inside one, or the skull is inside one), your double-tag becomes a regular ping.",
		ru = "Если силовое поле псайкера замешано хоть как-то (линия пересекает его, цель внутри купола или череп внутри), двойная метка становится обычной меткой.",
	},
	manual_block_smoke = {
		en = "Block manual order through smoke",
		ru = "Блокировать ручной приказ сквозь дым",
	},
	manual_block_smoke_desc = {
		en = "If a veteran smoke cloud is on the skull-to-target line (or the skull is inside one), your double-tag becomes a regular ping. The skull cannot shoot through smoke.",
		ru = "Если дым ветерана на линии череп→цель (или череп внутри дыма), двойная метка становится обычной меткой. Череп не стреляет сквозь дым.",
	},
	manual_block_burster = {
		en = "Block manual order on close Poxbursters",
		ru = "Блокировать ручной приказ по близким взрывунам",
	},
	manual_block_burster_desc = {
		en = "Off by default. When ON, double-tagging a Poxburster that is inside the manual radius below becomes a regular ping instead of an attack order, so you cannot pop one in your own face by mistake. If 'Forbidden radius protects teammates too' (in Target priorities) is on, the guard also fires when any living ally — bots included — is inside that radius. Poxbursters outside the radius can be ordered normally. This is separate from the auto-attack forbidden radius: manual gets its own, wider setting because you often want to tag a burster far down the corridor while still being protected up close.",
		ru = "По умолчанию выкл. Когда ВКЛ, двойная метка по взрывуну внутри ручного радиуса ниже становится обычной меткой, а не приказом атаки — так вы не подорвёте его себе в лицо по ошибке. Если включено «Запретный радиус защищает и союзников» (в приоритетах целей), защита срабатывает и когда внутри радиуса любой живой союзник, включая ботов. По взрывунам за пределами радиуса приказ проходит как обычно. Это отдельная настройка от запретного радиуса авто-атаки: у ручного приказа свой, более широкий радиус, потому что часто нужно пометить взрывуна далеко в конце коридора, оставаясь защищённым вблизи.",
	},
	dist_burster_manual = {
		en = "— manual Poxburster radius (m)",
		ru = "— ручной радиус взрывуна (м)",
	},
	dist_burster_manual_desc = {
		en = "Manual orders on Poxbursters closer than this (to you, or to any teammate when teammate protection is on) are downgraded to a ping. The explosion radius is 6 m; default 10 m keeps a margin. Range goes up to 50 m so you can forbid manual burster orders across most of the room. NOTE: this radius only governs your own double-tags. If you set it wider than the auto-attack forbidden radius, auto-attack can still pick up a burster in the gap between the two — raise the forbidden radius in Target priorities to match, or use 'Never target Poxbursters' there.",
		ru = "Ручные приказы по взрывунам ближе этой дистанции (к вам или к любому союзнику при включённой защите союзников) понижаются до метки. Радиус взрыва 6 м; дефолт 10 м оставляет запас. Диапазон до 50 м — можно запретить ручные приказы по взрывунам почти по всей комнате. ВАЖНО: этот радиус управляет только вашими двойными метками. Если сделать его шире запретного радиуса авто-атаки, авто-атака всё ещё сможет взять взрывуна в промежутке между ними — поднимите запретный радиус в приоритетах целей до того же значения или включите там «Никогда не атаковать взрывунов».",
	},
	block_notify = {
		en = "Chat message on blocked order",
		ru = "Сообщение в чат при блокировке приказа",
	},
	block_notify_desc = {
		en = "Locally shows why a manual order was downgraded (busy / shield / smoke / Poxburster).",
		ru = "Локально показывает, почему ручной приказ был понижен до метки (занят / щит / дым / взрывун).",
	},
	group_priorities = {
		en = "Target priorities (0 = never)",
		ru = "Приоритеты целей (0 = никогда)",
	},
	group_priorities_desc = {
		en = "Shared by both companions: the threat ranking is about the enemy, not about who is sent at it. What differs per companion is the engagement envelope (distance, view cone, hold time) — the servo-skull uses the Auto-attack group, the Arbites mastiff the Cyber-Mastiff group.",
		ru = "Общие для обоих компаньонов: рейтинг угроз описывает врага, а не того, кого на него посылают. Различается только «конверт» вовлечения (дистанция, конус, удержание): у сервочерепа — группа «Авто-атака», у мастифа Арбитра — группа «Кибермастиф».",
	},
	prio_hound_close = {
		en = "Hound in leap range",
		ru = "Собака в радиусе прыжка",
	},
	prio_hound_close_desc = {
		en = "Priority for Chaos Hounds within their leap distance below. Beyond it they fall back to the disabler line-of-sight priority.",
		ru = "Приоритет для собак Хаоса в пределах их дистанции прыжка (ниже). Дальше — резервный приоритет дизейблера в прямой видимости.",
	},
	dist_hound = {
		en = "— hound leap distance (m)",
		ru = "— дистанция прыжка собаки (м)",
	},
	dist_hound_desc = {
		en = "A hound can leap from ~14+ m. Default 15 m keeps a small margin.",
		ru = "Собака прыгает с ~14+ м. Дефолт 15 м оставляет небольшой запас.",
	},
	prio_hound_far = {
		en = "Hound beyond leap range",
		ru = "Собака дальше дистанции прыжка",
	},
	prio_hound_far_desc = {
		en = "Priority for hounds beyond the leap distance above. 0 = never target far hounds.",
		ru = "Приоритет для собак дальше дистанции прыжка выше. 0 = дальние собаки не атакуются никогда.",
	},
	prio_trapper_close = {
		en = "Trapper in net range",
		ru = "Траппер в радиусе сети",
	},
	prio_trapper_close_desc = {
		en = "Priority for Scab Trappers (Netgunners) within their net distance below. Beyond it they fall back to the disabler line-of-sight priority.",
		ru = "Приоритет для трапперов (сетемётчиков) в пределах их дистанции сети (ниже). Дальше — резервный приоритет дизейблера в прямой видимости.",
	},
	dist_trapper = {
		en = "— trapper net distance (m)",
		ru = "— дистанция сети траппера (м)",
	},
	dist_trapper_desc = {
		en = "A trapper's net reaches ~14 m. Default 15 m keeps a small margin.",
		ru = "Сеть траппера бьёт на ~14 м. Дефолт 15 м оставляет небольшой запас.",
	},
	prio_trapper_far = {
		en = "Trapper beyond net range",
		ru = "Траппер дальше дистанции сети",
	},
	prio_trapper_far_desc = {
		en = "Priority for trappers beyond the net distance above. 0 = never target far trappers.",
		ru = "Приоритет для трапперов дальше дистанции сети выше. 0 = дальние трапперы не атакуются никогда.",
	},
	prio_mutant = {
		en = "Mutant (any distance)",
		ru = "Мутант (любая дистанция)",
	},
	prio_mutant_desc = {
		en = "Priority for Mutants at any distance within the max target distance. 0 = never target Mutants.",
		ru = "Приоритет для мутантов на любой дистанции в пределах макс. дальности. 0 = мутанты не атакуются никогда.",
	},
	prio_flamer_close = {
		en = "Flamer in burn range",
		ru = "Огнемётчик в радиусе поджога",
	},
	prio_flamer_close_desc = {
		en = "Priority for Scab/Dreg Flamers within their burn distance below. Beyond it they fall back to the 'Other specials' priority.",
		ru = "Приоритет для огнемётчиков Scab/Dreg в пределах их дистанции поджога (ниже). Дальше — приоритет «Прочие специалисты».",
	},
	dist_flamer = {
		en = "— flamer burn distance (m)",
		ru = "— дистанция поджога огнемётчика (м)",
	},
	dist_flamer_desc = {
		en = "A flamer burns up to ~15 m. Default 15 m matches its reach.",
		ru = "Огнемётчик жжёт до ~15 м. Дефолт 15 м совпадает с его дальностью.",
	},
	prio_sniper = {
		en = "Sniper (any distance)",
		ru = "Снайпер (любая дистанция)",
	},
	prio_sniper_desc = {
		en = "Scab Sniper. Ignores the max distance limit. 0 = never target snipers.",
		ru = "Снайпер. Игнорирует лимит макс. дистанции. 0 = снайперы не атакуются никогда.",
	},
	prio_bomber = {
		en = "Bombers (any distance)",
		ru = "Бомберы (любая дистанция)",
	},
	prio_bomber_desc = {
		en = "Scab Bomber and Dreg Tox Bomber. Ignore the max distance limit. 0 = never target bombers.",
		ru = "Обычный и токсичный бомберы. Игнорируют лимит макс. дистанции. 0 = бомберы не атакуются никогда.",
	},
	prio_shotgunner_close = {
		en = "Shotgunner in effective range",
		ru = "Шотганнер на эффективной дистанции",
	},
	prio_shotgunner_close_desc = {
		en = "Beyond that range shotgunners use the Gunner priority.",
		ru = "Дальше этой дистанции шотганнеры получают приоритет пулемётчиков.",
	},
	dist_shotgunner = {
		en = "— shotgunner range (m)",
		ru = "— дистанция шотганнера (м)",
	},
	dist_shotgunner_desc = {
		en = "Shotgun hurts most within ~8-15 m.",
		ru = "Дробовик больнее всего в пределах ~8-15 м.",
	},
	prio_gunner = {
		en = "Gunners (Scab/Dreg)",
		ru = "Пулемётчики (Scab/Dreg)",
	},
	prio_gunner_desc = {
		en = "Regular Scab/Dreg Gunners only. Reaper and Plasma have their own sliders below.",
		ru = "Только обычные пулемётчики Scab/Dreg. У Жнеца и Плазмы отдельные ползунки ниже.",
	},
	prio_reaper = {
		en = "Reaper (Ogryn gunner)",
		ru = "Жнец (огрин-пулемётчик)",
	},
	prio_reaper_desc = {
		en = "Chaos Ogryn Reaper — heavy stubber ogryn.",
		ru = "Огрин-Жнец с тяжёлым стаббером.",
	},
	prio_plasma = {
		en = "Plasma Gunner",
		ru = "Плазмоган (плазма-стрелок)",
	},
	prio_plasma_desc = {
		en = "Scab Plasma Gunner — high burst, worth killing fast.",
		ru = "Скаб-плазмаган — большой бурст, выгодно убивать быстро.",
	},
	prio_elite_close = {
		en = "Any elite nearby",
		ru = "Любая элита рядом",
	},
	prio_elite_close_desc = {
		en = "Elites (ragers, maulers, crushers...) within the distance below.",
		ru = "Элита (рейджеры, маулеры, крашеры...) в пределах дистанции ниже.",
	},
	dist_elite = {
		en = "— elite distance (m)",
		ru = "— дистанция элиты (м)",
	},
	dist_elite_desc = {
		en = "Elites are prioritized only within this range.",
		ru = "Элита приоритетна только в этом радиусе.",
	},
	prio_elite_far = {
		en = "Elite beyond that distance",
		ru = "Элита дальше этой дистанции",
	},
	prio_elite_far_desc = {
		en = "0 = don't target far elites.",
		ru = "0 = не целиться в дальнюю элиту.",
	},
	burster_never = {
		en = "Never target Poxbursters",
		ru = "Никогда не атаковать взрывунов",
	},
	burster_never_desc = {
		en = "Hard off-switch for auto-attack: the skull is never auto-ordered onto a Poxburster — at any distance, regardless of the priority slider below. Your own double-tags are not affected; guard those with 'Block manual order on close Poxbursters' in the Manual orders group.",
		ru = "Жёсткий выключатель для авто-атаки: череп никогда не получит авто-приказ по взрывуну — на любой дистанции, независимо от ползунка приоритета ниже. Ваши собственные двойные метки не затрагиваются; для них есть «Блокировать ручной приказ по близким взрывунам» в группе ручных приказов.",
	},
	burster_team_radius = {
		en = "Forbidden radius protects teammates too",
		ru = "Запретный радиус защищает и союзников",
	},
	burster_team_radius_desc = {
		en = "A Poxburster is never targeted while ANY living teammate — not just you, bots included — is inside the forbidden radius below. If the skull is already attacking a Poxburster and someone steps into the radius, the mod immediately switches it to the best other elite/special, skipping the force-field and smoke checks for that emergency switch so it happens as fast as possible. This also extends the manual Poxburster guard (Manual orders group) to your teammates.",
		ru = "Взрывун не атакуется, пока ЛЮБОЙ живой союзник — не только вы, боты тоже — внутри запретного радиуса ниже. Если череп уже атакует взрывуна и кто-то вошёл в радиус, мод немедленно переключает его на лучшую другую элиту/специалиста, пропуская проверки силового поля и дыма для этого аварийного переключения — чтобы оно случилось как можно быстрее. Это же распространяет защиту от взрывунов при ручном приказе (группа ручных приказов) на союзников.",
	},
	prio_burster_far = {
		en = "Poxburster beyond safe radius",
		ru = "Взрывун дальше безопасного радиуса",
	},
	prio_burster_far_desc = {
		en = "Poxbursters are NEVER targeted inside the forbidden radius below (they explode near you).",
		ru = "Взрывуны НИКОГДА не атакуются внутри запретного радиуса ниже (взорвутся рядом с вами).",
	},
	dist_burster_forbidden = {
		en = "— forbidden radius (m)",
		ru = "— запретный радиус (м)",
	},
	dist_burster_forbidden_desc = {
		en = "Auto-attack only. Explosion radius is 6 m; default 10 m keeps a margin. Manual double-tags use their own radius in the Manual orders group — set both to the same value if you want one consistent no-go zone around bursters.",
		ru = "Только для авто-атаки. Радиус взрыва 6 м; дефолт 10 м оставляет запас. У ручных двойных меток свой радиус в группе ручных приказов — поставьте оба значения одинаковыми, если нужна единая запретная зона вокруг взрывунов.",
	},
	prio_monster = {
		en = "Bosses / captains",
		ru = "Боссы / капитаны",
	},
	prio_monster_desc = {
		en = "Monstrosities and captains. Daemonhosts are NOT covered by this slider by default — they have their own group (Daemonhost protection) and are excluded from every automatic order. Only if you switch 'Never auto-order onto a Daemonhost' off does an awakened Daemonhost fall back to this priority; a sleeping one is never targeted either way.",
		ru = "Монстры и капитаны. Демонхосты по умолчанию этим ползунком НЕ управляются — у них своя группа («Защита от демонхостов»), и они исключены из всех автоматических приказов. Только если выключить «Никогда не приказывать авто-атаку по демонхосту», разбуженный демонхост получит этот приоритет; спящий не атакуется в любом случае.",
	},
	prio_special_other = {
		en = "Other specials",
		ru = "Прочие специалисты",
	},
	prio_special_other_desc = {
		en = "Any special not covered above (e.g. far flamer).",
		ru = "Специалисты, не попавшие в категории выше (например, дальний огнемётчик).",
	},
	group_heal = {
		en = "Heal order (Medicae skull)",
		ru = "Приказ лечения (Медикэ-череп)",
	},
	heal_snap_enabled = {
		en = "Aim-snap to downed allies",
		ru = "Доворот прицела на павших союзников",
	},
	heal_snap_enabled_desc = {
		en = "While aiming the skull order (blitz held), the view turns toward the nearest valid downed ally so the heal order locks on easily.",
		ru = "Пока вы целитесь приказом (зажат блиц), прицел сам доворачивается к ближайшему павшему союзнику — приказ лечения наводится легко.",
	},
	heal_snap_speed = {
		en = "Snap speed (deg/sec)",
		ru = "Скорость доворота (град/сек)",
	},
	heal_snap_speed_desc = {
		en = "How fast the view turns toward the ally.",
		ru = "Как быстро прицел поворачивается к союзнику.",
	},
	heal_snap_cone = {
		en = "Aim-snap cone (degrees)",
		ru = "Конус доворота (градусы)",
	},
	heal_snap_cone_desc = {
		en = "The view only snaps to a downed ally inside this cone around your look direction (same idea as the attack view cone). 360 = snap to the nearest downed ally in any direction. Narrow it so a closer ally behind you does not spin your camera around — you rez the one you are facing.",
		ru = "Прицел доворачивается к павшему союзнику только внутри этого конуса вокруг направления взгляда (та же идея, что и конус атаки боевого черепа). 360 = доворот к ближайшему павшему в любую сторону. Сузьте, чтобы более близкий союзник за спиной не разворачивал вам камеру — поднимаете того, на кого смотрите.",
	},
	heal_auto_launch = {
		en = "Auto-launch when aimed at an ally",
		ru = "Авто-запуск при наведении на союзника",
	},
	heal_auto_launch_desc = {
		en = "While you hold the blitz, the skull launches by itself as soon as it is fully raised and the aim has settled on a valid downed ally — no need to release the key at the right time. One launch per key press: to send another, release and hold again.",
		ru = "Пока вы держите блиц, череп улетает сам, как только он поднят и прицел устойчиво сошёлся на валидном павшем союзнике — не нужно ловить момент отжатия. Один запуск за одно нажатие: чтобы послать снова, отпустите и зажмите ещё раз.",
	},
	heal_block_second = {
		en = "Don't send a second skull while the first is reviving",
		ru = "Не отправлять второй череп, пока первый воскрешает",
	},
	heal_block_second_desc = {
		en = "While the servo-skull is busy reviving an ally, holding the blitz does nothing — aiming for a second heal order is refused until the first revive finishes. Prevents wasting the skull on a duplicate order.",
		ru = "Пока сервочереп занят воскрешением союзника, зажатие блица ничего не делает — прицеливание второго приказа лечения блокируется, пока первое воскрешение не завершится. Не даёт потратить череп на дублирующий приказ.",
	},
	heal_outline_enabled = {
		en = "Bright green outline on downed allies",
		ru = "Ярко-зелёный силуэт павших союзников",
	},
	heal_outline_enabled_desc = {
		en = "Highlights allies who need help (visible through walls). Active for any class the mod supports (Skitarii, Arbites) — the Arbites mastiff cannot revive, but knowing who is down is still useful. Allies the heal order is not allowed to reach (bots when bots are excluded, or a class set to priority 0) are NOT outlined, so the highlight never promises a revive the mod will refuse.",
		ru = "Подсвечивает союзников, которым нужна помощь (видно сквозь стены). Работает за любой поддерживаемый модом класс (Скитарий, Арбитр) — мастиф Арбитра воскрешать не умеет, но знать, кто упал, всё равно полезно. Союзники, до которых приказу лечения запрещено доходить (боты при исключении ботов или класс с приоритетом 0), НЕ подсвечиваются — подсветка не обещает воскрешения, от которого мод откажется.",
	},
	group_revive_prio = {
		en = "Revive priorities (0 = never revive)",
		ru = "Приоритеты воскрешения (0 = не воскрешать)",
	},
	group_revive_prio_desc = {
		en = "Who the Medicae skull's heal order picks when more than one ally is down. Highest class priority wins, distance only breaks ties — so it also lets you fine-tune inside a full player team, not just player-versus-bot. All sliders start at 50, which reproduces the old behaviour exactly (nearest valid ally). Skitarii only; the Arbites mastiff cannot revive.",
		ru = "Кого выбирает приказ лечения Медикэ-черепа, когда упало больше одного союзника. Побеждает наибольший приоритет класса, дистанция решает только при равенстве — так что настройка работает и внутри полностью живой команды, а не только «игрок против бота». Все ползунки стартуют с 50, что в точности воспроизводит прежнее поведение (ближайший валидный союзник). Только для Скитария; мастиф Арбитра воскрешать не умеет.",
	},
	heal_ignore_bots = {
		en = "Never revive bots",
		ru = "Никогда не воскрешать ботов",
	},
	heal_ignore_bots_desc = {
		en = "Bots are excluded from heal-order targeting completely, so a real player always wins the skull. Independent of the priority sliders below — this switch wins even if the bot's class has a higher priority. Your own manual heal aim is unaffected: nothing stops you from aiming at a bot yourself.",
		ru = "Боты полностью исключаются из наведения приказа лечения, поэтому череп всегда достаётся живому игроку. Не зависит от ползунков ниже — этот выключатель сильнее, даже если у класса бота приоритет выше. На ваше собственное ручное наведение не влияет: навести прицел на бота вручную вам никто не мешает.",
	},
	heal_bots_last = {
		en = "Revive bots only when no player is down",
		ru = "Воскрешать ботов только если нет упавших игроков",
	},
	heal_bots_last_desc = {
		en = "On by default. A bot is only picked when no living human ally in range needs help — the classic case of a player and a bot going down side by side, or both propped against the same pillar, where auto-targeting used to grab the bot. A bot can still be picked ahead of a player if that player cannot be locked on at all (behind a wall, out of reticle reach): after about 1.5 s the unreachable candidate is parked and the next one gets its turn, so the order never stalls.",
		ru = "По умолчанию вкл. Бот берётся только если ни одному живому союзнику-человеку в радиусе не нужна помощь — классический случай, когда игрок и бот падают рядом или оба сидят у одной колонны, и авто-наведение раньше цеплялось за бота. Бот всё же может быть выбран раньше игрока, если этого игрока вообще нельзя захватить прицелом (за стеной, вне досягаемости): примерно через 1.5 с недостижимый кандидат откладывается, и очередь переходит к следующему — приказ не залипает.",
	},
	heal_prio_ogryn = {
		en = "Ogryn",
		ru = "Огрин",
	},
	heal_prio_ogryn_desc = {
		en = "Revive priority for a downed Ogryn. Higher wins; equal priorities are decided by distance (nearest first). 0 = never revive this class with the skull. Leave every slider at 50 to keep the old behaviour — always the nearest valid ally.",
		ru = "Приоритет воскрешения павшего огрина. Больше — важнее; при равных приоритетах решает дистанция (ближайший). 0 = не воскрешать этот класс черепом. Оставьте все ползунки на 50, чтобы сохранить прежнее поведение — всегда ближайший валидный союзник.",
	},
	heal_prio_zealot = {
		en = "Zealot",
		ru = "Фанатик (Zealot)",
	},
	heal_prio_zealot_desc = {
		en = "Revive priority for a downed Zealot. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения павшего фанатика. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	heal_prio_veteran = {
		en = "Veteran",
		ru = "Ветеран",
	},
	heal_prio_veteran_desc = {
		en = "Revive priority for a downed Veteran. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения павшего ветерана. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	heal_prio_psyker = {
		en = "Psyker",
		ru = "Псайкер",
	},
	heal_prio_psyker_desc = {
		en = "Revive priority for a downed Psyker. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения павшего псайкера. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	heal_prio_adamant = {
		en = "Arbites (Adamant)",
		ru = "Арбитр (Adamant)",
	},
	heal_prio_adamant_desc = {
		en = "Revive priority for a downed Adeptus Arbites. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения павшего Адептус Арбитрес. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	heal_prio_cryptic = {
		en = "Skitarii (Cryptic)",
		ru = "Скитарий (Cryptic)",
	},
	heal_prio_cryptic_desc = {
		en = "Revive priority for another downed Skitarii. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения другого павшего Скитария. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	heal_prio_broker = {
		en = "Broker",
		ru = "Брокер (Broker)",
	},
	heal_prio_broker_desc = {
		en = "Revive priority for a downed Broker. Higher wins; ties go to the nearest. 0 = never.",
		ru = "Приоритет воскрешения павшего брокера. Больше — важнее; при равенстве — ближайший. 0 = никогда.",
	},
	sskc_auto_on = {
		en = "Servo-skull auto-attack: ON",
		ru = "Авто-атака сервочерепа: ВКЛ",
	},
	sskc_auto_off = {
		en = "Servo-skull auto-attack: OFF",
		ru = "Авто-атака сервочерепа: ВЫКЛ",
	},
	sskc_panic_on_hold = {
		en = "PANIC MODE: ON (until pressed again) — charge gate ignored",
		ru = "ПАНИК-РЕЖИМ: ВКЛ (до повторного нажатия) — гейт зарядов игнорируется",
	},
	sskc_panic_on_timed = {
		en = "PANIC MODE: ON — charge gate ignored",
		ru = "ПАНИК-РЕЖИМ: ВКЛ — гейт зарядов игнорируется",
	},
	sskc_panic_off = {
		en = "PANIC MODE: OFF",
		ru = "ПАНИК-РЕЖИМ: ВЫКЛ",
	},
	sskc_blocked_busy = {
		en = "Order -> ping (skull busy)",
		ru = "Приказ -> метка (череп занят)",
	},
	sskc_blocked_shield = {
		en = "Order -> ping (force field in the way)",
		ru = "Приказ -> метка (на пути силовое поле)",
	},
	sskc_blocked_smoke = {
		en = "Order -> ping (smoke in the way)",
		ru = "Приказ -> метка (на пути дым)",
	},
	sskc_blocked_burster = {
		en = "Order -> ping (Poxburster too close)",
		ru = "Приказ -> метка (взрывун слишком близко)",
	},
	sskc_blocked_daemonhost = {
		en = "Order -> ping (Daemonhost, protected)",
		ru = "Приказ -> метка (демонхост, защита)",
	},
	sskc_dh_on = {
		en = "DAEMONHOST PROTECTION: ON",
		ru = "ЗАЩИТА ОТ ДЕМОНХОСТА: ВКЛ",
	},
	sskc_dh_off = {
		en = "DAEMONHOST PROTECTION: OFF",
		ru = "ЗАЩИТА ОТ ДЕМОНХОСТА: ВЫКЛ",
	},
}
