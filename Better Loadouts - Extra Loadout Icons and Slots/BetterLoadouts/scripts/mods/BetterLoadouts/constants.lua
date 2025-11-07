-- File: scripts/mods/BetterLoadouts/constants.lua
local mod = get_mod("BetterLoadouts"); if not mod then return end

-- Single shared namespace for all constants/helpers.
mod.BL                           = mod.BL or {}

-- ---------------------------------------------------------------------------
-- Version / misc
-- ---------------------------------------------------------------------------
mod.BL.VERSION                   = "1.3.1"
mod.BL.MIN_MAIN_MENU_CHARACTERS  = 8

-- Trait/blessing master-item fields to check (in order) when resolving icons.
mod.BL.ICON_FIELDS               = {
    "hud_icon",
    "display_icon_material",
    "icon",
    "small_icon",
    "texture", -- rare, but cheap to check
}

-- Extra Unicode (Private Use) code points you want available for preset icons.
mod.BL.UNICODE_EXTRA_CODES       = {
    0xE000, 0xE001, 0xE002, 0xE003, 0xE004, 0xE005, 0xE006, 0xE007,
    0xE01F, 0xE021, 0xE026, 0xE029, 0xE02E, 0xE041, 0xE042, 0xE045,
    0xE046, 0xE049, 0xE04D, 0xE04F, 0xE051, 0xE107, 0xE108, 0xE109,
    0xE10A, 0xE010, 0xE011, 0xE012, 0xE013, 0xE014, 0xE015, 0xE016,
    0xE017, 0xE018, 0xE019,
}

-- Default extra material icons to append after the 25 vanilla preset icons.
-- (These are used to seed your private icon pool; order preserved.)
mod.BL.DEFAULT_CUSTOM_ICON_PATHS = {
    "content/ui/materials/icons/item_types/ranged_weapons",
    "content/ui/materials/icons/circumstances/assault_01",
    "content/ui/materials/icons/item_types/weapons",
    "content/ui/materials/icons/item_types/melee_weapons",
    "content/ui/materials/hud/interactions/icons/grenade",
    "content/ui/materials/icons/circumstances/hunting_grounds_01",
    "content/ui/materials/icons/circumstances/ventilation_purge_01",
    "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    "content/ui/materials/icons/pocketables/hud/scripture",
    "content/ui/materials/icons/pocketables/hud/corrupted_auspex_scanner",
    -- "content/ui/materials/icons/traits/weapon_trait_119_small",
    -- "content/ui/materials/icons/traits/weapon_trait_076_small",
    -- "content/ui/materials/icons/traits/weapon_trait_167_small",
    -- "content/ui/materials/icons/traits/weapon_trait_214_small",
    -- "content/ui/textures/icons/traits/weapon_trait_119_small",
    -- "content/ui/textures/icons/traits/weapon_trait_076_small",
    -- "content/ui/textures/icons/traits/weapon_trait_167_small",
    -- "content/ui/textures/icons/traits/weapon_trait_214_small",
}

-- File: scripts/mods/BetterLoadouts/constants.lua
local mod                        = get_mod("BetterLoadouts"); if not mod then return end
mod.BL = mod.BL or {}

-- Configure which trait IDs you want to resolve & echo when opening the Inventory view.
-- Replace/extend this list with the traits you care about.
mod.BL.TRAIT_ICON_IDS = mod.BL.TRAIT_ICON_IDS or {
    -- Examples (safe to keep; missing ones will just print "false"):
    "weapon_trait_bespoke_boltpistol_p1_crit_chance_bonus_on_melee_kills",
    "weapon_trait_bespoke_boltpistol_p1_bleed_on_ranged",
    "weapon_trait_bespoke_chainsword_p1_infinite_melee_cleave_on_crit",
    "weapon_trait_bespoke_chainsword_p1_increased_attack_cleave_on_multiple_hits",
    "weapon_trait_bespoke_ogryn_pickaxe_2h_p1_increase_power_on_weapon_special_hit",
    "weapon_trait_bespoke_ogryn_combatblade_p1_infinite_melee_cleave_on_crit",
}

-- ---------------------------------------------------------------------------
-- Layout helpers
-- ---------------------------------------------------------------------------
-- Returns the layout constants table for a given preset cap (28 or 200).
-- Call as: local L = mod.BL.layout_for_limit(mod.preset_limit)
function mod.BL.layout_for_limit(limit)
    if limit == 200 then
        -- Compact grid: 10 columns * 20 rows = 200
        return {
            BAR_TOP_X     = 0,
            BAR_TOP_Y     = 50,
            BUTTON_WIDTH  = 29,
            BUTTON_HEIGHT = 43,
            BUTTON_GAP    = 0,
            TOP_PAD       = 23,
            BOTTOM_PAD    = 20,
            COLUMN_GAP    = 0,
            ROWS_PER_COL  = 20,
            MAX_COLUMNS   = 10,
            SAFE_GAP      = 40, -- tooltip horizontal gap from the bar
        }
    end

    -- Classic vertical bar: 2 columns * 14 rows = 28
    return {
        BAR_TOP_X     = -10,
        BAR_TOP_Y     = 114,
        BUTTON_WIDTH  = 44,
        BUTTON_HEIGHT = 58,
        BUTTON_GAP    = 0,
        TOP_PAD       = 48,
        BOTTOM_PAD    = 45,
        COLUMN_GAP    = 12,
        ROWS_PER_COL  = 14,
        MAX_COLUMNS   = 2,
        SAFE_GAP      = 40,
    }
end

-- Convenience getter using the currently cached mod.preset_limit.
function mod.BL.layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end
