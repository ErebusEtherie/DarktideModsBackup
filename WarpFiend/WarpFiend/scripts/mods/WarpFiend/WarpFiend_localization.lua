local mod = get_mod("WarpFiend")

local loc = {
    mod_name = {
        en = "WarpFiend",
    },
    mod_description = {
        en = "Advanced DPS optimization for Psyker basic attack gameplay with intelligent peril management",
    },
    -- Peril Management Group
    peril_management = {
        en = "Peril Management",
    },
    peril_peak_threshold = {
        en = "Peak Window Threshold",
    },
    peril_peak_threshold_description = {
        en = "Peril percentage where optimal burst window begins. [Default 0.8333 / 83.33%%]",
    },
    peril_emergency_threshold = {
        en = "Emergency Threshold",
    },
    peril_emergency_threshold_description = {
        en = "Peril percentage considered critical danger. [Default 0.97 / 97%%]",
    },
    micro_quell_duration = {
        en = "Micro-Quell Duration",
    },
    micro_quell_duration_description = {
        en = "How long to quell during micro-quell cycles. [Default 0.4s]",
    },
    -- Venting Shriek Group
    venting_shriek = {
        en = "Venting Shriek",
    },
    auto_shriek_enable = {
        en = "Auto Venting Shriek",
    },
    auto_shriek_enable_description = {
        en = "Automatically trigger Venting Shriek when conditions are optimal.",
    },
    target_density_threshold = {
        en = "Target Density Threshold",
    },
    target_density_threshold_description = {
        en = "Minimum number of enemies required for optimal Shriek execution. [Default 3]",
    },
    hold_shriek_for_value = {
        en = "Hold Shriek for Better Value",
    },
    hold_shriek_for_value_description = {
        en = "Delay Shriek when target density is low to maintain Warp Siphon damage buff.",
    },
    elite_priority = {
        en = "Elite/Specialist Priority",
    },
    elite_priority_description = {
        en = "Always execute Shriek immediately when Elite or Specialist is present.",
    },
    -- Input Mode Group
    input_mode_settings = {
        en = "Input Mode",
    },
    input_mode = {
        en = "Input Handling Mode",
    },
    input_mode_description = {
        en = "Choose between Auto-Cast (mod triggers abilities) or Input Blocking (mod blocks inputs, you press buttons).",
    },
    input_mode_auto = {
        en = "Auto-Cast",
    },
    input_mode_block = {
        en = "Input Blocking",
    },
    -- Buff Monitoring Group
    buff_monitoring = {
        en = "Buff Monitoring",
    },
    track_becalming_eruption = {
        en = "Track Becalming Eruption",
    },
    track_becalming_eruption_description = {
        en = "Allow continuous firing during Becalming Eruption (reduced peril generation).",
    },
    track_psykinetic_aura = {
        en = "Track Psykinetic's Aura",
    },
    track_psykinetic_aura_description = {
        en = "Adjust cooldown expectations when Elite/Specialist dies in coherency.",
    },
    track_empyric_shock = {
        en = "Track Empyric Shock",
    },
    track_empyric_shock_description = {
        en = "Priority Shriek execution when target has 5 stacks of Empyric Shock.",
    },
    -- Weapon Profile Group
    weapon_profile = {
        en = "Weapon Profile",
    },
    staff_type = {
        en = "Staff Type",
    },
    staff_type_description = {
        en = "Select your current staff for accurate peril cost calculation.",
    },
    staff_trauma = {
        en = "Trauma Staff",
    },
    staff_purgatus = {
        en = "Purgatus Staff",
    },
    staff_surge = {
        en = "Surge Staff",
    },
    staff_voidstrike = {
        en = "Voidstrike Staff",
    },
    custom_peril_cost = {
        en = "Custom Peril Cost Per Shot",
    },
    custom_peril_cost_description = {
        en = "Override auto-calculated peril cost. [Default 0 = use staff preset]",
    },
    -- Debug Group
    debug = {
        en = "Debug",
    },
    debug_logging = {
        en = "Enable Debug Logging",
    },
    debug_logging_description = {
        en = "Log which action the decision tree selects.",
    },
    -- Action Names for Debug
    action_1 = {
        en = "ACTION 1: Emergency Shriek",
    },
    action_2 = {
        en = "ACTION 2: Emergency Quell",
    },
    action_3 = {
        en = "ACTION 3: Primary Fire Ramp-Up",
    },
    action_4 = {
        en = "ACTION 4: Peak Window Burst",
    },
    action_5 = {
        en = "ACTION 5: Optimal Shriek",
    },
    action_6 = {
        en = "ACTION 6: Value-Hold Micro-Quell",
    },
}

return loc