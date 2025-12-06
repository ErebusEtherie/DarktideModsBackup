-- File: RingHud/scripts/mods/RingHud/systems/proximity_system.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ProximitySystem = {}

-------------------------------------------------------------------------------
-- System State & Constants
-------------------------------------------------------------------------------

-- Which pickup/deployable names we track and mirror with our own world marker
-- (Note: syringes are handled specially; we still track and mirror them,
--   but their spawn detection may come via different paths. See init() notes.)
mod._item_configs = mod._item_configs or {
    -- Syringes / pocketables
    { name = "syringe_corruption_pocketable" },
    { name = "syringe_power_boost_pocketable" },
    { name = "syringe_speed_boost_pocketable" },
    { name = "syringe_ability_boost_pocketable" },

    -- Ammo
    { name = "small_clip" },
    { name = "large_clip" },
    { name = "ammo_cache_pocketable" },
    { name = "ammo_cache_deployable" },

    -- Healing
    { name = "medical_crate_pocketable" },
    { name = "medical_crate_deployable" },
    { name = "health_station" },

    -- Scriptures
    { name = "tome_pocketable" },
    { name = "grimoire_pocketable" },
}

-- Proximity “flags” exported to the rest of the mod (all false by default).
-- These are recomputed during ProximitySystem.update at intervals.
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
mod._PROXIMITY_SCAN_INTERVAL               = mod._PROXIMITY_SCAN_INTERVAL or 1.0
mod._deferred_marker_additions             = mod._deferred_marker_additions or {}

-- Marker template & persistent tracking table
local RingHudItemTrackerMarker             = mod:io_dofile("RingHud/scripts/mods/RingHud/RingHud_marker")
mod._tracked_item_units                    = mod._tracked_item_units or mod:persistent_table("tracked_item_units")

-- Guards for once-only wiring
local are_ringhud_unit_template_hooks_done = false

-------------------------------------------------------------------------------
-- Private Helper Functions
-------------------------------------------------------------------------------

local function _get_pickup_name(unit)
    return unit and Unit.get_data(unit, "pickup_type")
end

local function _is_tracked_item_type(name)
    if not name then return false end
    -- simple linear lookup (small set)
    for i = 1, #mod._item_configs do
        if mod._item_configs[i].name == name then
            return true
        end
    end
    return false
end

-- Lightweight per-unit flags to avoid spammy notifications (kept for future use)
local function _is_notified(unit) return Unit.get_data(unit, "rh_notified") end
local function _set_notified(unit, val) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_notified", val) end end
local function _set_collected(unit, val) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_collected", val) end end
local function _set_last_t(unit, t) if unit and Unit.alive(unit) then Unit.set_data(unit, "rh_last_t", t) end end
local function _can_repeat(unit, t)
    local lt = Unit.get_data(unit, "rh_last_t")
    return not lt or lt + 1 < t
end

local function _is_being_tracked_by_rh(unit)
    return unit and Unit.get_data(unit, "rh_tracking")
end

local function _set_rh_tracking_status(unit, val)
    if unit and Unit.alive(unit) then
        Unit.set_data(unit, "rh_tracking", val)
    end
end

-- Return live HudElementWorldMarkers (if present)
local function _hewm()
    local hud = Managers.ui and Managers.ui._hud
    return hud and hud:element("HudElementWorldMarkers") or nil
end

-- Ensure the item tracker template is present **inside the live HEWM**.
local function _ensure_item_template()
    local hewm = _hewm()
    if not hewm or not hewm._marker_templates then return false end
    if not hewm._marker_templates[RingHudItemTrackerMarker.name] then
        hewm._marker_templates[RingHudItemTrackerMarker.name] = RingHudItemTrackerMarker
    end
    return true
end

