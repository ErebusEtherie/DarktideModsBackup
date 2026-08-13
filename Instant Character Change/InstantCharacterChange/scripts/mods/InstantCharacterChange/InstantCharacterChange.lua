--[[
	File: InstantCharacterChange.lua
	Description:
		Switch operatives without going back to the main menu and reloading
		the Mourningstar.

		Use case: you are on the Mourningstar as an Ogryn, the Party Finder
		needs a Psyker. Pick the Psyker in the Esc-menu panel, apply to the
		group as usual, and when the mission starts you connect to it AS the
		Psyker. One loading screen (the mission itself) instead of three
		(main menu -> Mourningstar -> mission).

		How it works (all of this is client-side data the game itself sends):

		1. "Who you are" for the Party Finder is your PRESENCE, which your own
		   client publishes every ~1s from
		   Managers.player:local_player_backend_profile()
		   (presence_manager.lua). Hooking that function makes the group
		   leader see you as the target character.

		2. The matchmaking queue ticket (fetch_queue_ticket_mission /
		   _hot_join_ticket / single player) sends a characterId taken from
		   the same local_player_backend_profile(). Same hook covers it.

		3. When connecting to the new game server the client CLAIMS its
		   character_id via rpc_sync_local_players; the sync data comes from
		   PlayerManager:create_sync_data() (local_players_sync_state.lua).
		   The server then fetches the authoritative profile for that id from
		   the backend itself (profile_synchronizer_host.lua ->
		   fetch_account_character) and syncs it back to us
		   (local_profiles_sync_state.lua -> player:set_profile). So we hook
		   create_sync_data to claim the target character; all the actual
		   character data comes from the backend, not from us.

		4. Managers.data_service.account:set_selected_character_id() is also
		   called (plain backend POST, no loading screen) so the backend's
		   "selected character" matches the ticket, in case it cross-checks.

		5. What PARTY MEMBERS see (hub left-side panels, Social, Party Finder)
		   is driven by PRESENCE, not by the hub server's profile sync: their
		   clients read presence:character_profile(), a blob the BACKEND
		   attaches to our presence from the character_id we advertise. After
		   every applied/armed/cancelled switch the mod re-advertises the
		   character and restarts the presence stream (the same full handshake
		   as a game login), so the backend rebuilds that blob and the party
		   list shows the new operative. The visible 3D unit in the hub still
		   stays the old character until the next travel.

		6. The MISSION TERMINAL's "which difficulties/missions are unlocked"
		   comes from a per-character player-journey fetch that the game caches
		   as ONE global blob, force-refreshed only on hub load — safe in
		   vanilla, where a character change always reloads the hub, stale
		   with this mod. The journey-data hook re-points that fetch at the
		   switched character and refreshes the cache when it was built for
		   someone else, so the terminal gates by the character actually
		   being played.

		The switch stays ARMED until the first server accepts us as the target
		character (detected in the HumanPlayer.set_profile hook), or until you
		run "/switchchar cancel", or until you go back to the main menu.

		While armed and still on the Mourningstar you keep walking around as
		your old character (the hub server cannot be re-told who you are) —
		that is cosmetic only.

	Author: X
]]

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

-- character_id we were actually playing when the switch was armed; restored
-- as the backend "selected character" on /switchchar cancel.
mod._original_character_id = nil

-- Anti-revert guard for the /switchnow hub swap: while set, incoming profile
-- pushes from the hub server for OUR player that carry a DIFFERENT character
-- are dropped (the hub server only knows the character we connected with and
-- would otherwise overwrite the local swap after every loadout edit).
-- Cleared automatically when handshaking into a new session (the new server
-- is authoritative for the right character from then on) or in the main menu.
mod._local_swap_character_id = nil

-- Which character the game's mission-board player-journey cache (the
-- difficulty / mission unlocks the mission terminal shows) was last built
-- for. The vanilla cache is a single global blob with no record of whose it
-- is; the journey-data hook below uses this to know when serving it would
-- show another character's unlocks.
mod._journey_cache_character_id = nil

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

