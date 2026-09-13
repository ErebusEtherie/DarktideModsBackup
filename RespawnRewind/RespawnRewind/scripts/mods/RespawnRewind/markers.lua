local mod = get_mod("RespawnRewind")

local Markers = {}

local Beacons = mod:io_dofile("RespawnRewind/scripts/mods/RespawnRewind/beacons")
local MARKER_TEMPLATE = mod:io_dofile("RespawnRewind/scripts/mods/RespawnRewind/RespawnRewind_marker")
local MARKER_TYPE = MARKER_TEMPLATE.name -- "respawn_rewind"

local ACTIVE_COLOR  = { 255, 120, 200, 255 } -- light blue: where the respawn is now
local RUNBACK_COLOR = { 255, 120, 220, 120 } -- green: where to hold back to

-- state.active  = { id, data, unit, pending_remove }
-- state.runback = { id, data, unit, pending_remove } (unit = the prev beacon this run-back point belongs to)
local state = { active = nil, runback = nil }

local function through_walls()
	local v = mod:get("through_walls")
	if v == nil then
		return true
	end
	return v
end

local function apply_template_settings()
	local size = mod:get("marker_size")
	if type(size) == "number" then
		MARKER_TEMPLATE.size = { size, size }
	end
	MARKER_TEMPLATE.check_line_of_sight = not through_walls()
end

local function ensure_marker_templates(world_markers)
	if not world_markers or not world_markers._marker_templates then
		return
	end
	world_markers._marker_templates[MARKER_TYPE] = MARKER_TEMPLATE
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	apply_template_settings()
	ensure_marker_templates(self)
end)

-- Do NOT wrap HudElementWorldMarkers.update to re-inject the template.
--
-- That hook ran every frame and called through to the base update, which walks every world marker the
-- game and every other mod has registered. A profiler timing the handler charges all of that to this
-- mod: reported on the Nexus page as 0.7ms/frame while the mod's own work measures ~25 MICROseconds per
-- refresh. Whether it shows up at all depends on load order, since a monitor can only wrap hooks from
-- mods that load after it, which is why the same setup looks clean on one machine and awful on another.
--
-- Hook the cheap function that actually needs the template instead. _template_by_type is called at
-- marker-add time and clones _marker_templates[type], throwing "bad argument #1 to 'clone'" when the
-- type is missing. Injecting right before the base reads it covers every instance and every HUD
-- re-init, costs nothing per frame, and is a stronger guarantee than the update hook ever was.
mod:hook(CLASS.HudElementWorldMarkers, "_template_by_type", function(func, self, marker_type, clone)
	local templates = self._marker_templates
	if templates and marker_type == MARKER_TYPE and not templates[marker_type] then
		apply_template_settings()
		ensure_marker_templates(self)
	end
	return func(self, marker_type, clone)
end)

-- Icon choices. Every path here is taken from the game's own world-marker templates rather than
-- guessed at, so they exist in the shipped build:
--   assistance  world_marker_template_player_assistance  (the "teammate needs help" icon)
--   location    world_marker_template_location_ping
--   attention   world_marker_template_location_attention
--   objective   world_marker_template_objective
--   resupply    world_marker_template_objective
--   default     world_marker_template_interaction
-- The skull is what the mod has always used and stays the default.
local MARKER_ICONS = {
	skull      = "content/ui/materials/icons/difficulty/difficulty_skull_uprising",
	assistance = "content/ui/materials/hud/icons/player_assistance/player_assistance_icon",
	location   = "content/ui/materials/hud/interactions/icons/location",
	attention  = "content/ui/materials/hud/interactions/icons/attention",
	objective  = "content/ui/materials/hud/interactions/icons/objective_main",
	resupply   = "content/ui/materials/hud/interactions/icons/resupply",
	default    = "content/ui/materials/hud/interactions/icons/default",
}

local function marker_icon()
	local choice = mod:get("marker_icon")
	return MARKER_ICONS[choice] or MARKER_ICONS.skull
end

-- Marker size, read live. The template bakes its size into the widget at add time and the base HUD
-- never resizes this template (it has no scale_settings), so the only way the slider can reach a
-- marker that is already on screen is through marker.data, which the template re-reads every frame.
-- The icon takes the same route. Both used to be read once, at add time: the slider and the dropdown
-- moved, and the markers did not.
local function marker_size()
	local size = mod:get("marker_size")
	if type(size) == "number" then
		return size
	end
	return MARKER_TEMPLATE.size[1]
