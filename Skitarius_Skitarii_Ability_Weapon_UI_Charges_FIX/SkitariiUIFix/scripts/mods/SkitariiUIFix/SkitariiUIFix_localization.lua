return {
	mod_name = {
		en = "Skitarii UI Fix",
		ru = "Skitarii UI Fix",
	},
	mod_description = {
		en = "HUD fixes for the Skitarii / Adeptus Mechanicus class. Shows the ability cooldown as a percent (1-100%%) in a colour you choose, instead of the seconds readout the charge ability falls back to. Lets you customise the weapon special charges shown in the centre of the screen (Arc Maul / Mechanicus Power Sword): show them as a number, or recolour the original pips so they stand out - and move, turn or mirror the whole gauge away from the crosshair. Also shows the remaining duration of the Noospheric Command servo-skull order as an arc bar (or a seconds countdown) beside the crosshair, movable the same way. Works on its own and alongside NumericUI.",
		ru = "Исправления интерфейса для класса Скитарии / Адептус Механикус. Показывает перезарядку способности в процентах (1-100%%) выбранным цветом вместо секунд, в которые скатывается зарядовая способность. Позволяет настроить заряды доп-атаки оружия в центре экрана (Arc Maul / Mechanicus Power Sword): показать их числом или перекрасить оригинальные индикаторы, чтобы были заметнее, — а также сдвинуть, повернуть или отразить всю шкалу подальше от прицела. Также показывает оставшееся время приказа сервочерепу (Noospheric Command) дуговой полоской (или отсчётом секунд) рядом с прицелом, с теми же настройками положения. Работает сам по себе и вместе с NumericUI.",
	},

	ability_group = {
		en = "Ability cooldown (percent)",
		ru = "Перезарядка способности (проценты)",
	},
	ability_enabled = {
		en = "Show cooldown as percent",
		ru = "Показывать перезарядку в процентах",
	},
	ability_enabled_description = {
		en = "Show the ability recharge as a percent (1-100%%) over the ability icon. Designed for the charge-based Skitarii ability, which otherwise shows a seconds countdown. Turn off to leave the ability HUD untouched.",
		ru = "Показывать восстановление способности в процентах (1-100%%) поверх иконки. Сделано для зарядовой способности Скитария, которая иначе показывает отсчёт в секундах. Выключите, чтобы не трогать интерфейс способности.",
	},
	ability_skitarii_only = {
		en = "Only for the Skitarii class",
		ru = "Только для класса Скитарии",
	},
	ability_skitarii_only_description = {
		en = "Only show the percent when you are playing the Skitarii / Adeptus Mechanicus class (detected automatically). Turn off to show the percent over the combat ability of every class.",
		ru = "Показывать процент только когда вы играете за класс Скитарии / Адептус Механикус (определяется автоматически). Выключите, чтобы показывать процент поверх боевой способности у любого класса.",
	},
	ability_percent_position = {
		en = "Percent placement",
		ru = "Где показывать процент",
	},
	ability_percent_position_description = {
		en = "Where to show the recharge percent. Over icon: large, centred on the ability icon. Next to charge count: small, in parentheses to the right of the vanilla charge count above the icon, e.g. \"0 (45%%)\".",
		ru = "Где показывать процент восстановления. На иконке: крупно, по центру иконки способности. Рядом со счётчиком зарядов: мелко, в скобках справа от ванильного счётчика зарядов над иконкой, например «0 (45%%)».",
	},
	ability_pos_icon = {
		en = "Over the icon",
		ru = "На иконке",
	},
	ability_pos_charges = {
		en = "Next to charge count (in brackets)",
		ru = "Рядом со счётчиком зарядов (в скобках)",
	},
	ability_color = {
		en = "Percent colour",
		ru = "Цвет процентов",
	},
	ability_color_description = {
		en = "Colour of the percent text.",
		ru = "Цвет текста процентов.",
	},
	ability_font_size = {
		en = "Percent font size",
		ru = "Размер шрифта процентов",
	},
	ability_font_size_description = {
		en = "Size of the percent text over the ability icon.",
		ru = "Размер текста процентов поверх иконки способности.",
	},
	ability_percent_offset_x = {
		en = "Percent offset X",
		ru = "Смещение процента по X",
	},
	ability_percent_offset_x_description = {
		en = "Move the percent text left (negative) or right (positive). Applies to both placements.",
		ru = "Сдвинуть текст процента влево (минус) или вправо (плюс). Действует в обоих режимах размещения.",
	},
	ability_percent_offset_y = {
		en = "Percent offset Y",
		ru = "Смещение процента по Y",
	},
	ability_percent_offset_y_description = {
		en = "Move the percent text up (negative) or down (positive). Applies to both placements.",
		ru = "Сдвинуть текст процента вверх (минус) или вниз (плюс). Действует в обоих режимах размещения.",
	},

	wc_group = {
		en = "Weapon special charges",
		ru = "Заряды доп-атаки оружия",
	},
	wc_enabled = {
		en = "Customise weapon charges",
		ru = "Настроить заряды оружия",
	},
	wc_enabled_description = {
		en = "Customise the weapon special charges drawn in the centre of the screen (the semi-transparent pips for weapons whose special recharges over time, e.g. Arc Maul / Mechanicus Power Sword). Turn off to leave them exactly as the game draws them.",
		ru = "Настроить заряды доп-атаки оружия в центре экрана (полупрозрачные индикаторы оружия, чья доп-атака восстанавливается со временем — Arc Maul / Mechanicus Power Sword). Выключите, чтобы оставить их как рисует игра.",
	},
	wc_mode = {
		en = "View",
		ru = "Вид отображения",
	},
	wc_mode_description = {
		en = "How to show the charges. Recolour: keep the original pips but force a brighter colour. Numbers: hide the pips and show the current charge count as text (size on the slider below). Original look: don't touch the colours at all - use this when you only want to move, turn or mirror the gauge.",
		ru = "Как показывать заряды. Перекрасить: оставить оригинальные индикаторы, но задать яркий цвет. Цифры: спрятать индикаторы и показывать текущее число зарядов текстом (размер — ползунком ниже). Как в игре: не менять цвета вообще — берите этот вариант, если нужно только сдвинуть, повернуть или отразить шкалу.",
	},
	wc_mode_recolor = {
		en = "Recolour original pips",
		ru = "Перекрасить оригинал",
	},
	wc_mode_numbers = {
		en = "Show as a number",
		ru = "Показывать числом",
	},
	wc_mode_vanilla = {
		en = "Original look (move only)",
		ru = "Как в игре (только положение)",
	},
	wc_offset_x = {
		en = "Gauge offset X",
		ru = "Смещение шкалы по X",
	},
	wc_offset_x_description = {
		en = "Move the whole charge gauge left (negative) or right (positive), away from the middle of the screen. The gauge still follows the crosshair, it is just drawn this far from it. Applies to the pips and to the number view.",
		ru = "Сдвинуть всю шкалу зарядов влево (минус) или вправо (плюс), от центра экрана. Шкала по-прежнему следует за прицелом, просто рисуется на таком расстоянии от него. Действует и на индикаторы, и на режим числа.",
	},
	wc_offset_y = {
		en = "Gauge offset Y",
		ru = "Смещение шкалы по Y",
	},
	wc_offset_y_description = {
		en = "Move the whole charge gauge up (negative) or down (positive), away from the middle of the screen. Applies to the pips and to the number view.",
		ru = "Сдвинуть всю шкалу зарядов вверх (минус) или вниз (плюс), от центра экрана. Действует и на индикаторы, и на режим числа.",
	},
	wc_mirror = {
		en = "Mirror the gauge",
		ru = "Отразить шкалу",
	},
	wc_mirror_description = {
		en = "Flip the charge pips. Horizontally: the arc moves to the LEFT side of the crosshair (charges still fill bottom to top). Vertically: the charge order flips upside down. Both: rotates the arc 180 degrees while keeping it readable.",
		ru = "Отразить индикаторы зарядов. По горизонтали: дуга переезжает на ЛЕВУЮ сторону от прицела (заряды по-прежнему заполняются снизу вверх). По вертикали: порядок зарядов переворачивается. И так и так: разворот дуги на 180 градусов с сохранением читаемости.",
	},
	wc_rotation = {
		en = "Rotate the gauge (degrees)",
		ru = "Поворот шкалы (градусы)",
	},
	wc_rotation_description = {
		en = "Turn the charge pips around the middle of the gauge. 0 = as the game draws them (arc to the right of the crosshair), 90 / 180 / 270 put the arc below / left / above it. Does not affect the number view.",
		ru = "Повернуть индикаторы зарядов вокруг центра шкалы. 0 = как рисует игра (дуга справа от прицела), 90 / 180 / 270 — дуга снизу / слева / сверху. На режим числа не влияет.",
	},
	wc_color = {
		en = "Colour",
		ru = "Цвет",
	},
	wc_color_description = {
		en = "Main colour: the pip outline/border in the 'Recolour' view, and the number in the 'Show as a number' view.",
		ru = "Основной цвет: контур индикатора в режиме «Перекрасить» и число в режиме «Показывать числом».",
	},
	wc_fill_contrast = {
		en = "Contrasting inner fill",
		ru = "Контрастная заливка",
	},
	wc_fill_contrast_description = {
		en = "Recolour view only: paint the inner fill of each charge a separate, solid (100%%) contrasting colour while the border keeps the main colour, so a filled charge really stands out. Whether that fill fades out at max charges is now a separate setting below - this option only decides its colour.",
		ru = "Только режим «Перекрасить»: красить внутреннюю заливку каждого заряда отдельным сплошным (100%%) контрастным цветом, а контур оставлять основным — так заполненный заряд заметнее. Гаснет ли эта заливка при полном заряде, теперь решает отдельная настройка ниже — здесь задаётся только цвет.",
	},
	wc_fill_color = {
		en = "Inner fill colour",
		ru = "Цвет заливки",
	},
	wc_fill_color_description = {
		en = "Colour of the inner fill when 'Contrasting inner fill' is on. White / yellow / orange read well against most pip colours.",
		ru = "Цвет внутренней заливки, когда включена «Контрастная заливка». Белый / жёлтый / оранжевый хорошо читаются на большинстве цветов индикатора.",
	},
	wc_no_fade_fill = {
		en = "Keep inner fill lit at max charges",
		ru = "Не гасить заливку при полном заряде",
	},
	wc_no_fade_fill_description = {
		en = "The game fades the charge gauge out about two seconds after the charges top up. With this on, the inner fill stays lit instead, so you can always tell at a glance that you are at max charges. Turn it off to let the fill fade with the rest of the gauge (that is what you want if you like the contrasting fill but not the permanent glow). Recolour view only.",
		ru = "Игра гасит шкалу зарядов примерно через две секунды после того, как заряды наполнились. Когда включено, внутренняя заливка вместо этого остаётся видимой — так всегда понятно, что заряды полные. Выключите, чтобы заливка гасла вместе с остальной шкалой (нужно, если нравится контрастная заливка, но не нравится постоянное свечение). Только режим «Перекрасить».",
	},
	wc_no_fade_outline = {
		en = "Keep outline lit at max charges",
		ru = "Не гасить контур при полном заряде",
	},
	wc_no_fade_outline_description = {
		en = "Same as above for the pip outline/border and the glow ring, so the whole gauge - not just the fill - stays visible once you are at max charges. Recolour view only.",
		ru = "То же самое для контура (границ) индикаторов и кольца свечения — тогда при полном заряде видна вся шкала, а не только заливка. Только режим «Перекрасить».",
	},
	wc_font_size = {
		en = "Number font size",
		ru = "Размер шрифта числа",
	},
	wc_font_size_description = {
		en = "Size of the charge number (used by the 'Show as a number' view).",
		ru = "Размер числа зарядов (используется в режиме «Показывать числом»).",
	},
	wc_number_opacity = {
		en = "Charges opacity",
		ru = "Непрозрачность зарядов",
	},
	wc_number_opacity_description = {
		en = "Opacity of the charge display in BOTH views (number and recoloured pips). 75 = the game's standard look; above 75 makes the pips/number more solid (up to 100 = maximum), below 75 makes them more see-through. The game's own fade-when-full is applied on top, unless you switch it off with the two settings above.",
		ru = "Непрозрачность отображения зарядов в ОБОИХ режимах (число и перекрашенные индикаторы). 75 = штатный вид игры; выше 75 делает индикаторы/число плотнее (до 100 = максимум), ниже 75 — прозрачнее. Собственное затухание игры при полном заряде накладывается поверх, если не отключить его двумя настройками выше.",
	},
	order_group = {
		en = "Servo-skull order key",
		ru = "Клавиша приказа сервочерепу",
	},
	order_keybind = {
		en = "Order skull to attack aimed enemy",
		ru = "Приказать черепу атаковать цель под прицелом",
	},
	order_keybind_description = {
		en = "A separate key that orders the servo-skull to attack the enemy under your crosshair — the game's own Companion Command tag, on a private bind. Fully self-contained: works regardless of the vanilla 'Companion Command' tag setting and of other mods, so you can keep the normal tag key as a plain tag and use this key only for skull orders. Skitarii only; needs a servo-skull that accepts orders.",
		ru = "Отдельная клавиша, приказывающая сервочерепу атаковать врага под прицелом — это игровой приказ компаньону (Companion Command), вынесенный на свой бинд. Полностью самодостаточна: работает независимо от ванильной настройки метки «Companion Command» и от других модов, так что обычную клавишу метки можно оставить простой меткой, а эту использовать только для приказов черепу. Только для Скитариев; нужен сервочереп, принимающий приказы.",
	},
	order_block_dome = {
		en = "Don't order through a psyker force field",
		ru = "Не приказывать сквозь силовое поле псайкера",
	},
	order_block_dome_description = {
		en = "The servo-skull can't shoot through a psyker force field — either the sphere dome or the flat forward wall (Protectorate shield) — and the game doesn't stop you ordering it to. With this on, the order is refused when the skull->target line actually crosses the shield surface (and an order you already placed on that target is cancelled, since the game keeps retrying it for up to 25s ignoring the field). The line is measured against the real shape of the shield, so shooting past the edge of a wall, or at a target standing inside the same dome as the skull, is allowed. Self-contained — no other mod required.",
		ru = "Сервочереп не может стрелять сквозь силовое поле псайкера — ни через сферический купол, ни через плоскую стену (щит протектората), — а игра не мешает отдать такой приказ. Когда включено — приказ отклоняется, если линия череп→цель действительно пересекает поверхность щита (а уже отданный приказ по этой цели отменяется, поскольку игра повторяет его до 25с, игнорируя поле). Линия проверяется по настоящей форме щита, поэтому выстрел мимо края стены или по цели, стоящей внутри того же купола, что и череп, разрешён. Самодостаточно — другой мод не нужен.",
	},
	order_edge_tolerance = {
		en = "Force field edge tolerance (m)",
		ru = "Допуск у края поля (м)",
	},
	order_edge_tolerance_description = {
		en = "How far inside the force field a shot may still be allowed, in metres. 0 = block from the exact surface of the shield; 0.25 (default) leaves a little slack so an order at the very edge of a wall or dome goes through instead of being refused. Raise it if orders near an edge still get refused; lower it to 0 if the skull accepts orders it then can't actually shoot.",
		ru = "Насколько глубоко внутрь силового поля выстрел ещё считается допустимым, в метрах. 0 = блокировать точно от поверхности щита; 0.25 (по умолчанию) даёт небольшой запас, чтобы приказ у самого края стены или купола проходил, а не отклонялся. Увеличьте, если приказы у края всё ещё отклоняются; поставьте 0, если череп принимает приказы, по которым потом не стреляет.",
	},
	order_block_smoke = {
		en = "Don't order through veteran smoke",
		ru = "Не приказывать сквозь дым ветерана",
	},
	order_block_smoke_description = {
		en = "The servo-skull can't see through a veteran's smoke grenade cloud. With this on, the order is refused when the skull->target line passes through smoke, or the skull itself is standing in it (an order you already placed is cancelled too). Note: this only works while you are the session host — as a client the game doesn't replicate the smoke's line-of-sight data, so the check quietly does nothing. Self-contained — no other mod required.",
		ru = "Сервочереп не видит сквозь облако дымовой гранаты ветерана. Когда включено — приказ отклоняется, если линия череп→цель проходит через дым или сам череп стоит в дыму (уже отданный приказ тоже отменяется). Замечание: работает только пока вы хост сессии — у клиента игра не реплицирует данные видимости дыма, поэтому проверка тихо ничего не делает. Самодостаточно — другой мод не нужен.",
	},
	order_debug = {
		en = "Debug: announce order result",
		ru = "Отладка: сообщать результат приказа",
	},
	order_debug_description = {
		en = "Print a chat line each time you press the order key, saying what happened (order sent / no target / on cooldown / blocked by psyker wall / blocked by psyker dome / blocked by smoke / not Skitarii ...). Use it to check the key is working, then turn it off.",
		ru = "Печатать строку в чат при каждом нажатии клавиши приказа с тем, что произошло (приказ отправлен / нет цели / кулдаун / блок стеной псайкера / блок куполом / блок дымом / не Скитарии ...). Помогает проверить, что клавиша работает; потом выключите.",
	},
	order_cooldown = {
		en = "Re-press delay (sec)",
		ru = "Задержка повторного нажатия (сек)",
	},
	order_cooldown_description = {
		en = "Minimum time between orders from the key above, so mashing or holding it can't spam commands non-stop. 0.1 = almost no limit, 1.0 = at most one order per second. A press with no enemy under your crosshair doesn't start the delay.",
		ru = "Минимальное время между приказами с клавиши выше, чтобы удержание или частые нажатия не спамили команды без остановки. 0.1 = почти без ограничения, 1.0 = не чаще одного приказа в секунду. Нажатие без врага под прицелом задержку не запускает.",
	},
	skull_group = {
		en = "Noospheric Command duration",
		ru = "Длительность Noospheric Command",
	},
	skull_enabled = {
		en = "Show order duration",
		ru = "Показывать длительность приказа",
	},
	skull_enabled_description = {
		en = "While the Noospheric Command servo-skull order is active, show its remaining duration next to the crosshair, mirroring the weapon charge pips on the other side. Re-issuing the order refreshes the indicator automatically. Works both for the untalented base order (player buff) and for the Improved Tagging talent (tracked via the order's smart tag).",
		ru = "Пока действует приказ сервочерепу (Noospheric Command), показывать оставшееся время рядом с прицелом, зеркально ячейкам заряда оружия с другой стороны. Повторная активация приказа автоматически обновляет индикатор. Работает и для базового приказа без талантов (бафф на игроке), и для таланта усиленного тегания (отслеживается по смарт-тагу приказа).",
	},
	skull_always_show = {
		en = "Always visible",
		ru = "Видно постоянно",
	},
	skull_always_show_description = {
		en = "On: the indicator is drawn all the time (only while playing the Skitarii class) — an empty arc (or 0.0 in seconds view) while no order is running. Handy for positioning and colour tuning. Off: only while the servo-skull order is active. Either way, nothing is shown on other classes.",
		ru = "Вкл: индикатор виден всегда (только когда вы играете за класс Скитарии) — пустая дуга (или 0.0 в режиме секунд), пока приказ не действует. Удобно для настройки положения и цветов. Выкл: только пока действует приказ черепу. В любом случае на других классах ничего не показывается.",
	},
	skull_seconds_mode = {
		en = "Seconds instead of the bar",
		ru = "Секунды вместо полоски",
	},
	skull_seconds_mode_description = {
		en = "Off: an arc bar of the same shape as the weapon charge pips that drains as the order runs out. On: a seconds countdown (e.g. 1.4) in the same spot.",
		ru = "Выкл: дуговая полоска той же формы, что и ячейки заряда оружия, убывающая по мере действия приказа. Вкл: отсчёт секунд (например, 1.4) на том же месте.",
	},
	skull_offset_x = {
		en = "Indicator offset X",
		ru = "Смещение индикатора по X",
	},
	skull_offset_x_description = {
		en = "Move the order indicator left (negative) or right (positive), away from the middle of the screen. It still follows the crosshair, it is just drawn this far from it. Applies to the arc and to the seconds readout.",
		ru = "Сдвинуть индикатор приказа влево (минус) или вправо (плюс), от центра экрана. Он по-прежнему следует за прицелом, просто рисуется на таком расстоянии от него. Действует и на дугу, и на отсчёт секунд.",
	},
	skull_offset_y = {
		en = "Indicator offset Y",
		ru = "Смещение индикатора по Y",
	},
	skull_offset_y_description = {
		en = "Move the order indicator up (negative) or down (positive), away from the middle of the screen. Applies to the arc and to the seconds readout.",
		ru = "Сдвинуть индикатор приказа вверх (минус) или вниз (плюс), от центра экрана. Действует и на дугу, и на отсчёт секунд.",
	},
	skull_mirror = {
		en = "Mirror the indicator",
		ru = "Отразить индикатор",
	},
	skull_mirror_description = {
		en = "Which side of the crosshair the arc sits on. Horizontally (default): to the LEFT, mirroring the weapon charges on the right. None: to the right, on top of the weapon charges. Vertically flips the arc upside down. The seconds readout follows the arc's side.",
		ru = "С какой стороны от прицела рисуется дуга. По горизонтали (по умолчанию): СЛЕВА, зеркально зарядам оружия справа. Нет: справа, поверх зарядов оружия. По вертикали — дуга переворачивается. Отсчёт секунд следует за стороной дуги.",
	},
	skull_rotation = {
		en = "Rotate the indicator (degrees)",
		ru = "Поворот индикатора (градусы)",
	},
	skull_rotation_description = {
		en = "Turn the arc around the middle of the indicator: 90 / 180 / 270 move it below / to the other side / above the crosshair. Only affects the arc, not the seconds readout.",
		ru = "Повернуть дугу вокруг центра индикатора: 90 / 180 / 270 — снизу / с другой стороны / сверху от прицела. Действует только на дугу, не на отсчёт секунд.",
	},
	skull_color = {
		en = "Outline colour",
		ru = "Цвет контура",
	},
	skull_color_description = {
		en = "Colour of the arc outline/border. Also used for the seconds countdown text.",
		ru = "Цвет контура (границ) дуги. Также используется для текста отсчёта секунд.",
	},
	skull_outline_opacity = {
		en = "Outline opacity",
		ru = "Непрозрачность контура",
	},
	skull_outline_opacity_description = {
		en = "Opacity of the arc outline/border. Also applies to the seconds countdown text. 100 = fully solid.",
		ru = "Непрозрачность контура (границ) дуги. Также действует на текст отсчёта секунд. 100 = полностью непрозрачно.",
	},
	skull_fill_color = {
		en = "Fill colour",
		ru = "Цвет заливки",
	},
	skull_fill_color_description = {
		en = "Colour of the inner fill of the duration arc, independent of the outline colour.",
		ru = "Цвет внутренней заливки дуги длительности, независимо от цвета контура.",
	},
	skull_fill_opacity = {
		en = "Fill opacity",
		ru = "Непрозрачность заливки",
	},
	skull_fill_opacity_description = {
		en = "Opacity of the inner fill of the duration arc. 100 = fully solid.",
		ru = "Непрозрачность внутренней заливки дуги длительности. 100 = полностью непрозрачно.",
	},
	skull_font_size = {
		en = "Seconds font size",
		ru = "Размер шрифта секунд",
	},
	skull_font_size_description = {
		en = "Size of the seconds countdown text (used when 'Seconds instead of the bar' is on).",
		ru = "Размер текста отсчёта секунд (используется, когда включено «Секунды вместо полоски»).",
	},

	mirror_none = {
		en = "No",
		ru = "Нет",
	},
	mirror_horizontal = {
		en = "Horizontally (other side)",
		ru = "По горизонтали (другая сторона)",
	},
	mirror_vertical = {
		en = "Vertically (upside down)",
		ru = "По вертикали (вверх ногами)",
	},
	mirror_both = {
		en = "Both ways",
		ru = "И так и так",
	},

	color_yellow = {
		en = "Yellow",
		ru = "Жёлтый",
	},
	color_orange = {
		en = "Orange",
		ru = "Оранжевый",
	},

	color_red = {
		en = "Red",
		ru = "Красный",
	},
	color_pink = {
		en = "Pink",
		ru = "Розовый",
	},
	color_purple = {
		en = "Purple",
		ru = "Фиолетовый",
	},
	color_white = {
		en = "White",
		ru = "Белый",
	},
	color_green = {
		en = "Green",
		ru = "Зелёный",
	},
	color_cyan = {
		en = "Cyan",
		ru = "Голубой",
	},
}
