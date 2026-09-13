-- Transport-independent session protocol. The adapter is the only Realms boundary.
-- No engine network calls, timers or player objects are created here.
local Sync = {}
Sync.__index = Sync
-- v9 supports the full 103-point native Stimm Lab recipe.
-- Older editors/hosts enforce a narrower policy and must not acknowledge it.
Sync.RPC = "loadout_rules_v1"
Sync.VERSION = 9
Sync.DEPLOYMENT_VERSION = "0.5.4"
local RETRY = 1
local REFRESH = 5
local LEASE = 15

local function integer(value, minimum)
	return type(value) == "number" and value % 1 == 0 and value >= minimum and value < 2147483647
end

local function token(value)
	return type(value) == "string" and #value > 0 and #value <= 128
end

function Sync.new(adapter)
	return setmetatable({ a = adapter, role = "local", peers = {}, now = 0,
		serial = 0, retired_hosts = {}, departed = {}, next_hello = 0, next_build = 0, status = "local" }, Sync)
end

function Sync:nonce()
	self.serial = self.serial + 1
	return tostring(self.a.generation) .. ":" .. tostring(self.connection) .. ":" .. self.serial
end

function Sync:hello_message()
	return { type = "hello", client_session = self.client_token, version = Sync.DEPLOYMENT_VERSION,
		ready = not self.a.local_ready or self.a.local_ready() == true }
end

function Sync:context(context)
	local role = context.role or "local"
	local changed = self.connection ~= context.connection or self.role ~= role or self.host ~= context.host
	local became_ready = context.ready and not self.ready
	self.ready = context.ready == true
	if changed then
		local old_peers = self.peers
		self.connection, self.role, self.host = context.connection, role, context.host
		self.peers, self.rules, self.pending, self.retired_hosts, self.departed = {}, nil, nil, {}, {}
		self.host_present = false
		self.client_token, self.host_token = self:nonce(), self:nonce()
		self.remote_host_token, self.last_rules_at = nil, nil
		self.build_sequence, self.last_signature = 0, nil
		self.next_hello, self.next_build = self.now, self.now
		self.status = role == "client" and "connecting" or role
		self.a.reset(old_peers, role)
		self.a.rules_changed(nil, true)
	end
	if became_ready and role == "client" then self.next_hello = self.now end
	return changed
end

function Sync:send(peer, message)
	if not self.ready or not peer or self.role == "local" then return false end
	message.protocol = Sync.VERSION
	local ok, reason = self.a.send(peer, message)
	if not ok and reason == "target_rpc_unsupported" then
		if self.role == "client" then self.status = "incompatible"
		elseif self.peers[peer] then self.peers[peer].status = "incompatible" end
	end
	return ok, reason
end

function Sync:joined(peer)
	if not peer then return end
	if self.role == "host" then
		if not self.peers[peer] then
			self.peers[peer] = { status = "connecting", joined_at = self.now, next_rules = self.now, retired = self.departed[peer] or {} }
			self:send(peer, { type = "hello_request" })
		end
	elseif self.role == "client" and peer == self.host then
		self.host_present = true
		self.next_hello = self.now
	end
end

function Sync:left(peer)
	if self.role == "host" then
		local member = self.peers[peer]
		if member then
			if member.client_token then member.retired[member.client_token] = true end
			self.departed[peer] = member.retired
		end
		self.peers[peer] = nil
		self.a.peer_left(peer, false)
		if self.a.member_left then self.a.member_left(peer) end
	elseif self.role == "client" and peer == self.host then
		self.host_present = false
		self.rules, self.pending, self.remote_host_token = nil, nil, nil
		self.client_token = self:nonce()
		self.status, self.last_signature = "disconnected", nil
		self.next_hello = self.now
		self.a.rules_changed(nil, true)
	end
end

function Sync:publish(peer)
	local member = self.peers[peer]
	if not member or not member.client_token then return end
	local rules = self.a.host_rules(peer)
	self:send(peer, { type = "rules", host_session = self.host_token, client_session = member.client_token,
		revision = rules.revision, enabled = rules.enabled, points = rules.realms_player_points,
		auras = rules.unlock_all_auras, keystones = rules.unlock_all_keystones, stimm_points = rules.stimm_points or -1 })
	member.next_rules = self.now + RETRY
