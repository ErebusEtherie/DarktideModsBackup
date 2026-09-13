-- Grace localization. The mirrored vanilla settings pull the game's own
-- strings into the en slot; every other language falls back to it.

-- ───────────────────── ❀ ─────────────────────
--  The game string reader
-- ───────────────────── ❀ ─────────────────────

local _game_string = function(key, fallback)
	local ok, text = pcall(Localize, key)

	if ok and type(text) == "string" and text ~= "" and not text:find("<") then
		return text
	end

	return fallback
end

-- ───────────────────── ❀ ─────────────────────
--  The string table
-- ───────────────────── ❀ ─────────────────────

return {
	mod_name = {
		en = "Grace",
	},
	mod_description = {
		en = "A labour of love to create the most comprehensive set of movement options all in one place.",
		["zh-cn"] = "一份用心之作，旨在将最全面的移动选项汇集于一处。",
		ru = "Труд любви: самый полный набор настроек передвижения в одном месте.",
		["zh-tw"] = "一份用心之作，旨在將最全面的移動選項匯集於一處。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Base and vanilla groups
	-- ───────────────────── ❀ ─────────────────────
	group_vanilla_inner = {
		en = "Vanilla Game's Movement Settings",
		["zh-cn"] = "原版游戏移动设置",
		ru = "Оригинальные игровые настройки движения",
		["zh-tw"] = "原版遊戲移動設定",
	},
	group_grace_base = {
		en = "Grace's Base Movement Settings",
		["zh-cn"] = "Grace 基础移动设置",
		ru = "Настройки базового движения Grace",
		["zh-tw"] = "Grace 基礎移動設定",
	},
	group_vanilla = {
		en = "Base",
		["zh-cn"] = "基础",
		ru = "База",
		["zh-tw"] = "基礎",
	},
	group_vanilla_description = {
		en = "The game's own settings, mirrored.",
		["zh-cn"] = "游戏自带设置的镜像。",
		ru = "Зеркало собственных настроек игры.",
		["zh-tw"] = "遊戲自帶設定的鏡像。",
	},
	vanilla_hold_to_crouch = {
		en = _game_string("loc_setting_hold_to_crouch", "Hold to Crouch"),
	},
	vanilla_hold_to_crouch_description = {
		en = _game_string("loc_setting_hold_to_crouch_desc", "The game's matching setting; see the game options for its full description."),
	},
	vanilla_hold_to_sprint = {
		en = _game_string("loc_setting_hold_to_sprint", "Hold to Sprint"),
	},
	vanilla_hold_to_sprint_description = {
		en = _game_string("loc_setting_hold_to_sprint_desc", "The game's matching setting; see the game options for its full description."),
	},
	vanilla_stationary_dodge = {
		en = _game_string("loc_setting_stationary_dodge", "Stationary Dodge"),
	},
	vanilla_stationary_dodge_description = {
		en = _game_string("loc_setting_stationary_dodge_desc", "The game's matching setting; see the game options for its full description."),
	},
	vanilla_diagonal_forward_dodge = {
		en = _game_string("loc_setting_diagonal_forward_dodge", "Diagonal Forward Dodge"),
	},
	vanilla_diagonal_forward_dodge_description = {
		en = _game_string("loc_setting_diagonal_forward_dodge_mouseover", "The game's matching setting; see the game options for its full description."),
	},
	vanilla_always_dodge = {
		en = _game_string("loc_setting_always_dodge", "Always Dodge"),
	},
	vanilla_always_dodge_description = {
		en = _game_string("loc_setting_always_dodge_desc", "The game's matching setting; see the game options for its full description."),
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Sprint
	-- ───────────────────── ❀ ─────────────────────
	group_sprint = {
		en = "Sprint",
		["zh-cn"] = "冲刺",
		ru = "Спринт",
		["zh-tw"] = "衝刺",
	},
	group_sprint_description = {
		en = "Sprints while you are moving forward.",
		["zh-cn"] = "在你向前移动时自动冲刺。",
		ru = "Спринт, пока вы движетесь вперёд.",
		["zh-tw"] = "在你向前移動時自動衝刺。",
	},
	sprint_enabled = {
		en = "Sprint (Always)",
		["zh-cn"] = "冲刺（始终）",
		ru = "Спринт (всегда)",
		["zh-tw"] = "衝刺（始終）",
	},
	sprint_enabled_description = {
		en = "Sprints whenever you are moving cleanly forward, without needing a keybind; the keybinds still switch it off and on afterwards. Only the intent is supplied; stamina, weapon actions that forbid sprinting, and every other rule the game applies to a held sprint key still apply exactly as normal.",
		["zh-cn"] = "只要你在正向前进就会自动冲刺，无需绑定按键；之后仍可用按键随时开关。本功能只提供意图；耐力、禁止冲刺的武器动作，以及游戏对按住冲刺键的所有规则照常生效。",
		ru = "Спринт включается сам, пока вы движетесь прямо вперёд, без назначения клавиши; клавиши по-прежнему выключают и включают его после этого. Передаётся только намерение; выносливость, действия оружия, запрещающие спринт, и все остальные правила игры для зажатой клавиши спринта действуют как обычно.",
		["zh-tw"] = "只要你在正向前進就會自動衝刺，無需綁定按鍵；之後仍可用按鍵隨時開關。本功能只提供意圖；耐力、禁止衝刺的武器動作，以及遊戲對按住衝刺鍵的所有規則照常生效。",
	},
	toggle_undo_hold = {
		en = "Undo Held Toggle Presses",
		["zh-cn"] = "长按切换键自动撤销",
		ru = "Отмена долгого нажатия переключателя",
		["zh-tw"] = "長按切換鍵自動撤銷",
	},
	toggle_undo_hold_description = {
		en = "A quick tap of a sprint or slide toggle keybind switches as normal. Held longer, the press undoes its own switch on release, so a key shared with a held bind can serve both.",
		["zh-cn"] = "快速点按冲刺或滑铲的切换键照常切换。按住更久时，松开会撤销这次切换，因此与长按键位共用一个按键也不会弄乱开关。",
		ru = "Быстрое нажатие клавиши переключателя спринта или подката работает как обычно. Если клавишу удержать дольше, переключение отменяется при отпускании — так одна клавиша может служить и переключателем, и удерживаемой привязкой.",
		["zh-tw"] = "快速點按衝刺或滑鏟的切換鍵照常切換。按住更久時，鬆開會撤銷這次切換，因此與長按鍵位共用一個按鍵也不會弄亂開關。",
	},
	sprint_toggle_keybind = {
		en = "Sprint (Toggle)",
		["zh-cn"] = "冲刺（切换）",
		ru = "Спринт (переключить)",
		["zh-tw"] = "衝刺（切換）",
	},
	sprint_toggle_keybind_description = {
		en = "Turns the sprint feature off and on. It stays as you left it until the key is pressed again.",
		["zh-cn"] = "开启或关闭冲刺功能。状态会保持不变，直到再次按下该按键。",
		ru = "Включает или выключает функцию спринта. Состояние сохраняется до следующего нажатия клавиши.",
		["zh-tw"] = "開啟或關閉衝刺功能。狀態會保持不變，直到再次按下該按鍵。",
	},
	sprint_hold_keybind = {
		en = "Sprint (Held)",
		["zh-cn"] = "冲刺（按住）",
		ru = "Спринт (удерживать)",
		["zh-tw"] = "衝刺（長按）",
	},
	sprint_hold_keybind_description = {
		en = "Switches the sprint feature while the key is held, and switches it back on release.",
		["zh-cn"] = "按住按键时切换冲刺功能，松开后切换回原状态。",
		ru = "Переключает функцию спринта, пока клавиша удерживается, и возвращает прежнее состояние при отпускании.",
		["zh-tw"] = "按住按鍵時切換衝刺功能，鬆開後切換回原狀態。",
	},
	sprint_perseverance = {
		en = "Perseverance",
		["zh-cn"] = "坚毅",
		ru = "Упорство",
		["zh-tw"] = "堅毅",
	},
	sprint_perseverance_description = {
		en = "For players with the game's Hold to Sprint setting turned off, where the sprint key is tap only. While sprint is held and you are moving forward, Grace keeps you sprinting, starting a fresh sprint whenever one has not begun or was broken, so holding works the way your hands expect. Releasing never stops a running sprint; the game's own rules end it. Changes nothing with Hold to Sprint on.",
		["zh-cn"] = "面向关闭了游戏「按住冲刺」设置的玩家，此时冲刺键只认轻点。当你按住冲刺键并向前移动时，Grace 会让你保持冲刺：只要冲刺尚未开始或被打断，就会重新开始一次，让按住的手感如你所期。松开按键不会停止正在进行的冲刺；由游戏自身的规则来结束它。开启按住冲刺时无任何变化。",
		ru = "Для игроков с выключенной игровой настройкой «Удержание для спринта», когда клавиша спринта принимает только нажатия. Пока клавиша спринта удерживается и вы движетесь вперёд, Grace держит вас в спринте, начиная новый всякий раз, когда он не начался или был прерван, так что удержание работает так, как привыкли руки. Отпускание не останавливает текущий спринт; его завершают собственные правила игры. При включённом удержании для спринта ничего не меняет.",
		["zh-tw"] = "面向關閉了遊戲「按住衝刺」設定的玩家，此時衝刺鍵只認輕點。當你按住衝刺鍵並向前移動時，Grace 會讓你保持衝刺：只要衝刺尚未開始或被打斷，就會重新開始一次，讓按住的手感如你所期。鬆開按鍵不會停止正在進行的衝刺；由遊戲自身的規則來結束它。開啟按住衝刺時無任何變化。",
	},
	sprint_reload_wait = {
		en = "Wait For Reloads",
		["zh-cn"] = "等待装填",
		ru = "Ожидание перезарядки",
		["zh-tw"] = "等待裝填",
	},
	sprint_reload_wait_description = {
		en = "Sprint (Always) waits out reloads instead of cancelling them, resuming the moment the ammunition is actually loaded, partway through the animation. Your own presses are never held back.",
		["zh-cn"] = "冲刺（常开）会等待装填完成而不是打断它，并在弹药真正装入（动画进行到一半左右）的那一刻恢复冲刺。你自己的按键绝不会被拦下。",
		ru = "Спринт (всегда) пережидает перезарядку вместо того, чтобы прерывать её, и возобновляется в момент, когда боеприпасы действительно заряжены, примерно на середине анимации. Ваши собственные нажатия никогда не задерживаются.",
		["zh-tw"] = "衝刺（常開）會等待裝填完成而不是打斷它，並在彈藥真正裝入（動畫進行到一半左右）的那一刻恢復衝刺。你自己的按鍵絕不會被攔下。",
	},
	sprint_melee_charge = {
		en = "Sprint While Charging Melee",
		["zh-cn"] = "蓄力近战时冲刺",
		ru = "Спринт во время замаха",
		["zh-tw"] = "蓄力近戰時衝刺",
	},
	sprint_melee_charge_description = {
		en = "Moving forward while charging a heavy attack enters the sprint on its own, with no sprint feature needed, on weapons whose own data permits sprinting through the charge. Weapons that forbid it are unchanged.",
		["zh-cn"] = "蓄力重攻击时向前移动会自行进入冲刺，无需任何冲刺功能，仅限自身数据允许蓄力冲刺的武器。禁止的武器不受影响。",
		ru = "Движение вперёд во время замаха тяжёлой атаки само переводит персонажа в спринт, без каких-либо функций спринта — только на оружии, чьи собственные данные это разрешают. Остальное оружие не затронуто.",
		["zh-tw"] = "蓄力重攻擊時向前移動會自行進入衝刺，無需任何衝刺功能，僅限自身資料允許蓄力衝刺的武器。禁止的武器不受影響。",
	},
	sprint_charge_slide = {
		en = "Slide While Charging Melee",
		["zh-cn"] = "蓄力近战时滑铲",
		ru = "Подкат во время замаха",
		["zh-tw"] = "蓄力近戰時滑鏟",
	},
	sprint_charge_slide_description = {
		en = "Allows a sprint entered while charging a heavy attack to become a Slide (Always) slide. Left off, the charge sprint stays on its feet; every other slide is untouched.",
		["zh-cn"] = "允许蓄力重攻击期间进入的冲刺被持续滑铲转为滑铲。关闭时，蓄力冲刺保持站立，其他滑铲不受影响。",
		ru = "Позволяет спринту, начатому во время замаха тяжёлой атаки, перейти в подкат от постоянного подката. В выключенном состоянии такой спринт остаётся на ногах — остальные подкаты не затронуты.",
		["zh-tw"] = "允許蓄力重攻擊期間進入的衝刺被持續滑鏟轉為滑鏟。關閉時，蓄力衝刺保持站立，其他滑鏟不受影響。",
	},
	reload_swap_keybind = {
		en = "Swap After Reload",
		["zh-cn"] = "装填后切换",
		ru = "Смена оружия после перезарядки",
		["zh-tw"] = "裝填後切換",
	},
	reload_swap_keybind_description = {
		en = "Hold during a reload and the swap to melee waits for the ammunition instead of throwing the reload away. Bind it to your reload key, your melee key, or any key you like. Bound to your melee key, letting go before the ammunition lands gives you melee straight away.",
		["zh-cn"] = "在装填过程中按住，切换近战会等待弹药到位，而不是白白丢掉这次装填。可以绑定到装填键、近战键或任何你喜欢的按键。绑定到近战键时，在弹药到位前松开会立即切换近战。",
		ru = "Удерживайте во время перезарядки, и смена на ближний бой дождётся боеприпасов, а не пустит перезарядку насмарку. Назначьте на клавишу перезарядки, на клавишу ближнего боя или на любую другую. Если это клавиша ближнего боя, отпускание до поступления боеприпасов даёт ближний бой сразу.",
		["zh-tw"] = "在裝填過程中按住，切換近戰會等待彈藥到位，而不是白白丟掉這次裝填。可以綁定到裝填鍵、近戰鍵或任何你喜歡的按鍵。綁定到近戰鍵時，在彈藥到位前鬆開會立即切換近戰。",
	},
	notify_reload_swap_moved = {
		en = "Grace: Swap To Melee After Reloads is now a keybind, Melee After Reload (Held). Bind it to your reload key for the old behaviour.",
		["zh-cn"] = "Grace：装填后切换近战现已改为按键绑定「装填后切换近战（按住）」。绑定到装填键即可恢复原有行为。",
		ru = "Grace: «Смена на ближний бой после перезарядки» теперь привязка клавиши «Ближний бой после перезарядки (удержание)». Назначьте её на клавишу перезарядки, чтобы вернуть прежнее поведение.",
		["zh-tw"] = "Grace：裝填後切換近戰現已改為按鍵綁定「裝填後切換近戰（按住）」。綁定到裝填鍵即可恢復原有行為。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Slide
	-- ───────────────────── ❀ ─────────────────────
	group_slide = {
		en = "Slide",
		["zh-cn"] = "滑铲",
		ru = "Подкат",
		["zh-tw"] = "滑鏟",
	},
	group_slide_description = {
		en = "Slides for you while you are sprinting.",
		["zh-cn"] = "在你冲刺时自动滑铲。",
		ru = "Подкат выполняется сам, пока вы спринтуете.",
		["zh-tw"] = "在你衝刺時自動滑鏟。",
	},
	slide_always_on = {
		en = "Slide (Always)",
		["zh-cn"] = "滑铲",
		ru = "Подкат",
		["zh-tw"] = "滑鏟",
	},
	slide_always_on_description = {
		en = "Slides for you whenever you are sprinting, without needing a keybind. The keybinds still switch it off and on afterwards.",
		["zh-cn"] = "无需绑定按键即可启用自动滑铲。之后仍可用上方的按键随时开关。如果你只想在部分时候使用自动滑铲，请保持关闭。",
		ru = "Включает автоподкат без назначения клавиши. Клавиши выше по-прежнему выключают и включают его после этого. Оставьте выключенным, если автоподкат нужен лишь иногда.",
		["zh-tw"] = "無需綁定按鍵即可啟用自動滑鏟。之後仍可用上方的按鍵隨時開關。如果你只想在部分時候使用自動滑鏟，請保持關閉。",
	},
	slide_once_per_sprint = {
		en = "Slide Once Per Sprint",
		["zh-cn"] = "每次冲刺仅滑铲一次",
		ru = "Один подкат за спринт",
		["zh-tw"] = "每次衝刺僅滑鏟一次",
	},
	slide_once_per_sprint_description = {
		en = "Slides once at the start of each sprint you begin, entirely on its own; the other slide controls can stay off. A sprint resumed straight out of a slide counts as the same sprint, so no further slides come until you genuinely set off again. If the keybinds or Always also have sliding on, their repeating chain takes over.",
		["zh-cn"] = "在你开始的每次冲刺开头滑铲一次，完全独立运作；其他滑铲控制可以保持关闭。紧接滑铲恢复的冲刺算作同一次冲刺，因此在你真正重新起步之前不会再滑铲。若按键或始终选项也开启了滑铲，则由它们的连续连锁接管。",
		ru = "Один подкат в начале каждого начатого вами спринта, полностью самостоятельно; остальные элементы управления подкатом могут оставаться выключенными. Спринт, возобновившийся сразу после подката, считается тем же спринтом, так что новых подкатов не будет, пока вы по-настоящему не разбежитесь снова. Если клавиши или «Всегда» тоже включают подкат, верх берёт их повторяющаяся цепочка.",
		["zh-tw"] = "在你開始的每次衝刺開頭滑鏟一次，完全獨立運作；其他滑鏟控制可以保持關閉。緊接滑鏟恢復的衝刺算作同一次衝刺，因此在你真正重新起步之前不會再滑鏟。若按鍵或始終選項也開啟了滑鏟，則由它們的連續連鎖接管。",
	},
	slide_toggle_keybind = {
		en = "Slide (Toggle)",
		["zh-cn"] = "滑铲（切换）",
		ru = "Подкат (переключить)",
		["zh-tw"] = "滑鏟（切換）",
	},
	slide_toggle_keybind_description = {
		en = "Turns sliding off and on. It stays as you left it until the key is pressed again. Sprint and a movement direction still have to be held as normal.",
		["zh-cn"] = "开启或关闭自动滑铲。状态会保持不变，直到再次按下该按键。仍需照常按住冲刺和移动方向。",
		ru = "Включает или выключает автоподкат. Состояние сохраняется до следующего нажатия клавиши. Спринт и направление движения нужно удерживать как обычно.",
		["zh-tw"] = "開啟或關閉自動滑鏟。狀態會保持不變，直到再次按下該按鍵。仍需照常按住衝刺和移動方向。",
	},
	slide_hold_keybind = {
		en = "Slide (Held)",
		["zh-cn"] = "滑铲（按住）",
		ru = "Подкат (удерживать)",
		["zh-tw"] = "滑鏟（長按）",
	},
	slide_hold_keybind_description = {
		en = "Switches sliding while the key is held, and switches it back on release.",
		["zh-cn"] = "按住按键时切换自动滑铲，松开后切换回原状态。适合按需快速移动，而不必让它一直开着。",
		ru = "Переключает автоподкат, пока клавиша удерживается, и возвращает прежнее состояние при отпускании. Удобно для быстрого перемещения по требованию, без постоянно включённой функции.",
		["zh-tw"] = "按住按鍵時切換自動滑鏟，鬆開後切換回原狀態。適合按需快速移動，而不必讓它一直開著。",
	},
	slide_extra_delay = {
		en = "First Slide Delay",
		["zh-cn"] = "额外滑铲延迟（秒）",
		ru = "Дополнительная задержка подката (сек)",
		["zh-tw"] = "額外滑鏟延遲（秒）",
	},
	slide_extra_delay_description = {
		en = "Extra wait before the first slide of a run, on top of the sprint ramp that is always waited out. Raise it if a slide taken from a standing start feels short, lower it if the slide comes too late.",
		["zh-cn"] = "在本模组已有延迟的基础上，每次自动滑铲前额外等待的时间。冲刺需要一点时间才能达到全速，在此之前开始的滑铲几乎没有动量，因此该加速过程始终会被等待完毕。如果滑铲距离仍然偏短可以调高此项，否则保持 0 即可。",
		ru = "Дополнительное ожидание перед каждым автоматическим подкатом, сверх задержки, которую мод применяет и так. Спринту нужно время, чтобы набрать полную скорость, а подкат, начатый до этого, почти не имеет инерции, поэтому разгон всегда выжидается. Увеличьте значение, если подкаты всё ещё кажутся короткими, или оставьте 0.",
		["zh-tw"] = "在本模組已有延遲的基礎上，每次自動滑鏟前額外等待的時間。衝刺需要一點時間才能達到全速，在此之前開始的滑鏟幾乎沒有動量，因此該加速過程始終會被等待完畢。如果滑鏟距離仍然偏短可以調高此項，否則保持 0 即可。",
	},
	slide_chain_delay = {
		en = "Delay Between Slides",
		["zh-cn"] = "滑铲间隔延迟",
		ru = "Задержка между подкатами",
		["zh-tw"] = "滑鏟間隔延遲",
	},
	slide_chain_delay_description = {
		en = "Extra wait before each slide that follows another one.",
		["zh-cn"] = "在紧接前一次滑铲之后的每次滑铲前额外等待的时间。",
		ru = "Дополнительное ожидание перед каждым подкатом, следующим за другим.",
		["zh-tw"] = "在緊接前一次滑鏟之後的每次滑鏟前額外等待的時間。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Dodge
	-- ───────────────────── ❀ ─────────────────────
	group_dodge = {
		en = "Dodge",
		["zh-cn"] = "闪避",
		ru = "Уклонение",
		["zh-tw"] = "閃避",
	},
	group_dodge_description = {
		en = "Makes your dodge key useful while sprinting. Direction decides what a press does.",
		["zh-cn"] = "让闪避键在冲刺时也有用武之地。按下时的方向决定效果。",
		ru = "Делает клавишу уклонения полезной во время спринта. Направление решает, что даст нажатие.",
		["zh-tw"] = "讓閃避鍵在衝刺時也有用武之地。按下時的方向決定效果。",
	},
	dodge_keep_sprint = {
		en = "Dodge Without Losing Sprint",
		["zh-cn"] = "闪避不中断冲刺",
		ru = "Уклонение без потери спринта",
		["zh-tw"] = "閃避不中斷衝刺",
	},
	dodge_keep_sprint_description = {
		en = "Pressing dodge while sprinting diagonally performs the dodge and then brings the sprint straight back, instead of the press being refused or turning into a sprint jump. While sprinting clearly diagonally, jumping is set aside so the press can become the dodge; straight sprints keep jumps and vaults as normal. Forward diagonal dodges also need the game's own Diagonal Forward Dodge setting turned on.",
		["zh-cn"] = "在斜向冲刺时按下闪避会执行闪避并立即恢复冲刺，而不是被拒绝或变成冲刺跳跃。在明显斜向冲刺时，跳跃会被暂时搁置，好让按键成为闪避；直线冲刺时跳跃和翻越照常。前斜向闪避还需要开启游戏自带的「前斜向闪避」设置。",
		ru = "Нажатие уклонения во время спринта по диагонали выполняет уклонение и сразу возвращает спринт, вместо того чтобы нажатие было отклонено или превратилось в прыжок в спринте. Пока вы спринтуете явно по диагонали, прыжок откладывается, чтобы нажатие стало уклонением; при прямом спринте прыжки и перелезания работают как обычно. Для передних диагональных уклонений также нужна включённая игровая настройка «Переднее диагональное уклонение».",
		["zh-tw"] = "在斜向衝刺時按下閃避會執行閃避並立即恢復衝刺，而不是被拒絕或變成衝刺跳躍。在明顯斜向衝刺時，跳躍會被暫時擱置，好讓按鍵成為閃避；直線衝刺時跳躍和翻越照常。前斜向閃避還需要開啟遊戲自帶的「前斜向閃避」設定。",
	},
	dodge_slide = {
		en = "Forward Dodge To Slide",
		["zh-cn"] = "向前闪避接滑铲",
		ru = "Уклонение вперёд в подкат",
		["zh-tw"] = "向前閃避接滑鏟",
	},
	dodge_slide_description = {
		en = "Pressing dodge while sprinting forward performs a slide immediately, ignoring the slide delays; the other slide controls can stay off. Once the slide ends, the sprint comes back on its own.",
		["zh-cn"] = "在向前冲刺时按下闪避会立即滑铲，忽略滑铲延迟；其他滑铲控制可以保持关闭。滑铲结束后，冲刺会自动恢复。",
		ru = "Нажатие уклонения во время спринта вперёд сразу выполняет подкат, минуя задержки подката; остальные элементы управления подкатом могут оставаться выключенными. Когда подкат заканчивается, спринт возвращается сам.",
		["zh-tw"] = "在向前衝刺時按下閃避會立即滑鏟，忽略滑鏟延遲；其他滑鏟控制可以保持關閉。滑鏟結束後，衝刺會自動恢復。",
	},
	dodge_slide_diagonal = {
		en = "Diagonal Dodge To Slide",
		["zh-cn"] = "斜向闪避接滑铲",
		ru = "Диагональное уклонение в подкат",
		["zh-tw"] = "斜向閃避接滑鏟",
	},
	dodge_slide_diagonal_description = {
		en = "Diagonal dodge presses slide as well, not only straight ones. Needs Forward Dodge To Slide switched on, and a diagonal press then slides instead of keeping the sprint.",
		["zh-cn"] = "斜向按下闪避也会滑铲，而不只是直向时。需要开启「向前闪避接滑铲」，并且斜向按键会改为滑铲，不再保留冲刺。",
		ru = "Диагональные нажатия уклонения тоже переходят в подкат, а не только прямые. Нужно включить «Уклонение вперёд в подкат», и диагональное нажатие тогда уходит в подкат вместо сохранения спринта.",
		["zh-tw"] = "斜向按下閃避也會滑鏟，而不只是直向時。需要開啟「向前閃避接滑鏟」，並且斜向按鍵會改為滑鏟，不再保留衝刺。",
	},
	dodge_easy_slide = {
		en = "Easy Dodge & Slide",
		["zh-cn"] = "轻松闪避接滑铲",
		ru = "Лёгкое уклонение в подкат",
		["zh-tw"] = "輕鬆閃避接滑鏟",
	},
	dodge_easy_slide_description = {
		en = "A second dodge press just after a dodge slides out of it. The slide runs in whatever direction the dodge was going.",
		["zh-cn"] = "闪避后立刻再按一次闪避，就会从这次闪避中滑铲。滑铲沿着闪避原本的方向进行。",
		ru = "Второе нажатие уклонения сразу после уклонения переходит в подкат. Подкат идёт в том направлении, куда шло уклонение.",
		["zh-tw"] = "閃避後立刻再按一次閃避，就會從這次閃避中滑鏟。滑鏟沿著閃避原本的方向進行。",
	},
	dodge_slide_keybind = {
		en = "Dodge & Slide",
		["zh-cn"] = "闪避接滑铲",
		ru = "Уклонение в подкат",
		["zh-tw"] = "閃避接滑鏟",
	},
	dodge_slide_keybind_description = {
		en = "One key that dodges and then slides out of it. The game has no straight forward dodge, so hold a strafe direction as well, or the key does nothing. Pressing it during a sprint needs Dodge Without Losing Sprint turned on.",
		["zh-cn"] = "一个按键完成闪避并接着滑铲。游戏没有正前方闪避，因此还需同时按住横向移动键，否则该按键不做任何事。在冲刺中按下需要开启「闪避不中断冲刺」。",
		ru = "Одна клавиша выполняет уклонение и переходит из него в подкат. В игре нет уклонения строго вперёд, поэтому удерживайте ещё и клавишу движения вбок, иначе клавиша ничего не делает. Нажатие во время спринта требует включённой настройки «Уклонение без потери спринта».",
		["zh-tw"] = "一個按鍵完成閃避並接著滑鏟。遊戲沒有正前方閃避，因此還需同時按住橫向移動鍵，否則該按鍵不做任何事。在衝刺中按下需要開啟「閃避不中斷衝刺」。",
	},
	dodge_hold = {
		en = "Hold Dodge",
		["zh-cn"] = "长按闪避",
		ru = "Удержание уклонения",
		["zh-tw"] = "長按閃避",
	},
	dodge_hold_description = {
		en = "Holding dodge past a short delay does more than a single dodge. A quick tap always stays a plain dodge. The game has no forward dodge, so a press made while pushing straight forward is refused unless Always Dodge under Base Settings is on. And Diagonal Forward Dodge turns a forward lean into a sideways dodge.",
		["zh-cn"] = "按住闪避超过短暂延迟后会做的不止一次闪避。快速轻按始终只是普通闪避。游戏中没有向前闪避，因此正向前推进时按下闪避会被拒绝，除非开启基础设置中的始终闪避。开启斜向前闪避后，向前偏移会转为向侧面的闪避。",
		ru = "Удержание уклонения дольше короткой задержки даёт больше, чем одно уклонение. Быстрое нажатие всегда остаётся обычным уклонением. В игре нет уклонения вперёд, поэтому нажатие при движении строго вперёд отклоняется, если не включено «Всегда уклоняться» в разделе «База». А «Уклонение по диагонали вперёд» превращает наклон вперёд в уклонение в сторону.",
		["zh-tw"] = "按住閃避超過短暫延遲後會做的不只一次閃避。快速輕按始終只是普通閃避。遊戲中沒有向前閃避，因此正向前推進時按下閃避會被拒絕，除非開啟基礎設定中的始終閃避。開啟斜向前閃避後，向前偏移會轉為向側面的閃避。",
	},
	dodge_hold_off = {
		en = "Off",
		["zh-cn"] = "关闭",
		ru = "Выключено",
		["zh-tw"] = "關閉",
	},
	dodge_hold_slide = {
		en = "Slide",
		["zh-cn"] = "滑铲",
		ru = "Подкат",
		["zh-tw"] = "滑鏟",
	},
	dodge_hold_keep = {
		en = "Keep Dodging",
		["zh-cn"] = "持续闪避",
		ru = "Продолжать уклоняться",
		["zh-tw"] = "持續閃避",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Jump block
	-- ───────────────────── ❀ ─────────────────────
	jump_block = {
		en = "Block Jump Presses",
		["zh-cn"] = "屏蔽跳跃按键",
		ru = "Блокировать нажатия прыжка",
		["zh-tw"] = "封鎖跳躍按鍵",
	},
	jump_block_description = {
		en = "Stops the jump key jumping, so a key shared with dodge can only dodge. \"While Dodging\" blocks it during a dodge and briefly after, so a press the game will not take as a dodge cannot come out as a jump partway through a chain. \"Always\" blocks it outright. Vaulting still works through the Vault settings, and grabbing a ledge in mid air is unaffected.",
		["zh-cn"] = "使跳跃键不再跳跃，与闪避共用的按键就只会闪避。「闪避期间」只在闪避中及其后短时间内阻止，这样连续闪避途中一次游戏不认可的闪避按键不会变成跳跃。「始终」则完全阻止。翻越仍可通过翻越设置进行，空中抓取边缘不受影响。",
		ru = "Клавиша прыжка перестаёт прыгать, поэтому клавиша, общая с уклонением, будет только уклоняться. «Во время уклонений» запрещает прыжок на время уклонения и вскоре после него, чтобы нажатие, которое игра не примет за уклонение, не обернулось прыжком посреди цепочки. «Всегда» запрещает его полностью. Перелезание по-прежнему работает через настройки перелезания, а захват уступа в воздухе не затронут.",
		["zh-tw"] = "使跳躍鍵不再跳躍，與閃避共用的按鍵就只會閃避。「閃避期間」只在閃避中及其後短時間內阻止，這樣連續閃避途中一次遊戲不認可的閃避按鍵不會變成跳躍。「始終」則完全阻止。翻越仍可透過翻越設定進行，空中抓取邊緣不受影響。",
	},
	jump_block_off = {
		en = "Off",
		["zh-cn"] = "关闭",
		ru = "Выключено",
		["zh-tw"] = "關閉",
	},
	jump_block_dodges = {
		en = "While Dodging",
		["zh-cn"] = "闪避期间",
		ru = "Во время уклонений",
		["zh-tw"] = "閃避期間",
	},
	jump_block_always = {
		en = "Always",
		["zh-cn"] = "始终",
		ru = "Всегда",
		["zh-tw"] = "始終",
	},
	notify_jump_block_moved = {
		en = "Grace: Block Jump Presses now has three settings and has been left on Always, which is what it did before.",
		["zh-cn"] = "Grace：阻止跳跃按键现有三个选项，已保留为「始终」，与此前的行为一致。",
		ru = "Grace: «Блокировать нажатия прыжка» теперь имеет три варианта и оставлен на «Всегда», как и работал раньше.",
		["zh-tw"] = "Grace：阻止跳躍按鍵現有三個選項，已保留為「始終」，與此前的行為一致。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Vault
	-- ───────────────────── ❀ ─────────────────────
	group_vault = {
		en = "Vault",
		["zh-cn"] = "翻越",
		ru = "Перелезание",
		["zh-tw"] = "翻越",
	},
	group_vault_description = {
		en = "Vaults and ledge grabs happen on their own whenever the game itself agrees one is possible, no jump press needed.",
		["zh-cn"] = "只要游戏本身判定可以翻越或抓住边缘，就会自动进行，无需按跳跃键。",
		ru = "Перелезания и захваты уступов происходят сами, когда сама игра считает их возможными, без нажатия прыжка.",
		["zh-tw"] = "只要遊戲本身判定可以翻越或抓住邊緣，就會自動進行，無需按跳躍鍵。",
	},
	vault_sprinting = {
		en = "Vault While Sprinting",
		["zh-cn"] = "冲刺时自动翻越",
		ru = "Перелезание в спринте",
		["zh-tw"] = "衝刺時自動翻越",
	},
	vault_sprinting_description = {
		en = "Sprinting straight at a vaultable obstacle vaults it automatically. Only a clean forward approach counts, so angled ledges are left alone, and it stands down while a deployable is in hand. A vault beats a queued slide when both are possible, which is the game's own order.",
		["zh-cn"] = "笔直冲向可翻越的障碍时会自动翻越。只有正面接近才算数，斜角的边缘不受影响；手持可部署物品时不会触发。当翻越和滑铲同时可行时，翻越优先，这是游戏本身的顺序。",
		ru = "Спринт прямо на перелезаемое препятствие перелезает его автоматически. Считается только чистый подход вперёд, косые уступы не трогаются, а с развёртываемым предметом в руках функция бездействует. При одновременной возможности перелезание опережает подкат, таков порядок самой игры.",
		["zh-tw"] = "筆直衝向可翻越的障礙時會自動翻越。只有正面接近才算數，斜角的邊緣不受影響；手持可部署物品時不會觸發。當翻越和滑鏟同時可行時，翻越優先，這是遊戲本身的順序。",
	},
	vault_walking = {
		en = "Vault While Walking",
		["zh-cn"] = "行走时自动翻越",
		ru = "Перелезание при ходьбе",
		["zh-tw"] = "行走時自動翻越",
	},
	vault_walking_description = {
		en = "Walking straight at a vaultable obstacle vaults it automatically, with the same forward-approach and deployable rules as the sprint version. More eager than it sounds: any forward stroll into cover will climb it.",
		["zh-cn"] = "笔直走向可翻越的障碍时会自动翻越，正面接近和可部署物品的规则与冲刺版相同。比听起来更积极：向前走进掩体就会爬上去。",
		ru = "Ходьба прямо на перелезаемое препятствие перелезает его автоматически, с теми же правилами подхода вперёд и развёртываемых предметов, что и в спринте. Активнее, чем звучит: любой шаг вперёд в укрытие приведёт к залезанию на него.",
		["zh-tw"] = "筆直走向可翻越的障礙時會自動翻越，正面接近和可部署物品的規則與衝刺版相同。比聽起來更積極：向前走進掩體就會爬上去。",
	},
	vault_safe = {
		en = "Safe Vault",
		["zh-cn"] = "安全翻越",
		ru = "Безопасное перелезание",
		["zh-tw"] = "安全翻越",
	},
	vault_safe_description = {
		en = "Checks the landing before any automatic vault: hangable railings are refused, and so is any spot with no ground in reach below. Anything unreadable counts as unsafe, so failure means fewer vaults, never a fall.",
		["zh-cn"] = "在任何自动翻越前检查落点：可悬挂的栏杆会被拒绝，下方没有可及地面的位置也是。任何无法读取的情况都算作不安全，因此失败意味着更少的翻越，绝不会是坠落。",
		ru = "Проверяет место приземления перед любым автоматическим перелезанием: перила, на которых можно повиснуть, отклоняются, как и любое место без досягаемой земли внизу. Всё нечитаемое считается небезопасным, так что сбой означает меньше перелезаний, но никогда падение.",
		["zh-tw"] = "在任何自動翻越前檢查落點：可懸掛的欄杆會被拒絕，下方沒有可及地面的位置也是。任何無法讀取的情況都算作不安全，因此失敗意味著更少的翻越，絕不會是墜落。",
	},
	vault_fall_limit = {
		en = "Max Fall Height",
		["zh-cn"] = "最大坠落高度",
		ru = "Максимальная высота падения",
		["zh-tw"] = "最大墜落高度",
	},
	vault_fall_limit_description = {
		en = "How far down the landing may be, in meters, before an automatic vault is refused. 7 is the edge of taking no fall damage. Needs Safe Vault on.",
		["zh-cn"] = "落点最多可以低多少米，超过则拒绝自动翻越。7米是不受坠落伤害的临界值。需要开启安全翻越。",
		ru = "Насколько ниже может быть место приземления, в метрах, прежде чем автоматическое перелезание будет отклонено. 7 - граница отсутствия урона от падения. Требует включённого безопасного перелезания.",
		["zh-tw"] = "落點最多可以低多少米，超過則拒絕自動翻越。7米是不受墜落傷害的臨界值。需要開啟安全翻越。",
	},
	vault_mantle = {
		en = "Graceful Mantle",
		["zh-cn"] = "自动攀爬",
		ru = "Автозахват уступов",
		["zh-tw"] = "自動攀爬",
	},
	vault_mantle_description = {
		en = "While falling or jumping, a ledge within reach is grabbed automatically, as if jump were held at exactly the right moment.",
		["zh-cn"] = "在下落或跳跃时，触手可及的边缘会被自动抓住，就像在恰到好处的时机按住了跳跃。",
		ru = "Во время падения или прыжка уступ в пределах досягаемости захватывается автоматически, как если бы прыжок был зажат в нужный момент.",
		["zh-tw"] = "在下落或跳躍時，觸手可及的邊緣會被自動抓住，就像在恰到好處的時機按住了跳躍。",
	},
	vault_min_height = {
		en = "Minimum Vault Height",
		["zh-cn"] = "最低翻越高度",
		ru = "Минимальная высота перелезания",
		["zh-tw"] = "最低翻越高度",
	},
	vault_min_height_description = {
		en = "Ledges lower than this many metres are only vaulted for you once, not repeatedly, so a staircase costs one small vault instead of one per step. Pressing jump yourself still vaults anything the game allows. Zero turns the limit off.",
		["zh-cn"] = "低于此高度（米）的边缘只会为你自动翻越一次，不会连续翻越，因此上楼梯只有一次小翻越而不是每级一次。自己按跳跃仍可翻越游戏允许的任何边缘。设为零则关闭此限制。",
		ru = "Уступы ниже этой высоты в метрах перелезаются за вас только один раз, а не подряд, поэтому лестница стоит одного небольшого перелезания вместо одного на ступень. Нажатие прыжка вручную по-прежнему перелезает всё, что позволяет игра. Ноль отключает ограничение.",
		["zh-tw"] = "低於此高度（公尺）的邊緣只會為你自動翻越一次，不會連續翻越，因此上樓梯只有一次小翻越而不是每級一次。自己按跳躍仍可翻越遊戲允許的任何邊緣。設為零則關閉此限制。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Melee swing
	-- ───────────────────── ❀ ─────────────────────
	group_swing = {
		en = "Swing",
		["zh-cn"] = "挥击",
		ru = "Удар",
		["zh-tw"] = "揮擊",
	},
	group_swing_description = {
		en = "For sharing one key between sprint and attacking. Without this, tapping that key to sprint also throws an attack; with it, a tap sprints and only a hold attacks. Works with attack mods such as KeepSwinging and with Grace's own attack keybinds.",
		["zh-cn"] = "用于让冲刺和攻击共用同一个按键。没有它时，轻点该键冲刺也会打出一次攻击；有了它，轻点是冲刺，只有按住才攻击。适用于 KeepSwinging 之类的攻击模组，也适用于 Grace 自己的攻击按键。",
		ru = "Для одной клавиши на спринт и на атаку. Без этого короткое нажатие ради спринта наносит ещё и удар; с этим короткое нажатие даёт спринт, а атакует только удержание. Работает с модами атаки вроде KeepSwinging и с собственными привязками атак Grace.",
		["zh-tw"] = "用於讓衝刺和攻擊共用同一個按鍵。沒有它時，輕點該鍵衝刺也會打出一次攻擊；有了它，輕點是衝刺，只有按住才攻擊。適用於 KeepSwinging 之類的攻擊模組，也適用於 Grace 自己的攻擊按鍵。",
	},
	swing_keybind = {
		en = "Swing Key (Held)",
		["zh-cn"] = "挥击按键（按住）",
		ru = "Клавиша удара (удержание)",
		["zh-tw"] = "揮擊按鍵（長按）",
	},
	swing_keybind_description = {
		en = "For sharing one key between sprint and attacking. Without this, tapping that key to sprint also throws an attack; with it, a tap sprints and only a hold attacks. Bind the shared key here, and whatever does the attacking keeps its own keybind unchanged.",
		["zh-cn"] = "用于让冲刺和攻击共用同一个按键。没有它时，轻点该键冲刺也会打出一次攻击；有了它，轻点是冲刺，只有按住才攻击。请在这里绑定共用的按键，负责攻击的那一方保留自己原有的按键绑定。",
		ru = "Для одной клавиши на спринт и на атаку. Без этого короткое нажатие ради спринта наносит ещё и удар; с этим короткое нажатие даёт спринт, а атакует только удержание. Назначьте общую клавишу здесь; то, что выполняет атаку, сохраняет свою привязку без изменений.",
		["zh-tw"] = "用於讓衝刺和攻擊共用同一個按鍵。沒有它時，輕點該鍵衝刺也會打出一次攻擊；有了它，輕點是衝刺，只有按住才攻擊。請在這裡綁定共用的按鍵，負責攻擊的那一方保留自己原有的按鍵綁定。",
	},
	swing_grace_ms = {
		en = "Grace Period (ms)",
		["zh-cn"] = "宽限时间（毫秒）",
		ru = "Окно снисхождения (мс)",
		["zh-tw"] = "寬限時間（毫秒）",
	},
	swing_grace_ms_description = {
		en = "The line between a tap and a hold: how long the key must stay down before the first attack starts. Release inside it and no attack happens at all, which is what keeps a sprint tap from throwing a punch. Only the first attack waits, so one value works for every weapon. To find yours, turn on Swing Messages and tap the key twenty or so times; it reports your longest tap and a suggested value.",
		["zh-cn"] = "轻点与按住之间的分界线：按键需要按住多久才开始第一次攻击。在此时间内松开则完全不会攻击，这正是让冲刺的轻点不会打出一拳的原因。只有第一次攻击会等待，因此一个数值适用于所有武器。想找到适合你的数值，请打开挥击信息并轻点该键二十次左右，它会报告你最长的一次轻点并给出建议数值。",
		ru = "Граница между коротким нажатием и удержанием: сколько клавиша должна оставаться нажатой до первой атаки. Отпустите внутри этого окна, и атаки не будет вовсе, именно это не даёт нажатию спринта обернуться ударом. Ждёт только первая атака, поэтому одно значение подходит любому оружию. Чтобы подобрать своё, включите сообщения удара и нажмите клавишу раз двадцать: она покажет самое длинное нажатие и предложит значение.",
		["zh-tw"] = "輕點與按住之間的分界線：按鍵需要按住多久才開始第一次攻擊。在此時間內鬆開則完全不會攻擊，這正是讓衝刺的輕點不會打出一拳的原因。只有第一次攻擊會等待，因此一個數值適用於所有武器。想找到適合你的數值，請打開揮擊訊息並輕點該鍵二十次左右，它會報告你最長的一次輕點並給出建議數值。",
	},
	swing_skip_when_still = {
		en = "No Delay While Stationary",
		["zh-cn"] = "静止时不延迟",
		ru = "Без задержки на месте",
		["zh-tw"] = "靜止時不延遲",
	},
	swing_skip_when_still_description = {
		en = "Attacks instantly, with no tap-or-hold wait, when you press the key while standing still. Off by default, because tapping sprint from a standstill is one of the most common ways to sprint, and skipping the wait there lets exactly the attack you were trying to avoid through.",
		["zh-cn"] = "站立不动时按下该键会立即攻击，不做轻点或按住的等待。默认关闭，因为从静止起步轻点冲刺是最常见的冲刺方式之一，在这里跳过等待恰恰会放行你想避免的那一击。",
		ru = "Атакует сразу, без ожидания короткого нажатия или удержания, если вы нажимаете клавишу стоя на месте. По умолчанию выключено, ведь нажатие спринта с места это один из самых частых способов побежать, и пропуск ожидания здесь пропускает именно тот удар, которого вы избегали.",
		["zh-tw"] = "站立不動時按下該鍵會立即攻擊，不做輕點或按住的等待。預設關閉，因為從靜止起步輕點衝刺是最常見的衝刺方式之一，在這裡跳過等待恰恰會放行你想避免的那一擊。",
	},
	swing_skip_when_sprinting = {
		en = "No Delay While Sprinting",
		["zh-cn"] = "冲刺时不延迟",
		ru = "Без задержки в спринте",
		["zh-tw"] = "衝刺時不延遲",
	},
	swing_skip_when_sprinting_description = {
		en = "Attacks instantly, with no tap-or-hold wait, when you press the key during a sprint that is already running. Off by default; turn it on if you would rather attack the moment you press mid-sprint, since there is no sprint press to protect at that point.",
		["zh-cn"] = "在已经进行的冲刺中按下该键会立即攻击，不做轻点或按住的等待。默认关闭；如果你希望冲刺中一按就攻击，可以打开，因为此时已经没有需要保护的冲刺按键了。",
		ru = "Атакует сразу, без ожидания короткого нажатия или удержания, если вы нажимаете клавишу во время уже идущего спринта. По умолчанию выключено; включите, если предпочитаете атаковать в тот же миг, ведь защищать нажатие спринта здесь уже незачем.",
		["zh-tw"] = "在已經進行的衝刺中按下該鍵會立即攻擊，不做輕點或按住的等待。預設關閉；如果你希望衝刺中一按就攻擊，可以打開，因為此時已經沒有需要保護的衝刺按鍵了。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Melee attacks and specials
	-- ───────────────────── ❀ ─────────────────────
	group_special_repeat = {
		en = "Repeat Special Attack",
	},
	special_repeat = {
		en = "Repeat Special Attack",
	},
	special_repeat_description = {
		en = "Holding the weapon special key keeps the special attack going instead of one swing per press, and it finds its way back if a normal attack interrupts it. Only weapons whose special can follow another one, such as the Bully Club and the Rumbler; weapons whose special is a toggle, like a chainsword, are left alone.",
	},
	group_attacks = {
		en = "Melee Attacks",
		["zh-cn"] = "近战攻击",
		ru = "Атаки ближнего боя",
		["zh-tw"] = "近戰攻擊",
	},
	attacks_light_toggle_keybind = {
		en = "Repeat Light Attacks (Toggle)",
		["zh-cn"] = "重复轻攻击（切换）",
		ru = "Повтор лёгких атак (переключить)",
		["zh-tw"] = "重複輕攻擊（切換）",
	},
	attacks_light_toggle_keybind_description = {
		en = "Press to start or stop repeating light attacks with the wielded melee weapon. Idle with a ranged weapon or a device in hand.",
		["zh-cn"] = "按下开始或停止用当前近战武器重复轻攻击。手持远程武器或装置时不起作用。",
		ru = "Нажмите, чтобы начать или остановить повтор лёгких атак текущим оружием ближнего боя. С дальнобойным оружием или устройством в руках бездействует.",
		["zh-tw"] = "按下開始或停止用當前近戰武器重複輕攻擊。手持遠程武器或裝置時不起作用。",
	},
	attacks_light_hold_keybind = {
		en = "Repeat Light Attacks (Held)",
		["zh-cn"] = "重复轻攻击（按住）",
		ru = "Повтор лёгких атак (удержание)",
		["zh-tw"] = "重複輕攻擊（長按）",
	},
	attacks_light_hold_keybind_description = {
		en = "Repeats light attacks while the key is held. Outranks a standing toggle for as long as it is down. Sharing this key with sprint: bind it to Swing Key as well, so a tap sprints instead of attacking.",
		["zh-cn"] = "按住期间重复轻攻击。按住时优先于已开启的切换。若此键与冲刺共用，请同时把它绑定到挥击按键，这样轻点便是冲刺而非攻击。",
		ru = "Повторяет лёгкие атаки, пока клавиша удержана. Пока нажата, имеет приоритет над включённым переключателем. Если эта клавиша общая со спринтом, назначьте её ещё и на клавишу удара, чтобы короткое нажатие давало спринт, а не атаку.",
		["zh-tw"] = "按住期間重複輕攻擊。按住時優先於已開啟的切換。若此鍵與衝刺共用，請同時把它綁定到揮擊按鍵，這樣輕點便是衝刺而非攻擊。",
	},
	attacks_heavy_toggle_keybind = {
		en = "Repeat Heavy Attacks (Toggle)",
		["zh-cn"] = "重复重攻击（切换）",
		ru = "Повтор тяжёлых атак (переключить)",
		["zh-tw"] = "重複重攻擊（切換）",
	},
	attacks_heavy_toggle_keybind_description = {
		en = "Press to start or stop repeating heavy attacks, each released the moment the wielded weapon allows it.",
		["zh-cn"] = "按下开始或停止重复重攻击，每次都在当前武器允许的最早时机释放。",
		ru = "Нажмите, чтобы начать или остановить повтор тяжёлых атак; каждая выпускается в самый ранний момент, какой позволяет текущее оружие.",
		["zh-tw"] = "按下開始或停止重複重攻擊，每次都在當前武器允許的最早時機釋放。",
	},
	attacks_heavy_hold_keybind = {
		en = "Repeat Heavy Attacks (Held)",
		["zh-cn"] = "重复重攻击（按住）",
		ru = "Повтор тяжёлых атак (удержание)",
		["zh-tw"] = "重複重攻擊（長按）",
	},
	attacks_heavy_hold_keybind_description = {
		en = "Repeats heavy attacks while the key is held. Outranks a standing toggle for as long as it is down. Sharing this key with sprint: bind it to Swing Key as well, so a tap sprints instead of attacking.",
		["zh-cn"] = "按住期间重复重攻击。按住时优先于已开启的切换。若此键与冲刺共用，请同时把它绑定到挥击按键，这样轻点便是冲刺而非攻击。",
		ru = "Повторяет тяжёлые атаки, пока клавиша удержана. Пока нажата, имеет приоритет над включённым переключателем. Если эта клавиша общая со спринтом, назначьте её ещё и на клавишу удара, чтобы короткое нажатие давало спринт, а не атаку.",
		["zh-tw"] = "按住期間重複重攻擊。按住時優先於已開啟的切換。若此鍵與衝刺共用，請同時把它綁定到揮擊按鍵，這樣輕點便是衝刺而非攻擊。",
	},
	attacks_push_toggle_keybind = {
		en = "Push While Blocking (Toggle)",
	},
	attacks_push_toggle_keybind_description = {
		en = "Repeats the melee push, but only while block is actually held. Bind it to the same key as a repeating attack and blocking turns that attack into a push. Weapons with a push follow up attack land it before the next push.",
	},
	attacks_push_hold_keybind = {
		en = "Push While Blocking (Held)",
	},
	attacks_push_hold_keybind_description = {
		en = "Repeats the melee push while this key and block are both held. Weapons with a push follow up attack land it before the next push. Does nothing when block is not held.",
	},
	notify_attacks_push_on = {
		en = "Push while blocking: on",
	},
	notify_attacks_push_off = {
		en = "Push while blocking: off",
	},
	attacks_invert_keybind = {
		en = "Swap Attack Kind (Held)",
		["zh-cn"] = "互换攻击类型（按住）",
		ru = "Смена типа атаки (удержание)",
		["zh-tw"] = "互換攻擊類型（長按）",
	},
	attacks_invert_keybind_description = {
		en = "While this key is held, a running light attack repeat becomes heavy and a heavy one becomes light. Starts nothing on its own.",
		["zh-cn"] = "按住此键时，正在进行的轻攻击重复变为重攻击，重攻击变为轻攻击。本身不会开始任何攻击。",
		ru = "Пока клавиша удержана, идущий повтор лёгких атак становится тяжёлым, а тяжёлых — лёгким. Сама по себе ничего не запускает.",
		["zh-tw"] = "按住此鍵時，正在進行的輕攻擊重複變為重攻擊，重攻擊變為輕攻擊。本身不會開始任何攻擊。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Class
	-- ───────────────────── ❀ ─────────────────────
	group_class = {
		en = "Classes",
		["zh-cn"] = "职业",
		ru = "Классы",
		["zh-tw"] = "職業",
	},
	group_class_description = {
		en = "Per-class controls.",
		["zh-cn"] = "按职业进行的设置。",
		ru = "Настройки по классам.",
		["zh-tw"] = "按職業進行的設定。",
	},
	per_class = {
		en = "Remember Per Class",
		["zh-cn"] = "按职业分别记忆",
		ru = "Запоминать для каждого класса",
		["zh-tw"] = "按職業分別記憶",
	},
	per_class_description = {
		en = "Keeps a separate copy of every Grace setting for each class. Turning it on starts every class from your current values; turning it off restores them. Keybinds always stay shared.",
		["zh-cn"] = "为每个职业分别保存一份Grace的全部设置。打开时，所有职业都从你当前的数值开始；关闭时会恢复这些数值。按键绑定始终共用。",
		ru = "Хранит отдельную копию всех настроек Grace для каждого класса. При включении все классы начинают с ваших текущих значений; при выключении они восстанавливаются. Привязки клавиш всегда общие.",
		["zh-tw"] = "為每個職業分別儲存一份Grace的全部設定。打開時，所有職業都從你目前的數值開始；關閉時會恢復這些數值。按鍵綁定始終共用。",
	},
	per_class_vanilla = {
		en = "Include Vanilla Settings",
		["zh-cn"] = "包含原版设置",
		ru = "Включая настройки оригинала",
		["zh-tw"] = "包含原版設定",
	},
	per_class_vanilla_description = {
		en = "With Remember Per Class on, the five settings inside the Base group also remember per class, so switching character really changes them; the game's own options menu will show them changing too, because it is the same setting. Edits made in either menu count for the class you are playing. Turning this off restores the values from before it was turned on.",
		["zh-cn"] = "开启按职业分别记忆后，基础组内的五项设置也会按职业记忆，切换角色时它们会真正改变；游戏自带的选项菜单也会显示变化，因为是同一项设置。在任一菜单中的修改都算作当前职业的修改。关闭此项会恢复开启前的数值。",
		ru = "При включённом запоминании для каждого класса пять настроек внутри группы «База» тоже запоминаются для каждого класса, так что смена персонажа действительно меняет их; собственное меню настроек игры тоже покажет изменения, потому что это та же настройка. Правки в любом из меню засчитываются для класса, за который вы играете. Выключение возвращает значения, бывшие до включения.",
		["zh-tw"] = "開啟按職業分別記憶後，基礎組內的五項設定也會按職業記憶，切換角色時它們會真正改變；遊戲自帶的選項選單也會顯示變化，因為是同一項設定。在任一選單中的修改都算作當前職業的修改。關閉此項會恢復開啟前的數值。",
	},
	per_class_reset = {
		en = "Reset Per Class Memory",
		["zh-cn"] = "重置职业记忆",
		ru = "Сброс памяти классов",
		["zh-tw"] = "重置職業記憶",
	},
	per_class_reset_description = {
		en = "Switch this on to wipe every remembered per-class value in one go; it switches itself back off when done. Every class then starts fresh from your current settings. \"Disable Per Class\" is left alone.",
		["zh-cn"] = "打开此开关即可一次性清除所有已记忆的职业数值；完成后开关会自动关闭。此后每个职业都从你当前的设置重新开始。「按职业禁用」不受影响。",
		ru = "Включите, чтобы разом стереть все запомненные значения классов; по завершении переключатель выключается сам. Каждый класс затем начинает заново с ваших текущих настроек. «Отключение по классам» не затрагивается.",
		["zh-tw"] = "打開此開關即可一次性清除所有已記憶的職業數值；完成後開關會自動關閉。此後每個職業都從你當前的設定重新開始。「按職業停用」不受影響。",
	},
	notify_class_reset = {
		en = "Per Class Memory Reset.",
		["zh-cn"] = "职业记忆已重置。",
		ru = "Память классов сброшена.",
		["zh-tw"] = "職業記憶已重置。",
	},
	group_class_reset = {
		en = "Reset",
		["zh-cn"] = "重置",
		ru = "Сброс",
		["zh-tw"] = "重置",
	},
	group_class_reset_description = {
		en = "Kept in its own section so it cannot be tripped by accident.",
		["zh-cn"] = "单独放在此处，以免误触。",
		ru = "Вынесено в отдельный раздел, чтобы не задеть случайно.",
		["zh-tw"] = "單獨放在此處，以免誤觸。",
	},
	group_disable_class = {
		en = "Disable Per Class",
		["zh-cn"] = "按职业禁用",
		ru = "Отключение по классам",
		["zh-tw"] = "按職業停用",
	},
	group_disable_class_description = {
		en = "Tick a class to switch the whole mod off while playing it.",
		["zh-cn"] = "勾选某个职业，即可在游玩该职业时关闭整个模组。",
		ru = "Отметьте класс, чтобы весь мод был выключен во время игры за него.",
		["zh-tw"] = "勾選某個職業，即可在遊玩該職業時關閉整個模組。",
	},
	disable_veteran = {
		en = "Veteran",
		["zh-cn"] = "老兵",
		ru = "Ветеран",
		["zh-tw"] = "老兵",
	},
	disable_veteran_description = {
		en = "Turns every Grace feature off while playing Veteran, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩老兵时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Ветеран», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩老兵時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	disable_zealot = {
		en = "Zealot",
		["zh-cn"] = "狂信徒",
		ru = "Фанатик",
		["zh-tw"] = "狂信徒",
	},
	disable_zealot_description = {
		en = "Turns every Grace feature off while playing Zealot, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩狂信徒时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Фанатик», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩狂信徒時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	disable_psyker = {
		en = "Psyker",
		["zh-cn"] = "灵能者",
		ru = "Псайкер",
		["zh-tw"] = "靈能者",
	},
	disable_psyker_description = {
		en = "Turns every Grace feature off while playing Psyker, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩灵能者时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Псайкер», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩靈能者時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	disable_ogryn = {
		en = "Ogryn",
		["zh-cn"] = "欧格林",
		ru = "Огрин",
		["zh-tw"] = "歐格林",
	},
	disable_ogryn_description = {
		en = "Turns every Grace feature off while playing Ogryn, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩欧格林时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Огрин», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩歐格林時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	disable_adamant = {
		en = "Arbitrator",
		["zh-cn"] = "仲裁者",
		ru = "Арбитратор",
		["zh-tw"] = "仲裁者",
	},
	disable_adamant_description = {
		en = "Turns every Grace feature off while playing Arbitrator, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩仲裁者时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Арбитратор», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩仲裁者時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	disable_broker = {
		en = "Hive Scum",
		["zh-cn"] = "巢都渣滓",
		ru = "Отброс улья",
		["zh-tw"] = "巢都渣滓",
	},
	disable_broker_description = {
		en = "Turns every Grace feature off while playing Hive Scum, as if the mod were not installed for this class. On by default.",
		["zh-cn"] = "在游玩巢都渣滓时关闭 Grace 的所有功能，就像该职业没有安装此模组一样。默认开启。",
		ru = "Отключает все возможности Grace во время игры за класс «Отброс улья», как будто мод для этого класса не установлен. По умолчанию включено.",
		["zh-tw"] = "在遊玩巢都渣滓時關閉 Grace 的所有功能，就像該職業沒有安裝此模組一樣。預設開啟。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Debug channels
	-- ───────────────────── ❀ ─────────────────────
	group_debug = {
		en = "Debug",
		["zh-cn"] = "调试",
		ru = "Отладка",
		["zh-tw"] = "偵錯",
	},
	group_debug_description = {
		en = "Prints what each feature is deciding to chat. All off by default.",
		["zh-cn"] = "把各功能的判断结果打印到聊天框。默认全部关闭。",
		ru = "Выводит в чат решения каждой возможности. Всё выключено по умолчанию.",
		["zh-tw"] = "把各功能的判斷結果列印到聊天框。預設全部關閉。",
	},
	debug_notify = {
		en = "Simple Messages",
		["zh-cn"] = "简单信息",
		ru = "Простые сообщения",
		["zh-tw"] = "簡單訊息",
	},
	debug_notify_description = {
		en = "One-line confirmations in chat when features switch on or off from their keybinds. Off means the mod never speaks in chat unless a debug channel is on.",
		["zh-cn"] = "功能通过按键开关时在聊天中显示单行确认信息。关闭后，除非某个调试频道开启，模组不会在聊天中发出任何信息。",
		ru = "Однострочные подтверждения в чате при включении и выключении функций с привязок. В выключенном состоянии мод молчит в чате, если не включён один из каналов отладки.",
		["zh-tw"] = "功能透過按鍵開關時在聊天中顯示單行確認訊息。關閉後，除非某個除錯頻道開啟，模組不會在聊天中發出任何訊息。",
	},
	debug_sprint = {
		en = "Sprint Messages",
		["zh-cn"] = "冲刺信息",
		ru = "Сообщения спринта",
		["zh-tw"] = "衝刺訊息",
	},
	debug_sprint_description = {
		en = "Reports sprint forcing switching on and off with the forward input value that decided it, the press machinery arming, injecting, or being blocked, the sprint confirming, and the hub jog state coming and going.",
		["zh-cn"] = "报告冲刺强制的开关及其判断所依据的前进输入数值、按键机制的待发、注入或受阻、冲刺的确认，以及枢纽慢跑状态的进出。",
		ru = "Сообщает о включении и выключении принудительного спринта со значением ввода вперёд, о взведении, введении или блокировке нажатий, о подтверждении спринта и о входе и выходе из состояния бега в хабе.",
		["zh-tw"] = "報告衝刺強制的開關及其判斷所依據的前進輸入數值、按鍵機制的待發、注入或受阻、衝刺的確認，以及樞紐慢跑狀態的進出。",
	},
	debug_slide = {
		en = "Slide Messages",
		["zh-cn"] = "滑铲信息",
		ru = "Сообщения подката",
		["zh-tw"] = "滑鏟訊息",
	},
	debug_slide_description = {
		en = "Reports sliding being switched on or off, each slide being queued with its wait or the reason a queue was refused, the crouch being forced, the crouch presses injected and released for toggle crouch, and a queue that expired without reaching slide speed, with the game crouch mode it saw.",
		["zh-cn"] = "报告滑铲的开启与关闭、每次滑铲排入队列及其等待时间或队列被拒绝的原因、蹲下被强制触发、为切换式蹲下注入和释放的蹲下按键，以及未达到滑铲速度而失效的队列及其所见的游戏蹲下模式。",
		ru = "Сообщает о включении и выключении подката, о каждом поставленном в очередь подкате с его ожиданием или причине отказа, о принудительном приседании, о введённых и отпущенных нажатиях приседания для переключаемого режима и об очереди, истёкшей без набора скорости подката, с увиденным режимом приседания игры.",
		["zh-tw"] = "報告滑鏟的開啟與關閉、每次滑鏟排入佇列及其等待時間或佇列被拒絕的原因、蹲下被強制觸發、為切換式蹲下注入和釋放的蹲下按鍵，以及未達到滑鏟速度而失效的佇列及其所見的遊戲蹲下模式。",
	},
	debug_dodge = {
		en = "Dodge Messages",
		["zh-cn"] = "闪避信息",
		ru = "Сообщения уклонения",
		["zh-tw"] = "閃避訊息",
	},
	debug_dodge_description = {
		en = "Reports each dodge press with its direction decision, the sprint being dropped and the off press injected, the dodge confirming, the crouch forced for a slide, and the sprint resuming.",
		["zh-cn"] = "报告每次闪避按键及其方向判断、冲刺被放下与注入的关闭按键、闪避确认、为滑铲强制的蹲下，以及冲刺的恢复。",
		ru = "Сообщает о каждом нажатии уклонения и решении по направлению, о сброшенном спринте и введённом отключающем нажатии, о подтверждении уклонения, о принудительном приседании для подката и о возобновлении спринта.",
		["zh-tw"] = "報告每次閃避按鍵及其方向判斷、衝刺被放下與注入的關閉按鍵、閃避確認、為滑鏟強制的蹲下，以及衝刺的恢復。",
	},
	debug_vault = {
		en = "Vault Messages",
		["zh-cn"] = "翻越信息",
		ru = "Сообщения перелезания",
		["zh-tw"] = "翻越訊息",
	},
	debug_vault_description = {
		en = "Reports each time a jump read is answered for a vault or a held jump for a ledge grab, and each vault Safe Vault refused, with the reason.",
		["zh-cn"] = "报告每次为翻越应答跳跃输入或为抓边应答按住跳跃的情况，以及安全翻越拒绝的每次翻越及其原因。",
		ru = "Сообщает каждый раз, когда чтение прыжка отвечается ради перелезания или удержание прыжка ради захвата уступа, а также каждое перелезание, отклонённое безопасным перелезанием, с причиной.",
		["zh-tw"] = "報告每次為翻越應答跳躍輸入或為抓邊應答按住跳躍的情況，以及安全翻越拒絕的每次翻越及其原因。",
	},
	debug_swing = {
		en = "Swing Messages",
		["zh-cn"] = "挥击信息",
		ru = "Сообщения удара",
		["zh-tw"] = "揮擊訊息",
	},
	debug_swing_description = {
		en = "Reports each press with its delay decision, the window opening and closing, and how many attack reads were suppressed. Also times every tap and suggests a grace period from your longest one, so the slider can be set from your own reflexes instead of guesswork.",
		["zh-cn"] = "报告每次按下及其延迟判断、窗口的开启与关闭，以及被拦下的攻击读取次数。它还会为每次轻点计时，并根据你最长的一次给出建议的宽限时间，让滑块可以依据你自己的反应来设定，而不是靠猜。",
		ru = "Сообщает о каждом нажатии и решении по задержке, об открытии и закрытии окна и о том, сколько чтений атаки было подавлено. Также замеряет каждое короткое нажатие и предлагает окно снисхождения исходя из самого длинного, чтобы ползунок настраивался по вашей собственной реакции, а не наугад.",
		["zh-tw"] = "報告每次按下及其延遲判斷、視窗的開啟與關閉，以及被攔下的攻擊讀取次數。它還會為每次輕點計時，並根據你最長的一次給出建議的寬限時間，讓滑桿可以依據你自己的反應來設定，而不是靠猜。",
	},
	debug_class = {
		en = "Class Messages",
		["zh-cn"] = "职业信息",
		ru = "Сообщения класса",
		["zh-tw"] = "職業訊息",
	},
	debug_class_description = {
		en = "Reports the class detected, whether the mod is switched on for it, and per class settings being applied.",
		["zh-cn"] = "报告检测到的职业、该职业是否启用了模组，以及按职业设置的应用情况。",
		ru = "Сообщает, какой класс определён, включён ли для него мод и как применяются настройки по классам.",
		["zh-tw"] = "報告檢測到的職業、該職業是否啟用了模組，以及按職業設定的應用情況。",
	},
	debug_attacks = {
		en = "Attack Messages",
		["zh-cn"] = "攻击信息",
		ru = "Сообщения атак",
		["zh-tw"] = "攻擊訊息",
	},
	debug_attacks_description = {
		en = "Reports each windup with its computed heavy release moment, and why the attack keybinds are standing idle.",
		["zh-cn"] = "报告每次蓄力及其计算出的重攻击释放时机，以及攻击按键闲置的原因。",
		ru = "Сообщает о каждом замахе и рассчитанном моменте выпуска тяжёлой атаки, а также о причинах простоя привязок атак.",
		["zh-tw"] = "報告每次蓄力及其計算出的重攻擊釋放時機，以及攻擊按鍵閒置的原因。",
	},
	-- ───────────────────── ❀ ─────────────────────
	--  Notification lines
	-- ───────────────────── ❀ ─────────────────────
	notify_attacks_light = {
		en = "Attacks: light",
		["zh-cn"] = "攻击：轻",
		ru = "Атаки: лёгкие",
		["zh-tw"] = "攻擊：輕",
	},
	notify_attacks_heavy = {
		en = "Attacks: heavy",
		["zh-cn"] = "攻击：重",
		ru = "Атаки: тяжёлые",
		["zh-tw"] = "攻擊：重",
	},
	notify_attacks_off = {
		en = "Attacks: off",
		["zh-cn"] = "攻击：关",
		ru = "Атаки: выкл",
		["zh-tw"] = "攻擊：關",
	},
	notify_slide_on = {
		en = "Sliding: on",
		["zh-cn"] = "滑铲：开启",
		ru = "Подкат: вкл",
		["zh-tw"] = "滑鏟：開啟",
	},
	notify_sprint_on = {
		en = "Sprinting: on",
		["zh-cn"] = "冲刺：开启",
		ru = "Спринт: вкл",
		["zh-tw"] = "衝刺：開啟",
	},
	notify_sprint_off = {
		en = "Sprinting: off",
		["zh-cn"] = "冲刺：关闭",
		ru = "Спринт: выкл",
		["zh-tw"] = "衝刺：關閉",
	},
	notify_slide_off = {
		en = "Sliding: off",
		["zh-cn"] = "滑铲：关闭",
		ru = "Подкат: выкл",
		["zh-tw"] = "滑鏟：關閉",
	},
}
