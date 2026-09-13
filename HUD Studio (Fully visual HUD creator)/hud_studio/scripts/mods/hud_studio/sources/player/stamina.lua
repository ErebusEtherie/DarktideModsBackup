---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_stamina then
	return mod.hud_studio_player_stamina
end

local Stamina = mod:original_require("scripts/utilities/attack/stamina")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@param unit Unit | nil
---@return table? stamina_component, table? stamina_template
local function stamina_utility(unit)
	if not unit then
		return
	end

	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data then
		return
	end

	local archetype = unit_data:archetype()
	local stamina_template = archetype and archetype.stamina
	if not stamina_template then
		return
	end

	return unit_data:read_component("stamina"), stamina_template
end

---@param unit Unit | nil
---@return number current, number max
local function stamina(unit)
	local stamina_component, stamina_template = stamina_utility(unit)
	if not stamina_template then
		return 0, 0
	end

	local ok, current, max = pcall(Stamina.current_and_max_value, unit, stamina_component, stamina_template)
	if not ok then
		return 0, 0
	end
	return current, max
end

---@type PlayerField
local Field = {
	fields = {
		status = {
			stamina = DataTypes.field("number", "[0..n] current stamina"),
			stamina_max = DataTypes.field("number", "[0..n] maximum stamina"),
			stamina_percent = DataTypes.field("number", "[0..100] % current stamina"),
		},
	},
}

---@param values table                    per-slot output table, rewritten in place
---@param player DL_PlayerObject | nil     slot occupant, or nil when the slot is empty
---@param unit Unit | nil                  the player's live unit, or nil when dead/absent
function Field.write(values, player, unit)
	local status = values.status or {}
	values.status = status
	local current, max = stamina(unit)
	status.stamina = current
	status.stamina_max = max

	status.stamina_percent = status.stamina_max >= 1 and ((status.stamina or 0) / status.stamina_max * 100) or 0
end

mod.hud_studio_player_stamina = Field
return Field
