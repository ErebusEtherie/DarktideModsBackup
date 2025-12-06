-- File: RingHud/scripts/mods/RingHud/team/throwables.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local U = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
-- Ensure visibility helpers are loaded (force-show, interlude, etc.)
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V                        = mod.team_visibility

local TH                       = {}

-- Central palette (with safe fallbacks so we never crash if palette isn't initialized yet)
mod.colors                     = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local Colors                   = mod.colors
local PALETTE                  = mod.PALETTE_ARGB255 or (Colors and Colors.PALETTE_ARGB255) or {}

local RED                      = PALETTE.AMMO_TEXT_COLOR_CRITICAL or { 255, 64, 64, 255 }
local ORANGE                   = PALETTE.AMMO_TEXT_COLOR_MEDIUM_L or { 255, 178, 102, 255 }
local WHITE                    = PALETTE.GENERIC_WHITE or { 255, 255, 255, 255 }

---------------------------------------------------------------------
-- Icon overrides (only listed items get swapped; others keep default)
---------------------------------------------------------------------
local OVERRIDE_THROWABLE_ICONS = {
    -- adamant / arbiter
    adamant_whistle           = "content/ui/materials/icons/throwables/hud/adamant_whistle",
    adamant_shock_mine        = "content/ui/materials/icons/throwables/hud/shock_mine",
    adamant_grenade_improved  = "content/ui/materials/icons/throwables/hud/adamant_grenade",

    -- zealot
    zealot_shock_grenade      = "content/ui/materials/icons/throwables/hud/stun_grenade",
    zealot_fire_grenade       = "content/ui/materials/icons/throwables/hud/flame_grenade",
    zealot_throwing_knives    = "content/ui/materials/icons/throwables/hud/throwing_knife",

    -- veteran
    veteran_frag_grenade      = "content/ui/materials/icons/throwables/hud/frag_grenade",
    veteran_krak_grenade      = "content/ui/materials/icons/throwables/hud/krak_grenade",
    veteran_smoke_grenade     = "content/ui/materials/icons/throwables/hud/smoke_grenade",

    -- ogryn
    ogryn_grenade_friend_rock = "content/ui/materials/icons/throwables/hud/rock_grenade",
    ogryn_grenade_box_cluster = "content/ui/materials/icons/throwables/hud/ogryn_grenade_box",
    ogryn_grenade_frag        = "content/ui/materials/icons/throwables/hud/ogryn_frag_grenade",
}

-- Groups for context rules
local GROUP_LT2_VISIBLE        = { -- visible if < 2 charges
    zealot_shock_grenade      = true,
    zealot_fire_grenade       = true,
    ogryn_grenade_box_cluster = true,
}
local GROUP_LT1_VISIBLE        = { -- visible if < 1 charge (== 0)
    veteran_frag_grenade     = true,
    veteran_krak_grenade     = true,
    veteran_smoke_grenade    = true,
    ogryn_grenade_frag       = true,
    adamant_shock_mine       = true,
    adamant_grenade_improved = true,
}

-- Internal: return the equipped grenade/blitz ability name (or nil)
local function _equipped_grenade_name(unit)
    if not unit or not Unit.alive(unit) then return nil end
    local has_ext = ScriptUnit.has_extension(unit, "ability_system")
    if not has_ext then return nil end

    local ability_ext = ScriptUnit.extension(unit, "ability_system")
    if not (ability_ext and ability_ext.equipped_abilities) then return nil end

    local ok, abilities = pcall(function() return ability_ext:equipped_abilities() end)
    if not ok or not abilities then return nil end

    local ga = abilities.grenade_ability
    if type(ga) == "table" and ga.name then
        return ga.name
    end
    return nil
end

---------------------------------------------------------------------
-- New: provide an icon override (or nil to keep default)
---------------------------------------------------------------------
function TH.icon_override_for(unit, archetype_name)
    -- Team tiles never show a throwable for psykers; keep behavior consistent.
    if archetype_name == "psyker" then
        return nil
    end

    local name = _equipped_grenade_name(unit)
    if not name then
        return nil
    end

    -- Return override path if we know this grenade; otherwise nil (fallback to vanilla icon).
    return OVERRIDE_THROWABLE_ICONS[name]
end

---------------------------------------------------------------------
-- Existing logic (unchanged): count charges from ext/component
---------------------------------------------------------------------
function TH.counts(unit)
    if not unit or not Unit.alive(unit) then return 0, 0 end

    local cur, max = 0, 0

    -- Primary (safe) path: ability extension
    local ability_ext = ScriptUnit.has_extension(unit, "ability_system") and ScriptUnit.extension(unit, "ability_system")
    if ability_ext and ability_ext:ability_is_equipped("grenade_ability") then
        cur = ability_ext:remaining_ability_charges("grenade_ability") or 0
        max = ability_ext:max_ability_charges("grenade_ability") or 0
    end

    -- Component fallback if extension returned nothing
    if cur == 0 and max == 0 then
        local uds  = ScriptUnit.has_extension(unit, "unit_data_system") and
            ScriptUnit.extension(unit, "unit_data_system")
        local comp = uds and uds:read_component("grenade_ability") or nil
        if comp then
            local ok_num, n = pcall(function() return comp.num_charges end)
            if ok_num and type(n) == "number" then cur = n end

            local ok_max, m = pcall(function() return comp.max_charges end)
            if ok_max and type(m) == "number" then max = math.max(max, m) end
        end
    end

    return cur, max
end

---------------------------------------------------------------------
-- Contextual visibility rules per design
---------------------------------------------------------------------
-- Update the throwable icon style based on settings + state.
-- Psyker still never shows a throwable.
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

    -- Never visible for psyker archetype (team tiles)
    if archetype_name == "psyker" then
        style_throwable.visible = false
        return
    end

    local cur, max = TH.counts(unit)

    -- If the unit simply has no throwable ability at all, hide regardless of mode
    if (max or 0) == 0 and (cur or 0) == 0 then
        style_throwable.visible = false
        return
    end

    -- “Always” mode
    if s.team_munitions == "team_munitions_always" then
        style_throwable.visible = true
        -- Color logic (unchanged)
        if cur == 0 then
            style_throwable.color = RED
        elseif (max or 0) ~= 1 and cur == 1 then
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
    local local_dead = (V and V.local_player_is_dead and V.local_player_is_dead()) or false

    if force_show or local_dead then
        show = true
    end

    -- Charge thresholds by grenade type
    if not show and name then
        if GROUP_LT2_VISIBLE[name] and (cur or 0) < 2 then
            show = true
        elseif GROUP_LT1_VISIBLE[name] and (cur or 0) < 1 then
            show = true
        end
    end

    -- Unified interlude (calm+full team OR local dead/hogtied)
    if not show and V and V.interlude then
        if V.interlude() then
            show = true
        end
    end

    style_throwable.visible = show

    if not show then
        return
    end

    -- Color logic (unchanged)
    if cur == 0 then
        style_throwable.color = RED
    elseif (max or 0) ~= 1 and cur == 1 then
        style_throwable.color = ORANGE
    else
        style_throwable.color = WHITE
    end
end

-- Expose for cross-file usage patterns
mod.team_throwables = TH

return TH
