-- GauntletTrajectory
-- Adds the same trajectory prediction arc used by the Grenade Launcher to the Ogryn Grenadier Gauntlet,
-- draws an explosion radius circle at the trajectory's landing point while aiming (projected onto the
-- ground below the actual impact point — following the aim — when the trajectory line ends on an enemy),
-- and highlights the enemy the trajectory line ends on with an outline of a configurable color.
-- Principle: reuse the game's built-in AimProjectileAdsEffects aim script, inject
-- projectile_aim_effect_settings into the gauntlet's alternate_fire_settings,
-- and register the script in wieldable_slot_scripts.
-- While aiming, the trajectory (and its explosion circle) also stays visible between two shots while
-- the right mouse button is held: the game's hide_arc flag of the shoot action is bypassed and a
-- hypothetical trajectory is projected from the configured arc start position every frame.

local mod = get_mod("GauntletTrajectory")

-- Use original_require to get the game's original (un-hooked) modules
local WeaponTemplates = mod:original_require("scripts/settings/equipment/weapon_templates/weapon_templates")
local ProjectileTemplates = mod:original_require("scripts/settings/projectile/player_projectile_templates")
local Action = mod:original_require("scripts/utilities/action/action")
local Ammo = mod:original_require("scripts/utilities/ammo")
local Explosion = mod:original_require("scripts/utilities/attack/explosion")
-- Required to hook the child class directly (class() copies parent methods).
local AimProjectileAdsEffects = mod:original_require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/aim_projectile_ads_effects")

-- Gauntlet weapon template name
local GAUNTLET_TEMPLATE_NAME = "ogryn_gauntlet_p1_m1"
-- Aim script class name (matches the class registered in aim_projectile_ads_effects.lua)
local ADS_SCRIPT_NAME = "AimProjectileAdsEffects"

-- Cached settings, read once at load and updated item-by-item in on_setting_changed.
-- Per-frame hooks must read this table instead of mod:get(): table settings (colors)
-- get deep-cloned on every mod:get call, which is too expensive for the aim hooks.
-- Note: DMF loads mod_data (which seeds default values) before mod_script,
-- so mod:get here always returns a valid value.
local mod_settings = {
	arc_show_delay              = mod:get("arc_show_delay"),
	use_sway_and_recoil         = mod:get("use_sway_and_recoil"),
	use_custom_arc_start_offset = mod:get("use_custom_arc_start_offset"),
	arc_start_offset_x          = mod:get("arc_start_offset_x"),
	arc_start_offset_y          = mod:get("arc_start_offset_y"),
	arc_start_offset_z          = mod:get("arc_start_offset_z"),
	hide_crosshair_during_ads   = mod:get("hide_crosshair_during_ads"),
	keep_arc_while_aiming       = mod:get("keep_arc_while_aiming"),
	show_explosion_radius       = mod:get("show_explosion_radius"),
	explosion_radius            = mod:get("explosion_radius"),
	explosion_circle_color      = mod:get("explosion_circle_color"),
	show_target_outline         = mod:get("show_target_outline"),
	target_outline_priority     = mod:get("target_outline_priority"),
	target_outline_color        = mod:get("target_outline_color"),
}

