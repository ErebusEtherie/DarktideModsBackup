-- File: RingHud/scripts/mods/RingHud/HudElementRingHud.lua

local mod = get_mod("RingHud")
if not mod then return end

-- ## 1. DEPENDENCIES ##
local RingHudState      = mod:io_dofile("RingHud/scripts/mods/RingHud/RingHud_state")
local Definitions       = mod:io_dofile("RingHud/scripts/mods/RingHud/RingHud_definitions")
local PlayerUnitStatus  = require("scripts/utilities/attack/player_unit_status")
local C                 = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")

local PerilFeature      = mod:io_dofile("RingHud/scripts/mods/RingHud/features/peril_feature")
local SurvivalFeature   = mod:io_dofile("RingHud/scripts/mods/RingHud/features/survival_feature")
local MunitionsFeature  = mod:io_dofile("RingHud/scripts/mods/RingHud/features/munitions_feature")
local ChargeFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/charge_feature")
local AbilityFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ability_feature")
local PocketableFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/pocketable_feature")

-- ## 2. CLASS DEFINITION ##
local HudElementRingHud = class("HudElementRingHud", "HudElementBase")

-- Consistent time source (match team/visibility.lua: ui -> gameplay -> os.clock)
local function _now_ui_pref()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

-- ## 3. PUBLIC LIFECYCLE METHODS ##

HudElementRingHud.init = function(self, parent, draw_layer, start_scale)
    HudElementRingHud.super.init(self, parent, draw_layer, start_scale, Definitions)

    -- Base scale captured from creation; we multiply this by user ring_scale each frame
    self._base_scale                             = self._scale or start_scale or 1

    self._remaining_efficient_dodges             = 0
    self._stamina_bar_latched_on                 = false
    self._health_change_visibility_duration      = 5.00
    self._health_change_visibility_timer         = 0
    self._previous_health_fraction               = -1
    self._previous_corruption_fraction           = -1
    self._previous_dmg_effective_length          = -1
    self._has_overshield_active                  = false
    self._previous_peril_fraction                = -1
    self._current_peril_color_argb               = { 200, 138, 201, 38 } -- TODO Color
    self._ammo_clip_latched_low                  = false
    self._latched_current_clip_ammo              = 0
    self._latched_max_clip_ammo                  = 0
    self._ammo_reserve_latched_low               = false
    self._latched_reserve_fraction_for_display   = 0
    self._latched_reserve_actual_for_display     = 0
    self._was_ability_on_cooldown_for_timer_text = false
    self._force_ammo_data_refresh                = false
    self._ammo_reserve_visibility_timer          = 0
    self._previous_reserve_fraction_for_timer    = -1
    self._last_logged_utd_state                  = {}
    self._pocketable_pickup_visibility_duration  = 5.0
    self._pocketable_pickup_visibility_timer     = 0
    self._last_picked_up_pocketable_name         = nil
    self._previous_stimm_item_name               = nil
    self._previous_crate_item_name               = nil
    self._is_music_intense_latched               = false
    self._music_intensity_failsafe_timer         = 0
    self._was_music_high_intensity               = false
    self._MUSIC_INTENSITY_FAILSAFE_DURATION      = 180

    if mod then
        mod.hud_instance = self
    end

    if not mod._wield_hook_applied then
        mod:hook(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded",
            function(func, weapon_ext_self, slot_name, t, skip_wield_action)
                local result = func(weapon_ext_self, slot_name, t, skip_wield_action)

                local local_player = Managers.player:local_player_safe(1)
                local local_player_unit = local_player and local_player.player_unit
                if not local_player_unit or weapon_ext_self._unit ~= local_player_unit then
                    return result
                end

                -- We only care about local-player wields from here
                local now                = _now_ui_pref()

                -- Try to read the template (for the existing heal-tool latch)
                local visual_loadout_ext = ScriptUnit.has_extension(weapon_ext_self._unit, "visual_loadout_system")
                    and ScriptUnit.extension(weapon_ext_self._unit, "visual_loadout_system") or nil
                local weapon_template    = visual_loadout_ext and visual_loadout_ext:weapon_template_from_slot(slot_name) or
                    nil
                local item_name          = weapon_template and weapon_template.name or ""

                -- =========================
                -- EXISTING: heal-tool latch
                -- =========================
                -- Keep: specifically corruption syringe OR medical crate → drives teammate HP reassurance rules.
                if item_name == "syringe_corruption_pocketable"
                    or item_name == "medical_crate_pocketable"
                then
                    -- Keep local player ring visible briefly (existing behavior)
                    if mod.hud_instance and mod.hud_instance._health_change_visibility_timer ~= nil then
                        mod.hud_instance._health_change_visibility_timer =
                            mod.hud_instance._health_change_visibility_duration
                    end

                    -- Publish heal-wield latch for teammate HP context rules
                    local heal_dur = (C and (C.LOCAL_WIELD_LATCH_SEC)) or 10
                    mod.local_wield_heal_tool_until = now + heal_dur
                end

                -- ===========================================
                -- NEW: ANY stimm / ANY crate (slot-based)
                -- ===========================================
                local latch_dur = (C and (C.WIELD_POCKETABLE_LATCH_SEC or C.LOCAL_WIELD_LATCH_SEC)) or 10

                -- Any stimm → small pocketable slot
                if slot_name == "slot_pocketable_small" then
                    mod.local_wield_any_stimm_until = now + latch_dur
                end

                -- Any crate → pocketable slot (med crate / ammo cache / future crates)
                if slot_name == "slot_pocketable" then
                    mod.local_wield_any_crate_until = now + latch_dur
                end

                -- NEW: specific ammo-cache wield latch (drives teammate munitions visibility)
                if item_name == "ammo_cache_pocketable" then
                    mod.local_wield_ammo_cache_until = now + latch_dur
                end

                return result
            end)
        mod._wield_hook_applied = true
    end

    -- Mark all player widgets as NON-team tiles so team code won't ever touch them.
    -- (Team-side writers should early-return unless widget._ringhud_is_team_tile == true)
    for _, w in pairs(self._widgets_by_name or {}) do
        w._ringhud_is_team_tile = false
    end
