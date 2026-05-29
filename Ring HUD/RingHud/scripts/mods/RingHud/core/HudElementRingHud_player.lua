-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_player.lua

local mod = get_mod("RingHud")
if not mod then return end

-- ## 1. DEPENDENCIES ##
local RingHudState       = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_player")
local Definitions        = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_player")
local PlayerUnitStatus   = require("scripts/utilities/attack/player_unit_status")

local PerilFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/peril_feature")
local DodgeFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/dodge_feature")
local StaminaFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/stamina_feature")
local ToughnessHpFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/toughness_hp_feature")
local GrenadesFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/grenades_feature")
local AmmoReserveFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ammo_reserve_feature")
local AmmoClipFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ammo_clip_feature")
local ChargeFeature      = mod:io_dofile("RingHud/scripts/mods/RingHud/features/charge_feature")
local AbilityFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ability_feature")
local PocketableFeature  = mod:io_dofile("RingHud/scripts/mods/RingHud/features/pocketable_feature")

local TalentFeature      = mod:io_dofile("RingHud/scripts/mods/RingHud/features/talent_feature")

local Intensity          = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

mod:io_dofile("RingHud/scripts/mods/RingHud/context/wield_context")

local math_abs             = math.abs
local math_max             = math.max
local tonumber             = tonumber
local apply_shake_offset   = U.apply_shake_to_style_offset

-- PERFORMANCE: Pre-generate string keys to prevent constant string allocations/concatenations every frame
local MAX_PREGEN           = 30
local STR_DODGE_BAR        = {}
local STR_CHARGE_SEG       = {}
local STR_CHARGE_SEG_EDGE  = {}
local STR_GRENADE_SEG      = {}
local STR_GRENADE_SEG_EDGE = {}
local STR_AMMO_MULTI       = {}
local STR_TALENT_SEG       = {}
local STR_ADAMANT_SEG      = {}
local STR_ADAMANT_SEG_EDGE = {}

for i = 1, MAX_PREGEN do
    STR_DODGE_BAR[i]        = "dodge_bar_" .. i
    STR_CHARGE_SEG[i]       = "charge_seg_" .. i
    STR_CHARGE_SEG_EDGE[i]  = "charge_seg_edge_" .. i
    STR_GRENADE_SEG[i]      = "grenade_segment_" .. i
    STR_GRENADE_SEG_EDGE[i] = "grenade_segment_edge_" .. i
    STR_AMMO_MULTI[i]       = "ammo_clip_filled_multi_" .. i
    STR_TALENT_SEG[i]       = "talent_seg_" .. i
    STR_ADAMANT_SEG[i]      = "talent_adamant_seg_" .. i
    STR_ADAMANT_SEG_EDGE[i] = "talent_adamant_seg_" .. i .. "_edge"
end

-- ## 2. CLASS DEFINITION ##
local HudElementRingHud_player         = class("HudElementRingHud_player", "HudElementBase")

-- ## 3. PUBLIC LIFECYCLE METHODS ##

HudElementRingHud_player.init          = function(self, parent, draw_layer, start_scale)
    HudElementRingHud_player.super.init(self, parent, draw_layer, start_scale, Definitions)

    self._remaining_efficient_dodges             = 0
    self._stamina_bar_latched_on                 = false
    self._previous_health_fraction               = -1
    self._previous_corruption_fraction           = -1
    self._previous_dmg_effective_length          = -1
    self._previous_peril_fraction                = -1
    self._current_peril_color_argb               = { 200, 138, 201, 38 }
    self._ammo_clip_has_latched_data             = false
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
    self._force_show_active                      = false
    self._is_player_dead                         = false

    if mod then
        mod.hud_instance = self
    end

    for _, w in pairs(self._widgets_by_name or {}) do
        w._ringhud_is_team_tile = false
    end
end

