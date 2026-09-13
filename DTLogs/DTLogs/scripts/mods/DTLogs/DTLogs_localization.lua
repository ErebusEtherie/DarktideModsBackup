return {
	mod_name = {
		en = "DTLogs",
		ru = "DTLogs",
	},
	mod_description = {
		en = "Records a JSONL timeline of combat events, player profiles, talents, and loadouts.",
		ru = "Записывает JSONL-лог боевых событий, профилей игроков, талантов и экипировки.",
	},
	auto_upload_completed_missions = {
		en = "Automatically upload mission logs to DTLogs.com",
		ru = "Автоматически загружать логи миссий на DTLogs.com",
	},
	auto_upload_completed_missions_tooltip = {
		en = "After a mission log is finalized, upload eligible JSONL files to DTLogs.com silently in the background. Failed uploads remain queued and are retried automatically. The local file is always kept. Requires Windows 10/11 curl.exe. Upload processes are launched without a console window.",
		ru = "После завершения миссии незаметно загружает подходящий JSONL-файл на DTLogs.com в фоне. Неудачные загрузки остаются в очереди и повторяются автоматически. Локальный файл всегда сохраняется. Требуется curl.exe из Windows 10/11. Процессы загрузки запускаются без консольного окна.",
	},
	auto_upload_scope = {
		en = "Which missions should be uploaded",
		ru = "Какие миссии загружать на сервер",
	},
	auto_upload_scope_successful_only = {
		en = "Successful missions only (recommended)",
		ru = "Только успешно завершённые миссии (рекомендуется)",
	},
	auto_upload_scope_all_missions = {
		en = "All completed missions (successes and failures)",
		ru = "Все завершённые миссии (успешные и неуспешные)",
	},
	auto_upload_scope_tooltip = {
		en = "Default: successful missions only. DTLogs treats Darktide's real mission outcome 'won' as a successful completion (and also accepts 'success' as a compatibility alias). Other outcomes are still saved locally but are not automatically uploaded when this mode is selected. Already queued reports continue their existing retry cycle.",
		ru = "По умолчанию: только успешные миссии. Успешным завершением считается реальный исход миссии Darktide 'won' (значение 'success' также принимается для совместимости). При других исходах лог всё равно сохраняется локально, но автоматически на сервер не отправляется. Уже находящиеся в очереди отчёты продолжают свой текущий цикл повторных попыток.",
	},
	account_link_status = {
		en = "DTLogs account connection status",
		ru = "Статус подключения к аккаунту DTLogs",
	},
	account_link_status_tooltip = {
		en = "Shows whether this addon currently has a DTLogs account upload key. This dropdown is informational; DTLogs restores the actual connection state if it is changed manually.",
		ru = "Показывает, сохранён ли в аддоне ключ загрузки аккаунта DTLogs. Этот список информационный: если изменить его вручную, DTLogs восстановит фактический статус подключения.",
	},
	account_link_status_linked = {
		en = "Linked",
		ru = "Подключено",
	},
	account_link_status_not_linked = {
		en = "Not linked",
		ru = "Не подключено",
	},
	account_link_action = {
		en = "Link addon to a DTLogs account",
		ru = "Привязать аддон к аккаунту DTLogs",
	},
	account_link_action_none = {
		en = "No action",
		ru = "Не выполнять действие",
	},
	account_link_action_show_command = {
		en = "Show account-link command in chat",
		ru = "Показать команду привязки аккаунта в чате",
	},
	account_link_action_tooltip = {
		en = "Compatibility mode for older DMF versions: select this to print the /dtlogs_link <upload-key-or-link> command instructions in chat. The command accepts both the raw dtl_up_... key and copied text/link containing that key.",
		ru = "Режим совместимости со старыми версиями DMF: выберите этот пункт, чтобы вывести в чат инструкцию для команды /dtlogs_link <ключ-или-ссылка>. Команда принимает как сам ключ dtl_up_..., так и скопированный текст/ссылку, содержащие этот ключ.",
	},
	account_link_input = {
		en = "Link to DTLogs account — paste upload key or link",
		ru = "Привязать аккаунт DTLogs — вставьте ключ или ссылку",
	},
	account_link_input_tooltip = {
		en = "Paste either the raw dtl_up_... upload key or a copied link/text containing that key, then confirm the text field. The full key is stored locally and is never written into mission JSONL files.",
		ru = "Вставьте либо сам ключ загрузки dtl_up_..., либо скопированную ссылку/текст, содержащие этот ключ, затем подтвердите поле ввода. Полный ключ хранится только локально и никогда не записывается в JSONL-файлы миссий.",
	},
	account_unlink_action = {
		en = "Disconnect addon from DTLogs account",
		ru = "Отключить аддон от аккаунта DTLogs",
	},
	account_unlink_keep = {
		en = "Keep current account connection",
		ru = "Оставить текущее подключение",
	},
	account_unlink_disconnect = {
		en = "DISCONNECT — I understand the upload key must be entered again to reconnect",
		ru = "ОТКЛЮЧИТЬ — я понимаю, что для повторного подключения ключ придётся ввести заново",
	},
	account_unlink_action_tooltip = {
		en = "Warning: disconnecting removes the locally saved DTLogs upload key. To link the addon to this account again, you must enter the upload key again. Unlinked automatic uploads use the anonymous upload endpoint.",
		ru = "Внимание: отключение удалит локально сохранённый ключ загрузки DTLogs. Чтобы снова привязать аддон к этому аккаунту, ключ потребуется ввести заново. После отключения автоматические загрузки выполняются анонимно.",
	},
	startup_upload_successful_only = {
		en = "DTLogs: Online log upload is enabled for successful missions only.",
		ru = "DTLogs: Онлайн-загрузка логов включена только для успешно завершённых миссий.",
	},
	startup_upload_all_missions = {
		en = "DTLogs: Online log upload is enabled for all completed missions.",
		ru = "DTLogs: Онлайн-загрузка логов включена для всех завершённых миссий.",
	},
	startup_upload_disabled = {
		en = "DTLogs: Online log upload is disabled. Mission logs will be saved locally only.",
		ru = "DTLogs: Онлайн-загрузка логов отключена. Логи миссий будут сохраняться только локально.",
	},
	startup_account_linked = {
		en = "DTLogs account: linked",
		ru = "Аккаунт DTLogs: подключён",
	},
	startup_account_linked_note = {
		en = "Online uploads will be attributed to your linked DTLogs account.",
		ru = "Онлайн-загрузки будут привязаны к вашему подключённому аккаунту DTLogs.",
	},
	startup_account_not_linked = {
		en = "DTLogs account: not linked. Without an account connection, online uploads are anonymous and the uploader will be shown as Anonymous on DTLogs.",
		ru = "Аккаунт DTLogs: не подключён. Без подключения к аккаунту онлайн-загрузки выполняются анонимно, а загрузивший лог будет отображаться на DTLogs как Anonymous.",
	},
}
