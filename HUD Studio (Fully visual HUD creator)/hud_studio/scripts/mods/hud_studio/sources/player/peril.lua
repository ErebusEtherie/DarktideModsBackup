---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_peril then
	return mod.hud_studio_player_peril
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@type PlayerField
local Field = {
	fields = {
		status = {
			peril_percent = DataTypes.field("number", "[0..100] % of current peril amount"),
			peril_quell_lockout = DataTypes.field(
				"boolean",
				"[true/false] whether peril is locked out from being quelled -- perils of the warp is "
					.. "going off and venting is refused. Local player (slot 1) only; always false for teammates"
			),
		},
	},
}

---@param unit Unit | nil
---@return table|nil
local function warp_charge(unit)
	if not unit then
		return nil
	end
	local unit_data = Player.extensions(unit, "unit_data_system")
	return unit_data and unit_data:read_component("warp_charge") or nil
end

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local status = values.status or {}
	values.status = status

	local component = warp_charge(unit)

	local fraction = component and component.current_percentage or nil
	status.peril_percent = (fraction and fraction * 100) or 0

	status.peril_quell_lockout = component ~= nil and component.state == "exploding"
end

mod.hud_studio_player_peril = Field
return Field
