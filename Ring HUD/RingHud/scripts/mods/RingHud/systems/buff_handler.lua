-- File: RingHud/scripts/mods/RingHud/systems/buff_handler.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Guard against double-loading
if mod._buff_handler_loaded then return {} end
mod._buff_handler_loaded = true

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

if type(mod.get_buff_stack_count) ~= "function" then
    error("RingHud: utils.lua must define mod.get_buff_stack_count(buff_ext, buff_name_lookup).")
end
if type(mod.get_buff_cooldown_fraction) ~= "function" then
    error("RingHud: utils.lua must define mod.get_buff_cooldown_fraction(buff_ext, buff_name_lookup).")
end

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------

mod.THRUST_MAX_STACKS = 3

local RANGED_WINDUP_BUFFS = {
    weapon_trait_bespoke_shotpistol_shield_p1_increases_power_while_aiming = true,
    weapon_trait_bespoke_ogryn_gauntlet_p1_windup_increases_power = true,
}

local PSYKER_SEGMENT_MAX = 3
local PSYKER_EMPOWERED_GRENADE_VISUAL_BUFFS = {
    psyker_empowered_grenades_passive_visual_buff = true,
    psyker_empowered_grenades_passive_visual_buff_increased = true,
}

-- Zealot: Until Death / Holy Revenant proc cooldown (hardcoded; driven by Wwise detector)
local ZEALOT_RESIST_DEATH_CD_S = 125.0 -- 5s invulnerability + 120s cd

-- Broker: countdown bar after toughness breaks (driven by the HUD buff 'show' hook)
local BROKER_TOUGHNESS_BROKEN_WINDOW_S = 16.0 -- 6s buff + 10s cd

-- Adamant: Terminus Warrant melee + ranged stack tracking
local ADAMANT_TERMINUS_WARRANT_MAX_STACKS = 20

-- These are the stack-carrying buffs
local ADAMANT_TERMINUS_WARRANT_MELEE_STACK_BUFFS = {
    adamant_terminus_warrant_melee = true,
}
local ADAMANT_TERMINUS_WARRANT_RANGED_STACK_BUFFS = {
    adamant_terminus_warrant_ranged = true,
}

----------------------------------------------------------------
-- Time helpers
----------------------------------------------------------------

-- Used for timers that are NOT driven by a HUD element's (dt, t).
-- Prefer Managers.time clocks; fall back to os.clock if unavailable.
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("gameplay") or MT:time("ui") or os.clock()
    end
    return os.clock()
end

----------------------------------------------------------------
-- Logic: Charge / Thrust / Windup
----------------------------------------------------------------

-- Detects any "windup increases power" buff (Thrust blessing or intrinsic weapon buff).
-- Prioritizes 'child' buffs as they typically carry the stack count.
function mod.update_thrust_state(player_unit, weapon_template_name, charge_level, hud_state)
    if not player_unit then
        return
    end

    local buff_ext = ScriptUnit.has_extension(player_unit, "buff_system")
        and ScriptUnit.extension(player_unit, "buff_system")
    local stacking = buff_ext and buff_ext._stacking_buffs
    if not stacking then
        return
    end

    local found_buff_name = nil

    -- Broad search for any active windup buff (Thrust or Intrinsic)
    for key, _ in pairs(stacking) do
        if string.find(key, "windup_increases_power", 1, true) then
            -- Prefer 'child' variants (usually the ones holding the stack count)
            if string.find(key, "child", 1, true) then
                found_buff_name = key
                break
            end
            -- Fallback to whatever matched if no child found yet
            if not found_buff_name then
                found_buff_name = key
            end
        end
    end

    if not found_buff_name then
        return
    end

    hud_state.charge_has_thrust          = true
    hud_state.charge_thrust_max_stacks   = mod.THRUST_MAX_STACKS
    hud_state.charge_thrust_charge_level = math.clamp(charge_level or 0, 0, 1)

    -- Read current stacks from the actual buff instance
    local max_sc                         = 0
    local buff_list                      = buff_ext._buffs or buff_ext._buffs_by_index
    if buff_list then
        for _, b in pairs(buff_list) do
            local name = mod.buff_template_name(b)
            if name == found_buff_name then
                local ctx = b._template_context
                local sc  = ctx and ctx.stack_count
                if sc and sc > max_sc then
                    max_sc = sc
                end
            end
        end
    end

    -- Offset by -1 as these buffs typically start at 1 stack (0 bonus)
    local buff_stacks                = math.clamp((max_sc or 0) - 1, 0, mod.THRUST_MAX_STACKS)

    -- Simplified tracking: just use integer stacks.
    hud_state.charge_thrust_stacks   = buff_stacks
    hud_state.charge_thrust_progress = 0
end

