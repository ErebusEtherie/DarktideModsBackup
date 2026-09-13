-- Realms transport adapter. Only the host generates rewards or accepts builds.
local Coordinator = {}
local RPC = "mortis_session_v10"
local function finite(n) return type(n) == "number" and n == n and n > -math.huge and n < math.huge end
local function player_name(value)
    local result=""
    for c in tostring(value):gmatch("[%z\1-\127\194-\244][\128-\191]*")do if #result+#c>128 then break end;result=result..c end
    return result
end
local function normalize(peer) return peer and string.lower(tostring(peer)) end
function Coordinator.new(mod, Draft, api, shared)
	local max_presentation_delay = math.ceil(Draft.max_points * (Draft.selection_time + Draft.reveal_time))
	local self = { now = 0, elapsed = 0, request_serial = 0, sequence = 0, peers = {}, role = "local",
		known_characters = {}, seen_kills = setmetatable({}, { __mode = "k" }), run_serial = 0 }
	local function players() return api.players() or {} end
	local function peer_player(peer, id)
		for _, player in pairs(players()) do
			if normalize(player:peer_id()) == normalize(peer) and player:local_player_id() == id then return player end
		end
	end
	local function send(peer, packet)
		local realms = api.realms()
		if not mod:is_enabled() or not self.connection or self.role == "local" or not realms
			or type(realms.network_is_available) ~= "function" or not realms.network_is_available() then return false end
		packet.protocol = 10
		local ok, reason = realms.network_send(mod, RPC, peer, packet)
		if self.role == "host" and reason == "target_rpc_unsupported" then
			self.peer_state[peer] = self.peer_state[peer] or { since = self.now }
			self.peer_state[peer].status = "incompatible"
		end
		return ok, reason
	end
	function self:context()
		local connection, role, host = api.context()
		host = normalize(host)
		if connection == self.connection and role == self.role and host == self.host then return end
		self.connection, self.role, self.host = connection, role, host
		self.run, self.mission, self.run_mode = nil, nil, nil
		shared.session_rules, shared.remote_selections = nil, {}
		self.remote, self.pending_choice, self.request_nonce = nil, nil, nil
		self.host_epoch = nil
		self.last_sequence, self.elapsed, self.peers, self.enrolled = 0, 1, {}, {}
		self.peer_state, self.retired_requests = {}, {}
		self.request_at, self.last_received = 0, nil
		self.known_characters = {}
		shared.session_serial = (shared.session_serial or 0) + 1
		self.epoch = tostring(shared.session_serial)
		self.registered = nil
		self.snapshot_cache, self.sent = nil, {}
        self.compatibility_cache,self.compatibility_at,self.compatibility_manifest=nil,nil,nil
	end
	function self:rules()
		if self.role == "client" then return shared.session_rules end
		return api.rules()
	end
    function self:compatibility()
        if not api.diy_manifest or not api.diy_availability then return nil end
        local manifest,library=api.diy_manifest()
        if self.compatibility_cache and self.compatibility_manifest==manifest and self.compatibility_at and self.now-self.compatibility_at<.5 then return self.compatibility_cache end
        local peers={}
        if self.role=="host" then for _,player in pairs(players())do if player~=api.local_player() then
            local peer=normalize(player:peer_id());local record=self.peer_state and self.peer_state[peer]
            local profile=player:profile();local name=profile and profile.name or peer
            local reason
            if record and record.status=="disabled" then reason=3
            elseif not record or not record.last_seen then reason=record and self.now-record.since>8 and 5 or 4
            elseif self.now-record.last_seen>8 then reason=6
            elseif record.character~=player:character_id() then reason=4
            elseif not record.manifest then reason=5 end
            peers[#peers+1]={peer=peer,name=player_name(name),manifest=record and record.manifest,reason=reason}
        end end end
        table.sort(peers,function(a,b)return a.peer<b.peer end)
        local next_value=api.diy_availability(library,manifest,peers)
        if not self.compatibility_cache or not api.same_availability(self.compatibility_cache,next_value) then self.compatibility_cache=next_value end
        self.compatibility_at=self.now;self.compatibility_manifest=manifest
        return self.compatibility_cache
    end
	function self:ensure_run()
		local rules, mission = api.rules(), api.mission()
		local mode = rules.enabled and rules.mode ~= "preselect" and rules.mode or nil
		if self.role == "client" then return end
		if mission ~= self.mission or mode ~= self.run_mode then
			self.mission, self.run_mode = mission, mode
			self.run, self.seen_kills = nil, setmetatable({}, { __mode = "k" })
			if mission and mode then
				self.run_serial = self.run_serial + 1
				self.run = Draft.new((self.epoch or "local") .. "/" .. self.run_serial, mode)
			end
		end
	end
	function self:host_snapshot(player)
		if not self.run or not player then return end
		local record = Draft.player(self.run, api.key(player))
		return Draft.snapshot(self.run, record, api.rules().limit, record.suspended_at or self.now)
	end
	function self:eligible(player)
		if player == api.local_player() then return true end
		local seen = self.enrolled and self.enrolled[normalize(player:peer_id())]
		return self.role == "host" and seen ~= nil and self.now - seen <= 8
	end
	function self:deployment(peer)
		peer = normalize(peer)
		local player = api.local_player()
		if player and normalize(player:peer_id()) == peer then
			return { status = api.assets_ready() and "ready" or "loading_assets", version = api.version }
		end
		local record = self.peer_state and self.peer_state[peer]
		if not record then return { status = "connecting" } end
		local status = record.status or "connecting"
		if (status == "ready" or status == "loading_assets") and record.last_seen and self.now - record.last_seen > 8 then status = "disconnected"
		elseif status == "connecting" and self.now - record.since > 8 then status = "unavailable" end
		return { status = status, version = record.version }
	end
	local function state_to(peer, request)
		local player = peer_player(peer, 1)
		local rules = api.rules()
		local record = self.run and player and Draft.player(self.run, api.key(player))
		self.sent = self.sent or {}
		self.sent[peer] = { run = self.run, character = player and player:character_id(),
			version = record and record.version, earned = self.run and self.run.earned,
			suspended = record and record.suspended_at, revision = rules.revision }
		self.sequence = self.sequence + 1
		return send(peer, { kind = "state", epoch = self.epoch, sequence = self.sequence,
			request = request, rules = rules, character = player and player:character_id(), draft = self:host_snapshot(player) })
	end
	function self:changed()
		self:context(); self:ensure_run()
		if self.run then for _, record in pairs(self.run.players) do
			if record.exhausted then record.exhausted = false; record.version = record.version + 1 end
		end end
		if self.role == "host" then for peer in pairs(self.peers) do state_to(peer) end end
		shared.pending_selection_submit = self.role == "client"
	end
	local function valid_rules(rules)
		return type(rules) == "table" and type(rules.enabled) == "boolean" and finite(rules.limit)
			and rules.limit % 1 == 0 and rules.limit >= 0 and rules.limit <= Draft.max_points
			and (rules.mode == "preselect" or rules.mode == "draft" or rules.mode == "competition")
			and rules.limit == Draft.limit(rules.mode, rules.limit)
			and finite(rules.revision) and (not api.valid_bans or api.valid_bans(rules.bans))
            and (not api.valid_availability or api.valid_availability(rules.diy_availability))
            and (not api.valid_availability or type(rules.native_enabled)=="boolean" and type(rules.diy_enabled)=="boolean"
                and type(rules.locked)=="boolean" and api.valid_limits(rules.diy_limits))
	end
	local function valid_draft(draft, rules)
		if draft == nil then return true end
		if type(draft) ~= "table" or type(draft.epoch) ~= "string" or not finite(draft.version)
			or not finite(draft.earned) or not finite(draft.spent) or not finite(draft.queued)
			or not finite(draft.progress) or type(draft.selected) ~= "table" or #draft.selected > Draft.buff_limit("competition", Draft.max_points) then return false end
		if draft.counting ~= nil and type(draft.counting) ~= "boolean" then return false end
        if draft.skip_family~=nil and type(draft.skip_family)~="boolean" then return false end
		if draft.completed ~= nil and (not finite(draft.completed) or draft.completed % 1 ~= 0
			or draft.completed < 0 or draft.completed > Draft.max_points) then return false end
		if draft.family ~= nil and not api.known_family(draft.family) then return false end
		if draft.mode ~= rules.mode or draft.mode == "preselect" or draft.limit ~= Draft.buff_limit(rules.mode, rules.limit)
			or draft.earned % 1 ~= 0 or draft.earned < 0 or draft.earned > rules.limit
			or draft.spent ~= math.min(#draft.selected, draft.limit)
			or draft.queued % 1 ~= 0 or draft.queued < 0 or draft.queued > draft.earned then return false end
		local selected = {}
		for _, name in ipairs(draft.selected) do
			if not api.known(name) or selected[name] then return false end; selected[name] = true
		end
		if draft.rewards ~= nil then
			if type(draft.rewards) ~= "table" or #draft.rewards > Draft.buff_limit("competition", Draft.max_points) then return false end
			local last = 0
			for _, reward in ipairs(draft.rewards) do
				if type(reward) ~= "table" or not finite(reward.id) or reward.id % 1 ~= 0 or reward.id <= last
					or reward.id > Draft.buff_limit("competition", Draft.max_points) or not selected[reward.name] or not finite(reward.round)
					or reward.round % 1 ~= 0 or reward.round < 1 or reward.round > rules.limit then return false end
				last = reward.id
			end
		end
		local active = draft.active
		if active then
			if type(active) ~= "table" or type(active.id) ~= "string" or not finite(active.remaining)
				or active.remaining < 0 or active.remaining > 60 or type(active.choices) ~= "table"
				or #active.choices < 1 or #active.choices > 3 then return false end
			if active.delay ~= nil and (not finite(active.delay) or active.delay < 0 or active.delay > max_presentation_delay) then return false end
			if active.kind ~= "family" and active.kind ~= "legendary" then return false end
				if active.kind == "family" and draft.family~=nil or active.kind=="legendary" and draft.family==nil and draft.skip_family~=true then return false end
			local seen = {}
			for _, name in ipairs(active.choices) do
				local known = active.kind == "family" and api.known_family(name) or active.kind == "legendary" and api.known(name)
				if not known or seen[name] or selected[name] then return false end; seen[name] = true
			end
		end
		return true
	end
	function self:receive(peer, packet)
		if not mod:is_enabled() or type(packet) ~= "table" or packet.protocol ~= 10 then return end
		self:context(); self:ensure_run(); peer = normalize(peer)
		if self.role == "host" then
			-- A packet cannot create membership or revive an old client session.
			if not peer_player(peer, 1) then return end
			if packet.kind == "request" and type(packet.request) == "string" and #packet.request < 100 then
				if self.retired_requests[peer] and self.retired_requests[peer][packet.request] then return end
				local record = self.peer_state[peer] or { since = self.now }
				if record.request and record.request ~= packet.request then
					self.retired_requests[peer] = self.retired_requests[peer] or {}
					self.retired_requests[peer][record.request] = true
				end
				record.status = packet.assets_ready == true and "ready" or "loading_assets"
				record.last_seen = self.now
				record.version = type(packet.version) == "string" and #packet.version <= 40 and packet.version or nil
				record.request = packet.request; self.peer_state[peer] = record
                local player=peer_player(peer,1)
                record.character=packet.character
                record.manifest=player and packet.character==player:character_id() and api.valid_manifest and api.valid_manifest(packet.diy_manifest) and packet.diy_manifest or nil
                self.compatibility_at=nil
				self.enrolled[peer] = packet.assets_ready == true and self.now or nil
				self.peers[peer] = true; state_to(peer, packet.request)
			elseif type(packet.session) ~= "string" or not self.peer_state[peer] or packet.session ~= self.peer_state[peer].request then return
			elseif packet.kind == "leave" and packet.epoch == self.epoch then
                self.compatibility_at=nil
                if self.peer_state[peer] then self.peer_state[peer].manifest=nil end
				self.enrolled[peer] = nil; shared.remote_selections[peer] = nil
				self.retired_requests[peer] = self.retired_requests[peer] or {}
				self.retired_requests[peer][packet.session] = true
				if self.peer_state[peer] then self.peer_state[peer].status = "disabled" end
			elseif packet.epoch == self.epoch and packet.kind == "build" then
				local payload = packet.build
				if type(payload) ~= "table" or payload.local_player_id ~= 1 then return end
				local player = peer_player(peer, 1)
				if not player or not self:eligible(player) or player:character_id() ~= payload.character_id or player:archetype_name() ~= payload.archetype then return end
				if not api.rules().enabled or api.rules().mode ~= "preselect" then return end
				local accepted = api.accept(player, payload)
				send(peer, { kind = "build_result", epoch = self.epoch, character = payload.character_id, accepted = accepted })
			elseif packet.epoch == self.epoch and packet.kind == "choose" then
				local player = peer_player(peer, 1)
				if not player or not self:eligible(player) or player:character_id() ~= packet.character then return end
				self:choose(player, packet.id, packet.index)
				state_to(peer)
			end
		elseif self.role == "client" and peer == self.host then
			local player = api.local_player()
			if packet.kind == "state" then
				if not player or packet.character ~= player:character_id() or not valid_rules(packet.rules)
					or not valid_draft(packet.draft, packet.rules) or type(packet.epoch) ~= "string" or not finite(packet.sequence) then return end
				local handshake = self.request_nonce and packet.request == self.request_nonce
				if not handshake and (not shared.session_rules or packet.epoch ~= self.host_epoch) then return end
				local incoming_epoch, previous_epoch = tonumber(packet.epoch), tonumber(self.host_epoch)
				if not incoming_epoch or previous_epoch and incoming_epoch < previous_epoch then return end
				if packet.epoch == self.host_epoch and packet.sequence <= self.last_sequence then return end
				local previous = shared.session_rules
				self.host_epoch, self.last_sequence = packet.epoch, packet.sequence
				self.last_received = self.now
				shared.session_rules = packet.rules
				self.remote, self.received_at = packet.draft, self.now
				if not previous or previous.revision ~= packet.rules.revision then shared.pending_selection_submit = true end
				if self.pending_choice and (not packet.draft or not packet.draft.active
					or packet.draft.active.id ~= self.pending_choice.id) then
					self.pending_choice = nil
				end
			elseif packet.kind == "build_result" and packet.epoch == self.host_epoch and player
				and packet.character == player:character_id() and packet.accepted == true then
				shared.pending_selection_submit = false
			end
		end
	end
	function self:register()
		local realms = api.realms()
		if self.registered == realms or not realms or type(realms.network_register) ~= "function" then return end
		if not realms.network_register(mod, RPC, function(peer, packet) self:receive(peer, packet) end) then return end
		self.registered = realms
		if realms.network_on_peer_joined then realms.network_on_peer_joined(mod, function(peer)
			if not mod:is_enabled() then return end
			self:context(); peer = normalize(peer); self.peers[peer] = true
            self.compatibility_at=nil
			if self.role == "host" then state_to(peer) else self.elapsed = 1 end
		end) end
		if realms.network_on_peer_left then realms.network_on_peer_left(mod, function(peer)
			peer = normalize(peer); self.peers[peer] = nil; self.enrolled[peer] = nil; shared.remote_selections[peer] = nil
            self.compatibility_at=nil
			local record = self.peer_state[peer]
			if record and record.request then
				self.retired_requests[peer] = self.retired_requests[peer] or {}
				self.retired_requests[peer][record.request] = true
			end
			self.peer_state[peer] = nil
			-- Drafts stay keyed to peer + character until this mission ends.
			if self.role == "client" and peer == self.host then
				shared.session_rules, self.remote, self.pending_choice = nil, nil, nil
				self.request_nonce, self.request_at = nil, 0
			end
		end) end
	end
	function self:choose(player, id, index)
		if not mod:is_enabled() then return false end
		if self.role == "client" then
			if self.last_received and self.now - self.last_received > 8 then
				shared.session_rules, self.remote, self.pending_choice = nil, nil, nil
			end
			if not self.remote or not self.remote.active or self.remote.active.id ~= id then return false end
			self.pending_choice = { kind = "choose", epoch = self.host_epoch, session = self.request_nonce, id = id, index = index, character = player:character_id() }
			local sent = send(self.host, self.pending_choice)
			return sent
		end
		if not self.run or not api.rules().enabled or not self:eligible(player) then return false end
		local pool = api.pool(player)
		if not pool then return false end
		local accepted = Draft.choose(self.run, Draft.player(self.run, api.key(player)), id, index, api.rules().limit, pool, self.now, math.random)
		return accepted
	end
	function self:event(key)
		self:ensure_run()
		if self.run and self.run.mode == "draft" then
			local fraction = api.progress()
			if type(fraction) == "number" then Draft.progress(self.run, fraction)
			else Draft.event(self.run, key) end
		end
	end
	function self:kill(player, unit, contribution)
		if self.role == "client" or not self.run or self.run.mode ~= "competition" or not self:eligible(player) or self.seen_kills[unit] then return end
		local record = Draft.player(self.run, api.key(player))
		local limit = api.rules().limit
		if not Draft.counting(record, limit) then return end
		self.seen_kills[unit] = true
		Draft.kill(record, contribution, limit)
	end
	function self:counting(player,unit)
		if self.role == "client" or not self.run or self.run.mode ~= "competition" then return false end
		if unit and self.seen_kills[unit] then return false end
		return self:eligible(player) and Draft.counting(Draft.player(self.run, api.key(player)), api.rules().limit)
	end
	function self:snapshot()
		if not mod:is_enabled() then return end
		if self.role == "client" then
			if not shared.session_rules or not shared.session_rules.enabled then return end
			return self.remote, self.now - (self.received_at or self.now), self.pending_choice ~= nil
		end
		local player = api.local_player()
		if not self.run or not player then return end
		local record = Draft.player(self.run, api.key(player))
		local limit, cached = api.rules().limit, self.snapshot_cache
		local now = record.suspended_at or self.now
		if not cached or cached.run ~= self.run or cached.record ~= record or cached.version ~= record.version
			or cached.earned ~= self.run.earned or cached.limit ~= limit or cached.suspended ~= record.suspended_at then
			cached = { run = self.run, record = record, version = record.version, earned = self.run.earned,
				limit = limit, suspended = record.suspended_at, at = now, value = Draft.snapshot(self.run, record, limit, now) }
			self.snapshot_cache = cached
		end
		return cached.value, math.max(0, now - cached.at), false
	end
	function self:update(dt)
		self.now = self.now + dt; self:context()
		if self.role == "client" and self.last_received and self.now - self.last_received > 8 then
			shared.session_rules, self.remote, self.pending_choice = nil, nil, nil
		end
		self.elapsed = self.elapsed + dt
		if self.elapsed < 0.5 then return end
		self.elapsed = 0
		-- Keep connection/lease changes immediate; mission discovery and RPC
		-- registration share the existing reward tick instead of every frame.
		self:register(); self:ensure_run()
		local rules = api.rules()
		if self.run then
			if self.run.mode == "draft" then Draft.progress(self.run, api.progress()) end
			local active_keys = {}
			for _, player in pairs(players()) do
				if api.ready(player) and self:eligible(player) then
					local key = api.key(player); active_keys[key] = true
					local record = Draft.player(self.run, key)
					local setup = api.setup and api.setup(player)
					if setup ~= record.setup then
						record.setup = setup
						if record.exhausted then record.exhausted = false; record.version = record.version + 1 end
					end
					if record.suspended_at then
						local paused = self.now - record.suspended_at
                        if record.active then
                            record.active.deadline = record.active.deadline + paused
                            if record.active.ready_at then record.active.ready_at = record.active.ready_at + paused end
                            if record.presentation_until then record.presentation_until = record.presentation_until + paused end
                        end
						record.suspended_at = nil
					end
					-- A backend exclusion can change without replacing the talent
					-- table. Revisit an empty pool occasionally, but never after quota.
					if record.exhausted and record.earned < rules.limit and self.now >= (record.pool_check_at or 0) then
						record.pool_check_at = self.now + 5
						local pool = api.pool(player)
						if pool and pool ~= record.pool then
							record.exhausted = false; record.version = record.version + 1
						end
					end
					if Draft.needs_tick(self.run, record, rules.limit) then
						local pool = api.pool(player)
						if pool then record.pool = pool; Draft.tick(self.run, record, rules.limit, pool, self.now, math.random) end
					end
				end
			end
			-- Missing/unready peers retain their own cards and remaining time.
			-- Other players' timers and reward queues continue independently.
			for key, record in pairs(self.run.players) do
				if not active_keys[key] and not record.suspended_at then record.suspended_at = self.now end
			end
		end
		if self.role == "client" then
			local player = api.local_player(); local character = player and player:character_id()
			if character ~= self.character then
				self.character = character; shared.session_rules = nil; self.remote = nil; self.pending_choice = nil
				self.request_nonce = nil; self.request_at = 0; shared.pending_selection_submit = true
			end
			if not self.request_nonce then
				self.request_serial = self.request_serial + 1
				self.request_nonce = (self.epoch or "") .. ":" .. self.request_serial
			end
			if self.now >= (self.request_at or 0) then
				send(self.host, { kind = "request", request = self.request_nonce, version = api.version, assets_ready = api.assets_ready(),
                    character=character,diy_manifest=api.diy_manifest and api.diy_manifest() }); self.request_at = self.now + 2
			end
			if shared.session_rules and shared.session_rules.enabled and shared.session_rules.mode == "preselect"
				and shared.pending_selection_submit then
				send(self.host, { kind = "build", epoch = self.host_epoch, session = self.request_nonce, build = api.payload() })
			end
			if self.pending_choice then send(self.host, self.pending_choice) end
		elseif self.role == "host" then
			local connected_peers = {}
			for _, player in pairs(players()) do
				if player ~= api.local_player() then
					local peer = normalize(player:peer_id()); connected_peers[peer] = true
					local record = self.peer_state[peer] or { status = "connecting", since = self.now }
					self.peer_state[peer] = record
					local status = self:deployment(peer).status
					if status == "ready" then record.warned = nil
					elseif api.warn_peer and self.now - record.since > 8 and record.warned ~= status then
						record.warned = status; api.warn_peer(player, status)
					end
				end
			end
			self.peers = connected_peers
			-- Send changes promptly. Client requests still provide a two-second
			-- heartbeat/resync and the eight-second disconnect lease is unchanged.
			if self.run then for peer in pairs(self.peers) do
				local player = peer_player(peer, 1)
				local record = player and self.run.players[api.key(player)]
				local sent = self.sent and self.sent[peer]
				if not sent or sent.run ~= self.run or sent.revision ~= rules.revision
					or sent.character ~= (player and player:character_id()) or sent.earned ~= self.run.earned
					or sent.version ~= (record and record.version) or sent.suspended ~= (record and record.suspended_at) then state_to(peer) end
			end end
		end
	end
	function self:cleanup()
		if self.role == "client" and self.connection and self.host_epoch then
			local realms = api.realms()
			if realms and realms.network_is_available and realms.network_is_available() then
				realms.network_send(mod, RPC, self.host, { protocol = 10, kind = "leave", epoch = self.host_epoch, session = self.request_nonce })
			end
		end
		if self.role == "host" then
			local realms = api.realms()
			if realms and self.connection and realms.network_is_available and realms.network_is_available() then
				for peer in pairs(self.peers) do
					local player = peer_player(peer, 1)
					local rules = {}; for key, value in pairs(api.rules()) do rules[key] = value end
					rules.enabled = false
					self.sequence = self.sequence + 1
					realms.network_send(mod, RPC, peer, { protocol = 10, kind = "state", epoch = self.epoch,
						sequence = self.sequence, character = player and player:character_id(), rules = rules })
				end
			end
		end
		self.run, self.remote, self.mission, self.run_mode, self.pending_choice = nil, nil, nil, nil, nil
		self.connection, self.host, self.host_epoch, self.registered = nil, nil, nil, nil
		self.role, self.peers, self.request_nonce = "local", {}, nil
		shared.session_rules, shared.remote_selections = nil, {}
	end
	return self
end
return Coordinator
