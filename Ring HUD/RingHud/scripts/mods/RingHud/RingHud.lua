-- File: RingHud/scripts/mods/RingHud/RingHud.lua
-- The thinking that went into this mod makes more sense if you are familiar with Edward Tufte ( https://www.geeksforgeeks.org/mastering-tuftes-data-visualization-principles/ )

local mod = get_mod("RingHud")
if not mod then return end
mod.version = "RingHud version 1.08a"

--[[
CHANGELOG
1.08a No Man's Land Quick Fix
    -- [Fixed] Changed loaded ammo code to handle structure in new patch

1.08 Audible Ability Recharge Fix
    -- [Fixed] Fix conflict with Audible Ability Recharge
    -- [Fixed] Removed options for feature that is not yet implemented
    -- [Better] Improvements to contextual teammate settings

1.07 Team Tiles
    -- [New] ADS scale and separation controls
    -- [New] Team health bars (ignores bots), gold toughness, broken toughness (red border)
    -- [New] Team panels docked and undocked modes
    -- [New] Team rescue progress (green border), ledge time to fall (red border)
    -- [New] Team reserve ammo, blitz, pocketables, cooldown
    -- [New] Team toughness counter, hp counter
    -- [New] RecolorStimms compatibility
    -- [Better] Moved player stimm widget
    -- [Better] Altered outlines and fills to make bars more readable
    -- [Better] Force show no longer shows grenade bar for smite / brain burst
    -- [Fixed] Apply "enhanced blitz" mutator and other buffs to grenade bar max grenades

1.06 Pocketables and layout
    -- [New] Pocketables and optional contextual visibility for pocketables
    -- [New] Dynamic hp text label -- text label is always dynamic to reduce clutter
    -- [New] Scale slider to make this thing huge
    -- [New] Separation slider to make this thing square
    -- [Better] Enhanced context sensitivity for toughness/health bar
    -- [Better] Overhauled mod structure
    -- [Fixed] Prevented Ring HUD visual elements persisting after mod is disabled

1.05 Arbites
    -- Arbite/adamant grenade regen
    -- Control adamant shield charge with helbore setting instead of FGS setting
    -- Improved compatibility with Ration Pack mod

1.04 Chinese language
    -- Chinese localisation by jcyl2023

1.03 Compatibility and immersion
    -- Deadshot stamina
    -- Move with crosshair
    -- Options to hide native HUD elements
    -- Fix Nuncio Aquila crash
    -- No longer disrupts Stimms Pickup Icon mod

1.02 Munitions and toughness
    -- Toughness/HP bar.
    -- Green dodges border if full.
    -- White charge up border if no peril.
    -- Always show stamina if threshold set to 0, always hide if set to negative.  Same as dodges.
    -- Change peril color progression. Skip blue.
    -- Ammo clip bar.
    -- Ammo clip text widget.
    -- Ammo reserve text label.
    -- Grenade bar.
    -- Hot key to show all while held.
    -- Detect proximity to ammo for dynamic setting.
    -- Detect proximity to healing for dynamic setting.

1.01 Initial release (required a reupload)
]]

mod._ringhud_visibility_applied_to_hud = setmetatable({}, { __mode = "k" })
mod._ringhud_hooked_elements           = setmetatable({}, { __mode = "k" })

local PlayerUnitStatus                 = require("scripts/utilities/attack/player_unit_status")
local PlayerCharacterConstants         = require("scripts/settings/player_character/player_character_constants")
local CrosshairUtil                    = require("scripts/ui/utilities/crosshair")

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/settings_manager")

local ProximitySystem   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/proximity_system")
local VanillaHudManager = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/vanilla_hud_manager")
local ReassuranceSystem = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/reassurance_system")

-- Floating teammates (world markers)
mod.floating_manager    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/floating")

-- Name composition (WAY/TL bridges + cache) and nameplate styling
mod:io_dofile("RingHud/scripts/mods/RingHud/compat/who_are_you_bridge")
mod:io_dofile("RingHud/scripts/mods/RingHud/compat/true_level_bridge")
mod.name_cache = mod:io_dofile("RingHud/scripts/mods/RingHud/team/name_cache")
mod:io_dofile("RingHud/scripts/mods/RingHud/team/nameplates")

mod:io_dofile("RingHud/scripts/mods/RingHud/team/ping_suppress")
mod:io_dofile("RingHud/scripts/mods/RingHud/team/player_assistance_suppress")

-- RecolorStimms compatibility (cache on enter events)
local RSBridge = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge")

-- Audible Ability Recharge (AAR) compatibility bridge
mod:io_dofile("RingHud/scripts/mods/RingHud/compat/audible_ability_recharge_bridge")

-- Ensure edge-packing constants are loaded and alias the recompute helper
do
    local ok, C = pcall(mod.io_dofile, mod, "RingHud/scripts/mods/RingHud/team/constants")
    if ok and type(C) == "table" and type(C.recompute_edge_marker_size) == "function" then
        mod.recompute_edge_marker_size = C.recompute_edge_marker_size
    end
end

if ProximitySystem and ProximitySystem.init then ProximitySystem.init() end
if VanillaHudManager and VanillaHudManager.init then VanillaHudManager.init() end
if ReassuranceSystem and ReassuranceSystem.init then ReassuranceSystem.init() end

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
mod.current_crosshair_delta_x       = 0
mod.current_crosshair_delta_y       = 0

mod.AMMO_CLIP_ARC_MIN               = 0.51
mod.AMMO_CLIP_ARC_MAX               = 0.99
mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY = 30
mod.MAX_DODGE_SEGMENTS              = 8
mod.MAX_GRENADE_SEGMENTS_DISPLAY    = 14

mod.override_color                  = nil

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

-- Helper to safely load a template file (returns the table or nil)
local function safe_load(path)
    local ok, res = pcall(mod.io_dofile, mod, path)
    return ok and res or nil
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
        or mode == "team_hud_icons_vanilla"
        or mode == "team_hud_icons_docked"
end

-- Helper: float mode toggler (guarded so we don't require FloatingManager to expose anything specific)
local function _apply_team_mode_runtime()
    local is_floating = mod.is_floating_team_tiles_enabled()
    if mod.floating_manager and mod.floating_manager.set_enabled then
        mod.floating_manager.set_enabled(is_floating)
    end
end

-- Nudge: when switching into floating, purge any already-spawned player_assistance markers
function mod._refresh_assistance_markers_visibility()
    local hewm = rawget(mod, "_hewm_world_markers")
    if not hewm or not hewm._markers_by_type then return end
    local list = hewm._markers_by_type.player_assistance
    if not list or #list == 0 then return end

    if mod.is_floating_team_tiles_enabled() then
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
    class_name = "HudElementRingHud",
    filename = "RingHud/scripts/mods/RingHud/HudElementRingHud",
    visibility_groups = { "alive" }
}
mod:add_require_path(custom_hud_element_data.filename)

local custom_team_hud_element_data = {
    use_hud_scale = true,
    class_name = "HudElementRingHudTeam",
    filename = "RingHud/scripts/mods/RingHud/HudElementRingHudTeam",
    visibility_groups = { "alive", "communication_wheel", "dead" }
}
mod:add_require_path(custom_team_hud_element_data.filename)

local function add_or_replace_ring_hud_elements(element_pool)
    if not element_pool then return end

    local function insert_or_replace(data)
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

    insert_or_replace(custom_hud_element_data)
    insert_or_replace(custom_team_hud_element_data)
end

-- NEW: spectator should only have the TEAM element (never the player element)
local function add_or_replace_team_only(element_pool)
    if not element_pool then return end

    local function insert_or_replace(data)
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

    insert_or_replace(custom_team_hud_element_data)
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
        and mode ~= "team_hud_icons_vanilla"
    then
        return
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
        pcall(cb, hewm)
    else
        table.insert(mod._world_markers_init_callbacks, cb)
    end
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self_hewm, parent, draw_layer, start_scale)
    mod._hewm_world_markers = self_hewm

    local teammate_tpl = safe_load("RingHud/scripts/mods/RingHud/team/floating_marker_template")
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

    if type(mod.on_world_markers_init) == "function" then
        mod:on_world_markers_init(self_hewm)
    end

    if mod.floating_manager and mod.floating_manager.on_hewm_ready then
        mod.floating_manager.on_hewm_ready(self_hewm)
    end
