-- File: RingHud/scripts/mods/RingHud/team/team_grenades.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Guard against double loading to prevent rehooking warning
if mod.team_throwables then
    return mod.team_throwables
end

local U = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
-- Ensure visibility helpers are loaded (force-show, interlude, etc.)
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V           = mod.team_visibility

local TH          = {}

-- Central palette (with safe fallbacks so we never crash if palette isn't initialized yet)
mod.colors        = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local Colors      = mod.colors
local PALETTE     = mod.PALETTE_ARGB255 or (Colors and Colors.PALETTE_ARGB255) or {}

local RED         = PALETTE.AMMO_TEXT_COLOR_CRITICAL
local ORANGE      = PALETTE.AMMO_TEXT_COLOR_MEDIUM_L
local WHITE       = PALETTE.GENERIC_WHITE

---------------------------------------------------------------------
-- Cache & Hooks
---------------------------------------------------------------------
local _icon_cache = {}

-- Clear cache on game mode init to ensure we don't hold stale peer data across sessions
mod:hook_safe(CLASS.GameModeManager, "init", function(self, game_mode_context, game_mode_name, ...)
    _icon_cache = {}
end)

---------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------

-- Items in this list only appear when count is < 1 (Empty).
-- All other valid grenades default to appearing when count is < 2.
local GROUP_LT1_VISIBLE = {
    -- veteran
    veteran_frag_grenade     = true,
    veteran_krak_grenade     = true,
    veteran_smoke_grenade    = true,
    -- ogryn
    ogryn_grenade_frag       = true,
    -- arbitrator
    adamant_shock_mine       = true,
    adamant_grenade_improved = true,
}

-- Internal: return the equipped grenade/blitz ability name (or nil)
local function _equipped_grenade_name(unit)
    if not unit or not Unit.alive(unit) then return nil end

    if not ScriptUnit.has_extension(unit, "ability_system") then
        return nil
    end

    local ability_ext = ScriptUnit.extension(unit, "ability_system")
    if not (ability_ext and ability_ext.equipped_abilities) then
        return nil
    end

    -- Direct call (no pcall). Darktide ability_extension guarantees this method.
    local abilities = ability_ext:equipped_abilities()
    if not abilities then
        return nil
    end

    local ga = abilities.grenade_ability
    if type(ga) == "table" and ga.name then
        return ga.name
    end

    return nil
end

local function _resolve_grenade_icon(unit)
    if not unit or not Unit.alive(unit) then return nil end

    -- Try to resolve a stable ID for the cache (Peer ID for humans, Unique ID/Name for bots)
    local player = Managers.player and Managers.player:player_by_unit(unit)
    local cache_id = nil
    if player then
        cache_id = player:peer_id() or player:unique_id() or player:name()
    end

    -- Return cached if available
    if cache_id and _icon_cache[cache_id] then
        return _icon_cache[cache_id]
    end

    -- Lookup from Visual Loadout
    local vload = ScriptUnit.has_extension(unit, "visual_loadout_system") and
        ScriptUnit.extension(unit, "visual_loadout_system")
    if not vload or not vload.weapon_template_from_slot then
        return nil
    end

    local tmpl = vload:weapon_template_from_slot("slot_grenade_ability")
    if not tmpl then return nil end

    local icon = tmpl.hud_icon

    -- Cache result if we have a valid ID
    if cache_id and icon then
        _icon_cache[cache_id] = icon
    end

    return icon
end

---------------------------------------------------------------------
-- New: provide an icon override (or nil to keep default)
---------------------------------------------------------------------
function TH.icon_override_for(unit, archetype_name)
    -- Now queries the actual weapon template in the slot
    return _resolve_grenade_icon(unit)
end

---------------------------------------------------------------------
-- Existing logic (with husk-safe component fallback)
---------------------------------------------------------------------
function TH.counts(unit)
    if not unit or not Unit.alive(unit) then return 0, 0 end

    local cur, max = 0, 0

    -- Primary (safe) path: ability extension
    local ability_ext = ScriptUnit.has_extension(unit, "ability_system") and ScriptUnit.extension(unit, "ability_system")
    if ability_ext and ability_ext.ability_is_equipped and ability_ext:ability_is_equipped("grenade_ability") then
        cur = ability_ext.remaining_ability_charges and (ability_ext:remaining_ability_charges("grenade_ability") or 0) or
            0
        max = ability_ext.max_ability_charges and (ability_ext:max_ability_charges("grenade_ability") or 0) or 0
    end

    -- Husk-safe component fallback: read ONLY num_charges; do NOT touch max_charges
    if cur == 0 and max == 0 then
        local uds  = ScriptUnit.has_extension(unit, "unit_data_system") and
            ScriptUnit.extension(unit, "unit_data_system")
        local comp = uds and uds.read_component and uds:read_component("grenade_ability") or nil
        if comp then
            local n = comp.num_charges
            if type(n) == "number" then
                cur = n
                -- If max is unknown, lift it to at least current so UI can still color/show.
                if max == 0 then max = n end
            end
        end
    end

    return cur, max
end

---------------------------------------------------------------------
-- Contextual visibility rules per design
---------------------------------------------------------------------
-- Update the throwable icon style based on settings + state.
function TH.update(style_throwable, archetype_name, unit)
    if not style_throwable then return end

    local s = mod._settings or {}

    -- Tiles disabled or munitions disabled => never visible
    if s.team_hud_mode == "team_hud_disabled"
        or s.team_munitions == "team_munitions_disabled"
    then
        style_throwable.visible = false
        return
    end

    local cur, max = TH.counts(unit)
    local is_infinite = (max or 0) <= 0

    -- If the unit simply has no throwable ability at all (and isn't infinite type like Smite), hide.
    -- (Note: Smite/BrainBurst often return max=0, so we rely on the infinite check below for logic)
    if not is_infinite and max == 0 and cur == 0 then
        style_throwable.visible = false
        return
    end

    -- “Always” mode
    if s.team_munitions == "team_munitions_always" then
        style_throwable.visible = true
        -- Color logic (unchanged)
        if cur == 0 and not is_infinite then
            style_throwable.color = RED
        elseif not is_infinite and max ~= 1 and cur == 1 then
            style_throwable.color = ORANGE
        else
            style_throwable.color = WHITE
        end
        return
    end

    -- Context mode
    local show = false
    local name = _equipped_grenade_name(unit)

    -- Force gates (unified: manual hotkey OR ADS-as-hotkey from RingHud.lua)
    local force_show = (V and V.force_show_requested and V.force_show_requested()) or false
    -- local_dead covers what "interlude" used to cover in Scenario B
    local local_dead = (V and V.local_player_is_dead and V.local_player_is_dead()) or false

    if force_show or local_dead then
        show = true
    end

    -- Contextual checks (Skipped for Psykers and Infinite grenades)
    local skip_context = (archetype_name == "psyker") or is_infinite

    if not show and not skip_context then
        -- Rule: If in LT1 group, show when < 1. Otherwise, default to show when < 2.
        local threshold = (name and GROUP_LT1_VISIBLE[name]) and 1 or 2

        if (cur or 0) < threshold then
            show = true
        end
    end

    style_throwable.visible = show

    if not show then
        return
    end

    -- Color logic
    if cur == 0 and not is_infinite then
        style_throwable.color = RED
    elseif not is_infinite and max ~= 1 and cur == 1 then
        style_throwable.color = ORANGE
    else
        style_throwable.color = WHITE
    end
end

-- Expose for cross-file usage patterns
mod.team_throwables = TH

return TH
