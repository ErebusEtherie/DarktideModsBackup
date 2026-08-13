local mod = get_mod("Grace")

local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local LedgeVaulting = require("scripts/extension_systems/character_state_machine/character_states/utilities/ledge_vaulting")

-- Shared
-- --------------------------------------------------------------------------

local debug_notify = mod:get("debug_notify") and true or false
local debug_sprint = mod:get("debug_sprint") and true or false
local debug_slide = mod:get("debug_slide") and true or false
local debug_dodge = mod:get("debug_dodge") and true or false
local debug_vault = mod:get("debug_vault") and true or false
local debug_swing = mod:get("debug_swing") and true or false
local debug_class = mod:get("debug_class") and true or false
local debug_attacks = mod:get("debug_attacks") and true or false

local clock_unreadable = false
local player_count_unreadable = false

-- Set from the sprinting state's enter and exit hooks; shared by Sprint,
-- Slide and Swing. The timestamp serves the slide queue's ramp wait.
local is_sprinting = false
local sprint_entered_at = nil


local _say = function(channel, key_or_text, is_literal)
	if not channel then
		return
	end

	mod:echo(is_literal and key_or_text or mod:localize(key_or_text))
end

-- Several features gate on this and fail silently when it returns nil, so more
-- than one timer name is tried. "gameplay" is the name the movement code reads.
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

	if not clock_unreadable then
		clock_unreadable = true

		mod:warning("No usable clock could be read; timed features depend on it.")
	end

	return nil
end

-- local_player faults at engine level with no session, which pcall does not
-- catch, so the player count is read first. A field read cannot fault the way
-- the call can.
local _in_session = function()
	local player_manager = Managers.player

	if not player_manager then
		return false
	end

	local num_players = rawget(player_manager, "_num_players")

	if type(num_players) ~= "number" then
		if not player_count_unreadable then
			player_count_unreadable = true

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

local _move_axis = function()
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

	if not axis_read or type(y) ~= "number" then
		return nil, nil
	end

	return x, y
end

-- Per class settings
-- --------------------------------------------------------------------------
-- Live settings, a base snapshot, per class stores on top; values are
-- written on class change, not resolved on read.

local _refresh_cache
local _write_game_setting
local _read_game_setting
local _refresh_sprint_hold_mode

local VANILLA_SAVE_LOCATION = "input_settings"

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
	"slide_always_on",
	"slide_once_per_sprint",
	"slide_extra_delay",
	"slide_chain_delay",
	"dodge_keep_sprint",
	"dodge_slide",
	"vault_sprinting",
	"vault_walking",
	"vault_mantle",
	"vault_safe",
	"vault_fall_limit",
	"swing_grace_ms",
	"swing_skip_when_still",
	"swing_skip_when_sprinting",
}

local PER_CLASS_LOOKUP = {}

for i = 1, #PER_CLASS_SETTINGS do
	PER_CLASS_LOOKUP[PER_CLASS_SETTINGS[i]] = true
end

local per_class = mod:get("per_class") and true or false
local per_class_vanilla = mod:get("per_class_vanilla") and true or false

local synced_class = nil
local class_enabled = true
local applying = false
local unknown_classes = {}

-- Every class the stores can hold; the reset walks this list, so a class
-- added later needs adding here too.
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

local _apply = function(id, value)
	applying = true

	mod:set(id, value)

	if _refresh_cache then
		_refresh_cache(id)
	end

	applying = false
end

local _capture_base = function()
	for i = 1, #PER_CLASS_SETTINGS do
		local id = PER_CLASS_SETTINGS[i]

		mod:set(_base_key(id), mod:get(id))
	end

	if per_class_vanilla then
		for i = 1, #VANILLA_SETTINGS do
			local id = VANILLA_SETTINGS[i].mod_id

			mod:set(_base_key(id), mod:get(id))
		end
	end
end

-- Applying a mirrored setting writes the game's save too, so a value put
-- back by class change or restore takes real effect, not just menu effect.
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

	if per_class_vanilla then
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

	if per_class_vanilla then
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

-- Wipes every per-class store and snapshot, leaves the disable switches
-- alone, and re-captures a fresh base when Per Class is on so today
-- becomes the new restore point.
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

	if per_class then
		_capture_base()
	end

	-- The one always-on message: a popup on the notification feed, visible
	-- over the menus where the reset is run, never routed through chat.
	mod:notify(mod:localize("notify_class_reset"))
end

-- Rides the input reads once a second, since no game event fires for a
-- loadless character switch. No-ops when the class is unchanged.
local class_check_at = nil

local _ensure_class_synced = function()
	local class = _current_class()

	if not class or class == synced_class then
		return
	end

	synced_class = class

	-- A defined setting always answers, so nil means an archetype added since
	-- this version. The mod runs on it regardless and reports it once.
	local stored = mod:get(_disable_key(class))

	class_enabled = not stored

	if stored == nil and not unknown_classes[class] then
		unknown_classes[class] = true

		mod:warning(string.format("No class switch defined for '%s'; running on it by default.", class))
	end

	if per_class then
		_apply_class(class)

		_say(debug_class, string.format("per class settings applied for %s", class), true)
	end

	_say(debug_class, string.format("%s, mod is %s", class, class_enabled and "on" or "off"), true)
end

local _record_edit = function(id)
	local class = synced_class or _current_class()

	if class then
		synced_class = class

		mod:set(_class_key(class, id), mod:get(id))
	else
		mod:set(_base_key(id), mod:get(id))
	end
end

-- Game settings bridge
-- --------------------------------------------------------------------------
-- Mirrors the game's five movement settings, two doors into the same save
-- field, written the way the vanilla menu writes and re-read on every
-- queued save.

local vanilla_write_failed = false

-- The game's own reader and writer both require a local player before
-- touching the save, so the same gate is kept here.
local _game_settings_table = function()
	local save_manager = Managers.save

	if not save_manager or not _local_player() then
		return nil
	end

	local ok, account_data = pcall(save_manager.account_data, save_manager)

	if not ok or type(account_data) ~= "table" then
		return nil
	end

	return account_data[VANILLA_SAVE_LOCATION]
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
		if not vanilla_write_failed then
			vanilla_write_failed = true

			mod:warning("The game settings could not be written; use the game's own options menu instead.")
		end

		return
	end

	settings[game_id] = value and true or false

	save_manager:queue_save()
end

-- Save into checkboxes through the applying guard; a change arriving here
-- came from the game's own menu and counts as a per-class edit when the
-- opt-in is on.
local _sync_vanilla_settings = function()
	_refresh_sprint_hold_mode()

	for i = 1, #VANILLA_SETTINGS do
		local entry = VANILLA_SETTINGS[i]
		local value = _read_game_setting(entry.game_id)

		if value ~= nil then
			value = value and true or false

			if (mod:get(entry.mod_id) and true or false) ~= value then
				_apply(entry.mod_id, value)

				if per_class and per_class_vanilla then
					_record_edit(entry.mod_id)
				end
			end
		end
	end
end

-- The dodge features' state, in one table declared ahead of the sprint and
-- crouch filters that read it; the features' own logic lives in the Dodge
-- section. Timestamps are absolute deadlines, nil while inactive.
local DODGE = {
	keep_sprint = mod:get("dodge_keep_sprint") and true or false,
	slide_on = mod:get("dodge_slide") and true or false,
	drop_until = nil,
	resume_until = nil,
	replay_until = nil,
	slide_until = nil,
	slide_said = false,
	slide_resume = false,
	off_press_pending = false,
	off_press_frame = nil,
	last_val = false,
}

-- Sprint
-- --------------------------------------------------------------------------
-- Hold mode: force the held state. Toggle mode: inject a press, retried
-- until the sprint state confirms, carried through slides.

-- Names from Sprint.sprint_input. hold_to_sprint picks the branch, sprinting
-- answers the hold branch, and sprint is the press edge the toggle branch
-- reads.
local SPRINT_HELD_INPUT = "sprinting"
local SPRINT_HOLD_MODE_INPUT = "hold_to_sprint"
local SPRINT_FORWARD_MIN = 0.75

local SPRINT_PRESS_INPUT = "sprint"

-- Patience serves hold mode only (zeroed in toggle); the retry re-arms
-- only unconfirmed, so a press can never toggle a running sprint off.
local PRESS = {
	patience = 0.15,
	retry = 0.4,
}

local sprint_enabled = mod:get("sprint_enabled") and true or false
local sprint_forcing = false

local sprint_intent_since = nil
local sprint_press_pending = false
local sprint_press_frame = nil
local sprint_next_press_at = nil

-- True while the character is in the walking state or the hub jog state,
-- where an injected press unambiguously means start and retries are safe.
local in_ground_state = false

-- One announcement per stretch of blocked press intent on the debug
-- channel, reset whenever the press state resets.
local press_block_said = false

-- A stop press stands down when a real press just landed: the sprint is
-- already stopped and a second press would toggle it straight back on.
local real_sprint_press_at = nil

