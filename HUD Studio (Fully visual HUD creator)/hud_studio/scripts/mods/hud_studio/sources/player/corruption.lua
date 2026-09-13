---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_corruption then
	return mod.hud_studio_player_corruption
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@type PlayerField
local Field = {
	fields = {
		status = {
			corruption = DataTypes.field("number", "[0..n] actual amount of current corruption damage"),
			corruption_percent = DataTypes.field(
				"number",
				"[0..100] % amount of current corruption damage relative to max health"
			),
		},

	},
	sections = {
		{ id = "vitals", label = "Vitals" },
		{ id = "movement", label = "Movement" },
		{ id = "psyker", label = "Psyker" },
	},
	field_meta = {
		["status.wounds"] = { section = "vitals" },
		["status.wounds_max"] = { section = "vitals" },
		["status.health"] = { section = "vitals" },
		["status.health_percent"] = { section = "vitals" },
		["status.health_max"] = { section = "vitals" },
		["status.toughness_broken"] = { section = "vitals" },
		["status.toughness"] = { section = "vitals" },
		["status.toughness_regular"] = { section = "vitals" },
		["status.toughness_regular_max"] = { section = "vitals" },
		["status.toughness_regular_percent"] = { section = "vitals" },
		["status.toughness_gold"] = { section = "vitals" },
		["status.toughness_percent"] = { section = "vitals" },
		["status.has_golden_toughness"] = { section = "vitals" },
		["status.stamina"] = { section = "vitals" },
		["status.stamina_max"] = { section = "vitals" },
		["status.stamina_percent"] = { section = "vitals" },
		["status.corruption"] = { section = "vitals" },
		["status.corruption_percent"] = { section = "vitals" },
		["status.dodges"] = { section = "movement" },
		["status.dodges_clamped"] = { section = "movement" },
		["status.dodges_max"] = { section = "movement" },
		["status.dodge_refresh_percent"] = { section = "movement" },
		["status.dodge_refresh_seconds"] = { section = "movement" },
		["status.peril_percent"] = { section = "psyker" },
		["status.peril_quell_lockout"] = { section = "psyker" },
	},
	write = function(values, player, unit)
		local status = values.status or {}
		values.status = status
		local absolute = player and Player.corruption(player) or 0
		local fraction = player and Player.corruption_percent(player) or 0
		status.corruption = absolute or 0
		status.corruption_percent = (fraction and fraction * 100) or 0
	end,
}

mod.hud_studio_player_corruption = Field
return Field
