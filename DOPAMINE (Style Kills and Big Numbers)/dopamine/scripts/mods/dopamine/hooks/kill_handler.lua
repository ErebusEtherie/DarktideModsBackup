---@type mod
local mod = get_mod("dopamine")

if mod.kill_handler then
	return mod.kill_handler
end

local Unit = Unit
local Vector3 = Vector3

local BreedFatigueRelief = mod:core(mod.breed_fatigue_relief, "utils/breed_fatigue_relief")
local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local HitTrackers = mod:core(mod.hit_trackers, "utils/hit_trackers")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local EventScoring = mod:core(mod.event_scoring, "utils/event/scoring")

local SP_COLOR = mod.constants.COLOR.NUMBERS.GREEN
local SP_COLOR_MAX_FURY = mod.constants.COLOR.NUMBERS.GREEN
local MULT_COLOR = mod.constants.COLOR.NUMBERS.ORANGE
local MULT_COLOR_MAX_FURY = mod.constants.COLOR.NUMBERS.RED

local MARKER_STYLE = "kill"

local function register_marker_style()
	local font_type = mod.dl.fonts.validated("mono_tide_bold")

	local amount_size = mod.dl.settings.marker_font_size

	local mult_size = amount_size * 0.7

	local pop_fade_config = mod.dl.settings.enable_immersive_markers
			and {
				spread_near_distance = 10,
				spread_far_distance = 27.5,
				spread_near = 1.05,
				spread_far = 1.15, 
			}
		or {}

	local scale_far_distance = mod.dl.settings.enable_immersive_markers and 27.5 or 0

	mod.dl_hud.marker.register_style(MARKER_STYLE, {
		font = font_type,
		lifetime = mod.dl.settings.marker_fade_duration,
		max_active = mod.dl.settings.max_active_markers,
		scale_near_distance = 7.5,
		scale_far_distance = scale_far_distance,
		scale_near = 1,
		scale_far = 0.65,
		animate = mod.dl_hud.marker.animate.pop_fade(pop_fade_config),

		z_layer = 2,

		lines = {

			{ id = "amount", font_size = amount_size, color = SP_COLOR },
			{ id = "mult", font_size = mult_size, color = MULT_COLOR },
		},
	})
end

register_marker_style()

local _previous_on_setting_changed = mod.on_setting_changed
function mod.on_setting_changed(...)
	if _previous_on_setting_changed then
		_previous_on_setting_changed(...)
	end
	register_marker_style()
end

local function queue_sp_markers(world_pos, max_fury_mode, sp_awarded, sp_multiplier)
	if not mod.dl.settings.enable_kill_markers or not world_pos then
		return
	end

	local sp_text = EventScoring.format_marker_amount(sp_awarded)
	if sp_text then

		mod.dl_hud.marker.fire(MARKER_STYLE, {
			world_pos = world_pos,
			lines = {
				amount = { text = sp_text, color = max_fury_mode and SP_COLOR_MAX_FURY or nil },
				mult = {
					text = EventScoring.format_marker_multiplier(sp_multiplier),
					color = max_fury_mode and MULT_COLOR_MAX_FURY or nil,
				},
			},
		})
	end
end

local function as_vector3(position)
	if not position then
		return nil
	end

	if position.unbox then
		return position:unbox()
	end

	if position.x and position.y and position.z then
		return position
	end

	return nil
end

---@return number | nil
local function kill_distance_from_player(world_pos, player_unit)
	if not world_pos or not player_unit or not Unit.alive(player_unit) then
		return nil
	end

	local player_pos = Unit.world_position(player_unit, 1)
	local target_pos = as_vector3(world_pos)

	if not target_pos then
		return nil
	end

	return Vector3.distance(target_pos, player_pos)
end

---@param style_event_id EventID
---@param tracker UnitHitTracker
---@param hit_count number
---@param context EventContext
local function on_hit_hook(style_event_id, tracker, hit_count, context)
	if not tracker:qualifies(hit_count) then
		return
	end

	local sp_awarded = EventManager.signal(style_event_id, EventManager.make_hit_context(hit_count, context.breed_data))

	if sp_awarded > 0 then
		local max_fury_mode = ComboState.at_max_fury()
		local sp_multiplier = EventManager.scoring_multiplier()
		queue_sp_markers(context.world_pos, max_fury_mode, sp_awarded, sp_multiplier)
	end
end

HitTrackers.Berserk:on_hit(function(_unit, hit_count, context)
	on_hit_hook(EventEnums.EVENT_ID.berserk, HitTrackers.Berserk, hit_count, context)
end)

HitTrackers.MagDump:on_hit(function(_unit, hit_count, context)
	on_hit_hook(EventEnums.EVENT_ID.mag_dump, HitTrackers.MagDump, hit_count, context)
end)

---@param breed FatsharkBreedData
---@param event DL_HitEvent
local function try_on_hit_event(breed, event)
	if not mod.dl.breeds.is_any(breed, "category.elite", "category.boss") then

		return
	end

	if event.attack_type == "ranged" then
		HitTrackers.MagDump:record_hit(event.attacked_unit, {
			breed = breed,
		})
	elseif event.attack_type == "melee" then
		HitTrackers.Berserk:record_hit(event.attacked_unit, {
			breed = breed,
		})
	end

end

---@param breed_data FatsharkBreedData
---@param event DL_HitEvent
local function on_kill(breed_data, event)
	ComboState.on_kill(event.damage)

	BreedFatigueRelief.apply(breed_data)

	local context = EventManager.make_context({
		hit_weakspot = event.hit_weakspot or false,
		breed_data = breed_data,
		damage = event.damage,
		attack_type = event.attack_type,
		distance = kill_distance_from_player(event.hit_world_position, event.attacking_unit),
	})

	local sp_awarded = EventManager.signal("kill", context)

	local max_fury_mode = ComboState.at_max_fury()
	local sp_multiplier = EventManager.scoring_multiplier()

	queue_sp_markers(event.hit_world_position, max_fury_mode, sp_awarded, sp_multiplier)
end

mod.dl.on_hit.track_stats_for(mod.dl.player.local_player(), { persist = true })

mod.dl.on_hit.execute("controlling player", function(event)
	local breed_data = mod.dl.breeds.data_from_unit(event.attacked_unit)

	if not breed_data or not mod.dl.breeds.is_minion(event.attacked_unit) then
		return
	end

	if event.attack_result == "died" then
		on_kill(breed_data, event)
		HitTrackers.reset_all()
	else
		try_on_hit_event(breed_data, event)
		ComboState.on_hit_enemy(event.damage)
	end
end)

---@class KillHandler
local KillHandler = {}

mod.kill_handler = KillHandler

return KillHandler
