local mod = get_mod("Noospheric Mercy")
local Phrases = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/phrases")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")
local Marker = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/marker")
local Settings = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/settings")

local World = World
local Unit = Unit
local Light = Light
local Vector3 = Vector3
local Quaternion = Quaternion
local math_pi = math.pi

local LIGHT_SUPPORT = (World and World.spawn_unit_ex and Unit and Unit.light and Light and Vector3 and Quaternion) and true or false
local LIGHT_HEIGHT = 7
local LIGHT_INTENSITY = 30
local LIGHT_VOLUMETRIC = 16
local LIGHT_SPOT_START = 2 / 180 * math_pi
local LIGHT_SPOT_END = 14 / 180 * math_pi
local LIGHT_FALLOFF_START = 0
local LIGHT_FALLOFF_END = 9
local LIGHT_COLOR_CERTAIN = { 1.0, 0.8, 0.3 }
local LIGHT_COLOR_GUESS = { 1.0, 0.5, 0.0 }

local USE_LIGHT = false
local USE_BEAM = false
local USE_MARKER = true

local BEAM_PARTICLE = "content/fx/particles/abilities/cryptic/servoskull_empowered"

local USE_HACK_LIGHT = true
local HACK_PARTICLE = "content/fx/particles/abilities/cryptic/precision_stance_target_effect"
local HACK_LIGHT_COLOR = { 0.2, 0.6, 1.0 }

local HACK_TUNING = {
	height = 5,
	intensity = 8,
	volumetric = 5,
	falloff_end = 6,
	spot_end_deg = 18,
	particle_height = 1.2,
}

local CONE_LEVELS = 1
local CONE_SPACING = 0.7
local CONE_BASE_SCALE = 1.0
local CONE_TOP_SCALE = 0.2

local Visuals = {}

Visuals.HACK_TUNING = HACK_TUNING

local _cog = {}
local _outline = {}
local _light = {}
local _beam = {}
local _marker = {}

local DEFAULT_OUTLINE_PRIORITY = 5
local _guess_profile

local function outline_priority()
	return Settings.get("outline_priority") or DEFAULT_OUTLINE_PRIORITY
end

local function outline_system()
	return Managers.state.extension and Managers.state.extension:system("outline_system")
end

local function particle_for(confidence)
	if confidence == Phrases.CONFIDENCE_GUESS then
		return Phrases.COG_PARTICLE_GUESS
	end

	return Phrases.COG_PARTICLE
end

local function outline_for(confidence)
	if confidence == Phrases.CONFIDENCE_GUESS then
		return Phrases.OUTLINE_GUESS
	end

	return Phrases.OUTLINE_NAME
end

local function cone_offset(level)
	return Vector3.up() * (level * CONE_SPACING)
end

local function cone_scale(level)
	local t = (CONE_LEVELS > 1) and (level / (CONE_LEVELS - 1)) or 0
	local s = CONE_BASE_SCALE + (CONE_TOP_SCALE - CONE_BASE_SCALE) * t

	return Vector3(s, s, s)
end

