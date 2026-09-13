-- Braced Autogun Meltagun prototype. Native finite-burst hitscan supplies
-- authoritative damage; bounded cosmetic plasma layers supply presentation.
-- Loaded once by bootstrap through io_dofile, never by native require.
local M = {}
local T = {
	mark = "autogun_p2_m3", windup = 0.65, interval = 0.1,
	ticks = 10, cycle = 2.4, range = 12, full_range = 6,
	clip = 40, reserve = 160, attack = { 450, 650 },
	-- Per-axis emitter scaling is supported by the engine. Whether this asset's
	-- sprites and spread both inherit it still needs a visual field test.
	stream_width = 0.28,
	beam_particle = "content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_orange",
	plasma_width = 0.20, plasma_refresh = 0.05, plasma_lifetime = 0.14, plasma_max_layers = 3,
	-- Exact exports verified against the installed orange beam's material and
	-- shader. These alter shading, not geometry, particles or damage queries.
	plasma_material = { cloud = "beam", emission = 30, fill_blend = 0.35,
		alpha_scale = 0.65, colour = { 1, 0.12, 0.015 } },
	local_cycle_volume = 70,
	wound_interval = 0.20,
	laser_particle = "content/fx/particles/enemies/sniper_laser_sight",
	-- Actual sniper SHOT, not its aiming laser or drifting companion trail.
	shot_particle = "content/fx/particles/enemies/renegade_sniper/renegade_sniper_beam",
	shot_width = 0.10, shot_refresh = 0.04, shot_lifetime = 0.11, shot_max_layers = 3,
	-- Short first-person overlap only. Main beam and third-person stay native.
	muzzle_core_length = 1.20,
	custom_laser_particle = "content/fx/particles/pilgrimage/melta_core_warm_white",
	-- Native targeting laser uses hit_distance = (.05, distance + 1, .5).
	-- Restore the narrow v0.28.109 baseline. Wider ribbons failed in game.
	laser_width = 0.15, laser_y_offset = 1, laser_z = 0.5,
	impact_sound = "wwise/events/weapon/play_bullet_hits_plasmagun_gen",
	impact_sound_interval = 0.20,
	contact_grace = 0.16,
	particle = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control",
	particle_3p = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_3p",
	sound = "wwise/events/weapon/play_flamethrower_fire_loop_3d",
	stop_sound = "wwise/events/weapon/stop_flamethrower_fire_loop_3d",
	charge_particle = "content/fx/particles/weapons/rifles/plasma_gun/plasma_gun_charge",
	charge_sound = "wwise/events/weapon/play_weapon_plasmagun_charge_fast",
	charge_stop_sound = "wwise/events/weapon/stop_weapon_plasmagun_charge_fast",
}
local mod, hooks, fileio, heavy, settings
local thermal_wound
local WOUND_NAME = "pilgrimage_melta_thermal"
-- Bounded candidate diagnostics, flushed on action cleanup, never per frame.
-- DMF logging may be disabled, so use the established mod-local writer.
local trace_lines, trace_count, instance_serial = {}, 0, 0
local function trace(event, instance, detail)
	if not fileio or trace_count >= 192 then return end
	trace_count = trace_count + 1
	local a = instance and instance._action
	trace_lines[#trace_lines + 1] = string.format("%s instance=%s owner=%s local=%s first_person=%s action=%s %s\n",
		event, tostring(instance and instance._trace_id), tostring(instance and instance._owner),
		tostring(instance and instance._is_local_unit), tostring(instance and instance._is_first_person),
		tostring(a and a.current_action_name), tostring(detail or ""))
end
local function flush_trace()
	if not fileio or #trace_lines == 0 then return end
	pcall(fileio.append, "melta-presentation-diagnostic.txt", table.concat(trace_lines))
	trace_lines = {}
end
local active = false
local requested = {}
local instances = setmetatable({}, { __mode = "k" })
local warned = {}
local ready_times = setmetatable({}, { __mode = "k" })
local audio_retry_at = {}
local audio_files = { cycle = "cycle.wav", contact = "contact.wav" }
local audio_lengths = { cycle = T.cycle, contact = 1.2 }
-- Simple Audio subtracts decay * distance in addition to its linear falloff.
-- The old .06/2/35 contact settings were almost silent at our 12m range.
-- Retain direction at the target, but full contact gain within weapon range.
local function audio_falloff(phase)
	if phase == "contact" then return 0, T.range, 35 end
	return 0.06, 2, 35
end
local rate = { fire_time = T.windup, auto_fire_time = T.interval, max_shots = T.ticks }

local function copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copy(v) end
	return out
end

local function warn_once(key, detail)
	if warned[key] then return end
	warned[key] = true
	trace("warning", nil, key .. ": " .. tostring(detail))
	if mod and mod.warning then mod:warning("Meltagun %s: %s", key, tostring(detail)) end
end

local function marked(self)
	return active and self._action_settings and self._action_settings._pilgrimage_melta
end

-- Install on the concrete hitscan class too: native class() copies methods,
-- so a subclass created before the base hook otherwise retains an uncapped
-- autogun rate. Separate target keys cannot be mistaken for copied sentinels.
local function install_rate_hooks(target, key)
	if hooks.claim and hooks.claim(target, key) then return end
	mod:hook(target, "_fire_rate_settings", function(func, self, ...)
		if marked(self) then return rate end
		local owned = heavy and heavy.fire_rate(self)
		if owned then return owned end
		return func(self, ...)
	end)
	mod:hook(target, "_scale_auto_fire_time_with_buffs", function(func, self, interval)
		if marked(self) then return T.interval end
		local owned = heavy and heavy.fire_rate(self)
		if owned then return func(self, owned.auto_fire_time or interval) end
		return func(self, interval)
	end)
end

local function resource(kind, name)
	if not Application or not Application.can_get_resource then return false end
	local ok, available = pcall(Application.can_get_resource, kind, name)
	return ok and available == true
end

local function request_resources()
	if not mod or not mod.load_package then return end
	for _, name in ipairs({ T.beam_particle, T.laser_particle, T.shot_particle, T.impact_sound,
		T.particle, T.particle_3p, T.sound, T.stop_sound,
		T.charge_particle, T.charge_sound, T.charge_stop_sound }) do
		if not requested[name] and resource("package", name) then
			requested[name] = true
			-- Asynchronous and once per session, not a repeating setup scan.
			local ok, err = pcall(mod.load_package, mod, name)
			if not ok then warn_once("package load", err) end
		end
	end