end)

-------------------------------------------------------------------------------
-- Misc Global Hooks
-------------------------------------------------------------------------------
if CrosshairUtil and CrosshairUtil.position then
    mod:hook(CrosshairUtil, "position", function(func, dt, t, ui_hud, ui_renderer, current_x, current_y, pivot_position)
        local final_x, final_y = func(dt, t, ui_hud, ui_renderer, current_x, current_y, pivot_position)
        mod.current_crosshair_delta_x = final_x
        mod.current_crosshair_delta_y = final_y
        return final_x, final_y
    end)
end

mod:hook_safe(CLASS.HudElementCrosshair, "update", function(self)
    if mod.override_color == nil then return end
    local widget = self._widget; if not widget or not widget.style then return end
    local template = self._crosshair_templates and self._crosshair_templates[self._crosshair_type]
    if not template or not template.name then return end
    local style = widget.style; local color = table.clone(mod.override_color)
    if template.name == "charge_up" or template.name == "charge_up_ads" then
        if style.charge_mask_right then style.charge_mask_right.color = color end
        if style.charge_mask_left then style.charge_mask_left.color = color end
    elseif template.name == "flamer" or template.name == "shotgun_wide" or template.name == "spray_n_pray" or template.name == "assault" or template.name == "cross" or template.name == "shotgun" then
        if style.left then style.left.color = color end
        if style.right then style.right.color = color end
        if style.top then style.top.color = color end
        if style.bottom then style.bottom.color = color end
    end
    widget.dirty = true
end)

