---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_pocketable_read then
	return mod.hud_studio_player_pocketable_read
end

local Player = mod.dl.player

---@class PocketableRead
local Pocketable = {}

local color_table = {
	["syringe_corruption_pocketable"] = { 255, 40, 255, 40 },
	["syringe_ability_boost_pocketable"] = { 255, 255, 255, 40 },
	["syringe_power_boost_pocketable"] = { 255, 255, 60, 60 },
	["syringe_speed_boost_pocketable"] = { 255, 30, 30, 255 },
	["syringe_broker_pocketable"] = { 255, 160, 0, 160 },
}

---@param unit Unit | nil
---@param slot string
---@return string | nil, string | nil, string | nil, table | nil
function Pocketable.read(unit, slot)
	local unit_data, visual_loadout = Player.extensions(unit, "unit_data_system", "visual_loadout_system")

	if not unit_data or not visual_loadout then
		return nil, nil
	end

	local inventory = unit_data:read_component("inventory")
	local item_name = inventory and inventory[slot]

	if not item_name or item_name == "not_equipped" then
		return nil, nil
	end

	local weapon_template = visual_loadout:weapon_template_from_slot(slot)
	local item = visual_loadout:item_from_slot(slot)
	local icon = (weapon_template and weapon_template.hud_icon) or (item and (item.hud_icon or item.icon))
	local icon_small = (weapon_template and weapon_template.hud_icon_small)

	return item_name, icon, icon_small, color_table[weapon_template.name]
end

mod.hud_studio_player_pocketable_read = Pocketable
return Pocketable