end

local function profile_from(original)
	if type(original) ~= "table" or type(original.targets) ~= "table"
		or type(original.targets.default_target) ~= "table" then return nil end
	local p = copy(original)
	p._pilgrimage_melta_impact = true
	-- Keep the shipped name for NetworkLookup. Do not create a melta profile id.
	p.power_distribution = { attack = copy(T.attack), impact = { 15, 25 } }
	p.ranges = { min = { T.full_range, T.full_range }, max = { T.range, T.range } }
	p.cleave_distribution = { attack = 8, impact = 4 }
	p.ignore_shield = true
	p.damage_type = "burning"
	-- Native wounds expose the underlying flesh; gibbing is only the separate
	-- killing-blow/ragdoll presentation. Neither changes armour conversion.
	if thermal_wound then p.wounds_template = thermal_wound end
	p.gibbing_type = "plasma"
	p.gibbing_power = 3 -- native GibbingSettings.gibbing_power.heavy
	local close = { unarmored = 1, armored = 1, resistant = 0.6, player = 1,
		berserker = 1, super_armor = 1, disgustingly_resilient = 1, void_shield = 0.75 }
	p.armor_damage_modifier_ranged = { near = { attack = {}, impact = {} }, far = { attack = {}, impact = {} } }
	for armor, value in pairs(close) do
		p.armor_damage_modifier_ranged.near.attack[armor] = { value, value }
		p.armor_damage_modifier_ranged.far.attack[armor] = { value * 0.2, value * 0.2 }
		p.armor_damage_modifier_ranged.near.impact[armor] = { 1, 1 }
		p.armor_damage_modifier_ranged.far.impact[armor] = { 0.4, 0.4 }
	end
	-- One shared per-contact profile, not an inherited strong first-target
	-- override followed by native autogun damage on subsequent targets.
	local target = copy(p.targets.default_target)
	target.power_distribution = nil
	target.armor_damage_modifier = nil
	target.boost_curve_multiplier_finesse = { 0.25, 0.25 }
	target.crit_boost = 0.1
	p.targets = { default_target = target }
	return p
end

local function build_action(original, braced)
	local config = original and original.fire_configuration
	local scan = config and config.hit_scan_template
	local profile = scan and scan.damage and scan.damage.impact and scan.damage.impact.damage_profile
	local owned_profile = profile_from(profile)
	if not owned_profile or original.kind ~= "shoot_hit_scan" then return nil end
	local a = copy(original)
	a._pilgrimage_melta = true
	local original_condition = original.action_condition_func
	a.action_condition_func = function(settings, params, used_input, t, ...)
		if original_condition and not original_condition(settings, params, used_input, t, ...) then return false end
		local ready = params and params.unit and ready_times[params.unit]
		return not ready or t >= ready
	end
	a.total_time = T.cycle
	-- Natural completion uses stop_input to re-arm the native input hierarchy.
	-- minimum_hold_time commits the burst without removing that reset signal.
	a.stop_input = "shoot_release"
	a.minimum_hold_time = T.cycle
	a.time_scale_stat_buffs = {}
	a.ammunition_usage = 1
	a.action_movement_curve = { start_modifier = braced and 0.35 or 0.5 }
	a.fx = { no_ammo_shoot_sfx_alias = "ranged_no_ammo",
		melta_plasma_layers = { T.beam_particle, T.laser_particle, T.shot_particle },
		melta_impacts = { T.impact_sound },
		-- Native resource discovery walks this table; the explicit async load
		-- also covers a donor whose dependency list was cached in the hub.
		melta_stream = { T.particle, T.particle_3p, T.sound, T.stop_sound },
		melta_charge = { T.charge_particle, T.charge_sound, T.charge_stop_sound },
	}
	a.fire_configuration.damage_type = "burning"
	a.fire_configuration.hit_scan_template = {
		range = T.range,
		damage = {
			impact = { damage_profile = owned_profile, destroy_on_impact = false },
			penetration = { depth = 0.5, target_index_increase = 1, destroy_on_exit = false },
		},
		collision_tests = {
			{ test = "ray", against = "statics", collision_filter = "filter_player_character_shooting_raycast_statics" },
			{ test = "sphere", against = "dynamics", collision_filter = "filter_player_character_shooting_raycast_dynamics", radius = 0.12 },
		},
	}
	-- Defensive swaps/abilities stay available. Re-bracing, reloading or
	-- special attacks cannot cancel straight into another full-power burst.
	for key, chain in pairs(a.allowed_chain_actions or {}) do
		if key ~= "wield" and key ~= "combat_ability" and key ~= "grenade_ability" then
			chain.chain_time = T.cycle
		end
	end
	a.allowed_chain_actions = a.allowed_chain_actions or {}
	a.allowed_chain_actions[braced and "zoom_shoot" or "shoot"] = {
		action_name = braced and "action_shoot_zoomed" or "action_shoot_hip", chain_time = T.cycle,
	}
	return a
end