-- Hooks for ability ready sound
local NEW_ABILITY_SOUND      = "wwise/events/player/play_ability_zealot_bolstering_prayer"
local ORIGINAL_ABILITY_SOUND = "wwise/events/ui/play_hud_ability_off_cooldown"

-- Helpers to integrate with AAR (if present)
local function _pick_aar_sound_by_charges(charges)
    local s1 = mod._aar_sound_1 or ORIGINAL_ABILITY_SOUND
    local s2 = mod._aar_sound_2 or s1
    if charges == 2 then
        return s2
    else
        return s1
    end
end

local function _play_ready_sound(event_name, self_or_nil)
    local is_aar_event = (event_name == (mod._aar_sound_1 or "")) or (event_name == (mod._aar_sound_2 or ""))
    if mod._aar_present and is_aar_event then
        if mod._aar_play_event then
            return mod._aar_play_event(event_name)
        else
            return false
        end
    end
    if self_or_nil and self_or_nil._play_sound then
        self_or_nil:_play_sound(event_name)
        return true
    end
    return false
end

mod:hook(CLASS.HudElementPlayerSlotItemAbility, "init", function(func, self, parent, draw_layer, start_scale, data)
    -- If AAR is present, don't override vanilla at all (and don't play init sound here).
    if mod._aar_present then
        return func(self, parent, draw_layer, start_scale, data)
    end

    -- (Original RingHud override)
    local definition_path = data.definition_path
    local definitions = dofile(definition_path)

    HudElementPlayerSlotItemAbility.super.init(self, parent, draw_layer, start_scale, definitions)

    self._data = data
    self._slot_id = data.slot_id

    local slot_configuration = PlayerCharacterConstants.slot_configuration
    local slot_config = slot_configuration[self._slot_id]
    local wield_inputs = slot_config.wield_inputs

    self._wield_input = wield_inputs and wield_inputs[1]

    self:_set_progress(1)
    self:set_charges_amount()
    self:set_icon(data.icon)

    local on_cooldown = false
    local uses_charges = false
    local has_charges_left = true

    self:_set_widget_state_colors(on_cooldown, uses_charges, has_charges_left)
    self:_update_input(); self:_register_events()

    if mod._settings.timer_sound_enabled then
        _play_ready_sound(NEW_ABILITY_SOUND, self)
    else
        _play_ready_sound(ORIGINAL_ABILITY_SOUND, self)
    end
end)

