--[[
	GhostHost - the Realms listen-server host plays as an invisible spectator
	========================================================================
	Use case: run the Realms listen server on a spare machine (a laptop next to
	the desk) and join it as a normal client from the main PC. The host machine
	then only has to simulate the mission - it must not take a squad slot, must
	not hold doors, lifts or the extraction zone, and must not keep the mission
	alive when the real squad wipes.

	KEY INSIGHT (verified against the game source, 2026-09-10):
	"a human player without a player_unit" is a VANILLA state - it is how the
	game represents a player who is waiting to be rescued. Every gameplay check
	that asks "all players" iterates
	    Managers.state.player_unit_spawn:alive_players()
	which is `_players_with_unit` - so a player without a unit is already
	excluded from all of it:

	  * failure conditions - game_mode_coop_complete_objective.lua:200
	    `_all_players_dead(..., include_bots = false)` only looks at humans that
	    HAVE a unit => the mission is lost exactly when the four guests go down,
	    and the ghost host never keeps it running.
	  * `_can_start_players_check` (:221) only arms once a living human exists,
	    so the host may load into the level before anybody joins.
	  * lifts / doors / extraction - trigger_condition_all_players_inside.lua,
	    trigger_condition_all_alive_players_inside.lua,
	    trigger_condition_at_least_half_players_inside.lua and
	    trigger_condition_all_required_players_in_end_zone.lua all walk
	    alive_players() as well => the airlock opens for the guests alone.
	  * enemy attention - without a unit the host is not in side_system's
	    `side_by_unit` / `player_units`, so minions never target him.
	  * pacing - pacing_manager.lua:590 counts `HEALTH_ALIVE[unit]`.
	  * rescue cage - respawn_beacon_system.lua:208 only wakes up when
	    `has_players_waiting_to_spawn()` is true, and that queue is built from
	    `can_spawn_player` (see below) => no cage, no rescue marker.
	  * AFK kick - afk_checker.lua:86 only inspects `player.remote`, never the
	    local host.
	  * companion teleports on doors/platforms use human_players() but every
	    loop is guarded with `if human_unit then` (door_extension.lua:646,684,
	    moveable_platform_extension.lua:529) => the ghost is skipped, not a
	    blocker.

	So the whole mod is two server-side hooks that put the host into that
	vanilla state and keep him there:

	  1) GameModeManager.should_spawn_dead -> true
	     PlayerUnitSpawnManager.spawn_player checks it FIRST and returns before
	     honouring `force_spawn`, and `force_spawn = true` is exactly what
	     HumanGameplay.on_enter:85-89 passes for the local player. The player is
	     filed under `_players_without_unit` instead.

	  2) GameModeManager.can_spawn_player -> false
	     PlayerUnitSpawnManager.fixed_update builds `_players_to_spawn` only
	     from players this returns true for, so the host is never respawned and
	     the respawn beacon stays asleep.

	Everything else in this file is comfort: camera behaviour, hiding the ghost
	from the team HUD, and keeping Realms' bot target honest.

	WHO NEEDS THE MOD: the host, always. Guests only need it for the HUD
	cosmetic (see hide_ghost_panel) - the gameplay half is server-authoritative
	and replicates by itself.
]]

local mod = get_mod("GhostHost")

local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

local CAMERA_SPECTATE = "spectate"

-- Realms/SoloPlay run normal missions as "coop_complete_objective" (that
-- includes Havoc). The hub, the Psykhanium and the shooting range must stay
-- untouched, otherwise the host would turn invisible on the Mourningstar and
-- could not pick a mission at all.
local GHOSTABLE_GAME_MODES = {
	coop_complete_objective = true,
}

-- Survival and Expedition hand out mission buffs and wait for a choice from
-- every human player (mission_buffs_selector.lua ->
-- check_if_all_players_chosen_family), which a unit-less host cannot make.
-- Opt-in only, and documented as untested.
local EXPERIMENTAL_GAME_MODES = {
	survival = true,
	expedition = true,
}

-- Set by "/ghosthost join": lets the host drop back into the game (he then
-- shows up in a rescue cage like any other dead player) without disabling the
-- whole mod.
local suspended = false

local announced = false

-- ---------------------------------------------------------------------------
-- Session / mission gates
-- ---------------------------------------------------------------------------

