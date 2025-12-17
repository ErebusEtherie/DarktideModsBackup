-- File: RingHud/scripts/mods/RingHud/RingHud.lua
-- The thinking that went into this mod makes more sense if you are familiar with Edward Tufte ( https://www.geeksforgeeks.org/mastering-tuftes-data-visualization-principles/ )

local mod = get_mod("RingHud")
if not mod then return end
mod.version                            = "RingHud version 1.09.02"

local MISSION_BOARD_PACKAGE            = "packages/ui/views/mission_board_view/mission_board_view"

mod._ringhud_visibility_applied_to_hud = setmetatable({}, { __mode = "k" })
mod._ringhud_hooked_elements           = setmetatable({}, { __mode = "k" })

local PlayerUnitStatus                 = require("scripts/utilities/attack/player_unit_status")

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/settings_manager")

-- Ensure RingHud palettes/helpers are available early (some features read mod.PALETTE_* at load time)
mod.colors              = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local ProximitySystem   = mod:io_dofile("RingHud/scripts/mods/RingHud/context/proximity_context")
local VanillaHudManager = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/vanilla_hud_manager")
local ReassuranceSystem = mod:io_dofile("RingHud/scripts/mods/RingHud/context/reassurance_context")
local ScannerContext    = mod:io_dofile("RingHud/scripts/mods/RingHud/context/scanner_context")

-- Load GrenadesFeature early so its broker blitz template patch + mod.grenades_update_state are installed ASAP
mod:io_dofile("RingHud/scripts/mods/RingHud/features/grenades_feature")

-- ★ New: centralised ammo visibility policy (after proximity/reassurance/wield)
mod:io_dofile("RingHud/scripts/mods/RingHud/context/ammo_visibility")

-- ★ New: centralised pocketable visibility policy
mod:io_dofile("RingHud/scripts/mods/RingHud/context/pocketables_visibility")

local CrosshairFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/crosshair_feature")
if CrosshairFeature and CrosshairFeature.init then CrosshairFeature.init() end

-- Floating teammates (world markers)
mod.floating_manager = mod:io_dofile("RingHud/scripts/mods/RingHud/core/HudElementRingHud_team_nameplate")

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/player_assistance_suppress")

-- Compatibility
local RSBridge = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge")
mod:io_dofile("RingHud/scripts/mods/RingHud/compat/audible_ability_recharge_bridge")

mod:io_dofile("RingHud/scripts/mods/RingHud/features/ability_sound_feature")

-- Ensure edge-packing constants are loaded and alias the recompute helper
do
    local C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
    if C and type(C) == "table" and type(C.recompute_edge_marker_size) == "function" then
        mod.recompute_edge_marker_size = C.recompute_edge_marker_size
    end
end

if ProximitySystem and ProximitySystem.init then ProximitySystem.init() end
if VanillaHudManager and VanillaHudManager.init then VanillaHudManager.init() end
if ReassuranceSystem and ReassuranceSystem.init then ReassuranceSystem.init() end
if ScannerContext and ScannerContext.init then ScannerContext.init() end

--========================
-- Central settings cache
--========================
mod._settings = mod._settings or {}

-- A small patch to prevent a common nil error in the game's base code.
mod:hook(CLASS.MechanismManager, "mechanism_data", function(func, self)
    if self._mechanism then
        return func(self)
    end
end)

-------------------------------------------------------------------------------
-- Global Mod State (non-settings) -- TODO Constants or not constants?
-------------------------------------------------------------------------------
mod.AMMO_CLIP_ARC_MIN               = 0.51
mod.AMMO_CLIP_ARC_MAX               = 0.99
mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY = 30
mod.MAX_DODGE_SEGMENTS              = 8
mod.MAX_GRENADE_SEGMENTS_DISPLAY    = 14

-- unified force-show flag (computed each frame from manual hotkey OR ADS rule)
mod.show_all_hud_hotkey_active      = false
mod._hotkey_manual_active           = false

mod.reassure_health                 = false
mod.reassure_ammo                   = false
mod.reassure_health_last_set_time   = 0
mod.reassure_ammo_last_set_time     = 0
mod.REASSURE_TIMEOUT                = 2.0

mod.team_average_health_fraction    = 1.0
mod.team_average_ammo_fraction      = 1.0
mod.next_team_stats_poll_time       = 0
local TEAM_STATS_POLL_INTERVAL      = 10

if mod._ringhud_accumulated_time == nil then mod._ringhud_accumulated_time = 0 end

local function _sum_if_table(v)
    if type(v) ~= "table" then
        return v
    end
    local s = 0
    for _, x in pairs(v) do
        if type(x) == "number" then
            s = s + x
        end
    end
    return s
end

-- Helper: current team HUD mode (from settings cache)
local function _team_mode()
    return mod._settings.team_hud_mode
end

-- Exported helper: is any floating team-tiles mode active?
function mod.is_floating_team_tiles_enabled()
    local mode = _team_mode()
    return mode == "team_hud_floating"
        or mode == "team_hud_floating_docked"
        or mode == "team_hud_floating_vanilla"
        or mode == "team_hud_floating_thin"
end

-- Helper: float mode toggler
local function _apply_team_mode_runtime()
    local is_floating = mod.is_floating_team_tiles_enabled()
    if mod.floating_manager and mod.floating_manager.set_enabled then
        mod.floating_manager.set_enabled(is_floating)
    end
end

-- Helper: does the current team_name_icon setting enable "status" icons?
-- These four values are the explicit "status1" variants and replace the old "contains 'special'" rule.
local function _team_icon_has_status_enabled()
    local s    = mod._settings
    local icon = s and s.team_name_icon

    if not icon then
        return false
    end

    return icon == "name0_icon1_status1"
        or icon == "name0_icon0_status1"
        or icon == "name1_icon1_status1"
        or icon == "name1_icon0_status1"
end

-- Nudge: when switching into floating, purge any already-spawned player_assistance markers
-- Updated: Now strictly checks both MODE and ICON setting to match player_assistance_suppress.lua logic.
function mod._refresh_assistance_markers_visibility()
    local hewm = rawget(mod, "_hewm_world_markers")
    if not hewm or not hewm._markers_by_type then return end
    local list = hewm._markers_by_type.player_assistance
    if not list or #list == 0 then return end

    -- New semantics: use explicit team_name_icon values instead of substring search.
    local is_status_enabled = _team_icon_has_status_enabled()

    if mod.is_floating_team_tiles_enabled() and is_status_enabled then
        for i = #list, 1, -1 do
            local m = list[i]
            if m and m.unit then
                -- vanilla template key for this marker type is "player_assistance"
                Managers.event:trigger("remove_world_marker_by_unit", "player_assistance", m.unit)
            end
            list[i] = nil
        end
    end
end

-------------------------------------------------------------------------------
-- Custom HUD Element Registration
-------------------------------------------------------------------------------
local custom_hud_element_data = {
    use_hud_scale = true,
    class_name = "HudElementRingHud_player",
    filename = "RingHud/scripts/mods/RingHud/core/HudElementRingHud_player",
    visibility_groups = { "alive" }
}
mod:add_require_path(custom_hud_element_data.filename)

local custom_team_hud_element_data = {
    use_hud_scale = true,
    class_name = "HudElementRingHud_team_docked",
    filename = "RingHud/scripts/mods/RingHud/core/HudElementRingHud_team_docked",
    visibility_groups = { "alive", "communication_wheel", "dead" }
}
mod:add_require_path(custom_team_hud_element_data.filename)

-- Shared helper to add or replace an element in a HUD element pool
local function _insert_or_replace_element(element_pool, data)
    if not element_pool or not data then return end
    local found_index
    for i = 1, #element_pool do
        local e = element_pool[i]
        if e and e.class_name == data.class_name then
            found_index = i
            break
        end
    end
    if found_index then
        element_pool[found_index] = data
    else
        element_pool[#element_pool + 1] = data
    end
end

-- Registers both player and team HUD elements
local function add_or_replace_ring_hud_elements(element_pool)
    _insert_or_replace_element(element_pool, custom_hud_element_data)
    _insert_or_replace_element(element_pool, custom_team_hud_element_data)
end

-- Registers only the team HUD element (for spectator view)
local function add_or_replace_team_only(element_pool)
    _insert_or_replace_element(element_pool, custom_team_hud_element_data)
end

-- Standard player HUDs
mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", add_or_replace_ring_hud_elements)
mod:hook_require("scripts/ui/hud/hud_elements_player", add_or_replace_ring_hud_elements)

-- Training Grounds / Range / Tutorial
mod:hook_require("scripts/ui/hud/hud_elements_training_grounds", add_or_replace_ring_hud_elements)
mod:hook_require("scripts/ui/hud/hud_elements_shooting_range", add_or_replace_ring_hud_elements)
mod:hook_require("scripts/ui/hud/hud_elements_tutorial", add_or_replace_ring_hud_elements)

-- Spectator HUD: register ONLY the team element so player widgets never show while dead
mod:hook_require("scripts/ui/hud/hud_elements_spectator", add_or_replace_team_only)

-- Vanilla Team Player Panel visibility
mod:hook(CLASS.HudElementTeamPlayerPanel, "draw", function(func, self, ...)
    local mode = _team_mode()
    -- Show vanilla only in these modes; hide it everywhere else.
    if mode ~= "team_hud_disabled"
        and mode ~= "team_hud_floating_vanilla"
        and mode ~= "team_hud_floating_thin"
        and mode ~= "team_hud_icons_vanilla"
    then
        return
    end

    -- In the thin mode, strip specific panel visuals regardless of minimal_objective_feed_enabled
    if VanillaHudManager and VanillaHudManager.apply_team_panel_thin_styles then
        VanillaHudManager.apply_team_panel_thin_styles(self)
    end

    return func(self, ...)
end)

-------------------------------------------------------------------------------
-- HudElementWorldMarkers orchestration (single init hook)
-------------------------------------------------------------------------------
mod._world_markers_init_callbacks = mod._world_markers_init_callbacks or {}
function mod:on_world_markers_init(cb)
    if type(cb) ~= "function" then return end
    local hewm = rawget(mod, "_hewm_world_markers")
    if hewm and hewm._marker_templates then
        cb(hewm)
    else
        table.insert(mod._world_markers_init_callbacks, cb)
    end
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self_hewm, parent, draw_layer, start_scale)
    mod._hewm_world_markers = self_hewm

    local teammate_tpl = mod:io_dofile("RingHud/scripts/mods/RingHud/team/floating_marker_template")
    if teammate_tpl and teammate_tpl.name and self_hewm._marker_templates then
        self_hewm._marker_templates[teammate_tpl.name] = teammate_tpl -- "ringhud_teammate_tile"
    end

    -- true_level compat: make sure vanilla buckets always exist
    do
        local by_type = self_hewm._markers_by_type
        if by_type then
            by_type.nameplate_party  = by_type.nameplate_party or {}
            by_type.nameplate_combat = by_type.nameplate_combat or {}
        end
    end

    -- Execute any stored callbacks
    for _, cb in ipairs(mod._world_markers_init_callbacks) do
        cb(self_hewm)
    end
    mod._world_markers_init_callbacks = {} -- Clear after running

    if mod.floating_manager and mod.floating_manager.on_hewm_ready then
        mod.floating_manager.on_hewm_ready(self_hewm)
    end
end)

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
local function _refresh_compat_caches()
    if RSBridge and RSBridge.refresh then
        RSBridge.refresh()
    end
