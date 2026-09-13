local mod = get_mod("WarpHorror")

local loc = {
    mod_name = {
        en = "Warp Horror",
    },
    mod_description = {
        en = "Enhanced Venting Shriek automation with Warp Siphon integration - Prevent Peril Explosion & Warp Unbound Bug Fix & Auto Quelling",
    },
    -- Prevent Psyker Explosion
    prevent_psyker_explosion = {
        en = "Prevent Psyker Explosion",
    },
    prevent_psyker_explosion_enable = {
        en = "Enable Prevent Psyker Explosion",
    },
    prevent_psyker_explosion_enable_description = {
        en = "Prevents peril-generating attacks when peril exceeds the threshold whilst Warp Unbound ability is not active.",
    },
    peril_threshold = {
        en = "Peril Threshold Percentage",
    },
    peril_threshold_description = {
        en = "Maximum allowable peril before peril-generating attacks are disabled. [Default 0.95]",
    },
    -- Warp Unbound Bug Fix
    warp_unbound_bug_fix = {
        en = "Warp Unbound Bug Fix",
    },
    warp_unbound_bug_fix_enable = {
        en = "Enable Warp Unbound Bug Fix",
    },
    warp_unbound_bug_fix_enable_description = {
        en = "There is a probability to explode with Smite, Surge & Trauma staffs despite activating Warp Unbound. Bugfix disables attacks that generate peril when entering and exiting the infinite-casting state.",
    },
    debounce_enter_percentage = {
        en = "Debounce Enter Percentage",
    },
    debounce_enter_percentage_description = {
        en = "At what peril percentage are perilous inputs disabled until warp unbound buff becomes activated. [Default 0.96]",
    },
    debounce_exit_time = {
        en = "Debounce Exit Time.",
    },
    debounce_exit_time_description = {
        en = "At how many seconds left of the Warp Unbound buff timer are perilous inputs disabled until buff becomes disabled. [Default 0.5]",
    },
    -- Auto Quell
    auto_quell = {
        en = "Auto Quell",
    },
    auto_quell_enable = {
        en = "Enable Auto Quell",
    },
    auto_quell_threshold = {
        en = "Auto Quell Threshold",
    },
    auto_quell_threshold_description = {
        en = "[Default 0.95]",
    },
    auto_quell_duration = {
        en = "Auto Quell Duration.",
    },
    auto_quell_duration_description = {
        en = "[Default 0.5]",
    },
    -- Auto Ability Activation
    auto_ability = {
        en = "Auto Ability",
    },
    auto_gaze_enable = {
        en = "Auto Scriers Gaze",
    },
    auto_gaze_enable_description = {
        en = "Activate Scriers Gaze automatically (if warp unbound is equipped) when the timer reaches the end.",
    },
    auto_vent_enable = {
        en = "Auto Venting Shriek",
    },
    auto_vent_enable_description = {
        en = "Activate Venting Shriek automatically if current peril is above peril threshold.",
    },
    -- Venting Shriek Explosion Prevention
    venting_shriek_explosion_prevention = {
        en = "Venting Shriek Explosion Prevention",
    },
    venting_shriek_explosion_threshold = {
        en = "Explosion Prevention Threshold",
    },
    venting_shriek_explosion_threshold_description = {
        en = "Peril percentage at which Venting Shriek is automatically triggered to prevent explosion. [Default 0.98]",
    },
    -- Warp Siphon Integration
    warp_siphon_integration = {
        en = "Warp Siphon Integration",
    },
    warp_siphon_integration_enable = {
        en = "Enable Warp Siphon Integration",
    },
    warp_siphon_integration_enable_description = {
        en = "Enables advanced Venting Shriek automation when Warp Siphon keystone is equipped.",
    },
    warp_siphon_peril_threshold = {
        en = "Warp Siphon Peril Threshold",
    },
    warp_siphon_peril_threshold_description = {
        en = "Peril percentage required to trigger Venting Shriek with Warp Siphon. [Default 0.95]",
    },
    warp_siphon_min_souls = {
        en = "Warp Siphon Minimum Souls",
    },
    warp_siphon_min_souls_description = {
        en = "Minimum soul charges required to trigger Venting Shriek. [Default 4]",
    },
    warp_siphon_auto_quell_fallback = {
        en = "Auto Quell Fallback",
    },
    warp_siphon_auto_quell_fallback_description = {
        en = "Automatically quell if Venting Shriek conditions are not met (not at 100% peril and not exploding).",
    },
}

return loc