end

-- Push the current icon and size into a live entry's data. Two table writes per entry per tick; the
-- template only touches the widget when a value actually differs. Callers read the two settings once
-- and pass them in, so a loop over the practice set does not hit mod:get per entry.
local function refresh_appearance(entry, icon, size)
	entry.data.icon = icon
	entry.data.size = size
end

local function new_marker_data(text, colour)
	return { icon = marker_icon(), size = marker_size(), text = text, color = colour }
end

local function distance_enabled()
	local v = mod:get("show_distance")
	if v == nil then
		return true
	end
	return v
end

local function distance_text(target_position)
	if not distance_enabled() or not target_position then
		return nil
	end
	local pp = Beacons.player_position()
	if not pp then
		return nil
	end
	local ok, d = pcall(Vector3.distance, pp, target_position)
	if ok and type(d) == "number" then
		return string.format("%.0fm", d)
	end
	return nil
end

local function label(prefix, target_position)
	local dt = distance_text(target_position)
	if dt then
		return prefix .. " | " .. dt
	end
	return prefix
end

-- The hold-back marker is a threshold, not somewhere to walk to, so its label reports where the team
-- stands against that threshold rather than how far the marker is from your feet.
--
--   past it   -> "Run back | 29m"    the team has to give up 29m for the earlier beacon to win
--   behind it -> "Stay behind | -12m" 12m of room left before that option is lost
--
-- The old label read "Hold back | 29m" in both cases, which is actively misleading when you are
-- already safe: it looks like an instruction to travel 29m when it is really 29m of slack. Reported
-- on the Nexus page by a user who wanted the marker to stay visible with a negative value.
--
-- Falls back to the plain distance label when the offset is unavailable (non-linear path, where there
-- is no main-path line to be in front of or behind).
local function runback_label(model)
	local offset = model and model.runback_offset
	if type(offset) ~= "number" then
		return label("Hold back", model and model.runback_position)
	end
	if not distance_enabled() then
		return (offset > 0) and "Run back" or "Stay behind"
	end
	if offset > 0 then
		return string.format("Run back | %.0fm", offset)
	end
	return string.format("Stay behind | %.0fm", offset)
end

-- pcall-guarded so a dispatch into a tearing-down world/HUD (mission end) can't fault the tick.
local function trigger_event(...)
	if not Managers.event then
		return
	end
	pcall(Managers.event.trigger, Managers.event, ...)
end

local function remove_marker(slot)
	local entry = state[slot]
	if entry then
		if entry.id then
			trigger_event("remove_world_marker", entry.id)
		else
			-- Add-callback hasn't fired yet: flag it so the callback removes the marker once it has an id,
			-- instead of orphaning it (add without a matching remove).
			entry.pending_remove = true
		end
	end
	state[slot] = nil
end

-- Called from the add-marker callback; stores the id, or removes immediately if we were superseded.
local function on_marker_added(entry, marker_id)
	entry.id = marker_id
	if entry.pending_remove then
		trigger_event("remove_world_marker", marker_id)
	end
end

-- The whole respawn layout at once, for learning a map. Off by default.
--
-- Two markers per respawn point: the point itself, anchored to the beacon unit, and the line that
-- governs it, which sits 25m short of it along the route. Both are needed. A line marker on its own
-- reads as "you respawn here" and is wrong by 25m, which is the opposite of what someone studying a
-- map wants to learn.
--
--   "Respawn 3"  the beacon: where you actually come back
--   "3 ends"     the line: cross it going forward and you lose beacon 3 to the next one
--
-- Deliberately NOT gated on somebody being dead. The point is to study the map while you move through
-- it, and a respawn is exactly when you have no attention to spare for memorising anything. Pairs with
-- turning enemy spawns off.
--
-- Placed once. The geometry never moves and position markers cannot be moved after they are added, so
-- the set is never re-placed. Only its icon and size are refreshed each tick: those are settings, and
-- someone tuning them will most likely do it with this set on screen.
local BEACON_PRACTICE_COLOR = { 255, 130, 170, 200 } -- { alpha, r, g, b } muted blue: the place
local LINE_PRACTICE_COLOR   = { 255, 175, 175, 175 } -- grey: the boundary
local practice_slots = 0