end

-- Robust hotkey handler: works whether DMF calls with (self, pressed) or (pressed)
function mod.handle_show_all_hud_hotkey_state(...)
    local a, b = ...
    local pressed = (type(b) == "boolean") and b or (type(a) == "boolean" and a or false)
    mod._hotkey_manual_active = (pressed == true)
end

-- Backwards-compatible alias if your schema still references the old name
mod.handle_show_all_hotkey_state = mod.handle_show_all_hud_hotkey_state

-- ADS detector (alternate fire active on the local player's unit)
local function _is_ads_now()
    local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not (unit and Unit.alive(unit)) then return false end
    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    if not uds then return false end
    local alt = uds:read_component("alternate_fire")
    return (alt and alt.is_active) or false
end

mod.update = function(dt)
    if not mod:is_enabled() then
        return
    end

    mod._ringhud_accumulated_time = mod._ringhud_accumulated_time + dt
    local t = mod._ringhud_accumulated_time

    -- Compute unified force-show flag each frame:
    -- manual hotkey OR (ADS if ads_visibility_dropdown == "ads_vis_hotkey")
    do
        local ads_counts_as_hotkey     = (mod._settings and mod._settings.ads_visibility_dropdown == "ads_vis_hotkey")
        local ads_hotkey_active        = ads_counts_as_hotkey and _is_ads_now() or false
        mod.show_all_hud_hotkey_active = (mod._hotkey_manual_active == true) or ads_hotkey_active
    end

    if ProximitySystem and ProximitySystem.update then ProximitySystem.update(dt) end
    if mod.floating_manager and mod.floating_manager.update then mod.floating_manager.update(dt) end

    if t >= (mod.next_team_stats_poll_time or 0) then
        local total_health, health_count, total_ammo, ammo_count = 0, 0, 0, 0
        local pm = Managers.player
        if pm and pm.players then
            for _, player in pairs(pm:players()) do
                local unit = player.player_unit
                if unit and Unit.alive(unit) then
                    local unit_data  = ScriptUnit.has_extension(unit, "unit_data_system")
                    local health_sys = ScriptUnit.has_extension(unit, "health_system")
                    local is_dead    = false

                    if unit_data and health_sys then
                        local character_state_comp = unit_data:read_component("character_state")
                        is_dead = PlayerUnitStatus.is_dead(character_state_comp, health_sys)
                        if is_dead then
                            health_count = health_count + 1
                        else
                            total_health = total_health + health_sys:current_health_percent() +
                                health_sys:permanent_damage_taken_percent()
                            health_count = health_count + 1
                        end
                    end

                    if unit_data and not is_dead then
                        local has_ammo = false
                        for _, slot_name in pairs({ "slot_primary", "slot_secondary" }) do
                            local slot_comp = unit_data:read_component(slot_name)
                            if slot_comp then
                                local max_res = _sum_if_table(slot_comp.max_ammunition_reserve) or 0
                                local cur_res = _sum_if_table(slot_comp.current_ammunition_reserve) or 0

                                if max_res > 0 then
                                    total_ammo = total_ammo + (cur_res / max_res)
                                    has_ammo = true
                                    break
                                end
                            end
                        end
                        if has_ammo then ammo_count = ammo_count + 1 end
                    end
                end
            end
        end
        mod.team_average_health_fraction = (health_count > 0) and (total_health / health_count) or 1.0
        mod.team_average_ammo_fraction   = (ammo_count > 0) and (total_ammo / ammo_count) or 1.0
        mod.next_team_stats_poll_time    = t + TEAM_STATS_POLL_INTERVAL
    end

    if mod.reassure_health and t >= (mod.reassure_health_last_set_time or 0) + mod.REASSURE_TIMEOUT then mod.reassure_health = false end
    if mod.reassure_ammo and t >= (mod.reassure_ammo_last_set_time or 0) + mod.REASSURE_TIMEOUT then mod.reassure_ammo = false end
end

mod.on_game_state_changed = function(status, state_name)
    if not mod:is_enabled() then return end

    if state_name == "StateGameplay" and status == "enter" then
        mod._grenade_max_override = nil

        -- Reset broker blitz mirror state on mission entry (prevents stale progress/ghost partials)
        mod._broker_blitz_tracked_kills = 0
        mod._broker_blitz_prev_grenade_cur = 0

        _refresh_compat_caches()
        _apply_team_mode_runtime()
        mod._refresh_assistance_markers_visibility()
        if ScannerContext and ScannerContext.on_game_state_changed then
            ScannerContext.on_game_state_changed(status,
                state_name)
        end
        -- Keep ammo-visibility caches fresh on state entry
        if mod.ammo_vis_on_setting_changed then mod.ammo_vis_on_setting_changed() end
        -- Keep pocketable-visibility caches fresh on state entry
        if mod.pockets_vis_on_setting_changed then mod.pockets_vis_on_setting_changed() end
    end

    if state_name == "StateLoading" and status == "enter" then
        if mod._ringhud_accumulated_time then mod._ringhud_accumulated_time = 0 end
        if ProximitySystem and ProximitySystem.on_game_state_changed then
            ProximitySystem.on_game_state_changed(status, state_name)
        end
        if VanillaHudManager and VanillaHudManager.on_game_state_changed then
            VanillaHudManager.on_game_state_changed(status, state_name)
        end
        _refresh_compat_caches()
    end
end

mod.on_all_mods_loaded = function()
    mod:info(mod.version)

    if ProximitySystem and ProximitySystem.on_all_mods_loaded then ProximitySystem.on_all_mods_loaded() end
    if VanillaHudManager and VanillaHudManager.on_all_mods_loaded then VanillaHudManager.on_all_mods_loaded() end
    _refresh_compat_caches()

    if mod.floating_manager and mod.floating_manager.install then
        mod.floating_manager.install()
    end

    if mod.recompute_edge_marker_size then
        mod.recompute_edge_marker_size()
    end

    -- Ensure new modules have the latest settings cache
    if mod.ammo_vis_on_setting_changed then mod.ammo_vis_on_setting_changed() end
    if mod.pockets_vis_on_setting_changed then mod.pockets_vis_on_setting_changed() end

    _apply_team_mode_runtime()
    mod._refresh_assistance_markers_visibility()
end

mod.on_disabled = function(initial_call)
    mod.show_all_hud_hotkey_active = false
    mod._hotkey_manual_active = false
    mod.reassure_health = false
    mod.reassure_ammo = false

    -- Broker blitz mirror state
    mod._broker_blitz_tracked_kills = 0
    mod._broker_blitz_prev_grenade_cur = 0

    if VanillaHudManager and VanillaHudManager.on_mod_disabled then
        VanillaHudManager.on_mod_disabled()
    end

    if mod.floating_manager and mod.floating_manager.uninstall then
        mod.floating_manager.uninstall()
    end

    if Managers.package then
        Managers.package:release(MISSION_BOARD_PACKAGE, "RingHud")
    end
end

mod.on_enabled = function(initial_call)
    if Managers.package then
        Managers.package:load(MISSION_BOARD_PACKAGE, "RingHud", nil, true)
    end

    mod._ringhud_visibility_applied_to_hud = setmetatable({}, { __mode = "k" })
    _apply_team_mode_runtime()
    -- Ensure new modules have the latest settings cache on enable
    if mod.ammo_vis_on_setting_changed then mod.ammo_vis_on_setting_changed() end
    if mod.pockets_vis_on_setting_changed then mod.pockets_vis_on_setting_changed() end
end
