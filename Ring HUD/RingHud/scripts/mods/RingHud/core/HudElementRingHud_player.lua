-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_player.lua

local mod = get_mod("RingHud")
if not mod then return end

-- ## 1. DEPENDENCIES ##
local RingHudState       = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_player")
local Definitions        = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_player") or {}
local PlayerUnitStatus   = require("scripts/utilities/attack/player_unit_status")

local PerilFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/peril_feature") or {}
local DodgeFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/dodge_feature") or {}
local StaminaFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/stamina_feature") or {}
local ToughnessHpFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/toughness_hp_feature") or {}
local GrenadesFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/grenades_feature") or {}
local AmmoReserveFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ammo_reserve_feature") or {}
local AmmoClipFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ammo_clip_feature") or {}
local ChargeFeature      = mod:io_dofile("RingHud/scripts/mods/RingHud/features/charge_feature") or {}
local AbilityFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ability_feature") or {}
local PocketableFeature  = mod:io_dofile("RingHud/scripts/mods/RingHud/features/pocketable_feature") or {}

local Intensity          = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

mod:io_dofile("RingHud/scripts/mods/RingHud/context/wield_context")

-- ## 2. CLASS DEFINITION ##
local HudElementRingHud_player = class("HudElementRingHud_player", "HudElementBase")

-- ## 3. PUBLIC LIFECYCLE METHODS ##

HudElementRingHud_player.init = function(self, parent, draw_layer, start_scale)
    HudElementRingHud_player.super.init(self, parent, draw_layer, start_scale, Definitions)

    self._remaining_efficient_dodges             = 0
    self._stamina_bar_latched_on                 = false
    self._previous_health_fraction               = -1
    self._previous_corruption_fraction           = -1
    self._previous_dmg_effective_length          = -1
    self._previous_peril_fraction                = -1
    self._current_peril_color_argb               = { 200, 138, 201, 38 }
    self._ammo_clip_latched_low                  = false
    self._latched_current_clip_ammo              = 0
    self._latched_max_clip_ammo                  = 0
    self._prev_reserve_frac_for_bump             = nil
    self._was_ability_on_cooldown_for_timer_text = false
    self._force_ammo_data_refresh                = false
    self._last_logged_utd_state                  = {}
    self._pocketable_pickup_visibility_duration  = 5.0
    self._pocketable_pickup_visibility_timer     = 0
    self._last_picked_up_pocketable_name         = nil
    self._previous_stimm_item_name               = nil
    self._previous_crate_item_name               = nil

    -- Cache state for draw
    self._ads_active                             = false
    self._apply_shake                            = false

    if mod then
        mod.hud_instance = self
    end

    for _, w in pairs(self._widgets_by_name or {}) do
        w._ringhud_is_team_tile = false
    end
end

