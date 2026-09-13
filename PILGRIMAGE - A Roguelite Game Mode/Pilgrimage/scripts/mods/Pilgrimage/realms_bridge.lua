-- realms_bridge.lua
--
-- Experimental Realms compatibility shell. This module owns only session discovery,
-- Pilgrimage-version admission, the small host-rules snapshot, and the human-seat
-- model used by the terminal and bot roster. It deliberately does not pretend that
-- the complete boon catalogue is network-safe yet.

local M = {}

local _mod
local _settings
local _shared
local _run_state
local _debug_log
local _realms
local _installed = false
local _peers = {}
local _last_active = false
local _rules_revision = 0
local _last_rules_signature = nil
local _clock = 0

local RPC_HANDSHAKE = "pilgrimage_handshake_v1"
local RPC_RULES = "pilgrimage_rules_v1"
local RPC_WEAPON_FX = "pilgrimage_weapon_fx_v1"
local _weapon_fx_handler
local NETWORK_PROTOCOL = 1
local MAX_GUESTS = 3

local function _normalize_peer_id(peer_id)
	if peer_id == nil then return nil end
	return string.lower(tostring(peer_id))
end

local function _local_peer_id()
	local Network = rawget(_G, "Network")
	if not Network or type(Network.peer_id) ~= "function" then return nil end
	local ok, peer_id = pcall(Network.peer_id)
	return ok and _normalize_peer_id(peer_id) or nil
end

local function _connection()
	return Managers and Managers.connection or nil
end

local function _is_host()
	local connection = _connection()
	if not connection or type(connection.is_host) ~= "function" then return false end
	local ok, value = pcall(connection.is_host, connection)
	return ok and value == true
end

local function _is_client()
	local connection = _connection()
	if not connection or type(connection.is_client) ~= "function" then return false end
	local ok, value = pcall(connection.is_client, connection)
	return ok and value == true
end

local function _host_peer_id()
	if _is_host() then return _local_peer_id() end
	local connection = _connection()
	if not connection or type(connection.host) ~= "function" then return nil end
	local ok, peer_id = pcall(connection.host, connection)
	return ok and _normalize_peer_id(peer_id) or nil
end

local function _realms_host_type()
	local session = Managers and Managers.multiplayer_session or nil
	if not session or type(session.host_type) ~= "function" then return nil end
	local ok, host_type = pcall(session.host_type, session)
	return ok and host_type or nil
end

local function _is_player_host_type(host_type)
	if host_type == "player" then return true end
	local constants = rawget(_G, "MatchmakingConstants")
	local expected = constants and constants.HOST_TYPES and constants.HOST_TYPES.player
	return expected ~= nil and host_type == expected
end

function M.is_installed()
	return _installed and type(_realms) == "table"
end

function M.is_active()
	if not M.is_installed() then return false end
	if type(_realms.network_is_available) ~= "function" then return false end
	local ok_network, available = pcall(_realms.network_is_available)
	if not ok_network or available ~= true then return false end
	return _is_player_host_type(_realms_host_type())
end

function M.is_host()
	return M.is_active() and _is_host()
end

function M.is_client()
	return M.is_active() and _is_client()
end

local function _content_schema()
	-- The exact internal version is the required compatibility boundary for this
	-- prototype. Keep a separately named field now so a deterministic file-manifest
	-- hash can replace it without changing the RPC shape later.
	return "pilgrimage-content-" .. tostring(_mod and _mod.version or "unknown")
end

local function _settings_snapshot()
	return {
		cheat_mode = _settings.cheat_mode_enabled(),
		cheat_invulnerable = _settings.cheat_invulnerable_enabled(),
		cheat_one_shot = _settings.cheat_one_shot_enabled(),
		custom_weapon_balancing = _settings.custom_weapon_balancing_enabled(),
		custom_weapon_balancing_meat_grinder =
			_settings.custom_weapon_balancing_meat_grinder_enabled(),
	}
end

local function _rules_signature(rules)
	return table.concat({
		tostring(rules.cheat_mode),
		tostring(rules.cheat_invulnerable),
		tostring(rules.cheat_one_shot),
		tostring(rules.custom_weapon_balancing),
		tostring(rules.custom_weapon_balancing_meat_grinder),
	}, "|")
end

local function _send(rpc_name, recipient, ...)
	if not M.is_active() or type(_realms.network_send) ~= "function" then
		return false, "Realms network is unavailable"
	end
	local ok, sent, reason = pcall(_realms.network_send,
		_mod, rpc_name, recipient, ...)
	if not ok then return false, tostring(sent) end
	return sent == true, reason
