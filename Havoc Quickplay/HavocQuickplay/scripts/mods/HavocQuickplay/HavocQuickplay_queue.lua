local mod = get_mod("HavocQuickplay")
local InputUtils = require("scripts/managers/input/input_utils")

local C = mod.C
local S = mod.S
local STATE = mod.STATE

mod.min_rank = function()
	return mod.clamp_rank(tonumber(mod.setting("hq_min_rank")) or C.MIN_HAVOC_RANK)
end

mod.max_rank = function()
	return mod.clamp_rank(tonumber(mod.setting("hq_max_rank")) or C.MAX_HAVOC_RANK)
end

mod.set_min_rank = function(value)
	value = mod.clamp_rank(value)

	mod:set("hq_min_rank", value)

	if mod.max_rank() < value then
		mod:set("hq_max_rank", value)
	end
end

mod.set_max_rank = function(value)
	value = mod.clamp_rank(value)

	mod:set("hq_max_rank", value)

	if value < mod.min_rank() then
		mod:set("hq_min_rank", value)
	end
end

mod.countdown_seconds = function()
	local seconds = tonumber(mod.setting("hq_countdown")) or C.COUNTDOWN

	if seconds < C.COUNTDOWN_MIN then
		seconds = C.COUNTDOWN_MIN
	elseif seconds > C.COUNTDOWN then
		seconds = C.COUNTDOWN
	end

	return math.floor(seconds)
end

local function decline_book()
	local id = mod.character_id()

	if id ~= C.UNKNOWN_CHARACTER and S.declines_character ~= id then
		if S.declines_character ~= nil then
			mod.debug("character changed, decline memory cleared")
		end

		S.declines_character = id

		for party_id in pairs(S.declines) do
			S.declines[party_id] = nil
		end
	end

	return S.declines
end

mod.remember_decline = function(party_id)
	if party_id then
		decline_book()[party_id] = mod.now()
	end
end

mod.was_declined = function(party_id)
	return decline_book()[party_id] ~= nil
end

mod.decline_count = function()
	local n = 0

	for _ in pairs(decline_book()) do
		n = n + 1
	end

	return n
end

mod.prune_declines = function()
	if next(S.declines) == nil then
		return
	end

	local now = mod.now()
	local book = decline_book()

	for party_id, at in pairs(book) do
		if now - at >= C.DECLINE_TTL then
			book[party_id] = nil
		end
	end
end

mod.blacklist_minutes = function()
	local minutes = tonumber(mod.setting("hq_blacklist_minutes")) or C.BLACKLIST_DEF_MIN

	if minutes < C.BLACKLIST_MIN_MIN then
		minutes = C.BLACKLIST_MIN_MIN
	elseif minutes > C.BLACKLIST_MAX_MIN then
		minutes = C.BLACKLIST_MAX_MIN
	end

	return math.floor(minutes)
end

mod.blacklist_ttl = function()
	return mod.blacklist_minutes() * 60
end

mod.blacklist_lobby = function(party_id)
	if not party_id then
		return false
	end

	S.blacklist[party_id] = mod.now()

	mod.debug("blacklisted %s", tostring(party_id))

	return true
end

mod.is_blacklisted = function(party_id)
	local at = party_id and S.blacklist[party_id]

	if not at then
		return false
	end

	if mod.now() - at >= mod.blacklist_ttl() then
		S.blacklist[party_id] = nil

		return false
	end

	return true
end

mod.blacklist_count = function()
	local n = 0

	for party_id in pairs(S.blacklist) do
		if mod.is_blacklisted(party_id) then
			n = n + 1
		end
	end

	return n
end

mod.leave_and_blacklist = function()
	if mod.other_members() < 1 then
		mod.say(mod.loc("hq_notify_not_in_lobby"))

		return false
	end

	mod.blacklist_lobby(mod.party_id())

	if S.hosting then
		mod.end_host_session()
	end

	local party_manager = mod.party()

	if party_manager and party_manager.leave_party then
		pcall(party_manager.leave_party, party_manager)
	end

	mod.say(mod.loc("hq_notify_blacklisted", mod.blacklist_minutes()))

	return true