function M.build(templates, ammo_templates)
	local template = templates and templates[T.mark]
	local ammunition = ammo_templates and ammo_templates[T.mark]
	if not template or not template.actions or not ammunition
		or not ammunition.ammunition_clips or not ammunition.ammunition_clips[1]
		or not ammunition.ammunition_reserve then return nil, "unexpected Meltagun donor/ammo shape" end
	local hip = build_action(template.actions.action_shoot_hip, false)
	local brace = build_action(template.actions.action_shoot_zoomed, true)
	if not hip or not brace then return nil, "unexpected Meltagun firing profile" end
	local ammo = copy(ammunition)
	ammo.ammunition_clips[1].lerp_basic = T.clip
	ammo.ammunition_clips[1].lerp_perfect = T.clip
	ammo.ammunition_reserve.lerp_basic = T.reserve
	ammo.ammunition_reserve.lerp_perfect = T.reserve
	local scripts = copy(template.wieldable_slot_scripts or {})
	scripts[#scripts + 1] = "PilgrimageMeltaEffects"
	local lookup = template.__base_template_lookup
	if not lookup or not lookup.dodge or not lookup.dodge.base
		or type(lookup.dodge.base.new_identifier) ~= "string" then
		return nil, "unexpected Meltagun dodge lookup"
	end
	local owned_lookup = copy(lookup)
	-- Reuse the heavy-weapon source registered by the same atomic catalogue.
	-- Preserve the donor's networked component identifier and all other lookups.
	owned_lookup.dodge.base.base_identifier = "pilgrimage_plasma_cannon_single_dodge"
	local buffs = copy(template.buffs or {})
	buffs.on_wield = buffs.on_wield or {}
	local heavy_buff = "pilgrim_weapon_plasma_cannon_wield_penalty"
	local found = false
	for _, name in ipairs(buffs.on_wield) do if name == heavy_buff then found = true end end
	if not found then
		if #buffs.on_wield >= 3 then return nil, "Meltagun has no free on-wield buff slot" end
		buffs.on_wield[#buffs.on_wield + 1] = heavy_buff
	end
	return { template = template, hip = template.actions.action_shoot_hip,
		lookup = lookup, owned_lookup = owned_lookup, buffs = template.buffs, owned_buffs = buffs,
		brace = template.actions.action_shoot_zoomed, ammo = ammunition,
		scripts = template.wieldable_slot_scripts, owned_scripts = scripts,
		owned_hip = hip, owned_brace = brace, owned_ammo = ammo }
end

function M.apply(bundle, ammo_templates)
	bundle.template.__base_template_lookup = bundle.owned_lookup
	bundle.template.buffs = bundle.owned_buffs
	bundle.template.actions.action_shoot_hip = bundle.owned_hip
	bundle.template.actions.action_shoot_zoomed = bundle.owned_brace
	bundle.template.wieldable_slot_scripts = bundle.owned_scripts
	ammo_templates[T.mark] = bundle.owned_ammo
	active = true
	request_resources()
end

function M.revert(bundle, ammo_templates)
	active = false
	ready_times = setmetatable({}, { __mode = "k" })
	audio_retry_at = {}
	for instance in pairs(instances) do instance:unwield() end
	if not bundle then return end
	bundle.template.__base_template_lookup = bundle.lookup
	bundle.template.buffs = bundle.buffs
	bundle.template.actions.action_shoot_hip = bundle.hip
	bundle.template.actions.action_shoot_zoomed = bundle.brace
	bundle.template.wieldable_slot_scripts = bundle.scripts
	ammo_templates[T.mark] = bundle.ammo
end

-- Visual scripts also run for husks, so they derive their phase from native
-- synchronized action/shoot components, not local hook-only timestamps.
local Effects = class("PilgrimageMeltaEffects")

function Effects:init(context, slot, template, fx_sources)
	self._owner = context.owner_unit
	self._is_local_unit = context.is_local_unit == true
	self._camera = ScriptUnit.has_extension and ScriptUnit.has_extension(context.owner_unit, "first_person_system")
	instance_serial = instance_serial + 1
	self._trace_id = instance_serial
	self._world = context.world
	self._wwise_world = context.wwise_world
	self._group = context.player_particle_group_id
	self._template = template
	self._muzzle = fx_sources._muzzle
	local data = ScriptUnit.extension(context.owner_unit, "unit_data_system")
	self._action = data:read_component("weapon_action")
	self._shoot = data:read_component("action_shoot")
	self._first_person = data:read_component("first_person")
	self._fx = ScriptUnit.extension(context.owner_unit, "fx_system")
	self._physics = World.physics_world(context.world)
	instances[self] = true
end

function Effects:wield() end

-- Optional presentation only. A missing/disabled library or rejected playback
-- leaves the native sound intact and cannot abort weapon balancing.
function Effects:_start_audio(phase, position, t, offset)
	if settings and not settings.custom_weapon_sounds_enabled() then
		self:_stop_audio(phase)
		return false
	end
	self._audio = self._audio or {}
	if self._audio[phase] then return self._audio[phase].custom end
	local state = { custom = false }
	self._audio[phase] = state
	if not get_mod or t < (audio_retry_at[phase] or 0) then return false end
	local ok, api = pcall(get_mod, "SimpleAudio")
	if not ok or not api or type(api.play_file) ~= "function"
		or type(api.stop_file) ~= "function" then return false end
	if api.is_enabled then
		local enabled, value = pcall(api.is_enabled, api)
		if not enabled or not value then return false end
	end
	offset = math.max(0, offset or 0)
	if offset >= audio_lengths[phase] then state.custom = true; return true end
	local spatial_position
	if phase == "contact" or not self._is_local_unit then spatial_position = position end
	local decay, minimum, maximum = audio_falloff(phase)
	local success, id = pcall(api.play_file,
		"mods/Pilgrimage/audio/melta/" .. audio_files[phase],
		{ audio_type = "sfx", volume = phase == "cycle" and self._is_local_unit and T.local_cycle_volume or 100, pos = offset,
			duration = audio_lengths[phase] - offset }, spatial_position, decay, minimum, maximum)
	trace("audio_start", self, string.format("phase=%s offset=%.3f spatial=%s success=%s id=%s fire_at=%s",
		phase, offset, tostring(spatial_position ~= nil), tostring(success), tostring(id), tostring(self._shoot.fire_at_time)))
	if not success or not id then
		audio_retry_at[phase] = t + 30
		warn_once("optional " .. phase .. " audio", success and "using native fallback" or id)
		return false
	end
	state.api, state.id, state.custom, state.position_at = api, id, true, t
	return true
end

function Effects:_position_audio(phase, position, t)
	local state = self._audio and self._audio[phase]
	if not state or not state.id or (phase ~= "contact" and self._is_local_unit) or t < state.position_at + 0.05 then return end
	state.position_at = t
	local decay, minimum, maximum = audio_falloff(phase)
	if state.api.set_position then pcall(state.api.set_position, state.id, position, decay, minimum, maximum) end
end

function Effects:_stop_audio(phase)
	local state = self._audio and self._audio[phase]
	if not state then return end
	-- Never pass nil: Simple Audio interprets that as stopping every mod's audio.
	if state.id then
		trace("audio_stop", self, "phase=" .. phase .. " id=" .. tostring(state.id))
		pcall(state.api.stop_file, state.id, 0.08)
	end
	self._audio[phase] = nil
end

function M.on_audio_settings_changed()
	audio_retry_at = {}
	for instance in pairs(instances) do
		instance:_stop_audio("cycle")
		instance:_stop_audio("contact")
		-- Remove only our fallback sources when switching back to custom audio.
		-- The next presentation update resumes at the current phase offset;
		-- do not restart the attack, particle effects, or anyone else's sounds.
		for _,source in ipairs({ {"_charge_source",T.charge_stop_sound}, {"_source",T.stop_sound} }) do
			local id=instance[source[1]]
			if id then
				pcall(WwiseWorld.trigger_resource_event,instance._wwise_world,source[2],id)
				pcall(WwiseWorld.destroy_manual_source,instance._wwise_world,id)
				instance[source[1]]=nil
			end
		end
	end
end

function Effects:unwield()
	self:_stop_charge()
	self:_stop_stream()
	self:_stop_audio("cycle")
	self:_stop_audio("contact")
	self._contact_until = nil
	self._cycle_fire_at = nil
	self._impact_sound_at = nil
	self._traced_contacts = nil
	if self._blocked_audio_count then
		trace("native_muzzle_blocked", self, "count=" .. tostring(self._blocked_audio_count))
		self._blocked_audio_count = nil
	end
	flush_trace()
end

-- Sound decorates an already resolved contact. Rejected contact particles
-- and muzzle flash are removed until the intended reference is identified.
function Effects:_impact(target, position, normal)
	local t = self._last_update_t
	if not t or not position or not normal then return end
	-- One positional texture spans consecutive damage ticks and cleaved targets.
	-- Never replay its attack for every victim. No stored transient Vector3.
	self._contact_until = t + T.contact_grace
	if self:_start_audio("contact", position, t, 0) then
		self:_position_audio("contact", position, t)
		return
	end
	-- Limit sound across
	-- all cleaved enemies, so a crowded hit does not multiply its volume.
	if (not self._impact_sound_at or t - self._impact_sound_at >= T.impact_sound_interval)
		and mod and mod.package_status and mod:package_status(T.impact_sound) == "loaded" then
		self._impact_sound_at = t
		pcall(WwiseWorld.trigger_resource_event, self._wwise_world, T.impact_sound, position)
	end
end

function Effects:_stop_stream()
	self:_stop_shot_core()
	self:_stop_laser_core()
	self._plasma_next_t = nil
	self._stream_is_beam = nil
	if self._plasma_layers then
		for _, layer in ipairs(self._plasma_layers) do
			if World.are_particles_playing(self._world, layer.id) then World.destroy_particles(self._world, layer.id) end
		end
		self._plasma_layers = nil
		self._particle = nil
	elseif self._particle then
		World.destroy_particles(self._world, self._particle)
		self._particle = nil
	end
	if self._source then
		WwiseWorld.trigger_resource_event(self._wwise_world, T.stop_sound, self._source)
		WwiseWorld.destroy_manual_source(self._wwise_world, self._source)
		self._source = nil
	end
end

local function stop_shot_layer(world, layer)
	for _, id in ipairs({ layer.id, layer.muzzle_id }) do
		if World.are_particles_playing(world, id) then World.destroy_particles(world, id) end
	end
	layer.muzzle_id = nil
end

function Effects:_stop_shot_core()
	for _, layer in ipairs(self._shot_layers or {}) do
		stop_shot_layer(self._world, layer)
	end
	self._shot_layers, self._shot_next_t = nil, nil
end

function Effects:_camera_is_first_person()
	if not self._is_local_unit then return false end
	-- First Person Body can show 3p equipment while the CAMERA stays 1p.
	-- Do not use that equipment flag to alter actual third-person rendering.
	local camera = self._camera
	if camera then
		if camera._force_third_person_mode then return false end
		if type(camera.wants_first_person_camera) == "function" then
			local ok, wants = pcall(camera.wants_first_person_camera, camera)
			if ok then return wants == true end
			return false
		end
	end
	return self._is_first_person == true
end

function Effects:_update_muzzle_core(position, rotation, length)
	local wanted = not self._muzzle_core_failed and self:_camera_is_first_person()
	local short_length = math.min(length, T.muzzle_core_length)
	local ok, err = pcall(function()
		for _, layer in ipairs(self._shot_layers or {}) do
			if not wanted then
				if layer.muzzle_id and World.are_particles_playing(self._world, layer.muzzle_id) then
					World.destroy_particles(self._world, layer.muzzle_id)
				end
				layer.muzzle_id = nil
			elseif not layer.muzzle_attempted then
				layer.muzzle_attempted = true
				layer.muzzle_id = World.create_particles(self._world, T.shot_particle, position, rotation, nil, self._group)
				assert(layer.muzzle_id, "no muzzle core particle")
				-- Match the source equipment's projection, even with a 1p camera.
				if self._is_first_person then World.set_particles_use_custom_fov(self._world, layer.muzzle_id, true) end
			end
			if wanted and layer.muzzle_id and World.are_particles_playing(self._world, layer.muzzle_id) then
				World.move_particles(self._world, layer.muzzle_id, position, rotation)
				World.set_particles_variable(self._world, layer.muzzle_id, self._shot_index, Vector3(T.shot_width, short_length, short_length))
			end
		end
	end)
	if not ok then
		self._muzzle_core_failed = true
		-- An optional near-field fill failure must not discard the approved core.
		for _, layer in ipairs(self._shot_layers or {}) do
			if layer.muzzle_id and World.are_particles_playing(self._world, layer.muzzle_id) then
				World.destroy_particles(self._world, layer.muzzle_id)
			end
			layer.muzzle_id = nil
		end
		warn_once("first-person muzzle fill unavailable; retaining main beam", err)
	end
end

function Effects:_update_shot_core(t, position, rotation, length)
	if length <= 0.01 then self:_stop_shot_core(); return false end
	if self._shot_failed or not mod or not mod.package_status
		or mod:package_status(T.shot_particle) ~= "loaded" or not resource("particles", T.shot_particle) then
		self:_stop_shot_core(); return false
	end
	if not self._shot_index then
		local ok, index = pcall(World.find_particles_variable, self._world, T.shot_particle, "hit_distance")
		if not ok or index == nil or index == -1 then
			self._shot_failed = true
			warn_once("sniper shot controls unavailable; retaining targeting core", index)
			return false
		end
		self._shot_index = index
	end
	local layers = self._shot_layers or {}
	self._shot_layers = layers
	for i = #layers, 1, -1 do
		local layer = layers[i]
		local playing = World.are_particles_playing(self._world, layer.id)
		if not playing or t >= layer.expires then
			stop_shot_layer(self._world, layer)
			table.remove(layers, i)
		end
	end
	-- Short overlapping shot flashes, not projectile entities or extra hits.
	-- At most one creation per update and three live core layers. No catch-up.
	if not self._shot_next_t or t >= self._shot_next_t then
		if #layers >= T.shot_max_layers then stop_shot_layer(self._world, table.remove(layers, 1)) end
		local ok, id = pcall(World.create_particles, self._world, T.shot_particle, position, rotation, nil, self._group)
		if not ok or not id then
			self._shot_failed = true; self:_stop_shot_core()
			warn_once("sniper shot creation failed; retaining targeting core", id)
			return false
		end
		layers[#layers + 1] = { id = id, expires = t + T.shot_lifetime }
		self._shot_next_t = t + T.shot_refresh
		if self._is_first_person then World.set_particles_use_custom_fov(self._world, id, true) end
		if not self._shot_traced then trace("sniper_shot_core", self, T.shot_particle); self._shot_traced = true end
	end
	-- Native MinionFxExtension uses (.1, length, length) for the shot beam.
	-- Unlike the targeting sight, it does not use (width, length + 1, .5).
	local ok, err = pcall(function()
		for _, layer in ipairs(layers) do
			World.move_particles(self._world, layer.id, position, rotation)
			World.set_particles_variable(self._world, layer.id, self._shot_index, Vector3(T.shot_width, length, length))
		end
	end)
	if not ok then
		self._shot_failed = true; self:_stop_shot_core()
		warn_once("sniper shot alignment failed; retaining targeting core", err)
		return false
	end
	self:_update_muzzle_core(position, rotation, length)
	return #layers > 0
end

function Effects:_stop_laser_core()
	if self._laser_particle and World.are_particles_playing(self._world, self._laser_particle) then
		World.destroy_particles(self._world, self._laser_particle)
	end
	self._laser_particle = nil
	self._laser_resource = nil
	self._laser_index = nil
end

function Effects:_update_laser_core(position, rotation, length)
	if self._laser_failed or length <= 0.01 then
		self:_stop_laser_core()
		return
	end
	-- The private asset patch adds a NEW particle to the native laser package.
	-- Do not request a nonexistent separately named package, and never switch
	-- the resource/control contract underneath a live emitter.
	if not self._laser_resource then
		local loaded = mod and mod.package_status and mod:package_status(T.laser_particle) == "loaded"
		self._laser_resource = loaded and not self._custom_laser_failed
			and resource("particles", T.custom_laser_particle) and T.custom_laser_particle or T.laser_particle
		local key = "laser resource " .. self._laser_resource
		if not warned[key] then
			warned[key] = true
			if mod and mod.info then mod:info("Meltagun core selected: %s", self._laser_resource) end
		end
	end
	local particle_name = self._laser_resource
	if not resource("particles", particle_name) then self:_stop_laser_core(); return end
	if not self._laser_index then
		local ok, index = pcall(World.find_particles_variable, self._world, particle_name, "hit_distance")
		if not ok or index == nil or index == -1 then
			if particle_name == T.custom_laser_particle then
				self._custom_laser_failed = true; self:_stop_laser_core()
				warn_once("custom core controls unavailable; using native laser", index)
				return self:_update_laser_core(position, rotation, length)
			end
			self._laser_failed = true
			warn_once("targeting laser control unavailable; retaining plasma shell", index)
			return
		end
		self._laser_index = index
	end
	if self._laser_particle and not World.are_particles_playing(self._world, self._laser_particle) then
		self._laser_particle = nil
	end
	if not self._laser_particle then
		local ok, id = pcall(World.create_particles, self._world, particle_name, position, rotation, nil, self._group)
		if not ok or not id then
			if particle_name == T.custom_laser_particle then
				self._custom_laser_failed = true; self:_stop_laser_core()
				warn_once("custom core creation unavailable; using native laser", id)
				return self:_update_laser_core(position, rotation, length)
			end
			self._laser_failed = true
			warn_once("targeting laser creation failed; retaining plasma shell", id)
			return
		end
		self._laser_particle = id
		if self._is_first_person then World.set_particles_use_custom_fov(self._world, id, true) end
	end
	-- One persistent emitter, not a new laser for every damage tick/frame.
	-- This asset's Z control is .5, NOT the plasma line's repeated length.
	World.move_particles(self._world, self._laser_particle, position, rotation)
	World.set_particles_variable(self._world, self._laser_particle, self._laser_index,
		Vector3(T.laser_width, length + T.laser_y_offset, T.laser_z))
end

function Effects:_shade_plasma(id)
	if self._plasma_material_unavailable then return end
	if type(World.set_particles_material_scalar) ~= "function"
		or type(World.set_particles_material_vector3) ~= "function" then
		self._plasma_material_unavailable = true
		warn_once("plasma material API unavailable; retaining native shell", "missing setter")
		return
	end
	local p = T.plasma_material
	local ok, err = pcall(function()
		-- material_variable_1aa2798d blends a continuous transverse tent into
		-- the eroded profile. d3db8882.z scales coverage; preserve its X/Y.
		-- 81be4b15 multiplies emitted RGB, while material_variable is tint.
		World.set_particles_material_scalar(self._world, id, p.cloud, "material_variable_1aa2798d", p.fill_blend)
		World.set_particles_material_vector3(self._world, id, p.cloud, "material_variable_d3db8882", Vector3(1, 1, p.alpha_scale))
		World.set_particles_material_scalar(self._world, id, p.cloud, "material_variable_81be4b15", p.emission)
		World.set_particles_material_vector3(self._world, id, p.cloud, "material_variable", Vector3(p.colour[1], p.colour[2], p.colour[3]))
	end)
	if not ok then
		-- Optional per-emitter shading must never abort the weapon catalogue.
		self._plasma_material_unavailable = true
		warn_once("plasma material tuning unavailable", err)
	end
end

function Effects:_update_plasma(t, position, rotation, length)
	if not self._plasma_index then
		local ok, index = pcall(World.find_particles_variable, self._world, T.beam_particle, "hit_distance")
		if not ok or index == nil or index == -1 then
			self._beam_unavailable = true
			warn_once("orange plasma controls unavailable", index)
			self:_stop_stream()
			return false
		end
		self._plasma_index = index
	end
	local layers = self._plasma_layers or {}
	self._plasma_layers = layers
	for i = #layers, 1, -1 do
		local layer = layers[i]
		local playing = World.are_particles_playing(self._world, layer.id)
		if not playing or t >= layer.expires or length <= 0.01 then
			if playing then World.destroy_particles(self._world, layer.id) end
			table.remove(layers, i)
		end
	end
	if length > 0.01 and (not self._plasma_next_t or t >= self._plasma_next_t) then
		-- Never catch up missed frames with a spawn storm. At most one new
		-- cosmetic layer per update and three owned layers per weapon.
		if #layers >= T.plasma_max_layers then
			World.destroy_particles(self._world, table.remove(layers, 1).id)
		end
		local ok, id = pcall(World.create_particles, self._world, T.beam_particle, position, rotation, nil, self._group)
		if not ok or not id then
			self._beam_unavailable = true
			warn_once("orange plasma creation failed", id)
			self:_stop_stream()
			return false
		end
		layers[#layers + 1] = { id = id, expires = t + T.plasma_lifetime }
		-- Set once on each newly owned emitter, never on a shared material or
		-- every visual update. Ordinary plasma guns retain their native look.
		self:_shade_plasma(id)
		self._plasma_next_t = t + T.plasma_refresh
		if self._is_first_person then World.set_particles_use_custom_fov(self._world, id, true) end
	end
	-- Native plasma line FX use hit_distance = (width, length, length).
	-- Keep every surviving layer aligned, including when a wall moves closer.
	for _, layer in ipairs(layers) do
		World.move_particles(self._world, layer.id, position, rotation)
		World.set_particles_variable(self._world, layer.id, self._plasma_index, Vector3(T.plasma_width, length, length))
	end
	self._particle = layers[#layers] and layers[#layers].id or nil
	self._stream_is_beam = true
	return true
end

function Effects:_stop_charge()
	if self._charge_particle then
		World.destroy_particles(self._world, self._charge_particle)
		self._charge_particle = nil
	end
	if self._charge_source then
		WwiseWorld.trigger_resource_event(self._wwise_world, T.charge_stop_sound, self._charge_source)
		WwiseWorld.destroy_manual_source(self._wwise_world, self._charge_source)
		self._charge_source = nil
	end
end

function Effects:_update_charge(t)
	local pose = self._fx:vfx_spawner_pose(self._muzzle)
	local position = Matrix4x4.translation(pose)
	local rotation = Quaternion.look(Quaternion.forward(self._first_person.rotation))
	local level = math.max(0, math.min(1, 1 - (self._shoot.fire_at_time - t) / T.windup))
	if not self._charge_particle and resource("particles", T.charge_particle) then
		local ok, id = pcall(World.create_particles, self._world, T.charge_particle, position, rotation, nil, self._group)
		if ok and id then
			self._charge_particle = id
			self._charge_index = World.find_particles_variable(self._world, T.charge_particle, "charge_level")
			if self._is_first_person then World.set_particles_use_custom_fov(self._world, id, true) end
		else warn_once("charge effect creation", id) end
	end
	if self._charge_particle then
		World.move_particles(self._world, self._charge_particle, position, rotation)
		World.set_particles_variable(self._world, self._charge_particle, self._charge_index, Vector3(level, level, level))
	end
	-- Charge and discharge share one pre-mixed timeline. Stopping a visual
	-- phase must not stop the audio file at the charge/discharge boundary.
	local custom_audio = self:_start_audio("cycle", position, t, T.windup - (self._shoot.fire_at_time - t))
	self:_position_audio("cycle", position, t)
	if not custom_audio and not self._charge_source and mod and mod.package_status
		and mod:package_status(T.charge_sound) == "loaded"
		and mod:package_status(T.charge_stop_sound) == "loaded" then
		self._charge_source = WwiseWorld.make_manual_source(self._wwise_world, position, rotation)
		WwiseWorld.set_source_parameter(self._wwise_world, self._charge_source, "first_person_mode", self._is_first_person and 1 or 0)
		WwiseWorld.trigger_resource_event(self._wwise_world, T.charge_sound, self._charge_source)
	end
	if self._charge_source then
		WwiseWorld.set_source_position(self._wwise_world, self._charge_source, position)
		WwiseWorld.set_source_parameter(self._wwise_world, self._charge_source, "charge_level", level)
	end
end

function Effects:destroy()
	self:unwield()
	instances[self] = nil
end

function Effects:update_first_person_mode(first_person)
	if self._is_first_person ~= first_person then
		trace("perspective", self, "next=" .. tostring(first_person))
		-- Recreate view-dependent particles/sources, not the owner's continuous
		-- Simple Audio cycle. Switching presentation must not replay its attack.
		self:_stop_charge()
		self:_stop_stream()
	end
	self._is_first_person = first_person
end

function M.is_emitting(action, shoot, t)
	return active and action.template_name == T.mark
		and (action.current_action_name == "action_shoot_hip" or action.current_action_name == "action_shoot_zoomed")
		and shoot.num_shots_fired > 0 and t - shoot.fire_last_t < T.interval + 0.07
end

function Effects:update_unit_position(unit, dt, t)
	self._last_update_t = t
	if self._contact_until and t > self._contact_until then
		self:_stop_audio("contact")
		self._contact_until = nil
	end
	local charging = active and self._action.template_name == T.mark
		and (self._action.current_action_name == "action_shoot_hip" or self._action.current_action_name == "action_shoot_zoomed")
		and self._shoot.num_shots_fired == 0 and t < self._shoot.fire_at_time
	if charging then
		self:_stop_audio("contact")
		self._contact_until = nil
		if self._cycle_fire_at ~= self._shoot.fire_at_time then
			self:_stop_audio("cycle")
			self._cycle_fire_at = self._shoot.fire_at_time
		end
		self:_stop_stream(); self:_update_charge(t); return
	end
	self:_stop_charge()
	if not M.is_emitting(self._action, self._shoot, t) then
		local recovering = active and self._action.template_name == T.mark
			and (self._action.current_action_name == "action_shoot_hip" or self._action.current_action_name == "action_shoot_zoomed")
			and self._shoot.num_shots_fired >= T.ticks
		if recovering then
			local position = Matrix4x4.translation(self._fx:vfx_spawner_pose(self._muzzle))
			self:_position_audio("cycle", position, t)
			self:_stop_stream()
		else self:unwield() end
		return
	end
	local particle_name = self._fx:should_play_husk_effect() and T.particle_3p or T.particle
	local use_beam = not self._beam_unavailable and resource("particles", T.beam_particle)
	if use_beam then particle_name = T.beam_particle end
	-- If an asynchronous package finishes mid-burst, do not switch contracts
	-- under an existing particle. Its selected type lasts until cleanup.
	if self._particle or self._plasma_layers then use_beam = self._stream_is_beam end
	local pose = self._fx:vfx_spawner_pose(self._muzzle)
	local position = Matrix4x4.translation(pose)
	local direction = Quaternion.forward(self._first_person.rotation)
	local rotation = Quaternion.look(direction)
	local beam_unit, beam_node
	if use_beam then
		-- Use the same perspective-aware source selection as native unit FX.
		local ok, unit, node, unit_3p, node_3p = pcall(self._fx.vfx_spawner_unit_and_node, self._fx, self._muzzle)
		if ok then
			beam_unit = self._is_first_person and unit or unit_3p
			beam_node = self._is_first_person and node or node_3p
		end
		if not beam_unit or beam_node == nil then
			self._beam_unavailable = true
			warn_once("plasma source unavailable", self._muzzle)
			self:_stop_stream()
			return
		end
		position = Unit.world_position(beam_unit, beam_node)
	end
	local elapsed = t - self._shoot.fire_last_t + (self._shoot.num_shots_fired - 1) * T.interval
	-- One existing static ray bounds presentation only, never extra damage.
	local hit, _, distance = PhysicsWorld.raycast(self._physics, position, direction, T.range,
		"closest", "collision_filter", "filter_player_character_shooting_raycast_statics")
	local length = math.max(0, math.min(hit and distance or T.range, T.range))
	-- Look rotation points local +Y down the barrel. Compress X/Z only;
	-- the existing lifetime/raycast still controls forward reach, not this scale.
	local stream_scale = not use_beam and Vector3(T.stream_width, 1, T.stream_width) or nil
	if use_beam then
		if not self:_update_plasma(t, position, rotation, length) then return end
		if self:_update_shot_core(t, position, rotation, length) then
			self:_stop_laser_core()
		else self:_update_laser_core(position, rotation, length) end
	elseif not self._particle then
		if not resource("particles", particle_name) then
			warn_once("effect unavailable", particle_name)
			return
		end
		local ok, id = pcall(World.create_particles, self._world, particle_name, position, rotation, stream_scale, self._group)
		if not ok or not id then
			if use_beam then self._beam_unavailable = true end
			warn_once("effect creation", id); return
		end
		self._particle = id
		self._stream_is_beam = use_beam
		self._life_index = World.find_particles_variable(self._world, particle_name, "life")
		if self._is_first_person then World.set_particles_use_custom_fov(self._world, id, true) end
	elseif not use_beam then
		World.move_particles(self._world, self._particle, position, rotation, stream_scale)
	end
	local custom_audio = self:_start_audio("cycle", position, t, T.windup + elapsed)
	self:_position_audio("cycle", position, t)
	if not custom_audio and not self._source and mod and mod.package_status
		and mod:package_status(T.sound) == "loaded" and mod:package_status(T.stop_sound) == "loaded" then
		self._source = WwiseWorld.make_manual_source(self._wwise_world, position, rotation)
		WwiseWorld.trigger_resource_event(self._wwise_world, T.sound, self._source)
	end
	if not use_beam then
		local life = math.max(0.01, length / 45)
		World.set_particles_variable(self._world, self._particle, self._life_index, Vector3(life, life, life))
	end
	if self._source then WwiseWorld.set_source_position(self._wwise_world, self._source, position) end
end

-- Register only after the native lookup has been built, so vanilla IDs never
-- shift. Both Realms peers need this version, as enforced by the existing bridge.
function M.register_wounds(templates, lookup)
	if type(templates) ~= "table" or type(templates.plasma) ~= "table" or type(lookup) ~= "table" then return false end
	local wound = copy(templates.plasma)
	wound.name = WOUND_NAME
	for _, outcome in pairs(wound) do
		if type(outcome) == "table" then
			for _, zone in pairs(outcome) do
				if type(zone) == "table" then
					for _, shape in pairs(zone) do
						if type(shape) == "table" and shape.color_brightness then
							shape.color_brightness = { 0.06, 1 }
							shape.duration = { 2, 2.5 }
							shape.radius = { 3, 4 }
						end
					end
				end
			end
		end
	end
	local id = rawget(lookup, WOUND_NAME)
	if id and rawget(lookup, id) ~= WOUND_NAME then return false end
	if not id then
		id = #lookup + 1
		lookup[id], lookup[WOUND_NAME] = WOUND_NAME, id
	end
	templates[WOUND_NAME], thermal_wound = wound, wound
	return true
end

function M.install_wounds(WoundsExtension)
	if type(WoundsExtension.add_wounds) ~= "function" then return end
	if hooks.claim and hooks.claim(WoundsExtension, "__pilgrimage_melta_wounds") then return end
	mod:hook(WoundsExtension, "add_wounds", function(func, self, template, position, node, result, percent, damage_type, zone, shape)
		if not active or not template or template.name ~= WOUND_NAME then
			return func(self, template, position, node, result, percent, damage_type, zone, shape)
		end
		if not position or not node or (result ~= "damaged" and result ~= "died") or not percent or percent <= 0 then return end
		local t = World.time(Unit.world(self._unit))
		if result ~= "died" and self._pil_melta_wound_t and t >= self._pil_melta_wound_t
			and t - self._pil_melta_wound_t < T.wound_interval then return end
		local data, maximum = self._wounds_data, self._max_num_wounds
		if not data or not maximum or maximum < 1 then return end
		-- Borrow the native writer with an instance-local, temporary filter.
		-- Shared breed data is never edited. Keep region/gore checks, actor-space
		-- positioning, flesh visibility and native RPC handling inside func.
		local breed, health_threshold, count = self._breed, self._next_wound_health_percent, data.num_wounds
		local local_breed = {}
		for k,v in pairs(breed) do local_breed[k] = v end
		local config = {}
		for k,v in pairs(breed.wounds_config or {}) do config[k] = v end
		config.thresholds, config.health_percent_throttle = nil, nil
		config.apply_threshold_filtering = false
		local_breed.wounds_config = config
		self._breed = local_breed
		-- Native REUSE_WOUNDS is false. Reuse the next of its existing three
		-- slots only for this thermal wound, without allocating more slots.
		local previous_index = data.last_write_index
		if count >= maximum then
			data.last_write_index = previous_index % maximum
			data.num_wounds = data.last_write_index
		end
		local ok, err = pcall(func, self, template, position, node, result, percent, damage_type, zone, shape)
		self._breed, self._next_wound_health_percent = breed, health_threshold
		data.num_wounds = math.max(count, data.num_wounds)
		if ok then self._pil_melta_wound_t = t else
			data.last_write_index = previous_index
			warn_once("thermal wound", err)
		end
	end)
end

function M.init(deps)
	mod, hooks = deps.mod, deps.hooks
	fileio = deps.fileio
	heavy = deps.heavy
	settings = deps.settings
	if fileio then pcall(fileio.write, "melta-presentation-diagnostic.txt", "Pilgrimage 0.28.119: bounded presentation trace\n") end
	local wound_ok, templates, lookup = pcall(function()
		local network = require("scripts/network_lookup/network_lookup")
		return require("scripts/settings/damage/wounds_templates"), network.wounds_templates
	end)
	if not wound_ok or not M.register_wounds(templates, lookup) then warn_once("thermal wound registration", "keeping donor wounds") end
	hooks.require_now("scripts/extension_systems/wounds/wounds_extension", M.install_wounds)
	hooks.require_now("scripts/utilities/attack/impact_effect", function(ImpactEffect)
		if hooks.claim and hooks.claim(ImpactEffect, "__pilgrimage_melta_impacts") then return end
		if heavy then heavy.install_surface(ImpactEffect) end
		mod:hook(ImpactEffect, "play", function(func, target, actor, damage, damage_type, zone,
			result, position, normal, direction, attacker, data, stopped, attack_type, efficiency, profile)
			func(target, actor, damage, damage_type, zone, result, position, normal, direction,
				attacker, data, stopped, attack_type, efficiency, profile)
			if not active or not profile or not profile._pilgrimage_melta_impact or not damage or damage <= 0 then return end
			local extension = ScriptUnit.has_extension(target, "unit_data_system")
			local breed = extension and extension:breed()
			if not breed or breed.breed_type ~= "minion" then return end
			for instance in pairs(instances) do
				if instance._owner == attacker then
					instance._traced_contacts = instance._traced_contacts or {}
					local name = breed.name or "unknown"
					if not instance._traced_contacts[name] then
						instance._traced_contacts[name] = true
						local wound = profile.wounds_template
						trace("contact", instance, "breed=" .. tostring(name) .. " zone=" .. tostring(zone)
							.. " damage=" .. tostring(damage) .. " type=" .. tostring(damage_type)
							.. " wound=" .. tostring(type(wound) == "table" and wound.name or wound)
							.. " position=" .. tostring(position ~= nil) .. " normal=" .. tostring(normal ~= nil))
					end
					local ok, err = pcall(instance._impact, instance, target, position, normal)
					if not ok then warn_once("optional impact effect", err) end
					break
				end
			end
		end)
	end)
	hooks.require_now("scripts/extension_systems/weapon/actions/action_shoot", function(ActionShoot)
		if hooks.claim and hooks.claim(ActionShoot, "__pilgrimage_melta_rate_hooks") then return end
		install_rate_hooks(ActionShoot, "__pilgrimage_base_rate_dispatch")
		if heavy then
			heavy.install_shoot(ActionShoot)
		end
	end)
end

-- weapon_rebalance owns the single ActionShootHitScan require callback and
-- _shoot hook. It fans out here; registering either again aborts bootstrap
-- or replaces the Plasma Pistol's heat handler in DMF.
function M.install_hitscan_fx(ActionShootHitScan)
	install_rate_hooks(ActionShootHitScan, "__pilgrimage_hitscan_rate_dispatch")
	-- One owner for these methods: the dispatcher above serves both modules.
	if heavy then heavy.install_hitscan(ActionShootHitScan, true) end
	for _, method in ipairs({ "_play_line_fx", "_play_muzzle_flash_vfx", "_play_muzzle_smoke", "_play_shoot_sound", "_update_looping_shoot_sound" }) do
		mod:hook(ActionShootHitScan, method, function(func, self, ...)
			if heavy and heavy.fx(method, self, ...) then return end
			if marked(self) then
				-- EWC has a separate aimed/braced repeating-shot path. Do not
				-- layer the donor's gunfire over our single owned audio cycle.
				self.fake_looping_shoot_sfx_alias = nil
				self.fake_timer = nil
				return
			end
			return func(self, ...)
		end)
	end
end

function M.before_shoot(self, t)
	if marked(self) and self._action_component.num_shots_fired == 1 then
		ready_times[self._player_unit] = t + T.cycle - T.windup
	end
end

-- EWC can run outside our action hook and emit its braced sound BEFORE
-- calling the next hook. Guard the actual muzzle-sound entry point as well.
-- Ownership, current template, shooting action and source must all match;
-- reloads, abilities, other players and ordinary weapons remain untouched.
function M.install_player_fx(PlayerUnitFxExtension)
	if hooks.claim and hooks.claim(PlayerUnitFxExtension, "__pilgrimage_melta_muzzle_audio") then return end
	local function owns_muzzle(self, source)
		if heavy and heavy.owns_muzzle(self._unit, source) then return true end
		if not active or source == nil then return false end
		for instance in pairs(instances) do
			local action = instance._action
			if instance._owner == self._unit and instance._muzzle == source
				and action.template_name == T.mark
				and (action.current_action_name == "action_shoot_hip" or action.current_action_name == "action_shoot_zoomed") then
				instance._blocked_audio_count = (instance._blocked_audio_count or 0) + 1
				return true
			end
		end
		return false
	end
	for _, method in ipairs({ "trigger_wwise_event_with_source", "run_looping_sound" }) do
		if type(PlayerUnitFxExtension[method]) == "function" then
			mod:hook(PlayerUnitFxExtension, method, function(func, self, sound, source, ...)
				if owns_muzzle(self, source) then return end
				return func(self, sound, source, ...)
			end)
		end
	end
end

function M.status()
	return { active = active, mark = T.mark, windup = T.windup, ticks = T.ticks,
		range = T.range, cycle = T.cycle, clip = T.clip, reserve = T.reserve,
		stream_width = T.stream_width, beam_particle = T.beam_particle,
		laser_particle = T.laser_particle, laser_width = T.laser_width }
end
M.tuning = T
return M