-- A Realms listen server is Darktide's player-hosted session type. Detection
-- straight from Realms' own integration docs.
local function is_realms_host()
	local multiplayer_session = Managers.multiplayer_session
	local connection = Managers.connection

	if not multiplayer_session or not connection then
		return false
	end

	if multiplayer_session:host_type() ~= HOST_TYPES.player then
		return false
	end

	return connection:is_host() and true or false
end

local function is_realms_session()
	local multiplayer_session = Managers.multiplayer_session

	return multiplayer_session and multiplayer_session:host_type() == HOST_TYPES.player or false
end

local function current_game_mode_name()
	local state = Managers.state
	local game_mode_manager = state and state.game_mode

	return game_mode_manager and game_mode_manager:game_mode_name()
end

local function is_ghostable_mission()
	local game_mode_name = current_game_mode_name()

	if not game_mode_name then
		return false
	end

	if GHOSTABLE_GAME_MODES[game_mode_name] then
		return true
	end

	return mod:get("allow_experimental_modes") and EXPERIMENTAL_GAME_MODES[game_mode_name] or false
end

local function local_player()
	local player_manager = Managers.player

	return player_manager and player_manager:local_player_safe(1)
end

-- The one predicate the two gameplay hooks share: is THIS player the local
-- host of a Realms mission that we are allowed to ghost?
local function is_ghost_target(player)
	if suspended or not player or player.remote then
		return false
	end

	if not player.is_human_controlled or not player:is_human_controlled() then
		return false
	end

	local peer_id = player.peer_id and player:peer_id()

	if not peer_id or peer_id ~= Network.peer_id() then
		return false
	end

	return is_realms_host() and is_ghostable_mission()
end

-- "The ghost is currently in effect": used by the bot-count correction, the
-- announcement and the status command. Deliberately checks the missing unit
-- instead of the settings, so it stays false while the host still has a body.
local function is_ghost_active()
	if not is_realms_host() or not is_ghostable_mission() then
		return false
	end

	local player = local_player()

	return player ~= nil and player.player_unit == nil
end

-- ---------------------------------------------------------------------------
-- 1) Do not spawn the host, ever
-- ---------------------------------------------------------------------------

mod:hook(CLASS.GameModeManager, "should_spawn_dead", function (func, self, player)
	if is_ghost_target(player) then
		return true
	end

	return func(self, player)
end)

mod:hook(CLASS.GameModeManager, "can_spawn_player", function (func, self, player)
	if is_ghost_target(player) then
		return false
	end

	return func(self, player)
end)

-- ---------------------------------------------------------------------------
-- 2) Camera
-- ---------------------------------------------------------------------------
--
-- Vanilla already does the cheap thing for us: CameraHandler._next_follow_unit
-- bails out with `nil` unless `self._side_id` is set, and `_side_id` is only
-- ever assigned by `_follow_owner()`, which needs the player's own unit. A
-- ghost host therefore never follows anybody - the viewport stays where
-- spawn_camera() created it (world origin) and `_update_follow` reports
-- set_has_proper_3d_camera(false), which is the cheapest state the client half
-- of the game can be in. That is the "static" camera mode: nothing to hook.
--
-- The "spectate" mode restores what a dead player sees, by answering
-- _next_follow_unit ourselves from alive_players() instead of from the side
-- the host is not part of. HumanGameplay then builds the spectator HUD on its
-- own (it derives `_spectated_player` from the followed unit).

local spectate_players = {}
local spectate_units = {}

local function sort_by_unique_id(a, b)
	return tostring(a:unique_id()) < tostring(b:unique_id())
end

