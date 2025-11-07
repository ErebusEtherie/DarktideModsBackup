local mod = get_mod("LessAnnoyingArbites")
local FixedFrame = require("scripts/utilities/fixed_frame")

local OutlineSettings = require("scripts/settings/outline/outline_settings")

local VFX_INDICATOR = "content/fx/particles/weapons/grenades/area_buff_drone/area_buff_drone_radius_indicator"
local VFX_SCANNING = "content/fx/particles/weapons/grenades/area_buff_drone/buff_drone_scanning"
local SCREENSPACE_SCALE = 0.1
local DRONE_UNIT_NAME = "content/weapons/player/ranged/drone_area_buff/wpn_drone_area_buff"

local BuffSettings = require("scripts/settings/buff/buff_settings")
local buff_keywords = BuffSettings.keywords
local MINE_VFX = "content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_no_target"
local DOUBLE_TAP_DELAY = 0.3
--local VFX = "content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_01"

--local VFX = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_01"

local print_no_log = CommandWindow.print
local enable_debug_mode = mod:get("setting_enable_debug_mode") or false
local setting_enable_attack = true
local setting_enable_dog_outline = true
local setting_enable_dog_others_outline = true
local setting_enable_outline_colors = true
local setting_nuncio_offset = 2.5
local setting_impact_maul_special = "" --local vars to avoid table lookup in freq called hooked funcs, prob unneeded
local setting_impact_shield_special = ""
local setting_impact_shock = ""
local setting_enable_screenspace_vfx = true
local setting_enable_mine_vfx = false
local setting_replace_mine_vfx = false
local setting_nuncio_override = false
local setting_nuncio_visible = true
local setting_nuncio_enable_scan_vfx = false
local setting_enable_tag_double_tap = true
local setting_tag_double_tap_delay = 0.3
local setting_enable_impact_vfx = false

local function print_debug(...)
	if enable_debug_mode then
		print_no_log("[LessAnnoyingArbites]: ", os.date("%X"), ...)
	end
end
local function print_stack_trace()
	if enable_debug_mode then
		print("[LessAnnoyingArbites]", os.date("%X"), debug.traceback())
	end
end
local function get_smart_tag_hud()
	local hud = Managers.ui:get_hud()
	return hud and hud:element("HudElementSmartTagging")
end
local function load_resource(package_name, callback)
	local load_id = 0
	if package_name ~= nil and Application.can_get_resource("package", package_name) then
		local ref_count = Managers.package:reference_count(package_name)
		if ref_count >= 1 then
			print_debug(" SKIP load_resource package_name,ALREADY LOADED has  ref_count", package_name, ref_count)
			return
		end
		print_debug("load_resource package_name, ref_count", package_name, ref_count)

		load_id = Managers.package:load(package_name, "LessAnnoyingArbites", function()
			if callback then
				callback(package_name)
			end
		end)
	else
		if callback then
			callback(package_name)
		end
	end
	return load_id
end
local function release_resource(load_id)
	Managers.package:release(load_id)
end

local function rgb_to_mat(r, g, b)
	return { r / 255, g / 255, b / 255 }
end
local function set_color(outline, color)
	outline.color = rgb_to_mat(color[2], color[3], color[4])
end
local function set_mat_color(outline, color)
	outline.color = { color[1], color[2], color[3] }
end
local function restart_dog(player)
	local local_player = Managers.player:local_player(1)
	local is_local_player = local_player == player
	local outline_name = is_local_player and "owned_companion" or "allied_companion"
	local player_unit = player.player_unit
	if player_unit then
		local companion_spawner_extension = ScriptUnit.extension(player_unit, "companion_spawner_system")
		local companion_unit = companion_spawner_extension:companion_unit()
		if companion_unit then
			local outline_system = ScriptUnit.extension(companion_unit, "outline_system")
			if outline_system then
				--outline_system:remove_outline(companion_unit, outline_name)
				--outline_system:add_outline(companion_unit, outline_name)
				print_debug(" _stop_outline() for dog", player:name(), outline_name)

				outline_system:_stop_outline()
				--outline_system:_start_outline()
				if
					(is_local_player and setting_enable_dog_outline)
					or (not is_local_player and setting_enable_dog_others_outline)
				then
					print_debug(" _start_outline() for dog", player:name(), outline_name)
					outline_system:_start_outline()
				end
			end
		end
	end