-- Logs to the file (if enabled) and, when echo_too is set, to chat. The text
-- is passed to echo as a format ARGUMENT so stray '%' in names/errors can't
-- break string.format. Chat output respects the "chat_messages_enabled"
-- setting; direct responses to typed chat commands bypass this on purpose.
local function log(text, echo_too)
	write_log_line(text)
	if echo_too and mod:get("chat_messages_enabled") then
		mod:echo("[InstantCharacterChange] %s", text)
	end
end

-- Switch-flow chat notification, silenced by the "chat_messages_enabled"
-- setting.
local function chat_message(text)
	if mod:get("chat_messages_enabled") then
		mod:echo("[InstantCharacterChange] %s", text)
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

local function profile_label(profile, index)
	local archetype = profile.archetype and profile.archetype.name or "?"
	local level = profile.current_level or "?"
	local name = profile.name or "?"
	return string.format("%d. %s  —  %s, lv %s", index, name, archetype, level)
end

-- Finds a character in a fetched profile list by: index number, archetype
-- name prefix ("psy" -> psyker) or character name substring. Returns
-- profile or nil plus an error message.
local function find_target(profiles, query)
	query = string.lower(query or "")
	if query == "" then
		return nil, "empty query"
	end

	-- By index.
	local index = tonumber(query)
	if index then
		local profile = profiles[index]
		if profile then
			return profile
		end
		return nil, "no character #" .. tostring(index)
	end

	-- By archetype prefix, e.g. "psy", "ogryn", "vet", "zealot", "adamant".
	for i = 1, #profiles do
		local profile = profiles[i]
		local archetype = profile.archetype and profile.archetype.name
		if archetype and string.find(string.lower(archetype), query, 1, true) == 1 then
			return profile
		end
	end

	-- By character name substring.
	for i = 1, #profiles do
		local profile = profiles[i]
		local name = profile.name
		if name and string.find(string.lower(name), query, 1, true) then
			return profile
		end
	end

	return nil, "no character matches '" .. query .. "'"
end

-- Custom character order (drag & drop in the Esc panel), persisted as an
-- array of character ids in the mod settings. Applied to every fetched
-- profile list the mod shows, so the panel and the /switchchar numbering
-- always agree. Ids missing from the saved order (new characters) keep their
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

		if stream then
			stream:abort()
		end

		pm:_init_immaterium_presence()

		mod._presence_restart_cooldown = PRESENCE_RESTART_DEBOUNCE
		mod._presence_reinit_retry = PRESENCE_REINIT_RETRY_DELAY

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
-- Arm / disarm
-- ---------------------------------------------------------------------------

-- Applies the armed switch RIGHT NOW inside a locally hosted singleplayer
-- session (see in_own_singleplay_session). On the next synchronizer tick the
-- profile is applied (our set_profile hook then disarms and reports success)
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
-- set_profile detector hook below fires from our own call and disarms.
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
		log("Hub-local switch applied (unit stays the old character until the next travel)")
		chat_message(mod:localize("msg_hub_swapped"))
	else
		mod._local_swap_character_id = nil
		log("Hub-local switch failed: " .. tostring(err) .. " (switch stays armed for the next travel)", true)
	end
end

local function disarm(reason, silent)
	if not mod._target then
		return
	end
	local label = mod._target.label
	mod._target = nil
	log("Switch disarmed (" .. tostring(reason) .. "): " .. tostring(label), not silent)
end

