-- File: scripts/mods/SimpleBuffFilter/SimpleBuffFilter.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end
mod.version = "Simple Buff Filter version 1.1.2"

--[[
CHANGELOG
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

-- Hooks (HUD)
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hooks/hud_buffs")

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