end
local function restart_your_dog_color()
	local local_player = Managers.player:local_player(1)
	restart_dog(local_player)
end

local function refresh_dogs()
	print_debug("refresh_dogs() called")
	local player_manager = Managers.player

	--local local_player = player_manager:local_player(1)
	local human_players = player_manager:human_players()
	for unique_id, player in pairs(human_players) do
		--if player ~= local_player then
		restart_dog(player)
		--end
	end
end
local function refresh_outlines()
	if setting_enable_outline_colors then
		local dog_target_outline_color = Color[mod:get("setting_dog_target_outline_color")](255, true)
		local adamant_mark_outline_color = Color[mod:get("setting_adamant_mark_outline_color")](255, true)
		local dog_outline_color = Color[mod:get("setting_dog_outline_color")](255, true)
		local dog_other_outline_color = Color[mod:get("setting_dog_other_outline_color")](255, true)
		local horde_remaining_outline_color = Color[mod:get("setting_horde_remaining_outline_color")](255, true)
		set_color(OutlineSettings.MinionOutlineExtension.adamant_smart_tag, dog_target_outline_color)
		set_color(OutlineSettings.MinionOutlineExtension.adamant_mark_target, adamant_mark_outline_color)
		set_color(OutlineSettings.CompanionOutlineExtension.owned_companion, dog_outline_color)
		set_color(OutlineSettings.CompanionOutlineExtension.allied_companion, dog_other_outline_color)
		set_color(OutlineSettings.MinionOutlineExtension.hordes_tagged_remaining_target, horde_remaining_outline_color)
	else
		set_mat_color(OutlineSettings.MinionOutlineExtension.adamant_smart_tag, { 1, 0.25, 0.25 })
		set_mat_color(OutlineSettings.MinionOutlineExtension.adamant_mark_target, { 0.5, 0.4, 1 })
		set_mat_color(OutlineSettings.CompanionOutlineExtension.owned_companion, { 0, 0.4, 0.1 })
		set_mat_color(OutlineSettings.CompanionOutlineExtension.allied_companion, { 0.7, 1, 0.8 })
		set_mat_color(OutlineSettings.MinionOutlineExtension.hordes_tagged_remaining_target, { 0, 0.73, 1 })
	end
	print_debug("Settings updated")
	--Managers.event:trigger("event_update_companion_outlines", "both")
	refresh_dogs()
end

local function refresh_vfx()
	if setting_impact_maul_special ~= "" then
		mod.setting_impact_maul_special_loaded_package_id = load_resource(
			setting_impact_maul_special,
			function(loaded_package_name)
				print_debug("LessAnnoyingArbites load_resource: VFX", loaded_package_name)
			end
		)
	end
	if setting_impact_shield_special ~= "" then
		mod.setting_impact_shield_special_loaded_package_id = load_resource(
			setting_impact_shield_special,
			function(loaded_package_name)
				print_debug("LessAnnoyingArbites load_resource: VFX", loaded_package_name)
			end
		)
	end
	if setting_impact_shock ~= "" then
		mod.setting_impact_shock_loaded_package_id = load_resource(setting_impact_shock, function(loaded_package_name)
			print_debug("LessAnnoyingArbites load_resource: VFX", loaded_package_name)
		end)
	end
end

mod.get_settings = function()
	enable_debug_mode = mod:get("setting_enable_debug_mode")
	setting_enable_attack = mod:get("setting_enable_attack")
	setting_enable_outline_colors = mod:get("setting_enable_outline_colors")
	setting_enable_dog_outline = mod:get("setting_enable_dog_outline")
	setting_enable_dog_others_outline = mod:get("setting_enable_dog_others_outline")

	refresh_outlines()

	setting_enable_impact_vfx = mod:get("setting_enable_impact_vfx")
	setting_impact_maul_special = mod:get("setting_impact_maul_special")
	setting_impact_shield_special = mod:get("setting_impact_shield_special")
	setting_impact_shock = mod:get("setting_impact_shock")
	setting_enable_screenspace_vfx = mod:get("setting_enable_screenspace_vfx")
	setting_enable_mine_vfx = mod:get("setting_enable_mine_vfx")
	setting_replace_mine_vfx = mod:get("setting_replace_mine_vfx")
	setting_nuncio_override = mod:get("setting_nuncio_override")
	setting_nuncio_offset = tonumber(mod:get("setting_nuncio_offset")) or 2

	setting_nuncio_visible = mod:get("setting_nuncio_visible")
	setting_nuncio_enable_scan_vfx = mod:get("setting_nuncio_enable_scan_vfx")

	setting_enable_tag_double_tap = mod:get("setting_enable_tag_double_tap")
	setting_tag_double_tap_delay = tonumber(mod:get("setting_tag_double_tap_delay")) or 0.3

	refresh_vfx()
