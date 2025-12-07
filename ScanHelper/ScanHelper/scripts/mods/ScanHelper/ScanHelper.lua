local mod = get_mod("ScanHelper")

local scannable_units = {}

local _set_outline_and_highlight = function(active)
    for scannable_unit, _ in pairs(scannable_units) do
        local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

        if scannable_extension then
            local is_active = scannable_extension:is_active()

            if is_active then
                scannable_extension:set_scanning_outline(active)
                scannable_extension:set_scanning_highlight(active)
            end
        end
    end
end

mod:hook_safe(CLASS.AuspexScanningEffects, "init", function (...)
    local mission_objective_zone_system = Managers.state.extension:system("mission_objective_zone_system")
    
    scannable_units = mission_objective_zone_system:scannable_units()

    if scannable_units then
        _set_outline_and_highlight(true)
    end
end)