-- While the pause bind is held, every implicit sprint driver stands down;
-- Perseverance would otherwise read the pausing key as sprint intent.
-- The held keybind is a plain down flag, never an inversion of stored
-- state. The effective state is the baseline inverted while the key is
-- down, and a hold that suppresses an active baseline is what counts as
-- pausing.
local sprint_hold_down = false

-- Hub detection asks the game mode directly and reads the hub jog
-- component; the hub jog state hooks never fire in play.
local in_hub = false
local hub_checked = false
local hub_component = nil
local hub_was_sprinting = false
local hub_said_at = nil

-- The real Hold to Sprint via the bridge; forcing runs in hold mode only,
-- since in toggle it fed only the presentation layer (visible hitch).
-- Assumed hold until readable, refreshed on every settings save.
local sprint_hold_mode = true
local sprint_hold_mode_known = false

-- Wait For Reloads: automation stands down until has_refilled_ammunition
-- flips in the action_reload component; real presses and hand-armed
-- presses are exempt. The weapon_action component is read alongside so a
-- reload the engine discarded without a finish call is still detected.
-- Persistent state lives in a feature table, as DODGE and VAULT do.
local RELOAD = {
	wait = mod:get("sprint_reload_wait") and true or false,
	active = false,
	action_name = nil,
	component = nil,
	action_component = nil,
	unit = nil,
	sprint_component = nil,
	was_waiting = false,
}
local sprint_press_by_hand = false

-- Returns the action_reload and weapon_action components for the current
-- player unit, refetched whenever the unit changes so a respawn or a
-- character switch never reads a dead unit's data.
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

local _reload_waiting = function()
	if not RELOAD.wait or not RELOAD.active then
		return false
	end

	local reload, action = _reload_components()

	if not reload then
		return false
	end

	-- A server correction replaces the running action without calling
	-- finish, so a reload cancelled by an interruption never clears the
	-- latch through the finish hook. The weapon action component carries
	-- the corrected truth; when it stops naming the reload, the latch
	-- clears here and the withheld sprint press is free to fire.
	if RELOAD.action_name and action.current_action_name ~= RELOAD.action_name then
		RELOAD.active = false
		RELOAD.action_name = nil
		RELOAD.was_waiting = false

		_say(debug_sprint, "reload cancelled, sprint automation resuming", true)

		return false
	end

	return not reload.has_refilled_ammunition
end

-- Swap To Melee After Reloads
-- --------------------------------------------------------------------------

-- Assigned once the vault state exists further down; the wielded slot is
-- tracked there and this reads it without depending on declaration order.
local _wielded_slot

-- Wait While Firing: the sprint automation stands down while the attack
-- input is held with a ranged weapon in hand. Freshness rather than a
-- release edge, since the read only arrives while the button is down.
local FIRE = {
	wait = mod:get("sprint_fire_wait") and true or false,
	held_at = nil,
	was_waiting = false,
	freshness = 0.1,
}

-- Watched from the chain head: the sprint filter narrows to sprint
-- actions before this read would reach it.
local _observe_fire_input = function(action_name, val, now)
	if action_name == "action_one_hold" and val and val ~= 0 and now then
		FIRE.held_at = now
	end
end

local _fire_waiting = function(now)
	if not FIRE.wait or not now or not FIRE.held_at then
		return false
	end

	if not _wielded_slot or _wielded_slot() ~= "slot_secondary" then
		return false
	end

	return now - FIRE.held_at < FIRE.freshness
end

-- Movement state corrector
-- --------------------------------------------------------------------------
-- The state hooks remain the primary path. A server correction swaps the
-- running character state without calling on_exit or on_enter, and the
-- first state of a mission can land before the local player unit
-- resolves; either leaves the tracking flags stale with no event to fix
-- them. The character_state component carries the live name, read once
-- per clock frame riding the input reads, and only used to correct drift.

-- Mode "dodges" answers only while the dodging state is live and for
-- block_window after it, so a press that the game refuses as a dodge
-- cannot fall through to a jump partway along a chain. Each dodge
-- refreshes the deadline and entering a slide clears it, a slide being
-- committed enough that a jump press there means a slide jump. Both are
-- set from the live state read in _correct_movement_flags.
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

		STATE_CHECK.component = component
		STATE_CHECK.unit = unit
	end

	local name = STATE_CHECK.component.state_name

	if type(name) ~= "string" or name == "dummy" then
		return
	end

	local sprinting = name == "sprinting"
	local grounded = STATE_CHECK.ground_names[name] and true or false

	if name == "dodging" then
		JUMP.dodge_until = now + JUMP.block_window
	elseif name == "sliding" then
		JUMP.dodge_until = nil
	end

	if sprinting ~= is_sprinting then
		is_sprinting = sprinting

		_say(debug_sprint, string.format("sprint tracking corrected to %s from the live state", sprinting and "sprinting" or "not sprinting"), true)
	end

	if grounded ~= in_ground_state then
		in_ground_state = grounded
		press_block_said = false

		_say(debug_sprint, string.format("ground tracking corrected to %s from the live state", grounded and "grounded" or "airborne"), true)
	end
end

local SWAP = {
	key_down = false,
	withheld = false,
	pressed = false,
	press_until = nil,
}

-- Hold the bind during a reload and the melee swap waits for the
-- ammunition instead of throwing the reload away. Holding withholds the
-- melee wield read, and the press is handed over the moment
-- has_refilled_ammunition flips. Releasing early hands it over at once,
-- but only when a real press was being withheld, which keeps a bind
-- sharing the reload key from swapping mid-reload. Independent of Wait
-- For Reloads; only the tracking is shared.
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

	_say(debug_sprint, "ammunition landed with the swap bind held, melee wield pressed", true)

	return true
end

_refresh_sprint_hold_mode = function()
	local value = _read_game_setting and _read_game_setting("hold_to_sprint")

	if value ~= nil then
		sprint_hold_mode = value and true or false
		sprint_hold_mode_known = true
	end
end

local _refresh_hub_flag = function()
	if hub_checked then
		return
	end

	local state_manager = Managers.state
	local game_mode = state_manager and state_manager.game_mode

	if not game_mode then
		return
	end

	local ok, social = pcall(game_mode.is_social_hub, game_mode)

	in_hub = ok and social and true or false
	hub_checked = true
end

local _hub_sprinting = function()
	if not in_hub then
		return false
	end

	if not hub_component then
		local unit = _get_player_unit()

		if not unit or not ScriptUnit.has_extension(unit, "unit_data_system") then
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

		hub_component = component
	end

	return hub_component.move_state == "sprint"
end

-- Through a slide the press is answered continuously, and for this long
-- past the slide's end, so the single walking frame a slide exits through
-- sees it. Sprint confirming, a real press, or losing forward all end it.
local SLIDE_PRESS_CARRY = 0.3

local in_slide_state = false
local slide_press_said = false
local slide_press_carry_until = nil

-- Perseverance: a physically held sprint key counts as sprint intent for
-- this long past its last stamped read; release stops nothing itself.
local RAW_HELD_FRESHNESS = 0.1

local sprint_perseverance = mod:get("sprint_perseverance") and true or false

local raw_sprint_held_at = nil

local _reset_sprint_press = function()
	sprint_intent_since = nil
	sprint_press_pending = false
	sprint_press_frame = nil
	sprint_next_press_at = nil
	slide_press_carry_until = nil
	press_block_said = false
end

local _sprint_active = function()
	return sprint_enabled ~= sprint_hold_down
end

-- Applies the side effects of an effective state change. Callers capture
-- the effective state before their write and pass it in, so a write that
-- changes nothing stays silent.
local _after_sprint_change = function(was_active)
	local active = _sprint_active()

	if active == was_active then
		return
	end

	sprint_forcing = false

	_reset_sprint_press()

	-- A toggle-mode sprint outlives the feature switching off, so a stop
	-- press is injected to match hold mode's visible stop.
	if not active and not sprint_hold_mode and (is_sprinting or hub_was_sprinting) then
		DODGE.off_press_pending = true
		DODGE.off_press_frame = nil
	end

	_say(debug_notify, active and "notify_sprint_on" or "notify_sprint_off")
end

local _set_sprint_enabled = function(state)
	local was_active = _sprint_active()

	sprint_enabled = state

	_after_sprint_change(was_active)
end

-- Holding arms the wait; releasing before the ammunition lands hands the
-- melee press straight over, but only if one was being withheld, so a bind
-- sharing the reload key disarms quietly instead of swapping.
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

			_say(debug_sprint, "swap bind released early, melee wield pressed", true)
		end
	end

	SWAP.withheld = false
end

mod._kb_toggle_sprint = function(held)
	_ensure_class_synced()
	_set_sprint_enabled(not sprint_enabled)
end

mod._kb_hold_sprint = function(held)
	_ensure_class_synced()

	local was_active = _sprint_active()

	sprint_hold_down = held and true or false

	_say(debug_sprint, string.format("sprint hold bind %s", sprint_hold_down and "down" or "up"), true)

	_after_sprint_change(was_active)
