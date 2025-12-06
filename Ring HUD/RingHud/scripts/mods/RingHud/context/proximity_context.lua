-- File: RingHud/scripts/mods/RingHud/context/proximity_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ProximitySystem = {}

-------------------------------------------------------------------------------
-- System State & Constants
-------------------------------------------------------------------------------

-- Which pickup/deployable names we track.
-- NOTE: We track-by-unit for ALL of these; we only create a RingHud marker
-- for "medical_crate_deployable" because vanilla does not provide one.
mod._item_configs = mod._item_configs or {
    -- Syringes / pocketables (tracked via vanilla interaction marker path)
    { name = "syringe_corruption_pocketable" },
    { name = "syringe_power_boost_pocketable" },
    { name = "syringe_speed_boost_pocketable" },
    { name = "syringe_ability_boost_pocketable" },

    -- Ammo
    { name = "small_clip" },
    { name = "large_clip" },
    { name = "ammo_cache_pocketable" },
    { name = "ammo_cache_deployable" }, -- tagged via interaction marker

    -- Healing
    { name = "medical_crate_pocketable" },
    { name = "medical_crate_deployable" }, -- the ONLY thing we (may) mark
    { name = "health_station" },

    -- Scriptures
    { name = "tome_pocketable" },
    { name = "grimoire_pocketable" },
}

-- Proximity flags exported to the rest of the mod.
mod._proximity_types = mod._proximity_types or {
    small_clip                       = "near_small_clip",
    large_clip                       = "near_large_clip",
    ammo_cache_deployable            = "near_ammo_cache_deployable",
    syringe_corruption_pocketable    = "near_syringe_corruption_pocketable",
    syringe_power_boost_pocketable   = "near_syringe_power_boost_pocketable",
    syringe_speed_boost_pocketable   = "near_syringe_speed_boost_pocketable",
    syringe_ability_boost_pocketable = "near_syringe_ability_boost_pocketable",
    medical_crate_deployable         = "near_medical_crate_deployable",
    health_station                   = "near_health_station",
    medical_crate_pocketable         = "near_medical_crate_pocketable",
    ammo_cache_pocketable            = "near_ammo_cache_pocketable",
    tome_pocketable                  = "near_tome_pocketable",
    grimoire_pocketable              = "near_grimoire_pocketable",
}
for _, varname in pairs(mod._proximity_types) do
    if mod[varname] == nil then
        mod[varname] = false
    end
end

-- Timers / queues
mod._next_proximity_scan_time              = mod._next_proximity_scan_time or 0
mod._PROXIMITY_SCAN_INTERVAL               = mod._PROXIMITY_SCAN_INTERVAL or 0.5
mod._deferred_marker_additions             = mod._deferred_marker_additions or {}

-- Pending queue to give other mods first dibs on med-crate markers
mod._pending_medcrate_markers              = mod._pending_medcrate_markers or
    {} -- unit -> { t_added=..., name="medical_crate_deployable" }
local ADD_MARKER_GRACE_S                   = 0.25

-- Marker template & persistent tracking table
local RingHudItemTrackerMarker             = mod:io_dofile("RingHud/scripts/mods/RingHud/context/RingHud_marker")
mod._tracked_item_units                    = mod._tracked_item_units or mod:persistent_table("tracked_item_units")

-- Guards for once-only wiring
local are_ringhud_unit_template_hooks_done = false

-- Known external template names
local MARKERS_AIO_MED_TEMPLATE_NAME        =
"med_marker" -- markers_aio medical-crate template name.

-------------------------------------------------------------------------------
-- Private Helper Functions
-------------------------------------------------------------------------------

local function _get_pickup_name(unit)
    return unit and Unit.get_data(unit, "pickup_type")
end

local function _is_tracked_item_type(name)
    if not name then return false end
    for i = 1, #mod._item_configs do
        if mod._item_configs[i].name == name then
            return true
        end
    end
    return false
end

local function _is_notified(unit) return Unit.get_data(unit, "rh_notified") end
local function _set_notified(unit, val) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_notified", val) end end
local function _set_collected(unit, val) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_collected", val) end end
local function _set_last_t(unit, t) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_last_t", t) end end
local function _can_repeat(unit, t)
    local lt = Unit.get_data(unit, "rh_last_t"); return not lt or lt + 1 < t
end

local function _is_being_tracked_by_rh(unit)
    return unit and Unit.get_data(unit, "rh_tracking")
end

local function _set_rh_tracking_status(unit, val)
    if unit and Unit.alive(unit) then
        Unit.set_data(unit, "rh_tracking", val)
    end
end