end

function M.set_weapon_fx_handler(handler)
	_weapon_fx_handler = handler
end

function M.send_weapon_fx(packet)
	if not M.is_host() then return end
	for peer, state in pairs(_peers) do
		if state.status == "compatible" then _send(RPC_WEAPON_FX, peer, packet) end
	end
end

local function _on_weapon_fx(sender, packet)
	sender = _normalize_peer_id(sender)
	local peer = _peers[sender]
	if not M.is_client() or sender ~= _host_peer_id() or not peer
		or peer.status ~= "compatible" or not _weapon_fx_handler then return end
	-- Presentation only. No client-supplied coordinates can cause damage.
	pcall(_weapon_fx_handler, packet)
end

local function _attempt_kick(peer_id, reason)
	-- Realms 0.5.1 does not yet expose a public compatibility-rejection API.
	-- For this explicitly experimental build, use its guarded internal kick seam so
	-- the exact-version rule is real rather than a cosmetic warning. If that private
	-- seam changes, launch remains blocked and the failure is logged instead.
	if not M.is_host() then return false end
	local session = _realms and _realms._session
	if not session or type(session.can_kick_peer) ~= "function"
		or type(session.kick_peer) ~= "function" then
		_debug_log("realms_kick_missing", 0,
			"cannot reject " .. tostring(peer_id) .. ": " .. tostring(reason), 0, "warn")
		return false
	end
	local ok_can, can = pcall(session.can_kick_peer, peer_id)
	if not ok_can or not can then return false end
	local ok_kick, kicked = pcall(session.kick_peer, peer_id)
	return ok_kick and kicked == true
end

local function _reject_peer(peer_id, reason)
	local state = _peers[peer_id] or {}
	state.status = "incompatible"
	state.reason = reason
	_peers[peer_id] = state
	if M.is_host() then
		_shared.notify("Pilgrimage Realm rejected a player: " .. tostring(reason), "alert")
		_attempt_kick(peer_id, reason)
	end
end

local function _send_handshake(peer_id)
	local state = _peers[peer_id]
	if state then state.last_handshake_t = _clock end
	local sent, reason = _send(RPC_HANDSHAKE, peer_id,
		tostring(_mod.version), NETWORK_PROTOCOL, _content_schema())
	if not sent and M.is_host() then
		_reject_peer(peer_id,
			"Pilgrimage is missing or incompatible (" .. tostring(reason) .. ")")
	end
	return sent, reason
end

local function _send_rules(peer_id)
	if not M.is_host() then return false, "not host" end
	local rules = _settings_snapshot()
	_rules_revision = _rules_revision + 1
	_last_rules_signature = _rules_signature(rules)
	return _send(RPC_RULES, peer_id or "others", _rules_revision, rules)
end

local function _on_handshake(sender_peer_id, version, protocol, content_schema)
	local peer_id = _normalize_peer_id(sender_peer_id)
	if not peer_id then return end
	local state = _peers[peer_id] or {}
	state.version = tostring(version or "")
	state.protocol = tonumber(protocol)
	state.content_schema = tostring(content_schema or "")

	local reason
	if state.version ~= tostring(_mod.version) then
		reason = "internal Pilgrimage version " .. state.version
			.. " does not match host " .. tostring(_mod.version)
	elseif state.protocol ~= NETWORK_PROTOCOL then
		reason = "Pilgrimage network protocol does not match"
	elseif state.content_schema ~= _content_schema() then
		reason = "Pilgrimage gameplay content does not match"
	end

	if reason then
		_reject_peer(peer_id, reason)
		return
	end

	state.status = "compatible"
	state.reason = nil
	_peers[peer_id] = state
	if M.is_host() then _send_rules(peer_id) end
end

local function _on_rules(sender_peer_id, revision, rules)
	if not M.is_client() then return end
	if _normalize_peer_id(sender_peer_id) ~= _host_peer_id() then return end
	if type(rules) ~= "table" or tonumber(revision) == nil then return end

	local allowed = {
		cheat_mode = true,
		cheat_invulnerable = true,
		cheat_one_shot = true,
		custom_weapon_balancing = true,
		custom_weapon_balancing_meat_grinder = true,
	}
	local clean = {}
	for key in pairs(allowed) do
		if type(rules[key]) == "boolean" then clean[key] = rules[key] end
	end
	_settings.set_session_overrides(clean, tonumber(revision))
end