-- NOTE: alive_players() hands back a table the engine reuses and clears, so
-- copy out of it in the same breath - never keep the reference.
local function collect_spectate_units()
	table.clear(spectate_players)
	table.clear(spectate_units)

	local state = Managers.state
	local player_unit_spawn_manager = state and state.player_unit_spawn

	if not player_unit_spawn_manager then
		return spectate_units
	end

	local alive_players = player_unit_spawn_manager:alive_players()

	for i = 1, #alive_players do
		local player = alive_players[i]
		local player_unit = player.player_unit

		if player:is_human_controlled() and player_unit and ALIVE[player_unit] then
			spectate_players[#spectate_players + 1] = player
		end
	end

	-- `_players_with_unit` is a hash map, so its iteration order is not stable;
	-- sort so that "spectate next" walks the squad in the same order every time.
	table.sort(spectate_players, sort_by_unique_id)

	for i = 1, #spectate_players do
		spectate_units[i] = spectate_players[i].player_unit
	end

	return spectate_units
end

mod:hook(CLASS.CameraHandler, "_next_follow_unit", function (func, self, except_unit)
	if mod:get("camera_mode") ~= CAMERA_SPECTATE or not is_ghost_target(self._player) then
		return func(self, except_unit)
	end

	local units = collect_spectate_units()
	local num_units = #units

	if num_units == 0 then
		return nil
	end

	local old_unit = self._camera_follow_unit

	if not old_unit then
		local selected_unit = units[1]

		if selected_unit == except_unit then
			selected_unit = units[2]
		end

		return selected_unit
	end

	local selected_index = 1

	for i = 1, num_units do
		if units[i] == old_unit then
			selected_index = i % num_units + 1

			break
		end
	end

	local selected_unit = units[selected_index]

	if selected_unit == except_unit then
		selected_unit = num_units > 1 and units[selected_index % num_units + 1] or nil
	end

	return selected_unit
end)

-- ---------------------------------------------------------------------------
-- 3) Team HUD - the only part guests benefit from
-- ---------------------------------------------------------------------------
--
-- hud_element_team_panel_handler_settings.lua caps the team panel at
-- max_panels = 4, and a five-member Realms session has one member too many:
-- the ghost can eat the panel of a living team mate. Everyone running this mod
-- simply never adds a panel for a host that has no unit.

local function is_ghost_panel(unique_id)
	if not unique_id or not is_realms_session() or not is_ghostable_mission() then
		return false
	end

	local connection = Managers.connection
	local host_peer_id = connection and connection:host()

	if not host_peer_id then
		return false
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:player_from_unique_id(unique_id)

	if not player or not player:is_human_controlled() then
		return false
	end

	if player:peer_id() ~= host_peer_id then
		return false
	end

	-- Only while he actually is a ghost: the panel comes back the moment the
	-- host spawns a unit (mod disabled, /ghosthost join, next mission).
	return player.player_unit == nil
end

mod:hook(CLASS.HudElementTeamPanelHandler, "_add_panel", function (func, self, unique_id, ui_renderer, fixed_scenegraph_id)
	if mod:get("hide_ghost_panel") and is_ghost_panel(unique_id) then
		return
	end

	return func(self, unique_id, ui_renderer, fixed_scenegraph_id)
end)

-- ---------------------------------------------------------------------------
-- 4) Bot target correction
-- ---------------------------------------------------------------------------
--
-- Realms fills bots from its own formula (core/bot_backfill.lua):
--     desired = mod:get("bot_fill_target") - Managers.player:num_ready_human_players()
-- and that counter walks `_human_players`, where a unit-less host still
-- counts. Without the correction "bot_fill_target = 4" means "3 guests + 1
-- ghost = squad full". Subtracting the ghost makes the target mean what a
-- player expects: how many bodies should be in the squad.
--
-- num_ready_human_players() has exactly two call sites in the game
-- (player_unit_spawn_manager.lua:417 - the vanilla bot formula Realms
-- replaces) plus Realms' own, so this correction cannot leak anywhere else.

mod:hook(CLASS.PlayerManager, "num_ready_human_players", function (func, self)
	local num_players = func(self)

	if not mod:get("bot_target_ignores_ghost") or not is_ghost_active() then
		return num_players
	end

	return math.max(num_players - 1, 0)
end)

-- ---------------------------------------------------------------------------
-- 5) Escape must still open the system menu
-- ---------------------------------------------------------------------------
--
-- Found the hard way in a live session: with the static camera the host could
-- not open the system menu at all and had to kill the game to stop the server.
--
-- Why: with no unit the camera never follows anybody, so `_update_follow`
-- reports set_has_proper_3d_camera(false), and constant_element_loading.lua:103
-- turns that into an active `loading_view`. UIManager._update_view_hotkeys only
-- reaches its "open a view by hotkey" branch when NO view is active
-- (ui_manager.lua:548-587) - with the loading view up, Escape is swallowed.
--
-- Two ways out, both optional:
--   * esc_opens_menu (default): when that blank screen is up, open system_view
--     ourselves on the same hotkey. Keeps `disable_game_world = true` of the
--     loading view, i.e. the host machine still renders no 3D world at all.
--   * disable_loading_overlay: claim a proper 3D camera, so no loading view is
--     shown and Escape works exactly like vanilla - at the price of the host
--     rendering the world again (from the camera's spawn point at the world
--     origin, which can mean the whole level in frame).