HudElementRingHud_player.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod.is_enabled and mod:is_enabled()) then
        return
    end

    Intensity.update(dt, t)

    -- Rebuild-on-demand
    if mod._ringhud_needs_rebuild then
        mod._ringhud_needs_rebuild = false

        local new_defs = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_player")
        if type(new_defs) == "table" then
            Definitions = new_defs
        end

        if self.destroy then
            self:destroy(self._ui_renderer)
        end
        HudElementRingHud_player.super.init(self, self._parent, self._draw_layer, self._scale, Definitions)

        for _, w in pairs(self._widgets_by_name or {}) do
            w._ringhud_is_team_tile = false
        end
    end

    -- ADS & Shake Calculation (Optimization)
    local ads_active = U.is_ads_now()
    self._ads_active = ads_active

    -- ADS scale override
    if ads_active ~= self._was_ads then
        self._was_ads = ads_active
        local ads_s = tonumber(mod._settings.ads_scale_override)
        mod._runtime_overrides = mod._runtime_overrides or {}
        if ads_active and ads_s and ads_s > 0 then
            mod._runtime_overrides.ring_scale = ads_s
        else
            mod._runtime_overrides.ring_scale = nil
        end
        mod._ringhud_needs_rebuild = true
    end

    HudElementRingHud_player.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    local widgets = self._widgets_by_name
    if not widgets or not widgets.peril_bar then return end

    if self._pocketable_pickup_visibility_timer > 0 then
        self._pocketable_pickup_visibility_timer = math.max(0, self._pocketable_pickup_visibility_timer - dt)
    end

    local hud_state = RingHudState.get_hud_data_state(self)
    if not hud_state then return end

    -- Determine shake (cached for draw)
    self._apply_shake = false
    local shake_mode = mod._settings.crosshair_shake_dropdown
    if shake_mode == "crosshair_shake_ads" then
        self._apply_shake = ads_active
    elseif shake_mode == "crosshair_shake_always" then
        -- Fast alive check using cached extensions
        if hud_state.player_extensions then
            local ud = hud_state.player_extensions.unit_data
            local he = hud_state.player_extensions.health
            if ud and he then
                local cs = ud:read_component("character_state")
                if cs and not PlayerUnitStatus.is_dead(cs, he) then
                    self._apply_shake = true
                end
            end
        end
    end

    -- Update logic (unchanged)
    if math.abs(hud_state.health_data.current_fraction - self._previous_health_fraction) > 0.001 or
        math.abs(hud_state.health_data.corruption_fraction - self._previous_corruption_fraction) > 0.001 then
        if mod.thv_player_recent_change_bump then
            mod.thv_player_recent_change_bump()
        end
    end
    self._previous_health_fraction     = hud_state.health_data.current_fraction
    self._previous_corruption_fraction = hud_state.health_data.corruption_fraction

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

    local ad = hud_state.ammo_data
    do
        local uses_ammo    = ad.uses_ammo and true or false
        local current_clip = tonumber(ad.current_clip) or 0
        local max_clip     = tonumber(ad.max_clip) or 0

        if uses_ammo and max_clip > 0 then
            self._latched_current_clip_ammo = current_clip
            self._latched_max_clip_ammo     = max_clip
            self._ammo_clip_latched_low     = (current_clip / max_clip) < 0.45 and current_clip < max_clip
        end
    end

    if mod._settings.ammo_reserve_dropdown ~= "ammo_reserve_disabled" then
        local max_reserve = tonumber(ad.max_reserve) or 0
        local cur_reserve = tonumber(ad.current_reserve) or 0

        if max_reserve > 0 then
            local reserve_frac = math.min(cur_reserve / max_reserve, 1.0)
            local prev         = self._prev_reserve_frac_for_bump
            if prev ~= nil and math.abs(reserve_frac - prev) > 0.001 then
                if mod.ammo_vis_player_recent_change_bump then
                    mod.ammo_vis_player_recent_change_bump()
                end
            end
            self._prev_reserve_frac_for_bump = reserve_frac
        else
            self._prev_reserve_frac_for_bump = nil
        end
    else
        self._prev_reserve_frac_for_bump = nil
    end

    local hotkey_active_override = mod.show_all_hud_hotkey_active or false
    local vis_mode               = mod._settings.ads_visibility_dropdown
    if vis_mode == "ads_vis_hotkey" and ads_active then
        hotkey_active_override = true
    end

    -- Feature Updates
    if PerilFeature.update then PerilFeature.update(self, widgets.peril_bar, hud_state, hotkey_active_override) end
    if DodgeFeature.update then DodgeFeature.update(widgets.dodge_bar, hud_state, hotkey_active_override) end
    if StaminaFeature.update then StaminaFeature.update(self, widgets.stamina_bar, hud_state, hotkey_active_override) end
    if ToughnessHpFeature.update then ToughnessHpFeature.update(self, widgets, hud_state, hotkey_active_override) end
    if ToughnessHpFeature.update_health_text then
        ToughnessHpFeature.update_health_text(self, widgets.health_text_display_widget, hud_state, hotkey_active_override)
    end
    if GrenadesFeature.update then GrenadesFeature.update(self, widgets.grenade_bar, hud_state, hotkey_active_override) end
    if AmmoClipFeature.update_bar then
        AmmoClipFeature.update_bar(self, widgets.ammo_clip_bar, hud_state,
            hotkey_active_override)
    end
    if AmmoReserveFeature.update_text then
        AmmoReserveFeature.update_text(self, widgets.ammo_reserve_display_widget, hud_state, hotkey_active_override)
    end
    if AmmoClipFeature.update_text then
        AmmoClipFeature.update_text(self, widgets.ammo_clip_text_display_widget, hud_state, hotkey_active_override)
    end
    if ChargeFeature.update then ChargeFeature.update(widgets.charge_bar, hud_state, hotkey_active_override) end
    if AbilityFeature.update then AbilityFeature.update(widgets.ability_timer, hud_state, hotkey_active_override) end
    if PocketableFeature.update then PocketableFeature.update(widgets, hud_state, hotkey_active_override) end

    if not hud_state.player_extensions then
        self._previous_health_fraction      = -1
        self._previous_corruption_fraction  = -1
        self._previous_dmg_effective_length = -1
        self._prev_reserve_frac_for_bump    = nil
        self._latched_current_clip_ammo     = 0
        self._latched_max_clip_ammo         = 0
        self._ammo_clip_latched_low         = false
    end
