-- Switch operatives from the Esc menu without reloading the Mourningstar.
-- Hub: apply the backend profile locally, guard against old server pushes,
-- and refresh after loadout edits. The visible unit changes on next travel.
-- Psykhanium: use the host's profile override and package-driven respawn.
-- Presence, matchmaking and session sync all follow the selected character.
-- See README.md for the user flow, architecture and in-game verification.

local mod = get_mod("InstantCharacterChange")

-- Sandboxed io/os handed to mods by DMF.
local _io = Mods and Mods.lua and Mods.lua.io or nil
local _os = Mods and Mods.lua and Mods.lua.os or nil

-- View classes are loaded LAZILY by the game (on first open), so at mod-load
-- time CLASS.<ViewName> may still be nil — and DMF silently refuses to hook
-- a nil object (the hook just never attaches; this is why hooks on the
-- inventory view can appear "dead"). Require the files explicitly so the
-- class tables exist right now and hook those directly.
local ok_require_invview, InventoryBackgroundViewClass = pcall(require, "scripts/ui/views/inventory_background_view/inventory_background_view")
local ok_require_sysview, SystemViewClass = pcall(require, "scripts/ui/views/system_view/system_view")

if not ok_require_invview then
	InventoryBackgroundViewClass = nil
end

if not ok_require_sysview then
	SystemViewClass = nil
end

local ok_require_presets_el, ViewElementProfilePresetsClass = pcall(require, "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets")

if not ok_require_presets_el then
	ViewElementProfilePresetsClass = nil
end

-- The world-marker HUD element, needed for the meat-grinder damage-indicator
-- fix below. Required explicitly for the same reason as the views above: the
-- class must exist NOW for the hook to attach.
local ok_require_wm, HudElementWorldMarkersClass = pcall(require, "scripts/ui/hud/elements/world_markers/hud_element_world_markers")

if not ok_require_wm then
	HudElementWorldMarkersClass = nil
end

-- Lazily-required game modules (cached), so a load-order quirk or a future
-- game update can never crash the mod at file scope.
local _profile_utils
local function profile_utils()
	if not _profile_utils then
		local ok, m = pcall(require, "scripts/utilities/profile_utils")
		if ok then
			_profile_utils = m
		end
	end
	return _profile_utils
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

-- Armed switch: { profile = <backend profile>, character_id = <uuid>,
--                 label = "Psyker Lv 30 (CoolName)" }. nil when not armed.
mod._target = nil
mod._switch_epoch = 0
mod._switch_request = nil
mod._profile_refresh = nil

-- Anti-revert guard for the Esc-menu hub swap: while set, incoming profile
-- pushes from the hub server for OUR player that carry a DIFFERENT character
-- are dropped (the hub server only knows the character we connected with and
-- would otherwise overwrite the local swap after every loadout edit).
-- Cleared automatically when handshaking into a new session (the new server
-- is authoritative for the right character from then on) or in the main menu.
mod._local_swap_character_id = nil

-- Presence-restart bookkeeping (see force_presence_readvertise): debounce
-- countdown, a deferred-restart reason set while the debounce is running, and
-- the one-shot re-init retry timer. All driven from mod.update.
mod._presence_restart_cooldown = nil
mod._presence_restart_pending = nil
mod._presence_reinit_retry = nil

-- ---------------------------------------------------------------------------
-- Diagnostics log: %APPDATA%\Fatshark\Darktide\InstantCharacterChange.log
-- ---------------------------------------------------------------------------

local function timestamp()
	if _os and _os.date then
		local ok, str = pcall(_os.date, "%Y-%m-%d %H:%M:%S")
		if ok and str then
			return str
		end
	end
	return "unknown-time"
end

local function write_log_line(text)
	if not mod:get("diagnostics_enabled") then
		return
	end
	if not _io or not _io.open or not _os or not _os.getenv then
		return
	end
	local appdata = _os.getenv("APPDATA") or _os.getenv("AppData")
	if not appdata or appdata == "" then
		return
	end
	local path = appdata .. "\\Fatshark\\Darktide\\InstantCharacterChange.log"
	local file = _io.open(path, "a")
	if not file then
		return
	end
	file:write(string.format("[%s] %s\n", timestamp(), text))
	file:close()
end

-- Logs technical text to the file and optionally echoes chat_text (or the
-- same text) to chat. A localized chat message never changes the log marker. The text
-- is passed to echo as a format ARGUMENT so stray '%' in names/errors can't
-- break string.format. Chat output respects the "chat_messages_enabled"
-- setting; switch rejection messages are always shown.
local function log(text, echo_too, chat_text)
	write_log_line(text)
	if echo_too and mod:get("chat_messages_enabled") then
		mod:echo("[InstantCharacterChange] %s", chat_text or text)
	end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- The REAL local profile, bypassing our own local_player_backend_profile hook.
local function real_local_profile()
	local ok, player = pcall(function()
		return Managers.player:local_player(1)
	end)
	if not ok or not player then
		return nil
	end
	local ok_p, profile = pcall(function()
		return player:profile()
	end)
	return ok_p and profile or nil
end

local function current_game_mode()
	local game_mode = Managers.state and Managers.state.game_mode
	if not game_mode then
		return nil
	end
	local ok, name = pcall(function()
		return game_mode:game_mode_name()
	end)
	return ok and name or nil
end

local function in_hub()
	return current_game_mode() == "hub"
end

-- Psykhanium / shooting range: a locally hosted singleplayer session where WE
-- are the host, so the game's own profile-override machinery can apply the
-- switch LIVE with a full respawn. It is the same pipeline the training
-- scenario uses to hand you specific weapons (override_slot) and the barber
-- uses for appearance changes: override_singleplay_profile ->
-- ProfileSynchronizerHost.update applies set_profile ->
-- PackageSynchronizerHost sees the archetype changed, despawns the unit,
-- loads the new class' packages and respawns on the spot.
local function in_own_singleplay_session()
	local name = current_game_mode()
	if name ~= "training_grounds" and name ~= "shooting_range" then
		return false
	end
	local ok, host = pcall(function()
		return Managers.profile_synchronization:synchronizer_host()
	end)
	return ok and host ~= nil
end

-- Display names for archetypes (raw name -> label); anything missing falls
-- back to a capitalized raw name, so future classes still show. Used by the
-- Esc panel entries and the party-chat announcement.
local ARCHETYPE_DISPLAY_NAMES = {
	veteran = "Veteran",
	zealot = "Zealot",
	psyker = "Psyker",
	ogryn = "Ogryn",
	adamant = "Arbites",
	cryptic = "Skitarii",
	broker = "Hive Scum",
}

local function _archetype_display_name(archetype_name)
	local display = ARCHETYPE_DISPLAY_NAMES[archetype_name]

	if display then
		return display
	end

	local raw = tostring(archetype_name or "?")

	return raw:sub(1, 1):upper() .. raw:sub(2)
end

