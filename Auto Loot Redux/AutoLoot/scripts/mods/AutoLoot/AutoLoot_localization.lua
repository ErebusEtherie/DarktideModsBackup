return {
	-- ───────────────────── ❀ ─────────────────────
	--  Mod Entry
	-- ───────────────────── ❀ ─────────────────────
	mod_name = {
		en = "Auto Loot",
		ru = "Автосбор лута",
	},
	mod_description = {
		en = "Automatically picks up crafting materials and other loot.",
		es = "Recoge automáticamente materiales de fabricación y otros objetos.",
		ru = "Auto Loot — Автоматически подбирает материалы для крафта и прочий лут.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Aim Gate
	-- ───────────────────── ❀ ─────────────────────
	aim_limit = {
		en = "How closely you must aim",
		es = "Precisión de apuntado necesaria",
		ru = "Точность прицеливания",
	},
	aim_limit_description = {
		en = "An item is only taken when you are pointing within this many centimetres of it. At 75 it takes anything the game offers, the way older versions did.",
		es = "Un objeto solo se recoge cuando apuntas a esta distancia de él en centímetros. En 75 recoge todo lo que el juego ofrece, como hacían las versiones anteriores.",
		ru = "Предмет подбирается, только когда вы целитесь не дальше указанного числа сантиметров от него. При 75 подбирается всё, что предлагает игра, как в прежних версиях.",
	},
	press_delay_seconds = {
		en = "Wait before picking up",
		es = "Espera antes de recoger",
		ru = "Задержка перед подбором",
	},
	press_delay_seconds_description = {
		en = "Holds each pickup until the same item has been in view for this many seconds. 0 takes it the moment you look at it.",
		es = "Retrasa cada recogida hasta que el mismo objeto lleve este número de segundos a la vista. Con 0 se recoge en cuanto lo miras.",
		ru = "Откладывает подбор, пока один и тот же предмет не пробудет в поле зрения указанное число секунд. При 0 подбирается сразу, как только вы на него посмотрите.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Ammo Sliders
	-- ───────────────────── ❀ ─────────────────────
	ammo_clip_threshold = {
		en = "Ammo clip pickup threshold",
		es = "Umbral de recogida de cargadores de munición",
		ru = "Порог подбора малых боеприпасов",
	},
	ammo_clip_threshold_description = {
		en = "Auto-loots a small ammo clip when your spare ammo is at or below this percent of its maximum. Rounds loaded in your weapons don't count, since pickups only refill spare ammo.",
		es = "Recoge automáticamente un cargador pequeño cuando tu munición de reserva está en este porcentaje de su máximo o por debajo. Las balas cargadas en tus armas no cuentan, ya que las recogidas solo rellenan la reserva.",
		ru = "Автоматически подбирает малую обойму, когда запас боеприпасов равен или ниже этого процента от максимума. Заряженные в оружие патроны не учитываются, так как подбор пополняет только запас.",
	},
	ammo_bag_threshold = {
		en = "Ammo bag pickup threshold",
		es = "Umbral de recogida de bolsas de munición",
		ru = "Порог подбора больших боеприпасов",
	},
	ammo_bag_threshold_description = {
		en = "Auto-loots a large ammo bag when your spare ammo is at or below this percent of its maximum. Rounds loaded in your weapons don't count, since pickups only refill spare ammo.",
		es = "Recoge automáticamente una bolsa de munición grande cuando tu munición de reserva está en este porcentaje de su máximo o por debajo. Las balas cargadas en tus armas no cuentan, ya que las recogidas solo rellenan la reserva.",
		ru = "Автоматически подбирает большую сумку с патронами, когда запас боеприпасов равен или ниже этого процента от максимума. Заряженные в оружие патроны не учитываются, так как подбор пополняет только запас.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Groups & Stimms
	-- ───────────────────── ❀ ─────────────────────
	other_group = {
		en = "Other",
		es = "Otros",
		ru = "Прочее",
	},
	stimms_group = {
		en = "Stimms",
		es = "Estimulantes",
		ru = "Стимуляторы",
	},
	pickup_stimms = {
		en = "Automatically pick up stimms",
		es = "Recoger automáticamente estimulantes",
		ru = "Автоматически подбирать стимуляторы",
	},
	pickup_stimms_description = {
		en = "Master switch for all stimm auto-looting. When off, none of the stimm settings below have any effect.",
		es = "Interruptor principal para la recogida automática de estimulantes. Si está desactivado, ninguna de las opciones siguientes tendrá efecto.",
		ru = "Основной включатель для автоматического подбора стимуляторов. Если выключен, никакие настройки стимуляторов ниже не действуют.",
	},
	per_class_stimms = {
		en = "Per-class priorities",
		es = "Prioridades por clase",
		ru = "Приоритеты для каждого класса",
	},
	per_class_stimms_description = {
		en = "When off, one shared list is used for every class, reset to the default priorities (Med, Combat, Celerity, Concentration). Per-class lists are kept and come back when re-enabled.",
		es = "Cuando está desactivado, todas las clases comparten una única lista con las prioridades predeterminadas (Médico, Combate, Celeridad y Concentración). Las listas por clase se conservan y se restauran al volver a activarlo.",
		ru = "Если выключено, используется один общий список для всех классов, сброшенный к приоритетам по умолчанию (Мед, Боевой, Скоростной, Концентрации). Списки для каждого класса сохраняются и возвращаются при повторном включении.",
	},
	stimm_med_enabled = {
		en = "{#color(80,255,120)}Med Stimm{#reset()}",
		es = "{#color(80,255,120)}Estimulante Médico{#reset()}",
		ru = "{#color(80,255,120)}Лечебный стимулятор{#reset()}",
	},
	stimm_med_enabled_description = {
		en = "The healing stimm. Restores 25% of max health or one health segment, whichever is higher, and heals corruption damage. Med stimms cannot be used on targets without health or corruption damage.",
		es = "El estimulante curativo. Restaura un 25 % de la salud máxima o un segmento de salud, lo que sea mayor, y cura el daño de corrupción. No puede usarse en objetivos sin daño de salud o corrupción.",
		ru = "Лечебный стимулятор. Восстанавливает 25% максимального здоровья или один сегмент здоровья, в зависимости от того, что больше, и излечивает повреждения от порчи. Лечебные стимуляторы нельзя применить к целям без потери здоровья или порчи.",
	},
	stimm_med_rank = {
		en = "Med Stimm priority",
		es = "Prioridad del estimulante Médico",
		ru = "Приоритет лечебного стимулятора",
	},
	stimm_med_rank_description = {
		en = "1 is the highest priority and 4 the lowest. A stimm with a lower number is swapped in over a held stimm with a higher number. Equal priority never swaps.",
		es = "1 es la prioridad más alta y 4 la más baja. Un estimulante con un número menor sustituirá al que lleves equipado si este tiene una prioridad inferior. Si ambas prioridades son iguales, no se sustituirá.",
		ru = "1 — наивысший приоритет, 4 — наинизший. Стимулятор с меньшим номером заменяет удерживаемый стимулятор с большим номером. При равном приоритете замена не происходит.",
	},
	stimm_combat_enabled = {
		en = "{#color(255,90,40)}Combat Stimm{#reset()}",
		es = "{#color(255,90,40)}Estimulante de Combate{#reset()}",
		ru = "{#color(255,90,40)}Боевой стимулятор{#reset()}",
	},
	stimm_combat_enabled_description = {
		en = "The damage stimm. For 15 seconds: +25% Damage & Stagger power. +25% Rending (armour penetration). -33% Peril generation.",
		es = "El estimulante de daño. Durante 15 segundos: +25 % de daño y poder de tambaleo, +25 % de perforación de armadura y -33 % de generación de peligro.",
		ru = "Боевой стимулятор. На 15 секунд: +25% урона и силы оглушения. +25% пробивания брони. -33% накопления опасности.",
	},
	stimm_combat_rank = {
		en = "Combat Stimm priority",
		es = "Prioridad del estimulante de Combate",
		ru = "Приоритет боевого стимулятора",
	},
	stimm_combat_rank_description = {
		en = "1 is the highest priority and 4 the lowest. A stimm with a lower number is swapped in over a held stimm with a higher number. Equal priority never swaps.",
		es = "1 es la prioridad más alta y 4 la más baja. Un estimulante con un número menor sustituirá al que lleves equipado si este tiene una prioridad inferior. Si ambas prioridades son iguales, no se sustituirá.",
		ru = "1 — наивысший приоритет, 4 — наинизший. Стимулятор с меньшим номером заменяет удерживаемый стимулятор с большим номером. При равном приоритете замена не происходит.",
	},
	stimm_celerity_enabled = {
		en = "{#color(70,170,255)}Celerity Stimm{#reset()}",
		es = "{#color(70,170,255)}Estimulante de Celeridad{#reset()}",
		ru = "{#color(70,170,255)}Стимулятор скорости{#reset()}",
	},
	stimm_celerity_enabled_description = {
		en = "The speed stimm. For 15 seconds: +15% Reload speed. +20% Attack speed. +25% Peril Quell speed. -25% Stamina cost for Pushing/Blocking & -50% Sprint cost. +25% faster speed for Plasma guns, Psyker Staves, Brain Burst/Smite/Assail.",
		es = "El estimulante de velocidad. Durante 15 segundos: +15 % de velocidad de recarga, +20 % de velocidad de ataque, +25 % de velocidad para disipar peligro, -25 % de coste de aguante al empujar y bloquear, -50 % de coste al esprintar y +25 % de velocidad con rifles de plasma, bastones de psíquico, Estallido cerebral, Castigo y Asalto.",
		ru = "Стимулятор скорости. На 15 секунд: +15% скорости перезарядки. +20% скорости атаки. +25% скорости подавления опасности. -25% стоимости выносливости для толчков/блоков и -50% стоимости спринта. +25% скорости зарядки для плазменных пушек, посохов псайкера, «Взрыва мозга»/«Кара»/«Нападение».",
	},
	stimm_celerity_rank = {
		en = "Celerity Stimm priority",
		es = "Prioridad del estimulante de Celeridad",
		ru = "Приоритет стимулятора скорости",
	},
	stimm_celerity_rank_description = {
		en = "1 is the highest priority and 4 the lowest. A stimm with a lower number is swapped in over a held stimm with a higher number. Equal priority never swaps.",
		es = "1 es la prioridad más alta y 4 la más baja. Un estimulante con un número menor sustituirá al que lleves equipado si este tiene una prioridad inferior. Si ambas prioridades son iguales, no se sustituirá.",
		ru = "1 — наивысший приоритет, 4 — наинизший. Стимулятор с меньшим номером заменяет удерживаемый стимулятор с большим номером. При равном приоритете замена не происходит.",
	},
	stimm_concentration_enabled = {
		en = "{#color(255,191,0)}Concentration Stimm{#reset()}",
		es = "{#color(255,191,0)}Estimulante de Concentración{#reset()}",
		ru = "{#color(255,191,0)}Стимулятор концентрации{#reset()}",
	},
	stimm_concentration_enabled_description = {
		en = "The ability stimm. For 15 seconds: +300% Combat Ability Cooldown Regeneration speed. Roughly 4x the normal rate. Bringing class abilities back quicker.",
		es = "El estimulante de habilidad. Durante 15 segundos: +300 % de velocidad de regeneración del tiempo de reutilización de la habilidad de combate, aproximadamente 4 veces más rápido de lo normal.",
		ru = "Стимулятор способностей. На 15 секунд: +300% скорости восстановления боевых способностей. Примерно в 4 раза быстрее обычной скорости. Позволяет быстрее использовать классовые способности.",
	},
	stimm_concentration_rank = {
		en = "Concentration Stimm priority",
		es = "Prioridad del estimulante de Concentración",
		ru = "Приоритет стимулятора концентрации",
	},
	stimm_concentration_rank_description = {
		en = "1 is the highest priority and 4 the lowest. A stimm with a lower number is swapped in over a held stimm with a higher number. Equal priority never swaps.",
		es = "1 es la prioridad más alta y 4 la más baja. Un estimulante con un número menor sustituirá al que lleves equipado si este tiene una prioridad inferior. Si ambas prioridades son iguales, no se sustituirá.",
		ru = "1 — наивысший приоритет, 4 — наинизший. Стимулятор с меньшим номером заменяет удерживаемый стимулятор с большим номером. При равном приоритете замена не происходит.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Ammo
	-- ───────────────────── ❀ ─────────────────────
	pickup_ammo = {
		en = "Automatically pick up ammo",
		es = "Recoger automáticamente munición",
		ru = "Автоматически подбирать боеприпасы",
	},
	auto_ammo_thresholds = {
		en = "Automatic ammo thresholds",
		es = "Umbrales de munición automáticos",
		ru = "Порог автоподбора боеприпасов",
	},
	auto_ammo_thresholds_description = {
		en = "Takes an ammo pickup only when the full amount fits into your spare ammo, so not a single round is wasted, and ignores the two sliders below. Havoc missions that reduce ammo pickups are accounted for automatically, so there is nothing to change when switching between Havoc and normal missions. Turn this off to go back to your own values.",
		es = "Recoge munición solo cuando la cantidad completa cabe en tu munición de reserva, sin desperdiciar ni una sola bala, ignorando los dos controles de abajo. Las misiones de Havoc que reducen la munición recogida se tienen en cuenta automáticamente, así que no hay nada que cambiar al alternar entre Havoc y misiones normales. Desactiva esta opción para volver a tus propios valores.",
		ru = "Подбирает боеприпасы только тогда, когда полный объём помещается в ваш запас, чтобы ни один патрон не был потрачен впустую, и игнорирует два ползунка ниже. Миссии Хавока, уменьшающие количество подбираемых боеприпасов, учитываются автоматически, поэтому при переключении между Хавоком и обычными миссиями ничего менять не нужно. Отключите эту опцию, чтобы вернуться к вашим собственным значениям.",
	},
	show_auto_ammo_threshold_notifications = {
		en = "Show automatic thresholds at mission start",
		es = "Mostrar los umbrales automáticos al iniciar la misión",
		ru = "Показывать пороги подбора в начале миссии",
	},
	show_auto_ammo_threshold_notifications_description = {
		en = "Prints the two automatic thresholds to your chat window when a mission begins. Only you see them. Has no effect unless Automatic ammo thresholds is on.",
		es = "Muestra los dos umbrales automáticos en tu ventana de chat al comenzar una misión. Solo tú los ves. No tiene efecto si los umbrales de munición automáticos están desactivados.",
		ru = "Выводит два порога подбора в окно чата в начале миссии. Видите их только вы. Не действует, если автоматические пороги боеприпасов отключены.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Loot & Chests
	-- ───────────────────── ❀ ─────────────────────
	pickup_materials = {
		en = "Automatically pick up crafting materials",
		es = "Recoger automáticamente materiales de fabricación",
		ru = "Автоматически подбирать материалы для крафта",
	},
	pickup_expedition_materials = {
		en = "Automatically pick up expedition materials",
		es = "Recoger automáticamente materiales de expedición",
		ru = "Автоматически подбирать материалы экспедиций",
	},
	pickup_event_items = {
		en = "Automatically pick up event items",
		es = "Recoger automáticamente objetos de evento",
		ru = "Автоматически подбирать предметы событий",
	},
	pickup_event_items_description = {
		en = "Picks up live event collectibles such as the Tainted, Defiled, and Corrupted Relics.",
		es = "Recoge los coleccionables de los eventos en curso, como las Reliquias Mancilladas, Profanadas y Corruptas.",
		ru = "Подбирает коллекционные предметы живых событий, такие как Испорченные, Осквернённые и Порченные реликвии.",
	},
	open_chests = {
		en = "Automatically open chests",
		es = "Abrir automáticamente los cofres",
		ru = "Автоматически открывать сундуки",
	},
	pickup_crates = {
		en = "Automatically pick up deployable crates",
		es = "Recoger automáticamente cajas desplegables",
		ru = "Автоматически подбирать раскладываемые ящики",
	},
	pickup_crates_description = {
		en = "Only picks up crates if you don't already have one.",
		es = "Solo recoge cajas si no llevas ya una.",
		ru = "Подбирает ящики, только если у вас ещё нет такого.",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Grenades
	-- ───────────────────── ❀ ─────────────────────
	pickup_grenades = {
		en = "Automatically pick up grenades",
		es = "Recoger automáticamente granadas",
		ru = "Автоматически подбирать гранаты",
	},
	grenades_threshold = {
		en = "Grenade pickup threshold",
		es = "Umbral de recogida de granadas",
		ru = "Порог подбора гранат",
	},
	grenades_threshold_description = {
		en = "Threshold of minimum remaining grenades to auto-loot grenades.",
		es = "Cantidad mínima de granadas restantes a partir de la cual se recogen automáticamente.",
		ru = "Порог минимального остатка гранат для автоматического подбора гранат.",
	},
	grenadesammo_group = {
		en = "Grenades/Ammo",
		es = "Granadas/Munición",
		ru = "Гранаты/Боеприпасы",
	},
}