end

-- =============================================================
--  Scale handling
-- =============================================================

local function _clamp_scale(s)
    s = tonumber(s) or 1.0
    if s < 0.5 then s = 0.5 elseif s > 2.0 then s = 2.0 end
    return s
end

-- Shared ADS helpers ---------------------------------------------------------

local function _is_ads_now()
    local player = Managers.player:local_player_safe(1)
    if player and player.player_unit then
        local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")
        if unit_data_extension then
            local alternate_fire_comp = unit_data_extension:read_component("alternate_fire")
            return (alternate_fire_comp and alternate_fire_comp.is_active) or false
        end
    end
    return false
end

local function _effective_scale(is_ads)
    if is_ads then
        local s = mod._settings.ads_scale_override
        if s ~= nil then return _clamp_scale(tonumber(s) or 1.0) end
    end
    return _clamp_scale(mod._settings.ring_scale)
end

local function _effective_bias(is_ads)
    local b
    if is_ads then
        b = mod._settings.ads_offset_bias_override
        b = tonumber(b)
        if b ~= nil then
            if b < 0 then b = 0 elseif b > 200 then b = 200 end
            return b
        end
    end
    b = tonumber(mod._settings.ring_offset_bias) or 0
    if b < 0 then b = 0 elseif b > 200 then b = 200 end
    return b
end

local function _apply_shake_to_style_offset(live_style, base_x, base_y, base_z,
                                            apply_shake, dx, dy,
                                            extra_bias_x, extra_bias_y, scale)
    if not live_style then return false end

    local changed = false
    local s = _clamp_scale(scale)

    base_x = base_x or 0
    local base_y_ = base_y or 0
    local base_z_ = base_z or 0

    live_style.offset = live_style.offset or { base_x, base_y, base_z }

    local px_x = (extra_bias_x or 0)
    local px_y = (extra_bias_y or 0)
    if apply_shake then
        px_x = px_x + (dx or 0)
        px_y = px_y + (dy or 0)
    end

    local target_x = base_x + (px_x / s)
    local target_y = base_y + (px_y / s)

    if live_style.offset[1] ~= target_x then
        live_style.offset[1] = target_x; changed = true
    end
    if live_style.offset[2] ~= target_y then
        live_style.offset[2] = target_y; changed = true
    end
    if live_style.offset[3] ~= base_z then
        live_style.offset[3] = base_z; changed = true
    end

    return changed
