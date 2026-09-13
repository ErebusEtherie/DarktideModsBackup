local mod = get_mod("RitualDangerZones")
local modules = mod:persistent_table("RitualDangerZones_modules")
local Detection = modules.Detection

local Warning = {}

local WARNING_TEMPLATE = mod:io_dofile("RitualDangerZones/scripts/mods/RitualDangerZones/RitualDangerZones_warning")
local WARNING_TYPE = WARNING_TEMPLATE.name -- "ritual_danger_warning"

local warnings_by_unit = mod:persistent_table("rdz_warnings")

-- Stage colours, { alpha, r, g, b }. approach and ticking share amber; speedup is red.
local STAGE_COLOR = {
	approach = { 255, 255, 180, 40 }, -- amber
	ticking  = { 255, 255, 180, 40 }, -- amber
	speedup  = { 255, 255, 50, 40 },  -- red
}

-- Stage ranking, so a stage can only ever escalate. The game latches both of its states (nothing
-- clears scratchpad.speed, and activated stops the check once full speed is reached), so backing
-- off never un-triggers a ritual and the warning must not pretend otherwise.
local STAGE_RANK = { approach = 1, ticking = 2, speedup = 3 }

-- How far before the first tripwire the approach warning appears, in path metres. Hardcoded on
-- purpose, same policy as the refresh interval: it is a tuning constant, not a user knob.
local APPROACH_LEAD = 10

-- Euclidean fallback radii, used only when the main path is unavailable. These are the 1.2.0
-- values and the model they describe is wrong (the game never measures euclidean distance), but a
-- wrong warning beats no warning if some mission has no registered main path.
local FALLBACK_START = 30
local FALLBACK_SPEEDUP = 15

local function setting(id, default)
	local v = mod:get(id)
	if v == nil then return default end
	return v
end

local function warning_size()
	local s = mod:get("warning_size")
	return (type(s) == "number") and s or 128
end

-- Banner text colour from the warning_text_color RGBA settings (0-100 each), returned as the
-- template's { alpha, r, g, b } in 0-255. Defaults to white when a channel is unset.
local function warning_text_color()
	local function channel(suffix)
		local v = mod:get("warning_text_color_" .. suffix)
		v = (type(v) == "number") and v or 100
		return math.floor(v * 2.55 + 0.5)
	end
	return { channel("a"), channel("r"), channel("g"), channel("b") }
end

local function apply_template_settings()
	local size = mod:get("warning_size")
	if type(size) == "number" then
		WARNING_TEMPLATE.size = { size, size }
	end
	WARNING_TEMPLATE.screen_clamp = setting("warning_directional", true)
end

local function ensure_templates(world_markers)
	if not world_markers or not world_markers._marker_templates then
		return
	end
	world_markers._marker_templates[WARNING_TYPE] = WARNING_TEMPLATE
end

-- Do NOT hook HudElementWorldMarkers here. marker.lua already hooks its init and update, and DMF
-- rejects a second hook of the same method from the same mod ("Attempting to rehook active hook"),
-- which would silently drop this template injection. marker.lua's single hook calls Warning.inject
-- to register this template alongside its own.
function Warning.inject(world_markers)
	apply_template_settings()
	ensure_templates(world_markers)
end

Warning.marker_type = WARNING_TYPE
modules.Warning = Warning

local function player_position()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local unit = player and player.player_unit
	if unit and Unit.alive(unit) then
		return Detection.get_unit_position(unit)
	end
	return nil
end

local function player_distance(unit)
	local pp = player_position()
	local rp = Detection.get_unit_position(unit)
	if not (pp and rp) then
		return nil
	end
	local ok, d = pcall(Vector3.distance, pp, rp)
	if ok and type(d) == "number" then
		return d
	end
	return nil
end