local function clear_practice()
	for i = 1, practice_slots do
		remove_marker("practice_beacon_" .. i)
		remove_marker("practice_line_" .. i)
	end
	practice_slots = 0
end

local function add_practice_marker(slot, text, colour, unit, position)
	local data = new_marker_data(text, colour)
	local new_entry = { id = nil, data = data }
	state[slot] = new_entry
	local function added(marker_id)
		on_marker_added(new_entry, marker_id)
	end
	if unit then
		trigger_event("add_world_marker_unit", MARKER_TYPE, unit, added, data)
	else
		local fresh_pos = Vector3(Vector3.x(position), Vector3.y(position), Vector3.z(position))
		trigger_event("add_world_marker_position", MARKER_TYPE, fresh_pos, added, data)
	end
end

local function practice_setting(id, default)
	local value = mod:get(id)
	if value == nil then
		return default
	end
	return value
end

-- Rebuilt whenever the toggles change rather than diffed, because the set's geometry is placed once
-- and then never touched: there is no per-tick path where a cheap diff would pay for itself, and a stale
-- half-set is worse than a rebuild that costs one tick.
local practice_signature = nil

-- Did the HUD actually take the markers we handed it?
--
-- The add event is fire-and-forget: it answers through a callback, and if HudElementWorldMarkers does
-- not exist yet the call simply goes nowhere and no callback ever arrives. That is the normal case
-- here, because this set is placed on the first tick in gameplay while the live markers are only added
-- on a death, long after the HUD is up.
--
-- So "placed" is not the same as "accepted", and treating it as such left twenty marker entries with
-- no ids and nothing on screen for the whole mission. Retry until at least one id comes back.
local function practice_took()
	for i = 1, practice_slots do
		local beacon_entry = state["practice_beacon_" .. i]
		if beacon_entry and beacon_entry.id then
			return true
		end
		local line_entry = state["practice_line_" .. i]
		if line_entry and line_entry.id then
			return true
		end
	end
	return false
end

-- The practice set is placed once and its geometry never changes, but its look can: icon and size
-- are settings, and someone tuning them will most likely do it with this set on screen.
local function refresh_practice_appearance()
	local icon, size = marker_icon(), marker_size()
	for i = 1, practice_slots do
		local beacon_entry = state["practice_beacon_" .. i]
		if beacon_entry then
			refresh_appearance(beacon_entry, icon, size)
		end
		local line_entry = state["practice_line_" .. i]
		if line_entry then
			refresh_appearance(line_entry, icon, size)
		end
	end
end

local function sync_practice()
	if not practice_setting("practice_enabled", false) then
		if practice_slots > 0 then
			clear_practice()
			practice_signature = nil
		end
		return
	end

	local want_beacons = practice_setting("practice_beacons", true)
	local want_lines = practice_setting("practice_lines", true)
	local want_numbers = practice_setting("practice_numbers", true)
	-- The margin is part of the signature because it moves every line. Position markers cannot be moved
	-- once added, so a margin change has to re-place the set; nothing else does.
	local signature = tostring(want_beacons) .. tostring(want_lines) .. tostring(want_numbers) ..
		"|" .. tostring(Beacons.runback_margin())
	if practice_slots > 0 and signature == practice_signature and practice_took() then
		-- Already placed for this mission, with these toggles, and the HUD accepted them.
		refresh_practice_appearance()
		return
	end
	if practice_slots > 0 then
		clear_practice()
	end

	local list = Beacons.practice_points()
	for i = 1, #list do
		local entry = list[i]
		local number = want_numbers and tostring(i) or nil
		if want_beacons and entry.unit and Unit.alive(entry.unit) then
			local text = number and ("Respawn " .. number) or "Respawn"
			add_practice_marker("practice_beacon_" .. i, text, BEACON_PRACTICE_COLOR, entry.unit, nil)
		end
		if want_lines and entry.line_position then
			local text = number and (number .. " ends") or "Line"
			add_practice_marker("practice_line_" .. i, text, LINE_PRACTICE_COLOR, nil, entry.line_position)
		end
	end
	practice_slots = #list
	practice_signature = signature
end