end

HudElementRingHud.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod.is_enabled and mod:is_enabled()) then
        return
    end

    local ads_active = _is_ads_now()
    local s          = _effective_scale(ads_active)

    local rs         = render_settings or {}
    local prev_scale = rs.scale
    local prev_is    = rs.inverse_scale

    if s ~= 1 then
        local base_scale = prev_scale or RESOLUTION_LOOKUP.scale
        local base_inv   = prev_is or RESOLUTION_LOOKUP.inverse_scale
        rs.scale         = base_scale * s
        rs.inverse_scale = base_inv / s
    end

    HudElementRingHud.super.update(self, dt, t, ui_renderer, rs, input_service)

    if s ~= 1 then
        rs.scale = prev_scale
        rs.inverse_scale = prev_is
    end

    local widgets = self._widgets_by_name
    if not widgets or not widgets.peril_bar then return end

    -- ## UPDATE TIMERS AND LOCAL STATE FIRST ##
    if self._health_change_visibility_timer > 0 then
        self._health_change_visibility_timer = math.max(0, self._health_change_visibility_timer - dt)
    end
    if self._pocketable_pickup_visibility_timer > 0 then
        self._pocketable_pickup_visibility_timer = math.max(0, self._pocketable_pickup_visibility_timer - dt)
    end
    if mod._settings.ammo_reserve_dropdown ~= "ammo_reserve_disabled" then
        if self._ammo_reserve_visibility_timer > 0 then
            self._ammo_reserve_visibility_timer = math.max(0, self._ammo_reserve_visibility_timer - dt)
        end
    else
        self._ammo_reserve_visibility_timer = 0
    end

    -- ## FETCH LATEST GAME STATE ##
    local hud_state = RingHudState.get_hud_data_state(self)
    if not hud_state then return end

    -- ## PROCESS STATE AND UPDATE LATCHES ##
    local music_is_intense_now = hud_state.is_music_high_intensity
    local music_was_intense    = self._was_music_high_intensity
    if music_is_intense_now and not music_was_intense then
        self._is_music_intense_latched = true
        self._music_intensity_failsafe_timer = self._MUSIC_INTENSITY_FAILSAFE_DURATION
    elseif not music_is_intense_now and music_was_intense then
        self._is_music_intense_latched = false
        self._music_intensity_failsafe_timer = 0
    end
    if self._is_music_intense_latched then
        self._music_intensity_failsafe_timer = math.max(0, self._music_intensity_failsafe_timer - dt)
        if self._music_intensity_failsafe_timer == 0 then
            self._is_music_intense_latched = false
        end
    end
    self._was_music_high_intensity = music_is_intense_now

    if math.abs(hud_state.health_data.current_fraction - self._previous_health_fraction) > 0.001 or
        math.abs(hud_state.health_data.corruption_fraction - self._previous_corruption_fraction) > 0.001 then
        self._health_change_visibility_timer = self._health_change_visibility_duration
    end
    self._previous_health_fraction     = hud_state.health_data.current_fraction
    self._previous_corruption_fraction = hud_state.health_data.corruption_fraction
    self._has_overshield_active        = hud_state.toughness_data.has_overshield

    if hud_state.stimm_item_name and hud_state.stimm_item_name ~= self._previous_stimm_item_name then
        self._pocketable_pickup_visibility_timer = self._pocketable_pickup_visibility_duration
        self._last_picked_up_pocketable_name = hud_state.stimm_item_name
    end
    self._previous_stimm_item_name = hud_state.stimm_item_name

    if hud_state.crate_item_name and hud_state.crate_item_name ~= self._previous_crate_item_name then
        self._pocketable_pickup_visibility_timer = self._pocketable_pickup_visibility_duration
        self._last_picked_up_pocketable_name = hud_state.crate_item_name
    end
    self._previous_crate_item_name = hud_state.crate_item_name

    if self._stamina_bar_latched_on and hud_state.stamina_fraction >= 1.0 then
        self._stamina_bar_latched_on = false
    elseif (not self._stamina_bar_latched_on) and hud_state.stamina_fraction < 1.0 and
        hud_state.stamina_fraction <= (tonumber(mod._settings.stamina_viz_threshold) or 1.0) then
        self._stamina_bar_latched_on = true
    end

    -- Ammo: latch using numeric copy of hud_state.ammo_data (1.10-safe)
    local ad           = hud_state.ammo_data or {}
    local current_clip = tonumber(ad.current_clip) or 0
    local max_clip     = tonumber(ad.max_clip) or 0

    if ad.uses_ammo and max_clip > 0 then
        self._latched_current_clip_ammo = current_clip
        self._latched_max_clip_ammo     = max_clip

        if current_clip < max_clip and (current_clip / max_clip) < 0.45 then
            self._ammo_clip_latched_low = true
        else
            self._ammo_clip_latched_low = false
        end
    end

    if mod._settings.ammo_reserve_dropdown ~= "ammo_reserve_disabled" then
        if ad.max_reserve and ad.max_reserve > 0 then
            local reserve_frac = math.min((ad.current_reserve or 0) / ad.max_reserve, 1.0)
            if math.abs(reserve_frac - self._previous_reserve_fraction_for_timer) > 0.001 then
                self._ammo_reserve_visibility_timer = 3.0
            end
            self._previous_reserve_fraction_for_timer  = reserve_frac
            self._latched_reserve_fraction_for_display = reserve_frac
            self._latched_reserve_actual_for_display   = ad.current_reserve or 0
        else
            self._latched_reserve_fraction_for_display = 0
            self._latched_reserve_actual_for_display   = 0
        end
    end

    local hotkey_active_override = mod.show_all_hud_hotkey_active or false
    local vis_mode = mod._settings.ads_visibility_dropdown
    if vis_mode == "ads_vis_hotkey" and ads_active then
        hotkey_active_override = true
    end

    local widgets_by_name = self._widgets_by_name
    PerilFeature.update(self, widgets_by_name.peril_bar, hud_state, hotkey_active_override)
    SurvivalFeature.update_dodge(widgets_by_name.dodge_bar, hud_state, hotkey_active_override)
    SurvivalFeature.update_stamina(self, widgets_by_name.stamina_bar, hud_state, hotkey_active_override)
    SurvivalFeature.update_toughness_and_health(self, widgets_by_name, hud_state, hotkey_active_override)
    SurvivalFeature.update_health_text(self, widgets_by_name.health_text_display_widget, hud_state,
        hotkey_active_override)
    MunitionsFeature.update_grenades(widgets_by_name.grenade_bar, hud_state, hotkey_active_override)
    MunitionsFeature.update_ammo_clip_bar(self, widgets_by_name.ammo_clip_bar, hud_state, hotkey_active_override)
    MunitionsFeature.update_ammo_reserve_text(self, widgets_by_name.ammo_reserve_display_widget, hud_state,
        hotkey_active_override)
    MunitionsFeature.update_ammo_clip_text(self, widgets_by_name.ammo_clip_text_display_widget, hud_state,
        hotkey_active_override)
    ChargeFeature.update(widgets_by_name.charge_bar, hud_state, hotkey_active_override)
    AbilityFeature.update(widgets_by_name.ability_timer, hud_state, hotkey_active_override)
    PocketableFeature.update(widgets_by_name, hud_state, hotkey_active_override)

    if not hud_state.player_extensions then
        self._previous_health_fraction             = -1
        self._previous_corruption_fraction         = -1
        self._previous_dmg_effective_length        = -1
        self._previous_reserve_fraction_for_timer  = -1
        self._latched_reserve_fraction_for_display = 0
        self._ammo_reserve_latched_low             = false
        self._latched_current_clip_ammo            = 0
        self._latched_max_clip_ammo                = 0
        self._ammo_clip_latched_low                = false
        self._ammo_reserve_visibility_timer        = 0
        self._latched_reserve_actual_for_display   = 0
    end
