local mod = get_mod("ScanHelper")
mod:hook_safe(CLASS.AuspexScanningEffects, "init", function (...)
    local mission_objective_zone_system = Managers.state.extension:system("mission_objective_zone_system")
local scannable_units = mission_objective_zone_system:scannable_units()

for current_scannable_unit, _ in pairs(scannable_units) do
        local scannable_extension = ScriptUnit.has_extension(current_scannable_unit, "mission_objective_zone_scannable_system")
        if scannable_extension then
            local is_active = scannable_extension:is_active()
            if is_active then
                scannable_extension:set_scanning_outline(true)
                scannable_extension:set_scanning_highlight(true)
            end
        end
    end
end)