end

function Sync:rules_updated(target)
	for peer, member in pairs(self.peers) do
		if not target or target == peer then
		member.ack_revision = nil
		member.status = member.status == "incompatible" and member.status or "syncing"
		member.build_status = nil
		member.next_rules = self.now
		end
	end
end

function Sync:queue_build()
	self.last_signature = nil
	self.pending = nil
	self.next_build = self.now
end

function Sync:valid_host_message(peer, message)
	return self.role == "client" and self.host_present and peer == self.host and message.client_session == self.client_token
		and token(message.host_session)
end

function Sync:receive(peer, message)
	if not self.ready or type(message) ~= "table" or message.protocol ~= Sync.VERSION then return end
	local kind = message.type
	if self.role == "host" then
		local member = self.peers[peer]
		-- Only Realms' current membership events admit a peer, never a packet itself.
		if not member then return end
		if kind == "hello" and token(message.client_session) then
			if member.retired[message.client_session] then return end
			member.last_seen = self.now
			member.version = type(message.version) == "string" and #message.version <= 40 and message.version or nil
			member.client_ready = message.ready ~= false -- Older v6 clients omit this diagnostic field.
			if member.client_token ~= message.client_session then
				if member.client_token then member.retired[member.client_token] = true end
				member.client_token, member.latest_request, member.last_result = message.client_session, 0, nil
				member.ack_revision, member.status = nil, "syncing"
				member.build_status = nil
				self.a.peer_left(peer)
			end
			self:publish(peer)
			return
		end
		if message.client_session ~= member.client_token or not member.client_token
			or message.host_session ~= self.host_token then return end
		member.last_seen = self.now
		local current = self.a.host_rules(peer)
		if kind == "rules_ack" and message.revision == current.revision then
			member.ack_revision, member.status = message.revision, "synced"
		elseif kind == "leave" then
			self.a.peer_left(peer)
			member.retired[member.client_token] = true
			member.client_token, member.last_result, member.ack_revision = nil, nil, nil
			member.status = "disabled"
			member.build_status = nil
		elseif kind == "build" and integer(message.request_id, 1) then
			if message.revision ~= current.revision then self:publish(peer); return end
			if message.request_id < (member.latest_request or 0) then return end
			if message.request_id == member.latest_request and member.last_result then
				self:send(peer, member.last_result)
				return
			end
			local result
			if not current.enabled then result = { accepted = false, reason = "disabled" }
			else result = self.a.apply_build(peer, message.build) end
			result = result or { accepted = false, retry = true, reason = "loading" }
			local response = { type = "build_result", host_session = self.host_token,
				client_session = member.client_token, request_id = message.request_id, revision = current.revision,
				accepted = result.accepted == true, retry = result.retry == true, reason = result.reason }
			member.latest_request = message.request_id
			-- A retryable result is re-evaluated when the same request comes back.
			member.last_result = not response.retry and response or nil
			member.build_status = response.retry and "loading" or response.accepted and "accepted" or "rejected"
			self:send(peer, response)
		end
	elseif self.role == "client" then
		if kind == "hello_request" and peer == self.host and self.host_present then
			self:send(self.host, self:hello_message())
			self.next_hello = self.now + RETRY
			return
		end
		if not self:valid_host_message(peer, message) then return end
		if kind == "rules" then
			if not integer(message.stimm_points, -1) or message.stimm_points > 103
                or not integer(message.revision, 1) or not integer(message.points, 30) or message.points > 99
				or type(message.enabled) ~= "boolean" or type(message.auras) ~= "boolean"
				or type(message.keystones) ~= "boolean" or self.retired_hosts[message.host_session] then return end
			local previous = self.rules
			if message.host_session ~= self.remote_host_token then
				if self.remote_host_token then self.retired_hosts[self.remote_host_token] = true end
				self.remote_host_token, self.pending, self.last_signature = message.host_session, nil, nil
				previous = nil
			end
			if previous and message.revision < previous.revision then return end
			self.last_rules_at = self.now
			self:send(peer, { type = "rules_ack", host_session = self.remote_host_token,
				client_session = self.client_token, revision = message.revision })
			if not previous or previous.revision ~= message.revision then
				self.rules = { enabled = message.enabled, revision = message.revision,
					realms_player_points = message.points, unlock_all_auras = message.auras,
					unlock_all_keystones = message.keystones, stimm_points = message.stimm_points }
				self.pending, self.last_signature = nil, nil
				self.status = message.enabled and "synced" or "disabled"
				self.next_build = self.now
				self.a.rules_changed(self.rules, not previous)
			end
		elseif kind == "build_result" and self.pending and self.rules
			and message.host_session == self.remote_host_token and message.revision == self.rules.revision
			and message.request_id == self.pending.request_id and type(message.accepted) == "boolean" then
			if message.retry == true then
				self.status, self.next_build = "loading", self.now + RETRY
			else
				self.status = message.accepted and "accepted" or "rejected"
				self.last_signature, self.pending = self.pending.signature, nil
			end
		end
	end