end

-- ## 4. PRIVATE HELPER METHODS ##

HudElementRingHud._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
    local widgets = self._widgets_by_name
    if not widgets then return end

    local dx          = mod.current_crosshair_delta_x
    local dy          = mod.current_crosshair_delta_y

    -- ADS-aware apply_shake
    local ads_active  = _is_ads_now()
    local apply_shake = false
    local shake_mode  = mod._settings.crosshair_shake_dropdown

    if shake_mode == "crosshair_shake_always" then
        local player = Managers.player:local_player_safe(1)
        if player and player.player_unit then
            local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")
            local health_extension    = ScriptUnit.has_extension(player.player_unit, "health_system")
            if unit_data_extension and health_extension then
                local character_state_comp = unit_data_extension:read_component("character_state")
                if not PlayerUnitStatus.is_dead(character_state_comp, health_extension) then
                    apply_shake = true
                end
            elseif health_extension and health_extension:is_alive() then
                apply_shake = true
            end
        end
    elseif shake_mode == "crosshair_shake_ads" then
        apply_shake = ads_active
    end

    -- Global offset bias (px), ADS-aware
    local user_bias = _effective_bias(ads_active)

    -- Scale & centering, ADS-aware
    local s         = _effective_scale(ads_active)
    local rw        = RESOLUTION_LOOKUP.res_w or 1920
    local rh        = RESOLUTION_LOOKUP.res_h or 1080
    local center_dx = (1 - s) * (rw * 0.5)
    local center_dy = (1 - s) * (rh * 0.5)

    -- -------------- PERIL BAR + TEXT --------------
    local pb        = widgets.peril_bar
    if pb and pb.style then
        local changed = false
        if pb.style.peril_bar then
            if _apply_shake_to_style_offset(pb.style.peril_bar, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias + center_dx, user_bias + center_dy, s) then
                changed = true
            end
        end
        -- NEW: keep the peril edge sliver in perfect sync with the base
        if pb.style.peril_edge then
            if _apply_shake_to_style_offset(pb.style.peril_edge, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias + center_dx, user_bias + center_dy, s) then
                changed = true
            end
        end
        if pb.style.percent_text then
            local base_x = -Definitions.text_offset - 3
            local base_y = Definitions.offset_correction
            if _apply_shake_to_style_offset(pb.style.percent_text, base_x, base_y, 2, apply_shake, dx, dy,
                    -user_bias + center_dx, user_bias + center_dy, s) then
                changed = true
            end
        end
        if changed then pb.dirty = true end
    end

    -- -------------- DODGE --------------
    local db = widgets.dodge_bar
    if db and db.style then
        local changed = false
        for i = 1, (mod.MAX_DODGE_SEGMENTS or 6) do
            local st = db.style["dodge_bar_" .. i]
            if st and _apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                    user_bias + center_dx, -user_bias + center_dy, s) then
                changed = true
            end
        end
        if changed then db.dirty = true end
    end

    -- -------------- STAMINA --------------
    local sb = widgets.stamina_bar
    if sb and sb.style then
        local changed = false
        if sb.style.stamina_bar and
            _apply_shake_to_style_offset(sb.style.stamina_bar, 0, 0, 1, apply_shake, dx, dy,
                -user_bias + center_dx, -user_bias + center_dy, s) then
            changed = true
        end
        -- keep the edge sliver perfectly in sync (z=2 to preserve layering)
        if sb.style.stamina_edge and
            _apply_shake_to_style_offset(sb.style.stamina_edge, 0, 0, 2, apply_shake, dx, dy,
                -user_bias + center_dx, -user_bias + center_dy, s) then
            changed = true
        end
        if changed then sb.dirty = true end
    end

    -- -------------- CHARGE --------------
    local cb = widgets.charge_bar
    if cb and cb.style then
        local changed = false
        if cb.style.charge_bar_1 and _apply_shake_to_style_offset(cb.style.charge_bar_1, 0, 0, 1, apply_shake, dx, dy,
                user_bias + center_dx, user_bias + center_dy, s) then
            changed = true
        end
        -- NEW: edge sliver for segment 1 (z=2)
        if cb.style.charge_bar_1_edge and _apply_shake_to_style_offset(cb.style.charge_bar_1_edge, 0, 0, 2, apply_shake, dx, dy,
                user_bias + center_dx, user_bias + center_dy, s) then
            changed = true
        end
        if cb.style.charge_bar_2 and _apply_shake_to_style_offset(cb.style.charge_bar_2, 0, 0, 2, apply_shake, dx, dy,
                user_bias + center_dx, user_bias + center_dy, s) then
            changed = true
        end
        -- NEW: edge sliver for segment 2 (z=3)
        if cb.style.charge_bar_2_edge and _apply_shake_to_style_offset(cb.style.charge_bar_2_edge, 0, 0, 3, apply_shake, dx, dy,
                user_bias + center_dx, user_bias + center_dy, s) then
            changed = true
        end
        if changed then cb.dirty = true end
    end

    -- -------------- TOUGHNESS / HP RING (3 layers) --------------
    local tcor = widgets.toughness_bar_corruption
    if tcor and tcor.style and tcor.style.corruption_segment then
        if _apply_shake_to_style_offset(tcor.style.corruption_segment, 0, 0, 0, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.1) + center_dy, s) then
            tcor.dirty = true
        end
        -- NEW: keep the corruption edge sliver aligned (z=1)
        if tcor.style.corruption_segment_edge and
            _apply_shake_to_style_offset(tcor.style.corruption_segment_edge, 0, 0, 1, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.5) + center_dy, s) then
            tcor.dirty = true
        end
    end
    local thp = widgets.toughness_bar_health
    if thp and thp.style and thp.style.health_segment then
        if _apply_shake_to_style_offset(thp.style.health_segment, 0, 0, 1, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.5) + center_dy, s) then
            thp.dirty = true
        end
        -- NEW: keep the health edge sliver aligned (z=2)
        if thp.style.health_segment_edge and
            _apply_shake_to_style_offset(thp.style.health_segment_edge, 0, 0, 2, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.5) + center_dy, s) then
            thp.dirty = true
        end
    end
    local tdm = widgets.toughness_bar_damage
    if tdm and tdm.style and tdm.style.damage_segment then
        if _apply_shake_to_style_offset(tdm.style.damage_segment, 0, 0, 2, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.5) + center_dy, s) then
            tdm.dirty = true
        end
        -- NEW: keep the damage edge sliver aligned (z=3)
        if tdm.style.damage_segment_edge and
            _apply_shake_to_style_offset(tdm.style.damage_segment_edge, 0, 0, 3, apply_shake, dx, dy,
                0 + center_dx, (user_bias * 1.5) + center_dy, s) then
            tdm.dirty = true
        end
    end

    -- -------------- GRENADES --------------
    local gb = widgets.grenade_bar
    if gb and gb.style then
        local changed = false
        for i = 1, (mod.MAX_GRENADE_SEGMENTS_DISPLAY or 6) do
            local st  = gb.style["grenade_segment_" .. i]
            local ste = gb.style["grenade_segment_edge_" .. i]
            if st and _apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                    0 + center_dx, user_bias + center_dy, s) then
                changed = true
            end
            if ste and _apply_shake_to_style_offset(ste, 0, 0, 2, apply_shake, dx, dy,
                    0 + center_dx, user_bias + center_dy, s) then
                changed = true
            end
        end
        if changed then gb.dirty = true end
    end

    -- -------------- AMMO CLIP BAR --------------
    local acb = widgets.ammo_clip_bar
    if acb and acb.style then
        local changed = false
        if acb.style.ammo_clip_unfilled_background and _apply_shake_to_style_offset(acb.style.ammo_clip_unfilled_background, 0, 0, 0, apply_shake, dx, dy,
                -user_bias + center_dx, -user_bias + center_dy, s) then
            changed = true
        end
        if acb.style.ammo_clip_filled_single and _apply_shake_to_style_offset(acb.style.ammo_clip_filled_single, 0, 0, 1, apply_shake, dx, dy,
                -user_bias + center_dx, -user_bias + center_dy, s) then
            changed = true
        end
        for i = 1, (mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 5) do
            local st = acb.style["ammo_clip_filled_multi_" .. i]
            if st and _apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias + center_dx, -user_bias + center_dy, s) then
                changed = true
            end
        end
        if changed then acb.dirty = true end
    end

    -- -------------- STIMM / CRATE ICONS --------------
    local stw = widgets.stimm_indicator_widget
    if stw and stw.style and stw.style.stimm_icon then
        if _apply_shake_to_style_offset(stw.style.stimm_icon, 0, 0, 0, apply_shake, dx, dy,
                user_bias + center_dx, -user_bias + center_dy, s) then
            stw.dirty = true
        end
    end

    local cw = widgets.crate_indicator_widget
    if cw and cw.style and cw.style.crate_icon then
        if _apply_shake_to_style_offset(cw.style.crate_icon, 0, 0, 0, apply_shake, dx, dy,
                user_bias + center_dx, -user_bias + center_dy, s) then
            cw.dirty = true
        end
    end

    -- -------------- TEXT WIDGETS --------------
    local at = widgets.ability_timer
    if at and at.style and at.style.ability_text then
        local base_x = Definitions.text_offset
        local base_y = Definitions.offset_correction
        if _apply_shake_to_style_offset(at.style.ability_text, base_x, base_y, 2, apply_shake, dx, dy,
                user_bias + center_dx, user_bias + center_dy, s) then
            at.dirty = true
        end
    end

    local ar = widgets.ammo_reserve_display_widget
    if ar and ar.style and ar.style.reserve_text_style then
        if _apply_shake_to_style_offset(ar.style.reserve_text_style, 0, 0, 2, apply_shake, dx, dy,
                -user_bias + center_dx, -user_bias + center_dy, s) then
            ar.dirty = true
        end
    end

    local act = widgets.ammo_clip_text_display_widget
    if act and act.style and act.style.ammo_clip_text_style then
        if _apply_shake_to_style_offset(act.style.ammo_clip_text_style, 0, 0, 1, apply_shake, dx, dy,
                -user_bias + center_dx, 0 + center_dy, s) then
            act.dirty = true
        end
    end

    local ht = widgets.health_text_display_widget
    if ht and ht.style and ht.style.health_text_style then
        if _apply_shake_to_style_offset(ht.style.health_text_style, 0, 0, 1, apply_shake, dx, dy,
                0 + center_dx, user_bias + center_dy, s) then
            ht.dirty = true
        end
    end

    -- Draw with current element scale (set in update via render_settings)
    HudElementRingHud.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