-- Custom character order (drag & drop in the Esc panel), persisted as an
-- array of character ids in the mod settings. Applied to every fetched
-- profile list the panel shows. Ids missing from the saved order
-- (new characters) keep their
-- backend order at the end; stale ids are skipped. Every save rewrites the
-- full list, so it self-heals.
local function apply_saved_order(profiles)
	local saved = mod:get("character_order")

	if type(saved) ~= "table" or #saved == 0 then
		return profiles
	end

	local by_id = {}

	for i = 1, #profiles do
		local id = profiles[i].character_id

		if id then
			by_id[id] = profiles[i]
		end
	end

	local ordered = {}
	local used = {}

	for i = 1, #saved do
		local id = saved[i]
		local profile = by_id[id]

		if profile and not used[id] then
			ordered[#ordered + 1] = profile
			used[id] = true
		end
	end

	for i = 1, #profiles do
		local id = profiles[i].character_id

		if not id or not used[id] then
			ordered[#ordered + 1] = profiles[i]
		end
	end

	return ordered
end

-- ---------------------------------------------------------------------------
-- Party-chat announcement ("party_announce_enabled" setting, default off)
-- ---------------------------------------------------------------------------

local _chat_constants
local function chat_constants()
	if not _chat_constants then
		local ok, m = pcall(require, "scripts/foundation/managers/chat/chat_manager_constants")
		if ok then
			_chat_constants = m
		end
	end
	return _chat_constants
end

-- Handle of the party chat channel, or nil when there is none. Strictly the
-- PARTY-tagged channel, no fallback: outside a party the only other channel
-- is the hub-wide one, and announcing there would spam strangers.
local function party_channel()
	local chat = Managers.chat

	if not chat or not chat.sessions then
		return nil
	end

	local sessions = chat:sessions()

	if type(sessions) ~= "table" then
		return nil
	end

	local constants = chat_constants()
	local party_tag = constants and constants.ChannelTag and constants.ChannelTag.PARTY

	if not party_tag then
		return nil
	end

	for handle, channel in pairs(sessions) do
		local tag = channel.tag or chat:tag_from_session_handle(handle)

		if tag == party_tag then
			return handle
		end
	end

	return nil
end

-- Tint for the class names in the announcement ("party_announce_color"
-- dropdown), applied with the game's own {#color(r,g,b)}...{#reset()} text
-- markup — only to the two class names, the way the game's system messages
-- highlight their key fragments. The markup renders on the RECEIVING clients
-- too: the chat UI only scrubs markup typed into the input field, not
-- incoming messages (field-tested in another mod).
-- KEEP THE RGB VALUES IN SYNC with the party_color_* dropdown labels in the
-- localization file — those preview these exact colors via the same markup.
local ANNOUNCE_COLORS = {
	amber = { 235, 185, 90 },
	steel_blue = { 130, 180, 215 },
	green = { 80, 220, 80 },
	red = { 235, 95, 80 },
	purple = { 190, 125, 220 },
}

-- Short party-chat message on switch, so the party immediately sees the
-- class change. Only sent when there is someone in the party to read it AND
-- a party chat channel exists.
local function announce_switch_to_party(from_profile, to_profile)
	if not mod:get("party_announce_enabled") then
		return
	end

	pcall(function()
		local others = Managers.party_immaterium:other_members()

		if not others or #others == 0 then
			return
		end

		local handle = party_channel()

		if not handle then
			return
		end

		local from_name = _archetype_display_name(from_profile and from_profile.archetype and from_profile.archetype.name)
		local to_name = _archetype_display_name(to_profile and to_profile.archetype and to_profile.archetype.name)
		local shown_from, shown_to = from_name, to_name
		local color = ANNOUNCE_COLORS[mod:get("party_announce_color")]

		if color then
			local tint = string.format("{#color(%d,%d,%d)}", color[1], color[2], color[3])

			shown_from = tint .. from_name .. "{#reset()}"
			shown_to = tint .. to_name .. "{#reset()}"
		end

		Managers.chat:send_channel_message(handle, string.format("Switched character: %s -> %s", shown_from, shown_to))
		log("Announced the switch in party chat: " .. from_name .. " -> " .. to_name)
	end)
end

-- ---------------------------------------------------------------------------
-- Presence re-advertise: make PARTY MEMBERS see the switch
--
-- The party panels other players see (hub left side, Social, Party Finder)
-- are driven by PRESENCE, not by the hub server's profile sync: their clients
-- read presence:character_profile(), a blob the BACKEND attaches to our
-- presence from the character_id we advertise, and the panels live-refresh
-- when it changes. Our client only ever sends the character_id
-- (presence_entry_myself.create_key_values).
--
-- The game's own path for advertising a change is PresenceManager.update
-- polling local_player_backend_profile() every ~1s and sending an INCREMENTAL
-- update on the live stream (a vanilla character change relies on exactly
-- this; the stream itself is only reset at title/error/shutdown). Field
-- reports say the party still saw the OLD character after a mod switch, so
-- on top of that update the stream is RESTARTED here: abort + immediate
-- re-init sends the same full handshake as a game login, which makes the
-- backend re-resolve the blob. The tap hook below logs every advertisement
-- and the stream state, so a failing field test can tell "the update never
-- left" (DEAD/MISSING stream) apart from "the backend ignored it".
-- ---------------------------------------------------------------------------

local PRESENCE_RESTART_DEBOUNCE = 5
local PRESENCE_REINIT_RETRY_DELAY = 1

-- True while the user's AppearOffline mod keeps the presence stream down on
-- purpose — restarting it here would silently end that invisibility. (Its
-- /online restore performs the same full handshake, which then advertises
-- whatever character we set below, so the switch still propagates.)
local function appear_offline_active()
	local ok, offline = pcall(function()
		local other = get_mod("AppearOffline")

		return other and other:is_enabled() and other._offline == true
	end)

	return ok and offline == true
end

-- Pushes the given character into our presence NOW and restarts the presence
-- stream so the backend rebuilds what the party sees. Debounced: within the
-- cooldown the restart is DEFERRED, not dropped (mod.update fires it with
-- whoever we are/armed as by then), so rapid re-switching ends up advertised
-- correctly. The local set_character_profile always happens immediately.
local function force_presence_readvertise(profile, reason)
	if not profile then
		return
	end

	local ok, err = pcall(function()
		local pm = Managers.presence

		if not pm or not pm._initialized then
			return
		end

		-- Local presence entry first: the incremental update this sends and
		-- any later handshake both advertise this character_id.
		pm:set_character_profile(profile)

		if appear_offline_active() then
			log("Presence: stream restart skipped, AppearOffline invisibility is active (" .. tostring(reason) .. ")")

			return
		end

		if mod._presence_restart_cooldown then
			mod._presence_restart_pending = tostring(reason) .. ", deferred"

			log("Presence: stream restart deferred by debounce (" .. tostring(reason) .. ")")

			return
		end

		-- Same detach-then-abort pattern AppearOffline uses (detach first so
		-- PresenceManager.update never sees the dead stream), plus the
		-- immediate re-init the game itself runs at login.
		local stream = pm._my_presence_stream

		pm._my_presence_stream = nil
		mod._presence_restart_cooldown = PRESENCE_RESTART_DEBOUNCE
		mod._presence_reinit_retry = PRESENCE_REINIT_RETRY_DELAY

		if stream then
			stream:abort()
		end

		pm:_init_immaterium_presence()

		log("Presence: stream restarted — full handshake sent with character_id=" .. tostring(profile.character_id) .. " (" .. tostring(reason) .. ")")
	end)
	if not ok then
		log("Presence: restart failed: " .. tostring(err), true)
	end
end

-- Log-only tap on every presence character advertisement — the game's own
-- 1s poll and our forced calls both land here (the hook runs after the
-- message was handed to the stream).
mod:hook_safe(CLASS.PresenceManager, "set_character_profile", function(self, character_profile)
	if not mod:get("diagnostics_enabled") then
		return
	end

	local stream_state = "MISSING"

	pcall(function()
		local stream = self._my_presence_stream

		if stream then
			stream_state = stream:alive() and "alive" or "DEAD"
		end
	end)

	log(string.format("Presence: advertised character_id=%s (stream %s)",
		tostring(character_profile and character_profile.character_id), stream_state))
end)

-- ---------------------------------------------------------------------------
-- Switch application
-- ---------------------------------------------------------------------------

-- Applies the armed switch RIGHT NOW inside a locally hosted singleplayer
-- session (see in_own_singleplay_session). On the next synchronizer tick the
-- profile is applied (our set_profile hook then clears the target and reports success)
-- and the unit respawns as the new class.
local function apply_live_singleplay_switch()
	local target = mod._target
	if not target then
		return
	end

	local ok, err = pcall(function()
		local host = Managers.profile_synchronization:synchronizer_host()
		local player = Managers.player:local_player(1)

		host:override_singleplay_profile(player:peer_id(), player:local_player_id(), target.profile)
	end)
	if ok then
		log("Live switch requested via override_singleplay_profile — respawn incoming")
	else
		log("Live switch failed: " .. tostring(err) .. " (switch stays armed for the next travel)", true)
	end
end

-- Applies the armed switch locally while standing in the hub. The hub
-- server cannot be re-told who we are, so your VISIBLE unit stays the old
-- character — but everything data-driven becomes the new one: the loadout /
-- talent views open for the new character (edits hit the right character on
-- the backend, since equips use player:character_id()), the Party Finder
-- advertises the new class, and the next mission connects as it. The
-- set_profile detector hook below fires from our own call and clears the target.
local function apply_hub_local_switch()
	local target = mod._target
	if not target then
		return
	end

	local ok, err = pcall(function()
		local player = Managers.player:local_player(1)

		-- Guard first, so a server push racing our swap cannot revert it.
		mod._local_swap_character_id = target.character_id

		player:set_profile(target.profile)
	end)
	if ok then
		log("Hub-local switch applied (unit stays the old character until the next travel)", true, mod:localize("msg_hub_swapped"))
	else
		mod._local_swap_character_id = nil
		log("Hub-local switch failed: " .. tostring(err) .. " (switch stays armed for the next travel)", true)
		force_presence_readvertise(target.profile, "hub apply failed; switch armed")
	end
end

-- Re-read at every async boundary. A failed state query must not authorize
-- an identity change while the connection state is unknown.
local function switch_block_reason()
	local ok, reason = pcall(function()
		if not in_hub() and not in_own_singleplay_session() then
			return "msg_hub_only"
		end
		local party = Managers.party_immaterium
		if Managers.data_service.social:is_in_matchmaking() then
			return "msg_in_matchmaking"
		end
		if party:game_session_in_progress() then
			return "msg_departing_blocked"
		end
		local vote = party:party_vote_state()
		if vote and vote.type == "start_matchmaking" and vote.state == "ONGOING" then
			return "msg_start_vote_blocked"
		end
	end)
	if not ok then
		return "msg_switch_unavailable"
	end
	return reason
end

local function arm(profile)
	if mod._switch_request then
		mod:echo("[InstantCharacterChange] %s", mod:localize("msg_switch_pending"))
		return false
	end
	local current = real_local_profile()
	if current and current.character_id == profile.character_id then
		mod:echo("[InstantCharacterChange] %s", mod:localize("msg_already_that_character"))
		return false
	end
	local reason = switch_block_reason()
	if reason then
		mod:echo("[InstantCharacterChange] %s", mod:localize(reason))
		return false
	end

	local request = {
		player = Managers.player:local_player(1),
		original_id = current and current.character_id,
	}
	mod._switch_request = request
	local label = string.format("%s (%s, lv %s)", profile.name or "?",
		profile.archetype and profile.archetype.name or "?", tostring(profile.current_level or "?"))

	local function is_current()
		return mod._switch_request == request
	end
	local function can_apply()
		if not is_current() then
			return false
		end
		local live = real_local_profile()
		local blocked = switch_block_reason()
		return not blocked and Managers.player:local_player(1) == request.player
			and live and live.character_id == request.original_id
	end
	local function finish()
		if is_current() then
			mod._switch_request = nil
		end
	end
	local function failed(err)
		if is_current() then
			mod:echo("[InstantCharacterChange] %s", mod:localize("msg_switch_unavailable"))
			log("Switch request failed: " .. tostring(err))
		end
		finish()
	end

	-- Narrative belongs to THIS operation. Do not publish a target before it
	-- is ready, and do not let another selection overtake the account POST.
	local ok, err = pcall(function()
		Managers.narrative:load_character_narrative(profile.character_id):next(function()
			if not can_apply() then
				finish()
				return
			end
			return Managers.data_service.account:set_selected_character_id(profile.character_id):next(function()
				if not is_current() then
					return
				end
				if not can_apply() then
					-- Keep the operation locked until rollback completes. Queue
					-- tickets still use the previous identity throughout this path.
					local effective = mod._target and mod._target.profile or real_local_profile()
					if effective then
						return Managers.data_service.account:set_selected_character_id(effective.character_id):next(finish)
					end
					finish()
					return
				end

				mod._target = { profile = profile, character_id = profile.character_id, label = label }
				finish()
				log("Backend accepted selected-character change. Switch ARMED: " .. label, true)
				announce_switch_to_party(current, profile)
				if in_own_singleplay_session() then
					apply_live_singleplay_switch()
				else
					apply_hub_local_switch()
				end
			end)
		end):catch(failed)
	end)
	if not ok then
		failed(err)
		return false
	end
end

-- ---------------------------------------------------------------------------
-- The three hooks that do the actual switching
-- ---------------------------------------------------------------------------

-- 1) Identity for presence (what the Party Finder leader sees) and for every
--    matchmaking queue ticket. All of them read this one function.
mod:hook(CLASS.PlayerManager, "local_player_backend_profile", function(func, self, ...)
	local target = mod._target
	if target then
		return target.profile
	end
	return func(self, ...)
end)

-- 2) The character we CLAIM when connecting to a game server
--    (rpc_sync_local_players). The server fetches the real profile for this
--    id from the backend itself, so this is the only field that matters.
mod:hook(CLASS.PlayerManager, "create_sync_data", function(func, self, peer_id, include_profile_chunks, ...)
	local sync_data = func(self, peer_id, include_profile_chunks, ...)
	local target = mod._target

	if peer_id == Network.peer_id() then
		-- Handshaking into a new session: from here the server is
		-- authoritative for the right character, so the hub-swap
		-- anti-revert guard (see apply_hub_local_switch) is no longer needed.
		mod._local_swap_character_id = nil
	end

	if not target or peer_id ~= Network.peer_id() then
		return sync_data
	end

	local ids = sync_data.character_id_array
	local humans = sync_data.is_human_controlled_array

	if type(ids) ~= "table" or type(humans) ~= "table" then
		return sync_data
	end

	for i = 1, #ids do
		if humans[i] then
			log(string.format("create_sync_data: claiming character %s instead of %s (slot %d)",
				tostring(target.character_id), tostring(ids[i]), i))
			ids[i] = target.character_id

			-- Player-hosted sessions (psykhanium etc.) also pack the whole
			-- profile; swap it so the claim is consistent there too.
			local chunks_array = sync_data.profile_chunks_array
			if chunks_array and chunks_array[i] then
				local PU = profile_utils()
				if PU then
					local ok = pcall(function()
						local profile_json = PU.pack_profile(target.profile)
						local chunks = {}
						PU.split_for_network(profile_json, chunks)
						chunks_array[i] = chunks
					end)
					if not ok then
						log("create_sync_data: could not repack profile chunks (continuing with id claim only)")
					end
				end
			end
		end
	end

	return sync_data
end)

