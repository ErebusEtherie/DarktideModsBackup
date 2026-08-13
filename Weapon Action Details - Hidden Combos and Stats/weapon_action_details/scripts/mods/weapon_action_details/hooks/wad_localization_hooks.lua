-- File: weapon_action_details/scripts/mods/weapon_action_details/hooks/wad_localization_hooks.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

-- ============================================================================
-- LOCAL CONSTANTS
-- ============================================================================

local DYNAMIC_HIT_ZONE_LOCALIZATION_KEYS = {
    wad_dynamic_hit_zone_body = mod.WAD_LOC.WEAPON_DETAILS_BODY,
    wad_dynamic_hit_zone_weakspot = mod.WAD_LOC.WEAPON_DETAILS_WEAKSPOT,
    wad_dynamic_hit_zone_critical = mod.WAD_LOC.WEAPON_DETAILS_CRIT,
    wad_dynamic_hit_zone_critical_weakspot = mod.WAD_LOC.WEAPON_DETAILS_CRIT_HS,
}

local DYNAMIC_RANGE_MODES = {
    wad_dynamic_range_optimal = { mode = mod.WAD_RANGE_MODE_OPTIMAL, loc_key = mod.WAD_LOC.WEAPON_KEYWORD_HIGH_DAMAGE },
    wad_dynamic_range_far = { mode = mod.WAD_RANGE_MODE_FAR, loc_key = mod.WAD_LOC.WEAPON_STATS_DISPLAY_FAR },
    wad_dynamic_range_near = { mode = mod.WAD_RANGE_MODE_NEAR, loc_key = mod.WAD_LOC.WEAPON_STATS_DISPLAY_NEAR },
}

local DYNAMIC_CHARGE_MODES = {
    wad_dynamic_charge_100 = {
        localization_key = mod.WAD_LOC.EXPERTISE_CRAFTING_MODIFIERS_MAX,
    },
    wad_dynamic_charge_30 = {
        text = "30%",
    },
    wad_dynamic_charge_1 = {
        localization_key = mod.WAD_LOC.SETTINGS_MENU_LOW,
    },
}

-- ============================================================================
-- HOOKS
-- ============================================================================

mod:hook(CLASS.LocalizationManager, "localize", function(func, self, key, no_cache, context)
    -- Check if the requested key is one of WAD's custom dynamic Hit Zone keys.
    local hit_zone_localization_key = DYNAMIC_HIT_ZONE_LOCALIZATION_KEYS[key]

    if hit_zone_localization_key then
        -- Returns format: "Mode Switch (Weakspot)".
        return func(self, mod.WAD_LOC.WEAPON_SPECIAL_MODE_SWITCH, no_cache, context) ..
            " (" .. func(self, hit_zone_localization_key, no_cache, context) .. ")"
    end

    -- Check if the requested key is one of WAD's custom dynamic Range Mode keys.
    local range_data = DYNAMIC_RANGE_MODES[key]

    if range_data then
        local range_text = func(self, mod.WAD_LOC.STATS_DISPLAY_RANGE_STAT, no_cache, context)
        local range_mode_text = func(self, range_data.loc_key, no_cache, context)

        -- If it is the "Optimal" range mode, wrap it in parentheses.
        if range_data.mode == mod.WAD_RANGE_MODE_OPTIMAL then
            range_mode_text = "(" .. range_mode_text .. ")"
        end

        return range_text .. " " .. range_mode_text
    end

    -- Check if the requested key is one of WAD's custom dynamic Charge Level keys.
    local charge_mode = DYNAMIC_CHARGE_MODES[key]

    if charge_mode then
        local charge_text = func(self, mod.WAD_LOC.WEAPON_KEYWORD_CHARGED_ATTACK, no_cache, context)
        local charge_mode_text = charge_mode.text

        if charge_mode.localization_key then
            charge_mode_text = func(self, charge_mode.localization_key, no_cache, context)
        end

        -- Returns formats such as "Charged Attack (Low)", "Charged Attack (30%)", and "Charged Attack (Max)".
        return charge_text .. " (" .. charge_mode_text .. ")"
    end

    -- If the key isn't related to WAD, pass it back to the original game function normally.
    return func(self, key, no_cache, context)
end)