end

-- ## 4. DRAWING ##

HudElementRingHud_player._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
    local widgets = self._widgets_by_name
    if not widgets then return end

    local dx, dy = 0, 0
    if mod.crosshair and mod.crosshair.get_offset then
        dx, dy = mod.crosshair.get_offset()
    end

    -- Use cached state from update()
    local ads_active   = self._ads_active
    local apply_shake  = self._apply_shake
    local user_bias_px = U.effective_bias(ads_active)

    -- -------------- PERIL BAR + TEXT --------------
    do
        local pb = widgets.peril_bar
        if pb and pb.style then
            local changed = false
            if pb.style.peril_bar then
                if U.apply_shake_to_style_offset(pb.style.peril_bar, 0, 0, 1, apply_shake, dx, dy,
                        -user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if pb.style.peril_edge then
                if U.apply_shake_to_style_offset(pb.style.peril_edge, 0, 0, 1, apply_shake, dx, dy,
                        -user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if pb.style.peril_other_edge then
                if U.apply_shake_to_style_offset(pb.style.peril_other_edge, 0, 0, 1, apply_shake, dx, dy,
                        -user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if pb.style.percent_text then
                local base_x = -Definitions.text_offset - 3
                local base_y = Definitions.offset_correction
                if U.apply_shake_to_style_offset(pb.style.percent_text, base_x, base_y, 2, apply_shake, dx, dy,
                        -user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if changed then pb.dirty = true end
        end
    end

    -- -------------- DODGE --------------
    do
        local db = widgets.dodge_bar
        if db and db.style then
            local changed = false
            for i = 1, (mod.MAX_DODGE_SEGMENTS or 6) do
                local st = db.style["dodge_bar_" .. i]
                if st and U.apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        user_bias_px, -user_bias_px) then
                    changed = true
                end
            end
            if changed then db.dirty = true end
        end
    end

    -- -------------- STAMINA --------------
    do
        local sb = widgets.stamina_bar
        if sb and sb.style then
            local changed = false
            if sb.style.stamina_bar and
                U.apply_shake_to_style_offset(sb.style.stamina_bar, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias_px, -user_bias_px) then
                changed = true
            end
            if sb.style.stamina_edge and
                U.apply_shake_to_style_offset(sb.style.stamina_edge, 0, 0, 2, apply_shake, dx, dy,
                    -user_bias_px, -user_bias_px) then
                changed = true
            end
            if changed then sb.dirty = true end
        end
    end

    -- -------------- CHARGE --------------
    do
        local cb = widgets.charge_bar
        if cb and cb.style then
            local changed = false

            -- Legacy 2-segment bar (still used for non-dual-shivs)
            if cb.style.charge_bar_1 and U.apply_shake_to_style_offset(
                    cb.style.charge_bar_1, 0, 0, 1, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_1_edge and U.apply_shake_to_style_offset(
                    cb.style.charge_bar_1_edge, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_2 and U.apply_shake_to_style_offset(
                    cb.style.charge_bar_2, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_2_edge and U.apply_shake_to_style_offset(
                    cb.style.charge_bar_2_edge, 0, 0, 3, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end

            -- New: segmented dual-shivs passes (if present)
            local max_segments = mod.MAX_CHARGE_SEGMENTS or 6
            for i = 1, max_segments do
                local st  = cb.style["charge_seg_" .. i]
                local ste = cb.style["charge_seg_edge_" .. i]

                if st and U.apply_shake_to_style_offset(
                        st, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                    ) then
                    changed = true
                end
                if ste and U.apply_shake_to_style_offset(
                        ste, 0, 0, 3, apply_shake, dx, dy, user_bias_px, user_bias_px
                    ) then
                    changed = true
                end
            end

            if changed then cb.dirty = true end
        end
    end

    -- -------------- TOUGHNESS / HP RING (3 layers) --------------
    do
        local tcor = widgets.toughness_bar_corruption
        if tcor and tcor.style and tcor.style.corruption_segment then
            if U.apply_shake_to_style_offset(tcor.style.corruption_segment, 0, 0, 0, apply_shake, dx, dy,
                    0, (user_bias_px * 1.1)) then
                tcor.dirty = true
            end
            if tcor.style.corruption_segment_edge and
                U.apply_shake_to_style_offset(tcor.style.corruption_segment_edge, 0, 0, 1, apply_shake, dx, dy,
                    0, (user_bias_px * 1.5)) then
                tcor.dirty = true
            end
        end

        local thp = widgets.toughness_bar_health
        if thp and thp.style and thp.style.health_segment then
            if U.apply_shake_to_style_offset(thp.style.health_segment, 0, 0, 1, apply_shake, dx, dy,
                    0, (user_bias_px * 1.5)) then
                thp.dirty = true
            end
            if thp.style.health_segment_edge and
                U.apply_shake_to_style_offset(thp.style.health_segment_edge, 0, 0, 2, apply_shake, dx, dy,
                    0, (user_bias_px * 1.5)) then
                thp.dirty = true
            end
        end

        local tdm = widgets.toughness_bar_damage
        if tdm and tdm.style and tdm.style.damage_segment then
            if U.apply_shake_to_style_offset(tdm.style.damage_segment, 0, 0, 2, apply_shake, dx, dy,
                    0, (user_bias_px * 1.5)) then
                tdm.dirty = true
            end
            if tdm.style.damage_segment_edge and
                U.apply_shake_to_style_offset(tdm.style.damage_segment_edge, 0, 0, 3, apply_shake, dx, dy,
                    0, (user_bias_px * 1.5)) then
                tdm.dirty = true
            end
        end
    end

    -- -------------- GRENADES --------------
    do
        local gb = widgets.grenade_bar
        if gb and gb.style then
            local changed = false
            for i = 1, (mod.MAX_GRENADE_SEGMENTS_DISPLAY or 6) do
                local st  = gb.style["grenade_segment_" .. i]
                local ste = gb.style["grenade_segment_edge_" .. i]
                if st and U.apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        0, user_bias_px) then
                    changed = true
                end
                if ste and U.apply_shake_to_style_offset(ste, 0, 0, 2, apply_shake, dx, dy,
                        0, user_bias_px) then
                    changed = true
                end
            end
            if changed then gb.dirty = true end
        end
    end

    -- -------------- AMMO CLIP BAR --------------
    do
        local acb = widgets.ammo_clip_bar
        if acb and acb.style then
            local changed = false
            if acb.style.ammo_clip_unfilled_background and U.apply_shake_to_style_offset(acb.style.ammo_clip_unfilled_background, 0, 0, 0, apply_shake, dx, dy,
                    -user_bias_px, -user_bias_px) then
                changed = true
            end
            if acb.style.ammo_clip_filled_single and U.apply_shake_to_style_offset(acb.style.ammo_clip_filled_single, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias_px, -user_bias_px) then
                changed = true
            end
            for i = 1, (mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 5) do
                local st = acb.style["ammo_clip_filled_multi_" .. i]
                if st and U.apply_shake_to_style_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        -user_bias_px, -user_bias_px) then
                    changed = true
                end
            end
            if changed then acb.dirty = true end
        end
    end

    -- -------------- STIMM / CRATE ICONS --------------
    do
        local stw = widgets.stimm_indicator_widget
        if stw and stw.style then
            local changed = false
            if stw.style.stimm_icon then
                if U.apply_shake_to_style_offset(stw.style.stimm_icon, 0, 0, 0, apply_shake, dx, dy,
                        user_bias_px, -user_bias_px) then
                    changed = true
                end
            end

            if stw.style.stimm_timer_text then
                if U.apply_shake_to_style_offset(stw.style.stimm_timer_text, 0, 0, 1, apply_shake, dx, dy,
                        user_bias_px, -user_bias_px) then
                    changed = true
                end
            end

            if changed then stw.dirty = true end
        end

        local cw = widgets.crate_indicator_widget
        if cw and cw.style and cw.style.crate_icon then
            if U.apply_shake_to_style_offset(cw.style.crate_icon, 0, 0, 0, apply_shake, dx, dy,
                    user_bias_px, -user_bias_px) then
                cw.dirty = true
            end
        end
    end

    -- -------------- TEXT WIDGETS --------------
    do
        local at = widgets.ability_timer
        if at and at.style and at.style.ability_text then
            local base_x = Definitions.text_offset
            local base_y = Definitions.offset_correction
            if U.apply_shake_to_style_offset(at.style.ability_text, base_x, base_y, 2, apply_shake, dx, dy,
                    user_bias_px, user_bias_px) then
                at.dirty = true
            end
        end

        local ar = widgets.ammo_reserve_display_widget
        if ar and ar.style and ar.style.reserve_text_style then
            if U.apply_shake_to_style_offset(ar.style.reserve_text_style, 0, 0, 2, apply_shake, dx, dy,
                    -user_bias_px, -user_bias_px) then
                ar.dirty = true
            end
        end

        local act = widgets.ammo_clip_text_display_widget
        if act and act.style and act.style.ammo_clip_text_style then
            if U.apply_shake_to_style_offset(act.style.ammo_clip_text_style, 0, 0, 1, apply_shake, dx, dy,
                    -user_bias_px, 0) then
                act.dirty = true
            end
        end

        local ht = widgets.health_text_display_widget
        if ht and ht.style and ht.style.health_text_style then
            if U.apply_shake_to_style_offset(ht.style.health_text_style, 0, 0, 1, apply_shake, dx, dy,
                    0, user_bias_px) then
                ht.dirty = true
            end
        end
    end

    HudElementRingHud_player.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

function HudElementRingHud_player:draw(dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod:is_enabled()) then
        return
    end

    local is_dead = false
    -- Optimized dead check using cached state if possible, or fast lookup
    if self._apply_shake then
        is_dead = false
    else
        -- Fallback check similar to before but simpler
        local player = Managers.player:local_player_safe(1)
        if player and player.player_unit then
            local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system")
            local health_extension = ScriptUnit.has_extension(player.player_unit, "health_system")
            if unit_data_extension and health_extension then
                local cs = unit_data_extension:read_component("character_state")
                is_dead = PlayerUnitStatus.is_dead(cs, health_extension)
            end
        end
    end
    if is_dead then return end

    local ads_active = self._ads_active -- cached
    local vis_mode   = mod._settings.ads_visibility_dropdown
    if (vis_mode == "ads_vis_hide_in_ads" and ads_active) or
        (vis_mode == "ads_vis_hide_outside_ads" and not ads_active) then
        return
    end

    HudElementRingHud_player.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementRingHud_player
