---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_buffs then
	return mod.hud_studio_player_buffs
end

---@type PlayerField
local Field = {
	fields = {
		buffs = {},
	},
}

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)

	values.buffs = values.buffs or {}
end

mod.hud_studio_player_buffs = Field
return Field