-- Add a marker, but only if the template is guaranteed to be present.
-- Otherwise, defer and try again later.
local function _add_marker(unit, data_for_marker)
    if not unit or not Unit.alive(unit) then return end
    if not _ensure_item_template() then
        -- Try again later; keep only one outstanding deferral per unit
        mod._deferred_marker_additions[unit] = data_for_marker
        return
    end
    -- (marker_type, unit, cb, data, extra) signature variety is tolerated;
    -- we pass our payload under the fifth arg to avoid clashing with vanilla cb/data.
    Managers.event:trigger("add_world_marker_unit", RingHudItemTrackerMarker.name, unit, nil, nil, data_for_marker)
end

-- Unit-template spawn hooks (deployables often don’t go through the same UI path)
local function _handle_deployable_spawn(unit, deployable_name)
    if not unit or not Unit.alive(unit) then return end
    if Unit.get_data(unit, "rh_processed_spawn_" .. deployable_name) then return end
    if _is_tracked_item_type(deployable_name) then
        _set_rh_tracking_status(unit, true)
        Unit.set_data(unit, "rh_processed_spawn_" .. deployable_name, true)
        Unit.set_data(unit, "rh_marker_type", deployable_name) -- fallback if pickup_type is missing
        mod._tracked_item_units[unit] = unit
        _add_marker(unit, { rh_pickup_name = deployable_name })
    end
end

-- ========= NEW: combined proximity predicates (no settings logic here) ======
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
    -- 1) When a vanilla interaction marker spawns, mirror it with our tracker.
    -- We *skip* ALL syringes here because they travel the vanilla "interaction"
    -- world-marker path that other hooks watch; skipping avoids duplicate markers
    -- and lets StimmsPickupIcon tint the visible marker without interference.
    mod:hook_safe(CLASS.HudElementInteraction, "_on_interaction_marker_spawned",
        function(self_hud_interaction, unit)
            if not unit or not Unit.alive(unit) then return end

            local pickup_name_from_unit_data = Unit.get_data(unit, "pickup_type")
            if pickup_name_from_unit_data == "syringe_corruption_pocketable"
                or pickup_name_from_unit_data == "syringe_ability_boost_pocketable"
                or pickup_name_from_unit_data == "syringe_power_boost_pocketable"
                or pickup_name_from_unit_data == "syringe_speed_boost_pocketable"
            then
                return -- handled via world-marker path to avoid duplicates
            end

            local identified_item_name = pickup_name_from_unit_data

            -- If there’s no pickup_type but it’s a health station interactable, tag it.
            if not identified_item_name and ScriptUnit.has_extension(unit, "interactee_system") then
                local interactee_extension = ScriptUnit.extension(unit, "interactee_system")
                if interactee_extension and interactee_extension:interaction_type() == "health_station" then
                    identified_item_name = "health_station"
                end
            end

            if identified_item_name and _is_tracked_item_type(identified_item_name) then
                _set_rh_tracking_status(unit, true)
                mod._tracked_item_units[unit] = unit
                _add_marker(unit, { rh_pickup_name = identified_item_name })
            end
        end
    )

    -- 2) Let our template’s update function prune dead units and state.
    mod:hook_safe(RingHudItemTrackerMarker, "update_function",
        function(_, _, widget, marker, self_template, dt, t)
            local unit = marker and marker.unit
            if not unit or not Unit.alive(unit) then
                if unit and mod._tracked_item_units[unit] then
                    mod._tracked_item_units[unit] = nil
                end
                return
            end

            -- Autoflag "collected" if the vanilla marker is gone OR the unit no longer interactable.
            if ScriptUnit.has_extension(unit, "pickup_system") then
                local ps = ScriptUnit.extension(unit, "pickup_system")
                if ps and ps._picked_up then
                    _set_collected(unit, true)
                end
            end

            -- Keep a gentle cadence for any optional notifications
            if _can_repeat(unit, t) then
                _set_last_t(unit, t)
                -- (reserved for soft beeps/UI pulses, if you enable them later)
            end
        end
    )

    -- Expose compat shims so other modules can call mod.near_* as functions.
    mod.near_stimm_source = function() return ProximitySystem.near_stimm_source() end
    mod.near_crate_source = function() return ProximitySystem.near_crate_source() end
