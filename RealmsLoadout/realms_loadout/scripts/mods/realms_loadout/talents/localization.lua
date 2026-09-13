local localization = {
	custom_talent_settings_group = {
		["en"] = "Custom talent points",
		["zh-cn"] = "扩展天赋点", ["zh-tw"]="擴充套件天賦點",
	},
	enable_custom_talent_points = {
		["en"] = "Enable custom talent builds",
		["zh-cn"] = "启用扩展天赋构筑总开关", ["zh-tw"]="啟用擴充套件天賦構築總開關",
	},
	enable_custom_talent_points_desc = {
		["en"] = "Uses a separate local build that is never uploaded to the official backend. The normal path, prerequisite and exclusive-node rules still apply.",
		["zh-cn"] = "使用不会上传到官方后端的独立本地构筑；原有路径、前置点数和互斥节点规则仍然有效。", ["zh-tw"]="使用不會上傳到官方後端的獨立本地構築；原有路徑、前置點數和互斥節點規則仍然有效。",
	},
	enable_local_custom_talents = {
		["en"] = "Apply to my character",
		["zh-cn"] = "对自己的角色生效", ["zh-tw"]="對自己的角色生效",
	},
	enable_local_custom_talents_desc = {
		["en"] = "Let the local player edit and use the separate extended build in supported local sessions.",
		["zh-cn"] = "允许本机玩家在受支持的本地会话中编辑和使用独立扩展构筑。", ["zh-tw"]="允許本機玩家在受支援的本地會話中編輯和使用獨立擴充套件構築。",
	},
	local_talent_points = {
		["en"] = "My talent-point budget",
		["zh-cn"] = "自己的天赋点额度", ["zh-tw"]="自己的天賦點額度",
	},
	local_talent_points_desc = {
		["en"] = "Talent-point budget for the host or a solo player.",
		["zh-cn"] = "房主或单人玩家使用的天赋点额度。", ["zh-tw"]="房主或單人玩家使用的天賦點額度。",
	},
	enable_bot_custom_talents = {
		["en"] = "Apply custom talents to Bots",
		["zh-cn"] = "对 Bot 应用扩展天赋", ["zh-tw"]="對 Bot 應用擴充套件天賦",
	},
	enable_bot_custom_talents_desc = {
		["en"] = "Allows Bots to use the configured budget. This is controlled by the host.",
		["zh-cn"] = "允许 Bot 使用设定额度，由房主控制。", ["zh-tw"]="允許 Bot 使用設定額度，由房主控制。",
	},
	bot_talent_points = {
		["en"] = "Bot talent-point budget",
		["zh-cn"] = "Bot 天赋点额度", ["zh-tw"]="Bot 天賦點額度",
	},
	bot_talent_points_desc = {
		["en"] = "Maximum talent points for each Bot build.",
		["zh-cn"] = "每个 Bot 构筑的天赋点上限。", ["zh-tw"]="每個 Bot 構築的天賦點上限。",
	},
	bot_talent_autofill = {
		["en"] = "Automatically spend extra Bot points",
		["zh-cn"] = "自动分配 Bot 的额外天赋点", ["zh-tw"]="自動分配 Bot 的額外天賦點",
	},
	bot_talent_autofill_desc = {
		["en"] = "Adds legal nodes to each original Bot build until the budget or the valid tree is exhausted.",
		["zh-cn"] = "在 Bot 原构筑上继续选择合法节点，直到用完额度或没有合法节点。", ["zh-tw"]="在 Bot 原構築上繼續選擇合法節點，直到用完額度或沒有合法節點。",
	},
	enable_realms_custom_talents = {
		["en"] = "Allow Realms guests to use custom talents",
		["zh-cn"] = "允许 Realms 客机使用扩展天赋", ["zh-tw"]="允許 Realms 客機使用擴充套件天賦",
	},
	enable_realms_custom_talents_desc = {
		["en"] = "The host validates every guest build and applies the host's point budget. Guest settings cannot override the host.",
		["zh-cn"] = "房主会验证每个客机构筑并执行房主设定的点数上限；客机设置不能覆盖房主规则。", ["zh-tw"]="房主會驗證每個客機構築並執行房主設定的點數上限；客機設定不能覆蓋房主規則。",
	},
	realms_talent_points = {
		["en"] = "Realms guest talent-point budget",
		["zh-cn"] = "Realms 客机天赋点额度", ["zh-tw"]="Realms 客機天賦點額度",
	},
	realms_talent_points_desc = {
		["en"] = "Host-authoritative point budget for every Realms guest.",
		["zh-cn"] = "由房主决定的所有 Realms 客机天赋点额度。", ["zh-tw"]="由房主決定的所有 Realms 客機天賦點額度。",
	},
	custom_talent_edit_notice = {
		["en"] = "Editing the local extended talent build (%d-point budget). It will not be uploaded to the official backend.",
		["zh-cn"] = "正在编辑本地扩展构筑（%d 点额度），不会上传到官方后端。", ["zh-tw"]="正在編輯本地擴充套件構築（%d 點額度），不會上傳到官方後端。",
	},
	custom_talent_build_saved = {
		["en"] = "Local extended talent build saved: %d/%d points.",
		["zh-cn"] = "本地扩展天赋构筑已保存：%d/%d 点。", ["zh-tw"]="本地擴充套件天賦構築已儲存：%d/%d 點。",
	},
	custom_talent_build_rejected = {
		["en"] = "Custom talent build rejected",
		["zh-cn"] = "扩展天赋构筑被拒绝", ["zh-tw"]="擴充套件天賦構築被拒絕",
	},
	custom_talent_session_disabled = {
		["en"] = "The host no longer allows custom talent builds. These changes were not saved.",
		["zh-cn"] = "房主已不再允许扩展天赋构筑，本次更改未保存。", ["zh-tw"]="房主已不再允許擴充套件天賦構築，本次更改未儲存。",
	},
}
localization.mod_name = { en = "Talent Point Manager", ["zh-cn"] = "天赋点管理器", ["zh-tw"]="天賦點管理器" }
localization.toggle_mod_name = localization.mod_name
localization.mod_description = {
    en = "Type /rl in chat and select Talents; no key binding required. An optional DMF shortcut opens the same shared workspace. Supports SoloPlay and Realms.",
    ["zh-cn"] = "聊天输入 /rl 并选择天赋标签，无需绑定按键；也可在 DMF 设置快捷键，进入同一配装窗口。支持 SoloPlay 与 Realms。",
    ["zh-tw"] = "聊天輸入 /rl 並選擇天賦標籤，無需綁定按鍵；也可在 DMF 設定快捷鍵，進入同一配裝視窗。支援 SoloPlay 與 Realms。",
}
localization.unlock_all_auras = { ["en"] = "Allow multiple auras", ["zh-cn"] = "允许多选光环", ["zh-tw"] = "允許多選光環" }
localization.unlock_all_auras_desc = { ["en"] = "Allow multiple native auras while retaining costs and prerequisites. In Realms, the host sets this rule for guests; guest preferences do not override it.", ["zh-cn"] = "允许多选原版光环，保留点数与前置要求。Realms 中客机采用主机下发的规则，本机偏好不能覆盖主机。", ["zh-tw"] = "允許多選原版光環，保留點數與前置要求。Realms 中客機採用主機下發的規則，本機偏好不能覆蓋主機。" }
localization.unlock_all_keystones = { ["en"] = "Allow multiple keystones and upgrades", ["zh-cn"] = "允许多选基石与兼容强化", ["zh-tw"] = "允許多選基石與相容強化" }
localization.unlock_all_keystones_desc = { ["en"] = "Allows audited keystone, skill and companion upgrades with normal costs and prerequisites. Psyker Disrupt Destiny: 25 stacks / 10 seconds when combined. Arbites removal + a dog-dependent talent keeps the dog and native bonuses. Shield forms, attack actions and main combat/Blitz choices stay exclusive. Realms guests follow the host.", ["zh-cn"] = "允许已核对的基石、技能及机械犬强化多选，仍消耗点数并遵循前置。灵能者标记基石双选为25层、10秒；仲裁官移除犬强化与依赖犬天赋双选时保留犬及原版强化。护罩形态、攻击动作、战斗技能及闪击本体仍互斥。Realms客机遵循主机规则。", ["zh-tw"] = "允許已核對的基石、技能及機械犬強化多選，仍消耗點數並遵循前置。靈能者標記基石雙選為25層、10秒；仲裁官移除犬強化與依賴犬天賦雙選時保留犬及原版強化。護罩形態、攻擊動作、戰鬥技能及閃擊本體仍互斥。Realms客機遵循主機規則。" }
localization.custom_talent_rules_pruned = { ["en"] = "Talent rules changed. Choices that no longer fit were removed from the editor. Your saved build is unchanged until you save.", ["zh-cn"] = "天赋规则已变更，编辑器已移除不再符合规则的选择。确认保存前，原有已保存构筑保持不变。", ["zh-tw"] = "天賦規則已變更，編輯器已移除不再符合規則的選擇。確認儲存前，原有已儲存構築保持不變。" }
localization.enable_custom_talent_points_desc = { ["en"] = "Uses a separate local build. Point costs and prerequisites remain; only the enabled aura/keystone switches relax exclusivity. Custom builds are not uploaded to the official backend.", ["zh-cn"] = "使用独立本地构筑，保留点数消耗与前置要求；仅按光环、基石开关解除对应互斥。扩展构筑不会上传到官方后端。", ["zh-tw"] = "使用獨立本地構築，保留點數消耗與前置要求；僅按光環、基石開關解除對應互斥。擴展構築不會上傳到官方後端。" }
localization.custom_talent_host_rules = { ["en"] = "Host rules: %d points; multiple auras: %s; multiple keystones: %s.", ["zh-cn"] = "主机规则：%d 点；多选光环：%s；多选基石：%s。", ["zh-tw"] = "主機規則：%d 點；多選光環：%s；多選基石：%s。" }
localization.custom_talent_allowed = { ["en"] = "allowed", ["zh-cn"] = "允许", ["zh-tw"] = "允許" }
localization.custom_talent_restricted = { ["en"] = "restricted", ["zh-cn"] = "限制", ["zh-tw"] = "限制" }
localization.custom_talent_native_fallback = { ["en"] = "Host rules are unavailable. You can continue editing within native limits; the current host rules will apply when synchronization resumes.", ["zh-cn"] = "暂未收到主机规则，可继续按原版限制编辑；同步恢复后自动采用主机当前规则。", ["zh-tw"] = "暫未收到主機規則，可繼續按原版限制編輯；同步恢復後自動採用主機目前規則。" }
localization.local_talent_points_desc = { ["en"] = "Your solo/host budget. As a Realms guest, the active editor instead uses the host budget; this local preference is preserved.", ["zh-cn"] = "自己单人或作为主机时的额度。作为 Realms 客机时，编辑器采用主机额度，保留本机偏好供离开房间后使用。", ["zh-tw"] = "自己單人或作為主機時的額度。作為 Realms 客機時，編輯器採用主機額度，保留本機偏好供離開房間後使用。" }
localization.enable_realms_custom_talents_desc = { ["en"] = "The host pushes the point budget and both unlock rules to guests, validates submissions and updates applied builds after changes. All peers need the same mod version.", ["zh-cn"] = "主机主动下发点数额度及两项解锁规则，校验客机构筑，并在规则变化后更新已应用的构筑。主客机需使用相同模组版本。", ["zh-tw"] = "主機主動下發點數額度及兩項解鎖規則，校驗客機構築，並在規則變化後更新已套用的構築。主客機需使用相同模組版本。" }
localization.tpm_status_heading = { en = "%s · %d/%d points", ["zh-cn"] = "%s · %d/%d 点", ["zh-tw"] = "%s · %d/%d 點" }
localization.tpm_role_local = { en = "Local rules", ["zh-cn"] = "本机规则", ["zh-tw"] = "本機規則" }
localization.tpm_role_host = { en = "Realms host", ["zh-cn"] = "Realms 主机", ["zh-tw"] = "Realms 主機" }
localization.tpm_role_client = { en = "Realms guest", ["zh-cn"] = "Realms 客机", ["zh-tw"] = "Realms 客機" }
localization.tpm_status_choices = { en = "Auras: %s · Keystones: %s", ["zh-cn"] = "光环：%s · 基石：%s", ["zh-tw"] = "光環：%s · 基石：%s" }
localization.tpm_multi = { en = "Multi", ["zh-cn"] = "多选", ["zh-tw"] = "多選" }
localization.tpm_single = { en = "Single", ["zh-cn"] = "单选", ["zh-tw"] = "單選" }
localization.tpm_status_local = { en = "Local build editing", ["zh-cn"] = "编辑本机构筑", ["zh-tw"] = "編輯本機構築" }
localization.tpm_status_host = { en = "Hosting a Realms room", ["zh-cn"] = "正在主持 Realms 房间", ["zh-tw"] = "正在主持 Realms 房間" }
localization.tpm_status_empty = { en = "Room has no guests", ["zh-cn"] = "房间暂无客机", ["zh-tw"] = "房間暫無客機" }
localization.tpm_status_members = { en = "Rules confirmed: %d/%d guests", ["zh-cn"] = "规则已确认：%d/%d 位客机", ["zh-tw"] = "規則已確認：%d/%d 位客機" }
localization.tpm_status_connecting = { en = "Connecting to host…", ["zh-cn"] = "正在与主机同步…", ["zh-tw"] = "正在與主機同步…" }
localization.tpm_status_synced = { en = "Rules received · Preparing build", ["zh-cn"] = "规则已收到 · 正在准备构筑", ["zh-tw"] = "規則已收到 · 正在準備構築" }
localization.tpm_status_submitting = { en = "Awaiting build confirmation…", ["zh-cn"] = "构筑已提交 · 等待主机确认…", ["zh-tw"] = "構築已提交 · 等待主機確認…" }
localization.tpm_status_accepted = { en = "Build accepted by host", ["zh-cn"] = "主机已接受构筑", ["zh-tw"] = "主機已接受構築" }
localization.tpm_status_rejected = { en = "Build rejected · Edit and save again", ["zh-cn"] = "构筑未通过 · 请修改后重新保存", ["zh-tw"] = "構築未透過 · 請修改後重新儲存" }
localization.tpm_status_loading = { en = "Host loading · Retrying automatically", ["zh-cn"] = "主机正在加载 · 将自动重试", ["zh-tw"] = "主機正在載入 · 將自動重試" }
localization.tpm_status_disabled = { en = "Host disabled custom talents", ["zh-cn"] = "主机已关闭客机扩展天赋", ["zh-tw"] = "主機已關閉客機擴充套件天賦" }
localization.tpm_status_disconnected = { en = "Connection lost · Using native limits", ["zh-cn"] = "连接中断 · 暂用原版限制", ["zh-tw"] = "連線中斷 · 暫用原版限制" }
localization.tpm_status_incompatible = { en = "Host needs the same experiment build", ["zh-cn"] = "需要主客机使用同一实验版", ["zh-tw"] = "需要主客機使用同一實驗版" }
localization.tpm_status_draft = { en = "Unsaved changes · Save to submit", ["zh-cn"] = "修改尚未保存 · 保存后提交", ["zh-tw"] = "修改尚未儲存 · 儲存後提交" }
localization.tpm_status_guest_budget = { en = "Guest budget: %d · Host controlled", ["zh-cn"] = "客机额度：%d 点 · 由主机设定", ["zh-tw"] = "客機額度：%d 點 · 由主機設定" }
localization.tpm_status_host_scope = { en = "Host rules · Local options preserved", ["zh-cn"] = "采用主机规则 · 保留本机偏好", ["zh-tw"] = "採用主機規則 · 保留本機偏好" }
localization.tpm_status_native_scope = { en = "30 points · Editing remains available", ["zh-cn"] = "暂用 30 点 · 可以继续编辑", ["zh-tw"] = "暫用 30 點 · 可以繼續編輯" }
localization.tpm_status_local_scope = { en = "Costs and prerequisites still apply", ["zh-cn"] = "仍消耗点数并遵循前置要求", ["zh-tw"] = "仍消耗點數並遵循前置要求" }
localization.tpm_status_mismatch = { en = "Some guests need the same mod version", ["zh-cn"] = "部分客机需要安装同一模组版本", ["zh-tw"] = "部分客機需要安裝同一模組版本" }
localization.local_talent_points = { en = "Solo / initial room budget", ["zh-cn"] = "单人／房间初始点数", ["zh-tw"] = "單人／房間初始點數" }
localization.local_talent_points_desc = { en = "Solo budget and initial Realms rules (0-99). In a room, the host adjusts each player in the preparation list. Guests use their assigned rules and keep their local preferences.", ["zh-cn"] = "单人额度及 Realms 房间初始规则（0–99）。进入房间后，由房主在准备列表逐人调整；客机采用被分配的规则，保留本机偏好。", ["zh-tw"] = "單人額度及 Realms 房間初始規則（0–99）。進入房間後，由房主在準備列表逐人調整；客機採用被分配的規則，保留本機偏好。" }
localization.tpm_player_controls = { en = "Talent points", ["zh-cn"] = "天赋点数", ["zh-tw"] = "天賦點數" }
localization.tpm_player_auras = { en = "Auras: %s", ["zh-cn"] = "光环：%s", ["zh-tw"] = "光環：%s" }
localization.tpm_player_keystones = { en = "Keystones: %s", ["zh-cn"] = "基石/强化：%s", ["zh-tw"] = "基石/強化：%s" }
localization.tpm_player_host_only = { en = "Host only · Applies to this player", ["zh-cn"] = "仅房主可见 · 仅调整此玩家", ["zh-tw"] = "僅房主可見 · 僅調整此玩家" }
localization.tpm_player_number_help = { en = "Enter / click away: save · Esc: cancel", ["zh-cn"] = "回车／点击别处确认 · Esc 取消", ["zh-tw"] = "Enter／點擊別處確認 · Esc 取消" }
localization.tpm_player_enable_first = { en = "Enable custom talents in Mod options", ["zh-cn"] = "请先在模组选项启用扩展天赋", ["zh-tw"] = "請先在模組選項啟用擴充天賦" }
localization.tpm_status_guest_budget = { en = "Player rules: preparation screen", ["zh-cn"] = "玩家规则：在准备界面逐人设置", ["zh-tw"] = "玩家規則：在準備介面逐人設定" }
localization.debug_talent_effects = { en = "Skill debug logging", ["zh-cn"] = "技能调试日志", ["zh-tw"] = "技能除錯日誌" }
localization.debug_talent_effects_desc = { en = "Off by default. Records your applied talents, live buffs, aggregate stats and accepted proc events in the console log every 15 seconds. Proc counts do not prove damage or healing; client observations are partial. Disable after testing.", ["zh-cn"] = "默认关闭。每15秒在游戏日志记录自己的已应用天赋、当前Buff、汇总属性及原版接受的触发事件。触发计数不代表已造成伤害或治疗；客机观察不完整。测试后请关闭。", ["zh-tw"] = "預設關閉。每15秒在遊戲日誌記錄自己的已套用天賦、目前Buff、彙總屬性及原版接受的觸發事件。觸發計數不代表已造成傷害或治療；客機觀察不完整。測試後請關閉。" }
localization["tpm_deploy_connecting"] = { ["en"] = "Talent: Connecting", ["zh-cn"] = "天赋：等待连接", ["zh-tw"] = "天賦：等待連線" }
localization["tpm_deploy_syncing"] = { ["en"] = "Talent: Syncing rules", ["zh-cn"] = "天赋：同步规则中", ["zh-tw"] = "天賦：同步規則中" }
localization["tpm_deploy_synced"] = { ["en"] = "Talent: Rules synced", ["zh-cn"] = "天赋：规则已同步", ["zh-tw"] = "天賦：規則已同步" }
localization["tpm_deploy_accepted"] = { ["en"] = "Talent: Ready", ["zh-cn"] = "天赋：已就绪", ["zh-tw"] = "天賦：已就緒" }
localization["tpm_deploy_loading"] = { ["en"] = "Talent: Waiting for character", ["zh-cn"] = "天赋：等待角色加载", ["zh-tw"] = "天賦：等待角色載入" }
localization["tpm_deploy_rejected"] = { ["en"] = "Talent: Build rejected", ["zh-cn"] = "天赋：配置未通过校验", ["zh-tw"] = "天賦：配置未通過校驗" }
localization["tpm_deploy_disabled"] = { ["en"] = "Talent: Disabled", ["zh-cn"] = "天赋：已关闭", ["zh-tw"] = "天賦：已關閉" }
localization["tpm_deploy_incompatible"] = { ["en"] = "Talent: Missing / incompatible", ["zh-cn"] = "天赋：未安装或协议不兼容", ["zh-tw"] = "天賦：未安裝或協定不相容" }
localization["tpm_deploy_unavailable"] = { ["en"] = "Talent: No response; check mod", ["zh-cn"] = "天赋：未响应，请检查模组", ["zh-tw"] = "天賦：未回應，請檢查模組" }
localization["tpm_deploy_disconnected"] = { ["en"] = "Talent: Disconnected", ["zh-cn"] = "天赋：连接中断", ["zh-tw"] = "天賦：連線中斷" }
localization["tpm_peer_warning"] = { ["en"] = "Talent Point Manager · %s: %s. Other players can continue.", ["zh-cn"] = "天赋点管理器 · %s：%s。其他玩家可以继续。", ["zh-tw"] = "天賦點管理器 · %s：%s。其他玩家可以繼續。" }

