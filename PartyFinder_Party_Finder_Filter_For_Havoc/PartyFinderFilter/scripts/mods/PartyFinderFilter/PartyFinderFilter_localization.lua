return {
	mod_name = {
		en = "Party Finder Filter",
		ru = "Фильтр Party Finder",
	},
	mod_description = {
		en = "Automatically declines Party Finder join requests by class (decline an entire class, or decline a class that is already in your party), by build (decline unless one of the allowed combat abilities is present), and by platform (decline PlayStation players). Only works while YOU have listed the party (List own Party button) — never in someone else's group.",
		ru = "Автоматически отклоняет заявки в Party Finder по классу (отклонять класс целиком или класс, который уже есть в группе), по билду (отклонять, если нет ни одной из разрешённых боевых способностей) и по платформе (отклонять игроков PlayStation). Работает только пока группу залистили вы сами (кнопка List own Party) — в чужой группе никогда.",
	},
	filter_enabled = {
		en = "Enable filter",
		ru = "Фильтр включён",
	},
	filter_enabled_desc = {
		en = "Master switch. When unchecked, the mod declines nothing.",
		ru = "Главный выключатель: если снят, мод ничего не отклоняет.",
	},
	show_notification = {
		en = "Show notification on auto-decline",
		ru = "Уведомление при автоотклонении",
	},
	show_notification_desc = {
		en = "Shows a popup notification when a join request is declined automatically.",
		ru = "Показывает всплывающее уведомление, когда заявка отклонена автоматически.",
	},
	decline_ps5 = {
		en = "Decline PlayStation (PS5) players",
		ru = "Отклонять игроков PlayStation (PS5)",
	},
	decline_ps5_desc = {
		en = "Automatically declines join requests from players on PlayStation (PSN), regardless of class.",
		ru = "Автоматически отклоняет заявки от игроков на PlayStation (PSN), независимо от класса.",
	},
	min_havoc_rank = {
		en = "Minimum Havoc rank",
		ru = "Минимальный ранг Havoc",
	},
	min_havoc_rank_desc = {
		en = "Declines players whose current Havoc assignment rank is below this value, regardless of class. Set to 0 to turn this off. Players whose rank can't be read yet, or who have no current Havoc assignment, are left alone.",
		ru = "Отклоняет игроков, чей текущий ранг назначения Havoc ниже этого значения, независимо от класса. Поставьте 0, чтобы выключить. Игроки, чей ранг ещё не успел подгрузиться или у кого нет активного назначения Havoc, не трогаются.",
	},
	filter_whole_class = {
		en = "Decline entire class",
		ru = "Отклонять класс целиком",
	},
	filter_whole_class_desc = {
		en = "Decline every join request from this class, regardless of build.",
		ru = "Отклонять любые заявки этого класса, независимо от билда.",
	},
	filter_unique = {
		en = "Decline if this class is already in the party",
		ru = "Отклонять, если этот класс уже есть в группе",
	},
	filter_unique_desc = {
		en = "If a player of this class (including yourself) is already in your party, all further requests from this class are declined — keeps the squad's classes unique.",
		ru = "Если игрок этого класса (в том числе вы сами) уже есть в группе, все следующие заявки этого класса отклоняются — классы в отряде остаются уникальными.",
	},
	ability_group_title = {
		en = "Require one of these abilities",
		ru = "Требовать одну из способностей",
	},
	ability_allow_desc = {
		en = "If any ability here is checked, requests from this class are declined unless the applicant's build has at least one of the checked combat abilities. Check none to disable this filter for the class.",
		ru = "Если отмечена хотя бы одна способность, заявки этого класса отклоняются, пока в билде заявителя нет ни одной из отмеченных боевых способностей. Не отмечайте ничего, чтобы отключить этот фильтр для класса.",
	},
	declined_notify_class = {
		en = "Declined join request: %s (%s)",
		ru = "Отклонена заявка: %s (%s)",
	},
	declined_notify_duplicate = {
		en = "Declined join request: %s (%s already in party)",
		ru = "Отклонена заявка: %s (%s уже в группе)",
	},
	declined_notify_ability = {
		en = "Declined join request: %s (%s — missing required ability)",
		ru = "Отклонена заявка: %s (%s — нет нужной способности)",
	},
	declined_notify_ps5 = {
		en = "Declined PlayStation player: %s (%s)",
		ru = "Отклонён игрок PlayStation: %s (%s)",
	},
	declined_notify_havoc = {
		en = "Declined join request: %s (%s, Havoc rank too low)",
		ru = "Отклонена заявка: %s (%s, низкий ранг Havoc)",
	},
}
