---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_pocketables then
	return mod.hud_studio_player_pocketables
end

local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Pocketable = mod:core(mod.hud_studio_player_pocketable_read, "sources/player/reads/pocketable_read")
local Player = mod.dl.player

local POCKETABLE_SLOT = "slot_pocketable"

local COLLECTIBLES = {
	tome = {
		item = "tome_pocketable",
		icon = "content/ui/materials/icons/pocketables/hud/scripture",
		icon_small = "content/ui/materials/icons/pocketables/hud/small/party_scripture",
		color = { 255, 235, 200, 110 },
	},
	grimoire = {
		item = "grimoire_pocketable",
		icon = "content/ui/materials/icons/pocketables/hud/grimoire",
		icon_small = "content/ui/materials/icons/pocketables/hud/small/party_grimoire",
		color = { 255, 175, 95, 220 },
	},
}

local DEPLOYABLE_COLOR = { 255, 255, 255, 255 }

---@type PlayerField
local Field = {
	fields = {
		pocketables = {
			icon = DataTypes.field("material", "[string|nil] path of material to the carried item's icon"),
			icon_small = DataTypes.field(
				"material",
				"[string|nil] path of material to the carried item's icon (small)"
			),
			color = DataTypes.field("rgba", "[{a,r,g,b}|nil] the color tint for the carried item"),

			held = DataTypes.field("boolean", "[true/false] whether anything is currently carried in the slot"),
			is_equipped = DataTypes.field("boolean", "[true/false] whether the carried item is currently in hand"),

			deployable_is_held = DataTypes.field(
				"boolean",
				"[true/false] whether a deployable (crate / force field / mine) is currently carried"
			),
			deployable_is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether a deployable is currently in hand"
			),

			tome_is_held = DataTypes.field("boolean", "[true/false] whether a Scripture (tome) is currently carried"),
			tome_is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether a Scripture (tome) is currently in hand"
			),

			grimoire_is_held = DataTypes.field("boolean", "[true/false] whether a Grimoire is currently carried"),
			grimoire_is_equipped = DataTypes.field("boolean", "[true/false] whether a Grimoire is currently in hand"),
		},
	},
	sections = {
		{ id = "icon", label = "Icon" },
		{ id = "status", label = "Status" },
		{ id = "deployables", label = "Deployables" },
		{ id = "tomes", label = "Tomes" },
	},
	field_meta = {
		["pocketables.icon"] = { section = "icon" },
		["pocketables.icon_small"] = { section = "icon" },
		["pocketables.held"] = { section = "icon" },
		["pocketables.is_equipped"] = { section = "icon" },
		["pocketables.deployable_is_held"] = { section = "deployables" },
		["pocketables.deployable_is_equipped"] = { section = "deployables" },
		["pocketables.tome_is_held"] = { section = "tomes" },
		["pocketables.tome_is_equipped"] = { section = "tomes" },
		["pocketables.grimoire_is_held"] = { section = "tomes" },
		["pocketables.grimoire_is_equipped"] = { section = "tomes" },
	},
	write = function(values, player, unit)
		local pocketables = values.pocketables or {}
		values.pocketables = pocketables

		local item_name, icon, icon_small = Pocketable.read(unit, POCKETABLE_SLOT)

		local unit_data = Player.extensions(unit, "unit_data_system")
		local inventory = unit_data and unit_data:read_component("inventory")
		local slot_is_wielded = (inventory and inventory.wielded_slot) == POCKETABLE_SLOT

		local tome = COLLECTIBLES.tome
		local grimoire = COLLECTIBLES.grimoire

		pocketables.tome_is_held = item_name ~= nil and item_name:find(tome.item, 1, true) ~= nil
		pocketables.grimoire_is_held = item_name ~= nil and item_name:find(grimoire.item, 1, true) ~= nil

		pocketables.held = item_name ~= nil
		pocketables.deployable_is_held = pocketables.held
			and not pocketables.tome_is_held
			and not pocketables.grimoire_is_held

		pocketables.is_equipped = pocketables.held and slot_is_wielded
		pocketables.tome_is_equipped = pocketables.tome_is_held and slot_is_wielded
		pocketables.grimoire_is_equipped = pocketables.grimoire_is_held and slot_is_wielded
		pocketables.deployable_is_equipped = pocketables.deployable_is_held and slot_is_wielded

		local collectible = (pocketables.tome_is_held and tome) or (pocketables.grimoire_is_held and grimoire) or nil

		if collectible then
			pocketables.icon = collectible.icon
			pocketables.icon_small = collectible.icon_small
			pocketables.color = collectible.color
		elseif pocketables.deployable_is_held then
			pocketables.icon = icon
			pocketables.icon_small = icon_small
			pocketables.color = DEPLOYABLE_COLOR
		else
			pocketables.icon = nil
			pocketables.icon_small = nil
			pocketables.color = nil
		end
	end,
}

mod.hud_studio_player_pocketables = Field
return Field
