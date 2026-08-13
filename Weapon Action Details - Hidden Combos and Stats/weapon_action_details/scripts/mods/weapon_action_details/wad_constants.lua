-- File: weapon_action_details/scripts/mods/weapon_action_details/wad_constants.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")

local ARMOR_TYPES = ArmorSettings.types

mod.WAD_DAMAGE_TEXT_COLOR = "{#color(171,91,81)}"
mod.WAD_IMPACT_TEXT_COLOR = "{#color(95,152,180)}"
mod.WAD_CLEAVE_TEXT_COLOR = "{#color(90,170,100)}"
mod.WAD_CRIT_TEXT_COLOR = "{#color(255,128,0)}"
mod.WAD_CRIT_CHANCE_TEXT_COLOR = mod.WAD_CRIT_TEXT_COLOR
mod.WAD_PERIL_TEXT_COLOR = "{#color(180,100,255)}"
mod.WAD_HEAT_TEXT_COLOR = mod.WAD_PERIL_TEXT_COLOR
mod.WAD_SPRINT_TECH_TEXT_COLOR = "{#color(255,255,255)}"
mod.WAD_STAGGER_INFO_TEXT_COLOR = mod.WAD_IMPACT_TEXT_COLOR
mod.WAD_CLEAVE_INFO_TEXT_COLOR = mod.WAD_CLEAVE_TEXT_COLOR
mod.WAD_COMBO_LOOP_TEXT_COLOR = "{#color(255,200,80)}"
mod.WAD_DAMAGE_GLYPH = ""
mod.WAD_IMPACT_GLYPH = ""
mod.WAD_CLEAVE_GLYPH = ""
mod.WAD_CRIT_GLYPH = ""
mod.WAD_PERIL_GLYPH = ""
mod.WAD_HEAT_GLYPH = ""
mod.WAD_SPRINT_TECH_GLYPH = ""
mod.WAD_RICH_TEXT_RESET = "{#reset()}"

mod.ARMOR_DAMAGE_ORDER = {
    ARMOR_TYPES.unarmored,
    ARMOR_TYPES.disgustingly_resilient,
    ARMOR_TYPES.armored,
    ARMOR_TYPES.resistant,
    ARMOR_TYPES.super_armor,
    ARMOR_TYPES.berserker,
}

mod.TAB_ATTACK_PATTERNS = 1
mod.TAB_ACTIONS = 2
mod.TAB_SPECIAL_ACTIONS = 3
mod.TAB_TRAINING = 4
mod.TAB_HEIGHT = 44
mod.TAB_GAP = 16
mod.TAB_BOTTOM_SPACING = 16
mod.ACTIONS_TAB_MAX_HEIGHT = 900
mod.MAX_ACTION_CHAIN_TEXT_LENGTH = 180

mod.ACTION_ICON_SIZE = 32
mod.ACTION_ICON_PADDING = 14
mod.ACTION_ICON_X = 16
mod.ACTION_ICON_Y = 14
mod.ACTION_TEXT_ROW_HEIGHT = 24
mod.ACTION_NAME_ROW_HEIGHT = 30
mod.ACTION_ENTRY_BOTTOM_PADDING = 10
mod.ACTION_ENTRY_MIN_HEIGHT = 56

mod.WAD_DAMAGE_HIT_ZONE_BODY = "body"
mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT = "weakspot"
mod.WAD_DAMAGE_HIT_ZONE_CRITICAL = "critical"
mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT = "critical_weakspot"
mod.wad_damage_hit_zone = mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT

mod.WAD_DAMAGE_HIT_ZONE_NEXT = {
    [mod.WAD_DAMAGE_HIT_ZONE_BODY] = mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT,
    [mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT] = mod.WAD_DAMAGE_HIT_ZONE_BODY,
}

mod.WAD_DAMAGE_HIT_ZONE_IS_WEAKSPOT = {
    [mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT] = true,
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT] = true,
}

mod.WAD_DAMAGE_HIT_ZONE_IS_CRITICAL = {
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL] = true,
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT] = true,
}

mod.WAD_RANGE_MODE_OPTIMAL = "optimal"
mod.WAD_RANGE_MODE_FAR = "far"
mod.WAD_RANGE_MODE_NEAR = "near"
mod.wad_range_mode = mod.WAD_RANGE_MODE_OPTIMAL

mod.WAD_RANGE_MODE_NEXT = {
    [mod.WAD_RANGE_MODE_OPTIMAL] = mod.WAD_RANGE_MODE_FAR,
    [mod.WAD_RANGE_MODE_FAR] = mod.WAD_RANGE_MODE_NEAR,
    [mod.WAD_RANGE_MODE_NEAR] = mod.WAD_RANGE_MODE_OPTIMAL,
}

mod.WAD_CHARGE_LEVEL_100 = "charge_100"
mod.WAD_CHARGE_LEVEL_30 = "charge_30"
mod.WAD_CHARGE_LEVEL_1 = "charge_1"
mod.wad_charge_level = mod.WAD_CHARGE_LEVEL_100

mod.WAD_CHARGE_LEVEL_NEXT = {
    [mod.WAD_CHARGE_LEVEL_100] = mod.WAD_CHARGE_LEVEL_30,
    [mod.WAD_CHARGE_LEVEL_30] = mod.WAD_CHARGE_LEVEL_1,
    [mod.WAD_CHARGE_LEVEL_1] = mod.WAD_CHARGE_LEVEL_100,
}

mod.WAD_ACTION_FILTER_NORMAL = "normal"
mod.WAD_ACTION_FILTER_SPECIAL = "special"

mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS = {
    activate_special = true,
    ranged_load_special = true,
    toggle_special = true,
    toggle_special_with_block = true,
}

mod.WAD_SPECIAL_ACTION_INPUT_PREFIXES = {
    special_action = true,
    weapon_extra = true,
    start_attack_special = true,
    light_attack_special = true,
    heavy_attack_special = true,
}

mod.EXCLUDED_ACTION_KINDS = {
    inspect = true,
    inspect_3p = true,
    spawn_projectile = true,
    unwield = true,
    unwield_to_specific = true,
    windup = true,
    dummy = true,
    target_finder = true,
}

-- input names, not action names or kinds
mod.EXCLUDED_CHAIN_ACTION_NAMES = {
    block = true,
    combat_ability = true,
    grenade_ability = true,
    special_action = true,
    wield = true,
    vent = true,
    shoot_braced = true,
}

mod.EXCLUDED_SPECIAL_ACTION_DISPLAY_NAME_WEAPON_TEMPLATES = {
    --     powermaul_p2_m1 = true,
}
