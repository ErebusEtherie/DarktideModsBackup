---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_ability_read then
	return mod.hud_studio_player_ability_read
end

local Player = mod.dl.player

---@class DL_AbilityExtension
---@field equipped_abilities fun(self: DL_AbilityExtension): table<string, table>
---@field remaining_ability_cooldown fun(self: DL_AbilityExtension, ability_id: string): number
---@field max_ability_cooldown fun(self: DL_AbilityExtension, ability_id: string): number
---@field remaining_ability_charges fun(self: DL_AbilityExtension, ability_id: string): integer
---@field max_ability_charges fun(self: DL_AbilityExtension, ability_id: string): integer

---@class AbilityRead
local Ability = {}

local PLAYER_ABILITIES_PATH = "scripts/settings/ability/player_abilities/player_abilities"
local ARCHETYPE_TALENTS_PATH = "scripts/settings/ability/archetype_talents/archetype_talents"

---@type table<table, { id: string, group: string | nil, talent_key: string | nil, name_loc: string | nil }> | nil
local identities = nil

---@type table<string, table> | nil
local archetype_talents_by_name = nil

---@return table<table, table>
local function ability_identities()
	if identities then
		return identities
	end
	identities = {}

	local ok_abilities, PlayerAbilities = pcall(mod.original_require, mod, PLAYER_ABILITIES_PATH)
	if not ok_abilities or type(PlayerAbilities) ~= "table" then
		return identities
	end

	for ability_key, config in pairs(PlayerAbilities) do
		if type(config) == "table" then
			identities[config] = { id = ability_key, group = config.ability_group }
		end
	end

	local ok_talents, ArchetypeTalents = pcall(mod.original_require, mod, ARCHETYPE_TALENTS_PATH)
	if not ok_talents or type(ArchetypeTalents) ~= "table" then
		return identities
	end
	archetype_talents_by_name = ArchetypeTalents

	for _, archetype_talents in pairs(ArchetypeTalents) do
		if type(archetype_talents) == "table" then
			for talent_key, talent in pairs(archetype_talents) do
				local player_ability = type(talent) == "table" and talent.player_ability or nil
				local config = type(player_ability) == "table" and player_ability.ability or nil
				local identity = type(config) == "table" and identities[config] or nil

				if identity and (not identity.talent_key or talent_key < identity.talent_key) then
					identity.talent_key = talent_key
					identity.name_loc = talent.display_name
				end
			end
		end
	end

	return identities
end

---@type table<table, table<string, table>>
local abilities_by_profile = setmetatable({}, { __mode = "k" })

---@param profile table
---@return table<string, table>   ability_type -> PlayerAbilities config
local function profile_abilities(profile)
	local cached = abilities_by_profile[profile]
	if cached then
		return cached
	end

	local configs = {}
	abilities_by_profile[profile] = configs

	local archetype = profile.archetype
	local talents = profile.talents
	local archetype_talents = archetype_talents_by_name and archetype and archetype_talents_by_name[archetype.name]
	if type(talents) ~= "table" or type(archetype_talents) ~= "table" then
		return configs
	end

	for talent_key in pairs(talents) do
		local talent = archetype_talents[talent_key]
		local player_ability = type(talent) == "table" and talent.player_ability or nil
		local config = type(player_ability) == "table" and player_ability.ability or nil
		if type(config) == "table" and player_ability.ability_type then
			configs[player_ability.ability_type] = config
		end
	end

	return configs
end

---@param ext DL_AbilityExtension
---@param method string
---@param ability_id string
---@return any | nil
local function call(ext, method, ability_id)
	local fn = ext[method]
	if not fn then
		return nil
	end
	local ok, result = pcall(fn, ext, ability_id)
	return ok and result or nil
end

---@param out table
---@param config table | nil
function Ability.apply_config(out, config)

	local identity = config and ability_identities()[config] or nil
	out.id = identity and identity.id or nil
	out.group = identity and identity.group or nil
	out.talent_key = identity and identity.talent_key or nil
	out.name_loc = identity and identity.name_loc or nil

	out.icon = config and config.hud_icon or nil
	out.icon_mask = config and config.hud_icon_mask or nil
	out.icon_ramp = config and config.hud_icon_ramp or nil

	out.inventory_item_name = config and config.inventory_item_name or nil

	out.icon_frame = config and config.hud_icon_frame or nil
	out.icon_frame_glow = config and config.hud_icon_frame_glow or nil
	out.icon_frame_glow_spin = config and config.hud_icon_frame_glow_spin or nil

	return config
end

---@param unit Unit | nil                 the player's live unit, or nil when dead/absent
---@param ability_id string               "combat_ability" | "grenade_ability"
---@param out table | nil                 previous per-slot table for this field, or nil
---@param player DL_PlayerObject | nil    the slot's occupant, for the no-unit profile fallback
---@return table
function Ability.read(unit, ability_id, out, player)
	out = out or {}

	---@type DL_AbilityExtension | nil
	local ext = unit and Player.extensions(unit, "ability_system") or nil
	if not ext then

		ability_identities()
		local profile = player and Player.profile(player) or nil
		local config = profile and profile_abilities(profile)[ability_id] or nil
		Ability.apply_config(out, config)

		local known = config ~= nil
		out.progress_percent_to_next_charge = known and 100 or 0
		out.progress_percent_to_max_charges = known and 100 or 0
		out.cooldown_seconds_to_next_charge = 0
		out.charges, out.max_charges = 0, 0
		out.has_cooldown = false
		out.is_ready = false
		return out
	end

	local equipped = call(ext, "equipped_abilities", ability_id)
	local config = type(equipped) == "table" and equipped[ability_id] or nil
	Ability.apply_config(out, config)

	out.charges = call(ext, "remaining_ability_charges", ability_id) or 0
	out.max_charges = call(ext, "max_ability_charges", ability_id) or 0

	local base_cooldown = config and config.cooldown
	out.has_cooldown = base_cooldown ~= nil and base_cooldown ~= 0

	local remaining = call(ext, "remaining_ability_cooldown", ability_id)
	local max_cooldown = call(ext, "max_ability_cooldown", ability_id)

	if remaining == nil or remaining == math.huge then
		out.cooldown_seconds_to_next_charge = 0
		out.progress_percent_to_next_charge = 100
		out.progress_percent_to_max_charges = 100
	else
		out.cooldown_seconds_to_next_charge = remaining

		if max_cooldown and max_cooldown > 0 and remaining > 0 then
			out.progress_percent_to_next_charge = math.clamp(1 - remaining / max_cooldown, 0, 1) * 100
		else
			out.progress_percent_to_next_charge = 100
		end

		if out.charges and out.max_charges and out.max_charges > 0 then
			out.progress_percent_to_max_charges =
				math.clamp(((out.charges + out.progress_percent_to_next_charge / 100) / out.max_charges) * 100, 0, 100)
		else
			out.progress_percent_to_max_charges = 100
		end
	end

	out.is_ready = out.charges and out.charges ~= 0

	return out
end

mod.hud_studio_player_ability_read = Ability
return Ability
