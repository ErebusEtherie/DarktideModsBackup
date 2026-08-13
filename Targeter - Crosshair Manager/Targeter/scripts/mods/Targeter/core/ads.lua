-- ===== Targeter/scripts/mods/Targeter/core/ads.lua =====
local mod = get_mod("Targeter")
if not mod then return end

local AlternateFire  = require("scripts/utilities/alternate_fire")

mod.ADS_END_GRACE    = mod.ADS_END_GRACE or 0.2
mod._ads_poll_active = mod._ads_poll_active or false
mod._ads_state       = mod._ads_state or { last_true_t = 0, started_by = nil }

local STARTED_BY_MAP = {
    aim = "action_start_aim",
    overload_charge = "action_start_overload_charge"
}

function mod.ads_notify_action_start(action_settings, t)
    if action_settings then
        local kind = action_settings.kind
        if kind == "aim" or kind == "overload_charge" then
            mod._ads_poll_active      = true
            mod._ads_state.started_by = STARTED_BY_MAP[kind] or "action_start_aim"

            if type(t) == "number" then
                mod._ads_state.last_true_t = t
            else
                local now_func = mod.now
                mod._ads_state.last_true_t = mod._last_t or (now_func and now_func()) or 0
            end
        end
    end
end

mod:hook_safe(AlternateFire, "start", function(...)
    mod._ads_poll_active = true
    mod._ads_state.started_by = "alternate_fire_start"

    local now_func = mod.now
    mod._ads_state.last_true_t = mod._last_t or (now_func and now_func()) or 0
end)