end

mod.on_setting_changed = function()
	mod.get_settings()
end
mod.get_settings()

--********** Mines **********
if setting_replace_mine_vfx then
	mod.mine_vfx_loaded_package_id = load_resource(MINE_VFX, function(loaded_package_name)
		print_debug("LessAnnoyingArbites setting_replace_mine_vfx load_resource: VFX", loaded_package_name)
	end)

	local TARGET_NODE_NAME = "enemy_aim_target_02"
	local PARTICLE_VARIABLE_NAME = "length"
	local CENTER_NODE_NAME = "fx_center"

	local function is_minion_alive(unit)
		if not HEALTH_ALIVE[unit] then
			return false
		end

		return true
	end
	local HARD_CODED_RADIUS = 3
	local HARD_CODED_COOLDOWN = 1.75
	local DESTROY_ALL_COOLDOWN = 3

	local _broadphase_results = {}
	local target_loop = {
		start = "wwise/events/weapon/play_adamant_shockmine_electric_loop",
		stop = "wwise/events/weapon/stop_adamant_shockmine_electric_loop",
	}

	mod:hook_require("scripts/components/shock_mine", function(ShockMine)
		--print_debug("LessAnnoyingArbites: ShockMine component loaded")
		ShockMine.DestroyAllParticles = function(self)
			--print_debug("LessAnnoyingArbites: DestroyAllParticles called")
			local world = self._world

			for unit_object_id, particle_id in pairs(self._particle_id_list) do
				if particle_id and World.are_particles_playing(world, particle_id) then
					--print_debug("LessAnnoyingArbites: Destroying particle for unit", unit_object_id, particle_id)
					World.destroy_particles(world, particle_id)
				end
			end
			self._particle_id_list = {}
		end
		mod:hook_origin(ShockMine, "_update_target_effects", function(self, dt, t)
			--print_debug("LessAnnoyingArbites: ShockMine _update_target_effects called")
			local world = self._world
			local wwise_world = self._wwise_world
			local unit = self._unit
			local enemy_side_names = self._enemy_side_names
			local broadphase = self._broadphase
			local cooldowns = self._cooldowns

			table.clear(_broadphase_results)

			local num_results = broadphase.query(
				broadphase,
				POSITION_LOOKUP[unit],
				HARD_CODED_RADIUS,
				_broadphase_results,
				enemy_side_names
			)
			local elasped_time = t - self._last_destroy_time
			if elasped_time > DESTROY_ALL_COOLDOWN then
				self:DestroyAllParticles()
				self._last_destroy_time = t
			end
			for ii = 1, num_results do
				local target_unit = _broadphase_results[ii]

				if HEALTH_ALIVE[target_unit] and not cooldowns[target_unit] then
					local buff_extension = ScriptUnit.has_extension(target_unit, "buff_system")

					if buff_extension then
						local target_is_electrocuted = buff_extension:has_keyword(buff_keywords.electrocuted)

						if target_is_electrocuted then
							--print_debug("LessAnnoyingArbites: ShockMine _update_target_effects calling _play_target_vfx")
							self:_play_target_vfx(world, unit, target_unit)
							self:_play_target_sfx(wwise_world, target_unit)

							cooldowns[target_unit] = HARD_CODED_COOLDOWN
						end
					end
				end
			end

			local source_id = self._source_id
			local targets_loop_playing_id = self._targets_loop_playing_id

			if num_results > 0 and not targets_loop_playing_id then
				local playing_id = self:_start_looping_sound(source_id, target_loop.start)

				self._targets_loop_playing_id = playing_id

				self:_update_targets_sfx_loop(source_id, num_results)
			elseif num_results <= 0 and targets_loop_playing_id then
				self:_stop_looping_sound(source_id, targets_loop_playing_id, target_loop.stop)

				self._targets_loop_playing_id = nil
			elseif num_results > 0 and targets_loop_playing_id then
				self:_update_targets_sfx_loop(source_id, num_results)
			end
		end)

		mod:hook_origin(ShockMine, "_play_target_vfx", function(self, world, unit, target_unit)
			local effect_name = MINE_VFX
			local unit_object_id = Managers.state.unit_spawner:game_object_id(target_unit)
			local old_particle_id = self._particle_id_list[unit_object_id]

			if old_particle_id and World.are_particles_playing(world, old_particle_id) then
				--print_debug("LessAnnoyingArbites: Destroying particle for unit", unit_object_id, old_particle_id)
				World.destroy_particles(world, old_particle_id)
			end

			local particle_id = World.create_particles(world, effect_name, Vector3.zero())
			self._particle_id_list[unit_object_id] = particle_id
			--print_debug("LessAnnoyingArbites: Create particle for unit", unit_object_id, particle_id)
			--		self._particle_id = particle_id
			local source_pos = Unit.world_position(unit, Unit.node(unit, CENTER_NODE_NAME))
			local target_pos = Unit.world_position(target_unit, Unit.node(target_unit, TARGET_NODE_NAME))
			local line = target_pos - source_pos
			local direction, length = Vector3.direction_length(line)
			local rotation = Quaternion.look(direction)
			local particle_length = Vector3(length, length, length)
			local length_variable_index = World.find_particles_variable(world, effect_name, PARTICLE_VARIABLE_NAME)

			World.set_particles_variable(world, particle_id, length_variable_index, particle_length)
			World.move_particles(world, particle_id, source_pos, rotation)
		end)

		mod:hook_safe(ShockMine, "init", function(self, unit)
			self._particle_id_list = {}
			self._last_destroy_time = 0
		end)

		mod:hook_safe(ShockMine, "destroy", function(self, unit)
			self:DestroyAllParticles()
			self._particle_id_list = nil
		end)
	end)
