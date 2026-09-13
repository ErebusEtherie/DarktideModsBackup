---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_syn_read then
	return mod.hud_studio_player_syn_read
end

local External = mod:core(mod.hud_studio_player_external_read, "sources/player/reads/external_read")

---@type ExternalHandle
local HANDLE = {
	id = "state_your_name",
	requires = { "compose_player_identity" },
	refresh_seconds = 1,
	cache = {},
}

local SURFACE_BY_GAME_MODE = {
	coop_complete_objective = "team_hud",
	expedition = "team_hud",
	hub = "team_hud",
	hub_singleplay = "team_hud",
	prologue = "team_hud",
	prologue_hub = "team_hud",
	shooting_range = "team_hud",
	survival = "team_hud",
	training_grounds = "team_hud",
}

local _game_mode
local _surface

local function syn_surface()
	local game_mode = mod.dl.gameplay.game_mode_name()

	if game_mode ~= _game_mode then
		_game_mode = game_mode
		_surface = SURFACE_BY_GAME_MODE[game_mode]
	end

	return _surface
end

---@param syn table
---@param player DL_PlayerObject
---@param surface string
---@return string | nil
local function compose_identity(syn, player, surface)
	return syn.compose_player_identity(player, surface)
end

---@class SynRead
local SYN = {}

---@param player DL_PlayerObject
---@param character_id string
---@param player_name string
---@param time_now number
---@return string
function SYN.read(player, character_id, player_name, time_now)
	local surface = syn_surface()

	if not surface then
		return player_name
	end

	return External.read(HANDLE, character_id, surface, time_now, compose_identity, player, surface) or player_name
end

mod.hud_studio_player_syn_read = SYN
return SYN
