return {
	-- mod_name
	mod_name = {
		en = "Auto Medicae Servo-Skull",
		["zh-cn"] = "自动医疗伺服头骨",
		ru = "Серво-череп-автолекарь",
	},
	mod_description = {
		en = "Save Those Rejects",
		["zh-cn"] = "拯救那些废弃者",
		ru = "Auto Medicae Servo-Skull - Спаси этих отступников",
	},
	-- mod_settings
	mod_settings = {
		en = "Mod Settings",
		["zh-cn"] = "模组设置",
		ru = "Настройки мода",
	},
	toggle_mod = {
		en = "Toggle Mod",
		["zh-cn"] = "模组开关",
		ru = "Вкл/Выкл мод",
	},
	toggle_mod_keybind = {
		en = "Toggle Keybind",
		["zh-cn"] = "模组开关按键",
		ru = "Клавиша включения",
	},
	toggle_mod_notify = {
		en = "Toggle Notification",
		["zh-cn"] = "模组开关通知",
		ru = "Уведомление о включении",
	},
	debug_mode = {
		en = "Debug Mode",
		["zh-cn"] = "调试模式",
		ru = "Режим отладки",
	},
	-- manual inject
	manual_inject_settings = {
		en = "Manual Inject Settings",
		["zh-cn"] = "手动注射设置",
		ru = "Настройки ручной инъекции",
	},
	manual_inject_keybind = {
		en = "Manual Inject Keybind (Hold)",
		["zh-cn"] = "手动注射按键（按住）",
		ru = "Клавиша ручной инъекции (удержание)",
	},
	manual_inject_keybind_description = {
		en = "Dedicated key to dispatch the Medicae Servo-Skull and inject incapacitated allies. Activates continuously while held down.",
		["zh-cn"] = "使用此按键来派遣医疗伺服颅骨对受困队友进行注射。按住时持续生效。",
		ru = "Клавиша для отправки медицинского серво-черепа к союзникам выведенным из строя и выполнения инъекции. Действует непрерывно при удержании.",
	},
	manual_inject_press_keybind = {
		en = "Manual Inject Keybind (Press)",
		["zh-cn"] = "手动注射按键（按下）",
		ru = "Клавиша ручной инъекции (нажатие)",
	},
	manual_inject_press_keybind_description = {
		en = "Dedicated key to dispatch the Medicae Servo-Skull and inject incapacitated allies. Only activates on key press, special inputs such as mouse wheel are supported.",
		["zh-cn"] = "使用此按键来派遣医疗伺服颅骨对受困队友进行注射。仅在按下时生效（支持鼠标滚轮等特殊按键）。",
		ru = "Клавиша для отправки медицинского серво-черепа к союзникам выведенным из строя и выполнения инъекции. Срабатывает только при нажатии, поддерживаются особые вводы (например, колесо мыши).",
	},
	-- auto inject
	auto_inject_settings = {
		en = "Auto Inject Settings",
		["zh-cn"] = "自动注射设置",
		ru = "Настройки автоматической инъекции",
	},
	auto_inject = {
		en = "Auto Inject",
		["zh-cn"] = "自动注射",
		ru = "Автоинъекция",
	},
	auto_inject_ignore_bot = {
		en = "Ignore Bots",
		["zh-cn"] = "忽略机器人",
		ru = "Игнорировать ботов",
	},
	auto_inject_ignore_bot_description = {
		en = "When enabled, Auto-Inject will only trigger for human players.",
		["zh-cn"] = "开启后，自动注射仅对人类玩家触发。",
		ru = "При включении автоматическая инъекция срабатывает только для игроков.",
	},
	auto_inject_description = {
		en = "Automatically deploys a Medicae Servo-Skull to administer an injection when you aim at a knocked down, hogtied, or netted ally. It is disabled by default during weapon actions and ability actions. Adjust the settings below to enable it if needed. This feature will not activate while you manually hold the blitz key to aim. For manual-aim auto-release functionality, configure it in the Auto-Release section.",
		["zh-cn"] = "当瞄准被击倒、被束缚或被陷阱捕获的友军时，自动对其派遣医疗伺服头骨进行注射。攻击与技能动作期间默认不启用，如需启用请调整下方设置。手动按住闪击键瞄准时本功能不会生效，如需手动瞄准自动释放功能，请在自动释放设置板块中配置。",
		ru = "Автоматически отправляет медицинский серво-череп для инъекции, когда вы наводитесь на сбитого с ног, связанного или пойманного в сеть союзника. По умолчанию отключено во время действий с оружием и способностями. При необходимости включите в настройках ниже. Функция не работает, пока вы вручную удерживаете клавишу блица для прицеливания. Для функции автоматического отпускания при ручном прицеливании настройте в разделе «Автоматическое отпускание».",
	},
	auto_inject_knocked_down = {
		en = "Enable for Knocked Down",
		["zh-cn"] = "为被击倒者启用",
		ru = "Включить для сбитых с ног",
	},
	auto_inject_knocked_down_description = {
		en = "Enable Auto-Inject for Knocked Down Allies",
		["zh-cn"] = "对被击倒的友军启用自动注射",
		ru = "Включить автоматическую инъекцию для сбитых с ног союзников",
	},
	auto_inject_knocked_down_threshold = {
		en = "Blitz Threshold for Knocked Down",
		["zh-cn"] = "倒地闪击阈值",
		ru = "Порог зарядов блица для сбитых с ног",
	},
	auto_inject_knocked_down_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Inject for knocked down allies.",
		["zh-cn"] = "为被击倒的队友设置启用自动注射的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматической инъекции для сбитых с ног союзников.",
	},
	auto_inject_hogtied = {
		en = "Enable for Hogtied",
		["zh-cn"] = "为被束缚者启用",
		ru = "Включить для связанных",
	},
	auto_inject_hogtied_description = {
		en = "Enable Auto-Inject for Hogtied Allies",
		["zh-cn"] = "对被束缚的友军启用自动注射",
		ru = "Включить автоматическую инъекцию для связанных союзников",
	},
	auto_inject_hogtied_threshold = {
		en = "Blitz Threshold for Hogtied",
		["zh-cn"] = "束缚闪击阈值",
		ru = "Порог зарядов блица для связанных",
	},
	auto_inject_hogtied_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Inject for hogtied allies.",
		["zh-cn"] = "为被束缚的队友设置启用自动注射的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматической инъекции для связанных союзников.",
	},
	auto_inject_netted = {
		en = "Enable for Netted",
		["zh-cn"] = "为被陷阱捕获者启用",
		ru = "Включить для пойманных в сеть",
	},
	auto_inject_netted_description = {
		en = "Enable Auto-Inject for Netted Allies",
		["zh-cn"] = "对被陷阱捕获的友军启用自动注射",
		ru = "Включить автоматическую инъекцию для пойманных в сеть союзников",
	},
	auto_inject_netted_threshold = {
		en = "Blitz Threshold for Netted",
		["zh-cn"] = "陷阱闪击阈值",
		ru = "Порог зарядов блица для пойманных в сеть",
	},
	auto_inject_netted_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Inject for netted allies.",
		["zh-cn"] = "为被陷阱捕获的队友设置启用自动注射的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматической инъекции для пойманных в сеть союзников.",
	},
	auto_inject_ignore_weapon_action = {
		en = "Enable During Weapon Actions",
		["zh-cn"] = "在武器攻击期间启用",
		ru = "Включить во время действий с оружием",
	},
	auto_inject_ignore_weapon_action_description = {
		en = "When enabled, Auto-Inject will trigger normally even during weapon attack actions.",
		["zh-cn"] = "开启后，武器攻击动作期间自动注射仍可正常触发。",
		ru = "При включении автоматическая инъекция будет срабатывать даже во время атак оружием.",
	},
	auto_inject_ignore_ability_action = {
		en = "Enable During Ability Actions",
		["zh-cn"] = "在能力施放期间启用",
		ru = "Включить во время действий способностей",
	},
	auto_inject_ignore_ability_action_description = {
		en = "When enabled, Auto-Inject will trigger normally even during ability actions(Chordclaw).",
		["zh-cn"] = "开启后，能力施放动作（共鸣爪）期间自动注射仍可正常触发。",
		ru = "При включении автоматическая инъекция будет срабатывать даже во время действий способностей (Chordclaw).",
	},
	auto_release_settings = {
		en = "Auto Release Settings",
		["zh-cn"] = "自动释放设置",
		ru = "Настройки автоматического отпускания",
	},
	auto_release = {
		en = "Auto Release",
		["zh-cn"] = "自动释放",
		ru = "Автоотпускание",
	},
	auto_release_ignore_bot = {
		en = "Ignore Bots",
		["zh-cn"] = "忽略机器人",
		ru = "Игнорировать ботов",
	},
	auto_release_ignore_bot_description = {
		en = "When enabled, Auto-Release will only trigger for human players.",
		["zh-cn"] = "开启后，自动释放仅对人类玩家触发。",
		ru = "При включении автоматическое отпускание срабатывает только для игроков.",
	},
	auto_release_description = {
		en = "Hold your blitz key to aim at a disabled ally, and the mod will automatically release the key to deploy the Medicae Servo-Skull for you.",
		["zh-cn"] = "按住闪击键瞄准受控友军，模组将自动替你松开按键以部署医疗伺服头骨。",
		ru = "Удерживайте клавишу блица, наводясь на недееспособного союзника — мод автоматически отпустит клавишу и отправит медицинский серво-череп.",
	},
	auto_release_knocked_down = {
		en = "Enable for Knocked Down",
		["zh-cn"] = "为被击倒者启用",
		ru = "Включить для сбитых с ног",
	},
	auto_release_knocked_down_description = {
		en = "Enable Auto-Release for Knocked Down Allies",
		["zh-cn"] = "对被击倒的友军启用自动释放",
		ru = "Включить автоматическое отпускание для сбитых с ног союзников",
	},
	auto_release_knocked_down_threshold = {
		en = "Blitz Threshold for Knocked Down",
		["zh-cn"] = "倒地闪击阈值",
		ru = "Порог зарядов блица для сбитых с ног",
	},
	auto_release_knocked_down_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Release for knocked down allies.",
		["zh-cn"] = "为被击倒的队友设置启用自动释放的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматического отпускания для сбитых с ног союзников.",
	},
	auto_release_hogtied = {
		en = "Enable for Hogtied",
		["zh-cn"] = "为被束缚者启用",
		ru = "Включить для связанных",
	},
	auto_release_hogtied_description = {
		en = "Enable Auto-Release for Hogtied Allies",
		["zh-cn"] = "对被束缚的友军启用自动释放",
		ru = "Включить автоматическое отпускание для связанных союзников",
	},
	auto_release_hogtied_threshold = {
		en = "Blitz Threshold for Hogtied",
		["zh-cn"] = "束缚闪击阈值",
		ru = "Порог зарядов блица для связанных",
	},
	auto_release_hogtied_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Release for hogtied allies.",
		["zh-cn"] = "为被束缚的队友设置启用自动释放的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматического отпускания для связанных союзников.",
	},
	auto_release_netted = {
		en = "Enable for Netted",
		["zh-cn"] = "为被陷阱捕获者启用",
		ru = "Включить для пойманных в сеть",
	},
	auto_release_netted_description = {
		en = "Enable Auto-Release for Netted Allies",
		["zh-cn"] = "对被陷阱捕获的友军启用自动释放",
		ru = "Включить автоматическое отпускание для пойманных в сеть союзников",
	},
	auto_release_netted_threshold = {
		en = "Blitz Threshold for Netted",
		["zh-cn"] = "陷阱闪击阈值",
		ru = "Порог зарядов блица для пойманных в сеть",
	},
	auto_release_netted_threshold_description = {
		en = "Sets the minimum number of blitz charges required to enable Auto-Release for netted allies.",
		["zh-cn"] = "为被陷阱捕获的队友设置启用自动释放的最小闪击持有量。",
		ru = "Устанавливает минимальное количество зарядов блица, необходимое для включения автоматического отпускания для пойманных в сеть союзников.",
	},
}