local function arm(profile, hub_live)
	local current = real_local_profile()
	local current_id = current and current.character_id

	if current_id and current_id == profile.character_id then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_already_that_character"))
		return false
	end

	-- Same guard the game applies to its own "change character" button:
	-- swapping identity mid-matchmaking would race the queue ticket. Echoed
	-- unconditionally (not via chat_message): every arm() call is a direct
	-- user action, and a silently ignored click reads as a broken mod.
	local in_matchmaking = false
	pcall(function()
		in_matchmaking = Managers.data_service.social:is_in_matchmaking()
	end)
	if in_matchmaking then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_in_matchmaking"))
		return false
	end

	-- "Departing" guard. Once the party accepts a mission, the backend
	-- allocates the game session while everyone is still standing in the hub
	-- — party game state GAME_SESSION_IN_PROGRESS, the phase the game shows
	-- as "Departing". is_in_matchmaking() above is already FALSE here: it
	-- only covers the queue and the acceptance vote (PartyState matchmaking /
	-- matchmaking_acceptance_vote), never in_mission. The session slot was
	-- reserved for the character we queued as, so switching now makes the
	-- connect-time claim (create_sync_data) contradict that reservation —
	-- the server accepts the join and then kicks us right after the mission
	-- loads (Nexus bug report). The party state is re-read on every attempt
	-- and drops back to idle when the vote fails or matchmaking is aborted,
	-- so switching unblocks by itself.
	local departing = false
	pcall(function()
		departing = Managers.party_immaterium:game_session_in_progress()
	end)
	if departing then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_departing_blocked"))
		return false
	end

	-- Premade "start mission" vote (mission terminal with a party, Havoc —
	-- same template): it runs as a party vote of type "start_matchmaking",
	-- which vanilla's current_state() does NOT map (it only knows
	-- "accept_matchmaking", the found-game accept popup) — so while members
	-- are still accepting, both checks above read the party as idle (field
	-- report: Havoc premade). The window is just as dangerous: each
	-- member's queue ticket — with their character baked in — goes out THE
	-- MOMENT THEY VOTE YES, so switching after accepting recreates the
	-- departing mismatch and the kick. The vote popup is modal, so in
	-- practice this window only exists after the local accept — block the
	-- whole ONGOING vote; a failed vote unblocks automatically (live
	-- re-read).
	local start_vote_ongoing = false
	pcall(function()
		local vote = Managers.party_immaterium:party_vote_state()

		start_vote_ongoing = vote and vote.type == "start_matchmaking" and vote.state == "ONGOING"
	end)
	if start_vote_ongoing then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_start_vote_blocked"))
		return false
	end

	mod._original_character_id = current_id

	local archetype = profile.archetype and profile.archetype.name or "?"
	local label = string.format("%s (%s, lv %s)", profile.name or "?", archetype, tostring(profile.current_level or "?"))

	-- Tell the backend first, so its "selected character" agrees with the
	-- queue tickets we are about to send. Plain POST — no loading screen.
	log("Arming switch to " .. label .. " character_id=" .. tostring(profile.character_id))

	local ok = pcall(function()
		Managers.data_service.account:set_selected_character_id(profile.character_id):next(function()
			mod._target = {
				profile = profile,
				character_id = profile.character_id,
				label = label,
			}

			-- Preload the target's narrative (onboarding/story progress) NOW.
			-- NarrativeManager keeps per-character data that is normally only
			-- loaded when entering the hub AS that character; onboarding UI
			-- indexes it by profile.character_id every frame and hard-crashes
			-- on a missing entry. So the profile may only go live once this
			-- has landed. Idempotent and async.
			local narrative_promise
			pcall(function()
				narrative_promise = Managers.narrative:load_character_narrative(profile.character_id)
			end)

			log("Backend accepted selected-character change. Switch ARMED: " .. label, true)

			announce_switch_to_party(current, profile)

			if in_own_singleplay_session() then
				-- Psykhanium: no server involved — switch right here, gated
				-- on the narrative preload (see above).
				chat_message(mod:localize("msg_live_switching"))
				if narrative_promise then
					narrative_promise:next(function()
						apply_live_singleplay_switch()
					end):catch(function()
						log("Could not load target narrative — live switch aborted; the switch stays armed and applies on your next travel", true)
					end)
				else
					apply_live_singleplay_switch()
				end
			elseif hub_live and in_hub() then
				-- /switchnow in the hub: swap the local profile in place,
				-- gated on the same narrative preload (hub onboarding UI
				-- reads it per character every frame).
				if narrative_promise then
					narrative_promise:next(function()
						if in_hub() then
							apply_hub_local_switch()
						end
					end):catch(function()
						log("Could not load target narrative — hub swap aborted; the switch stays armed and applies on your next travel", true)
					end)
				else
					apply_hub_local_switch()
				end
			else
				chat_message(mod:localize("msg_armed_hint"))

				-- No local swap on this path, but the party should still see
				-- the class we are going to play (hook 1 already answers the
				-- presence poll with the target).
				force_presence_readvertise(profile, "switch armed")
			end
		end):catch(function(error)
			local details = type(error) == "table" and table.tostring(error, 3) or tostring(error)
			log("Backend REJECTED selected-character change: " .. details, true)
		end)
	end)
	if not ok then
		log("Could not reach the account service (game update?)", true)
	end
