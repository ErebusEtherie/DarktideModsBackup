local loc = {
	mod_name = {
		en = "Strikemap",
		["zh-cn"] = "战术雷达地图",
	},
	mod_description = {
		en = "A real Strikemap: renders the level's walkable floor plan around you, "
			.. "with allies, player pings, enemies, elites, specialists, objectives and medicae stations. "
			.. "Records every run into a Mission Debrief with replay, heatmaps and squad stats. "
			.. "Map geometry is pre-baked per mission, so it works as host and client alike.",
		["zh-cn"] = "真实战术雷达地图：渲染当前关卡可行走地形，显示队友、玩家标记、敌人、精英、特殊敌人、任务目标以及医疗站。记录每局对局数据，支持对局回放、热力图与小队数据统计。地图数据为每关预编译文件，房主与客户端均可正常使用。",
	},

	-- General
	strikemap_general = {
		en = "General",
		["zh-cn"] = "通用设置",
	},
	enable_minimap = {
		en = "Enable Minimap",
		["zh-cn"] = "启用小地图",
	},
	enable_minimap_tooltip = {
		en = "Persistent master switch for the corner minimap. Turn this off to keep the minimap hidden after restarting the game. The full-screen tactical map and Mission Debrief remain available.",
		["zh-cn"] = "小地图的永久总开关。关闭后，即使重新启动游戏，小地图也会保持隐藏；全屏战术地图和任务复盘仍可使用。",
	},
	map_theme = {
		en = "Radar Theme",
		["zh-cn"] = "雷达外观样式",
	},
	map_theme_tooltip = {
		en = "Terminal: the full cogitator-skinned square panel. Round: circular auspex "
			.. "with range rings. Clean Square/Circle: flat borderless layouts. Ghost: no "
			.. "background or frame at all - just the floor plan and markers.",
		["zh-cn"] = "终端样式：完整机魂电脑方形面板；圆形观测仪：带有测距环的圆形雷达；简约方形/圆形：无边框扁平化样式；幽灵模式：无背景边框，仅保留地形与标记。",
	},
	theme_terminal = {
		en = "Terminal (square)",
		["zh-cn"] = "终端面板（方形）",
	},
	theme_round = {
		en = "Auspex (round)",
		["zh-cn"] = "观测仪（圆形）",
	},
	theme_clean = {
		en = "Clean (flat square)",
		["zh-cn"] = "简约（扁平方形）",
	},
	theme_clean_circle = {
		en = "Clean (flat circle)",
		["zh-cn"] = "简约（扁平圆形）",
	},
	theme_ghost = {
		en = "Ghost (no frame)",
		["zh-cn"] = "幽灵模式（无框架）",
	},
	floor_style = {
		en = "Floor Separation Style",
	},
	floor_style_tooltip = {
		en = "Tactical Contours renders a flat neutral floor plan that fades with distance: bone wall outlines, whole staircases lit while you climb them, decks below kept visible as darker fill, upper decks as thin outlines. Classic Filled Tiers preserves the original filled elevation palette.",
	},
	show_veil = {
		en = "Soft Light (Rear Fade + Player Glow)",
		["zh-cn"] = "柔光（后方渐隐+玩家光晕）",
	},
	show_veil_tooltip = {
		en = "Cosmetic lighting overlays: the map behind you rolls off into a gentle fade, and a warm lamp glow surrounds your position. Screen-anchored - never hides map data (not fog of war). On the frameless Ghost theme this also draws the soft dark halo behind the plan.",
		["zh-cn"] = "装饰性光效叠加：身后的地图渐渐淡出，你的位置周围环绕一圈温暖的灯光。锚定于屏幕，绝不会隐藏地图信息（并非战争迷雾）。在无边框的幽灵主题下，还会在地图后方绘制柔和的暗色光晕。",
	},
	show_hatchwork = {
		en = "Upper-Deck Hatching",
		["zh-cn"] = "上层甲板阴影线",
	},
	show_hatchwork_tooltip = {
		en = "Draws diagonal hatching across decks above you. Off by default: outlines alone keep the plan cleaner and cheaper to draw.",
		["zh-cn"] = "以斜线纹理标示上方甲板。默认关闭：仅用轮廓线更简洁，绘制开销也更低。",
	},
	floor_style_tactical = {
		en = "Tactical Contours (new default)",
	},
	floor_style_classic = {
		en = "Classic Filled Tiers",
	},
	show_medicae_charges = {
		en = "Show Medicae Charges",
		["zh-cn"] = "显示医疗站剩余充能次数",
	},
	show_medicae_charges_tooltip = {
		en = "Show the remaining charge count next to each medicae station, updated live.",
		["zh-cn"] = "实时在医疗站图标旁显示剩余使用次数。",
	},
	show_supplies = {
		en = "Show Openable Containers",
		["zh-cn"] = "显示弹药箱与手雷补给箱",
	},
	show_supplies_tooltip = {
		en = "Mark unopened loot containers as squares. Pocketable ammo and medical crates have separate icon settings below.",
		["zh-cn"] = "标记弹药箱和手雷补给箱，默认使用琥珀色方块标识。",
	},
	supplies_color = {
		en = "Supplies Colour",
		["zh-cn"] = "补给物品颜色",
	},
	show_books = {
		en = "Show Grimoires & Scriptures",
		["zh-cn"] = "显示魔法书与圣典",
	},
	show_books_tooltip = {
		en = "Mark side-objective book pickups (violet diamonds by default). "
			.. "Markers disappear when a book is picked up.",
		["zh-cn"] = "标记支线道具魔法书与圣典，默认紫色菱形；拾取之后标记自动消失。",
	},
	books_color = {
		en = "Books Colour",
		["zh-cn"] = "书本标记颜色",
	},
	show_materials = {
		en = "Show Crafting & Other Pickups",
		["zh-cn"] = "显示小型拾取物品",
	},
	show_materials_tooltip = {
		en = "Mark crafting materials and uncategorized small pickups. Loose ammo, grenades, crates and stimms have separate settings.",
		["zh-cn"] = "标记素材、小包弹药等小型道具；道具数量繁多，默认关闭。",
	},
	materials_color = {
		en = "Other Pickups Colour",
		["zh-cn"] = "小型物品颜色",
	},
	show_ammo_pickups = {
		en = "Show Loose Ammo",
		["zh-cn"] = "显示散落弹药",
	},
	show_ammo_pickups_tooltip = {
		en = "Show loose ammo tins and bags using the ammunition icon.",
		["zh-cn"] = "使用弹药图标显示地上散落的弹药包、弹药罐。",
	},
	ammo_pickups_color = {
		en = "Loose Ammo Colour",
		["zh-cn"] = "散落弹药颜色",
	},
	ammo_pickups_color_tooltip = {
		en = "Tint used for loose-ammo icons.",
		["zh-cn"] = "散落弹药图标的着色。",
	},
	show_grenades = {
		en = "Show Grenade Pickups",
		["zh-cn"] = "显示手雷拾取物",
	},
	show_grenades_tooltip = {
		en = "Show loose grenade pickups using the grenade icon.",
		["zh-cn"] = "使用手雷图标显示地上散落的手雷。",
	},
	grenades_color = {
		en = "Grenade Colour",
		["zh-cn"] = "手雷颜色",
	},
	grenades_color_tooltip = {
		en = "Tint used for grenade pickup icons.",
		["zh-cn"] = "手雷拾取图标的着色。",
	},
	show_ammo_crates = {
		en = "Show Ammo Crates",
		["zh-cn"] = "显示弹药补给箱",
	},
	show_ammo_crates_tooltip = {
		en = "Show pocketable and player-deployed ammo crates using the ammo-crate icon.",
		["zh-cn"] = "使用弹药箱图标显示可拾取、玩家部署的弹药补给箱。",
	},
	ammo_crates_color = {
		en = "Ammo Crate Colour",
		["zh-cn"] = "弹药箱颜色",
	},
	ammo_crates_color_tooltip = {
		en = "Tint used for pocketable and deployed ammo-crate icons.",
		["zh-cn"] = "可拾取与部署弹药箱图标的着色。",
	},
	show_med_crates = {
		en = "Show Medical Crates",
		["zh-cn"] = "显示医疗补给箱",
	},
	show_med_crates_tooltip = {
		en = "Show pocketable and player-deployed medical crates using the medical-crate icon.",
		["zh-cn"] = "使用医疗箱图标显示可拾取、玩家部署的医疗补给箱。",
	},
	med_crates_color = {
		en = "Medical Crate Colour",
		["zh-cn"] = "医疗箱颜色",
	},
	med_crates_color_tooltip = {
		en = "Tint used for pocketable and deployed medical-crate icons.",
		["zh-cn"] = "可拾取与部署医疗箱图标的着色。",
	},
	show_stimms = {
		en = "Show Stimms",
		["zh-cn"] = "显示兴奋剂",
	},
	show_stimms_tooltip = {
		en = "Show stimms using the matching ability, corruption, power, speed or broker icon.",
		["zh-cn"] = "对应显示抗性、腐蚀、威力、移速、交易商各类兴奋剂专属图标。",
	},
	stimms_color = {
		en = "Stimm Colours",
		["zh-cn"] = "兴奋剂颜色",
	},
	stimms_color_tooltip = {
		en = "Use each stimm type's natural colour or override every stimm with one custom tint.",
		["zh-cn"] = "使用各类兴奋剂原生配色，或统一全部兴奋剂为自定义单色。",
	},
	stimm_color_by_type = {
		en = "By Stimm Type",
		["zh-cn"] = "按兴奋剂种类区分颜色",
	},
	show_ally_health = {
		en = "Show Ally Health Rings",
		["zh-cn"] = "显示队友血量条",
	},
	show_ally_health_tooltip = {
		en = "Represent each teammate's live health as the outer ring around their marker.",
		["zh-cn"] = "队友图标下方显示微型血条；倒地时血条闪烁红色。",
	},
	show_ally_facing = {
		en = "Show Ally Facing",
	},
	show_ally_facing_tooltip = {
		en = "Add a small directional nose to each teammate marker using their replicated facing direction.",
	},
	show_ally_distress = {
		en = "Show Downed Distress Pulses",
	},
	show_ally_distress_tooltip = {
		en = "Emit expanding red distress rings from teammates while they are knocked down.",
	},
	show_ally_badges = {
		en = "Show Carried-Item Badges",
	},
	show_ally_badges_tooltip = {
		en = "Attach badges for batteries, luggable objectives, scriptures, grimoires and other mission items to teammate markers.",
	},
	report_view_title = {
		en = "Mission Reports",
		["zh-cn"] = "对局报告",
	},
	record_reports = {
		en = "Record Mission Reports",
		["zh-cn"] = "保存对局记录",
	},
	record_reports_tooltip = {
		en = "Record each run (player paths, downs, deaths, rescues, combat locations, "
			.. "class and difficulty) and save it for post-game review in the Mission Debrief.",
		["zh-cn"] = "记录本局行进路线、倒地、阵亡、救援、交战位置、职业和难度信息，结束后可查看复盘。",
	},
	record_psykhanium = {
		en = "Record Psykhanium / Mortis Trials",
		["zh-cn"] = "记录灵能室试炼对局",
	},
	record_psykhanium_tooltip = {
		en = "Off by default. Enable to save Psykhanium and Mortis Trials sessions in Mission Debrief.",
		["zh-cn"] = "像普通任务一样记录灵能室（殉难者试炼）对局；取消勾选后试炼不再进入复盘历史。",
	},
	auto_open_report = {
		en = "Auto-Open Debrief After Missions",
		["zh-cn"] = "对局结束自动打开复盘面板",
	},
	auto_open_report_tooltip = {
		en = "When the end-of-mission screen appears, automatically open the Mission "
			.. "Debrief and play the whole run back as a fast tactical replay - "
			.. "a scoreboard popup, except it is the map of everything that happened.",
		["zh-cn"] = "任务结算页面弹出后自动打开复盘面板，以地图回放全程对局，直观查看整场战斗经过。",
	},
	feed_stream_replay = {
		en = "Stream Events During Replay",
		["zh-cn"] = "回放时逐条显示事件",
	},
	feed_stream_replay_tooltip = {
		en = "During a replay, the event feed only lists what has already happened - "
			.. "events stream in as the playhead passes them. Off: always show the full list.",
		["zh-cn"] = "回放过程中事件列表只显示已经发生的事件，随播放进度逐条出现；关闭后始终显示完整列表。",
	},
	auto_replay_speed = {
		en = "Auto-Replay Speed",
		["zh-cn"] = "自动回放倍速",
	},
	auto_replay_speed_tooltip = {
		en = "Playback speed used when the debrief opens itself after a mission. "
			.. "You can change speed any time with the speed button on the timeline.",
		["zh-cn"] = "对局结束自动回放时的播放速度，回放过程里依然可以在时间轴修改倍速。",
	},
	replay_speed_4 = {
		en = "4x",
		["zh-cn"] = "4倍速",
	},
	replay_speed_8 = {
		en = "8x",
		["zh-cn"] = "8倍速",
	},
	replay_speed_16 = {
		en = "16x",
		["zh-cn"] = "16倍速",
	},
	replay_speed_32 = {
		en = "32x",
		["zh-cn"] = "32倍速",
	},
	replay_speed_64 = {
		en = "64x",
		["zh-cn"] = "64倍速",
	},
	fullmap_rotate = {
		en = "Full Map Rotates With Camera",
		["zh-cn"] = "全屏地图跟随镜头旋转",
	},
	fullmap_rotate_tooltip = {
		en = "On: the full-screen tactical map turns to face your heading. "
			.. "Off (default): it stays north-up while your arrow rotates.",
		["zh-cn"] = "开启：全屏地图随你的朝向转动；关闭（默认）：地图固定上方为北，仅玩家箭头旋转。",
	},
	map_corner = {
		en = "Screen Anchor",
		["zh-cn"] = "雷达停靠位置",
	},
	map_corner_tooltip = {
		en = "Which part of the screen the Strikemap sits in. "
			.. "Fine-tune with the offset sliders below.",
		["zh-cn"] = "设置雷达面板停靠在屏幕的哪个位置，可配合下方偏移滑条微调。",
	},
	corner_top_right = {
		en = "Top Right",
		["zh-cn"] = "右上角",
	},
	corner_top_left = {
		en = "Top Left",
		["zh-cn"] = "左上角",
	},
	corner_top_center = {
		en = "Top Center",
		["zh-cn"] = "顶部居中",
	},
	corner_bottom_right = {
		en = "Bottom Right",
		["zh-cn"] = "右下角",
	},
	corner_bottom_left = {
		en = "Bottom Left",
		["zh-cn"] = "左下角",
	},
	corner_bottom_center = {
		en = "Bottom Center",
		["zh-cn"] = "底部居中",
	},
	corner_center = {
		en = "Screen Center",
		["zh-cn"] = "屏幕中央",
	},
	map_contents_opacity = {
		en = "Map Contents Opacity",
		["zh-cn"] = "地图内容不透明度",
	},
	map_contents_opacity_tooltip = {
		en = "Fades everything the panel draws - floor plan, walls, markers and text - not just the backdrop. Lower this when placing the map at Screen Center so it overlays the action instead of blocking it. The Radar Opacity slider above still controls the panel background on its own.",
		["zh-cn"] = "淡化面板绘制的所有内容——地形、墙体、标记与文字，而不仅仅是背景。将地图放在屏幕中央时调低此项，可让地图叠加在画面上而不遮挡视野。上方的雷达不透明度滑块仍单独控制面板背景。",
	},
	map_offset_x = {
		en = "Horizontal Offset",
		["zh-cn"] = "水平偏移",
	},
	map_offset_x_tooltip = {
		en = "Shift the panel left (negative) or right (positive) from its anchor, "
			.. "in 1080p-reference pixels.",
		["zh-cn"] = "以停靠点为基准向左（负值）或向右（正值）微调面板位置（1080P基准像素）。",
	},
	map_offset_y = {
		en = "Vertical Offset",
		["zh-cn"] = "垂直偏移",
	},
	map_offset_y_tooltip = {
		en = "Shift the panel up (negative) or down (positive) from its anchor, "
			.. "in 1080p-reference pixels.",
		["zh-cn"] = "以停靠点为基准向上（负值）或向下（正值）微调面板位置（1080P基准像素）。",
	},
	map_size = {
		en = "Map Size",
		["zh-cn"] = "雷达尺寸",
	},
	map_size_tooltip = {
		en = "Size of the Strikemap panel in pixels (at 1080p reference scale).",
		["zh-cn"] = "1080P分辨率基准下雷达面板像素大小。",
	},
	map_zoom = {
		en = "Zoom (metres across)",
		["zh-cn"] = "雷达视野范围（米）",
	},
	map_zoom_tooltip = {
		en = "How many metres of the level the Strikemap spans. Lower = closer zoom.",
		["zh-cn"] = "雷达横向覆盖多少米范围，数值越小镜头越近。",
	},
	map_opacity = {
		en = "Background Opacity",
		["zh-cn"] = "背景透明度",
	},
	map_opacity_tooltip = {
		en = "Opacity of the dark backdrop behind the map geometry.",
		["zh-cn"] = "地形后方深色背景的透明度。",
	},
	rotate_with_camera = {
		en = "Rotate With Camera",
		["zh-cn"] = "迷你雷达跟随镜头旋转",
	},
	rotate_with_camera_tooltip = {
		en = "On: the map rotates so up is always where you are looking. "
			.. "Off: the map stays north-up and your arrow rotates instead.",
		["zh-cn"] = "开启：雷达上方永远对应你的朝向；关闭：地图上方固定朝北，只有玩家箭头旋转。",
	},
	marker_visibility_mode = {
		en = "Marker Visibility",
		["zh-cn"] = "敌人可见判定规则",
	},
	marker_visibility_mode_tooltip = {
		en = "Choose how much the Strikemap reveals. Squad Sight only shows enemies and map markers "
			.. "that you or a teammate could see. Your Sight uses only your own view. Show Everything "
			.. "keeps the classic full radar view.",
		["zh-cn"] = "选择雷达显示逻辑：小队视野：仅你或队友视野范围内敌人才会显示；自身视野：只显示你自己看见的敌人；全部显示：传统雷达模式，无视视野限制。",
	},
	marker_visibility_team_los = {
		en = "Squad Sight",
		["zh-cn"] = "小队共享视野",
	},
	marker_visibility_self_los = {
		en = "Your Sight Only",
		["zh-cn"] = "仅自身视野",
	},
	marker_visibility_all = {
		en = "Show Everything",
		["zh-cn"] = "全部显示",
	},
	show_sight_cones = {
		en = "Show Sight Cones",
		["zh-cn"] = "显示视野扇形区域",
	},
	show_sight_cones_tooltip = {
		en = "Draw the visible area in front of you, and in front of teammates when Marker Visibility is set to Squad Sight. "
			.. "Hidden automatically when Marker Visibility is set to Show Everything.",
		["zh-cn"] = "绘制你和队友的视野扇形区域（小队视野模式生效）；全部显示模式下自动关闭该选项。",
	},
	show_scanner_sweep = {
		en = "Show Radar Sweep Line",
		["zh-cn"] = "显示雷达扫描线",
	},
	show_scanner_sweep_tooltip = {
		en = "The animated sweep line on the Terminal and Auspex themes. Pure cosmetics - "
			.. "turn it off for a calmer panel.",
		["zh-cn"] = "终端与观测仪主题上的旋转扫描线，纯装饰效果；关闭后面板更简洁。",
	},
	integrate_objectives = {
		en = "Objectives On The Panel",
		["zh-cn"] = "任务目标整合到雷达面板",
	},
	integrate_objectives_tooltip = {
		en = "Draw the mission objective list as a themed strip attached to the Strikemap "
			.. "and hide the game's own tracker, so the two never overlap. "
			.. "Off: leave the vanilla objective tracker alone.",
		["zh-cn"] = "将任务目标列表以面板风格显示在雷达边缘，并隐藏游戏原生目标栏，避免两者重叠；关闭后保留原生目标栏。",
	},
	show_when_no_map = {
		en = "Show Without Map Data",
		["zh-cn"] = "缺失地形数据时仍然启用雷达",
	},
	show_when_no_map_tooltip = {
		en = "A few missions have no pre-baked floor plan yet. On: the panel still shows "
			.. "allies/enemies/objectives there (radar style). Off: hide the panel entirely.",
		["zh-cn"] = "部分关卡暂无预编译地形文件。开启后依旧以雷达形式显示敌人队友；关闭则隐藏整个雷达面板。",
	},
	floors_above = {
		en = "Metres Shown Above You",
		["zh-cn"] = "上方可显示高度（米）",
	},
	floors_above_tooltip = {
		en = "Geometry more than this many metres above your current walkable floor is hidden. Visible upper decks are kept faint so the active floor stays clear.",
		["zh-cn"] = "高于该数值的地形不会渲染，防止上层地形遮挡当前楼层。",
	},
	floors_below = {
		en = "Metres Shown Below You",
		["zh-cn"] = "下方可显示高度（米）",
	},
	floors_below_tooltip = {
		en = "Geometry more than this many metres below your current walkable floor is hidden. Lower decks fade darker with depth.",
		["zh-cn"] = "低于该数值的地形不会渲染。",
	},
	no_map_data = {
		en = "Strikemap: no map data for this mission",
		["zh-cn"] = "战术雷达：本关卡暂无地形数据",
	},
	expedition_live_map = {
		en = "Live Expedition Maps",
		["zh-cn"] = "远征实时地图",
	},
	expedition_live_map_tooltip = {
		en = "Build a floor plan for the procedurally assembled Wastes by composing known tiles and scanning each new section's live navigation mesh.",
		["zh-cn"] = "组合已知区块并扫描每个新区段的实时导航网格，为随机生成的荒原远征绘制地图。",
	},
	exp_scan_started = {
		en = "Strikemap: scanning expedition floor plan",
		["zh-cn"] = "战术雷达：正在扫描远征地图",
	},
	exp_compose_ready = {
		en = "Strikemap: expedition tiles composed",
		["zh-cn"] = "战术雷达：远征区块地图已组合",
	},
	exp_tiles_recorded = {
		en = "Strikemap: expedition tiles recorded",
		["zh-cn"] = "战术雷达：远征区块地图已记录",
	},
	hud_no_floor_plan = {
		en = "NO FLOOR PLAN - MARKERS ONLY",
		["zh-cn"] = "无地形数据 — 仅显示标记",
	},

	-- Allies & points of interest
	strikemap_allies = {
		en = "Allies & Objectives",
		["zh-cn"] = "队友与任务目标",
	},
	strikemap_items = {
		en = "Items & Stations",
		["zh-cn"] = "道具与功能站点",
	},
	show_teammates = {
		en = "Show Teammates",
		["zh-cn"] = "显示队友位置",
	},
	show_teammates_tooltip = {
		en = "Draw a marker for each teammate (clamped to the map edge when far away).",
		["zh-cn"] = "为队友生成标记，距离过远时图标固定在地图边缘。",
	},
	ally_style = {
		en = "Teammate Marker Style",
		["zh-cn"] = "队友标记样式",
	},
	ally_style_tooltip = {
		en = "Class Icon uses each teammate's Veteran, Zealot, Psyker, Ogryn, Arbites or Hive Scum symbol. Legacy shapes remain available.",
		["zh-cn"] = "选择队友图标的形状或内置图标。",
	},
	ally_color_mode = {
		en = "Teammate Colours",
		["zh-cn"] = "队友颜色模式",
	},
	ally_color_mode_tooltip = {
		en = "Player Colours matches the game's party slot colours; Fixed uses the colour below.",
		["zh-cn"] = "玩家默认色：沿用游戏队伍槽位颜色；固定颜色：使用下方自定义颜色。",
	},
	ally_color_mode_slot = {
		en = "Player Colours",
		["zh-cn"] = "游戏默认玩家色",
	},
	ally_color_mode_fixed = {
		en = "Fixed Colour",
		["zh-cn"] = "固定颜色",
	},
	ally_color = {
		en = "Teammate Colour (Fixed)",
		["zh-cn"] = "队友固定颜色",
	},
	ally_color_tooltip = {
		en = "Marker colour used when Teammate Colours is set to Fixed.",
		["zh-cn"] = "颜色模式选择固定颜色时生效。",
	},
	show_player_pings = {
		en = "Show Player Pings",
		["zh-cn"] = "显示玩家标记",
	},
	show_player_pings_tooltip = {
		en = "Mirror player smart tags onto the radar as pulsing rings in the pinging player's colour, with item icons for tagged pickups.",
		["zh-cn"] = "雷达上显示玩家标记，使用标记者的颜色绘制脉冲圆环，拾取道具会附带对应图标。",
	},
	show_objectives = {
		en = "Show Objectives",
		["zh-cn"] = "显示任务目标",
	},
	show_objectives_tooltip = {
		en = "Mirror the game's live objective markers onto the map.",
		["zh-cn"] = "在雷达同步显示游戏原生任务目标标记。",
	},
	show_live_gates = {
		en = "Show Live Route Changes",
	},
	show_live_gates_tooltip = {
		en = "Draw closed doors and objective-sealed paths as tactical barriers. Routes pulse when they lock, unlock or open during the mission.",
	},
	show_tactical_updates = {
		en = "Show Tactical Event Updates",
	},
	show_tactical_updates_tooltip = {
		en = "Flash objective areas when access is granted or extraction opens, and animate recently changed route geometry.",
	},
	objective_style = {
		en = "Objective Marker Style",
		["zh-cn"] = "目标标记样式",
	},
	objective_style_tooltip = {
		en = "Game objective icon, or a plain diamond.",
		["zh-cn"] = "选择游戏原版图标或是菱形标记。",
	},
	objective_color = {
		en = "Objective Colour",
		["zh-cn"] = "目标标记颜色",
	},
	objective_color_tooltip = {
		en = "Tint for objective markers.",
		["zh-cn"] = "自定义任务目标图标的颜色。",
	},
	show_medicae = {
		en = "Show Medicae Stations",
		["zh-cn"] = "显示医疗站",
	},
	show_medicae_tooltip = {
		en = "Mark medicae stations on the map.",
		["zh-cn"] = "在雷达地图标注医疗站位置。",
	},
	medicae_style = {
		en = "Medicae Marker Style",
		["zh-cn"] = "医疗站标记样式",
	},
	medicae_style_tooltip = {
		en = "Game health icon, or a plain cross.",
		["zh-cn"] = "游戏原版生命图标或者十字图标。",
	},
	medicae_color = {
		en = "Medicae Colour",
		["zh-cn"] = "医疗站颜色",
	},
	medicae_color_tooltip = {
		en = "Tint for medicae markers.",
		["zh-cn"] = "自定义医疗站图标的颜色。",
	},

	-- Enemies
	strikemap_enemies = {
		en = "Enemies",
		["zh-cn"] = "敌人设置",
	},
	show_monsters = {
		en = "Show Monsters & Bosses",
		["zh-cn"] = "显示巨兽与首领",
	},
	show_monsters_tooltip = {
		en = "Monstrosities, captains and daemonhosts near you.",
		["zh-cn"] = "显示巨兽、队长以及恶魔宿主等高级敌人。",
	},
	monster_icon = {
		en = "Monster Marker Style",
		["zh-cn"] = "巨兽标记样式",
	},
	monster_icon_tooltip = {
		en = "Icon or shape used for monster markers.",
		["zh-cn"] = "选择巨兽敌人使用的图标或形状。",
	},
	monster_color = {
		en = "Monster Colour",
		["zh-cn"] = "巨兽标记颜色",
	},
	monster_color_tooltip = {
		en = "Tint for monster markers.",
		["zh-cn"] = "自定义巨兽图标的颜色。",
	},
	show_specials = {
		en = "Show Specialists",
		["zh-cn"] = "显示特殊敌人",
	},
	show_specials_tooltip = {
		en = "Disablers, snipers, bombers and other specialists near you.",
		["zh-cn"] = "显示束缚者、狙击手、投弹兵等特殊敌人。",
	},
	special_icon = {
		en = "Specialist Marker Style",
		["zh-cn"] = "特殊敌人标记样式",
	},
	special_icon_tooltip = {
		en = "Icon or shape used for specialist markers.",
		["zh-cn"] = "选择特殊敌人的图标或形状。",
	},
	special_color = {
		en = "Specialist Colour",
		["zh-cn"] = "特殊敌人颜色",
	},
	special_color_tooltip = {
		en = "Tint for specialist markers.",
		["zh-cn"] = "自定义特殊敌人图标的颜色。",
	},
	show_elites = {
		en = "Show Elites",
		["zh-cn"] = "显示精英敌人",
	},
	show_elites_tooltip = {
		en = "Crushers, ragers, gunners and other elites near you.",
		["zh-cn"] = "显示粉碎者、狂战士、重机枪手等精英敌人。",
	},
	elite_icon = {
		en = "Elite Marker Style",
		["zh-cn"] = "精英敌人标记样式",
	},
	elite_icon_tooltip = {
		en = "Icon or shape used for elite markers.",
		["zh-cn"] = "选择精英敌人使用的图标或形状。",
	},
	elite_color = {
		en = "Elite Colour",
		["zh-cn"] = "精英敌人颜色",
	},
	elite_color_tooltip = {
		en = "Tint for elite markers.",
		["zh-cn"] = "自定义精英敌人图标的颜色。",
	},
	show_horde = {
		en = "Show Horde / Other Enemies",
		["zh-cn"] = "显示潮杂兵敌人",
	},
	show_horde_tooltip = {
		en = "Every other nearby enemy. Turn off if the map feels cluttered.",
		["zh-cn"] = "显示普通感染者等杂兵，如果地图标记过于拥挤可以关闭。",
	},
	horde_color = {
		en = "Horde Colour",
		["zh-cn"] = "杂兵敌人颜色",
	},
	horde_color_tooltip = {
		en = "Tint for horde and other basic enemy markers.",
		["zh-cn"] = "普通杂兵敌人的图标颜色。",
	},
	horde_icon = {
		en = "Horde Marker Style",
		["zh-cn"] = "杂兵标记样式",
	},
	horde_icon_tooltip = {
		en = "Icon or shape used for horde and other basic enemy markers.",
		["zh-cn"] = "选择杂兵敌人使用的图标或形状。",
	},
	strikemap_enemy_types = {
		en = "Enemy Types",
		["zh-cn"] = "细分敌人样式",
	},
	enemy_type_overrides = {
		en = "Use Enemy Type Icons & Colours",
		["zh-cn"] = "为每种敌人单独设置图标与颜色",
	},
	enemy_type_overrides_tooltip = {
		en = "Off: enemies use the clean broad radar theme from the Enemies tab. "
			.. "On: known enemy breeds use the individual icon and colour settings below.",
		["zh-cn"] = "关闭：敌人统一采用上方大类设置；开启：单独为每种敌人配置专属图标和颜色。",
	},
	enemy_type_icon_tooltip = {
		en = "Icon or shape used for this enemy type.",
		["zh-cn"] = "选择该敌人种类对应的图标形状。",
	},
	enemy_type_color_tooltip = {
		en = "Tint used for this enemy type.",
		["zh-cn"] = "设置该敌人种类对应的颜色。",
	},

	enemy_type_scale_tooltip = {
		-- DMF runs every localization string through string.format, even when
		-- there are no interpolation arguments. Escape literal percent signs.
		en = "Size of this enemy type's marker (100%% is the category default).",
		["zh-cn"] = "该敌人标记尺寸（100%%为分类默认大小）。",
	},

	-- Marker style option labels
	style_skull = {
		en = "Skull Icon",
		["zh-cn"] = "骷髅图标",
	},
	style_enemy = {
		en = "Enemy Icon",
		["zh-cn"] = "敌人专用图标",
	},
	style_enemy_priority = {
		en = "Priority Enemy Icon",
		["zh-cn"] = "高危敌人图标",
	},
	style_icon = {
		en = "Game Icon",
		["zh-cn"] = "游戏原版图标",
	},
	style_class_icon = {
		en = "Class Icon",
		["zh-cn"] = "职业图标",
	},
	style_dot = {
		en = "Dot",
		["zh-cn"] = "圆点",
	},
	style_diamond = {
		en = "Diamond",
		["zh-cn"] = "菱形",
	},
	style_cross = {
		en = "Cross",
		["zh-cn"] = "十字形",
	},
	style_ring = {
		en = "Ring",
		["zh-cn"] = "圆环",
	},
	style_square = {
		en = "Square",
		["zh-cn"] = "方形",
	},
	style_triangle = {
		en = "Triangle",
		["zh-cn"] = "三角形",
	},

	-- Performance
	strikemap_performance = {
		en = "Performance",
		["zh-cn"] = "性能设置",
	},
	perf_enemy_scan_range = {
		en = "Enemy Scan Range",
		["zh-cn"] = "敌人扫描范围",
	},
	perf_enemy_scan_range_tooltip = {
		en = "How far (in meters) the mod scans for enemies around you. Shorter range means fewer tracked enemies and fewer line-of-sight checks - the single biggest performance lever. Markers beyond this range simply don't appear.",
		["zh-cn"] = "模组扫描周围敌人的距离（米）。范围越小，需要追踪的敌人和视线检测就越少——这是最重要的性能选项。超出范围的敌人标记不会显示。",
	},
	perf_enemy_tick = {
		en = "Enemy Update Rate",
		["zh-cn"] = "敌人刷新频率",
	},
	perf_enemy_tick_tooltip = {
		en = "How often enemy positions and line-of-sight refresh. Relaxed roughly halves scan cost; enemy dots update slightly less smoothly. Map geometry and your own marker always stay per-frame smooth.",
		["zh-cn"] = "敌人位置与视线检测的刷新频率。宽松档大约减半扫描开销；敌人标记的移动会略微不那么流畅。地图本身和你自己的标记始终逐帧流畅更新。",
	},
	perf_tick_fast = {
		en = "Fast (0.15 s)",
		["zh-cn"] = "快速（0.15秒）",
	},
	perf_tick_balanced = {
		en = "Balanced (0.25 s)",
		["zh-cn"] = "均衡（0.25秒）",
	},
	perf_tick_relaxed = {
		en = "Relaxed (0.4 s)",
		["zh-cn"] = "宽松（0.4秒）",
	},
	perf_horde_los = {
		en = "Horde Line-of-Sight",
		["zh-cn"] = "杂兵视线检测",
	},
	perf_horde_los_tooltip = {
		en = "Precise fires an occlusion raycast per horde enemy - the bulk of all raycasts during waves. Cheap (default) uses view-cone and range only for horde dots; specials, elites and monsters always keep precise checks.",
		["zh-cn"] = "精确模式对每个杂兵发射遮挡射线——尸潮期间的大部分射线开销都来自于此。省电模式（默认）对杂兵仅使用视锥和距离判断；特殊敌人、精英和怪物始终保持精确检测。",
	},
	perf_los_cone = {
		en = "Cheap (cone + range)",
		["zh-cn"] = "省电（视锥+距离）",
	},
	perf_los_raycast = {
		en = "Precise (raycast)",
		["zh-cn"] = "精确（射线检测）",
	},
	perf_map_tri_budget = {
		en = "Minimap Detail Budget",
		["zh-cn"] = "小地图细节上限",
	},
	perf_map_tri_budget_tooltip = {
		en = "Caps how many floor triangles the corner minimap draws per frame. When the cap is hit, the farthest geometry is dropped first - the area around you always draws. Lower caps help most at high zoom-out.",
		["zh-cn"] = "限制小地图每帧绘制的地面三角形数量。达到上限时优先舍弃最远处的地形——你周围的区域始终完整绘制。缩小视野倍率较高时，较低的上限效果最明显。",
	},
	perf_tris_400 = {
		en = "400 triangles",
		["zh-cn"] = "400 三角形",
	},
	perf_tris_900 = {
		en = "900 triangles",
		["zh-cn"] = "900 三角形",
	},
	perf_tris_1400 = {
		en = "1400 triangles",
		["zh-cn"] = "1400 三角形",
	},
	perf_tris_unlimited = {
		en = "Unlimited",
		["zh-cn"] = "无限制",
	},
	perf_fullmap_fidelity = {
		en = "Full-Screen Map Fidelity",
		["zh-cn"] = "全屏地图画质",
	},
	perf_fullmap_fidelity_tooltip = {
		en = "High draws the full-screen tactical map with drop shadows and surface relief. Low skips those passes and caps geometry - far cheaper on large open missions while the overview is open.",
		["zh-cn"] = "高画质：全屏战术地图带投影与表面起伏效果。低画质：跳过这些绘制并限制几何数量——在大型开阔任务中打开全屏地图时开销低得多。",
	},
	perf_effects_quality = {
		en = "Panel Effects Quality",
		["zh-cn"] = "面板特效画质",
	},
	perf_effects_quality_tooltip = {
		en = "Quality of the cosmetic panel effects: rear fade, player glow and round/ghost theme chrome. Low halves their draw cost; Off removes them entirely. Map data is never affected.",
		["zh-cn"] = "装饰性面板特效（后方渐隐、玩家光晕、圆形/幽灵主题外框）的画质。低画质减半绘制开销；关闭则完全移除。不影响任何地图信息。",
	},
	perf_quality_high = {
		en = "High",
		["zh-cn"] = "高",
	},
	perf_quality_low = {
		en = "Low",
		["zh-cn"] = "低",
	},
	perf_quality_off = {
		en = "Off",
		["zh-cn"] = "关闭",
	},
	perf_ally_status_rate = {
		en = "Ally Status Update Rate",
		["zh-cn"] = "队友状态刷新频率",
	},
	perf_ally_status_rate_tooltip = {
		en = "How often teammate health, badges and state are re-read. Positions and facing always update every frame - only the status probes throttle. 10/s is visually identical to every-frame.",
		["zh-cn"] = "队友血量、徽章和状态的重新读取频率。位置与朝向始终逐帧更新——仅状态探测受此限制。每秒10次与逐帧在视觉上没有区别。",
	},
	perf_status_every_frame = {
		en = "Every frame",
		["zh-cn"] = "逐帧",
	},
	perf_status_10hz = {
		en = "10 / second",
		["zh-cn"] = "每秒10次",
	},
	perf_status_4hz = {
		en = "4 / second",
		["zh-cn"] = "每秒4次",
	},
	perf_report_autosave = {
		en = "Debrief Autosave Interval",
		["zh-cn"] = "复盘自动保存间隔",
	},
	perf_report_autosave_tooltip = {
		en = "How often the in-progress Mission Debrief is saved to disk during a mission (crash protection). Longer intervals remove a periodic micro-stutter on long runs. The report always saves at mission end regardless.",
		["zh-cn"] = "任务进行中复盘数据写入磁盘的频率（防崩溃保护）。更长的间隔可消除长时间对局中的周期性微卡顿。无论如何设置，任务结束时都会完整保存。",
	},
	perf_autosave_30 = {
		en = "Every 30 s",
		["zh-cn"] = "每30秒",
	},
	perf_autosave_60 = {
		en = "Every 60 s",
		["zh-cn"] = "每60秒",
	},
	perf_autosave_end = {
		en = "Mission end only",
		["zh-cn"] = "仅任务结束时",
	},
	perf_combat_tracking = {
		en = "Detailed Combat Stats",
		["zh-cn"] = "详细战斗统计",
	},
	perf_combat_tracking_tooltip = {
		en = "Tracks per-hit combat detail (weakspot %%, crit %%, damage attribution) for the Mission Debrief. Runs on every hit by every player, so turning it off helps during dense hordes. Kills, paths, downs and the rest of the Debrief keep working.",
		["zh-cn"] = "为任务复盘记录逐次命中的战斗细节（弱点率、暴击率、伤害归属）。每名玩家的每次命中都会触发，关闭后在密集尸潮中有助于性能。击杀、路线、倒地等其余复盘功能不受影响。",
	},
	perf_debrief_tri_budget = {
		en = "Debrief Map Detail",
		["zh-cn"] = "复盘地图细节",
	},
	perf_debrief_tri_budget_tooltip = {
		en = "Triangle budget for the Mission Debrief's 3D map render. Only affects the Debrief screen, never gameplay.",
		["zh-cn"] = "任务复盘3D地图渲染的三角形上限。仅影响复盘界面，不影响游戏过程。",
	},
	perf_tris_3000 = {
		en = "3000 triangles",
		["zh-cn"] = "3000 三角形",
	},
	perf_tris_6000 = {
		en = "6000 triangles",
		["zh-cn"] = "6000 三角形",
	},
	perf_tris_12000 = {
		en = "12000 triangles",
		["zh-cn"] = "12000 三角形",
	},
	perf_debrief_heat_cell = {
		en = "Heatmap Resolution",
		["zh-cn"] = "热力图分辨率",
	},
	perf_debrief_heat_cell_tooltip = {
		en = "Cell size for Debrief heatmaps. Coarse quarters the cell count - useful on very long missions. Only affects the Debrief screen.",
		["zh-cn"] = "复盘热力图的网格大小。粗糙档将格子数量减为四分之一——适合超长任务。仅影响复盘界面。",
	},
	perf_heat_fine = {
		en = "Fine (4 m cells)",
		["zh-cn"] = "精细（4米格）",
	},
	perf_heat_coarse = {
		en = "Coarse (8 m cells)",
		["zh-cn"] = "粗糙（8米格）",
	},

	-- Keybinds
	strikemap_keybinds = {
		en = "Keybinds",
		["zh-cn"] = "快捷键设置",
	},
	kb_toggle_strikemap = {
		en = "Toggle Strikemap",
		["zh-cn"] = "开启/关闭迷你雷达",
	},
	kb_toggle_fullmap = {
		en = "Toggle Full Map",
		["zh-cn"] = "开启/关闭全屏战术地图",
	},
	kb_zoom_in = {
		en = "Zoom In",
		["zh-cn"] = "放大雷达视野",
	},
	kb_zoom_out = {
		en = "Zoom Out",
		["zh-cn"] = "缩小雷达视野",
	},
	kb_toggle_reports = {
		en = "Open/Close Mission Reports",
		["zh-cn"] = "打开/关闭对局复盘面板",
	},

	-- External minimap integration (compatibility API)
	strikemap_compat = {
		en = "External Minimap Integration",
		["zh-cn"] = "外部小地图联动",
	},
	compat_api_enabled = {
		en = "Allow External Mods to Use Strikemap Geometry",
		["zh-cn"] = "允许外部模组使用 Strikemap 地形数据",
	},
	compat_api_enabled_tooltip = {
		en = "Expose the current mission's Strikemap geometry through a public "
			.. "compatibility API. External mods must still be installed and enabled separately.",
		["zh-cn"] = "通过公共兼容接口向外部模组提供当前任务的 Strikemap 地形数据；外部模组仍需单独安装并启用。",
	},
	compat_geometry_only = {
		en = "Geometry-Only Mode",
		["zh-cn"] = "仅地形模式",
	},
	compat_geometry_only_tooltip = {
		en = "Keep Strikemap map loading and mission recording active, but disable "
			.. "Strikemap's own live minimap markers and HUD rendering. Intended for use "
			.. "with compatible external minimap mods such as Radar.",
		["zh-cn"] = "保留地图加载与对局记录，但关闭 Strikemap 自身的实时小地图标记与 HUD 渲染；供 Radar 等兼容的外部小地图模组使用。",
	},
	compat_auto_geometry_only = {
		en = "Auto-Disable Minimap for External Renderers",
		["zh-cn"] = "检测到外部渲染器时自动关闭小地图",
	},
	compat_auto_geometry_only_tooltip = {
		en = "Switch into Geometry-Only Mode automatically while an external minimap mod "
			.. "is registered through the compatibility API. Off (default): geometry-only "
			.. "mode is controlled manually with the setting above.",
		["zh-cn"] = "当外部小地图模组通过兼容接口注册后，自动进入仅地形模式；关闭（默认）时仅由上方选项手动控制。",
	},
}