-- 3) Success detection: when a server accepts the claim it fetches the
--    target character from the backend and syncs the profile back to us
--    (local_profiles_sync_state.lua -> player:set_profile). The hub server
--    keeps sending our OLD character, so a false trigger cannot happen.
--    (Also fires right after our own set_profile in the singleplayer hook
--    below, which is the correct moment to clear the target there too.)
mod:hook_safe(CLASS.HumanPlayer, "set_profile", function(self, profile)
	local target = mod._target
	if not target or not profile or profile.character_id ~= target.character_id then
		return
	end

	local ok, is_local = pcall(function()
		return self:peer_id() == Network.peer_id()
	end)
	if ok and is_local then
		local label = target.label
		mod._switch_epoch = mod._switch_epoch + 1
		mod._switch_request = nil
		mod._profile_refresh = nil

		mod._target = nil

		log("Switch applied — now playing as " .. tostring(label), true)

		-- One place covers every applied path (hub swap, psykhanium respawn,
		-- new-server accept): the party sees the new operative via presence.
		force_presence_readvertise(profile, "switch applied")
	end
end)

-- 4) Singleplayer sessions (Psykhanium / shooting range). There is no
--    network handshake and no backend fetch there: the game reuses the local
--    player object AS IS (connection_singleplayer.lua), so hooks 1-2 never
--    run. Instead, swap the profile on the local player directly at session
--    boot — this is the moment the hub is being torn down (safe to swap) and
--    it is BEFORE the loading state, so the target class' packages load.
--    The set_profile hook above then sees the target id and clears it.
mod:hook_safe(CLASS.MultiplayerSessionManager, "boot_singleplayer_session", function(self)
	local target = mod._target
	if not target then
		return
	end

	-- The hub keeps ticking for a few frames after this call, and its
	-- onboarding UI indexes NarrativeManager data by our profile's
	-- character_id every frame. That data is preloaded at arm time (see
	-- arm()), but if the backend reply has not landed yet, swapping now
	-- would crash the game — degrade gracefully instead: enter the
	-- Psykhanium as the old character and keep the switch armed.
	local narrative_ready = pcall(function()
		local characters = Managers.narrative._characters
		return assert(characters and characters[target.character_id])
	end)
	if not narrative_ready then
		log("Singleplayer session boot: target narrative not loaded yet — keeping current character for this visit (switch stays armed)", true)
		return
	end

	local ok = pcall(function()
		local player = Managers.player:local_player(1)
		player:set_profile(target.profile)
	end)
	if ok then
		log("Singleplayer session boot: local profile swapped to " .. tostring(target.label))
	else
		log("Singleplayer session boot: could not swap local profile", true)
	end
end)

-- 5) Respawn guard for the live switch. A different archetype (or gender /
--    voice / height) makes PackageSynchronizerHost despawn the unit, load the
--    new class' packages over several frames and only THEN respawn it
--    (spawn_player with force_spawn). While the packages load, the player
--    sits in the spawn manager's "without unit" list and the game mode's
--    can_spawn_player() still says yes -- harmless in vanilla, where nothing
--    in the Psykhanium spawns from that list, but SoloPlay 2.6+
--    (workarounds/shooting_range.lua) respawns every listed player on the
--    next fixed frame: the new class gets spawned before its packages exist,
--    and the synchronizer then spawns it a SECOND time -- native crash.
--    Answer "no" for a player whose package sync is still waiting to respawn
--    them. The synchronizer's own spawn passes force_spawn and is unaffected.
-- Required explicitly (same reason as the views above): the class table
-- must exist NOW for the hook to attach.
local ok_require_gmm, GameModeManagerClass = pcall(require, "scripts/managers/game_mode/game_mode_manager")

if not ok_require_gmm or type(GameModeManagerClass) ~= "table" then
	GameModeManagerClass = CLASS and CLASS.GameModeManager
end

local function package_respawn_pending(player)
	local manager = Managers.package_synchronization
	local host = manager and manager:synchronizer_host()
	local syncs = host and host._syncs
	local peer_syncs = syncs and syncs[player:peer_id()]
	local sync_data = peer_syncs and peer_syncs[player:local_player_id()]
	local changed = sync_data and sync_data.changed_profile_fields

	return changed ~= nil and changed.player_unit_respawn == true
end

mod:hook(GameModeManagerClass, "can_spawn_player", function(func, self, player, ...)
	if player and package_respawn_pending(player) then
		return false
	end

	return func(self, player, ...)
end)

-- ---------------------------------------------------------------------------
-- Psykhanium HUD rebuild: restore enemy health bars / damage numbers
-- ---------------------------------------------------------------------------
-- The health bar AND the damage numbers over a meat-grinder enemy are one
-- world marker ("damage_indicator"), registered by a ONE-SHOT event fired
-- when the enemy spawns (shooting_range_steps.lua). The live switch above
-- respawns the player unit, which makes HumanGameplay tear down and recreate
-- the whole HUD (its camera follow unit changed) — the fresh
-- HudElementWorldMarkers starts with an empty marker list and nothing in the
-- game re-registers enemies that are already standing, so their bars/numbers
-- are gone until each one dies and its replacement fires the event again.
-- Vanilla never hits this: it cannot change character mid-session. Fix:
-- remember which units got a damage_indicator marker, and after every HUD
-- (re)build in our own singleplay session re-fire the registration event for
-- the ones still alive.
--
-- Memory: the record is a weak-KEYED set of unit userdata with `true` values
-- — it pins nothing (despawned units fall out with GC; while alive the side
-- system holds strong refs, so entries cannot vanish early), and it is wiped
-- on every top-level game state change so nothing carries across sessions.
-- Both hooks are class hooks, no per-instance state. The re-added markers
-- themselves are owned by the vanilla element, which already removes them on
-- unit death (remove_on_death_duration) and on HUD destroy.
mod._damage_indicator_units = setmetatable({}, { __mode = "k" })

local function reset_switch_state(scope)
	mod._switch_epoch = mod._switch_epoch + 1
	mod._switch_request = nil
	mod._profile_refresh = nil
	mod._preset_commit = nil
	mod._preset_verify_elapsed = nil
	mod._preset_verify_min_delay = nil
	mod._preset_verify_deadline = nil
	mod._damage_indicator_units = setmetatable({}, { __mode = "k" })

	-- The armed switch and its presence work must survive destination loading.
	if scope ~= "transition" then
		mod._presence_reinit_retry = nil
		mod._presence_restart_pending = nil
		mod._presence_restart_cooldown = nil
		mod._target = nil
		mod._local_swap_character_id = nil
	end
end

mod.on_game_state_changed = function(status, state_name)
	reset_switch_state("transition")
end

local _ui_widget
local function ui_widget()
	if not _ui_widget then
		local ok, m = pcall(require, "scripts/managers/ui/ui_widget")
		if ok then
			_ui_widget = m
		end
	end
	return _ui_widget
end

local panel_views = setmetatable({}, { __mode = "k" })
local function hide_panel_widget(widget)
	local ok, err = pcall(function() widget.content.visible = false end)
	if not ok then log("Esc panel: cleanup failed: " .. tostring(err)) end
end

local function _clear_entries(view)
	local destroyed = {}
	local function destroy_entry(widget)
		if destroyed[widget] then return end
		destroyed[widget] = true
		hide_panel_widget(widget)
		local ok, err = pcall(function()
			ui_widget().destroy(view._ui_renderer, widget)
		end)
		if not ok then log("Esc panel: widget destroy failed: " .. tostring(err)) end
	end
	for name, widget in pairs(view._widgets_by_name or {}) do
		if name:match("^chs_entry_") then
			destroy_entry(widget)
			view._widgets_by_name[name] = nil
		end
	end
	for i = #(view._widgets or {}), 1, -1 do
		local widget = view._widgets[i]
		if widget.name and widget.name:match("^chs_entry_") then
			destroy_entry(widget)
			table.remove(view._widgets, i)
		end
	end
	view._chs_entries = nil
	view._chs_drag = nil
end

-- DMF removes hooks before on_disabled; invalidate callbacks before UI cleanup.
mod.on_disabled = function()
	reset_switch_state("disabled")
	for view in pairs(panel_views) do
		view._chs_generation = (view._chs_generation or 0) + 1
		_clear_entries(view)
		for name, widget in pairs(view._widgets_by_name or {}) do
			if name:match("^chs_") then hide_panel_widget(widget) end
		end
	end
end

-- Recorder. Cheap gate order: almost every registration that is not ours
-- fails the string compare. Our own re-fire below lands here too — harmless,
-- it re-inserts the same key.
mod:hook_safe(HudElementWorldMarkersClass or CLASS.HudElementWorldMarkers, "event_add_world_marker_unit", function(self, marker_type, unit)
	if marker_type == "damage_indicator" and unit and in_own_singleplay_session() then
		mod._damage_indicator_units[unit] = true
	end
end)

