--[[
    cooldown_tracking.lua

    Tracks combat ability cooldown durations by polling the "combat_ability"
    unit data component each frame via the HudElementPlayerBuffs._update_buffs hook.

    Detection logic:
      - cooldown field == 0 means the ability is ready.
      - cooldown field > 0 is an absolute fixed-frame timestamp for when it expires.
      - 0 → nonzero transition = ability just used     → start timing, record souls stacks (Psyker only)
      - nonzero → 0 transition = cooldown complete     → compute duration, record entry
      - If duration < FLAG_THRESHOLD it is marked flagged (almost certainly a reset).
      - If tracking ends with a pending use, it is silently dropped (orphaned).
      - If the player dies, any pending use is orphaned. Knockdown is NOT orphaned
        because cooldowns continue ticking normally during knockdown.

    Works for all archetypes automatically; Psyker-specific souls tracking is
    gated on the is_psyker flag set at mission start.
--]]

local mod = get_mod("cooldown_analysis")

local FLAG_THRESHOLD = 4.0   -- seconds; completions below this are flagged

local state = {
    active          = false,
    is_psyker       = false,
    uses            = {},       -- completed CooldownEntry records
    pending_use     = nil,      -- { use_time, souls_stacks, use_number } while on cooldown
    last_cooldown   = nil,      -- last observed component.cooldown value
    prev_souls      = 0,        -- souls count from the PREVIOUS frame (souls are consumed on use)
    mission_start_t = 0,
}

-- ===== Debug helper =====

local function debug(msg)
    if mod:get("debug_messages") then
        mod:echo("[CA] " .. msg)
    end
end

-- ===== Public API =====

function mod:cooldown_tracking_active()
    return state.active
end

function mod:start_cooldown_tracking(is_psyker)
    state.active          = true
    state.is_psyker       = is_psyker
    state.uses            = {}
    state.pending_use     = nil
    state.last_cooldown   = nil
    state.prev_souls      = 0
    state.mission_start_t = mod:now()
    debug("Tracking started. Psyker: " .. tostring(is_psyker))
end

function mod:end_cooldown_tracking()
    if not state.active then return end
    state.active = false

    -- Orphaned pending use (ability used but mission ended before cooldown completed)
    if state.pending_use then
        debug("Orphaned pending use dropped.")
        state.pending_use = nil
    end

    local n   = #state.uses
    local dur = mod:now() - state.mission_start_t

    debug(string.format("Tracking ended: %d completed uses, %.0fs mission.", n, dur))

    local player = Managers.player and Managers.player:local_player(1)
    local params = mod._current_mission_params or {}

    local session = {
        uses      = state.uses,
        duration  = dur,
        map       = params.mission_name or "unknown",
        player    = player and player:name() or "unknown",
        archetype = player and player:archetype_name() or "unknown",
        is_psyker = state.is_psyker,
    }

    mod._last_cooldown_session = session

    if n > 0 then
        mod:save_cooldown_session(session)
    end
end

-- ===== Souls stack reader =====

-- Reads the soul count directly from the "talent_resource" unit data component.
-- This is the authoritative source the game itself uses internally, and works
-- regardless of whether the player has the base (max 4) or increased (max 6)
-- souls talent. The hud_element parameter is kept for signature compatibility
-- but we access unit_data via the parent player extensions instead.
local function get_souls_stacks(hud_element)
    local player_extensions = hud_element._parent:player_extensions()
    local unit_data = player_extensions and player_extensions.unit_data
    if not unit_data then return 0 end

    local ok, souls = pcall(function()
        return unit_data:read_component("talent_resource").current_resource
    end)

    if ok and souls then return math.floor(souls) end
    return 0
end

-- ===== Bar colour helper (used by cooldown_view.lua) =====