function mod.update_ranged_windup_state(player_unit, hud_state)
    if not player_unit then return end
    local buff_ext = ScriptUnit.has_extension(player_unit, "buff_system")
        and ScriptUnit.extension(player_unit, "buff_system")

    local buff_list = buff_ext and (buff_ext._buffs or buff_ext._buffs_by_index)
    if not buff_list then return end

    local found_buff = nil

    for _, b in pairs(buff_list) do
        local name = mod.buff_template_name(b)
        if name and RANGED_WINDUP_BUFFS[name] then
            found_buff = b
            break
        end
    end

    if not found_buff then return end

    hud_state.charge_has_thrust = true
    hud_state.charge_thrust_max_stacks = 5
    hud_state.charge_thrust_charge_level = 0

    local sc = 0
    -- Use visual_stack_count (steps) directly to handle 0..5 progression correctly.
    -- Standard stack_count usually stays at 1 for these traits.
    if found_buff.visual_stack_count and type(found_buff.visual_stack_count) == "function" then
        sc = found_buff:visual_stack_count()
    else
        sc = mod.buff_stack_count(found_buff)
    end

    hud_state.charge_thrust_stacks = math.clamp(sc, 0, 5)
    hud_state.charge_thrust_progress = 0
end

----------------------------------------------------------------
-- Broker proc detection via HUD buff visibility
----------------------------------------------------------------

mod._broker_buff_was_active    = false
mod._broker_buff_has_sampled   = false
mod._broker_toughness_cd_now_t = nil

-- _add_buff only fires on registration (often at spawn), so we must monitor the 'show' state.
local function _hook_hud_update(HudClass)
    if not HudClass then return end

    -- Only hook one implementation (some game versions may load both files).
    if mod._broker_hud_buffs_hooked then
        return
    end
    mod._broker_hud_buffs_hooked = true

    mod:hook_safe(HudClass, "update", function(self, dt, t)
        if not self._active_buffs_data then return end

        -- Cache the HUD timebase; this is the clock we use for the Broker timer to avoid
        -- clock-domain mismatch during mission transitions/loading.
        if type(t) == "number" then
            mod._broker_toughness_cd_now_t = t
        end

        local is_visible = false
        for _, data in ipairs(self._active_buffs_data) do
            if data.buff_name == "broker_passive_stun_immunity_on_toughness_broken" then
                if data.show then
                    is_visible = true
                end
                break
            end
        end

        -- IMPORTANT:
        -- On the first ever sample after load/mission transition, we "sync" to the current
        -- visibility state without treating it as a rising edge. This prevents the common
        -- false-trigger where the first frame arrives with show=true and our latch was
        -- still false from a previous session/state.
        if not mod._broker_buff_has_sampled then
            mod._broker_buff_was_active  = is_visible
            mod._broker_buff_has_sampled = true
            return
        end

        if is_visible and not mod._broker_buff_was_active then
            local now = (type(t) == "number") and t or _now()
            mod._broker_toughness_cd_until_t = now + BROKER_TOUGHNESS_BROKEN_WINDOW_S
        end

        mod._broker_buff_was_active = is_visible
    end)
end

-- Hook both potential locations for the player buffs element to be safe
mod:hook_require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling", _hook_hud_update)
mod:hook_require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs", _hook_hud_update)

----------------------------------------------------------------
-- Talent state updater
----------------------------------------------------------------

local function _resolve_buff_ext(player_unit, hud_state)
    return (ScriptUnit.has_extension(player_unit, "buff_system") and ScriptUnit.extension(player_unit, "buff_system"))
        or (hud_state and hud_state.player_extensions and hud_state.player_extensions.buff)
end

