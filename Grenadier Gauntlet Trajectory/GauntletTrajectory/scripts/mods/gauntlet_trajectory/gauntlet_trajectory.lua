-- GauntletTrajectory
-- Adds the same trajectory prediction arc used by the Grenade Launcher to the Ogryn Grenadier Gauntlet.
-- Principle: reuse the game's built-in AimProjectileAdsEffects aim script, inject
-- projectile_aim_effect_settings into the gauntlet's alternate_fire_settings,
-- and register the script in wieldable_slot_scripts.

local mod = get_mod("GauntletTrajectory")

-- Use original_require to get the game's original (un-hooked) modules
local WeaponTemplates = mod:original_require("scripts/settings/equipment/weapon_templates/weapon_templates")
local ProjectileTemplates = mod:original_require("scripts/settings/projectile/player_projectile_templates")
local Action = mod:original_require("scripts/utilities/action/action")
-- Required to hook the child class directly (class() copies parent methods).
local AimProjectileAdsEffects = mod:original_require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/aim_projectile_ads_effects")

-- Gauntlet weapon template name
local GAUNTLET_TEMPLATE_NAME = "ogryn_gauntlet_p1_m1"
-- Aim script class name (matches the class registered in aim_projectile_ads_effects.lua)
local ADS_SCRIPT_NAME = "AimProjectileAdsEffects"

