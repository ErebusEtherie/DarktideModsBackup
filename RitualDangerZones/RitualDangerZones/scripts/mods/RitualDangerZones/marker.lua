local mod = get_mod("RitualDangerZones")
local modules = mod:persistent_table("RitualDangerZones_modules")
local Detection = modules.Detection

local Marker = {}

local MARKER_TEMPLATE = mod:io_dofile("RitualDangerZones/scripts/mods/RitualDangerZones/RitualDangerZones_marker")
local MARKER_TYPE = MARKER_TEMPLATE.name -- "ritual_danger_zone"

-- markers_by_unit[unit] = { id = marker_id, data = data_table }
local markers_by_unit = mod:persistent_table("rdz_markers")

-- Apply a couple of settings to the shared template once (clones inherit them at add-time).
local function apply_template_settings()
	local size = mod:get("marker_size")
	if type(size) == "number" then
		MARKER_TEMPLATE.size = { size, size }
	end
	local through_walls = mod:get("marker_through_walls")
	if through_walls == nil then
		through_walls = true
	end
	MARKER_TEMPLATE.check_line_of_sight = not through_walls

	-- F3 Route A: let the base HUD clamp the marker to the screen edge (arrow) when off-screen.
	-- The base HudElementWorldMarkers already handles projection + the behind-camera case.
	local offscreen = mod:get("marker_offscreen")
	if offscreen == nil then
		offscreen = true
	end
	MARKER_TEMPLATE.screen_clamp = offscreen
	MARKER_TEMPLATE.screen_margins = { 0.05, 0.05 }
end

-- Inject our template into the live HudElementWorldMarkers instance. There is no public
-- register-template API, so hook init (once) + update (defensive re-inject) per agent research.
local function ensure_marker_templates(world_markers)
	if not world_markers or not world_markers._marker_templates then
		return
	end
	world_markers._marker_templates[MARKER_TYPE] = MARKER_TEMPLATE
end

-- Single owner of the HudElementWorldMarkers hook for this mod. Also injects the warning template
-- (via the shared module registry) so warning.lua does not hook the same method a second time, which
-- DMF would reject as a rehook. modules.Warning is nil-guarded so the marker still works if warning
-- failed to load.
mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	apply_template_settings()
	ensure_marker_templates(self)
	if modules.Warning then
		modules.Warning.inject(self)
	end
end)

mod:hook(CLASS.HudElementWorldMarkers, "update", function(func, self, ...)
	ensure_marker_templates(self)
	if modules.Warning then
		modules.Warning.inject(self)
	end
	return func(self, ...)
end)

-- Hard guarantee against table.clone(nil). The base _template_by_type clones _marker_templates[type]
-- at marker-add time and throws "bad argument #1 to 'clone'" if our type is missing. Worse, the base
-- _register_marker adds the marker to the list BEFORE the clone, so that throw leaves an orphaned
-- marker with template=nil, which later crashes smart_tagging (_find_marker_by_unit indexes
-- marker.template). Inject the requested custom template right before the base reads it, covering every
-- instance and every HUD re-init regardless of the init/update hook timing. This is the real fix; the
-- init/update injection above is kept for continuous settings re-application.
mod:hook(CLASS.HudElementWorldMarkers, "_template_by_type", function(func, self, marker_type, clone)
	local templates = self._marker_templates
	if templates and not templates[marker_type] then
		if marker_type == MARKER_TYPE then
			apply_template_settings()
			ensure_marker_templates(self)
		elseif modules.Warning and marker_type == modules.Warning.marker_type then
			modules.Warning.inject(self)
		end
	end
	return func(self, marker_type, clone)
end)

local function marker_enabled()
	local v = mod:get("marker_enabled")
	if v == nil then return true end
	return v
end

local function timer_enabled()
	local v = mod:get("timer_enabled")
	if v == nil then return true end
	return v
end

local function distance_enabled()
	local v = mod:get("marker_show_distance")
	if v == nil then return true end
	return v
end

-- Marker icon, user-selectable. "skull" is the difficulty skull the mod has always used and is the
-- default: it is a compact silhouette that stays out of the way. "ritual" is the game's own Heinous
-- Rituals circumstance icon, which reads as native and names the thing being marked, but is a busier
-- shape that takes up noticeably more screen space at the same setting.
--
-- Read per tick and pushed through marker data rather than baked into the template, so switching the
-- setting takes effect on live markers instead of waiting for a HUD re-init.
local MARKER_ICONS = {
	ritual = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals",
	skull  = "content/ui/materials/icons/difficulty/difficulty_skull_uprising",
}

local function marker_icon()
	return MARKER_ICONS[mod:get("marker_icon")] or MARKER_ICONS.skull
end

-- Label text size. The setting has existed since 1.0.0 with a default of 24 but was never read by
-- anything, so it is anchored at its own default rather than used as a raw pixel size: the scale is
-- (setting / 24), and each template multiplies its own base size by it. At the default that
-- reproduces today's sizes exactly (marker 20, warning 28), so turning this from dead to live does
-- not change the look for anyone who never touched it, and the marker stays smaller than the banner
-- instead of both collapsing to one number.
local TEXT_SIZE_ANCHOR = 24