-- Central updater for hud_state.talent_data
function mod.talent_update_state(player, player_unit, hud_state)
    local td = hud_state and hud_state.talent_data
    if not td then
        return
    end

    -- Always clear (prevents stale state if settings/archetype change mid-session)
    td.cooldown_fraction        = 0
    td.is_active                = false
    td.is_available             = false
    td.stacks                   = 0
    td.mode                     = nil
    td.segment_max              = nil

    -- Adamant Terminus Warrant extra fields (always clear)
    td.adamant_tw_melee_stacks  = 0
    td.adamant_tw_ranged_stacks = 0

    local setting               = mod._settings and mod._settings.timer_buff_dropdown
    if setting ~= "all" then
        return
    end

    if not (player and player_unit) then
        return
    end

    -- Use the cached archetype helper (optimization)
    local archetype = mod.get_local_archetype()
    if not archetype then
        return
    end

    ----------------------------------------------------------------
    -- Zealot: cooldown-style bar (hardcoded timing; start is driven by hooks)
    ----------------------------------------------------------------
    if archetype == "zealot" then
        td.is_available = true
        td.mode         = "zealot_resist_death"
        td.stacks       = 0
        td.segment_max  = 0

        local now       = _now()
        local until_t   = tonumber(mod._zealot_resist_death_cd_until_t) or 0
        local rem       = until_t - now

        -- Safety: if we ever end up with an impossible remaining time (clock mismatch),
        -- clear the timer rather than letting it “pin” forever.
        if rem > (ZEALOT_RESIST_DEATH_CD_S + 1.0) then
            mod._zealot_resist_death_cd_until_t = 0
            td.cooldown_fraction = 0
            td.is_active = false
            return
        end

        if rem > 0 then
            td.cooldown_fraction = math.clamp(rem / ZEALOT_RESIST_DEATH_CD_S, 0, 1)
            td.is_active         = true
        else
            if until_t ~= 0 then
                mod._zealot_resist_death_cd_until_t = 0
            end
            td.cooldown_fraction = 0
            td.is_active         = false
        end

        return
    end

    ----------------------------------------------------------------
    -- Psyker: Empowered Grenades segmented stacks
    ----------------------------------------------------------------
    if archetype == "psyker" then
        local buff_ext = _resolve_buff_ext(player_unit, hud_state)
        if not buff_ext then
            return
        end

        local stacks, has_buff = mod.get_buff_stack_count(buff_ext, PSYKER_EMPOWERED_GRENADE_VISUAL_BUFFS)
        stacks                 = math.clamp(tonumber(stacks) or 0, 0, PSYKER_SEGMENT_MAX)

        td.mode                = (has_buff == true) and "psyker_empowered_grenades" or nil
        td.stacks              = stacks
        td.cooldown_fraction   = 0
        td.is_available        = (has_buff == true)
        td.is_active           = (has_buff == true and stacks > 0)
        td.segment_max         = PSYKER_SEGMENT_MAX
        return
    end

    ----------------------------------------------------------------
    -- Broker: toughness-broken countdown (timer set by HUD hook)
    ----------------------------------------------------------------
    if archetype == "broker" then
        td.is_available = true
        td.mode         = "broker_toughness_broken_cd"
        td.stacks       = 0
        td.segment_max  = 0

        -- Use the cached HUD clock if available to avoid timebase switching during loads.
        local now       = tonumber(mod._broker_toughness_cd_now_t) or _now()
        local until_t   = tonumber(mod._broker_toughness_cd_until_t) or 0
        local rem       = until_t - now

        -- Safety: if we ever end up with an impossible remaining time (clock mismatch),
        -- clear the timer rather than letting it “pin” forever.
        if rem > (BROKER_TOUGHNESS_BROKEN_WINDOW_S + 1.0) then
            mod._broker_toughness_cd_until_t = 0
            td.cooldown_fraction = 0
            td.is_active = false
            return
        end

        if rem > 0 then
            td.cooldown_fraction = math.clamp(rem / BROKER_TOUGHNESS_BROKEN_WINDOW_S, 0, 1)
            td.is_active         = true
        else
            if until_t ~= 0 then
                mod._broker_toughness_cd_until_t = 0
            end
            td.cooldown_fraction = 0
            td.is_active         = false
        end

        return
    end

    ----------------------------------------------------------------
    -- Adamant: Terminus Warrant (melee + ranged independent stacks)
    ----------------------------------------------------------------
    if archetype == "adamant" then
        local buff_ext = _resolve_buff_ext(player_unit, hud_state)
        if not buff_ext then
            return
        end

        local melee_stacks, melee_has   = mod.get_buff_stack_count(buff_ext, ADAMANT_TERMINUS_WARRANT_MELEE_STACK_BUFFS)
        local ranged_stacks, ranged_has = mod.get_buff_stack_count(buff_ext, ADAMANT_TERMINUS_WARRANT_RANGED_STACK_BUFFS)

        melee_stacks                    = math.clamp(tonumber(melee_stacks) or 0, 0, ADAMANT_TERMINUS_WARRANT_MAX_STACKS)
        ranged_stacks                   = math.clamp(tonumber(ranged_stacks) or 0, 0, ADAMANT_TERMINUS_WARRANT_MAX_STACKS)

        td.adamant_tw_melee_stacks      = melee_stacks
        td.adamant_tw_ranged_stacks     = ranged_stacks

        local any_has                   = (melee_has == true) or (ranged_has == true) or (melee_stacks > 0) or
            (ranged_stacks > 0)
        if not any_has then
            -- Leave td.mode nil so the renderer doesn't show TW segments (and force-show stays quiet).
            return
        end

        td.mode         = "adamant_terminus_warrant"
        td.segment_max  = 2
        td.is_available = true
        td.is_active    = (melee_stacks > 0) or (ranged_stacks > 0)

        -- Keep td.stacks meaningful for any generic “active?” checks elsewhere
        td.stacks       = math.max(melee_stacks, ranged_stacks)

        return
    end
end

return {}
