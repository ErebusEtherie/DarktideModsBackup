-- Realms Loadout equipment catalog sync (strategy A).
--
-- A Realms client owns its forged weapons locally: the real data lives in
-- weapon_catalog_<character>.json / attachment_catalog_<character>.json, while
-- the profile only carries a local-item marker plus { id, overrides }. The
-- official inventory view (used by the inspection button) has no rebuild step,
-- so a teammate can only see the modified weapon once the receiving client
-- knows the owner's catalog entry.
--
-- The exchange mirrors the talent sync: the client submits a trimmed catalog
-- for the items it actually has equipped, the host validates and stores it in
-- memory (never on disk, never in the local catalog), and every profile that is
-- applied afterwards is rebuilt from that store. No host -> client broadcast is
-- needed because the profile itself still carries { id, overrides }.
local mod = get_mod("realms_loadout")
if mod._weapon_catalog_sync then return mod._weapon_catalog_sync end

local WeaponCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/weapon_catalog")
local AttachmentCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/attachment_catalog")
local Storage = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/storage")
local WeaponSync = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_weapon_sync")
-- Shared peer-event dispatcher: Realms keeps one peer callback per mod, so the
-- talent protocol and this one must not register competing callbacks.
local PeerEvents = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_peer_events")

local MasterItems = require("scripts/backend/master_items")

local PROTOCOL_VERSION = WeaponSync.VERSION
local CATALOG_VERSION = WeaponSync.CATALOG_VERSION

local KIND_WEAPON = "weapon"
local KIND_ATTACHMENT = "attachment"

local MAX_ENTRIES = 12
local MAX_ENTRY_BYTES = 8 * 1024
local MAX_TOTAL_BYTES = 64 * 1024
local MAX_SANITIZE_DEPTH = 8
local MAX_SANITIZE_NODES = 4000
local MAX_PERKS = 15
local MAX_TRAITS = 10
local MAX_BASE_STATS = 8
local MAX_SLOTS = 6

local OVERRIDE_KEYS = {
	"ver",
	"rarity",
	"characterLevel",
	"itemLevel",
	"baseItemLevel",
	"base_stats",
	"perks",
	"traits",
	"slot_weapon_skin",
	"attachments",
}

local INTEGER_OVERRIDE_KEYS = {
	"ver",
	"rarity",
	"characterLevel",
	"itemLevel",
	"baseItemLevel",
}

local state = {
	connection = nil,
	network_closed = false,
	network_registered = false,
	network_role = "local",
	official_ui_profiles = {},
	sync = nil,
	sync_generation = 0,
	suspended = false,
}

-- remote[peer][local_player_id][character_id] = { by_source = { [source_gear_id] = entry }, revision, received_at, reconciled_revision }
-- Memory only: another player's catalog must never reach the local JSON files
-- or WeaponCatalog's cache, or it would show up in the local forge.
local remote = {}

local function normalize_peer_id(peer_id)
	return peer_id and string.lower(tostring(peer_id)) or nil
end

local function local_peer_id()
	local player = Managers.player and Managers.player:local_player_safe(1)

	return player and normalize_peer_id(player:peer_id())
end

local function profile_key(peer_id, local_player_id)
	return string.format("%s|%s", normalize_peer_id(peer_id) or "local", tostring(local_player_id or 1))
end

