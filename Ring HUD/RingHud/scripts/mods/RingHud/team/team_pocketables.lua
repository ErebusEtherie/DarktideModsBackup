-- File: RingHud/scripts/mods/RingHud/team/team_pocketables.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local RingHudColors      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local RSBridge           = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge")
local C                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

-- Expose on mod.* for cross-file use (central pocketables helpers)
mod.team_pocketables     = mod.team_pocketables or {}
local P                  = mod.team_pocketables

-- =========================
-- Color & kind definitions
-- =========================

-- Default tints for known pocketables (ARGB 0..255)
local pocketable_colors  = {
    syringe_corruption_pocketable    = { color = mod.PALETTE_ARGB255.HEALTH_GREEN },
    syringe_power_boost_pocketable   = { color = mod.PALETTE_ARGB255.POWER_RED },
    syringe_speed_boost_pocketable   = { color = mod.PALETTE_ARGB255.SPEED_BLUE },
    syringe_ability_boost_pocketable = { color = mod.PALETTE_ARGB255.COOLDOWN_YELLOW },

    medical_crate_pocketable         = { color = mod.PALETTE_ARGB255.HEALTH_GREEN },
    ammo_cache_pocketable            = { color = mod.PALETTE_ARGB255.SPEED_BLUE },
    tome_pocketable                  = { color = mod.PALETTE_ARGB255.TOME_BLUE },
    grimoire_pocketable              = { color = mod.PALETTE_ARGB255.GRIMOIRE_PURPLE },
}

-- Map known syringe template names -> semantic kind
-- Must stay in lockstep with pocketables_visibility.lua
local STIMM_KIND_BY_NAME = {
    syringe_corruption_pocketable    = "corruption",
    syringe_power_boost_pocketable   = "power",
    syringe_speed_boost_pocketable   = "speed",
    syringe_ability_boost_pocketable = "ability",
}

-- Map known crate/tome/grimoire names -> semantic kind
-- Must stay in lockstep with pocketables_visibility.lua
local CRATE_KIND_BY_NAME = {
    medical_crate_pocketable = "medical",
    ammo_cache_pocketable    = "ammo",
    tome_pocketable          = "tome",
    grimoire_pocketable      = "grimoire",
}

-- Build a lookup of all palette colors + any explicit { color = ... } entries.
local ALL_COLORS         = {} -- TODO Color
do
    local RC = RingHudColors or {}
    local PA = RC.PALETTE or mod.PALETTE_ARGB255

    -- A) entries like { color = ... }
    for k, v in pairs(RC) do
        if type(v) == "table" and v.color then
            ALL_COLORS[k] = v.color
        end
    end

    -- B) palette key -> ARGB
    if type(PA) == "table" then
        for k, rgba in pairs(PA) do
            if type(rgba) == "table" and rgba[1] then
                ALL_COLORS[k] = rgba
            end
        end
    end
end

-- =========================
-- Public: crates (extended)
-- =========================
-- Returns: icon, tint, kind, mapping_known
--  • kind ∈ {"medical","ammo","tome","grimoire","unknown"}
--  • mapping_known = false for seasonal/unknown variants (no known mapping)
-- NOTE: older 2-value callers keep working (icon, tint).
function P.crate_icon_and_color(unit)
    if not unit or not Unit.alive(unit) then
        return nil, nil, nil, false
    end

    local vload = ScriptUnit.has_extension(unit, "visual_loadout_system")
        and ScriptUnit.extension(unit, "visual_loadout_system")
    if not vload or not vload.weapon_template_from_slot then
        return nil, nil, nil, false
    end

    local tmpl = vload:weapon_template_from_slot("slot_pocketable")
    if not tmpl or not tmpl.name then
        return nil, nil, nil, false
    end

    local name          = tmpl.name
    local icon          = tmpl.hud_icon_small
    local palette       = mod.PALETTE_ARGB255
    local settings      = mod._settings or {}

    -- Kind + mapping-known
    local kind          = CRATE_KIND_BY_NAME[name] or "unknown"
    local mapping_known = CRATE_KIND_BY_NAME[name] ~= nil

    -- Resolve color (allow user overrides for medical/ammo)
    local color
    if name == "medical_crate_pocketable" then
        local key = settings.medical_crate_color
        color = (key and ((palette and palette[key]) or ALL_COLORS[key]))
            or (pocketable_colors[name] and pocketable_colors[name].color)
    elseif name == "ammo_cache_pocketable" then
        local key = settings.ammo_cache_color
        color = (key and ((palette and palette[key]) or ALL_COLORS[key]))
            or (pocketable_colors[name] and pocketable_colors[name].color)
    else
        color = (pocketable_colors[name] and pocketable_colors[name].color)
            or ALL_COLORS[name]
    end

    -- Final fallback
    color = color or ALL_COLORS.GENERIC_WHITE or { 255, 255, 255, 255 }

    return icon, color, kind, mapping_known
