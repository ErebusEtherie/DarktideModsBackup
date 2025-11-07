-- File: scripts/mods/BetterLoadouts/BetterLoadouts.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

-- Load shared constants first (used throughout this file)
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/constants")

-- Load split-out hook files
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/ui_manager_load_view")
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/view_element_profile_presets_definitions")
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/profile_presets_layout_changed")
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/profile_presets_setup_buttons")
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/profile_presets_present_grid")
mod:io_dofile("BetterLoadouts/scripts/mods/BetterLoadouts/hooks/profile_presets_left_pressed")

-- ---- Settings cache (once at init) + centralized on_setting_changed ----------
mod.preset_limit = mod:get("preset_limit") or 28

-- Forward declare (so on_setting_changed can call it even though we define it later)
local _apply_limit_to_settings

function mod.on_setting_changed(setting_id)
    if setting_id == "preset_limit" then
        mod.preset_limit = mod:get("preset_limit") or 28
        _apply_limit_to_settings()
    end
end

-- -----------------------------------------------------------------------------

-- Detect DSMI once (for compatibility choices below)
local HAS_DSMI = (get_mod and get_mod("DistinctSideMissionIcons")) ~= nil

-- Preload class so we can define a shim before DSMI tries to hook it
pcall(require, "scripts/ui/views/mission_board_view/mission_board_view")

-- Compatibility shim for older mods expecting MissionBoardView._populate_mission_widget
do
    if HAS_DSMI then
        local MBV = rawget(_G, "CLASS") and CLASS.MissionBoardView
        if MBV and MBV._populate_mission_widget == nil and MBV._create_mission_widget_from_mission then
            function MBV:_populate_mission_widget(mission, blueprint_name, slot, ...)
                return self:_create_mission_widget_from_mission(mission, blueprint_name, slot)
            end
        end
    end
end

local ViewElementProfilePresetsSettings =
    require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")
local MainMenuViewSettings = require("scripts/ui/views/main_menu_view/main_menu_view_settings")

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

-- >>> The classic explicit assignment is back, now based on the cached setting.
--     This guarantees the cap applies even if the settings table isn't on _G.
ViewElementProfilePresetsSettings.max_profile_presets = mod.preset_limit or 28

-- Helper sets BOTH the module table and the (optional) global symbol
function _apply_limit_to_settings()
    local cap = mod.preset_limit or 28

    -- Always set the module table we required above
    if ViewElementProfilePresetsSettings then
        ViewElementProfilePresetsSettings.max_profile_presets = cap
    end

    -- Also set the global if it exists (some builds/mods look there)
    local S = rawget(_G, "ViewElementProfilePresetsSettings")
    if S then
        S.max_profile_presets = cap
    end
end

-- Apply current limit to engine settings right away (after require + explicit set)
_apply_limit_to_settings()

-- Main Menu: keep ≥ configured minimum characters
if MainMenuViewSettings then
    local min_chars = mod.BL.MIN_MAIN_MENU_CHARACTERS or 8
    MainMenuViewSettings.max_num_characters = math.max(MainMenuViewSettings.max_num_characters or 0, min_chars)
end

function mod.on_all_mods_loaded()
    mod:info(mod.BL.VERSION)

    -- Enforce current limit & ≥ configured minimum characters
    _apply_limit_to_settings()
    if MainMenuViewSettings then
        local min_chars = mod.BL.MIN_MAIN_MENU_CHARACTERS or 8
        MainMenuViewSettings.max_num_characters = math.max(MainMenuViewSettings.max_num_characters or 0, min_chars)
    end
end
