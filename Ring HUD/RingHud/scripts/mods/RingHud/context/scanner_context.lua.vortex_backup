-- File: RingHud/scripts/mods/RingHud/context/scanner_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ScannerContext = {}

-- State exposed to the rest of the mod
mod.scanner_active = false

function ScannerContext.init()
    -- Detects when the scanning loop SFX starts (actually scanning)
    if CLASS.AuspexScanningEffects then
        mod:hook_safe(CLASS.AuspexScanningEffects, "_run_searching_sfx_loop", function(self)
            if self._is_husk then return end
            mod.scanner_active = true
        end)

        mod:hook_safe(CLASS.AuspexScanningEffects, "_stop_scan_units_effects", function(self)
            if self._is_husk then return end
            mod.scanner_active = false
        end)
    end

    -- Detects when the device is equipped/unequipped
    if CLASS.AuspexEffects then
        mod:hook_safe(CLASS.AuspexEffects, "wield", function(self)
            if self._is_husk then return end
            mod.scanner_active = true
        end)

        mod:hook_safe(CLASS.AuspexEffects, "unwield", function(self)
            if self._is_husk then return end
            mod.scanner_active = false
        end)
    end
end

function ScannerContext.on_game_state_changed(status, state_name)
    if state_name == "StateGameplay" and status == "enter" then
        mod.scanner_active = false
    end
end

return ScannerContext