-- Colour option labels (color_red, color_orange, ...)
local COLOR_LABELS = {
	red = "Red",
	crimson = "Crimson",
	scarlet = "Scarlet",
	vermilion = "Vermilion",
	coral = "Coral",
	salmon = "Salmon",
	orange = "Orange",
	tangerine = "Tangerine",
	amber = "Amber",
	gold = "Gold",
	yellow = "Yellow",
	lemon = "Lemon",
	chartreuse = "Chartreuse",
	lime = "Lime",
	green = "Green",
	emerald = "Emerald",
	jade = "Jade",
	mint = "Mint",
	teal = "Teal",
	turquoise = "Turquoise",
	cyan = "Cyan",
	aqua = "Aqua",
	sky = "Sky",
	azure = "Azure",
	blue = "Blue",
	cobalt = "Cobalt",
	indigo = "Indigo",
	violet = "Violet",
	purple = "Purple",
	plum = "Plum",
	magenta = "Magenta",
	pink = "Pink",
	hot_pink = "Hot Pink",
	rose = "Rose",
	lavender = "Lavender",
	white = "White",
	ivory = "Ivory",
	silver = "Silver",
	steel = "Steel",
}

-- zh-cn colour names (contributed translation)
local COLOR_LABELS_CN = {
	red = "红色",
	crimson = "深红",
	scarlet = "猩红",
	vermilion = "朱红",
	coral = "珊瑚色",
	salmon = "三文鱼色",
	orange = "橙色",
	tangerine = "橘黄",
	amber = "琥珀色",
	gold = "金色",
	yellow = "黄色",
	lemon = "柠檬黄",
	chartreuse = "嫩绿色",
	lime = "青柠色",
	green = "绿色",
	emerald = "翠绿",
	jade = "玉绿色",
	mint = "薄荷绿",
	teal = "青绿色",
	turquoise = "绿松石色",
	cyan = "青色",
	aqua = "水蓝色",
	sky = "天蓝色",
	azure = "蔚蓝色",
	blue = "蓝色",
	cobalt = "钴蓝色",
	indigo = "靛蓝",
	violet = "紫罗兰色",
	purple = "紫色",
	plum = "梅子紫",
	magenta = "品红色",
	pink = "粉色",
	hot_pink = "艳粉色",
	rose = "玫瑰色",
	lavender = "薰衣草紫",
	white = "白色",
	ivory = "象牙白",
	silver = "银色",
	steel = "钢灰色",
}

