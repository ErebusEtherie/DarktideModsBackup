-- File: weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local BASE_PATH = "weapon_action_details/scripts/mods/weapon_action_details/"

-- ============================================================================
-- VANILLA LOCALIZATION GLOSSARY
-- ============================================================================
mod:io_dofile(BASE_PATH .. "wad_localization_glossary")

-- ============================================================================
-- CORE CONSTANTS
-- ============================================================================
mod:io_dofile(BASE_PATH .. "wad_constants")

-- ============================================================================
-- FORMATTING (Text, UI string generation, Number conversions)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "formatting/wad_text_helpers")
mod:io_dofile(BASE_PATH .. "formatting/wad_damage_formatter")
mod:io_dofile(BASE_PATH .. "formatting/wad_tooltip_formatter")

-- ============================================================================
-- DAMAGE (Math, Dropoff, Armor Modifiers, Hit Zones)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "damage/wad_damage_profiles")
mod:io_dofile(BASE_PATH .. "damage/wad_damage_base")
mod:io_dofile(BASE_PATH .. "damage/wad_interval_effects")
mod:io_dofile(BASE_PATH .. "damage/wad_warpfire")
mod:io_dofile(BASE_PATH .. "damage/wad_toxins")
mod:io_dofile(BASE_PATH .. "damage/wad_bleed")
mod:io_dofile(BASE_PATH .. "damage/wad_burning")
mod:io_dofile(BASE_PATH .. "damage/wad_damage_sticky")
mod:io_dofile(BASE_PATH .. "damage/wad_damage_dropoff")
mod:io_dofile(BASE_PATH .. "damage/wad_cleave")
mod:io_dofile(BASE_PATH .. "damage/wad_stagger")

-- ============================================================================
-- RESOURCES (Weapon Economies, Cooldowns, Ammo)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "resources/wad_ammo_and_ranged")
mod:io_dofile(BASE_PATH .. "resources/wad_heat_and_peril")
mod:io_dofile(BASE_PATH .. "resources/wad_stamina")
mod:io_dofile(BASE_PATH .. "resources/wad_time")

-- ============================================================================
-- ACTIONS (Context, Typing, Naming, Dependencies)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "actions/wad_innate_traits")
mod:io_dofile(BASE_PATH .. "actions/wad_actions")
mod:io_dofile(BASE_PATH .. "actions/wad_action_entries")
mod:io_dofile(BASE_PATH .. "actions/wad_action_context")
mod:io_dofile(BASE_PATH .. "actions/wad_action_chains")
mod:io_dofile(BASE_PATH .. "actions/wad_action_icons")
mod:io_dofile(BASE_PATH .. "actions/wad_action_names")
mod:io_dofile(BASE_PATH .. "actions/wad_action_name_overrides")
mod:io_dofile(BASE_PATH .. "actions/wad_action_archetypes")
mod:io_dofile(BASE_PATH .. "actions/wad_action_movement")
mod:io_dofile(BASE_PATH .. "actions/wad_sprint_tech")
mod:io_dofile(BASE_PATH .. "actions/wad_special_states")
mod:io_dofile(BASE_PATH .. "actions/wad_type_resolvers")
mod:io_dofile(BASE_PATH .. "actions/wad_semantic_parser")
mod:io_dofile(BASE_PATH .. "actions/wad_action_directions")

-- ============================================================================
-- COMBOS (Training Tab, Graph Generation, Cycle Math)
-- ============================================================================
-- Temporarily disabled
-- mod:io_dofile(BASE_PATH .. "combos/wad_combo_graph")
-- mod:io_dofile(BASE_PATH .. "combos/wad_combo_cycles")
-- mod:io_dofile(BASE_PATH .. "combos/wad_combo_scoring")
-- mod:io_dofile(BASE_PATH .. "combos/wad_training_tab")

-- ============================================================================
-- UI (Layout, Widgets, Drawing Passes)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "ui/wad_ui_blueprints")
mod:io_dofile(BASE_PATH .. "ui/wad_ui_tooltips")
mod:io_dofile(BASE_PATH .. "ui/wad_ui")

-- ============================================================================
-- HOOKS (Injections into Base Game UI)
-- ============================================================================
mod:io_dofile(BASE_PATH .. "hooks/wad_inventory_details_hooks")
mod:io_dofile(BASE_PATH .. "hooks/wad_weapon_patterns_hooks")
mod:io_dofile(BASE_PATH .. "hooks/wad_localization_hooks")
