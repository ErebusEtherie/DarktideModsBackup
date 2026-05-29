-- File: scripts/mods/BetterLoadouts/constants.lua
local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

mod.BL = mod.BL or {}

-- ---------------------------------------------------------------------------
-- Version / misc
-- ---------------------------------------------------------------------------
mod.BL.VERSION = "1.5.2"

-- Trait/blessing master-item fields to check (in order) when resolving icons.
mod.BL.ICON_FIELDS = {
    "hud_icon",
    "display_icon_material",
    "icon",
    "small_icon",
    "texture",
}

-- Extra Unicode (Private Use) code points available for preset icons.
mod.BL.UNICODE_EXTRA_CODES = {
    0xE053, 0xE000, 0xE001, 0xE002, 0xE003,
    0xE004, 0xE005, 0xE006, 0xE007, 0xE01F,
    0xE021, 0xE026, 0xE029, 0xE02E, 0xE041,
    0xE042, 0xE045, 0xE046, 0xE049, 0xE04D,
    0xE04F, 0xE051, 0xE107, 0xE108, 0xE109,
    0xE10A, 0xE010, 0xE011, 0xE012, 0xE013,
    0xE014, 0xE015, 0xE016, 0xE017, 0xE018,
    0xE019,
}

-- Default extra material icons to append after the 25 vanilla preset icons.
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
    "content/ui/materials/hud/interactions/icons/barber",
    "content/ui/materials/hud/interactions/icons/forge",
    "content/ui/materials/hud/interactions/icons/mission_board",
    "content/ui/materials/icons/throwables/hud/missile_launcher",
    "content/ui/materials/icons/pocketables/hud/syringe_power",
    "content/ui/materials/hud/interactions/icons/expeditions",
    "content/ui/materials/hud/interactions/icons/valkyrie_payload",
    "content/ui/materials/hud/interactions/icons/artillery_strike",
    "content/ui/materials/hud/interactions/icons/big_fn_grenade",
    "content/ui/materials/hud/interactions/icons/valkyrie_hover",
    "content/ui/materials/hud/interactions/icons/landmine_fire",
    "content/ui/materials/hud/interactions/icons/landmine_shock",
    "content/ui/materials/hud/interactions/icons/time_syringe",
    "content/ui/materials/hud/interactions/icons/barrel_explosive",
    "content/ui/materials/backgrounds/scanner/scanner_decoration_skull",
    "content/ui/materials/hud/interactions/icons/expeditions_death",
    "content/ui/materials/hud/interactions/icons/help",
    "content/ui/materials/icons/weapons/actions/ads",
    "content/ui/materials/icons/weapons/actions/flashlight",
}

mod.BL.TEXT_ICON_FONT_TYPE = "itc_novarese_bold"
mod.BL.TEXT_ICON_FONT_SIZE = 27
mod.BL.TEXT_PRESET_ICONS = {
    -- yes, you can add your initials or other little text strings here
    -- they will be added to the "icon" pool
    { key = "text:I",    text = "I" },
    { key = "text:II",   text = "II" },
    { key = "text:III",  text = "III" },
    { key = "text:IV",   text = "IV" },
    { key = "text:V",    text = "V" },
    { key = "text:VI",   text = "VI" },
    { key = "text:VII",  text = "VII" },
    { key = "text:VIII", text = "VIII" },
    { key = "text:IX",   text = "IX" },
    { key = "text:X",    text = "X" },
}

-- ---------------------------------------------------------------------------
-- Layout helpers
-- ---------------------------------------------------------------------------
local function _compact_layout(rows_per_col, max_columns)
    return {
        BAR_TOP_X = 0,
        BAR_TOP_Y = 50,
        BUTTON_WIDTH = 29,
        BUTTON_HEIGHT = 43,
        BUTTON_GAP = 0,
        TOP_PAD = 23,
        BOTTOM_PAD = 20,
        COLUMN_GAP = 0,
        ROWS_PER_COL = rows_per_col,
        MAX_COLUMNS = max_columns,
        SAFE_GAP = 40, -- tooltip horizontal gap from the bar
    }
end

local function _wide_roomy_layout(rows_per_col, max_columns)
    return {
        BAR_TOP_X = -10,
        BAR_TOP_Y = 90,
        BUTTON_WIDTH = 36,
        BUTTON_HEIGHT = 50,
        BUTTON_GAP = 0,
        TOP_PAD = 34,
        BOTTOM_PAD = 28,
        COLUMN_GAP = 4,
        ROWS_PER_COL = rows_per_col,
        MAX_COLUMNS = max_columns,
        SAFE_GAP = 40, -- tooltip horizontal gap from the bar
    }
end

-- Returns the layout constants table for a given preset cap.
-- Call as: local L = mod.BL.layout_for_limit(mod.preset_limit)
function mod.BL.layout_for_limit(limit)
    if limit == 300 then
        -- Compact grid: 15 columns * 20 rows = 300
        return _compact_layout(20, 15)
    elseif limit == 240 then
        -- Ultra-wide compact bar: 80 columns * 3 rows = 240
        return _compact_layout(3, 80)
    elseif limit == 200 then
        -- Compact grid: 10 columns * 20 rows = 200
        return _compact_layout(20, 10)
    elseif limit == 160 then
        -- Ultra-wide compact bar: 80 columns * 2 rows = 160
        return _compact_layout(2, 80)
    elseif limit == 60 then
        -- Wide bar: 30 columns * 2 rows = 60, with roomier spacing than compact mode
        return _wide_roomy_layout(2, 30)
    elseif limit == 30 then
        -- Single wide row: 30 columns * 1 row = 30
        return _wide_roomy_layout(1, 30)
    end

    -- Classic vertical bar: 2 columns * 14 rows = 28
    return {
        BAR_TOP_X = -10,
        BAR_TOP_Y = 114,
        BUTTON_WIDTH = 44,
        BUTTON_HEIGHT = 58,
        BUTTON_GAP = 0,
        TOP_PAD = 48,
        BOTTOM_PAD = 45,
        COLUMN_GAP = 12,
        ROWS_PER_COL = 14,
        MAX_COLUMNS = 2,
        SAFE_GAP = 40,
    }
end

-- Convenience getter using the currently cached mod.preset_limit.
function mod.BL.layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end
