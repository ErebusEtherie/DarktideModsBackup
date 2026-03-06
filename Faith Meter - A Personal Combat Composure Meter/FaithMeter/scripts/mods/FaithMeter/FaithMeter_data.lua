local mod = get_mod("FaithMeter")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            -- Core HUD
            {
                setting_id = "hud_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "hud_show_text",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "hud_show_state_text",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "hud_show_flavor_text",
                type = "checkbox",
                default_value = true,
            },

            -- Layout
            {
                setting_id = "hud_offset_x",
                type = "numeric",
                default_value = 0,
                range = { -800, 800 },
                decimals_number = 0,
            },
            {
                setting_id = "hud_offset_y",
                type = "numeric",
                default_value = 0,
                range = { -600, 600 },
                decimals_number = 0,
            },
            {
                setting_id = "hud_scale",
                type = "numeric",
                default_value = 1.0,
                range = { 0.5, 2.0 },
                decimals_number = 2,
            },

            -- UI Layout (visual only)
            {
                setting_id = "hud_layout",
                type = "dropdown",
                default_value = 1,
                options = {
                    { text = mod:localize("hud_layout_classic"), value = 1 },
                    { text = mod:localize("hud_layout_dual"), value = 2 },
                },
            },

            -- Dual-bar layout cosmetics (visual only)
            {
                setting_id = "dual_bar_background",
                type = "checkbox",
                default_value = false,
            },

            -- Special pressure (v1.3 TEST)
            {
                setting_id = "sp_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_engage_radius",
                type = "numeric",
                default_value = 30,
                range = { 0, 45 },
                decimals_number = 0,
            },
            {
                setting_id = "sp_grace_seconds",
                type = "numeric",
                default_value = 12,
                range = { 0, 45 },
                decimals_number = 0,
            },
            {
                setting_id = "sp_loss_per_second",
                type = "numeric",
                default_value = 0.06,
                range = { 0.0, 0.25 },
                decimals_number = 2,
            },

            -- Team engagement dampening (balance)
            {
                setting_id = "team_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "team_mult",
                type = "numeric",
                default_value = 0.70,
                range = { 0.10, 1.00 },
                decimals_number = 2,
            },
            {
                setting_id = "team_window_s",
                type = "numeric",
                default_value = 6,
                range = { 0, 30 },
                decimals_number = 0,
            },
            {
                setting_id = "team_cap_s",
                type = "numeric",
                default_value = 12,
                range = { 0, 60 },
                decimals_number = 0,
            },
            {
                setting_id = "team_exclude_bosses",
                type = "checkbox",
                default_value = true,
            },

            -- Initial meter lock (start-of-mission)
            {
                setting_id = "initial_lock_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "initial_lock_value",
                type = "numeric",
                default_value = 50,
                range = { 0, 100 },
                decimals_number = 0,
            },

            -- Proximity pressure (Phase 2.6)
            {
                setting_id = "sp_proximity_enabled",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_proximity_radius",
                type = "numeric",
                default_value = 35,
                range = { 0, 60 },
                decimals_number = 0,
            },
            {
                setting_id = "sp_proximity_loss_per_second",
                type = "numeric",
                default_value = 0.20,
                range = { 0.0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id = "sp_include_monsters",
                type = "checkbox",
                default_value = true,
            },

            {
                setting_id = "sp_clutch_coeff_enabled",
                type = "checkbox",
                default_value = true,
            },

            -- Special type toggles
            {
                setting_id = "sp_track_bomber",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_flamer",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_sniper",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_trapper",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_hound",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_mutant",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_track_burster",
                type = "checkbox",
                default_value = true,
            },

            {
                setting_id = "sp_sound_detection",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "sp_sound_signal_ttl",
                type = "numeric",
                default_value = 6.0,
                range = { 0.5, 20.0 },
                decimals_number = 1,
            },
            {
                setting_id = "sp_track_other_specials",
                type = "checkbox",
                default_value = true,
            },

            -- Phase 2: Team Pressure model
{
    setting_id = "pressure_tick_seconds",
    type = "numeric",
    default_value = 0.25,
    range = {0.05, 1.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_faith_gain_per_s",
    type = "numeric",
    default_value = 2.5,
    range = {0.0, 20.0},
    decimals_number = 1,
},
{
    setting_id = "pressure_faith_decay_per_s",
    type = "numeric",
    default_value = 3.0,
    range = {0.0, 30.0},
    decimals_number = 1,
},
{
    setting_id = "pressure_relief_coherency_min",
    type = "numeric",
    default_value = 0.75,
    range = {0.0, 1.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_relief_toughness_min",
    type = "numeric",
    default_value = 0.30,
    range = {0.0, 1.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_relief_timeout_s",
    type = "numeric",
    default_value = 10.0,
    range = {1.0, 60.0},
    decimals_number = 0,
},
{
    setting_id = "pressure_silence_window_s",
    type = "numeric",
    default_value = 4.0,
    range = {0.0, 30.0},
    decimals_number = 1,
},
{
    setting_id = "pressure_hp_loss_event_p",
    type = "numeric",
    default_value = 0.01,
    range = {0.0, 0.2},
    decimals_number = 2,
},
{
    setting_id = "pressure_tough_loss_event_p",
    type = "numeric",
    default_value = 0.02,
    range = {0.0, 0.2},
    decimals_number = 2,
},
{
    setting_id = "pressure_health_critical_p",
    type = "numeric",
    default_value = 0.25,
    range = {0.05, 0.9},
    decimals_number = 2,
},
{
    setting_id = "pressure_health_spike_drop_p",
    type = "numeric",
    default_value = 0.12,
    range = {0.01, 0.9},
    decimals_number = 2,
},
{
    setting_id = "pressure_toughness_low_p",
    type = "numeric",
    default_value = 0.20,
    range = {0.0, 0.95},
    decimals_number = 2,
},
{
    setting_id = "pressure_toughness_break_p",
    type = "numeric",
    default_value = 0.05,
    range = {0.0, 0.3},
    decimals_number = 2,
},
{
    setting_id = "pressure_coherency_isolate_grace_s",
    type = "numeric",
    default_value = 8.0,
    range = {0.0, 60.0},
    decimals_number = 0,
},
{
    setting_id = "pressure_disable_grace_s",
    type = "numeric",
    default_value = 3.0,
    range = {0.0, 30.0},
    decimals_number = 0,
},
{
    setting_id = "pressure_multi_incap_penalty",
    type = "numeric",
    default_value = 6.0,
    range = {0.0, 50.0},
    decimals_number = 1,
},
{
    setting_id = "pressure_single_incap_penalty",
    type = "numeric",
    default_value = 2.0,
    range = {0.0, 30.0},
    decimals_number = 1,
},
{
    setting_id = "pressure_weight_coherency",
    type = "numeric",
    default_value = 1.25,
    range = {0.0, 5.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_weight_toughness",
    type = "numeric",
    default_value = 1.10,
    range = {0.0, 5.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_weight_health",
    type = "numeric",
    default_value = 0.85,
    range = {0.0, 5.0},
    decimals_number = 2,
},
{
    setting_id = "pressure_weight_incap",
    type = "numeric",
    default_value = 1.80,
    range = {0.0, 6.0},
    decimals_number = 2,
},

-- Debug
            {
    setting_id = "debug_pressure",
    type = "checkbox",
    default_value = false,
},
{
                setting_id = "debug_special_pressure",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "debug_demo_oscillate",
                type = "checkbox",
                default_value = false,
            },
        },
    },
}
