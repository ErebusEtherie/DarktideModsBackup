-- ewc_owned_content.lua
--
-- Pilgrimage-owned EWC content. This is deliberately an external plugin for
-- standard Extended Weapon Customization: no EWC files are replaced, and no
-- third-party attachment pack is copied into Pilgrimage.

local M = {}

local _mod
local _debug_log
local _ewc
local _registered_kaizen = false
local _registered_traitor = false
local _effects_installed = false
local _wielding_traitor_plasma = false

local ITEM_ROOT = "content/items/weapons/player"
local EMPTY_ITEM = ITEM_ROOT .. "/trinkets/unused_trinket"
local K_NONE_ITEM = ITEM_ROOT .. "/melee/reskins/k_none"
local K_HIDE_ITEM = ITEM_ROOT .. "/reskins/k_hide_weapon"
local K_KARNAK_ITEM = ITEM_ROOT .. "/melee/reskins/k_karnak_sword"
local TP_NONE_ITEM = ITEM_ROOT .. "/ranged/reskins/tp_none"
local TP_TRAITOR_ITEM = ITEM_ROOT .. "/ranged/reskins/tp_traitor_plasma"
local MINION_SWORD_ITEM =
	"content/items/weapons/minions/melee/chaos_traitor_guard_2h_power_sword"
local MINION_PLASMA_ITEM =
	"content/items/weapons/minions/ranged/chaos_traitor_guard_trooper_plasma_gun"

local FAMILY_PARENTS = {
	arc_rifle = "receiver", autogun = "receiver", autopistol = "receiver",
	bolter = "receiver", boltpistol = "receiver", flamer = "receiver",
	galvanic_rifle = "receiver", lasgun = "receiver", laspistol = "receiver",
	needlepistol = "receiver", ogryn_heavystubber = "receiver",
	ogryn_rippergun = "receiver", ogryn_thumper = "receiver",
	phosphor_pistol = "receiver", plasmagun = "receiver", shotgun = "receiver",
	stubrevolver = "rail", shotpistol_shield = "left",
	dual_autopistols = "right", dual_stubpistols = "right",
	forcestaff = "body", chainsword = "grip", combataxe = "grip",
	combatknife = "grip", combatsword = "grip", forcesword = "grip",
	powersword = "grip", chainsword_2h = "hilt", forcesword_2h = "hilt",
	powersword_2h = "hilt", chainaxe = "shaft", ogryn_pickaxe_2h = "shaft",
	ogryn_powermaul = "shaft", powermaul = "shaft", powermaul_2h = "shaft",
	ogryn_gauntlet = "body", ogryn_combatblade = "body", ogryn_club = "shaft",
	ogryn_powermaul_slabshield = "left", powermaul_shield = "left",
	thunderhammer_2h = "head", crowbar = "body", dual_shivs = "right",
	saw = "right", transonic_sword_transonic_knife = "right",
}

local TEMPLATE_PARENTS = {
	ogryn_club_p2_m1 = "body",
}

local KARNAK_FAMILIES = {
	forcesword_2h = true,
	powersword_2h = true,
	powersword = true,
}

local HIDE_ALL_SLOTS = {
	"receiver", "barrel", "muzzle", "magazine", "stock", "sight", "rail",
	"flashlight", "grip", "grip_1", "grip_2", "foregrip", "bayonet",
	"cover", "cover_slide", "handle", "mount", "underbarrel", "blade",
	"pommel", "hilt", "hilt_1", "hilt_2", "connector", "body", "left",
	"right", "head", "shaft", "shaft_upper", "shaft_lower", "emblem_left",
	"emblem_right", "trinket_hook",
}

local KARNAK_HIDE_SLOTS = {
	"blade", "pommel", "hilt", "hilt_2", "emblem_left", "emblem_right",
	"trinket_hook",
}

local PLASMA_HIDE_SLOTS = {
	"receiver", "magazine", "barrel", "stock", "grip", "sight", "rail",
	"emblem_left", "emblem_right", "trinket_hook", "flashlight",
}

local HIDE_MESHES = {}
for i = 1, 40 do HIDE_MESHES[i] = i end

