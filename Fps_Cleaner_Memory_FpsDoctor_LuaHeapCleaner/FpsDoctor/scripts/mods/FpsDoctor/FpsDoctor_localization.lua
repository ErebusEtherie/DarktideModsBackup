local mod = get_mod("FpsDoctor")

return {
	mod_name = {
		en = "FPS Doctor",
		ru = "FPS Doctor",
	},
	mod_description = {
		en = "On-screen performance panel (FPS, 1%% low, frame time, memory use and its growth) plus optional automatic memory cleanup. Helps you tell apart a script-memory problem (memory climbs over time, FPS recovers after a cleanup or a new mission) from a graphics-card limit on heavy maps (memory steady, FPS just low). The memory shown is the game's script memory — only one part of the game's total memory use, and not your video memory. FpsDoctor does not show video memory (VRAM); watch that with an external overlay such as MSI Afterburner / RTSS.",
		ru = "Экранная панель производительности (FPS, 1%% low, время кадра, расход памяти и его рост) плюс опциональная авто-очистка памяти. Помогает отличить проблему со скриптовой памятью (память растёт со временем, FPS восстанавливается после очистки или новой миссии) от упора в видеокарту на тяжёлых картах (память ровная, FPS просто низкий). Показываемая память — это скриптовая память игры, лишь одна часть общего расхода памяти, и не видеопамять. FpsDoctor не показывает видеопамять (VRAM); смотрите её внешним оверлеем (MSI Afterburner / RTSS).",
	},

	show_overlay = {
		en = "Show overlay",
		ru = "Показывать оверлей",
	},
	show_overlay_desc = {
		en = "Master switch for the on-screen panel. Turning it off hides the whole panel at once. You can also bind a key below to toggle it quickly while playing.",
		ru = "Главный переключатель экранной панели. Выключение прячет всю панель сразу. Ниже можно назначить клавишу, чтобы быстро скрывать/показывать её прямо в игре.",
	},
	toggle_overlay_key = {
		en = "Show / hide overlay key",
		ru = "Клавиша показа/скрытия оверлея",
	},
	toggle_overlay_key_desc = {
		en = "Key to quickly show or hide the whole overlay while you play.",
		ru = "Клавиша, чтобы быстро показать или скрыть весь оверлей прямо в игре.",
	},
	anchor = {
		en = "Overlay corner",
		ru = "Угол оверлея",
	},
	anchor_desc = {
		en = "Which screen corner the panel sticks to. Works on any resolution and aspect ratio (1080p, 1440p, 4K, 16:10, ultrawide).",
		ru = "К какому углу экрана прижата панель. Работает на любом разрешении и соотношении (1080p, 1440p, 4K, 16:10, ultrawide).",
	},
	anchor_top_left = {
		en = "Top-left",
		ru = "Сверху слева",
	},
	anchor_top_right = {
		en = "Top-right",
		ru = "Сверху справа",
	},
	anchor_bottom_left = {
		en = "Bottom-left",
		ru = "Снизу слева",
	},
	anchor_bottom_right = {
		en = "Bottom-right",
		ru = "Снизу справа",
	},
	pos_x = {
		en = "Horizontal margin",
		ru = "Отступ по горизонтали",
	},
	pos_x_desc = {
		en = "Gap in pixels from the left/right screen edge of the chosen corner. Scales automatically with resolution.",
		ru = "Зазор в пикселях от левого/правого края выбранного угла. Масштабируется под разрешение автоматически.",
	},
	pos_y = {
		en = "Vertical margin",
		ru = "Отступ по вертикали",
	},
	pos_y_desc = {
		en = "Gap in pixels from the top/bottom screen edge of the chosen corner. Scales automatically with resolution.",
		ru = "Зазор в пикселях от верхнего/нижнего края выбранного угла. Масштабируется под разрешение автоматически.",
	},
	overlay_scale = {
		en = "Overlay scale (%%)",
		ru = "Масштаб оверлея (%%)",
	},
	overlay_scale_desc = {
		en = "Size of the whole panel as a percentage. 100 is the default. This is on top of the automatic per-resolution sizing, so you can make the panel bigger on 4K or smaller on 1080p to taste. It grows or shrinks from its corner and does not move.",
		ru = "Размер всей панели в процентах. 100 — по умолчанию. Накладывается поверх авто-размера под разрешение, так что панель можно сделать крупнее на 4K или мельче на 1080p по вкусу. Растёт/уменьшается от своего угла, положение не меняет.",
	},
	opacity_text = {
		en = "Text opacity (%%)",
		ru = "Непрозрачность текста (%%)",
	},
	opacity_text_desc = {
		en = "How solid the text is. 100 = fully solid; lower makes the numbers more see-through. Keep it high for readability.",
		ru = "Насколько плотный текст. 100 = полностью непрозрачный; меньше делает цифры более прозрачными. Для читаемости держи повыше.",
	},
	opacity_bg = {
		en = "Background opacity (%%)",
		ru = "Непрозрачность фона (%%)",
	},
	opacity_bg_desc = {
		en = "How solid the dark background box is. 100 = solid black box; 0 = no box at all (text floats directly on the game). Lower it if the box covers too much, raise it if the text is hard to read against a bright scene.",
		ru = "Насколько плотный тёмный фон-подложка. 100 = плотная чёрная подложка; 0 = подложки нет совсем (текст прямо поверх игры). Уменьшай, если подложка перекрывает много, увеличивай, если текст плохо читается на светлой сцене.",
	},

	show_fps = {
		en = "Show: FPS",
		ru = "Показывать: FPS",
	},
	show_fps_desc = {
		en = "Show the framerate line — your current and average FPS. The basic 'how smooth is it right now' number.",
		ru = "Строка частоты кадров — текущий и средний FPS. Базовое число «насколько плавно прямо сейчас».",
	},
	show_low = {
		en = "Show: 1%% low",
		ru = "Показывать: 1%% low",
	},
	show_low_desc = {
		en = "Show the 1%% low line — your FPS during the worst moments. If it sits far below your average, the game feels choppy even when the average looks fine. This is the real 'stutter' number.",
		ru = "Строка 1%% low — FPS в худшие моменты. Если она сильно ниже среднего, игра ощущается дёргано, даже когда средний FPS выглядит хорошо. Это и есть настоящее число «дёрганости».",
	},
	show_frame_ms = {
		en = "Show: frame time",
		ru = "Показывать: время кадра",
	},
	show_frame_ms_desc = {
		en = "Show how long each frame takes to draw. Another way to read smoothness, mainly for a closer look.",
		ru = "Сколько времени отрисовывается каждый кадр. Ещё один способ оценить плавность, в основном для детального взгляда.",
	},
	show_heap = {
		en = "Show: memory use",
		ru = "Показывать: расход памяти",
	},
	show_heap_desc = {
		en = "Show how much script memory the game is using and whether it's climbing. Memory that keeps climbing is the usual reason FPS gets worse the longer you play. This is the game's script (Lua) memory, not your video memory. FpsDoctor cannot read a maximum for it, so the panel never shows a percentage or a remaining figure — only the real size and how fast it is changing.",
		ru = "Сколько скриптовой памяти занимает игра и растёт ли она. Постоянно растущая память — обычная причина того, что FPS падает со временем игры. Это скриптовая (Lua) память игры, не видеопамять. FpsDoctor не может прочитать её максимум, поэтому панель никогда не показывает проценты или остаток — только реальный размер и скорость изменения.",
	},
	show_mission = {
		en = "Show: peak & per-mission growth",
		ru = "Показывать: пик и рост за миссию",
	},
	show_mission_desc = {
		en = "Show the highest memory reached this session, the floor (what remains right after a full cleanup) and how much memory grew during the current mission. The floor is the true leak indicator: if it climbs mission after mission, something is really leaking; a high peak that drops back to the same floor after cleanup is normal. Opening any full-screen menu (inventory, shop, mission board, Mod Options) allocates a lot of script memory. In Continuous and Aggressive modes menu growth is left out of the per-mission number automatically; in the other modes, press the Reset diagnostics key after closing the menu.",
		ru = "Наибольший достигнутый расход памяти за сессию, «пол» (сколько остаётся сразу после полной очистки) и рост за текущую миссию. Пол — главный индикатор утечки: если он растёт от миссии к миссии, что-то действительно течёт; высокий пик, который после очистки возвращается к тому же полу, — это норма. Открытие любого полноэкранного меню (инвентарь, магазин, доска миссий, Настройки модов) выделяет много скриптовой памяти. В Непрерывном и Агрессивном режимах рост в меню автоматически исключается из числа за миссию; в остальных режимах нажмите клавишу сброса показателей после закрытия меню.",
	},
	show_session = {
		en = "Show: floor drift (session)",
		ru = "Показывать: дрейф пола (за сессию)",
	},
	show_session_desc = {
		en = "Show how much the floor — what remains right after a cleanup — has risen since this session started, and over how many level loads. This is the memory a cleanup does not bring back down, so a floor that keeps climbing is the sign that only restarting the game will reset it. Off by default. Needs a cleanup mode: with cleanup Off the floor cannot be measured at all. The Reset diagnostics key does not affect this line, because it measures the whole session.",
		ru = "Показывать, насколько вырос «пол» — то, что остаётся сразу после очистки — с начала этой сессии, и за сколько загрузок уровня. Это память, которую очистка не возвращает обратно, поэтому постоянно растущий пол — признак того, что сбросить его может только перезапуск игры. По умолчанию выключено. Нужен режим очистки: при выключенной очистке пол измерить нельзя. Клавиша сброса показателей на эту строку не влияет, потому что измеряется вся сессия.",
	},
	restart_advice_mb = {
		en = "Restart advice threshold (MB)",
		ru = "Порог совета о перезапуске (МБ)",
	},
	restart_advice_mb_desc = {
		en = "Once the floor has risen this much since the session started, the mod says so in chat once, and again on each further step of the same size. It only speaks up when memory is also genuinely high, so a session that is merely finishing loading itself does not trigger it. Set to 0 to never advise.",
		ru = "Когда пол вырастет на столько с начала сессии, мод один раз скажет об этом в чате, и затем на каждом следующем шаге такого же размера. Он подаёт голос только когда память при этом действительно велика, поэтому сессия, которая просто досоздаёт себя при загрузке, его не вызывает. 0 — никогда не советовать.",
	},
	show_hitch = {
		en = "Show: stutter count",
		ru = "Показывать: счётчик рывков",
	},
	show_hitch_desc = {
		en = "Show how many noticeable stutters happened this mission. Good for spotting hitching that the average FPS hides. If the mod's own memory cleanup was busy on a stutter frame, the line shows it as '(N gc)' — so you can tell cleanup spikes apart from heavy scenes. Full-screen menus (inventory, shop, Mod Options) cause stutters too; in Continuous and Aggressive modes those are counted separately as '(N menu)' rather than blamed on the mission, and menu frames are also kept out of the 1%% low. Note that any frame slower than half a second is ignored on purpose, so a very heavy menu build may not show up at all.",
		ru = "Сколько заметных рывков случилось за миссию. Помогает заметить подёргивания, которые средний FPS скрывает. Если в кадре рывка была занята собственная очистка памяти мода, строка покажет это как «(N gc)» — так можно отличить всплески очистки от тяжёлых сцен. Полноэкранные меню (инвентарь, магазин, Настройки модов) тоже вызывают рывки; в Непрерывном и Агрессивном режимах они считаются отдельно как «(N menu)», а не записываются на миссию, и кадры меню не попадают в 1%% low. Учтите: кадры медленнее половины секунды намеренно игнорируются, поэтому очень тяжёлое меню может не попасть в счётчик вовсе.",
	},
	hitch_ms = {
		en = "Stutter threshold (ms)",
		ru = "Порог рывка (мс)",
	},
	hitch_ms_desc = {
		en = "A frame slower than this counts as a stutter in the stutter counter. 50 is roughly a stutter you'd actually notice; lower it to also catch smaller spikes.",
		ru = "Кадр медленнее этого значения считается рывком в счётчике рывков. 50 — это уже заметный рывок; снизь, чтобы ловить и более мелкие всплески.",
	},
	show_gc_mode = {
		en = "Show: cleanup mode",
		ru = "Показывать: режим очистки",
	},
	show_gc_mode_desc = {
		en = "Show which memory-cleanup mode is currently active, as a reminder of your setting.",
		ru = "Показывать, какой режим очистки памяти сейчас активен — как напоминание о настройке.",
	},
	reset_stats_key = {
		en = "Reset diagnostics key",
		ru = "Клавиша сброса показателей",
	},
	reset_stats_key_desc = {
		en = "Key to clear the tracked numbers right now: peak memory, per-mission growth, stutter count, 1%% low and the growth rate all start measuring fresh from this moment. Handy after a cleanup, or when you want to watch only what happens next.",
		ru = "Клавиша, чтобы прямо сейчас сбросить накопленные показатели: пик памяти, рост за миссию, счётчик рывков, 1%% low и скорость роста начнут считаться заново с этого момента. Удобно после очистки или когда хочешь следить только за тем, что будет дальше.",
	},
	auto_reset = {
		en = "Auto-reset diagnostics",
		ru = "Авто-сброс показателей",
	},
	auto_reset_desc = {
		en = "Automatically clear the tracked numbers (peak memory, per-mission growth, stutter count and 1%% low) every so often, so they reflect recent play instead of the whole session. Off by default. You can also clear them any time with the Reset diagnostics key above.",
		ru = "Автоматически сбрасывать накопленные показатели (пик памяти, рост за миссию, счётчик рывков и 1%% low) через заданные промежутки, чтобы они отражали недавнюю игру, а не всю сессию. По умолчанию выключено. Сбросить вручную в любой момент можно клавишей сброса выше.",
	},
	auto_reset_minutes = {
		en = "Auto-reset every (minutes)",
		ru = "Авто-сброс каждые (минуты)",
	},
	auto_reset_minutes_desc = {
		en = "How often to automatically clear the tracked numbers, when Auto-reset is on.",
		ru = "Как часто автоматически сбрасывать накопленные показатели, когда включён Авто-сброс.",
	},

	gc_mode = {
		en = "Memory cleanup mode",
		ru = "Режим очистки памяти",
	},
	gc_mode_desc = {
		en = "Chooses how the mod cleans up script memory. Off = only show the numbers, never clean. On map change = clean once at the start of each mission. Balanced = keep memory tidy during play plus a cleanup each mission. Continuous = the mod paces the cleanup itself, doing a tiny time-capped slice every frame — the smoothest memory profile for long sessions. Aggressive (the default) = Continuous with bigger cleanup slices, plus cleanups on a timer and when memory grows large, a deep clean of game caches on loading screens, and an emergency cleanup near the script-memory limit — the strongest protection for long heavily-modded sessions. A regular cleanup can only reclaim memory that is no longer in use; the deep clean additionally releases known game caches, and what remains after that is cleared only by restarting the game. Picking a mode also resets the cleanup sliders below to that mode's recommended values.",
		ru = "Как мод чистит скриптовую память. Выкл = только показывать числа, не чистить. На смене карты = очистка один раз в начале каждой миссии. Сбалансированный = поддерживать память в порядке во время игры плюс очистка каждую миссию. Непрерывный = мод сам задаёт темп очистки: крошечный кусочек с лимитом времени каждый кадр — самый ровный профиль памяти для длинных сессий. Агрессивный (по умолчанию) = Непрерывный с более крупными кусочками очистки, плюс очистки по таймеру и при сильном росте памяти, глубокая очистка кэшей игры на загрузочных экранах и аварийная очистка у лимита скриптовой памяти — самая сильная защита для долгих сессий с кучей модов. Обычная очистка может вернуть только память, которая больше не используется; глубокая очистка дополнительно освобождает известные кэши игры, а что остаётся после неё — снимает только перезапуск игры. Выбор режима также сбрасывает ползунки очистки ниже на рекомендованные для него значения.",
	},
	gc_mode_off = {
		en = "Off (only show numbers)",
		ru = "Выкл (только показывать числа)",
	},
	gc_mode_map_only = {
		en = "On map change",
		ru = "На смене карты",
	},
	gc_mode_balanced = {
		en = "Balanced",
		ru = "Сбалансированный",
	},
	gc_mode_pacer = {
		en = "Continuous (smoothest)",
		ru = "Непрерывный (самый плавный)",
	},
	gc_mode_aggressive = {
		en = "Aggressive (default)",
		ru = "Агрессивный (по умолчанию)",
	},
	smooth_collect = {
		en = "Smooth cleanup (no freeze)",
		ru = "Плавная очистка (без фриза)",
	},
	smooth_collect_desc = {
		en = "When on, memory cleanups are spread out over many frames so the game keeps running smoothly (recommended). When off, cleanups happen all at once: memory is freed instantly, but the game briefly freezes. Mid-mission automatic cleanups always use the smooth method regardless of this setting; the instant method applies at mission start, outside missions and to the manual cleanup key.",
		ru = "Когда включено, очистки памяти размазываются на много кадров, и игра идёт плавно (рекомендуется). Когда выключено, очистка происходит разом: память освобождается мгновенно, но игра кратко подвисает. Автоматические очистки в разгар миссии всегда идут плавным способом независимо от этой настройки; мгновенный способ применяется в начале миссии, вне миссий и для клавиши ручной очистки.",
	},
	gc_pause = {
		en = "Advanced: cleanup spacing",
		ru = "Продвинутое: частота очистки",
	},
	gc_pause_desc = {
		en = "How long the game waits between its own automatic cleanups. Lower keeps memory smaller (cleans more often); higher lets it build up more. In Continuous and Aggressive modes the recommended value is deliberately HIGH: it keeps the game's unpaced automatic cleanup out of the way, so all cleaning happens in the mod's smooth per-frame slices instead. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Сколько игра ждёт между собственными автоматическими очистками. Меньше = память держится плотнее (чистит чаще); больше = даёт накопиться сильнее. В Непрерывном и Агрессивном режимах рекомендованное значение намеренно ВЫСОКОЕ: оно убирает с дороги неразмеренную автоматическую очистку игры, чтобы вся уборка шла плавными покадровыми кусочками мода. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	gc_stepmul = {
		en = "Advanced: cleanup effort",
		ru = "Продвинутое: интенсивность очистки",
	},
	gc_stepmul_desc = {
		en = "How much cleanup work each unit of effort does. Higher keeps up with memory better and wastes less overhead per slice. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Сколько работы по очистке делает каждая единица усилия. Больше = лучше поспевает за памятью и меньше накладных расходов на кусочек. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	gc_budget_us = {
		en = "Smooth cleanup speed",
		ru = "Скорость плавной очистки",
	},
	gc_budget_us_desc = {
		en = "How much frame time the smooth cleanup and the Continuous mode may spend per frame, in microseconds. Higher frees memory faster but eats into the frame; lower is smoother but takes longer. On spike frames the work is skipped automatically. Outside missions the cleanup automatically works several times harder, since those frames are cheap. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Сколько времени кадра могут тратить плавная очистка и Непрерывный режим, в микросекундах. Больше = память освобождается быстрее, но забирает часть кадра; меньше = плавнее, но дольше. На кадрах с рывком работа автоматически пропускается. Вне миссий очистка автоматически работает в несколько раз усерднее — там кадры дешёвые. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	mem_type = {
		en = "RAM type",
		ru = "Тип памяти (ОЗУ)",
	},
	mem_type_desc = {
		en = "Sets how large a single slice of cleanup work may be. Cleanup is done in slices, and the mod can only check its stopwatch BETWEEN slices — so one slice that runs long is time the frame spends over budget. How long a slice takes depends on your RAM: the same slice can cost three times more on old DDR3 than on fast DDR5, and that difference lands entirely on the weakest machines. 'Auto' (recommended) ignores the setting below and simply measures how fast cleanup actually runs on your PC, then sizes the slices to fit. Pick your RAM generation manually only if you would rather not rely on the measurement. This never changes how much frame time cleanup is allowed to use — only how finely that time is chopped up.",
		ru = "Задаёт, каким по размеру может быть один кусочек работы по очистке. Очистка идёт кусочками, а свериться с секундомером мод может только МЕЖДУ ними — поэтому один затянувшийся кусочек и есть перерасход времени кадра. Длительность кусочка зависит от вашей ОЗУ: один и тот же кусочек на старой DDR3 может стоить втрое дороже, чем на быстрой DDR5, и этот перерасход целиком достаётся самым слабым машинам. «Авто» (рекомендуется) игнорирует настройку ниже и просто измеряет, насколько быстро очистка реально идёт на вашем ПК, и подбирает размер кусочков. Выбирайте поколение памяти вручную, только если не хотите доверять измерению. На то, сколько времени кадра разрешено тратить на очистку, это не влияет — только на то, насколько мелко это время нарезано.",
	},
	mem_type_auto = {
		en = "Auto (measure on this PC)",
		ru = "Авто (измерить на этом ПК)",
	},
	mem_type_ddr3 = {
		en = "DDR3",
		ru = "DDR3",
	},
	mem_type_ddr4 = {
		en = "DDR4",
		ru = "DDR4",
	},
	mem_type_ddr5 = {
		en = "DDR5",
		ru = "DDR5",
	},
	mem_mts = {
		en = "RAM speed (closest to yours)",
		ru = "Частота памяти (ближайшая к вашей)",
	},
	mem_mts_desc = {
		en = "Used only when RAM type above is not 'Auto'. Pick the value closest to your memory speed in MT/s (what a kit sells as 'DDR4-3200' is 3200 MT/s; CPU-Z, Task Manager > Performance > Memory, or your XMP/EXPO profile will tell you). Exactness does not matter much: cleanup speed depends far more on memory latency, which barely changed across DDR generations, than on the headline number — which is why 'Auto' measures instead of guessing.",
		ru = "Используется только если тип памяти выше не «Авто». Выберите значение, ближайшее к частоте вашей памяти в MT/s (то, что продаётся как «DDR4-3200» — это 3200 MT/s; посмотреть можно в CPU-Z, в Диспетчере задач > Производительность > Память, или в профиле XMP/EXPO). Точность не критична: скорость очистки куда сильнее зависит от задержек памяти, которые между поколениями DDR почти не менялись, чем от цифры частоты — именно поэтому «Авто» измеряет, а не угадывает.",
	},
	mem_mts_1333 = { en = "1333 MT/s", ru = "1333 MT/s" },
	mem_mts_1600 = { en = "1600 MT/s", ru = "1600 MT/s" },
	mem_mts_1866 = { en = "1866 MT/s", ru = "1866 MT/s" },
	mem_mts_2133 = { en = "2133 MT/s", ru = "2133 MT/s" },
	mem_mts_2400 = { en = "2400 MT/s", ru = "2400 MT/s" },
	mem_mts_2666 = { en = "2666 MT/s", ru = "2666 MT/s" },
	mem_mts_3000 = { en = "3000 MT/s", ru = "3000 MT/s" },
	mem_mts_3200 = { en = "3200 MT/s", ru = "3200 MT/s" },
	mem_mts_3600 = { en = "3600 MT/s", ru = "3600 MT/s" },
	mem_mts_4000 = { en = "4000 MT/s", ru = "4000 MT/s" },
	mem_mts_4800 = { en = "4800 MT/s", ru = "4800 MT/s" },
	mem_mts_5200 = { en = "5200 MT/s", ru = "5200 MT/s" },
	mem_mts_5600 = { en = "5600 MT/s", ru = "5600 MT/s" },
	mem_mts_6000 = { en = "6000 MT/s", ru = "6000 MT/s" },
	mem_mts_6400 = { en = "6400 MT/s", ru = "6400 MT/s" },
	mem_mts_7200 = { en = "7200 MT/s", ru = "7200 MT/s" },
	mem_mts_8000 = { en = "8000 MT/s", ru = "8000 MT/s" },
	hw_profile = {
		en = "Hardware advice",
		ru = "Советы по железу",
	},
	hw_profile_desc = {
		en = "Once per session, a minute or so into a mission, the mod looks at what it has measured -- how much memory survives every cleanup, how close that is to the limit, your frame time, cleanup speed on your PC, video memory pressure -- and tells you the one or two things that would actually help. 'Advise' only writes them to chat and the log. 'Apply' also changes what it safely can: the script memory limit when your launch options prove the game's memory area is bigger, the cleanup speed when it is a large share of your frame, the cleanup mode when your frame rate says a cheaper one would serve you better, and the VRAM line when video memory is the real bottleneck. Nothing here is guessed from a hardware name: it is measured on your PC, in your session.",
		ru = "Раз за сессию, примерно через минуту в миссии, мод смотрит на то, что уже измерил — сколько памяти выживает после каждой очистки, насколько это близко к лимиту, ваше время кадра, скорость очистки именно на вашем ПК, давление на видеопамять — и называет одну-две вещи, которые реально помогут. «Советовать» только пишет их в чат и лог. «Применять» ещё и меняет то, что можно менять безопасно: лимит скриптовой памяти, если ваши параметры запуска доказывают, что область памяти игры больше; скорость очистки, если она занимает большую долю кадра; режим очистки, если по частоте кадров вам выгоднее более дешёвый; и строку VRAM, если настоящее узкое место — видеопамять. Ничего здесь не угадывается по названию железа: всё измерено на вашем ПК в вашей сессии.",
	},
	hw_profile_advise = {
		en = "Advise (chat and log only)",
		ru = "Советовать (только чат и лог)",
	},
	hw_profile_apply = {
		en = "Advise and apply what is safe",
		ru = "Советовать и применять безопасное",
	},
	hw_profile_off = {
		en = "Off",
		ru = "Выключено",
	},
	vram_gb = {
		en = "Video memory (GB)",
		ru = "Видеопамять (ГБ)",
	},
	vram_gb_desc = {
		en = "Your graphics card's memory. This never changes anything about cleanup -- video memory is not the game's script memory, and no cleanup setting moves it by a byte. It is asked for one reason: on cards with little VRAM, stutter on busy maps is usually video memory rather than script memory, and the mod would rather tell you that than sell you cleanup settings that cannot help. 'Auto' reads the driver's own figure where the game exposes it, which is better than any number you can type here; pick a size only if the panel shows no VRAM reading.",
		ru = "Объём памяти вашей видеокарты. На очистку это не влияет никак: видеопамять — не скриптовая память игры, и ни одна настройка очистки её не двигает. Спрашивается ровно по одной причине: на картах с малым объёмом VRAM подёргивания на нагруженных картах обычно вызваны видеопамятью, а не скриптовой, и мод предпочтёт сказать вам это, а не продавать настройки очистки, которые тут не помогут. «Авто» берёт цифру у самого драйвера, если игра её отдаёт, — это точнее любого значения, введённого вручную; выбирайте объём только если панель не показывает VRAM.",
	},
	vram_gb_auto = { en = "Auto (read from the driver)", ru = "Авто (взять у драйвера)" },
	vram_gb_2 =  { en = "2 GB",  ru = "2 ГБ" },
	vram_gb_3 =  { en = "3 GB",  ru = "3 ГБ" },
	vram_gb_4 =  { en = "4 GB",  ru = "4 ГБ" },
	vram_gb_6 =  { en = "6 GB",  ru = "6 ГБ" },
	vram_gb_8 =  { en = "8 GB",  ru = "8 ГБ" },
	vram_gb_10 = { en = "10 GB", ru = "10 ГБ" },
	vram_gb_12 = { en = "12 GB", ru = "12 ГБ" },
	vram_gb_16 = { en = "16 GB", ru = "16 ГБ" },
	vram_gb_24 = { en = "24 GB or more", ru = "24 ГБ и больше" },
	periodic_minutes = {
		en = "Periodic cleanup (minutes)",
		ru = "Периодическая очистка (минуты)",
	},
	periodic_minutes_desc = {
		en = "Aggressive mode only: how often to clean memory on a timer. The timed cleanup is skipped when almost nothing has piled up since the last one. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Только агрессивный режим: как часто чистить память по таймеру. Плановая очистка пропускается, если с прошлой очистки почти ничего не накопилось. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	threshold_mb = {
		en = "Cleanup trigger (MB)",
		ru = "Порог очистки (МБ)",
	},
	threshold_mb_desc = {
		en = "Cleans memory once it grows past this size. Used by Aggressive mode and as a safety backstop in Continuous mode. After such a cleanup the trigger re-arms only once memory grows noticeably again, so cleanups cannot fire back-to-back. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Чистить память, когда она вырастает больше этого размера. Используется Агрессивным режимом и как страховка в Непрерывном. После такой очистки триггер взводится снова только после заметного нового роста памяти, поэтому очистки не идут одна за другой. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	heap_ceiling_mb = {
		en = "Script memory limit (MB)",
		ru = "Лимит скриптовой памяти (МБ)",
	},
	heap_ceiling_mb_desc = {
		en = "The game reserves a fixed amount of script memory; running out of it crashes the game with an out-of-memory error no matter how much RAM you have. When memory gets close to this limit (92%%), the mod does one instant emergency cleanup — a brief freeze that is strictly better than the crash. Stock game reserve is about 1024 MB. If you use the Steam launch option --lua-heap-mb-size 2048, set this to 2048. Set to 0 to disable the emergency backstop.",
		ru = "Игра резервирует фиксированный объём скриптовой памяти; его исчерпание роняет игру с ошибкой Out of Memory, сколько бы ОЗУ ни стояло. Когда память подходит к этому лимиту (92%%), мод делает одну мгновенную аварийную очистку — короткий фриз, который строго лучше вылета. Стандартный резерв игры — около 1024 МБ. Если используете опцию запуска Steam --lua-heap-mb-size 2048, поставьте 2048. 0 — отключить аварийную защиту.",
	},
	deep_clean = {
		en = "Deep clean on loading screens",
		ru = "Глубокая очистка на загрузках",
	},
	deep_clean_desc = {
		en = "On every loading screen, additionally releases game caches that a normal cleanup can never touch because the game itself keeps holding them: browsed premium-shop pages, the wallet cache, the raw inventory list, mastery/news/penance catalogues, group-finder tags, the previous mission's end-of-round report, the localization cache, and the pending telemetry queue — then runs a full instant cleanup while the loading screen hides the cost. This is memory that previously only a game restart could return. Safe by design: it releases only data the game reloads by itself on next use, and only between missions. It never touches textures, icons or anything owned by the renderer or by other mods.",
		ru = "На каждом загрузочном экране дополнительно освобождает кэши игры, которые обычная очистка не может тронуть никогда, потому что игра сама продолжает их держать: просмотренные страницы премиум-магазина, кэш кошельков, сырой список инвентаря, каталоги мастери/новостей/пенансов, теги группоискателя, отчёт конца прошлой миссии, кэш локализации и очередь неотправленной телеметрии — а затем делает полную мгновенную очистку, пока загрузочный экран прячет её цену. Это память, которую раньше возвращал только перезапуск игры. Безопасно по устройству: освобождаются только данные, которые игра сама загружает заново при следующем обращении, и только между миссиями. Текстуры, иконки и всё, чем владеет рендер или другие моды, не трогаются никогда.",
	},
	deep_clean_key = {
		en = "Deep clean key",
		ru = "Клавиша глубокой очистки",
	},
	deep_clean_key_desc = {
		en = "Runs the deep clean right now: game caches (only when no menu is open) plus a full instant cleanup. Causes a brief freeze — best pressed between fights, in the Mourningstar, or during long Psykhanium sessions, which pile up memory faster than anything else in the game.",
		ru = "Запускает глубокую очистку прямо сейчас: кэши игры (только когда не открыто ни одно меню) плюс полная мгновенная очистка. Вызывает короткий фриз — лучше нажимать между боями, в Морнингстаре или во время долгих сессий в Психаниуме, который копит память быстрее всего в игре.",
	},
	engine_gc = {
		en = "Suppress engine freeze-cleanups",
		ru = "Подавлять фриз-очистки движка",
	},
	engine_gc_desc = {
		en = "The game engine runs its own memory-cleanup controller with a built-in emergency: when script garbage piles up fast, the ENGINE freezes the game for a full cleanup — mid-fight, unpaced, invisible to any mod's smooth cleanup. This option raises the engine's emergency bar so those freezes stop happening, and the mod's own paced cleanup plus the memory-limit backstop take over that duty. Works in Continuous and Aggressive modes. If the game build lacks this control, the option quietly does nothing.",
		ru = "Движок игры запускает собственный контроллер очистки памяти со встроенной аварийкой: когда скриптовый мусор копится быстро, ДВИЖОК замораживает игру ради полной очистки — посреди боя, без темпа, мимо любой плавной очистки мода. Эта опция поднимает аварийную планку движка, чтобы такие фризы перестали случаться, а их работу берут на себя размеренная очистка мода и защита по лимиту памяти. Работает в Непрерывном и Агрессивном режимах. Если в сборке игры этого управления нет, опция тихо ничего не делает.",
	},
	uncap_menus = {
		en = "Uncap FPS in menus",
		ru = "Снять кап FPS в меню",
	},
	uncap_menus_desc = {
		en = "The game silently caps FPS at 60 whenever a full-screen menu is open (inventory, crafting, social menu, mission board — even mid-mission). This lifts that cap so menus run at your full frame rate. Note: the cap exists to reduce GPU load and heat in menus, so leaving it off is also a valid choice.",
		ru = "Игра молча ограничивает FPS до 60, когда открыто любое полноэкранное меню (инвентарь, крафт, соцменю, доска миссий — даже посреди миссии). Эта опция снимает ограничение, и меню работают на полной частоте кадров. Учтите: кап существует, чтобы снизить нагрузку и нагрев видеокарты в меню, так что оставить его — тоже нормальный выбор.",
	},
	fast_loading = {
		en = "Uncap FPS on loading screens",
		ru = "Снять кап FPS на загрузках",
	},
	fast_loading_desc = {
		en = "Loading screens run under the game's 60 FPS cap, and the game moves loaded assets along once per frame — so the cap also slows loading turnaround slightly. This lifts the cap during loading screens. Expect a small improvement on fast SSDs and none on slow drives; the GPU renders the loading screen faster for nothing in return, so this is off by default.",
		ru = "Загрузочные экраны идут под капом 60 FPS, а игра продвигает загруженные ресурсы раз в кадр — поэтому кап немного замедляет и оборот загрузки. Эта опция снимает кап на время загрузки. Ожидайте небольшое ускорение на быстрых SSD и ничего на медленных дисках; видеокарта при этом зря рендерит экран загрузки быстрее, поэтому по умолчанию выключено.",
	},
	mod_profiler = {
		en = "Mod memory profiler",
		ru = "Профайлер памяти модов",
	},
	mod_profiler_desc = {
		en = "Finds which mod is allocating script memory: measures every mod's update step and shows the biggest allocator on the panel as 'top alloc' (also written to the log). This measures allocation rate, not leaks — a busy mod is not automatically a leaking one — but the classic leaker that grows tables every frame shows up within seconds. Costs a tiny fixed overhead per mod per frame while enabled. Works in Continuous and Aggressive modes.",
		ru = "Ищет, какой мод выделяет скриптовую память: замеряет шаг update каждого мода и показывает крупнейшего аллокатора на панели строкой «top alloc» (и пишет в лог). Это скорость выделения, а не утечка — занятой мод не обязательно течёт — но классический «течец», растящий таблицы каждый кадр, виден за секунды. Пока включено, стоит крошечных фиксированных накладных расходов на мод за кадр. Работает в Непрерывном и Агрессивном режимах.",
	},
	force_gc_key = {
		en = "Manual cleanup key (instant)",
		ru = "Клавиша ручной очистки (мгновенно)",
	},
	force_gc_key_desc = {
		en = "Key to clean memory right now, all in one go. It frees memory instantly but causes a brief freeze, so it's best used between fights or on a loading screen.",
		ru = "Клавиша, чтобы очистить память прямо сейчас и разом. Освобождает память мгновенно, но вызывает короткий фриз, поэтому лучше нажимать между боями или на загрузочном экране.",
	},
	show_proc_mem = {
		en = "Show: game memory and VRAM",
		ru = "Показывать: память игры и VRAM",
	},
	show_proc_mem_desc = {
		en = "Extra panel line with the engine's own memory total for the whole game and, on Windows, video memory used against the driver's budget. This is the memory the script-memory number can never see: if FPS melts while script memory looks fine and VRAM sits near its budget (the line turns yellow at 90%%), the problem is graphics memory — lower texture/shadow settings; no script cleanup can help. Read-only, sampled every few seconds.",
		ru = "Дополнительная строка панели: общая память игры по учёту самого движка и, на Windows, занятая видеопамять относительно бюджета драйвера. Это память, которую число скриптовой памяти не видит в принципе: если FPS тает, скриптовая память в норме, а VRAM у бюджета (строка желтеет на 90%%) — проблема в видеопамяти, помогут настройки текстур/теней, а не очистка скриптов. Только чтение, замер раз в несколько секунд.",
	},
	fix_hud_leaks = {
		en = "Fix game HUD widget leaks",
		ru = "Чинить утечки HUD-виджетов игры",
	},
	fix_hud_leaks_desc = {
		en = "Fixes two small memory leaks in the game itself: the HUD's world markers (nameplates, interaction prompts, tags, chat bubbles) and the kill feed each create a uniquely-named widget per entry and never release the name registration, so memory grows slowly for the whole mission or hub session. The fix releases each widget's registration the moment the game removes the entry — using the game's own cleanup call that these two elements simply forgot to make. Safe to leave on; turn off only when hunting a HUD problem.",
		ru = "Чинит две небольшие утечки памяти в самой игре: мировые маркеры HUD (неймплейты, подсказки взаимодействия, метки, реплики чата) и килфид создают по уникально именованному виджету на каждую запись и никогда не снимают регистрацию имени — память медленно растёт всю миссию или сессию в хабе. Фикс снимает регистрацию виджета в момент, когда игра сама удаляет запись — тем же штатным вызовом очистки, который эти два элемента просто забыли сделать. Можно держать включённым; выключайте только при разборе проблем с HUD.",
	},
	menu_drain = {
		en = "Cleanup after heavy menus",
		ru = "Очистка после тяжёлых меню",
	},
	menu_drain_desc = {
		en = "When closing a menu left more than a few MB of fresh garbage behind (the mod options list and the inventory are the usual offenders), start a smooth paced cleanup right away instead of letting that garbage sit until the next scheduled cleanup. Uses the same time-capped, spike-aware cleanup as everything else. Works in Continuous and Aggressive modes.",
		ru = "Если закрытие меню оставило после себя больше нескольких МБ свежего мусора (обычные виновники — список настроек модов и инвентарь), сразу запускать плавную размеренную очистку, не дожидаясь следующей плановой. Использует ту же очистку с лимитом времени и защитой от рывков, что и всё остальное. Работает в Непрерывном и Агрессивном режимах.",
	},
	dmf_release = {
		en = "Experimental: release mod-menu leftovers",
		ru = "Экспериментально: освобождать остатки меню модов",
	},
	dmf_release_desc = {
		en = "The mod framework's options menu keeps one full copy of its last widget build (every setting of every installed mod) referenced even after the menu closes — a few MB with many mods. This option releases those references right after the menu closes so the next cleanup can reclaim them. Uses name-based lookups only, touches nothing while the menu is open, and quietly does nothing if the framework changes. Experimental: works in Continuous and Aggressive modes.",
		ru = "Меню настроек мод-фреймворка держит одну полную копию последней сборки своих виджетов (все настройки всех установленных модов) даже после закрытия меню — несколько МБ при большом наборе модов. Эта опция освобождает эти ссылки сразу после закрытия меню, чтобы следующая очистка могла их забрать. Работает только по именам, ничего не трогает при открытом меню и тихо бездействует, если фреймворк изменится. Экспериментально: работает в Непрерывном и Агрессивном режимах.",
	},
	mute_telemetry = {
		en = "Mute game telemetry",
		ru = "Отключить телеметрию игры",
	},
	mute_telemetry_desc = {
		en = "Stops the game from collecting gameplay telemetry events (they are buffered in memory — up to 16000 entries — and serialized and sent every 5 minutes, which costs a small hiccup). Crash reporting is separate and stays untouched. Note: with this on, Fatshark does not receive performance telemetry from your client, which is data they use to improve the game — that is why it is off by default.",
		ru = "Останавливает сбор игровых событий телеметрии (они копятся в памяти — до 16000 записей — и раз в 5 минут сериализуются и отправляются, что стоит небольшого подвисания). Отчёты о вылетах — отдельная система, она не затрагивается. Учтите: с этой опцией Fatshark не получает телеметрию производительности с вашего клиента, а по ней они улучшают игру — поэтому по умолчанию выключено.",
	},
	diag_log = {
		en = "Write measurements to the game log",
		ru = "Писать замеры в лог игры",
	},
	diag_log_desc = {
		en = "Every ten seconds, writes one line to the game log with the frame rate, the 1%% low, how often the cleanup ran and for how many milliseconds per second, where memory sits, and the settings in force. Use it to answer 'is this actually costing me frames' with numbers instead of impressions: play the same mission twice, once as you have it and once with the cleanup mode set to Off, then compare the lines. The log is at Documents (or %%APPDATA%%) / Fatshark / Darktide / console_logs. Off by default -- it costs nothing to run but there is no reason to fill the log when you are not comparing anything.",
		ru = "Каждые десять секунд пишет в лог игры одну строку: частота кадров, 1%% low, как часто работала очистка и сколько миллисекунд в секунду она заняла, где стоит память и какие настройки действуют. Нужно, чтобы отвечать на вопрос «это правда стоит мне кадров» числами, а не ощущениями: пройдите одну и ту же миссию дважды — один раз как есть, второй с режимом очистки «Выключено» — и сравните строки. Лог лежит в Документы (или %%APPDATA%%) / Fatshark / Darktide / console_logs. По умолчанию выключено: работа стоит недорого, но забивать лог без сравнения незачем.",
	},
	silent = {
		en = "Hide chat messages",
		ru = "Скрыть сообщения в чате",
	},
	silent_desc = {
		en = "When on, the mod won't post cleanup messages in chat. The same info still goes to the mod's log file.",
		ru = "Когда включено, мод не пишет сообщения об очистке в чат. Та же информация всё равно идёт в лог-файл мода.",
	},
}