end

-- =========================
-- Public: stimms (extended)
-- =========================
-- Returns: icon, tint, kind, mapping_known
--  • kind ∈ {"power","speed","corruption","ability","unknown"}
--  • mapping_known = false for unknown/seasonal variants (no known mapping)
-- NOTE: extra return values are backward-compatible for existing 2-value callers.
function P.stimm_icon_and_color(unit)
    if not unit or not Unit.alive(unit) then
        return nil, nil, nil, false
    end

    local vload = ScriptUnit.has_extension(unit, "visual_loadout_system")
        and ScriptUnit.extension(unit, "visual_loadout_system")
    if not vload or not vload.weapon_template_from_slot then
        return nil, nil, nil, false
    end

    local tmpl = vload:weapon_template_from_slot("slot_pocketable_small")
    if not tmpl or not tmpl.name then
        return nil, nil, nil, false
    end

    local stimm_name    = tmpl.name
    local icon          = tmpl.hud_icon_small

    local kind          = STIMM_KIND_BY_NAME[stimm_name] or "unknown"
    local mapping_known = STIMM_KIND_BY_NAME[stimm_name] ~= nil

    local fallback      = (pocketable_colors[stimm_name] and pocketable_colors[stimm_name].color)
        or ALL_COLORS[stimm_name]
        or ALL_COLORS.GENERIC_WHITE
        or { 255, 255, 255, 255 }

    local tint          = (RSBridge and RSBridge.stimm_argb255 and RSBridge.stimm_argb255(stimm_name, fallback))
        or fallback

    return icon, tint, kind, mapping_known
end

-- ===================================
-- Context opacity helpers (exported)
-- ===================================
-- These are *pure transforms* used by pocketables_visibility.lua:
-- they never apply their own context rules (no intensity, proximity,
-- wield latches, etc.), only “X metric → 0..255 alpha”.

-- Corruption stimm opacity:
-- • Active when hp_frac <= C.STIMM_CORRUPTION_HP_THRESHOLD
-- • Alpha scales up as health drops (linear to 0)
-- Returns integer alpha ∈ [0,255]
function P.opacity_for_corruption(hp_frac)
    local f = tonumber(hp_frac or 0)
    f = math.clamp(f, 0, 1)
    local THRESH = C and C.STIMM_CORRUPTION_HP_THRESHOLD or 0.75
    if f > THRESH then
        return 0
    end
    -- Scale: hp THRESH -> 0 alpha, hp 0.0 -> 255 alpha
    local a = math.floor(255 * ((THRESH - f) / THRESH) + 0.5)
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return a
end

-- Ability stimm opacity:
-- • Only meaningful if max_secs is known (> 0)
-- • Alpha scales with remaining cooldown (rem / max)
-- Returns integer alpha ∈ [0,255]
function P.opacity_for_ability(rem_secs, max_secs)
    local rem = tonumber(rem_secs or 0) or 0
    local max = tonumber(max_secs or 0) or 0
    if max <= 0 or rem <= 0 then
        return 0
    end
    local a = math.floor(255 * math.clamp(rem / max, 0, 1) + 0.5)
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return a
end

-- Medical crate opacity:
-- • `carrier_hp_frac` is the carrier’s own hp fraction (0..1) – currently unused
-- • `group_hp_frac` is the average (hp+corruption) over alive strike team members.
-- We base alpha solely on group_hp_frac, so the carrier’s crate tracks *group* need.
-- Returns integer alpha ∈ [0,255]
function P.opacity_for_medical_crate(carrier_hp_frac, group_hp_frac)
    local f = tonumber(group_hp_frac or carrier_hp_frac or 0)
    f = math.clamp(f, 0, 1)
    local a = math.floor(255 * (1 - f) + 0.5)
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return a
end

-- Ammo cache opacity:
-- • `carrier_reserve_frac` is the carrier’s own reserve fraction (0..1)
-- • `group_ammo_need` is the team-wide ammo-need metric (0..1, where 1 = huge need).
-- We primarily use group_ammo_need; if it’s nil, we derive need from carrier_reserve_frac.
-- Returns integer alpha ∈ [0,255]
function P.opacity_for_ammo_cache(carrier_reserve_frac, group_ammo_need)
    local need
    if group_ammo_need ~= nil then
        need = tonumber(group_ammo_need) or 0
    else
        local frac = tonumber(carrier_reserve_frac or 1) or 1
        need = 1.0 - math.clamp(frac, 0, 1)
    end

    need = math.clamp(need, 0, 1)
    local a = math.floor(255 * need + 0.5)
    if a < 0 then a = 0 elseif a > 255 then a = 255 end
    return a
end

return P
