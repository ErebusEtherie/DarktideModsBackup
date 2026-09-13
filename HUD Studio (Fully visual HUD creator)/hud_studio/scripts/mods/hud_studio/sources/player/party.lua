---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_party then
	return mod.hud_studio_player_party
end

local Player = mod.dl.player

local Party = {}

local member_peers = {}
local member_accounts = {}

local occupants = {}

local composition_name = nil
local party_filtered = false

local member_count = 0
local matched_count = 0
local built_frame = nil
local built = false

---@param player DL_PlayerObject
---@return string|nil
local function peer_id_of(player)
	local ok, peer_id = pcall(player.peer_id, player)
	return ok and peer_id or nil
end

---@param a table
---@param b table
---@return boolean
local function by_member_id(a, b)
	return a.id < b.id
end

---@param member table
---@param getter function
---@return string|nil
local function member_key(member, getter)
	if not getter then
		return nil
	end
	local ok, key = pcall(getter, member)
	return ok and type(key) == "string" and key ~= "" and key or nil
end

local function clear(lookup)
	for key in pairs(lookup) do
		lookup[key] = nil
	end
end

---@return string|nil
local function current_composition()
	local Managers = _G.Managers
	local game_mode = Managers and Managers.state and Managers.state.game_mode or nil
	if not game_mode then
		return nil
	end

	local ok, hud_settings = pcall(game_mode.hud_settings, game_mode)
	if not ok or type(hud_settings) ~= "table" then
		return nil
	end
	return hud_settings.player_composition
end

local function build()
	built = true
	clear(member_peers)
	clear(member_accounts)
	member_count, matched_count = 0, 0

	composition_name = current_composition()
	party_filtered = false
	if composition_name ~= "party" then
		return
	end

	local Managers = _G.Managers
	local party_manager = Managers and Managers.party_immaterium or nil
	if not party_manager then

		return
	end

	party_filtered = true

	local ok, members = pcall(party_manager.other_members, party_manager)
	if not ok or type(members) ~= "table" then
		return
	end

	for _, member in pairs(members) do
		member_count = member_count + 1

		local peer_id = member_key(member, member.peer_id)
		if peer_id then
			member_peers[peer_id] = true
		end
		local account_id = member_key(member, member.account_id)
		if account_id then
			member_accounts[account_id] = true
		end
	end

	local local_player = Player.local_player()
	local players_by_member = {}
	for _, player in pairs(Player.players()) do
		if player ~= local_player and Party.matches_member(player) then
			matched_count = matched_count + 1
			local peer_id = peer_id_of(player)
			if peer_id then
				players_by_member[peer_id] = player
			end
			local account_ok, account_id = pcall(Player.account_id, player)
			if account_ok and type(account_id) == "string" and account_id ~= "" then
				players_by_member[account_id] = player
			end
		end
	end

	local count = 0
	for _, member in pairs(members) do
		local peer_id = member_key(member, member.peer_id)
		local account_id = member_key(member, member.account_id)
		local id = peer_id or account_id
		if id then
			count = count + 1
			local occupant = players_by_member[peer_id or id] or players_by_member[account_id or id] or member
			local entry = occupants[count]
			if entry then
				entry.id, entry.occupant = id, occupant
			else
				occupants[count] = { id = id, occupant = occupant }
			end
		end
	end
	for i = #occupants, count + 1, -1 do
		occupants[i] = nil
	end
	table.sort(occupants, by_member_id)
end

---@param player DL_PlayerObject
---@return boolean
function Party.matches_member(player)
	local peer_id = peer_id_of(player)
	if peer_id and member_peers[peer_id] then
		return true
	end
	local account_ok, account_id = pcall(Player.account_id, player)
	return account_ok and type(account_id) == "string" and member_accounts[account_id] == true
end

---@param frame_id number|nil
---@return table[]|nil
function Party.other_occupants(frame_id)
	Party.refresh(frame_id)
	if not party_filtered then
		return nil
	end
	return occupants