local function vector_box(x, y, z)
	local constructor = rawget(_G, "Vector3Box")
	return constructor and constructor(x, y, z) or { x, y, z }
end

local function family_for(template)
	if type(template) ~= "string" then return nil end
	return string.match(template, "^(.-)_p%d+_m%d+$")
end

local function empty_kitbash(name, attach_node, display_name)
	return {
		is_full_item = true,
		is_fallback_item = false,
		show_in_1p = true,
		only_show_in_1p = false,
		base_unit = "content/characters/empty_item/empty_item",
		item_list_faction = "Player",
		attach_node = attach_node,
		attachments = {
			zzz_shared_material_overrides = { item = "", children = {} },
		},
		resource_dependencies = {
			["content/characters/empty_item/empty_item"] = true,
		},
		display_name = display_name,
		name = name,
		tags = {},
		feature_flags = { "FEATURE_item_retained" },
		workflow_checklist = {},
		workflow_state = "RELEASABLE",
	}
end

local function ensure_weapon(plugin, template)
	plugin.attachments[template] = plugin.attachments[template] or {}
	plugin.attachments[template].skins =
		plugin.attachments[template].skins or {}
	plugin.attachment_slots[template] =
		plugin.attachment_slots[template] or {}
	plugin.fixes[template] = plugin.fixes[template] or {}
	return plugin.attachments[template].skins, plugin.fixes[template]
end

local function add_kaizen_skins(plugin, ewc)
	local known = ewc.settings and ewc.settings.attachments or {}
	for template in pairs(known) do
		local family = family_for(template)
		local parent = TEMPLATE_PARENTS[template]
			or (family and FAMILY_PARENTS[family])
		if parent then
			local skins, fixes = ensure_weapon(plugin, template)
			skins.k_none = {
				selection_index = 1,
				custom_selection_group = "kaizen_skins",
				replacement_path = K_NONE_ITEM,
				icon_render_unit_rotation_offset = { 90, -30, 0 },
				icon_render_camera_position_offset = { .1, -4, .9 },
			}
			skins.k_hide_weapon = {
				selection_index = 999,
				custom_selection_group = "kaizen_skins",
				replacement_path = K_HIDE_ITEM,
				icon_render_unit_rotation_offset = { 90, -30, 0 },
				icon_render_camera_position_offset = { .1, -4, .9 },
			}
			if KARNAK_FAMILIES[family] then
				skins.k_karnak_sword = {
					selection_index = 2,
					custom_selection_group = "kaizen_skins",
					replacement_path = K_KARNAK_ITEM,
					icon_render_unit_rotation_offset = { 90, -30, 0 },
					icon_render_camera_position_offset = { .1, -4, .9 },
				}
			end

			plugin.attachment_slots[template].skins = {
				parent_slot = parent,
				default_path = EMPTY_ITEM,
			}

			for _, slot in ipairs(HIDE_ALL_SLOTS) do
				fixes[#fixes + 1] = {
					attachment_slot = slot,
					requirements = { skins = { has = "k_hide_weapon" } },
					fix = {
						hide = { node = 1, mesh = HIDE_MESHES },
						alpha = 1,
					},
				}
			end

			if KARNAK_FAMILIES[family] then
				for _, slot in ipairs(KARNAK_HIDE_SLOTS) do
					fixes[#fixes + 1] = {
						attachment_slot = slot,
						requirements = { skins = { has = "k_karnak_sword" } },
						fix = { hide = { mesh = HIDE_MESHES }, alpha = 1 },
					}
				end
				fixes[#fixes + 1] = {
					attachment_slot = "grip",
					requirements = { skins = { has = "k_karnak_sword" } },
					fix = { hide = { mesh = HIDE_MESHES } },
				}
				fixes[#fixes + 1] = {
					attachment_slot = "skins",
					requirements = { skins = { has = "k_karnak_sword" } },
					fix = { offset = {
						position = vector_box(0, 0, 0),
						rotation = vector_box(0, 0, 0),
						scale = vector_box(1, 1, 1),
					} },
				}
			end
		end
	end

	plugin.kitbashs[K_NONE_ITEM] =
		empty_kitbash(K_NONE_ITEM, "ap_grip_01", "loc_k_none")
	plugin.kitbashs[K_HIDE_ITEM] =
		empty_kitbash(K_HIDE_ITEM, "ap_grip_01", "loc_k_hide_weapon")
	local sword = empty_kitbash(
		K_KARNAK_ITEM, "ap_grip_01", "loc_k_karnak_sword")
	sword.attachments.k_sword = {
		item = MINION_SWORD_ITEM,
		fix = { offset = {
			position = vector_box(0, 0, 0),
			rotation = vector_box(0, 0, 0),
			scale = vector_box(1, 1, 1),
		} },
	}
	plugin.kitbashs[K_KARNAK_ITEM] = sword
