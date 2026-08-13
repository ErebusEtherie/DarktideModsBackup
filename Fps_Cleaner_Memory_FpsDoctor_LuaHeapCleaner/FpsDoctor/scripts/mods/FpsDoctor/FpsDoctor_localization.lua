local mod = get_mod("FpsDoctor")

return {
	mod_name = {
		en = "FPS Doctor",
		ru = "FPS Doctor",
	},
	mod_description = {
		en = "On-screen performance panel (FPS, 1%% low, frame time, memory use and its growth) plus optional automatic memory cleanup. Helps you tell apart a script-memory problem (memory climbs over time, FPS recovers after a cleanup or a new mission) from a graphics-card limit on heavy maps (memory steady, FPS just low). Note: the game does not report video memory (VRAM) to mods, so watch that with an external overlay such as MSI Afterburner / RTSS.",
		ru = "Экранная панель производительности (FPS, 1%% low, время кадра, расход памяти и его рост) плюс опциональная авто-очистка памяти. Помогает отличить проблему со скриптовой памятью (память растёт со временем, FPS восстанавливается после очистки или новой миссии) от упора в видеокарту на тяжёлых картах (память ровная, FPS просто низкий). Важно: игра не сообщает модам видеопамять (VRAM), поэтому смотрите её внешним оверлеем (MSI Afterburner / RTSS).",
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
		en = "Show how much script memory the game is using and whether it's climbing. Memory that keeps climbing is the usual reason FPS gets worse the longer you play.",
		ru = "Сколько скриптовой памяти занимает игра и растёт ли она. Постоянно растущая память — обычная причина того, что FPS падает со временем игры.",
	},
	show_mission = {
		en = "Show: peak & per-mission growth",
		ru = "Показывать: пик и рост за миссию",
	},
	show_mission_desc = {
		en = "Show the highest memory reached this session, the floor (what remains right after a full cleanup) and how much memory grew during the current mission. The floor is the true leak indicator: if it climbs mission after mission, something is really leaking; a high peak that drops back to the same floor after cleanup is normal.",
		ru = "Наибольший достигнутый расход памяти за сессию, «пол» (сколько остаётся сразу после полной очистки) и рост за текущую миссию. Пол — главный индикатор утечки: если он растёт от миссии к миссии, что-то действительно течёт; высокий пик, который после очистки возвращается к тому же полу, — это норма.",
	},
	show_hitch = {
		en = "Show: stutter count",
		ru = "Показывать: счётчик рывков",
	},
	show_hitch_desc = {
		en = "Show how many noticeable stutters happened this mission. Good for spotting hitching that the average FPS hides. If the mod's own memory cleanup was busy on a stutter frame, the line shows it as '(N gc)' — so you can tell cleanup spikes apart from heavy scenes.",
		ru = "Сколько заметных рывков случилось за миссию. Помогает заметить подёргивания, которые средний FPS скрывает. Если в кадре рывка была занята собственная очистка памяти мода, строка покажет это как «(N gc)» — так можно отличить всплески очистки от тяжёлых сцен.",
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
		en = "Chooses how the mod cleans up script memory. Off = only show the numbers, never clean. On map change = clean once at the start of each mission. Balanced = keep memory tidy during play plus a cleanup each mission (recommended). Continuous = the mod paces the cleanup itself, doing a tiny time-capped slice every frame — the smoothest memory profile for long sessions. Aggressive = Balanced plus extra cleanups on a timer and when memory grows large. Picking a mode also resets the cleanup sliders below to that mode's recommended values.",
		ru = "Как мод чистит скриптовую память. Выкл = только показывать числа, не чистить. На смене карты = очистка один раз в начале каждой миссии. Сбалансированный = поддерживать память в порядке во время игры плюс очистка каждую миссию (рекомендуется). Непрерывный = мод сам задаёт темп очистки: крошечный кусочек с лимитом времени каждый кадр — самый ровный профиль памяти для длинных сессий. Агрессивный = Сбалансированный плюс дополнительные очистки по таймеру и при сильном росте памяти. Выбор режима также сбрасывает ползунки очистки ниже на рекомендованные для него значения.",
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
		en = "Balanced (recommended)",
		ru = "Сбалансированный (рекоменд.)",
	},
	gc_mode_pacer = {
		en = "Continuous (smoothest)",
		ru = "Непрерывный (самый плавный)",
	},
	gc_mode_aggressive = {
		en = "Aggressive",
		ru = "Агрессивный",
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
		en = "How long the game waits between automatic cleanups. Lower keeps memory smaller (cleans more often); higher lets it build up more. Not used in Continuous mode (it paces itself). Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Сколько игра ждёт между автоматическими очистками. Меньше = память держится плотнее (чистит чаще); больше = даёт накопиться сильнее. В Непрерывном режиме не используется (он задаёт темп сам). Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	gc_stepmul = {
		en = "Advanced: cleanup effort",
		ru = "Продвинутое: интенсивность очистки",
	},
	gc_stepmul_desc = {
		en = "How hard each automatic cleanup works. Higher keeps up with memory better. Not used in Continuous mode (it paces itself). Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Насколько сильно работает каждая автоматическая очистка. Больше = лучше поспевает за памятью. В Непрерывном режиме не используется (он задаёт темп сам). Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
	gc_budget_us = {
		en = "Smooth cleanup speed",
		ru = "Скорость плавной очистки",
	},
	gc_budget_us_desc = {
		en = "How much frame time the smooth cleanup and the Continuous mode may spend per frame, in microseconds. Higher frees memory faster but eats into the frame; lower is smoother but takes longer. On spike frames the work is skipped automatically. Outside missions the cleanup automatically works several times harder, since those frames are cheap. Changing the cleanup mode resets this to the mode's recommended value.",
		ru = "Сколько времени кадра могут тратить плавная очистка и Непрерывный режим, в микросекундах. Больше = память освобождается быстрее, но забирает часть кадра; меньше = плавнее, но дольше. На кадрах с рывком работа автоматически пропускается. Вне миссий очистка автоматически работает в несколько раз усерднее — там кадры дешёвые. Смена режима очистки сбрасывает это значение на рекомендованное.",
	},
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
	force_gc_key = {
		en = "Manual cleanup key (instant)",
		ru = "Клавиша ручной очистки (мгновенно)",
	},
	force_gc_key_desc = {
		en = "Key to clean memory right now, all in one go. It frees memory instantly but causes a brief freeze, so it's best used between fights or on a loading screen.",
		ru = "Клавиша, чтобы очистить память прямо сейчас и разом. Освобождает память мгновенно, но вызывает короткий фриз, поэтому лучше нажимать между боями или на загрузочном экране.",
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
