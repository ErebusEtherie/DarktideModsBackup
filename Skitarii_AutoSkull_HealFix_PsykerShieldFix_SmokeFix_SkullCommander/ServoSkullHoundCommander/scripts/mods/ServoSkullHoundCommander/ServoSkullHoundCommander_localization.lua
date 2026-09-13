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
		en = "Auto-attack — common (both companions)",
		ru = "Авто-атака — общее (оба компаньона)",
	},
	group_auto_desc = {
		en = "Controls that apply to whichever companion you play: the master toggle and its hotkey, the one-press attack order key (its guards live in the Manual orders group), the aim-switch override, the unalerted filter, teammate Poxburster protection, training areas and debug. Each companion's own reach, view cone, timing and full threat priority table live in its tab below — the servo-skull and the mastiff no longer share a single priority table.",
		ru = "Управление, действующее на любого компаньона: общий тумблер и его клавиша, клавиша приказа атаки одним нажатием (её защиты — в группе ручных приказов), оверрайд по прицелу, фильтр непотревоженных, защита союзников от взрывунов, тренировочные зоны и отладка. Дальность, конус, тайминги и полная таблица приоритетов у каждого компаньона теперь свои — в его вкладке ниже; общей таблицы приоритетов больше нет.",
	},
	group_skull = {
		en = "Servo-skull (Skitarii)",
		ru = "Сервочереп (Скитарий)",
	},
	group_skull_desc = {
		en = "Everything specific to the Skitarii servo-skull: its engagement envelope (distance, view cone, timing), the shot-line guards, and its OWN threat priority table — tune it freely, the mastiff tab has its own and they never touch. The charge gate, heal order and revive priorities are servo-skull features too and keep their own groups below.",
		ru = "Всё, что касается только сервочерепа Скитария: его «конверт» вовлечения (дистанция, конус, тайминги), проверки линии выстрела и его СОБСТВЕННАЯ таблица приоритетов — крутите свободно, у мастифа во вкладке ниже своя, и они не пересекаются. Гейт зарядов, приказ лечения и приоритеты воскрешения — тоже фичи черепа, они в своих группах ниже.",
	},
	auto_enabled = {
		en = "Enable auto-attack",
		ru = "Включить авто-атаку",
	},
	auto_enabled_desc = {
		en = "Master toggle: the mod periodically orders your companion — the servo-skull or the cyber-mastiff — onto the highest-priority enemy (same as double-tagging it yourself). Each companion can additionally be switched off individually in its own tab.",
		ru = "Общий тумблер: мод периодически приказывает вашему компаньону — сервочерепу или кибермастифу — атаковать самую приоритетную цель (то же самое, что двойная метка вручную). Каждого компаньона можно дополнительно выключить отдельно в его вкладке.",
	},
	order_key = {
		en = "Attack order key (order at the crosshair)",
		ru = "Клавиша приказа атаки (по цели под прицелом)",
	},
	order_key_desc = {
		en = "One press orders your companion — servo-skull or mastiff — at the enemy under your crosshair. No double-tag needed, works with auto-attack on or off, and pauses auto-attack briefly like any manual order. All manual-order guards apply (Daemonhost, close Poxburster, and the busy/shield/smoke ones if enabled — they live in the Manual orders group). Pressing it TWICE quickly with no enemy under the crosshair releases the mastiff's manual target lock. Built in so this mod does not need Skitarii UI Fix's order key: theirs is Skitarii-only, this one also drives the mastiff. Runs cleanly alongside it too — if Skitarii UI Fix is enabled and its order key is bound to the SAME key, this mod yields the skull order to it (no double press) and keeps handling only the mastiff.",
		ru = "Одно нажатие приказывает вашему компаньону — сервочерепу или мастифу — атаковать врага под прицелом. Двойная метка не нужна, работает при включённой и выключенной авто-атаке и, как любой ручной приказ, ненадолго ставит её на паузу. Действуют все защиты ручного приказа (демонхост, близкий взрывун, а также занят/щит/дым, если включены — они в группе ручных приказов). ДВОЙНОЕ быстрое нажатие без врага под прицелом снимает ручную фиксацию цели мастифа. Встроено, чтобы рядом с этим модом не требовалась кнопка приказа из Skitarii UI Fix: та работает только у Скитария, эта командует и мастифом. С ним она и уживается: если Skitarii UI Fix включён и его кнопка приказа назначена на ТУ ЖЕ клавишу, этот мод уступает ему приказ черепа (никакого двойного прожатия) и продолжает обслуживать только мастифа.",
	},
	skull_auto_enabled = {
		en = "Auto-attack applies to the servo-skull",
		ru = "Авто-атака действует на сервочереп",
	},
	skull_auto_enabled_desc = {
		en = "Per-companion switch under the master toggle: turn this OFF and the mod never auto-orders the servo-skull while everything for the Arbites mastiff keeps working. Manual double-tags are unaffected. Useful when you play both classes and only want one of the companions automated.",
		ru = "Пер-компаньонный выключатель под общим тумблером: ВЫКЛ — мод никогда не отдаёт авто-приказы сервочерепу, при этом всё для мастифа Арбитра продолжает работать. Ручные двойные метки не затрагиваются. Полезно, если играете за оба класса и хотите автоматизировать только одного компаньона.",
	},
	auto_toggle_key = {
		en = "Auto-attack toggle key",
		ru = "Клавиша вкл/выкл авто-атаки",
	},
	auto_toggle_key_desc = {
		en = "Toggle auto-attack mid-mission to take full manual control of the companion.",
		ru = "Переключайте авто-атаку посреди миссии, чтобы полностью управлять компаньоном вручную.",
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
		en = "While auto-attack is on, whatever enemy your crosshair is on (the exact unit the tag key would pick) instantly becomes your companion's target — no double-tag needed, and the mastiff obeys it just like the skull. This is a pure manual-style override: it IGNORES the priority table, the view cone, the max distance limit and the force field / smoke / wall checks AND the Poxburster forbidden radius. Point at it and it gets marked. While you keep aiming at it the companion holds it; look away and normal priority logic (with all its checks) resumes. Skull-only note: with the Improved Tagging talent, the charge gate can still pause this — use panic mode to override that.",
		ru = "При включённой авто-атаке враг под прицелом (ровно та цель, что выбрала бы клавиша метки) мгновенно становится целью вашего компаньона — двойная метка не нужна, и мастиф слушается этого так же, как череп. Это чистый ручной оверрайд: он ИГНОРИРУЕТ таблицу приоритетов, конус обзора, лимит макс. дистанции и проверки поля / дыма / стен, А ТАКЖЕ запретный радиус взрывунов. Навёл — пометилось. Пока держите под прицелом, компаньон держит цель; отвели взгляд — снова обычная логика приоритетов (со всеми проверками). Примечание только для черепа: с талантом улучшенной метки гейт по зарядам всё ещё может ставить это на паузу — используйте паник-режим, чтобы его обойти.",
	},
	ignore_unaggroed = {
		en = "Ignore unalerted enemies",
		ru = "Игнорировать непотревоженных врагов",
	},
	ignore_unaggroed_desc = {
		en = "Don't auto-acquire enemies that haven't noticed anyone yet (they have no combat target) — the companion won't drag sleeping patrols and ambient mobs into a fight early. The current target is never dropped because of this, and aiming at an enemy directly (option above) overrides the filter — deliberate aim counts as intent. Rescue targets ignore this filter too.",
		ru = "Не брать в цели врагов, которые ещё никого не заметили (у них нет боевой цели) — компаньон не будет раньше времени втягивать в бой спящие патрули и фоновых мобов. Текущая цель из-за этого никогда не сбрасывается, а прямое наведение прицела (опция выше) фильтр обходит — осознанный прицел значит намерение. Цели спасения этот фильтр тоже игнорируют.",
	},
	auto_block_shield = {
		en = "Auto: don't order through force fields",
		ru = "Авто: не приказывать сквозь силовые поля",
	},
	auto_block_shield_desc = {
		en = "OFF by default: the game has FIXED the servo-skull refusing to shoot through allied force fields, so this guard is no longer needed (existing profiles are switched off once automatically). Kept available in case a future patch breaks the fix again — when ON, targets are skipped whenever a psyker shield/dome is involved in any way: the line crosses it, the target stands inside one, or the skull is inside one.",
		ru = "По умолчанию ВЫКЛ: игра ПОЧИНИЛА отказ сервочерепа стрелять сквозь союзные силовые поля, так что защита больше не нужна (старые профили один раз переключаются автоматически). Настройка оставлена на случай, если будущий патч снова сломает фикс — при ВКЛ цели пропускаются, если поле псайкера замешано хоть как-то: линия пересекает стенку/купол, цель внутри купола или сам череп внутри.",
	},
	auto_block_smoke = {
		en = "Auto: don't order through smoke",
		ru = "Авто: не приказывать сквозь дым",
	},
	auto_block_smoke_desc = {
		en = "OFF by default: the game has FIXED the servo-skull not shooting through smoke, so this guard is no longer needed (existing profiles are switched off once automatically). Kept available in case a future patch breaks the fix again — when ON, targets are skipped when a veteran smoke cloud sits on the skull-to-target line or the skull stands in one. Pox gas and other clouds never blocked shots and are not affected by this.",
		ru = "По умолчанию ВЫКЛ: игра ПОЧИНИЛА стрельбу сервочерепа сквозь дым, так что защита больше не нужна (старые профили один раз переключаются автоматически). Настройка оставлена на случай, если будущий патч снова сломает фикс — при ВКЛ цели пропускаются, когда дым ветерана на линии череп→цель или череп стоит в дыму. Pox-газ и прочие облака выстрелы и не блокировали, эта настройка их не касается.",
	},
	auto_in_training = {
		en = "Attack in training areas (Psykhanium)",
		ru = "Атака в тренировочных зонах (Псайканум)",
	},
	auto_in_training_desc = {
		en = "Off by default. The Meat Grinder / Psykhanium shooting range (tg_shooting_range) is flagged non-aggressive by the game and keeps companions passive there. When ON, the mod still sends orders — they may work, but the game may ignore them. Real missions are unaffected either way.",
		ru = "По умолчанию выкл. Тир Meat Grinder / Псайканум (tg_shooting_range) помечен игрой как неагрессивный и держит компаньонов пассивными. При ВКЛ мод всё равно шлёт приказы — они могут сработать, но игра может их игнорировать. На реальные миссии не влияет в любом случае.",
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
		en = "Everything specific to the Arbites cyber-mastiff: its engagement envelope, the close-combat mode key, its OWN full threat priority table (completely independent of the servo-skull's tab — no more re-tuning when you switch classes), teammate rescue, the sight/reach gates, the bleed hand-off and auto-Detonation. The dog takes orders through exactly the same double-tag as the skull, but it is a melee pouncer, not a gun: enemies it can PIN to the ground (all human-sized shooters and specials) it shreds, while hounds, mutants and ogryn-sized elites it can only kick once, leap away from and re-approach — which is why those default to 0 here. Force field / smoke checks never apply to it (it runs around walls), it cannot revive anyone, and the charge gate does not apply — Arbites orders are free.",
		ru = "Всё, что касается только кибермастифа Арбитра: его «конверт» вовлечения, клавиша режима ближнего боя, его СОБСТВЕННАЯ полная таблица приоритетов (полностью независимая от вкладки сервочерепа — больше не нужно перекручивать мод при смене класса), спасение союзников, проверки видимости/достижимости, передача кровотечению и авто-подрыв. Приказы пёс получает ровно той же двойной меткой, что и череп, но он — прыжок и клыки, а не ствол: врагов, которых он ПРИЖИМАЕТ к земле (все человекоразмерные стрелки и специалисты), он рвёт на части, а собак, мутантов и элиту огрин-размера может лишь раз пнуть, отпрыгнуть и заходить заново — поэтому они здесь по умолчанию на нуле. Проверки силового поля / дыма к нему не применяются (он оббегает стены), воскрешать он не умеет, а гейт по зарядам не действует — у Арбитра приказы бесплатны.",
	},
	dog_auto_enabled = {
		en = "Auto-attack applies to the mastiff",
		ru = "Авто-атака действует на мастифа",
	},
	dog_auto_enabled_desc = {
		en = "Per-companion switch under the master toggle: turn this OFF and the mod never auto-orders the mastiff — including the teammate-rescue logic — the dog is fully yours and the game's. Manual double-tags are unaffected, and auto-Detonation has its own switch below. Everything for the Skitarii servo-skull keeps working.",
		ru = "Пер-компаньонный выключатель под общим тумблером: ВЫКЛ — мод никогда не отдаёт авто-приказы мастифу, включая логику спасения союзников — пёс полностью ваш и игровой. Ручные двойные метки не затрагиваются, у авто-подрыва свой выключатель ниже. Всё для сервочерепа Скитария продолжает работать.",
	},
	dog_max_distance = {
		en = "Max target distance (m)",
		ru = "Макс. дистанция цели (м)",
	},
	dog_max_distance_desc = {
		en = "The Arbites mastiff runs to whatever it is pointed at, so it needs its own reach setting: a dog sent across the room leaves you alone and arrives late. The game itself puts no distance cap on an ordered target, so the slider goes up to 100 m if you want a hunter rather than a bodyguard — but the default 25 m is what keeps it next to you. Three things may reach beyond this leash, each with its own slider below: snipers, bombers, and rescues of a held teammate.",
		ru = "Мастиф Арбитра бежит к цели ножками, поэтому у него свой параметр радиуса: пёс, отправленный через всю комнату, оставляет вас одного и прибегает поздно. Сама игра дистанцию приказанной цели ничем не ограничивает, поэтому ползунок доходит до 100 м, если нужен охотник, а не телохранитель — но именно дефолтные 25 м держат пса рядом с вами. За пределы этого поводка могут выходить только три вещи, у каждой свой ползунок ниже: снайперы, бомберы и спасение схваченного союзника.",
	},
	dog_cone_angle = {
		en = "View cone for new targets (degrees)",
		ru = "Конус обзора для новых целей (градусы)",
	},
	dog_cone_angle_desc = {
		en = "Same idea as the servo-skull view cone, but wider by default (180) — the dog is a bodyguard and you usually want it to answer threats at your flanks, not only what you are staring at. 360 = look direction ignored. The current target is kept even if it leaves the cone.",
		ru = "То же, что конус обзора сервочерепа, но по умолчанию шире (180) — пёс работает телохранителем, и обычно нужно, чтобы он реагировал на угрозы с флангов, а не только на то, куда вы смотрите. 360 = направление взгляда не учитывается. Текущая цель удерживается, даже если вышла из конуса.",
	},
	dog_interval = {
		en = "Re-order interval (sec)",
		ru = "Интервал приказа по цели (сек)",
	},
	dog_interval_desc = {
		en = "How often the order on the CURRENT target is re-issued. Orders are free for the Arbites (no charge cost), so this is only about keeping the dog pinned on the target. Re-orders can be sparse for the dog: the game's order tag lives 25 s, so even the 15 s maximum refreshes it without a gap, and a NEW target is always ordered instantly regardless of this value. While the dog is already ON the target (pinning it or biting point-blank) re-orders are skipped — no marker/voice-line spam — with one quiet refresh before the 25 s tag would lapse, and they resume by themselves if its attention drifts. Range 4-15 s, default 4.",
		ru = "Как часто переотдаётся приказ по ТЕКУЩЕЙ цели. У Арбитра приказы бесплатны (не тратят заряды), так что это только про удержание пса на цели. Псу редкие переприказы не вредят: тег приказа в игре живёт 25 с, поэтому даже максимум в 15 с обновляет его без разрыва, а НОВАЯ цель приказывается мгновенно независимо от этого значения. Пока пёс уже НА цели (прижимает или грызёт вплотную), переприказы пропускаются — без спама маркером и репликой свистка — с одним тихим обновлением до истечения 25-секундного тега, и возобновляются сами, если его внимание уплыло. Диапазон 4-15 с, дефолт 4.",
	},
	dog_close_key = {
		en = "Close-combat mode key",
		ru = "Клавиша режима ближнего боя",
	},
	dog_close_key_desc = {
		en = "Toggle for tense fights: while active, the mastiff's max target distance AND the sniper/bomber hunt distances are all leashed to the close radius below, and the view cone opens to 360 degrees — the dog brawls around you instead of leaving on hunts. Teammate rescue keeps its full reach even in this mode (a carried ally is exactly the emergency it must not mute). Press again to switch back; the mode always starts OFF at the beginning of each mission.",
		ru = "Тумблер для напряжённого боя: пока активен, макс. дистанция цели И дистанции охоты на снайперов/бомберов зажимаются до ближнего радиуса ниже, а конус обзора раскрывается до 360 градусов — пёс дерётся вокруг вас, а не убегает на охоту. Спасение союзников сохраняет полную дальность даже в этом режиме (утаскиваемый союзник — ровно та тревога, которую глушить нельзя). Повторное нажатие возвращает как было; в начале каждой миссии режим всегда ВЫКЛ.",
	},
	dog_close_distance = {
		en = "— close-combat radius (m)",
		ru = "— радиус ближнего боя (м)",
	},
	dog_close_distance_desc = {
		en = "The leash used while close-combat mode is active. Default 10 m keeps the dog inside the melee around you.",
		ru = "Поводок, действующий при активном режиме ближнего боя. Дефолтные 10 м держат пса внутри свалки вокруг вас.",
	},
	dog_los_current = {
		en = "— drop the current target once unseen ~2.5 s",
		ru = "— бросать текущую цель, невидимую ~2.5 с",
	},
	dog_los_current_desc = {
		en = "The visibility rule above only filters NEW targets; this extends it to the CURRENT one: a target you have not seen for about 2.5 seconds (ran a floor below, two corners deep) is released, and the next order goes to something you can actually see. The grace period keeps ordinary peeking behind cover from flapping the target. Never drops: targets the dog is pinning, rescue targets, and hunt specials while their exemption above is on.",
		ru = "Правило видимости выше фильтрует только НОВЫЕ цели; это распространяет его и на ТЕКУЩУЮ: цель, которую вы не видите около 2.5 секунд (убежала этажом ниже, за два поворота), отпускается, и следующий приказ идёт по тому, кого вы реально видите. Льготный период не даёт цели «мигать» от обычных выглядываний из-за укрытия. Никогда не бросает: цели, которые пёс прижимает, цели спасения и спецов охоты, пока их исключение выше включено.",
	},
	dog_manual_lock = {
		en = "Manual order locks the target until it dies",
		ru = "Ручной приказ фиксирует цель до её смерти",
	},
	dog_manual_lock_desc = {
		en = "On by default. When YOU order the mastiff at an enemy — double-tag or the attack order key — that enemy stays the dog's target until it is dead. The priority table, the aim switch and the bleed hand-off all wait; previously the dog could be switched onto something 'better' while still running to your mark. A new manual order replaces the lock, and pressing the order key at empty space TWICE quickly releases it (a single missed press does nothing — combat presses miss all the time). Three exceptions end or pause it on their own: a teammate rescue borrows the dog (the lock resumes if the enemy is still alive), a target pinned by another player's mastiff is dropped (our orders there are dead on arrival), and the Daemonhost guard still applies. Poxbursters are never locked — their safety logic keeps the last word.",
		ru = "По умолчанию вкл. Когда ВЫ приказываете мастифу атаковать врага — двойной меткой или клавишей приказа — этот враг остаётся целью пса, пока не умрёт. Таблица приоритетов, переключение по прицелу и передача кровотечению ждут; раньше пса могло переключить на цель «получше», пока он ещё бежал к вашей метке. Новый ручной приказ заменяет фиксацию, а ДВОЙНОЕ быстрое нажатие клавиши приказа в пустоту снимает её (одиночный промах не делает ничего — в бою промахи случаются постоянно). Три исключения работают сами: спасение союзника одалживает пса (фиксация возобновится, если враг ещё жив), цель, прижатую чужим мастифом, пёс бросает (наши приказы туда мертворождённые), и защита от демонхостов продолжает действовать. Взрывуны не фиксируются никогда — их логика безопасности главнее.",
	},
	dog_lock_notify = {
		en = "— chat message when the lock is released",
		ru = "— сообщение в чат при снятии фиксации",
	},
	dog_lock_notify_desc = {
		en = "The local 'manual target lock released' line shown after a deliberate double-press at empty space. Turn OFF for a fully silent lock — releasing still works, it just says nothing.",
		ru = "Локальная строка «ручная фиксация цели снята» после осознанного двойного нажатия в пустоту. Выключите для полностью тихой фиксации — снятие продолжит работать, просто молча.",
	},
	dog_bleed_release = {
		en = "Bleed hand-off: leave targets that will bleed out",
		ru = "Передача кровотечению: бросать истекающих кровью",
	},
	dog_bleed_release_desc = {
		en = "With the Arbites dog-bleed talent, the mastiff's kick-off burst and its ogryn pounces stack the bleed DoT — and your own weapon-blessing bleeds stack it too; without any bleed source this option simply never fires. When the dog's current victim is at or below the HP threshold with enough bleed stacks, it will die on its own — the mastiff is released for the next target (never for the same one: the dying victim is excluded from the re-pick) instead of watching it expire. Applies to pins too; bosses and captains are never judged 'doomed'. The two sliders below tune how certain the kill must be; the check is an estimate, not an exact damage prediction.",
		ru = "С талантом Арбитра на кровотечение от пса его отбрасывающий импульс и прыжки по огринам вешают стакающееся кровотечение — и кровотечения ваших благословений оружия тоже стакаются; без источника кровотечения опция просто никогда не сработает. Когда текущая жертва пса на пороге ХП или ниже и с достаточным числом стаков, она умрёт сама — мастиф освобождается под следующую цель (никогда под ту же: умирающая исключается из перевыбора), а не смотрит, как она истекает. Действует и на прижатых; боссы и капитаны «обречёнными» не считаются никогда. Два ползунка ниже задают, насколько верной должна быть смерть; проверка — оценка, а не точный расчёт урона.",
	},
	dog_bleed_hp = {
		en = "— hand-off below HP (%%)",
		ru = "— передавать ниже ХП (%%)",
	},
	dog_bleed_hp_desc = {
		en = "The victim must be at or below this health percentage. Lower = more conservative (the dog leaves later).",
		ru = "Жертва должна быть на этом проценте здоровья или ниже. Меньше = осторожнее (пёс уходит позже).",
	},
	dog_bleed_stacks = {
		en = "— hand-off at bleed stacks",
		ru = "— передавать при стаках кровотечения",
	},
	dog_bleed_stacks_desc = {
		en = "Minimum bleed stacks on the victim. Higher = more conservative.",
		ru = "Минимум стаков кровотечения на жертве. Больше = осторожнее.",
	},
	dog_switch_interval = {
		en = "Target hold time (sec)",
		ru = "Время удержания цели (сек)",
	},
	dog_switch_interval_desc = {
		en = "Minimum seconds before switching to a higher-priority target. Longer than the skull's default on purpose: every switch throws away the distance the dog has already covered, so the dog cannot be set below 2.5 s (the skull can go to zero). It still switches instantly when the target dies or leaves range.",
		ru = "Минимум секунд до переключения на более приоритетную цель. Специально больше, чем у черепа: каждое переключение обнуляет уже пройденный псом путь, поэтому псу нельзя поставить меньше 2.5 с (черепу можно и ноль). На мёртвую/ушедшую цель переключение всё равно мгновенное.",
	},
	dog_skip_game_excluded = {
		en = "Skip targets the game keeps it away from",
		ru = "Пропускать цели, от которых его держит игра",
	},
	dog_skip_game_excluded_desc = {
		en = "The game's own mastiff target selection deliberately ignores a few breeds — Poxbursters, gunships and hazards. A whistle order bypasses that filter, so this option re-applies it. Leave it on unless you specifically want to pounce Poxbursters.",
		ru = "Собственный выбор целей мастифа в игре намеренно игнорирует несколько типов — взрывунов, ганшипы и хазарды. Приказ свистком этот фильтр обходит, и данная опция возвращает его. Оставьте включённым, если специально не хотите прыжков по взрывунам.",
	},
	dog_prio_trapper_close = {
		en = "Trapper in net range",
		ru = "Траппер в радиусе сети",
	},
	dog_prio_trapper_close_desc = {
		en = "The mastiff's signature kill: it pins a trapper, which both silences and shreds it — bite it down before the net flies. Beyond the net distance below, the far slider applies.",
		ru = "Фирменное блюдо мастифа: траппера он прижимает — это и затыкает его, и рвёт на части; загрызть, пока трап не прилетел. Дальше дистанции сети ниже действует «дальний» ползунок.",
	},
	dog_dist_trapper = {
		en = "— trapper net distance (m)",
		ru = "— дистанция сети траппера (м)",
	},
	dog_dist_trapper_desc = {
		en = "A trapper's net reaches ~14 m. Default 15 m keeps a small margin.",
		ru = "Сеть траппера бьёт на ~14 м. Дефолт 15 м оставляет небольшой запас.",
	},
	dog_prio_trapper_far = {
		en = "Trapper beyond net range",
		ru = "Траппер дальше дистанции сети",
	},
	dog_prio_trapper_far_desc = {
		en = "Default 60 — deliberately higher than the skull's: hunting trappers down before they ever get in net range (door camping included) is what the mastiff does best. 0 = never chase far trappers.",
		ru = "Дефолт 60 — сознательно выше, чем у черепа: выцеплять трапперов до того, как они вообще выйдут на дистанцию сети (включая караул у дверей), — то, что мастиф умеет лучше всего. 0 = за дальними трапперами не бегать.",
	},
	dog_prio_sniper = {
		en = "Sniper",
		ru = "Снайпер",
	},
	dog_prio_sniper_desc = {
		en = "The mastiff pins snipers and eats them before they even step out of their doorway. Within the normal leash always; the hunt distance below extends the reach.",
		ru = "Снайперов мастиф прижимает и жрёт ещё до того, как они выйдут из своей двери. В пределах обычного поводка — всегда; дистанция охоты ниже расширяет радиус.",
	},
	dog_prio_bomber = {
		en = "Bombers",
		ru = "Бомберы",
	},
	dog_prio_bomber_desc = {
		en = "Scab Bomber and Dreg Tox Bomber — pinnable, and the one party member who can reach them behind doors and in holes is the dog. The hunt distance below extends the reach and drops the view cone.",
		ru = "Обычный и токсичный бомберы — прижимаемы, и единственный в отряде, кто достанет их за дверьми и в дырках, — это пёс. Дистанция охоты ниже расширяет радиус и снимает конус обзора.",
	},
	dog_prio_flamer_close = {
		en = "Flamer in burn range",
		ru = "Огнемётчик в радиусе поджога",
	},
	dog_prio_flamer_close_desc = {
		en = "First target while it can actually burn you — the pin shuts the flame off instantly. Beyond the burn distance below it counts as an ordinary special.",
		ru = "Первая цель, пока он реально может вас жечь — прижим мгновенно выключает огонь. Дальше дистанции поджога ниже считается обычным специалистом.",
	},
	dog_dist_flamer = {
		en = "— flamer burn distance (m)",
		ru = "— дистанция поджога огнемётчика (м)",
	},
	dog_dist_flamer_desc = {
		en = "A flamer burns up to ~15 m. Default 15 m matches its reach.",
		ru = "Огнемётчик жжёт до ~15 м. Дефолт 15 м совпадает с его дальностью.",
	},
	dog_prio_shotgunner_close = {
		en = "Shotgunner in effective range",
		ru = "Шотганнер на эффективной дистанции",
	},
	dog_prio_shotgunner_close_desc = {
		en = "The mastiff's bread and butter — it pins shotgunners and tears through a whole squad of them one by one. Beyond the range below they use the Gunner priority.",
		ru = "Хлеб мастифа — шотганнеров он прижимает и выносит целыми пачками одного за другим. Дальше дистанции ниже действует приоритет пулемётчиков.",
	},
	dog_dist_shotgunner = {
		en = "— shotgunner range (m)",
		ru = "— дистанция шотганнера (м)",
	},
	dog_dist_shotgunner_desc = {
		en = "Shotgun hurts most within ~8-15 m.",
		ru = "Дробовик больнее всего в пределах ~8-15 м.",
	},
	dog_prio_gunner = {
		en = "Gunners (Scab/Dreg)",
		ru = "Пулемётчики (Scab/Dreg)",
	},
	dog_prio_gunner_desc = {
		en = "Regular human-sized gunners — pinnable, prime dog food. The ogryn Reaper has its own slider below.",
		ru = "Обычные человекоразмерные пулемётчики — прижимаемы, отличный корм для пса. У огрина-Жнеца свой ползунок ниже.",
	},
	dog_prio_plasma = {
		en = "Plasma Gunner",
		ru = "Плазмоган",
	},
	dog_prio_plasma_desc = {
		en = "High burst, pinnable, worth silencing fast. One perched in a spot the dog cannot stand on is skipped by the navmesh check below.",
		ru = "Большой бурст, прижимаем, выгодно затыкать быстро. Засевшего там, куда псу не встать, отсеет проверка навмеша ниже.",
	},
	dog_prio_elite_close = {
		en = "Human-sized elite nearby",
		ru = "Человекоразмерная элита рядом",
	},
	dog_prio_elite_close_desc = {
		en = "Ragers, Maulers and the like within the distance below — the dog pins and shreds these. Ogryn-sized elites never use this slider; they have their own below.",
		ru = "Буйные, маулеры и подобные в пределах дистанции ниже — их пёс прижимает и рвёт. Элита огрин-размера этим ползунком не управляется — у неё свой ниже.",
	},
	dog_dist_elite = {
		en = "— elite distance (m)",
		ru = "— дистанция элиты (м)",
	},
	dog_dist_elite_desc = {
		en = "Human-sized elites are prioritized only within this range.",
		ru = "Человекоразмерная элита приоритетна только в этом радиусе.",
	},
	dog_prio_elite_far = {
		en = "Elite beyond that distance",
		ru = "Элита дальше этой дистанции",
	},
	dog_prio_elite_far_desc = {
		en = "0 = don't send the dog after far elites.",
		ru = "0 = не посылать пса за дальней элитой.",
	},
	dog_prio_hound = {
		en = "Hound (kick-only)",
		ru = "Собака Хаоса (только пинок)",
	},
	dog_prio_hound_desc = {
		en = "Default 0 = never: the mastiff cannot pin a hound — it kicks once, leaps away, waits 1.5 s and starts over, easily 40-60 seconds of theatre per hound while real threats shoot at you (an order at a hound mid-leap even whiffs outright). The exception is built in: a hound actually ON a teammate is a rescue target (below) and gets attacked regardless of this slider.",
		ru = "Дефолт 0 = никогда: мастиф не может прижать собаку — он раз пинает её, отпрыгивает, ждёт 1.5 с и заходит снова; легко 40-60 секунд цирка на одну собаку, пока настоящие угрозы стреляют по вам (а приказ по собаке в прыжке вообще уходит в молоко). Исключение встроено: собака, сидящая НА союзнике, — это цель спасения (ниже) и атакуется независимо от этого ползунка.",
	},
	dog_prio_mutant = {
		en = "Mutant (kick-only)",
		ru = "Мутант (только пинок)",
	},
	dog_prio_mutant_desc = {
		en = "Default 0 = never: a mutant only gets kicked once per re-approach, which wastes the dog's time for scraps of damage. A mutant actually CARRYING a teammate is a rescue target and is attacked regardless of this slider — the kick's heavy stagger knocks the grab loose.",
		ru = "Дефолт 0 = никогда: мутанта пёс лишь пинает раз за заход — трата времени ради крох урона. Мутант, который НЕСЁТ союзника, — цель спасения и атакуется независимо от этого ползунка: тяжёлый стаггер от пинка выбивает захват.",
	},
	dog_prio_reaper = {
		en = "Reaper — Ogryn gunner (kick-only)",
		ru = "Жнец — огрин-пулемётчик (только пинок)",
	},
	dog_prio_reaper_desc = {
		en = "Default 0 = never: the mastiff can only scratch an ogryn with repeated kick-and-re-approach passes — it will 'fight' one Reaper for minutes. If you value the stunlock (the kicks do keep interrupting its shooting), raise this consciously.",
		ru = "Дефолт 0 = никогда: огрина мастиф способен только царапать бесконечными заходами с пинком — одного Жнеца он «грызёт» минутами. Если вам ценен станлок (пинки действительно не дают ему стрелять), поднимайте осознанно.",
	},
	dog_prio_elite_ogryn = {
		en = "Ogryn elites — Crusher / Bulwark (kick-only)",
		ru = "Элита-огрины — Крашер / Булварк (только пинок)",
	},
	dog_prio_elite_ogryn_desc = {
		en = "Ogryn-sized elites only. Default 0 = never: same story as the Reaper — kick, leap away, re-approach, repeat. Human-sized elites use the 'Human-sized elite' sliders above instead — those the dog pins and shreds.",
		ru = "Только элита огрин-размера. Дефолт 0 = никогда: та же история, что со Жнецом — пнул, отпрыгнул, зашёл заново. Человекоразмерная элита управляется ползунками «Человекоразмерная элита» выше — её пёс прижимает и рвёт.",
	},
	dog_prio_houndmaster = {
		en = "Houndmaster (zero damage)",
		ru = "Псарь (нулевой урон)",
	},
	dog_prio_houndmaster_desc = {
		en = "Default 0 = never, and this one you should genuinely leave at 0: against the Houndmaster the pounce deals ZERO damage — the dog is simply shoved off, and the boss even gains 10 seconds of stagger immunity from it. A strictly wasted order.",
		ru = "Дефолт 0 = никогда, и вот его правда стоит оставить на нуле: по Псарю прыжок наносит НОЛЬ урона — пса просто отшвыривает, а босс ещё и получает от этого 10 секунд иммунитета к стаггеру. Приказ, потраченный впустую в чистом виде.",
	},
	dog_prio_monster = {
		en = "Bosses / captains",
		ru = "Боссы / капитаны",
	},
	dog_prio_monster_desc = {
		en = "On a Plague Ogryn, Chaos Spawn or Beast of Nurgle the mastiff latches on for ~1.5 s of monster-grade bites — decent. Captains and the Twins it only kicks once and bounces off. The Houndmaster has its own slider above and never uses this one.",
		ru = "На чумном огрине, порождении Хаоса и звере Нургла мастиф повисает на ~1.5 с монстро-укусов — прилично. Капитанов и близнецов он лишь раз пинает и отлетает. У Псаря свой ползунок выше, этот на него не действует.",
	},
	dog_exec_enabled = {
		en = "Attack Execution Order marks",
		ru = "Атаковать метки Execution Order",
	},
	dog_exec_enabled_desc = {
		en = "For the Arbites keystone Execution Order: enemies carrying its kill mark (the highlighted outline) get the priority below, ahead of the breed tables — including breeds the dog normally ignores. Killing a mark procs the whole keystone package, and the mastiff's pounce on a mark has its own bonus on top, so sending the dog at them is exactly what the keystone wants. Marks are also exempt from the line-of-sight gate (you can see the highlight anyway). Inert without the keystone. Teammate rescue and Daemonhost protection still outrank marks, and a marked Poxburster stays under the burster safety logic.",
		ru = "Для кейстоуна Арбитра Execution Order: враги с его меткой убийства (подсвеченный контур) получают приоритет ниже — поверх таблиц пород, включая тех, кого пёс обычно игнорирует. Убийство метки запускает весь пакет кейстоуна, а прыжок мастифа по метке имеет ещё и собственный бонус, так что посылать пса по ним — ровно то, чего кейстоун хочет. Метки также исключены из проверки прямой видимости (подсветку вы видите и так). Без кейстоуна опция бездействует. Спасение союзников и защита от демонхостов всё равно важнее меток, а помеченный взрывун остаётся под логикой безопасности взрывунов.",
	},
	dog_prio_exec = {
		en = "— Execution Order mark priority",
		ru = "— приоритет метки Execution Order",
	},
	dog_prio_exec_desc = {
		en = "Priority for marked enemies. Default 90 — above gunners/elites, below a rescue (100). 0 = off.",
		ru = "Приоритет помеченных врагов. Дефолт 90 — выше пулемётчиков/элиты, ниже спасения (100). 0 = выкл.",
	},
	dog_burster_never = {
		en = "Never target Poxbursters",
		ru = "Никогда не атаковать взрывунов",
	},
	dog_burster_never_desc = {
		en = "Hard off-switch for the dog's auto orders on Poxbursters. Note this whole row only matters with 'skip targets the game keeps it away from' turned OFF — that filter already excludes bursters. The kick itself deals zero damage (a safe knockback that cannot detonate them).",
		ru = "Жёсткий выключатель авто-приказов пса по взрывунам. Учтите: весь этот блок имеет смысл только при ВЫКЛЮЧЕННОМ «пропускать цели, от которых его держит игра» — тот фильтр и так исключает взрывунов. Сам пинок наносит ноль урона (безопасный отброс, подорвать им взрывуна нельзя).",
	},
	dog_prio_burster_far = {
		en = "Poxburster beyond safe radius",
		ru = "Взрывун дальше безопасного радиуса",
	},
	dog_prio_burster_far_desc = {
		en = "The dog's kick on a Poxburster is a zero-damage knockback — it punts the burster away without detonating it. Never inside the forbidden radius below, and 'Forbidden radius protects teammates too' (common group) applies as well.",
		ru = "Пинок пса по взрывуну — отброс с нулевым уроном: отшвыривает взрывуна, не подрывая его. Внутри запретного радиуса ниже — никогда, и «Запретный радиус защищает и союзников» (общая группа) тоже действует.",
	},
	dog_dist_burster_forbidden = {
		en = "— forbidden radius (m)",
		ru = "— запретный радиус (м)",
	},
	dog_dist_burster_forbidden_desc = {
		en = "The explosion radius is 6 m; default 10 m keeps a margin. Applies to you and (with the common-group option) to teammates.",
		ru = "Радиус взрыва 6 м; дефолт 10 м оставляет запас. Действует для вас и (при включённой опции в общей группе) для союзников.",
	},
	dog_prio_special_other = {
		en = "Other specials",
		ru = "Прочие специалисты",
	},
	dog_prio_special_other_desc = {
		en = "Any special not covered above (e.g. a far flamer).",
		ru = "Специалисты, не попавшие в категории выше (например, дальний огнемётчик).",
	},
	dog_rescue_enabled = {
		en = "Rescue held teammates",
		ru = "Спасать схваченных союзников",
	},
	dog_rescue_enabled_desc = {
		en = "The moment ANY enemy is holding a teammate — a hound on top of them, a mutant carrying them, a trapper whose net landed, a Chaos Spawn or Beast eating them — that exact enemy becomes the dog's top-priority target (slider below), bypassing the view cone, the hold timer and even the pause after your manual order. Knock it off, kill it, back to eating rangers. This is precisely the one moment hounds and mutants ARE worth the mastiff's time, which is why their own sliders can stay at 0. The game only does this for YOU (the dog auto-saves its owner); this extends it to the whole team. Daemonhosts are never a rescue target — Daemonhost protection wins.",
		ru = "Как только ЛЮБОЙ враг держит союзника — собака сидит на нём, мутант его несёт, траппер накинул сеть, порождение или зверь Нургла его жрёт — именно этот враг становится целью пса с высшим приоритетом (ползунок ниже), в обход конуса обзора, таймера удержания цели и даже паузы после вашего ручного приказа. Сбить, загрызть, вернуться жрать стрелков. Это ровно тот единственный момент, когда собаки и мутанты СТОЯТ времени мастифа — потому их собственные ползунки и могут оставаться на нуле. Сама игра делает это только для ВАС (пёс автоматически спасает хозяина); эта опция распространяет это на всю команду. Демонхост целью спасения не бывает никогда — защита от демонхостов сильнее.",
	},
	dog_prio_rescue = {
		en = "— rescue priority",
		ru = "— приоритет спасения",
	},
	dog_prio_rescue_desc = {
		en = "Priority given to an enemy currently holding a teammate. Default 100, and a rescue also wins any tie against equal-priority threats (a trapper at 100 next to the dog does not outrank it). Lower it below a category if you want that category — e.g. flamers in your face — to strictly win.",
		ru = "Приоритет врага, который прямо сейчас держит союзника. Дефолт 100, и при равенстве очков спасение выигрывает ничью (траппер со 100 рядом с псом его не перебьёт). Снизьте ниже нужной категории, если хотите, чтобы она — например, огнемётчик в упор — побеждала строго.",
	},
	dog_rescue_distance = {
		en = "— rescue distance (m)",
		ru = "— дистанция спасения (м)",
	},
	dog_rescue_distance_desc = {
		en = "A held teammate justifies a longer run than the normal leash: rescue targets are allowed up to this distance even beyond 'max target distance'. Mutants carry their victim away fast, so keep this generous.",
		ru = "Схваченный союзник оправдывает пробежку дальше обычного поводка: цели спасения разрешены до этой дистанции даже за пределами «макс. дистанции цели». Мутант утаскивает жертву быстро, так что запас тут не лишний.",
	},
	dog_dist_sniper = {
		en = "— sniper hunt distance (m)",
		ru = "— дистанция охоты на снайперов (м)",
	},
	dog_dist_sniper_desc = {
		en = "Snipers are worth a run: the mastiff shreds them even before they step out of their doorway, and from a good position it can leap absurd distances. Snipers beyond 'max target distance' but within this many meters are still targeted (still inside the view cone). 0 = no extension, the normal leash applies.",
		ru = "Снайперы стоят пробежки: мастиф рвёт их ещё до того, как они выйдут из своей двери, а с удачной позиции прыгает на неприличные дистанции. Снайперы дальше «макс. дистанции цели», но ближе этого значения всё равно берутся в цели (конус обзора действует). 0 = без расширения, работает обычный поводок.",
	},
	dog_dist_bomber = {
		en = "— bomber hunt distance (m)",
		ru = "— дистанция охоты на бомберов (м)",
	},
	dog_dist_bomber_desc = {
		en = "Bombers are a target regardless of where they sit — behind doors, in that hole nobody can jump into — because their grenades arrive anywhere and the mastiff is the one party member who can go eat them. Bombers are targeted up to this distance and ignore the view cone entirely. 0 = no extension.",
		ru = "Бомбер — цель независимо от того, где он засел: за дверьми, вооон в той дырке, куда никому не допрыгнуть — его гранаты прилетают откуда угодно, а мастиф единственный в отряде, кто может сбегать его сожрать. Бомберы берутся в цели до этой дистанции и полностью игнорируют конус обзора. 0 = без расширения.",
	},
	dog_require_los = {
		en = "Only visible targets",
		ru = "Только видимые цели",
	},
	dog_require_los_desc = {
		en = "On by default. Ordinary enemies (gunners, shotgunners, elites...) are only auto-ordered when you can actually see them from your camera — no more sending the dog three corners deep after a shooter you physically cannot see yet. Whether the hunt specials (sniper/trapper/bomber) keep their exemption is the checkbox below; rescue targets are always exempt.",
		ru = "По умолчанию вкл. Обычные враги (пулемётчики, дробовики, элита...) авто-приказываются, только когда вы реально видите их с камеры — больше никаких отправок пса за три поворота по врагу, которого вы физически ещё не видите. Сохраняют ли исключение спецы-цели охоты (снайпер/траппер/бомбер) — чекбокс ниже; цели спасения — исключение всегда.",
	},
	dog_los_hunters = {
		en = "— hunt specials may skip line of sight",
		ru = "— спецы охоты могут без прямой видимости",
	},
	dog_los_hunters_desc = {
		en = "On by default: snipers, trappers and bombers may be ordered without direct sight — behind doors, under/above your floor — and the dog going for a trapper the moment its door cracks open is the best thing it does. Turn OFF if the marks through walls and floors, or the dog camping a spawn door until something walks out, bother you (teammates can read it as suspicious): line of sight is then required for every breed. Teammate rescue stays exempt either way.",
		ru = "По умолчанию вкл.: снайперы, трапперы и бомберы могут получать приказ без прямой видимости — за дверьми, этажом ниже/выше — и пёс, уходящий за траппером при первом приоткрытии дверки, — лучшее, что он умеет. Выключите, если метки сквозь стены и полы или пёс, караулящий у спавн-двери, вас смущают (сокомандники могут счесть это подозрительным): тогда прямая видимость нужна для всех типов врагов. Спасение союзников — исключение в любом случае.",
	},
	dog_check_navmesh = {
		en = "Skip unreachable targets (off navmesh)",
		ru = "Пропускать недостижимые цели (вне навмеша)",
	},
	dog_check_navmesh_desc = {
		en = "On by default. Before ordering, the target's position is checked against the navigation mesh with the exact probe the dog's own movement uses. The server never refuses an order at an unreachable target — the dog just runs to the nearest reachable point and parks there until the order expires (25 s), or even gets teleported back to you by the stuck-watchdog. This skips enemies perched in spots the dog genuinely cannot stand on (plasma gunner in a wall niche and similar).",
		ru = "По умолчанию вкл. Перед приказом позиция цели проверяется по навигационной сетке ровно тем же зондом, каким пользуется движение самого пса. Сервер не отклоняет приказ по недостижимой цели — пёс просто добегает до ближайшей достижимой точки и стоит там, пока приказ не истечёт (25 с), а то и телепортируется к вам сторожем застреваний. Эта проверка пропускает врагов, засевших там, где псу физически не встать (плазма в нише стены и подобные бебеня).",
	},
	dog_hold_pin = {
		en = "Hold the pin, respect other mastiffs' pins",
		ru = "Держать прижим и уважать чужой прижим",
	},
	dog_hold_pin_desc = {
		en = "On by default, two effects. First: while YOUR mastiff has an enemy pinned to the ground, the mod will not re-order it onto a merely higher-priority target (a pin holds until the victim dies — re-ordering releases it); only a teammate rescue — or the bleed hand-off below — may pull it off the pin. Second: enemies already pinned by ANOTHER player's mastiff are skipped — only one dog can pin a given enemy, so such an order would be wasted.",
		ru = "По умолчанию вкл., два эффекта. Первый: пока ВАШ мастиф прижимает врага к земле, мод не переприкажет его на просто более приоритетную цель (прижим держится до смерти жертвы — переприказ его снимает); сорвать пса с прижима может только спасение союзника или передача кровотечению ниже. Второй: враги, уже прижатые ЧУЖИМ мастифом, пропускаются — прижать врага может только один пёс, такой приказ ушёл бы впустую.",
	},
	dog_det_enabled = {
		en = "Auto-Detonation on bosses (needs the Detonation blitz)",
		ru = "Авто-подрыв на боссах (нужен блиц «Подрыв»)",
	},
	dog_det_enabled_desc = {
		en = "Off by default — detonation charges are precious (2 charges, 50 s each). When ON, and you run the Detonation blitz, the mod presses it automatically at the exact moment the mastiff is physically ON a boss (latched onto a Plague Ogryn / Chaos Spawn / Beast of Nurgle, or biting point-blank): the blast is centred on the dog, so that window is where it hurts most. It works whether the dog got there by auto-attack or by your manual order. Not blind: never on Daemonhosts, respects the charge reserve below, never fires while you are holding the blitz key yourself, and 3 s internal cooldown.",
		ru = "По умолчанию выкл. — заряды подрыва дороги (2 заряда по 50 с). Когда ВКЛ и у вас блиц «Подрыв», мод нажимает его автоматически ровно в тот момент, когда мастиф физически НА боссе (повис на чумном огрине / порождении / звере Нургла или грызёт вплотную): взрыв центрируется на псе, и это окно — где он больнее всего. Работает независимо от того, привела пса туда авто-атака или ваш ручной приказ. Не бездумно: никогда по демонхостам, уважает резерв зарядов ниже, не срабатывает, пока вы сами держите клавишу блица, и имеет внутренний кулдаун 3 с.",
	},
	dog_det_captains = {
		en = "— also detonate on captains / Twins",
		ru = "— подрывать и на капитанах / близнецах",
	},
	dog_det_captains_desc = {
		en = "Off by default: the dog cannot latch onto captains — it only kicks and bounces off, so the on-target window is a fraction of a second and the charge often detonates beside the boss rather than on it. Against a shielded captain the blast is reduced by the void shield as well. Turn on if you want it to try anyway.",
		ru = "По умолчанию выкл.: на капитанах пёс не повисает — только пинает и отлетает, окно «на цели» длится доли секунды, и заряд часто рвётся рядом с боссом, а не на нём. По капитану под щитом взрыв к тому же порезан войд-щитом. Включайте, если хотите, чтобы он всё равно пытался.",
	},
	dog_det_keep_charges = {
		en = "— keep blitz charges in reserve",
		ru = "— держать зарядов блица в резерве",
	},
	dog_det_keep_charges_desc = {
		en = "Auto-detonation only fires while MORE than this many charges remain. Default 1: one charge always stays yours for a manual moment. 0 = the mod may spend everything.",
		ru = "Авто-подрыв срабатывает, только пока зарядов осталось БОЛЬШЕ этого числа. Дефолт 1: один заряд всегда остаётся вам на ручной момент. 0 = мод может потратить всё.",
	},
	dog_det_notify = {
		en = "— chat message on auto-detonation",
		ru = "— сообщение в чат при авто-подрыве",
	},
	dog_det_notify_desc = {
		en = "Locally announces when the mod fires the Detonation, so a sudden bang is never a mystery.",
		ru = "Локально сообщает, когда мод нажал «Подрыв», — внезапный взрыв не останется загадкой.",
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
		en = "On by default. Daemonhosts are excluded from every automatic order path, including the 'Switch to the enemy you aim at' override which otherwise ignores the whole priority table. The 'Attack an AWAKENED Daemonhost' slider below is the one exception: above 0 it overrides this guard for Daemonhosts that are already awake. Turning this checkbox OFF entirely routes an awakened Daemonhost to the 'Bosses / captains' slider instead (only while the slider below is 0 — otherwise that slider wins) — a sleeping one is still never ordered on (the game refuses such orders anyway).",
		ru = "По умолчанию вкл. Демонхосты исключены из всех путей автоматического приказа, включая оверрайд «Переключаться на цель под прицелом», который иначе игнорирует всю таблицу приоритетов. Единственное исключение — ползунок «Атаковать РАЗБУЖЕННОГО демонхоста» ниже: больше 0 — он перекрывает эту защиту для уже разбуженных. Полное выключение этого чекбокса отдаёт разбуженного демонхоста ползунку «Боссы / капитаны» (только пока ползунок ниже на 0 — иначе побеждает он) — по спящему приказ не пойдёт всё равно (игра такие приказы отклоняет).",
	},
	dh_awake_prio = {
		en = "Attack an AWAKENED Daemonhost (priority, 0 = never)",
		ru = "Атаковать РАЗБУЖЕННОГО демонхоста (приоритет, 0 = никогда)",
	},
	dh_awake_prio_desc = {
		en = "Default 0 = classic protection, the companion never auto-attacks a Daemonhost. Set above 0 and a Daemonhost that is already awake (it has a combat target — somebody triggered it anyway) becomes a regular target with this priority, for BOTH companions, and the aim-switch override works on it too. A Daemonhost holding a teammate then also counts as a rescue target for the mastiff. A sleeping Daemonhost is still never targeted (any unreadable state counts as sleeping — the check fails safe), your own double-tap is still guarded by 'Block manual order', the keep-busy diversion simply stops mattering, and 'Stop auto-attack entirely' still wins while the Daemonhost is inside its watch radius (this slider can reach further — mind the gap). Note: the mastiff cannot pin a Daemonhost — one bite and it bounces off, so this slider mostly matters for the skull.",
		ru = "Дефолт 0 = классическая защита, компаньон никогда не атакует демонхоста сам. Больше 0 — уже разбуженный демонхост (у него есть боевая цель — его всё равно кто-то потревожил) становится обычной целью с этим приоритетом для ОБОИХ компаньонов, и оверрайд по прицелу на нём тоже работает. Демонхост, схвативший союзника, тогда считается и целью спасения для мастифа. Спящий по-прежнему не атакуется никогда (любое нечитаемое состояние считается сном — проверка ошибается в безопасную сторону), ваша двойная метка по-прежнему под защитой «Блокировать ручной приказ», отвлечение «занять компаньона» просто теряет смысл, а «Полностью останавливать авто-атаку» всё ещё сильнее — пока демонхост внутри своего радиуса наблюдения (этот ползунок может доставать дальше — учитывайте зазор). Учтите: мастиф демонхоста не прижимает — один укус и отлетает, так что ползунок в основном для черепа.",
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
		en = "Automatic panic for disablers: while a Trapper is within its net distance or a Hound within its leap distance (the distance sliders in the Servo-skull tab), the charge gate is bypassed and the skull keeps ordering even at 0 charges. Only the gate is bypassed — priorities and force field / smoke / wall checks still apply.",
		ru = "Автоматическая паника при дизейблерах: пока траппер в пределах дистанции сети или собака в пределах дистанции прыжка (ползунки дистанций во вкладке сервочерепа), гейт по зарядам обходится, и череп приказывает даже при 0 зарядов. Обходится только гейт — приоритеты и проверки поля / дыма / стен действуют по-прежнему.",
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
		en = "OFF by default since the game fixed the skull shooting through allied force fields (existing profiles are switched off once automatically). When ON, your double-tag becomes a regular ping if a psyker shield/dome is involved in any way (the line crosses it, the target is inside one, or the skull is inside one).",
		ru = "По умолчанию ВЫКЛ — игра починила стрельбу черепа сквозь союзные поля (старые профили один раз переключаются автоматически). При ВКЛ двойная метка становится обычной меткой, если поле псайкера замешано хоть как-то (линия пересекает его, цель внутри купола или череп внутри).",
	},
	manual_block_smoke = {
		en = "Block manual order through smoke",
		ru = "Блокировать ручной приказ сквозь дым",
	},
	manual_block_smoke_desc = {
		en = "OFF by default since the game fixed the skull shooting through smoke (existing profiles are switched off once automatically). When ON, your double-tag becomes a regular ping if a veteran smoke cloud is on the skull-to-target line or the skull is inside one.",
		ru = "По умолчанию ВЫКЛ — игра починила стрельбу черепа сквозь дым (старые профили один раз переключаются автоматически). При ВКЛ двойная метка становится обычной меткой, если дым ветерана на линии череп→цель или череп внутри дыма.",
	},
	manual_block_burster = {
		en = "Block manual order on close Poxbursters",
		ru = "Блокировать ручной приказ по близким взрывунам",
	},
	manual_block_burster_desc = {
		en = "Off by default. When ON, double-tagging a Poxburster that is inside the manual radius below becomes a regular ping instead of an attack order, so you cannot pop one in your own face by mistake. If 'Forbidden radius protects teammates too' (in the common Auto-attack group) is on, the guard also fires when any living ally — bots included — is inside that radius. Poxbursters outside the radius can be ordered normally. This is separate from the auto-attack forbidden radius: manual gets its own, wider setting because you often want to tag a burster far down the corridor while still being protected up close.",
		ru = "По умолчанию выкл. Когда ВКЛ, двойная метка по взрывуну внутри ручного радиуса ниже становится обычной меткой, а не приказом атаки — так вы не подорвёте его себе в лицо по ошибке. Если включено «Запретный радиус защищает и союзников» (в общей группе авто-атаки), защита срабатывает и когда внутри радиуса любой живой союзник, включая ботов. По взрывунам за пределами радиуса приказ проходит как обычно. Это отдельная настройка от запретного радиуса авто-атаки: у ручного приказа свой, более широкий радиус, потому что часто нужно пометить взрывуна далеко в конце коридора, оставаясь защищённым вблизи.",
	},
	dist_burster_manual = {
		en = "— manual Poxburster radius (m)",
		ru = "— ручной радиус взрывуна (м)",
	},
	dist_burster_manual_desc = {
		en = "Manual orders on Poxbursters closer than this (to you, or to any teammate when teammate protection is on) are downgraded to a ping. The explosion radius is 6 m; default 10 m keeps a margin. Range goes up to 50 m so you can forbid manual burster orders across most of the room. NOTE: this radius only governs your own double-tags. If you set it wider than the auto-attack forbidden radius, auto-attack can still pick up a burster in the gap between the two — raise the forbidden radius in your companion's own tab (Servo-skull or Cyber-Mastiff) to match, or use 'Never target Poxbursters' there.",
		ru = "Ручные приказы по взрывунам ближе этой дистанции (к вам или к любому союзнику при включённой защите союзников) понижаются до метки. Радиус взрыва 6 м; дефолт 10 м оставляет запас. Диапазон до 50 м — можно запретить ручные приказы по взрывунам почти по всей комнате. ВАЖНО: этот радиус управляет только вашими двойными метками. Если сделать его шире запретного радиуса авто-атаки, авто-атака всё ещё сможет взять взрывуна в промежутке между ними — поднимите запретный радиус во вкладке своего компаньона (Сервочереп или Кибермастиф) до того же значения или включите там «Никогда не атаковать взрывунов».",
	},
	block_notify = {
		en = "Chat message on blocked order",
		ru = "Сообщение в чат при блокировке приказа",
	},
	block_notify_desc = {
		en = "Locally shows why a manual order was downgraded (busy / shield / smoke / Poxburster).",
		ru = "Локально показывает, почему ручной приказ был понижен до метки (занят / щит / дым / взрывун).",
	},
	prio_hound_close = {
		en = "Hound in leap range",
		ru = "Собака в радиусе прыжка",
	},
	prio_hound_close_desc = {
		en = "Priority for Chaos Hounds within their leap distance below. Beyond it the 'Hound beyond leap range' slider below applies.",
		ru = "Приоритет для собак Хаоса в пределах их дистанции прыжка (ниже). Дальше действует ползунок «Собака дальше дистанции прыжка» ниже.",
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
		en = "Priority for Scab Trappers (Netgunners) within their net distance below. Beyond it the 'Trapper beyond net range' slider below applies.",
		ru = "Приоритет для трапперов (сетемётчиков) в пределах их дистанции сети (ниже). Дальше действует ползунок «Траппер дальше дистанции сети» ниже.",
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
		en = "A Poxburster is never targeted while ANY living teammate — not just you, bots included — is inside the forbidden radius (each companion has its own radius slider in its tab). If your companion is already attacking a Poxburster and someone steps into the radius, the mod immediately switches it to the best other elite/special, skipping the force-field and smoke checks for that emergency switch so it happens as fast as possible. This also extends the manual Poxburster guard (Manual orders group) to your teammates.",
		ru = "Взрывун не атакуется, пока ЛЮБОЙ живой союзник — не только вы, боты тоже — внутри запретного радиуса (у каждого компаньона свой ползунок радиуса в его вкладке). Если ваш компаньон уже атакует взрывуна и кто-то вошёл в радиус, мод немедленно переключает его на лучшую другую элиту/специалиста, пропуская проверки силового поля и дыма для этого аварийного переключения — чтобы оно случилось как можно быстрее. Это же распространяет защиту от взрывунов при ручном приказе (группа ручных приказов) на союзников.",
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
		en = "Companion auto-attack: ON",
		ru = "Авто-атака компаньона: ВКЛ",
	},
	sskc_auto_off = {
		en = "Companion auto-attack: OFF",
		ru = "Авто-атака компаньона: ВЫКЛ",
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
	sskc_det_fired = {
		en = "MASTIFF: auto-Detonation!",
		ru = "МАСТИФ: авто-подрыв!",
	},
	sskc_rename_migrated = {
		en = "[Servo-Skull & Hound Commander] Settings migrated from the old Servo-Skull Commander profile.",
		ru = "[Servo-Skull & Hound Commander] Настройки перенесены из старого профиля Servo-Skull Commander.",
	},
	sskc_lock_cleared = {
		en = "MASTIFF: manual target lock released",
		ru = "МАСТИФ: ручная фиксация цели снята",
	},
	sskc_close_na = {
		en = "Close-combat mode only applies to the Arbites cyber-mastiff",
		ru = "Режим ближнего боя действует только на кибермастифа Арбитра",
	},
	sskc_close_on = {
		en = "MASTIFF: close-combat mode ON (leashed to the close radius)",
		ru = "МАСТИФ: режим ближнего боя ВКЛ (поводок до ближнего радиуса)",
	},
	sskc_close_off = {
		en = "MASTIFF: close-combat mode OFF",
		ru = "МАСТИФ: режим ближнего боя ВЫКЛ",
	},
	sskc_tabs_notice = {
		en = "[Servo-Skull & Hound Commander] The mastiff now has its OWN priority table in the Cyber-Mastiff settings tab (new defaults: hounds/mutants/ogryns ignored, trappers hunted). If you had tuned the old shared sliders for your dog, re-check that tab once.",
		ru = "[Servo-Skull & Hound Commander] У мастифа теперь СВОЯ таблица приоритетов во вкладке «Кибермастиф» (новые дефолты: собаки/мутанты/огрины игнорируются, трапперы — в приоритете охоты). Если вы настраивали старые общие ползунки под пса — загляните в ту вкладку один раз.",
	},
}
