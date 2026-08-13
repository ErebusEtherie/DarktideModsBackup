local mod = get_mod("HavocQuickplay")

local C = mod.C
local S = mod.S

local ORDER_TTL = 60

local function pick_best_order(order_data)
	if type(order_data) ~= "table" then
		return nil
	end

	local best, best_rank

	for i = 1, #order_data do
		local order = order_data[i]
		local data = order and order.data
		local rank = data and tonumber(data.rank)

		if rank and (not best_rank or best_rank < rank) then
			best = order
			best_rank = rank
		end
	end

	return best
end

local function attach_ongoing_mission(order)
	local havoc_service = Managers.data_service and Managers.data_service.havoc

	if not order or not havoc_service then
		return
	end

	havoc_service:check_ongoing_havoc():next(function(ongoing)
		if type(ongoing) ~= "table" then
			return
		end

		local valid = {}

		for i = 1, #ongoing do
			local entry = ongoing[i]

			if entry and not entry.depleted then
				valid[#valid + 1] = entry
			end
		end

		if #valid > 0 then
			order.ongoing_mission_id = valid[1].id
			order.ongoing_mission_start = valid[1].start
			order.participants = valid[1].eligibleParticipants
		end
	end):catch(function()
		return
	end)
end

mod.refresh_order = function(force)
	if S.order_pending then
		return
	end

	local now = mod.now()

	if not force and S.order and now - S.order_fetched_at < ORDER_TTL then
		return
	end

	local havoc_service = Managers.data_service and Managers.data_service.havoc

	if not havoc_service then
		return
	end

	S.order_pending = true

	havoc_service:refresh_havoc_unlock_status():next(function()
		local ok, status = pcall(havoc_service.get_havoc_unlock_status, havoc_service)

		S.unlock_status = ok and status or nil

		return havoc_service:summary()
	end):next(function(summary)
		local cadence = summary and summary.cadence_status

		S.cadence_active = cadence == nil or cadence.active ~= false

		return havoc_service:available_orders()
	end):next(function(order_data)
		S.order = pick_best_order(order_data)
		S.order_fetched_at = mod.now()
		S.order_pending = false

		attach_ongoing_mission(S.order)

		mod.debug("order refreshed: rank=%s unlock=%s cadence=%s",
			tostring(mod.my_rank()), tostring(S.unlock_status), tostring(S.cadence_active))

	end):catch(function(err)
		S.order_pending = false
		S.order_fetched_at = mod.now()

		mod.debug("order refresh failed: %s", tostring(err))
	end)
end

mod.my_order = function()
	return S.order
end

mod.my_rank = function()
	local order = S.order
	local data = order and order.data

	return data and tonumber(data.rank) or nil
end

mod.havoc_unlocked = function()
	return S.unlock_status == "unlocked"
end

mod.level_requirement_met = function()
	local level = mod.character_level()

	return level == nil or level >= C.HAVOC_MIN_LEVEL
end

local block_level_text, block_locked_text

mod.havoc_block_reason = function()
	if not mod.level_requirement_met() then
		block_level_text = block_level_text or mod.loc("hq_block_level")

		return block_level_text
	end

	if not mod.havoc_unlocked() then
		block_locked_text = block_locked_text or mod.loc("hq_block_not_unlocked")

		return block_locked_text
	end

	return nil
end

mod.build_advertise_config = function()
	local order = S.order

	if not order then
		return nil, nil
	end

	local blueprint = order.blueprint or {}
	local data = order.data or {}
	local order_id = order.id
	local rank = data.rank and tostring(data.rank)
	local mission_template = blueprint.template and blueprint.template.id
	local flags = blueprint.flags or {}
	local account_id = mod.local_account_id()

	if not order_id or not rank or not mission_template or not account_id or not next(flags) then
		return nil, nil
	end

	local config = {
		havoc_order_owner = account_id,
		havoc_order_id = order_id,
		havoc_order_rank = rank,
		havoc_mission_template = mission_template,
	}

	local threshold_tag
	local circ_counter = 1

	for flag, _ in pairs(flags) do
		if flag:find("^havoc%-circ%-") then
			config["havoc_circ_" .. circ_counter] = flag:sub(#"havoc-circ-" + 1)
			circ_counter = circ_counter + 1
		elseif flag:find("^havoc%-theme%-") then
			config.havoc_theme = flag:sub(#"havoc-theme-" + 1)
		elseif flag:find("^havoc%-threshold%-") then
			threshold_tag = flag:sub(#"havoc-threshold-" + 1)
		end
	end

	local tags = {}

	for i = 1, #C.BASE_TAGS do
		tags[i] = C.BASE_TAGS[i]
	end

	if threshold_tag and threshold_tag ~= "" then
		tags[#tags + 1] = threshold_tag
	end

	return config, tags
end

local function fetch_account_rank(account_id, on_resolved)
	S.rank_pending[account_id] = true

	local path = "/data/" .. account_id .. "/havoc/summary"

	Managers.backend:title_request(path, { method = "GET" }):next(function(response)
		S.rank_pending[account_id] = nil

		local body = response and response.body
		local current_order = body and (body.currentOrder or body.current_order)
		local rank = current_order and tonumber(current_order.rank)

		if rank then
			S.rank_cache[account_id] = { rank = rank, at = mod.now() }
		else
			S.rank_cache[account_id] = { none = true, at = mod.now() }
		end

		if on_resolved then
			on_resolved(account_id)
		end
	end):catch(function()
		S.rank_pending[account_id] = nil
		S.rank_cache[account_id] = { error_at = mod.now() }
	end)
end

mod.account_rank = function(account_id, on_resolved)
	if not account_id or account_id == "" or not Managers.backend then
		return nil, false
	end

	local now = mod.now()
	local cached = S.rank_cache[account_id]

	if cached and (now == 0 or now - (cached.at or 0) < C.RANK_TTL) then
		if cached.rank then
			return cached.rank, false
		end

		if cached.none then
			return nil, true
		end
	end

	local in_backoff = cached and cached.error_at and (now == 0 or now - cached.error_at < C.RANK_ERROR_BACKOFF)

	if not S.rank_pending[account_id] and not in_backoff then
		fetch_account_rank(account_id, on_resolved)
	end

	return nil, false
end