-- Live HudElementWorldMarkers
local function _hewm()
    local hud = Managers.ui and Managers.ui._hud
    return hud and hud:element("HudElementWorldMarkers") or nil
end

-- Best-effort retrieve a marker object for a unit (varies across game builds/mods)
local function _get_marker_for_unit(unit)
    local hewm = _hewm()
    if not hewm or not unit then return nil end
    local by_unit = hewm._markers_by_unit or hewm._markers or hewm._active_markers
    if type(by_unit) ~= "table" then return nil end

    local got = by_unit[unit]
    -- Sometimes it’s a single marker; sometimes a list; handle both.
    if got and got.unit then
        return got
    elseif type(got) == "table" then
        for _, maybe in pairs(got) do
            if maybe and maybe.unit == unit then
                return maybe
            end
        end
    end
    return nil
end

-- Does ANY marker exist for this unit?
local function _unit_has_any_marker(unit)
    return _get_marker_for_unit(unit) ~= nil
end

-- Is the unit marked specifically by markers_aio's med-crate template?
local function _unit_has_markers_aio_medcrate_marker(unit)
    local m = _get_marker_for_unit(unit)
    if not m then return false end
    local tmpl = m.template or (m.data and m.data.template) or {}
    local name = tmpl.name or m.name
    if name == MARKERS_AIO_MED_TEMPLATE_NAME then
        return true
    end
    -- Secondary heuristic: markers_aio sets template.data.type = "medical_crate_deployable".
    local data = m.data
    if data and data.type == "medical_crate_deployable" then
        -- Avoid misclassifying RingHud's invisible tracker:
        if name ~= RingHudItemTrackerMarker.name then
            return true
        end
    end
    return false
end

-- Ensure our (invisible) item tracker template exists in HEWM (used only for med crate deployable).
local function _ensure_item_template()
    local hewm = _hewm()
    if not hewm or not hewm._marker_templates then return false end
    if not hewm._marker_templates[RingHudItemTrackerMarker.name] then
        hewm._marker_templates[RingHudItemTrackerMarker.name] = RingHudItemTrackerMarker
    end
    return true
end

-- Add our invisible marker if needed (currently for medical_crate_deployable only).
local function _add_marker(unit, data_for_marker)
    if not unit or not Unit.alive(unit) then return end
    -- NEVER place if markers_aio already marked this med crate.
    if _unit_has_markers_aio_medcrate_marker(unit) then
        return
    end
    -- Also skip if any other marker has claimed it (compat).
    if _unit_has_any_marker(unit) then
        return
    end
    if not _ensure_item_template() then
        mod._deferred_marker_additions[unit] = data_for_marker
        return
    end
    Managers.event:trigger("add_world_marker_unit", RingHudItemTrackerMarker.name, unit, nil, nil, data_for_marker)
end

-- Unit-template spawn hooks (deployables that may lack a vanilla marker path).
local function _handle_deployable_spawn(unit, deployable_name)
    if not unit or not Unit.alive(unit) then return end
    if Unit.get_data(unit, "rh_processed_spawn_" .. deployable_name) then return end
    if not _is_tracked_item_type(deployable_name) then return end

    _set_rh_tracking_status(unit, true)
    Unit.set_data(unit, "rh_processed_spawn_" .. deployable_name, true)
    Unit.set_data(unit, "rh_marker_type", deployable_name) -- fallback if pickup_type is missing
    mod._tracked_item_units[unit] = unit

    -- Only "medical_crate_deployable" may get a RingHud marker.
    if deployable_name == "medical_crate_deployable" then
        -- Defer with a grace window to allow other mods (e.g. markers_aio) to attach their marker first
        local now = (Managers.time and Managers.time:time("main")) or 0
        mod._pending_medcrate_markers[unit] = { t_added = now, name = deployable_name }
    end
end

-- Adopt any existing markers_aio medical-crate markers we see (ensures tracking even if spawn hook missed).
local function _adopt_external_medcrate_markers()
    local hewm = _hewm()
    if not hewm then return end
    local by_unit = hewm._markers_by_unit or hewm._markers or hewm._active_markers
    if type(by_unit) ~= "table" then return end

    for unit, marker_or_list in pairs(by_unit) do
        if unit and Unit.alive(unit) then
            local m = _get_marker_for_unit(unit)
            if m and _unit_has_markers_aio_medcrate_marker(unit) then
                _set_rh_tracking_status(unit, true)
                Unit.set_data(unit, "rh_marker_type", "medical_crate_deployable")
                mod._tracked_item_units[unit] = unit
            end
        end
    end
end