mod:hook(CLASS.HudElementPlayerAbility, "update",
    function(func, self, dt, t, ui_renderer, render_settings, input_service)
        -- Run RingHud's own logic; AAR's plays are muted by our bridge and we mirror its chosen sounds here.
        HudElementPlayerAbility.super.update(self, dt, t, ui_renderer, render_settings, input_service)

        local player = self._data.player
        local parent = self._parent
        local ability_extension = parent:get_player_extension(player, "ability_system")
        local ability_id = self._ability_id
        local cooldown_progress, remaining_ability_charges
        local has_charges_left = true
        local uses_charges = false
        local in_process_of_going_on_cooldown = false
        local force_on_cooldown = false

        if ability_extension and ability_extension:ability_is_equipped(ability_id) then
            local remaining_ability_cooldown = ability_extension:remaining_ability_cooldown(ability_id)
            local max_ability_cooldown = ability_extension:max_ability_cooldown(ability_id)
            local is_paused = ability_extension:is_cooldown_paused(ability_id)

            remaining_ability_charges = ability_extension:remaining_ability_charges(ability_id)

            local max_ability_charges = ability_extension:max_ability_charges(ability_id)

            uses_charges = max_ability_charges and max_ability_charges > 1
            has_charges_left = remaining_ability_charges > 0

            if is_paused then
                cooldown_progress = 0
            elseif max_ability_cooldown and max_ability_cooldown > 0 then
                cooldown_progress = 1 - math.lerp(0, 1, remaining_ability_cooldown / max_ability_cooldown)

                if cooldown_progress == 0 then
                    cooldown_progress = 1
                end
            else
                cooldown_progress = uses_charges and 1 or 0
            end
        end

        if cooldown_progress ~= self._ability_progress then
            self:_set_progress(cooldown_progress)
        end

        local on_cooldown = cooldown_progress ~= 1 and not in_process_of_going_on_cooldown or force_on_cooldown

        if on_cooldown ~= self._on_cooldown or uses_charges ~= self._uses_charges or has_charges_left ~= self._has_charges_left then
            if not on_cooldown and self._on_cooldown and (not uses_charges or has_charges_left) then
                -- Ability just became ready
                if mod._settings.timer_sound_enabled then
                    if mod._aar_present then
                        -- Use AAR's selected event; choose by charges (combat ability only)
                        local event = _pick_aar_sound_by_charges(remaining_ability_charges)
                        _play_ready_sound(event, self)
                    else
                        _play_ready_sound(NEW_ABILITY_SOUND, self)
                    end
                else
                    -- If user disabled RingHud timer sound: stay silent even if AAR is present (we mute AAR).
                end
            end

            self._on_cooldown = on_cooldown
            self._uses_charges = uses_charges
            self._has_charges_left = has_charges_left

            self:_set_widget_state_colors(on_cooldown, uses_charges, has_charges_left)
        end

        if remaining_ability_charges and remaining_ability_charges ~= self._remaining_ability_charges then
            self._remaining_ability_charges = remaining_ability_charges

            self:set_charges_amount(uses_charges and remaining_ability_charges)
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

-- ========= NEW unified hotkey handler & ADS bridging =========
-- Robust handler: works whether DMF calls with (self, pressed) or (pressed)
function mod.handle_show_all_hud_hotkey_state(...)
    local a, b = ...
    local pressed = (type(b) == "boolean") and b or (type(a) == "boolean" and a or false)
    mod._hotkey_manual_active = (pressed == true)
end

-- Backwards-compatible alias if your schema still references the old name
mod.handle_show_all_hotkey_state = mod.handle_show_all_hud_hotkey_state

-- Safe ADS detector (alternate fire active on the local player's unit)
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
    -- Optional low-frequency name cache tick (safe no-op if not implemented)
    if mod.name_cache and mod.name_cache.update then mod.name_cache.update(dt) end

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
                            if slot_comp and slot_comp.max_ammunition_reserve and slot_comp.max_ammunition_reserve > 0 then
                                total_ammo = total_ammo +
                                    (slot_comp.current_ammunition_reserve / slot_comp.max_ammunition_reserve)
                                has_ammo = true
                                break
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
        _refresh_compat_caches()
        _apply_team_mode_runtime()
        -- Clear out any lingering assistance markers if we’re starting in a floating mode
        mod._refresh_assistance_markers_visibility()
        if mod.name_cache and mod.name_cache.invalidate_all then mod.name_cache:invalidate_all() end
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
    -- Build the settings cache once
    -- mod._init_settings_cache()

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

    -- Initialize name cache (safe no-op if it doesn't expose init)
    if mod.name_cache and mod.name_cache.init then
        pcall(function() mod.name_cache:init() end)
    end

    _apply_team_mode_runtime()
    -- Clean-up any assistance markers if we start in a floating mode
    mod._refresh_assistance_markers_visibility()
end

mod.on_disabled = function(initial_call)
    mod.override_color = nil
    mod.show_all_hud_hotkey_active = false
    mod._hotkey_manual_active = false
    mod.reassure_health = false
    mod.reassure_ammo = false

    if VanillaHudManager and VanillaHudManager.on_mod_disabled then
        pcall(VanillaHudManager.on_mod_disabled)
    end

    if mod.floating_manager and mod.floating_manager.uninstall then
        pcall(mod.floating_manager.uninstall)
    end
end

mod.on_enabled = function(initial_call)
    mod._ringhud_visibility_applied_to_hud = setmetatable({}, { __mode = "k" })
    _apply_team_mode_runtime()
end