end
--********** Nuncio **********

mod:hook_require("scripts/components/area_buff_drone", function(AreaBuffDrone)
	mod:hook_safe(AreaBuffDrone, "_set_active", function(self)
		local unit = self._unit
		print_debug("LessAnnoyingNuncio _set_active", unit, Unit.world_position(unit, 1))
	end)
	mod:hook_safe(AreaBuffDrone, "_deploy", function(self)
		local unit = self._unit
		print_debug("LessAnnoyingNuncio _deploy", unit, Unit.world_position(unit, 1))
		Unit.set_unit_visibility(unit, setting_nuncio_visible)
	end)
end)

mod:hook_require("scripts/components/gyroscope_particle_effect", function(GyroscopeParticleEffect)
	print_debug("HOOK  gyroscope_particle_effect")

	if not setting_nuncio_enable_scan_vfx then
		mod:hook_origin(GyroscopeParticleEffect, "_create_particle", function(self)
			local world_position = Unit.world_position(self._unit, 1)
			print_debug("GyroscopeParticleEffect _create_particle", self._particle_name, world_position)

			if self._particle_name == VFX_SCANNING then
				if not setting_nuncio_enable_scan_vfx then
					--self._particle_id = nil

					return
				end
				--todo other stuff here
				--Vector3.set_z(world_position, Vector3.z(world_position) + setting_nuncio_offset)
				--Unit.set_local_position(self._unit, 1, world_position)
			end
			self._particle_id =
				World.create_particles(self._world, self._particle_name, world_position, Quaternion.identity())
		end)
	end
	if setting_nuncio_override then
		mod:hook_origin(GyroscopeParticleEffect, "update", function(self, unit, dt, t)
			local world = self._world
			local particle_id = self._particle_id

			if particle_id then
				local alive = World.are_particles_playing(world, particle_id)

				if alive then
					local world_position = Unit.world_position(unit, 1)

					if self._particle_name == VFX_INDICATOR then
						if self._last_world_position ~= nil and not self._nuncio_stopped_moving then
							local last_world_position = Vector3Box.unbox(self._last_world_position)
							if last_world_position and Vector3.equal(last_world_position, world_position) then
								print_debug("Nuncio STOPPED MOVING and moved to (3)", world_position)
								--print_debug(debug.traceback())
								self._nuncio_stopped_moving = true
								self._final_world_position = Vector3Box(world_position)
							end
						end

						if self._nuncio_stopped_moving and self._final_world_position then
							local final_world_position = Vector3Box.unbox(self._final_world_position)
							Vector3.set_z(final_world_position, Vector3.z(final_world_position) + setting_nuncio_offset) --set z each loop to get a real time preview in world
							Unit.set_local_position(self._unit, 1, final_world_position)
							Vector3.set_z(world_position, Vector3.z(world_position) - setting_nuncio_offset)
						else
							self._last_world_position = Vector3Box(world_position)
						end
					end
					World.move_particles(world, particle_id, world_position, Quaternion.identity())

					return true
				end
			end

			self._particle_id = nil

			return true
		end)
	end
end)