localization.workspace_talents = { ["en"] = "Talents", ["zh-cn"] = "天赋", ["zh-tw"] = "天賦" }
localization.workspace_close_native = { ["en"] = "Close the original inventory before opening the custom workspace.", ["zh-cn"] = "请先关闭原版装备界面，再打开自定义配装窗口。", ["zh-tw"] = "請先關閉原版裝備介面，再開啟自訂配裝視窗。" }
localization.workspace_close = { ["en"] = "Close", ["zh-cn"] = "关闭", ["zh-tw"] = "關閉" }
localization.workspace_command = { ["en"] = "Open the shared workspace: Talents.", ["zh-cn"] = "打开统一配装窗口：天赋。", ["zh-tw"] = "開啟統一配裝視窗：天賦。" }

localization.workspace_unavailable = { en = "The requested page is unavailable. Finish the current operation or check this mod’s settings.", ["zh-cn"] = "当前页面不可用，请完成正在进行的操作或检查本 mod 的设置。", ["zh-tw"] = "目前頁面無法使用，請完成正在進行的操作或檢查本 mod 的設定。" }

localization.inspect_player_unavailable = { ["en"] = "This player is no longer available.", ["zh-cn"] = "该玩家当前不可用。", ["zh-tw"] = "該玩家目前無法使用。" }
localization.inspect_profile_unavailable = { ["en"] = "This player's profile is not ready yet.", ["zh-cn"] = "该玩家的档案尚未就绪。", ["zh-tw"] = "該玩家的檔案尚未就緒。" }
localization.inspect_open_failed = { ["en"] = "Failed to open the inspection view.", ["zh-cn"] = "打开检视界面失败。", ["zh-tw"] = "開啟檢視介面失敗。" }

return localization
