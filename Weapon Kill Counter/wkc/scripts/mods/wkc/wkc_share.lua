local mod = get_mod("wkc")

local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")

local MOD_ID = "wkc.kills"
local PAYLOAD_VERSION = 1
local POLL_INTERVAL = 2
local SLOTS = { "slot_primary", "slot_secondary" }
local INSPECT_FIELDS = { "_preview_player", "_player" }

local manifold = nil
local unsubscribe = nil
local payload = nil
local signature = nil
local poll_t = 0
local peer_rev = -1
local peer_cache = nil
local gear_map = nil
local announced = {}

mod._share_rev = 0

local function local_player()
	local pm = Managers and Managers.player
	if not (pm and pm.local_player_safe) then return nil end
	local ok, player = pcall(pm.local_player_safe, pm, 1)
	if not ok or type(player) ~= "table" then return nil end
	return player
end

local function account_id_of(obj)
	if type(obj) ~= "table" or type(obj.account_id) ~= "function" then return nil end
	local ok, id = pcall(obj.account_id, obj)
	if not ok or type(id) ~= "string" or id == "" then return nil end
	return id
end

local function display_name_of(obj)
	if type(obj) ~= "table" then return nil end
	if type(obj.name) == "function" then
		local ok, n = pcall(obj.name, obj)
		if ok and type(n) == "string" and n ~= "" then return n end
	elseif type(obj.name) == "string" and obj.name ~= "" then
		return obj.name
	end
	return nil
end

local function loadout_of(player)
	local ok, profile = pcall(player.profile, player)
	if not (ok and type(profile) == "table") then return nil end
	local loadout = profile.loadout
	if type(loadout) ~= "table" then return nil end
	return loadout
end

local function item_in_slot(player, slot_name)
	local player_unit = player.player_unit
	if player_unit and ALIVE[player_unit] then
		local visual = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
		if visual and visual.item_in_slot then
			local ok, live = pcall(visual.item_in_slot, visual, slot_name)
			if ok and type(live) == "table" then return live end
		end
	end

	local loadout = loadout_of(player)
	local item = loadout and loadout[slot_name]
	if type(item) == "table" then return item end

	return nil
end

local function template_of(item)
	local ok, template = pcall(WeaponTemplate.weapon_template_from_item, item)
	if not (ok and type(template) == "table") then return nil end
	local name = template.name
	if type(name) ~= "string" or name == "" or name == "unarmed" then return nil end
	return name
end

local function build()
	local player = local_player()
	if not player then return nil end

	local weapons, found = {}, false
	for i = 1, #SLOTS do
		local item = item_in_slot(player, SLOTS[i])
		local name = item and template_of(item)
		if name then
			local bucket = mod._bucket_for(name, item)
			weapons[name] = (bucket and bucket.kills) or 0
			found = true
		end
	end

	if not found then return nil end
	local p = { v = PAYLOAD_VERSION, w = weapons }
	if mod._per_instance() then p.i = true end
	return p
end
mod._share_build = build