end

local function cancel_switch()
	if not mod._target then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_nothing_armed"))
		return
	end

	-- Mirror of the guards in arm(): from the moment a queue ticket may be
	-- out with the ARMED character (hook 1 answers ticket fetches with it),
	-- cancelling would create the same claim-vs-reservation mismatch in
	-- reverse and get us kicked on mission load. That covers the whole
	-- pipeline: the premade start-mission vote (tickets go out as members
	-- vote yes), the queue, the found-game accept vote (tickets went out at
	-- queue start), and the allocated session. Re-read live, so a failed
	-- vote / aborted queue / cancelled departure unblocks cancelling by
	-- itself.
	local ticket_may_be_out = false
	pcall(function()
		local pm = Managers.party_immaterium
		local vote = pm:party_vote_state()

		-- SocialService.is_in_matchmaking covers the queue AND the
		-- found-game accept vote (unlike the party manager's own, which is
		-- queue-only).
		ticket_may_be_out = Managers.data_service.social:is_in_matchmaking()
			or pm:game_session_in_progress()
			or (vote and vote.type == "start_matchmaking" and vote.state == "ONGOING")
	end)
	if ticket_may_be_out then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_departing_cancel_blocked"))
		return
	end

	local restore_id = mod._original_character_id

	disarm("cancelled by user")

	-- Point the backend's selected character back at who we actually are.
	if restore_id then
		pcall(function()
			Managers.data_service.account:set_selected_character_id(restore_id):next(function()
				log("Backend selected character restored to " .. tostring(restore_id))
			end):catch(function()
				log("Could not restore backend selected character (harmless: it self-corrects next relog)", true)
			end)
		end)
	end

	-- The party may have been shown the armed target already — advertise the
	-- character we actually still are.
	force_presence_readvertise(real_local_profile(), "switch cancelled")
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
		-- anti-revert guard (see /switchnow) is no longer needed.
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
--    below, which is the correct moment to disarm there too.)
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
		mod._target = nil
		mod._original_character_id = nil
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
--    The set_profile hook above then sees the target id and disarms.
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

mod.on_game_state_changed = function(status, state_name)
	mod._damage_indicator_units = setmetatable({}, { __mode = "k" })
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
-- Single-flight with a dirty flag: edit bursts (items + talents commit as
-- separate POSTs) collapse into at most one trailing re-fetch.
-- Reapplying a profile is only safe while we are actually STANDING in the
-- hub (game mode "hub" — false on every loading screen) and the party has no
-- allocated game session ("Departing"). Checked at promise-RESOLVE time, not
-- at fetch time: a set_profile landing during the hub teardown loads item /
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

local function request_local_profile_refresh(character_id)
	if mod._refresh_inflight then
		mod._refresh_dirty = true
		return
	end

	mod._refresh_inflight = true
	mod._refresh_dirty = false

	local ok = pcall(function()
		Managers.data_service.profiles:fetch_profile(character_id):next(function(profile)
			mod._refresh_inflight = false

			if mod._local_swap_character_id ~= character_id or not profile then
				return
			end

			if not safe_to_reapply_profile() then
				log("Skipped local profile reapply — hub teardown/departing in progress (avoids racing the package unload)")
				return
			end

			local applied = pcall(function()
				local player = Managers.player:local_player(1)

				player:set_profile(profile)
				-- What the real push would have triggered; among others this
				-- clears UIManager's "waiting for loadout" state.
				Managers.event:trigger("event_player_profile_updated", player:peer_id(), player:local_player_id(), profile)
			end)
			if applied then
				log("Local profile refreshed from backend after loadout edit")
			end

			if mod._refresh_dirty then
				request_local_profile_refresh(character_id)
			end
		end):catch(function(err)
			mod._refresh_inflight = false
			log("Backend profile refresh failed: " .. tostring(err))
		end)
	end)
	if not ok then
		mod._refresh_inflight = false
	end
end

-- Anti-revert guard for the /switchnow hub swap. The hub server re-fetches
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
			mod._refresh_delay_left = 0.75

			return
		end
	end

	return func(self, channel_id, peer_id, local_player_id, ...)
end)

