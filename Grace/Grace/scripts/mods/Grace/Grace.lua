-- Grace. Input timing forgiveness for sprinting, sliding, dodging,
-- vaulting and melee swings, worked entirely from the game's own input reads.

local mod = get_mod("Grace")

local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local LedgeVaulting = require("scripts/extension_systems/character_state_machine/character_states/utilities/ledge_vaulting")

-- ───────────────────── ❀ ─────────────────────
--  Shared state
-- ───────────────────── ❀ ─────────────────────

local K = {}
local S = {}

S.debug_notify = mod:get("debug_notify") and true or false
S.debug_sprint = mod:get("debug_sprint") and true or false
S.debug_slide = mod:get("debug_slide") and true or false
S.debug_dodge = mod:get("debug_dodge") and true or false
S.debug_vault = mod:get("debug_vault") and true or false
S.debug_swing = mod:get("debug_swing") and true or false
S.debug_class = mod:get("debug_class") and true or false
S.debug_attacks = mod:get("debug_attacks") and true or false
S.special_repeat = mod:get("special_repeat") and true or false

S.clock_unreadable = false
S.player_count_unreadable = false

S.is_sprinting = false
S.sprint_entered_at = nil

local _say = function(channel, key_or_text, is_literal)
	if not channel then
		return
	end

	mod:echo(is_literal and key_or_text or mod:localize(key_or_text))
end

local _now = function()
	local time_manager = Managers.time

	if not time_manager then
		return nil
	end

	local names = { "gameplay", "main" }

	for i = 1, #names do
		local ok, t = pcall(time_manager.time, time_manager, names[i])

		if ok and type(t) == "number" then
			return t
		end
	end

	if not S.clock_unreadable then
		S.clock_unreadable = true

		mod:warning("No usable clock could be read; timed features depend on it.")
	end

	return nil
end

-- ───────────────────── ❀ ─────────────────────
--  Session and player reads
-- ───────────────────── ❀ ─────────────────────

local _in_session = function()
	local player_manager = Managers.player

	if not player_manager then
		return false
	end

	local num_players = rawget(player_manager, "_num_players")

	if type(num_players) ~= "number" then
		if not S.player_count_unreadable then
			S.player_count_unreadable = true

			mod:warning("Could not read the player count, so class features are disabled this session.")
		end

		return false
	end

	return num_players > 0
end

local _local_player = function()
	if not _in_session() then
		return nil
	end

	local player_manager = Managers.player
	local found, player = pcall(player_manager.local_player, player_manager, 1)

	if not found then
		return nil
	end

	return player
end

local _get_player_unit = function()
	local player = _local_player()

	return player and player.player_unit or nil
end

local _read_move_axis = function()
	local input_manager = Managers.input
	local service = input_manager and input_manager:get_input_service("Ingame")

	if not service then
		return nil, nil
	end

	local success, move = pcall(service.get, service, "move")

	if not success or not move then
		return nil, nil
	end

	local axis_read, x, y = pcall(function()
		return move.x, move.y
	end)

	if not axis_read or type(x) ~= "number" or type(y) ~= "number" then
		return nil, nil
	end

	return x, y
end

K.MOVE_STAMP_FRESHNESS = 0.2

S.move_x = nil
S.move_y = nil
S.move_at = nil

local _stamp_move_axis = function(now)
	if not now then
		return
	end

	local x, y = _read_move_axis()

	if x and y then
		S.move_x = x
		S.move_y = y
		S.move_at = now
	end
end

local _move_axis = function()
	local x, y = _read_move_axis()

	if x and y then
		return x, y
	end

	local now = _now()

	if S.move_at and now and now - S.move_at <= K.MOVE_STAMP_FRESHNESS then
		return S.move_x, S.move_y
	end

	return nil, nil
end

-- ───────────────────── ❀ ─────────────────────
--  Per class settings
-- ───────────────────── ❀ ─────────────────────

local _refresh_cache
local _write_game_setting
local _read_game_setting
local _refresh_sprint_hold_mode

K.VANILLA_SAVE_LOCATION = "input_settings"

local VANILLA_SETTINGS = {
	{ mod_id = "vanilla_hold_to_crouch", game_id = "hold_to_crouch" },
	{ mod_id = "vanilla_hold_to_sprint", game_id = "hold_to_sprint" },
	{ mod_id = "vanilla_stationary_dodge", game_id = "stationary_dodge" },
	{ mod_id = "vanilla_diagonal_forward_dodge", game_id = "diagonal_forward_dodge" },
	{ mod_id = "vanilla_always_dodge", game_id = "always_dodge" },
}

local VANILLA_LOOKUP = {}

for i = 1, #VANILLA_SETTINGS do
	VANILLA_LOOKUP[VANILLA_SETTINGS[i].mod_id] = VANILLA_SETTINGS[i].game_id
end

local PER_CLASS_SETTINGS = {
	"sprint_enabled",
	"sprint_perseverance",
	"sprint_reload_wait",
	"sprint_melee_charge",
	"sprint_charge_slide",
	"slide_always_on",
	"slide_once_per_sprint",
	"slide_extra_delay",
	"slide_chain_delay",
	"dodge_keep_sprint",
	"dodge_slide",
	"dodge_slide_diagonal",
	"dodge_easy_slide",
	"dodge_hold",
	"jump_block",
	"vault_sprinting",
	"vault_walking",
	"vault_mantle",
	"vault_safe",
	"vault_fall_limit",
	"vault_min_height",
	"swing_grace_ms",
	"swing_skip_when_still",
	"swing_skip_when_sprinting",
}

local PER_CLASS_LOOKUP = {}

for i = 1, #PER_CLASS_SETTINGS do
	PER_CLASS_LOOKUP[PER_CLASS_SETTINGS[i]] = true
end

S.per_class = mod:get("per_class") and true or false
S.per_class_vanilla = mod:get("per_class_vanilla") and true or false

S.synced_class = nil
S.class_enabled = true
S.applying = false
local unknown_classes = {}

local KNOWN_CLASSES = { "veteran", "zealot", "psyker", "ogryn", "adamant", "broker" }

local _base_key = function(id)
	return "base_" .. id
end

local _class_key = function(class, id)
	return "class_" .. class .. "_" .. id
end

local _disable_key = function(class)
	return "disable_" .. class
end

-- ───────────────────── ❀ ─────────────────────
--  Reading the class
-- ───────────────────── ❀ ─────────────────────

local _current_class = function()
	local player = _local_player()

	if not player then
		return nil
	end

	local read, profile = pcall(player.profile, player)

	if not read or not profile then
		return nil
	end

	local archetype = profile.archetype
	local name = archetype and archetype.name

	if type(name) ~= "string" or name == "" then
		return nil
	end

	return name
end

-- ───────────────────── ❀ ─────────────────────
--  Applying a class
-- ───────────────────── ❀ ─────────────────────

local _apply = function(id, value)
	S.applying = true

	mod:set(id, value)

	if _refresh_cache then
		_refresh_cache(id)
	end

	S.applying = false
end

local _capture_base = function()
	for i = 1, #PER_CLASS_SETTINGS do
		local id = PER_CLASS_SETTINGS[i]

		mod:set(_base_key(id), mod:get(id))
	end

	if S.per_class_vanilla then
		for i = 1, #VANILLA_SETTINGS do
			local id = VANILLA_SETTINGS[i].mod_id

			mod:set(_base_key(id), mod:get(id))
		end
	end
end

local _apply_vanilla = function(entry, value)
	_apply(entry.mod_id, value)

	if _write_game_setting then
		_write_game_setting(entry.game_id, value and true or false)
	end
end

local _restore_base = function()
	for i = 1, #PER_CLASS_SETTINGS do
		local id = PER_CLASS_SETTINGS[i]
		local stored = mod:get(_base_key(id))

		if stored ~= nil then
			_apply(id, stored)
		end
	end

	if S.per_class_vanilla then
		for i = 1, #VANILLA_SETTINGS do
			local entry = VANILLA_SETTINGS[i]
			local stored = mod:get(_base_key(entry.mod_id))

			if stored ~= nil then
				_apply_vanilla(entry, stored)
			end
		end
	end
end

local _apply_class = function(class)
	for i = 1, #PER_CLASS_SETTINGS do
		local id = PER_CLASS_SETTINGS[i]
		local stored = mod:get(_class_key(class, id))

		if stored == nil then
			stored = mod:get(_base_key(id))
		end

		if stored ~= nil then
			_apply(id, stored)
		end
	end

	if S.per_class_vanilla then
		for i = 1, #VANILLA_SETTINGS do
			local entry = VANILLA_SETTINGS[i]
			local stored = mod:get(_class_key(class, entry.mod_id))

			if stored == nil then
				stored = mod:get(_base_key(entry.mod_id))
			end

			if stored ~= nil then
				_apply_vanilla(entry, stored)
			end
		end
	end
end

local _reset_per_class_memory = function()
	for c = 1, #KNOWN_CLASSES do
		local class = KNOWN_CLASSES[c]

		for i = 1, #PER_CLASS_SETTINGS do
			mod:set(_class_key(class, PER_CLASS_SETTINGS[i]), nil)
		end

		for i = 1, #VANILLA_SETTINGS do
			mod:set(_class_key(class, VANILLA_SETTINGS[i].mod_id), nil)
		end
	end

	for i = 1, #PER_CLASS_SETTINGS do
		mod:set(_base_key(PER_CLASS_SETTINGS[i]), nil)
	end

	for i = 1, #VANILLA_SETTINGS do
		mod:set(_base_key(VANILLA_SETTINGS[i].mod_id), nil)
	end

	if S.per_class then
		_capture_base()
	end

	mod:notify(mod:localize("notify_class_reset"))
end

-- ───────────────────── ❀ ─────────────────────
--  Class change watch
-- ───────────────────── ❀ ─────────────────────

S.class_check_at = nil

local _ensure_class_synced = function()
	local class = _current_class()

	if not class or class == S.synced_class then
		return
	end

	S.synced_class = class

	local stored = mod:get(_disable_key(class))

	S.class_enabled = not stored

	if stored == nil and not unknown_classes[class] then
		unknown_classes[class] = true

		mod:warning(string.format("No class switch defined for '%s'; running on it by default.", class))
	end

	if S.per_class then
		_apply_class(class)

		_say(S.debug_class, string.format("per class settings applied for %s", class), true)
	end

	_say(S.debug_class, string.format("%s, mod is %s", class, S.class_enabled and "on" or "off"), true)
end

local _record_edit = function(id)
	local class = S.synced_class or _current_class()

	if class then
		S.synced_class = class

		mod:set(_class_key(class, id), mod:get(id))
	else
		mod:set(_base_key(id), mod:get(id))
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Game settings bridge
-- ───────────────────── ❀ ─────────────────────

S.vanilla_write_failed = false

local _game_settings_table = function()
	local save_manager = Managers.save

	if not save_manager or not _local_player() then
		return nil
	end

	local ok, account_data = pcall(save_manager.account_data, save_manager)

	if not ok or type(account_data) ~= "table" then
		return nil
	end

	return account_data[K.VANILLA_SAVE_LOCATION]
end

_read_game_setting = function(game_id)
	local settings = _game_settings_table()

	if type(settings) ~= "table" then
		return nil
	end

	return settings[game_id]
end

_write_game_setting = function(game_id, value)
	local settings = _game_settings_table()
	local save_manager = Managers.save

	if type(settings) ~= "table" or not save_manager then
		if not S.vanilla_write_failed then
			S.vanilla_write_failed = true

			mod:warning("The game settings could not be written; use the game's own options menu instead.")
		end

		return
	end

	settings[game_id] = value and true or false

	save_manager:queue_save()
end

local _sync_vanilla_settings = function()
	_refresh_sprint_hold_mode()

	for i = 1, #VANILLA_SETTINGS do
		local entry = VANILLA_SETTINGS[i]
		local value = _read_game_setting(entry.game_id)

		if value ~= nil then
			value = value and true or false

			if (mod:get(entry.mod_id) and true or false) ~= value then
				_apply(entry.mod_id, value)

				if S.per_class and S.per_class_vanilla then
					_record_edit(entry.mod_id)
				end
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Dodge state
-- ───────────────────── ❀ ─────────────────────

local DODGE = {
	keep_sprint = mod:get("dodge_keep_sprint") and true or false,
	slide_on = mod:get("dodge_slide") and true or false,
	slide_diagonal = mod:get("dodge_slide_diagonal") and true or false,
	easy_slide = mod:get("dodge_easy_slide") and true or false,
	walk_last = false,
	walk_edge_t = nil,
	easy_window = 0.3,
	hold_mode = mod:get("dodge_hold") or "off",
	hold_delay = 0.15,
	hold_down = false,
	hold_since = nil,
	hold_engaged = false,
	drop_until = nil,
	resume_until = nil,
	replay_until = nil,
	slide_until = nil,
	kb_press_until = nil,
	kb_slide_until = nil,
	kb_resume = false,
	slide_said = false,
	slide_speed_ok = false,
	slide_resume = false,
	dodged_at = nil,
	off_press_pending = false,
	off_press_frame = nil,
	last_val = false,
	in_vault = false,
}

-- ───────────────────── ❀ ─────────────────────
--  Sprint
-- ───────────────────── ❀ ─────────────────────

