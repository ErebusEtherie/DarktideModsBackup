-- bots.lua
--
-- Pilgrimage's bot management: slot progression, Better Bots soft-dependency,
-- and CCB conflict detection.
--
-- ===========================================================================
-- WHY THIS MODULE EXISTS
-- ===========================================================================
--
-- Fatshark's solo-play bot spawner defaults to 3 bot slots and picks profiles
-- with a bias that gives you three Veterans if the player character is a
-- Veteran too, which is one of the complaints Pilgrimage inherits from the
-- vanilla Solo Play experience.
--
-- Better Bots (hummat's mod) unlocks the AI hardcoded whitelist so bots
-- actually use abilities, grenades, revives, and it adds substantial
-- per-class heuristics on top. Pilgrimage needs that intelligence at the
-- higher War Plan tiers (Fanatic and Martyr are unplayable with dumb bots
-- against Havoc-stacked Damnation). We treat Better Bots as a REQUIRED
-- companion in Nexus copy but detect softly at runtime, so a user who
-- ignores the requirement gets a warning rather than a crash.
--
-- Custom Character Bots (mods/1096) is INCOMPATIBLE: it replaces the bot
-- profile selection with the player's saved characters, which conflicts
-- with Pilgrimage's own preset system (v0.21.1+). We soft-warn at boot;
-- the user can uninstall CCB if they want the preset system to work.
--
-- ===========================================================================
-- SLOT PROGRESSION (v0.28.52 early Warband revision)
-- ===========================================================================
--
--   Base                          1 slot (free Tier 1 Veteran baseline)
--   pilgrim_first_recruit         +1  (Novitiate clear)
--   pilgrim_second_recruit        +1  (three Living Tithe recruits owned)
--   pilgrim_sanctioned            +1  (Penitent clear)
--   pilgrim_full_muster earned    +1  (Fanatic+ clear, all 4 slots filled)
--   pilgrim_emperors_six earned   +1  (Martyr+ clear, 5 bots slotted)
--
-- Cap: 6. Legacy bot_slot_3 and bot_slot_4 purchases remain valid as
-- non-stacking alternatives to the matching new Penance gates.

local M = {}

local _mod
local _shared
local _hooks
local _penances
local _shop
-- v0.22.75: Preset dep for None-bound slot accounting (spawn_target).
local _preset
local _realms_bridge
-- Declared at the top, above every function that reads it.
local _debug_log

local BASE_SLOTS = 1
M.MAX_SLOTS = 6

-- Fatshark's PlayerUnitSpawnManager lives here. Standard Hooks.fanout target.
M.SPAWN_MANAGER_PATH = "scripts/managers/player/player_unit_spawn_manager"

-- v0.21.5: party HUD widening. The right-side team panels are governed by
-- one settings table (max_panels = 4 by default: local player + three
-- teammates). The handler's scenegraph loop generates positions for
-- player_1..player_{max_panels-1}, so bumping max_panels here also
-- creates the widget slots for the extra rows. We target 7 (local + 6
-- bots), matching M.MAX_SLOTS above so a fully-unlocked player has one
-- HUD row per warband member.
M.TEAM_PANEL_SETTINGS_PATH =
	"scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler_settings"

local SENTINEL = "__pilgrimage_bots_installed"
local HUD_SENTINEL = "__pilgrimage_hud_widen_installed"

-- ===========================================================================
-- Slot count
-- ===========================================================================
--
-- Called at spawn time by the hook below. Reads penance state and shop
-- unlocks live rather than caching, so a new penance earned mid-session
-- takes effect on the next mission load without a reboot.

function M.slot_count()
	local slots = BASE_SLOTS

	if _penances and _penances.is_earned then
		if _penances.is_earned("pilgrim_first_recruit") then
			slots = slots + 1
		end
		-- Legacy third/fourth-slot purchases remain valid alternatives to
		-- the new Penance gates, but cannot stack with them.
		if _penances.is_earned("pilgrim_second_recruit")
			or (_shop and _shop.is_unlocked and _shop.is_unlocked("bot_slot_3")) then
			slots = slots + 1
		end
		if _penances.is_earned("pilgrim_sanctioned")
			or (_shop and _shop.is_unlocked and _shop.is_unlocked("bot_slot_4")) then
			slots = slots + 1
		end
		if _penances.is_earned("pilgrim_full_muster") then
			slots = slots + 1
		end
		if _penances.is_earned("pilgrim_emperors_six") then
			slots = slots + 1
		end
	end

	if slots > M.MAX_SLOTS then slots = M.MAX_SLOTS end
	return slots
end

-- v0.22.75 (Session I): the number of bots to actually SPAWN. This is
-- slot_count() minus every active slot which is empty. This includes an
-- explicit "None" binding and legacy nil bindings left by the retired
-- "Default bot" option (locked decision 2026-08-09: an
-- unlocked slot is a capability, not a requirement). slot_count()
-- stays the capability number the Party tab renders rows for;
-- spawn_target() is what the spawn-manager hook below feeds the
-- engine. Preset.resolve_for_slot does the matching spawn-index ->
-- slot mapping on the add_bot side, so the Nth spawned bot always
-- lands on the Nth non-None slot.
function M.spawn_target()
	local slots = M.slot_count()
	local target = 0
	local bindings = _preset and _preset.slot_bindings
		and _preset.slot_bindings() or {}
	local none_id = _preset and _preset.NONE_BINDING or "none"
	for slot = 1, slots do
		local occupied = _realms_bridge
			and _realms_bridge.human_occupant_for_bot_slot
			and _realms_bridge.human_occupant_for_bot_slot(slot)
		local binding = bindings[slot]
		if not occupied and binding and binding ~= none_id then
			target = target + 1
		end
	end
	return target
end

local function _is_authority_host()
	if _shared and _shared.is_solo_host and _shared.is_solo_host() then return true end
	return _realms_bridge and _realms_bridge.is_host
		and _realms_bridge.is_host() or false
end

-- ===========================================================================
-- Mod presence checks
--
-- get_mod returns nil for a mod that is not loaded. We pcall in case DMF's
-- loader shape ever changes; a missing DMF or a load-order problem must
-- degrade to "assume mod is absent" rather than crash.
-- ===========================================================================

local function _mod_present(name)
	local ok, other = pcall(get_mod, name)
	return ok and type(other) == "table"
end

function M.better_bots_present()
	return _mod_present("BetterBots")
end

-- CCB's DMF name is what get_mod expects. If the actual registered name
-- differs (Nexus display names and DMF ids do not always match), this
-- check misses and no warning fires; the mod still runs correctly.
function M.custom_character_bots_present()
	return _mod_present("CustomCharacterBots")
end

-- v0.21.2: Vox Filter fixes bot voice attenuation-behind-the-player, a
-- Fatshark bug that gets worse in third person. Kaizen's own mod. Same
-- soft-detection treatment as Better Bots. DMF name guessed as
-- "VoxFilter"; if the real registered name differs, this misses and
-- the warning does not fire, which is harmless.
function M.vox_filter_present()
	return _mod_present("VoxFilter")
end

-- ===========================================================================
-- Hook: intercept bot-slot count
-- ===========================================================================
--
-- Fatshark's PlayerUnitSpawnManager._num_available_bot_slots is what the
-- solo-play flow calls to decide how many bots to spawn. Overriding it is
-- how TrueSoloQoL disables bots entirely, and it's the same knob we use
-- to add slots.
--
-- Solo-host only: in a coop lobby the count comes from the host anyway,
-- and we should never rewrite it out from under a real party.

-- v0.21.5: mutate HudElementTeamPanelHandlerSettings.max_panels in place
-- so the party HUD renders 1 local player + up to MAX_SLOTS bot rows.
--
-- The handler reads max_panels once at construction (self._max_panels =
-- HudElementTeamPanelHandlerSettings.max_panels), and the definitions
-- file's scenegraph loop runs `for i = 1, max_panels - 1`. Bumping the
-- number here in the settings table before either of those consumers
-- runs widens both, no additional widget hooking needed.
--
-- Idempotence guard so a hot-reload during dev does not re-bump on
-- top of an already-bumped value.
function M.install_hud_widen(settings_return)
	-- The settings file returns settings("HudElementTeamPanelHandlerSettings", tbl).
	-- Fatshark's settings() sometimes returns the table and sometimes returns
	-- nil while registering it globally. Cover both cases: prefer the
	-- passed-in value if it's a table, otherwise reach for the global.
	local target_table = settings_return
	if type(target_table) ~= "table" then
		target_table = rawget(_G, "HudElementTeamPanelHandlerSettings")
	end
	if type(target_table) ~= "table" then return end

	if _hooks and _hooks.claim(target_table, HUD_SENTINEL) then return end

	local target = 1 + M.MAX_SLOTS  -- local player + max bot slots
	if type(target_table.max_panels) == "number" and target_table.max_panels < target then
		target_table.max_panels = target
		_debug_log("bots", 0,
			"party HUD widened to " .. tostring(target) .. " panels", 0, "info")
	end
end

function M.install(PlayerUnitSpawnManager)
	if not PlayerUnitSpawnManager then return end
	if _hooks.claim(PlayerUnitSpawnManager, SENTINEL) then return end

	-- v0.21.1 fix: _num_available_bot_slots returns REMAINING slots (the
	-- delta between target and current bot count), not TOTAL. The caller
	-- invokes it in a loop and adds one bot per positive value returned.
	-- Fatshark's implementation reads:
	--
	--   desired_bot_count = clamp(max_players - num_ready_humans, 0, max_bots)
	--   return desired_bot_count - num_bots - queued
	--
	-- The v0.21.0 hook returned M.slot_count() as if it were a total,
	-- which either loops forever or gets capped by upstream game logic at
	-- Fatshark's default of 3 (Kaizen saw exactly 3 on a Fanatic run
	-- that should have opened 4).
	--
	-- The fix: compute the same diff, but against OUR target count
	-- instead of Fatshark's mode-level max_bots. Everything else about
	-- the caller's loop stays as it was.
	_mod:hook(PlayerUnitSpawnManager, "_num_available_bot_slots", function(orig, self, ...)
		if not _is_authority_host() then
			return orig(self, ...)
		end

		local Managers = rawget(_G, "Managers")
		local bot_manager = Managers and Managers.bot
		if not bot_manager or type(bot_manager.synchronizer_host) ~= "function" then
			return orig(self, ...)
		end

		local ok_host, host = pcall(bot_manager.synchronizer_host, bot_manager)
		if not ok_host or not host or type(host.num_bots) ~= "function" then
			return orig(self, ...)
		end

		local ok_count, num_bots = pcall(host.num_bots, host)
		if not ok_count then return orig(self, ...) end
		num_bots = tonumber(num_bots) or 0

		local queued = tonumber(self._queued_bots_n) or 0
		-- v0.22.75: spawn_target, not slot_count — None-bound slots
		-- spawn nothing.
		local target = M.spawn_target()
		local remaining = target - num_bots - queued
		-- Realms needs the negative value when a human joins so Darktide's
		-- _on_client_joined path knows exactly how many existing bots to despawn.
		-- The ordinary solo path retains its previous add-only behavior.
		if remaining < 0 and not (_realms_bridge and _realms_bridge.is_host
			and _realms_bridge.is_host()) then
			remaining = 0
		end
		return remaining
	end)

	-- Realms installs an instance-level bot-count function during init. Instance
	-- fields bypass the class method above, so after Realms finishes its original
	-- init we replace that one function with the same Pilgrimage target calculation.
	-- The hook is inert in ordinary solo and official sessions.
	_mod:hook(PlayerUnitSpawnManager, "init", function(orig, self, is_server, ...)
		local result = orig(self, is_server, ...)
		if is_server and _realms_bridge and _realms_bridge.is_host
			and _realms_bridge.is_host() then
			self._num_available_bot_slots = function(spawn_manager)
				local Managers = rawget(_G, "Managers")
				local bot_manager = Managers and Managers.bot
				local host
				if bot_manager and type(bot_manager.synchronizer_host) == "function" then
					local ok_host, value = pcall(bot_manager.synchronizer_host, bot_manager)
					if ok_host then host = value end
				end
				local num_bots = 0
				if host and type(host.num_bots) == "function" then
					local ok_count, value = pcall(host.num_bots, host)
					if ok_count then num_bots = tonumber(value) or 0 end
				end
				local queued = tonumber(spawn_manager._queued_bots_n) or 0
				-- Do not clamp this result. A negative number is Darktide's native
				-- signal to remove bots as real players occupy their mapped seats.
				return M.spawn_target() - num_bots - queued
			end
			if type(self._validate_bot_backfill) == "function" then
				pcall(self._validate_bot_backfill, self)
			end
		end
		return result
	end)

	_debug_log("bots", 0, "PlayerUnitSpawnManager hook installed", 0, "info")
