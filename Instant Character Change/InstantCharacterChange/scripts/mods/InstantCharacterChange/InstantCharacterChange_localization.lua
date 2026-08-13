return {
	mod_name = {
		en = "Instant Character Change",
		ru = "Мгновенная смена персонажа",
	},
	mod_description = {
		en = "Switch operatives instantly from the Esc menu, without reloading the Mourningstar. Drag entries in the panel to reorder them.",
		ru = "Мгновенная смена оперативника через Esc-меню, без перезагрузки Морнингстар. Записи в панели можно перетаскивать, меняя порядок.",
	},
	command_description = {
		en = "Switch character for the next mission (no Mourningstar reload)",
		ru = "Сменить персонажа для следующей миссии (без перезагрузки Морнингстар)",
	},
	chat_messages_enabled = {
		en = "Chat messages",
		ru = "Сообщения в чате",
	},
	chat_messages_enabled_tooltip = {
		en = "Shows mod messages in the chat when switching characters.",
		ru = "Показывает сообщения мода в чате при смене персонажа.",
	},
	party_announce_enabled = {
		en = "Announce switch in party chat",
		ru = "Сообщать группе о смене персонажа",
	},
	party_announce_enabled_tooltip = {
		en = "Sends a short party chat message when you switch characters (e.g. \"Switched character: Ogryn -> Psyker\"), so your party sees it right away. Nothing is sent when you are not in a party.",
		ru = "Отправляет короткое сообщение в чат группы при смене персонажа (например, \"Switched character: Ogryn -> Psyker\"), чтобы группа сразу это видела. Вне группы ничего не отправляется.",
	},
	party_announce_color = {
		en = "Message color",
		ru = "Цвет сообщения",
	},
	party_announce_color_tooltip = {
		en = "Highlights the two class names in the announcement with this color; the rest of the message stays default. \"None\" sends plain white text.",
		ru = "Подсвечивает этим цветом названия обоих классов в сообщении; остальной текст остаётся обычным. \"Без цвета\" — весь текст белый.",
	},
	-- The dropdown labels are tinted with their own color via {#color()}
	-- markup (rendered by the engine in any text pass, options menu
	-- included), so the picker previews exactly what the chat will show.
	-- KEEP THE RGB VALUES IN SYNC with ANNOUNCE_COLORS in the main file.
	party_color_none = {
		en = "None (plain)",
		ru = "Без цвета",
	},
	party_color_amber = {
		en = "{#color(235,185,90)}Amber{#reset()}",
		ru = "{#color(235,185,90)}Янтарный{#reset()}",
	},
	party_color_steel_blue = {
		en = "{#color(130,180,215)}Steel blue{#reset()}",
		ru = "{#color(130,180,215)}Стальной синий{#reset()}",
	},
	party_color_green = {
		en = "{#color(80,220,80)}Green{#reset()}",
		ru = "{#color(80,220,80)}Зелёный{#reset()}",
	},
	party_color_red = {
		en = "{#color(235,95,80)}Red{#reset()}",
		ru = "{#color(235,95,80)}Красный{#reset()}",
	},
	party_color_purple = {
		en = "{#color(190,125,220)}Purple{#reset()}",
		ru = "{#color(190,125,220)}Фиолетовый{#reset()}",
	},
	diagnostics_enabled = {
		en = "Write diagnostic log",
		ru = "Записывать диагностический лог",
	},
	diagnostics_enabled_tooltip = {
		en = "Writes a diagnostic log to AppData\\Fatshark\\Darktide\\InstantCharacterChange.log.",
		ru = "Пишет диагностический лог в AppData\\Fatshark\\Darktide\\InstantCharacterChange.log.",
	},
	msg_character_list = {
		en = "Your characters:",
		ru = "Твои персонажи:",
	},
	msg_current_marker = {
		en = "current",
		ru = "текущий",
	},
	msg_usage_hint = {
		en = "Usage: /switchchar <name|class|number>, /switchchar cancel",
		ru = "Использование: /switchchar <имя|класс|номер>, /switchchar cancel",
	},
	msg_armed_status = {
		en = "Switch armed:",
		ru = "Переключение взведено:",
	},
	msg_armed_hint = {
		en = "Now join a Party Finder group or start a mission — you will connect to it as that character. The Party Finder will show you with the new class within a second. (/switchchar cancel to revert.)",
		ru = "Теперь вступай в группу через Party Finder или запускай миссию — ты подключишься к ней этим персонажем. Party Finder покажет тебя с новым классом в течение секунды. (/switchchar cancel — отменить.)",
	},
	msg_already_that_character = {
		en = "You are already playing that character.",
		ru = "Ты уже играешь этим персонажем.",
	},
	msg_nothing_armed = {
		en = "No switch is armed.",
		ru = "Переключение не взведено.",
	},
	msg_in_matchmaking = {
		en = "Cannot switch while matchmaking is in progress.",
		ru = "Нельзя менять персонажа во время подбора игры.",
	},
	msg_departing_blocked = {
		en = "Cannot switch while the group is departing to a mission — the server already reserved your slot for the current character; switching now would get you kicked on mission load. Try again after the mission (or if the departure gets cancelled).",
		ru = "Нельзя менять персонажа, пока группа отправляется на миссию — сервер уже зарезервировал твой слот за текущим персонажем, смена сейчас закончится киком при загрузке миссии. Попробуй после миссии (или если отправка сорвётся).",
	},
	msg_departing_cancel_blocked = {
		en = "Cannot cancel now — the matchmaking ticket already went out with the armed character, so you will connect to the mission as it. Cancelling unlocks again if the queue or departure gets cancelled.",
		ru = "Нельзя отменить сейчас — тикет матчмейкинга уже ушёл со взведённым персонажем, и в миссию ты подключишься им. Отмена снова станет доступна, если очередь или отправка сорвётся.",
	},
	msg_start_vote_blocked = {
		en = "Cannot switch while the group is accepting a mission — queue tickets are sent as members accept, and switching now would get you kicked on mission load. Try again if the vote fails (or after the mission).",
		ru = "Нельзя менять персонажа, пока группа принимает миссию — тикеты очереди уходят по мере принятия, и смена сейчас закончится киком при загрузке миссии. Попробуй снова, если голосование сорвётся (или после миссии).",
	},
	msg_hub_only = {
		en = "Character switching only works on the Mourningstar or in the Psykhanium.",
		ru = "Смена персонажа работает только на Морнингстар или в Психаниуме.",
	},
	command_description_now = {
		en = "Switch character instantly",
		ru = "Сменить персонажа мгновенно",
	},
	panel_offset_x = {
		en = "Panel: horizontal offset",
		ru = "Панель: сдвиг по горизонтали",
	},
	panel_offset_x_tooltip = {
		en = "Moves the panel left (negative) or right (positive).",
		ru = "Сдвигает панель влево (минус) или вправо (плюс).",
	},
	panel_offset_y = {
		en = "Panel: vertical offset",
		ru = "Панель: сдвиг по вертикали",
	},
	panel_offset_y_tooltip = {
		en = "Moves the panel up (negative) or down (positive).",
		ru = "Сдвигает панель вверх (минус) или вниз (плюс).",
	},
	panel_width = {
		en = "Panel: width",
		ru = "Панель: ширина",
	},
	panel_width_tooltip = {
		en = "Panel width in pixels.",
		ru = "Ширина панели в пикселях.",
	},
	panel_scale = {
		en = "Panel: scale, percent",
		ru = "Панель: масштаб, проценты",
	},
	panel_scale_tooltip = {
		en = "Scales the panel contents (row height, names, class icons).",
		ru = "Масштабирует содержимое панели (высоту строк, имена, иконки классов).",
	},
	panel_show_level = {
		en = "Panel: show level",
		ru = "Панель: показывать уровень",
	},
	panel_show_level_tooltip = {
		en = "Show the character level in the Esc-menu panel entries. Turn off for a cleaner look.",
		ru = "Показывать уровень персонажа в строках панели Esc-меню. Отключите для более чистого вида.",
	},
	panel_title = {
		en = "OPERATIVES",
		ru = "ОПЕРАТИВНИКИ",
	},
	panel_level_short = {
		en = "lvl",
		ru = "ур.",
	},
	panel_current_tag = {
		en = "current",
		ru = "текущий",
	},
	msg_hub_swapped = {
		en = "Switched (data only): your visible character stays the old one until the next travel, but the inventory/talents now open for the NEW character — set up the build, then queue. The next mission spawns you as the new character.",
		ru = "Переключено (по данным): внешне ты останешься старым персонажем до следующего перемещения, но инвентарь и таланты теперь открываются за НОВОГО — настрой билд и запускай миссию. В миссии заспавнишься уже новым персонажем.",
	},
	msg_live_switching = {
		en = "Switching right here — you will respawn as the new character in a few seconds...",
		ru = "Переключаю прямо здесь — через пару секунд ты переспавнишься новым персонажем...",
	},
	msg_fetch_failed = {
		en = "Could not fetch your character list from the backend — try again in a moment.",
		ru = "Не удалось получить список персонажей с бэкенда — попробуй ещё раз через пару секунд.",
	},
}