-- Combined proximity predicates (no settings logic here)
local function _near_stimm_source_now()
    return (mod.near_syringe_corruption_pocketable == true)
        or (mod.near_syringe_power_boost_pocketable == true)
        or (mod.near_syringe_speed_boost_pocketable == true)
        or (mod.near_syringe_ability_boost_pocketable == true)
        or (mod.near_health_station == true)
end

local function _near_crate_source_now()
    return (mod.near_medical_crate_pocketable == true)
        or (mod.near_medical_crate_deployable == true)
        or (mod.near_ammo_cache_pocketable == true)
        or (mod.near_ammo_cache_deployable == true)
end

-------------------------------------------------------------------------------
-- Public System Functions
-------------------------------------------------------------------------------

function ProximitySystem.init()
    -- When a vanilla interaction marker spawns, we TAG & TRACK the unit (no RingHud marker).
    -- Syringes are already handled in a similar tag-only style; keep that behavior.
    mod:hook_safe(CLASS.HudElementInteraction, "_on_interaction_marker_spawned",
        function(self_hud_interaction, unit)
            if not unit or not Unit.alive(unit) then return end

            local pickup_name_from_unit_data = Unit.get_data(unit, "pickup_type")
            if pickup_name_from_unit_data == "syringe_corruption_pocketable"
                or pickup_name_from_unit_data == "syringe_ability_boost_pocketable"
                or pickup_name_from_unit_data == "syringe_power_boost_pocketable"
                or pickup_name_from_unit_data == "syringe_speed_boost_pocketable"
            then
                -- Syringes: tag-only (SPI/other mods can style the visible vanilla marker).
                _set_rh_tracking_status(unit, true)
                mod._tracked_item_units[unit] = unit
                return
            end

            local identified_item_name = pickup_name_from_unit_data

            -- If no pickup_type but it's a health station interactable, tag it.
            if not identified_item_name and ScriptUnit.has_extension(unit, "interactee_system") then
                local interactee_extension = ScriptUnit.extension(unit, "interactee_system")
                if interactee_extension and interactee_extension:interaction_type() == "health_station" then
                    identified_item_name = "health_station"
                end
            end

            -- ammo_cache_deployable is now discovered via this interaction-marker path.
            if identified_item_name and _is_tracked_item_type(identified_item_name) then
                -- Tag & track ONLY (no RingHud marker) for:
                -- small_clip, large_clip, ammo_cache_pocketable, ammo_cache_deployable,
                -- medical_crate_pocketable, health_station, tome_pocketable, grimoire_pocketable
                _set_rh_tracking_status(unit, true)
                mod._tracked_item_units[unit] = unit
            end
        end
    )

    -- NEW: Track health stations via InteracteeExtension regardless of UI interaction state.
    -- This ensures they are detected even when the local player is full health.
    if CLASS.InteracteeExtension then
        mod:hook_safe(CLASS.InteracteeExtension, "init", function(self, extension_init_context, unit, ...)
            if self.interaction_type and self:interaction_type() == "health_station" then
                mod._tracked_item_units[unit] = unit
            end
        end)
    end

    -- Let our template’s update function prune dead units and state.
    mod:hook_safe(RingHudItemTrackerMarker, "update_function",
        function(_, _, widget, marker, self_template, dt, t)
            local unit = marker and marker.unit
            if not unit or not Unit.alive(unit) then
                if unit and mod._tracked_item_units[unit] then
                    mod._tracked_item_units[unit] = nil
                end
                return
            end

            if ScriptUnit.has_extension(unit, "pickup_system") then
                local ps = ScriptUnit.extension(unit, "pickup_system")
                if ps and ps._picked_up then
                    _set_collected(unit, true)
                end
            end

            if _can_repeat(unit, t) then
                _set_last_t(unit, t)
            end
        end
    )

    -- Expose compat shims so other modules can call mod.near_* as functions.
    mod.near_stimm_source = function() return ProximitySystem.near_stimm_source() end
    mod.near_crate_source = function() return ProximitySystem.near_crate_source() end
end

