-- File: RingHud/scripts/mods/RingHud/systems/sound_manager.lua
local mod = get_mod("RingHud"); if not mod then return end

mod.sound_manager                  = mod.sound_manager or {}
local SM                           = mod.sound_manager

-----------------------------------------------------------------------
-- Zealot "Until Death" / "Holy Revenant" proc detection + hardcoded CD
-----------------------------------------------------------------------
local ZEALOT_RESIST_DEATH_CD_S     = 125.0
local ZEALOT_RESIST_DEATH_ON_EVENT = "wwise/events/player/play_ability_zealot_maniac_resist_death_on"

local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("gameplay") or MT:time("ui") or os.clock()
    end
    return os.clock()
end

local function _local_player_is_zealot()
    -- Use cached archetype helper (performance)
    return mod.get_local_archetype() == "zealot"
end

local function _start_zealot_resist_death_cd_if_idle(now_t)
    local until_t = tonumber(mod._zealot_resist_death_cd_until_t) or 0
    if until_t <= now_t then
        mod._zealot_resist_death_cd_until_t = now_t + ZEALOT_RESIST_DEATH_CD_S
    end
end

-----------------------------------------------------------------------
-- Detect presence of AAR once at startup.
-----------------------------------------------------------------------
local aar = get_mod("audible_ability_recharge")
mod._aar_present = aar ~= nil

-----------------------------------------------------------------------
-- 0) Read AAR's configured sounds (so RingHud can mirror behavior)
-----------------------------------------------------------------------
local function _safe_get_aar_sound(setting_id, fallback)
    if not aar then return fallback end
    local getter = aar.get or aar.get_setting
    if type(getter) == "function" then
        -- AAR uses colon-call style; pass self to be safe with either style.
        local v = getter(aar, setting_id)
        if type(v) == "string" and v ~= "" then
            return v
        end
    end
    return fallback
end

-- Conservative fallbacks (only used if AAR has no value)
mod._aar_sound_1 = _safe_get_aar_sound("ability_charge_1_sound",
    "wwise/events/ui/play_hud_ability_off_cooldown")
mod._aar_sound_2 = _safe_get_aar_sound("ability_charge_2_sound",
    "wwise/events/ui/play_hud_ability_off_cooldown")

-----------------------------------------------------------------------
-- 1) Wwise hook (AAR mute + Resist Death ON event detection)
--    IMPORTANT: single hook, extended (no duplicates).
-----------------------------------------------------------------------
if not mod._aar_wwise_hook_installed then
    -- Guard flag: our own plays set allowlist = true temporarily (AAR mirror)
    mod._aar_allow_wwise_play = false

    mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
        -- Zealot resist death: detect ONLY the "_on" event,
        -- and gate to the local Zealot so other players' audio can't start our bar.
        if event_name == ZEALOT_RESIST_DEATH_ON_EVENT and _local_player_is_zealot() then
            _start_zealot_resist_death_cd_if_idle(_now())
        end

        -- AAR: swallow ONLY the two specific events selected in AAR's settings
        if mod._aar_present
            and (event_name == mod._aar_sound_1 or event_name == mod._aar_sound_2)
            and not mod._aar_allow_wwise_play
        then
            return
        end

        return func(wwise_world, event_name, ...)
    end)

    mod._aar_wwise_hook_installed = true
end