local function _remote_peer_count()
	local count = 0
	for _ in pairs(_peers) do count = count + 1 end
	return count
end

local function _on_peer_joined(peer_id)
	peer_id = _normalize_peer_id(peer_id)
	if not peer_id then return end
	_peers[peer_id] = { status = "pending", reason = "waiting for handshake" }

	-- The first Realm does not exist until the host presses Begin and Realms opens
	-- its preparation screen. The run is already marked active by then, so a
	-- run-state-only guard would reject every legitimate first-leg guest. Permit
	-- joins while no gameplay session exists, but continue refusing true hotjoins
	-- after the mission world has started because the prototype has no complete
	-- mid-mission run snapshot yet.
	local gameplay_session = Managers and Managers.state
		and Managers.state.game_session or nil
	if M.is_host() and _run_state and _run_state.is_active
		and _run_state.is_active() and gameplay_session ~= nil then
		_reject_peer(peer_id,
			"Pilgrimage hotjoin is unavailable after a run has started")
		return
	end

	if M.is_host() and _remote_peer_count() > MAX_GUESTS then
		_reject_peer(peer_id, "Pilgrimage experimental Realms mode supports three guests")
		return
	end

	-- Every peer exchanges the same tiny identity packet. That lets clients render
	-- the same compatibility state for one another while the host remains the only
	-- node allowed to admit, reject, or launch.
	_send_handshake(peer_id)
end

local function _on_peer_left(peer_id)
	peer_id = _normalize_peer_id(peer_id)
	if not peer_id then return end
	local was_host = peer_id ~= nil and peer_id == _host_peer_id()
	_peers[peer_id] = nil
	if M.is_client() and was_host then _settings.clear_session_overrides() end
end

local function _safe_player_name(player)
	if not player or type(player.name) ~= "function" then return "Player" end
	local ok, name = pcall(player.name, player)
	return ok and tostring(name or "Player") or "Player"
end

local function _safe_player_peer_id(player)
	if not player or type(player.peer_id) ~= "function" then return nil end
	local ok, peer_id = pcall(player.peer_id, player)
	return ok and _normalize_peer_id(peer_id) or nil
end

local function _human_rows()
	local rows = {}
	local manager = Managers and Managers.player or nil
	if not manager or type(manager.human_players) ~= "function" then return rows end
	local ok, players = pcall(manager.human_players, manager)
	if not ok or type(players) ~= "table" then return rows end
	for _, player in pairs(players) do
		local peer_id = _safe_player_peer_id(player)
		if peer_id then
			rows[#rows + 1] = {
				peer_id = peer_id,
				name = _safe_player_name(player),
			}
		end
	end
	table.sort(rows, function(a, b)
		return a.name == b.name and a.peer_id < b.peer_id or a.name < b.name
	end)
	return rows
end