K.SPRINT_HELD_INPUT = "sprinting"
K.SPRINT_HOLD_MODE_INPUT = "hold_to_sprint"
K.SPRINT_FORWARD_MIN = 0.75

K.SPRINT_PRESS_INPUT = "sprint"

local PRESS = {
	patience = 0.15,
	retry = 0.4,
}

if type(mod:get("sprint_charge_slide")) ~= "boolean" then
	mod:set("sprint_charge_slide", false)
end

if type(mod:get(_base_key("sprint_charge_slide"))) == "string" then
	mod:set(_base_key("sprint_charge_slide"), nil)
end

for i = 1, #KNOWN_CLASSES do
	local key = _class_key(KNOWN_CLASSES[i], "sprint_charge_slide")

	if type(mod:get(key)) == "string" then
		mod:set(key, nil)
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Sprint while charging melee
-- ───────────────────── ❀ ─────────────────────

PRESS.charge = {
	on = mod:get("sprint_melee_charge") and true or false,
	slide_allowed = mod:get("sprint_charge_slide") and true or false,
	allowed = false,
	action_name = nil,
	said = false,
	prevent_kinds = {},
}

do
	local ok, handler_settings = pcall(require, "scripts/settings/action/action_handler_settings")
	local list = ok and type(handler_settings) == "table" and handler_settings.prevent_sprint

	if type(list) == "table" then
		for i = 1, #list do
			PRESS.charge.prevent_kinds[list[i]] = true
		end
	end
end

PRESS.undo = {
	on = mod:get("toggle_undo_hold") and true or false,
	window = 0.3,
	sprint_down_at = nil,
	slide_down_at = nil,
}

-- ───────────────────── ❀ ─────────────────────
--  Sprint state
-- ───────────────────── ❀ ─────────────────────

S.sprint_enabled = mod:get("sprint_enabled") and true or false
S.sprint_forcing = false

S.sprint_intent_since = nil
S.sprint_press_pending = false
S.sprint_press_frame = nil
S.sprint_next_press_at = nil
S.sprint_cooldown_until = nil

S.in_ground_state = false

S.press_block_said = false

S.real_sprint_press_at = nil

S.sprint_hold_down = false

S.in_hub = false
S.hub_checked = false
S.hub_component = nil
S.hub_unit = nil
S.hub_was_sprinting = false
S.hub_said_at = nil

S.sprint_hold_mode = true
S.sprint_hold_mode_known = false

-- ───────────────────── ❀ ─────────────────────
--  Wait for reloads
-- ───────────────────── ❀ ─────────────────────

K.PER_ROUND_RELOAD_KIND = "reload_shotgun"

local RELOAD = {
	wait = mod:get("sprint_reload_wait") and true or false,
	active = false,
	action_name = nil,
	per_round_action = nil,
	component = nil,
	action_component = nil,
	unit = nil,
	sprint_component = nil,
	was_waiting = false,
}
S.sprint_press_charging = false

local _reload_components = function()
	local unit = _get_player_unit()

	if not unit then
		return nil
	end

	if unit ~= RELOAD.unit then
		RELOAD.component = nil
		RELOAD.action_component = nil
		RELOAD.unit = nil

		if not ScriptUnit.has_extension(unit, "unit_data_system") then
			return nil
		end

		local ok, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")

		if not ok or not unit_data then
			return nil
		end

		local ok_reload, reload = pcall(unit_data.read_component, unit_data, "action_reload")
		local ok_action, action = pcall(unit_data.read_component, unit_data, "weapon_action")
		local ok_sprint, sprint = pcall(unit_data.read_component, unit_data, "sprint_character_state")

		if not ok_reload or not reload or not ok_action or not action or not ok_sprint or not sprint then
			return nil
		end

		RELOAD.component = reload
		RELOAD.action_component = action
		RELOAD.sprint_component = sprint
		RELOAD.unit = unit
	end

	return RELOAD.component, RELOAD.action_component, RELOAD.sprint_component
end

-- ───────────────────── ❀ ─────────────────────
--  Wait for weapon specials
-- ───────────────────── ❀ ─────────────────────

local SPECIAL = {
	action_name = nil,
	since = nil,
	was_waiting = false,
	input_seen = false,
	said_blind = false,
}

K.SPECIAL_WAIT_MAX = 0.4

local _special_input = function(used_input)
	if type(used_input) ~= "string" or used_input:find("cancel", 1, true) then
		return false
	end

	return used_input:find("weapon_extra", 1, true) ~= nil or used_input:find("special", 1, true) ~= nil
end

local _special_waiting = function(now)
	if not SPECIAL.action_name then
		return false
	end

	if not now or not SPECIAL.since or now - SPECIAL.since > K.SPECIAL_WAIT_MAX then
		SPECIAL.action_name = nil
		SPECIAL.since = nil

		return false
	end

	local _, action = _reload_components()

	if not action or action.current_action_name ~= SPECIAL.action_name then
		SPECIAL.action_name = nil
		SPECIAL.since = nil

		return false
	end

	return true
end

local _reload_running = function()
	local reload, action = _reload_components()

	if not reload then
		return false
	end

	if RELOAD.per_round_action then
		if action.current_action_name == RELOAD.per_round_action then
			return true
		end

		RELOAD.per_round_action = nil
	end

	if not RELOAD.active then
		return false
	end

	if RELOAD.action_name and action.current_action_name ~= RELOAD.action_name then
		RELOAD.active = false
		RELOAD.action_name = nil
		RELOAD.was_waiting = false

		_say(S.debug_sprint, "reload cancelled, sprint automation resuming", true)

		return false
	end

	return not reload.has_refilled_ammunition
end

local _reload_waiting = function()
	return RELOAD.wait and _reload_running()
end

-- ───────────────────── ❀ ─────────────────────
--  Wait for vents and channels
-- ───────────────────── ❀ ─────────────────────

K.CHANNEL_KINDS = {
	chain_lightning = true,
	damage_target = true,
	overload_charge_target_finder = true,
	smite_targeting = true,
	vent_overheat = true,
	vent_warp_charge = true,
	zealot_channel = true,
}

local CHANNEL = {
	action_name = nil,
	was_waiting = false,
}

local _channel_waiting = function()
	if not CHANNEL.action_name then
		return false
	end

	local _, action = _reload_components()

	if not action or action.current_action_name ~= CHANNEL.action_name then
		CHANNEL.action_name = nil

		return false
	end

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  Swap to melee after reloads
-- ───────────────────── ❀ ─────────────────────

local _wielded_slot

local FIRE = {
	held_at = nil,
	was_waiting = false,
	freshness = 0.1,
}

local _observe_fire_input = function(action_name, val, now)
	if action_name == "action_one_hold" and val and val ~= 0 and now then
		FIRE.held_at = now
	end
end

local _fire_waiting = function(now)
	if not now or not FIRE.held_at then
		return false
	end

	if not _wielded_slot or _wielded_slot() ~= "slot_secondary" then
		return false
	end

	return now - FIRE.held_at < FIRE.freshness
end

-- ───────────────────── ❀ ─────────────────────
--  Wait for an ability that must wield something
-- ───────────────────── ❀ ─────────────────────

K.ABILITY_INPUTS = {
	combat_ability_pressed = true,
	combat_ability_release = true,
}

K.ABILITY_WIELD_MAX = 1.2

K.ABILITY_WIELD_KINDS = {
	unwield_to_specific = true,
	wield = true,
}

local ABILITY = {
	wield_until = nil,
	was_waiting = false,
}

local _observe_ability_wield = function(action_settings, t, used_input)
	local kind = type(action_settings) == "table" and action_settings.kind or nil

	if t and type(used_input) == "string" and K.ABILITY_INPUTS[used_input] and K.ABILITY_WIELD_KINDS[kind] then
		ABILITY.wield_until = t + K.ABILITY_WIELD_MAX

		return
	end

	if ABILITY.wield_until and kind and not K.ABILITY_WIELD_KINDS[kind] then
		ABILITY.wield_until = nil
	end
end

local _ability_waiting = function(now)
	if not ABILITY.wield_until then
		return false
	end

	if now and now < ABILITY.wield_until then
		return true
	end

	ABILITY.wield_until = nil

	return false
end

-- ───────────────────── ❀ ─────────────────────
--  Movement state corrector
-- ───────────────────── ❀ ─────────────────────

local JUMP = {
	mode = mod:get("jump_block") or "off",
	block_window = 0.35,
	dodge_until = nil,
}

local STATE_CHECK = {
	frame = nil,
	component = nil,
	unit = nil,
	ground_names = {
		walking = true,
		hub_jog = true,
	},
}

local _correct_movement_flags = function(now)
	if not now or STATE_CHECK.frame == now then
		return
	end

	STATE_CHECK.frame = now

	local unit = _get_player_unit()

	if not unit then
		return
	end

	if unit ~= STATE_CHECK.unit then
		STATE_CHECK.component = nil
		STATE_CHECK.move_component = nil
		STATE_CHECK.unit = nil

		if not ScriptUnit.has_extension(unit, "unit_data_system") then
			return
		end

		local ok, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")

		if not ok or not unit_data then
			return
		end

		local ok_state, component = pcall(unit_data.read_component, unit_data, "character_state")

		if not ok_state or not component then
			return
		end

		local ok_move, move_component = pcall(unit_data.read_component, unit_data, "movement_state")

		STATE_CHECK.component = component
		STATE_CHECK.move_component = ok_move and move_component or nil
		STATE_CHECK.unit = unit
	end

	local name = STATE_CHECK.component.state_name

	if type(name) ~= "string" or name == "dummy" then
		return
	end

	local sprinting = name == "sprinting"
	local grounded = STATE_CHECK.ground_names[name] and true or false

	DODGE.in_vault = name == "ledge_vaulting"

	if name == "dodging" then
		JUMP.dodge_until = now + JUMP.block_window
		DODGE.dodged_at = now

		if DODGE.kb_slide_until and now < DODGE.kb_slide_until then
			DODGE.kb_slide_until = nil
			DODGE.kb_press_until = nil
			DODGE.slide_until = now + K.DODGE_SLIDE_TIMEOUT
			DODGE.slide_said = false
			DODGE.slide_speed_ok = false
			DODGE.slide_resume = DODGE.kb_resume and true or false

			_say(S.debug_dodge, "dodge slide bind, dodge started and slide forced", true)
		end
	elseif name == "sliding" then
		JUMP.dodge_until = nil
	end

	local sliding_live = name == "sliding"

	if S.in_slide_state ~= sliding_live then
		S.in_slide_state = sliding_live

		_say(S.debug_slide, string.format("slide tracking corrected to %s from the live state", sliding_live and "sliding" or "not sliding"), true)
	end

	if sprinting ~= S.is_sprinting then
		S.is_sprinting = sprinting

		_say(S.debug_sprint, string.format("sprint tracking corrected to %s from the live state", sprinting and "sprinting" or "not sprinting"), true)
	end

	if grounded ~= S.in_ground_state then
		S.in_ground_state = grounded
		S.press_block_said = false

		_say(S.debug_sprint, string.format("ground tracking corrected to %s from the live state", grounded and "grounded" or "airborne"), true)
	end

	if S.crouch_latch_on and not S.crouch_release_pending and grounded
		and not DODGE.slide_until and not S.slide_queued_at then
		local move = STATE_CHECK.move_component

		if move and move.is_crouching then
			S.crouch_release_pending = true
			S.crouch_release_frame = nil

			_say(S.debug_slide, "crouch latch corrected from the live state, release armed", true)
		elseif move then
			S.crouch_latch_on = false

			_say(S.debug_slide, "crouch latch cleared, the live state is already standing", true)
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  The reload swap filter
-- ───────────────────── ❀ ─────────────────────

local SWAP = {
	key_down = false,
	withheld = false,
	pressed = false,
	press_until = nil,
}

local _filter_reload_swap_input = function(action_name, val, now)
	if action_name ~= "wield_1" then
		return val
	end

	if SWAP.press_until and now then
		if now < SWAP.press_until then
			return true
		end

		SWAP.press_until = nil
	end

	if not SWAP.key_down or not RELOAD.active or not now then
		return val
	end

	local reload, action = _reload_components()

	if not reload then
		return val
	end

	if RELOAD.action_name and action.current_action_name ~= RELOAD.action_name then
		return val
	end

	if not reload.has_refilled_ammunition then
		if val then
			SWAP.withheld = true
		end

		return false
	end

	if SWAP.pressed then
		return val
	end

	SWAP.pressed = true
	SWAP.withheld = false
	SWAP.press_until = now + 0.05

	_say(S.debug_sprint, "ammunition landed with the swap bind held, melee wield pressed", true)

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  Hold mode and the hub
-- ───────────────────── ❀ ─────────────────────

_refresh_sprint_hold_mode = function()
	local value = _read_game_setting and _read_game_setting("hold_to_sprint")

	if value ~= nil then
		S.sprint_hold_mode = value and true or false
		S.sprint_hold_mode_known = true
	end
end

local _refresh_hub_flag = function()
	if S.hub_checked then
		return
	end

	local state_manager = Managers.state
	local game_mode = state_manager and state_manager.game_mode

	if not game_mode then
		return
	end

	local ok, social = pcall(game_mode.is_social_hub, game_mode)

	S.in_hub = ok and social and true or false
	S.hub_checked = true