-- The game's real check, reproduced client-side. Returns (stage, path_usable).
--
-- The comparison is the team's FURTHEST-AHEAD player against the two tripwire path distances, not
-- the local player's distance to the ritual. That is why this can fire while you are personally
-- nowhere near the daemonhost: a teammate ahead of you trips the wire, and the ritual ticks for
-- everyone.
--
-- The two return values answer different questions and must NOT be collapsed into one:
--   stage       = the stage this tick's query produced, or nil for "no new information".
--   path_usable = whether the main path itself is usable at all.
-- Only path_usable false (no path model, or nothing registered) may send the caller to the
-- euclidean fallback. A per-unit query that came back nil on this tick returns path_usable TRUE
-- with a nil stage, meaning "hold whatever the stage latch already has".
--
-- Conflating those two is the trap. The fallback measures straight-line distance, which the game
-- never uses, and the latch never downgrades. One transient nil while you stand next to an
-- untriggered daemonhost whose path projection is far ahead of the team would pin a red
-- RITUAL SPEEDING UP banner for the rest of the mission.
local function path_stage(unit, path_model)
	if not path_model or not path_model.available() then
		return nil, false
	end
	-- The game tests this FIRST and returns before any distance math, so no ritual ticks while the
	-- team is still in the spawn area. Returning (nil, true) means "no stage, and the path is fine",
	-- so this does not fall through to the euclidean model. The flag clears as soon as the team
	-- aggros anything, so it only covers the opening window.
	if path_model.in_safe_zone and path_model.in_safe_zone() then
		return nil, true
	end
	local wires = path_model.wires(unit)
	local ahead = path_model.ahead_distance()
	if not wires or not ahead then
		return nil, true
	end
	if ahead > wires.close then
		return "speedup", true
	end
	if ahead > wires.far then
		return "ticking", true
	end
	if wires.far - ahead <= APPROACH_LEAD then
		return "approach", true
	end
	return nil, true
end

-- Pre-1.3.0 behaviour, kept only for missions with no registered main path.
local function euclidean_stage(unit)
	local dist = player_distance(unit)
	if not dist or dist > FALLBACK_START then
		return nil
	end
	return (dist <= FALLBACK_SPEEDUP) and "speedup" or "ticking"
end

local function eta_text(eta)
	if not eta then return "" end
	if eta < 1 then return "0s" end
	if eta > 60 then return ">60s" end
	return string.format("%ds", math.floor(eta + 0.5))
end

local STAGE_HEAD = {
	approach = "RITUAL AHEAD",
	ticking  = "RITUAL TICKING",
	speedup  = "RITUAL SPEEDING UP",
}

-- The banner shows the same icon as the locator marker, because it REPLACES that marker while it is
-- up. A different icon at the handoff looks like the marker glitching into something else instead of
-- one thing escalating. The stage still reads through colour, size and pulse.
local function banner_icon()
	local marker = modules.Marker
	if marker and marker.icon then
		return marker.icon()
	end
	return nil
end

-- Same label scale as the marker, from the shared helper, so one setting drives both.
local function text_scale()
	local marker = modules.Marker
	if marker and marker.text_scale then
		return marker.text_scale()
	end
	return 1
end

local STATUS_WORD = { contested = "contested", near_complete = "!" }