-- Default settings (matches Ogryn Thumper P1 M2's projectile_aim_effect_settings,
-- but projectile_template uses the gauntlet's own ogryn_gauntlet_grenade)
local DEFAULT_SETTINGS = {
	arc_show_delay      = 0.1,
	arc_vfx_spawner_name = "_muzzle",
	stop_on_impact      = false,
	throw_type          = "shoot",
	use_sway_and_recoil = false,
	arc_start_offset    = Vector3Box(0.15, 1.5, -0.2),
}

-- Save the original fields before injection so they can be restored on disable/unload
local _original_state = {
	had_projectile_aim_effect_settings = false,
	had_wieldable_slot_scripts         = false,
	wieldable_slot_scripts             = nil,
	projectile_aim_effect_settings     = nil,
}

-- Read and apply user settings
-- Note: AimProjectileAdsEffects._trajectory_settings reads
--       projectile_aim_effect_settings.projectile_template.locomotion_template,
--       so projectile_template is a required field; use the gauntlet's own ogryn_gauntlet_grenade.
local function _build_settings()
	local settings = {
		arc_show_delay       = mod:get("arc_show_delay"),
		arc_vfx_spawner_name = DEFAULT_SETTINGS.arc_vfx_spawner_name,
		stop_on_impact       = mod:get("stop_on_impact"),
		throw_type           = DEFAULT_SETTINGS.throw_type,
		use_sway_and_recoil  = mod:get("use_sway_and_recoil"),
		arc_start_offset     = DEFAULT_SETTINGS.arc_start_offset,
		projectile_template  = ProjectileTemplates.ogryn_gauntlet_grenade,
	}

	-- x / y / z offset components
	local offset_x = mod:get("arc_start_offset_x")
	local offset_y = mod:get("arc_start_offset_y")
	local offset_z = mod:get("arc_start_offset_z")
	settings.arc_start_offset = Vector3Box(offset_x, offset_y, offset_z)

	return settings
end

-- Inject trajectory prediction into the gauntlet weapon template
local function apply_trajectory_prediction()
	local weapon_template = WeaponTemplates[GAUNTLET_TEMPLATE_NAME]
	if not weapon_template then
		mod:warning("Weapon template not found: " .. GAUNTLET_TEMPLATE_NAME)
		return
	end

	local alternate_fire_settings = weapon_template.alternate_fire_settings
	if not alternate_fire_settings then
		mod:warning("alternate_fire_settings not found in weapon template")
		return
	end

	-- Inject projectile_aim_effect_settings
	alternate_fire_settings.projectile_aim_effect_settings = _build_settings()

	-- Register the AimProjectileAdsEffects aim script
	if not weapon_template.wieldable_slot_scripts then
		weapon_template.wieldable_slot_scripts = {}
	end

	-- Avoid duplicate registration
	local already_registered = false
	for _, script_name in ipairs(weapon_template.wieldable_slot_scripts) do
		if script_name == ADS_SCRIPT_NAME then
			already_registered = true
			break
		end
	end

	if not already_registered then
		table.insert(weapon_template.wieldable_slot_scripts, ADS_SCRIPT_NAME)
	end
end

-- Restore the gauntlet weapon template (called on disable/unload)
local function revert_trajectory_prediction()
	local weapon_template = WeaponTemplates[GAUNTLET_TEMPLATE_NAME]
	if not weapon_template then
		return
	end

	local alternate_fire_settings = weapon_template.alternate_fire_settings
	if alternate_fire_settings then
		if not _original_state.had_projectile_aim_effect_settings then
			alternate_fire_settings.projectile_aim_effect_settings = nil
		else
			alternate_fire_settings.projectile_aim_effect_settings = _original_state.projectile_aim_effect_settings
		end
	end

	if not _original_state.had_wieldable_slot_scripts then
		weapon_template.wieldable_slot_scripts = nil
	else
		weapon_template.wieldable_slot_scripts = table.clone(_original_state.wieldable_slot_scripts)
	end
end

-- Record the original state so it can be restored
local function record_original_state()
	local weapon_template = WeaponTemplates[GAUNTLET_TEMPLATE_NAME]
	if not weapon_template then
		return
	end

	local alternate_fire_settings = weapon_template.alternate_fire_settings
	if alternate_fire_settings then
		_original_state.had_projectile_aim_effect_settings = alternate_fire_settings.projectile_aim_effect_settings ~= nil
		_original_state.projectile_aim_effect_settings = alternate_fire_settings.projectile_aim_effect_settings
	end

	_original_state.had_wieldable_slot_scripts = weapon_template.wieldable_slot_scripts ~= nil
	_original_state.wieldable_slot_scripts = weapon_template.wieldable_slot_scripts and table.clone(weapon_template.wieldable_slot_scripts) or nil
end

-- Initialization: record original state and apply modifications
record_original_state()
apply_trajectory_prediction()

-- Re-apply on setting change (takes effect on the next wield)
mod.on_setting_changed = function(setting_id)
	apply_trajectory_prediction()
end

-- Re-apply when the mod is enabled
mod.on_enabled = function()
	apply_trajectory_prediction()
end

-- Restore when the mod is disabled
mod.on_disabled = function()
	revert_trajectory_prediction()
end

-- Restore when the mod is unloaded
mod.on_unload = function()
	revert_trajectory_prediction()
end

-- #####################################################################################################################
-- # Crosshair hide logic                                                                                              #
-- #####################################################################################################################
-- The gauntlet normally shows a projectile_drop crosshair while aiming down sights (ADS),
-- which visually conflicts with the newly added trajectory arc.
-- Here we hook HudElementCrosshair._get_current_crosshair_type and return "none" while the gauntlet is in ADS.
-- Only active when the hide_crosshair_during_ads setting is enabled; has no effect on other weapons.

-- These action kinds indicate the player is entering or leaving ADS
local ADS_ACTION_KINDS = {
	aim   = true,
	unaim = true,
}

mod:hook("HudElementCrosshair", "_get_current_crosshair_type", function(func, self, crosshair_settings)
	local crosshair_type = func(self, crosshair_settings)

	-- Only intervene when the original result is not "none" and the user has enabled crosshair hiding
	if crosshair_type ~= "none" and mod:get("hide_crosshair_during_ads") then
		local parent = self._parent
		local player_extensions = parent and parent:player_extensions()
		local unit_data = player_extensions and player_extensions.unit_data
		local weapon_action = unit_data and unit_data:read_component("weapon_action")

		if weapon_action and weapon_action.template_name == GAUNTLET_TEMPLATE_NAME then
			local weapon_template = WeaponTemplates[GAUNTLET_TEMPLATE_NAME]
			local _, action_settings = Action.current_action(weapon_action, weapon_template)
			local action_kind = action_settings and action_settings.kind

			local alternate_fire = unit_data:read_component("alternate_fire")
			local in_ads = (alternate_fire and alternate_fire.is_active)
				or (action_kind and ADS_ACTION_KINDS[action_kind])

			if in_ads then
				return "none"
			end
		end
	end

	return crosshair_type
end)

-- Fix: with stop_on_impact, a close-target hit leaves only 2 aim_data entries,
-- failing the renderer's "> 1" check. Pad to 3; aim_data[3] is never read when
-- aim_data[1].has_hit. Hook the child class because class() copies parent methods.

mod:hook(AimProjectileAdsEffects, "_set_trajectory_positions_spline", function(func, self, aim_data, number_of_aim_data, arc_offset, total_distance, arc_distances, dt)
	if number_of_aim_data == 2 and aim_data[1] and aim_data[1].has_hit then
		number_of_aim_data = 3
	end

	return func(self, aim_data, number_of_aim_data, arc_offset, total_distance, arc_distances, dt)
end)