local function create_cog_cone(world, particle_name, ground_position)
	local ids = {}

	for level = 0, CONE_LEVELS - 1 do
		ids[#ids + 1] = World.create_particles(world, particle_name, ground_position + cone_offset(level), nil, cone_scale(level))
	end

	return ids
end

local function move_cog_cone(world, ids, ground_position)
	for level = 1, #ids do
		World.move_particles(world, ids[level], ground_position + cone_offset(level - 1))
	end
end

local function destroy_cog_cone(world, ids)
	if not ids then
		return
	end

	for level = 1, #ids do
		World.destroy_particles(world, ids[level])
	end
end

local function light_color_for(confidence)
	if confidence == Phrases.CONFIDENCE_GUESS then
		return LIGHT_COLOR_GUESS
	end

	return LIGHT_COLOR_CERTAIN
end

local function light_position(ground_position, height)
	return ground_position + Vector3.up() * (height or LIGHT_HEIGHT)
end

local function spawn_light(world, ground_position, color, tuning)
	if not LIGHT_SUPPORT or not world then
		return nil
	end

	local height = tuning and tuning.height or LIGHT_HEIGHT
	local rotation = Quaternion.look(-Vector3.up(), Vector3.forward())
	local ok, unit = pcall(World.spawn_unit_ex, world, Phrases.LIGHT_UNIT, nil, light_position(ground_position, height), rotation)

	if not ok or not unit then
		Log.write("LIGHT spawn FAILED (ok=%s) for unit %s", tostring(ok), Phrases.LIGHT_UNIT)
		return nil
	end

	local fwd = Quaternion.forward(Unit.world_rotation(unit, 1))
	Log.write("LIGHT spawned, unit forward=(%.2f,%.2f,%.2f)", Vector3.x(fwd), Vector3.y(fwd), Vector3.z(fwd))

	local light = Unit.light(unit, 1)

	if light then
		Light.set_enabled(light, true)
		Light.set_casts_shadows(light, false)
		Light.set_spot_reflector(light, true)
		Light.set_intensity(light, tuning and tuning.intensity or LIGHT_INTENSITY)
		Light.set_spot_angle_start(light, LIGHT_SPOT_START)
		Light.set_spot_angle_end(light, tuning and tuning.spot_end_deg and (tuning.spot_end_deg / 180 * math_pi) or LIGHT_SPOT_END)
		Light.set_falloff_start(light, LIGHT_FALLOFF_START)
		Light.set_falloff_end(light, tuning and tuning.falloff_end or LIGHT_FALLOFF_END)
		Light.set_volumetric_intensity(light, tuning and tuning.volumetric or LIGHT_VOLUMETRIC)
		Light.set_color_filter(light, Vector3(color[1], color[2], color[3]))
	end

	return { unit = unit, light = light, world = world, color = color, height = height }
end

local function destroy_light(entry)
	if entry and entry.unit and Unit.alive(entry.unit) then
		World.destroy_unit(entry.world, entry.unit)
	end
end

function Visuals.register_outline()
	mod:hook_require("scripts/settings/outline/outline_settings", function(settings)
		_guess_profile = {
			priority = outline_priority(),
			color = { 1, 0.5, 0 },
			material_layers = {
				"player_outline_knocked_down",
				"player_outline_knocked_down_reversed_depth",
			},
			visibility_check = function(unit)
				return HEALTH_ALIVE[unit]
			end,
		}
		settings.PlayerUnitOutlineExtension[Phrases.OUTLINE_GUESS] = _guess_profile
	end)
end

function Visuals.refresh_outline_priority()
	if _guess_profile then
		_guess_profile.priority = outline_priority()
	end
end

function Visuals.register_marker()
	Marker.register()
end

local function destroy_go(go_id, osys)
	local cog = _cog[go_id]

	if cog then
		destroy_cog_cone(cog.world, cog.ids)
		_cog[go_id] = nil
	end

	local ol = _outline[go_id]

	if ol then
		osys = osys or outline_system()

		if osys and ol.ally_unit and ALIVE[ol.ally_unit] then
			osys:remove_outline(ol.ally_unit, ol.profile)
		end

		_outline[go_id] = nil
	end

	local lt = _light[go_id]

	if lt then
		destroy_light(lt)
		_light[go_id] = nil
	end

	local bm = _beam[go_id]

	if bm then
		if bm.world and bm.id then
			World.destroy_particles(bm.world, bm.id)
		end

		_beam[go_id] = nil
	end

	local mk = _marker[go_id]

	if mk then
		if mk.id then
			Managers.event:trigger("remove_world_marker", mk.id)
		end

		_marker[go_id] = nil
	end
end

function Visuals.start(go_id)
	destroy_go(go_id)
end

function Visuals.clear(go_id)
	destroy_go(go_id)
end

function Visuals.apply(go_id, ally_unit, ground_position, confidence)
	if not ally_unit or not ALIVE[ally_unit] or not ground_position then
		return
	end

	local want_particle = particle_for(confidence)
	local cog = _cog[go_id]

	if cog and cog.particle_name ~= want_particle then
		Log.write("COG swap particle (confidence=%s)", tostring(confidence))
		destroy_cog_cone(cog.world, cog.ids)
		cog, _cog[go_id] = nil, nil
	end

	if not cog then
		local world = Unit.world(ally_unit)

		if world then
			_cog[go_id] = {
				ids = create_cog_cone(world, want_particle, ground_position),
				world = world,
				particle_name = want_particle,
				anchor_unit = ally_unit,
			}
			Log.write("COG cone created (%d rings, confidence=%s)", CONE_LEVELS, tostring(confidence))
		end
	elseif cog.anchor_unit ~= ally_unit then
		move_cog_cone(cog.world, cog.ids, ground_position)
		cog.anchor_unit = ally_unit
		Log.write("COG cone moved (retarget)")
	end

	local osys = outline_system()
	local want_profile = outline_for(confidence)
	local ol = _outline[go_id]

	if not ol then
		if osys then
			osys:add_outline(ally_unit, want_profile)
		end

		_outline[go_id] = { ally_unit = ally_unit, profile = want_profile }
		Log.write("OUTLINE added (profile=%s)", tostring(want_profile))
	elseif ol.ally_unit ~= ally_unit or ol.profile ~= want_profile then
		if osys then
			if ALIVE[ol.ally_unit] then
				osys:remove_outline(ol.ally_unit, ol.profile)
			end

			osys:add_outline(ally_unit, want_profile)
		end

		Log.write("OUTLINE swap (profile=%s)", tostring(want_profile))
		ol.ally_unit, ol.profile = ally_unit, want_profile
	end

	if USE_MARKER and Settings.get("rescue_marker_enabled") then
		local mk = _marker[go_id]

		if not mk then
			local entry = { anchor_unit = ally_unit, confidence = confidence, data = { color = Marker.color_for(confidence) } }
			_marker[go_id] = entry

			Marker.ensure_registered()

			local ok = pcall(Managers.event.trigger, Managers.event, "add_world_marker_unit", Marker.TYPE, ally_unit, function(id)
				entry.id = id
			end, entry.data)

			if ok and entry.id then
				Log.write("MARKER added (confidence=%s)", tostring(confidence))
			else
				Log.write("MARKER add FAILED (ok=%s, template unresolved?)", tostring(ok))
			end
		elseif mk.anchor_unit ~= ally_unit then
			if mk.id then
				Managers.event:trigger("remove_world_marker", mk.id)
			end

			mk.id = nil
			mk.anchor_unit = ally_unit
			mk.confidence = confidence
			mk.data.color = Marker.color_for(confidence)

			Marker.ensure_registered()

			pcall(Managers.event.trigger, Managers.event, "add_world_marker_unit", Marker.TYPE, ally_unit, function(id)
				mk.id = id
			end, mk.data)
			Log.write("MARKER moved (retarget)")
		elseif mk.confidence ~= confidence then
			mk.confidence = confidence
			mk.data.color = Marker.color_for(confidence)
			Log.write("MARKER recolour (confidence=%s)", tostring(confidence))
		end
	end

	if USE_BEAM and Settings.get("rescue_marker_enabled") then
		local bm = _beam[go_id]

		if not bm then
			local world = Unit.world(ally_unit)

			if world then
				local ok, id = pcall(World.create_particles, world, BEAM_PARTICLE, ground_position)

				if ok and id then
					_beam[go_id] = { id = id, world = world, anchor_unit = ally_unit }
					Log.write("BEAM created (%s)", BEAM_PARTICLE)
				else
					Log.write("BEAM create FAILED for %s (bad path?)", BEAM_PARTICLE)
				end
			end
		elseif bm.anchor_unit ~= ally_unit then
			World.move_particles(bm.world, bm.id, ground_position)
			bm.anchor_unit = ally_unit
			Log.write("BEAM moved (retarget)")
		end
	end

	if USE_LIGHT and LIGHT_SUPPORT and Settings.get("rescue_marker_enabled") then
		local want_color = light_color_for(confidence)
		local lt = _light[go_id]

		if not lt then
			lt = spawn_light(Unit.world(ally_unit), ground_position, want_color)

			if lt then
				lt.anchor_unit = ally_unit
				_light[go_id] = lt
			end
		else
			if lt.anchor_unit ~= ally_unit then
				if lt.unit and Unit.alive(lt.unit) then
					Unit.set_local_position(lt.unit, 1, light_position(ground_position))
					World.update_unit(lt.world, lt.unit)
				end

				lt.anchor_unit = ally_unit
				Log.write("LIGHT moved (retarget)")
			end

			if lt.color ~= want_color and lt.light then
				Light.set_color_filter(lt.light, Vector3(want_color[1], want_color[2], want_color[3]))
				lt.color = want_color
				Log.write("LIGHT recolour (confidence=%s)", tostring(confidence))
			end
		end
	end
end

function Visuals.apply_hack(go_id, target_unit, ground_position)
	if not target_unit or not ALIVE[target_unit] or not ground_position then
		return
	end

	local cog = _cog[go_id]

	if not cog then
		local world = Unit.world(target_unit)

		if world then
			local particle_position = ground_position + Vector3.up() * HACK_TUNING.particle_height
			local ok, id = pcall(World.create_particles, world, HACK_PARTICLE, particle_position)

			if ok and id then
				_cog[go_id] = {
					ids = { id },
					world = world,
					particle_name = HACK_PARTICLE,
					anchor_unit = target_unit,
				}
				Log.write("HACK particle created (%s)", HACK_PARTICLE)
			else
				Log.write("HACK particle create FAILED for %s (package not loaded?)", HACK_PARTICLE)
			end
		end
	elseif cog.anchor_unit ~= target_unit then
		move_cog_cone(cog.world, cog.ids, ground_position + Vector3.up() * HACK_TUNING.particle_height)
		cog.anchor_unit = target_unit
	end

	if not Settings.get("hack_marker_enabled") then
		return
	end

	local mk = _marker[go_id]

	if not mk then
		local entry = { anchor_unit = target_unit, data = { color = Marker.hack_color() } }
		_marker[go_id] = entry

		Marker.ensure_registered()

		local ok = pcall(Managers.event.trigger, Managers.event, "add_world_marker_unit", Marker.TYPE_HACK, target_unit, function(id)
			entry.id = id
		end, entry.data)

		Log.write(ok and "HACK marker added" or "HACK marker add FAILED (template not registered?)")
	elseif mk.anchor_unit ~= target_unit then
		if mk.id then
			pcall(Managers.event.trigger, Managers.event, "remove_world_marker", mk.id)
		end

		mk.id = nil
		mk.anchor_unit = target_unit

		Marker.ensure_registered()

		pcall(Managers.event.trigger, Managers.event, "add_world_marker_unit", Marker.TYPE_HACK, target_unit, function(id)
			mk.id = id
		end, mk.data)
	end

	if USE_HACK_LIGHT and LIGHT_SUPPORT then
		local lt = _light[go_id]

		if not lt then
			lt = spawn_light(Unit.world(target_unit), ground_position, HACK_LIGHT_COLOR, HACK_TUNING)

			if lt then
				lt.anchor_unit = target_unit
				_light[go_id] = lt
			end
		elseif lt.anchor_unit ~= target_unit then
			if lt.unit and Unit.alive(lt.unit) then
				Unit.set_local_position(lt.unit, 1, light_position(ground_position, lt.height))
				World.update_unit(lt.world, lt.unit)
			end

			lt.anchor_unit = target_unit
		end
	end
end

function Visuals.stop(go_id, t)
	local cog = _cog[go_id]

	if cog then
		cog.destroy_at = t + Phrases.FADE_SECONDS
	end

	local ol = _outline[go_id]

	if ol then
		ol.fade_end_t = t + Phrases.FADE_SECONDS
	end

	local lt = _light[go_id]

	if lt then
		lt.destroy_at = t + Phrases.FADE_SECONDS
	end

	local bm = _beam[go_id]

	if bm then
		bm.destroy_at = t + Phrases.FADE_SECONDS
	end

	local mk = _marker[go_id]

	if mk then
		mk.destroy_at = t + Phrases.FADE_SECONDS
	end
end

function Visuals.update(t)
	for go_id, cog in pairs(_cog) do
		if cog.destroy_at and t >= cog.destroy_at then
			destroy_cog_cone(cog.world, cog.ids)
			_cog[go_id] = nil
		end
	end

	if next(_outline) then
		local osys = outline_system()

		for go_id, ol in pairs(_outline) do
			if ol.fade_end_t and t >= ol.fade_end_t then
				if osys and ol.ally_unit and ALIVE[ol.ally_unit] then
					osys:remove_outline(ol.ally_unit, ol.profile)
				end

				_outline[go_id] = nil
			end
		end
	end

	for go_id, lt in pairs(_light) do
		if lt.destroy_at and t >= lt.destroy_at then
			destroy_light(lt)
			_light[go_id] = nil
		end
	end

	for go_id, bm in pairs(_beam) do
		if bm.destroy_at and t >= bm.destroy_at then
			if bm.world and bm.id then
				World.destroy_particles(bm.world, bm.id)
			end

			_beam[go_id] = nil
		end
	end

	for go_id, mk in pairs(_marker) do
		if mk.destroy_at and t >= mk.destroy_at then
			if mk.id then
				Managers.event:trigger("remove_world_marker", mk.id)
			end

			_marker[go_id] = nil
		end
	end
end

function Visuals.reset()
	for go_id in pairs(_cog) do
		_cog[go_id] = nil
	end

	for go_id in pairs(_outline) do
		_outline[go_id] = nil
	end

	for go_id in pairs(_light) do
		_light[go_id] = nil
	end

	for go_id in pairs(_beam) do
		_beam[go_id] = nil
	end

	for go_id, mk in pairs(_marker) do
		if mk.id and Managers.event then
			Managers.event:trigger("remove_world_marker", mk.id)
		end

		_marker[go_id] = nil
	end
end

function Visuals.cleanup_all()
	local osys = outline_system()
	local seen = {}

	for go_id in pairs(_cog) do seen[go_id] = true end
	for go_id in pairs(_outline) do seen[go_id] = true end
	for go_id in pairs(_light) do seen[go_id] = true end
	for go_id in pairs(_beam) do seen[go_id] = true end
	for go_id in pairs(_marker) do seen[go_id] = true end

	for go_id in pairs(seen) do
		destroy_go(go_id, osys)
	end
end

return Visuals
