-- Single owner of the Realms peer-joined / peer-left registration.
--
-- Realms' ModNetwork keeps exactly ONE callback per mod name for each peer
-- event (Realms/core/mod_network.lua:471-487 stores callbacks[mod_name], and
-- :52-58 notifies that single entry). realms_loadout now runs two session
-- protocols - talents and equipment catalogs - and when both called
-- network_on_peer_joined/left with the same mod object, the later registration
-- silently replaced the earlier one. The replaced protocol then never received
-- "peer joined", never started its handshake, and looked permanently unable to
-- sync with the host.
--
-- Every module must subscribe here instead of calling Realms directly.
local mod = get_mod("realms_loadout")
if mod._realms_peer_events then return mod._realms_peer_events end

local PeerEvents = {
	joined_callbacks = {},
	left_callbacks = {},
	realms = nil,
}

local function dispatch(callbacks, peer)
	for _, callback in pairs(callbacks) do
		local ok, err = pcall(callback, peer)

		if not ok then
			mod:warning("realms_loadout peer event callback failed: %s", tostring(err))
		end
	end
end

local function on_joined(peer)
	dispatch(PeerEvents.joined_callbacks, peer)
end

local function on_left(peer)
	dispatch(PeerEvents.left_callbacks, peer)
end

-- Registers the shared dispatcher with Realms. Idempotent per Realms object;
-- safe to call from every module on every update.
function PeerEvents.install(realms)
	if not realms or type(realms.network_on_peer_joined) ~= "function"
		or type(realms.network_on_peer_left) ~= "function" then
		return false
	end

	if PeerEvents.realms == realms then
		return true
	end

	PeerEvents.realms = realms

	realms.network_on_peer_joined(mod, on_joined)
	realms.network_on_peer_left(mod, on_left)

	return true
end

-- Re-registering the dispatcher makes Realms replay its currently known peers
-- to us. That is how a protocol that subscribes (or re-subscribes after a
-- session change) learns about the members that are already present.
function PeerEvents.refresh()
	local realms = PeerEvents.realms

	if not realms then
		return false
	end

	realms.network_on_peer_joined(mod, on_joined)

	return true
end

function PeerEvents.set_joined(key, callback)
	PeerEvents.joined_callbacks[key] = callback
	PeerEvents.refresh()
end

function PeerEvents.set_left(key, callback)
	PeerEvents.left_callbacks[key] = callback
end

mod._realms_peer_events = PeerEvents

return PeerEvents
