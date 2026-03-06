-- File: RingHud/scripts/mods/RingHud/context/scanner_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ScannerContext = {}

-- State exposed to the rest of the mod (local-player oriented)
mod.scanner_active = mod.scanner_active or false

-- Cross-file per-unit auspex state (teammates + local)
mod.auspex_active_units = mod.auspex_active_units or {}

local function _set_unit_active(unit, active)
    if not unit then
        return
    end
    mod.auspex_active_units[unit] = active and true or false
end

function ScannerContext.init()
    -- Guard against double init / rehooking
    if mod._scanner_context_inited then
        return
    end
    mod._scanner_context_inited = true

    ------------------------------------------------------------------------
    -- Detects when the scanning loop SFX starts/stops (actually scanning)
    ------------------------------------------------------------------------
    if CLASS.AuspexScanningEffects then
        mod:hook_safe(CLASS.AuspexScanningEffects, "_run_searching_sfx_loop", function(self)
            -- Track for the owning unit (works for husks + local)
            _set_unit_active(self and self._owner_unit, true)

            -- Preserve existing local-player behaviour (only local was previously tracked)
            if self and not self._is_husk then
                mod.scanner_active = true
            end
        end)

        mod:hook_safe(CLASS.AuspexScanningEffects, "_stop_scan_units_effects", function(self)
            _set_unit_active(self and self._owner_unit, false)

            if self and not self._is_husk then
                mod.scanner_active = false
            end
        end)

        -- Extra safety: if the scanner is unwielded without a clean stop, ensure false.
        mod:hook_safe(CLASS.AuspexScanningEffects, "unwield", function(self)
            _set_unit_active(self and self._owner_unit, false)

            if self and not self._is_husk then
                mod.scanner_active = false
            end
        end)
    end

    ------------------------------------------------------------------------
    -- Detects when the device is equipped/unequipped (wield/unwield)
    ------------------------------------------------------------------------
    if CLASS.AuspexEffects then
        mod:hook_safe(CLASS.AuspexEffects, "wield", function(self)
            local owner_unit = self and self._fx_extension and self._fx_extension._unit
            _set_unit_active(owner_unit, true)

            if self and not self._is_husk then
                mod.scanner_active = true
            end
        end)

        mod:hook_safe(CLASS.AuspexEffects, "unwield", function(self)
            local owner_unit = self and self._fx_extension and self._fx_extension._unit
            _set_unit_active(owner_unit, false)

            if self and not self._is_husk then
                mod.scanner_active = false
            end
        end)
    end
end

function ScannerContext.on_game_state_changed(status, state_name)
    if state_name == "StateGameplay" and status == "enter" then
        mod.scanner_active = false
        -- Reset per-unit table on entering gameplay (fresh mission/session)
        mod.auspex_active_units = {}
    end
end

return ScannerContext