local function clear_official_ui_profile(peer_id)
	local prefix = (normalize_peer_id(peer_id) or "local") .. "|"

	for key in pairs(state.official_ui_profiles) do
		if string.sub(key, 1, #prefix) == prefix then
			state.official_ui_profiles[key] = nil
		end
	end
end

local function current_connection()
	local manager = Managers.connection

	return manager and (manager._connection_host or manager._connection_client) or nil
end

local function realms_mod()
	return get_mod("Realms")
end

local function player_for_peer(peer_id, local_player_id)
	local player_manager = Managers.player

	if not player_manager then
		return nil
	end

	return player_manager:player(peer_id, local_player_id)
		or player_manager:player(normalize_peer_id(peer_id), local_player_id)
end

local function active_profile_synchronizer_host()
	local manager = Managers.profile_synchronization

	return manager and manager:synchronizer_host() or nil
end

-- remote[peer][local_player_id][character_id]
local function remote_store(peer, local_player_id, character_id)
	local by_peer = remote[peer]
	local by_player = by_peer and by_peer[local_player_id]

	return by_player and by_player[character_id] or nil
end

--------------------------------------------------------------------------------
-- Payload: the equipped local items only, trimmed of the master item snapshot.
-- __master_item is 86% of a catalog entry (~18 KB of ~21 KB measured) and the
-- receiving client resolves the same master item from its own game data.
--------------------------------------------------------------------------------

local function trim_entry(entry, kind, item_data)
	local source_gear_id = entry and entry.source_gear_id or item_data and item_data.source_gear_id
	local master_id = entry and entry.id or item_data and item_data.id

	if type(source_gear_id) ~= "string" or source_gear_id == "" then
		return nil
	end
	if type(master_id) ~= "string" or master_id == "" then
		return nil
	end

	return {
		kind = kind,
		source_gear_id = source_gear_id,
		id = master_id,
		name = entry and entry.name or master_id,
		slots = entry and entry.slots or nil,
		item_type = entry and entry.item_type or nil,
		rarity = entry and entry.rarity or nil,
		itemLevel = entry and entry.itemLevel or nil,
		baseItemLevel = entry and entry.baseItemLevel or nil,
		characterLevel = entry and entry.characterLevel or nil,
		weapon_template = entry and entry.weapon_template or nil,
		overrides = entry and entry.overrides or item_data and item_data.overrides or nil,
	}
end

local function collect_candidates(profile)
	local result = {}
	local seen = {}

	local function add(item_data)
		if type(item_data) ~= "table" then
			return
		end

		local source_gear_id = item_data.source_gear_id

		if type(source_gear_id) ~= "string" or source_gear_id == "" or seen[source_gear_id] then
			return
		end

		local kind

		if item_data.local_attachment == true then
			kind = KIND_ATTACHMENT
		elseif item_data.local_weapon == true then
			kind = KIND_WEAPON
		else
			-- Official weapons/curios keep their edits in the profile's own
			-- overrides; only Realms-local items need the catalog.
			return
		end

		seen[source_gear_id] = true
		result[#result + 1] = { item_data = item_data, kind = kind }
	end

	local live = profile and profile.loadout_item_data

	if type(live) == "table" then
		for _, item_data in pairs(live) do
			add(item_data)
		end
	end

	-- A Realms client pushes the saved loadout instead of applying it locally,
	-- so the saved file is the authoritative list for that role as well.
	local saved = Storage.get_active_loadout(profile)
	local compact = saved and saved.profile and saved.profile.loadout_item_data

	if type(compact) == "table" then
		for _, item_data in pairs(compact) do
			add(item_data)
		end
	end

	return result
end

local function local_catalog()
	if state.suspended then
		return nil
	end

	local player = Managers.player and Managers.player:local_player_safe(1)
	local profile = player and player:profile()

	if type(profile) ~= "table" or type(profile.character_id) ~= "string" then
		return nil
	end

	local candidates = collect_candidates(profile)

	if #candidates == 0 then
		return nil
	end

	local entries = {}

	for i = 1, #candidates do
		local candidate = candidates[i]
		local catalog = candidate.kind == KIND_ATTACHMENT and AttachmentCatalog or WeaponCatalog
		local catalog_data = catalog.ensure_catalog(profile)
		local source_gear_id = candidate.item_data.source_gear_id
		local entry = catalog_data and catalog_data.by_source and catalog_data.by_source[source_gear_id]
		local trimmed = trim_entry(entry or {}, candidate.kind, candidate.item_data)

		if trimmed then
			entries[#entries + 1] = trimmed
		end
	end

	if #entries == 0 then
		return nil
	end

	table.sort(entries, function (a, b)
		return tostring(a.source_gear_id) < tostring(b.source_gear_id)
	end)

	local payload = {
		character_id = profile.character_id,
		local_player_id = player:local_player_id(),
		catalog_version = CATALOG_VERSION,
		entries = entries,
	}
	local ok, signature = pcall(cjson.encode, entries)

	if not ok or type(signature) ~= "string" then
		return nil
	end

	return payload, signature
end

local function safe_local_catalog()
	local ok, payload, signature = pcall(local_catalog)

	if not ok then
		mod:warning("realms_loadout weapon sync could not build the local catalog: %s", tostring(payload))

		return nil
	end

	return payload, signature
end

--------------------------------------------------------------------------------
-- Validation. The host only ever stores what it can re-check against the game's
-- own data; nothing from the wire is used as-is.
--------------------------------------------------------------------------------

local function sanitize(value, depth, seen, budget)
	local value_type = type(value)

	if value_type == "table" then
		if depth > MAX_SANITIZE_DEPTH or seen[value] then
			return nil
		end

		seen[value] = true

		local result = {}

		for key, child in pairs(value) do
			budget.nodes = budget.nodes + 1

			if budget.nodes > MAX_SANITIZE_NODES then
				seen[value] = nil

				return nil
			end

			local safe_key = sanitize(key, depth + 1, seen, budget)
			local safe_child = sanitize(child, depth + 1, seen, budget)

			if safe_key ~= nil and safe_child ~= nil then
				result[safe_key] = safe_child
			end
		end

		seen[value] = nil

		return result
	elseif value_type == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil
		end

		return value
	elseif value_type == "string" then
		if #value > 256 then
			return nil
		end

		return value
	elseif value_type == "boolean" then
		return value
	end

	return nil
end

local function sanitize_overrides(overrides)
	if overrides == nil then
		return nil
	end
	if type(overrides) ~= "table" then
		return nil
	end

	local clean = sanitize(overrides, 0, {}, { nodes = 0 })

	if type(clean) ~= "table" then
		return nil
	end

	local result = {}

	for i = 1, #OVERRIDE_KEYS do
		local key = OVERRIDE_KEYS[i]

		if clean[key] ~= nil then
			result[key] = clean[key]
		end
	end

	for i = 1, #INTEGER_OVERRIDE_KEYS do
		local value = result[INTEGER_OVERRIDE_KEYS[i]]

		if value ~= nil and (type(value) ~= "number" or value % 1 ~= 0 or value < 0 or value > 100000) then
			return nil
		end
	end

	if result.perks ~= nil then
		if type(result.perks) ~= "table" or #result.perks > MAX_PERKS then
			return nil
		end

		for i = 1, #result.perks do
			local perk = result.perks[i]

			if type(perk) ~= "table" or type(perk.id) ~= "string" then
				return nil
			end
		end
	end

	if result.traits ~= nil then
		if type(result.traits) ~= "table" or #result.traits > MAX_TRAITS then
			return nil
		end

		for i = 1, #result.traits do
			local trait = result.traits[i]

			if type(trait) ~= "table" or type(trait.id) ~= "string" then
				return nil
			end
		end
	end

	if result.base_stats ~= nil then
		if type(result.base_stats) ~= "table" or #result.base_stats > MAX_BASE_STATS then
			return nil
		end

		for i = 1, #result.base_stats do
			local stat = result.base_stats[i]

			if type(stat) ~= "table" or type(stat.name) ~= "string" or type(stat.value) ~= "number" then
				return nil
			end
		end
	end

	return result
end

local function sanitize_slots(slots)
	if type(slots) ~= "table" then
		return nil
	end

	local result = {}

	for i = 1, #slots do
		local slot_name = slots[i]

		if type(slot_name) ~= "string" or #slot_name > 64 then
			return nil
		end

		result[#result + 1] = slot_name

		if #result > MAX_SLOTS then
			return nil
		end
	end

	return #result > 0 and result or nil
end

local function safe_number(value, maximum)
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return nil
	end
	if value < 0 or value > maximum then
		return nil
	end

	return value
end

local function valid_entry(raw)
	if type(raw) ~= "table" then
		return nil, "malformed"
	end

	local kind = raw.kind

	if kind ~= KIND_WEAPON and kind ~= KIND_ATTACHMENT then
		return nil, "kind"
	end

	local source_gear_id = raw.source_gear_id
	local master_id = raw.id

	if type(source_gear_id) ~= "string" or source_gear_id == "" or #source_gear_id > 128 then
		return nil, "source"
	end
	if type(master_id) ~= "string" or master_id == "" or #master_id > 200 then
		return nil, "id"
	end

	local master_item = MasterItems.get_item(master_id)

	if type(master_item) ~= "table" then
		return nil, "unknown_item"
	end

	local overrides = sanitize_overrides(raw.overrides)

	if raw.overrides ~= nil and overrides == nil then
		return nil, "overrides"
	end

	local entry = {
		kind = kind,
		source_gear_id = source_gear_id,
		id = master_id,
		name = master_id,
		slots = sanitize_slots(raw.slots),
		item_type = master_item.item_type or (type(raw.item_type) == "string" and raw.item_type or nil),
		rarity = safe_number(raw.rarity, 1000),
		itemLevel = safe_number(raw.itemLevel, 100000),
		baseItemLevel = safe_number(raw.baseItemLevel, 100000),
		characterLevel = safe_number(raw.characterLevel, 1000),
		weapon_template = master_item.weapon_template or (type(raw.weapon_template) == "string" and raw.weapon_template or nil),
		overrides = overrides,
	}
	local ok, encoded = pcall(cjson.encode, entry)

	if not ok or #encoded > MAX_ENTRY_BYTES then
		return nil, "oversized"
	end

	return entry
end

--------------------------------------------------------------------------------
-- Instance rebuilding. WeaponCatalog.make_local_weapon_instance and
-- AttachmentCatalog.make_local_attachment_instance already do the heavy
-- lifting; the only extra step is restoring the gear id that the packed
-- profile carries, because that is what the official view matches against.
--------------------------------------------------------------------------------

local function build_instance(entry, slot_name)
	if entry.kind == KIND_ATTACHMENT then
		return AttachmentCatalog.make_local_attachment_instance(entry)
	end

	return WeaponCatalog.make_local_weapon_instance(entry, slot_name)
end

local function expected_gear_id(slot_name, entry)
	if entry.kind == KIND_ATTACHMENT then
		return "realms_local_attachment_" .. tostring(entry.source_gear_id)
	end

	return "realms_local_weapon_" .. tostring(slot_name) .. "_" .. tostring(entry.source_gear_id)
end

local function match_entry(by_source, slot_name, gear_id)
	if type(by_source) ~= "table" or type(gear_id) ~= "string" then
		return nil
	end

	for source_gear_id, entry in pairs(by_source) do
		if gear_id == source_gear_id or gear_id == expected_gear_id(slot_name, entry) then
			return entry
		end
	end

	return nil
end

local function apply_synced_weapons(peer_id, local_player_id, profile)
	if type(profile) ~= "table" then
		return profile
	end

	local peer = normalize_peer_id(peer_id)

	if not peer or peer == local_peer_id() then
		return profile
	end

	local key = profile_key(peer_id, local_player_id)
	local marker = profile.tamm_custom_talents
	local marker_source = marker and marker.source

	-- The equipment transform runs before the talent transform that removes
	-- these transport markers. Keep the remote client's official profile wholly
	-- native while its own official inventory is open; otherwise a normal
	-- official gear id can be mistaken for the source of a Realms-local weapon.
	if marker_source == "realms_loadout_official_ui" then
		state.official_ui_profiles[key] = true

		return profile
	elseif marker_source == "realms_loadout_resume" then
		state.official_ui_profiles[key] = nil
	elseif state.official_ui_profiles[key] then
		return profile
	end

	local stored = remote_store(peer, local_player_id, profile.character_id)

	if not stored then
		return profile
	end

	local item_ids = profile.loadout_item_ids

	if type(item_ids) ~= "table" then
		return profile
	end

	local rebuilt

	for slot_name, gear_id in pairs(item_ids) do
		local entry = match_entry(stored.by_source, slot_name, gear_id)

		if entry then
			local item = build_instance(entry, slot_name)

			if item then
				item.gear_id = gear_id
				item.__gear_id = gear_id

				if not rebuilt then
					rebuilt = table.clone_instance(profile)
					rebuilt.loadout = rebuilt.loadout or {}
					rebuilt.visual_loadout = rebuilt.visual_loadout or {}
				end

				rebuilt.loadout[slot_name] = item
				rebuilt.visual_loadout[slot_name] = item
			end
		end
	end

	return rebuilt or profile
end

-- When the catalog arrives after the host already applied that peer's profile,
-- the queued profile has to be re-applied once so the host (and the clients it
-- forwards to) use the rebuilt instances.
local function reconcile_peer_weapons(peer, local_player_id)
	if peer == local_peer_id() then
		return
	end

	local player = player_for_peer(peer, local_player_id)

	if not player or player.__deleted then
		return
	end

	local profile = player:profile()

	if type(profile) ~= "table" then
		return
	end

	local stored = remote_store(peer, local_player_id, profile.character_id)

	if not stored or stored.reconciled_revision == stored.revision then
		return
	end

	local rebuilt = apply_synced_weapons(player:peer_id(), local_player_id, profile)

	if rebuilt == profile then
		stored.reconciled_revision = stored.revision

		return
	end

	local synchronizer = active_profile_synchronizer_host()

	if not synchronizer then
		return
	end

	local ok, err = pcall(function ()
		synchronizer:override_singleplay_profile(player:peer_id(), player:local_player_id(), rebuilt)
	end)

	if ok then
		stored.reconciled_revision = stored.revision
	else
		mod:warning("realms_loadout weapon sync could not re-apply the profile for %s: %s", tostring(peer), tostring(err))
	end
end

local function apply_catalog(peer, payload)
	if type(payload) ~= "table" or type(payload.character_id) ~= "string" then
		return { accepted = false, reason = "malformed" }
	end
	if payload.catalog_version ~= CATALOG_VERSION then
		return { accepted = false, reason = "version" }
	end

	local local_player_id = payload.local_player_id

	if type(local_player_id) ~= "number" or local_player_id % 1 ~= 0
		or local_player_id < 1 or local_player_id > 4 then
		return { accepted = false, reason = "identity" }
	end

	local entries = payload.entries

	if type(entries) ~= "table" or #entries == 0 or #entries > MAX_ENTRIES then
		return { accepted = false, reason = "entries" }
	end

	local player = player_for_peer(peer, local_player_id)
	local profile = player and player:profile()

	if not player or type(profile) ~= "table" then
		return { accepted = false, retry = true, reason = "loading" }
	end
	if profile.character_id ~= payload.character_id then
		return { accepted = false, reason = "identity" }
	end

	local clean = {}
	local total_bytes = 0

	for i = 1, #entries do
		local entry, reason = valid_entry(entries[i])

		if not entry then
			return { accepted = false, reason = reason or "invalid" }
		end

		local ok, encoded = pcall(cjson.encode, entry)

		if not ok then
			return { accepted = false, reason = "invalid" }
		end

		total_bytes = total_bytes + #encoded

		if total_bytes > MAX_TOTAL_BYTES then
			return { accepted = false, reason = "oversized" }
		end

		clean[entry.source_gear_id] = entry
	end

	local by_peer = remote[peer]

	if not by_peer then
		by_peer = {}
		remote[peer] = by_peer
	end

	local by_player = by_peer[local_player_id]

	if not by_player then
		by_player = {}
		by_peer[local_player_id] = by_player
	end

	local previous = by_player[payload.character_id]
	local revision = (previous and previous.revision or 0) + 1

	by_player[payload.character_id] = {
		by_source = clean,
		revision = revision,
		received_at = os.time(),
		reconciled_revision = previous and previous.reconciled_revision or nil,
	}

	reconcile_peer_weapons(peer, local_player_id)

	return { accepted = true }
end

--------------------------------------------------------------------------------
-- Display side. The official inventory view is what the inspection button
-- opens; it never calls Realms' own rebuild path.
--------------------------------------------------------------------------------

-- The equipment panel is rendered by the child inventory view, which keeps the
-- table reference handed over in the view context. Update every table the
-- parent owns so icons, stats and the wielded preview all agree.
local function set_preview_item(view, slot_name, item)
	view._preview_profile_equipped_items[slot_name] = item

	local fields = {
		"_starting_profile_equipped_items",
		"_current_profile_equipped_items",
		"_valid_profile_equipped_items",
	}

	for i = 1, #fields do
		local items = view[fields[i]]

		if type(items) == "table" then
			items[slot_name] = item
		end
	end
end

local function apply_inspect_preview(view)
	-- Only the read-only inspection view is rebuilt. The normal official
	-- inventory view must keep operating on the untouched official profile.
	if not view then
		return
	end

	local readonly = view._is_readonly == true
		or (type(view._context) == "table" and view._context.is_readonly == true)

	if not readonly then
		return
	end

	local player = view._preview_player

	if not player or player.__deleted then
		return
	end

	local items = view._preview_profile_equipped_items

	if type(items) ~= "table" then
		return
	end

	local profile = player:profile()

	if type(profile) ~= "table" then
		return
	end

	if view._is_own_player then
		-- RL swaps the local profile back to the official snapshot for the
		-- lifetime of the official view, so read the saved Realms loadout
		-- instead; this is the same source the Realms equipment view uses.
		local working = Storage.load_working_profile(profile)
		local loadout = working and working.loadout

		if type(loadout) == "table" then
			for slot_name, item in pairs(loadout) do
				if WeaponCatalog.is_local_weapon(item) or AttachmentCatalog.is_local_attachment(item) then
					set_preview_item(view, slot_name, item)
				end
			end
		end

		return
	end

	local peer = normalize_peer_id(player:peer_id())
	local stored = remote_store(peer, player:local_player_id(), profile.character_id)
	local item_ids = profile.loadout_item_ids

	if not stored or type(item_ids) ~= "table" then
		return
	end

	for slot_name, gear_id in pairs(item_ids) do
		local entry = match_entry(stored.by_source, slot_name, gear_id)

		if entry then
			local item = build_instance(entry, slot_name)

			if item then
				item.gear_id = gear_id
				item.__gear_id = gear_id
				set_preview_item(view, slot_name, item)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Network wiring (same shape as custom_talents.lua).
--------------------------------------------------------------------------------

state.sync_generation = state.sync_generation + 1
state.sync = WeaponSync.new({
	generation = state.sync_generation,
	local_ready = function ()
		local player = Managers.player and Managers.player:local_player_safe(1)
		local profile = player and player:profile()

		return not state.suspended and type(profile) == "table" and type(profile.character_id) == "string"
	end,
	warn_peer = function (peer, status)
		mod:warning("realms_loadout weapon sync peer %s: %s", tostring(peer), tostring(status))
	end,
	local_catalog = safe_local_catalog,
	apply_catalog = apply_catalog,
	peer_left = function (peer)
		remote[peer] = nil
		clear_official_ui_profile(peer)
	end,
	reset = function (old_peers, role)
		for peer in pairs(old_peers or {}) do
			remote[peer] = nil
		end

		remote = {}
		state.official_ui_profiles = {}
		state.network_role = role
	end,
	send = function (peer, message)
		local realms = realms_mod()

		if not realms or not state.sync.ready then
			return false
		end

		return realms.network_send(mod, WeaponSync.RPC, peer, message)
	end,
})

local function sync_network_context()
	local realms = realms_mod()
	local session = realms and realms._session
	local connection = current_connection()
	local role = "local"

	if connection and session and not state.network_closed then
		if type(session.is_active_host) == "function" and session:is_active_host() then
			role = "host"
		elseif type(session.is_active_client) == "function" and session:is_active_client() then
			role = "client"
		end
	end

	local host = role == "client" and normalize_peer_id(Managers.connection:host()) or nil
	local ready = role ~= "local" and realms and type(realms.network_is_available) == "function"
		and realms.network_is_available() == true

	state.connection, state.network_role = connection, role

	return state.sync:context({ connection = connection, role = role, host = host, ready = ready })
end

local function register_realms_network(replay)
	local realms = realms_mod()

	if not realms or type(realms.network_register) ~= "function"
		or type(realms.network_on_peer_joined) ~= "function" or type(realms.network_on_peer_left) ~= "function" then
		return
	end

	-- Realms keeps one peer callback per mod, so all RL protocols share one
	-- dispatcher (realms_peer_events) instead of overwriting each other.
	PeerEvents.install(realms)

	if state.network_registered ~= realms then
		local registered = realms.network_register(mod, WeaponSync.RPC, function (peer, message)
			sync_network_context()
			state.sync:receive(normalize_peer_id(peer), message)
		end)

		if not registered then
			return
		end

		state.network_registered = realms
		replay = true
	end

	if replay then
		PeerEvents.set_left("weapon_sync", function (peer)
			sync_network_context()
			state.sync:left(normalize_peer_id(peer))
		end)
		-- Subscribing replays currently known members when enabling mid-session.
		PeerEvents.set_joined("weapon_sync", function (peer)
			sync_network_context()
			state.sync:joined(normalize_peer_id(peer))
		end)
	end
end

local function update_realms_network(dt)
	local changed = sync_network_context()

	register_realms_network(changed)
	state.sync:update(dt)
end

--------------------------------------------------------------------------------
-- Public API and lifecycle.
--------------------------------------------------------------------------------

mod.realms_weapon_deployment = function (peer)
	peer = normalize_peer_id(peer)

	if not peer then
		return nil
	end
	if peer == local_peer_id() then
		return { status = "accepted", version = WeaponSync.DEPLOYMENT_VERSION }
	end

	return state.sync:deployment(peer)
end

mod.update_weapon_catalog_sync = function (dt)
	update_realms_network(dt)
end

mod.weapon_catalog_sync_pause = function ()
	state.suspended = true
end

mod.weapon_catalog_sync_resume = function ()
	state.network_closed = false
	state.suspended = false
	state.sync:queue_catalog()
	update_realms_network(0)
end

mod.weapon_catalog_sync_cleanup = function (full_exit)
	if full_exit then
		state.network_closed = true
		state.sync:close()
		state.network_registered = false
	end

	state.suspended = true
	state.sync:queue_catalog()
	remote = {}
	state.official_ui_profiles = {}
end

mod:command("realms_weapon_sync", "Realms Loadout weapon catalog sync status", function ()
	local sync = state.sync
	local lines = {
		"Realms weapon sync: role=" .. tostring(sync.role) .. " status=" .. tostring(sync.status)
			.. " ready=" .. tostring(sync.ready),
		"  rpc=" .. WeaponSync.RPC .. " protocol=" .. tostring(PROTOCOL_VERSION)
			.. " catalog=" .. tostring(CATALOG_VERSION),
	}

	for peer, by_player in pairs(remote) do
		for local_player_id, by_character in pairs(by_player) do
			for character_id, data in pairs(by_character) do
				lines[#lines + 1] = string.format("  peer=%s player=%s character=%s entries=%d revision=%d",
					tostring(peer), tostring(local_player_id), tostring(character_id),
					table.size(data.by_source or {}), data.revision or 0)
			end
		end
	end

	for i = 1, #lines do
		mod:echo(lines[i])
	end
end)

local ProfileHooks = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_profile_hooks")

-- Priority 10: rebuild the synced weapon/attachment instances before the talent
-- transform (priority 20) clones the profile.
ProfileHooks.set_transform("weapon_catalog", function (peer_id, local_player_id, profile)
	return apply_synced_weapons(peer_id, local_player_id, profile)
end, 10)

local function resolve_class(name)
	local class = rawget(_G, name)

	if class then
		return class
	end

	local classes = rawget(_G, "CLASS")

	return classes and rawget(classes, name) or nil
end

local InventoryBackgroundView = resolve_class("InventoryBackgroundView")

if type(InventoryBackgroundView) == "table" and type(InventoryBackgroundView._setup_inventory) == "function" then
	mod:hook(InventoryBackgroundView, "_setup_inventory", function (func, self, ...)
		local result = func(self, ...)
		local ok, err = pcall(apply_inspect_preview, self)

		if not ok then
			mod:warning("realms_loadout weapon sync could not rebuild the inspection preview: %s", tostring(err))
		end

		return result
	end)
else
	mod:warning("realms_loadout weapon sync could not hook the official inventory view")
end

mod._weapon_catalog_sync = {
	protocol = WeaponSync,
	state = state,
	remote = function ()
		return remote
	end,
	apply_inspect_preview = apply_inspect_preview,
	apply_synced_weapons = apply_synced_weapons,
}

return mod._weapon_catalog_sync
