---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_blitz then
	return mod.hud_studio_player_blitz
end

local Ability = mod:core(mod.hud_studio_player_ability_read, "sources/player/reads/ability_read")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Localize = mod:core(mod.hud_studio_source_localize, "sources/localize")
local LoadoutCache = mod:core(mod.hud_studio_player_loadout_cache, "sources/player/cache/loadout_cache")
local Player = mod.dl.player

local ABILITY_ID = "grenade_ability"

local ABILITY_SLOT = "slot_grenade_ability"

local HARDCODED_ICON_FROM_ABILITY = {
	["content/ui/materials/icons/throwables/hud/cryptic_servo_skull_order_shooting"] = true,
	["content/ui/materials/icons/throwables/hud/cryptic_force_field"] = true,
	["content/ui/materials/icons/throwables/hud/adamant_whistle"] = true,
}

local MASTER_ITEMS_PATH = "scripts/backend/master_items"

---@type table<string, table|false>
local item_by_name = {}

---@param inventory_item_name string | nil
---@return table | nil
local function master_item(inventory_item_name)
	if not inventory_item_name then
		return nil
	end
	local cached = item_by_name[inventory_item_name]
	if cached ~= nil then
		return cached or nil
	end

	local ok_items, MasterItems = pcall(mod.original_require, mod, MASTER_ITEMS_PATH)
	if not ok_items or type(MasterItems) ~= "table" then
		return nil
	end

	local ok_cache, items = pcall(MasterItems.get_cached)
	local item = ok_cache and type(items) == "table" and items[inventory_item_name] or nil

	if item then
		item_by_name[inventory_item_name] = item
	end
	return item
end

local scratch = {}

---@type PlayerField
local Field = {
	fields = {
		blitz = {

			is_equipped = DataTypes.field("boolean", "[true/false] whether the blitz is currently in hand"),
			icon = DataTypes.field("material", "[string|nil] path of material to blitz icon"),
			count = DataTypes.field("integer", "[0..n] number of currently available blitz charges"),
			max_count = DataTypes.field("integer", "[0..n] maximum number of blitz charges"),
			uses_charges = DataTypes.field("boolean", "[true/false] does the blitz use charges"),
			progress_percent_to_next_charge = DataTypes.field(
				"number",
				"[0..100] % recharge progress to the next blitz charge being ready"
			),
			progress_percent_to_max_charges = DataTypes.field(
				"number",
				"[0..100] % recharge progress to all blitz charges being ready"
			),
			cooldown_seconds_to_next_charge = DataTypes.field(
				"number",
				"[0..n] [seconds] seconds left until the next blitz charge is ready"
			),
			is_ready = DataTypes.field("boolean", "[true/false] whether at least one blitz charge is ready"),

			is_refilling = DataTypes.field("boolean", "[true/false] whether the blitz refills by itself"),

		},
	},
	sections = {
		{ id = "icon", label = "Icon" },
		{ id = "state", label = "State" },
		{ id = "charges", label = "Charges" },
	},
	field_meta = {
		["blitz.icon"] = { section = "state" },
		["blitz.is_equipped"] = { section = "state" },
		["blitz.count"] = { section = "charges" },
		["blitz.max_count"] = { section = "charges" },
		["blitz.is_ready"] = { section = "charges" },
		["blitz.is_refilling"] = { section = "charges" },
		["blitz.uses_charges"] = { section = "charges" },
		["blitz.progress_percent_to_next_charge"] = { section = "charges" },
		["blitz.cooldown_seconds_to_next_charge"] = { section = "charges" },
		["blitz.progress_percent_to_max_charges"] = { section = "charges" },
	},
	write = function(values, player, unit)

		local ability = Ability.read(unit, ABILITY_ID, scratch, player)

		local blitz = values.blitz or {}
		values.blitz = blitz
		blitz.id = ability.id
		blitz.count = ability.charges
		blitz.max_count = ability.max_charges

		blitz.progress_percent_to_next_charge = ability.progress_percent_to_next_charge
		blitz.progress_percent_to_max_charges = ability.progress_percent_to_max_charges
		blitz.cooldown_seconds_to_next_charge = ability.cooldown_seconds_to_next_charge
		blitz.is_ready = (ability.charges or 0) > 0

		blitz.uses_charges = (ability.max_charges or 0) > 0
		blitz.is_refilling = blitz.uses_charges and ability.has_cooldown

		blitz.is_throwable = not blitz.is_refilling

		local unit_data, visual_loadout = Player.extensions(unit, "unit_data_system", "visual_loadout_system")
		local item = LoadoutCache.item(player, visual_loadout, ABILITY_SLOT) or master_item(ability.inventory_item_name)
		blitz.icon = HARDCODED_ICON_FROM_ABILITY[ability.icon] and ability.icon or item and (item.hud_icon or item.icon)

		local inventory_comp = unit_data and unit_data:read_component("inventory")
		blitz.is_equipped = inventory_comp and inventory_comp.wielded_slot == ABILITY_SLOT or false

		blitz.name = (item and Localize.game(item.display_name)) or Localize.game(ability.name_loc) or nil

	end,
}

mod.hud_studio_player_blitz = Field
return Field