end

---@return boolean
function Party.excludes_strangers()
	if not built then
		build()
	end
	if not party_filtered then
		return true
	end
	return member_count == 0 or matched_count > 0
end

---@param frame_id number|nil  nil simply means no memoization, never a stale answer
function Party.refresh(frame_id)
	if built and frame_id ~= nil and frame_id == built_frame then
		return
	end
	built_frame = frame_id
	build()
end

---@param player DL_PlayerObject | nil
---@return boolean
function Party.is_in_party(player)
	if not player then
		return false
	end

	if player == Player.local_player() then
		return true
	end
	local human_ok, human_controlled = pcall(player.is_human_controlled, player)
	if human_ok and human_controlled == false then
		return true
	end

	if not built or composition_name ~= current_composition() then
		build()
	end

	if party_filtered then
		return Party.matches_member(player)
	end

	if composition_name == "game_session_players" then
		local Managers = _G.Managers
		local game_session = Managers and Managers.state and Managers.state.game_session or nil
		if not game_session then
			return true
		end
		local ok, joined_peers = pcall(game_session.joined_peers, game_session)
		if not ok or type(joined_peers) ~= "table" then
			return true
		end
		local peer_id = peer_id_of(player)
		return peer_id ~= nil and joined_peers[peer_id] ~= nil
	end

	return true
end

mod:command("hud_studio_party", "hud_studio: dump the party/slot resolution", function()
	build()

	local log = mod.dl.log
	log.echo("[party] composition=%s filtered=%s members=%d matched=%d excludes_strangers=%s",
		tostring(composition_name), tostring(party_filtered), member_count, matched_count,
		tostring(Party.excludes_strangers()))

	local Managers = _G.Managers
	local party_manager = Managers and Managers.party_immaterium or nil
	if party_manager then
		local ok, members = pcall(party_manager.other_members, party_manager)
		if ok and type(members) == "table" then
			for _, member in pairs(members) do
				log.echo("[party] member peer=%s account=%s name=%s",
					tostring(member_key(member, member.peer_id)),
					tostring(member_key(member, member.account_id)),
					tostring(member_key(member, member.name)))

				local profile = Player.profile(member)
				local function count_keys(t)
					if type(t) ~= "table" then
						return -1
					end
					local n = 0
					for _ in pairs(t) do
						n = n + 1
					end
					return n
				end
				log.echo("[party]   profile=%s archetype=%s level=%s talents=%d loadout=%d",
					tostring(profile ~= nil),
					tostring(profile and profile.archetype and profile.archetype.name),
					tostring(profile and profile.current_level),
					count_keys(profile and profile.talents),
					count_keys(profile and profile.loadout))
			end
		else
			log.echo("[party] other_members() failed or returned no table")
		end
	else
		log.echo("[party] Managers.party_immaterium is absent")
	end

	for i = 1, #occupants do
		local entry = occupants[i]
		local occupant = entry.occupant
		log.echo("[party] slot %d id=%s occupant=%s unit=%s",
			i + 1,
			entry.id,
			tostring(occupant.player_unit ~= nil and "player" or "member"),
			tostring(Player.unit(occupant) ~= nil))
	end

	local local_player = Player.local_player()
	for _, player in pairs(Player.players()) do
		local account_ok, account_id = pcall(Player.account_id, player)
		local name_ok, player_name = pcall(Player.name, player)
		log.echo("[party] player name=%s peer=%s account=%s local=%s matched=%s in_party=%s",
			tostring(name_ok and player_name or "<error>"),
			tostring(peer_id_of(player)),
			tostring(account_ok and account_id or "<error>"),
			tostring(player == local_player),
			tostring(Party.matches_member(player)),
			tostring(Party.is_in_party(player)))
	end
end)

mod.hud_studio_player_party = Party
return Party