end

-- Read-site diagnostics on the Sprint debug channel: the first few sightings
-- of each sprint input per hook site each mission, then silence, so one run
-- shows which sites the game actually reads through and with what raw values.
local DIAG_LIMIT = 3
local diag_counts = {}

local _diag_read = function(site, action_name, val)
	if not debug_sprint then
		return
	end

	if action_name ~= SPRINT_HELD_INPUT and action_name ~= SPRINT_HOLD_MODE_INPUT and action_name ~= "sprint" then
		return
	end

	local key = site .. ":" .. action_name
	local count = (diag_counts[key] or 0) + 1

	if count > DIAG_LIMIT then
		return
	end

	diag_counts[key] = count

	_say(true, string.format("%s read %s = %s", site, action_name, tostring(val)), true)
end


local _filter_sprint_input = function(action_name, val, now)
	if not class_enabled then
		return val
	end

	-- A real press cancels any injection under way; the player's own edge
	-- does the job or must not be paired with a second one.
	if action_name == SPRINT_PRESS_INPUT then
		if val and val ~= 0 then
			sprint_press_pending = false
			sprint_press_frame = nil
			slide_press_carry_until = nil
			DODGE.off_press_pending = false
			DODGE.off_press_frame = nil
			real_sprint_press_at = now

			return val
		end

		-- The off press that drops a toggle-mode sprint for a dodge, one
		-- frame true by the same clock-frame trick as the start press. Hold
		-- mode ignores the edge, so injecting it blind is harmless there.
		if DODGE.off_press_pending then
			if now and not DODGE.off_press_frame and real_sprint_press_at and now - real_sprint_press_at < 0.15 then
				DODGE.off_press_pending = false

				_say(debug_sprint, "stop press stood down, real press already landed", true)

				return val
			end

			if now then
				if not DODGE.off_press_frame then
					DODGE.off_press_frame = now

					_say(debug_dodge, "sprint off press injected", true)

					-- The hub consumes a clock-frame press twice; one read
					-- only there, mirroring the start press.
					if in_hub then
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

		-- While the drop window is open no press machinery may fight it.
		if DODGE.drop_until and now and now < DODGE.drop_until then
			return val
		end

		local raw_held = sprint_perseverance and not (sprint_enabled and sprint_hold_down) and raw_sprint_held_at and now and now - raw_sprint_held_at < RAW_HELD_FRESHNESS
		local carrying = false

		if slide_press_carry_until then
			if now and now < slide_press_carry_until then
				carrying = true
			else
				slide_press_carry_until = nil
			end
		end

		if not (_sprint_active() or raw_held) then
			carrying = false
		end

		if (in_slide_state or carrying) and not is_sprinting and (_sprint_active() or raw_held) then
			local _, forward = _move_axis()

			if type(forward) == "number" and forward >= SPRINT_FORWARD_MIN then
				if not slide_press_said then
					slide_press_said = true

					_say(debug_sprint, "sprint press held through the slide", true)
				end

				return true
			end
		end

		if not sprint_press_pending then
			return val
		end

		-- An armed press holds its fire through a reload wait, so the frame
		-- the ammunition lands is the frame the sprint resumes; a press
		-- armed off the physically held key fires regardless.
		if not sprint_press_by_hand and (_reload_waiting() or _fire_waiting(now)) then
			return val
		end

		if not now then
			return val
		end

		if not sprint_press_frame then
			-- The toggle want is the sprint state itself, so a press consumed
			-- during the sprint cooldown toggles nothing and is wasted. The
			-- cooldown is readable, so the press waits it out and fires on
			-- the first read that can work.
			local _, _, sprint_state = _reload_components()

			if sprint_state and now < (sprint_state.cooldown or 0) then
				return val
			end

			sprint_press_frame = now

			_say(debug_sprint, "sprint press edge injected", true)

			-- The hub consumes a clock-frame press twice, and a toggle
			-- press consumed twice re-toggles; one read only there.
			if in_hub then
				sprint_press_pending = false
				sprint_press_frame = nil
			end

			return true
		end

		if now == sprint_press_frame then
			return true
		end

		sprint_press_pending = false
		sprint_press_frame = nil

		return val
	end

	if action_name ~= SPRINT_HELD_INPUT and action_name ~= SPRINT_HOLD_MODE_INPUT then
		return val
	end

	if action_name == SPRINT_HELD_INPUT and val and val ~= 0 and now then
		raw_sprint_held_at = now
	end

	-- While genuinely pausing, the held state is answered false (the drop
	-- window's proven mechanism) so hold mode stops despite the physical
	-- key. Pausing direction only: an engaging hold must not choke itself.
	if sprint_enabled and sprint_hold_down and action_name == SPRINT_HELD_INPUT then
		return false
	end

	-- While the drop window is open the held state is answered false, which
	-- is what stops a hold-mode sprint, and forcing and injection stand down
	-- so the sprint state can exit and take the dodge press.
	if DODGE.drop_until and now then
		if now < DODGE.drop_until then
			if action_name == SPRINT_HELD_INPUT then
				_reset_sprint_press()

				return false
			end

			return val
		end

		DODGE.drop_until = nil
	end

	-- After the drop, the resume window counts as sprint intent of its own,
	-- so manual sprinters get their sprint back as well as Always users.
	-- Sprint confirming clears it from the state hooks.
	local resume_active = DODGE.resume_until and now and now < DODGE.resume_until and not (sprint_enabled and sprint_hold_down)

	local raw_held = sprint_perseverance and not (sprint_enabled and sprint_hold_down) and raw_sprint_held_at and now and now - raw_sprint_held_at < RAW_HELD_FRESHNESS
	local _, forward = _move_axis()
	local forward_held = type(forward) == "number" and forward >= SPRINT_FORWARD_MIN
	local reload_wait = _reload_waiting()

	if reload_wait ~= RELOAD.was_waiting then
		RELOAD.was_waiting = reload_wait

		_say(debug_sprint, reload_wait and "reloading, sprint automation waiting" or "ammo loaded, sprint automation resuming", true)
	end

	local fire_wait = _fire_waiting(now)

	if fire_wait ~= FIRE.was_waiting then
		FIRE.was_waiting = fire_wait

		_say(debug_sprint, fire_wait and "firing, sprint automation waiting" or "fire released, sprint automation resuming", true)
	end

	local should_force = (_sprint_active() or resume_active) and forward_held and sprint_hold_mode and not reload_wait and not fire_wait

	if should_force ~= sprint_forcing then
		sprint_forcing = should_force

		_say(debug_sprint, string.format("sprint forcing %s, forward %s", should_force and "on" or "off",
			type(forward) == "number" and string.format("%.2f", forward) or "unreadable"), true)
	end

	if not forward_held then
		_reset_sprint_press()

		return should_force and true or val
	end

	-- Hub press context comes from the mode check and the hub jog
	-- component; the component flipping to sprint is the confirmation.
	_refresh_hub_flag()

	if not sprint_hold_mode_known then
		_refresh_sprint_hold_mode()
	end

	local hub_sprint = in_hub and _hub_sprinting() or false

	if in_hub and hub_sprint ~= hub_was_sprinting then
		hub_was_sprinting = hub_sprint

		if hub_sprint then
			_reset_sprint_press()
		end

		-- The hub move state flickers through a boundary frame on sprint
		-- starts, so announcements within a breath of the last are the
		-- same event and stay quiet.
		if now and (not hub_said_at or now - hub_said_at > 0.25) then
			hub_said_at = now

			_say(debug_sprint, hub_sprint and "hub sprint confirmed" or "hub sprint ended", true)
		end
	end

	local press_context_open = in_hub and not hub_sprint or not in_hub and not is_sprinting and in_ground_state

	if now and press_context_open and (_sprint_active() or raw_held or resume_active) then
		sprint_intent_since = sprint_intent_since or now

		-- Patience lets hold-mode forcing go first; in toggle mode there
		-- is nothing to wait for and the wait was pure start latency.
		local patient = sprint_hold_mode == false or now - sprint_intent_since >= PRESS.patience
		local rested = not sprint_next_press_at or now >= sprint_next_press_at

		if patient and rested and not sprint_press_pending then
			sprint_press_pending = true
			sprint_press_by_hand = raw_held and true or false
			sprint_next_press_at = now + PRESS.retry

			_say(debug_sprint, "sprint press armed, waiting for a press read", true)
		end
	elseif debug_sprint and now and not is_sprinting and not hub_sprint and (_sprint_active() or raw_held or resume_active) and not press_block_said then
		-- The one gate left is the ground state; naming it here is what a
		-- hub debug run needs, said once per stretch of blocked intent.
		press_block_said = true

		_say(debug_sprint, "sprint press blocked: not in a ground movement state", true)
	end

	-- Only the held state is forced; the mode preference resolves server
	-- side and client forcing of it only ever fed false predictions.
	if should_force and action_name == SPRINT_HELD_INPUT then
		return true
	end

	return val
end

-- Slide
-- --------------------------------------------------------------------------
-- Sprinting queues a slide, the input hook answers the next crouch read, and
-- leaving the sprint clears the queue.

-- Slide before the ramp is up and it carries no speed, dropping straight back
-- to walking. Always waited out.
local SPRINT_RAMP_DURATION = PlayerCharacterConstants.sprint_start_slowdown_duration or 0

-- Crouch reaches the states through three actions; the toggle branch
-- flips a persistent latch, which is why the press machinery below
-- exists.
local CROUCH_HOLD_MODE_INPUT = "hold_to_crouch"
local CROUCH_HELD_INPUT = "crouching"
local CROUCH_PRESS_INPUT = "crouch"

-- Covers a sprint that never reaches slide speed, where forcing the inputs
-- indefinitely would hold the player in a crouch they did not ask for.
local INJECT_TIMEOUT = 0.5

-- How soon after a slide's exit a new sprint still counts as chaining;
-- anything slower is the player setting off again.
local CHAIN_WINDOW = 0.5

-- slide_enabled is the baseline set by Always Slide and the toggle
-- keybind; the held keybind is a plain down flag layered on top, and the
-- effective state is the baseline inverted while the key is down, so one
-- clean press and release of the key resynchronizes everything.
local slide_enabled = mod:get("slide_always_on") and true or false
local slide_hold_down = false

local _slide_active = function()
	return slide_enabled ~= slide_hold_down
end

local slide_first_delay = mod:get("slide_extra_delay") or 0.08
local slide_chain_delay = mod:get("slide_chain_delay") or 0.01
local slide_once = mod:get("slide_once_per_sprint") and true or false

local slide_queued_at = nil

-- Toggle crouch obeys only real press edges: one press latches the crouch
-- that becomes the slide, one more after unlatches. Never retried within
-- an attempt: a retry would toggle the latch straight back off.
local crouch_press_pending = false
local crouch_press_frame = nil
local crouch_latch_on = false
local crouch_release_pending = false
local crouch_release_frame = nil

local _arm_crouch_press = function()
	if crouch_latch_on or crouch_press_pending then
		return
	end

	local hold_mode = _read_game_setting and _read_game_setting("hold_to_crouch")

	if hold_mode == false then
		crouch_press_pending = true
		crouch_press_frame = nil
	end
end

local _reset_crouch_press = function()
	crouch_press_pending = false
	crouch_press_frame = nil
	crouch_latch_on = false
	crouch_release_pending = false
	crouch_release_frame = nil
end

-- True once the crouch has been forced for the current queue.
local slide_injected = false

-- Stamped by the sliding state's exit hook, the moment the chain window
-- counts from.
local slide_exited_at = nil

local _queue_slide = function(unit)
	if not class_enabled or not (_slide_active() or slide_once) then
		-- Naming the refused gate is what a slide debug run needs when no
		-- queue message ever appears.
		_say(debug_slide, string.format("slide queue skipped: %s", class_enabled and "slide features off" or "class disabled"), true)

		return
	end

	local now = _now()

	if not now then
		return
	end

	-- Some sprints skip the ramp. hook_safe runs after the original so the
	-- component is already up to date.
	local ramp = 0
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local sprint_component = unit_data and unit_data:read_component("sprint_character_state")

	if sprint_component and sprint_component.use_sprint_start_slowdown then
		ramp = SPRINT_RAMP_DURATION
	end

	-- A sprint resumed straight out of a slide already carries speed, so it
	-- gets its own delay rather than the one tuned for setting off cold.
	local chained = slide_exited_at ~= nil and now - slide_exited_at < CHAIN_WINDOW

	-- Once per sprint stands alone: one slide per sprint the player started,
	-- a sprint resumed straight out of a slide being the same sprint. While
	-- the keybinds or Always have sliding on, their repeating chain wins.
	if chained and not _slide_active() then
		_say(debug_slide, "chained slide skipped, once per sprint", true)

		return
	end

	local extra = chained and slide_chain_delay or slide_first_delay

	-- The ramp counts from sprint entry, not from the queue, so a queue made
	-- mid sprint waits only the part of it still unserved, usually none.
	local ramp_left = math.max(0, (sprint_entered_at or now) + ramp - now)

	slide_queued_at = now + ramp_left + extra
	slide_injected = false

	_say(debug_slide, string.format("%s slide queued, ramp left %.2fs plus %.2fs, firing in %.2fs",
		chained and "chained" or "first", ramp_left, extra, slide_queued_at - now), true)
end

-- Switching slide on partway through a sprint queues immediately, so a pause
-- through the keybinds resumes sliding without needing a fresh sprint.
local _queue_slide_if_sprinting = function()
	if not is_sprinting or slide_queued_at then
		return
	end

	local unit = _get_player_unit()

	if unit then
		_queue_slide(unit)
	end
end

local _clear_queued_slide = function()
	if slide_queued_at then
		_say(debug_slide, "sprint ended, slide queue cleared", true)
	end

	slide_queued_at = nil
end

local _filter_crouch_input = function(action_name, val, now)
	-- The press edges for toggle-crouch mode: a real player press cancels
	-- every plan and wins outright; otherwise the release edge goes first,
	-- since it is also the safety that stands the player back up.
	if action_name == CROUCH_PRESS_INPUT then
		if val and val ~= 0 then
			_reset_crouch_press()

			return val
		end

		if now then
			if crouch_release_pending then
				if not crouch_release_frame then
					crouch_release_frame = now

					_say(debug_slide, "crouch release press injected", true)
				end

				if now == crouch_release_frame then
					return true
				end

				crouch_release_pending = false
				crouch_release_frame = nil
				crouch_latch_on = false
			elseif crouch_press_pending then
				if not crouch_press_frame then
					crouch_press_frame = now

					_say(debug_slide, "crouch press injected, toggle crouch", true)
				end

				if now == crouch_press_frame then
					return true
				end

				crouch_press_pending = false
				crouch_press_frame = nil
				crouch_latch_on = true
			end
		end

		return val
	end

	if action_name ~= CROUCH_HELD_INPUT and action_name ~= CROUCH_HOLD_MODE_INPUT then
		return val
	end

	-- Dodge and Slide forces the crouch immediately, skipping the queue;
	-- cleared by the sliding state's enter or its own expiry.
	if DODGE.slide_until then
		if now and now < DODGE.slide_until then
			if not DODGE.slide_said then
				DODGE.slide_said = true

				_arm_crouch_press()

				_say(debug_dodge, "crouch forced for the dodge slide", true)
			end

			return true
		end

		DODGE.slide_until = nil

		if crouch_latch_on then
			crouch_release_pending = true
			crouch_release_frame = nil
		end
	end

	if (not _slide_active() and not slide_once) or not slide_queued_at then
		return val
	end

	if not now then
		return val
	end

	if now < slide_queued_at then
		return val
	end

	if now - slide_queued_at > INJECT_TIMEOUT then
		slide_queued_at = nil
		slide_injected = false
		crouch_press_pending = false
		crouch_press_frame = nil

		if crouch_latch_on then
			crouch_release_pending = true
			crouch_release_frame = nil
		end

		local hold_mode = _read_game_setting and _read_game_setting("hold_to_crouch")

		_say(debug_slide, string.format("slide never reached speed, crouch released, game crouch mode %s",
			hold_mode == false and "toggle" or hold_mode == true and "hold" or "unknown"), true)

		return val
	end

	if not slide_injected then
		slide_injected = true

		_arm_crouch_press()

		_say(debug_slide, "crouch forced, slide starting", true)
	end

	return true
end

-- Applies the side effects of an effective slide state change: a fresh
-- queue when it turns on, a cleared queue when it turns off, and the
-- notification echo. Callers capture the effective state before their
-- write and pass it in, so a write that changes nothing stays silent.
local _after_slide_change = function(was_active)
	local active = _slide_active()

	if active == was_active then
		return
	end

	if active then
		_queue_slide_if_sprinting()
	elseif not slide_once then
		slide_queued_at = nil
	end

	_say(debug_notify, active and "notify_slide_on" or "notify_slide_off")
end

local _set_slide_enabled = function(state)
	local was_active = _slide_active()

	slide_enabled = state

	_after_slide_change(was_active)
end

mod._kb_toggle_slide = function(held)
	_ensure_class_synced()
	_set_slide_enabled(not slide_enabled)
end

-- The held bind is an absolute down flag, never an inversion of stored
-- state, so a release lost to a menu or a focus change cannot corrupt
-- the baseline; the next press and release resynchronize it.
mod._kb_hold_slide = function(held)
	_ensure_class_synced()

	local was_active = _slide_active()

	slide_hold_down = held and true or false

	_say(debug_slide, string.format("slide hold bind %s", slide_hold_down and "down" or "up"), true)

	_after_slide_change(was_active)
end

-- Dodge
-- --------------------------------------------------------------------------
-- The dodge action is never read during a sprint, so the press is polled
-- once per jump read; a diagonal press drops and restores the sprint, a
-- forward press becomes a slide. Missions only.

local DODGE_INPUT = "dodge"
local JUMP_INPUT = "jump"

-- The game's own diagonal test: the sideways share of the normalized move
-- above 0.707. At or below it counts as forward, so every press mid sprint
-- lands on one side or the other with no dead band between them.
local DODGE_DIAGONAL_MIN = 0.707
local DODGE_MOVE_EPSILON = 0.1

-- Drop covers the exit and the walking frame that takes the dodge; replay
-- holds the press alive into it; resume counts as sprint intent after.
local DODGE_DROP_WINDOW = 0.25
local DODGE_RESUME_WINDOW = 1.5

-- How long the crouch is forced waiting for the slide, cleared by the
-- sliding state's enter; the same ceiling the slide queue uses for a sprint
-- that never reaches slide speed.
local DODGE_SLIDE_TIMEOUT = 0.5

local _sideways_share = function()
	local x, y = _move_axis()

	if type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end

	local length = math.sqrt(x * x + y * y)

	if length < DODGE_MOVE_EPSILON then
		return nil
	end

	return math.abs(x) / length
end

local _dodge_features_armed = function()
	return (DODGE.keep_sprint or DODGE.slide_on) and class_enabled and is_sprinting and not in_ground_state
end

local _on_dodge_press = function(now)
	if not now then
		return
	end

	local share = _sideways_share()

	if not share then
		return
	end

	if share > DODGE_DIAGONAL_MIN then
		if DODGE.keep_sprint then
			DODGE.drop_until = now + DODGE_DROP_WINDOW
			DODGE.replay_until = now + DODGE_DROP_WINDOW
			DODGE.resume_until = now + DODGE_RESUME_WINDOW
			DODGE.off_press_pending = true
			DODGE.off_press_frame = nil

			_say(debug_dodge, string.format("diagonal dodge press, sideways %.2f, sprint dropped", share), true)
		end
	elseif DODGE.slide_on then
		DODGE.slide_until = now + DODGE_SLIDE_TIMEOUT
		DODGE.slide_said = false
		DODGE.slide_resume = true

		_say(debug_dodge, string.format("forward dodge press, sideways %.2f, slide forced", share), true)
	end
end

-- The walking route: the engine grants a slide for half a second after a
-- dodge, exactly as it does after a sprint, so a second press inside the
-- double window forces the crouch and lets the dodge itself run. The
-- engine still requires speed along the look direction, so a backward or
-- sideways dodge carries none and no slide follows.


local _filter_dodge_input = function(action_name, val, now, service, original)
	if action_name == DODGE_INPUT then
		-- Suppressed during a forced dodge slide, replayed true through
		-- the drop so the walking frame still sees its press.
		if DODGE.slide_until and now and now < DODGE.slide_until then
			return false
		end

		if DODGE.replay_until then
			if now and now < DODGE.replay_until then
				return true
			end

			DODGE.replay_until = nil
		end

		return val
	end

	if action_name ~= JUMP_INPUT then
		return val
	end

	-- Jump reads carry the poll; it goes through the unhooked original so
	-- it cannot re-enter this filter, and only the rising edge triggers.
	if _dodge_features_armed() and service and original then
		local ok, raw = pcall(original, service, DODGE_INPUT)
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

	if DODGE.slide_until and now and now < DODGE.slide_until then
		return false
	end

	-- While sprinting clearly diagonally the jump read is answered false, so
	-- a press shared with the jump key becomes the dodge rather than a
	-- sprint jump. Straight sprints keep jumps and vaults untouched.
	if DODGE.keep_sprint and class_enabled and is_sprinting and not in_ground_state then
		local share = _sideways_share()

		if share and share > DODGE_DIAGONAL_MIN then
			return false
		end
	end

	return val
end

-- Vault
-- --------------------------------------------------------------------------
-- Answers jump (ground) and held jump (air) true only when the game's own
-- can_enter, fed the captured extensions, grants a vault this frame.

local JUMP_HELD_INPUT = "jump_held"
local DEVICE_SLOT = "slot_device"

-- Straight-approach gate: clean forward only, unknown reads fail toward
-- fewer vaults, and the bounds stay clear of the dodge diagonal at 0.707.
local VAULT_FORWARD_MIN = 0.75
local VAULT_STRAFE_MAX = 0.35

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

-- Landing check ray geometry, meters: hang probes just past the lip,
-- ground probe a stride beyond, down to the fall limit plus margin.
local VAULT_HANG_PROBE_FORWARD = 0.3
local VAULT_HANG_PROBE_UP = 0.5
local VAULT_HANG_PROBE_LENGTH = 2.0
local VAULT_GROUND_PROBE_FORWARD = 1.0
local VAULT_GROUND_PROBE_UP = 0.5
local VAULT_GROUND_PROBE_MARGIN = 2.0

-- The physics world, fetched once per session the way the engine hands it
-- out and dropped at loading screens.
local vault_physics_world = nil

local _vault_physics = function()
	if vault_physics_world then
		return vault_physics_world
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

	vault_physics_world = physics_world

	return vault_physics_world
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

-- One downward probe on the hang-ledge filter; a hit means a hangable
-- railing at that point of the lip.
local _hang_probe = function(physics, point, forward, up, down)
	local from = point + forward * VAULT_HANG_PROBE_FORWARD + up * VAULT_HANG_PROBE_UP

	return pcall(PhysicsWorld.raycast, physics, from, down, VAULT_HANG_PROBE_LENGTH, "closest", "collision_filter", "filter_hang_ledge_collision")
end

-- The floor is in metres of ledge height above the player, zero turning
-- the rule off. Both the ground vault and the airborne grab run it.
-- Height alone cannot separate a stair step from a low obstacle, so a low
-- ledge is allowed only when none has been seen for chain_window; every
-- sighting refreshes that window, refused ones included. An unreadable
-- height fails toward fewer vaults.
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

-- Reports what the ledge finder is offering when a vault is refused: the
-- chosen ledge, then every candidate as height and flat distance in
-- metres, throttled alongside the skip message. Costs nothing while the
-- vault channel is off.
local _say_ledge_candidates = function(ledge)
	if not debug_vault or not VAULT.ext then
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

	-- Hangable railings carry their own collision; three probes across the
	-- lip, allocation-free per call.
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

	-- The landing must have ground within the fall limit, measured from
	-- lip level down.
	local probe_from = mid + forward * VAULT_GROUND_PROBE_FORWARD + up * VAULT_GROUND_PROBE_UP
	local probe_length = VAULT.fall_limit + VAULT_GROUND_PROBE_UP + VAULT_GROUND_PROBE_MARGIN
	local ok, hit, _, hit_distance = pcall(PhysicsWorld.raycast, physics, probe_from, down, probe_length, "closest", "collision_filter", "filter_player_mover")

	if not ok then
		return false, "ground probe unreadable"
	end

	if not hit then
		return false, "no ground below the landing"
	end

	local drop = (hit_distance or probe_length) - VAULT_GROUND_PROBE_UP

	if drop > VAULT.fall_limit then
		return false, string.format("%.1fm drop beyond the %dm limit", drop, VAULT.fall_limit)
	end

	return true
end

-- True between the enter and exit of the falling and jumping states, fed
-- by their hooks; the mantle only answers while genuinely airborne.
local in_air_state = false

-- The five fields every vaulting-capable state carries. Captured whole or
-- not at all, so a partial state can never leave a mixed set behind.
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
	if action_name ~= JUMP_INPUT and action_name ~= JUMP_HELD_INPUT then
		return val
	end

	if val and val ~= 0 then
		return val
	end

	-- The dodge windows own the jump input while they run; a vault answer
	-- during a forced slide or a sprint drop would fight them.
	if not class_enabled or in_hub or VAULT.wielded_slot == DEVICE_SLOT or DODGE.slide_until or DODGE.drop_until then
		return val
	end

	if action_name == JUMP_INPUT then
		local wanted = (is_sprinting and VAULT.sprinting) or (in_ground_state and not is_sprinting and VAULT.walking)

		if not wanted then
			return val
		end

		local x, y = _move_axis()

		if type(x) ~= "number" or type(y) ~= "number" or y < VAULT_FORWARD_MIN or math.abs(x) > VAULT_STRAFE_MAX then
			VAULT.said = false

			return val
		end

		local possible, ledge = _vault_possible()

		-- Stair steps read as legitimate low ledges, so anything under the
		-- height floor is left to normal movement rather than vaulted.
		if possible and not _ledge_tall_enough(ledge, now) then
			possible = false

			-- Ledges flicker in and out of reach while climbing and
			-- reset the one-shot flag, so a time gap governs this pair
			-- as well.
			if not VAULT.block_said and (not VAULT.block_said_at or not now or now - VAULT.block_said_at > VAULT.block_say_gap) then
				VAULT.block_said = true
				VAULT.block_said_at = now

				_say(debug_vault, "vault skipped: low ledge, and low ledges keep arriving", true)

				_say_ledge_candidates(ledge)
			end
		end

		if possible then
			local safe, reason = _vault_landing_safe(ledge)

			if safe then
				if not VAULT.said then
					VAULT.said = true

					_say(debug_vault, "ledge ahead, jump answered for the vault", true)
				end

				return true
			end

			if not VAULT.block_said then
				VAULT.block_said = true

				_say(debug_vault, string.format("vault blocked: %s", reason or "unsafe landing"), true)
			end

			return val
		end

		VAULT.said = false
		VAULT.block_said = false

		return val
	end

	if not VAULT.mantle or not in_air_state then
		return val
	end

	local grab_possible, grab_ledge = _vault_possible()

	if grab_possible and _ledge_tall_enough(grab_ledge, now) then
		if not VAULT.said then
			VAULT.said = true

			_say(debug_vault, "ledge in reach, held jump answered for the grab", true)
		end

		return true
	end

	VAULT.said = false

	return val
end

-- Jump block
-- --------------------------------------------------------------------------
-- Answers the jump press false so a shared jump and dodge key can only
-- dodge. Jump and dodge are separate actions sharing a default key, space
-- on keyboard and A on controller, so the dodge answer is untouched.
-- Placed before the vault filter, which answers the jump on its own
-- authority. The held jump is never touched.

local _filter_jump_block_input = function(action_name, val, now)
	if JUMP.mode == "off" or not class_enabled or action_name ~= JUMP_INPUT then
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

-- Swing
-- --------------------------------------------------------------------------
-- Suppresses attack inputs briefly after the swing key press so an
-- injected swing is ignored, whether it comes from an attack-spam mod or
-- from the optional attacks module, which runs earlier in the chain.
-- Manual attacks inside the window go with it, injected and real being
-- indistinguishable.

local FORWARD_EPSILON = 0.1
local MOVING_SPEED_EPSILON = 1

-- Attacks only. The action_two family carries block and aim, which must keep
-- reading through untouched.
local BLOCKED_ATTACK_ACTIONS = {
	action_one_pressed = true,
	action_one_hold = true,
	weapon_extra_pressed = true,
	weapon_extra_hold = true,
}

local swing_grace_period = (mod:get("swing_grace_ms") or 85) / 1000
local swing_skip_when_still = mod:get("swing_skip_when_still") and true or false
local swing_skip_when_sprinting = mod:get("swing_skip_when_sprinting") and true or false

local swing_block_until = nil
local swing_movement_unreadable = false
local swing_suppressed_count = 0

-- Records when the key went down and the longest hold so far short enough to
-- count as a tap, so the grace period can be set from measured reflexes.
local swing_pressed_at = nil
local swing_longest_tap = 0

-- Holds longer than this are the player swinging on purpose, not a tap that
-- needs catching, so they are left out of the running maximum.
local TAP_MEASURE_CEILING = 0.4
local swing_seen_actions = {}
local swing_seen_reported = false

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

	return Vector3.length(Vector3.flat(velocity)) > MOVING_SPEED_EPSILON
end

-- Returns the reason alongside the decision, so a press that declined reads
-- differently in the log from a press that never arrived.
local _should_delay_swing = function()
	if swing_skip_when_sprinting and is_sprinting then
		return false, "already sprinting"
	end

	if not swing_skip_when_still then
		return true, "delay always"
	end

	local forward = _forward_from_input()

	if forward ~= nil then
		if forward > FORWARD_EPSILON then
			return true, string.format("moving forward %.2f", forward)
		end

		return false, string.format("not moving forward %.2f", forward)
	end

	local moving = _moving_from_velocity()

	if moving ~= nil then
		return moving, "velocity fallback, moving = " .. tostring(moving)
	end

	if not swing_movement_unreadable then
		swing_movement_unreadable = true

		mod:warning("Movement could not be read from either source; every press will be delayed.")
	end

	return true, "movement unreadable"
end

local _filter_attack_input = function(action_name, val, now)
	if not swing_block_until then
		return val
	end

	if debug_swing and val == true and not BLOCKED_ATTACK_ACTIONS[action_name] then
		swing_seen_actions[action_name] = true
	end

	if not BLOCKED_ATTACK_ACTIONS[action_name] then
		return val
	end

	if not now or now >= swing_block_until then
		swing_block_until = nil

		if debug_swing then
			_say(debug_swing, string.format("window closed, %d attack reads suppressed", swing_suppressed_count), true)

			-- Zero across a whole window means nothing was injected into it.
			-- The same cannot be judged per read, since only one blocked
			-- action is ever in use and the rest read false throughout.
			if swing_suppressed_count == 0 then
				_say(debug_swing, "nothing was suppressed, so no attack input reached the window", true)
			end

			if not swing_seen_reported then
				swing_seen_reported = true

				local names = {}

				for name in pairs(swing_seen_actions) do
					names[#names + 1] = name
				end

				_say(debug_swing, "other actions true during window: " .. (next(names) and table.concat(names, ", ") or "none"), true)
			end
		end

		swing_suppressed_count = 0

		return val
	end

	swing_suppressed_count = swing_suppressed_count + 1

	return false
end

mod._kb_hold_swing = function(held)
	_ensure_class_synced()

	if not held then
		if debug_swing and swing_pressed_at then
			local now = _now()

			if now then
				local ms = (now - swing_pressed_at) * 1000

				if ms < TAP_MEASURE_CEILING * 1000 then
					if ms > swing_longest_tap then
						swing_longest_tap = ms
					end

					_say(debug_swing, string.format("held %.0fms, longest tap so far %.0fms, suggested grace %.0fms",
						ms, swing_longest_tap, swing_longest_tap + 50), true)
				else
					_say(debug_swing, string.format("held %.0fms, too long to count as a tap", ms), true)
				end
			end
		end

		swing_pressed_at = nil

		-- The window is left to expire on its own deadline. Clearing it here
		-- can run a frame ahead of the other mod's release handling, and one
		-- unsuppressed frame is enough for an injected press to land.
		return
	end

	local now = _now()

	swing_pressed_at = now
	swing_block_until = nil

	local delay, reason = _should_delay_swing()

	_say(debug_swing, string.format("block press, class %s, delay %s (%s)", tostring(class_enabled), tostring(delay), reason), true)

	if not class_enabled or not delay then
		return
	end

	if not now then
		_say(debug_swing, "no clock, window cannot open", true)

		return
	end

	swing_block_until = now + swing_grace_period

	_say(debug_swing, string.format("window open for %.0fms", swing_grace_period * 1000), true)
end

-- Modifier keybind assist
-- --------------------------------------------------------------------------
-- Covers held binds DMF cannot drive, riding the input reads once per
-- clock frame and calling the same handlers DMF would.

local MODIFIER_ASSIST_TARGETS = {
	{ setting = "sprint_hold_keybind", handler = "_kb_hold_sprint" },
	{ setting = "slide_hold_keybind", handler = "_kb_hold_slide" },
	{ setting = "reload_swap_keybind", handler = "_kb_hold_reload_swap" },
	{ setting = "swing_keybind", handler = "_kb_hold_swing" },
}

-- ONLY generic-name binds ("shift"), which DMF cannot resolve; specific
-- names are DMF's alone, and covering both puts two inverters on one key.
-- Indices are the raw buttons DMF itself reads.
local MODIFIER_KEY_RAW_INDICES = {
	["shift"] = { 160, 161 },
	["ctrl"] = { 162, 163 },
	["alt"] = { 164, 165 },
}

local modifier_assists = nil
local modifier_last_frame = nil

-- Renders any stored bind value verbatim for the debug channel, so the
-- storage format DMF actually uses is observed rather than assumed.
local _describe_bind

_describe_bind = function(value)
	if type(value) ~= "table" then
		return string.format("%s (%s)", tostring(value), type(value))
	end

	local parts = {}

	for key, entry in pairs(value) do
		parts[#parts + 1] = string.format("%s=%s", tostring(key), type(entry) == "table" and _describe_bind and "(table)" or tostring(entry))
	end

	table.sort(parts)

	return "{" .. table.concat(parts, ", ") .. "}"
end

local _rebuild_modifier_assists = function()
	modifier_assists = {}

	for i = 1, #MODIFIER_ASSIST_TARGETS do
		local target = MODIFIER_ASSIST_TARGETS[i]
		local keys = mod:get(target.setting)
		local armed = false

		local raw = type(keys) == "table" and #keys == 1 and MODIFIER_KEY_RAW_INDICES[keys[1]]

		if raw then
			modifier_assists[#modifier_assists + 1] = { indices = raw, handler = target.handler, down = false, setting = target.setting }
			armed = true

			_say(debug_sprint, string.format("%s assist watching buttons %s", target.setting, table.concat(raw, ", ")), true)
		end

		_say(debug_sprint, string.format("%s stored as %s, modifier assist %s", target.setting, _describe_bind(keys), armed and "armed" or "not armed"), true)
	end
end

local _update_modifier_assists = function(now)
	if not now or now == modifier_last_frame then
		return
	end

	modifier_last_frame = now

	for i = 1, #modifier_assists do
		local assist = modifier_assists[i]
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

			_say(debug_sprint, string.format("%s key %s", assist.setting or "assist", down and "down" or "up"), true)

			local handler = mod[assist.handler]

			if handler then
				handler(down)
			end
		end
	end
end

-- Hooks
-- --------------------------------------------------------------------------
-- Guards and dispatch targets live on a global table a reload runs past;
-- bodies resolve their target at run time, each hook carries its own
-- guard, and CLASS values are passed, never indexed.

-- Graceful Swinging module (optional file)
-- --------------------------------------------------------------------------
-- GracefulSwinging.lua in this mod's scripts folder adds the attack keybinds;
-- with the file absent nothing loads and no options appear. The presence
-- check is a raw quiet file open, the same primitive DMF's own loader
-- uses before it prints its missing file error, so an absent module
-- stays silent. The data file runs the identical check for the widgets.

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

	if module and module.api == 1 then
		ATTACKS = module

		ATTACKS.init({
			now = _now,
			say = _say,
			debug = function()
				return debug_attacks
			end,
			notify = function()
				return debug_notify
			end,
			melee_wielded = function()
				return VAULT.wielded_slot == "slot_primary"
			end,
			class_enabled = function()
				return class_enabled
			end,
			in_hub = function()
				return in_hub
			end,
			current_action = function()
				local _, action = _reload_components()

				return action and action.current_action_name or nil
			end,
		})

		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_light_hold_keybind", handler = "_kb_attacks_light_hold" }
		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_heavy_hold_keybind", handler = "_kb_attacks_heavy_hold" }
		MODIFIER_ASSIST_TARGETS[#MODIFIER_ASSIST_TARGETS + 1] = { setting = "attacks_invert_keybind", handler = "_kb_attacks_invert" }
	elseif module then
		mod:warning("GracefulSwinging.lua was built for a different version of Grace's module interface and stays inactive; download the current GracefulSwinging to match this build")
	elseif f then
		mod:warning("GracefulSwinging.lua was found but did not register and stays inactive")
	end
end

local HOOK_STATE = rawget(_G, "__grace_hook_state")

if not HOOK_STATE then
	HOOK_STATE = {}

	rawset(_G, "__grace_hook_state", HOOK_STATE)
end


HOOK_STATE.on_slide_state_changed = function(unit, sliding)
	if unit ~= _get_player_unit() then
		return
	end

	in_slide_state = sliding
	slide_press_said = false

	-- The dodge slide has landed once the sliding state is up; releasing the
	-- forced crouch here keeps it from outliving a short slide.
	if sliding and DODGE.slide_until then
		DODGE.slide_until = nil

		_say(debug_dodge, "dodge slide confirmed", true)
	end

	-- The slide arrived, so any still-waiting crouch press is stood down;
	-- the latch itself stays until the slide ends and the release press
	-- stands the player back up.
	if sliding then
		crouch_press_pending = false
		crouch_press_frame = nil
	elseif crouch_latch_on then
		crouch_release_pending = true
		crouch_release_frame = nil
	end

	if not sliding then
		sprint_press_pending = false
		sprint_press_frame = nil

		local now = _now()

		slide_exited_at = now
		slide_press_carry_until = now and now + SLIDE_PRESS_CARRY or nil

		-- A forced dodge slide gets the dodge's own resume treatment,
		-- covering the toggle-mode manual sprinter.
		if DODGE.slide_resume then
			DODGE.slide_resume = false
			DODGE.resume_until = now and now + DODGE_RESUME_WINDOW or nil

			_say(debug_dodge, "dodge slide ended, sprint resuming", true)
		end
	end
end

HOOK_STATE.on_ground_state_changed = function(unit, grounded, state)
	if unit ~= _get_player_unit() then
		return
	end

	in_ground_state = grounded
	sprint_intent_since = nil
	sprint_press_pending = false
	sprint_press_frame = nil
	press_block_said = false

	if grounded then
		_capture_vault_ext(state)
	end
end

HOOK_STATE.on_sprint_enter = function(unit, state)
	if unit ~= _get_player_unit() then
		return
	end

	_capture_vault_ext(state)

	is_sprinting = true
	sprint_entered_at = _now()
	DODGE.resume_until = nil

	_reset_sprint_press()

	_say(debug_sprint, "sprint state confirmed", true)

	-- Earliest point the class is reliably known, so sync here.
	_ensure_class_synced()

	_queue_slide(unit)
end

HOOK_STATE.on_sprint_exit = function(unit, next_state)
	if unit ~= _get_player_unit() then
		return
	end

	is_sprinting = false
	sprint_entered_at = nil

	-- A dodge slide exits the sprint into the sliding state, which clears
	-- the window itself; any other exit means the slide is not coming, and
	-- holding the crouch on would leave the player crouched for nothing.
	if next_state ~= "sliding" then
		DODGE.slide_until = nil
		DODGE.slide_resume = false

		if crouch_latch_on and not crouch_release_pending then
			crouch_release_pending = true
			crouch_release_frame = nil
		end
	end

	_clear_queued_slide()
end

HOOK_STATE.on_dodge_state_entered = function(unit)
	if unit ~= _get_player_unit() then
		return
	end

	-- The dodge landed, so the replay stops before it can chain a second
	-- one and the drop ends early, letting the resume window start work.
	DODGE.replay_until = nil
	DODGE.drop_until = nil

	_say(debug_dodge, "dodge confirmed, sprint resuming", true)
end

HOOK_STATE.on_air_state_changed = function(unit, inside, state)
	if unit ~= _get_player_unit() then
		return
	end

	in_air_state = inside

	if inside then
		_capture_vault_ext(state)
	end
end

-- The wielded slot, cached from the weapon extension's own bookkeeping so
-- the vault can stand down while a deployable is in hand. A nil unit on
-- the extension is accepted rather than guessed about.
HOOK_STATE.on_wielded_slot = function(slot, unit)
	if unit and unit ~= _get_player_unit() then
		return
	end

	VAULT.wielded_slot = slot
end

HOOK_STATE.on_weapon_action_started = function(id, action_name, action_settings, action_params, t)
	if not ATTACKS or id ~= "weapon_action" then
		return
	end

	if not action_params or action_params.player_unit ~= _get_player_unit() then
		return
	end

	ATTACKS.on_action_started(action_name, action_settings, action_params.weapon, t)
end

HOOK_STATE.on_reload_action = function(unit, started)
	if unit ~= _get_player_unit() then
		return
	end

	RELOAD.active = started

	-- The component already names the reload when the start hook runs, so
	-- the name is captured here for the cancellation check. A failed read
	-- leaves it nil, which disables the check and keeps the plain latch.
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

-- A queued save is the moment to re-read the mirror; the bridge's own
-- writes re-enter here once and no-op.
HOOK_STATE.on_save_queued = function()
	-- The class sync rides the one menu-adjacent signal proven to fire;
	-- its own writes re-enter once and no-op.
	_ensure_class_synced()
	_sync_vanilla_settings()
end

-- The chain fetches the clock once and threads it down; no filter reads
-- the clock itself, and a nil clock passes through with every filter's
-- original nil handling intact.
HOOK_STATE.filter_input = function(action_name, val, site, service, original)
	local now = _now()

	if now and (not class_check_at or now - class_check_at >= 1) then
		class_check_at = now

		_ensure_class_synced()
	end

	if modifier_assists and #modifier_assists > 0 then
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
		val = ATTACKS.filter(action_name, val, now)
	end

	val = _filter_attack_input(action_name, val, now)

	return val
end


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

if ATTACKS and not HOOK_STATE.attacks_action_hooked then
	HOOK_STATE.attacks_action_hooked = true

	mod:hook_safe(CLASS.ActionHandler, "start_action", function(self, id, action_objects, action_name, action_params, action_settings, used_input, t)
		local handler = HOOK_STATE.on_weapon_action_started

		if handler then
			handler(id, action_name, action_settings, action_params, t)
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

-- Both hooks are needed (simulated actions bypass _get) and the filters
-- absorb double passes by being idempotent. Installed from
-- on_all_mods_loaded because the last hook registered wins.
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

-- Framework callbacks
-- --------------------------------------------------------------------------

_refresh_cache = function(id)
	if id == "debug_notify" then
		debug_notify = mod:get(id) and true or false
	elseif id == "debug_sprint" then
		debug_sprint = mod:get(id) and true or false
	elseif id == "debug_slide" then
		debug_slide = mod:get(id) and true or false
	elseif id == "debug_swing" then
		debug_swing = mod:get(id) and true or false
		swing_longest_tap = 0
	elseif id == "debug_dodge" then
		debug_dodge = mod:get(id) and true or false
	elseif id == "debug_vault" then
		debug_vault = mod:get(id) and true or false
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
		debug_class = mod:get(id) and true or false
	elseif id == "debug_attacks" then
		debug_attacks = mod:get(id) and true or false
	elseif id == "dodge_keep_sprint" then
		DODGE.keep_sprint = mod:get(id) and true or false

		if not DODGE.keep_sprint then
			DODGE.drop_until = nil
			DODGE.resume_until = nil
			DODGE.replay_until = nil
			DODGE.off_press_pending = false
			DODGE.off_press_frame = nil
		end
	elseif id == "dodge_slide" then
		DODGE.slide_on = mod:get(id) and true or false

		if not DODGE.slide_on then
			DODGE.slide_until = nil
			DODGE.slide_resume = false
		end
	elseif id == "sprint_enabled" then
		-- A settings write is authoritative: any held-bind state is
		-- dropped so the checkbox always means exactly what it says.
		sprint_hold_down = false
		sprint_enabled = mod:get(id) and true or false
		sprint_forcing = false
	elseif id == "sprint_reload_wait" then
		RELOAD.wait = mod:get(id) and true or false
	elseif id == "jump_block" then
		JUMP.mode = mod:get(id) or "off"

		if JUMP.mode ~= "dodges" then
			JUMP.dodge_until = nil
		end
	elseif id == "sprint_fire_wait" then
		FIRE.wait = mod:get(id) and true or false
	elseif id == "sprint_hold_keybind" or id == "slide_hold_keybind" or id == "swing_keybind" then
		if id == "slide_hold_keybind" then
			slide_hold_down = false
		end

		_rebuild_modifier_assists()
	elseif id == "sprint_perseverance" then
		sprint_perseverance = mod:get(id) and true or false
	elseif id == "slide_extra_delay" then
		slide_first_delay = mod:get(id) or 0
	elseif id == "slide_chain_delay" then
		slide_chain_delay = mod:get(id) or 0
	elseif id == "slide_once_per_sprint" then
		slide_once = mod:get(id) and true or false

		if slide_once then
			_queue_slide_if_sprinting()
		elseif not _slide_active() then
			slide_queued_at = nil
		end
	elseif id == "slide_always_on" then
		-- A settings write is authoritative: any held-bind state is
		-- dropped so the checkbox always means exactly what it says.
		slide_hold_down = false
		slide_enabled = mod:get(id) and true or false

		if slide_enabled then
			_queue_slide_if_sprinting()
		elseif not slide_once then
			slide_queued_at = nil
		end
	elseif id == "swing_grace_ms" then
		swing_grace_period = (mod:get(id) or 85) / 1000
	elseif id == "swing_skip_when_still" then
		swing_skip_when_still = mod:get(id) and true or false
	elseif id == "swing_skip_when_sprinting" then
		swing_skip_when_sprinting = mod:get(id) and true or false
	end
end

mod.on_setting_changed = function(id)
	if applying then
		return
	end

	-- A mirrored checkbox writes straight through to the game's save, and
	-- with the per class opt-in the edit is recorded for the current class.
	local game_id = VANILLA_LOOKUP[id]

	if game_id then
		_write_game_setting(game_id, mod:get(id) and true or false)

		if per_class and per_class_vanilla then
			_record_edit(id)
		end

		return
	end

	-- The reset checkbox behaves as a button: ticked runs the wipe once
	-- and unticks itself through the applying guard.
	if id == "per_class_reset" then
		if mod:get(id) then
			_reset_per_class_memory()
			_apply(id, false)
		end

		return
	end

	if id == "per_class_vanilla" then
		per_class_vanilla = mod:get(id) and true or false

		if per_class_vanilla then
			for i = 1, #VANILLA_SETTINGS do
				local mod_id = VANILLA_SETTINGS[i].mod_id

				mod:set(_base_key(mod_id), mod:get(mod_id))
			end

			-- Stores from an earlier run with the switch on pick up where
			-- they left off, the same as the per class switch itself.
			if per_class and synced_class then
				_apply_class(synced_class)
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
		per_class = mod:get(id) and true or false

		if per_class then
			_capture_base()

			synced_class = nil

			_ensure_class_synced()
		else
			synced_class = nil

			-- Per class stores are left in place, so switching back on picks up
			-- where it left off.
			_restore_base()
		end

		return
	end

	if id:sub(1, 8) == "disable_" then
		synced_class = nil

		_ensure_class_synced()

		return
	end

	_refresh_cache(id)

	if per_class and PER_CLASS_LOOKUP[id] then
		_record_edit(id)
	end
end

mod.on_game_state_changed = function(status, state_name)
	is_sprinting = false
	sprint_entered_at = nil
	diag_counts = {}
	in_ground_state = false
	in_slide_state = false
	slide_press_said = false
	slide_press_carry_until = nil
	raw_sprint_held_at = nil
	sprint_intent_since = nil
	sprint_press_pending = false
	sprint_press_frame = nil
	sprint_next_press_at = nil
	slide_queued_at = nil
	slide_exited_at = nil
	swing_block_until = nil
	DODGE.drop_until = nil
	DODGE.resume_until = nil
	DODGE.replay_until = nil
	DODGE.slide_until = nil
	DODGE.slide_resume = false
	DODGE.off_press_pending = false
	DODGE.off_press_frame = nil
	DODGE.last_val = false
	in_hub = false
	hub_checked = false
	hub_component = nil
	hub_was_sprinting = false
	hub_said_at = nil
	sprint_hold_mode_known = false
	class_check_at = nil
	real_sprint_press_at = nil
	sprint_hold_down = false
	slide_hold_down = false
	RELOAD.active = false
	RELOAD.action_name = nil
	RELOAD.component = nil
	RELOAD.action_component = nil
	RELOAD.unit = nil
	RELOAD.was_waiting = false
	STATE_CHECK.frame = nil
	STATE_CHECK.component = nil
	STATE_CHECK.unit = nil
	FIRE.held_at = nil
	FIRE.was_waiting = false
	SWAP.key_down = false
	SWAP.withheld = false
	SWAP.pressed = false
	SWAP.press_until = nil
	sprint_press_by_hand = false
	in_air_state = false
	VAULT.ext = nil
	VAULT.wielded_slot = nil
	VAULT.said = false
	VAULT.block_said = false
	VAULT.block_said_at = nil
	VAULT.low_seen_at = nil
	vault_physics_world = nil

	if ATTACKS then
		ATTACKS.reset()
	end

	_reset_crouch_press()
	_ensure_class_synced()
	_sync_vanilla_settings()
end

mod.on_all_mods_loaded = function()
	_install_input_hooks()
	_rebuild_modifier_assists()

	-- One-time migration from the shipped enable_ switches to the inverted
	-- disable_ switches, so a class a 0.10 user turned off stays off. Old
	-- keys are left behind and ignored.
	for i = 1, #KNOWN_CLASSES do
		local class = KNOWN_CLASSES[i]

		if mod:get("enable_" .. class) == false and mod:get(_disable_key(class)) == nil then
			mod:set(_disable_key(class), true)
		end
	end

	-- Block Jump Presses became a three way setting. A stored true is the
	-- old always-block, so it is carried over rather than lost. The notice
	-- goes to chat as well as the notification.
	if mod:get("jump_block") == true then
		mod:set("jump_block", "always")
		JUMP.mode = "always"

		local moved = mod:localize("notify_jump_block_moved")

		mod:notify(moved)
		mod:echo(moved)
	end

	-- Swap To Melee After Reloads became a keybind. Anyone who had the
	-- checkbox on is told once and the stored value cleared, so the feature
	-- cannot go quiet without the player hearing why.
	if mod:get("reload_swap_melee") then
		mod:set("reload_swap_melee", false)

		local moved = mod:localize("notify_reload_swap_moved")

		mod:notify(moved)
		mod:echo(moved)
	end

	_sync_vanilla_settings()

	-- Settings added after per class was first switched on have no base
	-- snapshot yet; only the missing ones are captured.
	if per_class then
		for i = 1, #PER_CLASS_SETTINGS do
			local id = PER_CLASS_SETTINGS[i]

			if mod:get(_base_key(id)) == nil then
				mod:set(_base_key(id), mod:get(id))
			end
		end

		if per_class_vanilla then
			for i = 1, #VANILLA_SETTINGS do
				local id = VANILLA_SETTINGS[i].mod_id

				if mod:get(_base_key(id)) == nil then
					mod:set(_base_key(id), mod:get(id))
				end
			end
		end
	end
end

mod.on_disabled = function()
	swing_block_until = nil
	slide_queued_at = nil
	sprint_forcing = false
	DODGE.drop_until = nil
	DODGE.resume_until = nil
	DODGE.replay_until = nil
	DODGE.slide_until = nil
	DODGE.slide_resume = false
	DODGE.off_press_pending = false
	DODGE.off_press_frame = nil
	DODGE.last_val = false
	in_air_state = false
	VAULT.said = false
	_reset_crouch_press()
	_reset_sprint_press()
end