function ProximitySystem.update(dt)
    -- Try any deferred marker additions (template not ready yet).
    if next(mod._deferred_marker_additions) ~= nil then
        local snapshot = mod._deferred_marker_additions
        mod._deferred_marker_additions = {}
        for unit, payload in pairs(snapshot) do
            if unit and Unit.alive(unit) then
                _add_marker(unit, payload)
            end
        end
    end

    -- Process the grace window for medical_crate_deployable pending markers.
    do
        local now = (Managers.time and Managers.time:time("main")) or 0
        for unit, info in pairs(mod._pending_medcrate_markers) do
            if (not unit) or (not Unit.alive(unit)) then
                mod._pending_medcrate_markers[unit] = nil
            elseif (now - (info.t_added or 0)) >= ADD_MARKER_GRACE_S then
                -- Prefer markers_aio’s med marker if present; otherwise, add our invisible tracker.
                if not _unit_has_markers_aio_medcrate_marker(unit) and not _unit_has_any_marker(unit) then
                    _add_marker(unit, { rh_pickup_name = info.name or "medical_crate_deployable" })
                end
                mod._pending_medcrate_markers[unit] = nil
            end
        end
    end

    -- Periodic proximity scan cadence
    local t_now = (mod._ringhud_accumulated_time or 0) + (dt or 0)
    mod._ringhud_accumulated_time = t_now

    if t_now < (mod._next_proximity_scan_time or 0) then
        return
    end
    mod._next_proximity_scan_time = t_now + (mod._PROXIMITY_SCAN_INTERVAL or 0.5)

    -- Adopt any late-arriving external med-crate markers (e.g. markers_aio).
    _adopt_external_medcrate_markers()

    -- Reset flags
    -- MOVED UP: Ensure we clear flags before potentially returning early due to game mode.
    for _, flag_name in pairs(mod._proximity_types) do
        mod[flag_name] = false
    end

    -- Only run in missions / range
    local gm = Managers.state and Managers.state.game_mode
    local gm_name = gm and gm:game_mode_name() or "unknown"
    if gm_name ~= "coop_complete_objective" and gm_name ~= "shooting_range" then
        return
    end

    -- Player position
    local lp = Managers.player and Managers.player:local_player_safe(1)
    local player_unit = lp and lp.player_unit
    local player_pos = (player_unit and Unit.alive(player_unit)) and Unit.world_position(player_unit, 1) or nil
    if not player_pos then return end

    local range = tonumber(mod._settings.trigger_detection_range) or 0
    if range <= 0 then return end
    local range_sq = range * range

    -- Walk tracked units and set near_* flags
    for unit in pairs(mod._tracked_item_units) do
        if unit and Unit.alive(unit) then
            local pickup_name = Unit.get_data(unit, "pickup_type") or Unit.get_data(unit, "rh_marker_type")
            if not pickup_name and ScriptUnit.has_extension(unit, "interactee_system") then
                local iext = ScriptUnit.extension(unit, "interactee_system")
                if iext and iext:interaction_type() == "health_station" then
                    pickup_name = "health_station"
                end
            end

            if pickup_name and _is_tracked_item_type(pickup_name) then
                local upos = Unit.world_position(unit, 1)
                local dx = upos.x - player_pos.x
                local dy = upos.y - player_pos.y
                local dz = upos.z - player_pos.z
                local dist_sq = dx * dx + dy * dy + dz * dz

                if dist_sq <= range_sq then
                    local flag = mod._proximity_types[pickup_name]
                    if flag then
                        mod[flag] = true
                        -- mod:echo("Proximity Active: %s", pickup_name)
                    end
                end
            end
        else
            mod._tracked_item_units[unit] = nil
        end
    end

    -- Aggregates
    mod.near_any_stimm        = _near_stimm_source_now()
    mod.near_crate_source_any = _near_crate_source_now()
end

function ProximitySystem.on_all_mods_loaded()
    if are_ringhud_unit_template_hooks_done then return end

    -- Deployables: track spawns ONLY where vanilla lacks a world marker.
    mod:hook_require("scripts/extension_systems/unit_templates", function(unit_templates)
        if are_ringhud_unit_template_hooks_done then return end
        if unit_templates then
            -- Keep med-crate deployable (no vanilla interaction marker).
            if unit_templates.medical_crate_deployable then
                mod:hook_safe(unit_templates.medical_crate_deployable, "husk_init",
                    function(unit) _handle_deployable_spawn(unit, "medical_crate_deployable") end)
                mod:hook_safe(unit_templates.medical_crate_deployable, "local_unit_spawned",
                    function(unit) _handle_deployable_spawn(unit, "medical_crate_deployable") end)
            end
            -- ammo_cache_deployable: no spawn hooks (handled via interaction marker)
        end
        are_ringhud_unit_template_hooks_done = true
    end)

    -- Inject our (invisible) item template for the med-crate fallback when HEWM boots.
    if type(mod.on_world_markers_init) == "function" then
        mod:on_world_markers_init(function(hewm)
            if hewm and hewm._marker_templates then
                hewm._marker_templates[RingHudItemTrackerMarker.name] = RingHudItemTrackerMarker
            end
        end)
    end
end

-- Public accessors
function ProximitySystem.near_stimm_source()
    return _near_stimm_source_now()
end

function ProximitySystem.near_crate_source()
    return _near_crate_source_now()
end

return ProximitySystem