-- Replayer. The element registers its event listeners synchronously inside
-- UIHud:new (element packages are preloaded per mission), so when this hook
-- runs the fresh element is already listening and its marker list is empty —
-- the re-fire can neither arrive too early nor duplicate an existing marker.
mod:hook_safe(CLASS.UIManager, "create_player_hud", function(self)
	if not in_own_singleplay_session() then
		return
	end

	-- Snapshot first: the trigger re-enters the recorder hook above, and
	-- vanilla marker code may only be handed alive units.
	local units = {}
	for unit in pairs(mod._damage_indicator_units) do
		if HEALTH_ALIVE[unit] then
			units[#units + 1] = unit
		end
	end

	if #units == 0 then
		return
	end

	local ok = pcall(function()
		for i = 1, #units do
			Managers.event:trigger("add_world_marker_unit", "damage_indicator", units[i])
		end
	end)
	if ok then
		log(string.format("HUD rebuilt — restored damage indicators for %d meat grinder enemies", #units))
	else
		log("HUD rebuilt — could not restore meat grinder damage indicators")
	end
end)

-- The blocked server push (below) is ALSO the mechanism that normally
-- refreshes the local profile after a loadout/talent edit: the edit POSTs to
-- the backend, then the hub server re-fetches and pushes the result back.
-- With the push dropped, the local profile would stay stale forever — the
-- inventory would silently deselect the preset on reopen ("previewed item
-- not matching") and every downstream consumer would see the OLD build. So
-- whenever a push is dropped, fetch the TARGET character from the backend
-- ourselves and apply that instead — same data, right character.
-- One request record owns the fetch, queued edits and equip retry policy.
-- Edit bursts (items + talents commit as separate POSTs) share one trailing
-- fetch; successful equip healing leaves no active timer.
-- Reapplying a profile is only safe while we are actually STANDING in the
-- hub (game mode "hub" — false on every loading screen) and the party has no
-- allocated game session ("Departing"). Checked before fetching and again
-- before applying the response: a set_profile during hub teardown loads item /
-- portrait packages while the engine is unloading the hub ones — a native
-- refcount assertion no Lua pcall can catch (Nexus crash report). Both
-- conditions are needed: during the departing countdown the game mode is
-- still "hub" (the session check catches it), while the psykhanium
-- transition allocates no party session (the game-mode check catches it).
local function safe_to_reapply_profile()
	local safe = false

	pcall(function()
		safe = in_hub() and not Managers.party_immaterium:game_session_in_progress()
	end)

	return safe
end

local PROFILE_REFRESH_DELAY = 0.75
local REFRESH_MAX_ATTEMPTS = 3
local PROFILE_REFRESH_TIMEOUT = 15
local EQUIP_HEAL_QUIET_PERIOD = 30
local refresh_time = 0

local function refresh_identity()
	local ok, player, character_id = pcall(function()
		local player = Managers.player:local_player(1)
		local profile = player and player:profile()
		if not player or not profile or not profile.character_id then
			return nil, nil
		end
		return player, mod._local_swap_character_id or profile.character_id
	end)
	if ok and player and character_id then
		return player, character_id, true
	end
	return nil, nil, false
end

local function new_profile_refresh(player, character_id, heal_due)
	return { player = player, character_id = character_id, loadout_attempts = 0,
		heal_attempts = 0, next_heal_at = refresh_time, heal_due = heal_due }
end

-- All boundaries use the same identity transition. Equip demand belongs to
-- the local player's guard; edits and callbacks belong to one character.
local function align_refresh_identity(state, player, character_id)
	if not player or not character_id then
		return state
	end
	if not state or (state.player and state.player ~= player)
		or (state.character_id and state.character_id ~= character_id) then
		-- Unbound guard demand survives the first readable local identity.
		local heal = state and (not state.player or state.player == player) and (state.heal_due or state.inflight and state.inflight.heal)
		state = new_profile_refresh(player, character_id, heal and refresh_time or nil)
		mod._profile_refresh = state
	else
		state.player, state.character_id = player, character_id
	end
	return state
end

-- Every completion (including a rejected profile or unavailable session) goes
-- through one transition. Source demands and retry policy belong to the same
-- record; a new push cannot erase an equip demand attached to its fetch.
local function finish_profile_refresh(state, request, profile, err)
	if mod._profile_refresh ~= state or state.inflight ~= request then
		return
	end
	local player, character_id, identity_ok = refresh_identity()
	if identity_ok then
		local aligned = align_refresh_identity(state, player, character_id)
		if aligned ~= state then
			return
		end
	end

	local unavailable = not identity_ok or not safe_to_reapply_profile()
	local discarded = not err and (unavailable or request.swap_id ~= mod._local_swap_character_id
		or not profile or profile.character_id ~= character_id)
	if not err and not discarded then
		-- Keep the token through set_profile and the event: either may trigger
		-- another nil-item equip synchronously. Earlier equip demands are
		-- captured at dispatch are satisfied; later demands remain queued.
		request.applying = true
		local applied, apply_err = pcall(function()
			player:set_profile(profile)
			Managers.event:trigger("event_player_profile_updated", player:peer_id(), player:local_player_id(), profile)
		end)
		request.applying = nil
		if not applied then
			err = apply_err or "profile apply failed"
		end
	end
	if mod._profile_refresh ~= state or state.inflight ~= request then
		return
	end
	state.inflight = nil

	-- A response blocked by transient readiness did not get a chance to heal.
	if discarded and unavailable then
		if request.heal then state.heal_attempts = math.max(0, state.heal_attempts - 1) end
		if request.loadout then state.loadout_attempts = math.max(0, state.loadout_attempts - 1) end
	end

	if not err and not discarded then
		if request.heal and not request.heal_failed_during_apply then
			state.heal_attempts = 0
		end
		log("Local profile refreshed from backend")
	else
		if request.heal and not state.heal_due and state.heal_attempts < REFRESH_MAX_ATTEMPTS then
			state.heal_due = math.max(refresh_time + PROFILE_REFRESH_DELAY, state.next_heal_at)
		end
		-- Retry failed and discarded responses alike, within each source budget.
		-- Never carry an old character's edit to a new one.
		if request.loadout and not state.loadout_due and state.loadout_attempts < REFRESH_MAX_ATTEMPTS then
			state.loadout_due = math.max(refresh_time + PROFILE_REFRESH_DELAY, request.loadout_retry_at)
		end
		log(err and ("Backend profile refresh failed: " .. tostring(err))
			or "Local profile refresh discarded — identity changed or profile reapply is unavailable")
	end
end

-- Only demand entry points and update dispatch work; completion never dispatches.
local function start_profile_refresh(state)
	if mod._profile_refresh ~= state or state.inflight or (state.ready_at and refresh_time < state.ready_at) then
		return
	end
	local loadout_due = state.loadout_due and state.loadout_due <= refresh_time
	local heal_due = state.heal_due and state.heal_due <= refresh_time
	if not loadout_due and not heal_due then
		return
	end

	local player, character_id, identity_ok = refresh_identity()
	if not identity_ok then
		state.ready_at = refresh_time + 2
		return
	end
	local aligned = align_refresh_identity(state, player, character_id)
	if aligned ~= state then
		state = aligned
		loadout_due = state.loadout_due and state.loadout_due <= refresh_time
		heal_due = state.heal_due and state.heal_due <= refresh_time
		if not loadout_due and not heal_due then return end
	end

	-- Readiness is not a backend attempt: retain work until departure is
	-- cancelled, or session cleanup invalidates the record. Poll slowly.
	if not safe_to_reapply_profile() then
		state.ready_at = refresh_time + 2
		return
	end
	state.ready_at = nil

	local request = { swap_id = mod._local_swap_character_id, heal = heal_due, loadout = loadout_due,
		deadline = refresh_time + PROFILE_REFRESH_TIMEOUT }
	state.inflight = request
	if heal_due then
		state.heal_due = nil
	end
	if loadout_due then
		state.loadout_due = nil
	end
	if request.loadout then
		state.loadout_attempts = state.loadout_attempts + 1
		request.loadout_retry_at = refresh_time + 2 ^ math.min(state.loadout_attempts - 1, 2)
	end
	if request.heal then
		state.heal_attempts = state.heal_attempts + 1
		state.next_heal_at = refresh_time + 2 ^ math.min(state.heal_attempts - 1, 2)
	end

	local ok, err = pcall(function()
		request.promise = Managers.data_service.profiles:fetch_profile(character_id)
		request.promise:next(function(profile)
			finish_profile_refresh(state, request, profile)
		end):catch(function(fetch_err)
			finish_profile_refresh(state, request, nil, fetch_err or "profile fetch rejected")
		end)
	end)
	if not ok then
		finish_profile_refresh(state, request, nil, err or "profile fetch failed")
	end
end

local function request_local_profile_refresh(source)
	local player, character_id, identity_ok = refresh_identity()
	local state = mod._profile_refresh
	if identity_ok then
		state = align_refresh_identity(state, player, character_id)
	elseif not state then
		state = new_profile_refresh(nil, mod._local_swap_character_id)
		mod._profile_refresh = state
	end
	if source == "loadout" then
		state.loadout_due = refresh_time + PROFILE_REFRESH_DELAY
		state.loadout_attempts = 0
	else
		if state.inflight and state.inflight.applying then
			state.inflight.heal_failed_during_apply = true
		end
		-- Completed work has no due time and incurs no per-frame timer work.
		-- Keep only a short burst limit, reset lazily after a quiet period.
		if not state.last_equip_at or refresh_time - state.last_equip_at >= EQUIP_HEAL_QUIET_PERIOD then
			state.heal_attempts = 0
			state.next_heal_at = refresh_time
		end
		state.last_equip_at = refresh_time
		if state.heal_attempts < REFRESH_MAX_ATTEMPTS then
			state.heal_due = state.heal_due or math.max(refresh_time, state.next_heal_at)
		end
	end
	start_profile_refresh(state)
end

-- Anti-revert guard for the Esc-menu hub swap. The hub server re-fetches
-- and pushes OUR profile after every loadout/talent edit
-- (rpc_notify_profile_changed -> profile_changed -> sync_player_profile ->
-- this RPC applies it via player:set_profile). It only knows the character we
-- CONNECTED with, so while the local swap is active those pushes would
-- overwrite the swapped profile — drop them and refresh from the backend
-- instead (see above). Pushes for other players, and pushes that already
-- carry the right character, pass through untouched.
mod:hook(CLASS.ProfileSynchronizerClient, "rpc_profile_synced_by_all", function(func, self, channel_id, peer_id, local_player_id, ...)
	local guard_id = mod._local_swap_character_id

	if guard_id and peer_id == Network.peer_id() then
		local ok, incoming_id = pcall(function()
			local PU = profile_utils()
			local profile_json = self._peer_profiles_json[peer_id][local_player_id]
			local profile = PU.unpack_profile(profile_json)

			return profile.character_id
		end)

		if ok and incoming_id and incoming_id ~= guard_id then
			log("Blocked a hub server profile push for old character " .. tostring(incoming_id) .. " (local swap active) — refreshing from backend instead")

			-- Mirror the "waiting for loadout" decrement the real push would
			-- have performed, so the inventory input never freezes until its
			-- internal timeout.
			pcall(function()
				Managers.ui:update_client_loadout_waiting_state(false)
			end)

			-- Debounced: pushes arriving within the window (items + talents
			-- commit as separate POSTs, each causing one push) collapse into
			-- a single backend fetch — less traffic and less Lua garbage.
			request_local_profile_refresh("loadout")

			return
		end
	end

	return func(self, channel_id, peer_id, local_player_id, ...)
end)

-- Back in the main menu the game manages character selection itself; an armed
-- switch would fight it. Disarm silently.
mod:hook_safe(CLASS.StateMainMenu, "on_enter", function()
	if mod._target then
		log("Switch disarmed (entered main menu): " .. tostring(mod._target.label))
	end
	reset_switch_state("main_menu")
end)

-- ---------------------------------------------------------------------------
-- Log-only taps on the queue tickets, so a backend rejection is attributable:
-- the ticket request logs the characterId actually sent, and the promise
-- errors are already logged by the game (party_immaterium logs) / our echo.
-- ---------------------------------------------------------------------------

mod:hook_safe(CLASS.Matchmaker, "fetch_queue_ticket_mission", function(self, mission_id, character_id, private_session)
	log(string.format("queue ticket (mission %s, private=%s) sent with characterId=%s",
		tostring(mission_id), tostring(private_session), tostring(character_id)))
end)

mod:hook_safe(CLASS.Matchmaker, "fetch_queue_ticket_mission_hotjoin", function(self, matched_game_session_id, character_id)
	log(string.format("queue ticket (hot-join session %s) sent with characterId=%s",
		tostring(matched_game_session_id), tostring(character_id)))
end)

mod:hook_safe(CLASS.Matchmaker, "fetch_queue_ticket_single_player", function(self, mission_id, character_id)
	log(string.format("queue ticket (single player %s) sent with characterId=%s",
		tostring(mission_id), tostring(character_id)))
end)

-- ---------------------------------------------------------------------------
-- Mission terminal: difficulty / mission unlocks follow the switch
--
-- The terminal gates difficulties and missions by the player-journey blob
-- (difficulty progress + unlocked missions + quickplay), fetched per
-- CHARACTER but cached as ONE global blob with no owner recorded
-- (backend/mission_board.lua: _cached_progression_data). Vanilla only
-- force-refreshes it on hub load (mechanism_hub) — safe there, because a
-- vanilla character change always reloads the hub; the terminal itself
-- always fetches with force_refresh=false and eats whatever is cached.
-- After a mod switch there is no hub reload, so the terminal kept showing
-- the ORIGINAL character's unlocks (Nexus bug report).
--
-- Hooked at the BACKEND interface rather than the service wrapper so every
-- caller lands here: the mission terminal, the Mortis Trials terminal (its
-- expedition service routes through the same cache) and the backend's own
-- internal refetch after a campaign skip. Two adjustments:
--   * the fetch is re-pointed at the character actually being PLAYED (armed
--     target, else the current profile) — while a switch is merely armed the
--     queue tickets already go out as the target, so the terminal must gate
--     by the target too;
--   * when the cached blob was built for a different character it is
--     force-refreshed (the game's own clear+refetch path, so the service's
--     progression rebuild still runs). When nothing changed the cache is
--     served exactly as in vanilla — zero extra backend traffic.
-- ---------------------------------------------------------------------------

mod:hook(CLASS.MissionBoard, "fetch_player_journey_data", function(func, self, account_id, character_id, force_refresh)
	local target = mod._target
	local profile = not target and real_local_profile() or nil
	local desired_id = target and target.character_id or profile and profile.character_id or character_id

	if desired_id ~= character_id then
		log(string.format("Journey data: fetching for character %s instead of %s (mission terminal follows the switch)",
			tostring(desired_id), tostring(character_id)))
	end

	if force_refresh == false and self.__chs_journey_cache_character_id ~= desired_id then
		force_refresh = true

		log("Journey data: cached unlocks belong to another character — forcing a backend refresh")
	end

	local result = func(self, account_id, desired_id, force_refresh)
	if not result then
		return result
	end
	return result:next(function(value)
		-- Vanilla writes the cache before resolving and returns nil on success,
		-- but resolves with BackendError on failure. Track the last writer,
		-- not the last request: replies can arrive in either order.
		if value == nil and self._cached_progression_data then
			self.__chs_journey_cache_character_id = desired_id
		end
		return value
	end)
end)

-- The "new difficulty unlocked" toast (onboarding template "Player Journey -
-- Mission Board Tier Up") polls this every frame for the CURRENT player's
-- character and answers it by comparing that character's highest-difficulty
-- tracker against the GLOBAL journey blob — again assuming the blob belongs
-- to the current character. Between a switch and the next terminal-open
-- refresh it does not, so the toast misfired (for a fresh character's
-- "uprising" even with an unshipped loc string, since vanilla can never
-- newly-unlock uprising), and its activation then corrupted the tracker with
-- the other character's difficulty via reset_cached_highest_difficulty. The
-- question "did THIS character unlock something new?" is only answerable
-- while the blob is that character's — otherwise the answer is no. Real
-- unlocks still fire: after a mission the hub reload refetches the blob for
-- the character who played it.
mod:hook(CLASS.MissionBoard, "get_new_difficulty_unlocked", function(func, self, character_id)
	local blob_owner_id = self.__chs_journey_cache_character_id

	if not self._cached_progression_data or character_id ~= blob_owner_id then
		return false
	end

	return func(self, character_id)
end)

-- ---------------------------------------------------------------------------
-- Preset guard: direct-to-backend loadout preset commit
--
-- The vanilla "preset did not apply" bug is a race inside the inventory
-- view: applying a preset resolves its items through the view's inventory
-- list (_get_item), and the commit on close is skipped entirely unless that
-- list finished syncing (on_exit gates on is_inventory_synced()). Click a
-- preset before the list has loaded — or close the view too fast — and the
-- change silently evaporates; the game then even deselects the preset at the
-- next open because the profile does not match it.
--
-- Only an explicit preset activation in the local inventory authorizes a
-- repair. Opening the view is not an activation. After close, compare the
-- profile against a snapshot of that preset; discard the request if its
-- character, active preset or saved contents changed. Reopening the editor
-- pauses repair until it closes again. An unrelated mismatch is left to the
-- game's normal deselection behavior.
-- ---------------------------------------------------------------------------

-- Slots that define a build. Cosmetic slots are excluded on purpose: the
-- game rewrites preset cosmetic entries to match the backend, so committing
-- them could push stale gear ids.
local BUILD_SLOTS = {
	slot_primary = true,
	slot_secondary = true,
	slot_attachment_1 = true,
	slot_attachment_2 = true,
	slot_attachment_3 = true,
}

-- preset.talents and profile.selected_nodes are both maps of talent tree
-- node widget_name -> points spent, directly comparable. (profile.talents is
-- NOT comparable: talent-name-keyed + auto-granted archetype base talents.)
local function _talent_maps_equal(a, b)
	a = a or {}
	b = b or {}

	for k, v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end

	for k, v in pairs(b) do
		if a[k] ~= v then
			return false
		end
	end

	return true
end

-- min_delay: small grace period before the first check (lets the game's
-- close-commit START, so the waiting flag is already up if it is coming).
-- max_wait: hard deadline — verify even if the waiting flag never clears
-- (a lost round-trip is exactly the failure being repaired).
local function schedule_preset_commit(view, reason, min_delay, max_wait)
	local ok = pcall(function()
		local PU = profile_utils()
		local preset_id = PU and PU.get_active_profile_preset_id()

		if not preset_id then
			return
		end
		local preset = PU.get_profile_preset(preset_id)
		if not preset then
			return
		end
		local profile = real_local_profile()
		local previous = view.__chs_pending_preset
		local character_id = profile and profile.character_id
			or (previous and previous.epoch == mod._switch_epoch and previous.character_id)
		if not character_id then
			log("Preset guard: could not schedule a commit — character identity unavailable", true)
			return
		end
		local resumed = previous and previous.epoch == mod._switch_epoch
			and previous.character_id == character_id and previous.preset_id == preset_id
			and _talent_maps_equal(previous.loadout, preset.loadout)
			and _talent_maps_equal(previous.talents, preset.talents)
		if view.__chs_preset_intent ~= preset_id and not resumed then
			return
		end

		mod._preset_commit = {
			epoch = mod._switch_epoch,
			loadout = table.clone(preset.loadout or {}),
			talents = table.clone(preset.talents or {}),
			preset_id = preset_id,
			character_id = character_id,
			reason = reason,
		}
		mod._preset_verify_elapsed = 0
		mod._preset_verify_min_delay = min_delay or 0.4
		mod._preset_verify_deadline = max_wait or 5.0
	end)
	if not ok then
		log("Preset guard: could not schedule a commit")
	end
end

local function direct_commit_preset()
	local pending = mod._preset_commit

	mod._preset_commit = nil

	if not pending then
		return
	end

	if not in_hub() and not in_own_singleplay_session() then
		return
	end

	local ok, err = pcall(function()
		local PU = profile_utils()
		local readable, player, profile = pcall(function()
			local player = Managers.player:local_player(1)
			return player, player and player:profile()
		end)
		local preset = PU and PU.get_profile_preset(pending.preset_id)

		if not readable or not profile then
			if pending.epoch == mod._switch_epoch
				and (mod._preset_verify_elapsed or 0) < (mod._preset_verify_deadline or 5.0) then
				mod._preset_commit = pending
			else
				log("Preset guard: commit expired — profile unavailable", true)
			end
			return
		end
		if not preset or pending.epoch ~= mod._switch_epoch
			or PU.get_active_profile_preset_id() ~= pending.preset_id
			or not _talent_maps_equal(preset.loadout, pending.loadout)
			or not _talent_maps_equal(preset.talents, pending.talents) then
			return
		end

		-- Stale request from before a character switch.
		if profile.character_id ~= pending.character_id then
			return
		end

		-- ITEMS: gear ids straight from the preset save data.
		local wrong_slots = {}
		local wrong_count = 0
		local equipped = profile.loadout_item_ids or {}

		for slot_name, gear_id in pairs(preset.loadout or {}) do
			if BUILD_SLOTS[slot_name] and gear_id and equipped[slot_name] ~= gear_id then
				wrong_slots[slot_name] = gear_id
				wrong_count = wrong_count + 1
			end
		end

		if wrong_count > 0 then
			log("Preset guard (" .. tostring(pending.reason) .. "): committing " .. tostring(wrong_count) .. " item slot(s) directly to backend", true)
			Managers.data_service.profiles:equip_items_in_slots(profile.character_id, wrong_slots, {}):next(function()
				-- Same follow-up the game does after an equip: nudges the
				-- server refetch (or, with an active hub swap, our own
				-- refresh path).
				local ok_notify, notified = pcall(function()
					if pending.epoch ~= mod._switch_epoch or Managers.player:local_player(1) ~= player
						or player:character_id() ~= pending.character_id then
						return false
					end
					if Managers.connection:is_host() then
						local host = Managers.profile_synchronization:synchronizer_host()

						if host then
							host:profile_changed(player:peer_id(), player:local_player_id())
							return true
						end
					else
						Managers.connection:send_rpc_server("rpc_notify_profile_changed", player:local_player_id())
						return true
					end
				end)
				if ok_notify and notified then
					log("Preset guard: items saved to backend; server refresh requested", true)
				else
					log("Preset guard: items saved to backend; server refresh not requested", true)
				end
			end):catch(function(equip_err)
				log("Preset guard: item commit FAILED: " .. tostring(equip_err), true)
			end)
		end

		-- TALENTS: node map straight from the preset save data.
		-- Newly created presets also have talents = {}. An empty map is not
		-- evidence that the user requested a reset. Unknown profile schemas
		-- must not authorize a speculative talent write either.
		local preset_talents = preset.talents
		local can_check_talents = type(preset_talents) == "table" and next(preset_talents) ~= nil
			and type(profile.selected_nodes) == "table"
		local talents_match = can_check_talents and _talent_maps_equal(profile.selected_nodes, preset_talents)

		if can_check_talents and not talents_match then
			log("Preset guard (" .. tostring(pending.reason) .. "): committing talents directly to backend", true)

			local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
			local archetype = profile.archetype
			local talent_info, specialization_talent_info

			if archetype.talent_layout_file_path then
				talent_info = {
					layout = require(archetype.talent_layout_file_path),
					node_tiers = TalentLayoutParser.filter_layout_talents(profile, "talent_layout_file_path", preset_talents),
				}
			end

			if archetype.specialization_talent_layout_file_path then
				specialization_talent_info = {
					layout = require(archetype.specialization_talent_layout_file_path),
					node_tiers = TalentLayoutParser.filter_layout_talents(profile, "specialization_talent_layout_file_path", preset_talents),
				}
			end

			if talent_info or specialization_talent_info then
				Managers.data_service.talents:set_talents_v2(player, talent_info, specialization_talent_info)
			end
		end

		if wrong_count == 0 then
			if talents_match then
				log("Preset guard: profile already matches preset '" .. tostring(preset.name or pending.preset_id) .. "'")
			elseif not can_check_talents then
				log("Preset guard: items already match; talents not checked (empty preset or unknown profile schema)")
			end
		end
	end)
	if not ok then
		log("Preset guard: commit errored: " .. tostring(err), true)
	end
end

if InventoryBackgroundViewClass then
	mod:hook_safe(InventoryBackgroundViewClass, "on_enter", function(self)
		if not self._is_readonly and self._is_own_player then
			self.__chs_pending_preset = mod._preset_commit
			mod._preset_commit = nil
		end
	end)

	-- Only an explicit preset activation authorizes repair. Vanilla also calls
	-- this event directly during setup; those calls are not user selections.
	mod:hook_safe(InventoryBackgroundViewClass, "event_on_profile_preset_changed", function(self, preset, on_preset_deleted)
		if self.__chs_setting_up_presets or self._is_readonly or not self._is_own_player then
			return
		end
		self.__chs_preset_intent = not on_preset_deleted and preset and preset.id or nil
		local profile = real_local_profile()
		self.__chs_pending_preset = self.__chs_preset_intent and profile and profile.character_id and {
			epoch = mod._switch_epoch, character_id = profile.character_id, preset_id = preset.id,
			loadout = table.clone(preset.loadout or {}), talents = table.clone(preset.talents or {}),
		} or nil
		mod._preset_commit = nil
	end)

	mod:hook(InventoryBackgroundViewClass, "_setup_profile_presets", function(func, self, ...)
		local PU = profile_utils()
		local pending = self.__chs_pending_preset or mod._preset_commit
		self.__chs_pending_preset = nil
		local profile = real_local_profile()
		local active_id = PU and PU.get_active_profile_preset_id()
		local preset = active_id and PU.get_profile_preset(active_id)
		local resume = not self._is_readonly and self._is_own_player and pending
			and pending.epoch == mod._switch_epoch and profile
			and pending.character_id == profile.character_id and pending.preset_id == active_id
			and preset and _talent_maps_equal(preset.loadout, pending.loadout)
			and _talent_maps_equal(preset.talents, pending.talents)
		self.__chs_pending_preset = resume and pending or nil
		if not self._is_readonly and self._is_own_player then
			-- A reopened editor owns the next commit; the old timer must not
			-- write while the user is making new changes.
			mod._preset_commit = nil
			self.__chs_preset_intent = (resume or self.__chs_preset_intent == active_id) and active_id or nil
		end
		self.__chs_setting_up_presets = true
		self.__chs_block_preset_deselect = not self._is_readonly and self._is_own_player
			and active_id and self.__chs_preset_intent == active_id or nil
		local results = { pcall(func, self, ...) }
		self.__chs_setting_up_presets = nil
		self.__chs_block_preset_deselect = nil
		if not results[1] then
			error(results[2])
		end
		return unpack(results, 2)
	end)

	-- Single trigger: inventory close.
	mod:hook(InventoryBackgroundViewClass, "on_exit", function(func, self, ...)
		local own_player = false
		local skipped = false

		pcall(function()
			own_player = not self._is_readonly and self._is_own_player
			skipped = own_player and not self:is_inventory_synced()
		end)

		if skipped and self.__chs_preset_intent then
			-- The game is about to skip its ENTIRE commit (closed before the
			-- item list synced) — nothing to wait for. Talents do not depend
			-- on that list, commit them right away; items follow via the
			-- direct preset commit almost immediately.
			log("Inventory closed before its item sync finished — the game skipped its commit; committing directly", true)

			pcall(function()
				self:_apply_current_talents_to_profile()
			end)

			schedule_preset_commit(self, "game skipped commit on close", 0.15, 3.0)
		elseif own_player then
			-- Normal close: the game's own commit is on its way. Verify the
			-- moment its round-trip settles (the waiting flag is polled every
			-- frame) — the comparison is purely local (save data vs profile),
			-- so when the game's path worked this costs ZERO backend requests.
			schedule_preset_commit(self, "verify after close", 0.4, 5.0)
		end

		return func(self, ...)
	end)
else
	mod:error("[InstantCharacterChange] Could not load the inventory view class — the preset guard is disabled (game update?)")
end

if ViewElementProfilePresetsClass then
	-- The mismatch-driven deselect during inventory setup (see above). Only
	-- suppressed while the flag is up — deleting a preset and every other
	-- legitimate path goes through untouched.
	mod:hook(ViewElementProfilePresetsClass, "remove_active_profile_preset", function(func, self, ...)
		local parent = self._parent

		if parent and parent.__chs_block_preset_deselect then
			log("Preset guard: blocked a transient preset deselect during inventory setup")

			return
		end

		if parent then
			parent.__chs_preset_intent = nil
		end
		return func(self, ...)
	end)
end

-- ---------------------------------------------------------------------------
-- Update loop: debounced backend refresh + preset guard timing
-- ---------------------------------------------------------------------------

mod.update = function(dt)
	dt = dt or 0

	refresh_time = refresh_time + dt
	local refresh = mod._profile_refresh
	if refresh and refresh.inflight and refresh_time >= refresh.inflight.deadline then
		local request = refresh.inflight
		-- Promise.cancel only releases callbacks; the service exposes no HTTP cancellation.
		pcall(function()
			if request.promise and request.promise.cancel then request.promise:cancel() end
		end)
		finish_profile_refresh(refresh, request, nil, "profile fetch timed out")
	end
	refresh = mod._profile_refresh
	if refresh and not refresh.inflight and (refresh.loadout_due or refresh.heal_due) then
		start_profile_refresh(refresh)
	end

	-- Preset guard: verify/commit as soon as the game's own equip round-trip
	-- settles. The loadout-waiting flag is polled every frame (a cheap
	-- getter); the verify fires the moment it clears — or at the hard
	-- deadline if it never does (a lost round-trip is exactly the failure
	-- being repaired).
	if mod._preset_commit then
		mod._preset_verify_elapsed = (mod._preset_verify_elapsed or 0) + dt

		if mod._preset_verify_elapsed >= (mod._preset_verify_min_delay or 0.4) then
			local busy = false

			pcall(function()
				busy = Managers.ui:get_client_loadout_waiting_state()
			end)

			if not busy or mod._preset_verify_elapsed >= (mod._preset_verify_deadline or 5.0) then
				direct_commit_preset()
			end
		end
	end

	-- Presence-restart debounce. When it expires with a deferred restart
	-- queued, fire that restart with whoever we are/armed as by now — rapid
	-- re-switching thus ends on the correct character.
	if mod._presence_restart_cooldown then
		mod._presence_restart_cooldown = mod._presence_restart_cooldown - dt

		if mod._presence_restart_cooldown <= 0 then
			mod._presence_restart_cooldown = nil

			local reason = mod._presence_restart_pending

			if reason then
				mod._presence_restart_pending = nil

				local target = mod._target
				local profile = target and target.profile or real_local_profile()

				force_presence_readvertise(profile, reason)
			end
		end
	end

	-- One-shot safety net for the restart: if the re-init threw and left us
	-- with no stream (we would stay presence-offline until relog, like
	-- AppearOffline's /offline), try once more a second later. A live stream
	-- or an intentional AppearOffline state makes this a no-op.
	if mod._presence_reinit_retry then
		mod._presence_reinit_retry = mod._presence_reinit_retry - dt

		if mod._presence_reinit_retry <= 0 then
			mod._presence_reinit_retry = nil

			pcall(function()
				local pm = Managers.presence

				if pm and pm._initialized and not pm._my_presence_stream and not appear_offline_active() then
					pm:_init_immaterium_presence()
					log("Presence: stream was still down after the restart — re-init retried", true)
				end
			end)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Esc-menu character panel
--
-- A panel to the right of the system (Esc) menu, one entry per character:
-- class icon, name, class + level. Clicking an entry performs the INSTANT
-- switch without a Mourningstar reload and closes the menu.
-- Dragging an entry (press, move, release) reorders the list; the order is
-- saved between sessions.
-- Only shown where switching works: hub and Psykhanium.
--
-- Integration technique: the panel's scenegraph nodes and static widgets are
-- injected into the view's DEFINITIONS via hook_require, so the view builds,
-- draws and destroys them natively; per-character entries are created with
-- the view's own _create_widget at open time. (Custom draw-hook approaches
-- proved unreliable.)
-- ---------------------------------------------------------------------------


-- Geometry. PANEL_W is the scenegraph NODE width baked into the definitions;
-- the drawn width comes from the "panel_width" mod setting and is applied to
-- the widgets at build time (the node only anchors the right edge, drawing
-- is not clipped by it).
local PANEL_W = 430
local PANEL_MAX_H = 860
local PANEL_MARGIN_RIGHT = 48
local HEADER_H = 42
local ENTRY_H = 56
local ENTRY_GAP = 5
local ENTRY_ICON_SIZE = 40
local ENTRY_TEXT_X = 68

-- All size-dependent values in one place, scaled by the "panel_scale" mod
-- setting (percent). Entry widgets are rebuilt on every menu open, so the
-- scale applies immediately on the next open.
local function panel_layout()
	local scale = math.clamp(tonumber(mod:get("panel_scale")) or 100, 70, 200) / 100

	return {
		width = math.clamp(tonumber(mod:get("panel_width")) or PANEL_W, 340, 600),
		header_h = math.floor(HEADER_H * scale + 0.5),
		header_font = math.floor(21 * scale + 0.5),
		entry_h = math.floor(ENTRY_H * scale + 0.5),
		gap = math.max(math.floor(ENTRY_GAP * scale + 0.5), 2),
		icon_font = math.floor(30 * scale + 0.5),
		icon_box = math.floor(ENTRY_ICON_SIZE * scale + 0.5),
		icon_x = math.floor(14 * scale + 0.5),
		text_x = math.floor(ENTRY_TEXT_X * scale + 0.5),
		name_font = math.floor(19 * scale + 0.5),
		name_y = math.floor(8 * scale + 0.5),
		sub_font = math.floor(14 * scale + 0.5),
	}
end

-- Palette {alpha, r, g, b}: cool steel-blue accent on near-black, in contrast
-- to the game's amber terminal look.
local C_PANEL_BG = { 205, 11, 13, 16 }
local C_ACCENT = { 255, 96, 148, 178 }
local C_ACCENT_DIM = { 90, 96, 148, 178 }
local C_HOVER_BG = { 70, 58, 88, 108 }
local C_TITLE = { 255, 208, 218, 228 }
local C_NAME = { 255, 224, 229, 234 }
local C_NAME_CURRENT = { 255, 148, 195, 228 }
local C_SUB = { 255, 138, 148, 158 }

-- Class icons are FONT GLYPHS (UISettings.archetype_font_icon), not texture
-- materials, on purpose: texture materials would create gui material
-- instances referencing resources owned by OTHER views' packages (group
-- finder / main menu load the class icon materials), and a package unload
-- while such an instance is alive trips the engine's refcount assert
-- ("Trying to unload resource that's used elsewhere"). Font glyphs are part
-- of the always-loaded UI font — zero resource management.
local _ui_settings
local function ui_settings()
	if not _ui_settings then
		local ok, m = pcall(require, "scripts/settings/ui/ui_settings")
		if ok then
			_ui_settings = m
		end
	end
	return _ui_settings
end

local function _class_glyph(profile)
	local archetype = profile and profile.archetype
	local name = type(archetype) == "table" and archetype.name or tostring(archetype or "")
	local settings = ui_settings()
	local glyphs = settings and settings.archetype_font_icon

	return glyphs and glyphs[name] or ""
end

local function _make_entry_definition(profile, is_current, layout)
	local UIWidget = ui_widget()
	local passes = {
		{
			pass_type = "hotspot",
			content_id = "hotspot",
		},
		-- Hover fill.
		{
			pass_type = "rect",
			style_id = "hover_bg",
			style = {
				color = { 0, C_HOVER_BG[2], C_HOVER_BG[3], C_HOVER_BG[4] },
			},
			change_function = function(content, style)
				local hotspot = content.hotspot
				local progress = hotspot and hotspot.anim_hover_progress or 0

				if content.is_current then
					progress = 0
				end

				style.color[1] = math.floor(C_HOVER_BG[1] * progress)
			end,
		},
		-- Accent bar on the left edge: solid for the current character,
		-- hover-driven for the rest.
		{
			pass_type = "rect",
			style_id = "accent_bar",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				size = { 3, layout.entry_h - 8 },
				offset = { 0, 0, 3 },
				color = { is_current and C_ACCENT[1] or 0, C_ACCENT[2], C_ACCENT[3], C_ACCENT[4] },
			},
			change_function = function(content, style)
				if content.is_current then
					return
				end

				local hotspot = content.hotspot
				local progress = hotspot and hotspot.anim_hover_progress or 0

				style.color[1] = math.floor(220 * progress)
			end,
		},
		-- Class icon (font glyph — see note above _class_glyph).
		{
			pass_type = "text",
			style_id = "class_icon",
			value_id = "class_icon",
			style = {
				font_type = "proxima_nova_bold",
				font_size = layout.icon_font,
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				size = { layout.icon_box, layout.entry_h },
				offset = { layout.icon_x, 0, 2 },
				text_color = { is_current and 235 or 150, 255, 255, 255 },
			},
			change_function = function(content, style)
				if content.is_current then
					return
				end

				local hotspot = content.hotspot
				local progress = hotspot and hotspot.anim_hover_progress or 0

				style.text_color[1] = math.floor(150 + 85 * progress)
			end,
		},
		-- Character name.
		{
			pass_type = "text",
			style_id = "name",
			value_id = "name",
			style = {
				font_type = "proxima_nova_bold",
				font_size = layout.name_font,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				offset = { layout.text_x, layout.name_y, 2 },
				text_color = is_current and C_NAME_CURRENT or C_NAME,
			},
		},
		-- Class + level subtitle.
		{
			pass_type = "text",
			style_id = "sub",
			value_id = "sub",
			style = {
				font_type = "proxima_nova_bold",
				font_size = layout.sub_font,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { layout.text_x, -layout.name_y, 2 },
				text_color = C_SUB,
			},
		},
		-- Thin divider under the entry.
		{
			pass_type = "rect",
			style_id = "divider",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "bottom",
				size = { layout.width - 32, 1 },
				offset = { 0, layout.gap - 1, 1 },
				color = { 55, 96, 148, 178 },
			},
		},
	}

	return UIWidget.create_definition(passes, "chs_list", {
		hotspot = {},
		name = "",
		sub = "",
		class_icon = _class_glyph(profile),
		is_current = is_current,
	}, {
		layout.width,
		layout.entry_h,
	})
end

-- Static panel chrome: background plate, top accent line, header title.
local function _make_bg_definition()
	local UIWidget = ui_widget()

	return UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "plate",
			style = {
				vertical_alignment = "top",
				size = { PANEL_W, PANEL_MAX_H },
				offset = { 0, 0, 0 },
				color = C_PANEL_BG,
			},
		},
		{
			pass_type = "rect",
			style_id = "top_line",
			style = {
				vertical_alignment = "top",
				size = { PANEL_W, 2 },
				offset = { 0, 0, 2 },
				color = C_ACCENT,
			},
		},
		{
			pass_type = "rect",
			style_id = "bottom_line",
			style = {
				vertical_alignment = "top",
				size = { PANEL_W, 1 },
				offset = { 0, PANEL_MAX_H, 2 },
				color = C_ACCENT_DIM,
			},
		},
	}, "chs_root", { visible = false })