-- Add/refresh the active-beacon marker (anchored to the beacon unit).
local function sync_active(active)
	if not active or not active.unit or not Unit.alive(active.unit) then
		remove_marker("active")
		return
	end
	local text = label("Respawn", active.position)
	local entry = state.active
	if entry and entry.unit == active.unit then
		entry.data.text = text
		entry.data.color = ACTIVE_COLOR
		refresh_appearance(entry, marker_icon(), marker_size())
		return
	end
	remove_marker("active")
	local data = new_marker_data(text, ACTIVE_COLOR)
	local new_entry = { id = nil, data = data, unit = active.unit }
	state.active = new_entry
	trigger_event("add_world_marker_unit", MARKER_TYPE, active.unit, function(marker_id)
		on_marker_added(new_entry, marker_id)
	end, data)
end

-- Add/refresh the run-back marker (a fixed main-path position). Keyed by the target (prev) beacon AND
-- by where along the path the line sits, so it re-adds whenever either changes (position markers box
-- their position at add-time and cannot be moved); otherwise just refresh the label.
--
-- The line distance has to be part of the key or the safety margin is invisible: it moves the line
-- without changing which beacon the line belongs to, so keying on the beacon alone kept the marker
-- sitting at the old spot with only its label changing. Compared with a tolerance because the margin
-- moves in whole metres and float noise must never cause a re-add, which would flicker every tick.
local LINE_MOVED_EPSILON = 0.5

local function line_moved(a, b)
	if type(a) ~= "number" or type(b) ~= "number" then
		return a ~= b
	end
	return math.abs(a - b) >= LINE_MOVED_EPSILON
end

local function sync_runback(model)
	local show = mod:get("show_runback")
	if show == nil then
		show = true
	end
	local pos = show and model.runback_position or nil
	local key_unit = show and model.runback_beacon_unit or nil
	if not pos or not key_unit then
		remove_marker("runback")
		return
	end
	local text = runback_label(model)
	local line_distance = model.runback_line_distance
	local entry = state.runback
	if entry and entry.unit == key_unit and not line_moved(entry.line_distance, line_distance) then
		entry.data.text = text
		entry.data.color = RUNBACK_COLOR
		refresh_appearance(entry, marker_icon(), marker_size())
		return
	end
	remove_marker("runback")
	local fresh_pos = Vector3(Vector3.x(pos), Vector3.y(pos), Vector3.z(pos))
	local data = new_marker_data(text, RUNBACK_COLOR)
	local new_entry = { id = nil, data = data, unit = key_unit, line_distance = line_distance }
	state.runback = new_entry
	trigger_event("add_world_marker_position", MARKER_TYPE, fresh_pos, function(marker_id)
		on_marker_added(new_entry, marker_id)
	end, data)
end

function Markers.sync(model)
	if not Managers.event then
		return
	end
	if not model or not model.active then
		Markers.teardown_all()
		return
	end
	sync_active(model.active)
	sync_runback(model)
end

function Markers.sync_practice()
	sync_practice()
end

-- Markers already on screen pick the new size and icon up through their data on the next tick, and a
-- marker added later is sized by on_enter before its first draw, so neither depends on this. It keeps
-- the shared template current anyway: that is what every new marker is cloned from, and the template
-- is the only place the through-walls flag lives.
function Markers.on_setting_changed()
	apply_template_settings()
end

-- How many marker slots the practice set is actually holding, and how many have a live marker id back
-- from the HUD. Slots without an id mean the add event never completed.
function Markers.practice_state()
	local placed, with_id = 0, 0
	for i = 1, practice_slots do
		for _, prefix in ipairs({ "practice_beacon_", "practice_line_" }) do
			local entry = state[prefix .. i]
			if entry then
				placed = placed + 1
				if entry.id then
					with_id = with_id + 1
				end
			end
		end
	end
	return practice_slots, placed, with_id
end

-- The two live markers only. This is what the respawn-episode path calls, which is most ticks: the
-- practice markers are not part of an episode and must survive it, or they get placed and wiped on
-- the same tick and never appear at all.
function Markers.teardown_live()
	remove_marker("active")
	remove_marker("runback")
end

-- Everything, practice markers included. Only for leaving gameplay or switching the mod off.
function Markers.teardown_all()
	clear_practice()
	Markers.teardown_live()
end

return Markers
