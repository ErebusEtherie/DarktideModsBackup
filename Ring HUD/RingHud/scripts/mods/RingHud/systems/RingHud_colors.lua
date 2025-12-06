-- File: RingHud/scripts/mods/RingHud/systems/RingHud_colors.lua
-- Single source of truth for Ring HUD colours (no tint changes).
-- - Prefers Darktide utilities where available.
-- - Removes duplicated colour entries (no aliasing).
-- - Exposes shared helpers needed across files here.

-- *IMPORTANT I do not want functions to convert ARGB255 to RGBA1 and vice versa in any RingHud file.  Call sites need to call the correct palette table from this file.
-- *IMPORTANT I do not want synonym mapping in any RingHud file. Call sites need to call the correct colour from this file.

local mod = get_mod("RingHud")
if not mod then return {} end

-- Darktide's colour utilities (for ARGB -> material RGBA)
local ColorUtilities = require("scripts/utilities/ui/colors")
local PALETTE        = {}

-- Canonical ARGB palette (0..255)
mod.PALETTE_ARGB255  = {
    HEALTH_GREEN             = { 255, 38, 204, 26 },
    POWER_RED                = { 255, 205, 51, 26 }, -- aka STRENGTH/DAMAGE red
    SPEED_BLUE               = { 255, 0, 127, 218 },
    COOLDOWN_YELLOW          = { 255, 230, 192, 13 },
    AMMO_ORANGE              = { 255, 255, 130, 1 },
    TOME_BLUE                = { 255, 80, 110, 160 },
    GRIMOIRE_PURPLE          = { 255, 102, 38, 98 },
    GENERIC_CYAN             = { 255, 60, 220, 220 },
    GENERIC_WHITE            = { 255, 255, 255, 255 },

    TOUGHNESS_OVERSHIELD     = { 255, 255, 214, 1 }, -- gold
    TOUGHNESS_TEAL           = { 255, 108, 187, 196 },
    TOUGHNESS_BROKEN         = { 255, 255, 80, 80 }, -- red

    AMMO_TEXT_COLOR_HIGH     = { 255, 168, 191, 153 },
    AMMO_TEXT_COLOR_MEDIUM_H = { 255, 255, 255, 150 },
    AMMO_TEXT_COLOR_MEDIUM_L = { 255, 255, 150, 51 },
    AMMO_TEXT_COLOR_LOW      = { 255, 255, 51, 51 },
    AMMO_TEXT_COLOR_CRITICAL = { 255, 255, 0, 0 },
    peril_color_spectrum     = {
        { 200, 138, 201, 38 }, -- green
        { 200, 138, 201, 38 },
        { 255, 255, 202, 58 },
        { 255, 255, 146, 76 },
        { 255, 255, 89,  94 },
        { 255, 244, 121, 229 },
        { 255, 244, 50,  229 }, -- violet
    }
}

-- RGBA (0..1) small set we keep here (used elsewhere)
mod.PALETTE_RGBA1    = {
    HEALTH_GREEN         = { 0.15, 0.80, 0.10, 1.00 },
    POWER_RED            = { 0.75, 0.00, 0.00, 1.00 }, -- aka STRENGTH/DAMAGE red
    SPEED_BLUE           = { 0.00, 0.00, 0.30, 1.00 },
    COOLDOWN_YELLOW      = { 1.00, 0.20, 0.00, 1.00 },
    AMMO_ORANGE          = { 1.00, 0.51, 0.00, 1.00 },
    TOME_BLUE            = { 0.31, 0.43, 0.63, 1.00 },
    GRIMOIRE_PURPLE      = { 0.40, 0.15, 0.38, 1.00 },
    GENERIC_CYAN         = { 0.24, 0.86, 0.86, 1.00 },
    GENERIC_WHITE        = { 1.00, 1.00, 1.00, 1.00 },

    -- default_toughness_color_rgba  = { 0.80, 1.00, 1.00, 1.00 },    -- teal
    TOUGHNESS_TEAL       = { 0.33, 0.56, 0.59, 1.00 }, -- teal, adjusted
    -- TOUGHNESS_OVERSHIELD          = { 1.00, 0.84, 0.00, 1.00 }, -- gold
    TOUGHNESS_OVERSHIELD = { 1.00, 0.65, 0.00, 1.00 }, -- gold, adjusted
    -- TOUGHNESS_BROKEN              = { 1.00, 0.31, 0.31, 1.00 }, -- red
    TOUGHNESS_BROKEN     = { 1.00, 0.24, 0.24, 1.00 }, -- red, adjusted


    dodge_color_full_rgba         = { 0.61, 1.00, 0.31, 1.00 },
    -- dodge_color_positive_rgba     = { 0.94, 0.90, 0.31, 1.00 }, -- yellow
    dodge_color_positive_rgba     = { 0.72, 0.69, 0.24, 1.00 }, -- yellow, adjusted
    -- dodge_color_negative_rgba     = { 1.00, 0.31, 0.31, 1.00 },
    dodge_color_negative_rgba     = { 1.00, 0.24, 0.24, 1.00 }, -- red, adjusted

    default_corruption_color_rgba = { 0.80, 0.27, 0.80, 1.00 },
    default_damage_color_rgba     = { 0.50, 0.50, 0.50, 1.00 }, -- mid-grey

    -- AMMO_BAR_COLOR_HIGH           = { 0.66, 0.75, 0.60, 1.00 },
    AMMO_BAR_COLOR_HIGH           = { 0.51, 0.58, 0.46, 1.00 }, -- adjusted
    -- AMMO_BAR_COLOR_MEDIUM_H       = { 1.00, 1.00, 0.59, 1.00 },
    AMMO_BAR_COLOR_MEDIUM_H       = { 1.00, 1.00, 0.45, 1.00 }, -- adjusted
    -- AMMO_BAR_COLOR_MEDIUM_L       = { 1.00, 0.59, 0.20, 1.00 },
    AMMO_BAR_COLOR_MEDIUM_L       = { 1.00, 0.45, 0.15, 1.00 }, -- adjusted
    -- AMMO_BAR_COLOR_LOW            = { 1.00, 0.20, 0.20, 1.00 },
    AMMO_BAR_COLOR_LOW            = { 1.00, 0.15, 0.15, 1.00 },
    AMMO_BAR_COLOR_CRITICAL       = { 1.00, 0.00, 0.00, 1.00 },

    peril_color_spectrum          = { -- 7 steps
        -- { 0.54, 0.79, 0.15, 1.00 }, -- green
        { 0.42, 0.61, 0.11, 1.00 },   -- green, adjusted
        -- { 0.54, 0.79, 0.15, 1.00 }, -- second bracket is also green
        { 0.42, 0.61, 0.11, 1.00 },   -- green, adjusted
        -- { 1.00, 0.79, 0.23, 1.00 }, -- step 3
        { 1.00, 0.61, 0.17, 1.00 },   -- step 3, adjusted
        -- { 1.00, 0.57, 0.30, 1.00 },   -- step 4
        { 1.00, 0.44, 0.23, 1.00 },   -- step 4, adjusted
        -- { 1.00, 0.35, 0.37, 1.00 },   -- step 5
        { 1.00, 0.27, 0.28, 1.00 },   -- step 5
        -- { 0.96, 0.47, 0.90, 1.00 },   -- step 6
        { 0.74, 0.37, 0.69, 1.00 },   -- step 6
        -- { 0.96, 0.20, 0.90, 1.00 },   -- violet
        { 0.74, 0.15, 0.69, 1.00 },   -- violet
    }

}

PALETTE              = mod.PALETTE_ARGB255
return PALETTE