end

function ProximitySystem.update(dt)
    -- 1) Try any deferred marker additions (template wasn’t ready yet).
    if next(mod._deferred_marker_additions) ~= nil then
        local snapshot = mod._deferred_marker_additions
        mod._deferred_marker_additions = {} -- drain; _add_marker will re-defer if still not ready
        for unit, payload in pairs(snapshot) do
            if unit and Unit.alive(unit) then
                _add_marker(unit, payload)
            end
        end
    end

    -- 2) Periodic proximity scan (cheap; O(n) on small set of tracked units)
    local t_now = (mod._ringhud_accumulated_time or 0) + (dt or 0)
    mod._ringhud_accumulated_time = t_now

    if t_now < (mod._next_proximity_scan_time or 0) then
        return
    end
    mod._next_proximity_scan_time = t_now + (mod._PROXIMITY_SCAN_INTERVAL or 1.0)

    -- Only run in actual missions or the range; skip menus etc.
    local gm = Managers.state and Managers.state.game_mode
    local gm_name = gm and gm:game_mode_name() or "unknown"
    if gm_name ~= "coop_complete_objective" and gm_name ~= "shooting_range" then
        return
    end

    -- Reset flags
    for _, flag_name in pairs(mod._proximity_types) do
        mod[flag_name] = false
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
            -- derive name robustly
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
                    end
                end
            end
        else
            -- cleanup dead handles
            mod._tracked_item_units[unit] = nil
        end
    end

    -- Publish convenient aggregates (optional to use)
    mod.near_any_stimm        = _near_stimm_source_now()
    mod.near_crate_source_any = _near_crate_source_now()
end

function ProximitySystem.on_all_mods_loaded()
    if are_ringhud_unit_template_hooks_done then return end

    -- 1) Deployables emit via unit-templates; catch those spawns to mirror with our marker.
    mod:hook_require("scripts/extension_systems/unit_templates", function(unit_templates)
        if are_ringhud_unit_template_hooks_done then return end
        if unit_templates then
            if unit_templates.medical_crate_deployable then
                mod:hook_safe(unit_templates.medical_crate_deployable, "husk_init",
                    function(unit) _handle_deployable_spawn(unit, "medical_crate_deployable") end)
                mod:hook_safe(unit_templates.medical_crate_deployable, "local_unit_spawned",
                    function(unit) _handle_deployable_spawn(unit, "medical_crate_deployable") end)
            end
            if unit_templates.ammo_cache_deployable then
                mod:hook_safe(unit_templates.ammo_cache_deployable, "husk_init",
                    function(unit) _handle_deployable_spawn(unit, "ammo_cache_deployable") end)
                mod:hook_safe(unit_templates.ammo_cache_deployable, "local_unit_spawned",
                    function(unit) _handle_deployable_spawn(unit, "ammo_cache_deployable") end)
            end
        end
        are_ringhud_unit_template_hooks_done = true
    end)

    -- 2) Inject our item template when the world-markers element initializes.
    -- (Avoids relying on timing; no duplicate hooks.)
    if type(mod.on_world_markers_init) == "function" then
        mod:on_world_markers_init(function(hewm)
            if hewm and hewm._marker_templates then
                hewm._marker_templates[RingHudItemTrackerMarker.name] = RingHudItemTrackerMarker
            end
        end)
    end

    -- NOTE: We intentionally DO NOT hook CLASS.HudElementWorldMarkers:event_add_world_marker_unit here.
    -- That hook is unified in team/floating.lua per project rule “any given hook can only appear in one file”.
end

-- ========= NEW: public accessors (called by team/visibility.lua) ============
function ProximitySystem.near_stimm_source()
    return _near_stimm_source_now()
end

function ProximitySystem.near_crate_source()
    return _near_crate_source_now()
end

return ProximitySystem
