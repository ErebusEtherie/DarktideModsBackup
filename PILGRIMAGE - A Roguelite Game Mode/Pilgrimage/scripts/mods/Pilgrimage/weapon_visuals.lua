-- weapon_visuals.lua
--
-- Optional presentation layer for Pilgrimage's transformed weapon marks.
-- Standard Extended Weapon Customization still owns all attachment injection.
-- Pilgrimage only supplies an in-memory default when that exact gear item has
-- no EWC settings of its own. Nothing is saved into EWC and a player-authored
-- customization always wins.

local M = {}

local _mod
local _settings
local _debug_log
local _installed = false

local UNUSED = "content/items/weapons/player/trinkets/unused_trinket"

-- These are not invented configurations. They are the cleaned attachment sets
-- captured from Kaizen's Kasrkin Marksman, Tech Priest, Theodora,
-- Ministorum Flamer and Lord Magleviathan.
-- Entries unavailable in a user's installed EWC catalogue are dropped at use
-- time, allowing standard parts to survive when an optional pack is absent.
local DEFAULTS = {
	autogun_p2_m3 = {
		muzzle = "content/items/weapons/player/ranged/muzzles/autogun_rifle_ak_muzzle_03",
		magazine = "content/items/weapons/player/ranged/magazines/syn_hag_magazine_01_auto",
		receiver = "content/items/weapons/player/ranged/recievers/autogun_rifle_killshot_receiver_03",
		syn_ammo_belt_extension = "content/items/weapons/player/trinkets/unused_trinket",
		barrel_foreskin = "content/items/weapons/player/trinkets/unused_trinket",
		stock = "content/items/weapons/player/ranged/stocks/owo_tactical_stock_folded_n_u",
		skins = "content/items/weapons/player/trinkets/unused_trinket",
		dakka_carry_handle = "content/items/weapons/player/ranged/dakka_carry_handle/dakka_carry_handle_03",
		rail = "content/items/weapons/player/ranged/rails/stubgun_pistol_rail_off",
		flashlight = "content/items/weapons/player/trinkets/unused_trinket",
		trinket_hook = "content/items/weapons/player/trinkets/unused_trinket",
		sight_reticle = "content/items/weapons/player/trinkets/unused_trinket",
		emblem_left = "content/items/weapons/player/trinkets/unused_trinket",
		sight = "content/items/weapons/player/ranged/sights/autogun_rifle_ak_sight_01",
		grip = "content/items/weapons/player/ranged/grips/autogun_rifle_grip_02",
		barrel = "content/items/weapons/player/ranged/barrels/syn_primaris_barrel_06_autogun",
	},
	autogun_p3_m2 = {
		sight_reticle = UNUSED,
		rail = "content/items/weapons/player/ranged/rails/stubgun_pistol_rail_off",
		flashlight = UNUSED,
		trinket_hook = "content/items/weapons/player/trinkets/trinket_hook_05_coated",
		syn_magwell_extension = "content/items/weapons/player/ranged/magwell/syn_m41a_magwell_01",
		barrel_foreskin = UNUSED,
		barrel = "content/items/weapons/player/ranged/barrels/syn_autogun_stubgun_barrel_05",
		grip = "content/items/weapons/player/ranged/grips/autogun_rifle_grip_killshot_01",
		magazine = "content/items/weapons/player/ranged/magazines/autogun_rifle_magazine_03",
		syn_bipod = "content/items/weapons/player/ranged/bipod/syn_bipod_02",
		receiver = "content/items/weapons/player/ranged/recievers/autogun_rifle_killshot_receiver_03",
		skins = UNUSED,
		muzzle = "content/items/weapons/player/ranged/muzzles/syn_silencer_01",
		stock = "content/items/weapons/player/ranged/stocks/syn_reinforced_stock_02",
		sight = "content/items/weapons/player/ranged/sights/aquilon_scope_01f",
	},
	plasmagun_p1_m2 = {
		emblem_left = UNUSED,
		emblem_right = UNUSED,
		trinket_hook = "content/items/weapons/player/trinkets/trinket_hook_05_coated",
		syn_sightrail = "content/items/weapons/player/ranged/syn_heavyplasma_sightrail_00",
		syn_mag_ext = "content/items/weapons/player/ranged/magazines/syn_hag_extension_01",
		rail = UNUSED,
		barrel = "content/items/weapons/player/ranged/barrels/plasma_rifle_barrel_ml01",
		grip = "content/items/weapons/player/ranged/grips/plasma_rifle_grip_03",
		magazine = "content/items/weapons/player/ranged/magazines/plasma_rifle_magazine_ml01",
		receiver = "content/items/weapons/player/ranged/recievers/syn_heavyplasma_receiver_ml01",
		syn_receiver_extension = "content/items/weapons/player/ranged/receiver_extension/ma5_extension_19",
		skins = UNUSED,
		flashlight = UNUSED,
		stock = "content/items/weapons/player/ranged/stocks/syn_slim_plasma_rifle_stock_ml01",
		sight = UNUSED,
	},
	boltpistol_p1_m2 = {
		grip = "content/items/weapons/player/ranged/grips/boltgun_pistol_grip_01",
		receiver = "content/items/weapons/player/ranged/recievers/syn_plasma_pistol_receiver_02",
		barrel_foreskin = UNUSED,
		barrel = "content/items/weapons/player/ranged/barrel/syn_plasma_pistol_barrel_08",
		muzzle = UNUSED,
		magazine = "content/items/weapons/player/ranged/magazines/syn_plasma_pistol_magazine_06",
		sight = "content/items/weapons/player/ranged/sights/boltgun_pistol_sight_02",
		sight_reticle = UNUSED,
		trinket_hook = "content/items/weapons/player/trinkets/trinket_hook_01",
		syn_filler = "content/items/weapons/player/ranged/syn_no_sight",
		syn_rail = "content/items/weapons/player/ranged/rails/stubgun_pistol_rail_off",
		skins = "content/items/weapons/player/melee/reskins/k_none",
		flashlight = UNUSED,
	},
	flamer_p1_m1 = {
		barrel = "content/items/weapons/player/ranged/barrels/syn_vindictor_barrel_04",
		magazine = "content/items/weapons/player/ranged/magazines/flamer_rifle_magazine_01",
		grip = "content/items/weapons/player/ranged/grips/flamer_rifle_grip_06",
		receiver = "content/items/weapons/player/ranged/recievers/flamer_rifle_receiver_04",
		skins = UNUSED,
		stock = "content/items/weapons/player/ranged/stocks/syn_reinforced_stock_04_alt",
		flashlight = UNUSED,
		emblem_left = UNUSED,
		emblem_right = UNUSED,
		trinket_hook = "content/items/weapons/player/trinkets/trinket_hook_01",
	},
    -- The Hunter's ordinary Heavy Stubber look belongs only to his bot capture.
    -- Do not add a player default until an Autocannon appearance is approved.
}