end

-- ===========================================================================
-- Load-time warnings
--
-- Emitted on init so the player sees them the first time Pilgrimage loads
-- after (dis)installing BB or CCB. notify() goes through the chat feed,
-- which survives the DMF logging off-switch that squashes mod:echo.
-- ===========================================================================

local function _warn_better_bots_missing()
	if not _shared or not _shared.notify then return end
	_shared.notify(
		"Pilgrimage: Better Bots not detected. Higher War Plan tiers will be very hard on default bots. Install Better Bots for the intended experience.",
		"alert")
end

local function _warn_ccb_present()
	if not _shared or not _shared.notify then return end
	_shared.notify(
		"Pilgrimage: Custom Character Bots is installed and incompatible. Pilgrimage's bot preset system will not apply while CCB is enabled.",
		"alert")
end

local function _warn_vox_filter_missing()
	if not _shared or not _shared.notify then return end
	_shared.notify(
		"Pilgrimage: Vox Filter not detected. Bot voices will fade when they are behind the camera (Fatshark bug). Install Vox Filter for correct 2D bot voice mixing.",
		"alert")
end

-- ===========================================================================

function M.status()
	return {
		slot_count             = M.slot_count(),
		spawn_target           = M.spawn_target(),
		base_slots             = BASE_SLOTS,
		max_slots              = M.MAX_SLOTS,
		better_bots_present    = M.better_bots_present(),
		ccb_present            = M.custom_character_bots_present(),
		vox_filter_present     = M.vox_filter_present(),
		slot_from_first_recruit = _penances and _penances.is_earned
			and _penances.is_earned("pilgrim_first_recruit") or false,
		slot_from_second_recruit = _penances and _penances.is_earned
			and _penances.is_earned("pilgrim_second_recruit") or false,
		slot_from_sanctioned = _penances and _penances.is_earned
			and _penances.is_earned("pilgrim_sanctioned") or false,
		legacy_slot_from_shop_3 = _shop and _shop.is_unlocked
			and _shop.is_unlocked("bot_slot_3") or false,
		legacy_slot_from_shop_4 = _shop and _shop.is_unlocked
			and _shop.is_unlocked("bot_slot_4") or false,
		slot_from_full_muster  = _penances and _penances.is_earned
			and _penances.is_earned("pilgrim_full_muster") or false,
		slot_from_emperors_six = _penances and _penances.is_earned
			and _penances.is_earned("pilgrim_emperors_six") or false,
	}
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_penances = deps.penances
	_shop = deps.shop
	-- v0.22.75: optional; only none_count is read, and only at spawn
	-- time, so init order vs Preset does not matter.
	_preset = deps.preset
	_realms_bridge = deps.realms_bridge
	_debug_log = deps.debug_log or function() end

	if not M.better_bots_present() then
		_debug_log("bots", 0, "Better Bots not detected", 0, "warn")
		_warn_better_bots_missing()
	end

	if M.custom_character_bots_present() then
		_debug_log("bots", 0, "Custom Character Bots detected (incompatible)", 0, "warn")
		_warn_ccb_present()
	end

	if not M.vox_filter_present() then
		_debug_log("bots", 0, "Vox Filter not detected", 0, "warn")
		_warn_vox_filter_missing()
	end
end

return M