end

local _hub_sprinting = function()
	if not S.in_hub then
		return false
	end

	local unit = _get_player_unit()

	if not unit then
		return false
	end

	if not S.hub_component or S.hub_unit ~= unit then
		S.hub_component = nil
		S.hub_unit = nil

		if not ScriptUnit.has_extension(unit, "unit_data_system") then
			return false
		end

		local ok, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")

		if not ok or not unit_data then
			return false
		end

		local ok_component, component = pcall(unit_data.read_component, unit_data, "hub_jog_character_state")

		if not ok_component or not component then
			return false
		end

		S.hub_component = component
		S.hub_unit = unit
	end

	return S.hub_component.move_state == "sprint"
end

-- ───────────────────── ❀ ─────────────────────
--  Sprint press state
-- ───────────────────── ❀ ─────────────────────

K.SLIDE_PRESS_CARRY = 0.3

S.in_slide_state = false
S.slide_press_said = false
S.slide_press_carry_until = nil

K.RAW_HELD_FRESHNESS = 0.1

S.sprint_perseverance = mod:get("sprint_perseverance") and true or false

S.raw_sprint_held_at = nil

local _reset_sprint_press = function()
	S.sprint_intent_since = nil
	S.sprint_press_pending = false
	S.sprint_press_frame = nil
	S.sprint_next_press_at = nil
	S.sprint_cooldown_until = nil
	S.slide_press_carry_until = nil
	S.press_block_said = false
end

local _sprint_active = function()
	return S.sprint_enabled ~= S.sprint_hold_down
end

local _after_sprint_change = function(was_active)
	local active = _sprint_active()

	if active == was_active then
		return
	end

	S.sprint_forcing = false

	_reset_sprint_press()

	if not active and not S.sprint_hold_mode and (S.is_sprinting or S.hub_was_sprinting) then
		DODGE.off_press_pending = true
		DODGE.off_press_frame = nil
	end

	_say(S.debug_notify, active and "notify_sprint_on" or "notify_sprint_off")
end

local _set_sprint_enabled = function(state)
	local was_active = _sprint_active()

	S.sprint_enabled = state

	_after_sprint_change(was_active)
end

-- ───────────────────── ❀ ─────────────────────
--  Sprint keybinds
-- ───────────────────── ❀ ─────────────────────

mod._kb_hold_reload_swap = function(held)
	if held then
		SWAP.key_down = true

		return
	end

	SWAP.key_down = false

	if SWAP.withheld and not SWAP.pressed then
		local now = _now()

		if now then
			SWAP.pressed = true
			SWAP.press_until = now + 0.05

			_say(S.debug_sprint, "swap bind released early, melee wield pressed", true)
		end
	end

	SWAP.withheld = false
end

mod._kb_toggle_sprint = function(held)
	_ensure_class_synced()

	if held then
		PRESS.undo.sprint_down_at = _now()

		_set_sprint_enabled(not S.sprint_enabled)

		return
	end

	if PRESS.undo.on and PRESS.undo.sprint_down_at then
		local now = _now()

		if now and now - PRESS.undo.sprint_down_at >= PRESS.undo.window then
			_set_sprint_enabled(not S.sprint_enabled)

			_say(S.debug_sprint, "sprint toggle press was a hold, switch undone", true)
		end
	end

	PRESS.undo.sprint_down_at = nil
end

mod._kb_hold_sprint = function(held)
	_ensure_class_synced()

	local was_active = _sprint_active()

	S.sprint_hold_down = held and true or false

	_say(S.debug_sprint, string.format("sprint hold bind %s", S.sprint_hold_down and "down" or "up"), true)

	_after_sprint_change(was_active)
end

-- ───────────────────── ❀ ─────────────────────
--  Sprint read diagnostics
-- ───────────────────── ❀ ─────────────────────

K.DIAG_LIMIT = 3
local diag_counts = {}

local _diag_read = function(site, action_name, val)
	if not S.debug_sprint then
		return
	end

	if action_name ~= K.SPRINT_HELD_INPUT and action_name ~= K.SPRINT_HOLD_MODE_INPUT and action_name ~= "sprint" then
		return
	end

	local key = site .. ":" .. action_name
	local count = (diag_counts[key] or 0) + 1

	if count > K.DIAG_LIMIT then
		return
	end

	diag_counts[key] = count

	_say(true, string.format("%s read %s = %s", site, action_name, tostring(val)), true)
end

-- ───────────────────── ❀ ─────────────────────
--  The engine sprint cooldown
-- ───────────────────── ❀ ─────────────────────

K.COOLDOWN_LAPSE_WINDOW = 0.25

local _cooldown_lapsed = function(now)
	if not now then
		return false
	end

	local _, _, sprint_state = _reload_components()

	if not sprint_state then
		return false
	end

	local cooldown = sprint_state.cooldown

	if type(cooldown) ~= "number" then
		return false
	end

	if now < cooldown then
		S.sprint_cooldown_until = cooldown

		return false
	end

	if not S.sprint_cooldown_until or now - S.sprint_cooldown_until > K.COOLDOWN_LAPSE_WINDOW then
		return false
	end

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  The sprint input filter
-- ───────────────────── ❀ ─────────────────────

local _filter_sprint_input = function(action_name, val, now)
	if not S.class_enabled then
		return val
	end

	if action_name == K.SPRINT_PRESS_INPUT then
		if val and val ~= 0 then
			S.sprint_press_pending = false
			S.sprint_press_frame = nil
			S.slide_press_carry_until = nil
			DODGE.off_press_pending = false
			DODGE.off_press_frame = nil
			S.real_sprint_press_at = now

			return val
		end

		if DODGE.off_press_pending then
			if now and not DODGE.off_press_frame and S.real_sprint_press_at and now - S.real_sprint_press_at < 0.15 then
				DODGE.off_press_pending = false

				_say(S.debug_sprint, "stop press stood down, real press already landed", true)

				return val
			end

			if now then
				if not DODGE.off_press_frame then
					DODGE.off_press_frame = now

					_say(S.debug_dodge, "sprint off press injected", true)

					if S.in_hub then
						DODGE.off_press_pending = false
						DODGE.off_press_frame = nil
					end

					return true
				end

				if now == DODGE.off_press_frame then
					return true
				end

				DODGE.off_press_pending = false
				DODGE.off_press_frame = nil
			end
		end

		if DODGE.drop_until and now and now < DODGE.drop_until then
			return val
		end

		local raw_held = S.sprint_perseverance and not (S.sprint_enabled and S.sprint_hold_down) and S.raw_sprint_held_at and now and now - S.raw_sprint_held_at < K.RAW_HELD_FRESHNESS
		local carrying = false

		if S.slide_press_carry_until then
			if now and now < S.slide_press_carry_until then
				carrying = true
			else
				S.slide_press_carry_until = nil
			end
		end

		if not (_sprint_active() or raw_held) then
			carrying = false
		end

		if (S.in_slide_state or carrying) and not S.is_sprinting and (_sprint_active() or raw_held) and not (_reload_running() or _channel_waiting() or _fire_waiting(now) or _special_waiting(now) or _ability_waiting(now)) then
			local _, forward = _move_axis()

			if type(forward) == "number" and forward >= K.SPRINT_FORWARD_MIN then
				if not S.slide_press_said then
					S.slide_press_said = true

					_say(S.debug_sprint, "sprint press held through the slide", true)
				end

				return true
			end
		end

		if not S.sprint_press_pending then
			return val
		end

		if not S.sprint_press_charging and (_reload_running() or _channel_waiting() or _fire_waiting(now) or _special_waiting(now) or _ability_waiting(now)) then
			return val
		end

		if not now then
			return val
		end

		if not S.sprint_press_frame then
			local _, action_component, sprint_state = _reload_components()

			if sprint_state and now < (sprint_state.cooldown or 0) then
				return val
			end

			if PRESS.charge.on and action_component and action_component.current_action_name ~= "none" then
				local ready = action_component.sprint_ready_time

				if type(ready) == "number" and now < ready then
					if not PRESS.charge.said then
						PRESS.charge.said = true

						_say(S.debug_sprint, "sprint press held for the weapon's ready time", true)
					end

					return val
				end
			end

			PRESS.charge.said = false
			S.sprint_press_frame = now

			_say(S.debug_sprint, "sprint press edge injected", true)

			if S.in_hub then
				S.sprint_press_pending = false
				S.sprint_press_frame = nil
			end

			return true
		end

		if now == S.sprint_press_frame then
			return true
		end

		S.sprint_press_pending = false
		S.sprint_press_frame = nil

		return val
	end

	if action_name ~= K.SPRINT_HELD_INPUT and action_name ~= K.SPRINT_HOLD_MODE_INPUT then
		return val
	end

	if action_name == K.SPRINT_HELD_INPUT and val and val ~= 0 and now then
		S.raw_sprint_held_at = now
	end

	if S.sprint_enabled and S.sprint_hold_down and action_name == K.SPRINT_HELD_INPUT then
		return false
	end

	if DODGE.drop_until and now then
		if now < DODGE.drop_until then
			if action_name == K.SPRINT_HELD_INPUT then
				_reset_sprint_press()

				return false
			end

			return val
		end

		DODGE.drop_until = nil
	end

	local resume_active = DODGE.resume_until and now and now < DODGE.resume_until and not (S.sprint_enabled and S.sprint_hold_down)

	local raw_held = S.sprint_perseverance and not (S.sprint_enabled and S.sprint_hold_down) and S.raw_sprint_held_at and now and now - S.raw_sprint_held_at < K.RAW_HELD_FRESHNESS

	if PRESS.charge.allowed then
		local _, action_component = _reload_components()

		if not action_component or action_component.current_action_name ~= PRESS.charge.action_name then
			PRESS.charge.allowed = false
			PRESS.charge.action_name = nil

			_say(S.debug_sprint, "melee charge ended", true)
		end
	end

	local charge_intent = PRESS.charge.on and PRESS.charge.allowed and not (S.sprint_enabled and S.sprint_hold_down) or false
	local reload_wait = _reload_waiting()

	if reload_wait ~= RELOAD.was_waiting then
		RELOAD.was_waiting = reload_wait

		_say(S.debug_sprint, reload_wait and "reloading, sprint automation waiting" or "ammo loaded, sprint automation resuming", true)
	end

	local fire_wait = _fire_waiting(now)

	if fire_wait ~= FIRE.was_waiting then
		FIRE.was_waiting = fire_wait

		_say(S.debug_sprint, fire_wait and "firing, sprint automation waiting" or "fire released, sprint automation resuming", true)
	end

	local special_wait = _special_waiting(now)

	if special_wait ~= SPECIAL.was_waiting then
		SPECIAL.was_waiting = special_wait

		_say(S.debug_sprint, special_wait and "weapon special running, sprint automation waiting" or "weapon special ended, sprint automation resuming", true)
	end

	local ability_wait = _ability_waiting(now)

	if ability_wait ~= ABILITY.was_waiting then
		ABILITY.was_waiting = ability_wait

		_say(S.debug_sprint, ability_wait and "ability wielding, sprint automation waiting" or "ability wielded, sprint automation resuming", true)
	end

	local channel_wait = _channel_waiting()

	if channel_wait ~= CHANNEL.was_waiting then
		CHANNEL.was_waiting = channel_wait

		if not channel_wait and now and S.raw_sprint_held_at and now - S.raw_sprint_held_at < K.RAW_HELD_FRESHNESS then
			DODGE.resume_until = now + K.DODGE_RESUME_WINDOW
		end

		_say(S.debug_sprint, channel_wait and "vent or channel running, sprint automation waiting" or "vent or channel ended, sprint automation resuming", true)
	end

	if channel_wait and action_name == K.SPRINT_HELD_INPUT then
		_reset_sprint_press()

		return false
	end

	if not (_sprint_active() or raw_held or resume_active or charge_intent) then
		if S.sprint_forcing then
			S.sprint_forcing = false

			_say(S.debug_sprint, "sprint forcing off, nothing asking for a sprint", true)
		end

		_reset_sprint_press()

		return val
	end

	local _, forward = _move_axis()
	local forward_held = type(forward) == "number" and forward >= K.SPRINT_FORWARD_MIN

	local should_force = (_sprint_active() or resume_active or charge_intent) and forward_held and S.sprint_hold_mode and not reload_wait and not fire_wait and not special_wait and not channel_wait and not ability_wait

	if should_force ~= S.sprint_forcing then
		S.sprint_forcing = should_force

		_say(S.debug_sprint, string.format("sprint forcing %s, forward %s", should_force and "on" or "off",
			type(forward) == "number" and string.format("%.2f", forward) or "unreadable"), true)
	end

	if not forward_held then
		_reset_sprint_press()

		return should_force and true or val
	end

	_refresh_hub_flag()

	if not S.sprint_hold_mode_known then
		_refresh_sprint_hold_mode()
	end

	local hub_sprint = S.in_hub and _hub_sprinting() or false

	if S.in_hub and hub_sprint ~= S.hub_was_sprinting then
		S.hub_was_sprinting = hub_sprint

		if hub_sprint then
			_reset_sprint_press()
		end

		if now and (not S.hub_said_at or now - S.hub_said_at > 0.25) then
			S.hub_said_at = now

			_say(S.debug_sprint, hub_sprint and "hub sprint confirmed" or "hub sprint ended", true)
		end
	end

	local press_context_open = S.in_hub and not hub_sprint or not S.in_hub and not S.is_sprinting and S.in_ground_state

	if now and press_context_open and (_sprint_active() or raw_held or resume_active or charge_intent) then
		S.sprint_intent_since = S.sprint_intent_since or now

		local patient = S.sprint_hold_mode == false or _cooldown_lapsed(now) or now - S.sprint_intent_since >= PRESS.patience
		local rested = not S.sprint_next_press_at or now >= S.sprint_next_press_at

		if patient and rested and not S.sprint_press_pending then
			S.sprint_press_pending = true
			S.sprint_press_charging = charge_intent and true or false
			S.sprint_next_press_at = now + PRESS.retry

			_say(S.debug_sprint, "sprint press armed, waiting for a press read", true)
		end
	elseif S.debug_sprint and now and not S.is_sprinting and not hub_sprint and (_sprint_active() or raw_held or resume_active or charge_intent) and not S.press_block_said then
		S.press_block_said = true

		_say(S.debug_sprint, "sprint press blocked: not in a ground movement state", true)
	end

	if should_force and action_name == K.SPRINT_HELD_INPUT then
		return true
	end

	return val
