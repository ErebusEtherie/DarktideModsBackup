-- File: RingHud/scripts/mods/RingHud/compat/audible_ability_recharge_bridge.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Detect presence of AAR once at startup.
local aar = get_mod("audible_ability_recharge")
mod._aar_present = aar ~= nil

-- Nothing to do if AAR isn't installed.
if not mod._aar_present then
    return true
end

-----------------------------------------------------------------------
-- 0) Read AAR's configured sounds (so RingHud can mirror behavior)
-----------------------------------------------------------------------
local function _safe_get_aar_sound(setting_id, fallback)
    local ok, v = pcall(function() return aar:get(setting_id) end)
    if ok and type(v) == "string" and v ~= "" then return v end
    return fallback
end

-- Conservative fallbacks (only used if AAR has no value)
mod._aar_sound_1 = _safe_get_aar_sound("ability_charge_1_sound",
    "wwise/events/ui/play_hud_ability_off_cooldown")
mod._aar_sound_2 = _safe_get_aar_sound("ability_charge_2_sound",
    "wwise/events/ui/play_hud_ability_off_cooldown")

-----------------------------------------------------------------------
-- 1) Provide a safe "play AAR event once" helper for RingHud
--    (and mute AAR's own plays to prevent loops)
-----------------------------------------------------------------------
if not mod._aar_wwise_hook_installed then
    -- We filter ONLY the two specific events selected in AAR's settings.
    -- Guard flag: our own plays set allowlist = true temporarily.
    mod._aar_allow_wwise_play = false

    mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
        if (event_name == mod._aar_sound_1 or event_name == mod._aar_sound_2) and not mod._aar_allow_wwise_play then
            -- Swallow AAR’s original sound to prevent loops.
            return
        end
        return func(wwise_world, event_name, ...)
    end)

    -- Expose a safe player to RingHud.lua
    mod._aar_play_event = function(event_name)
        local world = Managers.world and Managers.world:world("level_world")
        if not world then return false end
        local wwise_world = Managers.world:wwise_world(world)
        if not wwise_world then return false end
        mod._aar_allow_wwise_play = true
        WwiseWorld.trigger_resource_event(wwise_world, event_name)
        mod._aar_allow_wwise_play = false
        return true
    end

    mod._aar_wwise_hook_installed = true
end

-----------------------------------------------------------------------
-- 2) Single hook for BOTH debounce + edge detection
--    (combat ability only; suppress grenade/blitz)
-----------------------------------------------------------------------
if not mod._aar_hook_installed then
    -- Weak-per-extension state:
    -- state[self_ext] = {
    --   cache = { [key] = { v = number, expires_at = t } },
    --   ready = { [key] = bool }
    -- }
    local state = setmetatable({}, { __mode = "k" })

    -- Base coalesce window (seconds)
    local COALESCE_TTL = 0.05
    -- Grenade/blitz cause most flapping; give them a longer TTL
    local PER_TYPE_TTL = {
        grenade_ability = 0.15,
        blitz_ability   = 0.15,
        -- combat_ability falls back to COALESCE_TTL
    }

    local function _now()
        local MT = Managers and Managers.time
        if MT and MT.time then
            return MT:time("gameplay") or MT:time("ui") or os.clock()
        end
        return os.clock()
    end

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
            if entry and entry.expires_at and now < entry.expires_at then
                -- Use cached value
            else
                local v       = func(self_ext, ability_type, ...)
                local ttl     = PER_TYPE_TTL[key] or COALESCE_TTL
                entry         = { v = v, expires_at = now + ttl }
                st.cache[key] = entry
            end

            local remaining_time = entry.v

            -- ---------- Edge detection (combat ability only) ----------
            if not _is_grenade_like(key) then
                local was_ready = st.ready[key] == true
                local is_ready  = remaining_time <= 0

                if is_ready and not was_ready then
                    -- Choose AAR’s event based on charges (1 vs 2)
                    local event = mod._aar_sound_1
                    local ok_c, charges = pcall(function()
                        return self_ext:remaining_ability_charges(ability_type)
                    end)
                    if ok_c and tonumber(charges) == 2 then
                        event = mod._aar_sound_2 or event
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

-- All set: AAR stays for settings UI; its plays are muted, and RingHud
-- mirrors the selected sounds with clean, per-ability edge detection.
return true
