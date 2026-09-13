---@type mod
local mod = get_mod("dopamine")

local lines, important = mod.dl.loc_helpers.lines, mod.dl.loc_helpers.important

local loc = {

	heading_mission_summary = {
		en = "Mission Summary",
		["zh-cn"] = "任务总结",
	},
	mod_menu_keybind = {
		en = "Mod Menu Keybind",
		["zh-cn"] = "模组菜单快捷键",
	},
	mod_menu_keybind_description = {
		en = lines(
			"",
			"Dopamine is managed entirely via a very pretty, custom mod menu",
			"",
			important(
				"I'd recommend using a combination (e.g. SHIFT+T) to avoid the menu opening when using text inputs"
			)
		),
		["zh-cn"] = lines(
			"",
			"Dopamine 完全通过一个精美的自定义模组菜单进行管理",
			"",
			important("建议使用组合键（例如 SHIFT+T），以避免在输入文字时意外打开菜单")
		),
	},

	mod_menu_title = {
		en = "DOPAMINE",
		["zh-cn"] = "DOPAMINE",
	},
	mission_summary_module = {
		en = "MISSIONS",
		["zh-cn"] = "任务",
	},
	settings_module = {
		en = "SETTINGS",
		["zh-cn"] = "设置",
	},

	mission_summary_run_heading = {
		en = "RUN",
		["zh-cn"] = "战绩",
	},
	mission_summary_events_heading = {
		en = "STYLE EVENTS",
		["zh-cn"] = "风格事件",
	},
	mission_summary_victims_heading = {
		en = "VICTIMS",
		["zh-cn"] = "受害者",
	},
	mission_summary_method_heading = {
		en = "METHOD",
		["zh-cn"] = "方式",
	},
	mission_summary_style_heading = {
		en = "STYLE",
		["zh-cn"] = "风格",
	},
	mission_summary_competence_heading = {
		en = "COMPETENCE",
		["zh-cn"] = "能力",
	},
	mission_summary_team_heading = {
		en = "SHARED TRAUMA",
		["zh-cn"] = "队伍",
	},
	mission_summary_objective_time = {
		en = "OBJECTIVE TIME",
		["zh-cn"] = "目标时间",
	},
	mission_summary_objectives = {
		en = "OBJECTIVES",
		["zh-cn"] = "目标",
	},

	mission_summary_objectives_time = {
		en = "OBJECTIVES/TIME",
		["zh-cn"] = "目标/时间",
	},
	mission_summary_rescues = {
		en = "RESCUES",
		["zh-cn"] = "救援",
	},

	mission_summary_allies_stimmed = {
		en = "ALLIES STIMMED",
		["zh-cn"] = "队友注射",
	},
	mission_summary_coherency = {
		en = "COHERENCY",
		["zh-cn"] = "凝聚",
	},

	mission_summary_berserker_magdump = {
		en = "BERSERK/MAGDUMP",
		["zh-cn"] = "狂暴/倾泻",
	},
	mission_summary_hotswap = {
		en = "HOTSWAP",
		["zh-cn"] = "换武击杀",
	},
	mission_summary_melee_kill = {
		en = "MELEE KILL",
		["zh-cn"] = "近战击杀",
	},
	mission_summary_ranged_kill = {
		en = "RANGED KILL",
		["zh-cn"] = "远程击杀",
	},
	mission_summary_best_combo = {
		en = "BEST COMBO",
		["zh-cn"] = "最佳连击",
	},

	mission_summary_damage_taken = {
		en = "DAMAGE TAKEN",
		["zh-cn"] = "承受伤害",
	},
	mission_summary_downs = {
		en = "DOWNED",
		["zh-cn"] = "倒地次数",
	},
	mission_summary_date = {
		en = "DATE",
		["zh-cn"] = "日期",
	},
	mission_summary_time = {
		en = "TIME",
		["zh-cn"] = "时间",
	},
	mission_summary_kills = {
		en = "KILLS",
		["zh-cn"] = "击杀",
	},
	mission_summary_damage = {
		en = "DAMAGE",
		["zh-cn"] = "伤害",
	},
	mission_summary_boss_damage = {
		en = "BOSS DAMAGE",
		["zh-cn"] = "首领伤害",
	},
	mission_summary_style = {
		en = "STYLE",
		["zh-cn"] = "风格",
	},

	mission_summary_violence = {
		en = "VIOLENCE",
		["zh-cn"] = "暴力",
	},
	mission_summary_unity = {
		en = "UNITY",
		["zh-cn"] = "团结",
	},
	mission_summary_finesse = {
		en = "FINESSE",
		["zh-cn"] = "技巧",
	},

	mission_summary_magnitude_heading = {
		en = "MAGNITUDE",
		["zh-cn"] = "伤害量",
	},
	mission_summary_elites = {
		en = "ELITES",
		["zh-cn"] = "精英",
	},
	mission_summary_specials = {
		en = "SPECIALS",
		["zh-cn"] = "特殊",
	},
	mission_summary_bosses = {
		en = "BOSSES",
		["zh-cn"] = "首领",
	},
	mission_summary_secrets = {
		en = "SECRETS",
		["zh-cn"] = "秘密",
	},
	mission_summary_plasteel = {
		en = "PLASTEEL",
		["zh-cn"] = "塑钢",
	},
	mission_summary_diamantine = {
		en = "DIAMANTINE",
		["zh-cn"] = "金刚石",
	},
	mission_summary_high_score = {
		en = "TOP 10 RUNS",
		["zh-cn"] = "前十名战绩",
	},
	mission_summary_show_live = {
		en = "SHOW LIVE MISSION SCORE",
		["zh-cn"] = "显示当前任务分数",
	},

	mission_summary_hell_yeah = {
		en = "HELL YEAH",
		["zh-cn"] = "太棒了",
	},

	mission_summary_skip_recap = {
		en = "SKIP RECAP",
		["zh-cn"] = "跳过回顾",
	},

	mission_summary_delete_run = {
		en = "DELETE RUN",
		["zh-cn"] = "删除记录",
	},

	mission_summary_current_run = {
		en = "[CURRENT]",
		["zh-cn"] = "[当前]",
	},
	mission_summary_new_run = {
		en = "[NEW!]",
		["zh-cn"] = "[新!]",
	},
	mission_summary_not_in_mission = {
		en = "NOT IN A MISSION",
		["zh-cn"] = "当前不在任务中",
	},
	mission_summary_select_mission = {
		en = "SELECT MISSION",
		["zh-cn"] = "选择任务",
	},
}

return loc