local MENU_OPEN_COOLDOWN = 0.5
local last_menu_open_t = -MENU_OPEN_COOLDOWN

mod:hook(CLASS.CameraManager, "has_proper_3d_camera", function (func, self)
	if mod:get("disable_loading_overlay") and is_ghost_active() then
		return true
	end

	return func(self)
end)

-- "The host is staring at the loading overlay because it has no camera."
-- Asks the camera manager, so it also covers the spectate mode while there is
-- nobody alive to spectate (and it answers `true` through the hook above when
-- the overlay is disabled, which is exactly when this path is not needed).
local function blank_screen_active()
	if not is_ghost_active() then
		return false
	end

	local camera_manager = Managers.state and Managers.state.camera

	return camera_manager ~= nil and not camera_manager:has_proper_3d_camera()
end

local function open_system_menu(ui_manager)
	ui_manager = ui_manager or Managers.ui

	if not ui_manager or ui_manager:view_active("system_view") then
		return false
	end

	last_menu_open_t = Managers.time and Managers.time:time("main") or 0

	ui_manager:open_view("system_view")

	return true
end

mod:hook(CLASS.UIManager, "_update_view_hotkeys", function (func, self)
	if not mod:get("esc_opens_menu") or not blank_screen_active() then
		return func(self)
	end

	-- Never steal the key from the chat or another element that owns input:
	-- there Escape means "close me", not "open the menu".
	local constant_elements = self._ui_constant_elements

	if constant_elements and constant_elements:using_input() then
		return func(self)
	end

	local view_handler = self._view_handler

	if not view_handler or view_handler:transitioning() or self:view_active("system_view") then
		return func(self)
	end

	local input_service = self:input_service()

	if input_service and input_service:get("hotkey_system") then
		local t = Managers.time and Managers.time:time("main") or 0

		-- The view reads the same key on the frame it opens; without the
		-- cooldown it would close itself again immediately.
		if MENU_OPEN_COOLDOWN < t - last_menu_open_t and open_system_menu(self) then
			return
		end
	end

	return func(self)
end)

-- ---------------------------------------------------------------------------
-- 6) Announcement + status command
-- ---------------------------------------------------------------------------

local function realms_max_players()
	local realms = get_mod("Realms")

	return realms and realms:get("max_players") or nil
end

local function num_session_humans()
	local player_manager = Managers.player

	if not player_manager then
		return 0
	end

	local count = 0

	for _, _player in pairs(player_manager:human_players()) do
		count = count + 1
	end

	return count
end

-- DMF calls mod.update even for disabled mods, hence the explicit gate.
mod.update = function ()
	if not mod:is_enabled() then
		return
	end

	if not is_ghost_active() then
		announced = false

		return
	end

	if announced or not mod:get("announce_on_start") then
		return
	end

	announced = true

	mod:echo(mod:localize("msg_ghost_active"))

	local max_players = realms_max_players()

	if max_players and max_players < 5 then
		mod:echo(mod:localize("msg_max_players_low", max_players, max_players - 1))
	end
end

mod:command("ghosthost", mod:localize("cmd_description"), function (argument)
	if argument == "menu" then
		if open_system_menu() then
			mod:echo(mod:localize("msg_menu_opened"))
		else
			mod:echo(mod:localize("msg_menu_already_open"))
		end

		return
	end

	if argument == "join" then
		suspended = true

		mod:echo(mod:localize("msg_suspended"))

		return
	end

	if argument == "ghost" then
		suspended = false

		local player = local_player()

		if player and player.player_unit then
			mod:echo(mod:localize("msg_resumed_with_body"))
		else
			mod:echo(mod:localize("msg_resumed"))
		end

		return
	end

	local player = local_player()
	local state = Managers.state
	local player_unit_spawn_manager = state and state.player_unit_spawn
	local num_alive = 0

	if player_unit_spawn_manager then
		num_alive = #player_unit_spawn_manager:alive_players()
	end

	mod:echo(mod:localize("msg_status_session", tostring(is_realms_host()), tostring(current_game_mode_name())))
	mod:echo(mod:localize("msg_status_ghost", tostring(is_ghost_active()), tostring(suspended)))
	mod:echo(mod:localize("msg_status_squad", num_session_humans(), num_alive, tostring(realms_max_players())))
	mod:echo(mod:localize("msg_status_body", tostring(player ~= nil and player.player_unit ~= nil)))
end)
