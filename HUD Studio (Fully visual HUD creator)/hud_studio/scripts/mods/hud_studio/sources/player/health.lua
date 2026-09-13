---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_health then
	return mod.hud_studio_player_health
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@type PlayerField
local Field = {
	fields = {
		status = {
			health = DataTypes.field("number", "[0..n] current health"),
			health_percent = DataTypes.field("number", "[0..100] % current health"),
			health_max = DataTypes.field("number", "[0..n] maximum health"),
		},
	},
}

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local status = values.status or {}
	values.status = status
	status.health = player and Player.health(player) or 0
	status.health_max = player and Player.max_health(player) or 0
	status.health_percent = status.health_max >= 1 and ((status.health or 0) / status.health_max * 100) or 0
end

mod.hud_studio_player_health = Field
return Field
