return {
	mod_name = {
		en = "Havoc Quickplay",
	},
	mod_description = {
		en = "",
	},

	hq_auto_accept = {
		en = "Auto-Accept Join Requests",
		ko = "참가 요청 자동 수락",
		["zh-cn"] = "自动接受加入请求",
		["zh-tw"] = "自動接受加入請求",
	},
	hq_auto_accept_mission = {
		en = "Auto-Accept Havoc Mission",
		ko = "하복 임무 자동 수락",
		["zh-cn"] = "自动接受浩劫任务",
		["zh-tw"] = "自動接受浩劫任務",
	},
	hq_auto_accept_mission_desc = {
		en = "Accepts when the lobby host puts up a havoc mission.",
		ko = "파티장이 하복 임무를 올리면 자동으로 수락합니다.",
		["zh-cn"] = "当队伍房主发起浩劫任务时自动接受。",
		["zh-tw"] = "當隊伍房主發起浩劫任務時自動接受。",
	},
	hq_auto_accept_desc = {
		en = "Auto-Accepts based on your minimum/maximum havoc rank setting. Reads their TRUE havoc assignment rank, not their clearance one.",
		ko = "설정한 최소/최대 하복 랭크에 따라 자동으로 수락합니다. 허가 수준이 아니라 실제 하복 임무 랭크를 확인합니다.",
		["zh-cn"] = "根据你设置的最低/最高浩劫等级自动接受。读取的是真实的浩劫任务等级，而非许可等级。",
		["zh-tw"] = "根據你設定的最低/最高浩劫級別自動接受。讀取的是真實的浩劫任務級別，而非許可等級。",
	},
	hq_auto_decline = {
		en = "Auto-Decline Join Requests",
		ko = "참가 요청 자동 거절",
		["zh-cn"] = "自动拒绝加入请求",
		["zh-tw"] = "自動拒絕加入請求",
	},
	hq_auto_decline_desc = {
		en = "Auto-Declines based on your minimum/maximum havoc rank setting. Reads their TRUE havoc assignment rank, not their clearance one.",
		ko = "설정한 최소/최대 하복 랭크에 따라 자동으로 거절합니다. 허가 수준이 아니라 실제 하복 임무 랭크를 확인합니다.",
		["zh-cn"] = "根据你设置的最低/最高浩劫等级自动拒绝。读取的是真实的浩劫任务等级，而非许可等级。",
		["zh-tw"] = "根據你設定的最低/最高浩劫級別自動拒絕。讀取的是真實的浩劫任務級別，而非許可等級。",
	},
	hq_auto_start = {
		en = "Auto-Start on Full Lobby",
		ko = "파티가 꽉 차면 자동 시작",
		["zh-cn"] = "队伍满员时自动开始",
		["zh-tw"] = "隊伍滿員時自動開始",
	},
	hq_auto_start_desc = {
		en = "Automatically puts up your current havoc mission when your lobby reaches 4 players. Will stop if someone declines.",
		ko = "파티가 4명이 되면 현재 하복 임무를 자동으로 올립니다. 누군가 거절하면 중단됩니다.",
		["zh-cn"] = "当队伍达到4名玩家时自动发起你当前的浩劫任务。若有人拒绝则会停止。",
		["zh-tw"] = "當隊伍達到4名玩家時自動發起你目前的浩劫任務。若有人拒絕則會停止。",
	},
	hq_join_keybind = {
		en = "Instant Join Keybind",
		ko = "즉시 참가 키",
		["zh-cn"] = "立即加入按键",
		["zh-tw"] = "立即加入按鍵",
	},
	hq_cancel_keybind = {
		en = "Cancel Queue Keybind",
		ko = "대기열 취소 키",
		["zh-cn"] = "取消排队按键",
		["zh-tw"] = "取消排隊按鍵",
	},
	hq_countdown = {
		en = "Join Countdown (seconds)",
		ko = "참가 대기 시간(초)",
		["zh-cn"] = "加入倒计时（秒）",
		["zh-tw"] = "加入倒數（秒）",
	},
	hq_countdown_desc = {
		en = "How many seconds you'll wait before the mod joins a havoc lobby that you got accepted to. "
			.. "NOTE: I recommend keeping this at default, as the mod works by prioritizing the lobby with "
			.. "the most players in it. Reducing this would give other lobbies less time to accept you, "
			.. "potentially making your wait times longer.",
		ko = "수락된 하복 파티에 모드가 참가하기까지 기다리는 시간입니다. "
			.. "참고: 이 모드는 인원이 가장 많은 파티를 우선하므로 기본값으로 두는 것을 권장합니다. "
			.. "값을 줄이면 다른 파티가 수락할 시간이 짧아져 오히려 대기 시간이 길어질 수 있습니다.",
		["zh-cn"] = "在你被某个浩劫队伍接受后，模组等待多少秒才加入。"
			.. "注意：建议保持默认值，因为本模组会优先选择人数最多的队伍。"
			.. "调低此值会让其他队伍来不及接受你的请求，反而可能延长你的等待时间。",
		["zh-tw"] = "在你被某個浩劫隊伍接受後，模組會等待多少秒才加入。"
			.. "注意：建議保持預設值，因為本模組會優先選擇人數最多的隊伍。"
			.. "調低此值會讓其他隊伍來不及接受你的請求，反而可能延長你的等待時間。",
	},
	hq_disable_bl_button = {
		en = "Disable Blacklist Button",
		ko = "차단 버튼 비활성화",
		["zh-cn"] = "禁用屏蔽按钮",
		["zh-tw"] = "停用封鎖按鈕",
	},
	hq_disable_bl_button_desc = {
		en = "Disables the blacklist button in case it's incompatible with another mod of yours. You can use /hqp_bl instead",
		ko = "다른 모드와 충돌하는 경우 차단 버튼을 비활성화합니다. 대신 /hqp_bl 명령어를 사용할 수 있습니다",
		["zh-cn"] = "当该按钮与你的其他模组冲突时将其禁用。你可以改用 /hqp_bl 命令",
		["zh-tw"] = "當該按鈕與你的其他模組衝突時將其停用。你可以改用 /hqp_bl 指令",
	},
	hq_blacklist_minutes = {
		en = "Blacklist Duration (minutes)",
		ko = "차단 지속 시간(분)",
		["zh-cn"] = "屏蔽持续时间（分钟）",
		["zh-tw"] = "封鎖持續時間（分鐘）",
	},
	hq_rank_group = {
		en = "Havoc Rank Filter",
		ko = "하복 랭크 필터",
		["zh-cn"] = "浩劫等级筛选",
		["zh-tw"] = "浩劫級別篩選",
	},
	hq_min_rank = {
		en = "Minimum Assignment / Mission Rank",
		ko = "최소 임무 랭크",
		["zh-cn"] = "最低任务等级",
		["zh-tw"] = "最低任務級別",
	},
	hq_max_rank = {
		en = "Maximum Assignment / Mission Rank",
		ko = "최대 임무 랭크",
		["zh-cn"] = "最高任务等级",
		["zh-tw"] = "最高任務級別",
	},
	hq_rank_desc = {
		en = "Does the same thing as adjusting the setting inside the mission terminal. Just here as well in case you're in a mission or away from the terminal and just don't have an alternate way of accessing it (e.g. the Hub Shortcuts mod).",
		ko = "임무 단말기에서 설정을 조정하는 것과 똑같이 작동합니다. 임무 중이거나 단말기에서 떨어져 있어 달리 접근할 방법이 없을 때를 위해 여기에도 두었습니다(예: Hub Shortcuts 모드).",
		["zh-cn"] = "与在任务终端中调整该设置的效果完全相同。放在这里是为了让你在任务中、或远离终端而没有其他访问方式时也能修改（例如 Hub Shortcuts 模组）。",
		["zh-tw"] = "與在任務終端中調整該設定的效果完全相同。放在這裡是為了讓你在任務中、或遠離終端而沒有其他存取方式時也能修改（例如 Hub Shortcuts 模組）。",
	},
	hq_refresh_interval = {
		en = "Refresh interval",
		ko = "새로 고침 간격",
		["zh-cn"] = "刷新间隔",
		["zh-tw"] = "重新整理間隔",
	},
	hq_refresh_interval_desc = {
		en = "How often the queue refreshes the listings and sends a fresh round of join requests to every Havoc lobby in your rank range.",
		ko = "대기열이 목록을 새로 고치고 랭크 범위 안의 모든 하복 파티에 참가 요청을 다시 보내는 주기입니다.",
		["zh-cn"] = "排队功能刷新列表、并向你等级范围内的所有浩劫队伍重新发送加入请求的频率。",
		["zh-tw"] = "排隊功能重新整理清單、並向你級別範圍內的所有浩劫隊伍重新發送加入請求的頻率。",
	},
	hq_debug = {
		en = "Debug messages",
		ko = "디버그 메시지",
		["zh-cn"] = "调试信息",
		["zh-tw"] = "偵錯訊息",
	},
	hq_debug_desc = {
		en = "Logs queue activity to the console",
		ko = "대기열 활동을 콘솔에 기록합니다",
		["zh-cn"] = "将排队活动记录到控制台",
		["zh-tw"] = "將排隊活動記錄到主控台",
	},

	hq_stepper_min = {
		en = "LOWEST RANK",
		ko = "최소 랭크",
		["zh-cn"] = "最低等级",
		["zh-tw"] = "最低級別",
	},
	hq_stepper_max = {
		en = "HIGHEST RANK",
		ko = "최대 랭크",
		["zh-cn"] = "最高等级",
		["zh-tw"] = "最高級別",
	},

	hq_search_title = {
		en = "Looking for Havoc Party...",
		ko = "하복 파티를 찾고 있습니다...",
		["zh-cn"] = "正在搜寻浩劫队伍…",
		["zh-tw"] = "正在尋找浩劫隊伍……",
	},
	hq_search_range = {
		en = "Havoc - %d to %d",
		ko = "하복 - %d ~ %d",
		["zh-cn"] = "浩劫 - %d 至 %d",
		["zh-tw"] = "浩劫 - %d 至 %d",
	},
	hq_search_cancel = {
		en = "Press %s to cancel search.",
		ko = "%s을 눌러 검색을 취소합니다.",
		["zh-cn"] = "按下 %s 取消搜索。",
		["zh-tw"] = "按下 %s 取消搜尋。",
	},

	hq_found_title = {
		en = "Havoc lobby found!",
		ko = "하복 파티를 찾았습니다!",
		["zh-cn"] = "已找到浩劫队伍！",
		["zh-tw"] = "已找到浩劫隊伍！",
	},
	hq_found_joining = {
		en = "Joining in %d...",
		ko = "%d초 후 참가합니다...",
		["zh-cn"] = "%d 秒后加入…",
		["zh-tw"] = "%d 秒後加入……",
	},
	hq_found_cancel = {
		en = "Press %s to cancel.",
		ko = "%s을 눌러 취소합니다.",
		["zh-cn"] = "按下 %s 取消。",
		["zh-tw"] = "按下 %s 取消。",
	},
	hq_found_join_cancel = {
		en = "Press %s to join instantly, or %s to cancel.",
		ko = "%s을 눌러 즉시 참가하거나, %s을 눌러 취소합니다.",
		["zh-cn"] = "按下 %s 立即加入，或按下 %s 取消。",
		["zh-tw"] = "按下 %s 立即加入，或按下 %s 取消。",
	},

	hq_notify_joined = {
		en = "Joining Havoc lobby",
		ko = "하복 파티에 참가합니다",
		["zh-cn"] = "正在加入浩劫队伍",
		["zh-tw"] = "正在加入浩劫隊伍",
	},
	hq_notify_cancelled = {
		en = "Havoc queue cancelled",
		ko = "하복 대기열이 취소됨",
		["zh-cn"] = "浩劫排队已取消",
		["zh-tw"] = "浩劫排隊已取消",
	},
	hq_notify_already_queued = {
		en = "Already in the Havoc queue",
		ko = "이미 하복 대기열에 있습니다",
		["zh-cn"] = "已在浩劫排队中",
		["zh-tw"] = "已在浩劫排隊中",
	},
	hq_notify_blacklisted = {
		en = "Left the lobby. The queue will not ask to join it again for %d minutes.",
		ko = "파티를 떠났습니다. 앞으로 %d분 동안 이 파티에는 참가를 요청하지 않습니다.",
		["zh-cn"] = "已离开队伍。接下来 %d 分钟内不会再向该队伍发送加入请求。",
		["zh-tw"] = "已離開隊伍。接下來 %d 分鐘內不會再向該隊伍發送加入請求。",
	},
	hq_bl_popup_body = {
		en = "Leave this lobby and stop the queue from asking to join it again for the next %d minutes. "
			.. "The block clears by itself, and it applies to this lobby only.",
		ko = "이 파티를 떠나고, 앞으로 %d분 동안 대기열이 이 파티에 참가를 요청하지 않도록 합니다. "
			.. "차단은 시간이 지나면 저절로 풀리며, 이 파티에만 적용됩니다.",
		["zh-cn"] = "离开该队伍，并在接下来的 %d 分钟内不再向其发送加入请求。"
			.. "该屏蔽会自动解除，且仅对此队伍生效。",
		["zh-tw"] = "離開該隊伍，並在接下來的 %d 分鐘內不再向其發送加入請求。"
			.. "該封鎖會自動解除，且僅對此隊伍生效。",
	},
	hq_notify_not_in_lobby = {
		en = "Not in a lobby with anyone",
		ko = "다른 플레이어와 같은 파티에 있지 않습니다",
		["zh-cn"] = "当前没有与其他玩家组队",
		["zh-tw"] = "目前沒有與其他玩家組隊",
	},
	hq_notify_not_queued = {
		en = "Not queued or hosting",
		ko = "대기 중도 호스팅 중도 아닙니다",
		["zh-cn"] = "当前既未排队也未开设队伍",
		["zh-tw"] = "目前既未排隊也未開設隊伍",
	},
	hq_notify_host_started = {
		en = "Hosting a Havoc lobby",
		ko = "하복 파티를 호스팅합니다",
		["zh-cn"] = "正在开设浩劫队伍",
		["zh-tw"] = "正在開設浩劫隊伍",
	},
	hq_notify_host_stopped = {
		en = "Stopped hosting",
		ko = "호스팅을 중단했습니다",
		["zh-cn"] = "已停止开设队伍",
		["zh-tw"] = "已停止開設隊伍",
	},
	hq_notify_host_failed = {
		en = "Could not create the Havoc lobby",
		ko = "하복 파티를 만들지 못했습니다",
		["zh-cn"] = "无法创建浩劫队伍",
		["zh-tw"] = "無法建立浩劫隊伍",
	},
	hq_notify_auto_start = {
		en = "Lobby full, starting Havoc mission",
		ko = "파티가 꽉 찼습니다. 하복 임무를 시작합니다",
		["zh-cn"] = "队伍已满，正在开始浩劫任务",
		["zh-tw"] = "隊伍已滿員，正在開始浩劫任務",
	},
	hq_notify_launch_failed = {
		en = "Could not start the Havoc mission",
		ko = "하복 임무를 시작하지 못했습니다",
		["zh-cn"] = "无法开始浩劫任务",
		["zh-tw"] = "無法開始浩劫任務",
	},

	hq_block_level = {
		en = "You must be level 30 to queue for this mode.",
		ko = "이 모드에 대기하려면 레벨 30 이상이어야 합니다.",
		["zh-cn"] = "必须达到30级才能排队进行此模式。",
		["zh-tw"] = "必須達到30級才能排隊進行此模式。",
	},
	hq_block_not_unlocked = {
		en = "Havoc is not unlocked on this account",
		ko = "이 계정에서는 하복이 잠금 해제되지 않았습니다",
		["zh-cn"] = "此账号尚未解锁浩劫",
		["zh-tw"] = "此帳號尚未解鎖浩劫",
	},
	hq_block_off_cadence = {
		en = "Havoc is between cadences right now",
		ko = "지금은 하복 주기 사이입니다",
		["zh-cn"] = "浩劫当前处于两个周期之间",
		["zh-tw"] = "浩劫目前處於兩個週期之間",
	},
	hq_block_in_havoc = {
		en = "Already in a Havoc mission",
		ko = "이미 하복 임무 중입니다",
		["zh-cn"] = "已在浩劫任务中",
		["zh-tw"] = "已在浩劫任務中",
	},
	hq_block_cancelled = {
		en = "Queue cancelled. Return to the Mourningstar to queue again.",
		ko = "대기열이 취소되었습니다. 다시 대기하려면 모어닝스타로 돌아가세요.",
		["zh-cn"] = "排队已取消。返回哀星号后才能重新排队。",
		["zh-tw"] = "排隊已取消。返回哀星號後才能重新排隊。",
	},
	hq_block_host_in_mission = {
		en = "Cannot host while in a mission",
		ko = "임무 중에는 호스팅할 수 없습니다",
		["zh-cn"] = "任务进行中无法开设队伍",
		["zh-tw"] = "任務進行中無法開設隊伍",
	},
	hq_block_no_order = {
		en = "No Havoc assignment to host",
		ko = "호스팅할 하복 임무가 없습니다",
		["zh-cn"] = "没有可供开设的浩劫任务",
		["zh-tw"] = "沒有可供開設的浩劫任務",
	},

	hq_cmd_queue_desc = {
		en = "Queue for a Havoc match, works from inside a mission",
		ko = "하복 매치 대기열에 참가합니다. 임무 중에도 작동합니다",
		["zh-cn"] = "排队匹配浩劫，在任务中也可使用",
		["zh-tw"] = "排隊配對浩劫，在任務中也可使用",
	},
	hq_cmd_blacklist_desc = {
		en = "Leave the lobby and block the queue from asking to rejoin it",
		ko = "파티를 떠나고 대기열이 다시 참가를 요청하지 않도록 차단합니다",
		["zh-cn"] = "离开队伍，并阻止排队功能再次请求加入",
		["zh-tw"] = "離開隊伍，並阻止排隊功能再次請求加入",
	},
	hq_cmd_cancel_desc = {
		en = "Cancel the Havoc queue or stop hosting",
		ko = "하복 대기열을 취소하거나 호스팅을 중단합니다",
		["zh-cn"] = "取消浩劫排队或停止开设队伍",
		["zh-tw"] = "取消浩劫排隊或停止開設隊伍",
	},
	hq_cmd_status_desc = {
		en = "Print the Havoc queue status",
		ko = "하복 대기열 상태를 출력합니다",
		["zh-cn"] = "输出浩劫排队状态",
		["zh-tw"] = "輸出浩劫排隊狀態",
	},
}
