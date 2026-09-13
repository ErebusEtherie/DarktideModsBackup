local mod = get_mod("WarpGod")

local loc = {
    mod_name = {
        en = "Warp God",
    },
    mod_description = {
        en = "Prevent Peril of the Warp Explosion & Warp Unbound talent bug hotfix & Auto Quelling & Auto Ability Activation",
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
        en = "Auto Scrier's Gaze",
    },
    auto_gaze_enable_description = {
        en = "Activate Scrier's Gaze automatically (if warp unbound is equipped) when the timer reaches the end.",
    },
    -- Venting Shriek
    venting_shriek_header = {
        en = "Venting Shriek (Vent Warp Charge)",
    },
    auto_vent_emergency_enable = {
        en = "Emergency Venting Shriek",
    },
    auto_vent_emergency_enable_description = {
        en = "Automatically activate Venting Shriek when peril reaches emergency threshold to prevent explosion. This is your safety net.",
    },
    auto_vent_emergency_threshold = {
        en = "Emergency Threshold",
    },
    auto_vent_emergency_threshold_description = {
        en = "Peril threshold for emergency Venting Shriek activation. [Default: 1.0 = 100%]",
    },
    auto_vent_optimized_enable = {
        en = "Optimized Venting Shriek",
    },
    auto_vent_optimized_enable_description = {
        en = "Automatically activate Venting Shriek only at MAX Warp Charges (4 or 6 depending on Warp Battery talent). Maximizes warp charge efficiency.",
    },
    -- Centin Shriek
    centin_shriek_header = {
        en = "Centin Shriek",
    },
    auto_centin_enable = {
        en = "Auto Centin Shriek",
    },
    auto_centin_enable_description = {
        en = "Automatically activate Centin Shriek when Warp Charges reach the configured amount.",
    },
    auto_centin_threshold = {
        en = "Centin Shriek Warp Charges",
    },
    auto_centin_threshold_description = {
        en = "Number of Warp Charges required to activate Centin Shriek (1-6). [Default: 6]",
    },
}

return loc
