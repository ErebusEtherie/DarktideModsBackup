-- Keeps the Realms preparation page's local player row showing the saved
-- Realms loadout. The live profile temporarily switches to the official
-- profile while the official inventory view is open (Storage.begin_official_ui)
-- and can be overwritten again when Realms re-fetches the backend profile, so
-- the preparation page would otherwise display official weapons even though
-- the Realms loadout is what the game ultimately applies.
--
-- Display only: the profile pipeline, loadout storage and the automatic
-- re-apply of the Realms loadout are untouched. Only the local player's
-- weapons and their row signature are replaced; portraits, skills and every
-- other player row keep using the live profile exactly as Realms builds them.
local mod = get_mod("realms_loadout")
if mod._realms_preparation_loadout then return mod._realms_preparation_loadout end

local Storage = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/storage")
local MasterItems = require("scripts/backend/master_items")

-- Realms/views/preparation_view/loadout.lua joins the three key parts with \31.
local SEPARATOR = "\31"

local state = {
	installed = false,
	cache_character_id = nil,
	cache_active_id = nil,
	cache_compact = nil,
	cache_catalog_stamp = nil,
	cache_weapons = nil,
	cache_loadout_key = nil,
}

local function normalize_peer_id(peer_id)
	return peer_id and string.lower(tostring(peer_id)) or nil
end

local function local_player()
	return Managers.player and Managers.player:local_player_safe(1)
end

local function weapon_icon(item)
	if type(item) ~= "table" then
		return nil
	end

	local master_item = item.name and MasterItems.get_item(item.name)

	return master_item and master_item.hud_icon or item.hud_icon
end

local function weapon_key_part(item)
	if type(item) ~= "table" then
		return ""
	end

	return item.gear_id or item.name or ""
end

-- Reuse the live profile's talent part so talent changes still refresh the row.
local function talent_part(loadout_key)
	if type(loadout_key) ~= "string" then
		return ""
	end

	local first = string.find(loadout_key, SEPARATOR, 1, true)

	if not first then
		return ""
	end

	local second = string.find(loadout_key, SEPARATOR, first + 1, true)

	if not second then
		return ""
	end

	return string.sub(loadout_key, second + 1)
end

local function working_weapons(profile)
	local saved = Storage.get_active_loadout(profile)
	local compact = saved and saved.profile

	if type(compact) ~= "table" then
		return nil
	end

	-- A cache miss rebuilds the whole working profile (pack/unpack plus local
	-- catalog rebuild). The saved loadout is held and compared by reference:
	-- unlike a formatted table address, a reference cannot be recycled by a
	-- later table, and holding it keeps the compared table alive.
	local catalog = mod._weapon_catalog_cache
	local character_id = profile.character_id
	local active_id = Storage.get_active_profile_preset_id()
	local catalog_stamp = catalog and catalog.generated_at or 0

	if rawequal(state.cache_compact, compact)
		and state.cache_character_id == character_id
		and state.cache_active_id == active_id
		and state.cache_catalog_stamp == catalog_stamp then
		return state.cache_weapons, state.cache_loadout_key
	end

	local working = Storage.load_working_profile(profile)
	local loadout = working and working.loadout

	if type(loadout) ~= "table" then
		return nil
	end

	local primary = loadout.slot_primary
	local secondary = loadout.slot_secondary
	local weapons = {
		{ icon = weapon_icon(primary), item = primary, slot = "slot_primary" },
		{ icon = weapon_icon(secondary), item = secondary, slot = "slot_secondary" },
	}
	local loadout_key = table.concat({ weapon_key_part(primary), weapon_key_part(secondary) }, SEPARATOR)

	state.cache_character_id = character_id
	state.cache_active_id = active_id
	state.cache_compact = compact
	state.cache_catalog_stamp = catalog_stamp
	state.cache_weapons = weapons
	state.cache_loadout_key = loadout_key

	return weapons, loadout_key
end

local function patch_rows(rows)
	local player = local_player()
	local profile = player and player:profile()

	if type(profile) ~= "table" then
		return rows
	end

	local peer_id = normalize_peer_id(player:peer_id())
	local weapons, loadout_key = working_weapons(profile)

	if not weapons then
		return rows
	end

	for i = 1, #rows do
		local row = rows[i]

		if row and row.peer_id == peer_id then
			row.weapons = weapons
			row.loadout_key = loadout_key .. SEPARATOR .. talent_part(row.loadout_key)

			break
		end
	end

	return rows
end

local function realms_preparation()
	local realms = get_mod("Realms")

	return realms and realms._preparation or nil
end

local function install()
	if state.installed then
		return true
	end

	local preparation = realms_preparation()

	if not preparation or type(preparation.player_rows) ~= "function" then
		return false
	end

	mod:hook(preparation, "player_rows", function (func, ...)
		local rows = func(...)

		if type(rows) ~= "table" then
			return rows
		end

		local ok, err = pcall(patch_rows, rows)

		if not ok then
			mod:warning("realms_loadout preparation loadout display failed: %s", tostring(err))
		end

		return rows
	end)

	state.installed = true

	return true
end

mod.update_preparation_loadout_display = function ()
	if not mod:is_enabled() then
		return
	end

	install()
end

mod:command("realms_prep_display", "Realms preparation loadout display status", function ()
	local player = local_player()
	local profile = player and player:profile()
	local saved = profile and Storage.get_active_loadout(profile)

	mod:echo("Realms preparation loadout display")
	mod:echo("  installed=" .. tostring(state.installed) .. " cached=" .. tostring(state.cache_compact ~= nil))
	mod:echo("  active_loadout=" .. tostring(saved and saved.id) .. " character=" .. tostring(profile and profile.character_id))

	local weapons = state.cache_weapons

	if weapons then
		mod:echo("  primary=" .. tostring(weapons[1] and weapons[1].item and weapons[1].item.name))
		mod:echo("  secondary=" .. tostring(weapons[2] and weapons[2].item and weapons[2].item.name))
	end
end)

install()

mod._realms_preparation_loadout = {
	install = install,
	patch_rows = patch_rows,
	working_weapons = working_weapons,
	state = state,
}

return mod._realms_preparation_loadout