end

local function keybind(setting_id)
	local keys = mod.setting(setting_id)

	if type(keys) ~= "table" or keys[1] == nil then
		return nil
	end

	return keys
end

local function cancel_keybind()
	return keybind("hq_cancel_keybind")
end

local function join_keybind()
	return keybind("hq_join_keybind")
end

mod.cancel_keybind = cancel_keybind

local function combo_text(keys)
	local parts = {}

	for i = #keys, 1, -1 do
		parts[#parts + 1] = string.upper(tostring(keys[i]))
	end

	return "[" .. table.concat(parts, " + ") .. "]"
end

local function cancel_key_text()
	local keys = cancel_keybind()

	if keys then
		return combo_text(keys)
	end

	local ok, text = pcall(InputUtils.input_text_for_current_input_device, "View", C.CANCEL_ACTION, true)

	return ok and text or "?"
end

local function show_notification(texts)
	if S.notif_id then
		Managers.event:trigger("event_update_notification_message", S.notif_id, texts)
	else
		Managers.event:trigger("event_add_notification_message", "matchmaking", {
			texts = texts,
		}, function(id)
			S.notif_id = id
		end)
	end
end

local function clear_notification()
	if S.notif_id then
		Managers.event:trigger("event_remove_notification", S.notif_id)

		S.notif_id = nil
	end
end

local function refresh_notification(force)
	local now = mod.now()

	if not force and now < S.notif_next_update then
		return
	end

	S.notif_next_update = now + 1

	if S.state == STATE.COUNTDOWN and S.countdown_ends_at then
		local seconds = math.max(0, math.ceil(S.countdown_ends_at - now))
		local join_keys = join_keybind()
		local prompt

		if join_keys then
			prompt = mod.loc("hq_found_join_cancel", combo_text(join_keys), cancel_key_text())
		else
			prompt = mod.loc("hq_found_cancel", cancel_key_text())
		end

		show_notification({
			mod.loc("hq_found_title"),
			mod.loc("hq_found_joining", seconds),
			prompt,
		})
	elseif S.state == STATE.SEARCHING then
		show_notification({
			mod.loc("hq_search_title"),
			mod.loc("hq_search_range", mod.min_rank(), mod.max_rank()),
			mod.loc("hq_search_cancel", cancel_key_text()),
		})
	end
end

local function stop_stream()
	local id = S.stream_id

	S.stream_id = nil

	if not id then
		return
	end

	local grpc = Managers.grpc

	if grpc and grpc.abort_operation then
		pcall(grpc.abort_operation, grpc, id)
	end
end

local function start_stream()
	if S.stream_id then
		return
	end

	local grpc = Managers.grpc
	local region = mod.region()

	if not grpc or not grpc.party_finder_list_advertisements_stream or not region then
		return
	end

	local ok, promise, id = pcall(grpc.party_finder_list_advertisements_stream, grpc, region, { "havoc", "my_havoc_order" })

	if not ok or not promise then
		return
	end

	S.stream_id = id

	promise:next(function()
		if S.stream_id == id then
			S.stream_id = nil
		end
	end):catch(function()
		if S.stream_id == id then
			S.stream_id = nil
		end
	end)

	mod.debug("stream open (%s)", tostring(region))
end

local function poll_stream()
	local id = S.stream_id

	if not id then
		return
	end

	local grpc = Managers.grpc

	if not grpc or not grpc.get_party_finder_list_advertisements_events then
		return
	end

	local ok, events = pcall(grpc.get_party_finder_list_advertisements_events, grpc, tostring(id))

	if not ok or type(events) ~= "table" then
		return
	end

	for i = 1, #events do
		local event = events[i]
		local event_type = event and event.type

		if event_type == "advertisement_entries_update" then
			local entries = event.entries or {}
			local listings = {}

			for j = 1, #entries do
				local entry = entries[j]
				local party_id = entry and entry.party_id

				if party_id then
					local previous = S.listings[party_id]

					listings[party_id] = {
						party_id = party_id,
						config = entry.config or {},
						tags = entry.tags or {},
						status = entry.status,
						members = previous and previous.members or nil,
					}
				end
			end

			S.listings = listings
		elseif event_type == "party_update" then
			local party = event.party
			local party_id = party and party.party_id
			local members = party and party.members
			local listing = party_id and S.listings[party_id]

			if listing and members then
				local connected = 0

				for k = 1, #members do
					if members[k].status == "CONNECTED" then
						connected = connected + 1
					end
				end

				listing.members = connected
			end
		end
	end
end

local function havoc_listing_rank(listing)
	local config = listing and listing.config
	local tags = listing and listing.tags

	if not config or not tags then
		return nil
	end

	local tagged = false

	for i = 1, #tags do
		if tags[i] == "my_havoc_order" then
			tagged = true

			break
		end
	end

	if not tagged then
		return nil
	end

	local rank = tonumber(config.havoc_order_rank)

	if not rank or rank < C.MIN_HAVOC_RANK or rank > C.MAX_HAVOC_RANK then
		return nil
	end

	return math.floor(rank)
end

mod.havoc_listing_rank = havoc_listing_rank

local function listing_members(listing)
	return listing and listing.members or 1
end

local function listing_matches(listing, own_party_id, own_size)
	if not listing then
		return false
	end

	if listing.status ~= nil and listing.status ~= "SEARCHING" then
		return false
	end

	if own_party_id and listing.party_id == own_party_id then
		return false
	end

	if mod.is_blacklisted(listing.party_id) then
		return false
	end

	local members = listing_members(listing)

	if members >= C.PARTY_MAX then
		return false
	end

	if own_size > 1 and members < own_size then
		return false
	end

	if mod.was_declined(listing.party_id) then
		return false
	end

	local rank = havoc_listing_rank(listing)

	if not rank then
		return false
	end

	return mod.min_rank() <= rank and rank <= mod.max_rank()
end

local function send_requests()
	local party_manager = mod.party()
	local account_id = mod.local_account_id()

	if not party_manager or not party_manager.send_request_to_join_party or not account_id then
		return
	end

	local own_party_id = mod.party_id()
	local own_size = mod.party_size()
	local sent = 0

	for _, listing in pairs(S.listings) do
		if listing_matches(listing, own_party_id, own_size) then
			local party_id = listing.party_id
			local stub = {
				id = party_id,
				description = "",
				tags = {},
				metadata = {},
				restrictions = {},
				version = 0,
				required_level = 0,
				level_requirement_met = true,
				hqp_auto = true,
			}

			local ok, promise = pcall(party_manager.send_request_to_join_party, party_manager, stub, account_id)

			if ok then
				sent = sent + 1
				S.requested[party_id] = mod.now()

				if promise then
					promise:next(function(response)
						if response and response.accepted == false then
							mod.remember_decline(party_id)
						end
					end):catch(function()
						mod.remember_decline(party_id)
					end)
				end
			end
		end
	end

	mod.debug("requested %d lobbies", sent)
end

local function decline_offer(party_id, invite_token)
	local grpc = Managers.grpc

	if grpc and grpc.cancel_invite_to_party then
		pcall(grpc.cancel_invite_to_party, grpc, party_id, invite_token, nil)
	end
end

local function decline_all_offers(except_party_id)
	for party_id, offer in pairs(S.offers) do
		if party_id ~= except_party_id then
			decline_offer(party_id, offer.invite_token)
		end
	end

	S.offers = {}
end

local function offer_count()
	local n = 0

	for _ in pairs(S.offers) do
		n = n + 1
	end

	return n
end

local function best_offer()
	local best, best_members

	for party_id, offer in pairs(S.offers) do
		local members = listing_members(S.listings[party_id])

		if not best_members or best_members < members then
			best = offer
			best_members = members
		end
	end

	return best
end

local join_best_offer

local function fills_party(party_id)
	return listing_members(S.listings[party_id]) + 1 >= C.PARTY_MAX
end

mod.fills_party = fills_party

mod.add_offer = function(party_id, invite_token)
	if mod.is_blacklisted(party_id) then
		mod.debug("refused a blacklisted offer from %s", tostring(party_id))
		decline_offer(party_id, invite_token)

		return
	end

	S.offers[party_id] = {
		party_id = party_id,
		invite_token = invite_token,
		at = mod.now(),
	}

	if fills_party(party_id) then
		S.countdown_ends_at = nil

		mod.debug("offer from %s fills the party, joining at once", tostring(party_id))
		join_best_offer()

		return
	end

	if S.state == STATE.SEARCHING then
		S.countdown_ends_at = mod.now() + mod.countdown_seconds()

		mod.set_state(STATE.COUNTDOWN)
		refresh_notification(true)
		mod.arm_taskbar_flash()
	end

	mod.debug("offer from %s (%d held)", tostring(party_id), offer_count())
end

join_best_offer = function()
	local offer = best_offer()

	if not offer then
		mod.set_state(STATE.SEARCHING)
		refresh_notification(true)

		return
	end

	local party_manager = mod.party()

	mod.set_state(STATE.JOINING)
	decline_all_offers(offer.party_id)
	stop_stream()
	clear_notification()

	if party_manager and party_manager.join_party then
		pcall(party_manager.join_party, party_manager, {
			party_id = offer.party_id,
			invite_token = offer.invite_token,
		})
	end

	if mod.in_mission() then
		S.left_mission_by_us = true
		S.left_mission_at = mod.now()
	end

	mod.say(mod.loc("hq_notify_joined"))
	mod.finish_queue()
end

mod.join_now_keybind = function()
	if S.state ~= STATE.COUNTDOWN then
		return
	end

	local ui_manager = Managers.ui

	if ui_manager and ui_manager.chat_using_input then
		local ok, typing = pcall(ui_manager.chat_using_input, ui_manager)

		if ok and typing then
			return
		end
	end

	S.countdown_ends_at = nil

	join_best_offer()
end

mod.can_queue = function()
	local blocked = mod.havoc_block_reason()

	if blocked then
		return false, blocked
	end

	if S.cadence_active == false then
		return false, mod.loc("hq_block_off_cadence")
	end

	if mod.in_havoc_mission() then
		return false, mod.loc("hq_block_in_havoc")
	end

	if S.queue_blocked then
		return false, mod.loc("hq_block_cancelled")
	end

	return true
end

mod.start_queue = function()
	if mod.is_queued() then
		return false
	end

	local allowed, reason = mod.can_queue()

	if not allowed then
		mod.say(reason)

		return false
	end

	S.listings = {}
	S.offers = {}
	S.requested = {}
	S.countdown_ends_at = nil
	S.next_request_at = mod.now() + C.STREAM_WARMUP
	S.next_refresh_at = nil
	S.notif_next_update = 0

	mod.set_state(STATE.SEARCHING)
	refresh_notification(true)

	return true
end

local function teardown()
	stop_stream()
	clear_notification()

	S.listings = {}
	S.countdown_ends_at = nil
	S.next_request_at = nil
	S.next_refresh_at = nil

	mod.set_state(STATE.IDLE)
end

mod.cancel_queue = function(message)
	if S.state == STATE.IDLE then
		return
	end

	decline_all_offers(nil)
	teardown()

	S.queue_blocked = not mod.in_hub()

	if message then
		mod.say(message)
	end
end

mod.finish_queue = function()
	S.offers = {}

	teardown()
end

local function cancel_pressed()
	if cancel_keybind() then
		return false
	end

	local ui_manager = Managers.ui

	if not ui_manager or not ui_manager.input_service then
		return false
	end

	local ok, input_service = pcall(ui_manager.input_service, ui_manager)

	if not ok or not input_service then
		return false
	end

	local pressed_ok, pressed = pcall(input_service.get, input_service, C.CANCEL_ACTION)

	return pressed_ok and pressed and true or false
end

mod.queue_update = function(dt)
	if cancel_pressed() then
		mod.cancel_queue(mod.loc("hq_notify_cancelled"))

		return
	end

	local now = mod.now()

	if S.state == STATE.COUNTDOWN and S.countdown_ends_at and now >= S.countdown_ends_at then
		S.countdown_ends_at = nil

		join_best_offer()

		return
	end

	refresh_notification(false)
end

mod.queue_sweep = function()
	if S.state ~= STATE.SEARCHING then
		return
	end

	poll_stream()
	start_stream()

	local now = mod.now()
	local interval = math.max(C.STREAM_WARMUP * 2, tonumber(mod.setting("hq_refresh_interval")) or 30)

	if S.next_request_at and now >= S.next_request_at then
		S.next_request_at = nil
		S.next_refresh_at = now + interval - C.STREAM_WARMUP

		send_requests()
	elseif S.next_refresh_at and now >= S.next_refresh_at then
		S.next_refresh_at = nil
		S.next_request_at = now + C.STREAM_WARMUP

		stop_stream()
		start_stream()
	end
end

mod.print_status = function()
	local listings = 0

	for _ in pairs(S.listings) do
		listings = listings + 1
	end

	mod:echo("state: %s   hosting: %s", tostring(S.state), tostring(S.hosting))
	mod:echo("assignment rank: %s", tostring(mod.my_rank()))
	mod:echo("range: %d - %d   countdown: %d s", mod.min_rank(), mod.max_rank(), mod.countdown_seconds())
	mod:echo("party: %d / %d", mod.party_size(), C.PARTY_MAX)
	mod:echo("listings: %d   offers held: %d", listings, offer_count())
	mod:echo("blacklisted lobbies: %d   declined lobbies: %d", mod.blacklist_count(), mod.decline_count())
end

mod:hook_safe(CLASS.PartyImmateriumManager, "send_request_to_join_party", function(self, data, account_id)
	local party_id = data and data.id

	if party_id and not data.hqp_auto then
		S.requested[party_id] = nil
	end
end)

mod:hook(CLASS.PartyImmateriumManager, "_handle_immaterium_invite", function(func, self, party_id, invite_token, inviter_account_id, ...)
	if mod:is_enabled() and inviter_account_id == C.SENTINEL_ACCOUNT then
		local ours = S.requested[party_id] ~= nil

		S.requested[party_id] = nil

		if mod.is_queued() then
			if self._close_invite_popup then
				pcall(self._close_invite_popup, self, party_id)
			end

			mod.add_offer(party_id, invite_token)

			return
		end

		if ours then
			if self._close_invite_popup then
				pcall(self._close_invite_popup, self, party_id)
			end

			decline_offer(party_id, invite_token)
			mod.debug("declined a stale acceptance from %s", tostring(party_id))

			return
		end
	end

	return func(self, party_id, invite_token, inviter_account_id, ...)
end)

local LEFT_MISSION_GRACE = 60

local function suppressing_reconnect()
	if not S.left_mission_by_us then
		return false
	end

	if mod.now() - (S.left_mission_at or 0) > LEFT_MISSION_GRACE then
		S.left_mission_by_us = false
		S.left_mission_at = nil

		return false
	end

	return true
end

mod:hook(CLASS.StateMainMenu, "_show_reconnect_popup", function(func, self, ...)
	if mod:is_enabled() and suppressing_reconnect() then
		mod.debug("suppressed main menu reconnect popup")

		return
	end

	return func(self, ...)
end)

mod:hook(CLASS.MechanismHub, "_show_retry_popup", function(func, self, ...)
	if mod:is_enabled() and suppressing_reconnect() then
		mod.debug("suppressed hub reconnect popup")

		return
	end

	return func(self, ...)
end)

local function is_havoc_vote(view)
	local mission_data = view and view._mission_data
	local flags = mission_data and mission_data.flags

	if type(flags) ~= "table" then
		return false
	end

	for flag in pairs(flags) do
		if type(flag) == "string" and flag:find("havoc-rank", 1, true) then
			return true
		end
	end

	return false
end

mod:hook_safe(CLASS.MissionVotingView, "on_enter", function(self)
	if not mod:is_enabled() or not mod.setting("hq_auto_accept_mission") then
		return
	end

	if not is_havoc_vote(self) then
		return
	end

	if self.cb_on_accept_mission_pressed then
		mod.debug("auto-accepting the havoc mission vote")
		pcall(self.cb_on_accept_mission_pressed, self)
	end
end)