end

local function _make_header_definition()
	local UIWidget = ui_widget()

	return UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "title",
			value_id = "text",
			style = {
				font_type = "proxima_nova_bold",
				font_size = 21,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				offset = { 16, 0, 3 },
				text_color = C_TITLE,
			},
		},
	}, "chs_header", {
		visible = false,
		text = "",
	})
end

-- Inject scenegraph nodes + static widgets into the Esc menu's definitions,
-- so the view itself owns them (built, drawn and destroyed natively).
mod:hook_require("scripts/ui/views/system_view/system_view_definitions", function(definitions)
	definitions.scenegraph_definition.chs_root = {
		parent = "screen",
		horizontal_alignment = "right",
		vertical_alignment = "center",
		size = { PANEL_W, PANEL_MAX_H },
		position = { -PANEL_MARGIN_RIGHT, 0, 10 },
	}
	definitions.scenegraph_definition.chs_header = {
		parent = "chs_root",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { PANEL_W, HEADER_H },
		position = { 0, 2, 1 },
	}
	definitions.scenegraph_definition.chs_list = {
		parent = "chs_root",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { PANEL_W, PANEL_MAX_H - HEADER_H },
		position = { 0, HEADER_H + 6, 1 },
	}

	definitions.widget_definitions.chs_bg = _make_bg_definition()
	definitions.widget_definitions.chs_header = _make_header_definition()
end)