end

-- ───────────────────── ❀ ─────────────────────
--  Slide
-- ───────────────────── ❀ ─────────────────────

K.SPRINT_RAMP_DURATION = PlayerCharacterConstants.sprint_start_slowdown_duration or 0

K.CROUCH_HOLD_MODE_INPUT = "hold_to_crouch"
K.CROUCH_HELD_INPUT = "crouching"
K.CROUCH_PRESS_INPUT = "crouch"

K.INJECT_TIMEOUT = 0.5

K.CHAIN_WINDOW = 0.5

S.slide_enabled = mod:get("slide_always_on") and true or false
S.slide_hold_down = false

local _slide_active = function()
	return S.slide_enabled ~= S.slide_hold_down
end

S.slide_first_delay = mod:get("slide_extra_delay") or 0.08
S.slide_chain_delay = mod:get("slide_chain_delay") or 0.01
S.slide_once = mod:get("slide_once_per_sprint") and true or false

S.slide_queued_at = nil

-- ───────────────────── ❀ ─────────────────────
--  Crouch press machinery
-- ───────────────────── ❀ ─────────────────────

S.crouch_press_pending = false
S.crouch_press_frame = nil
S.crouch_latch_on = false
S.crouch_release_pending = false
S.crouch_release_frame = nil

local _arm_crouch_press = function()
	if S.crouch_press_pending then
		return
	end

	if S.crouch_latch_on and not S.crouch_release_pending then
		return
	end

	local hold_mode = _read_game_setting and _read_game_setting("hold_to_crouch")

	if hold_mode == false then
		S.crouch_press_pending = true
		S.crouch_press_frame = nil
	end
end

local _reset_crouch_press = function()
	S.crouch_press_pending = false
	S.crouch_press_frame = nil
	S.crouch_latch_on = false
	S.crouch_release_pending = false
	S.crouch_release_frame = nil
end

-- ───────────────────── ❀ ─────────────────────
--  The slide queue
-- ───────────────────── ❀ ─────────────────────

S.slide_injected = false

S.slide_exited_at = nil

local _queue_slide = function(unit)
	if not S.class_enabled or not (_slide_active() or S.slide_once) then
		_say(S.debug_slide, string.format("slide queue skipped: %s", S.class_enabled and "slide features off" or "class disabled"), true)

		return
	end

	local now = _now()

	if not now then
		return
	end

	if PRESS.charge.on and PRESS.charge.allowed and not PRESS.charge.slide_allowed then
		_say(S.debug_slide, "slide queue skipped: charge sprint, charge sliding off", true)

		return
	end

	local ramp = 0
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local sprint_component = unit_data and unit_data:read_component("sprint_character_state")

	if sprint_component and sprint_component.use_sprint_start_slowdown then
		ramp = K.SPRINT_RAMP_DURATION
	end

	local chained = S.slide_exited_at ~= nil and now - S.slide_exited_at < K.CHAIN_WINDOW

	if chained and not _slide_active() then
		_say(S.debug_slide, "chained slide skipped, once per sprint", true)

		return
	end

	local extra = chained and S.slide_chain_delay or S.slide_first_delay

	local ramp_left = math.max(0, (S.sprint_entered_at or now) + ramp - now)

	S.slide_queued_at = now + ramp_left + extra
	S.slide_injected = false

	_say(S.debug_slide, string.format("%s slide queued, ramp left %.2fs plus %.2fs, firing in %.2fs",
		chained and "chained" or "first", ramp_left, extra, S.slide_queued_at - now), true)
end

local _queue_slide_if_sprinting = function()
	if not S.is_sprinting or S.slide_queued_at then
		return
	end

	local unit = _get_player_unit()

	if unit then
		_queue_slide(unit)
	end
end

local _clear_queued_slide = function()
	if S.slide_queued_at then
		_say(S.debug_slide, "sprint ended, slide queue cleared", true)
	end

	S.slide_queued_at = nil
end

-- ───────────────────── ❀ ─────────────────────
--  The crouch input filter
-- ───────────────────── ❀ ─────────────────────

K.SLIDE_SPEED_SQ = PlayerCharacterConstants.slide_move_speed_threshold_sq or 17.64

local _slide_speed_reached = function()
	local unit = _get_player_unit()

	if not unit then
		return true
	end

	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local locomotion = unit_data and unit_data:read_component("locomotion")
	local velocity = locomotion and locomotion.velocity_current

	if not velocity then
		return true
	end

	return Vector3.length_squared(Vector3.flat(velocity)) >= K.SLIDE_SPEED_SQ
end

local _filter_crouch_input = function(action_name, val, now)
	if action_name == K.CROUCH_PRESS_INPUT then
		if val and val ~= 0 then
			_reset_crouch_press()

			return val
		end

		if now then
			if S.crouch_release_pending then
				if not S.crouch_release_frame then
					S.crouch_release_frame = now

					_say(S.debug_slide, "crouch release press injected", true)
				end

				if now == S.crouch_release_frame then
					return true
				end

				S.crouch_release_pending = false
				S.crouch_release_frame = nil
				S.crouch_latch_on = false
			elseif S.crouch_press_pending then
				if not S.crouch_press_frame then
					S.crouch_press_frame = now

					_say(S.debug_slide, "crouch press injected, toggle crouch", true)
				end

				if now == S.crouch_press_frame then
					return true
				end

				S.crouch_press_pending = false
				S.crouch_press_frame = nil
				S.crouch_latch_on = true
			end
		end

		return val
	end

	if action_name ~= K.CROUCH_HELD_INPUT and action_name ~= K.CROUCH_HOLD_MODE_INPUT then
		return val
	end

	if DODGE.slide_until then
		if now and now < DODGE.slide_until then
			if not DODGE.slide_speed_ok then
				DODGE.slide_speed_ok = S.is_sprinting or _slide_speed_reached()

				if not DODGE.slide_speed_ok then
					return val
				end
			end

			if not DODGE.slide_said then
				DODGE.slide_said = true

				_arm_crouch_press()

				_say(S.debug_dodge, "crouch forced for the dodge slide", true)
			end

			return true
		end

		DODGE.slide_until = nil

		if S.crouch_latch_on then
			S.crouch_release_pending = true
			S.crouch_release_frame = nil
		end
	end

	if (not _slide_active() and not S.slide_once) or not S.slide_queued_at then
		return val
	end

	if not now then
		return val
	end

	if now < S.slide_queued_at then
		return val
	end

	if now - S.slide_queued_at > K.INJECT_TIMEOUT then
		S.slide_queued_at = nil
		S.slide_injected = false
		S.crouch_press_pending = false
		S.crouch_press_frame = nil

		if S.crouch_latch_on then
			S.crouch_release_pending = true
			S.crouch_release_frame = nil
		end

		local hold_mode = _read_game_setting and _read_game_setting("hold_to_crouch")

		_say(S.debug_slide, string.format("slide never reached speed, crouch released, game crouch mode %s",
			hold_mode == false and "toggle" or hold_mode == true and "hold" or "unknown"), true)

		return val
	end

	if not S.slide_injected then
		S.slide_injected = true

		_arm_crouch_press()

		_say(S.debug_slide, "crouch forced, slide starting", true)
	end

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  Slide switches and keybinds
-- ───────────────────── ❀ ─────────────────────

local _after_slide_change = function(was_active)
	local active = _slide_active()

	if active == was_active then
		return
	end

	if active then
		_queue_slide_if_sprinting()
	elseif not S.slide_once then
		S.slide_queued_at = nil
	end

	_say(S.debug_notify, active and "notify_slide_on" or "notify_slide_off")
end

local _set_slide_enabled = function(state)
	local was_active = _slide_active()

	S.slide_enabled = state

	_after_slide_change(was_active)
end

mod._kb_toggle_slide = function(held)
	_ensure_class_synced()

	if held then
		PRESS.undo.slide_down_at = _now()

		_set_slide_enabled(not S.slide_enabled)

		return
	end

	if PRESS.undo.on and PRESS.undo.slide_down_at then
		local now = _now()

		if now and now - PRESS.undo.slide_down_at >= PRESS.undo.window then
			_set_slide_enabled(not S.slide_enabled)

			_say(S.debug_slide, "slide toggle press was a hold, switch undone", true)
		end
	end

	PRESS.undo.slide_down_at = nil
end

mod._kb_hold_slide = function(held)
	_ensure_class_synced()

	local was_active = _slide_active()

	S.slide_hold_down = held and true or false

	_say(S.debug_slide, string.format("slide hold bind %s", S.slide_hold_down and "down" or "up"), true)

	_after_slide_change(was_active)
end

-- ───────────────────── ❀ ─────────────────────
--  Dodge
-- ───────────────────── ❀ ─────────────────────

K.DODGE_INPUT = "dodge"
K.JUMP_INPUT = "jump"

K.DODGE_DIAGONAL_MIN = 0.707
K.DODGE_MOVE_EPSILON = 0.1

K.DODGE_DROP_WINDOW = 0.25
K.DODGE_RESUME_WINDOW = 1.5

K.DODGE_SLIDE_TIMEOUT = 0.5

K.DODGE_KB_PRESS = 0.1

K.DODGE_KB_ARM = 0.5

K.DODGE_RECENT = 0.35

-- ───────────────────── ❀ ─────────────────────
--  Dodge press reads
-- ───────────────────── ❀ ─────────────────────

local _sideways_share = function()
	local x, y = _move_axis()

	if type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end

	local length = math.sqrt(x * x + y * y)

	if length < K.DODGE_MOVE_EPSILON then
		return nil
	end

	return math.abs(x) / length
end

local _dodge_features_armed = function()
	return (DODGE.keep_sprint or DODGE.slide_on) and S.class_enabled and S.is_sprinting and not S.in_ground_state
end

local _on_dodge_press = function(now)
	if not now then
		return
	end

	local share = _sideways_share()

	if not share then
		return
	end

	local diagonal = share > K.DODGE_DIAGONAL_MIN

	if diagonal and DODGE.slide_diagonal and DODGE.slide_on then
		diagonal = false
	end

	if diagonal then
		if DODGE.keep_sprint then
			DODGE.drop_until = now + K.DODGE_DROP_WINDOW
			DODGE.replay_until = now + K.DODGE_DROP_WINDOW
			DODGE.resume_until = now + K.DODGE_RESUME_WINDOW
			DODGE.off_press_pending = true
			DODGE.off_press_frame = nil

			_say(S.debug_dodge, string.format("diagonal dodge press, sideways %.2f, sprint dropped", share), true)
		end
	elseif DODGE.slide_on then
		DODGE.slide_until = now + K.DODGE_SLIDE_TIMEOUT
		DODGE.slide_said = false
		DODGE.slide_speed_ok = false
		DODGE.slide_resume = true

		_say(S.debug_dodge, string.format("dodge press, sideways %.2f, slide forced", share), true)
	end
end

local _vanilla_dodge_on = function(mod_id, game_id)
	local live = _read_game_setting(game_id)

	if live ~= nil then
		return live and true or false
	end

	return mod:get(mod_id) and true or false
end

local _dodge_direction_ok = function()
	local x, y = _move_axis()

	if type(x) ~= "number" or type(y) ~= "number" then
		return true
	end

	if _vanilla_dodge_on("vanilla_always_dodge", "always_dodge") then
		return true
	end

	local length = math.sqrt(x * x + y * y)

	if length < K.DODGE_MOVE_EPSILON then
		return _vanilla_dodge_on("vanilla_stationary_dodge", "stationary_dodge")
	end

	if y <= 0 then
		return true
	end

	if math.abs(x) / length > K.DODGE_DIAGONAL_MIN then
		return _vanilla_dodge_on("vanilla_diagonal_forward_dodge", "diagonal_forward_dodge")
	end

	return false
end

-- ───────────────────── ❀ ─────────────────────
--  The Dodge and Slide bind
-- ───────────────────── ❀ ─────────────────────