-- The banner is the only thing drawn for a ritual while it is up: marker.lua stands down whenever
-- Warning.is_active, because both anchor the same daemonhost and stacking them put two icons and two
-- text lines on one target. So this label carries everything the marker used to: stage, distance,
-- countdown, and the contested / near-complete status word.
local function label_for(unit, timer_module, stage)
	local parts = { STAGE_HEAD[stage] or STAGE_HEAD.ticking }

	-- Reuses the marker's own distance toggle, since this replaces the marker's readout.
	if setting("marker_show_distance", true) then
		local dist = player_distance(unit)
		if dist then
			parts[#parts + 1] = string.format("%.0fm", dist)
		end
	end

	-- No ETA on approach: nothing has tripped yet, so there is no fill rate to extrapolate from
	-- and any number shown would be invented.
	if stage ~= "approach" and timer_module then
		local eta, status = timer_module.update(unit)
		if setting("warning_show_eta", true) then
			local et = eta_text(eta)
			if et ~= "" then
				parts[#parts + 1] = et
			end
		end
		local word = STATUS_WORD[status]
		if word then
			parts[#parts + 1] = word
		end
	end

	return table.concat(parts, " | ")
end

function Warning.sync(ritual_units, timer_module, path_model)
	if not setting("warning_enabled", true) or not Managers.event then
		Warning.teardown_all()
		return
	end

	local alive = {}
	for i = 1, #ritual_units do
		local unit = ritual_units[i]
		local stage, path_ok = path_stage(unit, path_model)
		if not path_ok then
			stage = euclidean_stage(unit)
		end

		-- Sample the timer unconditionally, every stage, before consulting has_progressed below.
		-- has_progressed only knows about a tick if Timer.update(unit) has been called for it, and
		-- nothing else guarantees that: marker.lua only samples when its own marker and timer
		-- settings are both on, and label_for below only samples outside the approach stage. Do not
		-- make this conditional again. Approach is exactly the stage where geometry has not tripped
		-- yet, which makes the cultist-damage trigger the only thing that could be advancing the
		-- ritual, so this is the one case the override exists to catch. Timer.update is idempotent
		-- within a tick, so sampling here is free when the marker already sampled this frame.
		if timer_module and timer_module.update then
			timer_module.update(unit)
		end

		-- Ground-truth override. The stage above is a prediction from path geometry, and it misses
		-- the cultist-damage trigger entirely (damaging a chanting cultist below 95% health sends
		-- the ritual to full speed with no wire crossing). If the fill has measurably advanced,
		-- the ritual is ticking whatever the geometry says.
		if timer_module and timer_module.has_progressed and timer_module.has_progressed(unit) then
			if not stage or STAGE_RANK[stage] < STAGE_RANK.ticking then
				stage = "ticking"
			end
		end

		local entry = warnings_by_unit[unit]

		-- Latch: never downgrade. Matches the game, where nothing clears the ritual's speed state.
		if entry and entry.data.stage then
			local current = STAGE_RANK[entry.data.stage] or 0
			if not stage or (STAGE_RANK[stage] or 0) < current then
				stage = entry.data.stage
			end
		end

		if stage then
			alive[unit] = true
			local color = STAGE_COLOR[stage] or STAGE_COLOR.ticking
			local text = label_for(unit, timer_module, stage)
			-- Only CREATE for a unit with a readable position, mirroring Marker.sync's guard. Before
			-- 1.3.0 this was implicit: the euclidean distance check returned nil without a position,
			-- so no stage meant no marker. The has_progressed override broke that, because it sets a
			-- stage from health-extension state alone. This mod already shipped a hard crash where a
			-- world marker left in a bad state took down the game's smart-tagging system
			-- (_find_marker_by_unit indexes marker.template), so do not remove this guard. The UPDATE
			-- path below is deliberately NOT gated: an existing marker keeps its live text.
			if not entry then
				if Detection.get_unit_position(unit) then
					local data = {
						text = text, color = color, stage = stage,
						size = warning_size(), text_color = warning_text_color(), icon = banner_icon(),
						text_scale = text_scale(),
					}
					local new_entry = { id = nil, data = data }
					warnings_by_unit[unit] = new_entry
					Managers.event:trigger("add_world_marker_unit", WARNING_TYPE, unit, function(marker_id)
						new_entry.id = marker_id
					end, data)
				end
			else
				entry.data.text = text
				entry.data.color = color
				entry.data.stage = stage
				entry.data.text_color = warning_text_color()
				entry.data.size = warning_size()
				entry.data.icon = banner_icon()
				entry.data.text_scale = text_scale()
			end
		end
	end

	for unit in pairs(warnings_by_unit) do
		if not alive[unit] then
			Warning.teardown(unit)
		end
	end
end

-- Is a warning banner currently on screen for this unit? marker.lua asks so it can drop its own ETA
-- and avoid printing the same countdown twice on one daemonhost.
function Warning.is_active(unit)
	return warnings_by_unit[unit] ~= nil
end

-- Diagnostic: the banner's current stage, and which of the three inputs produced it. The banner and
-- the tripwires can disagree, and each cause needs a different fix, so report them apart:
--   geometry = the path comparison put it here. If that looks wrong, `ahead` is wrong.
--   progress = the daemonhost's observed fill raised it, no wire crossing needed. Either a cultist
--              took damage (real, and the wires cannot show it) or the health reading is noisy.
--   fallback = the euclidean path ran, meaning the main path was unavailable this tick.
function Warning.debug(unit, path_model, timer_module)
	local entry = warnings_by_unit[unit]
	local geometric, path_ok = path_stage(unit, path_model)
	local progressed = timer_module and timer_module.has_progressed and timer_module.has_progressed(unit)
	return {
		shown = entry and entry.data.stage or "none",
		geometric = geometric or "none",
		source = (not path_ok and "fallback")
			or (geometric and "geometry")
			or (progressed and "progress")
			or "none",
		progressed = progressed and true or false,
	}
end

function Warning.teardown(unit)
	local entry = warnings_by_unit[unit]
	if entry and entry.id and Managers.event then
		Managers.event:trigger("remove_world_marker", entry.id)
	end
	warnings_by_unit[unit] = nil
end

function Warning.teardown_all()
	for unit in pairs(warnings_by_unit) do
		Warning.teardown(unit)
	end
end

return Warning