--********** Dog **********
if setting_enable_attack then
	mod:hook_safe(CLASS.HudElementSmartTagging, "init", function(self, parent, draw_layer, start_scale)
		print_debug("HudElementSmartTagging.init")
		--mod.parent = parent --player
		mod.smart_tag_hud = self --cache it on init rather than fetchign every time
	end)
	mod:hook_safe(CLASS.HudElementSmartTagging, "_handle_selected_unit", function(self, target_unit)
		mod.target_unit = target_unit --capture the tagged unit here
		-- print_debug("_handle_selected_unit")
		-- local outline_system = ScriptUnit.extension(target_unit, "outline_system")
		-- print_debug(table.tostring(outline_system))
		-- local has_smart_tag = outline_system:has_outline(target_unit, "smart_tagged_enemy")
		-- print_debug("has_smart_tag", has_smart_tag)
	end)

	mod:hook_origin(CLASS.HudElementSmartTagging, "_on_tag_start", function(self, t)
		local tag_context = self._tag_context

		tag_context.enemy_tagged = false
		tag_context.marker_handled = false
		tag_context.input_start_time = t
		print_debug("_on_tag_start", t)
		--print_stack_trace()
		if setting_enable_tag_double_tap then
			tag_context.is_double_tap = tag_context.input_stop_time
				and t - tag_context.input_stop_time <= setting_tag_double_tap_delay
			if tag_context.is_double_tap then
				print_debug("Double Tap", t - tag_context.input_stop_time)
				--print_stack_trace()
			end
		else
			print_debug("DISABLED Ping Double Tap")
			tag_context.is_double_tap = false
		end
	end)

	--[[ 	mod:hook_origin(CLASS.SmartTagSystem, "set_contextual_unit_tag", function(self, tagger_unit, target_unit, alternate)
		local target_extension = self._unit_extension_data[target_unit]
		local template = target_extension:contextual_tag_template(tagger_unit, alternate)
		if template then
			if template.name ~= "enemy_companion_target" then
				local local_player = Managers.player:local_player(1) --todo: cache maybe, meh not called every split second
				local local_player_unit = local_player.player_unit
				if local_player_unit == tagger_unit then --local player tagged a unit, this will be our dog target
					mod.target_unit = target_unit
					mod.tagger_unit = tagger_unit
					mod.smart_tag_system = self
				end
				--self:set_tag(template.name, tagger_unit, target_unit, nil)
			else --supress the double-tap dog attack tag set
				--				print_debug("set_contextual_unit_tag SKIPPING double-tap dog attack", template.name)
			end
			self:set_tag(template.name, tagger_unit, target_unit, nil)
		end
	end) ]]
	mod.dog_attack = function()
		local smart_tag = mod.smart_tag_hud
		if smart_tag == nil then
			return
		end

		local target_unit = mod.target_unit --use the cached unit as our target
		local tag_context = smart_tag._tag_context
		print_debug("dog_attack", target_unit, tag_context.enemy_tagged, HEALTH_ALIVE[target_unit])
		--and tag_context.enemy_tagged
		if target_unit and HEALTH_ALIVE[target_unit] then
			local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
			if unit_data_extension then
				print_debug("dog_attack ordered")
				smart_tag:_trigger_smart_tag_unit_contextual(target_unit, "companion_order")
			end
		end
	end
	mod.dog_attack_single_press = function()
		print_debug("dog_attack_single_press")
		--local smart_tag = get_smart_tag_hud()
		local smart_tag = mod.smart_tag_hud
		if smart_tag == nil then
			return
		end
		local parent = smart_tag._parent
		local target_marker, target_unit, target_position =
			smart_tag:_find_best_smart_tag_interaction(parent._ui_renderer, parent._render_settings, true) --raycast to find best target like the game normally would
		if target_unit and HEALTH_ALIVE[target_unit] then
			local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
			if unit_data_extension then
				smart_tag:_trigger_smart_tag_unit_contextual(target_unit) --tag onnce
				print_debug("dog_attack ordered")
				smart_tag:_trigger_smart_tag_unit_contextual(target_unit, "companion_order") --send attack order
			end
		else
			print_debug("NO target unit or dead")
		end
	end