mod._kb_dodge_slide = function()
	_ensure_class_synced()

	local now = _now()

	if not now or not S.class_enabled or S.in_hub then
		return
	end

	if S.is_sprinting and not DODGE.keep_sprint then
		_say(S.debug_dodge, "dodge slide bind, sprinting without keep sprint, no dodge to take", true)

		return
	end

	if not _dodge_direction_ok() then
		_say(S.debug_dodge, "dodge slide bind, direction refused, no dodge to take", true)

		return
	end

	if S.is_sprinting then
		DODGE.drop_until = now + K.DODGE_DROP_WINDOW
		DODGE.kb_press_until = now + K.DODGE_DROP_WINDOW
	else
		DODGE.kb_press_until = now + K.DODGE_KB_PRESS
	end

	DODGE.kb_slide_until = now + K.DODGE_KB_ARM
	DODGE.kb_resume = S.is_sprinting

	_say(S.debug_dodge, string.format("dodge slide bind, dodge pressed%s", S.is_sprinting and ", sprint dropped" or ""), true)
end

-- ───────────────────── ❀ ─────────────────────
--  The dodge input filter
-- ───────────────────── ❀ ─────────────────────

DODGE.raw_held = function(service)
	local ok_rule, rule = pcall(service.action_rule, service, K.DODGE_INPUT)

	if not ok_rule or type(rule) ~= "table" or type(rule.debug_info) ~= "table" then
		return false
	end

	local keys = service._active_keys_and_axes

	if type(keys) ~= "table" then
		return false
	end

	for i = 1, #rule.debug_info do
		local info = keys[rule.debug_info[i]]

		if info and info.device and info.index then
			local ok, held = pcall(info.device.held, info.device, info.index)

			if ok and held then
				local passed = true

				if info.enablers then
					for e = 1, #info.enablers do
						local enabler = info.enablers[e]
						local ok_e, held_e = pcall(enabler.device.held, enabler.device, enabler.index)

						if not ok_e or not held_e then
							passed = false

							break
						end
					end
				end

				if passed and info.disablers then
					for d = 1, #info.disablers do
						local disabler = info.disablers[d]
						local ok_d, held_d = pcall(disabler.device.held, disabler.device, disabler.index)

						if ok_d and held_d then
							passed = false

							break
						end
					end
				end

				if passed then
					return true
				end
			end
		end
	end

	return false
end

local _filter_dodge_input = function(action_name, val, now, service, original)
	if action_name == K.DODGE_INPUT then
		if DODGE.kb_press_until then
			if now and now < DODGE.kb_press_until then
				return true
			end

			DODGE.kb_press_until = nil
		end

		if DODGE.slide_until and now and now < DODGE.slide_until then
			return false
		end

		if DODGE.replay_until then
			if now and now < DODGE.replay_until then
				return true
			end

			DODGE.replay_until = nil
		end

		if DODGE.hold_engaged and DODGE.hold_mode == "keep" then
			return true
		end

		return val
	end

	if action_name ~= K.JUMP_INPUT then
		return val
	end

	_refresh_hub_flag()
	_stamp_move_axis(now)

	if _dodge_features_armed() and service and original then
		local ok, raw = pcall(original, service, K.DODGE_INPUT)
		local pressed = ok and raw and raw ~= 0 or false

		if pressed and not DODGE.last_val then
			DODGE.last_val = true

			_on_dodge_press(now)
		elseif not pressed then
			DODGE.last_val = false
		end
	else
		DODGE.last_val = false
	end

	if DODGE.easy_slide and S.class_enabled and not S.in_hub and not S.is_sprinting and service and original then
		local ok, raw = pcall(original, service, K.DODGE_INPUT)
		local pressed = ok and raw and raw ~= 0 or false

		if pressed and not DODGE.walk_last then
			DODGE.walk_last = true

			if DODGE.walk_edge_t and now and now - DODGE.walk_edge_t <= DODGE.easy_window then
				local move_x, move_y = _move_axis()
				local moving = move_x and move_x ~= 0 or move_y and move_y ~= 0 or false
				local dodged = DODGE.dodged_at and now - DODGE.dodged_at <= K.DODGE_RECENT

				if moving and dodged then
					DODGE.slide_until = now + K.DODGE_SLIDE_TIMEOUT
					DODGE.slide_said = false
					DODGE.slide_speed_ok = false
					DODGE.walk_edge_t = nil

					_say(S.debug_dodge, "second dodge press inside the window, dodge slide forced", true)
				else
					DODGE.walk_edge_t = now

					_say(S.debug_dodge, moving and "second dodge press but no dodge landed, no slide to force"
						or "second dodge press while stationary, no slide to force", true)
				end
			elseif now then
				DODGE.walk_edge_t = now
			end
		elseif not pressed then
			DODGE.walk_last = false
		end
	else
		DODGE.walk_last = false
	end

	if DODGE.hold_mode ~= "off" and S.class_enabled and not S.in_hub and not S.is_sprinting and not DODGE.in_vault and service then
		local down = DODGE.raw_held(service)

		if down then
			if not DODGE.hold_down then
				DODGE.hold_down = true
				DODGE.hold_since = now
				DODGE.hold_engaged = false

				_say(S.debug_dodge, "dodge key down, hold timer started", true)
			elseif not DODGE.hold_engaged and DODGE.hold_since and now and now - DODGE.hold_since >= DODGE.hold_delay then
				DODGE.hold_engaged = true

				if DODGE.hold_mode == "slide" then
					local move_x, move_y = _move_axis()
					local moving = move_x and move_x ~= 0 or move_y and move_y ~= 0 or false
					local dodged = DODGE.dodged_at and now - DODGE.dodged_at <= K.DODGE_RECENT

					if moving and dodged then
						DODGE.slide_until = now + K.DODGE_SLIDE_TIMEOUT
						DODGE.slide_said = false
						DODGE.slide_speed_ok = false
					else
						DODGE.hold_engaged = false
						DODGE.hold_since = now
					end
				end

				if DODGE.hold_engaged then
					_say(S.debug_dodge, string.format("dodge key held past the delay, %s engaged", DODGE.hold_mode), true)
				end
			end
		else
			if DODGE.hold_engaged then
				_say(S.debug_dodge, "dodge key released, hold behaviour ended", true)
			end

			DODGE.hold_down = false
			DODGE.hold_since = nil
			DODGE.hold_engaged = false
		end
	else
		DODGE.hold_down = false
		DODGE.hold_since = nil
		DODGE.hold_engaged = false
	end

	if DODGE.slide_until and now and now < DODGE.slide_until then
		return false
	end

	if DODGE.keep_sprint and S.class_enabled and S.is_sprinting and not S.in_ground_state then
		local share = _sideways_share()

		if share and share > K.DODGE_DIAGONAL_MIN then
			return false
		end
	end

	return val
end

-- ───────────────────── ❀ ─────────────────────
--  Vault
-- ───────────────────── ❀ ─────────────────────

K.JUMP_HELD_INPUT = "jump_held"
K.DEVICE_SLOT = "slot_device"

K.VAULT_FORWARD_MIN = 0.75
K.VAULT_STRAFE_MAX = 0.35

local VAULT = {
	sprinting = mod:get("vault_sprinting") and true or false,
	walking = mod:get("vault_walking") and true or false,
	mantle = mod:get("vault_mantle") and true or false,
	safe = mod:get("vault_safe") and true or false,
	fall_limit = mod:get("vault_fall_limit") or 7,
	min_height = mod:get("vault_min_height") or 0.6,
	low_seen_at = nil,
	chain_window = 1.5,
	block_said_at = nil,
	block_say_gap = 2,
	ext = nil,
	wielded_slot = nil,
	said = false,
	block_said = false,
}

_wielded_slot = function()
	return VAULT.wielded_slot
end

K.VAULT_HANG_PROBE_FORWARD = 0.3
K.VAULT_HANG_PROBE_UP = 0.5
K.VAULT_HANG_PROBE_LENGTH = 2.0
K.VAULT_GROUND_PROBE_FORWARD = 1.0
K.VAULT_GROUND_PROBE_UP = 0.5
K.VAULT_GROUND_PROBE_MARGIN = 2.0

S.vault_physics_world = nil

-- ───────────────────── ❀ ─────────────────────
--  Vault probes
-- ───────────────────── ❀ ─────────────────────

local _vault_physics = function()
	if S.vault_physics_world then
		return S.vault_physics_world
	end

	local world_manager = Managers.world

	if not world_manager then
		return nil
	end

	local ok, world = pcall(world_manager.world, world_manager, "level_world")

	if not ok or not world then
		return nil
	end

	local ok_physics, physics_world = pcall(World.physics_world, world)

	if not ok_physics or not physics_world then
		return nil
	end

	S.vault_physics_world = physics_world

	return S.vault_physics_world
end

local _unbox = function(boxed)
	local ok, vector = pcall(function()
		return boxed:unbox()
	end)

	if ok then
		return vector
	end

	return nil
end

local _hang_probe = function(physics, point, forward, up, down)
	local from = point + forward * K.VAULT_HANG_PROBE_FORWARD + up * K.VAULT_HANG_PROBE_UP

	return pcall(PhysicsWorld.raycast, physics, from, down, K.VAULT_HANG_PROBE_LENGTH, "closest", "collision_filter", "filter_hang_ledge_collision")
end

-- ───────────────────── ❀ ─────────────────────
--  Ledge judgement
-- ───────────────────── ❀ ─────────────────────

local _ledge_tall_enough = function(ledge, now)
	if VAULT.min_height <= 0 then
		return true
	end

	local height = ledge and ledge.height_distance_from_player_unit

	if type(height) == "number" and height >= VAULT.min_height then
		return true
	end

	if not now then
		return false
	end

	local chained = VAULT.low_seen_at and now - VAULT.low_seen_at < VAULT.chain_window

	VAULT.low_seen_at = now

	return not chained
end