-- Default settings (matches Ogryn Thumper P1 M2's projectile_aim_effect_settings, but
-- projectile_template uses the gauntlet's own ogryn_gauntlet_grenade). Unlike the Thumper,
-- the gauntlet grenade explodes on its first impact and can never bounce, so stop_on_impact
-- is hardcoded to true in _build_settings instead of being a user setting.
local DEFAULT_SETTINGS = {
	arc_show_delay       = 0.1,
	arc_vfx_spawner_name = "_muzzle",
	throw_type           = "shoot",
	use_sway_and_recoil  = false,
	arc_start_offset     = Vector3Box(0.15, 1.5, -0.2),
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
		arc_show_delay       = mod_settings.arc_show_delay,
		arc_vfx_spawner_name = DEFAULT_SETTINGS.arc_vfx_spawner_name,
		-- The gauntlet grenade explodes on its first impact (damage.impact.explosion_template),
		-- so the real shot can never bounce — always stop the aim arc at the first impact to
		-- match what the grenade actually does.
		stop_on_impact       = true,
		throw_type           = DEFAULT_SETTINGS.throw_type,
		use_sway_and_recoil  = mod_settings.use_sway_and_recoil,
		projectile_template  = ProjectileTemplates.ogryn_gauntlet_grenade,
	}

	-- Arc start offset: fixed mod default (the Thumper-matching 0.15, 1.5, -0.2) unless the
	-- user explicitly enables custom offsets. The game unboxes arc_start_offset per frame
	-- (aim_projectile_ads_effects.lua: _trajectory_settings), and on_setting_changed re-runs
	-- apply_trajectory_prediction, so toggling the switch takes effect immediately.
	if mod_settings.use_custom_arc_start_offset then
		settings.arc_start_offset = Vector3Box(mod_settings.arc_start_offset_x, mod_settings.arc_start_offset_y, mod_settings.arc_start_offset_z)
	else
		settings.arc_start_offset = DEFAULT_SETTINGS.arc_start_offset
	end

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

-- #####################################################################################################################
-- # Explosion radius circle                                                                                           #
-- #####################################################################################################################
-- The gauntlet grenade (ogryn_gauntlet_grenade) explodes on its first impact, so the trajectory's landing
-- point is the first aim data entry flagged as a hit — unless its 1s fuse expires first, in which case it
-- detonates mid-air and no ground circle is shown. While the arc is visible we draw a ground decal circle
-- at that position, sized to the grenade's explosion radius. When the trajectory line ends on a living
-- enemy, the circle is instead placed on the ground directly below the actual impact point (the point on
-- the enemy's body the line ends on), so the circle follows the aim position as it moves over the enemy,
-- and hidden when there is no ground within reach below that point. The radius is computed the same way
-- the game does it (Explosion.radii, weapon traits and stat buffs included) unless overridden via mod
-- settings.

local DECAL_PATH     = "content/levels/training_grounds/fx/decal_aoe_indicator"
local PACKAGE_PATH   = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local DECAL_Z_OFFSET = 0.05
local FALLBACK_EXPLOSION_RADIUS = 3 -- base radius of default_gauntlet_grenade
-- Out-of-sight park position the decal unit is spawned at. A freshly spawned unit can
-- reach the renderer for one frame with its spawn pose before the scale set later in
-- the same frame lands, which flashed the decal briefly at its authored (much smaller)
-- size at the landing point. Spawning it far away hides that first frame — the game
-- does the same for its aim-facing AOE decal (force_staff_aoe_targeting_effects.lua:
-- SPAWN_POS = Vector3Box(400, 400, 400)).
local DECAL_SPAWN_POSITION = Vector3Box(400, 400, 400)

-- Ground projection: when the trajectory line ends on a living enemy, the circle is drawn on the ground
-- directly below the impact point (the point on the enemy's body the line ends on) instead of at the
-- point itself, so the circle follows the aim position. The ground is found with a downward physics
-- raycast that only tests static geometry — the same filter the game's AOE unit spawner uses to snap
-- spawn positions onto the ground (area_of_effect_unit_spawner_extension.lua) — so the enemy's own
-- physics body never occludes the ray and the surface below the impact point is reached. A cast that
-- finds nothing (e.g. the impact point is far above a gap) hides the circle.
local GROUND_PROBE_START_OFFSET = Vector3Box(0, 0, 0.05) -- cast starts a hair above the impact point so a point exactly on a surface cannot self-intersect
local GROUND_PROBE_DISTANCE = 5 -- a surface farther below the impact point than this does not count as "the ground below" (covers head-height impacts on the tallest enemies)
local GROUND_PROBE_TYPES = "statics"
local GROUND_PROBE_COLLISION_FILTER = "filter_player_character_shooting_raycast_statics"

-- Fuse of the gauntlet grenade: it detonates mid-air this many seconds after launch if it
-- hasn't hit anything first (projectile_damage_extension counts it from launch, and the
-- gauntlet's shoot action never passes a fuse_override). Used to reject simulated landing
-- points the real grenade could never reach.
local _gauntlet_locomotion_template = ProjectileTemplates.ogryn_gauntlet_grenade.locomotion_template
local _gauntlet_trajectory_parameters = _gauntlet_locomotion_template.trajectory_parameters.shoot
local _fuse_time = ProjectileTemplates.ogryn_gauntlet_grenade.damage.fuse and ProjectileTemplates.ogryn_gauntlet_grenade.damage.fuse.fuse_time
local _aim_time_step_multiplier = _gauntlet_trajectory_parameters.aim_time_step_multiplier or 1

local _explosion_decal = {
	unit       = nil,
	package_id = nil,
}

-- Load (in the background) the package that contains the decal unit and keep the
-- load-call id, so the reference can be released again (see _release_decal_package).
-- Skipped entirely while the circle feature is off, so a disabled circle
-- costs no extra package memory in regular missions.
local function _ensure_decal_package_loaded()
	if not mod_settings.show_explosion_radius then
		return
	end

	if not (Managers and Managers.package) then
		return
	end

	-- package_id is the single "we hold a reference" guard: set the moment the load is
	-- requested, cleared only by _release_decal_package, so the same reference is never
	-- requested twice. Requesting a load for an already loaded / still loading package
	-- is fine — the package manager just registers one more reference for it.
	if _explosion_decal.package_id == nil then
		_explosion_decal.package_id = Managers.package:load(PACKAGE_PATH, "GauntletTrajectory")
	end
end

local function _destroy_explosion_decal()
	local decal_unit = _explosion_decal.unit

	if decal_unit then
		if Unit.alive(decal_unit) then
			local world = Unit.world(decal_unit)

			World.destroy_unit(world, decal_unit)
		end

		_explosion_decal.unit = nil
	end
end

-- Destroy the decal unit first (its resources live inside the package), then release
-- our package reference so the package manager can unload the package again. Turning
-- the circle back on later simply requests the package once more; the package manager
-- cancels pending unloads and re-queues loads on its own (PackageManager.load/release).
local function _release_decal_package()
	_destroy_explosion_decal()

	local package_id = _explosion_decal.package_id

	-- A released id is invalidated immediately by the package manager, so it must never
	-- be passed to release twice; clearing it here makes that impossible.
	if package_id and Managers and Managers.package then
		Managers.package:release(package_id)
	end

	_explosion_decal.package_id = nil
end

-- Entries beyond number_of_aim_data hold stale data from previous frames and must not be read.
-- Returns the position where the grenade will actually explode, or nil when it would detonate
-- mid-air first (fuse expired before reaching the simulated impact, e.g. long lobs) or when
-- no impact happens within the simulated trajectory (e.g. aiming at the open sky).
local function _get_landing_position(aim_data, number_of_aim_data)
	local game_session = Managers.state and Managers.state.game_session
	local fixed_time_step = game_session and game_session.fixed_time_step

	for ii = 1, number_of_aim_data do
		local data = aim_data[ii]

		if data and data.has_hit then
			-- Before the first hit, every integration iteration adds exactly one aim_data
			-- entry, so the entry index equals the iteration count at the hit. Each
			-- iteration advances the simulation by fixed_time_step * aim_time_step_multiplier.
			if _fuse_time and fixed_time_step then
				local flight_time = ii * fixed_time_step * _aim_time_step_multiplier

				if _fuse_time < flight_time then
					return nil
				end
			end

			return data.new_position
		end
	end

	return nil
end

-- Position of the ground (static geometry) directly below the given position, or nil when there is
-- none within GROUND_PROBE_DISTANCE below it.
local function _ground_below_position(self, position)
	local physics_world = self._physics_world

	if not physics_world then
		return nil
	end

	-- Cast straight down from just above the point; the statics-only filter ignores the
	-- enemy's own body (and any other dynamic unit), so the ray passes through it and
	-- reaches the surface below the point.
	local from_position = position + GROUND_PROBE_START_OFFSET:unbox()
	local hit, hit_position = PhysicsWorld.raycast(physics_world, from_position, Vector3.down(), GROUND_PROBE_DISTANCE, "closest", "types", GROUND_PROBE_TYPES, "collision_filter", GROUND_PROBE_COLLISION_FILTER)

	-- The engine guarantees hit implies a valid hit_position — the same contract the game's
	-- AOE unit spawner relies on when snapping spread positions to the ground
	-- (area_of_effect_unit_spawner_extension.lua: it uses the hit_position directly when
	-- hit is true); a nil result is handled by the caller's "no ground -> hide the circle"
	-- branch, so no extra guard is needed here.
	if hit then
		return hit_position
	end

	return nil
end

-- The living enemy of the local player that the trajectory line ends on, or nil.
-- Forward-declared here because _update_explosion_decal below is its first consumer; assigned
-- in the target-outline section, right after _get_side_system (which it depends on).
local _landing_enemy_unit

-- Explosion radius of the gauntlet grenade: manual override via settings, or computed
-- the same way the game's force staff AOE targeting does it.
local function _get_explosion_radius(self)
	local custom_radius = mod_settings.explosion_radius

	if custom_radius and custom_radius > 0 then
		return custom_radius
	end

	local owner_unit = self._owner_unit

	if owner_unit then
		local success, radius = pcall(function()
			local explosion_template = ProjectileTemplates.ogryn_gauntlet_grenade.damage.impact.explosion_template
			local lerp_values = Explosion.lerp_values(owner_unit, explosion_template.name, "action_shoot_zoomed")
			local buff_extension = ScriptUnit.has_extension(owner_unit, "buff_system")
			local stat_buffs = buff_extension and buff_extension:stat_buffs()
			local unit_data_extension = ScriptUnit.has_extension(owner_unit, "unit_data_system")
			local breed = unit_data_extension and unit_data_extension:breed()

			return Explosion.radii(explosion_template, 1, lerp_values, "explosion", stat_buffs, breed)
		end)

		if success and radius and radius > 0 then
			return radius
		end
	end

	return FALLBACK_EXPLOSION_RADIUS
end

local function _update_explosion_decal(self, aim_data, number_of_aim_data)
	local landing_position = _get_landing_position(aim_data, number_of_aim_data)

	-- No impact within the simulated trajectory (e.g. aiming at the open sky): nothing to show
	if not landing_position then
		_destroy_explosion_decal()

		return
	end

	local circle_position = landing_position

	-- The trajectory line ends on a living enemy: draw the circle on the ground directly below
	-- the actual impact point (the point on the enemy's body the line ends on) so it follows the
	-- aim position, and hide it when there is no ground within reach below that point (e.g. the
	-- point is far above a gap). Note the probe runs from the impact point of the current frame's
	-- aim data, which updates with the aim; it no longer anchors to the enemy's root position.
	local enemy_unit = _landing_enemy_unit(self, landing_position)

	if enemy_unit then
		local ground_position = _ground_below_position(self, landing_position)

		if not ground_position then
			_destroy_explosion_decal()

			return
		end

		circle_position = ground_position
	end

	local world = self._world

	if not world then
		return
	end

	-- Same defensive convention as _ensure_decal_package_loaded / _release_decal_package: a
	-- missing package manager skips the decal instead of indexing nil. Unreachable in normal
	-- gameplay (Managers.package is a boot-time singleton created in boot_state_init_managers),
	-- but keeping every package access in this file guarded uniformly makes the decal path safe
	-- against any future change to the manager lifecycle, and costs one `and` short-circuit.
	if not (Managers and Managers.package and Managers.package:has_loaded(PACKAGE_PATH)) then
		_ensure_decal_package_loaded()

		return
	end

	local decal_unit = _explosion_decal.unit

	-- Cached DMF color setting value: { a, r, g, b } table with 0-255 components
	local color = mod_settings.explosion_circle_color

	if not (decal_unit and Unit.alive(decal_unit)) then
		-- Spawn parked out of sight first (see DECAL_SPAWN_POSITION), then move and
		-- scale it into place below; the potentially stale first render therefore
		-- happens where the player cannot see it.
		decal_unit = World.spawn_unit_ex(world, DECAL_PATH, nil, DECAL_SPAWN_POSITION:unbox())
		_explosion_decal.unit = decal_unit

		-- Colour is baked into the material at spawn; RGB components in 0..1 range
		local colour = Quaternion.identity()

		Quaternion.set_xyzw(colour, color[2] / 255, color[3] / 255, color[4] / 255, 0)
		Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
	end

	Unit.set_local_position(decal_unit, 1, circle_position + Vector3(0, 0, DECAL_Z_OFFSET))
	Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", color[1] / 255)

	local diameter = _get_explosion_radius(self) * 2

	Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
end

-- True while the aim script instance belongs to the gauntlet (and only for the local
-- player; remote instances never get a weapon template set by the parent class).
local function _is_gauntlet_aim_script(self)
	local weapon_template = self._weapon_template

	return weapon_template ~= nil and weapon_template.name == GAUNTLET_TEMPLATE_NAME
end

-- Initialization: record original state and apply modifications
record_original_state()
apply_trajectory_prediction()

-- Preload the decal package so the circle is ready on the first aim.
-- DMF fires this event for disabled mods as well, so gate on the enabled state:
-- a mod disabled at startup must not hold the decal package in memory.
mod.on_all_mods_loaded = function()
	if mod:is_enabled() then
		_ensure_decal_package_loaded()
	end
end

-- Re-apply on setting change (takes effect on the next wield)
-- Explosion circle settings also reset the decal so changes apply immediately.
-- Target outline settings refresh the registered outline entry and re-add the active
-- outline, since outline entries snapshot priority/color when they are added.
local EXPLOSION_CIRCLE_SETTINGS = {
	show_explosion_radius  = true,
	explosion_radius       = true,
	explosion_circle_color = true,
}

local TARGET_OUTLINE_SETTINGS = {
	show_target_outline     = true,
	target_outline_color    = true,
	target_outline_priority = true,
}

-- The target outline state and functions are defined in the section below; forward-declare
-- the ones the lifecycle handlers here reference, since Lua locals must be in scope where
-- the referencing closure is created.
local _update_outline_settings, _add_target_outline, _remove_target_outline, _outlined_unit

mod.on_setting_changed = function(setting_id)
	-- Refresh the cached value of the changed setting (like BetterEnemyTag/AutoMark).
	-- Note: this event also fires while the mod is disabled — DMF does not gate it on
	-- the enabled state, and its options view lets users change settings (and "reset
	-- to defaults", which routes every changed setting through widget on_activated →
	-- mod:set(..., true)) of disabled mods — so the cache stays in sync either way.
	if mod_settings[setting_id] ~= nil then
		mod_settings[setting_id] = mod:get(setting_id)
	end

	-- The registered outline entry (priority/color) is plain data and safe to refresh
	-- while the mod is disabled; adding/removing outlines on units is not.
	if TARGET_OUTLINE_SETTINGS[setting_id] then
		_update_outline_settings()
	end

	-- Re-applying the trajectory prediction while the mod is disabled would re-inject
	-- it into the shared weapon template (vanilla arc showing with the mod "off"), and
	-- toggling the circle on would load the decal package. When the mod is re-enabled,
	-- on_enabled restores both from the refreshed settings.
	if not mod:is_enabled() then
		return
	end

	apply_trajectory_prediction()

	if EXPLOSION_CIRCLE_SETTINGS[setting_id] then
		if setting_id == "show_explosion_radius" then
			-- Circle just turned on: start loading the decal package right away
			-- (also covered lazily by _update_explosion_decal while aiming).
			if mod_settings.show_explosion_radius then
				_ensure_decal_package_loaded()
			-- Circle turned off: destroy the decal and release the package reference,
			-- so the package no longer stays resident in memory.
			else
				_release_decal_package()
			end
		else
			-- Radius/color change: color is baked into the decal material at spawn, so
			-- the unit is destroyed here and respawned on the next aim update.
			_destroy_explosion_decal()
		end
	end

	if TARGET_OUTLINE_SETTINGS[setting_id] then
		if setting_id == "show_target_outline" then
			-- Outline turned off: remove it from the currently highlighted enemy.
			if not mod_settings.show_target_outline then
				_remove_target_outline()
			end
		elseif _outlined_unit then
			-- Color/priority change: re-add the active outline so it re-snapshots
			-- the new values from the refreshed outline settings.
			local unit = _outlined_unit

			_remove_target_outline()
			_add_target_outline(unit)
		end
	end
end

-- Re-apply when the mod is enabled
mod.on_enabled = function()
	apply_trajectory_prediction()
	_ensure_decal_package_loaded()
end

-- Restore when the mod is disabled
mod.on_disabled = function()
	revert_trajectory_prediction()
	_release_decal_package()
	_remove_target_outline()
end

-- Restore when the mod is unloaded
mod.on_unload = function()
	revert_trajectory_prediction()
	_release_decal_package()
	_remove_target_outline()
end

-- The decal's world is torn down on game state change (leaving a level);
-- destroy it before the world it lives in becomes invalid. (The hook is registered
-- at the end of the target outline section below, which shares this cleanup.)

-- #####################################################################################################################
-- # Target enemy outline                                                                                              #
-- #####################################################################################################################
-- While the trajectory arc is visible and the simulated trajectory line ends on a living enemy, that
-- enemy is highlighted with an outline whose color is configurable in the mod settings.
-- Detection: the grenade explodes on its first impact, so the arc is always built with
-- stop_on_impact enabled and the aim trajectory simulation stops integrating at the first
-- hit; because it also stops on living units (aim_projectile_effects.lua: "hit_minion" break),
-- the integration data's last_hit_unit at the end of the simulation is exactly the unit the
-- drawn line ends on — walls and statics either carry no unit or no health. The same fuse
-- rule as the explosion circle applies: if the grenade would detonate mid-air before
-- reaching its first impact, nothing is highlighted. This detection is shared with the
-- explosion circle (see _landing_enemy_unit), so the circle's ground projection and the
-- outline always agree on whether the trajectory ends on an enemy.
-- Compatibility: the outline is managed through the game's own OutlineSystem under a custom outline
-- name registered in outline_settings — the same mechanism used by the vanilla smart-tag outlines and
-- by outline mods (AlwaysOutline, enemies_improved). Outline entries stack per unit and the system
-- displays the one with the lowest priority number, so vanilla tags and other outline mods keep
-- working; our entry is removed again the moment the trajectory stops pointing at the enemy, which
-- makes the previously displayed outline (if any) re-appear automatically.

local OUTLINE_NAME = "gauntlet_trajectory_target"
local OUTLINE_MATERIAL_LAYERS = {
	"minion_outline",
}

local _outline_settings_instance = nil

-- System lookups are cached per game state (systems are recreated on state change);
-- failed lookups stay unchecked so they are retried until the systems exist.
local _outline_system = nil
local _outline_system_checked = false
local _side_system = nil
local _side_system_checked = false

local function _get_outline_system()
	if not _outline_system_checked then
		local extension_manager = Managers.state and Managers.state.extension

		if extension_manager and extension_manager:has_system("outline_system") then
			_outline_system = extension_manager:system("outline_system")
			_outline_system_checked = true
		end
	end

	return _outline_system
end

local function _get_side_system()
	if not _side_system_checked then
		local extension_manager = Managers.state and Managers.state.extension

		if extension_manager and extension_manager:has_system("side_system") then
			_side_system = extension_manager:system("side_system")
			_side_system_checked = true
		end
	end

	return _side_system
end

-- The living enemy of the local player that the trajectory line ends on, or nil. Consumed by both
-- the target outline and the explosion circle's ground projection, so both react to exactly the same
-- trajectory: the grenade explodes on its first impact and the aim trajectory simulation stops
-- integrating there (it also stops on living units — see aim_projectile_effects.lua), so
-- last_hit_unit at that point is exactly the unit the drawn line ends on — walls and statics carry
-- either no unit or no health. (Forward-declared in the explosion-circle section; assigned here
-- because it depends on _get_side_system.)
_landing_enemy_unit = function(self, landing_position)
	if not landing_position then
		return nil
	end

	local integration_data = self._integration_data
	local hit_unit = integration_data and integration_data.last_hit_unit

	if not (hit_unit and HEALTH_ALIVE[hit_unit]) then
		return nil
	end

	local owner_unit = self._owner_unit
	local side_system = _get_side_system()

	if owner_unit and side_system and side_system:is_enemy(owner_unit, hit_unit) then
		return hit_unit
	end

	return nil
end

local function _clear_cached_systems()
	_outline_system = nil
	_outline_system_checked = false
	_side_system = nil
	_side_system_checked = false
end

local function _outline_visibility_check(unit)
	if not HEALTH_ALIVE[unit] then
		return false
	end

	return true
end

-- DMF color settings are { a, r, g, b } tables with 0-255 components; outline materials take an
-- RGB vector with 0-1 components (the outline_color material variable has no alpha channel).
local function _get_outline_color_rgb()
	local color = mod_settings.target_outline_color

	return {
		color[2] / 255,
		color[3] / 255,
		color[4] / 255,
	}
end

local function _apply_outline_color(unit, color)
	if unit and color then
		-- include_children must be false (see AlwaysOutline): a specialist grabbing a player
		-- links the player unit as a child, and player outline materials share the variable name.
		Unit.set_vector3_for_materials(unit, "outline_color", Vector3(color[1], color[2], color[3]), false)
	end
end

-- (Re-)registers our outline entry in the game's outline settings. Outline entries snapshot
-- priority/color when added (OutlineSystem.add_outline), so setting changes go through here
-- and active outlines are re-added to pick up the new values.
-- (Forward-declared above; assigned here because the registration depends on the helpers below.)
_update_outline_settings = function()
	local minion_settings = _outline_settings_instance and _outline_settings_instance.MinionOutlineExtension

	if not minion_settings then
		return
	end

	minion_settings[OUTLINE_NAME] = {
		priority         = mod_settings.target_outline_priority,
		material_layers  = OUTLINE_MATERIAL_LAYERS,
		color            = _get_outline_color_rgb(),
		visibility_check = _outline_visibility_check,
	}
end

_remove_target_outline = function()
	local unit = _outlined_unit

	_outlined_unit = nil

	if unit then
		local outline_system = _get_outline_system()

		-- remove_outline is a no-op when the unit no longer has extension data or the outline
		-- is not present, so no extra guards are needed here.
		if outline_system then
			outline_system:remove_outline(unit, OUTLINE_NAME)
		end
	end
end

_add_target_outline = function(unit)
	local outline_system = _get_outline_system()

	if not outline_system then
		return
	end

	local extension = outline_system._unit_extension_data[unit]

	-- Enemies without the outline extension (or before our outline name got registered by the
	-- hook_require below) cannot take the outline; skip instead of spamming the game log.
	if not (extension and extension.settings[OUTLINE_NAME]) then
		return
	end

	_outlined_unit = unit

	outline_system:add_outline(unit, OUTLINE_NAME)

	-- The system only bakes the outline color into the materials for breeds that have an
	-- outline_config; write it unconditionally like AlwaysOutline does, so the color is
	-- guaranteed on the first frame for every enemy.
	_apply_outline_color(unit, _get_outline_color_rgb())

	-- If our entry is not the displayed (top) outline, add_outline has just re-colored the
	-- materials with our color while another outline is still being displayed; restore the
	-- displayed outline's own color so it keeps it until it is re-shown by the system.
	local top_outline = extension.outlines[1]

	if top_outline and top_outline.name ~= OUTLINE_NAME then
		_apply_outline_color(unit, top_outline.color)
	end
end

local function _update_target_outline(self, aim_data, number_of_aim_data)
	-- Same validity rule as the explosion radius circle: a trajectory whose grenade would
	-- detonate mid-air (fuse expired before the first impact) highlights nothing.
	local landing_position = _get_landing_position(aim_data, number_of_aim_data)
	local target_unit = landing_position and _landing_enemy_unit(self, landing_position)

	if target_unit and target_unit == _outlined_unit then
		-- Cheap liveness check: an external remove_all_outlines (e.g. the server's death RPC)
		-- could have wiped our outline while the target stayed the same.
		local outline_system = _get_outline_system()
		local extension = outline_system and outline_system._unit_extension_data[target_unit]

		if extension and outline_system:has_outline(target_unit, OUTLINE_NAME) then
			-- Re-assert the displayed (top) outline's color every frame. add_outline
			-- writes the newly-added outline's color onto the shared "minion_outline"
			-- material unconditionally (gated only by extension.outline_config), while the
			-- system itself only re-syncs color on a hidden->shown transition — which
			-- continuous aiming never triggers. So another mod (or the vanilla smart-tag
			-- event) adding a same-priority outline to the enemy we are still aiming at
			-- would otherwise leave our (still-displayed) outline showing that other
			-- outline's color until the aim moves off. Mirrors AlwaysOutline's per-tick
			-- set_outline_color self-heal, but scoped to the actively-aimed target.
			local top_outline = extension.outlines[1]

			if top_outline then
				_apply_outline_color(target_unit, top_outline.color)
			end

			return
		end
	end

	_remove_target_outline()

	if target_unit then
		_add_target_outline(target_unit)
	end
end

-- Runs the callback for every past and future instance of the game's outline settings, adding
-- our custom outline name to the minion outline extension's entries (same approach as the
-- AlwaysOutline and enemies_improved mods).
mod:hook_require("scripts/settings/outline/outline_settings", function(instance)
	_outline_settings_instance = instance
	_update_outline_settings()
end)

-- The decal's world and the outline/side systems are torn down on game state change (leaving a
-- level); drop our decal, outline and cached system references before the old state becomes invalid.
mod:hook_safe("UIManager", "cb_on_game_state_change", function()
	_destroy_explosion_decal()
	_remove_target_outline()
	_clear_cached_systems()
end)

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
	if crosshair_type ~= "none" and mod_settings.hide_crosshair_during_ads then
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

-- Fix: with stop_on_impact always enabled, a close-target hit leaves only 2 aim_data entries,
-- failing the renderer's "> 1" check. Pad to 3; aim_data[3] is never read when
-- aim_data[1].has_hit. Hook the child class because class() copies parent methods.
-- Also keeps the explosion radius circle and the target enemy outline in sync with
-- the current trajectory while the gauntlet's trajectory arc is visible.

mod:hook(AimProjectileAdsEffects, "_set_trajectory_positions_spline", function(func, self, aim_data, number_of_aim_data, arc_offset, total_distance, arc_distances, dt)
	if number_of_aim_data == 2 and aim_data[1] and aim_data[1].has_hit then
		number_of_aim_data = 3
	end

	if _is_gauntlet_aim_script(self) then
		if mod_settings.show_explosion_radius then
			_update_explosion_decal(self, aim_data, number_of_aim_data)
		end

		if mod_settings.show_target_outline then
			_update_target_outline(self, aim_data, number_of_aim_data)
		end
	end

	return func(self, aim_data, number_of_aim_data, arc_offset, total_distance, arc_distances, dt)
end)

-- Hide the explosion circle and the target outline whenever the trajectory arc stops (aim
-- released, out of ammo, unwield, slot script destroyed, ...). Gauntlet only.
mod:hook(AimProjectileAdsEffects, "_stop_trajectory_spline", function(func, self)
	if _is_gauntlet_aim_script(self) then
		_destroy_explosion_decal()
		_remove_target_outline()
	end

	return func(self)
end)

-- #####################################################################################################################
-- # Continuous aiming: keep the trajectory while the right mouse button is held                                       #
-- #####################################################################################################################
-- The gauntlet's shoot action (action_shoot_zoomed) sets hide_arc = true, so the game destroys the trajectory spline
-- the moment the grenade is launched. When the player keeps the right mouse button held this leaves a blank spot
-- between two shots that makes continuous aimed fire harder to line up.
-- Here we keep the spline (and, via the _set_trajectory_positions_spline hook above, the explosion circle) alive for
-- as long as the player keeps aiming: the game's own _trajectory_settings is re-run with the current action's hide_arc
-- flag temporarily cleared, so the built-in trajectory simulation keeps projecting a hypothetical trajectory from the
-- configured arc start position every frame.
-- Because the shoot action is uninterruptible, the game's alternate-fire is_active flag lingers for up to ~0.6s after
-- the aim button was already released, so the raw input state is also checked: releasing the button hides the kept
-- arc/circle the very same frame, even in the middle of the fire animation. Releasing also stops ADS, which makes the
-- game report no trajectory and destroy the spline/circle as usual.

-- True while the player is still engaged with the aim input: the aim button ("action_two",
-- right mouse button by default) is physically held, or — with the toggle_ads option enabled —
-- aiming is toggled on (the raw hold signal is meaningless for toggle users).
local function _is_aim_input_engaged()
	if Managers and Managers.input then
		local input_service = Managers.input:get_input_service("Ingame")

		if input_service and input_service:get("action_two_hold") then
			return true
		end
	end

	if Managers and Managers.save and Managers.save.account_data then
		local account_data = Managers.save:account_data()
		local input_settings = account_data and account_data.input_settings

		if input_settings and input_settings.toggle_ads then
			return true
		end
	end

	return false
end

-- Should the trajectory be kept alive even though the game wants to hide it?
local function _should_keep_arc_while_aiming(self)
	if not mod_settings.keep_arc_while_aiming then
		return false
	end

	if not _is_gauntlet_aim_script(self) then
		return false
	end

	-- Only while the player is actually still aiming down sights (right button held)
	local alternate_fire_component = self._alternate_fire_component

	if not (alternate_fire_component and alternate_fire_component.is_active) then
		return false
	end

	-- ... and only while the aim button is still engaged (held, or ADS toggled on)
	if not _is_aim_input_engaged() then
		return false
	end

	-- Respect the game's own aim-trajectory setting
	if not self._aim_trajectory_enabled then
		return false
	end

	-- Same ammo rule as the game: hide only when clip and reserve are both empty
	local inventory_slot_component = self._inventory_slot_component

	if inventory_slot_component then
		local no_ammo_in_clip = Ammo.current_ammo_in_clips(inventory_slot_component) == 0
		local no_ammo_in_reserve = inventory_slot_component.current_ammunition_reserve == 0

		if no_ammo_in_clip and no_ammo_in_reserve then
			return false
		end
	end

	return true
end

-- Hooked on the child class: class() copies parent methods, so hooking the parent
-- AimProjectileEffects would not affect AimProjectileAdsEffects instances.
mod:hook(AimProjectileAdsEffects, "_trajectory_settings", function(func, self, t)
	local draw_trajectory, trajectory_settings = func(self, t)

	if draw_trajectory then
		return true, trajectory_settings
	end

	if not _should_keep_arc_while_aiming(self) then
		return false, nil
	end

	-- The game hid the arc because the current action (the shoot action between two
	-- shots) sets hide_arc. Temporarily clear it and re-run the settings builder so a
	-- hypothetical trajectory from the player-configured arc start position is returned.
	local weapon_action_component = self._weapon_action_component
	local action_settings = weapon_action_component
		and Action.current_action_settings_from_component(weapon_action_component, self._weapon_actions)

	if not (action_settings and action_settings.hide_arc) then
		return false, nil
	end

	-- hide_arc is only read by this very function (synchronous, see game source), so the
	-- transient mutation is invisible everywhere else. Restore it even on error so the
	-- shared weapon template can never be left in a modified state.
	local original_hide_arc = action_settings.hide_arc

	action_settings.hide_arc = nil

	local ran_ok, draw_kept_trajectory, kept_trajectory_settings = pcall(func, self, t)

	action_settings.hide_arc = original_hide_arc

	if not ran_ok then
		-- Re-raise with the original message; the game handles Lua errors via Crashify
		-- (exceptions treated as warnings), same as it would for an un-hooked call.
		error(draw_kept_trajectory, 0)
	end

	if draw_kept_trajectory then
		return true, kept_trajectory_settings
	end

	return false, nil
end)