-----------------------------------------------------------------------
-- AAR-only logic below (mirroring AAR sounds and muting its own plays)
-----------------------------------------------------------------------
if mod._aar_present then
    -----------------------------------------------------------------------
    -- 2) Provide a safe "play AAR event once" helper for RingHud
    --    (AAR’s own plays are muted by the Wwise hook above)
    -----------------------------------------------------------------------
    if not mod._aar_play_event then
        mod._aar_play_event = function(event_name)
            if not event_name or event_name == "" then return false end
            local world_manager = Managers.world
            if not world_manager or not world_manager.world then return false end

            local world = world_manager:world("level_world")
            if not world or not world_manager.wwise_world then return false end

            local wwise_world = world_manager:wwise_world(world)
            if not wwise_world then return false end

            mod._aar_allow_wwise_play = true
            WwiseWorld.trigger_resource_event(wwise_world, event_name)
            mod._aar_allow_wwise_play = false
            return true
        end
    end

    -----------------------------------------------------------------------
    -- 3) Single hook for BOTH debounce + edge detection
    --    (combat ability only; suppress grenade/blitz)
    -----------------------------------------------------------------------
    if not mod._aar_hook_installed then
        -- Weak-per-extension state:
        local state = setmetatable({}, { __mode = "k" })

        -- Base coalesce window (seconds)
        local COALESCE_TTL = 0.05
        -- Grenade/blitz cause most flapping; give them a longer TTL
        local PER_TYPE_TTL = {
            grenade_ability = 0.15,
            blitz_ability   = 0.15,
            -- combat_ability falls back to COALESCE_TTL
        }

        local function _norm_key(ability_type)
            local k = ability_type
            if k == nil then k = "combat_ability" end
            if type(k) ~= "string" then k = tostring(k) end
            return string.lower(k)
        end

        local function _is_grenade_like(key)
            if key == "grenade_ability" or key == "blitz_ability" then return true end
            if string.find(key, "grenade", 1, true) then return true end
            return false
        end

        mod:hook(CLASS.PlayerUnitAbilityExtension, "remaining_ability_cooldown",
            function(func, self_ext, ability_type, ...)
                local key = _norm_key(ability_type)
                local now = _now()

                local st = state[self_ext]
                if not st then
                    st = { cache = {}, ready = {} }
                    state[self_ext] = st
                end

                -- ---------- Debounce ----------
                local entry = st.cache[key]
                if not (entry and entry.expires_at and now < entry.expires_at) then
                    local v       = func(self_ext, ability_type, ...)
                    local ttl     = PER_TYPE_TTL[key] or COALESCE_TTL
                    entry         = { v = v, expires_at = now + ttl }
                    st.cache[key] = entry
                end

                local remaining_time = entry.v

                -- ---------- Edge detection (combat ability only) ----------
                if not _is_grenade_like(key) then
                    local was_ready = st.ready[key] == true
                    local is_ready  = (remaining_time or 0) <= 0

                    if is_ready and not was_ready then
                        -- Choose AAR’s event based on charges (1 vs 2)
                        local event = mod._aar_sound_1
                        local charges = nil
                        if type(self_ext.remaining_ability_charges) == "function" then
                            charges = self_ext:remaining_ability_charges(ability_type)
                        end
                        if tonumber(charges) == 2 and mod._aar_sound_2 and mod._aar_sound_2 ~= "" then
                            event = mod._aar_sound_2
                        end
                        if event and mod._aar_play_event then
                            mod._aar_play_event(event)
                        end
                    end

                    st.ready[key] = is_ready
                end

                return remaining_time
            end)

        mod._aar_hook_installed = true
    end
end

----------------------------------------------------------------
-- Public API: Unified sound playing interface
----------------------------------------------------------------

-- Helper: pick sound based on charges (for AAR logic compatibility)
function SM.pick_aar_sound_by_charges(charges)
    local s1 = mod._aar_sound_1
    local s2 = mod._aar_sound_2 or s1
    -- Default to vanilla sound if AAR didn't provide one
    if not s1 or s1 == "" then s1 = "wwise/events/ui/play_hud_ability_off_cooldown" end
    if not s2 or s2 == "" then s2 = s1 end

    return (charges == 2) and s2 or s1
end

-- Unified play function:
-- 1. If AAR is installed and event is one of AAR's events, uses the Wwise workaround.
-- 2. Otherwise tries to play via UI widget/renderer if provided.
-- 3. Returns success/failure.
function SM.play_sound(event_name, ui_renderer_source)
    if not event_name or event_name == "" then return false end

    -- Check if this is an AAR event that needs special handling
    local is_aar_event = (event_name == (mod._aar_sound_1 or "")) or (event_name == (mod._aar_sound_2 or ""))

    if mod._aar_present and is_aar_event then
        if mod._aar_play_event then
            return mod._aar_play_event(event_name)
        end
        return false
    end

    -- Normal UI sound playback
    if ui_renderer_source and ui_renderer_source._play_sound then
        ui_renderer_source:_play_sound(event_name)
        return true
    end

    return false
end

return SM
