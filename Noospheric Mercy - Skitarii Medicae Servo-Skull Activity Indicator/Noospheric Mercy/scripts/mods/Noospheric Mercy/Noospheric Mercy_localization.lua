return {
	mod_name = {
		en = "Noospheric Mercy",
		["zh-cn"] = "救援提示",
	},
	mod_description = {
		en = "Keeps the medicae servo skull's cogwheel and ally outline visible while it travels to and restores a downed teammate. Spectators see it too; party-chat broadcast keeps the target exact across mod users.",
		["zh-cn"] = "治疗伺服头骨飞向并救援倒地队友期间，持续显示齿轮标识与队友高亮轮廓。观战玩家同样可见；小队频道同步播报，所有安装本模组的玩家显示目标完全一致。",
	},
	broadcast_enabled = {
		en = "Broadcast rescue in party chat",
		["zh-cn"] = "小队频道播报救援目标",
	},
	broadcast_only_when_multiple = {
		en = "Only broadcast when more than one player is down",
	},
	broadcast_only_when_multiple_description = {
		en = "With a single player down the target is never ambiguous, so other players' mods already show the correct one. Leave this on to keep party chat quiet and only announce when it actually resolves a doubt.",
	},
	show_others = {
		en = "Show rescues called by other players",
		["zh-cn"] = "显示其他玩家释放的救援头骨",
	},
	rescue_marker_enabled = {
		en = "Show a marker over the rescue target",
		["zh-cn"] = "在救援目标头顶显示标记",
	},
	hack_marker_enabled = {
		en = "Show a marker over the servo skull's hacking target",
	},
	outline_priority = {
		en = "Ally outline priority (lower wins)",
		["zh-cn"] = "队友高亮渲染层级（数值越低越顶层）",
	},
	outline_priority_description = {
		en = "Render priority of the rescue outline. Lower numbers draw over higher ones; the game's own outlines use 1-4, so 5 keeps the rescue outline below them.",
		["zh-cn"] = "救援高亮的渲染优先级，数值越小越优先显示。游戏原生高亮层级为1-4，设为5会让救援高亮置于原生高亮下层。",
	},
	verbose_logging = {
		en = "Write a detailed trace to the log file (for debugging)",
		["zh-cn"] = "输出完整运行日志至文件（调试用）",
	},
}