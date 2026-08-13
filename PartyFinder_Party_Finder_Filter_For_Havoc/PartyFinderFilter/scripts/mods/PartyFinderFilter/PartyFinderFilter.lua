local mod = get_mod("PartyFinderFilter")

mod._info = {
	title = "Party Finder Filter",
	author = "Huesos",
	date = "2026/06/25",
	version = "2.2.1",
}
mod:info("Version " .. mod._info.version)

local PLATFORM_PSN = "psn"
local DECLINE_COOLDOWN = 10
local HAVOC_TTL = 300
local HAVOC_ERROR_BACKOFF = 30

mod._pending = {}
mod._havoc = {}
mod._havoc_pending = {}
mod._own_listing_party_id = nil
mod._own_listing_was_active = false

local function _now()
	local ok, t = pcall(function()
		return Managers.time:time("main")
	end)

	return ok and t or 0
end

local function _localize_game(loc_key, fallback)
	if loc_key then
		local ok, text = pcall(Localize, loc_key)

		if ok and text and text ~= "" then
			return text
		end
	end

	return fallback
end

local function _request_profile(join_request)
	local presence = join_request and join_request.presence

	if not presence then
		return nil, nil
	end

	local ok, profile = pcall(presence.character_profile, presence)

	if not ok or not profile then
		return nil, nil
	end

	local archetype = profile.archetype

	if not archetype or not archetype.name then
		return nil, nil
	end

	return profile, archetype
end

local function _character_name(join_request)
	local presence = join_request.presence
	local ok, character_name = pcall(presence.character_name, presence)

	return ok and character_name or "???"
end

local function _platform(join_request)
	local presence = join_request and join_request.presence

	if not presence then
		return nil
	end

	local ok, platform = pcall(presence.platform, presence)

	return ok and platform or nil
end

local function _class_title(archetype)
	return _localize_game(archetype.archetype_name, archetype.name)
end

local function _decline_account(account_id)
	local party_immaterium = Managers.party_immaterium
	local party_id = mod._own_listing_party_id

	if not party_immaterium or not party_id then
		return false
	end

	local ok, err = pcall(function()
		return party_immaterium:party_finder_respond_to_join_request(party_id, account_id, false)
	end)

	if not ok then
		mod:warning("decline failed: %s", tostring(err))

		return false
	end

	return true
end

local function _havoc_below_threshold(rank)
	local min_havoc_rank = mod:get("min_havoc_rank")

	return min_havoc_rank and min_havoc_rank > 0 and rank < min_havoc_rank
end

local function _havoc_enforce(account_id, rank, character_name, class_title)
	if not mod._own_listing_party_id or not mod:get("filter_enabled") then
		return
	end

	if not _havoc_below_threshold(rank) then
		return
	end

	local t = _now()
	local sent_at = mod._pending[account_id]

	if sent_at and (t == 0 or t - sent_at < DECLINE_COOLDOWN) then
		return
	end

	if _decline_account(account_id) then
		mod._pending[account_id] = t

		if mod:get("show_notification") then
			mod:notify(mod:localize("declined_notify_havoc", character_name or "???", class_title or "???"))
		end
	end
end

local function _havoc_fetch(account_id, character_name, class_title)
	mod._havoc_pending[account_id] = true

	local path = "/data/" .. account_id .. "/havoc/summary"

	Managers.backend:title_request(path, { method = "GET" }):next(function(data)
		mod._havoc_pending[account_id] = nil

		local body = data and data.body
		local current_order = body and (body.currentOrder or body.current_order)
		local rank = current_order and tonumber(current_order.rank)

		if rank then
			mod._havoc[account_id] = { rank = rank, at = _now() }
			_havoc_enforce(account_id, rank, character_name, class_title)
		else
			mod._havoc[account_id] = { error_at = _now() }
		end
	end):catch(function()
		mod._havoc_pending[account_id] = nil
		mod._havoc[account_id] = { error_at = _now() }
	end)
end

local function _havoc_rank(account_id, character_name, class_title)
	if not account_id or account_id == "" or not Managers.backend then
		return nil
	end

	local now = _now()
	local cached = mod._havoc[account_id]

	if cached and cached.rank and (now == 0 or now - cached.at < HAVOC_TTL) then
		return cached.rank
	end

	local in_backoff = cached and cached.error_at and (now == 0 or now - cached.error_at < HAVOC_ERROR_BACKOFF)

	if not mod._havoc_pending[account_id] and not in_backoff then
		_havoc_fetch(account_id, character_name, class_title)
	end

	return cached and cached.rank or nil
end

local function _present_archetypes()
	local present = {}
	local party_immaterium = Managers.party_immaterium

	if not party_immaterium or not party_immaterium.all_members then
		return present
	end

	local ok, members = pcall(party_immaterium.all_members, party_immaterium)

	if not ok or type(members) ~= "table" then
		return present
	end

	for _, member in pairs(members) do
		if member and member.archetype_name then
			local ok_name, archetype_name = pcall(member.archetype_name, member)

			if ok_name and archetype_name then
				present[archetype_name] = true
			end
		end
	end

	return present
end