-- Back in the main menu the game manages character selection itself; an armed
-- switch would fight it. Disarm silently.
mod:hook_safe(CLASS.StateMainMenu, "on_enter", function()
	mod._local_swap_character_id = nil

	if mod._target then
		disarm("entered main menu", true)
	end
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

	if force_refresh == false and mod._journey_cache_character_id ~= desired_id then
		force_refresh = true

		log("Journey data: cached unlocks belong to another character — forcing a backend refresh")
	end

	mod._journey_cache_character_id = desired_id

	return func(self, account_id, desired_id, force_refresh)
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
	local blob_owner_id = mod._journey_cache_character_id

	if blob_owner_id and character_id ~= blob_owner_id then
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
-- The fix here does not touch that machinery at all. A preset already
-- CONTAINS everything the backend needs — gear ids per slot and the talent
-- node map live in the save file. Strategy is VERIFY-FIRST to stay
-- server-friendly: the game's own commit path runs untouched; after the
-- inventory closes (once the game's round-trip has landed) the profile is
-- compared LOCALLY against the active preset, and only actual losses are
-- committed straight to the backend with the same service calls the view
-- uses. The common, working case costs zero extra requests; a struck bug
-- costs at most two (one batched item equip + one talent set). The only
-- eager path is when the game demonstrably skips its whole commit (closing
-- before the item list synced) — there is nothing to wait for then.
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
local function schedule_preset_commit(reason, min_delay, max_wait)
	local ok = pcall(function()
		local PU = profile_utils()
		local preset_id = PU and PU.get_active_profile_preset_id()

		if not preset_id then
			return
		end

		local profile = real_local_profile()

		mod._preset_commit = {
			preset_id = preset_id,
			character_id = profile and profile.character_id,
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
		local player = Managers.player:local_player(1)
		local profile = player and player:profile()
		local preset = PU and PU.get_profile_preset(pending.preset_id)

		if not profile or not preset then
			return
		end

		-- Stale request from before a character switch.
		if pending.character_id and profile.character_id ~= pending.character_id then
			return
		end

		-- ITEMS: gear ids straight from the preset save data.
		local wrong_slots = {}
		local wrong_any = false
		local equipped = profile.loadout_item_ids or {}

		for slot_name, gear_id in pairs(preset.loadout or {}) do
			if BUILD_SLOTS[slot_name] and gear_id and equipped[slot_name] ~= gear_id then
				wrong_slots[slot_name] = gear_id
				wrong_any = true
			end
		end

		if wrong_any then
			local count = 0
			for _ in pairs(wrong_slots) do
				count = count + 1
			end

			log("Preset guard (" .. tostring(pending.reason) .. "): committing " .. tostring(count) .. " item slot(s) directly to backend", true)
			Managers.data_service.profiles:equip_items_in_slots(profile.character_id, wrong_slots, {}):next(function()
				-- Same follow-up the game does after an equip: nudges the
				-- server refetch (or, with an active hub swap, our own
				-- refresh path).
				pcall(function()
					if Managers.connection:is_host() then
						local host = Managers.profile_synchronization:synchronizer_host()

						if host then
							host:profile_changed(player:peer_id(), player:local_player_id())
						end
					else
						Managers.connection:send_rpc_server("rpc_notify_profile_changed", player:local_player_id())
					end
				end)
				log("Preset guard: items committed", true)
			end):catch(function(equip_err)
				log("Preset guard: item commit FAILED: " .. tostring(equip_err), true)
			end)
		end

		-- TALENTS: node map straight from the preset save data.
		local preset_talents = preset.talents
		local talents_match = true

		if type(preset_talents) == "table" and next(preset_talents) ~= nil and type(profile.selected_nodes) == "table" then
			talents_match = _talent_maps_equal(profile.selected_nodes, preset_talents)
		end

		if not talents_match then
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

		if not wrong_any and talents_match then
			log("Preset guard: profile already matches preset '" .. tostring(preset.name or pending.preset_id) .. "'")
		end
	end)
	if not ok then
		log("Preset guard: commit errored: " .. tostring(err), true)
	end
end

-- Returns the id of a preset that exactly matches the profile's current
-- build (weapons/curios + talents), or nil.
local function _find_matching_preset_id(profile)
	local PU = profile_utils()
	local presets = PU and PU.get_profile_presets()

	if not presets then
		return nil
	end

	local equipped = profile.loadout_item_ids or {}

	for i = 1, #presets do
		local preset = presets[i]
		local loadout = preset and preset.loadout

		if loadout then
			local matches = true

			for slot_name in pairs(BUILD_SLOTS) do
				local preset_gear_id = loadout[slot_name]

				if preset_gear_id and equipped[slot_name] ~= preset_gear_id then
					matches = false

					break
				end
			end

			if matches and type(preset.talents) == "table" and next(preset.talents) ~= nil and type(profile.selected_nodes) == "table" then
				matches = _talent_maps_equal(profile.selected_nodes, preset.talents)
			end

			if matches then
				return preset.id
			end
		end
	end

	return nil
end

-- Marks the given preset as selected in the presets element (the visual
-- highlight) and syncs the element/view bookkeeping.
local function _apply_preset_selection_visual(view, preset_id)
	local element = view._profile_presets_element
	local widgets = element and element._profile_buttons_widgets

	if not widgets then
		return false
	end

	local found = false

	for i = 1, #widgets do
		local content = widgets[i].content
		local selected = content.profile_preset_id == preset_id

		if content.hotspot then
			content.hotspot.is_selected = selected
		end

		found = found or selected
	end

	if found then
		element._active_profile_preset_id = preset_id
		view._active_profile_preset_id = preset_id
	end

	return found
end

if InventoryBackgroundViewClass then
	-- PRESET SELECTION HEALING. When the inventory opens while the profile
	-- has not caught up with a just-committed preset yet (fast close-reopen),
	-- the game sees a mismatch and DESELECTS the active preset — erasing the
	-- saved id, which is why the preset shows as "none selected" even after
	-- the build itself arrives. Two-part fix:
	--   1. While _setup_profile_presets runs, the transient mismatch-driven
	--      deselect is blocked (flag checked by the hook on
	--      ViewElementProfilePresets.remove_active_profile_preset below).
	--   2. After setup, if NO preset is marked active but the profile
	--      exactly matches one, that preset is re-selected — healing ids
	--      already erased before this fix and any other path that lost the
	--      selection.
	mod:hook(InventoryBackgroundViewClass, "_setup_profile_presets", function(func, self, ...)
		self.__chs_block_preset_deselect = true

		local result_a, result_b, result_c = func(self, ...)

		self.__chs_block_preset_deselect = nil

		pcall(function()
			local PU = profile_utils()
			local active_id = PU and PU.get_active_profile_preset_id()

			if active_id then
				return
			end

			local player = Managers.player:local_player(1)
			local profile = player and player:profile()
			local match_id = profile and _find_matching_preset_id(profile)

			if match_id and _apply_preset_selection_visual(self, match_id) then
				PU.save_active_profile_preset_id(match_id)
				log("Preset guard: restored the active preset selection (profile matches it)")
			end
		end)

		return result_a, result_b, result_c
	end)

	-- Single trigger: inventory close.
	mod:hook(InventoryBackgroundViewClass, "on_exit", function(func, self, ...)
		local own_player = false
		local skipped = false

		pcall(function()
			own_player = not self._is_readonly and self._is_own_player
			skipped = own_player and not self:is_inventory_synced()
		end)

		if skipped then
			-- The game is about to skip its ENTIRE commit (closed before the
			-- item list synced) — nothing to wait for. Talents do not depend
			-- on that list, commit them right away; items follow via the
			-- direct preset commit almost immediately.
			log("Inventory closed before its item sync finished — the game skipped its commit; committing directly", true)

			pcall(function()
				self:_apply_current_talents_to_profile()
			end)

			schedule_preset_commit("game skipped commit on close", 0.15, 3.0)
		elseif own_player then
			-- Normal close: the game's own commit is on its way. Verify the
			-- moment its round-trip settles (the waiting flag is polled every
			-- frame) — the comparison is purely local (save data vs profile),
			-- so when the game's path worked this costs ZERO backend requests.
			schedule_preset_commit("verify after close", 0.4, 5.0)
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

		return func(self, ...)
	end)
end

-- ---------------------------------------------------------------------------
-- Update loop: debounced backend refresh + preset guard timing
-- ---------------------------------------------------------------------------

mod.update = function(dt)
	dt = dt or 0

	-- Debounced local-profile refresh for the hub swap (armed by the blocked
	-- push handler; the window restarts on every push).
	if mod._refresh_delay_left then
		mod._refresh_delay_left = mod._refresh_delay_left - dt

		if mod._refresh_delay_left <= 0 then
			mod._refresh_delay_left = nil

			local guard_id = mod._local_swap_character_id
			if guard_id then
				request_local_profile_refresh(guard_id)
			end
		end
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
-- switch (same as /switchnow — no Mourningstar reload) and closes the menu.
-- Dragging an entry (press, move, release) reorders the list; the order is
-- saved and also applied to the /switchchar numbering.
-- Only shown where switching works: hub and Psykhanium.
--
-- Integration technique: the panel's scenegraph nodes and static widgets are
-- injected into the view's DEFINITIONS via hook_require, so the view builds,
-- draws and destroys them natively; per-character entries are created with
-- the view's own _create_widget at open time. (Custom draw-hook approaches
-- proved unreliable.)
-- ---------------------------------------------------------------------------

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

local function panel_user_width()
	local width = tonumber(mod:get("panel_width")) or PANEL_W

	return math.clamp(width, 340, 600)
end

-- All size-dependent values in one place, scaled by the "panel_scale" mod
-- setting (percent). Entry widgets are rebuilt on every menu open, so the
-- scale applies immediately on the next open.
local function panel_layout()
	local scale = math.clamp(tonumber(mod:get("panel_scale")) or 100, 70, 200) / 100

	return {
		width = panel_user_width(),
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
	}, "chs_root")
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

	if not in_hub() and not in_own_singleplay_session() then
		return
	end

	local view_name = view.view_name

	local ok, err = pcall(function()
		Managers.data_service.profiles:fetch_all_profiles():next(function(data)
			-- The menu may have been closed while the list was fetching.
			local active = false
			pcall(function()
				active = Managers.ui:view_active(view_name)
			end)
			if not active or view._destroyed or not view._widgets then
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

mod:hook_safe(SystemViewClass or CLASS.SystemView, "on_enter", function(self)
	_build_esc_panel(self)
end)

-- Remove our dynamic entries when the menu closes: destroy their passes (if
-- the view's renderer is still alive), drop them from the widget list and
-- unregister their names, so nothing of ours outlives the view.
mod:hook_safe(SystemViewClass or CLASS.SystemView, "on_exit", function(self)
	local entries = self._chs_entries

	self._chs_drag = nil
	self._chs_layout = nil

	if not entries then
		return
	end

	self._chs_entries = nil

	local UIWidget = ui_widget()
	local ui_renderer = self._ui_default_renderer

	for i = 1, #entries do
		local widget = entries[i].widget

		if UIWidget and ui_renderer then
			pcall(UIWidget.destroy, ui_renderer, widget)
		end

		local widgets = self._widgets
		if widgets then
			for j = #widgets, 1, -1 do
				if widgets[j] == widget then
					table.remove(widgets, j)
					break
				end
			end
		end

		pcall(function()
			self:_unregister_widget_name(widget.name)
		end)
	end
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

local function _ui_inverse_scale()
	local ok, inverse_scale = pcall(function()
		return RESOLUTION_LOOKUP.inverse_scale
	end)

	return ok and inverse_scale or 1
end

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
	if arm(entry.profile, true) == false then
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

	local delta = (cursor_y - drag.start_y) * _ui_inverse_scale()

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
-- /switchchar command
-- ---------------------------------------------------------------------------

local function list_characters()
	local ok = pcall(function()
		Managers.data_service.profiles:fetch_all_profiles():next(function(data)
			local profiles = apply_saved_order(data and data.profiles or {})

			mod:echo("[InstantCharacterChange] " .. mod:localize("msg_character_list"))
			local current = real_local_profile()
			local current_id = current and current.character_id
			for i = 1, #profiles do
				local line = profile_label(profiles[i], i)
				if profiles[i].character_id == current_id then
					line = line .. "   <- " .. mod:localize("msg_current_marker")
				end
				mod:echo("%s", line)
			end
			if mod._target then
				mod:echo("[InstantCharacterChange] %s %s", mod:localize("msg_armed_status"), mod._target.label)
			end
			mod:echo("[InstantCharacterChange] " .. mod:localize("msg_usage_hint"))
		end):catch(function()
			mod:echo("[InstantCharacterChange] " .. mod:localize("msg_fetch_failed"))
		end)
	end)
	if not ok then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_fetch_failed"))
	end
end

local function switch_command(hub_live, ...)
	local query = table.concat({ ... }, " ")

	if query == "" then
		list_characters()
		return
	end

	if query == "cancel" or query == "off" then
		cancel_switch()
		return
	end

	if not in_hub() and not in_own_singleplay_session() then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_hub_only"))
		return
	end

	-- Always re-fetch: loadouts/levels may have changed, and the profile we
	-- arm with is also what gets packed for player-hosted sessions.
	local ok = pcall(function()
		Managers.data_service.profiles:fetch_all_profiles():next(function(data)
			local profiles = apply_saved_order(data and data.profiles or {})

			local target, err = find_target(profiles, query)
			if not target then
				mod:echo("[InstantCharacterChange] %s. %s", tostring(err), mod:localize("msg_usage_hint"))
				return
			end

			arm(target, hub_live)
		end):catch(function()
			mod:echo("[InstantCharacterChange] " .. mod:localize("msg_fetch_failed"))
		end)
	end)
	if not ok then
		mod:echo("[InstantCharacterChange] " .. mod:localize("msg_fetch_failed"))
	end
end

mod:command("switchchar", mod:localize("command_description"), function(...)
	switch_command(false, ...)
end)

-- Same as /switchchar, but in the hub the switch applies IMMEDIATELY
-- (local profile swap): your visible unit stays the old character, but the
-- loadout/talent views open for the new one so the build can be adjusted
-- before queueing. In the Psykhanium it behaves exactly like /switchchar
-- (live respawn there already).
mod:command("switchnow", mod:localize("command_description_now"), function(...)
	switch_command(true, ...)
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

-- Single-flight backend re-fetch of whoever we currently are, applied the
-- way the real push would be. Speeds up the correction retry after a skip.
-- Hub only — mission/psykhanium profiles are managed by their own machinery.
local function equip_guard_heal()
	if mod._equip_guard_heal_inflight then
		return
	end

	mod._equip_guard_heal_inflight = true

	local ok = pcall(function()
		local player = Managers.player:local_player(1)
		local character_id = player:character_id()

		Managers.data_service.profiles:fetch_profile(character_id):next(function(profile)
			mod._equip_guard_heal_inflight = nil

			if not profile then
				return
			end

			if not safe_to_reapply_profile() then
				log("Equip guard: skipped profile reapply — hub teardown/departing in progress")
				return
			end

			local applied = pcall(function()
				local p = Managers.player:local_player(1)

				p:set_profile(profile)
				Managers.event:trigger("event_player_profile_updated", p:peer_id(), p:local_player_id(), profile)
			end)

			if applied then
				log("Equip guard: local profile refreshed after a skipped equip")
			end
		end):catch(function(err)
			mod._equip_guard_heal_inflight = nil

			log("Equip guard: profile refresh failed: " .. tostring(err))
		end)
	end)

	if not ok then
		mod._equip_guard_heal_inflight = nil
	end
end

local function equip_guard_tripped(slot_name, where)
	log("Equip guard: skipped equipping a nil item into " .. tostring(slot_name) .. " (" .. where .. ") — crash avoided")

	if in_hub() then
		equip_guard_heal()
	end
end

if EquipGuardVLExt then
	mod:hook(EquipGuardVLExt, "equip_item_to_slot", function(func, self, item, slot_name, ...)
		if not item then
			equip_guard_tripped(slot_name, "equip_item_to_slot")

			return
		end

		return func(self, item, slot_name, ...)
	end)

	mod:hook(EquipGuardVLExt, "_equip_item_to_slot", function(func, self, item, slot_name, ...)
		if not item then
			equip_guard_tripped(slot_name, "_equip_item_to_slot")

			return
		end

		return func(self, item, slot_name, ...)
	end)
else
	log("Equip guard DISABLED: PlayerUnitVisualLoadoutExtension not found (game update?)", true)
end

