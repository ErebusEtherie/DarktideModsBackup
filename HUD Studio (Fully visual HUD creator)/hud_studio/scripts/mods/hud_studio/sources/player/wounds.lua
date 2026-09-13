---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_wounds then
	return mod.hud_studio_player_wounds
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@type PlayerField
local Field = {
	fields = {
		status = {
			wounds = DataTypes.field("integer", "[0..n] current health segments"),
			wounds_max = DataTypes.field("integer", "[0..n] maximum health segments"),
		},
	},
}

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local status = values.status or {}
	values.status = status
	status.wounds = player and Player.wounds(player) or 0
	status.wounds_max = player and Player.max_wounds(player) or 0
end

mod.hud_studio_player_wounds = Field
return Field
