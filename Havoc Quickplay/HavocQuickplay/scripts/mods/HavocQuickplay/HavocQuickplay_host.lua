local mod = get_mod("HavocQuickplay")
local Promise = require("scripts/foundation/utilities/promise")

local C = mod.C
local S = mod.S

mod.can_host = function()
	local order = S.order

	if not order or not mod.my_rank() then
		return false
	end

	if S.cadence_active == false then
		return false
	end

	if order.ongoing_mission_id then
		return true
	end

	local charges = tonumber(order.charges)

	return charges == nil or charges > 0
end

mod.start_host = function()
	if S.hosting or S.host_pending then
		return false
	end

	local blocked = mod.havoc_block_reason()

	if blocked then
		mod.say(blocked)

		return false
	end

	if mod.in_mission() then
		mod.say(mod.loc("hq_block_host_in_mission"))

		return false
	end

	if not mod.can_host() then
		mod.say(mod.loc("hq_block_no_order"))

		return false
	end

	local party_manager = mod.party()

	if not party_manager or not party_manager.start_party_finder_advertise then
		return false
	end

	local config, tags = mod.build_advertise_config()
	local region = mod.region()

	if not config or not tags or not region then
		mod.say(mod.loc("hq_notify_host_failed"))

		return false
	end

	S.host_pending = true
	S.host_autostart_off = false
	S.host_seen_active = false
	S.host_launched = false

	local ok, promise = pcall(party_manager.start_party_finder_advertise, party_manager, config, tags, region)

	if not ok or not promise then
		S.host_pending = false

		return false
	end

	promise:next(function()
		S.host_pending = false
		S.hosting = true
		S.host_party_id = mod.party_id()

		mod.say(mod.loc("hq_notify_host_started"))
		mod.debug("hosting rank %s in %s", tostring(mod.my_rank()), tostring(region))
	end):catch(function(err)
		S.host_pending = false
		S.hosting = false

		mod.say(mod.loc("hq_notify_host_failed"))
		mod.debug("advertise failed: %s", tostring(err))
	end)

	return true
end

mod.stop_host = function()
	if not S.hosting then
		return
	end

	S.hosting = false
	S.host_party_id = nil
	S.host_autostart_off = false
	S.host_seen_active = false
	S.host_launched = false

	local party_manager = mod.party()

	if party_manager and party_manager.cancel_party_finder_advertise then
		pcall(party_manager.cancel_party_finder_advertise, party_manager)
	end
end

local function open_slots()
	return math.max(0, C.PARTY_MAX - mod.party_size())
end

local function havoc_status_of(join_request)
	local presence = join_request and join_request.presence

	if not presence or not presence.havoc_status then
		return nil
	end

	local ok, status = pcall(presence.havoc_status, presence)

	return ok and status or nil
end

local function respond(party_id, account_id, accept)
	local party_manager = mod.party()

	if not party_manager or not party_manager.party_finder_respond_to_join_request then
		return false
	end

	local ok = pcall(party_manager.party_finder_respond_to_join_request, party_manager, party_id, account_id, accept)

	if ok then
		mod.debug("%s %s", accept and "accepted" or "declined", tostring(account_id))
	end

	return ok
end

local function decide(join_request)
	local status = havoc_status_of(join_request)

	if status ~= nil and status ~= "ok" then
		return "decline"
	end

	local rank, resolved_none = mod.account_rank(join_request.account_id)

	if resolved_none then
		return "decline"
	end

	if not rank then
		return "wait"
	end

	if rank < mod.min_rank() or rank > mod.max_rank() then
		return "decline"
	end

	return "accept"
end

local function all_members_in_hub()
	local party_manager = mod.party()

	if not party_manager or not party_manager.are_all_members_in_hub then
		return false
	end

	local ok, value = pcall(party_manager.are_all_members_in_hub, party_manager)

	return ok and value or false
end

mod.launch_mission = function()
	local order = mod.my_order()
	local havoc_service = Managers.data_service and Managers.data_service.havoc

	if not order or not havoc_service then
		return
	end

	local activate

	if order.ongoing_mission_id then
		activate = Promise.resolved({ id = order.ongoing_mission_id })
	else
		activate = havoc_service:activate_havoc_mission(order.id)
	end

	activate:next(function(mission)
		if not mission or not mission.id then
			mod.say(mod.loc("hq_notify_launch_failed"))

			return
		end

		order.ongoing_mission_id = mission.id

		local party_manager = mod.party()

		if party_manager and party_manager.wanted_mission_selected then
			pcall(party_manager.wanted_mission_selected, party_manager, mission.id, false, mod.region())
		end
	end):catch(function(err)
		mod.debug("activate failed: %s", tostring(err))
		mod.say(mod.loc("hq_notify_launch_failed"))
	end)
end

local function try_auto_start()
	if S.host_launched or S.host_autostart_off then
		return
	end

	if not mod.setting("hq_auto_start") then
		return
	end

	if mod.party_size() < C.PARTY_MAX then
		return
	end

	if not mod.can_host() or not all_members_in_hub() then
		return
	end

	S.host_launched = true

	mod.say(mod.loc("hq_notify_auto_start"))
	mod.launch_mission()
end

local function end_host_session()
	S.hosting = false
	S.host_party_id = nil
	S.host_seen_active = false
	S.host_launched = false
	S.host_autostart_off = false
end

mod.end_host_session = end_host_session

mod.host_sweep = function()
	if not S.hosting then
		return
	end

	local party_id = mod.party_id()
	local party_manager = mod.party()

	if not party_id or not party_manager or not party_manager.advertisement_request_to_join_list then
		return
	end

	if S.host_party_id and party_id ~= S.host_party_id then
		mod.debug("party changed, host session over")
		end_host_session()

		return
	end

	local advertising = false
	local active_ok, active = pcall(party_manager.is_party_advertisement_active, party_manager)

	if active_ok and active then
		advertising = true
		S.host_seen_active = true
	end

	local auto_accept = mod.setting("hq_auto_accept")
	local auto_decline = mod.setting("hq_auto_decline")

	if auto_accept or auto_decline then
		local ok, requests = pcall(party_manager.advertisement_request_to_join_list, party_manager)

		if ok and type(requests) == "table" then
			local slots = open_slots()

			for account_id, join_request in pairs(requests) do
				if join_request.presence_synced then
					local verdict = decide(join_request)

					if verdict == "accept" and auto_accept and slots > 0 then
						if respond(party_id, account_id, true) then
							slots = slots - 1
						end
					elseif verdict == "decline" and auto_decline then
						respond(party_id, account_id, false)
					end
				end
			end
		end
	end

	try_auto_start()

	if S.host_seen_active and not advertising then
		mod.debug("advertisement ended, host session over")
		end_host_session()
	end
end

mod:hook_safe(CLASS.PartyImmateriumManager, "_handle_party_vote_update_event", function(self, event)
	if not S.hosting or not event then
		return
	end

	if event.state == "COMPLETED_REJECTED" or event.state == "FAILED_TIMEOUT" then
		S.host_autostart_off = true

		mod.debug("auto-start disabled until re-host (vote %s)", tostring(event.state))
	end
end)
