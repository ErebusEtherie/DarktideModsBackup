---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_archetype then
	return mod.hud_studio_player_archetype
end

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Localize = mod:core(mod.hud_studio_source_localize, "sources/localize")

local UISettings = require("scripts/settings/ui/ui_settings")

local _icons = mod.dl.icons.icons

local _archetype_glyph = {
	psyker = _icons.emblem_psyker,
	ogryn = _icons.emblem_ogryn,
	veteran = _icons.emblem_veteran,
	zealot = _icons.emblem_zealot,
	adamant = _icons.emblem_arbitrator,
	broker = _icons.emblem_hive_scum,
	cryptic = _icons.emblem_skitarii,
}

---@param player DL_PlayerObject | nil
---@return integer|nil
local function game_slot(player)
	if not player or not player.slot then
		return nil
	end
	local ok, slot = pcall(player.slot, player)
	return ok and type(slot) == "number" and slot or nil
end

---@type PlayerField
local Field = {
	fields = {
		identity = {
			id = DataTypes.field("string", "veteran/zealot/psyker/ogryn"),
			archetype = DataTypes.field("string", "[string|nil] localized character class name"),
			text_icon = DataTypes.field("string", "[string|nil] the unicode glyph that represents this player's class"),
			slot = DataTypes.field(
				"integer",
				"[integer|nil] the player's game party slot 1-4, which is NOT this source's slot number (player_1 is always you)"
			),
			slot_color = DataTypes.field(
				"rgba",
				"[{a,r,g,b}|nil] the game's colour for this player's party slot -- what the killfeed tints their name"
			),
			slot_color_bright = DataTypes.field(
				"rgba",
				"[{a,r,g,b}|nil] the brighter variant of slot_color, as vanilla uses for emphasis"
			),
		},
	},
	write = function(values, player, unit)
		local identity = values.identity or {}
		values.identity = identity

		local archetype = player and Player.archetype(player) or nil
		identity.id = archetype and archetype.name or nil
		identity.archetype = archetype and Localize.game(archetype.archetype_name) or nil
		identity.text_icon = archetype and _archetype_glyph[archetype.name] or nil

		local slot = game_slot(player)
		identity.slot = slot
		identity.slot_color = slot and UISettings.player_slot_colors[slot] or nil
		identity.slot_color_bright = slot and UISettings.player_bright_slot_colors[slot] or nil
	end,
}

mod.hud_studio_player_archetype = Field
return Field