for name, label in pairs(COLOR_LABELS) do
	loc["color_" .. name] = {
		en = label,
		["zh-cn"] = COLOR_LABELS_CN[name],
	}
end

local ENEMY_TYPE_LABELS = {
	chaos_poxwalker = "Poxwalker",
	chaos_newly_infected = "Newly Infected",
	chaos_lesser_mutated_poxwalker = "Mutated Poxwalker",
	chaos_mutated_poxwalker = "Tentacled Poxwalker",
	chaos_armored_infected = "Moebian 21st Infected",
	renegade_melee = "Scab Bruiser",
	renegade_assault = "Scab Stalker",
	renegade_rifleman = "Scab Shooter",
	cultist_melee = "Dreg Bruiser",
	cultist_assault = "Dreg Stalker",
	cultist_rifleman = "Dreg Shooter",
	renegade_executor = "Scab Mauler",
	chaos_ogryn_executor = "Crusher",
	chaos_ogryn_bulwark = "Bulwark",
	chaos_ogryn_gunner = "Reaper",
	renegade_berzerker = "Scab Rager",
	cultist_berzerker = "Dreg Rager",
	renegade_gunner = "Scab Gunner",
	cultist_gunner = "Dreg Gunner",
	renegade_shocktrooper = "Scab Shotgunner",
	cultist_shocktrooper = "Dreg Shotgunner",
	renegade_plasma_gunner = "Scab Plasma Gunner",
	renegade_flamer = "Scab Flamer",
	cultist_flamer = "Tox Flamer",
	renegade_netgunner = "Trapper",
	renegade_grenadier = "Bomber",
	cultist_grenadier = "Tox Bomber",
	renegade_sniper = "Sniper",
	cultist_mutant = "Mutant",
	chaos_hound = "Pox Hound",
	chaos_armored_hound = "Armoured Hound",
	chaos_ogryn_houndmaster = "Houndmaster",
	chaos_poxwalker_bomber = "Poxburster",
	chaos_plague_ogryn = "Plague Ogryn",
	chaos_spawn = "Chaos Spawn",
	chaos_beast_of_nurgle = "Beast of Nurgle",
	chaos_daemonhost = "Daemonhost",
	renegade_captain = "Scab Captain",
	cultist_captain = "Dreg Captain",
	renegade_twin_captain = "Scab Twin",
	cultist_twin_captain = "Dreg Twin",
	renegade_radio_operator = "Radio Operator",
	cultist_ritualist = "Ritualist",
}

