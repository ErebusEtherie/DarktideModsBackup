---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_device then
	return mod.hud_studio_player_device
end

local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Pocketable = mod:core(mod.hud_studio_player_pocketable_read, "sources/player/reads/pocketable_read")
local Player = mod.dl.player

local OBJECTIVE_SLOT = "slot_device"

---@type PlayerField
local Field = {
	fields = {
		device = {
			icon = DataTypes.field("material", "[string|nil] path of material to the carried objective item's icon"),
			held = DataTypes.field(
				"boolean",
				"[true/false] whether an objective item is currently carried in the slot"
			),
			is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether the carried objective item is currently in hand"
			),
		},
	},
	write = function(values, player, unit)
		local device = values.device or {}
		values.device = device

		local item_name, icon = Pocketable.read(unit, OBJECTIVE_SLOT)

		local unit_data = Player.extensions(unit, "unit_data_system")
		local inventory = unit_data and unit_data:read_component("inventory")
		local slot_is_wielded = (inventory and inventory.wielded_slot) == OBJECTIVE_SLOT

		device.icon = icon
		device.held = item_name ~= nil
		device.is_equipped = device.held and slot_is_wielded
	end,
}

mod.hud_studio_player_device = Field
return Field