local function _set_panel_chrome_visible(view, visible)
	local by_name = view._widgets_by_name

	if by_name and by_name.chs_bg then
		by_name.chs_bg.content.visible = visible
	end

	if by_name and by_name.chs_header then
		by_name.chs_header.content.visible = visible
	end
end

-- Fit the panel chrome to the actual content (height from the character
-- count, width from the mod setting) and apply the user position offsets to
-- the scenegraph node. The node is right-aligned, so the x position is
-- compensated by the width delta to keep the right edge anchored.
local function _fit_panel_chrome(view, count, layout)
	local width = layout.width
	local content_h = layout.header_h + 6 + count * (layout.entry_h + layout.gap) + 12
	local widget = view._widgets_by_name and view._widgets_by_name.chs_bg

	if widget then
		widget.style.plate.size[1] = width
		widget.style.plate.size[2] = content_h
		widget.style.top_line.size[1] = width
		widget.style.bottom_line.size[1] = width
		widget.style.bottom_line.offset[2] = content_h
	end

	local header = view._widgets_by_name and view._widgets_by_name.chs_header

	if header then
		header.style.title.font_size = layout.header_font
	end

	pcall(function()
		local offset_x = tonumber(mod:get("panel_offset_x")) or 0
		local offset_y = tonumber(mod:get("panel_offset_y")) or 0
		local scenegraph = view._ui_scenegraph
		local root_node = scenegraph and scenegraph.chs_root
		local list_node = scenegraph and scenegraph.chs_list

		if root_node and root_node.position then
			root_node.position[1] = -PANEL_MARGIN_RIGHT - (width - PANEL_W) + offset_x
			root_node.position[2] = offset_y
		end

		-- The list starts right under the (scaled) header.
		if list_node and list_node.position then
			list_node.position[2] = layout.header_h + 6
		end

		view:trigger_resolution_update()
	end)
