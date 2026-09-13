---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_toughness then
	return mod.hud_studio_player_toughness
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")

---@type PlayerField
local Field = {
	fields = {
		status = {
			toughness_broken = DataTypes.field("boolean", "[true/false] whether toughness is currently broken (0)"),
			toughness = DataTypes.field("number", "[0..n] current toughness, combined gold and blue"),
			toughness_regular = DataTypes.field("number", "[0..n] current regular (blue) toughness"),
			toughness_regular_max = DataTypes.field("number", "[0..n] maximum regular (blue) toughness"),
			toughness_regular_percent = DataTypes.field("number", "[0..100] % current regular (blue) toughness"),
			toughness_gold = DataTypes.field("number", "[0..n] current golden toughness"),
			toughness_percent = DataTypes.field(
				"number",
				"[0..100+n] % current toughness relative to maximum regular (blue) toughness"
			),
			has_golden_toughness = DataTypes.field("boolean", "[true/false] whether golden toughness is active"),
		},
	},
	write = function(values, player, unit)
		local status = values.status or {}
		values.status = status
		if not player then

			status.has_golden_toughness = false
			status.toughness_broken = true
			status.toughness = 0
			status.toughness_regular_max = 0
			status.toughness_regular = 0
			status.toughness_regular_percent = 0
			status.toughness_gold = 0
			status.toughness_percent = 0
		else
			local blue_and_gold = Player.toughness(player) or 0 
			local toughness_broken = blue_and_gold <= 0
			local has_gold = not toughness_broken and (Player.has_golden_toughness(player) or false)
			local blue_max = Player.max_toughness_visual(player) or 0 
			local blue = has_gold and blue_max or blue_and_gold
			status.toughness_broken = toughness_broken
			status.has_golden_toughness = has_gold
			status.toughness = blue_and_gold
			status.toughness_regular_max = blue_max
			status.toughness_regular = blue
			local blue_percent = not toughness_broken and blue >= 1 and (blue / (blue_max or 1) * 100) or 0
			local gold = has_gold and (blue_and_gold - blue) or 0
			local gold_pct_rel_to_blue_max = not toughness_broken and gold >= 1 and (gold / (blue_max or 1) * 100) or 0

			status.toughness_regular_percent = blue_percent
			status.toughness_gold = gold
			status.toughness_percent = not toughness_broken and (blue_percent + gold_pct_rel_to_blue_max) or 0
		end
	end,
}

mod.hud_studio_player_toughness = Field
return Field