end

function Sync:update(dt)
	self.now = self.now + math.max(0, dt or 0)
	-- Expiry still runs while the transport is unavailable.
	if self.role == "client" and self.rules and self.now - self.last_rules_at > LEASE then
		self.rules, self.pending, self.last_signature = nil, nil, nil
		self.status = "disconnected"
		self.a.rules_changed(nil, false)
	end
	if not self.ready then return end
	if self.role == "host" then
		for peer, member in pairs(self.peers) do
			local status = self:deployment(peer).status
			if status == "synced" or status == "accepted" then member.warned = nil
			elseif self.a.warn_peer and (status == "incompatible" or status == "unavailable" or status == "disconnected" or status == "disabled"
				or status == "loading" and self.now - member.joined_at > 8)
				and member.warned ~= status then
				member.warned = status; self.a.warn_peer(peer, status)
			end
			if member.client_token and member.status ~= "incompatible" and not member.ack_revision
				and self.now >= member.next_rules then self:publish(peer) end
		end
	elseif self.role == "client" then
		if not self.host_present then return end
		local ready = not self.a.local_ready or self.a.local_ready() == true
		if ready ~= self.local_ready then self.local_ready = ready; self.next_hello = self.now end
		if self.now >= self.next_hello then
			self:send(self.host, self:hello_message())
			self.next_hello = self.now + ((self.rules or self.status == "incompatible") and REFRESH or RETRY)
		end
		if self.rules and self.rules.enabled and self.now >= self.next_build then
			local build, signature = self.a.local_build()
			if build and signature then
				if (not self.pending or self.pending.signature ~= signature) and signature ~= self.last_signature then
					self.build_sequence = self.build_sequence + 1
					self.pending = { request_id = self.build_sequence, signature = signature,
						wire = { type = "build", host_session = self.remote_host_token, client_session = self.client_token,
							request_id = self.build_sequence, revision = self.rules.revision, build = build } }
				end
				if self.pending then
					self:send(self.host, self.pending.wire)
					self.status = self.status == "loading" and "loading" or "submitting"
				end
			end
			self.next_build = self.now + RETRY
		end
	end
end

function Sync:close()
	if self.role == "client" and self.remote_host_token then
		self:send(self.host, { type = "leave", host_session = self.remote_host_token, client_session = self.client_token })
	elseif self.role == "host" then
		-- The adapter marks host rules disabled before close, so guests receive the withdrawal.
		for peer in pairs(self.peers) do self:publish(peer) end
	end
	self.pending = nil
end

function Sync:deployment(peer)
	local member = self.peers[peer]
	if not member then return { status = "connecting" } end
	local status = member.status
	if status ~= "disabled" and status ~= "incompatible" then
		if member.last_seen and self.now - member.last_seen > LEASE then status = "disconnected"
		elseif not member.last_seen and self.now - (member.joined_at or self.now) > 8 then status = "unavailable"
		elseif member.client_ready == false then status = "loading"
		elseif status == "synced" then status = member.build_status or "synced" end
	end
	return { status = status, version = member.version }
end

return Sync