local function item_data(ewc, item)
	if type(ewc.item_data) == "function" then
		local ok, resolved = pcall(ewc.item_data, ewc, item)
		if ok and type(resolved) == "table" then return resolved end
	end
	return type(item) == "table" and item or nil
end

local function gear_id(ewc, item, fake_gear_id)
	if type(ewc.gear_id) ~= "function" then return nil end
	local ok, resolved = pcall(ewc.gear_id, ewc, item, fake_gear_id)
	return ok and resolved or nil
end

local function has_player_settings(ewc, id)
	if not id or type(ewc.gear_settings) ~= "function" then return false end
	local ok, saved = pcall(ewc.gear_settings, ewc, id)
	return ok and type(saved) == "table"
end

local function validated_defaults(ewc, weapon_template)
	local source = DEFAULTS[weapon_template]
	if type(source) ~= "table" then return nil end
	local registry = ewc.settings and ewc.settings.attachment_data_by_item_string
	if type(registry) ~= "table" then return nil end

	local out = {}
	for slot, path in pairs(source) do
		-- EWC's registry is the authoritative catalogue after all installed packs
		-- have loaded. Unknown addon paths are omitted instead of being handed to
		-- the engine as missing resources.
		if type(path) == "string" and rawget(registry, path) ~= nil then
			out[slot] = path
		end
	end
	return next(out) and out or nil
end

function M.try_install()
	if _installed then return true, "already installed" end
	local get_mod_fn = rawget(_G, "get_mod") or get_mod
	local ewc = get_mod_fn and get_mod_fn("extended_weapon_customization")
	if type(ewc) ~= "table" or type(ewc.modify_item) ~= "function" then
		return false, "Extended Weapon Customization not installed"
	end

	_mod:hook(ewc, "modify_item",
		function(func, self, raw_item, fake_gear_id, optional_settings, ...)
			if optional_settings ~= nil
				or not _settings.custom_weapon_visuals_enabled() then
				return func(self, raw_item, fake_gear_id, optional_settings, ...)
			end

			local item = item_data(self, raw_item)
			local template = item and item.weapon_template
			if not DEFAULTS[template] then
				return func(self, raw_item, fake_gear_id, optional_settings, ...)
			end

			-- Calling gear_settings here also lets EWC load an existing file-backed
			-- customization. Any table, even an intentionally sparse one, belongs to
			-- the player and suppresses Pilgrimage's visual default completely.
			if has_player_settings(self, gear_id(self, item, fake_gear_id)) then
				return func(self, raw_item, fake_gear_id, optional_settings, ...)
			end

			local defaults = validated_defaults(self, template)
			return func(self, raw_item, fake_gear_id, defaults, ...)
		end)

	_installed = true
	_debug_log("weapon_visuals:install", 0,
		"installed optional EWC visual-default bridge", 0, "info")
	return true, "installed"
end

function M.status()
	local marks = 0
	for _ in pairs(DEFAULTS) do marks = marks + 1 end
	return {
		installed = _installed,
		enabled = _settings and _settings.custom_weapon_visuals_enabled() or false,
		marks = marks,
	}
end

function M.init(deps)
	_mod = deps.mod
	_settings = deps.settings
	_debug_log = deps.debug_log or function() end
end

return M