else
	mod.dog_attack = function() end
end

mod:hook_origin(CLASS.CompanionOutlineExtension, "_start_outline", function(self)
	if self._outline_started then
		local local_player = Managers.player:local_player(1)
		local is_local_player = local_player == self._owner_player
		local outline_name = is_local_player and "owned_companion" or "allied_companion"
		local outline_system = self._outline_system
		if
			(setting_enable_dog_outline and outline_name == "owned_companion")
			or (setting_enable_dog_others_outline and outline_name == "allied_companion")
		then
			if not outline_system:has_outline(self._unit, outline_name) then
				print_debug("hook _start_outline() for dog", self._owner_player:name(), outline_name)

				outline_system:add_outline(self._unit, outline_name)
			else
				print_debug("hook EXISTING outline _start_outline() for dog", self._owner_player:name(), outline_name)

				outline_system:remove_outline(self._unit, outline_name)
				outline_system:add_outline(self._unit, outline_name)
			end
		end
	end
end)

mod:hook_origin(CLASS.CompanionOutlineExtension, "_stop_outline", function(self)
	local local_player = Managers.player:local_player(1)
	local is_local_player = local_player == self._owner_player
	local outline_name = is_local_player and "owned_companion" or "allied_companion"
	if
		(not setting_enable_dog_outline and outline_name == "owned_companion")
		or (not setting_enable_dog_others_outline and outline_name == "allied_companion")
	then
		print_debug("hook _stop_outline() for dog", self._owner_player:name(), outline_name)

		self._outline_system:remove_outline(self._unit, outline_name)
	end
end)

--********** VFX toning down **********

-- mod:hook_safe(
-- 	CLASS.FxSystem,
-- 	"play_impact_fx",
-- 	function(
-- 		self,
-- 		impact_fx,
-- 		position,
-- 		direction,
-- 		source_parameters,
-- 		attacking_unit,
-- 		optional_target_unit,
-- 		optional_node_index,
-- 		optional_hit_normal,
-- 		optional_will_be_predicted,
-- 		local_only_or_nil
-- 	)
-- 		print_debug(
-- 			"play_impact_fx",
-- 			impact_fx.name,
-- 			position,
-- 			direction,
-- 			source_parameters,
-- 			attacking_unit,
-- 			optional_target_unit,
-- 			optional_node_index,
-- 			optional_hit_normal,
-- 			optional_will_be_predicted,
-- 			local_only_or_nil
-- 		)

-- 	end
-- )
--[[ mod:hook_safe(CLASS.FxSystem, "trigger_vfx", function(self, vfx_name, position, optional_rotation)
	print_debug("trigger_vfx", vfx_name, position, optional_rotation)
end)
mod:hook_safe(CLASS.FxSystem, "rpc_trigger_vfx", function(self, vfx_name, position, optional_rotation)
	print_debug("rpc_trigger_vfx", vfx_name, position, optional_rotation)
end) ]]

--World.create_particles(world, start_particle_effect, position, rotation)
if setting_enable_impact_vfx then
	mod:hook(World, "create_particles", function(orig_func, world, effect_name, position, rotation, scale)
		if
			effect_name == "content/fx/particles/impacts/weapons/powermaul/impact_powermaul_weapon_special_p2"
			and setting_impact_maul_special ~= ""
		then
			effect_name = setting_impact_maul_special
		elseif
			effect_name == "content/fx/particles/weapons/shields/arbites_shield_weapon_special_01"
			and setting_impact_shield_special ~= ""
		then
			effect_name = setting_impact_shield_special
		elseif effect_name == "content/fx/particles/impacts/impact_shock_01" and setting_impact_shock ~= "" then
			effect_name = setting_impact_shock
		elseif
			not setting_enable_mine_vfx
			and effect_name == "content/fx/particles/weapons/grenades/shock_mine/shock_mine_link_01"
		then
			return
		elseif
			not setting_enable_screenspace_vfx
			and string.find(effect_name, "^content/fx/particles/screenspace/screen_adamant")
		then
			return
		end

		-- if enable_debug_mode and effect_name ~= "content/fx/particles/interacts/footstep_dust_01" then
		-- 	print_debug("World.create_particles", effect_name, position, rotation, scale)
		-- end
		return orig_func(world, effect_name, position, rotation, scale)
	end)
end