local function signature_of(p)
	local parts = {}
	for name, kills in pairs(p.w) do
		parts[#parts + 1] = name .. "=" .. kills
	end
	table.sort(parts)
	return table.concat(parts, ",") .. (p.i and "|i" or "")
end

local function in_mission()
	local gm = Managers and Managers.state and Managers.state.game_mode
	if not (gm and gm.game_mode_name) then return false end
	local ok, name = pcall(gm.game_mode_name, gm)
	if not ok then return false end
	local modes = mod._MISSION_GAME_MODES
	return (modes and modes[name]) == true
end

function mod._share_bump()
	mod._share_rev = mod._share_rev + 1
end

function mod._share_refresh()
	if not manifold then return end
	local p = build()
	if not p then return end
	local sig = signature_of(p)
	if sig == signature then return end
	signature = sig
	payload = p
	manifold.mark_dirty(MOD_ID)
end

local function other_players()
	local out = {}
	local pm = Managers and Managers.player
	if not (pm and pm.players) then return out end
	local ok, players = pcall(pm.players, pm)
	if not (ok and type(players) == "table") then return out end

	local me = local_player()
	local my_account = account_id_of(me)
	for _, p in pairs(players) do
		if type(p) == "table" and p ~= me then
			local account = account_id_of(p)
			if not (my_account and account == my_account) then
				out[#out + 1] = p
			end
		end
	end
	return out
end

function mod._share_rebuild_gear_map()
	local map = {}
	local players = other_players()
	for i = 1, #players do
		local loadout = loadout_of(players[i])
		if loadout then
			for j = 1, #SLOTS do
				local item = loadout[SLOTS[j]]
				local gear_id = type(item) == "table" and item.gear_id or nil
				if type(gear_id) == "string" and gear_id ~= "" then
					map[gear_id] = players[i]
				end
			end
		end
	end
	gear_map = map
	return map
end

local function party_member_for(account_id)
	local ok, members = pcall(manifold.members)
	if not (ok and type(members) == "table") then return nil end
	for i = 1, #members do
		if account_id_of(members[i]) == account_id then return members[i] end
	end
	return nil
end

local function social_info_for(account_id)
	local social = Managers and Managers.data_service and Managers.data_service.social
	if not (social and social.get_player_info_by_account_id) then return nil end
	local ok, info = pcall(social.get_player_info_by_account_id, social, account_id)
	if not (ok and type(info) == "table") then return nil end
	if type(info.presence) ~= "function" then return nil end
	return info
end

local function readable_for(player)
	if not manifold then return nil, "no_library" end
	local account_id = account_id_of(player)

	if account_id then
		local member = party_member_for(account_id)
		if member then return member, "party" end
	end

	if type(player) == "table" and type(player.presence) == "function" then
		return player, "presence"
	end

	if account_id then
		local info = social_info_for(account_id)
		if info then return info, "social" end
	end

	return nil, "unresolved"
end

function mod._share_inspected_from_view(view)
	if type(view) ~= "table" then return nil end
	for i = 1, #INSPECT_FIELDS do
		local p = view[INSPECT_FIELDS[i]]
		if type(p) == "table"
			and (type(p.account_id) == "function" or type(p.presence) == "function") then
			return p
		end
	end
	return nil
end

local function owner_of_item(item)
	if mod._inspected_player then return mod._inspected_player end
	local gear_id = type(item) == "table" and item.gear_id or nil
	if type(gear_id) ~= "string" or gear_id == "" then return nil end
	local map = gear_map or mod._share_rebuild_gear_map()
	return map[gear_id]
end

local function payload_of(owner)
	if peer_rev ~= mod._share_rev then
		peer_rev = mod._share_rev
		peer_cache = {}
	end

	local cached = peer_cache[owner]
	if cached ~= nil then return cached or nil end

	local found = false
	local readable = readable_for(owner)
	if readable then
		local ok, data = pcall(manifold.get, readable, MOD_ID)
		if ok and type(data) == "table" and type(data.w) == "table" then
			found = data
		end
	end

	peer_cache[owner] = found
	return found or nil
end

local function weapons_of(owner)
	local data = payload_of(owner)
	return data and data.w or nil
end

function mod._share_kills_for_item(item, template_name)
	local owner = owner_of_item(item)
	if not owner then return nil, false end
	if not manifold or type(template_name) ~= "string" then return nil, true end

	local weapons = weapons_of(owner)
	if not weapons then return nil, true end

	local kills = weapons[template_name]
	if type(kills) ~= "number" or kills < 0 then return nil, true end
	return kills, true
end

function mod._share_per_instance_for_item(item)
	local owner = owner_of_item(item)
	if not owner then return false, false end
	if not manifold then return false, true end
	local data = payload_of(owner)
	return (data and data.i) and true or false, true
end

local function announce_pass()
	if not manifold then return end

	local candidates = {}
	local ok, members = pcall(manifold.members)
	if ok and type(members) == "table" then
		for i = 1, #members do
			local m = members[i]
			local ok_self, mine = pcall(manifold.is_myself, m)
			if not (ok_self and mine) then candidates[#candidates + 1] = m end
		end
	end

	local players = other_players()
	for i = 1, #players do
		candidates[#candidates + 1] = players[i]
	end

	local by_account = {}
	for i = 1, #candidates do
		local who = candidates[i]
		local account_id = account_id_of(who)
		if account_id and not announced[account_id] then
			local entry = by_account[account_id]
			if not entry then
				entry = {}
				by_account[account_id] = entry
			end
			entry.name = entry.name or display_name_of(who)
			if not entry.readable then
				entry.readable = readable_for(who)
			end
		end
	end

	for account_id, entry in pairs(by_account) do
		if entry.readable and entry.name then
			local ok_v, version = pcall(manifold.has_mod, entry.readable, MOD_ID)
			if ok_v and type(version) == "string" then
				announced[account_id] = true
				mod:echo(mod:localize("wkc_share_also_using", entry.name))
			end
		end
	end
end

function mod._share_update(dt)
	poll_t = poll_t + (dt or 0)
	if poll_t < POLL_INTERVAL then return end
	poll_t = 0

	mod._share_rebuild_gear_map()

	if not manifold then return end

	announce_pass()

	if in_mission() then return end
	mod._share_refresh()
end

function mod._share_note_inspect()
	local player = mod._inspected_player
	if not player then
		mod:info("share: could not identify the inspected player")
		return
	end

	local _, route = readable_for(player)
	local weapons = manifold and weapons_of(player) or nil
	local n = 0
	if weapons then
		for _ in pairs(weapons) do n = n + 1 end
	end

	mod:info(("share: inspect route=%s weapons=%d"):format(route, n))
end

function mod._share_init()
	if manifold then return end

	local vox = get_mod("Vox Manifold")
	local api = vox and vox.api
	if type(api) ~= "table" or type(api.register) ~= "function" then return end

	local ok, err = api.register(MOD_ID, mod, function() return payload end)
	if not ok then
		mod:error("Vox Manifold rejected the registration: " .. tostring(err))
		return
	end

	manifold = api

	if type(api.on_update) == "function" then
		unsubscribe = api.on_update(function()
			mod._share_bump()
			if mod._overlay_layout_bumped then mod._overlay_layout_bumped() end
		end)
	end

	mod._share_refresh()
end

function mod._share_shutdown()
	if unsubscribe then
		pcall(unsubscribe)
		unsubscribe = nil
	end
	if manifold and manifold.unregister then
		pcall(manifold.unregister, MOD_ID)
	end
	manifold = nil
	payload = nil
	signature = nil
	mod._share_bump()
end

mod.on_enabled = function()
	mod._share_init()
end

mod.on_disabled = function()
	mod._share_shutdown()
end

mod.on_unload = function()
	mod._share_shutdown()
end
