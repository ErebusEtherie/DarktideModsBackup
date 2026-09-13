---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_tl_read then
	return mod.hud_studio_player_tl_read
end

local External = mod:core(mod.hud_studio_player_external_read, "sources/player/reads/external_read")

local REFERENCE = "team_panel"

---@type ExternalHandle
local HANDLE = {
	id = "true_level",

	requires = { "get_true_levels", "replace_level" },
	refresh_seconds = 1,
	cache = {},
}

---@param true_level table
---@param character_id string
---@param name string
---@return string | nil
local function format_name(true_level, character_id, name)
	local levels = true_level.get_true_levels(character_id)
	return levels and true_level.replace_level(name, levels, REFERENCE, true) or nil
end

---@class TLRead
local TL = {}

---@param character_id string
---@param player_name string
---@param time_now number
---@return string
function TL.read(character_id, player_name, time_now)
	return External.read(HANDLE, character_id, player_name, time_now, format_name, character_id, player_name)
		or player_name
end

mod.hud_studio_player_tl_read = TL
return TL
