--[[
	Localization. NOTE: DMF pushes every string through string.format, so a
	literal percent sign must be written as "%%" (it is formatted exactly once).
]]

local version = "0.1.1"

return {
	mod_name = {
		en = "DT Realms Ghost Host - invisible Realms host",
		ru = "DT Realms Ghost Host - невидимый хост Realms",
	},
	mod_description = {
		en = "Lets the Realms listen-server host play as an invisible spectator: he never spawns a body, so enemies ignore him, lifts and the extraction airlock open for the guests alone, and the mission is lost exactly when the real squad wipes. Meant for hosting on a spare machine and joining it as a normal client. Only the host needs this mod for the gameplay part; guests may run it to keep the ghost out of the team HUD. Version: " .. version,
		ru = "Позволяет хосту Realms играть невидимым наблюдателем: тело не спавнится, враги его не видят, лифты и шлюз эвакуации открываются от одних гостей, а миссия проваливается ровно тогда, когда полёг реальный отряд. Сделано для хостинга на отдельной машине с подключением к ней обычным клиентом. Для геймплейной части мод нужен только хосту; гостям - лишь чтобы призрак не занимал панель в HUD команды. Версия: " .. version,
	},

	camera_mode = {
		en = "Host camera",
		ru = "Камера хоста",
	},
	camera_mode_description = {
		en = "Static: the camera stays where the level put it and the game reports no 3D camera - the cheapest state for the host machine, because the loading overlay it shows disables the game world entirely. That overlay also swallows the vanilla Escape, which is what the two options below are for. Spectate: follow the squad like a dead player, switch target with the spectate key.",
		ru = "Статичная: камера остаётся там, где её создал уровень, игра считает, что 3D-камеры нет - самый лёгкий режим для машины хоста, потому что показанный при этом оверлей загрузки полностью отключает рендер мира. Он же съедает ванильный Esc - для этого есть две опции ниже. Наблюдение: следить за отрядом как мёртвый игрок, цель переключается клавишей наблюдения.",
	},
	camera_static = {
		en = "Static (cheapest)",
		ru = "Статичная (дешевле всего)",
	},
	camera_spectate = {
		en = "Spectate the squad",
		ru = "Наблюдать за отрядом",
	},

	esc_opens_menu = {
		en = "Escape opens the system menu on the blank screen",
		ru = "Esc открывает системное меню на пустом экране",
	},
	esc_opens_menu_description = {
		en = "Without a camera the game shows its loading overlay, and while any view is up the vanilla hotkey cannot open the system menu - so the host cannot stop the server without killing the game. With this on, the mod opens the menu itself on the same key. Leave it on unless you disable the overlay below.",
		ru = "Без камеры игра показывает оверлей загрузки, а пока открыт любой экран, ванильный хоткей не может открыть системное меню - хост не может остановить сервер, не убив игру. С этой опцией мод открывает меню сам по той же клавише. Выключать только если включена опция ниже.",
	},

	disable_loading_overlay = {
		en = "Disable the loading overlay (renders the world)",
		ru = "Отключить оверлей загрузки (мир рендерится)",
	},
	disable_loading_overlay_description = {
		en = "Report a proper 3D camera, so the loading overlay never appears and Escape behaves exactly like vanilla. The host machine then renders the world again from the camera's spawn position, which costs far more than the blank screen - use it only if the menu still refuses to open.",
		ru = "Сообщать игре, что 3D-камера есть: оверлей загрузки не появляется, Esc работает ровно как в ванили. Машина хоста при этом снова рендерит мир из точки создания камеры - это заметно дороже пустого экрана; включать, только если меню всё равно не открывается.",
	},

	hide_ghost_panel = {
		en = "Hide the ghost from the team HUD",
		ru = "Скрывать призрака в HUD команды",
	},
	hide_ghost_panel_description = {
		en = "The team panel only has four slots, so in a five-member session the ghost can take the slot of a living team mate. Works only for the machine it runs on - install the mod on the guests too if you want their HUD clean.",
		ru = "В панели команды всего четыре слота, поэтому в сессии на пять человек призрак может занять место живого союзника. Работает только на той машине, где включён, - поставь мод и гостям, если нужен чистый HUD у них.",
	},

	bot_target_ignores_ghost = {
		en = "Do not count the ghost in Realms' bot target",
		ru = "Не учитывать призрака в цели по ботам Realms",
	},
	bot_target_ignores_ghost_description = {
		en = "Realms fills bots up to its \"Bot fill target\" setting and counts the ghost host as a player. With this on, the target means the number of bodies you want in the squad.",
		ru = "Realms добирает ботов до своей настройки \"Bot fill target\" и считает призрака игроком. С этой опцией цель означает число реальных тел в отряде.",
	},

	announce_on_start = {
		en = "Announce in chat when ghosting starts",
		ru = "Сообщать в чат о включении призрака",
	},
	announce_on_start_description = {
		en = "One line in the host's own chat log per mission, plus a warning when Realms' player limit is too low for four guests plus the host.",
		ru = "Одна строка в чат-лог хоста за миссию плюс предупреждение, если лимит игроков Realms мал для четырёх гостей и хоста.",
	},

	allow_experimental_modes = {
		en = "Allow in Survival / Expedition (untested)",
		ru = "Разрешить в Survival / Expedition (не проверено)",
	},
	allow_experimental_modes_description = {
		en = "Those modes hand out mission buffs and wait for a choice from every human player, which a host without a body cannot make - the run may stall on the buff screen. Normal missions and Havoc do not need this.",
		ru = "Эти режимы выдают mission buffs и ждут выбора от каждого игрока-человека, а хост без тела выбрать не может - забег может застрять на экране баффов. Обычным миссиям и Havoc эта опция не нужна.",
	},

	cmd_description = {
		en = "Ghost Host: status, \"menu\" to open the system menu, or \"join\" / \"ghost\" to leave and re-enter ghost mode",
		ru = "Ghost Host: статус, \"menu\" - открыть системное меню, \"join\" / \"ghost\" - выйти из режима призрака и вернуться в него",
	},

	msg_menu_opened = {
		en = "[Ghost Host] System menu opened.",
		ru = "[Ghost Host] Системное меню открыто.",
	},
	msg_menu_already_open = {
		en = "[Ghost Host] The system menu is already open (or the UI is unavailable).",
		ru = "[Ghost Host] Системное меню уже открыто (или UI недоступен).",
	},

	msg_ghost_active = {
		en = "[Ghost Host] Ghosting: no body spawned, the squad plays without you.",
		ru = "[Ghost Host] Призрак активен: тело не заспавнено, отряд играет без тебя.",
	},
	msg_max_players_low = {
		en = "[Ghost Host] Realms player limit is %s - that leaves only %s guest slots. Raise \"Max players\" in the Realms options.",
		ru = "[Ghost Host] Лимит игроков Realms = %s, гостям остаётся мест: %s. Подними \"Max players\" в настройках Realms.",
	},
	msg_suspended = {
		en = "[Ghost Host] Ghosting suspended - you will be spawned like any dead player (a rescue cage). Use \"/ghosthost ghost\" to go back.",
		ru = "[Ghost Host] Призрак приостановлен - тебя заспавнит как обычного мёртвого игрока (клетка для спасения). Вернуться: \"/ghosthost ghost\".",
	},
	msg_resumed = {
		en = "[Ghost Host] Ghosting resumed.",
		ru = "[Ghost Host] Призрак снова включён.",
	},
	msg_resumed_with_body = {
		en = "[Ghost Host] Ghosting resumed - it applies from your next death or mission, your current body stays.",
		ru = "[Ghost Host] Призрак снова включён - подействует со следующей смерти или миссии, текущее тело остаётся.",
	},

	msg_status_session = {
		en = "[Ghost Host] Realms host: %s | game mode: %s",
		ru = "[Ghost Host] Хост Realms: %s | режим: %s",
	},
	msg_status_ghost = {
		en = "[Ghost Host] Ghosting now: %s | suspended: %s",
		ru = "[Ghost Host] Призрак сейчас: %s | приостановлен: %s",
	},
	msg_status_squad = {
		en = "[Ghost Host] Humans in session: %s | players with a body: %s | Realms max players: %s",
		ru = "[Ghost Host] Людей в сессии: %s | игроков с телом: %s | лимит Realms: %s",
	},
	msg_status_body = {
		en = "[Ghost Host] I have a body: %s",
		ru = "[Ghost Host] У меня есть тело: %s",
	},
}