local _say_ledge_candidates = function(ledge)
	if not S.debug_vault or not VAULT.ext then
		return
	end

	local chosen = ledge and ledge.height_distance_from_player_unit
	local parts = {}

	local ok, count, ledges = pcall(VAULT.ext.ledge_finder.ledges, VAULT.ext.ledge_finder)

	if ok and type(count) == "number" and type(ledges) == "table" then
		for i = 1, math.min(count, 5) do
			local candidate = ledges[i]
			local height = candidate and candidate.height_distance_from_player_unit
			local flat_sq = candidate and candidate.distance_flat_sq_from_player_unit

			if type(height) == "number" then
				parts[#parts + 1] = string.format("h%.2f d%.2f", height, type(flat_sq) == "number" and math.sqrt(flat_sq) or 0)
			end
		end
	end

	_say(true, string.format("ledges seen: chosen h%.2f, candidates %s",
		type(chosen) == "number" and chosen or 0,
		#parts > 0 and table.concat(parts, ", ") or "none readable"), true)
end

local _vault_landing_safe = function(ledge)
	if not VAULT.safe then
		return true
	end

	if not ledge or not ledge.forward or not ledge.left or not ledge.right then
		return false, "ledge unreadable"
	end

	local physics = _vault_physics()

	if not physics then
		return false, "physics world unreadable"
	end

	local forward = _unbox(ledge.forward)
	local left = _unbox(ledge.left)
	local right = _unbox(ledge.right)

	if not forward or not left or not right then
		return false, "ledge unreadable"
	end

	local mid = (left + right) * 0.5
	local up = Vector3.up()
	local down = -up

	for i = 1, 3 do
		local point = i == 1 and mid or i == 2 and left or right
		local ok, hit = _hang_probe(physics, point, forward, up, down)

		if not ok then
			return false, "hang probe unreadable"
		end

		if hit then
			return false, "hangable railing"
		end
	end

	local probe_from = mid + forward * K.VAULT_GROUND_PROBE_FORWARD + up * K.VAULT_GROUND_PROBE_UP
	local probe_length = VAULT.fall_limit + K.VAULT_GROUND_PROBE_UP + K.VAULT_GROUND_PROBE_MARGIN
	local ok, hit, _, hit_distance = pcall(PhysicsWorld.raycast, physics, probe_from, down, probe_length, "closest", "collision_filter", "filter_player_mover")

	if not ok then
		return false, "ground probe unreadable"
	end

	if not hit then
		return false, "no ground below the landing"
	end

	local drop = (hit_distance or probe_length) - K.VAULT_GROUND_PROBE_UP

	if drop > VAULT.fall_limit then
		return false, string.format("%.1fm drop beyond the %dm limit", drop, VAULT.fall_limit)
	end

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  The vault input filter
-- ───────────────────── ❀ ─────────────────────

S.in_air_state = false

local _capture_vault_ext = function(state)
	if type(state) ~= "table" then
		return
	end

	local ledge_finder = state._ledge_finder_extension
	local tweaks = state._ledge_vault_tweak_values
	local unit_data = state._unit_data_extension
	local input = state._input_extension
	local loadout = state._visual_loadout_extension

	if ledge_finder and tweaks and unit_data and input and loadout then
		VAULT.ext = {
			ledge_finder = ledge_finder,
			tweaks = tweaks,
			unit_data = unit_data,
			input = input,
			loadout = loadout,
		}
	end
end

local _vault_possible = function()
	local ext = VAULT.ext

	if not ext then
		return false, nil
	end

	local ok, can_vault, ledge = pcall(LedgeVaulting.can_enter, ext.ledge_finder, ext.tweaks, ext.unit_data, ext.input, ext.loadout)

	if ok and can_vault then
		return true, ledge
	end

	return false, nil
end

local _filter_vault_input = function(action_name, val, now)
	if action_name ~= K.JUMP_INPUT and action_name ~= K.JUMP_HELD_INPUT then
		return val
	end

	if val and val ~= 0 then
		return val
	end

	if not S.class_enabled or S.in_hub or VAULT.wielded_slot == K.DEVICE_SLOT or DODGE.slide_until or DODGE.drop_until then
		return val
	end

	if action_name == K.JUMP_INPUT then
		local wanted = (S.is_sprinting and VAULT.sprinting) or (S.in_ground_state and not S.is_sprinting and VAULT.walking)

		if not wanted then
			return val
		end

		local x, y = _move_axis()

		if type(x) ~= "number" or type(y) ~= "number" or y < K.VAULT_FORWARD_MIN or math.abs(x) > K.VAULT_STRAFE_MAX then
			VAULT.said = false

			return val
		end

		local possible, ledge = _vault_possible()

		if possible and not _ledge_tall_enough(ledge, now) then
			possible = false

			if not VAULT.block_said and (not VAULT.block_said_at or not now or now - VAULT.block_said_at > VAULT.block_say_gap) then
				VAULT.block_said = true
				VAULT.block_said_at = now

				_say(S.debug_vault, "vault skipped: low ledge, and low ledges keep arriving", true)

				_say_ledge_candidates(ledge)
			end
		end

		if possible then
			local safe, reason = _vault_landing_safe(ledge)

			if safe then
				if not VAULT.said then
					VAULT.said = true

					_say(S.debug_vault, "ledge ahead, jump answered for the vault", true)
				end

				return true
			end

			if not VAULT.block_said then
				VAULT.block_said = true

				_say(S.debug_vault, string.format("vault blocked: %s", reason or "unsafe landing"), true)
			end

			return val
		end

		VAULT.said = false
		VAULT.block_said = false

		return val
	end

	if not VAULT.mantle or not S.in_air_state then
		return val
	end

	local grab_possible, grab_ledge = _vault_possible()

	if grab_possible and _ledge_tall_enough(grab_ledge, now) then
		if not VAULT.said then
			VAULT.said = true

			_say(S.debug_vault, "ledge in reach, held jump answered for the grab", true)
		end

		return true
	end

	VAULT.said = false

	return val
end

-- ───────────────────── ❀ ─────────────────────
--  Jump block
-- ───────────────────── ❀ ─────────────────────

local _filter_jump_block_input = function(action_name, val, now)
	if JUMP.mode == "off" or not S.class_enabled or action_name ~= K.JUMP_INPUT then
		return val
	end

	if JUMP.mode == "always" then
		return false
	end

	if JUMP.dodge_until and now and now < JUMP.dodge_until then
		return false
	end

	return val
end

-- ───────────────────── ❀ ─────────────────────
--  Swing
-- ───────────────────── ❀ ─────────────────────

K.FORWARD_EPSILON = 0.1
K.MOVING_SPEED_EPSILON = 1

local BLOCKED_ATTACK_ACTIONS = {
	action_one_pressed = true,
	action_one_hold = true,
	weapon_extra_pressed = true,
	weapon_extra_hold = true,
}

S.swing_grace_period = (mod:get("swing_grace_ms") or 100) / 1000
S.swing_skip_when_still = mod:get("swing_skip_when_still") and true or false
S.swing_skip_when_sprinting = mod:get("swing_skip_when_sprinting") and true or false

S.swing_block_until = nil
S.swing_movement_unreadable = false
S.swing_suppressed_count = 0

S.swing_pressed_at = nil
S.swing_longest_tap = 0

K.TAP_MEASURE_CEILING = 0.4
local swing_seen_actions = {}
S.swing_seen_reported = false

-- ───────────────────── ❀ ─────────────────────
--  The swing decision
-- ───────────────────── ❀ ─────────────────────

local _forward_from_input = function()
	local _, forward = _move_axis()

	return forward
end

local _moving_from_velocity = function()
	local unit = _get_player_unit()

	if not unit then
		return nil
	end

	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local locomotion = unit_data and unit_data:read_component("locomotion")
	local velocity = locomotion and locomotion.velocity_current

	if not velocity then
		return nil
	end

	return Vector3.length(Vector3.flat(velocity)) > K.MOVING_SPEED_EPSILON
end

local _should_delay_swing = function()
	if S.swing_skip_when_sprinting and S.is_sprinting then
		return false, "already sprinting"
	end

	if not S.swing_skip_when_still then
		return true, "delay always"
	end

	local forward = _forward_from_input()

	if forward ~= nil then
		if forward > K.FORWARD_EPSILON then
			return true, string.format("moving forward %.2f", forward)
		end

		return false, string.format("not moving forward %.2f", forward)
	end

	local moving = _moving_from_velocity()

	if moving ~= nil then
		return moving, "velocity fallback, moving = " .. tostring(moving)
	end

	if not S.swing_movement_unreadable then
		S.swing_movement_unreadable = true

		mod:warning("Movement could not be read from either source; every press will be delayed.")
	end

	return true, "movement unreadable"
end

-- ───────────────────── ❀ ─────────────────────
--  The attack filter and swing bind
-- ───────────────────── ❀ ─────────────────────

local _filter_attack_input = function(action_name, val, now)
	if not S.swing_block_until then
		return val
	end

	if S.debug_swing and val == true and not BLOCKED_ATTACK_ACTIONS[action_name] then
		swing_seen_actions[action_name] = true
	end

	if not BLOCKED_ATTACK_ACTIONS[action_name] then
		return val
	end

	if not now or now >= S.swing_block_until then
		S.swing_block_until = nil

		if S.debug_swing then
			_say(S.debug_swing, string.format("window closed, %d attack reads suppressed", S.swing_suppressed_count), true)

			if S.swing_suppressed_count == 0 then
				_say(S.debug_swing, "nothing was suppressed, so no attack input reached the window", true)
			end

			if not S.swing_seen_reported then
				S.swing_seen_reported = true

				local names = {}

				for name in pairs(swing_seen_actions) do
					names[#names + 1] = name
				end

				_say(S.debug_swing, "other actions true during window: " .. (next(names) and table.concat(names, ", ") or "none"), true)
			end
		end

		S.swing_suppressed_count = 0

		return val
	end

	S.swing_suppressed_count = S.swing_suppressed_count + 1

	return false
end

mod._kb_hold_swing = function(held)
	_ensure_class_synced()

	if not held then
		if S.debug_swing and S.swing_pressed_at then
			local now = _now()

			if now then
				local ms = (now - S.swing_pressed_at) * 1000

				if ms < K.TAP_MEASURE_CEILING * 1000 then
					if ms > S.swing_longest_tap then
						S.swing_longest_tap = ms
					end

					_say(S.debug_swing, string.format("held %.0fms, longest tap so far %.0fms, suggested grace %.0fms",
						ms, S.swing_longest_tap, S.swing_longest_tap + 50), true)
				else
					_say(S.debug_swing, string.format("held %.0fms, too long to count as a tap", ms), true)
				end
			end
		end

		S.swing_pressed_at = nil

		return
	end

	local now = _now()

	S.swing_pressed_at = now
	S.swing_block_until = nil
	S.swing_suppressed_count = 0

	local delay, reason = _should_delay_swing()

	_say(S.debug_swing, string.format("block press, class %s, delay %s (%s)", tostring(S.class_enabled), tostring(delay), reason), true)

	if not S.class_enabled or not delay then
		return
	end

	if not now then
		_say(S.debug_swing, "no clock, window cannot open", true)

		return
	end

	S.swing_block_until = now + S.swing_grace_period

	_say(S.debug_swing, string.format("window open for %.0fms", S.swing_grace_period * 1000), true)
end

-- ───────────────────── ❀ ─────────────────────
--  Modifier keybind assist
-- ───────────────────── ❀ ─────────────────────

local MODIFIER_ASSIST_TARGETS = {
	{ setting = "sprint_toggle_keybind", handler = "_kb_toggle_sprint" },
	{ setting = "slide_toggle_keybind", handler = "_kb_toggle_slide" },
	{ setting = "sprint_hold_keybind", handler = "_kb_hold_sprint" },
	{ setting = "slide_hold_keybind", handler = "_kb_hold_slide" },
	{ setting = "reload_swap_keybind", handler = "_kb_hold_reload_swap" },
	{ setting = "swing_keybind", handler = "_kb_hold_swing" },
}

local MODIFIER_KEY_RAW_INDICES = {
	["shift"] = { 160, 161 },
	["ctrl"] = { 162, 163 },
	["alt"] = { 164, 165 },
}

S.modifier_assists = nil
S.modifier_last_frame = nil

local _describe_bind = function(value)
	if type(value) ~= "table" then
		return string.format("%s (%s)", tostring(value), type(value))
	end

	local parts = {}

	for key, entry in pairs(value) do
		parts[#parts + 1] = string.format("%s=%s", tostring(key), type(entry) == "table" and "(table)" or tostring(entry))
	end

	table.sort(parts)

	return "{" .. table.concat(parts, ", ") .. "}"
end

local _rebuild_modifier_assists = function()
	S.modifier_assists = {}

	for i = 1, #MODIFIER_ASSIST_TARGETS do
		local target = MODIFIER_ASSIST_TARGETS[i]
		local keys = mod:get(target.setting)
		local armed = false

		local raw = type(keys) == "table" and #keys == 1 and MODIFIER_KEY_RAW_INDICES[keys[1]]

		if raw then
			S.modifier_assists[#S.modifier_assists + 1] = { indices = raw, handler = target.handler, down = false, setting = target.setting }
			armed = true

			_say(S.debug_sprint, string.format("%s assist watching buttons %s", target.setting, table.concat(raw, ", ")), true)
		end

		_say(S.debug_sprint, string.format("%s stored as %s, modifier assist %s", target.setting, _describe_bind(keys), armed and "armed" or "not armed"), true)
	end
end

local _update_modifier_assists = function(now)
	if not now or now == S.modifier_last_frame then
		return
	end

	S.modifier_last_frame = now

	for i = 1, #S.modifier_assists do
		local assist = S.modifier_assists[i]
		local down = false

		for b = 1, #assist.indices do
			local ok, value = pcall(Keyboard.button, assist.indices[b])

			if ok and value and value > 0 then
				down = true

				break
			end
		end

		if down ~= assist.down then
			assist.down = down

			_say(S.debug_sprint, string.format("%s key %s", assist.setting or "assist", down and "down" or "up"), true)

			local handler = mod[assist.handler]

			if handler then
				handler(down)
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Graceful Swinging module
-- ───────────────────── ❀ ─────────────────────

local ATTACKS = nil

do
	local io_lib = Mods and Mods.lua and Mods.lua.io
	local f = io_lib and io_lib.open("./../mods/Grace/scripts/mods/Grace/GracefulSwinging.lua", "r")
	local module = nil

	if f then
		io_lib.close(f)
		mod:io_dofile("Grace/scripts/mods/Grace/GracefulSwinging")

		module = mod.graceful_swinging
	end

	if module and module.api == 2 then
		ATTACKS = module

		ATTACKS.init({
			now = _now,
			say = _say,
			debug = function()
				return S.debug_attacks
			end,
			notify = function()
				return S.debug_notify
			end,
			melee_wielded = function()
				return VAULT.wielded_slot == "slot_primary"
			end,
			class_enabled = function()
				return S.class_enabled
			end,
			in_hub = function()
				return S.in_hub
			end,
			current_action = function()
				local _, action = _reload_components()

				return action and action.current_action_name or nil
			end,
			time_scale = function()
				local _, action = _reload_components()

				return action and action.time_scale or nil
			end,
			special_repeat = function()
				return S.special_repeat
			end,
		})

		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_light_hold_keybind", handler = "_kb_attacks_light_hold" }
		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_heavy_hold_keybind", handler = "_kb_attacks_heavy_hold" }
		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_invert_keybind", handler = "_kb_attacks_invert" }
		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_push_hold_keybind", handler = "_kb_attacks_push_hold" }
	elseif module then
		mod:warning("GracefulSwinging.lua was built for a different version of Grace's module interface and stays inactive; download the current GracefulSwinging to match this build")
	elseif f then
		mod:warning("GracefulSwinging.lua was found but did not register and stays inactive")
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Shared hook state
-- ───────────────────── ❀ ─────────────────────

local HOOK_STATE = rawget(_G, "__grace_hook_state")

if not HOOK_STATE then
	HOOK_STATE = {}

	rawset(_G, "__grace_hook_state", HOOK_STATE)
end

HOOK_STATE.on_slide_state_changed = function(unit, sliding)
	if unit ~= _get_player_unit() then
		return
	end

	S.in_slide_state = sliding
	S.slide_press_said = false

	if sliding and DODGE.slide_until then
		DODGE.slide_until = nil

		_say(S.debug_dodge, "dodge slide confirmed", true)
	end

	if sliding then
		if S.crouch_press_frame then
			S.crouch_latch_on = true
		end

		S.crouch_press_pending = false
		S.crouch_press_frame = nil
	elseif S.crouch_latch_on then
		S.crouch_release_frame = nil
	end

	if not sliding then
		S.sprint_press_pending = false
		S.sprint_press_frame = nil

		local now = _now()

		S.slide_exited_at = now
		S.slide_press_carry_until = now and now + K.SLIDE_PRESS_CARRY or nil

		if DODGE.slide_resume then
			DODGE.slide_resume = false
			DODGE.resume_until = now and now + K.DODGE_RESUME_WINDOW or nil

			_say(S.debug_dodge, "dodge slide ended, sprint resuming", true)
		end
	end
end

HOOK_STATE.on_ground_state_changed = function(unit, grounded, state)
	if unit ~= _get_player_unit() then
		return
	end

	S.in_ground_state = grounded
	S.sprint_intent_since = nil
	S.sprint_press_pending = false
	S.sprint_press_frame = nil
	S.press_block_said = false

	if grounded then
		_capture_vault_ext(state)
	end
end

HOOK_STATE.on_sprint_enter = function(unit, state)
	if unit ~= _get_player_unit() then
		return
	end

	_capture_vault_ext(state)

	S.is_sprinting = true
	S.sprint_entered_at = _now()
	DODGE.resume_until = nil

	_reset_sprint_press()

	_say(S.debug_sprint, "sprint state confirmed", true)

	_ensure_class_synced()

	_queue_slide(unit)
end

HOOK_STATE.on_sprint_exit = function(unit, next_state)
	if unit ~= _get_player_unit() then
		return
	end

	S.is_sprinting = false
	S.sprint_entered_at = nil

	if next_state ~= "sliding" then
		DODGE.slide_until = nil
		DODGE.slide_resume = false

		if S.crouch_latch_on and not S.crouch_release_pending then
			S.crouch_release_pending = true
			S.crouch_release_frame = nil
		end
	end

	_clear_queued_slide()
end

HOOK_STATE.on_dodge_state_entered = function(unit)
	if unit ~= _get_player_unit() then
		return
	end

	DODGE.replay_until = nil
	DODGE.drop_until = nil

	_say(S.debug_dodge, "dodge confirmed, sprint resuming", true)
end

HOOK_STATE.on_air_state_changed = function(unit, inside, state)
	if unit ~= _get_player_unit() then
		return
	end

	S.in_air_state = inside

	if inside then
		_capture_vault_ext(state)
	end
end

HOOK_STATE.on_wielded_slot = function(slot, unit)
	if unit and unit ~= _get_player_unit() then
		return
	end

	VAULT.wielded_slot = slot
end

-- ───────────────────── ❀ ─────────────────────
--  Weapon action reports
-- ───────────────────── ❀ ─────────────────────

HOOK_STATE.on_weapon_action_started = function(id, action_name, action_settings, action_params, t, used_input)
	if id ~= "weapon_action" then
		return
	end

	if not action_params or action_params.player_unit ~= _get_player_unit() then
		return
	end

	_observe_ability_wield(action_settings, t, used_input)

	if type(action_settings) == "table" and action_settings.kind == K.PER_ROUND_RELOAD_KIND then
		RELOAD.per_round_action = action_name
	else
		RELOAD.per_round_action = nil
	end

	if type(action_settings) == "table" and K.CHANNEL_KINDS[action_settings.kind] then
		CHANNEL.action_name = action_name
	else
		CHANNEL.action_name = nil
	end

	local charge = PRESS.charge

	if charge.on and type(action_settings) == "table" and action_settings.kind == "windup" then
		local prevent = action_settings.prevent_sprint

		if prevent == nil then
			prevent = charge.prevent_kinds[action_settings.kind] or false
		end

		if prevent and not action_settings.override_allow_during_sprint then
			charge.allowed = false
			charge.action_name = nil
		else
			charge.allowed = true
			charge.action_name = action_name
			charge.said = false

			_say(S.debug_sprint, string.format("melee charge %s started, weapon allows sprint through it", tostring(action_name)), true)
		end
	else
		if charge.allowed then
			_say(S.debug_sprint, "melee charge ended", true)
		end

		charge.allowed = false
		charge.action_name = nil
	end

	if type(used_input) == "string" then
		SPECIAL.input_seen = true

		if _special_input(used_input) then
			SPECIAL.action_name = action_name
			SPECIAL.since = t

			_say(S.debug_sprint, string.format("weapon special started by %s", used_input), true)
		else
			SPECIAL.action_name = nil
			SPECIAL.since = nil
		end
	elseif not SPECIAL.input_seen and not SPECIAL.said_blind then
		SPECIAL.said_blind = true

		_say(S.debug_sprint, "no action start has named its input, the special wait stays idle", true)
	end

	if ATTACKS then
		ATTACKS.on_action_started(action_name, action_settings, action_params.weapon, t)
	end
end

HOOK_STATE.on_reload_action = function(unit, started)
	if unit ~= _get_player_unit() then
		return
	end

	RELOAD.active = started

	if started then
		SWAP.pressed = false
		SWAP.press_until = nil
		SWAP.withheld = false

		local _, action = _reload_components()

		RELOAD.action_name = action and action.current_action_name or nil
	else
		RELOAD.action_name = nil
	end
end

HOOK_STATE.on_save_queued = function()
	_ensure_class_synced()
	_sync_vanilla_settings()
end

-- ───────────────────── ❀ ─────────────────────
--  Input dispatch
-- ───────────────────── ❀ ─────────────────────

HOOK_STATE.filter_input = function(action_name, val, site, service, original)
	local now = _now()

	if now and (not S.class_check_at or now - S.class_check_at >= 1) then
		S.class_check_at = now

		_ensure_class_synced()
	end

	if S.modifier_assists and #S.modifier_assists > 0 then
		_update_modifier_assists(now)
	end

	_correct_movement_flags(now)
	_observe_fire_input(action_name, val, now)

	_diag_read(site or "service_sim", action_name, val)

	val = _filter_dodge_input(action_name, val, now, service, original)
	val = _filter_jump_block_input(action_name, val, now)
	val = _filter_vault_input(action_name, val, now)
	val = _filter_sprint_input(action_name, val, now)
	val = _filter_crouch_input(action_name, val, now)
	val = _filter_reload_swap_input(action_name, val, now)

	if ATTACKS then
		val = ATTACKS.filter(action_name, val, now, service, original)
	end

	val = _filter_attack_input(action_name, val, now)

	return val
end

-- ───────────────────── ❀ ─────────────────────
--  Character state hooks
-- ───────────────────── ❀ ─────────────────────

if not HOOK_STATE.sliding_state_hooked then
	HOOK_STATE.sliding_state_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateSliding, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_slide_state_changed

		if handler then
			handler(unit, true)
		end
	end)

	mod:hook_safe(CLASS.PlayerCharacterStateSliding, "on_exit", function(self, unit, t, next_state)
		local handler = HOOK_STATE.on_slide_state_changed

		if handler then
			handler(unit, false)
		end
	end)
end

if not HOOK_STATE.ground_state_hooked then
	HOOK_STATE.ground_state_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateWalking, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_ground_state_changed

		if handler then
			handler(unit, true, self)
		end
	end)

	mod:hook_safe(CLASS.PlayerCharacterStateWalking, "on_exit", function(self, unit, t, next_state)
		local handler = HOOK_STATE.on_ground_state_changed

		if handler then
			handler(unit, false)
		end
	end)

end

if not HOOK_STATE.sprint_hooked then
	HOOK_STATE.sprint_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateSprinting, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_sprint_enter

		if handler then
			handler(unit, self)
		end
	end)

	mod:hook_safe(CLASS.PlayerCharacterStateSprinting, "on_exit", function(self, unit, t, next_state)
		local handler = HOOK_STATE.on_sprint_exit

		if handler then
			handler(unit, next_state)
		end
	end)
end

if not HOOK_STATE.dodging_state_hooked then
	HOOK_STATE.dodging_state_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateDodging, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_dodge_state_entered

		if handler then
			handler(unit)
		end
	end)
end

if not HOOK_STATE.falling_state_hooked then
	HOOK_STATE.falling_state_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateFalling, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_air_state_changed

		if handler then
			handler(unit, true, self)
		end
	end)

	mod:hook_safe(CLASS.PlayerCharacterStateFalling, "on_exit", function(self, unit, t, next_state)
		local handler = HOOK_STATE.on_air_state_changed

		if handler then
			handler(unit, false)
		end
	end)
end

if not HOOK_STATE.jumping_state_hooked then
	HOOK_STATE.jumping_state_hooked = true

	mod:hook_safe(CLASS.PlayerCharacterStateJumping, "on_enter", function(self, unit, dt, t, previous_state, params)
		local handler = HOOK_STATE.on_air_state_changed

		if handler then
			handler(unit, true, self)
		end
	end)

	mod:hook_safe(CLASS.PlayerCharacterStateJumping, "on_exit", function(self, unit, t, next_state)
		local handler = HOOK_STATE.on_air_state_changed

		if handler then
			handler(unit, false)
		end
	end)
end

-- ───────────────────── ❀ ─────────────────────
--  Action and save hooks
-- ───────────────────── ❀ ─────────────────────

if not HOOK_STATE.reload_actions_hooked then
	HOOK_STATE.reload_actions_hooked = true

	for _, action_class in ipairs({ CLASS.ActionReloadState, CLASS.ActionReloadShotgun }) do
		mod:hook_safe(action_class, "start", function(self, action_settings, t, time_scale, ...)
			local handler = HOOK_STATE.on_reload_action

			if handler then
				handler(self._player_unit, true)
			end
		end)

		mod:hook_safe(action_class, "finish", function(self, reason, data, t, time_in_action)
			local handler = HOOK_STATE.on_reload_action

			if handler then
				handler(self._player_unit, false)
			end
		end)
	end
end

if not HOOK_STATE.attacks_action_hooked then
	HOOK_STATE.attacks_action_hooked = true

	mod:hook_safe(CLASS.ActionHandler, "start_action", function(self, id, action_objects, action_name, action_params, action_settings, used_input, t)
		local handler = HOOK_STATE.on_weapon_action_started

		if handler then
			handler(id, action_name, action_settings, action_params, t, used_input)
		end
	end)
end

if not HOOK_STATE.wielded_slot_hooked then
	HOOK_STATE.wielded_slot_hooked = true

	mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "_wielded_weapon", function(self, inventory_component, weapons)
		local handler = HOOK_STATE.on_wielded_slot

		if handler then
			handler(inventory_component and inventory_component.wielded_slot, self and self._unit)
		end
	end)