end

local function _build_esc_panel(view)
	if not ui_widget() then
		return
	end

	_set_panel_chrome_visible(view, false)
	view._chs_generation = (view._chs_generation or 0) + 1
	_clear_entries(view)

	if not in_hub() and not in_own_singleplay_session() then
		return
	end

	panel_views[view] = true
	local view_generation = view._chs_generation
	local view_name = view.view_name

	local ok, err = pcall(function()
		Managers.data_service.profiles:fetch_all_profiles():next(function(data)
			-- The menu may have been closed while the list was fetching.
			local active = false
			pcall(function()
				active = Managers.ui:view_active(view_name)
			end)
			if view_generation ~= view._chs_generation
				or not active or view._destroyed or not view._widgets then
				return
			end

			local profiles = apply_saved_order(data and data.profiles or {})
			local count = #profiles
			if count == 0 then
				return
			end

			local current = real_local_profile()
			local current_id = current and current.character_id
			local entries = {}
			local layout = panel_layout()

			for i = 1, count do
				local profile = profiles[i]
				local archetype = profile.archetype
				local archetype_name = type(archetype) == "table" and archetype.name or tostring(archetype or "?")
				local is_current = profile.character_id == current_id
				local widget_name = "chs_entry_" .. tostring(i)

				local ok_widget, widget = pcall(function()
					local definition = _make_entry_definition(profile, is_current, layout)
					local w = view:_create_widget(widget_name, definition)

					w.offset = { 0, (i - 1) * (layout.entry_h + layout.gap), 2 }

					return w
				end)

				if ok_widget and widget then
					widget.content.name = profile.name or "?"

					local sub = _archetype_display_name(archetype_name)

					if mod:get("panel_show_level") then
						sub = string.format("%s  ·  %s %s",
							sub,
							mod:localize("panel_level_short"),
							tostring(profile.current_level or "?"))
					end

					if is_current then
						sub = sub .. "  —  " .. mod:localize("panel_current_tag")
					end

					widget.content.sub = sub

					view._widgets[#view._widgets + 1] = widget
					entries[#entries + 1] = {
						widget = widget,
						profile = profile,
						is_current = is_current,
					}
				else
					log("Esc panel: entry widget failed: " .. tostring(widget), true)
				end
			end

			view._chs_entries = entries
			view._chs_layout = layout

			local header = view._widgets_by_name and view._widgets_by_name.chs_header
			if header then
				header.content.text = mod:localize("panel_title")
			end

			_fit_panel_chrome(view, count, layout)
			_set_panel_chrome_visible(view, true)

			log("Esc panel: built " .. tostring(count) .. " entries")
		end):catch(function()
			log("Esc panel: could not fetch the character list", true)
		end)
	end)
	if not ok then
		log("Esc panel: setup failed: " .. tostring(err), true)
	end
end

mod.on_enabled = function()
	local ok, err = pcall(function()
		local ui = Managers.ui
		if ui and ui:view_active("system_view") then
			local view = ui:view_instance("system_view")
			if view and not view._destroyed then _build_esc_panel(view) end
		end
	end)
	if not ok then log("Esc panel: enable rebuild failed: " .. tostring(err)) end
end

mod:hook_safe(SystemViewClass or CLASS.SystemView, "on_exit", function(self)
	self._chs_generation = (self._chs_generation or 0) + 1
	_clear_entries(self)
	_set_panel_chrome_visible(self, false)
	panel_views[self] = nil
end)

mod:hook_safe(SystemViewClass or CLASS.SystemView, "on_enter", function(self)
	_build_esc_panel(self)
end)

-- ---------------------------------------------------------------------------
-- Esc panel input: click to switch, drag to reorder
--
-- A press on an entry starts a CANDIDATE; what it was is decided by mouse
-- movement: past a small threshold it becomes a drag (the entry follows the
-- cursor, the others flow around the claimed slot), otherwise the release is
-- a plain click (switch character, as before).
--
-- The drag is tracked manually from the view's update rather than through
-- the hotspot: the hotspot's is_held goes false the moment the cursor leaves
-- the widget's rect (ui_passes.lua), which happens constantly during a fast
-- drag. The cursor from the input service is in real screen pixels; deltas
-- are converted to UI units with RESOLUTION_LOOKUP.inverse_scale — the same
-- transform the hotspot pass applies via UIResolution.inverse_scale_vector.
-- (The renderer's own inverse_scale field only exists inside a draw pass.)
-- ---------------------------------------------------------------------------

local DRAG_START_THRESHOLD = 6
local ENTRY_BASE_Z = 2
local DRAG_LIFT_Z = 30

local function _cursor_y(input_service)
	local ok, y = pcall(function()
		local cursor = input_service:get("cursor")

		return cursor and cursor[2]
	end)

	return ok and y or nil
end

local function _click_entry(view, entry)
	if entry.is_current then
		return
	end

	-- arm() returns false when a synchronous guard refused the switch
	-- (same character / matchmaking / departing). Keep the menu open then:
	-- the guard already echoed why, and a silently closing menu would look
	-- like the click just got lost.
	if arm(entry.profile) == false then
		return
	end

	pcall(function()
		Managers.ui:close_view(view.view_name)
	end)
end

local function _save_panel_order(entries)
	local ids = {}

	for i = 1, #entries do
		local id = entries[i].profile and entries[i].profile.character_id

		if id then
			ids[#ids + 1] = id
		end
	end

	mod:set("character_order", ids)
	log("Esc panel: character order saved")
end

local function _update_entry_drag(view, dt, input_service)
	local drag = view._chs_drag
	local entries = view._chs_entries
	local layout = view._chs_layout
	local entry = entries and entries[drag.index]

	if not entry or not layout then
		view._chs_drag = nil

		return
	end

	local count = #entries
	local step = layout.entry_h + layout.gap

	local held = false

	pcall(function()
		held = input_service:get("left_hold") and true or false
	end)

	if not held then
		-- Release resolves the candidate: drop (reorder) or click (switch).
		view._chs_drag = nil

		if not drag.moved then
			_click_entry(view, entry)

			return
		end

		local target = math.clamp(drag.target or drag.index, 1, count)

		table.remove(entries, drag.index)
		table.insert(entries, target, entry)

		for i = 1, count do
			local widget = entries[i].widget

			widget.offset[2] = (i - 1) * step
			widget.offset[3] = ENTRY_BASE_Z
		end

		_save_panel_order(entries)

		return
	end

	local cursor_y = _cursor_y(input_service)

	if not cursor_y then
		return
	end

	local ok_scale, inverse_scale = pcall(function()
		return RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale
	end)
	if not ok_scale or type(inverse_scale) ~= "number" then inverse_scale = 1 end
	local delta = (cursor_y - drag.start_y) * inverse_scale

	if not drag.moved and math.abs(delta) > DRAG_START_THRESHOLD then
		-- Candidate becomes a drag: lift the entry above its neighbours.
		drag.moved = true
		entry.widget.offset[3] = DRAG_LIFT_Z
	end

	if not drag.moved then
		return
	end

	-- The dragged entry follows the cursor (clamped to the list)...
	local origin_y = (drag.index - 1) * step
	local y = math.clamp(origin_y + delta, 0, (count - 1) * step)

	entry.widget.offset[2] = y

	-- ...and claims the slot its position is closest to.
	local target = math.clamp(math.floor(y / step + 0.5) + 1, 1, count)

	drag.target = target

	-- The other entries flow around the claimed slot (eased; snap on drop).
	local next_slot = 1

	for i = 1, count do
		if i ~= drag.index then
			if next_slot == target then
				next_slot = next_slot + 1
			end

			local widget = entries[i].widget
			local goal = (next_slot - 1) * step

			widget.offset[2] = widget.offset[2] + (goal - widget.offset[2]) * math.min((dt or 0) * 14, 1)
			next_slot = next_slot + 1
		end
	end
end

mod:hook_safe(SystemViewClass or CLASS.SystemView, "update", function(self, dt, t, input_service)
	local entries = self._chs_entries
	if not entries then
		return
	end

	if self._chs_drag then
		_update_entry_drag(self, dt, input_service)

		return
	end

	for i = 1, #entries do
		local entry = entries[i]
		local hotspot = entry.widget.content.hotspot

		if hotspot and hotspot.on_pressed then
			hotspot.on_pressed = nil

			local cursor_y = _cursor_y(input_service)

			if cursor_y then
				self._chs_drag = {
					index = i,
					start_y = cursor_y,
					moved = false,
				}
			else
				-- No cursor (gamepad?): keep the old press-to-switch behavior.
				_click_entry(self, entry)
			end

			break
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Equip crash guard (permanent). Nexus report: server_correction_occurred
-- resolves profile_field (cosmetic/weapon) slots via
-- profile.visual_loadout[slot_name] with NO nil check, so a server-side
-- equip landing while the LOCAL profile lacks that item (stale profile —
-- e.g. the hub-swap refresh window) makes _equip_item_to_slot index nil and
-- hard-crash (live line 711). EquipmentComponent.equip_item one level down
-- already treats a missing item as a no-op, so skipping here merely lifts
-- Fatshark's own guard up to where the indexing happens. A skipped slot
-- self-heals: server-auth inventory still differs from the local slot, so
-- the next server correction retries it — and the hub heal below re-fetches
-- the profile so that retry finds the item.
-- ---------------------------------------------------------------------------

local ok_equip_guard, EquipGuardVLExt = pcall(require, "scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension")

if not ok_equip_guard or type(EquipGuardVLExt) ~= "table" then
	EquipGuardVLExt = CLASS and CLASS.PlayerUnitVisualLoadoutExtension
end

-- Only the local unit can be healed by fetching the local profile. Use the
-- same request as blocked server pushes so the two paths cannot race.
local function equip_guard_tripped(extension, slot_name, where)
	pcall(function()
		log("Equip guard: skipped equipping a nil item into " .. tostring(slot_name) .. " (" .. where .. ") — crash avoided")

		if extension._is_local_unit and in_hub() then
			request_local_profile_refresh("equip")
		end
	end)
end

if EquipGuardVLExt then
	mod:hook(EquipGuardVLExt, "equip_item_to_slot", function(func, self, item, slot_name, ...)
		if not item then
			equip_guard_tripped(self, slot_name, "equip_item_to_slot")

			return
		end

		return func(self, item, slot_name, ...)
	end)

	mod:hook(EquipGuardVLExt, "_equip_item_to_slot", function(func, self, item, slot_name, ...)
		if not item then
			equip_guard_tripped(self, slot_name, "_equip_item_to_slot")

			return
		end

		return func(self, item, slot_name, ...)
	end)
else
	log("Equip guard DISABLED: PlayerUnitVisualLoadoutExtension not found (game update?)", true)
end