end

local function add_traitor_plasma(plugin)
	for _, template in ipairs({ "plasmagun_p1_m1", "plasmagun_p1_m2" }) do
		local skins, fixes = ensure_weapon(plugin, template)
		skins.tp_none = {
			selection_index = 1,
			custom_selection_group = "traitor_plasma",
			replacement_path = TP_NONE_ITEM,
			icon_render_unit_rotation_offset = { 90, 0, 45 },
			icon_render_camera_position_offset = { -.1, -1.75, .25 },
		}
		skins.tp_traitor_plasma = {
			selection_index = 2,
			custom_selection_group = "traitor_plasma",
			replacement_path = TP_TRAITOR_ITEM,
			icon_render_unit_rotation_offset = { 90, 0, 45 },
			icon_render_camera_position_offset = { -.1, -1.75, .25 },
		}
		plugin.attachment_slots[template].skins = {
			parent_slot = "receiver",
			default_path = EMPTY_ITEM,
		}
		for _, slot in ipairs(PLASMA_HIDE_SLOTS) do
			local fix = { hide = { mesh = HIDE_MESHES } }
			if slot ~= "receiver" then fix.alpha = 1 end
			fixes[#fixes + 1] = {
				attachment_slot = slot,
				requirements = { skins = { has = "tp_traitor_plasma" } },
				fix = fix,
			}
		end
		fixes[#fixes + 1] = {
			attachment_slot = "skins",
			requirements = { skins = { has = "tp_traitor_plasma" } },
			fix = { offset = {
				position = vector_box(0, 0, 0),
				rotation = vector_box(0, 0, 0),
				scale = vector_box(1, 1, 1),
			} },
		}
	end

	plugin.kitbashs[TP_NONE_ITEM] =
		empty_kitbash(TP_NONE_ITEM, "ap_receiver_01", "loc_tp_none")
	local plasma = empty_kitbash(
		TP_TRAITOR_ITEM, "ap_receiver_01", "loc_tp_traitor_plasma")
	plasma.attachments.tp_gun = {
		item = MINION_PLASMA_ITEM,
		fix = { offset = {
			position = vector_box(0, 0, 0),
			rotation = vector_box(0, 0, 0),
			scale = vector_box(1, 1, 1),
		} },
	}
	plugin.kitbashs[TP_TRAITOR_ITEM] = plasma
	plugin.packages_to_load[
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_captain"] = true
	plugin.packages_to_load[
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_orange"] = true
	plugin.packages_to_load[
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger_orange"] = true
	plugin.packages_to_load[
		"content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_explosion_medium"] = true
end

local function has_internal_pack(ewc, id)
	local pack = ewc and ewc.internal_packs and ewc.internal_packs[id]
	return type(pack) == "table"
		and type(pack.extended_weapon_customization_plugin) == "table"
end

local function build_plugin(ewc)
	local plugin = {
		attachments = {}, attachment_slots = {}, fixes = {}, kitbashs = {},
		packages_to_load = {},
	}
	if not has_internal_pack(ewc, "kskins") then
		add_kaizen_skins(plugin, ewc)
		_registered_kaizen = true
	end
	local get_mod_fn = rawget(_G, "get_mod")
	local standalone = get_mod_fn and get_mod_fn("traitor_plasma")
	if not has_internal_pack(ewc, "tplasma") and not standalone then
		add_traitor_plasma(plugin)
		_registered_traitor = true
	end
	return plugin
end

local MUZZLE_SWAPS = {
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_ks"] =
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_captain",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_bfg"] =
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_captain",
}
local PARTICLE_SWAPS = {
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam"] =
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_orange",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger"] =
		"content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger_orange",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_small"] =
		"content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_explosion_medium",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_medium"] =
		"content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_explosion_medium",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_large"] =
		"content/fx/particles/enemies/renegade_plasma_trooper/renegade_plasma_explosion_medium",
}
local HEAT_ALIASES = {
	ranged_charging = true, ranged_fast_charging = true,
	ranged_plasma_venting = true, plasma_venting = true,
	weapon_overload_loop = true,
}

local function item_has_traitor_skin(item)
	if not item or not _ewc then return false end
	local attachments = item.attachments
		or (item.__master_item and item.__master_item.attachments)
	if attachments and type(_ewc.fetch_attachment) == "function" then
		local ok, path = pcall(_ewc.fetch_attachment, _ewc, attachments, "skins")
		if ok and path == TP_TRAITOR_ITEM then return true end
	end
	if type(_ewc.gear_id) == "function" and type(_ewc.gear_settings) == "function" then
		local ok_id, id = pcall(_ewc.gear_id, _ewc, item)
		local ok_settings, settings = false, nil
		if ok_id and id then
			ok_settings, settings = pcall(_ewc.gear_settings, _ewc, id)
		end
		local chosen = ok_settings and settings and settings.attachments
			and settings.attachments.skins
		return chosen == "tp_traitor_plasma" or chosen == TP_TRAITOR_ITEM
	end
	return false
end

function M.try_install_effects()
	if _effects_installed then return true, "already installed" end
	if not _registered_traitor then return false, "handled by existing Traitor Plasma content" end
	if not _mod or not _ewc or not rawget(_G, "CLASS") then
		return false, "runtime classes unavailable"
	end
	local weapon_extension = CLASS.PlayerUnitWeaponExtension
	local fx_extension = CLASS.PlayerUnitFxExtension
	if not weapon_extension or not fx_extension or not rawget(_G, "World") then
		return false, "plasma effect hooks unavailable"
	end

	_mod:hook_safe(weapon_extension, "_wielded_weapon",
		function(self, inventory_component, weapons)
			local slot = inventory_component and inventory_component.wielded_slot
			local weapon = weapons and slot and weapons[slot]
			local item = weapon and weapon.item
			local name = item and (item.name
				or (item.__master_item and item.__master_item.name)) or ""
			_wielding_traitor_plasma = string.find(name, "plasmagun", 1, true) ~= nil
				and item_has_traitor_skin(item)
		end)

	_mod:hook(fx_extension, "spawn_looping_particles",
		function(func, self, alias, ...)
			if _wielding_traitor_plasma and HEAT_ALIASES[alias] then
				local manager = rawget(_G, "Managers") and Managers.player
				local player = manager and manager:local_player_safe(1)
				if player and player.player_unit == self._unit then return end
			end
			return func(self, alias, ...)
		end)

	_mod:hook(World, "create_particles", function(func, world, particles, pos, ...)
		if _wielding_traitor_plasma then
			particles = MUZZLE_SWAPS[particles] or PARTICLE_SWAPS[particles] or particles
		end
		return func(world, particles, pos, ...)
	end)

	_effects_installed = true
	return true, "installed"
end

function M.status()
	return {
		kaizen_skins = _registered_kaizen,
		traitor_plasma = _registered_traitor,
		traitor_effects = _effects_installed,
	}
end

function M.init(deps)
	_mod = deps.mod
	_debug_log = deps.debug_log or function() end
	local get_mod_fn = rawget(_G, "get_mod")
	_ewc = get_mod_fn and get_mod_fn("extended_weapon_customization")
	if type(_ewc) ~= "table" then
		_debug_log("ewc_owned_content:init", 0,
			"EWC absent; owned content bridge inactive", 0, "info")
		return
	end
	local plugin = build_plugin(_ewc)
	if _registered_kaizen or _registered_traitor then
		_mod.extended_weapon_customization_plugin = plugin
		_debug_log("ewc_owned_content:init", 0,
			"registered Pilgrimage-owned EWC content", 0, "info")
	end
end

return M