local function _allowed_abilities(archetype_name)
	local labels = mod._abilities_by_archetype and mod._abilities_by_archetype[archetype_name]

	if not labels then
		return nil
	end

	local allowed

	for talent_id in pairs(labels) do
		if mod:get("allow_ability_" .. archetype_name .. "_" .. talent_id) then
			allowed = allowed or {}
			allowed[talent_id] = true
		end
	end

	return allowed
end

local function _build_has_allowed_ability(profile, allowed)
	local talents = profile.talents

	if not talents then
		return false
	end

	for talent_id in pairs(allowed) do
		local points = talents[talent_id]

		if points and points ~= 0 then
			return true
		end
	end

	return false
end

local function _decline_reason(profile, archetype, platform, present, account_id, character_name, class_title)
	if mod:get("decline_ps5") and platform == PLATFORM_PSN then
		return "ps5"
	end

	local min_havoc_rank = mod:get("min_havoc_rank")

	if min_havoc_rank and min_havoc_rank > 0 then
		local rank = _havoc_rank(account_id, character_name, class_title)

		if rank and rank < min_havoc_rank then
			return "havoc"
		end
	end

	local archetype_name = archetype.name

	if mod:get("filter_" .. archetype_name) then
		return "class"
	end

	if mod:get("unique_" .. archetype_name) and present[archetype_name] then
		return "duplicate"
	end

	local allowed = _allowed_abilities(archetype_name)

	if allowed and not _build_has_allowed_ability(profile, allowed) then
		return "ability"
	end

	return nil
end

local function _filter_allowed(view)
	if not mod:get("filter_enabled") then
		return false
	end

	local own_party_id = mod._own_listing_party_id

	if not own_party_id then
		return false
	end

	local current_party_id = view.party_id and view:party_id()

	return current_party_id ~= nil and current_party_id == own_party_id
end

local function _auto_declined(join_request, present)
	local profile, archetype = _request_profile(join_request)

	if not profile then
		return false
	end

	local account_id = join_request.account_id

	if not account_id then
		return false
	end

	local platform = _platform(join_request)
	local character_name = _character_name(join_request)
	local class_title = _class_title(archetype)
	local reason = _decline_reason(profile, archetype, platform, present, account_id, character_name, class_title)

	if not reason then
		return false
	end

	local t = _now()
	local sent_at = mod._pending[account_id]

	if sent_at and (t == 0 or t - sent_at < DECLINE_COOLDOWN) then
		return true
	end

	if _decline_account(account_id) then
		mod._pending[account_id] = t

		if mod:get("show_notification") then
			if reason == "ps5" then
				mod:notify(mod:localize("declined_notify_ps5", character_name, class_title))
			elseif reason == "havoc" then
				mod:notify(mod:localize("declined_notify_havoc", character_name, class_title))
			elseif reason == "duplicate" then
				mod:notify(mod:localize("declined_notify_duplicate", character_name, class_title))
			elseif reason == "ability" then
				mod:notify(mod:localize("declined_notify_ability", character_name, class_title))
			else
				mod:notify(mod:localize("declined_notify_class", character_name, class_title))
			end
		end

		return true
	end

	return false
end

local function _forget_own_listing()
	mod._own_listing_party_id = nil
	mod._own_listing_was_active = false
end

local PARTY_MANAGER_HOOKS = {
	start_party_finder_advertise = function(self)
		local ok, party_id = pcall(self.party_id, self)

		mod._own_listing_party_id = ok and party_id or nil
		mod._own_listing_was_active = false
		mod._pending = {}
	end,
	cancel_party_finder_advertise = function(self)
		_forget_own_listing()
	end,
	_reset_party_data = function(self)
		_forget_own_listing()
	end,
	_handle_advertisement_state_update_event_trigger = function(self)
		if not mod._own_listing_party_id then
			return
		end

		local active = self.is_party_advertisement_active and self:is_party_advertisement_active()

		if active then
			mod._own_listing_was_active = true
		elseif mod._own_listing_was_active then
			_forget_own_listing()
		end
	end,
}

local party_manager_class = rawget(_G, "CLASS") and CLASS.PartyImmateriumManager

if party_manager_class then
	for method, fn in pairs(PARTY_MANAGER_HOOKS) do
		if party_manager_class[method] then
			mod:hook_safe(party_manager_class, method, fn)
		else
			mod:warning("PartyImmateriumManager.%s not found, own-listing tracking degraded", method)
		end
	end
else
	mod:warning("CLASS.PartyImmateriumManager not found, 'own listing' guard unavailable")
end

mod:hook(CLASS.GroupFinderView, "_populate_player_request_grid", function(func, self, join_requests, ...)
	if not join_requests or #join_requests == 0 then
		return func(self, join_requests, ...)
	end

	if not _filter_allowed(self) then
		return func(self, join_requests, ...)
	end

	local present = _present_archetypes()
	local filtered = {}

	for i = 1, #join_requests do
		local join_request = join_requests[i]

		if not _auto_declined(join_request, present) then
			filtered[#filtered + 1] = join_request
		end
	end

	return func(self, filtered, ...)
end)

mod:hook_safe(CLASS.GroupFinderView, "on_exit", function(self)
	mod._pending = {}
end)