function M.guest_slots()
	local slots = {}
	local host_peer_id = _host_peer_id()
	local guests = {}
	if M.is_active() then
		local rows = _human_rows()
		for i = 1, #rows do
			if rows[i].peer_id ~= host_peer_id then guests[#guests + 1] = rows[i] end
		end
	end

	for slot = 1, MAX_GUESTS do
		local guest = guests[slot]
		if guest then
			local peer = _peers[guest.peer_id] or {
				status = "pending", reason = "waiting for handshake",
			}
			slots[slot] = {
				slot = slot,
				occupied = true,
				name = guest.name,
				peer_id = guest.peer_id,
				status = peer.status or "pending",
				version = peer.version,
				reason = peer.reason,
			}
		else
			slots[slot] = { slot = slot, occupied = false, status = "open" }
		end
	end
	return slots
end

function M.human_occupant_for_bot_slot(slot)
	local entry = M.guest_slots()[tonumber(slot) or 0]
	return entry and entry.occupied and entry or nil
end

function M.host_name()
	local host_peer_id = _host_peer_id()
	local rows = _human_rows()
	for i = 1, #rows do
		if rows[i].peer_id == host_peer_id then return rows[i].name end
	end
	return M.is_host() and "Local host" or "Realm host"
end

function M.role()
	if M.is_host() then return "host" end
	if M.is_client() then return "client" end
	return "none"
end

function M.rules()
	return _settings_snapshot()
end

function M.can_launch()
	if not M.is_active() then return true end
	if not M.is_host() then return false, "only the Realm host can launch Pilgrimage" end
	if _remote_peer_count() > MAX_GUESTS then
		return false, "Pilgrimage experimental Realms mode supports three guests"
	end
	for peer_id, state in pairs(_peers) do
		if state.status ~= "compatible" then
			return false, "player " .. tostring(peer_id) .. " is "
				.. tostring(state.reason or state.status or "not synchronized")
		end
	end
	return true
end

function M.queue_mission_transition(mission_context)
	if not M.is_host() then return false, "only the Realm host can launch Pilgrimage" end
	if type(_realms.queue_mission_transition) ~= "function" then
		return false, "Realms mission-transition API unavailable"
	end
	local ok, queued, reason = pcall(_realms.queue_mission_transition,
		_mod, mission_context)
	if not ok then return false, tostring(queued) end
	return queued == true, reason
end

-- Realms normally learns this through MultiplayerSessionManager's
-- start_singleplayer_session hook. Pilgrimage follows SoloPlay's lower-level
-- reset + boot sequence, so provide the mission explicitly before the Realms
-- host listener is created. This affects only the initial Realm; later legs use
-- queue_mission_transition above.
function M.prepare_local_mission(mission_name)
	if not M.is_installed() then return false, "Realms not installed" end
	if type(mission_name) ~= "string" or mission_name == "" then
		return false, "invalid mission name"
	end
	local session = _realms and _realms._session
	if not session or type(session.prepare_local_mission) ~= "function" then
		return false, "Realms local-mission preparation API unavailable"
	end
	local ok, result = pcall(session.prepare_local_mission, mission_name)
	if not ok then return false, tostring(result) end
	return true
end

function M.broadcast_rules_if_changed()
	if not M.is_host() then return end
	local rules = _settings_snapshot()
	local signature = _rules_signature(rules)
	if signature ~= _last_rules_signature then _send_rules("others") end
end

function M.tick()
	_clock = _clock + 1
	local active = M.is_active()
	if _last_active and not active then
		_peers = {}
		_settings.clear_session_overrides()
	end
	_last_active = active
	if active then
		-- A callback can be replayed during the short interval in which Realms has
		-- discovered a peer but has not made its message channel available yet.
		-- Retry only pending handshakes, once per maintenance tick, rather than
		-- permanently leaving that peer in a cosmetic "checking" state.
		for peer_id, state in pairs(_peers) do
			if state.status == "pending"
				and (_clock - (state.last_handshake_t or -2)) >= 2 then
				_send_handshake(peer_id)
			end
		end
		M.broadcast_rules_if_changed()
	end
end

function M.try_install()
	if _installed then return true, "already installed" end
	local ok, realms = pcall(get_mod, "Realms")
	if not ok or type(realms) ~= "table" then return false, "Realms not installed" end
	if type(realms.network_register) ~= "function"
		or type(realms.network_on_peer_joined) ~= "function"
		or type(realms.network_on_peer_left) ~= "function"
		or type(realms.network_send) ~= "function" then
		return false, "Realms networking API unavailable"
	end

	_realms = realms
	local call_h, ok_h, why_h = pcall(realms.network_register,
		_mod, RPC_HANDSHAKE, _on_handshake)
	if not call_h or not ok_h then return false, tostring(why_h or ok_h) end
	local call_r, ok_r, why_r = pcall(realms.network_register,
		_mod, RPC_RULES, _on_rules)
	if not call_r or not ok_r then return false, tostring(why_r or ok_r) end
	local call_f, ok_f, why_f = pcall(realms.network_register,
		_mod, RPC_WEAPON_FX, _on_weapon_fx)
	if not call_f or not ok_f then return false, tostring(why_f or ok_f) end
	-- Peer callback registration immediately replays peers Realms already knows.
	-- Mark the bridge installed before that replay so is_active() can send them the
	-- handshake instead of mistaking the bridge for unavailable.
	_installed = true
	local call_j, ok_j, why_j = pcall(realms.network_on_peer_joined,
		_mod, _on_peer_joined)
	if not call_j or not ok_j then
		_installed = false
		return false, tostring(why_j or ok_j)
	end
	local call_l, ok_l, why_l = pcall(realms.network_on_peer_left,
		_mod, _on_peer_left)
	if not call_l or not ok_l then
		_installed = false
		return false, tostring(why_l or ok_l)
	end

	_last_active = M.is_active()
	return true, "Realms compatibility shell active"
end

function M.init(deps)
	_mod = deps.mod
	_settings = deps.settings
	_shared = deps.shared
	_run_state = deps.run_state
	_debug_log = deps.debug_log or function() end
end

M.NETWORK_PROTOCOL = NETWORK_PROTOCOL
M.MAX_GUESTS = MAX_GUESTS

return M