end

if not HOOK_STATE.save_queue_hooked then
	HOOK_STATE.save_queue_hooked = true

	mod:hook_safe(CLASS.SaveManager, "queue_save", function(self)
		local handler = HOOK_STATE.on_save_queued

		if handler then
			handler()
		end
	end)
end

-- ───────────────────── ❀ ─────────────────────
--  The options menu shine
-- ───────────────────── ❀ ─────────────────────

local SHINE = {
	hooked = false,
	last = 0,
	name = nil,
	claimed = setmetatable({}, { __mode = "k" }),
}

local _install_shine_hook = function()
	if SHINE.hooked then
		return
	end

	SHINE.hooked = true

	local stops = {
		{ 255, 255, 255 },
		{ 255, 215, 120 },
		{ 255, 150, 50 },
	}

	mod:hook_safe(CLASS.BaseView, "update", function(self)
		if self.view_name ~= "dmf_options_view" then
			return
		end

		local now = Application.time_since_launch()

		if now - SHINE.last < 0.12 then
			return
		end

		SHINE.last = now
		SHINE.name = SHINE.name or mod:localize("mod_name")

		local name = SHINE.name
		local length = #name
		local painted = {}

		for i = 1, length do
			local pos = ((i / length) - (now / 6)) % 1 * #stops
			local seg = math.floor(pos)
			local f = pos - seg
			local a = stops[seg + 1]
			local b = stops[(seg + 1) % #stops + 1]
			local r = math.floor(a[1] + (b[1] - a[1]) * f)
			local g = math.floor(a[2] + (b[2] - a[2]) * f)
			local bl = math.floor(a[3] + (b[3] - a[3]) * f)

			painted[#painted + 1] = string.format("{#color(%d,%d,%d)}%s", r, g, bl, string.sub(name, i, i))
		end

		painted[#painted + 1] = "{#reset()}"

		local text = table.concat(painted)
		local lists = { self._category_content_widgets, self._settings_content_widgets }

		for l = 1, #lists do
			local widgets = lists[l]

			if widgets then
				for w = 1, #widgets do
					local content = widgets[w].content

					if content and (content.text == name or SHINE.claimed[content]) then
						SHINE.claimed[content] = true
						content.text = text
					end
				end
			end
		end
	end)
end

-- ───────────────────── ❀ ─────────────────────
--  Input hooks
-- ───────────────────── ❀ ─────────────────────

local _install_input_hooks = function()
	if not HOOK_STATE.input_hooked then
		HOOK_STATE.input_hooked = true

		mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
			local val = func(self, action_name)
			local handler = HOOK_STATE.filter_input

			if handler then
				return handler(action_name, val, "service_get", self, func)
			end

			return val
		end)
	end

	if not HOOK_STATE.input_simulate_hooked then
		HOOK_STATE.input_simulate_hooked = true

		mod:hook(CLASS.InputService, "_get_simulate", function(func, self, action_name)
			local val = func(self, action_name)
			local handler = HOOK_STATE.filter_input

			if handler then
				return handler(action_name, val, "service_sim", self, func)
			end

			return val
		end)
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Framework callbacks
-- ───────────────────── ❀ ─────────────────────

_refresh_cache = function(id)
	if id == "debug_notify" then
		S.debug_notify = mod:get(id) and true or false
	elseif id == "debug_sprint" then
		S.debug_sprint = mod:get(id) and true or false
	elseif id == "debug_slide" then
		S.debug_slide = mod:get(id) and true or false
	elseif id == "debug_swing" then
		S.debug_swing = mod:get(id) and true or false
		S.swing_longest_tap = 0
	elseif id == "debug_dodge" then
		S.debug_dodge = mod:get(id) and true or false
	elseif id == "debug_vault" then
		S.debug_vault = mod:get(id) and true or false
	elseif id == "vault_sprinting" then
		VAULT.sprinting = mod:get(id) and true or false
	elseif id == "vault_walking" then
		VAULT.walking = mod:get(id) and true or false
	elseif id == "vault_mantle" then
		VAULT.mantle = mod:get(id) and true or false
	elseif id == "vault_safe" then
		VAULT.safe = mod:get(id) and true or false
	elseif id == "vault_fall_limit" then
		VAULT.fall_limit = mod:get(id) or 7
	elseif id == "vault_min_height" then
		VAULT.min_height = mod:get(id) or 0.6
	elseif id == "debug_class" then
		S.debug_class = mod:get(id) and true or false
	elseif id == "debug_attacks" then
		S.debug_attacks = mod:get(id) and true or false
	elseif id == "special_repeat" then
		S.special_repeat = mod:get(id) and true or false
	elseif id == "dodge_keep_sprint" then
		DODGE.keep_sprint = mod:get(id) and true or false

		if not DODGE.keep_sprint then
			DODGE.drop_until = nil
			DODGE.resume_until = nil
			DODGE.replay_until = nil
			DODGE.off_press_pending = false
			DODGE.off_press_frame = nil
			DODGE.kb_press_until = nil
			DODGE.kb_slide_until = nil
			DODGE.kb_resume = false
		end
	elseif id == "dodge_slide" then
		DODGE.slide_on = mod:get(id) and true or false

		if not DODGE.slide_on then
			DODGE.slide_until = nil
			DODGE.slide_resume = false
		end
	elseif id == "dodge_slide_diagonal" then
		DODGE.slide_diagonal = mod:get(id) and true or false
	elseif id == "dodge_easy_slide" then
		DODGE.easy_slide = mod:get(id) and true or false

		if not DODGE.easy_slide then
			DODGE.walk_edge_t = nil
			DODGE.walk_last = false
		end
	elseif id == "dodge_hold" then
		DODGE.hold_mode = mod:get(id) or "off"
		DODGE.hold_down = false
		DODGE.hold_since = nil
		DODGE.hold_engaged = false
	elseif id == "sprint_enabled" then
		S.sprint_hold_down = false
		S.sprint_enabled = mod:get(id) and true or false
		S.sprint_forcing = false
	elseif id == "sprint_reload_wait" then
		RELOAD.wait = mod:get(id) and true or false
	elseif id == "sprint_melee_charge" then
		PRESS.charge.on = mod:get(id) and true or false

		if not PRESS.charge.on then
			PRESS.charge.allowed = false
			PRESS.charge.action_name = nil
			PRESS.charge.said = false
		end
	elseif id == "sprint_charge_slide" then
		PRESS.charge.slide_allowed = mod:get(id) and true or false
	elseif id == "toggle_undo_hold" then
		PRESS.undo.on = mod:get(id) and true or false
		PRESS.undo.sprint_down_at = nil
		PRESS.undo.slide_down_at = nil
	elseif id == "jump_block" then
		JUMP.mode = mod:get(id) or "off"

		if JUMP.mode ~= "dodges" then
			JUMP.dodge_until = nil
		end
	elseif id == "sprint_toggle_keybind" or id == "slide_toggle_keybind" or id == "sprint_hold_keybind" or id == "slide_hold_keybind" or id == "reload_swap_keybind" or id == "swing_keybind"
		or id == "attacks_light_hold_keybind" or id == "attacks_heavy_hold_keybind" or id == "attacks_invert_keybind"
		or id == "attacks_push_hold_keybind" then
		if id == "slide_hold_keybind" then
			S.slide_hold_down = false
		end

		_rebuild_modifier_assists()
	elseif id == "sprint_perseverance" then
		S.sprint_perseverance = mod:get(id) and true or false
	elseif id == "slide_extra_delay" then
		S.slide_first_delay = mod:get(id) or 0
	elseif id == "slide_chain_delay" then
		S.slide_chain_delay = mod:get(id) or 0
	elseif id == "slide_once_per_sprint" then
		S.slide_once = mod:get(id) and true or false

		if S.slide_once then
			_queue_slide_if_sprinting()
		elseif not _slide_active() then
			S.slide_queued_at = nil
		end
	elseif id == "slide_always_on" then
		S.slide_hold_down = false
		S.slide_enabled = mod:get(id) and true or false

		if S.slide_enabled then
			_queue_slide_if_sprinting()
		elseif not S.slide_once then
			S.slide_queued_at = nil
		end
	elseif id == "swing_grace_ms" then
		S.swing_grace_period = (mod:get(id) or 100) / 1000
	elseif id == "swing_skip_when_still" then
		S.swing_skip_when_still = mod:get(id) and true or false
	elseif id == "swing_skip_when_sprinting" then
		S.swing_skip_when_sprinting = mod:get(id) and true or false
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Setting changes
-- ───────────────────── ❀ ─────────────────────

mod.on_setting_changed = function(id)
	if S.applying then
		return
	end

	local game_id = VANILLA_LOOKUP[id]

	if game_id then
		_write_game_setting(game_id, mod:get(id) and true or false)

		if S.per_class and S.per_class_vanilla then
			_record_edit(id)
		end

		return
	end

	if id == "per_class_reset" then
		if mod:get(id) then
			_reset_per_class_memory()
			_apply(id, false)
		end

		return
	end

	if id == "per_class_vanilla" then
		S.per_class_vanilla = mod:get(id) and true or false

		if S.per_class_vanilla then
			for i = 1, #VANILLA_SETTINGS do
				local mod_id = VANILLA_SETTINGS[i].mod_id

				mod:set(_base_key(mod_id), mod:get(mod_id))
			end

			if S.per_class and S.synced_class then
				_apply_class(S.synced_class)
			end
		else
			for i = 1, #VANILLA_SETTINGS do
				local entry = VANILLA_SETTINGS[i]
				local stored = mod:get(_base_key(entry.mod_id))

				if stored ~= nil then
					_apply_vanilla(entry, stored)
				end
			end
		end

		return
	end

	if id == "per_class" then
		S.per_class = mod:get(id) and true or false

		if S.per_class then
			_capture_base()

			S.synced_class = nil

			_ensure_class_synced()
		else
			S.synced_class = nil

			_restore_base()
		end

		return
	end

	if id:sub(1, 8) == "disable_" then
		S.synced_class = nil

		_ensure_class_synced()

		return
	end

	_refresh_cache(id)

	if S.per_class and PER_CLASS_LOOKUP[id] then
		_record_edit(id)
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Game state changes
-- ───────────────────── ❀ ─────────────────────

mod.on_game_state_changed = function(status, state_name)
	S.is_sprinting = false
	S.sprint_entered_at = nil
	diag_counts = {}
	S.in_ground_state = false
	S.in_slide_state = false
	S.slide_press_said = false
	S.slide_press_carry_until = nil
	S.raw_sprint_held_at = nil
	S.sprint_intent_since = nil
	S.sprint_press_pending = false
	S.sprint_press_frame = nil
	S.sprint_next_press_at = nil
	S.sprint_cooldown_until = nil
	S.slide_queued_at = nil
	S.slide_exited_at = nil
	S.move_x = nil
	S.move_y = nil
	S.move_at = nil
	S.swing_block_until = nil
	S.swing_suppressed_count = 0
	S.swing_pressed_at = nil
	JUMP.dodge_until = nil
	DODGE.drop_until = nil
	DODGE.resume_until = nil
	DODGE.replay_until = nil
	SPECIAL.action_name = nil
	SPECIAL.since = nil
	SPECIAL.was_waiting = false
	DODGE.slide_until = nil
	DODGE.kb_press_until = nil
	DODGE.kb_slide_until = nil
	DODGE.kb_resume = false
	DODGE.slide_speed_ok = false
	DODGE.slide_resume = false
	DODGE.dodged_at = nil
	DODGE.off_press_pending = false
	DODGE.off_press_frame = nil
	DODGE.last_val = false
	DODGE.walk_last = false
	DODGE.walk_edge_t = nil
	DODGE.hold_down = false
	DODGE.hold_since = nil
	DODGE.hold_engaged = false
	DODGE.in_vault = false
	PRESS.charge.allowed = false
	PRESS.charge.action_name = nil
	PRESS.charge.said = false
	PRESS.undo.sprint_down_at = nil
	PRESS.undo.slide_down_at = nil
	S.in_hub = false
	S.hub_checked = false
	S.hub_component = nil
	S.hub_unit = nil
	S.hub_was_sprinting = false
	S.hub_said_at = nil
	S.sprint_hold_mode_known = false
	S.class_check_at = nil
	S.real_sprint_press_at = nil
	S.sprint_hold_down = false
	S.slide_hold_down = false
	RELOAD.active = false
	RELOAD.action_name = nil
	RELOAD.per_round_action = nil
	RELOAD.component = nil
	RELOAD.action_component = nil
	RELOAD.unit = nil
	RELOAD.was_waiting = false
	CHANNEL.action_name = nil
	CHANNEL.was_waiting = false
	STATE_CHECK.frame = nil
	STATE_CHECK.component = nil
	STATE_CHECK.unit = nil
	FIRE.held_at = nil
	FIRE.was_waiting = false
	SWAP.key_down = false
	SWAP.withheld = false
	SWAP.pressed = false
	SWAP.press_until = nil
	S.sprint_press_charging = false
	S.in_air_state = false
	VAULT.ext = nil
	VAULT.wielded_slot = nil
	VAULT.said = false
	VAULT.block_said = false
	VAULT.block_said_at = nil
	VAULT.low_seen_at = nil
	S.vault_physics_world = nil

	if ATTACKS then
		ATTACKS.reset()
	end

	_reset_crouch_press()
	_ensure_class_synced()
	_sync_vanilla_settings()
end

-- ───────────────────── ❀ ─────────────────────
--  Startup and migrations
-- ───────────────────── ❀ ─────────────────────

mod.on_all_mods_loaded = function()
	_install_input_hooks()
	_install_shine_hook()
	_rebuild_modifier_assists()

	for i = 1, #KNOWN_CLASSES do
		local class = KNOWN_CLASSES[i]

		if mod:get("enable_" .. class) == false and mod:get(_disable_key(class)) == nil then
			mod:set(_disable_key(class), true)
		end
	end

	if mod:get("jump_block") == true then
		mod:set("jump_block", "always")
		JUMP.mode = "always"

		local moved = mod:localize("notify_jump_block_moved")

		mod:notify(moved)
		mod:echo(moved)
	end

	if mod:get("reload_swap_melee") then
		mod:set("reload_swap_melee", false)

		local moved = mod:localize("notify_reload_swap_moved")

		mod:notify(moved)
		mod:echo(moved)
	end

	_sync_vanilla_settings()

	if S.per_class then
		for i = 1, #PER_CLASS_SETTINGS do
			local id = PER_CLASS_SETTINGS[i]

			if mod:get(_base_key(id)) == nil then
				mod:set(_base_key(id), mod:get(id))
			end
		end

		if S.per_class_vanilla then
			for i = 1, #VANILLA_SETTINGS do
				local id = VANILLA_SETTINGS[i].mod_id

				if mod:get(_base_key(id)) == nil then
					mod:set(_base_key(id), mod:get(id))
				end
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Shutdown
-- ───────────────────── ❀ ─────────────────────

mod.on_disabled = function()
	S.swing_block_until = nil
	S.swing_suppressed_count = 0
	S.slide_queued_at = nil
	S.sprint_forcing = false
	JUMP.dodge_until = nil
	DODGE.drop_until = nil
	DODGE.resume_until = nil
	DODGE.replay_until = nil
	SPECIAL.action_name = nil
	SPECIAL.since = nil
	SPECIAL.was_waiting = false
	DODGE.slide_until = nil
	DODGE.kb_press_until = nil
	DODGE.kb_slide_until = nil
	DODGE.kb_resume = false
	DODGE.slide_speed_ok = false
	DODGE.slide_resume = false
	DODGE.dodged_at = nil
	DODGE.off_press_pending = false
	DODGE.off_press_frame = nil
	DODGE.last_val = false
	DODGE.walk_last = false
	DODGE.walk_edge_t = nil
	DODGE.hold_down = false
	DODGE.hold_since = nil
	DODGE.hold_engaged = false
	DODGE.in_vault = false
	PRESS.charge.allowed = false
	PRESS.charge.action_name = nil
	PRESS.charge.said = false
	PRESS.undo.sprint_down_at = nil
	PRESS.undo.slide_down_at = nil
	S.in_air_state = false
	VAULT.said = false
	_reset_crouch_press()
	_reset_sprint_press()
end
