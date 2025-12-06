-- File: RingHud/scripts/mods/RingHud/systems/settings_manager.lua
local mod = get_mod("RingHud")
if not mod then return end

-- Cache all settings once at init. After this, only mutate via mod.on_setting_changed.
mod._settings = {
    show_all_hud_hotkey            = mod:get("show_all_hud_hotkey"),
    trigger_detection_range        = mod:get("trigger_detection_range"),

    -- Layout
    crosshair_shake_dropdown       = mod:get("crosshair_shake_dropdown"),
    ring_scale                     = mod:get("ring_scale"),
    ring_offset_bias               = mod:get("ring_offset_bias"),

    -- ADS behaviour
    ads_visibility_dropdown        = mod:get("ads_visibility_dropdown"),
    ads_scale_override             = mod:get("ads_scale_override"),
    ads_offset_bias_override       = mod:get("ads_offset_bias_override"),

    -- Survival
    toughness_bar_dropdown         = mod:get("toughness_bar_dropdown"),
    stamina_viz_threshold          = mod:get("stamina_viz_threshold"),
    dodge_viz_threshold            = mod:get("dodge_viz_threshold"),

    -- Peril
    peril_bar_dropdown             = mod:get("peril_bar_dropdown"),
    peril_label_enabled            = mod:get("peril_label_enabled"),
    peril_crosshair_enabled        = mod:get("peril_crosshair_enabled"),

    -- Munitions
    ammo_clip_dropdown             = mod:get("ammo_clip_dropdown"),
    ammo_reserve_dropdown          = mod:get("ammo_reserve_dropdown"),
    grenade_bar_dropdown           = mod:get("grenade_bar_dropdown"),

    -- Charge
    charge_perilous_enabled        = mod:get("charge_perilous_enabled"),
    charge_kills_enabled           = mod:get("charge_kills_enabled"),
    charge_other_enabled           = mod:get("charge_other_enabled"),

    -- Ability Timers
    timer_cd_enabled               = mod:get("timer_cd_enabled"),
    timer_buff_enabled             = mod:get("timer_buff_enabled"),
    timer_sound_enabled            = mod:get("timer_sound_enabled"),

    -- Pocketables
    pocketable_visibility_dropdown = mod:get("pocketable_visibility_dropdown"),
    medical_crate_color            = mod:get("medical_crate_color"),
    ammo_cache_color               = mod:get("ammo_cache_color"),

    -- Team HUD
    team_hud_mode                  = mod:get("team_hud_mode"),
    team_tiles_scale               = mod:get("team_tiles_scale"),
    team_hp_bar                    = mod:get("team_hp_bar"),

    -- Team HUD Detail
    team_munitions                 = mod:get("team_munitions"),
    team_pockets                   = mod:get("team_pockets"),
    team_counters                  = mod:get("team_counters"),

    -- Vanilla HUD Visibility
    hide_default_ability           = mod:get("hide_default_ability"),
    hide_default_weapons           = mod:get("hide_default_weapons"),
    hide_default_player            = mod:get("hide_default_player"),

    minimal_objective_feed_enabled = mod:get("minimal_objective_feed_enabled"),
}

-- Centralized settings change handler (the only one in the mod)
function mod.on_setting_changed(setting_id)
    -- Update our live cache straight from DMF:
    mod._settings[setting_id] = mod:get(setting_id)

    -- Kick any subsystems that adjust behaviour live.
    local ok

    -- Floating teammate tiles (world markers, switching, etc.)
    local fm = rawget(mod, "floating_manager")
    if fm and fm.apply_settings then
        ok = pcall(fm.apply_settings, setting_id)
        if not ok then
            mod:warning("[settings_manager] floating_manager.apply_settings failed for '%s'", tostring(setting_id))
        end
    end

    -- Vanilla HUD visibility/tweaks (hide default HUD pieces, and chat node alignment)
    local vhm = rawget(mod, "VanillaHudManager")
    if vhm and vhm.apply_settings then
        ok = pcall(vhm.apply_settings, setting_id)
        if not ok then
            mod:warning("[settings_manager] VanillaHudManager.apply_settings failed for '%s'", tostring(setting_id))
        end
    end

    -- Proximity-driven features (if any setting affects them)
    local prox = rawget(mod, "ProximitySystem")
    if prox and prox.apply_settings then
        ok = pcall(prox.apply_settings, setting_id)
        if not ok then
            mod:warning("[settings_manager] ProximitySystem.apply_settings failed for '%s'", tostring(setting_id))
        end
    end

    -- Name cache / composition options (if present)
    local nc = rawget(mod, "name_cache")
    if nc and nc.apply_settings then
        ok = pcall(nc.apply_settings, nc, setting_id)
        if not ok then
            mod:warning("[settings_manager] name_cache.apply_settings failed for '%s'", tostring(setting_id))
        end
    end
end