-- Returns an ARGB colour table for a completed use entry.
-- Normal bars: blue-teal, Psyker bars: tinted greener by souls count.
-- Flagged bars: amber/orange regardless.
function mod.bar_color(entry, is_psyker)
    if entry.flagged then
        return { 220, 210, 110, 20 }    -- amber / orange
    end
    if not is_psyker then
        return { 210, 40, 170, 190 }    -- standard blue-teal
    end
    -- Tint by souls count: 0 = blue-teal, 4 = green-teal
    local s    = math.min(4, entry.souls_stacks or 0)
    local frac = s / 4
    local g    = math.floor(130 + frac * 80)
    local b    = math.floor(200 - frac * 55)
    return { 210, 30, g, b }
end

-- ===== Death detection =====
-- When the local player is knocked down or dies, any pending cooldown
-- is orphaned (silently dropped). Without this, the cooldown resumes
-- ticking after respawn and completes at a wildly inflated duration.

local function is_local_player(unit)
    local player = Managers.player:local_player(1)
    return player and unit == player.player_unit
end

local AttackSettings = mod:original_require("scripts/settings/damage/attack_settings")
local attack_results = AttackSettings.attack_results

mod:hook_safe(CLASS.AttackReportManager, "_process_attack_result", function(self, buffer_data)
    if not state.active then return end
    if not state.pending_use then return end

    local ok, relevant = pcall(function()
        local attacked_unit = buffer_data.attacked_unit
        if not is_local_player(attacked_unit) then return false end
        local attack_result = buffer_data.attack_result
        return attack_result == attack_results.died
    end)

    if ok and relevant then
        debug(string.format("Use #%d orphaned: player died.", state.pending_use.use_number))
        state.pending_use   = nil
        state.last_cooldown = nil   -- reset so post-respawn cooldown isn't misread
    end
end)

-- ===== Per-frame hook =====

mod:hook_safe(CLASS.HudElementPlayerBuffs, "_update_buffs", function(self)
    if not state.active then return end
    -- Guard against custom buff bars from other mods
    if self.__class_name ~= "HudElementPlayerBuffs" or self._filter then return end

    local player_extensions = self._parent:player_extensions()
    local unit_data = player_extensions and player_extensions.unit_data
    if not unit_data then return end

    -- Read the combat_ability component; .cooldown is 0 when ready, >0 = expiry timestamp
    local ok, cooldown = pcall(function()
        return unit_data:read_component("combat_ability").cooldown
    end)
    if not ok or cooldown == nil then return end

    local last = state.last_cooldown
    local now  = mod:now()

    -- Update souls count every frame for Psyker.
    -- We read CURRENT souls here but store it as prev_souls for next frame,
    -- because souls are consumed on the same frame the ability fires (remove_on_ability).
    -- So when we detect 0→nonzero, we use the value from the frame before.
    -- Reads from talent_resource.current_resource — the authoritative internal source,
    -- works for both psyker_souls (max 4) and psyker_souls_increased_max_stacks (max 6).
    local current_souls = 0
    if state.is_psyker then
        local ok2, s = pcall(get_souls_stacks, self)
        if ok2 then current_souls = s end
    end

    -- --- Detect ability use: cooldown transitions 0 → nonzero ---
    if last ~= nil and last == 0 and cooldown > 0 then
        -- Use prev_souls: souls were read the frame BEFORE this one, before consumption
        state.pending_use = {
            use_time     = now,
            souls_stacks = state.prev_souls,
            use_number   = #state.uses + 1,
        }
        debug(string.format("Use #%d detected. Souls: %d", state.pending_use.use_number, state.pending_use.souls_stacks))
    end

    -- --- Detect cooldown complete: cooldown transitions nonzero → 0 ---
    if last ~= nil and last > 0 and cooldown == 0 then
        if state.pending_use then
            local duration = now - state.pending_use.use_time
            local flagged  = duration < FLAG_THRESHOLD

            local entry = {
                use_number   = state.pending_use.use_number,
                souls_stacks = state.pending_use.souls_stacks,
                duration     = duration,
                flagged      = flagged,
            }
            state.uses[#state.uses + 1] = entry
            state.pending_use = nil

            debug(string.format(
                "Use #%d complete: %.2fs%s",
                entry.use_number, duration, flagged and " [FLAGGED]" or ""
            ))
        end
    end

    state.prev_souls    = current_souls
    state.last_cooldown = cooldown
end)