HudElementRingHud_player.update        = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod.is_enabled and mod:is_enabled()) then
        return
    end

    local settings = mod._settings
    if not settings then return end

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
        local ads_s = tonumber(settings.ads_scale_override)
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
    if not widgets then return end

    if self._pocketable_pickup_visibility_timer > 0 then
        self._pocketable_pickup_visibility_timer = math_max(0, self._pocketable_pickup_visibility_timer - dt)
    end

    local hud_state = RingHudState.get_hud_data_state(self)
    if not hud_state then return end

    self._apply_shake = false
    self._is_player_dead = false

    local shake_mode = settings.crosshair_shake_dropdown

    if hud_state.player_extensions then
        local ud = hud_state.player_extensions.unit_data
        local he = hud_state.player_extensions.health
        if ud and he then
            local cs = ud:read_component("character_state")
            local is_dead = PlayerUnitStatus.is_dead(cs, he)
            self._is_player_dead = is_dead

            if not is_dead then
                if shake_mode == "crosshair_shake_always" then
                    self._apply_shake = true
                elseif shake_mode == "crosshair_shake_ads" then
                    self._apply_shake = ads_active
                end
            end
        end
    end

    if math_abs(hud_state.health_data.current_fraction - self._previous_health_fraction) > 0.001 or
        math_abs(hud_state.health_data.corruption_fraction - self._previous_corruption_fraction) > 0.001
    then
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

    local stamina_threshold = tonumber(settings.stamina_viz_threshold) or 1.0

    local hide_threshold = 1.0
    if stamina_threshold >= 0.01 and stamina_threshold <= 0.10 then
        hide_threshold = 0.5
    end

    if self._stamina_bar_latched_on and hud_state.stamina_fraction >= hide_threshold then
        self._stamina_bar_latched_on = false
    elseif (not self._stamina_bar_latched_on) and hud_state.stamina_fraction < 1.0 and
        hud_state.stamina_fraction <= stamina_threshold
    then
        self._stamina_bar_latched_on = true
    end

    local ad = hud_state.ammo_data
    do
        local uses_ammo    = ad.uses_ammo and true or false
        local current_clip = tonumber(ad.current_clip) or 0
        local max_clip     = tonumber(ad.max_clip) or 0

        if uses_ammo and max_clip > 0 then
            self._ammo_clip_has_latched_data = true
            self._latched_current_clip_ammo  = current_clip
            self._latched_max_clip_ammo      = max_clip
            self._ammo_clip_latched_low      = (current_clip / max_clip) < 0.45 and current_clip < max_clip
        end
    end

    if settings.ammo_reserve_dropdown ~= "ammo_reserve_disabled" then
        local max_reserve = tonumber(ad.max_reserve) or 0
        local cur_reserve = tonumber(ad.current_reserve) or 0

        if max_reserve > 0 then
            local reserve_frac = math.min(cur_reserve / max_reserve, 1.0)
            local prev         = self._prev_reserve_frac_for_bump
            if prev ~= nil and math_abs(reserve_frac - prev) > 0.001 then
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
    local vis_mode               = settings.ads_visibility_dropdown
    if vis_mode == "ads_vis_hotkey" and ads_active then
        hotkey_active_override = true
    end
    self._force_show_active = hotkey_active_override

    -- Feature Updates
    if PerilFeature.update then PerilFeature.update(self, widgets, hud_state, hotkey_active_override) end
    if DodgeFeature.update then DodgeFeature.update(widgets.dodge_bar, hud_state, hotkey_active_override) end
    if StaminaFeature.update then StaminaFeature.update(self, widgets.stamina_bar, hud_state, hotkey_active_override) end
    if ToughnessHpFeature.update then ToughnessHpFeature.update(self, widgets, hud_state, hotkey_active_override) end
    if ToughnessHpFeature.update_health_text then
        ToughnessHpFeature.update_health_text(self, widgets.health_text_display_widget, hud_state, hotkey_active_override)
    end
    if GrenadesFeature.update then GrenadesFeature.update(self, widgets.grenade_bar, hud_state, hotkey_active_override) end
    if AmmoClipFeature.update_bar then
        AmmoClipFeature.update_bar(self, widgets.ammo_clip_bar, hud_state, hotkey_active_override)
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

    TalentFeature.update(widgets.talent_bar, hud_state, hotkey_active_override)

    if not hud_state.player_extensions then
        self._previous_health_fraction      = -1
        self._previous_corruption_fraction  = -1
        self._previous_dmg_effective_length = -1
        self._prev_reserve_frac_for_bump    = nil
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
    local ads_active         = self._ads_active
    local apply_shake        = self._apply_shake
    local user_bias_px       = U.effective_bias(ads_active)
    local n_user_bias_px     = -user_bias_px

    local text_bias_setting  = tonumber(mod._settings and mod._settings.player_hud_text_offset) or 0
    local text_bias_px       = text_bias_setting * (mod.scalable_unit or 1)
    local stimm_timer_base_x = 2 * (mod.scalable_unit or 1)
    local stimm_timer_base_y = -(6 * (mod.scalable_unit or 1))

    local text_bias_comb     = user_bias_px + text_bias_px
    local n_text_bias_comb   = -text_bias_comb
    local bias_1_5           = user_bias_px * 1.5

    -- -------------- PERIL BAR + TEXT --------------
    do
        local pb = widgets.peril_bar
        if pb and pb.style then
            local changed = false
            if pb.style.peril_bar then
                if apply_shake_offset(pb.style.peril_bar, 0, 0, 1, apply_shake, dx, dy,
                        n_user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if pb.style.peril_edge then
                if apply_shake_offset(pb.style.peril_edge, 0, 0, 1, apply_shake, dx, dy,
                        n_user_bias_px, user_bias_px) then
                    changed = true
                end
            end
            if pb.style.peril_other_edge then
                if apply_shake_offset(pb.style.peril_other_edge, 0, 0, 1, apply_shake, dx, dy,
                        n_user_bias_px, user_bias_px) then
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
                local st = db.style[STR_DODGE_BAR[i]]
                if st and apply_shake_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        user_bias_px, n_user_bias_px) then
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
                apply_shake_offset(sb.style.stamina_bar, 0, 0, 1, apply_shake, dx, dy,
                    n_user_bias_px, n_user_bias_px) then
                changed = true
            end
            if sb.style.stamina_edge and
                apply_shake_offset(sb.style.stamina_edge, 0, 0, 2, apply_shake, dx, dy,
                    n_user_bias_px, n_user_bias_px) then
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
            if cb.style.charge_bar_1 and apply_shake_offset(
                    cb.style.charge_bar_1, 0, 0, 1, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_1_edge and apply_shake_offset(
                    cb.style.charge_bar_1_edge, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_2 and apply_shake_offset(
                    cb.style.charge_bar_2, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end
            if cb.style.charge_bar_2_edge and apply_shake_offset(
                    cb.style.charge_bar_2_edge, 0, 0, 3, apply_shake, dx, dy, user_bias_px, user_bias_px
                ) then
                changed = true
            end

            -- New: segmented dual-shivs passes (if present)
            local max_segments = mod.MAX_CHARGE_SEGMENTS or 6
            for i = 1, max_segments do
                local st  = cb.style[STR_CHARGE_SEG[i]]
                local ste = cb.style[STR_CHARGE_SEG_EDGE[i]]

                if st and apply_shake_offset(
                        st, 0, 0, 2, apply_shake, dx, dy, user_bias_px, user_bias_px
                    ) then
                    changed = true
                end
                if ste and apply_shake_offset(
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
            if apply_shake_offset(tcor.style.corruption_segment, 0, 0, 0, apply_shake, dx, dy,
                    0, bias_1_5) then
                tcor.dirty = true
            end
            if tcor.style.corruption_segment_edge and
                apply_shake_offset(tcor.style.corruption_segment_edge, 0, 0, 1, apply_shake, dx, dy,
                    0, bias_1_5) then
                tcor.dirty = true
            end
        end

        local thp = widgets.toughness_bar_health
        if thp and thp.style and thp.style.health_segment then
            if apply_shake_offset(thp.style.health_segment, 0, 0, 1, apply_shake, dx, dy,
                    0, bias_1_5) then
                thp.dirty = true
            end
            if thp.style.health_segment_edge and
                apply_shake_offset(thp.style.health_segment_edge, 0, 0, 2, apply_shake, dx, dy,
                    0, bias_1_5) then
                thp.dirty = true
            end
        end

        local tdm = widgets.toughness_bar_damage
        if tdm and tdm.style and tdm.style.damage_segment then
            if apply_shake_offset(tdm.style.damage_segment, 0, 0, 2, apply_shake, dx, dy,
                    0, bias_1_5) then
                tdm.dirty = true
            end
            if tdm.style.damage_segment_edge and
                apply_shake_offset(tdm.style.damage_segment_edge, 0, 0, 3, apply_shake, dx, dy,
                    0, bias_1_5) then
                tdm.dirty = true
            end
        end
    end

    -- -------------- GRENADES --------------
    do
        local gb = widgets.grenade_bar
        if gb and gb.style then
            local changed = false
            for i = 1, (mod.MAX_GRENADE_SEGMENTS_DISPLAY or 14) do
                local st  = gb.style[STR_GRENADE_SEG[i]]
                local ste = gb.style[STR_GRENADE_SEG_EDGE[i]]
                if st and apply_shake_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        0, user_bias_px) then
                    changed = true
                end
                if ste and apply_shake_offset(ste, 0, 0, 2, apply_shake, dx, dy,
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
            if acb.style.ammo_clip_unfilled_background and apply_shake_offset(
                    acb.style.ammo_clip_unfilled_background, 0, 0, 0, apply_shake, dx, dy, n_user_bias_px, n_user_bias_px
                ) then
                changed = true
            end
            if acb.style.ammo_clip_filled_single and apply_shake_offset(
                    acb.style.ammo_clip_filled_single, 0, 0, 1, apply_shake, dx, dy, n_user_bias_px, n_user_bias_px
                ) then
                changed = true
            end
            for i = 1, (mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 5) do
                local st = acb.style[STR_AMMO_MULTI[i]]
                if st and apply_shake_offset(st, 0, 0, 1, apply_shake, dx, dy,
                        n_user_bias_px, n_user_bias_px) then
                    changed = true
                end
            end
            if changed then acb.dirty = true end
        end
    end

    -- -------------- TALENT BAR --------------
    do
        local tb = widgets.talent_bar
        if tb and tb.style then
            local changed = false

            if tb.style.talent_bar and apply_shake_offset(
                    tb.style.talent_bar, 0, 0, 1, apply_shake, dx, dy, user_bias_px, n_user_bias_px
                ) then
                changed = true
            end
            if tb.style.talent_bar_edge and apply_shake_offset(
                    tb.style.talent_bar_edge, 0, 0, 2, apply_shake, dx, dy, user_bias_px, n_user_bias_px
                ) then
                changed = true
            end

            -- Psyker segmented passes (so shake/bias affects them too)
            for i = 1, 3 do
                local st = tb.style[STR_TALENT_SEG[i]]
                if st and apply_shake_offset(
                        st, 0, 0, 1, apply_shake, dx, dy, user_bias_px, n_user_bias_px
                    ) then
                    changed = true
                end
            end

            -- Adamant segmented passes (base + notch edge)
            for i = 1, 4 do
                local st  = tb.style[STR_ADAMANT_SEG[i]]
                local ste = tb.style[STR_ADAMANT_SEG_EDGE[i]]

                if st and apply_shake_offset(
                        st, 0, 0, 1, apply_shake, dx, dy, user_bias_px, n_user_bias_px
                    ) then
                    changed = true
                end
                if ste and apply_shake_offset(
                        ste, 0, 0, 2, apply_shake, dx, dy, user_bias_px, n_user_bias_px
                    ) then
                    changed = true
                end
            end

            if changed then tb.dirty = true end
        end
    end

    -- -------------- STIMM / CRATE ICONS --------------
    do
        local stw = widgets.stimm_indicator_widget
        if stw and stw.style then
            local changed = false
            if stw.style.stimm_icon then
                if apply_shake_offset(stw.style.stimm_icon, 0, 0, 0, apply_shake, dx, dy,
                        user_bias_px, n_user_bias_px) then
                    changed = true
                end
            end

            if stw.style.stimm_timer_text then
                if apply_shake_offset(stw.style.stimm_timer_text, stimm_timer_base_x, stimm_timer_base_y, 1, apply_shake, dx, dy,
                        text_bias_comb, n_text_bias_comb) then
                    changed = true
                end
            end

            if changed then stw.dirty = true end
        end

        local cw = widgets.crate_indicator_widget
        if cw and cw.style and cw.style.crate_icon then
            if apply_shake_offset(cw.style.crate_icon, 0, 0, 0, apply_shake, dx, dy,
                    user_bias_px, n_user_bias_px) then
                cw.dirty = true
            end
        end
    end

    -- -------------- TEXT WIDGETS --------------
    do
        local pt = widgets.peril_text_display_widget
        if pt and pt.style and pt.style.percent_text_style then
            if apply_shake_offset(pt.style.percent_text_style, 0, 0, 2, apply_shake, dx, dy,
                    n_text_bias_comb, text_bias_comb) then
                pt.dirty = true
            end
        end

        local at = widgets.ability_timer
        if at and at.style and at.style.ability_text then
            local base_x = Definitions.text_offset
            local base_y = Definitions.offset_correction
            if apply_shake_offset(at.style.ability_text, base_x, base_y, 2, apply_shake, dx, dy,
                    text_bias_comb, text_bias_comb) then
                at.dirty = true
            end
        end

        local ar = widgets.ammo_reserve_display_widget
        if ar and ar.style and ar.style.reserve_text_style then
            if apply_shake_offset(ar.style.reserve_text_style, 0, 0, 2, apply_shake, dx, dy,
                    n_text_bias_comb, n_text_bias_comb) then
                ar.dirty = true
            end
        end

        local act = widgets.ammo_clip_text_display_widget
        if act and act.style and act.style.ammo_clip_text_style then
            if apply_shake_offset(act.style.ammo_clip_text_style, 0, 0, 1, apply_shake, dx, dy,
                    n_text_bias_comb, 0) then
                act.dirty = true
            end
        end

        local ht = widgets.health_text_display_widget
        if ht and ht.style and ht.style.health_text_style then
            if apply_shake_offset(ht.style.health_text_style, 0, 0, 1, apply_shake, dx, dy,
                    0, bias_1_5 + text_bias_px) then
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

    if self._is_player_dead then
        return
    end

    local ads_active = self._ads_active -- cached
    local force_show = (self._force_show_active == true)
    local vis_mode   = mod._settings.ads_visibility_dropdown

    local hide_hud   = false
    if not force_show then
        if (vis_mode == "ads_vis_hide_in_ads" and ads_active) or
            (vis_mode == "ads_vis_hide_outside_ads" and not ads_active) then
            hide_hud = true
        end
    end

    local saved_alphas = nil
    if hide_hud then
        local clip_mode = mod._settings.ammo_clip_dropdown
        local clip_ads_exception = ads_active and
            (clip_mode == "ammo_clip_bar_ads" or clip_mode == "ammo_clip_bar_forecast_ads")

        if not clip_ads_exception then
            return
        end

        saved_alphas = {}
        local widgets = self._widgets_by_name
        if widgets then
            for name, widget in pairs(widgets) do
                saved_alphas[widget] = widget.alpha_multiplier
                if name ~= "ammo_clip_bar" and name ~= "ammo_clip_text_display_widget" then
                    widget.alpha_multiplier = 0
                end
            end
        end
    end

    HudElementRingHud_player.super.draw(self, dt, t, ui_renderer, render_settings, input_service)

    if saved_alphas then
        for widget, alpha in pairs(saved_alphas) do
            widget.alpha_multiplier = alpha
        end
    end
end

return HudElementRingHud_player
