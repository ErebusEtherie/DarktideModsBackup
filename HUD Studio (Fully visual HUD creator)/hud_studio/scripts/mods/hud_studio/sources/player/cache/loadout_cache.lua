---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_loadout_cache then
	return mod.hud_studio_player_loadout_cache
end

local Player = mod.dl.player

local Cache = {}

---@type table<table, table>
local items_by_player = setmetatable({}, { __mode = "k" })

---@param player DL_PlayerObject | nil    slot occupant, or nil when the party slot is empty
---@param visual_loadout table | nil      the unit's visual_loadout extension, nil when dead
---@param slot string                     inventory slot name (e.g. "slot_primary")
---@return table | nil                    the equipped item table, or nil if never seen
function Cache.item(player, visual_loadout, slot)
	if not player then
		return nil
	end

	local items = items_by_player[player]

	if visual_loadout then
		local ok, item = pcall(visual_loadout.item_from_slot, visual_loadout, slot)
		if ok and item then
			if not items then
				items = {}
				items_by_player[player] = items
			end
			items[slot] = item
			return item
		end
	end

	local item = items and items[slot] or nil
	if item then
		return item
	end

	local profile = Player.profile(player)
	local loadout = profile and profile.loadout or nil
	return loadout and loadout[slot] or nil
end

mod.hud_studio_player_loadout_cache = Cache
return Cache