-- Override draw so we can scale BEFORE the renderer's begin_pass.
function HudElementRingHud:draw(dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod.is_enabled and mod:is_enabled()) then
        return
    end

    -- NEW: hide all player widgets when the local player is dead (or no alive unit)
    do
        local player = Managers.player:local_player_safe(1)
        local unit = player and player.player_unit
        local is_dead = true -- default to "suppress" unless we can prove alive
        if unit and Unit.alive(unit) then
            local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
            local health_extension    = ScriptUnit.has_extension(unit, "health_system")
            if unit_data_extension and health_extension then
                local character_state_comp = unit_data_extension:read_component("character_state")
                is_dead = PlayerUnitStatus.is_dead(character_state_comp, health_extension)
            else
                -- if we can't read components, fall back to allowing draw
                is_dead = false
            end
        end
        if is_dead then
            return
        end
    end

    local ads_active = _is_ads_now()
    local vis_mode   = mod._settings.ads_visibility_dropdown
    if (vis_mode == "ads_vis_hide_in_ads" and ads_active) or
        (vis_mode == "ads_vis_hide_outside_ads" and not ads_active) then
        return
    end

    local s          = _effective_scale(ads_active)

    local rs         = render_settings or {}
    local prev_scale = rs.scale
    local prev_is    = rs.inverse_scale

    if s ~= 1 then
        local base_scale = prev_scale or RESOLUTION_LOOKUP.scale
        local base_inv   = prev_is or RESOLUTION_LOOKUP.inverse_scale
        rs.scale         = base_scale * s
        rs.inverse_scale = base_inv / s
    end

    -- No pcall: let errors surface normally
    HudElementRingHud.super.draw(self, dt, t, ui_renderer, rs, input_service)

    -- restore
    if s ~= 1 then
        rs.scale = prev_scale
        rs.inverse_scale = prev_is
    end
end

return HudElementRingHud
