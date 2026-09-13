-- Pilgrimage_localization.lua
--
-- All player-visible strings. Keys match setting_ids by convention, with a
-- _tooltip suffix for the hover text, so the data file can derive them.
-- Simplified Chinese was contributed for v0.28.72 and lightly edited for
-- Warhammer terminology. The release regression suite checks that each future
-- entry retains both an English source string and a zh-cn translation.

local function title(text)
	-- Darktide's UI colour markup. Amber for group headers matches the terminal look.
	return "{#color(200,140,20)}" .. text .. "{#reset()}"
end

return {
	mod_name = {
		-- The Mod Options font does not contain U+2726 BLACK FOUR POINTED STAR.
		-- U+2605 BLACK STAR is already used successfully by other entries in this
		-- same screen, so it keeps the ornament without fallback-box glyphs.
		en = "{#color(239,193,82)}★ Pilgrimage ★{#reset()}",
		["zh-cn"] = "{#color(239,193,82)}★ 朝圣远征 ★{#reset()}",
	},
	mod_description = {
		en = "A roguelite expedition mode. Chain missions into a single run, gaining " ..
		     "boons and curses along the way. Experimental co-op is available through Realms.",
		["zh-cn"] = "肉鸽远征模式。将多个任务串联为一轮游玩，途中获取增益与诅咒。可通过 Realms 使用实验性合作模式。",
	},

	curses_havoc_pool = {
		en = "Havoc curses",
		["zh-cn"] = "浩劫诅咒池",
	},
	curses_havoc_pool_tooltip = {
		en = "Allow curses borrowed from Havoc's modifier list, such as Cranial " ..
		     "Corruption and Stimmed Foes. Turn this off if a Havoc curse misbehaves " ..
		     "in a normal mission. Only the explicit modifiers are used; Havoc's " ..
		     "hidden penalties to ammo, health and toughness are never applied.",
		["zh-cn"] = "允许使用取自浩劫模式的诅咒词条，例如颅骨腐化、强化敌人。如果某条浩劫诅咒在普通任务中出现异常，请关闭此项。仅会启用明确列出的词条；浩劫模式内置的弹药、生命值与韧性隐藏惩罚不会生效。",
	},

	curses_stacking = {
		en = "Curses stack across the run",
		["zh-cn"] = "诅咒在整轮中叠加生效",
	},
	curses_stacking_tooltip = {
		en = "Each assignment keeps the curses of every assignment before it, the way " ..
		     "boons do. Assignment 3 runs its own curse plus the modifiers of " ..
		     "assignments 1 and 2. Turn this off to run only each assignment's own " ..
		     "curse.",
		["zh-cn"] = "每个任务会继承之前所有任务的诅咒，与增益机制一致。第3个任务会携带自身诅咒外加第1、2任务的全部词条。关闭后仅生效当前任务自身的诅咒。",
	},

	enable_overlay_panel = {
		en = "Pilgrimage panel on the tactical overlay",
		["zh-cn"] = "战术界面显示朝圣远征面板",
	},
	enable_overlay_panel_tooltip = {
		en = "While holding the tactical overlay key (TAB by default) during a " ..
		     "pilgrimage, a small translucent panel in the top right shows the " ..
		     "current assignment, its conditions (including stacked ones), whether " ..
		     "their modifiers are verified live, and what comes next.",
		["zh-cn"] = "进行朝圣远征时，按住战术界面按键（默认Tab），右上角会显示半透明面板，展示当前任务、全部叠加条件、词条实时校验状态以及后续任务。",
	},

	-- v0.23.4: the starting_difficulty widget and its option labels are gone.
	-- Difficulty has been governed by the selected War Plan since the plans
	-- shipped; the dropdown only ever fed debug fallbacks.

	-- v0.23.4: enable_blitz_mode had a widget since the auto-chain rework but
	-- never got loc entries, so the checkbox showed a raw key with no tooltip.
	enable_blitz_mode = {
		en = "Blitz mode (auto-launch next assignment)",
		["zh-cn"] = "闪击模式（自动开启下一任务）",
	},
	enable_blitz_mode_tooltip = {
		en = "When an assignment is completed, the next one launches by itself " ..
		     "after the return to the Mourningstar, banner and all. With this " ..
		     "off, the road waits: you visit the terminal and press Continue " ..
		     "when ready. The choice is locked in when a run starts, so " ..
		     "flipping it mid-run affects the next run, not the current one.",
		["zh-cn"] = "任务完成后返回哀星号，会自动启动下一任务（含全部过场）。关闭后需前往终端手动点击「继续」。该选项在远征开始后锁定，中途修改仅对下一轮生效。",
	},

	-- v0.23.4: curses_live_event_pool also had a widget without loc entries.
	curses_live_event_pool = {
		en = "Live-event curses",
		["zh-cn"] = "限时活动诅咒池",
	},
	curses_live_event_pool_tooltip = {
		en = "Allow curses borrowed from past live events, such as Shambling " ..
		     "Pyres. These lean on mutators Fatshark can retire between " ..
		     "patches, so if a condition stops applying after a game update, " ..
		     "turn this off to isolate it. Existence is also verified at draw " ..
		     "time, so a retired curse is skipped rather than promised.",
		["zh-cn"] = "允许使用过往限时活动的诅咒，例如蹒跚火葬堆。这类词条依赖官方可随时移除的变异器，游戏更新后如果某词条失效，可以关闭此项排查问题。抽取时会校验有效性，已移除的诅咒会直接跳过不会被选中。",
	},

	fx_guard = {
		en = "Protect against missing boon effects",
		["zh-cn"] = "增益特效缺失防护",
	},
	-- v0.25.1 (technique credit: augentism, Chaos Wastes at Home).
	fx_full_visuals = {
		en = "Full boon visuals",
		["zh-cn"] = "完整增益视觉特效",
	},
	fx_full_visuals_tooltip = {
		en = "Load the Mortis Trials effect package alongside each " ..
		     "assignment so boon visual effects actually display, instead " ..
		     "of being safely skipped. Costs a little extra loading time " ..
		     "and memory. Turn off on memory-constrained machines; boons " ..
		     "keep working either way, only the flashes differ.",
		["zh-cn"] = "每个任务加载莫提斯试炼特效包，完整显示增益特效，而不是安全跳过。会增加加载时间与内存占用。内存不足设备请关闭；关闭后增益功能正常，仅缺失特效表现。",
	},
	fx_guard_tooltip = {
		en = "Some boon visual effects only exist in the Mortis Trials levels. " ..
		     "Spawning one in a normal mission crashes the game, so this skips " ..
		     "any effect the mission provably cannot show. The boon itself still " ..
		     "works, only that flash is missing. Turning this off restores the " ..
		     "crash, so leave it on unless you are testing.",
		["zh-cn"] = "部分增益特效仅存在于莫提斯试炼关卡，在普通任务生成会直接崩溃。本选项会跳过当前关卡无法渲染的特效。增益本身功能不受影响，仅缺失特效。关闭此项会恢复崩溃问题，仅调试时可关闭。",
	},

	curses_guard = {
		en = "Verify curses apply in the mission",
		["zh-cn"] = "校验任务诅咒生效状态",
	},
	curses_guard_tooltip = {
		en = "Loading a mission resets the game's scripts, which can silently drop " ..
		     "the assignment's curse. This checks the curse the mission is about to " ..
		     "run against the one the launch asked for, restores it if the game " ..
		     "lost it, and shows one line confirming which modifiers are active. " ..
		     "Only ever acts in your own solo assignments, never in public games.",
		["zh-cn"] = "加载任务会重置游戏脚本，有可能无声丢失诅咒词条。该功能会比对实际运行与预期的诅咒，丢失时自动恢复，并打印一行提示显示当前生效词条。仅在你的单人远征生效，不会影响公开匹配对局。",
	},

	-- Groups -----------------------------------------------------------------
	group_run = {
		en = title("Run"),
		["zh-cn"] = title("远征设置"),
	},
	group_terminal = {
		en = title("Terminal"),
		["zh-cn"] = title("终端设置"),
	},
	group_diagnostics = {
		en = title("Diagnostics"),
		["zh-cn"] = title("诊断调试"),
	},
	group_debug = {
		en = title("Debug shortcuts"),
		["zh-cn"] = title("调试快捷键"),
	},

	capture_target_preset = {
		en = "Capture-all target preset",
		["zh-cn"] = "一键捕获目标预设",
	},
	capture_target_preset_tooltip = {
		en = "The preset the capture-all keybind acts on. Add your intended character " ..
		     "to Character Select, load into it so the game caches its profile, then " ..
		     "press the keybind. The character, exact loadout, NPC Look, Personality Picker " ..
		     "voice, and EWC weapons are pinned when their optional mods are installed. " ..
		     "The keybind does the same " ..
		     "thing as /pil_preset_capture_all in chat.",
		["zh-cn"] = "一键捕获快捷键作用的目标预设。将目标角色添加到角色选择列表并进入游戏让缓存生效，再按下快捷键。若安装对应依赖模组，角色、配装、NPC外观、性格语音、EWC武器都会被固化。该快捷键等价于聊天指令 /pil_preset_capture_all。",
	},
	-- Capture labels show tier, display_name and role_designation for every
	-- preset. Internal ids (the key suffix) are historical and never
	-- change so saved captures stay valid across the renames.
	capture_target_none = {
		en = "None (keybind disabled)",
		["zh-cn"] = "无（快捷键禁用）",
	},
	capture_target_seneschal_abelard = {
		en = "T3  |  Abelard Werserian (Dynastic Seneschal)",
		["zh-cn"] = "T3 ｜ 阿贝拉德·韦尔塞里安（王朝总管）",
	},
	capture_target_ogryn_gunlugger = {
		en = "T3  |  Boss Grudd (Ogryn Crime Lord)",
		["zh-cn"] = "T3 ｜ 格鲁德头目（欧格林犯罪头目）",
	},
	capture_target_spyer = {
		en = "T3  |  Cael Helmawr (Necromundan Spyrer)",
		["zh-cn"] = "T3 ｜ 凯尔·赫尔玛乌尔（涅克罗蒙达尖塔猎人）",
	},
	capture_target_mechanicus_warhound_alpha = {
		en = "T3  |  Canis-Alpha (Mechanicus Warhound Alpha)",
		["zh-cn"] = "T3 ｜ 卡尼斯-阿尔法（机械教战犬阿尔法）",
	},
	capture_target_cassia_orsellio = {
		en = "T3  |  Cassia Orsellio (Navis Nobilite Navigator)",
		["zh-cn"] = "T3 ｜ 卡西娅·奥塞利奥（导航贵族领航员）",
	},
	capture_target_rogue_trader = {
		en = "T3  |  Dorian Valec (Rogue Trader)",
		["zh-cn"] = "T3 ｜ 多里安·瓦莱克（行商浪人）",
	},
	capture_target_interrogator_heinrix = {
		en = "T3  |  Heinrix van Calox (Inquisitorial Biomancer)",
		["zh-cn"] = "T3 ｜ 海因里克斯·范·卡洛克斯（审判庭生物灵能者）",
	},
	capture_target_idira_tlass = {
		en = "T3  |  Idira Tlass (Unsanctioned Diviner)",
		["zh-cn"] = "T3 ｜ 伊迪拉·特拉斯（未受制裁的占卜师）",
	},
	capture_target_princess_jae = {
		en = "T3  |  Jae Heydari (Cold Trader)",
		["zh-cn"] = "T3 ｜ 杰·海达莉（禁物商人）",
	},
	capture_target_jocasta_sauerback = {
		en = "T3  |  Jocasta Sauerback (Voidship Master-at-Arms)",
		["zh-cn"] = "T3 ｜ 乔卡斯塔·绍尔巴克（虚空舰军械长）",
	},
	capture_target_spinner_kibellah = {
		en = "T3  |  Kibellah (Bloodspun Web Assassin)",
		["zh-cn"] = "T3 ｜ 基贝拉（血纺蛛网刺客）",
	},
	capture_target_lady_steel = {
		en = "T3  |  Lady Steel (Tread Lightlies Cartel Lord)",
		["zh-cn"] = "T3 ｜ 斯蒂尔女士（轻步帮首领）",
	},
	capture_target_lord_magleviathan = {
		en = "T3  |  Lord Magleviathan (Iron Riders Cartel Lord)",
		["zh-cn"] = "T3 ｜ 马格莱维阿坦勋爵（铁骑帮首领）",
	},
	capture_target_sicarian_ruststalker_princeps = {
		en = "T3  |  Nex-Primus (Sicarian Ruststalker Princeps)",
		["zh-cn"] = "T3 ｜ 内克斯-普里默斯（西卡里安锈蚀潜猎者首领）",
	},
	capture_target_magos_haneumann = {
		en = "T3  |  Pasqal Haneumann (Magos Explorator)",
		["zh-cn"] = "T3 ｜ 帕斯卡尔·哈诺伊曼（探索贤者）",
	},
	capture_target_arbites_marshal = {
		en = "T3  |  Severan Dreyke (Arbites Marshal)",
		["zh-cn"] = "T3 ｜ 塞维兰·德雷克（法务部元帅）",
	},
	capture_target_tempestor_prime = {
		en = "T3  |  Severin Rauth (Tempestor Prime)",
		["zh-cn"] = "T3 ｜ 塞维林·劳思（风暴兵指挥官）",
	},
	capture_target_sister_argenta = {
		en = "T3  |  Sister Argenta (Battle Sister)",
		["zh-cn"] = "T3 ｜ 阿金塔修女（战斗修女）",
	},
	capture_target_solomorne = {
		en = "T3  |  Solomorne Anthar (Proctor Exactant)",
		["zh-cn"] = "T3 ｜ 索洛莫恩·安塔尔（执法审判官）",
	},
	capture_target_theodora_von_valancius = {
		en = "T3  |  Theodora von Valancius (Rogue Trader)",
		["zh-cn"] = "T3 ｜ 西奥多拉·冯·瓦兰修斯（行商浪人）",
	},
	capture_target_your_host = {
		en = "T3  |  Your Host (The Show Cartel Lord)",
		["zh-cn"] = "T3 ｜ Your Host（秀场帮首领）",
	},
	capture_target_krieg_guardsman = {
		en = "T2  |  143-621 (Death Korps Guardsman)",
		["zh-cn"] = "T2 ｜ 143-621（死亡兵团卫兵）",
	},
	capture_target_arbites_enforcer = {
		en = "T2  |  Brannic Kord (Arbites Enforcer)",
		["zh-cn"] = "T2 ｜ 布兰尼克·科德（法务部执法者）",
	},
	capture_target_heavy_skitarius = {
		en = "T2  |  Bront-66 (Skitarii Heavy Gunner)",
		["zh-cn"] = "T2 ｜ 布隆特-66（护教军重炮手）",
	},
	capture_target_mechanicus_warhound = {
		en = "T2  |  Canis-43 (Mechanicus Warhound)",
		["zh-cn"] = "T2 ｜ 卡尼斯-43（机械教战犬）",
	},
	capture_target_sister_repentia = {
		en = "T2  |  Caelia Venn (Sister Repentia)",
		["zh-cn"] = "T2 ｜ 凯莉娅·文恩（忏悔修女）",
	},
	capture_target_commissar = {
		en = "T2  |  Cassian Drave (Commissar)",
		["zh-cn"] = "T2 ｜ 卡西安·德雷夫（政委）",
	},
	capture_target_undercover_arbitrator = {
		en = "T2  |  Cyran Vale (Arbites Intelligencer)",
		["zh-cn"] = "T2 ｜ 赛兰·维尔（法务部情报员）",
	},
	capture_target_kasrkin_marksman = {
		en = "T2  |  Darran Rhen (Kasrkin Marksman)",
		["zh-cn"] = "T2 ｜ 达兰·伦（卡舍津神射手）",
	},
	capture_target_hive_exterminator = {
		en = "T2  |  Garran Rusk (Hive Scum Exterminator)",
		["zh-cn"] = "T2 ｜ 加兰·拉斯克（巢都渣滓灭杀者）",
	},
	capture_target_crusader = {
		en = "T2  |  Gideon Mordane (Ministorum Crusader)",
		["zh-cn"] = "T2 ｜ 吉迪恩·莫尔丹（国教十字军）",
	},
	capture_target_heavy_combat_servitor = {
		en = "T2  |  HCS-819 (Heavy Combat Servitor)",
		["zh-cn"] = "T2 ｜ HCS-819（重型战斗机仆）",
	},
	capture_target_scholastica_pyrokinetic = {
		en = "T2  |  Ilyra Neth (Scholastica Pyrokinetic)",
		["zh-cn"] = "T2 ｜ 伊莉拉·内斯（灵能学院控火者）",
	},
	capture_target_electropriest = {
		en = "T2  |  Iohm-Theta (Corpuscarii Electro-Priest)",
		["zh-cn"] = "T2 ｜ 约姆-西塔（圣躯派电僧）",
	},
	capture_target_tempestus_scion = {
		en = "T2  |  Kastor Hale (Tempestus Scion)",
		["zh-cn"] = "T2 ｜ 卡斯托·黑尔（风暴忠嗣军）",
	},
	capture_target_underhive_wyrd = {
		en = "T2  |  Knell (Underhive Wyrd)",
		["zh-cn"] = "T2 ｜ 内尔（底巢异能者）",
	},
	capture_target_tech_priest = {
		en = "T2  |  Lathrix-9 (Tech-Priest Enginseer)",
		["zh-cn"] = "T2 ｜ 拉瑟瑞克斯-9（机械神甫引擎先知）",
	},
	capture_target_household_navigator = {
		en = "T2  |  Lucien Orphael (Household Navigator)",
		["zh-cn"] = "T2 ｜ 卢西恩·奥菲尔（家族领航员）",
	},
	capture_target_ministorum_flamer = {
		en = "T2  |  Maela Vorn (Ministorum Flamer)",
		["zh-cn"] = "T2 ｜ 梅拉·沃恩（国教喷火兵）",
	},
	capture_target_astropath = {
		en = "T2  |  Mara Quill (Astropath)",
		["zh-cn"] = "T2 ｜ 玛拉·奎尔（星语者）",
	},
	capture_target_voidship_breacher = {
		en = "T2  |  Mira Hest (Voidship Breacher)",
		["zh-cn"] = "T2 ｜ 米拉·赫斯特（虚空舰破门兵）",
	},
	capture_target_sicarian_ruststalker = {
		en = "T2  |  Nex-17 (Sicarian Ruststalker)",
		["zh-cn"] = "T2 ｜ 内克斯-17（西卡里安锈蚀潜猎者）",
	},
	capture_target_ogryn_hunter = {
		en = "T2  |  Ogryn Hunter (Underhive Ogryn Hunter)",
		["zh-cn"] = "T2 ｜ 欧格林猎手（底巢欧格林猎手）",
	},
	capture_target_ogryn_demolition_specialist = {
		en = "T2  |  Borrik (Ogryn Demolition Specialist)",
		["zh-cn"] = "T2 ｜ 博里克（欧格林爆破专家）",
	},
	capture_target_heavy_weapons_servitor = {
		en = "T3  |  Ferrum-9 (Ogryn Skitarius)",
		["zh-cn"] = "T3 ｜ Ferrum-9（欧格林护教军）",
	},
	capture_target_augmented_ogryn_heavy_gunner = {
		en = "T3  |  Lug (Ogryn Siege Veteran)",
		["zh-cn"] = "T3 ｜ 卢格（欧格林攻城老兵）",
	},
	capture_target_sanctioned_psychic_enforcer = {
		en = "T2  |  Orren Thale (Psykana Battle-Psyker)",
		["zh-cn"] = "T2 ｜ 奥伦·泰尔（灵能学院战斗灵能者）",
	},
	capture_target_voidsman_at_arms = {
		en = "T2  |  Renn Calder (Voidsman-at-Arms)",
		["zh-cn"] = "T2 ｜ 伦·考尔德（虚空舰武装船员）",
	},
	capture_target_recon_drone = {
		en = "T2  |  Rho-32 (Skitarii Recon Marksman)",
		["zh-cn"] = "T2 ｜ 罗-32（护教军侦察神射手）",
	},
	capture_target_heavy_gunner = {
		en = "T2  |  Rictus Vane (The Show Heavy Gunner)",
		["zh-cn"] = "T2 ｜ 里克图斯·范恩（秀场帮重炮手）",
	},
	capture_target_rejuvenat_adept = {
		en = "T3  |  Epione Spes (Officio Medicae Chirurgeon)",
		["zh-cn"] = "T3 ｜ 萨贝拉·奎斯特（医务部外科医师）",
	},
	capture_target_arbites_proctor = {
		en = "T2  |  Sabine Krail (Arbites Proctor)",
		["zh-cn"] = "T2 ｜ 萨宾·克雷尔（法务部督察）",
	},
	capture_target_sister_of_battle = {
		en = "T2  |  Sister Verena Holt (Battle Sister)",
		["zh-cn"] = "T2 ｜ 维蕾娜·霍尔特修女（战斗修女）",
	},
	capture_target_hive_chemist = {
		en = "T2  |  Veyra Kline (Hive Scum Chemist)",
		["zh-cn"] = "T2 ｜ 薇拉·克莱因（巢都渣滓药剂师）",
	},
	capture_target_deck_cleaner = {
		en = "T2  |  Brakk (Voidsman Deck Gunner)",
		["zh-cn"] = "T2 ｜ 布拉克（虚空舰甲板炮手）",
	},
	capture_target_black_ship_fodder = {
		en = "T1  |  Black Ship Fodder (Unsanctioned Psyker)",
		["zh-cn"] = "T1 ｜ 黑船囚徒（未受制裁的灵能者）",
	},
	capture_target_cartel_recruit = {
		en = "T1  |  Cartel Recruit (Low-Hive Runner)",
		["zh-cn"] = "T1 ｜ 卡特尔新兵（底巢跑腿）",
	},
	capture_target_grog = {
		en = "T1  |  Grog (Ogryn Auxilia)",
		["zh-cn"] = "T1 ｜ 格罗格（欧格林辅助军）",
	},
	capture_target_militarum_preacher = {
		en = "T1  |  Militarum Preacher (Conscript Preacher)",
		["zh-cn"] = "T1 ｜ 军务部传教士（征召传教士）",
	},
	capture_target_moebian_conscript = {
		en = "T1  |  Moebian 21st Conscript (Penal Conscript)",
		["zh-cn"] = "T1 ｜ 莫比安第21兵团征召兵（惩戒军征召兵）",
	},
	capture_target_moebian_deputy = {
		en = "T1  |  Moebian Deputy (Tertium Deputy)",
		["zh-cn"] = "T1 ｜ 莫比安副手（特提姆副警员）",
	},
	capture_target_skitarius_2137 = {
		en = "T1  |  Sk1tar1us 2137 (Damaged Skitarius)",
		["zh-cn"] = "T1 ｜ Sk1tar1us 2137（受损护教军）",
	},
	capture_all_keybind = {
		en = "Capture all preset data",
		["zh-cn"] = "捕获全部预设数据",
	},
	capture_all_keybind_tooltip = {
		en = "Snapshots the current character, loadout, look, personality, and EWC weapons " ..
		     "into the target preset. Missing optional mods are skipped safely. Future changes " ..
		     "will no longer drift into the bot; the snapshot is frozen at press time.",
		["zh-cn"] = "将当前角色、配装、外观、性格、EWC武器快照保存到目标预设。缺失的可选模组会安全跳过。之后的改动不会影响该机器人，快照会固定在按下快捷键那一刻。",
	},

	-- Run --------------------------------------------------------------------
	enable_auto_chain = {
		en = "Chain missions automatically",
		["zh-cn"] = "自动接续任务",
	},
	enable_auto_chain_tooltip = {
		en = "When a leg ends, automatically launch the next one after you return to " ..
		     "the Mourningstar. Only acts while a run is in progress.",
		["zh-cn"] = "完成一个阶段返回哀星号后自动开启下一任务。仅在远征进行中生效。",
	},
	-- v0.23.4: run_length, run_boons_per_leg, run_seeded and run_seed loc
	-- entries removed with their widgets. Mission count comes from the War
	-- Plan, boon choices from Zero Waste, and seeding moved to /pil_seed
	-- in chat, which takes a typed number instead of a ten-digit slider.

	-- Terminal ---------------------------------------------------------------
	enable_terminal_prompt = {
		en = "Show terminal prompt",
		["zh-cn"] = "显示终端交互提示",
	},
	enable_terminal_prompt_tooltip = {
		en = "Display an on-screen prompt when standing near the pilgrimage terminal " ..
		     "in the Mourningstar.",
		["zh-cn"] = "在哀星号靠近朝圣远征终端时，屏幕弹出交互提示。",
	},
	terminal_prompt_distance = {
		en = "Prompt distance (m)",
		["zh-cn"] = "提示触发距离(米)",
	},
	terminal_prompt_distance_tooltip = {
		en = "How close you must be to the terminal before the prompt appears.",
		["zh-cn"] = "距离终端多近才会弹出交互提示。",
	},

	enable_bot_hack_orders = {
		en = "Skitarii bots auto-hack interrogators",
		["zh-cn"] = "护教军机器人自动破译数据终端",
	},
	enable_bot_hack_orders_tooltip = {
		en = "When any bot preset in your slots is a Skitarii (Magos Haneumann, for " ..
		     "instance) and has the servo skull blitz equipped, that bot will " ..
		     "auto-dispatch its skull at nearby stalled data interrogators. Uses the " ..
		     "same 'companion order' ping that a human Skitarii would double-tap. " ..
		     "Skips interrogators anyone else is already handling.",
		["zh-cn"] = "当槽位机器人为护教军类（例如帕斯卡尔·哈诺伊曼神甫）且装备伺服头骨突袭，机器人会自动派遣头骨处理停滞的数据破译终端。使用与玩家双击下达同伴指令相同逻辑，会跳过已经被其他人处理的终端。",
	},

	-- Diagnostics ------------------------------------------------------------
	log_level = {
		en = "Log level",
		["zh-cn"] = "日志等级",
	},
	log_level_tooltip = {
		en = "Console logging verbosity. Leave off unless you are diagnosing a problem.",
		["zh-cn"] = "控制台日志详细程度。排查问题以外请保持关闭。",
	},
	log_level_off = {
		en = "Off",
		["zh-cn"] = "关闭",
	},
	log_level_info = {
		en = "Info",
		["zh-cn"] = "信息",
	},
	log_level_debug = {
		en = "Debug",
		["zh-cn"] = "调试",
	},
	log_level_trace = {
		en = "Trace",
		["zh-cn"] = "追踪",
	},
	enable_event_log = {
		en = "Write event log file",
		["zh-cn"] = "输出事件日志文件",
	},
	betterbots_navigation_guard = {
		en = "Better Bots navigation safety guard",
		["zh-cn"] = "Better Bots导航安全防护",
	},
	betterbots_navigation_guard_tooltip = {
		en = "On by default. During Pilgrimage missions only, isolates Better Bots' " ..
		     "optional hazard and charge checks from the native navigation plugin linked " ..
		     "to recurring crashes. All other navigation is unchanged; Better Bots itself is not modified.",
		["zh-cn"] = "默认开启。仅朝圣远征任务中，隔离Better Bots可选危险与冲锋检测，规避原生导航插件导致的反复崩溃。其余导航逻辑不变，不会修改Better Bots本体。",
	},
	enable_event_log_tooltip = {
		en = "Write a detailed diagnostic file to the game's dump folder. Useful when " ..
		     "reporting a bug, otherwise leave off.",
		["zh-cn"] = "在游戏dump文件夹输出详细诊断日志。上报bug时使用，平时关闭。",
	},
	enable_perf = {
		en = "Profile performance",
		["zh-cn"] = "性能分析",
	},
	diagnostics_enabled = {
		en = "Write troubleshooting files",
		["zh-cn"] = "输出故障排查文件",
	},
	group_testing = {
		en = "Testing / Cheat Mode",
		["zh-cn"] = "测试 / 作弊模式",
	},
	cheat_mode = {
		en = "Enable cheat mode",
		["zh-cn"] = "启用作弊模式",
	},
	cheat_mode_tooltip = {
		en = "Testing toolkit for trying out Pilgrimage content. While this is " ..
		     "on, penances CANNOT be earned (nothing already earned is lost). " ..
		     "The toggles below pick the effects.",
		["zh-cn"] = "用于测试朝圣远征内容。开启后无法获取忏悔进度，已获取的进度不会丢失。下方开关选择具体效果。",
	},
	cheat_invulnerable = {
		en = "Cheat: no health damage",
		["zh-cn"] = "作弊：免疫生命值伤害",
	},
	cheat_invulnerable_tooltip = {
		en = "Your operative cannot take health damage while cheat mode is on.",
		["zh-cn"] = "作弊模式开启时你的角色不会受到生命值伤害。",
	},
	cheat_one_shot = {
		en = "Cheat: one-shot kills",
		["zh-cn"] = "作弊：一击秒杀",
	},
	cheat_one_shot_tooltip = {
		en = "Your attacks deal massively multiplied damage to enemies while " ..
		     "cheat mode is on.",
		["zh-cn"] = "作弊模式开启时你的攻击会造成巨额倍率伤害。",
	},
	group_weapon_balancing = {
		en = "Custom weapon balancing",
		["zh-cn"] = "自定义武器平衡",
	},
	custom_weapon_balancing = {
		en = "Enable custom weapon balancing",
		["zh-cn"] = "开启自定义武器平衡",
	},
	custom_weapon_balancing_tooltip = {
		en = "Use Pilgrimage's weapon transformations during recorded Pilgrimage " ..
		     "missions. Includes Vraks Headhunter, Achlys Mk II Heavy Stubber, Kickback, Heavy Sword, Shredder, Power Maul, Plasma Cannon, Vindicator and Plasma Pistol changes. Set before loading.",
		["zh-cn"] = "朝圣远征任务中启用模组专属武器改动，包括弗拉克斯猎头枪、阿克利斯 Mk II 重型机枪、Kickback、重剑、撕碎者自动手枪、动力锤、等离子炮、Vindictor火焰喷射器和等离子手枪。需要在加载任务前设置。",
	},
	custom_weapon_balancing_meat_grinder = {
		en = "Also enable in the Meat Grinder",
		["zh-cn"] = "靶场同样启用",
	},
	custom_weapon_balancing_meat_grinder_tooltip = {
		en = "Also apply custom weapon balancing when entering the Meat Grinder. " ..
		     "Requires the master switch and takes effect on the next visit.",
		["zh-cn"] = "进入靶场时也应用自定义武器平衡。需要主开关开启，下次进入靶场生效。",
	},
	custom_weapon_visuals = {
		en = "Use transformed weapon appearances",
		["zh-cn"] = "启用改动后武器外观",
	},
	custom_weapon_visuals_tooltip = {
		en = "While custom weapon balancing is enabled, give the Vraks Headhunter, Achlys Mk II Heavy Stubber, Plasma Cannon, Vindicator and Plasma Pistol " ..
		     "their intended appearances. Exact transformed looks also require Syn's " ..
		     "Edits. Saved customization wins and missing parts fall back safely.",
		["zh-cn"] = "开启自定义武器平衡后，为弗拉克斯猎头枪、阿克利斯 Mk II 重型机枪、等离子炮、Vindictor火焰喷射器和等离子手枪应用对应外观。完整外观依赖Syn's Edits模组。已保存的自定义优先，缺失资源会安全回退。",
	},
	loc_k_karnak_sword = {
		en = "Karnak's Power Sword",
		["zh-cn"] = "卡尔纳克动力剑",
	},
	custom_weapon_sounds = {
		en = "Use custom weapon sounds",
		["zh-cn"] = "启用自定义武器音效",
	},
	custom_weapon_sounds_tooltip = {
		en = "Use optional custom audio for Pilgrimage's transformed weapons. Requires Simple Audio and the matching sound files. Disable to use the existing in-game fallback sounds. This is your own audio preference, including in multiplayer; damage and weapon timing are unchanged.",
		["zh-cn"] = "为朝圣改造武器启用可选的自定义音效，需要 Simple Audio 和对应的音频文件。关闭后使用现有的游戏内备用音效。此设置仅影响你自己的声音，包括多人游戏，不改变伤害或武器动作时序。",
	},
	loc_k_none = {
		en = "Standard (no change)",
		["zh-cn"] = "原版（无改动）",
	},
	loc_k_hide_weapon = {
		en = "Hide Weapon",
		["zh-cn"] = "隐藏武器",
	},
	loc_ewc_kaizen_skins = {
		en = "KAIZEN SKINS",
		["zh-cn"] = "KAIZEN 皮肤",
	},
	kaizen_skins = {
		en = "Kaizen Skins",
		["zh-cn"] = "Kaizen皮肤",
	},
	loc_tp_traitor_plasma = {
		en = "Traitor Plasma Gun",
		["zh-cn"] = "叛党等离子枪",
	},
	loc_tp_none = {
		en = "Standard (no reskin)",
		["zh-cn"] = "原版（不换皮）",
	},
	attachment_slot_skins = {
		en = "Skins",
		["zh-cn"] = "皮肤",
	},
	traitor_plasma = {
		en = "Traitor Plasma",
		["zh-cn"] = "叛党等离子",
	},
	loc_ewc_traitor_plasma = {
		en = "TRAITOR PLASMA",
		["zh-cn"] = "叛党等离子",
	},
	terminal_keybind = {
		en = "Open terminal keybind",
		["zh-cn"] = "打开终端快捷键",
	},
	terminal_keybind_tooltip = {
		en = "Opens the Pilgrimage terminal from anywhere, no physical terminal " ..
		     "needed. Unbound by default.",
		["zh-cn"] = "无需实体终端，任意位置打开朝圣远征终端。默认未绑定按键。",
	},
	diagnostics_enabled_tooltip = {
		en = "Write extra troubleshooting files into the Pilgrimage mod folder " ..
		     "(ff_diag.txt and similar). Only useful when reporting or hunting " ..
		     "a bug, otherwise leave off.",
		["zh-cn"] = "在朝圣远征模组文件夹输出额外故障排查文件（ff_diag.txt等）。仅排查上报bug时使用，平时关闭。",
	},
	enable_perf_tooltip = {
		en = "Measure how long the mod's own work takes each frame. Use /pil_perf to " ..
		     "see the report. Leave off during normal play.",
		["zh-cn"] = "统计模组每帧开销，使用聊天指令 /pil_perf 查看报告。正常游玩请关闭。",
	},
}
