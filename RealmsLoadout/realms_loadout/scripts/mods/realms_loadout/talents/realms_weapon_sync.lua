-- Transport-independent session protocol for the Realms Loadout equipment
-- catalog. The structure mirrors realms_talent_sync.lua; the host-rules half
-- is intentionally absent because an equipment catalog is peer-owned read-only
-- data, so the exchange is only "client submits its equipped local items ->
-- host validates and stores them". The adapter is the only Realms boundary.
-- No engine network calls, timers or player objects are created here.
local Sync = {}
Sync.__index = Sync
-- Separate RPC from loadout_rules_v1 so the two features can version and be
-- disabled independently.
Sync.RPC = "loadout_weapons_v1"
Sync.VERSION = 1
Sync.DEPLOYMENT_VERSION = "0.5.4"
Sync.CATALOG_VERSION = 1
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
		serial = 0, retired_hosts = {}, departed = {}, next_hello = 0, next_catalog = 0, status = "local" }, Sync)
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
		self.peers, self.pending, self.retired_hosts, self.departed = {}, nil, {}, {}
		self.host_present = false
		self.client_token, self.host_token = self:nonce(), self:nonce()
		self.remote_host_token, self.last_host_message_at = nil, nil
		self.catalog_sequence, self.last_signature = 0, nil
		self.next_hello, self.next_catalog = self.now, self.now
		self.status = role == "client" and "connecting" or role
		self.a.reset(old_peers, role)
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
			self.peers[peer] = { status = "connecting", joined_at = self.now, retired = self.departed[peer] or {} }
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
		self.a.peer_left(peer)
	elseif self.role == "client" and peer == self.host then
		self.host_present = false
		self.pending, self.remote_host_token, self.last_host_message_at = nil, nil, nil
		self.client_token = self:nonce()
		self.status, self.last_signature = "disconnected", nil
		self.next_hello = self.now
	end
end

function Sync:queue_catalog()
	self.last_signature = nil
	self.pending = nil
	self.next_catalog = self.now
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
			member.client_ready = message.ready ~= false -- Older clients omit this diagnostic field.
			if member.client_token ~= message.client_session then
				if member.client_token then member.retired[member.client_token] = true end
				member.client_token, member.latest_request, member.last_result = message.client_session, 0, nil
				member.status, member.catalog_status = "syncing", nil
				self.a.peer_left(peer)
			end
			member.status = "synced"
			self:send(peer, { type = "hello_ack", host_session = self.host_token, client_session = member.client_token })
			return
		end
		if message.client_session ~= member.client_token or not member.client_token
			or message.host_session ~= self.host_token then return end
		member.last_seen = self.now
		if kind == "leave" then
			self.a.peer_left(peer)
			member.retired[member.client_token] = true
			member.client_token, member.last_result, member.catalog_status = nil, nil, nil
			member.status = "disabled"
		elseif kind == "catalog" and integer(message.request_id, 1) then
			if message.request_id < (member.latest_request or 0) then return end
			if message.request_id == member.latest_request and member.last_result then
				self:send(peer, member.last_result)
				return
			end
			local result = self.a.apply_catalog(peer, message.catalog)
			result = result or { accepted = false, retry = true, reason = "loading" }
			local response = { type = "catalog_result", host_session = self.host_token,
				client_session = member.client_token, request_id = message.request_id,
				accepted = result.accepted == true, retry = result.retry == true, reason = result.reason }
			member.latest_request = message.request_id
			-- A retryable result is re-evaluated when the same request comes back.
			member.last_result = not response.retry and response or nil
			member.catalog_status = response.retry and "loading" or response.accepted and "accepted" or "rejected"
			self:send(peer, response)
		end
	elseif self.role == "client" then
		if kind == "hello_request" and peer == self.host and self.host_present then
			self:send(self.host, self:hello_message())
			self.next_hello = self.now + RETRY
			return
		end
		if not self:valid_host_message(peer, message) then return end
		self.last_host_message_at = self.now
		if kind == "hello_ack" then
			local new_host_session = self.remote_host_token ~= message.host_session

			self.remote_host_token = message.host_session
			if self.status ~= "incompatible" and self.status ~= "accepted" then self.status = "synced" end
			-- A changed host session means the host restarted its bookkeeping,
			-- so the catalog has to be submitted again.
			if new_host_session then
				self.last_signature, self.pending = nil, nil
				self.next_catalog = self.now
			end
		elseif kind == "catalog_result" and self.pending
			and message.host_session == self.remote_host_token
			and message.request_id == self.pending.request_id and type(message.accepted) == "boolean" then
			if message.retry == true then
				self.status, self.next_catalog = "loading", self.now + RETRY
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
	if self.role == "client" and self.last_host_message_at and self.now - self.last_host_message_at > LEASE then
		self.last_host_message_at, self.pending, self.last_signature = nil, nil, nil
		self.status = "disconnected"
		self.client_token = self:nonce()
		self.remote_host_token = nil
		self.next_hello = self.now
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
		end
	elseif self.role == "client" then
		if not self.host_present then return end
		local ready = not self.a.local_ready or self.a.local_ready() == true
		if ready ~= self.local_ready then self.local_ready = ready; self.next_hello = self.now end
		if self.now >= self.next_hello then
			self:send(self.host, self:hello_message())
			local steady = self.status == "synced" or self.status == "accepted"
			self.next_hello = self.now + (steady and REFRESH or RETRY)
		end
		-- The catalog is only meaningful after the handshake, because every
		-- catalog message must carry the current host session token.
		if self.remote_host_token and self.now >= self.next_catalog then
			local catalog, signature = self.a.local_catalog()
			if catalog and signature then
				if (not self.pending or self.pending.signature ~= signature) and signature ~= self.last_signature then
					self.catalog_sequence = self.catalog_sequence + 1
					self.pending = { request_id = self.catalog_sequence, signature = signature,
						wire = { type = "catalog", host_session = self.remote_host_token, client_session = self.client_token,
							request_id = self.catalog_sequence, catalog = catalog } }
				end
				if self.pending then
					self:send(self.host, self.pending.wire)
					self.status = self.status == "loading" and "loading" or "submitting"
				end
			end
			self.next_catalog = self.now + RETRY
		end
	end
end

function Sync:close()
	if self.role == "client" and self.remote_host_token then
		self:send(self.host, { type = "leave", host_session = self.remote_host_token, client_session = self.client_token })
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
		elseif status == "synced" then status = member.catalog_status or "synced"
		end
	end
	return { status = status, version = member.version }
end

return Sync
