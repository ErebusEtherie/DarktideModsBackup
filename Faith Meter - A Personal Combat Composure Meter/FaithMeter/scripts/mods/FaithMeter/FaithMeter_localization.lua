return {
    mod_name = {
        en = "Faith Meter",
    },
    mod_description = {
        en = "A cosmetic, diegetic Faith meter HUD element.",
    },
    hud_enabled = {
        en = "Enable HUD",
    },
    hud_enabled_description = {
        en = "Show the Faith Meter HUD element.",
    },
    hud_show_text = {
        en = "Show label",
    },
    hud_show_text_description = {
        en = "Show the 'FAITH' label next to the meter.",
    },
    debug_demo_oscillate = {
        en = "Demo oscillation",
    },
    debug_demo_oscillate_description = {
        en = "If enabled, the bar animates to verify rendering.",
    },
    hud_offset_x = {
        en = "HUD X offset",
    },
    hud_offset_x_description = {
        en = "Move the Faith Meter left/right on the screen.",
    },
    hud_offset_y = {
        en = "HUD Y offset",
    },
    hud_offset_y_description = {
        en = "Move the Faith Meter up/down on the screen.",
    },
    hud_scale = {
        en = "HUD scale",
    },
    hud_scale_description = {
        en = "Scale the Faith Meter size (multiplies the base HUD size).",
    },

    hud_layout = {
        en = "HUD layout",
    },
    hud_layout_description = {
        en = "Choose between the classic horizontal bar or the dual vertical Faith/Pressure layout.",
    },
    hud_layout_classic = {
        en = "Classic bar",
    },
    hud_layout_dual = {
        en = "Dual bars (Pressure/Faith)",
    },

    dual_bar_background = {
        en = "Dual bars: background plate",
    },
    dual_bar_background_description = {
        en = "Show the background plate behind the dual vertical bars (off by default for a cleaner look).",
    },
hud_show_state_text = {
    en = "Show state text",
},
hud_show_state_text_description = {
    en = "Replace the label with a Faith state (Shattered/Wavering/Steeled/Resolute/Zealous/Divine).",
},
hud_show_flavor_text = {
    en = "Show flavor lines",
},
hud_show_flavor_text_description = {
    en = "Show brief, non-spammy quotes when your Faith crosses thresholds.",
},

    sp_enabled = {
        en = "Special pressure (v1.3 test)",
    },
    sp_enabled_description = {
        en = "When enabled, leaving specials alive near the team for too long will slowly reduce Faith (pressure = loss of control).",
    },
    sp_engage_radius = {
        en = "Special engage radius (m)",
    },
    sp_engage_radius_description = {
        en = "Only count specials within this distance of any player (prevents off-screen spawns from affecting you).",
    },
    sp_grace_seconds = {
        en = "Special grace time (s)",
    },
    sp_grace_seconds_description = {
        en = "How long a special can stay engaged before it starts applying pressure.",
    },
    sp_loss_per_second = {
        en = "Pressure loss per special (/s)",
    },
    sp_loss_per_second_description = {
        en = "Faith lost per second for each engaged special after grace time. Kept conservative for Auric tuning.",
    },

    sp_proximity_enabled = {
        en = "Proximity pressure",
    },
    sp_proximity_enabled_description = {
        en = "When enabled, specials within proximity apply ongoing Faith drain, even if not actively attacking.",
    },
    sp_proximity_radius = {
        en = "Proximity radius (m)",
    },
    sp_proximity_radius_description = {
        en = "Distance around you where nearby specials count as pressure sources.",
    },
    sp_proximity_loss_per_second = {
        en = "Proximity drain per special (/s)",
    },
    sp_proximity_loss_per_second_description = {
        en = "Faith lost per second for each special within proximity radius. This is intended to be noticeable but not oppressive.",
    },
    sp_include_monsters = {
        en = "Include monsters/bosses",
    },
    sp_include_monsters_description = {
        en = "If enabled, monster/boss units (e.g., Chaos Spawn) will also apply proximity pressure.",
    },
    sp_clutch_coeff_enabled = {
        en = "Clutch coefficient",
    },
    sp_clutch_coeff_enabled_description = {
        en = "Reduce special-pressure loss when fewer players are alive (clutch scenarios).",
    },
    sp_track_bomber = { en = "Track Bomber", },
    sp_track_flamer = { en = "Track Flamer", },
    sp_track_sniper = { en = "Track Sniper", },
    sp_track_trapper = { en = "Track Trapper", },
    sp_track_hound = { en = "Track Hound", },
    sp_track_mutant = { en = "Track Mutant", },
    sp_track_burster = { en = "Track Burster", },
    sp_sound_detection = {
        en = "Sound detection",
    },
    sp_sound_signal_ttl = {
        en = "Sound signal TTL (s)",
    },
    sp_track_other_specials = { en = "Track other specials", },
    debug_special_pressure = {
        en = "Debug: show special pressure",
    },
    debug_special_pressure_description = {
        en = "Shows a small debug line with special counts and pressure rate (testing only).",
    },

-- Phase 2: Team Pressure model
pressure_tick_seconds = { en = "Pressure tick (seconds)" },
pressure_tick_seconds_description = { en = "How often the pressure model samples team state." },

pressure_faith_gain_per_s = { en = "Faith gain rate" },
pressure_faith_gain_per_s_description = { en = "How quickly Faith increases when control is good." },

pressure_faith_decay_per_s = { en = "Faith decay rate (no relief)" },
pressure_faith_decay_per_s_description = { en = "Extra decay when the team does not get recovery windows." },

pressure_relief_coherency_min = { en = "Relief window: coherency minimum" },
pressure_relief_coherency_min_description = { en = "Minimum coherency coverage to count as a relief window." },

pressure_relief_toughness_min = { en = "Relief window: toughness minimum" },
pressure_relief_toughness_min_description = { en = "Minimum average toughness to count as a relief window." },

pressure_relief_timeout_s = { en = "Relief timeout (seconds)" },
pressure_relief_timeout_s_description = { en = "If no relief window occurs for this long, Faith begins to decay faster." },

pressure_health_critical_p = { en = "Critical health threshold" },
pressure_health_critical_p_description = { en = "Players below this health percentage are considered at critical health." },

pressure_health_spike_drop_p = { en = "Health spike threshold" },
pressure_health_spike_drop_p_description = { en = "A single sample health drop above this percentage counts as a spike." },

pressure_toughness_low_p = { en = "Low toughness threshold" },
pressure_toughness_low_p_description = { en = "Players below this toughness percentage are considered under sustained pressure." },

pressure_toughness_break_p = { en = "Toughness break threshold" },
pressure_toughness_break_p_description = { en = "Toughness at or below this is treated as broken." },

pressure_coherency_isolate_grace_s = { en = "Isolation grace (seconds)" },
pressure_coherency_isolate_grace_s_description = { en = "How long a player can be out of coherency before it meaningfully penalizes Faith." },

pressure_disable_grace_s = { en = "Disable grace (seconds)" },
pressure_disable_grace_s_description = { en = "How long a disable can persist before it meaningfully penalizes Faith." },

pressure_single_incap_penalty = { en = "Single incapacitation penalty" },
pressure_single_incap_penalty_description = { en = "Additional Faith decay while one player is disabled/down." },

pressure_multi_incap_penalty = { en = "Multiple incapacitation penalty" },
pressure_multi_incap_penalty_description = { en = "Additional Faith decay while two or more players are disabled/down." },

pressure_weight_coherency = { en = "Weight: coherency" },
pressure_weight_coherency_description = { en = "How strongly coherency affects Faith." },

pressure_weight_toughness = { en = "Weight: toughness" },
pressure_weight_toughness_description = { en = "How strongly toughness stability affects Faith." },

pressure_weight_health = { en = "Weight: health" },
pressure_weight_health_description = { en = "How strongly health stability affects Faith." },

pressure_weight_incap = { en = "Weight: incapacitations" },
pressure_weight_incap_description = { en = "How strongly downs/disables affect Faith." },

debug_pressure = { en = "Debug: show pressure breakdown" },
debug_pressure_description = { en = "Show live team pressure telemetry under the Faith Meter." },
    pressure_silence_window_s = {
        en = "Threat silence window (s)",
    },
    pressure_silence_window_s_description = {
        en = "Seconds without observed pressure (damage/toughness loss/incaps) before recovery relief is allowed.",
    },
    pressure_hp_loss_event_p = {
        en = "Pressure event: HP loss threshold",
    },
    pressure_hp_loss_event_p_description = {
        en = "Minimum health percent drop (per sample) that counts as a pressure event for threat silence.",
    },
    pressure_tough_loss_event_p = {
        en = "Pressure event: Toughness loss threshold",
    },
    pressure_tough_loss_event_p_description = {
        en = "Minimum toughness percent drop (per sample) that counts as a pressure event for threat silence.",
    },

    team_enabled = {
        en = "Team dampening enabled",
    },
    team_enabled_description = {
        en = "If enabled, teammate special-kills create a short dampening window that reduces special drain.",
    },
    team_mult = {
        en = "Team dampening multiplier",
    },
    team_mult_description = {
        en = "Drain multiplier applied while the team dampening window is active (lower = less drain).",
    },
    team_window_s = {
        en = "Dampening seconds per special kill",
    },
    team_window_s_description = {
        en = "How many seconds are added to the dampening window when any player kills a specialist.",
    },
    team_cap_s = {
        en = "Dampening cap (seconds)",
    },
    team_cap_s_description = {
        en = "Maximum accumulated dampening window time.",
    },
    team_exclude_bosses = {
        en = "Exclude bosses from team credit",
    },
    team_exclude_bosses_description = {
        en = "If enabled, boss/monster kills do not contribute to the team dampening window.",
    },

    initial_lock_enabled = {
        en = "Initial lock until first special",
    },
    initial_lock_enabled_description = {
        en = "Lock the meter at a fixed value from mission start until the first special engagement is detected. Any INCAP breaks the lock.",
    },
    initial_lock_value = {
        en = "Initial lock value",
    },
    initial_lock_value_description = {
        en = "Faith value held while the initial lock is active (percentage).",
    },
}