function Marker.text_scale()
	local v = mod:get("timer_text_size")
	if type(v) ~= "number" or v <= 0 then
		return 1
	end
	return v / TEXT_SIZE_ANCHOR
end

-- Exposed because the warning banner uses the SAME icon. The banner replaces this marker while it is
-- up, so a different icon there reads as the marker glitching into something else at the handoff
-- rather than as one thing escalating. Stage is signalled by colour, size and pulse instead.
function Marker.icon()
	return marker_icon()
end

modules.Marker = Marker

-- Position of the local (or currently-observed) player, for distance readout.
local function player_position()
	local players = Managers.player
	local player = players and players.local_player and players:local_player(1)
	local player_unit = player and player.player_unit
	if player_unit and Unit.alive(player_unit) then
		return Detection.get_unit_position(player_unit)
	end
	return nil
end

-- {a, r, g, b} per status (0-255). filling=amber, contested=grey, near_complete=red.
local STATUS_COLOR = {
	filling       = { 255, 235, 180, 40 },
	contested     = { 255, 220, 220, 220 },
	near_complete = { 255, 235, 40, 40 },
	idle          = { 255, 200, 60, 60 },
}
local STATUS_WORD = { contested = "contested", near_complete = "!" }

local function eta_text(eta)
	if not eta then return "" end
	if eta > 60 then return ">60s" end
	if eta < 1 then return "~0s" end
	return string.format("~%ds", math.floor(eta + 0.5))
end

-- Returns (label, color) for the unit's current ritual state. Calls Timer.update once per unit;
-- it is idempotent per tick so Warning.sync sharing it does not double-sample.
local function label_and_color(unit, timer_module)
	local parts = {}

	if distance_enabled() then
		local pp = player_position()
		local rp = Detection.get_unit_position(unit)
		if pp and rp then
			local ok, d = pcall(Vector3.distance, pp, rp)
			if ok and type(d) == "number" then
				parts[#parts + 1] = string.format("%.0fm", d)
			end
		end
	end

	local color = STATUS_COLOR.idle
	if timer_module and timer_enabled() then
		local eta, status = timer_module.update(unit)
		color = STATUS_COLOR[status] or STATUS_COLOR.idle
		local word = STATUS_WORD[status]
		-- Drop the countdown while the warning banner is up for this same daemonhost. Both anchor to
		-- the same unit and stack on screen, and the banner already carries the ETA, so showing it
		-- here too just prints the same number twice. Before 1.3.0 this barely showed, because the
		-- warning only existed within 30m; now it is up for most of a ritual. The marker keeps the
		-- distance and the status word, which the banner does not carry.
		local warning_up = modules.Warning and modules.Warning.is_active and modules.Warning.is_active(unit)
		if not warning_up then
			local et = eta_text(eta)
			if et ~= "" then
				parts[#parts + 1] = et
			end
		end
		if word then
			parts[#parts + 1] = word
		end
	end

	return table.concat(parts, " | "), color
end

function Marker.sync(ritual_units, timer_module)
	if not marker_enabled() then
		Marker.teardown_all()
		return
	end
	if not Managers.event then
		return
	end

	local alive = {}
	for i = 1, #ritual_units do
		local unit = ritual_units[i]
		-- Stand down while the warning banner is up for this daemonhost. Both anchor the same unit,
		-- so they stacked into two icons and two text lines on one target, and off screen into two
		-- edge arrows. The banner carries the distance and status word this marker would have shown,
		-- so nothing is lost. Before 1.3.0 the overlap was rare, because the warning only existed
		-- within 30m; now it is up for most of a ritual and the marker is redundant almost always.
		local warning_up = modules.Warning and modules.Warning.is_active and modules.Warning.is_active(unit)
		if warning_up then
			-- Deliberately NOT added to `alive`: the sweep below then removes any marker this unit
			-- still has, and the same sweep keeps handling units that vanished entirely.
			Marker.teardown(unit)
		else
			alive[unit] = true
			local entry = markers_by_unit[unit]
			if not entry and Detection.get_unit_position(unit) then
				local text, color = label_and_color(unit, timer_module)
				local data = { icon = marker_icon(), text = text, color = color, text_scale = Marker.text_scale() }
				local new_entry = { id = nil, data = data }
				markers_by_unit[unit] = new_entry
				Managers.event:trigger("add_world_marker_unit", MARKER_TYPE, unit, function(marker_id)
					new_entry.id = marker_id
				end, data)
			elseif entry then
				-- Live-update label, colour and icon (template re-reads marker.data every tick).
				local text, color = label_and_color(unit, timer_module)
				entry.data.text = text
				entry.data.color = color
				entry.data.icon = marker_icon()
				entry.data.text_scale = Marker.text_scale()
			end
		end
	end

	for unit in pairs(markers_by_unit) do
		if not alive[unit] then
			Marker.teardown(unit)
		end
	end
end

function Marker.teardown(unit)
	local entry = markers_by_unit[unit]
	if entry and entry.id and Managers.event then
		Managers.event:trigger("remove_world_marker", entry.id)
	end
	markers_by_unit[unit] = nil
end

function Marker.teardown_all()
	for unit in pairs(markers_by_unit) do
		Marker.teardown(unit)
	end
end

return Marker
