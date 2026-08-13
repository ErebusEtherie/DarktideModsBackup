-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_player.lua

local mod = get_mod("RingHud")
if not mod then return end

-- ## 1. DEPENDENCIES ##
local RingHudState       = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_player")
local Definitions        = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_player")
local PlayerUnitStatus   = require("scripts/utilities/attack/player_unit_status")
local UIWidget           = require("scripts/managers/ui/ui_widget")

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

local math_max                         = math.max
local tonumber                         = tonumber

-- Shared context table reused every frame by feature modules for layout/shake to avoid table generation GC overhead
local _shared_layout_context           = {
    apply_shake = false,
    dx = 0,
    dy = 0,
    user_bias_px = 0,
    n_user_bias_px = 0,
    text_bias_px = 0,
    text_bias_comb = 0,
    n_text_bias_comb = 0,
    bias_1_5 = 0,
    stimm_timer_base_x = 0,
    stimm_timer_base_y = 0
}

-- ## 2. CLASS DEFINITION ##
local HudElementRingHud_player         = class("HudElementRingHud_player", "HudElementBase")

-- ## 3. PUBLIC LIFECYCLE METHODS ##

HudElementRingHud_player.init          = function(self, parent, draw_layer, start_scale)
    HudElementRingHud_player.super.init(self, parent, draw_layer, start_scale, Definitions)

    self._stamina_bar_latched_on                 = false
    self._ammo_clip_has_latched_data             = false
    self._ammo_clip_latched_low                  = false
    self._latched_current_clip_ammo              = 0
    self._latched_max_clip_ammo                  = 0
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

    if hud_state.triggers and hud_state.triggers.recent_health_change then
        if mod.thv_player_recent_change_bump then
            mod.thv_player_recent_change_bump()
        end
    end

    if hud_state.triggers and hud_state.triggers.recent_ammo_reserve_change then
        if mod.ammo_vis_player_recent_change_bump then
            mod.ammo_vis_player_recent_change_bump()
        end
    end

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

    -- Populate the shared context table
    local ctx                = _shared_layout_context
    ctx.apply_shake          = apply_shake
    ctx.dx, ctx.dy           = dx, dy
    ctx.user_bias_px         = user_bias_px
    ctx.n_user_bias_px       = n_user_bias_px
    ctx.text_bias_px         = text_bias_px
    ctx.text_bias_comb       = text_bias_comb
    ctx.n_text_bias_comb     = n_text_bias_comb
    ctx.bias_1_5             = bias_1_5
    ctx.stimm_timer_base_x   = stimm_timer_base_x
    ctx.stimm_timer_base_y   = stimm_timer_base_y

    if PerilFeature.apply_layout then PerilFeature.apply_layout(widgets.peril_bar, widgets.peril_text_display_widget, ctx) end
    if DodgeFeature.apply_layout then DodgeFeature.apply_layout(widgets.dodge_bar, ctx) end
    if StaminaFeature.apply_layout then StaminaFeature.apply_layout(widgets.stamina_bar, ctx) end
    if ChargeFeature.apply_layout then ChargeFeature.apply_layout(widgets.charge_bar, ctx) end
    if ToughnessHpFeature.apply_layout then ToughnessHpFeature.apply_layout(widgets, ctx) end
    if GrenadesFeature.apply_layout then GrenadesFeature.apply_layout(widgets.grenade_bar, ctx) end
    if AmmoClipFeature.apply_layout then
        AmmoClipFeature.apply_layout(
            widgets.ammo_clip_bar,
            widgets.ammo_clip_text_display_widget,
            ctx
        )
    end
    if AmmoReserveFeature.apply_layout then AmmoReserveFeature.apply_layout(widgets.ammo_reserve_display_widget, ctx) end
    if TalentFeature.apply_layout then TalentFeature.apply_layout(widgets.talent_bar, ctx) end
    if AbilityFeature.apply_layout then AbilityFeature.apply_layout(widgets.ability_timer, ctx) end
    if PocketableFeature.apply_layout then PocketableFeature.apply_layout(widgets, ctx) end

    -- Inline visibility-aware draw loop (skips widget.visible==false widgets entirely,
    -- saving 1 FFI call + Lua pass-loop per hidden widget vs HudElementBase._draw_widgets).
    local active_widgets = self._widgets
    if active_widgets then
        local _draw = UIWidget.draw
        for i = 1, #active_widgets do
            local w = active_widgets[i]
            if w and w.visible ~= false then
                _draw(w, ui_renderer)
            end
        end
    end
end

function HudElementRingHud_player:draw(dt, t, ui_renderer, render_settings, input_service)
    if not (mod and mod:is_enabled()) then
        return
    end

    if self._is_player_dead then
        return
    end

    local ads_active = self._ads_active -- cached
    local force_show = self._force_show_active == true
    local vis_mode   = mod._settings.ads_visibility_dropdown

    local hide_hud   = false
    if not force_show then
        if (vis_mode == "ads_vis_hide_in_ads" and ads_active)
            or (vis_mode == "ads_vis_hide_outside_ads" and not ads_active)
        then
            hide_hud = true
        end
    end

    local saved_alphas = nil
    if hide_hud then
        local clip_mode = mod._settings.ammo_clip_dropdown
        local clip_ads_exception = ads_active
            and (clip_mode == "ammo_clip_bar_ads" or clip_mode == "ammo_clip_bar_forecast_ads")

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
