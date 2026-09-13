---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

local PLAYER_COUNT = 4

local Player = mod.dl.player
local Party = mod:core(mod.hud_studio_player_party, "sources/player/party")

local now = mod.dl.time.now
local _time_now = now()

---@class PlayerField : EditorDoc
---@field fields table<string, FieldShape|table<string, FieldShape>>   this provider's slice of the player leaf shape; a DataTypes.field(...) leaf is scalar, a nested table is a grouped field (e.g. ability -> {name, cooldown_progress, ...})
---@field sections { id: string, label: string }[]?   optional Field-dropdown headings for this provider's own leaves; pooled across providers by players.lua and handed to the source (see Source.sections)
---@field field_meta table<string, {label: string?, section: string?}>?   optional per-leaf dropdown overrides, keyed by the full "group.leaf" path (e.g. "equipment.ammo_mag_max"); pooled the same way
---@field write fun(values: table, player: DL_PlayerObject?, unit: Unit?, time_now: number)  populate its leaves in place

---@type PlayerField[]
local providers = {
	mod:core(mod.hud_studio_player_profile, "sources/player/profile"),
	mod:core(mod.hud_studio_player_appearance, "sources/player/appearance"),
	mod:core(mod.hud_studio_player_archetype, "sources/player/archetype"),
	mod:core(mod.hud_studio_player_state, "sources/player/state"),
	mod:core(mod.hud_studio_player_toughness, "sources/player/toughness"),
	mod:core(mod.hud_studio_player_health, "sources/player/health"),
	mod:core(mod.hud_studio_player_corruption, "sources/player/corruption"),
	mod:core(mod.hud_studio_player_wounds, "sources/player/wounds"),
	mod:core(mod.hud_studio_player_dodges, "sources/player/dodges"),
	mod:core(mod.hud_studio_player_stamina, "sources/player/stamina"),
	mod:core(mod.hud_studio_player_peril, "sources/player/peril"),
	mod:core(mod.hud_studio_player_ability, "sources/player/ability"),
	mod:core(mod.hud_studio_player_blitz, "sources/player/blitz"),
	mod:core(mod.hud_studio_player_equipment, "sources/player/equipment"),
	mod:core(mod.hud_studio_player_stimms, "sources/player/stimms"),
	mod:core(mod.hud_studio_player_device, "sources/player/device"),
	mod:core(mod.hud_studio_player_pocketables, "sources/player/pocketables"),

}

local FIELDS = {}
for i = 1, #providers do
	for field, shape in pairs(providers[i].fields) do
		if DataTypes.is_leaf(shape) then
			FIELDS[field] = shape
		else
			local group = FIELDS[field]
			if not group or DataTypes.is_leaf(group) then
				group = {}
				FIELDS[field] = group
			end
			for leaf, leaf_shape in pairs(shape) do
				group[leaf] = leaf_shape
			end
		end
	end
end

local SECTIONS = {}
local FIELD_META = {}
local seen_section = {}
for i = 1, #providers do
	local sections = providers[i].sections
	for s = 1, (sections and #sections or 0) do
		local section = sections[s]
		if not seen_section[section.id] then
			seen_section[section.id] = true
			SECTIONS[#SECTIONS + 1] = section
		end
	end
	for path, meta in pairs(providers[i].field_meta or {}) do
		FIELD_META[path] = meta
	end
end

---@param a table
---@param b table
---@return boolean
local function by_party_then_slot(a, b)
	if a.in_party ~= b.in_party then
		return a.in_party
	end
	return a.slot < b.slot
end

local ordering_scratch = {}
local others_scratch = {}
local others_frame = nil

---@param frame_id number|nil  the frame this ordering is for; nil (no frame stamped on the

---@return DL_PlayerObject[]   - others, ordered by game slot
local function others_by_slot(frame_id)
	if frame_id ~= nil and frame_id == others_frame then
		return others_scratch
	end
	others_frame = frame_id

	local party_occupants = Party.other_occupants(frame_id)
	if party_occupants then
		local occupant_count = #party_occupants
		for i = 1, occupant_count do
			others_scratch[i] = party_occupants[i].occupant
		end
		for i = #others_scratch, occupant_count + 1, -1 do
			others_scratch[i] = nil
		end
		return others_scratch
	end

	local local_player = Player.local_player()
	local count = 0

	local exclude_strangers = Party.excludes_strangers()

	for _, player in pairs(Player.players()) do
		if player ~= local_player and (not exclude_strangers or Party.is_in_party(player)) then

			local ok, player_slot = pcall(player.slot, player)
			local slot_index = ok and player_slot or math.huge
			local in_party = Party.is_in_party(player)
			count = count + 1
			local entry = ordering_scratch[count]
			if entry then
				entry.player, entry.slot, entry.in_party = player, slot_index, in_party
			else
				ordering_scratch[count] = { player = player, slot = slot_index, in_party = in_party }
			end
		end
	end

	for i = #ordering_scratch, count + 1, -1 do
		ordering_scratch[i] = nil
	end

	table.sort(ordering_scratch, by_party_then_slot)

	for i = 1, count do
		others_scratch[i] = ordering_scratch[i].player
	end
	for i = #others_scratch, count + 1, -1 do
		others_scratch[i] = nil
	end
	return others_scratch
end

---@param slot integer
---@param frame_id number|nil
---@return DL_PlayerObject | nil
local function player_in_slot(slot, frame_id)
	if slot == 1 then
		return Player.local_player()
	end
	return others_by_slot(frame_id)[slot - 1]
end

local stats = mod.hud_studio_source_stats or { provider_runs = 0 }
mod.hud_studio_source_stats = stats

---@type table<string, PlayerField[]>
local group_providers = {}
for i = 1, #providers do
	for field in pairs(providers[i].fields) do
		local list = group_providers[field]
		if not list then
			list = {}
			group_providers[field] = list
		end
		list[#list + 1] = providers[i]
	end
end

for slot = 1, PLAYER_COUNT do

	local store = {}

	local filled = {}

	local ran = {}
	local current_player, current_unit = nil, nil
	local current_frame = -1

	local values = setmetatable({}, {
		__index = function(_, key)
			if filled[key] == current_frame then
				return store[key]
			end
			local provs = group_providers[key]
			if not provs then
				return nil
			end
			filled[key] = current_frame
			_time_now = now()
			for i = 1, #provs do
				local provider = provs[i]
				if ran[provider] ~= current_frame then
					ran[provider] = current_frame
					stats.provider_runs = stats.provider_runs + 1
					provider.write(store, current_player, current_unit, _time_now)
				end
			end
			return store[key]
		end,
	})

	Registry.register({
		id = "player_" .. slot,
		kind = "pull",
		category = "player",
		label = mod:localize("data_source_player_" .. slot),
		fields = FIELDS,
		sections = SECTIONS,
		field_meta = FIELD_META,
		example = "return player_" .. slot .. ".status.health",
		---@param ctx Context
		resolve = function(ctx)

			current_player = player_in_slot(slot, ctx and ctx.frame_id)
			current_unit = current_player and Player.unit(current_player) or nil

			if ctx and ctx.frame_id then
				current_frame = ctx.frame_id
			else
				current_frame = current_frame + 1
			end
			return values
		end,
	})
end