-- zh-cn breed names (contributed translation)
local ENEMY_TYPE_LABELS_CN = {
	chaos_poxwalker = "瘟疫行尸",
	chaos_newly_infected = "呻吟者",
	chaos_lesser_mutated_poxwalker = "变异瘟疫行尸",
	chaos_mutated_poxwalker = "触须瘟疫行尸",
	chaos_armored_infected = "莫比安21团格斗兵",
	renegade_melee = "血痂格斗兵",
	renegade_assault = "血痂潜行者",
	renegade_rifleman = "血痂步枪兵",
	cultist_melee = "渣滓格斗兵",
	cultist_assault = "渣滓潜行者",
	cultist_rifleman = "渣滓步枪兵",
	renegade_executor = "血痂重锤兵",
	chaos_ogryn_executor = "粉碎者",
	chaos_ogryn_bulwark = "盾卫",
	chaos_ogryn_gunner = "收割者",
	renegade_berzerker = "血痂狂战士",
	cultist_berzerker = "渣滓狂战士",
	renegade_gunner = "血痂炮手",
	cultist_gunner = "渣滓重机枪手",
	renegade_shocktrooper = "血痂霰弹兵",
	cultist_shocktrooper = "渣滓霰弹兵",
	renegade_plasma_gunner = "血痂等离子枪手",
	renegade_flamer = "血痂火焰兵",
	cultist_flamer = "渣滓喷火兵",
	renegade_netgunner = "血痂陷阱手",
	renegade_grenadier = "血痂轰炸者",
	cultist_grenadier = "渣滓剧毒轰炸者",
	renegade_sniper = "血痂狙击手",
	cultist_mutant = "变种人",
	chaos_hound = "瘟疫猎犬",
	chaos_armored_hound = "装甲瘟疫猎犬",
	chaos_ogryn_houndmaster = "猎群大师",
	chaos_poxwalker_bomber = "自爆感染者",
	chaos_plague_ogryn = "瘟疫欧格林",
	chaos_spawn = "混沌魔物",
	chaos_beast_of_nurgle = "纳垢兽",
	chaos_daemonhost = "恶魔宿主",
	renegade_captain = "血痂连长",
	cultist_captain = "渣滓连长",
	renegade_twin_captain = "血痂双子连长",
	cultist_twin_captain = "渣滓双子连长",
	renegade_radio_operator = "通讯兵",
	cultist_ritualist = "渣滓仪式师",
}

for key, label in pairs(ENEMY_TYPE_LABELS) do
	local prefix = "enemy_type_" .. key
	local cn = ENEMY_TYPE_LABELS_CN[key]

	loc[prefix .. "_icon"] = {
		en = label .. " Icon",
		["zh-cn"] = cn and (cn .. "图标") or nil,
	}
	loc[prefix .. "_color"] = {
		en = label .. " Colour",
		["zh-cn"] = cn and (cn .. "颜色") or nil,
	}
	loc[prefix .. "_scale"] = {
		en = label .. " Scale (%%)",
		["zh-cn"] = cn and (cn .. "大小 (%%)") or nil,
	}
end

return loc
