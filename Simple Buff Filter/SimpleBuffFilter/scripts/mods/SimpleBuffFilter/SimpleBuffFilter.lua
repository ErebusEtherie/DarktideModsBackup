-- File: scripts/mods/SimpleBuffFilter/SimpleBuffFilter.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end
mod.version = "Simple Buff Filter version 1.4.2"

--[[
CHANGELOG
1.4.2
-- [Better] Improved mapping of screen effects to talent names
-- [Fixed] Kinetic Flayer screen effect mapping (not retroactive)

1.4.1
-- [Fixed] Compatibility issue with the Uptime mod (reported by Mitradraug)

1.4.0
-- [New] Assign buffs to separate buff bars (suggested by tdopz)

1.3.0
-- [New] Screen Modes: learns and filters moods/screen effects
-- [Fixed] Override for Fatshark linking Zealous aura to wrong talent (not retroactive)
-- [Fixed] Override for Fatshark using old name for Point Blank Barrage buffs/screen effects (not retroactive)

1.2.1
-- [Fixed] Odd position behaviour when moved with mods like Custom HUD

1.2.0
-- [Better] Added handling for live event buff localisation (not retroactive)
-- [Better] Added handling for expedition debuff localisation (not retroactive)
-- [Fixed] Added handling for ogryn houndmaster debuffs (not retroactive)
-- [Fixed] Crash when used with the Volley Fire Timer mod
-- [Fixed] Crash when refreshing with the Show Crit Chance mod

1.1.2
-- [Fixed] Fixed issue with Zealot perfect block talent and minor talent match improvements

1.1.1
-- [Fixed] Override for Fatshark listing Agile Engagement as the talent for the buff Exploit Weakness

1.1.0
-- [New] Chinese localisation
-- [New] Russian localisation
-- [Better] Decoupled buff stack text and background texture scaling process
-- [Better] Removed obsolete notifications setting
-- [Fixed] Fixed bug where new buffs did not inherit rules from old versions of that buff

1.0.0
-- Initial release

]]

-- Core prefs: shape + ensure + discovery + lookups + wipes
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/prefs")

-- Core settings: cache + the ONLY on_setting_changed live here
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/settings")

-- Core options builders: pre-tinted dropdowns + shared rule arrays
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/options_builders")

-- Syringe → pickup description mapper
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/syringe_loc")

-- Resolve helpers (archetypes, talent fallback, player_buff display_title, breed groups)
local Resolve = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/resolve")
if Resolve and Resolve.init_archetypes then
    Resolve.init_archetypes() -- discover archetypes (incl. adamant) early
end

-- Runtime context (time, local player, buff extension)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/context")

-- Runtime debug (logging, throttling, source tinting)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/debug")

-- Runtime buff helpers (template_from/template_name)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/buff_introspect")

-- Runtime mood mapping logic
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/moods")

-- Hooks (HUD)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hooks/hud_buffs")

-- Hooks (Moods)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hooks/mood_hooks")

-- ===== Shared, cross-file state (always use mod.*) ==========================
mod.NAME = "SimpleBuffFilter"

-- In-session mirrors (for quick refresh/build)
mod.discovered_talents_by_archetype = mod.discovered_talents_by_archetype or {}

-- Master-item helper (used by hooks/UI)
local MasterItems = require("scripts/backend/master_items")

-- Return the trait's loc_* key from its master-item definition
function mod.get_trait_loc_key(trait_id)
    if not trait_id or trait_id == "" then return nil end
    local item = MasterItems.get_item(trait_id)
    if not item then return nil end
    return item.display_name -- raw loc_* key
end

-- ============================================================================
-- Custom HUD Element Registration
-- ============================================================================

local custom_bar_visibility = {
    "dead",
    "alive",
    "communication_wheel",
    "player_in_danger_zone",
}

-- Register Bar 2
mod:register_hud_element({
    class_name = "HudElementSbfBuffBar2",
    filename = "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar",
    use_hud_scale = true,
    use_retained_mode = true,
    visibility_groups = custom_bar_visibility,
    context = { bar_index = 2 }
})

-- Register Bar 3
mod:register_hud_element({
    class_name = "HudElementSbfBuffBar3",
    filename = "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar",
    use_hud_scale = true,
    use_retained_mode = true,
    visibility_groups = custom_bar_visibility,
    context = { bar_index = 3 }
})
